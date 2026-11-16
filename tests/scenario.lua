local ns = KW
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
local function fire(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function slash(s) SlashCmdList.PASTIME(s) end
local function tick(sec, step)
    step = step or 0.05
    local t = 0
    while t < sec do
        NOW = NOW + step
        local gv = ns.gameView
        if gv and gv.scripts.OnUpdate then gv.scripts.OnUpdate(gv, step) end
        if ns.frame and ns.frame.scripts.OnUpdate then ns.frame.scripts.OnUpdate(ns.frame, step) end
        t = t + step
    end
end
local function key(k)
    local gv = ns.gameView
    check(gv.kb, "Tastatur sollte aktiv sein für " .. k)
    gv.scripts.OnKeyDown(gv, k)
    local consumed = not gv.propagate
    gv.scripts.OnKeyUp(gv, k)
    return consumed
end
local function errors() return #ERRORS_FORWARDED end

-- Laden ---------------------------------------------------------------------
fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
check(PastimeDB and PastimeDB.settings.autoOpen == true, "DB-Standardwerte")
check(#ns.games == 24, "24 Spiele registriert, sind " .. #ns.games)
check(ns.minimapButton ~= nil, "Minimap-Knopf")
check(ns.VersionFrom("v1.0.0-beta2") == "v1.0.0-beta2" and ns.VersionFrom("@project-version@") == "dev"
    and ns.VersionFrom(nil) == "dev" and ns.VERSION == "dev", "Version kommt aus der TOC, ungepackt „dev“")
check(ns.FormatNumber(1054000) == "1.054.000" and ns.FormatNumber(999) == "999" and ns.FormatNumber(-1234) == "-1.234",
    "Zahlen mit Tausenderpunkt: " .. ns.FormatNumber(1054000))

-- Fenster + Auswahl ------------------------------------------------------------
slash("")
check(ns.frame and ns.frame:IsShown(), "Fenster offen nach /pastime")
check(ns.launcher:IsVisible() and not ns.gameView:IsVisible(), "Auswahl sichtbar")
local visibleRows = 0
for _, r in ipairs(ns.launcher.list.rows) do if r.shown then visibleRows = visibleRows + 1 end end
check(visibleRows == 27, "27 Listenzeilen (3 Kategorien + 24 Spiele), sind " .. visibleRows)
check(ns.launcher.list.rows[1].htext.text == "Geschicklichkeit", "Kategorie 1: " .. ns.launcher.list.rows[1].htext.text)
check(ns.launcher.list.rows[10].htext.text == "Knobeln", "Kategorie 2 an Pos. 10: " .. tostring(ns.launcher.list.rows[10].htext.text))
check(ns.launcher.list.rows[19].htext.text == "Würfel & Karten", "Kategorie 3 an Pos. 19")
-- Kategorie zuklappen
ns.launcher.list.rows[1]:Click()
visibleRows = 0
for _, r in ipairs(ns.launcher.list.rows) do if r.shown then visibleRows = visibleRows + 1 end end
check(visibleRows == 19, "nach Zuklappen 19 Zeilen, sind " .. visibleRows)
ns.launcher.list.rows[1]:Click()
-- Spiel wählen: Steinschlag (kurze Spiele stehen in jeder Kategorie zuerst)
local function rowOf(id)
    for _, r in ipairs(ns.launcher.list.rows) do if r.shown and r.item and r.item.def and r.item.def.id == id then return r end end
end
rowOf("rockfall"):Click()
check(rowOf("snake").best.text:find("kurz") and rowOf("rockfall").best.text:find("lang"), "Markierung kurz/lang")
local order = {}
for _, r in ipairs(ns.launcher.list.rows) do if r.shown then order[#order + 1] = r.item.header and ("[" .. r.item.cat.name .. "]") or r.item.def.name end end
print("Liste: " .. table.concat(order, ", "))
check(ns.selected and ns.selected.id == "rockfall", "Steinschlag ausgewählt")
check(ns.launcher.detail.title.text == "Steinschlag", "Detailtitel " .. ns.launcher.detail.title.text)
check(ns.launcher.detail.scoreLines[1].left.text:find("Noch keine"), "leere Bestenliste")
check(not ns.launcher.detail.modeHead.shown, "Steinschlag ohne Schwierigkeit")
-- Minenfeld zeigt Modi
ns.selected = ns.gamesById.minen
ns.UpdateUI()
check(ns.launcher.detail.modeHead.shown and ns.launcher.detail.modeButtons[2].text == "Mittel (16×16)", "Minen-Modi")

-- Snake ------------------------------------------------------------------------
ns.selected = ns.gamesById.snake
ns.UpdateUI()
ns.launcher.detail.play:Click()
local run = ns.run
check(run and run.def.id == "snake" and run.state == "running", "Snake läuft")
check(ns.gameView:IsVisible() and ns.gameView.kb, "Spielansicht + Tastatur an")
local g = run.game
check(#g.snake == 3 and g.waiting, "Snake wartet auf Taste")
tick(1)
check(g.snake[1].x == 11, "Snake bewegt sich vor Tastendruck nicht")
check(key("RIGHT"), "RIGHT verbraucht")
check(key("B"), "B (Taschen) wird im Spiel geschluckt")
check(key("SPACE"), "Leertaste (Springen) wird geschluckt")
check(key("1") and key("Q") and key("TAB") and key("NUMLOCK"), "Aktionsleiste/Ziel/Autorun werden geschluckt")
check(not key("ENTER"), "ENTER (Chat) wird weitergereicht")
check(not key("R"), "R (Antworten) wird weitergereicht")
check(not key("LSHIFT"), "Shift allein wird weitergereicht")
SHIFT = true
check(not key("7"), "Shift-7 (Chat mit /) wird weitergereicht")
SHIFT = false
-- Strg+S schaltet den Ton: darf weder die Natter lenken noch geschluckt werden
CTRL = true
BINDINGS["CTRL-S"] = "TOGGLESOUND"
check(not key("S") and #g.queue == 0, "Strg+S (Ton an/aus) wird weitergereicht und lenkt nicht")
check(key("W") and #g.queue == 0, "Strg+W ohne erlaubte Belegung wird geschluckt und lenkt nicht")
CTRL = false
-- Taste vor dem Spiel gedrückt (WoW hat das Drücken gesehen): Loslassen muss an WoW gehen
do
    local gv = ns.gameView
    gv.scripts.OnKeyUp(gv, "X")
    check(gv.propagate == true, "Loslassen einer vorher gedrückten Taste geht an WoW (kein Hängenbleiben)")
    gv.scripts.OnKeyDown(gv, "X")
    check(gv.propagate == false, "X-Drücken im Spiel geschluckt")
    gv.scripts.OnKeyUp(gv, "X")
    check(gv.propagate == false, "X-Loslassen danach auch geschluckt")
end
-- Futter direkt vor den Kopf legen
g.fx, g.fy = 12, 11
tick(0.16)
check(#g.snake == 4 and g.score == 10 and g.eaten == 1, "Ei gefressen (Länge " .. #g.snake .. ", Punkte " .. g.score .. ")")
-- Umkehr nicht erlaubt
key("LEFT")
tick(0.16)
check(g.snake[1].x == 13 and not g.dead, "Umkehr ignoriert, x=" .. g.snake[1].x)
-- Pause per Esc
check(key("ESCAPE"), "Esc verbraucht")
check(run.state == "paused" and not ns.gameView.kb and ns.overlay.shown, "Pause: Tastatur aus, Overlay an")
local x0 = g.snake[1].x
tick(1)
check(g.snake[1].x == x0, "steht in Pause")
ns.overlay.scripts.OnMouseUp(ns.overlay)
check(run.state == "running" and ns.gameView.kb and run.countdown == 3, "weiter per Klick, Countdown 3")
tick(2.9)
check(g.snake[1].x == x0 and run.countdown ~= nil, "steht während des Countdowns")
tick(0.2)
check(run.countdown == nil, "Countdown vorbei")
-- gegen die Wand
tick(3)
check(g.dead and run.state == "over", "Snake an Wand gestorben")
check(ns.overlay.title.text == "Spiel vorbei" and ns.overlay.text.text:find("Neuer Rekord"), "Rekord-Overlay: " .. ns.overlay.text.text)
check(PastimeDB.scores.snake and PastimeDB.scores.snake[1].s == g.score, "Snake-Rekord gespeichert")
check(PastimeDB.scores.snake[1].d:match("^%d%d%.%d%d%.%d%d$"), "Datum deutsch (TT.MM.JJ): " .. tostring(PastimeDB.scores.snake[1].d))
-- Leertaste = nochmal (nach der kurzen Sperre)
NOW = NOW + 2
check(key("SPACE"), "SPACE im Endbildschirm verbraucht")
check(ns.run.state == "running" and ns.run.game.score == 0, "Neustart per Leertaste")
check(PastimeDB.stats.games.snake.n == 2, "2 Partien gezählt")

-- Perle
g = ns.run.game
key("UP")
for i = 1, 5 do g.fx, g.fy = g.snake[1].x, g.snake[1].y - 1; tick(g.step + 0.001) end
check(g.eaten == 5 and g.pearl ~= nil, "Perle nach 5 Eiern")
tick(PEARL_WAIT or 7.5, 0.05)
check(g.pearl == nil or g.dead, "Perle verschwindet")

-- Steinschlag -----------------------------------------------------------------------
ns.StartGame(ns.gamesById.rockfall)
g = ns.run.game
check(g.cur ~= nil and g.next ~= nil, "Steinschlag: Stein + Vorschau")
check(ns.host.preview.shown, "Vorschaufläche sichtbar")
-- Reihe vorbereiten: unterste Reihe bis auf Spalte 0..3 voll, dann I waagrecht reinwerfen
for x = 4, 9 do g.board[19][x] = { 1, 0, 0 } end
g.cur = { kind = "I", n = 4, cells = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } }, x = 0, y = 0 }
key("SPACE")
check(g.clearing ~= nil, "Reihe wird gelöscht")
tick(0.3)
check(g.lines == 1 and g.score >= 100, "1 Reihe, Punkte " .. g.score)
local empty = true
for x = 0, 9 do if g.board[19][x] then empty = false end end
check(empty, "unterste Reihe leer")
-- Drehen + DAS
local before = g.cur.x
local gv = ns.gameView
gv.scripts.OnKeyDown(gv, "LEFT")
tick(0.5)
check(g.cur == nil or g.cur.x <= 0 or g.cur.x < before - 1, "gehaltene Taste wiederholt")
gv.scripts.OnKeyUp(gv, "LEFT")
key("UP")
-- Bis zum Ende fallen lassen
for i = 1, 200 do
    if ns.run.state ~= "running" then break end
    key("SPACE"); tick(0.3)
end
check(ns.run.state == "over" and g.dead, "Steinschlag endet, wenn der Turm oben ist")

-- Windreiter ----------------------------------------------------------------------
ns.StartGame(ns.gamesById.windrider)
g = ns.run.game
check(g.waiting, "Windreiter wartet")
check(not ns.host.preview.shown, "keine Vorschau bei Windreiter")
key("SPACE")
check(not g.waiting and g.vy < 0, "Flügelschlag")
-- Gut fliegen: immer in die Lücke zielen
for i = 1, 400 do
    local target
    for _, s in ipairs(g.pool) do
        if s.active and s.x + 54 > 110 - 12 then
            if not target or s.x < target.x then target = s end
        end
    end
    local aim = target and (target.top + target.bottom) / 2 + 12 or 200
    if g.y > aim and g.vy > -50 then g:Flap() end
    tick(0.02, 0.02)
    if g.dead then break end
end
check(g.score >= 3, "Windreiter schafft Nadeln: " .. g.score)
-- Absturz
for i = 1, 300 do tick(0.02, 0.02); if g.dead then break end end
check(g.dead and ns.run.state == "over", "Windreiter stürzt ab")

-- Minenfeld --------------------------------------------------------------------
ns.StartGame(ns.gamesById.minen, "leicht")
g = ns.run.game
check(ns.gameView.kb, "Minenfeld fängt die Tastatur auch")
check(key("W") and key("SPACE"), "Minenfeld: Bewegung/Springen geschluckt")
local cells = g.set.cells
cells[41].scripts.OnClick(cells[41], "LeftButton")
check(g.placed and g.open[41] and not g.dead, "erster Klick sicher")
local mines = 0
for i = 1, 81 do if g.mine[i] then mines = mines + 1 end end
check(mines == 10, "10 Minen, sind " .. mines)
for _, j in ipairs(g:Neighbors(41)) do check(not g.mine[j], "Nachbar " .. j .. " minenfrei") end
check(g.opened > 1, "Leerfeld deckt Nachbarn auf: " .. g.opened)
-- Fahne
local m1
for i = 1, 81 do if g.mine[i] then m1 = i; break end end
cells[m1].scripts.OnClick(cells[m1], "RightButton")
check(g.flag[m1] and g.flags == 1, "Fahne gesetzt")
tick(2)
check(g.time > 1.9, "Zeit läuft: " .. g.time)
-- alles Sichere aufdecken -> gewonnen
for i = 1, 81 do if not g.mine[i] and not g.open[i] then cells[i].scripts.OnClick(cells[i], "LeftButton") end end
check(g.won and ns.run.state == "over", "Minenfeld gewonnen")
check(PastimeDB.scores["minen:leicht"] and PastimeDB.scores["minen:leicht"][1].s > 1.9, "Zeit gespeichert")
check(ns.overlay.title.text == "Gewonnen!", "Overlay Gewonnen")
-- verlieren im mittleren Feld
ns.StartGame(ns.gamesById.minen, "mittel")
g = ns.run.game
check(g.m.cols == 16, "Modus mittel")
cells = g.set.cells
cells[1].scripts.OnClick(cells[1], "LeftButton")
for i = 1, 256 do if g.mine[i] then cells[i].scripts.OnClick(cells[i], "LeftButton"); break end end
check(g.dead and ns.run.state == "over" and ns.overlay.title.text == "BUMM!", "Mine explodiert")
check(PastimeDB.scores["minen:mittel"] == nil or #PastimeDB.scores["minen:mittel"] == 0, "Niederlage ohne Rekord")

-- 2048 -------------------------------------------------------------------------
local slide = ns.gamesById["2048"]._game and ns.gamesById["2048"]._game.slide
ns.StartGame(ns.gamesById["2048"])
g = ns.run.game
slide = g.slide
local function eq(a, b) return table.concat(a, ",") == table.concat(b, ",") end
check(eq(slide({ 2, 2, 2, 2 }), { 4, 4, 0, 0 }), "2,2,2,2 -> 4,4")
check(eq(slide({ 2, 2, 4, 0 }), { 4, 4, 0, 0 }), "2,2,4 -> 4,4 (kein Doppelverschmelzen)")
check(eq(slide({ 0, 4, 0, 4 }), { 8, 0, 0, 0 }), "0,4,0,4 -> 8")
g.cells = { { 2, 2, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
key("LEFT")
check(g.cells[1][1] == 4 and g.score == 4, "Verschmelzen nach links")
g.cells = { { 2, 4, 2, 4 }, { 4, 2, 4, 2 }, { 32, 64, 32, 64 }, { 8, 16, 8, 0 } }
g.score = 100
key("RIGHT")
check(ns.run.state == "over", "2048: keine Züge mehr")
check(PastimeDB.scores["2048"] and PastimeDB.scores["2048"][1].s == 100, "2048-Punkte gespeichert")
tick(0.5)

-- Abbrechen zählt nicht ---------------------------------------------------------
local nSnake = #PastimeDB.scores.snake
ns.StartGame(ns.gamesById.snake)
g = ns.run.game
key("RIGHT"); g.fx, g.fy = 12, 11; tick(0.16)
check(g.score == 10, "Snake hat Punkte vor Abbruch")
ns.gameView.side.back:Click()
check(ns.run == nil and ns.launcher:IsVisible(), "Zur Auswahl beendet die Partie")
check(#PastimeDB.scores.snake == nSnake, "abgebrochene Partie wird NICHT gewertet")
ns.StartGame(ns.gamesById.snake)
g = ns.run.game
key("RIGHT"); g.fx, g.fy = 12, 11; tick(0.16)
ns.gameView.side.restart:Click()
check(#PastimeDB.scores.snake == nSnake and ns.run.game.score == 0, "Neu starten wertet nicht")
key("ESCAPE")
ns.overlay.btn2:Click()   -- „Beenden“ in der Pause
check(ns.run == nil and #PastimeDB.scores.snake == nSnake, "Beenden in der Pause wertet nicht")

-- Flug mit Streckenwertung ---------------------------------------------------------
ns.frame:Hide()
TakeTaxiNode(2)
check(TAKEN == 2, "Original-TakeTaxiNode aufgerufen")
ONTAXI = true
fire("PLAYER_CONTROL_LOST")
RunTimers()
local trip = ns.trip
check(trip.active and trip.kind == "flug" and trip.to == "Orgrimmar, Durotar" and trip.from == "Crossroads, Brachland", "Flug erkannt mit Route")
check(ns.frame:IsShown() and ns.launcher:IsVisible(), "Auswahl öffnet sich beim Abflug")
check(ns.launcher.status.text:find("Orgrimmar"), "Fußzeile zeigt Flug: " .. ns.launcher.status.text)
check(ns.launcher.detail.route.shown and ns.launcher.detail.route.text:find("noch kein Eintrag"), "Streckenzeile in Details: " .. ns.launcher.detail.route.text)
-- Partie 1: Snake stirbt im Flug -> Streckenrekord sofort
ns.StartGame(ns.gamesById.snake)
g = ns.run.game
check(ns.run.tripId == trip.id, "Partie gehört zum Flug")
key("RIGHT"); g.fx, g.fy = 12, 11; tick(0.16)
tick(3)
check(ns.run.state == "over", "Snake im Flug vorbei")
local fkey = "flug:Crossroads, Brachland > Orgrimmar, Durotar"
local froute = PastimeDB.routes[fkey]
check(froute and froute.scores.snake and froute.scores.snake[1].s == 10, "Streckenrekord Snake gespeichert")
check(ns.overlay.text.text:find("Streckenrekord Crossroads » Orgrimmar"), "Overlay nennt Streckenrekord: " .. ns.overlay.text.text)
-- Partie 2: 2048 läuft noch bei der Landung
ns.StartGame(ns.gamesById["2048"])
g = ns.run.game
g.cells = { { 2, 2, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
key("LEFT")
check(g.score == 4, "2048 hat 4 Punkte")
check(ns.gameView.side.route.text:find("Strecke"), "Seitenleiste zeigt Strecke: " .. ns.gameView.side.route.text)
NOW = NOW + 120
ONTAXI = false
local sounds = #SOUNDS
fire("PLAYER_CONTROL_GAINED")
RunTimers()
check(not trip.active, "gelandet")
check(ns.run.state == "paused" and ns.overlay.kind == "landed", "Landedialog")
check(ns.overlay.title.text == "Gelandet in Orgrimmar!", "Titel: " .. ns.overlay.title.text)
check(ns.overlay.text.text:find("Streckenwertung") and ns.overlay.text.text:find("neuer Streckenrekord"), "Streckenwertung im Dialog: " .. ns.overlay.text.text)
check(ns.overlay.btn1.text == "Weiterspielen" and ns.overlay.btn2.text == "Beenden & werten", "Knöpfe Weiterspielen / Beenden & werten")
check(froute.scores["2048"] and froute.scores["2048"][1].s == 4, "Landestand 2048 für die Strecke gespeichert")
check(ns.alertFrame.title.text == "Gelandet!" and ns.alertFrame.sub.text == "Orgrimmar", "großer Landealarm")
check(FLASHED >= 1 and #SOUNDS > sounds, "Ton + Taskleiste blinkt")
check(froute.t and froute.t >= 120 and froute.n == 1, "Flugzeit gemerkt: " .. tostring(froute.t))
-- Klick daneben setzt NICHT fort
ns.overlay.scripts.OnMouseUp(ns.overlay)
check(ns.run.state == "paused", "Landedialog braucht Knopfdruck")
-- Weiterspielen: Ergebnis zählt danach nur noch allgemein
ns.overlay.btn1:Click()
check(ns.run.state == "running" and ns.run.tripId == nil and ns.run.landed == nil, "weitergespielt")
g.cells = { { 2, 4, 2, 4 }, { 4, 2, 4, 2 }, { 32, 64, 32, 64 }, { 8, 16, 8, 0 } }
g.score = 50
key("RIGHT")
check(ns.run.state == "over", "2048 nach Landung beendet")
check(#froute.scores["2048"] == 1, "nach der Landung kein weiterer Streckeneintrag")
local found50 = false
for _, e in ipairs(PastimeDB.scores["2048"]) do if e.s == 50 then found50 = true end end
check(found50, "Endergebnis 50 in der allgemeinen Bestenliste")

-- Landung mit „Beenden & werten“ ------------------------------------------------
ns.frame:Hide()
TakeTaxiNode(3); ONTAXI = true; fire("PLAYER_CONTROL_LOST"); RunTimers()
check(trip.active and trip.to == "Ratchet, Brachland", "zweiter Flug nach Ratchet")
ns.StartGame(ns.gamesById.rockfall)
g = ns.run.game
key("SPACE")
local tscore = g.score
check(tscore > 0, "Steinschlag hat Punkte: " .. tscore)
NOW = NOW + 90; ONTAXI = false; RunTickers()
check(ns.overlay.kind == "landed", "Landedialog Steinschlag")
ns.overlay.btn2:Click()
check(ns.run.state == "over" and ns.overlay.title.text == "Gewertet", "Beenden & werten")
local nT = 0
for _, e in ipairs(PastimeDB.scores.rockfall or {}) do if e.s == tscore then nT = nT + 1 end end
check(nT == 1, "Steinschlag allgemein genau einmal gewertet (" .. nT .. ")")
local rr = PastimeDB.routes["flug:Crossroads, Brachland > Ratchet, Brachland"]
check(rr and rr.scores.rockfall and rr.scores.rockfall[1].s == tscore, "Steinschlag auf Strecke Ratchet")

-- Wiederholter Flug: Restzeit bekannt; ungenutzt -> Fenster schließt sich
ns.ShowLauncher()
ns.frame:Hide()
TakeTaxiNode(2); ONTAXI = true; fire("PLAYER_CONTROL_LOST"); RunTimers()
local st = ns.TripStatus()
check(st:find("Landung in ca. 2:0"), "Restzeit: " .. st)
ONTAXI = false; NOW = NOW + 60; RunTickers()
check(not trip.active and not ns.frame:IsShown(), "unbenutztes Fenster schließt sich bei Landung")
check(PastimeDB.routes[fkey].n == 2, "Flug gezählt")

-- Testflug-Befehl --------------------------------------------------------------
slash("testflug 10")
check(trip.active and trip.simulated and trip.kind == "test" and ns.frame:IsShown(), "Testflug startet")
ns.StartGame(ns.gamesById.snake)
g = ns.run.game
key("RIGHT"); g.fx, g.fy = 12, 11; tick(0.16)
NOW = NOW + 11
RunTickers()
check(not trip.active and ns.overlay.kind == "landed", "Testflug landet mit Dialog")
check(PastimeDB.routes["test:Testgelände > Orgrimmar"] ~= nil, "Teststrecke angelegt")
slash("testflug löschen")
check(PastimeDB.routes["test:Testgelände > Orgrimmar"] == nil, "Teststrecken gelöscht")
ns.ShowLauncher()

-- Zeppelin Orgrimmar -> Undercity ---------------------------------------------------
local function ttick(n) for _ = 1, n or 1 do NOW = NOW + 0.5; ns.TransportTick() end end
ns.frame:Hide()
PLAYER.map, PLAYER.x, PLAYER.y = 1411, 0.5082, 0.1354
SPEED, MOVING = 0, false
ttick(4)
check(not trip.active, "nach 2 s noch kein Warten")
ttick(8)
check(trip.active and trip.kind == "zeppelin" and trip.phase == "wait" and trip.from == "Orgrimmar" and trip.to == "Undercity", "wartet auf Zeppelin nach Undercity: " .. tostring(trip.to))
check(not ns.frame:IsShown(), "am Zeppelinturm bleibt das Fenster zu: es öffnet sich erst bei der Abfahrt")
ns.ShowFrame()
check(ns.launcher.status.text:find("Du wartest auf den Zeppelin nach Undercity"), "Status: " .. ns.launcher.status.text)
ns.StartGame(ns.gamesById["2048"])
g = ns.run.game
g.cells = { { 2, 2, 0, 0 }, { 4, 4, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
key("LEFT")
check(g.score == 12, "2048: 12 Punkte")
-- Zeppelin legt ab: wir werden bewegt, ohne zu laufen
for i = 1, 6 do PLAYER.x = PLAYER.x + 0.0015; ttick(1) end
check(trip.phase == "ride" and trip.start ~= nil, "Abfahrt erkannt")
check(ns.TripStatus():find("Zeppelin nach Undercity"), "Status Fahrt: " .. ns.TripStatus())
for i = 1, 20 do PLAYER.x = PLAYER.x + 0.0015; ttick(1) end
-- Ladebildschirm: anderer Kontinent, kurz vor dem Turm in Tirisfal
PLAYER.map, PLAYER.x, PLAYER.y = 1420, 0.5900, 0.5887
ttick(1)
for i = 1, 4 do PLAYER.x = PLAYER.x + 0.0035; ttick(1) end
check(trip.active, "noch unterwegs, solange er fährt")
ttick(8)   -- legt in Undercity an
check(not trip.active, "Ankunft erkannt")
local zkey = "zeppelin:Orgrimmar > Undercity"
local zr = PastimeDB.routes[zkey]
check(zr and zr.n == 1 and zr.t and zr.t > 5, "Zeppelinstrecke gemerkt: " .. tostring(zr and zr.t))
check(ns.overlay.kind == "landed" and ns.overlay.title.text == "Angekommen in Undercity!", "Ankunftsdialog: " .. ns.overlay.title.text)
check(zr.scores["2048"] and zr.scores["2048"][1].s == 12, "2048-Stand für Zeppelinstrecke")
check(ns.alertFrame.title.text == "Angekommen!", "Ankunftsalarm")
ns.overlay.btn2:Click()
check(ns.run.state == "over", "beendet & gewertet")
-- am Ankunftsturm stehen: kein neues Warten, bis man weggeht
ttick(16)
check(not trip.active, "nach Ankunft kein sofortiges Warten")
-- Spiel endet während der Fahrt -> erst bei Ankunft für die Strecke
MOVING = true
for i = 1, 6 do PLAYER.y = PLAYER.y + 0.006; ttick(1) end
MOVING = false
PLAYER.x, PLAYER.y = 0.6074, 0.5887
ns.frame:Hide()
ttick(12)
check(trip.active and trip.phase == "wait" and trip.from == "Undercity" and trip.to == "Orgrimmar", "wartet in Undercity auf Orgrimmar: " .. tostring(trip.to))
check(not ns.frame:IsShown(), "Warten in Undercity: Fenster bleibt zu")
for i = 1, 4 do PLAYER.x = PLAYER.x - 0.002; ttick(1) end
check(trip.phase == "ride", "Abfahrt Undercity")
check(ns.frame:IsShown() and ns.launcher:IsVisible(), "Fenster öffnet sich bei der Abfahrt")
ns.StartGame(ns.gamesById.windrider)
g = ns.run.game
key("SPACE")
g.score = 3
for i = 1, 200 do tick(0.02, 0.02); if g.dead then break end end
check(ns.run.state == "over" and ns.overlay.text.text:find("sobald du ankommst"), "Ergebnis vorgemerkt: " .. ns.overlay.text.text)
check(PastimeDB.routes["zeppelin:Undercity > Orgrimmar"] == nil, "Strecke noch nicht angelegt")
PLAYER.map, PLAYER.x, PLAYER.y = 1411, 0.5082, 0.1354
ttick(1); ttick(8)
local back = PastimeDB.routes["zeppelin:Undercity > Orgrimmar"]
check(back and back.scores.windrider and back.scores.windrider[1].s == 3, "vorgemerktes Ergebnis bei Ankunft eingetragen")
-- Warten und wieder gehen: verworfen, Fenster schließt sich
MOVING = true
for i = 1, 6 do PLAYER.y = PLAYER.y + 0.01; ttick(1) end
MOVING = false
PLAYER.x, PLAYER.y = 0.5069, 0.1289
ns.ShowLauncher(); ns.frame:Hide()
ttick(12)
check(trip.active and trip.phase == "wait" and trip.to == "Grom'gol" and not ns.frame:IsShown(), "Grom'gol-Seite erkannt, Fenster bleibt zu")
MOVING = true
for i = 1, 6 do PLAYER.y = PLAYER.y + 0.01; ttick(1) end
check(not trip.active and not ns.frame:IsShown(), "weggegangen: verworfen, Fenster zu")
check(PastimeDB.routes["zeppelin:Orgrimmar > Grom'gol"] == nil, "keine Strecke für verworfene Wartezeit")
MOVING = false
-- /pastime fotos: acht Szenen, je ein Screenshot, nichts wird gewertet oder gespeichert
do
    local shots, scoresBefore, goldBefore = 0, 0, PastimeDB.blackjack.gold
    Screenshot = function() shots = shots + 1 end
    for _, list in pairs(PastimeDB.scores) do scoresBefore = scoresBefore + #list end
    local purses = 0
    for _ in pairs(PastimeDB.purses) do purses = purses + 1 end
    local realScores, realRoutes = PastimeDB.scores, PastimeDB.routes
    slash("fotos")
    check(PastimeDB.scores ~= realScores and PastimeDB.scores.rockfall[1].p == "Thokk" and ns.staging, "Fototour: zeigt Beispiel-Rekorde")
    for _ = 1, 40 do RunTimers() end
    local scoresAfter, pursesAfter = 0, 0
    for _, list in pairs(PastimeDB.scores) do scoresAfter = scoresAfter + #list end
    for id, p in pairs(PastimeDB.purses) do if p.table then pursesAfter = pursesAfter + 100 end; pursesAfter = pursesAfter + 1 end
    check(shots == 8, "Fototour: acht Screenshots, sind " .. shots)
    check(scoresAfter == scoresBefore and PastimeDB.blackjack.gold == goldBefore and pursesAfter < 100, "Fototour: nichts gewertet, kein Tisch gespeichert")
    check(ns.launcher:IsVisible() and not ns.run, "Fototour: endet in der Spielauswahl")
    check(ns.staging == nil, "Fototour: die Wertungssperre ist wieder aufgehoben")
    check(PastimeDB.scores == realScores and PastimeDB.routes == realRoutes, "Fototour: die echten Rekorde und Strecken sind zurück")
    ns.StartGame(ns.gamesById.kodo)
    ns.staging = true
    ns.GameOver({ score = 99999 })
    ns.staging = nil
    local kodoBest = PastimeDB.scores.kodo and PastimeDB.scores.kodo[1] and PastimeDB.scores.kodo[1].s
    check(ns.run.state == "over" and kodoBest ~= 99999, "Fototour: ein Spielende in einer gestellten Szene wird nicht gewertet")
    ns.ShowLauncher()
    local errs = 0
    for _, e in ipairs(PastimeDB.log) do if e.l == "E" then errs = errs + 1; print("  " .. e.c .. ": " .. e.m) end end
    check(errs == 0, "Fototour: keine Fehler im Protokoll")
end
slash("hafen")

-- Reiserekorde-Ansicht ----------------------------------------------------------
ns.ShowFrame("records")
check(ns.records:IsVisible() and not ns.launcher:IsVisible(), "Reiserekorde sichtbar")
check(ns.frame.tabs[2].selectedTab and not ns.frame.tabs[1].selectedTab, "Reiter 2 aktiv")
local rows = ns.records.list.rows
local headers = {}
for _, r in ipairs(rows) do if r.shown and r.item.header then table.insert(headers, r.htext.text) end end
check(table.concat(headers, ",") == "Flüge (2),Zeppeline (2)", "Gruppen: " .. table.concat(headers, ","))
local flugRow
for _, r in ipairs(rows) do if r.shown and not r.item.header and r.item.key == fkey then flugRow = r end end
flugRow:Click()
local body = ns.records.detail.body.text
check(ns.records.detail.title.text == "Crossroads » Orgrimmar", "Titel Strecke: " .. ns.records.detail.title.text)
check(body:find("Windnatter") and body:find("2048") and body:find("1%."), "Platzierungen: " .. body)
check(ns.records.detail.sub.text:find("2× gereist"), "Untertitel: " .. ns.records.detail.sub.text)
ns.frame.tabs[1]:Click()
check(ns.launcher:IsVisible() and ns.frame.tabs[1].selectedTab, "zurück zu Spiele")

-- Kampf ------------------------------------------------------------------------
ns.ShowFrame()
ns.StartGame(ns.gamesById["2048"])
check(ns.gameView.kb, "Tastatur vor Kampf an")
fire("PLAYER_REGEN_DISABLED")
COMBAT = true
check(ns.run.state == "paused" and not ns.frame:IsShown() and not ns.gameView.kb, "Kampf: Pause + ausgeblendet + Tastatur aus")
slash("")
check(ns.frame:IsShown() and ns.run.state == "paused", "nach /pastime im Kampf weiter pausiert")
ns.Resume()
check(ns.run.state == "paused", "Fortsetzen im Kampf gesperrt")
ns.gameView.scripts.OnKeyDown(ns.gameView, "LEFT")  -- darf keinen Fehler werfen
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
ns.Resume()
check(ns.run.state == "running" and ns.gameView.kb, "nach Kampf fortsetzbar")
-- Kampf auf dem Spielende-Bildschirm, Fenster bleibt offen: die Tastatur muss frei sein.
-- (InCombatLockdown() ist im Ereignis PLAYER_REGEN_DISABLED noch false.)
PastimeDB.settings.hideInCombat = false
ns.StartGame(ns.gamesById.snake)
key("RIGHT"); tick(3)
check(ns.run.state == "over" and ns.gameView.kb, "Endbildschirm fängt die Tastatur")
fire("PLAYER_REGEN_DISABLED")
check(ns.frame:IsShown() and not ns.gameView.kb, "Kampf auf dem Endbildschirm: Tastatur frei, obwohl das Fenster offen bleibt")
fire("PLAYER_REGEN_ENABLED")
check(ns.gameView.kb, "nach dem Kampf fängt der Endbildschirm die Tastatur wieder")
PastimeDB.settings.hideInCombat = true
slash("snake")
check(ns.run.def.id == "snake", "/pastime snake startet direkt")
slash("rekorde")
slash("hilfe")
slash("auto")
check(PastimeDB.settings.autoOpen == false, "/pastime auto schaltet um")
slash("auto")
slash("log")

-- Klänge: Spiel leise über Effekte, Alarm über Master
local chOk, alarmMaster = true, false
for i, id in ipairs(SOUNDS) do
    if id == SOUNDKIT.READY_CHECK then alarmMaster = alarmMaster or SOUND_CH[i] == "Master"
    elseif SOUND_CH[i] ~= "SFX" then chOk = false end
end
check(chOk and alarmMaster, "Spielklänge über Effekte-Kanal, Alarm über Master")
local coin = 0
for _, id in ipairs(SOUNDS) do if id == SOUNDKIT.LOOT_WINDOW_COIN_SOUND then coin = coin + 1 end end
check(coin <= 3, "Münzklang nur noch für Besonderes (" .. coin .. "×)")

-- Debug ----------------------------------------------------------------------------
local traces = PastimeDB.traces or {}
local ev = {}
for _, tr in ipairs(traces) do table.insert(ev, tr.e) end
check(#traces >= 4, "Reise-Mitschnitte gespeichert: " .. table.concat(ev, ","))
local zepTrace
for _, tr in ipairs(traces) do if tr.e == "ankunft" and tr.info:find("zeppelin") then zepTrace = tr end end
check(zepTrace and #zepTrace.s > 5 and zepTrace.s[#zepTrace.s]:find("Undercity") or zepTrace.s[#zepTrace.s]:find("Orgrimmar"),
    "Zeppelin-Ankunft mit Messpunkten: " .. (zepTrace and (#zepTrace.s .. " · " .. tostring(zepTrace.s[#zepTrace.s])) or "-"))
check(PastimeDB.traces[#PastimeDB.traces].s ~= nil, "Mitschnitt hat Punkte-Liste")
slash("debug")
check(PastimeDB.debug and ns.debugPanel and ns.debugPanel.shown, "Debug-Fenster offen")
ns.debugPanel.scripts.OnUpdate(ns.debugPanel, 1)
local dtext = ns.debugPanel.text.text
check(dtext:find("Dock") and dtext:find("Trip") and dtext:find("Taxi"), "Debug-Fenster zeigt Messwerte:\n" .. dtext)
local diag = ns.DiagReport()
check(diag:find("== Now ==") and diag:find("Trip traces") and diag:find("zeppelin:Orgrimmar > Undercity"), "Diagnosebericht")
check(not diag:find("|c"), "Diagnose ohne Farbcodes")
slash("diag")
check(ns.copyFrame.shown and ns.copyFrame.title.text == "Pastime-Fehlerbericht", "/pastime diag öffnet Kopierfenster")
-- Protokoll: stille Client-Fehlschläge werden gemeldet, Debug-Zeilen laufen im Kurzzeitspeicher mit
slash("debug")      -- aus
local before = #PastimeDB.log
ns.Log("D", "test", "leise Zeile")
check(#PastimeDB.log == before and not ns.FormatLog(400):find("leise Zeile") and ns.FormatLog(400, false, true):find("leise Zeile"),
    "Protokoll: Debug-Zeile ohne Debug-Modus nur im Kurzzeitspeicher, der Bericht nimmt sie mit")
local okT, vT = ns.Try("Probe", function(x) return x * 2 end, 21)
check(okT and vT == 42 and ns.fails.Probe == nil, "ns.Try: Erfolg reicht die Rückgabe durch")
for _ = 1, 3 do ns.Try("Kaputt", function() error("gibt es nicht") end) end
local warn = 0
for _, e in ipairs(PastimeDB.log) do if e.l == "W" and e.c == "client" and e.m:find("Kaputt") then warn = warn + 1 end end
check(warn == 1 and ns.fails.Kaputt.n == 3, "ns.Try: Fehlschlag einmal als Warnung im Protokoll, danach gezählt")
ns.Log("E", "test", "Testfehler")
local posD, posE
for i, e in ipairs(PastimeDB.log) do
    if e.m == "leise Zeile" then posD = i elseif e.m == "Testfehler" then posE = i end
end
check(posD and posE and posD < posE, "Protokoll: bei einem Fehler wandern die Debug-Zeilen davor ins gespeicherte Protokoll")
PastimeDB.scores.kodo = { { s = 5, p = "Fremdername", d = "x" } }
ns.Log("I", "test", "Besuch von Fremdername und " .. ns.playerName)
local report = ns.DiagReport()
check(not report:find(ns.playerName, 1, true) and not report:find("Fremdername", 1, true) and report:find("Besuch von Char%d and Char%d") == nil
    and report:find("Besuch von Char%d und Char%d"), "Bericht: Charakternamen sind ersetzt")
local oldInfo = { d = "2020-01-01 00:00:00", t = 1, l = "I", c = "alt", m = "uralte Info", s = -5 }
local oldWarn = { d = "2020-01-01 00:00:00", t = 1, l = "W", c = "alt", m = "uralte Warnung", s = -5 }
table.insert(PastimeDB.log, 1, oldWarn); table.insert(PastimeDB.log, 1, oldInfo)
local trimmed = ns.DiagReport()
check(not trimmed:find("uralte Info", 1, true) and trimmed:find("uralte Warnung", 1, true), "Bericht: aus alten Sitzungen nur Fehler und Warnungen")
table.remove(PastimeDB.log, 1); table.remove(PastimeDB.log, 1)
check(report:find("Kaputt: 3× since", 1, true) and report:find("== Log", 1, true), "Bericht: nennt fehlgeschlagene Client-Aufrufe und das Protokoll")
PastimeDB.scores.kodo = nil
table.remove(PastimeDB.log, posE)      -- der Testfehler soll die Fehlerprüfung am Ende nicht stören
slash("debug")      -- wieder an
ns.Log("W", "test", "Testwarnung")
check(ns.FormatLog(50, true):find("Testwarnung") and not ns.FormatLog(50, true):find("INFO"), "log fehler filtert")
ns.debugPanel.scripts.OnUpdate(ns.debugPanel, 1)
slash("debug")
check(not PastimeDB.debug and not ns.debugPanel.shown, "Debug wieder aus")
print("---- Diagnose (Auszug) ----")
local n = 0
for line in diag:gmatch("[^\n]+") do n = n + 1; if n <= 26 then print("  " .. line) end end
print("---- Debug-Fenster ----")
for line in dtext:gmatch("[^\n]+") do print("  " .. line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- Fehlerfreiheit ---------------------------------------------------------------
-- Selbsttest: prüft Schnittstellen, Klänge, Texturen und Addon-Nachrichten und öffnet das Ergebnis
local debugWas = PastimeDB.debug
SlashCmdList.PASTIME("debug testlauf")
check(ns.selfTest == nil and ns.selfFrame.shown and ns.selfFrame.quick:IsShown() and ns.selfFrame.step.text == ns.L["What should be tested?"],
    "Selbsttest: ohne Zusatz fragt das Fenster, was getestet werden soll")
ns.selfFrame.quick.scripts.OnClick(ns.selfFrame.quick)
check(ns.selfTest ~= nil and not ns.selfFrame.quick:IsShown(), "Selbsttest: „Schnelltest“ startet ihn")
RunTimers()
check(ns.selfTest == nil and ns.copyFrame.shown and ns.copyFrame.text:find("sounds: not tested", 1, true) and not ns.copyFrame.text:find("sound fanfare", 1, true),
    "Selbsttest: der Schnelltest lässt die Klänge aus")
ns.copyFrame:Hide()
SlashCmdList.PASTIME("debug testlauf klang")
check(PastimeDB.debug == debugWas and ns.selfTest ~= nil, "Selbsttest: startet, ohne den Debug-Modus umzuschalten")
check(ns.selfFrame.shown and #ns.selfFrame.icons >= 30 and ns.selfFrame.step.text == ns.L["Checking the client …"],
    "Selbsttest: ein Fenster zeigt, was geprüft wird, und alle Symbolbilder")
RunTimers()
local st = ns.copyFrame.text or ""
check(ns.selfTest == nil and ns.copyFrame.shown and ns.copyFrame.title.text == ns.L["Pastime self-test"], "Selbsttest: das Ergebnis öffnet sich zum Kopieren")
check(st:find("Pastime self%-test: %d+ problem") and st:find("API C_Timer.After", 1, true) and st:find("sound fanfare (kit 888)", 1, true) and st:find("direct messages confirmed earlier", 1, true)
    and (st:find("guild list:", 1, true) or not ns.Comm.registered)
    and st:find("daily task:", 1, true) and st:find("textures:", 1, true), "Selbsttest: Schnittstellen, Klänge, Texturen und Tagesaufgabe stehen im Ergebnis")
check(not st:find("Thokk", 1, true), "Selbsttest: kein Charaktername im Ergebnis")
check(ns.selfFrame.step.text == (ns.L["Done: %d problem(s)"]):format(tonumber(st:match("(%d+) problem"))),
    "Selbsttest: das Fenster zeigt am Ende das Ergebnis: " .. tostring(ns.selfFrame.step.text))
ns.selfFrame:Hide()
ns.copyFrame:Hide()

-- Das Fenster schließen bricht den Selbsttest ab; danach lässt er sich neu starten
SlashCmdList.PASTIME("debug test schnell")
ns.selfFrame:Hide()
check(ns.selfTest == nil, "Selbsttest: Fenster zu bricht ihn ab")
ns.copyFrame:Hide()
RunTimers()
check(not ns.copyFrame.shown, "Selbsttest: abgebrochen öffnet sich kein Ergebnis")
SlashCmdList.PASTIME("debug test schnell")
check(ns.selfTest ~= nil, "Selbsttest: lässt sich danach neu starten")
RunTimers()
ns.selfFrame:Hide(); ns.copyFrame:Hide()

-- Daten-Auszug: maskiert, mit „klar“ im Klartext
SlashCmdList.PASTIME("debug dump")
local dump = ns.copyFrame.text or ""
check(ns.copyFrame.shown and ns.copyFrame.title.text == ns.L["Pastime data dump"] and dump:find("== Battle.net friends ==", 1, true)
    and dump:find("masked", 1, true) and not dump:find("Thokk", 1, true), "Daten-Auszug: maskiert steht kein Name darin")
SlashCmdList.PASTIME("debug dump klar")
dump = ns.copyFrame.text or ""
check(dump:find("PLAIN TEXT", 1, true) and dump:find('UnitName(player): "Thokk"', 1, true), "Daten-Auszug: mit „klar“ im Klartext, mit Warnhinweis")
ns.copyFrame:Hide()

-- „Was gewinnt?“: eigener Knopf bei den Karten- und Goldspielen
ns.StartGame(ns.gamesById.holdem)
local side = ns.gameView.side
check(side.wins:IsShown() and side.wins:IsEnabled(), "Hold'em: der Knopf „Was gewinnt?“ ist da")
side.wins.scripts.OnClick(side.wins)
local wt = ns.overlay.text.text
check(ns.run.state == "paused" and ns.overlay.title.text == ns.L["What wins?"] and wt:find("1. |cffffd100" .. ns.Cards.HANDS[9], 1, true)
    and wt:find("9. |cffffd100" .. ns.Cards.HANDS[1], 1, true) and wt:find(ns.L["Your best five out of seven cards count. Equal hands split the pot."], 1, true),
    "Hold'em: die Rangfolge vom Straight Flush bis zur höchsten Karte, dazu die Hold'em-Regel")
local function place(i) return wt:find("|cffffd100" .. ns.Cards.HANDS[i] .. "|r", 1, true) end
check(place(5) < place(4) and place(4) < place(3) and place(3) < place(2),
    "Straße steht vor Drilling, Drilling vor zwei Paaren, zwei Paare vor einem Paar")
local heart, spade = ns.Cards.SUITS[1].glyph, ns.Cards.SUITS[3].glyph
check(wt:find("5" .. heart, 1, true) and wt:find("9" .. heart, 1, true) and wt:find(ns.Cards.RANKS[12] .. spade, 1, true)
    and ns.Cards.Example({ 1, 3, 13, 1 }) == "|cffd8d8d8" .. ns.Cards.RANKS[1] .. spade .. "|r |cffff6060" .. ns.Cards.RANKS[13] .. heart .. "|r",
    "jedes Blatt hat ein Beispiel mit Kartenzeichen, rote Farben rot")
ns.Resume()
for _, id in ipairs({ "drawpoker", "blackjack", "higherlower", "roulette", "slots" }) do
    ns.StartGame(ns.gamesById[id])
    check(side.wins:IsShown() and #ns.gamesById[id].wins() > 40, id .. ": erklärt, was gewinnt")
end
ns.StartGame(ns.gamesById.snake)
check(not side.wins:IsShown(), "Windnatter: kein solcher Knopf")
ns.ShowLauncher()

-- Kein Regel- oder Gewinn-Fenster darf höher sein als das Spielfeld, über dem es liegt
for _, def in ipairs(ns.games) do
    ns.StartGame(def, ns.DefaultMode(def))
    ns.ShowRules()
    check(ns.overlay.box:GetHeight() <= def.height - 8, ("%s: die Spielregeln passen ins Spielfeld (%d von %d)"):format(def.id, ns.overlay.box:GetHeight(), def.height - 8))
    ns.Resume()
    if def.wins then
        ns.ShowWins()
        check(ns.overlay.box:GetHeight() <= def.height - 8 and ns.overlay.box:GetWidth() <= def.width - 8,
            ("%s: „Was gewinnt?“ passt ins Spielfeld (%d von %d)"):format(def.id, ns.overlay.box:GetHeight(), def.height - 8))
    end
    ns.ShowLauncher()
end

-- Spielregeln: oben die Steuerung, darunter die ausführliche Erklärung – für jedes Spiel
for _, def in ipairs(ns.games) do
    check(type(ns.HELP[def.id]) == "string" and #ns.HELP[def.id] > 150, def.id .. ": hat eine ausführliche Erklärung")
end
ns.StartGame(ns.gamesById.snake)
ns.ShowRules()
local rt = ns.overlay.text.text
local pc, ph = rt:find(ns.L["Controls"], 1, true), rt:find(ns.L["How to play"], 1, true)
check(pc and ph and pc < ph and rt:find(ns.HELP.snake, 1, true) and rt:find(ns.gamesById.snake.controls, 1, true) < ph,
    "Spielregeln: erst die Steuerung, dann die ausführliche Erklärung")
ns.ShowLauncher()

-- Reiter „Einstellungen“: dieselben Schalter wie im Addon-Menü
ns.ShowFrame("settings")
local sv = ns.settingsView
check(sv:IsShown() and not ns.launcher:IsShown() and #sv.checks == 12 and sv.checks[5]:IsShown() and not sv.checks[6]:IsShown() and not sv.checks[12]:IsShown(),
    "Einstellungen: der Reiter zeigt fünf Schalter; die sieben für den Mehrspieler erst, wenn er freigeschaltet ist")
check(not ns.frame.tabs[3]:IsShown() and ns.frame.tabs[3].key == "mp" and ns.mpAskFrame == nil, "ohne Freischaltung gibt es keinen Reiter „Mehrspieler“ und keine Frage")
check(PastimeDB.settings.mpGuild == true and PastimeDB.settings.mpParty == true and PastimeDB.mpAsked == false, "Mehrspieler: als Standard sind alle Kreise an, gefragt wurde noch nicht")
local was = PastimeDB.settings.sound
check(sv.checks[4]:GetChecked() == was, "Einstellungen: der Haken zeigt den gespeicherten Wert")
sv.checks[4]:SetChecked(not was)
sv.checks[4].scripts.OnClick(sv.checks[4])
check(PastimeDB.settings.sound == not was, "Einstellungen: ein Klick ändert die Einstellung")
sv.checks[4]:SetChecked(was)
sv.checks[4].scripts.OnClick(sv.checks[4])
sv.checks[5]:SetChecked(false)
sv.checks[5].scripts.OnClick(sv.checks[5])
check(PastimeDB.minimap.hidden == true, "Einstellungen: der Minimap-Knopf lässt sich ausblenden")
sv.checks[5]:SetChecked(true)
sv.checks[5].scripts.OnClick(sv.checks[5])
ns.frame.tabs[1].scripts.OnClick(ns.frame.tabs[1])
check((ns.launcher:IsShown() or ns.gameView:IsShown()) and not sv:IsShown(), "Einstellungen: der Reiter „Spiele“ führt zurück")

local errs = {}
for _, e in ipairs(PastimeDB.log) do if e.l == "E" then table.insert(errs, e.c .. ": " .. e.m) end end
check(#errs == 0, "keine Fehler im Protokoll:\n  " .. table.concat(errs, "\n  "))
check(errors() == 0, "keine Fehler an BugSack: " .. table.concat(ERRORS_FORWARDED, " | "))
print(("Tests: %d ok, %d Fehler"):format(passes, fails))
print("Chat (letzte):")
for i = 1, #CHAT do if CHAT[i]:find("Haltestelle") or CHAT[i]:find("Angekommen") or CHAT[i]:find("Gelandet") then print("  " .. CHAT[i]) end end
