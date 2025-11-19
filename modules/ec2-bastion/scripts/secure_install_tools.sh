#!/bin/bash
# Secure installation script for bastion host
# Security hardening and tool installation

set -euo pipefail

# Variables
PROJECT_NAME="${project_name}"
ENV_NAME="${env_name}"
LOG_FILE="/var/log/bastion-setup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting secure bastion setup for $PROJECT_NAME-$ENV_NAME"

# Update system
log "Updating system packages"
yum update -y

# Install security tools
log "Installing security and monitoring tools"
yum install -y \
    fail2ban \
    aide \
    rkhunter \
    chkrootkit \
    htop \
    iotop \
    tcpdump \
    nmap-ncat \
    wget \
    curl \
    unzip \
    git

# Configure fail2ban
log "Configuring fail2ban"
systemctl enable fail2ban
systemctl start fail2ban

# Install AWS CLI v2
log "Installing AWS CLI v2"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
log "Installing kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install eksctl
log "Installing eksctl"
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

# Install Helm
log "Installing Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Security hardening
log "Applying security hardening"

# Disable unused services
systemctl disable postfix || true
systemctl stop postfix || true

# Configure SSH hardening
cat >> /etc/ssh/sshd_config << 'EOF'
# Security hardening
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
EOF

# Restart SSH service
systemctl restart sshd

# Configure automatic security updates
log "Configuring automatic security updates"
yum install -y yum-cron
systemctl enable yum-cron
systemctl start yum-cron

# Set up log rotation
log "Configuring log rotation"
cat > /etc/logrotate.d/bastion-logs << 'EOF'
/var/log/bastion-setup.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Configure CloudWatch agent (optional)
log "Installing CloudWatch agent"
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
rm -f ./amazon-cloudwatch-agent.rpm

# Create CloudWatch agent config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENV_NAME-bastion",
                        "log_stream_name": "{instance_id}/messages"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENV_NAME-bastion",
                        "log_stream_name": "{instance_id}/secure"
                    },
                    {
                        "file_path": "/var/log/bastion-setup.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENV_NAME-bastion",
                        "log_stream_name": "{instance_id}/setup"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "AWS/EC2/Custom",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Set up AIDE (file integrity monitoring)
log "Initializing AIDE database"
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Create daily AIDE check
cat > /etc/cron.daily/aide-check << 'EOF'
#!/bin/bash
/usr/sbin/aide --check | /bin/mail -s "AIDE Report $(hostname)" root
EOF
chmod +x /etc/cron.daily/aide-check

# Configure firewall (iptables basic rules)
log "Configuring basic firewall rules"
iptables -F
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 943 -j ACCEPT
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

# Enable iptables service
systemctl enable iptables
systemctl start iptables

# Create motd with security notice
cat > /etc/motd << 'EOF'
***************************************************************************
                    AUTHORIZED ACCESS ONLY
***************************************************************************
This system is for authorized users only. All activities are monitored
and logged. Unauthorized access is prohibited and will be prosecuted.
***************************************************************************
EOF

# Set proper permissions
chmod 644 /etc/motd

log "Bastion host security setup completed successfully"

# Create completion marker
touch /var/log/bastion-setup-complete

log "All installation and hardening tasks completed"
