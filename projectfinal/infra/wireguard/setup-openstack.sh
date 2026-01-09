#!/bin/bash
# =============================================================================
# WIREGUARD SETUP - OPENSTACK SIDE
# =============================================================================
# Run this script on the OpenStack K3s master to set up WireGuard VPN
# This creates the VPN tunnel endpoint that AWS will connect to
# =============================================================================

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         WIREGUARD VPN SETUP - OPENSTACK GATEWAY                     ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"

# Install WireGuard
echo "[1/5] Installing WireGuard..."
sudo apt-get update
sudo apt-get install -y wireguard wireguard-tools

# Generate keys if they don't exist
if [ ! -f /etc/wireguard/privatekey ]; then
    echo "[2/5] Generating WireGuard keys..."
    wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/publickey
    sudo chmod 600 /etc/wireguard/privatekey
else
    echo "[2/5] Keys already exist, skipping generation..."
fi

# Read keys
PRIVATE_KEY=$(sudo cat /etc/wireguard/privatekey)
PUBLIC_KEY=$(sudo cat /etc/wireguard/publickey)

echo "[3/5] Enabling IP forwarding..."
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Create WireGuard config
echo "[4/5] Creating WireGuard configuration..."
cat << EOF | sudo tee /etc/wireguard/wg0.conf
[Interface]
# OpenStack WireGuard Gateway
PrivateKey = ${PRIVATE_KEY}
Address = 10.200.0.2/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE

[Peer]
# AWS WireGuard Gateway - Fill in after AWS deployment
# PublicKey = <AWS_WIREGUARD_PUBLIC_KEY>
# Endpoint = <AWS_PUBLIC_IP>:51820
# AllowedIPs = 10.100.0.0/16, 10.200.0.1/32
# PersistentKeepalive = 25
EOF

sudo chmod 600 /etc/wireguard/wg0.conf

echo "[5/5] Starting WireGuard..."
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0 || echo "WireGuard not started (peer not configured yet)"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    WIREGUARD SETUP COMPLETE                          ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  OpenStack WireGuard Public Key:                                     ║"
echo "║  ${PUBLIC_KEY}"
echo "║                                                                      ║"
echo "║  Use this public key in AWS terraform.tfvars:                        ║"
echo "║  openstack_wg_pubkey = \"${PUBLIC_KEY}\"                              ║"
echo "║                                                                      ║"
echo "║  OpenStack WireGuard Endpoint:                                       ║"
echo "║  openstack_wg_endpoint = \"<YOUR_OPENSTACK_PUBLIC_IP>:51820\"         ║"
echo "║                                                                      ║"
echo "║  NEXT STEPS:                                                         ║"
echo "║  1. Deploy AWS infrastructure with Terraform                         ║"
echo "║  2. Get AWS WireGuard public key from output                         ║"
echo "║  3. Edit /etc/wireguard/wg0.conf and add AWS peer                   ║"
echo "║  4. Restart WireGuard: sudo systemctl restart wg-quick@wg0          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
