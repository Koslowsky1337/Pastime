-- Pastime: Mau-Mau – nur im Mehrspieler. Zwei Spieler, auf Wunsch mit ein oder zwei Bots am Tisch.
-- 32 Karten (7 bis Ass). Bedienen nach Farbe oder Wert; 7: der Nächste zieht zwei (oder legt selbst
-- eine 7), 8: der Nächste setzt aus, Bube: passt auf alles außer auf einen Buben und wünscht eine Farbe.
-- Beide Seiten führen denselben Zustand; die Bots ziehen nach festen Regeln, also auf beiden Seiten gleich.
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 440, 440
local RANKS = { 7, 8, 9, 10, 11, 12, 13, 1 }
local SEVEN, EIGHT, JACK = 7, 8, 11
local BOTS = { "Grix", "Nazz" }

---------------------------------------------------------------------------
-- Regelwerk. Züge: 0 ziehen · -1 passen (nach dem Ziehen) · Kartennummer 1–32 legen ·
-- Bube: 100 × gewünschte Farbe + Kartennummer
---------------------------------------------------------------------------
local R = {}

function R.New(seed, bots)
    local rnd = ns.RNG(seed)
    local deck = {}
    for s = 1, 4 do
        for k, r in ipairs(RANKS) do deck[#deck + 1] = { rank = r, suit = s, id = (s - 1) * 8 + k } end
    end
    Cards.Shuffle(deck, rnd)
    local st = { rnd = rnd, n = 2 + bots, hands = {}, pile = deck, discard = {}, pend = 0, drew = false, idle = 0, events = {}, seq = 0 }
    -- Sitzordnung: Spieler 1, (Bot), Spieler 2, (Bot)
    st.human = bots == 0 and { 1, 2 } or { 1, 3 }
    st.seat = { [st.human[1]] = 1, [st.human[2]] = 2 }
    for p = 1, st.n do
        st.hands[p] = {}
        for _ = 1, 5 do table.insert(st.hands[p], table.remove(deck)) end
    end
    local top = table.remove(deck)
    while top.rank == JACK or top.rank == SEVEN or top.rank == EIGHT do      -- die erste Karte hat keine Wirkung
        table.insert(deck, 1, top)
        top = table.remove(deck)
    end
    st.top, st.suit = top, top.suit
    return st
end

function R.Fits(st, card)
    if st.pend > 0 then return card.rank == SEVEN end
    if card.rank == JACK then return st.top.rank ~= JACK end
    return card.suit == st.suit or card.rank == st.top.rank
end

local function draw(st, pos, k)
    local got = 0
    for _ = 1, k do
        if #st.pile == 0 then st.pile, st.discard = Cards.Shuffle(st.discard, st.rnd), {} end      -- Ablage neu mischen
        if #st.pile == 0 then break end
        table.insert(st.hands[pos], table.remove(st.pile))
        got = got + 1
    end
    st.events[#st.events + 1] = { pos = pos, kind = "draw", n = got }
    if got > 0 then st.idle = 0 end
    return got
end

local function advance(st, skip)
    st.cur, st.drew = st.cur % st.n + 1, false
    if skip then
        st.events[#st.events + 1] = { pos = st.cur, kind = "skip" }
        st.cur = st.cur % st.n + 1
    end
end

-- true: das war die letzte Karte
local function play(st, pos, i, wish)
    local card = table.remove(st.hands[pos], i)
    st.discard[#st.discard + 1] = st.top
    st.top, st.suit = card, card.rank == JACK and wish or card.suit
    if card.rank == SEVEN then st.pend = st.pend + 2 end
    st.idle = 0
    st.events[#st.events + 1] = { pos = pos, kind = "play", card = card, wish = card.rank == JACK and wish or nil }
    if #st.hands[pos] == 0 then st.winner = pos; return true end
    advance(st, card.rank == EIGHT)
end

local function pass(st, pos)
    st.events[#st.events + 1] = { pos = pos, kind = "pass" }
    st.idle = st.idle + 1
    advance(st)
end

-- Bot: 7 vor 8 vor einer passenden Karte vor dem Buben; sonst ziehen. Gewünscht wird die Farbe, die er am meisten hat.
local function bot(st, pos)
    local hand = st.hands[pos]
    local function pick()
        local best, score
        for i, c in ipairs(hand) do
            if R.Fits(st, c) then
                local v = (c.rank == SEVEN and 3 or (c.rank == EIGHT and 2 or (c.rank == JACK and 0 or 1))) * 100 - c.id
                if not score or v > score then best, score = i, v end
            end
        end
        return best
    end
    local function wish(skip)
        local n, w = { 0, 0, 0, 0 }, hand[skip].suit
        for i, c in ipairs(hand) do if i ~= skip then n[c.suit] = n[c.suit] + 1 end end
        for s = 4, 1, -1 do if n[s] > 0 and n[s] >= n[w] then w = s end end
        return w
    end
    local i = pick()
    if not i and st.pend > 0 then
        draw(st, pos, st.pend)
        st.pend = 0
        return advance(st)
    end
    if not i then
        draw(st, pos, 1)
        i = pick()
        if not i then return pass(st, pos) end
    end
    return play(st, pos, i, hand[i].rank == JACK and wish(i) or nil)
end

local function find(hand, id)
    for i, c in ipairs(hand) do if c.id == id then return i, c end end
end

function R.Legal(st, seat, v)
    local pos = st.human[seat]
    st.cur = st.cur or pos      -- wer beginnt, bestimmt die Sitzung
    if st.winner or st.cur ~= pos or type(v) ~= "number" or v ~= math.floor(v) then return false end
    if v == 0 then return not st.drew end
    if v == -1 then return st.drew and st.pend == 0 end
    local wish, id = math.floor(v / 100), v % 100
    local _, card = find(st.hands[pos], id)
    if v < 1 or not card or not R.Fits(st, card) then return false end
    if card.rank == JACK then return wish >= 1 and wish <= 4 end
    return wish == 0
end

-- Wer gewonnen hat, als Platz der Sitzung: geht ein Bot zuerst aus oder geht nichts mehr, gewinnt, wer weniger Karten hat
local function result(st)
    st.over = true
    if st.winner and st.seat[st.winner] then return st.seat[st.winner] end
    local a, b = #st.hands[st.human[1]], #st.hands[st.human[2]]
    return a == b and 0 or (a < b and 1 or 2)
end

function R.Apply(st, seat, v)
    local pos = st.human[seat]
    st.cur = st.cur or pos
    st.events, st.seq = {}, st.seq + 1
    if v == 0 and st.pend > 0 then
        draw(st, pos, st.pend)
        st.pend = 0
        advance(st)
    elseif v == 0 then
        draw(st, pos, 1)
        st.drew = true
    elseif v == -1 then
        pass(st, pos)
    else
        local i = find(st.hands[pos], v % 100)
        play(st, pos, i, math.floor(v / 100))
    end
    -- die Bots ziehen gleich mit, bis wieder ein Spieler dran ist
    while not st.winner and not st.seat[st.cur] and st.idle < 2 * st.n do bot(st, st.cur) end
    if st.winner or st.idle >= 2 * st.n then return result(st) end
    return nil, st.seat[st.cur]
end

local VARIANTS = { { "maumau", 0, L["Mau-Mau"] }, { "maumau3", 1, L["Mau-Mau with 1 bot"] }, { "maumau4", 2, L["Mau-Mau with 2 bots"] } }
for _, v in ipairs(VARIANTS) do
    local bots = v[2]
    ns.MP.Register(v[1], { def = "maumau", name = v[3], Legal = R.Legal, Apply = R.Apply,
        New = function(seed) return R.New(seed, bots) end })
end

---------------------------------------------------------------------------
-- Brett
---------------------------------------------------------------------------
local Game = { R = R }
Game.__index = Game

function Game:Name(pos)
    local s, st = self.mp, self.mp.board
    if st.seat[pos] == s.me then return L["You"] end
    if st.seat[pos] then return s.partner end
    return (L["%s (bot)"]):format(BOTS[pos == 2 and 1 or 2])
end

function Game:Start()
    self.mpDone, self.seen, self.wasMine, self.jack = nil, -1, nil, nil
    self:Sync()
end

function Game:Mine()
    local s = self.mp
    return s and ns.MP.session == s and s.state == "playing" and s.turn == s.me and not s.replaying
end

-- Klick auf eine Handkarte: legen; beim Buben erst die Farbe wählen
function Game:Click(i)
    if not self:Mine() then return end
    local st = self.mp.board
    local card = st.hands[st.human[self.mp.me]][i]
    if not card or not R.Fits(st, card) then return end
    if card.rank == JACK then
        self.jack = card.id
        return self:Render()
    end
    if ns.MP.Move(card.id) then self.host:Sound("click") end
end

function Game:Wish(suit)
    if not (self.jack and self:Mine()) then return end
    local id = self.jack
    self.jack = nil
    if ns.MP.Move(suit * 100 + id) then self.host:Sound("click") end
end

-- Ziehen oder – nach dem Ziehen – passen
function Game:DrawOrPass()
    if not self:Mine() then return end
    self.jack = nil
    if ns.MP.Move(self.mp.board.drew and -1 or 0) then self.host:Sound("click") end
end

function Game:Key(k, down)
    if k ~= "SPACE" then return false end
    if down then self:DrawOrPass() end
    return true
end

local function eventText(self, e)
    local who = self:Name(e.pos)
    if e.kind == "play" then
        local t = Cards.Name(e.card)
        if e.wish then t = t .. " – " .. (L["wishes for %s"]):format(Cards.SUITS[e.wish].name) end
        return who .. ": " .. t
    elseif e.kind == "draw" then
        return who .. ": " .. (L["draws %d"]):format(e.n)
    elseif e.kind == "pass" then
        return who .. ": " .. L["passes"]
    end
    return who .. ": " .. L["sits out"]
end

-- Mehrspieler: Stand der Sitzung aufs Brett bringen (nach jedem Zug, bei Ende und Unterbrechung)
function Game:Sync()
    local s = self.mp
    if not s or self.mpDone then return end
    if ns.MP.session ~= s then
        self.mpDone = true
        self:Render()
        return self.host:Over({ submit = false, title = L["Interrupted"],
            text = L["The game is paused and does not count. Ask the same player again within ten minutes to continue it."] })
    end
    local st = s.board
    if st.seq ~= self.seen then
        self.seen, self.jack = st.seq, nil
        local lines = {}
        for _, e in ipairs(st.events) do lines[#lines + 1] = eventText(self, e) end
        self.log:SetText(table.concat(lines, "\n"))
    end
    if s.state == "over" then
        self.mpDone = true
        self:Render()
        local mine, theirs = #st.hands[st.human[s.me]], #st.hands[st.human[3 - s.me]]
        local text = s.why == "gave up" and L["You gave up."] or (s.why == "partner gave up" and L["Your opponent gave up."] or nil)
        if not text then
            if st.winner and st.seat[st.winner] == s.me then text = L["You played your last card!"]
            elseif st.winner and st.seat[st.winner] then text = (L["%s played the last card."]):format(s.partner)
            else text = (L["Fewer cards win: you have %d, %s has %d."]):format(mine, s.partner, theirs) end
        end
        return self.host:Over({ submit = false, won = s.result == 2, title = s.result == 0 and L["Defeat"] or (s.result == 1 and L["Draw"] or nil), text = text })
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

function Game:Render()
    local s = self.mp
    local st = s and s.board
    if not st then return end
    local me = st.human[s.me]
    local hand, mine = st.hands[me], self:Mine()
    self.top:SetCard(st.top, true)
    local suit = Cards.SUITS[st.suit]
    self.wish:SetText(st.top.rank == JACK and (L["Wished: %s"]):format(suit.name .. " " .. suit.glyph) or "")
    -- Hand: so weit überlappt, dass alle Karten ins Feld passen
    local step = #hand > 1 and math.min(58, (W - 24 - 54) / (#hand - 1)) or 0
    local x0 = (W - (54 + step * (#hand - 1))) / 2
    for i = 1, math.max(#hand, #self.hand) do
        local f = self.hand[i]
        if hand[i] and not f then
            f = Cards.Create(self.board, 54, 76)
            f:SetScript("OnClick", function() if self.host:IsRunning() then ns.Safe("maumau", self.Click, self, i) end end)
            self.hand[i] = f
        end
        if f then
            f:SetCard(hand[i], true)
            if hand[i] then
                f:ClearAllPoints()
                f:SetPoint("BOTTOMLEFT", self.board, "BOTTOMLEFT", x0 + (i - 1) * step, 44)
                f:SetFrameLevel(self.board:GetFrameLevel() + 2 + i)
                f:SetSelected(mine and (self.jack == hand[i].id or (not self.jack and R.Fits(st, hand[i]))))
            end
        end
    end
    for i = 1, 4 do self.suits[i]:SetShown(mine and self.jack ~= nil) end
    self.drawBtn:SetShown(not self.mpDone)
    self.drawBtn:SetEnabled(mine)
    self.drawBtn:SetText(st.drew and L["Pass (Space)"] or (st.pend > 0 and (L["Draw %d (Space)"]):format(st.pend) or L["Draw (Space)"]))
    local status
    if self.mpDone then status = ""
    elseif not mine then status = (L["Waiting for %s …"]):format(s.partner)
    elseif self.jack then status = L["Which suit do you wish for?"]
    elseif st.pend > 0 then status = (L["Play a 7 or draw %d."]):format(st.pend)
    elseif st.drew then status = L["Play the card you drew, or pass."]
    else status = L["Your turn: play a card that matches suit or value, or draw."] end
    self.status:SetText(status)
end

function Game:Info()
    local s = self.mp
    local st = s and s.board
    if not st then return {} end
    local rows = { { L["Your cards"], tostring(#st.hands[st.human[s.me]]) } }
    for pos = 1, st.n do
        if st.seat[pos] ~= s.me then rows[#rows + 1] = { self:Name(pos), tostring(#st.hands[pos]) } end
    end
    rows[#rows + 1] = { L["Draw pile"], tostring(#st.pile) }
    return rows
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, hand = {}, suits = {}, score = 0 }, Game)
    local felt = ns.NewTexture(board, "BACKGROUND")
    felt:SetAllPoints()
    ns.Paint(felt, 0.06, 0.2, 0.12, 1)
    g.status = ns.FontString(board, "GameFontNormal", "CENTER")
    g.status:SetPoint("TOP", 0, -12)
    g.status:SetWidth(W - 24)
    g.top = Cards.Create(board, 70, 98)
    g.top:SetPoint("TOP", board, "TOP", -60, -56)
    g.wish = ns.FontString(board, "GameFontHighlight", "LEFT")
    g.wish:SetPoint("TOPLEFT", g.top, "TOPRIGHT", 14, -6)
    g.drawBtn = ns.CreateButton(board, L["Draw (Space)"], 150, function() if host:IsRunning() then ns.Safe("maumau", g.DrawOrPass, g) end end)
    g.drawBtn:SetHeight(26)
    g.drawBtn:SetPoint("TOPLEFT", g.top, "TOPRIGHT", 14, -40)
    g.log = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
    g.log:SetPoint("TOP", board, "TOP", 0, -166)
    g.log:SetWidth(W - 24)
    for i = 1, 4 do
        local suit = Cards.SUITS[i]
        local b = ns.CreateButton(board, suit.name, 100, function() if host:IsRunning() then ns.Safe("maumau", g.Wish, g, i) end end)
        b:SetHeight(24)
        b:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", 12 + (i - 1) * 104, 130)
        b:Hide()
        g.suits[i] = b
    end
    return g
end

ns.RegisterGame({
    id = "maumau",
    name = L["Mau-Mau"],
    short = L["Shed your cards"],
    mpOnly = true,
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Maelstrom_01",
    width = W, height = H,
    desc = L["Get rid of all your cards first. Play a card that matches the suit or the value of the top card, or draw."],
    controls = L["Click a card to play it · Space: draw, and pass after drawing · after a jack click the suit you wish for"],
    controlsShort = L["Click: play a card\nSpace: draw / pass"],
    Create = Create,
})
