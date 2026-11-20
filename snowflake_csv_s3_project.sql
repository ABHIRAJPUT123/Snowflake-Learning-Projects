-- ============================================================
-- SNOWFLAKE CSV + AWS S3 PROJECT
-- Date: 2026-11-20
--
-- Flow:
--   AWS S3 CSV -> Snowflake BRONZE_CSV -> SILVER_CSV -> AWS S3 CSV
--
-- Prerequisites:
--   1. Database NEWSNOWFLAKE_DB exists.
--   2. Warehouse COMPUTE_WH exists and is usable.
--   3. External stage NYASNOW_STAGE exists in JSON_SCHEMA and
--      points to s3://nyasnowflake/ in ap-southeast-2.
--   4. The stage has permission to read/write the S3 bucket.
--
-- IMPORTANT:
--   No AWS access keys or secrets are stored in this file.
--   The existing stage is reused; do not recreate it with credentials.
-- ============================================================


-- ------------------------------------------------------------
-- 1. SET ROLE, WAREHOUSE, DATABASE AND SCHEMA
-- ------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE NEWSNOWFLAKE_DB;

CREATE SCHEMA IF NOT EXISTS NEWSNOWFLAKE_DB.CSV_SCHEMA;
USE SCHEMA NEWSNOWFLAKE_DB.CSV_SCHEMA;


-- ------------------------------------------------------------
-- 2. VERIFY THE EXISTING S3 STAGE
-- ------------------------------------------------------------

SHOW STAGES IN DATABASE NEWSNOWFLAKE_DB;

-- The existing stage used in this project:
-- @NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE

LIST @NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE/CSV/;


-- ------------------------------------------------------------
-- 3. CREATE CSV FILE FORMAT
-- ------------------------------------------------------------
-- The source CSV contains a header row. SKIP_HEADER = 1 ensures
-- the column headings are not loaded as a transaction record.

CREATE OR REPLACE FILE FORMAT NEWSNOWFLAKE_DB.CSV_SCHEMA.CSV_FORMAT
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null');

DESC FILE FORMAT NEWSNOWFLAKE_DB.CSV_SCHEMA.CSV_FORMAT;


-- ------------------------------------------------------------
-- 4. INSPECT THE SOURCE CSV BEFORE LOADING
-- ------------------------------------------------------------

-- Show a few data rows. $1 ... $19 are positional CSV fields.
SELECT
    $1, $2, $3, $4, $5,
    $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15,
    $16, $17, $18, $19
FROM @NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE/CSV/POS_BATCH_JAN_APR.CSV
    (FILE_FORMAT => 'NEWSNOWFLAKE_DB.CSV_SCHEMA.CSV_FORMAT')
LIMIT 5;


-- ------------------------------------------------------------
-- 5. CREATE BRONZE TABLE
-- ------------------------------------------------------------
-- Bronze preserves source values as raw strings.
-- All 19 source fields are VARCHAR at this layer.

CREATE OR REPLACE TABLE NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV (
    C1  VARCHAR,
    C2  VARCHAR,
    C3  VARCHAR,
    C4  VARCHAR,
    C5  VARCHAR,
    C6  VARCHAR,
    C7  VARCHAR,
    C8  VARCHAR,
    C9  VARCHAR,
    C10 VARCHAR,
    C11 VARCHAR,
    C12 VARCHAR,
    C13 VARCHAR,
    C14 VARCHAR,
    C15 VARCHAR,
    C16 VARCHAR,
    C17 VARCHAR,
    C18 VARCHAR,
    C19 VARCHAR
);


-- ------------------------------------------------------------
-- 6. LOAD S3 CSV INTO BRONZE USING COPY INTO
-- ------------------------------------------------------------

COPY INTO NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV
FROM @NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE/CSV/POS_BATCH_JAN_APR.CSV
FILE_FORMAT = (
    FORMAT_NAME = 'NEWSNOWFLAKE_DB.CSV_SCHEMA.CSV_FORMAT'
)
ON_ERROR = 'ABORT_STATEMENT';


-- ------------------------------------------------------------
-- 7. VERIFY BRONZE LOAD
-- ------------------------------------------------------------

SELECT COUNT(*) AS TOTAL_RECORDS
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV;

SELECT *
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV
LIMIT 10;

-- Expected source transaction count from the coaching run:
-- 39,521 rows (the source file had one header row, skipped above).


-- ------------------------------------------------------------
-- 8. BRONZE DATA QUALITY CHECKS
-- ------------------------------------------------------------

-- Check NULLs in the transaction ID.
SELECT COUNT_IF(C1 IS NULL) AS NULL_TRANSACTION_IDS
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV;

-- Check duplicate transaction IDs.
SELECT
    C1 AS TRANSACTION_ID,
    COUNT(*) AS DUPLICATE_COUNT
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV
GROUP BY C1
HAVING COUNT(*) > 1
ORDER BY DUPLICATE_COUNT DESC;

-- Check NULLs in the remaining source fields.
SELECT
    COUNT_IF(C2 IS NULL) AS STORE_ID_NULL,
    COUNT_IF(C3 IS NULL) AS STORE_NAME_NULL,
    COUNT_IF(C4 IS NULL) AS CITY_NULL,
    COUNT_IF(C5 IS NULL) AS REGION_NULL,
    COUNT_IF(C6 IS NULL) AS CASHIER_NULL,
    COUNT_IF(C7 IS NULL) AS CUSTOMER_NULL,
    COUNT_IF(C8 IS NULL) AS DATE_NULL,
    COUNT_IF(C9 IS NULL) AS TIME_NULL,
    COUNT_IF(C10 IS NULL) AS SKU_NULL,
    COUNT_IF(C11 IS NULL) AS PRODUCT_NULL,
    COUNT_IF(C12 IS NULL) AS CATEGORY_NULL,
    COUNT_IF(C13 IS NULL) AS SUBCATEGORY_NULL,
    COUNT_IF(C14 IS NULL) AS QUANTITY_NULL,
    COUNT_IF(C15 IS NULL) AS PRICE_NULL,
    COUNT_IF(C16 IS NULL) AS DISCOUNT_NULL,
    COUNT_IF(C17 IS NULL) AS AMOUNT_NULL,
    COUNT_IF(C18 IS NULL) AS PAYMENT_NULL,
    COUNT_IF(C19 IS NULL) AS LOYALTY_NULL
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV;

-- Check numeric business rules.
SELECT
    COUNT_IF(TRY_TO_NUMBER(C14) <= 0) AS INVALID_QUANTITY,
    COUNT_IF(TRY_TO_DECIMAL(C15, 10, 2) < 0) AS INVALID_UNIT_PRICE,
    COUNT_IF(
        TRY_TO_NUMBER(C16) < 0 OR TRY_TO_NUMBER(C16) > 100
    ) AS INVALID_DISCOUNT,
    COUNT_IF(TRY_TO_DECIMAL(C17, 10, 2) < 0) AS INVALID_TOTAL_AMOUNT
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV;

-- Check date/time conversion.
SELECT
    COUNT_IF(TRY_TO_DATE(C8) IS NULL) AS INVALID_DATES,
    COUNT_IF(TRY_TO_TIME(C9) IS NULL) AS INVALID_TIMES
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV;


-- ------------------------------------------------------------
-- 9. CREATE SILVER TABLE FROM BRONZE (CTAS)
-- ------------------------------------------------------------
-- CTAS = CREATE TABLE AS SELECT.
-- This statement creates the Silver table AND inserts the
-- selected/transformed Bronze data in the same operation.
--
-- The header row was skipped during the Bronze load, so no
-- header-filter WHERE clause is required here.

CREATE OR REPLACE TABLE NEWSNOWFLAKE_DB.CSV_SCHEMA.SILVER_CSV AS
SELECT
    C1::VARCHAR          AS TRANSACTION_ID,
    C2::VARCHAR          AS STORE_ID,
    C3::VARCHAR          AS STORE_NAME,
    C4::VARCHAR          AS STORE_CITY,
    C5::VARCHAR          AS STORE_REGION,
    C6::VARCHAR          AS CASHIER_ID,
    C7::VARCHAR          AS CUSTOMER_ID,
    C8::DATE             AS TRANSACTION_DATE,
    C9::TIME             AS TRANSACTION_TIME,
    C10::VARCHAR         AS PRODUCT_SKU,
    C11::VARCHAR         AS PRODUCT_NAME,
    C12::VARCHAR         AS CATEGORY,
    C13::VARCHAR         AS SUBCATEGORY,
    C14::NUMBER(10, 0)   AS QUANTITY,
    C15::NUMBER(10, 2)   AS UNIT_PRICE,
    C16::NUMBER(5, 2)    AS DISCOUNT_PCT,
    C17::NUMBER(10, 2)   AS TOTAL_AMOUNT,
    C18::VARCHAR         AS PAYMENT_METHOD,
    C19::NUMBER(10, 0)   AS LOYALTY_POINTS
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV;


-- ------------------------------------------------------------
-- 10. VERIFY SILVER TABLE
-- ------------------------------------------------------------

DESC TABLE NEWSNOWFLAKE_DB.CSV_SCHEMA.SILVER_CSV;

SELECT COUNT(*) AS TOTAL_RECORDS
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.SILVER_CSV;

SELECT *
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.SILVER_CSV
LIMIT 10;


-- ------------------------------------------------------------
-- 11. EXPORT SILVER TABLE BACK TO S3 AS CSV
-- ------------------------------------------------------------
-- This is the reverse direction:
-- Snowflake table -> external stage -> S3 object.
--
-- SINGLE = TRUE requests one output file.
-- HEADER = TRUE writes column names in the CSV.
-- COMPRESSION = NONE writes an uncompressed CSV.
-- OVERWRITE = TRUE allows replacing the same destination file.

COPY INTO @NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE/CSV/EXPORT/SILVER_CSV_20261120.CSV
FROM NEWSNOWFLAKE_DB.CSV_SCHEMA.SILVER_CSV
FILE_FORMAT = (
    TYPE = CSV
    FIELD_DELIMITER = ','
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMPRESSION = NONE
)
HEADER = TRUE
SINGLE = TRUE
OVERWRITE = TRUE;


-- ------------------------------------------------------------
-- 12. VERIFY THE EXPORTED FILE
-- ------------------------------------------------------------

LIST @NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE/CSV/EXPORT/;


-- ============================================================
-- END OF PROJECT
-- ============================================================
