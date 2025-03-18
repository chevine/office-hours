alter session set statistics_level = all;
set serveroutput off
drop table if exists employees cascade constraints purge;
drop table if exists departments cascade constraints purge;
drop table if exists job_history cascade constraints purge;
drop table if exists emps cascade constraints purge;
create table employees as select * from hr.employees;
alter table employees add constraint employee_pk primary key ( employee_id );
create table departments as select * from hr.departments;
alter table departments add constraint department_pk primary key ( department_id );
create table job_history as select * from hr.job_history;