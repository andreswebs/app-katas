data "aws_subnet" "this" {
  id = var.subnet_id
}

module "ec2_base" {
  source              = "andreswebs/ec2-base/aws"
  version             = "0.6.0"
  name                = "qryn"
  vpc_id              = data.aws_subnet.this.vpc_id
  cidr_whitelist_ipv4 = var.cidr_whitelist_ipv4

  allow_public_web_traffic = true
}

module "ec2_instance" {
  source                 = "andreswebs/ec2-instance-linux/aws"
  version                = "0.8.0"
  name                   = "qryn"
  iam_profile_name       = module.ec2_base.instance_profile.name
  subnet_id              = data.aws_subnet.this.id
  vpc_security_group_ids = [module.ec2_base.security_group.id]

  app_username = "qryn"
  app_uid      = 2000
  app_gid      = 2000

  associate_public_ip_address = true

  instance_type = "m7a.xlarge"

  extra_volumes = [
    {
      device_name = "/dev/sdf"
      size        = 100
      mount_path  = "/var/lib/clickhouse"
      uid         = 2000
      gid         = 2000
    },
    {
      device_name = "/dev/sdg"
      size        = 100
      mount_path  = "/var/log/clickhouse-server"
      uid         = 2000
      gid         = 2000
    }
  ]
}

locals {
  app_hostname    = "qryn"
  app_ip_external = module.ec2_instance.public_ip
  instance_id     = module.ec2_instance.id
}
