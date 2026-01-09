# ============================================================
# ZERO TRUST ARCHITECTURE - AWS MICROSERVICE
# Hybrid Cloud: OpenStack (On-premise) + AWS (Public Cloud)
# ============================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ZTA-Capstone"
      Environment = "demo"
      ManagedBy   = "Terraform"
    }
  }
}

# ============================================================
# VPC - Isolated Network for ZTA Microservice
# ============================================================
resource "aws_vpc" "zta_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "zta-hybrid-vpc"
  }
}

# Internet Gateway for public access
resource "aws_internet_gateway" "zta_igw" {
  vpc_id = aws_vpc.zta_vpc.id

  tags = {
    Name = "zta-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.zta_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "zta-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.zta_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zta_igw.id
  }

  # Route to OpenStack via WireGuard VPN
  # Will be added after VPN is established
  # route {
  #   cidr_block           = "172.10.0.0/16"  # OpenStack network
  #   network_interface_id = aws_instance.zta_microservice.primary_network_interface_id
  # }

  tags = {
    Name = "zta-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# SECURITY GROUP - Zero Trust Principle: Least Privilege
# ============================================================
resource "aws_security_group" "zta_sg" {
  name        = "zta-microservice-sg"
  description = "Security group for ZTA microservice - minimal access"
  vpc_id      = aws_vpc.zta_vpc.id

  # SSH - Only from specific IPs (your IP)
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # HTTP - API endpoint
  ingress {
    description = "HTTP API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Will be restricted to VPN later
  }

  # WireGuard VPN
  ingress {
    description = "WireGuard VPN"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]  # OpenStack can connect
  }

  # HTTPS for secure API
  ingress {
    description = "HTTPS API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zta-microservice-sg"
  }
}

# ============================================================
# EC2 INSTANCE - AWS Microservice (Backend API)
# ============================================================
resource "aws_instance" "zta_microservice" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.zta_sg.id]

  # Enable detailed monitoring for observability
  monitoring = true

  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    openstack_cidr = var.openstack_cidr
  }))

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name    = "zta-aws-microservice"
    Role    = "backend-api"
    ZTAZone = "aws-public"
  }
}

# Elastic IP for stable endpoint
resource "aws_eip" "zta_eip" {
  instance = aws_instance.zta_microservice.id
  domain   = "vpc"

  tags = {
    Name = "zta-microservice-eip"
  }
}

# ============================================================
# CLOUDWATCH - Monitoring & Logging (Observability)
# ============================================================
resource "aws_cloudwatch_log_group" "zta_logs" {
  name              = "/zta/microservice"
  retention_in_days = 7

  tags = {
    Name = "zta-microservice-logs"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "zta-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when CPU > 80%"

  dimensions = {
    InstanceId = aws_instance.zta_microservice.id
  }
}

# ============================================================
# IAM ROLE - For EC2 to access CloudWatch (Least Privilege)
# ============================================================
resource "aws_iam_role" "zta_ec2_role" {
  name = "zta-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "zta-cloudwatch-policy"
  role = aws_iam_role.zta_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "zta_profile" {
  name = "zta-ec2-profile"
  role = aws_iam_role.zta_ec2_role.name
}
