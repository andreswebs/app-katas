
module "ec2_test" {
  source              = "../modules/aws-ec2-standalone"
  name                = "poc"
  subnet_id           = var.prv_subnet_id
  cidr_whitelist_ipv4 = ["10.0.0.0/8"]
}
