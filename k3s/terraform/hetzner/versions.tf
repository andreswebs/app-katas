terraform {
  required_version = "~> 1.3"

  required_providers {

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.41"
    }

  }
}
