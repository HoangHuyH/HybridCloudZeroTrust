# =============================================================================
# VPC PUBLIC - INTERNET-FACING LOAD BALANCER
# =============================================================================
# VPC này chứa EC2 instance làm Reverse Proxy/Load Balancer
# Cho phép user từ Internet truy cập vào ứng dụng Zero Trust
# =============================================================================

# =============================================================================
# VPC PUBLIC - For Internet Access
# =============================================================================
resource "aws_vpc" "zta_public_vpc" {
  cidr_block           = var.public_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "zta-public-vpc"
    Purpose = "Internet-facing Load Balancer"
  }
}

# Internet Gateway for Public VPC
resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.zta_public_vpc.id

  tags = {
    Name = "zta-public-igw"
  }
}

# Public Subnet in AZ-a
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.zta_public_vpc.id
  cidr_block              = var.public_vpc_subnet_a_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "zta-public-subnet-a"
  }
}

# Public Subnet in AZ-b (for HA)
resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.zta_public_vpc.id
  cidr_block              = var.public_vpc_subnet_b_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "zta-public-subnet-b"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_vpc_rt" {
  vpc_id = aws_vpc.zta_public_vpc.id

  # Route to Internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_igw.id
  }

  # Route to Workload VPC via Transit Gateway
  route {
    cidr_block         = var.vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.zta_tgw.id
  }

  # Route to OpenStack via Transit Gateway
  route {
    cidr_block         = var.openstack_cidr
    transit_gateway_id = aws_ec2_transit_gateway.zta_tgw.id
  }

  # Route to K3s Pod Network via Transit Gateway
  route {
    cidr_block         = var.openstack_pod_cidr
    transit_gateway_id = aws_ec2_transit_gateway.zta_tgw.id
  }

  tags = {
    Name = "zta-public-vpc-rt"
  }

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.public_vpc_attachment]
}

resource "aws_route_table_association" "public_subnet_a_rta" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_vpc_rt.id
}

resource "aws_route_table_association" "public_subnet_b_rta" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_vpc_rt.id
}

# =============================================================================
# TRANSIT GATEWAY ATTACHMENT - Public VPC
# =============================================================================
resource "aws_ec2_transit_gateway_vpc_attachment" "public_vpc_attachment" {
  subnet_ids         = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.zta_tgw.id
  vpc_id             = aws_vpc.zta_public_vpc.id

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = {
    Name = "zta-public-vpc-attachment"
  }
}

# Add route in TGW Route Table for Public VPC
resource "aws_ec2_transit_gateway_route" "to_public_vpc" {
  destination_cidr_block         = var.public_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.public_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.zta_tgw_rt.id
}

# =============================================================================
# SECURITY GROUPS - Load Balancer
# =============================================================================
resource "aws_security_group" "lb_sg" {
  name        = "zta-lb-sg"
  description = "Security group for Load Balancer - Internet facing"
  vpc_id      = aws_vpc.zta_public_vpc.id

  # HTTP from Internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from Internet"
  }

  # HTTPS from Internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from Internet"
  }

  # SSH for management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "zta-lb-sg"
  }
}

# =============================================================================
# ELASTIC IP for Load Balancer
# =============================================================================
resource "aws_eip" "lb_eip" {
  domain = "vpc"

  tags = {
    Name = "zta-lb-eip"
  }
}

# =============================================================================
# EC2 INSTANCE - Nginx Reverse Proxy / Load Balancer
# =============================================================================
resource "aws_instance" "load_balancer" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.lb_instance_type
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.lb_sg.id]
  key_name               = var.key_pair_name

  user_data = base64encode(templatefile("${path.module}/scripts/nginx-lb-setup.sh", {
    openstack_master_ip = var.openstack_k3s_master_ip
    openstack_istio_port = var.openstack_istio_nodeport
    domain_name         = var.domain_name
    backend_servers     = var.backend_servers
  }))

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "zta-load-balancer"
    Role = "reverse-proxy"
  }

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.public_vpc_attachment]
}

# Associate Elastic IP with Load Balancer
resource "aws_eip_association" "lb_eip_assoc" {
  instance_id   = aws_instance.load_balancer.id
  allocation_id = aws_eip.lb_eip.id
}

# =============================================================================
# ROUTE 53 (Optional - if you have a domain)
# =============================================================================
# Uncomment if you have a Route 53 hosted zone
/*
resource "aws_route53_record" "zta_app" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_eip.lb_eip.public_ip]
}
*/

# =============================================================================
# UPDATE WORKLOAD VPC - Add route to Public VPC
# =============================================================================
resource "aws_route" "workload_to_public_vpc" {
  route_table_id         = aws_route_table.zta_private_rt.id
  destination_cidr_block = var.public_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.zta_tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.public_vpc_attachment]
}
