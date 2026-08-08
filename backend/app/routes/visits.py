from datetime import datetime, timedelta

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.routes.auth import limiter
from app.security import enforce_owned_employee_code, resolve_employee_scope


visits_bp = Blueprint("visits", __name__)

_DEFAULT_LIMIT = 50
_MAX_LIMIT = 200
_ADMIN_DEFAULT_DAYS = 90


def _table_name():
    return current_app.config["ORACLE_VISITDETAILS_TABLE"]


def _parse_iso_datetime(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).replace(tzinfo=None)
    except ValueError:
        pass
    # Accept time-only values (HH:MM:SS) for VISITSTART / VISITEND.
    for fmt in ("%H:%M:%S", "%H:%M"):
        try:
            parsed = datetime.strptime(text, fmt)
            now = datetime.now()
            return now.replace(
                hour=parsed.hour,
                minute=parsed.minute,
                second=parsed.second,
                microsecond=0,
            )
        except ValueError:
            continue
    return None


def _parse_iso_date(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d")
    except ValueError:
        return None


def _format_duration(seconds: int) -> str:
    total = max(0, int(seconds))
    hours = total // 3600
    minutes = (total % 3600) // 60
    secs = total % 60
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def _format_time_only(value: datetime) -> str:
    """Store VISITSTART / VISITEND as HH:MM:SS only (date goes in VISITDATE)."""
    return value.strftime("%H:%M:%S")


def _date_only(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    return text[:10]


def _serialize_visit(row: dict) -> dict:
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "customerCode": str(row.get("customercode") or "").strip(),
        "customerName": str(row.get("customername") or "").strip(),
        "route": str(row.get("route") or "").strip(),
        "visitDate": _date_only(row.get("visitdate")),
        "visitStart": str(row.get("visitstart") or "").strip(),
        "visitEnd": str(row.get("visitend") or "").strip(),
        "totalDuration": str(row.get("totalduration") or "").strip(),
        "location": str(row.get("location") or "").strip(),
        "reason": str(row.get("reason") or "").strip(),
        "remarks": str(row.get("remarks") or "").strip(),
        "followUp": _date_only(row.get("followupdate")),
    }


@visits_bp.get("")
@limiter.limit("90 per minute")
def list_visits():
    """List visit rows from CRGS_VISITDETAILS (paginated)."""
    table_name = _table_name()
    employee_code, scope_err = resolve_employee_scope(
        request.args.get("employeeCode", "").strip()
    )
    if scope_err is not None:
        return scope_err
    customer_code = str(request.args.get("customerCode", "")).strip()
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )

    date_from = _parse_iso_date(request.args.get("dateFrom", ""))
    date_to = _parse_iso_date(request.args.get("dateTo", ""))
    # Admin unscoped list without dates walks the full visit history.
    if not employee_code and not customer_code and date_from is None and date_to is None:
        date_from = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        ) - timedelta(days=_ADMIN_DEFAULT_DAYS)

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(EMPLOYEECODE) = :employeecode")
        params["employeecode"] = employee_code
    if customer_code:
        conditions.append("TRIM(CUSTOMERCODE) = :customercode")
        params["customercode"] = customer_code
    if date_from is not None:
        conditions.append("VISITDATE >= :date_from")
        params["date_from"] = date_from
    if date_to is not None:
        conditions.append("VISITDATE < :date_to")
        params["date_to"] = date_to + timedelta(days=1)

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""
    columns_sql = (
        "EMPLOYEECODE, CUSTOMERCODE, CUSTOMERNAME, ROUTE, VISITDATE, "
        "VISITSTART, VISITEND, TOTALDURATION, LOCATION, REASON, REMARKS, FOLLOWUPDATE"
    )
    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY VISITDATE DESC NULLS LAST,
                 VISITSTART DESC NULLS LAST,
                 CUSTOMERNAME
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        rows = [_serialize_visit(row) for row in fetched]

    return jsonify(
        {
            "count": len(rows),
            "offset": offset,
            "limit": limit,
            "has_more": has_more,
            "visits": rows,
        }
    )


@visits_bp.post("/start")
@limiter.limit("60 per minute")
def start_visit():
    """Insert a row into CRGS_VISITDETAILS when a visit begins.

    Idempotent for an open visit (VISITEND IS NULL) for the same
    employee + customer so mobile retries after timeouts don't duplicate rows.
    """
    payload = request.get_json(silent=True) or {}

    employee_code, owned_err = enforce_owned_employee_code(
        payload.get("employeeCode")
    )
    if owned_err is not None:
        return owned_err
    customer_code = str(payload.get("customerCode", "")).strip()
    customer_name = str(payload.get("customerName", "")).strip()
    route = str(payload.get("route", "")).strip() or "-"
    location = str(payload.get("location", "")).strip() or None
    reason = str(payload.get("reason", "")).strip() or None
    remarks = str(payload.get("remarks", "")).strip() or None
    follow_up = _parse_iso_date(payload.get("followUp", ""))
    visit_start = _parse_iso_datetime(payload.get("visitStart", ""))
    visit_date = _parse_iso_date(payload.get("visitDate", ""))

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not customer_code:
        return jsonify({"error": "Customer code is required"}), 400
    if not customer_name:
        return jsonify({"error": "Customer name is required"}), 400
    if visit_start is None:
        visit_start = datetime.now()
    # Truncate micros so start/end round-trips match Oracle TIMESTAMP equality.
    visit_start = visit_start.replace(microsecond=0)
    if visit_date is None:
        visit_date = visit_start.replace(hour=0, minute=0, second=0, microsecond=0)

    if len(employee_code) > 20:
        return jsonify({"error": "Employee code must be 20 characters or fewer"}), 400
    if len(customer_code) > 20:
        return jsonify({"error": "Customer code must be 20 characters or fewer"}), 400
    if len(customer_name) > 100:
        return jsonify({"error": "Customer name must be 100 characters or fewer"}), 400
    if len(route) > 20:
        route = route[:20]
    if location and len(location) > 255:
        location = location[:255]
    if reason and len(reason) > 200:
        reason = reason[:200]
    if remarks and len(remarks) > 500:
        remarks = remarks[:500]

    table_name = _table_name()
    columns_sql = (
        "EMPLOYEECODE, CUSTOMERCODE, CUSTOMERNAME, ROUTE, VISITDATE, "
        "VISITSTART, VISITEND, TOTALDURATION, LOCATION, REASON, REMARKS, FOLLOWUPDATE"
    )

    with oracle_cursor() as cursor:
        # Reuse an existing open visit so retries after connection timeouts
        # don't create duplicate CRGS_VISITDETAILS rows.
        # ROWNUM (not FETCH FIRST) — Oracle 11g rejects FETCH FIRST with ORA-00933.
        cursor.execute(
            f"""
            SELECT {columns_sql}
            FROM (
                SELECT inner_query.*, ROWNUM AS rnum
                FROM (
                    SELECT {columns_sql}
                    FROM {table_name}
                    WHERE TRIM(EMPLOYEECODE) = :employeecode
                      AND TRIM(CUSTOMERCODE) = :customercode
                      AND VISITEND IS NULL
                    ORDER BY VISITDATE DESC NULLS LAST, VISITSTART DESC NULLS LAST
                ) inner_query
                WHERE ROWNUM <= 1
            )
            """,
            {
                "employeecode": employee_code,
                "customercode": customer_code,
            },
        )
        existing = cursor.fetchone()
        if existing is not None:
            row = _serialize_visit(row_to_dict(cursor, existing))
            return jsonify({**row, "reused": True}), 200

        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (
                    EMPLOYEECODE,
                    CUSTOMERCODE,
                    CUSTOMERNAME,
                    ROUTE,
                    VISITDATE,
                    VISITSTART,
                    LOCATION,
                    REASON,
                    REMARKS,
                    FOLLOWUPDATE
                )
            VALUES
                (
                    :employeecode,
                    :customercode,
                    :customername,
                    :route,
                    :visitdate,
                    :visitstart,
                    :location,
                    :reason,
                    :remarks,
                    :followup
                )
            """,
            {
                "employeecode": employee_code,
                "customercode": customer_code,
                "customername": customer_name,
                "route": route,
                "visitdate": visit_date,
                "visitstart": _format_time_only(visit_start),
                "location": location,
                "reason": reason,
                "remarks": remarks,
                "followup": follow_up,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "customerCode": customer_code,
                "customerName": customer_name,
                "route": route,
                "visitDate": visit_date.date().isoformat(),
                "visitStart": _format_time_only(visit_start),
                "location": location or "",
                "reused": False,
            }
        ),
        201,
    )


@visits_bp.post("/end")
@limiter.limit("60 per minute")
def end_visit():
    """Update VISITEND and TOTALDURATION (and form fields) when a visit ends."""
    payload = request.get_json(silent=True) or {}

    employee_code, owned_err = enforce_owned_employee_code(
        payload.get("employeeCode")
    )
    if owned_err is not None:
        return owned_err
    customer_code = str(payload.get("customerCode", "")).strip()
    visit_start = _parse_iso_datetime(payload.get("visitStart", ""))
    visit_end = _parse_iso_datetime(payload.get("visitEnd", ""))
    location = str(payload.get("location", "")).strip() or None
    reason = str(payload.get("reason", "")).strip() or None
    remarks = str(payload.get("remarks", "")).strip() or None
    follow_up = _parse_iso_date(payload.get("followUp", ""))

    total_duration = str(payload.get("totalDuration", "")).strip()
    if not total_duration and "durationSeconds" in payload:
        try:
            total_duration = _format_duration(int(payload.get("durationSeconds", 0)))
        except (TypeError, ValueError):
            total_duration = ""

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not customer_code:
        return jsonify({"error": "Customer code is required"}), 400
    if visit_start is None:
        return jsonify({"error": "Visit start time is required"}), 400
    visit_start = visit_start.replace(microsecond=0)
    if visit_end is None:
        visit_end = datetime.now()
    visit_end = visit_end.replace(microsecond=0)
    if not total_duration:
        seconds = int((visit_end - visit_start).total_seconds())
        total_duration = _format_duration(seconds)

    if location and len(location) > 255:
        location = location[:255]
    if reason and len(reason) > 200:
        reason = reason[:200]
    if remarks and len(remarks) > 500:
        remarks = remarks[:500]
    if len(total_duration) > 20:
        total_duration = total_duration[:20]

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            UPDATE {table_name}
            SET
                VISITEND = :visitend,
                TOTALDURATION = :totalduration,
                LOCATION = NVL(:location, LOCATION),
                REASON = NVL(:reason, REASON),
                REMARKS = NVL(:remarks, REMARKS),
                FOLLOWUPDATE = NVL(:followup, FOLLOWUPDATE)
            WHERE TRIM(EMPLOYEECODE) = :employeecode
              AND TRIM(CUSTOMERCODE) = :customercode
              AND VISITEND IS NULL
              AND TRIM(VISITSTART) = :visitstart
            """,
            {
                "visitend": _format_time_only(visit_end),
                "totalduration": total_duration,
                "location": location,
                "reason": reason,
                "remarks": remarks,
                "followup": follow_up,
                "employeecode": employee_code,
                "customercode": customer_code,
                "visitstart": _format_time_only(visit_start),
            },
        )
        updated = cursor.rowcount

        # Fallback: close the latest open visit for this employee/customer.
        if updated == 0:
            cursor.execute(
                f"""
                UPDATE {table_name}
                SET
                    VISITEND = :visitend,
                    TOTALDURATION = :totalduration,
                    LOCATION = NVL(:location, LOCATION),
                    REASON = NVL(:reason, REASON),
                    REMARKS = NVL(:remarks, REMARKS),
                    FOLLOWUPDATE = NVL(:followup, FOLLOWUPDATE)
                WHERE ROWID = (
                    SELECT rid FROM (
                        SELECT inner_query.rid, ROWNUM AS rnum
                        FROM (
                            SELECT ROWID AS rid
                            FROM {table_name}
                            WHERE TRIM(EMPLOYEECODE) = :employeecode
                              AND TRIM(CUSTOMERCODE) = :customercode
                              AND VISITEND IS NULL
                            ORDER BY VISITDATE DESC NULLS LAST,
                                     VISITSTART DESC NULLS LAST
                        ) inner_query
                        WHERE ROWNUM <= 1
                    )
                )
                """,
                {
                    "visitend": _format_time_only(visit_end),
                    "totalduration": total_duration,
                    "location": location,
                    "reason": reason,
                    "remarks": remarks,
                    "followup": follow_up,
                    "employeecode": employee_code,
                    "customercode": customer_code,
                },
            )
            updated = cursor.rowcount

        get_connection().commit()

    if updated == 0:
        return jsonify({"error": "Visit not found"}), 404

    return jsonify(
        {
            "employeeCode": employee_code,
            "customerCode": customer_code,
            "visitStart": _format_time_only(visit_start),
            "visitEnd": _format_time_only(visit_end),
            "totalDuration": total_duration,
            "location": location or "",
            "reason": reason or "",
            "remarks": remarks or "",
            "followUp": follow_up.date().isoformat() if follow_up else "",
        }
    )
