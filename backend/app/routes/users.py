from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.routes.auth import limiter
from app.security import (
    can_create_role_code,
    normalize_role_code,
    require_admin,
    require_full_admin,
    require_user_list,
)
from app.security.passwords import hash_password, validate_password_strength

users_bp = Blueprint("users", __name__)

USER_COLUMNS = ("USERNAME", "EMPLOYEECODE", "ROLECODE", "FLAG", "ROUTE")
ACTIVE_FLAG = "A"
INACTIVE_FLAG = "D"
_DEFAULT_LIMIT = 200
_MAX_LIMIT = 1000


def _table_name():
    return current_app.config["ORACLE_LOGIN_USERS_TABLE"]


def _designation_table_name():
    return current_app.config["ORACLE_DESIGNATION_TABLE"]


def _format_route_column(route_nos):
    return ",".join(str(no).strip() for no in route_nos if str(no).strip())


def _normalize_rolecode(value):
    return normalize_role_code(value)


@users_bp.get("")
@limiter.limit("90 per minute")
@require_user_list
def list_users():
    """List login users (admins, managers, call-center)."""
    table_name = _table_name()
    designation_table = _designation_table_name()
    active_only = request.args.get("activeOnly", "").lower() in ("1", "true", "yes")
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )
    columns_sql = ", ".join(f"u.{column}" for column in USER_COLUMNS)
    select_cols = f"{columns_sql}, d.DESIGNATION"
    where_sql = " WHERE u.FLAG = :flag" if active_only else ""
    params = {"flag": ACTIVE_FLAG} if active_only else {}

    inner_sql = f"""
        SELECT {select_cols}
        FROM {table_name} u
        LEFT JOIN {designation_table} d
          ON TRIM(u.ROLECODE) = TRIM(d.ROLECODE)
        {where_sql}
        ORDER BY u.USERNAME
    """
    # Outer select must list joined columns without table aliases.
    outer_cols = ", ".join(USER_COLUMNS) + ", DESIGNATION"
    query = rownum_page_sql(inner_sql, columns_sql=outer_cols)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        data = fetched
        for item in data:
            if item.get("rolecode") is not None:
                item["rolecode"] = _normalize_rolecode(item["rolecode"])
            route = item.get("route")
            if route is not None:
                item["route"] = str(route).strip()
            designation = item.get("designation")
            if designation is not None:
                item["designation"] = str(designation).strip()

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "users": data,
        }
    )


@users_bp.post("")
@require_full_admin
def create_user():
    payload = request.get_json(silent=True) or {}
    username = str(payload.get("username", "")).strip()
    employee_code = str(payload.get("employeeCode", "")).strip()
    password = str(payload.get("password", ""))
    role_code = _normalize_rolecode(
        payload.get("roleCode", payload.get("rolecode", ""))
    )

    if not username:
        return jsonify({"error": "Username is required"}), 400
    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not password:
        return jsonify({"error": "Password is required"}), 400
    password_error = validate_password_strength(password)
    if password_error:
        return jsonify({"error": password_error}), 400
    if not role_code:
        return jsonify({"error": "Designation is required"}), 400
    if not can_create_role_code(role_code):
        return (
            jsonify(
                {
                    "error": "Only role code 1 can create users with role code 1 or 9",
                }
            ),
            403,
        )

    table_name = _table_name()
    designation_table = _designation_table_name()
    password_hash = hash_password(password)

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            SELECT DESIGNATION
            FROM {designation_table}
            WHERE TRIM(ROLECODE) = :rolecode
            """,
            {"rolecode": role_code},
        )
        designation_row = cursor.fetchone()
        if not designation_row:
            return jsonify({"error": "Invalid designation"}), 400
        designation = str(designation_row[0]).strip() if designation_row[0] else ""

        cursor.execute(
            f"""
            SELECT 1
            FROM {table_name}
            WHERE UPPER(USERNAME) = UPPER(:username)
               OR UPPER(EMPLOYEECODE) = UPPER(:employeecode)
            """,
            {"username": username, "employeecode": employee_code},
        )
        if cursor.fetchone():
            return jsonify({"error": "Username or employee code already exists"}), 409

        cursor.execute(
            f"""
            INSERT INTO {table_name} (USERNAME, EMPLOYEECODE, PASSWORD, ROLECODE, FLAG)
            VALUES (:username, :employeecode, :password, :rolecode, :flag)
            """,
            {
                "username": username,
                "employeecode": employee_code,
                "password": password_hash,
                "rolecode": role_code,
                "flag": ACTIVE_FLAG,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "username": username,
                "employeeCode": employee_code,
                "roleCode": role_code,
                "designation": designation,
                "flag": ACTIVE_FLAG,
            }
        ),
        201,
    )


@users_bp.patch("/routes")
@require_admin
def update_user_routes():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_nos = payload.get("routeNos")

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if route_nos is None or not isinstance(route_nos, list):
        return jsonify({"error": "routeNos must be an array"}), 400

    route_value = _format_route_column(route_nos)
    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {table_name}
            SET ROUTE = :route
            WHERE UPPER(EMPLOYEECODE) = UPPER(:employeecode)
            """,
            {
                "route": route_value or None,
                "employeecode": employee_code,
            },
        )
        if cursor.rowcount == 0:
            return jsonify({"error": "User not found"}), 404
        get_connection().commit()

    return jsonify(
        {
            "employeeCode": employee_code,
            "route": route_value,
            "routeNos": [no.strip() for no in route_value.split(",") if no.strip()]
            if route_value
            else [],
        }
    )


@users_bp.patch("/status")
@require_full_admin
def update_user_status():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    flag = str(payload.get("flag", "")).strip().upper()

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if flag not in (ACTIVE_FLAG, INACTIVE_FLAG):
        return jsonify({"error": "flag must be A or D"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {table_name}
            SET FLAG = :flag
            WHERE UPPER(EMPLOYEECODE) = UPPER(:employeecode)
            """,
            {
                "flag": flag,
                "employeecode": employee_code,
            },
        )
        if cursor.rowcount == 0:
            return jsonify({"error": "User not found"}), 404
        get_connection().commit()

    return jsonify({"employeeCode": employee_code, "flag": flag})
