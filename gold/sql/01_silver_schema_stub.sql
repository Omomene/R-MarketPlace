-- Stub du schema Silver (proprietaire reel : Ameto).
-- Sert uniquement a developper/tester la couche Gold en local, en attendant
-- que le vrai pipeline Bronze -> Silver soit branche sur cette base.
-- Le contrat (noms de colonnes) suit le cahier des charges section 4.

CREATE SCHEMA IF NOT EXISTS silver;

-- Transactions nettoyees, niveau ligne (une ligne = un produit sur une facture)
CREATE TABLE IF NOT EXISTS silver.transactions (
    invoice             TEXT NOT NULL,
    stock_code          TEXT NOT NULL,
    description         TEXT,
    quantity            INTEGER NOT NULL,
    invoice_date        TIMESTAMP NOT NULL,
    price               NUMERIC(12, 2) NOT NULL,
    customer_id         TEXT NOT NULL,
    country             TEXT,
    transaction_amount  NUMERIC(14, 2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_silver_transactions_customer
    ON silver.transactions (customer_id);
CREATE INDEX IF NOT EXISTS idx_silver_transactions_date
    ON silver.transactions (invoice_date);

-- Table agregee au niveau client (cf. section 4 du cahier des charges)
CREATE TABLE IF NOT EXISTS silver.customers (
    customer_id                  TEXT PRIMARY KEY,
    country                      TEXT,
    total_spend                  NUMERIC(14, 2) NOT NULL,
    purchase_frequency           INTEGER NOT NULL,
    total_quantity                INTEGER NOT NULL,
    avg_order_value               NUMERIC(14, 2) NOT NULL,
    unique_products               INTEGER NOT NULL,
    recency                       INTEGER NOT NULL,
    tenure                        INTEGER NOT NULL,
    first_purchase_date           DATE NOT NULL,
    last_purchase_date            DATE NOT NULL,
    avg_quantity_per_order        NUMERIC(10, 2) NOT NULL,
    avg_product_price             NUMERIC(10, 2) NOT NULL,
    purchase_frequency_per_month  NUMERIC(10, 2) NOT NULL,
    high_value_customer           SMALLINT NOT NULL CHECK (high_value_customer IN (0, 1))
);
