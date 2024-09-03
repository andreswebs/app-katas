
module "openobserve" {
  source              = "../../openobserve/tf"
  subnet_id           = var.pub_subnet_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
}

output "openobserve" {
  value = module.openobserve.app_info
}
