FROM jenkins/jenkins:lts

USER root

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Clean + update + install (IMPORTANT FIX)
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update -y && \
    apt-get install -y \
        curl \
        unzip \
        gnupg \
        apt-transport-https \
        ca-certificates \
        lsb-release && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ─────────────────────────────
# Install AWS CLI v2
# ─────────────────────────────
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# ─────────────────────────────
# Install Terraform
# ─────────────────────────────
RUN curl -LO https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip \
    && unzip terraform_1.6.6_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_1.6.6_linux_amd64.zip

# ─────────────────────────────
# Install kubectl
# ─────────────────────────────
RUN curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# ─────────────────────────────
# Install Helm
# ─────────────────────────────
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash



USER jenkins