#!/bin/bash
#====================================================================
# ZERO TRUST ARCHITECTURE - COMPLETE DEPLOYMENT SCRIPT
# Author: ZTA Capstone Project Team
# Description: Deploy toàn bộ hệ thống ZTA với Keycloak, OAuth2-Proxy, Demo-App
#====================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   ZERO TRUST ARCHITECTURE DEPLOYMENT  ${NC}"
echo -e "${BLUE}========================================${NC}"

# Variables
NAMESPACE="demo"
KEYCLOAK_HOST="keycloak.172.10.0.190.nip.io"
APP_HOST="app.172.10.0.190.nip.io"
NODEPORT="31691"

#--------------------------------------------------------------------
# Step 1: Create Namespace
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 1/7] Tạo Namespace...${NC}"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace $NAMESPACE istio-injection=enabled --overwrite
echo -e "${GREEN}✓ Namespace $NAMESPACE đã sẵn sàng với Istio injection${NC}"

#--------------------------------------------------------------------
# Step 2: Deploy Keycloak (Identity Provider)
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 2/7] Deploy Keycloak...${NC}"
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/keycloak/keycloak.yaml -n $NAMESPACE
echo -e "${GREEN}✓ Keycloak deployed${NC}"

#--------------------------------------------------------------------
# Step 3: Deploy OAuth2-Proxy Secret
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 3/7] Deploy OAuth2-Proxy Secret...${NC}"
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/app/oauth2-proxy-secret.yaml -n $NAMESPACE
echo -e "${GREEN}✓ OAuth2-Proxy Secret deployed${NC}"

#--------------------------------------------------------------------
# Step 4: Deploy OAuth2-Proxy
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 4/7] Deploy OAuth2-Proxy...${NC}"
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/app/oauth2-proxy.yaml -n $NAMESPACE
echo -e "${GREEN}✓ OAuth2-Proxy deployed${NC}"

#--------------------------------------------------------------------
# Step 5: Deploy Demo Application
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 5/7] Deploy Demo Application...${NC}"
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/app/demo-app.yaml -n $NAMESPACE
echo -e "${GREEN}✓ Demo Application deployed${NC}"

#--------------------------------------------------------------------
# Step 6: Deploy Istio Resources
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 6/7] Deploy Istio Gateway & VirtualServices...${NC}"
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/istio/zta-gw.yaml -n $NAMESPACE
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/istio/app-vs.yaml -n $NAMESPACE
kubectl apply -f /home/deployer/ZTAproject/projectfinal/k8s/istio/keycloak-vs.yaml -n $NAMESPACE
echo -e "${GREEN}✓ Istio resources deployed${NC}"

#--------------------------------------------------------------------
# Step 7: Wait for pods to be ready
#--------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 7/7] Đợi các pod sẵn sàng...${NC}"
echo "Waiting for Keycloak..."
kubectl wait --for=condition=ready pod -l app=keycloak -n $NAMESPACE --timeout=180s 2>/dev/null || true

echo "Waiting for OAuth2-Proxy..."
kubectl wait --for=condition=ready pod -l app=oauth2-proxy -n $NAMESPACE --timeout=120s 2>/dev/null || true

echo "Waiting for Demo-App..."
kubectl wait --for=condition=ready pod -l app=demo-app -n $NAMESPACE --timeout=120s 2>/dev/null || true

#--------------------------------------------------------------------
# Summary
#--------------------------------------------------------------------
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   DEPLOYMENT HOÀN TẤT!                ${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${BLUE}📊 Trạng thái pods:${NC}"
kubectl get pods -n $NAMESPACE

echo -e "\n${BLUE}📊 Trạng thái services:${NC}"
kubectl get svc -n $NAMESPACE

echo -e "\n${YELLOW}🌐 URLs:${NC}"
echo -e "   - Application: ${GREEN}http://${APP_HOST}:${NODEPORT}${NC}"
echo -e "   - Keycloak Admin: ${GREEN}http://${KEYCLOAK_HOST}:${NODEPORT}${NC}"

echo -e "\n${YELLOW}👤 Tài khoản demo:${NC}"
echo -e "   - Giảng viên: ${GREEN}gv1 / 123${NC} (có quyền truy cập /api/giangvien)"
echo -e "   - Sinh viên: ${GREEN}sv1 / 123${NC} (chỉ được truy cập /api/sinhvien)"
echo -e "   - Keycloak Admin: ${GREEN}admin / admin123${NC}"

echo -e "\n${YELLOW}🧪 Test Zero Trust:${NC}"
echo -e "   1. Truy cập http://${APP_HOST}:${NODEPORT}"
echo -e "   2. Đăng nhập với sv1/123 → thử /api/giangvien → bị chặn (403)"
echo -e "   3. Đăng nhập với gv1/123 → thử /api/giangvien → được phép (200)"

echo -e "\n${GREEN}Done! 🎉${NC}"
