
# Capstone Project Outline  

## Đề tài 01: Triển khai và đánh giá Zero Trust Architecture trên môi trường Hybrid Cloud (OpenStack + AWS) với micro‑segmentation & identity‑aware proxies

**Mô tắt:**  
Thiết kế, triển khai và đánh giá một kiến trúc Zero Trust (ZTA) cho môi trường hybrid cloud (OpenStack private lab + AWS public cloud). Dự án tập trung vào: identity‑first access (OIDC/SAML, SPIFFE/SPIRE), micro‑segmentation (service‑level segmentation bằng service mesh + security groups / Neutron), identity‑aware proxies (Envoy/Envoy‑based proxies, OIDC gatekeepers), continuous authentication & device posture checks, policy‑as‑code (OPA/Rego), và observability để đo hiệu quả bảo mật (ngăn lateral movement, giảm blast radius).

---

### 1. Đặt vấn đề (Problem Statement)

- Mô hình mạng truyền thống (implicit trust within perimeter) không phù hợp với cloud/hybrid — lateral movement và quyền bị đánh cắp gây hậu quả lớn.  
- Zero Trust Architecture (verify‑explicit, least‑privilege, assume‑breach) yêu cầu chuyển từ network perimeter sang identity + policy driven controls.  
- Mục tiêu: xây dựng ZTA thực tế cho OpenStack + AWS, chứng minh khả năng ngăn chặn tấn công lateral, tự động hóa policy và đánh giá trade‑offs vận hành.

---

### 2. Mục tiêu dự án (Objectives)

- Thiết lập hybrid connectivity (VPN/Direct Connect / Transit) giữa OpenStack và AWS trong lab.  
- Triển khai identity fabric: OIDC IdP (Keycloak) kết nối với Keystone & AWS IAM Federation; thiết lập SPIFFE/SPIRE để phát chứng chỉ ngắn hạn cho workloads.  
- Micro‑segmentation: service mesh (Istio/Linkerd) với Envoy sidecar để thực hiện mTLS và identity‑aware proxying; bổ sung network policies (Neutron security groups / AWS SG / NACLs).  
- Policy engine: OPA/Gatekeeper + Rego để kiểm tra access based on identity, device posture, risk score.  
- Implement conditional access: MFA, device posture (OS, patch level), contextual rules (geo, time).  
- Observability & detection: telemetry (mTLS logs, audit logs, flow logs), SIEM integration, policy violation dashboards.  
- Đánh giá: measure MTTD, blocked lateral attempts, policy enforcement latency, developer/ops friction.

---

### 3. Kiến trúc & Công nghệ đề xuất (Architecture & Tech Stack)

- **Identity:** Keycloak (IdP, OIDC/SAML), Keystone federation, AWS IAM Identity Provider, SCIM for user sync.  
- **Service Identity & Workload Certs:** SPIFFE / SPIRE for workload identity and short‑lived X.509 certs.  
- **Service Mesh / Proxies:** Istio (Envoy) hoặc Linkerd + Envoy sidecars for east‑west, Ambassador/Envoy for north‑south.  
- **Network controls:** OpenStack Neutron security groups, AWS VPC Security Groups & Network ACLs, NSX (optional).  
- **Policy Engine:** OPA (Rego) + Gatekeeper for K8s manifests; OPA as policy decision point via sidecars for services.  
- **Authentication & Access:** OAuth2/OIDC flows, mutual TLS between services, short‑lived AWS STS tokens for cross‑cloud API access.  
- **Device Posture & Endpoint:** Telemetry from endpoint agents (osquery, osqueryd) or SSM to feed posture service.  
- **Observability / SIEM:** Fluent Bit/Filebeat → Kafka → Elasticsearch / Splunk, Jaeger for tracing, Prometheus/Grafana metrics.  
- **Orchestration / IaC:** Kubernetes (EKS / K8s on OpenStack), Terraform + Ansible for infra provisioning.  
- **Secrets & KMS:** AWS KMS / Vault for secrets and key management.  
- **Testing tools:** Caldera / Atomic Red Team (simulations), tcpreplay, packet capture, bastion lab for red team.

High‑level flow: User/Service requests → IdP/OIDC auth (conditional checks) → obtain short‑lived identity (SPIFFE cert / STS token) → network policy & proxy enforce policy (OPA decision) → requests logged & traced.

---

### 4. Threat Model & Use Cases (Attack Scenarios)

- **T1 — Compromised VM credentials / long‑lived keys:** attacker tries to use stolen creds to access other services.  
- **T2 — Lateral movement:** attacker compromises app pod and attempts to reach DB/metadata service.  
- **T3 — Unauthorized cross‑cloud access:** attacker from OpenStack tries to access AWS resource.  
- **T4 — Privilege escalation via misconfigured security group / IAM policy.**  
- **T5 — Insider with valid credentials but non‑compliant device posture.**

For each scenario define expected detection & containment (e.g., mTLS failure, OPA deny, network path blocked).

---

### 5. Lab Setup & Preconditions (OpenStack + AWS)

- **Accounts & network:** OpenStack project (3 tenants) + AWS account (VPC with subnets); create VPN or site‑to‑site tunnel (or use a transit / VPN appliance) for hybrid connectivity.  
- **Kubernetes:** Deploy Kubernetes clusters: one on OpenStack (k8s) and optionally EKS; or run both workloads on a single multi‑cluster testbed.  
- **IdP:** Deploy Keycloak, configure realms/clients for OIDC, add users/groups, enable MFA (OTP).  
- **SPIRE server & agents:** deploy SPIRE Server in control plane and SPIRE agents on hosts / node pools.  
- **Service Mesh:** Install Istio/Linkerd on clusters, enable mutual TLS, and sidecar injection.  
- **Policy infra:** Install OPA/Gatekeeper in cluster; create ConstraintTemplates for identity policies.  
- **Telemetry:** Configure Fluent Bit/Filebeat, Jaeger, Prometheus; route to central SIEM.  
- **Baseline apps:** Deploy sample microservices (frontend, backend, DB) across OpenStack & AWS to simulate cross‑cloud calls.

---

### 6. Identity & Federation Details

- **Keycloak:** configure OIDC clients for apps and configure SAML/OIDC federation with Keystone and AWS via SAML identity providers and AWS IAM SAML provider.  
- **SCIM:** optionally synchronize user/groups from corporate LDAP to Keycloak & Keystone.  
- **STS & SPIFFE:** for cross‑cloud workload-to-workload access, use SPIFFE identity plus short‑lived tokens; map SPIFFE IDs to IAM roles via an identity broker.  
- **Service principals & least privilege:** implement RBAC policies mapping identities → allowed actions/resources.

---

### 7. Micro‑segmentation Strategy

- **East‑West (service level):** enforce mTLS and service‑level authorization via Envoy/Istio Authorizers and OPA sidecar: allow only named SPIFFE identities to reach a service endpoint and only on required ports.  
- **North‑South (ingress/egress):** implement identity‑aware ingress gateway (Ambassador/Envoy) that performs OIDC auth for external users and applies access policies.  
- **Network layer fallback:** security groups / Neutron rules to limit lateral movement for non‑mesh workloads (DB VMs).  
- **Segmentation granularity:** namespace, workload, endpoint, data sensitivity labels.  
- **Segmentation policy lifecycle:** manage via GitOps (policy-as-code), store policies in git, test in CI (conftest/OPA), promote to cluster.

---

### 8. Policy‑as‑Code (OPA/Rego) Examples & Patterns

**Policy types:** access policy (who can call what), runtime posture policy (deny if device not compliant), network policy (deny if non‑mesh call), data access policy (deny wide exports).

**Sample Rego snippet (identity-based allow):**

```rego
package zta.authz
default allow = false

allow {
  input.method == "GET"
  input.path == "/orders"
  endswith(input.caller_spiffe, "frontend")
  input.caller_role == "order-frontend"
  input.device_posture.compliant == true
}
```

Store parameterized policy → Gatekeeper ConstraintTemplate for K8s; for non‑K8s services call OPA REST endpoint from Envoy ext_authz.

---

### 9. Device Posture & Conditional Access

- **Posture service:** aggregate endpoint telemetry (osquery, patch level, AV status), evaluate compliance score.  
- **Conditional rules:** block or require step‑up MFA if posture fails or risk higher (unusual geo, new device).  
- **Implementation:** posture agent reports to posture service; OPA queries posture API during authz decision or IdP enforces conditional access via Keycloak auth flow.

---

### 10. Observability, Audit & SIEM Integration

- **Telemetry to collect:** Istio access logs (mTLS identities), SPIRE logs, Keycloak auth logs, CloudTrail/Keystone, Neutron flow logs, host OS logs, Jaeger traces.  
- **Normalization:** enrich logs with identity attributes, request path, policy decisions and risk scores.  
- **SIEM rules & dashboards:** detection rules for failed mTLS, denied OPA decisions, unusual east‑west flows, sudden token issuance.  
- **Traceability:** correlate a request across clouds via trace id (Jaeger) and identity tags.

---

### 11. Testing & Attack Simulation Plan

- **Baseline tests:** connectivity matrix tests validating allowed/denied paths.  
- **Red team simulations:** use Atomic Red Team/Caldera for scenarios T1–T5; simulate credential theft, pivot attempts.  
- **Automated flow tests:** scripts that attempt calls with wrong identity, expired certs, missing posture.  
- **Chaos tests:** introduce node failure, network partition, and test failover of policy decision points.  
- **Metrics to capture:** number of blocked attempts, MTTD for alerts, policy decision latency (ms), percentage of legitimate requests denied (false positives).

---

### 12. Evaluation & Metrics

**Security metrics:** blocked lateral attempts, reduction in reachable attack surface (measured by allowed graph edges), number of privilege escalation paths eliminated.  
**Operational metrics:** policy evaluation latency, auth latency, system availability, CPU/memory overhead of sidecars.  
**Usability metrics:** false positive rate (FP rate), time-to-fix for blocked deployments, developer friction survey.  
**Compliance metrics:** percentage of services using mTLS, percentage of short‑lived identities, percentage of infra managed by policy‑as‑code.

Provide before/after comparison (without ZTA vs with ZTA) using simulated attack suite to quantify effectiveness.

---

### 13. Implementation Plan & Steps (Suggested)

1. Provision hybrid network & baseline clusters.  
2. Deploy IdP (Keycloak) and configure OIDC clients + federations.  
3. Deploy SPIRE server & agents.  
4. Install service mesh (Istio) with strict mTLS and sidecar injection.  
5. Deploy sample microservices across OpenStack and AWS.  
6. Create OPA policies & Gatekeeper constraints; configure Envoy ext_authz to call OPA.  
7. Configure device posture collection (osquery) and posture service.  
8. Integrate logs to SIEM and implement basic detection rules.  
9. Run attack simulations and collect metrics; iterate on policies.  
10. Harden and document runbooks & automation (Terraform/Ansible + GitOps).

---

### 14. Automation, IaC & CI/CD (DevOps Integration)

- **IaC:** Terraform modules for network, VMs, K8s clusters, Keycloak, SPIRE.  
- **Configuration Automation:** Ansible playbooks for node setup, SPIRE agent installation, posture agent.  
- **Policy GitOps:** policies in git repo; CI pipeline runs `conftest`/`opa test` on PRs; upon merge, apply to cluster via ArgoCD/Flux.  
- **CI tests:** automated integration tests that validate policy enforcement via `kubectl --dry-run=server` and test harness.

---

### 15. Deliverables (nộp cuối)

- Git repo with IaC (Terraform), Ansible scripts, helm charts/manifests for Keycloak/SPIRE/Istio/OPA.  
- Sample microservices & deployment examples across OpenStack & AWS.  
- Policy library (Rego) and Gatekeeper ConstraintTemplates/Constraints.  
- Attack simulation scripts & red team logs.  
- Evaluation artifacts: dashboards, plots, metrics, before/after reports.  
- Runbooks: onboarding, incident response for policy violations, exception workflow.  
- Final report (20–30 trang), presentation, and a demo video (8–12 phút).

---

### 16. Rubric đánh giá (Suggested Grading Rubric)

- **Architecture & design (20%)**: clear ZTA design, hybrid connectivity, identity fabric.  
- **Implementation & automation (25%)**: IaC, deployment of SPIRE/Keycloak/Istio/OPA, GitOps.  
- **Policy & enforcement (20%)**: Rego policies, Gatekeeper, correct enforcement & testing.  
- **Testing & evaluation (20%)**: attack simulations, metrics, quantitative results.  
- **Documentation & deliverables (15%)**: report, runbooks, demo.

---

### 17. Milestones & Timeline (14 tuần đề xuất)

- **Tuần 1–2:** Requirement & design, provision basic OpenStack + AWS testbeds, deploy Keycloak.  
- **Tuần 3–4:** Setup hybrid connectivity, deploy Kubernetes clusters & SPIRE server.  
- **Tuần 5–6:** Install Istio/Envoy with mTLS; deploy sample apps.  
- **Tuần 7–8:** Implement OPA/Gatekeeper policies, integrate ext_authz.  
- **Tuần 9:** Device posture service & posture integration into authz.  
- **Tuần 10:** Observability & SIEM dashboards; baseline metrics.  
- **Tuần 11:** Run attack simulations (red team) & collect results.  
- **Tuần 12:** Iterate policies, reduce FP, tune performance.  
- **Tuần 13:** Final evaluations, runbooks, IaC cleanups.  
- **Tuần 14:** Final reports, demo & presentation.

---

### 18. Testing Scenarios & Validation Cases (Suggested)

- **TC1:** Unauthorized pod from OpenStack cannot access AWS DB endpoint — expect OPA deny & SG drop.  
- **TC2:** Workload with expired SPIFFE cert is denied by Envoy mTLS.  
- **TC3:** Device with failing posture (outdated patch) forced to step‑up MFA, then denied access until compliant.  
- **TC4:** Simulated lateral movement attempts are blocked; measure attempted & blocked flows.  
- **TC5:** Policy change via GitOps validated in CI and applied; observe rollout & audit trail.

---

### 19. Ethical, Legal & Operational Considerations

- All red‑team simulations must run in lab/sandbox and be pre‑approved.  
- Manage credentials and secrets securely (Vault); rotate test keys after exercises.  
- Ensure privacy: sanitize logs before sharing; follow institutional policies for data handling.  
- Avoid blocking legitimate business operations; document exception process and SLA for exceptions.

---
