drop table employees cascade constraints purge;
exec ctx_ddl.drop_section_group('name_sg');
exec ctx_ddl.drop_preference('name_ds');

create or replace package timing_pkg as 

  start_time pls_integer;
  time_taken pls_integer;
  
  procedure set_start_time;
  procedure calc_runtime ( 
    operation varchar2,
    executions pls_integer default 1
  );
  
end;
/

create or replace package body timing_pkg as 
  
  procedure set_start_time as 
  begin 
    start_time := dbms_utility.get_time; 
  end; 

  procedure calc_runtime (  
    operation varchar2,
    executions pls_integer default 1
  ) as 
  begin 
    time_taken :=  
      ( dbms_utility.get_time - start_time ); 
    dbms_output.put_line ( 
      operation || ' ' || to_char ( ( time_taken / 100 ), 'fm990.00' ) || ' seconds ' ||
      to_char ( ( time_taken / executions / 100 ), 'fm90.099999' ) || ' seconds/exec '
    ); 
  end; 

end;
/

create table employees as 
  select * from hr.employees ;