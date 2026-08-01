from flask import Blueprint, current_app, jsonify, make_response, request

from app.cache import cache_get, cache_set, etag_for_payload
from app.db import oracle_cursor, row_to_dict
from app.routes.auth import limiter

designations_bp = Blueprint("designations", __name__)

DESIGNATION_COLUMNS = ("ROLECODE", "DESIGNATION")
_CACHE_TTL_SECONDS = 120
_CACHE_KEY = "designations:list"


def _table_name():
    return current_app.config["ORACLE_DESIGNATION_TABLE"]


@designations_bp.get("")
@limiter.limit("60 per minute")
def list_designations():
    cached = cache_get(_CACHE_KEY)
    if cached is None:
        table_name = _table_name()
        columns_sql = ", ".join(DESIGNATION_COLUMNS)
        query = f"""
            SELECT {columns_sql}
            FROM {table_name}
            ORDER BY DESIGNATION
        """

        with oracle_cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
            data = [row_to_dict(cursor, row) for row in rows]
            for item in data:
                if item.get("rolecode") is not None:
                    item["rolecode"] = str(item["rolecode"]).strip()
                if item.get("designation") is not None:
                    item["designation"] = str(item["designation"]).strip()

        cached = {"count": len(data), "designations": data}
        cache_set(_CACHE_KEY, cached, ttl_seconds=_CACHE_TTL_SECONDS)

    etag = etag_for_payload(cached)
    if request.headers.get("If-None-Match") == etag:
        response = make_response("", 304)
        response.headers["ETag"] = etag
        response.headers["Cache-Control"] = "private, max-age=60"
        return response

    response = make_response(jsonify(cached))
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "private, max-age=60"
    return response
