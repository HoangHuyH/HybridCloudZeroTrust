#!/bin/bash
# =============================================================================
# WORKLOAD SETUP SCRIPT - AWS K3S WORKER
# =============================================================================
# This script configures the workload instance to join K3s cluster
# =============================================================================

set -e

# Update system
apt-get update
apt-get install -y curl wget apt-transport-https ca-certificates

# Wait for network connectivity to OpenStack (via WireGuard)
echo "Waiting for VPN connectivity to K3s master..."
sleep 60  # Wait for WireGuard to be established

# Check connectivity
for i in {1..30}; do
    if ping -c 1 ${k3s_master_ip} &> /dev/null; then
        echo "K3s master is reachable"
        break
    fi
    echo "Waiting for K3s master connectivity... ($i/30)"
    sleep 10
done

# Install K3s agent if token is provided
if [ -n "${k3s_token}" ]; then
    echo "Installing K3s agent and joining cluster..."
    curl -sfL https://get.k3s.io | K3S_URL="https://${k3s_master_ip}:6443" K3S_TOKEN="${k3s_token}" sh -s - agent
    
    echo "K3s agent installed and joined cluster"
else
    echo "K3s token not provided, skipping cluster join"
    echo "To join manually, run:"
    echo "curl -sfL https://get.k3s.io | K3S_URL=\"https://${k3s_master_ip}:6443\" K3S_TOKEN=\"<token>\" sh -s - agent"
fi

# Install monitoring agent (node_exporter for Prometheus)
echo "Installing node_exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Create systemd service for node_exporter
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "$(date): Workload setup completed" >> /var/log/workload-setup.log
