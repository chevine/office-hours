



/* Create view to show history */
create or replace force view employee_job_changes as 
  select employee_id, hire_date, null end_date, job_id, department_id 
  from   employees
  union  all
  select * from job_history;











/* Create procedure to change job */
create or replace procedure change_job ( 
  employee_id int, new_job_id varchar2, new_dept_id int
) as
begin

  insert into job_history
    select e.employee_id, e.hire_date, trunc ( sysdate ), e.job_id, e.department_id
    from   employees e
    where  e.employee_id = change_job.employee_id;
    
  update employees
  set    job_id = new_job_id, department_id = new_dept_id,
         hire_date = trunc ( sysdate )
  where  employee_id = change_job.employee_id;

end;
/




select * from job_history;

/* Check new changes work */
select * from employee_job_changes
where  employee_id = 100;

exec change_job ( 100, 'IT_PROG', 10 );

select * from employee_job_changes
where  employee_id = 100;

rollback;







/* TODO PASTE CHANGES FROM JASMIN */







/* Check works as HR_APP */










/* TODO GET GRANTS FROM JASMIN */








/* Check HR_APP again */





/* Try recreating view & proc*/