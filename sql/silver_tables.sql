-- ==========================================
-- SILVER — CLEANED MARKETPLACE DATA
-- ==========================================

CREATE TABLE IF NOT EXISTS silver.orders (
    order_id TEXT PRIMARY KEY,
    seller_id TEXT NOT NULL,
    customer_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    order_date DATE NOT NULL,
    quantity INTEGER NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS silver.sellers (
    seller_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    country TEXT,
    joined_date DATE
);

CREATE TABLE IF NOT EXISTS silver.customers (
    customer_id TEXT PRIMARY KEY,
    email TEXT,
    city TEXT,
    signup_date DATE
);

CREATE TABLE IF NOT EXISTS silver.products (
    product_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    base_price NUMERIC(12,2)
);