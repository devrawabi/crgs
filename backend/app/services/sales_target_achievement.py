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


def _sum_orders_for_target(
    cursor,
    order_hdr_table: str,
    *,
    employee_code: str,
    target_route,
    start: datetime,
    end: datetime,
) -> float:
    cursor.execute(
        f"""
        SELECT
            TRIM(TO_CHAR(ROUTE)) AS ROUTE,
            TOTALAMOUNT
        FROM {order_hdr_table}
        WHERE TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode
          AND TRUNC(ORDERDATE) BETWEEN TRUNC(:start_date) AND TRUNC(:end_date)
        """,
        {
            "employeecode": employee_code,
            "start_date": start,
            "end_date": end,
        },
    )
    total = 0.0
    for route, amount in cursor.fetchall():
        if not _route_matches(target_route, route):
            continue
        try:
            total += float(amount or 0)
        except (TypeError, ValueError):
            continue
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

    Call this after an order is saved so the Achieved column reflects order totals.
    """
    params: dict = {}
    where_sql = ""
    if employee_code:
        where_sql = "WHERE TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode"
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
    updated: list[dict] = []

    for employeecode, period, target, _achieved, route, duedate in rows:
        emp = str(employeecode or "").strip()
        window = period_window(period, duedate)
        if not emp or window is None:
            continue

        start, end = window
        achieved = _sum_orders_for_target(
            cursor,
            order_hdr_table,
            employee_code=emp,
            target_route=route,
            start=start,
            end=end,
        )

        cursor.execute(
            f"""
            UPDATE {sale_targets_table}
            SET ACHIEVED = :achieved
            WHERE TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode
              AND PERIOD = :period
              AND TRIM(TO_CHAR(ROUTE)) = :route
              AND TRUNC(DUEDATE) = TRUNC(:duedate)
            """,
            {
                "achieved": achieved,
                "employeecode": emp,
                "period": period,
                "route": str(route or "").strip(),
                "duedate": duedate if isinstance(duedate, datetime) else _to_date(duedate),
            },
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

    return updated
