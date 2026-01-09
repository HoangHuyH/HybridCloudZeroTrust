#!/bin/bash
# ============================================================
# USER DATA SCRIPT - AWS ZTA Microservice Bootstrap
# Installs Docker, WireGuard, and runs the backend API
# ============================================================

set -e

# Log output
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting ZTA Microservice setup at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    docker.io \
    docker-compose \
    wireguard \
    wireguard-tools \
    python3-pip \
    python3-venv \
    curl \
    jq \
    net-tools \
    htop

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# ============================================================
# Create ZTA Backend API Application
# ============================================================
mkdir -p /opt/zta-api
cd /opt/zta-api

# Create the FastAPI application
cat > main.py << 'PYTHON_EOF'
"""
ZTA AWS Microservice - Backend API
Zero Trust Architecture Capstone Project
Hybrid Cloud: OpenStack + AWS
"""
from fastapi import FastAPI, Request, Header
from fastapi.responses import JSONResponse
from datetime import datetime
import os
import socket
import json

app = FastAPI(
    title="ZTA AWS Microservice",
    description="Backend API running on AWS for Zero Trust Architecture Demo",
    version="1.0.0"
)

# ============================================================
# HEALTH & INFO ENDPOINTS
# ============================================================
@app.get("/")
def root():
    return {
        "service": "ZTA AWS Microservice",
        "status": "running",
        "cloud": "AWS",
        "region": os.getenv("AWS_REGION", "ap-southeast-1"),
        "hostname": socket.gethostname(),
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
def health():
    return {"status": "healthy", "cloud": "aws"}

@app.get("/api/info")
def info():
    """Return detailed service information"""
    return {
        "service_name": "zta-aws-backend",
        "version": "1.0.0",
        "cloud_provider": "AWS",
        "architecture": "Zero Trust",
        "features": [
            "Identity-aware access",
            "mTLS ready",
            "WireGuard VPN",
            "CloudWatch logging"
        ],
        "endpoints": {
            "/": "Service info",
            "/health": "Health check",
            "/api/info": "Detailed info",
            "/api/data": "Protected data (requires auth)",
            "/api/hybrid-test": "Test hybrid cloud connectivity"
        }
    }

# ============================================================
# PROTECTED DATA ENDPOINT - Simulates sensitive data access
# ============================================================
@app.get("/api/data")
def get_data(
    request: Request,
    x_forwarded_user: str = Header(None),
    x_forwarded_groups: str = Header(None),
    authorization: str = Header(None)
):
    """
    Protected data endpoint - In production, this would be protected by:
    1. mTLS (Istio sidecar)
    2. JWT validation
    3. OPA policy check
    """
    # Log access attempt
    client_ip = request.client.host if request.client else "unknown"
    
    # Check if request has identity headers (from oauth2-proxy)
    if x_forwarded_user:
        return {
            "status": "success",
            "message": "Access granted to AWS protected data",
            "data": {
                "records": [
                    {"id": 1, "name": "AWS Resource Alpha", "type": "compute"},
                    {"id": 2, "name": "AWS Resource Beta", "type": "storage"},
                    {"id": 3, "name": "AWS Resource Gamma", "type": "network"}
                ],
                "total": 3,
                "classification": "confidential"
            },
            "access_info": {
                "user": x_forwarded_user,
                "groups": x_forwarded_groups,
                "client_ip": client_ip,
                "cloud": "aws",
                "timestamp": datetime.now().isoformat()
            }
        }
    else:
        # Return limited data for demo purposes
        return {
            "status": "limited",
            "message": "Anonymous access - limited data",
            "data": {
                "records": [
                    {"id": 1, "name": "Public Resource", "type": "demo"}
                ],
                "total": 1,
                "classification": "public"
            },
            "access_info": {
                "user": "anonymous",
                "client_ip": client_ip,
                "cloud": "aws",
                "timestamp": datetime.now().isoformat()
            }
        }

# ============================================================
# HYBRID CLOUD TEST ENDPOINT
# ============================================================
@app.get("/api/hybrid-test")
def hybrid_test(request: Request):
    """Test endpoint for verifying hybrid cloud connectivity"""
    client_ip = request.client.host if request.client else "unknown"
    
    # Check if request is from OpenStack network (via WireGuard)
    is_from_openstack = client_ip.startswith("172.10.") or client_ip.startswith("10.42.")
    
    return {
        "test": "hybrid_cloud_connectivity",
        "status": "success",
        "source": {
            "client_ip": client_ip,
            "is_from_openstack": is_from_openstack,
            "network_zone": "openstack-private" if is_from_openstack else "public-internet"
        },
        "destination": {
            "cloud": "aws",
            "region": os.getenv("AWS_REGION", "ap-southeast-1"),
            "hostname": socket.gethostname()
        },
        "zero_trust_checks": {
            "identity_verified": "x-forwarded-user" in dict(request.headers),
            "mtls_enabled": False,  # Would be True with Istio
            "vpn_tunnel": is_from_openstack
        },
        "timestamp": datetime.now().isoformat()
    }

# ============================================================
# METRICS ENDPOINT (for Prometheus)
# ============================================================
@app.get("/metrics")
def metrics():
    """Prometheus-compatible metrics endpoint"""
    metrics_text = """
# HELP zta_requests_total Total requests to ZTA service
# TYPE zta_requests_total counter
zta_requests_total{service="aws-backend",status="success"} 100

# HELP zta_service_info Service information
# TYPE zta_service_info gauge
zta_service_info{version="1.0.0",cloud="aws"} 1

# HELP zta_health_status Service health status
# TYPE zta_health_status gauge
zta_health_status{service="aws-backend"} 1
"""
    return JSONResponse(content=metrics_text, media_type="text/plain")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
PYTHON_EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.109.0
uvicorn==0.27.0
python-multipart==0.0.6
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  zta-api:
    build: .
    container_name: zta-aws-api
    ports:
      - "8080:8080"
    environment:
      - AWS_REGION=ap-southeast-1
    restart: always
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Build and run
docker-compose up -d --build

# ============================================================
# Setup WireGuard VPN (will be configured later)
# ============================================================
echo "WireGuard will be configured separately for hybrid connectivity"

# Create WireGuard config directory
mkdir -p /etc/wireguard

# Generate WireGuard keys
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
chmod 600 /etc/wireguard/privatekey

# Create placeholder WireGuard config
cat > /etc/wireguard/wg0.conf << 'EOF'
# WireGuard VPN Configuration for Hybrid Cloud
# This will be updated with OpenStack peer information

[Interface]
# AWS side - will be configured
Address = 10.10.1.1/24
PrivateKey = REPLACE_WITH_PRIVATE_KEY
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# OpenStack peer will be added here
# [Peer]
# PublicKey = OPENSTACK_PUBLIC_KEY
# AllowedIPs = 172.10.0.0/16
# Endpoint = OPENSTACK_PUBLIC_IP:51820
EOF

# Enable IP forwarding for VPN routing
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# ============================================================
# Setup CloudWatch Agent for monitoring
# ============================================================
# Install CloudWatch agent
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb || apt-get -f install -y
rm amazon-cloudwatch-agent.deb

echo "ZTA Microservice setup completed at $(date)"
echo "API available at http://localhost:8080"
