locals {
  region       = "europe-west1"
  zone         = "europe-west1-b"
  machine_type = "n2-standard-4"
  storage_name = "k3s-storage"
  has_snapshot = var.snapshot_name != "" && var.snapshot_name != null
}

data "cloudinit_config" "vm" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/tpl/cloudinit.yaml.tftpl", {
      device_file = "/dev/disk/by-id/google-${local.storage_name}"
      mount_path  = "/var/lib/rancher/k3s"
      mkfs        = !local.has_snapshot
    })
  }
}

module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.5.0"
  name                         = "k3s"
  region                       = local.region
  zone                         = local.zone
  subnetwork                   = "default"
  domain_name                  = "technet.link"
  external_access_ip_whitelist = var.external_access_ip_whitelist
  machine_type                 = local.machine_type

  metadata = {
    "user-data" = data.cloudinit_config.vm.rendered
  }

  extra_disks = [
    {
      name     = local.storage_name
      zone     = local.zone
      type     = "pd-ssd"
      size     = 20
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

resource "google_compute_firewall" "external_kube" {
  name    = "k3s-external-kube"
  network = module.network_info.network.name

  target_tags = ["k3s"]

  source_ranges = var.external_access_ip_whitelist

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

}

locals {
  app_hostname    = module.vm.hostname
  app_ip_external = module.vm.external_ip
}
