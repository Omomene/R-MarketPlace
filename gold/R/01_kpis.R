library(dplyr)
library(lubridate)

#' Construit gold.kpi_country a partir de silver.customers.
build_kpi_country <- function(customers) {
  customers %>%
    filter(!is.na(country)) %>%
    group_by(country) %>%
    summarise(
      n_customers      = n(),
      total_revenue    = sum(total_spend, na.rm = TRUE),
      avg_order_value  = mean(avg_order_value, na.rm = TRUE),
      avg_recency_days = mean(recency, na.rm = TRUE),
      pct_high_value   = 100 * mean(high_value_customer, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(run_date = Sys.Date())
}

#' Construit gold.kpi_monthly a partir de silver.transactions.
build_kpi_monthly <- function(transactions) {
  transactions %>%
    mutate(year_month = format(as.Date(invoice_date), "%Y-%m")) %>%
    group_by(year_month) %>%
    summarise(
      n_orders      = n_distinct(invoice),
      n_customers   = n_distinct(customer_id),
      total_revenue = sum(transaction_amount, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(run_date = Sys.Date())
}
