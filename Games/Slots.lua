-- Pastime: Goblin-Automat – fünf Walzen, drei Reihen, fünf Gewinnlinien; eigener Goldtopf,
-- gewertet wird der höchste Goldstand
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local COLS, ROWS, CELL, GAPX, GAPY = 5, 3, 62, 10, 6

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

-- Symbole: Gewicht je Feld und Auszahlung für 3, 4 und 5 gleiche von links – als Vielfaches
-- des Linieneinsatzes (ein Fünftel des Einsatzes); pair = Auszahlung schon für zwei gleiche.
-- Viele kleine Treffer bringen weniger als den Einsatz zurück: gut die Hälfte der Drehungen
-- zahlt etwas, rund jede siebte mehr als den Einsatz.
-- Die Rune (letztes Symbol) ist Joker und Scatter zugleich: sie ersetzt auf jeder Linie jedes
-- Symbol, liegt höchstens einmal je Walze und nie auf allen fünf. Drei oder vier Runen irgendwo
-- zahlen sofort das RUNE_PAY-fache des ganzen Einsatzes und geben FREE Freispiele.
-- In den Freispielen gilt ein Bonussymbol (eins der fünf gewöhnlichen, vom Spieler gezogen):
-- liegt es auf drei, vier oder fünf Walzen – egal wo, auch mit Lücken –, füllt es diese Walzen
-- und zahlt zusätzlich expand (in Linieneinsätzen, für das ganze Bild). Verlängern Runen die
-- Freispiele, kommt ein zweites Bonussymbol dazu.
-- Auszahlungsquote samt Freispielen rund 96 % (tests/games.lua rechnet nach). Sie hängt stark
-- an RUNE_CHANCE: ein halbes Prozent mehr sind gut fünf Punkte Quote.
Game.SYMBOLS = {
    { icon = "Interface\\Icons\\INV_Misc_Fish_02", w = 13, pay = { 4, 6, 10 }, expand = { 1, 3, 15 } },
    { icon = "Interface\\Icons\\INV_Misc_Bomb_04", w = 10, pay = { 4, 7, 11 }, expand = { 2, 4, 20 } },
    { icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01", w = 7, pair = 1, pay = { 5, 8, 14 }, expand = { 3, 8, 40 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01", w = 4, pair = 2, pay = { 6, 10, 25 }, expand = { 6, 20, 100 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01", w = 3, pair = 2, pay = { 8, 12, 50 }, expand = { 10, 40, 250 } },
    { icon = "Interface\\Icons\\INV_Misc_Coin_01", w = 3, pair = 3, pay = { 10, 25, 200 } },
    { icon = "Interface\\Icons\\INV_Misc_Rune_01" },
}
local COIN, RUNE = 6, 7
Game.STAKE = true
Game.JACKPOT = L["five rubies or coins on one line"]
Game.PLAY = L["Spin for %d gold (Space)"]
Game.RUNE_CHANCE = 0.137      -- je Walze
Game.FREE = { 10, 20 }        -- für drei und für vier Runen
Game.RUNE_PAY = { 2, 10 }
local AUTO_SPINS = 20
local PICK_TIME, PICK_REEL = 2.5, 3      -- so lange dreht die mittlere Walze, bis das Bonussymbol feststeht
local FILL_WAIT, FILL_STEP = 0.6, 0.14   -- Auffüllen der Walzen: Pause davor, Abstand zwischen zwei Feldern
local BIG_WIN, COUNT_TIME = 10, 2.2      -- ab dem BIG_WIN-fachen Einsatz zählt die Anzeige den Gewinn hoch
-- Gewinnlinien: Reihe je Walze (drei Reihen, zwei Diagonalen)
Game.LINES = { { 1, 1, 1, 1, 1 }, { 2, 2, 2, 2, 2 }, { 3, 3, 3, 3, 3 }, { 1, 2, 3, 2, 1 }, { 3, 2, 1, 2, 3 } }
-- Sprüche unter dem Ergebnis: einer davon, zufällig
local LOSE = { L["No luck this time."], L["The goblin grins."], L["So close."], L["Nothing. Again."], L["The reels have other plans."],
    L["The goblin counts your gold."], L["Next spin, for sure."] }
local WIN = { L["Winning line!"], L["That's the stuff!"], L["The goblin winces."], L["Gold for you!"], L["Keep them coming!"],
    L["The machine likes you."] }
local function pick(t) return t[math.random(#t)] end
ns.SELFTEST_TEXTURES = {}
for _, s in ipairs(Game.SYMBOLS) do ns.SELFTEST_TEXTURES[#ns.SELFTEST_TEXTURES + 1] = s.icon end
local STRIP = {}
for i, s in ipairs(Game.SYMBOLS) do for _ = 1, s.w or 0 do STRIP[#STRIP + 1] = i end end
local FIRST_STOP, STOP_STEP, TEASE = 0.9, 0.45, 1.1      -- die Walzen bleiben von links nach rechts stehen; TEASE: Extrazeit vor einer spannenden Walze

-- Gleiche Symbole von links (Runen zählen mit) unter den ersten upto Feldern einer Linie.
-- Nur Runen: sie zählen als Münzen.
function Game.Run(s, upto)
    local sym = COIN
    for i = 1, upto do
        if s[i] ~= RUNE then sym = s[i]; break end
    end
    local n = 0
    for i = 1, upto do
        if s[i] == sym or s[i] == RUNE then n = n + 1 else break end
    end
    return n, sym
end

-- Eine Linie (fünf Symbole von links): Auszahlung und Zahl der zählenden Felder
function Game.LinePay(s)
    local n, sym = Game.Run(s, COLS)
    local pay = n >= 3 and Game.SYMBOLS[sym].pay[n - 2] or (n == 2 and Game.SYMBOLS[sym].pair or 0)
    -- Runen vorn können als Münzen mehr wert sein als die längere Reihe, die sie ergänzen
    -- (vier Runen und ein Fisch: 25 statt 10): es zählt die bessere Lesart
    local runes = 0
    while s[runes + 1] == RUNE do runes = runes + 1 end
    if runes >= 3 and Game.SYMBOLS[COIN].pay[runes - 2] > pay then return Game.SYMBOLS[COIN].pay[runes - 2], runes end
    if pay == 0 then return 0, 0 end
    return pay, n
end

-- Spannung: Felder der Linien, auf denen vor Walze col noch alles passt. Vor der dritten
-- Walze zählen nur die wertvollen Symbole (Smaragd, Rubin, Münze), danach jede laufende Reihe.
function Game.Tease(grid, col)
    local cells, any = {}, false
    for _, line in ipairs(Game.LINES) do
        local s = {}
        for c = 1, col - 1 do s[c] = grid[c][line[c]] end
        local n, sym = Game.Run(s, col - 1)
        if n == col - 1 and (col > 3 or sym >= 4) then
            any = true
            for c = 1, col - 1 do cells[c * 10 + line[c]] = true end
        end
    end
    -- zwei Runen liegen schon: die dritte brächte Freispiele
    local runes = {}
    for c = 1, col - 1 do
        for r = 1, ROWS do if grid[c][r] == RUNE then runes[#runes + 1] = c * 10 + r end end
    end
    if #runes >= 2 then
        any = true
        for _, k in ipairs(runes) do cells[k] = true end
    end
    return any and cells or nil
end

-- Runen im ganzen Feld: Zahl der Freispiele (oder nil), ihre Felder und das Vielfache des Einsatzes
function Game.Scatter(grid)
    local cells, n = {}, 0
    for c = 1, COLS do
        for r = 1, ROWS do if grid[c][r] == RUNE then n = n + 1; cells[c * 10 + r] = true end end
    end
    local i = math.min(n, 4) - 2
    return Game.FREE[i], cells, Game.RUNE_PAY[i]
end

-- Walzen, auf denen das Bonussymbol liegt
function Game.Expand(grid, sym)
    local reels = {}
    for c = 1, COLS do
        for r = 1, ROWS do
            if grid[c][r] == sym then reels[#reels + 1] = c; break end
        end
    end
    return reels
end

-- Ganzes Feld grid[Walze][Reihe]: Summe der Linien und die Felder, die gewonnen haben
function Game.Evaluate(grid)
    local sum, cells = 0, {}
    for _, line in ipairs(Game.LINES) do
        local s = {}
        for c = 1, COLS do s[c] = grid[c][line[c]] end
        local pay, n = Game.LinePay(s)
        sum = sum + pay
        for c = 1, n do cells[c * 10 + line[c]] = true end
    end
    return sum, cells
end

local function strip() return STRIP[math.random(#STRIP)] end

-- Jede Walze zeigt mit RUNE_CHANCE genau eine Rune; fünf Runen gibt es nicht
function Game.RandomGrid()
    local g, runes = {}, {}
    for c = 1, COLS do
        g[c] = { strip(), strip(), strip() }
        if math.random() < Game.RUNE_CHANCE then
            local r = math.random(ROWS)
            g[c][r] = RUNE
            runes[#runes + 1] = { c, r }
        end
    end
    if #runes == COLS then
        local x = runes[math.random(COLS)]
        g[x[1]][x[2]] = strip()
    end
    return g
end

function Game:Clear()
    self.won, self.hot, self.count, self.steps, self.only = {}, nil, nil, nil, nil
end

function Game:Start()
    self.grid = Game.RandomGrid()
    self.auto, self.autoT = false, nil
    local p = self:Purse()
    if (tonumber(p.gold) or 0) < ns.Gamble.MIN_BET then p.free = nil end      -- neuer Lauf: alte Freispiele verfallen
    self.free, self.stake, self.specials, self.pick = tonumber(p.free) or 0, tonumber(p.stake) or 0, {}, p.pick and true or nil
    for _, s in ipairs(type(p.specials) == "table" and p.specials or {}) do
        if type(s) == "number" and s >= 1 and s < COIN and #self.specials < 2 then self.specials[#self.specials + 1] = s end
    end
    self:OpenRun()
    if self.free > 0 and self.stake > 0 then
        self:Await()      -- Freispiele von vorhin
    else
        self.free, self.specials, self.pick = 0, {}, nil
    end
end

function Game:Save()
    ns.Gamble.Save(self)
    local p, left = self:Purse(), (self.free or 0) > 0
    p.free, p.stake = left and self.free or nil, left and self.stake or nil
    p.specials, p.pick = left and { unpack(self.specials or {}) } or nil, left and self.pick or nil
end

-- Freispiele stehen an und warten auf den Spieler: zuerst zieht er das Bonussymbol (Leertaste),
-- dann dreht jede Leertaste ein Freispiel – oder er schaltet dafür Auto-Spin ein.
function Game:Await()
    self.bet = 0
    self:Clear()
    if #self.specials == 0 or self.pick then
        self.state, self.pick = "pick", true
        self.msg:SetText((L["%d free spins!"]):format(self.free))
        self.sub:SetText(L["Space: draw your bonus symbol"])
        self:Save()
    else
        self.state = "free"
        self.msg:SetText("")
        self.sub:SetText((L["Free spins left: %d – Space spins, A: auto"]):format(self.free))
    end
    self:Render()
end

function Game:Next()
    if self.state == "pick" then
        -- nur die mittlere Walze dreht, die anderen sind ausgeblendet
        self.state, self.pickT, self.flick = "picking", PICK_TIME, 0
        self.sub:SetText("")
        self.host:Sound("click")
        return self:Render()
    end
    if self.state == "picked" then return self:Await() end
    if self.state == "result" then
        if (self.free or 0) > 0 then return self:Await() end
        self.specials, self.pick = {}, nil      -- Freispiele vorbei: die Bonussymbole gelten nicht mehr
        if self.isFree then self.auto = false end
        return ns.Gamble.Next(self)
    end
    if self.state ~= "free" then return end
    self.free = self.free - 1
    self.bet = 0
    self:Save()
    self:Clear()
    self:Deal(self.stake, true)
    self.sub:SetText((L["Free spin · %d left"]):format(self.free))
end

function Game:Deal(amount, free)
    self.stake, self.isFree = amount, free
    self.final = Game.RandomGrid()
    self:Plan()
    self.state, self.spin, self.flick, self.won = "spin", 0, 0, {}
    self.msg:SetText("")
    self.sub:SetText("")
    self:Render()
end

-- Wann welche Walze stehen bleibt: vor einer spannenden Walze dauert es länger
function Game:Plan()
    self.stops, self.tease = {}, {}
    local t = FIRST_STOP
    for c = 1, COLS do
        if c > 1 then
            self.tease[c] = c >= 3 and Game.Tease(self.final, c) or nil
            t = t + STOP_STEP + (self.tease[c] and TEASE or 0)
        end
        self.stops[c] = t
    end
end

-- Auto-Spin: AUTO_SPINS Drehungen von selbst. Er hört auf, wenn Freispiele fallen, wenn er
-- abgeschaltet wird oder das Gold ausgeht – danach muss der Spieler ihn selbst wieder starten.
-- Während der Freispiele eingeschaltet, dreht er sie durch und endet mit ihnen.
function Game:ToggleAuto()
    if self.state == "over" then return end
    self.auto, self.autoT, self.autoLeft = not self.auto, nil, AUTO_SPINS
    self.host:Sound("click")
    self:Render()
end

-- Ein Symbol, das noch kein Bonussymbol ist
function Game:FreshSymbol()
    local s
    repeat s = math.random(COIN - 1) until s ~= self.specials[1]
    return s
end

-- Die Walzen stehen: Linien, Runen, Bonussymbole, Jackpot. Füllen sich Walzen, läuft erst die
-- Animation (Zustand "expand"), dann wird ausgezahlt.
function Game:Settle()
    self.hot, self.blink, self.blinkOn = nil, 0, true
    for c = 1, COLS do self.grid[c] = { unpack(self.final[c]) } end
    local sum, cells = Game.Evaluate(self.final)
    local steps, extra, filled = {}, 0, nil
    if self.isFree then
        for _, sp in ipairs(self.specials) do
            local reels = Game.Expand(self.final, sp)
            if #reels >= 3 then
                filled = math.max(filled or 0, #reels)
                extra = extra + math.floor(self.stake * Game.SYMBOLS[sp].expand[#reels - 2] / #Game.LINES)
                for _, c in ipairs(reels) do
                    for r = 1, ROWS do steps[#steps + 1] = { c, r, sp } end
                end
            end
        end
    end
    local award, runes, bonus = Game.Scatter(self.final)
    if award then
        self.free = (self.free or 0) + award
        if self.isFree then
            if #self.specials < 2 then self.pick = true end      -- Verlängerung: ein zweites Bonussymbol
        else
            self.auto = false                                     -- neue Freispiele: der Spieler ist dran
        end
        self.host:Sound("fanfare")
        for k in pairs(runes) do cells[k] = true end
    end
    -- Jackpot: fünf Rubine oder Münzen auf einer Linie (rund jede 3.400. Drehung)
    local jack = false
    for _, line in ipairs(Game.LINES) do
        local all = true
        for c = 1, COLS do
            local s = self.final[c][line[c]]
            all = all and (s == COIN or s == COIN - 1)
        end
        jack = jack or all
    end
    if jack then self:Jackpot() end
    self.won = cells
    local win = math.floor(self.stake * sum / #Game.LINES) + (award and self.stake * bonus or 0) + extra
    local small = win <= self.bet      -- ein Treffer, der den Einsatz nicht wieder einspielt
    local text = filled == COLS and L["FULL SCREEN!"] or (filled and (L["Bonus symbol on %d reels!"]):format(filled))
        or award and (L["%d free spins!"]):format(award)
        or (sum > 0 and (small and (L["%d gold back"]):format(win) or pick(WIN)) or (self.isFree and (L["Free spins left: %d"]):format(self.free) or pick(LOSE)))
    self.pending = { win, text, (award or filled or (sum > 0 and not small)) and 2.6 or (sum > 0 and 1.6 or 1.2) }
    if #steps == 0 then return self:Finish() end
    self.state, self.steps, self.stepT = "expand", steps, FILL_WAIT
    self.sub:SetText(text)
    self:Render()
end

-- Auszahlen; große Gewinne zählt die Anzeige hoch
function Game:Finish()
    local win, text, wait = unpack(self.pending)
    local diff = win - self.bet
    self.pending, self.steps = nil, nil
    self:Pay(win, text, wait)
    if diff >= BIG_WIN * self.stake then
        self.count = { to = diff, t = 0 }
        self.t = self.t + COUNT_TIME
        self.msg:SetText("|cff80ff80+0 Gold|r")
    end
end

function Game:Update(dt)
    if self.state == "picking" then
        self.pickT, self.flick = self.pickT - dt, self.flick + dt
        if self.pickT <= 0 then
            -- das Symbol steht: kurz ist nur dieses eine Feld zu sehen, weiter geht es auf Tastendruck
            local sp = self:FreshSymbol()
            self.specials[#self.specials + 1] = sp
            self.grid[PICK_REEL] = { self.grid[PICK_REEL][1], sp, self.grid[PICK_REEL][3] }
            self.state, self.pick, self.only = "picked", nil, PICK_REEL * 10 + 2
            self.won, self.blinkOn = { [self.only] = true }, true
            self:Save()
            self.host:Sound("big")
            self.msg:SetText(L["Bonus symbol"])
            self.sub:SetText(L["Space: on to the free spins"])
        elseif self.flick >= 0.09 then
            self.flick = 0
            self.grid[PICK_REEL] = { self:FreshSymbol(), self:FreshSymbol(), self:FreshSymbol() }
            self.host:Sound("click")
        end
        return self:Render()
    end
    if self.state == "expand" then
        -- die Walzen des Bonussymbols füllen sich Feld für Feld
        self.stepT = self.stepT - dt
        while self.stepT <= 0 do
            local s = table.remove(self.steps, 1)
            if not s then return self:Finish() end
            self.won[s[1] * 10 + s[2]] = true
            if self.grid[s[1]][s[2]] ~= s[3] then
                self.grid[s[1]][s[2]] = s[3]
                self.stepT = self.stepT + FILL_STEP
                self.host:Sound("point")
            end
        end
        return self:Render()
    end
    if self.auto and (self.state == "bet" or self.state == "free") then
        self.autoT = (self.autoT or 0.4) - dt
        if self.autoT <= 0 then
            self.autoT = nil
            if self.state == "free" then return self:Next() end
            self.autoLeft = self.autoLeft - 1
            if self.autoLeft <= 0 then self.auto = false end
            self:Play()
        end
        return
    end
    if self.state ~= "spin" then
        if self.state == "result" then
            if self.count then
                local c = self.count
                c.t = c.t + dt
                local done = c.t >= COUNT_TIME
                self.msg:SetText(("|cff80ff80+%d Gold|r"):format(done and c.to or math.floor(c.to * c.t / COUNT_TIME)))
                self.host:Sound(done and "big" or "point")
                if done then self.count = nil end
            end
            -- Gewinnfelder blinken, solange das Ergebnis steht
            if next(self.won) then
                self.blink = (self.blink or 0) + dt
                local on = self.blink % 0.5 < 0.3
                if on ~= self.blinkOn then self.blinkOn = on; self:Render() end
            end
        end
        return self:Tick(dt)
    end
    local before = self.spin
    self.spin = self.spin + dt
    self.flick = self.flick + dt
    local flick = self.flick >= 0.07
    if flick then self.flick = 0 end
    self.hot = nil
    for c = 1, COLS do
        local stop = self.stops[c]
        if self.spin >= stop then
            self.grid[c] = self.final[c]
            if before < stop then self.host:Sound(self.tease[c] and "point" or "click") end
        else
            -- die nächste Walze: läuft sie auf etwas Gutes zu, leuchten die Felder davor
            if not self.hot and (c == 1 or self.spin >= self.stops[c - 1]) then self.hot = self.tease[c] end
            if flick then self.grid[c] = { strip(), strip(), strip() } end
        end
    end
    if self.spin < self.stops[COLS] then return self:Render() end
    self:Settle()
end

function Game:Key(k, down)
    if k == "A" then
        if down then self:ToggleAuto() end
        return true
    end
    if (self.state == "pick" or self.state == "picked" or self.state == "free") and (k == "SPACE" or k == "ENTER") then
        if down then self:Next() end
        return true
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    local picking = self.state == "pick" or self.state == "picking"
    for c = 1, COLS do
        for r = 1, ROWS do
            local cell = self.cells[c][r]
            local key = c * 10 + r
            local show = (not picking or c == PICK_REEL) and (self.state ~= "picked" or key == self.only)
            cell.icon:SetShown(show)
            cell.back:SetShown(show)
            ns.SetIcon(cell.icon, Game.SYMBOLS[self.grid[c][r]].icon)
            cell.glow:SetShown(show and ((self.won[key] == true and self.blinkOn ~= false) or (self.hot ~= nil and self.hot[key] == true)))
        end
    end
    self:BaseRender()
    self.nextBtn:SetShown(self.state == "result" or self.state == "pick" or self.state == "picked" or self.state == "free")
    local sp = self.specials or {}
    self.bonus:SetShown(sp[1] ~= nil)
    if sp[1] then ns.SetIcon(self.bonus.icon, Game.SYMBOLS[sp[1]].icon) end
    self.bonus.second:SetShown(sp[2] ~= nil)
    if sp[2] then ns.SetIcon(self.bonus.second, Game.SYMBOLS[sp[2]].icon) end
    self.autoBtn:SetText(self.auto and (L["Auto-spin: %d left (A)"]):format(self.autoLeft) or (L["Auto-spin: %d× (A)"]):format(AUTO_SPINS))
    self.autoBtn:SetShown(self.state ~= "over")
end

-- Vielfaches des ganzen Einsatzes (die Tabellen rechnen in Linieneinsätzen)
local function mult(v)
    local s = ("%g"):format(v / #Game.LINES)
    if ns.THOUSANDS == "." then s = s:gsub("%.", ",") end
    return "×" .. s
end

-- Gewinnplan für „Was gewinnt?“: je Symbol die Linien und, wo es Bonussymbol sein kann, die Walzen
local function Rules()
    local t = { L["Payouts as multiples of your bet. Left: 2 · 3 · 4 · 5 of a kind on a line. Right in gold: the bonus symbol on 3 · 4 · 5 reels in a free spin."] }
    for i = 1, COIN do
        local s = Game.SYMBOLS[i]
        local line = ("|T%s:16|t  %s · %s · %s · %s"):format(s.icon, s.pair and mult(s.pair) or "–", mult(s.pay[1]), mult(s.pay[2]), mult(s.pay[3]))
        if s.expand then
            line = line .. ("    |cffffd100%s · %s · %s|r"):format(mult(s.expand[1]), mult(s.expand[2]), mult(s.expand[3]))
        end
        t[#t + 1] = line
    end
    return table.concat(t, "\n")
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "slots", 266)
    g.grid, g.cells, g.won, g.specials = Game.RandomGrid(), {}, {}, {}
    g.autoBtn = ns.CreateButton(board, "", 190, function() if host:IsRunning() then ns.Safe("slots", g.ToggleAuto, g) end end)
    g.autoBtn:SetHeight(24)
    g.autoBtn:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", 8, 42)
    g.cashBtn:ClearAllPoints()
    g.cashBtn:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -8, 42)
    -- Bonussymbole der Freispiele: oben in der Mitte, nur solange sie gelten
    g.bonus = CreateFrame("Frame", nil, board)
    g.bonus:SetSize(24, 24)
    g.bonus:SetPoint("TOP", board, "TOP", 2, -4)
    g.bonus:EnableMouse(true)
    g.bonus.icon = g.bonus:CreateTexture(nil, "ARTWORK")
    g.bonus.icon:SetAllPoints()
    g.bonus.second = g.bonus:CreateTexture(nil, "ARTWORK")
    g.bonus.second:SetSize(24, 24)
    g.bonus.second:SetPoint("LEFT", g.bonus, "RIGHT", 3, 0)
    local bonusLabel = ns.FontString(g.bonus, "GameFontNormalSmall", "RIGHT")
    bonusLabel:SetPoint("RIGHT", g.bonus, "LEFT", -4, 0)
    bonusLabel:SetText(L["Bonus:"])
    ns.SetTooltip(g.bonus, L["Bonus symbol"], L["You draw it when the free spins start. If it lands on three or more reels during a free spin, it fills those reels and pays for that many of a kind – gaps do not matter. Five reels fill the whole screen. If runes extend your free spins, you draw a second bonus symbol."])
    g.bonus:Hide()
    local x0 = (W - COLS * CELL - (COLS - 1) * GAPX) / 2
    for c = 1, COLS do
        g.cells[c] = {}
        for r = 1, ROWS do
            local x, y = x0 + (c - 1) * (CELL + GAPX), 36 + (r - 1) * (CELL + GAPY)
            local glow = ns.Box(board, "BORDER", 1, 0.82, 0, 0.9)
            glow:SetSize(CELL + 6, CELL + 6)
            glow:SetPoint("TOPLEFT", board, "TOPLEFT", x - 3, -(y - 3))
            glow:Hide()
            local back = ns.Box(board, "BORDER", 0.02, 0.02, 0.02, 0.9)
            back:SetDrawLayer("BORDER", 1)
            back:SetSize(CELL, CELL)
            back:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
            local icon = board:CreateTexture(nil, "ARTWORK")
            icon:SetSize(CELL - 6, CELL - 6)
            icon:SetPoint("CENTER", back, "CENTER")
            g.cells[c][r] = { icon = icon, glow = glow, back = back }
        end
    end
    -- Unter den Walzen steht nur, was die Rune tut; der ganze Gewinnplan steht in den Spielregeln
    local rune = board:CreateTexture(nil, "ARTWORK")
    rune:SetSize(18, 18)
    rune:SetPoint("TOP", board, "TOP", 0, -302)
    ns.SetIcon(rune, Game.SYMBOLS[RUNE].icon)
    local info = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
    info:SetPoint("TOP", board, "TOP", 0, -323)
    info:SetWidth(W - 16)
    info:SetText(L["The rune is wild: it stands in for any symbol and joins a line together."] .. "\n"
        .. (L["3 runes anywhere: %d free spins · 4 runes: %d free spins"]):format(Game.FREE[1], Game.FREE[2]))
    local hint = ns.FontString(board, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("TOP", board, "TOP", 0, -351)
    hint:SetWidth(W - 16)
    hint:SetText(L["All payouts: “What wins?” on the right"])
    return g
end

ns.RegisterGame({
    id = "slots",
    name = L["Goblin Slots"],
    short = L["Five reels"],
    aliases = { "slots", "slot", "automat", "walzen", "goblinslots" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Bomb_04",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Five reels, three rows, five lines: the three rows and the two diagonals. Three or more of a kind from the left win; the rune is wild. Three or four runes pay 2 or 10 times your bet plus 10 or 20 free spins with a bonus symbol that fills whole reels. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    wins = Rules,
    controls = L["1/2: lower or raise your bet · 3: highest bet · Space: spin · A: auto-spin on or off · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1/2: bet · Space: spin\nA: auto-spin\n%s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
