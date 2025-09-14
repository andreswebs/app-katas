# `AGENTS.md`

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
- Install Docker and Docker Compose (see https://docs.docker.com/get-docker/)
- Install Terraform (see https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- Install Ansible (see https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

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
