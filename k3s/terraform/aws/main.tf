module "ec2_base" {
  source  = "andreswebs/ec2-base/aws"
  version = "0.8.0"

  name                     = "k3s"
  vpc_id                   = var.vpc_id
  cidr_whitelist_ipv4      = var.cidr_whitelist_ipv4
  allow_public_web_traffic = true

  extra_whitelisted_ingress_rules_ipv4 = [
    {
      from_port = "6443"
      to_port   = "6443"
    }
  ]

}

module "ec2_instance" {
  source  = "andreswebs/ec2-instance-linux/aws"
  version = "0.17.0"

  name                   = "k3s"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [module.ec2_base.security_group.id]
  iam_profile_name       = module.ec2_base.instance_profile.name
  instance_type          = "m7a.2xlarge"

  associate_public_ip_address = true

  extra_volumes = [
    {
      device_name = "/dev/sdf"
      volume_size = 100
      mount_path  = "/var/lib/rancher"
    }
  ]
}

locals {
  app_hostname    = "k3s"
  app_ip_external = module.ec2_instance.public_ip
}
