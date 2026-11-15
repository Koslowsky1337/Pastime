# Pastime – ToDo

Stand: `v1.0.1` ist veröffentlicht (15.11.). Die Prüflisten bis 1.0 sind erledigt und stehen in der Git-Historie.
(Diese Datei kommt nicht ins Addon-Zip: `.pkgmeta` lässt `TODO.md` weg.)

## 1. Von Hand (GitHub)
- [ ] GitHub-Releases zu `v1.0.0` und `v1.0.1` anlegen (*Releases → Draft a new release*)
- [ ] Beschreibung auf „24 mini-games“ ändern, neues Social-Preview-Bild (`media/social-preview.png`) hochladen
- [x] Screenshots für die CurseForge-Galerie (15.11., mit `/pastime fotos`)

## 2. Version 1.1 (als `v1.1.0` veröffentlicht am 15.11.) und danach
- [x] Reiserekorde: Platzziffern auf dem Pergament dunkler (waren kaum lesbar)
- [x] `/pastime fotos`: wertet nichts, zeigt Beispiel-Rekorde, Kodo mitten im Sprung
- [x] Goblin-Automat: Freispiele und Scatter-Symbol (Rune; 3/4/5 Runen = 5/8/12 Freispiele, Quote rund 96 %)
- [ ] **Im Spiel prüfen:** Rune wird angezeigt (kein grünes Kästchen); Freispiele drehen von selbst; fühlt sich „jede 31. Drehung“ richtig an?
- [x] Goblin-Roulette: Kessel mit 37 Fächern, die Kugel läuft aus (4,5 s)
- [ ] **Im Spiel prüfen:** Kessel links unter dem Tisch, Meldungen rechts daneben – passt alles, ist die Kugel gut zu sehen, stimmt das Tempo? 📸
- [x] Roulette: Liste der letzten 15 Zahlen; Automat: Münzen am Linienanfang zählen in der besseren Lesart
- [x] Protokoll: Kurzzeitspeicher für Debug-Zeilen, stille Client-Fehlschläge als Warnung (`ns.Try`), anonymisierter Bericht `/pastime report` und Knopf in den Optionen
- [ ] **Im Spiel prüfen:** `/pastime report` öffnet das Kopierfenster, kein Charaktername im Text; Knopf „Fehlerbericht erstellen“ unter Optionen → AddOns → Pastime
- [x] Fester Einsatz statt 10 / ¼ / ½ in Automat, Blackjack, Goblin-Poker, Höher oder tiefer (1/2 kleiner/größer, 3 Maximum, Leertaste spielt); Auto-Spin im Automaten (A)
- [ ] **Im Spiel prüfen (für 1.2):** Einsatzknöpfe „–“, „Drehen für … Gold“, „+“ in allen vier Spielen; Auto-Spin läuft und stoppt mit A; Knopf „Auto-Spin“ links, „Kasse machen“ rechts 📸
- [ ] Goblin-Automat: Runen zahlen zusätzlich sofort Gold (Lesart noch bestätigen, Quote neu einstellen)
- [ ] Tavernen-Hold'em: wer mitten in einer Hand geht, bekommt den Stand vor der Hand zurück – bei Bedarf den Einsatz der Hand abziehen

## 3. Später
- [ ] Arbeitsordner von `Pastetime` in `Pastime` umbenennen (Sitzung schließen, umbenennen, neu öffnen)
