from flask import Blueprint, current_app, jsonify, request

from app.db import oracle_cursor, row_to_dict

routes_data_bp = Blueprint("routes_data", __name__)

ROUTE_COLUMNS = ("ROUTENAME", "ROUTENO")


@routes_data_bp.get("")
def list_routes():
    table_name = current_app.config["ORACLE_ROUTES_TABLE"]
    search = request.args.get("search", "").strip()
    limit = min(int(request.args.get("limit", 500)), 5000)
    offset = max(int(request.args.get("offset", 0)), 0)

    columns_sql = ", ".join(ROUTE_COLUMNS)
    base_query = f"""
        SELECT {columns_sql}
        FROM {table_name}
    """
    params = {}

    if search:
        base_query += """
        WHERE UPPER(ROUTENAME) LIKE :search
           OR UPPER(ROUTENO) LIKE :search
        """
        params["search"] = f"%{search.upper()}%"

    query = f"""
        SELECT {columns_sql}
        FROM (
            SELECT inner_query.*, ROWNUM AS rnum
            FROM (
                {base_query}
                ORDER BY ROUTENAME
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
            if item.get("routeno") is not None:
                item["routeno"] = str(item["routeno"]).strip()

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "routes": data,
        }
    )
