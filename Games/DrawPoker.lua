-- Pastime: Goblin-Poker – fünf Karten gegen den Goblin: tauschen, dann erhöhen oder passen
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 420, 440
local CW, CH, STEP = 68, 95, 78

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

-- So tauscht der Goblin: Paare und Besseres behalten, sonst vier Karten einer Farbe,
-- sonst Bube bis Ass. Kein Blick in deine Karten.
function Game.Keep(hand)
    local cnt, suit, keep, any = {}, {}, {}, false
    for _, c in ipairs(hand) do
        cnt[c.rank] = (cnt[c.rank] or 0) + 1
        suit[c.suit] = (suit[c.suit] or 0) + 1
    end
    if Cards.Eval(hand) >= 5 then return { true, true, true, true, true } end
    for i, c in ipairs(hand) do if cnt[c.rank] >= 2 then keep[i] = true; any = true end end
    if any then return keep end
    for i, c in ipairs(hand) do if suit[c.suit] >= 4 then keep[i] = true; any = true end end
    if any then return keep end
    for i, c in ipairs(hand) do if c.rank == 1 or c.rank >= 11 then keep[i] = true end end
    return keep
end

function Game:Clear()
    self.hand, self.goblin, self.hold, self.reveal = {}, {}, {}, false
end

function Game:Start()
    self:OpenRun()
end

function Game:Deal(ante)
    self.deck = Cards.Shuffle(Cards.NewDeck())
    self.ante, self.hand, self.goblin, self.hold, self.reveal = ante, {}, {}, {}, false
    for i = 1, 5 do
        self.hand[i] = table.remove(self.deck)
        self.goblin[i] = table.remove(self.deck)
    end
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
        if not self.hold[i] then self.hand[i] = table.remove(self.deck) end
    end
    self.hold = {}
    self.state = "decide"
    self.msg:SetText(Cards.HANDS[(Cards.Eval(self.hand))])
    self.sub:SetText(L["Raise against the goblin, or fold and lose your ante?"])
    self.host:Sound("click")
    self:Render()
end

function Game:Fold()
    if self.state ~= "decide" then return end
    self:Pay(0, L["You folded."])
end

-- Erhöhen: noch einmal den Grundeinsatz (oder was vom Gold übrig ist), dann tauscht der Goblin
function Game:Raise()
    if self.state ~= "decide" then return end
    self:Spend(math.min(self.ante, self.gold))
    self.state, self.t = "goblin", 0.8
    self.msg:SetText(L["The goblin draws …"])
    self.sub:SetText("")
    self.host:Sound("click")
    self:Render()
end

function Game:Showdown()
    local keep = Game.Keep(self.goblin)
    for i = 1, 5 do
        if not keep[i] then self.goblin[i] = table.remove(self.deck) end
    end
    self.reveal = true
    local mine, myScore = Cards.Eval(self.hand)
    local his, hisScore = Cards.Eval(self.goblin)
    local text = ("%s – %s: %s"):format(Cards.HANDS[mine], L["the goblin"], Cards.HANDS[his])
    -- der Goblin behält ein Zehntel des Gewinns: sonst wäre „nur mit Paar erhöhen“ ein sicheres Geschäft
    self:Pay(myScore > hisScore and self.bet + math.floor(self.bet * 0.9) or (myScore == hisScore and self.bet or 0), text, false)
end

function Game:Update(dt)
    if self.state == "goblin" then
        self.t = self.t - dt
        if self.t <= 0 then self:Showdown() end
    else
        self:Tick(dt)
    end
end

function Game:Key(k, down)
    local act
    if self.state == "hold" then
        local n = tonumber(k)
        if n and n >= 1 and n <= 5 then act = function() self:Toggle(n) end
        elseif k == "SPACE" or k == "ENTER" then act = function() self:Swap() end end
    elseif self.state == "decide" then
        if k == "1" or k == "SPACE" or k == "ENTER" then act = function() self:Raise() end
        elseif k == "2" then act = function() self:Fold() end end
    end
    if act then
        if down then act() end
        return true
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    for i = 1, 5 do
        self.cards[i]:SetCard(self.hand[i], true)
        self.cards[i]:SetSelected(self.hold[i])
        self.holdText[i]:SetShown(self.hold[i] and self.state == "hold")
        self.goblinCards[i]:SetCard(self.goblin[i], self.reveal)
    end
    self.swapBtn:SetShown(self.state == "hold")
    self.raiseBtn:SetShown(self.state == "decide")
    self.raiseBtn:SetText((L["Raise %d (1)"]):format(math.min(self.ante or 0, self.gold or 0)))
    self.foldBtn:SetShown(self.state == "decide")
    self:BaseRender()
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "drawpoker", 172)
    g.cards, g.goblinCards, g.holdText = {}, {}, {}
    g:Clear()
    local name = ns.FontString(board, "GameFontNormal")
    name:SetPoint("TOPLEFT", board, "TOPLEFT", 14, -30)
    name:SetText(L["The goblin"])
    local x0 = (W - 4 * STEP - CW) / 2
    for i = 1, 5 do
        local gc = Cards.Create(board, 56, 78)
        gc:SetPoint("TOPLEFT", board, "TOPLEFT", 70 + (i - 1) * 60, -50)
        gc:Hide()
        g.goblinCards[i] = gc
        local c = Cards.Create(board, CW, CH)
        c:SetPoint("TOPLEFT", board, "TOPLEFT", x0 + (i - 1) * STEP, -262)
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
    g.raiseBtn = g:Button("", 190, 14, function() g:Raise() end)
    g.foldBtn = g:Button(L["Fold (2)"], 190, 216, function() g:Fold() end)
    return g
end

ns.RegisterGame({
    id = "drawpoker",
    name = L["Goblin Poker"],
    short = L["Five cards against the goblin"],
    aliases = { "poker", "goblinpoker", "drawpoker", "tauschpoker" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Maelstrom_01",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["You and the goblin each get five cards. Hold what you like and swap the rest once. Then decide: raise by your ante and see his hand, or fold and lose only the ante. The goblin swaps too, and the better hand wins – he keeps a tenth of what you win. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: ante of 10, ¼ or ½ of your gold · 1–5 or click a card: hold · Space: draw · then 1: raise · 2: fold · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–5: hold · Space: draw\n1: raise · 2: fold\n%s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
