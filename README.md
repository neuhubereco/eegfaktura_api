# EEGFaktura API – Integrations-Dokumentation

Konsolidierte, entwicklerfreundliche Dokumentation der **eegfaktura.at**-API
(Mitglieder-/Zählpunkt-Verwaltung und Energiedaten-Abruf).

> **Zweck:** Referenz für die Anbindung an die eegfaktura-Backend-API.
> Diese Doku beschreibt die **externe API**, die von eegfaktura.at betrieben wird –
> nicht eine selbst entwickelte API.
>
> **Stand:** 30.09.2026, abgeglichen mit dem Quellcode
> [`eegfaktura/eegfaktura-backend`](https://github.com/eegfaktura/eegfaktura-backend) (Commit `f4974b2`, 26.09.2026)
> und [`eegfaktura/eegfaktura-energystore`](https://github.com/eegfaktura/eegfaktura-energystore) (Commit `a254dc8`, 26.09.2026)
> sowie der offiziellen Doku <https://eegfaktura.github.io/eegfaktura-docs/>.

---

## Überblick

- **Base URL:** `https://eegfaktura.at`
- **Backend (Go):** <https://github.com/eegfaktura/eegfaktura-backend> – die Routen sind im Backend
  ohne Präfix eingehängt (`/participant`, `/meteringpoint`, `/master` …); öffentlich erreichbar
  sind sie unter `https://eegfaktura.at/api/…` (Präfix kommt vom Ingress).
- **Energystore (Go):** <https://github.com/eegfaktura/eegfaktura-energystore> – öffentlich unter
  `https://eegfaktura.at/energystore/…`.
- **Offizielle Doku:** <https://eegfaktura.github.io/eegfaktura-docs/> (u. a. `architecture/auth`, `services/backend`)
- **Keycloak (Auth):** `https://login.eegfaktura.at`, Realm `EEGFaktura`

| Bereich | Pfad-Präfix | Zweck | Auth |
|---|---|---|---|
| **Participant API** | `/api/participant` | Mitglieder anlegen, ändern, bestätigen, löschen | Bearer (EEG-Admin) |
| **Metering-Point API** | `/api/meteringpoint` | Zählpunkte anlegen/ändern, Teilnahmefaktor, Abmeldung, Energiedaten anfordern | Bearer (EEG-Admin) |
| **Master API** | `/api/master` | Stammdaten lesen, Teilnahmefaktor-Änderung beantragen (Server-zu-Server) | Basic |
| **Energystore API** | `/energystore/query` | Zählpunkt-Metadaten & 15-Minuten-Energierohdaten | Basic |

---

## Wichtigste Erkenntnis für Integratoren

Die Authentifizierung hängt an der **Middleware der Route**, nicht an der HTTP-Methode:

| Middleware (Backend-Code) | Header | Routen |
|---|---|---|
| `Protect` / `ConditionProtect` | `Authorization: Bearer <Keycloak-Access-Token>` | **alle** `/api/participant/…` und `/api/meteringpoint/…` (auch `POST`) |
| `ProtectApi` | `Authorization: Basic base64(user:passwort)` | nur `/api/master/…` und `/energystore/query/…` |

- **Basic Auth auf `/api/participant` funktioniert nicht** – auch nicht für `POST`. Der Code
  (`api/middleware/tokenVerifier.go`) antwortet auf einen Nicht-Bearer-Header mit `403`.
- Schreibende Participant-/Metering-Point-Routen verlangen ein Token eines Benutzers in der
  Keycloak-Gruppe **`EEG_ADMIN`** (Claim `access_groups` enthält `/EEG_ADMIN`), sonst `401`.
- Einen offiziellen Machine-to-Machine-Weg für die Participant-API gibt es derzeit nicht
  (Feature-Request [eegfaktura/eegfaktura-backend#9](https://github.com/eegfaktura/eegfaktura-backend/issues/9)).

Details → [docs/authentication.md](docs/authentication.md).

---

## Schnellstart

```bash
# Zählpunkt-Metadaten abrufen (Energystore, Basic Auth)
AUTH=$(printf '%s' "DEIN_API_USER:DEIN_PASSWORT" | base64 | tr -d '\n')
curl -X POST "https://eegfaktura.at/energystore/query/{ecId}/metadata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  -H "X-Tenant: {tenant}" \
  -d '{}'

# Mitglieder lesen (Backend, Bearer Token eines EEG-Admins)
curl "https://eegfaktura.at/api/participant" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Tenant: {tenant}"
```

Alle Requests senden zusätzlich den Mandanten-Header **`X-Tenant`** (i. d. R. die RC-/CC-Nummer
der Gemeinschaft, z. B. `RC######`). Der Wert muss im `tenant`-Claim des Benutzers stehen.

---

## Inhaltsverzeichnis

| Dokument | Inhalt |
|---|---|
| [docs/authentication.md](docs/authentication.md) | Bearer (Keycloak) vs. Basic (`ProtectApi`), Header, Tenant, Statuscodes |
| [docs/endpoints.md](docs/endpoints.md) | Alle Endpoints mit Request/Response und Statuscodes |
| [docs/data-model.md](docs/data-model.md) | `Participant`-, `MeteringPoint`- und Request-Modelle (JSON-Feldnamen, Typen) |
| [docs/eda-processes.md](docs/eda-processes.md) | EDA/Ponton-Hintergrund: ECON/CPF/PT-Prozesse, Ablehnungsgründe, Datenverfügbarkeit |
| [docs/known-issues.md](docs/known-issues.md) | Stolperfallen, frühere Fehlannahmen, offene Fragen |
| [openapi.yaml](openapi.yaml) | Maschinenlesbare OpenAPI-3.0-Spec (Swagger/Postman/Codegen) |

---

## Status-Legende

- ✅ **Verifiziert** – in echten Integrationstests erfolgreich
- 📄 **Laut Quellcode** – aus dem Backend-/Energystore-Code abgeleitet, (noch) nicht live getestet
- ❌ **Existiert nicht / schlägt fehl** – im Code nicht vorhanden bzw. getestet mit Fehler

---

## Herkunft & Pflege

Ursprünglich eine Konsolidierung aus realen Integrationstests (Markdown-Notizen + TypeScript-Client),
seit 09/2026 gegen den Quellcode der öffentlichen eegfaktura-Repositories abgeglichen.
Bei Änderungen bitte gegen den Code (`api/*Controller.go`, `api/middleware/`, `model/participant.go`,
Energystore `rest/energy.go`) und die offizielle Doku abgleichen.

---

## Lizenz

[MIT](LICENSE) — frei nutzbar, anpassbar und weiterverteilbar (inkl. Beispiel-Code).

> Hinweis: Bezieht sich nur auf den Inhalt **dieses** Repos (Doku + Beispiele).
> Die eegfaktura.at-API selbst sowie das Upstream-Backend stehen unter ihren eigenen Bedingungen.
