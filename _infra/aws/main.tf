
module "k3s" {
  source         = "../../k3s/terraform/aws"
  vpc_id         = var.vpc_id
  subnet_id      = var.subnet_id
  cidr_whitelist = var.cidr_whitelist
}
