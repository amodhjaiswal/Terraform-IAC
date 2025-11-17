#!/bin/bash
# ============================================================
# EC2 User Data Script
# Installs AWS CLI v2, kubectl, and eksctl on Ubuntu
# Logs output to /var/log/user-data.log
# ============================================================

# Log all output to console and file
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -e

echo "=== Starting system update ==="
apt-get update -y
apt-get upgrade -y

echo "=== Installing dependencies ==="
apt-get install -y unzip curl tar

# ------------------------------------------------------------
# Install AWS CLI v2
# ------------------------------------------------------------
echo "=== Installing AWS CLI v2 ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Verify AWS CLI installation
aws --version

# ------------------------------------------------------------
# Install kubectl (latest stable version)
# ------------------------------------------------------------
echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# Verify kubectl installation
kubectl version --client

# ------------------------------------------------------------
# Install eksctl
# ------------------------------------------------------------
echo "=== Installing eksctl ==="
curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
chmod +x /usr/local/bin/eksctl

# Verify eksctl installation
eksctl version

# ------------------------------------------------------------
# Save tool versions
# ------------------------------------------------------------
echo "=== Saving tool versions to /root/tool_versions.txt ==="
{
  echo "AWS CLI Version:"
  aws --version
  echo
  echo "kubectl Version:"
  kubectl version --client
  echo
  echo "eksctl Version:"
  eksctl version
} > /root/tool_versions.txt

echo "=== Installation completed successfully ==="
