from contextlib import contextmanager
from datetime import date, datetime

import oracledb
from flask import current_app, g

_oracle_client_initialized = False


def init_oracle_client(app):
    global _oracle_client_initialized
    if _oracle_client_initialized:
        return

    lib_dir = app.config.get("ORACLE_CLIENT_LIB_DIR") or None
    try:
        if lib_dir:
            oracledb.init_oracle_client(lib_dir=lib_dir)
        else:
            oracledb.init_oracle_client()
        _oracle_client_initialized = True
    except oracledb.Error:
        # Thick mode unavailable; thin mode may still work on newer Oracle versions.
        pass


def init_oracle_pool(app):
    init_oracle_client(app)

    pool = oracledb.create_pool(
        user=app.config["ORACLE_USER"],
        password=app.config["ORACLE_PASSWORD"],
        dsn=app.config["ORACLE_DSN"],
        min=1,
        max=4,
        increment=1,
    )
    app.extensions["oracle_pool"] = pool

    @app.teardown_appcontext
    def close_connection(_error):
        conn = g.pop("oracle_conn", None)
        if conn is not None:
            pool.release(conn)


def get_pool():
    return current_app.extensions["oracle_pool"]


def get_connection():
    if "oracle_conn" not in g:
        g.oracle_conn = get_pool().acquire()
    return g.oracle_conn


@contextmanager
def oracle_cursor():
    conn = get_connection()
    cursor = conn.cursor()
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
