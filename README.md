# AtmosData

GCP weather data engineering project.

## Fixed configuration
- GCP project: `my-project-77-511616`
- Region: `asia-south1`
- Collection interval: 15 minutes
- Cities: Hyderabad, Bengaluru, Mumbai, Delhi, Chennai
- Weather provider: OpenWeatherMap
- Raw storage: Cloud Storage
- Warehouse: BigQuery Bronze / Silver / Gold
- Orchestration: Airflow / Cloud Composer
- Event loading: GCS finalized event → Eventarc → Cloud Run Function
- Operational metadata: Cloud SQL for MySQL (optional deployment switch)
- Email: Gmail SMTP, credentials in Secret Manager

## Important security rules
Never commit API keys, Gmail App Passwords, service-account keys, `.env` files, Terraform state, or secrets.
The Gmail App Password previously pasted into chat must be revoked. Create a new one only when configuring Secret Manager.

## Deployment strategy
This repository is a deployable starter baseline, not a claim that cloud resources have already been tested in your account. Deploy in phases and validate each phase before proceeding.

1. Bootstrap the Terraform state bucket separately.
2. Run Terraform plan and review costs.
3. Deploy functions and configure Eventarc.
4. Develop/test Airflow DAGs locally. Composer is disabled by default because it can consume significant credits even while idle.
5. Configure Secret Manager values manually through secure terminal input.
6. Run integration tests and validate end-to-end.

## Required local tools
- Google Cloud CLI
- Terraform
- Python 3.11+
- Git
- A Google Cloud project with billing enabled

## Python setup (PowerShell)
```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
```

## GCP setup (PowerShell)
```powershell
gcloud auth login
gcloud config set project my-project-77-511616
gcloud auth application-default login
gcloud auth application-default set-quota-project my-project-77-511616
```

## Terraform
```powershell
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```
Do not run `terraform apply` until you review the plan and estimated costs.

## Secrets
Create Secret Manager secrets for:
- `openweather-api-key`
- `gmail-app-password`

Do not place secret values in this repository. Use `gcloud secrets versions add` with a secure input workflow; avoid command-line literals that end up in shell history.

## Data flow
OpenWeatherMap → Airflow DAG → `weather-ingestion` → GCS raw JSON → Eventarc → `weather-gcs-to-bq` → BigQuery Bronze → Silver SQL → Gold SQL → Looker Studio.

The Eventarc-triggered loader is the only component that loads new raw objects into Bronze. Airflow coordinates the pipeline and runs transformations; it must not duplicate the GCS-to-Bronze load.
