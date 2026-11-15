
-- Practice Drills D1–D10 
-- SokoMart Kenya Advanced SQL Project

set search_path to sokomart;

-- D1. Products above overall average unit_price - top 10 

select product_id, product_name, category, unit_price,
       (select AVG(unit_price) from products) as overall_avg_price
from products
where unit_price > (select AVG(unit_price) from products)
order by unit_price desc
limit 10;

select COUNT(*) AS products_above_average
from products
where unit_price > (select AVG(unit_price) from products);

-- D2. List customers living in Mombasa who placed at least one order (any status) in December 2025.

select customer_id, first_name, last_name, email
from customers
where county = 'Mombasa' and customer_id in (
select distinct customer_id
from orders
where order_date >= '2025-12-01' and order_date < '2026-01-01'
  )
order by customer_id;


-- D3. How many customers living in Kisumu have at least one payment with payment_status = 'failed'?
select COUNT(*) as kisumu_failed_payment
from customers c
where c.county = 'Kisumu'
and exists  (
select 1
from orders o
join payments p on p.order_id = o.order_id
where o.customer_id = c.customer_id and p.payment_status = 'failed');

-- D4. For each order_status, show the number of orders, the average number of lines per order and the average number of units per order. 
-- Compute the per-order figures in a subquery in FROM.

select o.order_status, COUNT(*) as orders, ROUND(AVG(ol.lines_per_order), 2) as average_lines_per_order,
ROUND(AVG(ol.units_per_order), 2) as average_units_per_order
from orders o
join (SELECT order_id, COUNT(*) as lines_per_order, SUM(quantity) as units_per_order
    from order_items
    group by  order_id
) ol  on  ol.order_id = o.order_id
group by o.order_status
order by o.order_status;

-- D5. Top 5 shipping counties by number of completed orders in 2026. Put the filtered orders in a CTE.
with completed_orders_2026 as (
    select shipping_county, order_id
    from orders
    where order_status = 'completed' and order_date >= '2026-01-01' and order_date < '2027-01-01'
)
select shipping_county, COUNT(*) as completed_orders
from completed_orders_2026 
group by shipping_county
order by completed_orders desc
limit 5;

-- D6. For 2025: completed orders per month, the 2025 monthly average, and whether each month is above average or at/below average. 
-- Use two CTEs (monthly counts, then the stats).
with monthly as (
    select DATE_TRUNC('month', order_date)::date as month, COUNT(*) as completed_orders
    from orders
    where order_status = 'completed' and order_date >= '2025-01-01' and order_date < '2026-01-01'
    group by  DATE_TRUNC('month', order_date)
),
stats as (
    select AVG(completed_orders) as average_per_month
    from monthly
)
select TO_CHAR(m.month, 'YYYY-MM') as month, m.completed_orders, ROUND(s.average_per_month, 2) AS average_per_month,
   case when m.completed_orders > s.average_per_month  then 'above average'
            else 'at/below average' end as rank_average
from monthly m
cross join stats s
order by m.month;

-- D7. Write sokomart.fn_order_count(p_customer_id INTEGER) 
-- RETURNS INTEGER — the number of orders (any status) a customer has. 
-- Call it for customer 177 and for a customer that does not exist (-1).
create or replace function sokomart.fn_order_count(p_customer_id int)
returns integer
language sql
stable
as $$
    select COUNT(*)::integer
    from sokomart.orders
    where customer_id = p_customer_id;
$$;

select sokomart.fn_order_count(177) AS orders_for_177;
select sokomart.fn_order_count(-1) AS orders_for_nonexistent;


-- D8. Write sokomart.sp_set_customer_status(p_customer_id INTEGER, p_status VARCHAR). 
-- It raises an exception for a status other than active / inactive / suspended, and for a customer that does not exist. 
-- Inside BEGIN … ROLLBACK, set customer 177 to suspended, show it, roll back, show it is active again. 
-- Then show the exception for status 'vip'.
create or replace procedure sokomart.sp_set_customer_status(
    p_customer_id int,
    p_status varchar
)
language plpgsql
as $$
begin
    if p_status not in  ('active', 'inactive', 'suspended') then
        raise exception 'Invalid status: %. Allowed: active, inactive, suspended', p_status;
    end if;
    if not exists (select 1 from sokomart.customers where customer_id = p_customer_id) then
        raise exception 'Customer % does not exist', p_customer_id;
    end if;
    update sokomart.customers
    set customer_status = p_status
    where customer_id = p_customer_id;
end;
$$;

-- Rollback
begin;
call sokomart.sp_set_customer_status(177, 'suspended');
select customer_id, customer_status from sokomart.customers where customer_id = 177;
rollback;
select customer_id, customer_status from sokomart.customers where customer_id = 177;


-- D9. Beauty products whose stock_quantity is below the average Beauty stock. 
-- Put the Beauty products in a CTE and compare with a scalar subquery on that CTE.
with beauty_products as (
    select product_id, product_name, stock_quantity
    from products
    where category = 'Beauty'
)
select  product_id, product_name, stock_quantity, (select AVG(stock_quantity) from beauty_products ) as beauty_average_stock
from beauty_products
where stock_quantity < (select AVG(stock_quantity) from beauty_products )
order by stock_quantity;

-- D10. Write sokomart.sp_county_summary(IN p_county VARCHAR, OUT p_customers INTEGER, OUT p_revenue NUMERIC) 
-- returning the number of customers living in the county and their completed revenue. 
-- CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);
create or replace procedure  sokomart.sp_county_summary(
    in p_county varchar,
    out p_customers int,
    out p_revenue numeric)
language plpgsql
as $$
begin
    select COUNT(*) into p_customers
    from customers
    where county = p_county;

    select coalesce(SUM(i.line_total), 0) into p_revenue
    from sokomart.customers c
    join sokomart.orders o on o.customer_id = c.customer_id
    join sokomart.order_items i on i.order_id = o.order_id
    where c.county = p_county and o.order_status = 'completed';
end;
$$;

call sokomart.sp_county_summary('Nakuru', NULL, NULL);
