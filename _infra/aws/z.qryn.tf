
module "qryn" {
  source              = "../../qryn/tf"
  subnet_id           = var.pub_subnet_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
}

output "qryn" {
  value = module.qryn.app_info
}
