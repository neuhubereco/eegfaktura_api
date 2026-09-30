# Known Issues, Stolperfallen & offene Fragen

Stand: 30.09.2026. Frühere Fassungen dieser Doku beruhten auf Integrationstests und der
DeepWiki-Zusammenfassung; einige Annahmen daraus haben sich beim Abgleich mit dem Quellcode
als falsch erwiesen. Diese Datei hält fest, was **nicht** funktioniert – damit der nächste
Entwickler nicht dieselben Sackgassen durchläuft.

---

## 1. Basic Auth funktioniert nicht für `/api/participant` – auch nicht für `POST`

**Frühere Annahme:** `POST /api/participant` funktioniert mit Basic Auth, nur `GET` braucht Bearer.

**Laut Code:** Alle Routen unter `/api/participant` und `/api/meteringpoint` laufen über die
Bearer-Middleware (`Protect` bzw. `ConditionProtect` in `api/middleware/tokenVerifier.go`).
Ein `Authorization: Basic …`-Header wird dort mit `403` abgelehnt. Basic Auth (`ProtectApi`) gibt es
nur für `/api/master/…` und `/energystore/query/…` → [authentication.md](authentication.md).

**Beobachtet:** `GET /api/participant` mit Basic Auth lieferte in unseren Tests `400` ohne Body.
Das aktuelle Backend antwortet in diesem Fall mit `403`; der Unterschied kommt vermutlich aus einer
älteren Backend-Version oder dem Ingress. In beiden Fällen gilt: Bearer verwenden.

**Query-Parameter:** `GET /api/participant` wertet keine Parameter aus (`?id=`, `?email=`,
`?participantNumber=` …). Ein Einzelabruf per ID existiert nicht.

---

## 2. Kein Machine-to-Machine-Zugang für die Participant-API

Es gibt **keinen** `username/password`→JWT-Endpoint unter `/api/…`:

| Versuch | Ergebnis |
|---|---|
| `POST /api/auth/login` | 404 |
| `POST /api/login` | 404 |
| `POST /api/auth/token` | 404 |
| `GET /api/auth` | 404 |
| Selbst signierte JWTs | 401 Unauthorized |

**Konsequenz:** Bearer-Tokens kommen aus dem Keycloak-OIDC-Flow der offiziellen Web-App
(Realm `EEGFaktura`, Client `at.ourproject.vfeeg.app`); eine Integration hält sie per
`grant_type=refresh_token` am Leben. Der Benutzer muss in der Gruppe `EEG_ADMIN` sein.

**Offen:** Ein Service-Account-/Client-Credentials-Flow bzw. ein `ProtectApi`-Pendant für
Participant-Schreibzugriffe fehlt →
[eegfaktura/eegfaktura-backend#9](https://github.com/eegfaktura/eegfaktura-backend/issues/9).
Die Basic-Routen (`/api/master`, `/energystore/query`) brauchen serverseitig einen Keycloak-Client
mit „Direct Access Grants“; ob das auf eegfaktura.at für jeden Benutzer freigeschaltet ist,
entscheidet der Betreiber.

---

## 3. `PUT /api/participant/{id}`: ID aus dem Body, Zählpunkte werden ignoriert

- Die ID im Pfad wird **nicht** ausgewertet; maßgeblich ist `id` im Body. Fehlt sie →
  `400` mit `pq: invalid input syntax for type uuid: ""` (Ursache früherer Update-Fehlschläge).
- `meters` wird **nicht** geschrieben – trotzdem kommt `202`. Zählpunkte ändert man über
  `/api/meteringpoint/…`, den Teilnahmefaktor über `changepartitionfactor`.
- `202` kommt mit dem gesendeten Body zurück, auch wenn nichts gespeichert wurde → per `GET` prüfen.

---

## 4. Löschen ist endgültig, Archivieren von Mitgliedern gibt es nicht

- `DELETE /api/participant/{id}` existiert **nicht**. Es gibt nur `DELETE /api/participant/v2/{id}`,
  und das ist ein **hartes Löschen** inkl. Zählpunkt-Zuordnungen, Adressen, Kontakt- und Bankdaten.
- Für einen regulären Austritt die Zählpunkte abmelden (`/api/meteringpoint/{pid}/revokemeters`)
  bzw. archivieren (`/api/meteringpoint/{pid}/archive/{mid}`).

---

## 5. `confirm` ist nur für die Erstanmeldung

- Body ist ein JSON-**Array** von Zählpunkten mit `activationMode` (`ONLINE`/`OFFLINE`) –
  ohne Body oder mit Objekt → `400`. Fehlt `activationMode`, wird offline angemeldet.
- Ein zweiter Aufruf für ein aktives Mitglied schickt die EDA-Anmeldung erneut. Für
  Teilnahmefaktor-Änderungen ist `confirm` der falsche Weg.
- Der Endpoint verschickt selbst keine E-Mail; die Mails kommen mit den EDA-Antworten.

---

## 6. Feldtypen, die leicht falsch gesetzt werden

- `partFact` ist eine **ganze Prozentzahl** (`100` = voll). `1` bedeutet 1 %. Fehlt `partFact`
  beim Anlegen eines Zählpunkts, wird `0` gespeichert.
- `tariffId`/`tariff_id` sind UUIDs; Platzhalter-Strings lassen das Speichern scheitern.
- `participantNumber` wird nicht vom Server vergeben.
- Beim Anlegen werden `status` (Mitglied), `tariffId` (Mitglied) sowie `status`/`modifiedAt`
  (Zählpunkt) vom Server gesetzt bzw. ignoriert.

→ [data-model.md](data-model.md)

---

## 7. Energystore: Sonderzeichen in Basic-Zugangsdaten

Der Energystore dekodiert Basic-Zugangsdaten mit URL-sicherem Base64 und trennt an jedem `:`.
Passwörter mit `:` oder Zugangsdaten, deren Base64-Form `+`/`/` enthält, scheitern dort mit `403`.
Abhilfe: Passwort ohne diese Zeichen wählen.

---

## 8. Empfohlene Integrationsstrategie

1. **Mitglieder anlegen/ändern/bestätigen** mit Bearer-Token eines `EEG_ADMIN`-Benutzers
   (Refresh-Token-Kette mit Keepalive).
2. Beim Anlegen die zurückgegebene `id` **lokal persistieren**; `participantNumber` selbst vergeben.
3. Nach `PUT`/`confirm` den Zustand per `GET /api/participant` verifizieren.
4. **Energiedaten** per Basic Auth aus dem Energystore; Stammdaten für Abrechnung/Abgleich
   optional per `GET /api/master/masterdata`.

---

## 9. Noch nicht verifiziert

Aus dem Code abgeleitet, aber noch nicht live getestet:

- alle Bearer-Routen unter `/api/participant` und `/api/meteringpoint` (Erfolgspfad)
- `GET /api/master/masterdata` und `POST /api/master/updatepartfact` mit Basic Auth

Wer diese verifiziert: bitte Ergebnis hier ergänzen.

---

## Referenzen

- Backend: <https://github.com/eegfaktura/eegfaktura-backend> – `api/participantController.go`,
  `api/meteringPointController.go`, `api/apiController.go`, `api/middleware/tokenVerifier.go`,
  `database/participantDao.go`, `model/participant.go`
- Energystore: <https://github.com/eegfaktura/eegfaktura-energystore> – `rest/energy.go`,
  `middleware/api_authentication.go`
- Offizielle Doku: <https://eegfaktura.github.io/eegfaktura-docs/> (`architecture/auth`, `services/backend`)
