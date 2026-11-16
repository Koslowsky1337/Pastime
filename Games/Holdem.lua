-- Pastime: Tavernen-Hold'em – Turnier am Tisch gegen drei Computergegner.
-- Du kaufst dich mit Gold ein, alle vier starten mit gleich vielen Chips. Niemand setzt mehr,
-- als er hat; wer keine Chips mehr hat, fliegt raus. Gewinnst du den Tisch, gehören dir alle Chips.
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 420, 440
local SEATS, MAX_RAISES, SAMPLES = 4, 4, 40
local NOISE = 0.4       -- so weit verschätzen sich die Gegner (±20 Punkte Gewinnchance)
local BLIND_HANDS = 5   -- nach so vielen Händen verdoppeln sich die Blinds

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game

Game.JACKPOT = L["a pot won with four of a kind or a straight flush"]

-- tight: wie gut die Chancen sein müssen, um mitzugehen · aggr: wie gern er erhöht · bluff: Anteil der Bluffs
Game.BOTS = {
    { name = L["Gnome"], tight = 0.6, aggr = 0.7, bluff = 0.02 },
    { name = L["Troll"], tight = 0.25, aggr = 0.8, bluff = 0.08 },
    { name = L["Dwarf"], tight = 0.45, aggr = 1.0, bluff = 0.05 },
}
local BOARD_N = { 0, 3, 4, 5 }      -- offene Gemeinschaftskarten je Setzrunde

-- Einkauf am Tisch: ¼, ½ oder dein ganzes Gold
function Game.Bets(gold)
    local function part(f) return math.max(10, math.floor(gold * f / 5) * 5) end
    return { part(0.25), part(0.5), math.max(10, gold) }
end

function Game:Blinds()
    local sb = math.max(1, math.floor(self.buyin / 50)) * 2 ^ math.max(0, math.floor((self.hands - 1) / BLIND_HANDS))
    return sb, sb * 2
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

function Game:CanAct(s) return not self.folded[s] and not self.allin[s] end

local function nextSeat(self, s, ok)
    for _ = 1, SEATS do
        s = s % SEATS + 1
        if ok(s) then return s end
    end
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
    local opp = math.max(1, self:Active() - 1)
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

-- Erhöhung: der halbe Topf, mindestens der große Blind
function Game:RaiseSize()
    local _, bb = self:Blinds()
    return math.max(bb, math.floor(self:Pot() / 2))
end

-- Entscheidung eines Computergegners: "fold", "call", "raise" oder "allin". Ungenaues
-- Einschätzen (NOISE) und gelegentliche Bluffs sorgen dafür, dass er Fehler macht.
function Game:BotChoice(seat)
    local bot = Game.BOTS[seat - 1]
    local e = self:Equity(seat) + (math.random() - 0.5) * NOISE
    local fair = 1 / self:Active()
    local stack = self.stacks[seat]
    local toCall = math.min(self.cur - self.r[seat], stack)
    local _, bb = self:Blinds()
    local canRaise = self.raises < MAX_RAISES and stack > toCall
    local bluff = math.random() < bot.bluff
    local push = stack <= 6 * bb or stack - toCall <= self:RaiseSize() * 1.5
    if toCall == 0 then
        if canRaise and (bluff or e > fair * 2.3 / bot.aggr) then return push and "allin" or "raise" end
        return "call"
    end
    if canRaise and ((bluff and toCall <= 2 * bb) or e > fair * 3.0 / bot.aggr) then
        return (push or (e > 0.8 and math.random() < 0.3)) and "allin" or "raise"
    end
    local odds = toCall / (self:Pot() + toCall)
    return e > odds * bot.tight and "call" or "fold"
end

function Game:Clear()
    self.holes, self.comm, self.folded, self.allin, self.says, self.reveal = {}, {}, {}, {}, {}, false
    self.c, self.r, self.street, self.cur = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 1, 0
    self.stacks = nil
end

-- Der Tisch bleibt über Schließen und Neustart erhalten – auch mitten in einer Hand: dann liegt
-- sie beim nächsten Öffnen genau so wieder da (Karten, Töpfe, wer dran ist).
local HAND = { "holes", "comm", "folded", "allin", "says", "reveal", "c", "r", "acted", "raises", "street", "cur", "seat", "state" }
function Game:SaveTable()
    local t = nil
    if self.stacks then
        t = { stacks = { unpack(self.stacks) }, button = self.button, hands = self.hands, buyin = self.buyin }
        if self.state == "act" or self.state == "bots" or self.state == "runout" then
            t.hand = {}
            for _, k in ipairs(HAND) do t.hand[k] = self[k] end
        end
    end
    self:Purse().table = t
end

function Game:Start()
    local p = self:Purse()
    local t = p.table
    if type(t) == "table" and type(t.stacks) == "table" and (t.stacks[1] or 0) > 0 then
        self.gold = tonumber(p.gold) or 0
        self.peak = math.max(tonumber(p.peak) or 0, self.gold)
        self.score = self.peak
        self:Clear()
        self.stacks, self.button, self.hands, self.buyin, self.bet = { unpack(t.stacks) }, t.button, t.hands, t.buyin, t.buyin
        self.state = "between"
        self.msg:SetText(L["Back at the table."])
        self.sub:SetText("")
        if type(t.hand) == "table" and type(t.hand.holes) == "table" and type(t.hand.c) == "table" then
            for _, k in ipairs(HAND) do self[k] = t.hand[k] end
            self.wait = 0.9
            if self.state == "act" then self.sub:SetText(L["Your turn."]) end
        end
        return self:Render()
    end
    p.table = nil
    self:OpenRun()
end

function Game:Deal(buyin)
    self.buyin, self.hands = buyin, 0
    self.stacks = { buyin, buyin, buyin, buyin }
    self.button = math.random(SEATS)
    self:SaveTable()
    self:NewHand()
end

-- Chips eines Sitzes in den Topf; wer nichts mehr hat, ist „all in“
function Game:Put(seat, amount)
    amount = math.min(amount, self.stacks[seat])
    self.stacks[seat] = self.stacks[seat] - amount
    self.c[seat] = self.c[seat] + amount
    self.r[seat] = self.r[seat] + amount
    if self.stacks[seat] == 0 then self.allin[seat] = true end
end

function Game:NewHand()
    if self.state ~= "between" and self.state ~= "bet" then return end
    self.jackWon = nil
    local deck = Cards.Shuffle(Cards.NewDeck())
    self.holes, self.comm, self.folded, self.allin, self.says, self.reveal = {}, {}, {}, {}, {}, false
    self.c, self.r, self.acted, self.raises, self.street = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, {}, 0, 1
    for s = 1, SEATS do
        if self.stacks[s] == 0 then self.folded[s] = true else self.holes[s] = { table.remove(deck), table.remove(deck) } end
    end
    for i = 1, 5 do self.comm[i] = table.remove(deck) end
    self.hands = self.hands + 1
    local alive = function(s) return not self.folded[s] end
    self.button = nextSeat(self, self.button, alive)
    local sbSeat = nextSeat(self, self.button, alive)
    local bbSeat = nextSeat(self, sbSeat, alive)
    local sb, bb = self:Blinds()
    self:Put(sbSeat, sb)
    self:Put(bbSeat, bb)
    self.says[sbSeat], self.says[bbSeat] = L["small blind"], L["big blind"]
    self.cur = bb
    self.seat = nextSeat(self, bbSeat, alive)
    self.sub:SetText("")
    self.host:Sound("click")
    self:Advance()
end

-- Nächster Sitz, der noch handeln muss; niemand mehr: Setzrunde zu Ende
function Game:Advance()
    for _ = 1, SEATS do
        local s = self.seat
        if self:CanAct(s) and (not self.acted[s] or self.r[s] < self.cur) then
            if s == 1 then
                self.state = "act"
                self.sub:SetText(L["Your turn."])
            else
                self.state, self.wait = "bots", 0.7
            end
            self:SaveTable()
            return self:Render()
        end
        self.seat = s % SEATS + 1
    end
    self:EndRound()
end

function Game:EndRound()
    if self.street == 4 then return self:Showdown() end
    local can = 0
    for s = 1, SEATS do if self:CanAct(s) then can = can + 1 end end
    if can <= 1 then
        -- höchstens einer kann noch setzen: die restlichen Karten werden einfach aufgedeckt
        self.state, self.wait, self.reveal = "runout", 0.9, true
        self:SaveTable()
        return self:Render()
    end
    self.street = self.street + 1
    self.cur, self.r, self.acted, self.raises = 0, { 0, 0, 0, 0 }, {}, 0
    for s = 2, SEATS do if self:CanAct(s) then self.says[s] = nil end end
    self.seat = nextSeat(self, self.button, function(s) return not self.folded[s] end)
    self.host:Sound("click")
    self:Advance()
end

function Game:Act(seat, what)
    local toCall = self.cur - self.r[seat]
    if what == "fold" then
        self.folded[seat] = true
        self.says[seat] = L["folds"]
    elseif what == "call" then
        self.says[seat] = toCall == 0 and L["checks"] or L["calls"]
        self:Put(seat, toCall)
    else
        local opened = self.cur == 0
        self:Put(seat, what == "allin" and self.stacks[seat] or (self.cur + self:RaiseSize() - self.r[seat]))
        if self.r[seat] > self.cur then
            self.cur, self.raises = self.r[seat], self.raises + 1
            self.says[seat] = opened and L["bets"] or L["raises"]
        else
            self.says[seat] = L["calls"]
        end
    end
    if self.allin[seat] then self.says[seat] = L["all in"] end
    self.acted[seat] = true
    self.host:Sound("click")
    if self:Active() == 1 then
        local winner = nextSeat(self, seat, function(s) return not self.folded[s] end)
        self.stacks[winner] = self.stacks[winner] + self:Pot()
        return self:EndHand(winner == 1 and L["Everyone else folded – the pot is yours."]
            or (L["%s wins."]):format(Game.BOTS[winner - 1].name), winner == 1 and self:Pot() or 0)
    end
    self.seat = seat % SEATS + 1
    self:Advance()
end

-- Töpfe verteilen. Wer „all in“ weniger gesetzt hat, gewinnt von jedem höchstens diesen Betrag;
-- der Rest bildet Nebentöpfe für die anderen. Liefert den Gewinn je Sitz und die Sieger des Haupttopfs.
function Game.Split(c, folded, score)
    local rem, wins, main = { unpack(c) }, { 0, 0, 0, 0 }, nil
    while true do
        local m
        for s = 1, SEATS do
            if not folded[s] and rem[s] > 0 and (not m or rem[s] < m) then m = rem[s] end
        end
        if not m then break end
        local pot, best, winners = 0, 0, {}
        for s = 1, SEATS do
            local part = math.min(rem[s], m)
            pot = pot + part
            if not folded[s] and rem[s] > 0 and score[s] > best then best = score[s] end
        end
        for s = 1, SEATS do
            if not folded[s] and rem[s] > 0 and score[s] == best then winners[#winners + 1] = s end
            rem[s] = rem[s] - math.min(rem[s], m)
        end
        local share = math.floor(pot / #winners)
        for _, s in ipairs(winners) do wins[s] = wins[s] + share end
        wins[winners[1]] = wins[winners[1]] + pot - share * #winners
        main = main or winners
    end
    for s = 1, SEATS do wins[main[1]] = wins[main[1]] + rem[s] end      -- Reste von Sitzen, die gepasst haben
    return wins, main
end

function Game:Showdown()
    self.street, self.reveal = 4, true
    local score, cat1 = {}, nil
    for s = 1, SEATS do
        if not self.folded[s] then
            local hand = { self.holes[s][1], self.holes[s][2] }
            for i = 1, 5 do hand[#hand + 1] = self.comm[i] end
            local cat, v = Cards.Eval(hand)
            score[s] = v
            if s == 1 then cat1 = cat else self.says[s] = Cards.HANDS[cat] end
        end
    end
    local wins, main = Game.Split(self.c, self.folded, score)
    -- Jackpot: den Topf mit einem Vierling oder Straight Flush gewinnen (rund jede 1.100. Hand)
    if cat1 and cat1 >= 8 and main[1] == 1 then self:Jackpot() end
    for s = 1, SEATS do self.stacks[s] = self.stacks[s] + wins[s] end
    local text
    if wins[1] > 0 and main[1] == 1 then
        text = (#main > 1 and L["Split pot: %s."] or L["You win: %s."]):format(Cards.HANDS[cat1])
    else
        local names = {}
        for _, s in ipairs(main) do if s > 1 then names[#names + 1] = Game.BOTS[s - 1].name end end
        text = (L["%s wins."]):format(table.concat(names, ", "))
    end
    self:EndHand(text, wins[1])
end

-- Hand vorbei: Stand merken; ohne Chips bist du raus, ohne Gegner gehört dir der Tisch
function Game:EndHand(text, won)
    local diff = won - self.c[1]
    self.c = { 0, 0, 0, 0 }
    self.state = "between"
    self.msg:SetText(diff > 0 and ("|cff80ff80+%d|r"):format(diff) or (diff < 0 and ("|cffff6060%d|r"):format(diff) or "±0"))
    self.sub:SetText(text)
    self.host:Sound(diff > 0 and "big" or (diff < 0 and "bad" or "click"))
    self:SaveTable()
    local bots = 0
    for s = 2, SEATS do if self.stacks[s] > 0 then bots = bots + 1 end end
    if self.stacks[1] == 0 then return self:LeaveTable(L["You are out of chips."]) end
    if bots == 0 then return self:LeaveTable(L["You won the table!"]) end
    self:Render()
end

-- Aufstehen: deine Chips werden wieder zu Gold
function Game:LeaveTable(text)
    if self.state ~= "between" then return end
    local chips = self.stacks[1]
    self.stacks[1] = 0
    self:Purse().table = nil
    self:Pay(chips, text or (L["You leave the table with %d chips."]):format(chips), false)
end

function Game:Update(dt)
    if self.state == "bots" then
        self.wait = self.wait - dt
        if self.wait <= 0 then self:Act(self.seat, self:BotChoice(self.seat)) end
    elseif self.state == "runout" then
        self.wait = self.wait - dt
        if self.wait <= 0 then
            if self.street == 4 then return self:Showdown() end
            self.street, self.wait = self.street + 1, 0.9
            self:SaveTable()
            self.host:Sound("click")
            self:Render()
        end
    else
        self:Tick(dt)
    end
end

function Game:CanRaise()
    return self.state == "act" and self.raises < MAX_RAISES and self.stacks[1] > self.cur - self.r[1] + self:RaiseSize()
end

function Game:Player(what)
    if self.state ~= "act" or (what == "raise" and not self:CanRaise()) then return end
    self:Act(1, what)
end

local ACTIONS = { ["1"] = "fold", ["2"] = "call", ["3"] = "raise", ["4"] = "allin" }
function Game:Key(k, down)
    local act
    if self.state == "act" and ACTIONS[k] then act = function() self:Player(ACTIONS[k]) end
    elseif self.state == "between" and (k == "1" or k == "SPACE" or k == "ENTER") then act = function() self:NewHand() end
    elseif self.state == "between" and k == "2" then act = function() self:LeaveTable() end
    end
    if act then
        if down then act() end
        return true
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    local seated = self.stacks ~= nil
    local dealt = self.holes[1] ~= nil
    local nBoard = dealt and BOARD_N[self.street] or 0
    for i = 1, 5 do self.commCards[i]:SetCard(i <= nBoard and self.comm[i] or nil, true) end
    for s = 2, SEATS do
        local seat = self.seats[s]
        local show = self.holes[s] ~= nil and not self.folded[s]
        for i = 1, 2 do seat.cards[i]:SetCard(show and self.holes[s][i] or nil, self.reveal) end
        seat.says:SetText(self.says[s] or "")
        local stack = seated and self.stacks[s] or nil
        seat.name:SetText(Game.BOTS[s - 1].name .. (stack and (stack > 0 or show) and (" · " .. stack) or (stack and (" · " .. L["out"]) or "")))
        local turn = self.state == "bots" and self.seat == s
        seat.name:SetTextColor(turn and 1 or 0.8, turn and 0.82 or 0.8, turn and 0 or 0.8)
    end
    for i = 1, 2 do self.myCards[i]:SetCard(dealt and self.holes[1][i] or nil, true) end
    self.you:SetText(L["You"] .. (seated and (" · " .. self.stacks[1]) or ""))
    local hand = ""
    if dealt and nBoard >= 3 then
        local cards = { self.holes[1][1], self.holes[1][2] }
        for i = 1, nBoard do cards[#cards + 1] = self.comm[i] end
        hand = Cards.HANDS[(Cards.Eval(cards))]
    end
    self.handText:SetText(hand)
    local playing = self.state == "act" or self.state == "bots" or self.state == "runout"
    if playing then
        self.msg:SetText((L["Pot: %d"]):format(self:Pot()))
        if self.state ~= "act" then self.sub:SetText("") end
    end
    local act = self.state == "act"
    local toCall = act and math.min(self.cur - self.r[1], self.stacks[1]) or 0
    self.foldBtn:SetShown(act)
    self.callBtn:SetShown(act)
    self.callBtn:SetText(toCall == 0 and L["Check (2)"] or (L["Call %d (2)"]):format(toCall))
    self.raiseBtn:SetShown(act)
    self.raiseBtn:SetEnabled(self:CanRaise())
    self.raiseBtn:SetText(((self.cur or 0) == 0 and L["Bet %d (3)"] or L["Raise %d (3)"]):format(act and self:RaiseSize() or 0))
    self.allinBtn:SetShown(act)
    self.allinBtn:SetText((L["All in %d (4)"]):format(act and self.stacks[1] or 0))
    self.handBtn:SetShown(self.state == "between")
    self.leaveBtn:SetShown(self.state == "between")
    self:BaseRender()
    local amounts = self.Bets(self.gold or 0)
    for i, b in ipairs(self.betButtons) do b:SetText((L["Buy in %d (%d)"]):format(amounts[i], i)) end
end

function Game:Info()
    local sb, bb = 0, 0
    if self.stacks then sb, bb = self:Blinds() end
    return {
        { L["Gold"], tostring(self.gold or 0) },
        { L["Chips"], tostring(self.stacks and self.stacks[1] or 0) },
        { L["Blinds"], ("%d/%d"):format(sb, bb) },
    }
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "holdem", 228)
    g.seats, g.commCards, g.myCards, g.hands, g.buyin = {}, {}, {}, 0, 0
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
    g.you = ns.FontString(board, "GameFontNormal", "RIGHT")
    g.you:SetPoint("TOPRIGHT", board, "TOPLEFT", 122, -310)
    g.handText = ns.FontString(board, "GameFontHighlight", "LEFT")
    g.handText:SetPoint("TOPLEFT", board, "TOPLEFT", 266, -310)
    g.handText:SetWidth(146)
    -- zwei Reihen Knöpfe: unten Passen und Mitgehen, darüber Erhöhen und All-in
    local function btn(text, x, y, fn)
        local b = g:Button(text, 200, x, fn)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", x, y)
        return b
    end
    g.foldBtn = btn(L["Fold (1)"], 8, 10, function() g:Player("fold") end)
    g.callBtn = btn("", 212, 10, function() g:Player("call") end)
    g.raiseBtn = btn("", 8, 40, function() g:Player("raise") end)
    g.allinBtn = btn("", 212, 40, function() g:Player("allin") end)
    g.handBtn = btn(L["Next hand (Space)"], 8, 10, function() g:NewHand() end)
    g.leaveBtn = btn(L["Leave table (2)"], 212, 10, function() g:LeaveTable() end)
    ns.SetTooltip(g.leaveBtn, L["Leave table (2)"], L["Your chips turn back into gold. The table is over."])
    return g
end

ns.RegisterGame({
    id = "holdem",
    name = L["Tavern Hold'em"],
    short = L["Poker tournament for four"],
    aliases = { "holdem", "texas", "tavernholdem", "pokerrunde", "turnier" },
    category = "karten",
    length = "lang",
    icon = "Interface\\Icons\\INV_Misc_Dice_01",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["A Texas Hold'em table against a gnome, a troll and a dwarf. You buy in with gold and all four start with the same chips. Nobody can bet more than they have, and whoever runs out is gone. Win the table and all chips are yours – or get up between hands and take what you have. The blinds double every five hands."],
    controls = L["1/2/3: buy in with ¼, ½ or all of your gold · in the hand 1: fold · 2: check or call · 3: raise · 4: all in · between hands Space: next hand · 2: leave the table · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1: fold · 2: call\n3: raise · 4: all in\n%s: cash out"]:format(ns.KEYS.cash),
    wins = function() return Cards.Ranking(L["Your best five out of seven cards count. Equal hands split the pot."]) end,
    Create = Create,
})
