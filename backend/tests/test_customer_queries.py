"""Lightweight checks for customer list SQL builders (no Oracle required)."""

from app.routes.customers import (
    _MISSING_CONDITION,
    _build_list_query,
    _customer_columns_sql,
    _missing_threshold,
)


def test_missing_condition_uses_threshold_bind():
    assert ":missing_threshold" in _MISSING_CONDITION
    assert "TRUNC(SYSDATE) - TRUNC(av.BILLDATE)" in _MISSING_CONDITION
    assert _missing_threshold(0) == 1
    assert _missing_threshold(30) == 30


def test_all_customers_page_first_skips_age_view():
    query, params = _build_list_query(
        "CUSTOMERS",
        "CUSTOMERAGEVIEW",
        route="12",
        search="",
        priority="",
        missing_days=30,
        offset=0,
        limit=50,
    )
    assert "CUSTOMERAGEVIEW" not in query
    assert "age_rn" not in query
    assert "0 AS IS_MISSING" in query
    assert params["route"] == 12
    assert params["max_row"] == 50
    assert "ORDER BY c.CUST_NAME" in query


def test_missing_filter_applies_before_pagination():
    query, params = _build_list_query(
        "CUSTOMERS",
        "CUSTOMERAGEVIEW",
        route="12",
        search="ACME",
        priority="missing",
        missing_days=7,
        offset=50,
        limit=50,
    )
    assert "aged.IS_MISSING = 1" in query
    assert "age_rn" in query
    assert params["missing_threshold"] == 7
    assert params["min_row"] == 50
    assert params["search"] == "%ACME%"


def test_outstanding_uses_page_first_path():
    query, params = _build_list_query(
        "CUSTOMERS",
        "CUSTOMERAGEVIEW",
        route="12",
        search="",
        priority="outstanding",
        missing_days=30,
        offset=0,
        limit=50,
    )
    assert "LIKE '%OUT%'" in query
    assert "CREDIT_AMOUNT" in query
    assert "aged.IS_MISSING" not in query
    assert "CUSTOMERAGEVIEW" not in query
    assert "missing_threshold" not in params


def test_four_month_missing_window_binds_120_days():
    """UI '4 months' chip maps to missing_days=120 and still filters before ROWNUM."""
    query, params = _build_list_query(
        "CUSTOMERS",
        "CUSTOMERAGEVIEW",
        route="18",
        search="",
        priority="missing",
        missing_days=120,
        offset=0,
        limit=50,
    )
    assert params["missing_threshold"] == 120
    assert params["route"] == 18
    assert "aged.IS_MISSING = 1" in query
    assert ":missing_threshold" in query


def test_all_missing_window_uses_one_day_threshold():
    """UI 'All' chip (missing_days=0) means not billed today (>= 1 day)."""
    query, params = _build_list_query(
        "CUSTOMERS",
        "CUSTOMERAGEVIEW",
        route="18",
        search="",
        priority="missing",
        missing_days=0,
        offset=0,
        limit=50,
    )
    assert params["missing_threshold"] == 1
    assert "aged.IS_MISSING = 1" in query


def test_customer_columns_stable():
    cols = _customer_columns_sql("c")
    assert "c.CUST_CODE" in cols
    assert "c.CREATEDSTATUS" in cols
    assert "c.CUSTOMERSTATUS" in cols
