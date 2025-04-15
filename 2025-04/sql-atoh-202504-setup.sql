
drop table detailed_oos_events purge;
create table detailed_oos_events (
  master_id      varchar2(100),
  marketplace_id number,
  oos_date       date
);

/* Insert Sample Records */
begin
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2023-07-03','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2023-07-04','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-06-30','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-01','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-02','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-03','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-04','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-05','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-06','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-07','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-08','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-09','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-10','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-11','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-12','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-13','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-14','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-15','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-16','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-17','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-18','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-19','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-20','YYYY-MM-DD') );
  insert into detailed_oos_events (
    master_id,
    marketplace_id,
    oos_date
  ) values ( 'P04G',
             13,
             to_date('2024-07-21','YYYY-MM-DD') );
  commit;
end;
/

alter session set statistics_level = all;
set serveroutput off;
col master_id format a10
alter session set nls_date_format = 'DD-MON-YYYY';