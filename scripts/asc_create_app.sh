#!/usr/bin/env bash
# Create the SleepWindow app in App Store Connect via the App Store Connect API.
#
# Requires:
#   - ASC_KEY_ID        e.g. 48ZWN983JL (the key ID — matches AuthKey_<ID>.p8)
#   - ASC_ISSUER_ID     UUID, looks like 57246542-96fe-1a63-e053-0824d011072a
#   - ASC_KEY_PATH      path to the .p8 file (default: ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8)
#   - ASC_TEAM_ID       your 10-char Apple Developer Team ID (e.g. ABC1234567)
#
# Does:
#   1. Mints a JWT signed with ES256 using the .p8 key
#   2. Looks up the bundle ID (creates it if missing)
#   3. Creates the app record with name "SleepWindow" and primary locale en-US
#
# NOTE: You'll still have to fill in screenshots, description, review notes,
# age rating answers, and the IAP in the ASC web UI — those fields aren't
# all supported by the API or need media uploads.
set -euo pipefail

: "${ASC_KEY_ID:?set ASC_KEY_ID (10-char key id, e.g. 48ZWN983JL)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (UUID from https://appstoreconnect.apple.com/access/integrations/api)}"
: "${ASC_TEAM_ID:?set ASC_TEAM_ID (10-char Apple Developer Team ID)}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

BUNDLE_ID="com.sleepwindow.app"
APP_NAME="SleepWindow"
PRIMARY_LOCALE="en-US"
SKU="SLEEPWINDOW001"

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "private key not found at $ASC_KEY_PATH" >&2
  exit 1
fi

# Mint JWT with Python — avoids a bash JWT lib dependency.
JWT=$(python3 - <<PY
import jwt, time, sys
with open("${ASC_KEY_PATH}", "rb") as f:
    key = f.read()
token = jwt.encode(
    {
        "iss": "${ASC_ISSUER_ID}",
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    },
    key,
    algorithm="ES256",
    headers={"kid": "${ASC_KEY_ID}", "typ": "JWT"},
)
print(token)
PY
)

AUTH=( -H "Authorization: Bearer ${JWT}" -H "Content-Type: application/json" )

echo "==> Looking up bundle ID ${BUNDLE_ID}"
BUNDLE_RESP=$(curl -sSf -g "https://api.appstoreconnect.apple.com/v1/bundleIds?filter%5Bidentifier%5D=${BUNDLE_ID}" "${AUTH[@]}")
BUNDLE_RELID=$(echo "$BUNDLE_RESP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["data"][0]["id"] if d.get("data") else "")')

if [[ -z "$BUNDLE_RELID" ]]; then
  echo "==> Creating bundle ID ${BUNDLE_ID}"
  BUNDLE_RELID=$(curl -sSf -X POST "https://api.appstoreconnect.apple.com/v1/bundleIds" "${AUTH[@]}" \
    -d "{\"data\":{\"type\":\"bundleIds\",\"attributes\":{\"identifier\":\"${BUNDLE_ID}\",\"name\":\"SleepWindow\",\"platform\":\"IOS\"}}}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
else
  echo "==> Bundle ID already exists: ${BUNDLE_RELID}"
fi

echo "==> Creating app record"
APP_RESP=$(curl -sS -X POST "https://api.appstoreconnect.apple.com/v1/apps" "${AUTH[@]}" \
  -d "{
    \"data\": {
      \"type\": \"apps\",
      \"attributes\": {
        \"name\": \"${APP_NAME}\",
        \"primaryLocale\": \"${PRIMARY_LOCALE}\",
        \"sku\": \"${SKU}\",
        \"bundleId\": \"${BUNDLE_ID}\"
      },
      \"relationships\": {
        \"bundleId\": {\"data\": {\"type\": \"bundleIds\", \"id\": \"${BUNDLE_RELID}\"}}
      }
    }
  }")
echo "$APP_RESP" | python3 -m json.tool

APP_ID=$(echo "$APP_RESP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("data",{}).get("id",""))')
if [[ -n "$APP_ID" ]]; then
  echo "==> App created. appleId=${APP_ID}"
  echo "==> Open https://appstoreconnect.apple.com/apps/${APP_ID} to continue setup."
fi
