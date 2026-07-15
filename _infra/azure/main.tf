data "azurerm_client_config" "current" {}

# Operator public IP, used to scope the inbound SSH rule when ssh_source_address
# is not set explicitly. body is like "203.0.113.7\n".
data "http" "operator_ip" {
  count = var.ssh_source_address == null ? 1 : 0
  url   = "https://api.ipify.org"
}

locals {
  ssh_source_address = coalesce(var.ssh_source_address, try("${chomp(data.http.operator_ip[0].response_body)}/32", null))
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}
