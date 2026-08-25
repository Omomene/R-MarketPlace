-- ==========================================
-- GOLD — BUSINESS ANALYTICS
-- ==========================================


-- ==========================================
-- REVENUE ANALYSIS
-- ==========================================

CREATE TABLE IF NOT EXISTS gold.revenue_analysis (
    order_date DATE PRIMARY KEY,
    total_orders INTEGER,
    total_revenue NUMERIC(12,2),
    average_order_value NUMERIC(12,2),
    total_commission NUMERIC(12,2)
);


-- ==========================================
-- SELLER ANALYSIS
-- ==========================================

CREATE TABLE IF NOT EXISTS gold.seller_analysis (
    seller_id TEXT,
    seller_name TEXT,
    order_date DATE,
    total_orders INTEGER,
    revenue NUMERIC(12,2),
    average_order_value NUMERIC(12,2),
    rank INTEGER,
    PRIMARY KEY (seller_id, order_date)
);


-- ==========================================
-- CATEGORY ANALYSIS
-- ==========================================

CREATE TABLE IF NOT EXISTS gold.category_analysis (
    category TEXT,
    order_date DATE,
    total_orders INTEGER,
    revenue NUMERIC(12,2),
    average_order_value NUMERIC(12,2),
    PRIMARY KEY (category, order_date)
);


-- ==========================================
-- ANOMALY RESULTS
-- ==========================================

CREATE TABLE IF NOT EXISTS gold.anomaly_results (
    anomaly_id SERIAL PRIMARY KEY,
    order_date DATE,
    metric TEXT,
    value NUMERIC(12,2),
    expected_value NUMERIC(12,2),
    threshold NUMERIC(12,2),
    anomaly_type TEXT,
    is_anomaly BOOLEAN
);