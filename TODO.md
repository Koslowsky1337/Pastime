# Pastime – ToDo bis zur Vollversion 1.0.0

Diese Liste muss abgehakt sein, bevor `v1.0.0` getaggt wird.
(Sie kommt nicht ins Addon-Zip: `.pkgmeta` nennt `TODO.md` und `README.md` ausdrücklich und lässt zusätzlich alle `*.md` weg.)

## 0. Reparaturen nach der Gesamt-Evaluation (14.11.)

- [x] Paket 1: Tastatur bleibt im Kampf frei, auch auf dem Spielende-Bildschirm
- [x] Paket 2: Release-Unterlagen (README, Changelog, `.pkgmeta`, Credits, Feedback-Link)
- [x] Paket 3: Versionsnummer kommt aus dem Tag (`@project-version@` in der TOC; ungepackt zeigt das Addon „dev“)
- [x] Paket 4: Zeppelin und Schiff (Anleger, Reload unterwegs, heruntergefallen, Ruhestein, Tod), Strecke löschen
- [x] Paket 5: Sprache und Formate (Zahlen, Datum, Ortsnamen wie im Client)
- [x] Paket 6: Spiel-Kleinigkeiten (Anzeige Runenpaare/Solitär, Blackjack-Ankunftstext, Enter beim Angeln, Top 10 im Tooltip, Strg-Tasten, toter Knopf „Fortsetzen“ entfernt)
- [x] Paket 7: Lesbarkeit und Farbschwäche (2048, Wortraten, Kristall statt Amethyst, Kartenrücken, langer Zielname)
- [x] Paket 8: Tests härten (Wertungsregeln, Übersetzungen, Allianz-Anleger, Migration; `tests/all.py` meldet jetzt auch abgebrochene Suites)
- [x] Vier in einer Reihe: der Gegner macht Fehler (Mittel bei 35 %, Schwer bei 8 % der Züge) und spielt nicht mehr jede Partie gleich
- [x] Goblin-Blackjack: ein Lauf kann als Gewinn enden („Kasse machen“ ab mehr als 100 Gold, eigener Commit – lässt sich einzeln zurücknehmen)

### Dazu im Spiel prüfen
- [ ] **Kampf auf dem Endbildschirm:** „Im Kampf ausblenden“ aus, eine Partie verlieren, angreifen lassen – Bewegen und Zaubern gehen sofort.
- [ ] **Zeppelin, Fenster erst bei Abfahrt (15.11.):** am Turm bleibt das Fenster zu; es öffnet sich, sobald der Zeppelin ablegt.
- [ ] **Zeppelin, ganz normal:** warten, abfahren, ankommen – Strecke und Dauer stimmen (die Erkennung wurde umgebaut). Danach `/pastime diag` 📸.
- [ ] **Zeppelin ohne Warten:** erst im letzten Moment aufspringen – die Reise wird trotzdem erkannt.
- [ ] **`/reload` auf dem Zeppelin:** bei der Ankunft geht kein Fenster auf und es steht keine Reise im Status.
- [ ] **Am Anleger stehen bleiben:** Fenster schließen, 11 Minuten warten – es öffnet sich nicht erneut.
- [ ] **Reiserekorde:** „Strecke löschen“ fragt nach und löscht erst beim zweiten Klick 📸.
- [ ] **Bestenliste:** Bei mehr als fünf Einträgen steht „(Maus: Top 10)“ neben der Überschrift; der Tooltip zeigt alle Plätze 📸.
- [ ] **Strg+S** in der Windnatter schaltet den Ton und lenkt nicht nach unten.
- [ ] **2048:** dunkle Zahlen auf den hellen Kacheln (2, 4, 8, 64 …), weiße auf Blau, Lila und Rot 📸.
- [ ] **Wortraten:** richtige Buchstaben sind dunkelgrün mit goldenem Rahmen, vorhandene golden 📸.
- [ ] **Edelstein-Code und Edelsteine:** der türkise Kristall (statt Amethyst) wird angezeigt, kein grünes Kästchen 📸.
- [ ] **Ankunft mit langem Zielnamen** (z. B. Zoram'gar-Außenposten): der Titel bricht um und bleibt im Rahmen 📸.
- [ ] **Goblin-Blackjack:** über 100 Gold kommen, „Kasse machen (K)“ zwischen zwei Händen – Spielende zeigt „Gewonnen!“ und den höchsten Goldstand 📸. Bei 100 Gold oder weniger ist der Knopf grau.
- [ ] **Vier in einer Reihe:** je drei Partien auf „Mittel“ und „Schwer“ – der Gegner ist schlagbar und antwortet auf gleiche Züge nicht immer gleich. Fühlt sich „Schwer“ noch schwer genug an?
- [ ] **Ortsnamen:** Zeppelin- und Schiffsstrecken heißen jetzt „Undercity“, „Ratchet“, „Booty Bay“ wie im Client. Mit einem Allianz-Charakter prüfen: Heißt es dort „Stormwind“, „Southshore“ und „Hafen von Menethil“? Alte Strecken mit „Unterstadt“ oder „Ratschet“ bleiben in der Liste stehen (über „Strecke löschen“ entfernen).
- [ ] **Nach dem Umbenennen (Spiel neu starten!):** alle 19 Spiele stehen in der Liste; alte Bestenlisten und Reiserekorde von Steinschlag, Windreiter, Mauerbrecher, Totem-Echo, Runenpaare, Tavernenwürfel und Vier in einer Reihe sind noch da 📸.
- [ ] **Pause:** P in einem laufenden Spiel – das Feld ist ganz verdeckt und erscheint erst mit „Weiter“ (bei Echtzeit-Spielen mit dem Countdown) 📸. Ebenso beim Ankunftsdialog.
- [ ] **Lange Streckennamen:** in der Streckenzeile der Auswahl und in den Reiserekorden steht z. B. „Zoram'gar-Auße… → Orgrimmar“; der Tooltip zeigt den vollen Namen 📸.
- [ ] **Knopf „Spielregeln“** in der Seitenleiste: pausiert und zeigt Ziel und Steuerung; „Weiter“ setzt fort. Passt die Seitenleiste noch (Vorschau bei Steinschlag, Steuerungs-Hinweis, Reisezeile) 📸?

### Glücksspiele – nach dem Umbau vom 15.11. im Spiel prüfen, **Spiel neu starten**
- [ ] **Goblin-Automat:** fünf Walzen bleiben von links nach rechts stehen; Gewinnfelder leuchten golden; Gewinnplan unter den Walzen lesbar 📸. Fühlt sich die Gewinnhäufigkeit jetzt gut an?
- [ ] **Goblin-Poker:** halten, tauschen, dann erhöhen oder passen; die Karten des Goblins werden aufgedeckt 📸.
- [ ] **Höher oder tiefer:** Faktoren auf den Knöpfen; nach einem Treffer lässt sich der Topf nehmen.
- [ ] **Goblin-Roulette:** Chips per Klick legen (Betrag steht auf dem Feld), Rechtsklick nimmt zurück, Leertaste dreht; das Gewinnfeld leuchtet; Leertaste ohne Chips wiederholt die letzten Einsätze 📸.
- [ ] **Tavernen-Hold'em:** einkaufen, einen Tisch spielen: Chips neben jedem Namen, All-in-Knopf, Gegner fliegen raus („raus“), Blinds steigen; „Aufstehen“ tauscht Chips in Gold; nach `/reload` sitzt du wieder am Tisch 📸.
- [ ] **Spielauswahl:** das Mausrad scrollt zwei Zeilen je Raste.
- [ ] In allen fünf: „Kasse machen“ ab mehr als 100 Gold, Gold bleibt nach `/reload`, Knopf „Spielregeln“ erklärt das Spiel.
- [ ] Spielauswahl: 24 Spiele, die Liste unter „Würfel & Karten“ passt in das Fenster (oder lässt sich scrollen) 📸.

## 1. Prüfung im Spiel (16 Spiele)

Im Spiel bestätigt sind bisher: Windnatter, Windreiter, Kodo-Sprint.

Vorher: `/reload`, dann `/pastime debug`. Das Debug-Fenster prüft alles, was angeklickt wird.
Zeigt es bei „Layout“ eine Zahl über 0: Screenshot.
Für jedes Spiel einmal: Details in der Auswahl ansehen, kurze Runde, einmal P und weiter, Spielende ansehen.
📸 = Screenshot machen.

### Geschicklichkeit
- [ ] **Kobold-Hauen:** Einblendungen „+10“, „+30“, „-20“ erscheinen über dem Schacht 📸. Nach P und „Weiter“ kommt der Countdown.
- [ ] **Angeln:** zehn Würfe; unter 300 Punkten steht am Ende „Spiel vorbei“ 📸.
- [ ] **Steinschlag:** aufliegender Stein lässt sich noch kurz schieben; Countdown nach Pause; Seitenleiste zeigt „P/Esc: Pause“ 📸.
- [ ] **Mauerbrecher:** Seitenleiste zeigt „Stufe“; Countdown nach Pause.
- [ ] **Murloc-Invasion:** Countdown nach Pause.

### Knobeln
- [ ] **Goblin-Minenfeld:** „Leicht“ und „Mittel“; Flaggen per Rechtsklick 📸.
- [ ] **Totem-Echo:** Steinrahmen der vier Totems vollständig sichtbar 📸.
- [ ] **Runenpaare:** falsches Paar aufdecken, sofort dritte Karte anklicken – Paar geht zu, neue Karte auf.
- [ ] **Edelstein-Code:** einmal lösen oder 10 Versuche; Erklärung rechts passt in ihren Platz 📸.
- [ ] **Wortraten:** ein Wort raten; P ist ein Buchstabe, Esc pausiert.
- [ ] **Vier in einer Reihe:** auf „Schwer“; die KI macht keine spürbare Denkpause.
- [ ] **2048:** Kacheln schieben 📸.
- [ ] **Edelsteine:** ungültigen Tausch versuchen – „Kein Treffer – Zug zurück“ ist mitten auf dem Feld lesbar 📸.

### Würfel & Karten
- [ ] **Goblin-Blackjack:** Einsatzknöpfe wachsen mit dem Gold 📸; nach `/reload` bleibt das Gold; alles verspielen – Spielende zeigt „Höchster Goldstand“ 📸; Farbzeichen ♥♦♠♣ auf den Karten sichtbar.
- [ ] **Tavernenwürfel:** Knopf heißt „Würfeln (2)“.
- [ ] **Solitär:** Karte und ganzen Stapel ziehen; Klick auf ein Ass legt es auf seinen Farbplatz; bei überdeckten Karten sind Wert und Farbzeichen sichtbar 📸.

### Testflug
- [ ] `/pastime testflug 40`, Kobold-Hauen oder Steinschlag starten, nochmal `/pastime testflug` – nach „Weiterspielen“ kommt der Countdown.

### Horde und Allianz
- [ ] Horde: Fenster mit roten Akzenten und Horde-Wappen neben „Pastime“ 📸.
- [ ] Mit einem Allianz-Charakter: Fenster blau mit Allianz-Wappen 📸; Greifenflug, Widder-Sprint und Glocken-Echo statt Windreiter, Kodo-Sprint und Totem-Echo 📸; Windnatter auf grüner Wiese; Angeln mit Elwynn-Fischen; Vier in einer Reihe, Minenfeld, Runenpaare und Kartenrücken mit Allianz-Motiven.

Zum Schluss: `/pastime debug` aus, `/reload`, dann Screenshots und Protokoll auswerten lassen.

## 2. Gesamtprüfung
- [ ] Auswahlfenster: Liste, Kategorien, Markierungen kurz/lang, Details, Bestenliste
- [ ] Reiserekorde-Ansicht, Landedialog, Landealarm
- [ ] Optionen → AddOns → Pastime, Minimap-Knopf, Addon-Fach, Tastenbelegung
- [ ] `/pastime hilfe` (DE) und `/pastime help` (EN)

## 3. Offene Entscheidungen
- [x] Blackjack: Knopf „Kasse machen“ (Lauf freiwillig beenden und Höchststand werten) – am 14.11. eingebaut, weil sonst jeder Lauf mit „Pleite“ endete. Gefällt es dir nicht: den Commit „Goblin Blackjack: cash out“ zurücknehmen.
- [x] Layout-Prüfer bleibt im Release (nur im Debug-Modus; hilft bei Fehlermeldungen).
- [x] Markennamen sind raus: Dateinamen, interne Spiel-IDs, Befehls-Kürzel und Kommentare (14.11.). Gespeicherte Bestenlisten, Streckenrekorde und Statistik ziehen beim ersten Start auf die neuen IDs um.
- [x] Logo: die Herkunftsdaten („erstellt mit Claude“) bleiben drin.
- [x] Changelog enthält nur Änderungen; die Funktionsübersicht steht in der CurseForge-Beschreibung (README).
- [x] Haltestellen-Koordinaten bleiben wie sie sind (fest im Addon, keine Abhängigkeit von anderen Addons; Quellen stehen im README).
- [x] Zeitvertreib statt Herausforderung: Tavernenwürfel zeigt „Gewonnen!“ ab 150 statt 200 Punkten.
- [x] Goblin-Minenfeld ist als „lang“ markiert (das 16×16-Feld dauert mehrere Minuten).
- [x] Fraktions-Thema für Horde und Allianz (Stufe 3 umgesetzt, Prüfung im Spiel steht unter 1.)

## 4. CurseForge
- [ ] Beta-Datei geprüft: Spielversion 1.60.1, Changelog sauber formatiert, Zip enthält nur den Ordner `Pastime` ohne `tests`, `media`, `README.md` und `TODO.md` (ob CurseForge das Muster `*.md` versteht, steht nicht in deren Doku; `CHANGELOG.md` darf im Zip liegen)
- [ ] GitHub-Repo: Beschreibung und Topics setzen (beides ist leer)
- [ ] Logo als PNG hochgeladen (nicht webp)
- [ ] Screenshots für die Galerie

## 5. Release
- [x] README (= CurseForge-Beschreibung) an die Änderungen anpassen (auch: Horde/Allianz-Varianten), Link zu den GitHub-Issues ergänzen – danach den Text auf der CurseForge-Seite ersetzen
- [x] CHANGELOG: Abschnitt `1.0.0` steht oben
- [x] Version in `Pastime.toc` und `Core.lua` prüfen (kommt jetzt aus dem Tag; im Beta-Zip nachsehen, ob in der TOC die Tag-Version steht)
- [x] Dateiliste der `.toc` prüfen (29 Einträge, alle vorhanden, keine doppelt)
- [x] Secret-Scan über die ganze Historie (14.11.: keine Treffer; jeder neue Commit wird einzeln geprüft)
- [x] Tag `v1.0.0` (15.11.; CurseForge baut daraus die Vollversion)
- [ ] GitHub-Release zum Tag anlegen (von Hand auf GitHub: *Releases → Draft a new release → v1.0.0*)

## 6. Ideen für 1.1
- [ ] Goblin-Automat: Freispiele und Scatter-Symbole
- [ ] Goblin-Roulette: Animation wie bei einem echten Kessel
- [ ] Tavernen-Hold'em: wer mitten in einer Hand geht, bekommt den Stand vor der Hand zurück – bei Bedarf den Einsatz der Hand abziehen
- [ ] Arbeitsordner von `Pastetime` in `Pastime` umbenennen (Sitzung schließen, umbenennen, neu öffnen)
