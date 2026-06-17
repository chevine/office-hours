
















/* Issue pay rises */
update employees 
set    salary = salary * 1.1;

/* Now we're stuck :( 
   Back to session 1 */






/* Insert another row with same PK 
   => must wait for session one to commit/rollback */
insert into employees 
set    employee_id = 42, -- same PK
       last_name = 'Blockee',
       email = 'BLOCKED',
       hire_date = sysdate,
       job_id = 'IT_PROG';
/* Return to session 1 */

rollback;





/********************************



********************************/






/* DML [no]wait clause in 23.26.2 */
/* Fail immediately if can't get lock! */
update employees 
set    salary = salary * 1.1
nowait;

/* Wait 5 seconds */
update employees 
set    salary = salary * 1.1
wait   5;

/* Wait 5 microseconds */
update employees 
set    salary = salary * 1.1
wait   5 microseconds;




/* Also have this clause on DELETE */
delete employees 
nowait;


/* and on INSERT */
insert into employees 
set    employee_id = 42,
       last_name = 'Blocker',
       email = 'BLOCKER',
       hire_date = sysdate,
       job_id = 'IT_PROG'
nowait;




/* SELECT ... FOR UPDATE now has subsecond units */
select * from employees
for    update 
wait   42 milliseconds;





/* Wait indefinitely (default) */
update employees 
set    salary = salary * 1.1
wait   forever;

/* Return to session 1 */





rollback;





/********************************





********************************/



sho parameter prior

/* HIGH priority transaction overrules MEDIUM 
   But we're only tracking so session 1 not undone */
update employees 
set    salary = salary * 1.1
wait   30 seconds;
/* Back to session 1 */





/* HIGH priority transaction overrules MEDIUM 
   This time we force MEDIUM to rollback */
update employees 
set    salary = salary * 1.1
wait   forever;


rollback;






/********************************




********************************/







/* Two sessions can update RESERVABLE column concurrently */
update departments 
set    free_lunches = free_lunches - 2
where  department_id = 10;

/* There are no blockers */
select lck.* 
from   dba_locks lck
join   v$transaction 
on     lock_id2 = xidsqn;





/* But change not visible... */
select * from departments
where  department_id = 10;






/* ...until you commit */
commit;

select * from departments
where  department_id = 10;
/* Back to session 1 */



