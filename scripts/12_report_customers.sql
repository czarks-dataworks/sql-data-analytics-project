/*==============================================================================
  Script Name:	Customer Report
  Purpose:		Consolidates key customer metrics and behaviors
 
  Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories and age groups:
	   - VIP: lifespan >= 12 months and total sales > 5,000
	   - Regular: lifespan >= 12 months and total sales <= 5,000
	   - New: lifespan < 12 months
	3. Aggregates customer-level metrics:
       - Total orders
 	   - Total sales
 	   - Total quantity purchased
 	   - Total products
	   - Lifespan (in months; DATEDIFF counts month boundaries crossed,
	     not full months)
	4. Calculates valuable KPIs:
	   - Recency (months since last order)
	   - Average order value
	   - Average monthly spend
==============================================================================*/

--------------------------------------------------------------------------------
-- Create Report: gold.report_customers
--------------------------------------------------------------------------------
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS

WITH base_query AS (
--------------------------------------------------------------------------------
-- 1. Base Query: Retrieves core columns from tables
--------------------------------------------------------------------------------
SELECT
	f.order_number,
	f.product_key,
	COALESCE(order_date, DATEADD(DAY, -7, shipping_date)) AS order_date,
	f.sales_amount,
	f.quantity,
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
	-- Age = completed years as of the run date (same rule as script 03).
	-- DATEDIFF(YEAR) alone counts year boundaries crossed, so subtract 1 if
	-- this year's birthday has not yet happened.
	DATEDIFF(YEAR, c.birthdate, CAST(GETDATE() AS DATE)) -
		CASE WHEN 
			CASE
				-- Feb. 29 birthdates: Use March 1 if the current year
				-- is not a leap year (same handling as script 03)
				WHEN MONTH(c.birthdate) = 2 AND DAY(c.birthdate) = 29
					AND NOT ((YEAR(GETDATE()) % 4 = 0
						AND YEAR(GETDATE()) % 100 <> 0)
						OR YEAR(GETDATE()) % 400 = 0)
				THEN DATEFROMPARTS(YEAR(GETDATE()), 3, 1)
				ELSE DATEFROMPARTS(YEAR(GETDATE()), MONTH(c.birthdate),
					DAY(c.birthdate))
			END > CAST(GETDATE() AS DATE)
		THEN 1
		ELSE 0 END AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
)
, customer_aggregation AS (
--------------------------------------------------------------------------------
-- 2. Customer Aggregations: Summarizes key metrics at the customer level
--------------------------------------------------------------------------------
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_products,
	MAX(order_date) AS last_order_date,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	customer_name,
	age
)
--------------------------------------------------------------------------------
-- 3. Final Query: Combines all of the above information into one output
--------------------------------------------------------------------------------
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE 
		 WHEN age IS NULL THEN 'Unknown'	-- No birthdate on record
		 WHEN age < 20 THEN 'Under 20'
		 WHEN age between 20 and 29 THEN '20-29'
		 WHEN age between 30 and 39 THEN '30-39'
		 WHEN age between 40 and 49 THEN '40-49'
		 ELSE '50 and above'
	END AS age_group,
	CASE 
		WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END AS customer_segment,
	last_order_date,
	DATEDIFF(month, last_order_date, CAST(GETDATE() AS DATE)) AS recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan,
	-- Compute average order value (AOV)
	CASE WHEN total_sales = 0 THEN 0
		 ELSE CAST(1.0 * total_sales / total_orders AS DECIMAL(18, 2))
	END AS avg_order_value,
	-- Compute average monthly spend
	CASE WHEN lifespan = 0 THEN total_sales
		 ELSE CAST(1.0 * total_sales / lifespan AS DECIMAL(18, 2))
	END AS avg_monthly_spend
FROM customer_aggregation;

-- Observations below are from SELECT * FROM gold.report_customers, sorted by
-- the column named in each observation.

/*
SELECT
	customer_number,
	customer_segment,
	lifespan,
	total_orders,
	total_sales
FROM gold.report_customers
ORDER BY total_sales DESC;
*/
-- >> Observation 12.1 [Customer]: The highest-spending customers are VIPs
--    with only a few orders.
--    Evidence: Sorted by total_sales, the top customers are AW00012132 and
--    AW00012301 (13,294 each), AW00012308 (13,268), AW00012131 (13,265) and
--    AW00012300 (13,242). Each has total_orders of 5 and falls within the
--    VIP segment.
--    Implication: Top customer spend comes from a small number of
--    high-value orders, not from frequent purchasing.

/*
SELECT
	customer_number,
	customer_segment,
	lifespan,
	total_orders,
	total_sales
FROM gold.report_customers
ORDER BY total_orders DESC, total_sales DESC;
*/
-- >> Observation 12.2 [Customer]: The most frequent buyers spend far less
--    than the top spenders.
--    Evidence: Sorted by total_orders, AW00011176 and AW00011091 have 28
--    orders each, with total_sales of 1,317 and 1,186, and AW00011185 has 27
--    orders with total_sales of 1,616. AW00011176 and AW00011185 are in the
--	  New segment (lifespan 11) and AW00011091 is Regular (lifespan 12).
--    Implication: Order frequency does not drive spend. Customer segments
--    depend on lifespan and total sales, so frequent low-spend buyers can
--    still be classified as New.
