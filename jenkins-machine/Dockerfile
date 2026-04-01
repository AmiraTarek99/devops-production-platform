FROM jenkins/jenkins:lts

USER root

ENV DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────
# Base packages
# ─────────────────────────────
RUN apt-get update -y && \
    apt-get install -y \
        curl \
        unzip \
        gnupg \
        apt-transport-https \
        ca-certificates \
        lsb-release \
        jq && \
    rm -rf /var/lib/apt/lists/*

# ─────────────────────────────
# Install AWS CLI v2 (latest)
# ─────────────────────────────
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip && \
    unzip -q awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# ─────────────────────────────
# Install Terraform (latest)
# ─────────────────────────────
RUN TERRAFORM_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name | sed 's/v//') && \
    curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# ─────────────────────────────
# Install kubectl (latest stable)
# ─────────────────────────────
RUN KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt) && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# ─────────────────────────────
# Install Helm (latest)
# ─────────────────────────────
RUN HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name) && \
    curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 helm-${HELM_VERSION}-linux-amd64.tar.gz

# ─────────────────────────────
# Verify installations (optional but recommended)
# ─────────────────────────────
RUN terraform -version && \
    kubectl version --client && \
    helm version && \
    aws --version

USER jenkins