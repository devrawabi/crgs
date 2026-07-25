"""Update CRGS_CUSTOMERTARGET.ACHIEVED for new_acquisition from CONTACTINFO FLAG=N."""

from __future__ import annotations

NEW_ACQUISITION_TYPE = "new_acquisition"


def count_new_customers_flag_n(cursor, contactinfo_table: str) -> int:
    """Total add-customer requests (FLAG = N) in CRGS_CONTACTINFO."""
    cursor.execute(
        f"""
        SELECT COUNT(*)
        FROM {contactinfo_table}
        WHERE UPPER(TRIM(FLAG)) = 'N'
        """
    )
    row = cursor.fetchone()
    if not row or row[0] is None:
        return 0
    return int(row[0])


def refresh_new_acquisition_achieved(
    cursor,
    *,
    customer_targets_table: str,
    contactinfo_table: str,
    employee_code: str | None = None,
) -> int:
    """
    Set ACHIEVED = COUNT(CONTACTINFO FLAG=N) for new_acquisition customer targets.

    Returns the FLAG=N count used for ACHIEVED.
    """
    achieved = count_new_customers_flag_n(cursor, contactinfo_table)

    params: dict = {"achieved": achieved, "targettype": NEW_ACQUISITION_TYPE}
    where_sql = "WHERE LOWER(TRIM(TO_CHAR(TARGETTYPE))) = :targettype"
    if employee_code:
        where_sql += " AND TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode"
        params["employeecode"] = str(employee_code).strip()

    cursor.execute(
        f"""
        UPDATE {customer_targets_table}
        SET ACHIEVED = :achieved
        {where_sql}
        """,
        params,
    )
    return achieved
