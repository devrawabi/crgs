from flask import Blueprint, current_app, g, jsonify, request
from flask_limiter import Limiter

from app.db import get_connection, oracle_cursor, row_to_dict
from app.security.passwords import hash_password, is_password_hash, verify_password
from app.security.tokens import create_access_token

auth_bp = Blueprint("auth", __name__)

ACTIVE_FLAG = "A"
ONBOARD_COMPLETE_FLAG = "Y"


def _client_ip():
    forwarded = request.headers.get("CF-Connecting-IP") or request.headers.get(
        "X-Forwarded-For", ""
    )
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.remote_addr or "unknown"


# Shared limiter instance; bound to app in create_app
limiter = Limiter(key_func=_client_ip, default_limits=[])


def _table_name():
    return current_app.config["ORACLE_LOGIN_USERS_TABLE"]


def _normalize_route(value):
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _normalize_onboard(value):
    if value is None:
        return None
    text = str(value).strip().upper()
    return text or None


@auth_bp.post("/login")
@limiter.limit("10 per minute")
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
        SELECT USERNAME, EMPLOYEECODE, ROLECODE, FLAG, ROUTE, ONBOARD_FLAG, PASSWORD
        FROM {table_name}
        WHERE UPPER(EMPLOYEECODE) = UPPER(:employeecode)
          AND FLAG = :flag
    """

    with oracle_cursor() as cursor:
        cursor.execute(
            query,
            {"employeecode": employee_code, "flag": ACTIVE_FLAG},
        )
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "Invalid employee code or password"}), 401
        data = row_to_dict(cursor, row)
        stored_password = data.get("password")
        if not verify_password(password, stored_password):
            return jsonify({"error": "Invalid employee code or password"}), 401

        # Upgrade legacy plaintext passwords to bcrypt on successful login
        if stored_password and not is_password_hash(str(stored_password)):
            try:
                cursor.execute(
                    f"""
                    UPDATE {table_name}
                    SET PASSWORD = :password
                    WHERE UPPER(EMPLOYEECODE) = UPPER(:employeecode)
                    """,
                    {
                        "password": hash_password(password),
                        "employeecode": employee_code,
                    },
                )
                get_connection().commit()
            except Exception:
                get_connection().rollback()

        route = _normalize_route(data.get("route"))
        onboard_flag = _normalize_onboard(data.get("onboard_flag"))
        role_code = data.get("rolecode")
        if role_code is not None:
            role_code = str(role_code).strip()

    token = create_access_token(
        employee_code=data["employeecode"],
        username=data["username"],
        role_code=role_code,
        route=route,
    )

    return jsonify(
        {
            "token": token,
            "tokenType": "Bearer",
            "expiresInHours": int(current_app.config.get("JWT_EXPIRE_HOURS", 12)),
            "username": data["username"],
            "employeeCode": data["employeecode"],
            "roleCode": role_code,
            "flag": data["flag"],
            "route": route,
            "onboardFlag": onboard_flag,
        }
    )


@auth_bp.get("/me")
def me():
    user = getattr(g, "current_user", None)
    if not user:
        return jsonify({"error": "Authentication required"}), 401
    return jsonify(user)


@auth_bp.patch("/onboarding")
def complete_onboarding():
    payload = request.get_json(silent=True) or {}
    employee_code = str(payload.get("employeeCode", "")).strip()
    current = getattr(g, "current_user", None) or {}

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400

    # Users may only complete their own onboarding
    if str(current.get("employeeCode", "")).upper() != employee_code.upper():
        return jsonify({"error": "Forbidden"}), 403

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
