#!/bin/bash
# deploy-all.sh - Complete ZTA Project Deployment
# Zero Trust Architecture Capstone Project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "  Zero Trust Architecture Deployment"
echo "  Complete Project Setup"
echo "========================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "docker not found"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "All prerequisites met"
}

# Deploy Istio (if not exists)
deploy_istio() {
    log_step "Checking Istio installation..."
    
    if kubectl get namespace istio-system &> /dev/null; then
        log_info "Istio already installed"
    else
        log_warn "Istio not found. Please install Istio first:"
        echo "  curl -L https://istio.io/downloadIstio | sh -"
        echo "  cd istio-*"
        echo "  export PATH=\$PWD/bin:\$PATH"
        echo "  istioctl install --set profile=demo -y"
        exit 1
    fi
}

# Deploy demo namespace with Istio injection
deploy_namespace() {
    log_step "Creating demo namespace with Istio injection..."
    
    kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace demo istio-injection=enabled --overwrite
}

# Deploy Keycloak
deploy_keycloak() {
    log_step "Deploying Keycloak..."
    
    kubectl apply -f "$PROJECT_DIR/k8s/keycloak/keycloak.yaml" -n demo || true
    
    log_info "Waiting for Keycloak to be ready..."
    kubectl wait --for=condition=ready pod -l app=keycloak -n demo --timeout=180s || true
}

# Deploy OAuth2 Proxy
deploy_oauth2_proxy() {
    log_step "Deploying OAuth2 Proxy..."
    
    kubectl apply -f "$PROJECT_DIR/k8s/app/oauth2-proxy.yaml" -n demo || true
    
    log_info "Waiting for OAuth2 Proxy to be ready..."
    kubectl wait --for=condition=ready pod -l app=oauth2-proxy -n demo --timeout=120s || true
}

# Deploy Demo App
deploy_demo_app() {
    log_step "Deploying Demo Application..."
    
    kubectl apply -f "$PROJECT_DIR/k8s/app/deployment.yaml" -n demo || true
    kubectl apply -f "$PROJECT_DIR/k8s/app/service.yaml" -n demo || true
    
    log_info "Waiting for Demo App to be ready..."
    kubectl wait --for=condition=ready pod -l app=demo-app -n demo --timeout=120s || true
}

# Deploy Istio Gateway and VirtualServices
deploy_istio_config() {
    log_step "Deploying Istio Gateway and VirtualServices..."
    
    kubectl apply -f "$PROJECT_DIR/k8s/istio/gateway.yaml" -n demo || true
    kubectl apply -f "$PROJECT_DIR/k8s/istio/virtual-service.yaml" -n demo || true
}

# Deploy mTLS policies
deploy_mtls() {
    log_step "Deploying mTLS strict mode..."
    
    kubectl apply -f "$PROJECT_DIR/policies/mtls-strict.yaml" || true
}

# Deploy OPA
deploy_opa() {
    log_step "Deploying OPA..."
    
    kubectl apply -f "$PROJECT_DIR/policies/opa/opa-deployment.yaml" || true
    
    log_info "Waiting for OPA to be ready..."
    kubectl wait --for=condition=ready pod -l app=opa -n opa-system --timeout=120s || true
}

# Deploy Monitoring
deploy_monitoring() {
    log_step "Deploying Monitoring Stack..."
    
    bash "$SCRIPT_DIR/deploy-monitoring.sh" || true
}

# Show status
show_status() {
    echo ""
    echo "========================================"
    echo "  Deployment Status"
    echo "========================================"
    
    # Get node IP
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null || echo "31691")
    
    echo ""
    log_info "All pods:"
    kubectl get pods -n demo
    
    echo ""
    log_info "Services:"
    kubectl get svc -n demo
    
    echo ""
    log_info "Monitoring pods:"
    kubectl get pods -n monitoring 2>/dev/null || log_warn "Monitoring not deployed"
    
    echo ""
    echo "========================================"
    echo "  Access URLs"
    echo "========================================"
    echo ""
    echo "  Demo Application:"
    echo "    http://app.${NODE_IP}.nip.io:${NODE_PORT}"
    echo ""
    echo "  Keycloak Admin Console:"
    echo "    http://keycloak.${NODE_IP}.nip.io:${NODE_PORT}"
    echo "    Username: admin"
    echo "    Password: admin"
    echo ""
    echo "  Prometheus:"
    echo "    http://${NODE_IP}:30090"
    echo ""
    echo "  Grafana:"
    echo "    http://${NODE_IP}:30030"
    echo "    Username: admin"
    echo "    Password: admin123"
    echo ""
    echo "========================================"
    echo "  Test Users"
    echo "========================================"
    echo ""
    echo "  Giảng viên:"
    echo "    Username: gv1"
    echo "    Password: gv1"
    echo "    Role: giangvien"
    echo "    Access: /api/giangvien ✓, /api/sinhvien ✓ (read-only)"
    echo ""
    echo "  Sinh viên:"
    echo "    Username: sv1"
    echo "    Password: sv1"
    echo "    Role: sinhvien"
    echo "    Access: /api/sinhvien ✓, /api/giangvien ✗"
    echo ""
}

# Main
main() {
    check_prerequisites
    deploy_istio
    deploy_namespace
    deploy_keycloak
    deploy_oauth2_proxy
    deploy_demo_app
    deploy_istio_config
    
    read -p "Deploy mTLS strict mode? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_mtls
    fi
    
    read -p "Deploy OPA policy engine? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_opa
    fi
    
    read -p "Deploy Monitoring Stack? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_monitoring
    fi
    
    show_status
}

main "$@"
