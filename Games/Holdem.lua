-- Pastime: Tavernen-Hold'em – Texas Hold'em mit festen Einsätzen gegen drei Computergegner.
-- Nur dein Gold wird geführt: die Gegner haben immer genug. Gewinnst du, bekommst du von
-- jedem höchstens so viel, wie du selbst gesetzt hast (so braucht es keine Nebentöpfe).
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 420, 440
local SEATS, MAX_RAISES, SAMPLES = 4, 3, 40
local NOISE = 0.4       -- so weit verschätzen sich die Gegner (±20 Punkte Gewinnchance)

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

-- tight: wie gut die Chancen sein müssen, um mitzugehen · aggr: wie gern er erhöht · bluff: Anteil der Bluffs
Game.BOTS = {
    { name = L["Gnome"], tight = 0.6, aggr = 0.7, bluff = 0.02 },
    { name = L["Troll"], tight = 0.25, aggr = 0.8, bluff = 0.08 },
    { name = L["Dwarf"], tight = 0.45, aggr = 1.0, bluff = 0.05 },
}
local BOARD_N = { 0, 3, 4, 5 }      -- offene Gemeinschaftskarten je Setzrunde

-- Grundeinsatz (Ante und kleiner Einsatz): 10 Gold, 5 % oder 10 % des Golds
function Game.Bets(gold)
    local function part(f) return math.max(10, math.floor(gold * f / 5) * 5) end
    return { 10, part(0.05), part(0.1) }
end

function Game:Active()
    local n = 0
    for s = 1, SEATS do if not self.folded[s] then n = n + 1 end end
    return n
end

function Game:Pot()
    local p = 0
    for s = 1, SEATS do p = p + self.c[s] end
    return p
end

-- Gewinnchance eines Sitzes gegen zufällige Hände der übrigen Spieler. Der Gegner kennt
-- nur seine eigenen Karten und die offenen Gemeinschaftskarten.
function Game:Equity(seat)
    local known, rest = {}, {}
    local nBoard = BOARD_N[self.street]
    local mine = { self.holes[seat][1], self.holes[seat][2] }
    for i = 1, nBoard do mine[#mine + 1] = self.comm[i] end
    for _, c in ipairs(mine) do known[c.rank * 10 + c.suit] = true end
    for s = 1, 4 do
        for r = 1, 13 do
            if not known[r * 10 + s] then rest[#rest + 1] = { rank = r, suit = s } end
        end
    end
    local opp = self:Active() - 1
    local need = (5 - nBoard) + 2 * opp
    local score = 0
    for _ = 1, SAMPLES do
        for i = 1, need do
            local j = math.random(i, #rest)
            rest[i], rest[j] = rest[j], rest[i]
        end
        local hand = { mine[1], mine[2] }
        for i = 1, nBoard do hand[#hand + 1] = self.comm[i] end
        for i = 1, 5 - nBoard do hand[#hand + 1] = rest[i] end
        local _, my = Cards.Eval(hand)
        local best = 0
        for o = 1, opp do
            local k = (5 - nBoard) + 2 * (o - 1)
            hand[1], hand[2] = rest[k + 1], rest[k + 2]
            local _, v = Cards.Eval(hand)
            if v > best then best = v end
        end
        score = score + (my > best and 1 or (my == best and 0.5 or 0))
    end
    return score / SAMPLES
end

-- Entscheidung eines Computergegners: "fold", "call" oder "raise". Ungenaues Einschätzen
-- (NOISE) und gelegentliche Bluffs sorgen dafür, dass er Fehler macht.
function Game:BotChoice(seat)
    local bot = Game.BOTS[seat - 1]
    local e = self:Equity(seat) + (math.random() - 0.5) * NOISE
    local fair = 1 / self:Active()
    local toCall = self.cur - self.r[seat]
    local canRaise = self.raises < MAX_RAISES
    local bluff = math.random() < bot.bluff
    if toCall == 0 then
        return canRaise and (bluff or e > fair * 2.3 / bot.aggr) and "raise" or "call"
    end
    if canRaise and (bluff or e > fair * 3.0 / bot.aggr) then return "raise" end
    local odds = toCall / (self:Pot() + toCall)
    return e > odds * bot.tight and "call" or "fold"
end

function Game:Clear()
    self.holes, self.comm, self.folded, self.says, self.reveal = {}, {}, {}, {}, false
    self.c, self.r, self.street, self.cur = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 1, 0
end

function Game:Start()
    self.first = math.random(SEATS)
    self:OpenRun()
end

function Game:Deal(u)
    local deck = Cards.Shuffle(Cards.NewDeck())
    self.u, self.holes, self.comm, self.folded, self.says, self.reveal = u, {}, {}, {}, {}, false
    for s = 1, SEATS do self.holes[s] = { table.remove(deck), table.remove(deck) } end
    for i = 1, 5 do self.comm[i] = table.remove(deck) end
    self.c = { u, u, u, u }
    self.allin = self.gold == 0
    self.first = self.first % SEATS + 1
    self.street = 1
    self.sub:SetText("")
    self:BeginRound()
end

function Game:BeginRound()
    self.size = self.street <= 2 and self.u or self.u * 2
    self.cur, self.r, self.raises, self.acted = 0, { 0, 0, 0, 0 }, 0, {}
    self.seat = self.first
    if self.allin then
        self.state, self.wait = "runout", 0.9
        return self:Render()
    end
    self:Advance()
end

-- Nächster Sitz, der noch handeln muss; niemand mehr: Setzrunde zu Ende
function Game:Advance()
    for _ = 1, SEATS do
        local s = self.seat
        if not self.folded[s] and (not self.acted[s] or self.r[s] < self.cur) then
            if s == 1 then
                self.state = "act"
                self.sub:SetText(L["Your turn."])
            else
                self.state, self.wait = "bots", 0.7
            end
            return self:Render()
        end
        self.seat = s % SEATS + 1
    end
    self:EndRound()
end

function Game:EndRound()
    if self.street == 4 then return self:Showdown() end
    self.street = self.street + 1
    for s = 2, SEATS do if not self.folded[s] then self.says[s] = nil end end
    self.host:Sound("click")
    self:BeginRound()
end

function Game:Act(seat, what)
    local toCall = self.cur - self.r[seat]
    local pay = 0
    if what == "fold" then
        self.folded[seat] = true
        self.says[seat] = L["folds"]
    elseif what == "raise" then
        self.says[seat] = self.cur == 0 and L["bets"] or L["raises"]
        self.cur = self.cur + self.size
        self.raises = self.raises + 1
        pay = self.cur - self.r[seat]
    else
        self.says[seat] = toCall == 0 and L["checks"] or L["calls"]
        pay = toCall
    end
    if seat == 1 then
        pay = math.min(pay, self.gold)      -- zu wenig Gold: mit dem Rest mitgehen („all in“)
        self:Spend(pay)
        if self.gold == 0 then self.allin = true end
    end
    self.c[seat] = self.c[seat] + pay
    self.r[seat] = self.cur
    self.acted[seat] = true
    self.host:Sound("click")
    if self.folded[1] then return self:Finish(0, L["You folded."], 1.6) end
    if self:Active() == 1 then return self:Finish(self:Share(1), L["Everyone else folded – the pot is yours."], 2) end
    if self.allin then
        self.state, self.wait = "runout", 0.9
        return self:Render()
    end
    self.seat = seat % SEATS + 1
    self:Advance()
end

-- Dein Anteil am Topf: von jedem Sitz höchstens so viel, wie du selbst gesetzt hast
function Game:Share(winners)
    local sum = 0
    for s = 1, SEATS do sum = sum + math.min(self.c[s], self.c[1]) end
    return math.floor(sum / winners)
end

function Game:Showdown()
    self.street, self.reveal = 4, true
    local best, winners, names, cat1 = 0, 0, {}, nil
    local score = {}
    for s = 1, SEATS do
        if not self.folded[s] then
            local hand = { self.holes[s][1], self.holes[s][2] }
            for i = 1, 5 do hand[#hand + 1] = self.comm[i] end
            local cat, v = Cards.Eval(hand)
            score[s] = v
            if s == 1 then cat1 = cat else self.says[s] = Cards.HANDS[cat] end
            if v > best then best = v end
        end
    end
    for s = 1, SEATS do
        if score[s] == best then
            winners = winners + 1
            if s > 1 then names[#names + 1] = Game.BOTS[s - 1].name end
        end
    end
    if score[1] == best then
        return self:Finish(self:Share(winners), winners > 1 and (L["Split pot: %s."]):format(Cards.HANDS[cat1])
            or (L["You win: %s."]):format(Cards.HANDS[cat1]), false)
    end
    self:Finish(0, (L["%s wins."]):format(table.concat(names, ", ")), false)
end

function Game:Finish(win, text, wait)
    self:Pay(win, text, wait)
end

function Game:Update(dt)
    if self.state == "bots" then
        self.wait = self.wait - dt
        if self.wait <= 0 then self:Act(self.seat, self:BotChoice(self.seat)) end
    elseif self.state == "runout" then
        -- du bist „all in“: die restlichen Karten werden ohne weitere Einsätze aufgedeckt
        self.wait = self.wait - dt
        if self.wait <= 0 then
            if self.street == 4 then return self:Showdown() end
            self.street, self.wait = self.street + 1, 0.9
            self.host:Sound("click")
            self:Render()
        end
    else
        self:Tick(dt)
    end
end

function Game:CanRaise()
    return self.state == "act" and self.raises < MAX_RAISES and self.gold >= self.cur - self.r[1] + self.size
end

function Game:Player(what)
    if self.state ~= "act" or (what == "raise" and not self:CanRaise()) then return end
    self:Act(1, what)
end

function Game:Key(k, down)
    if self.state == "act" and (k == "1" or k == "2" or k == "3") then
        if down then self:Player(k == "1" and "fold" or (k == "2" and "call" or "raise")) end
        return true
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    local dealt = self.holes[1] ~= nil
    local nBoard = dealt and BOARD_N[self.street] or 0
    for i = 1, 5 do self.commCards[i]:SetCard(i <= nBoard and self.comm[i] or nil, true) end
    for s = 2, SEATS do
        local seat = self.seats[s]
        local show = dealt and not self.folded[s]
        for i = 1, 2 do seat.cards[i]:SetCard(show and self.holes[s][i] or nil, self.reveal) end
        seat.says:SetText(self.says[s] or "")
        local turn = self.state == "bots" and self.seat == s
        seat.name:SetTextColor(turn and 1 or 0.8, turn and 0.82 or 0.8, turn and 0 or 0.8)
    end
    for i = 1, 2 do self.myCards[i]:SetCard(dealt and self.holes[1][i] or nil, true) end
    local hand = ""
    if dealt and nBoard >= 3 then
        local cards = { self.holes[1][1], self.holes[1][2] }
        for i = 1, nBoard do cards[#cards + 1] = self.comm[i] end
        hand = Cards.HANDS[(Cards.Eval(cards))]
    end
    self.handText:SetText(hand)
    if dealt and self.state ~= "result" and self.state ~= "over" then
        self.msg:SetText((L["Pot: %d"]):format(self:Pot()))
        if self.state ~= "act" then self.sub:SetText("") end
    end
    local act = self.state == "act"
    local toCall = act and math.min(self.cur - self.r[1], self.gold) or 0
    self.foldBtn:SetShown(act)
    self.callBtn:SetShown(act)
    self.callBtn:SetText(toCall == 0 and L["Check (2)"] or (L["Call %d (2)"]):format(toCall))
    self.raiseBtn:SetShown(act)
    self.raiseBtn:SetEnabled(self:CanRaise())
    self.raiseBtn:SetText(((self.cur or 0) == 0 and L["Bet %d (3)"] or L["Raise %d (3)"]):format(self.size or 0))
    self:BaseRender()
end

function Game:Info()
    return {
        { L["Gold"], tostring(self.gold or 0) },
        { L["Bet"], tostring(self.bet or 0) },
        { L["Pot"], tostring(self.c and self:Pot() or 0) },
    }
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "holdem", 228)
    g.seats, g.commCards, g.myCards = {}, {}, {}
    g:Clear()
    for s = 2, SEATS do
        local cx = 70 + (s - 2) * 140
        local seat = { cards = {} }
        seat.name = ns.FontString(board, "GameFontNormal", "CENTER")
        seat.name:SetPoint("TOP", board, "TOPLEFT", cx, -28)
        seat.name:SetText(Game.BOTS[s - 1].name)
        for i = 1, 2 do
            seat.cards[i] = Cards.Create(board, 40, 56)
            seat.cards[i]:SetPoint("TOPLEFT", board, "TOPLEFT", cx - 42 + (i - 1) * 44, -44)
            seat.cards[i]:Hide()
        end
        seat.says = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
        seat.says:SetPoint("TOP", board, "TOPLEFT", cx, -103)
        g.seats[s] = seat
    end
    for i = 1, 5 do
        g.commCards[i] = Cards.Create(board, 56, 78)
        g.commCards[i]:SetPoint("TOPLEFT", board, "TOPLEFT", 58 + (i - 1) * 62, -122)
        g.commCards[i]:Hide()
    end
    for i = 1, 2 do
        g.myCards[i] = Cards.Create(board, 60, 84)
        g.myCards[i]:SetPoint("TOPLEFT", board, "TOPLEFT", 130 + (i - 1) * 66, -276)
        g.myCards[i]:Hide()
    end
    local you = ns.FontString(board, "GameFontNormal", "RIGHT")
    you:SetPoint("TOPRIGHT", board, "TOPLEFT", 120, -310)
    you:SetText(L["You"])
    g.handText = ns.FontString(board, "GameFontHighlight", "LEFT")
    g.handText:SetPoint("TOPLEFT", board, "TOPLEFT", 266, -310)
    g.handText:SetWidth(146)
    g.foldBtn = g:Button(L["Fold (1)"], 126, 8, function() g:Player("fold") end)
    g.callBtn = g:Button("", 126, 144, function() g:Player("call") end)
    g.raiseBtn = g:Button("", 126, 280, function() g:Player("raise") end)
    return g
end

ns.RegisterGame({
    id = "holdem",
    name = L["Tavern Hold'em"],
    short = L["Poker against three"],
    aliases = { "holdem", "texas", "tavernholdem", "pokerrunde" },
    category = "karten",
    length = "lang",
    icon = "Interface\\Icons\\INV_Misc_Dice_01",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Texas Hold'em against a gnome, a troll and a dwarf: two cards each, five on the table, the best hand of five wins. After the ante come four betting rounds with fixed bets. The others misjudge their hands and bluff now and then. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2/3: ante of 10, 1/20 or 1/10 of your gold · in the hand 1: fold · 2: check or call · 3: bet or raise · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1–3: ante, then\n1: fold · 2: call\n3: raise · %s: cash out"]:format(ns.KEYS.cash),
    Create = Create,
})
