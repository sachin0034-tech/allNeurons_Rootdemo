-- ============================================================
-- ROOTS CANADA — JUNE 2026 DATA EXTENSION
-- Patches May 31 (missing from original ROWCOUNT=>150) and
-- adds June 1–30 daily sales + W23–W26 weekly aggregates.
-- Run against RETAIL_ANALYTICS.CORE after fresh_dataset.SQL
-- ============================================================

USE DATABASE RETAIL_ANALYTICS;
USE SCHEMA CORE;


-- ============================================================
-- 1. Patch DIM_DATE — May 31 + June 1–30 (31 new rows)
--    Original ROWCOUNT=>150 ends at May 30 (day 149 from Jan 1)
--    day 150 = May 31 · day 151 = Jun 1 · day 180 = Jun 30
-- ============================================================
INSERT INTO DIM_DATE (DATE_ID, WEEK_NUM, WEEK_LABEL, MONTH_NUM, MONTH_NAME,
                      QUARTER, FISCAL_YEAR, IS_WEEKEND)
WITH src AS (
    SELECT DATEADD(DAY, SEQ4() + 150, '2026-01-01')::DATE AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 31))
)
SELECT
    d,
    WEEKOFYEAR(d),
    'W' || LPAD(WEEKOFYEAR(d)::VARCHAR, 2, '0'),
    MONTH(d),
    MONTHNAME(d),
    QUARTER(d),
    YEAR(d),
    DAYOFWEEK(d) IN (1, 7)
FROM src
WHERE d NOT IN (SELECT DATE_ID FROM DIM_DATE);


-- ============================================================
-- 2. FACT_DAILY_STORE_SALES — May 31 + June 1–30
--    Same driver logic as original; adds MONTH_NUM=6 season mult
-- ============================================================
INSERT INTO FACT_DAILY_STORE_SALES (
    SALE_DATE, STORE_ID,
    TRANSACTIONS, TRAFFIC,
    NET_SALES, REG_PRICE_SALES, MARKDOWN_SALES, UNITS_SOLD,
    BUDGET_SALES, LY_NET_SALES, LY_TRAFFIC, LY_TRANSACTIONS
)
WITH base_rates AS (
    SELECT 'Mall'         AS ST, 4500  AS BASE_TRAFFIC, 42000 AS BASE_SALES, 0.1130 AS BASE_CVR, 0.745 AS BASE_FP
    UNION ALL SELECT 'Street',        580,   9500, 0.1650, 0.790
    UNION ALL SELECT 'Ski City',      620,   7200, 0.1270, 0.810
    UNION ALL SELECT 'Recall',        590,   6300, 0.1155, 0.740
    UNION ALL SELECT 'Power Centre',  110,   2400, 0.2280, 0.720
),
region_factors AS (
    SELECT REGION_CODE,
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
        rf.LY_SALES_MULT * tf.TYPE_SALES_MULT  AS LY_SALES_MULT,
        rf.LY_TRAFFIC_MULT                     AS LY_TRAFFIC_MULT,
        rf.LY_CVR_MULT  * tf.TYPE_CVR_MULT     AS LY_CVR_MULT,
        CASE WHEN d.IS_WEEKEND THEN 1.35 ELSE 1.0 END AS WEEKEND_MULT,
        CASE d.MONTH_NUM
            WHEN 1 THEN 1.10  WHEN 2 THEN 0.89  WHEN 3 THEN 0.94
            WHEN 4 THEN 1.02  WHEN 5 THEN 1.07  WHEN 6 THEN 1.08
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
    WHERE d.DATE_ID BETWEEN '2026-05-31' AND '2026-06-30'
      AND s.IS_ACTIVE = TRUE
)
SELECT
    DATE_ID,
    STORE_ID,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_CVR)              AS TRANSACTIONS,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE)                         AS TRAFFIC,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE, 2)                      AS NET_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * FP_MIX_TARGET, 2)     AS REG_PRICE_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * (1-FP_MIX_TARGET), 2) AS MARKDOWN_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE / 51.82)                 AS UNITS_SOLD,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * 1.06, 2)               AS BUDGET_SALES,
    ROUND(BASE_SALES   * WEEKEND_MULT * SEASON_MULT * NOISE * LY_SALES_MULT, 2)     AS LY_NET_SALES,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * LY_TRAFFIC_MULT)       AS LY_TRAFFIC,
    ROUND(BASE_TRAFFIC * WEEKEND_MULT * SEASON_MULT * NOISE * BASE_CVR * LY_CVR_MULT) AS LY_TRANSACTIONS
FROM cross_data;


-- ============================================================
-- 3. FACT_FINANCIAL_WEEKLY — W23–W26
--    W23 = Jun 8 · W24 = Jun 15 (Father's Day) · W25 = Jun 22 · W26 = Jun 29
--    (W22 already in table; its WEEK_START = DATEADD(WEEK,21,'2026-01-05') = Jun 1)
-- ============================================================
INSERT INTO FACT_FINANCIAL_WEEKLY
WITH weeks AS (
    SELECT WN AS WEEK_NUM,
           DATEADD(WEEK, WN - 1, '2026-01-05') AS WEEK_START,
           SEA, LY_MULT, BUD_MULT
    FROM (VALUES
        (23, 1.11, 1.035, 1.025),   -- Jun 8  – steady summer
        (24, 1.13, 1.033, 1.032),   -- Jun 15 – Father's Day lift
        (25, 1.10, 1.031, 1.018),   -- Jun 22 – post-holiday settle
        (26, 1.08, 1.028, 1.010)    -- Jun 29 – Canada Day pre-long-weekend
    ) AS t (WN, SEA, LY_MULT, BUD_MULT)
),
computed AS (
    SELECT
        WEEK_NUM, WEEK_START,
        ROUND(2050000 * SEA, 2)                          AS REVENUE,
        ROUND(2050000 * SEA / BUD_MULT, 2)               AS BUDGET_REVENUE,
        ROUND(2050000 * SEA * LY_MULT, 2)                AS LY_REVENUE,
        ROUND(2050000 * SEA * 0.585, 2)                  AS COGS,
        ROUND(2050000 * SEA * 0.415, 2)                  AS GROSS_MARGIN,
        ROUND(0.415, 4)                                  AS GM_PCT,
        ROUND(2050000 * SEA * 0.225, 2)                  AS EBITDA,
        ROUND(0.225, 4)                                  AS EBITDA_PCT,
        ROUND(2050000 * SEA * 0.180, 2)                  AS OPEX,
        ROUND(2050000 * SEA * 0.025, 2)                  AS DEPRECIATION,
        ROUND(2050000 * SEA * 0.200, 2)                  AS NET_OPERATING_INCOME
    FROM weeks
)
SELECT
    WEEK_NUM, WEEK_START,
    REVENUE, BUDGET_REVENUE, LY_REVENUE,
    ROUND((REVENUE - LY_REVENUE) / LY_REVENUE, 4)           AS REVENUE_YOY_PCT,
    COGS, GROSS_MARGIN, GM_PCT, EBITDA, EBITDA_PCT,
    OPEX, DEPRECIATION, NET_OPERATING_INCOME,
    ROUND(18400000 + (WEEK_NUM - 11) * 85000, 2)            AS CASH_POSITION,
    ROUND(REVENUE * 0.14, 2)                                AS ACCOUNTS_RECEIVABLE,
    ROUND(COGS    * 0.21, 2)                                AS ACCOUNTS_PAYABLE,
    ROUND(REVENUE - BUDGET_REVENUE, 2)                      AS BUDGET_VARIANCE,
    ROUND((REVENUE - BUDGET_REVENUE) / BUDGET_REVENUE, 4)  AS BUDGET_VARIANCE_PCT
FROM computed;


-- ============================================================
-- 4. FACT_SUPPLY_CHAIN_WEEKLY — W23–W26
--    OTD improving in June (no post-holiday congestion): 96.0–96.8%
-- ============================================================
INSERT INTO FACT_SUPPLY_CHAIN_WEEKLY
WITH weeks AS (
    SELECT WN AS WEEK_NUM,
           DATEADD(WEEK, WN - 1, '2026-01-05') AS WEEK_START,
           SEA
    FROM (VALUES (23, 1.11),(24, 1.13),(25, 1.10),(26, 1.08)) AS t (WN, SEA)
),
computed AS (
    SELECT
        WEEK_NUM, WEEK_START,
        ROUND(1200 * SEA)       AS SHIPS,
        ROUND(1200 * SEA) * 13  AS UNITS,
        95.8 + (WEEK_NUM - 22) * 0.2   AS OTD,
        124.50 + (WEEK_NUM * 0.35)     AS FRT_A
    FROM weeks
)
SELECT
    WEEK_NUM, WEEK_START,
    SHIPS                                                          AS TOTAL_SHIPMENTS,
    UNITS                                                          AS UNITS_SHIPPED,
    ROUND(SHIPS * OTD / 100)                                       AS ON_TIME_SHIPMENTS,
    ROUND(LEAST(OTD, 99.0), 2)                                     AS OTD_PCT,
    SHIPS - ROUND(SHIPS * OTD / 100)                               AS LATE_SHIPMENTS,
    ROUND(GREATEST(1.5, 2.8 - WEEK_NUM * 0.02), 2)                AS AVG_TRANSIT_DAYS,
    ROUND(SHIPS * FRT_A, 2)                                        AS TOTAL_FREIGHT_COST,
    ROUND(FRT_A, 2)                                                AS AVG_FREIGHT_PER_SHIPMENT,
    ROUND(SHIPS * 0.36)                                            AS FEDEX_SHIPMENTS,
    ROUND(SHIPS * 0.25)                                            AS UPS_SHIPMENTS,
    ROUND(SHIPS * 0.23)                                            AS CANADA_POST_SHIPMENTS,
    SHIPS - ROUND(SHIPS*0.36) - ROUND(SHIPS*0.25)
          - ROUND(SHIPS*0.23)                                      AS PUROLATOR_SHIPMENTS,
    ROUND(LEAST(96.8 + WEEK_NUM * 0.04, 99.5), 2)                  AS FILL_RATE_PCT
FROM computed;


-- ============================================================
-- 5. FACT_INVENTORY_WEEKLY — W23–W26
--    June: DC restocking ramp-up ahead of back-to-school
-- ============================================================
INSERT INTO FACT_INVENTORY_WEEKLY
WITH weeks AS (
    SELECT WN AS WEEK_NUM,
           DATEADD(WEEK, WN - 1, '2026-01-05') AS WEEK_START,
           INV_SEA
    FROM (VALUES (23, 0.99),(24, 1.01),(25, 1.02),(26, 1.04)) AS t (WN, INV_SEA)
)
SELECT
    WEEK_NUM, WEEK_START,
    ROUND(4200000 * INV_SEA, 2)                               AS TOTAL_INV_VALUE,
    3800 + WEEK_NUM * 18                                      AS ACTIVE_SKUS,
    5 + (WEEK_NUM - 22)                                       AS CRITICAL_SKUS,
    ROUND(LEAST(88.0, 75.0 + WEEK_NUM * 0.6), 2)             AS SELL_THRU_PCT,
    ROUND(GREATEST(22.0, 32.0 - WEEK_NUM * 0.45), 1)         AS DAYS_OF_STOCK,
    ROUND(52 / GREATEST(22.0, 32.0 - WEEK_NUM * 0.45), 2)   AS INV_TURNS,
    ROUND(4200000 * INV_SEA * 0.07, 2)                        AS MARKDOWN_RISK_VALUE,
    55 + WEEK_NUM * 2                                         AS REORDER_PENDING_SKUS,
    18000 + WEEK_NUM * 620                                    AS DC_INBOUND_UNITS,
    16000 + WEEK_NUM * 580                                    AS DC_OUTBOUND_UNITS,
    ROUND(GREATEST(96.5, 98.5 - WEEK_NUM * 0.04), 2)         AS INV_ACCURACY_PCT,
    280 + MOD(WEEK_NUM * 17, 200)                             AS SHRINK_UNITS
FROM weeks;


-- ============================================================
-- 6. FACT_CUSTOMER_WEEKLY — W23–W26
--    CSAT recovered from W15–W18 staffing-pressure dip
-- ============================================================
INSERT INTO FACT_CUSTOMER_WEEKLY
WITH weeks AS (
    SELECT WN AS WEEK_NUM,
           DATEADD(WEEK, WN - 1, '2026-01-05') AS WEEK_START
    FROM (VALUES (23),(24),(25),(26)) AS t (WN)
)
SELECT
    WEEK_NUM, WEEK_START,
    7800 + WEEK_NUM * 22                                          AS ACTIVE_CUSTOMERS,
    820  + WEEK_NUM * 3                                           AS NEW_CUSTOMERS,
    190  + WEEK_NUM                                               AS LAPSED_CUSTOMERS,
    300  + WEEK_NUM * 4                                           AS CHAMPION_COUNT,
    900  + WEEK_NUM * 12                                          AS LOYALIST_COUNT,
    GREATEST(0, 420 - WEEK_NUM * 8)                              AS AT_RISK_COUNT,
    2380 + WEEK_NUM * 18                                          AS AVG_LTV,
    (7800 + WEEK_NUM * 22) * (2380 + WEEK_NUM * 18)              AS TOTAL_LTV,
    ROUND(4.47, 2)                                                AS CSAT_SCORE,
    ROUND(42 + WEEK_NUM * 0.45, 1)                                AS NPS,
    ROUND(2.6  + WEEK_NUM * 0.01, 2)                              AS VISITS_PER_CUSTOMER,
    ROUND(28.5 + WEEK_NUM * 0.12, 2)                              AS EMAIL_OPEN_PCT,
    ROUND(GREATEST(1.4, 2.8 - WEEK_NUM * 0.06), 2)               AS CHURN_PCT
FROM weeks;


-- ============================================================
-- 7. FACT_HR_WEEKLY — W23–W26
--    Summer headcount creep; training intensive pre-back-to-school
-- ============================================================
INSERT INTO FACT_HR_WEEKLY
WITH weeks AS (
    SELECT WN AS WEEK_NUM,
           DATEADD(WEEK, WN - 1, '2026-01-05') AS WEEK_START
    FROM (VALUES (23),(24),(25),(26)) AS t (WN)
)
SELECT
    WEEK_NUM, WEEK_START,
    518 + WEEK_NUM - 10                                                       AS HEADCOUNT,
    83                                                                        AS STORE_COUNT_STAFFED,
    (518 + WEEK_NUM - 10) * 36                                                AS REG_HOURS,
    ROUND((518 + WEEK_NUM - 10) * 36 * 0.07)                                  AS OT_HOURS,
    ROUND((518 + WEEK_NUM - 10) * 36 * 1.07)                                  AS TOTAL_HOURS,
    ROUND(19.85 + WEEK_NUM * 0.03, 2)                                         AS AVG_WAGE_RATE,
    ROUND((518 + WEEK_NUM - 10) * 36 * (1 + 0.07 * 1.5)
          * (19.85 + WEEK_NUM * 0.03), 2)                                     AS TOTAL_LABOUR_COST,
    ROUND(26.5 + WEEK_NUM * 0.04, 2)                                          AS LABOUR_PCT_OF_SALES,
    7.00                                                                      AS OT_PCT,
    14 + MOD(WEEK_NUM, 4)                                                     AS ABSENT_DAYS,
    380 + WEEK_NUM * 8                                                        AS TRAINING_HOURS,
    ROUND(GREATEST(1.2, 2.4 - WEEK_NUM * 0.05), 2)                           AS TURNOVER_PCT
FROM weeks;


-- ============================================================
-- VERIFY — expected deltas vs fresh_dataset.SQL baseline:
--   DIM_DATE              +31  (May 31 + Jun 1–30)    → 181 total
--   FACT_DAILY_STORE_SALES +992 (31 days × 32 stores)  → ~5,888 total
--   each weekly fact table  +4  (W23–W26)              → 26 total
-- ============================================================
SELECT TABLE_NAME, COUNT(*) AS ROW_COUNT FROM (
    SELECT 'DIM_DATE'                  AS TABLE_NAME, DATE_ID       AS K FROM DIM_DATE
    UNION ALL SELECT 'FACT_FINANCIAL_WEEKLY',  WEEK_NUM::VARCHAR    FROM FACT_FINANCIAL_WEEKLY
    UNION ALL SELECT 'FACT_SUPPLY_CHAIN_WEEKLY', WEEK_NUM::VARCHAR  FROM FACT_SUPPLY_CHAIN_WEEKLY
    UNION ALL SELECT 'FACT_INVENTORY_WEEKLY',  WEEK_NUM::VARCHAR    FROM FACT_INVENTORY_WEEKLY
    UNION ALL SELECT 'FACT_CUSTOMER_WEEKLY',   WEEK_NUM::VARCHAR    FROM FACT_CUSTOMER_WEEKLY
    UNION ALL SELECT 'FACT_HR_WEEKLY',         WEEK_NUM::VARCHAR    FROM FACT_HR_WEEKLY
) GROUP BY TABLE_NAME
UNION ALL
SELECT 'FACT_DAILY_STORE_SALES', COUNT(*) FROM FACT_DAILY_STORE_SALES
ORDER BY TABLE_NAME;
