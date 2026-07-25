from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict

auth_bp = Blueprint("auth", __name__)

ACTIVE_FLAG = "A"
ONBOARD_COMPLETE_FLAG = "Y"


def _table_name():
    return current_app.config["ORACLE_LOGIN_USERS_TABLE"]


@auth_bp.post("/login")
def login():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    password = str(payload.get("password", ""))

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not password:
        return jsonify({"error": "Password is required"}), 400

    table_name = _table_name()
    query = f"""
        SELECT USERNAME, EMPLOYEECODE, ROLECODE, FLAG, ROUTE, ONBOARD_FLAG
        FROM {table_name}
        WHERE UPPER(EMPLOYEECODE) = UPPER(:employeecode)
          AND PASSWORD = :password
          AND FLAG = :flag
    """

    with oracle_cursor() as cursor:
        cursor.execute(
            query,
            {"employeecode": employee_code, "password": password, "flag": ACTIVE_FLAG},
        )
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "Invalid employee code or password"}), 401
        data = row_to_dict(cursor, row)
        route = data.get("route")
        if route is not None:
            route = str(route).strip()
        onboard_flag = data.get("onboard_flag")
        if onboard_flag is not None:
            onboard_flag = str(onboard_flag).strip().upper() or None

    return jsonify(
        {
            "username": data["username"],
            "employeeCode": data["employeecode"],
            "roleCode": data["rolecode"],
            "flag": data["flag"],
            "route": route or None,
            "onboardFlag": onboard_flag,
        }
    )


@auth_bp.patch("/onboarding")
def complete_onboarding():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {table_name}
            SET ONBOARD_FLAG = :onboard_flag
            WHERE UPPER(EMPLOYEECODE) = UPPER(:employeecode)
              AND FLAG = :flag
            """,
            {
                "onboard_flag": ONBOARD_COMPLETE_FLAG,
                "employeecode": employee_code,
                "flag": ACTIVE_FLAG,
            },
        )
        if cursor.rowcount == 0:
            return jsonify({"error": "User not found"}), 404
        get_connection().commit()

    return jsonify(
        {
            "employeeCode": employee_code,
            "onboardFlag": ONBOARD_COMPLETE_FLAG,
        }
    )
