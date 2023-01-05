variable "project" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Main region for GCP project resources"
  default     = null
}

provider "google" {
  project = var.project
  region  = var.region
}
