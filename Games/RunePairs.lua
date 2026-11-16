-- Pastime: Runenpaare – Kartenpaare mit WoW-Symbolen finden
local ADDON, ns = ...
local L = ns.L

local MODES = {
    { id = "leicht", name = L["Easy (4×4)"], cols = 4, rows = 4, w = 96, h = 96, gap = 8 },
    { id = "mittel", name = L["Medium (6×5)"], cols = 6, rows = 5, w = 64, h = 76, gap = 6 },
}
local MODE_BY_ID = {}
for _, m in ipairs(MODES) do MODE_BY_ID[m.id] = m end

local ICONS = {
    "Spell_Fire_Fireball02", "Spell_Frost_FrostBolt02", "Spell_Nature_Lightning", "INV_Sword_04", "INV_Axe_01",
    "INV_Shield_06", "INV_Helmet_03", "INV_Potion_51", "INV_Misc_Food_14", "INV_Misc_Herb_10", "INV_Jewelry_Ring_03",
    "INV_Misc_Rune_01", "INV_Misc_Head_Dragon_01", "Ability_Hunter_Pet_Cat", "Ability_Hunter_Pet_Wolf",
    "Ability_Hunter_Pet_Raptor", "INV_Misc_Horn_01", "INV_Misc_Lantern_01", "Spell_Shadow_ShadowBolt",
    "INV_Staff_08", "Ability_Hunter_Pet_Owl", "INV_Misc_Flower_02",
}

local Game = {}
Game.__index = Game

local function fmtTime(s)
    s = math.floor(s or 0)
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

function Game:BuildSet(m)
    local set = { cards = {} }
    local f = CreateFrame("Frame", nil, self.board)
    f:SetSize(m.cols * (m.w + m.gap) - m.gap, m.rows * (m.h + m.gap) - m.gap)
    f:SetPoint("CENTER")
    set.frame = f
    for i = 1, m.cols * m.rows do
        local col, row = (i - 1) % m.cols, math.floor((i - 1) / m.cols)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(m.w, m.h)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", col * (m.w + m.gap), -row * (m.h + m.gap))
        b:RegisterForClicks("LeftButtonDown")
        b.back = ns.NewTexture(b, "BACKGROUND")
        b.back:SetAllPoints()
        b.emblem = b:CreateTexture(nil, "BORDER")
        b.emblem:SetTexture(ns.IsAlliance() and "Interface\\TargetingFrame\\UI-PVP-Alliance" or "Interface\\TargetingFrame\\UI-PVP-Horde")
        b.emblem:SetSize(m.w * 0.7, m.w * 0.7)
        b.emblem:SetPoint("CENTER")
        b.emblem:SetAlpha(0.35)
        b.face = ns.NewTexture(b, "BACKGROUND", 1)
        b.face:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 6, -6)
        b.icon:SetPoint("BOTTOMRIGHT", -6, 6)
        b:SetHighlightTexture(ns.TEX.cellHi, "ADD")
        b.index = i
        b:SetScript("OnClick", function(btn)
            if self.host:IsRunning() then ns.Safe("runepairs", self.Flip, self, btn.index) end
        end)
        set.cards[i] = b
    end
    return set
end

function Game:Draw(i)
    local c, b = self.cards[i], self.set.cards[i]
    if c.up or c.done then
        b.back:Hide(); b.emblem:Hide()
        b.face:Show(); b.icon:Show()
        ns.SetIcon(b.icon, "Interface\\Icons\\" .. c.icon)
        if c.done then ns.Paint(b.face, 0.85, 0.7, 0.25, 1, 0.75) else ns.Paint(b.face, 0.85, 0.8, 0.65, 1, 0.8) end
        b.icon:SetAlpha(c.done and 0.85 or 1)
    else
        b.face:Hide(); b.icon:Hide()
        b.back:Show(); b.emblem:Show()
        local back = ns.THEME.card      -- Rückseite in der Fraktionsfarbe
        ns.Paint(b.back, back[1], back[2], back[3], 1, 0.55)
    end
end

function Game:Start(mode)
    local m = MODE_BY_ID[mode or ""] or MODES[1]
    if self.mp then m = MODE_BY_ID.mittel end      -- Duell: 15 Paare, also nie unentschieden
    self.m = m
    for _, s in pairs(self.sets) do s.frame:Hide() end
    self.sets[m.id] = self.sets[m.id] or self:BuildSet(m)
    self.set = self.sets[m.id]
    self.set.frame:Show()
    local n = m.cols * m.rows
    local pool = {}
    for _, ic in ipairs(ICONS) do pool[#pool + 1] = ic end
    for i = #pool, 2, -1 do local j = math.random(i); pool[i], pool[j] = pool[j], pool[i] end
    local deck = {}
    for p = 1, n / 2 do deck[#deck + 1] = pool[p]; deck[#deck + 1] = pool[p] end
    for i = #deck, 2, -1 do local j = math.random(i); deck[i], deck[j] = deck[j], deck[i] end
    self.cards = {}
    for i = 1, n do self.cards[i] = { icon = deck[i], up = false, done = false } end
    if self.mp then self.cards = self.mp.board.cards end      -- das Brett gehört der Sitzung
    self.mpDone, self.seen, self.wasMine = nil, 0, nil
    self.open, self.lockT = {}, nil
    self.moves, self.pairs, self.total = 0, 0, n / 2
    self.time, self.started, self.score, self.won = 0, false, 0, false
    for i = 1, n do self:Draw(i) end
    if self.mp then self:Sync() end
end

-- Mehrspieler: Stand der Sitzung aufs Brett bringen (nach jedem Zug, bei Ende und Unterbrechung)
function Game:Sync()
    local s = self.mp
    if not s or self.mpDone then return end
    if ns.MP.session ~= s then
        self.mpDone, self.won = true, true
        return self.host:Over({ submit = false, title = L["Interrupted"],
            text = L["The game is paused and does not count. Ask the same player again within ten minutes to continue it."] })
    end
    local st = s.board
    -- ein neues falsches Paar bleibt kurz offen liegen, für beide
    if st.n ~= self.seen then
        self.seen = st.n
        if self.lockT then self:CoverOpen() end
        if st.miss then self.open, self.lockT = { st.miss[1], st.miss[2] }, 1.5 end
        self.host:Sound(st.miss and "click" or "point")
    end
    for i, c in ipairs(self.cards) do
        c.up = i == st.open or (self.lockT ~= nil and (i == self.open[1] or i == self.open[2]))
        self:Draw(i)
    end
    self.pairs, self.total = st.pairs[s.me], #self.cards / 2
    if s.state == "over" then
        self.mpDone, self.won = true, true
        local why = s.why == "gave up" and L["You gave up."] or (s.why == "partner gave up" and L["Your opponent gave up."] or nil)
        return self.host:Over({ submit = false, won = s.result == 2, title = s.result == 0 and L["Defeat"] or (s.result == 1 and L["Draw"] or nil),
            text = why or (L["You found %d pairs, %s found %d."]):format(st.pairs[s.me], s.partner, st.pairs[3 - s.me]) })
    end
    local mine = s.turn == s.me and not s.replaying
    if mine and self.wasMine == false then self.host:Sound("point") end
    self.wasMine = mine
    self.host:Refresh()
end

-- Das Brett wird verlassen: eine laufende Mehrspieler-Partie hält an
function Game:Stop()
    local s = self.mp
    self.mpDone = true
    if s and ns.MP.session == s and s.state == "playing" then ns.MP.Pause() end
end

function Game:Flip(i)
    if self.won then return end
    if self.mp then
        -- nur wer dran ist, deckt auf; gesendet wird die Karte
        if ns.MP.Move(i) then self.host:Sound("click") end
        return
    end
    -- falsches Paar liegt noch offen: sofort zudecken statt warten
    if self.lockT then self:CoverOpen() end
    local c = self.cards[i]
    if not c or c.up or c.done then return end
    self.started = true
    c.up = true
    table.insert(self.open, i)
    self:Draw(i)
    self.host:Sound("click")
    if #self.open == 2 then
        self.moves = self.moves + 1
        self.score = self.moves        -- große Anzeige zählt mit; gewertet wird erst das gelöste Spiel
        local a, b = self.cards[self.open[1]], self.cards[self.open[2]]
        if a.icon == b.icon then
            a.done, b.done = true, true
            self:Draw(self.open[1]); self:Draw(self.open[2])
            self.open = {}
            self.pairs = self.pairs + 1
            self.host:Sound("point")
            if self.pairs == self.total then
                self.won = true
                self.score = self.moves
                self.host:Over({ score = self.moves, won = true,
                    text = (L["Found all %d pairs in %s."]):format(self.total, fmtTime(self.time)) })
            end
        else
            self.lockT = 0.8
        end
    end
    self.host:Refresh()
end

function Game:CoverOpen()
    self.lockT = nil
    for _, i in ipairs(self.open) do
        self.cards[i].up = self.mp ~= nil and self.mp.board.open == i
        self:Draw(i)
    end
    self.open = {}
end

function Game:Update(dt)
    if self.started and not self.won then self.time = self.time + dt end
    if self.lockT then
        self.lockT = self.lockT - dt
        if self.lockT <= 0 then self:CoverOpen() end
    end
end

function Game:Info()
    local s = self.mp
    if s and s.board then
        return {
            { L["Your pairs"], tostring(s.board.pairs[s.me]) },
            { s.partner, tostring(s.board.pairs[3 - s.me]) },
            { L["Turn"], s.state ~= "playing" and "–" or (s.turn == s.me and L["You"] or s.partner) },
        }
    end
    return {
        { L["Pairs"], ("%d/%d"):format(self.pairs or 0, self.total or 8) },
        { L["Moves"], tostring(self.moves or 0) },
        { L["Time"], fmtTime(self.time) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, sets = {}, score = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    ns.Paint(bg, 0.1, 0.08, 0.06, 1)
    return g
end

-- Regelwerk für den Mehrspieler: ein gemeinsames Brett mit 15 Paaren. Wer dran ist, deckt zwei Karten auf
-- (zwei Züge, gesendet wird jeweils die Karte); ein Paar gehört ihm und er ist noch einmal dran.
ns.MP.Register("runepairs", {
    New = function(seed)
        local rnd = ns.RNG(seed)
        local pool, deck, cards = {}, {}, {}
        for _, ic in ipairs(ICONS) do pool[#pool + 1] = ic end
        for i = #pool, 2, -1 do local j = rnd(i); pool[i], pool[j] = pool[j], pool[i] end
        for p = 1, 15 do deck[#deck + 1] = pool[p]; deck[#deck + 1] = pool[p] end
        for i = #deck, 2, -1 do local j = rnd(i); deck[i], deck[j] = deck[j], deck[i] end
        for i = 1, 30 do cards[i] = { icon = deck[i], up = false, done = false } end
        return { cards = cards, pairs = { 0, 0 }, n = 0 }
    end,
    Legal = function(st, _, i)
        local c = type(i) == "number" and st.cards[i]
        return c ~= nil and c ~= false and not c.done and st.open ~= i
    end,
    Apply = function(st, seat, i)
        if not st.open then st.open = i; return nil, seat end
        local a, b = st.cards[st.open], st.cards[i]
        st.n = st.n + 1
        if a.icon ~= b.icon then
            st.miss, st.open = { st.open, i }, nil
            return nil
        end
        a.done, b.done, st.open, st.miss = true, true, nil, nil
        st.pairs[seat] = st.pairs[seat] + 1
        if st.pairs[1] + st.pairs[2] == 15 then return st.pairs[1] > st.pairs[2] and 1 or 2 end
        return nil, seat
    end,
})

ns.RegisterGame({
    id = "runepairs",
    name = L["Rune Pairs"],
    short = L["Matching pairs"],
    aliases = { "paare", "karten", "pairs", "runes", "runepairs", "runenpaare" },
    category = "knobeln",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Rune_01",
    width = 420, height = 420,
    modes = { { id = "leicht", name = L["Easy (4×4)"] }, { id = "mittel", name = L["Medium (6×5)"] } },
    lowerIsBetter = true,
    scoreLabel = L["Moves"],
    FormatScore = function(s) return (L["%d moves"]):format(s or 0) end,
    desc = L["Turn over two cards – if they show the same symbol, they stay face up. Find all pairs in as few moves as possible. Only solved games are scored."],
    controls = L["Click a card to turn it over"],
    controlsShort = L["Click: turn over a card"],
    Create = Create,
})
