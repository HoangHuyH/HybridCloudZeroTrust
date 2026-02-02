# 🔐 Zero Trust Architecture on Hybrid Cloud

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![Istio](https://img.shields.io/badge/Service%20Mesh-Istio-466BB0?logo=istio)](https://istio.io/)

> Implementation and evaluation of Zero Trust Architecture on Hybrid Cloud (OpenStack + AWS) with micro-segmentation and identity-aware proxies.

## 📖 Overview

This repository contains the implementation of a Zero Trust Architecture (ZTA) for a hybrid cloud environment combining OpenStack (private cloud) and AWS (public cloud). The project demonstrates identity-first access control, micro-segmentation, and policy-as-code principles to enhance security in modern cloud environments.

### Key Features

- 🔑 **Identity-First Access**: OIDC/OAuth2 authentication via Keycloak
- 🛡️ **Micro-Segmentation**: Service mesh implementation with Istio and mTLS
- 📜 **Policy-as-Code**: Authorization policies using OPA (Open Policy Agent)
- 🌐 **Hybrid Cloud**: Seamless integration between OpenStack and AWS via WireGuard VPN
- 📊 **Observability**: Comprehensive monitoring with Prometheus, Grafana, and Loki

## 🏗️ Architecture

The project implements a Zero Trust Architecture with the following components:

- **Identity Provider**: Keycloak for centralized authentication
- **Service Mesh**: Istio with Envoy sidecars for mTLS and traffic management
- **Policy Engine**: OPA/Rego for fine-grained authorization
- **VPN Connectivity**: WireGuard for secure cross-cloud communication
- **Monitoring Stack**: Prometheus, Grafana, and Loki for observability

## 📂 Repository Structure

```
├── 01_Zero_Trust_Hybrid_Cloud.md    # Project outline and specifications
├── LICENSE                          # MIT License
├── TruongDucHao_HongHuyHoang_ZeroTrust.pdf  # Project documentation
└── projectfinal/                    # Main implementation
    ├── apps/                        # Application source code
    ├── aws/                         # AWS-specific configurations
    ├── docs/                        # Documentation
    ├── identity/                    # Identity management configurations
    ├── infra/                       # Infrastructure as Code
    ├── k8s/                         # Kubernetes manifests
    ├── monitoring/                  # Observability stack
    ├── policies/                    # Security policies
    ├── scripts/                     # Automation scripts
    └── testing/                     # Testing and simulation scripts
```

## 🚀 Getting Started

For detailed implementation instructions, please refer to:
- [`projectfinal/README.md`](projectfinal/README.md) - Complete deployment guide
- [`01_Zero_Trust_Hybrid_Cloud.md`](01_Zero_Trust_Hybrid_Cloud.md) - Project specifications

### Prerequisites

- OpenStack environment (private cloud)
- AWS account (public cloud)
- Basic knowledge of Kubernetes, service mesh, and Zero Trust principles

## 📚 Documentation

- **Project Outline**: [01_Zero_Trust_Hybrid_Cloud.md](01_Zero_Trust_Hybrid_Cloud.md)
- **Implementation Guide**: [projectfinal/README.md](projectfinal/README.md)
- **Full Report**: [TruongDucHao_HongHuyHoang_ZeroTrust.pdf](TruongDucHao_HongHuyHoang_ZeroTrust.pdf)

## 🛠️ Technology Stack

| Category | Technology |
|----------|------------|
| Container Orchestration | K3s (Lightweight Kubernetes) |
| Service Mesh | Istio + Envoy |
| Identity Provider | Keycloak |
| Auth Gateway | OAuth2-Proxy |
| Policy Engine | OPA (Open Policy Agent) |
| VPN | WireGuard |
| Infrastructure | Terraform |
| Monitoring | Prometheus + Grafana + Loki |

## 🎯 Zero Trust Principles

This implementation follows core Zero Trust principles:

- **Never Trust, Always Verify**: All requests are authenticated and authorized
- **Least Privilege Access**: Users and services have minimal required permissions
- **Assume Breach**: Defense in depth with multiple security layers
- **Verify Explicitly**: Every access request is fully authenticated and authorized

## 📊 Use Cases

The implementation addresses several security scenarios:

1. **Lateral Movement Prevention**: Micro-segmentation prevents unauthorized service-to-service communication
2. **Cross-Cloud Access Control**: Policy-based authorization for hybrid cloud resources
3. **Identity-Based Access**: All access decisions based on verified identities
4. **Continuous Verification**: Real-time policy enforcement and monitoring

## 👥 Authors

- Truong Duc Hao
- Hong Huy Hoang

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This is a capstone project demonstrating the implementation of Zero Trust Architecture in a hybrid cloud environment for educational purposes.
