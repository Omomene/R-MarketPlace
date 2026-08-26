# ============================================================
# MARKETPLACE - SILVER -> GOLD
# Statistical analysis and business analytics
# ============================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(tidyr)
library(slider)

# ------------------------------------------------------------
# 1. Parameters
# ------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

target_date <- ifelse(
  length(args) > 0,
  args[1],
  as.character(Sys.Date())
)

cat("====================================\n")
cat("MARKETPLACE R ANALYSIS\n")
cat("Analysis for:", target_date, "\n")
cat("====================================\n")


# ------------------------------------------------------------
# 2. PostgreSQL connection
# ------------------------------------------------------------

con <- dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("DB_HOST", "postgres"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  dbname = Sys.getenv("DB_NAME", "marketplace"),
  user = Sys.getenv("DB_USER", "app"),
  password = Sys.getenv("DB_PASSWORD", "app12345")
)

cat("Connected to PostgreSQL\n")


# ------------------------------------------------------------
# 3. Read Silver orders
# ------------------------------------------------------------

orders <- dbGetQuery(
  con,
  "
  SELECT
      order_id,
      seller_id,
      customer_id,
      product_id,
      order_date,
      quantity,
      total_amount,
      status
  FROM silver.orders
  "
)

orders$order_date <- as.Date(orders$order_date)

cat("Silver rows:", nrow(orders), "\n")

if (nrow(orders) == 0) {
  stop("Silver table is empty.")
}


# ------------------------------------------------------------
# 4. Read Silver sellers
# ------------------------------------------------------------

sellers <- dbGetQuery(
  con,
  "
  SELECT
      seller_id,
      name AS seller_name
  FROM silver.sellers
  "
)


# ------------------------------------------------------------
# 5. Read Silver products
# ------------------------------------------------------------

products <- dbGetQuery(
  con,
  "
  SELECT
      product_id,
      name,
      category,
      base_price
  FROM silver.products
  "
)


# ============================================================
# 6. REVENUE ANALYSIS
# ============================================================

revenue_analysis <- orders %>%

  filter(
    order_date == as.Date(target_date)
  ) %>%

  summarise(

    order_date = as.Date(target_date),

    total_orders =
      n_distinct(order_id),

    total_revenue =
      sum(
        total_amount[status == "completed"],
        na.rm = TRUE
      ),

    average_order_value =
      mean(
        total_amount[status == "completed"],
        na.rm = TRUE
      ),

    # Marketplace commission = 10%
    total_commission =
      sum(
        total_amount[status == "completed"],
        na.rm = TRUE
      ) * 0.10
  )

cat("\n")
cat("====================================\n")
cat("REVENUE ANALYSIS\n")
cat("====================================\n")

print(revenue_analysis)


# ============================================================
# 7. SELLER ANALYSIS
# ============================================================

seller_analysis <- orders %>%

  filter(
    order_date == as.Date(target_date),
    status == "completed"
  ) %>%

  group_by(
    seller_id,
    order_date
  ) %>%

  summarise(

    total_orders =
      n_distinct(order_id),

    revenue =
      sum(
        total_amount,
        na.rm = TRUE
      ),

    average_order_value =
      mean(
        total_amount,
        na.rm = TRUE
      ),

    .groups = "drop"
  ) %>%

  left_join(
    sellers,
    by = "seller_id"
  ) %>%

  arrange(
    desc(revenue)
  ) %>%

  mutate(
    rank = row_number()
  ) %>%

  select(
    seller_id,
    seller_name,
    order_date,
    total_orders,
    revenue,
    average_order_value,
    rank
  )

cat("\n")
cat("====================================\n")
cat("SELLER ANALYSIS\n")
cat("====================================\n")

print(seller_analysis)


# ============================================================
# 8. CATEGORY ANALYSIS
# ============================================================

category_analysis <- orders %>%

  filter(
    order_date == as.Date(target_date),
    status == "completed"
  ) %>%

  left_join(
    products,
    by = "product_id"
  ) %>%

  group_by(
    category,
    order_date
  ) %>%

  summarise(

    total_orders =
      n_distinct(order_id),

    revenue =
      sum(
        total_amount,
        na.rm = TRUE
      ),

    average_order_value =
      mean(
        total_amount,
        na.rm = TRUE
      ),

    .groups = "drop"
  )

cat("\n")
cat("====================================\n")
cat("CATEGORY ANALYSIS\n")
cat("====================================\n")

print(category_analysis)

# ============================================================
# 9. ANOMALY DETECTION
# ============================================================

# Calculate daily seller revenue over all available dates
seller_daily <- orders %>%

  filter(
    status == "completed"
  ) %>%

  group_by(
    seller_id,
    order_date
  ) %>%

  summarise(
    revenue = sum(
      total_amount,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%

  arrange(
    seller_id,
    order_date
  )


# ------------------------------------------------------------
# Calculate historical baseline
# ------------------------------------------------------------

seller_anomalies <- seller_daily %>%

  group_by(
    seller_id
  ) %>%

  mutate(

    # Average revenue from the PREVIOUS 7 days
    # Current day is excluded from the baseline
    expected_value =
      slide_dbl(
        lag(revenue),
        mean,
        .before = 6,
        .complete = FALSE,
        na.rm = TRUE
      ),

    # Anomaly threshold = 70% of expected revenue
    threshold =
      expected_value * 0.70,

    # Revenue drop greater than 30%
    is_anomaly =
      !is.na(expected_value) &
      revenue < threshold

  ) %>%

  ungroup()


# ------------------------------------------------------------
# Keep results for target date
# ------------------------------------------------------------

anomaly_results <- seller_anomalies %>%

  filter(
    order_date == as.Date(target_date)
  ) %>%

  mutate(

    metric =
      "seller_daily_revenue",

    anomaly_type =
      ifelse(
        is_anomaly,
        "Revenue drop",
        "Normal"
      )
  ) %>%

  select(
    order_date,
    metric,
    value = revenue,
    expected_value,
    threshold,
    anomaly_type,
    is_anomaly
  )


# ------------------------------------------------------------
# Display anomaly results
# ------------------------------------------------------------

cat("\n")
cat("====================================\n")
cat("ANOMALY ANALYSIS\n")
cat("====================================\n")

cat(
  "Anomalies detected:",
  sum(
    anomaly_results$is_anomaly,
    na.rm = TRUE
  ),
  "\n"
)

print(anomaly_results)


# ============================================================
# 10. REGRESSION
# ============================================================

regression_model <- lm(
  total_amount ~ quantity,
  data = orders %>%
    filter(status == "completed")
)

regression_summary <- summary(
  regression_model
)

cat("\n")
cat("====================================\n")
cat("REGRESSION RESULTS\n")
cat("====================================\n")

print(regression_summary)


# Prepare regression results

coefficients <- coef(
  regression_summary
)

regression_results <- data.frame(

  variable =
    rownames(coefficients),

  coefficient =
    coefficients[, 1],

  p_value =
    coefficients[, 4],

  r_squared =
    regression_summary$r.squared,

  analysis_date =
    as.Date(target_date)
)


# ============================================================
# 11. T-TEST
# ============================================================

orders_test <- orders %>%

  filter(
    status == "completed"
  ) %>%

  mutate(

    quantity_group =
      ifelse(
        quantity <= median(
          quantity,
          na.rm = TRUE
        ),
        "Low quantity",
        "High quantity"
      )
  )


t_test <- t.test(
  total_amount ~ quantity_group,
  data = orders_test
)

cat("\n")
cat("====================================\n")
cat("T-TEST RESULTS\n")
cat("====================================\n")

print(t_test)


# ============================================================
# 12. CREATE GOLD SCHEMA
# ============================================================

dbExecute(
  con,
  "CREATE SCHEMA IF NOT EXISTS gold"
)


# ============================================================
# 13. CREATE GOLD TABLES
# ============================================================

dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.revenue_analysis (
      order_date DATE PRIMARY KEY,
      total_orders INTEGER,
      total_revenue NUMERIC(12,2),
      average_order_value NUMERIC(12,2),
      total_commission NUMERIC(12,2)
  )
  "
)


dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.seller_analysis (
      seller_id TEXT,
      seller_name TEXT,
      order_date DATE,
      total_orders INTEGER,
      revenue NUMERIC(12,2),
      average_order_value NUMERIC(12,2),
      rank INTEGER,
      PRIMARY KEY (seller_id, order_date)
  )
  "
)


dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.category_analysis (
      category TEXT,
      order_date DATE,
      total_orders INTEGER,
      revenue NUMERIC(12,2),
      average_order_value NUMERIC(12,2),
      PRIMARY KEY (category, order_date)
  )
  "
)


dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.anomaly_results (
      anomaly_id SERIAL PRIMARY KEY,
      order_date DATE,
      metric TEXT,
      value NUMERIC(12,2),
      expected_value NUMERIC(12,2),
      threshold NUMERIC(12,2),
      anomaly_type TEXT,
      is_anomaly BOOLEAN
  )
  "
)


dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.regression_results (
      variable TEXT,
      coefficient NUMERIC,
      p_value NUMERIC,
      r_squared NUMERIC,
      analysis_date DATE
  )
  "
)


# ============================================================
# 14. WRITE REVENUE ANALYSIS
# ============================================================

dbExecute(
  con,
  "DELETE FROM gold.revenue_analysis
   WHERE order_date = $1",
  params = list(target_date)
)

dbWriteTable(
  con,
  Id(
    schema = "gold",
    table = "revenue_analysis"
  ),
  revenue_analysis,
  append = TRUE,
  row.names = FALSE
)


# ============================================================
# 15. WRITE SELLER ANALYSIS
# ============================================================

dbExecute(
  con,
  "DELETE FROM gold.seller_analysis
   WHERE order_date = $1",
  params = list(target_date)
)

if (nrow(seller_analysis) > 0) {

  dbWriteTable(
    con,
    Id(
      schema = "gold",
      table = "seller_analysis"
    ),
    seller_analysis,
    append = TRUE,
    row.names = FALSE
  )
}


# ============================================================
# 16. WRITE CATEGORY ANALYSIS
# ============================================================

dbExecute(
  con,
  "DELETE FROM gold.category_analysis
   WHERE order_date = $1",
  params = list(target_date)
)

if (nrow(category_analysis) > 0) {

  dbWriteTable(
    con,
    Id(
      schema = "gold",
      table = "category_analysis"
    ),
    category_analysis,
    append = TRUE,
    row.names = FALSE
  )
}


# ============================================================
# 17. WRITE ANOMALIES
# ============================================================

dbExecute(
  con,
  "DELETE FROM gold.anomaly_results
   WHERE order_date = $1",
  params = list(target_date)
)

if (nrow(anomaly_results) > 0) {

  dbWriteTable(
    con,
    Id(
      schema = "gold",
      table = "anomaly_results"
    ),
    anomaly_results,
    append = TRUE,
    row.names = FALSE
  )
}


# ============================================================
# 18. WRITE REGRESSION RESULTS
# ============================================================

dbExecute(
  con,
  "DELETE FROM gold.regression_results
   WHERE analysis_date = $1",
  params = list(target_date)
)

dbWriteTable(
  con,
  Id(
    schema = "gold",
    table = "regression_results"
  ),
  regression_results,
  append = TRUE,
  row.names = FALSE
)


# ============================================================
# 19. FINISH
# ============================================================

dbDisconnect(con)

cat("\n")
cat("====================================\n")
cat("R ANALYSIS COMPLETED SUCCESSFULLY\n")
cat("====================================\n")