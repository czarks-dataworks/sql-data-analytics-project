/*******************************************************************************
 * Script Name: Cumulative Analysis
 * Purpose:
 *              - Calculate running totals or moving averages for key metrics
 *              - Track performance over time cumulatively
 *              - Useful for growth analysis or identifying long-term trends
 *
 * SQL Functions Used: 
 *              - Window Functions: SUM() OVER(), AVG() OVER()
 *              - Others: CAST(), DECIMAL(), DATETRUNC(), DATEADD(), COALESCE()
 ******************************************************************************/

-- Calculate the total sales per year and the running total of sales over time.
-- moving_average_price is the running average of the yearly average prices.
-- CAST to DECIMAL keeps the decimals if price is stored as an integer.

-- OPTION 1: Subquery
SELECT
	order_date,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
    CAST(AVG(avg_price) OVER (ORDER BY order_date) AS DECIMAL(18, 2))
        AS moving_average_price
FROM (
    SELECT 
        DATETRUNC(year, COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
            AS order_date,
        SUM(sales_amount) AS total_sales,
        AVG(CAST(price AS DECIMAL(18, 2))) AS avg_price
    FROM gold.fact_sales
    GROUP BY DATETRUNC(year, COALESCE(order_date, DATEADD(DAY, -7, 
        shipping_date)))
)t;

-- OPTION 2: One query (Returns the same results as Option 1)
SELECT 
    DATETRUNC(year, COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
        AS order_date,
    SUM(sales_amount) AS total_sales,
    SUM(SUM(sales_amount)) OVER (ORDER BY DATETRUNC(year, COALESCE(order_date, 
        DATEADD(DAY, -7, shipping_date)))) AS running_total_sales,
    CAST(AVG(AVG(CAST(price AS DECIMAL(18, 2)))) OVER (ORDER BY DATETRUNC(year, 
        COALESCE(order_date, DATEADD(DAY, -7, shipping_date))))
        AS DECIMAL(18, 2)) AS moving_average_price
FROM gold.fact_sales
GROUP BY DATETRUNC(year, COALESCE(order_date, DATEADD(DAY, -7, shipping_date)));

-- >> Observation 8.1 [Growth]: 2013 added more sales than all earlier years
--    combined.
--    Evidence: running_total_sales was 12,960,738 at the end of 2012 and
--    29,310,608 at the end of 2013. total_sales for 2013 alone was
--    16,349,870.
--    Implication: Cumulative sales are dominated by 2013. The running total
--    more than doubled in that single year.
--
-- >> Observation 8.2 [Growth]: 2010 and 2014 contribute very little to the
--    running total as these cover approximately only one month per year.
--    Evidence: total_sales was 43,419 in 2010 and 45,642 in 2014. The final
--    running_total_sales is 29,356,250.
--    Implication: Excluding these years from trend analysis is acceptable.
--
-- >> Observation 8.3 [Pricing]: The running average price falls steadily
--    after 2011.
--    Evidence: moving_average_price is about 3,101 (2010), 3,147 (2011),
--    2,671 (2012), 2,081 (2013) and 1,669 (2014).
--    Implication: Average prices per order line trended lower as sales
--    volume grew, so growth did not come from higher prices.
