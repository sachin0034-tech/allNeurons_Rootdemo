from utils.snowflake_conn import run_query


def get_weekly_kpi(week: int):
    return run_query(
        "SELECT * FROM VW_WEEKLY_KPI WHERE WEEK_NUM = %(week)s",
        {"week": week},
    )


def get_region_fp_mix(week: int):
    return run_query(
        "SELECT * FROM VW_REGION_FP_MIX WHERE WEEK_NUM = %(week)s ORDER BY FP_MIX DESC",
        {"week": week},
    )


def get_store_type_perf(week: int):
    return run_query(
        "SELECT * FROM VW_STORE_TYPE_PERF WHERE WEEK_NUM = %(week)s",
        {"week": week},
    )


def get_region_weekly(week: int):
    return run_query(
        "SELECT * FROM VW_REGION_WEEKLY_YOY WHERE WEEK_NUM = %(week)s",
        {"week": week},
    )


def get_nso_stores():
    return run_query(
        """
        SELECT s.STORE_NUM, s.STORE_NAME, r.REGION_CODE,
               st.STORE_TYPE_NAME, s.OPEN_DATE
        FROM DIM_STORE s
        JOIN DIM_REGION r      ON s.REGION_ID      = r.REGION_ID
        JOIN DIM_STORE_TYPE st ON s.STORE_TYPE_ID  = st.STORE_TYPE_ID
        WHERE s.IS_NSO = TRUE AND s.IS_ACTIVE = TRUE
        ORDER BY s.OPEN_DATE DESC
        """
    )


def get_available_weeks():
    return run_query(
        "SELECT WEEK_NUM, WEEK_LABEL, MIN(DATE_ID) AS WEEK_START "
        "FROM DIM_DATE GROUP BY WEEK_NUM, WEEK_LABEL ORDER BY WEEK_NUM"
    )
