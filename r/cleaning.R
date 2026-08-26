# ============================================================
# MARKETPLACE - BRONZE -> SILVER
# Personne 3 : nettoyage, transformation, validation
#
# Lit l'objet UNIQUE déposé par le DAG (upload_to_minio) :
#   marketplace/dt=<date>/data.json
# contenant {date, orders, sellers, products, customers}
# ============================================================

library(DBI)
library(RPostgres)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(aws.s3)

# ------------------------------------------------------------
# 1. Paramètres
# ------------------------------------------------------------

target_date <- ifelse(
  length(commandArgs(trailingOnly = TRUE)) > 0,
  commandArgs(trailingOnly = TRUE)[1],
  as.character(Sys.Date())
)

cat("Cleaning data for:", target_date, "\n")

# ------------------------------------------------------------
# 2. Variables d'environnement
# ------------------------------------------------------------

db_host     <- Sys.getenv("DB_HOST", Sys.getenv("POSTGRES_HOST", "postgres"))
db_port     <- as.integer(Sys.getenv("DB_PORT", Sys.getenv("POSTGRES_PORT", "5432")))
db_name     <- Sys.getenv("DB_NAME", Sys.getenv("POSTGRES_DB", "marketplace"))
db_user     <- Sys.getenv("DB_USER", Sys.getenv("POSTGRES_USER", "app"))
db_password <- Sys.getenv("DB_PASSWORD", Sys.getenv("POSTGRES_PASSWORD", "app12345"))

minio_endpoint   <- Sys.getenv("MINIO_ENDPOINT", "http://minio:9000")
minio_access_key <- Sys.getenv("MINIO_ACCESS_KEY", "minio")
minio_secret_key <- Sys.getenv("MINIO_SECRET_KEY", "minio12345")
minio_bucket     <- Sys.getenv("MINIO_BUCKET", "bronze")

Sys.setenv(
  AWS_ACCESS_KEY_ID = minio_access_key,
  AWS_SECRET_ACCESS_KEY = minio_secret_key,
  AWS_S3_ENDPOINT = minio_endpoint
)

# ------------------------------------------------------------
# 3. Connexion PostgreSQL
# ------------------------------------------------------------

con <- dbConnect(
  RPostgres::Postgres(),
  host = db_host, port = db_port, dbname = db_name,
  user = db_user, password = db_password
)

cat("Connected to PostgreSQL (", db_host, ":", db_port, "/", db_name, ")\n", sep = "")

# ------------------------------------------------------------
# 4. Lecture de l'objet Bronze unique
# ------------------------------------------------------------

object_key <- paste0("marketplace/dt=", target_date, "/data.json")
cat("Reading Bronze object:", object_key, "(bucket:", minio_bucket, ")\n")

temp_file <- tempfile(fileext = ".json")

tryCatch({
  save_object(
    object = object_key,
    bucket = minio_bucket,
    file = temp_file,
    base_url = sub("https?://", "", minio_endpoint),
    region = "",          # évite "us-east-1.<base_url>" (spécifique AWS, pas MinIO)
    use_https = FALSE     # MinIO tourne en HTTP simple dans ce docker-compose
  )
}, error = function(e) {
  stop(paste("Impossible de lire", object_key, "depuis MinIO :", e$message))
})

raw <- fromJSON(temp_file, flatten = TRUE)
unlink(temp_file)

orders_raw    <- as.data.frame(raw$orders)
sellers_raw   <- as.data.frame(raw$sellers)
products_raw  <- as.data.frame(raw$products)
customers_raw <- as.data.frame(raw$customers)

cat("Orders:", nrow(orders_raw),
    "| Sellers:", nrow(sellers_raw),
    "| Products:", nrow(products_raw),
    "| Customers:", nrow(customers_raw), "\n")

# ------------------------------------------------------------
# 5. Nettoyage — orders
# ------------------------------------------------------------

orders_clean <- orders_raw %>%
  mutate(
    order_id     = as.character(order_id),
    seller_id    = as.character(seller_id),
    customer_id  = as.character(customer_id),
    product_id   = as.character(product_id),
    order_date   = as.Date(dt),          # la table silver.orders utilise "order_date", pas "dt"
    quantity     = as.integer(quantity),
    total_amount = as.numeric(total_amount),
    status       = as.character(status)
  ) %>%
  select(order_id, seller_id, customer_id, product_id,
         order_date, quantity, total_amount, status) %>%
  filter(
    !is.na(order_id), !is.na(seller_id), !is.na(customer_id),
    !is.na(product_id), !is.na(order_date), !is.na(quantity), !is.na(total_amount)
  ) %>%
  filter(quantity > 0, total_amount >= 0) %>%
  distinct(order_id, .keep_all = TRUE)

cat("Orders after cleaning:", nrow(orders_clean), "\n")

if (nrow(orders_clean) == 0) stop("No valid orders remain after cleaning.")
if (nrow(filter(orders_clean, order_date > Sys.Date())) > 0) stop("Data contains future dates.")

# ------------------------------------------------------------
# 6. Nettoyage — sellers / products / customers
# ------------------------------------------------------------

sellers_clean <- sellers_raw %>%
  mutate(
    seller_id   = as.character(seller_id),
    name        = trimws(name),
    country     = trimws(country),
    joined_date = as.Date(joined_date)
  ) %>%
  filter(!is.na(seller_id), !is.na(name), name != "") %>%
  distinct(seller_id, .keep_all = TRUE)

products_clean <- products_raw %>%
  mutate(
    product_id = as.character(product_id),
    name       = trimws(name),
    category   = trimws(category),
    base_price = as.numeric(base_price)
  ) %>%
  filter(!is.na(product_id), !is.na(name), name != "") %>%
  filter(is.na(base_price) | base_price >= 0) %>%
  distinct(product_id, .keep_all = TRUE)

customers_clean <- customers_raw %>%
  mutate(
    customer_id = as.character(customer_id),
    email       = trimws(email),
    city        = trimws(city),
    signup_date = as.Date(signup_date)
  ) %>%
  filter(!is.na(customer_id)) %>%
  distinct(customer_id, .keep_all = TRUE)

cat("Sellers:", nrow(sellers_clean),
    "| Products:", nrow(products_clean),
    "| Customers:", nrow(customers_clean), "(après nettoyage)\n")

# ------------------------------------------------------------
# 7. Intégrité référentielle : orders -> dimensions connues
# ------------------------------------------------------------

before_fk <- nrow(orders_clean)

orders_clean <- orders_clean %>%
  filter(
    seller_id %in% sellers_clean$seller_id,
    product_id %in% products_clean$product_id,
    customer_id %in% customers_clean$customer_id
  )

if (nrow(orders_clean) < before_fk) {
  cat("Orders exclus pour FK invalide:", before_fk - nrow(orders_clean), "\n")
}
if (nrow(orders_clean) == 0) stop("Plus aucune commande valide après contrôle FK.")

# ------------------------------------------------------------
# 8. Schéma Silver (déjà créé par silver_tables.sql, sécurité)
# ------------------------------------------------------------

dbExecute(con, "CREATE SCHEMA IF NOT EXISTS silver;")

# ------------------------------------------------------------
# 9. Chargement idempotent
# ------------------------------------------------------------

# orders : partitionné par order_date -> DELETE + INSERT
dbExecute(con, "DELETE FROM silver.orders WHERE order_date = $1", params = list(target_date))
dbWriteTable(con, Id(schema = "silver", table = "orders"),
             orders_clean, append = TRUE, row.names = FALSE)

# sellers / products / customers : dimensions complètes -> TRUNCATE + INSERT
dbExecute(con, "TRUNCATE TABLE silver.sellers CASCADE")
dbWriteTable(con, Id(schema = "silver", table = "sellers"),
             sellers_clean, append = TRUE, row.names = FALSE)

dbExecute(con, "TRUNCATE TABLE silver.products CASCADE")
dbWriteTable(con, Id(schema = "silver", table = "products"),
             products_clean, append = TRUE, row.names = FALSE)

dbExecute(con, "TRUNCATE TABLE silver.customers CASCADE")
dbWriteTable(con, Id(schema = "silver", table = "customers"),
             customers_clean, append = TRUE, row.names = FALSE)

cat("Silver load completed:", nrow(orders_clean), "orders,",
    nrow(sellers_clean), "sellers,",
    nrow(products_clean), "products,",
    nrow(customers_clean), "customers\n")

# ------------------------------------------------------------
# 10. Fin
# ------------------------------------------------------------

dbDisconnect(con)

cat("Cleaning completed successfully.\n")