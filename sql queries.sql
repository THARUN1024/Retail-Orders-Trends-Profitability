select * from orders_data
-- 1. Get all unique cities
SELECT DISTINCT city
FROM orders_data;

-- 2. Calculate total sale and profit per order
SELECT
  "Order Id",
  SUM(quantity * unit_selling_price)          AS total_selling_price,
  ROUND(SUM(quantity * unit_profit)::numeric, 2) AS total_profit
FROM orders_data
GROUP BY "Order Id"
ORDER BY total_profit DESC;

-- 3. List Technology orders sent by Second Class, sorted by date
SELECT
  "Order Id",
  "Order Date"
FROM orders_data
WHERE category = 'Technology'
  AND ship_mode = 'Second Class'
ORDER BY "Order Date";

-- 4. Compute average order value
SELECT
  ROUND(AVG(quantity * unit_selling_price)::numeric, 2) AS average_order_value
FROM orders_data;

-- 5. Find the city with the most items sold
SELECT
  city,
  SUM(quantity) AS total_quantity
FROM orders_data
GROUP BY city
ORDER BY total_quantity DESC
LIMIT 1;

-- 6. Rank orders by quantity within each region
SELECT
  "Order Id",
  region,
  quantity AS total_quantity,
  DENSE_RANK() OVER (
    PARTITION BY region
    ORDER BY quantity DESC
  ) AS rank_in_region
FROM orders_data
ORDER BY region, rank_in_region;

-- 7. Total value for orders in Q1 (Jan–Mar)
SELECT
  "Order Id",
  SUM(quantity * unit_selling_price) AS total_value
FROM orders_data
WHERE EXTRACT(MONTH FROM "Order Date") IN (1, 2, 3)
GROUP BY "Order Id"
ORDER BY total_value DESC;

-- 8a. Top 10 products by total profit
SELECT
  product_id,
  SUM(total_profit) AS profit
FROM orders_data
GROUP BY product_id
ORDER BY profit DESC
LIMIT 10;

-- 8b. Same, using a CTE and window function
WITH profit_cte AS (
  SELECT
    product_id,
    SUM(total_profit) AS profit,
    DENSE_RANK() OVER (ORDER BY SUM(total_profit) DESC) AS rn
  FROM orders_data
  GROUP BY product_id
)
SELECT product_id, profit
FROM profit_cte
WHERE rn <= 10;

-- 9. Top 3 products by sales in each region
WITH sales_cte AS (
  SELECT
    region,
    product_id,
    SUM(quantity * unit_selling_price) AS sales,
    ROW_NUMBER() OVER (
      PARTITION BY region
      ORDER BY SUM(quantity * unit_selling_price) DESC
    ) AS rn
  FROM orders_data
  GROUP BY region, product_id
)
SELECT region, product_id, sales
FROM sales_cte
WHERE rn <= 3;

-- 10. Compare monthly sales for 2022 vs 2023
WITH monthly_sales AS (
  SELECT
    EXTRACT(YEAR FROM "Order Date")  AS year,
    EXTRACT(MONTH FROM "Order Date") AS month,
    SUM(quantity * unit_selling_price) AS sales
  FROM orders_data
  GROUP BY year, month
)
SELECT
  month,
  ROUND(SUM(CASE WHEN year = 2022 THEN sales ELSE 0 END)::numeric, 2) AS sales_2022,
  ROUND(SUM(CASE WHEN year = 2023 THEN sales ELSE 0 END)::numeric, 2) AS sales_2023
FROM monthly_sales
GROUP BY month
ORDER BY month;

-- 11. For each category, find the month with highest sales
WITH category_month AS (
  SELECT
    category,
    TO_CHAR("Order Date", 'YYYY-MM') AS month,
    SUM(quantity * unit_selling_price) AS sales,
    ROW_NUMBER() OVER (
      PARTITION BY category
      ORDER BY SUM(quantity * unit_selling_price) DESC
    ) AS rn
  FROM orders_data
  GROUP BY category, TO_CHAR("Order Date", 'YYYY-MM')
)
SELECT
  category,
  month       AS top_month,
  sales       AS total_sales
FROM category_month
WHERE rn = 1;

-- 12. Find sub-category with highest growth from 2022 to 2023
WITH subcat_sales AS (
  SELECT
    sub_category,
    EXTRACT(YEAR FROM "Order Date") AS year,
    SUM(quantity * unit_selling_price) AS sales
  FROM orders_data
  GROUP BY sub_category, year
),
growth AS (
  SELECT
    sub_category,
    COALESCE(MAX(CASE WHEN year = 2022 THEN sales END), 0) AS sales_2022,
    COALESCE(MAX(CASE WHEN year = 2023 THEN sales END), 0) AS sales_2023
  FROM subcat_sales
  GROUP BY sub_category
)
SELECT
  sub_category,
  sales_2022,
  sales_2023,
  (sales_2023 - sales_2022) AS growth_amount
FROM growth
ORDER BY growth_amount DESC
LIMIT 1;
