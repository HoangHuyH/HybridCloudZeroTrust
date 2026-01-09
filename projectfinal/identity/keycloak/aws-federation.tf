# Keycloak Federation với AWS IAM
# Cho phép users Keycloak assume AWS IAM Roles qua OIDC

# Biến cần set
variable "keycloak_issuer_url" {
  description = "Keycloak OIDC Issuer URL"
  default     = "http://keycloak.172.10.0.190.nip.io:31691/realms/zta"
}

variable "keycloak_client_id" {
  description = "Keycloak Client ID"
  default     = "aws-federation"
}

# 1. Tạo OIDC Identity Provider trong AWS
resource "aws_iam_openid_connect_provider" "keycloak" {
  url = var.keycloak_issuer_url

  client_id_list = [
    var.keycloak_client_id,
    "sts.amazonaws.com"
  ]

  # Thumbprint của Keycloak certificate
  # Lấy bằng: openssl s_client -servername keycloak.xxx -showcerts -connect keycloak.xxx:443
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = {
    Name        = "keycloak-oidc-provider"
    Project     = "ZTA"
    Environment = "lab"
  }
}

# 2. IAM Role cho Giảng viên
resource "aws_iam_role" "giangvien_role" {
  name = "ZTA-GiangVien-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.keycloak.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.keycloak_issuer_url, "https://", "")}:aud" = var.keycloak_client_id
          }
          StringLike = {
            "${replace(var.keycloak_issuer_url, "https://", "")}:sub" = "*"
          }
          # Chỉ users trong group giangvien mới assume được
          ForAnyValue:StringEquals = {
            "${replace(var.keycloak_issuer_url, "https://", "")}:groups" = "giangvien"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "ZTA-GiangVien-Role"
    Project = "ZTA"
  }
}

# 3. IAM Role cho Sinh viên
resource "aws_iam_role" "sinhvien_role" {
  name = "ZTA-SinhVien-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.keycloak.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.keycloak_issuer_url, "https://", "")}:aud" = var.keycloak_client_id
          }
          ForAnyValue:StringEquals = {
            "${replace(var.keycloak_issuer_url, "https://", "")}:groups" = "sinhvien"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "ZTA-SinhVien-Role"
    Project = "ZTA"
  }
}

# 4. Policy cho Giảng viên - Full S3 access
resource "aws_iam_role_policy" "giangvien_policy" {
  name = "GiangVienS3Policy"
  role = aws_iam_role.giangvien_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::zta-education-bucket",
          "arn:aws:s3:::zta-education-bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# 5. Policy cho Sinh viên - Read-only S3
resource "aws_iam_role_policy" "sinhvien_policy" {
  name = "SinhVienS3Policy"
  role = aws_iam_role.sinhvien_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::zta-education-bucket",
          "arn:aws:s3:::zta-education-bucket/public/*"
        ]
      }
    ]
  })
}

# 6. S3 Bucket cho demo
resource "aws_s3_bucket" "education" {
  bucket = "zta-education-bucket-${random_string.suffix.result}"

  tags = {
    Name    = "ZTA Education Bucket"
    Project = "ZTA"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Outputs
output "keycloak_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.keycloak.arn
  description = "ARN of Keycloak OIDC Provider"
}

output "giangvien_role_arn" {
  value       = aws_iam_role.giangvien_role.arn
  description = "ARN of Giảng viên IAM Role"
}

output "sinhvien_role_arn" {
  value       = aws_iam_role.sinhvien_role.arn
  description = "ARN of Sinh viên IAM Role"
}

output "education_bucket" {
  value       = aws_s3_bucket.education.bucket
  description = "S3 bucket for education resources"
}
