source("R/utils/db.R")
source("R/00_load_silver.R")
source("R/01_kpis.R")
source("R/02_anomaly_detection.R")
source("R/03_eda.R")
source("R/04_regression_linear.R")
source("R/05_regression_logistic.R")

main <- function() {
  con <- gold_db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  message("Chargement des donnees Silver...")
  customers <- load_silver_customers(con)
  transactions <- load_silver_transactions(con)

  message("Construction des KPIs...")
  gold_write_table(con, "gold", "kpi_country", build_kpi_country(customers))
  gold_write_table(con, "gold", "kpi_monthly", build_kpi_monthly(transactions))

  message("Detection des anomalies...")
  gold_write_table(con, "gold", "customer_anomalies", build_customer_anomalies(customers), run_date_col = NULL)

  message("Exploration des donnees (EDA)...")
  run_eda(customers)

  message("Regression lineaire (TotalSpend)...")
  linear_result <- run_linear_regression(customers)
  gold_write_table(con, "gold", "model_coefficients", linear_result$coefficients)
  gold_write_table(con, "gold", "model_metrics", linear_result$metrics)

  message("Regression logistique (HighValueCustomer)...")
  logistic_result <- run_logistic_regression(customers)
  gold_write_table(con, "gold", "model_coefficients", logistic_result$coefficients)
  gold_write_table(con, "gold", "model_metrics", logistic_result$metrics)

  message("Pipeline Gold termine avec succes.")
}

if (sys.nframe() == 0) {
  main()
}
