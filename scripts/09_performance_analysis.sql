/*******************************************************************************
 * Script Name: Performance Analysis [Year-over-Year (YOY)]
 * Purpose:
 *              - Measure the performance of products, customers, or regions
 *                over time
 *              - For benchmarking and identifying high-performing entities
 *              - Track yearly trends and growth
 *
 * SQL Functions Used: 
 *              - LAG(): Accesses data from previous rows
 *              - AVG() OVER(): Computes average values within partitions
 *              - RANK() OVER(): Ranks rows by a metric
 *              - CASE: Defines conditional logic for trend analysis
 *              - SUM(CASE WHEN ...): Conditional aggregation to pivot years
 *                into columns
 ******************************************************************************/

/* Analyze the yearly performance of products by comparing their sales to both
the average sales performance of the product and the previous year's sales */

WITH yearly_product_sales AS (
    SELECT
        YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
            AS order_year,
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
           ON f.product_key = p.product_key
    GROUP BY
        YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))),
        p.category,
        p.product_name
)
SELECT
    order_year,
    category,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER(PARTITION BY product_name)
        AS diff_avg,
    CASE
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name)
            > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name)
            < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,
    -- Year-over-Year (YOY) Analysis
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year ASC)
        AS prev_yr_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name
        ORDER BY order_year ASC) AS diff_prev_yr,
    CASE
        -- A product's first year has no previous year to compare with
        WHEN LAG(current_sales) OVER (PARTITION BY product_name
            ORDER BY order_year ASC) IS NULL THEN 'N/A (First Year)'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name
            ORDER BY order_year ASC) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name
            ORDER BY order_year ASC) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS prev_yr_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

/* Product sales by year (2011-2013) with YOY Increase/Decrease flags:
   Uses conditional aggregation: SUM(CASE WHEN) turns each year into a column.
   A NULL in a year column means the product had no sales that year.
   Ranks are NULL for years with no sales. */

WITH yearly_sales AS (
    SELECT
        p.product_name,
        p.category,
        YEAR(COALESCE(f.order_date, DATEADD(DAY, -7, f.shipping_date))) AS order_year,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
           ON f.product_key = p.product_key
    WHERE YEAR(COALESCE(f.order_date, DATEADD(DAY, -7, f.shipping_date)))
          BETWEEN 2011 AND 2013
    GROUP BY
        p.product_name,
        p.category,
        YEAR(COALESCE(f.order_date, DATEADD(DAY, -7, f.shipping_date)))
)
, pivoted AS (
    SELECT
        product_name,
        category,
        SUM(total_sales) AS total_sales,
        SUM(CASE WHEN order_year = 2011 THEN total_sales END) AS sales_2011,
        SUM(CASE WHEN order_year = 2012 THEN total_sales END) AS sales_2012,
        SUM(CASE WHEN order_year = 2013 THEN total_sales END) AS sales_2013
    FROM yearly_sales
    GROUP BY product_name, category
)
, product_ranks_and_changes AS (
SELECT
    product_name,
    category,
    total_sales,
    sales_2011,
    sales_2012,
    sales_2013,
    CASE WHEN sales_2011 IS NULL THEN NULL
         ELSE RANK() OVER (ORDER BY sales_2011 DESC) END AS rank_2011,
    CASE WHEN sales_2012 IS NULL THEN NULL
         ELSE RANK() OVER (ORDER BY sales_2012 DESC) END AS rank_2012,
    CASE WHEN sales_2013 IS NULL THEN NULL
         ELSE RANK() OVER (ORDER BY sales_2013 DESC) END AS rank_2013,
    sales_2012 - sales_2011 AS diff_2011_to_2012,
    CASE
        WHEN sales_2011 IS NULL OR sales_2012 IS NULL THEN 'N/A'
        WHEN sales_2012 > sales_2011 THEN 'Increase'
        WHEN sales_2012 < sales_2011 THEN 'Decrease'
        ELSE 'No Change'
    END AS change_2011_to_2012,
    sales_2013 - sales_2012 AS diff_2012_to_2013,
    CASE
        WHEN sales_2012 IS NULL OR sales_2013 IS NULL THEN 'N/A'
        WHEN sales_2013 > sales_2012 THEN 'Increase'
        WHEN sales_2013 < sales_2012 THEN 'Decrease'
        ELSE 'No Change'
    END AS change_2012_to_2013
FROM pivoted
)
SELECT
*
FROM product_ranks_and_changes
-- Customize WHERE clause to show years and rankings of interest.
-- Example: To show the 5 top-selling products per year:
-- WHERE rank_2011 <= 5 OR rank_2012 <= 5 OR rank_2013 <= 5
ORDER BY total_sales DESC;

-- >> Observation 9.1 [Product]: The five Road-150 Red models (Bikes) led
--    product sales in 2011, and none of them has a row after 2011.
--    Evidence: current_sales in 2011 was 1,198,630 (Road-150 Red- 48),
--    1,195,052 (Red- 62), 1,076,978 (Red- 52), 1,051,932 (Red- 56) and
--    1,001,840 (Red- 44). These are the highest product-year values in the
--    output, and each model has rows for 2010 and 2011 only.
--    Implication: 2011 sales rested on a few high-selling models that do not
--    appear in later years.
--
-- >> Observation 9.2 [Product]: The highest product sales in 2012 were far
--    below the highest in 2011.
--    Evidence: The highest current_sales in 2012 was 423,570 (Mountain-200
--    Black- 46), followed by 392,343 (Mountain-200 Black- 42) and 388,437
--    (Road-250 Red- 48). In 2011, five products exceeded 1,000,000, and the
--    highest was 1,198,630 (Road-150 Red- 48).
--    Implication: The top-selling models of 2011 had much higher sales than
--    any model in 2012, which is consistent with the dip in total sales
--    that year.
--
-- >> Observation 9.3 [Growth]: Mountain-200 models led 2013 sales, with each
--    more than doubling its 2012 sales.
--    Evidence: Six Mountain-200 models reached 902,480 to 970,785 in 2013,
--    up from 342,921 to 423,570 in 2012 (for example, Black- 42 went from
--    392,343 to 970,785). Each of the six has a larger diff_prev_yr than any
--    other product in 2013.
--    Implication: The 2013 rebound was driven by one model line, not by
--    growth across the whole range.
--
-- >> Observation 9.4 [Product]: Accessories ramped up from very small
--    starting sales in 2012.
--    Evidence: AWC Logo Cap (Accessories) went from 72 in 2012 to 18,891 in
--    2013, and All-Purpose Bike Stand (Accessories) from 159 to 37,683.
--    Implication: New accessory products scaled quickly in 2013, though
--    their sales remain small next to the leading bike models.
--
-- >> Observation 9.5 [Product]: The Mountain-100 and Road-150 Red models have
--    sales in 2011 but none in any later year.
--    Evidence: Eight Mountain-100 models (sales_2011 from 122,400 to 202,500)
--    and five Road-150 Red models (sales_2011 from 1,001,840 to 1,198,630)
--    have NULL in sales_2012 and sales_2013. change_2011_to_2012 is 'N/A'
--    for all of them.
--    Implication: Some of the highest-selling 2011 models do not continue
--    into 2012, so the product mix changed after 2011.
--
-- >> Observation 9.6 [Growth]: Every product with sales in both 2011 and 2012
--    increased in 2012, but many started from very small 2011 values.
--    Evidence: No product shows 'Decrease' in change_2011_to_2012.
--    Examples: Road-250 Red- 48 went from 7,329 to 388,437, Mountain-200
--    Black- 46 from 2,049 to 423,570, and Road-650 Red- 52 from 14,064 to
--    31,320.
--    Implication: The 2012 dip in total sales is consistent with the
--    models that stopped selling (9.5), not with declines in continuing
--    products. The increases for continuing products often start from very
--    small 2011 sales, so they reflect new models ramping up.
--
-- >> Observation 9.7 [Growth]: Nearly every product with sales in both 2012
--    and 2013 increased, with three exceptions.
--    Evidence: change_2012_to_2013 is 'Decrease' for Road-250 Black- 52
--    (378,269 to 351,792), Road-250 Black- 58 (316,912 to 302,932) and
--    Road-250 Red- 58 (376,087 to 320,033). Every other product with sales
--    in both years shows 'Increase'.
--    Implication: The 2013 growth was broad across the product range, with
--    only these three Road-250 models declining.
--
-- >> Observation 9.8 [Product]: Six Mountain-200 models have the highest
--    total_sales.
--    Evidence: Sorted by total_sales, the top six are Mountain-200 Black- 46
--    (1,373,454), Black- 42 (1,363,128), Silver- 38 (1,339,394), Silver- 46
--    (1,301,029), Black- 38 (1,294,854) and Silver- 42 (1,257,368). All are
--    in the Bikes category.
--    Implication: The best-selling products over the period all come from
--    one model line.
--
-- >> Observation 9.9 [Product]: The top-selling products change from year to
--    year.
--    Evidence: In 2011, the Road-150 Red models hold ranks 1 to 5
--    (sales_2011 from 1,001,840 to 1,198,630). In 2012, Mountain-200
--    Black- 46 (423,570) and Black- 42 (392,343) hold ranks 1 and 2, followed
--    by Road-250 Red- 48 (388,437). In 2013, Mountain-200 models hold the
--    top six places (ranks 1, 2, 3, 3, 5 and 6), led by Black- 42 (970,785).
--    Implication: Sales leadership rotates between model lines, so
--    performance depends on whichever line is currently leading.
--
-- >> Observation 9.10 [Growth]: The Mountain-200 models rose from little or
--    no sales in 2011 to the top ranks within two years.
--    Evidence: Mountain-200 Black- 46 went from 2,049 (2011) to 423,570
--    (2012, rank 1) to 947,835 (2013, rank 3). Black- 42 has no 2011 sales,
--    then 392,343 (2012, rank 2) and 970,785 (2013, rank 1).
--    Implication: These models scaled quickly into the best sellers.
