library(dplyr)
library(broom)
library(pROC)

#' Regression logistique : HighValueCustomer ~ PurchaseFrequency + Recency +
#' Tenure + UniqueProducts + AvgQuantityPerOrder + Country
#' (section 8 du cahier des charges).
#'
#' NB : TotalSpend et AvgOrderValue sont volontairement exclus des variables
#' explicatives pour eviter une relation circulaire avec HighValueCustomer.
#'
#' Split train/test (70/30) pour evaluer la capacite de generalisation.
run_logistic_regression <- function(customers, output_dir = "output", seed = 42, train_ratio = 0.7) {
  model_name <- "logistic_high_value"

  set.seed(seed)
  n <- nrow(customers)
  train_idx <- sample.int(n, size = floor(train_ratio * n))
  train_data <- customers[train_idx, ]
  test_data <- customers[-train_idx, ]

  fit <- glm(
    high_value_customer ~ purchase_frequency + recency + tenure +
      unique_products + avg_quantity_per_order + country,
    data = train_data,
    family = binomial(link = "logit")
  )

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

  test_probs <- predict(fit, newdata = test_data, type = "response")
  test_preds <- as.integer(test_probs >= 0.5)
  actual <- test_data$high_value_customer

  confusion <- table(
    predicted = factor(test_preds, levels = c(0, 1)),
    actual    = factor(actual, levels = c(0, 1))
  )
  tp <- confusion["1", "1"]
  tn <- confusion["0", "0"]
  fp <- confusion["1", "0"]
  fn <- confusion["0", "1"]

  accuracy    <- (tp + tn) / (tp + tn + fp + fn)
  sensitivity <- ifelse((tp + fn) > 0, tp / (tp + fn), NA_real_)
  specificity <- ifelse((tn + fp) > 0, tn / (tn + fp), NA_real_)

  roc_obj <- pROC::roc(actual, test_probs, quiet = TRUE)
  auc_value <- as.numeric(pROC::auc(roc_obj))

  metrics_df <- tibble::tibble(
    model_name   = model_name,
    metric_name  = c("accuracy", "sensitivity", "specificity", "auc", "n_train", "n_test"),
    metric_value = c(accuracy, sensitivity, specificity, auc_value, nrow(train_data), nrow(test_data)),
    run_date     = Sys.Date()
  )

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  png(file.path(output_dir, "10_logistic_roc_curve.png"), width = 800, height = 600)
  plot(roc_obj, main = "Courbe ROC - HighValueCustomer")
  dev.off()

  list(model = fit, coefficients = coefficients_df, metrics = metrics_df, confusion_matrix = confusion)
}
