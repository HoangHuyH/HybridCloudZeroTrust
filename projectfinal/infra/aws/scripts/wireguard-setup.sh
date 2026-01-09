#!/bin/bash
# =============================================================================
# WIREGUARD VPN SETUP SCRIPT - AWS GATEWAY
# =============================================================================
# This script is run via user_data when EC2 instance boots
# It configures WireGuard VPN to connect AWS to OpenStack
# =============================================================================

set -e

# Update and install WireGuard
apt-get update
apt-get install -y wireguard wireguard-tools

# Enable IP forwarding (required for VPN routing)
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Create WireGuard configuration
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = ${wg_private_key}
Address = ${wg_address}
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE

[Peer]
# OpenStack WireGuard Gateway
PublicKey = ${openstack_pubkey}
Endpoint = ${openstack_endpoint}
AllowedIPs = ${openstack_cidr}, 10.200.0.2/32
PersistentKeepalive = 25
EOF

# Set permissions
chmod 600 /etc/wireguard/wg0.conf

# Enable and start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Log completion
echo "WireGuard VPN configured and started" | logger -t wireguard-setup
echo "$(date): WireGuard setup completed" >> /var/log/wireguard-setup.log
