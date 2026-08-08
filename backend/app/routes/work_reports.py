"""Additional work reports — list/insert CRGS_WORKREPORT (not tasks)."""

from datetime import datetime, timedelta

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.security import enforce_owned_employee_code, resolve_employee_scope

work_reports_bp = Blueprint("work_reports", __name__)

_DEFAULT_LIMIT = 50
_MAX_LIMIT = 200
_ADMIN_DEFAULT_DAYS = 90


def _table_name() -> str:
    return current_app.config["ORACLE_WORKREPORT_TABLE"]


def _clip(value: str, max_len: int) -> str:
    text = str(value or "").strip()
    if len(text) > max_len:
        return text[:max_len]
    return text


def _date_only(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    return text[:10]


def _parse_iso_date(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d")
    except ValueError:
        return None


def _serialize(row: dict) -> dict:
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "customerName": str(row.get("customername") or "").strip(),
        "notes": str(row.get("notes") or "").strip(),
        "createdAt": _date_only(row.get("createdat")),
    }


@work_reports_bp.get("")
def list_work_reports():
    """List additional work reports (paginated)."""
    table_name = _table_name()
    employee_code, scope_err = resolve_employee_scope(
        request.args.get("employeeCode", "").strip()
    )
    if scope_err is not None:
        return scope_err
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )

    date_from = _parse_iso_date(request.args.get("dateFrom", ""))
    date_to = _parse_iso_date(request.args.get("dateTo", ""))
    if not employee_code and date_from is None and date_to is None:
        date_from = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        ) - timedelta(days=_ADMIN_DEFAULT_DAYS)

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(EMPLOYEECODE) = :employeecode")
        params["employeecode"] = employee_code
    if date_from is not None:
        conditions.append("CREATEDAT >= :date_from")
        params["date_from"] = date_from
    if date_to is not None:
        conditions.append("CREATEDAT < :date_to")
        params["date_to"] = date_to + timedelta(days=1)

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""
    columns_sql = "EMPLOYEECODE, CUSTOMERNAME, NOTES, CREATEDAT"
    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY CREATEDAT DESC NULLS LAST, ROWID DESC
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        rows = [_serialize(row) for row in fetched]

    return jsonify(
        {
            "count": len(rows),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "items": rows,
        }
    )


@work_reports_bp.post("")
def create_work_report():
    """
    Insert a row into CRGS_WORKREPORT for extra work done outside an
    assigned task. Does not create or update CRGS_TASK.
    """
    payload = request.get_json(silent=True) or {}

    employee_code, owned_err = enforce_owned_employee_code(
        payload.get("employeeCode")
    )
    if owned_err is not None:
        return owned_err

    customer_name = _clip(payload.get("customerName", ""), 100)
    notes = _clip(payload.get("notes", ""), 1000)

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if len(employee_code) > 20:
        return jsonify({"error": "Employee code must be 20 characters or fewer"}), 400
    if not customer_name:
        return jsonify({"error": "Customer name is required"}), 400
    if not notes:
        return jsonify({"error": "Notes are required"}), 400

    table_name = _table_name()
    created_at = datetime.now().replace(microsecond=0)

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (
                    EMPLOYEECODE,
                    CUSTOMERNAME,
                    WORKTYPE,
                    NOTES,
                    CREATEDAT
                )
            VALUES
                (
                    :employeecode,
                    :customername,
                    :worktype,
                    :notes,
                    :createdat
                )
            """,
            {
                "employeecode": employee_code,
                "customername": customer_name,
                # WORKTYPE remains NOT NULL in Oracle; default for simplified form.
                "worktype": "additional_work",
                "notes": notes,
                "createdat": created_at,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "customerName": customer_name,
                "notes": notes,
                "createdAt": created_at.date().isoformat(),
            }
        ),
        201,
    )
