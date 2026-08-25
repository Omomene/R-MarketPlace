# ============================================================
# MARKETPLACE - SILVER -> GOLD
# Statistical analysis and aggregation
# ============================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(tidyr)

# ------------------------------------------------------------
# 1. Parameters
# ------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

target_date <- ifelse(
  length(args) > 0,
  args[1],
  as.character(Sys.Date())
)

cat("Analysis for:", target_date, "\n")

# ------------------------------------------------------------
# 2. PostgreSQL connection
# ------------------------------------------------------------

con <- dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("DB_HOST", "postgres"),
  port = as.integer(
    Sys.getenv("DB_PORT", "5432")
  ),
  dbname = Sys.getenv(
    "DB_NAME",
    "marketplace"
  ),
  user = Sys.getenv(
    "DB_USER",
    "app"
  ),
  password = Sys.getenv(
    "DB_PASSWORD",
    "app12345"
  )
)

cat("Connected to PostgreSQL\n")

# ------------------------------------------------------------
# 3. Read Silver data
# ------------------------------------------------------------

orders <- dbGetQuery(
  con,
  "
  SELECT
      order_id,
      seller_id,
      customer_id,
      product_id,
      dt,
      quantity,
      total_amount,
      status
  FROM silver.orders
  "
)

orders$dt <- as.Date(orders$dt)

cat(
  "Silver rows:",
  nrow(orders),
  "\n"
)

if (nrow(orders) == 0) {
  stop("Silver table is empty.")
}

# ------------------------------------------------------------
# 4. Daily revenue
# ------------------------------------------------------------

daily_revenue <- orders %>%
  group_by(dt) %>%
  summarise(
    total_orders = n_distinct(order_id),
    revenue = sum(total_amount, na.rm = TRUE),
    average_order_value =
      mean(total_amount, na.rm = TRUE),
    total_quantity =
      sum(quantity, na.rm = TRUE),
    .groups = "drop"
  )

# ------------------------------------------------------------
# 5. Seller analysis
# ------------------------------------------------------------

seller_analysis <- orders %>%

  group_by(
    seller_id,
    dt
  ) %>%

  summarise(
    orders = n_distinct(order_id),
    revenue = sum(
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

  arrange(
    seller_id,
    dt
  ) %>%

  group_by(seller_id) %>%

  mutate(

    # Rolling 7-day average
    avg_7d = slider::slide_dbl(
      revenue,
      mean,
      .before = 6,
      .complete = FALSE,
      na.rm = TRUE
    ),

    # Detect significant drop
    drop_flag =
      revenue < (0.70 * avg_7d)

  ) %>%

  ungroup()

# ------------------------------------------------------------
# 6. Category analysis
# ------------------------------------------------------------

# Product information is stored in Silver products
# if available.

products <- tryCatch(

  dbGetQuery(
    con,
    "
    SELECT
        product_id,
        name,
        category,
        base_price
    FROM silver.products
    "
  ),

  error = function(e) {

    cat(
      "silver.products not found. ",
      "Category analysis skipped.\n"
    )

    NULL
  }
)

category_analysis <- NULL

if (!is.null(products)) {

  category_analysis <- orders %>%

    left_join(
      products,
      by = "product_id"
    ) %>%

    group_by(
      dt,
      category
    ) %>%

    summarise(
      orders = n_distinct(order_id),
      revenue =
        sum(
          total_amount,
          na.rm = TRUE
        ),
      quantity =
        sum(
          quantity,
          na.rm = TRUE
        ),
      .groups = "drop"
    )
}

# ------------------------------------------------------------
# 7. Anomaly detection
# ------------------------------------------------------------

anomalies <- seller_analysis %>%

  filter(
    drop_flag == TRUE
  ) %>%

  transmute(

    seller_id,

    dt,

    metric =
      "seller_daily_revenue",

    value =
      revenue,

    threshold =
      avg_7d * 0.70
  )

cat(
  "Anomalies detected:",
  nrow(anomalies),
  "\n"
)

# ------------------------------------------------------------
# 8. Regression analysis
# ------------------------------------------------------------

# Does quantity have an influence on revenue?

regression_model <- lm(
  total_amount ~ quantity,
  data = orders
)

regression_summary <-
  summary(regression_model)

cat("\n")
cat("====================================\n")
cat("REGRESSION RESULTS\n")
cat("====================================\n")

print(regression_summary)

# ------------------------------------------------------------
# 9. Statistical test
# ------------------------------------------------------------

# Compare revenue between low and high quantity orders

orders_test <- orders %>%

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

# ------------------------------------------------------------
# 10. Create Gold schema
# ------------------------------------------------------------

dbExecute(
  con,
  "
  CREATE SCHEMA IF NOT EXISTS gold;
  "
)

# ------------------------------------------------------------
# 11. Gold tables
# ------------------------------------------------------------

dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.daily_revenue (
      dt DATE PRIMARY KEY,
      total_orders INTEGER,
      revenue NUMERIC,
      average_order_value NUMERIC,
      total_quantity INTEGER
  );
  "
)

dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.seller_analysis (
      seller_id TEXT,
      dt DATE,
      orders INTEGER,
      revenue NUMERIC,
      average_order_value NUMERIC,
      avg_7d NUMERIC,
      drop_flag BOOLEAN,
      PRIMARY KEY (seller_id, dt)
  );
  "
)

dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.anomalies (
      seller_id TEXT,
      dt DATE,
      metric TEXT,
      value NUMERIC,
      threshold NUMERIC
  );
  "
)

# ------------------------------------------------------------
# 12. Write daily revenue
# ------------------------------------------------------------

dbExecute(
  con,
  "DELETE FROM gold.daily_revenue WHERE dt = $1",
  params = list(target_date)
)

daily_target <- daily_revenue %>%
  filter(
    dt == as.Date(target_date)
  )

if (nrow(daily_target) > 0) {

  dbWriteTable(
    con,
    Id(
      schema = "gold",
      table = "daily_revenue"
    ),
    daily_target,
    append = TRUE,
    row.names = FALSE
  )
}

# ------------------------------------------------------------
# 13. Write seller analysis
# ------------------------------------------------------------

dbExecute(
  con,
  "DELETE FROM gold.seller_analysis WHERE dt = $1",
  params = list(target_date)
)

seller_target <- seller_analysis %>%
  filter(
    dt == as.Date(target_date)
  )

if (nrow(seller_target) > 0) {

  dbWriteTable(
    con,
    Id(
      schema = "gold",
      table = "seller_analysis"
    ),
    seller_target,
    append = TRUE,
    row.names = FALSE
  )
}

# ------------------------------------------------------------
# 14. Write anomalies
# ------------------------------------------------------------

dbExecute(
  con,
  "DELETE FROM gold.anomalies WHERE dt = $1",
  params = list(target_date)
)

anomaly_target <- anomalies %>%
  filter(
    dt == as.Date(target_date)
  )

if (nrow(anomaly_target) > 0) {

  dbWriteTable(
    con,
    Id(
      schema = "gold",
      table = "anomalies"
    ),
    anomaly_target,
    append = TRUE,
    row.names = FALSE
  )
}

# ------------------------------------------------------------
# 15. Save regression results
# ------------------------------------------------------------

dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS gold.regression_results (
      variable TEXT,
      coefficient NUMERIC,
      p_value NUMERIC,
      r_squared NUMERIC,
      analysis_date DATE
  );
  "
)

coefficients <- coef(
  regression_summary
)

p_values <- coef(
  regression_summary
)[, 4]

regression_results <- data.frame(

  variable =
    rownames(
      coef(regression_summary)
    ),

  coefficient =
    coefficients[, 1],

  p_value =
    p_values,

  r_squared =
    regression_summary$r.squared,

  analysis_date =
    as.Date(target_date)
)

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

# ------------------------------------------------------------
# 16. Finish
# ------------------------------------------------------------

dbDisconnect(con)

cat("\n")
cat("====================================\n")
cat("R ANALYSIS COMPLETED SUCCESSFULLY\n")
cat("====================================\n")