create or replace view employee_job_changes as 
  select employee_id, hire_date start_date, null end_date, job_id, department_id 
  from   employees
  union  all
  select employee_id, start_date, end_date, job_id, department_id 
  from   job_history