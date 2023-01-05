locals {
  region = "europe-west1"
  zone   = "europe-west1-d"
}

module "network_info" {
  source  = "andreswebs/network-info/google"
  version = "0.2.0"
  network = "default"
}

module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.4.0"
  name                         = "vaultwarden"
  region                       = local.region
  zone                         = local.zone
  subnetwork                   = module.network_info.subnetwork[local.region].name
  domain_name                  = "technet.link"
  external_access_ip_whitelist = var.external_access_ip_whitelist

  extra_disks = [
    {
      name     = "vaultwarden-data"
      type     = "pd-ssd"
      zone     = local.zone
      size     = 10
      snapshot = var.snapshot_name
    }
  ]

}

module "dns" {
  source                = "andreswebs/reverse-dns/google"
  version               = "0.1.0"
  dns_reverse_zone_name = "internal-reverse"
  dns_zone_name         = "internal-technet-link"
  fqdn                  = module.vm.hostname
  ipv4_address          = module.vm.internal_ip
}

locals {
  app_hostname    = module.vm.hostname
  app_ip_external = module.vm.external_ip
}
