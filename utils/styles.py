import streamlit as st


def inject_css():
    st.markdown(
        """
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

        /* ── Global background ──────────────────────────────────── */
        .stApp {
            background-color: #fafaff;
            background-image:
                radial-gradient(at 20% 0%,   rgba(255, 224, 240, 0.85) 0%, transparent 50%),
                radial-gradient(at 80% 30%,  rgba(212, 228, 255, 0.85) 0%, transparent 50%),
                radial-gradient(at 50% 100%, rgba(224, 212, 255, 0.80) 0%, transparent 50%);
            background-attachment: fixed;
            font-family: 'Inter', sans-serif;
        }

        /* ── Sidebar glass ──────────────────────────────────────── */
        [data-testid="stSidebar"] {
            background: rgba(255, 255, 255, 0.72) !important;
            backdrop-filter: blur(20px) saturate(160%);
            -webkit-backdrop-filter: blur(20px) saturate(160%);
            border-right: 1px solid rgba(255, 255, 255, 0.5) !important;
            box-shadow: 4px 0 24px rgba(15, 15, 20, 0.06);
        }
        [data-testid="stSidebar"] > div:first-child {
            background: transparent !important;
        }

        /* ── Main container ─────────────────────────────────────── */
        .block-container {
            background: transparent !important;
            padding-top: 2rem;
        }

        /* ── KPI Card (frosted glass) ───────────────────────────── */
        .kpi-card {
            background: rgba(255, 255, 255, 0.60);
            backdrop-filter: blur(20px) saturate(160%);
            -webkit-backdrop-filter: blur(20px) saturate(160%);
            border: 1px solid rgba(255, 255, 255, 0.55);
            border-radius: 16px;
            padding: 18px 20px;
            margin-bottom: 12px;
            box-shadow:
                0 8px 32px rgba(15, 15, 20, 0.07),
                inset 0 1px 0 rgba(255, 255, 255, 0.65);
            transition: box-shadow 0.2s ease;
        }
        .kpi-card:hover {
            box-shadow:
                0 12px 40px rgba(139, 92, 246, 0.12),
                inset 0 1px 0 rgba(255, 255, 255, 0.65);
        }

        .kpi-label {
            color: #8b5cf6;
            font-size: 10px;
            letter-spacing: 1.8px;
            text-transform: uppercase;
            font-weight: 600;
            font-family: 'Inter', sans-serif;
        }
        .kpi-value {
            color: #0f0f14;
            font-size: 28px;
            font-weight: 600;
            margin: 6px 0 4px;
            font-family: 'Inter', sans-serif;
            letter-spacing: -0.5px;
        }
        .kpi-sub {
            color: #5a5a68;
            font-size: 12px;
            font-family: 'Inter', sans-serif;
        }
        .badge {
            display: inline-block;
            border-radius: 8px;
            padding: 3px 10px;
            font-size: 12px;
            font-weight: 600;
            margin-top: 6px;
            font-family: 'Inter', sans-serif;
        }

        /* ── Header banner ──────────────────────────────────────── */
        .header-banner {
            background: rgba(255, 255, 255, 0.65);
            backdrop-filter: blur(20px) saturate(160%);
            -webkit-backdrop-filter: blur(20px) saturate(160%);
            border: 1px solid rgba(255, 255, 255, 0.55);
            border-left: 4px solid #8b5cf6;
            border-radius: 16px;
            padding: 18px 24px;
            margin-bottom: 24px;
            box-shadow:
                0 8px 32px rgba(15, 15, 20, 0.07),
                inset 0 1px 0 rgba(255, 255, 255, 0.65);
        }
        .header-title {
            color: #0f0f14;
            font-size: 15px;
            font-weight: 600;
            letter-spacing: 0.2px;
            font-family: 'Inter', sans-serif;
        }
        .header-sub {
            color: #5a5a68;
            font-size: 12px;
            margin-top: 6px;
            font-family: 'Inter', sans-serif;
        }

        /* ── Section label ──────────────────────────────────────── */
        .section-label {
            color: #8b5cf6;
            font-size: 10px;
            letter-spacing: 2px;
            text-transform: uppercase;
            font-weight: 600;
            margin: 20px 0 10px;
            padding-bottom: 6px;
            border-bottom: 1px solid rgba(139, 92, 246, 0.18);
            font-family: 'Inter', sans-serif;
        }

        /* ── Streamlit widget overrides ─────────────────────────── */
        [data-testid="stSelectbox"] > div > div {
            background: rgba(255, 255, 255, 0.75) !important;
            border: 1px solid rgba(15, 15, 20, 0.10) !important;
            border-radius: 12px !important;
            backdrop-filter: blur(12px);
            color: #0f0f14 !important;
        }

        [data-testid="baseButton-secondary"] {
            background: rgba(255, 255, 255, 0.70) !important;
            border: 1px solid rgba(139, 92, 246, 0.30) !important;
            border-radius: 12px !important;
            color: #8b5cf6 !important;
            backdrop-filter: blur(12px);
            font-weight: 500;
        }
        [data-testid="baseButton-secondary"]:hover {
            background: rgba(139, 92, 246, 0.08) !important;
            border-color: #8b5cf6 !important;
        }

        [data-testid="stDownloadButton"] button {
            background: rgba(255, 255, 255, 0.70) !important;
            border: 1px solid rgba(139, 92, 246, 0.30) !important;
            border-radius: 12px !important;
            color: #8b5cf6 !important;
            backdrop-filter: blur(12px);
            font-weight: 500;
        }

        .stTextArea textarea {
            background: rgba(255, 255, 255, 0.75) !important;
            border: 1px solid rgba(15, 15, 20, 0.10) !important;
            border-radius: 12px !important;
            color: #0f0f14 !important;
        }
        .stTextArea textarea:focus {
            border-color: #8b5cf6 !important;
            box-shadow: 0 0 0 2px rgba(139, 92, 246, 0.18) !important;
        }

        /* ── Plotly chart glass wrap ────────────────────────────── */
        [data-testid="stPlotlyChart"] {
            background: rgba(255, 255, 255, 0.55);
            backdrop-filter: blur(20px) saturate(160%);
            -webkit-backdrop-filter: blur(20px) saturate(160%);
            border: 1px solid rgba(255, 255, 255, 0.55);
            border-radius: 16px;
            padding: 4px;
            box-shadow:
                0 8px 32px rgba(15, 15, 20, 0.07),
                inset 0 1px 0 rgba(255, 255, 255, 0.65);
        }

        /* ── Scrollbar ──────────────────────────────────────────── */
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb {
            background: rgba(139, 92, 246, 0.25);
            border-radius: 2px;
        }

        /* ── HR divider ─────────────────────────────────────────── */
        hr { border-color: rgba(15, 15, 20, 0.07) !important; margin: 6px 0 !important; }

        /* ── Hide Streamlit toolbar ─────────────────────────────── */
        [data-testid="stHeader"]  { display: none !important; }
        [data-testid="stToolbar"] { display: none !important; }
        #MainMenu                 { display: none !important; }
        footer                    { display: none !important; }

        /* ── Hide page navigation links from sidebar ────────────── */
        [data-testid="stSidebarNav"] { display: none !important; }
        </style>
        """,
        unsafe_allow_html=True,
    )
