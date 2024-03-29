locals {
  region       = "europe-west1"
  zone         = "europe-west1-b"
  has_snapshot = var.snapshot_name != "" && var.snapshot_name != null
}

data "cloudinit_config" "vm" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/tpl/cloudinit.yaml.tftpl", {
      device_file = "/dev/disk/by-id/google-vaultwarden-data"
      mount_path  = "/var/lib/vaultwarden"
      username    = "vaultwarden"
      mkfs        = !local.has_snapshot
    })
  }
}

module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.5.0"
  name                         = "vaultwarden"
  region                       = local.region
  zone                         = local.zone
  subnetwork                   = "default"
  domain_name                  = "technet.link"
  external_access_ip_whitelist = var.external_access_ip_whitelist

  metadata = {
    "user-data" = data.cloudinit_config.vm.rendered
  }

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
