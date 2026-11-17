# Snowflake Table Types, Time Travel & Fail-safe

A beginner-friendly Snowflake SQL practice project covering:

- Permanent, transient, and temporary tables
- Database and schema retention settings
- Time Travel queries after update and delete
- Restoring a dropped table with `UNDROP TABLE`
- Fail-safe behavior
- Zero-copy cloning
- Storage and compute separation (conceptual notes)

## Files

- `snowflake_table_types_time_travel.sql` — complete SQL practice script.

## How to run

1. Open Snowflake and create a SQL Worksheet.
2. Open `snowflake_table_types_time_travel.sql`.
3. Check that your active role has permission to create databases, schemas, and tables.
4. If you want to use a warehouse, uncomment `use warehouse compute_wh;` and replace `compute_wh` with a warehouse that exists in your account.
5. Run the script from top to bottom in one session. Keep the session open until the temporary-table section and final verification have completed.

## Important notes

- `CREATE OR REPLACE` can replace an existing object. This script uses it for clearly named learning/demo tables.
- The standard Time Travel retention period is 1 day. Retention greater than 1 day for permanent objects requires Enterprise Edition or higher.
- Transient and temporary tables support 0 or 1 day of Time Travel and have no Fail-safe.
- Permanent tables have a separate, non-configurable 7-day Fail-safe period after Time Travel ends. Fail-safe recovery is performed by Snowflake on a best-effort basis; it is not a user-accessible extension of Time Travel.
- A temporary table is available only in the session in which it was created. Do not close the worksheet/session before completing the temporary-table examples.
- The transient database section is separate from the permanent database section.

## Storage vs compute

- **Storage** is where Snowflake keeps table data. You do not need to create another copy of the same table just because more users run queries.
- **Compute** is the virtual warehouse that executes SQL. You can resize a warehouse or use additional warehouses to provide more processing capacity.
- Separating storage and compute lets teams scale query processing independently from the amount of data stored. Compute usage still costs money, so suspend warehouses when they are not needed.

## GitHub push commands

Run these commands in PowerShell from the project folder after creating an empty repository on GitHub:

```powershell
git init
git add .
git commit -m "Add Snowflake table types and Time Travel practice"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

Replace the remote URL with your actual GitHub repository URL. If `origin` already exists, use:

```powershell
git remote set-url origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

## Official Snowflake references

- [Temporary and transient tables](https://docs.snowflake.com/en/user-guide/tables-temp-transient)
- [Time Travel](https://docs.snowflake.com/en/user-guide/data-time-travel)
- [Fail-safe](https://docs.snowflake.com/en/user-guide/data-failsafe)
- [Storage costs](https://docs.snowflake.com/en/user-guide/cost-understanding-data-storage)
