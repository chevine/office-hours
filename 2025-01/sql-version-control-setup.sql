/* Run this before presentation! */
-- Run flashback to ensure clean slate
drop user if exists hr_app;
grant create session to hr_app identified by hr_app;

alter trigger hr.update_job_history disable;
drop procedure hr.add_job_history;

drop restore point pre_release;
create restore point pre_release;
