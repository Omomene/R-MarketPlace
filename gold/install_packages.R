pkgs <- c(
  "DBI",
  "RPostgres",
  "dplyr",
  "tidyr",
  "ggplot2",
  "lubridate",
  "broom",
  "pROC",
  "tibble",
  "testthat"
)

installed <- rownames(installed.packages())
to_install <- setdiff(pkgs, installed)

if (length(to_install) > 0) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
}
