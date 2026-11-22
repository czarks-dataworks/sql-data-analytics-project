/*******************************************************************************
 * Script Name: Data Segmentation Analysis
 * Purpose:
 *              - To group data into meaningful categories for targeted insights
 *              - For customer segmentation, product categorization,
 *                or regional analysis
 *
 * SQL Functions Used: 
 *              - CASE WHEN: Defines custom segmentation logic.
 *              - GROUP BY: Groups data into segments.
 ******************************************************************************/

/*
Segment products into cost ranges and count how many products fall into each
segment. Segments: Below 100, 100 to <500, 500 to <1000, 1000 and above.
*/

WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost >= 100 AND cost < 500 then '100 to <500'
            WHEN cost >= 500 AND cost < 1000 then '500 to <1000'
            ELSE '1000 and above'
        END AS cost_range
    FROM gold.dim_products
)
SELECT
    cost_range,
    COUNT(product_key) total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

-- Check results: The total of total_products should be equal to 295
-- -> Correct.

-- >> Observation 10.1 [Product]: Most products fall in the two lowest cost
--    ranges.
--    Evidence: total_products is 110 for Below 100 and 101 for 100 to <500,
--    against 45 for 500 to <1000 and 39 for 1000 and above.
--    Implication: The product catalog is weighted toward low-cost items,
--    and high-cost products are a minority.

/*
Group customers into three segments based on their spending behavior:
    - VIP: Customers with at least 12 months of history
           and spending more than €5,000.
	- Regular: Customers with at least 12 months of history 
           but spending €5,000 or less.
	- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

WITH customer_spending AS (
SELECT
    c.customer_key,
    MIN(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) AS first_order,
    MAX(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) AS last_order,
    DATEDIFF(MONTH, MIN(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))),
        MAX(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))) AS lifespan,
    SUM(f.sales_amount) AS total_sales
FROM gold.dim_customers c
LEFT JOIN gold.fact_sales f
        ON c.customer_key = f.customer_key
GROUP BY c.customer_key
)
, segmented_customers AS (
SELECT
    *,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'a) VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'b) Regular'
        ELSE 'c) New'
    END AS customer_segment
FROM customer_spending
)
SELECT
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM segmented_customers
GROUP BY customer_segment
ORDER BY customer_segment;

-- >> Observation 10.2 [Customer]: Most customers are in the New segment, and
--    VIPs are the smallest group.
--    Evidence: total_customers is 14,631 for c) New, 2,198 for b) Regular and
--    1,655 for a) VIP.
--    Implication: The customer base is dominated by customers with a
--    lifespan under 12 months, and only a small group meets the VIP
--    criteria.

-- Check results: The total of the three segments should be equal to the total
-- number of customers in gold.dim_customers (i.e. 18,484)
-- *if* all customers in that table have purchases -> Determine this first.

WITH sales_per_customer AS (
SELECT
    customer_key,
    SUM(sales_amount) AS total_sales
FROM gold.fact_sales
GROUP BY customer_key
)
SELECT
*
FROM gold.dim_customers c
LEFT JOIN sales_per_customer s
       ON c.customer_key = s.customer_key
-- WHERE s.customer_key IS NULL   -- To show only customers without purchases
ORDER BY c.customer_key;

-- Result: None. Therefore, all customers have purchases and the total of the
-- three segments should be 18,484 -> Correct.
