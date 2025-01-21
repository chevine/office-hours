sho pdbs


alter pluggable database freepdb1 close immediate;

flashback pluggable database freepdb1 to restore point pre_release;

alter pluggable database freepdb1 open resetlogs;









/* Check it's definitely reset */
select * from cdb_objects
where  owner = 'HR'
and    con_id = 3
and    object_name in ( 'CHANGE_JOB', 'EMPLOYEE_JOB_CHANGES' );

select * from cdb_tab_cols
where  owner = 'HR'
and    con_id = 3
and    table_name = 'JOB_HISTORY';