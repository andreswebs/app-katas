variable "cidr_whitelist_ipv4" {
  type    = list(string)
  default = []
}

variable "vpc_id" {
  type = string
}

variable "pub_subnet_id" {
  type = string
}

variable "prv_subnet_id" {
  type = string
}
