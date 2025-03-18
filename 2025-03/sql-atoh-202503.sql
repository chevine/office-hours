@sql-atoh-202503-setup


/* FROM clause defines the data: which rows & columns are available */
select * from employees;









/* non_existent_column not in table => error */
select non_existent_column from employees;
select * from employees where non_existent_column = 'error';










/* Joins extend rows and columns available */
select * from employees
cross  join departments;









/* department_id is on both tables => ambiguity  */
select department_id 
from   employees 
cross  join departments;







/* Use aliases to avoid this */
select empl.department_id 
from   employees empl
cross  join departments dept
where  dept.department_id = 10;

/* Beware! New columns can break any joins with unaliased columns! */






/* WITH clause/CTEs define named subqueries
   Become part of FROM/JOIN */
with emp_dept_ids ( emp_dept_id ) as (
  select department_id 
  from   employees 
), dept_dept_ids ( dept_id ) as ( 
  select department_id 
  from   departments 
)
select emp_dept_id   -- => employees.department_id
from   emp_dept_ids
cross  join dept_dept_ids
where  dept_id = 10; -- => departments.department_id
/* Can help reduce ambiguity and make intent clearer 
   making readability and maintenance easier */






/*************************** 

       Filtering data
   
***************************/

/* WHERE operates on rows from input table(s) */
select * from employees
where  first_name like 'A%';








/* FROM happens before WHERE? */
select * from employees
where  employee_id = 100;











/* Optimizer decides which order to process FROM/JOIN/WHERE */
select * from employees empl
cross  join departments depa
where  empl.employee_id = 100
and    depa.department_id = 10;







/* Remember: the optimizer rearranges where possible 
   Using subqueries to filter has no impact! */
select * from (
  select * from employees
  where  employee_id = 100
) cross  join (
  select * from departments 
  where  department_id = 10
);





/* Using WITH clause also gives same plan */ 
with emp_100 as (
  select * from employees
  where  employee_id = 100
), dept_10 as (
  select * from departments 
  where  department_id = 10
)
select * from emp_100
cross  join dept_10;








/*************************** 

       Returning data 
   
***************************/
/* SELECT - restrict columns returned 
   But also define new columns */
select employee_id, job_id, lower ( first_name ) lowercase_name
from   employees;







/* SELECT works on result set, so this is invalid */
select employee_id, job_id, lower ( first_name ) lowercase_name
from   employees
where  lowercase_name like 'a%';







/* Copy the expression into the where... */
select employee_id, job_id, lower ( first_name ) lowercase_name
from   employees
where  lower ( first_name ) like 'a%';




/* ...or define expressions in a CTE */
with emps_jobs_lowercase_names as (
  select employee_id, job_id, lower ( first_name ) lowercase_name
  from   employees
)
select * from emps_jobs_lowercase_names
where  lowercase_name like 'a%';









/* Queries return tables */
select * from (
  select job_id   -- new table with just job_id
  from   employees
);






/* So these are both invalid */
select * from (
  select job_id 
  from   employees
)
where  first_name like 'A%';

select department_id from (
  select job_id 
  from   employees
);
/* Remember: subquery derives new table; outer queries can only acccess data it returns */









/* Subquery is virtual: the optimizer can rearrange */
with employee_ids as (
  select employee_id, first_name from employees
)
select * from employee_ids
where  employee_id = 100;



/***************************************/




/***************************************/

/* Grouping operations */



/* GROUP BY defines a new table */
select department_id
from   employees 
group  by department_id;
/* Note: GROUP BY <> ORDER BY! */







/* Usually to get aggregate totals (COUNT, SUM, AVG, MAX, etc.) */
select department_id, count(*) emp#, sum ( salary ) salary_total
from   employees 
group  by department_id;






/* Can aggregate without grouping */
select count (*) emp#, sum ( salary ) salary_total
from   employees;
/* Implicit GROUP BY () => grand total */








/* Don't need to select grouping columns */
select count(*) emp#
from   employees 
group  by department_id;


select count(*) emp#, first_name
from   employees 
group  by department_id, first_name;
/* Why would you do this?! */







/* To use an aggregate total in a subquery */
/* e.g. find staff with a salary equal to the max in any department */
select employee_id, department_id, salary, first_name 
from   employees
where  salary in ( 
  select max ( salary ) max_sal
  from   employees 
  group  by department_id
);
/* Note: subquery runs first! */





/* Grouping columns and unaggregated selected columns must match 
   => this is invalid */
select department_id, count(*) emp#
from   employees 
group  by first_name;
/* The group only has first_name 
   To fix: add department_id to GROUP BY  
   or SELECT it in an aggregate function */





/* Expressions on grouped columns */
select first_name, count(*) emp#
from   employees 
group  by lower ( first_name );





/* Can't derive first_name from lower ( first_name ) */
/* But we can do the opposite! */
select count(*) emp#, lower ( first_name ) 
from   employees 
group  by first_name;
/* This may lead to confusion... */







select extract ( year from hire_date ) hire_year, count(*) emp#
from   employees 
group  by hire_date;
/* Take care to ensure grouping and selecting columns match */





/* Want to group by expression and select it? 
   Pre 23ai need to duplicate */
select extract ( year from hire_date ) hire_year, count(*) emp#
from   employees 
group  by extract ( year from hire_date );






/* Until 23ai when you can group by alias */
select extract ( year from hire_date ) hire_year, count(*) emp#
from   employees 
group  by hire_year;










/*************************** 

   Filtering grouped data 
   
***************************/

/* WHERE  - check a row
   HAVING - check a group of rows */

/* These are both wrong */
select department_id, count(*)
from   employees 
where  count(*) = 1         -- count(*) is a group function; not a row function
group  by department_id;

select department_id, count(*)
from   employees 
group  by department_id
having first_name like 'A%'; -- first_name is not in the group





/* Fixing the above */
/* Find the departments with one person */
select department_id, count (*)
from   employees 
group  by department_id
having count (*) = 1;

/* Count with people with A names in each department */
select department_id, count(*)
from   employees 
where  first_name like 'A%'
group  by department_id;






/* You can have unaggreated columns in HAVING; 
   but they must be in the group */
select first_name, department_id, count(*)
from   employees 
group  by first_name, department_id
having first_name like 'A%'; 
/* This is a different query to the above! 
   It returns a group for each (first_name, department_id) not (department_id)







/*************************** 

          Windows
   
***************************/

/* Split by department_id */
select * from employees
window dept_window as ( partition by department_id ); 
/* WINDOW clause added in 21c */



/* Allows reuse of window within query */
select department_id, 
       count (*) over dept_window emp#, 
       sum ( salary ) over dept_window salary_total
from   employees
window dept_window as ( partition by department_id );





/* Window calculated AFTER where */
/* Filter then group != group then filter */
/* Count the people with A names in each dept */
select * from (
  select count(*) over dept_window emp#,
         department_id, first_name
  from   employees 
  where  first_name like 'A%'
  window dept_window as ( partition by department_id )
);

/* Count all the people in each dept; return only those with A names */
select * from (
  select count(*) over dept_window emp#,
         department_id, first_name
  from   employees e
  window dept_window as ( partition by department_id )
)
where  first_name like 'A%';






/* The WITH clause can make this clearer */
with emps_with_dept_counts as (
  select count(*) over dept_window emp#,
         department_id, first_name
  from   employees e
  window dept_window as ( partition by department_id )
)
select * from emps_with_dept_counts 
where  first_name like 'A%';





/*************************** 

      Groups & Windows
   
***************************/


/* What's the order here?! */
select department_id, count(*) emp#, count(*) over () dept#
from   employees
group  by department_id;
/* Check the plan */







/* FROM -> GROUP -> WINDOW */









/* So you can calculate windows over aggregates! */ 
select department_id, 
       count ( count(*) ) over () number_of_depts,
       sum ( count(*) ) over () number_of_emps
from   employees
group  by department_id;




/* Again the WITH clause is clearer */
with emp_dept_groups as (
  select department_id, 
         count(*) emp#
  from   employees
  group  by department_id
)
select department_id,  
       count ( emp# ) over () number_of_depts, 
       sum ( emp# ) over () number_of_emps
from   emp_dept_groups;




/*************************** 

     Deduplicating data 
   
***************************/

/* DISTINCT - return unique values */
select distinct department_id
from   employees;







/* ...is equivalent to */
select department_id
from   employees
group  by department_id;

/* Which do you prefer for returning unique values? 
   DISTINCT or GROUP BY? */










/* DISTINCT applies to the final results 
   i.e. after grouping/windows 
   Both of these return the unique number of employees/dept */
select distinct count(*)
from   employees
group  by department_id;

select distinct count(*) over ( partition by department_id )
from   employees;






/***************************************/




/***************************************/

/* Sorting and limiting */

/*************************** 

         ORDER BY
   
***************************/
/* Ordering applies to final result set */
select * from employees
order  by first_name;
/* If you want sorted data, you must include a final order by! */








/* ORDER BY applies after getting all the data 
   Only sort rows for department_id 80 */
select * from employees
where  department_id = 80
order  by first_name;







/* Sort is "last", so can order by columns in the select */
select lower ( first_name ) lowercase_name, e.*
from   employees e
order  by lowercase_name;
/* This has been possible for decades! */






/* Can order by unselected columns in the table */
select first_name 
from   employees
order  by employee_id;







/* Remember: DISTINCT forms a new table
   => this is invalid */
select distinct first_name
from   employees
order  by employee_id;



/* Think in terms of derived tables */
select * from (
  select distinct first_name
  from   employees
)
order  by employee_id;




/*************************** 

      OFFSET & FETCH 
   
***************************/
/* Get any 5 rows */
select * from employees
fetch  first 5 rows only;

/* Skip any 100 rows; return the rest */
select * from employees
offset 100 rows;








/* What's this going to do? */
select count(*) from employees
fetch  first 5 rows only;





/* Aggreate, then limit => all the rows in employees */



/* This is different: limit, then aggregate */
with five_emps as (
  select * from employees
  fetch  first 5 rows only
)
select count(*) from five_emps;









/* Sort, then limit */
select * from employees
order  by first_name
fetch  first 10 rows only;





/* Sort, move to row N, get next M rows */
select * from employees
order  by first_name
offset 5 rows
fetch  next 10 rows only;














/* Sorting & limiting can have a large impact on performance! */
/* Dataset has ~2 million rows*/
select count(*)
from   employees 
cross  join departments 
cross  join departments 
cross  join departments;




/* This needs to sort full data set */
select * 
from   employees 
cross  join departments 
cross  join departments 
cross  join departments
order  by first_name;







/* Only need to hold 10 rows => much faster! */
select * 
from   employees 
cross  join departments 
cross  join departments 
cross  join departments
order  by first_name
fetch  first 10 rows only;








/* Beware OFFSET - needs to hold N+M rows in sort */
select * 
from   employees 
cross  join departments 
cross  join departments 
cross  join departments
order  by first_name
offset 200000 rows
fetch  first 10 rows only;








/* Order on indexed column => no sort needed 
   => big performance gain */
select * 
from   employees 
cross  join departments 
cross  join departments 
cross  join departments
order  by employee_id -- indexed column
offset 200000 rows
fetch  first 10 rows only;




/* Notice no sort operation in the plan! */
select * 
from   employees 
order  by employee_id;








/*************************** 

       Set operations
       combine tables
   
***************************/
select employee_id from employees
union  all    -- all rows from both tables
select department_id from departments;

select employee_id from employees
intersect all -- common values in both tables; all added in 21c
select department_id from departments;

select employee_id from employees
minus all     -- values only in employees; all added in 21c
select department_id from departments;






/* Each clause in set operation is its own query */
select department_id, count(*) from employees
where  first_name like 'A%'
group  by department_id
union  all
select department_id, 1 from departments
where  department_name < 'N';







/* ...except order by: can only appear at the end */
/* This is invalid */ 
select employee_id from employees
order  by employee_id
union  all
select department_id from departments;




/* This is valid */
select employee_id from employees
union  all
select department_id from departments
order  by employee_id;












/*************************** 

   CONNECT BY hierarchies
   
***************************/

/* Build the company hierarchy */
select employee_id, level, first_name
from   employees e
start  with e.manager_id is null
connect by prior employee_id = e.manager_id;




/* CONNECT BY before WHERE */
select *
from   employees e
where  employee_id = 100
start  with e.manager_id is null
connect by prior employee_id = e.manager_id;











/*************************** 

   Other table operations
   Accept & return tables
   
***************************/


/* PIVOTING 
   Count jobs/department as columns  */
select *
from   ( select job_id, department_id from employees )
pivot ( 
  count(*) for job_id in ( 
    'SA_MAN' as sam, 'SA_REP' as sar, 'IT_PROG' as itp 
  )
)
where  sam + sar + itp > 0; 



/* JOIN then PIVOT */
select *
from   ( select job_id, department_id from employees )
cross  join departments 
pivot ( 
  count(*) for job_id in ( 
    'SA_MAN' as sam, 'SA_REP' as sar, 'IT_PROG' as itp 
  )
);




/* PIVOT then JOIN */
select *
from   ( select job_id, department_id from employees )
pivot ( 
  count(*) for job_id in ( 
    'SA_MAN' as sam, 'SA_REP' as sar, 'IT_PROG' as itp 
  )
)
cross  join departments; 
/* UNPIVOT works the same */






/* As does pattern matching */
select *
from   employees
match_recognize (
  order by first_name
  measures 
    count(*) as row#
  all rows per match
  pattern ( init+ )
  define 
    init as 1 = 1
)
where  first_name like 'A%';










/* MODEL clause only after GROUP BY */
/* Invalid: JOIN before GROUP BY */
select * from employees
model
  dimension by ( employee_id )
  measures ( 0 row# )
  rules ( row#[any] = count(*) over () )
cross  join departments;



/* This is valid */
select * from employees
cross  join departments
model
  dimension by ( employee_id, department_name )
  measures ( 0 row# )
  rules ( row#[any, any] = count(*) over () );


/***************************************/

                /*FIN*/

/***************************************/


