#!/bin/bash
# deploy-monitoring.sh - Deploy Monitoring Stack (Prometheus + Grafana + Loki)
# Zero Trust Architecture Capstone Project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "  ZTA Monitoring Stack Deployment"
echo "========================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Deploy namespace
log_info "Creating monitoring namespace..."
kubectl apply -f "$PROJECT_DIR/monitoring/namespace.yaml"

# Wait for namespace
sleep 2

# Deploy Prometheus
log_info "Deploying Prometheus..."
kubectl apply -f "$PROJECT_DIR/monitoring/prometheus/prometheus-configmap.yaml"
kubectl apply -f "$PROJECT_DIR/monitoring/prometheus/prometheus-deployment.yaml"

# Deploy Loki
log_info "Deploying Loki..."
kubectl apply -f "$PROJECT_DIR/monitoring/loki/loki-deployment.yaml"
kubectl apply -f "$PROJECT_DIR/monitoring/loki/promtail-deployment.yaml"

# Deploy Grafana
log_info "Deploying Grafana..."
kubectl apply -f "$PROJECT_DIR/monitoring/grafana/grafana-deployment.yaml"

# Wait for pods to be ready
log_info "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=120s || true

# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "========================================"
echo "  Monitoring Stack Deployed!"
echo "========================================"
echo ""
log_info "Access URLs:"
echo "  - Prometheus: http://${NODE_IP}:30090"
echo "  - Grafana:    http://${NODE_IP}:30030"
echo ""
echo "  Grafana Credentials:"
echo "    Username: admin"
echo "    Password: admin123"
echo ""
log_info "Checking pod status..."
kubectl get pods -n monitoring

echo ""
log_info "To view logs, run:"
echo "  kubectl logs -f deployment/prometheus -n monitoring"
echo "  kubectl logs -f deployment/grafana -n monitoring"
echo "  kubectl logs -f deployment/loki -n monitoring"
