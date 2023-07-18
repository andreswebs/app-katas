output "app_address" {
  value = {
    (local.app_hostname) = local.app_ip_external
  }
}
