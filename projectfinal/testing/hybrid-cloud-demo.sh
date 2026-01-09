#!/bin/bash
# =============================================================================
# HYBRID CLOUD SIMULATION DEMO
# =============================================================================
# Dùng cho demo khi không có AWS account thật
# Tạo môi trường giả lập để minh họa Hybrid Cloud concept
# =============================================================================

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║        ZERO TRUST HYBRID CLOUD - SIMULATION DEMO                     ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Simulated AWS VPC info
AWS_VPC_CIDR="10.100.0.0/16"
AWS_PUBLIC_SUBNET="10.100.1.0/24"
AWS_PRIVATE_SUBNET="10.100.2.0/24"
AWS_WG_IP="10.200.0.1"

# OpenStack info
OPENSTACK_CIDR="172.10.0.0/24"
OPENSTACK_K3S_MASTER="172.10.0.190"
OPENSTACK_WG_IP="10.200.0.2"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 1: Hybrid Cloud Architecture Overview${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cat << 'EOF'
    ┌─────────────────────────────┐         ┌─────────────────────────────┐
    │       OPENSTACK             │         │           AWS               │
    │     (On-Premises)           │         │        (Cloud)              │
    │                             │         │                             │
    │  ┌─────────────────────┐    │         │    ┌─────────────────────┐  │
    │  │    K3s Master       │    │ WireGuard│   │   WireGuard GW     │  │
    │  │   172.10.0.190      │◄────────────────►│   (Public Subnet)   │  │
    │  │                     │    │  VPN     │    │   10.100.1.x       │  │
    │  └──────────┬──────────┘    │ Tunnel   │    └──────────┬──────────┘  │
    │             │               │         │               │             │
    │  ┌──────────▼──────────┐    │         │    ┌──────────▼──────────┐  │
    │  │   ZTA Services      │    │         │    │   K3s Worker        │  │
    │  │  - Keycloak         │    │         │    │   (Private Subnet)  │  │
    │  │  - OAuth2-Proxy     │    │         │    │   10.100.2.x        │  │
    │  │  - Demo App         │    │         │    │                     │  │
    │  │  - Istio Mesh       │    │         │    │  + node_exporter    │  │
    │  └─────────────────────┘    │         │    └─────────────────────┘  │
    │                             │         │                             │
    │  Network: 172.10.0.0/24     │         │  Network: 10.100.0.0/16     │
    └─────────────────────────────┘         └─────────────────────────────┘
EOF

echo ""
read -p "Press Enter to continue..."

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 2: WireGuard VPN Tunnel Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}OpenStack WireGuard Config (/etc/wireguard/wg0.conf):${NC}"
cat << EOF
[Interface]
PrivateKey = <OPENSTACK_PRIVATE_KEY>
Address = 10.200.0.2/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; ...
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; ...

[Peer]
# AWS Gateway
PublicKey = <AWS_PUBLIC_KEY>
Endpoint = <AWS_PUBLIC_IP>:51820
AllowedIPs = 10.100.0.0/16, 10.200.0.1/32
PersistentKeepalive = 25
EOF

echo ""
echo -e "${GREEN}AWS WireGuard Config:${NC}"
cat << EOF
[Interface]
PrivateKey = <AWS_PRIVATE_KEY>
Address = 10.200.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; ...

[Peer]
# OpenStack Gateway
PublicKey = <OPENSTACK_PUBLIC_KEY>
Endpoint = <OPENSTACK_PUBLIC_IP>:51820
AllowedIPs = 172.10.0.0/24, 10.200.0.2/32
PersistentKeepalive = 25
EOF

echo ""
read -p "Press Enter to continue..."

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 3: Zero Trust Security Features in Hybrid Cloud${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}1. Network Segmentation (AWS Security Groups):${NC}"
cat << 'EOF'
   ┌─────────────────────────────────────────────────────────────────┐
   │                    AWS Security Groups                          │
   ├─────────────────────────────────────────────────────────────────┤
   │                                                                 │
   │  wireguard-sg:                                                  │
   │    - Inbound: UDP 51820 (WireGuard) from 0.0.0.0/0             │
   │    - Inbound: SSH 22 from specific IPs only                    │
   │    - Inbound: All from 172.10.0.0/24 (OpenStack via VPN)       │
   │                                                                 │
   │  workload-sg:                                                   │
   │    - Inbound: ONLY from wireguard-sg (Zero Trust)              │
   │    - No direct internet access to workloads                    │
   │                                                                 │
   └─────────────────────────────────────────────────────────────────┘
EOF

echo ""
echo -e "${GREEN}2. Cross-Cloud Authentication Flow:${NC}"
cat << 'EOF'
   User Request                                                      
        │                                                            
        ▼                                                            
   ┌─────────────┐                                                   
   │   Istio     │  ◄─── mTLS enabled                               
   │  Ingress    │                                                   
   └──────┬──────┘                                                   
          │                                                          
          ▼                                                          
   ┌─────────────┐     ┌─────────────┐                              
   │ OAuth2-Proxy│────►│  Keycloak   │  ◄─── Identity Provider      
   └──────┬──────┘     └─────────────┘                              
          │                                                          
          │ (authenticated + authorized)                             
          ▼                                                          
   ┌─────────────┐                    ┌─────────────┐               
   │  Demo App   │──── WireGuard ────►│ AWS Worker  │               
   │ (OpenStack) │     VPN Tunnel     │  (AWS)      │               
   └─────────────┘                    └─────────────┘               
                                                                     
   ✓ All traffic encrypted (WireGuard + mTLS)                       
   ✓ Identity verified at every hop                                 
   ✓ No implicit trust between clouds                               
EOF

echo ""
read -p "Press Enter to continue..."

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 4: Terraform Infrastructure as Code${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}Terraform Resources Created:${NC}"
cat << EOF
┌────────────────────────────────────────────────────────────────────┐
│ Resource                        │ Purpose                         │
├────────────────────────────────────────────────────────────────────┤
│ aws_vpc.zta_vpc                 │ Main VPC (10.100.0.0/16)        │
│ aws_subnet.public_subnet        │ WireGuard gateway subnet        │
│ aws_subnet.private_subnet       │ Workload subnet                 │
│ aws_internet_gateway.igw        │ Internet access                 │
│ aws_nat_gateway.nat             │ Private subnet internet access  │
│ aws_security_group.wireguard_sg │ VPN gateway security            │
│ aws_security_group.workload_sg  │ Zero Trust workload security    │
│ aws_instance.wireguard_gateway  │ VPN gateway (t3.micro)          │
│ aws_instance.workload           │ K3s worker (t3.medium)          │
│ aws_flow_log.vpc_flow_log       │ Network monitoring              │
│ aws_cloudwatch_log_group        │ Log aggregation                 │
└────────────────────────────────────────────────────────────────────┘
EOF

echo ""
echo -e "${GREEN}Deployment Commands:${NC}"
echo "  cd infra/aws"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"

echo ""
read -p "Press Enter to continue..."

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 5: Monitoring Across Hybrid Cloud${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cat << 'EOF'
   ┌─────────────────────────────────────────────────────────────────┐
   │                    UNIFIED MONITORING                           │
   ├─────────────────────────────────────────────────────────────────┤
   │                                                                 │
   │   OpenStack                          AWS                        │
   │   ┌─────────────┐                   ┌─────────────┐            │
   │   │ Prometheus  │◄──────────────────│node_exporter│            │
   │   │ (scrapes)   │   WireGuard VPN   │  (metrics)  │            │
   │   └──────┬──────┘                   └─────────────┘            │
   │          │                                                      │
   │          ▼                                                      │
   │   ┌─────────────┐                                              │
   │   │  Grafana    │◄─── Dashboards show both clouds              │
   │   │             │                                              │
   │   └──────┬──────┘                                              │
   │          │                                                      │
   │          ▼                                                      │
   │   ┌─────────────┐                   ┌─────────────┐            │
   │   │    Loki     │◄──────────────────│  CloudWatch │            │
   │   │   (logs)    │   VPC Flow Logs   │   (logs)    │            │
   │   └─────────────┘                   └─────────────┘            │
   │                                                                 │
   └─────────────────────────────────────────────────────────────────┘
EOF

echo ""
echo -e "${GREEN}Cross-Cloud Metrics Collection:${NC}"
echo "  • AWS workload exports metrics via node_exporter"
echo "  • Prometheus on OpenStack scrapes via WireGuard tunnel"
echo "  • Grafana displays unified view of both clouds"
echo "  • VPC Flow Logs can be forwarded to Loki"

echo ""
read -p "Press Enter to see summary..."

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                     HYBRID CLOUD DEMO SUMMARY                        ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                      ║"
echo "║  ✅ Architecture: OpenStack + AWS connected via WireGuard VPN       ║"
echo "║  ✅ Encryption: All cross-cloud traffic encrypted                   ║"
echo "║  ✅ Zero Trust: No implicit trust between clouds                    ║"
echo "║  ✅ Segmentation: Security groups with deny-by-default              ║"
echo "║  ✅ IaC: Terraform for reproducible infrastructure                  ║"
echo "║  ✅ Monitoring: Unified observability across clouds                 ║"
echo "║                                                                      ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Files created:                                                      ║"
echo "║  • infra/aws/main.tf         - AWS infrastructure                   ║"
echo "║  • infra/aws/variables.tf    - Configuration variables              ║"
echo "║  • infra/aws/outputs.tf      - Output values                        ║"
echo "║  • infra/wireguard/*.sh      - VPN setup scripts                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
