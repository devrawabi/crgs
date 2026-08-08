from flask import Blueprint, current_app, jsonify, make_response, request

from app.cache import cache_get, cache_set, etag_for_payload
from app.db import oracle_cursor, row_to_dict
from app.pagination import apply_has_more, parse_limit_offset, rownum_page_sql
from app.routes.auth import limiter

routes_data_bp = Blueprint("routes_data", __name__)

ROUTE_COLUMNS = ("ROUTENAME", "ROUTENO")
_DEFAULT_LIMIT = 500
_MAX_LIMIT = 5000
_MAX_ROUTE_NOS = 200
_CACHE_TTL_SECONDS = 60


def _parse_route_nos(raw: str) -> list[str]:
    """Parse comma/semicolon-separated route numbers; normalize numeric forms."""
    if not raw or not str(raw).strip():
        return []
    seen: set[str] = set()
    out: list[str] = []
    for part in str(raw).replace(";", ",").split(","):
        text = part.strip()
        if not text:
            continue
        try:
            # "058" and "58" should match the same Oracle ROUTENO.
            text = str(int(text))
        except ValueError:
            pass
        if text in seen:
            continue
        seen.add(text)
        out.append(text)
        if len(out) >= _MAX_ROUTE_NOS:
            break
    return out


@routes_data_bp.get("")
@limiter.limit("90 per minute")
def list_routes():
    """
    Paginated routes list.

    Query params:
      - search: name/number contains
      - routeNos: comma-separated ROUTENO filter (for assigned-route lookups)
      - limit / offset
    """
    table_name = current_app.config["ORACLE_ROUTES_TABLE"]
    search = request.args.get("search", "").strip()
    route_nos = _parse_route_nos(
        request.args.get("routeNos") or request.args.get("routeNos[]") or ""
    )
    limit, offset = parse_limit_offset(
        default_limit=_DEFAULT_LIMIT,
        max_limit=_MAX_LIMIT,
    )

    cache_key = None
    if not search and not route_nos:
        cache_key = f"routes:list:{limit}:{offset}"
        cached = cache_get(cache_key)
        if cached is not None:
            etag = etag_for_payload(cached)
            if request.headers.get("If-None-Match") == etag:
                response = make_response("", 304)
                response.headers["ETag"] = etag
                response.headers["Cache-Control"] = "private, max-age=30"
                return response
            response = make_response(jsonify(cached))
            response.headers["ETag"] = etag
            response.headers["Cache-Control"] = "private, max-age=30"
            return response

    columns_sql = ", ".join(ROUTE_COLUMNS)
    where_parts: list[str] = []
    params: dict = {}

    if search:
        where_parts.append(
            "(UPPER(ROUTENAME) LIKE :search OR UPPER(ROUTENO) LIKE :search)"
        )
        params["search"] = f"%{search.upper()}%"

    if route_nos:
        # Prefer bare ROUTENO IN (...) for numeric codes (index-friendly).
        # Keep TO_CHAR / LTRIM fallback for padded VARCHAR storage.
        num_binds: list[str] = []
        text_binds: list[str] = []
        stripped_binds: list[str] = []
        for i, no in enumerate(route_nos):
            text_key = f"rno_t_{i}"
            stripped_key = f"rno_s_{i}"
            text_binds.append(f":{text_key}")
            stripped_binds.append(f":{stripped_key}")
            params[text_key] = no
            params[stripped_key] = no
            try:
                num_key = f"rno_n_{i}"
                num_binds.append(f":{num_key}")
                params[num_key] = int(no)
            except (TypeError, ValueError):
                pass
        clauses = []
        if num_binds:
            clauses.append(f"ROUTENO IN ({', '.join(num_binds)})")
        clauses.append(f"TRIM(TO_CHAR(ROUTENO)) IN ({', '.join(text_binds)})")
        clauses.append(
            f"LTRIM(TRIM(TO_CHAR(ROUTENO)), '0') IN ({', '.join(stripped_binds)})"
        )
        where_parts.append("(" + " OR ".join(clauses) + ")")

    where_sql = f" WHERE {' AND '.join(where_parts)}" if where_parts else ""

    inner_sql = f"""
        SELECT {columns_sql}
        FROM {table_name}
        {where_sql}
        ORDER BY ROUTENAME
    """
    query = rownum_page_sql(inner_sql, columns_sql=columns_sql)
    params["max_row"] = offset + limit + 1
    params["min_row"] = offset

    with oracle_cursor() as cursor:
        cursor.execute(query, params)
        fetched = [row_to_dict(cursor, row) for row in cursor.fetchall()]
        fetched, has_more = apply_has_more(fetched, limit)
        data = fetched
        for item in data:
            if item.get("routeno") is not None:
                item["routeno"] = str(item["routeno"]).strip()
            if item.get("routename") is not None:
                item["routename"] = str(item["routename"]).strip()
            else:
                item["routename"] = ""

    payload = {
        "count": len(data),
        "offset": offset,
        "limit": limit,
        "has_more": has_more,
        "routes": data,
    }
    if cache_key:
        cache_set(cache_key, payload, ttl_seconds=_CACHE_TTL_SECONDS)
        etag = etag_for_payload(payload)
        response = make_response(jsonify(payload))
        response.headers["ETag"] = etag
        response.headers["Cache-Control"] = "private, max-age=30"
        return response

    return jsonify(payload)
