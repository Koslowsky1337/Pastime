# Pastime 2.0 – Mehrspieler (Definition)

Stand: bestätigt am 15.11. Die Sitzungslogik (`Multiplayer.lua`) ist gebaut und getestet, die Oberfläche noch nicht.
(Sie kommt nicht ins Addon-Zip: `.pkgmeta` lässt `*.md` weg.)

## 1. Grundsätze

- **Nichts Sichtbares im Chat.** Alles läuft über Addon-Nachrichten. Kein Spieler sieht davon etwas in einem Chatfenster.
- **Immer zwei Spieler.** Jede Partie ist ein Duell.
- **Nichts passiert ohne Zustimmung.** Eine Anfrage muss bestätigt werden. Im Kampf kommt keine Anfrage an.
- **Jeder rechnet selbst.** Beide Seiten führen das Spiel nach denselben Regeln; gesendet werden nur Züge.
- **Nur gültige Züge.** Das eigene Fenster lässt einen ungültigen Zug gar nicht zu: Man bleibt am Zug, bis man etwas Erlaubtes tut. Kommt trotzdem ein ungültiger Zug vom Gegner an, wird er nicht ausgeführt, und der Gegner bleibt am Zug.
- **Fremde Nachrichten gelten als nicht vertrauenswürdig.** Feste Nachrichtentypen, feste Felder, Mengenbremse (steht in `Comm.lua` schon bereit).

## 2. Wer wen sieht

Jeder bestimmt selbst, wo er als Mitspieler erscheint:

| Kreis | Standard | Wie man sich findet |
|---|---|---|
| Gruppe und Schlachtzug | an | Meldung im Gruppenkanal |
| Freunde | an | unsichtbare Nachfrage an Freunde, die gerade online sind |
| Gilde | aus | Meldung im Gildenkanal |

Wer einen Kreis abschaltet, erscheint dort bei niemandem und sieht dort auch niemanden. Spieler auf der Ignorierliste werden nie angezeigt und können nichts schicken.

## 3. Was gesendet wird

| Nachricht | Weg | Inhalt | Wann |
|---|---|---|---|
| `HELLO` | Gilden-, Gruppen-, Schlachtzugskanal; an Freunde einzeln | Versionsnummer, Mehrspieler-Stufe | Einloggen, Gruppenbeitritt, selten als Wiederholung |
| `INVITE` | an den Mitspieler | Sitzungsnummer | Klick auf „Anfragen“ |
| `ACCEPT` / `DECLINE` | an den Mitspieler | Sitzungsnummer | Antwort des Eingeladenen |
| `START` | an den Mitspieler | Sitzungsnummer, Spiel, Startwert | Der Einladende hat ein Spiel gewählt |
| `MOVE` | an den Mitspieler | Sitzungsnummer, laufende Nummer, Zug | Jeder Zug |
| `RESULT` | an den Mitspieler | Sitzungsnummer, Ergebnis aus eigener Sicht | Spielende, zur Gegenprobe |
| `PAUSE` | an den Mitspieler | Sitzungsnummer | Anhalten (Fenster zu, zehn Minuten ohne Zug) |
| `BYE` | an den Mitspieler | Sitzungsnummer | Aufgeben oder Abbruch vor Spielbeginn |
| `RESUME` / `REPLAY` | an den Mitspieler | Sitzungsnummer, bisherige Züge | Wiederaufnahme nach einer Unterbrechung |
| `STATS` | an den Mitspieler | eigene Bilanz je Spiel | Einmal nach `ACCEPT` |

„An den Mitspieler“ heißt: als unsichtbare Addon-Nachricht direkt an ihn. Das ist kein Flüstern im Chat; weder er noch sonst jemand sieht eine Zeile.

**Bekannte Eigenheit:** Schickt man eine solche Nachricht an jemanden, der gerade offline ist, zeigt der Client selbst die gelbe Zeile „Kein Spieler mit dem Namen … ist online“. Pastime schreibt deshalb nur an Spieler, die laut Gruppe, Freundesliste oder Gilde online sind, und blendet diese eine Systemzeile für die eigenen Nachrichten aus.

### Braucht es ein Passwort?

Nein, und es gäbe auch keinen Ort dafür: Ein Kanalpasswort gibt es nur für selbst angelegte Chatkanäle, und die nutzt Pastime nicht.

Die Absicherung übernehmen zwei Dinge:

- **Der Absender ist echt.** Den Namen des Absenders setzt der Server, ein Addon kann ihn nicht fälschen.
- **Die Sitzungsnummer ist das Codewort.** Der Einladende würfelt für jede Partie eine zufällige Nummer aus. Jede weitere Nachricht muss vom richtigen Absender kommen und diese Nummer tragen, sonst wird sie verworfen.

Name und Stufe der beiden Spieler wären als Passwort ungeeignet, weil jeder sie sehen kann.

## 4. Ablauf für den Spieler

1. **Reiter „Mehrspieler“** neben „Spiele“ und „Reiserekorde“. Er zeigt die Mitspieler aus den eingeschalteten Kreisen, dazu die Bilanz gegen dich.
2. **Anfragen:** Ein Knopf je Spieler. Der Eingeladene bekommt ein kleines Fenster „X möchte mit dir spielen“ mit „Annehmen“ und „Ablehnen“. Es verfällt nach 60 Sekunden.
3. **Spiel wählen:** Nach dem Annehmen wählt der Einladende eines der Mehrspieler-Spiele. Der andere sieht „X wählt ein Spiel …“.
4. **Spielen:** Beide Fenster zeigen dieselbe Partie, jeder aus seiner Sicht. Wer dran ist, steht groß da.
5. **Ende:** Ergebnis, Bilanz wird fortgeschrieben, Knopf „Revanche“ (dieselbe Paarung, der Verlierer beginnt).

Fristen: 60 Sekunden für die Antwort auf eine Anfrage, 120 Sekunden für die Spielwahl. Für einzelne Züge gibt es keine harte Frist, siehe Unterbrechungen.

**Wer beginnt:** Bei der ersten Partie entscheidet der Zufall, bei einer Revanche im selben Spiel beginnt der Verlierer.

**Läuft gerade ein Einzelspiel,** wenn man eine Anfrage annimmt, wird es geparkt und nach der Mehrspieler-Partie fortgesetzt. Ist es dasselbe Spiel wie die Mehrspieler-Partie, wird es abgebrochen und nicht gewertet; das Anfrage-Fenster sagt das vorher.

**Namen:** Spieler senden hier unter Vor- und Nachnamen. Der Mehrspieler arbeitet durchgehend mit dem Absendernamen, wie der Client ihn liefert.

## 5. Unterbrechungen und Wiederaufnahme

- **Jede laufende Partie wird mitgeschrieben:** Spiel, Startwert, alle Züge, Gegner, Uhrzeit.
- **Unterbrechung:** `/reload`, Absturz, Ausloggen, Fenster schließen oder zehn Minuten ohne Zug. Die Partie zählt dann für niemanden, sie ist nur angehalten.
- **Zehn Minuten Frist:** Solange bleibt die angehaltene Partie bei beiden gespeichert.
- **Weiterspielen:** Schickt einer der beiden dem anderen in dieser Zeit eine neue Anfrage, erkennt Pastime die angehaltene Partie und fragt beide „Partie fortsetzen?“. Bei Ja steht das Brett wieder so da wie vorher.
- **Nach einem Absturz** hat der Abgestürzte seine Mitschrift verloren, weil WoW gespeicherte Daten nur beim sauberen Beenden schreibt. Dann schickt der Gegner die Züge (`SYNC`), und beide stehen wieder gleich.
- **Stimmen zwei Mitschriften nicht überein,** wird nicht fortgesetzt; die Partie verfällt.
- **Aufgeben** ist etwas anderes: Der Knopf „Aufgeben“ beendet die Partie sofort als Niederlage.
- **Kampf:** Die Partie pausiert bei dem, der kämpft.

Bei Spielen mit verdeckten Karten kann der Gegner die Mitschrift nicht vollständig liefern; dort lässt sich nach einem Absturz nur die laufende Runde neu geben.

## 6. Spiele

Vorschlag für 2.0, in der Reihenfolge, in der sie gebaut werden:

| Stufe | Spiel | Gibt es schon? | So läuft das Duell |
|---|---|---|---|
| Beta 1 | Vier gewinnt | ja | abwechselnd Steine, gesendet wird die Spalte. Kreise in Beta 1: Gruppe und Gilde; Freunde ab Beta 2 |
| Beta 2 | Tavernenwürfel | ja | abwechselnd würfeln und eintragen, höhere Summe gewinnt |
| Beta 2 | Runenpaare-Duell | ja | ein gemeinsames Feld, abwechselnd zwei Karten; wer ein Paar findet, darf noch einmal |
| Beta 3 | Edelsteincode-Duell | ja | jeder legt dem anderen einen Code; wer ihn in weniger Versuchen knackt, gewinnt |
| Beta 3 | Blackjack-Duell | ja | beide spielen dieselben Karten gegen den Goblin, über fünf Hände; wer mehr Gold hat, gewinnt |
| Beta 4 | Flottenduell (neu) | nein | jeder versteckt Schiffe auf seinem Feld, abwechselnd wird geschossen |

Weitere Ideen für später, nur im Mehrspieler: Reversi, Dame, Mühle, Käsekästchen, Fünf in einer Reihe, Würfelduell um die höchste Zahl, Galgenraten mit selbst gewähltem Wort.

**Verdeckte Informationen** (Code, Schiffe, später Hold'em): Jeder behält sein Geheimnis bei sich und antwortet nur auf Fragen („Treffer“, „zwei richtig“). Am Ende legt jeder sein Geheimnis offen, und das andere Addon prüft, ob alle Antworten dazu passen. Geschummelte Partien werden als ungültig markiert.

**Zufall:** Würfe und Kartenreihenfolge entstehen aus einem Startwert, zu dem beide beitragen, damit keiner allein bestimmt.

## 7. Bilanz und Statistik

- **Gespeichert wird je Gegner und Spiel:** Siege, Niederlagen, Unentschieden, letzte Partie.
- **Gegen dich (gesichert):** Partien, an denen dein Addon beteiligt war.
- **Laut eigener Angabe:** Die Gesamtbilanz, die dir ein Spieler nach dem Annehmen schickt (`STATS`). Sie wird getrennt angezeigt, weil sie in der eigenen Datei gefälscht sein könnte.
- **Kein Weitererzählen in 2.0:** Bilanzen Dritter werden vorerst nicht weitergegeben. Eine echte globale Rangliste ist ohne Server nicht möglich.

## 8. Einstellungen

| Einstellung | Standard |
|---|---|
| Mehrspieler (Hauptschalter; aus: nichts wird gemeldet, niemand sieht dich) | an |
| Sichtbar für Gruppe und Schlachtzug | an |
| Sichtbar für Freunde | an |
| Sichtbar für die Gilde | aus |
| Meine Bilanz mitschicken | an |
| Ton bei einer Anfrage | an |
| Keine Anfragen in Instanzen und Schlachtzügen | an |

Der Update-Hinweis aus 1.3 bleibt davon unabhängig.

## 9. Test und Veröffentlichung

- Bis 2.0 ist der Mehrspieler abgeschaltet und wird für Tests mit `/pastime mp` freigeschaltet (bei beiden Spielern).
- Tags `v2.0.0-beta1`, `-beta2` … gehen als Vorabversionen an GitHub und CurseForge.
- Betastände melden die Versionsnummer 0 und fordern niemanden zum Aktualisieren auf, zeigen sich aber gegenseitig als Mitspieler.
- Getestet wird mit einem zweiten Spieler. Prüfliste je Beta:
  1. Beide sehen sich im Reiter „Mehrspieler“ (Gruppe, Freunde, Gilde je nach Einstellung).
  2. Anfrage, Annehmen, Ablehnen, Verfall nach 60 Sekunden.
  3. Eine ganze Partie, beide Seiten zeigen dasselbe Brett.
  4. `/reload` mitten in der Partie, danach fortsetzen.
  5. Ausloggen und Absturz (Spiel hart beenden), danach fortsetzen.
  6. Aufgeben zählt als Niederlage.
  7. Anfrage im Kampf kommt nicht an.
  8. Bilanz stimmt auf beiden Seiten.
  9. In keinem Chatfenster taucht eine Zeile auf, auch nicht „Kein Spieler mit dem Namen …“.
- `/pastime report` enthält die verworfenen Nachrichten mit Grund, damit Fehler nachvollziehbar sind.
- `v2.0.0` erst, wenn alle Betas mit einem zweiten Spieler durchgelaufen sind.

## 10. Bewusst nicht in 2.0

- Echtzeit-Spiele gegeneinander (Windnatter, Kodo-Sprint): Addon-Nachrichten sind zu langsam.
- Spiele um Goblin-Gold gegeneinander.
- Zuschauer und mehr als zwei Spieler.
- Gemeinsame Rekordlisten der Gilde, Weitererzählen fremder Bilanzen.
