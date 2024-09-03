data "aws_subnet" "this" {
  id = var.subnet_id
}

module "ec2_base" {
  source              = "andreswebs/ec2-base/aws"
  version             = "0.6.0"
  name                = var.name
  vpc_id              = data.aws_subnet.this.vpc_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4

  allow_public_web_traffic = true

  # create_ssh_key = true
  # allow_ssh      = true
}

module "ec2_instance" {
  source                 = "andreswebs/ec2-instance-linux/aws"
  version                = "0.8.0"
  name                   = var.name
  iam_profile_name       = module.ec2_base.instance_profile.name
  subnet_id              = data.aws_subnet.this.id
  vpc_security_group_ids = [module.ec2_base.security_group.id]
  instance_type          = var.instance_type

  associate_public_ip_address = true

  # ssh_key_name = module.ec2_base.key_pair.key_name
}
