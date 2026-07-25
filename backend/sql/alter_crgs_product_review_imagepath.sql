-- Add optional photo path for customer product feedback.
-- Run once on existing Oracle databases.

ALTER TABLE CRGS_PRODUCTREVIEW ADD (IMAGEPATH VARCHAR2(255));
