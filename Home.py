"""
Roots Data Intelligence — Data Pipeline Hub
5 months of raw source data (W01–W22 2026) across 6 systems,
push to Snowflake, then hand off to the Claude WBR Skill.
"""
import time
import numpy as np
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import streamlit as st
from utils.styles import inject_css

st.set_page_config(
    page_title="Roots — Data Pipeline Hub",
    page_icon="🦫",
    layout="wide",
    initial_sidebar_state="expanded",
)
inject_css()

# ─────────────────────────────────────────────────────────────
# MOCK DATA  (22-week Jan–May 2026, seed=42)
# ─────────────────────────────────────────────────────────────
@st.cache_data
def build_pipeline_data():
    rng = np.random.default_rng(42)
    n   = 22   # W01–W22 = Jan 5 – May 31 2026
    wk  = [f"W{i:02d}" for i in range(1, n + 1)]
    wd  = pd.date_range("2026-01-05", periods=n, freq="W-MON").strftime("%Y-%m-%d").tolist()

    # Roots Canada seasonal index (Jan–May)
    sea = np.array([
        1.12, 1.02, 0.90, 0.88, 0.87, 0.89,
        0.91, 0.93, 0.95, 0.97, 0.99, 1.01,
        1.02, 1.04, 1.05, 1.06, 1.06, 1.05,
        1.07, 1.08, 1.09, 1.10,
    ])
    # Inventory seasonal (inverse: high Jan post-holiday, low mid-spring, recover May)
    inv_sea = np.array([
        1.18, 1.12, 1.08, 1.04, 1.01, 0.99,
        0.97, 0.95, 0.93, 0.91, 0.90, 0.89,
        0.88, 0.87, 0.87, 0.88, 0.89, 0.90,
        0.91, 0.93, 0.95, 0.97,
    ])
    ns = lambda s: rng.normal(1.0, s, n)

    # ── Finance (18 cols) ─────────────────────────────────────
    rev      = (2_050_000 * sea * ns(0.04)).round(2)
    bud_rev  = (rev * rng.uniform(0.95, 1.07, n)).round(2)
    ly_rev   = (rev * rng.uniform(1.02, 1.06, n)).round(2)
    cogs     = (rev * 0.585 * ns(0.02)).round(2)
    gm       = (rev - cogs).round(2)
    gm_pct   = (gm / rev * 100).round(2)
    ebitda   = (rev * 0.225 * ns(0.03)).round(2)
    ebitda_p = (ebitda / rev * 100).round(2)
    opex     = (rev * 0.180 * ns(0.02)).round(2)
    depr     = (rev * 0.025 * ns(0.01)).round(2)
    noi      = (ebitda - depr).round(2)
    cash     = (np.cumsum(rng.normal(0, 280_000, n)) + 18_400_000).round(2)
    ar       = (rev * 0.14 * ns(0.05)).round(2)
    ap       = (cogs * 0.21 * ns(0.05)).round(2)
    bud_var  = (rev - bud_rev).round(2)
    bud_vp   = (bud_var / bud_rev * 100).round(2)
    rev_yoy  = ((rev - ly_rev) / ly_rev * 100).round(2)

    fin = pd.DataFrame({
        "WEEK": wk, "WEEK_START": wd,
        "REVENUE": rev, "BUDGET_REVENUE": bud_rev, "LY_REVENUE": ly_rev,
        "REVENUE_YOY_PCT": rev_yoy,
        "COGS": cogs, "GROSS_MARGIN": gm, "GM_PCT": gm_pct,
        "EBITDA": ebitda, "EBITDA_PCT": ebitda_p,
        "OPEX": opex, "DEPRECIATION": depr, "NET_OPERATING_INCOME": noi,
        "CASH_POSITION": cash, "ACCOUNTS_RECEIVABLE": ar, "ACCOUNTS_PAYABLE": ap,
        "BUDGET_VARIANCE_PCT": bud_vp,
    })

    # ── POS / Stores (20 cols) ────────────────────────────────
    traf     = (175_000 * sea * ns(0.05)).astype(int)
    ly_traf  = (traf * rng.uniform(1.02, 1.08, n)).astype(int)
    cvr      = np.clip(0.113 * ns(0.03), 0.08, 0.18)
    ly_cvr   = np.clip(cvr * rng.uniform(0.97, 1.04, n), 0.08, 0.18)
    txns     = (traf * cvr).astype(int)
    ly_txns  = (ly_traf * ly_cvr).astype(int)
    ads      = (96.50 * ns(0.03)).round(2)
    ly_ads   = (ads * rng.uniform(1.01, 1.05, n)).round(2)
    upt      = (2.10 * ns(0.02)).round(2)
    ly_upt   = (upt * rng.uniform(0.98, 1.03, n)).round(2)
    sales    = (txns * ads).round(2)
    bud_s    = (sales * rng.uniform(0.94, 1.08, n)).round(2)
    ly_s     = (sales * rng.uniform(1.02, 1.07, n)).round(2)
    fpm      = np.clip(0.758 * ns(0.015), 0.68, 0.86)
    cvr_bps  = ((cvr - ly_cvr) * 10000).round(1)
    ads_yoy  = ((ads - ly_ads) / ly_ads * 100).round(2)
    s_yoy    = ((sales - ly_s) / ly_s * 100).round(2)
    tr_yoy   = ((traf - ly_traf) / ly_traf * 100).round(2)

    pos = pd.DataFrame({
        "WEEK": wk, "WEEK_START": wd,
        "NET_SALES": sales, "BUDGET_SALES": bud_s, "LY_SALES": ly_s,
        "SALES_YOY_PCT": s_yoy,
        "TRAFFIC": traf, "LY_TRAFFIC": ly_traf, "TRAFFIC_YOY_PCT": tr_yoy,
        "TRANSACTIONS": txns, "LY_TRANSACTIONS": ly_txns,
        "CVR_PCT": (cvr * 100).round(2), "LY_CVR_PCT": (ly_cvr * 100).round(2),
        "CVR_DELTA_BPS": cvr_bps,
        "ADS": ads, "LY_ADS": ly_ads, "ADS_YOY_PCT": ads_yoy,
        "UPT": upt, "LY_UPT": ly_upt,
        "FP_MIX_PCT": (fpm * 100).round(1),
    })

    # ── 3PL (15 cols) ─────────────────────────────────────────
    ships    = (1_200 * sea * ns(0.06)).astype(int)
    units_s  = (ships * rng.integers(11, 16, n)).astype(int)
    otd      = np.clip(94.2 + rng.normal(0, 1.5, n), 88, 99).round(1)
    late_s   = (ships * (1 - otd / 100)).astype(int)
    on_t     = ships - late_s
    tdays    = np.clip(2.8 + rng.normal(0, 0.4, n), 1.5, 5.0).round(1)
    frt_a    = (124.50 * ns(0.08)).round(2)
    frt_t    = (ships * frt_a).round(2)
    fill     = np.clip(96.8 + rng.normal(0, 0.9, n), 92, 100).round(1)
    fedex_s  = (ships * rng.uniform(0.33, 0.40, n)).astype(int)
    ups_s    = (ships * rng.uniform(0.22, 0.28, n)).astype(int)
    cp_s     = (ships * rng.uniform(0.20, 0.26, n)).astype(int)
    puro_s   = np.maximum(ships - fedex_s - ups_s - cp_s, 0)

    tpl = pd.DataFrame({
        "WEEK": wk, "WEEK_START": wd,
        "TOTAL_SHIPMENTS": ships, "UNITS_SHIPPED": units_s,
        "ON_TIME_SHIPMENTS": on_t, "OTD_PCT": otd,
        "LATE_SHIPMENTS": late_s, "AVG_TRANSIT_DAYS": tdays,
        "TOTAL_FREIGHT_COST": frt_t, "AVG_FREIGHT_PER_SHIPMENT": frt_a,
        "FEDEX_SHIPMENTS": fedex_s, "UPS_SHIPMENTS": ups_s,
        "CANADA_POST_SHIPMENTS": cp_s, "PUROLATOR_SHIPMENTS": puro_s,
        "FILL_RATE_PCT": fill,
    })

    # ── WMS / Inventory (14 cols) ─────────────────────────────
    inv_v    = (4_200_000 * inv_sea * ns(0.04)).round(2)
    act_sku  = rng.integers(3_800, 4_200, n)
    crit_s   = rng.integers(2, 18, n)
    st_pct   = np.clip(0.82 * ns(0.03), 0.65, 0.98)
    dos      = np.clip(28 / st_pct * ns(0.04), 14, 60).round(1)
    turns    = np.clip(52 / dos, 4.0, 12.0).round(2)
    mkd_r    = (inv_v * rng.uniform(0.04, 0.12, n)).round(2)
    reorder  = rng.integers(15, 85, n)
    inb      = rng.integers(18_000, 32_000, n)
    outb     = rng.integers(16_000, 30_000, n)
    acc_pct  = np.clip(98.5 + rng.normal(0, 0.6, n), 96, 100).round(1)
    shrink   = rng.integers(120, 480, n)

    wms = pd.DataFrame({
        "WEEK": wk, "WEEK_START": wd,
        "TOTAL_INV_VALUE": inv_v, "ACTIVE_SKUS": act_sku,
        "CRITICAL_SKUS": crit_s, "SELL_THRU_PCT": (st_pct * 100).round(1),
        "DAYS_OF_STOCK": dos, "INV_TURNS": turns,
        "MARKDOWN_RISK_VALUE": mkd_r, "REORDER_PENDING_SKUS": reorder,
        "DC_INBOUND_UNITS": inb, "DC_OUTBOUND_UNITS": outb,
        "INV_ACCURACY_PCT": acc_pct, "SHRINK_UNITS": shrink,
    })

    # ── CRM (15 cols) ─────────────────────────────────────────
    actc     = (8_000 * ns(0.03)).astype(int)
    newc     = (820 * ns(0.12)).astype(int)
    lapsed   = rng.integers(120, 480, n)
    champ    = rng.integers(280, 420, n)
    loyal    = rng.integers(800, 1_200, n)
    at_risk  = rng.integers(180, 620, n)
    ltv      = (2_420 * ns(0.04)).round(2)
    tot_ltv  = (actc * ltv).round(2)
    csat     = np.clip(4.42 + rng.normal(0, 0.14, n), 3.8, 5.0).round(2)
    nps      = np.clip(44 + rng.normal(0, 4, n), 26, 68).round(1)
    vpc      = np.clip(2.8 + rng.normal(0, 0.3, n), 1.8, 4.2).round(2)
    email_op = np.clip(28.5 + rng.normal(0, 2.2, n), 18, 42).round(1)
    churn    = np.clip(2.05 + rng.normal(0, 0.38, n), 0.8, 4.5).round(2)

    crm = pd.DataFrame({
        "WEEK": wk, "WEEK_START": wd,
        "ACTIVE_CUSTOMERS": actc, "NEW_CUSTOMERS": newc,
        "LAPSED_CUSTOMERS": lapsed, "CHAMPION_COUNT": champ,
        "LOYALIST_COUNT": loyal, "AT_RISK_COUNT": at_risk,
        "AVG_LTV": ltv, "TOTAL_LTV": tot_ltv,
        "CSAT_SCORE": csat, "NPS": nps,
        "VISITS_PER_CUSTOMER": vpc, "EMAIL_OPEN_PCT": email_op,
        "CHURN_PCT": churn,
    })

    # ── HR (14 cols) ──────────────────────────────────────────
    hc       = rng.integers(512, 534, n)
    sc_st    = rng.integers(81, 84, n)
    rh       = (hc * 36 * ns(0.02)).astype(int)
    oh       = (rh * rng.uniform(0.06, 0.12, n)).astype(int)
    th       = (rh + oh).astype(int)
    wage     = (19.85 * ns(0.01)).round(2)
    lcost    = ((rh + oh * 1.5) * wage).round(2)
    l_pct    = np.clip(26.5 + rng.normal(0, 1.5, n), 22.0, 32.0).round(2)
    ot_pct   = (oh / th * 100).round(2)
    absent   = rng.integers(8, 28, n)
    train_h  = rng.integers(180, 520, n)
    turn     = np.clip(1.8 + rng.normal(0, 0.4, n), 0.5, 4.2).round(2)

    hr = pd.DataFrame({
        "WEEK": wk, "WEEK_START": wd,
        "HEADCOUNT": hc, "STORE_COUNT_STAFFED": sc_st,
        "REG_HOURS": rh, "OT_HOURS": oh, "TOTAL_HOURS": th,
        "AVG_WAGE_RATE": wage, "TOTAL_LABOUR_COST": lcost,
        "LABOUR_PCT_OF_SALES": l_pct, "OT_PCT": ot_pct,
        "ABSENT_DAYS": absent, "TRAINING_HOURS": train_h,
        "TURNOVER_PCT": turn,
    })

    return {
        "Finance":    {"df": fin,  "rows": 8_904,   "icon": "💰", "cat": "Financial",   "stg": "STG_FINANCE"},
        "POS/Stores": {"df": pos,  "rows": 142_380, "icon": "🏪", "cat": "Operational", "stg": "STG_POS_DAILY"},
        "3PL":        {"df": tpl,  "rows": 28_540,  "icon": "🚚", "cat": "Operational", "stg": "STG_3PL_SHIPMENTS"},
        "WMS":        {"df": wms,  "rows": 19_820,  "icon": "📦", "cat": "Operational", "stg": "STG_WMS_INVENTORY"},
        "CRM":        {"df": crm,  "rows": 54_210,  "icon": "👥", "cat": "Operational", "stg": "STG_CRM_CUSTOMERS"},
        "HR":         {"df": hr,   "rows": 11_640,  "icon": "👔", "cat": "Operational", "stg": "STG_HR_LABOUR"},
    }


DATA       = build_pipeline_data()
TOTAL_ROWS = sum(v["rows"] for v in DATA.values())

# ─────────────────────────────────────────────────────────────
# CHART HELPERS
# ─────────────────────────────────────────────────────────────
C_PUR   = "#8b5cf6"; C_TEAL = "#06b6d4"
C_GRN   = "#10b981"; C_RED  = "#ef4444"
C_AMB   = "#f59e0b"; C_GRAY = "#cbd5e1"
C_ROOTS = "#1C2B1E"


def _lay(fig, h=320):
    fig.update_layout(
        height=h, margin=dict(l=4, r=4, t=28, b=4),
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        legend=dict(orientation="h", yanchor="bottom", y=1.02,
                    xanchor="right", x=1, font_size=10),
        font=dict(family="Calibri,sans-serif", color="#0f0f14"),
        xaxis=dict(showgrid=False, tickfont_size=9),
        yaxis=dict(showgrid=True, gridcolor="rgba(0,0,0,0.06)", tickfont_size=9),
    )
    return fig


def bar_line(df, bc, lc, bn, ln, bc_col=C_PUR, lc_col=C_TEAL, bf=",d", lf=".1f"):
    fig = make_subplots(specs=[[{"secondary_y": True}]])
    fig.add_trace(go.Bar(x=df.WEEK, y=df[bc], name=bn, marker_color=bc_col, opacity=0.82,
        hovertemplate=f"%{{x}}<br>{bn}: %{{y:{bf}}}<extra></extra>"), secondary_y=False)
    fig.add_trace(go.Scatter(x=df.WEEK, y=df[lc], name=ln,
        line=dict(color=lc_col, width=2.5), mode="lines+markers", marker_size=5,
        hovertemplate=f"%{{x}}<br>{ln}: %{{y:{lf}}}<extra></extra>"), secondary_y=True)
    _lay(fig)
    fig.update_yaxes(showgrid=False, tickfont_size=9, secondary_y=True)
    return fig


def bar_duo(df, c1, c2, n1, n2, col1=C_PUR, col2=C_GRAY, fmt="$,.0f"):
    fig = go.Figure([
        go.Bar(x=df.WEEK, y=df[c1], name=n1, marker_color=col1, opacity=0.85,
               hovertemplate=f"%{{x}}<br>{n1}: %{{y:{fmt}}}<extra></extra>"),
        go.Bar(x=df.WEEK, y=df[c2], name=n2, marker_color=col2, opacity=0.60,
               hovertemplate=f"%{{x}}<br>{n2}: %{{y:{fmt}}}<extra></extra>"),
    ])
    fig.update_layout(barmode="group")
    return _lay(fig)


def area(df, col, name, color=C_PUR, fmt=".1f", target=None):
    fc = color.lstrip("#")
    r, g, b = int(fc[0:2], 16), int(fc[2:4], 16), int(fc[4:6], 16)
    fig = go.Figure(go.Scatter(
        x=df.WEEK, y=df[col], name=name, fill="tozeroy", mode="lines",
        line=dict(color=color, width=2.5),
        fillcolor=f"rgba({r},{g},{b},0.12)",
        hovertemplate=f"%{{x}}<br>{name}: %{{y:{fmt}}}<extra></extra>",
    ))
    if target:
        fig.add_hline(y=target["v"], line_dash="dot", line_color=C_AMB,
                      annotation_text=target["lbl"], annotation_font_size=9)
    return _lay(fig)


def mline(df, cols, names, colors, fmt=".1f"):
    fig = go.Figure()
    for c, n, col in zip(cols, names, colors):
        fig.add_trace(go.Scatter(x=df.WEEK, y=df[c], name=n,
            mode="lines+markers", line=dict(color=col, width=2.5), marker_size=5,
            hovertemplate=f"%{{x}}<br>{n}: %{{y:{fmt}}}<extra></extra>"))
    return _lay(fig)


def card(label, value, note=""):
    return (
        f'<div style="background:rgba(255,255,255,0.72);backdrop-filter:blur(14px);'
        f'border:1px solid rgba(28,43,30,0.13);border-radius:14px;'
        f'padding:16px 18px;min-height:84px">'
        f'<div style="font-size:10px;font-weight:700;letter-spacing:1.2px;'
        f'color:{C_ROOTS};margin-bottom:6px">{label}</div>'
        f'<div style="font-size:23px;font-weight:800;color:#0f0f14;line-height:1.1">{value}</div>'
        f'<div style="font-size:10px;color:#9a9aaa;margin-top:5px">{note}</div>'
        f'</div>'
    )


# ─────────────────────────────────────────────────────────────
# SIDEBAR
# ─────────────────────────────────────────────────────────────
with st.sidebar:
    try:
        st.image("assets/logo.png", width=100)
    except Exception:
        st.markdown("### 🦫")
    st.markdown(
        '<div style="font-size:14px;font-weight:700;color:#1C2B1E;margin-top:6px;'
        'letter-spacing:0.5px">Roots Canada</div>'
        '<div style="font-size:11px;color:#9a9aaa;margin-bottom:18px">'
        'Data Intelligence Platform</div>',
        unsafe_allow_html=True,
    )
    st.markdown("### Filters")
    w1, w2 = st.slider("Week range", 1, 22, (1, 22), format="W%02d")
    sel    = st.multiselect("Source systems", list(DATA.keys()), default=list(DATA.keys()))
    st.markdown("---")


# ─────────────────────────────────────────────────────────────
# PAGE HEADER — Roots logo + title
# ─────────────────────────────────────────────────────────────
logo_col, title_col = st.columns([1, 11])
with logo_col:
    try:
        st.image("assets/logo.png", width=72)
    except Exception:
        st.markdown("## 🦫")
with title_col:
    st.markdown(
        f'<div style="font-size:30px;font-weight:900;color:{C_ROOTS};'
        f'letter-spacing:-0.5px;margin-bottom:2px;margin-top:6px">Data Pipeline Hub</div>'
        f'<p style="color:#5a5a68;font-size:13px;margin:0">'
        f'Roots Canada  ·  6 source systems  ·  '
        f'<strong>{TOTAL_ROWS:,} records</strong>  ·  '
        f'W01–W22 2026 (Jan–May)  ·  Snowflake as single source of truth</p>',
        unsafe_allow_html=True,
    )

st.markdown("<div style='height:10px'></div>", unsafe_allow_html=True)

# Pipeline flow diagram
st.markdown("""
<div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;
     background:rgba(28,43,30,0.04);border:1px solid rgba(28,43,30,0.12);
     border-radius:12px;padding:10px 18px;margin-bottom:16px">
  <span style="font-size:10px;font-weight:700;color:#1C2B1E;letter-spacing:1px;margin-right:4px">DATA FLOW</span>
  <span style="font-size:10px;background:#f0fdf4;border:1px solid #86efac;border-radius:6px;padding:3px 9px;color:#15803d;font-weight:600">🏪 POS</span>
  <span style="font-size:10px;background:#f0fdf4;border:1px solid #86efac;border-radius:6px;padding:3px 9px;color:#15803d;font-weight:600">🚚 3PL</span>
  <span style="font-size:10px;background:#f0fdf4;border:1px solid #86efac;border-radius:6px;padding:3px 9px;color:#15803d;font-weight:600">📦 WMS</span>
  <span style="font-size:10px;background:#fef3c7;border:1px solid #fcd34d;border-radius:6px;padding:3px 9px;color:#92400e;font-weight:600">💰 Finance</span>
  <span style="font-size:10px;background:#fef3c7;border:1px solid #fcd34d;border-radius:6px;padding:3px 9px;color:#92400e;font-weight:600">👥 CRM</span>
  <span style="font-size:10px;background:#fef3c7;border:1px solid #fcd34d;border-radius:6px;padding:3px 9px;color:#92400e;font-weight:600">👔 HR</span>
  <span style="color:#1C2B1E;font-size:16px;font-weight:700">→</span>
  <span style="font-size:10px;background:linear-gradient(135deg,#e0f2fe,#bae6fd);border:1px solid #38bdf8;border-radius:6px;padding:3px 12px;color:#0369a1;font-weight:700">❄️ Snowflake</span>
  <span style="color:#1C2B1E;font-size:16px;font-weight:700">→</span>
  <span style="font-size:10px;background:linear-gradient(135deg,#f5f3ff,#ede9fe);border:1px solid #8b5cf6;border-radius:6px;padding:3px 12px;color:#6d28d9;font-weight:700">🤖 Claude Skill</span>
  <span style="color:#1C2B1E;font-size:16px;font-weight:700">→</span>
  <span style="font-size:10px;background:linear-gradient(135deg,#fffbeb,#fef3c7);border:1px solid #f59e0b;border-radius:6px;padding:3px 12px;color:#92400e;font-weight:700">📊 WBR Deck</span>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────
# SUMMARY METRICS (6 top KPIs)
# ─────────────────────────────────────────────────────────────
fin_s = DATA["Finance"]["df"].iloc[w1-1:w2]
pos_s = DATA["POS/Stores"]["df"].iloc[w1-1:w2]
tpl_s = DATA["3PL"]["df"].iloc[w1-1:w2]
crm_s = DATA["CRM"]["df"].iloc[w1-1:w2]

rev_total = fin_s.REVENUE.sum()
bud_total = fin_s.BUDGET_REVENUE.sum()
bud_arrow = "▲" if rev_total >= bud_total else "▼"
bud_delta = abs(rev_total / bud_total - 1) * 100

c1, c2, c3, c4, c5, c6 = st.columns(6)
c1.markdown(card("REVENUE",       f"${rev_total/1e6:.1f}M",
                 f"{bud_arrow} {bud_delta:.1f}% vs budget · W{w1:02d}–W{w2:02d}"),
            unsafe_allow_html=True)
c2.markdown(card("GROSS MARGIN",  f"{fin_s.GM_PCT.mean():.1f}%",  "fleet avg"),      unsafe_allow_html=True)
c3.markdown(card("STORE TRAFFIC", f"{int(pos_s.TRAFFIC.sum()/1e3)}K", "total visits"),  unsafe_allow_html=True)
c4.markdown(card("AVG CVR",       f"{pos_s.CVR_PCT.mean():.2f}%", "fleet average"),   unsafe_allow_html=True)
c5.markdown(card("ON-TIME DEL",   f"{tpl_s.OTD_PCT.mean():.1f}%", "3PL average"),     unsafe_allow_html=True)
c6.markdown(card("CSAT",          f"{crm_s.CSAT_SCORE.mean():.2f}/5", "customer score"), unsafe_allow_html=True)

st.markdown("<div style='height:14px'></div>", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────
# PUSH ALL TO SNOWFLAKE — Single CTA
# ─────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="background:linear-gradient(135deg,rgba(28,43,30,0.05),'
    f'rgba(28,43,30,0.02));border:1.5px solid rgba(28,43,30,0.16);'
    f'border-radius:16px;padding:20px 24px;margin-bottom:20px">',
    unsafe_allow_html=True,
)
push_col, _ = st.columns([3, 6])
with push_col:
    push_all = st.button(
        "❄️  Push All to Snowflake",
        type="primary",
        use_container_width=True,
        key="push_all_btn",
    )
st.markdown("</div>", unsafe_allow_html=True)

if push_all:
    prog  = st.progress(0, "Connecting to Snowflake…")
    log   = st.empty()
    lines = [
        f"❄️  Connected → RETAIL_ANALYTICS.CORE  (account: LUMNPAC-EF71075)",
        f"{'─' * 68}",
    ]
    time.sleep(0.3)
    for i, (nm, info) in enumerate(DATA.items()):
        pct = (i + 1) / len(DATA)
        prog.progress(pct, f"Loading {nm} ({info['rows']:,} rows)…")
        time.sleep(0.45)
        cols = len(info["df"].columns)
        lines.append(
            f"✅  {nm:<14}→  {info['stg']:<26}  {info['rows']:>8,} rows  ·  {cols:2d} cols"
        )
        log.code("\n".join(lines), language=None)
    time.sleep(0.2)
    lines.append(f"{'─' * 68}")
    lines.append(f"✅  Views refreshed: VW_WEEKLY_KPI, VW_REGION_FP_MIX, VW_STORE_TYPE_PERF,")
    lines.append(f"    VW_REGION_WEEKLY_YOY, VW_WEEKLY_FINANCIAL, VW_WEEKLY_SUPPLY_CHAIN")
    log.code("\n".join(lines), language=None)
    time.sleep(0.3)
    prog.empty()
    log.empty()
    st.success(
        f"All **{TOTAL_ROWS:,} records** pushed across {len(DATA)} Snowflake tables.  "
        "Views refreshed.  Data is ready for the WBR skill.",
        icon="❄️",
    )

st.markdown("---")

# ─────────────────────────────────────────────────────────────
# SOURCE OVERVIEW TABLE
# ─────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="font-size:11px;font-weight:700;letter-spacing:1.5px;'
    f'color:{C_ROOTS};margin-bottom:10px">SOURCE SYSTEM OVERVIEW</div>',
    unsafe_allow_html=True,
)
overview_rows = []
for nm, info in DATA.items():
    df_ov = info["df"].iloc[w1-1:w2]
    overview_rows.append({
        "Source": f"{info['icon']}  {nm}",
        "Category": info["cat"],
        "Snowflake Table": f"CORE.{info['stg']}",
        "Source Records": f"{info['rows']:,}",
        "Columns": len(df_ov.columns),
        "Weeks": len(df_ov),
        "Date Range": f"{df_ov.WEEK_START.iloc[0]} → {df_ov.WEEK_START.iloc[-1]}",
        "Status": "✅ Ready",
    })
st.dataframe(pd.DataFrame(overview_rows), use_container_width=True, hide_index=True, height=264)

st.markdown("<br>", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────
# SOURCE TABS
# ─────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="font-size:11px;font-weight:700;letter-spacing:1.5px;'
    f'color:{C_ROOTS};margin-bottom:10px">'
    f'SOURCE DATA — WEEKLY TRENDS  '
    f'(W{w1:02d}–W{w2:02d}  ·  {w2 - w1 + 1} weeks selected)</div>',
    unsafe_allow_html=True,
)

visible = [s for s in DATA if s in sel] if sel else list(DATA.keys())
tabs    = st.tabs([f"{DATA[s]['icon']}  {s}" for s in visible])

for tab, sn in zip(tabs, visible):
    info = DATA[sn]
    df   = info["df"].iloc[w1-1:w2].copy()

    with tab:

        # ── Finance ───────────────────────────────────────────
        if sn == "Finance":
            rev_t = df.REVENUE.sum(); bud_t = df.BUDGET_REVENUE.sum()
            arrow = "▲" if rev_t >= bud_t else "▼"
            k1, k2, k3, k4 = st.columns(4)
            k1.markdown(card("REVENUE",     f"${rev_t/1e6:.2f}M",
                             f"{arrow} {abs(rev_t/bud_t-1)*100:.1f}% vs Budget"), unsafe_allow_html=True)
            k2.markdown(card("AVG GM %",    f"{df.GM_PCT.mean():.1f}%", "gross margin"), unsafe_allow_html=True)
            k3.markdown(card("EBITDA",      f"${df.EBITDA.sum()/1e6:.2f}M", "period total"), unsafe_allow_html=True)
            k4.markdown(card("CASH (last)", f"${df.CASH_POSITION.iloc[-1]/1e6:.1f}M", "end of period"), unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
            r1, r2 = st.columns(2)
            with r1:
                st.caption("**Revenue vs Budget** — weekly ($)")
                st.plotly_chart(bar_duo(df, "REVENUE", "BUDGET_REVENUE", "Actual", "Budget", fmt="$,.0f"),
                                use_container_width=True, key="f_rev")
            with r2:
                st.caption("**EBITDA & Gross Margin %**")
                st.plotly_chart(bar_line(df, "EBITDA", "GM_PCT", "EBITDA ($)", "GM %",
                                bc_col=C_TEAL, lc_col=C_PUR, bf="$,.0f", lf=".1f"),
                                use_container_width=True, key="f_ebitda")
            r3, r4 = st.columns(2)
            with r3:
                st.caption("**Cash Position** — weekly ($)")
                st.plotly_chart(area(df, "CASH_POSITION", "Cash ($)", C_GRN, "$,.0f"),
                                use_container_width=True, key="f_cash")
            with r4:
                st.caption("**AR / AP** — weekly ($)")
                st.plotly_chart(mline(df, ["ACCOUNTS_RECEIVABLE", "ACCOUNTS_PAYABLE"],
                                ["Accounts Receivable", "Accounts Payable"], [C_PUR, C_AMB], "$,.0f"),
                                use_container_width=True, key="f_arap")

        # ── POS / Stores ──────────────────────────────────────
        elif sn == "POS/Stores":
            k1, k2, k3, k4 = st.columns(4)
            k1.markdown(card("NET SALES",  f"${df.NET_SALES.sum()/1e6:.2f}M", "period"), unsafe_allow_html=True)
            k2.markdown(card("TRAFFIC",    f"{int(df.TRAFFIC.sum()/1e3)}K", "total visits"), unsafe_allow_html=True)
            k3.markdown(card("AVG CVR",    f"{df.CVR_PCT.mean():.2f}%", ""), unsafe_allow_html=True)
            k4.markdown(card("AVG ADS",    f"${df.ADS.mean():.2f}", "per transaction"), unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
            r1, r2 = st.columns(2)
            with r1:
                st.caption("**Net Sales & CVR %** — weekly")
                st.plotly_chart(bar_line(df, "NET_SALES", "CVR_PCT", "Net Sales ($)", "CVR %",
                                bf="$,.0f", lf=".2f"), use_container_width=True, key="p_sales")
            with r2:
                st.caption("**Traffic & ADS** — weekly")
                st.plotly_chart(bar_line(df, "TRAFFIC", "ADS", "Traffic", "ADS ($)",
                                bc_col=C_TEAL, lc_col=C_AMB, bf=",d", lf="$.2f"),
                                use_container_width=True, key="p_traffic")
            r3, r4 = st.columns(2)
            with r3:
                st.caption("**Full-Price Mix %** — weekly (target 75%)")
                st.plotly_chart(area(df, "FP_MIX_PCT", "FP Mix %", C_PUR, ".1f",
                                target={"v": 75, "lbl": "Target 75%"}),
                                use_container_width=True, key="p_fp")
            with r4:
                st.caption("**UPT — CY vs LY**")
                st.plotly_chart(mline(df, ["UPT", "LY_UPT"], ["CY UPT", "LY UPT"],
                                [C_PUR, C_GRAY], ".2f"), use_container_width=True, key="p_upt")

        # ── 3PL ───────────────────────────────────────────────
        elif sn == "3PL":
            k1, k2, k3, k4 = st.columns(4)
            k1.markdown(card("SHIPMENTS",     f"{int(df.TOTAL_SHIPMENTS.sum()):,}", "period total"), unsafe_allow_html=True)
            k2.markdown(card("UNITS SHIPPED", f"{int(df.UNITS_SHIPPED.sum()):,}", ""), unsafe_allow_html=True)
            k3.markdown(card("AVG OTD %",     f"{df.OTD_PCT.mean():.1f}%", ""), unsafe_allow_html=True)
            k4.markdown(card("TOTAL FREIGHT", f"${df.TOTAL_FREIGHT_COST.sum()/1e3:.0f}K", "period"), unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
            r1, r2 = st.columns(2)
            with r1:
                st.caption("**On-Time Delivery %** — weekly (target 92%)")
                colors_otd = [C_GRN if v >= 92 else C_RED for v in df.OTD_PCT]
                fig_otd = go.Figure(go.Scatter(
                    x=df.WEEK, y=df.OTD_PCT, mode="lines+markers",
                    line=dict(color=C_GRN, width=2.5),
                    marker=dict(size=8, color=colors_otd),
                    fill="tozeroy", fillcolor="rgba(16,185,129,0.08)",
                    hovertemplate="%{x}<br>OTD: %{y:.1f}%<extra></extra>",
                ))
                fig_otd.add_hline(y=92, line_dash="dot", line_color=C_AMB,
                                  annotation_text="Target 92%", annotation_font_size=9)
                st.plotly_chart(_lay(fig_otd), use_container_width=True, key="t_otd")
            with r2:
                st.caption("**Shipments & Avg Freight** — weekly")
                st.plotly_chart(bar_line(df, "TOTAL_SHIPMENTS", "AVG_FREIGHT_PER_SHIPMENT",
                                "Shipments", "Avg Freight ($)",
                                bc_col=C_TEAL, lc_col=C_AMB, bf=",d", lf="$.2f"),
                                use_container_width=True, key="t_ship")
            r3, r4 = st.columns(2)
            with r3:
                st.caption("**Total Freight Cost** — weekly ($)")
                st.plotly_chart(area(df, "TOTAL_FREIGHT_COST", "Total Freight ($)", C_AMB, "$,.0f"),
                                use_container_width=True, key="t_frt")
            with r4:
                st.caption("**Fill Rate %** — weekly (target 95%)")
                st.plotly_chart(area(df, "FILL_RATE_PCT", "Fill Rate %", C_GRN, ".1f",
                                target={"v": 95, "lbl": "Target 95%"}),
                                use_container_width=True, key="t_fill")

        # ── WMS ───────────────────────────────────────────────
        elif sn == "WMS":
            k1, k2, k3, k4 = st.columns(4)
            k1.markdown(card("INV VALUE (last)", f"${df.TOTAL_INV_VALUE.iloc[-1]/1e6:.2f}M", ""),  unsafe_allow_html=True)
            k2.markdown(card("AVG SELL-THRU",   f"{df.SELL_THRU_PCT.mean():.1f}%", ""),           unsafe_allow_html=True)
            k3.markdown(card("AVG DAYS STOCK",  f"{df.DAYS_OF_STOCK.mean():.0f}", "days"),         unsafe_allow_html=True)
            k4.markdown(card("MARKDOWN RISK",   f"${df.MARKDOWN_RISK_VALUE.sum()/1e3:.0f}K", "period"), unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
            r1, r2 = st.columns(2)
            with r1:
                st.caption("**Inventory Value** — weekly ($)")
                st.plotly_chart(area(df, "TOTAL_INV_VALUE", "Inventory ($)", C_PUR, "$,.0f"),
                                use_container_width=True, key="w_inv")
            with r2:
                st.caption("**Sell-Through % & Days of Stock**")
                st.plotly_chart(bar_line(df, "DAYS_OF_STOCK", "SELL_THRU_PCT",
                                "Days of Stock", "Sell-Through %",
                                bc_col=C_AMB, lc_col=C_GRN, bf=".0f", lf=".1f"),
                                use_container_width=True, key="w_st")
            r3, r4 = st.columns(2)
            with r3:
                st.caption("**Inventory Turns** — annualised")
                st.plotly_chart(area(df, "INV_TURNS", "Turns (ann.)", C_TEAL, ".2f"),
                                use_container_width=True, key="w_turns")
            with r4:
                st.caption("**Critical SKUs** — needing reorder")
                fig_c = go.Figure(go.Bar(
                    x=df.WEEK, y=df.CRITICAL_SKUS,
                    marker_color=[C_RED if v >= 12 else C_AMB if v >= 6 else C_GRN
                                  for v in df.CRITICAL_SKUS],
                    hovertemplate="%{x}<br>Critical SKUs: %{y}<extra></extra>",
                ))
                st.plotly_chart(_lay(fig_c), use_container_width=True, key="w_crit")

        # ── CRM ───────────────────────────────────────────────
        elif sn == "CRM":
            k1, k2, k3, k4 = st.columns(4)
            k1.markdown(card("NEW CUSTOMERS", f"{int(df.NEW_CUSTOMERS.sum()):,}", "period"),       unsafe_allow_html=True)
            k2.markdown(card("AVG LTV",       f"${df.AVG_LTV.mean():,.0f}", "per customer"),       unsafe_allow_html=True)
            k3.markdown(card("AVG CSAT",      f"{df.CSAT_SCORE.mean():.2f}/5", ""),               unsafe_allow_html=True)
            k4.markdown(card("AVG NPS",       f"{df.NPS.mean():.0f}", "net promoter score"),       unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
            r1, r2 = st.columns(2)
            with r1:
                st.caption("**New Customers & Churn %**")
                st.plotly_chart(bar_line(df, "NEW_CUSTOMERS", "CHURN_PCT",
                                "New Customers", "Churn %",
                                bc_col=C_PUR, lc_col=C_RED, bf=",d", lf=".2f"),
                                use_container_width=True, key="c_nc")
            with r2:
                st.caption("**CSAT & NPS trends**")
                fig_cn = make_subplots(specs=[[{"secondary_y": True}]])
                fig_cn.add_trace(go.Scatter(x=df.WEEK, y=df.CSAT_SCORE, name="CSAT (/5)",
                    line=dict(color=C_GRN, width=2.5), mode="lines+markers", marker_size=5,
                    hovertemplate="%{x}<br>CSAT: %{y:.2f}<extra></extra>"), secondary_y=False)
                fig_cn.add_trace(go.Scatter(x=df.WEEK, y=df.NPS, name="NPS",
                    line=dict(color=C_PUR, width=2.5), mode="lines+markers", marker_size=5,
                    hovertemplate="%{x}<br>NPS: %{y:.0f}<extra></extra>"), secondary_y=True)
                _lay(fig_cn)
                fig_cn.update_yaxes(showgrid=False, secondary_y=True)
                st.plotly_chart(fig_cn, use_container_width=True, key="c_csat")
            r3, r4 = st.columns(2)
            with r3:
                st.caption("**Active Customers & At-Risk**")
                st.plotly_chart(bar_line(df, "ACTIVE_CUSTOMERS", "AT_RISK_COUNT",
                                "Active Customers", "At-Risk Count",
                                bc_col=C_TEAL, lc_col=C_RED, bf=",d", lf=",d"),
                                use_container_width=True, key="c_act")
            with r4:
                st.caption("**Customer Segments** — weekly")
                fig_seg = go.Figure([
                    go.Bar(x=df.WEEK, y=df.CHAMPION_COUNT, name="Champions",
                           marker_color="#22c55e", opacity=0.85,
                           hovertemplate="%{x}<br>Champions: %{y:,d}<extra></extra>"),
                    go.Bar(x=df.WEEK, y=df.LOYALIST_COUNT, name="Loyalists",
                           marker_color=C_PUR, opacity=0.75,
                           hovertemplate="%{x}<br>Loyalists: %{y:,d}<extra></extra>"),
                    go.Bar(x=df.WEEK, y=df.AT_RISK_COUNT, name="At Risk",
                           marker_color=C_RED, opacity=0.65,
                           hovertemplate="%{x}<br>At Risk: %{y:,d}<extra></extra>"),
                ])
                fig_seg.update_layout(barmode="group")
                st.plotly_chart(_lay(fig_seg), use_container_width=True, key="c_seg")

        # ── HR ────────────────────────────────────────────────
        elif sn == "HR":
            k1, k2, k3, k4 = st.columns(4)
            k1.markdown(card("HEADCOUNT",    str(int(df.HEADCOUNT.iloc[-1])), "last week"),         unsafe_allow_html=True)
            k2.markdown(card("LABOUR COST",  f"${df.TOTAL_LABOUR_COST.sum()/1e6:.2f}M", "period"), unsafe_allow_html=True)
            k3.markdown(card("AVG WAGE",     f"${df.AVG_WAGE_RATE.mean():.2f}/hr", ""),             unsafe_allow_html=True)
            k4.markdown(card("OT HOURS",     f"{int(df.OT_HOURS.sum()):,}", "period total"),        unsafe_allow_html=True)
            st.markdown("<br>", unsafe_allow_html=True)
            r1, r2 = st.columns(2)
            with r1:
                st.caption("**Labour Cost & OT Hours**")
                st.plotly_chart(bar_line(df, "TOTAL_LABOUR_COST", "OT_HOURS",
                                "Labour Cost ($)", "OT Hours",
                                bc_col=C_PUR, lc_col=C_AMB, bf="$,.0f", lf=",d"),
                                use_container_width=True, key="h_cost")
            with r2:
                st.caption("**Headcount & Absenteeism**")
                st.plotly_chart(bar_line(df, "HEADCOUNT", "ABSENT_DAYS",
                                "Headcount", "Absent Days",
                                bc_col=C_TEAL, lc_col=C_RED, bf=",d", lf=",d"),
                                use_container_width=True, key="h_hc")
            r3, r4 = st.columns(2)
            with r3:
                st.caption("**Regular vs OT Hours** — stacked")
                fig_rh = go.Figure([
                    go.Bar(x=df.WEEK, y=df.REG_HOURS, name="Regular",
                           marker_color=C_PUR, opacity=0.82,
                           hovertemplate="%{x}<br>Regular: %{y:,d}<extra></extra>"),
                    go.Bar(x=df.WEEK, y=df.OT_HOURS, name="Overtime",
                           marker_color=C_AMB, opacity=0.82,
                           hovertemplate="%{x}<br>OT: %{y:,d}<extra></extra>"),
                ])
                fig_rh.update_layout(barmode="stack")
                st.plotly_chart(_lay(fig_rh), use_container_width=True, key="h_rh")
            with r4:
                st.caption("**Labour % of Sales & Turnover %**")
                st.plotly_chart(mline(df, ["LABOUR_PCT_OF_SALES", "TURNOVER_PCT"],
                                ["Labour % Sales", "Turnover %"], [C_GRN, C_RED], ".2f"),
                                use_container_width=True, key="h_l_pct")

        # ── Raw data expander (CSV download only, no per-source push) ──
        st.markdown("<br>", unsafe_allow_html=True)
        with st.expander(
            f"📋  Raw data — {len(df)} weeks  ·  {len(df.columns)} columns  ·  "
            f"{info['rows']:,} source records  ·  target: CORE.{info['stg']}",
            expanded=False,
        ):
            st.dataframe(
                df.style.format(precision=2),
                use_container_width=True,
                hide_index=True,
                height=280,
            )
            st.caption(
                f"All **{len(df.columns)} columns** shown above.  "
                f"Snowflake target: **RETAIL_ANALYTICS.CORE.{info['stg']}**  ·  "
                f"{info['rows']:,} source records (daily granularity aggregated weekly for this preview)."
            )
            st.download_button(
                "⬇  Download CSV",
                df.to_csv(index=False).encode(),
                f"{sn.lower().replace('/','_')}_pipeline_W{w1:02d}_W{w2:02d}.csv",
                "text/csv",
                key=f"dl_{sn}",
            )

# ─────────────────────────────────────────────────────────────
# FOOTER
# ─────────────────────────────────────────────────────────────
st.markdown("---")
st.markdown(
    '<div style="text-align:center;padding:14px 0 6px;color:#5a5a68;font-size:13px">'
    'All sources loaded into Snowflake.  Data is ready for analysis and reporting.</div>',
    unsafe_allow_html=True,
)
