-- Mehrspieler-Grundlage: Kodierung, Prüfung, Mengenbremse, Sitzungsregeln
local ns = KW
local C = ns.Comm
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end
end
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")

check(C.ENABLED == false and not C.registered, "multiplayer is off; without the chat API nothing is registered")
check(#C.PREFIX <= 16, "prefix fits 16 characters")
check(C.Send("INVITE", "WHISPER", "Thrall", "s1") == false, "no multiplayer message is sent while disabled")

-- Kodieren / Dekodieren
local m = C.Encode("START", "s1", "snake", 12345, 1, 2, 0)
check(m == "PT1^START^s1^snake^12345^1^2^0", "encode start: " .. tostring(m))
local kind, f = C.Decode(m)
check(kind == "START" and f[2] == "snake" and f[3] == 12345, "decode start")
check(C.Encode("START", "s1", "sn|ake", 1, 1, 1, 0) == nil, "no escape codes in fields")
check(C.Decode("PT1^REPLAY^s1^1^4:3:-2:7") == "REPLAY" and C.Decode("PT1^REPLAY^s1^1^4:x:2") == nil, "move lists hold numbers only")
check(C.Encode("MOVE", "s1", 1) == nil, "wrong field count refused")
check(C.Encode("EVIL", "x") == nil, "unknown type refused")

-- Bösartige oder kaputte Eingaben
local bad = {
    "", "PT1", "PT2^HELLO^100", "PT1^HELLO", "PT1^HELLO^abc", "PT1^HELLO^100^1^1^1", "PT1^HELLO^100^1^abc", "PT1^HELLO^100^1", "PT1^RUN^os.exit()",
    "PT1^HELLO^9999999", "PT1^MOVE^s1^0^1", "PT1^INVITE^s1^snake^1^9999", "PT1^INVITE^s1^|cffff0000x^1^1",
    "PT1^RESULT^s1^-5", "PT1^HELLO^1e9", ("PT1^HELLO^" .. string.rep("1", 300)), "PT1^HELLO^10\n0",
    "PT1^ROLL^s1^0", "PT1^ROLL^s1^101", "PT1^INVITE^s1^snake^0x10^5",
}
for _, b in ipairs(bad) do
    check(C.Decode(b) == nil, "rejects " .. b:sub(1, 40))
end
check(C.Sanitize("|cffff0000Böse|r\nZeile") == "cffff0000Böserrzeile" or not C.Sanitize("|cff|r"):find("|"), "sanitize removes |")
check(not C.Sanitize("a\0b\tc"):find("%c"), "sanitize removes control characters")

-- Kanal, Absender, Mengenbremse
C._Reset()
local hello = C.Encode("HELLO", 100, 0, 5)
check(C.Accept("OtherAddon", hello, "WHISPER", "Thrall") == nil, "foreign prefix")
check(C.Accept(C.PREFIX, hello, "CHANNEL", "Thrall") == nil, "public channels ignored")
check(C.Accept(C.PREFIX, hello, "WHISPER", "Thokk") == nil, "own messages ignored")
C_FriendList = { IsIgnored = function(n) return n == "Troll" end }
check(C.Accept(C.PREFIX, hello, "WHISPER", "Troll") == nil, "ignored players dropped")
local okCount = 0
for _ = 1, 20 do if C.Accept(C.PREFIX, hello, "WHISPER", "Spammer") then okCount = okCount + 1 end end
check(okCount == 6, "per-sender limit (6 burst), got " .. okCount)
NOW = NOW + 3
check(C.Accept(C.PREFIX, hello, "WHISPER", "Spammer") ~= nil, "bucket refills over time")
local many = 0
for i = 1, 60 do if C.Accept(C.PREFIX, hello, "PARTY", "P" .. i) then many = many + 1 end end
check(many < 40, "global limit holds against many senders: " .. many)

-- Versionsabgleich: nur die Versionsnummer geht an Gilde und Gruppe; wer älter ist, bekommt einen Hinweis
C._Reset()
check(C.VersionNumber("v1.3.0") == 10300 and C.VersionNumber("1.12.7") == 11207 and C.VersionNumber("dev") == nil
    and C.VersionNumber("v1.3.0-beta1") == nil and C.VersionText(10300) == "1.3.0", "version numbers: only full releases count")
local SENT, CHAT = {}, {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel, target) SENT[#SENT + 1] = { prefix, msg, channel, target }; return true end }
IsInGuild = function() return true end
IsInGroup = function() return false end
IsInRaid = function() return false end
local realPrint = ns.Print
ns.Print = function(text) CHAT[#CHAT + 1] = text end
local function flush() for _ = 1, 6 do NOW = NOW + 1; C.Flush() end end
C.Enable()
ns.VERSION = "dev"
C.Announce(); flush()
check(#SENT == 0, "a development copy announces nothing")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 20000, 0, 5), "GUILD", "Thrall")
check(#CHAT == 0 and C.peers.Thrall and C.peers.Thrall.v == 20000, "and is not told to update, but knows who has Pastime")
ns.VERSION = "v1.3.0"
C.Announce(); flush()
check(#SENT == 1 and SENT[1][1] == C.PREFIX and SENT[1][2] == "PT1^HELLO^10300^0^" .. C.tag and SENT[1][3] == "GUILD" and SENT[1][4] == nil, "the version goes to the guild, nothing else")
IsInGroup = function() return true end
C.Announce(true); flush()
check(#SENT == 2 and SENT[2][3] == "PARTY", "on joining a group it goes to the group only")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10300, 0, 5), "GUILD", "Jaina"); flush()
check(#CHAT == 0 and #SENT == 2, "same version: no notice, no reply")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10200, 0, 5), "GUILD", "Rexxar"); flush()
check(#SENT == 2, "an older copy right after our own announcement: nothing more is sent")
NOW = NOW + 601
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10200, 0, 5), "GUILD", "Rexxar"); flush()
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10200, 0, 5), "GUILD", "Rexxar"); flush()
check(#CHAT == 0 and #SENT == 3 and SENT[3][3] == "GUILD" and SENT[3][4] == nil and SENT[3][2] == "PT1^HELLO^10300^0^" .. C.tag,
    "later an older copy makes us repeat our version once in the same channel, never as a whisper")
local whispers = 0
for _, m in ipairs(SENT) do if m[3] == "WHISPER" then whispers = whispers + 1 end end
check(whispers == 0, "no message ever goes from player to player")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10400, 0, 5), "PARTY", "Thrall")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10500, 1, 5), "PARTY", "Garrosh")
check(#CHAT == 1 and CHAT[1]:find("1.4.0", 1, true) and CHAT[1]:find("1.3.0", 1, true) and PastimeDB.newest == 10500 and C.peers.Garrosh.mp == 1,
    "a newer version is announced once per session and remembered: " .. tostring(CHAT[1]))
-- Eigene Nachrichten: der Kanal schickt sie zurück, womöglich unter einem längeren Namen (Vor- und Nachname)
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10300, 0, C.tag), "GUILD", "Thokk Eisenfaust")
check(C.selfNames["Thokk Eisenfaust"] and C.peers["Thokk Eisenfaust"] == nil, "our own announcement is recognised by its session mark, whatever the sender name")
check(C.Accept(C.PREFIX, C.Encode("HELLO", 10900, 0, 7), "GUILD", "Thokk Eisenfaust") == nil, "and from then on that sender counts as ourselves")
check(C.Send("INVITE", "WHISPER", "Thrall", "s1") == false, "multiplayer messages stay switched off")
ns.Print = realPrint
C_ChatInfo = nil
C._Reset()

-- Handler-Fehler bleiben eingefangen
local realHello = C.handlers.HELLO
C.handlers.HELLO = function() error("boom") end
C.OnMessage(C.PREFIX, C.Encode("HELLO", 100, 0, 9), "GUILD", "Thrall")
C.handlers.HELLO = realHello
check(#ERRORS_FORWARDED >= 1, "handler error caught and logged")

print(("Comm tests: %d ok, %d failed"):format(passes, fails))
