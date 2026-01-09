#!/bin/bash
# =============================================================================
# DEPLOY ZERO TRUST DEMO APP ON AWS WORKLOAD INSTANCE
# =============================================================================
# Script này deploy ứng dụng demo FastAPI lên AWS workload instance
# Truy cập qua Transit Gateway từ Load Balancer
# =============================================================================

set -e

# Logging
exec > >(tee /var/log/zta-app-setup.log|logger -t zta-app -s 2>/dev/console) 2>&1

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   ZERO TRUST DEMO APP DEPLOYMENT ON AWS                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Install Docker
echo "[1/5] Installing Docker..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Install Docker Compose
echo "[2/5] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application directory
echo "[3/5] Creating application directory..."
mkdir -p /opt/zta-app
cd /opt/zta-app

# Create FastAPI Demo Application
echo "[4/5] Creating Demo Application..."

cat > main.py << 'PYTHON_APP'
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
from datetime import datetime

app = FastAPI(
    title="Zero Trust Architecture Demo",
    description="Demo application for ZTA Capstone Project - AWS Deployment",
    version="2.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simulated data
SCHEDULE_DATA = {
    "giangvien": {
        "name": "Thời Khóa Biểu Giảng Viên",
        "schedule": [
            {"day": "Thứ 2", "time": "07:30-09:30", "subject": "An toàn thông tin", "room": "A101", "class": "CNTT01"},
            {"day": "Thứ 3", "time": "09:30-11:30", "subject": "Mạng máy tính", "room": "B205", "class": "CNTT02"},
            {"day": "Thứ 5", "time": "13:30-15:30", "subject": "Zero Trust Architecture", "room": "Lab1", "class": "CNTT01"},
        ]
    },
    "sinhvien": {
        "name": "Thời Khóa Biểu Sinh Viên",
        "schedule": [
            {"day": "Thứ 2", "time": "07:30-09:30", "subject": "An toàn thông tin", "room": "A101", "teacher": "TS. Nguyễn Văn A"},
            {"day": "Thứ 4", "time": "13:30-15:30", "subject": "Lập trình Python", "room": "Lab2", "teacher": "ThS. Trần Văn B"},
            {"day": "Thứ 6", "time": "09:30-11:30", "subject": "Cơ sở dữ liệu", "room": "C301", "teacher": "TS. Lê Văn C"},
        ]
    }
}

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    user = request.headers.get("x-forwarded-user", "anonymous")
    groups = request.headers.get("x-forwarded-groups", "")
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Zero Trust Architecture Demo</title>
        <meta charset="utf-8">
        <style>
            * {{ margin: 0; padding: 0; box-sizing: border-box; }}
            body {{ 
                font-family: 'Segoe UI', Arial, sans-serif; 
                background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                min-height: 100vh;
                color: white;
            }}
            .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; }}
            .header {{ 
                text-align: center; 
                padding: 40px 20px;
                background: rgba(255,255,255,0.05);
                border-radius: 15px;
                margin-bottom: 30px;
            }}
            .header h1 {{ 
                font-size: 2.5em; 
                background: linear-gradient(90deg, #00d2ff, #3a7bd5);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
            }}
            .user-info {{
                background: rgba(0,210,255,0.1);
                border: 1px solid rgba(0,210,255,0.3);
                border-radius: 10px;
                padding: 20px;
                margin: 20px 0;
            }}
            .user-info h3 {{ color: #00d2ff; margin-bottom: 10px; }}
            .cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }}
            .card {{
                background: rgba(255,255,255,0.05);
                border: 1px solid rgba(255,255,255,0.1);
                border-radius: 15px;
                padding: 25px;
                transition: transform 0.3s, box-shadow 0.3s;
            }}
            .card:hover {{ 
                transform: translateY(-5px);
                box-shadow: 0 10px 30px rgba(0,210,255,0.2);
            }}
            .card h3 {{ color: #00d2ff; margin-bottom: 15px; }}
            .card a {{
                display: inline-block;
                background: linear-gradient(90deg, #00d2ff, #3a7bd5);
                color: white;
                padding: 10px 20px;
                border-radius: 25px;
                text-decoration: none;
                margin-top: 15px;
            }}
            .aws-badge {{
                position: fixed;
                bottom: 20px;
                right: 20px;
                background: #ff9900;
                color: #232f3e;
                padding: 10px 20px;
                border-radius: 5px;
                font-weight: bold;
            }}
            .architecture {{
                background: rgba(255,255,255,0.03);
                border-radius: 10px;
                padding: 20px;
                margin: 20px 0;
                font-family: monospace;
                font-size: 12px;
                white-space: pre;
                overflow-x: auto;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🔐 Zero Trust Architecture</h1>
                <p>Enterprise Hybrid Cloud Demo - AWS Transit Gateway</p>
            </div>
            
            <div class="user-info">
                <h3>👤 User Information</h3>
                <p><strong>Username:</strong> {user}</p>
                <p><strong>Groups:</strong> {groups if groups else 'Not authenticated'}</p>
                <p><strong>Server Time:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
                <p><strong>Instance:</strong> AWS Workload (10.100.2.248)</p>
            </div>
            
            <div class="cards">
                <div class="card">
                    <h3>📋 API Endpoints</h3>
                    <p>Access the following endpoints:</p>
                    <ul style="margin: 10px 0; padding-left: 20px;">
                        <li>/api/me - User info</li>
                        <li>/api/tkb - Schedule (role-based)</li>
                        <li>/api/health - Health check</li>
                    </ul>
                    <a href="/api/me">View My Info</a>
                </div>
                
                <div class="card">
                    <h3>📅 Thời Khóa Biểu</h3>
                    <p>View schedule based on your role</p>
                    <a href="/api/tkb">View Schedule</a>
                </div>
                
                <div class="card">
                    <h3>🏗️ Architecture</h3>
                    <p>Multi-VPC Transit Gateway setup</p>
                    <a href="/api/architecture">View Details</a>
                </div>
            </div>
            
            <div class="architecture">
Internet → Load Balancer (18.142.152.247)
              │
              │ Transit Gateway
              ▼
        ┌─────────────────┐
        │ Workload VPC    │
        │ 10.100.0.0/16   │
        │                 │
        │ This Instance   │
        │ 10.100.2.248    │
        └─────────────────┘
            </div>
        </div>
        <div class="aws-badge">☁️ Powered by AWS</div>
    </body>
    </html>
    """
    return HTMLResponse(content=html)

@app.get("/api/me")
async def get_me(request: Request):
    return {
        "user": request.headers.get("x-forwarded-user", "anonymous"),
        "email": request.headers.get("x-forwarded-email", ""),
        "groups": request.headers.get("x-forwarded-groups", "").split(",") if request.headers.get("x-forwarded-groups") else [],
        "ip": request.client.host,
        "server": {
            "instance": "aws-workload",
            "ip": "10.100.2.248",
            "region": "ap-southeast-1",
            "timestamp": datetime.now().isoformat()
        }
    }

@app.get("/api/tkb")
async def get_schedule(request: Request):
    groups = request.headers.get("x-forwarded-groups", "").lower()
    user = request.headers.get("x-forwarded-user", "anonymous")
    
    if "giangvien" in groups:
        return {
            "user": user,
            "role": "giangvien",
            "data": SCHEDULE_DATA["giangvien"]
        }
    elif "sinhvien" in groups:
        return {
            "user": user,
            "role": "sinhvien", 
            "data": SCHEDULE_DATA["sinhvien"]
        }
    else:
        return {
            "user": user,
            "role": "guest",
            "message": "Please login to view your schedule",
            "available_roles": ["giangvien", "sinhvien"]
        }

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "zta-demo-app",
        "version": "2.0.0",
        "location": "AWS ap-southeast-1",
        "instance": "10.100.2.248",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/architecture")
async def get_architecture():
    return {
        "project": "Zero Trust Architecture Capstone",
        "deployment": "AWS Multi-VPC with Transit Gateway",
        "components": {
            "public_vpc": {
                "cidr": "10.200.0.0/16",
                "purpose": "Internet-facing Load Balancer",
                "instances": ["nginx-lb: 18.142.152.247"]
            },
            "workload_vpc": {
                "cidr": "10.100.0.0/16",
                "purpose": "Application workloads",
                "instances": ["demo-app: 10.100.2.248"]
            },
            "transit_gateway": {
                "id": "tgw-06321ac15469997a8",
                "attachments": ["public-vpc", "workload-vpc", "vpn-openstack"]
            }
        },
        "security": {
            "network": "Transit Gateway isolation",
            "application": "Role-based access control",
            "identity": "Header-based authentication"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
PYTHON_APP

# Create requirements.txt
cat > requirements.txt << 'REQUIREMENTS'
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6
REQUIREMENTS

# Create Dockerfile
cat > Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKERFILE

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  zta-app:
    build: .
    container_name: zta-demo-app
    ports:
      - "8000:8000"
    restart: unless-stopped
    environment:
      - TZ=Asia/Ho_Chi_Minh
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
COMPOSE

# Build and run
echo "[5/5] Building and starting application..."
docker-compose up -d --build

# Wait for app to start
sleep 10

# Check status
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   DEPLOYMENT COMPLETE!                                        ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   Application URL: http://$(hostname -I | awk '{print $1}'):8000          ║"
echo "║   Health Check: curl http://localhost:8000/api/health         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Test health
curl -s http://localhost:8000/api/health | jq . || echo "App starting..."
