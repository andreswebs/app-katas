# AI Agent Instructions

## Project Overview

This repository contains a collection of application deployment and infrastructure-as-code (IaC) katas, including Docker Compose setups, Terraform configurations, Ansible playbooks, and supporting scripts for various open-source applications and cloud environments. The project is organized as a monorepo, with subfolders for each app or infrastructure component.

- **Key technologies:** Docker Compose, Terraform (AWS, GCP, Hetzner, local), Ansible, k3s, various open-source apps (WordPress, Jenkins, MinIO, Milvus, etc.)
- **Structure:**
  - `/app/` — Docker Compose files for each app
  - `/terraform/`, `/tf/`, `/terraform/aws|gcp|hcloud/` — Terraform modules and environments
  - `/playbooks/`, `/roles/` — Ansible automation
  - `/k3s/` — Kubernetes manifests and supporting files

## Setup Commands

### General

- Clone the repository:

  ```sh
  git clone <repo-url>
  cd app-katas
  ```

- Install Docker and Docker Compose (see <https://docs.docker.com/get-docker/>)
- Install Terraform (see <https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli>)
- Install Ansible (see <https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html>)

### Python/Ansible dependencies

- Install Ansible Galaxy roles:

  ```sh
  ansible-galaxy install -r _config/requirements.yml
  ```

## Development Workflow

### Docker Compose

- Start an app (example for Zammad):

  ```sh
  cd zammad/app
  docker compose up
  ```

- Stop an app:

  ```sh
  docker compose down
  ```

- View running containers:

  ```sh
  docker ps
  ```

### Terraform

- Initialize a Terraform environment (example for AWS):

  ```sh
  cd _infra/aws
  terraform init
  terraform plan
  terraform apply
  ```

- Destroy resources:

  ```sh
  terraform destroy
  ```

### Connecting to AWS EC2 instances (SSM Session Manager)

AWS EC2 instances in this repo (see `_infra/aws`, built from the
`_infra/modules/aws-ec2-standalone` module) are accessed via **AWS SSM Session
Manager, not SSH**. There is intentionally no SSH keypair and no inbound port 22.

Access works because the instance IAM role (from the upstream
`andreswebs/ec2-role/aws` module, via `ec2-base`) attaches
`AmazonSSMManagedInstanceCore`, which registers the instance as an SSM managed
node. The SSM agent (preinstalled on the AWS Linux AMIs) dials outbound to the
SSM service, so only egress is required.

- Prerequisites (client machine):
  - AWS CLI v2
  - Session Manager plugin: `brew install --cask session-manager-plugin`
    (`aws ssm start-session` shells out to this binary)

- Find the instance id (the module tags the instance `Name=poc`; no Terraform
  outputs are defined):

  ```sh
  export INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=poc" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
  ```

- Confirm it registered as a managed node:

  ```sh
  aws ssm describe-instance-information \
    --query "InstanceInformationList[?InstanceId=='${INSTANCE_ID}'].PingStatus" --output text
  ```

- Open an interactive shell:

  ```sh
  aws ssm start-session --target "${INSTANCE_ID}"
  ```

- Port-forward a service on the instance to localhost:

  ```sh
  aws ssm start-session --target "${INSTANCE_ID}" \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'
  ```

- SSH/scp over SSM (optional, still no open port 22) — add to `~/.ssh/config`:

  ```sshconfig
  host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
  ```

  then `ssh ec2-user@"${INSTANCE_ID}"`.

The operator's IAM principal needs `ssm:StartSession` (on the instance ARN or the
`AWS-StartSSHSession` document), `ssm:TerminateSession`/`ssm:ResumeSession` (on
`arn:aws:ssm:*:*:session/${aws:username}-*`), plus `ssm:DescribeInstanceInformation`
and `ec2:DescribeInstances`.

### Connecting to GCP instances (gcloud CLI)

GCP VMs (see `_infra/gcp` / `_infra/modules/gcp-vm-standalone`, built from
`andreswebs/public-vm/google`) get an external IP with tcp:22 opened to the
module's `external_access_ip_whitelist`. SSH keys are managed by the `gcloud` CLI
(`~/.ssh/google_compute_engine`), not committed anywhere.

- One-time auth (the Ansible `gcp_compute` inventory plugin uses Application
  Default Credentials):

  ```sh
  gcloud auth login
  gcloud auth application-default login
  gcloud config set project "${GOOGLE_PROJECT}"
  ```

- SSH into an instance (generates/pushes the key on first use):

  ```sh
  export GOOGLE_PROJECT="your-project-id"
  export GOOGLE_ZONE="europe-west1-b"
  export VM_NAME="poc"

  gcloud compute ssh "${VM_NAME}" --project "${GOOGLE_PROJECT}" --zone "${GOOGLE_ZONE}"
  ```

  For an instance with no external IP, add `--tunnel-through-iap` (needs
  `roles/iap.tunnelResourceAccessor` and firewall for `35.235.240.0/20` on tcp:22).

- Populate `~/.ssh/config` so plain `ssh` and Ansible can reach the hosts:

  ```sh
  gcloud compute config-ssh   # re-run when IPs change
  ssh "${VM_NAME}.${GOOGLE_ZONE}.${GOOGLE_PROJECT}"
  ```

- Key/user model:
  - **Metadata SSH keys** (default): username is the local part of the key (e.g.
    `andre`).
  - **OS Login** (recommended): set metadata `enable-oslogin=TRUE` and grant
    `roles/compute.osLogin`; username becomes email-derived (e.g.
    `andre_p41_bizee_com`). `gcloud compute ssh` handles this automatically.

### Ansible: GCP dynamic inventory

The `gcp_compute` plugin discovers instances via ADC and groups them by network
tag as `vm_tag_<tag>` (see `_config/inventory/example.gcp.yml`), which is what the
GCP playbooks target (`vm_tag_k3s`, `vm_tag_<app>`).

- Create the live inventory (gitignored; only `example.gcp.yml` is committed):

  ```sh
  cd _config
  cp inventory/example.gcp.yml inventory/gcp.yml   # set your real project id + ansible_user
  ```

- Run a playbook:

  ```sh
  ansible-playbook -i inventory/gcp.yml playbooks/docker-app.gcp.yml -e app=whoami
  ansible-playbook -i inventory/gcp.yml playbooks/k3s.gcp.yml
  ```

The `compose:` block in the inventory sets `ansible_host` to the external IP,
`ansible_user`, and `ansible_ssh_private_key_file` to the gcloud-managed key.

### Ansible

- Run a playbook (example):

  ```sh
  ansible-playbook -i inventory/aws_ec2.yml playbooks/docker-app.aws.yml
  ```

## Testing Instructions

- No formal automated test suite is included by default. For infrastructure, validate with:
  - Terraform: `terraform validate` in each environment directory
  - Ansible: `ansible-lint <playbook>`
  - Docker Compose: Ensure containers start and logs show healthy status
- For app-specific tests, see subproject `README.md` files if present.

## Code Style Guidelines

- **Terraform:**
  - Use `terraform fmt` for formatting
  - Use `terraform validate` for syntax checking
- **Ansible:**
  - Use YAML linting tools (e.g., `yamllint`)
  - Follow Ansible best practices for roles and playbooks
- **Docker Compose:**
  - Use versioned Compose files
  - Organize by app in `/app/` subfolders
- **General:**
  - Use descriptive folder and file names
  - Keep secrets and credentials out of version control

## Build and Deployment

- **Docker Compose:**
  - Build images (if needed): `docker compose build`
  - Deploy: `docker compose up -d`
- **Terraform:**
  - Apply changes: `terraform apply`
  - Destroy: `terraform destroy`
- **Ansible:**
  - Deploy with playbooks as needed
- **CI/CD:**
  - No global pipeline; see subproject or cloud provider for automation

## Security Considerations

- Do not commit secrets or credentials; use environment variables or secret managers
- Review Compose and Terraform files for exposed ports and credentials
- Use least-privilege IAM roles for cloud resources

## Monorepo Instructions

- Each app or infrastructure component is in its own subfolder
- To work on a specific app, navigate to its directory (e.g., `cd minio/app`)
- For infrastructure, use the appropriate `_infra/{provider}` or `terraform/{provider}` directory
- Some subprojects may have their own `README.md` or `AGENTS.md` for more details

## Pull Request Guidelines

- Use descriptive PR titles: `[component] Brief description`
- Ensure all relevant Compose, Terraform, and Ansible files are valid and linted
- Do not commit secrets or credentials
- Reference related issues or katas if applicable

## Debugging and Troubleshooting

- Check container logs: `docker logs <container>`
- For Terraform, use `terraform plan` and `terraform show` to debug state
- For Ansible, use `-vvv` for verbose output
- See subproject `README.md` files for app-specific troubleshooting

## Additional Notes

- This repository is intended for learning, experimentation, and rapid prototyping
- For production use, review and harden all configurations
- Update this `AGENTS.md` as new apps or infrastructure components are added
