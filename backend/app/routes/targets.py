from datetime import datetime

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.routes.auth import limiter
from app.security import is_admin, require_admin, resolve_employee_scope
from app.services.customer_target_achievement import (
    count_new_customers_flag_n,
    refresh_new_acquisition_achieved,
)
from app.services.sales_target_achievement import refresh_sales_target_achieved

targets_bp = Blueprint("targets", __name__)

_DEFAULT_LIMIT = 200
_MAX_LIMIT = 500


def _wants_refresh_achieved() -> bool:
    # Expensive ACHIEVED rebuild — admin only.
    if not is_admin():
        return False
    return request.args.get("refreshAchieved", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )


def _scoped_employee_arg() -> tuple[str | None, tuple | None]:
    return resolve_employee_scope(request.args.get("employeeCode", "").strip())


def _order_hdr_table():
    return current_app.config["ORACLE_ORDERHDR_TABLE"]


def _contactinfo_table():
    return current_app.config["ORACLE_CONTACTINFO_TABLE"]


SALE_TARGET_COLUMNS = (
    "EMPLOYEECODE",
    "PERIOD",
    "TARGET",
    "ACHIEVED",
    "ROUTE",
    "DUEDATE",
)

PRODUCT_TARGET_COLUMNS = (
    "EMPLOYEECODE",
    "PRODUCTS",
    "TYPE",
    "TARGET",
    "ACHIEVED",
    "ROUTE",
)

PRODUCT_TARGET_TYPES = {
    "quantity",
    "volume",
    "new_promotion",
    "replacement",
    "own_products",
}

CUSTOMER_TARGET_COLUMNS = (
    "EMPLOYEECODE",
    "TARGETTYPE",
    "TARGET",
    "ACHIEVED",
    "TARGETAMOUNT",
    "PERIOD",
    "ROUTE",
)

CUSTOMER_TARGET_TYPES = {
    "new_acquisition",
    "missing_recovery",
    "outstanding_collection",
    "purchase_limit",
}

PERIOD_TO_DB = {
    "daily": "D",
    "weekly": "W",
    "monthly": "M",
}

DB_TO_PERIOD = {
    "D": "daily",
    "W": "weekly",
    "M": "monthly",
    "DAILY": "daily",
    "WEEKLY": "weekly",
    "MONTHLY": "monthly",
}


def _table_name():
    return current_app.config["ORACLE_SALE_TARGETS_TABLE"]


def _product_table_name():
    return current_app.config["ORACLE_PRODUCT_TARGETS_TABLE"]


def _customer_table_name():
    return current_app.config["ORACLE_CUSTOMER_TARGETS_TABLE"]


def _normalize_period(value: str) -> str | None:
    text = str(value or "").strip().lower()
    if text in PERIOD_TO_DB:
        return PERIOD_TO_DB[text]
    upper = text.upper()
    if upper in DB_TO_PERIOD:
        return upper if len(upper) == 1 else PERIOD_TO_DB.get(DB_TO_PERIOD[upper])
    return None


def _period_from_db(value) -> str:
    if value is None:
        return "monthly"
    text = str(value).strip().upper()
    return DB_TO_PERIOD.get(text, "monthly")


def _parse_iso_date(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d")
    except ValueError:
        return None


def _normalize_product_label(value: str) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    if " — " in text:
        return text.split(" — ", 1)[0].strip()
    if " - " in text:
        return text.split(" - ", 1)[0].strip()
    return text


def _format_products_column(values) -> str:
    if values is None:
        return ""
    if isinstance(values, list):
        parts = [_normalize_product_label(item) for item in values]
    else:
        parts = [_normalize_product_label(part) for part in str(values).split(",")]
    return ",".join(part for part in parts if part)


def _parse_products_column(value) -> list[str]:
    text = str(value or "").strip()
    if not text:
        return []
    return [part.strip() for part in text.split(",") if part.strip()]


def _fetch_item_details(
    itemmaster_table: str, item_codes: list[str]
) -> dict[str, dict]:
    unique = list(dict.fromkeys(code.strip() for code in item_codes if code.strip()))
    if not unique:
        return {}

    binds = {f"c{i}": code for i, code in enumerate(unique)}
    in_clause = ", ".join(f":c{i}" for i in range(len(unique)))
    query = f"""
        SELECT ITEMCODE, ITEMNAME, BASEUOM, RETAILPRICE, CURRENTSTOCK, QUANTITYLIMIT
        FROM {itemmaster_table}
        WHERE TO_CHAR(ITEMCODE) IN ({in_clause})
    """

    details: dict[str, dict] = {}
    with oracle_cursor() as cursor:
        cursor.execute(query, binds)
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            code = str(item.get("itemcode") or "").strip()
            if not code:
                continue
            name = str(item.get("itemname") or "").strip()
            base_uom = str(item.get("baseuom") or "").strip()
            retail_raw = item.get("retailprice")
            try:
                retail_price = float(retail_raw) if retail_raw is not None else 0.0
            except (TypeError, ValueError):
                retail_price = 0.0
            try:
                current_stock = (
                    float(item.get("currentstock"))
                    if item.get("currentstock") is not None
                    else 0.0
                )
            except (TypeError, ValueError):
                current_stock = 0.0
            try:
                quantity_limit = (
                    float(item.get("quantitylimit"))
                    if item.get("quantitylimit") is not None
                    else 0.0
                )
            except (TypeError, ValueError):
                quantity_limit = 0.0
            details[code] = {
                "name": name or code,
                "baseUom": base_uom,
                "retailPrice": retail_price,
                "currentStock": current_stock,
                "quantityLimit": quantity_limit,
            }
    return details


def _fetch_item_names(itemmaster_table: str, item_codes: list[str]) -> dict[str, str]:
    details = _fetch_item_details(itemmaster_table, item_codes)
    return {code: info["name"] for code, info in details.items()}


def _resolve_product_names(codes: list[str], names_map: dict[str, str]) -> list[str]:
    return [names_map.get(code, code) for code in codes]


def _resolve_product_base_uoms(codes: list[str], details_map: dict[str, dict]) -> list[str]:
    return [str(details_map.get(code, {}).get("baseUom") or "") for code in codes]


def _resolve_product_retail_prices(
    codes: list[str], details_map: dict[str, dict]
) -> list[float]:
    return [
        float(details_map.get(code, {}).get("retailPrice") or 0)
        for code in codes
    ]


def _resolve_product_current_stocks(
    codes: list[str], details_map: dict[str, dict]
) -> list[float]:
    return [
        float(details_map.get(code, {}).get("currentStock") or 0)
        for code in codes
    ]


def _resolve_product_quantity_limits(
    codes: list[str], details_map: dict[str, dict]
) -> list[float]:
    return [
        float(details_map.get(code, {}).get("quantityLimit") or 0)
        for code in codes
    ]


def _enrich_product_targets(data: list[dict], itemmaster_table: str) -> None:
    all_codes = [code for item in data for code in item.get("products", [])]
    details_map = _fetch_item_details(itemmaster_table, all_codes)
    names_map = {code: info["name"] for code, info in details_map.items()}
    for item in data:
        codes = item.get("products", [])
        item["productNames"] = _resolve_product_names(codes, names_map)
        item["baseUoms"] = _resolve_product_base_uoms(codes, details_map)
        item["retailPrices"] = _resolve_product_retail_prices(codes, details_map)
        item["currentStocks"] = _resolve_product_current_stocks(codes, details_map)
        item["quantityLimits"] = _resolve_product_quantity_limits(
            codes, details_map
        )


def _normalize_product_type(value: str) -> str | None:
    text = str(value or "").strip().lower()
    if text in PRODUCT_TARGET_TYPES:
        return text
    return None


def _normalize_customer_type(value: str) -> str | None:
    text = str(value or "").strip().lower()
    if text in CUSTOMER_TARGET_TYPES:
        return text
    return None


def _serialize_product_target(row: dict) -> dict:
    route = row.get("route")
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "products": _parse_products_column(row.get("products")),
        "type": str(row.get("type") or "").strip().lower(),
        "targetValue": float(row.get("target") or 0),
        "achievedValue": float(row.get("achieved") or 0),
        "routeNo": str(route).strip() if route is not None else "",
    }


def _serialize_customer_target(row: dict, *, new_customer_count: int | None = None) -> dict:
    route = row.get("route")
    target_type = str(row.get("targettype") or "").strip().lower()
    achieved = float(row.get("achieved") or 0)
    # Live total of add-customer requests (FLAG=N) for new acquisition targets.
    if target_type == "new_acquisition" and new_customer_count is not None:
        achieved = float(new_customer_count)
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "type": target_type,
        "targetCount": float(row.get("target") or 0),
        "achievedCount": achieved,
        "targetAmount": float(row.get("targetamount") or 0),
        "period": _period_from_db(row.get("period")),
        "routeNo": str(route).strip() if route is not None else "",
    }


def _serialize_target(row: dict) -> dict:
    route = row.get("route")
    target_amount = float(row.get("target") or 0)
    achieved_amount = float(row.get("achieved") or 0)
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "period": _period_from_db(row.get("period")),
        "targetAmount": target_amount,
        "achievedAmount": achieved_amount,
        "remainingAmount": round(target_amount - achieved_amount, 2),
        "routeNo": str(route).strip() if route is not None else "",
        "dueDate": row.get("duedate") or "",
    }


def _build_target_filters(
    employee_code: str = "",
    period: str | None = None,
    *,
    period_column: str = "PERIOD",
    employee_column: str = "EMPLOYEECODE",
) -> tuple[list[str], dict]:
    conditions: list[str] = []
    params: dict = {}

    if employee_code:
        # CRGS_* EMPLOYEECODE columns are VARCHAR2 — avoid TO_CHAR (blocks indexes).
        conditions.append(f"TRIM({employee_column}) = :employeecode")
        params["employeecode"] = employee_code

    if period:
        conditions.append(f"{period_column} = :period")
        params["period"] = period

    return conditions, params


@targets_bp.get("/sales")
@limiter.limit("90 per minute")
def list_sales_targets():
    """List sales targets (paginated)."""
    table_name = _table_name()
    columns_sql = ", ".join(SALE_TARGET_COLUMNS)
    employee_code, scope_err = _scoped_employee_arg()
    if scope_err is not None:
        return scope_err
    period = _normalize_period(request.args.get("period", ""))
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )
    conditions, params = _build_target_filters(employee_code or "", period)
    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY DUEDATE DESC, EMPLOYEECODE, ROUTE
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        data = [_serialize_target(row) for row in fetched]

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "targets": data,
        }
    )


@targets_bp.post("/sales")
@require_admin
def create_sales_target():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    period = _normalize_period(payload.get("period", ""))
    target_raw = payload.get("targetAmount")
    due_date = _parse_iso_date(payload.get("dueDate", ""))

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if not period:
        return jsonify({"error": "Period must be daily, weekly, or monthly"}), 400
    if target_raw in (None, ""):
        return jsonify({"error": "Target amount is required"}), 400
    if due_date is None:
        return jsonify({"error": "Due date is required (YYYY-MM-DD)"}), 400

    try:
        target_amount = float(target_raw)
    except (TypeError, ValueError):
        return jsonify({"error": "Target amount must be a number"}), 400

    # ACHIEVED is server-computed from orders — ignore client values.
    achieved_amount = 0.0

    table_name = _table_name()
    due_iso = due_date.date().isoformat()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (EMPLOYEECODE, PERIOD, TARGET, ACHIEVED, ROUTE, DUEDATE)
            VALUES
                (:employeecode, :period, :target, :achieved, :route, :duedate)
            """,
            {
                "employeecode": employee_code,
                "period": period,
                "target": target_amount,
                "achieved": achieved_amount,
                "route": route_no,
                "duedate": due_date,
            },
        )
        updated = refresh_sales_target_achieved(
            cursor,
            sale_targets_table=table_name,
            order_hdr_table=_order_hdr_table(),
            employee_code=employee_code,
        )
        get_connection().commit()

    matched = next(
        (
            row
            for row in updated
            if row.get("routeNo") == route_no
            and str(row.get("dueDate", ""))[:10] == due_iso
            and str(row.get("period", "")).strip().upper() == period
        ),
        None,
    )
    if matched is not None:
        achieved_amount = float(matched.get("achievedAmount") or 0)

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "routeNo": route_no,
                "period": _period_from_db(period),
                "targetAmount": target_amount,
                "achievedAmount": achieved_amount,
                "remainingAmount": round(target_amount - achieved_amount, 2),
                "dueDate": due_iso,
            }
        ),
        201,
    )


@targets_bp.post("/sales/recalculate")
@require_admin
def recalculate_sales_target_achieved():
    """Rebuild ACHIEVED from order TOTALAMOUNT (optional employeeCode filter)."""
    payload = request.get_json(silent=True) or {}
    employee_code, scope_err = resolve_employee_scope(
        str(
            payload.get("employeeCode") or request.args.get("employeeCode") or ""
        ).strip()
    )
    if scope_err is not None:
        return scope_err

    with oracle_cursor() as cursor:
        updated = refresh_sales_target_achieved(
            cursor,
            sale_targets_table=_table_name(),
            order_hdr_table=_order_hdr_table(),
            employee_code=employee_code or None,
        )
        get_connection().commit()

    for row in updated:
        row["period"] = _period_from_db(row.get("period"))

    return jsonify({"count": len(updated), "targets": updated})


@targets_bp.delete("/sales")
@require_admin
def delete_sales_target():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    period = _normalize_period(payload.get("period", ""))
    due_date = _parse_iso_date(payload.get("dueDate", ""))

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if not period:
        return jsonify({"error": "Period must be daily, weekly, or monthly"}), 400
    if due_date is None:
        return jsonify({"error": "Due date is required (YYYY-MM-DD)"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            DELETE FROM {table_name}
            WHERE TRIM(EMPLOYEECODE) = :employeecode
              AND TRIM(ROUTE) = :route
              AND PERIOD = :period
              AND TRUNC(DUEDATE) = TRUNC(:duedate)
            """,
            {
                "employeecode": employee_code,
                "route": route_no,
                "period": period,
                "duedate": due_date,
            },
        )
        deleted = cursor.rowcount or 0
        get_connection().commit()

    if deleted == 0:
        return jsonify({"error": "Sales target not found"}), 404

    return jsonify({"deleted": deleted})


@targets_bp.get("/products")
@limiter.limit("90 per minute")
def list_product_targets():
    """List product targets (paginated)."""
    table_name = _product_table_name()
    columns_sql = ", ".join(PRODUCT_TARGET_COLUMNS)
    employee_code, scope_err = _scoped_employee_arg()
    if scope_err is not None:
        return scope_err
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )
    conditions, params = _build_target_filters(employee_code or "", period=None)
    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY EMPLOYEECODE, ROUTE, TYPE, PRODUCTS
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        data = [_serialize_product_target(row) for row in fetched]

    itemmaster_table = current_app.config["ORACLE_ITEMMASTER_TABLE"]
    _enrich_product_targets(data, itemmaster_table)

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "targets": data,
        }
    )


@targets_bp.post("/products")
@require_admin
def create_product_target():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    target_type = _normalize_product_type(payload.get("type", ""))
    target_raw = payload.get("targetValue")
    products_raw = payload.get("products")
    if products_raw is None:
        products_raw = payload.get("productNames")

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if not target_type:
        return jsonify({"error": "Invalid target type"}), 400
    if target_raw in (None, ""):
        return jsonify({"error": "Target value is required"}), 400

    products = _format_products_column(products_raw)
    if not products:
        return jsonify({"error": "At least one product is required"}), 400
    if len(products) > 100:
        return jsonify({"error": "Products value exceeds 100 characters"}), 400

    try:
        target_value = float(target_raw)
    except (TypeError, ValueError):
        return jsonify({"error": "Target value must be a number"}), 400

    table_name = _product_table_name()
    # ACHIEVED is not client-writable.
    achieved_value = 0.0

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (EMPLOYEECODE, PRODUCTS, TYPE, TARGET, ACHIEVED, ROUTE)
            VALUES
                (:employeecode, :products, :type, :target, :achieved, :route)
            """,
            {
                "employeecode": employee_code,
                "products": products,
                "type": target_type,
                "target": target_value,
                "achieved": achieved_value,
                "route": route_no,
            },
        )
        get_connection().commit()

    itemmaster_table = current_app.config["ORACLE_ITEMMASTER_TABLE"]
    product_codes = _parse_products_column(products)
    details_map = _fetch_item_details(itemmaster_table, product_codes)
    names_map = {code: info["name"] for code, info in details_map.items()}
    product_names = _resolve_product_names(product_codes, names_map)

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "products": product_codes,
                "productNames": product_names,
                "baseUoms": _resolve_product_base_uoms(product_codes, details_map),
                "retailPrices": _resolve_product_retail_prices(
                    product_codes, details_map
                ),
                "type": target_type,
                "targetValue": target_value,
                "achievedValue": achieved_value,
                "routeNo": route_no,
            }
        ),
        201,
    )


@targets_bp.delete("/products")
@require_admin
def delete_product_target():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    target_type = _normalize_product_type(payload.get("type", ""))
    products_raw = payload.get("products")
    if products_raw is None:
        products_raw = payload.get("productNames")

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if not target_type:
        return jsonify({"error": "Invalid target type"}), 400

    products = _format_products_column(products_raw)
    if not products:
        return jsonify({"error": "At least one product is required"}), 400

    table_name = _product_table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            DELETE FROM {table_name}
            WHERE TRIM(EMPLOYEECODE) = :employeecode
              AND TRIM(ROUTE) = :route
              AND LOWER(TRIM(TYPE)) = :type
              AND TRIM(PRODUCTS) = :products
            """,
            {
                "employeecode": employee_code,
                "route": route_no,
                "type": target_type,
                "products": products,
            },
        )
        deleted = cursor.rowcount or 0
        get_connection().commit()

    if deleted == 0:
        return jsonify({"error": "Product target not found"}), 404

    return jsonify({"deleted": deleted})


@targets_bp.get("/customers")
@limiter.limit("90 per minute")
def list_customer_targets():
    """List customer targets (paginated). DB ACHIEVED refresh is opt-in."""
    table_name = _customer_table_name()
    columns_sql = ", ".join(CUSTOMER_TARGET_COLUMNS)
    employee_code, scope_err = _scoped_employee_arg()
    if scope_err is not None:
        return scope_err
    period = _normalize_period(request.args.get("period", ""))
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )
    conditions, params = _build_target_filters(employee_code or "", period)
    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY EMPLOYEECODE, ROUTE, TARGETTYPE, PERIOD
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        contactinfo_table = _contactinfo_table()
        if _wants_refresh_achieved():
            new_customer_count = refresh_new_acquisition_achieved(
                cursor,
                customer_targets_table=table_name,
                contactinfo_table=contactinfo_table,
                employee_code=employee_code or None,
            )
            get_connection().commit()
        else:
            new_customer_count = count_new_customers_flag_n(
                cursor, contactinfo_table
            )

        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        data = [
            _serialize_customer_target(
                row,
                new_customer_count=new_customer_count,
            )
            for row in fetched
        ]

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "newCustomersFlagN": new_customer_count,
            "targets": data,
        }
    )


@targets_bp.post("/customers")
@require_admin
def create_customer_target():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    target_type = _normalize_customer_type(payload.get("type", ""))
    period = _normalize_period(payload.get("period", ""))
    target_raw = payload.get("targetCount")
    if target_raw is None:
        target_raw = payload.get("target")
    amount_raw = payload.get("targetAmount", 0)

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if not target_type:
        return jsonify({"error": "Invalid target type"}), 400
    if not period:
        return jsonify({"error": "Period must be daily, weekly, or monthly"}), 400
    if target_raw in (None, ""):
        return jsonify({"error": "Target count is required"}), 400

    try:
        target_count = float(target_raw)
    except (TypeError, ValueError):
        return jsonify({"error": "Target count must be a number"}), 400

    try:
        target_amount = float(amount_raw or 0)
    except (TypeError, ValueError):
        return jsonify({"error": "Target amount must be a number"}), 400

    # ACHIEVED is server-computed — ignore client values.
    achieved_count = 0.0

    table_name = _customer_table_name()

    with oracle_cursor() as cursor:
        if target_type == "new_acquisition":
            achieved_count = float(
                count_new_customers_flag_n(cursor, _contactinfo_table())
            )

        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (EMPLOYEECODE, TARGETTYPE, TARGET, ACHIEVED, TARGETAMOUNT, PERIOD, ROUTE)
            VALUES
                (:employeecode, :targettype, :target, :achieved, :targetamount, :period, :route)
            """,
            {
                "employeecode": employee_code,
                "targettype": target_type,
                "target": target_count,
                "achieved": achieved_count,
                "targetamount": target_amount,
                "period": period,
                "route": route_no,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "type": target_type,
                "targetCount": target_count,
                "achievedCount": achieved_count,
                "targetAmount": target_amount,
                "period": _period_from_db(period),
                "routeNo": route_no,
            }
        ),
        201,
    )


@targets_bp.delete("/customers")
@require_admin
def delete_customer_target():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    target_type = _normalize_customer_type(payload.get("type", ""))
    period = _normalize_period(payload.get("period", ""))

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if not target_type:
        return jsonify({"error": "Invalid target type"}), 400
    if not period:
        return jsonify({"error": "Period must be daily, weekly, or monthly"}), 400

    table_name = _customer_table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            DELETE FROM {table_name}
            WHERE TRIM(EMPLOYEECODE) = :employeecode
              AND TRIM(ROUTE) = :route
              AND LOWER(TRIM(TARGETTYPE)) = :targettype
              AND PERIOD = :period
            """,
            {
                "employeecode": employee_code,
                "route": route_no,
                "targettype": target_type,
                "period": period,
            },
        )
        deleted = cursor.rowcount or 0
        get_connection().commit()

    if deleted == 0:
        return jsonify({"error": "Customer target not found"}), 404

    return jsonify({"deleted": deleted})
