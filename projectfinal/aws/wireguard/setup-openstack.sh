#!/bin/bash
# ============================================================
# WIREGUARD VPN SETUP - OPENSTACK SIDE
# Zero Trust Architecture - Hybrid Cloud Connectivity
# Run this on the OpenStack K8s master node
# ============================================================

set -e

echo "=========================================="
echo "  WireGuard VPN Setup - OpenStack Side"
echo "=========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Install WireGuard if not installed
if ! command -v wg &> /dev/null; then
    apt-get update
    apt-get install -y wireguard wireguard-tools
fi

# Configuration
OPENSTACK_VPN_IP="10.10.1.2"
AWS_VPN_IP="10.10.1.1"
AWS_NETWORK="10.10.0.0/16"
VPN_PORT="51820"

# Generate keys if not exist
if [ ! -f /etc/wireguard/privatekey ]; then
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
    chmod 600 /etc/wireguard/privatekey
    echo "Generated new WireGuard keys"
fi

OPENSTACK_PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
OPENSTACK_PUBLIC_KEY=$(cat /etc/wireguard/publickey)

echo ""
echo "OpenStack WireGuard Public Key: $OPENSTACK_PUBLIC_KEY"
echo "Save this key to configure AWS side!"
echo ""

# Prompt for AWS info
read -p "Enter AWS WireGuard Public Key: " AWS_PUBLIC_KEY
read -p "Enter AWS Public IP (Elastic IP): " AWS_PUBLIC_IP

# Create WireGuard config
cat > /etc/wireguard/wg0.conf << EOF
# ============================================================
# WireGuard VPN - OpenStack Side
# Zero Trust Architecture - Hybrid Cloud
# ============================================================

[Interface]
Address = ${OPENSTACK_VPN_IP}/24
PrivateKey = ${OPENSTACK_PRIVATE_KEY}
ListenPort = ${VPN_PORT}

# Enable forwarding
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

# AWS Peer
[Peer]
PublicKey = ${AWS_PUBLIC_KEY}
AllowedIPs = ${AWS_VPN_IP}/32, ${AWS_NETWORK}
Endpoint = ${AWS_PUBLIC_IP}:${VPN_PORT}
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo ""
echo "=========================================="
echo "  WireGuard VPN Started!"
echo "=========================================="
echo ""
echo "Status:"
wg show

echo ""
echo "To test connectivity from OpenStack to AWS:"
echo "  ping ${AWS_VPN_IP}"
echo "  curl http://${AWS_VPN_IP}:8080/health"
echo ""
echo "To access AWS API from K8s pods, use:"
echo "  http://${AWS_VPN_IP}:8080"
