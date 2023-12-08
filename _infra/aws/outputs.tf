output "apps" {
  value = {
    wordpress = module.wordpress.app_address
  }
}
