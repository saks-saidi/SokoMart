
-- Section A — CTEs and subqueries (Q1–Q5)
-- SokoMart Kenya Advanced SQL Project
set search_path to sokomart;

-- Q1. Big spenders of 2025
-- Result: top customers above avg + summary counts
WITH customer_2025 AS (
    SELECT c.customer_id,
           c.first_name || ' ' || c.last_name AS full_name,
           c.county,
           COALESCE(SUM(i.line_total), 0) AS total_spent_2025
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.county
)
SELECT customer_id, full_name, county, total_spent_2025,
       (SELECT AVG(total_spent_2025) FROM customer_2025) AS avg_spent_2025,
       total_spent_2025 - (SELECT AVG(total_spent_2025) FROM customer_2025) AS amount_above_avg
FROM customer_2025
WHERE total_spent_2025 > (SELECT AVG(total_spent_2025) FROM customer_2025)
ORDER BY total_spent_2025 DESC;

-- Summary
SELECT (SELECT COUNT(*) FROM (
            SELECT c.customer_id
            FROM customers c
            JOIN orders o ON o.customer_id = c.customer_id
            WHERE o.order_status = 'completed'
              AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
            GROUP BY c.customer_id
        ) t) AS customers_who_bought_2025,
       (SELECT AVG(total_spent_2025) FROM (
            SELECT COALESCE(SUM(i.line_total), 0) AS total_spent_2025
            FROM customers c
            JOIN orders o ON o.customer_id = c.customer_id
            JOIN order_items i ON i.order_id = o.order_id
            WHERE o.order_status = 'completed'
              AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
            GROUP BY c.customer_id
        ) t) AS avg_spent_2025,
       (SELECT COUNT(*) FROM (
            WITH customer_2025 AS (
                SELECT c.customer_id, COALESCE(SUM(i.line_total), 0) AS total_spent_2025
                FROM customers c
                JOIN orders o ON o.customer_id = c.customer_id
                JOIN order_items i ON i.order_id = o.order_id
                WHERE o.order_status = 'completed'
                  AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
                GROUP BY c.customer_id
            )
            SELECT * FROM customer_2025
            WHERE total_spent_2025 > (SELECT AVG(total_spent_2025) FROM customer_2025)
        ) t) AS above_avg_count;

-- Q2. Premium-priced products (correlated subquery)
SELECT p.product_id, p.product_name, p.category, p.unit_price,
       (SELECT AVG(p2.unit_price) FROM products p2 WHERE p2.category = p.category) AS category_avg_price,
       p.unit_price - (SELECT AVG(p2.unit_price) FROM products p2 WHERE p2.category = p.category) AS price_gap
FROM products p
WHERE p.product_status = 'active'
  AND p.unit_price > (SELECT AVG(p2.unit_price) FROM products p2 WHERE p2.category = p.category)
ORDER BY p.category, price_gap DESC;

-- Counts per category
SELECT category, COUNT(*) AS premium_count
FROM (
    SELECT p.category
    FROM products p
    WHERE p.product_status = 'active'
      AND p.unit_price > (SELECT AVG(p2.unit_price) FROM products p2 WHERE p2.category = p.category)
) t
GROUP BY category
ORDER BY category;

-- Q3. 2026 monthly profit and loss (Jan–Oct) — chained CTEs
WITH order_lines AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month,
           i.line_total,
           i.quantity * p.cost_price AS line_cost
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    JOIN products p ON p.product_id = i.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2026-01-01' AND o.order_date < '2026-11-01'
),
monthly AS (
    SELECT month,
           SUM(line_total) AS revenue,
           SUM(line_cost) AS cost
    FROM order_lines
    GROUP BY month
),
with_profit AS (
    SELECT month, revenue, cost,
           revenue - cost AS gross_profit
    FROM monthly
)
SELECT TO_CHAR(month, 'YYYY-MM') AS month,
       ROUND(revenue, 2) AS revenue,
       ROUND(cost, 2) AS cost,
       ROUND(gross_profit, 2) AS gross_profit,
       ROUND(100.0 * gross_profit / NULLIF(revenue, 0), 2) AS margin_pct
FROM with_profit
ORDER BY month;

-- Q4. Cross-category shoppers in Nakuru 
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS full_name,
       c.county,
       s.category_count,
       s.total_spent
FROM customers c
JOIN (
    SELECT o.customer_id,
           COUNT(DISTINCT p.category) AS category_count,
           SUM(i.line_total) AS total_spent
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    JOIN products p ON p.product_id = i.product_id
    WHERE o.order_status = 'completed'
    GROUP BY o.customer_id
) s ON s.customer_id = c.customer_id
WHERE c.county = 'Nakuru'
  AND s.category_count >= 3
ORDER BY s.category_count DESC, s.total_spent DESC;

-- Summary
SELECT COUNT(*) AS nakuru_qualifying,
       COUNT(*) FILTER (WHERE category_count = 5) AS bought_all_five
FROM (
    SELECT o.customer_id,
           COUNT(DISTINCT p.category) AS category_count
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items i ON i.order_id = o.order_id
    JOIN products p ON p.product_id = i.product_id
    WHERE c.county = 'Nakuru'
      AND o.order_status = 'completed'
    GROUP BY o.customer_id
    HAVING COUNT(DISTINCT p.category) >= 3
) t;

-- Q5. Products nobody has ordered (NOT EXISTS)
SELECT p.product_id, p.product_name, p.category, p.product_status,
       p.stock_quantity, p.created_at
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
)
ORDER BY p.category, p.product_name;
