output "resource_group_name" {
  description = "Resource group hosting the VM. Pass to the playbook / az ssh as the RG."
  value       = azurerm_resource_group.this.name
}

output "vm_name" {
  description = "Deployed VM name (vm-wireguard)."
  value       = module.wireguard.vm.name
}

output "public_ip" {
  description = "Public IP address of the WireGuard VM. Point the SERVERURL DNS record here."
  value       = module.wireguard.public_ip.ip_address
}

output "ssh_source_address" {
  description = "Source address allowed inbound on 22/tcp."
  value       = local.ssh_source_address
}
