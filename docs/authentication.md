# Authentifizierung

Die eegfaktura-Dienste kennen **zwei** Authentifizierungswege. Welcher gilt, entscheidet die
Middleware der jeweiligen Route – nicht die HTTP-Methode.

| Middleware | Header | Routen | Rolle/Gruppe |
|---|---|---|---|
| `Protect` | `Authorization: Bearer <JWT>` | alle `/api/participant/…` außer `GET`, alle `/api/meteringpoint/…`, `/api/eeg/…`, `/api/process/…` | Gruppe `EEG_ADMIN` |
| `ConditionProtect` | `Authorization: Bearer <JWT>` | `GET /api/participant`, `GET /api/eeg` | `EEG_ADMIN` → alle Datensätze, `EEG_USER` → eigener Datensatz |
| `ProtectApi` (Backend) | `Authorization: Basic base64(user:passwort)` | `GET /api/master/masterdata`, `POST /api/master/updatepartfact` | vom Betreiber freigegebener API-Benutzer |
| `ProtectApi` (Energystore) | `Authorization: Basic base64(user:passwort)` | `POST /energystore/query/rawdata`, `POST /energystore/query/{ecId}/metadata` | vom Betreiber freigegebener API-Benutzer |

Quelle: `api/middleware/tokenVerifier.go`, `api/participantController.go`, `api/meteringPointController.go`,
`api/apiController.go` (Backend) bzw. `middleware/api_authentication.go`, `rest/energy.go` (Energystore).
Siehe auch die offizielle Doku: [Architecture / Authentication](https://eegfaktura.github.io/eegfaktura-docs/architecture/auth/).

---

## Gemeinsame Header

| Header | Wert | Pflicht |
|---|---|---|
| `Content-Type` | `application/json` (bei Requests mit Body) | ja |
| `X-Tenant` | Mandant, i. d. R. die RC-/CC-Nummer der Gemeinschaft (z. B. `RC######`) | ja |
| `Authorization` | `Bearer …` oder `Basic …` je nach Route (siehe oben) | ja |

> **Tenant:** Der Wert muss im `tenant`-Claim (JSON-Array) des Benutzers stehen; der Vergleich
> ist unabhängig von Groß-/Kleinschreibung. Bearer-Routen akzeptieren alternativ den Header
> `tenant` (wird zuerst gelesen); `ProtectApi`-Routen lesen **nur** `X-Tenant`.

---

## 1. Keycloak Bearer Token (Participant-, Metering-Point-, EEG-Routen)

### Keycloak-Parameter

| Parameter | Wert |
|---|---|
| Server URL | `https://login.eegfaktura.at` |
| Realm | `EEGFaktura` |
| Token-Endpoint | `https://login.eegfaktura.at/realms/EEGFaktura/protocol/openid-connect/token` |
| Client ID (Web-App, public, PKCE) | `at.ourproject.vfeeg.app` |

Das Backend prüft das Token (RS256, Issuer) und wertet folgende Claims aus:

| Claim | Bedeutung |
|---|---|
| `tenant` | Array der Mandanten, auf die der Benutzer zugreifen darf |
| `access_groups` | Gruppen mit führendem Slash, z. B. `["/EEG_ADMIN"]` – entscheidet über Admin (`/EEG_ADMIN`) bzw. Mitglied (`/EEG_USER`) |
| `email` | für die Mitglieder-Selbstabfrage (`GET /api/participant` ohne Admin-Gruppe) |
| `preferred_username` | wird als `createdBy`/`modifiedBy` gespeichert |

> Seit Backend-Release 1.0.0 (28.06.2026) entscheidet `access_groups` über die Berechtigung,
> nicht mehr `realm_access.roles`.

### Access Token via Refresh Token erneuern

Es gibt **keinen** `username/password`→JWT-Endpoint unter `/api/…`. Das Token kommt aus dem
Keycloak-OIDC-Flow der offiziellen Web-App (Authorization Code + PKCE). Eine Integration kann
einen vorhandenen **Refresh Token** zum Erneuern verwenden:

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

- Access Token läuft kurz (≈ `expires_in`, oft 300 s) → **cachen** und mit Puffer (~30 s) erneuern.
- Refresh Token läuft ebenfalls ab (`refresh_expires_in`) → bei jedem Refresh den **neuen**
  Refresh Token speichern (Keycloak rotiert ihn ggf.). Ohne regelmäßige Erneuerung verfällt die Kette.
- Der Refresh Token stammt aus einer Session der offiziellen Web-App. Einen dokumentierten
  Service-Account-/Client-Credentials-Flow für die Participant-API gibt es derzeit nicht
  → [eegfaktura/eegfaktura-backend#9](https://github.com/eegfaktura/eegfaktura-backend/issues/9).

### Antwortcodes der Bearer-Middleware

| Situation | Status |
|---|---|
| `Authorization` fehlt oder ist kein `Bearer …` (z. B. Basic) | `403` |
| Token ungültig/abgelaufen | `401` |
| `X-Tenant`/`tenant` nicht im `tenant`-Claim | `403` |
| `Protect`-Route, Benutzer nicht in Gruppe `EEG_ADMIN` | `401` |
| `ConditionProtect`-Route, weder `EEG_ADMIN` noch `EEG_USER` | `401` |

---

## 2. Basic Authentication (`ProtectApi`: `/api/master/…`, `/energystore/query/…`)

```
Authorization: Basic {base64(username:password)}
X-Tenant: {tenant}
```

Der Dienst tauscht Benutzername/Passwort serverseitig per Keycloak-Password-Grant gegen ein Token
und prüft danach den Mandanten. Voraussetzungen:

- ein vom Betreiber freigegebener Keycloak-Benutzer, dessen `tenant`-Claim den `X-Tenant`-Wert enthält;
- der vom Betreiber dafür konfigurierte Keycloak-Client muss „Direct Access Grants“
  (Resource Owner Password Credentials) erlauben – das liegt nicht in der Hand des Integrators.

Base64-String erzeugen:

```bash
# macOS/Linux – KEIN `base64 -w0` auf macOS verwenden!
printf '%s' "username:password" | base64 | tr -d '\n'
```

Beispiel (Node.js):

```javascript
const auth = Buffer.from(`${apiUser}:${apiPassword}`).toString('base64');
const res = await fetch(`https://eegfaktura.at/energystore/query/${ecId}/metadata`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Basic ${auth}`,
    'X-Tenant': tenant,
  },
  body: '{}',
});
```

> **Stolperfalle Energystore:** Der Energystore dekodiert den Basic-Header mit URL-sicherem
> Base64 und trennt Benutzer/Passwort an **jedem** `:`. Passwörter mit `:` sowie Zugangsdaten,
> deren Base64-Form `+` oder `/` enthält, führen dort zu `403`. Das Backend (`/api/master/…`)
> ist davon nicht betroffen.

### Antwortcodes von `ProtectApi`

| Situation | Backend `/api/master` | Energystore |
|---|---|---|
| `Authorization` fehlt | `403` | `403` |
| Kein `Basic …`-Schema / ungültige Kodierung | `400` | `400` (Schema) |
| Benutzername/Passwort falsch oder Password-Grant nicht erlaubt | `403` | `403` |
| `X-Tenant` nicht im `tenant`-Claim | `403` | `403` |
