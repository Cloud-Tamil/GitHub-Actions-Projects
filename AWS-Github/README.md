# Task Manager Pro — Cloud-Native API

A production-oriented Task Manager microservice built with **Node.js, Express, PostgreSQL 15, and Redis 7**, designed for deployment on Kubernetes (**AWS EKS**) with automated **GitHub Actions CI/CD pipelines**.

---

## 🚀 Architecture Overview

```
                      +-----------------------------+
                      |       AWS ALB Ingress       |
                      |     (tasks.example.com)     |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |   Kubernetes Service (80)   |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |      Task API Pods (3000)   |
                      |   (HPA: 3-10 replicas)      |
                      +-------+-------------+-------+
                              |             |
                              v             v
             +--------------------+     +--------------------+
             |  Redis Cache (6379)|     | PostgreSQL DB(5432)|
             |    (60s TTL)       |     |  (tasks table)     |
             +--------------------+     +--------------------+
```

---

## 🛠️ Complete Local Access & Useful Commands Guide

### 1. Prerequisites Setup
Ensure you have the following installed on your local machine:
- **Node.js**: v20 or v22 (`node -v`)
- **Docker & Docker Compose**: (`docker -v`, `docker compose version`)
- **Git**: (`git --version`)
- **curl** or **Postman/HTTPie** for testing API endpoints

Clone your repository locally:
```bash
git clone https://github.com/Cloud-Tamil/GitHub-Projects.git
cd GitHub-Projects
```

---

### 2. Method A: Run Everything with Docker Compose (Recommended)
This is the simplest way to run the entire stack with PostgreSQL and Redis pre-configured in isolated containers.

```bash
# Start all services (API, PostgreSQL, Redis) with fresh build in foreground
docker compose up --build

# Or start in detached background mode:
docker compose up -d --build

# View container logs in real time:
docker compose logs -f

# View logs for a specific service:
docker compose logs -f api
docker compose logs -f postgres
docker compose logs -f redis

# Check container health and status:
docker compose ps

# Stop all containers:
docker compose down

# Stop and wipe database/cache volumes to start clean:
docker compose down -v
```

---

### 3. Method B: Run Directly with Node.js & Local Dependencies

```bash
# 1. Install all dependencies (using the generated package-lock.json)
npm install

# 2. Copy the example environment variables file
cp .env.example .env

# 3. If you have PostgreSQL & Redis running locally:
# DB_HOST=localhost, DB_PORT=5432, DB_NAME=taskdb, DB_USER=postgres, DB_PASSWORD=postgres
# REDIS_URL=redis://localhost:6379

# 4. Run database migrations:
node src/server/migrations.js

# 5. Start the development server (with live auto-reload):
npm run dev

# 6. Start the production server:
npm start
```

---

### 4. Running Tests & Code Quality Checks

```bash
# Run the complete automated test suite (Jest + Supertest):
npm test

# Run tests in watch mode (reruns on file changes):
npx jest --watch

# Run tests with code coverage report:
npm test -- --coverage

# Run ESLint linter across source files and tests:
npm run lint

# Automatically fix fixable ESLint formatting issues:
npx eslint src/ tests/ --fix
```

---

### 5. Useful API Commands (curl & CLI)

Once your application is running on `http://localhost:3000`:

#### Liveness Probe
```bash
curl -i http://localhost:3000/live
# Expected: HTTP 200 {"status":"alive"}
```

#### Readiness Probe (Pings Postgres & Redis)
```bash
curl -i http://localhost:3000/ready
# Expected: HTTP 200 {"status":"ready"}
```

#### Fetch All Tasks (Caches in Redis with 60s TTL)
```bash
curl -i http://localhost:3000/tasks
```

#### Create a New Task
```bash
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Deploy task-api to Kubernetes cluster"}'
```

#### Test Input Validation (Empty Body - Expects HTTP 400)
```bash
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{}'
# Expected: HTTP 400 {"error":"Title is required"}
```

#### Toggle Task Completed Status
```bash
curl -i -X PATCH http://localhost:3000/tasks/1
```

#### Delete a Task
```bash
curl -i -X DELETE http://localhost:3000/tasks/1
```

#### Inspect Live Cache & DB Stats
```bash
curl -i http://localhost:3000/api/stats
```

---

### 6. Useful Database & Redis Debugging Commands

When running with Docker Compose:

#### Access the PostgreSQL Database via psql:
```bash
# Open interactive PostgreSQL shell:
docker compose exec -it postgres psql -U postgres -d taskdb

# Useful psql queries inside the shell:
\dt                  # List tables
SELECT * FROM tasks; # View all tasks
\q                   # Exit psql
```

#### Access the Redis CLI:
```bash
# Open interactive Redis CLI:
docker compose exec -it redis redis-cli

# Useful redis-cli commands:
ping                 # Returns PONG
keys *               # View all cached keys (e.g. tasks:all)
ttl tasks:all        # Check remaining seconds before cache expires
get tasks:all        # View cached JSON data
flushall             # Clear all cache
exit                 # Exit redis-cli
```

---

### 7. Kubernetes Deployment Commands

To deploy the manifests in `k8s/` to an active Kubernetes cluster (Minikube, Kind, or AWS EKS):

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

## 📋 Comprehensive System Verification & Health Check Checklist

Use these verification commands to test and validate every component of the system end-to-end:

### Check 1: Liveness Health Probe
Verifies that the Node.js Express process is up and responding to traffic.
```bash
curl -i http://localhost:3000/live
# Expected Output:
# HTTP/1.1 200 OK
# Content-Type: application/json; charset=utf-8
# {"status":"alive"}
```

---

### Check 2: Readiness Probe (PostgreSQL & Redis Health)
Verifies database query execution (`SELECT 1`) and Redis client ping (`PONG`).
```bash
curl -i http://localhost:3000/ready
# Expected Output:
# HTTP/1.1 200 OK
# Content-Type: application/json; charset=utf-8
# {"status":"ready"}
```

---

### Check 3: Database & Cache Metrics Check
Inspects database mode, task counts, and Redis cache hit/miss counters in real time.
```bash
curl -s http://localhost:3000/api/stats | jq .
# Expected Output:
# {
#   "database": { "mode": "Connected", "totalTasks": 3, "completedTasks": 1, "pendingTasks": 2 },
#   "cache": { "mode": "Active", "hits": 5, "misses": 1, "keys": ["tasks:all"] },
#   "environment": { "port": 3000, "nodeEnv": "development" }
# }
```

---

### Check 4: Create Task API (`POST /tasks`)
Verifies task insertion and cache invalidation.
```bash
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Verify complete system pipeline"}'
# Expected Output:
# HTTP/1.1 201 Created
# {"id":4,"title":"Verify complete system pipeline","completed":false,"created_at":"..."}
```

---

### Check 5: Input Validation & Edge Case Handling (HTTP 400)
Verifies that invalid requests without titles are cleanly rejected without throwing exceptions.
```bash
# Empty body:
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{}'
# Expected Output: HTTP/1.1 400 Bad Request {"error":"Title is required"}

# Blank whitespace string:
curl -i -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "   "}'
# Expected Output: HTTP/1.1 400 Bad Request {"error":"Title is required"}
```

---

### Check 6: Cache Verification (Redis Hit vs Miss)
Verifies that subsequent `GET /tasks` requests serve from the Redis cache (`tasks:all` with 60s TTL).
```bash
# First fetch (populates cache):
curl -i http://localhost:3000/tasks

# Second fetch (served from Redis cache):
curl -i http://localhost:3000/tasks

# Inspect Redis keys & remaining TTL:
docker compose exec redis redis-cli ttl tasks:all
# Expected: positive integer <= 60 (seconds remaining)
```

---

### Check 7: Update & Delete Operations
Verifies task toggle and removal workflows.
```bash
# Toggle status:
curl -i -X PATCH http://localhost:3000/tasks/1

# Delete task:
curl -i -X DELETE http://localhost:3000/tasks/1
# Expected Output: HTTP/1.1 200 OK {"message":"Task deleted successfully","id":1}
```

---

### Check 8: Automated Test Suite Execution
Runs the full suite of unit and integration tests with Supertest.
```bash
npm test
# Expected Output:
# PASS tests/app.test.js
#   Task Manager API
#     ✓ GET /live returns 200
#     ✓ GET /ready returns 200
#     ✓ POST /tasks validates title
#     ✓ POST /tasks creates a task
#     ✓ GET /tasks returns tasks
# Test Suites: 1 passed, 1 total
# Tests:       5 passed, 5 total
```

---

### Check 9: Code Style & TypeScript/ESLint Verification
Verifies syntax, type safety, and formatting.
```bash
npm run lint
# Expected Output: Clean exit with code 0 (0 errors, 0 warnings)
```

---

### Check 10: Docker Multi-Stage Build & Container Health
Builds and runs the production Alpine container locally.
```bash
# 1. Build the production image:
docker build -t task-manager-pro:local .

# 2. Verify image layers and security non-root user:
docker image inspect task-manager-pro:local --format 'User: {{.Config.User}}'
# Expected: User: appuser

# 3. Test container healthcheck:
docker inspect --format='{{json .State.Health}}' $(docker compose ps -q api)
# Expected: {"Status":"healthy", ...}
```

---

### Check 11: Kubernetes Manifests Validation (Dry-Run)
Validates all Kubernetes manifests against schema rules before deploying.
```bash
kubectl apply --dry-run=client -f k8s/
# Expected Output:
# namespace/task-manager configured (dry run)
# deployment.apps/task-api configured (dry run)
# service/task-api configured (dry run)
# ingress.networking.k8s.io/task-api configured (dry run)
# horizontalpodautoscaler.autoscaling/task-api configured (dry run)
# poddisruptionbudget.policy/task-api configured (dry run)
```

