-- Pastime: Goblin-Automat – drei Walzen, eigener Goldtopf, gewertet wird der höchste Goldstand
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 440
local SIZE, GAP = 96, 20

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

-- Symbole: Gewicht auf jeder Walze und Auszahlung für drei gleiche (Vielfaches des Einsatzes).
-- Zwei gleiche geben den Einsatz zurück. Auszahlungsquote rund 97 % (tests/games.lua rechnet nach).
Game.SYMBOLS = {
    { icon = "Interface\\Icons\\INV_Misc_Fish_02", w = 6, pay = 5 },
    { icon = "Interface\\Icons\\INV_Misc_Bomb_04", w = 5, pay = 8 },
    { icon = "Interface\\Icons\\INV_Misc_Head_Murloc_01", w = 4, pay = 15 },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01", w = 3, pay = 30 },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01", w = 2, pay = 60 },
    { icon = "Interface\\Icons\\INV_Misc_Coin_01", w = 1, pay = 250 },
}
local STRIP = {}
for i, s in ipairs(Game.SYMBOLS) do for _ = 1, s.w do STRIP[#STRIP + 1] = i end end
local STOP = { 0.5, 0.9, 1.3 }      -- Sekunden, nach denen die Walzen stehen bleiben

-- Auszahlung einschließlich Einsatz, als Vielfaches des Einsatzes
function Game.Payout(a, b, c)
    if a == b and b == c then return Game.SYMBOLS[a].pay end
    if a == b or b == c or a == c then return 1 end
    return 0
end

function Game:Start()
    self.reels = { 6, 6, 6 }
    self:OpenRun()
end

function Game:Deal()
    self.final = { STRIP[math.random(#STRIP)], STRIP[math.random(#STRIP)], STRIP[math.random(#STRIP)] }
    self.state, self.spin, self.flick = "spin", 0, 0
    self.msg:SetText("")
    self.sub:SetText("")
    self:Render()
end

function Game:Update(dt)
    if self.state == "spin" then
        local before = self.spin
        self.spin = self.spin + dt
        self.flick = self.flick + dt
        for i = 1, 3 do
            if self.spin >= STOP[i] then
                self.reels[i] = self.final[i]
                if before < STOP[i] then self.host:Sound("click") end
            elseif self.flick >= 0.07 then
                self.reels[i] = STRIP[math.random(#STRIP)]
            end
        end
        if self.flick >= 0.07 then self.flick = 0 end
        if self.spin >= STOP[3] then
            local f = self.final
            local mult = Game.Payout(f[1], f[2], f[3])
            self:Pay(mult * self.bet, mult > 1 and (L["Three of a kind – pays %d×!"]):format(mult)
                or (mult == 1 and L["Two of a kind – bet returned."] or L["No luck this time."]), 1.2)
        else
            self:Render()
        end
    else
        self:Tick(dt)
    end
end

function Game:Key(k, down)
    return self:BaseKey(k, down)
end

function Game:Render()
    for i = 1, 3 do ns.SetIcon(self.reelTex[i], Game.SYMBOLS[self.reels[i]].icon) end
    self:BaseRender()
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "slots", 222)
    g.reels, g.reelTex = { 6, 6, 6 }, {}
    local x0 = (W - 3 * SIZE - 2 * GAP) / 2
    for i = 1, 3 do
        local frame = ns.Box(board, "BORDER", 0.02, 0.02, 0.02, 0.9)
        frame:SetSize(SIZE + 8, SIZE + 8)
        frame:SetPoint("TOPLEFT", board, "TOPLEFT", x0 + (i - 1) * (SIZE + GAP) - 4, -56)
        local t = board:CreateTexture(nil, "ARTWORK")
        t:SetSize(SIZE, SIZE)
        t:SetPoint("CENTER", frame, "CENTER")
        g.reelTex[i] = t
    end
    -- Gewinnplan: Symbol dreimal und die Auszahlung darunter
    local step = (W - 20) / #Game.SYMBOLS
    for i, s in ipairs(Game.SYMBOLS) do
        local icon = board:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("TOP", board, "TOPLEFT", 10 + (i - 0.5) * step, -286)
        ns.SetIcon(icon, s.icon)
        local fs = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
        fs:SetPoint("TOP", icon, "BOTTOM", 0, -3)
        fs:SetText(("3× = %d×"):format(s.pay))
    end
    local hint = ns.FontString(board, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("TOP", board, "TOP", 0, -340)
    hint:SetText(L["Two of a kind return your bet."])
    return g
end

ns.RegisterGame({
    id = "slots",
    name = L["Goblin Slots"],
    short = L["Three reels"],
    aliases = { "slots", "slot", "automat", "walzen", "goblinslots" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Bomb_04",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Pick a bet and the three reels spin. Three of a kind pay from 5 to 250 times your bet, two of a kind return it. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: bet 10, ¼ or ½ of your gold and spin · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–3: bet and spin\n%s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
