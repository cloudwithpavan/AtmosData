variable "project_id" {
  type    = string
  default = "my-project-77-511616"
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "raw_bucket_name" {
  type        = string
  description = "Globally unique bucket name. Keep the AtmosData prefix."
}

variable "enable_cloud_sql" {
  type        = bool
  default     = false
  description = "Cloud SQL costs money while provisioned."
}

variable "enable_composer" {
  type        = bool
  default     = false
  description = "Enable Cloud Composer after cost review."
}

variable "composer_environment_name" {
  type    = string
  default = "atmosdata-composer-dev"
}

variable "scheduler_timezone" {
  type    = string
  default = "Asia/Kolkata"
}