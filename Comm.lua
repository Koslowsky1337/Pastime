-- Pastime: Grundlage für den Mehrspieler (noch abgeschaltet) und Versionsabgleich
--
-- Von selbst sendet Pastime heute nur die eigene Versionsnummer (Nachricht HELLO) an Gilde und
-- Gruppe – unsichtbar, als Addon-Nachricht. Wer eine höhere Nummer empfängt, bekommt einmal einen
-- Hinweis auf das Update. Siehe „Versionsabgleich“ weiter unten.
--
-- Addon-Nachrichten sind für Spieler unsichtbar. Pastime erkennt seine eigenen
-- an der Kennung PREFIX und am Protokoll-Kopf PROTO. Alles, was ankommt, gilt
-- als nicht vertrauenswürdig:
--   * nur bekannte Nachrichtentypen mit fester Feldanzahl, Länge und Wertebereich
--   * nie als Code ausgeführt, nie als Formatstring benutzt, Farbcodes/Steuerzeichen
--     werden entfernt, bevor ein Name irgendwo angezeigt wird
--   * Mengenbremse pro Absender und insgesamt; Ignorierte und fremde Kanäle fallen raus
--   * Spielzüge nur vom Partner einer laufenden Partie mit passender Sitzungs-ID
--   * Einladungen brauchen immer eine Bestätigung des Spielers, verfallen nach 60 s,
--     höchstens eine offene pro Absender; im Kampf wird nichts angenommen
--   * Senden läuft gedrosselt über eine Warteschlange
local ADDON, ns = ...
local L = ns.L

local Comm = {}
ns.Comm = Comm

Comm.ENABLED = false                 -- wird mit dem Mehrspieler-Update eingeschaltet
Comm.VERSION_CHECK = true            -- HELLO senden und auswerten (unabhängig vom Mehrspieler)
-- Eigene Nachrichten kommen aus Gilde und Gruppe zurück. Der Absendername ist dabei nicht immer
-- UnitName("player") (WoW Forever kennt Vor- und Nachnamen), deshalb trägt jede Meldung eine
-- zufällige Sitzungsmarke: kommt sie zurück, ist der Absender man selbst.
Comm.tag = math.random(1, 999999)
Comm.selfNames = {}                  -- [Absendername] = true: unter diesem Namen sendet man selbst
Comm.PREFIX = "PastimeMiniGames"     -- 16 Zeichen (Höchstlänge)
Comm.PROTO = "PT1"                   -- Protokollversion
Comm.SEP = "^"
Comm.MAX_LEN = 240                   -- unter der Grenze von 255 Byte

-- Erlaubte Kanäle für eingehende Nachrichten
local CHANNELS = { WHISPER = true, PARTY = true, RAID = true, GUILD = true, INSTANCE_CHAT = true }

-- Feldprüfer: geben den bereinigten Wert oder nil zurück
local function int(lo, hi)
    return function(s)
        if type(s) ~= "string" or not s:match("^%-?%d+$") or #s > 10 then return nil end
        local n = tonumber(s)
        if not n or n < lo or n > hi then return nil end
        return n
    end
end
local function word(maxLen)
    return function(s)
        if type(s) ~= "string" or #s == 0 or #s > maxLen or not s:match("^[%w_%-:]+$") then return nil end
        return s
    end
end
local SESSION = word(12)
-- Liste ganzer Zahlen, mit „:“ getrennt
local function list(maxLen)
    return function(s)
        if type(s) ~= "string" or #s == 0 or #s > maxLen or not s:match("^[%d:%-]+$") then return nil end
        return s
    end
end

-- Nachrichtentypen: Feldliste in fester Reihenfolge
Comm.TYPES = {
    HELLO  = { int(0, 999999), int(0, 99), int(1, 999999) },    -- Addon-Version (10300 = 1.3.0, 0 = Betastand), Mehrspieler-Stufe, Sitzungsmarke
    INVITE = { SESSION },                                       -- Anfrage
    ACCEPT = { SESSION, int(0, 500) },                          -- angenommen; Züge der angehaltenen Partie mit diesem Spieler (0 = keine)
    DECLINE = { SESSION },
    -- Spiel, Startwert, Platz (1/2), der beginnt, Platz des Absenders, Züge, die als Mitschrift folgen (0 = neue Partie)
    START  = { SESSION, word(16), int(1, 2147483647), int(1, 2), int(1, 2), int(0, 500) },
    MOVE   = { SESSION, int(1, 100000), int(-100000, 100000) }, -- Sitzung, laufende Nr., Zug
    REPLAY = { SESSION, int(1, 100000), list(200) },            -- Mitschrift: ab Zug Nr., Züge mit „:“ getrennt
    RESUME = { SESSION },                                       -- „schick du die Mitschrift“
    RESULT = { SESSION, int(0, 2) },                            -- aus Sicht des Absenders: 0 verloren, 1 unentschieden, 2 gewonnen
    PAUSE  = { SESSION },                                       -- angehalten, zählt nicht
    BYE    = { SESSION },                                       -- aufgegeben oder abgebrochen
}

-- Farbcodes, Links, Texturen und Steuerzeichen aus fremden Texten entfernen
function Comm.Sanitize(s, maxLen)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|", ""):gsub("[%c]", "")
    if #s > (maxLen or 48) then s = s:sub(1, maxLen or 48) end
    return s
end

function Comm.Encode(kind, ...)
    local spec = Comm.TYPES[kind]
    if not spec then return nil, "unknown type" end
    local n = select("#", ...)
    if n ~= #spec then return nil, "field count" end
    local parts = { Comm.PROTO, kind }
    for i = 1, n do
        local v = tostring((select(i, ...)))
        if not spec[i](v) then return nil, "field " .. i end
        parts[#parts + 1] = v
    end
    local msg = table.concat(parts, Comm.SEP)
    if #msg > Comm.MAX_LEN then return nil, "too long" end
    return msg
end

-- Gibt kind, { Felder } zurück oder nil, Grund
function Comm.Decode(text)
    if type(text) ~= "string" or #text == 0 or #text > Comm.MAX_LEN then return nil, "size" end
    if text:find("[%c|]") then return nil, "characters" end
    local parts = {}
    for p in (text .. Comm.SEP):gmatch("(.-)%" .. Comm.SEP) do
        parts[#parts + 1] = p
        if #parts > 8 then return nil, "too many fields" end
    end
    if parts[1] ~= Comm.PROTO then return nil, "protocol" end
    local kind = parts[2]
    local spec = Comm.TYPES[kind]
    if not spec then return nil, "type" end
    if #parts - 2 ~= #spec then return nil, "field count" end
    local fields = {}
    for i, check in ipairs(spec) do
        local v = check(parts[i + 2])
        if v == nil then return nil, "field " .. i end
        fields[i] = v
    end
    return kind, fields
end

---------------------------------------------------------------------------
-- Mengenbremse (Token-Eimer): pro Absender und insgesamt
---------------------------------------------------------------------------
local Bucket = {}
Bucket.__index = Bucket
function Comm.NewBucket(capacity, perSecond)
    return setmetatable({ cap = capacity, rate = perSecond, n = capacity, t = GetTime() }, Bucket)
end
function Bucket:Take()
    local now = GetTime()
    self.n = math.min(self.cap, self.n + (now - self.t) * self.rate)
    self.t = now
    if self.n < 1 then return false end
    self.n = self.n - 1
    return true
end

local perSender, total = {}, nil
local MAX_SENDERS = 50

local function allowFrom(sender)
    total = total or Comm.NewBucket(30, 3)
    local b = perSender[sender]
    if not b then
        local count = 0
        for _ in pairs(perSender) do count = count + 1 end
        if count >= MAX_SENDERS then wipe(perSender) end
        b = Comm.NewBucket(6, 1)
        perSender[sender] = b
    end
    return b:Take() and total:Take()
end

local function isSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function isIgnored(name)
    if C_FriendList and C_FriendList.IsIgnored then
        local ok, res = ns.Try("C_FriendList.IsIgnored", C_FriendList.IsIgnored, name)
        return ok and res and true or false
    end
    return false
end

-- Was mit einer Nachricht geschieht: [Typ] = function(Absender, Felder, Kanal). Der Mehrspieler
-- (Multiplayer.lua) trägt seine ein und setzt Comm.Gate, das prüft, ob eine Nachricht zur Lage passt.
Comm.handlers = {}

-- Prüft eine eingehende Nachricht vollständig. Rückgabe: kind, fields, sender oder nil, Grund
function Comm.Accept(prefix, text, channel, sender)
    if prefix ~= Comm.PREFIX then return nil, "prefix" end
    if isSecret(text) or isSecret(sender) or isSecret(channel) then return nil, "secret" end
    if not CHANNELS[channel] then return nil, "channel" end
    if type(sender) ~= "string" or sender == "" then return nil, "sender" end
    sender = Ambiguate and Ambiguate(sender, "none") or sender
    if sender == ns.playerName or Comm.selfNames[sender] then return nil, "self" end
    if isIgnored(sender) then return nil, "ignored" end
    if not allowFrom(sender) then return nil, "rate" end
    local kind, fields = Comm.Decode(text)
    if not kind then return nil, fields end

    if Comm.Gate then
        local ok, why = Comm.Gate(kind, fields, sender, channel)
        if not ok then return nil, why end
    end
    return kind, fields, sender
end

function Comm.OnMessage(prefix, text, channel, sender)
    local kind, fields, who = Comm.Accept(prefix, text, channel, sender)
    if not kind then
        -- Dieser Client liefert auch die Addon-Nachrichten anderer Addons aus: die gehören nicht ins Protokoll
        if fields == "prefix" then return end
        -- verworfene Sitzungsnachrichten sind beim Testen die wichtigste Spur
        local direct = channel == "WHISPER" and prefix == Comm.PREFIX
        ns.Log(direct and "I" or "D", direct and "mp" or "comm", "dropped (%s)", tostring(fields))
        return
    end
    -- der Verlauf einer Sitzung steht im Protokoll, mit Kennung statt Name
    if kind ~= "HELLO" or channel == "WHISPER" then ns.Log("I", "mp", "in  %s from %s", kind, ns.NameId(who)) end
    local h = Comm.handlers[kind]
    if h then ns.Safe("comm-" .. kind, h, who, fields, channel) end
end

---------------------------------------------------------------------------
-- Senden: Warteschlange, höchstens eine Nachricht alle 0,5 s
---------------------------------------------------------------------------
local queue, lastSend = {}, 0
local SEND_GAP = 0.5
local RESULT_OK, RESULT_THROTTLE, RESULT_CHANNEL_THROTTLE = 0, 3, 8

function Comm.Send(kind, channel, target, ...)
    if not (Comm.ENABLED or (kind == "HELLO" and Comm.VERSION_CHECK)) then return false end      -- HELLO geht auch ohne Mehrspieler
    local msg, err = Comm.Encode(kind, ...)
    if not msg then ns.Log("W", "comm", "not sent: %s", tostring(err)); return false end
    if #queue >= 60 then ns.Log("W", "comm", "send queue full, %s dropped", tostring(kind)); return false end
    queue[#queue + 1] = { msg = msg, channel = channel, target = target, tries = 0 }
    return true
end

function Comm.Flush()
    local item = queue[1]
    if not item or GetTime() - lastSend < SEND_GAP then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then wipe(queue); return end
    lastSend = GetTime()
    if item.channel == "WHISPER" then Comm.lastDirect = { target = item.target, t = GetTime() } end
    local ok, res = ns.Try("C_ChatInfo.SendAddonMessage", C_ChatInfo.SendAddonMessage, Comm.PREFIX, item.msg, item.channel, item.target)
    local code = ok and (type(res) == "number" and res or (res == true and RESULT_OK)) or -1
    if code == RESULT_THROTTLE or code == RESULT_CHANNEL_THROTTLE then
        item.tries = item.tries + 1
        if item.tries < 5 then return end      -- später erneut versuchen
    end
    if code ~= RESULT_OK then ns.Log("D", "comm", "send result %s", tostring(code)) end
    local kind = item.msg:match("^[^%^]+%^([^%^]+)")
    if kind ~= "HELLO" or item.channel == "WHISPER" then
        ns.Log("I", "mp", "out %s to %s, result %s", tostring(kind), ns.NameId(item.target), tostring(code))
    end
    table.remove(queue, 1)
end

---------------------------------------------------------------------------
-- Versionsabgleich. Nur volle Versionen (v1.3.0) nehmen teil: Entwicklungs- und Betastände senden
-- nichts und werden nicht zum Aktualisieren aufgefordert.
---------------------------------------------------------------------------
-- "v1.3.0" -> 10300; alles andere -> nil
function Comm.VersionNumber(v)
    local a, b, c = tostring(v):match("^v?(%d+)%.(%d+)%.(%d+)$")
    a, b, c = tonumber(a), tonumber(b), tonumber(c)
    if not a or a < 1 or a > 99 or b > 99 or c > 99 then return nil end
    return a * 10000 + b * 100 + c
end

function Comm.VersionText(n)
    return ("%d.%d.%d"):format(math.floor(n / 10000), math.floor(n / 100) % 100, n % 100)
end

-- Hinweis auf eine neuere Version: höchstens einmal je Sitzung
local function notice(newer, mine)
    if Comm.noticed then return end
    Comm.noticed = true
    ns.Print((L["A newer version of Pastime is available: %s (you have %s). Update it with your addon manager."]):format(
        Comm.VersionText(newer), Comm.VersionText(mine)))
end

-- Eigene Version (0 = Entwicklungs- oder Betastand) und Mehrspieler-Stufe an einen Kanal.
-- Es gibt keine Nachricht von Spieler zu Spieler: gemeldet wird immer nur in Gilde, Gruppe
-- oder Schlachtzug.
local lastHello = {}      -- [Kanal] = Zeitpunkt der letzten Meldung
local lastLevel = {}      -- [Kanal oder Spieler] = zuletzt gemeldete Mehrspieler-Stufe
-- target: bei einer direkten Meldung an einen Freund sein Name
local function hello(channel, target)
    local mine = Comm.VersionNumber(ns.VERSION)
    local level = Comm.MPLevel and Comm.MPLevel(channel) or 0      -- 0, solange der Mehrspieler aus ist oder man hier nicht gesehen werden will
    local key = target or channel
    -- Betastände ohne Mehrspieler haben nichts zu melden – außer dass sie eben noch zu sehen waren (Abmelden)
    if not Comm.registered or not (mine or level > 0 or (lastLevel[key] or 0) > 0) then return end
    lastHello[key], lastLevel[key] = GetTime(), level
    ns.Log("D", "mp", "hello to %s: version %s, level %d", target and ns.NameId(target) or channel, tostring(mine or 0), level)
    Comm.Send("HELLO", channel, target, mine or 0, level, Comm.tag)
end

-- Freunde haben keinen Kanal: wer laut Freundesliste online ist, bekommt einmal je Sitzung eine direkte
-- Meldung (und eine weitere, wenn sich die eigene Sichtbarkeit ändert). Wer Pastime hat, antwortet einmal.
-- Direkte Nachrichten brauchen den vollen Namen (Vor- und Nachname). Nennt eine Liste nur den Vornamen,
-- wird der volle Name unter den bekannten Pastime-Nutzern und in der Gildenliste gesucht; ist er dort
-- nicht eindeutig zu finden, bleibt es beim Vornamen.
function Comm.FullName(name)
    if name:find(" ", 1, true) then return name end
    local found
    local function try(n)
        if type(n) ~= "string" or n:sub(1, #name + 1) ~= name .. " " then return end
        if found == nil then found = n elseif found ~= n then found = false end
    end
    for n in pairs(Comm.peers) do try(n) end
    if GetNumGuildMembers and GetGuildRosterInfo then
        for i = 1, GetNumGuildMembers() do try((GetGuildRosterInfo(i))) end
    end
    return found or name
end

local greeted = {}
function Comm.GreetFriends()
    local F = C_FriendList
    if not (Comm.registered and F and F.GetNumFriends and F.GetFriendInfoByIndex) then return end
    local level = Comm.MPLevel and Comm.MPLevel("WHISPER") or 0
    local ok, n = ns.Try("C_FriendList.GetNumFriends", F.GetNumFriends)
    for i = 1, ok and tonumber(n) or 0 do
        local ok2, info = ns.Try("C_FriendList.GetFriendInfoByIndex", F.GetFriendInfoByIndex, i)
        local name = ok2 and type(info) == "table" and info.connected and info.name
        name = type(name) == "string" and name ~= "" and Comm.FullName(name)
        if name and not Comm.selfNames[name] then
            if (not greeted[name] and level > 0) or (greeted[name] and lastLevel[name] ~= level) then
                greeted[name] = true
                hello("WHISPER", name)
            end
        end
    end
end

-- group = nur an die Gruppe (beim Beitritt)
function Comm.Announce(group)
    if not group then Comm.GreetFriends() end
    if not group and IsInGuild and IsInGuild() then hello("GUILD") end
    if IsInRaid and IsInRaid() then hello("RAID")
    elseif IsInGroup and IsInGroup() then hello("PARTY") end
end

-- Wer Pastime hat: [Name] = { v = Version, mp = höchste Mehrspieler-Stufe, t = zuletzt gehört, channel,
--   seen = { [Kanal] = { t, mp } } }
Comm.peers = {}
local REPLY_GAP = 600      -- so lange nach einer Meldung im selben Kanal wird nicht noch einmal gemeldet

Comm.handlers.HELLO = function(sender, fields, channel)
    if fields[3] == Comm.tag then Comm.selfNames[sender] = true; return end      -- die eigene Meldung
    local mine, theirs = Comm.VersionNumber(ns.VERSION), fields[1]
    local known = Comm.peers[sender]
    ns.Log("D", "mp", "hello from %s via %s: version %d, level %d", ns.NameId(sender), tostring(channel), theirs, fields[2])
    -- je Kanal merken, wann und mit welcher Stufe er sich gemeldet hat: in der Gilde kann jemand
    -- unsichtbar sein, den man in der Gruppe sieht
    local p = known or { seen = {} }
    p.seen = p.seen or {}
    p.seen[channel] = { t = GetTime(), mp = fields[2] }
    p.v, p.t, p.channel, p.mp = theirs, GetTime(), channel, math.max(fields[2], known and known.mp or 0)
    Comm.peers[sender] = p
    -- ein neuer Mitspieler: einmal zurückmelden, damit auch er mich sieht
    if fields[2] > 0 and not known and channel ~= "WHISPER" and Comm.MPLevel and Comm.MPLevel(channel) > 0
        and GetTime() - (lastHello[channel] or -60) >= 60 then
        hello(channel)
    end
    -- direkt gemeldet (er hat mich als Freund): einmal direkt antworten, wenn ich für Freunde sichtbar bin
    if channel == "WHISPER" and fields[2] > 0 and not greeted[sender] and Comm.MPLevel and Comm.MPLevel("WHISPER") > 0 then
        greeted[sender] = true
        hello("WHISPER", sender)
    end
    if not mine or theirs == 0 then return end
    if theirs > mine then
        ns.DB.newest = math.max(tonumber(ns.DB.newest) or 0, theirs)      -- auch beim nächsten Einloggen erinnern
        notice(theirs, mine)
    elseif theirs < mine and channel ~= "WHISPER" and GetTime() - (lastHello[channel] or -REPLY_GAP) >= REPLY_GAP then
        -- der andere ist älter: die eigene Version noch einmal im selben Kanal melden, damit er es erfährt
        hello(channel)
    end
end

-- Beim Einloggen: zuhören, nach ein paar Sekunden die eigene Version melden und an ein
-- früher gesehenes Update erinnern
function Comm.StartVersionCheck()
    if not Comm.VERSION_CHECK then return end
    Comm.Enable()
    if not Comm.registered then return end
    -- Der Absendername eigener Nachrichten ist der volle Name (Vor- und Nachname); GetUnitName liefert ihn,
    -- UnitName nur den Vornamen (im Client geprüft, Selbsttest vom 16.11.)
    local full = GetUnitName and GetUnitName("player", true)
    if type(full) == "string" and full ~= "" then Comm.selfNames[full] = true end
    C_Timer.After(8, ns.Wrap("comm-hello", function()
        local mine = Comm.VersionNumber(ns.VERSION)
        if mine and (tonumber(ns.DB.newest) or 0) > mine then notice(ns.DB.newest, mine) end
        Comm.Announce()
    end))
end

-- Geht eine direkte Nachricht an jemanden, der offline ist, schreibt der Client selbst die gelbe Zeile
-- „Kein Spieler mit dem Namen …“ in den Chat. Für die eigenen Nachrichten wird sie ausgeblendet.
function Comm.FilterOffline(_, _, text)
    local d = Comm.lastDirect
    if not (d and GetTime() - d.t < 5 and type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and type(text) == "string") then return false end
    if text ~= ERR_CHAT_PLAYER_NOT_FOUND_S:format(d.target) then return false end
    if Comm.onOffline then ns.Safe("comm-offline", Comm.onOffline, d.target) end
    return true
end

function Comm.Enable()
    if Comm.registered then return end
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
    C_ChatInfo.RegisterAddonMessagePrefix(Comm.PREFIX)
    Comm.registered = true
    if ChatFrame_AddMessageEventFilter then ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", Comm.FilterOffline) end
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:SetScript("OnEvent", ns.Wrap("comm", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then return Comm.OnMessage(...) end
        -- einer Gruppe beigetreten: dort einmal die Version melden
        local grouped = IsInGroup and IsInGroup() and true or false
        if grouped and not Comm.grouped then Comm.Announce(true) end
        Comm.grouped = grouped
    end))
    C_Timer.NewTicker(0.25, ns.Wrap("comm-send", Comm.Flush))
end

-- Nur zum Testen: Zustand zurücksetzen
function Comm._Reset()
    wipe(perSender); total = nil; wipe(queue); lastSend = 0
    if ns.MP then ns.MP._Reset() end
    wipe(lastHello); wipe(lastLevel); wipe(greeted); wipe(Comm.peers); wipe(Comm.selfNames); Comm.noticed = nil; Comm.grouped = nil
end
