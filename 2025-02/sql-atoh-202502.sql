@sql-atoh-202502-setup 


/* Demo requires 23.7 */
select banner_full from v$version;

/* Here's the source data */
select * from time_data;







/* Use trunc to round down to a unit */
select trunc ( datetime, 'yy' ) yr,  -- year start
       trunc ( datetime, 'mm' ) mth, -- month start
       trunc ( datetime ) dy,        -- day start
       trunc ( datetime, 'hh' ) hr,  -- hour start
       trunc ( datetime, 'mi' ) min  -- minute start
from   time_data;






/* Group by hour */
select count(*), trunc ( datetime, 'hh' ) hr 
from   time_data
group  by hr
order  by hr;









/* Group into N unit intervals
   1. Find units between datetime and origin
   2. Divide by N
   3. Round down
   4. Multiply by N 
   5. Add result to origin */

/* Find 5-minute interval from midnight */
/* 1. Convert day diff to units */
select 
  ( to_date ( '00:12:30', 'HH24:MI:SS' ) - date'2025-02-01' ) day_diff,
  ( to_date ( '00:12:30', 'HH24:MI:SS' ) - date'2025-02-01' ) * 1440 minute_diff;





/* 2, 3, & 4 Convert to bucket number */
select 
  ( to_date ( '00:12:30', 'HH24:MI:SS' ) - date'2025-02-01' ) * 1440 / 5 step_2,
  floor ( ( to_date ( '00:12:30', 'HH24:MI:SS' ) - date'2025-02-01' ) * 1440 / 5 ) step_3,
  floor ( ( to_date ( '00:12:30', 'HH24:MI:SS' ) - date'2025-02-01' ) * 1440 / 5 ) * 5 step_4;






/* Find units between times - beware numeric imprecision! */
select 
  ( to_date ( '00:00:20', 'HH24:MI:SS' ) - date'2025-02-01' ) * 86400 twenty_seconds,
  ( to_date ( '01:15:00', 'HH24:MI:SS' ) - date'2025-02-01' ) * 1440  seventy_five_minutes;
/* Round before floor to avoid */














/* Find which bucket each time falls in 
   1440 = minutes in a day 
   Note rounding to ensure bucket# is correct */
with rws as (
  select date'2025-02-01' origin, 
         datetime, 
         1440 units_in_day, -- minutes
         5 stride 
  from   time_data
), buckets as (
  select round ( ( datetime - origin ) * units_in_day, 9 ) / stride bucket_fraction,
         floor ( ( datetime - origin ) * units_in_day / stride ) wrong_bucket#,
         floor ( round ( ( datetime - origin ) * units_in_day, 9 ) / stride ) bucket#,
         datetime
  from   rws
)
select * from buckets
order  by datetime;




/* Multiply bucket# by stride 
   Add to origin to get start */
with rws as (
  select date'2025-02-01' origin, 
         datetime, 
         1440 units_in_day, -- minutes
         5 stride 
  from   time_data
), buckets as (
  select floor ( round ( ( datetime - origin ) * units_in_day, 9 ) / stride ) bucket#,
         r.*
  from   rws r
), intervals as (
  select origin + ( bucket# * stride / units_in_day ) start_datetime,
         origin + ( ( bucket# + 1 ) * stride / units_in_day ) end_datetime
  from   buckets
)
  select count(*), start_datetime, end_datetime
  from   intervals
  group  by start_datetime, end_datetime
  order  by start_datetime;







/* Origin can be any datetime that's a valid bucket start/end */
with rws as (
  select date'9999-12-31' origin, 
         datetime, 
         1440 units_in_day, 
         5 stride 
  from   time_data
), buckets as (
  select floor ( round ( ( datetime - origin ) * units_in_day, 9 ) / stride ) bucket#,
         r.*
  from   rws r
), intervals as (
  select origin + ( bucket# * stride / units_in_day ) start_datetime,
         origin + ( ( bucket# + 1 ) * stride / units_in_day ) end_datetime
  from   buckets
)
  select count(*), start_datetime, end_datetime
  from   intervals
  group  by start_datetime, end_datetime
  order  by start_datetime;





/* Generic solution for N days/hours/minutes/seconds */
with rws as (
  select to_date ( :start_date, 'DD-MON-YYYY HH24:MI:SS' ) origin,
         datetime,
         :units_in_day units_in_day,
         :time_interval stride 
  from   time_data
), buckets as (
  select floor ( round ( ( datetime - origin ) * units_in_day, 9 ) / stride ) bucket#,
         rws.*
  from   rws
), intervals as (
  select origin + ( bucket# * stride / units_in_day ) start_datetime,
         origin + ( ( bucket# + 1 ) * stride / units_in_day ) end_datetime
  from   buckets
)
  select count(*), start_datetime
  from   intervals
  group  by start_datetime
  order  by start_datetime;



/*********************************/




/*********************************/

/* Enter TIME_BUCKET in 23.7! */
select time_bucket ( 
  timestamp'2025-02-01 01:23:45', -- Datetime to bucket
  interval '5' minute,            -- Stride/interval
  timestamp'2025-02-01 00:00:00'  -- Origin date
) five_minute_interval_start,
time_bucket ( 
  timestamp'2025-02-01 01:23:45',
  interval '5' minute, 
  timestamp'2025-02-01 00:00:00',
  end                             -- Interval end
) five_minute_interval_end;







/* Use time_bucket to group into 5 minute intervals */
select count(*), 
       time_bucket ( 
         datetime, interval '5' minute, date'2025-02-01'
       ) start_date,
       time_bucket ( 
         datetime, interval '5' minute, date'2025-02-01', end
       ) end_date
from   time_data
group  by start_date, end_date
order  by start_date;




/* Also works for months/years 
   Place in 2 month intervals */
select count(*), 
       time_bucket ( 
         datetime, interval '2' month, date'2025-01-01'
       ) start_date
from   time_data
group  by start_date
order  by start_date;







/* Can also use epochs (seconds since 1 Jan 1970) as input and origin */
select time_bucket ( 
         1234567890, -- Feb 13 23:31:30 2009
         interval '1' day,
         0           -- Jan 01 00:00:00 1970
       ) start_epoch_day;








/* Bind stride interval? */
select time_bucket (
  sysdate, 
  interval :duration_in_minutes minute,
  trunc ( sysdate )
);








/* Bind stride interval */
select time_bucket (
  sysdate, 
  numtodsinterval ( :n, :unit ), -- choose day -> sec
  -- numtoyminterval ( :n, :unit ), -- choose year -> month
  trunc ( sysdate, 'mm' )
);







/* Use ISO time intervals for the stride 
   P5M => 5 months
   PT5M => 5 minutes
   P5MT5M => 5 months, 5 minutes; minutes ignored!
   */
select count(*), 
       time_bucket ( 
         datetime, :stride, date'2024-01-01'
       ) start_date
from   time_data
group  by start_date
order  by start_date;







/* Use lowest date in table as origin */
with origin_data as (
  select datetime, min ( datetime ) over () origin_date
  from   time_data
)
select count(*), 
       time_bucket ( 
         datetime, interval '5' minute, origin_date
       ) grp
from   origin_data
group  by grp
order  by grp;







/* Calculate intervals on write with materialized columns in 23.7 */
alter table time_data 
  add ( 
    five_minute_materialized as ( 
      time_bucket ( 
        datetime, interval '5' minute, date'2025-01-01', start 
      )
    ) materialized, -- calc on write; 23.7 addition
    five_minute_virtual as ( 
      time_bucket ( 
        datetime, interval '5' minute, date'2025-02-01', start
      )
    ) virtual -- calc on read; since 11g
  );





select count(*), 
       five_minute_materialized start_date
from   time_data
group  by start_date
order  by start_date;






/* How does materializing benefit? */
declare 
  iterations pls_integer := 2500;
  rows       integer;
  start_time pls_integer;
begin
  start_time := dbms_utility.get_time();
  for i in 1 .. iterations loop
    select count(*) into rows from time_data
    where  five_minute_materialized = date'2025-02-02';
  end loop;
  dbms_output.put_line ( 'Stored      = ' || to_char ( dbms_utility.get_time() - start_time, '9990' ) );

  start_time := dbms_utility.get_time();
  for i in 1 .. iterations loop
    select count(*) into rows from time_data
    where  five_minute_virtual = date'2025-02-02';
  end loop;
  dbms_output.put_line ( 'Virtual     = ' || to_char ( dbms_utility.get_time() - start_time, '9990' ) );

  start_time := dbms_utility.get_time();
  for i in 1 .. iterations loop
    select count(*) into rows from time_data
    where  time_bucket ( 
      datetime, interval '5' minute, date'2025-02-01'
    ) = date'2025-02-02';
  end loop;
  dbms_output.put_line ( 'time_bucket = ' || to_char ( dbms_utility.get_time() - start_time, '9990' ) );

end;
/



/*********************************/




/*********************************/

/* Show all intervals; even if there's no events 
   Step 1: Generate the intervals */
with intervals as (
  select date'2025-02-01'
           + ( ( level - 1 ) * :duration_in_minutes / 1440 ) start_date,
         date'2025-02-01'
           + ( level * :duration_in_minutes / 1440 ) end_date 
  connect by level <= :number_of_buckets
)
  select *
  from   intervals i;
  
  



/* Show all intervals; even if there's no events 
   Step 2: Outer join events to intervals */
with intervals as (
  select date'2025-02-01'
           + ( ( level - 1 ) * :duration_in_minutes / 1440 ) start_date,
         date'2025-02-01'
           + ( level * :duration_in_minutes / 1440 ) end_date 
  connect by level <= :number_of_buckets
)
  select count ( datetime ), start_date, end_date 
  from   intervals i
  left  join time_data t
  on     start_date <= datetime
  and    datetime < end_date
  group  by start_date, end_date
  order  by start_date;





/* Group into 5 minute intervals 
   Start date of each group equals the first date in it */
select *
from   time_data
  match_recognize (
    order by datetime
    measures
      count(*) as event_count, 
      init.datetime as start_date,
      init.datetime + ( :duration_in_minutes / 1440 ) as end_date
    -- all rows per match
    pattern ( init stride* )
    define
      stride as datetime < init.datetime + ( :duration_in_minutes / 1440 )
  );






/* Combine rows within five minutes of previous into one group 
   => split rows into groups with >= 5 minute gap between datetimes */
select *
from   time_data
  match_recognize (
    order by datetime
    measures
      count(*) as event_count,
      init.datetime as start_date,
      last ( datetime ) + :duration_in_minutes / 1440 as end_date
    -- all rows per match
    pattern ( init stride* )
    define
      stride as datetime < prev ( datetime ) + ( :duration_in_minutes / 1440 )
  );

/*********************************


              FIN


*********************************/
