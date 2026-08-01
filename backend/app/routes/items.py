"""ITEMMASTER catalog API — paginated, optionally incremental, validated."""

from __future__ import annotations

import logging
import re
from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, request

from app.db import oracle_cursor, row_to_dict
from app.pagination import rownum_limit_sql, rownum_page_sql
from app.routes.auth import limiter

logger = logging.getLogger(__name__)

items_bp = Blueprint("items", __name__)

ITEM_COLUMNS = (
    "ITEMCODE",
    "ITEMNAME",
    "BASEUOM",
    "RETAILPRICE",
    "CURRENTSTOCK",
    "QUANTITYLIMIT",
    # CHAR/VARCHAR — values like 'Y' / 'Y ' / 'N' (trimmed in _normalize_item).
    "OWNPRODUCT",
)

# Safe Oracle identifier (table / column names from config only).
_IDENT_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_$#]*$")

# Defaults tuned for field-sales sync: ~500–1000 rows/request.
_DEFAULT_LIMIT = 750
_MAX_LIMIT = 1000
_MAX_SEARCH_LEN = 80
# Cap ROWNUM deep-offset; catalog sync should use keyset cursors instead.
_MAX_OFFSET = 50_000
_DELTA_COLUMN_CANDIDATES = ("LAST_UPDATED", "LASTUPDATED", "UPDATED_AT", "MODIFIED_DATE")


def _safe_ident(value: str, fallback: str) -> str:
    raw = (value or "").strip()
    if raw and _IDENT_RE.match(raw):
        return raw.upper()
    return fallback


def _parse_int(raw, default: int, *, min_value: int, max_value: int) -> int:
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return default
    return max(min_value, min(value, max_value))


def _parse_updated_since(raw: str | None) -> datetime | None:
    """Parse ISO-8601 / Oracle-friendly timestamps from the client."""
    if not raw:
        return None
    text = raw.strip()
    if not text:
        return None
    # Accept trailing Z
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
            try:
                dt = datetime.strptime(text, fmt)
                break
            except ValueError:
                dt = None
        if dt is None:
            return None
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _updated_column_configured() -> str | None:
    """Return configured LAST_UPDATED-style column name, or None if unset."""
    configured = (current_app.config.get("ORACLE_ITEMMASTER_UPDATED_COLUMN") or "").strip()
    if not configured:
        return None
    if not _IDENT_RE.match(configured):
        logger.warning("Ignoring invalid ORACLE_ITEMMASTER_UPDATED_COLUMN=%r", configured)
        return None
    return configured.upper()


def _resolve_updated_column(cursor, table_name: str) -> str | None:
    """
    Resolve delta timestamp column.

    Uses ORACLE_ITEMMASTER_UPDATED_COLUMN when set and present; otherwise
    auto-detects common names so delta sync works after DBA adds LAST_UPDATED.
    """
    configured = _updated_column_configured()
    if configured and _column_exists(cursor, table_name, configured):
        return configured

    cache_key = f"_item_delta_col_{table_name}"
    cached = current_app.config.get(cache_key)
    if cached is not None:
        return cached or None

    found = None
    for candidate in _DELTA_COLUMN_CANDIDATES:
        if configured and candidate == configured:
            continue
        if _column_exists(cursor, table_name, candidate):
            found = candidate
            break
    current_app.config[cache_key] = found or ""
    return found


def _column_exists(cursor, table_name: str, column_name: str) -> bool:
    cache_key = f"_item_col_{table_name}_{column_name}"
    cached = current_app.config.get(cache_key)
    if cached is not None:
        return bool(cached)

    cursor.execute(
        """
        SELECT COUNT(*)
        FROM USER_TAB_COLUMNS
        WHERE TABLE_NAME = :table_name
          AND COLUMN_NAME = :column_name
        """,
        {"table_name": table_name.upper(), "column_name": column_name.upper()},
    )
    exists = int(cursor.fetchone()[0] or 0) > 0
    if not exists:
        # Also check ALL_TAB_COLUMNS in case the table is in another schema synonym.
        cursor.execute(
            """
            SELECT COUNT(*)
            FROM ALL_TAB_COLUMNS
            WHERE UPPER(TABLE_NAME) = :table_name
              AND COLUMN_NAME = :column_name
              AND ROWNUM = 1
            """,
            {"table_name": table_name.upper(), "column_name": column_name.upper()},
        )
        exists = int(cursor.fetchone()[0] or 0) > 0

    current_app.config[cache_key] = exists
    return exists


def _as_own_product_flag(raw) -> bool:
    """ITEMMASTER.OWNPRODUCT is typically 'Y' / 'N' (may include spaces like 'Y ')."""
    if raw is None:
        return False
    if isinstance(raw, bool):
        return raw
    text = "".join(str(raw).split()).upper()
    return text in {"Y", "YES", "1", "TRUE", "T"}


def _normalize_item(item: dict, updated_col: str | None) -> dict:
    if item.get("itemcode") is not None:
        item["itemcode"] = str(item["itemcode"]).strip()
    if item.get("itemname") is not None:
        item["itemname"] = str(item["itemname"]).strip()
    if item.get("baseuom") is not None:
        item["baseuom"] = str(item["baseuom"]).strip()

    retail_raw = item.get("retailprice")
    try:
        item["retailprice"] = float(retail_raw) if retail_raw is not None else 0.0
    except (TypeError, ValueError):
        item["retailprice"] = 0.0

    for numeric_key in ("currentstock", "quantitylimit"):
        raw = item.get(numeric_key)
        try:
            item[numeric_key] = float(raw) if raw is not None else 0.0
        except (TypeError, ValueError):
            item[numeric_key] = 0.0

    # Stable boolean for clients (column may be absent on older DBs).
    if "ownproduct" in item:
        item["ownproduct"] = _as_own_product_flag(item.get("ownproduct"))
    else:
        item["ownproduct"] = False

    # Expose a stable JSON key regardless of Oracle column name.
    if updated_col:
        key = updated_col.lower()
        if key in item:
            item["last_updated"] = item.pop(key) if key != "last_updated" else item[key]

    return item


@items_bp.get("")
@limiter.limit("120/minute")
def list_items():
    """
    Paginated ITEMMASTER list.

    Query params:
      - search: optional code/name filter (max 80 chars)
      - limit: page size (default 750, max 1000)
      - offset: row offset (default 0; capped — prefer keyset for deep pages)
      - after_itemcode / after_itemname / after_updated: keyset cursor
        (seek pagination; avoids deep ROWNUM offset cost)
      - updated_since: ISO timestamp — when LAST_UPDATED column exists, return
        only rows changed on/after this time (delta sync)
    """
    table_name = _safe_ident(
        current_app.config["ORACLE_ITEMMASTER_TABLE"], "ITEMMASTER"
    )
    search = (request.args.get("search") or "").strip()
    if len(search) > _MAX_SEARCH_LEN:
        return jsonify({"error": f"search must be at most {_MAX_SEARCH_LEN} characters"}), 400

    limit = _parse_int(
        request.args.get("limit", _DEFAULT_LIMIT),
        _DEFAULT_LIMIT,
        min_value=1,
        max_value=_MAX_LIMIT,
    )
    offset = _parse_int(
        request.args.get("offset", 0),
        0,
        min_value=0,
        max_value=_MAX_OFFSET,
    )

    after_itemcode = (request.args.get("after_itemcode") or "").strip()
    after_itemname = (request.args.get("after_itemname") or "").strip()
    after_updated_raw = (request.args.get("after_updated") or "").strip()
    after_updated = _parse_updated_since(after_updated_raw) if after_updated_raw else None
    if after_updated_raw and after_updated is None:
        return jsonify({"error": "after_updated must be a valid ISO-8601 timestamp"}), 400

    use_keyset = bool(after_itemcode) or bool(after_itemname) or after_updated is not None

    updated_since_raw = request.args.get("updated_since")
    updated_since = _parse_updated_since(updated_since_raw)
    if updated_since_raw and updated_since_raw.strip() and updated_since is None:
        return jsonify({"error": "updated_since must be a valid ISO-8601 timestamp"}), 400

    select_cols = list(ITEM_COLUMNS)
    delta_supported = False
    updated_col: str | None = None

    where_parts: list[str] = []
    params: dict = {}

    if search:
        # Avoid UPPER(TO_CHAR(...)) so TO_CHAR(ITEMCODE) / ITEMCODE indexes can help.
        # Name keeps contains-match for UX.
        where_parts.append(
            """(
                TO_CHAR(ITEMCODE) LIKE :search_code
                OR UPPER(ITEMNAME) LIKE :search_name
            )"""
        )
        upper = search.upper()
        params["search_code"] = f"{upper}%"
        params["search_name"] = f"%{upper}%"

    with oracle_cursor() as cursor:
        updated_col = _resolve_updated_column(cursor, table_name)
        if updated_col:
            delta_supported = True
            select_cols.append(updated_col)
            if updated_since is not None:
                where_parts.append(f"{updated_col} >= :updated_since")
                params["updated_since"] = updated_since

        # TRIM OWNPRODUCT so CHAR-padded values like 'Y ' become 'Y'.
        inner_select_cols = [
            "TRIM(OWNPRODUCT) AS OWNPRODUCT" if col == "OWNPRODUCT" else col
            for col in select_cols
        ]
        outer_select_cols = list(select_cols)
        inner_columns_sql = ", ".join(inner_select_cols)
        outer_columns_sql = ", ".join(outer_select_cols)

        delta_order = bool(delta_supported and updated_since is not None)
        if delta_order and updated_col:
            order_sql = f"ORDER BY {updated_col}, ITEMCODE"
        else:
            order_sql = "ORDER BY ITEMNAME, ITEMCODE"

        # Keyset seek: continue after the last row of the previous page.
        if use_keyset:
            if delta_order and updated_col:
                if after_updated is not None and after_itemcode:
                    where_parts.append(
                        f"("
                        f" {updated_col} > :after_updated"
                        f" OR ({updated_col} = :after_updated"
                        f"     AND TO_CHAR(ITEMCODE) > :after_itemcode)"
                        f")"
                    )
                    params["after_updated"] = after_updated
                    params["after_itemcode"] = after_itemcode
                elif after_itemcode:
                    where_parts.append("TO_CHAR(ITEMCODE) > :after_itemcode")
                    params["after_itemcode"] = after_itemcode
            elif after_itemname and after_itemcode:
                where_parts.append(
                    "("
                    " ITEMNAME > :after_itemname"
                    " OR (ITEMNAME = :after_itemname"
                    "     AND TO_CHAR(ITEMCODE) > :after_itemcode)"
                    ")"
                )
                params["after_itemname"] = after_itemname
                params["after_itemcode"] = after_itemcode
            elif after_itemcode:
                where_parts.append("TO_CHAR(ITEMCODE) > :after_itemcode")
                params["after_itemcode"] = after_itemcode

        where_sql = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""
        fetch_limit = limit + 1
        inner_sql = f"""
            SELECT {inner_columns_sql}
            FROM {table_name}
            {where_sql}
            {order_sql}
        """

        if use_keyset or offset == 0:
            query = rownum_limit_sql(inner_sql, columns_sql=outer_columns_sql)
            params["max_row"] = fetch_limit
        else:
            query = rownum_page_sql(inner_sql, columns_sql=outer_columns_sql)
            params["max_row"] = offset + fetch_limit
            params["min_row"] = offset

        try:
            cursor.execute(query, params)
        except Exception as exc:
            # Fallback if OWNPRODUCT is missing on an older schema.
            if "OWNPRODUCT" in str(exc).upper() and "OWNPRODUCT" in select_cols:
                logger.warning("OWNPRODUCT unavailable on %s — retrying without it", table_name)
                select_cols = [c for c in select_cols if c != "OWNPRODUCT"]
                columns_sql = ", ".join(select_cols)
                inner_sql_fb = f"""
                    SELECT {columns_sql}
                    FROM {table_name}
                    {where_sql}
                    {order_sql}
                """
                if use_keyset or offset == 0:
                    fb_query = rownum_limit_sql(inner_sql_fb, columns_sql=columns_sql)
                else:
                    fb_query = rownum_page_sql(inner_sql_fb, columns_sql=columns_sql)
                cursor.execute(fb_query, params)
            else:
                raise
        rows = cursor.fetchall()
        has_more = len(rows) > limit
        if has_more:
            rows = rows[:limit]
        data = [
            _normalize_item(
                row_to_dict(cursor, row),
                updated_col if delta_supported else None,
            )
            for row in rows
        ]

    next_cursor = None
    if has_more and data:
        last = data[-1]
        next_cursor = {
            "after_itemcode": last.get("itemcode") or "",
            "after_itemname": last.get("itemname") or "",
        }
        if last.get("last_updated") is not None:
            next_cursor["after_updated"] = str(last.get("last_updated"))

    server_time = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

    return jsonify(
        {
            "count": len(data),
            "offset": 0 if use_keyset else offset,
            "limit": limit,
            "has_more": has_more,
            "delta_supported": delta_supported,
            "server_time": server_time,
            "next_cursor": next_cursor,
            "items": data,
        }
    )


def _to_float(raw, default: float = 0.0) -> float:
    try:
        return float(raw) if raw is not None else default
    except (TypeError, ValueError):
        return default


@items_bp.get("/<item_code>/uoms")
@limiter.limit("120/minute")
def list_item_uoms(item_code: str):
    """
    Return sellable UOMs for one ITEMCODE.

    Combines ITEMMASTER.BASEUOM with ITEMALTERNATEUOMMAP.ALTERNATEUOMCODE.
    Prefer rows matching the item's LOCATIONCODE when present.
    """
    code = (item_code or "").strip()
    if not code:
        return jsonify({"error": "item code is required"}), 400
    if len(code) > 40:
        return jsonify({"error": "item code is too long"}), 400

    master_table = _safe_ident(
        current_app.config["ORACLE_ITEMMASTER_TABLE"], "ITEMMASTER"
    )
    alt_table = _safe_ident(
        current_app.config.get("ORACLE_ITEM_ALTERNATE_UOM_TABLE")
        or "ITEMALTERNATEUOMMAP",
        "ITEMALTERNATEUOMMAP",
    )

    base_uom = ""
    base_price = 0.0
    location_code = ""

    # Prefer bare ITEMCODE equality (index-friendly); fall back to TO_CHAR.
    try:
        code_num = int(code) if code.isdigit() else None
    except (TypeError, ValueError):
        code_num = None
    if code_num is not None:
        item_predicates = (
            ("ITEMCODE = :itemcode_num", {"itemcode_num": code_num}),
            ("TO_CHAR(ITEMCODE) = :itemcode", {"itemcode": code}),
        )
    else:
        item_predicates = (
            ("TO_CHAR(ITEMCODE) = :itemcode", {"itemcode": code}),
        )

    with oracle_cursor() as cursor:
        master_row = None
        for predicate, bind in item_predicates:
            cursor.execute(
                f"""
                SELECT BASEUOM, RETAILPRICE, LOCATIONCODE
                FROM {master_table}
                WHERE {predicate}
                  AND ROWNUM = 1
                """,
                bind,
            )
            master_row = cursor.fetchone()
            if master_row is not None:
                break
        if master_row is not None:
            master = row_to_dict(cursor, master_row)
            base_uom = str(master.get("baseuom") or "").strip()
            base_price = _to_float(master.get("retailprice"))
            location_raw = master.get("locationcode")
            location_code = (
                str(location_raw).strip() if location_raw is not None else ""
            )

        alt_rows = []
        for predicate, bind in item_predicates:
            cursor.execute(
                f"""
                SELECT ALTERNATEUOMCODE, CONVERSIONFACTOR, RETAILPRICE, LOCATIONCODE, SLNO
                FROM {alt_table}
                WHERE {predicate}
                ORDER BY SLNO NULLS LAST, ALTERNATEUOMCODE
                """,
                bind,
            )
            alt_rows = [row_to_dict(cursor, row) for row in cursor.fetchall()]
            if alt_rows:
                break

    if location_code:
        matched = [
            row
            for row in alt_rows
            if str(row.get("locationcode") or "").strip() == location_code
        ]
        if matched:
            alt_rows = matched

    uoms: list[dict] = []
    seen: set[str] = set()

    if base_uom:
        seen.add(base_uom.upper())
        uoms.append(
            {
                "code": base_uom,
                "retailprice": base_price,
                "conversionfactor": 1.0,
                "isBase": True,
            }
        )

    for row in alt_rows:
        alt_code = str(row.get("alternateuomcode") or "").strip()
        if not alt_code:
            continue
        key = alt_code.upper()
        if key in seen:
            continue
        seen.add(key)
        uoms.append(
            {
                "code": alt_code,
                "retailprice": _to_float(row.get("retailprice"), base_price),
                "conversionfactor": _to_float(row.get("conversionfactor"), 1.0),
                "isBase": False,
            }
        )

    # No base UOM in master but alternate rows exist — still expose them.
    if not uoms and not alt_rows:
        return jsonify(
            {
                "itemcode": code,
                "baseuom": base_uom,
                "retailprice": base_price,
                "uoms": [],
            }
        )

    return jsonify(
        {
            "itemcode": code,
            "baseuom": base_uom,
            "retailprice": base_price,
            "uoms": uoms,
        }
    )
