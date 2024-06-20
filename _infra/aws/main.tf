
module "wireguard" {
  source              = "../../wireguard/tf"
  subnet_id           = var.pub_subnet_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
}

module "ec2_test" {
  source              = "../modules/aws-ec2-standalone"
  name                = "wg-test"
  subnet_id           = var.prv_subnet_id
  cidr_whitelist_ipv4 = ["10.0.0.0/8"]
}
