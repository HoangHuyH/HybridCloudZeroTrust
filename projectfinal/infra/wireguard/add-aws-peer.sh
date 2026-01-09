#!/bin/bash
# =============================================================================
# WIREGUARD CONFIGURATION HELPER - ADD AWS PEER
# =============================================================================
# Run this after AWS Terraform deployment to complete VPN setup
# =============================================================================

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <AWS_PUBLIC_KEY> <AWS_PUBLIC_IP>"
    echo "Example: $0 'abc123...' '54.123.45.67'"
    exit 1
fi

AWS_PUBLIC_KEY=$1
AWS_PUBLIC_IP=$2

echo "Adding AWS peer to WireGuard configuration..."

# Add peer to existing config
cat << EOF | sudo tee -a /etc/wireguard/wg0.conf

[Peer]
# AWS WireGuard Gateway
PublicKey = ${AWS_PUBLIC_KEY}
Endpoint = ${AWS_PUBLIC_IP}:51820
AllowedIPs = 10.100.0.0/16, 10.200.0.1/32
PersistentKeepalive = 25
EOF

echo "Restarting WireGuard..."
sudo systemctl restart wg-quick@wg0

echo "Checking VPN status..."
sudo wg show

echo ""
echo "Testing connectivity to AWS..."
ping -c 3 10.200.0.1 || echo "Ping failed - AWS instance may still be starting"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    VPN TUNNEL ESTABLISHED                            ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  OpenStack (10.200.0.2) <=========> AWS (10.200.0.1)                 ║"
echo "║                                                                      ║"
echo "║  Test connectivity:                                                  ║"
echo "║  - From OpenStack: ping 10.200.0.1                                  ║"
echo "║  - From AWS: ping 10.200.0.2                                        ║"
echo "║  - From OpenStack: ping 10.100.1.x (AWS private subnet)             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
