@sql-atl-202606-setup



/* Change email address domain */
update employees 
set    email = email || '@ACME.COM';


/* leave uncommitted... */
/* Go to session 2 */











/* Check ASH data (requires license) */
select session_id, session_serial#,
       blocking_session, blocking_session_serial#, 
       event, sample_time
from   v$active_session_history
where  true 
and    blocking_session_status = 'VALID'
and    sample_time > systimestamp - interval '2' hour 
and    blocking_session is not null;


/* Get blocking details from dba_locks */
select sid, serial#, event, lck.* 
from   dba_locks lck
join   v$session 
on     sid = session_id
join   v$transaction 
on     lock_id2 = xidsqn;




/* Stop blocked SQL statement from running */
alter system cancel sql '57, 39298';





/* Other DML can block too - e.g. clash on PK values */
insert into employees 
set    employee_id = 42, -- PK
       last_name = 'Blocker',
       email = 'BLOCKER',
       hire_date = sysdate,
       job_id = 'IT_PROG';
/* Back to session 2 */




select sid, serial#, event, lck.* 
from   dba_locks lck
join   v$session 
on     sid = session_id
join   v$transaction 
on     lock_id2 = xidsqn;

/* Releases lock, allowing session 2 to complete */
rollback;



/********************************



********************************/


/* Change email address domain */
update employees 
set    email = email || '@ACME.COM';

/* And add a new employees */
insert into employees 
set    employee_id = 42,
       last_name = 'Blocker',
       email = 'BLOCKER@ACME.COM',
       hire_date = sysdate,
       job_id = 'IT_PROG';
/* over to second session... */








rollback;


/********************************



********************************/


sho parameter prior

/* Lower transaction priority */
alter session set txn_priority = medium;
/* Log that you would have taken priority */
alter system set priority_txns_mode = track;
/* Set how long to wait to steal lock in seconds */
alter system set priority_txns_high_wait_target = 5; 






/* Change email address domain */
update employees 
set    email = email || '@ACME.COM';

/* View the current transaction priority */
select txn_priority 
from   v$transaction
join   v$session
on     addr = taddr
where  sid = sys_context ( 'USERENV', 'SID' );

/* Check how trx priority has kicked in */
select name, value
from   v$sysstat
where  name like '%priority_txn%';
/* Over to session 2 */



/* Tracked priority count increase */
select name, value
from   v$sysstat
where  name like '%priority_txn%';

rollback;



/* Force rollback when taking priority */
alter system set priority_txns_mode = rollback;

/* Change email address domain */
update employees 
set    email = email || '@ACME.COM';



/* Back to session 2 */



select name, value
from   v$sysstat
where  name like '%priority_txn%';

rollback;

/* Email change undone */
select * from employees;

-- rollback session 2

/********************************




********************************/



/* Try to add a reservable column 
   to allow concurrent updates */
alter table departments 
  add free_lunches integer reservable;






alter table departments 
  add primary key ( department_id );

alter table departments 
  add free_lunches integer reservable
  default 20
  check ( free_lunches >= 0 );

select * from departments;






/* Try to get a free lunch... */
update departments 
set    free_lunches = free_lunches - 1,
       department_name = department_name;
/* Can't mix and match (non)reservable columns */

update departments 
set    free_lunches = free_lunches - 1;
/* Must filter on whole primary key */







update departments 
set    free_lunches = free_lunches - 1
where  department_id = 10;
/* Over to session 2 */
rollback;






/* Can see session 2 change; but not own yet */
select * from departments;

commit;

/* Now we can see all the changes */
select * from departments;





/* Constraint violation => immediate error */
update departments 
set    free_lunches = free_lunches - 20
where  department_id = 10;







/* Can't set to a specific value; only +/- value */
update departments 
set    free_lunches = 20
where  department_id = 10;


/* Reset to specific value by adding the difference between the target value and the column's current value */
update departments t
set    free_lunches = free_lunches + ( 20 - free_lunches )
where  department_id = 10;

commit;

select * from departments 
where  department_id = 10;
