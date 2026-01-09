#!/bin/bash
# ============================================================
# ATTACK SIMULATION - LATERAL MOVEMENT TEST
# Zero Trust Architecture - Security Testing
# Based on MITRE ATT&CK Framework
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="demo"
LOG_FILE="/tmp/zta-attack-simulation-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  ZERO TRUST ATTACK SIMULATION - LATERAL MOVEMENT          ${NC}"
echo -e "${BLUE}  Testing T2: Lateral Movement Scenarios                    ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo ""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

test_result() {
    if [ "$1" == "blocked" ]; then
        echo -e "${GREEN}[PASS]${NC} $2 - Attack was BLOCKED (ZTA working)" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[FAIL]${NC} $2 - Attack was ALLOWED (ZTA vulnerability)" | tee -a "$LOG_FILE"
    fi
}

# ============================================================
# T2.1: Pod-to-Pod Communication Without Authorization
# Scenario: Compromised pod tries to access another service
# ============================================================
echo -e "\n${YELLOW}=== T2.1: Unauthorized Pod-to-Pod Communication ===${NC}"
log "Testing: Unauthorized pod trying to access protected service"

# Create attacker pod
kubectl run attacker-pod --image=curlimages/curl:latest \
    -n $NAMESPACE \
    --restart=Never \
    --command -- sleep 3600 \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

sleep 5

# Try to access demo-app directly (bypass oauth2-proxy)
echo "Attempting direct access to demo-app..."
RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    http://demo-app:8000/api/giangvien 2>/dev/null || echo "blocked")

if [ "$RESULT" == "403" ] || [ "$RESULT" == "blocked" ] || [ "$RESULT" == "000" ]; then
    test_result "blocked" "Direct pod access to /api/giangvien"
else
    test_result "allowed" "Direct pod access returned HTTP $RESULT"
fi

# ============================================================
# T2.2: Try to Access Keycloak Admin Without Auth
# ============================================================
echo -e "\n${YELLOW}=== T2.2: Unauthorized Keycloak Admin Access ===${NC}"
log "Testing: Direct access to Keycloak admin console"

RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    http://keycloak:8080/admin 2>/dev/null || echo "blocked")

if [ "$RESULT" == "403" ] || [ "$RESULT" == "401" ] || [ "$RESULT" == "302" ]; then
    test_result "blocked" "Keycloak admin access (requires authentication)"
else
    test_result "allowed" "Keycloak admin returned HTTP $RESULT"
fi

# ============================================================
# T2.3: Cross-Namespace Access Attempt
# ============================================================
echo -e "\n${YELLOW}=== T2.3: Cross-Namespace Access Attempt ===${NC}"
log "Testing: Access to services in other namespaces"

# Try to access kube-dns in kube-system
RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    http://kube-dns.kube-system:53 2>/dev/null || echo "blocked")

log "kube-dns access result: $RESULT"

# Try to access Istio control plane
RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    http://istiod.istio-system:15010 2>/dev/null || echo "blocked")

if [ "$RESULT" == "blocked" ] || [ "$RESULT" == "000" ]; then
    test_result "blocked" "Istio control plane access"
else
    test_result "allowed" "Istio control plane returned HTTP $RESULT"
fi

# ============================================================
# T2.4: Metadata Service Access (Cloud Provider Attack)
# ============================================================
echo -e "\n${YELLOW}=== T2.4: Cloud Metadata Service Access ===${NC}"
log "Testing: Access to cloud metadata service"

# AWS metadata endpoint
RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 3 \
    http://169.254.169.254/latest/meta-data/ 2>/dev/null || echo "blocked")

if [ "$RESULT" == "blocked" ] || [ "$RESULT" == "000" ] || [ "$RESULT" == "403" ]; then
    test_result "blocked" "AWS metadata service access"
else
    test_result "allowed" "AWS metadata returned HTTP $RESULT"
fi

# ============================================================
# T2.5: Token Theft Simulation
# ============================================================
echo -e "\n${YELLOW}=== T2.5: Service Account Token Access ===${NC}"
log "Testing: Attempt to read service account token"

# Try to read mounted service account token
RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
    cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>&1 || echo "blocked")

if [ "$RESULT" == "blocked" ] || [[ "$RESULT" == *"No such file"* ]]; then
    test_result "blocked" "Service account token read"
    log "Token not accessible or doesn't exist"
else
    test_result "allowed" "Service account token is readable"
    log "WARNING: Token is accessible!"
fi

# ============================================================
# T2.6: Port Scanning Internal Network
# ============================================================
echo -e "\n${YELLOW}=== T2.6: Internal Network Port Scanning ===${NC}"
log "Testing: Port scanning internal services"

echo "Scanning common ports on demo-app..."
for PORT in 22 80 443 3306 5432 6379 8080 8000 9090; do
    RESULT=$(kubectl exec -n $NAMESPACE attacker-pod -- \
        timeout 2 sh -c "echo >/dev/tcp/demo-app/$PORT" 2>&1 && echo "open" || echo "closed")
    log "Port $PORT: $RESULT"
done

# ============================================================
# Cleanup
# ============================================================
echo -e "\n${YELLOW}=== Cleanup ===${NC}"
kubectl delete pod attacker-pod -n $NAMESPACE --ignore-not-found=true 2>/dev/null

# ============================================================
# Summary
# ============================================================
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}  ATTACK SIMULATION SUMMARY                                 ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Full log saved to: $LOG_FILE"
echo ""
echo -e "${GREEN}Passed tests indicate Zero Trust controls are working.${NC}"
echo -e "${RED}Failed tests indicate potential vulnerabilities.${NC}"
echo ""
echo "Recommendations:"
echo "1. Enable NetworkPolicy to restrict pod-to-pod communication"
echo "2. Enable Istio mTLS (STRICT mode) for all services"
echo "3. Use OPA/Gatekeeper for policy enforcement"
echo "4. Block metadata service access in production"
