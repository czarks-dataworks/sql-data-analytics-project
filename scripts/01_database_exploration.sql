/*******************************************************************************
 * Script Name: Database Exploration
 * Purpose:     Explore database structure, schemas, tables, and column metadata
 *
 * Tables Used: 
 *              - INFORMATION_SCHEMA.TABLES
 *              - INFORMATION_SCHEMA.COLUMNS
 ******************************************************************************/

-- Retrieve a list of all tables in the database
-- Will show the same result as 'SELECT * ...'
SELECT 
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES;

-- Retrieve all columns for all tables in the database
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS;

-- Retrieve all columns for each specified table
-- Five columns selected out of 23.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';

SELECT 
    TABLE_NAME,
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_products';

SELECT 
    TABLE_NAME,
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_sales';

