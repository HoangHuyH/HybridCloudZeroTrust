# =============================================================================
# AWS TRANSIT GATEWAY - ENTERPRISE HYBRID CLOUD CONNECTIVITY
# =============================================================================
# Thay thế WireGuard VPN bằng giải pháp Enterprise:
# - AWS Transit Gateway: Hub trung tâm kết nối nhiều VPC
# - Site-to-Site VPN: IPSec VPN với BGP dynamic routing
# - Có thể mở rộng sang Direct Connect trong tương lai
# =============================================================================

# =============================================================================
# TRANSIT GATEWAY - Central Hub
# =============================================================================
resource "aws_ec2_transit_gateway" "zta_tgw" {
  description                     = "ZTA Hybrid Cloud Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"
  auto_accept_shared_attachments  = "disable"
  
  # Amazon side ASN for BGP
  amazon_side_asn = var.tgw_amazon_asn

  tags = {
    Name        = "zta-transit-gateway"
    Purpose     = "Hybrid Cloud Connectivity"
    Environment = "capstone"
  }
}

# =============================================================================
# TRANSIT GATEWAY VPC ATTACHMENT
# =============================================================================
# Attach VPC to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "zta_vpc_attachment" {
  subnet_ids         = [aws_subnet.zta_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.zta_tgw.id
  vpc_id             = aws_vpc.zta_vpc.id
  
  dns_support        = "enable"
  ipv6_support       = "disable"

  tags = {
    Name = "zta-vpc-attachment"
  }
}

# =============================================================================
# CUSTOMER GATEWAY - On-Premises (OpenStack)
# =============================================================================
# Represents the OpenStack side of the VPN connection
resource "aws_customer_gateway" "openstack_cgw" {
  bgp_asn    = var.openstack_bgp_asn
  ip_address = var.openstack_public_ip
  type       = "ipsec.1"

  tags = {
    Name     = "zta-openstack-customer-gateway"
    Location = "OpenStack On-Premises"
  }
}

# =============================================================================
# VPN CONNECTION - Site-to-Site IPSec VPN
# =============================================================================
resource "aws_vpn_connection" "openstack_vpn" {
  customer_gateway_id = aws_customer_gateway.openstack_cgw.id
  transit_gateway_id  = aws_ec2_transit_gateway.zta_tgw.id
  type                = "ipsec.1"
  
  # Static routing (có thể chuyển sang dynamic nếu có BGP)
  static_routes_only = var.vpn_static_routes_only

  # Tunnel options
  tunnel1_inside_cidr   = var.vpn_tunnel1_inside_cidr
  tunnel1_preshared_key = var.vpn_tunnel1_psk
  
  tunnel2_inside_cidr   = var.vpn_tunnel2_inside_cidr
  tunnel2_preshared_key = var.vpn_tunnel2_psk

  tags = {
    Name = "zta-openstack-vpn"
  }
}

# =============================================================================
# TRANSIT GATEWAY ROUTE TABLE
# =============================================================================
resource "aws_ec2_transit_gateway_route_table" "zta_tgw_rt" {
  transit_gateway_id = aws_ec2_transit_gateway.zta_tgw.id

  tags = {
    Name = "zta-tgw-route-table"
  }
}

# Route to OpenStack via VPN
resource "aws_ec2_transit_gateway_route" "to_openstack" {
  destination_cidr_block         = var.openstack_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.openstack_vpn.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.zta_tgw_rt.id
}

# Route cho K3s Pod network trên OpenStack
resource "aws_ec2_transit_gateway_route" "to_openstack_pods" {
  destination_cidr_block         = var.openstack_pod_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.openstack_vpn.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.zta_tgw_rt.id
}

# =============================================================================
# VPC ROUTE TABLE UPDATES - Route to Transit Gateway
# =============================================================================
# Update private subnet route table to use Transit Gateway
resource "aws_route" "private_to_openstack_via_tgw" {
  count = var.use_transit_gateway ? 1 : 0
  
  route_table_id         = aws_route_table.zta_private_rt.id
  destination_cidr_block = var.openstack_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.zta_tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.zta_vpc_attachment]
}

resource "aws_route" "private_to_openstack_pods_via_tgw" {
  count = var.use_transit_gateway ? 1 : 0
  
  route_table_id         = aws_route_table.zta_private_rt.id
  destination_cidr_block = var.openstack_pod_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.zta_tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.zta_vpc_attachment]
}

# =============================================================================
# DIRECT CONNECT GATEWAY (Preparation for Future)
# =============================================================================
# Direct Connect Gateway - để kết nối với AWS Direct Connect
# Uncomment khi có Direct Connect physical connection
/*
resource "aws_dx_gateway" "zta_dxgw" {
  name            = "zta-direct-connect-gateway"
  amazon_side_asn = var.tgw_amazon_asn
}

resource "aws_dx_gateway_association" "zta_dxgw_tgw" {
  dx_gateway_id         = aws_dx_gateway.zta_dxgw.id
  associated_gateway_id = aws_ec2_transit_gateway.zta_tgw.id
  
  allowed_prefixes = [
    var.vpc_cidr,
    "10.42.0.0/16"  # K3s pod network
  ]
}
*/

# =============================================================================
# VPN CONNECTION MONITORING - CloudWatch
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "vpn_tunnel_down" {
  count = var.enable_vpn_monitoring ? 1 : 0
  
  alarm_name          = "zta-vpn-tunnel-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "VPN tunnel to OpenStack is down"
  
  dimensions = {
    VpnId = aws_vpn_connection.openstack_vpn.id
  }

  alarm_actions = var.vpn_alarm_actions
  ok_actions    = var.vpn_alarm_actions

  tags = {
    Name = "zta-vpn-tunnel-alarm"
  }
}

# =============================================================================
# SECURITY GROUP FOR TRANSIT GATEWAY TRAFFIC
# =============================================================================
resource "aws_security_group" "tgw_traffic_sg" {
  name        = "zta-tgw-traffic-sg"
  description = "Security group for Transit Gateway traffic"
  vpc_id      = aws_vpc.zta_vpc.id

  # Allow all traffic from OpenStack via TGW
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.openstack_cidr, var.openstack_pod_cidr]
    description = "Traffic from OpenStack via Transit Gateway"
  }

  # Allow K3s API traffic
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.openstack_cidr]
    description = "K3s API Server"
  }

  # Allow Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.openstack_pod_cidr]
    description = "Flannel VXLAN"
  }

  # Allow Kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.openstack_cidr]
    description = "Kubelet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zta-tgw-traffic-sg"
  }
}
