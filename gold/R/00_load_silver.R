library(DBI)
library(dplyr)
library(lubridate)


# ============================================================
# 1. Charger les transactions depuis silver.orders
# ============================================================

load_silver_transactions <- function(con) {

  orders <- dbGetQuery(
    con,
    "
    SELECT
        order_id,
        seller_id,
        customer_id,
        product_id,
        order_date,
        quantity,
        total_amount,
        status
    FROM silver.orders
    "
  )

  orders %>%
    mutate(
      invoice = order_id,
      invoice_date = as.Date(order_date),
      transaction_amount = as.numeric(total_amount)
    )
}


# ============================================================
# 2. Construire le profil client attendu par la Gold
# ============================================================

load_silver_customers <- function(con) {

  orders <- dbGetQuery(
    con,
    "
    SELECT
        order_id,
        customer_id,
        product_id,
        order_date,
        quantity,
        total_amount
    FROM silver.orders
    "
  )

  customers <- dbGetQuery(
    con,
    "
    SELECT
        customer_id,
        email,
        city,
        signup_date
    FROM silver.customers
    "
  )

  sellers <- dbGetQuery(
    con,
    "
    SELECT
        seller_id,
        country
    FROM silver.sellers
    "
  )

  # ----------------------------------------------------------
  # Pays du client
  #
  # Silver ne contient pas directement le pays du client.
  # On utilise ici le pays du vendeur de ses commandes comme
  # approximation pour alimenter les analyses Gold.
  # ----------------------------------------------------------

  order_country <- dbGetQuery(
    con,
    "
    SELECT
        o.customer_id,
        s.country
    FROM silver.orders o
    LEFT JOIN silver.sellers s
        ON o.seller_id = s.seller_id
    "
  )

  customer_country <- order_country %>%
    filter(!is.na(country)) %>%
    count(
      customer_id,
      country,
      name = "n"
    ) %>%
    group_by(customer_id) %>%
    slice_max(
      order_by = n,
      n = 1,
      with_ties = FALSE
    ) %>%
    ungroup() %>%
    select(
      customer_id,
      country
    )


  # ----------------------------------------------------------
  # Agrégats clients
  # ----------------------------------------------------------

  orders$order_date <- as.Date(
    orders$order_date
  )

  max_date <- max(
    orders$order_date,
    na.rm = TRUE
  )

  customer_metrics <- orders %>%
    group_by(customer_id) %>%
    summarise(

      total_spend =
        sum(
          total_amount,
          na.rm = TRUE
        ),

      purchase_frequency =
        n_distinct(order_id),

      avg_order_value =
        mean(
          total_amount,
          na.rm = TRUE
        ),

      unique_products =
        n_distinct(product_id),

      recency =
        as.numeric(
          max_date -
          max(
            order_date,
            na.rm = TRUE
          )
        ),

      total_quantity =
        sum(
          quantity,
          na.rm = TRUE
        ),

      avg_quantity_per_order =
        mean(
          quantity,
          na.rm = TRUE
        ),

      .groups = "drop"
    )


  # ----------------------------------------------------------
  # Tenure
  # ----------------------------------------------------------

  customers$signup_date <- as.Date(
    customers$signup_date
  )

  customer_profile <- customers %>%

    left_join(
      customer_metrics,
      by = "customer_id"
    ) %>%

    left_join(
      customer_country,
      by = "customer_id"
    ) %>%

    mutate(

      tenure =
        as.numeric(
          max_date -
          signup_date
        ),

      total_spend =
        coalesce(
          total_spend,
          0
        ),

      purchase_frequency =
        coalesce(
          purchase_frequency,
          0L
        ),

      avg_order_value =
        coalesce(
          avg_order_value,
          0
        ),

      unique_products =
        coalesce(
          unique_products,
          0L
        ),

      recency =
        coalesce(
          recency,
          0
        ),

      total_quantity =
        coalesce(
          total_quantity,
          0
        ),

      avg_quantity_per_order =
        coalesce(
          avg_quantity_per_order,
          0
        )
    )


  # ==========================================================
  # 3. High Value Customer
  #
  # Abraham attend cette variable pour la régression logistique.
  # On considère high value = dépense supérieure à la médiane.
  # ==========================================================

  spend_threshold <- median(
    customer_profile$total_spend,
    na.rm = TRUE
  )

  customer_profile <- customer_profile %>%
    mutate(
      high_value_customer =
        as.integer(
          total_spend >
          spend_threshold
        )
    )

  customer_profile
}