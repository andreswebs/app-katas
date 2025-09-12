variable "external_access_ip_whitelist" {
  type    = list(string)
  default = []
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "name" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "dns_reverse_zone_name" {
  type = string
}

variable "dns_zone_name" {
  type = string
}
