# =============================================================================
# VARIABLES - AWS Hybrid Cloud Configuration
# =============================================================================

# AWS Region (credentials from environment)
variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ap-southeast-1"  # Singapore - closest to Vietnam
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for AWS VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.100.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.100.2.0/24"
}

# OpenStack Configuration
variable "openstack_cidr" {
  description = "CIDR block of OpenStack network"
  type        = string
  default     = "172.10.0.0/24"
}

variable "openstack_k3s_master_ip" {
  description = "IP address of K3s master in OpenStack"
  type        = string
  default     = "172.10.0.190"
}

# WireGuard VPN Configuration
variable "wg_aws_private_key" {
  description = "WireGuard private key for AWS gateway"
  type        = string
  sensitive   = true
}

variable "wg_aws_address" {
  description = "WireGuard tunnel IP for AWS gateway"
  type        = string
  default     = "10.200.0.1/24"
}

variable "openstack_wg_endpoint" {
  description = "WireGuard endpoint (public IP:port) of OpenStack gateway"
  type        = string
}

variable "openstack_wg_pubkey" {
  description = "WireGuard public key of OpenStack gateway"
  type        = string
}

# EC2 Configuration
variable "key_pair_name" {
  description = "Name of AWS key pair for SSH access"
  type        = string
}

variable "wireguard_instance_type" {
  description = "Instance type for WireGuard gateway"
  type        = string
  default     = "t3.micro"
}

variable "workload_instance_type" {
  description = "Instance type for workload instances"
  type        = string
  default     = "t3.medium"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (Zero Trust - specific IPs only)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change to your IP in production
}

# K3s Configuration
variable "k3s_token" {
  description = "K3s cluster token for joining workers"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# TRANSIT GATEWAY CONFIGURATION
# =============================================================================

variable "use_transit_gateway" {
  description = "Use Transit Gateway instead of WireGuard VPN"
  type        = bool
  default     = true
}

variable "tgw_amazon_asn" {
  description = "Amazon side ASN for Transit Gateway BGP"
  type        = number
  default     = 64512
}

variable "openstack_bgp_asn" {
  description = "BGP ASN for OpenStack/On-premises network"
  type        = number
  default     = 65000
}

variable "openstack_public_ip" {
  description = "Public IP address of OpenStack VPN gateway"
  type        = string
}

variable "openstack_pod_cidr" {
  description = "K3s pod network CIDR on OpenStack"
  type        = string
  default     = "10.42.0.0/16"
}

# VPN Tunnel Configuration
variable "vpn_static_routes_only" {
  description = "Use static routes instead of BGP for VPN"
  type        = bool
  default     = true
}

variable "vpn_tunnel1_inside_cidr" {
  description = "Inside CIDR for VPN Tunnel 1"
  type        = string
  default     = "169.254.10.0/30"
}

variable "vpn_tunnel1_psk" {
  description = "Pre-shared key for VPN Tunnel 1"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vpn_tunnel2_inside_cidr" {
  description = "Inside CIDR for VPN Tunnel 2"
  type        = string
  default     = "169.254.11.0/30"
}

variable "vpn_tunnel2_psk" {
  description = "Pre-shared key for VPN Tunnel 2"
  type        = string
  sensitive   = true
  default     = ""
}

# VPN Monitoring
variable "enable_vpn_monitoring" {
  description = "Enable CloudWatch monitoring for VPN tunnel"
  type        = bool
  default     = true
}

variable "vpn_alarm_actions" {
  description = "SNS topic ARNs for VPN alarm notifications"
  type        = list(string)
  default     = []
}

# =============================================================================
# PUBLIC VPC CONFIGURATION (Internet-facing Load Balancer)
# =============================================================================

variable "public_vpc_cidr" {
  description = "CIDR block for Public VPC (Load Balancer)"
  type        = string
  default     = "10.200.0.0/16"
}

variable "public_vpc_subnet_a_cidr" {
  description = "CIDR block for Public VPC Subnet A"
  type        = string
  default     = "10.200.1.0/24"
}

variable "public_vpc_subnet_b_cidr" {
  description = "CIDR block for Public VPC Subnet B"
  type        = string
  default     = "10.200.2.0/24"
}

variable "lb_instance_type" {
  description = "Instance type for Load Balancer"
  type        = string
  default     = "t3.small"
}

variable "openstack_istio_nodeport" {
  description = "NodePort of Istio Ingress Gateway on OpenStack"
  type        = number
  default     = 31691
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = "zta.local"
}

variable "backend_servers" {
  description = "List of backend server IPs"
  type        = string
  default     = "172.10.0.190"
}
