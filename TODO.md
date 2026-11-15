# Pastime – ToDo

Stand: `v1.2.0` ist veröffentlicht (15.11.). Die Prüflisten bis 1.0 sind erledigt und stehen in der Git-Historie.
(Diese Datei kommt nicht ins Addon-Zip: `.pkgmeta` lässt `TODO.md` weg.)

## 1. Von Hand (GitHub)
- [x] GitHub-Releases: entstehen automatisch bei jedem Tag (`.github/workflows/release.yml`, mit Zip); v1.0.0, v1.0.1 und v1.1.0 sind nachgeholt
- [x] Beschreibung auf „24 mini-games“ geändert, neues Social-Preview-Bild hochgeladen (15.11.)
- [x] Englische Screenshots zugeschnitten (15.11., Ordner `Screenshots\Pastime-Galerie`)
- [ ] Die acht englischen Bilder in die CurseForge-Galerie laden
- [x] Screenshots für die CurseForge-Galerie (15.11., mit `/pastime fotos`)

## 2. Version 1.1 (als `v1.1.0` veröffentlicht am 15.11.) und danach
- [x] Reiserekorde: Platzziffern auf dem Pergament dunkler (waren kaum lesbar)
- [x] `/pastime fotos`: wertet nichts, zeigt Beispiel-Rekorde, Kodo mitten im Sprung
- [x] Goblin-Automat: Freispiele und Scatter-Symbol (Rune; 3/4/5 Runen = 5/8/12 Freispiele, Quote rund 96 %)
- [x] Goblin-Roulette: Kessel mit 37 Fächern, die Kugel läuft aus (4,5 s)
- [x] Roulette: Liste der letzten 15 Zahlen; Automat: Münzen am Linienanfang zählen in der besseren Lesart
- [x] Protokoll: Kurzzeitspeicher für Debug-Zeilen, stille Client-Fehlschläge als Warnung (`ns.Try`), anonymisierter Bericht `/pastime report` und Knopf in den Optionen
- [x] Fester Einsatz statt 10 / ¼ / ½ in Automat, Blackjack, Goblin-Poker, Höher oder tiefer (1/2 kleiner/größer, 3 Maximum, Leertaste spielt); Auto-Spin im Automaten (A)
- [x] Im Spiel geprüft (15.11.): fester Einsatz, Auto-Spin, Fehlerbericht-Knopf
- [x] Goblin-Automat: 3/4/5 Runen zahlen sofort den 1-/5-/20-fachen Einsatz, Linien leicht gesenkt (Quote 96,6 %)
- [x] Auto-Spin: 20 Drehungen, hält bei Freispielen an (kein Schnelldreh-Modus – bewusst weggelassen)
- [x] Roulette: Knopf „Nochmal“ bei leerem Tisch, letzte Einsätze überstehen das Schließen
- [x] Tavernen-Hold'em: die laufende Hand übersteht das Schließen des Fensters
- [x] Glücksspiele: Pleite ohne je über 100 Gold wird nicht gewertet, alte 100er-Einträge entfernt
- [ ] **Im Spiel prüfen (nach 1.2):** Runengold beim Scatter; Auto-Spin zählt 20 herunter und stoppt bei Freispielen; Roulette-Knopf „Nochmal“; Hold'em mitten in der Hand schließen und wieder öffnen; die 100er-Einträge sind aus den Rekorden weg
- [x] Jackpot über alle sechs Goldspiele: 10 % jedes Verlusts, je Spiel ein seltener Auslöser (rund 1 zu 1.000 bis 3.400), Tooltip erklärt ihn
- [x] Tagesaufgabe: ein Spiel pro Tag mit Ziel in der Fußzeile der Spielauswahl, Klick startet, Serie über aufeinanderfolgende Tage
- [ ] **Im Spiel prüfen (nach 1.2):** Jackpot-Anzeige oben links in allen sechs Goldspielen samt Tooltip; Tagesaufgabe rechts in der Fußzeile, Klick startet das Spiel, Chat-Meldung beim Erreichen
- [x] Goblin-Automat (für 1.3): Rune ist Joker und Scatter, höchstens eine je Walze (3 = 10 Freispiele, 4 = 20); Bonussymbol von Hand ziehen, Walzen füllen sich Feld für Feld, zweites Symbol bei Verlängerung; große Gewinne zählen hoch; Gewinnplan in den Spielregeln (Quote 96,4 %)
- [x] Startgold 1000 statt 100 in allen Goldspielen, Jackpot ab 10.000 (laufende Töpfe und alte Rekorde einmalig +900)
- [x] Automat: mehr kleine Treffer (zwei gleiche ab Murloc), Joker unter den Walzen erklärt (Quote 96,5 %, rund 56 % der Drehungen zahlen etwas)
- [x] Update-Hinweis: Versionsnummer unsichtbar an Gilde und Gruppe, Chat-Zeile bei neuerer Version (nur volle Versionen)
- [x] Reiter „Einstellungen“ im Fenster (dieselben Schalter wie im Addon-Menü)
- [x] Selbsttest `/pastime debug test` (Schnittstellen, Klänge, Texturen, Addon-Nachricht an sich selbst), mehr Sprüche im Automaten
- [ ] **Im Spiel prüfen (für 1.3):** Fanfare beim Runen-Treffer hörbar? Ziehen des Bonussymbols (nur mittlere Walze, dann nur das Symbol); Auffüllen Feld für Feld; zweites Symbol nach Verlängerung; Hochzählen; Spielregeln mit Gewinnplan passen ins Fenster 📸
- [ ] Tagesziele nach ein paar Tagen Spielen nachjustieren (`ns.DAILY` in `Core.lua`; Werte sind geschätzt)

## 3. Version 2.0: Mehrspieler
- [ ] Definition in `MULTIPLAYER.md` durchgehen und bestätigen (offene Punkte dort)
- [ ] Verbindungstest aus 1.3 auswerten: Sobald ein `/pastime debug test` mit einem zweiten 1.3-Nutzer „answered … directly“ zeigt (steht auch im Protokoll und als `directOK`), `PING`/`PONG`/`Comm.Ping` wieder entfernen und README anpassen
- [ ] Beta 1: Reiter „Mehrspieler“, Anfrage und Annehmen, Spielwahl, Vier gewinnt, Bilanz
- [ ] Beta 2: Tavernenwürfel und Runenpaare-Duell
- [ ] Beta 3: Edelsteincode-Duell und Blackjack-Duell
- [ ] Beta 4: Flottenduell (neues Spiel)
- [ ] Jede Beta mit einem zweiten Spieler nach der Prüfliste in `MULTIPLAYER.md` testen

## 4. Später
- [x] Arbeitsordner heißt jetzt `Pastime` (15.11.)
