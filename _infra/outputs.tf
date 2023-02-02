output "apps" {
  value = {
    jenkins = module.jenkins.app_address
    # vaultwarden = module.vaultwarden.app_address
  }
}
