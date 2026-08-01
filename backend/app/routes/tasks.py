from datetime import datetime

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.routes.auth import limiter
from app.security import (
    enforce_owned_employee_code,
    require_admin,
    resolve_employee_scope,
)

tasks_bp = Blueprint("tasks", __name__)

_DEFAULT_LIMIT = 100
_MAX_LIMIT = 500

TASK_COLUMNS = (
    "TYPE",
    "EMPLOYEECODE",
    "ROUTE",
    "STATUS",
    "DUEDATE",
)

TASK_TYPES = {
    "missing_customer_followup",
    "outstanding_collection_followup",
    "new_product_introduction",
    "product_replacement_campaign",
    "customer_visit_campaign",
    "own_products",
    "market_research",
    "other",
}

# Predefined types excluding free-form "other" labels.
STANDARD_TASK_TYPES = TASK_TYPES - {"other"}
# CRGS_TASK.TYPE is VARCHAR2(50).
_MAX_CUSTOM_TYPE_LEN = 50


def _table_name():
    return current_app.config["ORACLE_TASKS_TABLE"]


def _parse_iso_date(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d")
    except ValueError:
        return None


def _normalize_task_type(value: str, *, allow_custom: bool = False) -> str | None:
    text = " ".join(str(value or "").strip().lower().split())
    if not text:
        return None
    if text in TASK_TYPES:
        return text
    if allow_custom and len(text) <= _MAX_CUSTOM_TYPE_LEN:
        return text
    return None


def _normalize_custom_type(value: str) -> str | None:
    """Normalize free-form Other Type text for CRGS_TASK.TYPE."""
    text = " ".join(str(value or "").strip().split())
    if not text:
        return None
    text = text.lower()
    if len(text) > _MAX_CUSTOM_TYPE_LEN:
        return None
    return text


def _resolve_create_type(payload: dict) -> tuple[str | None, str | None]:
    """
    Resolve the TYPE value to insert.

    When Task Type is Other, CRGS_TASK.TYPE must be the Other Type text
    (from otherType, or from type when the client already sent the custom label).
    """
    raw_type = payload.get("type", "")
    known = _normalize_task_type(raw_type)

    if known == "other":
        custom = _normalize_custom_type(payload.get("otherType", ""))
        if not custom:
            return None, "Other type is required when task type is Other"
        return custom, None

    if known:
        return known, None

    # Client sent the Other Type text directly as `type`.
    custom = _normalize_custom_type(raw_type)
    if custom:
        return custom, None

    return None, "Task type is required"


def _serialize_task(row: dict) -> dict:
    route = row.get("route")
    due = str(row.get("duedate") or "").strip()
    if due and "T" in due:
        due = due[:10]
    return {
        "type": str(row.get("type") or "").strip().lower(),
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "routeNo": str(route).strip() if route is not None else "",
        "status": str(row.get("status") or "").strip().lower(),
        "dueDate": due[:10] if due else "",
    }


@tasks_bp.get("")
@limiter.limit("90 per minute")
def list_tasks():
    """List tasks from CRGS_TASK (paginated)."""
    table_name = _table_name()
    columns_sql = ", ".join(TASK_COLUMNS)
    employee_code, scope_err = resolve_employee_scope(
        request.args.get("employeeCode", "").strip()
    )
    if scope_err is not None:
        return scope_err
    raw_type = str(request.args.get("type", "") or "").strip().lower()
    task_type = _normalize_task_type(raw_type, allow_custom=True)
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(EMPLOYEECODE) = :employeecode")
        params["employeecode"] = employee_code
    if raw_type == "other":
        # "Other" filter includes literal "other" plus free-form custom labels.
        known = sorted(STANDARD_TASK_TYPES)
        placeholders = ", ".join(f":kt{i}" for i in range(len(known)))
        conditions.append(
            f"(LOWER(TRIM(TYPE)) = 'other' OR LOWER(TRIM(TYPE)) NOT IN ({placeholders}))"
        )
        for i, known_type in enumerate(known):
            params[f"kt{i}"] = known_type
    elif task_type:
        conditions.append("LOWER(TRIM(TYPE)) = :tasktype")
        params["tasktype"] = task_type

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
        data = [_serialize_task(row) for row in fetched]

    return jsonify(
        {
            "count": len(data),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "tasks": data,
        }
    )


@tasks_bp.post("")
@require_admin
def create_task():
    payload = request.get_json(silent=True) or {}
    task_type, type_error = _resolve_create_type(payload)
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    due_date = _parse_iso_date(payload.get("dueDate", ""))

    if type_error or not task_type:
        return jsonify({"error": type_error or "Task type is required"}), 400
    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if len(route_no) > 20:
        return jsonify({"error": "Route must be 20 characters or fewer"}), 400
    if due_date is None:
        return jsonify({"error": "Due date is required (YYYY-MM-DD)"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (TYPE, EMPLOYEECODE, ROUTE, DUEDATE)
            VALUES
                (:type, :employeecode, :route, :duedate)
            """,
            {
                "type": task_type,
                "employeecode": employee_code,
                "route": route_no,
                "duedate": due_date,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "type": task_type,
                "employeeCode": employee_code,
                "routeNo": route_no,
                "dueDate": due_date.date().isoformat(),
            }
        ),
        201,
    )


TASK_STATUSES = {
    "pending": "Pending",
    "in_progress": "In Progress",
    "completed": "Completed",
}


def _normalize_task_status(value: str) -> str | None:
    text = str(value or "").strip().lower().replace(" ", "_").replace("-", "_")
    if text in ("complete", "done", "c"):
        text = "completed"
    if text in ("inprogress", "progress", "started", "p"):
        text = "in_progress"
    return TASK_STATUSES.get(text)


@tasks_bp.patch("/status")
def update_task_status():
    payload = request.get_json(silent=True) or {}
    task_type = _normalize_task_type(payload.get("type", ""), allow_custom=True)
    employee_code, owned_err = enforce_owned_employee_code(
        payload.get("employeeCode")
    )
    if owned_err is not None:
        return owned_err
    route_no = str(payload.get("routeNo", "")).strip()
    due_date = _parse_iso_date(payload.get("dueDate", ""))
    status = _normalize_task_status(payload.get("status", ""))

    if not task_type:
        return jsonify({"error": "Task type is required"}), 400
    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if due_date is None:
        return jsonify({"error": "Due date is required (YYYY-MM-DD)"}), 400
    if status is None:
        return jsonify({"error": "Status must be Pending, In Progress, or Completed"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {table_name}
            SET STATUS = :status
            WHERE LOWER(TRIM(TYPE)) = :type
              AND TRIM(EMPLOYEECODE) = :employeecode
              AND TRIM(ROUTE) = :route
              AND TRUNC(DUEDATE) = TRUNC(:duedate)
            """,
            {
                "status": status,
                "type": task_type,
                "employeecode": employee_code,
                "route": route_no,
                "duedate": due_date,
            },
        )
        updated = cursor.rowcount or 0
        get_connection().commit()

    if updated == 0:
        return jsonify({"error": "Task not found"}), 404

    return jsonify(
        {
            "type": task_type,
            "employeeCode": employee_code,
            "routeNo": route_no,
            "dueDate": due_date.date().isoformat(),
            "status": status,
            "updated": updated,
        }
    )


@tasks_bp.delete("")
@require_admin
def delete_task():
    payload = request.get_json(silent=True) or {}
    task_type = _normalize_task_type(payload.get("type", ""), allow_custom=True)
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    due_date = _parse_iso_date(payload.get("dueDate", ""))

    if not task_type:
        return jsonify({"error": "Task type is required"}), 400
    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route_no:
        return jsonify({"error": "Route is required"}), 400
    if due_date is None:
        return jsonify({"error": "Due date is required (YYYY-MM-DD)"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            DELETE FROM {table_name}
            WHERE LOWER(TRIM(TYPE)) = :type
              AND TRIM(EMPLOYEECODE) = :employeecode
              AND TRIM(ROUTE) = :route
              AND TRUNC(DUEDATE) = TRUNC(:duedate)
            """,
            {
                "type": task_type,
                "employeecode": employee_code,
                "route": route_no,
                "duedate": due_date,
            },
        )
        deleted = cursor.rowcount or 0
        get_connection().commit()

    if deleted == 0:
        return jsonify({"error": "Task not found"}), 404

    return jsonify({"deleted": deleted})

