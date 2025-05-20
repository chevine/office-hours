@sql-atoh-202505-fuzzy-matching-setup






/* Find names that sound like Steven */
select employee_id, first_name, last_name from employees 
where  first_name in ( 'Steven', 'Stephen' );









/* LIKE - wildcard matching */
select employee_id, first_name, last_name from employees 
where  first_name like 'Ste_en'; -- one character match

select employee_id, first_name, last_name from employees 
where  first_name like 'Ste__en'; -- two characters match

select employee_id, first_name, last_name from employees 
where  first_name like 'Ste%en'; -- zero+ character match









/* Find staff with surnames sounding like Lee */
select employee_id, first_name, last_name from employees 
where  last_name in ( 'Li', 'Lee' );


/* Using LIKE returns many unwanted matches */
select employee_id, first_name, last_name from employees 
where  last_name like 'L%';






/* Sounds like... what about SOUNDEX?
   Algorithm popularized by Donald Knuth
   Find matches based on English pronunciation */
select first_name, soundex ( first_name )
from   employees
where  soundex ( first_name ) = soundex ( 'Steven' );


/* Also works for Li/Lee */
select last_name, soundex ( last_name )
from   employees
where  soundex ( last_name ) = soundex ( 'Lee' );







/* What about variations on Chris? */
select * from employees 
where  first_name = 'Christopher';







/* Swap Ch => K */
select first_name
from   employees
where  soundex ( first_name ) = soundex ( 'Kristopher' );
/* No rows?! */








/* SOUNDEX Problems
   Preserves first character */
select soundex ( 'Chris' ) = soundex ( 'Kris' ),
       soundex ( 'Chris' ), 
       soundex ( 'Kris' );






/* SOUNDEX Problems 
   Exactly four characters in encoding  
   => long names can have false positives 
   => miss possible abbreviations */ 
select soundex ( 'Christina' ) = soundex ( 'Christopher' ),
       soundex ( 'Chris' ), 
       soundex ( 'Christina' ), 
       soundex ( 'Christopher' );







/* Try fuzzy matching */

/* Edit distance (Levenshtein) 
   Number of changes required to make STR1 = STR2 */
select employee_id, first_name, 
       utl_match.edit_distance (
          first_name, 'Steven'
       ) changes,
       utl_match.edit_distance_similarity (
          first_name, 'Steven'
       ) similarity 
from   employees 
where  first_name in ( 'Steven', 'Stephen' );
/* Similarity: invert % of string changes 
   0 => all change
   100 => no changes
*/



select employee_id, first_name, 
       utl_match.edit_distance (
          first_name, 'Kristopher'
       ) changes,
       utl_match.edit_distance_similarity (
          first_name, 'Kristopher'
       ) similarity
from   employees 
where  first_name = 'Christopher';




select employee_id, last_name, 
       utl_match.edit_distance (
          last_name, 'Lee'
       ) changes,
       utl_match.edit_distance_similarity (
          last_name, 'Lee'
       ) similarity
from   employees 
where  last_name in ( 'Li', 'Lee' );




/* Can lead to lots of false positives */
select employee_id, first_name, last_name, 
       utl_match.edit_distance (
          last_name, 'Lee'
       ) changes,
       utl_match.edit_distance_similarity (
          last_name, 'Lee'
       ) similarity
from   employees 
order  by similarity desc;






/* Fuzzy matching with Jaro-Winkler 
   Returns value between 0-1 (1 = exact match)
   Includes concept of distance: 
   Check for same characters within half the length of the string */
select employee_id, first_name, last_name, 
       utl_match.jaro_winkler (
          first_name, 'Steven'
       ) jw,
       utl_match.jaro_winkler_similarity (
          first_name, 'Steven'
       ) similarity
from   employees 
where  first_name in ( 'Steven', 'Stephen' );


select employee_id, first_name, last_name, 
       utl_match.jaro_winkler (
          first_name, 'Kristopher'
       ) changes,
       utl_match.jaro_winkler_similarity (
          first_name, 'Kristopher'
       ) similarity
from   employees 
where  first_name = 'Christopher';






/* Can still give lots of false positives! */
select employee_id, first_name, last_name, 
       utl_match.jaro_winkler (
          last_name, 'Lee'
       ) jw,
       utl_match.jaro_winkler_similarity (
          last_name, 'Lee'
       ) similarity
from   employees 
order  by similarity desc;












/* Levenshtein vs Jaro-Winkler */
with strs ( str1, str2 ) as (
  values ( 'AA', 'AA' ),
         ( 'AAC', '1AA' ),
         ( 'AABC', '12AA' ),
         ( 'AABCD', '123AA' ), -- More than half the string apart
         ( 'AA', 'AABCDE' ),   -- excess characters at end
         ( 'AA', 'BCDEAA' )    -- excess characters at start
)
select str1, str2, 
       utl_match.edit_distance_similarity (
         str1, str2
       ) lev,
       utl_match.jaro_winkler_similarity (
         str1, str2
       ) jw 
from   strs;



/* Levenshtein - changes at position
   Jaro Winkler biased to matches at the start */









/* Find top-N similar strings */
with search as ( 
  select 'Steven' as search_name
)
select employee_id, first_name, 
       utl_match.jaro_winkler_similarity (
          first_name, search_name
       ) jw,
       utl_match.edit_distance_similarity (
          first_name, search_name
       ) lev
from   employees 
cross  join search
order  by jw desc
fetch  first 5 rows with ties; -- Include rows with same match value as the Nth row




/*******************************




*******************************/



/* Revisiting sounds like - problems with SOUNDEX */

/* False negative (K vs C - expect to match Christopher) */
select first_name
from   employees
where  soundex ( first_name ) = soundex ( 'Kristopher' );

/* False positive (Christina should not match Christopher) */
select first_name
from   employees
where  soundex ( first_name ) = soundex ( 'Christina' );






/* 23ai implements double metaphone algorithm with PHONIC_ENCODE 
   More sophisticated sounds like matching 
   Christopher and Kristopher match */
select first_name, 
       phonic_encode ( double_metaphone, 'Kristopher' ) metaph
from   employees
where  phonic_encode ( double_metaphone, first_name ) = 
       phonic_encode ( double_metaphone, 'Kristopher' );







/* By default 4 char encoding 
   => Christopher and Christina match */
select first_name, 
       phonic_encode ( double_metaphone, 'Christina' ) metaph
from   employees
where  phonic_encode ( double_metaphone, first_name ) = 
       phonic_encode ( double_metaphone, 'Christina' );







/* Can increase encoded string characters (up to 12) */
select first_name, 
       phonic_encode ( double_metaphone, 'Christina', 12 ) metaph
from   employees
where  phonic_encode ( double_metaphone, first_name, 12 ) = 
       phonic_encode ( double_metaphone, 'Christina', 12 );






/* Double metaphone much better than soundex 
   Care still needed for similar names or shortening/abbreviations */
select phonic_encode ( double_metaphone, 'Chris' ) 
         = phonic_encode ( double_metaphone, 'Christopher' ) compare,
       phonic_encode ( double_metaphone, 'Chris', 3 ) krs,
       phonic_encode ( double_metaphone, 'Christina', 3 ) krstn,
       phonic_encode ( double_metaphone, 'Christopher', 3 ) krstfr;







/* Are these names pronounced the same? */
select phonic_encode ( double_metaphone, 'Jasmin' )
         = phonic_encode ( double_metaphone, 'Yasmin' ) compare,
       phonic_encode ( double_metaphone, 'Jasmin' ) jasmin,
       phonic_encode ( double_metaphone, 'Yasmin' ) yasmin;








/* It depends on your language/dialect! */
select phonic_encode ( double_metaphone_alt, 'Jasmin' )
         = phonic_encode ( double_metaphone_alt, 'Yasmin' ) compare,
       phonic_encode ( double_metaphone_alt, 'Jasmin' ) jasmin,
       phonic_encode ( double_metaphone_alt, 'Yasmin' ) yasmin;









/* Pirmary and secondary encoding to account for different language pronunciation */
with encodings as (
  select first_name, 
         phonic_encode ( double_metaphone, first_name, 12 ) fname_meta,
         phonic_encode ( double_metaphone_alt, first_name, 12 ) fname_alt,
         last_name,
         phonic_encode ( double_metaphone, last_name, 12 ) lname_meta,
         phonic_encode ( double_metaphone_alt, last_name, 12 ) lname_alt
  from   employees
)
select * from encodings
where  fname_alt <> fname_meta 
or     lname_alt <> lname_meta;












/* What about fuzzy matching in 23ai? */
/* Use the FUZZY_MATCH operator */
with search as ( 
  select 'Steven' as search_name
)
select employee_id, first_name, last_name,
       fuzzy_match ( 
          jaro_winkler, -- algorithm
          first_name, 
          search_name
       ) jw,
       fuzzy_match ( 
          levenshtein,  -- algorithm
          first_name, 
          search_name
       ) lev
from   employees 
cross  join search
order  by jw desc
fetch  first 5 rows with ties;




/* FUZZY_MATCH uses scaled (similarity) by default 
   Use UNSCALED parameter to return raw value */
with search as ( 
  select 'Steven' as search_name
)
select employee_id, first_name, 
       fuzzy_match ( 
          jaro_winkler,
          first_name, search_name, unscaled
       ) jw,
       fuzzy_match ( 
          levenshtein, 
          first_name, search_name, unscaled
       ) lev
from   employees 
cross  join search
order  by jw desc
fetch  first 5 rows with ties;






/* But that's not all! */




/* N-gram - number of common 2 or 3 letter strings */
with search as ( 
  select 'Steven' as search_name
  -- Bigram match St, te, ev, ve, en
  -- Trigram match Ste, tev, eve, ven
)
select employee_id, first_name, 
       fuzzy_match ( 
          bigram, 
          first_name, search_name
       ) big,
       fuzzy_match ( 
          trigram, 
          first_name, search_name, unscaled
       ) trig
from   employees 
cross  join search
order  by big desc
fetch  first 5 rows with ties;





/* Longest common substring */
with search as ( 
  select 'Chris' as search_name
)
select employee_id, first_name, 
       fuzzy_match ( 
          longest_common_substring, 
          first_name, search_name
       ) lcs,
       fuzzy_match ( 
          longest_common_substring, 
          first_name, search_name, unscaled -- chars in longest match
       ) lcs_unscaled
from   employees 
cross  join search
order  by lcs desc
fetch  first 5 rows with ties;





/* What about matching on family and given name? */




/* Matching many words */
with search as ( 
  select 'Chris Johnston' as search_name
)
select employee_id, first_name, last_name,
       fuzzy_match ( 
         jaro_winkler,
         first_name || ' ' || last_name, search_name
       ) jw,
       fuzzy_match ( 
         levenshtein,
         first_name || ' ' || last_name, search_name
       ) lev
from   employees 
cross  join search
order  by jw desc, lev desc
fetch  first 15 rows with ties;





/* Whole word matching -
   Comparing sentences or phrases  */
with search as ( 
  select 'Chris Johnston' as search_name
)
select employee_id, first_name, last_name,
       fuzzy_match ( 
          whole_word_match,
          first_name || ' ' || last_name, search_name
       ) wwm,
       fuzzy_match ( 
          whole_word_match,
          first_name || ' ' || last_name, search_name, 
          edit_tolerance 50 -- percent of different characters
       ) wwm_50pct
from   employees 
cross  join search
order  by wwm_50pct desc
fetch  first 15 rows only;










/* To UTL_MATCH or FUZZY_MATCH? It depends! */

/* Both Levenshtein and Jaro-Winkler are case-sensitive */
select employee_id, first_name, last_name, 
       utl_match.edit_distance_similarity (
          first_name, 'STEVEN'
       ) lev,
       utl_match.jaro_winkler_similarity (
          first_name, 'STEVEN'
       ) jw
from   employees 
where  first_name in ( 'Steven', 'Stephen' );




/* Use upper/lower if need utl_match case insensitivity */
with search as ( 
  select 'STEVEN' as search_name
)
select employee_id, first_name,
       utl_match.edit_distance_similarity (
          upper ( first_name ), search_name
       ) um_lev,
       utl_match.jaro_winkler_similarity (
          upper ( first_name ), search_name
       ) um_jw
from   employees 
cross  join search
where  first_name in ( 'Steven', 'Stephen' );







/* What about COLLATE (added in 12.2)? */
select 'Steven' = 'STEVEN' collate binary_ci;







/* Case-insensitivity 
   FUZZY_MATCH works with COLLATE 
   UTL_MATCH doesn't */
with search as ( 
  select 'STEVEN' collate binary_ci 
    as search_name
)
select employee_id, first_name,
       fuzzy_match (
          levenshtein, first_name, search_name
       ) fm_lev,
       utl_match.edit_distance_similarity (
          first_name, search_name
       ) um_lev, 
       fuzzy_match ( 
         jaro_winkler, first_name, search_name
       ) fm_jw,
       utl_match.jaro_winkler_similarity (
          first_name, search_name
       ) um_jw
from   employees 
cross  join search
where  first_name in ( 'Steven', 'Stephen' );












/* Can define collations at column level
   This makes first_name is case and accent insensitive */
alter table employees modify 
  first_name collate binary_ai;



/* FUZZY_MATCH picks up column collation 
   UTL_MATCH doesn't */
with search as ( 
  select 'STÉVÊÑ' as search_name
)
select employee_id, first_name,
       fuzzy_match (
          levenshtein, first_name, search_name
       ) fm_lev,
       utl_match.edit_distance_similarity (
          first_name, search_name
       ) um_lev, 
       fuzzy_match ( 
         jaro_winkler, first_name, search_name
       ) fm_jw,
       utl_match.jaro_winkler_similarity (
          first_name, search_name
       ) um_jw
from   employees 
cross  join search
where  first_name in ( 'Steven', 'Stephen' );


/* Make case-sensitive again */
alter table employees modify 
  first_name collate using_nls_comp;





/* Only utl_match works in PL/SQL */
exec dbms_output.put_line ( utl_match.jaro_winkler_similarity ( 'Steven', 'Stephen' ) );
exec dbms_output.put_line ( fuzzy_match ( jaro_winkler, 'Steven', 'Stephen' ) );





/****************************



****************************/

/* Compare SQL vs PL/SQL performance */
declare 
  search_name varchar2(10) := 'Steven';
  iterations pls_integer   := 10000;
  names      dbms_sql.varchar2_table;
  match      pls_integer;
begin
  timing_pkg.set_start_time;
  for i in 1 .. iterations loop
    for rws in (
      select first_name, 
             fuzzy_match ( 
               jaro_winkler,
               first_name, search_name
             ) jw,
             fuzzy_match ( 
               levenshtein, 
               first_name, search_name
             ) lev
      from   employees 
    ) loop 
      null;
    end loop;
  end loop;
  timing_pkg.calc_runtime ( 'SQL   ', iterations );

  timing_pkg.set_start_time;
  for i in 1 .. iterations loop
    for rws in (
      select first_name, 
       utl_match.jaro_winkler_similarity (
          first_name, search_name
       ) jw,
       utl_match.edit_distance_similarity (
          first_name, search_name
       ) lev
      from   employees 
    ) loop 
      null;
    end loop;
  end loop;
  timing_pkg.calc_runtime ( 'PL/SQL', iterations );

end;
/












/* Compare SQL to pure PL/SQL */
declare 
  search_name varchar2(10) := 'Steven';
  iterations pls_integer := 10000;
  names      dbms_sql.varchar2_table;
  match      pls_integer;
begin
  timing_pkg.set_start_time;
  for i in 1 .. iterations loop
    for rws in (
      select first_name, 
             fuzzy_match ( 
               jaro_winkler,
               first_name, search_name
             ) jw,
             fuzzy_match ( 
               levenshtein, 
               first_name, search_name
             ) lev 
      from   employees 
    ) loop 
      null;
    end loop;
  end loop;
  timing_pkg.calc_runtime ( 'SQL   ', iterations );

  timing_pkg.set_start_time;
  for i in 1 .. iterations loop
    select first_name 
    bulk   collect 
    into   names 
    from   employees;

    for name in values of names loop
      match := utl_match.jaro_winkler_similarity (
        name, search_name
      );
      match := utl_match.edit_distance_similarity (
        name, search_name
      );
    end loop;

  end loop;
  timing_pkg.calc_runtime ( 'PL/SQL', iterations );


end;
/








/* Can we index phonic encoding? */
create index emp_fname_encode_i 
  on employees ( 
    phonic_encode (
      double_metaphone, first_name, 12
    )
  );






/* Yes we can! */
select first_name, 
       phonic_encode ( double_metaphone, 'Kristopher' ) metaph
from   employees
where  phonic_encode ( double_metaphone, first_name, 12 ) = 
       phonic_encode ( double_metaphone, 'Kristopher', 12 );








/* Ensure index parameters match query parameters */
select first_name, 
       phonic_encode ( double_metaphone, 'Kristopher' ) metaph
from   employees
where  phonic_encode ( double_metaphone, first_name, 6 ) = 
       phonic_encode ( double_metaphone, 'Kristopher', 6 );






/* What about fuzzy matching? */
create index emp_match_i 
  on employees ( 
    utl_match.jaro_winkler_similarity (
      first_name, 'Steven'
    )
  );



/* Same problem for other UTL_MATCH functions */


/* Can we index it? */
create index emp_match_i 
  on employees ( 
    fuzzy_match ( 
      jaro_winkler, first_name, 'Steven'
    )
  );

select * from employees 
where  fuzzy_match ( 
         jaro_winkler,first_name, 'Steven'
       ) > 80;




/* ...but we've hard-coded the search string! */
select * from employees 
where  fuzzy_match ( 
         jaro_winkler, first_name, 'Kristopher'
       ) > 80;
/* (probably) not very useful */




/* What about Oracle Text? */





/* SEARCH keyword 23ai simplification */
create search index emp_fname_text_i 
  on employees ( first_name );


/* 21c and earlier method for Oracle Text */
create index emp_lname_text_i 
  on employees ( last_name )
  indextype is ctxsys.context;





/* This enables CONTAINS queries to use an index */
select * from employees 
where  contains ( first_name, 'steven' ) > 0;







/* CONTAINS has FUZZY operator 
   Uses proprietary algorithm */
select score (1), employee_id, first_name 
from   employees
where  contains ( first_name, 'fuzzy ( steven )', 1 ) > 0;





select score (1), employee_id, first_name, last_name from employees
where  contains ( first_name, 'fuzzy ( chris )', 1 ) > 0;





/* Returning more matches
   2nd parameter - min similartiy score; lower => more results
   3rd parameter - number of expansions; higher => more results */
select score (1), employee_id, first_name, last_name from employees
where  contains ( first_name, 'fuzzy ( chris, 1, 5000 )', 1 ) > 0;





/* Fuzzy uses first character matching */
select score (1), employee_id, first_name from employees
where  contains ( first_name, 'fuzzy ( kristopher, 1, 5000 )', 1 ) > 0;







/* NDATA - fuzzy matching alternative 
   Combines fuzzy and soundex logic
   */
begin
  ctx_ddl.create_preference ( 'name_ds', 'MULTI_COLUMN_DATASTORE' );
  ctx_ddl.set_attribute ( 'name_ds', 'COLUMNS', 'first_name' );

  ctx_ddl.create_section_group ( 'name_sg', 'BASIC_SECTION_GROUP' );
  ctx_ddl.add_ndata_section ( 'name_sg', 'first_name', 'first_name' );
end;
/


/* Use the data store and section group */
alter index emp_fname_text_i 
  rebuild
  parameters ( 'replace datastore name_ds section group name_sg ');





/* Default use */
select score(1), e.* from employees e
where  contains ( first_name, 'ndata ( first_name, steven )', 1 ) > 0
order  by score(1) desc;
/* Only exact match?! */






/* Decrease the match threshold; 5th parameter */
select score(1), e.* from employees e
where  contains ( first_name, 'ndata ( first_name, steven, , , 1 )', 1 ) > 0
order  by score(1) desc;




select score(1), e.* from employees e
where  contains ( first_name, 'ndata ( first_name, chris, , , 1 )', 1 ) > 0
order  by score(1) desc;

select score(1), e.* from employees e
where  contains ( first_name, 'ndata ( first_name, kristopher, , , 1 )', 1 ) > 0
order  by score(1) desc;



/****************************

            FIN 

****************************/


