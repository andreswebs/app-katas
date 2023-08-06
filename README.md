# app-katas

This is a collection of "app katas" to practice deploying complex applications
using open-source DevOps tools.

> Kata is a Japanese word (型 or 形) meaning "form". It refers to a detailed
> choreographed pattern of martial arts movements made to be practised alone.
> [...] It is practised in Japanese martial arts as a way to memorize and
> perfect the movements being executed.
> ([Wikipedia - Kata](https://en.wikipedia.org/wiki/Kata))

The idea of "code katas" comes from [Dave Thomas](https://pragdave.me/), one of
the authors of the [Agile Manifesto](https://agilemanifesto.org/), as a way to
bring that element of disciplined practice into software development.

Here we apply the idea of code katas to DevOps practice, by deploying various
apps using a common DevOps tech stack. Those are the "app katas" included in the
present repo.

## Stack

The stack is comprised of the following tools:

- [Terraform](https://www.terraform.io/)
- [Ansible](https://www.ansible.com/)
- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Traefik](https://traefik.io/)
- [Let's Encrypt](https://letsencrypt.org/)

Installation and configuration of these tools is outside the scope of this
document.

## Deployment

### **Pre-requisites:**

Terraform and Ansible must be installed in the operator machine.

Terraform and Ansible credentials must have been configured for the cloud
provider of choice.

Create an inventory file from `_config/inventory/example.gcp.yml` and set the
GCP project ID.

Set up any needed environment variables for the app containers in
`<app>/app/.env`, as in the example `whoami/app/.env.example`.

(TODO: add more instructions)

### **Create infra:**

Individual app modules are instantiated in `_infra/gcp/main.tf`.

```sh
pushd ./_infra/gcp
terraform init
terraform plan
terraform apply
popd
```

(Grab the Terraform outputs to configure DNS)

### **DNS:**

Add DNS records pointing to the instance IPs output in the previous step.

### **Deploy docker app:**

Example:

```sh
pushd ./_config
ansible-galaxy install -r requirements.yml
./playbooks/gcp-docker-app.yml -i inventory/yourinventory.gcp.yml -e upgrade_system=true -e app=whoami
popd
```

## Example: k3s single node on Hetzner Cloud

```sh
export HCLOUD_TOKEN="examplehcloudtoken"
```

```sh
pushd ./_infra/hcloud
terraform init
terraform plan
terraform apply
popd
```

```sh
pushd ./_config
./playbooks/hcloud-k3s.yml --inventory inventory/hcloud.yml
popd
```

```sh
export KUBECONFIG=/tmp/k3s.yaml
export SERVER_IP="<SERVER_IP_HERE>"
kubectl apply -f ./k3s/hello-world/
curl "${SERVER_IP}"
```

```sh
pushd ./_infra/hcloud
terraform destroy
popd
```

## Authors

**Andre Silva** - [@andreswebs](https://github.com/andreswebs)

## License

This project is licensed under the [Unlicense](UNLICENSE.md).

## Acknowledgements

Dave Thomas, <http://codekata.com/>
