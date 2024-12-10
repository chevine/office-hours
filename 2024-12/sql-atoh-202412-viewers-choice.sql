@sql-atoh-202412-setup
/*  Coffee delivery company based in EU
 - Needs to handle multiple currencies (price and payment)
 - Convert monetary values to EUR
 - Customers can select grind type
 - Delivery to multiple countries

 - Decisions
 Money - type vs columns? - relational 
 Delivery address - columns vs JSON? - json
 Grind types - lookup table vs enum? lookup
*/


create or replace type money as object (
  amount            number,
  currency_code     varchar2(3 char),
  eur_exchange_rate number,
  member function amount_in_eur return number,
  member function display_in_eur return varchar2
);
/

create or replace type body money as 
  member function amount_in_eur return number as
  begin
    return self.amount * self.eur_exchange_rate;
  end;

  member function display_in_eur return varchar2 as
  begin
    return to_char ( round ( self.amount_in_eur, 2 ) );
  end;
end;
/



/* Store the coffee types */
create table coffee_packs ( 
  coffee_pack_id integer primary key,
  blend          varchar(100) unique not null
);




/* Store the prices in different currencies for each coffee */
create table coffee_pack_prices ( 
  coffee_pack_id references coffee_packs,
/*  price          money,
  primary key ( coffee_pack_id, price.currency_code ) /**/
  price          number, 
  currency_code  varchar2(3 char), 
  eur_ex_rate    number,
  primary key ( coffee_pack_id, currency_code ) /**/
);





/* Create some coffee blends */
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
  ( 3, 7.95, 'CHF', 1.09174311 );/**/
/*  ( 1, money ( 5.95, 'EUR', 1 ) ), 
  ( 1, money ( 4.95, 'GBP', 1.20202020 ) ), 
  ( 1, money ( 5.45, 'CHF', 1.09174311 ) ),
  ( 2, money ( 6.95, 'EUR', 1 ) ), 
  ( 2, money ( 5.95, 'GBP', 1.20202020 ) ), 
  ( 2, money ( 6.45, 'CHF', 1.09174311 ) ),
  ( 3, money ( 8.45, 'EUR', 1 ) ), 
  ( 3, money ( 7.45, 'GBP', 1.20202020 ) ), 
  ( 3, money ( 7.95, 'CHF', 1.09174311 ) );/**/


/* Check the data */
select * from coffee_packs;
select * from coffee_pack_prices;



-- View the catalogue with EUR prices
select 
  price,  
  -- copp.price.amount,
  blend
from   coffee_packs copa
join   coffee_pack_prices copp
using ( coffee_pack_id )
where  currency_code = 'EUR'
order  by price; /**/
/*where  copp.price.currency_code = 'EUR'
order  by price.amount; /**/




/* Define which grinds are available */ 
/*
create domain grinds as enum ( 
  wholebean, 
  filter, 
  stovetop,
  aeropress,
  cafetiere
);
/**/


create table grinds ( 
  grind_id   integer primary key, 
  grind_name varchar2(30) not null
);

insert into grinds values 
  ( 1, 'Wholebean' ),
  ( 2, 'Filter' ),
  ( 3, 'Stovetop' ),
  ( 4, 'Aeropress' ),
  ( 5, 'Cafetiere' );
/**/



/* This works whether an enum or table! */
select * from grinds;





/* Define the orders */
create table orders ( 
  order_id              integer primary key,
  customer_id           integer not null,
  order_datetime        timestamp not null,
  delivery_address      json,
/*  address_line_1        varchar2(255),
  address_line_2        varchar2(255),
  address_line_3        varchar2(255),
  address_line_4        varchar2(255),/**/
  delivery_country_code varchar2(2) 
);





create table order_items ( 
  order_id       references orders, 
  coffee_pack_id references coffee_packs, 
  primary key ( order_id, coffee_pack_id ),
  -- grind          domain grinds,
  grind_id       references grinds,
  -- amount         money
  amount         number, 
  currency_code  varchar2(3 char), 
  eur_ex_rate    number /**/
);






/* Insert some orders */
insert into orders values ( 
  1, 1, systimestamp,
  json ( '{ "street" : "1 Main Road", "town" : "Shiresville", "postCode" : "01234" } '),
  -- '1 Main Road', 'Shiresville', null, '01234', 
  'GB'
), ( 
  2, 2, systimestamp,
  json ( '{ "street" : "1 Avenue de France", "town" : "Saint-André", "postCode" : "AA1 9ZZ" } '),
  -- '1 Avenue de France', 'Saint-André', null, 'AA1 9ZZ',
  'FR'
);





select * from orders;
/* Ooopsie, we got the postcodes the wrong way around!
   This is a problem for JSON and relational columns */






/* Add the products to order 1 */
insert into order_items values ( 
  1, 1, 
  -- grinds.wholebean,
  ( select grind_id from grinds where grind_name = 'Wholebean' ),
  -- money ( 4.95, 'GBP', 1.20 ) 
  4.95, 'GBP', 1.20 
), ( 
  1, 2, 
  -- grinds.aeropress,
  ( select grind_id from grinds where grind_name = 'Aeropress' ),
  -- money ( 5.95, 'GBP', 1.20 ) 
  5.95, 'GBP', 1.20
), ( 
  1, 3, 
  -- grinds.aeropress,
  ( select grind_id from grinds where grind_name = 'Aeropress' ),
  -- money ( 7.45, 'GBP', 1.20 ) 
  7.45, 'GBP', 1.20 
);



/* Add the products to order 2 */
insert into order_items values ( 
  2, 1, 
  -- grinds.wholebean,
  ( select grind_id from grinds where grind_name = 'Wholebean' ),
  -- money ( 5.95, 'EUR', 1 ) 
  5.95, 'EUR', 1 
), ( 
  2, 2, 
  -- grinds.filter,
  ( select grind_id from grinds where grind_name = 'Filter' ),
  -- money ( 6.95, 'EUR', 1 ) 
  6.95, 'EUR', 1
), ( 
  2, 3, 
  -- grinds.stovetop,
  ( select grind_id from grinds where grind_name = 'Stovetop' ),
  -- money ( 8.45, 'EUR', 1 ) 
  8.45, 'EUR', 1 
);

commit;




/* Check the orders */
select * from orders 
join   order_items 
using ( order_id );




/* Get the order total in EUR */
select order_id, 
      --  sum ( oi.amount.amount_in_eur() ) total
       sum ( oi.amount * oi.eur_ex_rate ) total
from   orders o 
join   order_items oi
using ( order_id )
group  by order_id;






/* Count grind types needed for non-wholebean */







/* Using an enum */
select domain_display ( grind ) grind_name, count (*)
from   order_items
where  grind <> grinds.wholebean
group  by grind_name;

/* Using a lookup table */
select grind_name, count (*)
from   order_items
join   grinds 
using ( grind_id )
where  grind_name <> 'wholebean' collate binary_ci
group  by grind_name;


/**********************************


               FIN


**********************************/