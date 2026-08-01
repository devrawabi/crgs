"""Oracle connection pool and request-scoped helpers."""

from __future__ import annotations

import logging
from contextlib import contextmanager
from datetime import date, datetime

import oracledb
from flask import current_app, g

logger = logging.getLogger(__name__)

_oracle_client_initialized = False


def init_oracle_client(app):
    global _oracle_client_initialized
    if _oracle_client_initialized:
        return

    lib_dir = (app.config.get("ORACLE_CLIENT_LIB_DIR") or "").strip() or None
    try:
        if lib_dir:
            oracledb.init_oracle_client(lib_dir=lib_dir)
            logger.info("Oracle thick client initialized (lib_dir=%s)", lib_dir)
        else:
            oracledb.init_oracle_client()
            logger.info("Oracle thick client initialized (PATH)")
        _oracle_client_initialized = True
    except oracledb.Error as exc:
        # Thick mode unavailable; thin mode may still work on newer Oracle versions.
        logger.warning(
            "Oracle thick client unavailable (%s); continuing in thin mode",
            type(exc).__name__,
        )


def init_oracle_pool(app):
    """
    Shared connection pool — avoids open/close per request (major latency win).

    Tunables via env (see Config):
      ORACLE_POOL_MIN / ORACLE_POOL_MAX / ORACLE_POOL_INCREMENT
      ORACLE_POOL_TIMEOUT — seconds to wait for a free connection
      ORACLE_POOL_PING_INTERVAL — seconds between dead-connection checks
      ORACLE_POOL_MAX_LIFETIME — recycle connections after N seconds (0 = off)
      ORACLE_STMT_CACHE_SIZE — statement cache per connection
    """
    init_oracle_client(app)

    pool_kwargs = {
        "user": app.config["ORACLE_USER"],
        "password": app.config["ORACLE_PASSWORD"],
        "dsn": app.config["ORACLE_DSN"],
        "min": int(app.config.get("ORACLE_POOL_MIN", 2)),
        "max": int(app.config.get("ORACLE_POOL_MAX", 10)),
        "increment": int(app.config.get("ORACLE_POOL_INCREMENT", 1)),
        "timeout": int(app.config.get("ORACLE_POOL_TIMEOUT", 30)),
        "getmode": oracledb.POOL_GETMODE_WAIT,
        # Drop stale connections so long-idle Waitress workers stay healthy.
        "ping_interval": int(app.config.get("ORACLE_POOL_PING_INTERVAL", 60)),
        "stmtcachesize": int(app.config.get("ORACLE_STMT_CACHE_SIZE", 30)),
    }

    max_lifetime = int(app.config.get("ORACLE_POOL_MAX_LIFETIME", 3600))
    if max_lifetime > 0:
        pool_kwargs["max_lifetime_session"] = max_lifetime

    try:
        pool = oracledb.create_pool(**pool_kwargs)
    except oracledb.Error:
        logger.exception(
            "Failed to create Oracle pool (dsn=%s, user=%s)",
            app.config.get("ORACLE_DSN"),
            app.config.get("ORACLE_USER"),
        )
        raise

    # Fail fast at boot if credentials / network / listener are wrong.
    try:
        conn = pool.acquire()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1 FROM DUAL")
                cursor.fetchone()
        finally:
            pool.release(conn)
    except oracledb.Error:
        pool.close()
        logger.exception("Oracle pool created but connectivity check failed")
        raise

    app.extensions["oracle_pool"] = pool
    logger.info(
        "Oracle pool ready (min=%s max=%s ping=%ss stmtcache=%s)",
        pool_kwargs["min"],
        pool_kwargs["max"],
        pool_kwargs["ping_interval"],
        pool_kwargs["stmtcachesize"],
    )

    @app.teardown_appcontext
    def close_connection(_error):
        conn = g.pop("oracle_conn", None)
        if conn is not None:
            try:
                pool.release(conn)
            except oracledb.Error:
                logger.exception("Failed to release Oracle connection")


def close_oracle_pool(app=None):
    """Close the pool cleanly (tests / process shutdown)."""
    target = app or current_app
    pool = target.extensions.pop("oracle_pool", None)
    if pool is not None:
        try:
            pool.close(force=True)
        except oracledb.Error:
            logger.exception("Error closing Oracle pool")


def get_pool():
    return current_app.extensions["oracle_pool"]


def pool_stats():
    """Lightweight pool metrics for /api/health/db."""
    pool = get_pool()
    return {
        "opened": getattr(pool, "opened", None),
        "busy": getattr(pool, "busy", None),
        "max": int(current_app.config.get("ORACLE_POOL_MAX", 10)),
        "min": int(current_app.config.get("ORACLE_POOL_MIN", 2)),
    }


def get_connection():
    if "oracle_conn" not in g:
        pool = get_pool()
        try:
            g.oracle_conn = pool.acquire()
        except oracledb.Error:
            # One retry after a dead pooled connection is discarded by ping.
            logger.warning("Oracle acquire failed; retrying once")
            g.oracle_conn = pool.acquire()
    return g.oracle_conn


@contextmanager
def oracle_cursor():
    conn = get_connection()
    cursor = conn.cursor()
    # arraysize / prefetchrows cut round-trips on catalog & list pages.
    arraysize = int(current_app.config.get("ORACLE_CURSOR_ARRAYSIZE", 500))
    cursor.arraysize = arraysize
    try:
        cursor.prefetchrows = arraysize
    except Exception:  # noqa: BLE001 — older client builds may lack the attr
        pass
    try:
        yield cursor
    finally:
        cursor.close()


def _serialize_value(value):
    if value is None:
        return None
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def row_to_dict(cursor, row):
    columns = [col[0].lower() for col in cursor.description]
    return {
        column: _serialize_value(value)
        for column, value in zip(columns, row)
    }
