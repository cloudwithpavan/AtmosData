# Deployment checklist

- [ ] Revoke exposed Gmail App Password and generate a new one.
- [ ] Confirm GCP billing and remaining trial credits.
- [ ] Create GitHub repository and push this scaffold.
- [ ] Bootstrap remote Terraform state bucket separately.
- [ ] Set unique raw bucket name in `terraform/terraform.tfvars`.
- [ ] Run `terraform fmt`, `validate`, and `plan`.
- [ ] Review costs and IAM grants before apply.
- [ ] Add OpenWeatherMap API key and Gmail App Password to Secret Manager.
- [ ] Deploy functions and configure Eventarc.
- [ ] Create Bronze table using SQL script.
- [ ] Test one ingestion and verify Eventarc load.
- [ ] Test Silver and Gold SQL in BigQuery.
- [ ] Develop DAG locally; configure Airflow connection before deploying.
- [ ] Review Composer and Cloud SQL costs before enabling either.
