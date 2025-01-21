alter table job_history add ( 
  insert_timestamp timestamp default on null systimestamp,
  update_timestamp timestamp default on null for insert and update systimestamp 
);

