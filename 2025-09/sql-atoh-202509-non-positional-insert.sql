@sql-atoh-202509-setup.sql





/* What's wrong with this insert? */
insert into employees ( 
  employee_id, hire_date, job_id, 
  first_name, last_name, email
) values ( 
  210, sysdate, 'AD_ASST', 
  'SSQUIRREL', 'Sally', 'Squirrel' 
);








/* Check the data... */
select first_name, last_name, email 
from   employees 
where  employee_id = 210;



/* Back it out */
rollback;






/* Align columns and values - problem solved? */
insert into employees ( employee_id, hire_date, job_id,    email,       first_name, last_name ) 
values (                210,         sysdate,   'AD_ASST', 'SSQUIRREL', 'Sally',    'Squirrel' );








/* May not help when doing the good thing and using bind variables */
insert into employees ( employee_id, hire_date, job_id, first_name, last_name, email ) 
values (                :v1,         :v2,       :v3,    :v4,        :v5,       :v6   );







/* Problem: value is decoupled from column you're inserting it into 
   Can these be brought closer? */





/* Insert PL/SQL records */
declare
  emp_rec employees%rowtype;
begin
  emp_rec.employee_id := 210;
  emp_rec.first_name  := 'Sally';
  emp_rec.last_name   := 'Squirrel';
  emp_rec.email       := 'SSQUIRREL';
  emp_rec.hire_date   := sysdate;
  emp_rec.job_id      := 'AD_ASST';

  insert into employees values emp_rec;
end;
/

select first_name, last_name, email 
from   employees 
where  employee_id = 210;

rollback;




/* Record inserts always sets every visible column
   This has limitations - e.g. virtual columns */
alter table employees 
  add ( 
    full_name as (
      first_name || ' ' || last_name
    ) 
  );


declare
  emp_rec employees%rowtype;
begin
  emp_rec.employee_id := 210;
  emp_rec.first_name  := 'Sally';
  emp_rec.last_name   := 'Squirrel';
  emp_rec.email       := 'SSQUIRREL';
  emp_rec.hire_date   := sysdate;
  emp_rec.job_id      := 'AD_ASST';

  insert into employees values emp_rec;
end;
/


/* Remove virtual column */
alter table employees 
  drop ( full_name );

/* Add an invisible column */
alter table employees
  modify email invisible;

declare
  emp_rec employees%rowtype;
begin
  emp_rec.employee_id := 210;
  emp_rec.first_name  := 'Sally';
  emp_rec.last_name   := 'Squirrel';
  emp_rec.email       := 'SSQUIRREL';
  emp_rec.hire_date   := sysdate;
  emp_rec.job_id      := 'AD_ASST';

  insert into employees values emp_rec;
end;
/

/* Make visible again */
alter table employees
  modify email visible;









/* This isn't a problem for update... */
update employees
set    hire_date = sysdate,
       job_id    = 'AD_ASST'
where  employee_id = 210;

/* What if we made INSERT more like UPDATE? */


/******************************



******************************/



/* Starting in  23.9: INSERT INTO ... SET */
insert into employees 
set    employee_id = 210,
       hire_date   = sysdate, 
       job_id      = 'AD_ASST', 
       first_name  = 'Sally',
       last_name   = 'Squirrel', 
       email       = 'SSQUIRREL';






select first_name, last_name, email 
from   employees 
where  employee_id = 210;

rollback;






/* What about mutli-row inserts added in 23ai? */
insert into employees ( 
  employee_id, hire_date, job_id,    first_name, last_name,  email 
) values ( 
  210,         sysdate,   'AD_ASST', 'Sally',    'Squirrel', 'SSQUIRREL' 
), ( 
  211,         sysdate,   'IT_PROG', 'Quinn',    'Quetzal',  'QQUETZAL' 
), (
  212,         sysdate,   'IT_PROG', 'Lisa',     'Lemur',    'LLEMUR' 
);




/* Non-positional multi-row insert - brackets required */
insert into employees 
set ( 
  employee_id = 210,     hire_date = sysdate,    job_id = 'AD_ASST', 
  first_name  = 'Sally', last_name = 'Squirrel', email = 'SSQUIRREL' 
), ( 
  employee_id = 211,     hire_date = sysdate,    job_id = 'IT_PROG', 
  first_name  = 'Quinn', last_name = 'Quetzal',  email = 'QQUETZAL' 
), ( 
  employee_id = 212,     hire_date = sysdate,    job_id = 'IT_PROG', 
  first_name  = 'Lisa',  last_name = 'Lemur',    email = 'LLEMUR' 
);

select * from employees
where  hire_date > sysdate - 1;

rollback;





/* With VALUES all rows must supply columns for the same value in the same order 
   With SET can switch up column order and omit columns for some rows */
insert into employees 
set ( 
  employee_id = 210,     hire_date = sysdate,    job_id = 'AD_ASST', 
  first_name  = 'Sally', last_name = 'Squirrel', email = 'SSQUIRREL' 
), ( 
  first_name  = 'Quinn', last_name = 'Quetzal',  email = 'QQUETZAL',
  employee_id = 211,     hire_date = sysdate,    job_id = 'IT_PROG' 
), ( 
  hire_date = sysdate,   job_id = 'IT_PROG', 
  last_name = 'Lemur',   email = 'LLEMUR' 
);





/* But I want to ensure we set every column for every row! */



/* Define column list to ensure all columns are defined */
insert into employees ( 
  first_name, last_name, email, employee_id, hire_date, job_id  
) set ( 
  employee_id = 210,     hire_date = sysdate,    job_id = 'AD_ASST', 
  first_name  = 'Sally', last_name = 'Squirrel', email = 'SSQUIRREL' 
), ( 
  first_name  = 'Quinn', last_name = 'Quetzal',  email = 'QQUETZAL',
  employee_id = 211,     hire_date = sysdate,    job_id = 'IT_PROG' 
), ( 
  hire_date = sysdate,   job_id = 'IT_PROG', 
  last_name = 'Lemur',   email = 'LLEMUR' 
);




/* ...into and set list columns can still be in different orders though! */
insert into employees ( 
  first_name, last_name, email, employee_id, hire_date, job_id  
) set ( 
  employee_id = 210,     hire_date = sysdate,    job_id = 'AD_ASST', 
  first_name  = 'Sally', last_name = 'Squirrel', email = 'SSQUIRREL' 
), ( 
  first_name  = 'Quinn', last_name = 'Quetzal',  email = 'QQUETZAL',
  employee_id = 211,     hire_date = sysdate,    job_id = 'IT_PROG' 
);



/* Can also SET column list */
insert into employees 
set   ( 
  employee_id, hire_date, job_id, first_name, last_name, email 
) = ( 
  210, sysdate, 'AD_ASST', 'Sally', 'Squirrel', 'SSQUIRREL' 
);


rollback;





/* and assign column groups */
insert into employees 
set    ( 
  ( employee_id, hire_date, job_id ) = ( 210, sysdate, 'AD_ASST' ), 
  ( first_name, last_name, email ) = ( 'Sally', 'Squirrel', 'SSQUIRREL' )
);




/* What's the point of this? */



/* Could be useful when using different subqueries to get values */
insert into job_history 
set  ( 
  ( employee_id, start_date, job_id ) = ( 
    select employee_id, hire_date, job_id -- this must return at most one row
    from   employees 
    where  employee_id = 100 
  ), 
  end_date = sysdate, 
  department_id = ( 
    select department_id -- this must return at most one row
    from   departments 
    where  department_name = 'Administration' 
  )
);




/* Sidenote: column groups also work for UPDATE from 23.9 */
update job_history 
set   
  ( employee_id, start_date, job_id ) = ( 
    select employee_id, hire_date, job_id -- this must return at most one row
    from   employees 
    where  employee_id = 100 
  ), 
  end_date = sysdate, 
  department_id = ( 
    select department_id -- this must return at most one row
    from   departments 
    where  department_name = 'Administration' 
  )
where  employee_id = 201;

rollback;




/* Resilient to table changes */
alter table employees 
  add (
    company_id int default 1 not null,
    full_name as ( first_name || ' ' || last_name )
  );

alter table employees
  modify email invisible;


/* Above changes break this insert */
insert into employees 
values ( 210, 'Sally', 'Squirrel', 'SSQUIRREL', '1.515.555.0000', sysdate, 'AD_ASST', 10000, null, 100, 90 );



/* Non-positional insert still works */
insert into employees 
set    employee_id = 210,
       hire_date   = sysdate, 
       job_id      = 'AD_ASST', 
       first_name  = 'Sally',
       last_name   = 'Squirrel', 
       email       = 'SSQUIRREL';


select * from employees
where  employee_id = 210;

rollback;

/* Clean up */
alter table employees
  drop ( full_name, company_id );

alter table employees
  modify email visible;







/* So that's great for row inserts...
   What about inserting query results? 
   INSERT ... SELECT */
insert into job_history 
  select employee_id, job_id, 
         hire_date start_date, sysdate end_date, 
         department_id 
  from   employees;





/* Problem: into and select column lists in different orders :( */






/* INSERT ... BY NAME SELECT 
   Match subquery column aliases to target table column names */
insert into job_history 
by name 
  select employee_id, job_id, 
         hire_date start_date, sysdate end_date, 
         department_id
  from   employees;






/* Matching is on column name or alias
   => you must alias expressions */
insert into job_history 
by name 
  select employee_id, job_id, hire_date, sysdate, department_id 
  from   employees;




/* Matching is on column name only 
   Table aliases ignored */
insert into job_history 
by name 
  select e.employee_id, e.job_id, 
         e.hire_date start_date, sysdate end_date, 
         e.department_id 
  from   employees e;








/* Can provide column list to insert subset of columns */
insert into job_history (
  employee_id, job_id, start_date, end_date
) by name 
  select hire_date start_date, sysdate end_date, 
         employee_id, job_id 
  from   employees;
/* All columns in insert list must be in select list (in any order) */








/* BY POSITION is default and previous behaviour */
insert into job_history 
by position 
  select employee_id, hire_date, sysdate, job_id, department_id 
  from   employees;

rollback;




/* BY { NAME | POSITION } only for INSERT ... SELECT,
   not INSERT SET ... */
insert into employees 
by name -- invalid
set    employee_id = 210,
       hire_date   = sysdate, 
       job_id      = 'AD_ASST', 
       first_name  = 'Sally',
       last_name   = 'Squirrel', 
       email       = 'SSQUIRREL';





/******************************



******************************/


/* SET clause also available for other forms of INSERT */
/* Upsert employee details into job_history */
merge into job_history j
using employees e
on  ( j.employee_id = e.employee_id )
when matched then
  update 
  set    j.job_id = e.job_id, 
         j.department_id = e.department_id
when not matched then
  insert 
  set    j.employee_id = e.employee_id,
         j.start_date = e.hire_date,
         j.end_date = sysdate,
         j.job_id = e.job_id;




/* Can also use an explicit column list if desired */
merge into job_history j
using employees e
on  ( j.employee_id = e.employee_id )
when matched then
  update 
  set    j.job_id = e.job_id, 
         j.department_id = e.department_id
when not matched then
  -- Must alias target columns in explicit list
  insert ( j.employee_id, j.start_date, j.end_date, j.job_id )
  set    j.employee_id = e.employee_id,
         j.start_date = e.hire_date,
         j.end_date = sysdate,
         j.job_id = e.job_id;


rollback;











/* INSERT SET also works for multi-table inserts */
insert all
  into employees 
  set  employee_id = emp_id,     job_id    = job_id,    hire_date = hire_date, 
       first_name  = first_name, last_name = last_name, email = email
  into job_history 
  set  employee_id = emp_id,    job_id = job_id, 
       start_date  = hire_date, end_date = sysdate
select 210 emp_id, date'2025-01-01' hire_date, 'AD_ASST' job_id, 
       'Sally' first_name, 'Squirrel' last_name, 'SSQUIRREL' email;

rollback;




/* Muti-row insert unsupported... */
insert all
  into employees 
  set  ( employee_id = emp_id,     job_id    = job_id,    hire_date = hire_date, 
       first_name  = first_name, last_name = last_name, email = email ),
       ( employee_id = emp_id,     job_id    = job_id,    hire_date = hire_date, 
       first_name  = first_name, last_name = last_name, email = email )
  into job_history 
  set  employee_id = emp_id,    job_id = job_id, 
       start_date  = hire_date, end_date = sysdate
select 210 emp_id, date'2025-01-01' hire_date, 'AD_ASST' job_id, 
       'Sally' first_name, 'Squirrel' last_name, 'SSQUIRREL' email;




/* ... insert two the same table twice instead */
insert all
  into employees 
  set  employee_id = emp_id,     job_id    = job_id,    hire_date = hire_date, 
       first_name  = first_name, last_name = last_name, email = email
  into employees 
  set  employee_id = emp_id,     job_id    = job_id,    hire_date = hire_date, 
       first_name  = first_name, last_name = last_name, email = email
  into job_history 
  set  employee_id = emp_id,    job_id = job_id, 
       start_date  = hire_date, end_date = sysdate
select 210 emp_id, date'2025-01-01' hire_date, 'AD_ASST' job_id, 
       'Sally' first_name, 'Squirrel' last_name, 'SSQUIRREL' email;

rollback;








/* Works with error logging and returning clauses */
exec dbms_errlog.create_error_log ( 'employees' );
exec dbms_errlog.create_error_log ( 'job_history' );

insert into job_history 
by name 
  select e.employee_id, e.job_id, 
         e.hire_date start_date, 
         'junk' end_date, -- invalid data
         e.department_id 
  from   employees e
  log errors
  reject limit unlimited;

select * from err$_job_history;



insert into employees 
set    employee_id = 210,
       hire_date   = 'junk', -- invalid data
       job_id      = 'AD_ASST', 
       first_name  = 'Sally',
       last_name   = 'Squirrel', 
       email       = 'SSQUIRREL'
returning employee_id into :e
log errors reject limit unlimited;

select * from err$_employees;




var e number;

insert into employees 
set    employee_id = 210,
       hire_date   = sysdate,
       job_id      = 'AD_ASST', 
       first_name  = 'Sally',
       last_name   = 'Squirrel', 
       email       = 'SSQUIRREL'
returning employee_id into :e
log errors reject limit unlimited;

print :e;

rollback;


/******************************



******************************/



/* What's the problem with this statement? */
select job_id, 
       trunc ( hire_date, 'yyyy' ) yr,
       count (*) 
from   employees
group  by job_id;







/* Fixed it? */ 
select job_id, 
       trunc ( hire_date, 'yyyy' ) yr,
       count (*) 
from   employees
group  by job_id,
       hire_date;






/* ...hire_date grouping happens BEFORE trunc */





/* 23ai GA: GROUP BY alias */ 
select job_id, 
       trunc ( hire_date, 'yyyy' ) yr,
       count (*) 
from   employees
group  by job_id, 
       yr;





/* ...but what if we have 20+ expressions in the select? */






/* 23.9: GROUP BY ALL */
select job_id, 
       trunc ( hire_date, 'yyyy' ) yr,
       count (*) 
from   employees
group  by all; -- equivalent to job_id, yr





/* Beware combining * and ALL: results can change! */
with rws as (
  select department_id
      --  , job_id
  from   employees
)
select rws.*, count(*) 
from   rws
group  by all;





/* Doesn't work with ROLLUP/CUBE/GROUPING SETS */
with rws as (
  select department_id
  from   employees
)
select rws.*, count(*) 
from   rws
group  by rollup ( all );





/* List columns as normal to compute superaggregates */
with rws as (
  select department_id
  from   employees
)
select department_id, count(*) 
from   rws
group  by rollup ( department_id );











/* Back to INSERTs */
insert into employees 
set    employee_id = 210, -- UUIDs instead of sequences/integers?
       hire_date   = sysdate, 
       job_id      = 'AD_ASST', 
       first_name  = 'Sally',
       last_name   = 'Squirrel', 
       email       = 'SSQUIRREL';







/* Add UUID/GUIDs to employees */
alter table employees 
  add employee_uuid raw(16);

update employees
set    employee_uuid = sys_guid();

select employee_uuid from employees;






/* SYS_GUID values are sequential in session
   Generated by Oracle algorithm, not compliant with UUID RFC 9562 */



/* New UUID function - version 4 compliant (random) UUID generator */
update employees
set    employee_uuid = uuid ();

select employee_uuid from employees;




/* SYS_GUID vs UUID */
with rws as (
  select uuid() as id, 
         sys_guid() as gid,
         dbms_random.string ( 'X', 32 ) str
  connect by level <= 10
)
select id, gid, str,
       is_uuid ( raw_to_uuid ( id ) ) uuid_is_v4,
       is_uuid ( rawtohex ( gid ) ) uuid_not_v4,
       is_uuid ( str ) str_not_uuid
from   rws;








/* UUID generates raw values; RAW_TO_UUID to convert to string */
with rws as (
  select uuid (0) as id -- version parameter optional; 0 => v4
  connect by level <= 10
)
select id raw_uid, 
       raw_to_uuid ( id ) string_uid,
       cast ( id as varchar2(32) ) cast_uid,
       dump ( id ) raw_value
from   rws;






/* But what if you want RFC compliant UUIDs for other versions? 
   Use JavaScript! */





/* Here's an open source version - ensure you check licensing before using! */
-- curl -Lo /tmp/uuidv7.js 'https://cdn.jsdelivr.net/npm/uuidv7@1.0.2/dist/index.min.js' 
-- curl -o c:\temp\uuidv7.js https://cdn.jsdelivr.net/npm/uuidv7@1.0.2/dist/index.min.js 

-- Run in SQLcl
-- mle create-module -filename ./uuidv7.js -module-name uuidv7_module -version '1.0.2'
-- mle create-module -filename c:\temp\uuidv7.js -module-name uuidv7_module -version '1.0.2'

select * from user_mle_modules;

create or replace function uuidv7
return varchar2
as mle module uuidv7_module
signature 'uuidv7';
/


select uuidv7()
connect by level <= 10;



/* 23.9 Includes a few JS improvements */
/* No longer require EXECUTE ON JAVASCRIPT */
select * from user_tab_privs;


/* Also get compile time errors for JS */
create or replace function date_to_epoch (
  "theDate" timestamp with time zone
)
return number
as mle language javascript
{{
  const d = nw Date(theDate);

  if (isNaN(d)){
    throw new Error(`${theDate} is not a valid date`);
  }

  return d.getTime() / 1000;
}};
/

create or replace function date_to_epoch (
  "theDate" timestamp with time zone
)
return number
as mle language javascript
{{
  const d = new Date(theDate);

  if (isNaN(d)){
    throw new Error(`${theDate} is not a valid date`);
  }

  return d.getTime() / 1000;
}};
/


select date_to_epoch ( systimestamp );