#!/bin/bash
# ──────────────────────────────
# Jenkins CI/CD Environment Setup Script for Amazon Linux 2
# Installs Jenkins, Docker, Terraform, AWS CLI, kubectl, Helm, Python 3.11, Node.js
# ──────────────────────────────

set -e  # Exit on any error

echo "=== Updating system packages ==="
sudo yum update -y
sudo yum install -y git wget unzip curl gcc gcc-c++ make lsb-release

# ──────────────────────────────
# Java (required for Jenkins)
echo "=== Installing Java 17 (Amazon Corretto) ==="
sudo yum install -y java-17-amazon-corretto-devel
java -version

# ──────────────────────────────
# Jenkins
echo "=== Installing Jenkins ==="
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install -y jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins

# ──────────────────────────────
# Docker
echo "=== Installing Docker ==="
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker jenkins
echo "Docker installed. Restart Jenkins to pick up docker group permissions."

# ──────────────────────────────
# Terraform
echo "=== Installing Terraform ==="
T_VERSION="1.6.4"
wget https://releases.hashicorp.com/terraform/${T_VERSION}/terraform_${T_VERSION}_linux_amd64.zip
unzip terraform_${T_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform -version

# ──────────────────────────────
# AWS CLI v2
echo "=== Installing AWS CLI v2 ==="
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
# Python 3.11
echo "=== Installing Python 3.11 ==="
# Install dependencies for building Python
sudo yum groupinstall "Development Tools" -y
sudo yum install -y gcc libffi-devel bzip2 bzip2-devel xz-devel zlib-devel wget make

# Download Python 3.11 source
cd /usr/src
sudo wget https://www.python.org/ftp/python/3.11.8/Python-3.11.8.tgz
sudo tar xzf Python-3.11.8.tgz
cd Python-3.11.8

# Build and install
sudo ./configure --enable-optimizations
sudo make altinstall   # altinstall avoids overwriting default python
python3.11 --version

# Install venv and pip
sudo python3.11 -m ensurepip --upgrade
sudo python3.11 -m pip install --upgrade pip setuptools wheel

# ──────────────────────────────
# Node.js (LTS) + npm
echo "=== Installing Node.js LTS ==="
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
sudo yum install -y nodejs
node -v
npm -v

# ──────────────────────────────
# Backend / Frontend Testing Tools
echo "=== Installing Python and Node test tools ==="
sudo pip3 install flake8 pytest
sudo npm install -g jest

# ──────────────────────────────
# Summary
echo "=== Installation complete ==="
jenkins --version
docker --version
terraform -version
aws --version
kubectl version --client
helm version
python3.11 --version
node -v
npm -v

echo "=== IMPORTANT: Restart Jenkins to apply Docker group changes ==="
echo "sudo systemctl restart jenkins"