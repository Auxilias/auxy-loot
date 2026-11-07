-- Auxy Loot – kleines, dezentes Würfelfenster für Gruppen-Loot (WoW Forever)
--   Öffnet sich von selbst, sobald ein Item zum Würfeln auftaucht: Symbol, Name in Qualitätsfarbe,
--   Restzeit als feiner Balken, Knöpfe Bedarf / Gier / Entzaubern / Passen. Nach der Wahl bleibt die
--   Zeile gedimmt mit deiner Wahl stehen, bis das Würfeln endet; ist nichts mehr offen, schließt es sich.
--   Läuft als eigenes Addon „AuxyLoot“ und als Teil der Auxy UI Suite (dieselbe Datei). Sind beide da,
--   arbeitet nur das eigene Addon. In der Suite: Auxy-Stil (/auxy stil) und Bearbeitungsmodus.
--   Zeigt auch, was die anderen gewählt und gewürfelt haben, und am Ende den Gewinner.
--   Befehl /auxyloot. Eigener Code, MIT-Lizenz (LICENSE) – github.com/Auxilias/auxy-loot
local ADDON, ns = ...

-- In der Suite zurücktreten, wenn das eigene Addon „AuxyLoot“ ebenfalls geladen wird
if ADDON ~= "AuxyLoot" and C_AddOns and C_AddOns.GetAddOnEnableState then
    local ok, state = pcall(C_AddOns.GetAddOnEnableState, "AuxyLoot", UnitName("player"))
    local loadable = not C_AddOns.IsAddOnLoadable or select(1, C_AddOns.IsAddOnLoadable("AuxyLoot"))
    if ok and type(state) == "number" and state > 0 and loadable then return end
end

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local DEFAULTS = { hideBlizzard = true, scale = 1, width = 300, grow = "DOWN", hideChosen = false, linger = 6, list = true, listMax = 5 }
local LINE = 13 -- Höhe einer Mitspieler-Zeile unter dem Item
local ROW, GAP, HEAD = 38, 3, 20 -- Zeile: oben Item + Knöpfe, darunter die Würfe der anderen
-- Lootfilter: je Qualität automatisch würfeln ("greed" | "pass"); gebundene Items (BoP) immer fragen
local FILTER_Q = { { 1, "Gewöhnlich (weiß)" }, { 2, "Ungewöhnlich (grün)" }, { 3, "Selten (blau)" }, { 4, "Episch (lila)" } }
local FILTER_DO = { { nil, "Fragen" }, { "greed", "Automatisch Gier" }, { "pass", "Automatisch passen" } }
local ROLL = { need = 1, greed = 2, de = 3, pass = 0 }
local SORT = { [1] = 1, [2] = 2, [3] = 3, [0] = 4 }
local CHOICE_TEXT = { [1] = "|cff4cd964Bedarf|r", [2] = "|cffffd100Gier|r", [3] = "|cffb48cffEntzaubern|r", [0] = "|cff999999Passen|r" }
local BUTTONS = { -- Reihenfolge rechts » links: Passen ganz rechts
    { key = "pass", tex = "Interface\\Buttons\\UI-GroupLoot-Pass", tip = "Passen" },
    { key = "de", tex = "Interface\\Buttons\\UI-GroupLoot-DE", tip = "Entzaubern" },
    { key = "greed", tex = "Interface\\Buttons\\UI-GroupLoot-Coin", tip = "Gier" },
    { key = "need", tex = "Interface\\Buttons\\UI-GroupLoot-Dice", tip = "Bedarf" },
}
local db
local frame
local rows, rowPool = {}, {} -- rollID → Zeile
local order = {}            -- rollIDs in Ankunftsreihenfolge
local editing = false
local function msg(t) print("|cffffd100Auxy Loot:|r " .. t) end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- ---------------------------------------------------------------- Fenster
-- eigenständig: schlichter Auxy-Stil (goldener Titel, feine Goldlinie, kein Rahmen)
local function OwnChrome(f)
    local line = f:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", 0, -HEAD + 2); line:SetPoint("TOPRIGHT", 0, -HEAD + 2); line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.45)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 6, -4)
    f.title:SetTextColor(1, 0.82, 0)
    f.title:SetShadowColor(0, 0, 0, 1); f.title:SetShadowOffset(1, -1)
    -- Titelzeile ziehen = verschieben
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT"); h:SetPoint("TOPRIGHT"); h:SetHeight(HEAD)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
    h:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        ns.LootSavePoint()
    end)
    -- Rechtsklick auf die Titelzeile: Einstellungen
    h:SetScript("OnMouseUp", function(self, button) if button == "RightButton" and ns.LootMenu then ns.LootMenu(self) end end)
end

local function InSuite() return ns.Skin ~= nil end
local function TopInset() return InSuite() and 0 or HEAD end

local function SetTitle(n)
    local t = n > 0 and ("Würfeln · " .. n) or "Würfeln"
    if InSuite() then
        if not (ns.SetWindowTitle and ns.SetWindowTitle(frame, t)) and frame.title then frame.title:SetText(t) end
    elseif frame.title then
        frame.title:SetText(t)
    end
end

-- Position: bei „nach oben“ bleibt die Unterkante stehen, bei „nach unten“ die Oberkante
local function Place()
    frame:ClearAllPoints()
    frame:SetScale(db.scale or 1)
    local p = db.point
    if p then frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    elseif db.grow == "UP" then frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 320)
    else frame:SetPoint("TOP", UIParent, "BOTTOM", 0, 420) end
end
-- aktuelle Lage als Ecke merken, die zur Wachstumsrichtung passt (Werte im Maßstab des Fensters)
local function SavePoint()
    local l, t, b = frame:GetLeft(), frame:GetTop(), frame:GetBottom()
    if not (l and t and b) then return end
    if db.grow == "UP" then db.point = { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", l, b }
    else db.point = { "TOPLEFT", "UIParent", "BOTTOMLEFT", l, t } end
end
ns.LootSavePoint = SavePoint

-- ---------------------------------------------------------------- Zeilen
local function RowTooltip(self)
    local r = self:GetParent()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if r.rollID and r.rollID > 0 and GameTooltip.SetLootRollItem then
        GameTooltip:SetLootRollItem(r.rollID)
    elseif r.link then
        GameTooltip:SetHyperlink(r.link)
    end
    GameTooltip:Show()
end

local Sorted -- (unten definiert)
local function PlayersTooltip(r)
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    GameTooltip:SetText(r.name:GetText() or "", 1, 1, 1)
    local names = Sorted(r)
    if #names == 0 then GameTooltip:AddLine("Noch keine Wahl der anderen.", 0.6, 0.6, 0.6) end
    GameTooltip:AddLine("Rechtsklick: Einstellungen", 0.5, 0.5, 0.5)
    for _, n in ipairs(names) do
        local p = r.players[n]
        GameTooltip:AddDoubleLine(n:gsub("%-.*$", "") .. (n == r.winner and "  |cff4cd964(gewonnen)|r" or ""),
            (CHOICE_TEXT[p.choice] or "?") .. (p.roll and ("  " .. p.roll) or ""), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function ButtonTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.tip, 1, 1, 1)
    if self.reason then GameTooltip:AddLine(self.reason, 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

local Remove, Layout
-- Wahl ausführen (Klick oder Lootfilter); auto = vom Filter
local function DoChoice(r, kind, auto)
    if r.rollID and r.rollID > 0 and RollOnLoot then RollOnLoot(r.rollID, kind) end
    if db.hideChosen then return Remove(r.rollID) end
    r.choice = kind
    r.choiceText:SetText("» " .. CHOICE_TEXT[kind] .. (auto and " |cff999999(Filter)|r" or ""))
    for _, b in pairs(r.buttons) do b:Hide() end
    r.choiceText:Show()
    r:SetAlpha(0.55)
    Layout() -- Zähler im Titel
end
local function Choose(btn)
    if not btn.ok then return end
    DoChoice(btn:GetParent(), ROLL[btn.key])
end

local function NewRow()
    local r = table.remove(rowPool)
    if r then return r end
    r = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    r:SetSize(db.width, ROW)
    if r.SetBackdrop then
        r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        r:SetBackdropColor(0, 0, 0, 0.78) -- dunkel genug zum Lesen über hellem Boden
    end
    r:EnableMouse(true)
    r:SetScript("OnMouseUp", function(self, button) if button == "RightButton" and ns.LootMenu then ns.LootMenu(self) end end)
    r:SetScript("OnEnter", PlayersTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.iconBtn = CreateFrame("Button", nil, r)
    r.iconBtn:SetSize(ROW - 6, ROW - 6)
    r.iconBtn:SetPoint("TOPLEFT", 3, -3)
    r.icon = r.iconBtn:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints()
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = r.iconBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    r.count:SetPoint("BOTTOMRIGHT", -1, 1)
    r.iconBtn:SetScript("OnEnter", RowTooltip)
    r.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if r.iconBtn.RegisterForClicks then r.iconBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r.iconBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then if ns.LootMenu then ns.LootMenu(self) end; return end
        local link = self:GetParent().link
        if not link then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(link)
        elseif IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then DressUpItemLink(link) end
    end)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.name:SetPoint("TOPLEFT", r.iconBtn, "TOPRIGHT", 6, -2)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.name:SetShadowColor(0, 0, 0, 1); r.name:SetShadowOffset(1, -1)
    -- zweite Zeile: bis zum rechten Rand, eine Zeile, zu lang = „…“ (alles im Tooltip)
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.info:SetPoint("BOTTOMLEFT", r.iconBtn, "BOTTOMRIGHT", 6, 3)
    r.info:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.info:SetJustifyH("LEFT")
    r.info:SetWordWrap(false)
    r.info:SetShadowColor(0, 0, 0, 1); r.info:SetShadowOffset(1, -1)
    -- Restzeit: feiner Balken am unteren Rand
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", ROW - 1, -(ROW - 3))
    r.bar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2, -(ROW - 3))
    r.bar:SetHeight(2)
    r.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    r.bar:SetMinMaxValues(0, 1)
    r.buttons = {}
    local x = -3
    for _, def in ipairs(BUTTONS) do
        local b = CreateFrame("Button", nil, r)
        b:SetSize(20, 20)
        b:SetPoint("TOPRIGHT", x, -2)
        b:SetNormalTexture(def.tex .. "-Up")
        b:SetPushedTexture(def.tex .. "-Down")
        b:SetHighlightTexture(def.tex .. "-Highlight")
        b.key, b.tip = def.key, def.tip
        b:SetScript("OnClick", Choose)
        b:SetScript("OnEnter", ButtonTooltip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.buttons[def.key] = b
        x = x - 22
    end
    r.name:SetPoint("RIGHT", r, "TOPRIGHT", x - 2, -10)
    r.choiceText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.choiceText:SetPoint("TOPRIGHT", -6, -5)
    return r
end

local function SetButton(b, ok, reason)
    b.ok, b.reason = ok, (not ok) and reason or nil
    b:SetAlpha(ok and 1 or 0.3)
    local t = b.GetNormalTexture and b:GetNormalTexture()
    if t and t.SetDesaturated then t:SetDesaturated(not ok) end
    b:Show()
end

local REASON = { -- LOOT_ROLL_INELIGIBLE_REASONx (Blizzard-Texte, falls vorhanden)
    [1] = "LOOT_ROLL_INELIGIBLE_REASON1", [2] = "LOOT_ROLL_INELIGIBLE_REASON2", [3] = "LOOT_ROLL_INELIGIBLE_REASON3",
    [4] = "LOOT_ROLL_INELIGIBLE_REASON4", [5] = "LOOT_ROLL_INELIGIBLE_REASON5",
}
local function Reason(code) local k = REASON[code or 0]; return k and _G[k] or "Nicht möglich" end

-- Zeile für einen Wurf füllen; info = { texture, name, count, quality, bop, canNeed, canGreed, canDE, rN, rG, rD, link, total }
-- Infozeile: Wahl und Würfe der anderen, am Ende der Gewinner
-- kurzer Name: ohne Server, nur der Vorname („Thorn Eisenfaust-Forever“ » „Thorn“)
local function ShortName(n) n = (n or "?"):gsub("%-.*$", ""); return n:match("^(%S+)") or n end
local GROUPS = { { 1, "|cff4cd964Bedarf|r" }, { 2, "|cffffd100Gier|r" }, { 3, "|cffb48cffEntz.|r" } }
-- Infozeile: „Bedarf: Thorn 87 · Gier: Grimbold 45, Mira · Passen: Lirael“, am Ende der Gewinner
local function UpdateInfo(r)
    local parts = {}
    if r.winner then
        local p = r.players[r.winner]
        parts[1] = ("|cff4cd964» %s gewinnt%s|r"):format(ShortName(r.winner), p and p.roll and (" (" .. p.roll .. ")") or "")
    elseif r.allPassed then
        parts[1] = "|cff999999Alle haben gepasst|r"
    elseif r.bop then
        parts[1] = "|cffff6060gebunden|r"
    end
    if not r.winner and not r.allPassed and not db.list then
        local by = {}
        for _, name in ipairs(r.porder) do
            local p = r.players[name]
            local c = p.choice == nil and -1 or p.choice
            by[c] = by[c] or {}
            table.insert(by[c], name)
        end
        local function list(names)
            table.sort(names, function(a, b) return (r.players[a].roll or 0) > (r.players[b].roll or 0) end)
            local t = {}
            for _, n in ipairs(names) do t[#t + 1] = ShortName(n) .. (r.players[n].roll and (" " .. r.players[n].roll) or "") end
            return table.concat(t, ", ")
        end
        for _, g in ipairs(GROUPS) do
            if by[g[1]] then parts[#parts + 1] = g[2] .. ": " .. list(by[g[1]]) end
        end
        if by[0] then parts[#parts + 1] = "|cff999999Passen: " .. list(by[0]) .. "|r" end
    end
    r.info:SetText(table.concat(parts, "  ·  "))
end
-- Mitspieler sortiert: Bedarf » Gier » Entzaubern » noch offen » Passen, jeweils höchster Wurf zuerst
function Sorted(r)
    local names = {}
    for _, n in ipairs(r.porder or {}) do names[#names + 1] = n end
    table.sort(names, function(a, b)
        local pa, pb = r.players[a], r.players[b]
        local sa, sb = SORT[pa.choice] or 3.5, SORT[pb.choice] or 3.5
        if sa ~= sb then return sa < sb end
        return (pa.roll or 0) > (pb.roll or 0)
    end)
    return names
end

-- Würfe untereinander: dezente kleine Zeilen „Name · Wahl · Zahl“ unter dem Item
local function SubLine(r, i)
    r.sub = r.sub or {}
    local l = r.sub[i]
    if l then return l end
    local function fs(justify)
        local f = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f:SetJustifyH(justify); f:SetWordWrap(false)
        f:SetShadowColor(0, 0, 0, 1); f:SetShadowOffset(1, -1)
        return f
    end
    l = { name = fs("LEFT"), choice = fs("LEFT"), roll = fs("RIGHT") }
    r.sub[i] = l
    return l
end
local function UpdateList(r)
    local shown = 0
    if db.list and not r.winnerOnly then
        local names = Sorted(r)
        local max = db.listMax or 5
        local wide = (db.width or 300) - ROW - 10
        for i, n in ipairs(names) do
            if i > max then break end
            local p, l = r.players[n], SubLine(r, i)
            local y = -(ROW + 1 + (i - 1) * LINE)
            l.name:ClearAllPoints(); l.name:SetPoint("TOPLEFT", r, "TOPLEFT", ROW + 3, y); l.name:SetWidth(wide * 0.5)
            l.choice:ClearAllPoints(); l.choice:SetPoint("TOPLEFT", r, "TOPLEFT", ROW + 3 + wide * 0.5, y); l.choice:SetWidth(wide * 0.32)
            l.roll:ClearAllPoints(); l.roll:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, y); l.roll:SetWidth(40)
            local won, pass = n == r.winner, p.choice == 0
            l.name:SetText(ShortName(n) .. (won and "  «" or ""))
            l.choice:SetText(CHOICE_TEXT[p.choice] or "|cff777777…|r")
            l.roll:SetText(p.roll and tostring(p.roll) or "")
            if won then l.name:SetTextColor(0.3, 0.85, 0.4); l.roll:SetTextColor(0.3, 0.85, 0.4)
            elseif pass then l.name:SetTextColor(0.55, 0.55, 0.55); l.roll:SetTextColor(0.55, 0.55, 0.55)
            else l.name:SetTextColor(0.9, 0.9, 0.9); l.roll:SetTextColor(1, 1, 1) end
            for _, f in pairs(l) do f:Show() end
            shown = i
        end
        if #names > max then
            local l = SubLine(r, max + 1)
            l.name:ClearAllPoints(); l.name:SetPoint("TOPLEFT", r, "TOPLEFT", ROW + 3, -(ROW + 1 + max * LINE)); l.name:SetWidth(wide)
            l.name:SetText(("|cff999999+%d weitere (Maus über die Zeile)|r"):format(#names - max))
            l.name:Show(); l.choice:Hide(); l.roll:Hide()
            shown = max + 1
        end
    end
    for i, l in pairs(r.sub or {}) do if i > shown then for _, f in pairs(l) do f:Hide() end end end
    r.listH = shown > 0 and (shown * LINE + 4) or 0
end

local function Note(r, name, choice, roll)
    if not name then return end
    local p = r.players[name]
    if not p then p = {}; r.players[name] = p; r.porder[#r.porder + 1] = name end
    if choice then p.choice = choice end
    if roll then p.roll = roll end
    UpdateInfo(r)
    UpdateList(r)
    if Layout and frame then Layout() end -- Zeile wird höher
end

local function Fill(r, rollID, info)
    r.rollID, r.link, r.total, r.choice = rollID, info.link, info.total, nil
    r.endTime = GetTime() + (info.left or info.total or 60)
    r.ended, r.removeAt, r.winner, r.allPassed, r.bop = nil, nil, nil, nil, info.bop
    r.itemID = type(info.link) == "string" and tonumber(info.link:match("item:(%d+)")) or nil
    r.players, r.porder = {}, {}
    UpdateList(r)
    r.icon:SetTexture(info.texture)
    r.count:SetText((info.count or 1) > 1 and info.count or "")
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality or 1]
    r.name:SetText(info.name or "?")
    if c then r.name:SetTextColor(c.r, c.g, c.b); r.bar:SetStatusBarColor(c.r, c.g, c.b, 0.9)
    else r.name:SetTextColor(1, 1, 1); r.bar:SetStatusBarColor(1, 0.82, 0, 0.9) end
    UpdateInfo(r)
    SetButton(r.buttons.need, info.canNeed, Reason(info.rN))
    SetButton(r.buttons.greed, info.canGreed, Reason(info.rG))
    SetButton(r.buttons.pass, true)
    if info.canDE then SetButton(r.buttons.de, true) else r.buttons.de:Hide() end
    r.choiceText:Hide()
    r:SetAlpha(1)
    r.bar:SetValue(1)
    r:Show()
end

function Layout()
    local n, used = 0, 0
    for _, id in ipairs(order) do
        local r = rows[id]
        local h = ROW + (r.listH or 0)
        r:ClearAllPoints()
        r:SetSize(db.width, h)
        if db.grow == "UP" then -- erster Wurf unten, weitere stapeln sich nach oben
            r:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, used)
        else
            r:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -TopInset() - used)
        end
        used = used + h + GAP
        n = n + 1
    end
    local open = 0
    for _, id in ipairs(order) do local r = rows[id]; if r.choice == nil and not r.ended and not r.removeAt then open = open + 1 end end
    SetTitle(open)
    frame:SetSize(db.width, TopInset() + math.max(ROW, used - GAP))
    if n > 0 or editing then frame:Show() else frame:Hide() end
end

function Remove(rollID)
    local r = rows[rollID]
    if not r then return end
    rows[rollID] = nil
    for i, id in ipairs(order) do if id == rollID then table.remove(order, i); break end end
    r:Hide()
    rowPool[#rowPool + 1] = r
    Layout()
end

local function ReadRoll(rollID, rollTime)
    if not GetLootRollItemInfo then return nil end
    local texture, name, count, quality, bop, canNeed, canGreed, canDE, rN, rG, rD = GetLootRollItemInfo(rollID)
    if not name or secret(name) then return nil end
    return { texture = texture, name = name, count = count, quality = quality, bop = bop, canNeed = canNeed,
        canGreed = canGreed, canDE = canDE, rN = rN, rG = rG, rD = rD,
        link = GetLootRollItemLink and GetLootRollItemLink(rollID), total = (rollTime or 60000) / 1000 }
end

local function Add(rollID, info)
    if rows[rollID] or not info then return end
    local r = NewRow()
    rows[rollID] = r
    order[#order + 1] = rollID
    Fill(r, rollID, info)
    Layout()
    -- Lootfilter (nie bei gebundenen Items)
    local rule = db.auto and db.auto[info.quality or -1]
    if rule and not info.bop then
        if rule == "pass" then DoChoice(r, ROLL.pass, true)
        elseif rule == "greed" and info.canGreed then DoChoice(r, ROLL.greed, true) end
    end
end

-- Restzeit (alle 0,1 s, nur solange sichtbar)
local acc = 0
-- Ende eines Wurfs: Zeile bleibt, bis das Ergebnis da ist (oder die Zeit sicher um ist), dann db.linger Sekunden
local function Finish(r)
    if r.removeAt then return end
    if r.testWinner and not r.winner then r.winner = r.testWinner; UpdateInfo(r) end -- Beispiel-Ergebnis
    r.removeAt = GetTime() + (db.linger or 6)
    for _, b in pairs(r.buttons) do b:Hide() end
    if not r.choice then r.choiceText:SetText(r.winner and "" or "|cff999999vorbei|r"); r.choiceText:Show() end
    r:SetAlpha(0.75)
    Layout()
end
local function OnUpdate(_, el)
    acc = acc + el
    if acc < 0.1 then return end
    acc = 0
    local now = GetTime()
    for id, r in pairs(rows) do
        local left = (r.endTime or now) - now
        if id > 0 and GetLootRollTimeLeft and not r.ended then
            local ms = GetLootRollTimeLeft(id)
            if type(ms) == "number" and ms >= 0 then left = ms / 1000; r.endTime = now + left end
        end
        if r.total and r.total > 0 then r.bar:SetValue(math.max(0, math.min(1, left / r.total))) end
        if r.removeAt then
            if now >= r.removeAt then Remove(id) end
        elseif r.winner or r.allPassed or ((r.ended or id < 0) and left <= -1) then
            Finish(r)
        end
    end
end

-- ---------------------------------------------------------------- Würfe der anderen (Loot-Chat)
-- Blizzards eigene Texte (LOOT_ROLL_…) werden zu Mustern; so klappt es in jeder Sprache.
local PATTERNS
-- Forever stellt den Meldungen einen Verweis auf die Loot-Liste voran: „|HlootHistory:233239809|h[Loot]|h: …“.
-- Der fliegt raus, bevor ausgewertet wird (seine Nummer ist kein Wurf).
local function StripHistory(t) return (t:gsub("|HlootHistory:[^|]*|h.-|h:?%s*", "")) end
local function ToPattern(fmt)
    fmt = fmt:gsub("|HlootHistory:%%d|h.-|h:?%s*", "")
    local p = fmt:gsub("%%%d%$", "%%"):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local function BuildPatterns()
    PATTERNS = {}
    local function add(key, kind, choice)
        local fmt = _G[key]
        if type(fmt) == "string" then PATTERNS[#PATTERNS + 1] = { ToPattern(fmt), kind, choice, self = key:find("_SELF$") or key == "LOOT_ROLL_YOU_WON" } end
    end
    -- spezifischere zuerst („Everyone passed on“ passt sonst auch auf „%s passed on“)
    add("LOOT_ROLL_ALL_PASSED", "allpassed"); add("LOOT_ROLL_YOU_WON", "won")
    add("LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "roll", 1); add("LOOT_ROLL_ROLLED_NEED", "roll", 1)
    add("LOOT_ROLL_ROLLED_GREED", "roll", 2); add("LOOT_ROLL_ROLLED_DE", "roll", 3)
    add("LOOT_ROLL_NEED_SELF", "choice", 1); add("LOOT_ROLL_GREED_SELF", "choice", 2)
    add("LOOT_ROLL_DISENCHANT_SELF", "choice", 3); add("LOOT_ROLL_PASSED_SELF", "choice", 0)
    add("LOOT_ROLL_PASSED_SELF_AUTO", "choice", 0)
    add("LOOT_ROLL_NEED", "choice", 1); add("LOOT_ROLL_GREED", "choice", 2)
    add("LOOT_ROLL_DISENCHANT", "choice", 3); add("LOOT_ROLL_PASSED", "choice", 0); add("LOOT_ROLL_PASSED_AUTO", "choice", 0)
    add("LOOT_ROLL_WON", "won")
end

-- passende Zeile zum Item (älteste zuerst; bei Wahlen eine, in der der Spieler noch fehlt)
local function RowFor(itemID, name, kind)
    for _, id in ipairs(order) do
        local r = rows[id]
        if r and r.itemID == itemID and not r.winner and not r.allPassed then
            if kind ~= "choice" or not r.players[name] then return r end
        end
    end
end

local function OnLootChat(text)
    if type(text) ~= "string" or secret(text) then return end
    if not PATTERNS then BuildPatterns() end
    text = StripHistory(text)
    for _, pt in ipairs(PATTERNS) do
        local caps = { text:match(pt[1]) }
        if #caps > 0 then
            local link, roll, name
            for _, c in ipairs(caps) do
                if c:find("|H", 1, true) then link = c
                elseif not roll and tonumber(c) and tonumber(c) >= 1 and tonumber(c) <= 100 then roll = tonumber(c) -- Würfe 1–100
                else name = c end
            end
            if pt.self then name = UnitName("player") end
            local itemID = link and tonumber(link:match("item:(%d+)"))
            if not itemID then return end
            local r = RowFor(itemID, name, pt[2])
            if not r then return end
            if pt[2] == "choice" then Note(r, name, pt[3])
            elseif pt[2] == "roll" then Note(r, name, pt[3], roll)
            elseif pt[2] == "won" then r.winner = name; Note(r, name)
            elseif pt[2] == "allpassed" then r.allPassed = true; UpdateInfo(r) end
            return
        end
    end
end

-- ---------------------------------------------------------------- Blizzard-Würfelfenster
-- Forever öffnet seine Würfelfenster nicht (nur) über UIParent → zusätzlich GroupLootFrame1–4 beim Zeigen ausblenden
local hookedBlizz = false
local function HideBlizzFrame(f) if db.hideBlizzard and frame then f:Hide() end end
local function ApplyBlizzard()
    if not UIParent then return end
    if db.hideBlizzard then
        UIParent:UnregisterEvent("START_LOOT_ROLL")
    else
        UIParent:RegisterEvent("START_LOOT_ROLL")
    end
    if not hookedBlizz then
        hookedBlizz = true
        for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
            local f = _G["GroupLootFrame" .. i]
            if f and f.HookScript then f:HookScript("OnShow", HideBlizzFrame) end
        end
    end
    if db.hideBlizzard then
        for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
            local f = _G["GroupLootFrame" .. i]
            if f and f:IsShown() then f:Hide() end
        end
    end
end

-- ---------------------------------------------------------------- Test + Befehle
local testID = 0
local TEST = { { 2589, 4, 1 }, { 14119, 2, 1, true }, { 15310, 3, 1, false, true } } -- itemID, Qualität, …
local function Test()
    for _, t in ipairs(TEST) do
        testID = testID - 1
        local name = GetItemInfo and GetItemInfo(t[1])
        Add(testID, { texture = (GetItemIconByID and GetItemIconByID(t[1])) or 134400, name = name or ("Test-Item " .. -testID),
            count = t[2] == 4 and 4 or 1, quality = t[2], bop = t[4], canNeed = not t[5], canGreed = true, canDE = t[2] >= 2,
            rN = 2, link = "item:" .. t[1], total = 30 })
        local r = rows[testID]
        r.endTime = GetTime() + 30
        if t[2] == 2 then Note(r, "Grimbold", 2, 45); Note(r, "Lirael", 0); r.testWinner = "Grimbold" end
        if t[2] == 3 then Note(r, "Thorn", 1, 87); Note(r, "Mira", 2) end
    end
    msg("Test: drei Beispiel-Würfe für 30 s mit Beispiel-Mitspielern (Klicks würfeln hier nicht wirklich).")
end

local function Command(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "test" or arg == "" then return Test() end
    if arg == "reset" then db.point = nil; db.scale = 1; Place(); return msg("Position zurückgesetzt.") end
    if arg == "menü" or arg == "menu" or arg == "optionen" then return ns.LootMenu() end
    if arg == "oben" or arg == "unten" then db.grow = arg == "oben" and "UP" or "DOWN"; SavePoint(); Place(); Layout(); return msg("Wächst nach " .. arg .. ".") end
    if arg == "blizzard" then
        db.hideBlizzard = not db.hideBlizzard; ApplyBlizzard()
        return msg("Blizzards Würfelfenster " .. (db.hideBlizzard and "aus (nur Auxy Loot)." or "wieder an."))
    end
    local n = tonumber(arg:match("^gross%s+([%d%.]+)") or arg:match("^groß%s+([%d%.]+)") or "")
    if n and n >= 0.6 and n <= 2 then db.scale = n; Place(); return msg("Größe " .. n) end
    msg("/auxyloot – test · menü (Einstellungen, Lootfilter) · oben/unten (Wachstum) · reset · blizzard · groß 1.2 (Größe 0.6–2). Titelzeile ziehen = verschieben, Rechtsklick = Einstellungen.")
end
ns.LootCommand = Command
SLASH_AUXYLOOT1 = "/auxyloot"
SlashCmdList.AUXYLOOT = Command

-- Menü (Komfort-Untermenü, Optionen-Seite, Einstellungsfenster im Bearbeitungsmodus, Rechtsklick)
local function FillMenu(root)
    root:CreateCheckbox("Blizzards Würfelfenster ausblenden", function() return db.hideBlizzard end,
        function() db.hideBlizzard = not db.hideBlizzard; ApplyBlizzard() end)
    root:CreateCheckbox("Zeile nach der Wahl ausblenden", function() return db.hideChosen end,
        function() db.hideChosen = not db.hideChosen end)
    root:CreateCheckbox("Würfe der anderen untereinander", function() return db.list end, function()
        db.list = not db.list
        for _, r in pairs(rows) do UpdateInfo(r); UpdateList(r) end
        Layout()
    end)
    local lm = root:CreateButton("Höchstens Mitspieler-Zeilen")
    for _, v in ipairs({ 3, 5, 10, 40 }) do
        lm:CreateRadio(tostring(v), function() return db.listMax == v end, function()
            db.listMax = v; for _, r in pairs(rows) do UpdateList(r) end; Layout()
        end)
    end
    local g = root:CreateButton("Wächst nach")
    for _, d in ipairs({ { "DOWN", "unten" }, { "UP", "oben" } }) do
        g:CreateRadio(d[2], function() return db.grow == d[1] end, function()
            if db.grow == d[1] then return end
            db.grow = d[1]; SavePoint(); Place(); Layout()
        end)
    end
    local l = root:CreateButton("Ergebnis anzeigen")
    for _, v in ipairs({ 0, 3, 6, 10, 20 }) do
        l:CreateRadio(v == 0 and "nicht" or (v .. " s"), function() return db.linger == v end, function() db.linger = v end)
    end
    local w = root:CreateButton("Breite")
    for _, v in ipairs({ 240, 300, 360, 420 }) do
        w:CreateRadio(v .. " px", function() return db.width == v end, function() db.width = v; Layout() end)
    end
    local f = root:CreateButton("Lootfilter (nicht bei gebundenen Items)")
    for _, q in ipairs(FILTER_Q) do
        local sub = f:CreateButton(q[2])
        for _, act in ipairs(FILTER_DO) do
            sub:CreateRadio(act[2], function() return db.auto[q[1]] == act[1] end, function() db.auto[q[1]] = act[1] end)
        end
    end
    root:CreateButton("Test (3 Beispiel-Würfe)", Test)
    root:CreateButton("Position zurücksetzen", function() db.point = nil; Place() end)
end
local function AddMenu(root) FillMenu(root:CreateButton("Auxy Loot (Würfelfenster)")) end
ns.LootMenu = function(owner)
    local open = ns.ContextMenu or (MenuUtil and MenuUtil.CreateContextMenu)
    if open then open(owner or UIParent, function(_, root) root:CreateTitle("Auxy Loot"); FillMenu(root) end) end
end
if ns.KomfortMenus or ns.Skin then
    ns.KomfortMenus = ns.KomfortMenus or {}
    table.insert(ns.KomfortMenus, AddMenu)
    ns.LootMenuAdd = AddMenu -- eigene Optionen-Seite
end

-- ---------------------------------------------------------------- Start
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, a1, a2)
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        AuxyLootDB = AuxyLootDB or {}
        db = AuxyLootDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        db.auto = db.auto or {}
        frame = CreateFrame("Frame", "AuxyLootFrame", UIParent, "BackdropTemplate")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("MEDIUM")
        frame:Hide()
        if InSuite() then
            ns.Skin(frame, 0, { title = "Würfeln", close = false })
            if ns.MakeEditable then
                ns.MakeEditable(frame, { label = "Auxy Loot", minW = 220, maxW = 460, minH = 20, maxH = 400,
                    menu = function(o) ns.LootMenu(o) end,
                    scale = { get = function() return db.scale or 1 end, set = function(v) db.scale = v; Place() end },
                    options = function(p)
                        p:Slider("Breite", 220, 460, 10, function() return db.width end, function(v) db.width = v; Layout() end, "%d px")
                    end,
                    top = ns.HasTitleBar and ns.HasTitleBar() and 19 or 0,
                    onMove = function() SavePoint() end,
                    onSize = function(w) db.width = math.max(220, math.min(460, w)); Layout() end,
                    onEdit = function(on) editing = on; Layout() end })
            end
        else
            OwnChrome(frame)
        end
        frame:SetScript("OnUpdate", OnUpdate)
        frame.auxyMenu = function(owner) ns.LootMenu(owner) end -- Rechtsklick auf die Titelleiste (Suite)
        Place()
        for _, e in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "PLAYER_LOGIN", "CHAT_MSG_LOOT" }) do
            pcall(self.RegisterEvent, self, e)
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ApplyBlizzard()
        -- nach /reload: noch offene Würfe übernehmen
        if GetActiveLootRollIDs then
            for _, id in ipairs(GetActiveLootRollIDs() or {}) do
                Add(id, ReadRoll(id, (GetLootRollTimeLeft and GetLootRollTimeLeft(id)) or 60000))
            end
        end
    elseif event == "START_LOOT_ROLL" then
        Add(a1, ReadRoll(a1, a2))
    elseif event == "CANCEL_LOOT_ROLL" then
        -- kommt in Forever schon, sobald DU gewürfelt hast → Zeile bleibt für die Würfe der anderen
        local r = rows[a1]
        if r then r.ended = true; Layout() end
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        for _, id in ipairs(order) do if id > 0 and rows[id] then rows[id].ended = true end end
    elseif event == "CHAT_MSG_LOOT" then
        OnLootChat(a1)
    end
end)
