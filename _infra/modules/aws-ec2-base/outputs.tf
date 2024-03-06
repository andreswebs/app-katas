output "key_pair" {
  value = module.ec2_keypair.key_pair
}

output "instance_role" {
  value = module.ec2_role.role
}

output "instance_profile" {
  value = module.ec2_role.instance_profile
}

output "security_group" {
  value = aws_security_group.this
}
