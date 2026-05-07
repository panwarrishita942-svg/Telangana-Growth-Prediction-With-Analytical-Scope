create database telangana;
use telangana;
show tables; 

Select * from dim_districts;
Select * from dim_date;
Select * from fact_stamps;
Select * from fact_transport;
Select * from fact_ts_ipass;



-- 1. Top 5 Districts by Document Registration

WITH Document_Registered AS (
    SELECT district,
           SUM(documents_registered_cnt) AS Total_Document_Registered
    FROM fact_stamps
    LEFT JOIN dim_districts ON dim_districts.dist_code = fact_stamps.dist_code
    GROUP BY district
    ORDER BY Total_Document_Registered DESC
)
SELECT *
FROM (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY Total_Document_Registered DESC) AS District_rank
    FROM Document_Registered
) AS rank_table
WHERE District_rank BETWEEN 1 AND 5;

-- Analysis: This query identifies the top 5 districts with the highest number of documents registered.

-- 2. Top 5 Districts by Revenue from Document Registration (FY 2019-2022)

WITH Document_Revenue AS (
    SELECT district,
           SUM(documents_registered_rev) AS Total_Revenue,
           DENSE_RANK() OVER (ORDER BY SUM(documents_registered_rev) DESC) AS Dist_Rank
    FROM fact_stamps
    LEFT JOIN dim_districts ON dim_districts.dist_code = fact_stamps.dist_code
    GROUP BY district
)
SELECT district,
       FORMAT(Total_Revenue / 1000000000, 2) AS revenue_in_billion
FROM Document_Revenue
WHERE Dist_Rank BETWEEN 1 AND 5;

-- Analysis: This query finds the top 5 districts by revenue generated from document registration during FY 2019-2022, displaying revenue in billions.

-- 3. Total Revenue from e-Stamp Challans and Document Registrations

SELECT 
    SUM(estamps_challans_rev) AS Total_Estamps_Revenue,
    SUM(documents_registered_rev) AS Total_Documents_Revenue
FROM fact_stamps;

-- 4. Revenue and Document Registration by District

SELECT 
    dist_code,
    SUM(estamps_challans_rev) AS Total_Estamps_Revenue,
    SUM(documents_registered_rev) AS Total_Documents_Revenue
FROM fact_stamps
GROUP BY dist_code;

-- 5. Top 5 Districts by e-Stamp Challan Revenue

SELECT 
    dist_code,
    SUM(estamps_challans_rev) AS Total_Estamps_Revenue
FROM fact_stamps
GROUP BY dist_code
ORDER BY Total_Estamps_Revenue DESC
LIMIT 5;

-- 6. Vehicle Sales Trends by Month and District (Fuel-Type Specific)
WITH fuel_category AS (
    SELECT YEAR(f.month) AS yr,
           MONTHNAME(f.month) AS mnth,
           MONTH(f.month) AS mn_num,
           district,
           fuel_type_petrol,
           fuel_type_diesel,
           fuel_type_electric,
           fuel_type_others
    FROM fact_transport AS f
    LEFT JOIN dim_districts AS d ON f.dist_code = d.dist_code
)
SELECT yr,
       mnth,
       (Total_Petrol_Vehicle + Total_diesel_Vehicle + Total_electric_Vehicle + Total_Other_Vehicle) AS Total_Vehicle,
       DENSE_RANK() OVER (PARTITION BY yr ORDER BY (Total_Petrol_Vehicle + Total_diesel_Vehicle + Total_electric_Vehicle + Total_Other_Vehicle) DESC) AS sale_rank
FROM (
    SELECT mnth,
           mn_num,
           yr,
           SUM(fuel_type_petrol) AS Total_Petrol_Vehicle,
           SUM(fuel_type_diesel) AS Total_diesel_Vehicle,
           SUM(fuel_type_electric) AS Total_electric_Vehicle,
           SUM(fuel_type_others) AS Total_Other_Vehicle
    FROM fuel_category
    GROUP BY mnth, mn_num, yr
    ORDER BY mn_num
) AS a;

-- Analysis: This query explores the vehicle sales by fuel type across different months and ranks them by total vehicle sales.

-- 7.  Monthly e-Stamp Challan and Document Registration Counts

SELECT 
    SUBSTRING_INDEX(month, '/', -1) AS year,
    MONTH(SUBSTRING_INDEX(month, '/', 1)) AS month,
    SUM(estamps_challans_cnt) AS Total_Estamps_Count,
    SUM(documents_registered_cnt) AS Total_Documents_Count
FROM fact_stamps
GROUP BY year, month
ORDER BY year, month;

 
-- 8. Total e-Stamp Challan and Document Registration Revenue by Year

SELECT 
    SUBSTRING_INDEX(month, '/', -1) AS year,
    SUM(estamps_challans_rev) AS Total_Estamps_Revenue,
    SUM(documents_registered_rev) AS Total_Documents_Revenue
FROM fact_stamps
GROUP BY year
ORDER BY year;


-- 9. Districts with Non-Zero Total Investment

SELECT 
    district,
    SUM(investmentincr) AS Total_Investment
FROM fact_ts_ipass
LEFT JOIN dim_districts ON dim_districts.dist_code = fact_ts_ipass.dist_code
GROUP BY district
HAVING Total_Investment > 0;

-- Analysis: This query identifies the top 3 sectors attracting the most significant investments in each district between FY 2019 and 2022.

-- 10.  Districts with Non-Zero Document Registration Revenue

SELECT 
    dist_code,
    SUM(documents_registered_rev) AS Total_Documents_Revenue
FROM fact_stamps
WHERE documents_registered_rev > 0
GROUP BY dist_code;


-- 11.Revenue Growth Rate Year-over-Year

WITH Revenue_By_Year AS (
    SELECT 
        SUBSTRING_INDEX(month, '/', -1) AS year,
        SUM(estamps_challans_rev) AS Total_Estamps_Revenue,
        SUM(documents_registered_rev) AS Total_Documents_Revenue
    FROM fact_stamps
    GROUP BY year
)
SELECT
    current.year AS Year,
    current.Total_Estamps_Revenue AS Current_Estamps_Revenue,
    previous.Total_Estamps_Revenue AS Previous_Estamps_Revenue,
    ((current.Total_Estamps_Revenue - previous.Total_Estamps_Revenue) / NULLIF(previous.Total_Estamps_Revenue, 0) * 100) AS Estamps_Revenue_Growth_Percent,
    current.Total_Documents_Revenue AS Current_Documents_Revenue,
    previous.Total_Documents_Revenue AS Previous_Documents_Revenue,
    ((current.Total_Documents_Revenue - previous.Total_Documents_Revenue) / NULLIF(previous.Total_Documents_Revenue, 0) * 100) AS Documents_Revenue_Growth_Percent
FROM Revenue_By_Year AS current
LEFT JOIN Revenue_By_Year AS previous
ON current.year = previous.year + 1
ORDER BY current.year;


-- 12. Top Districts by Revenue and Document Registration Ratio

WITH Revenue_Ratio AS (
    SELECT 
        dist_code,
        SUM(estamps_challans_rev) AS Total_Estamps_Revenue,
        SUM(documents_registered_rev) AS Total_Documents_Revenue,
        (SUM(estamps_challans_rev) / NULLIF(SUM(documents_registered_rev), 0)) AS Revenue_Ratio
    FROM fact_stamps
    GROUP BY dist_code
)
SELECT 
    dist_code,
    Total_Estamps_Revenue,
    Total_Documents_Revenue,
    Revenue_Ratio,
    DENSE_RANK() OVER (ORDER BY Revenue_Ratio DESC) AS Rank_p
FROM Revenue_Ratio
ORDER BY Rank_p
LIMIT 5;


-- 13.  Monthly Revenue Trends

WITH Monthly_Revenue AS (
    SELECT 
        SUBSTRING_INDEX(month, '/', -1) AS year,
        MONTH(SUBSTRING_INDEX(month, '/', 1)) AS month,
        SUM(estamps_challans_rev) AS Monthly_Estamps_Revenue,
        SUM(documents_registered_rev) AS Monthly_Documents_Revenue
    FROM fact_stamps
    GROUP BY year, month
)
SELECT 
    year,
    month,
    Monthly_Estamps_Revenue,
    Monthly_Documents_Revenue,
    (Monthly_Estamps_Revenue / NULLIF(Monthly_Documents_Revenue, 0)) AS Revenue_Ratio
FROM Monthly_Revenue
ORDER BY year, month;