# 🚀 DevOps Production Platform

A production-grade multi-service application deployed on AWS EKS using a
full Jenkins CI/CD pipeline with Terraform infrastructure as code, Helm
chart deployments, and Prometheus/Grafana monitoring.

---

## 🏗️ Architecture

```
Developer pushes code to GitHub
            │
            ▼
    Jenkins Pipeline (Full CI/CD)
            │
    ┌───────┴────────────────────────────────────┐
    │  Stage 1  → Checkout code                  │
    │  Stage 2  → Test Backend  (pytest+flake8)  │
    │  Stage 3  → Test Frontend (npm test)       │
    │  Stage 4  → Build Docker images            │
    │  Stage 5  → Push to AWS ECR               │
    │  Stage 6  → Terraform Init                 │
    │  Stage 7  → Terraform Plan                 │
    │  Stage 8  → Terraform Apply  ← infra here  │
    │  Stage 9  → Configure kubectl + secrets    │
    │  Stage 10 → Helm deploy → DEV             │
    │  Stage 11 → Smoke test DEV                │
    │  Stage 12 → Manual Approval Gate ⛔        │
    │  Stage 13 → Helm deploy → PRODUCTION      │
    │  Stage 14 → Verify production             │
    │  Stage 15 → Deploy Monitoring (optional)  │
    └────────────────────────────────────────────┘
            │
            ▼
    AWS Infrastructure (Terraform managed)
    ┌──────────────────────────────────────────┐
    │  VPC  │  EKS  │  ECR  │  RDS  │  S3     │
    │  Jenkins EC2 (runs the pipeline)         │
    └──────────────────────────────────────────┘
```

---

## 🛠️ Full Tech Stack

| Layer          | Tool                          | Purpose                        |
|----------------|-------------------------------|--------------------------------|
| CI/CD          | Jenkins                       | Full pipeline with approval    |
| Infrastructure | Terraform                     | All AWS resources as code      |
| Containers     | Docker + AWS ECR              | Build and store images         |
| Orchestration  | AWS EKS (Kubernetes)          | Run containers in production   |
| Packaging      | Helm                          | K8s deployments + versioning   |
| Monitoring     | Prometheus + Grafana          | Metrics and dashboards         |
| Database       | AWS RDS PostgreSQL            | Managed database               |
| Storage        | AWS S3                        | Logs and static assets         |
| Registry       | AWS ECR                       | Private Docker image registry  |

---

## 📁 Project Structure

```
devops-platform/
│
├── backend/                    Flask API application
│   ├── app.py                  Main application
│   ├── test_app.py             Pytest tests
│   ├── requirements.txt        Python dependencies
│   ├── Dockerfile              Multi-stage production build
│   └── .dockerignore
│
├── frontend/                   React application
│   ├── src/App.jsx             Main React component
│   ├── public/index.html
│   ├── package.json
│   ├── Dockerfile              Multi-stage nginx build
│   └── nginx.conf              API proxy config
│
├── terraform/                  All AWS infrastructure as code
│   ├── provider.tf             AWS provider + S3 backend
│   ├── main.tf                 Calls all modules
│   ├── variables.tf            All input variables
│   ├── outputs.tf              All output values
│   └── modules/
│       ├── vpc/                VPC, subnets, NAT, routing
│       ├── eks/                EKS cluster + node groups + addons
│       ├── ecr/                ECR repos for backend + frontend
│       ├── rds/                PostgreSQL database
│       └── jenkins/            Jenkins EC2 + IAM + bootstrap
│
├── helm/                       Helm charts for Kubernetes
│   ├── backend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml         Production values
│   │   ├── values-dev.yaml     Dev overrides
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       └── service-hpa.yaml
│   └── frontend/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       └── templates/
│           └── deployment.yaml
│
├── jenkins/
│   └── Jenkinsfile             Full 16-stage CI/CD pipeline
│
├── monitoring/
│   └── prometheus-values.yaml  Prometheus + Grafana config
│
├── docker-compose.yml          Local development
├── .gitignore
└── README.md
```

---

## 🚀 Day 1 — How to Run This Project

### Step 1 — Install tools on your machine
```bash
# Terraform
sudo apt install terraform -y

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 2 — Configure AWS
```bash
aws configure
# Enter: Access Key, Secret Key, region: us-east-1, format: json
```

### Step 3 — Create EC2 key pair for Jenkins
```bash
aws ec2 create-key-pair \
  --key-name devops-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/devops-key.pem
chmod 400 ~/.ssh/devops-key.pem
```

### Step 4 — Bootstrap Terraform state backend
```bash
# Create S3 bucket (change YOURNAME to something unique)
aws s3 mb s3://devops-platform-tfstate-YOURNAME --region us-east-1

aws s3api put-bucket-versioning \
  --bucket devops-platform-tfstate-YOURNAME \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then update `terraform/provider.tf`:
```hcl
bucket = "devops-platform-tfstate-YOURNAME"  # ← your actual bucket name
```

### Step 5 — Run Terraform
```bash
cd terraform
terraform init
terraform plan  -var="db_password=YourPass123!" -var="key_pair_name=devops-key"
terraform apply -var="db_password=YourPass123!" -var="key_pair_name=devops-key"
# Takes 15-20 minutes — EKS creation is slow
```

### Step 6 — Connect kubectl to EKS
```bash
aws eks update-kubeconfig --region us-east-1 --name devops-platform-production
kubectl get nodes   # Should show 2 Ready nodes
```

### Step 7 — Set up Jenkins
```bash
# Get Jenkins URL from Terraform output
terraform output jenkins_url

# SSH in and get admin password
ssh -i ~/.ssh/devops-key.pem ec2-user@JENKINS_IP
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open `http://JENKINS_IP:8080` in browser, unlock Jenkins, install
suggested plugins, create admin user.

### Step 8 — Add credentials to Jenkins

Go to: **Manage Jenkins → Credentials → Global → Add Credentials**

| ID                    | Kind          | Value                        |
|-----------------------|---------------|------------------------------|
| `AWS_ACCESS_KEY_ID`   | Secret text   | Your AWS access key          |
| `AWS_SECRET_ACCESS_KEY`| Secret text  | Your AWS secret key          |
| `ECR_BACKEND_URL`     | Secret text   | ECR backend URL from output  |
| `ECR_FRONTEND_URL`    | Secret text   | ECR frontend URL from output |
| `DB_PASSWORD`         | Secret text   | YourPass123!                 |
| `TF_KEY_PAIR_NAME`    | Secret text   | devops-key                   |

### Step 9 — Create Jenkins pipeline job

1. New Item → name: `devops-platform-deploy` → Pipeline → OK
2. Pipeline section → Definition: `Pipeline script from SCM`
3. SCM: Git → Repository URL: your GitHub URL
4. Branch: `*/main`
5. Script Path: `jenkins/Jenkinsfile`
6. Save

### Step 10 — Run the pipeline

Click **Build with Parameters**:
- `IMAGE_TAG` → `v1.0`
- `RUN_TERRAFORM` → checked
- `DEPLOY_MONITORING` → checked (first run)
- `TERRAFORM_ACTION` → `apply`

Click **Build** and watch it run through all 15 stages.

---

## 🔄 What Happens in Every Pipeline Run

```
1.  Checkout      → Clone latest code from GitHub
2.  Test Backend  → pytest + flake8 (fails = nothing deploys)
3.  Test Frontend → npm test
4.  Build Images  → docker build backend + frontend
5.  Push to ECR   → docker push with build tag + latest
6.  TF Init       → terraform init (connects to S3 backend)
7.  TF Plan       → terraform plan (saved to file)
8.  TF Apply      → terraform apply (uses saved plan)
9.  Configure K8s → kubectl + namespaces + secrets
10. Deploy DEV    → helm upgrade --install (dev namespace)
11. Smoke Test    → kubectl rollout status + health check
12. Approval Gate → human clicks approve in Jenkins UI
13. Deploy PROD   → helm upgrade --install (production namespace)
14. Verify        → kubectl get pods/svc/hpa
15. Monitoring    → helm install prometheus+grafana (if checked)
```

---

## 🔐 Security Features

- Non-root containers (appuser in backend)
- ECR image scanning on every push
- EKS nodes and RDS in private subnets only
- RDS not publicly accessible
- RDS storage encrypted at rest
- Jenkins uses IAM role — no hardcoded AWS keys on EC2
- K8s secrets for sensitive data — never in ConfigMaps
- .gitignore blocks all .pem, .env, and secret files

---

## 📊 Access Monitoring

```bash
# Port-forward Grafana to your local machine
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring

# Open in browser
http://localhost:3000
# Username: admin
# Password: DevOpsAdmin123
```

Import dashboard ID `315` for Kubernetes cluster overview.

---

## ♻️ Rollback

Helm automatically rolls back on failure (`--atomic` flag).
To manually rollback to previous version:

```bash
# See history
helm history backend -n production

# Rollback to previous release
helm rollback backend 1 -n production
```

---

## 💥 Destroy Everything

In Jenkins, run the pipeline with `TERRAFORM_ACTION = destroy`.
It will ask for confirmation before destroying.

Or manually:
```bash
cd terraform
terraform destroy -var="db_password=YourPass123!" -var="key_pair_name=devops-key"
```
