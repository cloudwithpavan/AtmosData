
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "my-project-77-511616"
  region  = "asia-south1"
}

resource "google_storage_bucket" "terraform_state" {
  name                        = "atmosdata-tfstate-dev-802327721598"
  location                    = "asia-south1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
}
