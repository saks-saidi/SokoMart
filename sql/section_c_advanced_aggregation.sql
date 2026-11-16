
-- Section C — Advanced aggregation with subqueries 11–15

set search_path to sokomart;

-- 11. Customer tiers
SELECT tier,
       COUNT(*) AS customer_count,
       MIN(lifetime_revenue) AS min_spent,
       MAX(lifetime_revenue) AS max_spent,
       ROUND(AVG(lifetime_revenue), 2) AS avg_spent,
       ROUND(100.0 * SUM(lifetime_revenue) / (SELECT SUM(lifetime_revenue) FROM (
           SELECT COALESCE(SUM(i.line_total), 0) AS lifetime_revenue
           FROM customers c
           JOIN orders o ON o.customer_id = c.customer_id AND o.order_status = 'completed'
           JOIN order_items i ON i.order_id = o.order_id
           GROUP BY c.customer_id
       ) t), 2) AS revenue_share_pct
FROM (
    SELECT lifetime_revenue,
           CASE
               WHEN lifetime_revenue >= 1000000 THEN 'Platinum'
               WHEN lifetime_revenue >= 500000 THEN 'Gold'
               WHEN lifetime_revenue >= 100000 THEN 'Silver'
               ELSE 'Bronze'
           END AS tier
    FROM (
        SELECT c.customer_id,
               COALESCE(SUM(i.line_total), 0) AS lifetime_revenue
        FROM customers c
        JOIN orders o ON o.customer_id = c.customer_id AND o.order_status = 'completed'
        JOIN order_items i ON i.order_id = o.order_id
        GROUP BY c.customer_id
    ) rev
) tiers
GROUP BY tier
ORDER BY CASE tier
    WHEN 'Platinum' THEN 1
    WHEN 'Gold' THEN 2
    WHEN 'Silver' THEN 3
    WHEN 'Bronze' THEN 4
END;

-- 12. What did Mombasa buy in October? 
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS full_name,
       COUNT(DISTINCT p.product_name) AS product_count,
       STRING_AGG(DISTINCT p.product_name, '; ' ORDER BY p.product_name) AS products_ordered
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items i ON i.order_id = o.order_id
JOIN products p ON p.product_id = i.product_id
WHERE c.county = 'Mombasa'
  AND o.order_status <> 'cancelled'
  AND o.order_date >= '2026-10-01' AND o.order_date < '2026-11-01'
  AND EXISTS (
      SELECT 1 FROM orders o2
      WHERE o2.customer_id = c.customer_id
        AND o2.order_status <> 'cancelled'
        AND o2.order_date >= '2026-10-01' AND o2.order_date < '2026-11-01'
  )
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY product_count DESC, c.customer_id;


-- 13. Payment health by method, 2026
WITH payments_2026 AS (
    SELECT *
    FROM payments
    WHERE payment_date >= '2026-01-01' AND payment_date < '2027-01-01'
)
SELECT payment_method,
       COUNT(*) AS total_payments,
       COUNT(*) FILTER (WHERE payment_status = 'successful') AS successful,
       COUNT(*) FILTER (WHERE payment_status = 'failed') AS failed,
       COUNT(*) FILTER (WHERE payment_status = 'pending') AS pending,
       ROUND(100.0 * COUNT(*) FILTER (WHERE payment_status = 'successful') / COUNT(*), 2) AS success_rate_pct,
       COALESCE(SUM(amount) FILTER (WHERE payment_status = 'failed'), 0) AS failed_amount
FROM payments_2026
GROUP BY payment_method
ORDER BY total_payments DESC;

-- 14. Which departments carry the profit? (2025 above avg)
WITH cat_2025 AS (
    SELECT p.category,
           SUM(i.line_total) AS revenue,
           SUM(i.line_total) - SUM(i.quantity * p.cost_price) AS gross_profit
    FROM products p
    JOIN order_items i ON i.product_id = p.product_id
    JOIN orders o ON o.order_id = i.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
    GROUP BY p.category
)
SELECT category,
       ROUND(revenue, 2) AS revenue,
       ROUND(gross_profit, 2) AS gross_profit,
       ROUND(100.0 * gross_profit / NULLIF(revenue, 0), 2) AS margin_pct,
       ROUND((SELECT AVG(gross_profit) FROM cat_2025), 2) AS avg_category_gross_profit,
       ROUND(100.0 * (gross_profit - (SELECT AVG(gross_profit) FROM cat_2025))
             / NULLIF((SELECT AVG(gross_profit) FROM cat_2025), 0), 2) AS pct_above_avg
FROM cat_2025
WHERE gross_profit > (SELECT AVG(gross_profit) FROM cat_2025)
ORDER BY gross_profit DESC;

-- 15. One sales table with subtotals (GROUPING SETS)
WITH lines_2026 AS (
    SELECT o.shipping_county AS county,
           p.category,
           i.line_total,
           o.order_id
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    JOIN products p ON p.product_id = i.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2026-01-01' AND o.order_date < '2027-01-01'
      AND o.shipping_county IN ('Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Uasin Gishu')
)
SELECT CASE
           WHEN GROUPING(county) = 0 AND GROUPING(category) = 0 THEN 'county x category'
           WHEN GROUPING(county) = 0 AND GROUPING(category) = 1 THEN 'county total'
           WHEN GROUPING(county) = 1 AND GROUPING(category) = 0 THEN 'category total'
           ELSE 'grand total'
       END AS grouping_level,
       COALESCE(county, 'ALL COUNTIES') AS county,
       COALESCE(category, 'ALL CATEGORIES') AS category,
       ROUND(SUM(line_total), 2) AS revenue,
       COUNT(DISTINCT order_id) AS order_count
FROM lines_2026
GROUP BY GROUPING SETS (
    (county, category),
    (county),
    (category),
    ()
)
ORDER BY
    CASE WHEN GROUPING(county) = 1 AND GROUPING(category) = 1 THEN 3
         WHEN GROUPING(county) = 0 AND GROUPING(category) = 1 THEN 1
         WHEN GROUPING(county) = 1 AND GROUPING(category) = 0 THEN 2
         ELSE 0 END,
    county, category;
