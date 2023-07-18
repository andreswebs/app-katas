variable "name" {
  type        = string
  description = "server and app name"
}

variable "ssh_key_name" {
  type        = string
  description = "ssh key name"
  default     = "default"
}

variable "image" {
  type        = string
  description = "server image"
  default     = "ubuntu-22.04"
}

variable "server_type" {
  type        = string
  description = "server type"
  default     = "cx21"
}
