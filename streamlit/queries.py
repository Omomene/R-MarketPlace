from db import load_query


def get_transactions():
    """
    Données détaillées réelles utilisées par le dashboard.

    Le Silver réel contient silver.orders et non silver.transactions.
    On renomme les colonnes pour conserver l'interface actuelle du dashboard
    et on joint silver.products afin d'obtenir la catégorie.
    """
    return load_query("""
        SELECT
            o.order_id AS invoice,
            o.customer_id,
            o.seller_id,
            o.product_id,
            o.order_date AS invoice_date,
            o.quantity,
            o.total_amount AS transaction_amount,
            o.status,
            p.category
        FROM silver.orders o
        LEFT JOIN silver.products p
            ON o.product_id = p.product_id
        ORDER BY o.order_date
    """)


def get_kpi_country():
    return load_query("""
        SELECT
            country,
            n_customers,
            total_revenue,
            avg_order_value,
            avg_recency_days,
            pct_high_value,
            run_date
        FROM gold.kpi_country
        ORDER BY total_revenue DESC
    """)


def get_kpi_monthly():
    return load_query("""
        SELECT
            year_month,
            n_orders,
            n_customers,
            total_revenue,
            run_date
        FROM gold.kpi_monthly
        ORDER BY year_month
    """)


def get_customer_anomalies():
    return load_query("""
        SELECT
            customer_id,
            anomaly_type,
            metric_value,
            threshold_value,
            detected_at
        FROM gold.customer_anomalies
        ORDER BY detected_at DESC
    """)


def get_model_coefficients():
    return load_query("""
        SELECT
            model_name,
            term,
            estimate,
            std_error,
            statistic,
            p_value,
            run_date
        FROM gold.model_coefficients
        ORDER BY run_date DESC, model_name, term
    """)


def get_model_metrics():
    return load_query("""
        SELECT
            model_name,
            metric_name,
            metric_value,
            run_date
        FROM gold.model_metrics
        ORDER BY run_date DESC, model_name, metric_name
    """)
