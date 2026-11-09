-- Attrappen-Test für Auxy Loot (allein). Aufruf:
--   cd ~/Projekte/auxy-loot/AuxyLoot && luajit ../tests/loot-test.lua
local fail = 0
local function check(name, ok) if not ok then fail = fail + 1; io.stdout:write("FEHLER: ", name, "\n") else io.stdout:write("ok: ", name, "\n") end end
local noop = function() end
local mt = { __index = function(t, k) if type(k) == "string" and k:match("^%u") then return noop end end }

local now, frames, rolled, uiEvents
local function setup()
    now, frames, rolled, uiEvents = 100, {}, {}, { START_LOOT_ROLL = true }
    GetTime = function() return now end
    local function region()
        local o = setmetatable({ pts = {} }, mt)
        o.Show = function(s) s.shown = true end; o.Hide = function(s) s.shown = false end
        o.IsShown = function(s) return s.shown == true end
        o.SetPoint = function(s, ...) s.pts[#s.pts + 1] = { ... } end
        o.ClearAllPoints = function(s) s.pts = {} end
        o.SetText = function(s, t) s.text = t end
        o.SetAlpha = function(s, a) s.alpha = a end
        o.SetSize = function(s, w, h) s.w, s.h = w, h end
        o.SetWidth = function(s, w) s.w = w end
        o.SetShown = function(s, v) s.shown = v and true or false end
        o.SetVertexColor = function(s, r, g, b) s.vc = { r, g, b } end
        o.SetBackdrop = function(s, b) s.backdrop = b end
        o.SetBackdropBorderColor = function(s, r, g, b) s.edge = { r, g, b } end
        o.SetWordWrap = function(s, v) s.wrap = v end
        o.SetValue = function(s, v) s.value = v end
        o.GetFrameLevel = function() return 1 end
        return o
    end
    CreateFrame = function(kind, name, parent)
        local f = region()
        f.parent = parent
        f.GetParent = function(self) return self.parent end
        f.scripts = {}
        f.SetScript = function(s, n, fn) s.scripts[n] = fn end
        f.CreateTexture = function() return region() end
        f.CreateFontString = function() return region() end
        f.GetNormalTexture = function(s) s.nt = s.nt or region(); return s.nt end
        f.RegisterEvent = function(s, e) s.ev = s.ev or {}; s.ev[e] = true end
        f.UnregisterEvent = function(s, e) if s.ev then s.ev[e] = nil end end
        if name then _G[name] = f end
        frames[#frames + 1] = f
        return f
    end
    UIParent = CreateFrame("Frame", "UIParent")
    UIParent.UnregisterEvent = function(_, e) uiEvents[e] = nil end
    UIParent.RegisterEvent = function(_, e) uiEvents[e] = true end
    hooksecurefunc = noop
    InCombatLockdown = function() return false end
    UnitName = function() return "Auxy" end
    print = noop
    SlashCmdList = {}
    AuxyLootDB, AuxyUIDB, AuxyLootFrame = nil, nil, nil
    GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
    ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.1, g = 1, b = 0.1 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
    local ROLLS = {
        [7] = { 135274, "Feral Gloves", 1, 2, false, true, true, true },
        [8] = { 134400, "Northern Shortsword", 1, 3, true, false, true, false, 2 },
        [9] = { 134400, "Linen Cloth", 4, 1, false, true, true, false },
        [10] = { 134400, "Test Boots", 1, 2, false, true, true, false },
    }
    GetLootRollItemInfo = function(id) local r = ROLLS[id]; if r then return unpack(r) end end
    GetLootRollItemLink = function(id) return LINK(id) end
    rollEnds = {}
    GetLootRollTimeLeft = function(id) return math.max(0, ((rollEnds[id] or 0) - now) * 1000) end
    LOOT_ROLL_NEED = "%s has selected Need for: %s"; LOOT_ROLL_GREED = "%s has selected Greed for: %s"
    LOOT_ROLL_PASSED = "%s passed on: %s"; LOOT_ROLL_GREED_SELF = "You have selected Greed for: %s"
    LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"; LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s"
    LOOT_ROLL_WON = "%s won: %s"; LOOT_ROLL_YOU_WON = "You won: %s"; LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s"
    LOOT_ITEM = "%s receives loot: %s."; LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
    LOOT_ITEM_SELF = "You receive loot: %s."
    NUM_GROUP_LOOT_FRAMES = 4
    for i = 1, 4 do
        local g = CreateFrame("Frame", "GroupLootFrame" .. i)
        g.HookScript = function(self, n, fn) self.hooks = self.hooks or {}; self.hooks[n] = fn end
    end
    RollOnLoot = function(id, kind) rolled[#rolled + 1] = id .. ":" .. kind end
    C_AddOns = nil
end
function LINK(id) return "|cff1eff00|Hitem:" .. (1000 + id) .. "::::::::22:::::|h[Item " .. id .. "]|h|r" end
local function fire(e, ...) for _, f in ipairs(frames) do if f.ev and f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
local function tick(sec) local F = AuxyLootFrame; local stop = now + sec
    while now < stop do now = now + 0.2; if F and F.shown then F.scripts.OnUpdate(F, 0.2) end end end
local function start(id) rollEnds[id] = now + 60; fire("START_LOOT_ROLL", id, 60000) end
local function clearAll() for id in pairs(rollEnds) do rollEnds[id] = now end; for id = 7, 9 do fire("CANCEL_LOOT_ROLL", id) end; tick(70) end
local function rowsShown()
    local list = {}
    for _, f in ipairs(frames) do if f.buttons and f.shown then list[#list + 1] = f end end
    return list
end

-- ===== als eigenes Addon
setup()
assert(loadfile("AuxyLoot.lua"))("AuxyLoot", {})
fire("ADDON_LOADED", "AuxyLoot"); fire("PLAYER_LOGIN")
local F = AuxyLootFrame
check("eigenständig: Fenster da, zu Beginn versteckt", F and not F.shown)
check("Blizzards Würfelfenster aus (Standard)", uiEvents.START_LOOT_ROLL == nil)
check("eigener Titel im Auxy-Stil", F.title ~= nil)
GroupLootFrame1.shown = true; GroupLootFrame1.hooks.OnShow(GroupLootFrame1)
check("Blizzards GroupLootFrame wird beim Zeigen ausgeblendet", GroupLootFrame1.shown == false)
start(7)
check("Würfel kommt → Fenster öffnet sich", F.shown == true and #rowsShown() == 1)
local r = rowsShown()[1]
check("Name + Titel mit Zähler", r.name.text == "Feral Gloves" and F.title.text == "Würfeln · 1")
check("Entzaubern-Knopf sichtbar (kann entzaubert werden)", r.buttons.de.shown == true)
check("WoW-Stil: Zeile im Tooltip-Rahmen", r.backdrop and r.backdrop.edgeFile:find("UI-Tooltip-Border", 1, true))
check("WoW-Stil: Rand + Symbolrahmen in Qualitätsfarbe (grün)", r.edge and r.edge[2] == 1 and r.iconBorder.vc and r.iconBorder.vc[2] == 1 and r.iconBorder.shown ~= false)
start(8)
local r2 = rowsShown()[2]
check("zweiter Wurf: zwei Zeilen, BoP-Hinweis", #rowsShown() == 2 and r2.info.text:find("gebunden", 1, true))
check("kein Bedarf möglich → Knopf gedimmt, Grund im Tooltip", r2.buttons.need.ok == false and r2.buttons.need.alpha == 0.3 and r2.buttons.need.reason ~= nil)
check("ohne Entzaubern-Möglichkeit: Knopf weg", r2.buttons.de.shown == false)
r2.buttons.need.scripts.OnClick(r2.buttons.need)
check("gedimmter Knopf würfelt nicht", #rolled == 0)
r.buttons.greed.scripts.OnClick(r.buttons.greed)
check("Gier → RollOnLoot(7, 2)", rolled[1] == "7:2")
check("Zeile zeigt Wahl, gedimmt, Knöpfe weg", r.choiceText.text:find("Gier", 1, true) and r.alpha == 0.55 and r.buttons.pass.shown == false)
check("Titel zählt nur offene Würfe", F.title.text == "Würfeln · 1")
r2.buttons.pass.scripts.OnClick(r2.buttons.pass)
check("Passen → RollOnLoot(8, 0)", rolled[2] == "8:0")
-- Forever beendet das Würfeln für dich schon nach deinem Klick → Zeile bleibt für die anderen
AuxyLootDB.list = false -- erst die Kurzzeile (ohne Liste) prüfen
fire("CANCEL_LOOT_ROLL", 7)
check("nach deinem Wurf: Zeile bleibt stehen", #rowsShown() == 2)
fire("CHAT_MSG_LOOT", "You have selected Greed for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Akando Wrangler-Forever has selected Greed for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Thelights Nocat has selected Need for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Logic Limit passed on: " .. LINK(7))
check("Wahl der anderen gruppiert, Vornamen, Bedarf zuerst", r.info.text:find("Bedarf|r: Thelights", 1, true)
    and r.info.text:find("Gier|r: ", 1, true) and r.info.text:find("Passen: Logic", 1, true)
    and r.info.text:find("Bedarf", 1, true) < r.info.text:find("Gier", 1, true) and not r.info.text:find("Forever", 1, true)
    and not r.info.text:find("Nocat", 1, true))
check("eigene Wahl aus dem Chat erkannt", r.info.text:find("Auxy", 1, true) ~= nil)
check("Infozeile auf eine Zeile begrenzt (Rest im Tooltip)", r.info.wrap == false)
fire("CHAT_MSG_LOOT", "Need Roll - 87 for " .. LINK(7) .. " by Thelights Nocat")
fire("CHAT_MSG_LOOT", "Greed Roll - 45 for " .. LINK(7) .. " by Akando Wrangler-Forever")
local tipOk, tipErr = pcall(r.scripts.OnEnter, r)
check("Tooltip über der Zeile ohne Fehler (" .. tostring(tipErr) .. ")", tipOk)
check("Würfelzahlen sichtbar, höchster zuerst", r.info.text:find("Thelights 87", 1, true) and r.info.text:find("Gier|r: Akando 45, Auxy", 1, true))
fire("CHAT_MSG_LOOT", "Thelights Nocat won: " .. LINK(7))
check("Gewinner angezeigt", r.info.text:find("Thelights gewinnt (87)", 1, true) ~= nil)
check("Titel zählt nur offene Würfe", F.title.text == "Würfeln")
tick(1)
check("Ergebnis bleibt kurz stehen", #rowsShown() == 2)
tick(6)
check("danach Zeile weg", #rowsShown() == 1)
-- Wurf 8: Zeit läuft ab, kein Gewinner im Chat → nach Ablauf + Anzeige weg
fire("CANCEL_LOOT_ROLL", 8)
fire("CHAT_MSG_LOOT", "Everyone passed on: " .. LINK(8))
check("alle gepasst wird angezeigt", r2.info.text:find("gepasst", 1, true) ~= nil)
tick(8)
check("alles vorbei → Fenster zu", F.shown == false)
-- Zeit abgelaufen ohne Chat-Ergebnis
start(9); tick(0.4); rollEnds[9] = now; tick(0.4); fire("CANCEL_LOOT_ROLL", 9) -- Zeit läuft ab
tick(3)
check("ohne Ergebnis: nach Ablauf „vorbei“", #rowsShown() == 1 and rowsShown()[1].choiceText.text:find("vorbei", 1, true))
tick(7)
check("… und dann weg", F.shown == false)
-- Test-Würfe laufen von selbst ab
AuxyLootDB.list = true
-- ===== Würfe untereinander (Standard)
start(7); fire("CANCEL_LOOT_ROLL", 7)
local lr = rowsShown()[1]
fire("CHAT_MSG_LOOT", "Akando Wrangler has selected Greed for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Thelights Nocat has selected Need for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Logic Limit passed on: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Need Roll - 87 for " .. LINK(7) .. " by Thelights Nocat")
check("Liste: eine kleine Zeile je Mitspieler, Bedarf oben", lr.sub and lr.sub[1].name.text == "Thelights" and lr.sub[1].roll.text == "87"
    and lr.sub[1].choice.text:find("Bedarf", 1, true) and lr.sub[2].name.text == "Akando" and lr.sub[3].name.text == "Logic")
check("Liste: Passen grau", lr.sub[3].name.shown ~= false)
check("Liste: Zeile wird höher (3 × 13 + 4)", lr.listH == 43 and lr.h == 38 + 43)
check("Liste: Infozeile ohne doppelte Kurzfassung", not lr.info.text:find("Bedarf", 1, true))
AuxyLootDB.listMax = 2
fire("CHAT_MSG_LOOT", "Darlenes Gesicht passed on: " .. LINK(7))
check("Liste: höchstens 2 + „+N weitere“", lr.sub[3].name.text:find("+2 weitere", 1, true) and lr.sub[3].roll.shown == false)
AuxyLootDB.listMax = 5
fire("CHAT_MSG_LOOT", "Thelights Nocat won: " .. LINK(7))
check("Liste: Gewinner markiert + Infozeile", lr.sub[1].name.text:find("«", 1, true) and lr.info.text:find("Thelights gewinnt (87)", 1, true))
check("Liste: alle 4 wieder sichtbar (Maximum 5)", lr.sub[4].name.text == "Darlenes" and lr.sub[4].name.shown == true)
tick(10)
-- Forever: Meldungen mit Loot-Listen-Verweis davor (dessen Nummer ist kein Wurf)
LOOT_ROLL_ROLLED_NEED = "|HlootHistory:%d|h[Loot]|h: Need Roll - %d for %s by %s"
LOOT_ROLL_GREED = "|HlootHistory:%d|h[Loot]|h: %s has selected Greed for: %s"
LOOT_ROLL_WON = "|HlootHistory:%d|h[Loot]|h: %s won: %s"
start(8); fire("CANCEL_LOOT_ROLL", 8)
local hr8 = rowsShown()[1]
fire("CHAT_MSG_LOOT", "|HlootHistory:233239809|h[Loot]|h: Akando Wrangler has selected Greed for: " .. LINK(8))
fire("CHAT_MSG_LOOT", "|HlootHistory:233239809|h[Loot]|h: Need Roll - 64 for " .. LINK(8) .. " by Darlenes Gesicht")
fire("CHAT_MSG_LOOT", "|HlootHistory:233239809|h[Loot]|h: Darlenes Gesicht won: " .. LINK(8))
check("Forever-Format: Wurf 64 statt Verweis-Nummer", hr8.sub[1].name.text:find("Darlenes", 1, true) and hr8.sub[1].roll.text == "64")
check("Forever-Format: Gewinner mit 64", hr8.info.text:find("Darlenes gewinnt (64)", 1, true) ~= nil)
check("Forever-Format: Gier ohne Zahl", hr8.sub[2].name.text == "Akando" and hr8.sub[2].roll.text == "")
-- derselbe Spieler als „Auxy“ (Wurf) und „Auxy Swobu“ (Gewinner) darf nicht doppelt in der Liste stehen (07.11.)
start(10)
local hr9; for _, f in ipairs(rowsShown()) do if f.itemID == 1010 then hr9 = f end end
fire("CHAT_MSG_LOOT", "|HlootHistory:233239809|h[Loot]|h: Auxy Swobu has selected Greed for: " .. LINK(10)) -- mit Nachname
fire("CHAT_MSG_LOOT", "|HlootHistory:233239809|h[Loot]|h: Need Roll - 68 for " .. LINK(10) .. " by Auxy-Forever") -- mit Server
fire("CHAT_MSG_LOOT", "|HlootHistory:233239809|h[Loot]|h: Auxy won: " .. LINK(10))
check("Spieler mit Nachname/Server/ohne nur einmal in der Liste", #hr9.porder == 1 and hr9.winner == "Auxy")
tick(10)
tick(10)
SlashCmdList.AUXYLOOT("test")
check("/auxyloot test: drei Beispiel-Zeilen", #rowsShown() == 3 and F.shown)
local t = rowsShown()[1]
t.buttons.need.scripts.OnClick(t.buttons.need)
check("Test-Klick würfelt nicht wirklich", #rolled == 2)
local tb
for _, x in ipairs(rowsShown()) do if x.testWinner and x.sub and x.sub[1] and x.sub[1].name.text and x.sub[1].name.text:find("Grimbold", 1, true) then tb = x end end
check("Test: Beispiel-Mitspieler sichtbar", tb ~= nil)
tick(31)
check("Test: am Ende Beispiel-Gewinner", tb.info.text:find("gewinnt", 1, true) ~= nil and F.shown)
tick(7)
check("Test-Zeilen danach weg, Fenster zu", #rowsShown() == 0 and F.shown == false)
SlashCmdList.AUXYLOOT("blizzard")
check("/auxyloot blizzard: Blizzard-Fenster wieder an", uiEvents.START_LOOT_ROLL == true and AuxyLootDB.hideBlizzard == false)

-- ===== Gruppe: alle Mitspieler sofort da, Höhe bleibt fest (08.11.: Knöpfe wanderten beim Eintrudeln der Würfe)
AuxyLootDB.list = true; AuxyLootDB.hideBlizzard = true; AuxyLootDB.listMax = 5; AuxyLootDB.seed = true
GetNumGroupMembers = function() return 4 end
IsInRaid = function() return false end
local PARTY = { player = "Auxy", party1 = "Akando Wrangler", party2 = "Thelights-Forever", party3 = "Logic Limit" }
UnitName = function(u) return PARTY[u] end
start(7)
local gr = rowsShown()[1]
check("Gruppe: alle 4 sofort in der Liste", #gr.porder == 4 and gr.porder[2] == "Akando" and gr.porder[3] == "Thelights")
check("Gruppe: Höhe von Anfang an für 4 Zeilen (4 × 13 + 4)", gr.listH == 56 and gr.h == 38 + 56)
check("Gruppe: Zähler 0/4 gewählt", gr.info.text:find("0/4 gewählt", 1, true) ~= nil)
local h0 = gr.h
fire("CHAT_MSG_LOOT", "Akando Wrangler-Forever has selected Greed for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Thelights Nocat has selected Need for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Need Roll - 87 for " .. LINK(7) .. " by Thelights")
check("Gruppe: Zeile wächst nicht beim Eintrudeln", gr.h == h0 and #gr.porder == 4)
check("Gruppe: Zähler 2/4 gewählt", gr.info.text:find("2/4 gewählt", 1, true) ~= nil)
check("Gruppe: Zähler weg, sobald es einen Gewinner gibt", (function() fire("CHAT_MSG_LOOT", "Thelights won: " .. LINK(7)); return not gr.info.text:find("gewählt", 1, true) and gr.info.text:find("Thelights", 1, true) ~= nil end)())
clearAll()
-- ohne Gruppe (solo) wie bisher: keine vorbelegten Zeilen, kein Zähler
GetNumGroupMembers = function() return 0 end
start(7)
local solo = rowsShown()[1]
check("Solo: keine vorbelegte Liste", #solo.porder == 0 and solo.listH == 0)
clearAll()
-- Schalter aus: wie früher (wächst mit den Würfen)
GetNumGroupMembers = function() return 4 end; AuxyLootDB.seed = false
start(7)
check("Schalter aus: Liste beginnt leer", #rowsShown()[1].porder == 0)
clearAll()
-- Schlachtzug: mehr Mitglieder als Zeilen → „+N weitere“ ist von Anfang an eingeplant (max 5 + 1)
AuxyLootDB.seed = true; IsInRaid = function() return true end; GetNumGroupMembers = function() return 8 end
UnitName = function(u) local i = tonumber(u:match("^raid(%d+)$")); if u == "player" then return "Auxy" end; if i then return "Spieler" .. i end end
start(7)
local rr = rowsShown()[1]
check("Schlachtzug: 8 Namen (ohne Doppelte), Höhe für 5 Zeilen + „weitere“ (6 × 13 + 4)", #rr.porder == 9 or #rr.porder == 8)
check("Schlachtzug: Höhe fest", rr.listH == 82)
clearAll()
UnitName = function() return "Auxy" end; GetNumGroupMembers = nil; IsInRaid = nil; AuxyLootDB.list = true

-- ===== Ergebnis bleibt volle 5 s, auch wenn die Meldung erst nach dem Ende der Zeile kommt
AuxyLootDB.linger = 5; AuxyLootDB.list = true
start(7)
local lw = rowsShown()[1]
lw.buttons.greed.scripts.OnClick(lw.buttons.greed)
fire("CANCEL_LOOT_ROLL", 7)
tick(62)                                   -- Zeit abgelaufen, Zeile wartet auf das Ergebnis (removeAt gesetzt)
check("Ergebnis-Test: Zeile steht nach Ablauf noch", #rowsShown() == 1)
tick(3)
fire("CHAT_MSG_LOOT", "Thelights won: " .. LINK(7))
check("Gewinner wird angezeigt", lw.info.text:find("Thelights", 1, true) ~= nil)
tick(4)
check("Gewinner bleibt 4 s nach der Meldung stehen", #rowsShown() == 1)
tick(2)
check("nach 5 s weg", #rowsShown() == 0)
-- Standard + einmalige Umstellung 6 s → 5 s
check("Standard 5 s", AuxyLootDB.linger == 5)
clearAll()

-- ===== Lootfilter, Ausblenden, Wachstum, Breite (eigenständig weiter)
AuxyLootDB.hideBlizzard = true
AuxyLootDB.auto[2] = "greed"       -- grün: automatisch Gier
start(7)  -- grün, nicht gebunden
check("Filter: grünes Item automatisch Gier", rolled[#rolled] == "7:2")
local fr = rowsShown()[1]
check("Filter: Zeile zeigt „(Filter)“", fr and fr.choiceText.text:find("Filter", 1, true))
AuxyLootDB.auto[3] = "pass"
local before = #rolled
start(8)  -- blau, aber gebunden
check("Filter: gebundenes Item wird nie automatisch gewürfelt", #rolled == before)
clearAll()
AuxyLootDB.auto = {}
AuxyLootDB.hideChosen = true
start(7)
local hr = rowsShown()[1]
hr.buttons.need.scripts.OnClick(hr.buttons.need)
check("Zeile nach der Wahl ausblenden: weg, Fenster zu", #rowsShown() == 0 and F.shown == false and rolled[#rolled] == "7:1")
AuxyLootDB.hideChosen = false
-- Wachstum nach oben: erste Zeile unten am Fenster
F.GetLeft = function() return 500 end; F.GetTop = function() return 400 end; F.GetBottom = function() return 300 end
SlashCmdList.AUXYLOOT("oben")
check("„oben“: Unterkante wird gemerkt", AuxyLootDB.grow == "UP" and AuxyLootDB.point[1] == "BOTTOMLEFT" and AuxyLootDB.point[5] == 300)
start(7); start(8)
local r1, r2b = rowsShown()[1], rowsShown()[2]
check("„oben“: erste Zeile unten, zweite darüber", r1.pts[1][1] == "BOTTOMLEFT" and r1.pts[1][5] == 0 and r2b.pts[1][5] == 41)
SlashCmdList.AUXYLOOT("unten")
check("„unten“: Oberkante wird gemerkt, Zeilen von oben", AuxyLootDB.point[1] == "TOPLEFT" and AuxyLootDB.point[5] == 400 and r1.pts[1][1] == "TOPLEFT")
-- Breite
AuxyLootDB.width = 400
start(9) -- neu zeichnen
check("Breite: Fenster und Zeilen 400 px", F.w == 400 and r1.w == 400)
clearAll()
-- Menü per Rechtsklick (eigenständig: MenuUtil)
local captured
MenuUtil = { CreateContextMenu = function(_, gen)
    local function node() local n = { kids = {} }
        local function add(kind) return function(self, t, a, b) local k = node(); k.kind, k.text, k.a, k.b = kind, t, a, b; self.kids[#self.kids + 1] = k; return k end end
        n.CreateButton, n.CreateCheckbox, n.CreateRadio, n.CreateTitle, n.CreateDivider = add("button"), add("check"), add("radio"), add("title"), add("divider")
        return n end
    captured = node(); gen(nil, captured) end }
SlashCmdList.AUXYLOOT("menü")
local function child(n, text) for _, k in ipairs(n.kids) do if k.text and k.text:find(text, 1, true) then return k end end end
local lf = captured and child(captured, "Lootfilter")
check("Menü: Lootfilter mit 4 Qualitäten à 3 Möglichkeiten", lf and #lf.kids == 4 and #lf.kids[2].kids == 3)
lf.kids[2].kids[3].b()
check("Menü: grün » automatisch passen", AuxyLootDB.auto[2] == "pass")
AuxyLootDB.auto = {}; AuxyLootDB.width = 300; MenuUtil = nil

-- ===== Maus-Diagnose
local said = {}
print = function(t) said[#said + 1] = t end
WorldFrame = CreateFrame("Frame", "WorldFrame")
local blocker = CreateFrame("Frame", "IrgendeinVorhang"); blocker.GetDebugName = function() return "IrgendeinVorhang" end
GetMouseFoci = function() return { blocker, WorldFrame } end
LootFrame = CreateFrame("Frame", "LootFrame"); LootFrame.shown = true
SlashCmdList.AUXYLOOT("diagnose")
local dg; for _, f in ipairs(frames) do if f.ev and f.ev.GLOBAL_MOUSE_DOWN then dg = f end end
check("Diagnose: hört auf Mausklicks", dg ~= nil)
dg.scripts.OnEvent(dg, "GLOBAL_MOUSE_DOWN", "RightButton")
local last = said[#said] or ""
check("Diagnose nennt das Fenster unter der Maus + Beutefenster", last:find("IrgendeinVorhang", 1, true) and last:find("Beutefenster OFFEN", 1, true))
dg.scripts.OnEvent(dg, "GLOBAL_MOUSE_DOWN", "LeftButton")
check("Linksklick wird nicht gemeldet", said[#said] == last)
SlashCmdList.AUXYLOOT("diagnose")
check("Diagnose wieder aus", dg.ev.GLOBAL_MOUSE_DOWN == nil)
print = noop

-- ===== Beute der Gruppe
local FD = AuxyLootFeed
-- Standard: nur gewürfelte Items
FD.scripts.OnUpdate(FD, 0.3) -- alte Beispiel-Zeilen sind abgelaufen
start(7) -- um Item 7 wird (frisch) gewürfelt
fire("CHAT_MSG_LOOT", "Thorn Eisenfaust receives loot: |cffffffff|Hitem:4306::::::::22:::::|h[Silk Cloth]|h|rx3.")
fire("CHAT_MSG_LOOT", "Thorn Eisenfaust receives loot: |cffffffff|Hitem:2589::::::::22:::::|h[Linen Cloth]|h|r.")
check("Beute: nicht gewürfelte Items (auch das Test-Beispiel) werden standardmäßig nicht gezeigt", not FD.shown)
fire("CHAT_MSG_LOOT", "Thelights Nocat receives loot: " .. LINK(7) .. ".")
check("Beute: gewürfeltes Item (Wurf 7) wird gezeigt", FD.shown and FD.rows[1].text.text:find("Thelights:", 1, true))
now = now + 13; FD.scripts.OnUpdate(FD, 0.3)
clearAll()
AuxyLootDB.feedRollsOnly = false -- für die folgenden Tests: alles zeigen
local LC = "|cffffffff|Hitem:2589::::::::22:::::|h[Linen Cloth]|h|r"
local LG = "|cff9d9d9d|Hitem:3300::::::::22:::::|h[Rabbit's Foot]|h|r"
C_Item = { GetItemQualityByID = function(id) return id == 3300 and 0 or 1 end }
fire("CHAT_MSG_LOOT", "|HlootHistory:99|h[Loot]|h: Thorn Eisenfaust receives loot: " .. LC .. "x3.")
check("Beute: Zeile „Thorn: [Linen Cloth] ×3“", FD.shown and FD.rows[1].text.text:find("Thorn:", 1, true) and FD.rows[1].text.text:find("×3", 1, true))
fire("CHAT_MSG_LOOT", "Mira receives loot: " .. LC .. ".")
check("Beute: zweite Zeile ohne Anzahl", FD.rows[2].text.text:find("Mira:", 1, true) and not FD.rows[2].text.text:find("×", 1, true))
fire("CHAT_MSG_LOOT", "Mira receives loot: " .. LG .. ".")
check("Beute: graues Item ausgefiltert (ab weiß)", FD.rows[3] == nil or FD.rows[3].text.shown == false)
fire("CHAT_MSG_LOOT", "You receive loot: " .. LC .. ".")
check("Beute: eigene Beute standardmäßig nicht", FD.rows[3] == nil or FD.rows[3].text.shown == false)
AuxyLootDB.feedSelf = true
fire("CHAT_MSG_LOOT", "You receive loot: " .. LC .. ".")
check("Beute: eigene Beute, wenn eingeschaltet", FD.rows[3] and FD.rows[3].text.text:find("Auxy:", 1, true))
AuxyLootDB.feedSelf = false
now = now + 13; FD.scripts.OnUpdate(FD, 0.3)
check("Beute: nach 12 s ausgeblendet", FD.shown == false)
C_Item = nil

-- ===== Beutefenster schließen, wenn nur noch gewürfelt wird
C_Timer = { After = function(_, fn) fn() end }
local closed = 0
CloseLoot = function() closed = closed + 1 end
local slots = { { locked = true }, { locked = false } }
GetNumLootItems = function() return #slots end
LootSlotHasItem = function(i) return slots[i] ~= nil end
GetLootSlotInfo = function(i) return 1, "x", 1, nil, 2, slots[i].locked end
fire("LOOT_OPENED")
check("Beutefenster: noch Freies drin → bleibt offen", closed == 0)
slots[2] = nil
fire("LOOT_SLOT_CLEARED")
check("Beutefenster: nur noch Würfel-Item → geschlossen", closed == 1)
AuxyLootDB.autoClose = false
fire("LOOT_OPENED")
check("Beutefenster: Option aus → bleibt offen", closed == 1)
AuxyLootDB.autoClose = true

-- ===== Blizzard-Container wird mit ausgeblendet
GroupLootContainer = CreateFrame("Frame", "GroupLootContainer"); GroupLootContainer.shown = true
GroupLootFrame2.shown = true; GroupLootFrame2.hooks.OnShow(GroupLootFrame2)
check("leerer Blizzard-Container ausgeblendet", GroupLootContainer.shown == false and GroupLootFrame2.shown == false)

-- ===== /reload überleben
local T = 1000
time = function() return T end
tick(80) -- alte Zeilen weg
AuxyLootDB.list = true
start(7); start(8)
local ra = rowsShown()[1]
ra.buttons.greed.scripts.OnClick(ra.buttons.greed)           -- eigener Wurf auf 7
fire("CANCEL_LOOT_ROLL", 7)
fire("CHAT_MSG_LOOT", "Thelights Nocat has selected Need for: " .. LINK(7))
fire("CHAT_MSG_LOOT", "Need Roll - 87 for " .. LINK(7) .. " by Thelights Nocat")
fire("CHAT_MSG_LOOT", "Mira receives loot: " .. LINK(9) .. ".")
fire("PLAYER_LOGOUT")
check("Abmelden: Stand gespeichert (2 Würfe, Beute-Zeile)", AuxyLootDB.session and #AuxyLootDB.session.rows == 2 and #AuxyLootDB.session.feed == 1)
-- neues Spiel nach /reload: 5 s später, Wurf 8 läuft noch, 7 ist für uns schon vorbei
local keep = AuxyLootDB
local savedEnds = rollEnds
setup(); AuxyLootDB = keep; rollEnds = savedEnds; now = now + 5; T = T + 5
time = function() return T end
GetActiveLootRollIDs = function() return { 8 } end
assert(loadfile("AuxyLoot.lua"))("AuxyLoot", {})
fire("ADDON_LOADED", "AuxyLoot"); fire("PLAYER_LOGIN")
local rs = rowsShown()
check("nach /reload: beide Zeilen wieder da", #rs == 2 and AuxyLootFrame.shown)
local r7, r8
for _, x in ipairs(rs) do if x.rollID == 7 then r7 = x elseif x.rollID == 8 then r8 = x end end
check("Wurf 7: eigene Wahl „Gier“ wieder angezeigt", r7 and r7.choiceText.text:find("Gier", 1, true) and r7.buttons.need.shown == false)
check("Wurf 7: Würfe der anderen wieder da", r7.sub and r7.sub[1].name.text == "Thelights" and r7.sub[1].roll.text == "87")
check("Wurf 8: läuft noch → Knöpfe würfelbar", r8 and r8.buttons.pass.shown ~= false and r8.choice == nil)
r8.buttons.pass.scripts.OnClick(r8.buttons.pass)
check("Wurf 8: nach /reload würfeln geht", rolled[#rolled] == "8:0")
check("Beute-Liste wieder da", AuxyLootFeed.shown and AuxyLootFeed.rows[1].text.text:find("Mira:", 1, true))
check("gespeicherter Stand danach gelöscht", AuxyLootDB.session == nil)
-- zu alt (über 5 Minuten): nichts wiederherstellen
fire("PLAYER_LOGOUT"); keep = AuxyLootDB
setup(); AuxyLootDB = keep; T = T + 400; time = function() return T end
GetActiveLootRollIDs = function() return {} end
assert(loadfile("AuxyLoot.lua"))("AuxyLoot", {})
fire("ADDON_LOADED", "AuxyLoot"); fire("PLAYER_LOGIN")
check("nach über 5 Minuten: nichts wiederhergestellt", #rowsShown() == 0)
GetActiveLootRollIDs = nil; time = nil

-- ===== zusammen mit der Auxy UI Suite (nur wenn sie lokal daneben liegt; Loot lädt nach der Suite)
local SUITE = os.getenv("HOME") .. "/Projekte/auxy-ui-suite/AuxyUI/"
if io.open(SUITE .. "Core.lua") then
    setup()
    local ns = {}
    for _, f in ipairs({ "Core.lua", "QoL.lua" }) do assert(loadfile(SUITE .. f))("AuxyUI", ns) end
    fire("ADDON_LOADED", "AuxyUI")
    check("Suite setzt AuxyUI_NS", AuxyUI_NS == ns)
    assert(loadfile("AuxyLoot.lua"))("AuxyLoot", {})
    fire("ADDON_LOADED", "AuxyLoot"); fire("PLAYER_LOGIN")
    check("Suite: Würfelfenster aktiv, im Auxy-Stil (Hülle)", AuxyLootFrame and AuxyLootFrame.auxyModern ~= nil)
    check("Suite: /auxyloot und Komfort-Menü-Eintrag", SlashCmdList.AUXYLOOT ~= nil and #(ns.KomfortMenus or {}) >= 1)
    check("Suite: Optionen-Seite findet das Menü", ns.LootMenuAdd ~= nil)
    start(7)
    check("Suite: Wurf zeigt Zeile", #rowsShown() == 1 and AuxyLootFrame.shown)
    local menus = 0
    MenuUtil = { CreateContextMenu = function() menus = menus + 1 end }
    local hull = AuxyLootFrame.auxyModern
    hull.dragHandle.scripts.OnMouseUp(hull.dragHandle, "RightButton")
    check("Suite: Rechtsklick auf die Titelleiste öffnet die Einstellungen", menus == 1)
    local sr = rowsShown()[1]
    sr.scripts.OnMouseUp(sr, "RightButton")
    check("Suite: Rechtsklick auf eine Zeile öffnet die Einstellungen", menus == 2)
    sr.iconBtn.scripts.OnClick(sr.iconBtn, "RightButton")
    check("Suite: Rechtsklick auf das Symbol öffnet die Einstellungen", menus == 3)
    sr.scripts.OnMouseUp(sr, "LeftButton")
    check("Linksklick auf die Zeile öffnet nichts", menus == 3)
    MenuUtil = nil
    AuxyUI_NS = nil
end

io.stdout:write(fail == 0 and "\nAlle Tests bestanden.\n" or ("\n" .. fail .. " Fehler.\n"))
os.exit(fail == 0 and 0 or 1)
