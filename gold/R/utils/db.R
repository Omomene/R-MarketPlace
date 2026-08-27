library(DBI)
library(RPostgres)

#' Ouvre une connexion PostgreSQL a partir des variables d'environnement
#' PGHOST / PGPORT / PGDATABASE / PGUSER / PGPASSWORD.
gold_db_connect <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host     = Sys.getenv("PGHOST", "localhost"),
    port     = as.integer(Sys.getenv("PGPORT", "5432")),
    dbname   = Sys.getenv("PGDATABASE", "projet_r"),
    user     = Sys.getenv("PGUSER", "projet_r"),
    password = Sys.getenv("PGPASSWORD", "projet_r_pwd")
  )
}

#' Remplace integralement le contenu d'une table gold par un data.frame,
#' dans une transaction (pattern idempotent : DELETE run courant + INSERT).
gold_write_table <- function(con, schema, table, df, run_date_col = "run_date") {
  full_name <- DBI::Id(schema = schema, table = table)

  dbWithTransaction(con, {
    if (!is.null(run_date_col) && run_date_col %in% names(df) && nrow(df) > 0) {
      run_dates <- unique(df[[run_date_col]])
      placeholders <- paste(sprintf("'%s'", run_dates), collapse = ", ")
      dbExecute(con, sprintf(
        "DELETE FROM %s.%s WHERE %s IN (%s)",
        schema, table, run_date_col, placeholders
      ))
    } else {
      dbExecute(con, sprintf("TRUNCATE TABLE %s.%s", schema, table))
    }

    if (nrow(df) > 0) {
      dbAppendTable(con, full_name, df)
    }
  })

  invisible(NULL)
}
