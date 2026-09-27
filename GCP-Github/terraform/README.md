# Google Cloud Platform (GCP) Infrastructure with Terraform

This directory provisions complete Google Cloud Platform resources for the **Task Manager** production deployment and keyless GitHub Actions CI/CD via **Workload Identity Federation (WIF)**.

---

## Architecture Overview

1. **GCP Networking (VPC-Native)**:
   - Custom VPC network with private subnetwork
   - Secondary IP ranges for Kubernetes Pods and Services (IP aliasing)
   - Cloud Router & Cloud NAT for secure outbound internet access without public node IPs

2. **Google Kubernetes Engine (GKE)**:
   - Cluster Name: `task-manager-cluster` (matches `.github/workflows/cd.yml`)
   - Managed Node Pool with autoscaling (`1` to `4` nodes, `e2-medium`)
   - Workload Identity enabled on GKE
   - Shielded VM instances with Secure Boot enabled

3. **GitHub Actions Workload Identity Federation (Keyless OIDC)**:
   - **Workload Identity Pool**: `github-pool`
   - **Workload Identity Provider**: `github-provider` (validates GitHub OIDC JWT token)
   - **Dedicated Service Account**: `github-actions-deployer@<PROJECT_ID>.iam.gserviceaccount.com`
   - **IAM Binding**: `roles/iam.workloadIdentityUser` limited strictly to `repo:Cloud-Tamil/GitHub-Actions`
   - **RBAC / GKE Permissions**: `roles/container.developer` & `roles/container.clusterViewer` for zero-secret deployments

---

## Deployment Instructions

### 1. Prerequisites
- [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install)
- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
- Authenticate with GCP:
  ```bash
  gcloud auth login
  gcloud auth application-default login
  ```

### 2. Configure Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` with your GCP Project ID:
```hcl
project_id         = "your-actual-gcp-project-id"
gcp_region         = "us-central1"
cluster_name       = "task-manager-cluster"
github_repo        = "Cloud-Tamil/GitHub-Actions"
```

### 3. Initialize & Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

*(GKE cluster provisioning takes approximately 5–8 minutes).*

---

### 4. Configure GitHub Repository Secrets

After `terraform apply` finishes, run:
```bash
terraform output -raw gcp_workload_identity_provider
terraform output -raw gcp_service_account
```

In your GitHub repository (**Settings > Secrets and variables > Actions**), add these two secrets:

| Secret Name | Value Example |
| :--- | :--- |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/123456789012/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | `github-actions-deployer@your-project-id.iam.gserviceaccount.com` |

---

### 5. Connect Local `kubectl` (Optional)
```bash
terraform output -raw get_credentials_command
# or directly:
gcloud container clusters get-credentials task-manager-cluster --region us-central1 --project <your-project-id>
kubectl get nodes
```

---

### 6. Teardown / Destroy
```bash
terraform destroy -auto-approve
```
