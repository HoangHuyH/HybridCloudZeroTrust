#!/bin/bash
# ============================================================
# ATTACK SIMULATION - RBAC BYPASS TEST
# Zero Trust Architecture - Security Testing
# T1 & T4: Credential Theft & Privilege Escalation
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_URL="http://app.172.10.0.190.nip.io:31691"
KEYCLOAK_URL="http://keycloak.172.10.0.190.nip.io:31691"
LOG_FILE="/tmp/zta-rbac-test-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  ZERO TRUST ATTACK SIMULATION - RBAC BYPASS               ${NC}"
echo -e "${BLUE}  Testing T1 & T4: Credential & Privilege Attacks          ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo ""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

test_result() {
    if [ "$1" == "blocked" ]; then
        echo -e "${GREEN}[PASS]${NC} $2 - Attack was BLOCKED" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[FAIL]${NC} $2 - Attack was ALLOWED" | tee -a "$LOG_FILE"
    fi
}

# ============================================================
# T1.1: Access Protected Endpoint Without Authentication
# ============================================================
echo -e "\n${YELLOW}=== T1.1: Unauthenticated Access Attempt ===${NC}"
log "Testing: Access /api/giangvien without authentication"

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ] || [ "$RESULT" == "401" ] || [ "$RESULT" == "403" ]; then
    test_result "blocked" "Unauthenticated access to /api/giangvien (HTTP $RESULT)"
else
    test_result "allowed" "Returned HTTP $RESULT"
fi

# ============================================================
# T1.2: Access with Invalid Token
# ============================================================
echo -e "\n${YELLOW}=== T1.2: Access with Invalid/Expired Token ===${NC}"
log "Testing: Access with fake JWT token"

FAKE_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJoYWNrZXIiLCJyb2xlIjoiYWRtaW4ifQ.fake"

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    -H "Authorization: Bearer $FAKE_TOKEN" \
    "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ] || [ "$RESULT" == "401" ] || [ "$RESULT" == "403" ]; then
    test_result "blocked" "Invalid JWT token (HTTP $RESULT)"
else
    test_result "allowed" "Returned HTTP $RESULT"
fi

# ============================================================
# T1.3: Header Injection Attack
# ============================================================
echo -e "\n${YELLOW}=== T1.3: Header Injection Attack ===${NC}"
log "Testing: Injecting fake identity headers"

# Try to inject x-forwarded-groups header directly
RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    -H "X-Forwarded-Groups: giangvien" \
    -H "X-Forwarded-User: fake-admin" \
    -H "X-Forwarded-Email: admin@hacker.com" \
    "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ] || [ "$RESULT" == "401" ] || [ "$RESULT" == "403" ]; then
    test_result "blocked" "Header injection attack (HTTP $RESULT)"
else
    test_result "allowed" "Returned HTTP $RESULT - Headers may not be trusted"
fi

# ============================================================
# T4.1: Privilege Escalation - Student accessing Teacher API
# ============================================================
echo -e "\n${YELLOW}=== T4.1: Privilege Escalation Test ===${NC}"
log "Testing: Student (sv1) trying to access /api/giangvien"
log "This test requires manual verification:"
echo ""
echo "  1. Login as sv1/123 at: $APP_URL"
echo "  2. Try to access: $APP_URL/api/giangvien"
echo "  3. Expected: 403 Forbidden"
echo ""

# ============================================================
# T4.2: SQL Injection Attempt (if applicable)
# ============================================================
echo -e "\n${YELLOW}=== T4.2: SQL Injection Attempt ===${NC}"
log "Testing: SQL injection in API parameters"

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    "$APP_URL/api/sinhvien?id=1%27%20OR%20%271%27=%271" 2>/dev/null)

log "SQL injection test returned HTTP $RESULT"

# ============================================================
# T4.3: Path Traversal Attack
# ============================================================
echo -e "\n${YELLOW}=== T4.3: Path Traversal Attack ===${NC}"
log "Testing: Path traversal attempt"

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    "$APP_URL/../../../etc/passwd" 2>/dev/null)

if [ "$RESULT" == "400" ] || [ "$RESULT" == "404" ] || [ "$RESULT" == "403" ]; then
    test_result "blocked" "Path traversal attack (HTTP $RESULT)"
else
    test_result "allowed" "Returned HTTP $RESULT"
fi

# ============================================================
# T4.4: Cookie Manipulation
# ============================================================
echo -e "\n${YELLOW}=== T4.4: Cookie Manipulation Attack ===${NC}"
log "Testing: Fake session cookie"

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    -H "Cookie: _oauth2_proxy=fake_session_value" \
    "$APP_URL/api/giangvien" 2>/dev/null)

if [ "$RESULT" == "302" ] || [ "$RESULT" == "401" ] || [ "$RESULT" == "403" ]; then
    test_result "blocked" "Fake cookie attack (HTTP $RESULT)"
else
    test_result "allowed" "Returned HTTP $RESULT"
fi

# ============================================================
# T1.4: Brute Force Login Attempt
# ============================================================
echo -e "\n${YELLOW}=== T1.4: Brute Force Login Simulation ===${NC}"
log "Testing: Multiple failed login attempts"

echo "Simulating brute force (5 attempts)..."
for i in {1..5}; do
    RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 \
        -X POST \
        -d "username=admin&password=wrong$i" \
        "$KEYCLOAK_URL/realms/zta/protocol/openid-connect/token" 2>/dev/null)
    log "Attempt $i: HTTP $RESULT"
    sleep 1
done
echo "Note: Keycloak should have brute force protection enabled"

# ============================================================
# Summary
# ============================================================
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}  RBAC ATTACK SIMULATION SUMMARY                            ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "Full log saved to: $LOG_FILE"
echo ""
echo "Manual Tests Required:"
echo "1. Login as sv1, try /api/giangvien -> should get 403"
echo "2. Login as gv1, try /api/giangvien -> should get 200"
echo "3. Check Keycloak brute force protection settings"
echo ""
echo "Security Recommendations:"
echo "1. Enable rate limiting in Istio/Envoy"
echo "2. Configure Keycloak brute force detection"
echo "3. Add WAF rules for common attacks"
echo "4. Monitor failed authentication attempts"
