locals {
  region       = "europe-west1"
  zone         = "europe-west1-b"
  has_snapshot = var.snapshot_name != "" && var.snapshot_name != null
}

module "network_info" {
  source  = "andreswebs/network-info/google"
  version = "0.2.0"
  network = "default"
}

data "cloudinit_config" "vm" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/tpl/cloudinit.yaml.tftpl", {
      device_file = "/dev/disk/by-id/google-jenkins-data"
      mount_path  = "/mnt/disks/data"
      username    = "jenkins"
      mkfs        = !local.has_snapshot
    })
  }
}

module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.5.0"
  name                         = "jenkins"
  region                       = local.region
  zone                         = local.zone
  subnetwork                   = module.network_info.subnetwork[local.region].name
  domain_name                  = "inexistent.xyz"
  external_access_ip_whitelist = var.external_access_ip_whitelist

  metadata = {
    "user-data" = data.cloudinit_config.support_vm.rendered
  }

  extra_disks = [
    {
      name     = "jenkins-data"
      type     = "pd-ssd"
      zone     = local.zone
      size     = 50
      snapshot = var.snapshot_name
    }
  ]
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
