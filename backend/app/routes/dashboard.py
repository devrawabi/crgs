"""Aggregated dashboard KPIs — avoids full-list walks on the admin UI."""

from __future__ import annotations

from flask import Blueprint, current_app, jsonify

from app.cache import cache_get, cache_set
from app.db import oracle_cursor, row_to_dict
from app.pagination import rownum_page_sql
from app.routes.auth import limiter
from app.security import require_full_admin

dashboard_bp = Blueprint("dashboard", __name__)

_PERIOD_MONTHLY = "M"
_ACTIVE_FLAG = "A"
_SUMMARY_CACHE_KEY = "dashboard:summary"
_SUMMARY_CACHE_TTL_SECONDS = 180


def _username_display(username: str) -> str:
    text = (username or "").strip()
    if not text:
        return ""
    return text.split(".")[0] or text


def _parse_routes(route_value) -> list[str]:
    text = str(route_value or "").strip()
    if not text:
        return []
    parts = []
    for chunk in text.replace(";", ",").split(","):
        route = chunk.strip()
        if route:
            parts.append(route)
    return parts


@dashboard_bp.get("/summary")
@limiter.limit("60 per minute")
@require_full_admin
def dashboard_summary():
    """
    One-shot dashboard payload: active users, target rollups, task stats.

    Replaces admin multi-fetch of full users/tasks/targets tables.
    """
    cached = cache_get(_SUMMARY_CACHE_KEY)
    if cached is not None:
        return jsonify(cached)

    users_table = current_app.config["ORACLE_LOGIN_USERS_TABLE"]
    sales_table = current_app.config["ORACLE_SALE_TARGETS_TABLE"]
    product_table = current_app.config["ORACLE_PRODUCT_TARGETS_TABLE"]
    customer_table = current_app.config["ORACLE_CUSTOMER_TARGETS_TABLE"]
    tasks_table = current_app.config["ORACLE_TASKS_TABLE"]

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            SELECT USERNAME, EMPLOYEECODE, ROUTE
            FROM {users_table}
            WHERE FLAG = :flag
            ORDER BY USERNAME
            """,
            {"flag": _ACTIVE_FLAG},
        )
        executives = []
        assigned_routes: set[str] = set()
        name_by_code: dict[str, str] = {}
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            code = str(item.get("employeecode") or "").strip()
            username = str(item.get("username") or "").strip()
            routes = _parse_routes(item.get("route"))
            for route in routes:
                assigned_routes.add(route)
            if code:
                name_by_code[code.upper()] = username
            executives.append(
                {
                    "employeeCode": code,
                    "username": username,
                    "displayName": _username_display(username),
                    "routeNos": routes,
                }
            )

        cursor.execute(
            f"""
            SELECT
                NVL(SUM(TARGET), 0) AS target_total,
                NVL(SUM(ACHIEVED), 0) AS achieved_total
            FROM {sales_table}
            WHERE PERIOD = :period
            """,
            {"period": _PERIOD_MONTHLY},
        )
        sales_totals = row_to_dict(cursor, cursor.fetchone() or (0, 0))

        cursor.execute(
            f"""
            SELECT
                TRIM(EMPLOYEECODE) AS employeecode,
                NVL(SUM(TARGET), 0) AS target_total,
                NVL(SUM(ACHIEVED), 0) AS achieved_total
            FROM {sales_table}
            WHERE PERIOD = :period
            GROUP BY TRIM(EMPLOYEECODE)
            """,
            {"period": _PERIOD_MONTHLY},
        )
        sales_by_employee: dict[str, dict[str, float]] = {}
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            code = str(item.get("employeecode") or "").strip().upper()
            if not code:
                continue
            sales_by_employee[code] = {
                "target": float(item.get("target_total") or 0),
                "achieved": float(item.get("achieved_total") or 0),
            }

        cursor.execute(
            f"""
            SELECT
                TRIM(ROUTE) AS route,
                NVL(SUM(TARGET), 0) AS target_total,
                NVL(SUM(ACHIEVED), 0) AS achieved_total
            FROM {sales_table}
            WHERE PERIOD = :period
            GROUP BY TRIM(ROUTE)
            ORDER BY TRIM(ROUTE)
            """,
            {"period": _PERIOD_MONTHLY},
        )
        sales_by_route = []
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            route = str(item.get("route") or "").strip() or "Unassigned"
            sales_by_route.append(
                {
                    "name": route,
                    "target": float(item.get("target_total") or 0),
                    "achieved": float(item.get("achieved_total") or 0),
                }
            )

        cursor.execute(
            f"""
            SELECT
                NVL(SUM(TARGET), 0) AS target_total,
                NVL(SUM(ACHIEVED), 0) AS achieved_total
            FROM {product_table}
            """
        )
        product_totals = row_to_dict(cursor, cursor.fetchone() or (0, 0))

        cursor.execute(
            f"""
            SELECT
                NVL(SUM(TARGET), 0) AS target_total,
                NVL(SUM(ACHIEVED), 0) AS achieved_total
            FROM {customer_table}
            """
        )
        customer_totals = row_to_dict(cursor, cursor.fetchone() or (0, 0))

        cursor.execute(
            f"""
            SELECT LOWER(TRIM(TYPE)) AS type, COUNT(*) AS task_count
            FROM {tasks_table}
            GROUP BY LOWER(TRIM(TYPE))
            """
        )
        task_breakdown = []
        task_total = 0
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            count = int(item.get("task_count") or 0)
            task_total += count
            task_type = str(item.get("type") or "").strip()
            if task_type:
                task_breakdown.append({"type": task_type, "count": count})

        cursor.execute(
            f"""
            SELECT COUNT(*) AS overdue_count
            FROM {tasks_table}
            WHERE LOWER(TRIM(STATUS)) = 'overdue'
               OR (
                    LOWER(TRIM(STATUS)) NOT IN ('completed', 'done', 'complete')
                    AND DUEDATE IS NOT NULL
                    AND TRUNC(DUEDATE) < TRUNC(SYSDATE)
               )
            """
        )
        overdue_row = row_to_dict(cursor, cursor.fetchone() or (0,))
        overdue_count = int(overdue_row.get("overdue_count") or 0)

        recent_inner = f"""
            SELECT TYPE, EMPLOYEECODE, ROUTE, STATUS, DUEDATE
            FROM {tasks_table}
            ORDER BY DUEDATE DESC NULLS LAST, EMPLOYEECODE, ROUTE
        """
        recent_sql = rownum_page_sql(
            recent_inner,
            columns_sql="TYPE, EMPLOYEECODE, ROUTE, STATUS, DUEDATE",
        )
        cursor.execute(
            recent_sql,
            {"max_row": 5, "min_row": 0},
        )
        recent_tasks = []
        for row in cursor.fetchall():
            item = row_to_dict(cursor, row)
            code = str(item.get("employeecode") or "").strip()
            due = item.get("duedate")
            due_str = str(due).strip()[:10] if due is not None else ""
            recent_tasks.append(
                {
                    "type": str(item.get("type") or "").strip().lower(),
                    "employeeCode": code,
                    "executiveName": name_by_code.get(code.upper(), code),
                    "routeNo": (
                        str(item.get("route")).strip()
                        if item.get("route") is not None
                        else ""
                    ),
                    "status": str(item.get("status") or "").strip().lower(),
                    "dueDate": due_str,
                }
            )

    exec_performance = []
    for exec_row in executives:
        code = exec_row["employeeCode"].upper()
        totals = sales_by_employee.get(code) or {"target": 0.0, "achieved": 0.0}
        exec_performance.append(
            {
                "name": exec_row["displayName"] or exec_row["username"] or code,
                "employeeCode": exec_row["employeeCode"],
                "target": totals["target"],
                "achieved": totals["achieved"],
            }
        )

    payload = {
        "activeExecutives": len(executives),
        "assignedRoutes": len(assigned_routes),
        "sales": {
            "period": "monthly",
            "targetTotal": float(sales_totals.get("target_total") or 0),
            "achievedTotal": float(sales_totals.get("achieved_total") or 0),
            "byExecutive": exec_performance,
            "byRoute": sales_by_route,
        },
        "products": {
            "targetTotal": float(product_totals.get("target_total") or 0),
            "achievedTotal": float(product_totals.get("achieved_total") or 0),
        },
        "customers": {
            "targetTotal": float(customer_totals.get("target_total") or 0),
            "achievedTotal": float(customer_totals.get("achieved_total") or 0),
        },
        "tasks": {
            "total": task_total,
            "overdue": overdue_count,
            "breakdown": task_breakdown,
            "recent": recent_tasks,
        },
    }
    cache_set(_SUMMARY_CACHE_KEY, payload, ttl_seconds=_SUMMARY_CACHE_TTL_SECONDS)
    return jsonify(payload)
