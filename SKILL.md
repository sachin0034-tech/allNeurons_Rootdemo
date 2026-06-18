
skill:
  name: Roots Canada WBR Intelligence
  version: "1.1"
  format: claude-projects-knowledge
  purpose: >
    When loaded as a Claude.ai Project knowledge document, this skill enables Claude
    to answer Weekly Business Review questions, generate 5-slide executive summaries,
    and interpret retail KPIs for Roots Canada. Claude reads only from pre-built views
    in Snowflake — never raw tables. The skill defines what data exists, what each
    metric means, and exactly how to present it.

# ─────────────────────────────────────────────
# COMPANY CONTEXT
# ─────────────────────────────────────────────
company:
  name: Roots Canada Ltd.
  category: Outdoor lifestyle and apparel retail
  store_count: 83
  regions:
    canada: [ON, QC, BC, AB, MB, NS, SK, NL, NB]
    usa: [UT, MI]
  store_types:
    - Mall
    - Street
    - Ski City
    - Recall          # outlet/clearance format
    - Power Centre
  fiscal_calendar:
    week_1_start: "2026-01-05"
    week_numbering: W01 to W52
  data_coverage:
    weeks: W01–W22
    dates: "January 5 – May 31, 2026"
    total_weeks: 22
  performance_context: >
    Fleet-level revenue is tracking -2.1% to -5.0% YoY depending on region and period.
    January clearance is the strongest week (seasonal index ~1.12). Post-holiday dip
    runs W03–W08 (seasonal index 0.87–0.93). Spring recovery builds from W09 onward.
    Full-price mix is the primary margin lever; target >74% fleet average.

# ─────────────────────────────────────────────
# TRIGGER PHRASES
# ─────────────────────────────────────────────
triggers:
  full_deck:
    - "WBR"
    - "weekly business review"
    - "executive deck"
    - "generate deck"
    - "create a deck"
    - "create presentation"
    - "run the WBR"
    - "WBR for week [N]"
    - "deck for week [N]"
    - "week [N] performance"
  quick_summary:
    - "weekly report"
    - "how did we do this week"
    - "what were our sales"
    - "recap week [N]"
  week_identification:
    explicit: Use the WEEK_NUM stated by the user (e.g. "week 22" → WEEK_NUM = 22)
    implicit_latest: >
      If the user says "this week" or "latest week" without specifying,
      use WEEK_NUM = 22 (week ending May 31, 2026).
    date_range: Map month references to WEEK_NUMs (e.g. "May" → W18–W22).
    ambiguous: >
      Ask: "Which week would you like — the most recent (W22, ending May 31)
      or a specific earlier week?"

# ─────────────────────────────────────────────
# SNOWFLAKE DATA SCHEMA
# ─────────────────────────────────────────────
database: RETAIL_ANALYTICS
schema: CORE
rule: Query views only — never query FACT_* or STG_* tables directly.

views:
  - name: VW_WEEKLY_KPI
    description: Fleet-level weekly POS KPIs aggregated from all active stores.
    filter_by: WEEK_NUM
    key_columns:
      - WEEK_NUM, WEEK_LABEL, WEEK_START
      - NET_SALES                 # total CY net revenue
      - LY_NET_SALES              # same week last year revenue
      - BUDGET_SALES              # budgeted revenue
      - TRAFFIC                   # total store traffic (footfall)
      - LY_TRAFFIC                # prior year traffic
      - TRANSACTIONS              # total transaction count
      - LY_TRANSACTIONS           # prior year transactions
      - ADS                       # average dollar sale (Net Sales / Transactions)
      - LY_ADS                    # prior year ADS
      - UPT                       # units per transaction
      - AUR                       # average unit retail (Net Sales / Units Sold)
      - FP_MIX                    # full-price mix ratio (0.0–1.0)
      - LY_FP_MIX                 # prior year full-price mix

  - name: VW_REGION_FP_MIX
    description: Weekly revenue and full-price mix broken down by region.
    filter_by: WEEK_NUM
    key_columns:
      - REGION_CODE, REGION_NAME, WEEK_NUM
      - NET_SALES, LY_NET_SALES
      - REG_PRICE_SALES, TRAFFIC, TRANSACTIONS
      - FP_MIX, LY_FP_MIX

  - name: VW_STORE_TYPE_PERF
    description: Weekly performance by store format.
    filter_by: WEEK_NUM
    key_columns:
      - STORE_TYPE_NAME, WEEK_NUM
      - NET_SALES, LY_NET_SALES, TRAFFIC, LY_TRAFFIC
      - TRANSACTIONS, LY_TRANSACTIONS
      - ADS, LY_ADS, UPT, CVR, LY_CVR

  - name: VW_REGION_WEEKLY_YOY
    description: Regional YoY comparison — sales, traffic, CVR delta by week.
    filter_by: WEEK_NUM
    key_columns:
      - REGION_CODE, WEEK_NUM
      - CY_SALES, LY_SALES, CY_TRAFFIC, LY_TRAFFIC
      - CY_CVR, LY_CVR
      - SALES_YOY_PCT, TRAFFIC_YOY_PCT, CVR_DELTA_BPS

  - name: VW_WEEKLY_FINANCIAL
    description: Weekly P&L and balance-sheet snapshot.
    filter_by: WEEK_NUM
    key_columns:
      - WEEK_NUM, WEEK_START
      - REVENUE, BUDGET_REVENUE, LY_REVENUE
      - REVENUE_YOY_PCT, REVENUE_VS_BUDGET_PCT
      - GROSS_MARGIN, GM_PCT
      - EBITDA, EBITDA_PCT
      - OPEX, DEPRECIATION, NET_OPERATING_INCOME
      - CASH_POSITION, ACCOUNTS_RECEIVABLE, ACCOUNTS_PAYABLE
      - BUDGET_VARIANCE, BUDGET_VARIANCE_PCT
      - PREV_WEEK_REVENUE, REVENUE_WOW_PCT

  - name: VW_WEEKLY_SUPPLY_CHAIN
    description: 3PL shipment performance, OTD, freight cost, and fill rate.
    filter_by: WEEK_NUM
    key_columns:
      - WEEK_NUM, WEEK_START
      - TOTAL_SHIPMENTS, UNITS_SHIPPED
      - ON_TIME_SHIPMENTS, OTD_PCT, LATE_SHIPMENTS
      - AVG_TRANSIT_DAYS, TOTAL_FREIGHT_COST, AVG_FREIGHT_PER_SHIPMENT
      - FEDEX_SHIPMENTS, UPS_SHIPMENTS, CANADA_POST_SHIPMENTS, PUROLATOR_SHIPMENTS
      - FILL_RATE_PCT
      - PREV_OTD_PCT, OTD_WOW_BPS

  - name: VW_WEEKLY_INVENTORY
    description: Inventory health — value, SKU count, sell-through, turns, DC activity.
    filter_by: WEEK_NUM
    key_columns:
      - WEEK_NUM, WEEK_START
      - TOTAL_INV_VALUE, ACTIVE_SKUS, CRITICAL_SKUS
      - SELL_THRU_PCT, DAYS_OF_STOCK, INV_TURNS
      - MARKDOWN_RISK_VALUE, REORDER_PENDING_SKUS
      - DC_INBOUND_UNITS, DC_OUTBOUND_UNITS
      - INV_ACCURACY_PCT, SHRINK_UNITS
      - PREV_INV_TURNS, INV_TURNS_WOW

  - name: VW_WEEKLY_CUSTOMER
    description: CRM and loyalty metrics — active customers, segments, CSAT, NPS.
    filter_by: WEEK_NUM
    key_columns:
      - WEEK_NUM, WEEK_START
      - ACTIVE_CUSTOMERS, NEW_CUSTOMERS, LAPSED_CUSTOMERS
      - CHAMPION_COUNT, LOYALIST_COUNT, AT_RISK_COUNT
      - AVG_LTV, TOTAL_LTV
      - CSAT_SCORE, NPS, VISITS_PER_CUSTOMER
      - EMAIL_OPEN_PCT, CHURN_PCT
      - PREV_CSAT, CSAT_WOW, PREV_NPS, NPS_WOW

  - name: VW_WEEKLY_HR
    description: Labour metrics — headcount, hours, wage rate, OT, absenteeism.
    filter_by: WEEK_NUM
    key_columns:
      - WEEK_NUM, WEEK_START
      - HEADCOUNT, STORE_COUNT_STAFFED
      - REG_HOURS, OT_HOURS, TOTAL_HOURS
      - AVG_WAGE_RATE, TOTAL_LABOUR_COST
      - LABOUR_PCT_OF_SALES, OT_PCT
      - ABSENT_DAYS, TRAINING_HOURS, TURNOVER_PCT
      - PREV_LABOUR_COST, LABOUR_WOW_PCT

# ─────────────────────────────────────────────
# METRIC DEFINITIONS
# ─────────────────────────────────────────────
metric_definitions:
  ADS: "Average Dollar Sale = Net Sales ÷ Transactions. Measures basket value."
  UPT: "Units Per Transaction. Measures breadth of purchase."
  AUR: "Average Unit Retail = Net Sales ÷ Units Sold. Measures pricing."
  CVR: "Conversion Rate = Transactions ÷ Traffic. Expressed as percentage."
  FP_MIX: >
    Full-Price Mix = Regular-price sales ÷ Net Sales.
    Higher is better. Fleet target: >74%. Below 70% signals markdown pressure.
  OTD_PCT: >
    On-Time Delivery %. Fleet target: >94%. Below 92% requires 3PL review.
  FILL_RATE_PCT: >
    Fill Rate % — proportion of order lines fulfilled on first attempt.
    Target: >96.5%.
  DAYS_OF_STOCK: >
    How many days of sales the current inventory covers.
    Target range: 22–30 days. Above 35 signals overstock risk.
  INV_TURNS: >
    Annualised inventory turns = 52 ÷ Days of Stock.
    Target: >8x. Below 6x signals excess inventory.
  CSAT_SCORE: "Customer satisfaction score, scale 1–5. Target: ≥4.4."
  NPS: "Net Promoter Score, scale -100 to 100. Improving trend is key signal."
  LABOUR_PCT_OF_SALES: >
    Total labour cost as % of net sales. Target: <28%. Above 30% is a risk flag.
  OT_PCT: >
    Overtime as % of total hours. Normal: 7–9%. Above 12% indicates staffing strain.
  CHAMPION_COUNT: "Top loyalty tier — highest spend, highest frequency customers."
  AT_RISK_COUNT: "Customers showing declining purchase frequency. Churn precursor."

# ─────────────────────────────────────────────
# INDUSTRY BENCHMARKS
# ─────────────────────────────────────────────
benchmarks:
  revenue_yoy_growth:
    retail_canada_2026: "+1.8% to +3.2%"
    outdoor_apparel_segment: "+2.5% to +4.1%"
    roots_current_range: "-2.1% to -5.0%"
    interpretation: "Roots is underperforming the category benchmark"
  fp_mix:
    industry_specialty_apparel: "72–78%"
    roots_fleet_target: ">74%"
  otd_pct:
    3pl_industry_standard: "94–96%"
    roots_target: ">94%"
  fill_rate:
    industry_standard: "95–98%"
    roots_target: ">96.5%"
  inventory_turns:
    specialty_apparel_benchmark: "7–10x annualised"
    roots_target: ">8x"
  csat:
    retail_canada_benchmark: "4.2–4.5 / 5"
    roots_target: "≥4.4"
  labour_pct_of_sales:
    specialty_retail_benchmark: "22–26%"
    roots_target: "<28%"

# ─────────────────────────────────────────────
# EXECUTIVE DECK — 5-SLIDE STRUCTURE
# ─────────────────────────────────────────────
deck:
  slide_count: 5
  theme: "Cream/ivory background · Dark green (#1C2B1E) header bars · Gold (#8B7D3A) accents"
  font: Calibri
  slide_dimensions: "13.33in × 7.5in (widescreen 16:9)"

  slides:
    - id: 1
      title: "EXECUTIVE SUMMARY"
      subtitle: "Revenue · Traffic · Cash · Key Drivers"
      header_format: >
        "EXECUTIVE SUMMARY  |  Revenue {YoY%} ({$delta}) to LY  //  {BvB%} ({$delta}) to Budget"
      hero_kpis:
        - label: REVENUE
          value: Net Sales ($M)
          sub: "Budget: $X.XXM"
          badge: YoY %
        - label: STORE TRAFFIC
          value: YoY % change
          sub: vs Last Year
        - label: INVENTORY TURNS
          value: "X.Xx annualised"
          sub: annualised
        - label: CASH POSITION
          value: "$XX.XM"
          sub: end of week
      body: >
        Claude-generated narrative bullets (4–6 total, split into 2 columns).
        Cover top performers, risks, and the primary narrative tension (YoY decline).
      data_sources: [VW_WEEKLY_KPI, VW_WEEKLY_FINANCIAL]

    - id: 2
      title: "REVENUE PERFORMANCE"
      subtitle: "Regional breakdown · Budget vs Actual"
      left_panel:
        type: table
        columns: [REGION, CY SALES, LY SALES, YoY, BUDGET, vs BUD]
        source: VW_REGION_FP_MIX + VW_REGION_WEEKLY_YOY
      right_panel:
        top: "Claude revenue insights (3–4 bullets)"
        bottom: "Full-price mix bar chart by region"
        source: VW_REGION_FP_MIX
      data_sources: [VW_REGION_FP_MIX, VW_REGION_WEEKLY_YOY, VW_WEEKLY_FINANCIAL]

    - id: 3
      title: "STORE OPERATIONS"
      subtitle: "Traffic · Conversion · Basket · Format Performance"
      top_kpis:
        - STORE TRAFFIC (vs LY)
        - CONVERSION RATE (vs LY, in bps)
        - AVG. ORDER VALUE (vs LY)
        - UNITS PER TXN
      table:
        columns: [STORE TYPE, SALES, TRAFFIC, CVR, ADS, UPT, SALES YoY, CVR Δ]
        rows: one per store format (Mall, Street, Ski City, Recall, Power Centre)
        source: VW_STORE_TYPE_PERF
      body: "Claude ops narrative (2–4 bullets)"
      data_sources: [VW_WEEKLY_KPI, VW_STORE_TYPE_PERF]

    - id: 4
      title: "SUPPLY CHAIN & 3PL"
      subtitle: "Delivery · Freight · Inventory · Fill Rate"
      top_kpis:
        - ON-TIME DELIVERY % (vs LY, bps)
        - FREIGHT COST YoY
        - INVENTORY AGING (avg days)
        - FILL RATE % (vs LY, bps)
      detail_table:
        columns: [METRIC, CURRENT, PRIOR YEAR, VARIANCE, STATUS]
        rows:
          - On-Time Delivery %
          - Freight Cost Index
          - Avg Inventory Age (days)
          - Fill Rate %
          - Inventory Turns (ann.)
        status_badges: ["On Track", "Watch", "Risk", "Favourable", "Improving"]
      body: "Claude supply chain narrative (2–4 bullets)"
      data_sources: [VW_WEEKLY_SUPPLY_CHAIN, VW_WEEKLY_INVENTORY]

    - id: 5
      title: "RISKS & OPPORTUNITIES"
      subtitle: "Strategic Outlook — Internal signals + External intelligence"
      left_panel:
        header_color: deep red
        title: "KEY RISKS"
        content: "4–6 risk bullets (Claude-generated from internal data + web research)"
      right_panel:
        header_color: deep green
        title: "OPPORTUNITIES"
        content: "4–6 opportunity bullets (Claude-generated)"
      footer: "Cited sources from Claude web search (3 max)"
      data_sources: [VW_WEEKLY_KPI, VW_WEEKLY_FINANCIAL, VW_WEEKLY_SUPPLY_CHAIN, VW_WEEKLY_CUSTOMER]

# ─────────────────────────────────────────────
# NARRATIVE STYLE GUIDE
# ─────────────────────────────────────────────
narrative_style:
  tone: "Executive, fact-first, concise. No filler phrases like 'it is important to note'."
  bullet_format: "Start with the metric and magnitude. End with implication. Max 20 words."
  examples:
    good: "Revenue -3.2% YoY in ON — traffic decline (-4.1%) outpacing ADS recovery (+1.8%); CVR flat."
    bad: "It is important to note that Ontario revenue has declined compared to last year."
  yoy_context: >
    Always compare CY vs LY. When YoY is negative, explain the primary driver
    (traffic vs ADS vs mix). When positive, identify what's working.
  priorities:
    - Revenue vs budget (primary)
    - YoY trajectory (momentum)
    - Full-price mix (margin proxy)
    - OTD and fill rate (supply chain health)
    - CSAT and NPS (customer experience)

# ─────────────────────────────────────────────
# SEASONAL CONTEXT
# ─────────────────────────────────────────────
seasonality:
  W01_W02: "Post-holiday clearance — highest traffic weeks of H1 (index 1.10–1.12)"
  W03_W08: "Post-holiday dip — lowest revenue weeks (index 0.87–0.93)"
  W09_W14: "Spring recovery — gradual improvement (index 0.95–1.04)"
  W15_W22: "Pre-summer build — strongest spring momentum (index 1.05–1.10)"
  inventory_pattern: >
    Inventory is counter-seasonal: high Jan (post-production), declining through spring.
    Markdown risk is highest W01–W06; restocking peaks W16–W22.
  3pl_pattern: >
    Shipment volumes follow sales seasonal index.
    OTD dips W04–W06 (post-holiday carrier congestion); recovers by W09.

# ─────────────────────────────────────────────
# ERROR HANDLING
# ─────────────────────────────────────────────
error_handling:
  no_data_for_week: >
    If a query returns no rows for the requested WEEK_NUM,
    say: "No data found for W{N}. The dataset covers W01–W22 (Jan 5 – May 31, 2026).
    Please choose a week in that range."
  partial_data: >
    If some views return data but others don't, generate the deck with the
    available data and clearly note which sections used fallback values.
  data_freshness: >
    All data reflects the snapshot loaded in Snowflake. If the user asks about
    a week after W22, explain the data coverage ends May 31, 2026.

# ─────────────────────────────────────────────
# SECURITY RULES
# ─────────────────────────────────────────────
security:
  - Never write INSERT, UPDATE, DELETE, DROP, or DDL statements.
  - Query RETAIL_ANALYTICS.CORE views only.
  - Never expose Snowflake credentials, account IDs, or connection strings.
  - All queries must include a WHERE WEEK_NUM = {N} or WEEK_NUM <= {N} filter.
