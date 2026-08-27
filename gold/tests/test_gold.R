library(testthat)
library(dplyr)

source("R/01_kpis.R")
source("R/02_anomaly_detection.R")
source("R/04_regression_linear.R")
source("R/05_regression_logistic.R")

make_fixture_customers <- function(n = 200) {
  set.seed(1)
  tibble::tibble(
    customer_id                 = as.character(seq_len(n)),
    country                     = sample(c("United Kingdom", "France", "Germany"), n, replace = TRUE),
    purchase_frequency          = sample(1:20, n, replace = TRUE),
    avg_order_value             = round(runif(n, 10, 500), 2),
    unique_products             = sample(1:50, n, replace = TRUE),
    recency                     = sample(0:365, n, replace = TRUE),
    tenure                      = sample(1:730, n, replace = TRUE),
    total_quantity              = sample(1:1000, n, replace = TRUE),
    avg_quantity_per_order      = round(runif(n, 1, 50), 2),
    avg_product_price           = round(runif(n, 1, 100), 2),
    purchase_frequency_per_month = round(runif(n, 0, 5), 2)
  ) %>%
    mutate(
      total_spend = purchase_frequency * avg_order_value,
      high_value_customer = as.integer(total_spend > median(total_spend))
    )
}

test_that("build_kpi_country aggregates one row per country", {
  customers <- make_fixture_customers()
  kpis <- build_kpi_country(customers)

  expect_equal(nrow(kpis), n_distinct(customers$country))
  expect_true(all(c("n_customers", "total_revenue", "pct_high_value") %in% names(kpis)))
  expect_equal(sum(kpis$n_customers), nrow(customers))
})

test_that("detect_iqr_outliers only flags values above the upper bound", {
  customers <- make_fixture_customers()
  outliers <- detect_iqr_outliers(customers, "total_spend", "total_spend_outlier")

  expect_true(all(outliers$metric_value > outliers$threshold_value))
  expect_true(nrow(outliers) < nrow(customers))
})

test_that("run_linear_regression produces coefficients and metrics with expected shape", {
  customers <- make_fixture_customers()
  result <- run_linear_regression(customers, output_dir = tempdir())

  expect_s3_class(result$model, "lm")
  expect_true(all(c("model_name", "term", "estimate", "p_value") %in% names(result$coefficients)))
  expect_true("r_squared" %in% result$metrics$metric_name)
  expect_true("rmse" %in% result$metrics$metric_name)
})

test_that("run_logistic_regression produces a valid confusion matrix and AUC in [0,1]", {
  customers <- make_fixture_customers()
  result <- run_logistic_regression(customers, output_dir = tempdir())

  auc <- result$metrics$metric_value[result$metrics$metric_name == "auc"]
  n_test <- result$metrics$metric_value[result$metrics$metric_name == "n_test"]
  expect_true(auc >= 0 && auc <= 1)
  expect_equal(sum(result$confusion_matrix), n_test)
})

test_that("idempotence: rerunning KPI aggregation on the same data gives identical results", {
  customers <- make_fixture_customers()
  first_run <- build_kpi_country(customers)
  second_run <- build_kpi_country(customers)

  expect_equal(
    first_run %>% select(-run_date),
    second_run %>% select(-run_date)
  )
})
