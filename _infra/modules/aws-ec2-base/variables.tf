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

variable "extra_ingress_rules" {
  type = list(object({
    from_port   = string
    to_port     = string
    ip_protocol = optional(string, "tcp")
  }))

  default = []
}
