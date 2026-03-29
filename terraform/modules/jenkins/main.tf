resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Jenkins CI/CD server security group"
  vpc_id      = var.vpc_id

  ingress { description = "SSH";         from_port = 22;    to_port = 22;    protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "Jenkins UI";  from_port = 8080;  to_port = 8080;  protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "JNLP agent";  from_port = 50000; to_port = 50000; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-jenkins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ])
  policy_arn = each.value
  role       = aws_iam_role.jenkins.name
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name";                values = ["amzn2-ami-hvm-*-x86_64-gp2"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # This script runs automatically when EC2 starts for the first time
  # It installs every tool Jenkins needs to run the pipeline
  user_data = <<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    echo "======================================"
    echo " Jenkins Bootstrap Starting"
    echo "======================================"

    # Update system
    yum update -y

    # ── Java (required for Jenkins) ──────────────────────────────────
    echo "Installing Java..."
    amazon-linux-extras install java-openjdk11 -y

    # ── Jenkins ──────────────────────────────────────────────────────
    echo "Installing Jenkins..."
    wget -O /etc/yum.repos.d/jenkins.repo \
      https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import \
      https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    yum install jenkins -y
    systemctl enable jenkins
    systemctl start jenkins

    # ── Docker ───────────────────────────────────────────────────────
    echo "Installing Docker..."
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -aG docker jenkins
    usermod -aG docker ec2-user

    # ── kubectl ──────────────────────────────────────────────────────
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s \
      https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # ── Helm ─────────────────────────────────────────────────────────
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # ── Terraform ────────────────────────────────────────────────────
    echo "Installing Terraform..."
    yum install -y yum-utils
    yum-config-manager \
      --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum install terraform -y

    # ── AWS CLI ──────────────────────────────────────────────────────
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
      -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip

    # ── Python 3 (for backend tests in pipeline) ─────────────────────
    echo "Installing Python..."
    yum install python3 python3-pip -y

    # ── Node.js (for frontend tests in pipeline) ─────────────────────
    echo "Installing Node.js..."
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    yum install nodejs -y

    # ── Git ──────────────────────────────────────────────────────────
    yum install git -y

    # ── Configure kubectl for EKS ────────────────────────────────────
    echo "Configuring kubectl for EKS..."
    aws eks update-kubeconfig \
      --region ${var.aws_region} \
      --name ${var.eks_cluster_name} || true

    # Copy kubeconfig so Jenkins user can access cluster
    mkdir -p /var/lib/jenkins/.kube
    aws eks update-kubeconfig \
      --region ${var.aws_region} \
      --name ${var.eks_cluster_name} \
      --kubeconfig /var/lib/jenkins/.kube/config || true
    chown -R jenkins:jenkins /var/lib/jenkins/.kube || true

    # Restart Jenkins so Docker group takes effect
    systemctl restart jenkins

    echo "======================================"
    echo " Bootstrap Complete!"
    echo " Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
    echo "======================================"
  EOF

  tags = { Name = "${var.project_name}-jenkins" }
}

output "jenkins_public_ip" { value = aws_instance.jenkins.public_ip }
output "jenkins_url"       { value = "http://${aws_instance.jenkins.public_ip}:8080" }
