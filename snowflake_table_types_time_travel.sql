-- ============================================================
-- snowflake learning project
-- topic: permanent, transient and temporary tables
--       time travel, fail-safe, zero-copy cloning
--       storage and compute separation
--
-- IMPORTANT:
-- 1. run this script in a snowflake worksheet, from top to bottom.
-- 2. this is a learning/demo script. "create or replace" can replace
--    an existing object with the same name.
-- 3. fail-safe is not enabled by a sql parameter. permanent tables
--    get a non-configurable 7-day fail-safe period automatically.
-- ============================================================


-- ============================================================
-- 1. check your current snowflake session
-- ============================================================

select
    current_role() as current_role,
    current_warehouse() as current_warehouse,
    current_database() as current_database,
    current_schema() as current_schema;

show warehouses;


-- use a warehouse that exists in your account.
-- if compute_wh does not exist, replace it with your warehouse name.
-- use warehouse compute_wh;


-- ============================================================
-- 2. create a permanent database and schema
-- ============================================================

create database if not exists my_perm_db
    data_retention_time_in_days = 1
    comment = 'permanent database for snowflake learning';

use database my_perm_db;

create schema if not exists my_perm_schema
    data_retention_time_in_days = 1
    comment = 'schema for table type and time travel practice';

use schema my_perm_schema;

-- verify database and schema properties
show databases like 'MY_PERM_DB';
describe database my_perm_db;

show schemas like 'MY_PERM_SCHEMA';
describe schema my_perm_schema;

select
    current_database() as current_database,
    current_schema() as current_schema;


-- ============================================================
-- 3. permanent table
-- ============================================================

-- permanent is the default table type.
-- it remains until it is explicitly dropped.
-- time travel retention is set to 1 day for this demo.
-- permanent tables also receive 7 days of fail-safe automatically.

create or replace table employee_perm (
    emp_id number(10,0),
    emp_name varchar(100),
    salary number(10,2),
    joining_date date
)
data_retention_time_in_days = 1
comment = 'permanent employee table for practice';

insert into employee_perm values
    (1, 'gungun', 35000, '2025-01-10'),
    (2, 'rahul', 40000, '2025-02-15'),
    (3, 'amit', 45000, '2025-03-20');

-- check table structure
describe table employee_perm;

-- check table properties
show tables like 'EMPLOYEE_PERM';

-- check table data
select * from employee_perm;


-- ============================================================
-- 4. transient table
-- ============================================================

-- transient tables remain until explicitly dropped.
-- they can be accessed across sessions by users with permission.
-- they support 0 or 1 day of time travel.
-- they do not have fail-safe.

create or replace transient table employee_transient (
    emp_id number(10,0),
    emp_name varchar(100),
    salary number(10,2),
    joining_date date
)
data_retention_time_in_days = 1
comment = 'transient table for temporary etl or staging data';

insert into employee_transient values
    (101, 'neha', 30000, '2025-04-01'),
    (102, 'karan', 32000, '2025-04-10');

describe table employee_transient;
show tables like 'EMPLOYEE_TRANSIENT';

select * from employee_transient;


-- ============================================================
-- 5. temporary table
-- ============================================================

-- temporary tables exist only in the current session.
-- they are automatically removed when the session ends.
-- they support 0 or 1 day of time travel, but have no fail-safe.

create or replace temporary table employee_temp (
    emp_id number(10,0),
    emp_name varchar(100),
    salary number(10,2),
    joining_date date
)
data_retention_time_in_days = 1
comment = 'session-specific temporary employee table';

insert into employee_temp values
    (201, 'pooja', 28000, '2025-05-01'),
    (202, 'arjun', 31000, '2025-05-12');

describe table employee_temp;
show tables like 'EMPLOYEE_TEMP';

select * from employee_temp;


-- ============================================================
-- 6. compare all three table types
-- ============================================================

show tables in schema my_perm_db.my_perm_schema;

-- expected concept:
-- employee_perm      -> permanent
-- employee_transient -> transient
-- employee_temp      -> temporary (visible only in this session)


-- ============================================================
-- 7. check time travel retention settings
-- ============================================================

-- this shows the configured time travel retention value.
-- it does not show or configure the fail-safe period.

show parameters like 'DATA_RETENTION_TIME_IN_DAYS'
    in table my_perm_db.my_perm_schema.employee_perm;

show parameters like 'DATA_RETENTION_TIME_IN_DAYS'
    in table my_perm_db.my_perm_schema.employee_transient;

show parameters like 'DATA_RETENTION_TIME_IN_DAYS'
    in table my_perm_db.my_perm_schema.employee_temp;


-- ============================================================
-- 8. time travel: view old data before an update
-- ============================================================

-- first, note the current data.
select * from employee_perm;

-- update one employee's salary.
update employee_perm
set salary = 50000
where emp_id = 1;

-- view the current value after update.
select * from employee_perm
where emp_id = 1;

-- view the table as it was approximately 5 minutes ago.
-- run this soon after the update for the clearest demonstration.
select *
from employee_perm at (offset => -60 * 5)
where emp_id = 1;


-- ============================================================
-- 9. time travel: recover a deleted row using historical data
-- ============================================================

-- delete one row.
delete from employee_perm
where emp_id = 2;

-- current table no longer contains emp_id 2.
select * from employee_perm;

-- historical query can still show the row within retention.
select *
from employee_perm at (offset => -60 * 5)
where emp_id = 2;


-- ============================================================
-- 10. time travel: restore a dropped permanent table
-- ============================================================

-- use a separate demo table so the main employee table stays safe.
create or replace table employee_undrop_demo (
    emp_id number,
    emp_name varchar(100)
)
data_retention_time_in_days = 1;

insert into employee_undrop_demo values
    (1, 'demo employee');

select * from employee_undrop_demo;

-- drop the demo table.
drop table employee_undrop_demo;

-- restore it while it is still inside the time travel retention period.
undrop table employee_undrop_demo;

-- verify that the table and its data are back.
select * from employee_undrop_demo;


-- ============================================================
-- 11. fail-safe concept
-- ============================================================

-- fail-safe is a non-configurable 7-day recovery period for
-- historical data in permanent tables, after time travel ends.
--
-- only snowflake can attempt recovery during fail-safe.
-- users cannot query fail-safe data or run an "undrop" from fail-safe.
--
-- transient and temporary tables have no fail-safe.
-- therefore, do not use them for data that must have this extra
-- recovery protection.


-- ============================================================
-- 12. zero-copy cloning
-- ============================================================

-- a clone is created quickly without initially copying all the data.
-- storage is shared until changes are made to either object.
-- later changes can create additional storage usage.

create or replace table employee_clone
    clone employee_perm;

-- compare original and clone.
select * from employee_perm;
select * from employee_clone;

-- change only the clone.
insert into employee_clone values
    (4, 'isha', 52000, '2025-06-01');

-- original remains unchanged.
select * from employee_perm;

-- clone now contains the extra row.
select * from employee_clone;

-- compare table metadata.
show tables like 'EMPLOYEE%';

describe table employee_perm;
describe table employee_clone;


-- ============================================================
-- 13. transient database example
-- ============================================================

-- transient databases are useful for data that does not need
-- fail-safe protection. their child objects inherit transient
-- behavior unless explicitly supported otherwise.

create transient database if not exists my_trans_db
    data_retention_time_in_days = 1
    comment = 'transient database for staging practice';

use database my_trans_db;

create schema if not exists my_trans_schema
    data_retention_time_in_days = 1
    comment = 'schema for transient staging objects';

use schema my_trans_schema;

create or replace table tran_tab (
    emp_id number(10,0),
    emp_name varchar(100),
    join_date date
);

insert into tran_tab values
    (1, 'dev', '2025-07-01'),
    (2, 'riya', '2025-07-05');

show databases like 'MY_TRANS_DB';
describe database my_trans_db;

show tables like 'TRAN_TAB';
describe table tran_tab;

select * from tran_tab;


-- ============================================================
-- 14. final verification
-- ============================================================

-- switch back to the permanent project objects.
use database my_perm_db;
use schema my_perm_schema;

select 'permanent' as table_type, count(*) as total_records
from employee_perm

union all

select 'transient' as table_type, count(*) as total_records
from employee_transient

union all

select 'temporary' as table_type, count(*) as total_records
from employee_temp;

show databases like 'MY_PERM_DB';
show schemas in database my_perm_db;
show tables in schema my_perm_db.my_perm_schema;

-- end of project
