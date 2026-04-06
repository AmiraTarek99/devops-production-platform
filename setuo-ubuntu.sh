#!/bin/bash
# ──────────────────────────────
# Jenkins CI/CD Environment Setup Script for Ubuntu 22.04
# ──────────────────────────────

set -e

echo "=== Updating system ==="
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y git wget unzip curl build-essential software-properties-common

# ──────────────────────────────
echo "=== Installing Java 21 ==="
sudo apt install -y openjdk-21-jdk
java -version

# ──────────────────────────────
# Jenkins
echo "=== Installing Jenkins ==="
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins --no-pager

# ──────────────────────────────
# Docker
echo "=== Installing Docker ==="
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Add Jenkins to docker group
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu

echo "⚠️ Restart Jenkins after script to apply Docker permissions"

# ──────────────────────────────
# Terraform (latest)
echo "=== Installing Terraform ==="
T_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/v//')

wget https://releases.hashicorp.com/terraform/${T_VERSION}/terraform_${T_VERSION}_linux_amd64.zip
unzip terraform_${T_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform -version

# ──────────────────────────────
# AWS CLI v2
echo "=== Installing AWS CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# ──────────────────────────────
# kubectl
echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# ──────────────────────────────
# Helm
echo "=== Installing Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ──────────────────────────────
# Python 3.11 (native on Ubuntu)
echo "=== Installing Python 3.11 ==="
sudo apt install -y python3.11 python3.11-venv python3-pip
python3.11 --version

# Upgrade pip
python3.11 -m pip install --upgrade pip setuptools wheel

# ──────────────────────────────
# Node.js (LTS - v20)
echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

node -v
npm -v

# ──────────────────────────────
# Testing Tools
echo "=== Installing Testing Tools ==="
pip3 install flake8 pytest
sudo npm install -g jest

# ──────────────────────────────
# Final Check
echo "=== Installed Versions ==="
jenkins --version
docker --version
terraform -version
aws --version
kubectl version --client
helm version
python3.11 --version
node -v
npm -v

echo "=== DONE ==="
echo "👉 Access Jenkins: http://<EC2-IP>:8080"
echo "👉 Get admin password:"
echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "👉 Restart Jenkins after setup:"
echo "sudo systemctl restart jenkins"