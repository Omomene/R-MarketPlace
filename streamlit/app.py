import pandas as pd
import streamlit as st
import altair as alt

from queries import (
    get_customer_anomalies,
    get_kpi_country,
    get_kpi_monthly,
    get_model_coefficients,
    get_model_metrics,
    get_transactions,
)

st.set_page_config(
    page_title="Marketplace Analytics",
    page_icon="🛍️",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    '''
    <style>
    .block-container {
        padding-top: 4.15rem !important;
        padding-bottom: 0.65rem !important;
        padding-left: 1.3rem !important;
        padding-right: 1.3rem !important;
        max-width: 1500px !important;
    }

    section[data-testid="stSidebar"] {
        width: 205px !important;
        min-width: 205px !important;
        background: #f3f6fb;
        border-right: 1px solid #e1e6ef;
    }

    section[data-testid="stSidebar"] > div {
        padding-top: 3.1rem !important;
        padding-left: 0.85rem !important;
        padding-right: 0.85rem !important;
    }

    section[data-testid="stSidebar"] h2 {
        font-size: 1.05rem !important;
        margin: 0 0 0.65rem 0 !important;
    }

    section[data-testid="stSidebar"] label {
        font-size: 0.76rem !important;
    }

    section[data-testid="stSidebar"] input,
    section[data-testid="stSidebar"] [data-baseweb="select"] {
        font-size: 0.76rem !important;
    }

    .marketplace-header {
        width: 100%;
        text-align: center;
        margin: 0 0 0.55rem 0;
        padding: 0.20rem 0 0.30rem 0.05rem;
    }

    .marketplace-title {
        display: inline-block;
        font-size: 1.48rem;
        line-height: 1.15;
        font-weight: 800;
        color: #1d2638;
        padding: 0 0 0.10rem 0;
        border-bottom: 3px solid #4f86ef;
    }

    .marketplace-subtitle {
        margin-top: 0.20rem;
        color: #7a8394;
        font-size: 0.70rem;
    }

    .trend-chart-title {
        font-size: 0.88rem;
        font-weight: 700;
        color: #2d3444;
        margin: 0.15rem 0 0.30rem 0;
        line-height: 1.2;
    }

    .lower-chart-title {
        font-size: 0.84rem;
        font-weight: 700;
        color: #2d3444;
        margin: 0.45rem 0 0.35rem 0;
        line-height: 1.2;
    }

    div[data-testid="stMetric"] {
        background: #ffffff !important;
        border: 1px solid #dfe4ec !important;
        border-radius: 12px !important;
        padding: 0.46rem 0.68rem !important;
        min-height: 72px !important;
        box-shadow: 0 4px 12px rgba(20, 40, 80, 0.09) !important;
    }

    div[data-testid="stMetricLabel"] {
        font-size: 0.70rem !important;
    }

    div[data-testid="stMetricValue"] {
        font-size: 1.20rem !important;
        font-weight: 750 !important;
    }

    button[data-baseweb="tab"] {
        font-size: 0.76rem !important;
        padding-left: 0.45rem !important;
        padding-right: 0.45rem !important;
    }

    h2 { font-size: 1.02rem !important; }
    h3 { font-size: 0.91rem !important; }
    h4 {
        font-size: 0.82rem !important;
        margin-top: 0.1rem !important;
        margin-bottom: 0.28rem !important;
    }

    p, .stMarkdown {
        font-size: 0.79rem !important;
    }

    div[data-testid="stVerticalBlock"] {
        gap: 0.42rem !important;
    }

    div[data-testid="stDataFrame"] {
        border: 1px solid #e0e5ed;
        border-radius: 9px;
        overflow: hidden;
    }

    .dashboard-footer {
        text-align: center;
        color: #8a92a1;
        font-size: 0.68rem;
        padding-top: 0.35rem;
    }
    </style>
    ''',
    unsafe_allow_html=True,
)

st.markdown(
    '''
    <div class="marketplace-header">
        <div class="marketplace-title">🛍️ Marketplace Analytics</div>
        <div class="marketplace-subtitle">
            Analyse des ventes, vendeurs et anomalies
        </div>
    </div>
    ''',
    unsafe_allow_html=True,
)

try:
    transactions = get_transactions()
    kpi_monthly = get_kpi_monthly()
    kpi_country = get_kpi_country()
    anomalies = get_customer_anomalies()
    model_coefficients = get_model_coefficients()
    model_metrics = get_model_metrics()
except Exception as exc:
    st.error("Impossible de charger les données réelles depuis PostgreSQL.")
    st.exception(exc)
    st.stop()

if transactions.empty:
    st.warning("La table silver.orders ne contient aucune donnée.")
    st.stop()

if "invoice_date" not in transactions.columns:
    st.error("Les données Silver ne contiennent pas la date attendue.")
    st.stop()

transactions["invoice_date"] = pd.to_datetime(transactions["invoice_date"], errors="coerce")
transactions = transactions.dropna(subset=["invoice_date"]).copy()

transactions["transaction_amount"] = pd.to_numeric(
    transactions["transaction_amount"], errors="coerce"
).fillna(0)

transactions["quantity"] = pd.to_numeric(
    transactions.get("quantity", 0), errors="coerce"
).fillna(0)

min_date = transactions["invoice_date"].min().date()
max_date = transactions["invoice_date"].max().date()

st.sidebar.markdown("## Filtres")

start_date = st.sidebar.date_input(
    "Date de début",
    value=min_date,
    min_value=min_date,
    max_value=max_date,
)

end_date = st.sidebar.date_input(
    "Date de fin",
    value=max_date,
    min_value=min_date,
    max_value=max_date,
)

if start_date > end_date:
    st.sidebar.error("La date de début doit être avant la date de fin.")
    st.stop()

category_options = ["Toutes"]
if "category" in transactions.columns:
    category_options += sorted(
        transactions["category"].dropna().astype(str).unique().tolist()
    )

selected_category = st.sidebar.selectbox("Catégorie", category_options)

seller_options = ["Tous les vendeurs"]
if "seller_id" in transactions.columns:
    seller_options += sorted(
        transactions["seller_id"].dropna().astype(str).unique().tolist()
    )

selected_seller = st.sidebar.selectbox("Vendeur", seller_options)

filtered = transactions[
    (transactions["invoice_date"].dt.date >= start_date)
    & (transactions["invoice_date"].dt.date <= end_date)
].copy()

if selected_category != "Toutes" and "category" in filtered.columns:
    filtered = filtered[
        filtered["category"].astype(str) == selected_category
    ]

if selected_seller != "Tous les vendeurs" and "seller_id" in filtered.columns:
    filtered = filtered[
        filtered["seller_id"].astype(str) == selected_seller
    ]

total_revenue = float(filtered["transaction_amount"].sum())
total_orders = int(filtered["invoice"].nunique()) if "invoice" in filtered.columns else int(len(filtered))
average_order_value = total_revenue / total_orders if total_orders else 0.0
active_sellers = int(filtered["seller_id"].nunique()) if "seller_id" in filtered.columns else 0

c1, c2, c3, c4 = st.columns(4)
c1.metric("Chiffre d'affaires", f"{total_revenue:,.0f} €")
c2.metric("Commandes", f"{total_orders:,}")
c3.metric("Panier moyen", f"{average_order_value:,.2f} €")
c4.metric("Vendeurs actifs", f"{active_sellers:,}")

daily = (
    filtered.assign(dt=filtered["invoice_date"].dt.floor("D"))
    .groupby("dt", as_index=False)
    .agg(
        revenue=("transaction_amount", "sum"),
        total_orders=("invoice", "nunique"),
    )
    .sort_values("dt")
)

category_df = pd.DataFrame()
if "category" in filtered.columns:
    category_df = (
        filtered.assign(category=filtered["category"].fillna("Autres"))
        .groupby("category", as_index=False)
        .agg(revenue=("transaction_amount", "sum"))
        .sort_values("revenue", ascending=False)
    )

seller_df = pd.DataFrame()
if "seller_id" in filtered.columns:
    seller_df = (
        filtered.groupby("seller_id", as_index=False)
        .agg(
            revenue=("transaction_amount", "sum"),
            orders=("invoice", "nunique"),
        )
        .sort_values("revenue", ascending=False)
    )

status_df = pd.DataFrame()
if "status" in filtered.columns:
    status_work = filtered[["invoice", "status"]].copy()

    def map_status(value):
        value = str(value).strip().lower()
        if value in {
            "cancelled", "canceled", "annulée", "annulee",
            "cancel", "refunded", "rejected"
        }:
            return "Commandes annulées"
        return "Commandes validées"

    status_work["status_group"] = status_work["status"].apply(map_status)
    status_df = (
        status_work.groupby("status_group", as_index=False)
        .agg(orders=("invoice", "nunique"))
    )

def line_chart(df, x, y, title, y_title):
    if df.empty:
        st.info("Aucune donnée disponible.")
        return

    st.markdown(
        f'<div class="trend-chart-title">{title}</div>',
        unsafe_allow_html=True,
    )

    chart = (
        alt.Chart(df)
        .mark_line(strokeWidth=2.25, color="#1474d4")
        .encode(
            x=alt.X(
                f"{x}:T",
                title=None,
                axis=alt.Axis(
                    format="%d %b",
                    labelAngle=0,
                    tickCount=7,
                    labelFontSize=10,
                ),
            ),
            y=alt.Y(
                f"{y}:Q",
                title=y_title,
                axis=alt.Axis(labelFontSize=10, titleFontSize=11),
                scale=alt.Scale(zero=True),
            ),
            tooltip=[
                alt.Tooltip(f"{x}:T", title="Date", format="%d/%m/%Y"),
                alt.Tooltip(f"{y}:Q", title=y_title, format=",.2f"),
            ],
        )
        .properties(height=220)
        .configure_view(strokeOpacity=0)
        .configure_axis(gridColor="#e5eaf2")
    )

    st.altair_chart(chart, use_container_width=True)

def donut_chart(df, names, values, title):
    if df.empty:
        st.info("Aucune donnée disponible.")
        return

    work = df.copy()
    work[values] = pd.to_numeric(work[values], errors="coerce").fillna(0)

    total = work[values].sum()
    if total > 0:
        work["percentage"] = work[values] / total * 100
    else:
        work["percentage"] = 0

    base = alt.Chart(work).encode(
        theta=alt.Theta(
            f"{values}:Q",
            stack=True,
        ),
        color=alt.Color(
            f"{names}:N",
            legend=alt.Legend(
                title=None,
                orient="right",
                labelFontSize=9,
            ),
        ),
        tooltip=[
            alt.Tooltip(f"{names}:N", title=""),
            alt.Tooltip(f"{values}:Q", title="Valeur", format=",.2f"),
            alt.Tooltip("percentage:Q", title="Part", format=".1f"),
        ],
    )

    arcs = base.mark_arc(
        innerRadius=35,
        outerRadius=58,
    )

    labels = base.mark_text(
        radius=47,
        size=9,
        fontWeight="bold",
        color="#1f2937",
    ).encode(
        text=alt.Text(
            "percentage:Q",
            format=".1f"
        )
    )

    chart = (
        (arcs + labels)
        .properties(
            height=145,
        )
        .configure_view(strokeOpacity=0)
    )

    st.altair_chart(
        chart,
        use_container_width=True,
    )

def seller_bar_chart(df):
    if df.empty:
        st.info("Aucune donnée disponible.")
        return

    top = df.head(5).copy()
    top["revenue"] = pd.to_numeric(
        top["revenue"], errors="coerce"
    ).fillna(0)

    bars = (
        alt.Chart(top)
        .mark_bar(
            cornerRadiusEnd=3,
            color="#2f6fed",
        )
        .encode(
            y=alt.Y(
                "seller_id:N",
                sort="-x",
                title=None,
                axis=alt.Axis(labelFontSize=9),
            ),
            x=alt.X(
                "revenue:Q",
                title="CA (€)",
                axis=alt.Axis(labelFontSize=9, format="~s"),
            ),
            tooltip=[
                alt.Tooltip("seller_id:N", title="Vendeur"),
                alt.Tooltip("revenue:Q", title="CA", format=",.2f"),
                alt.Tooltip("orders:Q", title="Commandes"),
            ],
        )
    )

    labels = (
        alt.Chart(top)
        .mark_text(
            align="left",
            baseline="middle",
            dx=4,
            fontSize=9,
            color="#374151",
        )
        .encode(
            y=alt.Y(
                "seller_id:N",
                sort="-x",
            ),
            x=alt.X("revenue:Q"),
            text=alt.Text(
                "revenue:Q",
                format=",.0f",
            ),
        )
    )

    chart = (
        (bars + labels)
        .properties(
            height=145,
        )
        .configure_view(strokeOpacity=0)
        .configure_axis(gridColor="#e5eaf2")
    )

    st.altair_chart(
        chart,
        use_container_width=True,
    )

tab_overview, tab_sales, tab_sellers, tab_anomalies, tab_stats = st.tabs(
    [
        "📊 Vue générale",
        "📈 Ventes",
        "👤 Vendeurs",
        "🚨 Anomalies",
        "📐 Statistiques",
    ]
)

with tab_overview:
    top_left, top_right = st.columns(2)

    with top_left:
        line_chart(
            daily,
            "dt",
            "revenue",
            "Évolution du chiffre d'affaires",
            "CA (€)",
        )

    with top_right:
        line_chart(
            daily,
            "dt",
            "total_orders",
            "Évolution des commandes",
            "Commandes",
        )

    st.markdown("<div style='height:0.60rem'></div>", unsafe_allow_html=True)

    bottom_1, bottom_2, bottom_3 = st.columns(3)

    with bottom_1:
        st.markdown(
            '<div class="lower-chart-title">CA par catégorie</div>',
            unsafe_allow_html=True,
        )
        donut_chart(
            category_df,
            "category",
            "revenue",
            "CA par catégorie",
        )

    with bottom_2:
        st.markdown(
            '<div class="lower-chart-title">Top 5 vendeurs par CA</div>',
            unsafe_allow_html=True,
        )
        seller_bar_chart(seller_df)

    with bottom_3:
        st.markdown(
            '<div class="lower-chart-title">Répartition des commandes</div>',
            unsafe_allow_html=True,
        )
        donut_chart(
            status_df,
            "status_group",
            "orders",
            "Répartition des commandes",
        )

    st.markdown(
        f'''
        <div class="dashboard-footer">
            Période sélectionnée :
            <strong>{start_date.strftime("%d/%m/%Y")}</strong>
            →
            <strong>{end_date.strftime("%d/%m/%Y")}</strong>
        </div>
        ''',
        unsafe_allow_html=True,
    )

with tab_sales:
    st.subheader("Analyse des ventes")

    col1, col2 = st.columns(2)

    with col1:
        line_chart(
            daily,
            "dt",
            "revenue",
            "Chiffre d'affaires quotidien",
            "CA (€)",
        )

    with col2:
        line_chart(
            daily,
            "dt",
            "total_orders",
            "Commandes quotidiennes",
            "Commandes",
        )

    if not kpi_monthly.empty:
        st.markdown("#### Évolution mensuelle — Gold")

        monthly = kpi_monthly.copy()
        monthly["total_revenue"] = pd.to_numeric(
            monthly["total_revenue"], errors="coerce"
        )
        monthly["month_date"] = pd.to_datetime(
            monthly["year_month"] + "-01",
            errors="coerce",
        )

        monthly_chart = (
            alt.Chart(monthly)
            .mark_line(point=True, strokeWidth=2.2, color="#1474d4")
            .encode(
                x=alt.X(
                    "month_date:T",
                    title=None,
                    axis=alt.Axis(format="%b %Y", labelAngle=0),
                ),
                y=alt.Y("total_revenue:Q", title="CA (€)"),
                tooltip=[
                    alt.Tooltip("year_month:N", title="Mois"),
                    alt.Tooltip(
                        "total_revenue:Q",
                        title="CA",
                        format=",.2f",
                    ),
                ],
            )
            .properties(height=165)
            .configure_view(strokeOpacity=0)
            .configure_axis(gridColor="#e5eaf2")
        )

        st.altair_chart(monthly_chart, use_container_width=True)

    st.markdown("#### Synthèse des transactions")
    display = filtered.sort_values("invoice_date", ascending=False).copy()

    st.dataframe(
        display.head(500),
        use_container_width=True,
        hide_index=True,
        height=235,
    )

with tab_sellers:
    st.subheader("Analyse des vendeurs")

    if seller_df.empty:
        st.info("Aucune donnée vendeur disponible.")
    else:
        seller_view = seller_df.copy()
        seller_view["average_order_value"] = (
            seller_view["revenue"]
            / seller_view["orders"].replace(0, pd.NA)
        )

        col1, col2 = st.columns(2)

        with col1:
            seller_bar_chart(seller_view)

        with col2:
            st.markdown("#### Classement")

            display_sellers = seller_view.head(10).copy()
            display_sellers["revenue"] = display_sellers["revenue"].round(2)
            display_sellers["average_order_value"] = (
                display_sellers["average_order_value"].round(2)
            )

            st.dataframe(
                display_sellers,
                use_container_width=True,
                hide_index=True,
                height=250,
            )

    if not kpi_country.empty:
        st.markdown("#### Performance clients par pays")
        country_display = kpi_country.copy()
        country_display["total_revenue"] = pd.to_numeric(
            country_display["total_revenue"],
            errors="coerce",
        ).round(2)

        st.dataframe(
            country_display,
            use_container_width=True,
            hide_index=True,
            height=215,
        )

with tab_anomalies:
    st.subheader("Anomalies détectées")

    if anomalies.empty:
        st.success("Aucune anomalie détectée dans gold.customer_anomalies.")
    else:
        anomaly_display = anomalies.copy()
        anomaly_display["detected_at"] = pd.to_datetime(
            anomaly_display["detected_at"],
            errors="coerce",
        )

        if "customer_id" in filtered.columns:
            selected_customers = (
                filtered["customer_id"]
                .dropna()
                .astype(str)
                .unique()
            )
            period_anomalies = anomaly_display[
                anomaly_display["customer_id"]
                .astype(str)
                .isin(selected_customers)
            ].copy()
        else:
            period_anomalies = anomaly_display.copy()

        col1, col2, col3 = st.columns(3)
        col1.metric("Anomalies", len(period_anomalies))
        col2.metric(
            "Clients concernés",
            period_anomalies["customer_id"].nunique(),
        )
        col3.metric(
            "Types d'anomalies",
            period_anomalies["anomaly_type"].nunique(),
        )

        if "metric_value" in period_anomalies.columns:
            period_anomalies["metric_value"] = pd.to_numeric(
                period_anomalies["metric_value"],
                errors="coerce",
            ).round(2)

        if "threshold_value" in period_anomalies.columns:
            period_anomalies["threshold_value"] = pd.to_numeric(
                period_anomalies["threshold_value"],
                errors="coerce",
            ).round(2)

        st.dataframe(
            period_anomalies,
            use_container_width=True,
            hide_index=True,
            height=270,
        )

with tab_stats:
    st.subheader("Analyse statistique avec R")

    if model_metrics.empty and model_coefficients.empty:
        st.info("Aucun résultat statistique disponible dans la Gold.")
    else:
        if not model_metrics.empty:
            metrics = model_metrics.copy()
            metrics["metric_value"] = pd.to_numeric(
                metrics["metric_value"],
                errors="coerce",
            )

            latest_run = metrics["run_date"].max()
            latest_metrics = metrics[metrics["run_date"] == latest_run]

            st.markdown(f"Résultats du **{latest_run}**")

            st.dataframe(
                latest_metrics,
                use_container_width=True,
                hide_index=True,
                height=250,
            )

            def metric_value(name, decimals=3):
                subset = latest_metrics[
                    latest_metrics["metric_name"]
                    .astype(str)
                    .str.lower()
                    == name.lower()
                ]

                if subset.empty:
                    return "—"

                value = subset.iloc[0]["metric_value"]

                if pd.isna(value):
                    return "—"

                return f"{value:.{decimals}f}"

            col1, col2, col3 = st.columns(3)
            col1.metric("AUC", metric_value("auc", 3))
            col2.metric("R²", metric_value("r_squared", 3))
            col3.metric("RMSE", metric_value("rmse", 2))

        if not model_coefficients.empty:
            st.markdown("#### Coefficients des modèles")

            coeffs = model_coefficients.copy()
            latest_coeff_run = coeffs["run_date"].max()
            coeffs = coeffs[coeffs["run_date"] == latest_coeff_run]

            st.dataframe(
                coeffs,
                use_container_width=True,
                hide_index=True,
                height=300,
            )
