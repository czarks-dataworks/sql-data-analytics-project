/*******************************************************************************
 * Script Name: Change-Over-Time Analysis
 * Purpose:
 *              - Track trends, growth, and changes in key metrics over time.
 *              - For time-series analysis and identifying seasonality.
 *              - Measure growth or decline over specific periods.
 *
 * SQL Functions Used: 
 *              - Date Functions: YEAR(), MONTH(), DATETRUNC(), DATEADD(), FORMAT()
 *              - Aggregate Functions: SUM(), COUNT(),
 *              - Window Function: RANK() OVER ()
 ******************************************************************************/

-- Analyze sales performance over time
-- Quick Date Functions

-- Changes over Years
SELECT
    YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
GROUP BY YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
ORDER BY order_year;

-- >> Observation 7.1 [Growth]: Growth was uneven, not steady. Sales fell in
--    2012 and then more than doubled in 2013.
--    Evidence: total_sales was 7,075,088 (2011), 5,842,231 (2012) and
--    16,349,870 (2013).
--    Implication: Overall performance depends heavily on 2013, whose sales
--    are more than double those of each earlier year.
--
-- >> Observation 7.2 [Customer]: Customers and orders grew every year from
--    2011, including 2012, the year sales fell.
--    Evidence: total_customers was 2,216 (2011), 3,255 (2012) and 17,429
--    (2013). total_orders was 2,216, 3,269 and 21,289. Sales fell from
--    7,075,088 to 5,842,231 in 2012.
--    Implication: On average, each customer and each order brought in less
--    revenue in 2012 than in 2011, so the 2012 decline came from lower
--    revenue per customer, not from losing customers.

-- Changes over Years per Product Category
SELECT
    YEAR(COALESCE(f.order_date, DATEADD(DAY, -7, f.shipping_date))) AS order_year,
    p.category,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
GROUP BY YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))), p.category
ORDER BY p.category, order_year;

-- >> Observation 7.3 [Product]: Bikes were the only category with sales from
--    2010 to 2011, and they remain the dominant revenue source after the
--    other categories begin to have sales.
--    Evidence: Only Bikes have rows for 2010 and 2011. Accessories (2,146)
--    and Clothing (642) first appear in 2012. In 2013, Bikes total
--    15,358,322 against 667,784 for Accessories and 323,764 for Clothing.
--    Implication: The business sold only one category until 2012, and
--    revenue stays heavily concentrated in Bikes afterwards.
--
-- >> Observation 7.3.1 [Data Quality]: Bikes have sales before their
--    recorded start date.
--    Evidence: In script 02, the earliest Bikes start_date is July 1, 2011
--    (category-start years: Components-2003, Bikes-2011, Clothing-2011,
--    Accessories-2012). Yet Bikes have sales on Dec 29-31, 2010, and sales
--    in 2011 begin on January 1 (see Observation 3.2), six months before
--    that date.
--    Implication: Either the sales records are overstated or start_date does
--    not mark when a product was launched or first sold. Bike figures before
--    July 2011 should be treated with caution. This affects the 2010 total and
--    the first half of 2011, the baseline year for growth comparisons.
--
-- >> Observation 7.4 [Growth]: Bike sales fell in 2012 and then more than
--    doubled in 2013.
--    Evidence: Bikes total_sales was 7,075,088 (2011), 5,839,443 (2012) and
--    15,358,322 (2013).
--    Implication: The 2012 dip came from the Bikes category itself, and the
--    2013 rebound more than recovered it.
--
-- >> Observation 7.5 [Growth]: Accessories and Clothing grew rapidly after
--    their first appearance in 2012, from very small bases.
--    Evidence: Accessories went from 2,146 (2012) to 667,784 (2013).
--    Clothing went from 642 to 323,764.
--    Implication: The new categories scaled quickly in 2013, but their
--    combined sales were still small next to Bikes.
--
-- >> Observation 7.6 [Data Coverage]: 2014 has rows for Accessories and
--    Clothing only.
--    Evidence: 2014 shows Accessories at 30,332 and Clothing at 15,310,
--    with no Bikes row.
--    Implication: 2014 is not comparable with earlier years. Avoid
--    year-over-year conclusions for it from this result.

-- Changes over Months
SELECT
    MONTH(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity,
    RANK() OVER (ORDER BY SUM(sales_amount) DESC) AS sales_rank
FROM gold.fact_sales
WHERE YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
    NOT IN (2010, 2014)
GROUP BY MONTH(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
ORDER BY order_month;

-- >> Observation 7.7 [Seasonality]: Pooled across 2011-2013, December is the
--    highest sales month and February the lowest. 2010 and 2014 were excluded
--    as these records do not include full years (see Observation 3.2 in the
--    script 03_date_range_exploration.sql).
--    Evidence: December total_sales is 3,167,977 (rank 1) and February is
--    1,744,517 (rank 12). November, June and October rank 2nd to 4th.
--    March, January and February rank 10th to 12th.
--    Implication: Pooled demand is strongest in Q4 and June and weakest in
--    Q1. See the per-year ranking below to check whether this holds in
--    each year.

-- Seasonality check: rank months within each full year
WITH monthly AS (
    SELECT
        YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) AS order_year,
        MONTH(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) AS order_month,
        SUM(sales_amount) AS total_sales
    FROM gold.fact_sales
    WHERE YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) BETWEEN 2011 AND 2013
    GROUP BY
        YEAR(COALESCE(order_date, DATEADD(DAY, -7, shipping_date))),
        MONTH(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
)
SELECT
    order_year,
    order_month,
    total_sales,
    RANK() OVER (PARTITION BY order_year ORDER BY total_sales DESC) AS sales_rank_in_year
FROM monthly
ORDER BY order_year, order_month;

-- >> Observation 7.8 [Seasonality]: The December peak and the February low
--    are consistent in most years, but not in all.
--    Evidence: December ranked 1st in 2012 and 2013 and 3rd in 2011 (June was
--    the peak that year). February ranked 12th in 2011 and 2013 but 6th in
--    2012, when May was the lowest month (358,866). June ranked 1st, 2nd and
--    4th across the three years.
--    Implication: December strength and a January-February slowdown are a
--    likely pattern, with only three years of data to support it. Pooled totals
--    are weighted toward 2013, the largest year, and sales grew within 2013 
--    (see Observation 7.10), so growth may account for part of the pattern.

-- DATETRUNC(): Year and month combined in one column.
SELECT
    DATETRUNC(month, COALESCE(order_date, DATEADD(DAY, -7, shipping_date))) 
        AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
GROUP BY
    DATETRUNC(month, COALESCE(order_date, DATEADD(DAY, -7, shipping_date)))
ORDER BY order_date;

-- FORMAT(): To make the order_date more reader-friendly
SELECT
    FORMAT(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)), 'yyyy-MMM')
        AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
GROUP BY
    DATETRUNC(MONTH, COALESCE(order_date, DATEADD(DAY, -7, shipping_date))),
    FORMAT(COALESCE(order_date, DATEADD(DAY, -7, shipping_date)), 'yyyy-MMM')
ORDER BY DATETRUNC(MONTH, COALESCE(order_date, DATEADD(DAY, -7, shipping_date)));
-- Without this ORDER BY, the order_date will be sorted alphabetically,
-- i.e. 2011-Apr and 2011-Aug will come before 2011-Jan.

-- >> Observation 7.9 [Data Coverage]: Only 2011, 2012 and 2013 have rows for
--    all twelve months.
--    Evidence: 2010 shows a single row (December: total_sales 43,419) and
--    2014 shows a single row (January: total_sales 45,642).
--    Implication: Year-over-year and seasonality comparisons should use
--    2011-2013 only, which is why the monthly queries above exclude 2010
--    and 2014.
--
-- >> Observation 7.10 [Growth]: Sales in every month of 2013 were higher than
--    in the same month of 2012.
--    Evidence: January 857,758 vs 495,363; June 1,642,948 vs 555,142;
--    December 1,874,128 vs 624,454.
--    Implication: The 2013 growth was spread across the whole year, not
--    concentrated in a few months.
--
-- >> Observation 7.11 [Orders vs Sales]: From January to February 2013,
--    orders and units more than doubled while sales fell.
--    Evidence: total_orders went from 632 to 1,421 and total_quantity from
--    1,677 to 3,454, while total_sales fell from 857,758 to 771,218.
--    Implication: Order counts did not track sales in early 2013, so sales,
--    not order counts, is the better measure of growth.
