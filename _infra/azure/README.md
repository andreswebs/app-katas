# _infra/azure

Standalone Azure boilerplate that stands up a WireGuard VM using the
[azure-vm-standalone](../modules/azure-vm-standalone) module, ready for the
`wireguard` Ansible playbook to converge against.

It creates its own resource group, VNet, subnet, and NSG (it does not reuse the
agilitas ALZ hub), and deploys into the agilitas **dev** subscription using the
operator's `az login` context. State is local (no remote backend).

## What it builds

- `rg-wireguard-kata` resource group
- `vnet-wireguard-kata` (10.10.0.0/16) + `snet-wireguard-kata` (10.10.1.0/24)
- `nsg-wireguard-kata` allowing `22/tcp` from the operator IP and `51820/udp`
  from anywhere
- `vm-wireguard` via the module, tagged `Name=wireguard` + `role=wireguard`,
  with the `AADSSHLoginForLinux` extension and a static public IP
- `Virtual Machine Administrator Login` role for the operator, scoped to the VM

Between them these satisfy the playbook prerequisites in
[docs/azure-prereqs.md](../../../.local/ansible/playbooks/wireguard/docs/azure-prereqs.md).

## Prerequisites

```sh
az login
az account set --subscription a1ee7e9d-f0dd-4dd8-842d-21f84647390a
```

## Deploy

```sh
cd _infra/azure
terraform init
terraform apply
```

Override the SSH key or source IP if the defaults do not fit:

```sh
terraform apply \
  -var 'admin_ssh_public_key_path=~/.ssh/id_ed25519.pub' \
  -var 'ssh_source_address=203.0.113.7/32'
```

## Run the playbook

The `azure_rm` inventory keys on `tags.Name`, so the VM lands in the
`vm_tag_wireguard` group. From the playbook repo:

```sh
cd ~/app-katas/.local/ansible/playbooks/wireguard
./playbook.azure.yml -i inventory/azure_rm.yml
```

The operator's `az login` and default subscription must match this deployment.

## Teardown

```sh
terraform destroy
```
