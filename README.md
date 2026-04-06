# 🏗️ DevOps Platform — Infrastructure

Terraform infrastructure as code for the DevOps Production Platform.
Provisions all AWS resources through a Jenkins pipeline with Apply and Destroy buttons.

> **This is the infrastructure repository.**
> Application code, CI/CD pipelines, and Helm charts live in the companion repo:
> [`devops-platform-app`](https://github.com/AmiraTarek99/devops-platform-app.git)

---

## Table of Contents

- [What This Repo Does](#what-this-repo-does)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [AWS Resources Created](#aws-resources-created)
- [Prerequisites](#prerequisites)
- [Before You Start — One Time Setup](#before-you-start--one-time-setup)
- [Running the Infrastructure Pipeline](#running-the-infrastructure-pipeline)
- [Destroying Infrastructure](#destroying-infrastructure)
- [SSM Parameter Store](#ssm-parameter-store)
- [Terraform State](#terraform-state)
- [Modules](#modules)

---

## What This Repo Does

This repository manages two things:

**1. Bootstrap** (`terraform/bootstrap/`)
Run once from your laptop to create the Jenkins server.
After Jenkins exists it runs everything else — you never touch bootstrap again.

**2. Infrastructure** (`terraform/infrastructure/`)
Managed entirely by the Jenkins pipeline.
Creates the full AWS environment your application runs on.

```
You run bootstrap once  →  Jenkins EC2 is created
                              │
                              │  Jenkins runs infrastructure pipeline
                              ▼
                         VPC, EKS, ECR, RDS, S3, SSM created
                              │
                              │  App pipelines read from SSM
                              ▼
                         CI and Deploy pipelines work automatically
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS CLOUD                                 │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   VPC  10.0.0.0/16                       │   │
│  │                                                          │   │
│  │   Public Subnets              Private Subnets            │   │
│  │   ┌──────────────┐           ┌──────────────────────┐   │   │
│  │   │  Jenkins EC2 │           │   EKS Worker Nodes   │   │   │
│  │   │  (bootstrap) │           │   (private — no      │   │   │
│  │   └──────────────┘           │    public IP)        │   │   │
│  │   ┌──────────────┐           └──────────┬───────────┘   │   │
│  │   │  NAT Gateway │                      │               │   │
│  │   └──────┬───────┘           ┌──────────▼───────────┐   │   │
│  │          │ outbound only     │   RDS PostgreSQL      │   │   │
│  └──────────┼───────────────────│──────────────────────┼───┘   │
│             │                   └──────────────────────┘        │
│             ▼                                                    │
│        Internet                                                  │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   ECR    │  │    S3    │  │   SSM    │  │  CloudWatch  │   │
│  │ (images) │  │ (storage)│  │ (config) │  │   (logs)     │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
devops-platform-infra/
│
├── terraform/
│   │
│   ├── bootstrap/                  ← run once from your laptop
│   │   ├── provider.tf             S3 backend config (bootstrap state)
│   │   ├── main.tf                 Jenkins EC2 + VPC + IAM role
│   │   ├── variables.tf
│   │   └── outputs.tf              Jenkins URL + initial password command
│   │
│   └── infrastructure/             ← Jenkins pipeline runs this
│       ├── provider.tf             S3 backend config (infra state)
│       ├── main.tf                 calls all modules
│       ├── variables.tf
│       ├── outputs.tf
│       └── modules/
│           ├── vpc/                VPC, subnets, IGW, NAT Gateway, routes
│           ├── eks/                EKS cluster, node group, IAM roles, addons
│           ├── ecr/                ECR repos for backend and frontend
│           └── rds/                RDS PostgreSQL, subnet group, security group
│
└── jenkins/
    └── infrastructure/
        └── Jenkinsfile             Apply and Destroy pipeline
```

---

## AWS Resources Created

The infrastructure pipeline creates all of these:

| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16`, DNS enabled |
| Public subnets | 2 subnets across 2 availability zones |
| Private subnets | 2 subnets across 2 availability zones |
| Internet Gateway | Attached to VPC for public subnet access |
| NAT Gateway | Allows private subnet outbound internet |
| EKS Cluster | Kubernetes 1.29, control plane logs enabled |
| EKS Node Group | Managed, t3.medium, 1–5 nodes, desired 2 |
| EKS Addons | CoreDNS, kube-proxy, VPC CNI, EBS CSI driver |
| ECR — backend | Private repo, image scanning, lifecycle policy |
| ECR — frontend | Private repo, image scanning, lifecycle policy |
| RDS PostgreSQL | 15.4, db.t3.micro, encrypted, 7-day backups |
| S3 Bucket | App storage, versioning, AES256 encryption |
| SSM Parameters | ECR URLs, EKS name, RDS endpoint saved here |
| IAM Roles | EKS cluster role, node role, Jenkins role |

---

## Prerequisites

You need these installed on your laptop before running bootstrap.

### Install Terraform

```bash
# Ubuntu / Debian
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform -y

terraform -version
```

### Install AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws --version
```

### Configure AWS credentials

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, region (`us-east-1`), and output format (`json`).

Verify it works:

```bash
aws sts get-caller-identity
```

You should see your account ID printed. If you see an error your credentials are wrong.

---

## Before You Start — One Time Setup

These steps run once only. After this, everything else is automated.

### Step 1 — Create EC2 Key Pair

You need this to SSH into the Jenkins server.

```bash
aws ec2 create-key-pair \
  --key-name devops-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/devops-key.pem

chmod 400 ~/.ssh/devops-key.pem
```

Verify:

```bash
aws ec2 describe-key-pairs --key-names devops-key
```

### Step 2 — Create Terraform State Backend

Terraform saves its state in S3. The bucket and DynamoDB table must exist before Terraform can use them. You create them manually once.

```bash
# Replace YOURNAME with something unique — e.g. devops-platform-tfstate-amira
aws s3 mb s3://devops-platform-tfstate-YOURNAME --region us-east-1

# Enable versioning so you can recover old state if needed
aws s3api put-bucket-versioning \
  --bucket devops-platform-tfstate-YOURNAME \
  --versioning-configuration Status=Enabled

# Enable encryption — state file may contain sensitive values
aws s3api put-bucket-encryption \
  --bucket devops-platform-tfstate-YOURNAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket devops-platform-tfstate-YOURNAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
# Prevents two pipeline runs from applying Terraform simultaneously
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3 — Update Bucket Name in Provider Files

Open both provider files and replace `YOURNAME` with the bucket name you just created.

**File 1:** `terraform/bootstrap/provider.tf`

```hcl
backend "s3" {
  bucket = "devops-platform-tfstate-YOURNAME"  # ← change this
  key    = "bootstrap/terraform.tfstate"
  ...
}
```

**File 2:** `terraform/infrastructure/provider.tf`

```hcl
backend "s3" {
  bucket = "devops-platform-tfstate-YOURNAME"  # ← change this
  key    = "infrastructure/terraform.tfstate"
  ...
}
```

Push the changes:

```bash
git add terraform/bootstrap/provider.tf terraform/infrastructure/provider.tf
git commit -m "config: set terraform state bucket name"
git push
```

### Step 4 — Run Bootstrap Terraform

This creates only the Jenkins EC2. Run from your laptop, one time only.

```bash
cd terraform/bootstrap

# Download AWS provider
terraform init

# Preview what will be created
terraform plan -var="key_pair_name=devops-key"

# Create Jenkins EC2
terraform apply -var="key_pair_name=devops-key"
```

Type `yes` when asked.

When it finishes you will see:

```
Outputs:

jenkins_public_ip         = "1.2.3.4"
jenkins_url               = "http://1.2.3.4:8080"
initial_password_command  = "ssh -i ~/.ssh/devops-key.pem ec2-user@1.2.3.4 ..."
```

Save these values.

### Step 5 — Wait for Jenkins to Bootstrap

The Jenkins EC2 runs a bootstrap script on first start that installs all required tools:
Java, Jenkins, Docker, kubectl, Helm, Terraform, AWS CLI, Python, Node.js.

This takes about 5 minutes. Check progress:

```bash
# SSH into the Jenkins server
ssh -i ~/.ssh/devops-key.pem ec2-user@YOUR_JENKINS_IP

# Watch the bootstrap log
tail -f /var/log/bootstrap.log
```

Wait until you see `Bootstrap complete` at the bottom.

### Step 6 — Open Jenkins and Complete Setup

Open in your browser:

```
http://YOUR_JENKINS_IP:8080
```

Get the initial admin password:

```bash
ssh -i ~/.ssh/devops-key.pem ec2-user@YOUR_JENKINS_IP \
  "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

In the browser:
1. Paste the password → click **Continue**
2. Click **Install suggested plugins** → wait ~4 minutes
3. Create admin user → click **Save and Continue** → **Start using Jenkins**

### Step 7 — Add Credentials to Jenkins

Go to: **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

Add this credential:

```
Kind:        Secret text
ID:          DB_PASSWORD
Secret:      DevOpsPass123!
Description: RDS database password
```

This is the only credential you need to add manually.
ECR URLs, EKS cluster name, and RDS endpoint are all read from SSM at runtime.

### Step 8 — Create the Infrastructure Pipeline Job

1. Click **New Item**
2. Name: `devops-platform-infrastructure`
3. Select **Pipeline** → click **OK**

In the configuration page:

**General:**
- Check `Do not allow concurrent builds`

**Build Triggers:**
- Leave empty — this pipeline is manual only

**Pipeline:**
```
Definition:   Pipeline script from SCM
SCM:          Git
URL:          https://github.com/YOUR_USERNAME/devops-platform-infra.git
Branch:       */main
Script Path:  jenkins/infrastructure/Jenkinsfile
```

Click **Save**.

---

## Running the Infrastructure Pipeline

Now Jenkins manages all infrastructure. You never run `terraform apply` from your laptop again.

### To create or update infrastructure

1. In Jenkins click **devops-platform-infrastructure**
2. Click **Build with Parameters**
3. Set parameters:
   ```
   ACTION:       Apply
   AUTO_APPROVE: unchecked  (always review the plan first)
   ```
4. Click **Build**
5. Click the running build → click **Console Output**

**Watch each stage:**

```
Terraform Init
  Connects to S3 backend
  Downloads AWS provider plugin
  ✅ Terraform initialized

Terraform Plan
  Calculates what will be created/changed
  Saves plan to file
  Shows summary in console — read this carefully
  ✅ Plan complete

Approval Gate
  Pipeline pauses here
  Review the plan shown above
  Go back to pipeline view → click Confirm Apply
  ⛔ Waiting for your approval

Terraform Apply
  Creates all AWS resources
  EKS creation takes 15-20 minutes — this is normal
  Saves outputs to SSM Parameter Store
  ✅ Infrastructure ready
```

After apply completes the outputs are printed:

```
eks_cluster_name   = "devops-platform-production"
ecr_backend_url    = "123456789.dkr.ecr.us-east-1.amazonaws.com/devops-platform-backend"
ecr_frontend_url   = "123456789.dkr.ecr.us-east-1.amazonaws.com/devops-platform-frontend"
rds_endpoint       = "devops-platform-production-db.xxxxx.us-east-1.rds.amazonaws.com"
```

These are also automatically saved to SSM so your CI and Deploy pipelines can read them.

### Verify infrastructure is running

Connect kubectl to your new cluster:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name devops-platform-production

kubectl get nodes
```

Expected output:

```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-10-xxx.ec2.internal   Ready    <none>   5m    v1.29.x
ip-10-0-20-xxx.ec2.internal   Ready    <none>   5m    v1.29.x
```

Verify SSM parameters were saved:

```bash
aws ssm get-parameters-by-path \
  --path "/devops-platform" \
  --recursive \
  --region us-east-1 \
  --query "Parameters[*].{Name:Name,Value:Value}" \
  --output table
```

---

## Destroying Infrastructure

To tear down all AWS resources and stop incurring costs:

1. In Jenkins click **devops-platform-infrastructure**
2. Click **Build with Parameters**
3. Set parameters:
   ```
   ACTION:       Destroy
   AUTO_APPROVE: unchecked
   ```
4. Click **Build**

The pipeline will:
- Run `terraform plan -destroy` showing everything that will be deleted
- Pause and ask you to confirm
- Only then run `terraform destroy`

> **Warning:** Destroy deletes the RDS database including all data.
> Make sure you have backed up anything important before destroying.

To destroy only the Jenkins server (bootstrap):

```bash
cd terraform/bootstrap
terraform destroy -var="key_pair_name=devops-key"
```

---

## SSM Parameter Store

After Terraform apply, these parameters are saved automatically:

| Parameter | Type | Value |
|---|---|---|
| `/devops-platform/ecr/backend-url` | String | ECR backend repository URL |
| `/devops-platform/ecr/frontend-url` | String | ECR frontend repository URL |
| `/devops-platform/eks/cluster-name` | String | EKS cluster name |
| `/devops-platform/rds/endpoint` | SecureString | RDS connection endpoint |

The CI and Deploy pipelines in `devops-platform-app` read these at runtime:

```bash
# How pipelines read the ECR URL
aws ssm get-parameter \
  --name "/devops-platform/ecr/backend-url" \
  --region us-east-1 \
  --query "Parameter.Value" \
  --output text
```

This creates a clean contract between the infrastructure and application repos.
Terraform owns the values. Pipelines read them. No hardcoding anywhere.

---

## Terraform State

State is stored remotely in S3 with DynamoDB locking.

| | Bootstrap state | Infrastructure state |
|---|---|---|
| S3 key | `bootstrap/terraform.tfstate` | `infrastructure/terraform.tfstate` |
| Contains | Jenkins EC2 resources | VPC, EKS, ECR, RDS, S3 |
| Who runs it | You (once, from laptop) | Jenkins pipeline |

The two state files are separate so Jenkins infrastructure and the Jenkins server itself never interfere.

If a pipeline run fails and leaves a state lock:

```bash
# Find the lock ID in the error message then run:
cd terraform/infrastructure
terraform force-unlock LOCK_ID_HERE
```

---

## Modules

### `modules/vpc`

Creates the network foundation:

```
VPC 10.0.0.0/16
├── Public subnet  us-east-1a  10.0.1.0/24   ← NAT Gateway lives here
├── Public subnet  us-east-1b  10.0.2.0/24
├── Private subnet us-east-1a  10.0.10.0/24  ← EKS nodes live here
├── Private subnet us-east-1b  10.0.20.0/24  ← RDS lives here
├── Internet Gateway  → public subnets route here
└── NAT Gateway       → private subnets route here (outbound only)
```

EKS nodes are in private subnets — they have no public IP and cannot be reached from the internet directly.

### `modules/eks`

Creates the Kubernetes cluster:

```
EKS Control Plane  (AWS managed — you never touch this)
└── Managed Node Group
    ├── EC2 type:  t3.medium
    ├── Min nodes: 1
    ├── Max nodes: 5
    └── Desired:   2

Addons installed automatically:
  CoreDNS         → DNS resolution inside cluster
  kube-proxy      → network rules on nodes
  VPC CNI         → gives pods real VPC IP addresses
  EBS CSI driver  → persistent storage for pods
```

### `modules/ecr`

Creates two private Docker registries:

```
devops-platform-backend
  Image scanning: on every push
  Lifecycle policy: keep last 10 images, delete older ones

devops-platform-frontend
  Image scanning: on every push
  Lifecycle policy: keep last 10 images
```

### `modules/rds`

Creates the PostgreSQL database:

```
Engine:    PostgreSQL 15.4
Instance:  db.t3.micro
Storage:   20GB encrypted
Database:  taskdb
User:      taskuser

Security:
  In private subnet — not reachable from internet
  Security group allows port 5432 from VPC only (10.0.0.0/16)
  Storage encrypted with AES256
  Backups: 7 days retention
```