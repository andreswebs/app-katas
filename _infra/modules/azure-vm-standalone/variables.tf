variable "name" {
  description = "Base name used to derive resource names: vm-<name>, nic-<name>, pip-<name>, osdisk-<name>. Also set as the `Name` tag on the VM."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the VM and its supporting resources (NIC, public IP)."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource created by the module."
  type        = map(string)
  default     = {}
}

variable "role" {
  description = "Optional workload role. When set, merged as the `role` tag on the VM (e.g. \"wireguard\", \"bastion\")."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "ID of the subnet the VM NIC will attach to. Inbound traffic (SSH, WireGuard UDP, etc.) is governed by the subnet's NSG, which is the caller's responsibility."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Linux admin username created on the VM."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Authorized SSH public key for the admin user. Password authentication is disabled."
  type        = string
}

variable "os_image" {
  description = "Marketplace image reference for the VM OS."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

variable "os_disk_storage_account_type" {
  description = "Managed disk type for the OS disk."
  type        = string
  default     = "Standard_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB. Defaults to the image's published size when null."
  type        = number
  default     = null
}

variable "custom_data" {
  description = "Provisioning payload passed to the VM on first boot, plaintext (the module base64-encodes it). Typically cloud-init YAML or a shell script. This is the mechanism for provisioning workloads such as a WireGuard config: render the config/cloud-init in the caller and pass it here. Null leaves the VM unprovisioned."
  type        = string
  default     = null
}

variable "public_ip_enabled" {
  description = "Whether to allocate a Standard public IP and attach it to the NIC. Set to false for a private-only VM."
  type        = bool
  default     = true
}

variable "public_ip_zones" {
  description = "Availability zones for the Standard public IP. Defaults to zone-redundant. Set to [] for a non-zonal IP in regions without zones. Ignored when public_ip_enabled is false."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "aad_ssh_login_enabled" {
  description = "Whether to install the AADSSHLoginForLinux extension for Entra ID (Azure AD) based SSH access."
  type        = bool
  default     = true
}
