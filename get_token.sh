#!/bin/bash

# -------------------------------
# Keycloak Config
# -------------------------------
KEYCLOAK_HOST="http://192.168.180.203:8180/auth"
REALM="apacsvna"
CLIENT_ID="dcm4chee-arc-ui"
USERNAME="admin"
PASSWORD="changeit"
CLIENT_SECRET=""  # leave empty if public client

# -------------------------------
# Token Endpoint
# -------------------------------
TOKEN_URL="$KEYCLOAK_HOST/realms/$REALM/protocol/openid-connect/token"

# -------------------------------
# Fetch the token
# -------------------------------
RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  ${CLIENT_SECRET:+-d "client_secret=$CLIENT_SECRET"})

# -------------------------------
# Save response and extract token
# -------------------------------
echo "$RESPONSE" > /tmp/token_response.json
TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

# -------------------------------
# Print or return token
# -------------------------------
if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
  echo "❌ Failed to fetch token"
  exit 1
else
  echo "$TOKEN"
fi

