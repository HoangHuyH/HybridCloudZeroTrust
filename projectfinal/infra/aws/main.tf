# =============================================================================
# ZERO TRUST HYBRID CLOUD - AWS INFRASTRUCTURE
# =============================================================================
# Mục đích: Tạo VPC trên AWS và kết nối với OpenStack qua WireGuard VPN
# Đáp ứng yêu cầu Hybrid Cloud trong đồ án Zero Trust Architecture
# =============================================================================

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Uses AWS credentials from environment (aws configure or AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY)
  
  default_tags {
    tags = {
      Project     = "ZTA-Hybrid-Cloud"
      Environment = "capstone"
      ManagedBy   = "terraform"
    }
  }
}

# =============================================================================
# VPC - Virtual Private Cloud
# =============================================================================
resource "aws_vpc" "zta_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "zta-hybrid-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "zta_igw" {
  vpc_id = aws_vpc.zta_vpc.id

  tags = {
    Name = "zta-igw"
  }
}

# Public Subnet
resource "aws_subnet" "zta_public_subnet" {
  vpc_id                  = aws_vpc.zta_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "zta-public-subnet"
  }
}

# Private Subnet (for workloads)
resource "aws_subnet" "zta_private_subnet" {
  vpc_id            = aws_vpc.zta_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "zta-private-subnet"
  }
}

# Route Table - Public
resource "aws_route_table" "zta_public_rt" {
  vpc_id = aws_vpc.zta_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zta_igw.id
  }

  # Route to OpenStack network via WireGuard (only if NOT using Transit Gateway)
  dynamic "route" {
    for_each = var.use_transit_gateway ? [] : [1]
    content {
      cidr_block           = var.openstack_cidr
      network_interface_id = aws_instance.wireguard_gateway.primary_network_interface_id
    }
  }

  tags = {
    Name = "zta-public-rt"
  }
}

resource "aws_route_table_association" "zta_public_rta" {
  subnet_id      = aws_subnet.zta_public_subnet.id
  route_table_id = aws_route_table.zta_public_rt.id
}

# NAT Gateway for private subnet
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "zta-nat-eip"
  }
}

resource "aws_nat_gateway" "zta_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.zta_public_subnet.id

  tags = {
    Name = "zta-nat-gateway"
  }

  depends_on = [aws_internet_gateway.zta_igw]
}

# Route Table - Private
resource "aws_route_table" "zta_private_rt" {
  vpc_id = aws_vpc.zta_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.zta_nat.id
  }

  # Route to OpenStack via WireGuard (only if NOT using Transit Gateway)
  dynamic "route" {
    for_each = var.use_transit_gateway ? [] : [1]
    content {
      cidr_block           = var.openstack_cidr
      network_interface_id = aws_instance.wireguard_gateway.primary_network_interface_id
    }
  }

  tags = {
    Name = "zta-private-rt"
  }
}

resource "aws_route_table_association" "zta_private_rta" {
  subnet_id      = aws_subnet.zta_private_subnet.id
  route_table_id = aws_route_table.zta_private_rt.id
}

# =============================================================================
# SECURITY GROUPS - Zero Trust Network Security
# =============================================================================

# WireGuard VPN Security Group
resource "aws_security_group" "wireguard_sg" {
  name        = "zta-wireguard-sg"
  description = "Security group for WireGuard VPN Gateway"
  vpc_id      = aws_vpc.zta_vpc.id

  # WireGuard UDP port
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard VPN"
  }

  # SSH from specific IPs only (Zero Trust)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Allow all from OpenStack (via VPN)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.openstack_cidr]
    description = "Traffic from OpenStack via VPN"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "zta-wireguard-sg"
  }
}

# Workload Security Group (Zero Trust - deny by default)
resource "aws_security_group" "workload_sg" {
  name        = "zta-workload-sg"
  description = "Zero Trust security group for workloads - deny by default"
  vpc_id      = aws_vpc.zta_vpc.id

  # Only allow traffic from WireGuard gateway (authenticated traffic)
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.wireguard_sg.id]
    description     = "Only from VPN gateway"
  }

  # Allow internal VPC communication
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Internal VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zta-workload-sg"
  }
}

# =============================================================================
# EC2 INSTANCES
# =============================================================================

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# WireGuard VPN Gateway Instance
resource "aws_instance" "wireguard_gateway" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.wireguard_instance_type
  subnet_id                   = aws_subnet.zta_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.wireguard_sg.id]
  key_name                    = var.key_pair_name
  source_dest_check           = false  # Required for VPN routing
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/wireguard-setup.sh", {
    wg_private_key     = var.wg_aws_private_key
    wg_address         = var.wg_aws_address
    openstack_endpoint = var.openstack_wg_endpoint
    openstack_pubkey   = var.openstack_wg_pubkey
    openstack_cidr     = var.openstack_cidr
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "zta-wireguard-gateway"
    Role = "vpn-gateway"
  }
}

# Workload Instance (Example - can deploy K3s worker here)
resource "aws_instance" "workload" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.workload_instance_type
  subnet_id              = aws_subnet.zta_private_subnet.id
  vpc_security_group_ids = [aws_security_group.workload_sg.id]
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/scripts/workload-setup.sh", {
    k3s_master_ip = var.openstack_k3s_master_ip
    k3s_token     = var.k3s_token
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "zta-aws-workload"
    Role = "k3s-worker"
  }

  depends_on = [aws_nat_gateway.zta_nat]
}

# =============================================================================
# VPC FLOW LOGS (Security Monitoring)
# =============================================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/zta-flow-logs"
  retention_in_days = 7

  tags = {
    Name = "zta-vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "zta-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "zta-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.zta_vpc.id

  tags = {
    Name = "zta-vpc-flow-log"
  }
}
