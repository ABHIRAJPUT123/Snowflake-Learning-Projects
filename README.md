# Snowflake RBAC & Dynamic Data Masking

This project demonstrates role-based access control (RBAC) and column-level dynamic data masking in Snowflake.

## Topics covered

- Create a database and customer table.
- Create an `ANALYST` role and grant read access.
- Create and attach an email masking policy.
- Create `NORTH_MANAGER` and `EAST_MANAGER` roles.
- Apply conditional masking to the numeric `AMOUNT` column.
- Test results by switching the active role.

## Project file

- `snowflake_rbac_dynamic_masking.sql` — complete SQL script with section-by-section comments.

## How to run

1. Open a Snowflake SQL Worksheet.
2. Open `snowflake_rbac_dynamic_masking.sql`.
3. Run the script from top to bottom in one worksheet/session.
4. Ensure a warehouse is active for SELECT queries.
5. Replace `ABHISHEKVSLIFE` with your actual Snowflake username if different.
6. Run as `ACCOUNTADMIN` or a role with the required privileges.

The script creates objects in `DEMO_DB`. `CREATE OR REPLACE` can replace demo tables and policies with the same names.

## Expected results

### Email masking

The `EMAIL_MASK` policy is attached to `CUSTOMERS.EMAIL`.

- `ANALYST` sees a partially masked email, e.g. `a*****@regex.com`.
- Other active roles see `*****`.

### Manager amount masking

The `AMOUNT_MASK` policy is attached to `RAW_BASE.AMOUNT`.

- `NORTH_MANAGER` sees all amounts.
- `EAST_MANAGER` sees amounts only where `DIRECTION = 'east'`.
- Other roles receive `NULL` for the amount.

**Why NULL instead of `***`?** `AMOUNT` is a `NUMBER` column, so its masking policy must return a compatible numeric type. Returning text such as `***` from a numeric masking policy causes a return-type mismatch. For a visual `***`, use a separate presentation layer (for example, a view that casts the value to text); do not return text from this numeric policy.

## Important notes

- `USE ROLE` changes the active role in the current session. The role must be granted to the current user.
- Granting a role does not automatically activate it.
- The `ANALYST` role receives `CREATE MASKING POLICY` as a permission-learning example; `ACCOUNTADMIN` creates and attaches the policies in this script.
- `CURRENT_ROLE()` is used by the policies, so test by switching to the intended role before running SELECT.

## GitHub push commands

Run these commands in PowerShell from this project folder after creating an empty GitHub repository:

```powershell
git init
git add .
git commit -m "Add Snowflake RBAC and dynamic masking project"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

Replace the URL with your actual repository URL.

If `origin` already exists, update it instead:

```powershell
git remote set-url origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

## Official Snowflake documentation

- [Dynamic Data Masking](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro)
- [CREATE MASKING POLICY](https://docs.snowflake.com/en/sql-reference/sql/create-masking-policy)
- [Access control overview](https://docs.snowflake.com/en/user-guide/security-access-control-overview)
