module "ec2_base_01" {
  source         = "../modules/aws-ec2-base/"
  vpc_id         = var.vpc_id_01
  cidr_whitelist = var.cidr_whitelist
  name           = "test-01"
  rdp_enabled    = false
}

module "ec2_instance_01" {
  source                 = "../modules/aws-ec2-instance-linux/"
  subnet_id              = var.subnet_id_01
  vpc_security_group_ids = [module.ec2_base_01.security_group.id]
  ssh_key_name           = module.ec2_base_01.key_pair.key_name
  iam_profile_name       = module.ec2_base_01.instance_profile.name
  name                   = "test-01"
}

output "ec2_instance_01_public_ip" {
  value = module.ec2_instance_01.public_ip
}

module "ec2_base_02" {
  source         = "../modules/aws-ec2-base/"
  vpc_id         = var.vpc_id_02
  cidr_whitelist = var.cidr_whitelist
  name           = "data-poc"
}

module "ec2_instance_02" {
  source                 = "../modules/aws-ec2-instance-linux/"
  subnet_id              = var.subnet_id_02
  vpc_security_group_ids = [module.ec2_base_02.security_group.id]
  ssh_key_name           = module.ec2_base_02.key_pair.key_name
  iam_profile_name       = module.ec2_base_02.instance_profile.name
  instance_type          = "m6a.2xlarge"
  name                   = "data-poc"
  volume_size            = 100
}

output "ec2_instance_02_public_ip" {
  value = module.ec2_instance_02.public_ip
}
