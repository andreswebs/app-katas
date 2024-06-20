output "apps" {
  value = {
    # wordpress = module.wordpress.app_address
    wireguard = module.wireguard.app_address
  }
}
