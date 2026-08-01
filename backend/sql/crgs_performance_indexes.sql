-- CRGS performance helpers for common API filters.
-- Review with your DBA before applying — ownership/schema may differ.
--
-- CRGS_* code columns are VARCHAR2. Prefer TRIM(col) predicates (not
-- TRIM(TO_CHAR(col))) and matching function-based indexes below.

-- Sales targets (order save refreshes ACHIEVED by employee)
CREATE INDEX IDX_CRGS_SALETARGET_EMP
    ON CRGS_SALETARGET (TRIM(EMPLOYEECODE));

-- Orders listed / summed by executive + date
CREATE INDEX IDX_CRGS_ORDERHDR_EMP_DATE
    ON CRGS_ORDERHDR (TRIM(EMPLOYEECODE), TRUNC(ORDERDATE));

CREATE INDEX IDX_CRGS_ORDERDTL_ORDERNO
    ON CRGS_ORDERDTL (ORDERNO);

-- Visits by executive / customer
CREATE INDEX IDX_CRGS_VISIT_EMP
    ON CRGS_VISITDETAILS (TRIM(EMPLOYEECODE));

CREATE INDEX IDX_CRGS_VISIT_CUST
    ON CRGS_VISITDETAILS (TRIM(CUSTOMERCODE));

-- Tasks by executive
CREATE INDEX IDX_CRGS_TASK_EMP
    ON CRGS_TASK (TRIM(EMPLOYEECODE));

-- Product reviews / market research by executive
CREATE INDEX IDX_CRGS_PRODUCTREVIEW_EMP
    ON CRGS_PRODUCTREVIEW (TRIM(EMPLOYEECODE));

CREATE INDEX IDX_CRGS_MARKETRESEARCH_EMP
    ON CRGS_MARKETRESEARCH (TRIM(EMPLOYEECODE));

-- Login users by role (admin user list join)
CREATE INDEX IDX_CRGS_USER_ROLE
    ON CRGS_USER (TRIM(ROLECODE));

-- Order detail ↔ ITEMMASTER join (when codes are stored as text vs number)
CREATE INDEX IDX_CRGS_ORDERDTL_ITEMCODE
    ON CRGS_ORDERDTL (TRIM(TO_CHAR(ITEMCODE)));

-- Routes filter by ROUTENO (numeric equality preferred in API)
CREATE INDEX IDX_TBLROUTES_ROUTENO
    ON TBLROUTES (ROUTENO);
