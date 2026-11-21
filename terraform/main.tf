
provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  required_apis = toset([
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sqladmin.googleapis.com",
    "composer.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])
}

# ---------------------------------------------------------
# Enable Google Cloud APIs
# ---------------------------------------------------------

resource "google_project_service" "apis" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------
# GCS Raw Data Lake
# ---------------------------------------------------------

resource "google_storage_bucket" "raw" {
  name                        = var.raw_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = 365
    }

    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------
# BigQuery Datasets
# ---------------------------------------------------------

resource "google_bigquery_dataset" "bronze" {
  dataset_id                 = "weather_bronze_dev"
  location                   = var.region
  delete_contents_on_destroy = false
}

resource "google_bigquery_dataset" "silver" {
  dataset_id                 = "weather_silver_dev"
  location                   = var.region
  delete_contents_on_destroy = false
}

resource "google_bigquery_dataset" "gold" {
  dataset_id                 = "weather_gold_dev"
  location                   = var.region
  delete_contents_on_destroy = false
}

# ---------------------------------------------------------
# Cloud Run Functions Service Account
# ---------------------------------------------------------

resource "google_service_account" "functions" {
  account_id   = "atmosdata-functions"
  display_name = "AtmosData Cloud Run Functions"
}

resource "google_project_iam_member" "function_storage" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

resource "google_project_iam_member" "function_secret" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

resource "google_project_iam_member" "function_bq" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

# ---------------------------------------------------------
# Secret Manager
# ---------------------------------------------------------

resource "google_secret_manager_secret" "weather_api" {
  secret_id = "openweather-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "gmail_password" {
  secret_id = "gmail-app-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}


# ---------------------------------------------------------
# Optional Cloud SQL MySQL - Phase 9
# ---------------------------------------------------------

resource "google_sql_database_instance" "mysql" {
  count            = var.enable_cloud_sql ? 1 : 0
  name             = "atmosdata-mysql-dev"
  region           = var.region
  database_version = "MYSQL_8_4"

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_HDD"

    backup_configuration {
      enabled = true
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }

  deletion_protection = true

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------
# MySQL database and application credentials - Phase 9
# ---------------------------------------------------------

resource "random_password" "mysql" {
  count            = var.enable_cloud_sql ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_database" "atmosdata_ops" {
  count    = var.enable_cloud_sql ? 1 : 0
  name     = "atmosdata_ops"
  instance = google_sql_database_instance.mysql[0].name
}

resource "google_sql_user" "app" {
  count    = var.enable_cloud_sql ? 1 : 0
  name     = "atmosdata_app"
  instance = google_sql_database_instance.mysql[0].name
  password = random_password.mysql[0].result
  host     = "%"
}

resource "google_secret_manager_secret" "mysql_password" {
  count     = var.enable_cloud_sql ? 1 : 0
  secret_id = "atmosdata-mysql-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mysql_password" {
  count       = var.enable_cloud_sql ? 1 : 0
  secret      = google_secret_manager_secret.mysql_password[0].id
  secret_data = random_password.mysql[0].result
}

# Cloud SQL connection permission
resource "google_project_iam_member" "functions_cloudsql_client" {
  count   = var.enable_cloud_sql ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

# MySQL password access permission
resource "google_secret_manager_secret_iam_member" "mysql_password_accessor" {
  count     = var.enable_cloud_sql ? 1 : 0
  project   = var.project_id
  secret_id = google_secret_manager_secret.mysql_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.functions.email}"
}


# =========================================================
# PHASE 6 - CLOUD COMPOSER 3 / AIRFLOW
# =========================================================

resource "google_service_account" "composer" {
  count        = var.enable_composer ? 1 : 0
  account_id   = "atmosdata-composer"
  display_name = "AtmosData Composer Service Account"
}

resource "google_project_iam_member" "composer_worker" {
  count   = var.enable_composer ? 1 : 0
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer[0].email}"
}

resource "google_project_iam_member" "composer_bq_job" {
  count   = var.enable_composer ? 1 : 0
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.composer[0].email}"
}

resource "google_project_iam_member" "composer_bq_data" {
  count   = var.enable_composer ? 1 : 0
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.composer[0].email}"
}

resource "google_project_iam_member" "composer_run_invoker" {
  count   = var.enable_composer ? 1 : 0
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.composer[0].email}"
}

resource "google_composer_environment" "atmosdata" {
  count  = var.enable_composer ? 1 : 0
  name   = var.composer_environment_name
  region = var.region

  config {
    environment_size = "ENVIRONMENT_SIZE_SMALL"

    software_config {
      image_version = "composer-3-airflow-2"
    }

    workloads_config {
      scheduler {
        cpu        = 0.5
        memory_gb  = 2
        storage_gb = 1
        count      = 1
      }

      dag_processor {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 1
        count      = 1
      }

      triggerer {
        cpu       = 0.5
        memory_gb = 1
        count     = 1
      }

      web_server {
        cpu        = 0.5
        memory_gb  = 2
        storage_gb = 1
      }

      worker {
        cpu        = 0.5
        memory_gb  = 2
        storage_gb = 1
        min_count  = 1
        max_count  = 2
      }
    }

    node_config {
      service_account = google_service_account.composer[0].email
    }
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.composer_worker,
    google_project_iam_member.composer_bq_job,
    google_project_iam_member.composer_bq_data,
    google_project_iam_member.composer_run_invoker
  ]
}

# =========================================================
# PHASE 6 - CLOUD SCHEDULER
# =========================================================

resource "google_service_account" "scheduler" {
  count        = var.enable_composer ? 1 : 0
  account_id   = "atmosdata-scheduler"
  display_name = "AtmosData Cloud Scheduler Service Account"
}

resource "google_project_iam_member" "scheduler_composer_access" {
  count   = var.enable_composer ? 1 : 0
  project = var.project_id
  role    = "roles/composer.user"
  member  = "serviceAccount:${google_service_account.scheduler[0].email}"
}

resource "google_cloud_scheduler_job" "atmosdata_pipeline" {
  count       = var.enable_composer ? 1 : 0
  name        = "atmosdata-weather-pipeline-15min"
  description = "Trigger AtmosData Airflow DAG every 15 minutes"
  region      = var.region
  schedule    = "*/15 * * * *"
  time_zone   = var.scheduler_timezone

  retry_config {
    retry_count = 0
  }

  http_target {
    http_method = "POST"

    uri = "https://composer.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/environments/${var.composer_environment_name}:executeAirflowCommand"

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      command    = "dags"
      subcommand = "trigger"
      parameters = ["atmosdata_weather_pipeline"]
    }))

    oauth_token {
      service_account_email = google_service_account.scheduler[0].email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.scheduler_composer_access,
    google_composer_environment.atmosdata
  ]
}

# ---------------------------------------------------------
# Terraform Outputs
# ---------------------------------------------------------

output "raw_bucket_name" {
  value = google_storage_bucket.raw.name
}

output "bronze_dataset" {
  value = google_bigquery_dataset.bronze.dataset_id
}

output "silver_dataset" {
  value = google_bigquery_dataset.silver.dataset_id
}

output "gold_dataset" {
  value = google_bigquery_dataset.gold.dataset_id
}

output "function_service_account" {
  value = google_service_account.functions.email
}

output "composer_airflow_uri" {
  value = var.enable_composer ? google_composer_environment.atmosdata[0].config[0].airflow_uri : null
}

output "composer_dag_bucket" {
  value = var.enable_composer ? google_composer_environment.atmosdata[0].config[0].dag_gcs_prefix : null
}

output "scheduler_job_name" {
  value = var.enable_composer ? google_cloud_scheduler_job.atmosdata_pipeline[0].name : null
}

# =========================================================
# PHASE 11 - CLOUD MONITORING ALERTS
# =========================================================

resource "google_monitoring_notification_channel" "email" {
  for_each = toset([
    "pavankumargummadi77@gmail.com",
    "jeevanmarygummadi@gmail.com"
  ])

  display_name = "AtmosData Alert - ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }
}

resource "google_monitoring_alert_policy" "cloud_run_errors" {
  display_name = "AtmosData - Cloud Run HTTP 5xx Errors"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud Run HTTP 5xx responses"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloud_run_revision\"",
        "metric.type = \"run.googleapis.com/request_count\"",
        "metric.labels.response_code_class = \"5xx\""
      ])

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    for channel in google_monitoring_notification_channel.email : channel.name
  ]

  documentation {
    mime_type = "text/markdown"
    content   = "AtmosData Cloud Run function returned HTTP 5xx responses. Check Cloud Run logs and ingestion execution."
  }

  depends_on = [google_project_service.apis]
}