-- Pastime: Goblin-Roulette – Chips selbst auf den Tisch legen (Zahlen, Dutzende, einfache Chancen), dann rollt die Kugel
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local CELL_W, CELL_H, X0, Y0 = 28, 30, 28, 34

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

local RED = {}
for _, n in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do RED[n] = true end
Game.RED = RED

-- Felder: Zahl 0–36 oder eine der Außenwetten. pays = Auszahlung einschließlich Einsatz
local OUTSIDE = {
    d1 = { pays = 3, hit = function(n) return n >= 1 and n <= 12 end, label = "1–12" },
    d2 = { pays = 3, hit = function(n) return n >= 13 and n <= 24 end, label = "13–24" },
    d3 = { pays = 3, hit = function(n) return n >= 25 end, label = "25–36" },
    low = { pays = 2, hit = function(n) return n >= 1 and n <= 18 end, label = "1–18" },
    even = { pays = 2, hit = function(n) return n > 0 and n % 2 == 0 end, label = L["Even"] },
    red = { pays = 2, hit = function(n) return RED[n] == true end, label = L["Red"] },
    black = { pays = 2, hit = function(n) return n > 0 and not RED[n] end, label = L["Black"] },
    odd = { pays = 2, hit = function(n) return n % 2 == 1 end, label = L["Odd"] },
    high = { pays = 2, hit = function(n) return n >= 19 end, label = "19–36" },
}

-- Der Kessel: Reihenfolge der Fächer wie am echten Rad; SLOT[Zahl] = Platz im Ring (ab 0)
local WHEEL = { 0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26 }
local SLOT = {}
for i, n in ipairs(WHEEL) do SLOT[n] = i - 1 end
Game.WHEEL = WHEEL
local SPIN_TIME = 4.5
local WHEEL_X, WHEEL_Y, WHEEL_R, BALL_R = 117, 302, 72, 57
local HISTORY = 15
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"      -- weiße Kreisscheibe, wird eingefärbt

-- Auszahlung eines Chips auf spot, wenn n fällt (0: verloren)
function Game.Payout(spot, n, amount)
    if type(spot) == "number" then return spot == n and amount * 36 or 0 end
    local o = OUTSIDE[spot]
    return o.hit(n) and amount * o.pays or 0
end

function Game:Clear()
    self.bets = {}      -- die letzte Zahl bleibt stehen, die Kugel im Fach liegen
end

function Game:Start()
    self.chip, self.last, self.pos, self.number, self.history = 1, nil, 0, nil, {}
    self:OpenRun()
end

-- 1/2/3 wählen hier die Chipgröße; gesetzt wird mit einem Klick auf den Tisch
function Game:PlaceBet(i)
    if self.state ~= "bet" then return end
    self.chip = i
    self.host:Sound("click")
    self:Render()
end

function Game:Hint()
    self.msg:SetText(L["Place your chips!"])
    self.sub:SetText(self.bet > 0 and (L["%d gold on the table – Space spins."]):format(self.bet)
        or (self.last and L["Click the table to bet – Space repeats your last bets."] or L["Click the table to bet. Right-click takes a chip back."]))
end

function Game:Put(spot, amount)
    amount = amount or self.Bets(self.gold)[self.chip]
    if self.state ~= "bet" or amount > self.gold then return false end
    self.bets[spot] = (self.bets[spot] or 0) + amount
    self:Spend(amount)
    return true
end

function Game:Click(spot, button)
    if self.state ~= "bet" then return end
    if button == "RightButton" then
        local a = self.bets[spot]
        if not a then return end
        self.bets[spot] = nil
        self:Spend(-a)
    elseif not self:Put(spot) then
        return
    end
    self.host:Sound("click")
    self:Hint()
    self:Render()
end

function Game:Spin()
    if self.state ~= "bet" then return end
    if self.bet == 0 then
        -- nichts gesetzt: die Chips der letzten Runde noch einmal legen, soweit das Gold reicht
        for spot, amount in pairs(self.last or {}) do self:Put(spot, amount) end
        if self.bet == 0 then return end
    end
    self.last = {}
    for spot, amount in pairs(self.bets) do self.last[spot] = amount end
    self.final = math.random(0, 36)
    self.from = self.pos % 37 + math.random(0, 36)      -- die Kugel wird irgendwo eingeworfen
    self.state, self.spin, self.pos = "spin", 0, self.from
    self.number = WHEEL[math.floor(self.pos + 0.5) % 37 + 1]
    self.sub:SetText("")
    self.host:Sound("click")
    self:Render()
end

function Game:Update(dt)
    if self.state ~= "spin" then return self:Tick(dt) end
    self.spin = self.spin + dt
    -- Die Kugel läuft drei Runden und weiter bis zum Gewinnfach und wird dabei immer langsamer
    local from = self.from
    local dist = 37 * 3 + (SLOT[self.final] - from) % 37
    local left = math.max(0, 1 - self.spin / SPIN_TIME)
    self.pos = from + dist * (1 - left ^ 3)
    local n = WHEEL[math.floor(self.pos + 0.5) % 37 + 1]
    if self.spin < SPIN_TIME then
        if n ~= self.number and left < 0.45 then self.host:Sound("click") end      -- die letzten Fächer klackern
        self.number = n
        return self:Render()
    end
    local win = 0
    n = self.final
    self.number, self.pos = n, SLOT[n]
    for spot, amount in pairs(self.bets) do win = win + Game.Payout(spot, n, amount) end
    table.insert(self.history, 1, n)
    self.history[HISTORY + 1] = nil
    self:Pay(win, win > 0 and L["The ball is kind to you."] or L["The goblin rakes in the chips."], 2.2)
end

function Game:Key(k, down)
    if self.state == "bet" and (k == "SPACE" or k == "ENTER") then
        if down then self:Spin() end
        return true
    end
    if self.state == "bet" and k == ns.KEYS.cash and self.bet > 0 then return true end      -- erst Chips zurücknehmen
    return self:BaseKey(k, down)
end

local function colorOf(n) return n == 0 and "40ff40" or (RED[n] and "ff5040" or "d0d0d0") end

function Game:Render()
    for spot, cell in pairs(self.cells) do
        local a = self.bets[spot]
        cell.chip:SetText(a and tostring(a) or "")
        cell.mark:SetShown(a ~= nil)
        cell.hit:SetShown(self.state == "result" and self.number ~= nil and Game.Payout(spot, self.number, 1) > 0)
    end
    local n = self.number
    self.numText:SetText(n and ("|cff%s%d|r"):format(colorOf(n), n) or "")
    local a = (self.pos or 0) / 37 * 2 * math.pi
    self.ball:ClearAllPoints()
    self.ball:SetPoint("CENTER", self.board, "TOPLEFT", WHEEL_X + math.sin(a) * BALL_R, -(WHEEL_Y - math.cos(a) * BALL_R))
    self.ball:SetShown(n ~= nil)
    for i, h in ipairs(self.hist) do
        local v = self.history[i]
        h:SetText(v and ("|cff%s%d|r"):format(colorOf(v), v) or "")
    end
    if self.state == "spin" then self.msg:SetText("") end
    self:BaseRender()
    local betting = self.state == "bet"
    local amounts = self.Bets(self.gold or 0)
    for i, b in ipairs(self.betButtons) do
        b:SetText((i == self.chip and "> " or "") .. (L["Chip %d (%d)"]):format(amounts[i], i))
    end
    self.spinBtn:SetShown(betting)
    self.cashBtn:SetEnabled(betting and self.bet == 0 and (self.gold or 0) > self.START_GOLD)
end

function Game:Betting()
    ns.Gamble.Betting(self)
    self:Hint()
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "roulette", 266)
    g:Clear()
    g.cells, g.chip, g.pos = {}, 1, 0
    -- Kessel links: 37 Fächer im Ring (die Null oben), die gefallene Zahl in der Mitte, Meldungen rechts daneben
    local function disc(sub, size, r, gr, b)
        local t = board:CreateTexture(nil, "BORDER", nil, sub)
        t:SetTexture(ROUND)
        t:SetVertexColor(r, gr, b)
        t:SetSize(size, size)
        return t
    end
    -- Holzrand, Fächerring, Laufbahn der Kugel, Nabe
    for sub, d in ipairs({ { 170, 0.42, 0.24, 0.09 }, { 160, 0.72, 0.58, 0.25 }, { 130, 0.16, 0.09, 0.04 }, { 94, 0.3, 0.17, 0.07 } }) do
        local t = disc(sub - 3, d[1], d[2], d[3], d[4])
        t:SetPoint("CENTER", board, "TOPLEFT", WHEEL_X, -WHEEL_Y)
    end
    for i, n in ipairs(WHEEL) do
        local a = (i - 1) / 37 * 2 * math.pi
        local red = RED[n]
        local pocket = disc(2, 12, n == 0 and 0.1 or (red and 0.8 or 0.03), n == 0 and 0.7 or (red and 0.1 or 0.03), red and 0.08 or (n == 0 and 0.2 or 0.03))
        pocket:SetPoint("CENTER", board, "TOPLEFT", WHEEL_X + math.sin(a) * WHEEL_R, -(WHEEL_Y - math.cos(a) * WHEEL_R))
    end
    g.ball = disc(4, 10, 1, 1, 1)
    g.ball:Hide()
    g.numText = ns.FontString(board, "GameFontNormalHuge", "CENTER")
    g.numText:SetPoint("CENTER", board, "TOPLEFT", WHEEL_X, -WHEEL_Y)
    g.msg:ClearAllPoints()
    if g.numText.SetTextScale then g.numText:SetTextScale(1.4) end
    g.msg:SetPoint("CENTER", board, "TOPLEFT", 311, -236)
    g.sub:SetWidth(196)
    -- Die letzten Zahlen links neben dem Tisch: oben die neueste. Nur farbige Ziffern unter einer
    -- Überschrift, keine Kästchen – sonst sehen sie aus wie Felder zum Setzen.
    g.hist, g.history = {}, {}
    local head = ns.FontString(board, "GameFontDisableSmall", "LEFT")
    head:SetPoint("TOPLEFT", board, "TOPLEFT", 4, -(Y0 - 14))
    head:SetText(L["Last"])
    for i = 1, HISTORY do
        local fs = ns.FontString(board, i == 1 and "GameFontNormal" or "GameFontHighlightSmall", "CENTER")
        fs:SetPoint("CENTER", board, "TOPLEFT", 14, -(Y0 + 8 + (i - 1) * 16))
        g.hist[i] = fs
    end
    local function cell(spot, x, y, w, h, r, gr, b, text)
        local btn = CreateFrame("Button", nil, board)
        btn:SetSize(w - 2, h - 2)
        btn:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local bg = ns.Box(btn, "BACKGROUND", r, gr, b, 1)
        bg:SetAllPoints()
        btn.hit = ns.Box(btn, "BORDER", 1, 0.82, 0, 0.55)
        btn.hit:SetAllPoints()
        btn.hit:Hide()
        local fs = ns.FontString(btn, "GameFontHighlightSmall", "CENTER")
        fs:SetPoint("TOP", 0, -2)
        fs:SetText(text)
        btn.mark = ns.Box(btn, "ARTWORK", 0.95, 0.75, 0.1, 1)
        btn.mark:SetSize(math.min(w - 6, 24), 11)
        btn.mark:SetPoint("BOTTOM", 0, 2)
        btn.mark:Hide()
        btn.chip = ns.FontString(btn, "GameFontNormalSmall", "CENTER")
        btn.chip:SetPoint("CENTER", btn.mark, "CENTER")
        btn.chip:SetTextColor(0, 0, 0)
        btn:SetScript("OnClick", function(_, button) if host:IsRunning() then ns.Safe("roulette", g.Click, g, spot, button) end end)
        g.cells[spot] = btn
    end
    cell(0, X0, Y0, CELL_W, CELL_H * 3, 0.05, 0.4, 0.12, "0")
    for n = 1, 36 do
        local col, row = math.floor((n - 1) / 3), 2 - (n - 1) % 3      -- 3, 6, 9 … in der obersten Reihe
        local red = RED[n]
        cell(n, X0 + CELL_W * (col + 1), Y0 + row * CELL_H, CELL_W, CELL_H, red and 0.55 or 0.08, red and 0.08 or 0.08, red and 0.06 or 0.09, tostring(n))
    end
    for i, spot in ipairs({ "d1", "d2", "d3" }) do
        cell(spot, X0 + CELL_W + (i - 1) * CELL_W * 4, Y0 + CELL_H * 3 + 2, CELL_W * 4, CELL_H, 0.1, 0.24, 0.12, OUTSIDE[spot].label .. "  2:1")
    end
    for i, spot in ipairs({ "low", "even", "red", "black", "odd", "high" }) do
        local r, gr, b = 0.1, 0.24, 0.12
        if spot == "red" then r, gr, b = 0.55, 0.08, 0.06 elseif spot == "black" then r, gr, b = 0.08, 0.08, 0.09 end
        cell(spot, X0 + CELL_W + (i - 1) * CELL_W * 2, Y0 + CELL_H * 4 + 4, CELL_W * 2, CELL_H, r, gr, b, OUTSIDE[spot].label)
    end
    local hint = ns.FontString(board, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("TOP", board, "TOP", 0, -(Y0 + CELL_H * 5 + 10))
    hint:SetText(L["A number pays 35:1, a dozen 2:1, the bottom row 1:1."])
    g.spinBtn = ns.CreateButton(board, L["Spin (Space)"], 170, function() if host:IsRunning() then ns.Safe("roulette", g.Spin, g) end end)
    g.spinBtn:SetHeight(24)
    g.spinBtn:SetPoint("TOP", board, "TOPLEFT", 311, -326)
    g.cashBtn:ClearAllPoints()
    g.cashBtn:SetPoint("TOP", g.spinBtn, "BOTTOM", 0, -8)
    return g
end

ns.RegisterGame({
    id = "roulette",
    name = L["Goblin Roulette"],
    short = L["Place your chips"],
    aliases = { "roulette", "roulett", "kugel" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_01",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Put your chips where you like: on single numbers, on a dozen, or on red, black, even, odd, low or high – as many bets as you want. Then the ball rolls. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: chip of 10, ¼ or ½ of your gold · click: place a chip · right-click: take it back · Space: spin (or repeat your last bets) · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–3: chip size\nClick: bet · Space: spin\n%s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
