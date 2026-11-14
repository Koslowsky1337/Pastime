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
-- den ganzen Einsatz. Die Münze ist Joker. Auszahlungsquote rund 97 % (tests/games.lua rechnet nach).
Game.SYMBOLS = {
    { icon = "Interface\\Icons\\INV_Misc_Fish_02", w = 8, pay = { 6, 10, 25 } },
    { icon = "Interface\\Icons\\INV_Misc_Bomb_04", w = 7, pay = { 7, 12, 30 } },
    { icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01", w = 6, pay = { 8, 15, 40 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01", w = 5, pay = { 10, 20, 60 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01", w = 3, pay = { 12, 35, 150 } },
    { icon = "Interface\\Icons\\INV_Misc_Coin_01", w = 2, pay = { 25, 100, 500 } },
}
local WILD = #Game.SYMBOLS
-- Gewinnlinien: Reihe je Walze (drei Reihen, zwei Diagonalen)
Game.LINES = { { 1, 1, 1, 1, 1 }, { 2, 2, 2, 2, 2 }, { 3, 3, 3, 3, 3 }, { 1, 2, 3, 2, 1 }, { 3, 2, 1, 2, 3 } }
local STRIP = {}
for i, s in ipairs(Game.SYMBOLS) do for _ = 1, s.w do STRIP[#STRIP + 1] = i end end
local FIRST_STOP, STOP_STEP = 0.5, 0.25      -- die Walzen bleiben von links nach rechts stehen

-- Eine Linie (fünf Symbole von links): Auszahlung und Zahl der zählenden Felder
function Game.LinePay(s)
    local sym = WILD
    for i = 1, COLS do if s[i] ~= WILD then sym = s[i]; break end end
    local n = 0
    for i = 1, COLS do
        if s[i] == sym or s[i] == WILD then n = n + 1 else break end
    end
    if n < 3 then return 0, 0 end
    return Game.SYMBOLS[sym].pay[n - 2], n
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
    self.won = {}
end

function Game:Start()
    self.grid = randomGrid()
    self:OpenRun()
end

function Game:Deal()
    self.final = randomGrid()
    self.state, self.spin, self.flick, self.won = "spin", 0, 0, {}
    self.msg:SetText("")
    self.sub:SetText("")
    self:Render()
end

function Game:Update(dt)
    if self.state ~= "spin" then return self:Tick(dt) end
    local before = self.spin
    self.spin = self.spin + dt
    self.flick = self.flick + dt
    local flick = self.flick >= 0.07
    if flick then self.flick = 0 end
    for c = 1, COLS do
        local stop = FIRST_STOP + (c - 1) * STOP_STEP
        if self.spin >= stop then
            self.grid[c] = self.final[c]
            if before < stop then self.host:Sound("click") end
        elseif flick then
            for r = 1, ROWS do self.grid[c][r] = STRIP[math.random(#STRIP)] end
        end
    end
    if self.spin < FIRST_STOP + (COLS - 1) * STOP_STEP then return self:Render() end
    local sum, cells = Game.Evaluate(self.final)
    self.won = cells
    self:Pay(math.floor(self.bet * sum / #Game.LINES), sum > 0 and L["Winning line!"] or L["No luck this time."], sum > 0 and 2 or 1)
end

function Game:Key(k, down)
    return self:BaseKey(k, down)
end

function Game:Render()
    for c = 1, COLS do
        for r = 1, ROWS do
            local cell = self.cells[c][r]
            ns.SetIcon(cell.icon, Game.SYMBOLS[self.grid[c][r]].icon)
            cell.glow:SetShown(self.won[c * 10 + r] == true)
        end
    end
    self:BaseRender()
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "slots", 266)
    g.grid, g.cells, g.won = randomGrid(), {}, {}
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
        fs:SetText(("%d·%d·%d"):format(s.pay[1], s.pay[2], s.pay[3]))
    end
    local hint = ns.FontString(board, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("TOP", board, "TOP", 0, -347)
    hint:SetWidth(W - 16)
    hint:SetText(L["Per line: 3 · 4 · 5 of a kind from the left. The coin is wild."])
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
    desc = L["Five reels, three rows, five lines: the three rows and the two diagonals. Three or more of a kind in a row from the left win, and the coin stands in for any symbol. Every win pays more than you bet. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: bet 10, ¼ or ½ of your gold and spin · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–3: bet and spin\n%s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
