-- Pastime: Tauschpoker – fünf Karten, einmal tauschen, Auszahlung nach Blatt
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 420, 440
local CW, CH, STEP = 68, 95, 78

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

-- Auszahlung einschließlich Einsatz, als Vielfaches des Einsatzes (von oben nach unten angezeigt)
Game.PAYS = {
    { L["Royal Flush"], 250 }, { L["Straight Flush"], 50 }, { L["Four of a Kind"], 25 }, { L["Full House"], 9 },
    { L["Flush"], 6 }, { L["Straight"], 4 }, { L["Three of a Kind"], 3 }, { L["Two Pair"], 2 }, { L["Jacks or better"], 1 },
}
local ROW = { [9] = 2, [8] = 3, [7] = 4, [6] = 5, [5] = 6, [4] = 7, [3] = 8 }

-- Zeile im Gewinnplan für ein Blatt (nil: nichts)
function Game.Row(hand)
    local cat, _, t = Cards.Eval(hand)
    if cat == 9 and t[1] == 14 then return 1 end
    if cat == 2 then return t[1] >= 11 and 9 or nil end
    return ROW[cat]
end

function Game:Draw()
    return table.remove(self.deck)
end

function Game:Clear()
    self.hand, self.hold, self.row = {}, {}, nil
end

function Game:Start()
    self:OpenRun()
end

function Game:Deal()
    self.deck = Cards.Shuffle(Cards.NewDeck())
    self.hand, self.hold, self.row = {}, {}, nil
    for i = 1, 5 do self.hand[i] = self:Draw() end
    self.state = "hold"
    self.msg:SetText(L["Hold the cards you want to keep."])
    self.sub:SetText("")
    self:Render()
end

function Game:Toggle(i)
    if self.state ~= "hold" then return end
    self.hold[i] = not self.hold[i]
    self.host:Sound("click")
    self:Render()
end

function Game:Swap()
    if self.state ~= "hold" then return end
    for i = 1, 5 do
        if not self.hold[i] then self.hand[i] = self:Draw() end
    end
    self.row = Game.Row(self.hand)
    local p = self.row and Game.PAYS[self.row]
    self:Pay(p and p[2] * self.bet or 0, p and p[1] or L["Nothing – the goblin keeps your bet."], 2.2)
end

function Game:Update(dt)
    self:Tick(dt)
end

function Game:Key(k, down)
    if self.state == "hold" then
        local n = tonumber(k)
        if n and n >= 1 and n <= 5 then
            if down then self:Toggle(n) end
            return true
        elseif k == "SPACE" or k == "ENTER" then
            if down then self:Swap() end
            return true
        end
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    for i, f in ipairs(self.cards) do
        f:SetCard(self.hand[i], true)
        f:SetSelected(self.hold[i])
        self.holdText[i]:SetShown(self.hold[i] and self.state == "hold")
    end
    local row = self.state == "hold" and Game.Row(self.hand) or self.row
    for i, line in ipairs(self.payLines) do
        local c = i == row and 1 or 0.75
        line.l:SetTextColor(c, i == row and 0.82 or c, i == row and 0 or c)
        line.r:SetTextColor(c, i == row and 0.82 or c, i == row and 0 or c)
    end
    self.swapBtn:SetShown(self.state == "hold")
    self:BaseRender()
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "drawpoker", 322)
    g.cards, g.holdText, g.payLines, g.hand, g.hold = {}, {}, {}, {}, {}
    for i, p in ipairs(Game.PAYS) do
        local l = ns.FontString(board, "GameFontHighlightSmall", "LEFT")
        l:SetPoint("TOPLEFT", board, "TOPLEFT", 110, -28 - (i - 1) * 14)
        l:SetText(p[1])
        local r = ns.FontString(board, "GameFontHighlightSmall", "RIGHT")
        r:SetPoint("TOPRIGHT", board, "TOPRIGHT", -110, -28 - (i - 1) * 14)
        r:SetText(p[2] .. "×")
        g.payLines[i] = { l = l, r = r }
    end
    local x0 = (W - 4 * STEP - CW) / 2
    for i = 1, 5 do
        local c = Cards.Create(board, CW, CH)
        c:SetPoint("TOPLEFT", board, "TOPLEFT", x0 + (i - 1) * STEP, -182)
        c:SetScript("OnClick", function() if host:IsRunning() then ns.Safe("drawpoker", g.Toggle, g, i) end end)
        c:Hide()
        g.cards[i] = c
        local fs = ns.FontString(board, "GameFontNormalSmall", "CENTER")
        fs:SetPoint("BOTTOM", c, "TOP", 0, 3)
        fs:SetText(L["HOLD"])
        fs:Hide()
        g.holdText[i] = fs
    end
    g.swapBtn = g:Button(L["Draw (Space)"], 180, 120, function() g:Swap() end)
    return g
end

ns.RegisterGame({
    id = "drawpoker",
    name = L["Draw Poker"],
    short = L["Five cards, one draw"],
    aliases = { "poker", "drawpoker", "tauschpoker", "draw" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Maelstrom_01",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["You get five cards. Hold the ones you like and swap the rest once – the better the hand, the higher the payout, starting with a pair of jacks. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: bet 10, ¼ or ½ of your gold · 1–5 or click a card: hold · Space/Enter: draw · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–3: bet · 1–5: hold\nSpace: draw · %s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
