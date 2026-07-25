"""Market research — list/insert CRGS_MARKETRESEARCH."""

from flask import Blueprint, current_app, jsonify, request

from app.db import get_connection, oracle_cursor, row_to_dict

market_research_bp = Blueprint("market_research", __name__)


def _table_name() -> str:
    return current_app.config["ORACLE_MARKETRESEARCH_TABLE"]


def _clip(value: str, max_len: int) -> str:
    text = str(value or "").strip()
    if len(text) > max_len:
        return text[:max_len]
    return text


def _serialize_research(row: dict) -> dict:
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "route": str(row.get("route") or "").strip(),
        "marketTrend": str(row.get("markettrend") or "").strip(),
        "fastMovingProducts": str(row.get("fastmovingproducts") or "").strip(),
        "slowMovingProducts": str(row.get("slowmovingproducts") or "").strip(),
        "competitorPromotions": str(row.get("competitorpromotions") or "").strip(),
        "newOpportunities": str(row.get("newopportunities") or "").strip(),
        "notes": str(row.get("notes") or "").strip(),
    }


@market_research_bp.get("")
def list_market_research():
    """List market research rows, optionally filtered by employee/route."""
    table_name = _table_name()
    employee_code = str(request.args.get("employeeCode", "")).strip()
    route = str(request.args.get("route", "")).strip()

    conditions: list[str] = []
    params: dict = {}
    if employee_code:
        conditions.append("TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode")
        params["employeecode"] = employee_code
    if route:
        conditions.append("TRIM(TO_CHAR(ROUTE)) = :route")
        params["route"] = route

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                EMPLOYEECODE,
                ROUTE,
                MARKETTREND,
                FASTMOVINGPRODUCTS,
                SLOWMOVINGPRODUCTS,
                COMPETITORPROMOTIONS,
                NEWOPPORTUNITIES,
                NOTES
            FROM {table_name}
            {where_sql}
            ORDER BY ROWID DESC
            """,
            params,
        )
        rows = [
            _serialize_research(row_to_dict(cursor, row))
            for row in cursor.fetchall()
        ]

    return jsonify({"count": len(rows), "items": rows})


@market_research_bp.post("")
def create_market_research():
    """
    Insert a row into CRGS_MARKETRESEARCH:
    EMPLOYEECODE, ROUTE, MARKETTREND, FASTMOVINGPRODUCTS, SLOWMOVINGPRODUCTS,
    COMPETITORPROMOTIONS, NEWOPPORTUNITIES, NOTES
    """
    payload = request.get_json(silent=True) or {}

    employee_code = str(payload.get("employeeCode", "")).strip()
    route = str(payload.get("route", "")).strip()
    market_trend = _clip(payload.get("marketTrend", ""), 500)
    fast_moving = _clip(payload.get("fastMovingProducts", ""), 500)
    slow_moving = _clip(payload.get("slowMovingProducts", ""), 500)
    competitor_promotions = _clip(payload.get("competitorPromotions", ""), 500)
    new_opportunities = _clip(payload.get("newOpportunities", ""), 500)
    notes = _clip(payload.get("notes", ""), 1000)

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route:
        return jsonify({"error": "Route is required"}), 400

    if len(employee_code) > 20:
        return jsonify({"error": "Employee code must be 20 characters or fewer"}), 400
    if len(route) > 20:
        return jsonify({"error": "Route must be 20 characters or fewer"}), 400

    # Require at least one research field so empty submits are rejected.
    if not any(
        (
            market_trend,
            fast_moving,
            slow_moving,
            competitor_promotions,
            new_opportunities,
            notes,
        )
    ):
        return jsonify({"error": "Enter at least one research field"}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (
                    EMPLOYEECODE,
                    ROUTE,
                    MARKETTREND,
                    FASTMOVINGPRODUCTS,
                    SLOWMOVINGPRODUCTS,
                    COMPETITORPROMOTIONS,
                    NEWOPPORTUNITIES,
                    NOTES
                )
            VALUES
                (
                    :employeecode,
                    :route,
                    :markettrend,
                    :fastmovingproducts,
                    :slowmovingproducts,
                    :competitorpromotions,
                    :newopportunities,
                    :notes
                )
            """,
            {
                "employeecode": employee_code,
                "route": route,
                "markettrend": market_trend or None,
                "fastmovingproducts": fast_moving or None,
                "slowmovingproducts": slow_moving or None,
                "competitorpromotions": competitor_promotions or None,
                "newopportunities": new_opportunities or None,
                "notes": notes or None,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "route": route,
                "marketTrend": market_trend,
                "fastMovingProducts": fast_moving,
                "slowMovingProducts": slow_moving,
                "competitorPromotions": competitor_promotions,
                "newOpportunities": new_opportunities,
                "notes": notes,
            }
        ),
        201,
    )
