-- Pastime: Höher oder tiefer – jeder Treffer vergrößert den Topf, aussteigen geht jederzeit
local ADDON, ns = ...
local L = ns.L
local Cards = ns.Cards

local W, H = 420, 440
local CW, CH = 100, 140

local Game = setmetatable({}, { __index = ns.Gamble })
Game.__index = Game
Game.STAKE = true
Game.JACKPOT = L["a pot of 1,000 times your bet"]

local function value(card) return card.rank == 1 and 14 or card.rank end

-- Faktor für einen Treffer: fair nach der Zahl der passenden Werte, 2 % für den Goblin.
-- Gleicher Wert zählt nicht (neue Karte). nil: diese Richtung gibt es nicht.
function Game.Factor(card, up)
    local v = value(card)
    local n = up and (14 - v) or (v - 2)
    if n == 0 then return nil end
    return math.max(1, 0.98 * 12 / n)
end

function Game:Draw()
    if #self.deck < 10 then self.deck = Cards.Shuffle(Cards.NewDeck(), self.rnd) end
    return table.remove(self.deck)
end

function Game:Clear()
    self.card, self.pot, self.streak = nil, 0, 0
end

function Game:Start()
    self.deck = Cards.Shuffle(Cards.NewDeck(), self.rnd)
    self:OpenRun()
end

function Game:Deal(amount)
    self.card, self.pot, self.streak, self.stake0 = self:Draw(), amount, 0, amount
    self.state = "guess"
    self.msg:SetText(L["Higher or lower?"])
    self.sub:SetText("")
    self:Render()
end

function Game:Guess(up)
    if self.state ~= "guess" then return end
    local f = Game.Factor(self.card, up)
    if not f then return end
    local old, new = value(self.card), value(self:Draw())
    while new == old do new = value(self:Draw()) end      -- gleicher Wert: neue Karte
    self.card = { rank = new == 14 and 1 or new, suit = (self.rnd or math.random)(4) }
    if (new > old) == up then
        self.pot = math.floor(self.pot * f)
        self.streak = self.streak + 1
        self.host:Sound("point")
        -- Jackpot: der Topf erreicht das 1000-Fache des Einsatzes (höchstens einmal in 1.000 Runden, wie man auch spielt)
        if self.pot >= 1000 * self.stake0 and not self.jackWon then self:Jackpot() end
        self.msg:SetText((L["Right! Pot: %d"]):format(self.pot))
        self.sub:SetText(L["Keep going or take the pot?"])
        self:Render()
    else
        self:Pay(0, L["Wrong – the pot is gone."])
    end
end

function Game:Take()
    if self.state ~= "guess" or self.streak < 1 then return end
    self:Pay(self.pot, (L["You take the pot after %d hits."]):format(self.streak))
end

function Game:Update(dt)
    self:Tick(dt)
end

function Game:Key(k, down)
    if self.state == "guess" then
        local act
        if k == "1" or k == "UP" or k == "W" then act = function() self:Guess(true) end
        elseif k == "2" or k == "DOWN" or k == "S" then act = function() self:Guess(false) end
        elseif k == "3" or k == "SPACE" or k == "ENTER" then act = function() self:Take() end
        end
        if act then
            if down then act() end
            return true
        end
    end
    return self:BaseKey(k, down)
end

function Game:Render()
    self.cardFrame:SetCard(self.card, true)
    local guessing = self.state == "guess"
    local up, down = self.card and Game.Factor(self.card, true), self.card and Game.Factor(self.card, false)
    self.upBtn:SetShown(guessing)
    self.upBtn:SetEnabled(up ~= nil)
    self.upBtn:SetText(up and (L["Higher ×%.2f (1)"]):format(up) or L["Higher (1)"])
    self.downBtn:SetShown(guessing)
    self.downBtn:SetEnabled(down ~= nil)
    self.downBtn:SetText(down and (L["Lower ×%.2f (2)"]):format(down) or L["Lower (2)"])
    self.takeBtn:SetShown(guessing)
    self.takeBtn:SetEnabled(guessing and self.streak >= 1)
    self.takeBtn:SetText((L["Take %d (3)"]):format(self.pot or 0))
    self:BaseRender()
end

function Game:Info()
    return {
        { L["Gold"], tostring(self.gold or 0) },
        { L["Pot"], tostring(self.pot or 0) },
        { L["Streak"], tostring(self.streak or 0) },
    }
end

local function Create(host, board)
    local g = ns.Gamble.New(Game, host, board, "higherlower", 250)
    g.pot, g.streak = 0, 0
    g.cardFrame = Cards.Create(board, CW, CH)
    g.cardFrame:SetPoint("TOP", board, "TOP", 0, -60)
    g.cardFrame:Hide()
    local hint = ns.FontString(board, "GameFontDisableSmall", "CENTER")
    hint:SetPoint("TOP", board, "TOP", 0, -36)
    hint:SetText(L["Ace is high. A card of the same value is drawn again."])
    g.upBtn = g:Button("", 126, 8, function() g:Guess(true) end)
    g.downBtn = g:Button("", 126, 144, function() g:Guess(false) end)
    g.takeBtn = g:Button("", 126, 280, function() g:Take() end)
    return g
end

ns.RegisterGame({
    id = "higherlower",
    name = L["Higher or Lower"],
    short = L["Card guessing"],
    aliases = { "higher", "lower", "higherlower", "hoeher", "tiefer", "hoehertiefer" },
    category = "karten",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    noLandingScore = true,
    scoreLabel = L["Highest gold"],
    width = W, height = H,
    desc = L["Is the next card higher or lower? Every hit multiplies the pot – the less likely your guess, the more. One miss and the pot is gone, so take it in time. Your goblin gold carries over between games. When you go broke or cash out, your highest gold counts."],
    controls = L["1/2: lower or raise your bet · 3: highest bet · Space: deal · then 1 or Up: higher · 2 or Down: lower · 3 or Space: take the pot · %s: cash out"]:format(ns.KEYS.cash),
    controlsShort = L["1: higher · 2: lower\n3: take the pot\n%s: cash out"]:format(ns.KEYS.cash),
    wins = function()
        return table.concat({
            L["The ace is the highest card, the 2 the lowest. The suit does not matter."],
            L["A card of the same value does not count: another one is drawn."],
            L["The number on the button is what a hit multiplies your pot by: the less likely your guess, the higher it is."],
            L["One miss and the pot is gone. Taking the pot ends the round and it is yours."],
        }, "\n\n")
    end,
    race = true,
    Create = Create,
})
ns.MP.Race("higherlower")
