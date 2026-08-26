import os

import pandas as pd
import psycopg2
import streamlit as st
import plotly.express as px


# ============================================================
# CONFIGURATION
# ============================================================

st.set_page_config(
    page_title="Marketplace Analytics",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)


# ============================================================
# THEME
# ============================================================

PRIMARY = "#1F3A5F"
SECONDARY = "#2E5EAA"
ACCENT = "#4C9AFF"
LIGHT_BLUE = "#EAF2FB"
DARK = "#172B4D"
GREY = "#6B778C"
LIGHT_GREY = "#F4F6F8"
GREEN = "#2E8B57"
RED = "#C94C4C"
ORANGE = "#D98C00"

# ============================================================
# CUSTOM CSS
# ============================================================

st.markdown(
    f"""
    <style>

    /* ================================
       GLOBAL
    ================================= */

    .block-container {{
        padding-top: 1.5rem;
        padding-bottom: 2rem;
        max-width: 1500px;
    }}

    body {{
        background-color: #F7F9FC;
    }}

    /* ================================
       HEADER
    ================================= */

    .dashboard-header {{
        background: linear-gradient(
            135deg,
            {PRIMARY},
            {SECONDARY}
        );

        padding: 24px 30px;
        border-radius: 14px;

        color: white;

        margin-bottom: 22px;

        box-shadow:
            0 4px 12px rgba(31, 58, 95, 0.15);
    }}

    .dashboard-header h1 {{
        color: white;
        font-size: 34px;
        font-weight: 700;
        margin: 0;
    }}

    .dashboard-header p {{
        color: #E8EEF7;
        font-size: 15px;
        margin-top: 6px;
        margin-bottom: 0;
    }}

    /* ================================
       SECTION TITLES
    ================================= */

    .section-title {{
        color: {DARK};
        font-size: 21px;
        font-weight: 700;
        margin-top: 8px;
        margin-bottom: 12px;
    }}

    /* ================================
       KPI CARDS
    ================================= */

    .kpi-card {{
        background: white;
        border-radius: 12px;
        padding: 18px 20px;
        min-height: 110px;
        border: 1px solid #E6EAF0;

        box-shadow:
            0 2px 8px rgba(0, 0, 0, 0.04);
    }}

    .kpi-label {{
        color: {GREY};
        font-size: 14px;
        font-weight: 500;
        margin-bottom: 8px;
    }}

    .kpi-value {{
        color: {DARK};
        font-size: 27px;
        font-weight: 700;
    }}

    .kpi-subtitle {{
        color: #8A94A6;
        font-size: 12px;
        margin-top: 4px;
    }}

    /* ================================
       CHART CARDS
    ================================= */

    .chart-card {{
        background: white;
        border-radius: 12px;
        padding: 12px 14px 4px 14px;
        border: 1px solid #E6EAF0;

        box-shadow:
            0 2px 8px rgba(0, 0, 0, 0.035);
    }}

    /* ================================
       STATUS CARDS
    ================================= */

    .success-card {{
        background: #F0F8F3;
        border: 1px solid #C8E6D2;
        border-left: 5px solid {GREEN};
        border-radius: 10px;
        padding: 15px 18px;
        color: #246B45;
        font-weight: 500;
    }}

    .warning-card {{
        background: #FFF8E8;
        border: 1px solid #F2D38A;
        border-left: 5px solid {ORANGE};
        border-radius: 10px;
        padding: 15px 18px;
        color: #795600;
        font-weight: 500;
    }}

    /* ================================
       SIDEBAR
    ================================= */

    section[data-testid="stSidebar"] {{
        background-color: #F7F9FC;
    }}

    section[data-testid="stSidebar"] h2 {{
        color: {DARK};
    }}

    /* ================================
       TABLES
    ================================= */

    div[data-testid="stDataFrame"] {{
        border-radius: 10px;
        overflow: hidden;
    }}

    /* ================================
       DIVIDERS
    ================================= */

    hr {{
        border: none;
        border-top: 1px solid #E5E9EF;
        margin-top: 22px;
        margin-bottom: 22px;
    }}

    </style>
    """,
    unsafe_allow_html=True
)

# ============================================================
# HEADER
# ============================================================

st.markdown(
    '<div class="dashboard-header">'
    '<h1>Marketplace Analytics</h1>'
    '<p>Analyse des ventes, vendeurs, catégories et anomalies</p>'
    '</div>',
    unsafe_allow_html=True
)


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
# DATABASE CHECK
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

revenue_analysis = load_data(
    """
    SELECT
        order_date,
        total_orders,
        total_revenue,
        average_order_value,
        total_commission
    FROM gold.revenue_analysis
    ORDER BY order_date
    """
)


seller_analysis = load_data(
    """
    SELECT
        seller_id,
        seller_name,
        order_date,
        total_orders,
        revenue,
        average_order_value,
        rank
    FROM gold.seller_analysis
    ORDER BY order_date
    """
)


category_analysis = load_data(
    """
    SELECT
        category,
        order_date,
        total_orders,
        revenue,
        average_order_value
    FROM gold.category_analysis
    ORDER BY order_date
    """
)


anomaly_results = load_data(
    """
    SELECT
        anomaly_id,
        order_date,
        metric,
        value,
        expected_value,
        threshold,
        anomaly_type,
        is_anomaly
    FROM gold.anomaly_results
    ORDER BY order_date DESC
    """
)


# ============================================================
# CHECK DATA
# ============================================================

if revenue_analysis.empty:

    st.warning(
        "Aucune donnée disponible dans PostgreSQL Gold."
    )

    st.info(
        "Lancez d'abord le pipeline Airflow."
    )

    st.stop()


# ============================================================
# DATE CONVERSION
# ============================================================

revenue_analysis["order_date"] = pd.to_datetime(
    revenue_analysis["order_date"]
)

seller_analysis["order_date"] = pd.to_datetime(
    seller_analysis["order_date"]
)

category_analysis["order_date"] = pd.to_datetime(
    category_analysis["order_date"]
)

anomaly_results["order_date"] = pd.to_datetime(
    anomaly_results["order_date"]
)


# ============================================================
# SIDEBAR
# ============================================================

st.sidebar.markdown(
    "## Filtres"
)

st.sidebar.markdown(
    "Sélectionnez la période d'analyse."
)

min_date = revenue_analysis["order_date"].min().date()
max_date = revenue_analysis["order_date"].max().date()


selected_dates = st.sidebar.date_input(
    "Période",
    value=(min_date, max_date),
    min_value=min_date,
    max_value=max_date
)


if len(selected_dates) == 2:

    start_date = pd.Timestamp(
        selected_dates[0]
    )

    end_date = (
        pd.Timestamp(selected_dates[1])
        + pd.Timedelta(days=1)
        - pd.Timedelta(seconds=1)
    )

else:

    start_date = pd.Timestamp(min_date)

    end_date = (
        pd.Timestamp(max_date)
        + pd.Timedelta(days=1)
        - pd.Timedelta(seconds=1)
    )


st.sidebar.divider()

st.sidebar.caption(
    f"Données disponibles : "
    f"{min_date.strftime('%d/%m/%Y')} → "
    f"{max_date.strftime('%d/%m/%Y')}"
)


# ============================================================
# FILTER DATA
# ============================================================

filtered_revenue = revenue_analysis[
    (revenue_analysis["order_date"] >= start_date)
    &
    (revenue_analysis["order_date"] <= end_date)
]


filtered_sellers = seller_analysis[
    (seller_analysis["order_date"] >= start_date)
    &
    (seller_analysis["order_date"] <= end_date)
]


filtered_categories = category_analysis[
    (category_analysis["order_date"] >= start_date)
    &
    (category_analysis["order_date"] <= end_date)
]


filtered_anomalies = anomaly_results[
    (anomaly_results["order_date"] >= start_date)
    &
    (anomaly_results["order_date"] <= end_date)
    &
    (anomaly_results["is_anomaly"] == True)
]


# ============================================================
# KPI CALCULATIONS
# ============================================================

total_revenue = filtered_revenue[
    "total_revenue"
].sum()


total_orders = filtered_revenue[
    "total_orders"
].sum()


average_order_value = (
    total_revenue / total_orders
    if total_orders > 0
    else 0
)


total_commission = filtered_revenue[
    "total_commission"
].sum()


number_anomalies = len(
    filtered_anomalies
)


# ============================================================
# KPI SECTION
# ============================================================

st.markdown(
    '<div class="section-title">Vue d’ensemble</div>',
    unsafe_allow_html=True
)

col1, col2, col3, col4 = st.columns(4)


# ============================================================
# KPI 1 — REVENUE
# ============================================================

with col1:

    st.markdown(
        f'<div class="kpi-card">'
        f'<div class="kpi-label">Chiffre d\'affaires</div>'
        f'<div class="kpi-value">{total_revenue:,.2f} €</div>'
        f'<div class="kpi-subtitle">Revenus sur la période</div>'
        f'</div>',
        unsafe_allow_html=True
    )


# ============================================================
# KPI 2 — ORDERS
# ============================================================

with col2:

    st.markdown(
        f'<div class="kpi-card">'
        f'<div class="kpi-label">Commandes</div>'
        f'<div class="kpi-value">{total_orders:,}</div>'
        f'<div class="kpi-subtitle">Commandes traitées</div>'
        f'</div>',
        unsafe_allow_html=True
    )


# ============================================================
# KPI 3 — AVERAGE ORDER VALUE
# ============================================================

with col3:

    st.markdown(
        f'<div class="kpi-card">'
        f'<div class="kpi-label">Panier moyen</div>'
        f'<div class="kpi-value">{average_order_value:,.2f} €</div>'
        f'<div class="kpi-subtitle">Valeur moyenne par commande</div>'
        f'</div>',
        unsafe_allow_html=True
    )


# ============================================================
# KPI 4 — ANOMALIES
# ============================================================

with col4:

    anomaly_color = RED if number_anomalies > 0 else GREEN

    st.markdown(
        f'<div class="kpi-card">'
        f'<div class="kpi-label">Anomalies</div>'
        f'<div class="kpi-value" style="color:{anomaly_color};">'
        f'{number_anomalies}'
        f'</div>'
        f'<div class="kpi-subtitle">Anomalies détectées</div>'
        f'</div>',
        unsafe_allow_html=True
    )


# ============================================================
# DAILY EVOLUTION
# ============================================================

st.divider()

st.markdown(
    '<div class="section-title">Évolution quotidienne</div>',
    unsafe_allow_html=True
)


# Force exactly one row per calendar day
daily_chart = (
    filtered_revenue
    .assign(
        order_date=lambda df:
            df["order_date"].dt.normalize()
    )
    .groupby(
        "order_date",
        as_index=False
    )
    .agg(
        total_revenue=(
            "total_revenue",
            "sum"
        ),

        total_orders=(
            "total_orders",
            "sum"
        ),

        total_commission=(
            "total_commission",
            "sum"
        )
    )
    .sort_values(
        "order_date"
    )
)


def create_line_chart(
    dataframe,
    y_column,
    title,
    y_format
):

    fig = px.line(
        dataframe,
        x="order_date",
        y=y_column,
        markers=True
    )

    fig.update_layout(
        height=230,

        title=dict(
            text=title,
            font=dict(
                size=15,
                color=DARK
            ),
            x=0
        ),

        plot_bgcolor="white",
        paper_bgcolor="white",

        font=dict(
            family="Arial",
            color=DARK
        ),

        margin=dict(
            l=10,
            r=10,
            t=45,
            b=10
        ),

        xaxis=dict(
            title=None,
            type="date",
            tickformat="%d/%m",
            showgrid=False
        ),

        yaxis=dict(
            title=None,
            tickformat=y_format,
            showgrid=True,
            gridcolor="#EAECEF",
            zeroline=False
        ),

        hovermode="x unified"
    )

    return fig


col1, col2, col3 = st.columns(3)


with col1:

    fig = create_line_chart(
        daily_chart,
        "total_revenue",
        "Chiffre d'affaires",
        ",.0f"
    )

    st.plotly_chart(
        fig,
        use_container_width=True,
        config={
            "displayModeBar": False
        }
    )


with col2:

    fig = create_line_chart(
        daily_chart,
        "total_orders",
        "Commandes",
        ",.0f"
    )

    st.plotly_chart(
        fig,
        use_container_width=True,
        config={
            "displayModeBar": False
        }
    )


with col3:

    fig = create_line_chart(
        daily_chart,
        "total_commission",
        "Commissions",
        ",.0f"
    )

    st.plotly_chart(
        fig,
        use_container_width=True,
        config={
            "displayModeBar": False
        }
    )


# ============================================================
# TOP SELLERS
# ============================================================

st.divider()

st.markdown(
    '<div class="section-title">Top vendeurs</div>',
    unsafe_allow_html=True
)


top_sellers = (
    filtered_sellers
    .groupby(
        ["seller_id", "seller_name"],
        as_index=False
    )
    ["revenue"]
    .sum()
    .sort_values(
        "revenue",
        ascending=False
    )
    .head(10)
)


col1, col2 = st.columns(
    [1.5, 1]
)


with col1:

    fig = px.bar(
        top_sellers,
        x="revenue",
        y="seller_name",
        orientation="h"
    )

    fig.update_layout(
        height=350,

        plot_bgcolor="white",
        paper_bgcolor="white",

        font=dict(
            family="Arial",
            color=DARK
        ),

        margin=dict(
            l=10,
            r=10,
            t=10,
            b=10
        ),

        xaxis=dict(
            title=None,
            showgrid=True,
            gridcolor="#EAECEF"
        ),

        yaxis=dict(
            title=None,
            categoryorder="total ascending"
        ),

        showlegend=False
    )

    st.plotly_chart(
        fig,
        use_container_width=True,
        config={
            "displayModeBar": False
        }
    )


with col2:

    display_sellers = top_sellers.copy()

    display_sellers["revenue"] = (
        display_sellers["revenue"]
        .round(2)
    )

    display_sellers = display_sellers[
        [
            "seller_name",
            "revenue"
        ]
    ]

    display_sellers.columns = [
        "Vendeur",
        "CA (€)"
    ]

    st.dataframe(
        display_sellers,
        use_container_width=True,
        hide_index=True,
        height=350
    )


# ============================================================
# CATEGORY ANALYSIS
# ============================================================

st.divider()

st.markdown(
    '<div class="section-title">Performance par catégorie</div>',
    unsafe_allow_html=True
)


category_summary = (
    filtered_categories
    .groupby(
        "category",
        as_index=False
    )
    ["revenue"]
    .sum()
    .sort_values(
        "revenue",
        ascending=False
    )
)


col1, col2 = st.columns(
    [1.5, 1]
)


with col1:

    fig = px.bar(
        category_summary,
        x="revenue",
        y="category",
        orientation="h"
    )

    fig.update_layout(
        height=300,

        plot_bgcolor="white",
        paper_bgcolor="white",

        font=dict(
            family="Arial",
            color=DARK
        ),

        margin=dict(
            l=10,
            r=10,
            t=10,
            b=10
        ),

        xaxis=dict(
            title=None,
            showgrid=True,
            gridcolor="#EAECEF"
        ),

        yaxis=dict(
            title=None,
            categoryorder="total ascending"
        ),

        showlegend=False
    )

    st.plotly_chart(
        fig,
        use_container_width=True,
        config={
            "displayModeBar": False
        }
    )


with col2:

    category_display = category_summary.copy()

    category_display["revenue"] = (
        category_display["revenue"]
        .round(2)
    )

    category_display.columns = [
        "Catégorie",
        "CA (€)"
    ]

    st.dataframe(
        category_display,
        use_container_width=True,
        hide_index=True,
        height=300
    )


# ============================================================
# SELLER PERFORMANCE
# ============================================================

st.divider()

st.markdown(
    '<div class="section-title">Performance des vendeurs</div>',
    unsafe_allow_html=True
)


seller_display = filtered_sellers.copy()


seller_display["revenue"] = (
    seller_display["revenue"]
    .round(2)
)


seller_display["average_order_value"] = (
    seller_display["average_order_value"]
    .round(2)
)


seller_display = seller_display[
    [
        "seller_name",
        "order_date",
        "total_orders",
        "revenue",
        "average_order_value",
        "rank"
    ]
]


seller_display.columns = [
    "Vendeur",
    "Date",
    "Commandes",
    "CA (€)",
    "Panier moyen (€)",
    "Rang"
]


seller_display = seller_display.sort_values(
    ["Date", "CA (€)"],
    ascending=[False, False]
)


st.dataframe(
    seller_display,
    use_container_width=True,
    hide_index=True,
    height=350
)


# ============================================================
# ANOMALIES
# ============================================================

st.divider()

st.markdown(
    '<div class="section-title">Anomalies détectées</div>',
    unsafe_allow_html=True
)


if filtered_anomalies.empty:

    st.markdown(
        """
        <div class="success-card">
            ✓ Aucune anomalie détectée sur la période sélectionnée.
        </div>
        """,
        unsafe_allow_html=True
    )

else:

    st.markdown(
        f"""
        <div class="warning-card">
            ⚠ {len(filtered_anomalies)}
            anomalie(s) détectée(s) sur la période sélectionnée.
        </div>
        """,
        unsafe_allow_html=True
    )

    anomaly_display = filtered_anomalies.copy()


    anomaly_display["value"] = (
        anomaly_display["value"]
        .round(2)
    )


    anomaly_display["expected_value"] = (
        anomaly_display["expected_value"]
        .round(2)
    )


    anomaly_display["threshold"] = (
        anomaly_display["threshold"]
        .round(2)
    )


    anomaly_display = anomaly_display[
        [
            "order_date",
            "metric",
            "value",
            "expected_value",
            "threshold",
            "anomaly_type"
        ]
    ]


    anomaly_display.columns = [
        "Date",
        "Métrique",
        "Valeur",
        "Valeur attendue",
        "Seuil",
        "Type"
    ]


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
    "Marketplace Analytics — Groupe 11 | "
    "Architecture Bronze → Silver → Gold"
)