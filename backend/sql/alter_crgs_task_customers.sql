-- Store comma-separated customer codes for Other-route tasks.
-- Run once against the CRGS Oracle schema.
ALTER TABLE CRGS_TASK ADD (CUSTOMERS VARCHAR2(4000));
