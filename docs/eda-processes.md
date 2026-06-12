# EDA-Prozesse (Ponton-Schnittstelle)

Hintergrundwissen für Integratoren: Hinter mehreren API-Operationen steckt der
österreichische **energiewirtschaftliche Datenaustausch (EDA)** mit den Netzbetreibern,
abgewickelt über die **Ponton-Schnittstelle**. Diese Prozesse sind **asynchron** —
die API-Antwort (`201`/`202`) bestätigt nur die Annahme, nicht den Abschluss beim
Netzbetreiber.

Quelle: [Offizielles eegfaktura-Handbuch — Prozess-History](https://docs.eegfaktura.at/books/workflowprozesse/page/prozess-history)
sowie [ebutilities.at — Prozess 453](https://www.ebutilities.at/prozesse/453).

---

## Nachrichtentypen

| Typ | Prozess | Bezug zur API |
|---|---|---|
| **ECON** | Online-Anmeldung Teilnahme (`ANFORDERUNG` → `ABLEHNUNG`/`ANTWORT` → `ZUSTIMMUNG` → `ABSCHLUSS`) | Wird durch `POST /api/participant/{id}/confirm` angestoßen („EBMS-Nachrichten") |
| **CCMS** | Widerruf der Datenfreigabe (Consent-Management) | Zählpunkt-Abmeldung |
| **PT** | Anforderung von Energiedaten beim Netzbetreiber | Befüllt den Energystore (Quelle für `/energystore/query/...`) |
| **CPF** | Änderung des Teilnahmefaktors | `partFact` am `Meter`-Objekt |
| **CRMSG** | Übermittlung der Energiedaten durch den Netzbetreiber | Eingehende Rohdaten |

---

## Lebenszyklus einer Teilnehmer-Aktivierung

1. `POST /api/participant` → Teilnehmer angelegt (`status: PENDING`).
2. `POST /api/participant/{id}/confirm` → eegfaktura sendet **ECON-ANFORDERUNG** an den Netzbetreiber.
3. Der Netzbetreiber bestätigt (ggf. nach Smart-Meter-Installation) → **ABSCHLUSS_ECON**.
4. Erst dann ist der Zählpunkt wirklich aktiv und es fließen Energiedaten.

> ⏱️ **Timing:** Die Netzbetreiber-Aktivierung kann laut offizieller Doku
> **Tage bis Wochen** dauern (abhängig u. a. von der Smart-Meter-Verfügbarkeit).
> Eine Integration sollte den Teilnehmer-/Zählpunktstatus pollen statt auf
> sofortige Aktivierung zu bauen.

---

## Dokumentierte Ablehnungsgründe (Netzbetreiber)

Aus der Prozess-History bekannte Rejection-Ursachen:

- „Zählpunkt befindet sich nicht im Bereich der Energiegemeinschaft"
- Konkurrierender Prozess für den Zählpunkt bereits aktiv
- „Zählpunkt nicht versorgt"
- **Teilnahmefaktor über 100 %** (Summe über alle Gemeinschaften des Zählpunkts)
- Kein Smart Meter vorhanden (Installation erforderlich)

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

## Was es NICHT über die API gibt

| Funktion | Verfügbarkeit |
|---|---|
| Bulk-Import von Mitgliedern/Zählpunkten | ❌ nur Excel-Vorlage im Web-UI |
| Stammdaten-Export (EEG/Mitglieder/Zählpunkte) | ❌ nur XLSX-Download im Web-UI |
| Tarif-Verwaltung | ❌ nur Web-UI |
| Abrechnung auslösen | ❌ nur Web-UI (ganze EEG, einmal pro Periode, danach unveränderlich) |

→ **`POST /api/participant` ist der einzige dokumentierte programmatische Weg,
Mitglieder anzulegen.** Wer viele Mitglieder migrieren will, hat die Wahl:
API-Schleife über `POST /api/participant` oder die offizielle Excel-Import-Vorlage
(alle Zellen als „Text" formatieren; bereits erfasste Zählpunkte brechen den Import ab).
