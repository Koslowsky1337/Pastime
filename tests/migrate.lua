-- Gespeicherte Daten älterer Versionen: Flugzeiten aus 0.1.0, fehlende Felder, Einstellungen
-- Aufruf: python3 tests/run.py . tests/migrate.lua
local ns = KW
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end

PastimeDB = PastimeDB or {}
PastimeDB.flights = { ["Crossroads, Brachland > Orgrimmar, Durotar"] = { t = 118, d = "08.11.26" } }
PastimeDB.settings = { autoOpen = false }      -- Gespeichertes bleibt, Fehlendes wird ergänzt
-- Stand beta2: alte Spiel-IDs in Bestenlisten, Streckenrekorden, Statistik und Auswahl
PastimeDB.scores = { tetris = { { s = 900, p = "Thokk" } }, ["viergewinnt:schwer"] = { { s = 3, p = "Thokk" } },
    kobold = { { s = 7, p = "Thokk" } } }
PastimeDB.routes = { ["flug:A > B"] = { kind = "flug", from = "A", to = "B", n = 1, scores = { ["memory:mittel"] = { { s = 40, p = "Thokk" } } } } }
PastimeDB.stats = { games = { kniffel = { n = 4, t = 600 } } }
PastimeDB.modes = { viergewinnt = "schwer" }
PastimeDB.lastGame = "simon"
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")

local r = PastimeDB.routes["flug:Crossroads, Brachland > Orgrimmar, Durotar"]
check(r and r.t == 118 and r.last == "08.11.26" and r.kind == "flug", "alte Flugzeiten werden zu Strecken")
check(PastimeDB.flights == nil, "die alte Liste ist danach weg")
check(PastimeDB.settings.autoOpen == false and PastimeDB.settings.landAlarm == true and PastimeDB.settings.sound == true,
    "Einstellungen: Gespeichertes bleibt, Fehlendes wird ergänzt")
check(PastimeDB.logSession == 1 and PastimeDB.blackjack.gold == 100 and type(PastimeDB.scores) == "table",
    "Sitzungszähler und neue Felder sind angelegt")
local S = PastimeDB.scores
check(S.rockfall and S.rockfall[1].s == 900 and S.tetris == nil and S["fourinarow:schwer"] and S["viergewinnt:schwer"] == nil
    and S.kobold[1].s == 7, "Bestenlisten ziehen auf die neuen Spiel-IDs um")
check(PastimeDB.routes["flug:A > B"].scores["runepairs:mittel"][1].s == 40 and PastimeDB.routes["flug:A > B"].scores["memory:mittel"] == nil,
    "Streckenrekorde ziehen um")
check(PastimeDB.stats.games.taverndice.n == 4 and PastimeDB.stats.games.kniffel == nil and PastimeDB.modes.fourinarow == "schwer"
    and PastimeDB.lastGame == "totemecho", "Statistik, Schwierigkeit und letztes Spiel ziehen um")
check(ns.RouteLabel({ from = "Zoram'gar-Außenposten, Ashenvale", to = "Orgrimmar, Durotar" }, 14) == "Zoram'gar-Auße… → Orgrimmar"
    and ns.RouteLabel({ from = "Zoram'gar-Außenposten, Ashenvale", to = "Orgrimmar" }) == "Zoram'gar-Außenposten → Orgrimmar",
    "lange Ortsnamen werden nur auf Wunsch gekürzt: " .. ns.RouteLabel({ from = "Zoram'gar-Außenposten, Ashenvale", to = "Orgrimmar" }, 14))
SlashCmdList.PASTIME("")
check(ns.frame:IsShown() and #ERRORS_FORWARDED == 0, "Fenster öffnet sich ohne Fehler")
print(("Migrations-Tests: %d ok, %d Fehler"):format(passes, fails))
