variable "hetzner_token" {
  type      = string
  sensitive = true
}

provider "hcloud" {
  token  = var.hetzner_token
}
