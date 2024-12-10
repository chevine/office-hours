@sql-atoh-202412-setup


/* Create a usecase domain for monetary values */
create usecase domain money as (
  amount            as number,
  currency_code     as varchar2(3 char),
  eur_exchange_rate as number
    default 1
) 
order amount * eur_exchange_rate
display to_char ( round ( amount * eur_exchange_rate, 2 ) );






create table coffee_packs ( 
  coffee_pack_id integer primary key,
  blend          varchar(100) unique not null
);


-- Store the prices in different currencies
create table coffee_pack_prices ( 
  coffee_pack_id references coffee_packs,
  price          number, 
  currency_code  varchar2(3 char), 
  eur_ex_rate    number,
  domain money ( price, currency_code, eur_ex_rate ),
  primary key ( coffee_pack_id, currency_code ) 
);



/* Create some coffee blends! */
insert into coffee_packs 
values ( 1, 'Java Jolt' ),
       ( 2, 'SQL Speciality' ),
       ( 3, 'PL/SQL Powerpunch' );

/* And load their prices */
insert into coffee_pack_prices values 
  ( 1, 5.95, 'EUR', 1 ), 
  ( 1, 4.95, 'GBP', 1.20202020 ), 
  ( 1, 5.45, 'CHF', 1.09174311 ),
  ( 2, 6.95, 'EUR', 1 ), 
  ( 2, 5.95, 'GBP', 1.20202020 ), 
  ( 2, 6.45, 'CHF', 1.09174311 ),
  ( 3, 8.45, 'EUR', 1 ), 
  ( 3, 7.45, 'GBP', 1.20202020 ), 
  ( 3, 7.95, 'CHF', 1.09174311 );

/* Check the data */
select * from coffee_packs;
select * from coffee_pack_prices;






-- View the catalogue with EUR prices
select 
  price,  
  blend
from   coffee_packs copa
join   coffee_pack_prices copp
using ( coffee_pack_id )
where  currency_code = 'EUR'
order  by price;





/* Define which grinds are available */ 
create domain grinds_d as enum ( 
  wholebean  = 1, 
  filter     = 2, 
  stovetop   = 3,
  aeropress  = 4,
  cafetiere  = 5
);

create table grinds ( 
  grind_id   integer domain grinds_d primary key, 
  grind_name varchar2(30) not null
);

/* Use enum values as PK values */
insert into grinds values 
  ( grinds_d.wholebean, 'Wholebean' ),
  ( grinds_d.filter,    'Filter' ),
  ( grinds_d.stovetop,  'Stovetop' ),
  ( grinds_d.aeropress, 'Aeropress' ),
  ( grinds_d.cafetiere, 'Cafetiere' );




select * from grinds;
select * from grinds_d;





/* Solving the address problem - 
   flex domains with JSON schemas! */





/* British addresses */
create domain gb_address as ( 
  address as json validate '{
    "type" : "object",
    "properties" : {
      "street" : { "extendedType" : "string" },
      "locality" : { "extendedType" : "string" },
      "town" : { "extendedType" : "string" },
      "postCode" : {
        "extendedType" : "string",
        "allOf" : [ { "pattern" : "^[A-Z]{1,2}[0-9][A-Z]{0,1} [0-9][A-Z]{2}$" } ]
      }
    },
    "required" : [ "street", "town", "postCode" ]
  }' 
);




/* French addresses */
create domain fr_address as ( 
  address as json validate '{
    "type" : "object",
    "properties" : {
      "street" : { "extendedType" : "string" },
      "town" : { "extendedType" : "string" },
      "postCode" : {
        "extendedType" : "string",
        "allOf" : [ { "pattern" : "^[0-9]{5}$" } ]
      }
    },
    "required" : [ "street", "town", "postCode" ]
  }' 
);
  


/* Default address - no validation! */
create domain global_address as ( 
  address as json
); 



  



/* Create flex domain */
create flexible domain address (
  address
)
choose domain using ( country_code varchar2(2 char) )
from (
  case country_code
    when 'GB' then gb_address ( address )
    when 'FR' then fr_address ( address )
    else global_address ( address ) 
  end
);




/* Define the orders */
create table orders ( 
  order_id              integer primary key,
  customer_id           integer not null,
  order_datetime        timestamp not null,
  delivery_address      json,
  delivery_country_code varchar2(2),
  domain address ( delivery_address ) 
    using ( delivery_country_code )
);


create table order_items ( 
  order_id       references orders, 
  coffee_pack_id references coffee_packs, 
  primary key ( order_id, coffee_pack_id ),
  grind          domain grinds_d references grinds,
  amount         number, 
  currency_code  varchar2(3 char), 
  eur_ex_rate    number,
  domain money ( amount, currency_code, eur_ex_rate )
);






/* Find the monetary values in the DB */
select table_name, column_name 
from   user_tab_cols
where  domain_name = 'MONEY'
order  by table_name, column_id;









/* (try to ) insert orders with invalid delivery addresses */
insert into orders values ( 
  1, 1, systimestamp,
  json ( '{ "street" : "1 Main Road", "town" : "Shiresville", "postCode" : "01234" } '),
  'GB'
); 
insert into orders values ( 
  2, 2, systimestamp,
  json ( '{ "street" : "1 Avenue de France", "town" : "Saint-André", "postCode" : "AA1 9ZZ" } '),
  'FR'
);


/* Correct the postal codes */
insert into orders values ( 
  1, 1, systimestamp,
  json ( '{ "street" : "1 Main Road", "town" : "Shiresville", "postCode" : "AA1 9ZZ" } '),
  'GB'
), ( 
  2, 2, systimestamp,
  json ( '{ "street" : "1 Avenue de France", "town" : "Saint-André", "postCode" : "01234" } '),
  'FR'
);





/* Add the products to order 1 */
insert into order_items values ( 
  1, 1, grinds_d.wholebean, 4.95, 'GBP', 1.20 
), ( 
  1, 2, grinds_d.aeropress, 5.95, 'GBP', 1.20
), ( 
  1, 3, grinds_d.aeropress, 7.45, 'GBP', 1.20 
);

/* Add the products to order 2 */
insert into order_items values ( 
  2, 1, grinds_d.wholebean, 5.95, 'EUR', 1 
), ( 
  2, 2, grinds_d.filter,    6.95, 'EUR', 1
), ( 
  2, 3, grinds_d.stovetop,  8.45, 'EUR', 1 
);


/* Check the orders */
select * from orders 
join   order_items 
using ( order_id );



/* Get the order total in EUR */
select order_id, 
       sum ( 
         domain_order ( oi.amount, oi.currency_code, oi.eur_ex_rate ) 
       )
from   orders o 
join   order_items oi
using ( order_id )
group  by order_id;


/* Count grind types needed for non-wholebean */
select domain_display ( grind ) grind_name, count (*)
from   order_items
where  grind <> grinds_d.wholebean
group  by grind_name;





/* Add virtual columns for domain functions */
alter table order_items add (
  eur_amount as ( 
    domain_order ( amount, currency_code, eur_ex_rate )
  )
);
alter table order_items add (
  grind_name as ( domain_display ( grind ) )
);





select order_id, 
       sum ( eur_amount )
from   orders o 
join   order_items oi
using ( order_id )
group  by order_id;


select grind_name, count (*)
from   order_items
where  grind <> grinds_d.wholebean
group  by grind_name;






