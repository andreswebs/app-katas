output "vm" {
  description = "Identity of the deployed Linux VM (id, name, admin_username)."
  value = {
    id             = azurerm_linux_virtual_machine.this.id
    name           = azurerm_linux_virtual_machine.this.name
    admin_username = azurerm_linux_virtual_machine.this.admin_username
  }
}

output "public_ip" {
  description = "Full public IP resource, or null when public_ip_enabled is false. Use .ip_address for the dotted-quad."
  value       = one(azurerm_public_ip.this)
}

output "network_interface" {
  description = "Full NIC resource attached to the VM."
  value       = azurerm_network_interface.this
}
