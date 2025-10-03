select * from assignmentData;
--step1-To check for duplicates
SELECT ENTRY_ID, SALES_REP_ID, CUSTOMER_ID, CUSTOMER_CODE, SKU_NAME,
       COUNT(*) AS duplicate_count
FROM assignmentData
GROUP BY ENTRY_ID, SALES_REP_ID, CUSTOMER_ID, CUSTOMER_CODE, SKU_NAME
HAVING COUNT(*) > 1;


WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ENTRY_ID, SALES_REP_ID, CUSTOMER_ID, CUSTOMER_CODE, SKU_NAME
               ORDER BY ENTRY_ID
           ) AS rn
    FROM assignmentData
)
DELETE FROM ranked
WHERE rn > 1;

--step2- Check for NUll values
SELECT 
    SUM(CASE WHEN ENTRY_ID IS NULL THEN 1 ELSE 0 END) AS null_entry_id,
    SUM(CASE WHEN SALES_REP_ID IS NULL THEN 1 ELSE 0 END) AS null_sales_rep_id,
    SUM(CASE WHEN CUSTOMER_CODE IS NULL THEN 1 ELSE 0 END) AS null_customer_code,
    SUM(CASE WHEN CUSTOMER_NAME IS NULL THEN 1 ELSE 0 END) AS null_customer_name,
    SUM(CASE WHEN SKU_NAME IS NULL THEN 1 ELSE 0 END) AS null_sku_name,
    SUM(CASE WHEN UNIT_SOLD IS NULL THEN 1 ELSE 0 END) AS null_unit_sold,
    SUM(CASE WHEN TOTAL_VALUE_SOLD IS NULL THEN 1 ELSE 0 END) AS null_total_value_sold,
    SUM(CASE WHEN CHECKOUT_TIME IS NULL THEN 1 ELSE 0 END) AS null_checkout_time
FROM assignmentData;

-- Replace missing CUSTOMER_NAME with 'Unknown'
UPDATE assignmentData
SET CUSTOMER_NAME = 'Unknown'
WHERE CUSTOMER_NAME IS NULL;

-- Replace missing UNIT_SOLD with 0
UPDATE assignmentData
SET UNIT_SOLD = 0
WHERE UNIT_SOLD IS NULL;
--Change the datatype of req field
UPDATE assignmentData
SET CUSTOMER_CODE = TRY_CAST(REPLACE(CUSTOMER_CODE, '.0', '') AS INT)
WHERE CUSTOMER_CODE IS NOT NULL;


UPDATE assignmentData
SET ENTRY_ID = TRY_CAST(REPLACE(ENTRY_ID, '.0', '') AS INT)
WHERE ENTRY_ID IS NOT NULL;

UPDATE assignmentData
SET SALES_REP_ID = TRY_CAST(REPLACE(SALES_REP_ID, '.0', '') AS INT)
WHERE SALES_REP_ID IS NOT NULL;


--Step4: Handle negative values
EXEC sp_help 'assignmentData';
SELECT *
FROM assignmentData
WHERE TRY_CAST(UNIT_SOLD AS FLOAT) < 0
   OR TRY_CAST(TOTAL_VALUE_SOLD AS FLOAT) < 0;
-- First, update values (remove unwanted characters, just in case)
UPDATE assignmentData
SET UNIT_SOLD = REPLACE(UNIT_SOLD, '.0', '');

UPDATE assignmentData
SET TOTAL_VALUE_SOLD = REPLACE(TOTAL_VALUE_SOLD, '.0', '');

-- Then alter column types
ALTER TABLE assignmentData
ALTER COLUMN UNIT_SOLD FLOAT;

ALTER TABLE assignmentData
ALTER COLUMN TOTAL_VALUE_SOLD FLOAT;

SELECT *
FROM assignmentData
WHERE UNIT_SOLD < 0 OR TOTAL_VALUE_SOLD < 0;

-- step5: Fixing inconsistent data formats and InvalidData
-- Standardize CUSTOMER_NAME to uppercase
UPDATE assignmentData
SET CUSTOMER_NAME = UPPER(CUSTOMER_NAME);

-- Convert CHECKIN_TIME to proper DATETIME
ALTER TABLE assignmentData
ALTER COLUMN CHECKIN_TIME DATETIME;

--Checking the datatype
-- Preview converted values
SELECT 
    CHECKIN_TIME,
    TRY_CONVERT(DATETIME, CHECKIN_TIME, 101) AS CHECKIN_CONVERTED,
    CHECKOUT_TIME,
    TRY_CONVERT(DATETIME, CHECKOUT_TIME, 101) AS CHECKOUT_CONVERTED
FROM assignmentData;

ALTER TABLE assignmentData
ALTER COLUMN CHECKIN_TIME DATETIME;

ALTER TABLE assignmentData
ALTER COLUMN CHECKOUT_TIME DATETIME;
ALTER TABLE assignmentData
ALTER COLUMN ENTRY_ID INT;

ALTER TABLE assignmentData
ALTER COLUMN SALES_REP_ID INT;

ALTER TABLE assignmentData
ALTER COLUMN CUSTOMER_ID INT;

ALTER TABLE assignmentData
ALTER COLUMN CUSTOMER_CODE INT;

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'assignmentData';   -- if table name is all lowercase in metadata

select * from assignmentData;

/*Q1- TOP 10 SKUs Analysis
1.1-Identify the top 10 most selling SKUs:
a- By Quantity Sold
b-By value sold*/
/* Q1 - TOP 10 SKUs Analysis
   1.1 - Identify the top 10 most selling SKUs:
   a) By Quantity Sold
*/
SELECT SKU_NAME, SUM(UNIT_SOLD) AS Total_Quantity_Sold
FROM assignmentData
GROUP BY SKU_NAME
ORDER BY Total_Quantity_Sold DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
--b) BY Value sold
SELECT SKU_NAME,SUM(TOTAL_VALUE_SOLD) AS Total_Value_Sold
FROM assignmentData
GROUP BY SKU_NAME
ORDER BY Total_Value_Sold DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

/*1.2-Identify the Top 10 least-selling SKUs:
a)By Quantity Sold*/
SELECT SKU_NAME, SUM(UNIT_SOLD) AS Total_Quantity_Sold
FROM assignmentData
GROUP BY SKU_NAME
ORDER BY Total_Quantity_Sold asc
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
--b)By Value Count
SELECT SKU_NAME,SUM(TOTAL_VALUE_SOLD) AS Total_Value_Sold
FROM assignmentData
GROUP BY SKU_NAME
ORDER BY Total_Value_Sold asc
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

SELECT * FROM assignmentData;
/*2-Customer Analysis
Find the top 10 customers by total value purchased*/
SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    SUM(TOTAL_VALUE_SOLD) AS total_value_purchased
FROM
    assignmentData
WHERE
    TOTAL_VALUE_SOLD IS NOT NULL
GROUP BY
    CUSTOMER_ID,
    CUSTOMER_NAME
ORDER BY
    total_value_purchased DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

/*3-Sales Representative Performance
3.1-Identify the Top 10 Sales Performance:
a)By Value sold*/
SELECT
    SALES_REP_ID,
    SALES_REP,
    SUM(TOTAL_VALUE_SOLD) AS total_value_sold
FROM
    assignmentData
WHERE
    TOTAL_VALUE_SOLD IS NOT NULL
GROUP BY
    SALES_REP_ID,
    SALES_REP
ORDER BY
    total_value_sold DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
--b)By Time spent
SELECT
    SALES_REP_ID,
    SALES_REP,
    SUM(DATEDIFF(
            MINUTE,
            TRY_CONVERT(DATETIME, CHECKIN_TIME, 101),   -- 101 = mm/dd/yyyy
            TRY_CONVERT(DATETIME, CHECKOUT_TIME, 101)
        )) AS total_minutes_spent
FROM assignmentData
WHERE
    CHECKIN_TIME IS NOT NULL
    AND CHECKOUT_TIME IS NOT NULL
GROUP BY
    SALES_REP_ID,
    SALES_REP
ORDER BY
    total_minutes_spent DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;


/*3.2. For the Top 10 Sales Representatives (by Value), calculate:
a) Day-wise Average Value sold*/
/* --- 1. Identify Top 10 Sales Reps by Total Value --- */
WITH TopValueReps AS (
    SELECT
        SALES_REP_ID,
        SALES_REP,
        SUM(TOTAL_VALUE_SOLD) AS total_value_sold
    FROM assignmentData
    WHERE TOTAL_VALUE_SOLD IS NOT NULL
    GROUP BY SALES_REP_ID, SALES_REP
    ORDER BY total_value_sold DESC
    OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY
),

/* --- 2. Compute each rep’s total value per day --- */
DailyTotals AS (
    SELECT
        SALES_REP_ID,
        SALES_REP,
        CAST(TRY_CONVERT(DATE, CHECKIN_TIME, 101) AS DATE) AS visit_date,
        SUM(TOTAL_VALUE_SOLD) AS daily_value
    FROM assignmentData
    WHERE TOTAL_VALUE_SOLD IS NOT NULL
    GROUP BY
        SALES_REP_ID,
        SALES_REP,
        CAST(TRY_CONVERT(DATE, CHECKIN_TIME, 101) AS DATE)
)

/* --- 3. Average the daily totals --- */
SELECT
    d.SALES_REP_ID,
    d.SALES_REP,
    AVG(d.daily_value) AS avg_daily_value_sold
FROM DailyTotals d
JOIN TopValueReps t
    ON d.SALES_REP_ID = t.SALES_REP_ID
GROUP BY
    d.SALES_REP_ID,
    d.SALES_REP
ORDER BY
    avg_daily_value_sold DESC;

--b)Day wise Average Time Spent
/* --- 1. Identify Top 10 Sales Reps by Total Value --- */
WITH TopValueReps AS (
    SELECT
        SALES_REP_ID,
        SALES_REP,
        SUM(TOTAL_VALUE_SOLD) AS total_value_sold
    FROM assignmentData
    WHERE TOTAL_VALUE_SOLD IS NOT NULL
    GROUP BY SALES_REP_ID, SALES_REP
    ORDER BY total_value_sold DESC
    OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY
),

/* --- 2. Compute each rep’s total minutes spent per day --- */
DailyTime AS (
    SELECT
        SALES_REP_ID,
        SALES_REP,
        CAST(TRY_CONVERT(DATE, CHECKIN_TIME, 101) AS DATE) AS visit_date,
        SUM(
            DATEDIFF(
                MINUTE,
                TRY_CONVERT(DATETIME, CHECKIN_TIME, 101),
                TRY_CONVERT(DATETIME, CHECKOUT_TIME, 101)
            )
        ) AS daily_minutes
    FROM assignmentData
    WHERE CHECKIN_TIME IS NOT NULL
      AND CHECKOUT_TIME IS NOT NULL
    GROUP BY
        SALES_REP_ID,
        SALES_REP,
        CAST(TRY_CONVERT(DATE, CHECKIN_TIME, 101) AS DATE)
)

/* --- 3. Average the daily minutes --- */
SELECT
    d.SALES_REP_ID,
    d.SALES_REP,
    AVG(d.daily_minutes) AS avg_daily_minutes_spent
FROM DailyTime d
JOIN TopValueReps t
    ON d.SALES_REP_ID = t.SALES_REP_ID
GROUP BY
    d.SALES_REP_ID,
    d.SALES_REP
ORDER BY
    avg_daily_minutes_spent DESC;


/*4. Detailed Reports for Top 3 Sales Representatives (by Value)
For each of the Top 3 Sales Representatives, create an Excel file for each sales rep with the following sheets:*/

-- Top 3 reps by total value sold
/* 1️ Find the Top 3 Sales Reps by Total Value Sold */
WITH SalesTotals AS (
    SELECT
        SALES_REP_ID,
        SALES_REP,
        SUM(TOTAL_VALUE_SOLD) AS total_value_sold
    FROM assignmentData
    WHERE TOTAL_VALUE_SOLD IS NOT NULL
    GROUP BY SALES_REP_ID, SALES_REP
)
SELECT TOP 3 *
FROM SalesTotals
ORDER BY total_value_sold DESC;

SELECT
    SALES_REP_ID,
    SKU_NAME AS [SKU Sold],
    CAST(TOTAL_VALUE_SOLD * 1.0 / UNIT_SOLD AS DECIMAL(18,2)) AS [Price of each SKU],
    UNIT_SOLD AS [Quantity Sold],
    TOTAL_VALUE_SOLD AS [Value Sold],
    CAST(CHECKIN_TIME AS DATE) AS [Sale Date]
FROM assignmentData
WHERE SALES_REP_ID IN (663, 433, 493)
ORDER BY SALES_REP_ID, [Sale Date], SKU_NAME;






SELECT
    CAST(CHECKIN_TIME AS DATE) AS [Date],
    SUM(UNIT_SOLD) AS [Total Quantity Sold],
    SUM(TOTAL_VALUE_SOLD) AS [Total Value Sold],
    COUNT(DISTINCT SKU_NAME) AS [Number of Unique SKUs Sold],
    COUNT(DISTINCT CUSTOMER_ID) AS [Count of Unique Customers Served],
    COUNT(ENTRY_ID) AS [Number of Visits Made],
    -- Conversion Percentage: assuming "visit converted" if TOTAL_VALUE_SOLD > 0
    CAST(100.0 * SUM(CASE WHEN TOTAL_VALUE_SOLD > 0 THEN 1 ELSE 0 END) / COUNT(ENTRY_ID) AS DECIMAL(5,2)) AS [Conversion Percentage],
    -- Total time spent: difference between CHECKOUT_TIME and CHECKIN_TIME in minutes
    SUM(DATEDIFF(MINUTE, CHECKIN_TIME, CHECKOUT_TIME)) AS [Total Time Spent (Minutes)]
FROM assignmentData
WHERE SALES_REP_ID IN (663, 433, 493)
GROUP BY CAST(CHECKIN_TIME AS DATE)
ORDER BY [Date];

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              