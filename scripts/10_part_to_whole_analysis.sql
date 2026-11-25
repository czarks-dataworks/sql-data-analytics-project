/*******************************************************************************
 * Script Name: Part-to-Whole Analysis
 * Purpose:
 *              - Compare performance or metrics across dimensions
 *                or time periods
 *              - Evaluate differences between categories
 *              - Useful for A/B testing or regional comparisons
 *
 * SQL Functions Used: 
 *              - SUM(), AVG(): Aggregates values for comparison
 *              - Window Functions: SUM() OVER() for total calculations
 *              - Row functions: ROUND() and CAST() for percentage calculation
 ******************************************************************************/

-- Which categories contribute the most to overall sales?

WITH category_sales AS (
    SELECT
        p.category AS category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2), '%')
        AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;

-- >> Observation 10.1 [Product]: Bikes account for most of the sales.
--    Evidence: Bikes total_sales is 28,316,272, which is 96.46% of
--    overall_sales (29,356,250). Accessories contribute 2.39% (700,262) and
--    Clothing 1.16% (339,716).
--    Implication: Business performance is driven almost entirely by the
--    Bikes category, which makes the business dependent on a single
--    category.
--
-- >> Observation 10.2 [Product]: Accessories contribute more than twice as
--    much as Clothing.
--    Evidence: Accessories total_sales is 700,262 against 339,716 for
--    Clothing (2.39% vs 1.16% of overall_sales).
--    Implication: Within the smaller categories, Accessories is the stronger
--    contributor, but neither category materially offsets the dependence on
--    Bikes.

