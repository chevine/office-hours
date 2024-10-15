set define off
drop view people_ages;
drop function people_ages;
drop table if exists celebrate_birth_dates cascade constraints purge;
drop table if exists people cascade constraints purge;
drop table if exists celebrate_birth_dates cascade constraints purge;

create or replace function yyyymmdd ( 
  input_date date 
) return integer as
begin
  return to_number ( 
    to_char ( input_date, 'yyyymmdd' ) 
  );
end;
/


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


insert into ages (
  calendar_date, leapling_celebrate, birth_date, age, is_birthday 
)
with dts as ( 
  select date'1969-12-31' + level dt
  connect by level <= date'2026-01-01' - date'1970-01-01'
), leaps ( leapling_celebrate ) as (
  values ( cast ( 'FEB' as char (3 char) ) ), 
         ( cast ( 'MAR' as char (3 char) ) ) 
)
select 
  c.dt calendar_date,   
  l.leapling_celebrate, 
  b.dt birth_date, 
  case 
    when l.leapling_celebrate = 'FEB' 
    then floor ( months_between ( c.dt, b.dt ) / 12 ) 
    when l.leapling_celebrate = 'MAR'
    then floor ( ( yyyymmdd ( c.dt ) - yyyymmdd ( b.dt ) ) / 10000 )
  end age,
  case  
    when to_char ( b.dt, 'DD-MON' ) = to_char ( c.dt, 'DD-MON' ) then true
    when to_char ( b.dt, 'DD-MON' ) = '29-FEB' 
    and  mod ( extract ( year from c.dt ), 4 ) <> 0
    then
      case 
        when l.leapling_celebrate = 'FEB' and to_char ( c.dt, 'DD-MON' ) = '28-FEB' then true
        when l.leapling_celebrate = 'MAR' and to_char ( c.dt, 'DD-MON' ) = '01-MAR' then true
        else false
      end 
    else false 
  end is_birthday
from   dts b cross join dts c
cross  join (
  select * from (
    values ( 'FEB' ), ( 'MAR' )
  ) leaps ( leapling_celebrate )
) l
where  b.dt <= c.dt
and    c.dt >= date'2023-01-01';

create index age_birth_dt_i 
  on ages ( birth_date );

create table people ( 
  person_id  int primary key,
  birth_date date
);

insert into people 
values ( 1, date'1974-05-01' ), -- 
       ( 2, date'2000-02-28' ), -- 
       ( 3, date'2000-02-29' ), -- 
       ( 4, date'2000-03-01' ), -- 
       ( 5, date'2016-10-14' ), -- 
       ( 6, date'2016-10-15' ), -- 
       ( 7, date'2016-10-16' ), -- 
       ( 8, date'2016-11-14' ), -- 
       ( 9, date'2016-11-15' ), -- 
       ( 10, date'2016-11-16' );

commit;
alter session set nls_date_format = '  DD-MON-YYYY  ';

alter system set fixed_date = none;
-- Live session ran on 15th Oct
-- alter system set fixed_date = '15-OCT-2024'; 

var leap varchar2(4);
var age number;
var min_age number;
var n number;

exec :leap := 'MAR';
exec :age := 23;
exec :min_age := 23;
exec :n := 7;