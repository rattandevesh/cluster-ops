# Cluster Ops

Ansible playbooks for kOps cluster lifecycle management and add-on bootstrap.

## Playbooks

- **install-tools.yml**: Install kOps, kubectl, helm, argocd CLI
- **cluster-create.yml**: Generate kOps cluster manifest and create cluster
- **cluster-upgrade.yml**: Perform safe rolling upgrade
- **cluster-destroy.yml**: Teardown cluster and cleanup
- **addons-bootstrap.yml**: Install cluster add-ons with IRSA

## Usage

### Install Tools

```bash
ansible-playbook -i inventory install-tools.yml
```

### Create Cluster

```bash
ansible-playbook -i inventory cluster-create.yml \
  -e "environment=dev" \
  -e "cluster_name=dev.cluster.example.internal"
```

### Bootstrap Add-ons

```bash
ansible-playbook -i inventory addons-bootstrap.yml \
  -e "environment=dev" \
  -e "cluster_name=dev.cluster.example.internal"
```

## Prerequisites

- Ansible installed
- SSH access to bastion host
- Terraform outputs available (VPC, subnets, etc.)
