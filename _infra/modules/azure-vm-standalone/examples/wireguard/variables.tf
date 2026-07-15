variable "resource_group_name" {
  description = "Resource group hosting the VM."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the VM attaches to. Its NSG must allow inbound WireGuard UDP."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "Authorized SSH public key for the admin user."
  type        = string
}

variable "wg_address" {
  description = "WireGuard interface address in CIDR notation."
  type        = string
  default     = "10.100.0.1/24"
}

variable "wg_listen_port" {
  description = "WireGuard UDP listen port."
  type        = number
  default     = 51820
}

variable "wg_private_key" {
  description = "WireGuard server private key."
  type        = string
  sensitive   = true
}
