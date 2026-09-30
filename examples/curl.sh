#!/usr/bin/env bash
# Beispiel-Requests gegen die eegfaktura.at-API.
# Platzhalter in GROSSBUCHSTABEN ersetzen. KEINE echten Credentials committen!
#
# Auth-Übersicht (siehe docs/authentication.md):
#   /energystore/query/...  und  /api/master/...   -> Basic Auth
#   /api/participant/...    und  /api/meteringpoint/... -> Bearer (Keycloak, Gruppe EEG_ADMIN)
set -euo pipefail

BASE="https://eegfaktura.at"
API_USER="DEIN_API_USER"
API_PASS="DEIN_PASSWORT"
TENANT="DEIN_TENANT"          # i. d. R. die RC-/CC-Nummer, z. B. RC######
EC_ID="DEINE_EC_ID"           # z. B. AT00300000000RC...
METERING_POINT="DEIN_ZAEHLPUNKT"
REFRESH_TOKEN="${EEGFAKTURA_REFRESH_TOKEN:-DEIN_REFRESH_TOKEN}"   # aus einer Web-App-Session

# macOS-kompatibles Base64 (kein -w0!)
AUTH=$(printf '%s' "${API_USER}:${API_PASS}" | base64 | tr -d '\n')

echo "== 1) Zählpunkt-Metadaten (Energystore, Basic Auth) =="
curl -sS -X POST "${BASE}/energystore/query/${EC_ID}/metadata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  -H "X-Tenant: ${TENANT}" \
  -d '{}'
echo

echo "== 2) Energie-Rohdaten (Energystore, Basic Auth, absolute Unix-ms) =="
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

echo "== 3) Stammdaten aller Mitglieder (Backend /master, Basic Auth) =="
curl -sS "${BASE}/api/master/masterdata" \
  -H "Authorization: Basic ${AUTH}" \
  -H "X-Tenant: ${TENANT}"
echo

echo "== 4) Access Token per Refresh Token holen (Keycloak) =="
TOKEN_JSON=$(curl -sS -X POST \
  "https://login.eegfaktura.at/realms/EEGFaktura/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=at.ourproject.vfeeg.app" \
  -d "refresh_token=${REFRESH_TOKEN}")
ACCESS_TOKEN=$(printf '%s' "${TOKEN_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
# Hinweis: der Response enthält einen NEUEN refresh_token – für den nächsten Lauf speichern.

echo "== 5) Mitglieder lesen (Bearer) =="
curl -sS "${BASE}/api/participant" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Tenant: ${TENANT}"
echo

echo "== 6) Mitglied anlegen (Bearer — Basic Auth wird hier mit 403 abgelehnt) =="
curl -sS -X POST "${BASE}/api/participant" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Tenant: ${TENANT}" \
  -d @"$(dirname "$0")/participant.example.json"
echo

# == 7) Mitglied bestätigen / bei EDA anmelden (Bearer) – löst echte EDA-Nachrichten aus! ==
#   curl -sS -X POST "${BASE}/api/participant/${PARTICIPANT_ID}/confirm" \
#     -H "Content-Type: application/json" \
#     -H "Authorization: Bearer ${ACCESS_TOKEN}" \
#     -H "X-Tenant: ${TENANT}" \
#     -d @"$(dirname "$0")/confirm.example.json"

# == 8) Teilnahmefaktor-Änderung bei EDA beantragen (Bearer) – löst echte EDA-Nachrichten aus! ==
#   curl -sS -X POST "${BASE}/api/meteringpoint/changepartitionfactor" \
#     -H "Content-Type: application/json" \
#     -H "Authorization: Bearer ${ACCESS_TOKEN}" \
#     -H "X-Tenant: ${TENANT}" \
#     -d @"$(dirname "$0")/partfact-change.example.json"
