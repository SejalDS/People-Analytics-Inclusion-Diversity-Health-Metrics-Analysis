-- 1) Create DB if it doesn't exist
IF DB_ID('hr_id_metrics') IS NULL
    CREATE DATABASE hr_id_metrics;
GO

-- 2) Use it
USE hr_id_metrics;
GO

-- 3) Create a schema to keep things tidy
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'hr')
    EXEC('CREATE SCHEMA hr');
GO
USE hr_id_metrics;
GO

IF OBJECT_ID('hr.hr_clean','U') IS NOT NULL
    DROP TABLE hr.hr_clean;
GO

CREATE TABLE hr.hr_clean (
  employee_id INT PRIMARY KEY,
  gender                 VARCHAR(40),
  age_group              VARCHAR(40),
  nationality            VARCHAR(80),
  region_group           VARCHAR(80),
  broad_region_group     VARCHAR(80),
  department             VARCHAR(120),
  job_level_before_num   INT,
  job_level_before_title VARCHAR(100),
  job_level_after_num    INT,
  job_level_after_title  VARCHAR(100),
  seniority_group_after  VARCHAR(40),
  fy19_perf_rating       DECIMAL(6,2),
  fy20_perf_rating       DECIMAL(6,2),
  new_hire_fy20          BIT,
  fy20_leaver            BIT,
  is_active_fy20         BIT,
  leaver_fy              VARCHAR(10),
  promotion_in_fy20      BIT,
  promotion_in_fy21      BIT,
  in_base_group_for_promo_fy21        BIT,
  in_base_group_for_turnover_fy20     BIT,
  last_hire_date         DATE,
  time_in_job_level_at_2020_07_01 VARCHAR(50)
);
GO


USE hr_id_metrics;
GO

SELECT COUNT(*) AS dbo_count FROM dbo.id_hr_clean;

USE hr_id_metrics;
GO

-- 1) Drop the empty table in hr schema
IF OBJECT_ID('hr.hr_clean','U') IS NOT NULL
    DROP TABLE hr.hr_clean;
GO

-- 2) Move the loaded dbo table into hr schema
ALTER SCHEMA hr TRANSFER dbo.id_hr_clean;
GO

-- 3) Rename it to hr.hr_clean
EXEC sp_rename 'hr.id_hr_clean', 'hr_clean';
GO

-- 4) Verify
SELECT COUNT(*) AS rows_in_hr_clean FROM hr.hr_clean;
SELECT TOP (5) * FROM hr.hr_clean;

USE hr_id_metrics;
GO

-- Representation (FY20)
IF OBJECT_ID('hr.vw_representation_fy20','V') IS NOT NULL DROP VIEW hr.vw_representation_fy20;
GO
CREATE VIEW hr.vw_representation_fy20 AS
WITH base AS (
  SELECT * FROM hr.hr_clean WHERE ISNULL(is_active_fy20, 1) = 1
),
tot AS (SELECT COUNT(*) AS total_hc FROM base)
SELECT 'gender' AS dim_type, gender AS dim_value,
       COUNT(*) AS headcount,
       ROUND(100.0 * COUNT(*) / (SELECT total_hc FROM tot), 2) AS pct_representation
FROM base GROUP BY gender
UNION ALL
SELECT 'nationality', nationality,
       COUNT(*),
       ROUND(100.0 * COUNT(*) / (SELECT total_hc FROM tot), 2)
FROM base GROUP BY nationality;
GO

-- Leadership representation (level <= 2)
IF OBJECT_ID('hr.vw_representation_leadership_fy20','V') IS NOT NULL DROP VIEW hr.vw_representation_leadership_fy20;
GO
CREATE VIEW hr.vw_representation_leadership_fy20 AS
WITH leaders AS (
  SELECT * FROM hr.hr_clean
  WHERE ISNULL(is_active_fy20, 1) = 1
    AND job_level_after_num IS NOT NULL
    AND job_level_after_num <= 2
),
tot AS (SELECT COUNT(*) AS total_leaders FROM leaders)
SELECT gender AS group_name,
       COUNT(*) AS leaders_hc,
       ROUND(100.0 * COUNT(*) / (SELECT total_leaders FROM tot), 2) AS pct_leadership
FROM leaders
GROUP BY gender;
GO

-- Dept x Job-level matrix
IF OBJECT_ID('hr.vw_representation_matrix_fy20','V') IS NOT NULL DROP VIEW hr.vw_representation_matrix_fy20;
GO
CREATE VIEW hr.vw_representation_matrix_fy20 AS
SELECT department,
       job_level_after_num AS job_level_num,
       gender,
       COUNT(*) AS headcount
FROM hr.hr_clean
WHERE ISNULL(is_active_fy20, 1) = 1
GROUP BY department, job_level_after_num, gender;
GO

-- Attrition FY20 by gender (with disparity vs overall)
IF OBJECT_ID('hr.vw_attrition_gender_fy20','V') IS NOT NULL DROP VIEW hr.vw_attrition_gender_fy20;
GO
CREATE VIEW hr.vw_attrition_gender_fy20 AS
WITH base AS (
  SELECT gender,
         SUM(CASE WHEN in_base_group_for_turnover_fy20 = 1 THEN 1 ELSE 0 END) AS eligible,
         SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) AS exits
  FROM hr.hr_clean GROUP BY gender
),
overall AS (
  SELECT CAST(SUM(exits) AS DECIMAL(18,6)) / NULLIF(SUM(eligible),0) AS overall_rate
  FROM base
)
SELECT b.gender, b.exits, b.eligible,
       ROUND(100.0 * CAST(b.exits AS DECIMAL(18,6)) / NULLIF(b.eligible,0), 2) AS attrition_pct,
       ROUND(100.0 * (CAST(b.exits AS DECIMAL(18,6)) / NULLIF(b.eligible,0) - o.overall_rate), 2) AS disparity_pct_points
FROM base b CROSS JOIN overall o;
GO

-- Attrition FY20 by nationality
IF OBJECT_ID('hr.vw_attrition_nationality_fy20','V') IS NOT NULL DROP VIEW hr.vw_attrition_nationality_fy20;
GO
CREATE VIEW hr.vw_attrition_nationality_fy20 AS
WITH base AS (
  SELECT nationality,
         SUM(CASE WHEN in_base_group_for_turnover_fy20 = 1 THEN 1 ELSE 0 END) AS eligible,
         SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) AS exits
  FROM hr.hr_clean GROUP BY nationality
),
overall AS (
  SELECT CAST(SUM(exits) AS DECIMAL(18,6)) / NULLIF(SUM(eligible),0) AS overall_rate
  FROM base
)
SELECT b.nationality, b.exits, b.eligible,
       ROUND(100.0 * CAST(b.exits AS DECIMAL(18,6)) / NULLIF(b.eligible,0), 2) AS attrition_pct,
       ROUND(100.0 * (CAST(b.exits AS DECIMAL(18,6)) / NULLIF(b.eligible,0) - o.overall_rate), 2) AS disparity_pct_points
FROM base b CROSS JOIN overall o;
GO

-- Promotion equity FY21 by gender
IF OBJECT_ID('hr.vw_promotion_equity_gender_fy21','V') IS NOT NULL DROP VIEW hr.vw_promotion_equity_gender_fy21;
GO
CREATE VIEW hr.vw_promotion_equity_gender_fy21 AS
WITH rates AS (
  SELECT gender,
         SUM(CASE WHEN in_base_group_for_promo_fy21 = 1 THEN 1 ELSE 0 END) AS eligible,
         SUM(CASE WHEN promotion_in_fy21 = 1 THEN 1 ELSE 0 END) AS promoted,
         CAST(SUM(CASE WHEN promotion_in_fy21 = 1 THEN 1 ELSE 0 END) AS DECIMAL(18,6))
         / NULLIF(SUM(CASE WHEN in_base_group_for_promo_fy21 = 1 THEN 1 ELSE 0 END),0) AS promo_rate
  FROM hr.hr_clean GROUP BY gender
),
overall AS (
  SELECT CAST(SUM(promoted) AS DECIMAL(18,6)) / NULLIF(SUM(eligible),0) AS overall_rate
  FROM rates
)
SELECT r.gender, r.eligible, r.promoted,
       ROUND(100 * r.promo_rate, 2) AS promo_rate_pct,
       ROUND(r.promo_rate / NULLIF(o.overall_rate,0), 3) AS promotion_equity_index
FROM rates r CROSS JOIN overall o;
GO

-- Performance vs promotion FY21
IF OBJECT_ID('hr.vw_perf_vs_promo_fy21','V') IS NOT NULL DROP VIEW hr.vw_perf_vs_promo_fy21;
GO
CREATE VIEW hr.vw_perf_vs_promo_fy21 AS
SELECT gender,
       ROUND(AVG(CAST(fy20_perf_rating AS DECIMAL(18,6))), 2) AS avg_perf_fy20,
       ROUND(100.0 * AVG(CASE WHEN promotion_in_fy21 = 1 THEN 1.0 ELSE 0.0 END), 2) AS promo_rate_pct
FROM hr.hr_clean
WHERE in_base_group_for_promo_fy21 = 1
GROUP BY gender;
GO

-- Business impact: excess turnover cost FY20 (assume $25,000 per exit)
IF OBJECT_ID('hr.vw_attrition_cost_gender_fy20','V') IS NOT NULL DROP VIEW hr.vw_attrition_cost_gender_fy20;
GO
CREATE VIEW hr.vw_attrition_cost_gender_fy20 AS
WITH base AS (
  SELECT gender,
         SUM(CASE WHEN in_base_group_for_turnover_fy20 = 1 THEN 1 ELSE 0 END) AS eligible,
         SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) AS exits
  FROM hr.hr_clean GROUP BY gender
),
overall AS (
  SELECT CAST(SUM(exits) AS DECIMAL(18,6)) / NULLIF(SUM(eligible),0) AS overall_rate
  FROM base
)
SELECT b.gender, b.eligible, b.exits,
       ROUND(100.0 * CAST(b.exits AS DECIMAL(18,6)) / NULLIF(b.eligible,0), 2) AS attrition_pct,
       ROUND(100.0 * (CAST(b.exits AS DECIMAL(18,6)) / NULLIF(b.eligible,0) - o.overall_rate), 2) AS disparity_pct_points,
       CASE WHEN (CAST(b.exits AS DECIMAL(18,6)) - (o.overall_rate * b.eligible)) > 0
            THEN CAST(b.exits AS DECIMAL(18,6)) - (o.overall_rate * b.eligible) ELSE 0 END AS excess_exits,
       25000 * CASE WHEN (CAST(b.exits AS DECIMAL(18,6)) - (o.overall_rate * b.eligible)) > 0
            THEN CAST(b.exits AS DECIMAL(18,6)) - (o.overall_rate * b.eligible) ELSE 0 END AS excess_turnover_cost_usd
FROM base b CROSS JOIN overall o;
GO

SELECT TOP (20) * FROM hr.vw_representation_fy20 ORDER BY dim_type, pct_representation DESC;
SELECT TOP (20) * FROM hr.vw_attrition_gender_fy20;
SELECT TOP (20) * FROM hr.vw_promotion_equity_gender_fy21;
SELECT TOP (20) * FROM hr.vw_attrition_cost_gender_fy20;

USE hr_id_metrics;
GO

-- Overall attrition FY20
SELECT 
    ROUND(100.0 * SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 2) AS overall_attrition_pct
FROM hr.hr_clean;

-- Attrition by gender FY20
SELECT 
    gender,
    COUNT(*) AS headcount,
    SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) AS exits,
    ROUND(100.0 * SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 2) AS attrition_pct
FROM hr.hr_clean
GROUP BY gender;


-- Promotion rate by gender
WITH rates AS (
  SELECT 
      gender,
      SUM(CASE WHEN in_base_group_for_promo_fy21 = 1 THEN 1 ELSE 0 END) AS eligible,
      SUM(CASE WHEN promotion_in_fy21 = 1 THEN 1 ELSE 0 END) AS promoted,
      CAST(SUM(CASE WHEN promotion_in_fy21 = 1 THEN 1 ELSE 0 END) AS DECIMAL(18,6))
          / NULLIF(SUM(CASE WHEN in_base_group_for_promo_fy21 = 1 THEN 1 ELSE 0 END),0) AS promo_rate
  FROM hr.hr_clean
  GROUP BY gender
),
overall AS (
  SELECT SUM(promoted) * 1.0 / NULLIF(SUM(eligible),0) AS overall_rate FROM rates
)
SELECT 
    r.gender,
    r.eligible,
    r.promoted,
    ROUND(100 * r.promo_rate, 2) AS promo_rate_pct,
    ROUND(r.promo_rate / NULLIF(o.overall_rate,0), 3) AS promotion_equity_index
FROM rates r CROSS JOIN overall o;

-- Attrition cost by gender
WITH base AS (
  SELECT 
      gender,
      SUM(CASE WHEN in_base_group_for_turnover_fy20 = 1 THEN 1 ELSE 0 END) AS eligible,
      SUM(CASE WHEN fy20_leaver = 1 THEN 1 ELSE 0 END) AS exits
  FROM hr.hr_clean
  GROUP BY gender
),
overall AS (
  SELECT SUM(exits) * 1.0 / NULLIF(SUM(eligible),0) AS overall_rate FROM base
)
SELECT 
    b.gender,
    b.eligible,
    b.exits,
    ROUND(100.0 * b.exits * 1.0 / NULLIF(b.eligible,0), 2) AS attrition_pct,
    ROUND(100.0 * ((b.exits * 1.0 / NULLIF(b.eligible,0)) - o.overall_rate), 2) AS disparity_pct_points,
    CASE 
        WHEN (b.exits - (o.overall_rate * b.eligible)) > 0 
        THEN b.exits - (o.overall_rate * b.eligible) ELSE 0 END AS excess_exits,
    25000 * CASE 
        WHEN (b.exits - (o.overall_rate * b.eligible)) > 0 
        THEN b.exits - (o.overall_rate * b.eligible) ELSE 0 END AS excess_turnover_cost_usd
FROM base b CROSS JOIN overall o;
