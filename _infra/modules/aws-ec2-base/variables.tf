variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_key_name" {
  type    = string
  default = ""
}

variable "cidr_whitelist" {
  type = list(string)
}
