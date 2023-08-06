module "k3s" {
  source       = "../../k3s/terraform/hcloud/"
  name         = "k3s"
  ssh_key_name = "default"
}

output "k3s" {
  value = module.k3s.app_address
}
