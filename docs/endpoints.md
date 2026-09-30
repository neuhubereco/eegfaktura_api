# Endpoints

Base URL: `https://eegfaktura.at` · Backend-Routen unter `/api`, Energystore unter `/energystore`.

Status-Legende: ✅ verifiziert · 📄 laut Quellcode (Backend `f4974b2` / Energystore `a254dc8`, 26.09.2026) · ❌ existiert nicht

Auth-Kurzform: **Bearer** = Keycloak-Token + Gruppe `EEG_ADMIN`; **Basic** = `ProtectApi`
(siehe [authentication.md](authentication.md)). Alle Requests brauchen `X-Tenant`.

---

## Welcher Endpoint für welche Aufgabe?

| Aufgabe | Endpoint | Hinweis |
|---|---|---|
| Neues Mitglied anlegen | `POST /api/participant` | Status danach `PENDING` |
| Neues Mitglied bestätigen / beim Netzbetreiber anmelden | `POST /api/participant/{id}/confirm` | nur einmal, nur für neue Mitglieder |
| Stammdaten ändern (Name, Kontakt, Adressen, Bank) | `PUT /api/participant/{id}` oder `PUT /api/participant/v2/{id}` | Zählpunkte werden hier **nicht** geändert |
| Zählpunkt zu bestehendem Mitglied hinzufügen | `PUT /api/meteringpoint/{pid}/create` | |
| Zählpunktdaten ändern | `PUT /api/meteringpoint/{pid}/update/{mid}` oder `…/v2/{pid}/update/{mid}` | nicht für `partFact` |
| Teilnahmefaktor **mit** EDA-Prozess ändern | `POST /api/meteringpoint/changepartitionfactor` (Bearer) oder `POST /api/master/updatepartfact` (Basic) | |
| Teilnahmefaktor nur in eegfaktura korrigieren | `PUT /api/meteringpoint/{pid}/update/{mid}/partfact` | kein EDA-Prozess |
| Zählpunkt beim Netzbetreiber abmelden | `POST /api/meteringpoint/{pid}/revokemeters` | |
| Stammdaten aller Mitglieder lesen (Server-zu-Server) | `GET /api/master/masterdata` (Basic) | |
| Energiedaten lesen | `POST /energystore/query/rawdata`, `POST /energystore/query/{ecId}/metadata` | Basic |

---

## Participant API (`/api/participant`)

### `GET /api/participant` — Mitglieder lesen 📄

- **Auth:** Bearer (`ConditionProtect`).
  - Gruppe `EEG_ADMIN` → **alle** Mitglieder des Mandanten.
  - Gruppe `EEG_USER` → nur Mitglieder, deren `contact.email` der E-Mail im Token entspricht.
- **Query-Parameter:** keine. (`?id=`, `?email=` usw. werden ignoriert.)
- **Response:** `200 OK`, JSON-Array von `Participant` inkl. `meters` → [data-model.md](data-model.md). Fehler: `400`.

```bash
curl "https://eegfaktura.at/api/participant" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Tenant: {tenant}"
```

> Einen Endpoint „einzelnes Mitglied per ID lesen“ gibt es nicht – aus der Liste filtern.

---

### `POST /api/participant` — Mitglied anlegen 📄

- **Auth:** Bearer, `EEG_ADMIN`. **Basic Auth wird mit `403` abgelehnt.**
- **Body:** `Participant` inkl. `meters` → [data-model.md](data-model.md), Beispiel
  [examples/participant.example.json](../examples/participant.example.json).
- Server-seitig gesetzt bzw. ignoriert:
  - `id` wird neu vergeben, `status` immer `PENDING`, `createdBy` = Benutzer aus dem Token.
  - `participantSince` wird übernommen; fehlt es, gilt das heutige Datum.
  - `participantNumber` wird **nicht** generiert, sondern aus dem Body übernommen (optional).
  - `tariffId` (Mitglied) wird beim Anlegen **nicht** gespeichert – nachträglich per `PUT` setzen.
  - Je Zählpunkt: `status`, `modifiedAt`, `modifiedBy` setzt der Server; `processState` fehlt → `NEW`;
    `registeredSince` fehlt → heute. `partFact` wird übernommen (**fehlt er, wird 0 gespeichert**).
  - `contact.email` wird normalisiert und geprüft (mehrere Adressen mit `;` getrennt); ungültig → `400`.
- **Response:** `201 Created` mit dem angelegten Mitglied (inkl. neuer `id`). Fehler: `400`.

```bash
curl -X POST "https://eegfaktura.at/api/participant" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-Tenant: {tenant}" \
  -d @examples/participant.example.json
```

> **Kein Bulk-Import via API:** Massen-Import gibt es nur als Excel-Vorlage im Web-UI
> → [eda-processes.md](eda-processes.md#was-es-nicht-über-die-api-gibt).

---

### `PUT /api/participant/{id}` — Stammdaten aktualisieren 📄

- **Auth:** Bearer, `EEG_ADMIN`.
- **Body:** `Participant`. **Maßgeblich ist die `id` im Body** – die ID im Pfad wird nicht ausgewertet.
  Fehlt `id` im Body, schlägt das Update fehl (`400`, `invalid input syntax for type uuid: ""`).
- **Geschrieben werden nur:** `firstname`, `lastname`, `titleBefore`, `titleAfter`, `participantSince`,
  `participantNumber`, `vatNumber`, `taxNumber`, `companyRegisterNumber`, `businessRole`, `role`,
  `tariffId`, `status`, `version` sowie `contact`, `residentAddress`, `billingAddress`, `accountInfo`.
- **Nicht geschrieben:** `meters` (Zählpunkte → `/api/meteringpoint/…`), `id`, `createdBy`.
- Leere/fehlende Felder werden übersprungen – bestehende Werte bleiben erhalten.
- `contact.email` wird normalisiert und geprüft; ungültig → `400`.
- **Response:** `202 Accepted` mit dem **gesendeten** Body. Ein `202` belegt nicht, dass sich etwas
  geändert hat (z. B. bei unbekannter `id`) → danach per `GET` prüfen.

---

### `PUT /api/participant/v2/{id}` — einzelnes Feld ändern 📄

- **Auth:** Bearer, `EEG_ADMIN`.
- **Body:** `{"path": "<feld>", "value": <wert>}`. Unterobjekte mit Punkt:
  `contact.email`, `contact.phone`, `billingAddress.city`, `residentAddress.zip`, `accountInfo.iban` …;
  Basisfelder ohne Punkt, z. B. `{"path": "firstname", "value": "Anna"}`.
- Sonderfall: `businessRole` = `EEG_BUSINESS` leert zugleich `lastname`, `titleBefore`, `titleAfter`.
- `path` muss ein String sein; `value` hat den JSON-Typ des Zielfelds.
- **Response:** `202 Accepted` mit dem neu gelesenen Mitglied. Fehler beim Speichern: `500`; ungültiges JSON: `400`.

---

### `POST /api/participant/{id}/confirm` — Mitglied bestätigen und anmelden 📄

Erstaktivierung eines **neuen** Mitglieds (`PENDING` → `ACTIVE`).

- **Auth:** Bearer, `EEG_ADMIN`.
- **Body:** JSON-**Array** der Zählpunkte, die angemeldet werden sollen
  (Beispiel [examples/confirm.example.json](../examples/confirm.example.json)):

  ```json
  [
    {
      "meteringPoint": "AT0030000000000000000000000000000",
      "activationMode": "ONLINE",
      "activationCode": "",
      "registeredSince": "2026-11-01"
    }
  ]
  ```

  - `activationMode`: `ONLINE` (Online-Zustimmung) oder `OFFLINE` (mit `activationCode`).
    Jeder Wert außer `ONLINE` – auch ein fehlender – wird als **Offline**-Anmeldung behandelt.
  - Anmeldedatum = `registeredSince`, wenn es nach `participantSince` liegt, sonst `participantSince`.
  - Zählpunkte, die dem Mitglied nicht zugeordnet sind, werden stillschweigend übersprungen.
  - Kein Body oder ein Objekt statt Array → `400`.
- **Ablauf:**
  - Mitgliedsstatus wird auf `ACTIVE` gesetzt.
  - **Online-EEG:** je übergebenem Zählpunkt geht die EDA-Anmeldung (ECON) an den Netzbetreiber.
  - **Offline-EEG:** keine EDA-Nachricht; **alle** Zählpunkte des Mitglieds werden in der DB auf aktiv gesetzt.
  - Der Endpoint selbst verschickt **keine** E-Mail. Die Mails „Aktivierung im Serviceportal“ und
    „Dein Zählpunkt ist aktiv“ gehen erst raus, wenn die jeweilige EDA-Antwort eintrifft.
- **Response:** `201 Created` mit dem Mitglied. Fehler: `400` – Achtung, der Mitgliedsstatus kann
  dann bereits `ACTIVE` sein → per `GET` prüfen.

> ⏱️ **Asynchron:** Die `201` bestätigt nur den Versand. Die Aktivierung beim Netzbetreiber
> (`ABSCHLUSS_ECON`) dauert Tage bis Wochen und kann abgelehnt werden → [eda-processes.md](eda-processes.md).
>
> ⚠️ **Nicht für aktive Mitglieder verwenden** und **nicht zum Ändern des Teilnahmefaktors** –
> ein erneuter Aufruf schickt die Anmeldung noch einmal an EDA.

---

### `DELETE /api/participant/v2/{id}` — Mitglied endgültig löschen 📄

- **Auth:** Bearer, `EEG_ADMIN`.
- **Hartes Löschen**, kein Archivieren: der Datensatz wird entfernt, abhängige Daten
  (Zählpunkt-Zuordnungen, Adressen, Kontakt, Bankdaten) per Datenbank-Cascade mit.
  Es gibt keinen Undo und keine EDA-Abmeldung.
- Zum regulären Austritt stattdessen die Zählpunkte abmelden (`/api/meteringpoint/{pid}/revokemeters`)
  bzw. archivieren (`/api/meteringpoint/{pid}/archive/{mid}`).
- **Response:** `202 Accepted`, `{"id": "<id>"}`. Fehler: `400`.

---

### Nicht existierende Participant-Endpoints ❌

| Endpoint | Laut Code | In Tests beobachtet |
|---|---|---|
| `DELETE /api/participant/{id}` (ohne `v2`) | Route nur für `PUT` → `405` | – |
| `GET /api/participant/{id}` | Route nur für `PUT` → `405` | `404` |
| `GET /api/participants` (Plural) | existiert nicht | `404` |
| `POST /api/participant/list` | existiert nicht | `404` |
| `POST /api/auth/login`, `/api/login`, `/api/auth/token` | existiert nicht | `404` |
| `POST /energystore/query/{ecId}/participants` | existiert nicht | `404` |

---

## Metering-Point API (`/api/meteringpoint`) 📄

Alle Routen: Bearer, `EEG_ADMIN`. `{pid}` = Mitglieds-ID (UUID), `{mid}` = Zählpunktnummer (`AT…`).

| Methode | Pfad | Zweck | Body | Response |
|---|---|---|---|---|
| PUT | `/{pid}/create` | Zählpunkt zu bestehendem Mitglied hinzufügen | `MeteringPoint` (+ `activationMode`/`activationCode`) | `201` + Zählpunkt |
| POST | `/{pid}/register` | vorhandenen Zählpunkt bei EDA anmelden | `{"meteringPoint", "activationMode", "activationCode"}` | `201` + Mitglied |
| PUT | `/{pid}/update/{mid}` | Zählpunkt aktualisieren (ganzes Objekt) | `MeteringPoint` | `202` + gesendetes Objekt |
| PUT | `/v2/{pid}/update/{mid}` | ein Feld ändern | `{"path": "<spalte>", "value": …}` | `202` + Zählpunkt |
| PUT | `/v2/{pid}/updateid/{mid}` | Zählpunktnummer ändern | `{"newId": "AT…"}` | `202` + Zählpunkt |
| PUT | `/{pid}/update/{mid}/partfact` | Teilnahmefaktor **nur in der DB** setzen | `{"partFact": 50}` | `202` + Zählpunkt |
| POST | `/changepartitionfactor` | Teilnahmefaktor-Änderung **bei EDA beantragen** | siehe unten | `204` |
| PUT | `/{spid}/{dpid}/move/{mid}` | Zählpunkt von Mitglied `spid` zu `dpid` verschieben | `MeteringPoint` (wird zurückgegeben) | `202` |
| PUT | `/{pid}/archive/{mid}` | Zählpunkt archivieren | – | `202` `{"meteringpoint": …}` |
| DELETE | `/{pid}/remove/{mid}` | Zählpunkt entfernen (nur nie aktivierte) | – | `202` `{"meteringpoint": …}` |
| POST | `/{pid}/revokemeters` | Abmeldung bei EDA beantragen | siehe unten | `201` + Mitglied |
| POST | `/syncenergy` | Energiedaten bei EDA anfordern | siehe unten | `204` |

Fehler allgemein: `400` (Parse-/DB-Fehler), `500` (EDA-Versand fehlgeschlagen, leere Zählpunktliste bei `syncenergy`/`revokemeters`).

### `PUT /api/meteringpoint/{pid}/create`

- `processState` fehlt oder `NEW`: Ist das Mitglied bereits `ACTIVE` und die EEG online, wird der
  Zählpunkt sofort bei EDA angemeldet – dafür `activationMode` `ONLINE` oder `OFFLINE` mitsenden
  (sonst Fehler „Wrong activation code“).
- `registeredSince` wird auf heute gesetzt, außer `status` ist `ACTIVE`.

### `POST /api/meteringpoint/{pid}/register`

- Der Zählpunkt muss dem Mitglied bereits zugeordnet sein (sonst keine gültige Antwort).
- `activationMode` muss `ONLINE` oder `OFFLINE` sein, sonst `400` („Wrong activation code“).
- Bei einer Offline-EEG passiert nichts; die Antwort ist trotzdem `201`.

### `PUT /api/meteringpoint/{pid}/update/{mid}`

- Schreibt das **ganze** Objekt: nicht mitgesendete Felder (z. B. `tariff_id`, `equipmentName`,
  Adresse) werden geleert. Deshalb immer das zuvor gelesene, vollständige Objekt senden.
- `participantState` muss als Objekt enthalten sein (`{"activeSince": …, "inactiveSince": …}`).
- **Nicht** über diesen Weg änderbar: `meteringPoint`, `participantId`, `consentId`, `partFact`.
- `modifiedAt`/`modifiedBy` setzt der Server.

### `PUT /api/meteringpoint/v2/{pid}/update/{mid}`

`path` ist hier der **Spaltenname in der Datenbank**, nicht der JSON-Name – z. B. `equipmentName`,
`street`, `streetNumber`, `city`, `zip`, `tariff_id`, `inverterid`, `grid_operator_id`.
`modifiedAt`/`modifiedBy` setzt der Server. Antwort: `202` mit dem neu gelesenen Zählpunkt.

### `DELETE /api/meteringpoint/{pid}/remove/{mid}`

Entfernt nur Zählpunkte, die nie aktiviert wurden (`status` `INIT`, `processState` `NEW`/`PENDING`/`INVALID`).
Bei allen anderen antwortet der Endpoint trotzdem `202`, ohne etwas zu löschen.

### Teilnahmefaktor ändern (mit EDA-Prozess)

`POST /api/meteringpoint/changepartitionfactor` (Bearer) **oder** `POST /api/master/updatepartfact`
(Basic) – gleicher Body (Beispiel [examples/partfact-change.example.json](../examples/partfact-change.example.json)):

```json
{
  "meteringPoints": [
    {
      "meter": "AT0030000000000000000000000000000",
      "direction": "CONSUMPTION",
      "gridOperatorId": "AT003000",
      "activation": "2026-11-01",
      "partFact": 50
    }
  ]
}
```

| Feld | Typ | Beschreibung |
|---|---|---|
| `meter` | string | Zählpunktnummer – das Feld heißt **`meter`**, nicht `meteringPoint` |
| `direction` | `CONSUMPTION` \| `GENERATION` | |
| `gridOperatorId` | string, optional | Netzbetreiber-ID |
| `activation` | `YYYY-MM-DD` | Datum, ab dem der neue Faktor gelten soll |
| `partFact` | integer | Teilnahmefaktor in **Prozent** (z. B. `50`) |

- Löst je Netzbetreiber den EDA-Prozess `EC_PRTFACT_CHANGE` / `ANFORDERUNG_CPF` aus. Der neue Faktor
  steht erst nach `ANTWORT_CPF` des Netzbetreibers in eegfaktura. Netzbetreiber akzeptieren
  Anforderungen nur werktags zu Geschäftszeiten (sonst `ABLEHNUNG_CPF`, Code 82).
- Die EEG muss online sein, sonst `404`.
- **Response:** `changepartitionfactor` → `204`, `updatepartfact` → `201`. Leere Liste bei
  `updatepartfact` → `400`. EDA-Versandfehler → `500`.

### `POST /api/meteringpoint/{pid}/revokemeters`

```json
{
  "meteringPoints": [
    { "meter": "AT0030000000000000000000000000000", "direction": "CONSUMPTION", "consentId": "…" }
  ],
  "from": 1793491200000,
  "to": "Austritt aus der Gemeinschaft"
}
```

- `from`: Abmeldedatum als Unix-Millisekunden. `to`: **Freitext-Begründung** (optional) – das Feld heißt tatsächlich `to`.
- Nur aktive Zählpunkte werden abgemeldet; nur bei Online-EEG geht eine EDA-Nachricht raus.

### `POST /api/meteringpoint/syncenergy`

```json
{
  "meteringPoints": [ { "meter": "AT0030000000000000000000000000000", "direction": "CONSUMPTION" } ],
  "from": 1790812800000,
  "to": 1793491199000
}
```

Fordert Energiedaten beim Netzbetreiber an (EDA-Prozess PT), begrenzt auf den aktiven Zeitraum
des Zählpunkts. Nur bei Online-EEG. Die Daten landen asynchron im Energystore.

---

## Master API (`/api/master`, Basic Auth) 📄

Für Server-zu-Server-Aufrufe (`ProtectApi`, siehe [authentication.md](authentication.md#2-basic-authentication-protectapi-apimaster-energystorequery)).
Mit Basic Auth noch **nicht** selbst getestet.

### `GET /api/master/masterdata`

Stammdaten aller Mitglieder des Mandanten inkl. Zählpunkten.

**Response:** `200 OK`, Array von `MasterDataParticipant` → [data-model.md](data-model.md#masterdataparticipant--masterdatameter):

```json
[
  {
    "participantNumber": "0042",
    "firstname": "Max",
    "lastname": "Mustermann",
    "titleBefore": "",
    "titleAfter": "",
    "participantSince": "2025-01-01T00:00:00Z",
    "meters": [
      {
        "meteringPoint": "AT0030000000000000000000000000000",
        "consentId": "…",
        "transformer": "",
        "direction": "CONSUMPTION",
        "status": "ACTIVE",
        "equipmentNumber": "",
        "equipmentName": "",
        "inverterid": "",
        "registeredSince": "2025-01-01",
        "gridOperatorId": "AT003000",
        "gridOperatorName": "…",
        "processState": "",
        "partFact": 100,
        "activationMode": "",
        "allocationFactor": 0,
        "activeSince": "2025-02-01T00:00:00Z",
        "inactiveSince": "2999-12-31T00:00:00Z"
      }
    ],
    "status": "ACTIVE"
  }
]
```

- Leere Werte kommen als `""` bzw. `0`, nicht als `null`. `transformer`, `processState` und
  `activationMode` werden in dieser Antwort nicht befüllt.
- `participantSince`, `activeSince`, `inactiveSince` sind Zeitstempel (RFC 3339, Zeitzone des Servers);
  fehlt ein Datum, erscheint ein Platzhalter-Zeitstempel statt `null`.
- `partFact` ist eine ganze Prozentzahl.

### `POST /api/master/updatepartfact`

Teilnahmefaktor-Änderung bei EDA beantragen – Body und Verhalten wie
[`changepartitionfactor`](#teilnahmefaktor-ändern-mit-eda-prozess), Antwort `201`.

---

## Energystore API (`/energystore/query`, Basic Auth)

### `POST /energystore/query/{ecId}/metadata` — Zählpunkt-Metadaten ✅

Liefert verfügbare Datenzeiträume pro Zählpunkt.

**URL-Parameter:** `ecId` — Energy Community ID (z. B. `AT00300000000RC######...`).

**Body:** `{}`

```bash
curl -X POST "https://eegfaktura.at/energystore/query/{ecId}/metadata" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <BASE64>" \
  -H "X-Tenant: {tenant}" \
  -d '{}'
```

**Response:** `200 OK` — Map `meteringPoint → {periodBegin, periodEnd}` (Unix-ms). Fehler: `400`.

```json
{
  "AT0030000000000000000000000000000": {
    "periodBegin": 1733266800000,
    "periodEnd": 1764025200000
  }
}
```

> **Datenverfügbarkeit:** `periodBegin` entspricht i. d. R. dem **Aktivierungsdatum** des
> Zählpunkts beim Netzbetreiber — frühere Zeiträume existieren nicht und werden bei
> Nachforderungen abgelehnt. Netzbetreiber liefern außerdem verzögert: vollständige
> Monatsdaten sind erst **um den 5. des Folgemonats** zu erwarten.
> Hintergrund: [eda-processes.md](eda-processes.md).

---

### `POST /energystore/query/rawdata` — Energie-Rohdaten ✅

Liefert 15-Minuten-Rohdaten für Zählpunkte in einem absoluten Zeitfenster.

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
| `cps` | array | Zählpunkte (`{ meteringPoint }`); leer/fehlend → alle im Zeitraum aktiven Zählpunkte des Mandanten |
| `start` | number | **absoluter** Start-Timestamp in **Millisekunden** |
| `end` | number | **absoluter** End-Timestamp in **Millisekunden** |
| `format` | string, optional | `"csv"` liefert CSV statt JSON |

> ⚠️ `start`/`end` müssen **absolute** Unix-Millisekunden sein — keine relativen Werte.

**Response:** `200 OK`. Fehler: `400`.

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
Quelle: [Offizielle eegfaktura-Doku — Energiedaten herunterladen](https://docs.eegfaktura.at/books/workflowprozesse/page/energiedaten-herunterladen)
sowie [OBIS-Codes](https://eegfaktura.github.io/eegfaktura-docs/reference/obis-codes/).

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
> [`MeteringPoint`-Objekt](data-model.md) ist hier also schon eingerechnet.

**Abrechnungsrelevante Größen (GEA/EEG/BEG-Verrechnung)**

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
> vorläufig und müssen später **erneut abgerufen** werden.

**Normative Referenzen (österreichischer Marktstandard)**

- [ebutilities.at — Prozess 453](https://www.ebutilities.at/prozesse/453)
- [Informationsflüsse Energiegemeinschaften (PDF, 06/2023)](https://www.ebutilities.at/documents/2023/06/202306_Informationsfl%C3%BCsse_Energiegemeinschaften.pdf)
- [MeterCodes CR MSG (PDF, 12/2023)](https://www.ebutilities.at/documents/2023/12/13122023_MeterCodes_CR_MSG.pdf)
- [OBIS Metercodes VEZ VNB (PDF, 09/2022)](https://www.ebutilities.at/documents/20220928204643_20220927_OBIS_Metercodes_VEZ_VNB.pdf)

---

## Weitere Backend-Routen (Web-App-intern, hier nicht im Detail dokumentiert)

| Methode | Pfad | Auth |
|---|---|---|
| GET / POST | `/api/eeg` | Bearer (GET: Admin oder Mitglied, POST: Admin) |
| GET / POST | `/api/eeg/tariff`, GET / DELETE `/api/eeg/tariff/{id}` | Bearer, Admin |
| POST | `/api/eeg/sync/participants/{oid}` | Bearer, Admin |
| POST / GET | `/api/eeg/import/masterdata`, `/api/eeg/export/masterdata` (Excel) | Bearer, Admin |
| GET | `/api/eeg/notifications/{id}`, `/api/eeg/gridoperators`, `/api/eeg/user/get-user`, `/api/user/get-user` | Bearer, Admin |
| GET | `/api/process/history` | Bearer, Admin |
| POST | `/api/query` (GraphQL) | Bearer |

---

## Zusammenfassung Auth pro Endpoint

| Endpoint | Methode | Auth | Status |
|---|---|---|---|
| `/api/participant` | GET | Bearer (Admin: alle, Mitglied: eigene) | 📄 |
| `/api/participant` | POST | Bearer, Admin | 📄 |
| `/api/participant/{id}` | PUT | Bearer, Admin | 📄 |
| `/api/participant/v2/{id}` | PUT | Bearer, Admin | 📄 |
| `/api/participant/v2/{id}` | DELETE | Bearer, Admin | 📄 |
| `/api/participant/{id}/confirm` | POST | Bearer, Admin | 📄 |
| `/api/meteringpoint/…` | diverse | Bearer, Admin | 📄 |
| `/api/master/masterdata` | GET | Basic | 📄 |
| `/api/master/updatepartfact` | POST | Basic | 📄 |
| `/energystore/query/{ecId}/metadata` | POST | Basic | ✅ |
| `/energystore/query/rawdata` | POST | Basic | ✅ |
