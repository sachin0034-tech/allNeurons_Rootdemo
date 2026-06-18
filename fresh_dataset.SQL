-- ============================================================
-- ROOTS CANADA — COMPLETE FRESH DATASET
-- Run on a brand-new or fully-wiped RETAIL_ANALYTICS database.
-- Drops all objects, recreates schema, inserts 5 months of data
-- W01–W22 (Jan 5 – May 31, 2026).
--
-- Execution order:
--   1. Database / schema setup
--   2. Drop all existing tables (safe — IF EXISTS)
--   3. Create all dimension tables
--   4. Create all fact tables
--   5. Seed DIM_REGION, DIM_STORE_TYPE, DIM_STORE, DIM_DATE
--   6. Load FACT_DAILY_STORE_SALES (POS — W01–W22)
--   7. Load FACT_FINANCIAL_WEEKLY
--   8. Load FACT_SUPPLY_CHAIN_WEEKLY
--   9. Load FACT_INVENTORY_WEEKLY
--  10. Load FACT_CUSTOMER_WEEKLY
--  11. Load FACT_HR_WEEKLY
--  12. Create / Replace all 9 views
-- ============================================================

-- ============================================================
-- SECTION 0 — DATABASE & SCHEMA
-- ============================================================

CREATE DATABASE IF NOT EXISTS RETAIL_ANALYTICS;
USE DATABASE RETAIL_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS CORE;
USE SCHEMA CORE;


-- ============================================================
-- SECTION 1 — DROP ALL OBJECTS (clean slate)
-- ============================================================

DROP VIEW IF EXISTS VW_WEEKLY_HR;
DROP VIEW IF EXISTS VW_WEEKLY_CUSTOMER;
DROP VIEW IF EXISTS VW_WEEKLY_INVENTORY;
DROP VIEW IF EXISTS VW_WEEKLY_SUPPLY_CHAIN;
DROP VIEW IF EXISTS VW_WEEKLY_FINANCIAL;
DROP VIEW IF EXISTS VW_REGION_WEEKLY_YOY;
DROP VIEW IF EXISTS VW_STORE_TYPE_PERF;
DROP VIEW IF EXISTS VW_REGION_FP_MIX;
DROP VIEW IF EXISTS VW_WEEKLY_KPI;

DROP TABLE IF EXISTS FACT_HR_WEEKLY;
DROP TABLE IF EXISTS FACT_CUSTOMER_WEEKLY;
DROP TABLE IF EXISTS FACT_INVENTORY_WEEKLY;
DROP TABLE IF EXISTS FACT_SUPPLY_CHAIN_WEEKLY;
DROP TABLE IF EXISTS FACT_FINANCIAL_WEEKLY;
DROP TABLE IF EXISTS FACT_DAILY_STORE_SALES;
DROP TABLE IF EXISTS DIM_DATE;
DROP TABLE IF EXISTS DIM_STORE;
DROP TABLE IF EXISTS DIM_STORE_TYPE;
DROP TABLE IF EXISTS DIM_REGION;


-- ============================================================
-- SECTION 2 — CREATE DIMENSION TABLES
-- ============================================================

CREATE TABLE DIM_REGION (
    REGION_ID     INT AUTOINCREMENT PRIMARY KEY,
    REGION_CODE   VARCHAR(4)  NOT NULL UNIQUE,
    REGION_NAME   VARCHAR(60) NOT NULL,
    COUNTRY       VARCHAR(20) NOT NULL DEFAULT 'Canada'
);

CREATE TABLE DIM_STORE_TYPE (
    STORE_TYPE_ID   INT AUTOINCREMENT PRIMARY KEY,
    STORE_TYPE_NAME VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE DIM_STORE (
    STORE_ID        INT AUTOINCREMENT PRIMARY KEY,
    STORE_NUM       INT         NOT NULL UNIQUE,
    STORE_NAME      VARCHAR(60) NOT NULL,
    STORE_TYPE_ID   INT         NOT NULL REFERENCES DIM_STORE_TYPE(STORE_TYPE_ID),
    REGION_ID       INT         NOT NULL REFERENCES DIM_REGION(REGION_ID),
    OPEN_DATE       DATE,
    IS_ACTIVE       BOOLEAN     DEFAULT TRUE,
    IS_NSO          BOOLEAN     DEFAULT FALSE
);

CREATE TABLE DIM_DATE (
    DATE_ID     DATE    PRIMARY KEY,
    WEEK_NUM    INT     NOT NULL,
    WEEK_LABEL  VARCHAR(8),
    MONTH_NUM   INT     NOT NULL,
    MONTH_NAME  VARCHAR(12),
    QUARTER     INT     NOT NULL,
    FISCAL_YEAR INT     NOT NULL,
    IS_WEEKEND  BOOLEAN NOT NULL
);


-- ============================================================
-- SECTION 3 — CREATE FACT TABLES
-- ============================================================

CREATE TABLE FACT_DAILY_STORE_SALES (
    SALE_DATE       DATE    NOT NULL,
    STORE_ID        INT     NOT NULL REFERENCES DIM_STORE(STORE_ID),
    TRANSACTIONS    INT,
    TRAFFIC         INT,
    NET_SALES       DECIMAL(14,2),
    REG_PRICE_SALES DECIMAL(14,2),
    MARKDOWN_SALES  DECIMAL(14,2),
    UNITS_SOLD      INT,
    BUDGET_SALES    DECIMAL(14,2),
    LY_NET_SALES    DECIMAL(14,2),
    LY_TRAFFIC      INT,
    LY_TRANSACTIONS INT,
    PRIMARY KEY (SALE_DATE, STORE_ID)
);

CREATE TABLE FACT_FINANCIAL_WEEKLY (
    WEEK_NUM                INT  NOT NULL PRIMARY KEY,
    WEEK_START              DATE NOT NULL,
    REVENUE                 DECIMAL(14,2),
    BUDGET_REVENUE          DECIMAL(14,2),
    LY_REVENUE              DECIMAL(14,2),
    REVENUE_YOY_PCT         DECIMAL(6,4),
    COGS                    DECIMAL(14,2),
    GROSS_MARGIN            DECIMAL(14,2),
    GM_PCT                  DECIMAL(6,4),
    EBITDA                  DECIMAL(14,2),
    EBITDA_PCT              DECIMAL(6,4),
    OPEX                    DECIMAL(14,2),
    DEPRECIATION            DECIMAL(14,2),
    NET_OPERATING_INCOME    DECIMAL(14,2),
    CASH_POSITION           DECIMAL(14,2),
    ACCOUNTS_RECEIVABLE     DECIMAL(14,2),
    ACCOUNTS_PAYABLE        DECIMAL(14,2),
    BUDGET_VARIANCE         DECIMAL(14,2),
    BUDGET_VARIANCE_PCT     DECIMAL(6,4)
);

CREATE TABLE FACT_SUPPLY_CHAIN_WEEKLY (
    WEEK_NUM                 INT  NOT NULL PRIMARY KEY,
    WEEK_START               DATE NOT NULL,
    TOTAL_SHIPMENTS          INT,
    UNITS_SHIPPED            INT,
    ON_TIME_SHIPMENTS        INT,
    OTD_PCT                  DECIMAL(5,2),
    LATE_SHIPMENTS           INT,
    AVG_TRANSIT_DAYS         DECIMAL(5,2),
    TOTAL_FREIGHT_COST       DECIMAL(12,2),
    AVG_FREIGHT_PER_SHIPMENT DECIMAL(8,2),
    FEDEX_SHIPMENTS          INT,
    UPS_SHIPMENTS            INT,
    CANADA_POST_SHIPMENTS    INT,
    PUROLATOR_SHIPMENTS      INT,
    FILL_RATE_PCT            DECIMAL(5,2)
);

CREATE TABLE FACT_INVENTORY_WEEKLY (
    WEEK_NUM             INT  NOT NULL PRIMARY KEY,
    WEEK_START           DATE NOT NULL,
    TOTAL_INV_VALUE      DECIMAL(14,2),
    ACTIVE_SKUS          INT,
    CRITICAL_SKUS        INT,
    SELL_THRU_PCT        DECIMAL(5,2),
    DAYS_OF_STOCK        DECIMAL(5,1),
    INV_TURNS            DECIMAL(5,2),
    MARKDOWN_RISK_VALUE  DECIMAL(12,2),
    REORDER_PENDING_SKUS INT,
    DC_INBOUND_UNITS     INT,
    DC_OUTBOUND_UNITS    INT,
    INV_ACCURACY_PCT     DECIMAL(5,2),
    SHRINK_UNITS         INT
);

CREATE TABLE FACT_CUSTOMER_WEEKLY (
    WEEK_NUM             INT  NOT NULL PRIMARY KEY,
    WEEK_START           DATE NOT NULL,
    ACTIVE_CUSTOMERS     INT,
    NEW_CUSTOMERS        INT,
    LAPSED_CUSTOMERS     INT,
    CHAMPION_COUNT       INT,
    LOYALIST_COUNT       INT,
    AT_RISK_COUNT        INT,
    AVG_LTV              DECIMAL(10,2),
    TOTAL_LTV            DECIMAL(14,2),
    CSAT_SCORE           DECIMAL(4,2),
    NPS                  DECIMAL(5,1),
    VISITS_PER_CUSTOMER  DECIMAL(4,2),
    EMAIL_OPEN_PCT       DECIMAL(5,2),
    CHURN_PCT            DECIMAL(5,2)
);

CREATE TABLE FACT_HR_WEEKLY (
    WEEK_NUM             INT  NOT NULL PRIMARY KEY,
    WEEK_START           DATE NOT NULL,
    HEADCOUNT            INT,
    STORE_COUNT_STAFFED  INT,
    REG_HOURS            INT,
    OT_HOURS             INT,
    TOTAL_HOURS          INT,
    AVG_WAGE_RATE        DECIMAL(7,2),
    TOTAL_LABOUR_COST    DECIMAL(12,2),
    LABOUR_PCT_OF_SALES  DECIMAL(5,2),
    OT_PCT               DECIMAL(5,2),
    ABSENT_DAYS          INT,
    TRAINING_HOURS       INT,
    TURNOVER_PCT         DECIMAL(5,2)
);


-- ============================================================
-- SECTION 4 — SEED DIMENSION DATA
-- ============================================================

-- DIM_REGION (11 regions: 9 Canadian, 2 USA)
INSERT INTO DIM_REGION (REGION_CODE, REGION_NAME, COUNTRY) VALUES
('ON', 'Ontario',          'Canada'),
('QC', 'Quebec',           'Canada'),
('BC', 'British Columbia', 'Canada'),
('AB', 'Alberta',          'Canada'),
('MB', 'Manitoba',         'Canada'),
('NS', 'Nova Scotia',      'Canada'),
('SK', 'Saskatchewan',     'Canada'),
('NL', 'Newfoundland',     'Canada'),
('NB', 'New Brunswick',    'Canada'),
('UT', 'Utah',             'USA'),
('MI', 'Michigan',         'USA');

-- DIM_STORE_TYPE (5 formats)
INSERT INTO DIM_STORE_TYPE (STORE_TYPE_NAME) VALUES
('Mall'), ('Street'), ('Ski City'), ('Recall'), ('Power Centre');

-- DIM_STORE (32 stores)
INSERT INTO DIM_STORE (STORE_NUM, STORE_NAME, STORE_TYPE_ID, REGION_ID, OPEN_DATE, IS_ACTIVE, IS_NSO)
SELECT v.STORE_NUM, v.STORE_NAME, st.STORE_TYPE_ID, r.REGION_ID,
       v.OPEN_DATE::DATE, TRUE, v.IS_NSO
FROM (VALUES
    -- Ontario (10 stores)
    (101, 'Sherway Gardens',      'Mall',         'ON', '2020-01-15', FALSE),
    (102, 'Oshawa Centre',        'Mall',         'ON', '2019-03-10', FALSE),
    (103, 'Georgian Mall',        'Mall',         'ON', '2018-06-01', FALSE),
    (104, 'Rideau Centre',        'Mall',         'ON', '2017-11-20', FALSE),
    (105, 'Yorkdale',             'Mall',         'ON', '2016-09-15', FALSE),
    (106, 'Vaughan Mills',        'Mall',         'ON', '2021-04-17', FALSE),
    (107, 'Peterborough',         'Recall',       'ON', '2019-02-26', FALSE),
    (402, 'Lynden Park Mall',     'Mall',         'ON', '2025-07-29', TRUE),
    (452, 'Quinte Mall Kids',     'Mall',         'ON', '2025-07-30', TRUE),
    -- British Columbia (3 stores)
    (201, 'Pacific Centre',       'Mall',         'BC', '2018-04-01', FALSE),
    (202, 'Metrotown',            'Mall',         'BC', '2019-07-15', FALSE),
    (203, 'Park Royal',           'Street',       'BC', '2020-02-01', FALSE),
    -- Alberta (3 stores)
    (301, 'Chinook Centre',       'Mall',         'AB', '2017-05-10', FALSE),
    (302, 'West Edmonton Mall',   'Mall',         'AB', '2018-08-20', FALSE),
    (303, 'Southgate',            'Power Centre', 'AB', '2019-01-15', FALSE),
    -- Quebec (3 stores)
    (401, 'Carrefour Laval',      'Mall',         'QC', '2018-03-01', FALSE),
    (403, 'Place Ste-Foy',        'Mall',         'QC', '2019-06-10', FALSE),
    (239, 'MTL Premium Outlets',  'Mall',         'QC', '2025-08-15', TRUE),
    -- Nova Scotia (2 stores)
    (501, 'MicMac Mall',          'Mall',         'NS', '2020-01-10', FALSE),
    (502, 'Dartmouth Crossing',   'Power Centre', 'NS', '2021-04-15', FALSE),
    -- Manitoba (2 stores)
    (601, 'Polo Park',            'Mall',         'MB', '2018-07-01', FALSE),
    (602, 'St. Vital',            'Mall',         'MB', '2019-10-20', FALSE),
    -- Saskatchewan (2 stores)
    (701, 'Cornwall Centre',      'Mall',         'SK', '2019-03-05', FALSE),
    (702, 'River Heights',        'Street',       'SK', '2020-07-01', FALSE),
    -- Newfoundland (1 store)
    (801, 'Avalon Mall',          'Mall',         'NL', '2018-09-15', FALSE),
    -- New Brunswick (2 stores)
    (901, 'Regent Mall',          'Mall',         'NB', '2019-02-14', FALSE),
    (902, 'McAllister Place',     'Power Centre', 'NB', '2020-05-01', FALSE),
    -- Utah / Ski City (3 stores)
    (111, 'Park City Center',     'Ski City',     'UT', '2018-12-01', FALSE),
    (112, 'Deer Valley Ski Shop', 'Ski City',     'UT', '2019-11-15', FALSE),
    (113, 'Brighton Ski City',    'Ski City',     'UT', '2020-10-01', FALSE),
    -- Michigan (2 stores)
    (121, 'Somerset Collection',  'Mall',         'MI', '2018-06-20', FALSE),
    (122, 'Great Lakes Crossing', 'Ski City',     'MI', '2019-09-10', FALSE)
) AS v (STORE_NUM, STORE_NAME, STORE_TYPE_NAME, REGION_CODE, OPEN_DATE, IS_NSO)
JOIN DIM_STORE_TYPE st ON st.STORE_TYPE_NAME = v.STORE_TYPE_NAME
JOIN DIM_REGION     r  ON r.REGION_CODE      = v.REGION_CODE;

-- DIM_DATE (Jan 1 – May 31 2026 = 150 days)
INSERT INTO DIM_DATE (DATE_ID, WEEK_NUM, WEEK_LABEL, MONTH_NUM, MONTH_NAME,
                      QUARTER, FISCAL_YEAR, IS_WEEKEND)
SELECT
    DATEADD(DAY, SEQ4(), '2026-01-01')::DATE,
    WEEKOFYEAR(DATEADD(DAY, SEQ4(), '2026-01-01')),
    'W' || LPAD(WEEKOFYEAR(DATEADD(DAY, SEQ4(), '2026-01-01'))::VARCHAR, 2, '0'),
    MONTH(DATEADD(DAY, SEQ4(), '2026-01-01')),
    MONTHNAME(DATEADD(DAY, SEQ4(), '2026-01-01')),
    QUARTER(DATEADD(DAY, SEQ4(), '2026-01-01')),
    YEAR(DATEADD(DAY, SEQ4(), '2026-01-01')),
    DAYOFWEEK(DATEADD(DAY, SEQ4(), '2026-01-01')) IN (1, 7)
FROM TABLE(GENERATOR(ROWCOUNT => 150));


-- ============================================================
-- SECTION 5 — FACT_DAILY_STORE_SALES (POS, W01–W22)
-- ============================================================
-- Generates one row per store per day using Snowflake RANDOM().
-- Seasonal index built into SEASON_MULT; region+type factors
-- drive YoY story: overall fleet -3.1% YoY.

INSERT INTO FACT_DAILY_STORE_SALES (
    SALE_DATE, STORE_ID,
    TRANSACTIONS, TRAFFIC,
    NET_SALES, REG_PRICE_SALES, MARKDOWN_SALES, UNITS_SOLD,
    BUDGET_SALES, LY_NET_SALES, LY_TRAFFIC, LY_TRANSACTIONS
)
WITH base_rates AS (
    SELECT 'Mall'         AS ST, 4500  AS BASE_TRAFFIC, 42000 AS BASE_SALES, 0.1130 AS BASE_CVR, 0.745 AS BASE_FP
    UNION ALL SELECT 'Street',        580,    9500, 0.1650, 0.790
    UNION ALL SELECT 'Ski City',      620,    7200, 0.1270, 0.810
    UNION ALL SELECT 'Recall',        590,    6300, 0.1155, 0.740
    UNION ALL SELECT 'Power Centre',  110,    2400, 0.2280, 0.720
),
region_factors AS (
    SELECT REGION_CODE,
        -- LY multiplier > 1 means CY is lower YoY (decline story)
        CASE REGION_CODE
            WHEN 'ON' THEN 1.021 WHEN 'QC' THEN 1.055 WHEN 'BC' THEN 0.982
            WHEN 'AB' THEN 1.045 WHEN 'MB' THEN 0.995 WHEN 'NS' THEN 1.068
            WHEN 'SK' THEN 1.012 WHEN 'NL' THEN 1.031 WHEN 'NB' THEN 1.050
            WHEN 'UT' THEN 0.966 WHEN 'MI' THEN 1.029 ELSE 1.038
        END AS LY_SALES_MULT,
        CASE REGION_CODE
            WHEN 'ON' THEN 0.951 WHEN 'QC' THEN 0.925 WHEN 'BC' THEN 0.967
            WHEN 'AB' THEN 0.938 WHEN 'MB' THEN 0.957 WHEN 'NS' THEN 0.916
            WHEN 'SK' THEN 0.945 WHEN 'NL' THEN 0.935 WHEN 'NB' THEN 0.941
            WHEN 'UT' THEN 0.979 WHEN 'MI' THEN 0.954 ELSE 0.930
        END AS LY_TRAFFIC_MULT,
        CASE REGION_CODE
            WHEN 'ON' THEN 0.968 WHEN 'QC' THEN 0.955 WHEN 'BC' THEN 0.991
            WHEN 'AB' THEN 0.961 WHEN 'MB' THEN 0.974 WHEN 'NS' THEN 0.942
            WHEN 'SK' THEN 0.978 WHEN 'NL' THEN 0.956 WHEN 'NB' THEN 0.963
            WHEN 'UT' THEN 1.008 WHEN 'MI' THEN 0.970 ELSE 0.955
        END AS LY_CVR_MULT,
        CASE REGION_CODE
            WHEN 'ON' THEN 0.758 WHEN 'QC' THEN 0.742 WHEN 'BC' THEN 0.771
            WHEN 'AB' THEN 0.749 WHEN 'MB' THEN 0.735 WHEN 'NS' THEN 0.728
            WHEN 'SK' THEN 0.764 WHEN 'NL' THEN 0.751 WHEN 'NB' THEN 0.746
            WHEN 'UT' THEN 0.823 WHEN 'MI' THEN 0.761 ELSE 0.750
        END AS FP_MIX_TARGET
    FROM DIM_REGION
),
type_factors AS (
    SELECT STORE_TYPE_NAME,
        CASE STORE_TYPE_NAME
            WHEN 'Mall'         THEN 1.020
            WHEN 'Street'       THEN 0.980
            WHEN 'Ski City'     THEN 0.960
            WHEN 'Recall'       THEN 1.060
            WHEN 'Power Centre' THEN 1.080
            ELSE 1.040
        END AS TYPE_SALES_MULT,
        CASE STORE_TYPE_NAME
            WHEN 'Mall'         THEN 0.990
            WHEN 'Street'       THEN 0.975
            WHEN 'Ski City'     THEN 1.015
            WHEN 'Recall'       THEN 0.965
            WHEN 'Power Centre' THEN 0.958
            ELSE 0.980
        END AS TYPE_CVR_MULT
    FROM DIM_STORE_TYPE
),
cross_data AS (
    SELECT
        d.DATE_ID,
        s.STORE_ID,
        b.BASE_TRAFFIC,
        b.BASE_SALES,
        b.BASE_CVR,
        rf.FP_MIX_TARGET,
        rf.LY_SALES_MULT * tf.TYPE_SALES_MULT AS LY_SALES_MULT,
        rf.LY_TRAFFIC_MULT                    AS LY_TRAFFIC_MULT,
        rf.LY_CVR_MULT * tf.TYPE_CVR_MULT     AS LY_CVR_MULT,
        CASE WHEN d.IS_WEEKEND THEN 1.35 ELSE 1.0 END AS WEEKEND_MULT,
        CASE
            WHEN d.MONTH_NUM = 1                      THEN 1.10
            WHEN d.MONTH_NUM = 2                      THEN 0.89
            WHEN d.MONTH_NUM = 3                      THEN 0.94
            WHEN d.MONTH_NUM = 4                      THEN 1.02
            WHEN d.MONTH_NUM = 5                      THEN 1.07
            ELSE 1.00
        END AS SEASON_MULT,
        (0.88 + UNIFORM(0, 0.24, RANDOM())) AS NOISE
    FROM DIM_DATE d
    CROSS JOIN DIM_STORE s
    JOIN DIM_STORE_TYPE  st ON s.STORE_TYPE_ID    = st.STORE_TYPE_ID
    JOIN base_rates       b ON st.STORE_TYPE_NAME = b.ST
    JOIN DIM_REGION       r ON s.REGION_ID        = r.REGION_ID
    JOIN region_factors  rf ON r.REGION_CODE      = rf.REGION_CODE
    JOIN type_factors    tf ON st.STORE_TYPE_NAME = tf.STORE_TYPE_NAME
    WHERE d.DATE_ID BETWEEN '2026-01-05' AND '2026-05-31'
      AND s.IS_ACTIVE = TRUE
)
SELECT
    DATE_ID,
    STORE_ID,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_CVR)          AS TRANSACTIONS,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE)                     AS TRAFFIC,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE, 2)                  AS NET_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * FP_MIX_TARGET, 2) AS REG_PRICE_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * (1 - FP_MIX_TARGET), 2) AS MARKDOWN_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE / 51.82)             AS UNITS_SOLD,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * 1.06, 2)           AS BUDGET_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * LY_SALES_MULT, 2) AS LY_NET_SALES,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * LY_TRAFFIC_MULT)   AS LY_TRAFFIC,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_CVR * LY_CVR_MULT) AS LY_TRANSACTIONS
FROM cross_data;


-- ============================================================
-- SECTION 6 — FACT_FINANCIAL_WEEKLY (W01–W22)
-- ============================================================
-- Revenue baseline $2.05M/week with seasonal + noise
-- LY multipliers encode -3% to -5% YoY decline narrative

INSERT INTO FACT_FINANCIAL_WEEKLY
WITH weeks AS (
    SELECT
        wn.WEEK_NUM,
        DATEADD(WEEK, wn.WEEK_NUM - 1, '2026-01-05') AS WEEK_START,
        -- Seasonal index: Jan clearance → post-holiday dip → spring recovery
        CASE wn.WEEK_NUM
            WHEN  1 THEN 1.12  WHEN  2 THEN 1.02  WHEN  3 THEN 0.90
            WHEN  4 THEN 0.88  WHEN  5 THEN 0.87  WHEN  6 THEN 0.89
            WHEN  7 THEN 0.91  WHEN  8 THEN 0.93  WHEN  9 THEN 0.95
            WHEN 10 THEN 0.97  WHEN 11 THEN 0.99  WHEN 12 THEN 1.01
            WHEN 13 THEN 1.02  WHEN 14 THEN 1.04  WHEN 15 THEN 1.05
            WHEN 16 THEN 1.06  WHEN 17 THEN 1.06  WHEN 18 THEN 1.05
            WHEN 19 THEN 1.07  WHEN 20 THEN 1.08  WHEN 21 THEN 1.09
            WHEN 22 THEN 1.10  ELSE 1.00
        END AS SEA,
        -- LY multiplier (1.03x = CY is -3% YoY, 1.05x = -5% YoY)
        CASE wn.WEEK_NUM
            WHEN  1 THEN 1.030 WHEN  2 THEN 1.028 WHEN  3 THEN 1.032
            WHEN  4 THEN 1.035 WHEN  5 THEN 1.033 WHEN  6 THEN 1.031
            WHEN  7 THEN 1.034 WHEN  8 THEN 1.036 WHEN  9 THEN 1.038
            WHEN 10 THEN 1.040 WHEN 11 THEN 1.037 WHEN 12 THEN 1.035
            WHEN 13 THEN 1.039 WHEN 14 THEN 1.042 WHEN 15 THEN 1.041
            WHEN 16 THEN 1.044 WHEN 17 THEN 1.046 WHEN 18 THEN 1.049
            WHEN 19 THEN 1.045 WHEN 20 THEN 1.043 WHEN 21 THEN 1.041
            WHEN 22 THEN 1.038 ELSE 1.040
        END AS LY_MULT,
        -- Budget multiplier (some weeks above, some below budget)
        CASE wn.WEEK_NUM
            WHEN  1 THEN 1.020 WHEN  2 THEN 0.980 WHEN  3 THEN 0.965
            WHEN  4 THEN 0.972 WHEN  5 THEN 0.960 WHEN  6 THEN 0.978
            WHEN  7 THEN 0.985 WHEN  8 THEN 0.990 WHEN  9 THEN 0.995
            WHEN 10 THEN 1.002 WHEN 11 THEN 1.008 WHEN 12 THEN 1.015
            WHEN 13 THEN 1.012 WHEN 14 THEN 1.018 WHEN 15 THEN 1.025
            WHEN 16 THEN 0.992 WHEN 17 THEN 0.988 WHEN 18 THEN 0.975
            WHEN 19 THEN 1.005 WHEN 20 THEN 1.010 WHEN 21 THEN 1.014
            WHEN 22 THEN 1.020 ELSE 1.000
        END AS BUD_MULT
    FROM (
        SELECT  1 AS WEEK_NUM UNION ALL SELECT  2 UNION ALL SELECT  3 UNION ALL SELECT  4
        UNION ALL SELECT  5 UNION ALL SELECT  6 UNION ALL SELECT  7 UNION ALL SELECT  8
        UNION ALL SELECT  9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
        UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
        UNION ALL SELECT 21 UNION ALL SELECT 22
    ) wn
),
computed AS (
    SELECT
        WEEK_NUM,
        WEEK_START,
        ROUND(2050000 * SEA, 2)                                                   AS REVENUE,
        ROUND(2050000 * SEA / BUD_MULT, 2)                                        AS BUDGET_REVENUE,
        ROUND(2050000 * SEA * LY_MULT, 2)                                         AS LY_REVENUE,
        ROUND(2050000 * SEA * 0.585, 2)                                           AS COGS,
        ROUND(2050000 * SEA * (1 - 0.585), 2)                                     AS GROSS_MARGIN,
        ROUND(1 - 0.585, 4)                                                       AS GM_PCT,
        ROUND(2050000 * SEA * 0.225, 2)                                           AS EBITDA,
        ROUND(0.225, 4)                                                           AS EBITDA_PCT,
        ROUND(2050000 * SEA * 0.180, 2)                                           AS OPEX,
        ROUND(2050000 * SEA * 0.025, 2)                                           AS DEPRECIATION,
        ROUND(2050000 * SEA * (0.225 - 0.025), 2)                                AS NET_OPERATING_INCOME
    FROM weeks
)
SELECT
    WEEK_NUM,
    WEEK_START,
    REVENUE,
    BUDGET_REVENUE,
    LY_REVENUE,
    ROUND((REVENUE - LY_REVENUE) / LY_REVENUE, 4)                                AS REVENUE_YOY_PCT,
    COGS,
    GROSS_MARGIN,
    GM_PCT,
    EBITDA,
    EBITDA_PCT,
    OPEX,
    DEPRECIATION,
    NET_OPERATING_INCOME,
    -- Cash: starts at $18.4M, drifts ±$280K/week
    ROUND(18400000 + (WEEK_NUM - 11) * 85000, 2)                                 AS CASH_POSITION,
    ROUND(REVENUE * 0.14, 2)                                                     AS ACCOUNTS_RECEIVABLE,
    ROUND(COGS    * 0.21, 2)                                                     AS ACCOUNTS_PAYABLE,
    ROUND(REVENUE - BUDGET_REVENUE, 2)                                           AS BUDGET_VARIANCE,
    ROUND((REVENUE - BUDGET_REVENUE) / BUDGET_REVENUE, 4)                       AS BUDGET_VARIANCE_PCT
FROM computed;


-- ============================================================
-- SECTION 7 — FACT_SUPPLY_CHAIN_WEEKLY (W01–W22)
-- ============================================================
-- Baseline ~1,200 shipments/week, OTD ~94%, fill rate ~96.8%

INSERT INTO FACT_SUPPLY_CHAIN_WEEKLY
WITH weeks AS (
    SELECT
        WEEK_NUM,
        DATEADD(WEEK, WEEK_NUM - 1, '2026-01-05') AS WEEK_START,
        CASE WEEK_NUM
            WHEN  1 THEN 1.12  WHEN  2 THEN 1.02  WHEN  3 THEN 0.90
            WHEN  4 THEN 0.88  WHEN  5 THEN 0.87  WHEN  6 THEN 0.89
            WHEN  7 THEN 0.91  WHEN  8 THEN 0.93  WHEN  9 THEN 0.95
            WHEN 10 THEN 0.97  WHEN 11 THEN 0.99  WHEN 12 THEN 1.01
            WHEN 13 THEN 1.02  WHEN 14 THEN 1.04  WHEN 15 THEN 1.05
            WHEN 16 THEN 1.06  WHEN 17 THEN 1.06  WHEN 18 THEN 1.05
            WHEN 19 THEN 1.07  WHEN 20 THEN 1.08  WHEN 21 THEN 1.09
            WHEN 22 THEN 1.10  ELSE 1.00
        END AS SEA
    FROM (
        SELECT  1 AS WEEK_NUM UNION ALL SELECT  2 UNION ALL SELECT  3 UNION ALL SELECT  4
        UNION ALL SELECT  5 UNION ALL SELECT  6 UNION ALL SELECT  7 UNION ALL SELECT  8
        UNION ALL SELECT  9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
        UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
        UNION ALL SELECT 21 UNION ALL SELECT 22
    ) wk
),
computed AS (
    SELECT
        WEEK_NUM,
        WEEK_START,
        ROUND(1200 * SEA) AS SHIPS,
        ROUND(1200 * SEA) * 13 AS UNITS,
        -- OTD: varies 92–97%, dips W04–W06 (post-holiday congestion)
        CASE WHEN WEEK_NUM BETWEEN 4 AND 6 THEN 92.4
             WHEN WEEK_NUM BETWEEN 14 AND 16 THEN 95.8
             ELSE 94.2 + (WEEK_NUM * 0.05)
        END AS OTD,
        -- Freight: baseline $124.50/shipment, rises late spring
        124.50 + (WEEK_NUM * 0.35) AS FRT_A
    FROM weeks
)
SELECT
    WEEK_NUM,
    WEEK_START,
    SHIPS                                                      AS TOTAL_SHIPMENTS,
    UNITS                                                      AS UNITS_SHIPPED,
    ROUND(SHIPS * OTD / 100)                                   AS ON_TIME_SHIPMENTS,
    ROUND(LEAST(OTD, 99.0), 2)                                 AS OTD_PCT,
    SHIPS - ROUND(SHIPS * OTD / 100)                           AS LATE_SHIPMENTS,
    ROUND(GREATEST(1.5, 2.8 - (WEEK_NUM * 0.02)), 2)           AS AVG_TRANSIT_DAYS,
    ROUND(SHIPS * FRT_A, 2)                                    AS TOTAL_FREIGHT_COST,
    ROUND(FRT_A, 2)                                            AS AVG_FREIGHT_PER_SHIPMENT,
    ROUND(SHIPS * 0.36)                                        AS FEDEX_SHIPMENTS,
    ROUND(SHIPS * 0.25)                                        AS UPS_SHIPMENTS,
    ROUND(SHIPS * 0.23)                                        AS CANADA_POST_SHIPMENTS,
    SHIPS - ROUND(SHIPS * 0.36) - ROUND(SHIPS * 0.25) - ROUND(SHIPS * 0.23) AS PUROLATOR_SHIPMENTS,
    ROUND(LEAST(96.8 + (WEEK_NUM * 0.04), 99.5), 2)            AS FILL_RATE_PCT
FROM computed;


-- ============================================================
-- SECTION 8 — FACT_INVENTORY_WEEKLY (W01–W22)
-- ============================================================
-- Inventory starts high post-holiday (~$5.0M), depletes through spring
-- DC activity (inbound/outbound) reflects pre-summer restocking in May

INSERT INTO FACT_INVENTORY_WEEKLY
WITH weeks AS (
    SELECT
        WEEK_NUM,
        DATEADD(WEEK, WEEK_NUM - 1, '2026-01-05') AS WEEK_START,
        -- Inventory seasonal: inverse of sales — high Jan, low mid-spring
        CASE WEEK_NUM
            WHEN  1 THEN 1.18  WHEN  2 THEN 1.12  WHEN  3 THEN 1.08
            WHEN  4 THEN 1.04  WHEN  5 THEN 1.01  WHEN  6 THEN 0.99
            WHEN  7 THEN 0.97  WHEN  8 THEN 0.95  WHEN  9 THEN 0.93
            WHEN 10 THEN 0.91  WHEN 11 THEN 0.90  WHEN 12 THEN 0.89
            WHEN 13 THEN 0.88  WHEN 14 THEN 0.87  WHEN 15 THEN 0.87
            WHEN 16 THEN 0.88  WHEN 17 THEN 0.89  WHEN 18 THEN 0.90
            WHEN 19 THEN 0.91  WHEN 20 THEN 0.93  WHEN 21 THEN 0.95
            WHEN 22 THEN 0.97  ELSE 1.00
        END AS INV_SEA
    FROM (
        SELECT  1 AS WEEK_NUM UNION ALL SELECT  2 UNION ALL SELECT  3 UNION ALL SELECT  4
        UNION ALL SELECT  5 UNION ALL SELECT  6 UNION ALL SELECT  7 UNION ALL SELECT  8
        UNION ALL SELECT  9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
        UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
        UNION ALL SELECT 21 UNION ALL SELECT 22
    ) wk
)
SELECT
    WEEK_NUM,
    WEEK_START,
    ROUND(4200000 * INV_SEA, 2)                                  AS TOTAL_INV_VALUE,
    3800 + WEEK_NUM * 18                                         AS ACTIVE_SKUS,
    -- Critical SKUs: higher in Jan (clearance pressure), lower mid-season
    CASE WHEN WEEK_NUM <= 4 THEN 14 + (4 - WEEK_NUM) * 2
         WHEN WEEK_NUM BETWEEN 13 AND 17 THEN 5 + WEEK_NUM - 13
         ELSE 6
    END                                                          AS CRITICAL_SKUS,
    -- Sell-through: 75–88%
    ROUND(LEAST(88.0, 75.0 + WEEK_NUM * 0.6), 2)                AS SELL_THRU_PCT,
    -- Days of stock: 32 in Jan, declining to 22 by May
    ROUND(GREATEST(22.0, 32.0 - WEEK_NUM * 0.45), 1)            AS DAYS_OF_STOCK,
    -- Inventory turns: inverse of days of stock (annualised)
    ROUND(52 / GREATEST(22.0, 32.0 - WEEK_NUM * 0.45), 2)       AS INV_TURNS,
    -- Markdown risk: high Jan, low mid-season, rising late May
    ROUND(4200000 * INV_SEA * CASE WHEN WEEK_NUM <= 6 THEN 0.10
                                   WHEN WEEK_NUM <= 14 THEN 0.06
                                   ELSE 0.08 END, 2)             AS MARKDOWN_RISK_VALUE,
    -- Reorder pending: higher in spring restocking
    CASE WHEN WEEK_NUM >= 16 THEN 45 + WEEK_NUM * 2
         ELSE 20 + WEEK_NUM
    END                                                          AS REORDER_PENDING_SKUS,
    -- DC activity rises through spring
    18000 + WEEK_NUM * 620                                       AS DC_INBOUND_UNITS,
    16000 + WEEK_NUM * 580                                       AS DC_OUTBOUND_UNITS,
    ROUND(GREATEST(96.5, 98.5 - WEEK_NUM * 0.04), 2)            AS INV_ACCURACY_PCT,
    -- Shrink: steady ~300 units/week
    280 + MOD(WEEK_NUM * 17, 200)                                AS SHRINK_UNITS
FROM weeks;


-- ============================================================
-- SECTION 9 — FACT_CUSTOMER_WEEKLY (W01–W22)
-- ============================================================
-- Active base ~8,000; new acquisitions ~820/week
-- CSAT 4.3–4.6/5; NPS 40–52; lapsed driven by January churn

INSERT INTO FACT_CUSTOMER_WEEKLY
WITH weeks AS (
    SELECT
        WEEK_NUM,
        DATEADD(WEEK, WEEK_NUM - 1, '2026-01-05') AS WEEK_START
    FROM (
        SELECT  1 AS WEEK_NUM UNION ALL SELECT  2 UNION ALL SELECT  3 UNION ALL SELECT  4
        UNION ALL SELECT  5 UNION ALL SELECT  6 UNION ALL SELECT  7 UNION ALL SELECT  8
        UNION ALL SELECT  9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
        UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
        UNION ALL SELECT 21 UNION ALL SELECT 22
    ) wk
)
SELECT
    WEEK_NUM,
    WEEK_START,
    7800 + WEEK_NUM * 22                                           AS ACTIVE_CUSTOMERS,
    -- New customers: high in Jan (sale), low Feb, recovering spring
    CASE WHEN WEEK_NUM <= 2  THEN 1050 - WEEK_NUM * 40
         WHEN WEEK_NUM <= 6  THEN 680  - WEEK_NUM * 8
         WHEN WEEK_NUM <= 14 THEN 740  + WEEK_NUM * 5
         ELSE 820 + WEEK_NUM * 3
    END                                                            AS NEW_CUSTOMERS,
    -- Lapsed: higher post-holiday
    CASE WHEN WEEK_NUM <= 4 THEN 420 - WEEK_NUM * 20
         WHEN WEEK_NUM <= 12 THEN 260 - WEEK_NUM * 5
         ELSE 190 + WEEK_NUM
    END                                                            AS LAPSED_CUSTOMERS,
    300 + WEEK_NUM * 4                                             AS CHAMPION_COUNT,
    900 + WEEK_NUM * 12                                            AS LOYALIST_COUNT,
    420 - WEEK_NUM * 8                                             AS AT_RISK_COUNT,
    2380 + WEEK_NUM * 18                                           AS AVG_LTV,
    (7800 + WEEK_NUM * 22) * (2380 + WEEK_NUM * 18)               AS TOTAL_LTV,
    -- CSAT: dips slightly mid-season (staffing pressure), recovers
    ROUND(CASE WHEN WEEK_NUM BETWEEN 15 AND 18 THEN 4.32
               WHEN WEEK_NUM <= 5 THEN 4.42
               ELSE 4.45 END, 2)                                   AS CSAT_SCORE,
    -- NPS: improving trend through spring
    ROUND(42 + WEEK_NUM * 0.45, 1)                                 AS NPS,
    ROUND(2.6 + WEEK_NUM * 0.01, 2)                                AS VISITS_PER_CUSTOMER,
    ROUND(28.5 + WEEK_NUM * 0.12, 2)                               AS EMAIL_OPEN_PCT,
    -- Churn: highest post-holiday, declining through spring
    ROUND(GREATEST(1.4, 2.8 - WEEK_NUM * 0.06), 2)                AS CHURN_PCT
FROM weeks;


-- ============================================================
-- SECTION 10 — FACT_HR_WEEKLY (W01–W22)
-- ============================================================
-- ~520 headcount, avg wage $19.85/hr, OT peaks W01 (holiday season wind-down)

INSERT INTO FACT_HR_WEEKLY
WITH weeks AS (
    SELECT
        WEEK_NUM,
        DATEADD(WEEK, WEEK_NUM - 1, '2026-01-05') AS WEEK_START
    FROM (
        SELECT  1 AS WEEK_NUM UNION ALL SELECT  2 UNION ALL SELECT  3 UNION ALL SELECT  4
        UNION ALL SELECT  5 UNION ALL SELECT  6 UNION ALL SELECT  7 UNION ALL SELECT  8
        UNION ALL SELECT  9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
        UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
        UNION ALL SELECT 21 UNION ALL SELECT 22
    ) wk
)
SELECT
    WEEK_NUM,
    WEEK_START,
    -- Headcount: higher Jan (seasonal) → stable core → slight spring uptick
    CASE WHEN WEEK_NUM <= 3 THEN 532 - WEEK_NUM * 4
         WHEN WEEK_NUM <= 10 THEN 518
         ELSE 518 + WEEK_NUM - 10
    END                                                            AS HEADCOUNT,
    83                                                             AS STORE_COUNT_STAFFED,
    -- Regular hours: headcount × 36 hrs
    (CASE WHEN WEEK_NUM <= 3 THEN 532 - WEEK_NUM * 4
          WHEN WEEK_NUM <= 10 THEN 518
          ELSE 518 + WEEK_NUM - 10 END) * 36                      AS REG_HOURS,
    -- OT hours: high Jan, normalises by W06
    ROUND((CASE WHEN WEEK_NUM <= 3 THEN 532 - WEEK_NUM * 4
                WHEN WEEK_NUM <= 10 THEN 518
                ELSE 518 + WEEK_NUM - 10 END) * 36 *
          CASE WHEN WEEK_NUM <= 2 THEN 0.12
               WHEN WEEK_NUM <= 5 THEN 0.09
               ELSE 0.07 END)                                      AS OT_HOURS,
    -- Total hours
    ROUND((CASE WHEN WEEK_NUM <= 3 THEN 532 - WEEK_NUM * 4
                WHEN WEEK_NUM <= 10 THEN 518
                ELSE 518 + WEEK_NUM - 10 END) * 36 *
          (1 + CASE WHEN WEEK_NUM <= 2 THEN 0.12
                    WHEN WEEK_NUM <= 5 THEN 0.09
                    ELSE 0.07 END))                                AS TOTAL_HOURS,
    -- Wage: steady growth ~1.2% over period (BC/ON minimum wage pressure)
    ROUND(19.85 + WEEK_NUM * 0.03, 2)                             AS AVG_WAGE_RATE,
    -- Labour cost = (REG + OT*1.5) × wage
    ROUND((CASE WHEN WEEK_NUM <= 3 THEN 532 - WEEK_NUM * 4
                WHEN WEEK_NUM <= 10 THEN 518
                ELSE 518 + WEEK_NUM - 10 END) * 36 *
          (1 + CASE WHEN WEEK_NUM <= 2 THEN 0.12 * 1.5
                    WHEN WEEK_NUM <= 5 THEN 0.09 * 1.5
                    ELSE 0.07 * 1.5 END) * (19.85 + WEEK_NUM * 0.03), 2) AS TOTAL_LABOUR_COST,
    -- Labour % of sales (target <28%)
    ROUND(26.5 + (WEEK_NUM * 0.04), 2)                            AS LABOUR_PCT_OF_SALES,
    -- OT %
    ROUND(CASE WHEN WEEK_NUM <= 2 THEN 12.0
               WHEN WEEK_NUM <= 5 THEN 9.0
               ELSE 7.0 END, 2)                                    AS OT_PCT,
    -- Absenteeism: higher Jan, lower spring
    CASE WHEN WEEK_NUM <= 4 THEN 24 - WEEK_NUM * 2
         ELSE 14 + MOD(WEEK_NUM, 4)
    END                                                            AS ABSENT_DAYS,
    -- Training: higher in spring as stores prepare for summer
    CASE WHEN WEEK_NUM >= 16 THEN 380 + WEEK_NUM * 8
         WHEN WEEK_NUM >= 10 THEN 260 + WEEK_NUM * 5
         ELSE 200 + WEEK_NUM * 4
    END                                                            AS TRAINING_HOURS,
    -- Turnover: higher Jan (post-season), declining through spring
    ROUND(GREATEST(1.2, 2.4 - WEEK_NUM * 0.05), 2)               AS TURNOVER_PCT
FROM weeks;


-- ============================================================
-- SECTION 11 — REBUILD ALL 9 VIEWS
-- ============================================================

-- 1. POS weekly KPI (from FACT_DAILY_STORE_SALES)
CREATE OR REPLACE VIEW VW_WEEKLY_KPI AS
SELECT
    d.WEEK_NUM,
    d.WEEK_LABEL,
    MIN(d.DATE_ID)                                                          AS WEEK_START,
    SUM(f.NET_SALES)                                                        AS NET_SALES,
    SUM(f.TRAFFIC)                                                          AS TRAFFIC,
    SUM(f.TRANSACTIONS)                                                     AS TRANSACTIONS,
    SUM(f.UNITS_SOLD)                                                       AS UNITS_SOLD,
    ROUND(SUM(f.NET_SALES)       / NULLIF(SUM(f.TRANSACTIONS), 0), 2)      AS ADS,
    ROUND(SUM(f.UNITS_SOLD)      / NULLIF(SUM(f.TRANSACTIONS), 0), 2)      AS UPT,
    ROUND(SUM(f.NET_SALES)       / NULLIF(SUM(f.UNITS_SOLD),   0), 2)      AS AUR,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES),    0), 4)      AS FP_MIX,
    SUM(f.LY_NET_SALES)                                                     AS LY_NET_SALES,
    SUM(f.LY_TRAFFIC)                                                       AS LY_TRAFFIC,
    SUM(f.LY_TRANSACTIONS)                                                  AS LY_TRANSACTIONS,
    SUM(f.BUDGET_SALES)                                                     AS BUDGET_SALES,
    ROUND(SUM(f.LY_NET_SALES)    / NULLIF(SUM(f.LY_TRANSACTIONS), 0), 2)   AS LY_ADS,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0) + 0.028, 4) AS LY_FP_MIX
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE d ON f.SALE_DATE = d.DATE_ID
GROUP BY d.WEEK_NUM, d.WEEK_LABEL;

-- 2. Region full-price mix
CREATE OR REPLACE VIEW VW_REGION_FP_MIX AS
SELECT
    r.REGION_CODE,
    r.REGION_NAME,
    d.WEEK_NUM,
    SUM(f.NET_SALES)                                                   AS NET_SALES,
    SUM(f.REG_PRICE_SALES)                                             AS REG_PRICE_SALES,
    SUM(f.TRAFFIC)                                                     AS TRAFFIC,
    SUM(f.TRANSACTIONS)                                                AS TRANSACTIONS,
    SUM(f.LY_NET_SALES)                                                AS LY_NET_SALES,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0), 4)    AS FP_MIX,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0)
          + CASE r.REGION_CODE
              WHEN 'BC' THEN -0.005 WHEN 'UT' THEN -0.013 WHEN 'SK' THEN  0.008
              WHEN 'ON' THEN  0.012 WHEN 'MI' THEN  0.020 WHEN 'AB' THEN  0.024
              WHEN 'NL' THEN  0.029 WHEN 'NB' THEN  0.031 WHEN 'QC' THEN  0.038
              WHEN 'MB' THEN  0.041 WHEN 'NS' THEN  0.052 ELSE 0.035
            END, 4)                                                    AS LY_FP_MIX
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE   d ON f.SALE_DATE = d.DATE_ID
JOIN DIM_STORE  s ON f.STORE_ID  = s.STORE_ID
JOIN DIM_REGION r ON s.REGION_ID = r.REGION_ID
GROUP BY r.REGION_CODE, r.REGION_NAME, d.WEEK_NUM;

-- 3. Store type performance
CREATE OR REPLACE VIEW VW_STORE_TYPE_PERF AS
SELECT
    st.STORE_TYPE_NAME,
    d.WEEK_NUM,
    SUM(f.NET_SALES)                                                    AS NET_SALES,
    SUM(f.TRAFFIC)                                                      AS TRAFFIC,
    SUM(f.TRANSACTIONS)                                                 AS TRANSACTIONS,
    SUM(f.UNITS_SOLD)                                                   AS UNITS_SOLD,
    ROUND(SUM(f.NET_SALES)       / NULLIF(SUM(f.TRANSACTIONS), 0), 2)  AS ADS,
    ROUND(SUM(f.UNITS_SOLD)      / NULLIF(SUM(f.TRANSACTIONS), 0), 2)  AS UPT,
    ROUND(SUM(f.TRANSACTIONS)    / NULLIF(SUM(f.TRAFFIC),      0), 4)  AS CVR,
    SUM(f.LY_NET_SALES)                                                 AS LY_NET_SALES,
    SUM(f.LY_TRAFFIC)                                                   AS LY_TRAFFIC,
    SUM(f.LY_TRANSACTIONS)                                              AS LY_TRANSACTIONS,
    ROUND(SUM(f.LY_TRANSACTIONS) / NULLIF(SUM(f.LY_TRAFFIC),     0), 4) AS LY_CVR,
    ROUND(SUM(f.LY_NET_SALES)    / NULLIF(SUM(f.LY_TRANSACTIONS),0), 2) AS LY_ADS
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE       d  ON f.SALE_DATE     = d.DATE_ID
JOIN DIM_STORE      s  ON f.STORE_ID      = s.STORE_ID
JOIN DIM_STORE_TYPE st ON s.STORE_TYPE_ID = st.STORE_TYPE_ID
GROUP BY st.STORE_TYPE_NAME, d.WEEK_NUM;

-- 4. Region YoY weekly
CREATE OR REPLACE VIEW VW_REGION_WEEKLY_YOY AS
SELECT
    r.REGION_CODE,
    d.WEEK_NUM,
    SUM(f.NET_SALES)                                                            AS CY_SALES,
    SUM(f.LY_NET_SALES)                                                         AS LY_SALES,
    SUM(f.TRAFFIC)                                                              AS CY_TRAFFIC,
    SUM(f.LY_TRAFFIC)                                                           AS LY_TRAFFIC,
    ROUND(SUM(f.TRANSACTIONS)    / NULLIF(SUM(f.TRAFFIC),    0), 4)            AS CY_CVR,
    ROUND(SUM(f.LY_TRANSACTIONS) / NULLIF(SUM(f.LY_TRAFFIC), 0), 4)           AS LY_CVR,
    ROUND((SUM(f.NET_SALES)  - SUM(f.LY_NET_SALES)) / NULLIF(SUM(f.LY_NET_SALES),0), 4) AS SALES_YOY_PCT,
    ROUND((SUM(f.TRAFFIC)    - SUM(f.LY_TRAFFIC))   / NULLIF(SUM(f.LY_TRAFFIC),  0), 4) AS TRAFFIC_YOY_PCT,
    ROUND((SUM(f.TRANSACTIONS) / NULLIF(SUM(f.TRAFFIC), 0)) -
          (SUM(f.LY_TRANSACTIONS) / NULLIF(SUM(f.LY_TRAFFIC), 0)), 4)         AS CVR_DELTA_BPS
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE   d ON f.SALE_DATE = d.DATE_ID
JOIN DIM_STORE  s ON f.STORE_ID  = s.STORE_ID
JOIN DIM_REGION r ON s.REGION_ID = r.REGION_ID
GROUP BY r.REGION_CODE, d.WEEK_NUM;

-- 5. Financial weekly (+ WoW)
CREATE OR REPLACE VIEW VW_WEEKLY_FINANCIAL AS
SELECT
    WEEK_NUM,
    WEEK_START,
    REVENUE,
    BUDGET_REVENUE,
    LY_REVENUE,
    REVENUE_YOY_PCT,
    ROUND((REVENUE - BUDGET_REVENUE) / NULLIF(BUDGET_REVENUE, 0), 4)              AS REVENUE_VS_BUDGET_PCT,
    GROSS_MARGIN,
    GM_PCT,
    EBITDA,
    EBITDA_PCT,
    OPEX,
    DEPRECIATION,
    NET_OPERATING_INCOME,
    CASH_POSITION,
    ACCOUNTS_RECEIVABLE,
    ACCOUNTS_PAYABLE,
    BUDGET_VARIANCE,
    BUDGET_VARIANCE_PCT,
    LAG(REVENUE)      OVER (ORDER BY WEEK_NUM)                                    AS PREV_WEEK_REVENUE,
    ROUND((REVENUE - LAG(REVENUE) OVER (ORDER BY WEEK_NUM)) /
          NULLIF(LAG(REVENUE) OVER (ORDER BY WEEK_NUM), 0), 4)                    AS REVENUE_WOW_PCT
FROM FACT_FINANCIAL_WEEKLY;

-- 6. Supply chain weekly (+ WoW)
CREATE OR REPLACE VIEW VW_WEEKLY_SUPPLY_CHAIN AS
SELECT
    WEEK_NUM,
    WEEK_START,
    TOTAL_SHIPMENTS,
    UNITS_SHIPPED,
    ON_TIME_SHIPMENTS,
    OTD_PCT,
    LATE_SHIPMENTS,
    AVG_TRANSIT_DAYS,
    TOTAL_FREIGHT_COST,
    AVG_FREIGHT_PER_SHIPMENT,
    FEDEX_SHIPMENTS,
    UPS_SHIPMENTS,
    CANADA_POST_SHIPMENTS,
    PUROLATOR_SHIPMENTS,
    FILL_RATE_PCT,
    LAG(OTD_PCT)   OVER (ORDER BY WEEK_NUM)                                       AS PREV_OTD_PCT,
    ROUND((OTD_PCT - LAG(OTD_PCT) OVER (ORDER BY WEEK_NUM)) * 100, 0)            AS OTD_WOW_BPS
FROM FACT_SUPPLY_CHAIN_WEEKLY;

-- 7. Inventory weekly (+ WoW)
CREATE OR REPLACE VIEW VW_WEEKLY_INVENTORY AS
SELECT
    WEEK_NUM,
    WEEK_START,
    TOTAL_INV_VALUE,
    ACTIVE_SKUS,
    CRITICAL_SKUS,
    SELL_THRU_PCT,
    DAYS_OF_STOCK,
    INV_TURNS,
    MARKDOWN_RISK_VALUE,
    REORDER_PENDING_SKUS,
    DC_INBOUND_UNITS,
    DC_OUTBOUND_UNITS,
    INV_ACCURACY_PCT,
    SHRINK_UNITS,
    LAG(INV_TURNS) OVER (ORDER BY WEEK_NUM)                                       AS PREV_INV_TURNS,
    ROUND(INV_TURNS - LAG(INV_TURNS) OVER (ORDER BY WEEK_NUM), 3)                AS INV_TURNS_WOW
FROM FACT_INVENTORY_WEEKLY;

-- 8. Customer weekly (+ WoW)
CREATE OR REPLACE VIEW VW_WEEKLY_CUSTOMER AS
SELECT
    WEEK_NUM,
    WEEK_START,
    ACTIVE_CUSTOMERS,
    NEW_CUSTOMERS,
    LAPSED_CUSTOMERS,
    CHAMPION_COUNT,
    LOYALIST_COUNT,
    AT_RISK_COUNT,
    AVG_LTV,
    TOTAL_LTV,
    CSAT_SCORE,
    NPS,
    VISITS_PER_CUSTOMER,
    EMAIL_OPEN_PCT,
    CHURN_PCT,
    LAG(CSAT_SCORE) OVER (ORDER BY WEEK_NUM)                                      AS PREV_CSAT,
    ROUND(CSAT_SCORE - LAG(CSAT_SCORE) OVER (ORDER BY WEEK_NUM), 2)              AS CSAT_WOW,
    LAG(NPS) OVER (ORDER BY WEEK_NUM)                                             AS PREV_NPS,
    ROUND(NPS - LAG(NPS) OVER (ORDER BY WEEK_NUM), 1)                            AS NPS_WOW
FROM FACT_CUSTOMER_WEEKLY;

-- 9. HR weekly (+ WoW)
CREATE OR REPLACE VIEW VW_WEEKLY_HR AS
SELECT
    WEEK_NUM,
    WEEK_START,
    HEADCOUNT,
    STORE_COUNT_STAFFED,
    REG_HOURS,
    OT_HOURS,
    TOTAL_HOURS,
    AVG_WAGE_RATE,
    TOTAL_LABOUR_COST,
    LABOUR_PCT_OF_SALES,
    OT_PCT,
    ABSENT_DAYS,
    TRAINING_HOURS,
    TURNOVER_PCT,
    LAG(TOTAL_LABOUR_COST) OVER (ORDER BY WEEK_NUM)                               AS PREV_LABOUR_COST,
    ROUND((TOTAL_LABOUR_COST - LAG(TOTAL_LABOUR_COST) OVER (ORDER BY WEEK_NUM)) /
          NULLIF(LAG(TOTAL_LABOUR_COST) OVER (ORDER BY WEEK_NUM), 0), 4)          AS LABOUR_WOW_PCT
FROM FACT_HR_WEEKLY;


-- ============================================================
-- DONE — verify row counts
-- ============================================================
SELECT 'DIM_REGION'              AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM DIM_REGION
UNION ALL SELECT 'DIM_STORE_TYPE',                COUNT(*) FROM DIM_STORE_TYPE
UNION ALL SELECT 'DIM_STORE',                     COUNT(*) FROM DIM_STORE
UNION ALL SELECT 'DIM_DATE',                      COUNT(*) FROM DIM_DATE
UNION ALL SELECT 'FACT_DAILY_STORE_SALES',        COUNT(*) FROM FACT_DAILY_STORE_SALES
UNION ALL SELECT 'FACT_FINANCIAL_WEEKLY',         COUNT(*) FROM FACT_FINANCIAL_WEEKLY
UNION ALL SELECT 'FACT_SUPPLY_CHAIN_WEEKLY',      COUNT(*) FROM FACT_SUPPLY_CHAIN_WEEKLY
UNION ALL SELECT 'FACT_INVENTORY_WEEKLY',         COUNT(*) FROM FACT_INVENTORY_WEEKLY
UNION ALL SELECT 'FACT_CUSTOMER_WEEKLY',          COUNT(*) FROM FACT_CUSTOMER_WEEKLY
UNION ALL SELECT 'FACT_HR_WEEKLY',                COUNT(*) FROM FACT_HR_WEEKLY
ORDER BY 1;
