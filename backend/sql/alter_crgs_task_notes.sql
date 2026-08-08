-- Ensure NOTES exists for task free-text (safe if already present).
-- Run once against the CRGS Oracle schema.
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE CRGS_TASK ADD (NOTES VARCHAR2(4000))';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1430 THEN -- ORA-01430: column being added already exists
      RAISE;
    END IF;
END;
/
