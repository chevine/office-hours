drop table if exists employees cascade constraints purge;
drop table if exists err$_employees cascade constraints purge;
drop table if exists departments cascade constraints purge;
drop table if exists job_history cascade constraints purge;
drop table if exists err$_job_history cascade constraints purge;
drop sequence if exists employee_seq;

create table employees as
  select * from hr.employees;

create table departments as
  select * from hr.departments;

create table job_history as 
  select * from hr.job_history;

create sequence employee_seq
  start with 210;

alter table employees 
  modify hire_date default trunc ( sysdate );
