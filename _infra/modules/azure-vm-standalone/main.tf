locals {
  vm_tags = merge(
    var.tags,
    { Name = var.name },
    var.role != null ? { role = var.role } : {},
  )
}

resource "azurerm_public_ip" "this" {
  count = var.public_ip_enabled ? 1 : 0

  name                = "pip-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location

  allocation_method = "Static"
  sku               = "Standard"
  zones             = length(var.public_ip_zones) > 0 ? var.public_ip_zones : null

  tags = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_enabled ? azurerm_public_ip.this[0].id : null
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "vm-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location

  size           = var.vm_size
  admin_username = var.admin_username

  network_interface_ids = [azurerm_network_interface.this.id]

  disable_password_authentication = true

  custom_data = var.custom_data != null ? base64encode(var.custom_data) : null

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "osdisk-${var.name}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }

  tags = local.vm_tags

  lifecycle {
    # ALZ DINE policy (Azure Monitor Agent) attaches a UserAssigned identity
    # post-create. Ignoring identity drift keeps the policy's post-apply UAI in
    # place instead of fighting it on every plan.
    ignore_changes = [identity]
  }
}

resource "azurerm_virtual_machine_extension" "aad_ssh_login" {
  count = var.aad_ssh_login_enabled ? 1 : 0

  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  tags = var.tags
}
