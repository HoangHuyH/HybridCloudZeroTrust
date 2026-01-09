#!/bin/bash
# ============================================================
# ATTACK SIMULATION - CROSS-CLOUD ACCESS TEST
# Zero Trust Architecture - Security Testing
# T3: Unauthorized Cross-Cloud Access
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - Update these with actual values
AWS_API_ENDPOINT="${AWS_API_ENDPOINT:-http://10.10.1.1:8080}"
OPENSTACK_NETWORK="172.10.0.0/16"
NAMESPACE="demo"
LOG_FILE="/tmp/zta-crosscloud-test-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  ZERO TRUST ATTACK SIMULATION - CROSS-CLOUD ACCESS        ${NC}"
echo -e "${BLUE}  Testing T3: Unauthorized Cross-Cloud Access              ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "AWS Endpoint: $AWS_API_ENDPOINT"
echo "Log file: $LOG_FILE"
echo ""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

test_result() {
    if [ "$1" == "blocked" ]; then
        echo -e "${GREEN}[PASS]${NC} $2 - Attack was BLOCKED" | tee -a "$LOG_FILE"
    elif [ "$1" == "allowed" ]; then
        echo -e "${RED}[FAIL]${NC} $2 - Attack was ALLOWED" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}[INFO]${NC} $2" | tee -a "$LOG_FILE"
    fi
}

# ============================================================
# T3.1: Direct Access to AWS from Unauthorized Pod
# ============================================================
echo -e "\n${YELLOW}=== T3.1: Unauthorized Pod -> AWS Access ===${NC}"
log "Testing: Unauthorized pod accessing AWS API"

# Create attacker pod without proper identity
kubectl run crosscloud-attacker --image=curlimages/curl:latest \
    -n $NAMESPACE \
    --restart=Never \
    --command -- sleep 3600 \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

sleep 5

# Try to access AWS API
RESULT=$(kubectl exec -n $NAMESPACE crosscloud-attacker -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    "$AWS_API_ENDPOINT/api/data" 2>/dev/null || echo "unreachable")

if [ "$RESULT" == "unreachable" ] || [ "$RESULT" == "000" ]; then
    test_result "blocked" "AWS API unreachable (network isolation working)"
elif [ "$RESULT" == "403" ] || [ "$RESULT" == "401" ]; then
    test_result "blocked" "AWS API returned $RESULT (auth required)"
else
    test_result "info" "AWS API returned HTTP $RESULT"
fi

# ============================================================
# T3.2: Access AWS with Spoofed Headers
# ============================================================
echo -e "\n${YELLOW}=== T3.2: Spoofed Identity Headers to AWS ===${NC}"
log "Testing: Accessing AWS with fake identity headers"

RESULT=$(kubectl exec -n $NAMESPACE crosscloud-attacker -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    -H "X-Forwarded-User: fake-admin" \
    -H "X-Forwarded-Groups: admin,giangvien" \
    -H "X-SPIFFE-ID: spiffe://fake.domain/fake-service" \
    "$AWS_API_ENDPOINT/api/data" 2>/dev/null || echo "unreachable")

log "Spoofed header access result: $RESULT"

# ============================================================
# T3.3: VPN Tunnel Verification
# ============================================================
echo -e "\n${YELLOW}=== T3.3: VPN Tunnel Status ===${NC}"
log "Checking WireGuard VPN tunnel status"

if command -v wg &> /dev/null; then
    WG_STATUS=$(wg show 2>/dev/null || echo "not configured")
    log "WireGuard status: $WG_STATUS"
else
    log "WireGuard not installed on this node"
fi

# ============================================================
# T3.4: AWS Metadata from OpenStack
# ============================================================
echo -e "\n${YELLOW}=== T3.4: AWS Metadata Access Attempt ===${NC}"
log "Testing: Access AWS metadata from OpenStack pod"

# This should always fail as metadata is local to AWS
RESULT=$(kubectl exec -n $NAMESPACE crosscloud-attacker -- \
    curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 3 \
    http://169.254.169.254/latest/meta-data/ 2>/dev/null || echo "blocked")

if [ "$RESULT" == "blocked" ] || [ "$RESULT" == "000" ]; then
    test_result "blocked" "AWS metadata not accessible from OpenStack (correct)"
else
    test_result "allowed" "WARNING: Metadata returned HTTP $RESULT"
fi

# ============================================================
# T3.5: Hybrid Connectivity Test (Legitimate)
# ============================================================
echo -e "\n${YELLOW}=== T3.5: Legitimate Hybrid Connectivity ===${NC}"
log "Testing: Legitimate cross-cloud access via VPN"

# This tests if the VPN is working for authorized traffic
RESULT=$(kubectl exec -n $NAMESPACE crosscloud-attacker -- \
    curl -s --connect-timeout 10 \
    "$AWS_API_ENDPOINT/api/hybrid-test" 2>/dev/null || echo "unreachable")

if [ "$RESULT" != "unreachable" ]; then
    log "Hybrid test response: $RESULT"
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
else
    log "AWS API unreachable - VPN may not be configured"
fi

# ============================================================
# T3.6: OpenStack -> AWS Direct Access (No VPN)
# ============================================================
echo -e "\n${YELLOW}=== T3.6: Direct Internet Access to AWS ===${NC}"
log "Testing: Access AWS via public IP (bypassing VPN)"

# Get AWS public IP from terraform output or environment
AWS_PUBLIC_IP="${AWS_PUBLIC_IP:-}"

if [ -n "$AWS_PUBLIC_IP" ]; then
    RESULT=$(kubectl exec -n $NAMESPACE crosscloud-attacker -- \
        curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 10 \
        "http://$AWS_PUBLIC_IP:8080/health" 2>/dev/null || echo "blocked")
    
    if [ "$RESULT" == "200" ]; then
        test_result "info" "AWS accessible via public IP (expected for demo)"
    else
        log "Public access result: $RESULT"
    fi
else
    log "AWS_PUBLIC_IP not set - skipping public access test"
fi

# ============================================================
# Cleanup
# ============================================================
echo -e "\n${YELLOW}=== Cleanup ===${NC}"
kubectl delete pod crosscloud-attacker -n $NAMESPACE --ignore-not-found=true 2>/dev/null

# ============================================================
# Summary
# ============================================================
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}  CROSS-CLOUD ATTACK SIMULATION SUMMARY                     ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Full log saved to: $LOG_FILE"
echo ""
echo "Zero Trust Hybrid Cloud Controls:"
echo "1. WireGuard VPN encrypts all cross-cloud traffic"
echo "2. AWS Security Groups restrict source IPs"
echo "3. Identity headers are verified at AWS side"
echo "4. mTLS should be enabled for service-to-service"
echo ""
echo "Recommendations:"
echo "1. Restrict AWS API to VPN IP range only"
echo "2. Verify SPIFFE/SPIRE IDs for cross-cloud calls"
echo "3. Enable mutual TLS between clouds"
echo "4. Log all cross-cloud access attempts"
