-- Pastime: Goblin-Baccarat – auf Spieler, Bank oder Unentschieden setzen; gezogen wird nach festen Regeln
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 420, 440
local CW, CH, STEP = 60, 84, 46

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

Game.SIDES = { L["Player"], L["Banker"], L["Tie"] }

function Game.Total(hand)
    local t = 0
    for _, c in ipairs(hand) do t = t + (c.rank >= 10 and 0 or c.rank) end
    return t % 10
end

-- Dritte Karten nach den üblichen Regeln; draw() liefert die nächste Karte
function Game.Complete(player, banker, draw)
    local p, b = Game.Total(player), Game.Total(banker)
    if p >= 8 or b >= 8 then return end      -- „Natural“: beide bleiben stehen
    local third
    if p <= 5 then
        player[3] = draw()
        third = player[3].rank >= 10 and 0 or player[3].rank
    end
    local hit
    if not third then hit = b <= 5
    elseif b <= 2 then hit = true
    elseif b == 3 then hit = third ~= 8
    elseif b == 4 then hit = third >= 2 and third <= 7
    elseif b == 5 then hit = third >= 4 and third <= 7
    elseif b == 6 then hit = third == 6 or third == 7
    else hit = false end
    if hit then banker[3] = draw() end
end

-- Auszahlung einschließlich Einsatz: Spieler 1:1, Bank 0,95:1, Unentschieden 8:1;
-- bei Unentschieden gibt es den Einsatz auf Spieler oder Bank zurück
function Game.Payout(side, p, b, bet)
    local winner = p > b and 1 or (b > p and 2 or 3)
    if side == winner then
        return side == 1 and bet * 2 or (side == 2 and math.floor(bet * 1.95) or bet * 9)
    end
    return winner == 3 and bet or 0, winner
end

function Game:Clear()
    self.player, self.banker, self.shown, self.side = {}, {}, 0, nil
end

function Game:Start()
    self:OpenRun()
end

function Game:Deal()
    self.state = "side"
    self.msg:SetText(L["Who wins?"])
    self.sub:SetText(L["Player pays 1:1 · Banker 0.95:1 · Tie 8:1"])
    self:Render()
end

function Game:Choose(side)
    if self.state ~= "side" then return end
    local deck = Cards.Shuffle(Cards.NewDeck())
    local function draw() return table.remove(deck) end
    self.side = side
    self.player, self.banker = { draw(), draw() }, { draw(), draw() }
    Game.Complete(self.player, self.banker, draw)
    self.state, self.shown, self.t = "deal", 0, 0.3
    self.msg:SetText((L["Your bet: %s"]):format(Game.SIDES[side]))
    self.sub:SetText("")
    self.host:Sound("click")
    self:Render()
end

function Game:Update(dt)
    if self.state == "deal" then
        self.t = self.t - dt
        if self.t > 0 then return end
        local total = #self.player + #self.banker
        if self.shown < total then
            self.shown, self.t = self.shown + 1, 0.4
            self.host:Sound("click")
            return self:Render()
        end
        local p, b = Game.Total(self.player), Game.Total(self.banker)
        local win = Game.Payout(self.side, p, b, self.bet)
        local who = p > b and L["Player wins"] or (b > p and L["Banker wins"] or L["Tie"])
        self:Pay(win, ("%s – %d : %d"):format(who, p, b), 2.4)
    else
        self:Tick(dt)
    end
end

function Game:Key(k, down)
    if self.state == "side" and (k == "1" or k == "2" or k == "3") then
        if down then self:Choose(tonumber(k)) end
        return true
    end
    return self:BaseKey(k, down)
end

-- Aufdecken reihum: Spieler, Bank, Spieler, Bank, dann die dritten Karten
local ORDER = { { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 } }
function Game:Visible()
    local n = { 0, 0 }
    local left = self.state == "deal" and self.shown or 6
    for _, o in ipairs(ORDER) do
        if left > 0 then n[o[1]] = o[2]; left = left - 1 end
    end
    if left > 0 and self.player[3] then n[1] = 3; left = left - 1 end
    if left > 0 and self.banker[3] then n[2] = 3 end
    return n[1], n[2]
end

function Game:Render()
    local np, nb = self:Visible()
    local function part(hand, n)
        local out = {}
        for i = 1, math.min(n, #hand) do out[i] = hand[i] end
        return out
    end
    local vp, vb = part(self.player, np), part(self.banker, nb)
    for i = 1, 3 do
        self.playerCards[i]:SetCard(vp[i], true)
        self.bankerCards[i]:SetCard(vb[i], true)
    end
    self.playerTotal:SetText(#vp > 0 and tostring(Game.Total(vp)) or "")
    self.bankerTotal:SetText(#vb > 0 and tostring(Game.Total(vb)) or "")
    for i, b in ipairs(self.sideButtons) do b:SetShown(self.state == "side") end
    self:BaseRender()
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "baccarat", 218)
    g.player, g.banker, g.shown = {}, {}, 0
    g.playerCards, g.bankerCards, g.sideButtons = {}, {}, {}
    local function side(text, x)
        local fs = ns.FontString(board, "GameFontNormal")
        fs:SetPoint("TOPLEFT", board, "TOPLEFT", x, -52)
        fs:SetText(text)
        local total = ns.FontString(board, "GameFontHighlightLarge", "RIGHT")
        total:SetPoint("TOPRIGHT", board, "TOPLEFT", x + 2 * STEP + CW, -50)
        local cards = {}
        for i = 1, 3 do
            cards[i] = Cards.Create(board, CW, CH)
            cards[i]:SetFrameLevel(board:GetFrameLevel() + i)
            cards[i]:SetPoint("TOPLEFT", board, "TOPLEFT", x + (i - 1) * STEP, -74)
            cards[i]:Hide()
        end
        return cards, total
    end
    g.playerCards, g.playerTotal = side(Game.SIDES[1], 30)
    g.bankerCards, g.bankerTotal = side(Game.SIDES[2], 238)
    for i = 1, 3 do
        g.sideButtons[i] = g:Button(("%s (%d)"):format(Game.SIDES[i], i), 126, 8 + (i - 1) * 136, function() g:Choose(i) end)
    end
    return g
end

ns.RegisterGame({
    id = "baccarat",
    name = L["Goblin Baccarat"],
    short = L["Player or banker"],
    aliases = { "baccarat", "bakkarat", "bank" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_01",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Two hands are dealt, and the one closer to 9 wins – tens and face cards count 0, only the last digit of the sum counts. You only bet on the outcome: player, banker or tie. Third cards are drawn by fixed rules. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: bet 10, ¼ or ½ of your gold · then 1: player · 2: banker · 3: tie · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–3: bet, then\n1: player · 2: banker\n3: tie · %s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
