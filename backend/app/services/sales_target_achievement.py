"""Update CRGS_SALETARGET.ACHIEVED from CRGS_ORDERHDR.TOTALAMOUNT."""

from __future__ import annotations

from calendar import monthrange
from datetime import datetime, timedelta


def _normalize_route_no(value) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    try:
        number = float(text)
        if number.is_integer():
            return str(int(number))
    except (TypeError, ValueError):
        pass
    return text


def parse_route_column(route) -> list[str]:
    text = str(route or "").strip()
    if not text:
        return []
    routes: list[str] = []
    seen: set[str] = set()
    for part in text.split(","):
        normalized = _normalize_route_no(part)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        routes.append(normalized)
    return routes


def _to_date(value) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.replace(hour=0, minute=0, second=0, microsecond=0)
    text = str(value).strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d")
    except ValueError:
        return None


def period_window(period, due_date) -> tuple[datetime, datetime] | None:
    """Inclusive [start, end] for the target period ending on due_date."""
    due = _to_date(due_date)
    if due is None:
        return None

    code = str(period or "").strip().upper()
    if code in ("D", "DAILY"):
        return due, due
    if code in ("W", "WEEKLY"):
        return due - timedelta(days=6), due

    start = due.replace(day=1)
    last_day = monthrange(due.year, due.month)[1]
    end = due.replace(day=last_day)
    return start, end


def _route_matches(target_route, order_route: str) -> bool:
    order_normalized = _normalize_route_no(order_route)
    if not order_normalized:
        return False
    return order_normalized in parse_route_column(target_route)


def _fetch_orders_for_employees(
    cursor,
    order_hdr_table: str,
    *,
    employee_codes: set[str],
    start: datetime,
    end: datetime,
) -> dict[str, list[tuple[str, datetime | None, float]]]:
    """
    One round-trip: orders for all employees in [start, end].

    Returns {employee_code: [(route, order_date, amount), ...]}.
    """
    if not employee_codes:
        return {}

    # Bind a small IN-list (typical: 1 employee after order save).
    binds: dict = {"start_date": start, "end_date": end}
    placeholders: list[str] = []
    for index, code in enumerate(sorted(employee_codes)):
        key = f"emp_{index}"
        binds[key] = code
        placeholders.append(f":{key}")

    cursor.execute(
        f"""
        SELECT
            TRIM(EMPLOYEECODE) AS EMPLOYEECODE,
            TRIM(ROUTE) AS ROUTE,
            TRUNC(ORDERDATE) AS ORDERDATE,
            TOTALAMOUNT
        FROM {order_hdr_table}
        WHERE TRIM(EMPLOYEECODE) IN ({", ".join(placeholders)})
          AND TRUNC(ORDERDATE) BETWEEN TRUNC(:start_date) AND TRUNC(:end_date)
        """,
        binds,
    )

    by_employee: dict[str, list[tuple[str, datetime | None, float]]] = {
        code: [] for code in employee_codes
    }
    for emp, route, order_date, amount in cursor.fetchall():
        emp_key = str(emp or "").strip()
        if emp_key not in by_employee:
            continue
        try:
            amt = float(amount or 0)
        except (TypeError, ValueError):
            continue
        order_dt = _to_date(order_date)
        by_employee[emp_key].append((str(route or "").strip(), order_dt, amt))
    return by_employee


def _sum_from_orders(
    orders: list[tuple[str, datetime | None, float]],
    *,
    target_route,
    start: datetime,
    end: datetime,
) -> float:
    total = 0.0
    for route, order_date, amount in orders:
        if order_date is None or order_date < start or order_date > end:
            continue
        if not _route_matches(target_route, route):
            continue
        total += amount
    return round(total, 2)


def refresh_sales_target_achieved(
    cursor,
    *,
    sale_targets_table: str,
    order_hdr_table: str,
    employee_code: str | None = None,
) -> list[dict]:
    """
    Set ACHIEVED = SUM(matching order TOTALAMOUNT) for sales targets.

    Batched: 1 target SELECT + 1 order SELECT + 1 executemany UPDATE
    (avoids per-target N+1 round-trips after order save).
    """
    params: dict = {}
    where_sql = ""
    if employee_code:
        where_sql = "WHERE TRIM(EMPLOYEECODE) = :employeecode"
        params["employeecode"] = str(employee_code).strip()

    cursor.execute(
        f"""
        SELECT EMPLOYEECODE, PERIOD, TARGET, ACHIEVED, ROUTE, DUEDATE
        FROM {sale_targets_table}
        {where_sql}
        """,
        params,
    )
    rows = cursor.fetchall()
    if not rows:
        return []

    prepared: list[tuple] = []
    employee_codes: set[str] = set()
    min_start: datetime | None = None
    max_end: datetime | None = None

    for employeecode, period, target, _achieved, route, duedate in rows:
        emp = str(employeecode or "").strip()
        window = period_window(period, duedate)
        if not emp or window is None:
            continue
        start, end = window
        employee_codes.add(emp)
        if min_start is None or start < min_start:
            min_start = start
        if max_end is None or end > max_end:
            max_end = end
        prepared.append((emp, period, target, route, duedate, start, end))

    if not prepared or min_start is None or max_end is None:
        return []

    orders_by_emp = _fetch_orders_for_employees(
        cursor,
        order_hdr_table,
        employee_codes=employee_codes,
        start=min_start,
        end=max_end,
    )

    updated: list[dict] = []
    update_binds: list[dict] = []

    for emp, period, target, route, duedate, start, end in prepared:
        achieved = _sum_from_orders(
            orders_by_emp.get(emp, []),
            target_route=route,
            start=start,
            end=end,
        )
        due_value = duedate if isinstance(duedate, datetime) else _to_date(duedate)
        update_binds.append(
            {
                "achieved": achieved,
                "employeecode": emp,
                "period": period,
                "route": str(route or "").strip(),
                "duedate": due_value,
            }
        )
        target_amount = float(target or 0)
        updated.append(
            {
                "employeeCode": emp,
                "period": str(period or "").strip(),
                "routeNo": str(route or "").strip(),
                "dueDate": (
                    duedate.date().isoformat()
                    if isinstance(duedate, datetime)
                    else str(duedate or "")[:10]
                ),
                "targetAmount": target_amount,
                "achievedAmount": achieved,
                "remainingAmount": round(target_amount - achieved, 2),
            }
        )

    if update_binds:
        cursor.executemany(
            f"""
            UPDATE {sale_targets_table}
            SET ACHIEVED = :achieved
            WHERE TRIM(EMPLOYEECODE) = :employeecode
              AND PERIOD = :period
              AND TRIM(ROUTE) = :route
              AND TRUNC(DUEDATE) = TRUNC(:duedate)
            """,
            update_binds,
        )

    return updated
