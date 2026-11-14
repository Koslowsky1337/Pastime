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
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")

local r = PastimeDB.routes["flug:Crossroads, Brachland > Orgrimmar, Durotar"]
check(r and r.t == 118 and r.last == "08.11.26" and r.kind == "flug", "alte Flugzeiten werden zu Strecken")
check(PastimeDB.flights == nil, "die alte Liste ist danach weg")
check(PastimeDB.settings.autoOpen == false and PastimeDB.settings.landAlarm == true and PastimeDB.settings.sound == true,
    "Einstellungen: Gespeichertes bleibt, Fehlendes wird ergänzt")
check(PastimeDB.logSession == 1 and PastimeDB.blackjack.gold == 100 and type(PastimeDB.scores) == "table",
    "Sitzungszähler und neue Felder sind angelegt")
SlashCmdList.PASTIME("")
check(ns.frame:IsShown() and #ERRORS_FORWARDED == 0, "Fenster öffnet sich ohne Fehler")
print(("Migrations-Tests: %d ok, %d Fehler"):format(passes, fails))
