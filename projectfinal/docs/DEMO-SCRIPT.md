# 🎬 KỊCH BẢN DEMO ZERO TRUST HYBRID CLOUD

## 📋 Thông tin Demo

| Thông tin | Giá trị |
|-----------|---------|
| **URL chính** | http://app.172.10.0.190.nip.io:31691 |
| **Keycloak Admin** | http://keycloak.172.10.0.190.nip.io:31691 |
| **Grafana** | http://172.10.0.190:30030 (admin/admin123) |
| **Prometheus** | http://172.10.0.190:30090 |

### Tài khoản test:
| Username | Password | Role | Quyền |
|----------|----------|------|-------|
| gv1 | gv1 | giangvien | Full access |
| sv1 | sv1 | sinhvien | Limited access |

---

## 🎯 PHẦN 1: GIỚI THIỆU KIẾN TRÚC (2-3 phút)

### 1.1 Mở terminal SSH vào server
```bash
ssh -i /etc/kolla/ansible/inventory/mykey1.pem ubuntu@172.10.0.190
```

### 1.2 Hiển thị K3s Cluster (Hybrid Cloud)
```bash
# Hiển thị tất cả nodes
kubectl get nodes -o wide

# Kết quả mong đợi:
# NAME           STATUS   ROLES                  INTERNAL-IP    
# master         Ready    control-plane,master   10.0.1.185     (OpenStack)
# worker         Ready    <none>                 10.0.1.65      (OpenStack)
# aws-worker-1   Ready    <none>                 10.200.0.1     (AWS Singapore)
```

**💡 Điểm nhấn:** *"Đây là cluster K3s chạy trên 2 cloud khác nhau - OpenStack on-premises và AWS Singapore, kết nối qua WireGuard VPN"*

### 1.3 Hiển thị tất cả pods đang chạy
```bash
# Pods trong namespace demo (ứng dụng chính)
kubectl get pods -n demo -o wide

# Pods trong namespace microservices (TKB trên AWS)
kubectl get pods -n microservices -o wide

# Pods monitoring
kubectl get pods -n monitoring
```

### 1.4 Kiểm tra VPN connectivity
```bash
# Ping từ OpenStack sang AWS qua WireGuard
ping -c 3 10.200.0.1

# Kết quả mong đợi: ~40-50ms latency (Singapore)
```

**💡 Điểm nhấn:** *"Traffic giữa 2 cloud được mã hóa bằng WireGuard VPN với thuật toán ChaCha20-Poly1305"*

---

## 🔐 PHẦN 2: DEMO ZERO TRUST - AUTHENTICATION (5-7 phút)

### 2.1 Truy cập không đăng nhập (Never Trust)

**Mở browser, truy cập:**
```
http://app.172.10.0.190.nip.io:31691/
```

**Kết quả mong đợi:** 
- ❌ Tự động redirect sang Keycloak login page
- URL chuyển thành: `keycloak.172.10.0.190.nip.io:31691/realms/zta/...`

**💡 Điểm nhấn:** *"Theo nguyên tắc Zero Trust - Never Trust, Always Verify - mọi request đều phải xác thực, không có ngoại lệ"*

### 2.2 Đăng nhập với tài khoản Sinh viên

1. Nhập credentials:
   - Username: `sv1`
   - Password: `sv1`
   
2. Click **Sign In**

3. **Kết quả:** Redirect về trang chủ Demo App

**💡 Điểm nhấn:** *"OAuth2-Proxy đã xác thực với Keycloak và set các header x-forwarded-user, x-forwarded-groups"*

### 2.3 Xem thông tin user
```
http://app.172.10.0.190.nip.io:31691/api/me
```

**Kết quả mong đợi:**
```json
{
  "user": "sv1",
  "email": "sv1@zta.local",
  "groups": ["sinhvien"],
  "message": "Xin chào sv1!"
}
```

---

## 🚫 PHẦN 3: DEMO RBAC - LEAST PRIVILEGE (5-7 phút)

### 3.1 Sinh viên truy cập API sinh viên ✅
```
http://app.172.10.0.190.nip.io:31691/api/sinhvien
```

**Kết quả:** ✅ 200 OK - Truy cập thành công

### 3.2 Sinh viên truy cập API giảng viên ❌
```
http://app.172.10.0.190.nip.io:31691/api/giangvien
```

**Kết quả:** ❌ 403 Forbidden
```json
{
  "error": "Access denied",
  "message": "Chỉ giảng viên mới có quyền truy cập!",
  "your_groups": ["sinhvien"],
  "required_group": "giangvien"
}
```

**💡 Điểm nhấn:** *"Đây là nguyên tắc Least Privilege - người dùng chỉ có quyền truy cập tài nguyên cần thiết cho công việc của họ"*

### 3.3 Logout và đăng nhập Giảng viên

1. **Logout:** Click nút Logout hoặc clear cookies
2. **Đăng nhập lại:**
   - Username: `gv1`
   - Password: `gv1`

### 3.4 Giảng viên truy cập API giảng viên ✅
```
http://app.172.10.0.190.nip.io:31691/api/giangvien
```

**Kết quả:** ✅ 200 OK
```json
{
  "message": "Chào mừng giảng viên!",
  "user": "gv1",
  "role": "giangvien",
  "permissions": ["view_grades", "edit_grades", "manage_courses"]
}
```

---

## 🌏 PHẦN 4: DEMO HYBRID CLOUD MICROSERVICES (5-7 phút)

### 4.1 Truy cập TKB API (Cross-Cloud)
```
http://app.172.10.0.190.nip.io:31691/api/tkb
```

**Kết quả với gv1 (giangvien):**
```json
{
  "role": "giangvien",
  "schedule": {
    "monday": {"subject": "Lập trình Python", "room": "A101", "class": "CNTT01"},
    "wednesday": {"subject": "Cơ sở dữ liệu", "room": "B205", "class": "CNTT02"},
    "friday": {"subject": "An toàn thông tin", "room": "C301", "class": "CNTT03"}
  },
  "location": "AWS Singapore",
  "timestamp": "..."
}
```

**💡 Điểm nhấn:** 
- *"Request này đi từ browser → OpenStack (Demo-App) → WireGuard VPN → AWS Singapore (TKB Service)"*
- *"Đây là microservice thực sự chạy trên AWS, thể hiện tính Hybrid Cloud"*

### 4.2 So sánh TKB giữa 2 role

**Logout, đăng nhập sv1, truy cập /api/tkb:**

**Kết quả với sv1 (sinhvien):**
```json
{
  "role": "sinhvien",
  "schedule": {
    "monday": {"subject": "Lập trình Python", "teacher": "Nguyễn Văn A"},
    "tuesday": {"subject": "Toán cao cấp", "teacher": "Trần Thị B"},
    "thursday": {"subject": "Vật lý đại cương", "teacher": "Lê Văn C"}
  },
  "location": "AWS Singapore",
  "timestamp": "..."
}
```

**💡 Điểm nhấn:** *"Cùng 1 API nhưng trả về data khác nhau tùy vào role - giảng viên thấy lớp họ dạy, sinh viên thấy thầy cô dạy họ"*

### 4.3 Verify TKB chạy trên AWS (Terminal)
```bash
# Kiểm tra pod TKB đang chạy ở đâu
kubectl get pods -n microservices -o wide

# Kết quả: tkb-service-xxx chạy trên NODE: aws-worker-1

# Gọi trực tiếp TKB qua WireGuard
curl -s http://10.200.0.1:30080/health | jq
```

**Kết quả:**
```json
{
  "status": "healthy",
  "service": "tkb-service",
  "version": "1.0.0",
  "location": "AWS Singapore",
  "timestamp": "..."
}
```

---

## 🆕 PHẦN 5: DEMO OPA POLICY ENGINE (5-7 phút)

### 5.1 Giới thiệu OPA
```bash
echo "
╔════════════════════════════════════════════════════════════════╗
║              OPA - OPEN POLICY AGENT                           ║
║              Policy Decision Point (PDP)                       ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  OPA là:                                                       ║
║  • Policy-as-Code Engine                                       ║
║  • Sử dụng ngôn ngữ Rego                                       ║
║  • Tách biệt Authorization logic khỏi Application              ║
║  • Default DENY = Zero Trust principle                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"
```

### 5.2 Kiểm tra OPA đang chạy
```bash
# Xem OPA pod
kubectl get pods -n opa-system -o wide

# Kết quả: opa-xxx Running trên master node
```

### 5.3 Xem Rego Policy
```bash
# Hiển thị policy authz.rego
kubectl get configmap -n opa-system opa-policy -o jsonpath='{.data.authz\.rego}'
```

**💡 Điểm nhấn:** *"Policy được viết bằng Rego - có thể version control, review, audit"*

### 5.4 Demo OPA Authorization Decisions

**Test 1: Giảng viên truy cập /api/giangvien → ALLOW**
```bash
OPA_POD=$(kubectl get pod -n opa-system -l app=opa -o jsonpath='{.items[0].status.podIP}')

curl -s -X POST "http://$OPA_POD:8181/v1/data/zta/authz/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "gv1", "role": "giangvien", "path": "/api/giangvien"}}' | jq

# Kết quả: {"result": true} ✅
```

**Test 2: Sinh viên truy cập /api/giangvien → DENY**
```bash
curl -s -X POST "http://$OPA_POD:8181/v1/data/zta/authz/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "sv1", "role": "sinhvien", "path": "/api/giangvien"}}' | jq

# Kết quả: {"result": false} ❌
```

**Test 3: Sinh viên truy cập /api/sinhvien → ALLOW**
```bash
curl -s -X POST "http://$OPA_POD:8181/v1/data/zta/authz/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "sv1", "role": "sinhvien", "path": "/api/sinhvien"}}' | jq

# Kết quả: {"result": true} ✅
```

**Test 4: Không có identity → DENY (Zero Trust)**
```bash
curl -s -X POST "http://$OPA_POD:8181/v1/data/zta/authz/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "", "role": "", "path": "/api/giangvien"}}' | jq

# Kết quả: {"result": false} ❌
```

**💡 Điểm nhấn:** 
- *"OPA đưa ra quyết định authorization dựa trên policy Rego"*
- *"Default DENY - không có identity = không có quyền truy cập"*
- *"Policy-as-Code: dễ audit, version control, review trước khi deploy"*

---

## 🆕 PHẦN 6: DEMO SPIFFE/SPIRE WORKLOAD IDENTITY (5-7 phút)

### 6.1 Giới thiệu SPIFFE/SPIRE
```bash
echo "
╔════════════════════════════════════════════════════════════════╗
║              SPIFFE/SPIRE - WORKLOAD IDENTITY                  ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  SPIFFE (Secure Production Identity Framework):                ║
║  • Chuẩn định danh cho workloads                               ║
║  • Không dựa vào IP/network (Zero Trust)                       ║
║                                                                ║
║  SPIRE (SPIFFE Runtime Environment):                           ║
║  • Implementation của SPIFFE                                   ║
║  • Cấp short-lived certificates                                ║
║  • Trust Domain: zta.local                                     ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"
```

### 6.2 Kiểm tra SPIRE Server
```bash
# Xem SPIRE Server pod
kubectl get pods -n spire -o wide

# Kết quả: spire-server-xxx Running trên master
```

### 6.3 Xem SPIRE Server Configuration
```bash
# Trust Domain configuration
kubectl get configmap -n spire spire-server-config -o yaml | grep -A5 "server {"
```

**💡 Điểm nhấn:** *"Trust Domain là zta.local, CA TTL là 24h - certificates tự động rotate"*

### 6.4 Xem SPIFFE IDs trong Istio
```bash
# Mỗi pod có SPIFFE ID trong certificate
kubectl exec -n demo deploy/demo-app -c istio-proxy -- \
  curl -s localhost:15000/certs 2>/dev/null | grep -o 'spiffe://[^"]*' | head -5
```

**Kết quả mong đợi:**
```
spiffe://cluster.local/ns/demo/sa/demo-app
```

### 6.5 Demo mTLS với SPIFFE
```bash
# Kiểm tra Istio mTLS mode
kubectl get peerauthentication -A

# Kiểm tra certificate trong pod
kubectl exec -n demo deploy/demo-app -c istio-proxy -- \
  openssl s_client -connect keycloak.demo.svc:8080 -brief 2>/dev/null | head -5
```

**💡 Điểm nhấn:**
- *"Mỗi workload có SPIFFE ID duy nhất"*
- *"Certificates tự động rotate sau 24h"*
- *"Istio sử dụng SPIFFE cho mTLS - identity-based, không IP-based"*

---

## 🛡️ PHẦN 7: DEMO ATTACK SIMULATION (5-7 phút)

### 7.1 Header Injection Attack

**Mở terminal, thử inject header giả:**
```bash
# Attacker cố gắng giả mạo là admin
curl -v -H "x-forwarded-user: admin" \
     -H "x-forwarded-groups: giangvien" \
     "http://app.172.10.0.190.nip.io:31691/api/giangvien"
```

**Kết quả:** ❌ 302 Redirect to Keycloak

**💡 Điểm nhấn:** *"OAuth2-Proxy STRIP tất cả header x-forwarded-* đến từ bên ngoài. Chỉ sau khi xác thực thành công với Keycloak, các header mới được set bởi OAuth2-Proxy - không phải từ user"*

### 7.2 Fake JWT Token Attack
```bash
# Tạo fake JWT token
FAKE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsImdyb3VwcyI6WyJhZG1pbiJdfQ.fake"

curl -v -H "Authorization: Bearer $FAKE_TOKEN" \
     "http://app.172.10.0.190.nip.io:31691/api/giangvien"
```

**Kết quả:** ❌ 302 Redirect to Keycloak

**💡 Điểm nhấn:** *"Token giả không được ký bởi Keycloak nên bị reject. Đây là nguyên tắc Verify Explicitly"*

### 7.3 Unauthorized Access Attempt (Logs)
```bash
# Xem logs của OAuth2-Proxy
kubectl logs -n demo -l app=oauth2-proxy --tail=20 | grep -i "error\|denied\|401\|403"
```

---

## 📊 PHẦN 8: DEMO MONITORING & OBSERVABILITY (5-7 phút)

### 8.1 Mở Grafana Dashboard
```
http://172.10.0.190:30030
```
- Login: `admin` / `admin123`

### 8.2 Xem ZTA Overview Dashboard
- Vào **Dashboards** → **ZTA Overview**
- Hiển thị:
  - Total requests
  - Error rate
  - Response time
  - Requests by endpoint

### 8.3 Xem Security Logs Dashboard
- Vào **Dashboards** → **ZTA Security Logs**
- Hiển thị:
  - Failed authentication attempts
  - 403 Forbidden responses
  - Suspicious activities

### 8.4 Xem Prometheus Metrics
```
http://172.10.0.190:30090
```

**Query examples:**
```promql
# Total HTTP requests
http_requests_total

# Request duration
http_request_duration_seconds_bucket

# Error rate
rate(http_requests_total{status=~"4..|5.."}[5m])
```

### 8.5 Xem Logs trong Loki (qua Grafana)
- Vào Grafana → **Explore** → Chọn **Loki**
- Query:
```logql
{namespace="demo"} |= "403"
```

---

## 🔧 PHẦN 9: DEMO INFRASTRUCTURE AS CODE (3-5 phút)

### 9.1 Hiển thị Terraform cho AWS
```bash
cat /home/deployer/ZTAproject/projectfinal/infra/aws/main.tf
```

**Highlight:**
- VPC, Subnets
- Security Groups (deny by default)
- EC2 instances
- VPC Flow Logs

### 9.2 Hiển thị Kubernetes manifests
```bash
# Demo App deployment
cat /home/deployer/ZTAproject/projectfinal/apps/demo-app-v5/k8s/deployment.yaml

# TKB Service deployment (chạy trên AWS)
cat /home/deployer/ZTAproject/projectfinal/apps/tkb-service/k8s/deployment-nodeport.yaml
```

### 9.3 Hiển thị Istio configuration
```bash
# VirtualService routing
kubectl get virtualservice -n demo -o yaml
```

---

## 🏁 PHẦN 10: TỔNG KẾT (2-3 phút)

### 10.1 Recap các nguyên tắc Zero Trust đã demo:

| Nguyên tắc | Demo |
|------------|------|
| **Never Trust, Always Verify** | Mọi request redirect to Keycloak |
| **Least Privilege** | sv1 bị 403 khi truy cập /api/giangvien |
| **Assume Breach** | Defense in depth: Gateway → OAuth2 → OPA → App |
| **Verify Explicitly** | Header injection bị block, fake JWT reject |
| **Policy-as-Code** | OPA Rego policies, version controlled |
| **Workload Identity** | SPIFFE IDs, short-lived certificates |

### 10.2 Recap Hybrid Cloud:

| Thành phần | Location |
|------------|----------|
| K3s Master, Worker | OpenStack (On-Premises) |
| Demo-App, Keycloak, OAuth2-Proxy | OpenStack |
| OPA Policy Engine, SPIRE Server | OpenStack (Master) |
| TKB Microservice | AWS Singapore |
| WireGuard VPN | Kết nối 2 cloud |

### 10.3 Command tổng kết
```bash
echo "
╔════════════════════════════════════════════════════════════════╗
║           ZERO TRUST HYBRID CLOUD - DEMO COMPLETED!            ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  ✅ Authentication: Keycloak OIDC                              ║
║  ✅ Authorization: OPA Policy Engine (Rego)                   ║
║  ✅ Workload Identity: SPIFFE/SPIRE (Trust Domain: zta.local) ║
║  ✅ Encryption: WireGuard VPN + Istio mTLS                    ║
║  ✅ Hybrid Cloud: OpenStack + AWS Singapore                   ║
║  ✅ Microservices: TKB Service on AWS                         ║
║  ✅ Monitoring: Prometheus + Grafana + Loki                   ║
║  ✅ Attack Prevention: Header injection, Fake JWT blocked     ║
║  ✅ Policy-as-Code: Rego policies (auditable, version control)║
║  ✅ Short-lived Certificates: 24h TTL, auto-rotation          ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"
```

---

## ⏱️ Timeline Tổng quan

| Phần | Nội dung | Thời gian |
|------|----------|-----------|
| 1 | Giới thiệu kiến trúc | 2-3 phút |
| 2 | Demo Authentication | 5-7 phút |
| 3 | Demo RBAC | 5-7 phút |
| 4 | Demo Hybrid Cloud Microservices | 5-7 phút |
| 5 | **Demo OPA Policy Engine** | 5-7 phút |
| 6 | **Demo SPIFFE/SPIRE Workload Identity** | 5-7 phút |
| 7 | Demo Attack Simulation | 5-7 phút |
| 8 | Demo Monitoring | 5-7 phút |
| 9 | Demo IaC | 3-5 phút |
| 10 | Tổng kết | 2-3 phút |
| **Tổng** | | **~45-55 phút** |

---

## 🎤 Tips cho Demo

1. **Mở sẵn các tab browser:**
   - App URL
   - Keycloak Admin
   - Grafana
   - Prometheus

2. **Mở sẵn 2 terminal:**
   - 1 cho SSH vào server
   - 1 cho chạy curl commands

3. **Clear browser cookies** trước khi demo để không bị login tự động

4. **Test thử 1 lần** trước khi quay chính thức

5. **Highlight** các điểm quan trọng bằng cách nói to và rõ ràng

---

## 🚨 Troubleshooting

### Nếu không truy cập được app:
```bash
# Kiểm tra pods
kubectl get pods -n demo

# Restart nếu cần
kubectl rollout restart deployment demo-app -n demo
```

### Nếu TKB không response:
```bash
# Kiểm tra VPN
ping -c 3 10.200.0.1

# Kiểm tra TKB pod
kubectl get pods -n microservices
kubectl logs -n microservices -l app=tkb-service
```

### Nếu Keycloak không load:
```bash
kubectl rollout restart deployment keycloak -n demo
# Đợi 2-3 phút
```
