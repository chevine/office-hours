set serveroutput on
set feed on
set timing on
drop table employees cascade constraints purge;
 
create table employees as select * from hr.employees;
alter table employees modify (
  first_name varchar2(50), last_name varchar2(50), email varchar2(50)
);

alter table employees add primary key ( employee_id );

@sql-atoh-202408-load 12
alter session set statistics_level = all;
alter session set sql_transpiler = off;

set serveroutput on
set feed on
set timing on
set define on
set echo on

exec dbms_stats.gather_table_stats ( ownname => null, tabname => 'employees' );

cl scr