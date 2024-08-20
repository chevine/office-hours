/*
   Demo script for Ask Tom Office Hours, August 20, 2024
*/

@sql-atoh-202408-setup

-- Table based on HR.EMPLOYEES slightly modified and with >438 thousand rows
info+ employees;

select count(*) from employees;









-- Regular function to retrieve job type from concatenated JOB_ID column
create or replace function get_job_type (
  job_code varchar2
) return varchar2 as
begin
  return substr ( job_code, instr ( job_code, '_' ) + 1 );
end;
/

-- Query we wish to optimize
select count(*) from employees
where  get_job_type ( job_id ) = 'MAN';




-- Try using same function with PRAGMA UDF
create or replace function get_job_type_udf (
  job_code varchar2
) return varchar2 as
  pragma udf;
begin
  return substr ( job_code, instr ( job_code, '_' ) + 1 );
end;
/

select count(*) from employees
where  get_job_type_udf ( job_id ) = 'MAN';
-- -- 







-- -- 
-- Try using scalar subquery
select count(*) from employees
where  ( select get_job_type ( job_id ) ) = 'MAN';

-- Few distinct function input values 
-- => great candidate for scalar subquery caching
select count(*), count(distinct job_id), count(distinct get_job_type(job_id))
from   employees;





-- Regular function to retrieve formatted name
create or replace function formatted_name (
  first_name varchar2, last_name varchar2
) return varchar2 as
begin
  return last_name || ', ' || first_name;
end;
/

-- Query we wish to optimize
select * from employees
where  formatted_name ( first_name, last_name ) = 'King, Steven';




-- Try using scalar subquery
select * from employees
where  (select formatted_name ( first_name, last_name ) ) = 'King, Steven';






-- Nearly unique function input values => caching is not useful
select count(*), count(distinct first_name||'|'||last_name), 
       count(distinct formatted_name ( first_name, last_name ))
from   employees;
-- -- 




-- -- 
-- Try create index to help
create index emp_formatted_name_i 
  on employees ( formatted_name ( first_name, last_name ) );





-- Cannot create index on regular function, must be declared deterministic
create or replace function formatted_name_deter (
  first_name varchar2, last_name varchar2
) return varchar2 deterministic as
begin
  return last_name || ', ' || first_name;
end;
/

-- Index on deterministic function works
create index emp_formatted_name_i 
  on employees ( formatted_name_deter ( first_name, last_name ) );

exec dbms_stats.gather_table_stats ( ownname => null, tabname => 'employees', no_invalidate => false );


-- Using deterministic function in query uses index
select * from employees
where  formatted_name_deter ( first_name, last_name ) = 'King, Steven';






-- Regular function to retrieve email domain
create or replace function get_email_domain (
  email_address varchar2
) return varchar2 as
begin
  return substr ( email_address, instr ( email_address, '@' ) + 1 );
end;
/

-- Query we wish to optimize
select count(*) from employees
where  get_email_domain ( email ) = 'gmail.com';



-- Nearly unique function input values => caching is not useful
select count(*), count(distinct email), 
       count(distinct get_email_domain ( email ))
from   employees;




-- Deterministic function
create or replace function get_email_domain_deter (
  email_address varchar2
) return varchar2 deterministic as
begin
  return substr ( email_address, instr ( email_address, '@' ) + 1 );
end;
/

-- Index on the deterministic function
create index emp_email_domain_i 
  on employees ( get_email_domain_deter ( email ) );

exec dbms_stats.gather_table_stats ( ownname => null, tabname => 'employees', no_invalidate => false, method_opt => 'for all hidden columns size 100' );


-- Using deterministic function in query uses index fast full scan 
-- saves on blocks read and saves actually calling the function
select count(*) from employees
where  get_email_domain_deter ( email ) = 'gmail.com';






-- select * rather than count(*) might or might not use index, 
-- depending on expected selectivity
set feed only
select * from employees
where  get_email_domain_deter ( email ) = 'gmail.com';

select * from employees
where  get_email_domain_deter ( email ) = 'aol.com';
set feed on






-- Regular (non-deterministic!) function to retrieve 
-- how many years an employee has been hired as of this moment in time
create or replace function years_employed (
  hire_date date
) return int as
begin
  return floor ( months_between ( sysdate, hire_date ) / 12 );
end;
/

-- Query we wish to optimize
select count(*) from employees
where  years_employed ( hire_date ) = 10;
-- --



-- --
-- Avoid using PL/SQL function call!
select count(*) from employees
where  floor ( months_between ( sysdate, hire_date ) / 12 ) = 10;


/*********************************



*********************************/

-- Scalar SQL macro
create or replace function years_employed_macro (
  hire_date date
) return varchar2 sql_macro ( scalar ) as
begin
  return q'! floor ( months_between ( sysdate, hire_date ) / 12 ) !';
end;
/

-- Use macro instead of function will replace function with SQL 
-- at hard parse time
select count(*) from employees
where  years_employed_macro ( hire_date ) = 10;





-- That's a lot of rework...
-- ... plus we may need to keep the PL/SQL versions
exec dbms_output.put_line ( years_employed_macro ( sysdate ) );








-- Turn on SQL transpiler
alter session set sql_transpiler = on;

-- Regular function call automatically replaced with SQL
select count(*) from employees
where  years_employed ( hire_date ) = 10;

-- Turn off SQL transpiler
alter session set sql_transpiler = off;



/*********************************



*********************************/

-- Turn on SQL transpiler
alter session set sql_transpiler = on;

-- Try the other 3 regular functions
select count(*) from employees
where  get_job_type ( job_id ) = 'MAN';

select * from employees
where  formatted_name ( first_name, last_name ) = 'King, Steven';

select count(*) from employees
where  get_email_domain ( email ) = 'gmail.com';

-- Turn off SQL transpiler
alter session set sql_transpiler = off;
-- --




-- -- 
-- Transpiling replaces function with expression 
-- => need to index expression instead of function
create index emp_formatted_name_expr_i 
  on employees ( last_name || ', ' || first_name );

exec dbms_stats.gather_table_stats ( ownname => null, tabname => 'employees', no_invalidate => false );

-- Turn on SQL transpiler
alter session set sql_transpiler = on;

-- Transpiled SQL uses expression index
select * from employees
where  formatted_name ( first_name, last_name ) = 'King, Steven';

-- Turn off SQL transpiler
alter session set sql_transpiler = off;
-- --




-- --
-- Regular function with nested function calls
create or replace function employee_service (
  hire_date date
) return varchar2 as
begin
  return case
    when years_employed ( hire_date ) <= 1 then 'New starter'
    when years_employed ( hire_date ) <= 10 then 'Standard'
    when years_employed ( hire_date ) <= 25 then 'Faithful service'
    when years_employed ( hire_date ) <= 40 then 'Distinguished service'
    else 'Larry level'
  end;
end;
/

-- Query we wish to optimize
select count(*) from employees
where  employee_service ( hire_date ) = 'Larry level';



-- Turn on SQL transpiler
alter session set sql_transpiler = on;

-- Nested transpiling not possible
select count(*) from employees
where  employee_service ( hire_date ) = 'Larry level';

-- Turn off SQL transpiler
alter session set sql_transpiler = off;



/*********************************



*********************************/
-- Attempt at nesting macros
create or replace function employee_service_macro (
  hire_date date
) return varchar2 sql_macro ( scalar ) as
  service varchar2(4000);
begin
  service := case
    when years_employed ( hire_date ) <= 1 then 'New starter'
    when years_employed ( hire_date ) <= 10 then 'Standard'
    when years_employed ( hire_date ) <= 25 then 'Faithful service'
    when years_employed ( hire_date ) <= 40 then 'Distinguished service'
    else 'Larry level'
  end;
  dbms_output.put_line ( hire_date || ' ' || service );
  return service;
end;
/

-- Does not work that way
select employee_service_macro ( sysdate );





-- Nesting macros in the returned SQL string
create or replace function employee_service_macro (
  hire_date date
) return varchar2 sql_macro ( scalar ) as
begin
  return q'! case
    when years_employed ( hire_date ) <= 1 then 'New starter'
    when years_employed ( hire_date ) <= 10 then 'Standard'
    when years_employed ( hire_date ) <= 25 then 'Faithful service'
    when years_employed ( hire_date ) <= 40 then 'Distinguished service'
    else 'Larry level'
  end !';
end;
/

-- Works
select count(*) from employees
where  employee_service_macro ( hire_date ) = 'Larry level';





-- Regular function incorrectly using SQL syntax in PL/SQL => fails
create or replace function formatted_name_case_insensitive (
  first_name varchar2, last_name varchar2
) return varchar2 as
begin
  return last_name || ', ' || first_name collate binary_ci;
end;
/




-- Valid SQL syntax as snippet in scalar macro
create or replace function formatted_name_macro_case_insensitive (
  first_name varchar2, last_name varchar2
) return varchar2 sql_macro ( scalar ) as
begin
  return q'! last_name || ', ' || first_name collate binary_ci !';
end;
/

-- Allows case insensitive search using the macro
select formatted_name_macro_case_insensitive ( first_name, last_name ) 
from   employees
where  formatted_name_macro_case_insensitive ( 
  first_name, last_name 
) = 'kING, sTEVEN';
-- --





-- --
-- Query using 3 functions at once

select count(*) from employees
where  get_email_domain ( email ) = 'gmail.com'
and    get_job_type ( job_id ) = 'PRES'
and    formatted_name ( first_name, last_name ) like 'King,%'; 




-- Turn on SQL transpiler
alter session set sql_transpiler = on;

-- All 3 functions replaced with SQL
select count(*) from employees
where  get_email_domain ( email ) = 'gmail.com'
and    get_job_type ( job_id ) = 'PRES'
and    formatted_name ( first_name, last_name ) like 'King,%'; 

-- Turn off SQL transpiler
alter session set sql_transpiler = off;




-- Macro version of email domain function
create or replace function get_email_domain_macro (
  email_address varchar2
) return varchar2 sql_macro ( scalar ) as
begin
  return q'! substr ( email_address, instr ( email_address, '@' ) + 1 ) !';
end;
/

-- Macro version of job type function

create or replace function get_job_type_macro (
  job_code varchar2
) return varchar2 sql_macro ( scalar ) as
begin
  return q'! substr ( job_code, instr ( job_code, '_' ) + 1 ) !';
end;
/

-- Macro version of formatted name function

create or replace function formatted_name_macro (
  first_name varchar2, last_name varchar2
) return varchar2 sql_macro ( scalar ) as
begin
  return q'! last_name || ', ' || first_name !';
end;
/

-- Using the 3 macros instead of functions for same result as transpilation
select count(*) from employees
where  get_email_domain_macro ( email ) = 'gmail.com'
and    get_job_type_macro ( job_id ) = 'PRES'
and    formatted_name_macro ( first_name, last_name ) like 'King,%'; 

/**********************************************

   End of demo script for Ask Tom Office Hours, August 20, 2024

**********************************************/

create domain constants as enum ( open = 'open', closed = 'closed ' );
drop domain constants;
create domain constants as enum ( open = 'o', closed = 'closed ' );

select * from user_domains;

select * from constants;


select constants.open;

create or replace function f return varchar2 sql_macro ( scalar ) as begin
  return ' constants.open ';
end;
/