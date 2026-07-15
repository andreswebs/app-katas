variable "region" {
  type    = string
  default = "fra"
}

variable "plan" {
  type    = string
  default = "vhp-1c-1gb-amd"
}

variable "os_name" {
  type    = string
  default = "Ubuntu 26.04 LTS x64"
}

variable "ssh_key_name" {
  type    = string
  default = "default"
}
