library(dplyr)

#' Detecte les outliers d'une colonne numerique par la methode IQR
#' (borne = Q3 + k * IQR, k = 1.5 par defaut).
detect_iqr_outliers <- function(customers, metric_col, anomaly_type, k = 1.5) {
  values <- customers[[metric_col]]
  q1 <- quantile(values, 0.25, na.rm = TRUE)
  q3 <- quantile(values, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  upper_bound <- q3 + k * iqr

  customers %>%
    filter(.data[[metric_col]] > upper_bound) %>%
    transmute(
      customer_id     = customer_id,
      anomaly_type    = anomaly_type,
      metric_value    = .data[[metric_col]],
      threshold_value = upper_bound
    )
}

#' Construit gold.customer_anomalies : clients avec depense totale ou panier
#' moyen anormalement eleves par rapport a la distribution generale.
build_customer_anomalies <- function(customers) {
  spend_outliers <- detect_iqr_outliers(customers, "total_spend", "total_spend_outlier")
  aov_outliers   <- detect_iqr_outliers(customers, "avg_order_value", "avg_order_value_outlier")

  bind_rows(spend_outliers, aov_outliers) %>%
    mutate(detected_at = Sys.time())
}
