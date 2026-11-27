/*==============================================================================
  Script Name:	Product Report
  Purpose:		Consolidates key product metrics and behaviors
 
  Highlights:
    1. Gathers essential fields such as product name, category, subcategory,
       and cost.
    2. Segments products by revenue:
       - High-Performer: total sales > 50,000
       - Mid-Range: total sales 10,000 to 50,000
       - Low-Performer: total sales < 10,000
    3. Aggregates product-level metrics:
       - Total orders
       - Total sales
       - Total quantity sold
       - Total customers (unique)
	   - Lifespan (in months; DATEDIFF counts month boundaries crossed,
	     not full months)
    4. Calculates valuable KPIs:
       - Recency (months since last sale)
       - Average order revenue (AOR)
       - Average monthly revenue
==============================================================================*/

--------------------------------------------------------------------------------
-- Create Report: gold.report_products
--------------------------------------------------------------------------------
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

WITH base_query AS (
--------------------------------------------------------------------------------
-- 1. Base Query: Retrieves core columns from fact_sales and dim_products
--------------------------------------------------------------------------------
    SELECT
	    f.order_number,
        COALESCE(order_date, DATEADD(DAY, -7, shipping_date)) AS order_date,
		f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
),
product_aggregations AS (
--------------------------------------------------------------------------------
-- 2. Product Aggregations: Summarizes key metrics at the product level
--------------------------------------------------------------------------------
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
    MAX(order_date) AS last_sale_date,
    COUNT(DISTINCT order_number) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customers,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity,
	CAST(AVG(1.0 * sales_amount / NULLIF(quantity, 0)) AS DECIMAL(18, 2))
        AS avg_selling_price
FROM base_query
GROUP BY
    product_key,
    product_name,
    category,
    subcategory,
    cost
)
--------------------------------------------------------------------------------
-- 3. Final Query: Combines all of the above information into one output
--------------------------------------------------------------------------------
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, CAST(GETDATE() AS DATE)) AS recency_in_months,
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue (AOR)
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE CAST(1.0 * total_sales / total_orders AS DECIMAL(18, 2))
	END AS avg_order_revenue,
	-- Average Monthly Revenue
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSE CAST(1.0 * total_sales / lifespan AS DECIMAL(18, 2))
	END AS avg_monthly_revenue
FROM product_aggregations;

-- Observations below are from SELECT * FROM gold.report_products, sorted by
-- the column named in each observation.

/*
SELECT TOP 25 *
FROM gold.report_products
ORDER BY total_sales DESC;
*/
-- >> Observation 13.1 [Product]: Mountain-200 models are the top-selling
--    products.
--    Evidence: Sorted by total_sales, the top six products are Mountain-200
--    Black- 46 (1,373,454), Black- 42 (1,363,128), Silver- 38 (1,339,394),
--    Silver- 46 (1,301,029), Black- 38 (1,294,854) and Silver- 42
--    (1,257,368). All six are High-Performers.
--    Implication: The highest-selling products all come from a single model
--    line.

/*
SELECT *
FROM gold.report_products
ORDER BY total_orders DESC;
*/
-- >> Observation 13.2 [Product]: The product with the most orders is a
--    low-revenue item.
--    Evidence: Sorted by total_orders, Water Bottle - 30 oz. is first with
--    4,244 orders and 4,249 units, but its total_sales is only 21,245.
--    Implication: High order volume does not mean high revenue. Low-priced
--    accessories raise order counts but contribute little to sales.

