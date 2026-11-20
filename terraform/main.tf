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
    "composer.googleapis.com"
  ])
}

resource "google_project_service" "apis" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

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

resource "google_secret_manager_secret" "weather_api" {
  secret_id = "openweather-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "gmail_password" {
  secret_id = "gmail-app-password"
  replication {
    auto {}
  }
}

resource "google_sql_database_instance" "mysql" {
  count            = var.enable_cloud_sql ? 1 : 0
  name             = "atmosdata-mysql-dev"
  region           = var.region
  database_version = "MYSQL_8_0"
  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_HDD"
    backup_configuration { enabled = true }
    ip_configuration { ipv4_enabled = false }
  }
  deletion_protection = true
  depends_on          = [google_project_service.apis]
}

output "raw_bucket_name" {
  value = google_storage_bucket.raw.name
}

output "bronze_dataset" { value = google_bigquery_dataset.bronze.dataset_id }
output "silver_dataset" { value = google_bigquery_dataset.silver.dataset_id }
output "gold_dataset" { value = google_bigquery_dataset.gold.dataset_id }
output "function_service_account" { value = google_service_account.functions.email }
