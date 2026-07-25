from flask import Blueprint, current_app, jsonify, request

from app.db import oracle_cursor, row_to_dict

items_bp = Blueprint("items", __name__)

ITEM_COLUMNS = ("ITEMCODE", "ITEMNAME", "BASEUOM", "RETAILPRICE")


@items_bp.get("")
def list_items():
    table_name = current_app.config["ORACLE_ITEMMASTER_TABLE"]
    search = request.args.get("search", "").strip()
    limit = min(int(request.args.get("limit", 500)), 5000)
    offset = max(int(request.args.get("offset", 0)), 0)

    columns_sql = ", ".join(ITEM_COLUMNS)
    base_query = f"""
        SELECT {columns_sql}
        FROM {table_name}
    """
    params = {}

    if search:
        base_query += """
        WHERE UPPER(TO_CHAR(ITEMCODE)) LIKE :search
           OR UPPER(ITEMNAME) LIKE :search
        """
        params["search"] = f"%{search.upper()}%"

    query = f"""
        SELECT {columns_sql}
        FROM (
            SELECT inner_query.*, ROWNUM AS rnum
            FROM (
                {base_query}
                ORDER BY ITEMNAME
            ) inner_query
            WHERE ROWNUM <= :max_row
        )
        WHERE rnum > :min_row
    """
    params["max_row"] = offset + limit
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        rows = cursor.fetchall()
        data = [row_to_dict(cursor, row) for row in rows]
        for item in data:
            if item.get("itemcode") is not None:
                item["itemcode"] = str(item["itemcode"]).strip()
            if item.get("itemname") is not None:
                item["itemname"] = str(item["itemname"]).strip()
            if item.get("baseuom") is not None:
                item["baseuom"] = str(item["baseuom"]).strip()
            retail_raw = item.get("retailprice")
            try:
                item["retailprice"] = (
                    float(retail_raw) if retail_raw is not None else 0.0
                )
            except (TypeError, ValueError):
                item["retailprice"] = 0.0

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "items": data,
        }
    )
