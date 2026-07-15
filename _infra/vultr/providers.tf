variable "vultr_api_key" {
  type      = string
  sensitive = true
}

provider "vultr" {
  api_key = var.vultr_api_key
}
