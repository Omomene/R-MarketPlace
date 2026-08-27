library(ggplot2)
library(dplyr)

#' Genere les visualisations d'exploration (section 6 du cahier des charges)
#' et les enregistre dans output_dir.
run_eda <- function(customers, output_dir = "output") {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  save_plot <- function(p, filename) {
    ggsave(file.path(output_dir, filename), p, width = 8, height = 5)
  }

  save_plot(
    ggplot(customers, aes(x = total_spend)) +
      geom_histogram(bins = 50) +
      scale_x_log10() +
      labs(title = "Distribution des depenses totales (log10)", x = "TotalSpend", y = "Nombre de clients"),
    "01_distribution_total_spend.png"
  )

  save_plot(
    ggplot(customers, aes(x = purchase_frequency)) +
      geom_histogram(bins = 30) +
      labs(title = "Nombre de commandes par client", x = "PurchaseFrequency", y = "Nombre de clients"),
    "02_purchase_frequency.png"
  )

  save_plot(
    ggplot(customers, aes(x = avg_order_value)) +
      geom_histogram(bins = 50) +
      scale_x_log10() +
      labs(title = "Valeur moyenne des commandes (log10)", x = "AvgOrderValue", y = "Nombre de clients"),
    "03_avg_order_value.png"
  )

  save_plot(
    ggplot(customers, aes(x = recency)) +
      geom_histogram(bins = 30) +
      labs(title = "Recence des achats", x = "Recency (jours)", y = "Nombre de clients"),
    "04_recency.png"
  )

  save_plot(
    ggplot(customers, aes(x = tenure)) +
      geom_histogram(bins = 30) +
      labs(title = "Duree de la relation client", x = "Tenure (jours)", y = "Nombre de clients"),
    "05_tenure.png"
  )

  top_countries <- customers %>%
    group_by(country) %>%
    summarise(total_revenue = sum(total_spend, na.rm = TRUE), .groups = "drop") %>%
    slice_max(total_revenue, n = 10)

  save_plot(
    ggplot(top_countries, aes(x = reorder(country, total_revenue), y = total_revenue)) +
      geom_col() +
      coord_flip() +
      labs(title = "Top 10 pays par CA", x = "Pays", y = "CA total"),
    "06_revenue_by_country.png"
  )

  numeric_cols <- c(
    "total_spend", "purchase_frequency", "avg_order_value",
    "unique_products", "recency", "tenure", "total_quantity"
  )
  corr_matrix <- cor(customers[numeric_cols], use = "pairwise.complete.obs")
  write.csv(corr_matrix, file.path(output_dir, "07_correlation_matrix.csv"))

  invisible(NULL)
}
