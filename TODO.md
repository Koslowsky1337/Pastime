# Pastime – ToDo

Stand: `v1.1.0` ist veröffentlicht (15.11.), 1.2 ist in Arbeit. Die Prüflisten bis 1.0 sind erledigt und stehen in der Git-Historie.
(Diese Datei kommt nicht ins Addon-Zip: `.pkgmeta` lässt `TODO.md` weg.)

## 1. Von Hand (GitHub)
- [x] GitHub-Releases: entstehen automatisch bei jedem Tag (`.github/workflows/release.yml`, mit Zip); v1.0.0, v1.0.1 und v1.1.0 sind nachgeholt
- [x] Beschreibung auf „24 mini-games“ geändert, neues Social-Preview-Bild hochgeladen (15.11.)
- [ ] CurseForge-Galerie: Screenshots noch einmal auf Englisch (`/pastime fotos`), danach zuschneiden
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
- [ ] **Im Spiel prüfen (für 1.2):** Runengold beim Scatter; Auto-Spin zählt 20 herunter und stoppt bei Freispielen; Roulette-Knopf „Nochmal“; Hold'em mitten in der Hand schließen und wieder öffnen; die 100er-Einträge sind aus den Rekorden weg
- [ ] Jackpot über die Goblin-Spiele (Regeln noch festlegen)
- [ ] Tagesaufgabe: ein Spiel pro Tag mit Ziel (Regeln noch festlegen)

## 3. Später
- [x] Arbeitsordner heißt jetzt `Pastime` (15.11.)
