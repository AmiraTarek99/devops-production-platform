# 🌍 General
aws_region   = "us-east-1"
project_name = "devops-platform"
environment  = "production"

# 🌐 Networking
vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnets = [
  "10.0.10.0/24",
  "10.0.20.0/24"
]

# ☸️ EKS
eks_cluster_version = "1.29"


key_pair_name = "devops-key"

db_password = "12345"