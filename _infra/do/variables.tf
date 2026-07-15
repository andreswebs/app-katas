variable "region" {
  type    = string
  default = "fra1"
}

variable "size" {
  type    = string
  default = "s-1vcpu-1gb-amd"
}

variable "image" {
  type    = string
  default = "ubuntu-26-04-x64"
}

variable "ssh_key_name" {
  type    = string
  default = "default"
}
