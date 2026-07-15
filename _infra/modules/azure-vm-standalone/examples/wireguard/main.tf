terraform {
  required_version = "~> 1.14"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Renders a cloud-init payload that installs WireGuard and drops the server
# config. This is what "provisioning the WireGuard config via inputs" looks
# like: the config is data owned by the caller, the module just runs it.
locals {
  wg_cloud_init = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - wireguard
    write_files:
      - path: /etc/wireguard/wg0.conf
        permissions: "0600"
        owner: root:root
        content: |
          [Interface]
          Address = ${var.wg_address}
          ListenPort = ${var.wg_listen_port}
          PrivateKey = ${var.wg_private_key}
    runcmd:
      - sysctl -w net.ipv4.ip_forward=1
      - systemctl enable --now wg-quick@wg0
  EOT
}

module "wireguard" {
  source = "../.."

  name                = "wg"
  role                = "wireguard"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  admin_ssh_public_key = var.admin_ssh_public_key
  custom_data          = local.wg_cloud_init

  tags = {
    environment = "dev"
  }
}
