#!/bin/bash
# =============================================================================
# AWS SITE-TO-SITE VPN CONFIGURATION FOR OPENSTACK
# =============================================================================
# Script này cài đặt và cấu hình strongSwan để kết nối với AWS Transit Gateway
# =============================================================================

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   AWS SITE-TO-SITE VPN SETUP FOR OPENSTACK                    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"

# AWS VPN Configuration (from Terraform output)
AWS_TUNNEL1_IP="3.0.33.41"
AWS_TUNNEL2_IP="3.0.154.162"
LOCAL_PUBLIC_IP="172.10.0.101"
TUNNEL1_INSIDE_CIDR="169.254.10.0/30"
TUNNEL2_INSIDE_CIDR="169.254.11.0/30"
PSK_TUNNEL1="ZTACapstone_PSK_Tunnel1_2024"
PSK_TUNNEL2="ZTACapstone_PSK_Tunnel2_2024"

# Network CIDRs
LOCAL_NETWORK="172.10.0.0/24"
LOCAL_POD_NETWORK="10.42.0.0/16"
AWS_VPC_CIDR="10.100.0.0/16"

echo -e "${YELLOW}[1/5] Installing strongSwan...${NC}"
sudo apt-get update
sudo apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

echo -e "${YELLOW}[2/5] Enabling IP forwarding...${NC}"
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo -e "${YELLOW}[3/5] Configuring IPSec (ipsec.conf)...${NC}"
sudo tee /etc/ipsec.conf > /dev/null << 'EOF'
# =============================================================================
# AWS SITE-TO-SITE VPN - IPSEC CONFIGURATION
# =============================================================================
config setup
    charondebug="all"
    uniqueids=yes
    strictcrlpolicy=no

# =============================================================================
# TUNNEL 1 - PRIMARY
# =============================================================================
conn aws-vpn-tunnel1
    # Connection type
    type=tunnel
    authby=secret
    auto=start
    keyexchange=ikev2
    
    # IKE and ESP settings
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    
    # Rekey settings
    ikelifetime=8h
    lifetime=1h
    margintime=9m
    keyingtries=%forever
    
    # Dead Peer Detection
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    
    # Local (OpenStack) settings
    left=%defaultroute
    leftid=172.10.0.101
    leftsubnet=172.10.0.0/24,10.42.0.0/16
    leftfirewall=yes
    
    # Remote (AWS) settings
    right=3.0.33.41
    rightsubnet=10.100.0.0/16
    
    # Mark for routing
    mark=100

# =============================================================================
# TUNNEL 2 - FAILOVER
# =============================================================================
conn aws-vpn-tunnel2
    # Connection type
    type=tunnel
    authby=secret
    auto=start
    keyexchange=ikev2
    
    # IKE and ESP settings
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    
    # Rekey settings
    ikelifetime=8h
    lifetime=1h
    margintime=9m
    keyingtries=%forever
    
    # Dead Peer Detection
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    
    # Local (OpenStack) settings
    left=%defaultroute
    leftid=172.10.0.101
    leftsubnet=172.10.0.0/24,10.42.0.0/16
    leftfirewall=yes
    
    # Remote (AWS) settings
    right=3.0.154.162
    rightsubnet=10.100.0.0/16
    
    # Mark for routing
    mark=200
EOF

echo -e "${YELLOW}[4/5] Configuring Pre-Shared Keys (ipsec.secrets)...${NC}"
sudo tee /etc/ipsec.secrets > /dev/null << EOF
# AWS VPN Tunnel 1
172.10.0.101 3.0.33.41 : PSK "${PSK_TUNNEL1}"

# AWS VPN Tunnel 2
172.10.0.101 3.0.154.162 : PSK "${PSK_TUNNEL2}"
EOF

sudo chmod 600 /etc/ipsec.secrets

echo -e "${YELLOW}[5/5] Configuring Firewall rules...${NC}"
# Allow IPSec traffic
sudo iptables -A INPUT -p udp --dport 500 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4500 -j ACCEPT
sudo iptables -A INPUT -p esp -j ACCEPT
sudo iptables -A INPUT -p ah -j ACCEPT

# NAT for outgoing traffic to AWS
sudo iptables -t nat -A POSTROUTING -o eth0 -s 172.10.0.0/24 -d 10.100.0.0/16 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o eth0 -s 10.42.0.0/16 -d 10.100.0.0/16 -j MASQUERADE

# Save iptables rules
sudo iptables-save | sudo tee /etc/iptables.rules > /dev/null

echo -e "${GREEN}[DONE] Starting strongSwan...${NC}"
sudo systemctl restart strongswan-starter
sudo systemctl enable strongswan-starter

# Wait for connection
sleep 5

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    VPN STATUS                                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
sudo ipsec status

echo -e "\n${YELLOW}To check VPN status:${NC}"
echo "  sudo ipsec statusall"
echo "  sudo ipsec status"
echo ""
echo -e "${YELLOW}To restart VPN:${NC}"
echo "  sudo ipsec restart"
echo ""
echo -e "${YELLOW}To test connectivity:${NC}"
echo "  ping 10.100.2.248  # AWS workload instance"
