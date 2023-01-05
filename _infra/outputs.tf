output "apps" {
  value = {
    vaultwarden = module.vaultwarden.app_address
  }
}
