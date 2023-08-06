resource "hcloud_server" "this" {
  name        = var.name
  image       = var.image
  server_type = var.server_type

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  ssh_keys = [
    var.ssh_key_name
  ]

  labels = {
    app = var.name
  }
}
