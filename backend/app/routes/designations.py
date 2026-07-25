from flask import Blueprint, current_app, jsonify

from app.db import oracle_cursor, row_to_dict

designations_bp = Blueprint("designations", __name__)

DESIGNATION_COLUMNS = ("ROLECODE", "DESIGNATION")


def _table_name():
    return current_app.config["ORACLE_DESIGNATION_TABLE"]


@designations_bp.get("")
def list_designations():
    table_name = _table_name()
    columns_sql = ", ".join(DESIGNATION_COLUMNS)
    query = f"""
        SELECT {columns_sql}
        FROM {table_name}
        ORDER BY DESIGNATION
    """

    with oracle_cursor() as cursor:
        cursor.execute(query)
        rows = cursor.fetchall()
        data = [row_to_dict(cursor, row) for row in rows]
        for item in data:
            if item.get("rolecode") is not None:
                item["rolecode"] = str(item["rolecode"]).strip()
            if item.get("designation") is not None:
                item["designation"] = str(item["designation"]).strip()

    return jsonify({"count": len(data), "designations": data})
