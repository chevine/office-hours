@sql-atl-202607-setup.sql





/* Collecting weather sensor data and store as JSON */
select count (*) over () c, sere.* 
from   sensor_readings sere;








/* Find yesterday's readings for sensor 1 */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp() ) = trunc ( sysdate ) - 1;

/* Find temp readings > 38 for sensor 1 */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    json_value ( 
         sere.sensor_data, '$.metrics[*]?(@.metricType == "temperature").reading' returning number 
       ) > 38;









/* We can index the date query */
create index sere_sensor_time_i 
  on sensor_readings sere (
    sere.sensor_data.sensorId.number(),
    trunc ( sere.sensor_data.recordedAt.timestamp() )
  );

select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp() ) = trunc ( sysdate ) - 1;








/* Now find readings for last month */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp(), 'mm' ) = 
         add_months ( trunc ( sysdate, 'mm' ), -1 );
/* Function-index mismatch => full table scan */







/* Problem: all JSON queries are function-based! */



/* Find yesterday's readings for sensor 1
   Matching same rows but different processing */
select jt.* 
from   sensor_readings sere
cross  join json_table ( 
          sere.sensor_data, '$' 
          columns ( 
            sensorId number,
            recordedAt timestamp,
            nested metrics[*] columns ( -- generate a row for each metric
              metricType, reading number
            ) 
          )
       ) jt
where  sensorId = 1
and    trunc ( recordedAt ) = trunc ( systimestamp ) - 1;






/* Many optional clauses for JSON functions */
select * from sensor_readings sere                 
-- ERROR ON ERROR => raise exception if any problems reading sensorId
where  json_value ( sere.sensor_data, '$.sensorId' returning number error on error ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp() ) = trunc ( sysdate ) - 1;







/* We can insert non-numeric sensorId */
insert into sensor_readings 
set    sensor_data = json { 'sensorId' : 'abc' };

/* Raises error */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number error on error ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp() ) = trunc ( sysdate ) - 1;

/* Doesn't */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp() ) = trunc ( sysdate ) - 1;




/* JSON could have any structure => we may want to add this error checking */



/* e.g. we can add an (empty) array, when it should be an object! */
insert into sensor_readings 
set    sensor_data = json [];

select * from sensor_readings sere
where  sere.sensor_data = json [];

rollback;
/* We need a solid foundation before trying to optimize queries */




/* Drop index for now */
drop index sere_sensor_time_i;



/**********************************




**********************************/



/* Problem: we can insert arrays and empty or junk objects */
insert into sensor_readings 
set    ( sensor_data = json [] ), 
       ( sensor_data = json {} ), 
       ( sensor_data = json_scalar ( 'stuff' ) ), 
       ( sensor_data = json { 'junk' : 'data' } ); 

/* Find JSON without sensorIds */
select * from sensor_readings sere
where  not json_exists ( sere.sensor_data, '$.sensorId' );

/* We want to prevent this! */

rollback;







/* JSON type modifier: ensure only JSON objects can be stored (23.4) */
alter table sensor_readings
  modify ( sensor_data json object ); 

/* Adding an array now errors */
insert into sensor_readings 
set    sensor_data = json [];







/* You can also ensure only arrays 
   This means temps must be an array of numbers with a max size of 30 bytes */
create table temperatures ( 
  temps json array ( number ) limit 30 -- limit added in 23.8
);

/* Can insert JSON number arrays */
insert into temperatures
set    temps = json [1, 2, 3];




/* Provided the arrays are <= 30 BYTES! */
insert into temperatures
set    temps = json [1, 2, 3, 4];

/* Can't insert arrays of other types */
insert into temperatures
set    temps = json ['a', 'b'];







/* Back to the weather data - must be an object, but can have any/no attributes :/ */
insert into sensor_readings 
set    sensor_data = json {};
rollback;

/* Want to ensure it has:
   a numeric sensorId 
   a datetime recordedAt
   an array of metrics
   => We need a JSON schema!
*/








/* JSON VALIDATE => supply a JSON schema to check the structure
   The below ensures it's an object that contains:
   a sensorId number, recordedAt date, and metrics array */
alter table sensor_readings
  modify ( sensor_data json validate '{
    "type" : "object",
    "required" : [ "sensorId", "recordedAt", "metrics" ],
    "properties" : {
      "sensorId"   : { "type": "integer" },
      "recordedAt" : { "type": "string", "format": "date-time" },
      "metrics"    : { "type": "array" }
    }
  }' );





/* Now these all fail */
insert into sensor_readings 
set    sensor_data = json [];
insert into sensor_readings 
set    sensor_data = json {};
insert into sensor_readings 
set    sensor_data = json_scalar ( 'stuff' );
insert into sensor_readings 
set    sensor_data = json { 'junk' : 'data' };  






/* Can add JSON with other attributes: newAttr not in schema */
insert into sensor_readings 
set    sensor_data = json {
  'sensorId' : 1,
  'recordedAt' : '2026-07-28T00:14:44',
  'metrics' : [], 
  'newAttr' : 'newVal'
}; 
rollback;




/* We've got a solid foundation */
/* Back to finding yesterday's readings */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp() ) = trunc ( sysdate ) - 1;

/* Or last month's */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp(), 'mm' ) = 
         add_months ( trunc ( sysdate, 'mm' ), -1 );


/***********************************



***********************************/


/* Support different units: attempt #1 */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.sensor_data.recordedAt.timestamp(), :time_unit  ) =
         case 
           when :time_unit = 'month' then add_months ( trunc ( sysdate, 'mm' ), -1 )
           when :time_unit = 'day' then trunc ( sysdate ) - 1
         end;







/* Be careful! DAY = start of week! */
select sysdate, trunc ( sysdate, 'day' ); 









/* Before we continue... 
   sere.sensor_data.recordedAt.timestamp() is verbose */
/* => add materialized column to make recordedAt easier to query */
  



alter table sensor_readings
  add (
    recorded_at timestamp as 
      ( json_value ( sensor_data, '$.recordedAt' returning timestamp ) ) 
      materialized -- calc on write and store result 23.9 
                   -- default is virtual: calc on read; 11g
  );
/* Back to converting units */









/* Enter DATEDIFF! (23.26.1) */
/* Find how many time boundaries the reading crossed */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    datediff ( day, sere.sensor_data.recordedAt.timestamp(), systimestamp ) = 1;






/* Or weeks */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    datediff ( week, sere.recorded_at, systimestamp ) = 1;

/* Or months */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    datediff ( month, sere.recorded_at, systimestamp ) = 1;

/* Or bind it! */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    datediff ( :time_unit, sere.recorded_at, systimestamp ) = 1;









/* !!BEWARE!! The name is misleading! 
   DATEDIFF counts unit boundaries; not complete units */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
/* Find values for yesterday, not within the past 24 hours */
where  datediff ( day, sere.recorded_at, sysdate ) = 1;




/* Compare to past 24 hours */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  sere.recorded_at >= sysdate - 1;






/* DATEDIFF for times only 1 second apart... */
with times ( start_time, end_time ) as (
  values ( timestamp'2026-12-31 23:59:59', -- 1s before year end
           timestamp'2027-01-01 00:00:00' )
)
-- ...but datediff returns 1 for all these units
select datediff ( year, start_time, end_time ) years, 
       datediff ( quarter, start_time, end_time ) quarters, 
       datediff ( month, start_time, end_time ) months, 
       datediff ( hour, start_time, end_time ) hours, 
       datediff ( minute, start_time, end_time ) minutes,
       datediff ( second, start_time, end_time ) seconds
from   times;



/* What about weeks? */
with times ( start_time, end_time ) as (
  values ( timestamp'2026-12-31 23:59:59',  -- Thursday
           timestamp'2027-01-01 00:00:00' ) -- Friday
)
-- Fourth parameter defines first day of week (1 = Monday, 7 = Sunday, 0 = NLS setting (default))
select datediff ( week, start_time, end_time ) nls_week, 
       datediff ( week, start_time, end_time, 1 ) mon_weeks, 
       datediff ( week, start_time, end_time, 4 ) thu_weeks, 
       datediff ( week, start_time, end_time, 5 ) fri_weeks, -- only this crosses week end/start
       datediff ( week, start_time, end_time, 6 ) sat_weeks
from   times;
/* Remember: boundaries crossed, not durations! */





/* What if we want to work in fiscal units? 
   e.g. Find rows in last fiscal month? 
   Assume FY starts 15 July */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    datediff ( month, 
         -- move dates 14 days back
         trunc ( sere.recorded_at - 14, 'mm' ), 
         trunc ( systimestamp - 14, 'mm' )
       ) = 1;
/* Change TRUNC format to use different units */
/* What else can we do? */












/* DATEADD (23.26.3) for calendar units
   One function to add/subtract any time units (year -> nanosecond) */
select sysdate,
       dateadd ( day, 1, sysdate ) plus_1_day,
       dateadd ( week, 1, sysdate ) plus_1_week, -- 7 days
       dateadd ( month, 1, sysdate ) plus_1_month,
       dateadd ( quarter, 1, sysdate ) plus_1_quarter;




/* Months: move to same day, then work back if invalid */
select dateadd ( month, 1, date'2026-01-31' ),
       dateadd ( month, 1, date'2026-02-28' );





/* Yesterday */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( recorded_at ) = dateadd ( day, -1, trunc ( sysdate ) );

/* Last calendar month */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( recorded_at, 'mm' ) = dateadd ( month, -1, trunc ( sysdate, 'mm' ) );
/* What about fiscal months/years? */






/* Find rows for last fiscal month (FY starts 15 July)
   Offset by 14 days */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( dateadd ( day, -14, recorded_at ), 'mm' ) =
         dateadd ( month, -1, trunc ( dateadd ( day, -14, sysdate ), 'mm' ) );




/* Last fiscal year: offset by day number of year */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
-- 14 July is 195th day of year (in non leap years!)
and    trunc ( dateadd ( day, -195, recorded_at ), 'y' ) =
         dateadd ( year, -1, trunc ( dateadd ( day, -195, sysdate ), 'y' ) );








/* Enter FISCAL ADD functions (23.26.1); 2nd parameter is FY start */
select sysdate,
       fiscal_add_days ( sysdate, -1, date'2026-07-15' ) minus_1_day,
       fiscal_add_weeks ( sysdate, -1, date'2026-07-15' ) minus_1_wk,
       fiscal_add_months ( sysdate, -1, date'2026-07-15' ) minus_1_mnth,
       fiscal_add_quarters ( sysdate, -1, date'2026-07-15' ) minus_1_quarter;








/* There are also CALENDAR & RETAIL (4-4-5) equivalents */
select sysdate,
       calendar_add_days ( sysdate, -1 ) minus_1_day,
       calendar_add_weeks ( sysdate, -1 ) minus_1_wk,
       retail_add_months ( sysdate, -1 ) minus_1_ret_mnth, -- 4/5 weeks
       retail_add_quarters ( sysdate, -1 ) minus_1_ret_quarter; -- 13 weeks exactly




/* DATEADD and CALENDAR_ADD handle month end differently */
select dateadd ( month, 1, date'2026-02-28' ),
       calendar_add_months ( date'2026-02-28', 1 );








/* Standard formatting functions */
select sysdate,
       calendar_day ( sysdate ) cal_day,
       fiscal_week ( sysdate, date'2026-07-15' ) fis_week,
       retail_month ( sysdate ) ret_month,
       retail_quarter ( sysdate ) ret_quarter,
       calendar_year ( sysdate ) cal_year;
       







/* And X of Y functions */
select sysdate,
       calendar_day_of_week ( sysdate ) cal_dow,
       fiscal_day_of_month ( sysdate, date'2026-07-15' ) fis_dom,
       retail_week_of_quarter ( sysdate ) ret_woq,
       fiscal_quarter_of_year ( sysdate, date'2026-07-15' ) fis_qoy;









/* START/END date functions for each unit */
select sysdate,
       calendar_week_start_date ( sysdate ) cal_dow,
       fiscal_month_end_date ( sysdate, date'2026-07-15' ) fis_dom,
       retail_quarter_start_date ( sysdate ) ret_woq,
       fiscal_year_end_date ( sysdate, date'2026-07-15' ) fis_qoy;






/* Combine these 
   Recorded fiscal UNIT start date = 
   Fiscal UNIT start date of current date +/- fiscal UNITs */


 

/* Rows for last fiscal month */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    fiscal_month_start_date ( sere.recorded_at, date'2026-07-15' ) = 
         fiscal_month_start_date ( 
           fiscal_add_months ( sysdate, -1, date'2026-07-15' ), 
           date'2026-07-15' 
         ); 




/* Rows for last fiscal year */
select min ( sere.recorded_at ),
       max ( sere.recorded_at )
from   sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    fiscal_year_start_date ( sere.recorded_at, date'2026-07-15' ) = 
         fiscal_year_start_date ( 
           fiscal_add_years ( sysdate, -1, date'2026-07-15' ), 
           date'2026-07-15' 
         ); 





/* Problem: they're all still function-based indexes */
/* DATEDIFF is resistant to indexing :( */
create index daydiff_i
  on sensor_readings sere (
    datediff ( day, sere.recorded_at, sysdate ) 
  );

/* Hard coded adding one day into index */
create index dayadd_i
  on sensor_readings sere (
    dateadd ( day, 1, sere.recorded_at )
  );

drop index dayadd_i;
/* So how do we optimize these? */




/***********************************



***********************************/




/* Find yesterday's reading */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    trunc ( sere.recorded_at ) = dateadd ( day, -1, trunc ( sysdate ) );
/* Fundamental problem: function on datetime column! 
   => need function-based indexes */






/* Better => create regular index */
create index sere_recorded_i 
  on sensor_readings ( recorded_at );






/* And move all the logic off the table column! */
/* Search for date >= lowerbound and date < upperbound */
/* Yesterday's readings */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    sere.recorded_at >= dateadd ( day, -2, trunc ( sysdate ) )
and    sere.recorded_at < dateadd ( day, -1, trunc ( sysdate ) );


/* Last fiscal week readings */
select * from  sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    sere.recorded_at >= fiscal_week_start_date ( 
           fiscal_add_weeks ( sysdate, -1, date'2026-07-15' ), 
           date'2026-07-15' 
         )
and    sere.recorded_at < fiscal_week_start_date ( 
           fiscal_add_weeks ( sysdate, 0, date'2026-07-15' ), 
           date'2026-07-15' 
         ); 




/* But what about the JSON queries? */
select jt.* 
from   sensor_readings sere
cross  join json_table ( 
          sere.sensor_data, '$' 
          columns ( 
            sensorId number,
            nested metrics[*] columns ( metricType, reading number ) 
          )
       ) jt
where  sensorId = 1
and    sere.recorded_at >= trunc ( dateadd ( day, -1, sysdate ) )
and    sere.recorded_at <  trunc ( dateadd ( day, 0, sysdate ) );
/* Recorded at extracted => optimizer can use index */




/* But how do we optimize queries of the JSON array? */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    json_value ( sere.sensor_data, 
         '$.metrics[*]?(@.metricType == "temperature").reading' returning number 
       ) > 38;

select jt.* 
from   sensor_readings sere
cross  join json_table ( 
          sere.sensor_data, '$' 
          columns ( 
            sensorId number,
            nested metrics[*] columns ( metricType, reading number ) 
          )
       ) jt
where  sensorId = 1
and    metricType = 'temperature'
and    reading > 38;






/* Index the contents of JSON arrays with a multivalue index */
create multivalue index sere_metric_reading_mvi
  on sensor_readings sere (
    -- Use JSON_table for composite MVI
    json_table ( 
      sere.sensor_data, '$.metrics[*]' 
      -- these clauses are required by the index
      error on error null on empty null on mismatch
      columns ( 
        metricType varchar2(30), reading number  
      )
    )
  );





/* But the optimizer doesn't use it!? */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    json_value ( sere.sensor_data, 
         '$.metrics[*]?(@.metricType == "temperature").reading' returning number 
       ) > 38;

select jt.* 
from   sensor_readings sere
cross  join json_table ( 
          sere.sensor_data, '$' 
          columns ( 
            sensorId number,
            nested metrics[*] columns ( metricType, reading number ) 
          )
       ) jt
where  sensorId = 1
and    metricType = 'temperature'
and    reading > 38;





/* MVI work with JSON_EXISTS */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    json_exists ( sere.sensor_data, 
         '$.metrics[*]?(@.metricType == "temperature" && @.reading > 38 )' 
       );
/* So how do we index other queries? */






/* Create full text index of the JSON */
create search index weather_sensor_json_i 
  on sensor_readings sere ( sere.sensor_data )
  for json;







/* Now any JSON query can use the search index */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    json_value ( sere.sensor_data, 
         '$.metrics[*]?(@.metricType == "temperature").reading' returning number 
       ) > 38;






/* But the overall index size is large! */
select sum ( bytes ) / 1024 / 1024 size_in_mb
from   user_segments 
where  segment_name like '%$WEATHER_SENSOR_JSON_I$%';


/* Relative to size of JSON */
select sum ( lengthb ( sensor_data ) ) / 1024 / 1024
from   sensor_readings;





/* We already have materialized column for recordedAt
    => is full text indexing of this necessary? */






/* 23.26.1 ALTER INDEX to change path subsetting */
alter index weather_sensor_json_i 
  rebuild 
  -- 23.6 Remove recordedAt from index 
  parameters (
    'REPLACE 
     SEARCH_ON 
     TEXT EXCLUDE ( $.recordedAt )'
  );
  -- alt: state what to include in the index:
  -- SEARCH_ON TEXT INCLUDE ( $.sensorId, $.metrics.metricType, $.metrics.reading )' )




/* The index is notably smaller now */
select sum ( bytes ) / 1024 / 1024 size_in_mb
from   user_segments 
where  segment_name like '%$WEATHER_SENSOR_JSON_I$%';






/* The optimizer can combine the JSON search and regular B-Tree */
select jt.* from sensor_readings sere
cross  join json_table (
  sere.sensor_data, '$.metrics[*]'
  columns (
    metricType, reading number
  )
) jt
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    recorded_at >= trunc ( systimestamp ) - 1
and    recorded_at < trunc ( systimestamp );




/* These queries can now use the domain index */
select * from sensor_readings sere
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    json_value ( sere.sensor_data, 
         '$.metrics[*]?(@.metricType == "temperature").reading' returning number 
       ) > 38;

select jt.* from sensor_readings sere
cross  join json_table (
  sere.sensor_data, '$.metrics[*]'
  columns (
    metricType, reading number
  )
) jt
where  json_value ( sere.sensor_data, '$.sensorId' returning number ) = 1
and    metricType = 'temperature'
and    reading >= 38; 






/***********************************



***********************************/
