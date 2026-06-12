# Endpoints

Base URL: `https://eegfaktura.at`

Status-Legende: ✅ verifiziert · ⚠️ dokumentiert, nicht verifiziert · ❌ existiert nicht / schlägt fehl

---

## Participant API

### `POST /api/participant` — Teilnehmer anlegen ✅

Registriert einen neuen Teilnehmer. **Basic Auth.**

**Headers**
```
Content-Type: application/json
Authorization: Basic {base64(user:password)}
X-Tenant: {tenant}
```

**Body:** vollständiges `Participant`-Objekt → siehe [data-model.md](data-model.md).

**Response:** `201 Created`, Teilnehmer-Objekt inkl. generierter `id` und `participantNumber`.

```bash
curl -X POST "https://eegfaktura.at/api/participant" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <BASE64>" \
  -H "X-Tenant: {tenant}" \
  -d @participant.json
```

> **Wichtig:** Beim Anlegen die zurückgegebene `id` + `participantNumber` **lokal speichern** —
> es gibt keine zuverlässige Liste-aller-Teilnehmer-Operation (siehe unten).

---

### `GET /api/participant` — Teilnehmer lesen ⚠️

Soll laut Upstream-Doku alle Teilnehmer des Tenants zurückgeben.

- **Auth:** **Keycloak Bearer Token** (nicht Basic Auth — Basic Auth → `400`).
- **Mit Basic Auth getestet:** ohne Parameter sowie mit `?id=`, `?email=`,
  `?participantNumber=`, `?meteringPoint=`, `?tenant=`, `?ecId=` → **alle 400 Bad Request**.
- **Mit Bearer Token:** in der Referenzimplementierung als korrekter Weg vorgesehen,
  aber noch nicht abschließend grün verifiziert.

→ Details & Workaround: [known-issues.md](known-issues.md)

```
GET https://eegfaktura.at/api/participant
Authorization: Bearer {access_token}
X-Tenant: {tenant}
```

---

### `PUT /api/participant/{id}` — Teilnehmer aktualisieren ⚠️

Aktualisiert einen bestehenden Teilnehmer. Laut Doku `202 Accepted`.

- **URL-Parameter:** `id` — Teilnehmer-ID (UUID).
- **Body:** (Teil-)`Participant`-Objekt.
- **Praxis-Hinweis aus Referenzclient:** Vor dem Senden **leere Strings (`""`) entfernen** —
  sie können serverseitig UUID-Parse-Fehler auslösen. `null`-Werte sind i. d. R. ok.

---

### `DELETE /api/participant/{id}` — Teilnehmer archivieren ⚠️

Logisches Löschen (Archivierung). Laut Doku `202 Accepted`.

- **URL-Parameter:** `id` — Teilnehmer-ID.

---

### `POST /api/participant/{id}/confirm` — Teilnehmer bestätigen/aktivieren ⚠️

Bestätigt einen Teilnehmer und aktiviert ihn. Laut Doku `201 Created`.

Server-Aktionen:
- Setzt Teilnehmer-Status auf `ACTIVE`.
- Sendet EBMS-Nachrichten für die Zählpunkte (falls EEG online).
- Versendet Aktivierungs-E-Mail.

---

### Nicht existierende Endpoints ❌

| Endpoint | Ergebnis |
|---|---|
| `GET /api/participants` (Plural) | `404 Not Found` |
| `GET /api/participant/{id}` | `404 Not Found` (in Tests) |
| `POST /api/participant/list` | `404 Not Found` |
| `POST /energystore/query/{ecId}/participants` | `404 Not Found` |
| `POST /api/auth/login`, `/api/login`, `/api/auth/token` | `404 Not Found` |

---

## Energystore API

### `POST /energystore/query/{ecId}/metadata` — Zählpunkt-Metadaten ✅

Liefert verfügbare Datenzeiträume pro Zählpunkt. **Basic Auth.**

**URL-Parameter:** `ecId` — Energy Community ID (z. B. `AT00300000000RC######...`).

**Body:** `{}`

```bash
curl -X POST "https://eegfaktura.at/energystore/query/{ecId}/metadata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <BASE64>" \
  -H "X-Tenant: {tenant}" \
  -d '{}'
```

**Response:** `200 OK` — Map `meteringPoint → {periodBegin, periodEnd}` (Unix-ms):

```json
{
  "AT00300000000000000000000000000000": {
    "periodBegin": 1733266800000,
    "periodEnd": 1764025200000
  }
}
```

---

### `POST /energystore/query/rawdata` — Energie-Rohdaten ✅

Liefert 15-Minuten-Rohdaten für Zählpunkte in einem absoluten Zeitfenster. **Basic Auth.**

**Body**
```json
{
  "ecId": "{ecId}",
  "cps": [
    { "meteringPoint": "{meteringPointId}" }
  ],
  "start": 1732665600000,
  "end": 1732752000000
}
```

| Feld | Typ | Beschreibung |
|---|---|---|
| `ecId` | string | Energy Community ID |
| `cps` | array | Liste von Zählpunkten (`{ meteringPoint }`) |
| `start` | number | **absoluter** Start-Timestamp in **Millisekunden** |
| `end` | number | **absoluter** End-Timestamp in **Millisekunden** |

> ⚠️ `start`/`end` müssen **absolute** Unix-Millisekunden sein — keine relativen Werte.

**Response:** `200 OK`

```json
{
  "{meteringPointId}": {
    "data": [
      { "ts": 1732665600000, "value": [100.5, 0, 50.2], "qov": [1, 1, 1] }
    ],
    "direction": "CONSUMPTION"
  }
}

{
  "{meteringPointId}": {
    "data": [
      {"ts":1774738800000,"value":[0,0],"qov":[1,2]}
    ],
    "direction":"GENERATION"
  }
}
```

**Value mapping**

Die positionsbasierten `value`-/`qov`-Arrays folgen der EEG-Faktura-Excel-Spaltenreihenfolge:

| Richtung | `value[0]` | `value[1]` | `value[2]` |
|---|---|---|---|
| `CONSUMPTION` | `Gesamtverbrauch lt. Messung (bei Teilnahme gem. Erzeugung) [KWH]` | `Anteil gemeinschaftliche Erzeugung [KWH]` | `Eigendeckung gemeinschaftliche Erzeugung [KWH]` |
| `GENERATION` | `Gesamte gemeinschaftliche Erzeugung [KWH]` | `Gesamt/Überschusserzeugung, Gemeinschaftsüberschuss [KWH]` | not_used |


The values map to the OBIS codes like this: https://docs.eegfaktura.at/books/workflowprozesse/page/energiedaten-herunterladen

**Quality (`qov` pro Value-Index):**

- `1` / `2` / `3` → `L1` / `L2` / `L3`.
- `0` (`L0`) = fehlende Daten


---

## Zusammenfassung Auth pro Endpoint

| Endpoint | Methode | Auth | Status |
|---|---|---|---|
| `/api/participant` | POST | Basic | ✅ |
| `/api/participant` | GET | Bearer (Keycloak) | ⚠️ |
| `/api/participant/{id}` | PUT | Basic/Bearer¹ | ⚠️ |
| `/api/participant/{id}` | DELETE | Basic/Bearer¹ | ⚠️ |
| `/api/participant/{id}/confirm` | POST | Basic/Bearer¹ | ⚠️ |
| `/energystore/query/{ecId}/metadata` | POST | Basic | ✅ |
| `/energystore/query/rawdata` | POST | Basic | ✅ |

¹ Nicht abschließend getestet — analog zu POST vermutlich Basic Auth, bei Lesezugriff ggf. Bearer.
