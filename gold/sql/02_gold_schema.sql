-- Schema Gold (proprietaire : Abraham).
-- Contient les agregations/KPIs, les anomalies detectees, et les resultats
-- des modeles statistiques (regression lineaire et logistique).
-- Toutes les tables sont rechargees de facon idempotente (TRUNCATE + INSERT
-- ou DELETE sur run_date + INSERT) par les scripts R correspondants.

CREATE SCHEMA IF NOT EXISTS gold;

-- KPIs agreges par pays
CREATE TABLE IF NOT EXISTS gold.kpi_country (
    country            TEXT PRIMARY KEY,
    n_customers        INTEGER NOT NULL,
    total_revenue      NUMERIC(16, 2) NOT NULL,
    avg_order_value    NUMERIC(14, 2) NOT NULL,
    avg_recency_days   NUMERIC(10, 2) NOT NULL,
    pct_high_value     NUMERIC(5, 2) NOT NULL,
    run_date           DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Evolution du chiffre d'affaires par mois (issu de silver.transactions)
CREATE TABLE IF NOT EXISTS gold.kpi_monthly (
    year_month     TEXT PRIMARY KEY,   -- format 'YYYY-MM'
    n_orders       INTEGER NOT NULL,
    n_customers    INTEGER NOT NULL,
    total_revenue  NUMERIC(16, 2) NOT NULL,
    run_date       DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Clients detectes comme anomalies statistiques (outliers de depense,
-- panier moyen aberrant, quantites negatives residuelles, etc.)
CREATE TABLE IF NOT EXISTS gold.customer_anomalies (
    customer_id     TEXT NOT NULL,
    anomaly_type    TEXT NOT NULL,     -- ex: 'total_spend_outlier', 'avg_order_value_outlier'
    metric_value    NUMERIC(16, 2) NOT NULL,
    threshold_value NUMERIC(16, 2) NOT NULL,
    detected_at     TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (customer_id, anomaly_type)
);

-- Coefficients des modeles (lineaire et logistique), format long
CREATE TABLE IF NOT EXISTS gold.model_coefficients (
    model_name  TEXT NOT NULL,   -- ex: 'linear_total_spend', 'logistic_high_value'
    term        TEXT NOT NULL,
    estimate    NUMERIC(16, 6),
    std_error   NUMERIC(16, 6),
    statistic   NUMERIC(16, 6),
    p_value     NUMERIC(16, 6),
    run_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (model_name, term, run_date)
);

-- Metriques d'evaluation des modeles, format long (R2, RMSE, AUC, Accuracy...)
CREATE TABLE IF NOT EXISTS gold.model_metrics (
    model_name    TEXT NOT NULL,
    metric_name   TEXT NOT NULL,
    metric_value  NUMERIC(16, 6),
    run_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (model_name, metric_name, run_date)
);
