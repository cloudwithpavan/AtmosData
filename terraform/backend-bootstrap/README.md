# Terraform state bucket bootstrap

Create a globally unique GCS bucket for Terraform state in a separate one-time bootstrap configuration, then configure the main Terraform backend and run `terraform init -migrate-state`.

Do not configure the main backend to use a bucket that the same main state is responsible for creating. Keep state bucket separate from the raw weather bucket. Enable object versioning and uniform bucket-level access on the state bucket. Restrict access to the deployment identity.
