# Datenmodell

Abgeleitet aus dem Backend-Quellcode (`model/participant.go`, `model/Eeg.go`,
Datenbankschema `schema.sql`; Commit `f4974b2`, 26.09.2026).
Diese Strukturen werden in `POST /api/participant`, `PUT /api/participant/{id}`,
`GET /api/participant` und den `/api/meteringpoint`-Routen verwendet.

Datumsformat: `YYYY-MM-DD`. Spalte **Pflicht** = für `POST /api/participant` nötig;
**Server** = wird vom Server gesetzt bzw. beim Anlegen ignoriert.

---

## `Participant`

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `id` | string (UUID) | Server | beim Anlegen neu vergeben; bei `PUT /api/participant/{id}` **Pflicht im Body** |
| `participantNumber` | string \| null | – | Mitgliedsnummer – wird **nicht** generiert, sondern übernommen |
| `businessRole` | enum | – | `EEG_PRIVATE` (Default) \| `EEG_BUSINESS` |
| `role` | enum | – | `EEG_USER` (Default) \| `EEG_ADMIN` |
| `firstname` | string | ✅ | Vorname bzw. Firmenname |
| `lastname` | string | – | Nachname (bei Privatpersonen angeben, bei `EEG_BUSINESS` leer) |
| `titleBefore` | string \| null | – | Titel vorangestellt |
| `titleAfter` | string \| null | – | Titel nachgestellt |
| `participantSince` | string (Datum) \| null | – | Beitrittsdatum; fehlt es, gilt das heutige Datum |
| `vatNumber` | string \| null | – | UID-Nummer |
| `taxNumber` | string \| null | – | Steuernummer |
| `companyRegisterNumber` | string \| null | – | Firmenbuchnummer |
| `meters` | `MeteringPoint[]` | – | Zählpunkte (siehe unten); ohne Zählpunkte später per `PUT /api/meteringpoint/{pid}/create`. Wird bei `PUT /api/participant/{id}` **ignoriert** |
| `tariffId` | string (UUID) \| null | – | Tarif; wird beim Anlegen **nicht** gespeichert, nur per `PUT` |
| `status` | enum | Server | beim Anlegen immer `PENDING`, nach `confirm` `ACTIVE`; weitere Werte siehe unten |
| `version` | integer | – | |
| `createdBy` | string | Server | Benutzer aus dem Token |
| `contact` | object | ✅ | `{ phone?, email? }` |
| `billingAddress` | `Address` | ✅ | `type` = `BILLING` |
| `residentAddress` | `Address` | ✅ | `type` = `RESIDENCE` |
| `accountInfo` | object | ✅ | Bankverbindung (siehe unten) |

`status` (Mitglied) nutzt den gemeinsamen Prozessstatus: `NEW`, `PENDING`, `ACTIVE`, `INACTIVE`,
`APPROVED`, `REJECTED`, `REVOKED`, `INVALID`, `ARCHIVED`, … (siehe `ProcessStatusType` im Code).

### `contact`
| Feld | Typ | Pflicht | Hinweis |
|---|---|---|---|
| `phone` | string \| null | – | |
| `email` | string \| null | – | Wird normalisiert und geprüft; mehrere Adressen mit `;` trennen. Ungültig → `400`. Wird für die Mitglieder-Anmeldung und die Aktivierungs-Mails gebraucht. |

### `Address` (`billingAddress` / `residentAddress`)
| Feld | Typ | Pflicht | Hinweis |
|---|---|---|---|
| `type` | enum | ✅ | `BILLING` bzw. `RESIDENCE` – beim Anlegen unbedingt setzen |
| `street` | string \| null | – | |
| `streetNumber` | string \| null | – | |
| `zip` | string \| null | – | |
| `city` | string \| null | – | |

### `accountInfo`
| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `iban` | string \| null | – | IBAN |
| `owner` | string \| null | – | Kontoinhaber |
| `bankName` | string \| null | – | |
| `mandateReference` | string \| null | – | SEPA-Mandatsreferenz |
| `mandateDate` | string (Datum) \| null | – | SEPA-Mandatsdatum |
| `sepaDirectDebit` | string \| null | – | `CORE` \| `B2B` |

---

## `MeteringPoint` (Zählpunkt, im Feld `meters`)

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `meteringPoint` | string | ✅ | Zählpunktnummer (33-stellig, `AT…`) |
| `participantId` | string (UUID) | Server | zugehöriges Mitglied (nur Response) |
| `consentId` | string \| null | Server | Zustimmungs-ID aus dem EDA-Prozess |
| `transformer` | string \| null | – | |
| `direction` | enum | ✅ | `CONSUMPTION` \| `GENERATION` |
| `status` | enum | Server | `INIT` \| `ACTIVE` \| `INACTIVE` – wird aus `processState` abgeleitet |
| `statusCode` | integer \| null | Server | letzter EDA-Antwortcode |
| `tariff_id` | string (UUID) \| null | – | Tarif-ID (**snake_case!**). Muss eine gültige UUID sein, sonst schlägt das Speichern fehl |
| `equipmentNumber` | string \| null | – | |
| `equipmentName` | string \| null | – | |
| `inverterid` | string \| null | – | Wechselrichter-ID (**klein geschrieben!**) |
| `street` | string \| null | – | |
| `streetNumber` | string \| null | – | |
| `city` | string \| null | – | |
| `zip` | string \| null | – | |
| `registeredSince` | string (Datum) | – | fehlt es, gilt das heutige Datum |
| `modifiedAt` | string (Datum/Uhrzeit) | Server | |
| `modifiedBy` | string | Server | |
| `gridOperatorId` | string \| null | – | Netzbetreiber-ID |
| `gridOperatorName` | string \| null | – | Netzbetreiber-Name |
| `processState` | enum | – | fehlt → `NEW`. Werte: `NEW`, `INIT`, `PENDING`, `APPROVED`, `ACTIVE`, `INACTIVE`, `REJECTED`, `REVOKED`, `INVALID`, `ARCHIVED`, `ABORTED`, `RESTORE`, `WARN` |
| `participantState` | object | – | `{ activeSince, inactiveSince }` (Datum \| null). Bei `PUT /api/meteringpoint/{pid}/update/{mid}` **Pflicht** |
| `partFact` | integer | ✅ | Teilnahmefaktor in **Prozent** (`100` = voller Anteil). **Fehlt er, wird `0` gespeichert.** |
| `activationMode` | enum | – | nur für Anmeldung: `ONLINE` \| `OFFLINE` |
| `activationCode` | string | – | nur für Offline-Anmeldung |
| `allocationFactor` | number \| null | – | |

> **Achtung Naming:** Auf Mitgliedsebene heißt das Tarif-Feld `tariffId` (camelCase),
> auf Zählpunktebene `tariff_id` (snake_case); `inverterid` ist komplett klein geschrieben.
> So steht es im Backend – nicht „korrigieren“.

> **`status` vs. `processState`:** `processState` beschreibt den EDA-Prozessstand, `status`
> den Datenbankzustand (`INIT` = nie aktiviert, `ACTIVE`, `INACTIVE`). Die Spalte
> „Zählpunktstatus“ der Excel-Import-Vorlage (`ACTIVATED`, `REGISTERED` …) gilt nur für den
> Excel-Import, nicht für die API.

---

## Request-Modelle

### Bestätigung (`POST /api/participant/{id}/confirm`) – JSON-Array

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `meteringPoint` | string | ✅ | muss dem Mitglied zugeordnet sein |
| `activationMode` | enum | ✅ | `ONLINE` \| `OFFLINE` (alles außer `ONLINE` gilt als Offline) |
| `activationCode` | string | – | für Offline-Anmeldung |
| `registeredSince` | string (Datum) | – | gewünschtes Anmeldedatum |

### Teilnahmefaktor-Änderung (`POST /api/meteringpoint/changepartitionfactor`, `POST /api/master/updatepartfact`)

`{ "meteringPoints": [ PartFactChange ] }`

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `meter` | string | ✅ | Zählpunktnummer (heißt hier `meter`!) |
| `direction` | enum | ✅ | `CONSUMPTION` \| `GENERATION` |
| `gridOperatorId` | string | – | |
| `activation` | string (Datum) | ✅ | gültig ab |
| `partFact` | integer | ✅ | Prozent |

### Einzelfeld-Änderung (`PUT /api/participant/v2/{id}`, `PUT /api/meteringpoint/v2/{pid}/update/{mid}`)

`{ "path": "<feld>", "value": <wert> }` – Details in [endpoints.md](endpoints.md).

---

## `MasterDataParticipant` / `MasterDataMeter`

Antwort von `GET /api/master/masterdata` – reduzierte, flache Sicht ohne `null`:

- **Mitglied:** `participantNumber`, `firstname`, `lastname`, `titleBefore`, `titleAfter`,
  `participantSince` (Zeitstempel), `status`, `meters`.
- **Zählpunkt:** `meteringPoint`, `consentId`, `transformer`, `direction`, `status`,
  `equipmentNumber`, `equipmentName`, `inverterid`, `registeredSince` (Datum), `gridOperatorId`,
  `gridOperatorName`, `processState`, `partFact` (Prozent), `activationMode`, `allocationFactor`,
  `activeSince`, `inactiveSince` (Zeitstempel).

---

## Praxis-Hinweise

- **`partFact` ist eine ganze Prozentzahl** (0–100), kein Bruch. `1` bedeutet 1 %.
- **UUID-Felder** (`id`, `tariffId`, `tariff_id`) entweder weglassen, `null` oder als gültige UUID
  senden. Leere Strings oder Platzhalter führen zu `invalid input syntax for type uuid`.
- **Leere Strings entfernen:** Beim `PUT /api/participant/{id}` werden leere Felder ohnehin übersprungen;
  in UUID- und Datumsfeldern verursachen `""` aber Fehler.
- **`partFact` in Energiedaten nicht doppelt anwenden:** Die Rohdaten aus
  `/energystore/query/rawdata` sind bei den `…T`-OBIS-Codes (G.01T, P.01T) **bereits
  nach Teilnahmefaktor reduziert** → [endpoints.md → Value mapping](endpoints.md).
