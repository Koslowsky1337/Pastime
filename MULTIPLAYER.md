# Pastime 2.0 – Mehrspieler (Definition)

Stand: bestätigt am 15.11. Beta 1 ist gebaut und ohne Spiel getestet (`tests/mp.lua`); der Test zu zweit steht aus.
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
| Gilde | an | Meldung im Gildenkanal |

Wer einen Kreis abschaltet, erscheint dort bei niemandem und sieht dort auch niemanden. Spieler auf der Ignorierliste werden nie angezeigt und können nichts schicken.

### Wer gerade da ist (seit Beta 2)

- **Nachrichten klären nur, wer Pastime mit Mehrspieler hat.** Ob jemand gerade online ist, sagt der Client: Gruppen-, Gilden- und Freundesliste führen den Online-Status. Es gibt keinen wiederkehrenden Ping.
- **In der Liste steht,** wer sich in dieser Sitzung mit Mehrspieler gemeldet hat und laut Client online ist. Verlässt jemand die Gruppe oder loggt aus, verschwindet er sofort. Die 15-Minuten-Frist der Beta 1 entfällt.
- **Abmelden:** Wer den Mehrspieler ausschaltet oder sich für einen Kreis unsichtbar macht, meldet das einmal, damit er bei den anderen nicht weiter als spielbar dasteht.
- **Freunde:** Beim Einloggen und beim Öffnen des Reiters geht eine Meldung an jeden Freund, den die Freundesliste als online zeigt und der in dieser Sitzung noch keine bekommen hat. Wer Pastime hat, antwortet einmal. Ein eigenes Ereignis „Freund kommt online“ wird nicht gebraucht.
- **Kennzeichnung:** Hinter dem Namen steht ein farbiges Kürzel: (F) Freund in Rosa, (P) Gruppe in Blau, (G) Gilde in Grün. Steht jemand in mehreren Kreisen, gilt Freund vor Gruppe vor Gilde.
- **Namensformen (im Client geprüft, Selbsttest vom 16.11.):** Der Absender einer Nachricht ist der volle Name mit Leerzeichen. Die Gildenliste nennt denselben vollen Namen. `UnitName` liefert für Gruppenmitglieder nur den Vornamen, `GetUnitName(Einheit, true)` den vollen. Die Freundesliste ist noch ungeprüft (im Test war sie leer); der Abgleich nimmt dort beide Formen an.

## 3. Was gesendet wird

| Nachricht | Weg | Inhalt | Wann |
|---|---|---|---|
| `HELLO` | Gilden-, Gruppen-, Schlachtzugskanal; an Freunde einzeln | Versionsnummer, Mehrspieler-Stufe | Einloggen, Gruppenbeitritt, selten als Wiederholung |
| `HERE` | an den Absender eines `HELLO` | Mehrspieler-Stufe, Kanal des `HELLO` | Antwort auf jedes `HELLO` mit Mehrspieler-Stufe, höchstens alle 50 Sekunden je Absender. So finden sich zwei, auch wenn einer das `HELLO` des anderen verpasst hat |
| `INVITE` | an den Mitspieler | Sitzungsnummer | Klick auf „Anfragen“ |
| `ACCEPT` / `DECLINE` | an den Mitspieler | Sitzungsnummer | Antwort des Eingeladenen |
| `AWAY` | an den Anfragenden | Sitzungsnummer | Der Angefragte nimmt dort, wo er gerade ist, keine Anfragen an (siehe 8) |
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
| Beta 3 | Tavernenwürfel | ja | abwechselnd würfeln und eintragen, höhere Summe gewinnt |
| Beta 3 | Runenpaare-Duell | ja | ein gemeinsames Feld, abwechselnd zwei Karten; wer ein Paar findet, darf noch einmal |
| Beta 4 | Edelsteincode-Duell | ja | jeder legt dem anderen einen Code; wer ihn in weniger Versuchen knackt, gewinnt |
| Beta 4 | Blackjack-Duell | ja | beide spielen dieselben Karten gegen den Goblin, über fünf Hände; wer mehr Gold hat, gewinnt |
| Beta 5 | Flottenduell (neu) | nein | jeder versteckt Schiffe auf seinem Feld, abwechselnd wird geschossen |

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
| Sichtbar für die Gilde | an |
| Anfragen auf Reisen (Flug, Zeppelin, Schiff) | an |
| Anfragen in Gasthäusern und Städten (Ruhebereich) | an |
| Anfragen überall | aus |
| Meine Bilanz mitschicken | an |
| Ton bei einer Anfrage | an |
| Keine Anfragen in Instanzen und Schlachtzügen | an |

**Wann Anfragen ankommen:** Als Standard nur, wenn man ohnehin wartet: auf einer Reise oder in einem Ruhebereich. Sonst bekommt der Anfragende den Hinweis, dass gerade keine Anfragen angenommen werden; beim Angefragten erscheint nichts. Ausnahme: Wer in den letzten zehn Minuten mit einem gespielt hat oder ein angehaltenes Spiel mit einem hat, darf immer anfragen (Revanche, Fortsetzen).

**Freunde** sind die Freunde der Spielliste und die Battle.net-Freunde, die gerade in diesem Spiel, auf diesem Realm und in der eigenen Fraktion online sind.

**Erste Frage:** Beim ersten Öffnen mit Mehrspieler fragt ein Fenster, wer einen sehen darf und wann Anfragen ankommen (Hauptschalter, die drei Kreise, die drei Orte; vorgeschlagen ist alles an außer „Anfragen überall“). Solange die Frage offen ist, meldet Pastime nichts und nimmt keine Anfragen an.

Der Update-Hinweis aus 1.3 bleibt davon unabhängig.

## 9. Test und Veröffentlichung

- Bis 2.0 ist der Mehrspieler abgeschaltet und wird für Tests mit `/pastime mp` freigeschaltet (bei beiden Spielern). Seit 1.4 steckt er so in den normalen Versionen; eigene Beta-Tags braucht es zum Testen nicht mehr.
- Tags `v2.0.0-beta1`, `-beta2` … gehen als Vorabversionen an GitHub und CurseForge.
- Betastände melden die Versionsnummer 0 und fordern niemanden zum Aktualisieren auf, zeigen sich aber gegenseitig als Mitspieler.
- Zum Testen ohne Liste: `/pastime debug user Vorname Nachname` fragt einen Spieler direkt an. Der Verlauf (gesendet, empfangen, verworfen) steht mit Kennung statt Name im Protokoll und damit in `/pastime report`.
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

## 11. Notizen für den Changelog von 2.0

Der Mehrspieler wird erst mit 2.0 im Changelog genannt. Bis dahin steckt er abgeschaltet in den 1.x-Versionen und wird für Tests mit `/pastime mp` freigeschaltet. Was die Testversionen gebracht haben (englisch, als Vorlage für den Changelog):

### Beta 4

- Players find each other reliably: every announcement is answered directly, so two players no longer miss each other after logging in at the same moment. Needs this version on both sides; 1.4.0 does not answer.
- Friends now include Battle.net friends who are online in this game, on your realm and in your faction.
- New settings for when requests reach you: while travelling, in inns and cities, anywhere. By default only the first two; otherwise the asking player is told that you are not taking requests right now. A rematch or a paused game always gets through.
- The multiplayer settings are one compact block in the Settings tab; the first-run question asks for the three new settings too.
- New button “What wins?” in the card and gold games. Tavern Hold'em and Goblin Poker list the poker hands from strongest to weakest, each with an example hand and a short explanation; Goblin Blackjack shows example hands too; Goblin Blackjack, Higher or Lower and Goblin Roulette explain what wins and what it pays; Goblin Slots show their pay table there.
- The rules window now starts with the controls and explains the game below, for all 24 games in more detail than before: the goal, how a turn works, what scores and when the game ends.
- Solitaire: a tip (button or H) highlights a move that helps and says why. If no move is left, the game recognises it and ends as lost instead of leaving you searching.

### Beta 3

Multiplayer, third test version: fixes from the first test with two players.

- A rematch request now arrives. After a game the other player's finished board kept them “busy”, so the request was dropped and the asker waited forever.
- The first time multiplayer is on, a window asks who may see you: friends, group, guild. Until you have answered, nothing is announced. The guild is now part of the suggestion; before, two guild members only saw each other if both had found the switch.
- Ending a session now reaches the other side: withdrawing a request removes its window, a request to someone who is busy is turned down at once, and a message for a session the other side does not have ends it instead of leaving one player waiting.
- If both players ask each other at the same moment, one of the two requests wins automatically instead of both waiting.
- Four in a Row: the colours are the same on both screens. The player who invited plays red, the invited player blue, and the board says which one you are.
- Friends: if the friend list only knows a first name, the full name is looked up in the guild list, because direct messages need it.
- For testing: `/pastime debug dump` shows what the game reports about your group, guild, friends and Battle.net friends, with all text masked; `/pastime debug dump klar` shows it in plain text.
- The log no longer fills up with messages of other addons, so `/pastime report` shows the course of a multiplayer test.

### Beta 2

Multiplayer, second test version. Still switched off until both players type `/pastime mp`.

- The player list now follows who is really online: it asks the game's own group, guild and friend lists instead of remembering players for a quarter of an hour. Someone who logs out or leaves the group disappears at once.
- Friends are a third circle. Friends who are online and have Pastime with multiplayer appear in the list; there is a new switch “Visible to your friends”.
- After each name a coloured tag shows where you know the player from: (F) friend, (P) party, (G) guild. Friend comes before party, party before guild.
- Switching multiplayer off or hiding from a circle tells the others once, so you no longer show up as available.
- For testing: `/pastime debug user First Last` asks a player for a game directly, even if they are not in the list. `/pastime report` then contains the course of the session, with player ids instead of names.
- `/pastime debug test` asks whether to run quickly or with all sounds; closing its window cancels it.

### Beta 1

Multiplayer, first test version. It is switched off until both players type `/pastime mp`.

- New tab “Multiplayer”: it lists players in your group (and, if you switch it on, your guild) who have Pastime with multiplayer on, with your record against them.
- Ask a player for a game. They get a small window to accept or decline; then you choose the game.
- First game: Four in a Row against another player. Only legal moves go through. The first game starts at random, in a rematch the loser begins.
- Closing the board, reloading or ten idle minutes pause a game without counting it. Ask the same player again within ten minutes to continue where you stopped. Giving up counts as a loss.
- A single-player game that is running when you accept waits and comes back afterwards.
- Settings: multiplayer on or off, and whether your group and your guild see you.
- Everything travels as invisible addon messages; nothing appears in chat.
