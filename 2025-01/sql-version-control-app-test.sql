select * from hr.employee_job_changes
where  employee_id = 100;

exec hr.change_job ( 100, 'IT_PROG', 10 );

select * from hr.employee_job_changes
where  employee_id = 100;

rollback;



/***********************************/




/***********************************/

select * from user_schema_privs;

-- Access to all tables in HR
select * from hr.job_history;
select * from hr.jobs;

-- But not other schemas
select * from sh.sales;
