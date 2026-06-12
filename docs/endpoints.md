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

Beispiel `CONSUMPTION` (drei Werte pro `value`):

```json
{
  "{meteringPointId}": {
    "data": [
      { "ts": 1732665600000, "value": [100.5, 0, 50.2], "qov": [1, 1, 1] }
    ],
    "direction": "CONSUMPTION"
  }
}
```

Beispiel `GENERATION` (zwei Werte pro `value` — `value[2]` entfällt):

```json
{
  "{meteringPointId}": {
    "data": [
      { "ts": 1774738800000, "value": [0, 0], "qov": [1, 2] }
    ],
    "direction": "GENERATION"
  }
}
```

**Value mapping (mit OBIS-Codes)**

Die positionsbasierten `value`-/`qov`-Arrays folgen der EEG-Faktura-Excel-Spaltenreihenfolge.
Quelle: [Offizielle eegfaktura-Doku — Energiedaten herunterladen](https://docs.eegfaktura.at/books/workflowprozesse/page/energiedaten-herunterladen).

| Richtung | Index | OBIS-Code | Excel-Spalte | Bedeutung |
|---|---|---|---|---|
| `CONSUMPTION` | `value[0]` | `1-1:1.9.0 G.01T` | Gesamtverbrauch lt. Messung (bei Teilnahme gem. Erzeugung) [KWH] | Gemessener Gesamtverbrauch, reduziert nach Teilnahmefaktor |
| `CONSUMPTION` | `value[1]` | `1-1:2.9.0 G.02` | Anteil gemeinschaftliche Erzeugung [KWH] | **Maximal zur Verfügung gestellte** Energie der Gemeinschaft (theoretisches Angebot, nicht der Bezug!) |
| `CONSUMPTION` | `value[2]` | `1-1:2.9.0 G.03` | Eigendeckung gemeinschaftliche Erzeugung [KWH] | Tatsächlicher **Bezug aus der Gemeinschaft** nach Teilnahmefaktor |
| `GENERATION` | `value[0]` | `1-1:2.9.0 G.01T` | Gesamte gemeinschaftliche Erzeugung [KWH] | Gemessene Erzeugung, reduziert nach Teilnahmefaktor |
| `GENERATION` | `value[1]` | `1-1:2.9.0 P.01T` | Gesamt/Überschusserzeugung, Gemeinschaftsüberschuss [KWH] | **Überschusseinspeisung** (ins Netz) nach Teilnahmefaktor |
| `GENERATION` | `value[2]` | — | — | nicht vorhanden (Array hat nur 2 Elemente) |

> ⚠️ **Teilnahmefaktor nicht doppelt anwenden:** Die `…T`-Codes (G.01T, P.01T) sind bereits
> **nach Teilnahmefaktor reduziert**. Das Feld `partFact` aus dem
> [`Meter`-Objekt](data-model.md) ist hier also schon eingerechnet — wer es nochmal
> draufmultipliziert, rechnet doppelt.

**Abrechnungsrelevante Größen (GEA/EEG/BEG-Verrechnung)**

Laut offizieller Doku werden für die Verrechnung verwendet:

| Rolle | Abgerechnete Größe | Berechnung aus `value[]` |
|---|---|---|
| Verbraucher | Bezug aus der Gemeinschaft (`G.03`) | `value[2]` — **nicht** `value[1]`! |
| Erzeuger | Lieferung **in** die Gemeinschaft (`G.01T − P.01T`) | `value[0] − value[1]` — steht **nirgends direkt** im Array |

**Quality-of-Value (`qov`, gleiche Indizierung wie `value`)**

| `qov` | Stufe | Bedeutung | Abrechnung |
|---|---|---|---|
| `0` | L0 | Energiedaten fehlen | ❌ |
| `1` | L1 | Echtwert (gemessen) | ✅ |
| `2` | L2 | Ersatzwert, belastbar (ändert sich sehr wahrscheinlich nicht mehr) | ✅ |
| `3` | L3 | Ersatzwert, **nicht belastbar** (z. B. extrapoliert — wird sich noch ändern) | ⚠️ vorläufig |

> ⚠️ **Nur L1- und L2-Werte gehören in eine korrekte Abrechnung.** L3-Zeiträume sind
> vorläufig und müssen später **erneut abgerufen** werden — eine Sync-Pipeline sollte
> L3-Daten als „vorläufig" markieren und den Zeitraum re-fetchen, bis L1/L2 vorliegt.

**Normative Referenzen (österreichischer Marktstandard)**

Das Mapping folgt den ebUtilities-Spezifikationen, nicht einem eegfaktura-Eigenbau:

- [ebutilities.at — Prozess 453](https://www.ebutilities.at/prozesse/453)
- [Informationsflüsse Energiegemeinschaften (PDF, 06/2023)](https://www.ebutilities.at/documents/2023/06/202306_Informationsfl%C3%BCsse_Energiegemeinschaften.pdf)
- [MeterCodes CR MSG (PDF, 12/2023)](https://www.ebutilities.at/documents/2023/12/13122023_MeterCodes_CR_MSG.pdf)
- [OBIS Metercodes VEZ VNB (PDF, 09/2022)](https://www.ebutilities.at/documents/20220928204643_20220927_OBIS_Metercodes_VEZ_VNB.pdf)

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
