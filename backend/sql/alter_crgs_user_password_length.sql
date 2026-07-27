-- Widen password column to store bcrypt hashes (60 chars).
-- Run once against the CRGS Oracle schema.
ALTER TABLE CRGS_USER MODIFY (PASSWORD VARCHAR2(100));
