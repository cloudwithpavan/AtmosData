
# AtmosData - Terraform Backend Bootstrap

This configuration creates a dedicated Google Cloud Storage bucket
for storing Terraform remote state.

## State Bucket

atmosdata-tfstate-dev-802327721598

## Purpose

- Store Terraform state remotely.
- Enable object versioning.
- Enforce uniform bucket-level access.
- Prevent public access.
- Keep Terraform state separate from weather raw data.

## Deployment

Run from the repository root:

```powershell
terraform -chdir=terraform/backend-bootstrap init
terraform -chdir=terraform/backend-bootstrap apply
```

The state bucket is created separately before configuring
the main Terraform remote backend.
