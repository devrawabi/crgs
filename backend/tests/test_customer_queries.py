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
    assert "av.CUSTOMERCODE = c.CUST_CODE" in query
    assert "TRIM(TO_CHAR" not in query
    assert params["missing_threshold"] == 7
    assert params["min_row"] == 50
    assert params["search"] == "%ACME%"


def test_stats_age_join_scopes_to_routes():
    from app.routes.customers import _age_join_stats

    sql = _age_join_stats("CUSTOMERS", "CUSTOMERAGEVIEW", "c", [":route_0", ":route_1"])
    assert "WHERE a.CUSTOMERCODE IN" in sql
    assert "cx.ROUTE IN (:route_0, :route_1)" in sql
    assert "TRIM(TO_CHAR" not in sql
    assert "av.CUSTOMERCODE = c.CUST_CODE" in sql


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
        cash_view="CASHCUSTOMERBALANCE",
    )
    assert "LIKE '%OUT%'" in query
    assert "CREDIT_AMOUNT" in query
    assert "CASHCUSTOMERBALANCE" in query
    assert "cb.CUSTOMERCODE = c.CUST_CODE" in query
    assert "NVL(cb.OUTSTANDING, 0) > 0" in query
    assert "NVL(cb.OUTSTANDING, 0)) AS CREDIT_AMOUNT" in query
    assert "cb.CREDITLIMIT" in query
    assert "aged.IS_MISSING" not in query
    assert "CUSTOMERAGEVIEW" not in query
    assert "missing_threshold" not in params


def test_outstanding_requires_cash_view():
    import pytest

    with pytest.raises(ValueError, match="cash_view"):
        _build_list_query(
            "CUSTOMERS",
            "CUSTOMERAGEVIEW",
            route="12",
            search="",
            priority="outstanding",
            missing_days=30,
            offset=0,
            limit=50,
        )

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


def test_global_search_avoids_full_table_order():
    from app.routes.customers import _build_global_search_query

    query, params = _build_global_search_query(
        "CUSTOMERS",
        search="acme",
        offset=0,
        limit=12,
    )
    assert "ORDER BY c.CUST_NAME" not in query
    assert "UPPER(c.CUST_CODE) LIKE :search_code" in query
    assert "UPPER(c.CUST_NAME) LIKE :search_name" in query
    assert params["search_code"] == "ACME%"
    assert params["search_name"] == "%ACME%"
    assert params["max_row"] == 12


def test_codes_filter_uses_native_equality():
    from app.routes.customers import _build_customer_filters

    conditions, params = _build_customer_filters(
        route="",
        search="",
        priority="",
        codes=["101", "202"],
    )
    assert any("CUST_CODE IN" in c for c in conditions)
    assert "TRIM(TO_CHAR" not in " ".join(conditions)
    assert params["code0"] == "101"
    assert params["code1"] == "202"
