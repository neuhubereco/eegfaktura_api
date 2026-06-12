# EEGFaktura API – Integrations-Dokumentation

Konsolidierte, entwicklerfreundliche Dokumentation der **eegfaktura.at**-API,
zusammengestellt aus realen Integrationstests einer Energiegemeinschafts-Anbindung.

> **Zweck:** Referenz für die Anbindung an die eegfaktura-Backend-API
> (Teilnehmer-/Participant-Verwaltung + Energiedaten-Abruf).
> Diese Doku beschreibt die **externe API**, die von eegfaktura.at betrieben wird –
> nicht eine selbst entwickelte API.

---

## Überblick

- **Base URL:** `https://eegfaktura.at`
- **Upstream-Backend (Go):** <https://github.com/eegfaktura/eegfaktura-backend>
- **Primär-Doku (Upstream):** [DeepWiki – eegfaktura-backend API Layer](https://deepwiki.com/eegfaktura/eegfaktura-backend/3-api-layer)
- **Keycloak (Auth):** `https://login.eegfaktura.at`, Realm `EEGFaktura`

Zwei funktionale Bereiche:

| Bereich | Pfad-Präfix | Zweck |
|---|---|---|
| **Participant API** | `/api/participant` | Teilnehmer anlegen, ändern, archivieren, bestätigen |
| **Energystore API** | `/energystore/query` | Zählpunkt-Metadaten & 15-Minuten-Energierohdaten |

---

## ⚠️ Wichtigste Erkenntnis für Integratoren

Die Authentifizierung ist **nicht einheitlich** über alle Endpoints:

| Operation | Auth-Methode | Status |
|---|---|---|
| `POST /api/participant` (Anlegen) | **Basic Auth** (`user:password`) | ✅ funktioniert |
| `POST /energystore/query/...` | **Basic Auth** | ✅ funktioniert |
| `GET /api/participant` (Lesen) | **Keycloak Bearer Token** (nicht Basic Auth!) | ⚠️ siehe [Known Issues](docs/known-issues.md) |

Basic-Auth-`GET`-Requests gegen `/api/participant` liefern konsistent **400 Bad Request**.
Details und Workaround → [docs/known-issues.md](docs/known-issues.md).

---

## Schnellstart

```bash
# 1. Base64-Credentials für Basic Auth erzeugen
echo -n "DEIN_API_USER:DEIN_PASSWORT" | base64

# 2. Zählpunkt-Metadaten abrufen (funktioniert mit Basic Auth)
curl -X POST "https://eegfaktura.at/energystore/query/{ecId}/metadata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <BASE64>" \
  -H "X-Tenant: {tenant}" \
  -d '{}'
```

Alle Requests senden zusätzlich den Header **`X-Tenant`** (in der Regel der RC-Code, z. B. `RC######`).

---

## Inhaltsverzeichnis

| Dokument | Inhalt |
|---|---|
| [docs/authentication.md](docs/authentication.md) | Basic Auth + Keycloak-Bearer-Token-Flow, Header, Tenant |
| [docs/endpoints.md](docs/endpoints.md) | Alle Endpoints mit Request/Response, getestet vs. dokumentiert |
| [docs/data-model.md](docs/data-model.md) | `Participant`- und `Meter`-Datenmodell (Felder, Enums) |
| [docs/eda-processes.md](docs/eda-processes.md) | EDA/Ponton-Hintergrund: ECON/CPF/PT-Prozesse, Ablehnungsgründe, Datenverfügbarkeit, API-Lücken |
| [docs/known-issues.md](docs/known-issues.md) | `GET /participant` 400-Problem, offene Fragen, Empfehlungen |
| [openapi.yaml](openapi.yaml) | Maschinenlesbare OpenAPI-3.0-Spec (Swagger/Postman/Codegen) |

---

## Status-Legende

- ✅ **Verifiziert** – in echten Integrationstests erfolgreich
- ⚠️ **Dokumentiert, nicht verifiziert** – laut Upstream-Doku vorhanden, hier (noch) nicht erfolgreich getestet
- ❌ **Existiert nicht / schlägt fehl** – getestet, Endpoint antwortet 404 oder dauerhaft 400

---

## Herkunft & Pflege

Diese Doku ist eine Konsolidierung aus realen Integrationstests
(Markdown-Notizen + ein TypeScript-Client gegen die eegfaktura.at-API).
Bei Änderungen an der eegfaktura-API bitte gegen die
[DeepWiki-Doku](https://deepwiki.com/eegfaktura/eegfaktura-backend/3-api-layer) abgleichen.

---

## Lizenz

[MIT](LICENSE) — frei nutzbar, anpassbar und weiterverteilbar (inkl. Beispiel-Code).

> Hinweis: Bezieht sich nur auf den Inhalt **dieses** Repos (Doku + Beispiele).
> Die eegfaktura.at-API selbst sowie das Upstream-Backend stehen unter ihren eigenen Bedingungen.
