from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.google.cloud.operators.cloud_run import (
    CloudRunExecuteJobOperator,
)
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator

PROJECT_ID = "my-project-77-511616"
REGION = "asia-south1"

default_args = {
    "owner": "atmosdata",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=3),
}

with DAG(
    dag_id="atmosdata_weather_pipeline",
    description="15-minute weather collection and warehouse transformations",
    start_date=datetime(2026, 1, 1),
    schedule="*/15 * * * *",
    catchup=False,
    default_args=default_args,
    max_active_runs=1,
    tags=["AtmosData", "weather", "GCP"],
) as dag:
    # Configure an Airflow HTTP connection named atmosdata_ingestion_function
    # with the deployed Cloud Run Function URL and authentication as required.
    ingest_weather = SimpleHttpOperator(
        task_id="invoke_weather_ingestion",
        http_conn_id="atmosdata_ingestion_function",
        endpoint="",
        method="POST",
        headers={"Content-Type": "application/json"},
        data="{}",
        response_check=lambda response: response.status_code in (200, 207),
    )

    # Eventarc independently loads the GCS object into Bronze.
    # These SQL tasks run after ingestion; the SQL statements are idempotent.
    silver_transform = BigQueryInsertJobOperator(
        task_id="transform_bronze_to_silver",
        configuration={
            "query": {
                "query": "{% include 'sql/silver/transform_weather.sql' %}",
                "useLegacySql": False,
            }
        },
        location=REGION,
        project_id=PROJECT_ID,
    )

    gold_transform = BigQueryInsertJobOperator(
        task_id="transform_silver_to_gold",
        configuration={
            "query": {
                "query": "{% include 'sql/gold/build_daily_city_summary.sql' %}",
                "useLegacySql": False,
            }
        },
        location=REGION,
        project_id=PROJECT_ID,
    )

    ingest_weather >> silver_transform >> gold_transform
