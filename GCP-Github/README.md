# Task Manager Pro — Cloud-Native API on Google Cloud (GKE)

A production-oriented Task Manager microservice built with **Node.js, Express, PostgreSQL 15, and Redis 7**, designed for deployment on Google Cloud Platform (**GCP GKE**) with automated keyless **GitHub Actions CI/CD pipelines** powered by **Workload Identity Federation (WIF)**.

---

## 🚀 Architecture Overview

```text
                      +------------------------------------+
                      |    GCP Cloud HTTP(S) Load Balancer |
                      |         (GKE GCE Ingress)          |
                      |        (tasks.example.com)         |
                      +-----------------+------------------+
                                        |
                                        v
                      +------------------------------------+
                      |      Kubernetes Service (Port 80)  |
                      |            (app: task-api)         |
                      +-----------------+------------------+
                                        |
                                        v
                      +------------------------------------+
                      |       Task API Pods (Port 3000)    |
                      |         (HPA: 3-10 replicas)       |
                      +---------+----------------+---------+
                                |                |
                                v                v
              +---------------------+       +---------------------+
              |  Redis Cache (6379) |       |  PostgreSQL DB(5432)|
              |      (60s TTL)      |       |    (tasks table)    |
              +---------------------+       +---------------------+
```

---

## 🌐 Cloud Infrastructure (Terraform on GCP)

The `terraform/` directory provisions the complete infrastructure on Google Cloud Platform:

1. **VPC-Native Networking**:
   - Custom VPC network with private subnetwork
   - Secondary CIDR blocks for GKE Pods (`10.20.0.0/16`) and Services (`10.30.0.0/20`)
   - Cloud Router & Cloud NAT for outbound internet access without public node IPs

2. **Google Kubernetes Engine (GKE)**:
   - VPC-native GKE cluster (`task-manager-cluster`) in region `us-central1`
   - Managed autoscaling node pool (`1` to `4` nodes, `e2-medium`)
   - Workload Identity enabled on the cluster
   - Shielded VM instances with Secure Boot and integrity monitoring

3. **Keyless GitHub Actions OIDC Authentication**:
   - Workload Identity Pool: `github-pool`
   - Workload Identity Provider: `github-provider` (validates GitHub Actions OIDC tokens)
   - Service Account: `github-actions-deployer@<PROJECT_ID>.iam.gserviceaccount.com`
   - Zero static credentials or long-lived service account keys stored in GitHub!

---

## 🛠️ Step-by-Step Deployment Guide

### Step 1: Provision GCP Infrastructure with Terraform

```bash
# 1. Login to Google Cloud:
gcloud auth login
gcloud auth application-default login

# 2. Enter terraform directory:
cd terraform
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars with your GCP project ID:
# project_id = "your-actual-gcp-project-id"

# 4. Initialize and apply:
terraform init
terraform plan
terraform apply -auto-approve
```

*(GKE cluster provisioning takes approximately 5–8 minutes).*

---

### Step 2: Configure GitHub Repository Secrets

After `terraform apply` finishes, obtain the Workload Identity Federation outputs:

```bash
terraform output -raw gcp_workload_identity_provider
terraform output -raw gcp_service_account
```

In your GitHub repository (**Settings > Secrets and variables > Actions**), add these two secrets:

| Secret Name | Description | Example Value |
| :--- | :--- | :--- |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full resource name of the provider | `projects/123456789012/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | Email of the deployer service account | `github-actions-deployer@your-project-id.iam.gserviceaccount.com` |

---

### Step 3: Connect Local `kubectl` to GKE

```bash
gcloud container clusters get-credentials task-manager-cluster --region us-central1 --project <your-project-id>
kubectl get nodes
```

---

### Step 4: Deploy Kubernetes Workloads Manually (Optional)

To apply the manifests in `k8s/` manually:

```bash
# 1. Create the dedicated namespace:
kubectl apply -f k8s/namespace.yaml

# 2. Create the required Kubernetes secret for DB credentials:
kubectl create secret generic task-api-secrets \
  --namespace=task-manager \
  --from-literal=DB_HOST=your-postgres-host \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=taskdb \
  --from-literal=DB_USER=postgres \
  --from-literal=DB_PASSWORD=your-secure-password \
  --from-literal=REDIS_URL=redis://your-redis-host:6379

# 3. Apply all workloads (Deployment, Service, Ingress, HPA, PDB):
kubectl apply -f k8s/

# 4. Verify deployment status:
kubectl get pods -n task-manager
kubectl get svc -n task-manager
kubectl get ingress -n task-manager
kubectl get hpa -n task-manager

# 5. Check real-time pod logs:
kubectl logs -f -l app=task-api -n task-manager

# 6. Port forward to test locally:
kubectl port-forward svc/task-api 3000:80 -n task-manager
```

---

## 💻 Local Development & Testing

### Method A: Run with Docker Compose (Recommended)

Starts the entire stack with PostgreSQL and Redis in isolated containers:

```bash
# Start all services (API, PostgreSQL, Redis) with fresh build:
docker compose up --build

# Or start in detached background mode:
docker compose up -d --build

# View container logs:
docker compose logs -f

# Check container health and status:
docker compose ps

# Stop all containers:
docker compose down

# Stop and wipe database/cache volumes to start clean:
docker compose down -v
```

---

### Method B: Run Directly with Node.js

```bash
# 1. Install dependencies:
npm install

# 2. Copy the environment variables:
cp .env.example .env

# 3. Run database migrations:
node src/server/migrations.js

# 4. Start development server:
npm run dev
```

---

## 📋 Comprehensive System Verification Checklist

Use these verification commands to test and validate every component of the system:

### Check 1: Liveness Health Probe
Verifies that the Node.js Express process is up and responding.
```bash
curl -i http://localhost:3000/live
# Expected Output: HTTP/1.1 200 OK {"status":"alive"}
```

---

### Check 2: Readiness Probe (PostgreSQL & Redis Health)
Verifies database query execution (`SELECT 1`) and Redis client ping (`PONG`).
```bash
curl -i http://localhost:3000/ready
# Expected Output: HTTP/1.1 200 OK {"status":"ready"}
```

---

### Check 3: Database & Cache Metrics
Inspects database mode, task counts, and Redis cache hit/miss counters.
```bash
curl -s http://localhost:3000/api/stats | jq .
```

---

### Check 4: Create Task API (`POST /tasks`)
```bash
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Verify GCP GKE deployment pipeline"}'
# Expected Output: HTTP/1.1 201 Created
```

---

### Check 5: Input Validation & Edge Case Handling (HTTP 400)
```bash
# Empty body:
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{}'
# Expected Output: HTTP/1.1 400 Bad Request {"error":"Title is required"}
```

---

### Check 6: Cache Verification (Redis Hit vs Miss)
```bash
# First fetch (populates cache):
curl -i http://localhost:3000/tasks

# Second fetch (served from Redis cache):
curl -i http://localhost:3000/tasks

# Inspect Redis keys & remaining TTL:
docker compose exec redis redis-cli ttl tasks:all
```

---

### Check 7: Update & Delete Operations
```bash
# Toggle status:
curl -i -X PATCH http://localhost:3000/tasks/1

# Delete task:
curl -i -X DELETE http://localhost:3000/tasks/1
```

---

### Check 8: Automated Test Suite Execution
```bash
npm test
# Expected Output:
# PASS tests/app.test.js
# Test Suites: 1 passed, 1 total
# Tests:       5 passed, 5 total
```

---

### Check 9: Code Style & TypeScript Verification
```bash
npm run lint
# Expected Output: Clean exit with code 0 (0 errors, 0 warnings)
```

---

### Check 10: Docker Multi-Stage Build & Container Health
```bash
# 1. Build the production image:
docker build -t task-manager-pro:local .

# 2. Verify non-root user security:
docker image inspect task-manager-pro:local --format 'User: {{.Config.User}}'
# Expected: User: appuser
```

---

### Check 11: Kubernetes Manifests Validation (Dry-Run)
```bash
kubectl apply --dry-run=client -f k8s/
```

---

## 🔒 Security Summary

- **Workload Identity Federation (WIF)**: Eliminates static GCP Service Account JSON keys. GitHub Actions requests short-lived Google Cloud access tokens using OIDC federation.
- **Least-Privilege Node SA**: Worker nodes only have permissions to log and publish metrics (`logging.logWriter`, `monitoring.metricWriter`).
- **Container Non-Root User**: Docker container runs as unprivileged user `appuser` (UID: 10001).
- **VPC-Native Cluster**: Pods receive native VPC subnet IPs with private nodes fronted by Cloud NAT.
