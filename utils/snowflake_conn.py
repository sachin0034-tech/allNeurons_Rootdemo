import snowflake.connector
import streamlit as st
import pandas as pd


@st.cache_resource
def get_connection():
    return snowflake.connector.connect(
        account=st.secrets["SNOWFLAKE_ACCOUNT"],
        user=st.secrets["SNOWFLAKE_USER"],
        password=st.secrets["SNOWFLAKE_PASSWORD"],
        database="RETAIL_ANALYTICS",
        schema="CORE",
        warehouse="COMPUTE_WH",
    )


@st.cache_data(ttl=300)
def run_query(sql: str, params: dict = None) -> pd.DataFrame:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(sql, params or {})
    df = cur.fetch_pandas_all()
    cur.close()
    return df
