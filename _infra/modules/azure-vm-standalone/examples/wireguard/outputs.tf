output "public_ip" {
  description = "Public IP address of the WireGuard VM."
  value       = module.wireguard.public_ip.ip_address
}

output "vm" {
  description = "Deployed VM identity."
  value       = module.wireguard.vm
}
