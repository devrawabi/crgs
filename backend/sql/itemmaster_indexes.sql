-- ITEMMASTER performance helpers for CRGS product catalog sync.
-- Review with your DBA before applying — table names/ownership may differ.
--
-- Why: paginated ORDER BY ITEMNAME and ITEMCODE lookups need supporting indexes.
-- Without them, each /api/items page can full-scan ITEMMASTER.

-- Speeds name-ordered catalog pages and admin search-by-name.
CREATE INDEX IDX_ITEMMASTER_ITEMNAME
    ON ITEMMASTER (ITEMNAME);

-- Speeds code lookups (bare ITEMCODE equality / IN lists).
CREATE INDEX IDX_ITEMMASTER_ITEMCODE
    ON ITEMMASTER (ITEMCODE);

-- Speeds prefix search: TO_CHAR(ITEMCODE) LIKE :code%
-- (API avoids UPPER(TO_CHAR(...)) so this FBI can be used.)
CREATE INDEX IDX_ITEMMASTER_ITEMCODE_TC
    ON ITEMMASTER (TO_CHAR(ITEMCODE));

-- Speeds batched alternate-UOM enrichment on /api/items (IN :itemcodes).
CREATE INDEX IDX_ITEMALTUOM_ITEMCODE
    ON ITEMALTERNATEUOMMAP (ITEMCODE);

---------------------------------------------------------------------------
-- RECOMMENDED for H6 delta sync (run once if column is missing):
--   1) Uncomment and execute the ALTER / index / trigger below
--   2) Set ORACLE_ITEMMASTER_UPDATED_COLUMN=LAST_UPDATED in backend/.env
--      (API also auto-detects LAST_UPDATED when env is empty)
---------------------------------------------------------------------------

-- ALTER TABLE ITEMMASTER ADD (LAST_UPDATED DATE DEFAULT SYSDATE NOT NULL);
--
-- CREATE INDEX IDX_ITEMMASTER_LAST_UPDATED
--     ON ITEMMASTER (LAST_UPDATED, ITEMCODE);
--
-- CREATE OR REPLACE TRIGGER TRG_ITEMMASTER_LAST_UPDATED
--     BEFORE UPDATE ON ITEMMASTER
--     FOR EACH ROW
-- BEGIN
--     :NEW.LAST_UPDATED := SYSDATE;
-- END;
-- /
