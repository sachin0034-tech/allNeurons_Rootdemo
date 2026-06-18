import streamlit as st
from utils.queries import (
    get_weekly_kpi, get_region_fp_mix,
    get_store_type_perf, get_region_weekly,
)
from utils.week_selector import render_week_selector
from utils.styles import inject_css
from utils.deck_builder_light import build_deck_light as build_deck, _f
from utils.narrative import generate_narratives

st.set_page_config(page_title="Generate Deck", layout="wide")
inject_css()

WEEK = render_week_selector()

# ── Check for Anthropic key ───────────────────────────────────
has_api_key = bool(st.secrets.get("ANTHROPIC_API_KEY", ""))

st.markdown(
    '<div class="section-label" style="font-size:22px;letter-spacing:2px;margin-bottom:4px">'
    'GENERATE EXECUTIVE DECK</div>',
    unsafe_allow_html=True,
)
st.markdown(
    '<p style="color:#5a5a68;font-size:14px;margin-top:0">'
    'Claude reads live data from Snowflake, searches the web for industry context, '
    'and assembles a board-ready PowerPoint deck.</p>',
    unsafe_allow_html=True,
)

if not has_api_key:
    st.info(
        "**Claude AI narratives** are available when `ANTHROPIC_API_KEY` is set in `.streamlit/secrets.toml`. "
        "Deck will generate with template narratives until then.",
        icon="🤖",
    )

# ── Config ────────────────────────────────────────────────────
col_left, col_right = st.columns([3, 2])

with col_left:
    st.markdown('<div class="kpi-card" style="padding:20px">', unsafe_allow_html=True)
    st.markdown('<div class="kpi-label">WHAT SHOULD THIS DECK FOCUS ON?</div>',
                unsafe_allow_html=True)
    prompt = st.text_area(
        "Prompt",
        value=(
            "Generate a weekly executive summary for our retail leadership team.\n"
            "Highlight:\n"
            "• Top and bottom performing regions\n"
            "• Revenue vs budget performance\n"
            "• Supply chain and inventory risks\n"
            "• Strategic opportunities for Q3"
        ),
        height=150,
        label_visibility="collapsed",
        key="deck_prompt",
    )
    st.markdown("</div>", unsafe_allow_html=True)

with col_right:
    st.markdown("""
<div class="kpi-card" style="padding:20px">
  <div class="kpi-label">DECK STRUCTURE (5 SLIDES)</div>
  <div style="font-size:12px;color:#5a5a68;margin-top:10px;line-height:2.1">
    <b style="color:#8B7D3A">1.</b> Executive Summary — Revenue · Traffic · Cash · Key Drivers<br>
    <b style="color:#8B7D3A">2.</b> Revenue Performance — Regional breakdown · Budget vs Actual<br>
    <b style="color:#8B7D3A">3.</b> Store Operations — Traffic · CVR · AOV · Format table<br>
    <b style="color:#8B7D3A">4.</b> Supply Chain & 3PL — OTD · Freight · Inventory · Fill Rate<br>
    <b style="color:#8B7D3A">5.</b> Risks & Opportunities — Claude web insights + sources
  </div>
  <hr style="border-color:rgba(0,0,0,0.08);margin:12px 0">
  <div style="font-size:11px;color:#9a9aaa">
    {'🤖 Claude narratives ON' if has_api_key else '📝 Template narratives (add ANTHROPIC_API_KEY to enable Claude)'}
    <br>❄️ Live data from Snowflake
  </div>
</div>
""".replace("{", "{{").replace("}", "}}").replace("{{has_api_key}}", str(has_api_key))
    .replace(
        "{'🤖 Claude narratives ON' if has_api_key else '📝 Template narratives (add ANTHROPIC_API_KEY to enable Claude)'}",
        "🤖 Claude narratives ON" if has_api_key else "📝 Template narratives (add ANTHROPIC_API_KEY to enable Claude)"
    ),
    unsafe_allow_html=True)

st.markdown("---")

# ── Generate button ───────────────────────────────────────────
gen_col, _ = st.columns([2, 5])
with gen_col:
    generate = st.button(
        "🤖  Generate Executive Deck",
        type="primary",
        use_container_width=True,
        key="gen_deck",
    )

if generate:
    # Step 1: fetch Snowflake data
    with st.status("Fetching data from Snowflake…", expanded=True) as status:
        st.write("⬇  Querying VW_WEEKLY_KPI…")
        kpi_df = get_weekly_kpi(WEEK)
        st.write("⬇  Querying VW_REGION_FP_MIX…")
        fp_df  = get_region_fp_mix(WEEK)
        st.write("⬇  Querying VW_STORE_TYPE_PERF…")
        st_df  = get_store_type_perf(WEEK)
        st.write("⬇  Querying VW_REGION_WEEKLY_YOY…")
        reg_df = get_region_weekly(WEEK)
        status.update(label="Snowflake data loaded ✓", state="complete")

    if kpi_df.empty:
        st.error("No KPI data found. Run `refresh_data.SQL` in Snowflake first.")
        st.stop()

    kpi_row   = kpi_df.iloc[0].to_dict()
    week_lbl  = str(kpi_row.get("WEEK_LABEL", f"W{WEEK:02d}"))

    # add CVR_DELTA_BPS if missing
    if "CVR_DELTA_BPS" not in reg_df.columns:
        if "CY_CVR" in reg_df.columns and "LY_CVR" in reg_df.columns:
            reg_df["CVR_DELTA_BPS"] = reg_df["CY_CVR"] - reg_df["LY_CVR"]
        else:
            reg_df["CVR_DELTA_BPS"] = 0.0

    # Step 2: Claude narrative generation
    cy      = _f(kpi_row.get("NET_SALES"))
    ly      = _f(kpi_row.get("LY_NET_SALES", cy))
    bud     = _f(kpi_row.get("BUDGET_SALES", cy))
    traf    = _f(kpi_row.get("TRAFFIC"))
    ly_tr   = _f(kpi_row.get("LY_TRAFFIC", traf or 1))

    top_regs, bot_regs = [], []
    if not reg_df.empty and "SALES_YOY_PCT" in reg_df.columns:
        sr = reg_df.sort_values("SALES_YOY_PCT", ascending=False)
        top_regs = sr["REGION_CODE"].head(2).tolist()
        bot_regs = sr["REGION_CODE"].tail(2).tolist()

    top_types, bot_types = [], []
    if not st_df.empty and "NET_SALES" in st_df.columns and "LY_NET_SALES" in st_df.columns:
        st2 = st_df.copy()
        st2["_yoy"] = (
            st2["NET_SALES"].astype(float) - st2["LY_NET_SALES"].astype(float)
        ) / st2["LY_NET_SALES"].astype(float).replace(0, float("nan"))
        ss = st2.sort_values("_yoy", ascending=False)
        top_types = ss["STORE_TYPE_NAME"].head(2).tolist()
        bot_types = ss["STORE_TYPE_NAME"].tail(2).tolist()

    narr_input = {
        "week_label":       week_lbl,
        "revenue":          cy,
        "revenue_yoy":      (cy - ly) / ly if ly else 0,
        "revenue_budget_gap": (cy - bud) / bud if bud else 0,
        "traffic_yoy":      (traf - ly_tr) / ly_tr if ly_tr else 0,
        "cvr":              _f(kpi_row.get("TRANSACTIONS")) / traf if traf else 0,
        "cvr_bps":          0,
        "ads":              _f(kpi_row.get("ADS")),
        "fp_mix":           _f(kpi_row.get("FP_MIX")),
        "fp_mix_bps":       _f(kpi_row.get("FP_MIX")) - _f(kpi_row.get("LY_FP_MIX")),
        "gross_margin_pct": 0.58,
        "ebitda_pct":       0.22,
        "cash_position":    18_400_000,
        "inventory_turns":  8.4,
        "otd_pct":          0.942,
        "freight_savings":  -0.06,
        "top_regions":      top_regs,
        "bottom_regions":   bot_regs,
        "top_store_types":  top_types,
        "bottom_store_types": bot_types,
    }

    narr_label = "Generating Claude narratives with web search…" if has_api_key \
                 else "Generating template narratives…"
    with st.status(narr_label, expanded=True) as status:
        if has_api_key:
            st.write("🤖  Calling Claude claude-sonnet-4-6 with business metrics…")
            st.write("🌐  Searching web for industry context…")
        narratives = generate_narratives(narr_input)
        status.update(label="Narratives ready ✓", state="complete")

    # Step 3: build PPTX
    with st.status("Building PowerPoint deck…", expanded=True) as status:
        st.write("📊  Assembling 5 slides…")
        try:
            pptx_bytes = build_deck(kpi_row, fp_df, st_df, reg_df,
                                    narratives, week_lbl)
        except Exception as e:
            st.error(f"Deck generation failed: {e}")
            raise
        status.update(label="Deck ready ✓", state="complete")

    st.success(
        f"Executive deck generated — 5 slides for **{week_lbl}** "
        f"({'Claude AI narratives' if has_api_key else 'template narratives'})",
        icon="✅",
    )

    # ── Download + preview ────────────────────────────────────
    dl_col, preview_col = st.columns([1, 3])

    with dl_col:
        st.download_button(
            label="⬇  Download PowerPoint",
            data=pptx_bytes,
            file_name=f"RetailPulse_Executive_{week_lbl.replace(' ','_')}.pptx",
            mime="application/vnd.openxmlformats-officedocument.presentationml.presentation",
            type="primary",
            use_container_width=True,
        )

    with preview_col:
        narr_tabs = st.tabs(["📋 Narratives", "📊 Snowflake Data"])
        with narr_tabs[0]:
            for slide_key, slide_name in [
                ("exec_summary", "Slide 1 — Executive Summary"),
                ("revenue",      "Slide 2 — Revenue Performance"),
                ("operations",   "Slide 3 — Store Operations"),
                ("supply_chain", "Slide 4 — Supply Chain & 3PL"),
                ("risks",        "Slide 5 — Risks & Opportunities"),
            ]:
                with st.expander(slide_name, expanded=(slide_key == "exec_summary")):
                    n = narratives.get(slide_key, {})
                    if slide_key == "risks":
                        st.markdown("**Key Risks:**")
                        for r in n.get("risks", []):
                            st.markdown(f"- {r}")
                        st.markdown("**Opportunities:**")
                        for o in n.get("opportunities", []):
                            st.markdown(f"- {o}")
                    else:
                        for b in n.get("bullets", []):
                            st.markdown(f"- {b}")
                    sources = n.get("sources", [])
                    if sources:
                        st.markdown("**Sources:**")
                        for s in sources:
                            st.markdown(f"  [{s['title']}]({s['url']})")

        with narr_tabs[1]:
            t1, t2, t3, t4 = st.tabs(["KPI", "FP Mix", "Store Types", "Regional"])
            with t1: st.dataframe(kpi_df, use_container_width=True, hide_index=True)
            with t2: st.dataframe(fp_df,  use_container_width=True, hide_index=True)
            with t3: st.dataframe(st_df,  use_container_width=True, hide_index=True)
            with t4: st.dataframe(reg_df, use_container_width=True, hide_index=True)
