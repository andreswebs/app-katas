terraform {
  required_version = "~> 1.11"

  required_providers {

    google = {
      source  = "hashicorp/google"
      version = "~> 4.43"
    }

  }
}
