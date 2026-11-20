/*******************************************************************************
 * Script Name: Date Range Exploration
 * Purpose:     Identify temporal boundaries and historical span of key metrics
 *
 * SQL Functions Used:
 *              - Date Functions: YEAR(), MONTH(), DAY(), DATEDIFF(), GETDATE(),
 *                                DATEFROMPARTS()
 *              - Aggregate Functions: MIN(), MAX()
 *              - Window Functions: MIN() OVER (), MAX() OVER ()
 *              - Other: CAST(), CTE (WITH)
 *
 * NULL order_date Treatment (applies to all scripts in this project):
 *              - 19 rows in gold.fact_sales have a NULL order_date.
 *              - These rows are assigned order_date = shipping_date - 7.
 *              - The supporting checks are in the follow-up section below.
 ******************************************************************************/

-- Determine the first and last order date and the total duration in months

-- Overall range
SELECT 
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;

-- >> Observation 3.1 [Data Coverage]: Orders span a little over three years.
--    Evidence: first_order_date is 2010-12-29 and last_order_date is
--    2014-01-28, with an order_range_months of 37.
--    Implication: The business has about three years of order history.
--    Note that DATEDIFF counts month boundaries crossed, not full months.

-- Range per year
SELECT
    YEAR(order_date) AS order_year,
    MIN(order_date) AS first_order,
    MAX(order_date) AS last_order,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) + 1 AS months_covered
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- >> Observation 3.2 [Data Coverage]: Only 2011, 2012 and 2013 are full
--    years. 2010 and 2014 are partial and must not be compared with them.
--    Evidence: 2011 to 2013 each run from January 1 to December 31
--    (12 months covered). 2010 holds only Dec 29-31 and 2014 only Jan 1-28
--    (1 month covered each).
--    Implication: Trend and growth statements should use 2011-2013 only.
--    January 2014 is itself an incomplete month.

-- Find the youngest and oldest customer based on birthdate
-- Age = completed years as of the run date. DATEDIFF(YEAR) alone counts year
-- boundaries crossed and overstates age by 1 until the birthday has passed.

WITH relevant_dates_1 AS (
SELECT
    MIN(birthdate) AS oldest_birthdate,
    MAX(birthdate) AS youngest_birthdate,
    CAST(GETDATE() AS DATE) AS date_today
FROM gold.dim_customers
)
, relevant_dates_2 AS (
SELECT
    oldest_birthdate,
    CASE
-- The next 4 lines handle Feb. 29 birthdates if year today is not a leap year
        WHEN MONTH(oldest_birthdate) = 2 AND DAY(oldest_birthdate) = 29
            AND NOT ((YEAR(date_today) % 4 = 0 AND YEAR(date_today) % 100 <> 0)
            OR YEAR(date_today) % 400 = 0)
        THEN DATEFROMPARTS(YEAR(date_today), 3, 1)
        ELSE DATEFROMPARTS(YEAR(date_today), MONTH(oldest_birthdate), 
        DAY(oldest_birthdate))
    END AS ob_this_year,
    youngest_birthdate,
    CASE
-- The next 4 lines handle Feb. 29 birthdates if year today is not a leap year
        WHEN MONTH(youngest_birthdate) = 2 AND DAY(youngest_birthdate) = 29
            AND NOT ((YEAR(date_today) % 4 = 0 AND YEAR(date_today) % 100 <> 0)
            OR YEAR(date_today) % 400 = 0)
        THEN DATEFROMPARTS(YEAR(date_today), 3, 1)
        ELSE DATEFROMPARTS(YEAR(date_today), MONTH(youngest_birthdate), 
        DAY(youngest_birthdate))
    END AS yb_this_year,
    date_today
FROM relevant_dates_1
)
SELECT
    oldest_birthdate,
    DATEDIFF(YEAR, oldest_birthdate, date_today) -
        CASE WHEN ob_this_year > date_today THEN 1
        ELSE 0 END oldest_age,
    youngest_birthdate,
    DATEDIFF(YEAR, youngest_birthdate, date_today) -
        CASE WHEN yb_this_year > date_today THEN 1
        ELSE 0 END youngest_age
FROM relevant_dates_2;

-- >> Observation 3.3 [Customer]: The oldest customer is over 100 years old.
--    Evidence: oldest_birthdate is 1916-02-10 and youngest_birthdate is
--    1986-06-25. oldest_age is above 100 as of the run date.
--    Implication: An age above 100 is unlikely for an active customer, so
--    the oldest birthdate should be treated with caution in any age-based
--    analysis. Ages change with the run date; birthdates do not.

-- Find the order, shipping, and due dates with null values
SELECT * 
FROM gold.fact_sales
WHERE order_date IS NULL OR shipping_date IS NULL OR due_date IS NULL;

-- >> Observation 3.4 [Data Quality]: 19 rows have a NULL order_date, and all
--    of them have shipping and due dates.
--    Evidence: The query returns 19 rows. Every row has a NULL order_date
--    and none has a NULL shipping_date or due_date.
--    Implication: The shipping date can be used to recover the missing order
--    date, provided the gap between the two dates is predictable (see below).

-- Follow up: Explore possible valid values for NULL order_date values.

-- 1. For orders with order dates, check the range of days from order to
--    shipping, i.e., days-to-ship.
SELECT
    order_number,
    order_date,
    shipping_date,
    DATEDIFF(DAY, order_date, shipping_date) AS days_to_ship,
    MIN(DATEDIFF(DAY, order_date, shipping_date)) OVER() AS fastest_shipping,
    MAX(DATEDIFF(DAY, order_date, shipping_date)) OVER() AS slowest_shipping
FROM gold.fact_sales
WHERE order_date IS NOT NULL;

-- >> Observation 3.5 [Data Quality]: Every order with an order date has the
--    same days-to-ship.
--    Evidence: fastest_shipping and slowest_shipping are both 7, so
--    days_to_ship is 7 in every row with an order date.
--    Implication: A fixed 7-day gap between order and shipping holds without
--    exception, which supports deriving a missing order_date from
--    shipping_date.

-- 2. Check if orders with a NULL order_date also have rows with
--    a non-null order_date.
WITH orders_with_null_date AS (
    SELECT DISTINCT
        order_number,
        order_date,
        shipping_date
    FROM gold.fact_sales
    WHERE order_date IS NULL
),
matching_non_null_dates AS (
    SELECT DISTINCT
        order_number,
        order_date,
        shipping_date
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
      AND order_number IN (SELECT order_number FROM orders_with_null_date)
)
SELECT
    n.order_number AS null_od_order_number,
    m.order_number AS matching_order_number,
    MAX(m.order_date) AS matching_order_date,
    MAX(n.shipping_date) AS null_od_shipping_date,
    DATEDIFF(DAY, MAX(m.order_date), MAX(n.shipping_date)) AS days_to_ship
FROM orders_with_null_date n
LEFT JOIN matching_non_null_dates m
    ON n.order_number = m.order_number
GROUP BY
    n.order_number,
    m.order_number
ORDER BY n.order_number;

-- >> Observation 3.6 [Data Quality]: Most orders with a NULL order_date have
--    other rows that confirm the 7-day gap.
--    Evidence: 15 distinct orders have at least one row with a NULL
--    order_date. 13 of them also have rows with an order_date, and
--    days_to_ship is 7 for each. The other 2 (SO64339 and SO65340) have no
--    dated rows.
--    Implication: For 13 of 15 orders, the order's own dated rows support
--    the 7-day rule. For the remaining 2 orders (3 rows), the rule is an
--    assumption based on the pattern in 3.5.

-- >> Action: From this point on, the 19 rows with a NULL order_date are
--            assigned the value shipping_date - 7 in all scripts, using:
--            COALESCE(order_date, DATEADD(DAY, -7, shipping_date))
