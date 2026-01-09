#!/bin/bash
# ============================================================
# WIREGUARD VPN SETUP - AWS SIDE
# Zero Trust Architecture - Hybrid Cloud Connectivity
# ============================================================

set -e

echo "=========================================="
echo "  WireGuard VPN Setup - AWS Side"
echo "=========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Install WireGuard if not installed
if ! command -v wg &> /dev/null; then
    apt-get update
    apt-get install -y wireguard wireguard-tools
fi

# Configuration
AWS_VPN_IP="10.10.1.1"
AWS_VPN_CIDR="10.10.1.0/24"
OPENSTACK_VPN_IP="10.10.1.2"
OPENSTACK_NETWORK="172.10.0.0/16"
VPN_PORT="51820"

# Generate keys if not exist
if [ ! -f /etc/wireguard/privatekey ]; then
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
    chmod 600 /etc/wireguard/privatekey
    echo "Generated new WireGuard keys"
fi

AWS_PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
AWS_PUBLIC_KEY=$(cat /etc/wireguard/publickey)

echo ""
echo "AWS WireGuard Public Key: $AWS_PUBLIC_KEY"
echo "Save this key to configure OpenStack side!"
echo ""

# Prompt for OpenStack public key
read -p "Enter OpenStack WireGuard Public Key: " OPENSTACK_PUBLIC_KEY
read -p "Enter OpenStack Public IP: " OPENSTACK_PUBLIC_IP

# Create WireGuard config
cat > /etc/wireguard/wg0.conf << EOF
# ============================================================
# WireGuard VPN - AWS Side
# Zero Trust Architecture - Hybrid Cloud
# ============================================================

[Interface]
Address = ${AWS_VPN_IP}/24
PrivateKey = ${AWS_PRIVATE_KEY}
ListenPort = ${VPN_PORT}

# Enable forwarding and NAT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# OpenStack Peer
[Peer]
PublicKey = ${OPENSTACK_PUBLIC_KEY}
AllowedIPs = ${OPENSTACK_VPN_IP}/32, ${OPENSTACK_NETWORK}
Endpoint = ${OPENSTACK_PUBLIC_IP}:${VPN_PORT}
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
echo "To test connectivity from AWS to OpenStack:"
echo "  ping ${OPENSTACK_VPN_IP}"
echo "  ping 172.10.0.190  # OpenStack K8s master"
