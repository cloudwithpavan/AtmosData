
terraform {
  required_version = ">= 1.6.0"

  backend "gcs" {
    bucket = "atmosdata-tfstate-dev-802327721598"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
