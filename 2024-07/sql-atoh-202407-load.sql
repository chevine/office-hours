set define on
set echo on

rem define n = &1

select &1;

declare
  max_id int := 300;
begin
  for i in 1 .. &1 loop
    insert into employees ( employee_id, first_name, last_name, email, hire_date, job_id, department_id )
      select max_id + rownum,
             first_name || i, last_name , i || email, 
             hire_date, job_id, department_id 
      from   employees;
    max_id := max_id + sql%rowcount;
  end loop;
  commit;
end;
/
