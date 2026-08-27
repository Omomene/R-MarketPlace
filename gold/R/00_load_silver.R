library(DBI)

#' Charge la table client (niveau agrege) produite par la couche Silver.
load_silver_customers <- function(con) {
  dbGetQuery(con, "SELECT * FROM silver.customers")
}

#' Charge les transactions nettoyees (niveau ligne) produites par la couche Silver.
load_silver_transactions <- function(con) {
  dbGetQuery(con, "SELECT * FROM silver.transactions")
}
