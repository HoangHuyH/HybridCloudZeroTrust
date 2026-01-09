# =============================================================================
# OUTPUTS - Important values after deployment
# =============================================================================

output "vpc_id" {
  description = "ID of the ZTA VPC"
  value       = aws_vpc.zta_vpc.id
}

output "wireguard_public_ip" {
  description = "Public IP of WireGuard gateway"
  value       = aws_instance.wireguard_gateway.public_ip
}

output "wireguard_private_ip" {
  description = "Private IP of WireGuard gateway"
  value       = aws_instance.wireguard_gateway.private_ip
}

output "workload_private_ip" {
  description = "Private IP of workload instance"
  value       = aws_instance.workload.private_ip
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.zta_vpc.cidr_block
}

output "wireguard_endpoint" {
  description = "WireGuard endpoint for OpenStack to connect"
  value       = "${aws_instance.wireguard_gateway.public_ip}:51820"
}

output "ssh_command_wireguard" {
  description = "SSH command to connect to WireGuard gateway"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.wireguard_gateway.public_ip}"
}

output "hybrid_cloud_diagram" {
  description = "Hybrid cloud topology"
  value       = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║                    HYBRID CLOUD ARCHITECTURE                             ║
    ╠══════════════════════════════════════════════════════════════════════════╣
    ║                                                                          ║
    ║   ┌──────────────────────────┐         ┌──────────────────────────┐     ║
    ║   │      OPENSTACK           │         │         AWS              │     ║
    ║   │    (On-Premises)         │         │       (Cloud)            │     ║
    ║   │                          │         │                          │     ║
    ║   │  ┌──────────────────┐   │         │   ┌──────────────────┐   │     ║
    ║   │  │   K3s Master     │   │ WireGuard│   │  WireGuard GW   │   │     ║
    ║   │  │  ${var.openstack_k3s_master_ip}   │◄──────────────►│  ${aws_instance.wireguard_gateway.public_ip}    │   │     ║
    ║   │  └──────────────────┘   │   VPN    │   └──────────────────┘   │     ║
    ║   │           │              │ Tunnel   │           │              │     ║
    ║   │           │              │         │           │              │     ║
    ║   │  ┌────────▼─────────┐   │         │   ┌───────▼──────────┐   │     ║
    ║   │  │   ZTA Services   │   │         │   │  K3s Worker      │   │     ║
    ║   │  │  - Keycloak      │   │         │   │  (Workload)      │   │     ║
    ║   │  │  - OAuth2-Proxy  │   │         │   │  ${aws_instance.workload.private_ip}       │   │     ║
    ║   │  │  - Demo App      │   │         │   └──────────────────┘   │     ║
    ║   │  └──────────────────┘   │         │                          │     ║
    ║   │                          │         │                          │     ║
    ║   │  Network: ${var.openstack_cidr}    │         │  Network: ${var.vpc_cidr}      │     ║
    ║   └──────────────────────────┘         └──────────────────────────┘     ║
    ║                                                                          ║
    ╚══════════════════════════════════════════════════════════════════════════╝
    
  EOT
}

# =============================================================================
# TRANSIT GATEWAY OUTPUTS
# =============================================================================

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.zta_tgw.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.zta_tgw.arn
}

output "vpn_connection_id" {
  description = "ID of the Site-to-Site VPN connection"
  value       = aws_vpn_connection.openstack_vpn.id
}

output "vpn_tunnel1_address" {
  description = "Public IP of VPN Tunnel 1"
  value       = aws_vpn_connection.openstack_vpn.tunnel1_address
}

output "vpn_tunnel2_address" {
  description = "Public IP of VPN Tunnel 2"
  value       = aws_vpn_connection.openstack_vpn.tunnel2_address
}

output "customer_gateway_id" {
  description = "ID of the Customer Gateway"
  value       = aws_customer_gateway.openstack_cgw.id
}

output "vpn_configuration" {
  description = "VPN connection configuration for OpenStack"
  sensitive   = true
  value       = <<-EOT
    
    ═══════════════════════════════════════════════════════════════════════════
    AWS SITE-TO-SITE VPN CONFIGURATION
    ═══════════════════════════════════════════════════════════════════════════
    
    Configure on OpenStack VPN Gateway (e.g., strongSwan/Libreswan):
    
    TUNNEL 1:
    ---------
    AWS Endpoint:     ${aws_vpn_connection.openstack_vpn.tunnel1_address}
    Customer Gateway: ${var.openstack_public_ip}
    Inside CIDR:      ${var.vpn_tunnel1_inside_cidr}
    Pre-Shared Key:   ${var.vpn_tunnel1_psk}
    
    TUNNEL 2 (Failover):
    --------------------
    AWS Endpoint:     ${aws_vpn_connection.openstack_vpn.tunnel2_address}
    Customer Gateway: ${var.openstack_public_ip}
    Inside CIDR:      ${var.vpn_tunnel2_inside_cidr}
    Pre-Shared Key:   ${var.vpn_tunnel2_psk}
    
    IPSec Settings:
    ---------------
    IKE Version:      IKEv2
    Phase 1 DH Group: 2, 14, 15, 16, 17, 18, 19, 20, 21
    Phase 1 Encrypt:  AES128, AES256
    Phase 1 Integrity: SHA1, SHA2-256, SHA2-384, SHA2-512
    Phase 2 DH Group: 2, 5, 14, 15, 16, 17, 18, 19, 20, 21
    Phase 2 Encrypt:  AES128, AES256
    Phase 2 Integrity: SHA1, SHA2-256
    
    ═══════════════════════════════════════════════════════════════════════════
    
  EOT
}

output "transit_gateway_diagram" {
  description = "Transit Gateway architecture diagram"
  value       = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║              ENTERPRISE HYBRID CLOUD - TRANSIT GATEWAY ARCHITECTURE          ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                                                                              ║
    ║   ┌─────────────────────────────┐          ┌─────────────────────────────┐  ║
    ║   │      OPENSTACK DC           │          │          AWS CLOUD          │  ║
    ║   │    (On-Premises)            │          │       (ap-southeast-1)      │  ║
    ║   │                             │          │                             │  ║
    ║   │  ┌───────────────────┐     │          │   ┌───────────────────────┐ │  ║
    ║   │  │   K3s Cluster     │     │          │   │   TRANSIT GATEWAY     │ │  ║
    ║   │  │                   │     │          │   │   ${aws_ec2_transit_gateway.zta_tgw.id}      │ │  ║
    ║   │  │  master           │     │   IPSec  │   │                       │ │  ║
    ║   │  │  worker           │◄────┼──────────┼──►│  ┌─────────────────┐  │ │  ║
    ║   │  │                   │     │   VPN    │   │  │ VPN Attachment  │  │ │  ║
    ║   │  │  ${var.openstack_k3s_master_ip}     │     │          │   │  └─────────────────┘  │ │  ║
    ║   │  └───────────────────┘     │          │   │          │            │ │  ║
    ║   │         │                  │          │   │          ▼            │ │  ║
    ║   │  ┌──────▼────────────┐     │          │   │  ┌─────────────────┐  │ │  ║
    ║   │  │   VPN Gateway     │     │          │   │  │ VPC Attachment  │  │ │  ║
    ║   │  │   (strongSwan)    │     │          │   │  └────────┬────────┘  │ │  ║
    ║   │  │                   │     │          │   └───────────┼───────────┘ │  ║
    ║   │  │  ${var.openstack_public_ip}       │     │          │               │            │  ║
    ║   │  └───────────────────┘     │          │               ▼              │  ║
    ║   │                             │          │   ┌─────────────────────┐   │  ║
    ║   │  Network: ${var.openstack_cidr}   │          │   │   VPC: ${var.vpc_cidr}     │   │  ║
    ║   │  Pod CIDR: ${var.openstack_pod_cidr}    │          │   │                     │   │  ║
    ║   │                             │          │   │   K3s Workers (AWS) │   │  ║
    ║   │                             │          │   │   TKB Service       │   │  ║
    ║   └─────────────────────────────┘          │   └─────────────────────┘   │  ║
    ║                                            └─────────────────────────────┘  ║
    ║                                                                              ║
    ║   VPN Endpoints:                                                             ║
    ║   • Tunnel 1: ${aws_vpn_connection.openstack_vpn.tunnel1_address}                                              ║
    ║   • Tunnel 2: ${aws_vpn_connection.openstack_vpn.tunnel2_address} (failover)                                   ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
  EOT
}

# =============================================================================
# PUBLIC VPC / LOAD BALANCER OUTPUTS
# =============================================================================

output "public_vpc_id" {
  description = "ID of the Public VPC"
  value       = aws_vpc.zta_public_vpc.id
}

output "load_balancer_public_ip" {
  description = "Public IP of Load Balancer (Elastic IP)"
  value       = aws_eip.lb_eip.public_ip
}

output "load_balancer_private_ip" {
  description = "Private IP of Load Balancer"
  value       = aws_instance.load_balancer.private_ip
}

output "application_url" {
  description = "URL to access the Zero Trust application"
  value       = "https://${aws_eip.lb_eip.public_ip}"
}

output "ssh_command_lb" {
  description = "SSH command to connect to Load Balancer"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.lb_eip.public_ip}"
}

output "complete_architecture" {
  description = "Complete multi-VPC Transit Gateway architecture"
  value       = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
    ║                    COMPLETE ZERO TRUST HYBRID CLOUD ARCHITECTURE                                 ║
    ║                    with AWS Transit Gateway + Multi-VPC                                          ║
    ╠══════════════════════════════════════════════════════════════════════════════════════════════════╣
    ║                                                                                                  ║
    ║     INTERNET                                                                                     ║
    ║         │                                                                                        ║
    ║         │ HTTPS (443)                                                                            ║
    ║         ▼                                                                                        ║
    ║   ┌─────────────────────────────────────────────────────────────────────────────────────────┐   ║
    ║   │                          AWS CLOUD (ap-southeast-1)                                     │   ║
    ║   │                                                                                         │   ║
    ║   │   ┌─────────────────────────────┐         ┌─────────────────────────────┐              │   ║
    ║   │   │   PUBLIC VPC                │         │   WORKLOAD VPC              │              │   ║
    ║   │   │   ${var.public_vpc_cidr}            │         │   ${var.vpc_cidr}            │              │   ║
    ║   │   │                             │         │                             │              │   ║
    ║   │   │   ┌───────────────────┐    │         │   ┌───────────────────┐    │              │   ║
    ║   │   │   │  LOAD BALANCER    │    │         │   │   K3s Workers     │    │              │   ║
    ║   │   │   │  (Nginx)          │    │         │   │                   │    │              │   ║
    ║   │   │   │                   │    │         │   │   TKB Service     │    │              │   ║
    ║   │   │   │  ${aws_eip.lb_eip.public_ip}      │    │         │   │   Other µSvc     │    │              │   ║
    ║   │   │   │                   │    │         │   │                   │    │              │   ║
    ║   │   │   └─────────┬─────────┘    │         │   └───────────────────┘    │              │   ║
    ║   │   │             │              │         │             ▲              │              │   ║
    ║   │   └─────────────┼──────────────┘         └─────────────┼──────────────┘              │   ║
    ║   │                 │                                      │                             │   ║
    ║   │                 │         ┌─────────────────────┐      │                             │   ║
    ║   │                 └────────►│   TRANSIT GATEWAY   │◄─────┘                             │   ║
    ║   │                           │   ${aws_ec2_transit_gateway.zta_tgw.id}   │                               │   ║
    ║   │                           │                     │                                    │   ║
    ║   │                           │  ┌───────────────┐  │                                    │   ║
    ║   │                           │  │ VPN Attach    │  │                                    │   ║
    ║   │                           │  │ (IPSec)       │  │                                    │   ║
    ║   │                           │  └───────┬───────┘  │                                    │   ║
    ║   │                           └──────────┼──────────┘                                    │   ║
    ║   │                                      │                                               │   ║
    ║   └──────────────────────────────────────┼───────────────────────────────────────────────┘   ║
    ║                                          │ IPSec VPN                                         ║
    ║                                          │                                                   ║
    ║   ┌──────────────────────────────────────┼───────────────────────────────────────────────┐   ║
    ║   │                          OPENSTACK (On-Premises)                                     │   ║
    ║   │                                      │                                               │   ║
    ║   │   ┌─────────────────────────────────┐│                                               │   ║
    ║   │   │   K3s CLUSTER                    │                                               │   ║
    ║   │   │                                  │                                               │   ║
    ║   │   │   master: ${var.openstack_k3s_master_ip}                                                    │   ║
    ║   │   │   worker: K3s worker node                                                        │   ║
    ║   │   │                                  │                                               │   ║
    ║   │   │   Services:                      │                                               │   ║
    ║   │   │   ├── Istio Gateway (:${var.openstack_istio_nodeport})                                          │   ║
    ║   │   │   ├── Keycloak (OIDC)           │                                               │   ║
    ║   │   │   ├── OAuth2-Proxy              │                                               │   ║
    ║   │   │   ├── Demo-App (FastAPI)        │                                               │   ║
    ║   │   │   ├── OPA (Policy Engine)       │                                               │   ║
    ║   │   │   └── SPIRE (Workload ID)       │                                               │   ║
    ║   │   │                                  │                                               │   ║
    ║   │   │   Network: ${var.openstack_cidr}                                                      │   ║
    ║   │   │   Pod CIDR: ${var.openstack_pod_cidr}                                                      │   ║
    ║   │   │                                  │                                               │   ║
    ║   │   └─────────────────────────────────┘                                               │   ║
    ║   │                                                                                      │   ║
    ║   └──────────────────────────────────────────────────────────────────────────────────────┘   ║
    ║                                                                                              ║
    ╠══════════════════════════════════════════════════════════════════════════════════════════════╣
    ║   ACCESS INFORMATION:                                                                        ║
    ║   • Application URL: https://${aws_eip.lb_eip.public_ip}                                                   ║
    ║   • VPN Tunnel 1:    ${aws_vpn_connection.openstack_vpn.tunnel1_address}                                                           ║
    ║   • VPN Tunnel 2:    ${aws_vpn_connection.openstack_vpn.tunnel2_address}                                                           ║
    ╚══════════════════════════════════════════════════════════════════════════════════════════════╝
    
  EOT
}
