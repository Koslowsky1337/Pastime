-- Pastime: Debug – Messwerte-Fenster (/pastime debug) und Diagnosebericht (/pastime diag)
--
-- Was zum Auslesen in PastimeDB landet (geschrieben bei /reload oder Logout):
--   log     – Protokoll (E/W/I immer, D nur mit Debug),
--             Fehler mit Stacktrace (Feld st)
--   traces  – Reise-Mitschnitte: bei Warten/Abfahrt/Ankunft/Abbruch die
--             Messpunkte seit dem letzten Ereignis (siehe Transport.lua)
--   routes, scores, stats, settings
local ADDON, ns = ...
local L = ns.L

local function yesno(v)
    if v == nil then return "?" end
    return v and "yes" or "no"
end

local function plain(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function onTaxi()
    if not UnitOnTaxi then return nil end
    local ok, v = ns.Try("UnitOnTaxi", UnitOnTaxi, "player")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(v)) then return nil end
    return v and true or false
end

-- Aktuelle Messwerte als Zeilen
function ns.DebugLines()
    local lines = {}
    local function add(fmt, ...) table.insert(lines, select("#", ...) > 0 and fmt:format(...) or fmt) end
    local H = "|cffffd100"
    local t = ns.trip
    if t.active then
        local K = ns.KINDS[t.kind] or ns.KINDS.flug
        local since = t.phase == "ride" and t.start or t.waitStart
        add("%sTrip:|r %s · %s · %s » %s · %s%s", H, K.one, t.phase == "wait" and "waiting" or "travelling",
            ns.ShortName(t.from) or "?", ns.ShortName(t.to) or "?", ns.FormatTime(GetTime() - (since or GetTime())),
            t.expected and (" / expected " .. ns.FormatTime(t.expected)) or "")
        add("%sTrip ID:|r %d · played: %s · auto-opened: %s · pending: %d", H, t.id, yesno(t.played),
            yesno(t.autoOpened), #(t.pending or {}))
    else
        add("%sTrip:|r none", H)
    end
    add("%sTaxi (UnitOnTaxi):|r %s", H, yesno(onTaxi()))
    local LV = ns.transportState and ns.transportState.live
    if not LV then
        add("%sDocks:|r no measurement yet", H)
    elseif LV.note then
        add("%sDocks:|r %s", H, LV.note)
    else
        add("%sPosition:|r map %s  %.2f / %.2f  (continent %s)", H, tostring(LV.map), (LV.mx or 0) * 100,
            (LV.my or 0) * 100, tostring(LV.c))
        add("%sMoving:|r %.1f m/s · own speed %s · walking: %s · carried: %s (%d/4)", H, LV.v or 0,
            LV.speed and ("%.1f"):format(LV.speed) or "?", yesno(LV.moving), yesno(LV.carried), LV.nc or 0)
        if LV.dock then
            add("%sDock:|r %s » %s · %d m", H, LV.dock.name, LV.dock.to, math.floor((LV.dd or 0) + 0.5))
        else
            add("%sDock:|r none on this continent", H)
        end
        if (LV.still or 0) > 0 then add("%sStill at destination for:|r %.1f s", H, LV.still) end
        if LV.suppress then add("%sWaiting blocked|r until you leave %s", H, LV.suppress) end
    end
    local run = ns.run
    if run then
        add("%sRound:|r %s%s · %s · trip ID %s%s", H, run.def.name, run.mode and (" (" .. run.mode .. ")") or "",
            run.state, tostring(run.tripId or "-"), run.landed and " · arrival dialog" or "")
    else
        add("%sRound:|r none", H)
    end
    add("%sKeyboard:|r %s · combat: %s · window open: %s", H, yesno(ns.gameView and ns.gameView.kbOn),
        yesno(InCombatLockdown()), yesno(ns.frame and ns.frame:IsShown()))
    add("%sErrors (session):|r %d · traces: %d · routes: %d", H, ns.SessionErrors(),
        #(ns.DB.traces or {}), ns.CountRoutes())
    return lines
end

---------------------------------------------------------------------------
-- Messwerte-Fenster
---------------------------------------------------------------------------
local function SavePos(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    ns.DB.debugPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CreatePanel()
    local f = ns.AutoWrap(CreateFrame("Frame", "PastimeDebugFrame", UIParent, "BackdropTemplate"), "debug")
    f:SetBackdrop(ns.TOOLTIP_BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.82)
    f:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    f:SetSize(360, 196)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self) end)
    local pos = ns.DB.debugPos
    if type(pos) == "table" and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("TOPLEFT", 30, -220)
    end
    local title = ns.FontString(f, "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Pastime Debug")
    local hint = ns.FontString(f, "GameFontDisableSmall", "RIGHT")
    hint:SetPoint("TOPRIGHT", -30, -11)
    hint:SetText("/pastime diag · /pastime log")
    local close = ns.CreateCloseButton(f, function()
        ns.DB.debug = false
        ns.Log("I", "debug", "Debug off (window closed)")
        ns.Print(L["Debug |cffff6060off|r."])
        ns.UpdateDebugPanel()
    end)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    f.text = ns.FontString(f, "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 10, -28)
    f.text:SetWidth(340)
    f.text:SetSpacing(2)
    local acc, layoutN = 1, 0
    f:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        if acc < 0.5 then return end
        acc = 0
        local ok, lines = pcall(ns.DebugLines)
        -- Layout-Prüfung läuft mit: alles, was man durchklickt, wird geprüft (neue Funde ins Protokoll)
        local okL, found = ns.Try("LayoutCheck", ns.LayoutCheck)
        if okL then layoutN = #found end
        self.text:SetText((ok and table.concat(lines, "\n") or ("Errors: " .. tostring(lines)))
            .. ("\nLayout: %d problem(s) on screen · /pastime log"):format(layoutN))
        local h = self.text:GetStringHeight()
        if h then self:SetHeight(h + 40) end
    end)
    return f
end

function ns.UpdateDebugPanel()
    if not ns.DB then return end
    if ns.DB.debug then
        ns.debugPanel = ns.debugPanel or CreatePanel()
        ns.debugPanel:Show()
    elseif ns.debugPanel then
        ns.debugPanel:Hide()
    end
end

---------------------------------------------------------------------------
-- Diagnosebericht (/pastime diag) – zum Kopieren und Einfügen
---------------------------------------------------------------------------
local OTHER_ADDONS = { "TomTom", "Questie", "QuestieDB", "ForeverDungeonJournal", "Leatrix_Maps" }

local function addonLoaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not fn then return "?" end
    local ok, v = ns.Try("IsAddOnLoaded", fn, name)
    return ok and (v and "yes" or "no") or "?"
end

function ns.DiagReport()
    local out = {}
    local function add(fmt, ...) table.insert(out, select("#", ...) > 0 and fmt:format(...) or fmt) end
    local build, num = "?", "?"
    if GetBuildInfo then build, num = GetBuildInfo() end
    add("Pastime %s · Client %s (%s) · %s · %s · %s", ns.VERSION, tostring(build), tostring(num),
        GetLocale and GetLocale() or "?", ns.IsAlliance() and "Alliance" or "Horde", date("%Y-%m-%d %H:%M:%S"))
    local set = ns.DB.settings
    add("Session %s · debug %s · auto=%s alarm=%s combat=%s sound=%s", tostring(ns.session), yesno(ns.DB.debug),
        tostring(set.autoOpen), tostring(set.landAlarm), tostring(set.hideInCombat), tostring(set.sound))
    local addons = {}
    for _, a in ipairs(OTHER_ADDONS) do table.insert(addons, a .. "=" .. addonLoaded(a)) end
    add("Addons: %s", table.concat(addons, " "))
    local run = ns.run
    add("Game: %s", run and (run.def.id .. " " .. tostring(run.mode) .. " · " .. tostring(run.state)) or "-")
    add("")
    add("== Client calls that failed ==")
    local any = false
    for name, f in pairs(ns.fails) do
        any = true
        add("%s: %d× since %s · %s", name, f.n, f.first, f.err)
    end
    if not any then add("none") end
    add("")
    add("== Now ==")
    for _, l in ipairs(ns.DebugLines()) do add(plain(l)) end
    local have, total = 0, 0
    if ns.DockCount then have, total = ns.DockCount() end
    add("Docks computed: %d of %d", have, total)
    add("")
    add("== Routes (%d) ==", ns.CountRoutes())
    for key, r in pairs(ns.DB.routes) do
        local n = 0
        for _, list in pairs(r.scores or {}) do n = n + #list end
        add("%s · duration %s · %d× · %d entries", key, r.t and ns.FormatTime(r.t) or "?", r.n or 0, n)
    end
    add("")
    local traces = ns.DB.traces or {}
    add("== Trip traces (%d) ==", #traces)
    for i, tr in ipairs(traces) do
        add("[%d] %s %s · %s · %d points", i, tr.d or "?", tr.e or "?", tr.info or "", #(tr.s or {}))
    end
    local last = traces[#traces]
    if last and #(last.s or {}) > 0 then
        add("-- Points of the last trace (max. 40):")
        for i = math.max(1, #last.s - 39), #last.s do add(last.s[i]) end
    end
    if ns.TraceTail then
        local tail = ns.TraceTail(20)
        if #tail > 0 then
            add("-- Current samples:")
            for _, l in ipairs(tail) do add(l) end
        end
    end
    add("")
    add("== Log (this session and the one before, older errors and warnings; max. 120 lines) ==")
    add(ns.FormatLog(120, false, true, (ns.session or 1) - 1))
    return ns.Anonymize(table.concat(out, "\n"))
end

-- Charakternamen aus einem Text nehmen: jeder bekannte Name (eigene Charaktere, Namen in den
-- Bestenlisten und im Protokoll) wird zu „Char1“, „Char2“ …
function ns.Anonymize(text)
    local names, seen = {}, {}
    local function note(n)
        if type(n) == "string" and #n >= 2 and not seen[n] then seen[n] = true; names[#names + 1] = n end
    end
    note(ns.playerName)
    for n in pairs(ns.Comm and ns.Comm.selfNames or {}) do note(n) end      -- auch der volle Absendername
    for _, e in ipairs(ns.DB.log) do note(e.p) end
    local function lists(scores)
        for _, list in pairs(scores or {}) do
            for _, e in ipairs(list) do note(e.p) end
        end
    end
    lists(ns.DB.scores)
    for _, r in pairs(ns.DB.routes) do lists(r.scores) end
    table.sort(names, function(a, b) return #a > #b end)      -- lange zuerst: „Thokkar“ vor „Thokk“
    for i, n in ipairs(names) do
        text = text:gsub(n:gsub("%p", "%%%0"), "Char" .. i)
    end
    return text
end

function ns.ShowReport()
    ns.ShowCopy(L["Pastime bug report"], ns.DiagReport())
    ns.Print(L["Copy the report with Ctrl+C and paste it into an issue: github.com/Koslowsky1337/Pastime/issues"])
end

---------------------------------------------------------------------------
-- Selbsttest (/pastime debug test): prüft im laufenden Client, was die Tests ohne Spiel nicht
-- sehen – Schnittstellen, Klänge, Texturen, Addon-Nachrichten. Das Ergebnis öffnet sich zum
-- Kopieren. Bewusst englisch und ungeschönt: es ist für die Fehlersuche gedacht.
---------------------------------------------------------------------------
local NEEDED = { "C_Timer.After", "C_Timer.NewTicker", "PlaySound", "SOUNDKIT", "GetBuildInfo", "hooksecurefunc",
    "UnitOnTaxi", "TakeTaxiNode", "InCombatLockdown", "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.SendAddonMessage",
    "IsInGuild", "IsInGroup", "IsInRaid", "Settings.RegisterVerticalLayoutCategory", "Settings.RegisterProxySetting" }
local OPTIONAL = { "C_AddOns.GetAddOnMetadata", "C_FriendList.IsIgnored", "C_FriendList.GetNumFriends", "C_FriendList.GetFriendInfoByIndex",
    "Ambiguate", "GetBindingFromInput", "FlashClientIcon", "PanelTemplates_TabResize", "issecretvalue", "ChatFrame_AddMessageEventFilter",
    "GetNumGroupMembers", "GetRaidRosterInfo", "GetGuildRosterInfo", "GetNumGuildMembers", "UnitIsConnected", "GetUnitName",
    "CreateSettingsButtonInitializer" }

local function lookup(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local SOUND_GAP = 5      -- Sekunden zwischen zwei Klängen im Selbsttest

-- Namen im Testbericht stehen als Kennung da (eine Prüfsumme des Namens): so sieht man, ob zwei
-- Zeilen denselben Spieler meinen und ob man es selbst war, ohne dass ein Name im Bericht steht.
local function mask(name)
    local h = 5381
    for i = 1, #tostring(name) do h = (h * 33 + tostring(name):byte(i)) % 16777216 end
    return ("#%06x"):format(h)
end

-- Wofür jeder Klang steht: der Selbsttest zeigt es an, während er läuft
local SOUND_INFO = {
    start = L["a game starts"], point = L["a point scored, a field filling up"], click = L["a button, a reel stopping"],
    line = L["a line cleared"], big = L["a win"], over = L["game over"], record = L["new record, jackpot, daily task done"],
    flag = L["a switch turned on"], alarm = L["landing alarm"], bad = L["a loss"], fanfare = L["free spins in the slot machine"],
    t1 = L["totem tone 1"], t2 = L["totem tone 2"], t3 = L["totem tone 3"], t4 = L["totem tone 4"],
}

-- Fenster zum Zusehen: was gerade geprüft wird, und alle Symbolbilder zum Ansehen
local function SelfTestFrame(paths)
    local f = ns.selfFrame
    if not f then
        f = CreateFrame("Frame", "PastimeSelfTestFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop(BACKDROP_DIALOG_32_32 or ns.TOOLTIP_BACKDROP)
        ns.TintDialog(f)
        f:SetSize(440, 250)
        f:SetPoint("TOP", 0, -80)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f.title = ns.FontString(f, "GameFontNormal", "CENTER")
        f.title:SetPoint("TOP", 0, -18)
        f.title:SetText(L["Pastime self-test"])
        f.step = ns.FontString(f, "GameFontNormalLarge", "CENTER")
        f.step:SetPoint("TOP", 0, -44)
        f.step:SetWidth(400)
        f.desc = ns.FontString(f, "GameFontHighlight", "CENTER")
        f.desc:SetPoint("TOP", f.step, "BOTTOM", 0, -6)
        f.desc:SetWidth(400)
        f.icons = {}
        -- Auswahl vor dem Start: mit oder ohne Klänge
        f.quick = ns.CreateButton(f, L["Quick test"], 190, function() ns.PlaySound("click"); ns.SelfTest("quick") end)
        f.quick:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 18)
        f.full = ns.CreateButton(f, L["With all sounds"], 190, function() ns.PlaySound("click"); ns.SelfTest("sounds") end)
        f.full:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 18)
        ns.CreateCloseButton(f):SetPoint("TOPRIGHT", -4, -4)
        tinsert(UISpecialFrames, "PastimeSelfTestFrame")
        ns.selfFrame = f
    end
    for i, path in ipairs(paths) do
        local icon = f.icons[i]
        if not icon then
            icon = f:CreateTexture(nil, "ARTWORK")
            icon:SetSize(30, 30)
            icon:SetPoint("TOPLEFT", 24 + ((i - 1) % 11) * 36, -116 - math.floor((i - 1) / 11) * 36)
            f.icons[i] = icon
        end
        icon:SetTexture(path)
    end
    f:Show()
    return f
end

-- what: "quick" (ohne Klänge, wenige Sekunden) · "sounds" (dazu jeder Klang, gut eine Minute) ·
-- nichts: das Fenster fragt, was es sein soll
function ns.SelfTest(what)
    if ns.selfTest then return end
    if what ~= "quick" and what ~= "sounds" then
        local f = SelfTestFrame({})
        f:SetScript("OnHide", nil)
        f.step:SetText(L["What should be tested?"])
        f.desc:SetText(L["Quick: client, pictures, saved data and addon messages – a few seconds. With all sounds: also every sound, five seconds each."])
        for _, icon in ipairs(f.icons) do icon:Hide() end
        f.quick:Show(); f.full:Show()
        return
    end
    local sounds = what == "sounds"
    local out, bad = {}, 0
    ns.selfTest = out
    -- ok: true = in Ordnung, false = Fehler, nil = nur zur Kenntnis
    local function add(ok, text)
        if ok == false then bad = bad + 1 end
        out[#out + 1] = (ok == true and "ok    " or (ok == false and "FAIL  " or "info  ")) .. text
    end
    ns.Print(sounds and L["Self-test running: a good minute, one sound every five seconds. The result opens in a window afterwards."]
        or L["Self-test running: a few seconds. The result opens in a window afterwards."])

    local version, build, _, toc = GetBuildInfo()
    add(nil, ("Pastime %s · client %s (%s) · interface %s · %s · %s"):format(tostring(ns.VERSION), tostring(version), tostring(build),
        tostring(toc), tostring(GetLocale and GetLocale()), ns.IsAlliance() and "Alliance" or "Horde"))
    for _, path in ipairs(NEEDED) do add(lookup(path) ~= nil, "API " .. path) end
    for _, path in ipairs(OPTIONAL) do add(lookup(path) ~= nil and true or nil, "API " .. path .. (lookup(path) == nil and " (missing, optional)" or "")) end

    -- Texturen: nach SetTexture muss der Client eine Datei kennen
    local tex = (ns.frame or UIParent):CreateTexture()
    tex:Hide()
    local paths = { "Interface\\CharacterFrame\\TempPortraitAlphaMask" }
    for _, def in ipairs(ns.games) do paths[#paths + 1] = def.icon end
    for _, path in ipairs(ns.SELFTEST_TEXTURES or {}) do paths[#paths + 1] = path end
    local win = SelfTestFrame(paths)
    win.quick:Hide(); win.full:Hide()
    for _, icon in ipairs(win.icons) do icon:Show() end
    -- Das Fenster schließen bricht den Test ab
    win:SetScript("OnHide", function()
        if ns.selfTest ~= out then return end
        out.cancelled, ns.selfTest = true, nil
        ns.Print(L["Self-test cancelled."])
    end)
    win.step:SetText(L["Checking the client …"])
    win.desc:SetText(L["Below are all symbol pictures. Empty or green squares would be missing pictures."])
    local missing = 0
    for _, path in ipairs(paths) do
        tex:SetTexture(path)
        if tex:GetTexture() == nil then missing = missing + 1; add(false, "texture " .. tostring(path)) end
    end
    add(missing == 0, ("textures: %d of %d known to the client"):format(#paths - missing, #paths))

    -- Gespeichertes
    local db = ns.DB
    add(type(db.purses) == "table" and type(db.scores) == "table" and type(db.daily) == "table", "saved data has its tables")
    add(nil, ("jackpot %s · start gold raised %s · newest version seen %s · log entries %d"):format(tostring(db.jackpot),
        tostring(db.gold1000), tostring(db.newest), #db.log))
    add(nil, ("direct messages confirmed earlier: by another player %s · to yourself %s"):format(tostring(db.directPeer == true), tostring(db.directSelf == true)))
    local daily, goal, done, streak = ns.Daily()
    add(daily ~= nil, ("daily task: %s, goal %s, done %s, streak %s"):format(daily and daily.id or "?", tostring(goal), tostring(done), tostring(streak)))

    -- Client-Aufrufe, die in dieser Sitzung schon fehlgeschlagen sind
    local failed = 0
    for name, f in pairs(ns.fails) do failed = failed + 1; add(false, ("client call failed %d×: %s (%s)"):format(f.n or 1, name, tostring(f.err))) end
    add(failed == 0, "client calls that failed so far: " .. failed)

    -- Addon-Nachrichten: eine an sich selbst und zurück
    -- Addon-Nachrichten. Gilde und Gruppe schicken dem Absender die eigene Frage zurück: daran sieht
    -- man, dass Senden und Empfangen gehen, und unter welchem Namen man selbst sendet. Mit diesem
    -- Namen geht danach eine direkte Nachricht an sich selbst.
    local C, echo, listener = ns.Comm, {}, nil
    add(C.registered == true, "addon message prefix registered")
    local question, channels = ("PT1^HELLO^0^0^%d"):format(C.tag or 1), {}
    if C.registered and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        listener = CreateFrame("Frame")
        listener:RegisterEvent("CHAT_MSG_ADDON")
        listener:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
            if prefix == C.PREFIX and text == question then echo[tostring(channel)] = tostring(sender) end
        end)
        local function ask(channel)
            local ok, res = ns.Try("SelfTest:SendAddonMessage", C_ChatInfo.SendAddonMessage, C.PREFIX, question, channel)
            add(ok and (res == true or res == 0), ("addon message sent to %s, result %s"):format(channel, tostring(res)))
            channels[#channels + 1] = channel
        end
        if IsInGuild and IsInGuild() then ask("GUILD") end
        if IsInRaid and IsInRaid() then ask("RAID") elseif IsInGroup and IsInGroup() then ask("PARTY") end
        C_Timer.After(SOUND_GAP * 0.5, ns.Wrap("selbsttest", function()
            if out.cancelled then return end
            local me = echo.GUILD or echo.RAID or echo.PARTY
            local short = UnitName("player")
            add(nil, ("own sender name: %s; same as UnitName: %s; contains a space: %s; contains a dash: %s"):format(me and "known from the echo" or "unknown (no guild or group)",
                tostring(me == short), tostring(me ~= nil and me:find(" ", 1, true) ~= nil), tostring(me ~= nil and me:find("-", 1, true) ~= nil)))
            add(nil, "your own id in this report: " .. mask(me or short))
            -- Für den Mehrspieler: In welcher Form nennen Gruppen-, Gilden- und Freundesliste die Namen, und
            -- steht der eigene Absendername genau so darin? Ausgegeben werden nur Zahlen, keine Namen.
            local function shape(label, names, online)
                local space, dash, hit = 0, 0, false
                for _, n in ipairs(names) do
                    if n:find(" ", 1, true) then space = space + 1 end
                    if n:find("-", 1, true) then dash = dash + 1 end
                    if me and n == me then hit = true end
                end
                add(nil, ("%s: %d names, %d online, %d with a space, %d with a dash, own sender name among them: %s"):format(label, #names, online,
                    space, dash, tostring(hit)))
            end
            local names, online = {}, 0
            for i = 1, GetNumGroupMembers and GetNumGroupMembers() or 0 do
                local unit = (IsInRaid and IsInRaid()) and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
                local n = UnitName(unit)
                if type(n) == "string" then
                    names[#names + 1] = n
                    if UnitIsConnected and UnitIsConnected(unit) then online = online + 1 end
                end
            end
            shape("group list (UnitName)", names, online)
            names, online = {}, 0
            for i = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
                local n, _, _, _, _, _, _, _, on = GetGuildRosterInfo(i)
                if type(n) == "string" then
                    names[#names + 1] = n
                    if on then online = online + 1 end
                end
            end
            shape("guild list", names, online)
            names, online = {}, 0
            local F = C_FriendList
            for i = 1, F and F.GetNumFriends and F.GetNumFriends() or 0 do
                local info = F.GetFriendInfoByIndex(i)
                if type(info) == "table" and type(info.name) == "string" then
                    names[#names + 1] = info.name
                    if info.connected then online = online + 1 end
                end
            end
            shape("friend list", names, online)
            local full = GetUnitName and GetUnitName("player", true)
            add(nil, ("own name forms: GetUnitName(player, true) equals sender name: %s; UnitName returns %d value(s)"):format(tostring(me ~= nil and full == me),
                select("#", UnitName("player"))))
            local ok, res = ns.Try("SelfTest:SendAddonMessage", C_ChatInfo.SendAddonMessage, C.PREFIX, question, "WHISPER", me or short)
            add(ok and (res == true or res == 0), ("direct addon message to yourself sent (%s), result %s"):format(me and "full sender name" or "UnitName", tostring(res)))
        end))
    end
    add(nil, ("in guild %s · in group %s · in raid %s · peers heard %d"):format(tostring(IsInGuild and IsInGuild()), tostring(IsInGroup and IsInGroup()),
        tostring(IsInRaid and IsInRaid()), (function() local n = 0; for _ in pairs(C.peers or {}) do n = n + 1 end; return n end)()))

    -- Klänge: einer alle SOUND_GAP Sekunden, damit jeder ausklingt; der Client meldet, ob er ihn abspielt
    local kinds = {}
    for kind in pairs(sounds and ns.SOUNDS or {}) do kinds[#kinds + 1] = kind end
    table.sort(kinds)
    if not sounds then add(nil, "sounds: not tested (quick run)") end
    for i, kind in ipairs(kinds) do
        C_Timer.After((i - 1) * SOUND_GAP + 1, ns.Wrap("selbsttest", function()
            if out.cancelled then return end
            local id = ns.SOUNDS[kind]
            if type(id) ~= "number" then id = SOUNDKIT and SOUNDKIT[id] end
            local ok, will = false, nil
            if id then ok, will = pcall(PlaySound, id, "SFX") end
            add(id ~= nil and ok and will and true or false, ("sound %s (kit %s) plays: %s"):format(kind, tostring(id), tostring(will)))
            -- damit man sieht, welcher Klang gerade läuft und wofür er steht
            win.step:SetText((L["Sound %d of %d: %s"]):format(i, #kinds, kind))
            win.desc:SetText(SOUND_INFO[kind] or "")
            ns.Print(("|cffbbbbbb%d/%d · %s – %s|r"):format(i, #kinds, kind, SOUND_INFO[kind] or ""))
        end))
    end
    C_Timer.After(math.max(#kinds, 1) * SOUND_GAP + 1, ns.Wrap("selbsttest", function()
        if listener then listener:UnregisterEvent("CHAT_MSG_ADDON") end
        if out.cancelled then return end
        if listener then
            listener:UnregisterEvent("CHAT_MSG_ADDON")
            for _, channel in ipairs(channels) do
                add(echo[channel] ~= nil, ("addon message via %s %s"):format(channel, echo[channel] and "came back" or "did not come back"))
            end
            add(echo.WHISPER and true or nil, "direct addon message to yourself " .. (echo.WHISPER and "came back: direct messages arrive"
                or "did not come back (it takes a second player to be sure)"))
            if echo.WHISPER then db.directSelf = true end
        end
        win.desc:SetText("")
        win.step:SetText((L["Done: %d problem(s)"]):format(bad))
        table.insert(out, 1, ("Pastime self-test: %d problem(s)"):format(bad))
        ns.selfTest = nil
        ns.Log(bad > 0 and "W" or "I", "selbsttest", "%d problem(s)", bad)
        ns.Print((L["Self-test finished: %d problem(s). Copy the text from the window with Ctrl+C."]):format(bad))
        ns.ShowCopy(L["Pastime self-test"], ns.Anonymize(table.concat(out, "\n")))
    end))
end

---------------------------------------------------------------------------
-- Layout-Prüfer (/pastime layout, nur mit Debug): meldet abgeschnittene,
-- überstehende und überlappende Texte/Knöpfe als Warnung „layout“ im Protokoll
---------------------------------------------------------------------------
local TOL = 1
local logged, loggedN = {}, 0

local function rect(r)
    local l, rt, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
    if l and rt and t and b then return l, rt, t, b end
end

-- Fläche, die der Text wirklich belegt (bei fester Breite/Höhe kleiner als der Rahmen)
local function textRect(fs)
    local l, r, t, b = rect(fs)
    if not l then return end
    local sw, sh = fs:GetStringWidth() or 0, fs:GetStringHeight() or 0
    if sw < r - l then
        local j = fs:GetJustifyH()
        if j == "LEFT" then r = l + sw
        elseif j == "RIGHT" then l = r - sw
        else local c = (l + r) / 2; l, r = c - sw / 2, c + sw / 2 end
    end
    if sh < t - b then
        local j = fs:GetJustifyV()
        if j == "TOP" then b = t - sh
        elseif j == "BOTTOM" then t = b + sh
        else local c = (t + b) / 2; t, b = c + sh / 2, c - sh / 2 end
    end
    return l, r, t, b
end

local function label(obj)
    local s = obj.GetText and obj:GetText()
    if s and s ~= "" then return '"' .. plain(s):gsub("\n", " / "):sub(1, 50) .. '"' end
    return obj.GetDebugName and obj:GetDebugName() or obj:GetObjectType()
end

function ns.LayoutCheck(roots)
    local found, seen = {}, {}
    local function report(msg)
        if not seen[msg] then seen[msg] = true; found[#found + 1] = msg end
    end
    -- inScroll: in Scrollbereichen darf Text oben/unten aus dem Bild laufen
    local function walk(frame, inScroll)
        local fl, fr, ft, fb = rect(frame)
        local items = {}
        for _, reg in ipairs({ frame:GetRegions() }) do
            if reg:GetObjectType() == "FontString" and reg:IsVisible() and (reg:GetText() or "") ~= "" then
                if reg.IsTruncated and reg:IsTruncated() then report("truncated: " .. label(reg)) end
                local l, r, t, b = textRect(reg)
                if l then
                    items[#items + 1] = { reg, l, r, t, b }
                    -- Häkchen: Beschriftung steht absichtlich neben dem Kästchen
                    if fl and frame:GetObjectType() ~= "CheckButton" and (l < fl - TOL or r > fr + TOL or (not inScroll and (t > ft + TOL or b < fb - TOL))) then
                        report(("sticks out of %s: %s"):format(label(frame), label(reg)))
                    end
                end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:IsVisible() then
                local ot = child:GetObjectType()
                -- Knöpfe nur mit Beschriftung: Karten, Spalten und Felder ohne Text dürfen sich überlappen
                if (ot == "Button" or ot == "CheckButton") and ((child.GetText and child:GetText()) or "") ~= "" then
                    local l, r, t, b = rect(child)
                    if l then items[#items + 1] = { child, l, r, t, b } end
                end
                walk(child, inScroll or ot == "ScrollFrame")
            end
        end
        for i = 1, #items do
            local a = items[i]
            for j = i + 1, #items do
                local c = items[j]
                if math.min(a[3], c[3]) - math.max(a[2], c[2]) > TOL and math.min(a[4], c[4]) - math.max(a[5], c[5]) > TOL then
                    report(("overlap: %s / %s"):format(label(a[1]), label(c[1])))
                end
            end
        end
    end
    for _, root in ipairs(roots or { ns.frame, ns.alertFrame }) do
        if root and root:IsVisible() then walk(root, false) end
    end
    -- jeder Fund nur einmal pro Sitzung ins Protokoll (die Prüfung läuft im Debug-Modus ständig)
    for _, msg in ipairs(found) do
        if not logged[msg] and loggedN < 100 then
            logged[msg], loggedN = true, loggedN + 1
            ns.Log("W", "layout", "%s", msg)
        end
    end
    return found
end

---------------------------------------------------------------------------
-- /pastime shots: Vorzeige-Szenen stellen und von jeder einen Screenshot machen
-- (für die Addon-Seite). Nichts davon wird gewertet oder gespeichert: die Spiele
-- werden gestellt und am Ende verworfen.
---------------------------------------------------------------------------
local function card(rank, suit) return { rank = rank, suit = suit } end

local SCENES = {
    function()      -- Spielauswahl
        ns.ShowLauncher()
        ns.selected = ns.gamesById.rockfall
        ns.UpdateUI()
    end,
    function()      -- Steinschlag mit halb gefülltem Feld
        ns.StartGame(ns.gamesById.rockfall)
        local g = ns.run.game
        local colors = { { 0.10, 0.45, 0.90 }, { 0.85, 0.20, 0.20 }, { 0.12, 0.78, 0.10 }, { 0.64, 0.21, 0.93 },
            { 0.95, 0.80, 0.25 }, { 1.00, 0.50, 0.00 }, { 0.30, 0.78, 0.88 } }
        local heights = { 4, 3, 5, 2, 0, 3, 4, 1, 3, 5 }
        for x = 0, 9 do
            for h = 1, heights[x + 1] do g.board[20 - h][x] = colors[(x + h * 3) % #colors + 1] end
        end
        g.score, g.lines = 1240, 7
        g:Render()
    end,
    function() ns.StartGame(ns.gamesById.murlocs) end,
    function()      -- Kodo-Sprint: mitten im Sprung über ein Hindernis. Das Spiel bleibt im Wartezustand,
        ns.StartGame(ns.gamesById.kodo)      -- dort gibt es keine Zusammenstöße
        local g = ns.run.game
        g.hint:Hide()
        g:NewObstacle()
        for _, o in ipairs(g.pool) do
            if o.active then o.x = 150; g:PlaceObstacle(o) end
        end
        g.h, g.score = 46, 312
        g:PlaceKodo()
    end,
    function()      -- Hold'em mitten in einer Hand
        ns.StartGame(ns.gamesById.holdem)
        local g = ns.run.game
        g.buyin, g.hands, g.button, g.bet = 400, 3, 2, 400
        g.stacks = { 380, 290, 520, 310 }
        g.holes = { { card(1, 1), card(13, 1) }, { card(7, 3), card(7, 4) }, { card(10, 2), card(9, 2) }, { card(4, 3), card(12, 4) } }
        g.comm = { card(12, 1), card(5, 1), card(13, 3), card(2, 4), card(9, 1) }
        g.folded, g.allin, g.says, g.reveal = { [4] = true }, {}, { [2] = L["raises"], [3] = L["calls"], [4] = L["folds"] }, false
        g.c, g.r, g.acted = { 20, 60, 60, 20 }, { 0, 40, 40, 0 }, {}
        g.street, g.cur, g.raises, g.seat, g.state = 2, 40, 1, 1, "act"
        g.sub:SetText(L["Your turn."])
        g:Render()
    end,
    function()      -- Goblin-Automat mit Gewinnlinie
        ns.StartGame(ns.gamesById.slots)
        local g = ns.run.game
        g.grid = { { 5, 1, 2 }, { 5, 3, 1 }, { 6, 2, 4 }, { 5, 1, 3 }, { 2, 4, 1 } }
        local _, cells = g.Evaluate(g.grid)
        g.won, g.blinkOn = cells, true
        g.msg:SetText("|cff80ff80+110 Gold|r")
        g.sub:SetText(L["Winning line!"])
        g:Render()
    end,
    function()      -- Ankunftsdialog (gestellt: nichts wird gewertet)
        ns.StartGame(ns.gamesById.kobold)
        local run = ns.run
        local route
        for _, r in pairs(ns.DB.routes) do
            if type(r) == "table" and r.kind == "flug" then route = r; break end
        end
        route = route or { kind = "flug", from = "Crossroads", to = "Orgrimmar" }
        run.game.score = 240
        run.state = "paused"
        run.landed = { kind = "flug", dest = ns.ShortName(route.to), bound = true, score = 240, route = route, rank = 1 }
        ns.ShowLandedOverlay()
        ns.UpdateSidePanel()
    end,
    function() ns.ShowFrame("records") end,
}

-- Beispiel-Rekorde und -Strecken nur für die Bilder: erfundene Namen statt der eigenen Charaktere,
-- gut gefüllte Listen. Die echten Tabellen werden währenddessen nur beiseitegelegt.
local function demoData()
    local today = date(ns.DATE_FORMAT)
    local names = { "Thokk", "Zugra", "Morga" }
    local function list(...)
        local t = {}
        for i, s in ipairs({ ... }) do t[i] = { s = s, p = names[(i - 1) % #names + 1], d = today } end
        return t
    end
    local scores = {
        rockfall = list(4820, 3150, 2760, 1980, 1240), murlocs = list(2140, 1620, 980), kodo = list(812, 640, 455),
        kobold = list(1130, 920, 760), holdem = list(1600, 850, 400), slots = list(940, 515, 260), blackjack = list(720, 340),
    }
    local routes, first = {}, nil
    local function route(kind, from, to, t, n, sc)
        local key = ns.RouteKey(kind, from, to)
        routes[key] = { kind = kind, from = from, to = to, t = t, n = n, last = today, lastT = t, scores = sc or {} }
        first = first or key
    end
    route("flug", "Orgrimmar", "Crossroads", 112, 14, { rockfall = list(2760, 1980, 1240), kodo = list(455, 312), kobold = list(920),
        murlocs = list(980) })
    route("flug", "Crossroads", "Ratchet", 52, 9, { kodo = list(640), kobold = list(1130, 760) })
    route("flug", "Crossroads", "Thunder Bluff", 190, 6, { rockfall = list(4820), murlocs = list(2140, 1620) })
    route("flug", "Ratchet", "Orgrimmar", 160, 5, { rockfall = list(3150) })
    route("flug", "Camp Taurajo", "Crossroads", 79, 7, { kodo = list(812) })
    route("flug", "Orgrimmar", "Thunder Bluff", 285, 3, { holdem = list(850), rockfall = list(1980) })
    route("zeppelin", "Orgrimmar", "Undercity", 119, 4, { holdem = list(1600, 400), slots = list(940) })
    route("zeppelin", "Orgrimmar", "Grom'gol", 95, 2, { slots = list(515, 260) })
    return scores, routes, first
end

function ns.PhotoTour()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    ns.ShowFrame()
    -- solange die Tour läuft, wertet GameOver nichts (ein Kodo ohne Reiter läuft sonst in den Kaktus).
    -- Der Zeitgeber hebt die Sperre auch dann auf, wenn eine Szene mit einem Fehler abbricht.
    local realScores, realRoutes, realSelected = ns.DB.scores, ns.DB.routes, ns.selectedRoute
    local function restore()
        if ns.staging then ns.DB.scores, ns.DB.routes, ns.selectedRoute = realScores, realRoutes, realSelected end
        ns.staging = nil
    end
    ns.staging = true
    ns.DB.scores, ns.DB.routes, ns.selectedRoute = demoData()
    C_Timer.After(#SCENES * 2 + 5, restore)
    local i = 0
    local step
    step = ns.Wrap("fotos", function()
        i = i + 1
        local scene = SCENES[i]
        if not scene then
            restore()
            ns.ShowLauncher()
            return ns.Print((L["%d screenshots saved in the Screenshots folder of your game."]):format(#SCENES))
        end
        scene()
        C_Timer.After(1.2, ns.Wrap("fotos", function()
            if Screenshot then Screenshot() end
            C_Timer.After(0.8, step)
        end))
    end)
    step()
end
