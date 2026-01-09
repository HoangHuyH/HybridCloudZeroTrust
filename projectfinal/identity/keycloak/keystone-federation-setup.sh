#!/bin/bash
# Setup Keycloak Federation với OpenStack Keystone
# Cho phép Keycloak users access OpenStack qua OIDC

set -e

echo "=== Keycloak-Keystone Federation Setup ==="

# Variables
KEYCLOAK_URL="http://keycloak.172.10.0.190.nip.io:31691"
KEYSTONE_URL="http://172.10.0.190:5000"  # OpenStack Keystone endpoint
REALM="zta"

# 1. Tạo client trong Keycloak cho Keystone
echo "Step 1: Creating Keystone client in Keycloak..."

cat > /tmp/keystone-client.json << 'EOF'
{
  "clientId": "keystone-oidc",
  "name": "OpenStack Keystone OIDC Client",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "keystone-oidc-secret",
  "redirectUris": [
    "http://172.10.0.190:5000/v3/OS-FEDERATION/identity_providers/keycloak/protocols/oidc/auth",
    "http://172.10.0.190:5000/*"
  ],
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": true,
  "publicClient": false,
  "protocol": "openid-connect",
  "protocolMappers": [
    {
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "openstack-project",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-hardcoded-claim-mapper",
      "config": {
        "claim.value": "zta-project",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "openstack_project",
        "claim.type": "String"
      }
    }
  ]
}
EOF

echo "Client config created at /tmp/keystone-client.json"
echo ""

# 2. Cấu hình Keystone cho OIDC Federation
echo "Step 2: Keystone Federation Configuration"
echo ""
echo "Thêm vào /etc/keystone/keystone.conf:"
cat << 'EOF'
[auth]
methods = password,token,oidc
oidc = keystone.auth.plugins.mapped.Mapped

[federation]
# Trusted dashboard hosts
trusted_dashboard = http://172.10.0.190/dashboard/

[oidc]
# Keycloak as OIDC Identity Provider
remote_id_attribute = HTTP_OIDC_ISS
EOF

echo ""

# 3. Apache config cho mod_auth_openidc
echo "Step 3: Apache OIDC Configuration"
echo ""
echo "Thêm vào /etc/apache2/sites-available/keystone-wsgi-public.conf:"
cat << 'EOF'
# OIDC Configuration for Keycloak
OIDCClaimPrefix "OIDC-"
OIDCResponseType "id_token"
OIDCScope "openid email profile groups"
OIDCProviderMetadataURL http://keycloak.172.10.0.190.nip.io:31691/realms/zta/.well-known/openid-configuration
OIDCClientID keystone-oidc
OIDCClientSecret keystone-oidc-secret
OIDCCryptoPassphrase openstack-keystone-secret
OIDCRedirectURI http://172.10.0.190:5000/v3/OS-FEDERATION/identity_providers/keycloak/protocols/oidc/auth

<Location /v3/OS-FEDERATION/identity_providers/keycloak/protocols/oidc/auth>
  AuthType openid-connect
  Require valid-user
  LogLevel debug
</Location>
EOF

echo ""

# 4. Tạo Identity Provider trong Keystone
echo "Step 4: Keystone Identity Provider Commands"
echo ""
echo "Chạy các lệnh sau trên OpenStack controller:"
cat << 'EOF'
# Tạo Identity Provider
openstack identity provider create keycloak \
  --remote-id http://keycloak.172.10.0.190.nip.io:31691/realms/zta \
  --description "Keycloak OIDC Provider"

# Tạo mapping rules
openstack mapping create keycloak-mapping --rules /tmp/keycloak-mapping.json

# Tạo Federation Protocol
openstack federation protocol create oidc \
  --identity-provider keycloak \
  --mapping keycloak-mapping
EOF

echo ""

# 5. Tạo mapping rules file
echo "Step 5: Creating Mapping Rules..."
cat > /tmp/keycloak-mapping.json << 'EOF'
[
  {
    "local": [
      {
        "user": {
          "name": "{0}",
          "email": "{1}"
        },
        "group": {
          "name": "{2}",
          "domain": {
            "name": "Default"
          }
        }
      }
    ],
    "remote": [
      {
        "type": "OIDC-preferred_username"
      },
      {
        "type": "OIDC-email"
      },
      {
        "type": "OIDC-groups",
        "any_one_of": ["giangvien", "sinhvien"]
      }
    ]
  },
  {
    "local": [
      {
        "group": {
          "name": "zta-admins",
          "domain": {
            "name": "Default"
          }
        }
      }
    ],
    "remote": [
      {
        "type": "OIDC-groups",
        "any_one_of": ["giangvien"]
      }
    ]
  },
  {
    "local": [
      {
        "group": {
          "name": "zta-users",
          "domain": {
            "name": "Default"
          }
        }
      }
    ],
    "remote": [
      {
        "type": "OIDC-groups",
        "any_one_of": ["sinhvien"]
      }
    ]
  }
]
EOF

echo "Mapping rules created at /tmp/keycloak-mapping.json"
echo ""

# 6. Tạo groups trong Keystone
echo "Step 6: Create Keystone Groups"
cat << 'EOF'
# Tạo group cho mapping
openstack group create zta-admins --description "ZTA Administrators (Giảng viên)"
openstack group create zta-users --description "ZTA Users (Sinh viên)"

# Assign roles
openstack role add --group zta-admins --project zta-project admin
openstack role add --group zta-users --project zta-project member
EOF

echo ""
echo "=== Federation Setup Instructions Complete ==="
echo ""
echo "Summary:"
echo "1. Create Keycloak client 'keystone-oidc' using /tmp/keystone-client.json"
echo "2. Configure Keystone with OIDC settings"
echo "3. Configure Apache with mod_auth_openidc"
echo "4. Create Identity Provider, Mapping, and Protocol in Keystone"
echo "5. Create groups and assign roles"
echo ""
echo "Test federation with:"
echo "  export OS_AUTH_TYPE=v3oidcpassword"
echo "  export OS_IDENTITY_PROVIDER=keycloak"
echo "  export OS_PROTOCOL=oidc"
echo "  export OS_USERNAME=gv1"
echo "  export OS_PASSWORD=gv1"
echo "  openstack token issue"
