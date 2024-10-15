@sql-atoh-202410-setup

/************************

     Calculate Ages

************************/

/* How old are these people? */
select * from people;






/* Before we start...
   These SQL statements use SYSDATE
   How can we test leap days?! */






/* Enter FIXED_DATE parameter! */
select sysdate;
alter system set fixed_date = '28-FEB-2023'; 
select sysdate, systimestamp;
alter system set fixed_date = none; -- reset back to system time
/* Back to the program */






/*
Basic age formula => floor ( complete months / 12 )
*/




/* MONTHS_BETWEEN calculates month part using fixed 31 day month */
select 
  months_between ( date'2024-10-14', date'2023-10-15' ) prev_day,
  months_between ( date'2024-10-15', date'2023-10-15' ) same_day,
  months_between ( date'2024-10-16', date'2023-10-15' ) next_day;






/* Same day vs last of month */
select 
  months_between ( date'2024-10-29', date'2024-09-30' ) prev_date,
  months_between ( date'2024-10-30', date'2024-09-30' ) same_day,
  months_between ( date'2024-10-31', date'2024-09-30' ) next_day;




/* If both dates are the last day in the month
   => exact number of months between them
   What happens at the end of Feb?
 */




/* End of Feb differences */
select 
  months_between ( date'2024-02-27', date'2023-02-28' ) prev_day,
  months_between ( date'2024-02-28', date'2023-02-28' ) same_day,
  months_between ( date'2024-02-29', date'2023-02-28' ) "SAME_DAY?",
  months_between ( date'2024-03-01', date'2023-02-28' ) next_day;






select 
  months_between ( date'2025-02-27', date'2024-02-29' ) prev_day,
  months_between ( date'2025-02-28', date'2024-02-29' ) "SAME_DAY?",
  months_between ( date'2025-03-01', date'2024-02-29' ) next_day;

/* => leaplings one year older at the end of Feb */





/* 
Works if leaplings one year older on 28th Feb in non-leap years
What if they're a year older on 1st Mar? 

Subtract dates as YYYYMMDD numbers! => whole years 10,000 apart
*/





select 
  20230228 - 20000229 end_feb , -- 28th Feb 2023 - 29th Feb 2000
  20230301 - 20000229 start_mar --  1st Mar 2023 - 29th Feb 2000
/





/* Dates to YYYYMMDD numbers */
create or replace function yyyymmdd ( 
  input_date date 
) return integer as
begin
  return to_number ( 
    to_char ( input_date, 'yyyymmdd' ) 
  );
end;
/





/* Year differences are multiples of 10,000 */
select 
  yyyymmdd ( date'2024-10-14' ) - yyyymmdd ( date'2023-10-15' ) prev_day,
  yyyymmdd ( date'2024-10-15' ) - yyyymmdd ( date'2023-10-15' ) same_day,
  yyyymmdd ( date'2024-10-16' ) - yyyymmdd ( date'2023-10-15' ) next_day;






/* Same day vs last of month */
select 
  yyyymmdd ( date'2024-10-29' ) - yyyymmdd ( date'2024-09-30' ) prev_date,
  yyyymmdd ( date'2024-10-30' ) - yyyymmdd ( date'2024-09-30' ) same_day,
  yyyymmdd ( date'2024-10-31' ) - yyyymmdd ( date'2024-09-30' ) next_day;






/* End of Feb differences */
select 
  yyyymmdd ( date'2024-02-27' ) - yyyymmdd ( date'2023-02-28' ) prev_day,
  yyyymmdd ( date'2024-02-28' ) - yyyymmdd ( date'2023-02-28' ) same_day,
  yyyymmdd ( date'2024-02-29' ) - yyyymmdd ( date'2023-02-28' ) "SAME_DAY?",
  yyyymmdd ( date'2024-03-01' ) - yyyymmdd ( date'2023-02-28' ) next_day;


select 
  yyyymmdd ( date'2025-02-27' ) - yyyymmdd ( date'2024-02-29' ) prev_day,
  yyyymmdd ( date'2025-02-28' ) - yyyymmdd ( date'2024-02-29' ) "SAME_DAY?",
  yyyymmdd ( date'2025-03-01' ) - yyyymmdd ( date'2024-02-29' ) next_day;








/* 
  Two ways to calculate age round down either:
  - ( whole months / 12 )
  - yyyymmdd diff / 10,000
*/

select sysdate, birth_date, 
       floor ( 
         months_between ( sysdate, birth_date ) / 12 
       ) age_mths_between, 
       floor ( 
        ( 
          yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
        ) / 10000 
       ) age_numeric
from   people;


/* What about those leaplings? */







alter system set fixed_date = '28-FEB-2023'; 

select sysdate, birth_date, 
       floor ( 
         months_between ( sysdate, birth_date ) / 12 
       ) age_mths_between, 
       floor ( 
        ( 
          yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
        ) / 10000 
       ) age_numeric,
       person_id
from   people
where  person_id in ( 2, 3, 4 );


alter system set fixed_date = '01-MAR-2023';
alter system set fixed_date = '29-FEB-2024'; 



/* Find people at least N years old */
select sysdate, birth_date, 
       floor ( 
         months_between ( sysdate, birth_date ) / 12 
       ) age_mths_between, 
       floor ( ( 
          yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
        ) / 10000 
       ) age_numeric,
       person_id
from   people
/* Leaplings celebrate 1st March; use months_between for 28th Feb */
where  floor ( ( 
          yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
        ) / 10000 
       ) >= :min_age;

alter system set fixed_date = '28-FEB-2023'; 





/* Flag to check they're >= N years old */
select sysdate, birth_date, 
       case  
         when floor ( ( -- or use months_between
            yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
          ) / 10000 
         ) >= :min_age then true
         else false 
       end older_than_min_age
from   people;





/* Reset SYSDATE */
alter system set fixed_date = none;
select sysdate;





/************************

     Find birthdays 

************************/

/* Find birthdays today 
   Match day and month of birth date to current date
   (ignore leaplings for now)
*/
select * from people
where  to_char ( birth_date, 'DD-MON' ) = to_char ( sysdate, 'DD-MON' ) ;






/* But what about birthdays coming in the next month? */




/* Find birthdays next 7 days 
   Generate 7 days; check if DD-MON is in that
*/
select to_char ( sysdate - 1 + level, 'DD-MON' ) dt
-- 7 days including today
connect by level <= 7;




/* Find people with birth day and month matching 7 days including today 
   => today + next 6 days */
select * from people
where  to_char ( birth_date, 'DD-MON' ) in ( 
  select to_char ( sysdate - 1 + level, 'DD-MON' ) 
  connect by level <= 7
);




/* Find birthdays next calendar month */
select * from people
where  to_char ( birth_date, 'DD-MON' ) in ( 
  select to_char ( sysdate - 1 + level, 'DD-MON' ) 
  -- Get the number of days between today and one month later
  connect by level <= add_months ( sysdate, 1 ) - sysdate 
);




/* What does adding a month mean? */
select 
  add_months ( date'2024-01-01', 1 ) month_is_31_days,
  add_months ( date'2024-01-31', 1 ) month_is_29_days,
  add_months ( date'2024-03-31', 1 ) month_is_30_days;




select 
  date'2024-01-01' + 31 month_is_31_days,
  date'2024-01-31' + 29 month_is_29_days,
  date'2024-03-31' + 30 month_is_30_days;









/* Find birthdays next calendar month */
select * from people
where  to_char ( birth_date, 'DD-MON' ) in ( 
  select to_char ( sysdate - 1 + level, 'DD-MON' ) 
  -- Get the number of days between today and one month later
  connect by level <= add_months ( sysdate, 1 ) - sysdate 
);



/* What about leap babies?! */
alter system set fixed_date = '01-FEB-2023';
alter system set fixed_date = '02-FEB-2023';


/* In non-leap years 29th Feb not returned => leap babies ignored :( 
   Need special handling when it's NOT a leap year
 */



/* Check if it's a leap year */
create or replace function is_leap_year 
return boolean as 
  current_year integer;
begin
  current_year := extract ( year from sysdate );
  /* Leap years are divisible by 400 and 4 but not 100 */
  return case 
    when mod ( current_year, 400 ) = 0 then true
    when mod ( current_year, 100 ) = 0 then false
    when mod ( current_year, 4 ) = 0 then true
    else false
  end;
end;
/





/* Find birthdays today - including leaplings */

alter system set fixed_date = '01-MAR-2023';

/* Find birthdays today with leap babies celebrating 1st March */
select * from people
where  to_char ( sysdate, 'DD-MON' ) = to_char ( birth_date, 'DD-MON' )
or     ( 
  -- Leapling and it's NOT a leap year
  to_char ( birth_date, 'DD-MON' ) = '29-FEB' and
  not is_leap_year and 
  to_char ( sysdate, 'DD-MON' ) = '01-MAR' -- or 28 Feb 
  -- Beware NLS language settings!
);


alter session set nls_date_language = French;


select 
  to_char ( sysdate, 'DD-MON' ),
  /* NLS safe approach */
  to_char ( sysdate, 'DD-MON', 'nls_date_language = English' );

alter session set nls_date_language = English;




/* Next N days with leaplings */
alter system set fixed_date = '22-FEB-2023';

select p.*, sysdate + :N - 1 last_date, 
       to_char ( sysdate + :N, 'mmdd' )
from   people p
where  to_char ( birth_date, 'DD-MON' ) in ( 
  select to_char ( sysdate - 1 + level, 'DD-MON' ) 
  connect by level <= :N 
  union  all -- include 29-FEB when needed
  select '29-FEB' from dual 
  where  not is_leap_year
  and    '0229' between
    to_char ( sysdate, 'mmdd' ) and 
    -- Leaplings celebrate on 28th Feb => :N
    -- Leaplings celebrate on  1st Mar => :N - 1
    to_char ( sysdate + :N, 'mmdd' ) 
);

alter system set fixed_date = '23-FEB-2023';
alter system set fixed_date = '23-FEB-2024';



/* Why can't we just use BETWEEN anyway? */




/* Year end! */
alter system set fixed_date = '31-DEC-2024'; 




select 
  to_char ( date'2024-01-01', 'mmdd' ) jan_birthday,
  to_char ( sysdate, 'mmdd' ) current_date,
  to_char ( sysdate + 6, 'mmdd' ) next_six,
  to_char ( date'2024-01-01', 'mmdd') 
    between to_char ( sysdate, 'mmdd' ) 
    and     to_char ( sysdate + 6, 'mmdd' ) is_between;


alter system set fixed_date = none;





/************************

   Make it data driven!

************************/

/* Column on table? */
alter table people 
  add age int;

/* Set the ages (use appropriate leapling formula) */
update people 
set    age = floor ( 
         ( 
           yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
         ) / 10000 
       );

select age, birth_date from people;




/* Challenges: 
   - Need daily job to update it! 
   - Ages incorrect until job completes

*/




/* Use view? */
create or replace view people_ages as 
  select person_id, 
         floor ( ( 
             yyyymmdd ( sysdate ) - yyyymmdd ( birth_date )
           ) / 10000 
         ) age,
         p.birth_date
  from   people p;


select * from people_ages;


alter system set fixed_date = '31-DEC-2000'; 
alter system set fixed_date = none;

/* Make it work for any date? */




/* Use a macro! */
drop view people_ages;
create or replace function people_ages ( 
  calendar_date date 
) return clob sql_macro as 
begin
  return '
  select person_id, 
         floor ( ( 
             yyyymmdd ( calendar_date ) - yyyymmdd ( birth_date )
           ) / 10000 
         ) age,
         p.birth_date
  from   people p';

end;
/

select * from people_ages ( sysdate );
select * from people_ages ( date'2000-12-31' );





/* More challenges
   - Only one celebration date for leaplings
   - Only works for age on given date - what about range?
*/




-- Make this a macro? 
select p.* 
from   people p
where  to_char ( birth_date, 'DD-MON' ) in ( 
  select to_char ( sysdate - 1 + level, 'DD-MON' ) 
  connect by level <= :N 
  union  all -- include 29-FEB when needed
  select '29-FEB' from dual 
  where  not is_leap_year
  and    '0229' between
    to_char ( sysdate, 'mmdd' ) and 
    to_char ( sysdate + :N, 'mmdd' ) 
);






/* Minimize code. Maximize data.
   => store age on a specific day
   => need rows 
   => create a table!
 */


/* Reset */ 
alter table people 
  drop column age;












/* 
   Store the cross join of birthdays and calendar dates! 
   For each calendar date: 
   - Store the age for the corresponding birthday 
   - If the calendar date is a birthday for the birth date
   - (If needed) flag for leaplings celebration date
*/





create table if not exists ages ( 
  calendar_date      date,
  leapling_celebrate char(3 char),
  birth_date         date,
  age                integer,
  is_birthday        boolean, 
  primary key ( calendar_date, leapling_celebrate, birth_date ),
  check ( calendar_date = trunc ( calendar_date ) ),
  check ( birth_date = trunc ( birth_date ) ),
  check ( leapling_celebrate in ( 'FEB', 'MAR' ) ),
  check ( age >= 0 ) 
) organization index; 



/* 
   You need HOW MUCH data?!
   Ages up to 130 years           => ~47,000 dates
   Cross join with calendar dates => ~2 billion rows
   Double for MAR/FEB celebrate   => ~4 billion rows!
*/







/* We can simplify: only need
   calendar dates >= birth dates
   Only store calendar dates needed to calc age or find birthdays
   => rolling window of X calendar years?
*/





/* Here's one I populated earlier storing rolling 3 years */
select count(*), 
       min ( calendar_date ), 
       max ( calendar_date ) 
from   ages;


select * from ages
fetch  first 10 rows only;



/* Find todays birthdays
   Get today 
   Join to people on birth date 
*/



alter system set fixed_date = none;

/* Find everyone's age today and if it's their birthday */
select person_id, calendar_date, birth_date, age, is_birthday
from   people
join   ages 
using ( birth_date ) 
where  calendar_date = trunc ( sysdate )
and    leapling_celebrate = :leap;





/* Find birthdays in next month and their age */
select person_id, calendar_date, birth_date, age, sysdate 
from   people
join   ages 
using ( birth_date ) 
where  calendar_date >= trunc ( sysdate )
and    calendar_date <  add_months ( trunc ( sysdate ), 1 ) 
and    is_birthday is true
and    leapling_celebrate = :leap
order  by calendar_date;


alter system set fixed_date = '01-FEB-2023';
alter system set fixed_date = '01-FEB-2024';
alter system set fixed_date = none;



/* Check if people are N years or older today */
select person_id, calendar_date, birth_date, age, sysdate 
from   people
join   ages 
using ( birth_date ) 
where  calendar_date = trunc ( sysdate )
and    age >= :age
and    leapling_celebrate = :leap;




/* Check leapling info */
select * 
from   people
join   ages 
using ( birth_date ) 
where  person_id = 3 -- leapling
and    calendar_date in ( 
  date'2023-02-28', date'2023-03-01',
  date'2024-02-28', date'2024-02-29', date'2024-03-01'
)
order  by person_id, calendar_date;




/**********************/




/**********************/