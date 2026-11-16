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
-- zwischen zwei Nachrichten vergeht im Spiel mindestens eine halbe Sekunde; ohne das griffe die Mengenbremse
local function from(who, kind, ...) NOW = NOW + 1; C.OnMessage(C.PREFIX, C.Encode(kind, ...), "WHISPER", who) end
local JAINA = "Jaina Prachtmeer"      -- Namen haben hier Vor- und Nachnamen
local function best(key) local l = PastimeDB.scores[key]; return l and l[1] and l[1].s end

-- Ausgeschaltet: nichts geht hinaus, nichts wird angenommen
check(not MP.On() and MP.Invite(JAINA) == false and MP.session == nil, "Mehrspieler ist ohne Freischaltung aus")
from(JAINA, "INVITE", "s1")
check(next(MP.invites) == nil, "ausgeschaltet kommt keine Anfrage an")

SlashCmdList.PASTIME("mp")
local ask = ns.mpAskFrame
check(PastimeDB.mpBeta == true and not MP.On() and ask and ask.shown and #ask.checks == 7, "/pastime mp schaltet die Beta frei und fragt zuerst, wer einen sehen darf")
C.Announce(); flush()
local early = 0
for _, m in ipairs(SENT) do if m.msg:find("^PT1%^HELLO%^0%^1") then early = early + 1 end end
check(early == 0 and MP.Invite(JAINA) == false, "solange die Frage offen ist, wird nichts gemeldet und nichts angefragt")
check(ask.checks[4]:GetChecked() == true and ask.checks[4].key == "mpGuild", "vorgeschlagen ist alles an, auch die Gilde")
check(ask.checks[5]:GetChecked() == true and ask.checks[6]:GetChecked() == true and ask.checks[7]:GetChecked() == false and ask.checks[7].key == "mpInviteAnywhere",
    "Anfragen: vorgeschlagen sind Reisen und Ruhebereiche, „überall“ ist aus")
ask.checks[4]:SetChecked(false)
ask.save.scripts.OnClick(ask.save)
check(MP.On() and PastimeDB.mpAsked == true and not ask.shown and PastimeDB.settings.mpGuild == false and PastimeDB.settings.mpParty == true,
    "Speichern übernimmt die Wahl; erst dann ist der Mehrspieler an")
check(PastimeDB.settings.mpInviteTravel == true and PastimeDB.settings.mpInviteRest == true and PastimeDB.settings.mpInviteAnywhere == false,
    "Anfragen kommen als Standard nur auf Reisen und in Ruhebereichen an")
-- Wer die Frage in einer älteren Fassung beantwortet hat, wird einmal neu gefragt – mit seiner Wahl vorbelegt
check(PastimeDB.mpAskV == 2 and not ns.MPAskOpen(), "die beantwortete Frage merkt sich ihre Fassung")
PastimeDB.mpAskV = nil
if ns.MPAskOpen() then ns.MPAsk() end
check(ask.shown and MP.On() and ask.checks[4]:GetChecked() == false and ask.checks[7]:GetChecked() == false and ask.checks[5]:GetChecked() == true,
    "ältere Antwort: die Frage kommt noch einmal, der Mehrspieler bleibt an, die bisherige Wahl steht drin")
ask.save.scripts.OnClick(ask.save)
check(not ask.shown and PastimeDB.mpAskV == 2 and PastimeDB.settings.mpGuild == false, "danach ist sie erledigt")
-- Wann Anfragen ankommen
SENT = {}
from(JAINA, "INVITE", "q1"); flush()
check(MP.invites[JAINA] == nil and SENT[#SENT].msg == "PT1^AWAY^q1" and SENT[#SENT].target == JAINA, "unterwegs zu Fuß: die Anfrage kommt nicht an, die Anfragende erfährt es")
IsResting = function() return true end
from(JAINA, "INVITE", "q2")
check(MP.invites[JAINA] ~= nil, "im Gasthaus kommt sie an")
MP.invites[JAINA] = nil
PastimeDB.settings.mpInviteRest = false
from(JAINA, "INVITE", "q3")
check(MP.invites[JAINA] == nil, "Ruhebereich abgeschaltet: auch im Gasthaus nicht")
IsResting = nil
PastimeDB.settings.mpInviteRest = true
ns.trip.active = true
from(JAINA, "INVITE", "q4")
check(MP.invites[JAINA] ~= nil, "auf einer Reise kommt sie an")
MP.invites[JAINA] = nil
ns.trip.active = false
-- der Anfragende sieht, warum nichts kam
MP.Invite(JAINA)
from(JAINA, "AWAY", MP.session.id)
check(MP.session == nil and MP.note == "away", "nimmt sie gerade keine Anfragen an, endet meine Anfrage mit diesem Hinweis")
-- für die übrigen Tests: Anfragen überall
PastimeDB.settings.mpInviteAnywhere = true
MP._Reset(); flush(); SENT = {}
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
-- Revanche: beide werden gefragt, beide müssen zustimmen; dann wählt die andere das Spiel
from(JAINA, "AGAIN", sid)
check(MP.session.state == "over" and MP.session.theirAgain and not MP.session.again, "sie will eine Revanche: es fehlt noch meine Zustimmung")
SENT = {}
check(MP.Again() and MP.session.id == sid and MP.session.role == "guest" and MP.session.state == "waiting", "beide wollen: dieselbe Sitzung geht weiter, diesmal wählt sie")
flush()
check(sent(("PT1^AGAIN^%s"):format(sid)) and not MP.Again(), "meine Zustimmung geht genau einmal raus")
from(JAINA, "START", sid, "fourinarow", 5, 1, 1, 0)
check(MP.session.state == "playing" and MP.session.me == 2, "ihre Spielwahl startet die nächste Partie")
MP.GiveUp()
MP.Again()
from(JAINA, "BYE", sid)
check(MP.session == nil and MP.note == "no rematch", "lehnt sie ab, ist die Sitzung für beide zu Ende")
-- andersherum: ich zuerst, dann sie – dann wähle ich
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "START", sid, "fourinarow", 5, 1, 1, 0)
check(MP.session.state == "asking", "ohne Zusage kein Spiel")
from(JAINA, "ACCEPT", sid, 0); MP.Choose("fourinarow"); MP.GiveUp()
MP.Again()
check(MP.session.state == "over" and MP.session.again, "ich will: es fehlt noch ihre Zustimmung")
from(JAINA, "AGAIN", sid)
check(MP.session.role == "guest" and MP.session.state == "waiting", "ich hatte gewählt, also wählt jetzt sie")
from(JAINA, "START", sid, "fourinarow", 6, 2, 1, 0); MP.GiveUp()
MP.Again(); from(JAINA, "AGAIN", sid)
check(MP.session.role == "host" and MP.session.state == "choosing", "beim nächsten Mal wähle wieder ich")
MP.Choose("fourinarow"); MP.GiveUp()
-- ablehnen, und die Frist
SENT = {}
MP.Pause(); flush()
check(MP.session == nil and sent(("PT1^BYE^%s"):format(sid)), "„Nein, danke“ sagt es der anderen")
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0); MP.Choose("fourinarow"); MP.GiveUp()
NOW = NOW + 100; MP.Tick()
check(MP.session ~= nil, "die Revanche-Frage bleibt zwei Minuten offen")
NOW = NOW + 30; MP.Tick()
check(MP.session == nil and MP.note == "no rematch", "danach ist die Sitzung zu Ende")
PastimeDB.mp.stats[JAINA].fourinarow.w, PastimeDB.mp.stats[JAINA].fourinarow.l = 1, 1      -- Bilanz wie vor diesem Abschnitt

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
-- in mehreren Kreisen: der nähere zählt (Freunde vor Gruppe vor Gilde)
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 5), "GUILD", JAINA)
local function circleOf(name) for _, p in ipairs(MP.Players()) do if p.name == name then return p.circle end end end
check(circleOf(JAINA) == "mpParty" and circleOf("Rexxar") == "mpGuild", "in Gruppe und Gilde zugleich: gezeigt wird die Gruppe")
C_FriendList = { GetNumFriends = function() return 1 end, GetFriendInfoByIndex = function() return { name = "Jaina" } end }
check(circleOf(JAINA) == "mpFriends", "steht sie auf der Freundesliste, wird sie als Freundin gezeigt")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 0, 5), "GUILD", JAINA)
check(circleOf(JAINA) ~= nil, "wer sich in der Gilde unsichtbar meldet, bleibt über die Gruppe zu sehen")
C_FriendList = nil
PastimeDB.settings.mp = false
check(#MP.Players() == 0 and MP.Invite(JAINA) == false, "Hauptschalter aus: niemand zu sehen, keine Anfragen")
PastimeDB.settings.mp, PastimeDB.settings.mpGuild = true, false

-- Wer gerade da ist, sagt der Client: Gruppen-, Gilden- und Freundesliste
local partyOnline = true
GetNumGroupMembers = function() return 2 end
GetUnitName = function(unit) return unit == "party1" and JAINA or (unit == "player" and "Thokk Eisenfaust" or nil) end
UnitIsConnected = function() return partyOnline end
local guildOnline = { Rexxar = true }
GetNumGuildMembers = function() return 2 end
GetGuildRosterInfo = function(i) local n = i == 1 and "Rexxar" or JAINA; return n, nil, nil, nil, nil, nil, nil, nil, guildOnline[n] end
local function names() local t = {}; NOW = NOW + 4; for _, p in ipairs(MP.Players()) do t[p.name] = p.circle end; return t end
PastimeDB.settings.mpGuild = true
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 5), "GUILD", JAINA)
NOW = NOW + 2000
check(names()[JAINA] == "mpParty" and names().Rexxar == "mpGuild", "online laut Client: auch nach langer Zeit noch in der Liste")
partyOnline = false
check(names()[JAINA] == nil, "offline in der Gruppe und in der Gilde: sofort aus der Liste")
guildOnline[JAINA] = true
check(names()[JAINA] == "mpGuild", "in der Gilde online: über die Gilde zu sehen")
guildOnline.Rexxar = nil
check(names().Rexxar == nil, "aus der Gilde ausgeloggt: weg")
partyOnline, guildOnline.Rexxar = true, true
-- Diagnose für den Daten-Auszug: Stand in Zeilen, mit Kennung statt Name
local diag = table.concat(MP.Diagnose(), "\n")
check(diag:find("on true", 1, true) and diag:find(ns.NameId(JAINA), 1, true) and not diag:find("Jaina", 1, true)
    and diag:find("in the list: mpParty", 1, true) and diag:find("guild 2", 1, true),
    "Diagnose nennt Schalter, wer online ist und wer in der Liste steht – ohne Namen")
-- Ist der Reiter offen, meldet man sich höchstens einmal je Minute neu
flush(); SENT = {}
NOW = NOW + 100
MP.Refresh(); flush()
local again = 0
for _, m in ipairs(SENT) do if m.msg:find("^PT1%^HELLO") and (m.channel == "GUILD" or m.channel == "PARTY") then again = again + 1 end end
check(again == 2, "Reiter offen: einmal neu in Gilde und Gruppe gemeldet (" .. again .. ")")
NOW = NOW + 25
SENT = {}; MP.Refresh(); flush()
check(#SENT == 0, "aber nicht öfter als einmal je Minute")
-- Entdeckung: jede Meldung mit Mehrspieler wird direkt beantwortet, und die Antwort trägt den Kanal
flush(); SENT = {}
NOW = NOW + 100
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 31), "GUILD", "Cairne Bluthuf"); flush()
local here
for _, m in ipairs(SENT) do if m.msg == "PT1^HERE^1^GUILD" and m.channel == "WHISPER" and m.target == "Cairne Bluthuf" then here = m end end
check(here ~= nil, "wer sich in der Gilde meldet, bekommt eine direkte Antwort mit Stufe und Kanal")
local nSent = #SENT
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 31), "GUILD", "Cairne Bluthuf"); flush()
check(#SENT == nSent, "aber höchstens einmal in 50 Sekunden")
-- und umgekehrt: eine solche Antwort macht den Absender sichtbar, sobald die Gildenliste ihn als online führt
C.OnMessage(C.PREFIX, C.Encode("HERE", 1, "GUILD"), "WHISPER", "Baine Bluthuf")
check(C.peers["Baine Bluthuf"] and C.peers["Baine Bluthuf"].seen.GUILD.mp == 1 and names()["Baine Bluthuf"] == nil,
    "eine direkte Antwort merkt sich den Spieler; in der Liste steht er erst, wenn die Gildenliste ihn kennt")
guildOnline["Baine Bluthuf"] = true
GetNumGuildMembers = function() return 3 end
GetGuildRosterInfo = function(i) local n = i == 1 and "Rexxar" or (i == 2 and JAINA or "Baine Bluthuf"); return n, nil, nil, nil, nil, nil, nil, nil, guildOnline[n] end
check(names()["Baine Bluthuf"] == "mpGuild", "online in der Gildenliste: jetzt steht er da")
C.OnMessage(C.PREFIX, C.Encode("HERE", 1, "GUILD"), "GUILD", "Rexxar")
C.OnMessage(C.PREFIX, C.Encode("HERE", 1, "TRADE"), "WHISPER", "Rexxar")
check(true, "Antworten über einen Kanal oder für einen fremden Kanal werden nicht gewertet")
C.peers["Baine Bluthuf"], C.peers["Cairne Bluthuf"] = nil, nil
GetNumGuildMembers = function() return 2 end
GetGuildRosterInfo = function(i) local n = i == 1 and "Rexxar" or JAINA; return n, nil, nil, nil, nil, nil, nil, nil, guildOnline[n] end
-- Abmelden: wer sich für die Gruppe unsichtbar macht, sagt es dort einmal
C.Announce(); flush(); SENT = {}
PastimeDB.settings.mpParty = false
C.Announce(); flush()
local bye
for _, m in ipairs(SENT) do if m.channel == "PARTY" then bye = m.msg end end
check(bye == "PT1^HELLO^0^0^" .. C.tag, "unsichtbar für die Gruppe: einmal mit Stufe 0 abgemeldet (" .. tostring(bye) .. ")")
SENT = {}; C.Announce(); flush()
bye = nil
for _, m in ipairs(SENT) do if m.channel == "PARTY" then bye = m.msg end end
check(bye == nil, "danach meldet ein Betastand dort nichts mehr")
PastimeDB.settings.mpParty = true
-- Freunde: wer laut Freundesliste online ist, bekommt einmal eine direkte Meldung
local SYL = "Sylvanas Windläufer"
local friends = { { name = SYL, connected = true }, { name = "Garrosh", connected = false } }
C_FriendList = { GetNumFriends = function() return #friends end, GetFriendInfoByIndex = function(i) return friends[i] end }
SENT = {}; C.GreetFriends(); flush()
check(#SENT == 1 and SENT[1].channel == "WHISPER" and SENT[1].target == SYL and SENT[1].msg == "PT1^HELLO^0^1^" .. C.tag,
    "eine Freundin, die online ist, bekommt die Meldung direkt; wer offline ist, nichts")
C.GreetFriends(); flush()
check(#SENT == 1, "jeder Freund wird nur einmal je Sitzung gegrüßt")
check(names()[SYL] == nil, "solange sie nicht antwortet, steht sie nicht in der Liste")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 8), "WHISPER", SYL); flush()
check(names()[SYL] == "mpFriends" and #SENT == 1, "antwortet sie, steht sie als Freundin in der Liste; es geht nichts noch einmal zurück")
friends[1].connected = false
check(names()[SYL] == nil, "loggt sie aus, verschwindet sie")
friends[1].connected = true
-- nennt die Freundesliste nur den Vornamen, wird der volle Name in der Gildenliste gesucht
guildOnline["Thrall Kriegshäuptling"] = true
GetNumGuildMembers = function() return 3 end
GetGuildRosterInfo = function(i) local n = i == 1 and "Rexxar" or (i == 2 and JAINA or "Thrall Kriegshäuptling"); return n, nil, nil, nil, nil, nil, nil, nil, guildOnline[n] end
friends[2] = { name = "Thrall", connected = true }
check(C.FullName("Thrall") == "Thrall Kriegshäuptling" and C.FullName("Jaina Prachtmeer") == JAINA and C.FullName("Niemand") == "Niemand",
    "voller Name aus der Gildenliste; unbekannte bleiben, wie sie sind")
SENT = {}; C.GreetFriends(); flush()
check(#SENT == 1 and SENT[1].target == "Thrall Kriegshäuptling", "die direkte Meldung geht an den vollen Namen")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 12), "WHISPER", "Thrall Kriegshäuptling"); flush()
check(names()["Thrall Kriegshäuptling"] == "mpFriends", "antwortet er, steht er als Freund in der Liste, obwohl die Freundesliste nur „Thrall“ kennt")
friends[2] = { name = "Garrosh", connected = false }
C.peers["Thrall Kriegshäuptling"] = nil
SENT = { {}, }
-- Battle.net-Freunde: wer dieselbe Spielversion auf demselben Realm in derselben Fraktion spielt, zählt als Freund
GetNormalizedRealmName = function() return "TestRealm" end
WOW_PROJECT_ID = 18
local bnet = {
    { { isOnline = true, clientProgram = "WoW", characterName = "Lor'themar Theron", wowProjectID = 18, realmName = "TestRealm", factionName = "Horde" },
      { isOnline = true, clientProgram = "App" } },
    { { isOnline = true, clientProgram = "WoW", characterName = "Anduin Wrynn", wowProjectID = 18, realmName = "TestRealm", factionName = "Alliance" } },
    { { isOnline = true, clientProgram = "WoW", characterName = "Thalyssra", wowProjectID = 1, realmName = "TestRealm", factionName = "Horde" } },
    { { isOnline = true, clientProgram = "WoW", characterName = "Liadrin", wowProjectID = 18, realmName = "AndererRealm", factionName = "Horde" } },
    {},
}
BNGetNumFriends = function() return #bnet, 4 end
C_BattleNet = { GetFriendNumGameAccounts = function(i) return #bnet[i] end, GetFriendGameAccountInfo = function(i, j) return bnet[i][j] end }
local fr = C.OnlineFriends()
local nfr = 0
for _ in pairs(fr) do nfr = nfr + 1 end
check(fr["Lor'themar Theron"] and fr[SYL] and not fr["Anduin Wrynn"] and not fr.Thalyssra and not fr.Liadrin and nfr == 2,
    "Battle.net-Freunde zählen nur mit gleicher Spielversion, gleichem Realm und gleicher Fraktion (" .. nfr .. ")")
bnet[1][1].characterName = "Lorthemar Theron"
SENT = {}; C.GreetFriends(); flush()
check(#SENT == 1 and SENT[1].target == "Lorthemar Theron" and SENT[1].channel == "WHISPER", "ein Battle.net-Freund wird direkt unter seinem Charakternamen gegrüßt")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 10400, 1, 14), "WHISPER", "Lorthemar Theron"); flush()
check(names()["Lorthemar Theron"] == "mpFriends", "antwortet er, steht er als Freund in der Liste")
bnet[1][1].isOnline = false
check(names()["Lorthemar Theron"] == nil, "geht er bei Battle.net offline, verschwindet er")
BNGetNumFriends, C_BattleNet, GetNormalizedRealmName = nil, nil, nil
C.peers["Lorthemar Theron"] = nil
SENT = { {}, }
-- ein Fremder, der mich als Freund hat, meldet sich direkt: einmal antworten, aber er steht nicht in meiner Liste
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 9), "WHISPER", "Varian Wrynn"); flush()
check(#SENT == 2 and SENT[2].target == "Varian Wrynn" and SENT[2].channel == "WHISPER" and names()["Varian Wrynn"] == nil,
    "wer mich als Freund hat, bekommt eine Antwort und kann mich anfragen; in meiner Liste steht er nicht")
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 9), "WHISPER", "Varian Wrynn"); flush()
check(#SENT == 2, "geantwortet wird nur einmal")
-- die Schalter ändern, was Freunde erfahren
PastimeDB.settings.mpFriends = false
C.GreetFriends(); flush()
check(#SENT == 3 and SENT[3].target == SYL and SENT[3].msg == "PT1^HELLO^0^0^" .. C.tag, "unsichtbar für Freunde: die schon Gegrüßte erfährt es")
PastimeDB.settings.mpFriends = true
-- Debug: einen Spieler direkt per Namen anfragen
MP._Reset(); SENT = {}
SlashCmdList.PASTIME('invite "Brezzo Ozzerb"')
local inv = MP.session and sent("PT1^INVITE^" .. MP.session.id)
check(MP.session and MP.session.partner == "Brezzo Ozzerb" and inv and inv.target == "Brezzo Ozzerb" and inv.channel == "WHISPER",
    "/pastime invite fragt den genannten Spieler direkt an, Groß- und Kleinschreibung bleibt")
local trace = {}
for _, e in ipairs(PastimeDB.log) do if e.c == "mp" then trace[#trace + 1] = e.m end end
local text = table.concat(trace, "\n")
check(text:find("out INVITE to " .. ns.NameId("Brezzo Ozzerb"), 1, true) and not text:find("Brezzo", 1, true),
    "der Verlauf steht im Protokoll, mit Kennung statt Name")
from("Brezzo Ozzerb", "DECLINE", MP.session.id)
from("Brezzo Ozzerb", "MOVE", "zzz", 1, 1)
trace = {}
for _, e in ipairs(PastimeDB.log) do if e.c == "mp" then trace[#trace + 1] = e.m end end
text = table.concat(trace, "\n")
check(text:find("in  DECLINE from " .. ns.NameId("Brezzo Ozzerb"), 1, true) and text:find("dropped (not in session)", 1, true),
    "auch Eingehendes und Verworfenes steht im Protokoll")
SlashCmdList.PASTIME("invite")
check(MP.session == nil, "ohne Namen passiert nichts")
GetNumGroupMembers, GetUnitName, UnitIsConnected, GetNumGuildMembers, GetGuildRosterInfo, C_FriendList = nil, nil, nil, nil, nil, nil
C.peers[SYL], C.peers["Varian Wrynn"], C.peers.Rexxar = nil, nil, nil
PastimeDB.settings.mpGuild = false
C.OnMessage(C.PREFIX, C.Encode("HELLO", 0, 1, 5), "PARTY", JAINA)
MP._Reset()

-- Oberfläche: Reiter „Mehrspieler“, Anfrage-Fenster, Brett, geparktes Einzelspiel -------------------
local function click(b) b.scripts.OnClick(b) end
MP._Reset(); PastimeDB.mp.paused = {}; PastimeDB.mp.stats = {}
ns.ShowFrame("mp")
local v = ns.mpView
-- der sichtbare Knopf mit dieser Aufschrift
local function btn(text)
    for _, b in ipairs(v.buttons) do if b:IsShown() and b.text == text then return b end end
end
check(v:IsShown() and ns.frame.tabs[3]:IsShown() and ns.frame.tabs[3].key == "mp", "freigeschaltet gibt es den Reiter „Mehrspieler“")
check(v.rows[1]:IsShown() and v.rows[1].name.text:find(JAINA, 1, true) == 1 and v.rows[1].name.text:find("(P)", 1, true) and not v.rows[2]:IsShown() and not v.empty:IsShown(),
    "die Liste zeigt die Mitspielerin, dahinter das Kürzel für die Gruppe")
check(v.title.text == ns.L["Multiplayer"] and not v.buttons[1]:IsShown(), "ohne Sitzung steht dort die Anleitung")
click(v.rows[1].btn)
check(MP.session and MP.session.state == "asking" and v.title.text == JAINA and v.text.text == ns.L["Waiting for an answer …"]
    and v.buttons[1].text == ns.L["Cancel"] and not v.rows[1].btn:IsEnabled(), "Anfragen: der Reiter zeigt, dass auf die Antwort gewartet wird")
sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0)
check(v.text.text == ns.L["You choose the game:"] and btn(ns.gamesById.fourinarow.name) and btn(ns.gamesById.blackjack.name) and btn(ns.gamesById.runepairs.name) and v.buttons[#MP.order + 1].text == ns.L["Cancel"],
    "angenommen: die Mehrspieler-Spiele stehen zur Wahl")
MP.last = nil
math.randomseed(11)
click(btn(ns.gamesById.fourinarow.name))
local g = ns.run and ns.run.game
s = MP.session
check(ns.run and ns.run.mode == "mp" and ns.run.def.id == "fourinarow" and ns.gameView:IsShown() and g.mp == s and PastimeDB.modes.fourinarow ~= "mp",
    "Spiel gewählt: das Brett öffnet sich im Mehrspieler-Modus")
if s.turn ~= s.me then from(JAINA, "MOVE", sid, 1, 7) end
check(g.state == "player" and g.status.text == ns.L["You play red."] .. " " .. ns.L["Your turn."], "am Zug: das Brett sagt es, samt eigener Farbe")
g:Play(4)
local row = s.board.last[2]
check(g.state == "wait" and g.cells[4][row].disc:IsShown() and g.status.text:find((ns.L["Waiting for %s …"]):format(JAINA), 1, true), "mein Stein liegt, jetzt ist sie dran")
check(g.cells[4][row].disc.tex == "Interface\\Icons\\INV_BannerPVP_01", "der Einladende spielt Rot")
g:Play(4)
check(#s.moves == (s.first == 1 and 1 or 2), "solange sie dran ist, wirft mein Klick nichts")
from(JAINA, "MOVE", sid, #s.moves + 1, 5)
check(g.state == "player" and g.cells[5][1].disc:IsShown(), "ihr Stein erscheint auf dem Brett")
check(ns.gameView.side.restart.text == ns.L["Give up"], "während der Partie heißt der Knopf „Aufgeben“")
ns.Restart()
check(s.state == "over" and s.result == 0 and ns.run.state == "over" and ns.overlay.title.text == ns.L["Defeat"] and ns.overlay.text.text:find(ns.L["You gave up."], 1, true),
    "Aufgeben beendet die Partie als Niederlage")
check(best("fourinarow") == nil, "Mehrspieler-Partien kommen nicht in die Bestenliste")
check(ns.overlay.text.text:find(ns.L["Rematch? Both of you have to agree."], 1, true) and ns.overlay.btn1.text == ns.L["Rematch"] and ns.overlay.btn2.text == ns.L["No, thanks"],
    "nach der Partie fragt das Brett nach der Revanche")
local role = s.role
ns.Restart()
check(MP.session == s and s.again and s.state == "over" and ns.run ~= nil and ns.overlay.btn1.enabled == false
    and ns.overlay.text.text:find((ns.L["You want a rematch. Waiting for %s …"]):format(JAINA), 1, true),
    "derselbe Knopf stimmt der Revanche zu; das Brett wartet auf die andere")
from(JAINA, "AGAIN", s.id)
check(MP.session == s and s.role ~= role and (s.state == "waiting" or s.state == "choosing") and v:IsShown() and ns.run == nil,
    "stimmt sie auch zu, geht es bei der Spielwahl weiter – mit getauschten Rollen")
click(btn(ns.L["Cancel"]))
check(MP.session == nil and v.text.text == ns.L["Pick a player on the left and ask them for a game. They have to accept first."], "Abbrechen beendet die Sitzung")

-- Nach der Partie: die Revanche des anderen kommt an, obwohl mein Brett noch offen ist
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0); MP.last = nil; MP.Choose("fourinarow")
MP.GiveUp()
check(MP.session.state == "over" and ns.run and ns.run.mode == "mp", "die Partie ist vorbei, das Brett steht noch da")
from(JAINA, "INVITE", "rv1")
check(MP.invites[JAINA] and MP.invites[JAINA].id == "rv1" and MP.session == nil and ns.inviteFrame.shown,
    "ihre Revanche-Anfrage kommt an: eine beendete Partie hält niemanden besetzt")
click(ns.inviteFrame.yes)
check(MP.session and MP.session.id == "rv1" and MP.session.role == "guest" and MP.session.state == "waiting", "angenommen: ich warte auf ihre Spielwahl")
from(JAINA, "START", "rv1", "fourinarow", 9, 1, 1, 0)
g = ns.run.game
from(JAINA, "MOVE", "rv1", 1, 2)
check(g.mp == MP.session and g.cells[2][1].disc.tex == "Interface\\Icons\\INV_BannerPVP_01" and g.status.text:find(ns.L["You play blue."], 1, true),
    "als Eingeladener spiele ich Blau; ihr Stein ist rot")
g:Play(3)
check(g.cells[3][1].disc.tex == "Interface\\Icons\\INV_BannerPVP_02", "mein Stein ist blau")
from(JAINA, "BYE", "rv1")
ns.ShowLauncher()
-- Beide fragen gleichzeitig an: es gilt die Anfrage mit der kleineren Sitzungsnummer
MP.Invite(JAINA); sid = MP.session.id
SENT = {}
from(JAINA, "INVITE", "zzzzzzzzzz")
check(MP.session.id == sid and MP.session.state == "asking" and next(MP.invites) == nil, "gekreuzte Anfragen: meine hat die kleinere Nummer und gilt")
from(JAINA, "ACCEPT", sid, 0)
check(MP.session.state == "choosing", "sie nimmt meine an")
MP.Pause()
flush()
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "INVITE", "a0")
check(MP.session.id == "a0" and MP.session.role == "guest" and MP.session.state == "waiting" and sent("PT1^ACCEPT^a0^0"),
    "gekreuzte Anfragen: ihre hat die kleinere Nummer – ich nehme sie von selbst an")
MP.Pause()

-- Abbau: zieht der Anfragende zurück, verschwindet seine Anfrage bei mir
from(JAINA, "INVITE", "w1")
check(ns.inviteFrame.shown, "ihre Anfrage steht da")
from(JAINA, "BYE", "w1")
check(not ns.inviteFrame.shown and MP.invites[JAINA] == nil, "bricht sie ab, verschwindet die Anfrage sofort")
-- eine Nachricht zu einer Sitzung, die es hier nicht gibt, wird einmal mit BYE zurückgewiesen
flush(); SENT = {}
from(JAINA, "MOVE", "ghost", 3, 4)
from(JAINA, "MOVE", "ghost", 4, 4)
flush()
check(#SENT == 1 and SENT[1].msg == "PT1^BYE^ghost" and SENT[1].target == JAINA, "ein Zug zu einer unbekannten Sitzung: sie erfährt einmal, dass hier nichts läuft")
-- besetzt: wer anfragt, während ich spiele, bekommt sofort eine Absage
MP.Invite(JAINA); sid = MP.session.id
from(JAINA, "ACCEPT", sid, 0)
flush(); SENT = {}
from("Thrall", "INVITE", "busy1")
flush()
check(#SENT == 1 and SENT[1].msg == "PT1^DECLINE^busy1" and SENT[1].target == "Thrall" and MP.invites.Thrall == nil,
    "besetzt: der Anfragende bekommt sofort eine Absage statt 60 Sekunden zu warten")
-- und umgekehrt: weist die andere Seite meine Sitzung zurück, endet sie auch bei mir
MP.last = nil; MP.Choose("fourinarow")
from(JAINA, "BYE", sid)
check(MP.session == nil or MP.session.state == "over", "weist sie die Sitzung zurück, läuft sie auch bei mir nicht weiter")
MP.Pause(); ns.ShowLauncher()

-- Anfrage-Fenster und Parken: ich spiele gerade Windnatter und werde eingeladen
ns.StartGame(ns.gamesById.snake)
from(JAINA, "INVITE", "p1")
local pop = ns.inviteFrame
check(pop and pop.shown and pop.text.text:find(JAINA, 1, true) and pop.text.text:find(ns.L["Your current game waits until you are done."], 1, true),
    "Anfrage-Fenster erscheint und sagt, dass das laufende Spiel wartet")
click(pop.yes)
check(not pop.shown and MP.session.state == "waiting" and ns.run.def.id == "snake", "angenommen: bis das Spiel gewählt ist, läuft die Windnatter weiter")
from(JAINA, "START", "p1", "fourinarow", 9, 2, 1, 0)
check(ns.run.mode == "mp" and ns.parked and ns.parked.def.id == "snake" and ns.parked.state == "paused", "die Partie beginnt, die Windnatter ist geparkt")
ns.run.game:Play(3)
from(JAINA, "BYE", "p1")
check(ns.run.state == "over" and ns.overlay.text.text:find(ns.L["Your opponent gave up."], 1, true), "gibt sie auf, steht das im Ergebnis")
ns.ShowLauncher()
check(MP.session == nil and ns.parked == nil and ns.run and ns.run.def.id == "snake" and ns.run.state == "paused" and ns.gameView:IsShown(),
    "zurück: die Windnatter steht pausiert wieder da")
ns.ShowLauncher()
-- Ablehnen über das Fenster; eine verfallene Anfrage verschwindet
flush()
from(JAINA, "INVITE", "p2")
click(ns.inviteFrame.no)
check(not ns.inviteFrame.shown and MP.session == nil and last().msg == "PT1^DECLINE^p2", "Ablehnen über das Fenster")
from(JAINA, "INVITE", "p3")
NOW = NOW + 61; MP.Tick()
check(not ns.inviteFrame.shown, "eine verfallene Anfrage schließt ihr Fenster")
-- Dasselbe Spiel läuft allein: es wird abgebrochen, nicht geparkt
ns.StartGame(ns.gamesById.fourinarow, "leicht")
from(JAINA, "INVITE", "p4"); click(ns.inviteFrame.yes)
from(JAINA, "START", "p4", "fourinarow", 9, 1, 1, 0)
check(ns.run.mode == "mp" and ns.parked == nil, "läuft dasselbe Spiel allein, wird es abgebrochen statt geparkt")
-- Das Brett verlassen hält die Partie an; der Mitspieler bekommt Bescheid
SENT = {}
ns.ShowLauncher()
check(MP.session == nil and MP.note == "paused" and sent("PT1^PAUSE^p4") and v:IsShown() and v.text.text:find("zehn Minuten", 1, true) ~= nil == (ns.LOCALE == "deDE"),
    "Zur Auswahl: die Partie hält an und kann fortgesetzt werden")
-- Unterbrechung durch den Mitspieler, während das Brett offen ist
from(JAINA, "INVITE", "p5"); click(ns.inviteFrame.yes)
from(JAINA, "START", "p5", "fourinarow", 9, 1, 1, 0)
from(JAINA, "PAUSE", "p5")
check(ns.run.state == "over" and ns.overlay.title.text == ns.L["Interrupted"], "hält sie an, sagt das Brett „Unterbrochen“")
ns.ShowLauncher()
-- Offline: die gelbe Systemzeile wird für eigene Nachrichten geschluckt
flush()
MP.Invite(JAINA); NOW = NOW + 1; C.Flush()
ERR_CHAT_PLAYER_NOT_FOUND_S = "Kein Spieler mit dem Namen '%s' ist online."
check(C.FilterOffline(nil, nil, "Etwas anderes") == false and MP.session ~= nil, "andere Systemzeilen bleiben stehen")
check(C.FilterOffline(nil, nil, ERR_CHAT_PLAYER_NOT_FOUND_S:format(JAINA)) == true and MP.session == nil and MP.note == "offline",
    "ist die Mitspielerin offline, verschwindet die Systemzeile und die Anfrage endet")
-- Einstellungen: die Mehrspieler-Schalter
ns.ShowFrame("settings")
local sv = ns.settingsView
check(#sv.checks == 12 and sv.checks[6]:IsShown() and sv.checks[7]:GetChecked() == true and sv.checks[8]:GetChecked() == true and sv.checks[9]:GetChecked() == false
    and sv.checks[10]:GetChecked() == true and sv.checks[12]:GetChecked() == true,
    "Einstellungen: Mehrspieler-Schalter sichtbar; Freunde und Gruppe an, Gilde aus, dazu die drei für Anfragen")
sv.checks[6]:SetChecked(false); click(sv.checks[6])
check(PastimeDB.settings.mp == false and #MP.Players() == 0, "Hauptschalter aus: niemand mehr zu sehen")
sv.checks[6]:SetChecked(true); click(sv.checks[6])
-- Freischaltung zurücknehmen: der Reiter verschwindet
ns.ShowFrame("mp")
SlashCmdList.PASTIME("mp")
check(not MP.On() and not ns.frame.tabs[3]:IsShown() and not v:IsShown() and ns.launcher:IsShown(), "/pastime mp noch einmal: Mehrspieler aus, der Reiter ist weg")
SlashCmdList.PASTIME("mp")

-- Wettrennen: beide spielen gleichzeitig dasselbe Blatt und melden ein Ergebnis
do
    MP._Reset(); flush(); SENT = {}
    ns.ShowFrame("mp")
    local r1, r2, same, inRange = ns.RNG(77), ns.RNG(77), true, true
    for _ = 1, 50 do local x, y = r1(52), r2(52); same = same and x == y; inRange = inRange and x >= 1 and x <= 52 end
    local d1, d2 = ns.Cards.Shuffle(ns.Cards.NewDeck(), ns.RNG(5)), ns.Cards.Shuffle(ns.Cards.NewDeck(), ns.RNG(5))
    for i = 1, 52 do same = same and d1[i].rank == d2[i].rank and d1[i].suit == d2[i].suit end
    check(same and inRange, "derselbe Startwert gibt auf beiden Seiten dieselbe Zufallsfolge und dasselbe Blatt")

    -- Blackjack-Duell: ich bin zuerst fertig
    local gold, jackpot = PastimeDB.blackjack.gold, PastimeDB.jackpot
    MP.Invite(JAINA); local sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0)
    MP.Choose("blackjack")
    local s, g = MP.session, ns.run.game
    check(ns.run.def.id == "blackjack" and ns.run.mode == "mp" and g.mp == s and g.gold == 1000 and g.left == 5 and not g.cashBtn:IsShown()
        and g.sub.text == (ns.L["Duel: round %d of %d – the most gold wins."]):format(1, 5),
        "Blackjack-Duell: eigenes Gold für diese Partie, fünf Runden, kein „Kasse machen“")
    for _ = 1, 5 do
        g:Play()
        if g.state == "play" then g:Stand() end
        for _ = 1, 40 do if g.state == "dealer" then g:Update(0.6) end end
        g:NextHand()
    end
    check(ns.run.state == "over" and s.state == "playing" and s.board.score[s.me] == g.gold and sent(("PT1^MOVE^%s^1^%d"):format(sid, g.gold))
        and ns.overlay.text.text:find((ns.L["Your result: %d. Waiting for %s …"]):format(g.gold, JAINA), 1, true),
        "nach fünf Runden geht mein Goldstand an die Mitspielerin; das Brett wartet auf ihren")
    check(PastimeDB.blackjack.gold == gold and PastimeDB.jackpot == jackpot and PastimeDB.mp.paused[JAINA] == nil,
        "das Duell rührt weder mein Goblingold noch den Jackpot an und hat keine Mitschrift")
    ns.Restart()
    check(s.state == "playing", "solange sie noch spielt, gibt der Knopf nicht versehentlich auf")
    ns.ShowView("mp")
    check(v.text.text == (ns.L["Your result: %d. Waiting for %s …"]):format(g.gold, JAINA) and not btn(ns.L["Show the board"]), "auch der Reiter sagt, dass mein Ergebnis steht")
    ns.ShowView("game")
    from(JAINA, "MOVE", sid, 1, math.max(0, g.gold - 10))
    check(s.state == "over" and s.result == 2 and ns.overlay.title.text == ns.L["Victory!"]
        and ns.overlay.text.text:find((ns.L["You: %d · %s: %d"]):format(g.gold, JAINA, math.max(0, g.gold - 10)), 1, true)
        and ns.overlay.text.text:find(ns.L["Rematch? Both of you have to agree."], 1, true),
        "kommt ihr Ergebnis, steht der Sieger fest – mit beiden Ergebnissen und der Revanche-Frage")

    -- Revanche, diesmal wählt sie: Höher oder Tiefer, und sie ist zuerst fertig
    MP.Again(); from(JAINA, "AGAIN", sid)
    from(JAINA, "START", sid, "higherlower", 4711, 1, 1, 0)
    g = ns.run and ns.run.game
    check(ns.run and ns.run.def.id == "higherlower" and g.mp == s and g.gold == 1000 and ns.gameView:IsShown(), "ihre Spielwahl öffnet bei mir das Brett für Höher oder Tiefer")
    from(JAINA, "MOVE", sid, 1, 5000)
    check(s.state == "playing" and ns.run.state == "running", "ihr Ergebnis liegt schon vor, ich spiele weiter")
    for _ = 1, 5 do
        g:Play()
        if g.state == "guess" then g:Guess(ns.gamesById.higherlower.Create and g.card.rank ~= 1 and g.card.rank < 8) end
        if g.state == "guess" then g:Take() end
        g:Next()
    end
    check(s.state == "over" and s.result == (g.gold > 5000 and 2 or 0) and ns.overlay.title.text == (g.gold > 5000 and ns.L["Victory!"] or ns.L["Defeat"])
        and (PastimeDB.purses.higherlower == nil or PastimeDB.purses.higherlower.gold ~= g.gold or g.gold == 1000),
        "bin ich fertig, steht das Ergebnis sofort fest")
    MP.Pause(); ns.ShowLauncher()

    -- Solitär: fünf Minuten, gezählt werden die abgelegten Karten
    MP.Invite(JAINA); sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0); MP.Choose("solitaer")
    s, g = MP.session, ns.run.game
    check(ns.run.def.id == "solitaer" and g.started and g:Info()[1][2] == "5:00", "Solitär-Wettrennen: die Uhr läuft von fünf Minuten herunter")
    from(JAINA, "PAUSE", sid)
    check(MP.session == nil and ns.run.state == "over" and ns.overlay.title.text == ns.L["Interrupted"], "hält sie an, endet das Wettrennen als unterbrochen")
    ns.ShowLauncher()
    MP.Invite(JAINA); sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0); MP.Choose("solitaer")
    s, g = MP.session, ns.run.game
    g.time = 299; g:Update(2)
    check(ns.run.state == "over" and s.board.score[s.me] == g:Placed() * 100 and ns.overlay.title.text == ns.L["Time is up"], "nach fünf Minuten ist Schluss: 100 Punkte je abgelegter Karte")
    from(JAINA, "MOVE", sid, 1, g:Placed() * 100)
    check(s.state == "over" and s.result == 1 and ns.overlay.title.text == ns.L["Draw"], "gleiches Ergebnis: unentschieden")
    MP.Pause(); ns.ShowLauncher()
end

-- Runenpaare-Duell: ein gemeinsames Brett, wer ein Paar findet, ist noch einmal dran
do
    MP._Reset(); flush(); SENT = {}
    MP.Invite(JAINA); local sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0); MP.Choose("runepairs")
    local s, g = MP.session, ns.run.game
    local function free() for j, c in ipairs(g.cards) do if not c.done then return j end end end
    local function mate(i) for j, c in ipairs(g.cards) do if j ~= i and c.icon == g.cards[i].icon then return j end end end
    local function other(i) for j, c in ipairs(g.cards) do if not c.done and j ~= i and c.icon ~= g.cards[i].icon then return j end end end
    local function she(i) from(JAINA, "MOVE", sid, #s.moves + 1, i) end
    check(#g.cards == 30 and g.cards == s.board.cards and g:Info()[1][1] == ns.L["Your pairs"], "Duell: 30 Karten auf einem gemeinsamen Brett")
    if s.turn ~= s.me then local a = free(); she(a); she(other(a)) end
    check(s.turn == s.me, "nach ihrem Fehlgriff bin ich dran")
    local a = free()
    g:Flip(a)
    check(s.board.open == a and s.turn == s.me and g.cards[a].up, "meine erste Karte liegt offen, ich decke noch eine auf")
    g:Flip(mate(a))
    check(s.board.pairs[s.me] == 1 and s.turn == s.me and g.cards[a].done, "ein Paar: es gehört mir und ich bin noch einmal dran")
    a = free(); local b = other(a)
    g:Flip(a); g:Flip(b)
    check(s.turn ~= s.me and g.lockT ~= nil and g.cards[a].up and g.cards[b].up, "kein Paar: beide Karten bleiben kurz offen, dann ist sie dran")
    local n = #s.moves
    g:Flip(free())
    check(#s.moves == n, "solange sie dran ist, deckt mein Klick nichts auf")
    g:Update(2)
    check(not g.cards[a].up and not g.cards[b].up, "danach liegen die beiden wieder verdeckt")
    she(a); she(a)
    check(s.board.open == a and #s.moves == n + 1, "dieselbe Karte zweimal ist kein Zug")
    she(mate(a))
    while s.state == "playing" do a = free(); she(a); she(mate(a)) end
    check(s.state == "over" and s.result == 0 and s.board.pairs[3 - s.me] == 14 and ns.overlay.title.text == ns.L["Defeat"]
        and ns.overlay.text.text:find((ns.L["You found %d pairs, %s found %d."]):format(1, JAINA, 14), 1, true),
        "sind alle Paare gefunden, gewinnt, wer mehr hat")
    MP.Pause(); ns.ShowLauncher()
    PastimeDB.mp.stats = {}
end

-- Mau-Mau: nur im Mehrspieler, mit 0 bis 2 Bots
do
    local function card(rank, suit) local k = ({ [7] = 1, [8] = 2, [9] = 3, [10] = 4, [11] = 5, [12] = 6, [13] = 7, [1] = 8 })[rank]; return { rank = rank, suit = suit, id = (suit - 1) * 8 + k } end
    local function total(st) local n = 1 + #st.pile + #st.discard; for _, h in ipairs(st.hands) do n = n + #h end; return n end
    -- ganze Partien mit zufälligen erlaubten Zügen: sie enden, keine Karte geht verloren, und es ist auf beiden Seiten dasselbe
    local function playOut(id, seed)
        local G, rnd = MP.games[id], ns.RNG(seed + 99)
        local st, turn, res, steps, whole = G.New(seed), 1 + seed % 2, nil, 0, true
        while res == nil and steps < 3000 do
            steps = steps + 1
            local moves = {}
            for _, c in ipairs(st.hands[st.human[turn]]) do
                for w = 0, 4 do if G.Legal(st, turn, w * 100 + c.id) then moves[#moves + 1] = w * 100 + c.id end end
            end
            if #moves == 0 or rnd(4) == 1 then
                for _, v in ipairs({ 0, -1 }) do if G.Legal(st, turn, v) then moves[#moves + 1] = v end end
            end
            if #moves == 0 then return nil end
            local nextSeat
            res, nextSeat = G.Apply(st, turn, moves[rnd(#moves)])
            turn = nextSeat or (3 - turn)
            whole = whole and total(st) == 32
        end
        return res, steps, whole, st.top.id
    end
    local ended, whole, same = true, true, true
    for _, id in ipairs({ "maumau", "maumau3", "maumau4" }) do
        for seed = 1, 25 do
            local res, steps, ok, top = playOut(id, seed)
            local res2, steps2, _, top2 = playOut(id, seed)
            ended = ended and (res == 0 or res == 1 or res == 2)
            whole = whole and ok == true
            same = same and res == res2 and steps == steps2 and top == top2
        end
    end
    check(ended, "Mau-Mau: jede Partie endet mit einem Sieger oder unentschieden, mit 0, 1 und 2 Bots")
    check(whole, "dabei bleiben es immer 32 Karten")
    check(same, "derselbe Startwert und dieselben Züge geben auf beiden Seiten dieselbe Partie")

    local G = MP.games.maumau
    local st = G.New(1)
    st.hands[1], st.hands[2], st.top, st.suit = { card(7, 1), card(11, 3), card(9, 4) }, { card(13, 2), card(10, 1) }, card(9, 1), 1
    check(not G.Legal(st, 1, 21) and G.Legal(st, 1, 321) and G.Legal(st, 1, 27) and not G.Legal(st, 2, 0) and not G.Legal(st, 1, -1) and not G.Legal(st, 1, 15),
        "legen darf, wer dran ist: was in Farbe oder Wert passt; der Bube nur mit Wunsch; passen erst nach dem Ziehen")
    local res, nextSeat = G.Apply(st, 1, 1)
    check(res == nil and nextSeat == 2 and st.pend == 2 and not G.Legal(st, 2, 12) and not G.Legal(st, 2, -1), "nach einer 7 hilft nur eine 7 – oder ziehen")
    res, nextSeat = G.Apply(st, 2, 0)
    check(nextSeat == 1 and #st.hands[2] == 4 and st.pend == 0, "wer keine 7 hat, zieht zwei und ist damit fertig")
    res, nextSeat = G.Apply(st, 1, 221)
    check(st.suit == 2 and st.top.rank == 11 and nextSeat == 2, "der Bube wünscht eine Farbe")
    st.hands[2] = { card(10, 2), card(11, 1), card(8, 3) }
    check(G.Legal(st, 2, 12) and not G.Legal(st, 2, 105) and not G.Legal(st, 2, 18), "danach passt nur die gewünschte Farbe, kein zweiter Bube")
    G.Apply(st, 2, 12)
    st.hands[1] = { card(8, 2), card(9, 2) }
    res, nextSeat = G.Apply(st, 1, 10)
    check(res == nil and nextSeat == 1, "zu zweit heißt eine 8: gleich noch einmal")
    res = G.Apply(st, 1, 11)
    check(res == 1 and st.winner == 1, "wer die letzte Karte legt, gewinnt")
    st = G.New(2); st.cur = 1
    local before = #st.hands[1]
    res, nextSeat = G.Apply(st, 1, 0)
    check(nextSeat == 1 and #st.hands[1] == before + 1 and st.drew and G.Legal(st, 1, -1) and not G.Legal(st, 1, 0), "ziehen: eine Karte, danach legen oder passen")

    -- mit einem Bot: er antwortet auf die 7, und geht er zuerst aus, gewinnt, wer weniger Karten hat
    G = MP.games.maumau3
    st = G.New(3)
    st.hands[1], st.hands[2], st.top, st.suit = { card(7, 1), card(9, 1) }, { card(7, 3), card(13, 4) }, card(9, 1), 1
    res, nextSeat = G.Apply(st, 1, 1)
    check(res == nil and nextSeat == 2 and st.pend == 4 and #st.hands[2] == 1 and st.cur == 3 and st.events[2].kind == "play" and st.events[2].pos == 2,
        "der Bot legt seine 7 drauf: die zweite Spielerin müsste vier ziehen")
    st = G.New(3)
    st.hands[1], st.hands[2], st.top, st.suit = { card(12, 1), card(9, 1) }, { card(10, 1) }, card(9, 1), 1
    res = G.Apply(st, 1, 6)
    check(res == 1 and st.winner == 2 and #st.hands[1] == 1 and #st.hands[3] == 5, "geht ein Bot zuerst aus, gewinnt von beiden, wer weniger Karten hat")

    -- am Brett
    MP._Reset(); flush(); SENT = {}
    ns.ShowFrame("mp")
    MP.Invite(JAINA); local sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0)
    check(btn(ns.L["Mau-Mau"]) and btn(ns.L["Mau-Mau with 1 bot"]) and btn(ns.L["Mau-Mau with 2 bots"]), "die Spielwahl bietet Mau-Mau mit 0, 1 und 2 Bots")
    local last = PastimeDB.lastGame
    click(btn(ns.L["Mau-Mau with 2 bots"]))
    local s, g = MP.session, ns.run and ns.run.game
    check(s.game == "maumau4" and ns.run.def.id == "maumau" and ns.run.mode == "mp" and g.mp == s and ns.gameView:IsShown() and s.board.n == 4, "gewählt: das Mau-Mau-Brett öffnet sich, vier am Tisch")
    check(#ns.games == 24 and ns.gamesById.maumau.mpOnly and PastimeDB.lastGame == last, "Mau-Mau steht nicht in der Spielauswahl und wird nicht als letztes Spiel gemerkt")
    if s.turn ~= s.me then
        from(JAINA, "MOVE", sid, #s.moves + 1, 0)
        from(JAINA, "MOVE", sid, #s.moves + 1, -1)
    end
    local st2 = s.board
    local mine = st2.hands[st2.human[s.me]]
    check(s.turn == s.me and g.drawBtn.enabled and g:Info()[1][2] == tostring(#mine) and #g:Info() == 5, "ich bin dran; die Seitenleiste zählt die Karten aller vier und den Stapel")
    local n, cards = #s.moves, #mine
    if st2.pend > 0 then g:DrawOrPass() else g:DrawOrPass(); if s.turn == s.me and st2.drew then check(g.drawBtn.text == ns.L["Pass (Space)"], "nach dem Ziehen heißt der Knopf „Passen“"); g:DrawOrPass() end end
    check(#s.moves > n and #mine > cards and sent(("PT1^MOVE^%s^%d^0"):format(sid, n + 1)), "Ziehen geht als Zug an die Mitspielerin")
    local shown = 0
    for _, f in ipairs(g.hand) do if f:IsShown() then shown = shown + 1 end end
    check(shown == #mine and g.top.card == st2.top, "die Hand zeigt genau meine Karten, in der Mitte liegt die oberste")
    ns.ShowRules()
    check(ns.overlay.text.text:find(ns.HELP.maumau, 1, true), "das Regel-Fenster erklärt Mau-Mau")
    ns.Resume()
    MP.GiveUp()
    check(s.state == "over" and ns.run.state == "over" and ns.overlay.title.text == ns.L["Defeat"], "Aufgeben beendet auch Mau-Mau")
    MP.Pause(); ns.ShowLauncher()
    PastimeDB.mp.stats = {}
end

-- Poker zu zweit: Goblin-Poker (tauschen, eine Setzrunde) und Tavernen-Hold'em
do
    local FOLD, CALL, RAISE, DEAL, SWAP = 1, 2, 3, 4, 100
    -- ganze Partien mit zufälligen erlaubten Zügen: sie enden, das Gold bleibt zusammen 2000, beide Seiten sehen dasselbe
    local function playOut(id, seed)
        local G, rnd = MP.games[id], ns.RNG(seed + 7)
        local turn = 1 + seed % 2
        local st, res, steps, whole = G.New(seed, turn), nil, 0, true
        while res == nil and steps < 2000 do
            steps = steps + 1
            local moves = {}
            for _, v in ipairs({ FOLD, CALL, CALL, CALL, RAISE, RAISE, DEAL, SWAP + rnd(32) - 1 }) do
                if G.Legal(st, turn, v) then moves[#moves + 1] = v end
            end
            if #moves == 0 or G.Legal(st, 3 - turn, CALL) then return nil end
            local nextSeat
            res, nextSeat = G.Apply(st, turn, moves[rnd(#moves)])
            turn = nextSeat or (3 - turn)
            whole = whole and st.chips[1] + st.chips[2] == 2000 and st.chips[1] >= 0 and st.chips[2] >= 0
        end
        return res, steps, whole, st.chips[1], st.hand
    end
    local ended, whole, same, hands = true, true, true, true
    for _, id in ipairs({ "drawpoker", "holdem" }) do
        for seed = 1, 40 do
            local res, steps, ok, chips, hand = playOut(id, seed)
            local res2, steps2, _, chips2 = playOut(id, seed)
            ended = ended and (res == 0 or res == 1 or res == 2) and res == (chips == 1000 and 0 or (chips > 1000 and 1 or 2))
            whole = whole and ok == true
            same = same and res == res2 and steps == steps2 and chips == chips2
            hands = hands and hand ~= nil and hand <= (id == "holdem" and 10 or 5)
        end
    end
    check(ended, "Poker zu zweit: jede Partie endet, und es gewinnt, wer mehr Gold hat")
    check(whole, "das Gold der beiden bleibt zusammen immer 2000, keiner fällt unter null")
    check(same and hands, "derselbe Startwert gibt dieselbe Partie; Goblin-Poker geht über höchstens fünf, Hold'em über höchstens zehn Blätter")

    -- Goblin-Poker: Grundeinsatz, tauschen, eine Setzrunde
    local G = MP.games.drawpoker
    local st = G.New(11, 1)
    check(st.phase == "swap" and st.dealer == 2 and st.put[1] == 20 and st.put[2] == 20 and #st.cards[1] == 5 and G.Legal(st, 1, SWAP) and not G.Legal(st, 1, CALL) and not G.Legal(st, 2, SWAP),
        "Goblin-Poker: beide zahlen 20, zuerst tauscht, wer nicht gibt")
    local a, b, c = st.cards[1][1], st.cards[1][2], st.cards[1][3]
    local res, nextSeat = G.Apply(st, 1, SWAP + 3)
    check(st.cards[1][1] ~= a and st.cards[1][2] ~= b and st.cards[1][3] == c and st.swapN[1] == 2 and nextSeat == 2, "getauscht werden genau die markierten Karten")
    res, nextSeat = G.Apply(st, 2, SWAP)
    check(st.phase == "bet" and nextSeat == 1 and G.Legal(st, 1, RAISE), "nach dem Tauschen wird gesetzt")
    G.Apply(st, 1, RAISE); G.Apply(st, 2, RAISE); G.Apply(st, 1, RAISE)
    check(st.put[1] == 140 and st.put[2] == 100 and not G.Legal(st, 2, RAISE) and G.Legal(st, 2, CALL), "höchstens drei Erhöhungen je Runde")
    res, nextSeat = G.Apply(st, 2, CALL)
    local w = st.last.winner
    check(res == nil and st.phase == "done" and st.last.why == "show" and st.chips[1] == (w == 1 and 1140 or (w == 2 and 860 or 1000)) and nextSeat == 1 and G.Legal(st, 1, DEAL) and not G.Legal(st, 1, CALL),
        "mitgehen führt zum Aufdecken: das bessere Blatt gewinnt, was beide gesetzt haben; dann gibt der nächste Geber")
    res, nextSeat = G.Apply(st, 1, DEAL)
    check(st.hand == 2 and st.dealer == 1 and nextSeat == 2 and st.phase == "swap", "das nächste Blatt: der Geber wechselt")
    local before = st.chips[2]
    G.Apply(st, 2, SWAP); G.Apply(st, 1, SWAP)
    G.Apply(st, 2, RAISE)
    G.Apply(st, 1, FOLD)
    check(st.chips[2] == before + 20 and st.last.why == "fold" and st.last.winner == 2, "wer aussteigt, verliert nur, was er schon gesetzt hat")

    -- Hold'em: Blinds, vier Setzrunden, fünf gemeinsame Karten
    G = MP.games.holdem
    st = G.New(5, 1)
    check(st.dealer == 1 and st.put[1] == 10 and st.put[2] == 20 and #st.cards[1] == 2 and #st.board == 0 and st.toAct == 1, "Hold'em: der Geber zahlt 10, der andere 20, und der Geber beginnt")
    res, nextSeat = G.Apply(st, 1, CALL)
    check(nextSeat == 2 and st.round == 1, "nach dem Mitgehen darf der andere noch erhöhen")
    res, nextSeat = G.Apply(st, 2, CALL)
    check(st.round == 2 and #st.board == 3 and nextSeat == 2, "danach liegen drei gemeinsame Karten, und es beginnt, wer nicht gibt")
    G.Apply(st, 2, CALL); G.Apply(st, 1, CALL)
    G.Apply(st, 2, RAISE)
    check(#st.board == 4 and st.put[2] == 60, "in den späten Runden wird um 40 erhöht")
    G.Apply(st, 1, CALL); G.Apply(st, 2, CALL)
    res = G.Apply(st, 1, CALL)
    check(st.phase == "done" and #st.board == 5 and st.last.why == "show" and st.chips[1] + st.chips[2] == 2000 and math.abs(st.chips[1] - 1000) % 60 == 0, "nach der letzten Runde wird aufgedeckt")
    -- wer nicht mehr mithalten kann, setzt alles; der Rest wird ohne Setzen ausgeteilt
    st = G.New(6, 1)
    st.chips = { 30, 1970 }
    G.Apply(st, 1, RAISE)
    res = G.Apply(st, 2, CALL)
    check(st.phase == "done" and #st.board == 5 and st.chips[1] + st.chips[2] == 2000 and (st.chips[1] == 60 or st.chips[1] == 30 or (st.chips[1] == 0 and res == 2)),
        "alles gesetzt: es geht um höchstens das, was der Ärmere hat, und wer leer ausgeht, hat verloren")

    -- am Brett
    MP._Reset(); flush(); SENT = {}
    ns.ShowFrame("mp")
    MP.Invite(JAINA); local sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0)
    check(btn(ns.gamesById.drawpoker.name) and btn(ns.gamesById.holdem.name), "die Spielwahl bietet Goblin-Poker und Tavernen-Hold'em")
    click(btn(ns.gamesById.drawpoker.name))
    local s, g = MP.session, ns.run and ns.run.game
    st = s.board
    check(s.game == "drawpoker" and ns.run.def.id == "pokerduel" and g.mp == s and g.myCards[5]:IsShown() and g.myCards[1].face:IsShown()
        and g.oppCards[1].back:IsShown() and not g.boardCards[1]:IsShown(), "Goblin-Poker zu zweit: meine fünf Karten offen, ihre verdeckt")
    if s.turn ~= s.me then from(JAINA, "MOVE", sid, #s.moves + 1, SWAP) end
    g:Click(2)
    check(g.mark[2] and g.btn[2].text == (ns.L["Swap %d (Space)"]):format(1) and g.myCards[2].sel:IsShown(), "eine angeklickte Karte ist zum Tauschen markiert")
    local old = st.cards[s.me][2]
    g:Main()
    check(st.cards[s.me][2] ~= old and sent(("PT1^MOVE^%s^%d^%d"):format(sid, #s.moves, SWAP + 2)), "die Leertaste tauscht sie; der Zug geht an die Mitspielerin")
    while s.state == "playing" and st.phase ~= "done" do
        if s.turn == s.me then g:Main() else from(JAINA, "MOVE", sid, #s.moves + 1, st.phase == "swap" and SWAP or CALL) end
    end
    check(st.last and st.last.why == "show" and g.oppCards[1].face:IsShown() and g.log.text ~= "" and g.btn[2].text == ns.L["Next hand (Space)"], "nach dem Aufdecken liegen ihre Karten offen, und das Ergebnis steht da")
    ns.ShowRules()
    check(ns.overlay.text.text:find(ns.HELP_MP.drawpoker, 1, true) and not ns.overlay.text.text:find(ns.L["For two"], 1, true), "das Regel-Fenster erklärt Goblin-Poker zu zweit")
    ns.Resume()
    if s.turn == s.me then g:Main() else from(JAINA, "MOVE", sid, #s.moves + 1, DEAL) end
    check(st.hand == 2 and g:Info()[1][2] == "2/5", "das nächste Blatt ist gegeben")
    MP.GiveUp()
    check(s.state == "over" and ns.overlay.title.text == ns.L["Defeat"], "Aufgeben beendet auch die Pokerpartie")
    MP.Pause(); ns.ShowLauncher()
    -- Regel-Fenster im Wettrennen: das Spiel selbst, darunter „Zu zweit“
    MP.Invite(JAINA); sid = MP.session.id
    from(JAINA, "ACCEPT", sid, 0); MP.Choose("blackjack")
    ns.ShowRules()
    check(ns.overlay.text.text:find(ns.L["For two"], 1, true) and ns.overlay.text.text:find(ns.HELP_MP.blackjack, 1, true), "im Wettrennen steht unter den Regeln ein Abschnitt „Zu zweit“")
    ns.Resume()
    MP.GiveUp(); MP.Pause(); ns.ShowLauncher()
    PastimeDB.mp.stats = {}
end

local errs = {}
for _, e in ipairs(PastimeDB.log) do if e.l == "E" then table.insert(errs, e.c .. ": " .. e.m) end end
check(#errs == 0, "keine Fehler im Protokoll:\n  " .. table.concat(errs, "\n  "))
check(#ERRORS_FORWARDED == 0, "keine Fehler an BugSack: " .. table.concat(ERRORS_FORWARDED, " | "))
print(("Mehrspieler-Tests: %d ok, %d Fehler"):format(passes, fails))
