variable "subscription_id" {
  description = "Azure subscription to deploy into. Defaults to the agilitas dev workload subscription (csp-sub-agilitas-dev). Auth uses the operator's `az login` context."
  type        = string
  default     = "a1ee7e9d-f0dd-4dd8-842d-21f84647390a"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "name" {
  description = "Base name for the deployment, used in the resource group and network names."
  type        = string
  default     = "wireguard-kata"
}

variable "admin_ssh_public_key_path" {
  description = "Path to the SSH public key set as the VM admin key. Login to the VM is done via Entra ID (`az ssh`), so this key is a formality required by Azure; any valid public key works."
  type        = string
  default     = "~/.ssh/id_rsa_azure_vm_paxton.pub"
}

variable "ssh_source_address" {
  description = "Source address/CIDR allowed inbound on 22/tcp. When null, the operator's current public IP is auto-detected via the http data source."
  type        = string
  default     = null
}

variable "wireguard_listen_port" {
  description = "UDP port opened inbound for WireGuard clients."
  type        = number
  default     = 51820
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project     = "app-katas"
    environment = "dev"
    managed_by  = "terraform"
  }
}
