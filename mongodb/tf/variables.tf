variable "atlas_org_id" {
  type        = string
  description = "Atlas organization the disposable project is created under."
}

variable "project_name" {
  type        = string
  description = "Name of the disposable Atlas project."
  default     = "mongodb-poc"
}

variable "cluster_name" {
  type        = string
  description = "Name of the disposable cluster."
  default     = "poc"
}

variable "region_name" {
  type        = string
  description = <<-EOT
    Atlas region for the Flex cluster's backing provider. Flex cannot change
    region or provider after creation, which is the part of the one-way-door
    argument that does hold.
  EOT
  default     = "EU_CENTRAL_1"
}

variable "backing_provider_name" {
  type        = string
  description = "Cloud provider backing the Flex tier."
  default     = "AWS"
}

variable "provider_name" {
  type        = string
  description = <<-EOT
    Tier selector. FLEX for these exercises. Exercise 17 changes this to a
    dedicated tier and runs `terraform plan` only, to see whether the provider
    reports an in-place upgrade or a replacement.
  EOT
  default     = "FLEX"
}

variable "database_name" {
  type        = string
  description = "Application database the least-privilege user is scoped to."
  default     = "appdb"
}

variable "app_username" {
  type        = string
  description = "Least-privilege application user, readWrite on the app database only."
  default     = "app-user"
}

variable "ops_username" {
  type        = string
  description = "Operations user, atlasAdmin, for the restore comparison in exercise 13."
  default     = "ops-user"
}

variable "operator_ip" {
  type        = string
  description = <<-EOT
    The operator's public IPv4 address, as a single-address access-list entry.
    Get it with: curl -s https://checkip.amazonaws.com
    Exercise 16 removes this entry deliberately, to see the outage it produces.
  EOT
}
