from datetime import datetime

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict

tasks_bp = Blueprint("tasks", __name__)

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


def _normalize_task_type(value: str) -> str | None:
    text = str(value or "").strip().lower()
    if text in TASK_TYPES:
        return text
    return None


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
def list_tasks():
    table_name = _table_name()
    columns_sql = ", ".join(TASK_COLUMNS)
    employee_code = request.args.get("employeeCode", "").strip()

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode")
        params["employeecode"] = employee_code

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            SELECT {columns_sql}
            FROM {table_name}
            {where_sql}
            ORDER BY DUEDATE DESC, EMPLOYEECODE, ROUTE
            """,
            params,
        )
        rows = cursor.fetchall()
        data = [_serialize_task(row_to_dict(cursor, row)) for row in rows]

    return jsonify({"count": len(data), "tasks": data})


@tasks_bp.post("")
def create_task():
    payload = request.get_json(silent=True) or {}
    task_type = _normalize_task_type(payload.get("type", ""))
    employee_code = str(payload.get("employeeCode", "")).strip()
    route_no = str(payload.get("routeNo", "")).strip()
    due_date = _parse_iso_date(payload.get("dueDate", ""))

    if not task_type:
        return jsonify({"error": "Task type is required"}), 400
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
    task_type = _normalize_task_type(payload.get("type", ""))
    employee_code = str(payload.get("employeeCode", "")).strip()
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
            WHERE LOWER(TRIM(TO_CHAR(TYPE))) = :type
              AND TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode
              AND TRIM(TO_CHAR(ROUTE)) = :route
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
def delete_task():
    payload = request.get_json(silent=True) or {}
    task_type = _normalize_task_type(payload.get("type", ""))
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
            WHERE LOWER(TRIM(TO_CHAR(TYPE))) = :type
              AND TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode
              AND TRIM(TO_CHAR(ROUTE)) = :route
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

