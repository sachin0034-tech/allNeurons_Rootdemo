import streamlit as st
from utils.queries import get_available_weeks
from utils.snowflake_conn import run_query


def render_week_selector() -> int:
    """Renders the sidebar week picker and returns the selected WEEK_NUM."""
    weeks_df = get_available_weeks()
    week_options = {
        f"W{str(row.WEEK_NUM).zfill(2)} — week of {row.WEEK_START}": row.WEEK_NUM
        for _, row in weeks_df.iterrows()
    }
    selected_label = st.sidebar.selectbox(
        "Select Week",
        list(week_options.keys()),
        index=len(week_options) - 1,
    )

    st.sidebar.markdown("---")
    if st.sidebar.button("🔄 Refresh Data", use_container_width=True):
        run_query.clear()
        st.rerun()

    return week_options[selected_label]
