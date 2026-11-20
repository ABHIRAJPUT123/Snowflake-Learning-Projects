# Snowflake CSV to S3 Project

**Project date:** 20 November 2026

## Project objective

Load a CSV file from Amazon S3 into Snowflake, preserve the raw data in a Bronze table, create a typed Silver table, and export the Silver table back to Amazon S3 as a CSV file.

## Architecture

```text
Amazon S3
  nyasnowflake/csv/pos_batch_jan_apr.csv
          |
          | COPY INTO table
          v
Snowflake: NEWSNOWFLAKE_DB.CSV_SCHEMA.BRONZE_CSV
          |
          | CREATE TABLE AS SELECT (CTAS)
          v
Snowflake: NEWSNOWFLAKE_DB.CSV_SCHEMA.SILVER_CSV
          |
          | COPY INTO @stage
          v
Amazon S3
  nyasnowflake/csv/export/
```

## Source file

- Bucket: `nyasnowflake`
- Region: `ap-southeast-2` (Asia Pacific – Sydney)
- Source key: `csv/pos_batch_jan_apr.csv`
- Source stage: `NEWSNOWFLAKE_DB.JSON_SCHEMA.NYASNOW_STAGE`

## Snowflake objects

| Object | Name | Purpose |
|---|---|---|
| Database | `NEWSNOWFLAKE_DB` | Project database |
| Schema | `CSV_SCHEMA` | CSV project objects |
| External stage | `NYASNOW_STAGE` | Existing S3 connection in `JSON_SCHEMA` |
| File format | `CSV_FORMAT` | Reads comma-separated CSV and skips its header |
| Bronze table | `BRONZE_CSV` | Raw source values stored as VARCHAR |
| Silver table | `SILVER_CSV` | Typed, analysis-ready data |

## Before running

This script reuses an existing external stage. It does **not** create an AWS IAM user, storage integration, or stage, and it does not contain AWS credentials.

Confirm that:

1. `NEWSNOWFLAKE_DB` exists.
2. `COMPUTE_WH` exists and is available.
3. `NYASNOW_STAGE` exists at `NEWSNOWFLAKE_DB.JSON_SCHEMA`.
4. The stage points to `s3://nyasnowflake/`.
5. The stage has the required S3 read and write permissions.
6. `pos_batch_jan_apr.csv` exists under the S3 `csv/` prefix.

If your account uses different database, warehouse, stage, bucket, or file names, update the SQL before running it.

## How to run

1. Open a Snowflake worksheet.
2. Open `snowflake_csv_s3_project.sql`.
3. Run the statements in order, section by section.
4. Check the output after each `COPY INTO`.
5. Verify the exported object with the final `LIST` command or in the AWS S3 console.

## Important concepts

### Bronze layer

The Bronze table stores source fields in their original text form (`VARCHAR`). It is the raw landing layer and should be retained so the data can be reprocessed.

### Silver layer

The Silver table uses meaningful column names and appropriate types, including `DATE`, `TIME`, and numeric types. In this project it is created with CTAS:

`CREATE TABLE ... AS SELECT ...`

CTAS creates the table and populates it from the SELECT query in one operation.

### COPY INTO directions

- `COPY INTO <table> FROM @stage` loads data from a stage/S3 into a Snowflake table.
- `COPY INTO @stage FROM <table>` unloads data from a Snowflake table to a stage/S3.

## Header handling

The source CSV has a header row. The reproducible script uses `SKIP_HEADER = 1` in `CSV_FORMAT`, so the header is not loaded as a transaction record. The coaching session initially used a zero-header-skip format, which loaded the header as one extra Bronze row; the Silver query then filtered that row. This clean script avoids that extra row at the Bronze layer.

Expected transaction count from the coaching session: **39,521**.

## Source columns

| Position | Source field | Silver type |
|---:|---|---|
| 1 | transaction_id | VARCHAR |
| 2 | store_id | VARCHAR |
| 3 | store_name | VARCHAR |
| 4 | store_city | VARCHAR |
| 5 | store_region | VARCHAR |
| 6 | cashier_id | VARCHAR |
| 7 | customer_id | VARCHAR |
| 8 | transaction_date | DATE |
| 9 | transaction_time | TIME |
| 10 | product_sku | VARCHAR |
| 11 | product_name | VARCHAR |
| 12 | category | VARCHAR |
| 13 | subcategory | VARCHAR |
| 14 | quantity | NUMBER(10,0) |
| 15 | unit_price | NUMBER(10,2) |
| 16 | discount_pct | NUMBER(5,2) |
| 17 | total_amount | NUMBER(10,2) |
| 18 | payment_method | VARCHAR |
| 19 | loyalty_points | NUMBER(10,0) |

## Expected S3 export

The SQL unload command writes the Silver table to this S3 prefix:

`s3://nyasnowflake/csv/export/`

Requested output name:

`SILVER_CSV_20261120.CSV`

Snowflake unload output naming can be affected by unload options and generated file naming. Verify the exact object name using the `LIST` command and AWS S3 console.

## Security

- Never commit AWS access keys, secret keys, passwords, or private tokens.
- This repository intentionally contains no credentials.
- Use an appropriately configured Snowflake stage and least-privilege AWS permissions.
