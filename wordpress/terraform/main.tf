module "instance" {
  source         = "andreswebs/public-ec2/aws"
  version        = "0.2.0"
  name           = "wordpress"
  subnet_id      = var.subnet_id
  cidr_whitelist = var.cidr_whitelist
  ebs_volumes = [
    {
      name        = "wordpress-db"
      device_name = "/dev/sdf"
      mount_path  = "/var/lib/wordpress-db"
      size        = 10
    },
    {
      name        = "wordpress"
      device_name = "/dev/sdg"
      mount_path  = "/var/lib/wordpress"
      size        = 10
    }
  ]
}

locals {
  app_hostname = "blog.p41.inexistent.xyz"
  app_ip_external = module.instance.public_ip
}
