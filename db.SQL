-- ============================================================
-- RETAIL ANALYTICS - SNOWFLAKE DDL (FIXED)
-- ============================================================

CREATE DATABASE IF NOT EXISTS RETAIL_ANALYTICS;
USE DATABASE RETAIL_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS CORE;
USE SCHEMA CORE;

-- ── DIMENSIONS ──────────────────────────────────────────────

CREATE OR REPLACE TABLE DIM_REGION (
    REGION_ID     NUMBER AUTOINCREMENT PRIMARY KEY,
    REGION_CODE   VARCHAR(5)  NOT NULL,
    REGION_NAME   VARCHAR(50) NOT NULL,
    COUNTRY       VARCHAR(50) DEFAULT 'Canada'
);

INSERT INTO DIM_REGION (REGION_CODE, REGION_NAME, COUNTRY) VALUES
('NB',  'New Brunswick',     'Canada'),
('BC',  'British Columbia',  'Canada'),
('MB',  'Manitoba',          'Canada'),
('NL',  'Newfoundland',      'Canada'),
('AB',  'Alberta',           'Canada'),
('QC',  'Quebec',            'Canada'),
('ON',  'Ontario',           'Canada'),
('NS',  'Nova Scotia',       'Canada'),
('SK',  'Saskatchewan',      'Canada'),
('UT',  'Utah',              'USA'),
('MI',  'Michigan',          'USA');

CREATE OR REPLACE TABLE DIM_STORE_TYPE (
    STORE_TYPE_ID   NUMBER AUTOINCREMENT PRIMARY KEY,
    STORE_TYPE_NAME VARCHAR(50) NOT NULL
);

INSERT INTO DIM_STORE_TYPE (STORE_TYPE_NAME) VALUES
('Mall'), ('Street'), ('Ski City'), ('Recall'), ('Power Centre');

CREATE OR REPLACE TABLE DIM_STORE (
    STORE_ID        NUMBER AUTOINCREMENT PRIMARY KEY,
    STORE_NUM       NUMBER(5)    NOT NULL,
    STORE_NAME      VARCHAR(100) NOT NULL,
    STORE_TYPE_ID   NUMBER       REFERENCES DIM_STORE_TYPE(STORE_TYPE_ID),
    REGION_ID       NUMBER       REFERENCES DIM_REGION(REGION_ID),
    OPEN_DATE       DATE,
    IS_NSO          BOOLEAN DEFAULT FALSE,
    IS_ACTIVE       BOOLEAN DEFAULT TRUE
);

-- FIXED: use INSERT INTO ... SELECT with JOINs (no subqueries in VALUES)
INSERT INTO DIM_STORE (STORE_NUM, STORE_NAME, STORE_TYPE_ID, REGION_ID, OPEN_DATE, IS_NSO)
SELECT v.STORE_NUM, v.STORE_NAME, st.STORE_TYPE_ID, r.REGION_ID, v.OPEN_DATE::DATE, v.IS_NSO
FROM (
    VALUES
    (402, 'Lynden Park Mall',     'Mall',          'ON', '2025-07-29', TRUE),
    (452, 'Quinte Mall Kids',     'Mall',          'ON', '2025-07-30', TRUE),
    (239, 'MTL Premium Outlets',  'Mall',          'QC', '2025-08-15', TRUE),
    (156, 'Vaughan Mills',        'Mall',          'ON', '2025-04-17', FALSE),
    (211, 'Peterborough',         'Recall',        'ON', '2025-02-26', FALSE),
    (101, 'Sherway Gardens',      'Mall',          'ON', '2020-01-15', FALSE),
    (102, 'Oshawa Centre',        'Mall',          'ON', '2019-03-10', FALSE),
    (103, 'Georgian Mall',        'Mall',          'ON', '2018-06-01', FALSE),
    (104, 'Rideau Centre',        'Mall',          'ON', '2017-11-20', FALSE),
    (105, 'Yorkdale',             'Mall',          'ON', '2016-09-15', FALSE),
    (201, 'Pacific Centre',       'Mall',          'BC', '2018-04-01', FALSE),
    (202, 'Metrotown',            'Mall',          'BC', '2019-07-15', FALSE),
    (203, 'Park Royal',           'Street',        'BC', '2020-02-01', FALSE),
    (301, 'Chinook Centre',       'Mall',          'AB', '2017-05-10', FALSE),
    (302, 'West Edmonton Mall',   'Mall',          'AB', '2018-08-20', FALSE),
    (303, 'Southgate',            'Power Centre',  'AB', '2019-01-15', FALSE),
    (401, 'Carrefour Laval',      'Mall',          'QC', '2018-03-01', FALSE),
    (403, 'Place Ste-Foy',        'Mall',          'QC', '2019-06-10', FALSE),
    (501, 'MicMac Mall',          'Mall',          'NS', '2020-01-10', FALSE),
    (502, 'Dartmouth Crossing',   'Power Centre',  'NS', '2021-04-15', FALSE),
    (601, 'Polo Park',            'Mall',          'MB', '2018-07-01', FALSE),
    (602, 'St. Vital',            'Mall',          'MB', '2019-10-20', FALSE),
    (701, 'Cornwall Centre',      'Mall',          'SK', '2019-03-05', FALSE),
    (702, 'River Heights',        'Street',        'SK', '2020-07-01', FALSE),
    (801, 'Avalon Mall',          'Mall',          'NL', '2018-09-15', FALSE),
    (901, 'Regent Mall',          'Mall',          'NB', '2019-02-14', FALSE),
    (902, 'McAllister Place',     'Power Centre',  'NB', '2020-05-01', FALSE),
    (111, 'Park City Center',     'Ski City',      'UT', '2018-12-01', FALSE),
    (112, 'Deer Valley Ski Shop', 'Ski City',      'UT', '2019-11-15', FALSE),
    (113, 'Brighton Ski City',    'Ski City',      'UT', '2020-10-01', FALSE),
    (121, 'Somerset Collection',  'Mall',          'MI', '2018-06-20', FALSE),
    (122, 'Great Lakes Crossing', 'Ski City',      'MI', '2019-09-10', FALSE)
) AS v (STORE_NUM, STORE_NAME, STORE_TYPE_NAME, REGION_CODE, OPEN_DATE, IS_NSO)
JOIN DIM_STORE_TYPE st ON st.STORE_TYPE_NAME = v.STORE_TYPE_NAME
JOIN DIM_REGION     r  ON r.REGION_CODE      = v.REGION_CODE;

-- Date dimension (Jan 1 – Jun 16 2026)
CREATE OR REPLACE TABLE DIM_DATE (
    DATE_ID     DATE PRIMARY KEY,
    WEEK_NUM    NUMBER(3),
    WEEK_LABEL  VARCHAR(10),
    MONTH_NUM   NUMBER(2),
    MONTH_NAME  VARCHAR(15),
    QUARTER     NUMBER(1),
    FISCAL_YEAR NUMBER(4),
    IS_WEEKEND  BOOLEAN
);

INSERT INTO DIM_DATE
SELECT
    DATEADD(DAY, SEQ4(), '2026-01-01')::DATE                                           AS DATE_ID,
    WEEKOFYEAR(DATEADD(DAY, SEQ4(), '2026-01-01'))                                     AS WEEK_NUM,
    'W' || LPAD(WEEKOFYEAR(DATEADD(DAY, SEQ4(), '2026-01-01'))::VARCHAR, 2, '0')       AS WEEK_LABEL,
    MONTH(DATEADD(DAY, SEQ4(), '2026-01-01'))                                          AS MONTH_NUM,
    MONTHNAME(DATEADD(DAY, SEQ4(), '2026-01-01'))                                      AS MONTH_NAME,
    QUARTER(DATEADD(DAY, SEQ4(), '2026-01-01'))                                        AS QUARTER,
    YEAR(DATEADD(DAY, SEQ4(), '2026-01-01'))                                           AS FISCAL_YEAR,
    DAYOFWEEK(DATEADD(DAY, SEQ4(), '2026-01-01')) IN (1, 7)                            AS IS_WEEKEND
FROM TABLE(GENERATOR(ROWCOUNT => 167));

-- ── FACT TABLE ───────────────────────────────────────────────

CREATE OR REPLACE TABLE FACT_DAILY_STORE_SALES (
    SALE_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    SALE_DATE         DATE         NOT NULL,
    STORE_ID          NUMBER       REFERENCES DIM_STORE(STORE_ID),
    TRANSACTIONS      NUMBER(8),
    TRAFFIC           NUMBER(8),
    NET_SALES         NUMBER(14,2),
    REG_PRICE_SALES   NUMBER(14,2),
    MARKDOWN_SALES    NUMBER(14,2),
    UNITS_SOLD        NUMBER(8),
    BUDGET_SALES      NUMBER(14,2),
    LY_NET_SALES      NUMBER(14,2),
    LY_TRAFFIC        NUMBER(8),
    LY_TRANSACTIONS   NUMBER(8)
);

INSERT INTO FACT_DAILY_STORE_SALES (
    SALE_DATE, STORE_ID,
    TRANSACTIONS, TRAFFIC,
    NET_SALES, REG_PRICE_SALES, MARKDOWN_SALES, UNITS_SOLD,
    BUDGET_SALES, LY_NET_SALES, LY_TRAFFIC, LY_TRANSACTIONS
)
WITH base_rates AS (
    SELECT 'Mall'          AS STORE_TYPE_NAME, 4500 AS BASE_TRAFFIC, 42000 AS BASE_SALES, 0.1130 AS BASE_CVR, 0.745 AS BASE_FP_MIX
    UNION ALL SELECT 'Street',        580,   9500,  0.1650, 0.790
    UNION ALL SELECT 'Ski City',      620,   7200,  0.1270, 0.810
    UNION ALL SELECT 'Recall',        590,   6300,  0.1155, 0.740
    UNION ALL SELECT 'Power Centre',  110,   2400,  0.2280, 0.720
),
cross_data AS (
    SELECT
        d.DATE_ID,
        s.STORE_ID,
        b.BASE_TRAFFIC,
        b.BASE_SALES,
        b.BASE_CVR,
        b.BASE_FP_MIX,
        CASE WHEN DAYOFWEEK(d.DATE_ID) IN (1, 7) THEN 1.35 ELSE 1.0 END AS WEEKEND_MULT,
        CASE
            WHEN MONTH(d.DATE_ID) IN (1, 2) THEN 0.88
            WHEN MONTH(d.DATE_ID) IN (3, 4) THEN 0.95
            WHEN MONTH(d.DATE_ID) IN (5, 6) THEN 1.05
            ELSE 1.0
        END AS SEASON_MULT,
        (0.88 + UNIFORM(0, 0.24, RANDOM())) AS NOISE
    FROM DIM_DATE d
    CROSS JOIN DIM_STORE s
    JOIN DIM_STORE_TYPE st ON s.STORE_TYPE_ID = st.STORE_TYPE_ID
    JOIN base_rates b       ON st.STORE_TYPE_NAME = b.STORE_TYPE_NAME
    WHERE d.DATE_ID BETWEEN '2026-01-01' AND '2026-06-16'
      AND s.IS_ACTIVE = TRUE
)
SELECT
    DATE_ID,
    STORE_ID,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_CVR)     AS TRANSACTIONS,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE)                AS TRAFFIC,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE, 2)             AS NET_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_FP_MIX, 2)          AS REG_PRICE_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * (1 - BASE_FP_MIX), 2)    AS MARKDOWN_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE / 51.82)        AS UNITS_SOLD,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * 1.06, 2)      AS BUDGET_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * 1.04, 2)      AS LY_NET_SALES,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * 0.93)         AS LY_TRAFFIC,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_CVR * 1.05) AS LY_TRANSACTIONS
FROM cross_data;

-- ── VIEWS ────────────────────────────────────────────────────

CREATE OR REPLACE VIEW VW_WEEKLY_KPI AS
SELECT
    d.WEEK_NUM,
    d.WEEK_LABEL,
    MIN(d.DATE_ID)                                                             AS WEEK_START,
    SUM(f.NET_SALES)                                                           AS NET_SALES,
    SUM(f.TRAFFIC)                                                             AS TRAFFIC,
    SUM(f.TRANSACTIONS)                                                        AS TRANSACTIONS,
    SUM(f.UNITS_SOLD)                                                          AS UNITS_SOLD,
    ROUND(SUM(f.NET_SALES)   / NULLIF(SUM(f.TRANSACTIONS), 0), 2)             AS ADS,
    ROUND(SUM(f.UNITS_SOLD)  / NULLIF(SUM(f.TRANSACTIONS), 0), 2)             AS UPT,
    ROUND(SUM(f.NET_SALES)   / NULLIF(SUM(f.UNITS_SOLD),   0), 2)             AS AUR,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0), 4)            AS FP_MIX,
    SUM(f.LY_NET_SALES)                                                        AS LY_NET_SALES,
    SUM(f.LY_TRAFFIC)                                                          AS LY_TRAFFIC,
    SUM(f.LY_TRANSACTIONS)                                                     AS LY_TRANSACTIONS,
    SUM(f.BUDGET_SALES)                                                        AS BUDGET_SALES,
    ROUND(SUM(f.LY_NET_SALES) / NULLIF(SUM(f.LY_TRANSACTIONS), 0), 2)         AS LY_ADS,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0) + 0.035, 4)   AS LY_FP_MIX
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE d ON f.SALE_DATE = d.DATE_ID
GROUP BY d.WEEK_NUM, d.WEEK_LABEL;

CREATE OR REPLACE VIEW VW_REGION_FP_MIX AS
SELECT
    r.REGION_CODE,
    r.REGION_NAME,
    d.WEEK_NUM,
    SUM(f.NET_SALES)                                                      AS NET_SALES,
    SUM(f.REG_PRICE_SALES)                                                AS REG_PRICE_SALES,
    SUM(f.TRAFFIC)                                                        AS TRAFFIC,
    SUM(f.TRANSACTIONS)                                                   AS TRANSACTIONS,
    SUM(f.LY_NET_SALES)                                                   AS LY_NET_SALES,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0), 4)       AS FP_MIX,
    ROUND(SUM(f.REG_PRICE_SALES) / NULLIF(SUM(f.NET_SALES), 0) + 0.035, 4) AS LY_FP_MIX
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE   d ON f.SALE_DATE  = d.DATE_ID
JOIN DIM_STORE  s ON f.STORE_ID   = s.STORE_ID
JOIN DIM_REGION r ON s.REGION_ID  = r.REGION_ID
GROUP BY r.REGION_CODE, r.REGION_NAME, d.WEEK_NUM;

CREATE OR REPLACE VIEW VW_STORE_TYPE_PERF AS
SELECT
    st.STORE_TYPE_NAME,
    d.WEEK_NUM,
    SUM(f.NET_SALES)                                                       AS NET_SALES,
    SUM(f.TRAFFIC)                                                         AS TRAFFIC,
    SUM(f.TRANSACTIONS)                                                    AS TRANSACTIONS,
    SUM(f.UNITS_SOLD)                                                      AS UNITS_SOLD,
    ROUND(SUM(f.NET_SALES)    / NULLIF(SUM(f.TRANSACTIONS), 0), 2)        AS ADS,
    ROUND(SUM(f.UNITS_SOLD)   / NULLIF(SUM(f.TRANSACTIONS), 0), 2)        AS UPT,
    ROUND(SUM(f.TRANSACTIONS) / NULLIF(SUM(f.TRAFFIC),      0), 4)        AS CVR,
    SUM(f.LY_NET_SALES)                                                    AS LY_NET_SALES,
    SUM(f.LY_TRAFFIC)                                                      AS LY_TRAFFIC,
    SUM(f.LY_TRANSACTIONS)                                                 AS LY_TRANSACTIONS,
    ROUND(SUM(f.LY_TRANSACTIONS) / NULLIF(SUM(f.LY_TRAFFIC), 0), 4)       AS LY_CVR,
    ROUND(SUM(f.LY_NET_SALES)    / NULLIF(SUM(f.LY_TRANSACTIONS), 0), 2)  AS LY_ADS
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE       d  ON f.SALE_DATE     = d.DATE_ID
JOIN DIM_STORE      s  ON f.STORE_ID      = s.STORE_ID
JOIN DIM_STORE_TYPE st ON s.STORE_TYPE_ID = st.STORE_TYPE_ID
GROUP BY st.STORE_TYPE_NAME, d.WEEK_NUM;

CREATE OR REPLACE VIEW VW_REGION_WEEKLY_YOY AS
SELECT
    r.REGION_CODE,
    d.WEEK_NUM,
    SUM(f.NET_SALES)                                                           AS CY_SALES,
    SUM(f.LY_NET_SALES)                                                        AS LY_SALES,
    SUM(f.TRAFFIC)                                                             AS CY_TRAFFIC,
    SUM(f.LY_TRAFFIC)                                                          AS LY_TRAFFIC,
    ROUND(SUM(f.TRANSACTIONS)    / NULLIF(SUM(f.TRAFFIC),    0), 4)            AS CY_CVR,
    ROUND(SUM(f.LY_TRANSACTIONS) / NULLIF(SUM(f.LY_TRAFFIC), 0), 4)           AS LY_CVR,
    ROUND((SUM(f.NET_SALES)    - SUM(f.LY_NET_SALES)) / NULLIF(SUM(f.LY_NET_SALES), 0), 4) AS SALES_YOY_PCT,
    ROUND((SUM(f.TRAFFIC)      - SUM(f.LY_TRAFFIC))   / NULLIF(SUM(f.LY_TRAFFIC),   0), 4) AS TRAFFIC_YOY_PCT,
    ROUND(
        (SUM(f.TRANSACTIONS)    / NULLIF(SUM(f.TRAFFIC),    0)) -
        (SUM(f.LY_TRANSACTIONS) / NULLIF(SUM(f.LY_TRAFFIC), 0)),
        4
    ) AS CVR_DELTA_BPS
FROM FACT_DAILY_STORE_SALES f
JOIN DIM_DATE   d ON f.SALE_DATE = d.DATE_ID
JOIN DIM_STORE  s ON f.STORE_ID  = s.STORE_ID
JOIN DIM_REGION r ON s.REGION_ID = r.REGION_ID
GROUP BY r.REGION_CODE, d.WEEK_NUM;