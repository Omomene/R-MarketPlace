# R-MarketPlace — Pipeline Data & Analytics

Projet de pipeline Data complet réalisé autour d'une marketplace e-commerce.

L'objectif est de construire une architecture permettant de :

- collecter les données depuis une API Marketplace ;
- stocker les données brutes dans un Data Lake MinIO ;
- nettoyer et transformer les données avec R ;
- stocker les données structurées dans PostgreSQL ;
- construire des indicateurs analytiques et des modèles statistiques ;
- orchestrer le pipeline avec Apache Airflow ;
- visualiser les résultats dans un dashboard Streamlit.

---

## Architecture du projet

Le pipeline suit l'architecture suivante :

```text
Marketplace API
      │
      ▼
Apache Airflow
      │
      ▼
MinIO
Bronze Layer
      │
      ▼
R - Cleaning
      │
      ▼
PostgreSQL
Silver Layer
      │
      ▼
R - Analytics / Models
      │
      ▼
PostgreSQL
Gold Layer
      │
      ▼
Streamlit Dashboard
```

### Flux principal

```text
API → Airflow → MinIO → R → PostgreSQL Silver → Gold → Streamlit
```

---

## Structure du projet

```text
R-MarketPlace/
│
├── airflow/
│   ├── dags/
│   │   └── marketplace_pipeline.py
│   ├── plugins/
│   │   └── marketplace_hook.py
│   └── Dockerfile
│
├── api/
│   └── app.py
│
├── gold/
│   ├── R/
│   │   ├── utils/
│   │   │   └── db.R
│   │   ├── 00_load_silver.R
│   │   ├── 01_kpis.R
│   │   ├── 02_anomaly_detection.R
│   │   ├── 03_eda.R
│   │   ├── 04_regression_linear.R
│   │   ├── 05_regression_logistic.R
│   │   └── run_pipeline.R
│   ├── sql/
│   ├── tests/
│   └── Dockerfile
│
├── r/
│   ├── cleaning.R
│   └── analysis.R
│
├── sql/
│   ├── schema.sql
│   ├── silver_tables.sql
│   └── gold_tables.sql
│
├── streamlit/
│   ├── app.py
│   ├── components.py
│   ├── db.py
│   ├── queries.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── tests/
│
├── docker-compose.yaml
├── .gitignore
└── README.md
```

---

# Pipeline de données

## 1. Marketplace API

Une API Flask simule la source de données de la marketplace.

Elle fournit notamment les données relatives aux :

- commandes ;
- clients ;
- vendeurs ;
- produits.

L'API est accessible sur :

```text
http://localhost:5000
```

---

## 2. Orchestration avec Apache Airflow

Apache Airflow orchestre le pipeline de données.

Le DAG principal est :

```text
marketplace_pipeline
```

Il exécute les étapes suivantes :

```text
extract_marketplace_data
        ↓
upload_to_minio_bronze
        ↓
r_cleaning
        ↓
r_analysis
```

Airflow est accessible sur :

```text
http://localhost:8080
```

---

## 3. Bronze — MinIO

Les données brutes provenant de l'API sont stockées dans MinIO.

Le bucket utilisé est :

```text
bronze
```

Les données sont organisées par date :

```text
bronze/
└── marketplace/
    └── dt=YYYY-MM-DD/
        └── data.json
```

Console MinIO :

```text
http://localhost:9001
```

---

## 4. Silver — Nettoyage des données

La couche Silver contient les données nettoyées et structurées.

Le traitement est réalisé avec R avant chargement dans PostgreSQL.

Les principales tables sont :

```text
silver.orders
silver.customers
silver.products
silver.sellers
```

Cette couche constitue la base utilisée pour les traitements analytiques.

---

## 5. Gold — Analytics & Data Science

La couche Gold transforme les données Silver en indicateurs analytiques et résultats de modèles.

### KPI

Les indicateurs comprennent notamment :

- chiffre d'affaires ;
- nombre de commandes ;
- nombre de clients ;
- panier moyen ;
- évolution mensuelle ;
- analyse géographique.

### Détection d'anomalies

Le pipeline identifie également certains comportements ou valeurs atypiques au niveau client.

### Modèles statistiques

Deux modèles sont intégrés :

#### Régression linéaire

Utilisée pour analyser et expliquer le `TotalSpend`.

Les résultats incluent notamment :

- R² ;
- R² ajusté ;
- RMSE ;
- statistique F ;
- coefficients du modèle.

#### Régression logistique

Utilisée pour étudier les clients à forte valeur (`HighValueCustomer`).

Les métriques disponibles peuvent inclure :

- Accuracy ;
- Sensitivity ;
- Specificity ;
- AUC.

> Certaines métriques peuvent être indisponibles lorsque le jeu de données de test ne contient qu'une seule classe.

### Tables Gold

Le projet contient notamment :

```text
gold.kpi_country
gold.kpi_monthly
gold.customer_anomalies
gold.model_coefficients
gold.model_metrics
```

---

# Dashboard Streamlit

Le dashboard Streamlit constitue la couche de visualisation du projet.

Il se connecte directement aux couches Silver et Gold de PostgreSQL.

L'application propose plusieurs vues analytiques.

### Vue générale

Présentation synthétique des performances de la marketplace :

- chiffre d'affaires ;
- commandes ;
- clients ;
- panier moyen ;
- évolution du chiffre d'affaires ;
- évolution des commandes ;
- analyse par catégorie ;
- top vendeurs ;
- répartition des commandes.

### Ventes

Analyse détaillée des transactions et de leur évolution dans le temps.

### Clients

Analyse du comportement et des indicateurs clients.

### Vendeurs

Analyse des performances commerciales des vendeurs et des pays associés.

### Modèles R

Visualisation des résultats produits par les modèles statistiques de la couche Gold.

### Anomalies

Consultation des anomalies détectées par le pipeline analytique.

Streamlit est accessible sur :

```text
http://localhost:8501
```

---

# Lancement du projet

## Prérequis

Installer :

- Docker Desktop ;
- Docker Compose ;
- Git.

---

## 1. Cloner le repository

```bash
git clone https://github.com/Omomene/R-MarketPlace.git
cd R-MarketPlace
```

---

## 2. Configurer les variables d'environnement

Créer un fichier `.env` à la racine du projet :

```env
AIRFLOW_UID=50000
AIRFLOW_GID=0

POSTGRES_USER=app
POSTGRES_PASSWORD=app12345
POSTGRES_DB=marketplace

MARKETPLACE_API_TOKEN=formation-token-2026

MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio12345

RSTUDIO_PASSWORD=rstudio12345
```

> Le fichier `.env` ne doit pas être versionné dans Git.

---

## 3. Démarrer l'environnement

```bash
docker compose up -d
```

Vérifier les conteneurs :

```bash
docker compose ps
```

---

# PostgreSQL

La base utilisée est :

```text
marketplace
```

Utilisateur :

```text
app
```

Les données sont organisées principalement dans deux schémas :

```text
silver
gold
```

Adminer est disponible sur :

```text
http://localhost:8081
```

---

# Exécution de la couche Gold

Construire l'image :

```bash
docker build -t marketplace-gold ./gold
```

Puis lancer le pipeline Gold :

```bash
docker run --rm \
  --network r-marketplace_marketplace-net \
  -e PGHOST=postgres \
  -e PGPORT=5432 \
  -e PGDATABASE=marketplace \
  -e PGUSER=app \
  -e PGPASSWORD=app12345 \
  marketplace-gold
```

Une exécution réussie se termine par :

```text
Pipeline Gold termine avec succes.
```

---

#  Chargement historique

Le pipeline Airflow peut être exécuté sur plusieurs dates afin de construire un historique des commandes.

Exemple de période utilisée dans le projet :

```text
01/06/2026 → 27/08/2026
```

Les données Silver permettent ensuite de suivre l'évolution quotidienne et mensuelle des performances dans le dashboard.

---

#  Technologies utilisées

| Technologie | Utilisation |
|---|---|
| Python | API, orchestration et dashboard |
| R | Nettoyage, analyse et modèles statistiques |
| Apache Airflow | Orchestration du pipeline |
| PostgreSQL | Stockage Silver & Gold |
| MinIO | Data Lake / couche Bronze |
| Streamlit | Dashboard analytique |
| Altair | Visualisations |
| Flask | Marketplace API |
| Docker | Conteneurisation |
| Docker Compose | Orchestration des services |
| Git / GitHub | Versioning et collaboration |

---

#  Services

| Service | Adresse |
|---|---|
| Marketplace API | `http://localhost:5000` |
| Airflow | `http://localhost:8080` |
| Streamlit | `http://localhost:8501` |
| Adminer | `http://localhost:8081` |
| MinIO API | `http://localhost:9000` |
| MinIO Console | `http://localhost:9001` |
| RStudio | `http://localhost:8787` |

---

#  Objectif pédagogique

Ce projet met en œuvre un pipeline Data de bout en bout combinant :

```text
Ingestion
   ↓
Data Lake
   ↓
Transformation
   ↓
Data Warehouse
   ↓
Analytics / Data Science
   ↓
Data Visualization
```

Il illustre notamment :

- l'orchestration d'un pipeline ;
- une architecture Bronze / Silver / Gold ;
- l'intégration de Python et R ;
- la persistance des données dans PostgreSQL ;
- l'analyse statistique ;
- la conteneurisation avec Docker ;
- la construction d'un dashboard analytique interactif.

---

##  Projet

**R-MarketPlace — Groupe 11**

Projet réalisé dans le cadre d'un travail collaboratif autour de la conception d'un pipeline Data & Analytics. 
