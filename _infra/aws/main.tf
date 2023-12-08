module "wordpress" {
  source         = "../../wordpress/terraform"
  subnet_id      = var.subnet_id
  cidr_whitelist = var.cidr_whitelist
}
