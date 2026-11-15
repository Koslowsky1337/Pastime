-- Pastime: Goblin-Automat – fünf Walzen, drei Reihen, fünf Gewinnlinien; eigener Goldtopf,
-- gewertet wird der höchste Goldstand
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local COLS, ROWS, CELL, GAPX, GAPY = 5, 3, 62, 10, 6

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

-- Symbole: Gewicht je Feld und Auszahlung für 3, 4 und 5 gleiche von links – als Vielfaches
-- des Linieneinsatzes (ein Fünftel des Einsatzes). Schon der kleinste Treffer zahlt mehr als
-- den ganzen Einsatz. Die Münze ist Joker. Die Rune (letztes Symbol) zählt auf keiner Linie:
-- drei, vier oder fünf Runen irgendwo geben FREE Freispiele zum selben Einsatz und zahlen
-- sofort das RUNE_PAY-fache des ganzen Einsatzes.
-- In den Freispielen gilt ein Bonussymbol (eins der fünf gewöhnlichen, gewählt beim Auslösen):
-- liegt es auf drei, vier oder fünf Walzen – egal wo, auch mit Lücken –, füllt es diese Walzen
-- und zahlt zusätzlich expand (in Linieneinsätzen, für das ganze Bild).
-- Auszahlungsquote samt Freispielen rund 96 % (tests/games.lua rechnet nach).
Game.SYMBOLS = {
    { icon = "Interface\\Icons\\INV_Misc_Fish_02", w = 13, pay = { 6, 7, 9 }, expand = { 1, 3, 15 } },
    { icon = "Interface\\Icons\\INV_Misc_Bomb_04", w = 10, pay = { 6, 7, 11 }, expand = { 2, 4, 20 } },
    { icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01", w = 7, pay = { 6, 8, 14 }, expand = { 3, 8, 40 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01", w = 4, pay = { 7, 10, 25 }, expand = { 6, 20, 100 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01", w = 3, pay = { 8, 12, 50 }, expand = { 10, 40, 250 } },
    { icon = "Interface\\Icons\\INV_Misc_Coin_01", w = 3, pay = { 10, 25, 200 } },
    { icon = "Interface\\Icons\\INV_Misc_Rune_01", w = 2 },
}
local WILD, SCATTER = 6, 7
Game.STAKE = true
Game.JACKPOT = L["five rubies or coins on one line"]
Game.PLAY = L["Spin for %d gold (Space)"]
Game.FREE = { 4, 7, 10 }
Game.RUNE_PAY = { 1, 5, 20 }
local AUTO_SPINS = 20
-- Gewinnlinien: Reihe je Walze (drei Reihen, zwei Diagonalen)
Game.LINES = { { 1, 1, 1, 1, 1 }, { 2, 2, 2, 2, 2 }, { 3, 3, 3, 3, 3 }, { 1, 2, 3, 2, 1 }, { 3, 2, 1, 2, 3 } }
local STRIP = {}
for i, s in ipairs(Game.SYMBOLS) do for _ = 1, s.w do STRIP[#STRIP + 1] = i end end
local FIRST_STOP, STOP_STEP, TEASE = 0.9, 0.45, 1.1      -- die Walzen bleiben von links nach rechts stehen; TEASE: Extrazeit vor einer spannenden Walze

-- Gleiche Symbole von links (Münze zählt mit) unter den ersten upto Feldern einer Linie
function Game.Run(s, upto)
    local sym = WILD
    for i = 1, upto do
        if s[i] ~= WILD then
            if s[i] ~= SCATTER then sym = s[i] end
            break
        end
    end
    local n = 0
    for i = 1, upto do
        if s[i] == sym or s[i] == WILD then n = n + 1 else break end
    end
    return n, sym
end

-- Eine Linie (fünf Symbole von links): Auszahlung und Zahl der zählenden Felder
function Game.LinePay(s)
    local n, sym = Game.Run(s, COLS)
    if n < 3 then return 0, 0 end
    local pay = Game.SYMBOLS[sym].pay[n - 2]
    -- Münzen vorn können für sich mehr wert sein als die längere Reihe, die sie ergänzen
    -- (vier Münzen und ein Fisch: 25 statt 9): es zählt die bessere Lesart
    local coins = 0
    while s[coins + 1] == WILD do coins = coins + 1 end
    if coins >= 3 and Game.SYMBOLS[WILD].pay[coins - 2] > pay then return Game.SYMBOLS[WILD].pay[coins - 2], coins end
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
        for r = 1, ROWS do if grid[c][r] == SCATTER then runes[#runes + 1] = c * 10 + r end end
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
        for r = 1, ROWS do if grid[c][r] == SCATTER then n = n + 1; cells[c * 10 + r] = true end end
    end
    local i = math.min(n, 5) - 2
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

local function randomGrid()
    local g = {}
    for c = 1, COLS do
        g[c] = {}
        for r = 1, ROWS do g[c][r] = STRIP[math.random(#STRIP)] end
    end
    return g
end

function Game:Clear()
    self.won, self.hot = {}, nil
end

function Game:Start()
    self.grid = randomGrid()
    self.auto, self.autoT = false, nil
    local p = self:Purse()
    if (tonumber(p.gold) or 0) < ns.Gamble.MIN_BET then p.free = nil end      -- neuer Lauf: alte Freispiele verfallen
    self.free, self.stake, self.special = tonumber(p.free) or 0, tonumber(p.stake) or 0, tonumber(p.special)
    self:OpenRun()
    if self.free > 0 and self.stake > 0 then
        -- Freispiele von vorhin: gleich weiterdrehen
        self.state, self.t = "result", 1.5
        self.msg:SetText("")
        self.sub:SetText((L["Free spins left: %d"]):format(self.free))
        self:Render()
    else
        self.free, self.special = 0, nil
    end
end

function Game:Save()
    ns.Gamble.Save(self)
    local p, left = self:Purse(), (self.free or 0) > 0
    p.free, p.stake, p.special = left and self.free or nil, left and self.stake or nil, left and self.special or nil
end

-- Freispiele gehen vor: sie drehen zum Einsatz, der sie ausgelöst hat, und kosten nichts
function Game:Next()
    if self.state ~= "result" then return end
    if (self.free or 0) <= 0 then
        self.special = nil      -- Freispiele vorbei: das Bonussymbol gilt nicht mehr
        return ns.Gamble.Next(self)
    end
    self.free = self.free - 1
    self.bet = 0
    self:Save()
    self:Clear()
    self:Deal(self.stake, true)
    self.sub:SetText((L["Free spin · %d left"]):format(self.free))
end

function Game:Deal(amount, free)
    self.stake, self.isFree = amount, free
    self.final = randomGrid()
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
function Game:ToggleAuto()
    if self.state == "over" then return end
    self.auto, self.autoT, self.autoLeft = not self.auto, nil, AUTO_SPINS
    self.host:Sound("click")
    self:Render()
end

function Game:Update(dt)
    if self.auto and self.state == "bet" then
        self.autoT = (self.autoT or 0.4) - dt
        if self.autoT <= 0 then
            self.autoT = nil
            self.autoLeft = self.autoLeft - 1
            if self.autoLeft <= 0 then self.auto = false end
            self:Play()
        end
        return
    end
    if self.state ~= "spin" then
        -- Gewinnfelder blinken, solange das Ergebnis steht
        if self.state == "result" and next(self.won) then
            self.blink = (self.blink or 0) + dt
            local on = self.blink % 0.5 < 0.3
            if on ~= self.blinkOn then self.blinkOn = on; self:Render() end
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
            if flick then
                for r = 1, ROWS do self.grid[c][r] = STRIP[math.random(#STRIP)] end
            end
        end
    end
    if self.spin < self.stops[COLS] then return self:Render() end
    self.hot, self.blink, self.blinkOn = nil, 0, true
    local sum, cells = Game.Evaluate(self.final)
    -- Freispiel: das Bonussymbol füllt seine Walzen, wenn es auf mindestens dreien liegt
    local extra, filled = 0, nil
    if self.isFree and self.special then
        local reels = Game.Expand(self.final, self.special)
        if #reels >= 3 then
            filled = #reels
            extra = math.floor(self.stake * Game.SYMBOLS[self.special].expand[filled - 2] / #Game.LINES)
            for _, c in ipairs(reels) do
                self.grid[c] = { self.special, self.special, self.special }
                for r = 1, ROWS do cells[c * 10 + r] = true end
            end
        end
    end
    local award, runes, bonus = Game.Scatter(self.final)
    if award then
        self.free = (self.free or 0) + award
        self.auto = false
        self.special = self.special or math.random(WILD - 1)      -- weitere Freispiele behalten das Symbol
        for k in pairs(runes) do cells[k] = true end
    end
    -- Jackpot: fünf Rubine oder Münzen auf einer Linie (rund jede 3.400. Drehung)
    local jack = false
    for _, line in ipairs(Game.LINES) do
        local all = true
        for c = 1, COLS do
            local s = self.final[c][line[c]]
            all = all and (s == WILD or s == WILD - 1)
        end
        jack = jack or all
    end
    if jack then self:Jackpot() end
    self.won = cells
    local text = filled == COLS and L["FULL SCREEN!"] or (filled and (L["Bonus symbol on %d reels!"]):format(filled))
        or award and (L["%d free spins!"]):format(award)
        or (sum > 0 and L["Winning line!"] or (self.isFree and (L["Free spins left: %d"]):format(self.free) or L["No luck this time."]))
    self:Pay(math.floor(self.stake * sum / #Game.LINES) + (award and self.stake * bonus or 0) + extra, text, (sum > 0 or award or filled) and 2.6 or 1.2)
end

function Game:Key(k, down)
    if k == "A" then
        if down then self:ToggleAuto() end
        return true
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    for c = 1, COLS do
        for r = 1, ROWS do
            local cell = self.cells[c][r]
            ns.SetIcon(cell.icon, Game.SYMBOLS[self.grid[c][r]].icon)
            local key = c * 10 + r
            cell.glow:SetShown((self.won[key] == true and self.blinkOn ~= false) or (self.hot ~= nil and self.hot[key] == true))
        end
    end
    self:BaseRender()
    self.bonus:SetShown(self.special ~= nil)
    if self.special then ns.SetIcon(self.bonus.icon, Game.SYMBOLS[self.special].icon) end
    self.autoBtn:SetText(self.auto and (L["Auto-spin: %d left (A)"]):format(self.autoLeft) or (L["Auto-spin: %d× (A)"]):format(AUTO_SPINS))
    self.autoBtn:SetShown(self.state ~= "over")
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "slots", 266)
    g.grid, g.cells, g.won = randomGrid(), {}, {}
    g.autoBtn = ns.CreateButton(board, "", 190, function() if host:IsRunning() then ns.Safe("slots", g.ToggleAuto, g) end end)
    g.autoBtn:SetHeight(24)
    g.autoBtn:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", 8, 42)
    g.cashBtn:ClearAllPoints()
    g.cashBtn:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -8, 42)
    -- Bonussymbol der Freispiele: oben in der Mitte, nur solange es gilt
    g.bonus = CreateFrame("Frame", nil, board)
    g.bonus:SetSize(24, 24)
    g.bonus:SetPoint("TOP", board, "TOP", 14, -4)
    g.bonus:EnableMouse(true)
    g.bonus.icon = g.bonus:CreateTexture(nil, "ARTWORK")
    g.bonus.icon:SetAllPoints()
    local bonusLabel = ns.FontString(g.bonus, "GameFontNormalSmall", "RIGHT")
    bonusLabel:SetPoint("RIGHT", g.bonus, "LEFT", -4, 0)
    bonusLabel:SetText(L["Bonus:"])
    ns.SetTooltip(g.bonus, L["Bonus symbol"], L["Picked when the free spins start. If it lands on three or more reels during a free spin, it fills those reels and pays for that many of a kind – gaps do not matter. Five reels fill the whole screen."])
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
            g.cells[c][r] = { icon = icon, glow = glow }
        end
    end
    -- Gewinnplan: Symbol und darunter die Auszahlung für 3 · 4 · 5 gleiche
    local step = (W - 12) / #Game.SYMBOLS
    for i, s in ipairs(Game.SYMBOLS) do
        local icon = board:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("TOP", board, "TOPLEFT", 6 + (i - 0.5) * step, -306)
        ns.SetIcon(icon, s.icon)
        local fs = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
        fs:SetPoint("TOP", icon, "BOTTOM", 0, -2)
        local pay = s.pay or Game.FREE
        fs:SetText(("%d·%d·%d"):format(pay[1], pay[2], pay[3]))
    end
    local hint = ns.FontString(board, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("TOP", board, "TOP", 0, -347)
    hint:SetWidth(W - 16)
    hint:SetText(L["Per line: 3 · 4 · 5 of a kind from the left. The coin is wild. Runes anywhere: gold and free spins."])
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
    desc = L["Five reels, three rows, five lines: the three rows and the two diagonals. Three or more of a kind from the left win; the coin is wild. Three to five runes pay 1, 5 or 20 times your bet plus 4, 7 or 10 free spins with a bonus symbol that fills whole reels. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2: lower or raise your bet · 3: highest bet · Space: spin · A: auto-spin on or off · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1/2: bet · Space: spin\nA: auto-spin\n%s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
