
import hashlib
import json
import logging
import os
from datetime import datetime, timezone

import functions_framework
from google.cloud import bigquery, storage

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "my-project-77-511616")
DATASET_ID = os.environ.get("BRONZE_DATASET", "weather_bronze_dev")
TABLE_ID = os.environ.get("BRONZE_TABLE", "weather_observations")
RAW_BUCKET_NAME = os.environ.get(
    "RAW_BUCKET_NAME",
    "weatherpulse-raw-dev-802327721598",
)

logging.basicConfig(level=logging.INFO)

REQUIRED_FIELDS = {
    "city",
    "latitude",
    "longitude",
    "observed_at_utc",
    "provider_timestamp",
    "temperature_c",
    "feels_like_c",
    "humidity_pct",
    "pressure_hpa",
    "weather_main",
    "weather_description",
    "wind_speed_mps",
    "cloudiness_pct",
}


def _insert_rows(records, bucket_name, object_name, generation):
    client = bigquery.Client(project=PROJECT_ID)
    table = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

    loaded_at = datetime.now(timezone.utc).isoformat()
    rows = []
    row_ids = []

    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"Record {index} is not a JSON object")

        missing = REQUIRED_FIELDS - record.keys()
        if missing:
            raise ValueError(
                f"Record {index} is missing fields: {sorted(missing)}"
            )

        row = dict(record)
        row.update({
            "source_bucket": bucket_name,
            "source_object": object_name,
            "source_generation": str(generation),
            "loaded_at_utc": loaded_at,
        })
        rows.append(row)

        identity = f"{bucket_name}/{object_name}#{generation}#{index}"
        row_ids.append(hashlib.sha256(identity.encode("utf-8")).hexdigest())

    errors = client.insert_rows_json(
        table,
        rows,
        row_ids=row_ids,
    )

    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors}")

    return len(rows)


@functions_framework.cloud_event
def load_gcs_to_bigquery(cloud_event):
    """Load a finalized GCS weather JSON object into BigQuery Bronze."""

    try:
        data = cloud_event.data

        bucket_name = data.get("bucket")
        object_name = data.get("name")
        generation = data.get("generation")

        if not bucket_name or not object_name or generation is None:
            raise ValueError("Event is missing bucket, object name, or generation")

        if bucket_name != RAW_BUCKET_NAME:
            logging.info("Ignoring unexpected bucket: %s", bucket_name)
            return

        if not object_name.startswith("raw/weather/") or not object_name.endswith(".json"):
            logging.info("Ignoring unrelated object: gs://%s/%s",
                         bucket_name, object_name)
            return

        generation = int(generation)

        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(object_name, generation=generation)

        payload = json.loads(blob.download_as_text())

        if not isinstance(payload, dict):
            raise ValueError("Weather JSON payload must be an object")

        records = payload.get("records", [])

        if not isinstance(records, list):
            raise ValueError("'records' must be a JSON array")

        if not records:
            logging.warning(
                "No weather records found in gs://%s/%s",
                bucket_name,
                object_name,
            )
            return

        inserted = _insert_rows(
            records,
            bucket_name,
            object_name,
            generation,
        )

        logging.info(
            "Loaded %s rows from gs://%s/%s generation %s",
            inserted,
            bucket_name,
            object_name,
            generation,
        )

    except Exception:
        logging.exception("GCS to BigQuery loading failed")
        raise
