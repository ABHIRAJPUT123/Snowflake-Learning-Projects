-- ============================================================
-- snowflake project: rbac and dynamic data masking
-- ============================================================
-- topics:
-- 1. analyst role and email masking
-- 2. north_manager and east_manager roles
-- 3. conditional masking of numeric amount values
--
-- before running:
-- - run as accountadmin or a role with equivalent privileges.
-- - replace ABHISHEKVSLIFE with your actual snowflake username.
-- - make sure a warehouse is active for select queries.
-- - run top to bottom in one worksheet/session.
-- - create or replace can replace existing demo objects.
--
-- IMPORTANT:
-- amount is a number column, so its masking policy returns number.
-- hidden amounts are NULL, not '***'. A number policy cannot return text.
-- ============================================================

-- 1. session and database
use role accountadmin;

select current_role(), current_warehouse(), current_database();

-- if needed, activate a warehouse available in your account:
-- use warehouse compute_wh;

create database if not exists demo_db
    comment = 'database for rbac and masking policy practice';

create schema if not exists demo_db.public;

use database demo_db;
use schema public;


-- 2. customers table and sample data
create or replace table demo_db.public.customers (
    id number(10,0),
    name varchar(100),
    email varchar(255)
);

insert into demo_db.public.customers values
    (1, 'asha', 'asha@regex.com'),
    (2, 'ravi', 'ravi@regex.com'),
    (3, 'meera', 'meera@regex.com');

select * from demo_db.public.customers;


-- 3. analyst role and read permissions
create role if not exists analyst;

grant usage on database demo_db to role analyst;
grant usage on schema demo_db.public to role analyst;
grant select on table demo_db.public.customers to role analyst;

-- change this username if your snowflake username is different
grant role analyst to user ABHISHEKVSLIFE;

-- included as a permission-learning example.
-- accountadmin creates and attaches the policy below.
grant create masking policy on schema demo_db.public to role analyst;


-- 4. email masking policy
-- analyst example: asha@regex.com -> a*****@regex.com
-- other roles: asha@regex.com -> *****
create or replace masking policy demo_db.public.email_mask
    as (val varchar)
    returns varchar ->
        case
            when current_role() = 'ANALYST'
                then left(val, 1) || '*****'
                     || substr(val, position('@' in val))
            else '*****'
        end;

alter table demo_db.public.customers
    modify column email
    set masking policy demo_db.public.email_mask;


-- 5. test email masking as accountadmin
use role accountadmin;
select current_role();
select * from demo_db.public.customers;


-- 6. test email masking as analyst
-- analyst must be granted to the current user
use role analyst;
select current_role();
select * from demo_db.public.customers;


-- 7. create raw_base table
use role accountadmin;

create or replace table demo_db.public.raw_base (
    id number(10,0),
    manager_name varchar(100),
    direction varchar(20),
    amount number(12,2)
);

insert into demo_db.public.raw_base values
    (1, 'rahul', 'north', 10000),
    (2, 'priya', 'east', 20000),
    (3, 'aman', 'west', 30000),
    (4, 'neha', 'south', 40000),
    (5, 'rohit', 'east', 50000);

select * from demo_db.public.raw_base;


-- 8. create manager roles and grant read permissions
create role if not exists north_manager;
create role if not exists east_manager;

grant usage on database demo_db to role north_manager;
grant usage on schema demo_db.public to role north_manager;
grant select on table demo_db.public.raw_base to role north_manager;

grant usage on database demo_db to role east_manager;
grant usage on schema demo_db.public to role east_manager;
grant select on table demo_db.public.raw_base to role east_manager;


-- 9. conditional masking policy for amount
-- north_manager: sees all amounts.
-- east_manager: sees amounts only where direction is east.
-- all other roles: amount is NULL.
--
-- both arguments are passed in USING in the same order as the policy.
create or replace masking policy demo_db.public.amount_mask
    as (val number(12,2), row_direction varchar)
    returns number(12,2) ->
        case
            when current_role() = 'NORTH_MANAGER'
                then val
            when current_role() = 'EAST_MANAGER'
                 and lower(row_direction) = 'east'
                then val
            else null
        end;

alter table demo_db.public.raw_base
    modify column amount
    set masking policy demo_db.public.amount_mask
    using (amount, direction);


-- 10. grant manager roles to the intended user
grant role north_manager to user ABHISHEKVSLIFE;
grant role east_manager to user ABHISHEKVSLIFE;


-- 11. test as north_manager
use role north_manager;
select current_role();
select * from demo_db.public.raw_base;
-- expected: all five amount values are visible.


-- 12. test as east_manager
use role east_manager;
select current_role();
select * from demo_db.public.raw_base;
-- expected: east rows show amount; other directions show NULL.


-- 13. final verification
use role accountadmin;

show masking policies in schema demo_db.public;
describe table demo_db.public.customers;
describe table demo_db.public.raw_base;

select * from demo_db.public.customers;
select * from demo_db.public.raw_base;

-- end of project
