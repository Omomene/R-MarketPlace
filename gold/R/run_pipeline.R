library(dplyr)

source("R/utils/db.R")
source("R/00_load_silver.R")
source("R/01_kpis.R")
source("R/02_anomaly_detection.R")
source("R/03_eda.R")
source("R/04_regression_linear.R")
source("R/05_regression_logistic.R")


main <- function() {

  con <- gold_db_connect()

  on.exit(
    DBI::dbDisconnect(con),
    add = TRUE
  )


  # ==========================================================
  # SILVER
  # ==========================================================

  message("Chargement des donnees Silver...")

  customers <- load_silver_customers(con)

  transactions <- load_silver_transactions(con)


  # ==========================================================
  # KPI
  # ==========================================================

  message("Construction des KPIs...")

  seller_country_kpi <- transactions %>%
  left_join(
    DBI::dbGetQuery(
      con,
      "SELECT seller_id, country FROM silver.sellers"
    ),
    by = "seller_id"
  ) %>%
  filter(!is.na(country)) %>%
  group_by(country) %>%
  summarise(
    n_customers = n_distinct(customer_id),
    total_revenue = sum(transaction_amount, na.rm = TRUE),
    avg_order_value = mean(transaction_amount, na.rm = TRUE),
    avg_recency_days = 0,
    pct_high_value = 0,
    .groups = "drop"
  ) %>%
  mutate(run_date = Sys.Date())

gold_write_table(
  con,
  "gold",
  "kpi_country",
  seller_country_kpi
)

  gold_write_table(
    con,
    "gold",
    "kpi_monthly",
    build_kpi_monthly(transactions)
  )


  # ==========================================================
  # ANOMALIES
  # ==========================================================

  message("Detection des anomalies...")

  gold_write_table(
    con,
    "gold",
    "customer_anomalies",
    build_customer_anomalies(customers),
    run_date_col = NULL
  )


  # ==========================================================
  # EDA
  # ==========================================================

  message("Exploration des donnees (EDA)...")

  run_eda(customers)


  # ==========================================================
  # REGRESSION LINEAIRE
  # ==========================================================

  message("Regression lineaire (TotalSpend)...")

  linear_result <- run_linear_regression(
    customers
  )


  # ==========================================================
  # REGRESSION LOGISTIQUE
  # ==========================================================

  message(
    "Regression logistique (HighValueCustomer)..."
  )

  logistic_result <- run_logistic_regression(
    customers
  )


  # ==========================================================
  # REGROUPEMENT DES RESULTATS
  # ==========================================================

  all_coefficients <- bind_rows(
    linear_result$coefficients,
    logistic_result$coefficients
  )

  all_metrics <- bind_rows(
    linear_result$metrics,
    logistic_result$metrics
  )


  # ==========================================================
  # ECRITURE GOLD
  # Une seule écriture pour éviter que le second modèle
  # efface les résultats du premier.
  # ==========================================================

  message(
    "Ecriture des resultats des modeles dans Gold..."
  )

  gold_write_table(
    con,
    "gold",
    "model_coefficients",
    all_coefficients
  )

  gold_write_table(
    con,
    "gold",
    "model_metrics",
    all_metrics
  )


  # ==========================================================
  # FIN
  # ==========================================================

  message(
    "Pipeline Gold termine avec succes."
  )
}


if (sys.nframe() == 0) {

  main()

}