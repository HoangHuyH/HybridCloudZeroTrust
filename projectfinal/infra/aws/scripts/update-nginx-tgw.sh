#!/bin/bash
# =============================================================================
# UPDATE NGINX TO POINT TO AWS WORKLOAD VPC VIA TRANSIT GATEWAY
# =============================================================================
# Cấu hình Nginx Load Balancer để proxy đến Workload VPC
# Kết nối qua Transit Gateway (hoàn toàn AWS native)
# =============================================================================

set -e

WORKLOAD_IP="10.100.2.248"
WORKLOAD_PORT="8000"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   UPDATING NGINX FOR TRANSIT GATEWAY ROUTING                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

echo "[1/3] Creating new Nginx configuration..."

cat > /etc/nginx/sites-available/zta-app << 'NGINX_CONFIG'
# =============================================================================
# Zero Trust Architecture - AWS Transit Gateway Routing
# =============================================================================
# Load Balancer (Public VPC) → Transit Gateway → Workload VPC
# =============================================================================

# Upstream - Workload VPC via Transit Gateway
upstream zta_backend {
    server 10.100.2.248:8000;
    keepalive 32;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# HTTP → HTTPS Redirect
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;
    
    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Logging
    access_log /var/log/nginx/zta-access.log combined;
    error_log /var/log/nginx/zta-error.log warn;
    
    # Connection limits
    limit_conn conn_limit 20;
    
    # Main Proxy
    location / {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://zta_backend;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Connection "";
        
        # Demo: Add fake auth headers for testing
        # In production, these come from OAuth2-Proxy
        proxy_set_header X-Forwarded-User "demo-user";
        proxy_set_header X-Forwarded-Groups "sinhvien";
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffers
        proxy_buffer_size 4k;
        proxy_buffers 8 16k;
    }
    
    # Health check endpoint (local)
    location /health {
        access_log off;
        return 200 "Load Balancer: OK\n";
        add_header Content-Type text/plain;
    }
    
    # Nginx status
    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
    }
}
NGINX_CONFIG

echo "[2/3] Testing Nginx configuration..."
nginx -t

echo "[3/3] Reloading Nginx..."
systemctl reload nginx

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   CONFIGURATION COMPLETE!                                     ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   Traffic Flow:                                               ║"
echo "║   Internet → Load Balancer (this) → Transit Gateway           ║"
echo "║            → Workload VPC (10.100.2.248:8000)                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Test backend connectivity
echo ""
echo "Testing backend connectivity via Transit Gateway..."
curl -s --connect-timeout 5 http://10.100.2.248:8000/api/health 2>/dev/null && echo "✅ Backend reachable!" || echo "⚠️ Backend not yet available (deploy app first)"
