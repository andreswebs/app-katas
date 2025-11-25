data "aws_subnet" "this" {
  id = var.subnet_id
}

module "ec2_base" {
  source              = "andreswebs/ec2-base/aws"
  version             = "0.11.1"
  vpc_id              = data.aws_subnet.this.vpc_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
  name                = "wireguard"

  extra_ingress_rules_ipv4 = [
    {
      ip_protocol = "udp"
      from_port   = "51820"
      to_port     = "51820"
      cidr_ipv4   = "0.0.0.0/0"
    }
  ]

}

module "ec2_instance" {
  source                 = "andreswebs/ec2-instance-linux/aws"
  version                = "0.18.0"
  subnet_id              = data.aws_subnet.this.id
  vpc_security_group_ids = [module.ec2_base.security_group.id]
  iam_profile_name       = module.ec2_base.instance_profile.name
  name                   = "wireguard"

  ssh_key_name = module.ec2_base.key_pair.key_name
  app_username = "wireguard"

  associate_public_ip_address = true

  instance_type = "t4a.small"

  extra_volumes = [
    {
      device_name = "/dev/sdf"
      size        = 2
      mount_path  = "/etc/wireguard"
      uid         = 2000
      gid         = 2000
    }
  ]
}

locals {
  app_hostname    = "wireguard"
  app_ip_external = module.ec2_instance.public_ip
}
