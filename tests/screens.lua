-- Alle Bildschirme durch den Layout-Prüfer (mit dem Layout-Rechner aus layoutsim.lua)
-- Aufruf: python3 tests/run.py . tests/screens.lua
--         LOCALE=enUS und/oder FACTION=Alliance für die anderen Varianten
local ns = KW
local L = ns.L
local fire = function(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function slash(s) SlashCmdList.PASTIME(s) end

fire("ADDON_LOADED", "Pastime")
fire("PLAYER_LOGIN")
slash("")

local found, seen = {}, {}
local function scan(where)
    for _, m in ipairs(ns.LayoutCheck({ ns.frame })) do
        local key = where:gsub(" %b()", "") .. m
        if not seen[m] then
            seen[m] = true
            found[#found + 1] = where .. ": " .. m
        end
    end
end

-- Bestenlisten füllen: lange Namen und große Zahlen
for _, def in ipairs(ns.games) do
    for _, m in ipairs(def.modes or { { id = nil } }) do
        local list = ns.GetScores(def, m.id)
        for i = 1, 5 do table.insert(list, { s = def.lowerIsBetter and (61 + i) or (1054000 - i), p = "Thokk", d = date(ns.DATE_FORMAT) }) end
    end
end

-- 1. Auswahl: jedes Spiel, jede Schwierigkeit
ns.ShowLauncher()
for _, def in ipairs(ns.games) do
    for _, m in ipairs(def.modes or { { id = nil } }) do
        ns.selected = def
        if m.id then ns.DB.modes[def.id] = m.id end
        ns.UpdateUI()
        scan("Auswahl " .. def.id .. (m.id and (" " .. m.id) or ""))
    end
end

-- 2. Auswahl während einer Reise (Streckenzeile) und Reiserekorde
slash("testflug 600")
for _, def in ipairs(ns.games) do
    ns.ShowLauncher()
    ns.selected = def
    ns.UpdateUI()
    scan("Auswahl mit Reise " .. def.id)
end

-- 3. Jedes Spiel: laufend, Pause, Spielende
for _, def in ipairs(ns.games) do
    for _, m in ipairs(def.modes or { { id = nil } }) do
        ns.StartGame(def, m.id)
        ns.UpdateSidePanel()
        scan("Spiel " .. def.id)
        ns.Pause()
        scan("Pause " .. def.id)
        ns.gameView.side.rules.scripts.OnClick(ns.gameView.side.rules)
        if ns.overlay.title.text ~= L["Rules"] or not ns.overlay.text.text:find(def.controls, 1, true) then
            found[#found + 1] = "Spielregeln " .. def.id .. ": Dialog zeigt Ziel und Steuerung nicht"
        end
        scan("Spielregeln " .. def.id)
        ns.Resume()
        ns.SetCountdown(nil)
        ns.GameOver({ score = def.lowerIsBetter and 754 or 1054000, won = true,
            text = def.name .. " – " .. L["Game over"] })
        ns.UpdateSidePanel()
        scan("Spielende " .. def.id)
    end
end

-- 3b. Glücksspiele mitten in der Hand, mit großen Zahlen
do
    local function open(id)
        PastimeDB.purses[id] = { gold = 1054000, peak = 1054000 }
        ns.StartGame(ns.gamesById[id])
        return ns.run.game
    end
    local g = open("holdem")
    g:PlaceBet(3)
    for _ = 1, 400 do if g.state == "act" or g.state == "between" then break end; g:Update(1) end
    ns.UpdateSidePanel()
    scan("Hold'em in der Hand (" .. g.state .. ")")
    for _ = 1, 400 do
        if g.state == "between" or g.state == "result" then break end
        if g.state == "act" then g:Player("call") else g:Update(1) end
    end
    scan("Hold'em nach der Hand")
    g = open("roulette")
    for _, spot in ipairs({ 0, 17, 36, "d1", "d3", "low", "even", "red", "black", "odd", "high" }) do g:Click(spot, "LeftButton") end
    scan("Roulette mit Chips")
    g:Spin(); g:Update(5)
    scan("Roulette nach dem Wurf")
    g = open("drawpoker")
    g:Play(); g:Toggle(1); g:Toggle(5)
    scan("Goblin-Poker halten")
    g:Swap()
    scan("Goblin-Poker entscheiden")
    g:Raise(); g:Update(1)
    scan("Goblin-Poker aufgedeckt")
    g = open("slots")
    g:Play(); g:Update(2)
    scan("Automat nach der Drehung")
    g = open("higherlower")
    g:Play()
    scan("Höher oder tiefer")
    for id in pairs(PastimeDB.purses) do PastimeDB.purses[id] = nil end
    for _, def in ipairs(ns.games) do      -- die Bestenlisten für die folgenden Schritte wieder füllen
        if def.noLandingScore then
            local list = ns.GetScores(def)
            while #list > 5 do table.remove(list) end
        end
    end
end

-- 4. Ankunft mitten im Spiel
ns.StartGame(ns.gamesById.rockfall)
ns.run.game.score = 1054000
slash("testflug")
scan("Ankunft")

-- 4b. Ankunft mit langem Zielnamen: der Titel bricht um und bleibt im Rahmen
ns.ShowLauncher()
local longFrom, longTo = "Brackenwall, Marschen von Dustwallow", "Zoram'gar-Außenposten, Ashenvale"
ns.BeginTrip({ kind = "flug", from = longFrom, to = longTo })
ns.StartGame(ns.gamesById.rockfall)
ns.run.game.score = 1054000
ns.EndTrip(true)
scan("Ankunft mit langem Zielnamen")
ns.ShowLauncher()      -- die lange Strecke bleibt: Liste und Titel der Reiserekorde kürzen die Namen

-- 4b. „Was gewinnt?“ in den Karten- und Goldspielen: der Text muss ins Fenster passen
for _, id in ipairs({ "holdem", "drawpoker", "blackjack", "higherlower", "roulette", "slots" }) do
    ns.StartGame(ns.gamesById[id])
    ns.ShowWins()
    scan("Was gewinnt " .. id)
    ns.ShowLauncher()
end

-- 5. Reiserekorde
ns.ShowFrame("records")
scan("Reiserekorde")

-- 6. Einstellungen
ns.ShowFrame("settings")
scan("Einstellungen")

-- 7. Mehrspieler (freigeschaltet): Reiter mit Liste und Spielwahl, Einstellungen mit den drei Schaltern
ns.ShowFrame()
SlashCmdList.PASTIME("mp")
scan("Mehrspieler erste Frage")
ns.mpAskFrame.save.scripts.OnClick(ns.mpAskFrame.save)
ns.Comm.peers["Jaina Prachtmeer"] = { v = 0, mp = 1, t = GetTime(), channel = "PARTY" }
ns.Comm.peers["Thrall"] = { v = 0, mp = 1, t = GetTime(), channel = "PARTY" }
PastimeDB.mp.stats["Jaina Prachtmeer"] = { fourinarow = { w = 12, l = 7, d = 1 } }
ns.ShowFrame("mp")
scan("Mehrspieler")
ns.MP.session = { id = "s1", partner = "Jaina Prachtmeer", role = "host", state = "choosing", theirs = 3, t = GetTime() }
ns.UpdateUI()
scan("Mehrspieler Spielwahl")
ns.MP.session = nil
ns.ShowFrame("settings")
scan("Einstellungen mit Mehrspieler")
SlashCmdList.PASTIME("mp")

for _, f in ipairs(found) do print("FEHLER: " .. f) end

-- Gegenprobe: ein zu langer Knopftext muss auffallen, sonst ist der Prüfer blind
ns.StartGame(ns.gamesById.snake)
ns.Pause()
local old = ns.overlay.btn1:GetText()
ns.overlay.btn1:SetText(("W"):rep(30))
local hits = 0
for _, m in ipairs(ns.LayoutCheck({ ns.frame })) do if m:find("WWWW", 1, true) then hits = hits + 1 end end
ns.overlay.btn1:SetText(old)
if hits == 0 then print("FEHLER: Gegenprobe – zu langer Knopftext wurde nicht erkannt") end

print(("Bildschirm-Tests (%s, %s): %d ok, %d Fehler"):format(ns.LOCALE, ns.IsAlliance() and "Allianz" or "Horde",
    hits > 0 and 1 or 0, #found + (hits > 0 and 0 or 1)))
