# ============================================================
# OUTPUTS - Connection Information
# ============================================================

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.zta_microservice.id
}

output "public_ip" {
  description = "Public IP of microservice"
  value       = aws_eip.zta_eip.public_ip
}

output "public_dns" {
  description = "Public DNS of microservice"
  value       = aws_eip.zta_eip.public_dns
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = "http://${aws_eip.zta_eip.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_eip.zta_eip.public_ip}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.zta_vpc.id
}

output "wireguard_endpoint" {
  description = "WireGuard VPN endpoint"
  value       = "${aws_eip.zta_eip.public_ip}:51820"
}

# Connection info for OpenStack
output "openstack_connection_info" {
  description = "Info needed to configure OpenStack side"
  value = {
    aws_public_ip    = aws_eip.zta_eip.public_ip
    aws_vpc_cidr     = var.vpc_cidr
    aws_subnet_cidr  = var.public_subnet_cidr
    wireguard_port   = 51820
    api_port         = 8080
  }
}
