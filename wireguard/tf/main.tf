module "ec2_base" {
  source              = "andreswebs/ec2-base/aws"
  version             = "0.3.0"
  vpc_id              = var.vpc_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4
  name                = "wireguard"

  create_ssh_key = true
  allow_ssh      = true

  extra_whitelisted_ingress_rules = [
    {
      ip_protocol = "udp"
      from_port   = "51820"
      to_port     = "51820"
    }
  ]

}

module "ec2_instance" {
  source                 = "andreswebs/ec2-instance-linux/aws"
  version                = "0.8.0"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [module.ec2_base.security_group.id]
  iam_profile_name       = module.ec2_base.instance_profile.name
  name                   = "wireguard"

  ssh_key_name = module.ec2_base.key_pair.key_name
  app_username = "wireguard"

  associate_public_ip_address = true

  instance_type = "t3a.small"

  extra_volumes = [
    {
      device_name = "/dev/sdf"
      size        = 5
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
