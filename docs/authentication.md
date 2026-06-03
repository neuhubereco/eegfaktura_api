# Authentifizierung

Die eegfaktura-API verwendet **zwei verschiedene** Authentifizierungsmechanismen,
abhängig vom Endpoint bzw. der HTTP-Methode.

---

## Gemeinsame Header

Jeder Request enthält mindestens:

| Header | Wert | Pflicht |
|---|---|---|
| `Content-Type` | `application/json` | ja |
| `X-Tenant` | Tenant-Kennung, i. d. R. der RC-Code (z. B. `RC######`) | ja |
| `Authorization` | je nach Methode (siehe unten) | ja |

> **Tenant:** Der `X-Tenant`-Header steuert die Mandantentrennung. Er entspricht
> üblicherweise dem RC-Code der Energiegemeinschaft. Bei manchen Lese-Operationen
> kommt die Tenant-Information laut Upstream-Doku alternativ aus den JWT-Claims.

---

## 1. Basic Authentication (Schreiboperationen + Energystore)

Verwendet für `POST /api/participant` und alle `/energystore/query/...`-Endpoints.

```
Authorization: Basic {base64(username:password)}
```

Base64-String erzeugen:

```bash
# Linux / macOS – KEIN `base64 -w0` auf macOS verwenden!
echo -n "username:password" | base64
# bei langen Strings ggf.:  base64 < file | tr -d '\n'
```

Beispiel (Node.js):

```javascript
const auth = Buffer.from(`${apiUser}:${apiPassword}`).toString('base64');
const res = await fetch('https://eegfaktura.at/api/participant', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Basic ${auth}`,
    'X-Tenant': tenant,
  },
  body: JSON.stringify(participant),
});
```

---

## 2. Keycloak Bearer Token (Leseoperationen)

`GET /api/participant` akzeptiert **kein** Basic Auth, sondern erwartet ein
**Keycloak-OIDC-Access-Token** im `Authorization: Bearer ...`-Header.

### Keycloak-Parameter

| Parameter | Wert |
|---|---|
| Server URL | `https://login.eegfaktura.at` |
| Realm | `EEGFaktura` |
| Token-Endpoint | `https://login.eegfaktura.at/realms/EEGFaktura/protocol/openid-connect/token` |
| Client ID (App-Client) | `at.ourproject.vfeeg.app` |

> **Hinweis:** Es gibt **keinen** einfachen `username/password`→JWT-Login-Endpoint
> unter `/api/...`. Der Token kommt aus dem Keycloak-OIDC-Flow der offiziellen App.
> In der Referenzimplementierung wird ein vorhandener **Refresh Token** verwendet,
> um Access Tokens zu erneuern.

### Access Token via Refresh Token erneuern

```bash
curl -X POST \
  "https://login.eegfaktura.at/realms/EEGFaktura/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=at.ourproject.vfeeg.app" \
  -d "refresh_token=DEIN_REFRESH_TOKEN"
```

Antwort (gekürzt):

```json
{
  "access_token": "eyJhbGciOi...",
  "expires_in": 300,
  "refresh_token": "eyJhbGciOi...",
  "refresh_expires_in": 1800,
  "token_type": "Bearer"
}
```

Danach:

```
Authorization: Bearer {access_token}
X-Tenant: {tenant}
```

### Token-Handling (Empfehlung)

- Access Token läuft kurz (≈ `expires_in` Sekunden, oft 300 s) → **cachen** und vor
  Ablauf (Puffer ~30 s) erneuern.
- Refresh Token läuft ebenfalls ab (`refresh_expires_in`) → bei jedem Refresh den
  **neuen** Refresh Token speichern (Keycloak rotiert ihn ggf.).
- Für Tests kann ein **manuell extrahierter Bearer Token** direkt gesetzt werden
  (z. B. via Env-Var), um den Refresh-Flow zu umgehen.

---

## Wie komme ich an einen Refresh Token?

Der Refresh Token wird aus einer aktiven Session der offiziellen eegfaktura-Web-App
gewonnen (Browser-DevTools → Netzwerk-Tab → Token-Request, oder
`localStorage`/Keycloak-Adapter-State). Es gibt keinen dokumentierten
Service-Account-Flow für diese API. → siehe [known-issues.md](known-issues.md).
