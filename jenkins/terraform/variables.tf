variable "external_access_ip_whitelist" {
  type    = list(string)
  default = []
}

variable "snapshot_name" {
  type = string
  default = null
}
