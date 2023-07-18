output "app_address" {
  description = "app address"
  value       = hcloud_server.this.ipv4_address
}
