@sql-atoh-202504-setup.sql



/* Check sample data */
select * from detailed_oos_events;






/* Run these to capture plan stats */
alter session set statistics_level = all;
set serveroutput off;



/* Problem query */
with oos_events (
  master_id, marketplace_id, previous_date, 
  event_date, iteration, days_from_previous_event
) as (   -- Base query
  select master_id, marketplace_id,
         null as previous_date, min(oos_date) as event_date,
         0 as iteration, 0 as days_from_previous_event
  from   detailed_oos_events doe
  group by master_id,marketplace_id
  union all -- Recursive query: Find the next OOS event occurring 7+ days after the last event
  select e.master_id, e.marketplace_id,
         e.event_date as previous_date, d.oos_date as event_date,
         e.iteration + 1 as iteration, d.oos_date - e.event_date as days_from_previous_event
  from   oos_events e
  join   detailed_oos_events d
  on     d.oos_date >= e.event_date + 7
  and    d.master_id = e.master_id
  and    d.marketplace_id = e.marketplace_id
  left   join detailed_oos_events d2
  on     d2.oos_date >= e.event_date + 7
  and    d2.oos_date < d.oos_date
  and    d2.master_id = e.master_id
  and    d2.marketplace_id = e.marketplace_id
  where  d2.oos_date is null /* Ensures we select the earliest valid OOS event */
)
select * from oos_events;

select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );




/* Make it into a view for reuse */
create or replace view oos_events_original as 
with oos_events (
  master_id, marketplace_id, previous_date, 
  event_date, iteration, days_from_previous_event
) as (   -- Base query
  select master_id,
         marketplace_id,
         null as previous_date,
         min(oos_date) as event_date,
         0 as iteration,
         0 as days_from_previous_event
  from   detailed_oos_events doe
  group by master_id,marketplace_id
  union all -- Recursive query: Find the next OOS event occurring at least 7 days after the last event
  select e.master_id,
         e.marketplace_id,
         e.event_date as previous_date,
         d.oos_date as event_date,
         e.iteration + 1 as iteration,
         d.oos_date - e.event_date as days_from_previous_event
  from   oos_events e
  join   detailed_oos_events d
  on     d.oos_date >= e.event_date + 7
  and    d.master_id = e.master_id
  and    d.marketplace_id = e.marketplace_id
  left   join detailed_oos_events d2
  on     d2.oos_date >= e.event_date + 7
  and    d2.oos_date < d.oos_date
  and    d2.master_id = e.master_id
  and    d2.marketplace_id = e.marketplace_id
  where  d2.oos_date is null /* Ensures we select the earliest valid OOS event */
)
select * from oos_events;

select * from oos_events_original;




/* Optimizing recursive WITH
   Number rows 1 .. N in order
   Walk through from 1 .. N
   Add logic to calculate groups in select
 */




/* Step one: number the rows. 
   This is the basis for walking through the data */
with numbered_oos_events as (
  select row_number () over ( order by oos_date ) rn, d.*
  from   detailed_oos_events d
)
select * from numbered_oos_events;




/* Build recursive WITH 
   Start at 1, then iterate through rn = prev rn + 1 */
with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events as (
  select * from numbered_oos_events
  where  rn = 1
)
select * from oos_events;






-- Now build in the recursive query 
with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events as (
  select * from numbered_oos_events
  where  rn = 1
  union  all 
  select * from oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn = nuov.rn + 1
)
select * from oos_events;





/* ORA-32039: missing column alias list in recursive WITH clause element 
   Must list columns in spec
   WITH tree ( c1, c2, ... ) AS ( ... )
 */



/* Add column list in recursive CTE */
with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn ) as (
  select * from numbered_oos_events
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn  
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn = nuov.rn + 1
)
select * from oos_events;


/* Only 1 row?!
   Joining the wrong way around :( 
   Need to swap + 1 on this join:
  ooev.rn = nuov.rn + 1
*/



with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn ) as (
  select * from numbered_oos_events
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn  
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn -- swap the addition
  and    ooev.master_id = nuov.master_id  -- add in the other join conditions
  and    ooev.marketplace_id = nuov.marketplace_id
)
select rn, master_id, marketplace_id, oos_date from oos_events;



/* Quick performance check */
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );
/* Not great but looking better */




/* Add group column */
with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, grp ) as (
  select nuov.*,   
         0 grp -- Add group
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         ooev.grp -- Everything in one group for now - this is where magic happens!
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
)
select rn, grp, master_id, marketplace_id, oos_date from oos_events;





/* Need to increment group when current date >= 7 days after first 
   => need a CASE expression */
with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, grp ) as (
  select nuov.*, 0 grp -- Add group
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         -- Check if we have a new group 
         case 
           when nuov.oos_date >= ooev.oos_date + 7 then ooev.grp + 1
           else ooev.grp
         end as grp
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
)
select rn, grp, master_id, marketplace_id, oos_date from oos_events;



/* That didn't work... 
   Always comparing to prev/next date
   Need to add first date in each group */




with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, grp, oos_start_date ) as (
  select nuov.*, 
         0 grp,
         nuov.oos_date oos_start_date
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         -- Need two case expressions with same test
         case 
           when nuov.oos_date >= ooev.oos_date + 7 then ooev.grp + 1
           else ooev.grp 
         end as grp,
         case 
           when nuov.oos_date >= ooev.oos_date + 7 then nuov.oos_date
           else ooev.oos_date
         end as oos_start_date
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
)
select rn, grp, oos_start_date, oos_date from oos_events;







/* Use the new start of group date column */ 
with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, 
  grp, oos_start_date
) as (
  select nuov.*, 
         0 grp, 
         nuov.oos_date oos_start_date
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then ooev.grp + 1
           else ooev.grp
         end as grp,
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then nuov.oos_date
           else ooev.oos_start_date
         end as oos_start_date
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
)
select rn, grp, oos_start_date, oos_date from oos_events;



/* Looking good!
  Need to return one row/grp
 */




with numbered_oos_events as (
  select d.*, row_number () over ( order by oos_date ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, grp, oos_start_date ) as (
  select nuov.*, 
         0 grp,
         nuov.oos_date oos_start_date
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then ooev.grp + 1
           else ooev.grp
         end as grp,
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then nuov.oos_date
           else ooev.oos_start_date
         end as oos_start_date
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
), oos_grps as ( 
  select master_id, marketplace_id, oos_start_date, grp 
  from   oos_events
  group  by master_id, marketplace_id, oos_start_date, grp
)
select * from oos_grps;




/* Add in previous date with LAG and we're done! */
with numbered_oos_events as (
  select d.*, row_number () over ( 
            partition by master_id, marketplace_id
            order by oos_date 
         ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, grp, oos_start_date ) as (
  select nuov.*, 
         0 grp,
         nuov.oos_date oos_start_date
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then ooev.grp + 1
           else ooev.grp
         end as grp,
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then nuov.oos_date
           else ooev.oos_start_date
         end as oos_start_date
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
), oos_grps as ( 
  select master_id, marketplace_id, oos_start_date, grp 
  from   oos_events
  group  by master_id, marketplace_id, oos_start_date, grp
)
select master_id, marketplace_id, 
       lag ( oos_start_date ) over ( 
         partition by master_id, marketplace_id
         order by oos_start_date 
       ) as previous_date,
       oos_start_date as event_date, 
       grp as iteration,
       oos_start_date - lag ( 
         oos_start_date, 1, oos_start_date 
       ) over ( 
         partition by master_id, marketplace_id
         order by oos_start_date 
       ) as days_from_previous_event
from   oos_grps;


/* Recheck the performance */
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );



/* Make into a view for ease of testing */
create or replace view oos_events_recursive_with_opt as
with numbered_oos_events as (
  select d.*, row_number () over ( 
            partition by master_id, marketplace_id
            order by oos_date 
         ) rn
  from   detailed_oos_events d
), oos_events ( master_id, marketplace_id, oos_date, rn, grp, oos_start_date ) as (
  select nuov.*, 
         0 grp,
         nuov.oos_date oos_start_date
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then ooev.grp + 1
           else ooev.grp
         end as grp,
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then nuov.oos_date
           else ooev.oos_start_date
         end as oos_start_date
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
), oos_grps as ( 
  select master_id, marketplace_id, oos_start_date, grp 
  from   oos_events
  group  by master_id, marketplace_id, oos_start_date, grp
)
select master_id, marketplace_id, 
       lag ( oos_start_date ) over ( 
         partition by master_id, marketplace_id
         order by oos_start_date 
       ) as previous_date,
       oos_start_date as event_date, 
       grp as iteration,
       oos_start_date - lag ( 
         oos_start_date, 1, oos_start_date 
       ) over ( 
         partition by master_id, marketplace_id
         order by oos_start_date 
       ) as days_from_previous_event
from   oos_grps;




/* Check it's correct */
select master_id, marketplace_id, 
       previous_date, event_date, 
       iteration, days_from_previous_event 
from ( 
  select opt.*, 1 opt, 0 orig from oos_events_recursive_with_opt opt
  union  all 
  select orig.*, 0 opt, 1 orig from oos_events_original orig
)
group  by master_id, marketplace_id, 
       previous_date, event_date, 
       iteration, days_from_previous_event
having sum ( opt ) <> sum ( orig );




/*******************************



*******************************/


/* What's the requirement? 
   Find the next row 7 days or more after the current 
   Repeat from the current 
   This is a pattern matching problem!
*/


/* First attempt at pattern matching solution */
select *
from   detailed_oos_events
  match_recognize (
    order by oos_date 
    -- any row, then zero+ any other row, then one row 7 days after first
    pattern ( init within_7* more_than_7 ) 
    define 
      more_than_7 as oos_date >= init.oos_date + 7  
  );




/* Why ORA-30732: table contains no user-visible columns?
   To define output columns, MATCH_RECOGNIZE must have at least one of
     PARTITION BY 
     MEASURES 
     ALL ROWS PER MATCH 
*/




/* We know we need groups for (master_id, marketplace_id) 
   => put these in PARTITION BY */
select *
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    pattern ( init within_7* more_than_7 ) 
    define 
      more_than_7 as oos_date >= init.oos_date + 7  
  );









/* Something's wrong; all rows in one group... 
   Let's add some debugging */
select *
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures -- define calculated columns in output
      oos_date, 
      more_than_7.oos_date - init.oos_date,
      match_number(),   -- which group number this is 
      classifier()      -- show which pattern variable matches 
    all rows per match  -- output every row (default = one row per match)
    pattern ( init within_7* more_than_7 ) 
    define 
      more_than_7 as oos_date >= init.oos_date + 7  
  );







/* ORA-62505: expression needs to be aliased 
   Must provide alias for expressions in MEASURES */






/* Add debugging v2 => alias measures expressions */
select var, iteration, days_from_previous_event, oos_date, event_date, master_id, marketplace_id
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures -- define calculated columns in output
      oos_date       as event_date,
      more_than_7.oos_date - init.oos_date 
                     as days_from_previous_event,
      match_number() as iteration, -- show group number 
      classifier()   as var        -- show which variable is matched
    all rows per match             -- output every row (default = one row per match)
    pattern ( init within_7* more_than_7 ) 
    define 
      more_than_7 as oos_date >= init.oos_date + 7  
  );




/* What's the problem?
   Regexes are greedy - keep matching as long as they can
   Need to specify match condition for within_7! */



select var, iteration, days_from_previous_event, oos_date, event_date, master_id, marketplace_id
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures 
      oos_date       as event_date,
      more_than_7.oos_date - init.oos_date 
                     as days_from_previous_event,
      match_number() as iteration, 
      classifier()   as var        
    all rows per match             
    pattern ( init within_7* more_than_7 ) 
    define 
      within_7 as oos_date < init.oos_date + 7, -- make this is the opposite of more_than_7
      more_than_7 as oos_date >= init.oos_date + 7  
  );





/* Looking better - 
   Let's hide within_7 from results using exclusion syntax */
select var, iteration, days_from_previous_event, oos_date, event_date, master_id, marketplace_id
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures 
      oos_date as event_date,
      match_number() as iteration,
      more_than_7.oos_date - init.oos_date as days_from_previous_event,
      classifier() as var  
    all rows per match     
    -- {-exclude_var_from_output-}
    pattern ( init {-within_7-}* more_than_7 ) 
    define 
      within_7 as oos_date < init.oos_date + 7,
      more_than_7 as oos_date >= init.oos_date + 7  
  );





/* How does this compare? */
select * from oos_events_original;
/* Problem: after each group we continue from the NEXT row 
   Need to continue from the last matched row */





select var, iteration, days_from_previous_event, oos_date, event_date, master_id, marketplace_id
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures 
      oos_date       as event_date,
      match_number() as iteration,
      more_than_7.oos_date - init.oos_date as days_from_previous_event,
      classifier()   as var  
    all rows per match
    -- Default: SKIP PAST LAST ROW = continue from row after group
    after match skip past last row
    pattern ( init {-within_7-}* more_than_7 ) 
    define 
      within_7 as oos_date < init.oos_date + 7,
      more_than_7 as oos_date >= init.oos_date + 7  
  );




/* Change the starting row from next group with AFTER MATCH SKIP clause */
select var, iteration, days_from_previous_event, oos_date, event_date, master_id, marketplace_id
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures 
      oos_date as event_date,
      match_number() as iteration,
      more_than_7.oos_date - init.oos_date as days_from_previous_event,
      classifier() as var  
    all rows per match
    -- continue from last matched row
    after match skip to more_than_7
    pattern ( init {-within_7-}* more_than_7 ) 
    define 
      within_7 as oos_date < init.oos_date + 7,
      more_than_7 as oos_date >= init.oos_date + 7  
  );



/* Tidy it up a bit
   - Back to one row per match
   - Removing debugging data
*/ 
select *
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures 
      oos_date       as event_date,
      match_number() as iteration,
      more_than_7.oos_date - init.oos_date as days_from_previous_event
    after match skip to more_than_7 
    pattern ( init within_7* more_than_7 ) 
    define 
      within_7 as oos_date < init.oos_date + 7,
      more_than_7 as oos_date >= init.oos_date + 7  
  );


-- Are we on the right track? Quick performance check
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );
-- Only process each row once! :D





/* Nearly there! Need to add: 
   Previous event
   Iteration 0 */






/* Return date of last row in each group
   Use LAG to find the previous row */
select master_id, marketplace_id, 
       lag ( event_date ) 
         over ( 
           partition by master_id, marketplace_id
           order by event_date 
         ) previous_event, 
       event_date, 
       iteration,
       days_from_previous_event
from   detailed_oos_events
  match_recognize (
    partition by master_id, marketplace_id
    order by oos_date 
    measures 
      oos_date       as event_date,
      match_number() as iteration,
      more_than_7.oos_date - init.oos_date as days_from_previous_event
    after match skip to more_than_7 
    pattern ( init within_7* more_than_7 ) 
    define 
      within_7 as oos_date < init.oos_date + 7,
      more_than_7 as oos_date >= init.oos_date + 7  
  );












/* Missing start row - Use UNION ALL to add it in */
select master_id, marketplace_id, 
       lag ( event_date ) over ( 
         partition by master_id, marketplace_id
         order by event_date
       ) previous_date, 
       event_date, 
       iteration, 
       days_from_previous_event 
from (
  select master_id, marketplace_id, min ( oos_date ) event_date,
         0 iteration, 0 days_from_previous_event
  from   detailed_oos_events
  group  by master_id, marketplace_id
  union  all 
  select master_id, marketplace_id, 
         event_date, 
         iteration, 
         days_from_previous_event
  from   detailed_oos_events
    match_recognize (
      partition by master_id, marketplace_id
      order by oos_date 
      measures 
        oos_date as event_date,
        match_number() as iteration,
        more_than_7.oos_date - init.oos_date as days_from_previous_event
      after match skip to more_than_7
      pattern ( init within_7* more_than_7 ) 
      define 
        within_7 as oos_date < init.oos_date + 7,
        more_than_7 as oos_date >= init.oos_date + 7  
    )
);






/* Verify it's correct - save new query as view for simplicity */
create or replace view oos_events_match_recognize as 
select master_id, marketplace_id, 
       lag ( event_date ) over ( 
         partition by master_id, marketplace_id
         order by event_date
       ) previous_date, 
       event_date, 
       iteration, 
       days_from_previous_event 
from (
  select master_id, marketplace_id, min ( oos_date ) event_date,
         0 iteration, 0 days_from_previous_event
  from   detailed_oos_events
  group  by master_id, marketplace_id
  union  all 
  select master_id, marketplace_id, 
         event_date, 
         iteration, 
         days_from_previous_event
  from   detailed_oos_events
    match_recognize (
      partition by master_id, marketplace_id
      order by oos_date 
      measures 
        oos_date as event_date,
        match_number() as iteration,
        more_than_7.oos_date - init.oos_date as days_from_previous_event
      after match skip to more_than_7
      pattern ( init within_7* more_than_7 ) 
      define 
        within_7 as oos_date < init.oos_date + 7,
        more_than_7 as oos_date >= init.oos_date + 7  
    )
);





/* Compare: no rows => same results */
select master_id, marketplace_id, 
       previous_date, event_date, 
       iteration, days_from_previous_event 
from ( 
  select mr.*, 1 mr, 0 orig from oos_events_match_recognize mr
  union  all 
  select orig.*, 0 mr, 1 orig from oos_events_original orig
)
group  by master_id, marketplace_id, 
       previous_date, event_date, 
       iteration, days_from_previous_event
having sum ( mr ) <> sum ( orig );



/* Check performance */
select * from oos_events_match_recognize;
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );





/* Compare performance to original query */
select * from oos_events_original orig;
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );




/* Looks good! Posted this as the answer */








/* But was this really the best solution? 
   UNION ALL means reading table twice... */







/* Nope! mathguy's solution */
select master_id, marketplace_id, previous_date, event_date, iteration,
       event_date - previous_date as days_from_previous_event
from   detailed_oos_events
match_recognize(
  partition by master_id, marketplace_id
  order     by oos_date
  measures  e.oos_date          as event_date,
            -- find the prior date for E
            last(e.oos_date, 1) as previous_date, 
            count(e.*) - 1      as iteration -- running count of E rows
  all rows per match
  -- Any row, then zero+ within 7 days
  pattern   ( ( e {-x*-} )* )
  define    x as oos_date < e.oos_date + 7
);


/* Check the performance */
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );






/* So what's going on here? 
   Add debugging to understand and include X in results */
select grp, var, iteration,
       master_id, marketplace_id, previous_date, event_date, 
       event_date - previous_date as days_from_previous_event
from   detailed_oos_events
match_recognize(
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date             as event_date,
            last ( init.oos_date, 1 ) as previous_date, 
            count ( init.* ) - 1      as iteration,
            match_number ()           as grp, 
            classifier ()             as var 
  all rows per match
  pattern   ( ( init within_7* )* )
  define    within_7 as oos_date < init.oos_date + 7
);





/* Exclude the 2nd variable again */
select grp, var, iteration,
       master_id, marketplace_id, previous_date, event_date, 
       event_date - previous_date as days_from_previous_event
from   detailed_oos_events
match_recognize(
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date             as event_date,
            last ( init.oos_date, 1 ) as previous_date, 
            count ( init.* ) - 1      as iteration,
            match_number ()           as grp, 
            classifier ()             as var 
  all rows per match
  pattern   ( ( init {-within_7-}* )* )
  define    within_7 as oos_date < init.oos_date + 7
);


/* Double check the plan */
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );




/* Two things still bothered me
   PATTERN is a bit confusing 
   MATCH RECOGNIZE SORT in plan => backtracking could be a problem! */






/* Remove exclusion syntax and repeat group */
select iteration, oos_date, event_date, previous_date, master_id, marketplace_id        
from   detailed_oos_events
match_recognize (
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date             as event_date,
            last ( init.oos_date, 1 ) as previous_date,
            count ( init.* )          as iteration 
  all rows per match
  pattern   ( init within_7* )
  define    within_7 as oos_date < init.oos_date + 7
);



/* Use MATCH_NUMBER() again for iteration
   and one row/match */
select iteration, event_date, previous_date, master_id, marketplace_id 
from   detailed_oos_events
match_recognize (
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date            as event_date,
            last (init.oos_date, 1 ) as previous_date,
            match_number () - 1      as iteration
  pattern   ( init within_7* )
  define    within_7 as oos_date < init.oos_date + 7
);



/* Add previous event data in */
select master_id, marketplace_id, 
       lag ( event_date ) over ( 
         partition by master_id, marketplace_id
         order by event_date
       ) previous_date,
       event_date,
       iteration,
       nvl ( event_date -
         lag ( event_date ) over ( 
           partition by master_id, marketplace_id
           order by event_date
         ), 0 ) days_from_previous_event
from   detailed_oos_events
match_recognize(
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date          as event_date,
            match_number () - 1    as iteration
  pattern   ( init within_7* )
  define    within_7 as oos_date < init.oos_date + 7
);
 
/* Check performance */
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );



/* Plan includes DETERMINISTIC FINITE AUTO 
   => guarantee no backtracking in regex! :D
   But does have an extra WINDOW SORT operation due to LAG :( 
    
   Test on real data to see which MR solution performs best */



/* Check correct */
create or replace view oos_events_match_recognize_opt as 
select master_id, marketplace_id, 
       lag ( event_date ) over ( 
         partition by master_id, marketplace_id
         order by event_date
       ) previous_date,
       event_date,
       iteration,
       nvl ( event_date -
         lag ( event_date ) over ( 
           partition by master_id, marketplace_id
           order by event_date
         ), 0 ) days_from_previous_event
from   detailed_oos_events
match_recognize (
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date             as event_date,
            last ( init.oos_date, 1 ) as previous_date,
            match_number () - 1       as iteration
  pattern   ( init within_7* )
  define    within_7 as oos_date < init.oos_date + 7
);



/* Double check it's the same */ 
select master_id, marketplace_id, 
       previous_date, event_date, 
       iteration, days_from_previous_event 
from ( 
  select mr.*, 1 mr, 0 orig from oos_events_match_recognize_opt mr
  union  all 
  select orig.*, 0 mr, 1 orig from oos_events_original orig
)
group  by master_id, marketplace_id, 
       previous_date, event_date, 
       iteration, days_from_previous_event
having sum ( mr ) <> sum ( orig );
-- Yay!



/* Compare performance */
select * from oos_events_match_recognize_opt o;
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );

select * from oos_events_recursive_with_opt;
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );

-- Pattern matching still the winner!
-- More performant; IMO easier to write





/*******************************




*******************************/


/* Does an index help? */
create index deos_master_market_date_i 
  on detailed_oos_events ( master_id, marketplace_id, oos_date );

/* Check the plans */
select * from oos_events_match_recognize_opt;
select * from oos_events_recursive_with_opt;







/* Makes no difference? 
   Could it be becuase FTS is best? 
   Check with hint */



select /*+ index ( detailed_oos_events ( master_id ) ) */* 
from   detailed_oos_events
match_recognize(
  partition by master_id, marketplace_id
  order     by oos_date
  measures  init.oos_date          as event_date,
            match_number () - 1    as iteration
  pattern   ( init within_7* )
  define    within_7 as oos_date < init.oos_date + 7
);





/* Hint unused?! 
   Let's check the table */
info detailed_oos_events


/* Oracle Database excludes rows where all values are null from the index 
   => unsafe to full scan indexes when columns are optional */







/* All columns are optional! => unsafe to do index only scan */
alter table detailed_oos_events
  modify master_id not null;


/* Check the plans again */
select * from oos_events_match_recognize_opt;
select * from oos_events_recursive_with_opt;






/* Performance checks - load some more data */
insert into detailed_oos_events 
with grps ( master_id ) as (
  values ( 'P01G' ), ( 'P02G' ), ( 'P03G' )
), markets as (
  select level marketplace_id connect by level <= 10
), dts as ( 
  select date'2020-12-31' + level dt
  connect by level <= 1500
)
  select * from grps 
  cross join markets 
  cross join dts;

commit;
exec dbms_stats.gather_table_stats ( null, 'detailed_oos_events', no_invalidate => false );




/* Check the performance now */
set feed only -- suppress query results
select * from oos_events_original
fetch  first 100 rows only; -- Note: fetching 100 rows only!
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );

set feed only
select * from oos_events_recursive_with_opt;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );

set feed only 
select * from oos_events_match_recognize_opt o;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );





/* We can do better! 
   Lots of duplicate entries for the first two rows in the index */
select count(*), master_id, marketplace_id
from   detailed_oos_events
group  by master_id, marketplace_id;




/* => we can compress the index to deduplicate entries in the index */
/* Check the current size */
select leaf_blocks from user_indexes 
where  index_name like 'DEOS%';


alter index deos_master_market_date_i
  rebuild 
  compress 2; -- deduplicate first two entries in index


select leaf_blocks from user_indexes 
where  index_name like 'DEOS%';



set feed only
select * from oos_events_match_recognize_opt o;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );

set feed only
select * from oos_events_recursive_with_opt;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );









/* What about filtering to one group? */
set feed only
select * from oos_events_match_recognize_opt o
where  master_id = 'P04G'
and    marketplace_id = 13;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );
/* Big benefit for MR */


set feed only  
select * from oos_events_recursive_with_opt
where  master_id = 'P04G'
and    marketplace_id = 13;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );
/* Index has no effect for recursive WITH? */





/* For recursive WITH, need to put where clause in initial row numbering query */
with numbered_oos_events as (
  select d.*, row_number () over ( 
            partition by master_id, marketplace_id
            order by oos_date 
         ) rn
  from   detailed_oos_events d
  where  master_id = 'P04G'
  and    marketplace_id = 13
), oos_events ( master_id, marketplace_id, oos_date, rn, grp, oos_start_date ) as (
  select nuov.*, 
         0 grp,
         nuov.oos_date oos_start_date
  from   numbered_oos_events nuov
  where  rn = 1
  union  all 
  select nuov.master_id, nuov.marketplace_id, nuov.oos_date, nuov.rn, 
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then ooev.grp + 1
           else ooev.grp
         end as grp,
         case 
           when nuov.oos_date >= ooev.oos_start_date + 7 then nuov.oos_date
           else ooev.oos_start_date
         end as oos_start_date
  from   oos_events ooev
  join   numbered_oos_events nuov
  on     ooev.rn + 1 = nuov.rn 
  and    ooev.master_id = nuov.master_id  
  and    ooev.marketplace_id = nuov.marketplace_id
), oos_grps as ( 
  select master_id, marketplace_id, oos_start_date, grp 
  from   oos_events
  group  by master_id, marketplace_id, oos_start_date, grp
)
select master_id, marketplace_id, 
       lag ( oos_start_date ) over ( 
         partition by master_id, marketplace_id
         order by oos_start_date 
       ) as previous_date,
       oos_start_date as event_date, 
       grp as iteration,
       oos_start_date - lag ( 
         oos_start_date, 1, oos_start_date 
       ) over ( 
         partition by master_id, marketplace_id
         order by oos_start_date 
       ) as days_from_previous_event
from   oos_grps;

select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );








/* The index opens up another option for recursive WITH 
   Scalar subqueries! */
set feed only
with oos_events (
  master_id, marketplace_id, previous_date, 
  event_date, iteration
) as (   
  select master_id, marketplace_id,
         null as previous_date, 
         min ( oos_date ) as event_date,
         0 as iteration
  from   detailed_oos_events doe
  group  by master_id, marketplace_id
  union  all 
  select e.master_id, e.marketplace_id,
         e.event_date as previous_date, 
         ( select min ( d.oos_date ) 
           from   detailed_oos_events d 
           where  d.oos_date >= e.event_date + 7
           and    d.master_id = e.master_id
           and    d.marketplace_id = e.marketplace_id
         ) as event_date,
         e.iteration + 1 as iteration
  from   oos_events e
  where  exists (
    select null from detailed_oos_events d 
    where  d.oos_date >= e.event_date + 7
    and    d.master_id = e.master_id
    and    d.marketplace_id = e.marketplace_id
  )
) 
cycle  event_date set is_loop to 'Y' default 'N'
select master_id, marketplace_id, previous_date, event_date, iteration, 
       event_date - lag ( 
         event_date, 1, event_date
       ) over ( 
         partition by master_id, marketplace_id
         order by event_date
       ) days_from_previous_event
from   oos_events
order  by master_id, marketplace_id, event_date;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );






/* What if we load even more data in? */
insert into detailed_oos_events 
with grps ( master_id ) as (
  values ( 'P05G' ), ( 'P06G' ), ( 'P07G' ), ( 'P08G' )
), markets as (
  select level marketplace_id connect by level <= 30
), dts as ( 
  select date'2020-12-31' + level dt
  connect by level <= 1500
)
  select * from grps 
  cross join markets 
  cross join dts;

commit;
exec dbms_stats.gather_table_stats ( null, 'detailed_oos_events', no_invalidate => false );




set feed only
with oos_events (
  master_id, marketplace_id, previous_date, 
  event_date, iteration
) as (   
  select master_id, marketplace_id,
         null as previous_date, 
         min ( oos_date ) as event_date,
         0 as iteration
  from   detailed_oos_events doe
  group  by master_id, marketplace_id
  union  all 
  select e.master_id, e.marketplace_id,
         e.event_date as previous_date, 
         ( select min ( d.oos_date ) 
           from   detailed_oos_events d 
           where  d.oos_date >= e.event_date + 7
           and    d.master_id = e.master_id
           and    d.marketplace_id = e.marketplace_id
         ) as event_date,
         e.iteration + 1 as iteration
  from   oos_events e
  where  exists (
    select null from detailed_oos_events d 
    where  d.oos_date >= e.event_date + 7
    and    d.master_id = e.master_id
    and    d.marketplace_id = e.marketplace_id
  )
) 
cycle  event_date set is_loop to 'Y' default 'N'
select master_id, marketplace_id, previous_date, event_date, iteration, 
       event_date - lag ( 
         event_date, 1, event_date
       ) over ( 
         partition by master_id, marketplace_id
         order by event_date
       ) days_from_previous_event
from   oos_events
order  by master_id, marketplace_id, event_date;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );


set feed only
select * from oos_events_match_recognize_opt o;
set feed on
select * from dbms_xplan.display_cursor ( format => 'IOSTATS LAST' );
/* MR clear performance winner */





/*******************************


              FIN


*******************************/