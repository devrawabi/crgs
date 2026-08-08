from flask import Blueprint, current_app, jsonify, request

from app.cache import cache_get, cache_set
from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import DEFAULT_MAX_OFFSET, parse_int, parse_limit_offset
from app.routes.auth import limiter
from app.services.customer_target_achievement import refresh_new_acquisition_achieved

customers_bp = Blueprint("customers", __name__)

CUSTOMER_COLUMNS = (
    "CUST_CODE",
    "CUST_NAME",
    "ADDRESS",
    "CREDIT_LIMIT",
    "CREDIT_AMOUNT",
    "CATEGORY",
    "CATEGORYNAME",
    "ROUTE",
    "ROUTENAME",
    "TYPE",
    "MOBILE",
    "LOCATIONMAP",
    "CREATEDSTATUS",
    "CUSTOMERSTATUS",
    "WPNO",
)

DEFAULT_PAGE_SIZE = 10
MAX_PAGE_SIZE = 200
BILL_ITEMS_PAGE_SIZE = 5
MAX_BILL_ITEMS_PAGE_SIZE = 100


# A customer is "missing" when they were never billed, or their last bill is
# at least :missing_threshold days ago. missing_days=0 from the API means
# "not billed today" and is converted to threshold 1 before binding.
_MISSING_CONDITION = (
    "(av.BILLDATE IS NULL OR "
    "(TRUNC(SYSDATE) - TRUNC(av.BILLDATE)) >= :missing_threshold)"
)

_AGE_SELECT = (
    "av.BILLDATE AS LAST_PURCHASE_DATE, "
    "av.NETBILLAMOUNT AS LAST_PURCHASE_AMOUNT, "
    "av.BILLNO AS LAST_PURCHASE_BILLNO, "
    "av.LOCATIONCODE AS LAST_PURCHASE_LOCATION, "
    "CASE WHEN av.BILLDATE IS NULL THEN NULL "
    "ELSE TRUNC(SYSDATE) - TRUNC(av.BILLDATE) END AS DAYS_SINCE_PURCHASE, "
    f"CASE WHEN {_MISSING_CONDITION} THEN 1 ELSE 0 END AS IS_MISSING"
)

# Stats / outstanding only need these customer columns (keeps age join lighter).
_STATS_CUSTOMER_COLUMNS = ("CUST_CODE", "CREDIT_AMOUNT", "CUSTOMERSTATUS")


def _age_join(age_view: str, customer_alias: str = "c") -> str:
    """
    LEFT JOIN the customer age view (last bill) by code.

    Native equality only — OR TRIM(TO_CHAR(...)) blocks indexes and forces
    full scans on Missing list / stats. Codes must match CUST_CODE type.
    """
    return (
        f" LEFT JOIN {age_view} av"
        f" ON av.CUSTOMERCODE = {customer_alias}.CUST_CODE"
    )


def _age_join_stats(
    view_name: str,
    age_view: str,
    customer_alias: str,
    route_binds: list[str],
) -> str:
    """
    Stats-only join: aggregate age rows for the requested routes only.

    Avoids GROUP BY over the entire CUSTOMERAGEVIEW on every Reports load.
    """
    route_in = ", ".join(route_binds)
    return (
        f" LEFT JOIN ("
        f"   SELECT a.CUSTOMERCODE, MAX(a.BILLDATE) AS BILLDATE"
        f"   FROM {age_view} a"
        f"   WHERE a.CUSTOMERCODE IN ("
        f"     SELECT cx.CUST_CODE FROM {view_name} cx"
        f"     WHERE cx.ROUTE IN ({route_in})"
        f"   )"
        f"   GROUP BY a.CUSTOMERCODE"
        f" ) av"
        f" ON av.CUSTOMERCODE = {customer_alias}.CUST_CODE"
    )


def _bind_route(route: str):
    """Bind numeric routes as ints so Oracle can use a ROUTE index (NUMBER columns)."""
    try:
        return int(route)
    except ValueError:
        return route


def _bind_cust_code(code: str):
    """Strip only — keep string so padded/alphanumeric CUST_CODE values still match."""
    return str(code or "").strip()


def _bind_maybe_number(value: str):
    """Bind digits as int so BILLNO / LOCATIONCODE NUMBER indexes stay usable."""
    text = str(value or "").strip()
    if not text:
        return text
    try:
        return int(text)
    except ValueError:
        return text


def _contactinfo_table() -> str:
    return current_app.config["ORACLE_CONTACTINFO_TABLE"]


def _customer_targets_table() -> str:
    return current_app.config["ORACLE_CUSTOMER_TARGETS_TABLE"]


def _to_float(value, default: float | None = None) -> float | None:
    if value is None or value == "":
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalize_contact_status(value: str) -> str | None:
    text = str(value or "").strip()
    if not text:
        return None
    key = text.lower().replace(" ", "").replace("-", "").replace("_", "")
    aliases = {
        "prospect": "Prospect",
        "followup": "Follow-up",
        "converted": "Converted",
    }
    if key in aliases:
        return aliases[key]
    # Allow storing a custom status string as-is (trimmed).
    return text[:50]


def _next_customer_code(cursor, table_name: str) -> str:
    cursor.execute(
        f"""
        SELECT NVL(MAX(TO_NUMBER(REGEXP_SUBSTR(TRIM(CUSTOMERCODE), '^[0-9]+'))), 0) + 1
        FROM {table_name}
        """
    )
    row = cursor.fetchone()
    next_no = int(row[0]) if row and row[0] is not None else 1
    return str(next_no)


def _missing_threshold(missing_days: int) -> int:
    """API missing_days=0 means 'not billed today' (>= 1 day)."""
    return 1 if missing_days <= 0 else missing_days


def _priority_condition(priority: str) -> str | None:
    normalized = priority.strip().lower()
    if normalized == "missing":
        return _MISSING_CONDITION
    if normalized == "outstanding":
        return (
            "(UPPER(c.CUSTOMERSTATUS) LIKE '%OUT%' "
            "OR NVL(c.CREDIT_AMOUNT, 0) > 0)"
        )
    return None


def _needs_age_before_page(priority: str) -> bool:
    """Missing filter depends on BILLDATE, so the age join must happen before ROWNUM."""
    return priority.strip().lower() == "missing"


def _build_customer_filters(
    *,
    route: str,
    search: str,
    priority: str,
    customer_alias: str = "c",
    codes: list[str] | None = None,
) -> tuple[list[str], dict]:
    conditions = []
    params: dict = {}

    if codes:
        # Native equality only — TRIM(TO_CHAR(...)) blocks CUST_CODE indexes.
        binds = {f"code{i}": _bind_cust_code(code) for i, code in enumerate(codes)}
        in_clause = ", ".join(f":code{i}" for i in range(len(codes)))
        conditions.append(f"{customer_alias}.CUST_CODE IN ({in_clause})")
        params.update(binds)
    elif route:
        # Equality — not TRIM(TO_CHAR(...)) — so a ROUTE index can be used.
        conditions.append(f"{customer_alias}.ROUTE = :route")
        params["route"] = _bind_route(route)

    if search:
        # Match the UI ("name or code") — avoid scanning address/mobile/routename.
        conditions.append(
            f"""
            (
                UPPER({customer_alias}.CUST_CODE) LIKE :search
                OR UPPER({customer_alias}.CUST_NAME) LIKE :search
            )
            """
        )
        params["search"] = f"%{search.upper()}%"

    priority_condition = _priority_condition(priority)
    if priority_condition and _needs_age_before_page(priority):
        # Outstanding is applied on the customers table alone (see page-first path).
        conditions.append(priority_condition)

    return conditions, params


def _customer_columns_sql(alias: str = "c") -> str:
    return ", ".join(f"{alias}.{column}" for column in CUSTOMER_COLUMNS)


def _stats_customer_columns_sql(alias: str = "c") -> str:
    return ", ".join(f"{alias}.{column}" for column in _STATS_CUSTOMER_COLUMNS)


def _build_page_first_query(
    view_name: str,
    age_view: str,
    *,
    route: str,
    search: str,
    priority: str,
    missing_days: int,
    offset: int,
    limit: int,
) -> tuple[str, dict]:
    """
    Filter + ORDER + ROWNUM on CUSTOMERS only.

    All and Outstanding do not use last-purchase data to decide membership.
    Avoiding CUSTOMERAGEVIEW here keeps the common list path index-friendly
    and leaves the expensive age lookup to the Missing tab and customer detail.
    """
    conditions, params = _build_customer_filters(
        route=route,
        search=search,
        priority="",  # missing handled elsewhere; outstanding added below
    )
    params["max_row"] = offset + limit
    params["min_row"] = offset

    if priority.strip().lower() == "outstanding":
        conditions.append(
            "(UPPER(c.CUSTOMERSTATUS) LIKE '%OUT%' "
            "OR NVL(c.CREDIT_AMOUNT, 0) > 0)"
        )

    where_sql = (" WHERE " + " AND ".join(conditions)) if conditions else ""

    query = f"""
        SELECT {_customer_columns_sql("paged")},
               NULL AS LAST_PURCHASE_DATE,
               NULL AS LAST_PURCHASE_AMOUNT,
               NULL AS LAST_PURCHASE_BILLNO,
               NULL AS LAST_PURCHASE_LOCATION,
               NULL AS DAYS_SINCE_PURCHASE,
               0 AS IS_MISSING
        FROM (
            SELECT {_customer_columns_sql("ranked")},
                   ranked.rnum
            FROM (
                SELECT inner_query.*, ROWNUM AS rnum
                FROM (
                    SELECT {_customer_columns_sql("c")}
                    FROM {view_name} c
                    {where_sql}
                    ORDER BY c.CUST_NAME
                ) inner_query
                WHERE ROWNUM <= :max_row
            ) ranked
            WHERE ranked.rnum > :min_row
        ) paged
        ORDER BY paged.rnum
    """
    return query, params


def _build_age_first_query(
    view_name: str,
    age_view: str,
    *,
    route: str,
    search: str,
    priority: str,
    missing_days: int,
    offset: int,
    limit: int,
) -> tuple[str, dict]:
    """
    Filter the route (and search) on CUSTOMERS first, then join age and apply
    the missing predicate before ROWNUM. Avoids joining the age view to the
    entire customers table.
    """
    conditions, params = _build_customer_filters(
        route=route,
        search=search,
        priority="",  # missing applied after the age join below
    )
    params["missing_threshold"] = _missing_threshold(missing_days)
    params["max_row"] = offset + limit
    params["min_row"] = offset

    where_sql = (" WHERE " + " AND ".join(conditions)) if conditions else ""

    # Dedupe age matches per customer before applying the missing filter so
    # ROWNUM pagination cannot skip/double-count customers.
    query = f"""
        SELECT {_customer_columns_sql("paged")},
               paged.LAST_PURCHASE_DATE,
               paged.LAST_PURCHASE_AMOUNT,
               paged.LAST_PURCHASE_BILLNO,
               paged.LAST_PURCHASE_LOCATION,
               paged.DAYS_SINCE_PURCHASE,
               paged.IS_MISSING
        FROM (
            SELECT inner_query.*, ROWNUM AS rnum
            FROM (
                SELECT {_customer_columns_sql("aged")},
                       aged.LAST_PURCHASE_DATE,
                       aged.LAST_PURCHASE_AMOUNT,
                       aged.LAST_PURCHASE_BILLNO,
                       aged.LAST_PURCHASE_LOCATION,
                       aged.DAYS_SINCE_PURCHASE,
                       aged.IS_MISSING
                FROM (
                    SELECT {_customer_columns_sql("c")},
                           {_AGE_SELECT},
                           ROW_NUMBER() OVER (
                               PARTITION BY c.CUST_CODE
                               ORDER BY av.BILLDATE DESC NULLS LAST,
                                        av.BILLNO DESC NULLS LAST
                           ) AS age_rn
                    FROM (
                        SELECT {_customer_columns_sql("c")}
                        FROM {view_name} c
                        {where_sql}
                    ) c
                    {_age_join(age_view, "c")}
                ) aged
                WHERE aged.age_rn = 1
                  AND aged.IS_MISSING = 1
                ORDER BY aged.CUST_NAME
            ) inner_query
            WHERE ROWNUM <= :max_row
        ) paged
        WHERE paged.rnum > :min_row
    """
    return query, params


def _build_list_query(
    view_name: str,
    age_view: str,
    *,
    route: str,
    search: str,
    priority: str,
    missing_days: int,
    offset: int,
    limit: int,
) -> tuple[str, dict]:
    if _needs_age_before_page(priority):
        return _build_age_first_query(
            view_name,
            age_view,
            route=route,
            search=search,
            priority=priority,
            missing_days=missing_days,
            offset=offset,
            limit=limit,
        )
    return _build_page_first_query(
        view_name,
        age_view,
        route=route,
        search=search,
        priority=priority,
        missing_days=missing_days,
        offset=offset,
        limit=limit,
    )


def _build_global_search_query(
    view_name: str,
    *,
    search: str,
    offset: int,
    limit: int,
) -> tuple[str, dict]:
    """
    Call-center / unscoped typeahead: no full-table ORDER BY.

    Leading-wildcard name match still scans, but ROWNUM stopkey avoids
    sorting the entire CUSTOMERS master before returning a small page.
    Code uses prefix match (index-friendly when CUST_CODE is text-like).
    """
    upper = search.strip().upper()
    params = {
        "search_code": f"{upper}%",
        "search_name": f"%{upper}%",
        "max_row": offset + limit,
        "min_row": offset,
    }
    query = f"""
        SELECT {_customer_columns_sql("paged")},
               NULL AS LAST_PURCHASE_DATE,
               NULL AS LAST_PURCHASE_AMOUNT,
               NULL AS LAST_PURCHASE_BILLNO,
               NULL AS LAST_PURCHASE_LOCATION,
               NULL AS DAYS_SINCE_PURCHASE,
               0 AS IS_MISSING
        FROM (
            SELECT {_customer_columns_sql("ranked")},
                   ranked.rnum
            FROM (
                SELECT inner_query.*, ROWNUM AS rnum
                FROM (
                    SELECT {_customer_columns_sql("c")}
                    FROM {view_name} c
                    WHERE UPPER(c.CUST_CODE) LIKE :search_code
                       OR UPPER(c.CUST_NAME) LIKE :search_name
                ) inner_query
                WHERE ROWNUM <= :max_row
            ) ranked
            WHERE ranked.rnum > :min_row
        ) paged
        ORDER BY paged.CUST_NAME
    """
    return query, params


def _fetch_route_stats(
    view_name: str, age_view: str, route: str, missing_days: int
) -> dict:
    by_route = _fetch_routes_stats(view_name, age_view, [route], missing_days)
    return by_route.get(str(route).strip(), {"all": 0, "missing": 0, "outstanding": 0})


_STATS_ROUTE_CHUNK = 40
# Longer TTL — route stats hit CUSTOMERAGEVIEW; Reports remounts often.
_STATS_CACHE_TTL_SECONDS = 300
_GLOBAL_SEARCH_MIN_CHARS = 2


def _fetch_routes_stats(
    view_name: str,
    age_view: str,
    routes: list[str],
    missing_days: int,
) -> dict[str, dict]:
    """Aggregate all / missing / outstanding counts grouped by route."""
    cleaned = [str(r).strip() for r in routes if str(r).strip()]
    if not cleaned:
        return {}

    cache_key = (
        f"customer_stats:{view_name}:{age_view}:{missing_days}:"
        + ",".join(sorted(cleaned))
    )
    cached = cache_get(cache_key)
    if isinstance(cached, dict):
        return cached

    result: dict[str, dict] = {
        route: {"all": 0, "missing": 0, "outstanding": 0} for route in cleaned
    }

    # Chunk large route lists so Oracle bind/plan stays predictable.
    for start in range(0, len(cleaned), _STATS_ROUTE_CHUNK):
        chunk = cleaned[start : start + _STATS_ROUTE_CHUNK]
        params: dict = {"missing_threshold": _missing_threshold(missing_days)}
        route_binds: list[str] = []
        for i, route in enumerate(chunk):
            key = f"route_{i}"
            route_binds.append(f":{key}")
            params[key] = _bind_route(route)

        # Route-scoped age join + equality keeps COUNT DISTINCT cheap.
        query = f"""
            SELECT
                TO_CHAR(c.ROUTE) AS route_no,
                COUNT(DISTINCT c.CUST_CODE) AS total,
                COUNT(
                    DISTINCT CASE
                        WHEN {_MISSING_CONDITION} THEN c.CUST_CODE
                        ELSE NULL
                    END
                ) AS missing,
                COUNT(
                    DISTINCT CASE
                        WHEN (
                            UPPER(c.CUSTOMERSTATUS) LIKE '%OUT%'
                            OR NVL(c.CREDIT_AMOUNT, 0) > 0
                        ) THEN c.CUST_CODE
                        ELSE NULL
                    END
                ) AS outstanding
            FROM (
                SELECT {_stats_customer_columns_sql("c")}, c.ROUTE
                FROM {view_name} c
                WHERE c.ROUTE IN ({", ".join(route_binds)})
            ) c
            {_age_join_stats(view_name, age_view, "c", route_binds)}
            GROUP BY c.ROUTE
        """
        with oracle_cursor() as cursor:
            cursor.execute(query, params)
            for row in cursor.fetchall():
                data = row_to_dict(cursor, row)
                raw_route = data.get("route_no")
                if raw_route is None:
                    continue
                route_key = str(raw_route).strip()
                try:
                    route_key = str(int(float(route_key)))
                except (TypeError, ValueError):
                    pass
                stats = {
                    "all": int(data.get("total") or 0),
                    "missing": int(data.get("missing") or 0),
                    "outstanding": int(data.get("outstanding") or 0),
                }
                result[route_key] = stats
                for original in chunk:
                    if str(_bind_route(original)) == str(_bind_route(route_key)):
                        result[original] = stats

    cache_set(cache_key, result, ttl_seconds=_STATS_CACHE_TTL_SECONDS)
    return result


def _fetch_last_purchase_row(billhdr_table: str, cust_code: str) -> dict | None:
    """
    Latest bill for a customer. Equality-only first so IDX_BILLHDR_CUST_DATE
    can be used; TRIM fallback only if the padded/legacy code misses.
    """
    cust_code = cust_code.strip()
    if not cust_code:
        return None

    def _run(where_sql: str, binds: dict) -> dict | None:
        query = f"""
            SELECT BILLNO, LOCATIONCODE, BILLDATE, NETBILLAMOUNT
            FROM (
                SELECT BILLNO,
                       LOCATIONCODE,
                       BILLDATE,
                       NETBILLAMOUNT
                FROM {billhdr_table}
                WHERE NVL(DELFLAG, 'N') <> 'Y'
                  AND {where_sql}
                ORDER BY BILLDATE DESC, BILLNO DESC
            )
            WHERE ROWNUM = 1
        """
        with oracle_cursor() as cursor:
            cursor.execute(query, binds)
            row = cursor.fetchone()
            if not row:
                return None
            return row_to_dict(cursor, row)

    bound = _bind_cust_code(cust_code)
    found = _run("CUSTOMERCODE = :cust_code", {"cust_code": bound})
    if found is not None:
        return found
    # Rare legacy padded codes — avoid OR TRIM on the hot path.
    return _run("TRIM(CUSTOMERCODE) = :cust_code", {"cust_code": cust_code})


def _normalize_bill_item_row(item: dict) -> dict:
    if item.get("itemcode") is not None:
        item["itemcode"] = str(item["itemcode"]).strip()
    if item.get("itemname") is not None:
        item["itemname"] = str(item["itemname"]).strip()
    if item.get("itemdetails") is not None:
        item["itemdetails"] = str(item["itemdetails"]).strip()
    return item


def _fetch_item_names(itemmaster_table: str, item_codes: list[str]) -> dict[str, str]:
    unique = list(dict.fromkeys(code.strip() for code in item_codes if code.strip()))
    if not unique:
        return {}

    binds = {f"c{i}": _bind_cust_code(code) for i, code in enumerate(unique)}
    in_clause = ", ".join(f":c{i}" for i in range(len(unique)))
    query = f"""
        SELECT ITEMCODE, ITEMNAME
        FROM {itemmaster_table}
        WHERE ITEMCODE IN ({in_clause})
    """

    names: dict[str, str] = {}
    with oracle_cursor() as cursor:
        cursor.execute(query, binds)
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            code = str(item.get("itemcode") or "").strip()
            name = str(item.get("itemname") or "").strip()
            if code and name:
                names[code] = name
    return names


def _enrich_missing_item_names(
    itemmaster_table: str,
    items: list[dict],
) -> list[dict]:
    missing_codes = [
        item["itemcode"]
        for item in items
        if item.get("itemcode") and not item.get("itemname")
    ]
    if not missing_codes:
        return items

    names = _fetch_item_names(itemmaster_table, missing_codes)
    if not names:
        return items

    for item in items:
        code = item.get("itemcode") or ""
        if code and not item.get("itemname") and code in names:
            item["itemname"] = names[code]
    return items


def _fetch_bill_items_fast(
    billdtl_table: str,
    itemmaster_table: str,
    *,
    billno: str,
    location: str,
    offset: int,
    limit: int,
) -> list[dict]:
    billno = billno.strip()
    location = location.strip()

    query = f"""
        SELECT d.SLNO,
               d.ITEMCODE,
               NULLIF(TRIM(d.ITEMDETAILS1), '') AS ITEMNAME,
               d.ITEMDETAILS1 AS ITEMDETAILS,
               d.QUANTITY,
               d.RATE,
               d.UNITOFMEASUREMENT
        FROM {billdtl_table} d
        WHERE d.BILLNO = :billno
    """
    params: dict = {"billno": _bind_maybe_number(billno)}

    if location:
        query += " AND d.LOCATIONCODE = :location"
        params["location"] = _bind_maybe_number(location)

    query += " ORDER BY d.SLNO"

    if offset == 0:
        paginated_query = f"""
            SELECT *
            FROM (
                {query}
            )
            WHERE ROWNUM <= :limit
        """
        paginated_params = {**params, "limit": limit}
    else:
        paginated_query = f"""
            SELECT *
            FROM (
                SELECT inner_query.*, ROWNUM AS rnum
                FROM (
                    {query}
                ) inner_query
                WHERE ROWNUM <= :max_row
            )
            WHERE rnum > :min_row
        """
        paginated_params = {
            **params,
            "max_row": offset + limit,
            "min_row": offset,
        }

    with oracle_cursor() as cursor:
        cursor.execute(paginated_query, paginated_params)
        rows = cursor.fetchall()
        data = []
        for row in rows:
            item = _normalize_bill_item_row(row_to_dict(cursor, row))
            item.pop("rnum", None)
            data.append(item)

    return _enrich_missing_item_names(itemmaster_table, data)


@customers_bp.get("/last-order")
def customer_last_order():
    cust_code = request.args.get("cust_code", "").strip()
    if not cust_code:
        return jsonify({"error": "cust_code is required"}), 400

    items_limit = parse_int(
        request.args.get("items_limit", BILL_ITEMS_PAGE_SIZE),
        BILL_ITEMS_PAGE_SIZE,
        min_value=0,
        max_value=MAX_BILL_ITEMS_PAGE_SIZE,
    )
    items_offset = parse_int(
        request.args.get("items_offset", 0),
        0,
        min_value=0,
        max_value=DEFAULT_MAX_OFFSET,
    )

    billhdr_table = current_app.config["ORACLE_BILLHDR_TABLE"]
    billdtl_table = current_app.config["ORACLE_BILLDTL_TABLE"]
    itemmaster_table = current_app.config["ORACLE_ITEMMASTER_TABLE"]

    billno_param = request.args.get("billno", "").strip()
    location_param = request.args.get("location", "").strip()

    if billno_param:
        purchase_row = {
            "billno": billno_param,
            "locationcode": location_param,
            "billdate": request.args.get("billdate"),
            "netbillamount": request.args.get("netbillamount"),
        }
    else:
        purchase_row = _fetch_last_purchase_row(billhdr_table, cust_code)
        if not purchase_row:
            return jsonify(
                {
                    "cust_code": cust_code,
                    "last_purchase": None,
                    "items_offset": items_offset,
                    "items_limit": items_limit,
                    "has_more_items": False,
                    "items": [],
                }
            )

    billno = str(purchase_row.get("billno") or "").strip()
    location = str(purchase_row.get("locationcode") or "").strip()
    items = []
    has_more = False

    if items_limit > 0 and billno:
        items = _fetch_bill_items_fast(
            billdtl_table,
            itemmaster_table,
            billno=billno,
            location=location,
            offset=items_offset,
            limit=items_limit,
        )
        has_more = len(items) >= items_limit

    return jsonify(
        {
            "cust_code": cust_code,
            "last_purchase": {
                "billno": purchase_row.get("billno"),
                "locationcode": purchase_row.get("locationcode"),
                "billdate": purchase_row.get("billdate"),
                "netbillamount": purchase_row.get("netbillamount"),
            },
            "items_offset": items_offset,
            "items_limit": items_limit,
            "has_more_items": has_more,
            "items": items,
        }
    )


@customers_bp.get("/stats")
@limiter.limit("60 per minute")
def customer_stats():
    route = request.args.get("route", "").strip()
    routes_param = request.args.get("routes", "").strip()
    view_name = current_app.config["ORACLE_CUSTOMERS_VIEW"]
    age_view = current_app.config["ORACLE_CUSTOMER_AGE_VIEW"]
    default_missing_days = current_app.config["MISSING_DAYS"]
    missing_days = max(int(request.args.get("missing_days", default_missing_days)), 0)

    # Batch: ?routes=1,2,3 — one grouped query for report dashboards.
    if routes_param:
        routes = [part.strip() for part in routes_param.split(",") if part.strip()]
        if not routes:
            return jsonify({"error": "routes is required"}), 400
        if len(routes) > 200:
            return jsonify({"error": "Too many routes (max 200)"}), 400
        by_route = _fetch_routes_stats(view_name, age_view, routes, missing_days)
        return jsonify(
            {
                "missing_days": missing_days,
                "routes": [
                    {"route": route_no, "stats": stats}
                    for route_no, stats in by_route.items()
                ],
            }
        )

    if not route:
        return jsonify({"error": "route is required"}), 400

    return jsonify(
        {
            "route": route,
            "missing_days": missing_days,
            "stats": _fetch_route_stats(view_name, age_view, route, missing_days),
        }
    )


@customers_bp.get("/last-purchase")
def customer_last_purchase():
    cust_code = request.args.get("cust_code", "").strip()
    if not cust_code:
        return jsonify({"error": "cust_code is required"}), 400

    billhdr_table = current_app.config["ORACLE_BILLHDR_TABLE"]
    purchase_row = _fetch_last_purchase_row(billhdr_table, cust_code)
    if not purchase_row:
        return jsonify(
            {
                "cust_code": cust_code,
                "last_purchase": None,
            }
        )

    return jsonify(
        {
            "cust_code": cust_code,
            "last_purchase": {
                "billno": purchase_row.get("billno"),
                "locationcode": purchase_row.get("locationcode"),
                "billdate": purchase_row.get("billdate"),
                "netbillamount": purchase_row.get("netbillamount"),
            },
        }
    )


@customers_bp.get("/contact-info")
def list_contact_info():
    """List prospects created in CRGS_CONTACTINFO (newest first, paginated)."""
    from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql

    table_name = _contactinfo_table()
    status_filter = str(request.args.get("status", "")).strip()
    flag_filter = str(request.args.get("flag", "")).strip().upper()[:1]
    search = str(request.args.get("search", "")).strip()
    limit, offset = parse_limit_offset(default_limit=50, max_limit=200)

    conditions: list[str] = []
    params: dict = {}
    if status_filter:
        normalized = _normalize_contact_status(status_filter)
        if normalized:
            conditions.append("UPPER(TRIM(STATUS)) = :status")
            params["status"] = normalized.upper()
    if flag_filter in ("N", "E"):
        conditions.append("UPPER(TRIM(FLAG)) = :flag")
        params["flag"] = flag_filter
    if search:
        conditions.append(
            "("
            "UPPER(CUSTOMERNAME) LIKE :search OR "
            "UPPER(SHOPNAME) LIKE :search OR "
            "UPPER(NVL(CONTACTNUMBER, '')) LIKE :search OR "
            "UPPER(NVL(LOCATION, '')) LIKE :search OR "
            "UPPER(NVL(ADDRESS, '')) LIKE :search"
            ")"
        )
        params["search"] = f"%{search.upper()}%"

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""
    columns_sql = (
        "CUSTOMERCODE, CUSTOMERNAME, SHOPNAME, LOCATION, ADDRESS, "
        "BUSINESSTYPE, EXPECTEDAMOUNT, PRODUCTS, REMARKS, STATUS, "
        "CONTACTNUMBER, FLAG"
    )
    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY CUSTOMERCODE DESC
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        rows = []
        for item in fetched:
            rows.append(
                {
                    "customerCode": str(item.get("customercode") or "").strip(),
                    "customerName": str(item.get("customername") or "").strip(),
                    "shopName": str(item.get("shopname") or "").strip(),
                    "contactNumber": str(item.get("contactnumber") or "").strip(),
                    "location": str(item.get("location") or "").strip(),
                    "address": str(item.get("address") or "").strip(),
                    "businessType": str(item.get("businesstype") or "").strip(),
                    "expectedAmount": _to_float(item.get("expectedamount")),
                    "products": str(item.get("products") or "").strip(),
                    "remarks": str(item.get("remarks") or "").strip(),
                    "status": str(item.get("status") or "").strip(),
                    "flag": str(item.get("flag") or "").strip(),
                }
            )

    return jsonify(
        {
            "count": len(rows),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "items": rows,
        }
    )


@customers_bp.post("/contact-info")
def create_contact_info():
    """
    Insert into CRGS_CONTACTINFO.

    FLAG:
      - N = new prospect (default) — CUSTOMERCODE auto-generated
      - E = edit existing customer — CUSTOMERCODE required (existing code)
    """
    payload = request.get_json(silent=True) or {}

    customer_name = str(payload.get("customerName", "")).strip()
    shop_name = str(payload.get("shopName", "")).strip()
    contact_number = str(payload.get("contactNumber", "")).strip()
    location = str(payload.get("location", "")).strip()
    # Accept common key variants from clients.
    address = str(
        payload.get("address")
        or payload.get("Address")
        or payload.get("ADDRESS")
        or ""
    ).strip()
    business_type = str(payload.get("businessType", "")).strip()
    products = str(payload.get("products", "")).strip()
    remarks = str(payload.get("remarks", "")).strip()
    status = _normalize_contact_status(payload.get("status", "Prospect"))
    expected_amount = _to_float(payload.get("expectedAmount"), default=None)
    flag = str(payload.get("flag", "") or "N").strip().upper()[:1] or "N"
    requested_code = str(
        payload.get("customerCode") or payload.get("custCode") or ""
    ).strip()

    if flag not in ("N", "E"):
        return jsonify({"error": "Flag must be N (new) or E (edit)"}), 400

    if not customer_name:
        return jsonify({"error": "Customer name is required"}), 400

    # Edits only require name/mobile/address; shop defaults to customer name.
    if flag == "E":
        if not requested_code:
            return jsonify({"error": "Customer code is required for edit (FLAG=E)"}), 400
        if not shop_name:
            shop_name = customer_name
        if status is None:
            status = "Prospect"
    else:
        if not shop_name:
            return jsonify({"error": "Shop name is required"}), 400
        if status is None:
            return jsonify({"error": "Status is required"}), 400

    if expected_amount is not None and expected_amount < 0:
        return jsonify({"error": "Expected amount must be zero or greater"}), 400

    if len(customer_name) > 100:
        return jsonify({"error": "Customer name must be 100 characters or fewer"}), 400
    if len(shop_name) > 100:
        return jsonify({"error": "Shop name must be 100 characters or fewer"}), 400
    if len(contact_number) > 20:
        return jsonify({"error": "Contact number must be 20 characters or fewer"}), 400
    if len(requested_code) > 20:
        return jsonify({"error": "Customer code must be 20 characters or fewer"}), 400
    if len(location) > 255:
        location = location[:255]
    if len(address) > 500:
        address = address[:500]
    if len(business_type) > 50:
        business_type = business_type[:50]
    if len(products) > 500:
        products = products[:500]
    if len(remarks) > 500:
        remarks = remarks[:500]
    if len(status) > 20:
        status = status[:20]

    table_name = _contactinfo_table()
    current_app.logger.info(
        "contact-info insert flag=%s code=%s address_len=%s",
        flag,
        requested_code or "(auto)",
        len(address),
    )

    conn = get_connection()
    with oracle_cursor() as cursor:
        if flag == "E":
            customer_code = requested_code
        else:
            customer_code = _next_customer_code(cursor, table_name)

        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (
                    CUSTOMERCODE,
                    CUSTOMERNAME,
                    SHOPNAME,
                    LOCATION,
                    ADDRESS,
                    BUSINESSTYPE,
                    EXPECTEDAMOUNT,
                    PRODUCTS,
                    REMARKS,
                    STATUS,
                    CONTACTNUMBER,
                    FLAG
                )
            VALUES
                (
                    :customercode,
                    :customername,
                    :shopname,
                    :location,
                    :addr,
                    :businesstype,
                    :expectedamount,
                    :products,
                    :remarks,
                    :status,
                    :contactnumber,
                    :flag
                )
            """,
            {
                "customercode": customer_code,
                "customername": customer_name,
                "shopname": shop_name,
                "location": location or None,
                "addr": address or None,
                "businesstype": business_type or None,
                "expectedamount": expected_amount,
                "products": products or None,
                "remarks": remarks or None,
                "status": status,
                "contactnumber": contact_number or None,
                "flag": flag,
            },
        )
        if flag == "N":
            refresh_new_acquisition_achieved(
                cursor,
                customer_targets_table=_customer_targets_table(),
                contactinfo_table=table_name,
            )

        conn.commit()

        # Read back so clients/DB viewers see the persisted ADDRESS value.
        cursor.execute(
            f"""
            SELECT ADDRESS, FLAG
            FROM {table_name}
            WHERE TRIM(CUSTOMERCODE) = :customercode
              AND TRIM(FLAG) = :flag
            ORDER BY ROWID DESC
            """,
            {"customercode": str(customer_code), "flag": flag},
        )
        saved = cursor.fetchone()
        saved_address = (
            str(saved[0]).strip() if saved and saved[0] is not None else ""
        )
        saved_flag = str(saved[1]).strip() if saved and saved[1] is not None else flag

    return (
        jsonify(
            {
                "customerCode": customer_code,
                "customerName": customer_name,
                "shopName": shop_name,
                "contactNumber": contact_number,
                "location": location,
                "address": saved_address or address,
                "businessType": business_type,
                "expectedAmount": expected_amount,
                "products": products,
                "remarks": remarks,
                "status": status,
                "flag": saved_flag or flag,
            }
        ),
        201,
    )


@customers_bp.put("/<cust_code>")
def update_customer(cust_code: str):
    """Update editable customer fields on the CUSTOMERS table/view."""
    cust_code = str(cust_code or "").strip()
    if not cust_code:
        return jsonify({"error": "Customer code is required"}), 400

    payload = request.get_json(silent=True) or {}

    updates: dict[str, object] = {}
    field_map = (
        ("customerName", "CUST_NAME", 200),
        ("mobile", "MOBILE", 30),
        ("wpno", "WPNO", 30),
        ("address", "ADDRESS", 500),
        ("locationMap", "LOCATIONMAP", 255),
        ("type", "TYPE", 50),
    )

    for json_key, column, max_len in field_map:
        if json_key not in payload:
            continue
        raw = payload.get(json_key)
        value = "" if raw is None else str(raw).strip()
        if len(value) > max_len:
            return (
                jsonify(
                    {
                        "error": f"{json_key} must be {max_len} characters or fewer",
                    }
                ),
                400,
            )
        updates[column] = value or None

    if not updates:
        return jsonify({"error": "No editable fields provided"}), 400

    view_name = current_app.config["ORACLE_CUSTOMERS_VIEW"]
    set_clause = ", ".join(f"{col} = :{col}" for col in updates)
    bind = {**updates, "cust_code": cust_code}

    try:
        with oracle_cursor() as cursor:
            cursor.execute(
                f"""
                UPDATE {view_name}
                SET {set_clause}
                WHERE TRIM(CUST_CODE) = :cust_code
                """,
                bind,
            )
            if cursor.rowcount == 0:
                return jsonify({"error": "Customer not found"}), 404

            cursor.execute(
                f"""
                SELECT {_customer_columns_sql("c")}
                FROM {view_name} c
                WHERE TRIM(c.CUST_CODE) = :cust_code
                """,
                {"cust_code": cust_code},
            )
            row = cursor.fetchone()
            if row is None:
                get_connection().rollback()
                return jsonify({"error": "Customer not found after update"}), 404
            data = row_to_dict(cursor, row)
            get_connection().commit()
    except Exception:  # noqa: BLE001
        try:
            get_connection().rollback()
        except Exception:  # noqa: BLE001
            pass
        return jsonify({"error": "Failed to update customer"}), 500

    return jsonify(data)


@customers_bp.get("")
@limiter.limit("120 per minute")
def list_customers():
    view_name = current_app.config["ORACLE_CUSTOMERS_VIEW"]
    age_view = current_app.config["ORACLE_CUSTOMER_AGE_VIEW"]
    default_missing_days = current_app.config["MISSING_DAYS"]
    route = request.args.get("route", "").strip()
    search = request.args.get("search", "").strip()
    priority = request.args.get("priority", "").strip()
    codes_param = request.args.get("codes", "").strip()
    missing_days = parse_int(
        request.args.get("missing_days", default_missing_days),
        default_missing_days,
        min_value=0,
        max_value=3650,
    )
    limit, offset = parse_limit_offset(
        default_limit=DEFAULT_PAGE_SIZE,
        max_limit=MAX_PAGE_SIZE,
        max_offset=DEFAULT_MAX_OFFSET,
    )

    codes = [
        part.strip()
        for part in codes_param.replace(";", ",").split(",")
        if part.strip()
    ]
    # Cap IN-list size for Oracle bind safety.
    codes = codes[:100]

    # Unscoped list / priority without a route scans the live CUSTOMERS master.
    if not codes and not route:
        if priority:
            return jsonify(
                {"error": "route is required when using priority filters"}
            ), 400
        if len(search) < _GLOBAL_SEARCH_MIN_CHARS:
            return jsonify(
                {
                    "error": (
                        "route, codes, or search "
                        f"(min {_GLOBAL_SEARCH_MIN_CHARS} characters) is required"
                    )
                }
            ), 400

    # Fetch one extra row so has_more is exact without a COUNT(*) scan.
    fetch_limit = limit + 1

    if codes:
        conditions, params = _build_customer_filters(
            route="",
            search=search,
            priority="",
            codes=codes,
        )
        params["max_row"] = offset + fetch_limit
        params["min_row"] = offset
        where_sql = (" WHERE " + " AND ".join(conditions)) if conditions else ""
        paginated_query = f"""
            SELECT {_customer_columns_sql("paged")},
                   NULL AS LAST_PURCHASE_DATE,
                   NULL AS LAST_PURCHASE_AMOUNT,
                   NULL AS LAST_PURCHASE_BILLNO,
                   NULL AS LAST_PURCHASE_LOCATION,
                   NULL AS DAYS_SINCE_PURCHASE,
                   0 AS IS_MISSING
            FROM (
                SELECT {_customer_columns_sql("ranked")},
                       ranked.rnum
                FROM (
                    SELECT inner_query.*, ROWNUM AS rnum
                    FROM (
                        SELECT {_customer_columns_sql("c")}
                        FROM {view_name} c
                        {where_sql}
                        ORDER BY c.CUST_NAME
                    ) inner_query
                    WHERE ROWNUM <= :max_row
                ) ranked
                WHERE ranked.rnum > :min_row
            ) paged
            ORDER BY paged.rnum
        """
        paginated_params = params
    elif not route and search:
        paginated_query, paginated_params = _build_global_search_query(
            view_name,
            search=search,
            offset=offset,
            limit=fetch_limit,
        )
    else:
        paginated_query, paginated_params = _build_list_query(
            view_name,
            age_view,
            route=route,
            search=search,
            priority=priority,
            missing_days=missing_days,
            offset=offset,
            limit=fetch_limit,
        )

    with oracle_cursor() as cursor:
        cursor.execute(paginated_query, paginated_params)
        rows = cursor.fetchall()
        data = []
        for row in rows:
            item = row_to_dict(cursor, row)
            item.pop("rnum", None)
            if "is_missing" in item:
                item["is_missing"] = bool(item["is_missing"])
            if item.get("days_since_purchase") is not None:
                item["days_since_purchase"] = int(item["days_since_purchase"])
            data.append(item)

    has_more = len(data) > limit
    if has_more:
        data = data[:limit]

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "missing_days": missing_days,
            "customers": data,
        }
    )


@customers_bp.get("/bill-items")
def list_bill_items():
    billno = request.args.get("billno", "").strip()
    location = request.args.get("location", "").strip()
    limit, offset = parse_limit_offset(
        default_limit=BILL_ITEMS_PAGE_SIZE,
        max_limit=MAX_BILL_ITEMS_PAGE_SIZE,
        max_offset=DEFAULT_MAX_OFFSET,
    )

    if not billno:
        return jsonify({"error": "billno is required"}), 400

    billdtl_table = current_app.config["ORACLE_BILLDTL_TABLE"]
    itemmaster_table = current_app.config["ORACLE_ITEMMASTER_TABLE"]
    data = _fetch_bill_items_fast(
        billdtl_table,
        itemmaster_table,
        billno=billno,
        location=location,
        offset=offset,
        limit=limit,
    )

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": len(data) >= limit,
            "billno": billno,
            "items": data,
        }
    )
