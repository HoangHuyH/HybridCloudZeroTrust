from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse
import httpx
import os

app = FastAPI(title="ZTA Demo App with Microservices", version="5.0")

# TKB service URL (running on AWS via WireGuard)
TKB_SERVICE_URL = os.getenv("TKB_SERVICE_URL", "http://10.200.0.1:30080")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    user = request.headers.get("x-forwarded-user", "anonymous")
    groups = request.headers.get("x-forwarded-groups", "none")
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>ZTA Demo - Microservices</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
            .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            h1 {{ color: #2c3e50; }}
            .user-info {{ background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .api-list {{ background: #e3f2fd; padding: 15px; border-radius: 5px; }}
            .api-list a {{ display: block; padding: 10px; margin: 5px 0; background: #1976d2; color: white; text-decoration: none; border-radius: 5px; }}
            .api-list a:hover {{ background: #1565c0; }}
            .microservice {{ background: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .aws-badge {{ background: #ff9800; color: white; padding: 3px 8px; border-radius: 3px; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔐 Zero Trust Architecture Demo</h1>
            
            <div class="user-info">
                <h3>👤 User Information</h3>
                <p><strong>User:</strong> {user}</p>
                <p><strong>Groups:</strong> {groups}</p>
            </div>
            
            <div class="api-list">
                <h3>📡 API Endpoints (OpenStack)</h3>
                <a href="/api/giangvien">GET /api/giangvien - Giảng viên only</a>
                <a href="/api/sinhvien">GET /api/sinhvien - Sinh viên access</a>
                <a href="/api/me">GET /api/me - User Info</a>
            </div>
            
            <div class="microservice">
                <h3>🌏 Microservices <span class="aws-badge">AWS Singapore</span></h3>
                <p>Service chạy trên AWS Cloud, kết nối qua WireGuard VPN:</p>
                <a href="/api/tkb" style="display: block; padding: 10px; margin: 5px 0; background: #ff9800; color: white; text-decoration: none; border-radius: 5px;">GET /api/tkb - Thời Khóa Biểu (AWS)</a>
            </div>
            
            <div style="margin-top: 20px; padding: 15px; background: #f5f5f5; border-radius: 5px;">
                <h3>🏗️ Architecture</h3>
                <pre>
User → Istio Gateway → OAuth2-Proxy → Keycloak (Auth)
                           ↓
         Demo App (OpenStack) ←→ TKB Service (AWS)
                      WireGuard VPN
                </pre>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html)

@app.get("/api/me")
async def get_me(request: Request):
    return {
        "user": request.headers.get("x-forwarded-user", "anonymous"),
        "email": request.headers.get("x-forwarded-email", ""),
        "groups": request.headers.get("x-forwarded-groups", ""),
        "service": "demo-app",
        "location": "OpenStack On-Premises"
    }

@app.get("/api/giangvien")
async def giangvien_only(request: Request):
    groups = request.headers.get("x-forwarded-groups", "")
    user = request.headers.get("x-forwarded-user", "anonymous")
    
    if "giangvien" not in groups:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. User '{user}' with groups '{groups}' is not a giangvien."
        )
    
    return {
        "message": "Welcome, Giảng Viên!",
        "user": user,
        "role": "giangvien",
        "access": "full",
        "data": {
            "courses": ["Mạng máy tính", "An ninh mạng", "Cloud Computing"],
            "students_count": 150,
            "next_class": "Kubernetes - Lab1 - 09:00"
        },
        "location": "OpenStack"
    }

@app.get("/api/sinhvien")
async def sinhvien_access(request: Request):
    groups = request.headers.get("x-forwarded-groups", "")
    user = request.headers.get("x-forwarded-user", "anonymous")
    
    if "sinhvien" not in groups and "giangvien" not in groups:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. User '{user}' needs sinhvien or giangvien role."
        )
    
    return {
        "message": "Student Portal",
        "user": user,
        "role": "sinhvien" if "sinhvien" in groups else "giangvien",
        "data": {
            "gpa": 3.5,
            "credits": 120,
            "courses": ["Mạng máy tính", "Lập trình Python", "Cơ sở dữ liệu"]
        },
        "location": "OpenStack"
    }

# Proxy to TKB microservice on AWS
@app.get("/api/tkb")
@app.get("/api/tkb/{path:path}")
async def proxy_tkb(request: Request, path: str = ""):
    """Proxy requests to TKB microservice running on AWS"""
    
    # Forward headers from oauth2-proxy
    headers = {
        "x-forwarded-user": request.headers.get("x-forwarded-user", ""),
        "x-forwarded-groups": request.headers.get("x-forwarded-groups", ""),
        "x-forwarded-email": request.headers.get("x-forwarded-email", ""),
    }
    
    target_url = f"{TKB_SERVICE_URL}/api/tkb"
    if path:
        target_url = f"{TKB_SERVICE_URL}/api/tkb/{path}"
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(target_url, headers=headers)
            
            data = response.json()
            # Add proxy info
            data["_proxy"] = {
                "proxied_by": "demo-app (OpenStack)",
                "target_service": "tkb-service (AWS Singapore)",
                "connection": "WireGuard VPN Tunnel"
            }
            return JSONResponse(content=data, status_code=response.status_code)
            
    except httpx.ConnectError as e:
        return JSONResponse(
            status_code=503,
            content={
                "error": "TKB service unavailable",
                "detail": str(e),
                "target": TKB_SERVICE_URL,
                "note": "AWS microservice may be unreachable via WireGuard VPN"
            }
        )
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": "Proxy error", "detail": str(e)}
        )

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "demo-app", "version": "5.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
