library(dplyr)
library(broom)
library(ggplot2)

#' Regression lineaire : TotalSpend ~ PurchaseFrequency + AvgOrderValue +
#' UniqueProducts + Recency + Tenure + Country + TotalQuantity
#' (section 7 du cahier des charges).
#'
#' Retourne une liste avec le modele ajuste et les data.frames prets a etre
#' ecrits dans gold.model_coefficients / gold.model_metrics.
run_linear_regression <- function(customers, output_dir = "output") {
  model_name <- "linear_total_spend"

  # Vérifier si Country possède au moins 2 modalités
has_country_variation <- (
  "country" %in% names(customers) &&
  length(unique(na.omit(customers$country))) >= 2
)

if (has_country_variation) {

  formula_linear <- total_spend ~
    purchase_frequency +
    avg_order_value +
    unique_products +
    recency +
    tenure +
    country +
    total_quantity

} else {

  warning(
    "Country exclu de la regression lineaire : moins de 2 modalites."
  )

  formula_linear <- total_spend ~
    purchase_frequency +
    avg_order_value +
    unique_products +
    recency +
    tenure +
    total_quantity
}

fit <- lm(
  formula_linear,
  data = customers
)

  predictions <- predict(fit, customers)
  rmse <- sqrt(mean((customers$total_spend - predictions)^2, na.rm = TRUE))

  coefficients_df <- broom::tidy(fit) %>%
    transmute(
      model_name = model_name,
      term       = term,
      estimate   = estimate,
      std_error  = std.error,
      statistic  = statistic,
      p_value    = p.value,
      run_date   = Sys.Date()
    )

  fit_stats <- broom::glance(fit)
  metrics_df <- tibble::tibble(
    model_name   = model_name,
    metric_name  = c("r_squared", "adj_r_squared", "rmse", "f_statistic", "n_obs"),
    metric_value = c(fit_stats$r.squared, fit_stats$adj.r.squared, rmse, fit_stats$statistic, nobs(fit)),
    run_date     = Sys.Date()
  )

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  diag_df <- broom::augment(fit)

  ggsave(
    file.path(output_dir, "08_linear_residuals_vs_fitted.png"),
    ggplot(diag_df, aes(x = .fitted, y = .resid)) +
      geom_point(alpha = 0.3) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      labs(title = "Residus vs valeurs ajustees", x = "Fitted", y = "Residuals"),
    width = 8, height = 5
  )

  ggsave(
    file.path(output_dir, "09_linear_qq_plot.png"),
    ggplot(diag_df, aes(sample = .std.resid)) +
      stat_qq() +
      stat_qq_line() +
      labs(title = "QQ-plot des residus standardises"),
    width = 8, height = 5
  )

  list(model = fit, coefficients = coefficients_df, metrics = metrics_df)
}
