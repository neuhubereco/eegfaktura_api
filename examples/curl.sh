#!/usr/bin/env bash
# Beispiel-Requests gegen die eegfaktura.at-API.
# Platzhalter in GROSSBUCHSTABEN ersetzen. KEINE echten Credentials committen!
set -euo pipefail

BASE="https://eegfaktura.at"
API_USER="DEIN_API_USER"
API_PASS="DEIN_PASSWORT"
TENANT="DEIN_TENANT"          # i. d. R. der RC-Code, z. B. RC######
EC_ID="DEINE_EC_ID"           # z. B. AT00300000000RC...
METERING_POINT="DEIN_ZAEHLPUNKT"

# macOS-kompatibles Base64 (kein -w0!)
AUTH=$(printf '%s' "${API_USER}:${API_PASS}" | base64 | tr -d '\n')

echo "== 1) Zählpunkt-Metadaten (Basic Auth) =="
curl -sS -X POST "${BASE}/energystore/query/${EC_ID}/metadata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  -H "X-Tenant: ${TENANT}" \
  -d '{}'
echo

echo "== 2) Energie-Rohdaten (Basic Auth, absolute Unix-ms) =="
curl -sS -X POST "${BASE}/energystore/query/rawdata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  -H "X-Tenant: ${TENANT}" \
  -d "{
        \"ecId\": \"${EC_ID}\",
        \"cps\": [{\"meteringPoint\": \"${METERING_POINT}\"}],
        \"start\": 1732665600000,
        \"end\": 1732752000000
      }"
echo

echo "== 3) Teilnehmer anlegen (Basic Auth) =="
curl -sS -X POST "${BASE}/api/participant" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  -H "X-Tenant: ${TENANT}" \
  -d @"$(dirname "$0")/participant.example.json"
echo

# == 4) Teilnehmer lesen — braucht Keycloak Bearer Token, NICHT Basic Auth! ==
# Zuerst Token holen (Refresh-Token-Flow), dann:
#   curl -sS "${BASE}/api/participant" \
#     -H "Authorization: Bearer ${ACCESS_TOKEN}" \
#     -H "X-Tenant: ${TENANT}"
# Siehe docs/authentication.md
