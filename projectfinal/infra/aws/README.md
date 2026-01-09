# Zero Trust Hybrid Cloud - AWS Infrastructure

## 📋 Tổng quan

Terraform configuration để triển khai **Hybrid Cloud** kết nối:
- **OpenStack** (On-Premises) - K3s Master với ZTA services
- **AWS** (Public Cloud) - K3s Worker mở rộng

Kết nối qua **WireGuard VPN** tunnel đảm bảo:
- Mã hóa end-to-end
- Zero Trust network segmentation
- Secure cross-cloud communication

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      HYBRID CLOUD ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────┐         ┌─────────────────────────┐      │
│   │      OPENSTACK          │         │         AWS             │      │
│   │    (On-Premises)        │         │      (Cloud)            │      │
│   │                         │         │                         │      │
│   │  ┌─────────────────┐    │         │   ┌─────────────────┐   │      │
│   │  │  K3s Master     │    │ WireGuard│  │  WireGuard GW   │   │      │
│   │  │  172.10.0.190   │◄──────────────►│  10.100.1.x      │   │      │
│   │  └─────────────────┘    │   VPN    │   └─────────────────┘   │      │
│   │          │               │ Tunnel   │          │              │      │
│   │          │               │         │          │              │      │
│   │  ┌───────▼───────┐      │         │   ┌──────▼───────┐      │      │
│   │  │  ZTA Services │      │         │   │  K3s Worker  │      │      │
│   │  │  - Keycloak   │      │         │   │  10.100.2.x  │      │      │
│   │  │  - OAuth2     │      │         │   └──────────────┘      │      │
│   │  │  - Demo App   │      │         │                         │      │
│   │  └───────────────┘      │         │                         │      │
│   │                         │         │                         │      │
│   │  Network: 172.10.0.0/24 │         │  Network: 10.100.0.0/16 │      │
│   └─────────────────────────┘         └─────────────────────────┘      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📁 Cấu trúc thư mục

```
infra/aws/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example variables (copy to terraform.tfvars)
└── scripts/
    ├── wireguard-setup.sh  # User data script for WireGuard gateway
    └── workload-setup.sh   # User data script for workload instance
```

## 🚀 Hướng dẫn triển khai

### Prerequisites

1. **AWS Account** với IAM credentials (Access Key + Secret Key)
2. **AWS CLI** installed
3. **Terraform** >= 1.0.0
4. **WireGuard** installed trên OpenStack

### Step 1: Cấu hình WireGuard trên OpenStack

```bash
# SSH vào OpenStack K3s master
ssh -i /path/to/key.pem ubuntu@172.10.0.190

# Chạy setup script
cd /path/to/projectfinal/infra/wireguard
chmod +x setup-openstack.sh
./setup-openstack.sh

# Ghi nhớ Public Key output
```

### Step 2: Cấu hình AWS Credentials

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit với credentials thật
vim terraform.tfvars
```

Điền các giá trị:
```hcl
aws_access_key        = "AKIAXXXXXXXXXXXXXXXX"
aws_secret_key        = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
openstack_wg_endpoint = "PUBLIC_IP_OPENSTACK:51820"
openstack_wg_pubkey   = "PUBLIC_KEY_FROM_STEP_1"
key_pair_name         = "your-aws-keypair"
```

### Step 3: Deploy AWS Infrastructure

```bash
cd infra/aws

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply
terraform apply
```

### Step 4: Complete VPN Setup

Sau khi Terraform apply xong:

```bash
# Lấy AWS WireGuard public key
terraform output wireguard_public_key

# Trên OpenStack, thêm AWS peer
cd ../wireguard
./add-aws-peer.sh "AWS_PUBLIC_KEY" "AWS_PUBLIC_IP"
```

### Step 5: Verify Connectivity

```bash
# Từ OpenStack
ping 10.200.0.1  # AWS WireGuard tunnel IP
ping 10.100.2.x  # AWS workload private IP

# Từ AWS (SSH vào WireGuard gateway)
ping 10.200.0.2  # OpenStack tunnel IP
ping 172.10.0.190  # OpenStack K3s master
```

## 🔐 Zero Trust Security Features

### Network Segmentation
- **Security Groups** với deny-by-default
- Chỉ cho phép traffic từ VPN gateway đến workloads
- Microsegmentation giữa các subnets

### Encryption
- **WireGuard VPN** với modern cryptography (ChaCha20, Curve25519)
- All cross-cloud traffic encrypted
- **EBS encryption** cho storage

### Monitoring
- **VPC Flow Logs** ghi nhận tất cả network traffic
- CloudWatch integration
- Cross-cloud visibility

## 📊 Outputs sau khi deploy

```bash
terraform output

# Outputs:
# vpc_id                  = "vpc-xxxxxxxxx"
# wireguard_public_ip     = "x.x.x.x"
# wireguard_endpoint      = "x.x.x.x:51820"
# workload_private_ip     = "10.100.2.x"
# ssh_command_wireguard   = "ssh -i ~/.ssh/key.pem ubuntu@x.x.x.x"
```

## 🧹 Cleanup

```bash
# Destroy all AWS resources
terraform destroy

# Remove WireGuard config on OpenStack
sudo systemctl stop wg-quick@wg0
sudo rm /etc/wireguard/wg0.conf
```

## ⚠️ Important Notes

1. **Costs**: AWS resources will incur charges (t3.micro, NAT Gateway, etc.)
2. **Security**: Never commit `terraform.tfvars` to git
3. **Keys**: Rotate WireGuard keys periodically
4. **Firewall**: Ensure OpenStack security group allows UDP 51820
