-- Pastime: Kern (Speicher, Protokoll, Bestenlisten, Reisen, Befehle)
local ADDON, ns = ...
local L = ns.L
_G.Pastime = ns

-- Version aus der TOC: der Packager setzt dort den Tag ein (z. B. v1.0.0-beta2);
-- in der ungepackten Kopie steht noch der Platzhalter
function ns.VersionFrom(v)
    return (type(v) == "string" and v ~= "" and not v:find("@", 1, true)) and v or "dev"
end
ns.VERSION = ns.VersionFrom(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))

---------------------------------------------------------------------------
-- Protokoll (PastimeDB.log)
-- Stufen: E = Fehler, W = Warnung, I = Info, D = Debug (nur mit /pastime debug)
---------------------------------------------------------------------------
local MAX_ENTRIES = 400
-- Kurzzeitspeicher: Debug-Einträge laufen immer mit, aber nur im Arbeitsspeicher. Bei einem Fehler
-- wandern die letzten davon ins gespeicherte Protokoll (überlebt /reload), und der Bericht
-- (/pastime report) nimmt sie mit. So enthält eine Fehlermeldung die Minuten davor, ohne dass
-- jemand vorher den Debug-Modus einschalten musste.
local RECENT_MAX, RECENT_AGE, FREEZE_MAX = 200, 600, 60
local recent = {}
local LEVEL_NAME = { E = "ERROR", W = "WARNING", I = "INFO", D = "DEBUG" }
local LEVEL_COLOR = { E = "ff6060", W = "ffb040", I = "a0c0ff", D = "909090" }
local pending, echoed = {}, {}

local function trim(log)
    local extra = #log - MAX_ENTRIES
    for _ = 1, math.max(0, extra) do table.remove(log, 1) end
end

function ns.Print(text)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cffffd100Pastime:|r " .. tostring(text)) end
end

function ns.DebugOn() return ns.DB and ns.DB.debug and true or false end

-- Die jüngsten Debug-Einträge ins gespeicherte Protokoll übernehmen (vor einem Fehler)
local function freeze()
    local target = ns.DB and ns.DB.log or pending
    local oldest = time() - RECENT_AGE
    for i = math.max(1, #recent - FREEZE_MAX + 1), #recent do
        local e = recent[i]
        if (e.t or 0) >= oldest then table.insert(target, e) end
    end
    wipe(recent)
end

function ns.Log(level, cat, fmt, ...)
    local msg
    if select("#", ...) > 0 then
        local ok, res = pcall(string.format, fmt, ...)
        msg = ok and res or (tostring(fmt) .. " [format error]")
    else
        msg = tostring(fmt)
    end
    local entry = { d = date("%Y-%m-%d %H:%M:%S"), t = time(), l = level, c = cat, m = msg, p = ns.playerName, s = ns.session }
    if level == "D" and not ns.DebugOn() then
        recent[#recent + 1] = entry
        if #recent > RECENT_MAX then table.remove(recent, 1) end
        return entry
    end
    if level == "E" then freeze() end
    if ns.DB and ns.DB.log then
        table.insert(ns.DB.log, entry)
        trim(ns.DB.log)
    else
        table.insert(pending, entry)
    end
    if (level == "E" and not echoed[msg]) or (ns.DebugOn() and level ~= "I") then
        if level == "E" then echoed[msg] = true end
        ns.Print(("|cff%s[%s]|r %s: %s"):format(LEVEL_COLOR[level], LEVEL_NAME[level], cat, msg))
    end
    return entry
end

-- Aufruf einer Client-Funktion, die es in diesem Client vielleicht nicht (so) gibt. Ein Fehlschlag
-- wird nicht verschluckt: der erste je Funktion steht als Warnung im Protokoll, weitere werden
-- gezählt (ns.fails, steht im Bericht). Rückgabe wie pcall.
ns.fails = {}
local function tried(name, ok, ...)
    if ok then return true, ... end
    local f = ns.fails[name]
    if f then
        f.n = f.n + 1
    else
        ns.fails[name] = { n = 1, first = date("%H:%M:%S"), err = tostring((...)) }
        ns.Log("W", "client", "%s failed: %s", name, tostring((...)))
    end
    return false, ...
end
function ns.Try(name, fn, ...) return tried(name, pcall(fn, ...)) end

local function handler(err)
    return { err = err, stack = debugstack and debugstack(2, 12, 0) or "" }
end
local function collect(ok, ...) return ok, select("#", ...), { ... } end

function ns.Safe(cat, fn, ...)
    local n, args = select("#", ...), { ... }
    local ok, rn, r = collect(xpcall(function() return fn(unpack(args, 1, n)) end, handler))
    if ok then return unpack(r, 1, rn) end
    local info = type(r[1]) == "table" and r[1] or { err = r[1] }
    local entry = ns.Log("E", cat, "%s", tostring(info.err))
    if entry then entry.st = info.stack end
    local eh = geterrorhandler and geterrorhandler()
    if eh then pcall(eh, info.err) end
    return nil
end

function ns.Wrap(cat, fn)
    return function(...) return ns.Safe(cat, fn, ...) end
end

-- Alle per SetScript gesetzten Skripte eines Frames absichern (OnUpdate sichert sich selbst)
function ns.AutoWrap(frame, cat)
    local orig = frame.SetScript
    frame.SetScript = function(self, script, fn)
        if type(fn) == "function" and script ~= "OnUpdate" then fn = ns.Wrap(cat .. ":" .. script, fn) end
        return orig(self, script, fn)
    end
    return frame
end

function ns.SessionErrors()
    local n = 0
    for _, e in ipairs(ns.DB and ns.DB.log or {}) do
        if e.s == ns.session and e.l == "E" then n = n + 1 end
    end
    return n
end

function ns.FormatLog(maxLines, onlyProblems, withRecent, since)
    local log = ns.DB and ns.DB.log or {}
    local list = {}
    for _, e in ipairs(log) do
        local problem = e.l == "E" or e.l == "W"
        -- since: aus Sitzungen davor nur Fehler und Warnungen
        if (not onlyProblems or problem) and (not since or problem or (e.s or 0) >= since) then table.insert(list, e) end
    end
    if withRecent then
        -- Kurzzeitspeicher an der richtigen Stelle einsortieren (beide Listen sind zeitlich geordnet)
        local merged, i = {}, 1
        for _, r in ipairs(recent) do
            while list[i] and (list[i].t or 0) <= (r.t or 0) do merged[#merged + 1] = list[i]; i = i + 1 end
            merged[#merged + 1] = r
        end
        while list[i] do merged[#merged + 1] = list[i]; i = i + 1 end
        list = merged
    end
    local lines, last = {}, nil
    for i = math.max(1, #list - (maxLines or 200) + 1), #list do
        local e = list[i]
        if e.s and e.s ~= last then
            table.insert(lines, ("---- Session %s%s ----"):format(tostring(e.s), e.s == ns.session and " (current)" or ""))
            last = e.s
        end
        table.insert(lines, ("%s [%s] %s: %s"):format(e.d or "?", LEVEL_NAME[e.l] or e.l, e.c or "?", e.m or ""))
        if e.st and e.st ~= "" then table.insert(lines, "    " .. e.st:gsub("\n", "\n    ")) end
    end
    if #lines == 0 then return onlyProblems and L["No errors or warnings in the log."] or L["The log is empty."] end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
function ns.Trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function ns.FormatTime(sec)
    sec = math.max(0, math.floor((sec or 0) + 0.5))
    if sec >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
    end
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function ns.FormatNumber(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(math.abs(n))
    local sep = ns.THOUSANDS
    local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    if out:sub(1, 1) == sep then out = out:sub(2) end
    return (n < 0 and "-" or "") .. out
end

-- „Das Wegekreuz, Brachland“ -> „Das Wegekreuz“
function ns.ShortName(n)
    if not n then return nil end
    return (n:match("^([^,]+)") or n)
end

-- Werte, die der Client im Kampf/in Instanzen geheim hält, ignorieren
function ns.Num(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return type(v) == "number" and v or nil
end

-- Spielgeräusche laufen über den Effekte-Kanal (folgt dem Effekte-Regler)
-- und sind bewusst leise; nur der Landealarm nutzt die Hauptlautstärke.
local SOUND = {
    start = "IG_SPELLBOOK_OPEN", point = "IG_MAINMENU_OPTION_CHECKBOX_ON", click = "U_CHAT_SCROLL_BUTTON",
    line = "IG_ABILITY_PAGE_TURN", big = "LOOT_WINDOW_COIN_SOUND", over = "IG_SPELLBOOK_CLOSE",
    record = "IG_QUEST_LIST_COMPLETE", flag = "U_CHAT_SCROLL_BUTTON", alarm = "READY_CHECK",
    t1 = "U_CHAT_SCROLL_BUTTON", t2 = "IG_ABILITY_PAGE_TURN", t3 = "IG_SPELLBOOK_CLOSE", t4 = "IG_MAINMENU_OPTION_CHECKBOX_ON",
    bad = "IG_QUEST_LOG_ABANDON_QUEST",
    fanfare = 888,      -- Stufenaufstieg: der einzige längere Klang (Freispiele im Automaten); Zahl = Soundkit-ID
}
ns.SOUNDS = SOUND      -- für den Selbsttest (Debug.lua)
local lastSound = {}

function ns.PlaySound(kind)
    if kind ~= "alarm" and not (ns.DB and ns.DB.settings.sound) then return end
    local now = GetTime()
    if lastSound[kind] and now - lastSound[kind] < 0.12 then return end   -- kein Dauerfeuer
    lastSound[kind] = now
    local id = type(SOUND[kind]) == "number" and SOUND[kind] or (SOUNDKIT and SOUNDKIT[SOUND[kind] or ""])
    if id and PlaySound then ns.Try("PlaySound", PlaySound, id, kind == "alarm" and "Master" or "SFX") end
end

---------------------------------------------------------------------------
-- Speicher (PastimeDB, für alle Charaktere)
---------------------------------------------------------------------------
local DEFAULTS = {
    settings = { autoOpen = true, landAlarm = true, hideInCombat = true, sound = true },
    scores = {}, stats = {}, routes = {}, minimap = {}, collapsed = {}, modes = {},
    frame = false, lastGame = false, debug = false, log = {}, logSession = 0,
    blackjack = { gold = 1000, peak = 1000 },   -- Goblin-Gold bleibt zwischen Partien erhalten
    purses = {},                              -- dasselbe für die übrigen Glücksspiele: purses[id] = { gold, peak }
    jackpot = 10000,                          -- gemeinsamer Topf aller Glücksspiele (ns.Gamble)
    newest = 0,                               -- höchste Pastime-Version, die ein anderer Spieler gemeldet hat (Comm)
    daily = {},                               -- Tagesaufgabe: { last = Tag der letzten erledigten, streak = Serie }
}

local function fill(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            if type(v) == "table" then t[k] = fill({}, v) else t[k] = v end
        elseif type(v) == "table" and type(t[k]) == "table" then
            fill(t[k], v)
        end
    end
    return t
end

local RENAMED = { tetris = "rockfall", flappy = "windrider", breakout = "wallbreaker", simon = "totemecho",
    memory = "runepairs", kniffel = "taverndice", viergewinnt = "fourinarow" }

local GOLD_GAMES = { "blackjack", "slots", "drawpoker", "higherlower", "roulette", "holdem" }

-- Bis 1.2 begann jeder Lauf der Glücksspiele mit 100 Gold, seither mit 1000. Einmalig bekommen
-- laufende Töpfe und alte Rekorde die 900 Gold dazu, damit sie mit neuen Läufen vergleichbar bleiben.
local function raiseStartGold(db)
    local purses = { db.blackjack }
    for _, p in pairs(type(db.purses) == "table" and db.purses or {}) do purses[#purses + 1] = p end
    for _, p in ipairs(purses) do
        if type(p) == "table" and tonumber(p.gold) then
            p.gold, p.peak = p.gold + 900, (tonumber(p.peak) or p.gold) + 900
        end
    end
    local function lift(t)
        if type(t) ~= "table" then return end
        for _, id in ipairs(GOLD_GAMES) do
            for _, e in ipairs(type(t[id]) == "table" and t[id] or {}) do
                if type(e) == "table" and tonumber(e.s) then e.s = e.s + 900 end
            end
        end
    end
    lift(db.scores)
    for _, r in pairs(type(db.routes) == "table" and db.routes or {}) do if type(r) == "table" then lift(r.scores) end end
end

local function InitDB()
    if type(PastimeDB) == "table" and next(PastimeDB) ~= nil and not PastimeDB.gold1000 then raiseStartGold(PastimeDB) end
    PastimeDB = fill(type(PastimeDB) == "table" and PastimeDB or {}, DEFAULTS)
    ns.DB = PastimeDB
    ns.DB.gold1000 = true
    ns.DB.directOK = nil      -- aus einem Testlauf, in dem Pastime sich noch selbst geantwortet hat
    ns.DB.jackpot = math.max(10000, tonumber(ns.DB.jackpot) or 0)
    local st = ns.DB.stats
    st.total, st.flight, st.games = st.total or 0, st.flight or 0, st.games or {}
    -- 0.1.0 merkte nur Flugzeiten (flights["A > B"] = { t, d })
    if type(ns.DB.flights) == "table" then
        for key, v in pairs(ns.DB.flights) do
            local from, to = key:match("^(.-) > (.+)$")
            if from and type(v) == "table" then
                local r = ns.Route("flug", from, to)
                r.t, r.last = r.t or v.t, r.last or v.d
            end
        end
        ns.DB.flights = nil
    end
    -- bis beta2 hießen einige Spiele intern anders: Bestenlisten, Statistik und Auswahl ziehen mit um
    local function rekey(t)
        if type(t) ~= "table" then return end
        local moves = {}
        for k in pairs(t) do
            local id, rest = tostring(k):match("^([^:]+)(.*)$")
            if RENAMED[id] then moves[k] = RENAMED[id] .. rest end
        end
        for k, nk in pairs(moves) do
            if t[nk] == nil then t[nk] = t[k] end
            t[k] = nil
        end
    end
    rekey(ns.DB.scores); rekey(st.games); rekey(ns.DB.modes)
    for _, r in pairs(ns.DB.routes) do if type(r) == "table" then rekey(r.scores) end end
    ns.DB.lastGame = RENAMED[ns.DB.lastGame] or ns.DB.lastGame
    -- Läufe, die nie über das Startgold kamen, stehen nicht in den Listen (bis 1.1 taten sie das)
    local function unbust(t)
        if type(t) ~= "table" then return end
        for _, id in ipairs(GOLD_GAMES) do
            local list = type(t[id]) == "table" and t[id] or {}
            for i = #list, 1, -1 do
                if type(list[i]) ~= "table" or (tonumber(list[i].s) or 0) <= 1000 then table.remove(list, i) end
            end
            if #list == 0 then t[id] = nil end
        end
    end
    unbust(ns.DB.scores)
    for _, r in pairs(ns.DB.routes) do if type(r) == "table" then unbust(r.scores) end end
    ns.DB.logSession = (tonumber(ns.DB.logSession) or 0) + 1
    ns.session = ns.DB.logSession
    for _, e in ipairs(pending) do e.s = ns.session; table.insert(ns.DB.log, e) end
    wipe(pending)
    trim(ns.DB.log)
end

---------------------------------------------------------------------------
-- Spiele-Verzeichnis
---------------------------------------------------------------------------
ns.CATEGORIES = {
    { id = "geschick", name = L["Arcade"] },
    { id = "knobeln", name = L["Puzzles"] },
    { id = "karten", name = L["Dice & Cards"] },
}
-- Wie lange eine Partie ungefähr dauert
ns.LENGTHS = {
    kurz = { label = L["short"], color = "80ff80", short = L["For short flights (1–2 min)"],
        desc = L["for short flights – a round takes 1–2 minutes"] },
    lang = { label = L["long"], color = "80c0ff", short = L["For long journeys (several minutes)"],
        desc = L["for long journeys – rounds last several minutes, ideal for zeppelins and boats"] },
}
ns.games, ns.gamesById = {}, {}

-- def: id, name, category, icon, short, desc, controls, width, height,
--      Create(host, board) -> Spielobjekt; optional modes, lowerIsBetter, FormatScore, aliases
function ns.RegisterGame(def)
    def.order = #ns.games + 1
    def.length = def.length or "kurz"
    table.insert(ns.games, def)
    ns.gamesById[def.id] = def
    return def
end

-- Beim Login: Farbschema der Fraktion wählen und für die Allianz die Varianten der
-- Spiele übernehmen (def.alliance = { name, desc, icon, ... }). Id und Bestenliste bleiben.
function ns.ApplyFaction()
    local ally = ns.IsAlliance()
    ns.THEME = ns.THEMES[ally and "Alliance" or "Horde"]
    if not ally then return end
    for _, def in ipairs(ns.games) do
        for k, v in pairs(def.alliance or {}) do def[k] = v end
    end
end

function ns.FindGame(query)
    query = (query or ""):lower()
    if query == "" then return nil end
    for _, g in ipairs(ns.games) do
        if g.id == query or g.name:lower() == query then return g end
        for _, a in ipairs(g.aliases or {}) do if a == query then return g end end
    end
    if #query < 3 then return nil end      -- „/pastime a“ soll kein Spiel starten
    for _, g in ipairs(ns.games) do
        if g.name:lower():find(query, 1, true) then return g end
    end
end

function ns.DefaultMode(def)
    if not def.modes then return nil end
    local saved = ns.DB.modes[def.id]
    for _, m in ipairs(def.modes) do if m.id == saved then return saved end end
    return def.modes[1].id
end

function ns.ModeName(def, mode)
    for _, m in ipairs(def.modes or {}) do if m.id == mode then return m.name end end
end

---------------------------------------------------------------------------
-- Bestenlisten: PastimeDB.scores["spiel" oder "spiel:modus"] = { {s, p, d}, ... }
-- Es zählen nur beendete Partien (Spielende oder „Beenden & werten“ bei der
-- Ankunft) – abgebrochene nie.
---------------------------------------------------------------------------
local MAX_SCORES = 10
local MAX_ROUTE_SCORES = 5

function ns.ScoreKey(def, mode) return mode and (def.id .. ":" .. mode) or def.id end

function ns.GetScores(def, mode)
    local key = ns.ScoreKey(def, mode)
    ns.DB.scores[key] = ns.DB.scores[key] or {}
    return ns.DB.scores[key]
end

function ns.BestScore(def, mode)
    return ns.GetScores(def, mode)[1]
end

function ns.FormatScore(def, score)
    if def.FormatScore then return def.FormatScore(score) end
    return ns.FormatNumber(score)
end

local function better(def, a, b)
    if def.lowerIsBetter then return a < b end
    return a > b
end

-- In eine sortierte Liste einfügen; gibt Platz und „persönlich bestes“ zurück
local function insertScore(def, list, score, max)
    local personal = true
    for _, e in ipairs(list) do
        if e.p == ns.playerName and not better(def, score, e.s) then personal = false; break end
    end
    local rank = #list + 1
    for i, e in ipairs(list) do
        if better(def, score, e.s) then rank = i; break end
    end
    if rank > max then return nil, false end
    table.insert(list, rank, { s = score, p = ns.playerName or "?", d = date(ns.DATE_FORMAT) })
    while #list > max do table.remove(list) end
    return rank, personal
end

local function validScore(def, score)
    if type(score) ~= "number" then return nil end
    if def.lowerIsBetter then return score > 0 and score or nil end
    return score > 0 and score or nil
end

---------------------------------------------------------------------------
-- Tagesaufgabe: jeden Tag ein Spiel mit einem Ziel. Zahl = mindestens so viele Punkte,
-- true = eine gewertete Partie (gewinnen oder lösen). An aufeinanderfolgenden Tagen
-- erledigt, wächst die Serie.
---------------------------------------------------------------------------
ns.DAILY = {
    snake = 300, windrider = 15, kodo = 200, kobold = 300, angeln = 300, rockfall = 2000, wallbreaker = 500, murlocs = 1000,
    totemecho = 8, runepairs = true, code = true, wortraten = true, fourinarow = true, minen = true, ["2048"] = 3000,
    edelsteine = 800, taverndice = 150, solitaer = true,
    blackjack = 2000, slots = 2000, drawpoker = 2000, higherlower = 2000, roulette = 2000, holdem = 2000,
}

local function dayNumber()
    local t = date("*t")
    return math.floor(time({ year = t.year, month = t.month, day = t.day, hour = 12 }) / 86400)
end

-- Spiel des Tages, sein Ziel, ob heute schon erledigt, und die laufende Serie
function ns.Daily()
    local day, list = dayNumber(), {}
    for _, g in ipairs(ns.games) do if ns.DAILY[g.id] then list[#list + 1] = g end end
    local def = list[(day * 7) % #list + 1]      -- 7 ist teilerfremd zu 24: die Spiele wechseln quer durch die Liste
    local d = ns.DB.daily
    local streak = (d.last == day or d.last == day - 1) and tonumber(d.streak) or 0
    return def, ns.DAILY[def.id], d.last == day, streak
end

function ns.DailyGoalText(def, goal)
    if goal == true then return L["win a round"] end
    return ("%s: %s+"):format(def.scoreLabel or L["Points"], ns.FormatScore(def, goal))
end

local function dailyCheck(def, score)
    local today, goal, done = ns.Daily()
    if done or def ~= today or (goal ~= true and score < goal) then return end
    local d, day = ns.DB.daily, dayNumber()
    d.streak = d.last == day - 1 and (tonumber(d.streak) or 0) + 1 or 1
    d.last = day
    ns.PlaySound("record")
    ns.Print((L["Daily task done: %s! Streak: %d"]):format(def.name, d.streak))
end

function ns.SubmitScore(def, mode, score)
    score = validScore(def, score)
    if not score then return nil end
    dailyCheck(def, score)
    local rank, personal = insertScore(def, ns.GetScores(def, mode), score, MAX_SCORES)
    ns.Log("I", "rekord", "%s%s: %s (rank %s)", def.name, mode and (" " .. mode) or "", tostring(score), tostring(rank))
    return rank, personal
end

-- Punktestand einer laufenden Partie, der bei der Ankunft gewertet werden kann
-- (Zeit-Spiele wie das Minenfeld zählen nur gelöst)
function ns.CurrentScore(run)
    if not run or run.def.lowerIsBetter or run.def.noLandingScore then return nil end
    local s = run.game.score
    return (type(s) == "number" and s > 0) and s or nil
end

---------------------------------------------------------------------------
-- Strecken: PastimeDB.routes["art:Von > Nach"] =
--   { kind, from, to, t = Reisedauer, n = Anzahl, last, lastT, scores = { [scoreKey] = {...} } }
---------------------------------------------------------------------------
ns.KINDS = {
    flug = { name = L["Flights"], one = L["Flight"], the = L["the flight"], arrive = L["Landed"], verb = L["Flying to"] },
    zeppelin = { name = L["Zeppelins"], one = "Zeppelin", the = L["the zeppelin"], arrive = L["Arrived"], verb = L["Zeppelin to"] },
    schiff = { name = L["Boats"], one = L["Boat"], the = L["the boat"], arrive = L["Arrived"], verb = L["Boat to"] },
    test = { name = L["Test flights"], one = L["Test flight"], the = L["the test flight"], arrive = L["Landed"], verb = L["Test flight to"] },
}
ns.KIND_ORDER = { "flug", "zeppelin", "schiff", "test" }

function ns.RouteKey(kind, from, to) return ("%s:%s > %s"):format(kind, from or "?", to or "?") end

function ns.Route(kind, from, to, noCreate)
    local key = ns.RouteKey(kind, from, to)
    local r = ns.DB.routes[key]
    if not r and not noCreate then
        r = { kind = kind, from = from, to = to, n = 0, scores = {} }
        ns.DB.routes[key] = r
    end
    return r, key
end

function ns.CountRoutes()
    local n = 0
    for _ in pairs(ns.DB.routes) do n = n + 1 end
    return n
end

-- max: Ortsnamen auf so viele Zeichen kürzen (ganze UTF-8-Zeichen), damit das Ziel in schmalen Zeilen sichtbar bleibt
local function clip(s, max)
    if not max then return s end
    local n, out = 0, {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n <= max then out[n] = ch end
    end
    if n <= max + 1 then return s end
    return (table.concat(out):gsub("[%s%-']+$", "")) .. "…"
end

-- „»“ statt Pfeil: die Schriften des Spiels kennen „→“ nicht und zeigen ein Kästchen
function ns.RouteLabel(r, max)
    return ("%s » %s"):format(clip(ns.ShortName(r.from) or "?", max), clip(ns.ShortName(r.to) or "?", max))
end

function ns.RouteScores(r, def, mode)
    local key = ns.ScoreKey(def, mode)
    r.scores[key] = r.scores[key] or {}
    return r.scores[key]
end

function ns.SubmitRouteScore(r, def, mode, score)
    score = validScore(def, score)
    if not (r and score) then return nil end
    local rank = insertScore(def, ns.RouteScores(r, def, mode), score, MAX_ROUTE_SCORES)
    ns.Log("I", "strecke", "%s · %s: %s (rank %s)", ns.RouteLabel(r), def.name, tostring(score), tostring(rank))
    return rank
end

---------------------------------------------------------------------------
-- Statistik
---------------------------------------------------------------------------
local function gameStats(id)
    local g = ns.DB.stats.games[id]
    if not g then g = { n = 0, t = 0 }; ns.DB.stats.games[id] = g end
    return g
end

function ns.AddPlayTime(id, dt)
    local st = ns.DB.stats
    st.total = st.total + dt
    if ns.trip.active then st.flight = st.flight + dt end
    local g = gameStats(id)
    g.t = g.t + dt
end

function ns.CountGame(id)
    local g = gameStats(id)
    g.n = g.n + 1
end

---------------------------------------------------------------------------
-- Reisen (ns.trip): Flugmeister, Zeppeline, Schiffe
--   phase "wait": wartet am Turm/Anleger (nur Zeppelin/Schiff)
--   phase "ride": unterwegs
-- Partien bekommen beim Start die Reise-ID. Ergebnisse zählen für die Strecke,
-- sobald sie feststeht (Flug: sofort; Zeppelin/Schiff: bei der Ankunft).
---------------------------------------------------------------------------
ns.trip = { active = false, id = 0 }

local function tripInfo(t, extra)
    return ("%s/%s: %s > %s%s"):format(tostring(t.kind), tostring(t.phase), tostring(t.from), tostring(t.to), extra or "")
end
local function snapshot(event, t, extra)
    if ns.TraceSnapshot then ns.Safe("mitschnitt", ns.TraceSnapshot, event, tripInfo(t, extra)) end
end

function ns.BeginTrip(info)
    local t = ns.trip
    if t.active then return end
    t.id = t.id + 1
    t.active = true
    t.kind, t.phase = info.kind, info.phase or "ride"
    t.from, t.to, t.dock = info.from, info.to, info.dock
    t.simulated, t.simEnd = info.sim and true or false, info.sim and (GetTime() + info.sim) or nil
    t.played, t.autoOpened = false, false
    t.pending = {}
    t.confirmed = (t.kind == "flug" or t.kind == "test") and t.from ~= nil and t.to ~= nil
    t.waitStart = GetTime()
    if t.phase == "ride" then ns.DepartTrip(true) end
    ns.Log("I", "reise", "%s: %s -> %s (%s)%s", t.kind, tostring(t.from), tostring(t.to), t.phase,
        t.simulated and " [Test]" or "")
    snapshot("start", t)
    if ns.UpdateUI then ns.UpdateUI() end
end

-- Abfahrt (Zeppelin/Schiff legt ab) bzw. Abflug
function ns.DepartTrip(silent)
    local t = ns.trip
    if not t.active then return end
    t.phase = "ride"
    t.start = GetTime()
    local r = (t.from and t.to) and ns.Route(t.kind, t.from, t.to, true)
    t.expected = t.simEnd and (t.simEnd - t.start) or (r and r.t) or nil
    -- Das Fenster öffnet sich erst jetzt: am Turm oder Anleger wird nur gewartet (und die Zeit gemessen)
    if ns.DB.settings.autoOpen and not InCombatLockdown() and ns.OpenForTrip then ns.OpenForTrip() end
    if not silent then
        ns.Log("I", "reise", "Departure %s -> %s (expected: %s s)", tostring(t.from), tostring(t.to), tostring(t.expected))
        snapshot("abfahrt", t)
        if ns.UpdateUI then ns.UpdateUI() end
    end
end

-- Ergebnis einer beendeten Partie für die Strecke vormerken/eintragen.
-- Rückgabe: Platz (oder "vorgemerkt"), Strecke
function ns.TripResult(run, score)
    local t = ns.trip
    if not (run and run.tripId and t.active and run.tripId == t.id) then return nil end
    if not validScore(run.def, score) then return nil end
    if t.confirmed then
        local r = ns.Route(t.kind, t.from, t.to)
        return ns.SubmitRouteScore(r, run.def, run.mode, score), r
    end
    table.insert(t.pending, { def = run.def, mode = run.mode, score = score })
    return "vorgemerkt", nil
end

-- Reise endet. arrived = am Ziel angekommen (sonst abgebrochen/verworfen)
function ns.EndTrip(arrived, dest)
    local t = ns.trip
    if not t.active then return end
    if dest then t.to = dest end
    local r
    if arrived and t.phase == "ride" and t.from and t.to then
        r = ns.Route(t.kind, t.from, t.to)
        local dur = GetTime() - (t.start or GetTime())
        if dur > 10 then r.t = math.floor(dur + 0.5) end
        r.n = (r.n or 0) + 1
        r.last, r.lastT = date(ns.DATE_FORMAT), time()
        if not t.confirmed then
            t.confirmed = true
            for _, p in ipairs(t.pending) do ns.SubmitRouteScore(r, p.def, p.mode, p.score) end
        end
        ns.Log("I", "reise", "%s: arrived at %s after %s", tostring(t.kind), tostring(t.to), ns.FormatTime(dur))
    else
        ns.Log("I", "reise", "Trip discarded (%s, %s)", tostring(t.kind), tostring(t.phase))
    end
    snapshot(arrived and t.phase == "ride" and "ankunft" or "abbruch", t,
        t.start and (" after " .. ns.FormatTime(GetTime() - t.start)) or "")
    if ns.OnTripEnded then ns.OnTripEnded(t, arrived and t.phase == "ride", r) end
    t.active = false
    t.pending = {}
    if ns.UpdateUI then ns.UpdateUI() end
end

-- Kurzer Text für Fenster/Seitenleiste, nil wenn nicht unterwegs
function ns.TripStatus()
    local t = ns.trip
    if not t.active then return nil end
    local K = ns.KINDS[t.kind] or ns.KINDS.flug
    local dest = ns.ShortName(t.to)
    if t.phase == "wait" then
        return (L["Waiting for %s%s"]):format(K.the, dest and (L[" to "] .. dest) or "")
    end
    local head = dest and (K.verb .. " " .. dest) or (L["Travelling ("] .. K.one .. ")")
    local elapsed = GetTime() - (t.start or GetTime())
    local word = (t.kind == "flug" or t.kind == "test") and L["landing"] or L["arrival"]
    if t.expected then
        local left = t.expected - elapsed
        if left > 0 then return (L["%s · %s in about %s"]):format(head, word, ns.FormatTime(left)), left end
        return (L["%s · %s any moment"]):format(head, word), 0
    end
    return (L["%s · %s (measuring duration)"]):format(head, ns.FormatTime(elapsed))
end

-- Restzeit der Reise in Sekunden (nil, wenn unbekannt)
function ns.TripRemaining()
    local t = ns.trip
    if not (t.active and t.phase == "ride" and t.expected and t.start) then return nil end
    return math.max(0, t.expected - (GetTime() - t.start))
end

-- Bester Streckeneintrag für die aktuelle Reise
function ns.TripBest(def, mode)
    local t = ns.trip
    if not (t.active and t.from and t.to) then return nil end
    local r = ns.Route(t.kind, t.from, t.to, true)
    if not r then return nil end
    return (r.scores[ns.ScoreKey(def, mode)] or {})[1], r
end

---------------------------------------------------------------------------
-- Flugmeister: UnitOnTaxi + PLAYER_CONTROL_LOST/GAINED; Ziel über
-- TakeTaxiNode-Hook.
---------------------------------------------------------------------------
local pendingRoute
local flightTicker

local function currentNodeName()
    if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return nil end
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then return TaxiNodeName(i) end
    end
end

local function OnTakeTaxiNode(slot)
    local to = TaxiNodeName and TaxiNodeName(slot)
    local from = currentNodeName() or (GetMinimapZoneText and GetMinimapZoneText())
    pendingRoute = { from = from, to = to, t = GetTime() }
    ns.Log("D", "flug", "Flight selected: %s -> %s", tostring(from), tostring(to))
end

local function onTaxi()
    if not UnitOnTaxi then return false end
    local ok, v = ns.Try("UnitOnTaxi", UnitOnTaxi, "player")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(v)) then return false end
    return v and true or false
end

function ns.CheckTaxi()
    local t = ns.trip
    if t.active and t.simulated then
        if GetTime() >= t.simEnd then ns.EndTrip(true) end
        if ns.OnTripTick then ns.OnTripTick() end
        return
    end
    local on = onTaxi()
    if on and not (t.active and t.kind == "flug") then
        if t.active then ns.EndTrip(false) end   -- z. B. vom Anleger direkt zum Flugmeister
        local r = pendingRoute
        pendingRoute = nil
        local known = r and GetTime() - r.t < 90
        -- ohne gewähltes Ziel (z. B. /reload mitten im Flug) gibt es keine Strecke
        ns.BeginTrip({ kind = "flug", from = known and r.from or nil, to = known and r.to or nil })
    elseif not on and t.active and t.kind == "flug" then
        ns.EndTrip(true)
    elseif t.active and ns.OnTripTick then
        ns.OnTripTick()
    end
end

local function EnsureTicker()
    if flightTicker then return end
    flightTicker = C_Timer.NewTicker(1, ns.Wrap("reise-ticker", ns.CheckTaxi))
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

local function later(sec, cat, fn) C_Timer.After(sec, ns.Wrap(cat, fn)) end

ev:SetScript("OnEvent", ns.Wrap("event", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            ev:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        ns.playerName = UnitName("player")
        ns.ApplyFaction()          -- vor allen Fenstern, die Farben und Namen lesen
        local build, buildNum = "?", "?"
        if GetBuildInfo then build, buildNum = GetBuildInfo() end
        ns.Log("I", "start", "Pastime %s · Client %s (%s) · %s · %s", ns.VERSION, tostring(build),
            tostring(buildNum), GetLocale and GetLocale() or "?", tostring(ns.playerName))
        local set = ns.DB.settings
        ns.Log("I", "start", "Settings: auto=%s alarm=%s combat=%s sound=%s debug=%s · routes: %d",
            tostring(set.autoOpen), tostring(set.landAlarm), tostring(set.hideInCombat), tostring(set.sound),
            tostring(ns.DB.debug), ns.CountRoutes())
        if TakeTaxiNode and hooksecurefunc then
            hooksecurefunc("TakeTaxiNode", ns.Wrap("flug-hook", OnTakeTaxiNode))
        else
            ns.Log("W", "flug", "TakeTaxiNode missing – flight destination and duration cannot be detected.")
        end
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
        if ns.CreateSettings then ns.Safe("options", ns.CreateSettings) end
        if ns.StartTransportWatch then ns.StartTransportWatch() end
        if ns.Comm then ns.Safe("comm", ns.Comm.StartVersionCheck) end
        if ns.UpdateDebugPanel then ns.UpdateDebugPanel() end
        EnsureTicker()
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
                              "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD" }) do
            ev:RegisterEvent(e)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        later(1, "flug-login", ns.CheckTaxi)

    elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
        later(0.3, "flug-check", ns.CheckTaxi)

    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.inCombat = true      -- InCombatLockdown() meldet den Kampf erst nach diesem Ereignis
        if ns.OnCombat then ns.OnCombat() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.inCombat = false
        if ns.UpdateUI then ns.UpdateUI() end

    elseif event == "PLAYER_DEAD" then
        -- wer stirbt, fährt nicht weiter: Zeppelin- oder Schiffsreise verwerfen
        local t = ns.trip
        if t.active and (t.kind == "zeppelin" or t.kind == "schiff") then ns.EndTrip(false) end
    end
end))

---------------------------------------------------------------------------
-- Befehle (/pastime) – englische Namen, deutsche Namen gehen ebenfalls
---------------------------------------------------------------------------
local function HelpLines()
    return {
        L["|cffffffff/pastime|r – open or close the game collection"],
        L["|cffffffff/pastime <game>|r – start a game directly (e.g. snake, 2048, solitaire)"],
        L["|cffffffff/pastime records|r – best scores in chat · |cffffffff/pastime routes|r – open the route records"],
        L["|cffffffff/pastime options|r – open the settings"],
        L["|cffffffff/pastime testflight [sec]|r – simulate a trip · |cffffffff/pastime testflight clear|r – remove test routes"],
        L["|cffffffff/pastime dock|r – show the nearest zeppelin tower or boat dock"],
        L["|cffffffff/pastime auto|r · |cffffffff/pastime alarm|r · |cffffffff/pastime combat|r · |cffffffff/pastime sound|r – toggle settings"],
        L["|cffffffff/pastime minimap|r – show or hide the minimap button"],
        L["|cffffffff/pastime log|r – log · |cffffffff/pastime log errors|r – errors and warnings only · |cffffffff/pastime log clear|r"],
        L["|cffffffff/pastime debug|r – live debug window + detailed log · |cffffffff/pastime report|r – bug report to copy"],
    }
end

-- Einstellungen: Befehl -> { Schlüssel, Bezeichnung }
local SETTING_CMDS = {
    auto = "autoOpen", alarm = "landAlarm", combat = "hideInCombat", kampf = "hideInCombat",
    sound = "sound", ton = "sound",
}
ns.SETTING_LABELS = {
    autoOpen = L["Open when travelling"],
    landAlarm = L["Landing alarm"],
    hideInCombat = L["Hide in combat"],
    sound = L["Game sounds"],
}

local ALIASES = {
    rekorde = "records", rekord = "records", record = "records",
    strecken = "routes", reisen = "routes", reiserekorde = "routes", route = "routes",
    testflug = "testflight", test = "testflight",
    hafen = "dock", haltestelle = "dock", docks = "dock",
    optionen = "options", einstellungen = "options", config = "options", settings = "options",
    bericht = "diag", hilfe = "help", ["?"] = "help",
    fotos = "shots", screenshots = "shots",
}

function ns.ToggleSetting(key)
    ns.DB.settings[key] = not ns.DB.settings[key]
    ns.Print(("%s: %s"):format(ns.SETTING_LABELS[key] or key,
        ns.DB.settings[key] and L["|cff80ff80on|r"] or L["|cffff6060off|r"]))
    if ns.UpdateUI then ns.UpdateUI() end
    if ns.RefreshSettings then ns.RefreshSettings() end
end

local function PrintRecords()
    local any = false
    for _, def in ipairs(ns.games) do
        local modes = def.modes or { { id = nil } }
        for _, m in ipairs(modes) do
            local best = ns.BestScore(def, m.id)
            if best then
                any = true
                ns.Print(("%s%s: |cffffffff%s|r (%s, %s)"):format(def.name, m.name and (" – " .. m.name) or "",
                    ns.FormatScore(def, best.s), best.p or "?", best.d or "?"))
            end
        end
    end
    if not any then ns.Print(L["No records yet – time for a flight!"]) end
    local st = ns.DB.stats
    ns.Print(L["Played: %s, %s of it while travelling."]:format(ns.FormatTime(st.total), ns.FormatTime(st.flight)))
end

local function PrintHelp()
    for _, line in ipairs(HelpLines()) do ns.Print(line) end
end

function ns.HandleSlash(msg)
    msg = ns.Trim(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    cmd = ALIASES[cmd] or cmd
    local arg = (rest or ""):lower()

    if cmd == "" then
        ns.ToggleFrame()
    elseif SETTING_CMDS[cmd] then
        ns.ToggleSetting(SETTING_CMDS[cmd])
    elseif cmd == "options" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif cmd == "records" then
        PrintRecords()
    elseif cmd == "routes" then
        ns.ShowFrame("records")
    elseif cmd == "testflight" then
        if arg == "clear" or arg == "löschen" or arg == "loeschen" then
            local n = 0
            for key, r in pairs(ns.DB.routes) do
                if r.kind == "test" then ns.DB.routes[key] = nil; n = n + 1 end
            end
            ns.Print(L["%d test route(s) removed."]:format(n))
            if ns.UpdateUI then ns.UpdateUI() end
            return
        end
        local t = ns.trip
        if t.active then
            if t.simulated then ns.EndTrip(true) else ns.Print(L["You are really travelling right now."]) end
            return
        end
        local sec = math.max(5, math.min(600, tonumber(rest) or 30))
        ns.Print(L["Test flight: %d seconds. |cffffffff/pastime testflight|r again lands immediately."]:format(sec))
        ns.BeginTrip({ kind = "test", from = L["Test Range"], to = ns.IsAlliance() and L["Stormwind"] or L["Orgrimmar"], sim = sec })
    elseif cmd == "dock" then
        if ns.PrintNearestDock then ns.PrintNearestDock() end
    elseif cmd == "minimap" then
        ns.DB.minimap.hidden = not ns.DB.minimap.hidden
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        if ns.RefreshSettings then ns.RefreshSettings() end
    elseif cmd == "log" then
        if arg == "clear" or arg == "leeren" then
            wipe(ns.DB.log); ns.Print(L["Log cleared."])
        elseif arg == "errors" or arg == "fehler" then
            ns.ShowCopy(L["Pastime log: errors and warnings"], ns.FormatLog(200, true))
        else
            ns.ShowCopy(L["Pastime log"], ns.FormatLog(200))
        end
    elseif cmd == "layout" then
        if not ns.DebugOn() then return ns.Print("Layout check needs |cffffffff/pastime debug|r.") end
        ns.Print(("Layout check: %d problem(s) – see |cffffffff/pastime log|r"):format(#ns.LayoutCheck()))
    elseif cmd == "shots" then
        if ns.PhotoTour then ns.PhotoTour() end
    elseif cmd == "diag" or cmd == "report" or cmd == "bericht" then
        ns.ShowReport()
    elseif cmd == "debug" and (arg == "test" or arg == "testlauf" or arg == "selftest" or arg == "selbsttest") then
        if ns.SelfTest then ns.SelfTest() end
    elseif cmd == "debug" then
        ns.DB.debug = not ns.DB.debug
        ns.Print(ns.DB.debug and L["Debug |cff80ff80on|r – live window open, detailed log running."]
            or L["Debug |cffff6060off|r."])
        ns.Log("I", "debug", "Debug %s", ns.DB.debug and "on" or "off")
        if ns.UpdateDebugPanel then ns.UpdateDebugPanel() end
    elseif cmd == "help" then
        PrintHelp()
    else
        local def = ns.FindGame(cmd)
        if def then
            ns.ShowFrame()
            ns.StartGame(def, ns.DefaultMode(def))
        else
            PrintHelp()
        end
    end
end

SLASH_PASTIME1 = "/pastime"
SlashCmdList["PASTIME"] = function(msg) ns.Safe("slash", ns.HandleSlash, msg) end

BINDING_HEADER_PASTIME = "Pastime"
BINDING_NAME_PASTIME_TOGGLE = L["Open/close the game collection"]
function Pastime_Toggle() ns.Safe("taste", ns.ToggleFrame) end

-- Addon-Fach an der Minimap (Retail-Oberfläche): ## AddonCompartmentFunc in der TOC
function Pastime_OnAddonCompartmentClick() ns.Safe("fach", ns.ToggleFrame) end
