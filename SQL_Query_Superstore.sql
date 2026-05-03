SELECT * FROM Superstore

DROP TABLE IF EXISTS dbo.Superstore_Cleaned;

SELECT
    Row_ID,

    -- Dates are fine in the source; keep them as-is
    Order_Date,
    Ship_Date,

    -- Trim whitespace from all text columns (classic ETL move)
    LTRIM(RTRIM(Ship_Mode))     AS Ship_Mode,
    LTRIM(RTRIM(Customer_Name)) AS Customer_Name,
    LTRIM(RTRIM(Segment))       AS Segment,
    LTRIM(RTRIM(Country))       AS Country,
    LTRIM(RTRIM(City))          AS City,
    LTRIM(RTRIM(State))         AS [State],
    LTRIM(RTRIM(Region))        AS Region,
    LTRIM(RTRIM(Category))      AS Category,
    LTRIM(RTRIM(Sub_Category))  AS Sub_Category,
    LTRIM(RTRIM(Product_Name))  AS Product_Name,

    -- Round financials to 2 decimal places
    ROUND(Sales,    2) AS Sales,
    Quantity,
    ROUND(Discount, 4) AS Discount,
    ROUND(Profit,   2) AS Profit,

    -- Derived: days to ship
    DATEDIFF(DAY, Order_Date, Ship_Date) AS Days_To_Ship,

    -- Derived: profit margin % per line item (avoid divide by zero)
    CASE
        WHEN Sales = 0 THEN 0
        ELSE ROUND((Profit / Sales) * 100, 2)
    END AS Profit_Margin_Pct,

    -- Derived: revenue after discount
    ROUND(Sales * (1 - Discount), 2) AS Net_Revenue,

    -- Derived: order year and month for time intelligence in Power BI
    YEAR(Order_Date)                    AS Order_Year,
    MONTH(Order_Date)                   AS Order_Month,
    FORMAT(Order_Date, 'yyyy-MM')       AS Order_YearMonth,
    DATENAME(MONTH, Order_Date)         AS Order_Month_Name,
    DATEPART(QUARTER, Order_Date)       AS Order_Quarter,

    -- Derived: profit bucket for segmenting in visuals
    CASE
        WHEN Profit > 0  THEN 'Profitable'
        WHEN Profit = 0  THEN 'Break Even'
        ELSE             'Loss'
    END AS Profit_Status,

    -- Derived: discount tier
    CASE
        WHEN Discount = 0            THEN 'No Discount'
        WHEN Discount <= 0.10        THEN 'Low (1-10%)'
        WHEN Discount <= 0.30        THEN 'Medium (11-30%)'
        ELSE                              'High (31%+)'
    END AS Discount_Tier

INTO dbo.Superstore_Cleaned
FROM dbo.Superstore
WHERE
    -- Drop rows with NULL in columns we can't work without
    Order_Date    IS NOT NULL
    AND Sales     IS NOT NULL
    AND Quantity  IS NOT NULL;

-- Quick check after cleaning
SELECT COUNT(*) AS cleaned_rows FROM dbo.Superstore_Cleaned;

SELECT  * FROM dbo.Superstore_Cleaned;

DROP TABLE IF EXISTS dbo.DIM_Customer;

SELECT
    ROW_NUMBER() OVER (ORDER BY Customer_Name) AS Customer_Key,
    Customer_Name,
    Segment
INTO dbo.DIM_Customer
FROM (
    SELECT DISTINCT Customer_Name, Segment
    FROM dbo.Superstore_Cleaned
) t;



------------------------------------------------------------
-- 3b. DIM_Product
------------------------------------------------------------
DROP TABLE IF EXISTS dbo.DIM_Product;

SELECT
    ROW_NUMBER() OVER (ORDER BY Product_Name) AS Product_Key,
    Product_Name,
    Category,
    Sub_Category
INTO dbo.DIM_Product
FROM (
    SELECT DISTINCT Product_Name, Category, Sub_Category
    FROM dbo.Superstore_Cleaned
) t;

------------------------------------------------------------
-- 3c. DIM_Location
------------------------------------------------------------
DROP TABLE IF EXISTS dbo.DIM_Location;

SELECT
    ROW_NUMBER() OVER (ORDER BY Country, [State], City) AS Location_Key,
    Country,
    [State],
    City,
    Region
INTO dbo.DIM_Location
FROM (
    SELECT DISTINCT Country, [State], City, Region
    FROM dbo.Superstore_Cleaned
) t;

------------------------------------------------------------
-- 3d. DIM_Date (proper date dimension — Power BI loves this)
------------------------------------------------------------
DROP TABLE IF EXISTS dbo.DIM_Date;

WITH DateSeries AS (
    SELECT CAST('2011-01-01' AS DATE) AS [Date]
    UNION ALL
    SELECT DATEADD(DAY, 1, [Date])
    FROM DateSeries
    WHERE [Date] < '2015-12-31'
)
SELECT
    [Date]                                         AS [Date],
    FORMAT([Date], 'yyyyMMdd')                     AS Date_Key,
    YEAR([Date])                                   AS [Year],
    DATEPART(QUARTER, [Date])                      AS [Quarter],
    'Q' + CAST(DATEPART(QUARTER, [Date]) AS VARCHAR) AS Quarter_Label,
    MONTH([Date])                                  AS [Month],
    DATENAME(MONTH, [Date])                        AS Month_Name,
    FORMAT([Date], 'yyyy-MM')                      AS YearMonth,
    DATEPART(WEEK, [Date])                         AS Week_Number,
    DATEPART(WEEKDAY, [Date])                      AS Weekday_Number,
    DATENAME(WEEKDAY, [Date])                      AS Weekday_Name,
    DAY([Date])                                    AS Day_Of_Month,
    CASE WHEN DATEPART(WEEKDAY, [Date]) IN (1,7)
         THEN 'Weekend' ELSE 'Weekday'
    END                                            AS Day_Type
INTO dbo.DIM_Date
FROM DateSeries
OPTION (MAXRECURSION 10000);

------------------------------------------------------------
-- 3e. FACT_Orders (the big table everything joins to)
------------------------------------------------------------
DROP TABLE IF EXISTS dbo.FACT_Orders;

SELECT
    s.Row_ID,
    c.Customer_Key,
    p.Product_Key,
    l.Location_Key,
    s.Order_Date,
    s.Ship_Date,
    s.Ship_Mode,
    s.Days_To_Ship,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit,
    s.Net_Revenue,
    s.Profit_Margin_Pct,
    s.Profit_Status,
    s.Discount_Tier,
    s.Order_Year,
    s.Order_Month,
    s.Order_YearMonth,
    s.Order_Month_Name,
    s.Order_Quarter
INTO dbo.FACT_Orders
FROM dbo.Superstore_Cleaned    s
LEFT JOIN dbo.DIM_Customer     c ON s.Customer_Name = c.Customer_Name
                                AND s.Segment       = c.Segment
LEFT JOIN dbo.DIM_Product      p ON s.Product_Name  = p.Product_Name
LEFT JOIN dbo.DIM_Location     l ON s.City          = l.City
                                AND s.[State]        = l.[State];

-- Confirm row counts match
SELECT COUNT(*) AS fact_rows FROM dbo.FACT_Orders;


-- ============================================================
-- STEP 4 | KPI VIEWS FOR POWER BI
-- Drop these straight onto your Power BI canvas as datasets
-- ============================================================

------------------------------------------------------------
-- 4a. Executive Summary — one row, all top-line numbers
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_KPI_Summary AS
SELECT
    COUNT(DISTINCT Row_ID)       AS Total_Orders,
    COUNT(DISTINCT Customer_Key) AS Total_Customers,
    SUM(Sales)                   AS Total_Revenue,
    SUM(Net_Revenue)             AS Total_Net_Revenue,
    SUM(Profit)                  AS Total_Profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Overall_Margin_Pct,
    SUM(Quantity)                AS Units_Sold,
    AVG(Days_To_Ship)            AS Avg_Days_To_Ship
FROM dbo.FACT_Orders;
GO

------------------------------------------------------------
-- 4b. Revenue & Profit by Year and Month
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Sales_By_Month AS
SELECT
    Order_Year,
    Order_Month,
    Order_Month_Name,
    Order_YearMonth,
    SUM(Sales)       AS Total_Sales,
    SUM(Profit)      AS Total_Profit,
    SUM(Quantity)    AS Total_Units,
    COUNT(Row_ID)    AS Total_Orders,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Margin_Pct
FROM dbo.FACT_Orders
GROUP BY
    Order_Year, Order_Month, Order_Month_Name, Order_YearMonth;
GO

------------------------------------------------------------
-- 4c. Category & Sub-Category Breakdown
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Sales_By_Category AS
SELECT
    p.Category,
    p.Sub_Category,
    SUM(f.Sales)     AS Total_Sales,
    SUM(f.Profit)    AS Total_Profit,
    SUM(f.Quantity)  AS Total_Units,
    COUNT(f.Row_ID)  AS Order_Count,
    ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 2) AS Margin_Pct
FROM dbo.FACT_Orders  f
JOIN dbo.DIM_Product  p ON f.Product_Key = p.Product_Key
GROUP BY p.Category, p.Sub_Category;
GO

------------------------------------------------------------
-- 4d. Regional Performance
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Sales_By_Region AS
SELECT
    l.Region,
    l.Country,
    l.[State],
    SUM(f.Sales)     AS Total_Sales,
    SUM(f.Profit)    AS Total_Profit,
    COUNT(f.Row_ID)  AS Order_Count,
    ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 2) AS Margin_Pct
FROM dbo.FACT_Orders   f
JOIN dbo.DIM_Location  l ON f.Location_Key = l.Location_Key
GROUP BY l.Region, l.Country, l.[State];
GO

------------------------------------------------------------
-- 4e. Customer Segment Analysis
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Sales_By_Segment AS
SELECT
    c.Segment,
    COUNT(DISTINCT f.Customer_Key) AS Customer_Count,
    COUNT(f.Row_ID)                AS Order_Count,
    SUM(f.Sales)                   AS Total_Sales,
    SUM(f.Profit)                  AS Total_Profit,
    ROUND(AVG(f.Sales), 2)         AS Avg_Order_Value,
    ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 2) AS Margin_Pct
FROM dbo.FACT_Orders  f
JOIN dbo.DIM_Customer c ON f.Customer_Key = c.Customer_Key
GROUP BY c.Segment;
GO

------------------------------------------------------------
-- 4f. Top 10 Customers by Revenue
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Top_Customers AS
SELECT TOP 10
    c.Customer_Name,
    c.Segment,
    COUNT(f.Row_ID)   AS Order_Count,
    SUM(f.Sales)      AS Total_Sales,
    SUM(f.Profit)     AS Total_Profit,
    ROUND(SUM(f.Profit) / NULLIF(SUM(f.Sales), 0) * 100, 2) AS Margin_Pct
FROM dbo.FACT_Orders  f
JOIN dbo.DIM_Customer c ON f.Customer_Key = c.Customer_Key
GROUP BY c.Customer_Name, c.Segment
ORDER BY Total_Sales DESC;
GO

------------------------------------------------------------
-- 4g. Shipping Mode Performance
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Shipping_Analysis AS
SELECT
    Ship_Mode,
    COUNT(Row_ID)          AS Order_Count,
    AVG(Days_To_Ship)      AS Avg_Days_To_Ship,
    MIN(Days_To_Ship)      AS Min_Days,
    MAX(Days_To_Ship)      AS Max_Days,
    SUM(Sales)             AS Total_Sales,
    SUM(Profit)            AS Total_Profit
FROM dbo.FACT_Orders
GROUP BY Ship_Mode;
GO

------------------------------------------------------------
-- 4h. Discount Impact Analysis
--     Key question: does discounting actually help?
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_Discount_Impact AS
SELECT
    Discount_Tier,
    COUNT(Row_ID)                AS Order_Count,
    SUM(Sales)                   AS Total_Sales,
    SUM(Profit)                  AS Total_Profit,
    ROUND(AVG(Discount) * 100, 1) AS Avg_Discount_Pct,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS Margin_Pct,
    SUM(CASE WHEN Profit < 0 THEN 1 ELSE 0 END) AS Loss_Transactions
FROM dbo.FACT_Orders
GROUP BY Discount_Tier;
GO

------------------------------------------------------------
-- 4i. Year-over-Year Comparison
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_YoY_Comparison AS
SELECT
    Order_Year,
    SUM(Sales)                  AS Total_Sales,
    SUM(Profit)                 AS Total_Profit,
    SUM(Quantity)               AS Total_Units,
    COUNT(Row_ID)               AS Total_Orders,
    LAG(SUM(Sales))  OVER (ORDER BY Order_Year) AS Prev_Year_Sales,
    LAG(SUM(Profit)) OVER (ORDER BY Order_Year) AS Prev_Year_Profit,
    ROUND(
        (SUM(Sales) - LAG(SUM(Sales)) OVER (ORDER BY Order_Year))
        / NULLIF(LAG(SUM(Sales)) OVER (ORDER BY Order_Year), 0) * 100,
    2) AS Sales_Growth_Pct
FROM dbo.FACT_Orders
GROUP BY Order_Year;
GO


-- ============================================================
-- STEP 5 | QUICK SANITY CHECKS
-- Run these to make sure everything looks right
-- ============================================================

SELECT * FROM dbo.vw_KPI_Summary;
SELECT * FROM dbo.vw_Sales_By_Month    ORDER BY Order_YearMonth;
SELECT * FROM dbo.vw_Sales_By_Category ORDER BY Total_Sales DESC;
SELECT * FROM dbo.vw_Sales_By_Region   ORDER BY Total_Sales DESC;
SELECT * FROM dbo.vw_Sales_By_Segment;
SELECT * FROM dbo.vw_Top_Customers;
SELECT * FROM dbo.vw_Shipping_Analysis;
SELECT * FROM dbo.vw_Discount_Impact;
SELECT * FROM dbo.vw_YoY_Comparison;


-- ============================================================
-- POWER BI CONNECTION NOTES
-- ============================================================
-- 1. Use Import mode for better performance on this dataset size
-- 2. Connect directly to the views — don't pull from raw tables
-- 3. Recommended relationships in Power BI:
--      FACT_Orders[Customer_Key] -> DIM_Customer[Customer_Key]
--      FACT_Orders[Product_Key]  -> DIM_Product[Product_Key]
--      FACT_Orders[Location_Key] -> DIM_Location[Location_Key]
--      FACT_Orders[Order_Date]   -> DIM_Date[Date]
-- 4. Mark DIM_Date as your official Date Table in Power BI
--    (Model view > right-click > Mark as date table)
-- ============================================================
