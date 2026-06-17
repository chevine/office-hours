alter session set txn_priority = high;
drop table if exists employees cascade constraints purge;
drop table if exists departments cascade constraints purge;


create table departments as 
select * from hr.departments;

create table employees as 
select * from hr.employees;

alter table employees 
  add primary key ( employee_id );




/********************************
********************************/