from datetime import datetime

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.services.sales_target_achievement import refresh_sales_target_achieved

orders_bp = Blueprint("orders", __name__)


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


@orders_bp.get("")
def list_orders():
    """Fetch expected orders from CRGS_ORDERHDR + CRGS_ORDERDTL."""
    hdr_table = _hdr_table()
    dtl_table = _dtl_table()
    item_table = _item_table()
    employee_code = request.args.get("employeeCode", "").strip()

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(TO_CHAR(h.EMPLOYEECODE)) = :employeecode")
        params["employeecode"] = employee_code

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    with oracle_cursor() as cursor:
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
                ON TRIM(TO_CHAR(h.ORDERNO)) = TRIM(TO_CHAR(d.ORDERNO))
            LEFT JOIN {item_table} i
                ON TRIM(TO_CHAR(d.ITEMCODE)) = TRIM(TO_CHAR(i.ITEMCODE))
            {where_sql}
            ORDER BY h.ORDERDATE DESC,
                     TO_NUMBER(REGEXP_SUBSTR(TRIM(TO_CHAR(h.ORDERNO)), '^[0-9]+')) DESC NULLS LAST,
                     d.ITEMCODE
            """,
            params,
        )
        rows = [row_to_dict(cursor, row) for row in cursor.fetchall()]

    orders = _group_orders(rows)
    return jsonify({"count": len(orders), "orders": orders})


def _normalize_items(raw_items, route: str) -> tuple[list[dict], str | None]:
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

        try:
            price = float(raw.get("price", raw.get("unitPrice", 0)) or 0)
        except (TypeError, ValueError):
            return [], f"Item {index + 1} price is invalid"

        if "amount" in raw and raw.get("amount") is not None:
            try:
                amount = float(raw.get("amount") or 0)
            except (TypeError, ValueError):
                return [], f"Item {index + 1} amount is invalid"
        else:
            amount = round(qty * price, 2)

        item_route = str(raw.get("route") or route).strip() or route

        if not item_code:
            return [], f"Item {index + 1} code is required"
        if qty <= 0:
            return [], f"Item {index + 1} quantity must be greater than zero"
        if price < 0:
            return [], f"Item {index + 1} price cannot be negative"
        if amount < 0:
            return [], f"Item {index + 1} amount cannot be negative"
        if len(item_code) > 30:
            return [], f"Item {index + 1} code must be 30 characters or fewer"
        if len(uom) > 10:
            uom = uom[:10]
        if len(item_route) > 20:
            return [], f"Item {index + 1} route must be 20 characters or fewer"

        items.append(
            {
                "itemcode": item_code,
                "qty": round(qty, 3),
                "uom": uom,
                "price": round(price, 2),
                "amount": round(amount, 2),
                "route": item_route,
            }
        )

    return items, None


@orders_bp.post("")
def create_order():
    """Insert CRGS_ORDERHDR + CRGS_ORDERDTL rows when Save Expected Order is clicked."""
    payload = request.get_json(silent=True) or {}

    employee_code = str(payload.get("employeeCode", "")).strip()
    customer_code = str(payload.get("customerCode", "")).strip()
    customer_name = str(payload.get("customerName", "")).strip()
    route = str(payload.get("route", "")).strip()
    order_date = _parse_iso_datetime(payload.get("orderDate", ""))
    expected_date = _parse_iso_date(payload.get("expectedDate", ""))

    items, items_error = _normalize_items(payload.get("items"), route)
    if items_error:
        return jsonify({"error": items_error}), 400

    total_amount = round(sum(item["amount"] for item in items), 2)
    item_count = len(items)

    if "totalAmount" in payload and payload.get("totalAmount") is not None:
        try:
            client_total = float(payload.get("totalAmount") or 0)
            if abs(client_total - total_amount) < 0.01:
                total_amount = round(client_total, 2)
        except (TypeError, ValueError):
            return jsonify({"error": "Total amount must be a number"}), 400

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not customer_code:
        return jsonify({"error": "Customer code is required"}), 400
    if not customer_name:
        return jsonify({"error": "Customer name is required"}), 400
    if not route:
        return jsonify({"error": "Route is required"}), 400
    if total_amount < 0:
        return jsonify({"error": "Total amount cannot be negative"}), 400

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

    with oracle_cursor() as cursor:
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
