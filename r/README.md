
# Personne 3 (ADANTO Ameto Cornelia) — Couche Silver (nettoyage, transformation, validation)

## Rôle dans le pipeline

```
API Marketplace → extract_marketplace_data → upload_to_minio_bronze (Bronze)
                                                     ↓
r_cleaning (cleaning.R)  ← CETTE PARTIE
                                                     ↓
```

`cleaning.R` lit les données brutes déposées dans MinIO (Bronze) par Personne 2,
les nettoie, les valide, et les charge dans le schéma PostgreSQL `silver`
(dimensions + fait), de façon **idempotente**.

## Entrée : Bronze (MinIO)

Un seul objet JSON par jour, déposé par la tâche `upload_to_minio_bronze` :
```
s3://bronze/marketplace/dt=<YYYY-MM-DD>/data.json
```
contenant :
```json
{
  "date": "...",
  "orders": [ {order_id, seller_id, customer_id, product_id, quantity, unit_price, total_amount, status, dt}, ... ],
  "sellers": [ {seller_id, name, country, joined_date}, ... ],
  "products": [ {product_id, name, category, base_price}, ... ],
  "customers": [ {customer_id, email, city, signup_date}, ... ]
}
```

## Sortie : Silver (PostgreSQL, schéma `silver`)

| Table | Type | Clé |
|---|---|---|
| `silver.orders` | fait, partitionné par `order_date` | `order_id` |
| `silver.sellers` | dimension complète | `seller_id` |
| `silver.products` | dimension complète | `product_id` |
| `silver.customers` | dimension complète | `customer_id` |

⚠️ La colonne de date dans `silver.orders` s'appelle **`order_date`**, pas `dt`
(le champ brut Bronze s'appelle `dt`, il est renommé au chargement).

## Règles de nettoyage et de validation appliquées

**Orders**
- Typage strict (`order_id`/`seller_id`/`product_id`/`customer_id` en texte,
  `quantity` en entier, `total_amount` en numérique, `order_date` en date).
- Rejet si un champ obligatoire est manquant (`NA`).
- Rejet si `quantity <= 0` ou `total_amount < 0`.
- Rejet si `order_date` est dans le futur.
- Dédoublonnage sur `order_id`.
- **Intégrité référentielle** : une commande dont le `seller_id`, `product_id`
  ou `customer_id` n'existe pas dans les dimensions nettoyées est exclue (le
  nombre d'exclusions est loggué dans la console de la tâche).

**Sellers / Products / Customers**
- Trim des chaînes, typage des dates/prix.
- Rejet si nom manquant/vide (sellers, products) ou prix négatif (products).
- Dédoublonnage sur la clé primaire.

## Idempotence

- `silver.orders` (partitionné par date) : **DELETE + INSERT** sur la seule
  partition `order_date = <date traitée>`. Rejouer le même run pour la même
  date donne toujours le même `COUNT(*)` — vérifié manuellement.
- `silver.sellers` / `silver.products` / `silver.customers` (dimensions
  complètes, pas de notion de date) : **TRUNCATE + INSERT** à chaque run.

## Tester en isolation (sans passer par Airflow)

Dans RStudio (`localhost:8787`) :
```r
Sys.setenv(
  DB_HOST = "postgres", DB_PORT = "5432", DB_NAME = "marketplace",
  DB_USER = "app", DB_PASSWORD = "app12345",
  MINIO_ENDPOINT = "http://minio:9000",
  MINIO_ACCESS_KEY = "minio", MINIO_SECRET_KEY = "minio12345",
  MINIO_BUCKET = "bronze"
)
setwd("/home/rstudio/r")
source("cleaning.R")
```
Prérequis : une date pour laquelle `bronze/marketplace/dt=<date>/data.json`
existe déjà (déposé par le DAG `extract` → `upload_to_minio_bronze`).

Vérification dans Adminer (`localhost:8081`, serveur `postgres`, user `app`,
base `marketplace`, schéma `silver`) : `SELECT COUNT(*) FROM silver.orders;`
doit rester stable si on relance `source("cleaning.R")` deux fois de suite.

## Dépendances R

`DBI`, `RPostgres`, `jsonlite`, `dplyr`, `tidyr`, `lubridate`, `aws.s3`
(+ `libpq5` au niveau système pour que `RPostgres` puisse se charger).

## Problèmes rencontrés et corrigés pendant le développement

| Problème | Cause | Correction |
|---|---|---|
| `RPostgres` ne se charge pas (`libpq.so.5` introuvable) | Librairie système manquante dans l'image RStudio | Ajout de `libpq5` dans le Dockerfile RStudio |
| MinIO : `Could not resolve host: us-east-1.minio` | `aws.s3` insère une région AWS par défaut (`us-east-1`) incompatible avec MinIO | Forcer `region = ""` et `use_https = FALSE` dans `save_object()` |
| `column "dt" does not exist` | Le script utilisait `dt` alors que la table `silver.orders` (créée par `silver_tables.sql`) utilise `order_date` | Renommage `dt` → `order_date` dans `cleaning.R` |
| `there is no package called 'aws.s3'` (dans le conteneur Airflow) | Le Dockerfile Airflow n'installait pas `aws.s3` | Package ajouté au Dockerfile Airflow (voir section Docker) |
