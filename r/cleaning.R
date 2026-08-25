# ============================================================
# MARKETPLACE - BRONZE -> SILVER
# Cleaning and transformation
# ============================================================

library(DBI)
library(RPostgres)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(aws.s3)

# ------------------------------------------------------------
# 1. Parameters
# ------------------------------------------------------------

target_date <- ifelse(
  length(commandArgs(trailingOnly = TRUE)) > 0,
  commandArgs(trailingOnly = TRUE)[1],
  Sys.Date()
)

cat("Cleaning data for:", target_date, "\n")

# ------------------------------------------------------------
# 2. Environment variables
# ------------------------------------------------------------

db_host <- Sys.getenv("DB_HOST", "postgres")
db_port <- as.integer(Sys.getenv("DB_PORT", "5432"))
db_name <- Sys.getenv("DB_NAME", "marketplace")
db_user <- Sys.getenv("DB_USER", "app")
db_password <- Sys.getenv("DB_PASSWORD", "app12345")

minio_endpoint <- Sys.getenv(
  "MINIO_ENDPOINT",
  "http://minio:9000"
)

minio_access_key <- Sys.getenv(
  "MINIO_ACCESS_KEY",
  "minio"
)

minio_secret_key <- Sys.getenv(
  "MINIO_SECRET_KEY",
  "minio12345"
)

minio_bucket <- Sys.getenv(
  "MINIO_BUCKET",
  "bronze"
)

# ------------------------------------------------------------
# 3. PostgreSQL connection
# ------------------------------------------------------------

con <- dbConnect(
  RPostgres::Postgres(),
  host = db_host,
  port = db_port,
  dbname = db_name,
  user = db_user,
  password = db_password
)

cat("Connected to PostgreSQL\n")

# ------------------------------------------------------------
# 4. Configure MinIO
# ------------------------------------------------------------

Sys.setenv(
  AWS_ACCESS_KEY_ID = minio_access_key,
  AWS_SECRET_ACCESS_KEY = minio_secret_key
)

# MinIO is S3 compatible
Sys.setenv(
  AWS_S3_ENDPOINT = minio_endpoint
)

# ------------------------------------------------------------
# 5. Locate Bronze file
# ------------------------------------------------------------

object_key <- paste0(
  "orders/dt=",
  target_date,
  "/orders.json"
)

cat("Reading Bronze object:", object_key, "\n")

# ------------------------------------------------------------
# 6. Download JSON from MinIO
# ------------------------------------------------------------

temp_file <- tempfile(
  pattern = "orders_",
  fileext = ".json"
)

tryCatch({

  save_object(
    object = object_key,
    bucket = minio_bucket,
    file = temp_file,
    base_url = sub(
      "https?://",
      "",
      minio_endpoint
    )
  )

}, error = function(e) {

  stop(
    paste(
      "Unable to download Bronze data from MinIO:",
      e$message
    )
  )
})

# ------------------------------------------------------------
# 7. Read JSON
# ------------------------------------------------------------

raw_data <- fromJSON(
  temp_file,
  flatten = TRUE
)

orders <- as.data.frame(raw_data)

cat(
  "Rows received:",
  nrow(orders),
  "\n"
)

# ------------------------------------------------------------
# 8. Cleaning
# ------------------------------------------------------------

orders_clean <- orders %>%

  # Correct data types
  mutate(
    order_id = as.character(order_id),
    seller_id = as.character(seller_id),
    customer_id = as.character(customer_id),
    product_id = as.character(product_id),

    dt = as.Date(dt),

    quantity = as.integer(quantity),

    total_amount = as.numeric(total_amount),

    status = as.character(status)
  ) %>%

  # Remove invalid records
  filter(
    !is.na(order_id),
    !is.na(seller_id),
    !is.na(customer_id),
    !is.na(product_id),
    !is.na(dt),
    !is.na(quantity),
    !is.na(total_amount)
  ) %>%

  # Business rules
  filter(
    quantity > 0,
    total_amount >= 0
  ) %>%

  # Prevent duplicate orders
  distinct(
    order_id,
    .keep_all = TRUE
  )

cat(
  "Rows after cleaning:",
  nrow(orders_clean),
  "\n"
)

# ------------------------------------------------------------
# 9. Data quality checks
# ------------------------------------------------------------

if (nrow(orders_clean) == 0) {
  stop("No valid orders remain after cleaning.")
}

future_dates <- orders_clean %>%
  filter(dt > Sys.Date())

if (nrow(future_dates) > 0) {
  stop("Data contains future dates.")
}

missing_ids <- orders_clean %>%
  filter(
    is.na(order_id) |
    is.na(seller_id) |
    is.na(product_id)
  )

if (nrow(missing_ids) > 0) {
  stop("Missing mandatory identifiers.")
}

# ------------------------------------------------------------
# 10. Create Silver schema/table if necessary
# ------------------------------------------------------------

dbExecute(
  con,
  "
  CREATE SCHEMA IF NOT EXISTS silver;
  "
)

dbExecute(
  con,
  "
  CREATE TABLE IF NOT EXISTS silver.orders (
      order_id TEXT PRIMARY KEY,
      seller_id TEXT NOT NULL,
      customer_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      dt DATE NOT NULL,
      quantity INTEGER NOT NULL,
      total_amount NUMERIC NOT NULL,
      status TEXT
  );
  "
)

# ------------------------------------------------------------
# 11. Idempotent Silver load
# ------------------------------------------------------------

dbExecute(
  con,
  "DELETE FROM silver.orders WHERE dt = $1",
  params = list(target_date)
)

dbWriteTable(
  con,
  Id(
    schema = "silver",
    table = "orders"
  ),
  orders_clean,
  append = TRUE,
  row.names = FALSE
)

cat(
  "Silver load completed:",
  nrow(orders_clean),
  "rows\n"
)

# ------------------------------------------------------------
# 12. Close connection
# ------------------------------------------------------------

dbDisconnect(con)

unlink(temp_file)

cat("Cleaning completed successfully.\n")