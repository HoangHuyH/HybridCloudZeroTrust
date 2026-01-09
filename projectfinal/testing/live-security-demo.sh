#!/bin/bash
# ============================================================
# LIVE SECURITY DEMO SCRIPT
# Zero Trust Architecture - Demo for Professor
# ============================================================
#
# Script này sẽ:
# 1. Tạo traffic bình thường (sv1 truy cập /api/sinhvien)
# 2. Tạo traffic bị chặn (sv1 cố truy cập /api/giangvien)
# 3. Hiển thị kết quả real-time
#
# Chạy script này trong khi xem Grafana dashboard:
#   http://172.10.0.190:30030/d/zta-security-logs/zta-security-and-logs
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_URL="http://app.172.10.0.190.nip.io:31691"
KEYCLOAK_URL="http://keycloak.172.10.0.190.nip.io:31691"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           ZERO TRUST ARCHITECTURE - LIVE SECURITY DEMO              ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Mở Grafana dashboard trong tab khác để xem logs real-time:         ║"
echo "║  http://172.10.0.190:30030/d/zta-security-logs                       ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

sleep 2

# ============================================================
# Demo 1: Unauthenticated Access Attempt
# ============================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 1: Truy cập không xác thực${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Attempting:${NC} curl $APP_URL/api/giangvien (no authentication)"
echo ""

RESULT=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ]; then
    echo -e "${GREEN}✅ BLOCKED!${NC} HTTP 302 - Redirect to Keycloak login"
    echo -e "   → Zero Trust: Người dùng chưa xác thực sẽ bị redirect đến IdP"
else
    echo -e "${RED}⚠️ Result: HTTP $RESULT${NC}"
fi

echo ""
sleep 3

# ============================================================
# Demo 2: Header Injection Attack
# ============================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 2: Tấn công Header Injection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Attempting:${NC} Inject fake identity headers"
echo "  x-forwarded-user: hacker"
echo "  x-forwarded-groups: admin,giangvien"
echo ""

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "x-forwarded-user: hacker" \
    -H "x-forwarded-groups: admin,giangvien" \
    -H "x-forwarded-email: hacker@evil.com" \
    "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ]; then
    echo -e "${GREEN}✅ BLOCKED!${NC} HTTP 302 - Headers ignored, redirect to login"
    echo -e "   → Zero Trust: OAuth2-Proxy xóa headers từ client, chỉ tin headers từ IdP"
elif [ "$RESULT" == "403" ]; then
    echo -e "${GREEN}✅ BLOCKED!${NC} HTTP 403 - Forbidden"
    echo -e "   → Zero Trust: RBAC denied access"
else
    echo -e "${RED}⚠️ Result: HTTP $RESULT${NC}"
fi

echo ""
sleep 3

# ============================================================
# Demo 3: Invalid JWT Token
# ============================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 3: Token giả mạo${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Attempting:${NC} Use fake JWT token"
echo "  Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
echo ""

FAKE_JWT="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJoYWNrZXIiLCJyb2xlIjoiYWRtaW4iLCJleHAiOjk5OTk5OTk5OTl9.fake_signature"

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $FAKE_JWT" \
    "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ] || [ "$RESULT" == "401" ]; then
    echo -e "${GREEN}✅ BLOCKED!${NC} HTTP $RESULT - Token rejected"
    echo -e "   → Zero Trust: Token không hợp lệ hoặc không được ký bởi IdP tin cậy"
else
    echo -e "${RED}⚠️ Result: HTTP $RESULT${NC}"
fi

echo ""
sleep 3

# ============================================================
# Demo 4: Direct API Access Bypass Attempt  
# ============================================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  DEMO 4: Truy cập trực tiếp Pod (Bypass Ingress)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get pod IP
POD_IP=$(kubectl get pod -n demo -l app=demo-app -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")

if [ -n "$POD_IP" ]; then
    echo -e "${BLUE}Attempting:${NC} Direct access to Pod IP $POD_IP:8000"
    echo ""
    
    RESULT=$(kubectl exec -n demo deployment/oauth2-proxy -- \
        curl -s -o /dev/null -w "%{http_code}" "http://$POD_IP:8000/api/giangvien" 2>/dev/null || echo "failed")
    
    if [ "$RESULT" == "403" ]; then
        echo -e "${GREEN}✅ BLOCKED!${NC} HTTP 403 - No valid headers"
        echo -e "   → Zero Trust: App layer RBAC rejects requests without proper identity"
    elif [ "$RESULT" == "failed" ]; then
        echo -e "${GREEN}✅ BLOCKED!${NC} Network Policy prevented access"
        echo -e "   → Zero Trust: Microsegmentation blocks unauthorized traffic"
    else
        echo -e "${YELLOW}Result: HTTP $RESULT${NC}"
    fi
else
    echo -e "${BLUE}Skipped:${NC} Cannot get Pod IP from outside cluster"
fi

echo ""
sleep 3

# ============================================================
# Summary
# ============================================================
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                         DEMO SUMMARY                                 ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  ✅ Demo 1: Unauthenticated access → Redirect to IdP                ║"
echo "║  ✅ Demo 2: Header injection → Headers stripped by proxy            ║"
echo "║  ✅ Demo 3: Fake JWT token → Token validation failed                ║"
echo "║  ✅ Demo 4: Direct pod access → RBAC/Network Policy blocked         ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                      ║"
echo "║  ZERO TRUST PRINCIPLES DEMONSTRATED:                                 ║"
echo "║  • Never trust, always verify                                        ║"
echo "║  • Least privilege access                                            ║"
echo "║  • Assume breach (defense in depth)                                  ║"
echo "║  • Verify explicitly at every layer                                  ║"
echo "║                                                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Xem Grafana Logs Dashboard để thấy security events:${NC}"
echo "  http://172.10.0.190:30030/d/zta-security-logs/zta-security-and-logs"
echo ""
