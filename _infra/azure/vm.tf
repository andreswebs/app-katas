module "wireguard" {
  source = "../modules/azure-vm-standalone"

  name                = "wireguard"
  role                = "wireguard"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = azurerm_subnet.this.id

  admin_ssh_public_key = file(pathexpand(var.admin_ssh_public_key_path))

  tags = var.tags

  depends_on = [azurerm_subnet_network_security_group_association.this]
}

# The wireguard playbook connects over `az ssh` (Entra ID) and runs
# `become: true`, which needs sudo. That requires the "Virtual Machine
# Administrator Login" role (plain "User Login" does not grant sudo).
resource "azurerm_role_assignment" "operator_vm_admin_login" {
  scope                = module.wireguard.vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azurerm_client_config.current.object_id
}
