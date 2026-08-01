"""Shared limit/offset and keyset helpers for Oracle pagination."""

from __future__ import annotations

from flask import request

# Deep ROWNUM offsets get expensive; prefer keyset for catalog-scale walks.
DEFAULT_MAX_OFFSET = 50_000


def parse_int(raw, default: int, *, min_value: int, max_value: int) -> int:
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return default
    return max(min_value, min(value, max_value))


def parse_limit_offset(
    *,
    default_limit: int,
    max_limit: int,
    max_offset: int = DEFAULT_MAX_OFFSET,
) -> tuple[int, int]:
    """Parse `limit` / `offset` query args with safe bounds."""
    limit = parse_int(
        request.args.get("limit", default_limit),
        default_limit,
        min_value=1,
        max_value=max_limit,
    )
    offset = parse_int(
        request.args.get("offset", 0),
        0,
        min_value=0,
        max_value=max_offset,
    )
    return limit, offset


def apply_has_more(rows: list, limit: int) -> tuple[list, bool]:
    """Trim a limit+1 fetch and return (page_rows, has_more)."""
    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]
    return rows, has_more


def rownum_page_sql(
    inner_sql: str,
    columns_sql: str = "*",
) -> str:
    """
    Wrap an ordered inner SELECT with classic Oracle ROWNUM paging.

    Caller must bind :max_row and :min_row (offset+fetch_limit / offset).
    `inner_sql` should already include ORDER BY.

    Prefer keyset (`WHERE (sort_key) > (:cursor…)`) for deep catalog sync;
    deep ROWNUM offsets still sort/scan prior rows.
    """
    return f"""
        SELECT {columns_sql}
        FROM (
            SELECT inner_query.*, ROWNUM AS rnum
            FROM (
                {inner_sql}
            ) inner_query
            WHERE ROWNUM <= :max_row
        )
        WHERE rnum > :min_row
    """


def rownum_limit_sql(inner_sql: str, columns_sql: str = "*") -> str:
    """
    First-page / keyset fetch: ORDER BY already applied, take ROWNUM <= :max_row.
    Caller binds :max_row = limit+1 for has_more.
    """
    return f"""
        SELECT {columns_sql}
        FROM (
            SELECT inner_query.*, ROWNUM AS rnum
            FROM (
                {inner_sql}
            ) inner_query
            WHERE ROWNUM <= :max_row
        )
    """
