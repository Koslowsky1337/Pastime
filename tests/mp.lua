-- Mehrspieler: Sitzungen zwischen zwei Spielern (Anfrage, Spielwahl, Züge, Aufgeben, Wiederaufnahme)
-- Aufruf: python3 tests/run.py . tests/mp.lua
-- Getestet wird immer eine Seite; was der Mitspieler schickt, kommt als Nachricht herein.
local ns = KW
local C, MP = ns.Comm, ns.MP
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")

local SENT = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel, target) SENT[#SENT + 1] = { msg = msg, channel = channel, target = target }; return true end }
IsInGuild = function() return true end
IsInGroup = function() return true end
IsInRaid = function() return false end
C.Enable()
local function flush() for _ = 1, 40 do NOW = NOW + 0.6; C.Flush() end end
local function last() flush(); return SENT[#SENT] or {} end
local function sent(text) flush(); for _, m in ipairs(SENT) do if m.msg == text then return m end end end
local function from(who, kind, ...) C.OnMessage(C.PREFIX, C.Encode(kind, ...), "WHISPER", who) end
local JAINA = "Jaina Prachtmeer"      -- Namen haben hier Vor- und Nachnamen

-- Ausgeschaltet: nichts geht hinaus, nichts wird angenommen
check(not MP.On() and MP.Invite(JAINA) == false and MP.session == nil, "Mehrspieler ist ohne Freischaltung aus")
from(JAINA, "INVITE", "s1")
check(next(MP.invites) == nil, "ausgeschaltet kommt keine Anfrage an")

SlashCmdList.PASTIME("mp")
check(MP.On() and PastimeDB.mpBeta == true, "/pastime mp schaltet die Beta frei")
SENT = {}

-- Regelwerk Vier gewinnt
local R = MP.games.fourinarow
local st = R.New(1)
check(R.Legal(st, 1, 4) and not R.Legal(st, 1, 0) and not R.Legal(st, 1, 8) and not R.Legal(st, 1, 2.5), "Vier gewinnt: nur die Spalten 1 bis 7 sind Züge")
for _ = 1, 6 do R.Apply(st, 1, 3) end
check(not R.Legal(st, 2, 3), "Vier gewinnt: eine volle Spalte nimmt nichts mehr an")
st = R.New(1)
local res
for i = 1, 4 do res = R.Apply(st, 1, i) end
check(res == 1, "Vier gewinnt: vier in einer Reihe gewinnen")

-- Einladender: anfragen, der andere nimmt an, Spiel wählen, spielen bis zum Sieg
check(MP.Invite(JAINA) and MP.session.state == "asking" and last().msg == "PT1^INVITE^" .. MP.session.id and last().channel == "WHISPER" and last().target == JAINA,
    "Anfrage geht unsichtbar und direkt an den Mitspieler")
local sid = MP.session.id
check(MP.Invite("Thrall") == false, "während einer Sitzung keine zweite Anfrage")
check(MP.Choose("fourinarow") == false, "ein Spiel wählen geht erst nach dem Annehmen")
from("Thrall", "ACCEPT", sid, 0)
check(MP.session.state == "asking", "ein Fremder kann die Anfrage nicht annehmen")
from(JAINA, "ACCEPT", sid, 0)
check(MP.session.state == "choosing", "angenommen: der Einladende wählt das Spiel")
check(MP.Choose("snake") == false, "nur Spiele mit Mehrspieler-Regelwerk stehen zur Wahl")
check(MP.Choose("fourinarow") and MP.session.state == "playing" and MP.session.me == 1, "Spiel gewählt: die Partie läuft, der Einladende sitzt auf Platz 1")
local s = MP.session
check(last().msg == ("PT1^START^%s^fourinarow^%d^%d^1^0"):format(sid, s.seed, s.first), "START nennt Spiel, Startwert und wer beginnt: " .. tostring(last().msg))
check(PastimeDB.mp.paused[JAINA] and #PastimeDB.mp.paused[JAINA].moves == 0, "die Partie wird von Anfang an mitgeschrieben")
-- Ich werfe immer in Spalte 1, sie abwechselnd in 2 und 3: ich gewinne mit dem vierten Stein
local theirs = 0
local function theirMove() theirs = theirs + 1; from(JAINA, "MOVE", sid, #MP.session.moves + 1, 2 + theirs % 2) end
if s.turn ~= 1 then
    check(MP.Move(1) == false, "wer nicht dran ist, kann nicht ziehen")
    theirMove()
end
check(MP.Move(9) == false and s.turn == 1 and #SENT == #SENT, "ein ungültiger Zug wird nicht ausgeführt, man bleibt dran")
local n = #s.moves
check(MP.Move(1) and #s.moves == n + 1 and last().msg == ("PT1^MOVE^%s^%d^1"):format(sid, n + 1), "Zug ausgeführt und gesendet")
from(JAINA, "MOVE", sid, #s.moves + 5, 2)
check(#s.moves == n + 1, "ein Zug mit falscher Nummer wird verworfen")
from(JAINA, "MOVE", sid, #s.moves + 1, 9)
check(#s.moves == n + 1 and s.turn == 2, "ein ungültiger Zug des Mitspielers wird nicht ausgeführt, er bleibt dran")
from("Thrall", "MOVE", sid, #s.moves + 1, 2)
check(#s.moves == n + 1, "Züge von Fremden werden verworfen")
C.OnMessage(C.PREFIX, C.Encode("MOVE", sid, #s.moves + 1, 2), "GUILD", JAINA)
check(#s.moves == n + 1, "Züge über einen Kanal statt direkt werden verworfen")
theirMove()
for _ = 1, 3 do
    if MP.session.state ~= "playing" then break end
    MP.Move(1)
    if MP.session.state == "playing" then theirMove() end
end
check(s.state == "over" and s.result == 2, "vier in der Spalte: gewonnen")
check(sent(("PT1^RESULT^%s^2"):format(sid)) ~= nil, "das Ergebnis geht zur Gegenprobe an den Mitspieler")
local w, l, d = MP.Record(JAINA, "fourinarow")
check(w == 1 and l == 0 and d == 0 and PastimeDB.mp.paused[JAINA] == nil, "Bilanz 1:0, die Mitschrift ist weg")
from(JAINA, "RESULT", sid, 0)
check(not s.disputed, "meldet der Mitspieler das Spiegelbild, ist alles in Ordnung")
from(JAINA, "RESULT", sid, 2)
check(s.disputed, "melden beide einen Sieg, wird die Partie als strittig markiert")
PastimeDB.log[#PastimeDB.log] = nil      -- die Warnung dazu gehört zum Test
MP.Pause()
check(MP.session == nil, "nach der Partie ist die Sitzung zu Ende")

-- Revanche: der Verlierer beginnt
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0)
MP.Choose("fourinarow")
check(MP.session.first == 2, "Revanche: die Verliererin beginnt")
-- Aufgeben zählt als Niederlage
check(MP.GiveUp() and MP.session.result == 0 and sent(("PT1^BYE^%s"):format(sid)), "Aufgeben: verloren, der Mitspieler erfährt es")
w, l = MP.Record(JAINA)
check(w == 1 and l == 1, "Bilanz 1:1")
MP.Pause()

-- Eingeladener: Anfrage, annehmen, das Spiel kommt vom Einladenden
MP._Reset(); SENT = {}
COMBAT = true
from(JAINA, "INVITE", "g1")
check(MP.invites[JAINA] == nil, "im Kampf kommt keine Anfrage an")
COMBAT = false
from(JAINA, "INVITE", "g1")
check(MP.invites[JAINA] and MP.invites[JAINA].id == "g1" and MP.session == nil, "eine Anfrage wartet auf die Antwort des Spielers")
for i = 1, 5 do from("Spieler" .. i, "INVITE", "x" .. i) end
local open = 0
for _ in pairs(MP.invites) do open = open + 1 end
check(open == 3, "höchstens drei offene Anfragen (" .. open .. ")")
check(MP.Answer("Spieler1", false) and last().msg == "PT1^DECLINE^x1" and last().target == "Spieler1", "Ablehnen sagt dem Anfragenden Bescheid")
check(MP.Answer(JAINA, true) and MP.session.role == "guest" and MP.session.state == "waiting" and last().msg == "PT1^ACCEPT^g1^0", "Annehmen: warten, bis der andere ein Spiel wählt")
from(JAINA, "START", "g1", "doesnotexist", 5, 1, 1, 0)
check(MP.session == nil and last().msg == "PT1^BYE^g1", "ein unbekanntes Spiel beendet die Sitzung")
from(JAINA, "INVITE", "g2"); MP.Answer(JAINA, true)
from(JAINA, "START", "g2", "fourinarow", 5, 1, 1, 0)
s = MP.session
check(s.state == "playing" and s.me == 2 and s.turn == 1, "die Partie läuft, der Eingeladene sitzt auf Platz 2")
from(JAINA, "MOVE", "g2", 1, 4)
check(#s.moves == 1 and s.turn == 2 and s.board.b[4][1] == 1, "ihr Zug liegt auf dem Brett")
MP.Move(4)
from(JAINA, "BYE", "g2")
check(s.state == "over" and s.result == 2 and s.why == "partner gave up", "gibt sie auf, habe ich gewonnen")
MP.Pause()

-- Fristen
MP.Invite(JAINA); sid = MP.session.id
NOW = NOW + 61; MP.Tick()
check(MP.session == nil and MP.note == "no answer", "ohne Antwort verfällt die Anfrage nach 60 Sekunden")
from(JAINA, "INVITE", "old")
NOW = NOW + 61
check(MP.Answer(JAINA, true) == false and MP.session == nil, "eine verfallene Anfrage lässt sich nicht mehr annehmen")

-- Anhalten und fortsetzen: beide haben die Mitschrift (etwa nach /reload)
MP._Reset(); SENT = {}
PastimeDB.mp.paused = {}
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0)
MP.last = nil
math.randomseed(3)
MP.Choose("fourinarow")
s = MP.session
local moves = {}
for i = 1, 3 do
    if s.turn == 1 then MP.Move(i) else from(JAINA, "MOVE", sid, #s.moves + 1, i + 3) end
    moves[i] = s.moves[i]
end
local game, seed, first, turn = s.game, s.seed, s.first, s.turn
check(MP.Pause() and MP.session == nil and MP.note == "paused" and sent(("PT1^PAUSE^%s"):format(sid)), "Anhalten: die Sitzung endet, der Mitspieler erfährt es")
w, l, d = MP.Record(JAINA)
check(w + l + d == 3 and #PastimeDB.mp.paused[JAINA].moves == 3, "angehalten zählt nicht, die Mitschrift bleibt")
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 3)
check(MP.session.theirs == 3, "beim Annehmen meldet sie, dass sie drei Züge mitgeschrieben hat")
SENT = {}
check(MP.Resume() and MP.session.state == "playing" and #MP.session.moves == 3 and MP.session.turn == turn and MP.session.seed == seed,
    "Fortsetzen: das Brett steht wieder da, derselbe ist am Zug")
check(sent(("PT1^START^%s^%s^%d^%d^1^3"):format(sid, game, seed, first)) and sent(("PT1^REPLAY^%s^1^%s"):format(sid, table.concat(moves, ":"))),
    "die Mitschrift geht an den Mitspieler")
from(JAINA, "BYE", sid)
check(MP.session == nil and MP.note == "cancelled", "bricht sie vor dem ersten neuen Zug ab, zählt nichts")
check(select(1, MP.Record(JAINA)) + select(2, MP.Record(JAINA)) == 3, "die Bilanz bleibt, wie sie war")

-- Fortsetzen als Eingeladener: die Mitschrift kommt vom Einladenden und passt zur eigenen
PastimeDB.mp.paused[JAINA] = { game = "fourinarow", seed = 77, first = 1, me = 2, moves = { 4, 4, 5 }, t = time() }
from(JAINA, "INVITE", "r1"); MP.Answer(JAINA, true)
check(last().msg == "PT1^ACCEPT^r1^3", "der Eingeladene meldet seine drei Züge")
from(JAINA, "START", "r1", "fourinarow", 77, 1, 1, 3)
check(MP.session.state == "playing" and MP.session.replaying and MP.Move(1) == false, "während die Mitschrift ankommt, wird nicht gezogen")
from(JAINA, "REPLAY", "r1", 1, "4:4:5")
s = MP.session
check(s and not s.replaying and #s.moves == 3 and s.me == 2 and s.turn == 2 and s.board.b[4][2] == 2, "Mitschrift nachgespielt: Brett und Zugrecht stimmen")
check(MP.Move(5) and #s.moves == 4, "danach geht es normal weiter")
MP.Pause()
-- passt die Mitschrift nicht zur eigenen, wird nicht fortgesetzt
PastimeDB.mp.paused[JAINA] = { game = "fourinarow", seed = 77, first = 1, me = 2, moves = { 4, 4, 5 }, t = time() }
from(JAINA, "INVITE", "r2"); MP.Answer(JAINA, true)
from(JAINA, "START", "r2", "fourinarow", 77, 1, 1, 3)
from(JAINA, "REPLAY", "r2", 1, "4:4:6")
check(MP.session == nil and MP.note == "mismatch" and last().msg == "PT1^BYE^r2", "zwei Mitschriften, die sich widersprechen: keine Fortsetzung")

-- Nach einem Absturz fehlt die eigene Mitschrift: der Mitspieler liefert sie
PastimeDB.mp.paused = {}
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 3)
check(MP.Resume() and MP.session.state == "resumeWait" and last().msg == "PT1^RESUME^" .. sid, "ohne eigene Mitschrift wird der Mitspieler um seine gebeten")
from(JAINA, "START", sid, "fourinarow", 77, 1, 2, 3)      -- sie saß auf Platz 2
from(JAINA, "REPLAY", sid, 1, "4:4:5")
s = MP.session
check(s.state == "playing" and s.me == 1 and #s.moves == 3 and s.turn == 2, "die Partie steht wieder, ich sitze auf dem anderen Platz")
MP.Pause()
-- und umgekehrt: der Eingeladene wird um seine Mitschrift gebeten
PastimeDB.mp.paused[JAINA] = { game = "fourinarow", seed = 77, first = 1, me = 2, moves = { 4, 4, 5 }, t = time() }
from(JAINA, "INVITE", "r3"); MP.Answer(JAINA, true)
SENT = {}
from(JAINA, "RESUME", "r3")
check(sent("PT1^START^r3^fourinarow^77^1^2^3") and sent("PT1^REPLAY^r3^1^4:4:5") and MP.session.state == "playing" and #MP.session.moves == 3,
    "gebeten, schickt der Eingeladene seine Mitschrift und legt sie selbst aufs Brett")
MP.Pause()
-- nach zehn Minuten verfällt eine angehaltene Partie
PastimeDB.mp.paused[JAINA] = { game = "fourinarow", seed = 77, first = 1, me = 2, moves = { 4 }, t = time() - 601 }
check(MP.Paused(JAINA) == nil and PastimeDB.mp.paused[JAINA] == nil, "eine angehaltene Partie verfällt nach zehn Minuten")

-- Zehn Minuten ohne Zug: die Partie hält von selbst an
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0); MP.Choose("fourinarow")
NOW = NOW + 601; MP.Tick()
check(MP.session == nil and MP.note == "paused" and PastimeDB.mp.paused[JAINA] ~= nil, "zehn Minuten ohne Zug: angehalten, nicht verloren")

-- Sichtbarkeit: in der Gruppe wird die Mehrspieler-Stufe gemeldet, in der Gilde nicht (Standard)
SENT = {}
C.Announce(); flush()
local guild, party
for _, m in ipairs(SENT) do if m.channel == "GUILD" then guild = m.msg elseif m.channel == "PARTY" then party = m.msg end end
check(party == "PT1^HELLO^0^1^" .. C.tag and guild == nil, "Betastand: die Gruppe erfährt die Mehrspieler-Stufe, die Gilde nichts")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 5), "PARTY", JAINA)
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10300, 0, 6), "PARTY", "Thrall")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 7), "GUILD", "Rexxar")
local players = MP.Players()
check(#players == 1 and players[1].name == JAINA, "Mitspielerliste: nur wer Mehrspieler meldet und in einem eingeschalteten Kreis ist")
PastimeDB.settings.mpGuild = true
check(#MP.Players() == 2, "mit eingeschalteter Gilde erscheinen auch Gildenmitglieder")
PastimeDB.settings.mp = false
check(#MP.Players() == 0 and MP.Invite(JAINA) == false, "Hauptschalter aus: niemand zu sehen, keine Anfragen")
PastimeDB.settings.mp, PastimeDB.settings.mpGuild = true, false

local errs = {}
for _, e in ipairs(PastimeDB.log) do if e.l == "E" then table.insert(errs, e.c .. ": " .. e.m) end end
check(#errs == 0, "keine Fehler im Protokoll:\n  " .. table.concat(errs, "\n  "))
check(#ERRORS_FORWARDED == 0, "keine Fehler an BugSack: " .. table.concat(ERRORS_FORWARDED, " | "))
print(("Mehrspieler-Tests: %d ok, %d Fehler"):format(passes, fails))
