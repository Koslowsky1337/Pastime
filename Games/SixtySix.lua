-- Pastime: Sechsundsechzig – Stichspiel für genau zwei, nur im Mehrspieler.
-- 24 Karten (9 bis Ass), sechs auf der Hand, eine Trumpfkarte offen unter dem Stapel. Augen: Ass 11,
-- Zehn 10, König 4, Dame 3, Bube 2, Neun 0. Solange der Stapel liegt, darf man beliebig zugeben und
-- zieht nach jedem Stich nach; danach herrscht Farb- und Trumpfzwang. König und Dame einer Farbe beim
-- Ausspielen ansagen: 20 Augen, in Trumpf 40. Wer zuerst 66 Augen hat, gewinnt; sonst der letzte Stich.
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 440, 440
local ORDER = { 9, 11, 12, 13, 10, 1 }      -- von schwach nach stark
local POINTS = { 0, 2, 3, 4, 10, 11 }
local QUEEN, KING = 3, 4                     -- Stärke von Dame und König
local GOAL = 66

---------------------------------------------------------------------------
-- Regelwerk. Züge: Kartennummer 1–24 · 100 + Kartennummer: ausspielen und das Paar ansagen
---------------------------------------------------------------------------
local R = {}

local function sort(hand)
    table.sort(hand, function(a, b) return a.id < b.id end)
end

function R.New(seed, first)
    local rnd = ns.RNG(seed)
    local deck = {}
    for s = 1, 4 do
        for k, r in ipairs(ORDER) do deck[#deck + 1] = { rank = r, suit = s, k = k, id = (s - 1) * 6 + k } end
    end
    Cards.Shuffle(deck, rnd)
    local st = { hands = { {}, {} }, stock = deck, pts = { 0, 0 }, tricks = { 0, 0 }, seq = 0, toAct = first == 2 and 2 or 1 }
    for seat = 1, 2 do
        for _ = 1, 6 do table.insert(st.hands[seat], table.remove(deck)) end
        sort(st.hands[seat])
    end
    st.trumpCard = table.remove(deck)
    st.trump = st.trumpCard.suit
    table.insert(deck, 1, st.trumpCard)      -- liegt offen unter dem Stapel und wird als Letzte gezogen
    return st
end

local function find(hand, id)
    for i, c in ipairs(hand) do if c.id == id then return i, c end end
end

local function has(hand, suit)
    for _, c in ipairs(hand) do if c.suit == suit then return true end end
    return false
end

-- König und Dame derselben Farbe auf der Hand?
function R.Pair(hand, card)
    if card.k ~= QUEEN and card.k ~= KING then return false end
    return find(hand, card.id + (card.k == QUEEN and 1 or -1)) ~= nil
end

-- Darf diese Karte zugegeben werden? Mit Stapel alles; ohne: Farbe bedienen, sonst Trumpf, sonst beliebig
function R.Fits(st, hand, card)
    if not st.lead or #st.stock > 0 then return true end
    if has(hand, st.lead.suit) then return card.suit == st.lead.suit end
    if has(hand, st.trump) then return card.suit == st.trump end
    return true
end

function R.Legal(st, seat, v)
    if st.over or seat ~= st.toAct or type(v) ~= "number" or v ~= math.floor(v) or v < 1 then return false end
    local hand = st.hands[seat]
    local _, card = find(hand, v % 100)
    if not card then return false end
    if v >= 100 then return v < 200 and st.lead == nil and R.Pair(hand, card) end
    return R.Fits(st, hand, card)
end

function R.Apply(st, seat, v)
    local other, hand = 3 - seat, st.hands[seat]
    local i, card = find(hand, v % 100)
    st.seq = st.seq + 1
    if not st.lead then
        st.pair = nil
        if v >= 100 then
            st.pair = { seat = seat, n = card.suit == st.trump and 40 or 20 }
            st.pts[seat] = st.pts[seat] + st.pair.n
        end
        table.remove(hand, i)
        st.lead, st.leader, st.toAct = card, seat, other
        if st.pts[seat] >= GOAL then st.over = true; return seat end
        return nil, other
    end
    table.remove(hand, i)
    local lead = st.lead
    local w = st.leader
    if (card.suit == lead.suit and card.k > lead.k) or (card.suit ~= lead.suit and card.suit == st.trump) then w = seat end
    st.pts[w] = st.pts[w] + POINTS[lead.k] + POINTS[card.k]
    st.tricks[w] = st.tricks[w] + 1
    st.last = { lead = lead, follow = card, leader = st.leader, winner = w }
    st.lead, st.leader = nil, nil
    if #st.stock > 0 then      -- der Gewinner zieht zuerst
        table.insert(st.hands[w], table.remove(st.stock))
        table.insert(st.hands[3 - w], table.remove(st.stock))
        sort(st.hands[1]); sort(st.hands[2])
    end
    if st.pts[w] >= GOAL or #st.hands[1] == 0 then st.over = true; return w end      -- 66 erreicht, oder der letzte Stich
    st.toAct = w
    return nil, w
end

ns.MP.Register("sixtysix", { New = R.New, Legal = R.Legal, Apply = R.Apply })

---------------------------------------------------------------------------
-- Brett
---------------------------------------------------------------------------
local Game = { R = R }
Game.__index = Game

function Game:Start()
    self.mpDone, self.wasMine = nil, nil
    self:Sync()
end

function Game:Mine()
    local s = self.mp
    return s and ns.MP.session == s and s.state == "playing" and s.turn == s.me and not s.replaying
end

-- Klick auf eine Handkarte: ausspielen oder zugeben. König oder Dame mit Partner wird beim Ausspielen angesagt.
function Game:Click(i)
    if not self:Mine() then return end
    local st = self.mp.board
    local hand = st.hands[self.mp.me]
    local card = hand[i]
    if not card or not R.Fits(st, hand, card) then return end
    local v = card.id + ((not st.lead and R.Pair(hand, card)) and 100 or 0)
    if ns.MP.Move(v) then self.host:Sound("click") end
end

function Game:Key(k, down)
    local n = tonumber(k)
    if not n or n < 1 or n > 6 then return false end
    if down then self:Click(n) end
    return true
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
    if s.state == "over" then
        self.mpDone = true
        self:Render()
        local why = s.why == "gave up" and L["You gave up."] or (s.why == "partner gave up" and L["Your opponent gave up."] or nil)
        return self.host:Over({ submit = false, won = s.result == 2, title = s.result == 0 and L["Defeat"] or nil,
            text = why or (L["You: %d points · %s: %d points"]):format(st.pts[s.me], s.partner, st.pts[3 - s.me]) })
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
    local me, opp, mine = s.me, 3 - s.me, self:Mine()
    local hand = st.hands[me]
    for i, f in ipairs(self.myCards) do
        f:SetCard(hand[i], true)
        if hand[i] then f:SetSelected(mine and st.lead ~= nil and #st.stock == 0 and R.Fits(st, hand, hand[i])) end
    end
    for i, f in ipairs(self.oppCards) do f:SetCard(st.hands[opp][i], false) end
    -- Mitte: die ausgespielte Karte; sonst der letzte Stich
    local a, b, note = nil, nil, ""
    if st.lead then
        a = st.lead
        note = st.leader == me and L["You lead."] or (L["%s leads."]):format(s.partner)
    elseif st.last then
        a, b = st.last.lead, st.last.follow
        note = st.last.winner == me and L["Your trick."] or (L["%s takes the trick."]):format(s.partner)
    end
    if st.pair and (st.lead or st.last) then
        note = note .. "  " .. (st.pair.seat == me and L["You announce a pair: +%d."] or L["A pair is announced: +%d."]):format(st.pair.n)
    end
    self.tableCards[1]:SetCard(a, true)
    self.tableCards[2]:SetCard(b, true)
    self.note:SetText(note)
    self.trumpCard:SetCard(#st.stock > 0 and st.trumpCard or nil, true)
    local suit = Cards.SUITS[st.trump]
    self.trumpText:SetText((L["Trump: %s"]):format(suit.name .. " " .. suit.glyph) .. "\n"
        .. (#st.stock > 0 and (L["Stock: %d"]):format(#st.stock) or L["Stock empty: follow suit, or trump."]))
    local status
    if self.mpDone then status = ""
    elseif not mine then status = (L["Waiting for %s …"]):format(s.partner)
    elseif st.lead then status = #st.stock > 0 and L["Your turn: play any card."] or L["Your turn: follow suit; if you cannot, trump."]
    else status = L["Your lead: play a card."] end
    self.status:SetText(status)
end

function Game:Info()
    local s = self.mp
    local st = s and s.board
    if not st then return {} end
    return {
        { L["Your points"], ("%d/%d"):format(st.pts[s.me], GOAL) },
        { s.partner, ("%d/%d"):format(st.pts[3 - s.me], GOAL) },
        { L["Tricks"], ("%d : %d"):format(st.tricks[s.me], st.tricks[3 - s.me]) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, myCards = {}, oppCards = {}, tableCards = {}, score = 0 }, Game)
    local felt = ns.NewTexture(board, "BACKGROUND")
    felt:SetAllPoints()
    ns.Paint(felt, 0.06, 0.2, 0.12, 1)
    local CW, CH, STEP = 54, 76, 60
    local x0 = (W - (5 * STEP + CW)) / 2
    for i = 1, 6 do
        local f = Cards.Create(board, CW, CH)
        f:SetPoint("TOPLEFT", board, "TOPLEFT", x0 + (i - 1) * STEP, -10)
        f:Hide()
        g.oppCards[i] = f
        f = Cards.Create(board, CW, CH)
        f:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", x0 + (i - 1) * STEP, 14)
        f:SetScript("OnClick", function() if host:IsRunning() then ns.Safe("sixtysix", g.Click, g, i) end end)
        f:Hide()
        g.myCards[i] = f
    end
    g.trumpCard = Cards.Create(board, CW, CH)
    g.trumpCard:SetPoint("TOPLEFT", board, "TOPLEFT", 14, -140)
    g.trumpCard:Hide()
    g.trumpText = ns.FontString(board, "GameFontHighlightSmall", "LEFT")
    g.trumpText:SetPoint("TOPLEFT", board, "TOPLEFT", 14, -222)
    g.trumpText:SetWidth(130)
    for i = 1, 2 do
        local f = Cards.Create(board, 64, 90)
        f:SetPoint("TOP", board, "TOP", 20 + (i - 1) * 72, -134)
        f:Hide()
        g.tableCards[i] = f
    end
    g.note = ns.FontString(board, "GameFontHighlightSmall", "CENTER")
    g.note:SetPoint("TOP", board, "TOP", 56, -230)
    g.note:SetWidth(250)
    g.status = ns.FontString(board, "GameFontNormal", "CENTER")
    g.status:SetPoint("BOTTOM", board, "BOTTOM", 0, 100)
    g.status:SetWidth(W - 20)
    return g
end

ns.HELP.sixtysix = L["You play with 24 cards, from 9 to ace. Each of you holds six; one card lies face up under the stock and shows the trump suit. One of you leads a card, the other adds one; the higher card of the suit led takes the trick, and a trump beats any other suit. Card points: ace 11, ten 10, king 4, queen 3, jack 2, nine 0 – so the ten beats the king. Whoever takes the trick draws first and leads next. While the stock lasts you may add any card. Once it is gone you must follow suit, and trump if you cannot. If you lead a king or queen while holding the other one of that suit, the pair is announced for you: 20 points, 40 in trumps. The first to reach 66 points wins; if nobody does, the last trick decides."]

ns.RegisterGame({
    id = "sixtysix",
    name = L["Sixty-Six"],
    short = L["Trick game for two"],
    mpOnly = true,
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Maelstrom_01",
    width = W, height = H,
    desc = L["Take tricks and collect card points. The first to reach 66 wins."],
    controls = L["Click a card to play it · or keys 1–6 · a king-queen pair is announced automatically when you lead one of them"],
    controlsShort = L["Click or 1–6:\nplay a card"],
    Create = Create,
})
