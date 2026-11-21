
import json
import logging
import os
import smtplib
import uuid
from email.message import EmailMessage
from datetime import datetime, timezone
from typing import Any

import functions_framework
import pymysql
import requests
from google.cloud import secretmanager, storage
from google.cloud.sql.connector import Connector, IPTypes

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "my-project-77-511616")
BUCKET_NAME = os.environ["RAW_BUCKET_NAME"]
SECRET_NAME = os.environ.get("OPENWEATHER_SECRET_NAME", "openweather-api-key")

SQL_INSTANCE_CONNECTION_NAME = os.environ["SQL_INSTANCE_CONNECTION_NAME"]
MYSQL_DATABASE = os.environ.get("MYSQL_DATABASE", "atmosdata_ops")
MYSQL_USER = os.environ.get("MYSQL_USER", "atmosdata_app")
MYSQL_PASSWORD_SECRET_NAME = os.environ.get(
    "MYSQL_PASSWORD_SECRET_NAME",
    "atmosdata-mysql-password",
)

CITIES = [
    {"name": "Hyderabad", "lat": 17.3850, "lon": 78.4867},
    {"name": "Bengaluru", "lat": 12.9716, "lon": 77.5946},
    {"name": "Mumbai", "lat": 19.0760, "lon": 72.8777},
    {"name": "Delhi", "lat": 28.6139, "lon": 77.2090},
    {"name": "Chennai", "lat": 13.0827, "lon": 80.2707},
]

logging.basicConfig(level=logging.INFO)


def get_secret(secret_name: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_name}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("utf-8").strip()


def send_notification(subject: str, body: str) -> None:
    """Send an email notification. Email failures must not fail ingestion."""

    try:
        sender = os.environ["GMAIL_SENDER"]
        recipients = [
            address.strip()
            for address in os.environ["GMAIL_RECIPIENTS"].split(";")
            if address.strip()
        ]
        gmail_secret = os.environ.get(
            "GMAIL_SECRET_NAME",
            "gmail-app-password",
        )

        if not recipients:
            raise ValueError("No Gmail recipients configured.")

        password = get_secret(gmail_secret)

        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = sender
        message["To"] = ", ".join(recipients)
        message.set_content(body)

        with smtplib.SMTP("smtp.gmail.com", 587, timeout=30) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.ehlo()
            smtp.login(sender, password)
            smtp.send_message(message)

        logging.info("Email notification sent to %s", recipients)

    except Exception:
        logging.exception("Gmail notification failed")


def fetch_weather(city: dict[str, Any], api_key: str) -> dict[str, Any]:
    response = requests.get(
        "https://api.openweathermap.org/data/2.5/weather",
        params={
            "lat": city["lat"],
            "lon": city["lon"],
            "appid": api_key,
            "units": "metric",
        },
        timeout=20,
    )
    response.raise_for_status()

    payload = response.json()
    weather = (payload.get("weather") or [{}])[0]
    main = payload.get("main") or {}
    wind = payload.get("wind") or {}

    return {
        "city": city["name"],
        "latitude": city["lat"],
        "longitude": city["lon"],
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        "provider_timestamp": payload.get("dt"),
        "temperature_c": main.get("temp"),
        "feels_like_c": main.get("feels_like"),
        "humidity_pct": main.get("humidity"),
        "pressure_hpa": main.get("pressure"),
        "weather_main": weather.get("main"),
        "weather_description": weather.get("description"),
        "wind_speed_mps": wind.get("speed"),
        "cloudiness_pct": (payload.get("clouds") or {}).get("all"),
    }


def write_mysql_audit(
    run_id: str,
    successful_cities: list,
    failures: list,
    gcs_object: str,
) -> None:
    """Write per-city ingestion audit and API errors to Cloud SQL."""

    password = get_secret(MYSQL_PASSWORD_SECRET_NAME)

    with Connector() as connector:
        connection = connector.connect(
            SQL_INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=MYSQL_USER,
            password=password,
            db=MYSQL_DATABASE,
            ip_type=IPTypes.PUBLIC,
            connect_timeout=10,
        )

        try:
            with connection.cursor() as cursor:
                audit_rows = []

                for record in successful_cities:
                    audit_rows.append((
                        run_id,
                        record["city"],
                        "success",
                        gcs_object,
                        None,
                    ))

                for failure in failures:
                    audit_rows.append((
                        run_id,
                        failure["city"],
                        "failed",
                        gcs_object,
                        failure["error"][:5000],
                    ))

                cursor.executemany(
                    """
                    INSERT INTO ingestion_audit
                    (
                        run_id,
                        city_name,
                        status,
                        gcs_object,
                        error_message,
                        started_at,
                        completed_at
                    )
                    VALUES (
                        %s, %s, %s, %s, %s,
                        UTC_TIMESTAMP(), UTC_TIMESTAMP()
                    )
                    """,
                    audit_rows,
                )

                if failures:
                    error_rows = [
                        (
                            "weather-ingestion",
                            "WeatherAPIError",
                            failure["city"] + ": " + failure["error"],
                        )
                        for failure in failures
                    ]

                    cursor.executemany(
                        """
                        INSERT INTO error_log
                        (component, error_type, error_message)
                        VALUES (%s, %s, %s)
                        """,
                        error_rows,
                    )

            connection.commit()
            logging.info(
                "MySQL audit saved for run %s: %s successful, %s failed",
                run_id,
                len(successful_cities),
                len(failures),
            )

        except Exception:
            connection.rollback()
            raise

        finally:
            connection.close()


@functions_framework.http
def ingest_weather(request):
    """Fetch weather, upload raw JSON, and record operational audit."""

    run_id = str(uuid.uuid4())

    try:
        api_key = get_secret(SECRET_NAME)

        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(BUCKET_NAME)

        run_time = datetime.now(timezone.utc)
        date_path = run_time.strftime("%Y/%m/%d")
        timestamp = run_time.strftime("%Y%m%dT%H%M%S%fZ")

        results = []
        failures = []

        for city in CITIES:
            try:
                results.append(fetch_weather(city, api_key))

            except requests.RequestException as exc:
                logging.exception(
                    "Weather API failed for %s",
                    city["name"],
                )
                failures.append({
                    "city": city["name"],
                    "error": str(exc),
                })

        document = {
            "project": "AtmosData",
            "run_id": run_id,
            "collection_timestamp_utc": run_time.isoformat(),
            "records": results,
            "failures": failures,
        }

        object_name = (
            f"raw/weather/{date_path}/weather_{timestamp}.json"
        )

        blob = bucket.blob(object_name)
        blob.upload_from_string(
            json.dumps(document, ensure_ascii=False),
            content_type="application/json",
            if_generation_match=0,
        )

        # MySQL logging is best-effort:
        # a database logging failure must not discard a successful GCS upload.
        try:
            write_mysql_audit(
                run_id,
                results,
                failures,
                object_name,
            )
        except Exception:
            logging.exception(
                "MySQL operational audit failed for run %s",
                run_id,
            )

        if failures:
            subject = f"AtmosData - Partial Weather Ingestion - {len(failures)} failures"
            body = (
                f"AtmosData weather ingestion completed with partial failures.\n\n"
                f"Run ID: {run_id}\n"
                f"Successful cities: {len(results)}\n"
                f"Failed cities: {len(failures)}\n"
                f"GCS object: gs://{BUCKET_NAME}/{object_name}\n\n"
                f"Failure details:\n"
                + "\n".join(
                    f"- {failure['city']}: {failure['error']}"
                    for failure in failures
                )
            )
        else:
            subject = "AtmosData - Weather Ingestion Successful"
            body = (
                "AtmosData weather ingestion completed successfully.\n\n"
                f"Run ID: {run_id}\n"
                f"Successful cities: {len(results)}\n"
                f"Failed cities: 0\n"
                f"GCS object: gs://{BUCKET_NAME}/{object_name}\n"
            )

        send_notification(subject, body)

        status_code = 207 if failures else 200

        return (
            {
                "status": "partial" if failures else "success",
                "run_id": run_id,
                "gcs_object": object_name,
                "successful_cities": len(results),
                "failed_cities": failures,
            },
            status_code,
        )

    except Exception as exc:
        logging.exception("Weather ingestion failed")

        send_notification(
            "AtmosData - Weather Ingestion FAILED",
            (
                f"Weather ingestion failed.\n\n"
                f"Run ID: {run_id}\n"
                f"Error: {str(exc)[:4000]}\n"
                "Inspect Cloud Logging for the complete traceback."
            ),
        )

        return (
            {
                "status": "error",
                "run_id": run_id,
                "message": (
                    "Weather ingestion failed; inspect Cloud Logging."
                ),
            },
            500,
        )
