output "app_info" {
  value = {
    hostname    = local.app_hostname
    ip_external = local.app_ip_external
    instance_id = local.instance_id
  }
}
