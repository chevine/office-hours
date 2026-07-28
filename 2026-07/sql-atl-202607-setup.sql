alter session set nls_timestamp_format = 'DD-MON-YYYY HH24:MI';
alter session set nls_date_format = 'DD-MON-YYYY';
alter session set calendar_fiscal_year_start = '01-JAN-2026', 'DD-MON-YYYY';
-- set feed only
set feed on
alter session set time_zone = 'UTC';
set long 100000
drop table if exists sensor_readings purge;
drop table if exists temperatures purge;


create table sensor_readings (
    id          number 
      generated as identity primary key,
    sensor_data json
);



-- Generate and insert sample weather sensor data
declare
    v_start_time timestamp := systimestamp;
    rows_per_sensor pls_integer := 5000;
    jdata json;
begin
    for i in 1..rows_per_sensor loop
        for sensor_id in 1..10 loop
            /*jdata := json_object(
                'sensorId' value sensor_id,
                'recordedAt' value (systimestamp - (rows_per_sensor - i) * interval '15' minute),
                'metrics' value json_array(
                    json_object('metricType' value 'temperature', 'reading' value round(dbms_random.value(0, 40), 2)),
                    json_object('metricType' value 'humidity', 'reading' value round(dbms_random.value(0, 100), 2)),
                    json_object('metricType' value 'windSpeed', 'reading' value round(dbms_random.value(0, 50), 2))
                )
                returning json
              );*/
            insert into sensor_readings ( sensor_data ) 
            values ( 
              json_object(
                'sensorId' value sensor_id,
                'recordedAt' value (systimestamp - (rows_per_sensor - i) * interval '15' minute),
                'metrics' value json_array(
                    json_object('metricType' value 'temperature', 'reading' value round(dbms_random.value(0, 40), 2)),
                    json_object('metricType' value 'humidity', 'reading' value round(dbms_random.value(0, 100), 2)),
                    json_object('metricType' value 'windSpeed', 'reading' value round(dbms_random.value(0, 50), 2))
                )
              )
            );/**/
        end loop;
    end loop;
end;
/
commit;

exec dbms_stats.gather_table_stats ( ownname => null, tabname => 'sensor_readings' );

