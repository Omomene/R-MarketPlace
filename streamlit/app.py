import os

import pandas as pd
import psycopg2
import streamlit as st


# ============================================================
# CONFIGURATION
# ============================================================

st.set_page_config(
    page_title="Marketplace Analytics",
    page_icon="",
    layout="wide"
)

st.title("Marketplace Analytics")
st.caption("Analyse des ventes, vendeurs et anomalies")


# ============================================================
# DATABASE CONNECTION
# ============================================================

@st.cache_resource
def get_connection():

    return psycopg2.connect(
        host=os.getenv("DB_HOST", "postgres"),
        port=os.getenv("DB_PORT", "5432"),
        database=os.getenv("DB_NAME", "marketplace"),
        user=os.getenv("DB_USER", "app"),
        password=os.getenv("DB_PASSWORD", "app12345")
    )


def load_data(query):

    conn = get_connection()

    return pd.read_sql_query(
        query,
        conn
    )


# ============================================================
# CHECK DATABASE
# ============================================================

try:

    conn = get_connection()

except Exception as e:

    st.error(
        "Impossible de se connecter à PostgreSQL."
    )

    st.exception(e)

    st.stop()


# ============================================================
# LOAD GOLD DATA
# ============================================================

daily_revenue = load_data(
    """
    SELECT
        dt,
        total_orders,
        revenue,
        average_order_value,
        total_quantity
    FROM gold.daily_revenue
    ORDER BY dt
    """
)


seller_analysis = load_data(
    """
    SELECT
        seller_id,
        dt,
        orders,
        revenue,
        average_order_value,
        avg_7d,
        drop_flag
    FROM gold.seller_analysis
    ORDER BY dt
    """
)


anomalies = load_data(
    """
    SELECT
        seller_id,
        dt,
        metric,
        value,
        threshold
    FROM gold.anomalies
    ORDER BY dt DESC
    """
)


# ============================================================
# CHECK DATA
# ============================================================

if daily_revenue.empty:

    st.warning(
        "Aucune donnée disponible dans PostgreSQL Gold."
    )

    st.info(
        "Lancez d'abord le pipeline Airflow."
    )

    st.stop()


# ============================================================
# SIDEBAR FILTER
# ============================================================

st.sidebar.header("Filtres")

min_date = daily_revenue["dt"].min()
max_date = daily_revenue["dt"].max()

selected_dates = st.sidebar.date_input(
    "Période",
    value=(min_date, max_date),
    min_value=min_date,
    max_value=max_date
)


if len(selected_dates) == 2:

    start_date = selected_dates[0]
    end_date = selected_dates[1]

    filtered_revenue = daily_revenue[
        (daily_revenue["dt"] >= pd.Timestamp(start_date))
        &
        (daily_revenue["dt"] <= pd.Timestamp(end_date))
    ]

else:

    filtered_revenue = daily_revenue


# ============================================================
# KPIs
# ============================================================

total_revenue = filtered_revenue[
    "revenue"
].sum()

total_orders = filtered_revenue[
    "total_orders"
].sum()

average_order_value = (
    filtered_revenue["revenue"].sum()
    /
    filtered_revenue["total_orders"].sum()
    if filtered_revenue["total_orders"].sum() > 0
    else 0
)

number_anomalies = len(
    anomalies[
        (anomalies["dt"] >= pd.Timestamp(start_date))
        &
        (anomalies["dt"] <= pd.Timestamp(end_date))
    ]
)


col1, col2, col3, col4 = st.columns(4)

col1.metric(
    "Chiffre d'affaires",
    f"{total_revenue:,.2f} €"
)

col2.metric(
    "Commandes",
    f"{total_orders:,}"
)

col3.metric(
    "Panier moyen",
    f"{average_order_value:,.2f} €"
)

col4.metric(
    "Anomalies",
    f"{number_anomalies}"
)


# ============================================================
# REVENUE EVOLUTION
# ============================================================

st.divider()

st.subheader("Évolution du chiffre d'affaires")

chart_data = filtered_revenue.set_index("dt")[
    ["revenue"]
]

st.line_chart(
    chart_data
)


# ============================================================
# ORDERS EVOLUTION
# ============================================================

st.subheader("Évolution du nombre de commandes")

orders_chart = filtered_revenue.set_index("dt")[
    ["total_orders"]
]

st.line_chart(
    orders_chart
)


# ============================================================
# TOP SELLERS
# ============================================================

st.divider()

st.subheader("Top vendeurs")

seller_filtered = seller_analysis[
    (seller_analysis["dt"] >= pd.Timestamp(start_date))
    &
    (seller_analysis["dt"] <= pd.Timestamp(end_date))
]

top_sellers = (
    seller_filtered
    .groupby("seller_id", as_index=False)
    ["revenue"]
    .sum()
    .sort_values(
        "revenue",
        ascending=False
    )
    .head(10)
)

col1, col2 = st.columns(2)

with col1:

    st.bar_chart(
        top_sellers.set_index("seller_id")[
            ["revenue"]
        ]
    )

with col2:

    display_sellers = top_sellers.copy()

    display_sellers["revenue"] = (
        display_sellers["revenue"]
        .round(2)
    )

    st.dataframe(
        display_sellers,
        use_container_width=True,
        hide_index=True
    )


# ============================================================
# SELLER PERFORMANCE
# ============================================================

st.divider()

st.subheader("Performance des vendeurs")

seller_display = seller_filtered.copy()

seller_display["revenue"] = (
    seller_display["revenue"]
    .round(2)
)

seller_display["avg_7d"] = (
    seller_display["avg_7d"]
    .round(2)
)

seller_display["average_order_value"] = (
    seller_display["average_order_value"]
    .round(2)
)

st.dataframe(
    seller_display.sort_values(
        ["dt", "revenue"],
        ascending=[False, False]
    ),
    use_container_width=True,
    hide_index=True
)


# ============================================================
# ANOMALIES
# ============================================================

st.divider()

st.subheader("Anomalies détectées")

filtered_anomalies = anomalies[
    (anomalies["dt"] >= pd.Timestamp(start_date))
    &
    (anomalies["dt"] <= pd.Timestamp(end_date))
]

if filtered_anomalies.empty:

    st.success(
        "Aucune anomalie détectée sur cette période."
    )

else:

    st.warning(
        f"{len(filtered_anomalies)} anomalie(s) détectée(s)."
    )

    anomaly_display = filtered_anomalies.copy()

    anomaly_display["value"] = (
        anomaly_display["value"]
        .round(2)
    )

    anomaly_display["threshold"] = (
        anomaly_display["threshold"]
        .round(2)
    )

    st.dataframe(
        anomaly_display,
        use_container_width=True,
        hide_index=True
    )


# ============================================================
# FOOTER
# ============================================================

st.divider()

st.caption(
    "Marketplace Analytics — Groupe 11"
)