**Student:** [SAIDI KAHINDI]  
**Cohort:** LuxDevHQ Data Engineering / Data Analytics — Cohort 9  
**Date:** 15 November 2026  

## How to run

1. Load the SokoMart database following the project package steps (`03` schema → `04` data → `05` indexes).  
   This submission assumes the six core tables (`customers`, `products`, `orders`, `order_items`, `payments`, `payment_staging`) plus the supporting tables used by Section D (`product_price_history`, `audit_logs`, `order_status_history`) already exist in schema `sokomart`.

2. Run the SQL files in this order on a fresh load (or after `07_reset_database.sql` if available):

   `psql -d sokomart -f sql/00_practice_drills.sql
   psql -d sokomart -f sql/section_a_ctes_subqueries.sql
   psql -d sokomart -f sql/section_b_window_functions.sql
   psql -d sokomart -f sql/section_c_advanced_aggregation.sql
   psql -d sokomart -f sql/section_d_views_functions_procedures.sql
   psql -d sokomart -f sql/section_e_optimisation_transactions.sql`

3. Sections D and E modify data (prices, stock, order statuses, staging rows, indexes). Re-run the reset + load scripts before taking final screenshots of Sections A–C if needed.

## Results

QUESTION D1-D10  - `sql\00practicedrills.sql`

QUESTION 1 - 5 -     `sql/section_a_ctes_subqueries.sql`  with screenshots from `q1 to q5`

QUESTION 6 - 10 - `sql\section_b_window_functions.sql` with screenshots from `q6 to q10 `

QUESTION 11 - 15 - `sql\section_c_advanced_aggregation.sql` with screenshots from `q11 to q15`

# BUSINESS INSIGHTS

1. 
