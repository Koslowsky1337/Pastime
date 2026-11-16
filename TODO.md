# Pastime – ToDo

Stand: `v1.4.0` ist veröffentlicht (16.11.). Der Mehrspieler steckt abgeschaltet darin und wird erst mit 2.0 im Changelog genannt. Die Prüflisten bis 1.0 sind erledigt und stehen in der Git-Historie.
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
- [x] Im Spiel geprüft (15.11., Selbsttest ohne Befund): Klänge samt Fanfare, Texturen, Addon-Nachrichten über die Gilde und direkt an sich selbst
- [ ] Totem-Echo: eigene Töne statt der vier geliehenen Oberflächenklänge (Kandidaten mit dem Selbsttest prüfen)
- [ ] **Im Spiel prüfen (nach 1.3):** Fanfare beim Runen-Treffer hörbar? Ziehen des Bonussymbols (nur mittlere Walze, dann nur das Symbol); Auffüllen Feld für Feld; zweites Symbol nach Verlängerung; Hochzählen; Spielregeln mit Gewinnplan passen ins Fenster 📸
- [ ] Tagesziele nach ein paar Tagen Spielen nachjustieren (`ns.DAILY` in `Core.lua`; Werte sind geschätzt)

## 3. Version 2.0: Mehrspieler
- [x] Definition in `MULTIPLAYER.md` bestätigt (15.11.)
- [x] Beta 1, Schritt 1: Sitzungslogik `Multiplayer.lua` (Anfrage, Annehmen, Spielwahl, Züge, Aufgeben, Anhalten und Fortsetzen, Bilanz, Fristen) und Regelwerk Vier gewinnt, mit Tests `tests/mp.lua`
- [x] Beta 1, Schritt 2: Reiter „Mehrspieler“ (Mitspielerliste, Anfragen, Anfrage-Fenster, Spielwahl), Mehrspieler-Schalter im Reiter „Einstellungen“
- [x] Beta 1, Schritt 3: Vier gewinnt als Mehrspieler-Brett, laufendes Einzelspiel parken, Offline-Zeile ausblenden
- [x] Allein im Spiel geprüft (15.11.): Reiter „Mehrspieler“ und die drei Schalter in den Einstellungen passen
- [x] `v2.0.0-beta1` getaggt (16.11.), Vorab-Release auf GitHub mit Zip
- [x] Beta 2 (16.11.): Online-Status aus Gruppen-, Gilden- und Freundesliste, Abmelden, Kreis „Freunde“, Kürzel (F)/(P)/(G), `/pastime debug user Vorname Nachname`
- [x] Erster Test zu zweit mit Beta 2 (16.11.): Anfrage, Spielwahl und eine ganze Partie Vier gewinnt liefen; behoben für Beta 3: Revanche kam nicht an, gleiche Farbe auf beiden Seiten, Protokoll voller fremder Addon-Nachrichten, Freund nicht gesehen
- [x] Befund (16.11.): Die Freundesliste im Spiel ist leer, gemeint sind Battle.net-Freunde; die fragt Pastime noch nicht ab
- [ ] `/pastime debug dump` ausführen, während ein Battle.net-Freund mit Pastime online ist: der Auszug zeigt, wie dessen Charakter dasteht; danach den Kreis „Freunde“ auf Battle.net umbauen
- [x] „Sichtbar für die Gilde“ ist Standard an; beim ersten Öffnen fragt ein Fenster, wer einen sehen darf (16.11.)
- [ ] **Test zu zweit mit Beta 3** nach der Prüfliste in `MULTIPLAYER.md` (ab Teil 2: Liste, Revanche, Unterbrechen, Offline) (beide: Beta installieren, WoW neu starten, `/pastime mp`, in eine Gruppe gehen); danach beide `/pastime report` schicken
- [x] Verbindungstest aus 1.3 ausgewertet (15.11.): ein anderer Spieler hat direkt geantwortet, direkte Nachrichten kommen an. `PING`/`PONG` sind wieder entfernt
- [ ] Beta 3: Tavernenwürfel und Runenpaare-Duell, Bilanz „laut eigener Angabe“
- [ ] Beta 4: Edelsteincode-Duell und Blackjack-Duell
- [ ] Beta 5: Flottenduell (neues Spiel)
- [ ] Jede Beta mit einem zweiten Spieler nach der Prüfliste in `MULTIPLAYER.md` testen

## 4. Später
- [x] Ausführliche Spielerklärung für alle 24 Spiele im Regel-Fenster (oben Steuerung, darunter „So geht's“), Englisch und Deutsch (16.11.)
- [x] Solitär: Tipp (Knopf oder H) und Erkennung „kein Zug mehr“ (16.11.)
- [ ] **Im Spiel prüfen:** Knopf „Was gewinnt?“ in den Karten- und Goldspielen; Regel-Fenster bei ein paar Spielen (passt der Text?); Solitär-Tipp und Tipp-Knopf oben zwischen Ablage und Farbstapeln 📸
- [x] Arbeitsordner heißt jetzt `Pastime` (15.11.)
