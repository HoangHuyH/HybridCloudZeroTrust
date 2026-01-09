#!/bin/bash
# Register workloads with SPIRE for SPIFFE identity
# Each service gets a unique SPIFFE ID

set -e

SPIRE_SERVER_POD=$(kubectl get pods -n spire -l app=spire-server -o jsonpath='{.items[0].metadata.name}')

echo "=== Registering Workloads with SPIRE ==="

# Register Demo-App
echo "Registering demo-app..."
kubectl exec -n spire $SPIRE_SERVER_POD -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://zta.local/ns/demo/sa/demo-app \
  -parentID spiffe://zta.local/ns/spire/sa/spire-agent \
  -selector k8s:ns:demo \
  -selector k8s:sa:demo-app \
  -ttl 3600

# Register Keycloak
echo "Registering keycloak..."
kubectl exec -n spire $SPIRE_SERVER_POD -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://zta.local/ns/demo/sa/keycloak \
  -parentID spiffe://zta.local/ns/spire/sa/spire-agent \
  -selector k8s:ns:demo \
  -selector k8s:sa:keycloak \
  -ttl 3600

# Register OAuth2-Proxy
echo "Registering oauth2-proxy..."
kubectl exec -n spire $SPIRE_SERVER_POD -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://zta.local/ns/demo/sa/oauth2-proxy \
  -parentID spiffe://zta.local/ns/spire/sa/spire-agent \
  -selector k8s:ns:demo \
  -selector k8s:sa:oauth2-proxy \
  -ttl 3600

# Register TKB Service (AWS)
echo "Registering tkb-service..."
kubectl exec -n spire $SPIRE_SERVER_POD -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://zta.local/ns/microservices/sa/tkb-service \
  -parentID spiffe://zta.local/ns/spire/sa/spire-agent \
  -selector k8s:ns:microservices \
  -selector k8s:sa:default \
  -ttl 3600

echo ""
echo "=== Listing all registered entries ==="
kubectl exec -n spire $SPIRE_SERVER_POD -- \
  /opt/spire/bin/spire-server entry show

echo ""
echo "=== SPIRE Workload Registration Complete ==="
echo ""
echo "SPIFFE IDs registered:"
echo "  - spiffe://zta.local/ns/demo/sa/demo-app"
echo "  - spiffe://zta.local/ns/demo/sa/keycloak"
echo "  - spiffe://zta.local/ns/demo/sa/oauth2-proxy"
echo "  - spiffe://zta.local/ns/microservices/sa/tkb-service"
