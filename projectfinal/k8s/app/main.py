from fastapi import FastAPI, Header, Response, Request
from fastapi.responses import HTMLResponse
import os

app = FastAPI()

AWS_URL = os.getenv("AWS_URL", "http://10.10.1.10:8080/")

# ═══════════════════════════════════════════════════════════════════════════
# TRANG CHỦ - Giao diện web đẹp để demo cho thầy
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    # Lấy headers - oauth2-proxy dùng x-forwarded-*
    headers = dict(request.headers)
    username = headers.get("x-forwarded-preferred-username") or headers.get("x-forwarded-user")
    email = headers.get("x-forwarded-email")
    groups = headers.get("x-forwarded-groups") or ""
    
    # Xác định role từ groups header
    is_giangvien = "giangvien" in groups.lower() if groups else False
    is_sinhvien = "sinhvien" in groups.lower() if groups else False
    role_display = "Giảng viên 👨‍🏫" if is_giangvien else ("Sinh viên 👨‍🎓" if is_sinhvien else "Khách")
    role_color = "#28a745" if is_giangvien else ("#007bff" if is_sinhvien else "#6c757d")
    
    html_content = f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Zero Trust Demo - UIT</title>
        <link href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css" rel="stylesheet">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
        <style>
            body {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; }}
            .hero {{ background: transparent; }}
            .box {{ border-radius: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); }}
            .card {{ border-radius: 15px; transition: transform 0.3s; }}
            .card:hover {{ transform: translateY(-5px); }}
            .tag {{ font-size: 1rem; }}
            .user-info {{ background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; border-radius: 10px; padding: 20px; }}
            .api-card {{ cursor: pointer; }}
            .result-box {{ background: #1a1a2e; color: #0f0; font-family: monospace; border-radius: 10px; padding: 15px; min-height: 100px; }}
            .denied {{ color: #ff4757; }}
            .allowed {{ color: #2ed573; }}
        </style>
    </head>
    <body>
        <section class="hero is-fullheight">
            <div class="hero-body">
                <div class="container">
                    <div class="columns is-centered">
                        <div class="column is-10">
                            <!-- Header -->
                            <div class="box has-text-centered mb-5">
                                <h1 class="title is-2">
                                    <i class="fas fa-shield-alt"></i> Zero Trust Architecture Demo
                                </h1>
                                <p class="subtitle">Đề tài: Triển khai ZTA trên Hybrid Cloud (OpenStack + AWS)</p>
                                <p><strong>Capstone Project - UIT</strong></p>
                            </div>
                            
                            <!-- User Info -->
                            <div class="user-info mb-5">
                                <div class="columns is-vcentered">
                                    <div class="column">
                                        <p class="is-size-5">
                                            <i class="fas fa-user-circle fa-2x"></i>
                                            <strong style="margin-left: 10px;">Xin chào, {username or 'Khách'}!</strong>
                                        </p>
                                        <p><i class="fas fa-envelope"></i> Email: {email or 'N/A'}</p>
                                    </div>
                                    <div class="column has-text-right">
                                        <span class="tag is-large" style="background: {role_color}; color: white;">
                                            {role_display}
                                        </span>
                                    </div>
                                </div>
                            </div>
                            
                            <!-- API Endpoints -->
                            <div class="columns">
                                <!-- Public Endpoint -->
                                <div class="column">
                                    <div class="card api-card" onclick="callApi('/api/sinhvien', 'result1')">
                                        <div class="card-content has-text-centered">
                                            <span class="icon is-large has-text-success">
                                                <i class="fas fa-unlock fa-3x"></i>
                                            </span>
                                            <p class="title is-4 mt-3">/api/sinhvien</p>
                                            <span class="tag is-success is-light">PUBLIC - Ai cũng vào được</span>
                                        </div>
                                    </div>
                                    <div class="result-box mt-3" id="result1">Kết quả sẽ hiện ở đây...</div>
                                </div>
                                
                                <!-- Protected Endpoint -->
                                <div class="column">
                                    <div class="card api-card" onclick="callApi('/api/giangvien', 'result2')">
                                        <div class="card-content has-text-centered">
                                            <span class="icon is-large has-text-danger">
                                                <i class="fas fa-lock fa-3x"></i>
                                            </span>
                                            <p class="title is-4 mt-3">/api/giangvien</p>
                                            <span class="tag is-danger is-light">PROTECTED - Chỉ Giảng viên</span>
                                        </div>
                                    </div>
                                    <div class="result-box mt-3" id="result2">Kết quả sẽ hiện ở đây...</div>
                                </div>
                                
                                <!-- AWS Endpoint -->
                                <div class="column">
                                    <div class="card api-card" onclick="callApi('/api/aws', 'result3')">
                                        <div class="card-content has-text-centered">
                                            <span class="icon is-large has-text-warning">
                                                <i class="fab fa-aws fa-3x"></i>
                                            </span>
                                            <p class="title is-4 mt-3">/api/aws</p>
                                            <span class="tag is-warning is-light">Hybrid Cloud - AWS</span>
                                        </div>
                                    </div>
                                    <div class="result-box mt-3" id="result3">Kết quả sẽ hiện ở đây...</div>
                                </div>
                            </div>
                            
                            <!-- Zero Trust Principles -->
                            <div class="box mt-5">
                                <h2 class="title is-4"><i class="fas fa-check-circle has-text-success"></i> Zero Trust Principles Applied</h2>
                                <div class="columns">
                                    <div class="column">
                                        <p><i class="fas fa-fingerprint"></i> <strong>Identity-First:</strong> Keycloak OIDC</p>
                                        <p><i class="fas fa-network-wired"></i> <strong>Micro-segmentation:</strong> Istio mTLS</p>
                                    </div>
                                    <div class="column">
                                        <p><i class="fas fa-user-shield"></i> <strong>RBAC:</strong> Role-based Access Control</p>
                                        <p><i class="fas fa-cloud"></i> <strong>Hybrid Cloud:</strong> OpenStack + AWS</p>
                                    </div>
                                </div>
                            </div>
                            
                            <!-- Logout -->
                            <div class="has-text-centered mt-4">
                                <a href="/oauth2/sign_out" class="button is-danger is-outlined">
                                    <i class="fas fa-sign-out-alt"></i>&nbsp; Đăng xuất
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
        
        <script>
            async function callApi(endpoint, resultId) {{
                const resultBox = document.getElementById(resultId);
                resultBox.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Đang gọi API...';
                
                try {{
                    const response = await fetch(endpoint);
                    const data = await response.json();
                    
                    if (response.status === 403) {{
                        resultBox.innerHTML = '<span class="denied"><i class="fas fa-ban"></i> 403 FORBIDDEN - ' + data.error + '</span>';
                    }} else {{
                        resultBox.innerHTML = '<span class="allowed"><i class="fas fa-check-circle"></i> ' + JSON.stringify(data, null, 2) + '</span>';
                    }}
                }} catch (err) {{
                    resultBox.innerHTML = '<span class="denied"><i class="fas fa-exclamation-triangle"></i> Error: ' + err.message + '</span>';
                }}
            }}
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


# ═══════════════════════════════════════════════════════════════════════════
# API SINH VIÊN - PUBLIC (Ai cũng vào được nếu đã đăng nhập)
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/api/sinhvien")
def api_sinhvien(request: Request):
    headers = dict(request.headers)
    username = headers.get("x-forwarded-preferred-username") or headers.get("x-forwarded-user")
    email = headers.get("x-forwarded-email")
    return {
        "status": "success",
        "message": "Xin chào SINH VIÊN - Đây là dữ liệu PUBLIC",
        "user": username,
        "email": email,
        "access_level": "public"
    }


# ═══════════════════════════════════════════════════════════════════════════
# API GIẢNG VIÊN - PROTECTED (Chỉ role giangvien mới vào được)
# Đây là phần quan trọng để demo Zero Trust RBAC
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/api/giangvien")
def api_giangvien(request: Request):
    # Lấy headers trực tiếp từ request
    headers = dict(request.headers)
    
    # oauth2-proxy có thể dùng x-auth-request-* hoặc x-forwarded-*
    username = headers.get("x-forwarded-preferred-username") or headers.get("x-auth-request-preferred-username") or headers.get("x-forwarded-user")
    email = headers.get("x-forwarded-email") or headers.get("x-auth-request-email")
    groups = headers.get("x-forwarded-groups") or headers.get("x-auth-request-groups")
    
    # Log để debug
    print(f"[RBAC CHECK] User: {username}, Email: {email}, Groups: {groups}")
    
    # Kiểm tra role giangvien trong groups header
    if groups:
        # Groups có thể là dạng: "giangvien" hoặc "giangvien,sinhvien"
        user_roles = [r.strip().lower() for r in groups.split(",")]
        if "giangvien" in user_roles:
            return {
                "status": "success",
                "message": "Xin chào GIẢNG VIÊN - Đây là dữ liệu MẬT",
                "user": username,
                "email": email,
                "access_level": "protected",
                "roles": user_roles
            }
    
    # CHẶN TRUY CẬP - Không có role giangvien
    import json
    debug_info = {
        "status": "denied",
        "error": "RBAC: Access Denied - Bạn không có quyền truy cập. Chỉ Giảng viên mới được phép!",
        "debug_user": username,
        "debug_groups": groups
    }
    return Response(
        content=json.dumps(debug_info, ensure_ascii=False),
        status_code=403,
        media_type="application/json"
    )


# ═══════════════════════════════════════════════════════════════════════════
# API AWS - Hybrid Cloud Demo (Gọi sang AWS/External Service)
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/api/aws")
def api_aws(
    username: str = Header(None, alias="x-auth-request-preferred-username")
):
    try:
        import requests
        r = requests.get(AWS_URL, timeout=5)
        return {
            "status": "success",
            "message": "Kết nối Hybrid Cloud thành công!",
            "aws_url": AWS_URL,
            "aws_status_code": r.status_code,
            "user": username
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Không thể kết nối tới AWS/External: {str(e)}",
            "aws_url": AWS_URL,
            "user": username
        }


# ═══════════════════════════════════════════════════════════════════════════
# HEALTH CHECK - Cho Kubernetes probe
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/health")
def health():
    return {"status": "healthy"}