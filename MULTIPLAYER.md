# Pastime 2.0 – Mehrspieler (Definition)

Stand: Entwurf vom 15.11., noch nicht gebaut. Diese Datei legt fest, was gebaut wird, bevor Code entsteht.
(Sie kommt nicht ins Addon-Zip: `.pkgmeta` lässt `*.md` weg.)

## 1. Grundsätze

- **Nichts Sichtbares im Chat.** Alles läuft über Addon-Nachrichten. Kein Spieler sieht davon etwas in einem Chatfenster.
- **Nur mit Leuten aus der eigenen Gruppe.** Mehrspieler gibt es in 2.0 nur in Gruppe und Schlachtzug. Gilde und Freunde sind ein möglicher Ausbau.
- **Nichts passiert ohne Zustimmung.** Eine Anfrage muss bestätigt werden. Im Kampf kommt keine Anfrage an.
- **Jeder rechnet selbst.** Beide Seiten führen das Spiel nach denselben Regeln; gesendet werden nur Züge. Ein ungültiger Zug beendet die Partie.
- **Fremde Nachrichten gelten als nicht vertrauenswürdig.** Feste Nachrichtentypen, feste Felder, Mengenbremse (steht in `Comm.lua` schon bereit).

## 2. Was gesendet wird

| Nachricht | Kanal | Inhalt | Wann |
|---|---|---|---|
| `HELLO` | Gilde, Gruppe, Schlachtzug | Versionsnummer, Mehrspieler-Stufe | Einloggen, Gruppenbeitritt, höchstens alle 10 Minuten als Antwort auf eine ältere Version |
| `INVITE` | Gruppe | Sitzungsnummer, Name des Eingeladenen | Klick auf „Anfragen“ |
| `ACCEPT` / `DECLINE` | Gruppe | Sitzungsnummer | Antwort des Eingeladenen |
| `START` | Gruppe | Sitzungsnummer, Spiel, Startwert | Der Einladende hat ein Spiel gewählt |
| `MOVE` | Gruppe | Sitzungsnummer, laufende Nummer, Zug | Jeder Zug |
| `RESULT` | Gruppe | Sitzungsnummer, Ergebnis aus eigener Sicht | Spielende, zur Gegenprobe |
| `BYE` | Gruppe | Sitzungsnummer | Abbruch, Fenster zu, Ausloggen |
| `STATS` | Gruppe | eigene Bilanz je Spiel | Einmal nach `ACCEPT` |

Alle Nachrichten gehen in den Gruppenkanal, nie als Flüstern. Wer nicht gemeint ist, verwirft sie anhand der Sitzungsnummer.

**Offener Punkt:** Namen mit Umlauten oder Sonderzeichen passen nicht in die heutigen Felder. Für `INVITE` wird der Eingeladene deshalb über seinen Platz in der Gruppe angesprochen (Nummer), nicht über den Namen.

## 3. Ablauf für den Spieler

1. **Reiter „Mehrspieler“** neben „Spiele“ und „Reiserekorde“. Er zeigt die Gruppenmitglieder, die Pastime mit Mehrspieler haben, dazu ihre Bilanz gegen dich.
2. **Anfragen:** Ein Knopf je Spieler. Der Eingeladene bekommt ein kleines Fenster „X möchte mit dir spielen“ mit „Annehmen“ und „Ablehnen“. Es verfällt nach 60 Sekunden.
3. **Spiel wählen:** Nach dem Annehmen wählt der Einladende eines der Mehrspieler-Spiele. Der andere sieht „X wählt ein Spiel …“.
4. **Spielen:** Beide Fenster zeigen dieselbe Partie, jeder aus seiner Sicht. Wer dran ist, steht groß da.
5. **Ende:** Ergebnis, Bilanz wird fortgeschrieben, Knopf „Revanche“ (dieselbe Paarung, der Verlierer beginnt).

Zustände einer Sitzung: `angefragt` → `angenommen` → `Spiel gewählt` → `läuft` → `beendet`. Jeder Zustand hat eine Frist (60 s für die Antwort, 120 s für die Spielwahl, 90 s je Zug). Läuft sie ab, endet die Sitzung für beide.

## 4. Abbruch und Störungen

- **Fenster schließen oder „Aufgeben“:** zählt als Niederlage, der andere bekommt `BYE`.
- **Ausloggen, Gruppe verlassen, Verbindungsabbruch:** Kommt 90 Sekunden kein Zug, endet die Partie als „abgebrochen“ und zählt für niemanden.
- **Kampf:** Die Partie pausiert bei dem, der kämpft; die Zugfrist läuft weiter.
- **Züge außer der Reihe, doppelte oder ungültige Züge:** werden verworfen. Ein regelwidriger Zug beendet die Partie als „abgebrochen“.
- **Unterschiedliche Versionen:** Gespielt wird nur, wenn beide dieselbe Mehrspieler-Stufe melden.

## 5. Spiele und Reihenfolge

| Stufe | Spiel | Art | Was gesendet wird |
|---|---|---|---|
| Beta 1 | Vier gewinnt | Zug um Zug | Spalte |
| Beta 2 | Wettrennen: Runenpaare, Edelsteincode, Wortraten, Minenfeld | gleiche Aufgabe, wer ist besser | Startwert, am Ende das Ergebnis |
| Beta 3 | Tavernenwürfel | Zug um Zug, 2 Spieler | Würfe und gewählte Zeile |
| später | Tavernen-Hold'em | verdeckte Karten | siehe unten |

**Verdeckte Karten (Hold'em):** Jeder muss seine eigene Seite haben, ohne die Karten des anderen zu kennen. Ohne Server geht das nur, wenn einer die Karten gibt und dem anderen nur dessen Blatt schickt. Der Geber könnte dabei in seine gespeicherten Daten schauen. Für ein Spiel unter Bekannten ist das vertretbar, wird aber erst nach den offenen Spielen gebaut.

**Zufall:** Der Startwert kommt vom Einladenden. Wer beginnt, entscheidet eine Zahl, zu der beide beitragen, damit keiner allein bestimmt.

## 6. Bilanz und Statistik

- **Gespeichert wird je Gegner und Spiel:** Siege, Niederlagen, Unentschieden, letzte Partie.
- **Gegen dich (gesichert):** Partien, an denen dein Addon beteiligt war.
- **Laut eigener Angabe:** Die Gesamtbilanz, die dir ein Spieler nach dem Annehmen schickt (`STATS`). Sie wird getrennt angezeigt, weil sie in der eigenen Datei gefälscht sein könnte.
- **Kein Weitererzählen in 2.0:** Bilanzen Dritter werden vorerst nicht weitergegeben. Eine echte globale Rangliste ist ohne Server nicht möglich.
- **Abschaltbar:** Option „Meine Bilanz nicht mitschicken“.

## 7. Einstellungen

- „Mehrspieler-Anfragen annehmen“ (Standard: an). Aus bedeutet: Du erscheinst bei niemandem in der Liste.
- „Meine Bilanz mitschicken“ (Standard: an).

## 8. Test und Veröffentlichung

- Tags `v2.0.0-beta1`, `-beta2` … gehen als Vorabversionen an GitHub und CurseForge.
- Betastände melden die Versionsnummer 0 und fordern niemanden zum Aktualisieren auf, zeigen sich aber gegenseitig als Mitspieler.
- Getestet wird mit einem zweiten Spieler in derselben Gruppe. Prüfliste je Beta:
  1. Beide sehen sich im Reiter „Mehrspieler“.
  2. Anfrage, Annehmen, Ablehnen, Verfall nach 60 Sekunden.
  3. Eine ganze Partie, beide Seiten zeigen dasselbe Brett.
  4. Abbruch durch Schließen, Ausloggen und Gruppe verlassen.
  5. Anfrage im Kampf kommt nicht an.
  6. Bilanz stimmt auf beiden Seiten.
- `/pastime report` enthält die verworfenen Nachrichten mit Grund, damit Fehler nachvollziehbar sind.
- `v2.0.0` erst, wenn Beta 1 bis 3 mit einem zweiten Spieler durchgelaufen sind.

## 9. Bewusst nicht in 2.0

- Echtzeit-Spiele gegeneinander (Windnatter, Kodo-Sprint): Addon-Nachrichten sind zu langsam.
- Spiele um Goblin-Gold gegeneinander.
- Zuschauer, mehr als zwei Spieler (außer später Hold'em).
- Gemeinsame Rekordlisten der Gilde.
