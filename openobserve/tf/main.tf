data "aws_subnet" "this" {
  id = var.subnet_id
}

module "ec2_base" {
  source              = "andreswebs/ec2-base/aws"
  version             = "0.3.0"
  vpc_id              = data.aws_subnet.this.vpc_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
  name                = "openobserve"

  create_ssh_key = false
  allow_ssh      = false

  allow_web_traffic = true

  # extra_ingress_rules = [
  #   {
  #     ip_protocol = "udp"
  #     from_port   = "51820"
  #     to_port     = "51820"
  #     cidr_ipv4   = "0.0.0.0/0"
  #   }
  # ]

}

module "ec2_instance" {
  source                 = "andreswebs/ec2-instance-linux/aws"
  version                = "0.8.0"
  subnet_id              = data.aws_subnet.this.id
  vpc_security_group_ids = [module.ec2_base.security_group.id]
  iam_profile_name       = module.ec2_base.instance_profile.name
  name                   = "openobserve"

  # ssh_key_name = module.ec2_base.key_pair.key_name
  app_username = "openobserve"
  app_uid      = 2000
  app_gid      = 2000

  associate_public_ip_address = true

  instance_type = "t3a.small"

  extra_volumes = [
    {
      device_name = "/dev/sdf"
      size        = 5
      mount_path  = "/var/lib/openobserve"
      uid         = 2000
      gid         = 2000
    }
  ]
}

locals {
  app_hostname    = "openobserve"
  app_ip_external = module.ec2_instance.public_ip
}
