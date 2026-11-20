import json
import logging
import os
from datetime import datetime, timezone

import functions_framework
from google.cloud import bigquery, storage

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "my-project-77-511616")
DATASET_ID = os.environ.get("BRONZE_DATASET", "weather_bronze_dev")
TABLE_ID = os.environ.get("BRONZE_TABLE", "weather_observations")
logging.basicConfig(level=logging.INFO)


def _insert_rows(records, bucket_name, object_name, generation):
    client = bigquery.Client(project=PROJECT_ID)
    table = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    rows = []
    for record in records:
        row = dict(record)
        row.update({
            "source_bucket": bucket_name,
            "source_object": object_name,
            "source_generation": str(generation),
            "loaded_at_utc": datetime.now(timezone.utc).isoformat(),
        })
        rows.append(row)
    errors = client.insert_rows_json(table, rows, row_ids=[
        f"{generation}-{i}" for i in range(len(rows))
    ])
    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors}")


@functions_framework.cloud_event
def load_gcs_to_bigquery(cloud_event):
    """Load a finalized GCS JSON object into the Bronze table."""
    data = cloud_event.data
    bucket_name = data["bucket"]
    object_name = data["name"]
    generation = data.get("generation", "unknown")

    if not object_name.endswith(".json") or not object_name.startswith("raw/weather/"):
        logging.info("Ignoring unrelated object: gs://%s/%s", bucket_name, object_name)
        return

    storage_client = storage.Client(project=PROJECT_ID)
    blob = storage_client.bucket(bucket_name).blob(object_name, generation=int(generation))
    payload = json.loads(blob.download_as_text())
    records = payload.get("records", [])
    if not records:
        logging.warning("No weather records found in %s", object_name)
        return

    _insert_rows(records, bucket_name, object_name, generation)
    logging.info("Loaded %s rows from gs://%s/%s", len(records), bucket_name, object_name)
