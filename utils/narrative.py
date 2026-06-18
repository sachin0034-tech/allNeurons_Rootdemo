"""
Claude-powered narrative generator for executive deck slides.
Calls the Anthropic API with business metrics and returns
per-slide bullet points + sourced external insights.
Falls back to template narratives if no API key is configured.
"""
import json
import streamlit as st


def _template_narratives(data: dict) -> dict:
    """Template-based fallbacks when no Anthropic key is set."""
    cy  = data.get("revenue", 0)
    yoy = data.get("revenue_yoy", 0)
    traf_yoy = data.get("traffic_yoy", 0)

    return {
        "exec_summary": {
            "bullets": [
                f"Revenue of ${cy/1_000_000:.1f}M represents {yoy*100:+.1f}% YoY growth, "
                "driven by new store openings and improved basket metrics.",
                f"Store traffic {'increased' if traf_yoy > 0 else 'declined'} "
                f"{abs(traf_yoy)*100:.1f}% YoY, reflecting broader channel-shift trends.",
                "Inventory optimization initiatives improved turns and reduced markdown exposure.",
                "Cash position remains healthy with sufficient liquidity for planned capex.",
            ],
            "sources": [],
        },
        "revenue": {
            "bullets": [
                "Same-store sales led by Ontario and Alberta markets, offsetting softness in Maritime provinces.",
                "Full-price mix improvement of +280bps YoY reflects reduced promotional dependency.",
                "Budget variance driven by higher-than-planned conversion in Ski City and Street formats.",
                "Q2 seasonal uplift tracking ahead of internal forecast by 3.2%.",
            ],
            "sources": [
                {"title": "Canadian Retail Sales Statistics", "url": "https://www150.statcan.gc.ca/"},
                {"title": "Retail Council of Canada — Industry Benchmarks", "url": "https://www.retailcouncil.org/"},
            ],
        },
        "operations": {
            "bullets": [
                "Traffic increased across all regions; conversion decline in western markets signals merchandising gap.",
                "Average transaction value grew 4.2% driven by UPT improvement in full-price categories.",
                "Ski City and Street formats continue to outperform fleet average on all basket metrics.",
                "Power Centre and Recall formats require targeted intervention — footfall not converting.",
            ],
            "sources": [
                {"title": "McKinsey — Retail Operations Benchmark 2025", "url": "https://www.mckinsey.com/industries/retail"},
            ],
        },
        "supply_chain": {
            "bullets": [
                "On-time delivery at 94.2% — above the 92% industry benchmark for specialty retail.",
                "Freight cost reduction of 6% achieved through carrier renegotiations.",
                "Inventory aging risk concentrated in 3 SKU categories; clearance plan in progress.",
                "Fill rates stable at 96.8%; DC throughput capacity headroom remains adequate.",
            ],
            "sources": [
                {"title": "Gartner Supply Chain Top 25", "url": "https://www.gartner.com/en/supply-chain"},
                {"title": "Canadian Shipper — Freight Rate Index", "url": "https://www.canadianshipper.com/"},
            ],
        },
        "risks": {
            "risks": [
                "Rising labour costs in BC and Ontario (+8–12% minimum wage changes effective Q3).",
                "Inventory aging increasing in 2 categories — clearance risk if not actioned by Week 28.",
                "Conversion softness in western regions may signal a structural merchandising misalignment.",
                "Macro headwinds: consumer confidence index declined 4.2 points in May 2026.",
            ],
            "opportunities": [
                "High-performing Ski City stores have expansion runway — 3 sites in feasibility.",
                "Freight savings (−6%) can extend to 2 additional carrier lanes in Q3.",
                "Loyalty program reactivation of 12,400 lapsed customers could add $2.1M revenue.",
                "Private-label expansion in full-price categories could add 180bps to FP Mix.",
            ],
            "sources": [
                {"title": "Statistics Canada — CPI & Consumer Confidence", "url": "https://www150.statcan.gc.ca/"},
                {"title": "Retail Insider — Canadian Retail Outlook Q2 2026", "url": "https://www.retail-insider.com/"},
                {"title": "Bank of Canada — Economic Outlook", "url": "https://www.bankofcanada.ca/"},
            ],
        },
    }


def generate_narratives(data: dict) -> dict:
    """
    Generate slide narratives using Claude.
    data keys: revenue, revenue_yoy, revenue_budget_gap, traffic_yoy,
               cash_position, inventory_turns, otd_pct, freight_savings,
               top_regions, bottom_regions, week_label
    """
    api_key = st.secrets.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return _template_narratives(data)

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)

        context = f"""
WEEKLY RETAIL ANALYTICS DATA — {data.get('week_label', 'Current Week')}

FINANCIAL:
- Revenue: ${data.get('revenue', 0)/1_000_000:.2f}M  ({data.get('revenue_yoy', 0)*100:+.1f}% YoY)
- Budget variance: {data.get('revenue_budget_gap', 0)*100:+.1f}%
- Cash position: ${data.get('cash_position', 0)/1_000_000:.1f}M
- Gross Margin est: {data.get('gross_margin_pct', 0.58)*100:.1f}%
- EBITDA est: {data.get('ebitda_pct', 0.22)*100:.1f}%

OPERATIONAL:
- Store traffic YoY: {data.get('traffic_yoy', 0)*100:+.1f}%
- Conversion rate: {data.get('cvr', 0)*100:.2f}%  ({data.get('cvr_bps', 0)*10000:+.0f}bps YoY)
- Average transaction: ${data.get('ads', 0):.2f}
- Full-price mix: {data.get('fp_mix', 0)*100:.1f}%  ({data.get('fp_mix_bps', 0)*10000:+.0f}bps YoY)
- Inventory turns: {data.get('inventory_turns', 0):.1f}x
- On-time delivery: {data.get('otd_pct', 0)*100:.1f}%
- Freight cost change: {data.get('freight_savings', 0)*100:+.1f}%

REGIONAL STANDOUTS:
- Top: {', '.join(data.get('top_regions', []))}
- Bottom: {', '.join(data.get('bottom_regions', []))}

STORE TYPES:
- Outperforming: {', '.join(data.get('top_store_types', []))}
- Underperforming: {', '.join(data.get('bottom_store_types', []))}
"""

        prompt = f"""You are an executive business analyst generating board-ready presentation narratives for a Canadian specialty retail company.

{context}

Generate concise, insight-driven narratives for 5 presentation slides. For each slide provide exactly 4 bullet points and 2 external sources (real URLs). Return ONLY valid JSON matching this schema:

{{
  "exec_summary": {{
    "bullets": ["...","...","...","..."],
    "sources": [{{"title": "...", "url": "https://..."}}]
  }},
  "revenue": {{
    "bullets": ["...","...","...","..."],
    "sources": [{{"title": "...", "url": "https://..."}}]
  }},
  "operations": {{
    "bullets": ["...","...","...","..."],
    "sources": [{{"title": "...", "url": "https://..."}}]
  }},
  "supply_chain": {{
    "bullets": ["...","...","...","..."],
    "sources": [{{"title": "...", "url": "https://..."}}]
  }},
  "risks": {{
    "risks": ["...","...","..."],
    "opportunities": ["...","...","..."],
    "sources": [{{"title": "...", "url": "https://..."}}]
  }}
}}

Guidelines:
- Be specific with numbers from the data provided
- Add real industry context (Statistics Canada, Retail Council of Canada, Bank of Canada, McKinsey Retail, etc.)
- Sources must be real URLs from authoritative Canadian or global retail sources
- Risks and opportunities should be actionable and specific to the data"""

        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2000,
            messages=[{"role": "user", "content": prompt}],
        )

        raw = response.content[0].text.strip()
        # strip markdown code fences if present
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        return json.loads(raw)

    except Exception as e:
        st.warning(f"Claude API narrative generation failed ({e}). Using template narratives.")
        return _template_narratives(data)
