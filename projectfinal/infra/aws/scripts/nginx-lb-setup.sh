#!/bin/bash
# =============================================================================
# NGINX REVERSE PROXY / LOAD BALANCER SETUP
# =============================================================================
# This script sets up Nginx as a reverse proxy to route traffic from Internet
# to the Zero Trust application running on OpenStack
# =============================================================================

set -e

# Variables from Terraform
OPENSTACK_MASTER_IP="${openstack_master_ip}"
OPENSTACK_ISTIO_PORT="${openstack_istio_port}"
DOMAIN_NAME="${domain_name}"
BACKEND_SERVERS="${backend_servers}"

# Logging
exec > >(tee /var/log/nginx-setup.log|logger -t nginx-setup -s 2>/dev/console) 2>&1

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   NGINX REVERSE PROXY SETUP FOR ZTA                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Update and install packages
echo "[1/6] Installing Nginx and Certbot..."
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# Create Nginx configuration
echo "[2/6] Configuring Nginx..."

cat > /etc/nginx/sites-available/zta-app << 'NGINX_CONFIG'
# =============================================================================
# Zero Trust Architecture - Reverse Proxy Configuration
# =============================================================================

# Upstream backend servers (OpenStack K3s cluster via Transit Gateway)
upstream zta_backend {
    # OpenStack Istio Ingress Gateway
    server ${openstack_master_ip}:${openstack_istio_port};
    
    # Keepalive connections for better performance
    keepalive 32;
}

# Rate limiting zone
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# HTTP Server - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_name} _;
    
    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS Server - Main Application
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domain_name} _;
    
    # SSL Configuration (will be managed by Certbot)
    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;
    
    # Modern SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';" always;
    
    # Access logging
    access_log /var/log/nginx/zta-access.log combined;
    error_log /var/log/nginx/zta-error.log warn;
    
    # Connection limits
    limit_conn conn_limit 20;
    
    # Main application
    location / {
        # Rate limiting
        limit_req zone=api_limit burst=20 nodelay;
        
        # Proxy settings
        proxy_pass http://zta_backend;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Connection settings
        proxy_set_header Connection "";
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffer_size 4k;
        proxy_buffers 8 16k;
        proxy_busy_buffers_size 24k;
        
        # WebSocket support (for Keycloak)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Keycloak specific routes
    location /auth/ {
        proxy_pass http://zta_backend;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Longer timeouts for Keycloak
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
        
        # Buffer for large responses
        proxy_buffer_size 8k;
        proxy_buffers 16 32k;
    }
    
    # OAuth2 Proxy routes
    location /oauth2/ {
        proxy_pass http://zta_backend;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Nginx status (internal only)
    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        deny all;
    }
}
NGINX_CONFIG

# Create SSL directory and generate self-signed certificate
echo "[3/6] Generating self-signed SSL certificate..."
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/selfsigned.key \
    -out /etc/nginx/ssl/selfsigned.crt \
    -subj "/C=VN/ST=HCM/L=HoChiMinh/O=ZTA-Capstone/OU=IT/CN=$DOMAIN_NAME"

# Enable the site
echo "[4/6] Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/zta-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "[5/6] Testing Nginx configuration..."
nginx -t

# Reload Nginx
echo "[6/6] Reloading Nginx..."
systemctl reload nginx

# Create status script
cat > /usr/local/bin/check-zta-status << 'STATUS_SCRIPT'
#!/bin/bash
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   ZTA LOAD BALANCER STATUS                                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Nginx Status:"
systemctl status nginx --no-pager | head -5
echo ""
echo "Backend Connectivity:"
curl -s -o /dev/null -w "OpenStack Backend: %%{http_code}\n" --connect-timeout 5 http://${openstack_master_ip}:${openstack_istio_port}/ || echo "Backend: UNREACHABLE"
echo ""
echo "Active Connections:"
curl -s http://localhost/nginx_status 2>/dev/null || echo "Status page not available"
STATUS_SCRIPT
chmod +x /usr/local/bin/check-zta-status

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   SETUP COMPLETE!                                             ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   Access your application at:                                 ║"
echo "║   https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)                              ║"
echo "║                                                               ║"
echo "║   To get Let's Encrypt certificate, run:                      ║"
echo "║   sudo certbot --nginx -d yourdomain.com                      ║"
echo "║                                                               ║"
echo "║   To check status: check-zta-status                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
