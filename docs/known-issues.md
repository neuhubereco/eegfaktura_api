# Known Issues & offene Fragen

Stand: konsolidiert aus Integrationstests (Projekt `eegfakturareport`).
Diese Datei dokumentiert ehrlich, was **nicht** funktioniert hat — damit der nächste
Entwickler nicht dieselben Sackgassen durchläuft.

---

## 1. `GET /api/participant` → `400 Bad Request` mit Basic Auth

**Symptom:** Jede Lese-Abfrage gegen `/api/participant` mit Basic Auth schlägt fehl —
ohne Parameter und mit allen getesteten Query-Parametern:

| Variante | Ergebnis |
|---|---|
| `GET /api/participant` | 400 |
| `GET /api/participant?id=...` | 400 |
| `GET /api/participant?email=...` | 400 |
| `GET /api/participant?participantNumber=...` | 400 |
| `GET /api/participant?meteringPoint=...` | 400 |
| `GET /api/participant?tenant=...` | 400 |
| `GET /api/participant?ecId=...` | 400 |
| `GET /api/participant/{id}` | 404 |

Die 400er kommen **ohne Response-Body** (Content-Length 0).

**Ursache (sehr wahrscheinlich):** `GET /api/participant` erwartet einen
**Keycloak-Bearer-Token**, kein Basic Auth. Basic Auth funktioniert nur für `POST`.
Die Referenzimplementierung leitet GET-Requests entsprechend auf einen
Keycloak-Token-Pfad um (`fetchParticipantWithKeycloakToken`).

**Workaround / Lösungsweg:**
1. Keycloak Access Token besorgen (siehe [authentication.md](authentication.md#2-keycloak-bearer-token-leseoperationen)).
2. Request mit `Authorization: Bearer {token}` + `X-Tenant` senden.
3. Falls weiterhin Probleme: Teilnehmerdaten **lokal spiegeln** (siehe Punkt 3).

---

## 2. Kein einfacher JWT-Login-Endpoint

Es wurde **kein** `username/password`→JWT-Endpoint unter `/api/...` gefunden:

| Versuch | Ergebnis |
|---|---|
| `POST /api/auth/login` | 404 |
| `POST /api/login` | 404 |
| `POST /api/auth/token` | 404 |
| `GET /api/auth` | 404 |
| Selbst signierte JWTs | 401 Unauthorized |

**Konsequenz:** Tokens müssen über den **Keycloak-OIDC-Flow** der offiziellen App
bezogen werden (Token-Endpoint des Realms `EEGFaktura` auf `login.eegfaktura.at`,
Client `at.ourproject.vfeeg.app`, `grant_type=refresh_token`).

**Offene Frage an das eegfaktura-Team:** Gibt es einen **Service-Account- /
Client-Credentials-Flow** für Server-zu-Server-Integrationen? Das wäre der saubere
Weg statt Refresh-Token-Recycling aus einer User-Session.

---

## 3. Empfohlene Integrationsstrategie

Da es **keine zuverlässige „Liste aller Teilnehmer"-Operation** über Basic Auth gibt:

1. **Beim Anlegen** (`POST /api/participant`) die zurückgegebene `id` +
   `participantNumber` **lokal persistieren** (eigene DB-Tabelle, z. B. `ParticipantRegistration`).
2. **Abfragen primär aus der lokalen DB** bedienen, nicht aus der eegfaktura-API.
3. Für serverseitige Reads die **Keycloak-Bearer-Token-Variante** implementieren.
4. **Schreibpfade** (`POST`/`PUT`/`DELETE`/`confirm`) über Basic Auth abwickeln.

---

## 4. Noch nicht verifiziert

Folgende laut Upstream-Doku vorhandenen Endpoints wurden **nicht** abschließend getestet:

- `PUT /api/participant/{id}` (Update, soll `202` liefern)
- `DELETE /api/participant/{id}` (Archivieren, soll `202` liefern)
- `POST /api/participant/{id}/confirm` (Aktivieren, soll `201` liefern)
- `GET /api/participant` mit gültigem Bearer Token (Erfolgspfad)

Wer diese verifiziert: bitte Ergebnis hier ergänzen.

---

## Referenzen

- Upstream-Backend: <https://github.com/eegfaktura/eegfaktura-backend>
- DeepWiki API Layer: <https://deepwiki.com/eegfaktura/eegfaktura-backend/3-api-layer>
- Zu prüfende Stellen im Backend (Go): `handler/participant.go`, Auth-Middleware (JWT),
  Routing für `/api/participant`.
