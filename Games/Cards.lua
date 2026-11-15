-- Pastime: Spielkarten (für Blackjack und Solitär)
-- Farben mit Zeichen (♥♦♠♣ aus ARIALN) und zusätzlich einem Edelstein-Symbol,
-- damit sie auch ohne die Zeichen unterscheidbar bleiben.
local ADDON, ns = ...
local L = ns.L

local Cards = {}
ns.Cards = Cards

Cards.SUITS = {
    { name = L["Hearts"], glyph = "\226\153\165", red = true, icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01" },
    { name = L["Diamonds"], glyph = "\226\153\166", red = true, icon = "Interface\\Icons\\INV_Misc_Gem_Topaz_01" },
    { name = L["Spades"], glyph = "\226\153\160", red = false, icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01" },
    { name = L["Clubs"], glyph = "\226\153\163", red = false, icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01" },
}
-- Ass, Bube, Dame und König: Kürzel je nach Sprache (deDE: A, B, D, K)
Cards.RANKS = { L["A"], "2", "3", "4", "5", "6", "7", "8", "9", "10", L["J"], L["Q"], L["K"] }
local FONT = "Fonts\\ARIALN.TTF"

function Cards.NewDeck()
    local deck = {}
    for s = 1, 4 do
        for r = 1, 13 do deck[#deck + 1] = { rank = r, suit = s } end
    end
    return deck
end

function Cards.Shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function Cards.Name(card)
    return Cards.SUITS[card.suit].name .. " " .. Cards.RANKS[card.rank]
end

local function setFont(fs, size)
    if not (fs.SetFont and fs:SetFont(FONT, size, "")) then fs:SetFontObject(GameFontNormal) end
end

local CardMethods = {}

function CardMethods:SetCard(card, faceUp)
    self.card = card
    if not card then
        self:Hide()
        return
    end
    self:Show()
    local up = faceUp and true or false
    self.face:SetShown(up)
    self.rank:SetShown(up)
    self.suit:SetShown(up)
    self.icon:SetShown(up)
    self.back:SetShown(not up)
    self.emblem:SetShown(not up)
    if up then
        local s = Cards.SUITS[card.suit]
        local r, g, b = 0.08, 0.08, 0.1
        if s.red then r, g, b = 0.75, 0.08, 0.06 end
        self.rank:SetText(Cards.RANKS[card.rank])
        self.rank:SetTextColor(r, g, b)
        self.suit:SetText(s.glyph)
        self.suit:SetTextColor(r, g, b)
        ns.SetIcon(self.icon, s.icon)
    end
end

function CardMethods:SetSelected(on)
    self.sel:SetShown(on and true or false)
end

function Cards.Create(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.edge = ns.Box(b, "BACKGROUND", 0.08, 0.06, 0.04)
    b.edge:SetAllPoints()
    b.face = ns.NewTexture(b, "BORDER")
    b.face:SetPoint("TOPLEFT", 1, -1)
    b.face:SetPoint("BOTTOMRIGHT", -1, 1)
    ns.Paint(b.face, 0.96, 0.93, 0.85, 1, 0.9)
    b.back = ns.NewTexture(b, "BORDER", 1)
    b.back:SetPoint("TOPLEFT", 2, -2)
    b.back:SetPoint("BOTTOMRIGHT", -2, 2)
    local back = ns.THEME.card      -- Kartenrücken in der Fraktionsfarbe
    ns.Paint(b.back, back[1], back[2], back[3], 1, 0.55)
    b.emblem = b:CreateTexture(nil, "ARTWORK")
    b.emblem:SetSize(w * 0.55, w * 0.55)
    b.emblem:SetPoint("CENTER")
    ns.SetIcon(b.emblem, ns.IsAlliance() and "Interface\\Icons\\INV_BannerPVP_02" or "Interface\\Icons\\INV_BannerPVP_01")
    b.emblem:SetAlpha(0.4)
    local size = w >= 60 and 16 or 14
    b.rank = b:CreateFontString(nil, "OVERLAY")
    setFont(b.rank, size)
    b.rank:SetPoint("TOPLEFT", 4, -3)
    b.suit = b:CreateFontString(nil, "OVERLAY")
    setFont(b.suit, size)
    -- neben dem Wert, damit beides auch bei überdeckten Karten sichtbar bleibt
    b.suit:SetPoint("LEFT", b.rank, "RIGHT", 1, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(w * 0.42, w * 0.42)
    b.icon:SetPoint("CENTER", 4, -6)
    b.sel = ns.Box(b, "OVERLAY", 1, 0.82, 0, 0.35)
    b.sel:SetAllPoints()
    b.sel:Hide()
    for k, fn in pairs(CardMethods) do b[k] = fn end
    return b
end

-- Leerer Platz (gestrichelter Rahmen)
function Cards.CreateSlot(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local edge = ns.Box(b, "BACKGROUND", 1, 1, 1, 0.12)
    edge:SetAllPoints()
    local inner = ns.Box(b, "BORDER", 0, 0, 0, 0.35)
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    if label then
        b.label = ns.FontString(b, "GameFontDisableSmall", "CENTER")
        b.label:SetPoint("CENTER")
        b.label:SetText(label)
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(w * 0.45, w * 0.45)
    b.icon:SetPoint("CENTER")
    b.icon:SetAlpha(0.35)
    b.icon:Hide()
    return b
end

---------------------------------------------------------------------------
-- Pokerblatt aus 5 bis 7 Karten: Kategorie (1 höchste Karte … 9 Straight Flush),
-- Vergleichszahl (größer gewinnt) und die Werte in Vergleichsreihenfolge (Ass = 14)
---------------------------------------------------------------------------
Cards.HANDS = { L["High Card"], L["Pair"], L["Two Pair"], L["Three of a Kind"], L["Straight"], L["Flush"],
    L["Full House"], L["Four of a Kind"], L["Straight Flush"] }

local function straightTop(has)
    for hi = 14, 5, -1 do
        local ok = true
        for r = hi, hi - 4, -1 do
            if not has[r == 1 and 14 or r] then ok = false; break end
        end
        if ok then return hi end
    end
end

function Cards.Eval(cards)
    local cnt, suits, has = {}, { {}, {}, {}, {} }, {}
    for _, c in ipairs(cards) do
        local r = c.rank == 1 and 14 or c.rank
        cnt[r] = (cnt[r] or 0) + 1
        has[r] = true
        suits[c.suit][r] = true
    end
    local function top(n, set, skip1, skip2)      -- die n höchsten Werte aus set, ohne skip1/skip2
        local out = {}
        for r = 14, 2, -1 do
            if set[r] and r ~= skip1 and r ~= skip2 then
                out[#out + 1] = r
                if #out == n then break end
            end
        end
        return out
    end
    local function withCount(n, skip)
        for r = 14, 2, -1 do if (cnt[r] or 0) >= n and r ~= skip then return r end end
    end
    local flush
    for s = 1, 4 do
        local n = 0
        for _ in pairs(suits[s]) do n = n + 1 end
        if n >= 5 then flush = suits[s] end
    end
    local cat, t
    local sf = flush and straightTop(flush)
    local four, three = withCount(4), withCount(3)
    local pair = withCount(2, three)
    local st = straightTop(has)
    if sf then cat, t = 9, { sf }
    elseif four then cat, t = 8, { four, top(1, has, four)[1] }
    elseif three and pair then cat, t = 7, { three, pair }
    elseif flush then cat, t = 6, top(5, flush)
    elseif st then cat, t = 5, { st }
    elseif three then
        local k = top(2, has, three)
        cat, t = 4, { three, k[1], k[2] }
    elseif pair then
        local second = withCount(2, pair)
        if second then cat, t = 3, { pair, second, top(1, has, pair, second)[1] }
        else
            local k = top(3, has, pair)
            cat, t = 2, { pair, k[1], k[2], k[3] }
        end
    else cat, t = 1, top(5, has) end
    local v = cat
    for i = 1, 5 do v = v * 15 + (t[i] or 0) end
    return cat, v, t
end

---------------------------------------------------------------------------
-- Goblin-Gold für die Glücksspiele: jedes Spiel hat seinen eigenen Topf; gewertet
-- wird der höchste Goldstand eines Laufs (Pleite oder „Kasse machen“) wie beim Blackjack.
-- Ein Spiel erbt von ns.Gamble und liefert Deal() (nach dem Einsatz) und Render().
---------------------------------------------------------------------------
local Gamble = {}
Gamble.__index = Gamble
ns.Gamble = Gamble
local START_GOLD, MIN_BET = 100, 10
Gamble.START_GOLD, Gamble.MIN_BET = START_GOLD, MIN_BET

-- Einsätze: 10 Gold, ¼ und ½ des Golds (auf 5 abgerundet, mindestens 10)
function Gamble.Bets(gold)
    local function part(f) return math.max(MIN_BET, math.floor(gold * f / 5) * 5) end
    return { MIN_BET, part(0.25), part(0.5) }
end

-- Fester Einsatz (Spiele mit STAKE): einmal einstellen, dann nur noch spielen. Stufen 10, 25, 50,
-- 100, 250 … bis zum eigenen Gold; der Einsatz bleibt im Topf gespeichert.
function Gamble.Ladder(gold)
    local t, base = {}, MIN_BET
    while base <= gold do
        for _, f in ipairs({ 1, 2.5, 5 }) do
            if base * f <= gold then t[#t + 1] = base * f end
        end
        base = base * 10
    end
    return t
end

-- Der eingestellte Einsatz, höchstens so viel, wie das Gold hergibt
function Gamble:Wager()
    local steps = self.Ladder(self.gold or 0)
    local w = steps[1] or MIN_BET
    for _, v in ipairs(steps) do
        if v <= (self.wager or MIN_BET) then w = v end
    end
    return w
end

-- dir: -1 kleiner, 1 größer, "max" höchste Stufe
function Gamble:Stake(dir)
    if self.state ~= "bet" then return end
    local steps, cur, i = self.Ladder(self.gold or 0), self:Wager(), 1
    for k, v in ipairs(steps) do if v == cur then i = k end end
    i = dir == "max" and #steps or math.max(1, math.min(#steps, i + dir))
    self.wager = steps[i] or MIN_BET
    self:Purse().wager = self.wager
    self.host:Sound("click")
    self:Render()
end

function Gamble:Play()
    local amount = self:Wager()
    if self.state ~= "bet" or amount > self.gold then return end
    self:Spend(amount)
    self.host:Sound("click")
    self:Deal(amount)
end

function Gamble:Purse()
    local p = ns.DB.purses[self.id]
    if type(p) ~= "table" then p = {}; ns.DB.purses[self.id] = p end
    return p
end

-- Kontostand sofort sichern: wer mitten in der Hand geht, verliert den Einsatz
function Gamble:Save()
    local p = self:Purse()
    p.gold, p.peak = self.gold, self.peak
end

function Gamble:OpenRun()
    local p = self:Purse()
    if (tonumber(p.gold) or 0) < MIN_BET then p.gold, p.peak = START_GOLD, START_GOLD end
    self.gold = p.gold
    self.peak = math.max(tonumber(p.peak) or 0, self.gold)
    self.score = self.peak
    self.wager = tonumber(p.wager) or MIN_BET
    self:Betting()
end

function Gamble:Betting()
    self.state, self.bet = "bet", 0
    if self.Clear then self:Clear() end
    self.msg:SetText(L["Place your bet!"])
    self.sub:SetText((L["Best this run: %d gold"]):format(self.peak))
    self:Render()
end

function Gamble:Spend(amount)
    self.gold = self.gold - amount
    self.bet = self.bet + amount
    self:Save()
end

function Gamble:PlaceBet(i)
    local amount = self.Bets(self.gold)[i]
    if self.state ~= "bet" or not amount or amount > self.gold then return end
    self:Spend(amount)
    self.host:Sound("click")
    self:Deal(amount)
end

-- Hand abrechnen: win ist die Auszahlung einschließlich Einsatz. wait = Sekunden bis zur
-- nächsten Hand (false: erst auf Tastendruck)
function Gamble:Pay(win, text, wait)
    self.gold = self.gold + win
    self.peak = math.max(self.peak, self.gold)
    self.score = self.peak
    self:Save()
    local diff = win - self.bet
    self.msg:SetText(diff > 0 and ("|cff80ff80+%d Gold|r"):format(diff) or (diff < 0 and ("|cffff6060%d Gold|r"):format(diff) or "±0"))
    self.sub:SetText(text or "")
    self.host:Sound(diff > 0 and "big" or (diff < 0 and "bad" or "click"))
    self.state = "result"
    if wait == nil then self.t = 1.8 else self.t = wait end
    self:Render()
end

function Gamble:Tick(dt)
    if self.state == "result" and self.t then
        self.t = self.t - dt
        if self.t <= 0 then self:Next() end
    end
end

function Gamble:EndRun(res)
    self.state = "over"
    self:Render()
    local p = self:Purse()
    p.gold, p.peak = START_GOLD, START_GOLD
    res.score = self.peak
    if self.peak <= START_GOLD then res.submit = false end      -- nie über dem Startgold: nichts zu werten
    res.text = res.text .. "\n" .. (L["You start again with %d gold."]):format(START_GOLD)
    return self.host:Over(res)
end

function Gamble:Next()
    if self.state ~= "result" then return end
    if self.gold < MIN_BET then
        return self:EndRun({ title = L["Broke!"], text = L["The goblin took your last coin."] })
    end
    self:Betting()
end

-- Kasse machen: den Lauf freiwillig beenden – zwischen zwei Händen und nur mit Gewinn
function Gamble:CashOut()
    if self.state ~= "bet" or self.gold <= START_GOLD then return end
    return self:EndRun({ won = true, text = (L["You leave the table with %d gold."]):format(self.gold) })
end

-- Tasten, die in jedem Glücksspiel gleich sind; true = verbraucht
function Gamble:BaseKey(k, down)
    local act
    if self.state == "bet" and self.STAKE and (k == "1" or k == "LEFT") then act = function() self:Stake(-1) end
    elseif self.state == "bet" and self.STAKE and (k == "2" or k == "RIGHT") then act = function() self:Stake(1) end
    elseif self.state == "bet" and self.STAKE and k == "3" then act = function() self:Stake("max") end
    elseif self.state == "bet" and self.STAKE and (k == "SPACE" or k == "ENTER") then act = function() self:Play() end
    elseif self.state == "bet" and (k == "1" or k == "2" or k == "3") then act = function() self:PlaceBet(tonumber(k)) end
    elseif self.state == "bet" and k == ns.KEYS.cash then act = function() self:CashOut() end
    elseif self.state == "result" and (k == "SPACE" or k == "ENTER") then act = function() self:Next() end
    end
    if not act then return false end
    if down then act() end
    return true
end

function Gamble:BaseRender()
    self.goldText:SetText((L["Goblin gold: |cffffffff%d|r%s"]):format(self.gold or 0,
        (self.bet or 0) > 0 and (L["  ·  Bet: %d"]):format(self.bet) or ""))
    local betting = self.state == "bet"
    if self.STAKE then
        Gamble.StakeButtons(self, betting)
    else
        local amounts = self.Bets(self.gold or START_GOLD)
        for i, b in ipairs(self.betButtons) do
            b:SetShown(betting)
            b:SetText((L["Bet %d (%d)"]):format(amounts[i], i))
            b:SetEnabled((self.gold or 0) >= amounts[i])
        end
    end
    self.nextBtn:SetShown(self.state == "result")
    self.cashBtn:SetShown(betting)
    self.cashBtn:SetEnabled(betting and (self.gold or 0) > START_GOLD)
end

-- Die drei unteren Knöpfe als „kleiner · spielen · größer“ (auch für Blackjack)
function Gamble.StakeButtons(self, betting)
    local steps, w, b = self.Ladder(self.gold or 0), self:Wager(), self.betButtons
    b[1]:SetText("– (1)")
    b[2]:SetText((self.PLAY or L["Deal for %d gold (Space)"]):format(w))
    b[3]:SetText("+ (2)")
    for i = 1, 3 do b[i]:SetShown(betting) end
    b[1]:SetEnabled(w > (steps[1] or w))
    b[2]:SetEnabled((self.gold or 0) >= w)
    b[3]:SetEnabled(w < (steps[#steps] or w))
end

function Gamble:Info()
    return {
        { L["Gold"], tostring(self.gold or START_GOLD) },
        { L["Bet"], tostring(self.bet or 0) },
    }
end

-- Knopf in der unteren Reihe des Spielfelds
function Gamble:Button(text, w, x, fn)
    local b = ns.CreateButton(self.board, text, w, function() if self.host:IsRunning() then ns.Safe(self.id, fn) end end)
    b:SetHeight(26)
    b:SetPoint("BOTTOMLEFT", self.board, "BOTTOMLEFT", x, 10)
    return b
end

-- Filz, Goldanzeige, Meldung, Einsatzknöpfe, „Weiter“ und „Kasse machen“. msgY: Höhe der Meldung
function Gamble.New(class, host, board, id, msgY)
    local g = setmetatable({ host = host, board = board, id = id, betButtons = {}, bet = 0, state = "bet",
        score = START_GOLD, gold = START_GOLD, peak = START_GOLD }, class)
    local felt = ns.NewTexture(board, "BACKGROUND")
    felt:SetAllPoints()
    if CreateColor then felt:SetGradient("VERTICAL", CreateColor(0.03, 0.18, 0.08, 1), CreateColor(0.06, 0.3, 0.13, 1)) end
    g.msg = ns.FontString(board, "GameFontNormalHuge", "CENTER")
    g.msg:SetPoint("CENTER", board, "TOP", 0, -msgY)
    g.sub = ns.FontString(board, "GameFontHighlight", "CENTER")
    g.sub:SetPoint("TOP", g.msg, "BOTTOM", 0, -6)
    g.sub:SetWidth(380)
    g.goldText = ns.FontString(board, "GameFontNormal", "RIGHT")
    g.goldText:SetPoint("TOPRIGHT", -10, -8)
    if class.STAKE then
        g.betButtons[1] = g:Button("", 64, 8, function() g:Stake(-1) end)
        g.betButtons[2] = g:Button("", 264, 78, function() g:Play() end)
        g.betButtons[3] = g:Button("", 64, 348, function() g:Stake(1) end)
    else
        for i = 1, 3 do
            g.betButtons[i] = g:Button("", 126, 8 + (i - 1) * 136, function() g:PlaceBet(i) end)
        end
    end
    g.nextBtn = g:Button(L["Next (Space)"], 180, 120, function() g:Next() end)
    g.cashBtn = ns.CreateButton(board, L["Cash out (%s)"]:format(ns.KEYS.cash), 170,
        function() if host:IsRunning() then ns.Safe(id, g.CashOut, g) end end)
    g.cashBtn:SetHeight(24)
    g.cashBtn:SetPoint("BOTTOM", board, "BOTTOM", 0, 42)
    if g.cashBtn.SetMotionScriptsWhileDisabled then g.cashBtn:SetMotionScriptsWhileDisabled(true) end
    ns.SetTooltip(g.cashBtn, L["Cash out"], L["Ends the run and scores your highest gold. Possible between hands once you have more than 100 gold."])
    return g
end
