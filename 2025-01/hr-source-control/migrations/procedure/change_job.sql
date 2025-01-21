create or replace procedure change_job ( 
  employee_id int, new_job_id varchar2, new_dept_id int
) as
begin

  insert into job_history ( employee_id, start_date, end_date, job_id, department_id )
    select e.employee_id, e.hire_date, trunc ( sysdate ), e.job_id, e.department_id
    from   employees e
    where  e.employee_id = change_job.employee_id;
    
  update employees
  set    job_id = new_job_id, department_id = new_dept_id,
         hire_date = trunc ( sysdate )
  where  employee_id = change_job.employee_id;

end;
/