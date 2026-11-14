/*******************************************************************************
 * Script Name: Dimensions Exploration
 * Purpose:     Explore the structure of dimension tables
 *
 * SQL Functions Used: DISTINCT, ORDER BY
 ******************************************************************************/

-- Retrieve a list of unique countries, marital_status, and gender of customers
SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY country;

SELECT DISTINCT
    marital_status
FROM gold.dim_customers;

SELECT DISTINCT
    gender
FROM gold.dim_customers;

-- Explore all categories, the "major divisions"
SELECT DISTINCT
    category
FROM gold.dim_products;

-- Retrieve a list of unique categories and subcategories (overview of categories)
SELECT DISTINCT 
    category, 
    subcategory
FROM gold.dim_products
ORDER BY category, subcategory;

-- Retrieve a list of unique categories, subcategories, and products
SELECT DISTINCT 
    category, 
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY category, subcategory, product_name;
