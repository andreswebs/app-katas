module "jenkins" {
  source                       = "../jenkins/terraform"
  external_access_ip_whitelist = var.external_access_ip_whitelist
  snapshot_name                = "jenkins-data-manual-2022-12-08"
}

# module "drone" {
#   source                       = "../drone/terraform"
#   external_access_ip_whitelist = var.external_access_ip_whitelist
# }

# module "peertube" {
#   source                       = "../peertube/terraform"
#   external_access_ip_whitelist = var.external_access_ip_whitelist
# }

# module "vaultwarden" {
#   source                       = "../vaultwarden/terraform"
#   external_access_ip_whitelist = var.external_access_ip_whitelist
# }
