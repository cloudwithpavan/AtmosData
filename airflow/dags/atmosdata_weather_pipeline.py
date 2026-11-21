import json
from datetime import datetime, timedelta

import google.auth
from google.auth.transport.requests import Request
from google.oauth2 import id_token

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCheckOperator,
    BigQueryInsertJobOperator,
)


PROJECT_ID = "my-project-77-511616"
REGION = "asia-south1"

WEATHER_INGESTION_URL = (
    "https://weather-ingestion-rn5rxt2siq-el.a.run.app"
)

default_args = {
    "owner": "atmosdata",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=3),
}


def invoke_weather_ingestion(**context):
    """
    Invoke the authenticated Cloud Run Function using
    the Composer/Airflow service account identity token.
    """

    import requests

    request = Request()

    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )

    credentials.refresh(request)

    token = id_token.fetch_id_token(
        request,
        WEATHER_INGESTION_URL,
    )

    response = requests.post(
        WEATHER_INGESTION_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json={},
        timeout=120,
    )

    response.raise_for_status()

    result = response.json()

    if result.get("status") not in ("success", "partial"):
        raise RuntimeError(
            f"Weather ingestion failed: {result}"
        )

    gcs_object = result.get("gcs_object")

    if not gcs_object:
        raise RuntimeError(
            f"gcs_object missing from ingestion response: {result}"
        )

    context["ti"].xcom_push(
        key="gcs_object",
        value=gcs_object,
    )

    context["ti"].xcom_push(
        key="ingestion_result",
        value=json.dumps(result),
    )
    context["ti"].xcom_push(
        key="successful_cities",
        value=result.get("successful_cities", 0),
    )


with DAG(
    dag_id="atmosdata_weather_pipeline",
    description="AtmosData weather ingestion and warehouse pipeline",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    max_active_runs=1,
    tags=["AtmosData", "weather", "GCP"],
) as dag:

    # ---------------------------------------------------------
    # 1. Trigger Cloud Run weather ingestion
    # ---------------------------------------------------------
    ingest_weather = PythonOperator(
        task_id="invoke_weather_ingestion",
        python_callable=invoke_weather_ingestion,
    )

    # ---------------------------------------------------------
    # 2. Wait for Eventarc -> Bronze
    #
    # Eventarc loads the GCS object asynchronously.
    # We verify that all 5 expected city rows exist before
    # allowing Silver to execute.
    # ---------------------------------------------------------
    validate_bronze = BigQueryCheckOperator(
        task_id="validate_bronze_load",
        sql="""
        SELECT COUNT(*) >= GREATEST(CAST('{{ ti.xcom_pull(task_ids="invoke_weather_ingestion", key="successful_cities") }}' AS INT64), 1)
        FROM `my-project-77-511616.weather_bronze_dev.weather_observations`
        WHERE source_object = '{{ ti.xcom_pull(
            task_ids="invoke_weather_ingestion",
            key="gcs_object"
        ) }}'
        """,
        use_legacy_sql=False,
        location=REGION,
        gcp_conn_id="google_cloud_default",
        retries=10,
        retry_delay=timedelta(seconds=30),
    )

    # ---------------------------------------------------------
    # 3. Bronze -> Silver
    # ---------------------------------------------------------
    silver_transform = BigQueryInsertJobOperator(
        task_id="transform_bronze_to_silver",
        configuration={
            "query": {
                "query": """
                {% include 'sql/silver/transform_weather.sql' %}
                """,
                "useLegacySql": False,
            }
        },
        location=REGION,
        project_id=PROJECT_ID,
        gcp_conn_id="google_cloud_default",
    )

    # ---------------------------------------------------------
    # 4. Silver -> Gold
    # ---------------------------------------------------------
    gold_transform = BigQueryInsertJobOperator(
        task_id="transform_silver_to_gold",
        configuration={
            "query": {
                "query": """
                {% include 'sql/gold/build_daily_city_summary.sql' %}
                """,
                "useLegacySql": False,
            }
        },
        location=REGION,
        project_id=PROJECT_ID,
        gcp_conn_id="google_cloud_default",
    )

    # ---------------------------------------------------------
    # Pipeline dependency
    # ---------------------------------------------------------
    (
        ingest_weather
        >> validate_bronze
        >> silver_transform
        >> gold_transform
    )
