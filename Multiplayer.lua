-- Pastime: Mehrspieler – eine Sitzung zwischen zwei Spielern (Definition: MULTIPLAYER.md)
--
-- Ablauf: Anfrage (INVITE) -> Annehmen (ACCEPT) -> der Einladende wählt ein Spiel (START) ->
-- abwechselnd Züge (MOVE) -> Ergebnis (RESULT). Alles geht als unsichtbare Addon-Nachricht direkt
-- an den Mitspieler. Beide Seiten führen das Spiel mit demselben Regelwerk (MP.Register) und
-- senden nur Züge; ein Zug, den das Regelwerk nicht erlaubt, wird nicht ausgeführt.
--
-- Unterbrechungen: Jede laufende Partie steht als Mitschrift in PastimeDB.mp.paused. Wer das
-- Fenster schließt, neu lädt oder zehn Minuten nichts tut, hält die Partie an; sie zählt dann für
-- niemanden. Fragen sich dieselben beiden binnen zehn Minuten wieder an, kann sie fortgesetzt werden.
local ADDON, ns = ...
local Comm = ns.Comm

local MP = {}
ns.MP = MP

MP.LEVEL = 1                 -- Mehrspieler-Stufe, die in HELLO gemeldet wird
MP.games, MP.order = {}, {}  -- Regelwerke je Spiel-ID und ihre Reihenfolge in der Spielwahl
MP.session = nil             -- die eine laufende Sitzung
MP.invites = {}              -- [Absender] = { id, t }: offene Anfragen an mich
MP.note = nil                -- letzter Hinweis für die Anzeige (z. B. "declined")

local INVITE_TTL, CHOOSE_TTL, IDLE_TTL, PAUSE_TTL = 60, 120, 600, 600
local MAX_INVITES, CHUNK = 3, 40

-- Regelwerk eines Spiels:
--   New(seed)                 -> Zustand
--   Legal(state, seat, value) -> darf Platz seat (1 oder 2) diesen Zug machen?
--   Apply(state, seat, value) -> nil: weiter · 0: unentschieden · 1/2: dieser Platz hat gewonnen;
--                                zweiter Rückgabewert: wer als Nächster dran ist (sonst der andere)
function MP.Register(id, rules)
    MP.games[id] = rules
    MP.order[#MP.order + 1] = id
end

-- Eingeschaltet? In 1.x nur über den Schalter für Betatests (/pastime mp), dazu die Einstellung
function MP.On()
    return Comm.ENABLED and ns.DB and ns.DB.settings.mp and true or false
end

local function changed()
    if MP.onChange then ns.Safe("mp-anzeige", MP.onChange) end
    if ns.UpdateUI then ns.UpdateUI() end
end

local function store()
    local db = ns.DB.mp
    if type(db) ~= "table" then db = {}; ns.DB.mp = db end
    db.stats, db.paused = db.stats or {}, db.paused or {}
    return db
end

local function send(kind, ...)
    local s = MP.session
    return Comm.Send(kind, "WHISPER", s.partner, s.id, ...)
end

---------------------------------------------------------------------------
-- Mitschrift für die Wiederaufnahme
---------------------------------------------------------------------------
local function paused(partner)
    local db = store()
    local p = db.paused[partner]
    if type(p) ~= "table" or type(p.moves) ~= "table" or not MP.games[p.game] or time() - (tonumber(p.t) or 0) > PAUSE_TTL then
        db.paused[partner] = nil
        return nil
    end
    return p
end
MP.Paused = paused

local function save()
    local s = MP.session
    store().paused[s.partner] = { game = s.game, seed = s.seed, first = s.first, me = s.me, moves = { unpack(s.moves) }, t = time() }
end

---------------------------------------------------------------------------
-- Partie
---------------------------------------------------------------------------
local function begin(game, seed, first, me, expect)
    local s = MP.session
    s.prior = paused(s.partner)      -- die eigene Mitschrift, falls es eine gibt: zum Abgleich nach dem Nachspielen
    s.game, s.seed, s.first, s.me = game, seed, first, me
    s.board, s.moves, s.turn = MP.games[game].New(seed), {}, first
    s.state, s.expect, s.replaying, s.fresh = "playing", expect, expect > 0, expect > 0
    s.result, s.t = nil, GetTime()
    save()
end

local function finish(res, why)
    local s = MP.session
    s.state, s.why = "over", why
    s.result = res == 0 and 1 or (res == s.me and 2 or 0)      -- aus meiner Sicht: 0 verloren, 1 unentschieden, 2 gewonnen
    local db = store()
    db.paused[s.partner] = nil
    db.stats[s.partner] = db.stats[s.partner] or {}
    local g = db.stats[s.partner][s.game] or { w = 0, l = 0, d = 0 }
    db.stats[s.partner][s.game] = g
    if s.result == 2 then g.w = g.w + 1 elseif s.result == 0 then g.l = g.l + 1 else g.d = g.d + 1 end
    g.last = date("%Y-%m-%d")
    MP.last = { partner = s.partner, game = s.game, result = s.result }
    send("RESULT", s.result)
    ns.Log("I", "mp", "%s finished: %d (%s)", s.game, s.result, tostring(why or "played out"))
end

-- Einen Zug ausführen. quiet: beim Nachspielen einer Mitschrift
local function apply(seat, value, quiet)
    local s = MP.session
    local res, nextSeat = MP.games[s.game].Apply(s.board, seat, value)
    s.moves[#s.moves + 1] = value
    s.turn, s.t = nextSeat or (3 - seat), GetTime()
    if not quiet then s.fresh = false end
    save()
    if res ~= nil then finish(res) end
end

local function cancel(note)
    MP.session, MP.note = nil, note
    changed()
end

---------------------------------------------------------------------------
-- Was der Spieler tut
---------------------------------------------------------------------------
function MP.Invite(name)
    if not MP.On() or MP.session or type(name) ~= "string" or name == "" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    MP.session = { id = ("s%06x%04x"):format(math.random(0, 0xFFFFFF), math.random(0, 0xFFFF)), partner = name,
        role = "host", state = "asking", t = GetTime() }
    MP.note = nil
    send("INVITE")
    changed()
    return true
end

-- Auf eine Anfrage antworten
function MP.Answer(sender, yes)
    local inv = MP.invites[sender]
    MP.invites[sender] = nil
    if not inv or GetTime() - inv.t > INVITE_TTL or MP.session or not MP.On() then changed(); return false end
    if yes then
        MP.session = { id = inv.id, partner = sender, role = "guest", state = "waiting", t = GetTime() }
        MP.note = nil
        local p = paused(sender)
        send("ACCEPT", p and #p.moves or 0)
    else
        Comm.Send("DECLINE", "WHISPER", sender, inv.id)
    end
    changed()
    return true
end

-- Der Einladende wählt das Spiel. Nach einer entschiedenen Partie derselben beiden beginnt der Verlierer.
function MP.Choose(game)
    local s = MP.session
    if not (s and s.role == "host" and s.state == "choosing" and MP.games[game]) then return false end
    local first = math.random(2)
    local last = MP.last
    if last and last.partner == s.partner and last.game == game and last.result ~= 1 then first = last.result == 0 and 1 or 2 end
    local seed = math.random(1, 2147483646)
    send("START", game, seed, first, 1, 0)
    begin(game, seed, first, 1, 0)
    changed()
    return true
end

local function sendLog(p)
    send("START", p.game, p.seed, p.first, p.me, #p.moves)
    for i = 1, #p.moves, CHUNK do
        local part = {}
        for k = i, math.min(#p.moves, i + CHUNK - 1) do part[#part + 1] = tostring(p.moves[k]) end
        send("REPLAY", i, table.concat(part, ":"))
    end
end

-- Eigene Mitschrift wieder aufs Brett legen (der andere bekommt sie per sendLog)
local function restore(p)
    begin(p.game, p.seed, p.first, p.me, 0)
    local s = MP.session
    s.fresh = true
    for _, v in ipairs(p.moves) do
        if s.state ~= "playing" or not MP.games[s.game].Legal(s.board, s.turn, v) then return false end
        apply(s.turn, v, true)
    end
    return s.state == "playing"
end

-- Der Einladende setzt die angehaltene Partie fort, statt ein Spiel zu wählen
function MP.Resume()
    local s = MP.session
    if not (s and s.role == "host" and s.state == "choosing") then return false end
    local p = paused(s.partner)
    local mine = p and #p.moves or 0
    if mine == 0 and (s.theirs or 0) == 0 then return false end
    if mine >= (s.theirs or 0) then
        sendLog(p)
        if not restore(p) then send("BYE"); cancel("mismatch"); return false end
    else
        -- der andere hat die längere Mitschrift (hier fehlt sie etwa nach einem Absturz)
        send("RESUME")
        s.state, s.t = "resumeWait", GetTime()
    end
    changed()
    return true
end

function MP.Move(value)
    local s = MP.session
    if not (s and s.state == "playing" and not s.replaying and s.turn == s.me) then return false end
    if not MP.games[s.game].Legal(s.board, s.me, value) then return false end      -- bleibt am Zug, bis er etwas Erlaubtes tut
    send("MOVE", #s.moves + 1, value)
    apply(s.me, value)
    changed()
    return true
end

-- Aufgeben: sofort verloren
function MP.GiveUp()
    local s = MP.session
    if not (s and s.state == "playing") then return false end
    send("BYE")
    finish(3 - s.me, "gave up")
    changed()
    return true
end

-- Anhalten (Fenster zu, zurück zur Liste): die Partie zählt nicht und kann fortgesetzt werden
function MP.Pause()
    local s = MP.session
    if not s then return false end
    if s.state == "playing" then send("PAUSE") elseif s.state ~= "over" then send("BYE") end
    cancel(s.state == "playing" and "paused" or nil)
    return true
end

---------------------------------------------------------------------------
-- Was vom Mitspieler kommt. Comm hat Absender, Form und Menge schon geprüft; Gate entscheidet,
-- ob die Nachricht zur Lage passt.
---------------------------------------------------------------------------
local function openInvites()
    local n = 0
    for who, inv in pairs(MP.invites) do
        if GetTime() - inv.t > INVITE_TTL then MP.invites[who] = nil else n = n + 1 end
    end
    return n
end

function Comm.Gate(kind, fields, sender, channel)
    if kind == "HELLO" then return true end
    if not MP.On() then return false, "multiplayer off" end
    if channel ~= "WHISPER" then return false, "not direct" end
    local s = MP.session
    if kind == "INVITE" then
        if InCombatLockdown and InCombatLockdown() then return false, "combat" end
        if s then return false, "busy" end
        if not MP.invites[sender] and openInvites() >= MAX_INVITES then return false, "too many invites" end
        return true
    end
    if not (s and s.partner == sender and s.id == fields[1]) then return false, "not in session" end
    return true
end

local H = Comm.handlers

H.INVITE = function(sender, f)
    MP.invites[sender] = { id = f[1], t = GetTime() }
    ns.PlaySound("alarm")
    changed()
end

H.ACCEPT = function(_, f)
    local s = MP.session
    if s.role ~= "host" or s.state ~= "asking" then return end
    s.state, s.theirs, s.t = "choosing", f[2], GetTime()
    changed()
end

H.DECLINE = function()
    if MP.session.state == "asking" then cancel("declined") end
end

H.START = function(_, f)
    local s = MP.session
    if not ((s.role == "guest" and s.state == "waiting") or (s.role == "host" and s.state == "resumeWait")) then return end
    if not MP.games[f[2]] then send("BYE"); return cancel("unknown game") end
    begin(f[2], f[3], f[4], 3 - f[5], f[6])
    changed()
end

H.RESUME = function()
    local s = MP.session
    if s.role ~= "guest" or s.state ~= "waiting" then return end
    local p = paused(s.partner)
    if not p then send("BYE"); return cancel("mismatch") end
    sendLog(p)
    if not restore(p) then send("BYE"); return cancel("mismatch") end
    changed()
end

H.REPLAY = function(_, f)
    local s = MP.session
    if s.state ~= "playing" or not s.replaying or f[2] ~= #s.moves + 1 then return end
    for v in f[3]:gmatch("[^:]+") do
        v = tonumber(v)
        if not v or s.state ~= "playing" or not MP.games[s.game].Legal(s.board, s.turn, v) then send("BYE"); return cancel("mismatch") end
        apply(s.turn, v, true)
    end
    if #s.moves >= s.expect then
        s.replaying = false
        -- hatte ich selbst eine Mitschrift, muss sie zu dem passen, was gerade ankam
        local p = s.prior
        if p then
            local same = p.game == s.game and p.seed == s.seed and p.first == s.first and p.me == s.me
            for i = 1, math.min(#p.moves, #s.moves) do same = same and p.moves[i] == s.moves[i] end
            if not same then send("BYE"); return cancel("mismatch") end
        end
    end
    changed()
end

H.MOVE = function(_, f)
    local s = MP.session
    if s.state ~= "playing" or s.replaying or s.turn == s.me or f[2] ~= #s.moves + 1 then
        return ns.Log("D", "mp", "move %d ignored (state %s, turn %s)", f[2], tostring(s.state), tostring(s.turn))
    end
    -- ein Zug, den die Regeln nicht erlauben, wird nicht ausgeführt: der Mitspieler bleibt am Zug
    if not MP.games[s.game].Legal(s.board, s.turn, f[3]) then return ns.Log("W", "mp", "illegal move %d ignored", f[3]) end
    apply(s.turn, f[3])
    changed()
end

H.RESULT = function(_, f)
    local s = MP.session
    if s.state ~= "over" then return end
    -- Gegenprobe: was er für sich meldet, muss das Spiegelbild von meinem Ergebnis sein
    if f[2] ~= 2 - s.result then
        s.disputed = true
        ns.Log("W", "mp", "results differ: mine %d, theirs %d", s.result, f[2])
        changed()
    end
end

H.PAUSE = function()
    if MP.session.state == "playing" then cancel("partner paused") end
end

H.BYE = function()
    local s = MP.session
    if s.state == "playing" and not s.fresh then
        finish(s.me, "partner gave up")
        changed()
    elseif s.state ~= "over" then
        -- vor dem ersten neuen Zug: nichts passiert, nichts gewertet
        if s.state == "playing" then store().paused[s.partner] = nil end
        cancel("cancelled")
    end
end

---------------------------------------------------------------------------
-- Fristen (einmal je Sekunde)
---------------------------------------------------------------------------
function MP.Tick()
    local before = 0
    for _ in pairs(MP.invites) do before = before + 1 end
    if openInvites() ~= before then changed() end      -- eine verfallene Anfrage verschwindet auch aus der Anzeige
    local s = MP.session
    if not s then return end
    local idle = GetTime() - (s.t or 0)
    if s.state == "asking" and idle > INVITE_TTL then
        cancel("no answer")
    elseif (s.state == "choosing" or s.state == "waiting" or s.state == "resumeWait") and idle > CHOOSE_TTL then
        send("BYE")
        cancel("timed out")
    elseif s.state == "playing" and idle > IDLE_TTL then
        send("PAUSE")
        cancel("paused")
    end
end

---------------------------------------------------------------------------
-- Wer zu sehen ist: Pastime-Nutzer mit Mehrspieler aus den eingeschalteten Kreisen
---------------------------------------------------------------------------
local CIRCLE = { PARTY = "mpParty", RAID = "mpParty", GUILD = "mpGuild", WHISPER = "mpFriends" }

-- Stufe, die HELLO in diesem Kanal meldet: 0, wenn man dort nicht gesehen werden will
function Comm.MPLevel(channel)
    return MP.On() and ns.DB.settings[CIRCLE[channel] or ""] and MP.LEVEL or 0
end

function MP.Players()
    local list = {}
    if not MP.On() then return list end
    for name, p in pairs(Comm.peers) do
        if (p.mp or 0) >= 1 and GetTime() - (p.t or 0) < 900 and ns.DB.settings[CIRCLE[p.channel] or ""] then
            list[#list + 1] = { name = name, circle = CIRCLE[p.channel] }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Bilanz gegen einen Spieler in einem Spiel (oder über alle Spiele)
function MP.Record(partner, game)
    local w, l, d = 0, 0, 0
    for id, g in pairs(store().stats[partner] or {}) do
        if not game or id == game then w, l, d = w + (g.w or 0), l + (g.l or 0), d + (g.d or 0) end
    end
    return w, l, d
end

-- Der Mitspieler ist offline (der Client meldet es nach einer direkten Nachricht): eine laufende
-- Partie hält an, alles andere ist vorbei
function Comm.onOffline(target)
    local s = MP.session
    if s and s.partner == target and s.state ~= "over" then cancel(s.state == "playing" and "paused" or "offline") end
end

-- Nur zum Testen
function MP._Reset()
    MP.session, MP.note, MP.last = nil, nil, nil
    wipe(MP.invites)
end
