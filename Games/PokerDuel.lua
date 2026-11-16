-- Pastime: Poker zu zweit – das Brett für Goblin-Poker und Tavernen-Hold'em im Mehrspieler.
-- Beide beginnen mit 1000 Gold. Gespielt wird über eine feste Zahl von Blättern oder bis einer
-- pleite ist; wer dann mehr Gold hat, gewinnt. Gesetzt wird in festen Schritten (höchstens drei
-- Erhöhungen je Runde). Beide Seiten führen denselben Zustand; verdeckt ist nur die Anzeige.
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 440, 440
local START = 1000
local FOLD, CALL, RAISE, DEAL, SWAP = 1, 2, 3, 4, 100      -- Züge; tauschen: 100 + Bitmaske der Karten, die weg sollen
local VARIANTS = {
    drawpoker = { hole = 5, hands = 5, ante = 20, bets = { 40 }, swap = true },
    holdem = { hole = 2, hands = 10, small = 10, big = 20, bets = { 20, 20, 40, 40 } },
}

---------------------------------------------------------------------------
-- Regelwerk
---------------------------------------------------------------------------
local R = {}

local function avail(st, seat) return st.chips[seat] - st.put[seat] end

local function deal(st)
    local v = st.v
    st.hand = st.hand + 1
    st.deck = Cards.Shuffle(Cards.NewDeck(), st.rnd)
    st.cards, st.board, st.last, st.swapped, st.swapN = { {}, {} }, {}, nil, 0, {}
    for seat = 1, 2 do
        for _ = 1, v.hole do table.insert(st.cards[seat], table.remove(st.deck)) end
    end
    st.round, st.raises, st.acted = 1, 0, 0
    local d = st.dealer
    if v.swap then
        st.put = { math.min(st.chips[1], v.ante), math.min(st.chips[2], v.ante) }
        st.phase, st.toAct = "swap", 3 - d
    else
        st.put = {}
        st.put[d], st.put[3 - d] = math.min(st.chips[d], v.small), math.min(st.chips[3 - d], v.big)
        st.phase, st.toAct = "bet", d      -- zu zweit beginnt vor dem Flop der Geber
    end
end

function R.New(seed, first, id)
    local v = VARIANTS[id]
    local st = { v = v, rnd = ns.RNG(seed), chips = { START, START }, hand = 0, seq = 0 }
    first = first == 2 and 2 or 1
    st.dealer = v.swap and 3 - first or first      -- wer beginnt, bestimmt die Sitzung
    deal(st)
    return st
end

function R.CanRaise(st, seat)
    return st.raises < 3 and avail(st, seat) > st.put[3 - seat] - st.put[seat] and avail(st, 3 - seat) > 0
end

function R.Legal(st, seat, v)
    if st.over or seat ~= st.toAct or type(v) ~= "number" or v ~= math.floor(v) then return false end
    if st.phase == "done" then return v == DEAL end
    if st.phase == "swap" then return v >= SWAP and v <= SWAP + 31 end
    return v == FOLD or v == CALL or (v == RAISE and R.CanRaise(st, seat))
end

-- Blatt abrechnen: gewonnen wird, was beide gesetzt haben (wer weniger hatte, begrenzt den Topf)
local function settle(st, winner, why, cats)
    local m = math.min(st.put[1], st.put[2])
    if winner ~= 0 then
        st.chips[winner], st.chips[3 - winner] = st.chips[winner] + m, st.chips[3 - winner] - m
    end
    st.last = { winner = winner, why = why, won = m, cats = cats }
    st.phase, st.put = "done", { 0, 0 }
    if st.hand >= st.v.hands or st.chips[1] <= 0 or st.chips[2] <= 0 then
        st.over = true
        return st.chips[1] == st.chips[2] and 0 or (st.chips[1] > st.chips[2] and 1 or 2)
    end
    st.toAct = 3 - st.dealer      -- der nächste Geber gibt
    return nil, st.toAct
end

local function showdown(st)
    while not st.v.swap and #st.board < 5 do table.insert(st.board, table.remove(st.deck)) end
    local cats, val = {}, {}
    for seat = 1, 2 do
        local all = { unpack(st.cards[seat]) }
        for _, c in ipairs(st.board) do all[#all + 1] = c end
        cats[seat], val[seat] = Cards.Eval(all)
    end
    return settle(st, val[1] == val[2] and 0 or (val[1] > val[2] and 1 or 2), "show", cats)
end

local function nextRound(st)
    if st.v.swap or st.round == 4 or avail(st, 1) == 0 or avail(st, 2) == 0 then return showdown(st) end
    st.round, st.raises, st.acted = st.round + 1, 0, 0
    for _ = 1, st.round == 2 and 3 or 1 do table.insert(st.board, table.remove(st.deck)) end
    st.toAct = 3 - st.dealer
    return nil, st.toAct
end

function R.Apply(st, seat, v)
    local other = 3 - seat
    st.seq = st.seq + 1
    if v == DEAL then
        st.dealer = 3 - st.dealer
        deal(st)
    elseif v >= SWAP then
        local mask, n = v - SWAP, 0
        for i = 1, 5 do
            if mask % 2 == 1 then st.cards[seat][i] = table.remove(st.deck); n = n + 1 end
            mask = math.floor(mask / 2)
        end
        st.swapN[seat], st.swapped = n, st.swapped + 1
        if st.swapped == 2 then st.phase, st.toAct = "bet", 3 - st.dealer else st.toAct = other end
    elseif v == FOLD then
        return settle(st, other, "fold")
    elseif v == CALL then
        st.put[seat] = math.min(st.put[other], st.chips[seat])
        st.acted = st.acted + 1
        if st.acted >= 2 then return nextRound(st) end
        st.toAct = other
    else
        st.put[seat] = math.min(st.chips[seat], st.put[other] + st.v.bets[st.round])
        st.raises, st.acted = st.raises + 1, st.acted + 1
        st.toAct = other
    end
    return nil, st.toAct
end

for _, id in ipairs({ "drawpoker", "holdem" }) do
    ns.MP.Register(id, { def = "pokerduel", Legal = R.Legal, Apply = R.Apply,
        New = function(seed, first) return R.New(seed, first, id) end })
end

---------------------------------------------------------------------------
-- Brett
---------------------------------------------------------------------------
local Game = { R = R }
Game.__index = Game

function Game:Start()
    self.mpDone, self.seen, self.wasMine, self.mark = nil, -1, nil, {}
    self:Sync()
end

function Game:Mine()
    local s = self.mp
    return s and ns.MP.session == s and s.state == "playing" and s.turn == s.me and not s.replaying
end

function Game:Move(v)
    if self:Mine() and ns.MP.Move(v) then self.host:Sound("click") end
end

-- mittlerer Knopf und Leertaste: tauschen, mitgehen oder das nächste Blatt geben
function Game:Main()
    local st = self.mp.board
    if st.phase == "done" then return self:Move(DEAL) end
    if st.phase == "swap" then
        local mask = 0
        for i = 5, 1, -1 do mask = mask * 2 + (self.mark[i] and 1 or 0) end
        return self:Move(SWAP + mask)
    end
    self:Move(CALL)
end

function Game:Click(i)
    if not (self:Mine() and self.mp.board.phase == "swap") then return end
    self.mark[i] = not self.mark[i] or nil
    self.host:Sound("click")
    self:Render()
end

function Game:Key(k, down)
    local act
    local bet = self.mp and self.mp.board.phase == "bet"
    if k == "SPACE" or k == "ENTER" then act = function() self:Main() end
    elseif bet and k == "1" then act = function() self:Move(FOLD) end
    elseif bet and k == "2" then act = function() self:Move(CALL) end
    elseif bet and k == "3" then act = function() self:Move(RAISE) end
    elseif not bet and tonumber(k) and tonumber(k) >= 1 and tonumber(k) <= 5 then act = function() self:Click(tonumber(k)) end
    end
    if not act then return false end
    if down then act() end
    return true
end

-- Was im letzten Blatt geschah, aus meiner Sicht
local function lastText(s, st)
    local l = st.last
    if not l then return "" end
    local me = s.me
    if l.why == "fold" then
        return l.winner == me and (L["%s folds – you win %d gold."]):format(s.partner, l.won) or (L["You fold and lose %d gold."]):format(l.won)
    end
    local hands = (L["You: %s · %s: %s"]):format(Cards.HANDS[l.cats[me]], s.partner, Cards.HANDS[l.cats[3 - me]])
    if l.winner == 0 then return hands .. "\n" .. L["Equal hands – nobody wins."] end
    return hands .. "\n" .. (l.winner == me and (L["You win %d gold."]):format(l.won) or (L["%s wins %d gold."]):format(s.partner, l.won))
end

-- Mehrspieler: Stand der Sitzung aufs Brett bringen (nach jedem Zug, bei Ende und Unterbrechung)
function Game:Sync()
    local s = self.mp
    if not s or self.mpDone then return end
    if ns.MP.session ~= s then
        self.mpDone = true
        return self.host:Over({ submit = false, title = L["Interrupted"],
            text = L["The game is paused and does not count. Ask the same player again within ten minutes to continue it."] })
    end
    local st = s.board
    if st.seq ~= self.seen then self.seen, self.mark = st.seq, {} end
    if s.state == "over" then
        self.mpDone = true
        self:Render()
        local why = s.why == "gave up" and L["You gave up."] or (s.why == "partner gave up" and L["Your opponent gave up."] or nil)
        return self.host:Over({ submit = false, won = s.result == 2, title = s.result == 0 and L["Defeat"] or (s.result == 1 and L["Draw"] or nil),
            text = why or (lastText(s, st) .. "\n" .. (L["You: %d gold · %s: %d gold"]):format(st.chips[s.me], s.partner, st.chips[3 - s.me])) })
    end
    local mine = self:Mine()
    if mine and self.wasMine == false then self.host:Sound("point") end
    self.wasMine = mine
    self:Render()
    self.host:Refresh()
end

-- Das Brett wird verlassen: eine laufende Mehrspieler-Partie hält an
function Game:Stop()
    local s = self.mp
    self.mpDone = true
    if s and ns.MP.session == s and s.state == "playing" then ns.MP.Pause() end
end

local function row(frames, cards, faceUp)
    for i, f in ipairs(frames) do f:SetCard(cards[i], faceUp) end
end

function Game:Render()
    local s = self.mp
    local st = s and s.board
    if not st then return end
    local me, opp, mine = s.me, 3 - s.me, self:Mine()
    local shown = st.last ~= nil and st.last.why == "show"
    row(self.oppCards, st.cards[opp], shown)
    row(self.myCards, st.cards[me], true)
    row(self.boardCards, st.board, true)
    for i, f in ipairs(self.myCards) do f:SetSelected(st.phase == "swap" and self.mark[i]) end
    local function label(seat, name)
        local t = (L["%s – %d gold"]):format(name, st.chips[seat] - st.put[seat])
        if st.put[seat] > 0 then t = t .. (L["  ·  bet %d"]):format(st.put[seat]) end
        if st.dealer == seat then t = t .. "  ·  " .. L["dealer"] end
        return t
    end
    self.oppLabel:SetText(label(opp, s.partner))
    self.myLabel:SetText(label(me, L["You"]))
    self.pot:SetText(st.phase == "done" and "" or (L["Pot: %d"]):format(st.put[1] + st.put[2]))
    self.log:SetText(lastText(s, st))
    local b1, b2, b3 = self.btn[1], self.btn[2], self.btn[3]
    local bet = st.phase == "bet"
    b1:SetShown(bet and not self.mpDone); b3:SetShown(bet and not self.mpDone); b2:SetShown(not self.mpDone)
    for _, b in ipairs(self.btn) do b:SetEnabled(mine) end
    local status
    if st.phase == "done" then
        b2:SetText(L["Next hand (Space)"])
        status = mine and L["Deal the next hand."] or (L["Waiting for %s …"]):format(s.partner)
    elseif st.phase == "swap" then
        local n = 0
        for i = 1, 5 do if self.mark[i] then n = n + 1 end end
        b2:SetText(n == 0 and L["Keep all (Space)"] or (L["Swap %d (Space)"]):format(n))
        status = mine and L["Click the cards you want to swap."] or (L["Waiting for %s …"]):format(s.partner)
    else
        local need = st.put[opp] - st.put[me]
        b1:SetText(L["Fold (1)"])
        b2:SetText(need > 0 and (L["Call %d (2)"]):format(math.min(need, st.chips[me] - st.put[me])) or L["Check (2)"])
        b3:SetText((L["Raise to %d (3)"]):format(math.min(st.chips[me], st.put[opp] + st.v.bets[st.round])))
        b3:SetEnabled(mine and R.CanRaise(st, me))
        status = mine and L["Your turn."] or (L["Waiting for %s …"]):format(s.partner)
    end
    if st.swapN[opp] and st.phase ~= "done" then status = status .. "  " .. (L["%s swapped %d."]):format(s.partner, st.swapN[opp]) end
    self.status:SetText(self.mpDone and "" or status)
end

function Game:Info()
    local s = self.mp
    local st = s and s.board
    if not st then return {} end
    return {
        { L["Hand"], ("%d/%d"):format(st.hand, st.v.hands) },
        { L["Your gold"], tostring(st.chips[s.me]) },
        { s.partner, tostring(st.chips[3 - s.me]) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, oppCards = {}, myCards = {}, boardCards = {}, btn = {}, mark = {}, score = 0 }, Game)
    local felt = ns.NewTexture(board, "BACKGROUND")
    felt:SetAllPoints()
    ns.Paint(felt, 0.06, 0.2, 0.12, 1)
    local CW, CH, STEP = 54, 76, 60
    local x0 = (W - (4 * STEP + CW)) / 2
    g.oppLabel = ns.FontString(board, "GameFontNormal", "CENTER")
    g.oppLabel:SetPoint("TOP", 0, -8)
    g.pot = ns.FontString(board, "GameFontNormal", "CENTER")
    g.pot:SetPoint("TOP", 0, -112)
    g.status = ns.FontString(board, "GameFontHighlight", "CENTER")
    g.status:SetPoint("TOP", 0, -214)
    g.status:SetWidth(W - 20)
    g.log = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
    g.log:SetPoint("TOP", 0, -232)
    g.log:SetWidth(W - 20)
    g.myLabel = ns.FontString(board, "GameFontNormal", "CENTER")
    g.myLabel:SetPoint("BOTTOM", 0, 126)
    for i = 1, 5 do
        local f = Cards.Create(board, CW, CH)
        f:SetPoint("TOPLEFT", board, "TOPLEFT", x0 + (i - 1) * STEP, -28)
        f:Hide()
        g.oppCards[i] = f
        f = Cards.Create(board, CW, CH)
        f:SetPoint("TOPLEFT", board, "TOPLEFT", x0 + (i - 1) * STEP, -132)
        f:Hide()
        g.boardCards[i] = f
        f = Cards.Create(board, CW, CH)
        f:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", x0 + (i - 1) * STEP, 44)
        f:SetScript("OnClick", function() if host:IsRunning() then ns.Safe("pokerduel", g.Click, g, i) end end)
        f:Hide()
        g.myCards[i] = f
    end
    local moves = { function() g:Move(FOLD) end, function() g:Main() end, function() g:Move(RAISE) end }
    for i = 1, 3 do
        local b = ns.CreateButton(board, "", 138, function() if host:IsRunning() then ns.Safe("pokerduel", moves[i]) end end)
        b:SetHeight(26)
        b:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", 8 + (i - 1) * 143, 10)
        g.btn[i] = b
    end
    return g
end

ns.RegisterGame({
    id = "pokerduel",
    name = L["Poker for two"],
    short = L["Poker for two"],
    mpOnly = true,
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Maelstrom_01",
    width = W, height = H,
    desc = L["Poker against another player: the better hand wins what both have bet."],
    controls = L["1: fold · 2: check or call · 3: raise · Space: swap cards or deal the next hand · click or 1–5: mark cards to swap"],
    controlsShort = L["1: fold · 2: call\n3: raise\nSpace: swap / next hand"],
    winsCards = true,
    wins = function() return Cards.Ranking(L["In Hold'em your best five out of seven cards count. Equal hands: nobody wins the pot."]) end,
    Create = Create,
})
