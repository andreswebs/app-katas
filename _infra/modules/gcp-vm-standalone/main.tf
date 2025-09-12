module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.5.0"
  name                         = var.name
  region                       = var.region
  zone                         = var.zone
  subnetwork                   = var.subnetwork
  domain_name                  = var.domain_name
  external_access_ip_whitelist = var.external_access_ip_whitelist
}

module "dns" {
  source                = "andreswebs/reverse-dns/google"
  version               = "0.1.0"
  dns_reverse_zone_name = var.dns_reverse_zone_name
  dns_zone_name         = var.dns_zone_name
  fqdn                  = module.vm.hostname
  ipv4_address          = module.vm.internal_ip
}
