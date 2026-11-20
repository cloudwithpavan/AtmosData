# AtmosData architecture

1. Airflow runs every 15 minutes and invokes the weather ingestion function.
2. The ingestion function retrieves the OpenWeatherMap key from Secret Manager, fetches five cities, and writes a unique JSON object to GCS.
3. GCS object-finalized events invoke the loader function through Eventarc.
4. The loader writes records to BigQuery Bronze.
5. Airflow runs idempotent Silver and Gold SQL transformations.
6. Cloud SQL MySQL stores operational metadata when enabled.
7. Gmail notifications use SMTP credentials read from Secret Manager.
8. Looker Studio reads the Gold dataset.

Eventarc is the only GCS-to-Bronze loader. Airflow must not independently load the same files.
