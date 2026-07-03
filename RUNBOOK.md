# Cluster Ops Runbook

This runbook provides step-by-step instructions for kOps cluster lifecycle management and add-on bootstrap.

## Prerequisites

- Ansible >= 2.9 installed
- SSH access to bastion host
- Terraform outputs available (VPC, subnets, etc.)
- AWS CLI configured
- kOps state bucket created

## Initial Setup

### 1. Install Tools

```bash
cd /Users/devesh/workspace/assignment/cluster-ops
ansible-playbook install-tools.yml
```

This installs:
- kOps
- kubectl
- Helm
- ArgoCD CLI

### 2. Configure Environment Variables

```bash
export ENVIRONMENT=dev
export CLUSTER_NAME=dev.cluster.example.internal
export VPC_ID=vpc-xxxxxxxx
export PRIVATE_SUBNET_IDS=subnet-xxx,subnet-yyy,subnet-zzz
export PUBLIC_SUBNET_IDS=subnet-aaa,subnet-bbb,subnet-ccc
export HOSTED_ZONE_ID=Zxxxxxxxx
export KMS_KEY_ARN=arn:aws:kms:us-west-2:xxx:key/yyy
export NODE_INSTANCE_PROFILE_arn=arn:aws:iam::xxx:instance-profile/yyy
```

## Cluster Creation

### Step 1: Create kOps State Bucket

```bash
aws s3api create-bucket \
  --bucket ${CLUSTER_NAME}-state \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
```

### Step 2: Generate Cluster Manifest

```bash
export KOPS_STATE_STORE=s3://${CLUSTER_NAME}-state

kops create cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --zones=us-west-2a,us-west-2b,us-west-2c \
  --node-count=3 \
  --node-size=t3.medium \
  --master-size=t3.medium \
  --master-count=3 \
  --networking=calico \
  --topology=private \
  --bastion \
  --cloud=aws \
  --vpc=${VPC_ID} \
  --subnets=${PRIVATE_SUBNET_IDS} \
  --utility-subnets=${PUBLIC_SUBNET_IDS} \
  --dns-zone=${HOSTED_ZONE_ID} \
  --kubernetes-version=1.28.0 \
  --encryption=${KMS_KEY_ARN} \
  --node-instance-profile=${NODE_INSTANCE_PROFILE_ARN}
```

### Step 3: Create SSH Key Secret

```bash
kops create secret \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  ssh-publickey admin -i ~/.ssh/id_rsa.pub
```

### Step 4: Update Cluster

```bash
kops update cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --yes
```

### Step 5: Validate Cluster

```bash
kops validate cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --wait 10m
```

## Cluster Bootstrap

### Step 1: Configure kubectl

```bash
kops export kubecfg --name=${CLUSTER_NAME} --admin
kubectl get nodes
```

### Step 2: Bootstrap Add-ons

```bash
ansible-playbook addons-bootstrap.yml \
  -e "environment=${ENVIRONMENT}" \
  -e "cluster_name=${CLUSTER_NAME}"
```

This installs:
- Metrics Server
- Cluster Autoscaler (with IRSA)
- External DNS (with IRSA)
- NGINX Ingress Controller
- Cert Manager (with IRSA)
- External Secrets Operator

### Step 3: Verify Add-ons

```bash
kubectl get pods -A
kubectl get svc -A
```

## Cluster Upgrade

### Step 1: Check Current Version

```bash
kubectl version --short
```

### Step 2: Update Cluster Version

```bash
export TARGET_VERSION=1.28.1

kops update cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --kubernetes-version=${TARGET_VERSION} \
  --yes
```

### Step 3: Rolling Upgrade

```bash
kops rolling-update cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --yes \
  --force
```

### Step 4: Validate After Upgrade

```bash
kops validate cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --wait 15m
```

## Cluster Destruction

### Step 1: Delete Cluster

```bash
kops delete cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --yes
```

### Step 2: Delete State Bucket

```bash
aws s3 rb ${KOPS_STATE_STORE} --force
```

## Day 2 Operations

### Scale Cluster

```bash
kops edit cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE}
# Edit node count
kops update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
```

### Add Node Pool

```bash
kops edit ig nodes --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE}
kops update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
kops rolling-update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
```

### Update SSH Keys

```bash
kops delete secret --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} ssh-publickey admin
kops create secret --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} ssh-publickey admin -i ~/.ssh/new_key.pub
kops update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
```

## Troubleshooting

### Cluster Not Ready

```bash
kops validate cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE}
kubectl get nodes
kubectl describe node <node-name>
```

### Pod Not Scheduling

```bash
kubectl describe pod <pod-name>
kubectl get nodes -o wide
kubectl top nodes
```

### Add-on Installation Failed

```bash
kubectl logs -n <namespace> <pod-name>
helm list -A
helm history <release-name>
```

### IRSA Issues

```bash
kubectl describe serviceaccount <sa-name> -n <namespace>
aws iam get-role --role-name <role-name>
```

## Rollback

### Rollback Cluster Upgrade

```bash
kops update cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --kubernetes-version=<previous-version> \
  --yes

kops rolling-update cluster \
  --name=${CLUSTER_NAME} \
  --state=${KOPS_STATE_STORE} \
  --yes
```

### Rollback Add-on Changes

```bash
helm rollback <release-name> -n <namespace>
```

## Emergency Procedures

### Cluster Unreachable

1. Check bastion host status
2. Verify security group rules
3. Check VPC route tables
4. Verify NAT Gateway status

### Master Node Failure

```bash
kops get instancegroups --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE}
kops replace --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE}
kops update cluster --name=${CLUSTER_NAME} --state=${KOPS_STATE_STORE} --yes
```

### Complete Cluster Recovery

1. Restore from kOps state backup
2. Re-run cluster creation with existing state
3. Validate cluster health

## Monitoring

Set up monitoring for:
- Node health
- Pod status
- Resource utilization
- Cluster autoscaler events
- Ingress controller metrics
