# module "ec2_base" {
#   source         = "../modules/aws-ec2-base/"
#   vpc_id         = var.vpc_id
#   cidr_whitelist = var.cidr_whitelist
#   name           = "k3s"

#   allow_web_traffic = true

#   extra_whitelisted_ingress_rules = [
#     {
#       from_port = "6443"
#       to_port   = "6443"
#     }
#   ]

# }

# module "ec2_instance" {
#   source                 = "../modules/aws-ec2-instance-linux/"
#   subnet_id              = var.subnet_id
#   vpc_security_group_ids = [module.ec2_base.security_group.id]
#   ssh_key_name           = module.ec2_base.key_pair.key_name
#   iam_profile_name       = module.ec2_base.instance_profile.name
#   name                   = "k3s"
# }

# output "ec2_instance_public_ip" {
#   value = module.ec2_instance.public_ip
# }
