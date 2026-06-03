# Datenmodell

Abgeleitet aus dem TypeScript-Client der Referenzimplementierung
(`src/lib/eeg-faktura-participant.ts` im Repo `eegfakturareport`).
Diese Strukturen werden im Body von `POST /api/participant` und
`PUT /api/participant/{id}` verwendet.

---

## `Participant`

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `id` | string (UUID) | nur Response | Vom Server generiert |
| `participantNumber` | string | nur Response | Mitgliedsnummer, vom Server generiert |
| `businessRole` | enum | ✅ | `EEG_PRIVATE` \| `EEG_BUSINESS` |
| `role` | enum | ✅ | `EEG_USER` \| `EEG_ADMIN` |
| `firstname` | string | ✅ | Vorname |
| `lastname` | string | ✅ | Nachname |
| `titleBefore` | string | – | Titel vorangestellt |
| `titleAfter` | string | – | Titel nachgestellt |
| `participantSince` | string (ISO-Datum) | ✅ | Beitrittsdatum |
| `vatNumber` | string | – | UID-Nummer |
| `taxNumber` | string | – | Steuernummer |
| `companyRegisterNumber` | string \| null | – | Firmenbuchnummer |
| `meters` | `Meter[]` | ✅ | Zählpunkte (siehe unten) |
| `tariffId` | string | – | Tarif-ID |
| `status` | enum | ✅ | `PENDING` \| `ACTIVE` \| `INACTIVE` |
| `version` | number | – | Optimistic-Locking-Version |
| `createdBy` | string | – | Ersteller |
| `contact` | object | ✅ | `{ phone?, email }` |
| `billingAddress` | object | ✅ | Rechnungsadresse (siehe unten) |
| `residentAddress` | object | ✅ | Wohnadresse (siehe unten) |
| `accountInfo` | object | ✅ | Bankverbindung (siehe unten) |

### `contact`
| Feld | Typ | Pflicht |
|---|---|---|
| `phone` | string | – |
| `email` | string | ✅ |

### `billingAddress` / `residentAddress`
| Feld | Typ | Pflicht | Hinweis |
|---|---|---|---|
| `type` | enum | ✅ | `BILLING` bzw. `RESIDENCE` |
| `street` | string | ✅ | |
| `streetNumber` | string | ✅ | |
| `zip` | string | ✅ | |
| `city` | string | ✅ | |

### `accountInfo`
| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `iban` | string | – | IBAN |
| `owner` | string | – | Kontoinhaber |
| `bankName` | string \| null | – | |
| `mandateReference` | string | – | SEPA-Mandatsreferenz |
| `mandateDate` | string \| null | – | SEPA-Mandatsdatum |
| `sepaDirectDebit` | enum | ✅ | `CORE` \| `B2B` |

---

## `Meter` (Zählpunkt)

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `meteringPoint` | string | ✅ | Zählpunkt-ID (33-stellig, `AT...`) |
| `consentId` | string \| null | – | Zustimmungs-ID |
| `transformer` | string \| null | – | |
| `direction` | enum | ✅ | `CONSUMPTION` \| `GENERATION` |
| `status` | enum | ✅ | `INIT` \| `NEW` \| `ACTIVE` \| `ACTIVATED` \| `REGISTERED` |
| `statusCode` | string \| null | – | |
| `tariff_id` | string | ✅ | Tarif-ID (Snake-Case!) |
| `equipmentNumber` | string \| null | – | |
| `equipmentName` | string \| null | – | |
| `inverterid` | string \| null | – | Wechselrichter-ID |
| `street` | string | – | |
| `streetNumber` | string | – | |
| `city` | string | – | |
| `zip` | string | – | |
| `registeredSince` | string (ISO-Datum) | ✅ | |
| `modifiedAt` | string (ISO-Datum) | ✅ | |
| `modifiedBy` | string | – | |
| `gridOperatorId` | string | – | Netzbetreiber-ID |
| `gridOperatorName` | string | – | Netzbetreiber-Name |
| `processState` | enum | ✅ | `NEW` \| `ACTIVE` \| `INACTIVE` |
| `participantState` | object | ✅ | `{ activeSince?, inactiveSince? }` |
| `partFact` | number | ✅ | Aufteilungsfaktor |
| `activationMode` | string | – | |
| `allocationFactor` | number \| null | – | |

> **Achtung Naming:** Auf Participant-Ebene heißt das Tarif-Feld `tariffId` (camelCase),
> auf Meter-Ebene `tariff_id` (snake_case). Beide Schreibweisen sind so im echten Client
> vorhanden — nicht „korrigieren".

---

## Praxis-Hinweise

- **Leere Strings entfernen:** Vor `PUT`/`POST` alle `""`-Werte aus dem Objekt entfernen
  (rekursiv). Leere Strings in UUID-Feldern verursachen serverseitige Parse-Fehler.
- **`null` ist erlaubt** und sollte nicht pauschal entfernt werden.
- **Datumsfelder** als ISO-Strings (`YYYY-MM-DD` bzw. ISO-8601).
