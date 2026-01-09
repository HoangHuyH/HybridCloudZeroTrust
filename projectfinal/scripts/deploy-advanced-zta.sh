#!/bin/bash
# Deploy tất cả các thành phần Zero Trust bổ sung
# OPA, SPIRE, và hướng dẫn Federation

set -e

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║     DEPLOY ZERO TRUST ADVANCED COMPONENTS                         ║"
echo "║     OPA + SPIRE + Federation                                      ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_DIR="/home/deployer/ZTAproject/projectfinal"

# ============================================
# PHẦN 1: DEPLOY OPA POLICY ENGINE
# ============================================
echo "=== PHẦN 1: Deploying OPA Policy Engine ==="
echo ""

# Apply OPA deployment
kubectl apply -f $PROJECT_DIR/policies/opa/opa-deployment.yaml

# Wait for OPA to be ready
echo "Waiting for OPA pods..."
kubectl wait --for=condition=ready pod -l app=opa -n opa-system --timeout=120s 2>/dev/null || true

# Verify OPA
echo ""
echo "OPA Status:"
kubectl get pods -n opa-system
echo ""

# Test OPA policy
echo "Testing OPA policy..."
OPA_POD=$(kubectl get pods -n opa-system -l app=opa -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$OPA_POD" ]; then
  # Test allow case
  echo "Test 1: Giảng viên accessing /api/giangvien (should ALLOW):"
  kubectl exec -n opa-system $OPA_POD -- curl -s localhost:8181/v1/data/zta/authz/allow \
    -d '{
      "input": {
        "method": "GET",
        "path": "/api/giangvien",
        "headers": {
          "x-forwarded-user": "gv1",
          "x-forwarded-groups": "giangvien"
        }
      }
    }' | jq .

  echo ""
  echo "Test 2: Sinh viên accessing /api/giangvien (should DENY):"
  kubectl exec -n opa-system $OPA_POD -- curl -s localhost:8181/v1/data/zta/authz/allow \
    -d '{
      "input": {
        "method": "GET",
        "path": "/api/giangvien",
        "headers": {
          "x-forwarded-user": "sv1",
          "x-forwarded-groups": "sinhvien"
        }
      }
    }' | jq .
fi

echo ""
echo "✅ OPA Policy Engine deployed!"
echo "   Access OPA API: http://172.10.0.190:30181"
echo ""

# ============================================
# PHẦN 2: DEPLOY SPIFFE/SPIRE
# ============================================
echo "=== PHẦN 2: Deploying SPIFFE/SPIRE ==="
echo ""

# Apply SPIRE Server
kubectl apply -f $PROJECT_DIR/identity/spire/spire-server.yaml

# Wait for SPIRE Server
echo "Waiting for SPIRE Server..."
sleep 10
kubectl wait --for=condition=ready pod -l app=spire-server -n spire --timeout=180s 2>/dev/null || true

# Apply SPIRE Agent
kubectl apply -f $PROJECT_DIR/identity/spire/spire-agent.yaml

echo ""
echo "SPIRE Status:"
kubectl get pods -n spire
echo ""

# Register workloads (after SPIRE is ready)
echo "Registering workloads with SPIRE..."
sleep 5
bash $PROJECT_DIR/identity/spire/register-workloads.sh 2>/dev/null || echo "SPIRE registration will complete when server is fully ready"

echo ""
echo "✅ SPIFFE/SPIRE deployed!"
echo "   Trust Domain: zta.local"
echo ""

# ============================================
# PHẦN 3: FEDERATION SUMMARY
# ============================================
echo "=== PHẦN 3: Federation Setup Instructions ==="
echo ""

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  AWS IAM FEDERATION                                               ║"
echo "╠═══════════════════════════════════════════════════════════════════╣"
echo "║                                                                   ║"
echo "║  1. Trong Keycloak Admin:                                         ║"
echo "║     - Tạo client 'aws-federation' với config từ:                  ║"
echo "║       $PROJECT_DIR/identity/keycloak/aws-federation-client.json   ║"
echo "║                                                                   ║"
echo "║  2. Deploy AWS resources:                                         ║"
echo "║     cd $PROJECT_DIR/identity/keycloak                             ║"
echo "║     terraform init && terraform apply                             ║"
echo "║                                                                   ║"
echo "║  3. Test federation:                                              ║"
echo "║     # Lấy JWT token từ Keycloak                                   ║"
echo "║     TOKEN=\$(curl -X POST \\                                        ║"
echo "║       \"$KEYCLOAK_URL/realms/zta/protocol/openid-connect/token\" \\ ║"
echo "║       -d \"client_id=aws-federation\" \\                            ║"
echo "║       -d \"username=gv1&password=gv1\" \\                           ║"
echo "║       -d \"grant_type=password\" | jq -r .access_token)            ║"
echo "║                                                                   ║"
echo "║     # Assume AWS Role với token                                   ║"
echo "║     aws sts assume-role-with-web-identity \\                       ║"
echo "║       --role-arn arn:aws:iam::XXX:role/ZTA-GiangVien-Role \\       ║"
echo "║       --role-session-name keycloak-session \\                      ║"
echo "║       --web-identity-token \$TOKEN                                 ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  OPENSTACK KEYSTONE FEDERATION                                    ║"
echo "╠═══════════════════════════════════════════════════════════════════╣"
echo "║                                                                   ║"
echo "║  Chi tiết xem:                                                    ║"
echo "║  $PROJECT_DIR/identity/keycloak/keystone-federation-setup.sh      ║"
echo "║                                                                   ║"
echo "║  Tóm tắt:                                                         ║"
echo "║  1. Cài mod_auth_openidc cho Apache                               ║"
echo "║  2. Cấu hình Keystone với OIDC plugin                             ║"
echo "║  3. Tạo Identity Provider pointing to Keycloak                    ║"
echo "║  4. Tạo mapping rules để map Keycloak groups → Keystone groups    ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# PHẦN 4: VERIFICATION
# ============================================
echo "=== VERIFICATION ==="
echo ""

echo "1. OPA Policy Engine:"
kubectl get pods -n opa-system 2>/dev/null || echo "   Not deployed yet"
echo ""

echo "2. SPIFFE/SPIRE:"
kubectl get pods -n spire 2>/dev/null || echo "   Not deployed yet"
echo ""

echo "3. Existing ZTA Components:"
echo "   - Keycloak: http://keycloak.172.10.0.190.nip.io:31691"
echo "   - Demo App: http://app.172.10.0.190.nip.io:31691"
echo "   - Grafana:  http://172.10.0.190:30030"
echo "   - TKB (AWS): http://10.200.0.1:30080"
echo ""

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    DEPLOYMENT COMPLETE!                           ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
