
-- Section B — Window functions 6–10

SET search_path TO sokomart;

-- Q6. County leaderboards (DENSE_RANK top 3 per county)

WITH customer_revenue AS (
    SELECT c.customer_id,
           c.first_name || ' ' || c.last_name AS full_name,
           c.county,
           COALESCE(SUM(i.line_total), 0) AS total_spent
    FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.order_status = 'completed'
    LEFT JOIN order_items i ON i.order_id = o.order_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.county
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY county ORDER BY total_spent DESC) AS county_rank
    FROM customer_revenue
    WHERE total_spent > 0
)
SELECT county, county_rank, customer_id, full_name, total_spent
FROM ranked
WHERE county_rank <= 3
ORDER BY county, county_rank, customer_id;

-- Q7. Best sellers per category, 2025 (ROW_NUMBER top 3)
WITH product_2025 AS (
    SELECT p.category, p.product_id, p.product_name,
           SUM(i.line_total) AS revenue,
           SUM(i.quantity) AS units_sold
    FROM products p
    JOIN order_items i ON i.product_id = p.product_id
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC, product_id) AS rank_in_category
    FROM product_2025
)
SELECT category, rank_in_category, product_id, product_name, revenue, units_sold
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- Q8. Month-over-month growth - LAG
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(i.line_total) AS revenue
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-11-01'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT TO_CHAR(month, 'YYYY-MM') AS month,
       ROUND(revenue, 2) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2) AS growth_pct
FROM monthly
ORDER BY month;

-- Q9. Is each order bigger than the last? (Nyeri 2026, LAG)
WITH nyeri_orders AS (
    SELECT o.customer_id, o.order_id, o.order_date, o.total_amount,
           LAG(o.total_amount) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS previous_order_amount
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE c.county = 'Nyeri'
      AND o.order_status = 'completed'
      AND o.order_date >= '2026-01-01' AND o.order_date < '2027-01-01'
)
SELECT customer_id, order_id, order_date, total_amount,
       previous_order_amount,
       total_amount - previous_order_amount AS change_amount,
       CASE
           WHEN previous_order_amount IS NULL THEN 'first order'
           WHEN total_amount > previous_order_amount THEN 'up'
           WHEN total_amount < previous_order_amount THEN 'down'
           ELSE 'same'
       END AS direction
FROM nyeri_orders
ORDER BY customer_id, order_date;

-- Summary
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS distinct_customers,
       COUNT(*) FILTER (WHERE previous_order_amount IS NULL) AS first_orders,
       COUNT(*) FILTER (WHERE total_amount > previous_order_amount) AS orders_up,
       COUNT(*) FILTER (WHERE total_amount < previous_order_amount) AS orders_down
FROM (
    SELECT o.customer_id, o.total_amount,
           LAG(o.total_amount) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS previous_order_amount
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE c.county = 'Nyeri'
      AND o.order_status = 'completed'
      AND o.order_date >= '2026-01-01' AND o.order_date < '2027-01-01'
) t;

-- Q10. Year-to-date revenue - running totals
WITH monthly AS (
    SELECT EXTRACT(YEAR FROM o.order_date)::int AS year,
           DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(i.line_total) AS monthly_revenue
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-11-01'
    GROUP BY EXTRACT(YEAR FROM o.order_date), DATE_TRUNC('month', o.order_date)
)
SELECT year,
       TO_CHAR(month, 'YYYY-MM') AS month,
       ROUND(monthly_revenue, 2) AS monthly_revenue,
       ROUND(SUM(monthly_revenue) OVER (
           PARTITION BY year ORDER BY month
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ), 2) AS running_revenue_ytd,
       ROUND(SUM(monthly_revenue) OVER (
           ORDER BY month
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ), 2) AS running_revenue_all_time
FROM monthly
ORDER BY month;
