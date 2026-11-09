-- Auxy Loot – kleines, dezentes Würfelfenster für Gruppen-Loot (WoW Forever)
--   Öffnet sich von selbst, sobald ein Item zum Würfeln auftaucht: Symbol, Name in Qualitätsfarbe,
--   Restzeit als feiner Balken, Knöpfe Bedarf / Gier / Entzaubern / Passen. Nach der Wahl bleibt die
--   Zeile gedimmt mit deiner Wahl stehen, bis das Würfeln endet; ist nichts mehr offen, schließt es sich.
--   Läuft allein; ist die Auxy UI Suite (privat) ebenfalls da, kommen Auxy-Stil (/auxy stil) und Bearbeitungsmodus dazu.
--   Zeigt auch, was die anderen gewählt und gewürfelt haben, und am Ende den Gewinner.
--   Befehl /auxyloot. Eigener Code, MIT-Lizenz (LICENSE) – github.com/Auxilias/auxy-loot
local ADDON, ns = ...
-- Optional: Ist die Auxy UI Suite geladen (OptionalDeps), nutzt Auxy Loot deren Stil, Bearbeitungsmodus und Menüs.
-- Ohne Suite läuft es allein mit eigenem Aussehen.
if type(_G.AuxyUI_NS) == "table" then ns = _G.AuxyUI_NS end

-- Sprache: Deutsch (deDE) im Code als Schlüssel, alle anderen Clients bekommen Englisch. Fehlt ein Eintrag → deutscher Text.
local L = setmetatable({}, { __index = function(_, k) return k end })
if GetLocale and GetLocale() ~= "deDE" then
    for de, en in pairs({
        ["Bedarf"] = "Need",
        ["Gier"] = "Greed",
        ["Entzaubern"] = "Disenchant",
        ["Passen"] = "Pass",
        ["Entz."] = "Disench.",
        ["Würfeln"] = "Rolling",
        ["Gewöhnlich (weiß)"] = "Common (white)",
        ["Ungewöhnlich (grün)"] = "Uncommon (green)",
        ["Selten (blau)"] = "Rare (blue)",
        ["Episch (lila)"] = "Epic (purple)",
        ["Fragen"] = "Ask",
        ["Automatisch Gier"] = "Auto greed",
        ["Automatisch passen"] = "Auto pass",
        ["Noch keine Wahl der anderen."] = "No choices from the others yet.",
        ["Rechtsklick: Einstellungen"] = "Right-click: settings",
        ["gewonnen"] = "won",
        ["Filter"] = "filter",
        ["Nicht möglich"] = "Not possible",
        ["» %s gewinnt%s"] = "» %s wins%s",
        ["Alle haben gepasst"] = "Everyone passed",
        ["gebunden"] = "Bound",
        ["+%d weitere (Maus über die Zeile)"] = "+%d more (hover the row)",
        ["vorbei"] = "over",
        ["%d/%d gewählt"] = "%d/%d chosen",
        ["ausstehend"] = "pending",
        ["Alle Mitspieler sofort anzeigen (Fenster wächst nicht)"] = "Show all group members right away (window never grows)",
        ["Test-Item "] = "Test item ",
        ["Test: drei Beispiel-Würfe für 30 s mit Beispiel-Mitspielern (Klicks würfeln hier nicht wirklich)."] = "Test: three example rolls for 30 s with made-up players (clicks don't really roll here).",
        ["Position zurückgesetzt."] = "Position reset.",
        ["Wächst nach oben."] = "Grows upwards.",
        ["Wächst nach unten."] = "Grows downwards.",
        ["Blizzards Würfelfenster aus (nur Auxy Loot)."] = "Blizzard's roll frame off (Auxy Loot only).",
        ["Blizzards Würfelfenster wieder an."] = "Blizzard's roll frame on again.",
        ["Größe "] = "Size ",
        ["/auxyloot – test · menü (Einstellungen, Lootfilter) · oben/unten (Wachstum) · reset · blizzard · groß 1.2 (Größe 0.6–2). Titelzeile ziehen = verschieben, Rechtsklick = Einstellungen."] = "/auxyloot – test · menu (settings, loot filter) · up/down (growth) · reset · blizzard · size 1.2 (size 0.6–2). Drag the title bar to move, right-click for settings.",
        ["Blizzards Würfelfenster ausblenden"] = "Hide Blizzard's roll frame",
        ["Zeile nach der Wahl ausblenden"] = "Hide row after choosing",
        ["Würfe der anderen untereinander"] = "List the others' rolls under the item",
        ["Höchstens Mitspieler-Zeilen"] = "Max. player rows",
        ["Wächst nach"] = "Grows",
        ["unten"] = "down",
        ["oben"] = "up",
        ["Ergebnis anzeigen"] = "Show result for",
        ["nicht"] = "not",
        ["Breite"] = "Width",
        ["Lootfilter (nicht bei gebundenen Items)"] = "Loot filter (never for bind-on-pickup)",
        ["Beutefenster schließen, wenn nur noch gewürfelt wird"] = "Close loot window when only rolls are left",
        ["Beute der Gruppe"] = "Group loot",
        ["Anzeigen (wer hat was eingesammelt)"] = "Show (who looted what)",
        ["Nur Items, um die gewürfelt wurde"] = "Only items that were rolled on",
        ["Eigene Beute auch zeigen"] = "Show my own loot too",
        ["Ab Qualität"] = "From quality",
        ["alles (auch grau)"] = "all (incl. grey)",
        ["weiß"] = "white",
        ["grün"] = "green",
        ["blau"] = "blue",
        ["Stehen lassen"] = "Keep for",
        ["Test (3 Beispiel-Würfe)"] = "Test (3 example rolls)",
        ["Position zurücksetzen"] = "Reset position",
        ["Auxy Loot (Würfelfenster)"] = "Auxy Loot (roll window)",
    }) do L[de] = en end
end

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local DEFAULTS = { hideBlizzard = true, scale = 1, width = 300, grow = "DOWN", hideChosen = false, linger = 5, list = true, listMax = 5, seed = true,
    autoClose = true, feed = true, feedSelf = false, feedTime = 12, feedMax = 5, feedQuality = 1, feedRollsOnly = true }
local rolledItems = {} -- itemID → Zeit des Wurfs (für „Beute der Gruppe: nur gewürfelte Items“)
local LINE = 13 -- Höhe einer Mitspieler-Zeile unter dem Item
local ROW, GAP, HEAD = 38, 3, 20 -- Zeile: oben Item + Knöpfe, darunter die Würfe der anderen
-- Lootfilter: je Qualität automatisch würfeln ("greed" | "pass"); gebundene Items (BoP) immer fragen
local FILTER_Q = { { 1, L["Gewöhnlich (weiß)"] }, { 2, L["Ungewöhnlich (grün)"] }, { 3, L["Selten (blau)"] }, { 4, L["Episch (lila)"] } }
local FILTER_DO = { { nil, L["Fragen"] }, { "greed", L["Automatisch Gier"] }, { "pass", L["Automatisch passen"] } }
local ROLL = { need = 1, greed = 2, de = 3, pass = 0 }
local SORT = { [1] = 1, [2] = 2, [3] = 3, [0] = 4 }
local CHOICE_TEXT = { [1] = "|cff4cd964" .. L["Bedarf"] .. "|r", [2] = "|cffffd100" .. L["Gier"] .. "|r", [3] = "|cffb48cff" .. L["Entzaubern"] .. "|r", [0] = "|cff999999" .. L["Passen"] .. "|r" }
local BUTTONS = { -- Reihenfolge rechts » links: Passen ganz rechts
    { key = "pass", tex = "Interface\\Buttons\\UI-GroupLoot-Pass", tip = L["Passen"] },
    { key = "de", tex = "Interface\\Buttons\\UI-GroupLoot-DE", tip = L["Entzaubern"] },
    { key = "greed", tex = "Interface\\Buttons\\UI-GroupLoot-Coin", tip = L["Gier"] },
    { key = "need", tex = "Interface\\Buttons\\UI-GroupLoot-Dice", tip = L["Bedarf"] },
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
    local t = n > 0 and (L["Würfeln"] .. " · " .. n) or L["Würfeln"]
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
    if #names == 0 then GameTooltip:AddLine(L["Noch keine Wahl der anderen."], 0.6, 0.6, 0.6) end
    GameTooltip:AddLine(L["Rechtsklick: Einstellungen"], 0.5, 0.5, 0.5)
    for _, n in ipairs(names) do
        local p = r.players[n]
        GameTooltip:AddDoubleLine(n:gsub("%-.*$", "") .. (n == r.winner and "  |cff4cd964(" .. L["gewonnen"] .. ")|r" or ""),
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
-- gewählte Zeile anzeigen (auch nach /reload wiederhergestellt)
local function ShowChoice(r, kind, auto)
    r.choice, r.autoChoice = kind, auto
    r.choiceText:SetText("» " .. CHOICE_TEXT[kind] .. (auto and " |cff999999(" .. L["Filter"] .. ")|r" or ""))
    for _, b in pairs(r.buttons) do b:Hide() end
    r.choiceText:Show()
    r:SetAlpha(0.55)
end
local function DoChoice(r, kind, auto)
    if r.rollID and r.rollID > 0 and RollOnLoot then RollOnLoot(r.rollID, kind) end
    if db.hideChosen then return Remove(r.rollID) end
    ShowChoice(r, kind, auto)
    Layout() -- Zähler im Titel
end
local function Choose(btn)
    if not btn.ok then return end
    DoChoice(btn:GetParent(), ROLL[btn.key])
end

-- WoW-Stil (07.11.): Zeile im Tooltip-Rahmen (Rand in Qualitätsfarbe), Symbol mit Qualitätsrahmen,
-- Restzeit mit Blizzards Balken-Textur. Im Auxy-Stil „OLED“ flach schwarz.
local function Flat() return ns.Style and ns.Style() == "OLED" end
local function StyleRow(r)
    if not r.SetBackdrop then return end
    if Flat() then
        r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        r:SetBackdropColor(0, 0, 0, 0.85)
        r:SetBackdropBorderColor(1, 1, 1, 0.10)
    else
        r:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        r:SetBackdropColor(0.03, 0.03, 0.05, 0.9)
        r:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
    end
end
local function IconBorder(parent)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Common\\WhiteIconFrame")
    t:SetAllPoints()
    return t
end

local function NewRow()
    local r = table.remove(rowPool)
    if r then return r end
    r = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    r:SetSize(db.width, ROW)
    StyleRow(r)
    r:EnableMouse(true)
    r:SetScript("OnMouseUp", function(self, button) if button == "RightButton" and ns.LootMenu then ns.LootMenu(self) end end)
    r:SetScript("OnEnter", PlayersTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.iconBtn = CreateFrame("Button", nil, r)
    r.iconBtn:SetSize(ROW - 10, ROW - 10)
    r.iconBtn:SetPoint("TOPLEFT", 5, -5)
    r.icon = r.iconBtn:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints()
    r.iconBorder = IconBorder(r.iconBtn)
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
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", ROW - 2, -(ROW - 7))
    r.bar:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -(ROW - 7))
    r.bar:SetHeight(3)
    r.bar:SetStatusBarTexture(Flat() and "Interface\\Buttons\\WHITE8x8" or "Interface\\TargetingFrame\\UI-StatusBar")
    local barBg = r.bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(); barBg:SetColorTexture(0, 0, 0, 0.6)
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
local function Reason(code) local k = REASON[code or 0]; return k and _G[k] or L["Nicht möglich"] end

-- Zeile für einen Wurf füllen; info = { texture, name, count, quality, bop, canNeed, canGreed, canDE, rN, rG, rD, link, total }
-- Infozeile: Wahl und Würfe der anderen, am Ende der Gewinner
-- kurzer Name: ohne Server, nur der Vorname („Thorn Eisenfaust-Forever“ » „Thorn“)
local function ShortName(n) n = (n or "?"):gsub("%-.*$", ""); return n:match("^(%S+)") or n end
-- Alle Gruppenmitglieder (Vornamen). Beim Start eines Wurfs sofort in die Liste eingetragen → die Höhe der Zeile
-- steht von Anfang an fest, die Knöpfe wandern nicht, wenn die Würfe eintrudeln (sonst Fehlklicks, 08.11.)
local function GroupNames()
    local t, seen = {}, {}
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n == 0 or not UnitName then return t end
    local function add(unit)
        local name = UnitName(unit)
        if not name or secret(name) then return end
        name = ShortName(name)
        if not seen[name] then seen[name] = true; t[#t + 1] = name end
    end
    add("player")
    if IsInRaid and IsInRaid() then for i = 1, n do add("raid" .. i) end
    else for i = 1, n - 1 do add("party" .. i) end end
    return t
end
local GROUPS = { { 1, "|cff4cd964" .. L["Bedarf"] .. "|r" }, { 2, "|cffffd100" .. L["Gier"] .. "|r" }, { 3, "|cffb48cff" .. L["Entz."] .. "|r" } }
-- Infozeile: „Bedarf: Thorn 87 · Gier: Grimbold 45, Mira · Passen: Lirael“, am Ende der Gewinner
local function UpdateInfo(r)
    local parts = {}
    -- „3/5 gewählt“: wie viele schon entschieden haben (nur mit Mitspielerliste und mehr als einem Spieler)
    local total, chosen = #(r.porder or {}), 0
    for _, name in ipairs(r.porder or {}) do if r.players[name].choice ~= nil then chosen = chosen + 1 end end
    if r.winner then
        local p = r.players[r.winner]
        parts[1] = ("|cff4cd964" .. L["» %s gewinnt%s"] .. "|r"):format(ShortName(r.winner), p and p.roll and (" (" .. p.roll .. ")") or "")
    elseif r.allPassed then
        parts[1] = "|cff999999" .. L["Alle haben gepasst"] .. "|r"
    elseif r.bop then
        parts[1] = "|cffff6060" .. L["gebunden"] .. "|r"
    end
    if not r.winner and not r.allPassed and db.list and total > 1 then
        parts[#parts + 1] = "|cff999999" .. L["%d/%d gewählt"]:format(chosen, total) .. "|r"
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
        if by[0] then parts[#parts + 1] = "|cff999999" .. L["Passen"] .. ": " .. list(by[0]) .. "|r" end
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
            l.choice:SetText(CHOICE_TEXT[p.choice] or ("|cff777777" .. L["ausstehend"] .. "|r"))
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
            l.name:SetText(("|cff999999" .. L["+%d weitere (Maus über die Zeile)"] .. "|r"):format(#names - max))
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
    r.rollID, r.link, r.total, r.choice, r.src = rollID, info.link, info.total, nil, info
    r.endTime = GetTime() + (info.left or info.total or 60)
    r.ended, r.removeAt, r.winner, r.allPassed, r.bop = nil, nil, nil, nil, info.bop
    r.itemID = type(info.link) == "string" and tonumber(info.link:match("item:(%d+)")) or nil
    r.players, r.porder = {}, {}
    if db.seed ~= false and db.list then
        for _, name in ipairs(GroupNames()) do r.players[name] = {}; r.porder[#r.porder + 1] = name end
    end
    UpdateList(r)
    r.icon:SetTexture(info.texture)
    r.count:SetText((info.count or 1) > 1 and info.count or "")
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality or 1]
    r.name:SetText(info.name or "?")
    if c then r.name:SetTextColor(c.r, c.g, c.b); r.bar:SetStatusBarColor(c.r, c.g, c.b, 0.9)
    else r.name:SetTextColor(1, 1, 1); r.bar:SetStatusBarColor(1, 0.82, 0, 0.9) end
    -- Qualitätsfarbe für Symbolrahmen und Zeilenrand (wie Blizzards Item-Tooltips)
    local qr, qg, qb = c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6
    if r.iconBorder then r.iconBorder:SetVertexColor(qr, qg, qb); r.iconBorder:SetShown((info.quality or 1) >= 2) end
    if r.SetBackdropBorderColor and not Flat() then r:SetBackdropBorderColor(qr, qg, qb, 0.85) end
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

local function Add(rollID, info, restoring)
    if rows[rollID] or not info then return end
    local iid = type(info.link) == "string" and tonumber(info.link:match("item:(%d+)"))
    if iid and rollID > 0 then rolledItems[iid] = GetTime() end -- (Test-Würfe zählen nicht)
    local r = NewRow()
    rows[rollID] = r
    order[#order + 1] = rollID
    Fill(r, rollID, info)
    Layout()
    if restoring then return r end -- nach /reload: Filter hat schon gewürfelt
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
    if not r.choice then r.choiceText:SetText(r.winner and "" or ("|cff999999" .. L["vorbei"] .. "|r")); r.choiceText:Show() end
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
            -- Wahl-Meldung: Zeile, in der dieser Spieler noch nicht gewählt hat (er steht evtl. schon vorbelegt in der Liste)
            local p = r.players[name]
            if kind ~= "choice" or not p or p.choice == nil then return r end
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
            -- derselbe Spieler kommt mal als „Auxy“, mal als „Auxy-Forever“ / „Auxy Nachname“ → auf den Vornamen vereinheitlichen
            -- (sonst steht er doppelt in der Liste, 07.11.)
            if name then name = ShortName(name) end
            local itemID = link and tonumber(link:match("item:(%d+)"))
            if not itemID then return end
            local r = RowFor(itemID, name, pt[2])
            if not r then return end
            if pt[2] == "choice" then Note(r, name, pt[3])
            elseif pt[2] == "roll" then Note(r, name, pt[3], roll)
            elseif pt[2] == "won" then r.winner = name; Note(r, name)
            elseif pt[2] == "allpassed" then r.allPassed = true; UpdateInfo(r) end
            -- Ergebnis kommt oft erst, nachdem die Zeile schon „vorbei“ war: Anzeigezeit ab jetzt neu (volle db.linger Sekunden)
            if (pt[2] == "won" or pt[2] == "allpassed") and r.removeAt then r.removeAt = GetTime() + (db.linger or 5) end
            return
        end
    end
end

-- ---------------------------------------------------------------- Beute der Gruppe
-- Kleine Liste unter dem Würfelfenster: wer was eingesammelt hat („Thorn: [Leinenstoff] ×2“), blendet nach
-- db.feedTime Sekunden aus. Quelle: Blizzards Meldungen LOOT_ITEM… im Loot-Chat.
local feed, feedLines, feedPatterns = nil, {}, nil
local function BuildFeedPatterns()
    feedPatterns = {}
    local function add(key, self) local f = _G[key]; if type(f) == "string" then feedPatterns[#feedPatterns + 1] = { ToPattern(f), self } end end
    add("LOOT_ITEM_SELF_MULTIPLE", true); add("LOOT_ITEM_SELF", true); add("LOOT_ITEM_PUSHED_SELF_MULTIPLE", true)
    add("LOOT_ITEM_PUSHED_SELF", true); add("LOOT_ITEM_MULTIPLE"); add("LOOT_ITEM")
end
local function FeedLayout()
    local now = GetTime()
    for i = #feedLines, 1, -1 do if feedLines[i].till < now then table.remove(feedLines, i) end end
    while #feedLines > (db.feedMax or 5) do table.remove(feedLines, 1) end
    feed:ClearAllPoints()
    feed:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
    feed:SetWidth(db.width)
    for i = 1, math.max(#feedLines, #(feed.rows or {})) do
        local l = feedLines[i]
        local fr = feed.rows[i]
        if l and not fr then
            fr = { icon = feed:CreateTexture(nil, "ARTWORK"), text = feed:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
            fr.icon:SetSize(14, 14); fr.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            fr.border = feed:CreateTexture(nil, "OVERLAY")
            fr.border:SetTexture("Interface\\Common\\WhiteIconFrame")
            fr.border:SetPoint("TOPLEFT", fr.icon, "TOPLEFT"); fr.border:SetPoint("BOTTOMRIGHT", fr.icon, "BOTTOMRIGHT")
            fr.text:SetJustifyH("LEFT"); fr.text:SetWordWrap(false)
            fr.text:SetShadowColor(0, 0, 0, 1); fr.text:SetShadowOffset(1, -1)
            feed.rows[i] = fr
        end
        if fr then
            if l then
                fr.icon:ClearAllPoints(); fr.icon:SetPoint("TOPLEFT", feed, "TOPLEFT", 2, -(i - 1) * 16)
                fr.text:ClearAllPoints(); fr.text:SetPoint("LEFT", fr.icon, "RIGHT", 4, 0); fr.text:SetWidth(db.width - 24)
                fr.icon:SetTexture(l.icon); fr.text:SetText(l.text)
                local left = l.till - now -- in den letzten 2 s ausblenden
                local a = left < 2 and math.max(0, left / 2) or 1
                fr.icon:SetAlpha(a); fr.text:SetAlpha(a)
                fr.icon:Show(); fr.text:Show()
                local c = l.q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[l.q]
                if c then fr.border:SetVertexColor(c.r, c.g, c.b) end
                fr.border:SetAlpha(a)
                fr.border:SetShown((l.q or 1) >= 2)
            else
                fr.icon:Hide(); fr.text:Hide(); fr.border:Hide()
            end
        end
    end
    feed:SetHeight(math.max(1, #feedLines * 16))
    feed:SetShown(#feedLines > 0)
end
local function FeedAdd(name, link, count, sample)
    local itemID = tonumber(link:match("item:(%d+)"))
    -- Standard: nur Items, um die gewürfelt wurde (letzte 5 Minuten)
    if db.feedRollsOnly and not sample and not (itemID and rolledItems[itemID] and GetTime() - rolledItems[itemID] < 300) then return end
    local q = itemID and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
    q = q or tonumber(link:match("|cnIQ(%d)")) -- Forever-Links: Qualität steht im Farbcode
    if q and not secret(q) and q < (db.feedQuality or 0) then return end
    local icon = itemID and GetItemIconByID and GetItemIconByID(itemID) or 134400
    feedLines[#feedLines + 1] = { icon = icon, q = q, till = GetTime() + (db.feedTime or 12),
        text = "|cffdddddd" .. ShortName(name) .. ":|r " .. link .. ((count or 1) > 1 and (" |cffbbbbbb×" .. count .. "|r") or "") }
    FeedLayout()
end
local function OnFeedChat(text)
    if not (db.feed and feed) or type(text) ~= "string" or secret(text) then return end
    if not feedPatterns then BuildFeedPatterns() end
    text = StripHistory(text)
    for _, pt in ipairs(feedPatterns) do
        local caps = { text:match(pt[1]) }
        if #caps > 0 then
            if pt[2] and not db.feedSelf then return end
            local link, count, name
            for _, c in ipairs(caps) do
                if c:find("|H", 1, true) then link = c elseif tonumber(c) then count = tonumber(c) else name = c end
            end
            if pt[2] then name = UnitName("player") end
            if link and link:find("item:", 1, true) then FeedAdd(name, link, count) end
            return
        end
    end
end

-- ---------------------------------------------------------------- Beutefenster schließen, wenn nur noch Würfel-Items drin sind
-- Beim Gruppen-Loot bleibt das Beutefenster offen, solange gewürfelt wird – dann reagiert WoW kaum auf
-- Rechtsklicks in die Welt (Log 07.11.). Würfeln und Chat-Meldungen laufen nach dem Schließen weiter.
local closeGen = 0
local function CheckLootWindow()
    if not db.autoClose or not (GetNumLootItems and GetLootSlotInfo and CloseLoot) then return end
    local n = GetNumLootItems() or 0
    if n == 0 then return end
    for slot = 1, n do
        local hasItem = not LootSlotHasItem or LootSlotHasItem(slot)
        if hasItem then
            local locked = select(6, GetLootSlotInfo(slot))
            if secret(locked) or not locked then return end -- noch etwas zum Einsammeln da
        end
    end
    CloseLoot()
end
local function SoonCheckLoot()
    closeGen = closeGen + 1
    local mine = closeGen
    -- kurz warten: schnelles/automatisches Plündern nimmt erst alles Freie
    C_Timer.After(0.4, function() if mine == closeGen then CheckLootWindow() end end)
end

-- ---------------------------------------------------------------- /reload überleben
-- Beim Abmelden/Neuladen (PLAYER_LOGOUT) wird der Stand gespeichert, beim Login (PLAYER_LOGIN) wiederhergestellt:
-- Zeilen mit Wahl, Würfen der anderen, Gewinner, Restzeit und die Beute-Liste. Älter als 5 Minuten = verworfen.
local function Epoch() return (time and time()) or 0 end
local function SaveSession()
    local now = GetTime()
    local s = { at = Epoch(), rows = {}, feed = {} }
    for _, id in ipairs(order) do
        local r = rows[id]
        if r and id > 0 and r.src then
            s.rows[#s.rows + 1] = { id = id, info = r.src, choice = r.choice, auto = r.autoChoice, players = r.players,
                porder = r.porder, winner = r.winner, allPassed = r.allPassed, ended = r.ended, total = r.total,
                left = (r.endTime or now) - now, removeIn = r.removeAt and (r.removeAt - now) or nil }
        end
    end
    for _, l in ipairs(feedLines) do s.feed[#s.feed + 1] = { icon = l.icon, q = l.q, text = l.text, left = l.till - now } end
    db.session = (#s.rows > 0 or #s.feed > 0) and s or nil
end
local function RestoreSession()
    local s = db.session
    db.session = nil
    local active = {}
    if GetActiveLootRollIDs then for _, id in ipairs(GetActiveLootRollIDs() or {}) do active[id] = true end end
    if s and s.at and Epoch() - s.at < 300 then
        local gone = Epoch() - s.at
        local now = GetTime()
        for _, e in ipairs(s.rows or {}) do
            local left = (e.left or 0) - gone
            local keep = active[e.id] or (e.removeIn and e.removeIn - gone > 0) or (not e.removeIn and left > -1)
            local info = active[e.id] and ReadRoll(e.id, GetLootRollTimeLeft and GetLootRollTimeLeft(e.id)) or e.info
            if keep and info then
                info.left = math.max(0, left)
                info.total = e.total or info.total
                local r = Add(e.id, info, true)
                if r then
                    r.players, r.porder = e.players or {}, e.porder or {}
                    r.winner, r.allPassed = e.winner, e.allPassed
                    r.ended = e.ended or not active[e.id]
                    if e.choice ~= nil then ShowChoice(r, e.choice, e.auto)
                    elseif r.ended then for _, b in pairs(r.buttons) do b:Hide() end end
                    if e.removeIn then
                        r.removeAt = now + math.max(1, e.removeIn - gone)
                        for _, b in pairs(r.buttons) do b:Hide() end
                        r:SetAlpha(0.75)
                    end
                    UpdateInfo(r); UpdateList(r)
                end
            end
        end
        for _, l in ipairs(s.feed or {}) do
            local left = (l.left or 0) - gone
            if left > 0 then feedLines[#feedLines + 1] = { icon = l.icon, q = l.q, text = l.text, till = now + left } end
        end
        if feed then FeedLayout() end
    end
    -- noch offene Würfe, die nicht gespeichert waren
    for id in pairs(active) do
        if not rows[id] then Add(id, ReadRoll(id, (GetLootRollTimeLeft and GetLootRollTimeLeft(id)) or 60000), true) end
    end
    Layout()
end

-- ---------------------------------------------------------------- Blizzard-Würfelfenster
-- Forever öffnet seine Würfelfenster nicht (nur) über UIParent → zusätzlich GroupLootFrame1–4 beim Zeigen ausblenden
local hookedBlizz = false
local function HideBlizzFrame(f)
    if not (db.hideBlizzard and frame) then return end
    f:Hide()
    -- leeren Blizzard-Container mit ausblenden (blieb sonst unsichtbar mit Maus aktiv stehen)
    local any = false
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do local g = _G["GroupLootFrame" .. i]; if g and g:IsShown() then any = true end end
    if not any and GroupLootContainer and GroupLootContainer:IsShown() then GroupLootContainer:Hide() end
end
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

-- ---------------------------------------------------------------- Maus-Diagnose (/auxyloot diagnose)
-- Meldet bei jedem Rechtsklick, welches Fenster unter der Maus den Klick bekommt (07.11.: Rechtsklick in die
-- Welt ging nicht, solange gewürfelt wurde). Nur bis zum nächsten /reload an.
local diagFrame
local function FrameName(f)
    if not f then return "?" end
    local ok, n = pcall(function() return (f.GetDebugName and f:GetDebugName()) or (f.GetName and f:GetName()) end)
    return ok and n and n ~= "" and tostring(n) or tostring(f)
end
local function MouseReport(button)
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() or nil }
    local names = {}
    for _, f in ipairs(foci or {}) do if f and f ~= WorldFrame then names[#names + 1] = FrameName(f) end end
    local blizz = false
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do local g = _G["GroupLootFrame" .. i]; if g and g:IsShown() then blizz = true end end
    local loot = LootFrame and LootFrame:IsShown()
    local cont = GroupLootContainer and GroupLootContainer:IsShown() and (GroupLootContainer.IsMouseEnabled and GroupLootContainer:IsMouseEnabled())
    local t = ("%s über: %s · Würfelfenster %s · Blizzard-Würfeln %s · Beutefenster %s%s"):format(button,
        #names > 0 and table.concat(names, ", ") or "Welt (kein Fenster)", frame and frame:IsShown() and "offen" or "zu",
        blizz and "SICHTBAR" or "aus", loot and "OFFEN" or "zu", cont and " · GroupLootContainer fängt Maus" or "")
    msg(t)
    if ns.Log then ns.Log("Loot", t) end
end
local function ToggleDiag()
    if not diagFrame then
        diagFrame = CreateFrame("Frame")
        diagFrame:SetScript("OnEvent", function(_, _, button) if button == "RightButton" then MouseReport("Rechtsklick") end end)
    end
    diagFrame.on = not diagFrame.on
    if diagFrame.on then pcall(diagFrame.RegisterEvent, diagFrame, "GLOBAL_MOUSE_DOWN") else diagFrame:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
    msg("Maus-Diagnose " .. (diagFrame.on and "AN – jetzt beim Würfeln in die Welt rechtsklicken; die Meldung zeigt, was den Klick abfängt." or "aus"))
end

-- ---------------------------------------------------------------- Test + Befehle
local testID = 0
local TEST = { { 2589, 4, 1 }, { 14119, 2, 1, true }, { 15310, 3, 1, false, true } } -- itemID, Qualität, …
local function Test()
    for _, t in ipairs(TEST) do
        testID = testID - 1
        local name = GetItemInfo and GetItemInfo(t[1])
        Add(testID, { texture = (GetItemIconByID and GetItemIconByID(t[1])) or 134400, name = name or (L["Test-Item "] .. -testID),
            count = t[2] == 4 and 4 or 1, quality = t[2], bop = t[4], canNeed = not t[5], canGreed = true, canDE = t[2] >= 2,
            rN = 2, link = "item:" .. t[1], total = 30 })
        local r = rows[testID]
        r.endTime = GetTime() + 30
        if db.seed ~= false and db.list then -- Beispiel-Gruppe von Anfang an (wie im Dungeon mit 5 Spielern)
            for _, n in ipairs({ "Grimbold", "Lirael", "Thorn", "Mira", ShortName(UnitName("player") or "Du") }) do
                if not r.players[n] then r.players[n] = {}; r.porder[#r.porder + 1] = n end
            end
            UpdateInfo(r); UpdateList(r); Layout()
        end
        if t[2] == 2 then Note(r, "Grimbold", 2, 45); Note(r, "Lirael", 0); r.testWinner = "Grimbold" end
        if t[2] == 3 then Note(r, "Thorn", 1, 87); Note(r, "Mira", 2) end
    end
    if feed and db.feed then
        FeedAdd("Grimbold", "|cffffffff|Hitem:2589::::::::22:::::|h[Linen Cloth]|h|r", 3, true)
        FeedAdd("Mira", "|cff1eff00|Hitem:15310::::::::22:::::|h[Feral Gloves]|h|r", nil, true)
    end
    msg(L["Test: drei Beispiel-Würfe für 30 s mit Beispiel-Mitspielern (Klicks würfeln hier nicht wirklich)."])
end

local function Command(arg)
    arg = (arg or ""):lower():match("^%s*(.-)%s*$")
    if arg == "test" or arg == "" then return Test() end
    if arg == "reset" then db.point = nil; db.scale = 1; Place(); return msg(L["Position zurückgesetzt."]) end
    if arg == "menü" or arg == "menu" or arg == "optionen" then return ns.LootMenu() end
    if arg == "diagnose" or arg == "maus" then return ToggleDiag() end
    if arg == "oben" or arg == "unten" or arg == "up" or arg == "down" then
        local up = arg == "oben" or arg == "up"
        db.grow = up and "UP" or "DOWN"; SavePoint(); Place(); Layout()
        return msg(up and L["Wächst nach oben."] or L["Wächst nach unten."])
    end
    if arg == "blizzard" then
        db.hideBlizzard = not db.hideBlizzard; ApplyBlizzard()
        return msg(db.hideBlizzard and L["Blizzards Würfelfenster aus (nur Auxy Loot)."] or L["Blizzards Würfelfenster wieder an."])
    end
    local n = tonumber(arg:match("^gross%s+([%d%.]+)") or arg:match("^groß%s+([%d%.]+)") or arg:match("^size%s+([%d%.]+)") or "")
    if n and n >= 0.6 and n <= 2 then db.scale = n; Place(); return msg(L["Größe "] .. n) end
    msg(L["/auxyloot – test · menü (Einstellungen, Lootfilter) · oben/unten (Wachstum) · reset · blizzard · groß 1.2 (Größe 0.6–2). Titelzeile ziehen = verschieben, Rechtsklick = Einstellungen."])
end
ns.LootCommand = Command
SLASH_AUXYLOOT1 = "/auxyloot"
SlashCmdList.AUXYLOOT = Command

-- Menü (Komfort-Untermenü, Optionen-Seite, Einstellungsfenster im Bearbeitungsmodus, Rechtsklick)
local function FillMenu(root)
    root:CreateCheckbox(L["Blizzards Würfelfenster ausblenden"], function() return db.hideBlizzard end,
        function() db.hideBlizzard = not db.hideBlizzard; ApplyBlizzard() end)
    root:CreateCheckbox(L["Zeile nach der Wahl ausblenden"], function() return db.hideChosen end,
        function() db.hideChosen = not db.hideChosen end)
    root:CreateCheckbox(L["Alle Mitspieler sofort anzeigen (Fenster wächst nicht)"], function() return db.seed ~= false end,
        function() db.seed = not (db.seed ~= false) end)
    root:CreateCheckbox(L["Würfe der anderen untereinander"], function() return db.list end, function()
        db.list = not db.list
        for _, r in pairs(rows) do UpdateInfo(r); UpdateList(r) end
        Layout()
    end)
    local lm = root:CreateButton(L["Höchstens Mitspieler-Zeilen"])
    for _, v in ipairs({ 3, 5, 10, 40 }) do
        lm:CreateRadio(tostring(v), function() return db.listMax == v end, function()
            db.listMax = v; for _, r in pairs(rows) do UpdateList(r) end; Layout()
        end)
    end
    local g = root:CreateButton(L["Wächst nach"])
    for _, d in ipairs({ { "DOWN", L["unten"] }, { "UP", L["oben"] } }) do
        g:CreateRadio(d[2], function() return db.grow == d[1] end, function()
            if db.grow == d[1] then return end
            db.grow = d[1]; SavePoint(); Place(); Layout()
        end)
    end
    local l = root:CreateButton(L["Ergebnis anzeigen"])
    for _, v in ipairs({ 0, 3, 5, 8, 12, 20 }) do
        l:CreateRadio(v == 0 and L["nicht"] or (v .. " s"), function() return db.linger == v end, function() db.linger = v end)
    end
    local w = root:CreateButton(L["Breite"])
    for _, v in ipairs({ 240, 300, 360, 420 }) do
        w:CreateRadio(v .. " px", function() return db.width == v end, function() db.width = v; Layout() end)
    end
    local f = root:CreateButton(L["Lootfilter (nicht bei gebundenen Items)"])
    for _, q in ipairs(FILTER_Q) do
        local sub = f:CreateButton(q[2])
        for _, act in ipairs(FILTER_DO) do
            sub:CreateRadio(act[2], function() return db.auto[q[1]] == act[1] end, function() db.auto[q[1]] = act[1] end)
        end
    end
    root:CreateCheckbox(L["Beutefenster schließen, wenn nur noch gewürfelt wird"], function() return db.autoClose end,
        function() db.autoClose = not db.autoClose end)
    local fd = root:CreateButton(L["Beute der Gruppe"])
    fd:CreateCheckbox(L["Anzeigen (wer hat was eingesammelt)"], function() return db.feed end, function() db.feed = not db.feed
        if not db.feed then feedLines = {}; if feed then FeedLayout() end end end)
    fd:CreateCheckbox(L["Nur Items, um die gewürfelt wurde"], function() return db.feedRollsOnly end,
        function() db.feedRollsOnly = not db.feedRollsOnly end)
    fd:CreateCheckbox(L["Eigene Beute auch zeigen"], function() return db.feedSelf end, function() db.feedSelf = not db.feedSelf end)
    local fq = fd:CreateButton(L["Ab Qualität"])
    for _, q in ipairs({ { 0, L["alles (auch grau)"] }, { 1, L["weiß"] }, { 2, L["grün"] }, { 3, L["blau"] } }) do
        fq:CreateRadio(q[2], function() return db.feedQuality == q[1] end, function() db.feedQuality = q[1] end)
    end
    local ft = fd:CreateButton(L["Stehen lassen"])
    for _, v in ipairs({ 6, 12, 20, 40 }) do
        ft:CreateRadio(v .. " s", function() return db.feedTime == v end, function() db.feedTime = v end)
    end
    root:CreateButton(L["Test (3 Beispiel-Würfe)"], Test)
    root:CreateButton(L["Position zurücksetzen"], function() db.point = nil; Place() end)
end
local function AddMenu(root) FillMenu(root:CreateButton(L["Auxy Loot (Würfelfenster)"])) end
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
        if not db.lingerV2 then db.lingerV2 = true; if db.linger == 6 then db.linger = 5 end end -- Standard war 6 s, jetzt 5 s (einmalig)
        db.auto = db.auto or {}
        frame = CreateFrame("Frame", "AuxyLootFrame", UIParent, "BackdropTemplate")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("MEDIUM")
        frame:Hide()
        if InSuite() then
            ns.Skin(frame, 0, { title = L["Würfeln"], close = false })
            if ns.MakeEditable then
                ns.MakeEditable(frame, { label = "Auxy Loot", minW = 220, maxW = 460, minH = 20, maxH = 400,
                    menu = function(o) ns.LootMenu(o) end,
                    scale = { get = function() return db.scale or 1 end, set = function(v) db.scale = v; Place() end },
                    options = function(p)
                        p:Slider(L["Breite"], 220, 460, 10, function() return db.width end, function(v) db.width = v; Layout() end, "%d px")
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
        feed = CreateFrame("Frame", "AuxyLootFeed", UIParent)
        feed.rows = {}
        feed:SetSize(db.width, 1)
        feed:Hide()
        local facc = 0
        feed:SetScript("OnUpdate", function(_, el) facc = facc + el; if facc >= 0.25 then facc = 0; FeedLayout() end end)
        Place()
        for _, e in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "PLAYER_LOGIN", "CHAT_MSG_LOOT",
            "LOOT_OPENED", "LOOT_SLOT_CLEARED", "PLAYER_LOGOUT" }) do
            pcall(self.RegisterEvent, self, e)
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ApplyBlizzard()
        RestoreSession() -- nach /reload: Stand des Fensters wiederherstellen
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
        OnFeedChat(a1)
    elseif event == "PLAYER_LOGOUT" then
        SaveSession()
    elseif event == "LOOT_OPENED" or event == "LOOT_SLOT_CLEARED" then
        SoonCheckLoot()
    end
end)
