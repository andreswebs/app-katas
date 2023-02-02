locals {
  region = "europe-west1"
  zone   = "europe-west1-b"
}

module "network_info" {
  source  = "andreswebs/network-info/google"
  version = "0.2.0"
  network = "default"
}

module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.5.0"
  name                         = "whoami"
  region                       = local.region
  zone                         = local.zone
  subnetwork                   = module.network_info.subnetwork[local.region].name
  domain_name                  = "inexistent.xyz"
  external_access_ip_whitelist = var.external_access_ip_whitelist
}

module "dns" {
  source                = "andreswebs/reverse-dns/google"
  version               = "0.1.0"
  dns_reverse_zone_name = "internal-reverse"
  dns_zone_name         = "internal-inexistent-xyz"
  fqdn                  = module.vm.hostname
  ipv4_address          = module.vm.internal_ip
}

locals {
  app_hostname    = module.vm.hostname
  app_ip_external = module.vm.external_ip
}
