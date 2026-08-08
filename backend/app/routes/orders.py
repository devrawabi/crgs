from datetime import datetime, timedelta

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.routes.auth import limiter
from app.security import enforce_owned_employee_code, resolve_employee_scope
from app.services.sales_target_achievement import refresh_sales_target_achieved

orders_bp = Blueprint("orders", __name__)

_DEFAULT_LIMIT = 50
_MAX_LIMIT = 200


def _hdr_table():
    return current_app.config["ORACLE_ORDERHDR_TABLE"]


def _dtl_table():
    return current_app.config["ORACLE_ORDERDTL_TABLE"]


def _item_table():
    return current_app.config["ORACLE_ITEMMASTER_TABLE"]


def _sale_targets_table():
    return current_app.config["ORACLE_SALE_TARGETS_TABLE"]


def _parse_iso_date(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d")
    except ValueError:
        return None


def _parse_iso_datetime(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).replace(tzinfo=None)
    except ValueError:
        return None


def _date_only(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    if "T" in text:
        return text[:10]
    return text[:10]


def _format_time_only(value: datetime) -> str:
    """Store ORDERTIME as HH:MM:SS only (no date)."""
    return value.strftime("%H:%M:%S")


def _to_float(value, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _to_int(value, default: int = 0) -> int:
    try:
        if value is None:
            return default
        return int(float(value))
    except (TypeError, ValueError):
        return default


def _next_order_no(cursor, table_name: str) -> str:
    cursor.execute(
        f"""
        SELECT NVL(MAX(TO_NUMBER(REGEXP_SUBSTR(TRIM(ORDERNO), '^[0-9]+'))), 0) + 1
        FROM {table_name}
        """
    )
    row = cursor.fetchone()
    next_no = int(row[0]) if row and row[0] is not None else 1
    return str(next_no)


def _group_orders(rows: list[dict]) -> list[dict]:
    orders_by_no: dict[str, dict] = {}
    order: list[str] = []

    for row in rows:
        order_no = str(row.get("orderno") or "").strip()
        if not order_no:
            continue

        if order_no not in orders_by_no:
            order.append(order_no)
            orders_by_no[order_no] = {
                "orderNo": order_no,
                "orderDate": _date_only(row.get("orderdate")),
                "employeeCode": str(row.get("employeecode") or "").strip(),
                "customerCode": str(row.get("customercode") or "").strip(),
                "customerName": str(row.get("customername") or "").strip(),
                "route": str(row.get("route") or "").strip(),
                "totalAmount": _to_float(row.get("totalamount")),
                "itemCount": _to_int(row.get("itemcount")),
                "expectedDate": _date_only(row.get("expecteddate")),
                "items": [],
            }

        item_code = str(row.get("itemcode") or "").strip()
        if not item_code:
            continue

        item_name = str(row.get("itemname") or "").strip() or item_code
        qty = _to_float(row.get("qty"))
        price = _to_float(row.get("price"))
        amount = _to_float(row.get("amount"))
        if amount == 0 and qty and price:
            amount = round(qty * price, 2)

        orders_by_no[order_no]["items"].append(
            {
                "itemCode": item_code,
                "itemName": item_name,
                "qty": qty,
                "uom": str(row.get("uom") or "PCS").strip() or "PCS",
                "price": price,
                "amount": amount,
                "route": str(row.get("dtl_route") or row.get("route") or "").strip(),
            }
        )

    result = []
    for order_no in order:
        payload = orders_by_no[order_no]
        if payload["itemCount"] <= 0:
            payload["itemCount"] = len(payload["items"])
        result.append(payload)
    return result


def _header_orders(header_rows: list[dict]) -> list[dict]:
    """Serialize header-only order rows (empty items[])."""
    orders = []
    for row in header_rows:
        order_no = str(row.get("orderno") or "").strip()
        if not order_no:
            continue
        orders.append(
            {
                "orderNo": order_no,
                "orderDate": _date_only(row.get("orderdate")),
                "employeeCode": str(row.get("employeecode") or "").strip(),
                "customerCode": str(row.get("customercode") or "").strip(),
                "customerName": str(row.get("customername") or "").strip(),
                "route": str(row.get("route") or "").strip(),
                "totalAmount": _to_float(row.get("totalamount")),
                "itemCount": _to_int(row.get("itemcount")),
                "expectedDate": _date_only(row.get("expecteddate")),
                "items": [],
            }
        )
    return orders


@orders_bp.get("")
@limiter.limit("90 per minute")
def list_orders():
    """
    Fetch expected orders from CRGS_ORDERHDR (+ optional CRGS_ORDERDTL).

    Pagination is applied to order headers (not detail rows).
    Query params:
      - employeeCode, limit (default 50, max 200), offset
      - includeDetails: true|false (default true). false skips detail/ITEMNAME join.
      - dateFrom / dateTo: YYYY-MM-DD (admin unscoped lists default to last 90 days)
    """
    hdr_table = _hdr_table()
    dtl_table = _dtl_table()
    item_table = _item_table()
    employee_code, scope_err = resolve_employee_scope(
        request.args.get("employeeCode", "").strip()
    )
    if scope_err is not None:
        return scope_err
    include_details = request.args.get("includeDetails", "true").strip().lower() not in (
        "0",
        "false",
        "no",
    )
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )

    date_from = _parse_iso_date(request.args.get("dateFrom", ""))
    date_to = _parse_iso_date(request.args.get("dateTo", ""))
    # Admin "all employees" without a date window walks the full order history.
    if not employee_code and date_from is None and date_to is None:
        date_from = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        ) - timedelta(days=90)

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(EMPLOYEECODE) = :employeecode")
        params["employeecode"] = employee_code
    if date_from is not None:
        conditions.append("ORDERDATE >= :date_from")
        params["date_from"] = date_from
    if date_to is not None:
        conditions.append("ORDERDATE < :date_to")
        # Inclusive end date → next day exclusive bound (avoids TRUNC on column).
        params["date_to"] = date_to + timedelta(days=1)

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    # Page headers first (limit+1 for exact has_more), then load details.
    headers_inner = f"""
        SELECT
            ORDERNO,
            ORDERDATE,
            EMPLOYEECODE,
            CUSTOMERCODE,
            CUSTOMERNAME,
            ROUTE,
            TOTALAMOUNT,
            ITEMCOUNT,
            EXPECTEDDATE
        FROM {hdr_table}
        {where_sql}
        ORDER BY ORDERDATE DESC,
                 TO_NUMBER(REGEXP_SUBSTR(TRIM(ORDERNO), '^[0-9]+')) DESC NULLS LAST
    """
    headers_sql = rownum_page_sql(
        headers_inner,
        columns_sql=(
            "ORDERNO, ORDERDATE, EMPLOYEECODE, CUSTOMERCODE, CUSTOMERNAME, "
            "ROUTE, TOTALAMOUNT, ITEMCOUNT, EXPECTEDDATE"
        ),
    )
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(headers_sql, params)
        header_rows = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        header_rows, has_more = apply_has_more(header_rows, limit)

        if not header_rows:
            return jsonify(
                {
                    "count": 0,
                    "offset": offset,
                    "limit": limit,
                    "has_more": False,
                    "includeDetails": include_details,
                    "orders": [],
                }
            )

        if not include_details:
            orders = _header_orders(header_rows)
            return jsonify(
                {
                    "count": len(orders),
                    "offset": offset,
                    "limit": limit,
                    "has_more": has_more,
                    "includeDetails": False,
                    "orders": orders,
                }
            )

        order_nos = [
            str(row.get("orderno") or "").strip()
            for row in header_rows
            if str(row.get("orderno") or "").strip()
        ]
        # Bind IN-list safely (Oracle named binds).
        in_binds = {f"ono_{i}": ono for i, ono in enumerate(order_nos)}
        in_sql = ", ".join(f":{key}" for key in in_binds)

        # Equality-only ITEMMASTER join — OR TRIM(TO_CHAR(...)) disables indexes.
        cursor.execute(
            f"""
            SELECT
                h.ORDERNO,
                h.ORDERDATE,
                h.EMPLOYEECODE,
                h.CUSTOMERCODE,
                h.CUSTOMERNAME,
                h.ROUTE,
                h.TOTALAMOUNT,
                h.ITEMCOUNT,
                h.EXPECTEDDATE,
                d.ITEMCODE,
                d.QTY,
                d.UOM,
                d.PRICE,
                d.AMOUNT,
                d.ROUTE AS DTL_ROUTE,
                i.ITEMNAME
            FROM {hdr_table} h
            LEFT JOIN {dtl_table} d
                ON h.ORDERNO = d.ORDERNO
            LEFT JOIN {item_table} i
                ON d.ITEMCODE = i.ITEMCODE
            WHERE h.ORDERNO IN ({in_sql})
            ORDER BY h.ORDERDATE DESC,
                     TO_NUMBER(REGEXP_SUBSTR(TRIM(h.ORDERNO), '^[0-9]+')) DESC NULLS LAST,
                     d.ITEMCODE
            """,
            in_binds,
        )
        rows = [row_to_dict(cursor, row) for row in cursor.fetchall()]

    orders = _group_orders(rows)
    # Preserve header page order (IN-clause order is not guaranteed).
    order_index = {ono: idx for idx, ono in enumerate(order_nos)}
    orders.sort(key=lambda o: order_index.get(str(o.get("orderNo") or ""), 10**9))

    return jsonify(
        {
            "count": len(orders),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "includeDetails": True,
            "orders": orders,
        }
    )


def _lookup_retail_prices(cursor, item_codes: list[str]) -> dict[str, float]:
    """Server-authoritative unit prices from ITEMMASTER.RETAILPRICE."""
    prices: dict[str, float] = {}
    if not item_codes:
        return prices
    item_table = _item_table()
    unique = list(dict.fromkeys(item_codes))
    for start in range(0, len(unique), 40):
        chunk = unique[start : start + 40]
        binds = {f"c{i}": code for i, code in enumerate(chunk)}
        in_sql = ", ".join(f":{key}" for key in binds)
        cursor.execute(
            f"""
            SELECT ITEMCODE, NVL(RETAILPRICE, 0)
            FROM {item_table}
            WHERE ITEMCODE IN ({in_sql})
            """,
            binds,
        )
        for row in cursor.fetchall():
            code = str(row[0] or "").strip()
            if code:
                prices[code.upper()] = float(row[1] or 0)
    return prices


def _normalize_items(
    raw_items,
    route: str,
    prices_by_code: dict[str, float],
) -> tuple[list[dict], str | None]:
    if not isinstance(raw_items, list) or not raw_items:
        return [], "At least one order item is required"

    items: list[dict] = []
    for index, raw in enumerate(raw_items):
        if not isinstance(raw, dict):
            return [], f"Item {index + 1} is invalid"

        item_code = str(
            raw.get("itemCode") or raw.get("productId") or ""
        ).strip()
        uom = str(raw.get("uom") or "PCS").strip() or "PCS"

        try:
            qty = float(raw.get("qty", raw.get("quantity", 0)) or 0)
        except (TypeError, ValueError):
            return [], f"Item {index + 1} quantity is invalid"

        item_route = str(raw.get("route") or route).strip() or route

        if not item_code:
            return [], f"Item {index + 1} code is required"
        if qty <= 0:
            return [], f"Item {index + 1} quantity must be greater than zero"
        if len(item_code) > 30:
            return [], f"Item {index + 1} code must be 30 characters or fewer"
        if len(uom) > 10:
            uom = uom[:10]
        if len(item_route) > 20:
            return [], f"Item {index + 1} route must be 20 characters or fewer"

        price = prices_by_code.get(item_code.upper())
        if price is None:
            return [], f"Item {index + 1} ({item_code}) was not found in item master"
        if price < 0:
            return [], f"Item {index + 1} price cannot be negative"

        amount = round(qty * price, 2)
        items.append(
            {
                "itemcode": item_code,
                "qty": round(qty, 3),
                "uom": uom,
                "price": round(price, 2),
                "amount": amount,
                "route": item_route,
            }
        )

    return items, None


@orders_bp.post("")
def create_order():
    """Insert CRGS_ORDERHDR + CRGS_ORDERDTL rows when Save Expected Order is clicked."""
    payload = request.get_json(silent=True) or {}

    employee_code, owned_err = enforce_owned_employee_code(
        payload.get("employeeCode")
    )
    if owned_err is not None:
        return owned_err
    customer_code = str(payload.get("customerCode", "")).strip()
    customer_name = str(payload.get("customerName", "")).strip()
    route = str(payload.get("route", "")).strip()
    order_date = _parse_iso_datetime(payload.get("orderDate", ""))
    expected_date = _parse_iso_date(payload.get("expectedDate", ""))

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not customer_code:
        return jsonify({"error": "Customer code is required"}), 400
    if not customer_name:
        return jsonify({"error": "Customer name is required"}), 400
    if not route:
        return jsonify({"error": "Route is required"}), 400

    # ORDERDATE = calendar date only; ORDERTIME = clock time when the order was saved.
    order_time = datetime.now().replace(microsecond=0)
    if order_date is None:
        order_date = order_time
    order_date = order_date.replace(hour=0, minute=0, second=0, microsecond=0)

    if len(employee_code) > 20:
        return jsonify({"error": "Employee code must be 20 characters or fewer"}), 400
    if len(customer_code) > 20:
        return jsonify({"error": "Customer code must be 20 characters or fewer"}), 400
    if len(customer_name) > 100:
        return jsonify({"error": "Customer name must be 100 characters or fewer"}), 400
    if len(route) > 20:
        return jsonify({"error": "Route must be 20 characters or fewer"}), 400

    hdr_table = _hdr_table()
    dtl_table = _dtl_table()
    raw_items = payload.get("items")

    with oracle_cursor() as cursor:
        codes: list[str] = []
        if isinstance(raw_items, list):
            for raw in raw_items:
                if isinstance(raw, dict):
                    code = str(
                        raw.get("itemCode") or raw.get("productId") or ""
                    ).strip()
                    if code:
                        codes.append(code)
        prices = _lookup_retail_prices(cursor, codes)
        items, items_error = _normalize_items(raw_items, route, prices)
        if items_error:
            return jsonify({"error": items_error}), 400

        total_amount = round(sum(item["amount"] for item in items), 2)
        item_count = len(items)
        if total_amount < 0:
            return jsonify({"error": "Total amount cannot be negative"}), 400

        order_no = _next_order_no(cursor, hdr_table)
        cursor.execute(
            f"""
            INSERT INTO {hdr_table}
                (
                    ORDERNO,
                    ORDERDATE,
                    ORDERTIME,
                    EMPLOYEECODE,
                    CUSTOMERCODE,
                    CUSTOMERNAME,
                    ROUTE,
                    TOTALAMOUNT,
                    ITEMCOUNT,
                    EXPECTEDDATE
                )
            VALUES
                (
                    :orderno,
                    :orderdate,
                    :ordertime,
                    :employeecode,
                    :customercode,
                    :customername,
                    :route,
                    :totalamount,
                    :itemcount,
                    :expecteddate
                )
            """,
            {
                "orderno": order_no,
                "orderdate": order_date,
                "ordertime": _format_time_only(order_time),
                "employeecode": employee_code,
                "customercode": customer_code,
                "customername": customer_name,
                "route": route,
                "totalamount": total_amount,
                "itemcount": item_count,
                "expecteddate": expected_date,
            },
        )

        for item in items:
            cursor.execute(
                f"""
                INSERT INTO {dtl_table}
                    (
                        ORDERNO,
                        ITEMCODE,
                        QTY,
                        UOM,
                        PRICE,
                        AMOUNT,
                        ROUTE
                    )
                VALUES
                    (
                        :orderno,
                        :itemcode,
                        :qty,
                        :uom,
                        :price,
                        :amount,
                        :route
                    )
                """,
                {
                    "orderno": order_no,
                    "itemcode": item["itemcode"],
                    "qty": item["qty"],
                    "uom": item["uom"],
                    "price": item["price"],
                    "amount": item["amount"],
                    "route": item["route"],
                },
            )

        # Write order totals into CRGS_SALETARGET.ACHIEVED for this executive
        updated_targets = refresh_sales_target_achieved(
            cursor,
            sale_targets_table=_sale_targets_table(),
            order_hdr_table=hdr_table,
            employee_code=employee_code,
        )

        get_connection().commit()

    return (
        jsonify(
            {
                "orderNo": order_no,
                "orderDate": order_date.date().isoformat(),
                "orderTime": _format_time_only(order_time),
                "employeeCode": employee_code,
                "customerCode": customer_code,
                "customerName": customer_name,
                "route": route,
                "totalAmount": total_amount,
                "itemCount": item_count,
                "expectedDate": expected_date.date().isoformat() if expected_date else "",
                "updatedSalesTargets": updated_targets,
                "items": [
                    {
                        "itemCode": item["itemcode"],
                        "qty": item["qty"],
                        "uom": item["uom"],
                        "price": item["price"],
                        "amount": item["amount"],
                        "route": item["route"],
                    }
                    for item in items
                ],
            }
        ),
        201,
    )
