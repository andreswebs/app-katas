# azure-vm-standalone

A generic, standalone Linux VM module for Azure. It provisions a
`azurerm_linux_virtual_machine` with its NIC, an optional Standard public IP,
and the optional Entra ID SSH-login extension.

Workload provisioning (WireGuard, a bastion, a web server, etc.) is passed in
as data through `custom_data`: render cloud-init or a shell script in the
caller and hand it to the module. The module stays workload-agnostic; the
`role` variable only tags the VM so you can tell instances apart.

## Usage

```hcl
module "vm" {
  source = "../../modules/azure-vm-standalone"

  name                = "app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = azurerm_subnet.this.id

  admin_ssh_public_key = file("~/.ssh/id_ed25519.pub")

  custom_data = <<-EOT
    #cloud-config
    packages:
      - nginx
  EOT
}
```

See [`examples/wireguard`](examples/wireguard) for provisioning a WireGuard
server through `custom_data`.

## Notes

- The subnet's NSG governs all inbound traffic; the module opens nothing.
- Password authentication is always disabled; SSH is key-based.
- Set `public_ip_enabled = false` for a private-only VM.
- `custom_data` is plaintext; the module base64-encodes it. Azure caps it at
  64 KiB.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
