locals {
  ssh_key_name = var.ssh_key_name != "" ? var.ssh_key_name : "${var.name}-ssh"
}

resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  name   = var.name

  revoke_rules_on_delete = true

  tags = {
    Name = var.name
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.cidr_whitelist)

  security_group_id = aws_security_group.this.id

  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = each.value
}

resource "aws_vpc_security_group_ingress_rule" "rdp" {
  for_each = toset([for cidr in var.cidr_whitelist : cidr if var.rdp_enabled])

  security_group_id = aws_security_group.this.id

  ip_protocol = "tcp"
  from_port   = 3389
  to_port     = 3389
  cidr_ipv4   = each.value
}

resource "aws_vpc_security_group_egress_rule" "open" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  from_port         = "-1"
  to_port           = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  # cidr_ipv6         = "::/0"
}

module "ec2_keypair" {
  source             = "andreswebs/insecure-ec2-key-pair/aws"
  version            = "1.0.0"
  key_name           = local.ssh_key_name
  ssm_parameter_name = "/${var.name}/ssh-key"
}

module "ec2_role" {
  source       = "andreswebs/ec2-role/aws"
  version      = "1.1.0"
  role_name    = var.name
  profile_name = var.name
  policies = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
  ]
}

module "s3_requisites_for_ssm" {
  source  = "andreswebs/s3-requisites-for-ssm-policy-document/aws"
  version = "1.1.0"
}

resource "aws_iam_role_policy" "s3_requisites_for_ssm" {
  name   = "s3-requisites-for-ssm"
  role   = module.ec2_role.role.name
  policy = module.s3_requisites_for_ssm.json
}
