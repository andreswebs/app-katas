
module "wireguard" {
  source              = "../../wireguard/tf"
  vpc_id              = var.vpc_id
  subnet_id           = var.subnet_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
}
