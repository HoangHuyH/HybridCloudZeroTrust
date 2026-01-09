# ============================================================
# VARIABLES FOR ZTA AWS MICROSERVICE
# ============================================================

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"  # Singapore - gần Việt Nam
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.10.1.0/24"
}

variable "admin_ip" {
  description = "Admin IP for SSH access (your IP/32)"
  type        = string
  default     = "0.0.0.0/0"  # Should be restricted in production
}

variable "openstack_cidr" {
  description = "OpenStack network CIDR for VPN routing"
  type        = string
  default     = "172.10.0.0/16"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID"
  type        = string
  default     = "ami-0672fd5b9210aa093"  # Ubuntu 22.04 in ap-southeast-1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"  # Free tier eligible
}

variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
}
