# Snowflake Schema Reference — RETAIL_ANALYTICS

This document describes every table, view, and staging object in the
`RETAIL_ANALYTICS` Snowflake database, explains how data flows from source
systems through to the Claude-powered analytics deck, and shows the exact SQL
views Claude queries for each slide.

---

## Database: RETAIL_ANALYTICS

---

## Schema: CORE (Production Data)

Production tables and views. All writes are performed by the ELT pipeline;
application code and Claude query read-only views only.

---

### FACT_DAILY_STORE_SALES

**Description:** Grain-level POS/store transaction facts. One row per
store per calendar day. Populated nightly from `STG_POS_STORES` after
dimension lookups and quality checks.

| Column            | Data Type        | Description                                          |
|-------------------|------------------|------------------------------------------------------|
| SALE_DATE         | DATE             | Calendar date of the sales period (PK component)     |
| STORE_ID          | INT              | FK → DIM_STORE.STORE_ID (PK component)               |
| TRANSACTIONS      | INT              | Count of completed tender transactions               |
| TRAFFIC           | INT              | Customer traffic count (door counter or footfall)    |
| NET_SALES         | DECIMAL(12,2)    | Net revenue after markdowns and returns              |
| REG_PRICE_SALES   | DECIMAL(12,2)    | Full-price (regular price) sales component           |
| MARKDOWN_SALES    | DECIMAL(12,2)    | Markdown / promotional sales component               |
| UNITS_SOLD        | INT              | Total units sold across all transactions             |
| BUDGET_SALES      | DECIMAL(12,2)    | Pre-loaded weekly budget prorated to daily level     |
| LY_NET_SALES      | DECIMAL(12,2)    | Prior-year net sales for same SALE_DATE (52-wk lag)  |
| LY_TRAFFIC        | INT              | Prior-year traffic count                             |
| LY_TRANSACTIONS   | INT              | Prior-year transaction count                         |

**Notes:**
- Composite primary key: `(SALE_DATE, STORE_ID)`
- `FP_MIX` (full-price mix %) is derived in views as `REG_PRICE_SALES / NULLIF(NET_SALES, 0)`
- `ADS` (average dollar sale) is derived as `NET_SALES / NULLIF(TRANSACTIONS, 0)`
- `UPT` (units per transaction) is derived as `UNITS_SOLD / NULLIF(TRANSACTIONS, 0)`
- `CVR` (conversion rate) is derived as `TRANSACTIONS / NULLIF(TRAFFIC, 0)`

---

### DIM_STORE

**Description:** Store master dimension. One row per physical store location.
Slowly changing dimension (Type 1 — overwrite for attribute changes).

| Column        | Data Type    | Description                                             |
|---------------|--------------|---------------------------------------------------------|
| STORE_ID      | INT          | Surrogate primary key                                   |
| STORE_NUM     | VARCHAR(10)  | Business-facing store number (e.g. "0042")              |
| STORE_NAME    | VARCHAR(100) | Full store name / display label                         |
| REGION_ID     | INT          | FK → DIM_REGION.REGION_ID                               |
| STORE_TYPE_ID | INT          | FK → DIM_STORE_TYPE.STORE_TYPE_ID                       |
| OPEN_DATE     | DATE         | Date store first opened for trade                       |
| IS_ACTIVE     | BOOLEAN      | TRUE if store is currently trading                      |
| IS_NSO        | BOOLEAN      | TRUE if store opened within the last 12 months (NSO)    |

---

### DIM_REGION

**Description:** Region master. Maps stores to geographic reporting regions.

| Column      | Data Type   | Description                                  |
|-------------|-------------|----------------------------------------------|
| REGION_ID   | INT         | Surrogate primary key                        |
| REGION_CODE | VARCHAR(4)  | Short code used in deck (e.g. "NE", "SE")    |
| REGION_NAME | VARCHAR(60) | Full region display name                     |

---

### DIM_STORE_TYPE

**Description:** Store format master. Classifies stores by physical format
(e.g. Flagship, Mall, Outlet, Convenience).

| Column          | Data Type    | Description                              |
|-----------------|--------------|------------------------------------------|
| STORE_TYPE_ID   | INT          | Surrogate primary key                    |
| STORE_TYPE_NAME | VARCHAR(60)  | Human-readable format label              |

---

### DIM_DATE

**Description:** Date dimension spanning the full analytical horizon.
Used for all time-based joins and fiscal week / month / quarter groupings.

| Column      | Data Type    | Description                                        |
|-------------|--------------|----------------------------------------------------|
| DATE_ID     | DATE         | Calendar date (primary key)                        |
| WEEK_NUM    | INT          | ISO week number (1–53)                             |
| WEEK_LABEL  | VARCHAR(20)  | Human-readable week label (e.g. "W24 2026")        |
| MONTH_NUM   | INT          | Calendar month number (1–12)                       |
| QUARTER_NUM | INT          | Calendar quarter (1–4)                             |

---

## Views (Read by Claude Skill)

All views join `FACT_DAILY_STORE_SALES` to dimension tables and compute
derived KPIs. Claude queries these views exclusively — it never reads raw
fact or staging tables.

---

### VW_WEEKLY_KPI

**Purpose:** Fleet-level (all stores combined) KPIs aggregated to week grain.
This is the primary view for the Executive Summary and header metrics on every slide.

**Key columns produced:**

| Column          | Description                                              |
|-----------------|----------------------------------------------------------|
| WEEK_LABEL      | Human-readable week label from DIM_DATE                  |
| NET_SALES       | Total fleet net sales for the week                       |
| LY_NET_SALES    | Prior-year net sales (52-week lag)                       |
| BUDGET_SALES    | Budget target for the week                               |
| TRAFFIC         | Total store traffic                                      |
| LY_TRAFFIC      | Prior-year traffic                                       |
| TRANSACTIONS    | Total transactions                                       |
| LY_TRANSACTIONS | Prior-year transactions                                  |
| UNITS_SOLD      | Total units sold                                         |
| ADS             | Average dollar sale (NET_SALES / TRANSACTIONS)           |
| LY_ADS          | Prior-year ADS                                           |
| UPT             | Units per transaction                                    |
| AUR             | Average unit retail (NET_SALES / UNITS_SOLD)             |
| FP_MIX          | Full-price mix % (REG_PRICE_SALES / NET_SALES)           |
| LY_FP_MIX       | Prior-year full-price mix %                              |

---

### VW_REGION_FP_MIX

**Purpose:** Full-price mix by region and week. Powers the regional FP strip
on Slide 2 (Revenue Performance) and the revenue region table.

**Key columns produced:**

| Column        | Description                                              |
|---------------|----------------------------------------------------------|
| WEEK_LABEL    | Week label                                               |
| REGION_CODE   | Short region code (from DIM_REGION)                      |
| REGION_NAME   | Full region name                                         |
| NET_SALES     | Region net sales for the week                            |
| LY_NET_SALES  | Prior-year region net sales                              |
| FP_MIX        | Full-price mix % for the region                          |
| LY_FP_MIX     | Prior-year full-price mix % for the region               |

---

### VW_STORE_TYPE_PERF

**Purpose:** Store type (format) performance by week. Powers the store type
table on Slide 3 (Store Operations).

**Key columns produced:**

| Column          | Description                                          |
|-----------------|------------------------------------------------------|
| WEEK_LABEL      | Week label                                           |
| STORE_TYPE_NAME | Format name (from DIM_STORE_TYPE)                    |
| NET_SALES       | Format net sales for the week                        |
| LY_NET_SALES    | Prior-year format net sales                          |
| TRAFFIC         | Format traffic count                                 |
| LY_TRAFFIC      | Prior-year traffic                                   |
| TRANSACTIONS    | Format transactions                                  |
| CVR             | Conversion rate                                      |
| LY_CVR          | Prior-year conversion rate                           |
| ADS             | Average dollar sale                                  |
| UPT             | Units per transaction                                |

---

### VW_REGION_WEEKLY_YOY

**Purpose:** Regional year-over-year comparisons by week. Used to rank regions
for the top/bottom region callouts in narratives and the revenue table.

**Key columns produced:**

| Column          | Description                                          |
|-----------------|------------------------------------------------------|
| WEEK_LABEL      | Week label                                           |
| REGION_CODE     | Short region code                                    |
| REGION_NAME     | Full region name                                     |
| NET_SALES       | Region net sales                                     |
| LY_NET_SALES    | Prior-year region net sales                          |
| SALES_YOY_PCT   | YoY change as decimal (e.g. 0.043 = +4.3%)          |
| TRAFFIC_YOY_PCT | Traffic YoY change as decimal                        |
| FP_MIX          | Current week full-price mix                          |
| LY_FP_MIX       | Prior-year full-price mix                            |

---

## Schema: STAGING (Pipeline Inputs)

Staging tables receive raw data from source systems via the ELT pipeline
(Fivetran / dbt or custom connectors). They are truncated and reloaded each
pipeline run. **Application code never queries staging directly.**

---

### STG_POS_STORES

**Source system:** POS / Store registers (proprietary retail POS platform)
**Feeds into:** `FACT_DAILY_STORE_SALES`

**Description:** Raw daily sales export from the point-of-sale system. One row
per store per business day. Includes all tender types, markdown flags, and
traffic counter reads.

| Column              | Data Type      | Description                                         |
|---------------------|----------------|-----------------------------------------------------|
| STORE_NUM           | VARCHAR(10)    | Store number as provided by POS                     |
| BUSINESS_DATE       | DATE           | Business date of the transaction summary            |
| GROSS_SALES         | DECIMAL(12,2)  | Gross sales before returns and markdowns            |
| RETURNS_AMOUNT      | DECIMAL(12,2)  | Total returns/refunds for the day                   |
| MARKDOWN_AMOUNT     | DECIMAL(12,2)  | Promotional and clearance markdown dollars          |
| NET_SALES           | DECIMAL(12,2)  | Gross sales minus returns (pre-markdown net)        |
| TRANSACTION_COUNT   | INT            | Number of completed transactions                    |
| UNITS_SOLD          | INT            | Units sold across all transactions                  |
| TRAFFIC_COUNT       | INT            | Door-counter footfall (null if counter offline)     |
| REG_PRICE_SALES     | DECIMAL(12,2)  | Full-price (regular) sales component                |
| LOADED_AT           | TIMESTAMP_NTZ  | Pipeline load timestamp                             |

---

### STG_3PL_LOGISTICS

**Source system:** 3PL / Carrier (third-party logistics provider API)
**Feeds into:** Supply chain metrics surfaced in Slide 4 (via a separate
`FACT_SHIPMENTS` table, cross-joined to weekly KPI roll-ups)

**Description:** Outbound shipment and delivery records from the 3PL provider.
Covers store replenishment, e-commerce fulfillment, and inter-DC transfers.

| Column               | Data Type      | Description                                          |
|----------------------|----------------|------------------------------------------------------|
| SHIPMENT_ID          | VARCHAR(30)    | Unique carrier shipment reference                    |
| ORIGIN_DC            | VARCHAR(10)    | Origin distribution centre code                      |
| DESTINATION_STORE    | VARCHAR(10)    | Destination store number (null for DC-to-DC)         |
| SHIP_DATE            | DATE           | Date shipment left origin                            |
| PROMISED_DATE        | DATE           | Committed delivery date                              |
| ACTUAL_DELIVERY_DATE | DATE           | Actual delivery date (null if in transit)            |
| ON_TIME_FLAG         | BOOLEAN        | TRUE if ACTUAL <= PROMISED                           |
| FREIGHT_COST         | DECIMAL(10,2)  | Carrier cost for this shipment                       |
| CARTON_COUNT         | INT            | Number of cartons in shipment                        |
| WEIGHT_KG            | DECIMAL(8,2)   | Total shipment weight                                |
| CARRIER_CODE         | VARCHAR(10)    | Carrier identifier (e.g. "UPS", "FEDEX")             |
| LOADED_AT            | TIMESTAMP_NTZ  | Pipeline load timestamp                              |

---

### STG_INVENTORY_WMS

**Source system:** Warehouse Management System (WMS)
**Feeds into:** Inventory aging, fill rate, and turns metrics on Slide 4

**Description:** Daily snapshot of inventory on-hand and on-order positions
from the WMS. One row per SKU per DC per snapshot date.

| Column           | Data Type      | Description                                          |
|------------------|----------------|------------------------------------------------------|
| SNAPSHOT_DATE    | DATE           | Date of the inventory snapshot                       |
| DC_CODE          | VARCHAR(10)    | Distribution centre code                             |
| SKU_ID           | VARCHAR(20)    | SKU identifier                                       |
| CATEGORY_CODE    | VARCHAR(10)    | Merchandise category code                            |
| UNITS_OH         | INT            | Units on hand at snapshot                            |
| UNITS_ON_ORDER   | INT            | Units on open purchase orders                        |
| UNITS_IN_TRANSIT | INT            | Units in transit from vendor or DC                   |
| COST_OH          | DECIMAL(12,2)  | Cost value of on-hand units                          |
| RECEIPT_DATE     | DATE           | Date units were last received into this DC           |
| AGE_DAYS         | INT            | Days since receipt (SNAPSHOT_DATE - RECEIPT_DATE)    |
| FILL_RATE_FLAG   | BOOLEAN        | TRUE if store order was fulfilled in full             |
| LOADED_AT        | TIMESTAMP_NTZ  | Pipeline load timestamp                              |

---

### STG_NETSUITE_FINANCE

**Source system:** NetSuite ERP (finance / GL)
**Feeds into:** Cash position, budget actuals, and budget variance metrics

**Description:** General ledger extracts and budget data from NetSuite. Provides
the authoritative cash balance, approved budget by week/cost centre, and
actuals for non-sales P&L lines.

| Column            | Data Type      | Description                                          |
|-------------------|----------------|------------------------------------------------------|
| GL_PERIOD         | DATE           | First day of the GL reporting period                 |
| COST_CENTRE       | VARCHAR(20)    | NetSuite cost centre / department code               |
| ACCOUNT_CODE      | VARCHAR(15)    | Chart-of-accounts code                               |
| ACCOUNT_NAME      | VARCHAR(100)   | Account display name                                 |
| ACTUAL_AMOUNT     | DECIMAL(14,2)  | Actual GL amount for the period                      |
| BUDGET_AMOUNT     | DECIMAL(14,2)  | Approved budget for the period                       |
| CASH_BALANCE      | DECIMAL(14,2)  | End-of-period cash balance (bank accounts only)      |
| CURRENCY_CODE     | VARCHAR(3)     | ISO currency code (e.g. "USD")                       |
| INTERCOMPANY_FLAG | BOOLEAN        | TRUE if intercompany / elimination entry             |
| LOADED_AT         | TIMESTAMP_NTZ  | Pipeline load timestamp                              |

---

### STG_CRM_CUSTOMER

**Source system:** CRM (Salesforce / Loyalty platform)
**Feeds into:** Customer segmentation metrics (future use; not yet in deck)

**Description:** Customer profile and loyalty transaction records from the CRM
platform. Supports future customer lifetime value and retention analysis.

| Column             | Data Type      | Description                                          |
|--------------------|----------------|------------------------------------------------------|
| CUSTOMER_ID        | VARCHAR(30)    | CRM customer identifier                              |
| LOYALTY_TIER       | VARCHAR(20)    | Loyalty programme tier (e.g. "Silver", "Gold")       |
| ACQUISITION_DATE   | DATE           | Date customer first made a purchase                  |
| LAST_PURCHASE_DATE | DATE           | Date of most recent purchase                         |
| LIFETIME_SPEND     | DECIMAL(12,2)  | Cumulative net spend since acquisition               |
| EMAIL_OPT_IN       | BOOLEAN        | TRUE if customer has opted into email marketing      |
| HOME_STORE_NUM     | VARCHAR(10)    | Store number most frequently shopped                 |
| REGION_CODE        | VARCHAR(4)     | Region derived from home store                       |
| TOTAL_VISITS_LTM   | INT            | Store visits in the last twelve months               |
| CHURN_RISK_SCORE   | DECIMAL(5,4)   | Model-scored churn probability (0.0000–1.0000)       |
| LOADED_AT          | TIMESTAMP_NTZ  | Pipeline load timestamp                              |

---

### STG_HR_LABOUR

**Source system:** HR / Labour management system (Kronos / UKG)
**Feeds into:** Labour cost metrics (future use; not yet in deck)

**Description:** Weekly labour hours, wages, and headcount by store and
department. Used for labour cost as a percentage of sales analysis.

| Column            | Data Type      | Description                                          |
|-------------------|----------------|------------------------------------------------------|
| PAY_PERIOD_END    | DATE           | Last day of the pay period                           |
| STORE_NUM         | VARCHAR(10)    | Store number                                         |
| DEPARTMENT_CODE   | VARCHAR(15)    | Department / cost-centre code within store           |
| EMPLOYEE_TYPE     | VARCHAR(20)    | Employment classification (FT / PT / Casual)         |
| HEADCOUNT         | INT            | Active headcount at period end                       |
| HOURS_WORKED      | DECIMAL(10,2)  | Actual hours worked in the period                    |
| HOURS_SCHEDULED   | DECIMAL(10,2)  | Scheduled hours for the period                       |
| GROSS_WAGES       | DECIMAL(12,2)  | Total gross wages paid                               |
| OVERTIME_HOURS    | DECIMAL(10,2)  | Hours worked above straight-time threshold           |
| TURNOVER_FLAG     | BOOLEAN        | TRUE if any terminations occurred in the period      |
| LOADED_AT         | TIMESTAMP_NTZ  | Pipeline load timestamp                              |

---

## Data Flow Diagram

```
SOURCE SYSTEMS                STAGING (RETAIL_ANALYTICS.STAGING)
─────────────                 ──────────────────────────────────
POS / Registers      ──────► STG_POS_STORES
3PL / Carrier API    ──────► STG_3PL_LOGISTICS
Warehouse WMS        ──────► STG_INVENTORY_WMS
NetSuite ERP         ──────► STG_NETSUITE_FINANCE
CRM / Loyalty        ──────► STG_CRM_CUSTOMER
HR / Labour (UKG)    ──────► STG_HR_LABOUR
                                       │
                                       │  nightly ELT
                                       ▼
                     FACTS (RETAIL_ANALYTICS.CORE)
                     ────────────────────────────
                     FACT_DAILY_STORE_SALES   ◄── STG_POS_STORES
                     FACT_SHIPMENTS           ◄── STG_3PL_LOGISTICS
                     FACT_INVENTORY_SNAPSHOT  ◄── STG_INVENTORY_WMS
                     FACT_GL_ACTUALS          ◄── STG_NETSUITE_FINANCE
                                       │
                                       │  view layer (no data movement)
                                       ▼
                     VIEWS (RETAIL_ANALYTICS.CORE)
                     ─────────────────────────────
                     VW_WEEKLY_KPI
                     VW_REGION_FP_MIX
                     VW_STORE_TYPE_PERF
                     VW_REGION_WEEKLY_YOY
                                       │
                                       │  read-only SQL queries
                                       ▼
                     ┌─────────────────────────────┐
                     │   Claude Skill / Analyst    │
                     │  (utils/queries.py +        │
                     │   utils/narrative.py)       │
                     └─────────────────────────────┘
                                       │
                                       │  structured data + narratives
                                       ▼
                     ┌─────────────────────────────┐
                     │  Streamlit App (Home.py)    │
                     │  + deck_builder_light.py    │
                     │  → 5-slide .pptx download   │
                     └─────────────────────────────┘
```

---

## How Claude Reads the Data

Claude (via `utils/queries.py` and `utils/narrative.py`) issues read-only
queries against the view layer. No Claude component ever writes to or reads
from staging or raw fact tables.

### Slide 1 — Executive Summary

**View:** `VW_WEEKLY_KPI`

```sql
SELECT
    WEEK_LABEL,
    NET_SALES,
    LY_NET_SALES,
    BUDGET_SALES,
    TRAFFIC,
    LY_TRAFFIC,
    TRANSACTIONS,
    LY_TRANSACTIONS,
    ADS,
    LY_ADS,
    UPT,
    FP_MIX,
    LY_FP_MIX
FROM RETAIL_ANALYTICS.CORE.VW_WEEKLY_KPI
WHERE WEEK_LABEL = :week_label;
```

**Fields used in deck:**
- `NET_SALES` / `LY_NET_SALES` / `BUDGET_SALES` → Revenue hero block + YoY / vs Budget badges
- `TRAFFIC` / `LY_TRAFFIC` → Traffic YoY hero block
- Derived `inventory_turns` and `cash_position` are currently hardcoded
  defaults pending `FACT_INVENTORY_SNAPSHOT` and `FACT_GL_ACTUALS` integration

---

### Slide 2 — Revenue Performance

**View:** `VW_REGION_FP_MIX`

```sql
SELECT
    REGION_CODE,
    REGION_NAME,
    NET_SALES,
    LY_NET_SALES,
    FP_MIX,
    LY_FP_MIX
FROM RETAIL_ANALYTICS.CORE.VW_REGION_FP_MIX
WHERE WEEK_LABEL = :week_label
ORDER BY NET_SALES DESC;
```

**Fields used in deck:**
- `REGION_CODE` → row label in region table
- `NET_SALES` / `LY_NET_SALES` → CY SALES / LY SALES columns; YoY computed in Python
- `FP_MIX` / `LY_FP_MIX` → FP mix bar chart strip (right panel)
- Budget column is derived: `NET_SALES * budget_factor` (from `VW_WEEKLY_KPI`)

**Also used:** `VW_REGION_WEEKLY_YOY` to rank regions for narrative
top/bottom callouts:

```sql
SELECT REGION_CODE, SALES_YOY_PCT
FROM RETAIL_ANALYTICS.CORE.VW_REGION_WEEKLY_YOY
WHERE WEEK_LABEL = :week_label
ORDER BY SALES_YOY_PCT DESC;
```

---

### Slide 3 — Store Operations

**View:** `VW_STORE_TYPE_PERF`

```sql
SELECT
    STORE_TYPE_NAME,
    NET_SALES,
    LY_NET_SALES,
    TRAFFIC,
    LY_TRAFFIC,
    TRANSACTIONS,
    CVR,
    LY_CVR,
    ADS,
    UPT
FROM RETAIL_ANALYTICS.CORE.VW_STORE_TYPE_PERF
WHERE WEEK_LABEL = :week_label
ORDER BY NET_SALES DESC;
```

**Fields used in deck:**
- `STORE_TYPE_NAME` → row label in store type table
- `NET_SALES` / `LY_NET_SALES` → SALES + SALES YoY columns
- `TRAFFIC` → TRAFFIC column
- `CVR` / `LY_CVR` → CVR column + CVR delta badge
- `ADS` → ADS column
- `UPT` → UPT column

Fleet-level KPI blocks at the top of the slide come from `VW_WEEKLY_KPI`
(same query as Slide 1).

---

### Slide 4 — Supply Chain & 3PL

**Current state:** Supply chain KPIs (OTD%, freight cost YoY, inventory aging,
fill rate, inventory turns) are populated from hardcoded defaults in
`utils/deck_builder_light.py` pending full integration of `FACT_SHIPMENTS`
and `FACT_INVENTORY_SNAPSHOT`.

**Planned query against `VW_SUPPLY_CHAIN_WEEKLY` (to be created):**

```sql
-- Future view — not yet live
SELECT
    WEEK_LABEL,
    OTD_PCT,
    LY_OTD_PCT,
    FREIGHT_COST_YOY,
    AVG_INVENTORY_AGE_DAYS,
    FILL_RATE,
    LY_FILL_RATE,
    INVENTORY_TURNS_ANN,
    LY_INVENTORY_TURNS_ANN
FROM RETAIL_ANALYTICS.CORE.VW_SUPPLY_CHAIN_WEEKLY
WHERE WEEK_LABEL = :week_label;
```

---

### Slide 5 — Risks & Opportunities

Slide 5 content is **entirely Claude-generated narrative** — no direct
Snowflake query. Claude's `generate_narratives()` function in
`utils/narrative.py` synthesises:

1. The structured KPI data retrieved from the views above
2. External web search results (Claude tool use) for macro/market signals
3. Its own chain-of-thought reasoning about risk and opportunity themes

The output is a structured dict with `risks`, `opportunities`, and `sources`
keys, which `build_deck_light()` renders directly onto the slide.

---

## Column Naming Conventions

| Pattern       | Meaning                                              |
|---------------|------------------------------------------------------|
| `LY_*`        | Prior-year equivalent of the column (52-week lag)    |
| `*_YOY`       | Year-over-year change as decimal (e.g. 0.043 = 4.3%) |
| `*_BPS`       | Change expressed in basis points                     |
| `*_PCT`       | Value already expressed as a percentage decimal      |
| `BUDGET_*`    | Pre-approved plan/budget value                       |
| `STG_*`       | Staging table (pipeline input, not for app queries)  |
| `VW_*`        | View (safe for application and Claude queries)       |
| `FACT_*`      | Fact table (pipeline writes only)                    |
| `DIM_*`       | Dimension table (pipeline writes only)               |

---

## Access & Security Notes

- All application service accounts are granted `SELECT` on `CORE` views only.
- No `SELECT` grants exist on `STAGING` schema for application roles.
- Claude's Snowflake connector (`utils/snowflake_conn.py`) uses a dedicated
  `ANALYST_ROLE` with read-only warehouse binding (`ANALYST_WH`).
- PII columns in `STG_CRM_CUSTOMER` (email, loyalty ID) are masked using
  Snowflake Dynamic Data Masking for non-DBA roles.
