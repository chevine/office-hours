drop table if exists time_data purge;
create table time_data ( datetime ) as  
select cast ( datetime as date ) from (   
-- select cast ( datetime as timestamp ) from (   
  select date'2025-02-01'   
           + numtodsinterval ( level , 'minute' )   
           + ( mod ( level, 17 ) / 60 / 24 )  
           + ( sin ( level ) / 24 ) datetime  
  from   dual  
  connect by level <= 2000  
  union  all  
  select date'2025-02-01' + ( 75 / 1440 )
  union  all  
  select date'2025-02-02'  
           + ( level / 4 )  
           + ( sin ( level ) / 24 ) datetime  
  from   dual  
  connect by level <= 200  
)  
where  datetime >= date'2025-02-01'  
and    datetime not between date'2025-02-01' + 15/24/60 and date'2025-02-01' + 19/24/60   
order  by datetime;
