# Zero Trust Authorization Policy for OPA
# Package: zta.authz
#
# This policy implements Zero Trust principles:
# 1. Never trust, always verify
# 2. Least privilege access
# 3. Assume breach
# 4. Verify explicitly

package zta.authz

import future.keywords.if
import future.keywords.in

default allow := false

# Role-based access control mapping
# Maps roles to allowed API paths and methods
role_permissions := {
    "giangvien": {
        "/api/giangvien": ["GET", "POST", "PUT", "DELETE"],
        "/api/sinhvien": ["GET"],
        "/api/grades": ["GET", "POST", "PUT"],
        "/api/courses": ["GET", "POST", "PUT", "DELETE"],
        "/api/aws-status": ["GET"]
    },
    "sinhvien": {
        "/api/sinhvien": ["GET"],
        "/api/my-grades": ["GET"],
        "/api/courses": ["GET"],
        "/api/aws-status": ["GET"]
    },
    "admin": {
        "/api/*": ["GET", "POST", "PUT", "DELETE"]
    }
}

# Public endpoints accessible without authentication
public_endpoints := {
    "/": ["GET"],
    "/health": ["GET"],
    "/ready": ["GET"],
    "/login": ["GET", "POST"],
    "/oauth2/callback": ["GET"],
    "/static/*": ["GET"]
}

# Allow request if user has required role
allow if {
    # Get user's roles from input
    user_roles := input.user.roles
    
    # Check each role
    some role in user_roles
    
    # Get permissions for this role
    permissions := role_permissions[role]
    
    # Check if the requested path is allowed
    some allowed_path, methods in permissions
    
    # Match path (supports wildcard)
    path_match(input.request.path, allowed_path)
    
    # Check if method is allowed
    input.request.method in methods
}

# Allow public endpoints
allow if {
    some public_path, methods in public_endpoints
    path_match(input.request.path, public_path)
    input.request.method in methods
}

# Path matching with wildcard support
path_match(requested_path, allowed_path) if {
    allowed_path == "/*"
} else if {
    endswith(allowed_path, "/*")
    prefix := trim_suffix(allowed_path, "/*")
    startswith(requested_path, prefix)
} else if {
    requested_path == allowed_path
}

# Additional context checks for Zero Trust
# Time-based access control (example: block after hours)
time_allowed if {
    # Get current hour (0-23)
    hour := time.clock(time.now_ns())[0]
    
    # Allow access between 6 AM and 10 PM
    hour >= 6
    hour < 22
}

# IP-based access control (example: internal network only for sensitive operations)
ip_allowed if {
    # Check if request is from internal network
    internal_networks := ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    some network in internal_networks
    net.cidr_contains(network, input.request.source_ip)
}

# Strict mode: require all conditions
strict_allow if {
    allow
    time_allowed
    # ip_allowed  # Uncomment for stricter control
}

# Audit logging helper
audit_decision := {
    "allowed": allow,
    "user": input.user.name,
    "roles": input.user.roles,
    "path": input.request.path,
    "method": input.request.method,
    "timestamp": time.now_ns()
}

# Helper function to get denied reason
reason := "Access denied: User does not have required role" if {
    not allow
    input.user.roles != null
}

reason := "Access denied: User not authenticated" if {
    not allow
    input.user.roles == null
}

reason := "Access denied: Outside allowed hours" if {
    allow
    not time_allowed
}
