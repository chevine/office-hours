set serveroutput on
set feed on
set timing on
drop table if exists t cascade constraints purge;
drop table employees cascade constraints purge;
drop table departments cascade constraints purge;
drop table locations cascade constraints purge;
drop table countries cascade constraints purge;
drop table regions cascade constraints purge;
drop table job_history cascade constraints purge;
  

create table employees as select * from hr.employees;
create table departments as select * from hr.departments;
create table locations as select * from hr.locations;
create table countries as select * from hr.countries;
create table regions as select * from hr.regions;
create table job_history as select * from hr.job_history;
alter table job_history modify end_date null;
commit;

alter table employees modify (
  first_name varchar2(50), last_name varchar2(50)
);

alter table employees add primary key ( employee_id );
--create index regi_name_i on regions ( region_name );

cl scr