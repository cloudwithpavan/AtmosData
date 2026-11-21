# ðŸŒ¦ï¸ AtmosData â€” India Weather Intelligence & Analytics Platform

<p align="center">
  <strong>End-to-End GCP Data Engineering Project</strong><br>
  Automated Weather Ingestion | Event-Driven Processing | BigQuery | Airflow | MySQL | Looker Studio
</p>

<p align="center">
  ![GCP](https://img.shields.io/badge/Cloud-Google%20Cloud-blue?logo=googlecloud)
  ![Python](https://img.shields.io/badge/Language-Python-3776AB?logo=python)
  ![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
  ![BigQuery](https://img.shields.io/badge/Warehouse-BigQuery-4285F4?logo=googlebigquery)
  ![Airflow](https://img.shields.io/badge/Orchestration-Apache%20Airflow-017CEE?logo=apacheairflow)
</p>

---

## ðŸ“Œ 1. Project Overview

**AtmosData** is an end-to-end cloud-native data engineering platform built on Google Cloud Platform (GCP).

The platform collects weather observations from the OpenWeatherMap API for five major Indian cities, stores raw JSON data in Google Cloud Storage, processes the data through BigQuery Bronze, Silver and Gold layers, and presents analytical insights through a Looker Studio dashboard.

The pipeline uses Cloud Composer (Apache Airflow), Cloud Scheduler, Cloud Run Functions and Eventarc for automated orchestration and event-driven processing.

It also implements two UPSERT operations, Slowly Changing Dimension Type 2 (SCD Type 2), MySQL operational logging, Gmail notifications, Cloud Monitoring, Terraform infrastructure provisioning and GitHub Actions CI/CD.

### Cities Covered

| City | Country |
|---|---|
| Hyderabad | India |
| Bengaluru | India |
| Mumbai | India |
| Delhi | India |
| Chennai | India |

### Project Objectives

- Automate weather data collection every 15 minutes.
- Store raw API responses in Google Cloud Storage.
- Implement event-driven ingestion into BigQuery.
- Build Bronze, Silver and Gold warehouse layers.
- Implement two UPSERT operations using BigQuery MERGE.
- Implement SCD Type 2 historical dimension tracking.
- Orchestrate the pipeline using Apache Airflow.
- Maintain operational audit records in MySQL.
- Send pipeline success and failure notifications through Gmail.
- Monitor application errors through Cloud Monitoring.
- Visualize analytical data using Looker Studio.
- Automate infrastructure and application deployments through Terraform and GitHub Actions.

---

## ðŸ—ï¸ 2. End-to-End Architecture

### Overall GCP Architecture

```mermaid
flowchart TD
    A["OpenWeatherMap API"] --> B["Cloud Scheduler"]
    B --> C["Cloud Composer / Airflow"]
    C --> D["Cloud Run Function 1<br/>Weather Ingestion"]
    D --> E["Google Cloud Storage<br/>Raw JSON"]
    E --> F["Eventarc"]
    F --> G["Cloud Run Function 2<br/>GCS to BigQuery"]
    G --> H["BigQuery Bronze"]
    H --> I["Airflow Bronze Validation"]
    I --> J["BigQuery Silver"]
    J --> K["BigQuery Gold"]
    K --> L["Looker Studio Dashboard"]
    D --> M["Cloud SQL MySQL<br/>Operational Audit"]
    D --> N["Gmail Notifications"]
    C --> O["Cloud Monitoring"]
```

### Automated Pipeline Execution

```mermaid
flowchart TD
    A["Every 15 Minutes"] --> B["Cloud Scheduler"]
    B --> C["Trigger Airflow DAG"]
    C --> D["Fetch Weather for 5 Cities"]
    D --> E["Archive JSON in GCS"]
    E --> F["Eventarc Trigger"]
    F --> G["Load BigQuery Bronze"]
    G --> H["Validate Bronze Records"]
    H --> I["Silver Transformation"]
    I --> J["Gold Transformation"]
    J --> K["Operational Logging"]
    K --> L["Email Notification"]
    J --> M["Looker Studio"]
```

Cloud Scheduler is the recurring trigger. The Airflow DAG uses `schedule=None` because Cloud Scheduler triggers it through the Composer API. This avoids duplicate 15-minute scheduling.

### BigQuery Medallion Architecture

```mermaid
flowchart TD
    A["Raw Weather JSON<br/>GCS"] --> B["BRONZE"]
    B --> C["Raw Weather Observations"]
    C --> D["SILVER"]
    D --> E["Cleaned and Standardized Observations"]
    E --> F["GOLD"]
    F --> G["Daily City Weather Summary"]
    F --> H["City Dimension"]
    H --> I["SCD Type 2 Historical Records"]
    G --> J["Looker Studio"]
    I --> J
```

---

## âš™ï¸ 3. Technology Stack

| Category | Technology |
|---|---|
| Cloud Platform | Google Cloud Platform |
| Programming | Python |
| Weather API | OpenWeatherMap |
| Infrastructure as Code | Terraform |
| CI/CD | GitHub Actions |
| Object Storage | Google Cloud Storage |
| Serverless Compute | Cloud Run Functions |
| Event Processing | Eventarc |
| Data Warehouse | BigQuery |
| Data Orchestration | Cloud Composer / Apache Airflow |
| Operational Database | Cloud SQL MySQL 8.4 |
| Scheduling | Cloud Scheduler |
| Notifications | Gmail SMTP |
| Monitoring | Cloud Monitoring |
| Visualization | Looker Studio |

---

## ðŸ“¥ 4. Bronze Layer â€” Raw Data Ingestion

The Bronze layer captures weather data from the API and retains the original source information.

### Processing Flow

1. Airflow invokes the weather ingestion Cloud Run Function.
2. The function fetches weather information for five cities.
3. Raw JSON responses are archived in GCS.
4. Eventarc detects newly finalized GCS objects.
5. The GCS-to-BigQuery function loads observations into Bronze.

**GCS Bucket:** `weatherpulse-raw-dev-802327721598`

**BigQuery Dataset:** `weather_bronze_dev`

### GCS Raw Bucket Evidence

![GCS Raw Bucket](docs/outputs/gcs%20bucket%20raw.png)

### Bronze Table Evidence

![BigQuery Bronze Table](docs/outputs/table%20bronze.png)

---

## ðŸ¥ˆ 5. Silver Layer â€” Data Transformation and UPSERT

The Silver layer contains cleaned and standardized weather observations.

The transformation uses BigQuery SQL and a MERGE-based UPSERT pattern.

### Silver UPSERT Logic

The UPSERT operation combines INSERT and UPDATE behavior:

- If a matching record exists, the existing record is updated.
- If no matching record exists, a new record is inserted.
- MERGE matching conditions determine the appropriate action.
- Incremental processing helps maintain the target table without unnecessarily inserting duplicate matching records.

**BigQuery Dataset:** `weather_silver_dev`

### Silver Transformation Evidence

![Silver Transformation](docs/outputs/silver%20layer%20transformation.png)

![Silver Layer Output](docs/outputs/silver%20layer%202.png)

### Silver UPSERT â€” Logic and Execution Evidence

![Silver UPSERT Logic](docs/outputs/UPSERT%20Logic%20-%20silver.png)

---

## ðŸ¥‡ 6. Gold Layer â€” Analytical Data and UPSERT

The Gold layer contains business-ready analytical data used by the Looker Studio dashboard.

**BigQuery Dataset:** `weather_gold_dev`

**Main Table:** `daily_city_weather`

### Gold Table Structure

| Column | Description |
|---|---|
| weather_date | Weather observation date |
| city | City name |
| avg_temperature_c | Average temperature |
| min_temperature_c | Minimum temperature |
| max_temperature_c | Maximum temperature |
| avg_humidity_pct | Average humidity |
| observation_count | Number of observations |
| refreshed_at_utc | Last refresh timestamp |

### Gold UPSERT Logic

The Gold transformation performs a second UPSERT using BigQuery MERGE.

- Matches records using the target business key.
- Updates existing daily city summaries.
- Inserts new city/date combinations.
- Maintains the analytical summary table as new data arrives.

### Gold UPSERT â€” Logic and Execution Evidence

![Gold UPSERT Logic](docs/outputs/UPSERT%20Logic%20gold.png)

### Gold MERGE Execution Evidence

![Gold MERGE Execution](docs/outputs/gold%20merge.png)

![Gold MERGE Second Execution](docs/outputs/gold%20merge%202.png)

### Gold Data Verification

![Gold Layer Record Count Verification](docs/outputs/gold%20layer%20count%20verify.png)

---

## ðŸ” 7. Slowly Changing Dimension Type 2 (SCD Type 2)

AtmosData implements SCD Type 2 to preserve historical changes in the city dimension rather than overwriting previous attribute values.

### SCD Type 2 Implementation

The implementation maintains:

- Historical versions of dimension records.
- Effective start dates.
- Effective end dates.
- A current-record indicator (`is_current`).
- Previous values for historical analysis.

When a tracked attribute changes, the previous version is retained and a new current version is created.

### SCD Type 2 Processing

```mermaid
flowchart TD
    A["Existing City Dimension"] --> B["Detect Attribute Change"]
    B --> C["Expire Previous Record"]
    C --> D["Set Previous Record as Not Current"]
    D --> E["Insert New Dimension Version"]
    E --> F["Set New Record as Current"]
    F --> G["Preserve Historical Versions"]
```

### SCD Type 2 â€” Logic Evidence

![SCD Type 2 Implementation](docs/outputs/SCD%20type%202.png)

### City Record Version Evidence

![City Record Versions](docs/outputs/city%20record%20versions.png)

### Historical Version Verification

![Historical Version Verification](docs/outputs/verfication%20historical%20versions.png)

---

## â˜ï¸ 8. Infrastructure as Code â€” Terraform

Terraform is used to provision and manage GCP infrastructure.

The infrastructure includes:

- GCP APIs and IAM permissions.
- Service accounts.
- GCS raw storage bucket.
- BigQuery datasets.
- Cloud Run Functions.
- Eventarc configuration.
- Cloud SQL MySQL.
- Cloud Composer.
- Cloud Scheduler.
- Cloud Monitoring resources.

### Terraform Deployment Evidence

![Terraform GitHub Actions Deployment Success](docs/outputs/TerraformGitHub%20Actions%20deployment%20success.png)

![Terraform Apply Evidence](docs/outputs/real%20logic%20apply.png)

### IAM Access and Approval Evidence

![IAM Access Configuration](docs/outputs/approval%20Acess.png)

---

## ðŸš€ 9. CI/CD â€” GitHub Actions

GitHub Actions automates infrastructure and application deployments.

### Terraform CD

The infrastructure workflow:

1. Initializes Terraform.
2. Validates Terraform configuration.
3. Generates a Terraform plan.
4. Checks for unintended resource deletions.
5. Requires approval before applying the saved plan.
6. Applies the approved infrastructure changes.

### Application CD

The application workflow:

1. Deploys the weather ingestion function.
2. Deploys the GCS-to-BigQuery function.
3. Configures Eventarc integration.
4. Uploads Airflow DAG files.
5. Uploads dependent SQL files to Composer.

### Application Deployment Evidence

![Application CD Workflow](docs/outputs/application%20cd%20workflow.png)

![Application CD Deployment](docs/outputs/application%20cd.png)

---

## ðŸ”„ 10. Cloud Composer and Apache Airflow

Cloud Composer hosts the Airflow environment responsible for coordinating the data pipeline.

**DAG ID:** `atmosdata_weather_pipeline`

**Trigger Frequency:** Every 15 minutes through Cloud Scheduler.

### Airflow DAG Tasks

1. Invoke weather ingestion.
2. Validate Bronze records.
3. Execute Silver transformation.
4. Execute Gold transformation.

The ingestion function also performs MySQL audit logging and Gmail notification handling.

### Airflow Execution Evidence

![Airflow Pipeline Runs](docs/outputs/Pipeline%20Runs.png)

---

## ðŸ—„ï¸ 11. MySQL Operational Database

Cloud SQL MySQL 8.4 is used as the operational database.

**Database:** `atmosdata_ops`

Operational tables:

| Table | Purpose |
|---|---|
| `city_master` | City master data |
| `error_log` | Application error tracking |
| `ingestion_audit` | Ingestion audit records |
| `pipeline_audit` | Pipeline execution tracking |

MySQL provides operational visibility and supports pipeline auditing and troubleshooting.

---

## ðŸ“§ 12. Gmail Notifications

Gmail SMTP is integrated into the ingestion process.

Notifications support:

- Successful ingestion.
- Partial ingestion.
- Failed ingestion.

Credentials are stored in Secret Manager rather than hardcoded in application source code.

### Email Notification Evidence

![Gmail Notification](docs/outputs/email%20notification.png)

---

## ðŸ“Š 13. Looker Studio â€” India Weather Intelligence Dashboard

The Looker Studio dashboard connects to the BigQuery Gold layer.

### Dashboard KPIs and Visualizations

- Average Temperature.
- Average Humidity.
- Total Cities.
- Latest Data Refresh.
- Daily Average Temperature by City.
- Minimum vs Maximum Temperature by City.
- Average Humidity by City.
- Daily Weather Observation Count.
- Date range filter.
- City dropdown filter.

### Dashboard Preview

![AtmosData Looker Studio Dashboard](docs/outputs/looker%20dashboard.png)

---

## ðŸš¨ 14. Monitoring and Alerting

Cloud Monitoring is configured with the alert policy:

`AtmosData - Cloud Run HTTP 5xx Errors`

The alert policy monitors Cloud Run HTTP 5xx errors and helps identify application failures.

---

## ðŸ“ 15. Repository Structure

```text
AtmosData/
â”‚
â”œâ”€â”€ .github/
â”‚   â””â”€â”€ workflows/
â”‚       â”œâ”€â”€ terraform-cd.yml
â”‚       â””â”€â”€ application-cd.yml
â”‚
â”œâ”€â”€ airflow/
â”‚   â””â”€â”€ dags/
â”‚       â”œâ”€â”€ atmosdata_weather_pipeline.py
â”‚       â””â”€â”€ sql/
â”‚           â”œâ”€â”€ silver/
â”‚           â”‚   â””â”€â”€ transform_weather.sql
â”‚           â””â”€â”€ gold/
â”‚               â””â”€â”€ build_daily_city_summary.sql
â”‚
â”œâ”€â”€ cloud_run_functions/
â”‚   â”œâ”€â”€ weather_ingestion/
â”‚   â”œâ”€â”€ gcs_to_bigquery/
â”‚   â””â”€â”€ email_notification/
â”‚
â”œâ”€â”€ mysql/
â”‚   â””â”€â”€ tables/
â”‚       â””â”€â”€ 001_operational_tables.sql
â”‚
â”œâ”€â”€ sql/
â”‚   â”œâ”€â”€ bronze/
â”‚   â”œâ”€â”€ silver/
â”‚   â””â”€â”€ gold/
â”‚
â”œâ”€â”€ terraform/
â”‚   â”œâ”€â”€ main.tf
â”‚   â”œâ”€â”€ variables.tf
â”‚   â””â”€â”€ outputs.tf
â”‚
â”œâ”€â”€ docs/
â”‚   â””â”€â”€ outputs/
â”‚       â”œâ”€â”€ application cd workflow.png
â”‚       â”œâ”€â”€ application cd.png
â”‚       â”œâ”€â”€ approval Acess.png
â”‚       â”œâ”€â”€ city record versions.png
â”‚       â”œâ”€â”€ email notification.png
â”‚       â”œâ”€â”€ gcs bucket raw.png
â”‚       â”œâ”€â”€ gold layer count verify.png
â”‚       â”œâ”€â”€ gold merge 2.png
â”‚       â”œâ”€â”€ gold merge.png
â”‚       â”œâ”€â”€ Looker dashboard.png
â”‚       â”œâ”€â”€ Pipeline Runs.png
â”‚       â”œâ”€â”€ real logic apply.png
â”‚       â”œâ”€â”€ SCD type 2.png
â”‚       â”œâ”€â”€ silver layer 2.png
â”‚       â”œâ”€â”€ silver layer transformation.png
â”‚       â”œâ”€â”€ table bronze.png
â”‚       â”œâ”€â”€ TerraformGitHub Actions deployment success.png
â”‚       â”œâ”€â”€ UPSERT Logic - silver.png
â”‚       â”œâ”€â”€ UPSERT Logic gold.png
â”‚       â””â”€â”€ verfication historical versions.png
â”‚
â””â”€â”€ README.md
```

---

## ðŸ” 16. Security and Configuration

- Secret Manager stores sensitive API and database credentials.
- Dedicated service accounts are used for cloud workloads.
- IAM permissions are configured for individual workloads.
- Terraform state is stored in a remote GCS bucket.
- GitHub Actions uses controlled deployment permissions.
- Terraform CD includes a safeguard against unintended resource deletions.

---

## ðŸ’° 17. Cost Management

Some GCP resources incur charges even when the pipeline is idle.

Cloud Composer is particularly important to monitor because its environment continues to incur costs while running.

For temporary development environments, Composer can be removed through a carefully reviewed Terraform deployment and recreated later. Shared resources such as GCS, BigQuery datasets and Cloud SQL must be preserved.

---

## ðŸŽ¯ 18. Project Outcomes

AtmosData demonstrates practical implementation of:

- End-to-end GCP data engineering.
- API-based weather ingestion.
- Event-driven data processing.
- GCS and BigQuery integration.
- Bronze, Silver and Gold data warehouse architecture.
- Two BigQuery UPSERT operations.
- SCD Type 2 historical dimension management.
- Python-based serverless functions.
- Cloud Composer and Apache Airflow orchestration.
- Cloud Scheduler automation.
- MySQL operational auditing.
- Gmail notifications.
- Terraform infrastructure provisioning.
- GitHub Actions CI/CD.
- Cloud Monitoring and alerting.
- Looker Studio dashboard development.

---

## ðŸ‘¨â€ðŸ’» Author

**Pavan Kumar Gummadi**

GCP Data Engineering | BigQuery | Python | SQL | Terraform | Apache Airflow | Cloud Composer

GitHub: [cloudwithpavan](https://github.com/cloudwithpavan)

Project Repository: [AtmosData](https://github.com/cloudwithpavan/AtmosData)










