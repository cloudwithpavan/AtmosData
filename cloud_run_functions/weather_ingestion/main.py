import json
import logging
import os
from datetime import datetime, timezone
from typing import Any

import functions_framework
import requests
from google.cloud import secretmanager, storage

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "my-project-77-511616")
BUCKET_NAME = os.environ["RAW_BUCKET_NAME"]
SECRET_NAME = os.environ.get("OPENWEATHER_SECRET_NAME", "openweather-api-key")
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
    return client.access_secret_version(request={"name": name}).payload.data.decode("utf-8").strip()


def fetch_weather(city: dict[str, Any], api_key: str) -> dict[str, Any]:
    response = requests.get(
        "https://api.openweathermap.org/data/2.5/weather",
        params={"lat": city["lat"], "lon": city["lon"], "appid": api_key, "units": "metric"},
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


@functions_framework.http
def ingest_weather(request):
    """Fetch weather for the configured cities and write one immutable JSON object per run."""
    try:
        api_key = get_secret(SECRET_NAME)
        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(BUCKET_NAME)
        run_time = datetime.now(timezone.utc)
        date_path = run_time.strftime("%Y/%m/%d")
        timestamp = run_time.strftime("%Y%m%dT%H%M%S%fZ")
        results, failures = [], []

        for city in CITIES:
            try:
                results.append(fetch_weather(city, api_key))
            except requests.RequestException as exc:
                logging.exception("Weather API failed for %s", city["name"])
                failures.append({"city": city["name"], "error": str(exc)})

        document = {
            "project": "AtmosData",
            "collection_timestamp_utc": run_time.isoformat(),
            "records": results,
            "failures": failures,
        }
        object_name = f"raw/weather/{date_path}/weather_{timestamp}.json"
        blob = bucket.blob(object_name)
        blob.upload_from_string(
            json.dumps(document, ensure_ascii=False),
            content_type="application/json",
            if_generation_match=0,
        )
        status = 207 if failures else 200
        return ({"status": "partial" if failures else "success",
                 "gcs_object": object_name,
                 "successful_cities": len(results),
                 "failed_cities": failures}, status)
    except Exception:
        logging.exception("Weather ingestion failed")
        return ({"status": "error", "message": "Weather ingestion failed; inspect Cloud Logging."}, 500)
