# 🔐 Zero Trust Architecture on Hybrid Cloud

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![Istio](https://img.shields.io/badge/Service%20Mesh-Istio-466BB0?logo=istio)](https://istio.io/)
[![Keycloak](https://img.shields.io/badge/IdP-Keycloak-00B8E3)](https://www.keycloak.org/)

> Triển khai kiến trúc Zero Trust trên môi trường Hybrid Cloud (OpenStack + AWS) với micro-segmentation và identity-aware proxies.

## 📋 Mục lục

- [Tổng quan](#-tổng-quan)
- [Kiến trúc](#-kiến-trúc)
- [Công nghệ sử dụng](#-công-nghệ-sử-dụng)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Yêu cầu hệ thống](#-yêu-cầu-hệ-thống)
- [Hướng dẫn triển khai](#-hướng-dẫn-triển-khai)
- [Demo](#-demo)
- [Tài liệu](#-tài-liệu)
- [Đóng góp](#-đóng-góp)

---

## 🎯 Tổng quan

### Zero Trust là gì?

Zero Trust là mô hình bảo mật dựa trên nguyên tắc **"Never Trust, Always Verify"** - không tin tưởng bất kỳ ai/gì mặc định, luôn xác thực và ủy quyền cho mọi request.

### Nguyên tắc cốt lõi

| Nguyên tắc | Mô tả | Triển khai trong project |
|------------|-------|-------------------------|
| 🔒 Never Trust | Không tin tưởng mặc định | Keycloak + OAuth2-Proxy |
| 🎯 Least Privilege | Quyền truy cập tối thiểu | OPA/Rego RBAC policies |
| 🛡️ Assume Breach | Giả định đã bị xâm nhập | mTLS + Network Policies |
| ✅ Verify Explicitly | Xác thực rõ ràng mọi request | JWT validation |

### Tính năng chính

- ✅ **Identity-first Access**: Xác thực qua Keycloak (OIDC/OAuth2)
- ✅ **Micro-segmentation**: Service mesh với Istio + mTLS STRICT
- ✅ **Policy-as-Code**: Authorization bằng OPA/Rego
- ✅ **Hybrid Cloud**: OpenStack (Private) + AWS (Public) qua WireGuard VPN
- ✅ **Observability**: Prometheus + Grafana + Loki stack

---

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ZERO TRUST ARCHITECTURE                             │
│                    OpenStack (Private) + AWS (Public)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   INTERNET ──► ISTIO GATEWAY ──► OAUTH2-PROXY ──► KEYCLOAK (IdP)           │
│                      │                │                                     │
│                      │          JWT Validation                              │
│                      ▼                ▼                                     │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                        SERVICE MESH (ISTIO)                          │  │
│   │   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │  │
│   │   │   Istiod    │     │   mTLS      │     │  Network    │           │  │
│   │   │(Control Pln)│     │  STRICT     │     │  Policies   │           │  │
│   │   └─────────────┘     └─────────────┘     └─────────────┘           │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│   ┌────────────────────────────────┼────────────────────────────────────┐  │
│   │          OPENSTACK             │            AWS SINGAPORE           │  │
│   │   ┌───────────────────┐        │     ┌───────────────────┐         │  │
│   │   │  DEMO APP         │   WireGuard  │   TKB SERVICE     │         │  │
│   │   │  (FastAPI)        │◄────VPN────►│   (Node.js)       │         │  │
│   │   │  - /api/giangvien │   Encrypted │   - /api/tkb      │         │  │
│   │   │  - /api/sinhvien  │             │                   │         │  │
│   │   └───────────────────┘             └───────────────────┘         │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                         OBSERVABILITY                                │  │
│   │   ┌──────────┐  ┌─────────┐  ┌──────┐  ┌──────────┐                 │  │
│   │   │Prometheus│  │ Grafana │  │ Loki │  │ Promtail │                 │  │
│   │   │ :30090   │  │ :30030  │  │:3100 │  │          │                 │  │
│   │   └──────────┘  └─────────┘  └──────┘  └──────────┘                 │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HYBRID CLOUD NETWORK                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   OPENSTACK                           AWS SINGAPORE                 │
│   ┌─────────────────────┐            ┌─────────────────────┐       │
│   │ Provider: 172.10.0.0/24          │ VPC: 10.100.0.0/16  │       │
│   │ Tenant: 10.0.1.0/24  │            │                     │       │
│   │                      │            │                     │       │
│   │  K3s Master          │  WireGuard │  K3s Worker (AWS)  │       │
│   │  10.0.1.185          │◄──────────►│  10.200.0.1        │       │
│   │  FIP: 172.10.0.190   │ 10.200.0.0/24 (WireGuard IP)    │       │
│   │                      │            │                     │       │
│   │  K3s Worker          │            │  Public IP:        │       │
│   │  10.0.1.65           │            │  18.143.117.69     │       │
│   └─────────────────────┘            └─────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Công nghệ sử dụng

| Category | Technology | Purpose |
|----------|------------|---------|
| **Container Orchestration** | K3s | Lightweight Kubernetes |
| **Service Mesh** | Istio + Envoy | mTLS, traffic management |
| **Identity Provider** | Keycloak | OIDC/OAuth2 authentication |
| **Auth Gateway** | OAuth2-Proxy | OIDC integration, session management |
| **Policy Engine** | OPA (Rego) | Authorization decisions |
| **VPN** | WireGuard | Cross-cloud encrypted tunnel |
| **Infrastructure** | Terraform | AWS infrastructure as code |
| **Monitoring** | Prometheus + Grafana | Metrics collection & visualization |
| **Logging** | Loki + Promtail | Log aggregation |

---

## 📁 Cấu trúc thư mục

```
.
├── 📄 README.md                    # Tài liệu chính (file này)
├── 📄 REPORT.md                    # Báo cáo đồ án chi tiết
│
├── 📂 apps/                        # Source code ứng dụng
│   ├── demo-app-v5/               # Demo App (FastAPI + RBAC)
│   │   ├── Dockerfile
│   │   └── main.py
│   └── tkb-service/               # TKB Service (Node.js - AWS)
│       ├── Dockerfile
│       ├── package.json
│       ├── src/
│       └── k8s/
│
├── 📂 infra/                       # Infrastructure as Code
│   ├── aws/                       # Terraform cho AWS
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── wireguard/                 # WireGuard VPN config
│       ├── setup-openstack.sh
│       └── add-aws-peer.sh
│
├── 📂 k8s/                         # Kubernetes manifests
│   ├── app/                       # Application deployments
│   │   ├── demo-app.yaml
│   │   ├── oauth2-proxy.yaml
│   │   └── oauth2-proxy-secret.yaml
│   ├── istio/                     # Istio configurations
│   │   ├── zta-gw.yaml           # Gateway
│   │   ├── app-vs.yaml           # VirtualService
│   │   ├── demo-peerauth.yaml    # mTLS STRICT
│   │   └── jwt-authn.yaml        # JWT authentication
│   └── keycloak/                  # Keycloak deployment
│       ├── keycloak.yaml
│       └── zta-realm.json        # Pre-configured realm
│
├── 📂 identity/                    # Identity management
│   ├── keycloak/                  # Keycloak federation configs
│   │   ├── aws-federation.tf
│   │   └── keystone-federation-setup.sh
│   └── spire/                     # SPIFFE/SPIRE (optional)
│       ├── spire-server.yaml
│       └── spire-agent.yaml
│
├── 📂 policies/                    # Security policies
│   ├── mtls-strict.yaml          # mTLS STRICT mode
│   ├── mtls-permissive.yaml      # mTLS PERMISSIVE mode
│   ├── network-policies-fixed.yaml # Network segmentation
│   └── opa/                       # OPA authorization
│       ├── authz.rego            # RBAC policies
│       ├── authz_test.rego       # Policy tests
│       └── opa-deployment.yaml
│
├── 📂 monitoring/                  # Observability stack
│   ├── namespace.yaml
│   ├── prometheus/
│   │   ├── prometheus-configmap.yaml
│   │   └── prometheus-deployment.yaml
│   ├── grafana/
│   │   └── grafana-deployment.yaml
│   ├── loki/
│   │   ├── loki-deployment.yaml
│   │   └── promtail-deployment.yaml
│   └── kube-state-metrics/
│       └── kube-state-metrics.yaml
│
├── 📂 scripts/                     # Automation scripts
│   ├── deploy-all.sh             # Deploy toàn bộ stack
│   ├── deploy-complete.sh        # Deploy từng phần
│   ├── deploy-monitoring.sh      # Deploy monitoring
│   ├── deploy-advanced-zta.sh    # Deploy ZTA components
│   └── build-and-push.sh         # Build & push images
│
├── 📂 testing/                     # Testing & demo
│   ├── hybrid-cloud-demo.sh      # Demo hybrid cloud
│   ├── live-security-demo.sh     # Live security demo
│   └── attack-simulations/       # Attack simulation scripts
│       ├── lateral-movement.sh
│       ├── cross-cloud-access.sh
│       └── rbac-bypass.sh
│
└── 📂 docs/                        # Documentation
    ├── ARCHITECTURE.md           # Chi tiết kiến trúc
    ├── DEMO-SCRIPT.md            # Kịch bản demo
    ├── PRESENTATION.md           # Slides thuyết trình
    └── HYBRID-CLOUD-NETWORK-DIAGRAM.md
```

---

## 💻 Yêu cầu hệ thống

### OpenStack (Private Cloud)
- 2 VMs: K3s Master (4vCPU, 8GB RAM) + Worker (2vCPU, 4GB RAM)
- Ubuntu 22.04 LTS
- Floating IP có thể truy cập từ internet

### AWS (Public Cloud)
- 1 EC2 Instance: t3.small hoặc lớn hơn
- Ubuntu 22.04 LTS
- Public IP với Security Group cho UDP 51820 (WireGuard)

