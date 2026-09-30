# EDA-Prozesse (Ponton-Schnittstelle)

Hintergrundwissen für Integratoren: Hinter mehreren API-Operationen steckt der
österreichische **energiewirtschaftliche Datenaustausch (EDA)** mit den Netzbetreibern,
abgewickelt über die **Ponton-Schnittstelle**. Diese Prozesse sind **asynchron** —
die API-Antwort (`201`/`202`/`204`) bestätigt nur den Versand, nicht den Abschluss beim
Netzbetreiber. EDA-Nachrichten gehen nur für **Online-EEGs** raus.

Quelle: [Offizielles eegfaktura-Handbuch — Prozess-History](https://docs.eegfaktura.at/books/workflowprozesse/page/prozess-history),
[offizielle Entwickler-Doku — services/backend](https://eegfaktura.github.io/eegfaktura-docs/services/backend/)
sowie [ebutilities.at — Prozess 453](https://www.ebutilities.at/prozesse/453).

---

## Nachrichtentypen

| Typ | Prozess | Bezug zur API |
|---|---|---|
| **ECON** | Online-/Offline-Anmeldung Teilnahme (`ANFORDERUNG` → `ANTWORT` → `ZUSTIMMUNG`/`ABLEHNUNG` → `ABSCHLUSS`) | `POST /api/participant/{id}/confirm`, `POST /api/meteringpoint/{pid}/register`, `PUT /api/meteringpoint/{pid}/create` |
| **CCMS** | Widerruf der Datenfreigabe (Consent-Management) | `POST /api/meteringpoint/{pid}/revokemeters` |
| **PT** | Anforderung von Energiedaten beim Netzbetreiber | `POST /api/meteringpoint/syncenergy`; befüllt den Energystore (Quelle für `/energystore/query/...`) |
| **CPF** | Änderung des Teilnahmefaktors (`EC_PRTFACT_CHANGE`: `ANFORDERUNG_CPF` → `ANTWORT_CPF`/`ABLEHNUNG_CPF`) | `POST /api/meteringpoint/changepartitionfactor`, `POST /api/master/updatepartfact` |
| **CRMSG** | Übermittlung der Energiedaten durch den Netzbetreiber | Eingehende Rohdaten |

---

## Lebenszyklus einer Teilnehmer-Aktivierung

1. `POST /api/participant` → Mitglied angelegt (`status: PENDING`, Zählpunkte `processState: NEW`).
2. `POST /api/participant/{id}/confirm` mit den Zählpunkten → Mitglied `ACTIVE`; eegfaktura sendet
   je Zählpunkt die **ECON-ANFORDERUNG** an den Netzbetreiber.
3. Antwort des Netzbetreibers (`ANTWORT`) → Zählpunkt `PENDING`; das Mitglied erhält die Mail
   „Aktivierung im Serviceportal“ (Zustimmung im Netzbetreiber-Portal).
4. Zustimmung → `APPROVED`; Abschluss (`ABSCHLUSS_ECON`) → Zählpunkt `ACTIVE`, Mail
   „Dein Zählpunkt ist aktiv“. Erst dann fließen Energiedaten.

> ⏱️ **Timing:** Die Netzbetreiber-Aktivierung kann laut offizieller Doku
> **Tage bis Wochen** dauern (abhängig u. a. von der Smart-Meter-Verfügbarkeit).
> Eine Integration sollte den Mitglieds-/Zählpunktstatus per `GET /api/participant` pollen
> statt auf sofortige Aktivierung zu bauen.

---

## Dokumentierte Ablehnungsgründe (Netzbetreiber)

Aus der Prozess-History bekannte Rejection-Ursachen:

- „Zählpunkt befindet sich nicht im Bereich der Energiegemeinschaft"
- Konkurrierender Prozess für den Zählpunkt bereits aktiv
- „Zählpunkt nicht versorgt"
- **Teilnahmefaktor über 100 %** (Summe über alle Gemeinschaften des Zählpunkts)
- Kein Smart Meter vorhanden (Code 90)
- Prozessdatum falsch (Code 82) – Anforderung außerhalb Mo–Fr 09:00–17:00 bzw. falsches
  Aktivierungsdatum; betrifft v. a. Teilnahmefaktor-Änderungen

---

## Konsequenzen für die Energiedaten-Verfügbarkeit

- Energiedaten existieren erst **ab dem Aktivierungsdatum** des Zählpunkts —
  Anforderungen mit früherem Startdatum lehnt der Netzbetreiber ab.
  Das `periodBegin` aus [`POST /energystore/query/{ecId}/metadata`](endpoints.md)
  spiegelt genau das wider.
- Bei mehrfach aktivierten/deaktivierten Zählpunkten zählt das **erste**
  Aktivierungsdatum (sonst Filterfehler bei der Datenkontrolle).
- Netzbetreiber liefern verzögert: vollständige Monatsdaten sind laut offizieller
  Praxis erst **um den 5. des Folgemonats** zu erwarten. Eine Sync-Pipeline sollte
  davor gelieferte Werte als potenziell unvollständig behandeln
  (siehe QoV-Regeln in [endpoints.md](endpoints.md): nur L1/L2 abrechnen, L3 re-fetchen).

---

## Was es NICHT (bzw. nur eingeschränkt) über die API gibt

| Funktion | Verfügbarkeit |
|---|---|
| Bulk-Import von Mitgliedern/Zählpunkten | nur über die Excel-Vorlage (Web-UI; technisch `POST /api/eeg/import/masterdata`, Multipart, Bearer) |
| Stammdaten-Export | XLSX-Download im Web-UI (`GET /api/eeg/export/masterdata`, Bearer) oder JSON per `GET /api/master/masterdata` (Basic) |
| Tarif-Verwaltung | Web-UI (`/api/eeg/tariff`, Bearer) – hier nicht dokumentiert |
| Abrechnung auslösen | ❌ nur Web-UI (ganze EEG, einmal pro Periode, danach unveränderlich) |

→ **`POST /api/participant` ist der einzige Weg, einzelne Mitglieder programmatisch anzulegen.**
Wer viele Mitglieder migrieren will, hat die Wahl: API-Schleife über `POST /api/participant`
oder die offizielle Excel-Import-Vorlage (alle Zellen als „Text" formatieren; bereits erfasste
Zählpunkte brechen den Import ab).
