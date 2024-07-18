set define on
@sql-atoh-202407-setup
@sql-atoh-202407-load 12 
set define off




select count(*) from employees;

/* Move every European employee without a US/Americas manager 
   to global operations dept */
insert into departments values ( 280, 'Global operations', null, 2500 );
commit;







set timing on
declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin 
  for emps in ( 
    select employee_id, department_id, job_id
    from   employees e
    join   departments d using ( department_id )
    join   locations     using ( location_id )
    join   countries     using ( country_id )
    join   regions       using ( region_id )
    where  region_name = 'Europe'
    and    not exists (
      select * from employees m
      join   departments d using ( department_id )
      join   locations     using ( location_id )
      join   countries     using ( country_id )
      join   regions       using ( region_id )
      where  region_name = 'Americas'
      and    e.manager_id = m.employee_id
    )
  ) loop

    insert into job_history ( employee_id, start_date, job_id, department_id )
    values ( emps.employee_id, transfer_date, emps.job_id, emps.department_id );

    update employees e
    set    department_id = new_dept_id
    where  e.employee_id = emps.employee_id;

  end loop;
end;
/

/* Check how many moved over */
select count(*) from employees
where  department_id = 280;


/* How can we improve it?! */
/* Let's find out! */
/**********************************/




/**********************************/

/* Reset */
@@sql-atoh-202407-setup
/* Smaller data set to make this manageable */
select count(*) from employees;

insert into departments values ( 280, 'Global operations', null, 2500 );
commit;







/* Refactor query */
select employee_id, department_id, job_id
from   employees e   -- duplicate joins
join   departments d using ( department_id )
join   locations     using ( location_id )
join   countries     using ( country_id )
join   regions       using ( region_id )
where  region_name = 'Europe'
and    not exists (
  select null 
  from   employees m -- duplicate joins
  join   departments d using ( department_id )
  join   locations     using ( location_id )
  join   countries     using ( country_id )
  join   regions       using ( region_id )
  where  region_name = 'Americas'
  and    e.manager_id = m.employee_id
);



/* Refactor using CTEs */
with employee_regions as (
  select employee_id, first_name, last_name, job_id, 
         e.manager_id as emp_manager_id,
         department_id, region_name, d.manager_id as dept_manager_id
  from   employees e
  join   departments d using ( department_id )
  join   locations     using ( location_id )
  join   countries     using ( country_id )
  join   regions       using ( region_id )
)
select * from employee_regions e
where  region_name = 'Europe'
and    not exists (
  select null from employee_regions m
  where  e.emp_manager_id = m.employee_id
  and    m.region_name = 'Americas'
);





/* Refactor further => create view */
create or replace view employee_regions as
  select employee_id, first_name, last_name, job_id, e.manager_id as emp_manager_id,
         department_id, department_name, d.manager_id as dept_manager_id,
         location_id, street_address, postal_code, city, state_province,
         country_id, country_name,
         region_id, region_name
  from   employees e
  join   departments d using ( department_id )
  join   locations     using ( location_id )
  join   countries     using ( country_id )
  join   regions       using ( region_id );



/* Check the view */
select * from employee_regions;







/* Use the view */

select * from employee_regions e
where  region_name = 'Europe'
and    not exists (
  select null from employee_regions m
  where  e.emp_manager_id = m.employee_id
  and    m.region_name = 'Americas'
);


/* But is it the same?! */






/* Compare old and new queries
   This should return no rows */
select employee_id, department_id, job_id from (
  select employee_id, department_id, job_id 
  from   employee_regions e
  where  region_name = 'Europe'
  and    not exists (
    select null from employee_regions m
    where  e.emp_manager_id = m.employee_id
    and    m.region_name = 'Americas'
  )  
  union  all
  select employee_id, department_id, job_id
  from   employees e
  join   departments d using ( department_id )
  join   locations     using ( location_id )
  join   countries     using ( country_id )
  join   regions       using ( region_id )
  where  region_name = 'Europe'
  and    not exists (
    select * from employees m
    join   departments d using ( department_id )
    join   locations     using ( location_id )
    join   countries     using ( country_id )
    join   regions       using ( region_id )
    where  region_name = 'Americas'
    and    e.manager_id = m.employee_id
  )
)
group by employee_id, department_id, job_id
having count(*) <> 2;





/* Make the whole query a view? */
create or replace view eu_emps_no_amer_manager as 
  select * from employee_regions e
  where  region_name = 'Europe'
  and    not exists (
    select null from employee_regions m
    where  e.emp_manager_id = m.employee_id
    and    m.region_name = 'Americas'
  );



/* Simple query... */
select * from eu_emps_no_amer_manager;
/* ...but what if we want different regions? */







/* Create a table macro! */
create or replace function emp_in_region_without_manager_in_region (
  employee_region varchar2, manager_region varchar2
)
  return clob sql_macro ( table ) as 
begin

  return q'!  
  select * from employee_regions e
  where  region_name = employee_region
  and    not exists (
    select null from employee_regions m
    where  e.emp_manager_id = m.employee_id
    and    m.region_name = manager_region
  ) !';

end emp_in_region_without_manager_in_region;
/

/* Use the macro */
select * from emp_in_region_without_manager_in_region (
  employee_region => 'Europe', manager_region => 'Americas'
);





/* Double check it's the same */
select employee_id, department_id, job_id from (
  select employee_id, department_id, job_id 
  from   emp_in_region_without_manager_in_region (
    employee_region => 'Europe', manager_region => 'Americas'
  )
  union  all
  select employee_id, department_id, job_id
  from   employees e
  join   departments d using ( department_id )
  join   locations     using ( location_id )
  join   countries     using ( country_id )
  join   regions       using ( region_id )
  where  region_name = 'Europe'
  and    not exists (
    select * from employees m
    join   departments d using ( department_id )
    join   locations     using ( location_id )
    join   countries     using ( country_id )
    join   regions       using ( region_id )
    where  region_name = 'Americas'
    and    e.manager_id = m.employee_id
  )
)
group by employee_id, department_id, job_id
having count(*) <> 2;







/* Americas employees without EU manager */
select * from emp_in_region_without_manager_in_region (
  employee_region => 'Americas', manager_region => 'Europe'
);

/* Americas employees without Americas manager */
select * from emp_in_region_without_manager_in_region (
  employee_region => 'Europe', manager_region => 'Europe'
);










/* Use the new query */
declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin 
  for emps in ( 
    select employee_id, department_id, job_id 
    from   emp_in_region_without_manager_in_region (
      employee_region => 'Europe', manager_region => 'Americas'
    )
  ) loop

    insert into job_history ( employee_id, start_date, job_id, department_id )
    values ( emps.employee_id, transfer_date, emps.job_id, emps.department_id );

    update employees e
    set    department_id = new_dept_id
    where  e.employee_id = emps.employee_id;

  end loop;
end;
/
rollback;
/* But how do we make this faster?! */



/**********************************/




/**********************************/


/* 3 table plan */
select * 
from   locations   
join   countries using ( country_id )
join   regions   using ( region_id );











/* Which order will the database read the tables? */
select *
from   employees 
join   departments using ( department_id )
join   locations   using ( location_id )
join   countries   using ( country_id )
join   regions     using ( region_id )
where  region_name = 'Europe';


/* Check the plan! */







/* This is what really happened */
/* op 11 */ select *                       
/* op  9 */ from   employees               
/* op  7 */ join   departments             
/* op 10 */ using ( department_id )        
/* op  2 */ join   locations       -- Op 4!!
/* op  8 */ using ( location_id )          
/* op  5 */ join   countries               
/* op  6 */ using ( country_id )           
/* op  1 */ join   regions         -- Op 4!!
/* op  6 */ using ( region_id )            
/* op  1 */ where  region_name = 'Europe'; 






/* Is this really the CORRECT plan?! 
   Is REGIONS really the smallest table? */
alter session set statistics_level = all; -- capture plan stats
set serveroutput off

select employee_id, department_id, job_id
from   employees 
join   departments using ( department_id )
join   locations   using ( location_id )
join   countries   using ( country_id )
join   regions     using ( region_id )
where  region_name = 'Europe';

select * from dbms_xplan.display_cursor( format => 'ROWSTATS LAST');



/* What about an index? */
create index regi_name_i on regions ( region_name );

select employee_id, department_id, job_id
from   employees 
join   departments using ( department_id )
join   locations   using ( location_id )
join   countries   using ( country_id )
join   regions     using ( region_id )
where  region_name = 'Europe';

select * from dbms_xplan.display_cursor( format => 'ROWSTATS LAST');







/* What about more indexes? */
create index emp_dept_i on employees ( department_id );
create index coun_region_i on countries ( region_id );
create index loc_country_i on locations ( country_id );
create index dept_loc_i on departments ( location_id );

select employee_id, department_id, job_id
from   employees 
join   departments using ( department_id )
join   locations   using ( location_id )
join   countries   using ( country_id )
join   regions     using ( region_id )
where  region_name = 'Europe';

select * from dbms_xplan.display_cursor( format => 'ROWSTATS LAST');











/* So what difference does it make? */
@sql-atoh-202407-load 12 
set serveroutput on
declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin
  for emps in ( 
    select employee_id, department_id, job_id 
    from   emp_in_region_without_manager_in_region (
      employee_region => 'Europe', manager_region => 'Americas'
    )
  ) loop
    insert into job_history ( employee_id, start_date, job_id, department_id )
    values ( emps.employee_id, transfer_date, emps.job_id, emps.department_id );

    update employees e
    set    department_id = new_dept_id
    where  e.employee_id = emps.employee_id;
  end loop;
end;
/
/* Hmmm */
rollback;



/* Let's check the plan */
select * from dbms_xplan.display_cursor ( 
  sql_id => '4kvrxktc2xkq8', 
  format => 'ROWSTATS LAST'
);





/* Getting lots of employees => remove index? */
drop index emp_dept_i ;

declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin
  for emps in ( 
    select employee_id, department_id, job_id 
    from   emp_in_region_without_manager_in_region (
      employee_region => 'Europe', manager_region => 'Americas'
    )
  ) loop
    insert into job_history ( employee_id, start_date, job_id, department_id )
    values ( emps.employee_id, transfer_date, emps.job_id, emps.department_id );

    update employees e
    set    department_id = new_dept_id
    where  e.employee_id = emps.employee_id;
  end loop;
end;
/
/* Back to where we were... */

rollback;



/* It's not the query! Remove DML to see */
set serveroutput on
declare 
  start_time pls_integer;
begin
  
  for emps in ( 
    select employee_id, department_id, job_id 
    from   emp_in_region_without_manager_in_region (
      employee_region => 'Europe', manager_region => 'Americas'
    )  
  ) loop
    null;
  end loop;
end;
/
/* So how do we fix the DML? */



/**********************************/




/**********************************/

/* Compare SQL performance */
create table t ( 
  c1 int primary key, 
  c2 varchar2(100) default lpad ( 'x', 100, 'x' )
);

/* Compare:
   250k 1 row inserts to one 250k row insert
   250k 1 row updates to one 250k row update
   250k 1 row deletes to one 250k row delete
*/
set serveroutput on
declare
  rows_to_load   integer := 250000;
  rows_to_change integer := 250000;
  start_time     pls_integer;
begin
  dbms_output.put_line ( '******** INSERT ********* ' );
  start_time := dbms_utility.get_time();
  for i in 1 .. rows_to_load loop
    insert into t values ( i, default );
  end loop;
  dbms_output.put_line ( 'Many statements run time = ' || ( dbms_utility.get_time() - start_time ) );

  execute immediate 'truncate table t';

  start_time := dbms_utility.get_time();
  insert into t ( c1 )
    select level connect by level <= rows_to_load;
  dbms_output.put_line ( 'One statement run time = ' || ( dbms_utility.get_time() - start_time ) );
  
  commit;

  dbms_output.put_line ( '******** UPDATE ********* ' );
  
  start_time := dbms_utility.get_time();
  for i in 1 .. rows_to_change loop
    update t set c2 = 'test'
    where  c1 = i; 
  end loop;
  dbms_output.put_line ( 'Many statements run time = ' || ( dbms_utility.get_time() - start_time ) );
  
  rollback;

  start_time := dbms_utility.get_time();
  update t set c2 = 'test'
  where  c1 between 1 and rows_to_change;
  dbms_output.put_line ( 'One statement run time = ' || ( dbms_utility.get_time() - start_time ) );

  commit;

  dbms_output.put_line ( '******** DELETE ********* ' );

  start_time := dbms_utility.get_time();
  for i in 1 .. rows_to_change loop
    delete t 
    where  c1 = i; 
  end loop;
  dbms_output.put_line ( 'Many statements run time = ' || ( dbms_utility.get_time() - start_time ) );
  
  rollback;

  start_time := dbms_utility.get_time();
  delete t
  where  c1 between 1 and rows_to_change;
  dbms_output.put_line ( 'One statement run time = ' || ( dbms_utility.get_time() - start_time ) );

end;
/
commit;





/* So how do we rewrite our process? 
   Driving query 
   - Insert results
   - Filter update
 */
select employee_id, job_id, department_id
from   emp_in_region_without_manager_in_region (
  employee_region => 'Europe', manager_region => 'Americas'
) erwm;





/* Insert query result */
insert into job_history ( employee_id, start_date, job_id, department_id ) 
  select employee_id, sysdate, job_id, department_id
  from   emp_in_region_without_manager_in_region (
    employee_region => 'Europe', manager_region => 'Americas'
  ) erwm;



/* Move employees to new dept */
update employees e
set    e.department_id = 280
where  e.employee_id in ( 
  select erwm.employee_id 
  from   emp_in_region_without_manager_in_region (
    employee_region => 'Europe', manager_region => 'Americas'
  ) erwm
);




/* 23ai Update join */
update employees e
set    e.department_id = 280
from   emp_in_region_without_manager_in_region (
  employee_region => 'Europe', manager_region => 'Americas'
) erwm
where  e.employee_id = erwm.employee_id;

rollback;







/* Check - what difference did it make? */
select count(*) from employees;

/* Original code */
declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin 
  for emps in ( 
    select employee_id, department_id, job_id
    from   employees e
    join   departments d using ( department_id )
    join   locations     using ( location_id )
    join   countries     using ( country_id )
    join   regions       using ( region_id )
    where  region_name = 'Europe'
    and    not exists (
      select * from employees m
      join   departments d using ( department_id )
      join   locations     using ( location_id )
      join   countries     using ( country_id )
      join   regions       using ( region_id )
      where  region_name = 'Americas'
      and    e.manager_id = m.employee_id
    )
  ) loop

    insert into job_history ( employee_id, start_date, job_id, department_id )
    values ( emps.employee_id, transfer_date, emps.job_id, emps.department_id );

    update employees e
    set    department_id = new_dept_id
    where  e.employee_id = emps.employee_id;

  end loop;
end;
/

rollback;

/* New code */
declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin 

  insert into job_history ( employee_id, start_date, job_id, department_id ) 
    select employee_id, transfer_date, job_id, department_id
    from   emp_in_region_without_manager_in_region (
      employee_region => 'Europe', manager_region => 'Americas'
    ) erwm;

  update employees e
  set    e.department_id = new_dept_id
  from   emp_in_region_without_manager_in_region (
    employee_region => 'Europe', manager_region => 'Americas'
  ) erwm
  where  e.employee_id = erwm.employee_id;

end;
/

select count(*) from employees
where  department_id = 280;

rollback;




/* Want to tune further? We can get the plans! */
insert into job_history ( employee_id, start_date, job_id, department_id ) 
  select employee_id, :transfer_date, job_id, department_id
  from   emp_in_region_without_manager_in_region (
    employee_region => 'Europe', manager_region => 'Americas'
  ) erwm;

update employees e
set    e.department_id = :new_dept_id
from   emp_in_region_without_manager_in_region (
  employee_region => 'Europe', manager_region => 'Americas'
) erwm
where  e.employee_id = erwm.employee_id;

/**************************************/





/**************************************/


/* Bonus content */
/* Avoid double table accesses? */
select * from (
  select employee_id, department_id, 
         d.manager_id
  from   employees e
  join   departments d using ( department_id )
) emps
join   ( 
  select employee_id, department_id, 
         d.manager_id
  from   employees e
  join   departments d using ( department_id )
) mgrs
on     emps.manager_id = mgrs.employee_id;






/* WITH clause deduplicates for you! */
with rws as (
  select /*+ materialize */employee_id, department_id, 
         d.manager_id
  from   employees e
  join   departments d using ( department_id )
)
select * from rws emps;
join   rws mgrs
on     emps.manager_id = mgrs.employee_id;



/* Change macro to use WITH clause */
create or replace function emp_in_region_without_manager_in_region (
  employee_region varchar2, manager_region varchar2
)
  return clob sql_macro ( table ) as 
begin

  return q'!  
with employee_regions as (
  select employee_id, first_name, last_name, job_id, 
         e.manager_id as emp_manager_id,
         department_id, region_name
  from   employees e
  join   departments d using ( department_id )
  join   locations     using ( location_id )
  join   countries     using ( country_id )
  join   regions       using ( region_id )
)
  select * from employee_regions e
  where  region_name = employee_region
  and    not exists (
    select null from employee_regions m
    where  e.emp_manager_id = m.employee_id
    and    m.region_name = manager_region
  ) !';

end;
/


select employee_id, :transfer_date, job_id, department_id
from   emp_in_region_without_manager_in_region (
  employee_region => 'Europe', manager_region => 'Americas'
) erwm;








declare 
  transfer_date date := date'2024-08-01';
  new_dept_id   integer := 280;
begin 

  insert into job_history ( employee_id, start_date, job_id, department_id ) 
    select employee_id, transfer_date, job_id, department_id
    from   emp_in_region_without_manager_in_region (
      employee_region => 'Europe', manager_region => 'Americas'
    ) erwm;

  update employees e
  set    e.department_id = new_dept_id
  from   emp_in_region_without_manager_in_region (
    employee_region => 'Europe', manager_region => 'Americas'
  ) erwm
  where  e.employee_id = erwm.employee_id;

end;
/

rollback;





/* Summing 1 .. N vs formula */
declare
  n integer := 123456789;
  total integer := 0;
  start_time pls_integer;
begin
  
  start_time := dbms_utility.get_time();
  for i in 1 .. n loop
    total := total + i;
  end loop;
  dbms_output.put_line ( 'Runtime ' || n || ' additions = ' || ( dbms_utility.get_time() - start_time ) );

  start_time := dbms_utility.get_time();
  total := ( n * ( n + 1 ) ) / 2;
  dbms_output.put_line ( 'Runtime formula = ' || ( dbms_utility.get_time() - start_time ) );

end;
/