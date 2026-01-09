# Zero Trust Authorization Policy Tests
# Run with: opa test authz.rego authz_test.rego -v

package zta.authz

# Test: giangvien can access /api/giangvien
test_giangvien_access_allowed if {
    allow with input as {
        "user": {
            "name": "gv1",
            "roles": ["giangvien"]
        },
        "request": {
            "path": "/api/giangvien",
            "method": "GET"
        }
    }
}

# Test: sinhvien cannot access /api/giangvien
test_sinhvien_access_denied if {
    not allow with input as {
        "user": {
            "name": "sv1",
            "roles": ["sinhvien"]
        },
        "request": {
            "path": "/api/giangvien",
            "method": "GET"
        }
    }
}

# Test: sinhvien can access /api/sinhvien
test_sinhvien_access_own_endpoint if {
    allow with input as {
        "user": {
            "name": "sv1",
            "roles": ["sinhvien"]
        },
        "request": {
            "path": "/api/sinhvien",
            "method": "GET"
        }
    }
}

# Test: giangvien can view sinhvien endpoint (read-only)
test_giangvien_can_view_sinhvien if {
    allow with input as {
        "user": {
            "name": "gv1",
            "roles": ["giangvien"]
        },
        "request": {
            "path": "/api/sinhvien",
            "method": "GET"
        }
    }
}

# Test: giangvien cannot POST to sinhvien endpoint
test_giangvien_cannot_post_sinhvien if {
    not allow with input as {
        "user": {
            "name": "gv1",
            "roles": ["giangvien"]
        },
        "request": {
            "path": "/api/sinhvien",
            "method": "POST"
        }
    }
}

# Test: unauthenticated user cannot access protected endpoints
test_unauthenticated_denied if {
    not allow with input as {
        "user": {
            "name": null,
            "roles": []
        },
        "request": {
            "path": "/api/giangvien",
            "method": "GET"
        }
    }
}

# Test: public endpoints are accessible
test_public_endpoint_accessible if {
    allow with input as {
        "user": {
            "name": null,
            "roles": []
        },
        "request": {
            "path": "/health",
            "method": "GET"
        }
    }
}

# Test: root path is public
test_root_path_public if {
    allow with input as {
        "user": {
            "name": null,
            "roles": []
        },
        "request": {
            "path": "/",
            "method": "GET"
        }
    }
}

# Test: admin can access all endpoints
test_admin_full_access if {
    allow with input as {
        "user": {
            "name": "admin",
            "roles": ["admin"]
        },
        "request": {
            "path": "/api/giangvien",
            "method": "DELETE"
        }
    }
}

# Test: user with multiple roles gets combined permissions
test_multiple_roles if {
    allow with input as {
        "user": {
            "name": "user1",
            "roles": ["sinhvien", "giangvien"]
        },
        "request": {
            "path": "/api/giangvien",
            "method": "POST"
        }
    }
}

# Test: aws-status endpoint accessible by both roles
test_aws_status_giangvien if {
    allow with input as {
        "user": {
            "name": "gv1",
            "roles": ["giangvien"]
        },
        "request": {
            "path": "/api/aws-status",
            "method": "GET"
        }
    }
}

test_aws_status_sinhvien if {
    allow with input as {
        "user": {
            "name": "sv1",
            "roles": ["sinhvien"]
        },
        "request": {
            "path": "/api/aws-status",
            "method": "GET"
        }
    }
}
