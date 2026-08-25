from datetime import datetime
import json
import os

import boto3

from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.bash import BashOperator

from marketplace_hook import MarketplaceAPIHook

# ==========================================
# CONFIGURATION
# ==========================================

API_URL = os.getenv(
    "MARKETPLACE_API_URL",
    "http://api-marketplace:5000"
)

API_TOKEN = os.getenv(
    "MARKETPLACE_API_TOKEN",
    "formation-token-2026"
)

MINIO_ENDPOINT = os.getenv(
    "MINIO_ENDPOINT",
    "http://minio:9000"
)

MINIO_ACCESS_KEY = os.getenv(
    "MINIO_ACCESS_KEY",
    "minio"
)

MINIO_SECRET_KEY = os.getenv(
    "MINIO_SECRET_KEY",
    "minio12345"
)

MINIO_BUCKET = os.getenv(
    "MINIO_BUCKET",
    "bronze"
)


# ==========================================
# EXTRACT FROM API
# ==========================================

def extract_marketplace_data(**context):

    execution_date = context["ds"]

    hook = MarketplaceAPIHook(
        conn_id="marketplace_api"
    )

    print(
        f"Extracting marketplace data for {execution_date}"
    )

    orders = hook.get_orders(execution_date)

    sellers = hook.get_sellers()

    products = hook.get_products()

    customers = hook.get_customers()

    data = {
        "date": execution_date,
        "orders": orders,
        "sellers": sellers,
        "products": products,
        "customers": customers
    }

    print(f"Orders received: {len(orders)}")
    print(f"Sellers received: {len(sellers)}")
    print(f"Products received: {len(products)}")
    print(f"Customers received: {len(customers)}")

    context["ti"].xcom_push(
        key="marketplace_data",
        value=data
    )

# ==========================================
# UPLOAD TO MINIO — BRONZE
# ==========================================

def upload_to_minio(**context):

    execution_date = context["ds"]

    data = context["ti"].xcom_pull(
        task_ids="extract_marketplace_data",
        key="marketplace_data"
    )

    if not data:
        raise ValueError("No marketplace data received")

    # --------------------------------------
    # MinIO client
    # --------------------------------------

    s3 = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY
    )

    # --------------------------------------
    # Raw JSON
    # --------------------------------------

    object_name = (
        f"marketplace/"
        f"dt={execution_date}/"
        f"data.json"
    )

    json_data = json.dumps(
        data,
        ensure_ascii=False,
        indent=2
    )

    s3.put_object(
        Bucket=MINIO_BUCKET,
        Key=object_name,
        Body=json_data.encode("utf-8"),
        ContentType="application/json"
    )

    print(
        f"Data uploaded to "
        f"s3://{MINIO_BUCKET}/{object_name}"
    )


# ==========================================
# DAG
# ==========================================

with DAG(
    dag_id="marketplace_pipeline",

    description=(
        "Marketplace data pipeline: "
        "API -> MinIO Bronze -> R -> PostgreSQL"
    ),

    start_date=datetime(2026, 4, 1),

    schedule="@daily",

    catchup=False,

    tags=["marketplace", "r", "analytics"],

) as dag:

    # --------------------------------------
    # 1. API extraction
    # --------------------------------------

    extract = PythonOperator(
        task_id="extract_marketplace_data",
        python_callable=extract_marketplace_data
    )

    # --------------------------------------
    # 2. Bronze
    # --------------------------------------

    bronze = PythonOperator(
        task_id="upload_to_minio_bronze",
        python_callable=upload_to_minio
    )

    # --------------------------------------
    # 3. R Cleaning → Silver
    # --------------------------------------

    cleaning = BashOperator(
        task_id="r_cleaning",
        bash_command=(
            "Rscript /opt/airflow/r/cleaning.R "
            "{{ ds }}"
        )
    )

    # --------------------------------------
    # 4. R Analysis → Gold
    # --------------------------------------

    analysis = BashOperator(
        task_id="r_analysis",
        bash_command=(
            "Rscript /opt/airflow/r/analysis.R "
            "{{ ds }}"
        )
    )

    # --------------------------------------
    # PIPELINE
    # --------------------------------------

    extract >> bronze >> cleaning >> analysis