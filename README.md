# SQL Data Analytics Project

SQL-based analytics on a retail data warehouse (SQL Server), covering customer behavior, product performance, and sales trends. Built by following the Data With Baraa SQL course.

> 🚧 **Status: Work in progress.** Exploratory data analysis scripts are in progress.

## 💎 Objective

Develop SQL-based analytics to deliver detailed insights into:
- 🧑🏻‍🦱 Customer Behavior
- 🚲 Product Performance
- 📈 Sales Trends

This project has **two parts:**
1. **Exploratory Data Analysis (EDA)**
2. **Advanced Analytics**

## 📂 Repository Structure

```
sql-data-analytics-project/
├── datasets/    # Source data files and database backup
├── scripts/     # SQL analysis scripts
├── LICENSE
└── README.md
```

## 📊 Example Output

**Query:** total sales by product category

```sql
SELECT
    p.category,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_sales DESC;
```

**Result:**

| category    | total_sales |
|-------------|-------------|
| Bikes       |  28,316,272 |
| Accessories |     700,262 |
| Clothing    |     339,716 |

## 🚀 Getting Started

### Prerequisites

- **Database:** [SQL Server 2022 Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- **Client tool:** [SQL Server Management Studio (SSMS)](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)

### Setup

1. **Clone the repository:**
   ```
   git clone https://github.com/czarks-dataworks/sql-data-analytics-project.git
   cd sql-data-analytics-project
   ```
2. **Restore the database:**

    a. Copy `DataWarehouse.bak` from the `datasets/` folder to your SQL Server backup location, typically `C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup`.
    
    b. In SSMS, right-click `Databases` → `Restore Database...`
    
    c. Under Source, select `Device` → Click `...` → `Add` → Pick the `.bak` file → Click `OK` twice.

     > ⚠️ **Notice:** If you already have the `DataWarehouse` database from the SQL Data Warehouse Project, skip this step.

3. **Run the scripts** in the `scripts/` folder against the `DataWarehouse` database.

## 🙌 Credits

[![Built with Data With Baraa](https://img.shields.io/badge/Built_with-Data_With_Baraa-F5B301?style=for-the-badge)](https://github.com/DataWithBaraa/sql-data-analytics-project)

This project follows the guided [SQL Data Analytics Project](https://github.com/DataWithBaraa/sql-data-analytics-project) from the Data With Baraa SQL course, which provides the datasets and overall design.

## 📜 License

Licensed under the [MIT License](LICENSE). The original copyright notice from the source project is retained alongside mine.

## 👨‍💻 About Me

I am **Czarks**, an analytics professional with over a decade of experience using organizational data to understand and solve operational problems in banking and government. I am expanding my toolkit to include modern data tools such as SQL, and I am targeting BI and analytics engineering roles.

- **GitHub:** [@czarks-dataworks](https://github.com/czarks-dataworks)
- **LinkedIn:** [Czarina Besares](https://www.linkedin.com/in/czarinabesares/)
