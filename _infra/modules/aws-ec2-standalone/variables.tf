variable "cidr_whitelist_ipv4" {
  type    = list(string)
  default = []
}

variable "subnet_id" {
  type = string
}

variable "name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3a.small"
}
