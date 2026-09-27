# Infrastructure as Code with Terraform

This directory provisions the complete AWS infrastructure required for the **Task Manager** production deployment and GitHub Actions OIDC pipeline.

## Infrastructure Provisioned

1. **VPC Networking**
   - 1 VPC spanning 2 Availability Zones
   - 2 Public Subnets
   - 2 Private Subnets for EKS worker nodes and Pods
   - Internet Gateway for public subnet internet access
   - NAT Gateway for private subnet outbound internet access
   - Route tables and subnet associations

2. **AWS EKS Cluster**
   - Cluster Name: `task-manager-cluster` (matches `.github/workflows/cd.yml`)
   - EKS Managed Node Group
   - Instance Type: `t3.medium`
   - Autoscaling: 1–3 nodes
   - Public and Private EKS API endpoint access

3. **GitHub Actions OIDC & IAM Role**
   - GitHub Actions OIDC Identity Provider:
     `token.actions.githubusercontent.com`
   - IAM Role using `AssumeRoleWithWebIdentity`
   - Trust policy restricted to:
     `repo:Cloud-Tamil/GitHub-Actions:*`
   - EKS Access Entry for the GitHub Actions IAM role
   - `AmazonEKSClusterAdminPolicy` association for `kubectl` deployments without long-lived AWS credentials

---

## Prerequisites

- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with AWS credentials

Verify your AWS credentials:

```bash
aws sts get-caller-identity
```

- [kubectl](https://kubernetes.io/docs/tasks/tools/)

Make sure your AWS CLI is configured for the same AWS account and region used by Terraform.

---

## Deployment Steps

### 1. Initialize Terraform

From the repository root:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
```

Update `terraform.tfvars` with your required values before continuing.

---

### 2. Preview Resources

Review the resources Terraform will create:

```bash
terraform plan
```

---

### 3. Provision Infrastructure

Apply the Terraform configuration:

```bash
terraform apply -auto-approve
```

AWS EKS provisioning can take approximately **10–20 minutes**, depending on AWS account and resource creation time.

---

### 4. Get the GitHub Actions IAM Role ARN

After Terraform finishes, retrieve the IAM role ARN:

```bash
terraform output -raw aws_role_arn
```

Copy the returned ARN.

---

### 5. Add the IAM Role ARN to GitHub

In the GitHub repository:

**Settings → Secrets and variables → Actions → Repository secrets**

Create:

```text
Name: AWS_ROLE_ARN
Value: <IAM role ARN returned by Terraform>
```

If the workflow uses a GitHub Environment such as `production`, configure the secret according to the environment's secret requirements.

The GitHub Actions workflow can then authenticate to AWS using OIDC without storing a long-lived AWS access key or secret key.

---

### 6. Configure Local Kubernetes Access

After the EKS cluster has been created:

```bash
aws eks update-kubeconfig \
  --name task-manager-cluster \
  --region us-east-1
```

Verify the cluster connection:

```bash
kubectl get nodes
```

You should see the EKS managed node group instances.

You can also verify the cluster:

```bash
kubectl cluster-info
```

---

## Cleanup / Destroy

To remove the infrastructure created by Terraform:

```bash
cd terraform
terraform destroy -auto-approve
```

**Warning:** This permanently deletes the Terraform-managed AWS resources. Make sure any required data or resources are backed up before running the command.
