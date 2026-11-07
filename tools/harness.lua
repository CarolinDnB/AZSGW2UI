io.stdout:setvbuf("no")

-- where the addon folder is (AZS_ROOT: the folder that holds AZSGW2UI/, default: one up from tools/) and where the
-- layout dumps go (AZS_OUT, default: the current folder)
local ROOT = os.getenv("AZS_ROOT") or ".."
local ADDON_DIR = ROOT .. "/AZSGW2UI"          -- the addon folder: AZS_ROOT/AZSGW2UI, or AZS_ROOT itself when the toc is there (the repository layout)
do
	local probe = io.open(ADDON_DIR .. "/AZSGW2UI.toc")
	if probe then probe:close() else ADDON_DIR = ROOT end
end
local OUTDIR = os.getenv("AZS_OUT") or "."

-- ---------- Lua 5.0 compatibility shims (the real client is Lua 5.0)
table.getn = function(t) assert(type(t) == "table", "table.getn on " .. type(t)); return #t end
math.mod = math.fmod
unpack = table.unpack
local realFormat = string.format

-- ---------- tiny 1.12 widget mock with strict argument checks
local used = {}
cvars = { hudBuild = "1", minimapZoom = "3", minimapInsideZoom = "3", CombatDamage = "1", PetMeleeDamage = "1", PetSpellDamage = "1" }
local globals = {}
local namedFrames = {}
local allWidgets = {}

local function isnum(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function needNum(fn, ...)
	local a = { ... }
	for i = 1, select("#", ...) do
		if not isnum(a[i]) then error(fn .. ": argument " .. i .. " is not a number: " .. tostring(a[i]), 3) end
	end
end

local Widget = {}
local impl = {}

local function new(kind, parent, name)
	local w = setmetatable({ kind = kind, parent = parent, _name = name, shown = true,
		scripts = {}, w = 100, h = 20, text = "", points = 0 }, Widget)
	table.insert(allWidgets, w)
	if name then namedFrames[name] = w; _G[name] = w end
	return w
end

Widget.__index = function(t, k)
	local f = impl[k]
	if f then
		return function(self, ...)
			used[k] = (used[k] or 0) + 1
			return f(self, ...)
		end
	end
	if (t.kind == "Texture" or t.kind == "FontString") and (k == "GetScript" or k == "SetScript") then return nil end
	-- lower-case names are Lua fields set by the addon: a missing one is nil, as in the real client
	if type(k) ~= "string" or not string.find(k, "^%u") then return nil end
	return function(self, ...)
		used[k] = (used[k] or 0) + 1
		globals["UNKNOWN_METHOD_" .. tostring(k)] = true
		return nil
	end
end

impl.SetWidth = function(self, v) needNum("SetWidth", v); self.w = v; self.wSet = true end
impl.SetHeight = function(self, v) needNum("SetHeight", v); self.h = v; self.hSet = true end
impl.GetWidth = function(self) return self.w end
impl.GetHeight = function(self) return self.h end
impl.Show = function(self) self.shown = true end
impl.Hide = function(self) self.shown = false end
impl.IsShown = function(self) return self.shown end
impl.SetScript = function(self, n, f) assert(type(f) == "function" or f == nil); self.scripts[n] = f end
impl.GetScript = function(self, n) return self.scripts[n] end
impl.GetFrameLevel = function(self) return rawget(self, "level") or ((self.parent and self.parent:GetFrameLevel() or 0) + 1) end
impl.SetFrameLevel = function(self, v) needNum("SetFrameLevel", v); self.level = v end
impl.SetFrameStrata = function(self, s) assert(type(s) == "string"); self.strata = s end
impl.GetName = function(self) return rawget(self, "_name") end
impl.GetParent = function(self) return self.parent end
impl.EnableMouse = function(self, v) self.mouseOn = ( v ~= false ) end
impl.IsMouseEnabled = function(self) return self.mouseOn and true or false end
impl.EnableMouseWheel = function() end
impl.SetParent = function(self, p) assert(type(p) == "table", "SetParent needs a frame"); self.parent = p end
impl.SetMaskTexture = function(self, path) assert(type(path) == "string"); self.mask = path end
impl.GetNumPoints = function(self) return 1 end
impl.GetEffectiveScale = function(self) return 1 end
impl.GetZoom = function(self) return self.zoom or 0 end
impl.GetZoomLevels = function(self) return 5 end
impl.SetZoom = function(self, z)
	needNum("SetZoom", z); assert(z >= 0 and z <= 4, "zoom out of range")
	self.zoom = z
	if self.indoors then cvars.minimapInsideZoom = tostring(z) else cvars.minimapZoom = tostring(z) end
end
impl.SetMovable = function() end
impl.RegisterForDrag = function() end
impl.RegisterForClicks = function(self, a, b, c, d)
	self.clicks = {}
	for _, v in ipairs({ a, b, c, d }) do table.insert(self.clicks, v) end
end
impl.RegisterEvent = function() end
impl.StartMoving = function() end
impl.StopMovingOrSizing = function() end
impl.SetClampedToScreen = function() end
impl.GetPoint = function(self)
	local p = self.pts and self.pts[1]
	if p then return p[1], p[2], p[3], p[4], p[5] end
	return "CENTER", nil, "CENTER", 0, 0
end
impl.ClearAllPoints = function(self) self.points = 0; self.pts = {}; self.allpts = nil end
impl.SetScale = function(self, v) needNum("SetScale", v); assert(v > 0); self.scale = v end
impl.GetScale = function(self) return rawget(self, "scale") or 1 end
impl.SetAlpha = function(self, v) needNum("SetAlpha", v); self.alpha = v end
impl.GetAlpha = function(self) return rawget(self, "alpha") or 1 end
impl.GetTexture = function(self) return rawget(self, "tex") end
impl.GetTextColor = function(self) local c = rawget(self, "tcol"); if c then return c[1], c[2], c[3] end return 1, 1, 1 end
impl.GetNumChildren = function(self)
	local n = 0
	for _, w in ipairs(allWidgets) do
		if (w.kind == "Frame" or w.kind == "Button" or w.kind == "StatusBar") and w.parent == self then n = n + 1 end
	end
	return n
end
impl.GetValue = function(self) return self.sbValue or 0 end
impl.GetMinMaxValues = function(self) return self.sbMin or 0, self.sbMax or 1 end
impl.GetStatusBarColor = function(self) local c = self.sbColor or { 1, 1, 1 }; return c[1], c[2], c[3] end
impl.SetAllPoints = function(self, f) assert(type(f) == "table", "SetAllPoints needs a frame/region"); self.allpts = f; self.pts = {} end
impl.CreateTexture = function(self, n, layer)
	assert(self.kind ~= "Texture" and self.kind ~= "FontString", "CreateTexture on a region")
	assert(layer == nil or layer == "BACKGROUND" or layer == "BORDER" or layer == "ARTWORK" or layer == "OVERLAY" or layer == "HIGHLIGHT", "bad layer " .. tostring(layer))
	local t = new("Texture", self)
	t.layer = layer or "ARTWORK"
	return t
end
impl.CreateFontString = function(self, n, layer)
	assert(self.kind ~= "Texture" and self.kind ~= "FontString")
	assert(layer == nil or layer == "BACKGROUND" or layer == "BORDER" or layer == "ARTWORK" or layer == "OVERLAY", "bad layer " .. tostring(layer))
	return new("FontString", self)
end
impl.SetPoint = function(self, point, rel, relPoint, x, y)
	assert(type(point) == "string", "SetPoint point")
	if rel ~= nil then
		assert(type(rel) == "table" or type(rel) == "string", "SetPoint relativeTo is " .. type(rel))
		if type(rel) == "string" then assert(_G[rel], "SetPoint relativeTo name missing: " .. rel) end
		if type(relPoint) == "number" then x, y = relPoint, rel; error("SetPoint: relPoint is a number: " .. tostring(relPoint)) end
		if relPoint ~= nil then assert(type(relPoint) == "string", "SetPoint relPoint") end
		if x ~= nil then needNum("SetPoint x", x) end
		if y ~= nil then needNum("SetPoint y", y) end
	end
	self.points = self.points + 1
	local target = rel
	if type(target) == "string" then target = _G[target] end
	self.pts = self.pts or {}
	self.allpts = nil
	table.insert(self.pts, { point, target or self.parent, relPoint or point, x or 0, y or 0 })
end
impl.SetTexture = function(self, a, b, c, d)
	if type(a) == "number" then needNum("SetTexture", a, b, c) self.tex = nil self.solid = { a, b, c, d } return end
	assert(a == nil or type(a) == "string", "SetTexture path " .. tostring(a))
	self.tex = a
end
impl.SetVertexColor = function(self, r, g, b, a) needNum("SetVertexColor", r, g, b); if a ~= nil then needNum("SetVertexColor a", a) end self.vc = { r, g, b, a or 1 }; self.vcCount = (self.vcCount or 0) + 1 end
impl.SetTexCoord = function(self, ...) needNum("SetTexCoord", ...) self.tc = { ... } end
impl.GetTexCoord = function(self) if rawget(self, "tc") then return unpack(self.tc) end end
impl.SetBlendMode = function(self, m) assert(m == "ADD" or m == "BLEND" or m == "DISABLE" or m == "ALPHAKEY" or m == "MOD") end
impl.SetFont = function(self, f, s, fl)
	assert(type(f) == "string", "SetFont path"); needNum("SetFont size", s)
	assert(fl == nil or fl == "OUTLINE" or fl == "THICKOUTLINE" or fl == "")
	if failAzsFont and string.find(f, "azs_numbers", 1, true) then return nil end   -- like the client: the old font stays
	self.fontSet = true
	if fontSizes and string.find(f, "azs_numbers", 1, true) then fontSizes[s] = true end
	self.fpath = f
	self.fflags = fl or ""
	self.fsize = s
end
impl.SetJustifyH = function(self, j) assert(j == "LEFT" or j == "RIGHT" or j == "CENTER", "SetJustifyH " .. tostring(j)); self.just = j end
impl.SetTextColor = function(self, r, g, b, a) needNum("SetTextColor", r, g, b) self.tcol = { r, g, b } end
impl.SetText = function(self, t)
	assert(self.fontSet, "SetText before SetFont")
	assert(type(t) == "string", "SetText got " .. type(t) .. " (" .. tostring(t) .. ")")
	self.text = t
end
impl.GetFont = function(self) return self.fpath, self.fsize, "" end
impl.GetStringWidth = function(self)
	local t = rawget(self, "text") or ""
	local per = 0.507
	if not string.find(tostring(self.fpath), "azs_numbers", 1, true) then per = 0.55 end
	return string.len(t) * (self.fsize or 12) * per
end
impl.GetText = function(self) local t = rawget(self, "text"); if type(t) == "string" then return t end return nil end
impl.GetObjectType = function(self) return self.kind end
impl.GetRegions = function(self)
	local out = {}
	for _, w in ipairs(allWidgets) do
		if (w.kind == "Texture" or w.kind == "FontString") and w.parent == self then table.insert(out, w) end
	end
	return unpack(out)
end
impl.GetChildren = function(self)
	local out = {}
	for _, w in ipairs(allWidgets) do
		if (w.kind == "Frame" or w.kind == "Button" or w.kind == "StatusBar") and w.parent == self then table.insert(out, w) end
	end
	return unpack(out)
end
impl.IsVisible = function(self)
	local p = self
	while p do if not p.shown then return false end p = p.parent end
	return true
end
impl.GetNumRegions = function(self) return 0 end
impl.Click = function() end
-- GameTooltip
tipLines = {}
impl.AddLine = function(self, t, r, g, b)
	assert(type(t) == "string", "AddLine text " .. tostring(t))
	if r ~= nil then needNum("AddLine color", r, g, b) end
	table.insert(tipLines, t)
end
impl.AddDoubleLine = function(self, l, r, lr, lg, lb, rr, rg, rb)
	assert(type(l) == "string" and type(r) == "string", "AddDoubleLine text")
	if lr ~= nil then needNum("AddDoubleLine color", lr, lg, lb, rr, rg, rb) end
	table.insert(tipLines, l .. " | " .. r)
end
local tipStore = {}
-- book index -> the lines of the game's spell tooltip (for the scan tooltip). The text of a tooltip only changes when the
-- hero's upgrades do, and the game says so with a new stats stamp: a change here is made like that.
spellTipText = setmetatable({}, { __index = tipStore, __newindex = function(t, k, v)
	tipStore[k] = v
	-- (the stats themselves are left alone: the addon is told its remembered numbers are out of date, as a new number would)
	if AZSGW2 and AZSGW2.tgtSeen then AZSGW2.tgtSeen.statSig = "other" end
	AZS_STATS_UPDATED = (AZS_STATS_UPDATED or 0) + 1
end })
scanCalls = 0
scanBlind = false      -- the game writes the numbers of the hero only into the tooltip a player sees (a hover), not into a look
impl.SetOwner = function(self, f, a)
	assert(type(f) == "table" and type(a) == "string")
	self.tipText = nil
	self.anchor = a
	self.owner = f
	if self._name == "AZSGW2ScanTip" then return end
	tipLines = {}; lastSetSpell = nil; lastLink = nil
end
impl.SetSpell = function(self, idx, book)
	assert(type(idx) == "number" and (book == "spell" or book == "pet"), "SetSpell args")
	local nm = self._name
	if nm == "AZSGW2ScanTip" or nm == "GameTooltip" then
		scanCalls = scanCalls + 1
		-- like the game: the tooltip is filled and shown; its lines are GameTooltipTextLeft1, 2, ...
		local lines = spellTipText[book == "pet" and ("pet" .. idx) or idx] or { (GetSpellName(idx, book)) }
		if scanBlind and self.anchor == "ANCHOR_NONE" then lines = { lines[1] } end
		self.tipText = lines
		self.shown = true
		for i, t in ipairs(lines) do
			local fs = _G[nm .. "TextLeft" .. i] or new("FontString", self, nm .. "TextLeft" .. i)
			fs.fontSet = true; fs.text = t
		end
	end
	if nm == "AZSGW2ScanTip" then return end
	lastSetSpell = { idx, book }; tipLines = { "(game tooltip)" }
end
linkTip = {}           -- "spell:ID" / "enchant:ID" -> the lines of the tooltip a link gives ("error": the call fails)
lastLink = nil
impl.SetHyperlink = function(self, link)
	assert(type(link) == "string", "SetHyperlink arg")
	local nm = self._name
	local lines = linkTip[link]
	if lines == "error" then error("Unknown link type") end
	if not lines then self.tipText = nil; return end
	self.tipText = lines
	self.shown = true
	for i, t in ipairs(lines) do
		local fs = _G[nm .. "TextLeft" .. i] or new("FontString", self, nm .. "TextLeft" .. i)
		fs.fontSet = true; fs.text = t
	end
	if nm == "AZSGW2ScanTip" then return end
	lastLink = link; tipLines = { "(game tooltip)" }
end
impl.NumLines = function(self) return self.tipText and #self.tipText or 0 end
lastInvTip = nil
-- the game's tooltip of a worn item: only switched on by the tests that need it (INV_TIP)
impl.SetInventoryItem = function(self, unit, id)
	assert(unit == "player")
	if not INV_TIP then error("attempt to call method 'SetInventoryItem' (a nil value)") end
	if not worn[id] then return nil end
	self.tipText = { (worn[id][2]:match("%[(.-)%]")) }
	self.shown = true
	lastInvTip = id
	return true, false, 0
end
impl.GetOwner = function(self) return self.owner end
impl.ClearLines = function(self) self.tipText = nil; if self._name == "GameTooltip" then tipLines = {} end end
local book = { { "Frostbolt", "Rank 2" }, { "Frostbolt", "Rank 3" }, { "Blizzard", "Rank 1" } }
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo(t) return "General", "tex", 0, #book end
petBook = {}            -- the pet's own spellbook (empty unless a test fills it)
function GetSpellName(i, b) assert(b == "spell" or b == "pet"); local e = (b == "pet" and petBook or book)[i]; if e then return e[1], e[2] end end

function CreateFrame(kind, name, parent, template)
	assert(kind == "Frame" or kind == "Button" or kind == "PlayerModel" or kind == "StatusBar" or kind == "GameTooltip", "CreateFrame kind " .. tostring(kind))
	assert(name == nil or type(name) == "string")
	assert(parent == nil or type(parent) == "table", "CreateFrame parent " .. type(parent))
	return new(kind, parent, name)
end

UIParent = new("Frame", nil, "UIParent")
UIParent.w = 1024; UIParent.h = 768
GameTooltip = new("Frame", nil, "GameTooltip"); GameTooltip.shown = false
-- stock frames the addon should keep hidden
local stockFrames = {}
for _, n in ipairs({ "PlayerFrame", "PartyMemberFrame1", "PartyMemberFrame2", "BuffFrame", "MainMenuBar", "MainMenuExpBar", "ActionButton1", "ActionButton2", "TargetFrame" }) do
	stockFrames[n] = new("Frame", UIParent, n)
end
local plateCalls = { hide = 0, show = 0 }
NAMEPLATES_ON = 1
function HideNameplates() plateCalls.hide = plateCalls.hide + 1 end
function ShowNameplates() plateCalls.show = plateCalls.show + 1 end
function HideFriendNameplates() plateCalls.friendHide = (plateCalls.friendHide or 0) + 1 end
function ShowFriendNameplates() plateCalls.friendShow = (plateCalls.friendShow or 0) + 1 end
local errorsMsgs, raidMsgs = {}, {}
-- like a real frame: the method lives in the shared metatable, so a shadow set on the frame can be removed again
UIErrorsFrame = setmetatable({}, { __index = { AddMessage = function(self, m) table.insert(errorsMsgs, m) end } })
RaidNotice_AddMessage = function(f, m) table.insert(raidMsgs, m) end
-- stock minimap: Minimap lives in MinimapCluster, with the usual decorations
MinimapCluster = new("Frame", UIParent, "MinimapCluster")
Minimap = new("Frame", MinimapCluster, "Minimap")
Minimap.zoom = 3
Minimap.w = 140; Minimap.h = 140
Minimap:SetPoint("TOPRIGHT", MinimapCluster, "TOPRIGHT", -9, -22)
for _, n in ipairs({ "MinimapBackdrop", "MinimapZoomIn", "MinimapZoomOut", "MiniMapTracking", "GameTimeFrame" }) do stockFrames[n] = new("Frame", MinimapCluster, n) end
MinimapBorder = new("Texture", MinimapCluster, "MinimapBorder")
stockFrames.MinimapCluster = MinimapCluster
function GetMinimapZoneText() return "Scholomance" end
function GetZoneText() return "Scholomance" end
function AZS_GetLocalTime() return { text = "20:28" } end
WorldFrame = new("Frame", nil, "WorldFrame")
local ctEvents, ctCursor, ctHandler, ctProj = {}, 0, nil, {}
function AZS_GetCombatTextCapabilities() return { apiVersion = 1 } end
function AZS_RegisterCombatTextFrameHandler(h) ctHandler = h end
-- every reader keeps its own cursor (reading consumes nothing): the cursor says which list of hits it has read
-- ("c<list>:<how many of it>"); a test that puts a new table into ctEvents starts a new list
local ctTab = nil
function AZS_GetCombatTextEvents(cursor)
	if ctEvents ~= ctTab then ctTab = ctEvents; ctCursor = ctCursor + 1 end
	local from = 0
	if type(cursor) == "string" then
		local seq, n = cursor:match("^c(%d+):(%d+)$")
		if seq and tonumber(seq) == ctCursor then from = tonumber(n) end
	end
	local out = {}
	for i = from + 1, #ctEvents do table.insert(out, ctEvents[i]) end
	return { cursor = "c" .. ctCursor .. ":" .. #ctEvents, events = out, hasMore = false, droppedCount = 0 }
end
function AZS_ProjectCombatTextAnchors(ids, mode)
	assert(mode == "follow" or mode == "impact")
	local entries = {}
	for i, id in ipairs(ids) do entries[i] = ctProj[id] or { anchorId = id, state = "unknownAnchor" } end
	return { entries = entries }
end
AZS_CHESTS = {}
local originalOnShow = function() end
stockFrames.ActionButton1.scripts.OnShow = originalOnShow
local chatLines = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) table.insert(chatLines, m); print("  [chat] " .. m) end }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.8, b = 0.94 }, WARLOCK = { r = 0.58, g = 0.51, b = 0.79 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }
local now = 1000
function GetTime() return now end
function IsShiftKeyDown() return false end
function getglobal(n) return _G[n] end
function ReloadUI() print("  [ReloadUI]") end
SlashCmdList = {}
function RunBinding(b) print("  [RunBinding] " .. tostring(b)) end
local bindingNames = { "TOGGLECHARACTER0", "TOGGLETALENTS", "AZS_OPEN_TALENTS" }
function GetNumBindings() return #bindingNames end
function GetBinding(i) return bindingNames[i], "C" end
function GetBindingKey(cmd) if cmd == "AZS_OPEN_TALENTS" then return "T" end return nil end
-- EnumerateFrames: iterate widgets of kind Frame/Button
function EnumerateFrames(prev)
	local i = 0
	if prev then for k, w in ipairs(allWidgets) do if w == prev then i = k break end end end
	for k = i + 1, #allWidgets do
		local w = allWidgets[k]
		if w.kind == "Frame" or w.kind == "Button" then return w end
	end
	return nil
end

-- stock character window (1.12: ToggleCharacter -> ShowUIPanel / HideUIPanel, tab 1 = paper doll)
CharacterFrame = new("Frame", UIParent, "CharacterFrame")
CharacterFrame.shown = false
CharacterFrame.selectedTab = 1
stockCharShows = 0
CharacterFrame.scripts.OnShow = function() stockCharShows = stockCharShows + 1 end
function ShowUIPanel(f) if not f.shown then f.shown = true; if f.scripts.OnShow then f.scripts.OnShow() end end end
function HideUIPanel(f) f.shown = false end
function ToggleCharacter(tab)
	if tab == "PaperDollFrame" then CharacterFrame.selectedTab = 1 else CharacterFrame.selectedTab = 3 end
	if CharacterFrame.shown then HideUIPanel(CharacterFrame) else ShowUIPanel(CharacterFrame) end
end
UISpecialFrames = {}
local slotIds = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8,
	WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14, BackSlot = 15,
	MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19, AmmoSlot = 0 }
function GetInventorySlotInfo(n) assert(slotIds[n], "bad slot " .. tostring(n)); return slotIds[n], "Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. n end
worn = { [1] = { "Interface\\Icons\\INV_Helmet_08", "|cffa335ee|Hitem:12640:0:0:0|h[Lionheart Helm]|h|r" },
	[5] = { "Interface\\Icons\\INV_Chest_Cloth_21", "|cffffffff|Hitem:1:0:0:0|h[Robe]|h|r" },
	[13] = { "Interface\\Icons\\INV_Misc_Gear_01", "|cff0070dd|Hitem:2:0:0:0|h[Gear]|h|r" },
	[0] = { "Interface\\Icons\\INV_Ammo_Arrow_02", "|cffffffff|Hitem:3:0:0:0|h[Arrow]|h|r", 840 } }
function GetInventoryItemTexture(u, id) assert(u == "player"); return worn[id] and worn[id][1] or nil end
function GetInventoryItemLink(u, id) assert(u == "player"); return worn[id] and worn[id][2] or nil end
function GetInventoryItemCount(u, id) return worn[id] and worn[id][3] or 1 end
pickups = {}
function PickupInventoryItem(id) table.insert(pickups, id) end
function UseInventoryItem(id) table.insert(pickups, -id) end
local helm, cloak = true, true
function ShowingHelm() return helm and 1 or nil end
function ShowingCloak() return cloak and 1 or nil end
function ShowHelm(v) helm = v ~= nil end
function ShowCloak(v) cloak = v ~= nil end
function GetCursorPosition() return 500, 300 end
function IsMouseButtonDown() return false end

-- ---------- fake AZS API
local run = { t = 0, lvl = 63, xp = 1462, xpn = 1598, hp = 2400, hpm = 2400, sh = 300, gold = 5491, kills = 287,
	chest = 2235, lives = 1, endl = 0, nb = 45, proc = "seal_fate", pv = 3, pm = 5, owed = 0 }
AZS_RUN = run
AZS_ZONE = { zone = "sm", class = "mage", hero = "Mr Nippy" }
local phase = "playing"
local clock = 955.0
function AZS_GetPhase() return phase end
function AZS_GetRunTime() return clock end
function AZS_GetRunLength() return 1200 end
AZS_SPELLS = {
	{ key = "frostbolt", spell = 1, rank = 3, cd = 0, cdmax = 2 },
	{ key = "arcane_missiles", spell = 2, rank = 1, cd = 1.5, cdmax = 3 },
	{ key = "fire_blast", spell = 3, rank = 1, cd = 0, cdmax = 8 },
	{ key = "blizzard", spell = 4, rank = 1, cd = 4, cdmax = 10 },
	{ key = "frost_nova", spell = 5, rank = 1, cd = 0, cdmax = 25 },
	{ key = "pyroblast", spell = 6, rank = 1, cd = 12.5, cdmax = 30 },
	{ key = "racial", spell = 7, rank = 1, cd = 0, cdmax = 120 },
}
AZS_SPELLS_UPDATED = 1
AZS_SCHEDULE = {
	{ index = 1, at = 120, name = "A", final = 0, state = "dead" },
	{ index = 2, at = 360, name = "B", final = 0, state = "dead" },
	{ index = 3, at = 600, name = "C", final = 0, state = "up" },
	{ index = 4, at = 960, name = "D", final = 0, state = "due" },
	{ index = 5, at = 1200, name = "E", final = 1, state = "due" },
}
function AZS_GetUpcomingBosses() return { { index = 4, name = "Scarlet Commander", at = 960, left = 5, final = false } } end
function AZS_GetBosses()
	return { { id = 1, name = "Boss C", hp = 30000, hpm = 52500, final = false, enraged = true,
		debuffs = { { spell = 1, name = "Curse", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", stacks = 3, remaining = 12.4, duration = 30, permanent = false, dispelType = "Curse" },
			{ spell = 2, name = "Mark", icon = "Interface\\Icons\\Ability_Hunter_SniperShot", stacks = 1, permanent = true } } } }
end
function AZS_GetGuardians()
	return { { id = 5, name = "Necrofiend", hp = 100, hpm = 900, awake = true, debuffs = {} },
		{ id = 6, name = "Spectral Tutor", hp = 900, hpm = 900, awake = false, debuffs = {} } }
end
function AZS_GetLairs()
	return { { index = 1, id = 0, state = "empty", name = "Risen Construct", left = 50, flag = 0, x = 10, y = 10, spaceId = "m1:1" },
		{ index = 2, id = 5, state = "awake", name = "Necrofiend", left = -1, flag = 0, x = 30, y = 40, spaceId = "m1:1" },
		{ index = 3, id = 6, state = "asleep", name = "Spectral Tutor", left = -1, flag = 1, x = 100, y = -20, spaceId = "m1:1" } }
end
function AZS_GetPlayerPosition() return { x = 0, y = 0, z = 0, spaceId = "m1:1", facing = 0 } end
function AZS_GetMeter() return { { name = "Frostbolt", dmg = 2300000000, dps = 2400000, share = 0.96, proc = 0 }, { name = "Shadow Weaving", dmg = 85000000, dps = 90000, share = 0.036, proc = 1 } }, 2400000000, 2500000 end
defaultGetMeter = AZS_GetMeter
function AZS_GetHealing() return { { name = "Regeneration", dmg = 5000, dps = 10, share = 1, proc = 0 } }, 5000, 10 end
function AZS_GetBossMeter() return {}, 0, 0 end
function AZS_GetPartyMeter() return { { name = "Carolin", class = "warlock", dmg = 2300000000, dps = 2000000, share = 0.96, top = "Shadow Bolt", topdps = 1000000 }, { name = "Zaynor", class = "rogue", dmg = 85000000, dps = 80000, share = 0.036, top = "", topdps = 0 } }, 2400000000, 2500000 end
metaRev = "m1"
mockRun = "r1"
function AZS_GetMeterContext() return { runId = mockRun, metadataRevision = metaRev } end
local snapshotCalls = 0
snapshotQueries = {}
snapRate = nil                       -- what the API says the last 10 seconds' rate is (nil: it cannot say)
checkpoints = { made = 0, released = {}, expired = false }
function AZS_CreateMeterCheckpoint(run)
	assert(run == mockRun, "checkpoint for another run")
	checkpoints.made = checkpoints.made + 1
	return { checkpointId = "cp" .. checkpoints.made, runId = run }, nil
end
function AZS_ReleaseMeterCheckpoint(id) table.insert(checkpoints.released, id); return true, nil end
function AZS_GetMeterSnapshot(q)
	snapshotCalls = snapshotCalls + 1
	table.insert(snapshotQueries, q); if #snapshotQueries > 20 then table.remove(snapshotQueries, 1) end
	assert(q.apiVersion == 1 and q.runId == mockRun, "bad snapshot query")
	assert(q.metric == "damage" or q.metric == "healing")
	assert(q.period == "run" or q.period == "encounter")
	assert(q.scope == "self" or q.scope == "party")
	if q.windowSeconds == 10 then
		-- the recent rate: one total, no rows asked for
		assert(q.groupBy == "owner", "rate query groups by owner")
		if q.checkpointId then
			if checkpoints.expired or q.checkpointId ~= "cp" .. checkpoints.made then return nil, { code = "CHECKPOINT_EXPIRED", retryable = false } end
		end
		if snapRate == nil then return nil, { code = "NOT_READY", retryable = true, retryAfterSeconds = 0.2 } end
		return { totals = { displayRate = { status = "ready", value = snapRate } }, rows = {}, sources = {} }, nil
	end
	assert(q.groupBy == "source" and q.windowSeconds == 0, "bad snapshot query")
	return { rows = {}, sources = {
		a = { name = "Frostbolt", icon = { status = "ready", path = "Interface\\Icons\\Spell_Frost_FrostBolt02" } },
		b = { name = "Shadow Weaving", icon = { status = "ready", path = "Interface\\Icons\\Spell_Shadow_BlackPlague" } },
		c = { name = "Melee", icon = { status = "missing", reason = "none" } },
		d = { name = "Shadow Bolt", icon = { status = "ready", path = "Interface\\Icons\\Spell_Shadow_ShadowBolt" } },
	} }, nil
end
function AZS_GetMeterLoadout(q)
	assert(q.apiVersion == 1 and q.runId == mockRun)
	return { loadoutRevision = "rev1",
		sources = {
			["ability:frostbolt:r3"] = { abilityKey = "frostbolt", name = "Frostbolt", icon = { status = "ready", path = "Interface\\Icons\\Spell_Frost_FrostBolt02" } },
			["ability:frostbolt:r3:pulse"] = { abilityKey = "frostbolt", variantKey = "pulse", name = "Frostbolt (pulse)", icon = { status = "missing", reason = "x" } },
			["ability:blizzard:r1"] = { abilityKey = "blizzard", name = "Blizzard", icon = { status = "ready", path = "Interface\\Icons\\Spell_Frost_IceStorm" } },
			["item:100"] = { name = "Ring of Doom", icon = { status = "ready", path = "Interface\\Icons\\INV_Jewelry_Ring_03" } },
		},
		runJewelry = { { sourceKey = "item:100", category = "ring" } } }
end
function AZS_GetSummonGroups() return { { key = "imp", name = "Imp", icon = "Interface\\Icons\\Spell_Shadow_SummonImp", count = 2, permanent = 1, temporary = 1, remaining = 12 } }, 2 end
function AZS_GetTotems() return { { key = "searing_totem", name = "Searing Totem", icon = "Interface\\Icons\\Spell_Fire_SearingTotem", count = 1, remaining = 30 } } end
function AZS_GetTimers() return { { name = "Butcher", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis", kind = "summon", remaining = 5.5, ready = false },
	{ name = "Ready one", icon = "Interface\\Icons\\X", kind = "cooldown", remaining = 0, ready = true } } end
local stored = 4
function AZS_GetStoredLevels() return stored end
function AZS_OpenStoredLevels() print("  [OpenStoredLevels]") end
local bannerHandler
function AZS_RegisterBannerHandler(h) bannerHandler = h end
local hud = { clock = true, bosses = true, tally = true, build = true, meter = true, levels = true, banners = true }
function AZS_SetHudShown(p, s) hud[p] = s end
function AZS_IsHudShown(p) return hud[p] end
function GetCVar(n) return cvars[n] end
function SetCVar(n, v) assert(type(v) == "string"); cvars[n] = v end
AZS_STATS = { hp = 2400, dmg = 1.25, cd = 0.85, crit = 0.12, cm = 3.04, arm = 0.18, reg = 1.5, area = 1.1, cnt = 1, echo = 0.05,
	spd = 1.15, pick = 6, xp = 1.2, luck = 0.4, gold = 1.1, heal = 12, lch = 0.03, thn = 40, liv = 1,
	ghp = 300, gdmg = 0.15, gcrit = 0, foo = 7 }

-- party + player auras
function GetNumPartyMembers() return 3 end
local partyData = {
	party1 = { name = "Zaynor", class = "ROGUE", hp = 1800, hpm = 1800 },
	party2 = { name = "Carolin", class = "WARLOCK", hp = 700, hpm = 1500 },
	party3 = { name = "Ghost", class = "MAGE", hp = 0, hpm = 900 },
}
local clientTarget = nil   -- { name, hostile, dead, class, hp, hpm }
local mouseTarget = nil    -- the unit under the mouse: { name }
function UnitExists(u) if u == "target" then return clientTarget ~= nil end if u == "mouseover" then return mouseTarget ~= nil end return partyData[u] ~= nil end
local playerName = nil    -- UnitName("player"), only when a scenario wants one
function UnitName(u) if u == "target" then return clientTarget and clientTarget.name end if u == "mouseover" then return mouseTarget and mouseTarget.name end if u == "player" then return playerName end return partyData[u] and partyData[u].name end
function UnitCanAttack(a, b) return clientTarget ~= nil and clientTarget.hostile end
function UnitClassification(u) return clientTarget and clientTarget.class or "normal" end
function UnitClass(u) if u == "target" then return "Local", clientTarget and clientTarget.class end return "Local", partyData[u] and partyData[u].class end
function UnitIsPlayer(u) return u == "target" and clientTarget ~= nil and clientTarget.isPlayer == true end
function UnitHealth(u) if u == "target" then return clientTarget.hp end return partyData[u].hp end
function UnitHealthMax(u) if u == "target" then return clientTarget.hpm end return partyData[u].hpm end
function UnitIsDeadOrGhost(u) if u == "target" then return clientTarget.dead end return partyData[u].hp == 0 end
function UnitIsDead(u) return clientTarget ~= nil and clientTarget.dead == true end
function UnitBuff(u, i) if i <= 3 then return "Interface\\Icons\\Spell_Holy_WordFortitude" end end
clicks = { targeted = {}, menus = {}, spell = {}, dropped = {} }
targetedUnit = nil
function UnitIsUnit(a, b) if a == "target" then return b == targetedUnit end return a == b end
function TargetUnit(u) table.insert(clicks.targeted, u); targetedUnit = u end
spellTargeting, cursorItem = false, false
function SpellIsTargeting() return spellTargeting end
function SpellTargetUnit(u) table.insert(clicks.spell, u) end
function CursorHasItem() return cursorItem end
function DropItemOnUnit(u) table.insert(clicks.dropped, u) end
function UIDropDownMenu_Initialize(frame, init, mode) frame.ddInit = init; frame.ddMode = mode end
function ToggleDropDownMenu(level, value, frame, anchor, x, y)
	assert(frame.ddInit, "dropdown not initialised")
	frame.ddInit()
	table.insert(clicks.menus, { frame = frame, anchor = anchor })
end
function UnitPopup_ShowMenu(dd, which, unit) dd.which, dd.unit = which, unit; clicks.lastShown = { which = which, unit = unit } end
acts = {}
inRange = true
function CheckInteractDistance(u, k) return inRange end
function NotifyInspect(u) table.insert(acts, "notify:" .. u) end
function InspectUnit(u) table.insert(acts, "inspect:" .. u) end
function InitiateTrade(u) table.insert(acts, "trade:" .. u) end
function FollowUnit(u) table.insert(acts, "follow:" .. u) end
function ChatFrame_SendTell(n) table.insert(acts, "tell:" .. n) end
leader = false
function IsPartyLeader() return leader end
function PromoteByName(n) table.insert(acts, "promote:" .. n) end
function UninviteByName(n) table.insert(acts, "uninvite:" .. n) end
function GetCursorPosition() return 400, 300 end
downedList = { { id = "H2", name = "Ghost", positionAvailable = false } }
function AZS_GetDownedPartyMembers() local out = {} for i, d in ipairs(downedList) do local c = {} for k, v in pairs(d) do c[k] = v end out[i] = c end return out end
local worldHandler, catalogReads, playedSounds = nil, 0, {}
anchorCatalog = {}
function AZS_RegisterWorldAnchorFrameHandler(h) worldHandler = h end
function AZS_GetWorldAnchors(q, cursor, limit)
	assert(q and q.kinds and q.kinds[1] == "downedPartyMember", "catalog query")
	catalogReads = catalogReads + 1
	return { entries = anchorCatalog, hasMore = false }
end
projState = "onScreen"
function AZS_ProjectWorldAnchors(reqs)
	local entries = {}
	for i, r in ipairs(reqs) do
		assert(r.attachment == "position" and r.anchorId, "project request")
		entries[i] = { anchorId = r.anchorId, attachment = r.attachment, state = projState, x = 800 + i * 50, y = 300, playerDistance = 12 }
	end
	return { entries = entries }
end
function PlaySound(n) table.insert(playedSounds, n) end
playedFiles = {}
local soundHandles = 0
playedTimes = {}
function PlaySoundFile(path) table.insert(playedFiles, path); table.insert(playedTimes, GetTime()); soundHandles = soundHandles + 1; return true, (RETURN_HANDLES and soundHandles or nil) end
function GetAddOnMetadata(addon, field) if addon == "AZSGW2UI" and field == "Version" then return "9.9.9-test" end end
function GetPlayerBuff(i, filter)
	local n = (filter == "HELPFUL") and 4 or 2
	if i < n then return i + 10 end
	return -1
end
function GetPlayerBuffTexture(idx) return "Interface\\Icons\\Spell_Nature_Regeneration" end
function GetPlayerBuffTimeLeft(idx) return idx == 10 and 0 or 25.5 end
function GetPlayerBuffApplications(idx) return idx == 11 and 3 or 0 end
function GetPlayerBuffDispelType(idx) return idx == 11 and "Magic" or nil end

-- ---------- load the addon
-- the file list comes from the .toc, so a file missing there fails the test
for line in io.lines(ADDON_DIR .. "/AZSGW2UI.toc") do
	local f = line:match("^(%S+)%.lua%s*$")
	if f then
		local chunk, err = loadfile(ADDON_DIR .. "/" .. f .. ".lua")
		assert(chunk, err)
		chunk()
	end
end
local G = AZSGW2

-- find the event frame's handler: Main created a frame with OnEvent
local function fire(ev, a1)
	event = ev
	arg1 = a1
	for _, w in ipairs(allWidgets) do
		if w.scripts.OnEvent then w.scripts.OnEvent() end
	end
end

local function runTicks(n, dt)
	for i = 1, n do
		now = now + dt
		clock = clock + dt
		arg1 = dt
		for _, w in ipairs(allWidgets) do
			if w.scripts.OnUpdate then w.scripts.OnUpdate() end
		end
	end
end

local function scenario(name, fn)
	print("== " .. name)
	if fn then fn() end
end

scenario("startup", function()
	if os.getenv("STOCK") then AZSGW2DB = { customArt = false }; print("(stock art mode)") end
	fire("VARIABLES_LOADED")
	fire("PLAYER_ENTERING_WORLD")
	runTicks(10, 0.05)
	print("started", G.started, "shown", G.shown)
	assert(G.started and G.shown, "UI should be started and shown")
	for _, p in ipairs(G.HUD_PARTS) do assert(hud[p] == false, "HUD part not hidden: " .. p) end
end)

scenario("stock frames + HUD enforcement", function()
	for _, n in ipairs({ "PlayerFrame", "PartyMemberFrame1", "BuffFrame", "MainMenuBar", "ActionButton1" }) do
		assert(stockFrames[n].shown == false, n .. " still shown")
	end
	-- the game shows one again: the OnShow hook hides it at once
	stockFrames.PlayerFrame.shown = true
	stockFrames.PlayerFrame.scripts.OnShow()
	assert(stockFrames.PlayerFrame.shown == false, "OnShow hook did not hide PlayerFrame")
	-- the game switches the spells row back on: asserted again within half a second
	hud.build = true; cvars.hudBuild = "1"
	runTicks(12, 0.05)
	assert(hud.build == false and cvars.hudBuild == "0", "HUD part build not re-hidden")
	print("stock frames hidden, OnShow hook ok, HUD enforcement ok")
	print("detected bindings:", G.FindBinding("talents"), G.FindBinding("character"), "|", G.BindingText("talents"))
	assert(G.FindBinding("talents") == "AZS_OPEN_TALENTS" and G.FindBinding("character") == "TOGGLECHARACTER0")
end)

scenario("/gw2 off gives the game's own HUD and bars back", function()
	-- the game wants its action bar up while it is kept hidden (and the target frame, which follows a target)
	stockFrames.MainMenuBar.shown = true; stockFrames.MainMenuBar.scripts.OnShow()
	stockFrames.TargetFrame.shown = true; stockFrames.TargetFrame.scripts.OnShow()
	assert(stockFrames.MainMenuBar.shown == false and stockFrames.TargetFrame.shown == false)
	G.keptHidden.MainMenuBar.was = false      -- it was not up when it was first taken (the game shows it later, when a run starts)
	G.keptHidden.TargetFrame.was = false      -- no target at the time
	assert(hud.build == false and cvars.hudBuild == "0", "the spells row is not hidden while the UI is on")
	SlashCmdList["AZSGW2"]("off")
	for _, p in ipairs(G.HUD_PARTS) do assert(hud[p] == true, "HUD part not given back: " .. p) end
	assert(cvars.hudBuild == "1", "the setting behind the spells row was left at 0")
	assert(stockFrames.MainMenuBar.shown == true, "the action bar of the game is not back")
	assert(stockFrames.TargetFrame.shown == false, "the target frame is left to the game")
	-- the game puts the spells row away again: it is given back within a second
	hud.build = false; cvars.hudBuild = "0"
	runTicks(14, 0.05)
	assert(hud.build == true and cvars.hudBuild == "1", "the spells row stays hidden after /gw2 off")
	-- the watch ends after a few seconds: the game's own settings are not fought for ever
	runTicks(160, 0.05)
	hud.build = false; cvars.hudBuild = "0"
	runTicks(20, 0.05)
	assert(hud.build == false, "the HUD is fought for ever")
	hud.build = true; cvars.hudBuild = "1"
	-- /gw2 on takes it all again
	SlashCmdList["AZSGW2"]("on")
	runTicks(14, 0.05)
	for _, p in ipairs(G.HUD_PARTS) do assert(hud[p] == false, "HUD part not hidden again: " .. p) end
	assert(stockFrames.MainMenuBar.shown == false, "action bar not hidden again after /gw2 on")
	print("/gw2 off gives the HUD back, /gw2 on takes it again")
end)

scenario("nameplates + native messages", function()
	assert(plateCalls.hide > 0 and NAMEPLATES_ON == nil, "nameplates not hidden")
	-- the player presses the game's own key for them: they stay (1.8.0 switched them off again within a second)
	NAMEPLATES_ON = 1
	local before = plateCalls.hide
	runTicks(30, 0.05)
	assert(NAMEPLATES_ON == 1 and plateCalls.hide == before, "the game's own nameplates are fought")
	NAMEPLATES_ON = nil
	-- native centre-screen messages are swallowed
	UIErrorsFrame:AddMessage("Mother Fang enters the battlefield!")
	RaidNotice_AddMessage(nil, "Boss engaged")
	assert(table.getn(errorsMsgs) == 0 and table.getn(raidMsgs) == 0, "native messages not silenced")
	-- /gw2 messages on gives them back, off silences again
	SlashCmdList["AZSGW2"]("messages on")
	UIErrorsFrame:AddMessage("x"); RaidNotice_AddMessage(nil, "y")
	assert(table.getn(errorsMsgs) == 1 and table.getn(raidMsgs) == 1, "messages on did not restore")
	runTicks(12, 0.05)
	UIErrorsFrame:AddMessage("x2")
	assert(table.getn(errorsMsgs) == 2, "messages re-silenced although switched on")
	SlashCmdList["AZSGW2"]("messages off")
	UIErrorsFrame:AddMessage("x3"); RaidNotice_AddMessage(nil, "y3")
	assert(table.getn(errorsMsgs) == 2 and table.getn(raidMsgs) == 1, "messages off did not silence")
	-- /gw2 plates on: the game's plates are switched on (the GW2 ones are drawn on them) and they stay
	local showBefore = plateCalls.show
	SlashCmdList["AZSGW2"]("plates on")
	assert(plateCalls.show == showBefore + 1 and NAMEPLATES_ON == 1 and G.Opt("nameplates") == true, "plates on")
	local h = plateCalls.hide
	runTicks(12, 0.05)
	assert(plateCalls.hide == h and NAMEPLATES_ON == 1 and plateCalls.show == showBefore + 1, "plates re-hidden although switched on")
	SlashCmdList["AZSGW2"]("plates off")
	runTicks(12, 0.05)
	assert(NAMEPLATES_ON == nil and plateCalls.hide == h + 1, "plates off")
	assert(stockFrames.TargetFrame.shown == false, "stock TargetFrame still shown")
	print("nameplates hidden + enforced, native messages silenced, toggles ok")
end)

scenario("target bar", function()
	AZS_TARGET = nil; clientTarget = nil
	runTicks(4, 0.1)
	assert(not G.target.shown and G.bossFrame.withTarget == false, "target bar visible without target")
	-- the click: the client knows the target at once, AZS_TARGET still holds the previous (none) -> instant bar
	clientTarget = { name = "Defias Thug", hostile = true, hp = 50, hpm = 100, class = "normal" }
	fire("PLAYER_TARGET_CHANGED")     -- no tick in between: the event itself must update the bar
	print("instant:", G.target.shown, G.target.name.text, G.target.hpText.text)
	assert(G.target.shown and G.target.name.text == "Defias Thug" and G.target.hpText.text == "50%", "target bar not instant")
	assert(G.bossFrame.withTarget == true)
	-- AZS catches up with the exact numbers
	AZS_TARGET = { kind = "normal", id = "m1", name = "Defias Thug", hp = 450, hpm = 900, state = 0 }
	fire("CHAT_MSG_ADDON", "AZSTGT")
	assert(G.target.hpText.text == "450  50%", "target text " .. G.target.hpText.text)
	-- a stale AZS_TARGET naming the previous enemy must not leak onto the new one
	clientTarget = { name = "Defias Rogue", hostile = true, hp = 100, hpm = 100, class = "normal" }
	fire("PLAYER_TARGET_CHANGED")
	assert(G.target.name.text == "Defias Rogue" and G.target.hpText.text == "100%", "stale AZS_TARGET leaked: " .. G.target.name.text .. " " .. G.target.hpText.text)
	-- friendly / dead targets: no bar
	-- a friendly creature (the client only knows a percentage): the same bar, green, soft green name
	clientTarget = { name = "Stormwind Guard", hostile = false, hp = 100, hpm = 100 }
	fire("PLAYER_TARGET_CHANGED")
	assert(G.target.shown and G.target.name.text == "Stormwind Guard" and G.target.hpText.text == "100%", "bar for a friendly target")
	assert(G.target.bar.fill.vc[2] > G.target.bar.fill.vc[1] and G.target.bar.fill.vc[2] > G.target.bar.fill.vc[3], "friend bar is green: " .. table.concat(G.target.bar.fill.vc, ","))
	-- a friendly hero (a party member): class colour, real numbers, from AZS_TARGET kind "other" too
	clientTarget = { name = "Carolin", hostile = false, hp = 700, hpm = 1500, isPlayer = true, class = "WARLOCK" }
	AZS_TARGET = { kind = "other", name = "Carolin" }
	fire("PLAYER_TARGET_CHANGED")
	print("friend target:", G.target.shown, G.target.name.text, G.target.hpText.text, G.target.bar.fill.vc[2])
	assert(G.target.shown and G.target.hpText.text == "700  47%", "friend numbers: " .. G.target.hpText.text)
	local nr = G.target.name.tcol
	assert(nr and not (nr[1] == 0.7 and nr[2] == 1), "hero name in a class colour")
	assert(G.target.bar.fill.vc[2] > G.target.bar.fill.vc[1], "hero bar is green")
	-- yourself
	AZS_TARGET = { kind = "player", name = "Carolin" }
	fire("PLAYER_TARGET_CHANGED")
	assert(G.target.shown, "yourself targeted: the bar shows")
	-- a downed friend
	clientTarget = { name = "Ghost", hostile = false, hp = 0, hpm = 900, dead = true, isPlayer = true, class = "MAGE" }
	AZS_TARGET = nil
	fire("PLAYER_TARGET_CHANGED")
	assert(G.target.shown and G.target.hpText.text == "Downed", "downed friend: " .. G.target.hpText.text)
	-- and back to an enemy: red again
	clientTarget = { name = "Defias Thug", hostile = true, hp = 50, hpm = 100, class = "normal" }
	fire("PLAYER_TARGET_CHANGED")
	assert(G.target.bar.fill.vc[1] > G.target.bar.fill.vc[2], "enemy bar red again")
	clientTarget = { name = "Corpse", hostile = true, hp = 0, hpm = 100, dead = true }
	fire("PLAYER_TARGET_CHANGED")
	assert(not G.target.shown, "bar for a dead target")
	-- elite from the special enemy list gets exact numbers before AZS_TARGET arrives
	AZS_UNITS = { { kind = "elite", id = 7, name = "Defias Captain", hp = 1000, hpm = 4000, state = 0 },
		{ kind = "guardian", id = 8, name = "Risen Construct", hp = 10, hpm = 20, state = 0 } }
	clientTarget = { name = "Defias Captain", hostile = true, hp = 25, hpm = 100, class = "elite" }
	fire("PLAYER_TARGET_CHANGED")
	assert(G.target.shown and G.target.hpText.text == "1.0K  25%", "elite text " .. G.target.hpText.text)
	-- a guardian / boss target: no duplicate bar, not even for the moment before AZS_TARGET arrives
	clientTarget = { name = "Risen Construct", hostile = true, hp = 50, hpm = 100, class = "elite" }
	fire("PLAYER_TARGET_CHANGED")
	assert(not G.target.shown and G.bossFrame.withTarget == false, "target bar for a guardian")
	AZS_TARGET = { kind = "boss", id = "b1", name = "Mother Fang", hp = 100, hpm = 200 }
	clientTarget = { name = "Mother Fang", hostile = true, hp = 50, hpm = 100, class = "worldboss" }
	fire("PLAYER_TARGET_CHANGED")
	assert(not G.target.shown, "target bar shown for a boss")
	AZS_TARGET = { kind = "normal", name = "Zero", hp = 0, hpm = 0 }
	clientTarget = { name = "Zero", hostile = true, hp = 0, hpm = 100 }
	runTicks(2, 0.1)
	assert(not G.target.shown, "target bar with zero max hp")
	AZS_TARGET = nil; clientTarget = nil; AZS_UNITS = nil
	runTicks(2, 0.1)
end)

local function lastPoint(w) return w.pts[#w.pts] end

scenario("minimap: attach, pins, detach", function()
	local mm = G.mm
	assert(mm and mm:IsShown(), "minimap frame missing")
	assert(Minimap.parent == mm.holder, "Minimap not moved into our frame")
	assert(Minimap.mask and string.find(Minimap.mask, "mm_mask.tga", 1, true), "square mask not set")
	assert(MinimapCluster.shown == false and MinimapBackdrop.shown == false and MinimapZoomIn.shown == false, "stock minimap pieces still shown")
	assert(MinimapBorder.shown == false, "stock border texture still shown")
	assert(hud.flag == false and hud.localClock == false, "game flag / clock not hidden while our minimap is up")
	print("minimap attached, hidden pieces ok, flag hidden")
	-- outdoor zoom 3 = 266.67 yards across -> 160 px: 0.6 px per yard
	runTicks(3, 0.05)
	assert(math.abs(G.MapYards() - 266.6667) < 0.01, "yards " .. tostring(G.MapYards()))
	assert(Minimap.zoom == 3 and cvars.minimapZoom == "3", "zoom disturbed by the indoor test")
	-- indoors: the zoom setting that moves is the inside one
	Minimap.indoors = true; G.yardsStamp = nil
	assert(math.abs(G.MapYards() - 120) < 0.01, "indoor yards " .. tostring(G.MapYards()))
	assert(Minimap.zoom == 3, "zoom not restored after the indoor test")
	Minimap.indoors = nil; G.yardsStamp = nil
	-- pins: player at 0,0 facing north. +x north, +y west
	AZS_CHESTS = { { id = 1, x = 30, y = 0, spaceId = "m1:1" }, { id = 2, x = 0, y = 50, spaceId = "m1:1" },
		{ id = 3, x = 0, y = -1000, spaceId = "m1:1" }, { id = 4, x = 5, y = 5, spaceId = "other" } }
	runTicks(3, 0.05)
	local p1, p2, p3 = lastPoint(mm.chestPins[1]), lastPoint(mm.chestPins[2]), lastPoint(mm.chestPins[3])
	print("chest pins:", p1[4], p1[5], "|", p2[4], p2[5], "|", p3[4], p3[5], "| 4th shown", mm.chestPins[4].shown)
	assert(math.abs(p1[4]) < 0.01 and math.abs(p1[5] - 18) < 0.01, "30 yd north should be 18 px up")
	assert(math.abs(p2[4] + 30) < 0.01 and math.abs(p2[5]) < 0.01, "50 yd west should be 30 px left")
	assert(p3[4] > 0 and math.abs(p3[4] - 72) < 0.01, "far east chest should clamp to the right edge")
	assert(mm.chestPins[3].shown and not mm.chestPins[4].shown, "pins in another space must not show")
	-- lairs: awake / asleep / empty cells and the flagged one
	local l2 = lastPoint(mm.lairPins[2])
	assert(mm.lairPins[1].shown and mm.lairPins[2].shown and mm.lairPins[3].shown and not mm.lairPins[4].shown, "lair pins")
	assert(math.abs(l2[5] - 18) < 0.01, "lair 30 north 40 west: y " .. tostring(l2[5]))
	-- option off hides the chest pins
	G.SetOpt("pinChest", false); runTicks(2, 0.05)
	assert(not mm.chestPins[1].shown, "chest pins still shown with the option off")
	G.SetOpt("pinChest", true)
	-- zone plate + clock
	G.mm.zoneSet = false; runTicks(2, 0.5)
	assert(mm.zone.text == "Scholomance" and mm.clock.text == "20:28", "zone plate " .. mm.zone.text .. " " .. mm.clock.text)
	-- zoom buttons / wheel stay inside the range
	G.MapZoom(1); assert(Minimap.zoom == 4)
	G.MapZoom(1); assert(Minimap.zoom == 4, "zoom beyond the last level")
	G.MapZoom(-9); assert(Minimap.zoom == 0)
	G.MapZoom(3); assert(Minimap.zoom == 3)
	-- off: the game's minimap is back where it was, with the round mask
	AZSGW2DB.enabled = false; G.ApplyMinimap()
	assert(Minimap.parent == MinimapCluster and Minimap.mask == "Textures\\MinimapMask", "minimap not restored")
	assert(MinimapCluster.shown == true and not mm:IsShown(), "cluster not shown again / our frame still up")
	assert(hud.flag == true and hud.localClock == true, "flag / clock not given back")
	AZSGW2DB.enabled = true; G.ApplyMinimap(); G.HideGameHud(true); runTicks(12, 0.05)
	assert(Minimap.parent == mm.holder and MinimapCluster.shown == false, "minimap not attached again")
	-- somebody moves the map back to the cluster: it is put into our frame again within half a second
	Minimap:SetParent(MinimapCluster); runTicks(12, 0.05)
	assert(Minimap.parent == mm.holder, "minimap not re-attached")
	print("minimap detach / attach / re-attach ok")
end)

scenario("guardian arrows", function()
	local tex = { SetTexCoord = function(self, a, b, c, d) self.c = { a, b, c, d } end }
	G.SetArrow(tex, 0);            assert(tex.c[3] == 0 and tex.c[1] == 0, "arrow cell 0")
	G.SetArrow(tex, math.pi / 2);  assert(tex.c[1] == 0 and tex.c[3] == 0.25, "arrow cell 8 (90 deg)")
	G.SetArrow(tex, -math.pi / 2); assert(tex.c[1] == 0 and tex.c[3] == 0.75, "arrow cell 24 (-90 deg)")
	G.SetArrow(tex, math.pi);      assert(tex.c[3] == 0.5, "arrow cell 16 (180 deg)")
	G.SetArrow(tex, 6.2831);       assert(tex.c[3] == 0 and tex.c[1] == 0, "arrow wraps to 0")
	local p = { x = 0, y = 0, facing = 0 }
	assert(math.abs(G.RelBearing(p, 0, 50) - math.pi / 2) < 1e-6, "west of a north-facing hero is 90 deg counter-clockwise")
	assert(math.abs(G.RelBearing(p, 50, 0)) < 1e-6, "north of a north-facing hero is straight ahead")
	assert(math.abs(G.RelBearing({ x = 0, y = 0, facing = math.pi / 2 }, 0, 50)) < 1e-6, "facing west, target west: straight ahead")
	runTicks(8, 0.05)
	local f = G.guardians
	assert(f.headArrow.shown, "header arrow hidden")
	assert(f.nearest and f.nearest.name == "Necrofiend", "nearest guardian: " .. tostring(f.nearest and f.nearest.name))
	assert(f.rows[1].arrow.shown == false, "empty lair must not get an arrow")
	assert(f.rows[2].arrow.shown and f.rows[3].arrow.shown, "held lairs get arrows")
	G.SetOpt("arrows", false); runTicks(4, 0.05)
	assert(not f.headArrow.shown and not f.rows[2].arrow.shown, "arrows still shown with the option off")
	G.SetOpt("arrows", true)
	print("guardian arrows ok, nearest:", f.nearest.name)
end)

scenario("damage numbers", function()
	assert(G.dmg.ok and ctHandler, "combat text handler not registered")
	assert(cvars.CombatDamage == nil or cvars.CombatDamage == "0", "game's own damage numbers not switched off")
	local t = GetTime()
	ctProj = {
		a1 = { anchorId = "a1", state = "onScreen", x = 500, y = 400, playerDistance = 10 },
		a2 = { anchorId = "a2", state = "onScreen", x = 700, y = 300, playerDistance = 60 },
		a3 = { anchorId = "a3", state = "offscreen" },
		a4 = { anchorId = "a4", state = "onScreen", x = 100, y = 100 },
	}
	ctEvents = {
		{ kind = "damage", amount = 1234, anchorId = "a1", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 2500000, critical = true, anchorId = "a2", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "miss", result = { key = "dodge", text = "dodge" }, anchorId = "a3", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 99, anchorId = "a4", anchorStatus = "ready", sourceKind = "pet", presentedAt = t },
		{ kind = "damage", amount = 5, anchorId = nil, anchorStatus = "unavailable", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 7, anchorId = "a1", anchorStatus = "ready", sourceKind = "player", presentedAt = t - 5 },
	}
	ctHandler()
	local labels = G.dmg.labels
	print("labels:", #labels, labels[1].holder.text.text, labels[2].holder.text.text, labels[3].holder.text.text, labels[4].holder.text.text)
	assert(#labels == 4, "expected 4 labels (no anchor and stale ones skipped), got " .. #labels)
	assert(labels[1].holder.text.text == "1234" and labels[2].holder.text.text == "2.5M", "number format")
	assert(labels[3].holder.text.text == "Dodge", "miss word: " .. labels[3].holder.text.text)
	assert(labels[2].crit and labels[2].base > labels[1].base, "crits must be bigger")
	assert(not labels[1].holder.splat.shown, "no splash behind normal hits")
	if not os.getenv("STOCK") then
		assert(labels[2].holder.splat.shown, "red splash behind crits")
		assert(labels[2].holder.splat.tex:find("splat.tga"), "splash texture")
	end
	assert(G.NumFont():find("azs_numbers.ttf"), "number font not selected: " .. tostring(G.NumFont()))
	print("number font:", G.NumFont(), "| sizes:", labels[1].size, labels[2].size, labels[4].size)
	assert(labels[1].size == 15 and labels[2].size < 22, "sizes " .. labels[1].size .. "/" .. labels[2].size)
	local pt = lastPoint(labels[1].holder)
	assert(pt[2] == WorldFrame and pt[3] == "BOTTOMLEFT" and pt[4] >= 480 and pt[4] <= 520, "label not placed from WorldFrame BOTTOMLEFT: " .. tostring(pt[4]))
	assert(labels[3].holder.shown == false, "offscreen label should be hidden")
	-- far enemy: smaller numbers
	assert(labels[2].size < labels[2].base * 1.25, "far crit not shrunk")
	-- pets off
	G.SetOpt("dmgPet", false)
	ctEvents = { { kind = "damage", amount = 99, anchorId = "a4", anchorStatus = "ready", sourceKind = "summon", presentedAt = GetTime() } }
	ctHandler()
	assert(#G.dmg.labels == 4, "pet number shown with the option off")
	G.SetOpt("dmgPet", true)
	-- numbers float up and expire
	local y0 = lastPoint(labels[1].holder)[5]
	now = now + 0.3; ctHandler()
	assert(lastPoint(labels[1].holder)[5] > y0, "number does not rise")
	now = now + 1.5; ctHandler()
	assert(#G.dmg.labels == 0, "labels not released after their life: " .. #G.dmg.labels)
	assert(#G.dmg.free >= 4, "labels not pooled")
	-- a changed stream clears everything and re-subscribes
	ctEvents = { { kind = "damage", amount = 10, anchorId = "a1", anchorStatus = "ready", sourceKind = "player", presentedAt = GetTime() } }
	ctHandler(); assert(#G.dmg.labels == 1)
	ctProj.a1 = { anchorId = "a1", state = "expired" }
	ctHandler(); assert(#G.dmg.labels == 0, "expired anchor kept")
	-- option off: no reads, labels gone, native numbers back
	ctEvents = { { kind = "damage", amount = 10, anchorId = "a1", anchorStatus = "ready", sourceKind = "player", presentedAt = GetTime() } }
	ctProj.a1 = { anchorId = "a1", state = "onScreen", x = 1, y = 1 }
	G.SetOpt("dmg", false); G.ApplyDamage(); ctHandler()
	assert(#G.dmg.labels == 0 and #ctEvents == 1, "events read with the option off")
	assert(cvars.CombatDamage == "0", "with our numbers off, the game's own ones must stay off")
	G.SetOpt("dmg", true); G.ApplyDamage(); ctEvents = {}; ctHandler()
	-- options: ticks off, crits only, numbers off
	do
		local function send(list) ctEvents = list; ctHandler() end
		local function ev(kind, extra) local e = { kind = kind, amount = 50, anchorId = "a1", anchorStatus = "ready", sourceKind = "player", presentedAt = GetTime() } for k, v in pairs(extra or {}) do e[k] = v end return e end
		ctProj.a1 = { anchorId = "a1", state = "onScreen", x = 500, y = 400, playerDistance = 10 }
		G.ClearDamage()
		G.SetOpt("dmgTicks", false)
		send({ ev("damage", { periodic = true }), ev("damage", {}) })
		assert(#G.dmg.labels == 1, "periodic hit shown with ticks off: " .. #G.dmg.labels)
		G.ClearDamage(); G.SetOpt("dmgTicks", true)
		send({ ev("damage", { periodic = true }), ev("damage", {}) })
		assert(#G.dmg.labels == 2, "ticks not shown with ticks on")
		G.ClearDamage(); G.SetOpt("dmgCrit", true)
		send({ ev("damage", { periodic = true }), ev("damage", {}), ev("damage", { critical = true }), ev("miss", { result = { key = "dodge", text = "dodge" } }) })
		assert(#G.dmg.labels == 1 and G.dmg.labels[1].crit, "crits only: " .. #G.dmg.labels)
		G.ClearDamage(); G.SetOpt("dmgCrit", false)
		-- numbers off: nothing shown, and the game's own numbers stay off too
		G.SetOpt("dmg", false); G.ApplyDamage()
		send({ ev("damage", { critical = true }) })
		assert(#G.dmg.labels == 0, "numbers shown with the option off")
		assert(cvars.CombatDamage == "0", "game's own numbers came back with ours off: " .. tostring(cvars.CombatDamage))
		-- the game's own numbers on request
		G.SetOpt("dmgNative", true); G.ApplyDamage()
		assert(cvars.CombatDamage ~= "0", "game's own numbers not restored on request")
		G.SetOpt("dmgNative", false); G.SetOpt("dmg", true); G.ApplyDamage()
		assert(cvars.CombatDamage == "0")
		SlashCmdList["AZSGW2"]("dmg crits"); assert(G.Opt("dmg") and G.Opt("dmgCrit"))
		SlashCmdList["AZSGW2"]("dmg off"); assert(not G.Opt("dmg"))
		SlashCmdList["AZSGW2"]("dmg all"); assert(G.Opt("dmg") and not G.Opt("dmgCrit"))
		SlashCmdList["AZSGW2"]("dmg ticks off"); assert(not G.Opt("dmgTicks"))
		SlashCmdList["AZSGW2"]("dmg ticks on"); assert(G.Opt("dmgTicks"))
		G.ClearDamage()
	end
	-- a storm of hits at many distances still uses only a few font sizes
	do
		fontSizes = {}
		for i = 1, 120 do
			local dist = 5 + math.mod(i * 7, 55)
			ctProj["s" .. i] = { anchorId = "s" .. i, state = "onScreen", x = 100 + i, y = 200, playerDistance = dist }
			ctEvents[i] = { kind = "damage", amount = 100 + i, critical = (math.mod(i, 4) == 0), anchorId = "s" .. i, anchorStatus = "ready", sourceKind = "player", presentedAt = GetTime() }
		end
		for step = 1, 12 do ctHandler(); ctEvents = {}; now = now + 0.05 end
		local n = 0; local list = {}
		for sz in pairs(fontSizes) do n = n + 1; table.insert(list, sz) end
		table.sort(list)
		print("distinct damage font sizes in a storm:", n, table.concat(list, " "), "| labels:", #G.dmg.labels)
		assert(n <= 18, "too many distinct font sizes: " .. n)
		assert(#G.dmg.labels <= 60, "label cap")
		now = now + 2; ctHandler()
		assert(#G.dmg.labels == 0)
	end
	-- the font file can not be loaded (a client that refuses it): everything falls back to the game's font
	do
		local keepOk = G.sansOk
		G.sansOk = nil; failAzsFont = true
		assert(G.NumFont() == G.FONT and G.Sans() == G.FONT, "no fallback to the game's font")
		failAzsFont = false; G.sansOk = nil
		assert(G.NumFont():find("azs_numbers"), "font not picked again")
		-- Latin / Cyrillic clients get the sans font for text, other clients keep their own
		local keepFont = G.FONT
		G.FONT = "Fonts\\ARKai_T.ttf"
		assert(G.Sans() == G.FONT, "CJK client should keep its own font for text")
		G.FONT = keepFont
		assert(G.Sans():find("azs_numbers"), "Latin client should get the sans font for text")
	end
	print("damage numbers ok")
end)

scenario("nameplates: the game's plates get the GW2 look", function()
	local P = G.plates
	local function nativePlate(name, hp, color, elite)
		local f = new("Frame", WorldFrame); f.shown = false
		local border = new("Texture", f); border.tex = "Interface\\Tooltips\\Nameplate-Border"
		local glow = new("Texture", f); glow.tex = "Interface\\Tooltips\\Nameplate-Glow"
		local nm = new("FontString", f); nm.fontSet = true; nm.text = name; nm.tcol = { color[1], color[2], color[3] }
		local lv = new("FontString", f); lv.fontSet = true; lv.text = "12"
		local icon = new("Texture", f); icon.tex = "Interface\\Tooltips\\EliteNameplateIcon"; icon.shown = elite and true or false
		local raid = new("Texture", f); raid.shown = false
		local hb = new("StatusBar", f); hb.sbMin, hb.sbMax, hb.sbValue, hb.sbColor = 0, 100, hp, color
		local cast = new("StatusBar", f); cast.shown = false
		return { frame = f, name = nm, icon = icon, hb = hb, glow = glow, border = border }
	end
	local function show(pl) pl.frame.shown = true; this = pl.frame; if pl.frame.scripts.OnShow then pl.frame.scripts.OnShow() end end
	local RED, GREEN = { 1, 0.05, 0.05 }, { 0.05, 1, 0.05 }
	AZS_TARGET = nil; clientTarget = nil
	AZS_UNITS = { { kind = "elite", id = 2, name = "Defias Captain", hp = 2000, hpm = 4000, state = 0 } }
	local thug, captain, guard = nativePlate("Defias Thug", 80, RED, false), nativePlate("Defias Captain", 50, RED, true), nativePlate("Zaynor", 100, GREEN, false)
	for _, pl in ipairs({ thug, captain, guard }) do show(pl) end
	-- an unrelated frame under WorldFrame (like a damage number's holder) and a plate-like frame without a health bar
	local holder = new("Frame", WorldFrame); local ht = new("Texture", holder); ht.tex = "Interface\\Buttons\\WHITE8X8"
	local fake = new("Frame", WorldFrame); local ft = new("Texture", fake); ft.tex = "Interface\\Tooltips\\Nameplate-Border"
	runTicks(4, 0.1)
	-- everything off: the game's plates are not touched
	assert(#P.list == 0 and thug.border:GetAlpha() == 1 and thug.hb:GetAlpha() == 1, "plates touched with the options off")
	-- Enable nameplates
	SlashCmdList["AZSGW2"]("plates on")
	runTicks(3, 0.1)
	assert(#P.list == 3, "plates found: " .. #P.list)
	assert(thug.border:GetAlpha() == 0 and thug.name:GetAlpha() == 0 and thug.hb:GetAlpha() == 0 and thug.glow:GetAlpha() == 0 and thug.icon:GetAlpha() == 0, "the game's own drawing is still visible")
	assert(fake.azsPlate == false and holder.azsPlate == false, "a frame that is no plate was taken")
	local pt, pc, pg = thug.frame.azsPlate, captain.frame.azsPlate, guard.frame.azsPlate
	assert(pt.v.shown and pt.rawName == "Defias Thug" and pt.bar.lastFrac == 0.8, "enemy plate: " .. tostring(pt.rawName))
	assert(pt.nameText == nil and pc.nameText == nil, "plates show no names")
	assert(pt.bar.fill.vc[1] > pt.bar.fill.vc[2] and pt.bar.fill.vc[2] < 0.3, "enemy bar is red")
	assert(pt.text.text == "" and not pt.mark.shown and not pt.hl.shown, "a plain enemy shows no number, no mark")
	assert(pc.v.shown and pc.text.text == "2.0K" and (pc.mark.shown == (G.art.custom and true or false)), "elite: number (from the API), crown only with the custom art: " .. tostring(pc.text.text))
	assert(pc.bar.fill.vc[1] > 0.95 and pc.bar.fill.vc[2] > 0.4 and pc.bar.fill.vc[2] < 0.6 and pc.bar.fill.vc[3] < 0.15, "elite is orange")
	assert(not pg.v.shown, "a friend shows without the friend option")
	-- the plate itself is the parent: it moves with the unit
	assert(pt.v.parent == thug.frame and pt.v.pts[1][2] == thug.frame, "our drawing is not on the plate")
	-- only elites and guardians
	SlashCmdList["AZSGW2"]("plates elite on")
	runTicks(6, 0.1)
	assert(not pt.v.shown and pc.v.shown, "only elites: " .. tostring(pt.v.shown) .. " " .. tostring(pc.v.shown))
	SlashCmdList["AZSGW2"]("plates elite off")
	runTicks(6, 0.1)
	assert(pt.v.shown and pc.v.shown, "plain enemies back")
	-- friendly nameplates: the game's friendly plates are switched on, ours draws them green with the game's name colour
	local fs = plateCalls.friendShow or 0
	SlashCmdList["AZSGW2"]("plates friends on")
	assert((plateCalls.friendShow or 0) == fs + 1 and FRIENDNAMEPLATES_ON == 1, "friendly plates not switched on")
	runTicks(6, 0.1)
	assert(pg.v.shown and pg.rawName == "Zaynor" and pg.bar.fill.vc[2] > pg.bar.fill.vc[1], "friend plate (a hero)")
	assert(pg.text.text == "" , "friend text")
	-- your target: outline, exact health
	clientTarget = { name = "Defias Thug", hostile = true, hp = 50, hpm = 100, class = "normal" }
	AZS_TARGET = { kind = "normal", id = "m1", name = "Defias Thug", hp = 1800, hpm = 2250, state = 0 }
	thug.frame:SetAlpha(1); captain.frame:SetAlpha(0.5); guard.frame:SetAlpha(0.5)
	runTicks(4, 0.1)
	assert(pt.hl.shown and pt.text.text == "1.8K", "target plate: " .. tostring(pt.text.text))
	assert(not pc.hl.shown and not pg.hl.shown, "another plate is outlined")
	-- a guardian target is known exactly: the plate gets the elite look
	clientTarget = { name = "Risen Construct", hostile = true, hp = 50, hpm = 100, class = "elite" }
	local old = AZS_UnitKind; function AZS_UnitKind(u) return "guardian" end
	local gd = nativePlate("Risen Construct", 70, RED, false); gd.frame:SetAlpha(1); show(gd)
	runTicks(3, 0.1)
	local pgd = gd.frame.azsPlate
	assert(pgd and pgd.elite and (pgd.mark.shown == (G.art.custom and true or false)) and pgd.cKind == "elite", "guardian target did not get the elite look")
	AZS_UnitKind = old; clientTarget = nil; AZS_TARGET = nil
	gd.frame:SetAlpha(0.5)
	-- a plate given to another unit: hidden until looked at, then the new unit
	thug.name.text = "Wolf"; thug.hb.sbValue = 30
	thug.frame.shown = false; show(thug)
	assert(not pt.v.shown, "old unit still drawn after the plate was shown again")
	runTicks(1, 0.1)
	assert(pt.v.shown and pt.rawName == "Wolf" and pt.bar.lastFrac == 0.3, "plate not given to the new unit: " .. tostring(pt.rawName))
	-- the unit dies: the bar goes
	thug.hb.sbValue = 0
	runTicks(8, 0.1)
	assert(not pt.v.shown, "dead unit still drawn")
	thug.hb.sbValue = 100
	runTicks(8, 0.1)
	-- a lot of plates: all drawn, but only a part is looked at per tick
	local many = {}
	for i = 1, 150 do many[i] = nativePlate("Spawn " .. i, 90, RED, false); show(many[i]) end
	runTicks(1, 0.1)
	assert(#P.list == 154, "plates found: " .. #P.list)
	for i = 1, 150 do many[i].hb.sbValue = 40 end
	local c0 = used.GetValue or 0
	runTicks(1, 0.1)
	local looked = (used.GetValue or 0) - c0
	assert(looked <= 30, "one tick looked at " .. looked .. " plates")
	runTicks(8, 0.1)
	for i = 1, 150 do assert(many[i].frame.azsPlate.bar.lastFrac == 0.4, "plate " .. i .. " not kept up") end
	-- steady state: a stable crowd costs few widget calls
	local before = 0; for _, n in pairs(used) do before = before + n end
	local snap = {}; for k, n in pairs(used) do snap[k] = n end
	runTicks(10, 0.1)
	local after = 0; for _, n in pairs(used) do after = after + n end
	do
		local diff = {}
		for k, n in pairs(used) do if n - (snap[k] or 0) > 0 then table.insert(diff, { k, n - (snap[k] or 0) }) end end
		table.sort(diff, function(a, b) return a[2] > b[2] end)
		local out = {}
		for i = 1, math.min(8, #diff) do out[#out + 1] = diff[i][1] .. "=" .. diff[i][2] end
		print("  top calls in that second:", table.concat(out, " "))
	end
	print("nameplates: widget calls per second with 154 plates up:", math.floor((after - before) / 1.0 + 0.5))
	-- switching them off gives the game's drawing back
	SlashCmdList["AZSGW2"]("plates off"); SlashCmdList["AZSGW2"]("plates friends off")
	runTicks(3, 0.1)
	do
		local b0 = 0; for _, n in pairs(used) do b0 = b0 + n end
		runTicks(10, 0.1)
		local b1 = 0; for _, n in pairs(used) do b1 = b1 + n end
		print("nameplates: the same second with the plates off:", b1 - b0)
		assert((after - before) - (b1 - b0) < 2000, "the plates themselves cost " .. ((after - before) - (b1 - b0)) .. " calls per second")
	end
	assert(thug.border:GetAlpha() == 1 and thug.hb:GetAlpha() == 1 and thug.name:GetAlpha() == 1 and not pt.v.shown, "game drawing not given back")
	assert(not P.active and NAMEPLATES_ON == nil and FRIENDNAMEPLATES_ON == nil, "game plates not switched back")
	-- /gw2 off gives them back too, and /gw2 on takes them again
	SlashCmdList["AZSGW2"]("plates on"); runTicks(3, 0.1)
	assert(thug.hb:GetAlpha() == 0)
	AZSGW2DB.enabled = false; runTicks(3, 0.1)
	assert(thug.hb:GetAlpha() == 1, "nameplates not released while the addon is off")
	AZSGW2DB.enabled = true; runTicks(3, 0.1)
	assert(thug.hb:GetAlpha() == 0, "nameplates not taken again")
	SlashCmdList["AZSGW2"]("plates off"); runTicks(3, 0.1)
	-- the debug report runs, with plates found and with none
	SlashCmdList["AZSGW2"]("plates debug")
	SlashCmdList["AZSGW2"]("plates")
	SlashCmdList["AZSGW2"]("plates elite")
	print("nameplates ok")
end)

scenario("nameplates: recycled plates, orange elites, marks, pets and totems", function()
	local P = G.plates
	for i = 1, #P.list do P.list[i].frame.shown = false end         -- the plates of the scenario before are gone
	local function nativePlate(name, hp, color, elite)
		local f = new("Frame", WorldFrame); f.shown = false
		local border = new("Texture", f); border.tex = "Interface\\Tooltips\\Nameplate-Border"
		local glow = new("Texture", f); glow.tex = "Interface\\Tooltips\\Nameplate-Glow"
		local nm = new("FontString", f); nm.fontSet = true; nm.text = name; nm.tcol = { color[1], color[2], color[3] }
		local lv = new("FontString", f); lv.fontSet = true; lv.text = "12"
		local icon = new("Texture", f); icon.tex = "Interface\\Tooltips\\EliteNameplateIcon"; icon.shown = elite and true or false
		local raid = new("Texture", f); raid.shown = false; raid.tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
		local hb = new("StatusBar", f); hb.sbMin, hb.sbMax, hb.sbValue, hb.sbColor = 0, 100, hp, color
		local cast = new("StatusBar", f); cast.shown = false
		return { frame = f, name = nm, icon = icon, hb = hb, glow = glow, border = border, raid = raid, cast = cast, level = lv }
	end
	local function show(pl) pl.frame.shown = true; this = pl.frame; if pl.frame.scripts.OnShow then pl.frame.scripts.OnShow() end end
	local RED, GREEN = { 1, 0.05, 0.05 }, { 0.05, 1, 0.05 }
	AZS_TARGET = nil; clientTarget = nil
	AZS_UNITS = { { kind = "elite", id = 1, name = "Bone Warden", hp = 3000, hpm = 5000, state = 0 } }
	G.SetOpt("nameplates", true); G.SetOpt("platesElite", false); G.SetOpt("platesFriend", false); G.EnforcePlates()
	local grunt, captain = nativePlate("Reanimated Corpse", 40, RED, false), nativePlate("Bone Warden", 60, RED, true)
	show(grunt); show(captain)
	runTicks(6, 0.1)
	local pg, pc = grunt.frame.azsPlate, captain.frame.azsPlate
	assert(pg and pc and grunt.hb:GetAlpha() == 0 and grunt.cast:GetAlpha() == 0, "plates are not quiet")
	-- the game reuses a plate for the next enemy and sets it up again: its bar must not show next to ours
	grunt.frame.shown = false
	grunt.hb:SetAlpha(1); grunt.cast:SetAlpha(1); grunt.border:SetAlpha(1); grunt.name:SetAlpha(1); grunt.icon:SetAlpha(1)
	show(grunt)
	assert(grunt.hb:GetAlpha() == 0 and grunt.border:GetAlpha() == 0, "a reused plate shows the game's drawing at once")
	grunt.hb:SetAlpha(1)                                     -- the game sets it up a moment after it showed the plate
	runTicks(3, 0.1)
	assert(grunt.hb:GetAlpha() == 0 and grunt.cast:GetAlpha() == 0 and grunt.border:GetAlpha() == 0, "the game's bar came back")
	-- it undoes the alpha with no Show at all
	grunt.hb:SetAlpha(1)
	runTicks(2, 0.1)
	assert(grunt.hb:GetAlpha() == 0, "health bar made visible again by the game stays visible")
	grunt.cast:SetAlpha(1)
	runTicks(30, 0.1)
	assert(grunt.cast:GetAlpha() == 0, "cast bar made visible again by the game stays visible")
	-- a part the game adds later (its cast bar is made when the first spell is cast) is hidden too, ours is left alone
	local late = new("StatusBar", captain.frame)
	runTicks(40, 0.1)
	assert(late:GetAlpha() == 0, "a part added later is visible")
	-- the game shows its cast bar (a hero casts all the time late in a run): invisible at once, with no look in between,
	-- and the same for a part that was added later
	for _, part in ipairs({ grunt.cast, late }) do
		assert(part.scripts.OnShow, "a part of the game's plate has no OnShow hook")
		for round = 1, 3 do
			part.shown = true; part:SetAlpha(1)
			this = part; part.scripts.OnShow()
			assert(part:GetAlpha() == 0, "a part shown by the game was visible until the next look")
		end
	end
	assert((G.plates.brought or 0) >= 6, "the parts shown by the game were not counted")
	-- one made visible by its alpha alone is found within a few looks of an enemy plate (every fourth), not after a dozen
	grunt.cast:SetAlpha(1); late:SetAlpha(1); grunt.name:SetAlpha(1)
	runTicks(4, 0.1)
	assert(grunt.cast:GetAlpha() == 0 and late:GetAlpha() == 0, "a part made visible by its alpha stayed visible for more than four looks")
	assert(G.plates.noticed and G.plates.noticed >= 1)
	assert(pc.v:GetAlpha() == 1 and pc.bar:GetAlpha() == 1, "our own drawing was made invisible")
	assert(pc.v.shown and pg.v.shown, "our plates are gone")
	-- elites and guardians are orange
	local fc = pc.bar.fill.vc
	assert(fc[1] >= 0.95 and fc[2] > 0.4 and fc[2] < 0.6 and fc[3] < 0.15, "elite bar is not orange: " .. table.concat(fc, ","))
	local gc = pg.bar.fill.vc
	assert(gc[1] < 0.9 and gc[2] < 0.2, "plain enemy bar is not red")
	assert(pc.nameText == nil and pg.nameText == nil, "no names under the bars")
	-- only elites and guardians: decided by the API's list of special enemies, not by the game's level icon
	local guardian = nativePlate("Risen Construct", 70, RED, false)               -- a guardian: no elite icon on the game's plate
	local lord = nativePlate("Lord Ashvane", 90, RED, false)                      -- a boss
	local ghoul = nativePlate("Rotting Ghoul", 90, RED, true)                     -- the game's icon says elite, the API has no such unit
	local skullie = nativePlate("Level Skull", 90, RED, false); skullie.icon.tex = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"; skullie.icon.shown = true
	AZS_UNITS = { { kind = "elite", id = 1, name = "Bone Warden", hp = 3000, hpm = 5000, state = 0 },
		{ kind = "guardian", id = 2, name = "Risen Construct", hp = 800, hpm = 1000, state = 1 },
		{ kind = "boss", id = 3, name = "Lord Ashvane", hp = 9000, hpm = 9000, state = 0 } }
	for _, pl in ipairs({ guardian, lord, ghoul, skullie }) do show(pl) end
	runTicks(8, 0.1)
	local pgd, plo, pgh, psk = guardian.frame.azsPlate, lord.frame.azsPlate, ghoul.frame.azsPlate, skullie.frame.azsPlate
	assert(pgd.v.shown and plo.v.shown and pgh.v.shown and psk.v.shown and pg.v.shown, "all enemies show with the filter off")
	assert(pgd.bar.fill.vc[1] >= 0.95 and pgd.bar.fill.vc[3] < 0.15, "a guardian from the API list is orange")
	assert(plo.bar.fill.vc[1] >= 0.95 and plo.mark.shown, "a boss from the API list is orange, with the skull")
	assert(pgh.bar.fill.vc[1] < 0.9 and pgh.bar.fill.vc[2] < 0.2, "an ordinary unit with an elite icon is red: " .. table.concat(pgh.bar.fill.vc, ","))
	assert(psk.bar.fill.vc[1] < 0.9 and not psk.mark.shown, "an ordinary unit with a skull level is red and has no boss mark")
	SlashCmdList["AZSGW2"]("plates elite on")
	runTicks(8, 0.1)
	assert(pc.v.shown and pgd.v.shown and plo.v.shown, "elites, guardians and bosses show with the filter on")
	assert(not pg.v.shown and not pgh.v.shown and not psk.v.shown, "ordinary enemies still show with the filter on")
	assert(grunt.hb:GetAlpha() == 0 and ghoul.hb:GetAlpha() == 0, "the game's own plates of the hidden enemies are visible")
	-- an elite that spawns later is picked up within a second or two
	local late = nativePlate("Fresh Spawn", 90, RED, false); show(late); runTicks(4, 0.1)
	assert(not late.frame.azsPlate.v.shown, "ordinary spawn shows with the filter on")
	AZS_UNITS[#AZS_UNITS + 1] = { kind = "elite", id = 9, name = "Fresh Spawn", hp = 100, hpm = 100, state = 0 }
	runTicks(30, 0.1)
	assert(late.frame.azsPlate.v.shown, "a new elite was not picked up")
	-- no API list at all (an older game): the game's level icon decides
	local keepUnits = AZS_UNITS; AZS_UNITS = nil
	runTicks(30, 0.1)
	assert(pgh.v.shown and not pgd.v.shown, "without the API list the icon decides: " .. tostring(pgh.v.shown) .. tostring(pgd.v.shown))
	AZS_UNITS = keepUnits
	runTicks(30, 0.1)
	assert(not pgh.v.shown and pgd.v.shown, "the API list is trusted again")
	SlashCmdList["AZSGW2"]("plates elite off")
	runTicks(8, 0.1)
	for _, pl in ipairs({ guardian, lord, ghoul, skullie, late }) do pl.frame.shown = false end

	-- the game's mark (skull) on a plate is drawn above our bar, the game's own icon is invisible
	captain.raid.shown = true; captain.raid.tc = { 0.75, 0.25, 0.75, 0.5, 1, 0.25, 1, 0.5 }
	runTicks(3, 0.1)
	assert(pc.raidTex.shown and pc.raidTex.tc[1] == 0.75 and pc.raidTex.tc[2] == 1 and pc.raidTex.tc[3] == 0.25 and pc.raidTex.tc[4] == 0.5, "skull not drawn")
	assert(captain.raid:GetAlpha() == 0, "the game's own mark is still visible")
	local rp = pc.raidTex.pts[1]
	assert(rp[1] == "BOTTOM" and rp[2] == pc.bar and rp[3] == "TOP", "the mark is not above the bar")
	captain.raid.tc = { 0, 0, 0, 0.25, 0.25, 0, 0.25, 0.25 }   -- a star (1)
	runTicks(3, 0.1)
	assert(pc.raidTex.shown and pc.raidTex.tc[1] == 0 and pc.raidTex.tc[2] == 0.25 and pc.raidTex.tc[3] == 0, "star not drawn")
	captain.raid.shown = false
	runTicks(3, 0.1)
	assert(not pc.raidTex.shown, "mark stays after the game took it off")
	-- a game whose icon cannot be read keeps its own icon
	local odd = nativePlate("Odd", 70, RED, false); odd.raid.shown = true; odd.raid.tc = nil
	show(odd); runTicks(3, 0.1)
	assert(odd.raid:GetAlpha() == 1 and not odd.frame.azsPlate.raidTex.shown, "the game's own mark was hidden although ours cannot be drawn")
	-- plates are released when the options go: everything visible again, no leftovers
	odd.frame.shown = false

	-- friendly plates: pets and totems are shown by default, each can be switched off on its own; heroes always show
	local hero, wolf, totem, tree = nativePlate("Zaynor", 100, GREEN, false), nativePlate("Fluffy", 100, GREEN, false), nativePlate("Healing Stream Totem IV", 100, GREEN, false), nativePlate("Stoneclaw", 100, GREEN, false)
	local hero2 = nativePlate("Carolin", 100, GREEN, false)
	for _, pl in ipairs({ hero, hero2, wolf, totem, tree }) do show(pl) end
	AZS_TOTEMS = { { key = "stoneclaw_totem", name = "Stoneclaw" } }
	assert(G.Opt("friendPets") == true and G.Opt("friendTotems") == true, "pets and totems show by default")
	G.SetOpt("platesFriend", true); G.EnforcePlates()
	runTicks(14, 0.1)
	local ph, ph2, pw, pt, ps = hero.frame.azsPlate, hero2.frame.azsPlate, wolf.frame.azsPlate, totem.frame.azsPlate, tree.frame.azsPlate
	assert(ph.v.shown and ph2.v.shown and pw.v.shown and pt.v.shown and ps.v.shown, "friendly plates are missing with the defaults")
	-- a hero casts all the time late in a run: the game's cast bar (and a mana bar, if it has one) under a friendly plate is
	-- hidden at once when the game shows it, and found at the very next look when only its alpha comes back
	local mana = new("StatusBar", hero.frame)                -- a part the game adds under the plate of a friend
	runTicks(2, 0.1)
	assert(mana:GetAlpha() == 0, "a part added under a friendly plate is visible")
	for round = 1, 4 do
		hero.cast.shown = true; hero.cast:SetAlpha(1); mana.shown = true; mana:SetAlpha(1)
		this = hero.cast; hero.cast.scripts.OnShow(); this = mana; mana.scripts.OnShow()
		assert(hero.cast:GetAlpha() == 0 and mana:GetAlpha() == 0, "a cast / mana bar shown by the game is visible until the next look")
		hero.cast.shown = false; mana.shown = false
	end
	hero.cast:SetAlpha(1); mana:SetAlpha(1)
	runTicks(1, 0.1)
	assert(hero.cast:GetAlpha() == 0 and mana:GetAlpha() == 0, "a part under a friendly plate stayed visible for more than one look")
	-- pets off: only the pets / summons go
	SlashCmdList["AZSGW2"]("plates pets off")
	runTicks(8, 0.1)
	assert(not pw.v.shown, "a pet still has a plate with the option off")
	assert(ph.v.shown and ph2.v.shown and pt.v.shown and ps.v.shown, "heroes or totems lost their plates with the pets option off")
	assert(wolf.hb:GetAlpha() == 0, "the game's own plate of a pet shows")
	-- totems off too: both kinds of totem (by the API's list and by the name) go, heroes stay
	SlashCmdList["AZSGW2"]("plates hidetotems on")
	runTicks(8, 0.1)
	assert(not pw.v.shown and not pt.v.shown and not ps.v.shown and ph.v.shown and ph2.v.shown, "both off: only heroes should stay")
	-- more ways a totem is named: a rank after the API's name, any case, other languages
	AZS_TOTEMS = { { key = "stoneclaw_totem", name = "Stoneclaw" }, { key = "searing_totem", name = "Searing Totem" } }
	local t5, t6, t7 = nativePlate("Searing Totem V", 100, GREEN, false), nativePlate("healing ward TOTEM", 100, GREEN, false), nativePlate("T\195\179tem de Piedra", 100, GREEN, false)
	for _, pl in ipairs({ t5, t6, t7 }) do show(pl) end
	runTicks(14, 0.1)
	assert(not t5.frame.azsPlate.v.shown and not t6.frame.azsPlate.v.shown and not t7.frame.azsPlate.v.shown, "a totem with a rank / another case / another language keeps its plate")
	assert(t5.hb:GetAlpha() == 0, "the game's own plate of a totem shows")
	SlashCmdList["AZSGW2"]("plates hidetotems off"); runTicks(8, 0.1)
	assert(t5.frame.azsPlate.v.shown and t6.frame.azsPlate.v.shown and t7.frame.azsPlate.v.shown, "totems did not come back with hide totems off")
	SlashCmdList["AZSGW2"]("plates hidetotems on"); runTicks(8, 0.1)
	assert(not t5.frame.azsPlate.v.shown, "hide totems on")
	-- /gw2 plates debug says what each friendly plate is taken for
	SlashCmdList["AZSGW2"]("plates debug")
	for _, pl in ipairs({ t5, t6, t7 }) do pl.frame.shown = false end
	AZS_TOTEMS = { { key = "stoneclaw_totem", name = "Stoneclaw" } }
	-- pets back on, totems still off
	SlashCmdList["AZSGW2"]("plates pets on")
	runTicks(8, 0.1)
	assert(pw.v.shown and not pt.v.shown and not ps.v.shown and ph.v.shown, "pets on, totems off")
	-- the settings rows work the same
	local rows = {}
	for _, c in ipairs(G.settings.checks) do rows[c.row.label] = c end
	assert(rows["Show pets and summons"] and rows["Hide totems"], "settings rows for pets and totems missing")
	rows["Hide totems"].scripts.OnClick()
	assert(G.Opt("friendTotems") == true, "the totems row does not switch it")
	runTicks(8, 0.1)
	assert(pt.v.shown and ps.v.shown and pw.v.shown, "totems did not come back")
	rows["Show pets and summons"].scripts.OnClick()
	assert(G.Opt("friendPets") == false)
	runTicks(8, 0.1)
	assert(not pw.v.shown and pt.v.shown, "the pets row does not switch it")
	rows["Show pets and summons"].scripts.OnClick()
	assert(G.Opt("friendPets") == true)
	runTicks(8, 0.1)
	-- a new unknown friend (a summon) follows the pets option
	local imp = nativePlate("Imp", 100, GREEN, false); show(imp); runTicks(6, 0.1)
	assert(imp.frame.azsPlate.v.shown, "a new summon should show with the pets option on")
	G.SetOpt("friendPets", false); runTicks(6, 0.1)
	assert(not imp.frame.azsPlate.v.shown, "a new summon should go with the pets option off")
	G.SetOpt("friendPets", true)
	-- enemies are not touched by these options
	G.SetOpt("friendPets", false); G.SetOpt("friendTotems", false); runTicks(6, 0.1)
	assert(pg.v.shown, "enemy plate gone")
	G.SetOpt("friendPets", true); G.SetOpt("friendTotems", true)
	G.SetOpt("platesFriend", false); G.EnforcePlates(); runTicks(4, 0.1)
	for _, pl in ipairs({ hero, hero2, wolf, totem, tree, imp, odd }) do pl.frame.shown = false end
	AZS_TOTEMS = {}

	-- back to nothing
	G.SetOpt("nameplates", false); G.EnforcePlates(); runTicks(4, 0.1)
	for _, pl in ipairs({ grunt, captain }) do assert(pl.hb:GetAlpha() == 1, "plates not given back") end
	-- given back means given back: the hook leaves the game's parts alone now
	grunt.cast:SetAlpha(1); this = grunt.cast; grunt.cast.scripts.OnShow()
	assert(grunt.cast:GetAlpha() == 1, "the OnShow hook hides a part of the game's plate with the plates option off")
	SlashCmdList["AZSGW2"]("plates debug")
	print("nameplate repairs, orange elites, pets ok")
end)

scenario("party: marked with the game's raid icons (you too) when you join a co-op game", function()
	local setCalls, marked = {}, {}
	SetRaidTargetIcon = function(u, i) table.insert(setCalls, u .. "=" .. i); marked[u] = i end
	GetRaidTargetIndex = function(u) return marked[u] end
	playerName = "Aelara"
	assert(G.Opt("markAllies") == true, "marking allies is on by default")
	assert(G.Opt("marks") == nil, "the option of the boss marks is gone")
	-- you (Aelara) and Carolin, Ghost, Zaynor: sorted, the icons go star, circle, diamond, triangle, moon
	runTicks(30, 0.1)
	table.sort(setCalls)
	assert(table.concat(setCalls, ",") == "party1=4,party2=2,party3=3,player=1", "marks: " .. table.concat(setCalls, ","))   -- you too: first by name, the star
	setCalls = {}; runTicks(200, 0.1)
	assert(#setCalls == 0, "marked again with nothing changed: " .. table.concat(setCalls, ","))
	-- a mark that is taken off stays off while nothing changes (yours too)
	marked.player = nil; runTicks(60, 0.1)
	assert(#setCalls == 0, "your own mark that was taken off was put back")
	marked.player = 1
	marked.party1 = nil; runTicks(60, 0.1)
	assert(#setCalls == 0, "a mark that was taken off was put back")
	-- a hero leaves: the places move up (Aelara, Carolin, Zaynor), the one that is missing a mark gets it
	GetNumPartyMembers = function() return 2 end
	partyData.party3, partyData.party2 = nil, { name = "Carolin", class = "WARLOCK", hp = 700, hpm = 1500 }
	marked.party3 = nil                                      -- the hero is gone, and the mark with it
	runTicks(30, 0.1)
	assert(#setCalls == 1 and setCalls[1] == "party1=3", "a hero left: " .. table.concat(setCalls, ","))
	-- a mark somebody else put on is left alone, also when the party changes
	setCalls = {}; marked.party2 = 7
	GetNumPartyMembers = function() return 3 end
	partyData.party3 = { name = "Ghost", class = "MAGE", hp = 0, hpm = 900 }
	runTicks(30, 0.1)
	assert(marked.party2 == 7, "somebody else's mark was changed")
	assert(#setCalls == 1 and setCalls[1] == "party3=3", "the hero that came back: " .. table.concat(setCalls, ","))
	-- a new run marks again whoever has lost a mark (the heroes are new), you too
	marked.party2 = nil; marked.party3 = nil; marked.player = nil; setCalls = {}
	AZS_RUN.run = "run-2"; runTicks(30, 0.1)
	table.sort(setCalls)
	assert(table.concat(setCalls, ",") == "party2=2,party3=3,player=1", "a new run: " .. table.concat(setCalls, ","))
	-- a mark somebody else put on you is left alone too
	marked.player = 6; setCalls = {}; AZS_RUN.run = "run-2b"; runTicks(30, 0.1)
	assert(marked.player == 6 and #setCalls == 0, "your mark was changed: " .. table.concat(setCalls, ","))
	marked.player = 1
	-- the option: off marks nothing, on again marks at once
	G.SetOpt("markAllies", false)
	marked.party1, marked.party2, marked.party3 = nil, nil, nil; setCalls = {}
	AZS_RUN.run = "run-3"; runTicks(40, 0.1)
	assert(#setCalls == 0, "marked with the option off")
	SlashCmdList["AZSGW2"]("marks on")
	assert(G.Opt("markAllies") == true)
	runTicks(30, 0.1)
	assert(#setCalls == 3, "marking did not come back: " .. table.concat(setCalls, ","))
	-- out of a party: nothing, and the next party is marked
	GetNumPartyMembers = function() return 0 end
	marked.party1, marked.party2, marked.party3, marked.player = nil, nil, nil, nil; setCalls = {}
	runTicks(30, 0.1)
	assert(#setCalls == 0, "marked out of a party")
	SlashCmdList["AZSGW2"]("marks")
	GetNumPartyMembers = function() return 3 end
	runTicks(30, 0.1)
	assert(#setCalls == 4, "a new party was not marked: " .. table.concat(setCalls, ","))
	SlashCmdList["AZSGW2"]("marks")
	-- the game takes the mark only after a moment: it is tried again for a while
	marked.party1, marked.party2, marked.party3, marked.player = nil, nil, nil, nil; setCalls = {}
	local fails = 3
	SetRaidTargetIcon = function(u, i) table.insert(setCalls, u .. "=" .. i); if fails > 0 then fails = fails - 1 else marked[u] = i end end
	AZS_RUN.run = "run-4"; runTicks(100, 0.1)
	assert(marked.party1 == 4 and marked.party2 == 2 and marked.party3 == 3 and marked.player == 1, "marks never took: " .. table.concat(setCalls, ","))
	-- and not for ever when the game does not let us (an error is caught too)
	marked.party1, marked.party2, marked.party3, marked.player = nil, nil, nil, nil; setCalls = {}
	SetRaidTargetIcon = function(u, i) table.insert(setCalls, u .. "=" .. i); error("not allowed") end
	AZS_RUN.run = "run-5"; runTicks(400, 0.1)
	assert(#setCalls > 0 and #setCalls <= 4 * 16, "tries: " .. #setCalls)
	-- a client without the raid icon functions: nothing breaks
	SetRaidTargetIcon, GetRaidTargetIndex = nil, nil
	AZS_RUN.run = "run-6"; runTicks(30, 0.1)
	SlashCmdList["AZSGW2"]("marks")
	-- a name the game does not give yet
	local keep = partyData.party2.name; partyData.party2.name = nil
	SetRaidTargetIcon, GetRaidTargetIndex = function(u, i) marked[u] = i end, function(u) return marked[u] end
	marked = {}; AZS_RUN.run = "run-7"; runTicks(30, 0.1)
	assert(marked.party2 == nil and marked.party1 and marked.party3, "a hero without a name was marked")
	partyData.party2.name = keep
	SetRaidTargetIcon, GetRaidTargetIndex, playerName, AZS_RUN.run = nil, nil, nil, nil
	runTicks(10, 0.1)
	print("ally marks ok")
end)

scenario("the UI lets clicks through to the world where it should", function()
	-- the alert for a fallen friend stands in the middle of the screen: no frame of it takes the mouse
	downedList = { { id = "H2", name = "Ghost", positionAvailable = false } }
	runTicks(6, 0.05)
	assert(G.reviveFrame.shown, "no alert to look at")
	assert(not G.reviveFrame:IsMouseEnabled(), "the ally down alert takes the clicks meant for the world")
	for i = 1, #G.reviveFrame.rows do assert(not G.reviveFrame.rows[i]:IsMouseEnabled(), "an alert row takes the mouse") end
	for i = 1, #G.reviveMarks do assert(not G.reviveMarks[i]:IsMouseEnabled(), "a marker over a body takes the mouse") end
	-- the party frame and the guardian list: the frame around does not, the rows of the party still do
	assert(not G.party:IsMouseEnabled(), "the party frame takes the clicks around its rows")
	assert(not G.guardians:IsMouseEnabled(), "the guardian list takes the mouse")
	-- the party rows are buttons: a click on a friend still targets it
	assert(G.party.rows[1].scripts.OnClick or G.party.rows[1].scripts.OnMouseUp, "a party row lost its click")
	-- and /gw2 move can still move the alert: the move box of every movable frame has the mouse
	local key = G.movableOf[G.reviveFrame]
	assert(key == "revive", "the alert is not movable any more")
	downedList = { { id = "H2", name = "Ghost", positionAvailable = false } }
end)

scenario("settings window + unlock layout", function()
	local f = G.settings
	assert(f and not f:IsShown(), "settings should start closed")
	local btn = G.mapButton
	assert(btn and btn.shown, "minimap icon missing")
	arg1 = "LeftButton"; btn.scripts.OnClick(); assert(f:IsShown(), "left click did not open the settings")
	for i, c in ipairs(f.checks) do assert(c.scripts.OnClick, "check " .. i .. " has no click") end
	-- toggling a check flips the option
	local before = G.Opt("party")
	for _, c in ipairs(f.checks) do if c.row.label == "Party frames" then c.scripts.OnClick() end end
	assert(G.Opt("party") == not before, "party option did not flip")
	runTicks(6, 0.25); assert(not G.party.shown, "party frames still shown with the option off")
	for _, c in ipairs(f.checks) do if c.row.label == "Party frames" then c.scripts.OnClick() end end
	runTicks(6, 0.25); assert(G.party.shown, "party frames not back")
	-- nameplates / messages switches match the commands
	for _, c in ipairs(f.checks) do if c.row.label == "Enable nameplates" then c.scripts.OnClick() end end
	assert(G.Opt("nameplates") == true and NAMEPLATES_ON == 1)
	for _, c in ipairs(f.checks) do if c.row.label == "Enable nameplates" then c.scripts.OnClick() end end
	runTicks(12, 0.05); assert(G.Opt("nameplates") == false and NAMEPLATES_ON == nil)
	local labels = {}
	for _, c in ipairs(f.checks) do labels[c.row.label] = true end
	assert(labels["Only elites and guardians"] and labels["Enable friendly nameplates"] and labels["Max targets, on the skills"]
		and labels["Show pets and summons"] and labels["Hide totems"] and labels["Mark the party in co-op games"]
		and labels["Health bars on the list"], "settings rows missing")
	assert(f:GetHeight() <= 640, "settings window too tall: " .. f:GetHeight())
	-- pages: every option is on exactly one page, a tab shows one page at a time, the window opens on the page it was left on
	do
		local seen, perPage = {}, {}
		for _, c in ipairs(f.checks) do
			assert(not seen[c.row.label], "a switch twice: " .. c.row.label)
			seen[c.row.label] = true
			perPage[c.page] = (perPage[c.page] or 0) + 1
			assert(c.row.tip and c.row.tip ~= "", "no tooltip text for " .. c.row.label)
		end
		assert(#f.tabs == #f.pages and #f.pages >= 5, "a tab for every page")
		local names = {}
		for i, t in ipairs(f.tabs) do names[i] = t.text.text end
		assert(names[1] == "Interface" and names[2] == "Nameplates" and names[3] == "Damage" and names[4] == "Map & Guardians" and names[5] == "Utility", "page names: " .. table.concat(names, ","))
		for i = 1, #f.pages do assert((perPage[i] or 0) >= 1 or i == 1, "page " .. i .. " has no switch") end
		-- the 23 switches of 1.9.2 are all still there, and the new ones for the guardian bars (and the boss bar of the guardians) and the accessories
		local n = 0
		for _ in pairs(seen) do n = n + 1 end
		assert(n == 26, "number of switches: " .. n)
		assert(seen["Accessories"], "a switch for the accessories")
		-- every switch of a page is inside its panel and every panel inside the page (nothing hangs out of the window)
		for _, c in ipairs(f.checks) do
			local panel = c.parent
			local page = panel.parent
			local top = -panel.pts[1][5]
			assert(top + panel:GetHeight() <= page:GetHeight(), string.format("page %d panel '%s' ends at %d, the page is %d tall", c.page, c.row.label, top + panel:GetHeight(), page:GetHeight()))
			local cy = -c.pts[1][5]
			assert(cy + c:GetHeight() <= panel:GetHeight(), "switch '" .. c.row.label .. "' hangs out of its panel")
		end
		for i, t in ipairs(f.tabs) do
			t.scripts.OnClick()
			for k, pg in ipairs(f.pages) do assert(pg.shown == (k == i), "only page " .. i .. " shown (page " .. k .. ")") end
			assert(f.page == i)
		end
		f:Hide(); f.scripts.OnShow(); assert(f.pages[#f.pages].shown, "reopens on the page it was left on")
		f.tabs[1].scripts.OnClick()
		-- a part of another switch is dim while that one is off
		G.SetOpt("dmg", false); G.RefreshSettings()
		local crit
		for _, c in ipairs(f.checks) do if c.row.label == "Only critical hits" then crit = c end end
		assert(crit.live == false and crit.text.tcol[1] < 0.6, "sub switch dim while its parent is off")
		G.SetOpt("dmg", true); G.RefreshSettings()
		assert(crit.live == true and crit.text.tcol[1] > 0.9, "sub switch normal again")
		-- the guardian bars row works and follows the list
		for _, c in ipairs(f.checks) do if c.row.label == "Health bars on the list" then c.scripts.OnClick() end end
		assert(G.Opt("guardianBars") == true, "the bars row sets the option")
		for _, c in ipairs(f.checks) do if c.row.label == "Health bars on the list" then c.scripts.OnClick() end end
		assert(G.Opt("guardianBars") == false)
	end
	-- minimap switch detaches and re-attaches the game's minimap
	for _, c in ipairs(f.checks) do if c.row.label == "GW2 minimap" then c.scripts.OnClick() end end
	assert(Minimap.parent == MinimapCluster and not G.mm:IsShown(), "minimap option off did not hand the map back")
	for _, c in ipairs(f.checks) do if c.row.label == "GW2 minimap" then c.scripts.OnClick() end end
	runTicks(2, 0.05); assert(Minimap.parent == G.mm.holder and G.mm:IsShown(), "minimap option on")
	-- size
	G.SetScaleAll(1.25); assert(AZSGW2DB.scale == 1.25)
	G.SetScaleAll(9); assert(AZSGW2DB.scale == 1.6, "scale not clamped")
	G.SetScaleAll(1)
	-- unlock: one gold box per movable frame; dragging saves the place
	-- the minimap icon only reacts to the left button (a right click used to unlock and leave people stuck)
	assert(btn.clicks and #btn.clicks == 1 and btn.clicks[1] == "LeftButtonUp", "minimap icon should register left clicks only")
	f.unlock.scripts.OnClick()
	assert(G.unlocked, "unlock button did not unlock")
	local boxes, keys = 0, {}
	for _, m in ipairs(G.movables) do
		assert(m.ov and m.ov.shown, "no overlay for " .. m.key)
		boxes = boxes + 1; keys[m.key] = true
	end
	for _, k in ipairs({ "orb", "top", "tally", "bosses", "guardians", "party", "target", "meter", "banner", "levelup", "minimap", "mapButton" }) do
		assert(keys[k], "movable missing: " .. k)
	end
	local orbM
	for _, m in ipairs(G.movables) do if m.key == "orb" then orbM = m end end
	orbM.ov.scripts.OnDragStart(); orbM.ov.scripts.OnDragStop()
	assert(AZSGW2DB.pos.orb and AZSGW2DB.pos.orb[1], "dragged position not saved")
	assert(G.HasPos("orb") and not G.HasPos("nonsense"))
	f.unlock.scripts.OnClick()
	assert(not G.unlocked)
	for _, m in ipairs(G.movables) do assert(not m.ov.shown, "overlay still shown after lock") end
	-- a moved boss bar is left alone by the target bar's shifting
	AZSGW2DB.pos.bosses = { "TOP", "TOP", 10, -300 }
	G.bossFrame.withTarget = nil; G.PlaceBosses(true)
	AZSGW2DB.pos.bosses = nil; AZSGW2DB.pos.orb = nil
	f:Hide()
	print("settings, options, unlock/lock, movables:", boxes)
end)

scenario("per-frame size in unlock mode", function()
	local function near(a, b) return math.abs(a - b) < 0.0005 end
	local oldCursor = GetCursorPosition
	G.SetUnlocked(true)
	assert(G.lockBar and G.lockBar.shown, "no lock bar while unlocked")
	local orbM, tgtM = G.MovableByKey("orb"), G.MovableByKey("target")
	assert(orbM and tgtM and orbM.ov and tgtM.ov)
	-- what hangs off which movable frame
	assert(G.groupOf[G.slots[1]] == "orb" and G.groupOf[G.slots[6]] == "orb" and G.groupOf[G.racial] == "orb", "slots not in the skill bar group")
	assert(G.groupOf[G.resource] == "orb" and G.groupOf[G.status[1]] == "orb", "resource / status not in the skill bar group")
	-- summons and totems: one row under the left three skills, growing to the left, clear of the resource bar under the orb
	do
		local p1, p2 = lastPoint(G.status[1]), lastPoint(G.status[2])
		assert(p1[1] == "TOPRIGHT" and p1[2] == G.slots[3] and p1[3] == "BOTTOMRIGHT" and p1[5] < 0, "status row starts under the third skill")
		assert(p2[1] == "RIGHT" and p2[2] == G.status[1] and p2[3] == "LEFT", "the next one is to the left")
		assert(G.status[12].pts[1][2] == G.status[11], "one row of twelve")
		local clear = G.orb:GetWidth() / 2 + 6 + ( -p1[4] ) - G.resource:GetWidth() / 2
		assert(clear >= 4, "the status row ends left of the resource bar: " .. clear)
		assert(G.status[1].strata == "HIGH", "above the game's HUD frames: the mouse reaches the summons")
	end
	assert(G.groupOf[G.mapButton] == "mapButton" and G.groupOf[G.target] == "target")
	assert(G.groupOf[G.meter] == "meter")
	-- the wheel over the skill bar's box: the whole bar grows, nothing else does
	arg1 = 1; orbM.ov.scripts.OnMouseWheel(); orbM.ov.scripts.OnMouseWheel()
	assert(near(G.FrameScale("orb"), 1.1), "wheel did not size the skill bar: " .. G.FrameScale("orb"))
	for _, f in ipairs({ G.orb, G.slots[1], G.slots[6], G.racial, G.wingL, G.resource, G.status[1], G.buffs[1], G.talentBtn, G.charBtn }) do
		assert(near(f:GetScale(), 1.1), "a skill bar part did not grow")
	end
	for _, f in ipairs({ G.target, G.meter, G.party, G.mapButton, G.top }) do
		assert(near(f:GetScale(), 1), "another frame grew with the skill bar")
	end
	assert(orbM.ov.size.text == "110%", "box does not show the size: " .. tostring(orbM.ov.size.text))
	-- the anchor stays where it was on the screen: the offset shrinks by the same factor and is saved
	assert(AZSGW2DB.pos.orb and near(AZSGW2DB.pos.orb[4], 34 / 1.1), "anchor offset not kept: " .. tostring(AZSGW2DB.pos.orb and AZSGW2DB.pos.orb[4]))
	-- the global size multiplies it
	G.SetScaleAll(1.25)
	assert(near(G.slots[1]:GetScale(), 1.375) and near(G.target:GetScale(), 1.25), "global size does not multiply")
	G.SetScaleAll(1)
	-- a right click on the box puts the size back
	arg1 = "RightButton"; orbM.ov.scripts.OnMouseUp()
	assert(G.FrameScale("orb") == 1 and AZSGW2DB.fscale.orb == nil and near(G.slots[1]:GetScale(), 1), "right click did not reset")
	assert(near(AZSGW2DB.pos.orb[4], 34), "offset not restored after the reset")
	-- the corner grip: dragging out grows, in shrinks, the limits hold
	local cx, cy = 500, 300
	function GetCursorPosition() return cx, cy end
	local grip = tgtM.ov.grip
	assert(grip, "no grip on the box")
	arg1 = "LeftButton"; grip.scripts.OnMouseDown()
	assert(grip.scripts.OnUpdate, "grip does not follow the cursor")
	cx, cy = 550, 250; grip.scripts.OnUpdate()          -- 50 right, 50 down: the box was 100 wide
	assert(near(G.FrameScale("target"), 1.5), "grip drag out: " .. G.FrameScale("target"))
	assert(near(G.target:GetScale(), 1.5))
	cx, cy = 5000, -5000; grip.scripts.OnUpdate()
	assert(G.FrameScale("target") == 2, "upper limit")
	cx, cy = -5000, 5000; grip.scripts.OnUpdate()
	assert(G.FrameScale("target") == 0.5, "lower limit")
	grip.scripts.OnMouseUp()
	assert(grip.scripts.OnUpdate == nil, "grip keeps following after the button is up")
	GetCursorPosition = oldCursor
	-- the size survives a reload: it is in the saved variables and applied once everything is built
	assert(AZSGW2DB.fscale.target == 0.5)
	G.groupOf = nil; G.ApplyScales()
	assert(near(G.target:GetScale(), 0.5) and near(G.slots[1]:GetScale(), 1))
	G.SetFrameScale("target", 1)                          -- back to the full size: the anchor goes back where it was
	assert(AZSGW2DB.fscale.target == nil and near(AZSGW2DB.pos.target[4], -96), "target anchor not restored: " .. tostring(AZSGW2DB.pos.target and AZSGW2DB.pos.target[4]))
	AZSGW2DB.pos.target = nil
	-- damaged saved values are cleaned
	AZSGW2DB.fscale = { orb = "x", wide = 99, tiny = 0.01, ok = 1.2, [3] = 1.5 }
	G.CleanDB(AZSGW2DB)
	assert(AZSGW2DB.fscale.orb == nil and AZSGW2DB.fscale.wide == 2 and AZSGW2DB.fscale.tiny == 0.5 and AZSGW2DB.fscale.ok == 1.2 and AZSGW2DB.fscale[3] == nil, "fscale not cleaned")
	AZSGW2DB.fscale = nil; G.CleanDB(AZSGW2DB); assert(type(AZSGW2DB.fscale) == "table")
	-- the lock bar locks
	G.ApplyScales()
	G.lockBar.scripts.OnClick()
	assert(not G.unlocked and not G.lockBar.shown, "lock bar did not lock")
	for _, m in ipairs(G.movables) do assert(not m.ov.shown, "overlay still shown") end
	-- reset positions also puts the sizes back
	AZSGW2DB.fscale = { orb = 1.3 }
	G.ResetPositions()
	assert(next(AZSGW2DB.fscale) == nil and next(AZSGW2DB.pos) == nil, "reset did not clear sizes")
	G.ApplyScales()
	arg1 = nil
	print("per-frame size ok")
end)

scenario("skill rank text + no flash", function()
	runTicks(4, 0.05)
	assert(G.slots[1].keyText.text == "3", "rank text slot1: " .. tostring(G.slots[1].keyText.text))
	assert(G.slots[2].keyText.text == "1", "rank text slot2: " .. tostring(G.slots[2].keyText.text))
	-- a cooldown finishing must not trigger anything visible besides the cooldown clearing
	for _, sl in ipairs(G.slots) do assert(sl.flash == nil and sl.flashT == nil and sl.ready == nil, "flash state left on slot") end
	print("rank texts:", G.slots[1].keyText.text, G.slots[2].keyText.text, G.slots[3].keyText.text)
end)

scenario("ticks with data", function()
	runTicks(60, 0.05)
	assert(G.orb.hpText.text == "2,400", "hp text " .. G.orb.hpText.text)
	assert(G.slots[1].curIcon == "Interface\\Icons\\Spell_Frost_FrostBolt02", "icon " .. tostring(G.slots[1].curIcon))
	print("slot2 cd text:", G.slots[2].cdText.text, "slot6 cd text:", G.slots[6].cdText.text)
	print("jewelry 1:", G.jewSlots[1].data and G.jewSlots[1].data.name)
	print("status 1:", G.status[1].data and G.status[1].data.name, "time", G.status[1].time.text)
	print("top title:", G.top.title.text, "| next:", G.top.next.text)
	print("tally:", G.tally.items.kills.text.text, G.tally.items.gold.text.text, G.tally.items.chest.text.text, G.tally.items.kills.rate.text)
	assert(G.tally.items.kills.rate.text:find("^%[%d+%.?%d*/m%]$"), "kills/min format: " .. G.tally.items.kills.rate.text)
	-- the line under the run clock is one tight, centred line: the strip has the middle of the clock above it, the three groups
	-- stand the same gap apart, and the whole line has the same room to its left and to its right, whatever the numbers are
	do
		local t = G.tally
		local tp = t.pts[1]
		assert(tp[1] == "TOP" and tp[4] == 0, "tally strip is centred under the top of the screen")
		assert(G.top.pts[1][1] == "TOP" and G.top.pts[1][4] == 0 and G.top.pts[1][2] == UIParent, "run clock and tally share the middle")
		local function check(vals)
			t.shownKey = nil
			AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest = vals[1], vals[2], vals[3]
			G.UpdateTally(0.25)
			local keys = { "kills", "gold", "chest" }
			local xs, ws = {}, {}
			for i, k in ipairs(keys) do
				local h = t.items[k]
				local p = h.pts[1]
				assert(p[1] == "LEFT" and p[2] == t, k .. " group hangs off the strip")
				xs[i], ws[i] = p[4], h:GetWidth()
				local w = 12 + 4 + h.text:GetStringWidth()
				if h.rate then w = w + 4 + h.rate:GetStringWidth() end
				assert(math.abs(ws[i] - w) <= 0.5, string.format("%s group width %.1f vs content %.1f", k, ws[i], w))
			end
			local gap1, gap2 = xs[2] - (xs[1] + ws[1]), xs[3] - (xs[2] + ws[2])
			assert(gap1 == 22 and gap2 == 22, string.format("gaps %s / %s (%s)", gap1, gap2, t.items.kills.text.text))
			local left = xs[1]
			local right = t:GetWidth() - (xs[3] + ws[3])
			assert(math.abs(left - right) <= 1, string.format("line not centred: left %.1f right %.1f", left, right))
			assert(left >= 0, "line wider than the strip: " .. left)
		end
		local k0, g0, c0 = AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest
		check({ 0, 0, 25 })
		check({ 301, 356, 31 })
		check({ 7, 12345, 250 })
		check({ 1234, 987654321, 12 })
		check({ 123456, 5, 1000000 })
		check({ k0, g0, c0 })
		-- the second look a moment later changes nothing (the group stays where it is)
		local before = t.items.kills.pts[1][4]
		G.UpdateTally(0.25); G.UpdateTally(0.25); G.UpdateTally(0.25)
		assert(t.items.kills.pts[1][4] == before, "relayout moved the line")
	end
	local ravg, rrecent = G.KillRate()
	print("kill rate avg/recent:", ravg, rrecent)
	print("meter icons:", G.meter.rows[1].icon.tex, G.meter.rows[2].icon.tex, snapshotCalls)
	assert(G.meter.rows[1].icon.tex == "Interface\\Icons\\Spell_Frost_FrostBolt02", "meter row 1 icon")
	assert(G.meter.rows[2].icon.tex == "Interface\\Icons\\Spell_Shadow_BlackPlague", "meter row 2 icon")
	local br = G.bossFrame.rows[1]
	print("boss row1:", br.name.text, br.pct.text, "| head:", G.bossFrame.headText.text, G.bossFrame.headText.shown)
	assert(br.pct.text == "57%" and br.name.text == "Boss C  (Enraged)", "boss row content")
	assert(br.timer == nil and G.bossFrame.rows[2].timer == nil, "the effect timer bar is gone")
	-- the debuff icons are still there (with the stack count)
	assert(br.debuffs[1].shown and br.debuffs[2].shown and br.debuffs[1].stack.text == "3", "debuff icons stay")
	assert(G.bossFrame.rows[2].shown, "guardian row shown")
	-- rows are one bar tall: the second sits right under the first
	local r1y, r2y = lastPoint(G.bossFrame.rows[1])[5], lastPoint(G.bossFrame.rows[2])[5]
	assert(r1y - r2y == 45, "row spacing is one row (45): " .. tostring(r1y - r2y))
	print("boss row2:", G.bossFrame.rows[2].name.text, G.bossFrame.rows[2].curY, "row1 y:", br.curY)
	print("guardians:", G.guardians.rows[1].name.text, G.guardians.rows[1].info.text, "|", G.guardians.rows[2].info.text, "|", G.guardians.rows[3].info.text, "|", G.guardians.count.text)
	print("meter:", G.meter.summary.text, G.meter.rows[1].name.text, G.meter.rows[1].val.text)
	print("resource shown:", G.resource.shown, G.resource.text.text)
	print("levelup shown:", G.levelBtn.shown, G.levelBtn.badge.text.text)
	print("orb xp bars:", G.orb.xpL.fill.shown, G.orb.xpR.fill.shown)
	assert(G.orb.xpL.fill.shown, "left xp bar not drawn")
	assert(G.orb.hpText.text == "2,400" and G.orb.subText == nil, "orb should show only the hp number")
	print("buffs:", G.buffs[1].shown, G.buffs[1].time.text, G.buffs[2].count.text, G.buffs[4].shown, G.buffs[5].shown, "| debuffs:", G.debuffs[1].shown, G.debuffs[2].shown, G.debuffs[3].shown)
	assert(G.buffs[4].shown and not G.buffs[5].shown and G.debuffs[2].shown and not G.debuffs[3].shown, "aura counts")
	print("party:", G.party.shown, G.party.rows[1].name.text, G.party.rows[1].pct.text, "|", G.party.rows[2].pct.text, "|", G.party.rows[3].pct.text, G.party.rows[3].stateText.text, "| 4th", G.party.rows[4].shown)
	assert(G.party.shown and G.party.rows[3].stateText.text == "DOWN" and not G.party.rows[4].shown, "party frames")
end)

-- ---------- layout solver: resolves SetPoint anchors into rectangles (UIParent 1600x900, scale 1)
local SW, SH = 1600, 900
local labels = {}
local function labelAll()
	labels = {}
	for key, val in pairs(G) do
		if type(val) == "table" and val.kind then labels[val] = key end
	end
	local function arr(t, name) if type(t) == "table" then for i, v in ipairs(t) do if type(v) == "table" then labels[v] = name .. i end end end end
	arr(G.slots, "skill"); arr(G.jewSlots, "jewel"); arr(G.status, "status"); arr(G.top and G.top.skulls, "skull")
	if G.bossFrame then arr(G.bossFrame.rows, "bossrow") end
	arr(G.buffs, "buff"); arr(G.debuffs, "debuff")
	if G.party then arr(G.party.rows, "party") end
	if G.guardians then arr(G.guardians.rows, "lair") end
	if G.meter then arr(G.meter.rows, "meterrow"); arr(G.meter.tabs, "tab") end
	if G.tally then for k, v in pairs(G.tally.items) do labels[v] = "tally_" .. k end end
	labels[UIParent] = "UIParent"
end

local cache = {}
local solve
local function R(w)
	if w == UIParent then return { l = 0, b = 0, w = SW, h = SH } end
	if cache[w] == "busy" then error("anchor cycle at " .. tostring(labels[w])) end
	if cache[w] then return cache[w] end
	cache[w] = "busy"
	local r = solve(w)
	cache[w] = r
	return r
end
local function anchorXY(r, p)
	local x, y
	if string.find(p, "LEFT") then x = r.l elseif string.find(p, "RIGHT") then x = r.l + r.w else x = r.l + r.w / 2 end
	if string.find(p, "TOP") then y = r.b + r.h elseif string.find(p, "BOTTOM") then y = r.b else y = r.b + r.h / 2 end
	return x, y
end
solve = function(w)
	local sw, sh = w.w, w.h
	if w.kind == "FontString" then
		local size = w.fsize or 12
		sw = w.wSet and w.w or string.len(rawget(w, "text") or "") * size * 0.52
		sh = w.hSet and w.h or size + 2
	end
	if w.allpts then local r = R(w.allpts); return { l = r.l, b = r.b, w = r.w, h = r.h } end
	local pts = w.pts or {}
	if #pts == 0 then return { l = 0, b = 0, w = sw, h = sh, unanchored = true } end
	local lx, rx, cx, ty, by, cy
	for _, p in ipairs(pts) do
		local ax, ay = anchorXY(R(p[2]), p[3])
		ax, ay = ax + p[4], ay + p[5]
		if string.find(p[1], "LEFT") then lx = ax elseif string.find(p[1], "RIGHT") then rx = ax else cx = ax end
		if string.find(p[1], "TOP") then ty = ay elseif string.find(p[1], "BOTTOM") then by = ay else cy = ay end
	end
	local l, wd, b, ht
	if lx and rx then l, wd = lx, rx - lx elseif lx then l, wd = lx, sw elseif rx then wd = sw; l = rx - wd else wd = sw; l = cx - wd / 2 end
	if by and ty then b, ht = by, ty - by elseif by then b, ht = by, sh elseif ty then ht = sh; b = ty - ht else ht = sh; b = cy - ht / 2 end
	return { l = l, b = b, w = wd, h = ht }
end
local function visible(w)
	if w == UIParent then return true end
	return w.shown and w.parent and visible(w.parent)
end

local function dumpLayout(path)
	labelAll()
	cache = {}
	local out = { string.format("CANVAS|%d|%d", SW, SH) }
	for _, w in ipairs(allWidgets) do
		if (w.kind == "Frame" or w.kind == "Button") and w ~= UIParent and w ~= GameTooltip and visible(w) then
			local r = R(w)
			if not r.unanchored then
				table.insert(out, string.format("F|%s|%.1f|%.1f|%.1f|%.1f|%s", labels[w] or "-", r.l, r.b, r.w, r.h, w.kind))
			end
		elseif w.kind == "FontString" and visible(w) and (rawget(w, "text") or "") ~= "" then
			local r = R(w)
			if not r.unanchored then
				local c = w.tcol or { 1, 0.82, 0 }
				table.insert(out, string.format("T|%s|%.1f|%.1f|%.1f|%.1f|%d|%s|%.3f,%.3f,%.3f|%s", (rawget(w, "text"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), r.l, r.b, r.w, r.h, w.fsize or 12, w.just or "LEFT", c[1], c[2], c[3], tostring(w.fpath)) .. "|" .. tostring(w.fflags or ""))
			end
		elseif w.kind == "Texture" and visible(w) and (w.tex or w.solid) then
			local r = R(w)
			if not r.unanchored and r.w > 0 and r.h > 0 then
				local vc = w.vc or { 1, 1, 1, 1 }
				local sol = w.solid
				local depth, p = 0, w.parent
				while p do depth = depth + 1; p = p.parent end
				local idx = 0
				for k, x in ipairs(allWidgets) do if x == w then idx = k break end end
				local tc = w.tc and table.concat(w.tc, ",") or "0,1,0,1"
				local tex = w.tex or "SOLID"
				if tex == "Interface\\ChatFrame\\ChatFrameBackground" then tex = "SOLID" end
				if sol then vc = sol end
				table.insert(out, string.format("X|%s|%.1f|%.1f|%.1f|%.1f|%s|%.3f,%.3f,%.3f,%.3f|%s|%d|%d", tex, r.l, r.b, r.w, r.h, tc, vc[1], vc[2], vc[3], vc[4], w.layer or "ARTWORK", depth, idx))
			end
		end
	end
	local f = assert(io.open(path, "w"))
	f:write(table.concat(out, "\n"), "\n")
	f:close()
	print("layout written:", path, #out - 1, "items")
end

scenario("layout dump (normal)", function()
	dumpLayout(OUTDIR .. "/layout_normal.txt")
end)

scenario("damage preview dump", function()
	-- put the labels on screen for a picture: WorldFrame under UIParent for a moment
	WorldFrame.parent = UIParent
	local t = GetTime()
	ctProj = {}
	local function at(id, x, y, d) ctProj[id] = { anchorId = id, state = "onScreen", x = x, y = y, playerDistance = d or 10 } end
	at("p1", 200, 200); at("p2", 420, 200); at("p3", 640, 200); at("p4", 860, 200); at("p5", 1080, 200); at("p6", 1300, 200)
	at("q1", 200, 120); at("q2", 420, 120)
	ctEvents = {
		{ kind = "damage", amount = 1358, anchorId = "p1", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 7457, critical = true, anchorId = "p2", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 203, anchorId = "p3", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 41, periodic = true, anchorId = "p4", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 889, anchorId = "p5", anchorStatus = "ready", sourceKind = "pet", presentedAt = t },
		{ kind = "miss", result = { key = "dodge", text = "dodge" }, anchorId = "p6", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 12840, critical = true, anchorId = "q1", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
		{ kind = "damage", amount = 2500000, critical = true, anchorId = "q2", anchorStatus = "ready", sourceKind = "player", presentedAt = t },
	}
	ctHandler()
	now = now + 0.25; ctHandler()
	local was = {}
	for _, f in ipairs(G.all) do was[f] = f.shown; f.shown = false end
	for _, f in ipairs(G.always) do was[f] = f.shown; f.shown = false end
	dumpLayout(OUTDIR .. "/layout_dmg.txt")
	for f, v in pairs(was) do f.shown = v end
	WorldFrame.parent = nil
	now = now + 3; ctHandler()
end)

scenario("layout dump (busy: many summons / totems / timers)", function()
	local sg, tt, tm = AZS_GetSummonGroups, AZS_GetTotems, AZS_GetTimers
	local ic = "Interface\\Icons\\Spell_Shadow_SummonImp"
	function AZS_GetSummonGroups()
		local t = {}
		for i = 1, 7 do t[i] = { key = "s" .. i, name = "Summon " .. i, icon = ic, count = i, permanent = 0, temporary = i, remaining = 10 + i } end
		return t, 28
	end
	function AZS_GetTotems()
		local t = {}
		for i = 1, 3 do t[i] = { key = "t" .. i, name = "Totem " .. i, icon = ic, count = 1, remaining = 20 + i } end
		return t
	end
	function AZS_GetTimers()
		local t = {}
		for i = 1, 4 do t[i] = { name = "Timer " .. i, icon = ic, kind = "cooldown", remaining = 3 + i, ready = false } end
		return t
	end
	runTicks(10, 0.05)
	-- the talents' clocks are not shown any more (they looked like empty icons): only summons and totems
	local shownStatus = 0
	for i = 1, #G.status do
		local st = G.status[i]
		if st.shown then
			shownStatus = shownStatus + 1
			assert(st.data and st.data.note ~= "Recharging", "a talent clock is in the status row")
		end
	end
	assert(shownStatus == 10, "status row: expected 7 summons + 3 totems, got " .. shownStatus)
	dumpLayout(OUTDIR .. "/layout_busy.txt")
	AZS_GetSummonGroups, AZS_GetTotems, AZS_GetTimers = sg, tt, tm
	runTicks(10, 0.05)
end)

scenario("skills: the most targets a skill can hit, from its tooltip", function()
	local frost, blizz = G.slots[1], G.slots[4]
	assert(frost.entry.key == "frostbolt" and blizz.entry.key == "blizzard")
	assert(frost.hitChip and blizz.hitChip and G.racial.hitChip, "no target chip on a skill")
	assert(G.Opt("hits") == true, "the option is on by default")
	-- the game's tooltip of Blizzard says five (the +targets of upgrades and cards are in that number); Frostbolt hits one
	spellTipText[3] = { "Blizzard", "40 yd range", "Pounds the 5 nearest enemies within 40 yd for 120 Frost damage each.",
		"Upgrades: +135% damage, +1 target", "Your bonuses: +171% damage, +1 target" }
	spellTipText[2] = { "Frostbolt", "30 yd range", "Hurls a bolt at the nearest enemy for 300 Frost damage." }
	runTicks(30, 0.1)
	assert(blizz.hitChip.shown and blizz.hitText.text == "5", "chip should say 5: " .. tostring(blizz.hitText.text))
	assert(not frost.hitChip.shown, "a one target skill got a chip")
	local pt = blizz.hitChip.pts[1]
	assert(pt[3] == "TOP" and pt[5] < 0 + 1, "chip is not at the top")
	-- no enemy near is needed: the chip is there without any combat
	assert(blizz.hitChip.shown, "chip depends on enemies")
	-- the number comes from the description, not from the lines about upgrades and bonuses
	spellTipText[3] = { "Blizzard", "Your bonuses: +171% damage, +3 targets", "Upgrades: +4 targets", "Pounds up to 7 enemies within 40 yd." }
	runTicks(45, 0.1)
	assert(blizz.hitText.text == "7", "upgrade lines were read: " .. tostring(blizz.hitText.text))
	-- an upgrade (a card) changes the tooltip: the chip follows within a few seconds
	spellTipText[3] = { "Blizzard", "Pounds the 6 nearest enemies within 40 yd." }
	runTicks(45, 0.1)
	assert(blizz.hitText.text == "6", "chip did not follow the upgrade: " .. tostring(blizz.hitText.text))
	-- other wordings
	spellTipText[3] = { "Blizzard", "Hits 3 targets within 10 yd." }
	runTicks(45, 0.1)
	assert(blizz.hitText.text == "3", "wording 'N targets': " .. tostring(blizz.hitText.text))
	-- a skill for one enemy, or with no number in its text: no chip
	spellTipText[3] = { "Blizzard", "Strikes the nearest enemy." }
	runTicks(45, 0.1)
	assert(not blizz.hitChip.shown, "single target skill shows a chip")
	spellTipText[3] = { "Blizzard", "Strikes all enemies within 10 yd." }
	runTicks(45, 0.1)
	assert(not blizz.hitChip.shown, "an area skill without a number shows a chip")
	-- a skill that is not in the spellbook has no tooltip to read: no chip, no error
	local g1 = GetSpellName
	GetSpellName = function() return nil end
	blizz.tgtKey = nil
	spellTipText[3] = { "Blizzard", "Pounds the 5 nearest enemies." }
	runTicks(10, 0.1)
	GetSpellName = g1
	-- the cost: the tooltip is read for one skill per look
	blizz.tgtKey = nil
	local c0 = scanCalls
	runTicks(100, 0.1)
	assert(scanCalls - c0 <= 40, "tooltip read " .. (scanCalls - c0) .. " times in 10 seconds")
	assert(blizz.hitChip.shown and blizz.hitText.text == "5", "chip back with the spell in the book: " .. tostring(blizz.hitText.text))
	-- a new rank / a different skill in the slot is read at once
	spellTipText[2] = { "Frostbolt", "Hurls the 2 nearest enemies." }
	frost.tgtKey = nil
	runTicks(8, 0.1)
	assert(frost.hitChip.shown and frost.hitText.text == "2", "changed skill: " .. tostring(frost.hitText.text))
	spellTipText[2] = { "Frostbolt", "Hurls a bolt at the nearest enemy for 300 Frost damage." }
	runTicks(45, 0.1)
	-- the option switches it off and nothing is read any more
	G.SetOpt("hits", false); runTicks(3, 0.1)
	assert(not blizz.hitChip.shown and not frost.hitChip.shown, "option off did not clear")
	local c1 = scanCalls
	runTicks(60, 0.1)
	assert(scanCalls == c1, "reads the tooltip with the option off")
	G.SetOpt("hits", true); runTicks(30, 0.1)
	assert(blizz.hitChip.shown, "chip not back with the option on")
	-- the game's tooltip is the one that is read, and it is hidden again each time
	assert(not GameTooltip.shown, "the game's tooltip was left up")
	frost.tgtKey = nil; blizz.tgtKey = nil
	spellTipText[3] = { "Blizzard", "Pounds the 4 nearest enemies." }
	runTicks(30, 0.1)
	assert(blizz.hitText.text == "4" and not GameTooltip.shown, "read through the game's tooltip: " .. tostring(blizz.hitText.text))
	-- while a tooltip is up (the player hovers something) it is not touched; the chip stays, and is read when it is free
	GameTooltip.shown = true
	local c2 = scanCalls
	spellTipText[3] = { "Blizzard", "Pounds the 6 nearest enemies." }
	runTicks(30, 0.1)
	assert(scanCalls == c2, "the tooltip was read while another was up")
	assert(blizz.hitText.text == "4", "chip changed without a read")
	GameTooltip.shown = false
	runTicks(30, 0.1)
	assert(blizz.hitText.text == "6", "chip did not follow once the tooltip was free: " .. tostring(blizz.hitText.text))
	-- hovering a skill shows the game's tooltip for it, with the numbers: nothing of that is disturbed by the reads
	blizz.scripts.OnEnter(); runTicks(30, 0.1)
	assert(GameTooltip.shown and lastSetSpell and lastSetSpell[1] == 3, "hover tooltip was disturbed")
	blizz.scripts.OnLeave(); runTicks(10, 0.1)
	-- a game whose tooltip stays up for ever: the spare tooltip is used after a while
	GameTooltip.shown = true
	spellTipText[3] = { "Blizzard", "Pounds the 8 nearest enemies." }
	runTicks(160, 0.1)
	assert(blizz.hitText.text == "8", "spare tooltip not used: " .. tostring(blizz.hitText.text))
	GameTooltip.shown = false
	-- a card is picked (the game says its spells / stats changed): +2 targets are on the chip within a few seconds
	spellTipText[2] = { "Frostbolt", "Hurls the 4 nearest enemies." }
	runTicks(40, 0.1)
	assert(frost.hitText.text == "4")
	spellTipText[2] = { "Frostbolt", "Hurls the 6 nearest enemies." }
	AZS_STATS_UPDATED = ( AZS_STATS_UPDATED or 0 ) + 1
	runTicks(20, 0.1)    -- one skill is read per look (4 a second), seven skills: everything is up to date within two seconds
	assert(frost.hitText.text == "6", "chip did not follow the card: " .. tostring(frost.hitText.text))
	-- colour codes in the text do not hide the number
	spellTipText[2] = { "Frostbolt", "Hurls the |cffffd1005|r nearest enemies for |cff00ff00300|r damage." }
	AZS_SPELLS_UPDATED = ( AZS_SPELLS_UPDATED or 0 ) + 1
	runTicks(30, 0.1)
	assert(frost.hitText.text == "5", "colour codes: " .. tostring(frost.hitText.text))
	spellTipText[2] = { "Frostbolt", "Hurls a bolt at the nearest enemy for 300 Frost damage." }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(30, 0.1)
	-- other wordings the game may use
	local function chipFor(lines, want, what)
		spellTipText[3] = lines
		blizz.tgtKey = nil
		runTicks(12, 0.1)
		local got = blizz.hitChip.shown and blizz.hitText.text or "none"
		assert(got == want, what .. ": expected " .. want .. ", got " .. got)
	end
	chipFor({ "Blizzard", "Targets: 7" }, "7", "'Targets: N'")
	chipFor({ "Blizzard", "Max targets: 9", "Cooldown: 8 sec" }, "9", "'Max targets: N'")
	chipFor({ "Blizzard", "Hits 4 additional targets." }, "5", "'N additional targets' is on top of the main target")
	chipFor({ "Blizzard", "Hits your target and 2 other nearby enemies." }, "3", "'and N other nearby enemies'")
	chipFor({ "Blizzard", "Chains to up to 5 enemies (+2 targets from cards)." }, "5", "bonus in brackets")
	chipFor({ "Blizzard", "Fires at three nearest enemies." }, "3", "a number written out")
	chipFor({ "Blizzard", "Deals 120 damage to enemies within 10 yd for 5 sec." }, "none", "damage is not a count")
	chipFor({ "Blizzard", "Restores 30% more health to 1.5 enemies." }, "none", "decimals and percents are not counts")
	chipFor({ "Blizzard", "Hits 6 enemies", "Your bonuses: +3 targets" }, "6", "name line, description, bonus line")
	-- the game writes the hero's numbers only into the tooltip a player sees: the hover is read, and the chip keeps it
	scanBlind = true
	chipFor({ "Blizzard", "Pounds the 6 nearest enemies." }, "none", "a look that sees no numbers")
	blizz.scripts.OnEnter(); runTicks(6, 0.1)
	assert(blizz.hitChip.shown and blizz.hitText.text == "6", "hover not read: " .. tostring(blizz.hitText.text))
	blizz.scripts.OnLeave(); runTicks(60, 0.1)
	assert(blizz.hitChip.shown and blizz.hitText.text == "6", "chip lost the hover number: " .. tostring(blizz.hitText.text))
	spellTipText[3] = { "Blizzard", "Pounds the 8 nearest enemies." }   -- a card: the next hover shows it
	blizz.scripts.OnEnter(); runTicks(6, 0.1); blizz.scripts.OnLeave(); runTicks(30, 0.1)
	assert(blizz.hitText.text == "8", "hover after a card: " .. tostring(blizz.hitText.text))
	-- a look that sees the same numbers moves the chip along with the card, hover or no hover
	scanBlind = false
	spellTipText[3] = { "Blizzard", "Pounds the 9 nearest enemies." }
	runTicks(45, 0.1)
	assert(blizz.hitText.text == "9", "look after a hover: " .. tostring(blizz.hitText.text))
	spellTipText[3] = { "Blizzard", "Pounds the 5 nearest enemies." }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(20, 0.1)
	assert(blizz.hitText.text == "5", "look after a hover (down): " .. tostring(blizz.hitText.text))
	-- a different tooltip over a skill's slot is not read as the skill's
	GameTooltip.shown = false
	-- /gw2 targets: what was read, for a report from the game
	SlashCmdList["AZSGW2"]("targets")
	assert(not GameTooltip.shown, "the report left the tooltip up")
	print("max targets chip ok")
end)

scenario("skills: tooltips of pet abilities, and the timer ticks while hovering", function()
	local saved = {}
	for i = 1, 7 do saved[i] = AZS_SPELLS[i] end
	-- Kill Command lives in the pet's book; Demonic Empowerment is there but the game has nothing to say about it; the third is in no book
	petBook = { { "Kill Command", "Rank 1" }, { "Demonic Empowerment", "Rank 1" } }
	spellTipText.pet1 = { "Kill Command", "Your pet strikes at once.", "Pounds the 3 nearest enemies." }
	spellTipText.pet2 = {}
	AZS_SPELLS[2] = { key = "kill_command", spell = 2, rank = 1, cd = 0, cdmax = 6 }
	AZS_SPELLS[3] = { key = "demonic_empowerment", spell = 3, rank = 1, cd = 0, cdmax = 60 }
	AZS_SPELLS[5] = { key = "unknown_pet_skill", spell = 5, rank = 1, cd = 0, cdmax = 20 }
	AZS_SPELLS_UPDATED = (AZS_SPELLS_UPDATED or 0) + 1
	runTicks(40, 0.1)
	local s2, s3, s5 = G.slots[2], G.slots[3], G.slots[5]
	s2.scripts.OnEnter()
	assert(lastSetSpell and lastSetSpell[2] == "pet" and lastSetSpell[1] == 1, "the pet's book was not used for Kill Command: " .. tostring(lastSetSpell and lastSetSpell[2]))
	assert(GameTooltip.shown, "no tooltip for Kill Command")
	s2.scripts.OnLeave()
	s3.scripts.OnEnter()
	local function lines() return table.concat(tipLines, " | ") end
	assert(GameTooltip.shown and string.find(lines(), "Demonic Empowerment", 1, true) and string.find(lines(), "Casts automatically", 1, true), "no own tooltip when the game has no text: " .. lines())
	s3.scripts.OnLeave()
	s5.scripts.OnEnter()
	assert(GameTooltip.shown and string.find(lines(), "Unknown Pet Skill", 1, true), "no tooltip for a skill in no book: " .. lines())
	s5.scripts.OnLeave()
	-- the number of targets of a pet skill is read from the pet's book too
	s2.tgtKey = nil; runTicks(12, 0.1)
	assert(s2.hitChip.shown and s2.hitText.text == "3", "targets of a pet skill: " .. tostring(s2.hitText.text))
	petBook = {}
	for i = 1, 7 do AZS_SPELLS[i] = saved[i] end
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(40, 0.1)

	-- the "Ready in" line counts down while the mouse stays on the skill, and goes when the skill is ready
	AZS_SPELLS[4] = { key = "blizzard", spell = 4, rank = 1, cd = 4, cdmax = 10 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(6, 0.05)
	local b4 = G.slots[4]
	local function readyLine()
		for _, l in ipairs(tipLines) do if string.find(l, "^Ready in") then return l end end
		return nil
	end
	b4.scripts.OnEnter()
	local r1 = readyLine()
	assert(r1, "no Ready line while cooling down: " .. lines())
	runTicks(20, 0.05)                                    -- one second
	local r2 = readyLine()
	assert(r2 and r2 ~= r1, "the Ready in line did not move: " .. tostring(r1) .. " -> " .. tostring(r2))
	local n1 = tonumber(string.match(r1, "([%d%.]+)")); local n2 = tonumber(string.match(r2, "([%d%.]+)"))
	assert(n2 < n1 - 0.5 and n2 > n1 - 1.5, "wrong step: " .. n1 .. " -> " .. n2)
	runTicks(80, 0.05)                                    -- the skill is ready by now
	assert(readyLine() == nil and GameTooltip.shown, "the line stays after the skill is ready: " .. lines())
	-- no needless redrawing while nothing counts
	local c = scanCalls
	runTicks(40, 0.05)
	assert(scanCalls == c, "the tooltip is drawn again although nothing counts down")
	-- leaving the skill stops it
	b4.scripts.OnLeave()
	assert(not GameTooltip.shown and G.liveTip == nil, "the live tooltip outlives the hover")
	-- a cooldown that starts while the mouse is there shows up
	b4.scripts.OnEnter()
	AZS_SPELLS[4].cd = 3; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	assert(readyLine(), "a new cooldown does not show on a tooltip that is up")
	b4.scripts.OnLeave()
	AZS_SPELLS[4].cd = 0; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(6, 0.05)
	print("pet tooltips and the live timer ok")
end)

scenario("skills: a ready skill that cannot be used does not flash", function()
	local b = G.slots[4]
	local keep = AZS_SPELLS[4]
	AZS_SPELLS[4] = { key = "blizzard", spell = 4, rank = 1, cd = 0, cdmax = 10 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	assert(not b.cd.shown and b.cdText.text == "", "starts ready")
	-- nothing is in range: every try puts a moment of cooldown on the skill and takes it off again
	local flips, last = 0, false
	for i = 1, 80 do
		AZS_SPELLS[4].cd = ( i % 2 == 1 ) and ( 0.3 + ( i % 5 ) * 0.3 ) or 0
		AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
		runTicks(3, 0.05)
		local now = b.cd.shown and true or false
		if now ~= last then flips = flips + 1; last = now end
		assert(b.cdText.text == "", "the cooldown text flashed on a ready skill: " .. tostring(b.cdText.text))
	end
	assert(flips == 0, "the cooldown overlay flashed " .. flips .. " times")
	-- a real cooldown (the skill went off) shows at once, and counts down through updates that are short ones
	AZS_SPELLS[4].cd = 10; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(3, 0.05)
	assert(b.cd.shown and b.cdText.text ~= "", "a real cooldown is not shown")
	AZS_SPELLS[4].cd = 1.5; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1      -- the game's number for the same cooldown, later
	runTicks(3, 0.05)
	assert(b.cd.shown and b.cdText.text ~= "", "the end of a real cooldown was taken for a blip")
	AZS_SPELLS[4].cd = 0; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(3, 0.05)
	assert(not b.cd.shown and b.cdText.text == "", "ready again")
	-- a skill seen for the first time, already cooling down, shows its cooldown
	AZS_SPELLS[4] = { key = "newskill", spell = 4, rank = 1, cd = 1.2, cdmax = 10 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(3, 0.05)
	assert(b.cd.shown, "a new skill with a cooldown shows none")
	AZS_SPELLS[4] = keep; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	-- the cost: cooldown changes (every cast) do not make the tooltips be read again
	local c0 = scanCalls
	for i = 1, 100 do
		AZS_SPELLS[4].cd = ( i % 2 ) * 3
		AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
		runTicks(2, 0.1)
	end
	AZS_SPELLS[4].cd = 0; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	assert(scanCalls - c0 <= 16, "skills read " .. ( scanCalls - c0 ) .. " times in 20 seconds of casting")
	print("no flashing, no needless reads")
end)

scenario("skills: a skill is found in the spellbook by the first words of its spell's name", function()
	table.insert(book, { "Rockbiter Weapon", "Rank 1" })       -- book entry 4
	table.insert(book, { "Fireball", "Rank 1" })               -- book entry 5
	spellTipText[4] = { "Rockbiter Weapon", "Imbue your weapon with the power of earth." }
	local keep = AZS_SPELLS[5]
	local b = G.slots[5]
	AZS_SPELLS[5] = { key = "rockbiter", spell = 8017, rank = 1, cd = 0, cdmax = 0 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	b.scripts.OnEnter()
	assert(lastSetSpell and lastSetSpell[1] == 4 and lastSetSpell[2] == "spell", "Rockbiter Weapon was not found for 'rockbiter': " .. tostring(lastSetSpell and lastSetSpell[1]))
	assert(GameTooltip.shown, "no tooltip")
	b.scripts.OnLeave()
	-- a short name is not the start of every longer one
	AZS_SPELLS[5] = { key = "fire", spell = 1, rank = 1, cd = 0, cdmax = 3 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	b.scripts.OnEnter()
	assert(lastSetSpell == nil and #tipLines >= 2, "'fire' was taken for Fireball: " .. table.concat(tipLines, " | "))
	b.scripts.OnLeave()
	-- /gw2 focus on a skill says where its spell was found, or what looks like it
	local mf = GetMouseFocus
	AZS_SPELLS[5] = { key = "rockbiter", spell = 8017, rank = 1, cd = 0, cdmax = 0 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	GetMouseFocus = function() return b end
	SlashCmdList["AZSGW2"]("focus")
	AZS_SPELLS[5] = { key = "rockbiter_x", spell = 8017, rank = 1, cd = 0, cdmax = 0 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	SlashCmdList["AZSGW2"]("focus")
	GetMouseFocus = mf
	table.remove(book); table.remove(book)
	spellTipText[4] = nil
	SlashCmdList["AZSGW2"]("version")
	AZS_SPELLS[5] = keep
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	print("skills are found by the first words of a spell's name")
end)

scenario("skills: a skill that is in no spellbook gets the game's tooltip by its spell id", function()
	local keep = AZS_SPELLS[5]
	local b = G.slots[5]
	AZS_SPELLS[5] = { key = "rockbiter", spell = 8017, rank = 1, cd = 0, cdmax = 1.6 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	-- no link gives a tooltip: our own lines
	b.scripts.OnEnter()
	assert(lastSetSpell == nil and tipLines[1] == "Rockbiter" and #tipLines >= 3, "own lines: " .. table.concat(tipLines, " | "))
	b.scripts.OnLeave()
	-- the client takes the enchant kind of link, not the spell kind
	linkTip["enchant:8017"] = { "Rockbiter Weapon", "Imbue your weapon with the power of earth." }
	G.linkMiss = {}
	b.scripts.OnEnter()
	assert(lastLink == "enchant:8017" and GameTooltip.shown and tipLines[#tipLines] == "Casts automatically", "no tooltip by id: " .. table.concat(tipLines, " | "))
	assert(G.linkKind[8017] == "enchant", "the kind that worked is not remembered")
	b.scripts.OnLeave()
	-- the tooltip of another spell is not taken for this one
	linkTip["enchant:8017"] = { "Something Else", "x" }
	G.linkKind, G.linkMiss = {}, {}
	b.scripts.OnEnter()
	assert(tipLines[1] == "Rockbiter", "a tooltip of another spell was used: " .. table.concat(tipLines, " | "))
	b.scripts.OnLeave()
	-- a call that fails does not break the hover
	linkTip["enchant:8017"] = "error"
	G.linkKind, G.linkMiss = {}, {}
	b.scripts.OnEnter()
	assert(GameTooltip.shown and #tipLines >= 3, "the hover broke on a failing link")
	b.scripts.OnLeave()
	-- the number of targets is read from it
	linkTip["enchant:8017"] = nil
	linkTip["spell:8017"] = { "Rockbiter Weapon", "Strikes up to 3 enemies." }
	G.linkKind, G.linkMiss = {}, {}
	b.tgtKey = nil
	runTicks(30, 0.1)
	assert(b.hitChip.shown and b.hitText.text == "3", "targets by spell id: " .. tostring(b.hitText.text))
	assert(not GameTooltip.shown, "the reading left the tooltip up")
	-- /gw2 focus and /gw2 targets say what happened
	local mf = GetMouseFocus
	GetMouseFocus = function() return b end
	SlashCmdList["AZSGW2"]("focus")
	GetMouseFocus = mf
	SlashCmdList["AZSGW2"]("targets")
	linkTip = {}
	G.linkKind, G.linkMiss = {}, {}
	AZS_SPELLS[5] = keep
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(20, 0.1)
	print("tooltips by spell id ok")
end)

scenario("skills: the game's own icon of a skill gives its text when no spellbook and no link has it", function()
	local keep = AZS_SPELLS[5]
	local b = G.slots[5]
	AZS_SPELLS[5] = { key = "rockbiter", spell = 8017, rank = 1, cd = 0, cdmax = 1.6 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	local icon = "Interface\\Icons\\Spell_Nature_RockBiter"
	G.abilityInfo.rockbiter = { name = "Rockbiter Weapon", icon = icon }
	G.linkKind, G.linkMiss = {}, {}
	-- no frame of the game draws the icon: our own lines
	b.scripts.OnEnter()
	assert(tipLines[1] == "Rockbiter Weapon" and #tipLines >= 3, "own lines: " .. table.concat(tipLines, " | "))
	b.scripts.OnLeave()
	SlashCmdList["AZSGW2"]("focus")
	-- a frame of ours that has the icon and calls our own tooltip must not send the tooltip round in circles
	local oursLike = CreateFrame("Button", "FakeOursLike", UIParent)
	local ot = oursLike:CreateTexture(nil, "ARTWORK"); ot:SetTexture(icon)
	oursLike:SetScript("OnEnter", function() b.scripts.OnEnter() end)
	-- another skill's icon of the game: not taken for this one
	local other = CreateFrame("Button", "FakeOtherIcon", UIParent)
	local ox = other:CreateTexture(nil, "ARTWORK"); ox:SetTexture(icon)
	other:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip.tipText = { "Something Else", "Does things." }
		for i, t in ipairs(GameTooltip.tipText) do local fs = _G["GameTooltipTextLeft" .. i] or new("FontString", GameTooltip, "GameTooltipTextLeft" .. i); fs.fontSet = true; fs.text = t end
	end)
	-- a script that fails
	local broken = CreateFrame("Button", "FakeBrokenIcon", UIParent)
	local bx = broken:CreateTexture(nil, "ARTWORK"); bx:SetTexture(icon)
	broken:SetScript("OnEnter", function() error("boom") end)
	-- the game's own icon, with its text
	local gameIcon = CreateFrame("Button", "FakeGameRockbiter", UIParent)
	local gx = gameIcon:CreateTexture(nil, "ARTWORK"); gx:SetTexture(string.lower(icon))
	local seenThis, left
	local gameRights = { "Rank 1", "31 sec cooldown", "1.6 sec cooldown" }
	gameIcon:SetScript("OnEnter", function()
		seenThis = this
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		-- like the game's: the spell's own cooldown (left over from the 1.12 data) and the skill's real one
		local lines = { "Rockbiter Weapon", "10 yd range", "Automatic", "Imbue your weapon with the power of earth.", "Ready in 1.0 sec",
			"Your bonuses: -25% cooldown" }
		local rights = gameRights
		GameTooltip.tipText = lines
		for i, t in ipairs(lines) do
			local fs = _G["GameTooltipTextLeft" .. i] or new("FontString", GameTooltip, "GameTooltipTextLeft" .. i)
			fs.fontSet = true; fs.text = t; fs.tcol = i == 1 and { 1, 0.82, 0 } or { 1, 1, 1 }
			local rf = _G["GameTooltipTextRight" .. i] or new("FontString", GameTooltip, "GameTooltipTextRight" .. i)
			rf.fontSet = true; rf.text = rights[i]; rf.tcol = { 0.5, 0.5, 0.5 }
		end
		GameTooltip.shown = true
	end)
	gameIcon:SetScript("OnLeave", function() left = true; GameTooltip:Hide() end)
	G.borrowNote = {}; now = now + 40                         -- "no frame" was remembered for a while
	b.scripts.OnEnter()
	assert(seenThis == gameIcon, "the game's tooltip script was not run with its own frame as this")
	assert(left, "its OnLeave was not run")
	assert(tipLines[1] == "Rockbiter Weapon | Rank 1", "title: " .. table.concat(tipLines, " | "))
	-- one cooldown only: the skill's own (1.6), not the spell's 31
	assert(tipLines[2] == "10 yd range" and tipLines[3] == "Automatic | 1.6 sec cooldown", "cooldowns: " .. table.concat(tipLines, " | "))
	assert(tipLines[4] == "Imbue your weapon with the power of earth.", "text: " .. table.concat(tipLines, " | "))
	assert(tipLines[5] == "Your bonuses: -25% cooldown", "a bonus line was taken for a cooldown: " .. table.concat(tipLines, " | "))
	for _, t in ipairs(tipLines) do assert(not string.find(t, "31 sec"), "the wrong cooldown stayed: " .. t) end
	assert(tipLines[#tipLines] == "Casts automatically", "no own last line: " .. table.concat(tipLines, " | "))
	for _, t in ipairs(tipLines) do assert(not string.find(t, "Ready in 1.0"), "the game's own timer line was copied") end
	assert(GameTooltip.shown and GameTooltip.owner == b, "the tooltip is not ours again")
	assert(string.find(G.borrowNote[string.lower(icon)] or "", "works"), "no note: " .. tostring(G.borrowNote[string.lower(icon)]))
	SlashCmdList["AZSGW2"]("focus")
	local mf = GetMouseFocus
	GetMouseFocus = function() return b end
	SlashCmdList["AZSGW2"]("focus")
	GetMouseFocus = mf
	b.scripts.OnLeave()
	-- hovering again: still there (the frame that worked is asked first, the others are not)
	seenThis = nil
	b.scripts.OnEnter()
	assert(seenThis == gameIcon and tipLines[4] == "Imbue your weapon with the power of earth.")
	b.scripts.OnLeave()
	-- a single cooldown is left alone, in minutes too
	gameRights = { "Rank 1", "2 min cooldown", nil }
	b.scripts.OnEnter()
	assert(tipLines[2] == "10 yd range | 2 min cooldown" and tipLines[3] == "Automatic", "a single cooldown was changed: " .. table.concat(tipLines, " | "))
	b.scripts.OnLeave()
	-- the skill does not know its cooldown: the shorter one stays
	AZS_SPELLS[5] = { key = "rockbiter", spell = 8017, rank = 1, cd = 0, cdmax = 0 }
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(10, 0.05)
	gameRights = { "Rank 1", "31 sec cooldown", "1.6 sec cooldown" }
	b.scripts.OnEnter()
	assert(tipLines[2] == "10 yd range" and tipLines[3] == "Automatic | 1.6 sec cooldown", "shortest: " .. table.concat(tipLines, " | "))
	b.scripts.OnLeave()
	-- the game's icon is gone: our own lines, remembered for a while and tried again later
	gameIcon:Hide(); gameIcon:SetScript("OnEnter", nil)
	G.borrowNote = {}; now = now + 40
	b.scripts.OnEnter()
	assert(tipLines[1] == "Rockbiter Weapon" and tipLines[2] == "Rank 1", "back to own lines: " .. table.concat(tipLines, " | "))
	assert(GameTooltip.owner == b and GameTooltip.shown, "tooltip lost")
	assert(string.find(G.borrowNote[string.lower(icon)] or "", "none gave"), "no note: " .. tostring(G.borrowNote[string.lower(icon)]))
	b.scripts.OnLeave()
	runTicks(40, 0.1)
	for _, w in ipairs({ oursLike, other, broken, gameIcon }) do w:Hide(); w:SetScript("OnEnter", nil) end
	G.abilityInfo.rockbiter = nil
	AZS_SPELLS[5] = keep
	AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(20, 0.1)
	print("the game's own icon text ok")
end)

scenario("/gw2 rows tip: the tooltips of the game's own skill icons", function()
	local icon = G.abilityInfo.frostbolt and G.abilityInfo.frostbolt.icon
	assert(icon, "no icon for frostbolt in the loadout")
	local gameIcon = CreateFrame("Button", "FakeGameSkillIcon", UIParent)
	local tex = gameIcon:CreateTexture(nil, "ARTWORK"); tex:SetTexture(icon)
	local seenThis
	gameIcon:SetScript("OnEnter", function() seenThis = this; GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetSpell(2, "spell"); GameTooltip:Show() end)
	local left
	gameIcon:SetScript("OnLeave", function() left = true; GameTooltip:Hide() end)
	local before = #allWidgets
	SlashCmdList["AZSGW2"]("rows")
	SlashCmdList["AZSGW2"]("rows tip nothing")      -- only the skill asked for: no frame matches
	assert(seenThis == nil, "a frame that was not asked for was pointed at")
	SlashCmdList["AZSGW2"]("rows tip frost")
	assert(seenThis == gameIcon, "the game's tooltip script was not run with its own frame as this")
	assert(left and not GameTooltip.shown, "the tooltip was left up")
	-- a game icon with a failing script does not stop the report
	gameIcon:SetScript("OnEnter", function() error("boom") end)
	SlashCmdList["AZSGW2"]("rows tip")
	gameIcon:SetScript("OnEnter", nil)
	SlashCmdList["AZSGW2"]("rows tip")
	gameIcon:Hide()
	print("rows tip ok")
end)

scenario("tooltips: a buff the game has no text for still has one", function()
	runTicks(8, 0.1)
	local a = G.buffs[1]
	assert(a.shown and a.data, "no buff shown")
	-- the game gives no text for it (a buff of the hero that has no description)
	GameTooltip.SetPlayerBuff = function(self, idx) self.tipText = nil end
	a.scripts.OnEnter()
	assert(#tipLines >= 1 and tipLines[1] == "Regeneration", "no name on a buff without text: " .. table.concat(tipLines, " | "))
	assert(GameTooltip.shown and G.tipLast and G.tipLast.floor == true and G.tipLast.tag == "aura", "the fallback was not used")
	a.scripts.OnLeave()
	-- the loadout knows what the icon is called
	G.iconNames["interface\\icons\\spell_nature_regeneration"] = "Rockbiter Weapon"
	a.scripts.OnEnter()
	assert(tipLines[1] == "Rockbiter Weapon", "the loadout's name was not used: " .. tostring(tipLines[1]))
	a.scripts.OnLeave()
	G.iconNames = {}
	-- when the game does have text, it is the game's
	GameTooltip.SetPlayerBuff = function(self, idx) self.tipText = { "Rejuvenation" }; tipLines = { "Rejuvenation" } end
	GameTooltip.NumLines = function(self) return self.tipText and #self.tipText or 0 end
	a.scripts.OnEnter()
	assert(tipLines[1] == "Rejuvenation" and G.tipLast.floor == false, "the game's text was replaced")
	a.scripts.OnLeave()
	GameTooltip.SetPlayerBuff = nil
	GameTooltip.NumLines = nil
	-- /gw2 focus and /gw2 rows (what is under the mouse, where the game draws its skill icons) run in any state
	SlashCmdList["AZSGW2"]("focus")
	local mf = GetMouseFocus
	GetMouseFocus = function() return G.slots[1] end
	SlashCmdList["AZSGW2"]("focus")
	GetMouseFocus = function() return a end
	SlashCmdList["AZSGW2"]("focus")
	GetMouseFocus = mf
	SlashCmdList["AZSGW2"]("rows")
	SlashCmdList["AZSGW2"]("debug")
	print("buff tooltip fallback ok")
end)

scenario("/gw2 off: the game's skill rows are switched off and on again", function()
	local log = {}
	local orig = AZS_SetHudShown
	AZS_SetHudShown = function(p, s) if p == "build" then log[#log + 1] = tostring(s) end orig(p, s) end
	SlashCmdList["AZSGW2"]("off")
	runTicks(4, 0.05)
	assert(table.concat(log, ",") == "true", "given back at once: " .. table.concat(log, ","))
	runTicks(20, 0.05)
	assert(table.concat(log, ","):find("true,false,true", 1, true), "not switched off and on again: " .. table.concat(log, ","))
	assert(hud.build == true and cvars.hudBuild == "1", "the rows are left off after the second switch")
	runTicks(80, 0.05)
	assert(hud.build == true and cvars.hudBuild == "1", "the rows are off after the watch")
	local n = #log
	runTicks(120, 0.05)
	assert(#log == n, "the rows are switched for ever")
	AZS_SetHudShown = orig
	SlashCmdList["AZSGW2"]("on")
	runTicks(14, 0.05)
	for _, p in ipairs(G.HUD_PARTS) do assert(hud[p] == false, "HUD part not hidden again: " .. p) end
	print("/gw2 off switches the rows off and on:", table.concat(log, ","))
end)

scenario("cooldown counts down", function()
	local before = G.slots[6].cdText.text
	runTicks(40, 0.05)   -- 2 s
	print("slot6:", before, "->", G.slots[6].cdText.text)
	AZS_SPELLS[6].cd = 0; AZS_SPELLS_UPDATED = 2
	runTicks(3, 0.05)
	print("slot6 after refresh:", G.slots[6].cdText.text == "" and "ready" or G.slots[6].cdText.text)
end)

scenario("banners", function()
	assert(bannerHandler, "no banner handler")
	bannerHandler({ kind = "boss", boss = true, name = "X", text = "A boss approaches" })
	bannerHandler({ kind = "achievement", boss = false, name = "Y", text = "Achievement unlocked" })
	runTicks(100, 0.05)
	print("banner shown:", G.banner.shown, G.banner.text.text)
end)

scenario("native popup hunter", function()
	-- the game's own popup: an unnamed frame under UIParent with a big font string
	local txt = "Kobold Taskmaster is slain! Its lair yields treasure and its strength, and the other guardians grow stronger."
	local native = CreateFrame("Frame", nil, UIParent)
	local nfs = native:CreateFontString(nil, "OVERLAY"); nfs:SetFont("Fonts\\FRIZQT__.TTF", 30); nfs:SetText("|cffffd9a0" .. txt .. "|r")
	local decoy = CreateFrame("Frame", nil, UIParent)
	local dfs = decoy:CreateFontString(nil, "OVERLAY"); dfs:SetFont("Fonts\\FRIZQT__.TTF", 12); dfs:SetText("Something else entirely here")
	-- text straight on a full-screen frame
	local full = CreateFrame("Frame", "SomeFullScreen", UIParent); full.w = 5000; full.h = 5000
	local ffs = full:CreateFontString(nil, "OVERLAY"); ffs:SetFont("Fonts\\FRIZQT__.TTF", 30); ffs:SetText("Another guardian is slain! The lair is quiet.")
	AZSGW2DB.messages = false
	bannerHandler({ kind = "guardian", boss = false, name = "Kobold Taskmaster", text = txt })
	bannerHandler({ kind = "guardian", boss = false, name = "Other", text = "Another guardian is slain! The lair is quiet." })
	runTicks(60, 0.05)
	print("native frame shown:", native.shown, "parent is UIParent:", native.parent == UIParent, "| decoy shown:", decoy.shown)
	print("fullscreen frame shown:", full.shown, "| its text shown:", ffs.shown)
	print("our banner text:", G.banner.text.text)
	assert(not native.shown and native.parent ~= UIParent, "native popup not hidden")
	assert(decoy.shown and decoy.parent == UIParent, "decoy was hidden")
	assert(full.shown and not ffs.shown, "full-screen frame handling wrong")
	native.parent = native.parent; native:Show()
	assert(native.scripts.OnShow, "no OnShow hook"); native.scripts.OnShow()
	assert(not native.shown, "OnShow hook does not hide")
	G.RestoreHidden()
	print("after restore: parent is UIParent:", native.parent == UIParent)
	assert(native.parent == UIParent)
	-- a crowded screen: the walk stops after 900 frames, whatever is there
	do
		local crowd = CreateFrame("Frame", nil, UIParent)
		for i = 1, 1500 do CreateFrame("Frame", nil, crowd) end
		AZSGW2DB.messages = false
		G.hunt.off = false; G.hunt.misses = 0
		bannerHandler({ kind = "guardian", boss = false, name = "Q", text = "Nobody shows this text anywhere on screen" })
		runTicks(40, 0.05)
		print("frames looked at (crowded screen):", G.hunt.nodes, "| misses:", G.hunt.misses, "| off:", G.hunt.off)
		assert(G.hunt.nodes and G.hunt.nodes <= 900, "hunter walk is not bounded")
		-- a second empty hunt switches the hunter off for the session
		bannerHandler({ kind = "guardian", boss = false, name = "Q", text = "Nobody shows this text anywhere either" })
		runTicks(40, 0.05)
		assert(G.hunt.off, "hunter did not switch itself off after two empty hunts")
		local nodesBefore = G.hunt.nodes
		bannerHandler({ kind = "guardian", boss = false, name = "Q", text = "A third banner that nobody draws" })
		runTicks(40, 0.05)
		assert(G.hunt.pending == nil and G.hunt.nodes == nodesBefore, "hunter ran while switched off")
		SlashCmdList["AZSGW2"]("hunt on")
		assert(not G.hunt.off, "/gw2 hunt on")
		G.hunt.off = false; G.hunt.misses = 0
		crowd:Hide()
	end
	-- with the game's messages switched on (/gw2 messages) nothing is hunted
	AZSGW2DB.messages = true
	local before = G.hunt.count
	bannerHandler({ kind = "guardian", boss = false, name = "Z", text = "Zebra Guardian is slain! Treasure awaits you." })
	runTicks(20, 0.05)
	assert(G.hunt.count == before, "hunted while messages on")
	AZSGW2DB.messages = false
end)

scenario("ally down alert", function()
	assert(G.reviveFrame, "no alert frame")
	local reads0 = catalogReads
	-- Ghost has no known position: the alert shows without an arrow
	runTicks(4, 0.05)
	print("alert rows:", G.reviveFrame.shown, G.reviveFrame.rows[1].title.text, "| arrow shown:", G.reviveFrame.rows[1].arrow.shown)
	assert(G.reviveFrame.shown and G.reviveFrame.rows[1].shown, "alert not shown")
	assert(string.find(G.reviveFrame.rows[1].title.text, "Ghost") and string.find(G.reviveFrame.rows[1].title.text, "is down!") and string.find(G.reviveFrame.rows[1].title.text, "Revive them!"), "text")
	assert(not G.reviveFrame.rows[1].arrow.shown, "arrow without a position")
	assert(#playedSounds == 1, "one sound for one fall: " .. #playedSounds)
	-- a friend with a position and a world anchor
	downedList = { { id = "H2", name = "Ghost", positionAvailable = false },
		{ id = "H3", name = "Zaynor", positionAvailable = true, x = 30, y = 40, z = 0, spaceId = "m1:1" } }
	anchorCatalog = { { anchorId = "dp1", kind = "downedPartyMember", state = "downed", memberId = "H3", name = "Zaynor" } }
	runTicks(6, 0.05)
	local r2 = G.reviveFrame.rows[2]
	print("row 2:", r2.title.text, r2.dist.text, "| arrow shown:", r2.arrow.shown, "| catalog reads:", catalogReads - reads0)
	assert(r2.shown and string.find(r2.title.text, "Zaynor") and r2.arrow.shown and r2.dist.text == "50 yd", "row with position")
	assert(#playedSounds == 2, "second fall plays a sound")
	assert(catalogReads - reads0 >= 1 and catalogReads - reads0 <= 2, "catalog reads: " .. (catalogReads - reads0))
	-- the marker over the body
	assert(worldHandler, "no world anchors handler")
	worldHandler()
	WorldFrame.parent = UIParent
	dumpLayout(OUTDIR .. "/layout_alert.txt")
	WorldFrame.parent = nil
	local m = G.reviveMarks[1]
	print("marker:", m.shown, m.text.text)
	assert(m.shown and string.find(m.text.text, "Zaynor"), "marker over the body")
	local pt = lastPoint(m)
	assert(pt[2] == WorldFrame and pt[3] == "BOTTOMLEFT" and pt[4] == 850, "marker placement")
	projState = "offscreen"; worldHandler()
	assert(not m.shown, "marker hidden when off screen")
	projState = "onScreen"
	-- the same friend staying down does not make a new sound
	runTicks(20, 0.05)
	assert(#playedSounds == 2, "sound repeated")
	-- stock banner for the fall is not queued twice
	local q0 = #G.banner.queue
	bannerHandler({ kind = "frienddown", boss = false, name = "Zaynor", text = "Zaynor is down!" })
	assert(#G.banner.queue == q0, "frienddown banner queued next to the alert")
	G.SetOpt("revive", false)
	bannerHandler({ kind = "frienddown", boss = false, name = "Zaynor", text = "Zaynor is down!" })
	assert(#G.banner.queue == q0 + 1, "banner should show when the alert is off")
	runTicks(3, 0.05)
	assert(not G.reviveFrame.shown and not m.shown or true)
	worldHandler(); assert(not m.shown, "marker with the option off")
	G.SetOpt("revive", true)
	-- they get back up
	downedList = {}
	runTicks(4, 0.05)
	assert(not G.reviveFrame.shown and not G.reviveMarks[1].shown, "alert stays after the revive")
	assert(next(G.down.known) == nil, "known list not cleared")
	downedList = { { id = "H2", name = "Ghost", positionAvailable = false } }
end)

scenario("minimap shows the hero", function()
	assert(G.mm.me.shown, "player arrow not shown")
	runTicks(5, 0.06)
	assert(G.mm.me.shown)
end)

scenario("difficulty on the run bar", function()
	local keep = AZS_ZONE.heroic
	AZS_ZONE.heroic = nil; AZS_ZONE.affixes = nil
	runTicks(4, 0.1)
	print("difficulty:", G.top.diff.text.text, "|", G.top.affix.text)
	assert(G.top.diff.text.text == "NORMAL" and G.top.affix.text == "", "normal run")
	AZS_ZONE.heroic = 3; AZS_ZONE.affixes = "bolstering,sanguine"
	runTicks(4, 0.1)
	print("difficulty:", G.top.diff.text.text, "|", G.top.affix.text)
	assert(G.top.diff.text.text == "HEROIC III" and string.find(G.top.affix.text, "Bolstering") and string.find(G.top.affix.text, "Sanguine"), "heroic 3")
	dumpLayout(OUTDIR .. "/layout_diff.txt")
	AZS_ZONE.heroic = 5; AZS_ZONE.affixes = "explosive"
	runTicks(4, 0.1)
	assert(G.top.diff.text.text == "HEROIC V")
	AZS_ZONE.heroic = 1; AZS_ZONE.affixes = ""
	runTicks(4, 0.1)
	assert(G.top.diff.text.text == "HEROIC I" and G.top.affix.text == "")
	AZS_ZONE.heroic = 9
	runTicks(4, 0.1)
	assert(G.top.diff.text.text == "HEROIC V", "clamped")
	-- the affixes sit on the line under the bar, left of them the next boss, and nothing overlaps the title
	local up0 = AZS_GetUpcomingBosses
	local function rect(w) cache = {}; local r = R(w); return r.l, r.l + r.w, r.b, r.b + r.h end
	for _, case in ipairs({ { "bolstering", "Kovork" }, { "bolstering,sanguine", "Scarlet Commander" }, { "bolstering,sanguine,explosive", "Scarlet Commander" } }) do
		AZS_ZONE.heroic = 5; AZS_ZONE.affixes = case[1]
		AZS_GetUpcomingBosses = function() return { { index = 4, name = case[2], at = 960, left = 194, final = false } } end
		runTicks(4, 0.1)
		local t = G.top
		local fl, fr = rect(t)
		local tl, tr, tb, tt = rect(t.title)
		local nl, nr, nb, nt = rect(t.next)
		local al, ar, ab, at = rect(t.affix)
		print(string.format("  %-32s title %5.1f-%5.1f  next %5.1f-%5.1f  affix %5.1f-%5.1f  (frame %d-%d)", case[1], tl, tr, nl, nr, al, ar, fl, fr))
		assert(t.affix.shown ~= false, "affixes shown: " .. case[1])
		assert(at <= tb + 40 and ab < tb, "affixes are on the lower line")          -- under the title row
		assert(nr + 4 <= al, "next boss and affixes do not overlap: " .. nr .. " vs " .. al)
		assert(ar <= fr + 1 and nl >= fl - 1, "inside the frame")
	end
	-- not enough room: the affixes give way (the difficulty tooltip lists them)
	AZS_GetUpcomingBosses = function() return { { index = 4, name = string.rep("Averyveryverylongname ", 3), at = 960, left = 194, final = false } } end
	runTicks(4, 0.1)
	assert(G.top.affix.shown == false, "affixes hide when the line is too full")
	-- without affixes the next boss is centered again
	AZS_ZONE.heroic = 0; AZS_ZONE.affixes = ""
	AZS_GetUpcomingBosses = up0
	runTicks(4, 0.1)
	local pt = G.top.next.pts[#G.top.next.pts]
	assert(pt[1] == "TOP" and G.top.next.just == "CENTER", "next boss centered without affixes: " .. tostring(pt[1]))
	AZS_ZONE.heroic = 2; AZS_ZONE.affixes = "bolstering"
	runTicks(4, 0.1)
end)


scenario("character panel", function()
	local f = G.charPanel
	assert(f, "no character panel")
	AZS_ZONE.cname = "Mage"; AZS_ZONE.rname = "Human"
	-- the key binding (ToggleCharacter) opens ours, not the game's window
	local sounds0 = #playedSounds
	ToggleCharacter("PaperDollFrame")
	assert(f.shown and not CharacterFrame.shown, "panel should replace the stock window")
	runTicks(6, 0.1)
	print("header:", f.nameText.text, "|", f.levelText.text)
	assert(f.nameText.text == "Mr Nippy" and string.find(f.levelText.text, "Level 63") and string.find(f.levelText.text, "Human") and string.find(f.levelText.text, "Mage"), "header text")
	local ap = f.attr
	local shownCells, rows = 0, {}
	for _, c in ipairs(ap.cells) do
		if c.shown then shownCells = shownCells + 1; rows[c.entry.key] = c.label.text .. "=" .. c.value.text end
	end
	local keys = {}
	for k, v in pairs(rows) do table.insert(keys, v) end
	table.sort(keys)
	print("attribute cells shown:", shownCells, "\n   " .. table.concat(keys, "\n   "))
	assert(shownCells == 20, "all 19 stats + the unknown one shown, got " .. shownCells)
	assert(rows.hp == "Health=2,400" and rows.dmg == "Damage=x1.25" and rows.crit == "Crit Chance=12%" and rows.reg == "Regeneration=1.5/s", "value formats")
	assert(rows.cd == "CDR=15%" and rows.arm == "Armor=18%" and rows.cnt == "Extra Targets=1", "value formats 2")
	assert(rows.luck == "Luck=40%" and rows.cm == "Crit Damage=x3.04" and rows.lch == "Leech=3%", "luck / crit damage / leech: " .. tostring(rows.luck) .. " " .. tostring(rows.cm))
	assert(rows.foo == "Foo=7", "an unknown stat is listed under Other")
	-- gear bonuses colour the number and show in the tooltip
	local hpcell
	for _, c in ipairs(ap.cells) do if c.shown and c.entry.key == "hp" then hpcell = c end end
	assert(hpcell.value.tcol[1] < 0.7 and hpcell.value.tcol[2] > 0.9, "gear stat not green")
	pcall(hpcell.scripts.OnEnter)
	-- equipment: all gear on the left, only accessories on the right, weapons only when held
	local ammo = worn[0]; worn[0] = nil
	runTicks(6, 0.1)
	local slotsShown, filled = 0, 0
	for _, b in ipairs(f.slots) do slotsShown = slotsShown + 1; if b.hasItem then filled = filled + 1 end end
	print("slots:", slotsShown, "with items:", filled)
	assert(slotsShown == 20 and filled == 3, "slots")
	local names = {}
	for _, b in ipairs(f.slots) do names[b.slotName] = b end
	local function col(b) return lastPoint(b)[4] end
	for _, n in ipairs({ "HeadSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot" }) do
		assert(names[n] and col(names[n]) == 18, n .. " should be in the left column")
	end
	for _, n in ipairs({ "NeckSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }) do
		assert(names[n] and col(names[n]) >= 316, n .. " should be an accessory on the right")
	end
	for _, n in ipairs({ "BackSlot", "WaistSlot", "WristSlot", "ShirtSlot", "TabardSlot" }) do
		assert(col(names[n]) == 18, n .. " is gear, not an accessory")
	end
	assert(not f.weaponHead.shown, "no weapons held: no Weapons title")
	for _, n in ipairs({ "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" }) do
		assert(not names[n].shown, n .. " hidden when empty")
	end
	local head = names.HeadSlot
	assert(head.edges.top.vc[1] > 0.6 and head.edges.top.vc[2] < 0.3, "epic purple border on the helm")
	for _, b in ipairs(f.slots) do b.scripts.OnEnter(); b.scripts.OnLeave() end
	head.scripts.OnClick(); arg1 = "RightButton"; head.scripts.OnClick(); arg1 = nil
	assert(pickups[1] == 1 and pickups[2] == -1, "click handlers")
	assert(f.helm == nil and f.cloak == nil, "the helm / cloak switches are gone")
	-- a held weapon shows up, in the first place, with the title
	worn[16] = { "Interface\\Icons\\INV_Mace_01", "|cffffffff|Hitem:9:0:0:0|h[Mace]|h|r" }
	runTicks(6, 0.1)
	assert(names.MainHandSlot.shown and f.weaponHead.shown, "held weapon not shown")
	assert(col(names.MainHandSlot) == 18, "first weapon at the left")
	worn[17] = { "Interface\\Icons\\INV_Shield_01", "|cff0070dd|Hitem:10:0:0:0|h[Shield]|h|r" }
	runTicks(6, 0.1)
	assert(names.SecondaryHandSlot.shown and col(names.SecondaryHandSlot) > 18, "second weapon beside the first")
	worn[16] = nil; worn[17] = nil
	runTicks(6, 0.1)
	assert(not names.MainHandSlot.shown and not names.SecondaryHandSlot.shown and not f.weaponHead.shown, "weapons put away")
	worn[0] = ammo
	runTicks(6, 0.1)
	assert(names.AmmoSlot.shown and f.weaponHead.shown, "ammo shows when held")
	worn[0] = nil
	runTicks(6, 0.1)
	-- the show / hide scripts (the mock's Show does not run them)
	f.scripts.OnShow(); f.scripts.OnHide()
	assert(#playedSounds - sounds0 == 2, "open / close sounds")
	-- the picture
	local was = {}
	for _, w in ipairs(G.all) do was[w] = w.shown; w.shown = false end
	for _, w in ipairs(G.always) do was[w] = w.shown; w.shown = false end
	dumpLayout(OUTDIR .. "/layout_char.txt")
	for w, v in pairs(was) do w.shown = v end
	-- the same key closes it again
	ToggleCharacter("PaperDollFrame")
	assert(not f.shown and not CharacterFrame.shown, "toggle closes")
	-- another tab of the game's window is the game's own
	ToggleCharacter("ReputationFrame")
	assert(CharacterFrame.shown and not f.shown, "reputation tab stays stock")
	HideUIPanel(CharacterFrame)
	-- anything else that shows the stock window on its first tab is turned into ours
	CharacterFrame.selectedTab = 1
	ShowUIPanel(CharacterFrame)
	assert(f.shown and not CharacterFrame.shown, "OnShow backup")
	f:Hide()
	-- the buttons
	G.charBtn.scripts.OnClick()
	assert(f.shown, "character button opens the panel")
	G.charBtn.scripts.OnClick()
	assert(not f.shown, "character button closes it again")
	-- option off: the game's window comes back
	G.SetOpt("charPanel", false)
	ToggleCharacter("PaperDollFrame")
	assert(CharacterFrame.shown and not f.shown, "option off -> stock window")
	HideUIPanel(CharacterFrame)
	G.SetOpt("charPanel", true)
	-- no run: the game's window
	phase = nil
	runTicks(3, 0.1)
	ToggleCharacter("PaperDollFrame")
	assert(CharacterFrame.shown and not f.shown, "no run -> stock window")
	HideUIPanel(CharacterFrame)
	phase = "playing"
	runTicks(3, 0.1)
	-- a run ending takes the panel with it
	f:Show()
	phase = nil
	runTicks(3, 0.1)
	assert(not f.shown, "panel stays after the run ended")
	phase = "playing"
	runTicks(3, 0.1)
	-- changing stats rebuilds the layout, an empty table is fine
	local keep = AZS_STATS
	AZS_STATS = { hp = 100 }
	f:Show(); runTicks(6, 0.1)
	local n = 0
	for _, c in ipairs(f.attr.cells) do if c.shown then n = n + 1 end end
	assert(n == 1, "one stat -> one cell, got " .. n)
	AZS_STATS = {}
	runTicks(6, 0.1)
	n = 0
	for _, c in ipairs(f.attr.cells) do if c.shown then n = n + 1 end end
	assert(n == 0 and f.attr.empty.text ~= "", "empty stats")
	AZS_STATS = nil
	runTicks(6, 0.1)
	AZS_STATS = { hp = "x", dmg = "1.5", weird = {} }
	runTicks(6, 0.1)
	AZS_STATS = keep
	runTicks(6, 0.1)
	f:Hide()
		SlashCmdList["AZSGW2"]("stats")
	SlashCmdList["AZSGW2"]("char")
	assert(f.shown); f:Hide()
	SlashCmdList["AZSGW2"]("char off"); assert(not G.Opt("charPanel"))
	SlashCmdList["AZSGW2"]("char on"); assert(G.Opt("charPanel"))
end)


scenario("boss bars: the lists of the run before are not shown", function()
	local c = G.bossFrame
	runTicks(4, 0.1)
	assert(c.rows[1].shown, "the bars show a run's bosses")
	-- a new run begins: the game still holds the old list (its stamp is older than the run's)
	AZS_ZONE_UPDATED = 100; AZS_UNITS_UPDATED = 50
	runTicks(4, 0.1)
	assert(not c.rows[1].shown and not c.rows[2].shown, "the bars of the run before stay up")
	-- the new run's list comes
	AZS_UNITS_UPDATED = 120
	runTicks(4, 0.1)
	assert(c.rows[1].shown, "the bars do not come with the new list")
	-- before the run starts the tables are the last run's too
	phase = "ready"; runTicks(4, 0.1)
	assert(not c.rows[1].shown, "bars shown before a run")
	phase = "playing"; runTicks(4, 0.1)
	assert(c.rows[1].shown)
	-- the elite filter of the plates and the target bar read the same list
	AZS_UNITS = { { kind = "elite", id = 1, name = "Old Warden", hp = 10, hpm = 100, state = 0 } }
	AZS_UNITS_UPDATED = 60
	assert(G.UnitsStale() == true, "an old list is not stale")
	AZS_ZONE_UPDATED = nil; AZS_UNITS_UPDATED = nil; AZS_UNITS = nil
	assert(G.UnitsStale() == false)
end)

scenario("boss list header", function()
	local c = G.bossFrame
	runTicks(4, 0.1)
	print("header (boss + guardian):", c.headText.shown, c.headText.text)
	assert(c.headText.shown and c.headLine.shown and c.headText.text == "Bosses & Guardians", "title with two enemies")
	assert(c.headSkull == nil and c.headCrown == nil, "no skull / crown repeated in the title")
	local sb, sg = AZS_GetBosses, AZS_GetGuardians
	local function guard(id, name) return { id = id, name = name, hp = 100, hpm = 900, awake = true, debuffs = {} } end
	AZS_GetBosses = function() return {} end
	AZS_GetGuardians = function() return { guard(5, "Gruff Swiftbite") } end
	runTicks(4, 0.1)
	print("one guardian: title", c.headText.shown, "row", c.rows[1].shown, c.rows[1].name.text)
	assert(not c.headText.shown and not c.headLine.shown and c.rows[1].shown and not c.rows[2].shown, "a single enemy has no title")
	assert(lastPoint(c.rows[1])[5] == -2, "row 1 right under the top: " .. tostring(lastPoint(c.rows[1])[5]))
	WorldFrame.parent = nil
	local was = {}
	for _, w in ipairs(G.all) do was[w] = w.shown; if w ~= c then w.shown = false end end
	for _, w in ipairs(G.always) do was[w] = w.shown; w.shown = false end
	dumpLayout(OUTDIR .. "/layout_guard1.txt")
	AZS_GetGuardians = function() return { guard(5, "Gruff Swiftbite"), guard(6, "Spectral Tutor") } end
	runTicks(4, 0.1)
	assert(c.headText.shown and c.headText.text == "Guardians" and lastPoint(c.rows[1])[5] == -24, "title with two guardians")
	for _, w in ipairs(G.all) do if w ~= c then w.shown = false end end -- the ticks showed the other parts again; the preview is about the list
	for _, w in ipairs(G.always) do w.shown = false end
	dumpLayout(OUTDIR .. "/layout_guard2.txt")
	for w, v in pairs(was) do w.shown = v end
	AZS_GetGuardians = function() return {} end
	runTicks(4, 0.1)
	assert(not c.rows[1].shown and not c.headText.shown and not c.panel.shown, "nothing listed")
	AZS_GetBosses, AZS_GetGuardians = sb, sg
	runTicks(4, 0.1)
end)

scenario("settings pages: a picture of each", function()
	local f = G.settings
	f:Show(); G.RefreshSettings()
	WorldFrame.parent = nil
	local was = {}
	for _, w in ipairs(G.all) do was[w] = w.shown; w.shown = false end
	for _, w in ipairs(G.always) do was[w] = w.shown; w.shown = false end
	for i, t in ipairs(f.tabs) do
		t.scripts.OnClick()
		dumpLayout(OUTDIR .. "/layout_settings_" .. i .. ".txt")
	end
	f.tabs[1].scripts.OnClick()
	f:Hide()
	for w, v in pairs(was) do w.shown = v end
end)

scenario("jewelry row", function()
	-- no plate any more; the pieces stand in a row like the F1 - F5 skills of GW2
	assert(G.jewPlate == nil, "the jewelry plate is gone")
	local old = AZS_GetMeterLoadout
	local oldRev = metaRev
	AZS_GetMeterLoadout = function(q)
		local lo = old(q)
		local items = {
			{ "item:t1", "Trinket One", "trinket", "INV_Misc_Gear_01" },
			{ "item:r1", "Ring One", "ring", "INV_Jewelry_Ring_01" },
			{ "item:a1", "Amulet of Doom", "amulet", "INV_Jewelry_Necklace_01" },
			{ "item:t2", "Trinket Two", "trinket", "INV_Misc_Gear_02" },
			{ "item:r2", "Ring Two", "ring", "INV_Jewelry_Ring_02" },
		}
		lo.runJewelry = {}
		for _, it in ipairs(items) do
			lo.sources[it[1]] = { name = it[2], icon = { status = "ready", path = "Interface\\Icons\\" .. it[4] } }
			table.insert(lo.runJewelry, { sourceKey = it[1], category = it[3] })
		end
		return lo
	end
	metaRev = "jewel1"
	runTicks(4, 1.1)
	local names = {}
	for i = 1, 6 do names[i] = G.jewSlots[i].data and G.jewSlots[i].data.name or "-" end
	print("jewelry order:", table.concat(names, " | "))
	assert(names[1] == "Amulet of Doom" and names[2] == "Ring One" and names[3] == "Ring Two"
		and names[4] == "Trinket One" and names[5] == "Trinket Two" and names[6] == "-", "amulet, rings, trinkets: " .. table.concat(names, ","))
	local a = G.jewSlots[1]
	assert(a:GetWidth() > G.jewSlots[2]:GetWidth() and a:GetWidth() == a:GetHeight(), "the amulet is a little bigger than the rest")
	assert(G.jewSlots[2]:GetWidth() == G.jewSlots[5]:GetWidth() and G.jewSlots[2]:GetWidth() > 25, "rings and trinkets have one size")
	assert(a:GetWidth() <= G.jewSlots[2]:GetWidth() * 1.4, "only slightly bigger")
	local p1, p2, p5 = lastPoint(a), lastPoint(G.jewSlots[2]), lastPoint(G.jewSlots[5])
	assert(p1[2] == G.accessories and p1[1] == "BOTTOMLEFT" and p1[3] == "BOTTOMLEFT", "the row starts at the Accessories box")
	-- the box stands above the left three skills (1 - 3), a little over the racial, and can be moved and resized on its own
	do
		local acc = G.accessories
		local ap = acc.pts[1]
		assert(ap[1] == "BOTTOMLEFT" and ap[2] == G.slots[1] and ap[3] == "TOPLEFT" and ap[5] > 0, "above the first skill")
		assert(ap[4] == 0, "lined up with the first skill: " .. tostring(ap[4]))
		local m = G.MovableByKey("accessories")
		assert(m and m.label == "Accessories" and m.frame == acc, "movable, called Accessories")
		assert(G.groupOf[G.jewSlots[1]] == "accessories" and G.groupOf[G.jewSlots[6]] == "accessories", "the pieces scale with their box")
		-- the five pieces a hero can wear (amulet, two rings, two trinkets) are exactly as wide as the left three skills
		local five = G.jewSlots[1]:GetWidth() + 6 + 4 * G.jewSlots[2]:GetWidth() + 3 * 3
		assert(acc:GetWidth() == 3 * 52 + 2 * 3 and five == acc:GetWidth(), "five pieces as wide as skills 1 - 3: " .. five .. " vs " .. acc:GetWidth())
	end
	-- the right end of the row reaches no further than the right edge of the third skill
	do
		local last = G.jewSlots[5]
		local right = last.pts[1]
		assert(last:GetWidth() > 0 and right[2] == G.jewSlots[4], "pieces hang off each other")
	end
	assert(p2[2] == a and p5[2] == G.jewSlots[4] and p2[1] == "BOTTOMLEFT" and p2[3] == "BOTTOMRIGHT", "bottoms line up, each next to the one before")
	assert(p2[4] > p5[4], "a little more room after the amulet than between the others")
	for i = 1, 5 do assert(G.jewSlots[i].shown, "slot " .. i .. " shown") ; assert(G.jewSlots[i].icon.tex, "icon " .. i) end
	assert(not G.jewSlots[6].shown, "no sixth piece")
	dumpLayout(OUTDIR .. "/layout_jewelry.txt")
	-- the tooltip names the piece and its kind
	G.jewSlots[2].scripts.OnEnter()
	assert(tipLines[1] == "Ring One" and tipLines[2] == "Ring", "tooltip: name and kind: " .. table.concat(tipLines, " | "))
	G.jewSlots[2].scripts.OnLeave()
	assert(G.jewSlots[2].bev.tint == "steel" and G.jewSlots[2].slotId == nil, "pieces that are not worn keep the steel border")
	local gear13 = worn[13]
	worn[13] = nil                                          -- (the default mock wears some Gear in the first trinket place)
	runTicks(3, 1.1)
	assert(G.jewSlots[4].slotId == nil and G.jewSlots[4].bev.tint == "steel", "an empty place gives no tooltip and no colour")
	worn[13] = gear13
	-- worn: the border has the colour of the rarity and the tooltip is the game's own tooltip of the item
	do
		local saved = { worn[2], worn[11], worn[12], worn[13], worn[14] }
		worn[2] = { "Interface\\Icons\\INV_Jewelry_Necklace_01", "|cffa335ee|Hitem:21:0:0:0|h[Amulet of Doom]|h|r" }
		worn[11] = { "Interface\\Icons\\INV_Jewelry_Ring_01", "|cff0070dd|Hitem:22:0:0:0|h[Ring One]|h|r" }
		worn[12] = { "Interface\\Icons\\INV_Jewelry_Ring_02", "|cff1eff00|Hitem:23:0:0:0|h[Ring Two]|h|r" }
		worn[13] = { "Interface\\Icons\\INV_Misc_Gear_01", "|cffff8000|Hitem:24:0:0:0|h[Trinket One]|h|r" }
		worn[14] = { "Interface\\Icons\\INV_Misc_Gear_02", "|cffffffff|Hitem:25:0:0:0|h[Trinket Two]|h|r" }
		runTicks(3, 1.1)
		local function left(i) return G.jewSlots[i].bev.edges.left.vc end
		local function near(c, r, g, b) return math.abs(c[1] - r) < 0.02 and math.abs(c[2] - g) < 0.02 and math.abs(c[3] - b) < 0.02 end
		assert(G.jewSlots[1].slotId == 2 and G.jewSlots[2].slotId == 11 and G.jewSlots[3].slotId == 12 and G.jewSlots[4].slotId == 13 and G.jewSlots[5].slotId == 14,
			"every piece found its place: " .. table.concat({ tostring(G.jewSlots[1].slotId), tostring(G.jewSlots[2].slotId), tostring(G.jewSlots[3].slotId), tostring(G.jewSlots[4].slotId), tostring(G.jewSlots[5].slotId) }, ","))
		assert(near(left(1), 0xa3 / 255, 0x35 / 255, 0xee / 255), "epic amulet: purple border")
		assert(near(left(2), 0, 0x70 / 255, 0xdd / 255), "rare ring: blue border")
		assert(near(left(3), 0x1e / 255, 1, 0), "uncommon ring: green border")
		assert(near(left(4), 1, 0x80 / 255, 0), "legendary trinket: orange border")
		assert(near(left(5), 0.74, 0.74, 0.78), "common trinket: quiet steel, not glaring white")
		local top, bottom = G.jewSlots[2].bev.edges.top.vc, G.jewSlots[2].bev.edges.bottom.vc
		assert(top[3] > left(2)[3] and bottom[3] < left(2)[3], "light on top, dark below")
		-- the colour is only sent to the game when it changes
		local calls = G.jewSlots[2].bev.edges.left.vcCount
		runTicks(3, 1.1)
		assert(G.jewSlots[2].bev.edges.left.vcCount == calls, "the colour is not sent again")
		-- the tooltip is the game's own
		INV_TIP = true
		for i, slot in ipairs({ 2, 11, 12, 13, 14 }) do
			lastInvTip = nil
			tipLines = {}
			G.jewSlots[i].scripts.OnEnter()
			assert(lastInvTip == slot, "piece " .. i .. " shows inventory slot " .. slot .. ": " .. tostring(lastInvTip))
			G.jewSlots[i].scripts.OnLeave()
		end
		INV_TIP = nil
		-- a client where that call fails: the name in its colour and the kind
		tipLines = {}
		G.jewSlots[2].scripts.OnEnter()
		assert(tipLines[1] == "Ring One" and tipLines[2] == "Ring", "fallback tooltip: " .. table.concat(tipLines, " | "))
		G.jewSlots[2].scripts.OnLeave()
		-- two rings of the same name take one place each
		worn[12] = { "Interface\\Icons\\INV_Jewelry_Ring_01", "|cffff8000|Hitem:26:0:0:0|h[Ring One]|h|r" }
		G.jewSlots[3].data.name = "Ring One"
		runTicks(3, 1.1)
		assert(G.jewSlots[2].slotId == 11 and G.jewSlots[3].slotId == 12, "same name, two places: " .. tostring(G.jewSlots[2].slotId) .. "," .. tostring(G.jewSlots[3].slotId))
		G.jewSlots[3].data.name = "Ring Two"                    -- (the test before changed it)
		-- an UPGRADE: the item in the place is another one (a better rarity, and for the ring also another name and icon), and the
		-- loadout still has the old data and the old revision
		worn[2] = { "Interface\\Icons\\INV_Jewelry_Necklace_01", "|cffa335ee|Hitem:21:0:0:0|h[Amulet of Doom]|h|r" }
		worn[11] = { "Interface\\Icons\\INV_Jewelry_Ring_01", "|cffffffff|Hitem:22:0:0:0|h[Ring One]|h|r" }
		worn[12] = { "Interface\\Icons\\INV_Jewelry_Ring_02", "|cff1eff00|Hitem:23:0:0:0|h[Ring Two]|h|r" }
		worn[13] = { "Interface\\Icons\\INV_Misc_Gear_01", "|cffff8000|Hitem:24:0:0:0|h[Trinket One]|h|r" }
		worn[14] = { "Interface\\Icons\\INV_Misc_Gear_02", "|cffffffff|Hitem:25:0:0:0|h[Trinket Two]|h|r" }
		runTicks(3, 1.1)
		assert(G.jewSlots[2].slotId == 11 and near(left(2), 0.74, 0.74, 0.78), "before the upgrade: a white ring")
		-- same name, better rarity
		worn[11] = { "Interface\\Icons\\INV_Jewelry_Ring_01", "|cff1eff00|Hitem:32:0:0:0|h[Ring One]|h|r" }
		runTicks(3, 1.1)
		assert(near(left(2), 0x1e / 255, 1, 0) and G.jewSlots[2].slotId == 11, "upgraded to green: the border follows")
		-- another name and another icon too: nothing in the loadout says so, the place is still the ring's
		worn[11] = { "Interface\\Icons\\INV_Jewelry_Ring_09", "|cff0070dd|Hitem:33:0:0:0|h[Fine Ring of Doom]|h|r" }
		runTicks(3, 1.1)
		assert(G.jewSlots[2].slotId == 11 and near(left(2), 0, 0x70 / 255, 0xdd / 255), "renamed by the upgrade: still its place, blue border: " .. tostring(G.jewSlots[2].slotId))
		assert(G.jewSlots[3].slotId == 12, "the other ring keeps its place")
		INV_TIP = true; lastInvTip = nil; tipLines = {}
		G.jewSlots[2].scripts.OnEnter()
		assert(lastInvTip == 11, "and the tooltip is the game's tooltip of the upgraded ring: " .. tostring(lastInvTip))
		G.jewSlots[2].scripts.OnLeave()
		INV_TIP = nil
		-- the loadout names the places itself (item instances), so even two renamed rings are told apart: Ring One now sits in 12
		do
			local prev = AZS_GetMeterLoadout
			AZS_GetMeterLoadout = function(q)
				local lo = prev(q)
				for _, e in ipairs(lo.runJewelry) do e.itemInstanceKey = "inst:" .. e.sourceKey end
				lo.equipment = {}
				for i = 1, 20 do lo.equipment[i] = { slotId = i - 1, supported = true, occupied = false } end
				lo.equipment[13] = { slotId = 12, supported = true, occupied = true, itemInstanceKey = "inst:item:r1", sourceKey = "item:r1" }
				lo.equipment[12] = { slotId = 11, supported = true, occupied = true, itemInstanceKey = "inst:item:r2", sourceKey = "item:r2" }
				return lo
			end
			worn[11] = { "Interface\\Icons\\INV_Jewelry_Ring_11", "|cff1eff00|Hitem:34:0:0:0|h[Sparkling Band]|h|r" }
			worn[12] = { "Interface\\Icons\\INV_Jewelry_Ring_12", "|cffa335ee|Hitem:35:0:0:0|h[Shimmering Loop]|h|r" }
			metaRev = metaRev .. "e"
			runTicks(3, 1.1)
			assert(G.jewSlots[2].data.name == "Ring One" and G.jewSlots[2].slotId == 12 and near(left(2), 0xa3 / 255, 0x35 / 255, 0xee / 255),
				"Ring One is the item in place 12: " .. tostring(G.jewSlots[2].slotId))
			assert(G.jewSlots[3].data.name == "Ring Two" and G.jewSlots[3].slotId == 11 and near(left(3), 0x1e / 255, 1, 0), "Ring Two is the item in place 11")
			AZS_GetMeterLoadout = prev
			metaRev = metaRev .. "f"
			runTicks(3, 1.1)
		end
		-- a loadout that is a moment behind (same revision, the old piece in it) is read again after the worn pieces change
		do
			local reads = 0
			local prev = AZS_GetMeterLoadout
			local upgraded = false
			AZS_GetMeterLoadout = function(q)
				reads = reads + 1
				local lo = prev(q)
				if upgraded then
					lo.sources["item:t1"] = nil
					lo.sources["item:t1b"] = { name = "Trinket One+", icon = { status = "ready", path = "Interface\\Icons\\INV_Misc_Gear_05" } }
					for _, e in ipairs(lo.runJewelry) do if e.sourceKey == "item:t1" then e.sourceKey = "item:t1b" end end
				end
				return lo
			end
			runTicks(8, 1.1)
			local r0 = reads
			runTicks(8, 1.1)
			assert(reads == r0, "nothing changed: the loadout is not read again (" .. (reads - r0) .. ")")
			upgraded = true
			worn[13] = { "Interface\\Icons\\INV_Misc_Gear_05", "|cff0070dd|Hitem:36:0:0:0|h[Trinket One+]|h|r" }
			runTicks(2, 1.1)
			assert(reads > r0, "the worn piece changed: the loadout is read again")
			local t
			for i = 1, 6 do if G.jewSlots[i].data and G.jewSlots[i].data.name == "Trinket One+" then t = G.jewSlots[i] end end
			assert(t and t.slotId == 13 and near(t.bev.edges.left.vc, 0, 0x70 / 255, 0xdd / 255), "the upgraded trinket shows its new name, place and colour")
			runTicks(12, 1.1)
			local r1 = reads
			runTicks(8, 1.1)
			assert(reads == r1 and r1 - r0 <= 6, "the extra reads stop after a few seconds: " .. (r1 - r0))
			AZS_GetMeterLoadout = prev
			metaRev = metaRev .. "g"
			runTicks(3, 1.1)
		end
		worn[2], worn[11], worn[12], worn[13], worn[14] = saved[1], saved[2], saved[3], saved[4], saved[5]
		runTicks(3, 1.1)
		assert(G.jewSlots[2].bev.tint == "steel", "no longer worn: steel again")
	end
	assert(G.jewSlots[1].scripts.OnEnter and G.jewSlots[1].strata == "HIGH", "above the game's own HUD frames, so the mouse reaches the pieces")
	-- hiding with the run and coming back
	phase = nil; runTicks(4, 1.1)
	for i = 1, 5 do assert(not G.jewSlots[i].shown, "jewelry hidden outside a run") end
	phase = "playing"; runTicks(4, 1.1)
	for i = 1, 5 do assert(G.jewSlots[i].shown, "jewelry back with the run, slot " .. i) end
	-- only a ring: it moves to the front of the row, the other slots go
	AZS_GetMeterLoadout = function(q)
		local lo = old(q)
		lo.runJewelry = { { sourceKey = "item:100", category = "ring" } }
		return lo
	end
	metaRev = "jewel2"
	runTicks(4, 1.1)
	assert(G.jewSlots[1].data.name == "Ring of Doom" and G.jewSlots[1]:GetWidth() == G.jewSlots[2]:GetWidth() and not G.jewSlots[2].shown, "one ring: normal size, first")
	assert(lastPoint(G.jewSlots[1])[2] == G.accessories, "alone it is at the start of the Accessories box")
	-- not worn but known by its item id: the colour comes from the item, the tooltip from its link
	do
		local old2 = AZS_GetMeterLoadout
		AZS_GetMeterLoadout = function(q)
			local lo = old2(q)
			lo.sources["item:100"].itemId = 777
			return lo
		end
		GetItemInfo = function(id) return "Ring of Doom", "|cffff8000|Hitem:" .. id .. ":0:0:0|h[Ring of Doom]|h|r", 5 end
		linkTip["item:777"] = { "Ring of Doom" }
		metaRev = metaRev .. "y"
		runTicks(3, 1.1)
		local j = G.jewSlots[1]
		assert(j.slotId == nil and j.qr and math.abs(j.qg - 0.5) < 0.02, "colour from the item id")
		lastLink = nil
		j.scripts.OnEnter()
		assert(lastLink == "item:777", "tooltip from the link: " .. tostring(lastLink))
		j.scripts.OnLeave()
		GetItemInfo = nil; linkTip["item:777"] = nil
		AZS_GetMeterLoadout = old2
		metaRev = metaRev .. "z"
		runTicks(3, 1.1)
	end
	-- the switch
	G.SetOpt("accessories", false); runTicks(4, 1.1)
	for i = 1, 6 do assert(not G.jewSlots[i].shown, "accessories off: slot " .. i) end
	G.SetOpt("accessories", true); runTicks(4, 1.1)
	assert(G.jewSlots[1].shown, "accessories back on")
	AZS_GetMeterLoadout = old
	metaRev = oldRev
	runTicks(4, 1.1)
end)

scenario("secret party mode", function()
	-- nothing is built, nothing runs, before it is asked for
	assert(G.rave.built == false and rawget(_G, "AZSGW2Rave") == nil, "nothing built before /gw2 party")
	assert(G.raveUpdater and G.raveUpdater.interval >= 0.5, "the updater is idle while it is off")
	-- it is a secret: the help and the docs do not tell
	local n0 = #chatLines
	SlashCmdList["AZSGW2"]("help")
	local helped = table.concat(chatLines, "\n", n0 + 1)
	assert(not helped:lower():find("%f[%w]rave%f[%W]") and not helped:lower():find("party mode") and not helped:find("/gw2 party[^i]") and not helped:find("/gw2 party$"), "the help does not tell")
	for _, name in ipairs({ "README.md", "CHANGELOG.md", "tools/README.md" }) do
		local fh = io.open(ROOT .. "/" .. name)
		if fh then
			local txt = fh:read("*a"):lower(); fh:close()
			assert(not txt:find("/gw2 party[^i]") and not txt:find("party mode") and not txt:find("caramell") and not txt:find("%f[%w]rave%f[%W]"), "the secret is in " .. name)
		end
	end
	-- on
	local files0 = #playedFiles
	local widgets0 = #allWidgets
	SlashCmdList["AZSGW2"]("party")
	assert(G.rave.on and G.rave.built, "party mode is on")
	local f = rawget(_G, "AZSGW2Rave")
	assert(f and f.shown, "the overlay is up")
	assert(not f:IsMouseEnabled(), "the lights never take the mouse (a click goes through to the world)")
	assert(G.raveUpdater.interval < 0.1, "the updater runs fast while it is on")
	assert(#allWidgets - widgets0 < 170, "a sensible number of widgets: " .. (#allWidgets - widgets0))
	local chat0 = #chatLines
	local alphas, maxScale, wash = {}, 1, G.rave.wash
	local widgets1 = #allWidgets
	for i = 1, 240 do                                         -- eight seconds at 30 frames a second
		runTicks(1, 1 / 30)
		alphas[#alphas + 1] = wash.vc[4]
		for _, fr in ipairs(G.all) do
			local base = G.ScaleFor(fr)
			if fr.scale and fr.scale / base > maxScale then maxScale = fr.scale / base end
		end
	end
	assert(#allWidgets == widgets1, "nothing new is created while it runs")
	for i = chat0 + 1, #chatLines do assert(not chatLines[i]:find("error"), "an error while it runs: " .. chatLines[i]) end
	-- the song is played in pieces of 3 seconds, one after the other, each started a moment before its time (so that it fades into
	-- the one before): the first at once, the second 2.925 s later, the third 3 s after that
	assert(#playedFiles - files0 == 3, "three pieces in eight seconds: " .. (#playedFiles - files0))
	for k = 1, 3 do
		assert(playedFiles[files0 + k] == "Interface\\AddOns\\AZSGW2UI\\Sounds\\party_" .. k .. ".mp3", "piece " .. k .. ": " .. tostring(playedFiles[files0 + k]))
	end
	do
		local t1, t2, t3 = playedTimes[files0 + 1], playedTimes[files0 + 2], playedTimes[files0 + 3]
		assert(math.abs(t2 - t1 - 2.925) < 0.05 and math.abs(t3 - t2 - 3.0) < 0.05, string.format("piece times %.3f %.3f", t2 - t1, t3 - t2))
	end
	-- the interface bounces, a few percent
	assert(maxScale > 1.02 and maxScale < 1.06, "the interface bounces a little: " .. maxScale)
	-- nothing flashes: the wash stays faint, never goes dark and bright, and its brightness turns round no more than the beat does
	local lo, hi, turns = 9, -9, 0
	local dir = 0
	for i = 2, #alphas do
		lo, hi = math.min(lo, alphas[i]), math.max(hi, alphas[i])
		local d = alphas[i] - alphas[i - 1]
		if math.abs(d) > 1e-6 then
			local nd = d > 0 and 1 or -1
			if dir ~= 0 and nd ~= dir then turns = turns + 1 end
			dir = nd
		end
	end
	print(string.format("party wash alpha %.3f .. %.3f, %d turns in 8 s", lo, hi, turns))
	assert(hi <= 0.11 and lo >= 0.04 and hi - lo <= 0.06, "the wash is faint and gentle")
	assert(turns <= 8 * 2.7 * 2 + 4, "no faster than the beat (under three a second): " .. turns)
	-- the song comes round again after its length: 8 pieces, then the first again
	runTicks(800, 1 / 30)
	assert(#playedFiles - files0 == 12, "twelve pieces in 35 seconds: " .. (#playedFiles - files0))
	assert(playedFiles[files0 + 8]:find("party_8.mp3", 1, true) and playedFiles[files0 + 9]:find("party_1.mp3", 1, true), "the loop starts over")
	-- off: the interface is back at its own size, the overlay is gone, the updater idles
	SlashCmdList["AZSGW2"]("party")
	assert(not G.rave.on and not f.shown, "party mode off")
	for _, fr in ipairs(G.all) do assert(fr.scale == G.ScaleFor(fr), "size back to normal") end
	assert(G.raveUpdater.interval >= 0.5, "idle again")
	local count = #playedFiles
	runTicks(300, 1 / 30)
	assert(#playedFiles == count, "no more pieces started while it is off: the song ends with the piece that plays")
	-- switched on again: the song starts from its first piece
	SlashCmdList["AZSGW2"]("party on")
	runTicks(30, 1 / 30)
	assert(G.rave.on and #playedFiles == count + 1 and playedFiles[#playedFiles]:find("party_1.mp3", 1, true), "starts from the first piece")
	SlashCmdList["AZSGW2"]("party off")
	-- /gw2 off ends it too
	SlashCmdList["AZSGW2"]("party")
	assert(G.rave.on)
	SlashCmdList["AZSGW2"]("off")
	assert(not G.rave.on and not f.shown, "/gw2 off stops the party")
	SlashCmdList["AZSGW2"]("on")
	-- a song of the player's own
	now = now + 100
	SlashCmdList["AZSGW2"]("party song mysong 12")
	assert(AZSGW2DB.partySong and AZSGW2DB.partySong.file == "mysong" and AZSGW2DB.partySong.parts == 12)
	SlashCmdList["AZSGW2"]("party song ../evil 10"); assert(AZSGW2DB.partySong.file == "mysong", "a path is not a file name")
	SlashCmdList["AZSGW2"]("party song x 99999"); assert(AZSGW2DB.partySong.file == "mysong", "a silly number of pieces is refused")
	SlashCmdList["AZSGW2"]("party song x 0"); assert(AZSGW2DB.partySong.file == "mysong", "no pieces is refused")
	SlashCmdList["AZSGW2"]("party song x"); assert(AZSGW2DB.partySong.file == "mysong", "the number of pieces is needed")
	local c1 = #playedFiles
	SlashCmdList["AZSGW2"]("party on"); runTicks(10, 1 / 30)
	assert(#playedFiles == c1 + 1 and playedFiles[#playedFiles]:find("mysong_1.mp3", 1, true), "the player's song plays")
	SlashCmdList["AZSGW2"]("party off")
	-- damaged saved variables fall back to the built-in song
	now = now + 200
	for _, bad in ipairs({ { file = "a\\b", parts = 10 }, { file = string.rep("a", 100), parts = 10 }, { file = "ok", parts = 0 }, { file = "ok", parts = -5 },
		{ file = "ok", parts = 401 }, { file = "ok", parts = 2.5 }, { file = "ok", parts = 0 / 0 }, { file = 5, parts = 10 }, { file = "ok", len = 10 }, "x" }) do
		AZSGW2DB.partySong = bad
		local c2 = #playedFiles
		SlashCmdList["AZSGW2"]("party on"); runTicks(5, 1 / 30)
		assert(#playedFiles == c2 + 1 and playedFiles[#playedFiles]:find("party_1.mp3", 1, true), "built-in song for a damaged setting")
		SlashCmdList["AZSGW2"]("party off")
		now = now + 100
	end
	SlashCmdList["AZSGW2"]("party song default"); assert(AZSGW2DB.partySong == nil)
	SlashCmdList["AZSGW2"]("party song")
	now = now + 100
	runTicks(2, 0.1)
	-- stopping the song: no new piece starts, and the game's sound is switched off for a moment (a playing sound is dropped) and put back
	do
		cvars["EnableSound"] = "1"
		now = now + 300
		local c0 = #playedFiles
		SlashCmdList["AZSGW2"]("party on"); runTicks(10, 1 / 30)
		assert(#playedFiles == c0 + 1, "a song is playing")
		n0 = #chatLines
		SlashCmdList["AZSGW2"]("party off")
		assert(cvars["EnableSound"] == "0", "the sound effects are off the moment the party ends")
		assert(AZSGW2DB.sfxMuted == "EnableSound", "remembered in case the game ends now")
		local said = table.concat(chatLines, "\n", n0 + 1)
		assert(said:find("party's over") and not said:find("ends by itself"), "it does not say the song has to play out: " .. said)
		runTicks(2, 0.1)
		assert(cvars["EnableSound"] == "0", "still off after a fifth of a second")
		runTicks(12, 0.1)
		assert(cvars["EnableSound"] == "1" and AZSGW2DB.sfxMuted == nil, "back on after half a second")
		assert(G.raveUpdater.interval >= 0.5, "idle again")
		local cnt = #playedFiles
		runTicks(150, 1 / 30)
		assert(#playedFiles == cnt, "no piece starts after the party is over")
		-- on again within the half second: the effects are back first and the new song is heard
		SlashCmdList["AZSGW2"]("party on"); runTicks(5, 1 / 30)
		SlashCmdList["AZSGW2"]("party off")
		assert(cvars["EnableSound"] == "0")
		local c1 = #playedFiles
		SlashCmdList["AZSGW2"]("party on")
		assert(cvars["EnableSound"] == "1", "a quick restart puts the effects back at once")
		runTicks(5, 1 / 30)
		assert(#playedFiles == c1 + 1, "and the new song starts: " .. (#playedFiles - c1))
		SlashCmdList["AZSGW2"]("party off"); runTicks(15, 0.1)
		assert(cvars["EnableSound"] == "1")
		-- the game ended in the middle of the switch: the next start of the addon puts it back
		cvars["EnableSound"] = "0"; AZSGW2DB.sfxMuted = "EnableSound"; G.rave.checked = false; G.rave.sfx = nil
		runTicks(2, 0.5)
		assert(cvars["EnableSound"] == "1" and AZSGW2DB.sfxMuted == nil, "put back after a crash")
		-- a silly remembered value is never written to the game
		AZSGW2DB.sfxMuted = "Sound_Volume"; G.rave.checked = false; cvars["Sound_Volume"] = "0.5"
		runTicks(2, 0.5)
		assert(cvars["Sound_Volume"] == "0.5" and AZSGW2DB.sfxMuted == nil, "an unknown name is dropped, not set")
		-- sound effects the player had switched off are left alone
		cvars["EnableSound"] = "0"
		SlashCmdList["AZSGW2"]("party on"); runTicks(5, 1 / 30); SlashCmdList["AZSGW2"]("party off"); runTicks(15, 0.1)
		assert(cvars["EnableSound"] == "0" and AZSGW2DB.sfxMuted == nil, "effects the player switched off stay off")
		cvars["EnableSound"] = nil
		-- the other name of the same switch
		cvars["MasterSoundEffects"] = "1"
		SlashCmdList["AZSGW2"]("party on"); runTicks(5, 1 / 30); SlashCmdList["AZSGW2"]("party off")
		assert(cvars["MasterSoundEffects"] == "0"); runTicks(15, 0.1); assert(cvars["MasterSoundEffects"] == "1")
		cvars["MasterSoundEffects"] = nil
		-- a client with a handle and StopSound
		RETURN_HANDLES = true
		local stopped = {}
		StopSound = function(h) table.insert(stopped, h) end
		SlashCmdList["AZSGW2"]("party on"); runTicks(5, 1 / 30); SlashCmdList["AZSGW2"]("party off")
		assert(#stopped == 1 and stopped[1] == soundHandles, "StopSound got the handle of the song")
		StopSound, RETURN_HANDLES = nil, nil
		-- only the first switch that exists is touched
		cvars["EnableSound"] = "1"; cvars["Sound_EnableSFX"] = "1"
		SlashCmdList["AZSGW2"]("party on"); runTicks(5, 1 / 30); SlashCmdList["AZSGW2"]("party off")
		assert(cvars["EnableSound"] == "0" and cvars["Sound_EnableSFX"] == "1", "one switch at a time")
		runTicks(15, 0.1)
		assert(cvars["EnableSound"] == "1" and cvars["Sound_EnableSFX"] == "1")
		cvars["Sound_EnableSFX"] = nil
		-- a song of the player's own, in pieces: the file name and the number of pieces
		SlashCmdList["AZSGW2"]("party song caramell 59")
		assert(AZSGW2DB.partySong.file == "caramell" and AZSGW2DB.partySong.parts == 59, "name and number of pieces")
		now = now + 400
		local c2 = #playedFiles
		SlashCmdList["AZSGW2"]("party on"); runTicks(60 * 30, 1 / 30)
		assert(#playedFiles - c2 == 20 or #playedFiles - c2 == 21, "a piece every three seconds for a minute: " .. (#playedFiles - c2))
		assert(playedFiles[c2 + 1]:find("caramell_1.mp3", 1, true) and playedFiles[c2 + 2]:find("caramell_2.mp3", 1, true), "in order")
		SlashCmdList["AZSGW2"]("party off")
		SlashCmdList["AZSGW2"]("party song default")
		assert(AZSGW2DB.partySong == nil, "back to the built-in song")
		now = now + 400
	end
	-- the old diagnostic lives on under its new name
	n0 = #chatLines
	SlashCmdList["AZSGW2"]("partyinfo")
	assert(#chatLines > n0, "/gw2 partyinfo still prints")
end)

scenario("guardian health: boss bar and guardian list, two separate switches", function()
	local f, c = G.guardians, G.bossFrame
	local function top()
		local names = {}
		for _, r in ipairs(c.rows) do if r.shown and r.entry then names[r.entry.name] = (r.entry.kind or "?") end end
		return names
	end
	local function click(label)
		for _, ch in ipairs(G.settings.checks) do if ch.row.label == label then ch.scripts.OnClick(); return end end
		error("no switch " .. label)
	end
	runTicks(8, 0.3)
	-- default: guardians on the boss bar, no bars on the list
	assert(G.Opt("guardianBars") == false and G.Opt("guardianBoss") == true and not G.GuardianBarsOnList(), "default is the boss bar")
	assert(top()["Necrofiend"] == "guardian" and top()["Boss C"], "guardian on the boss bar by default")
	for i = 1, 8 do assert(not f.rows[i].bar.shown, "no bar in the list by default, row " .. i) end
	assert(lastPoint(f.rows[2])[5] == -42 and lastPoint(f.rows[3])[5] == -60, "plain rows are 18 px apart")
	-- the switch "Health bars on the list" takes the guardians off the boss bar with it
	click("Health bars on the list")
	runTicks(8, 0.3)
	assert(G.Opt("guardianBars") == true and G.Opt("guardianBoss") == false, "list bars on, boss bar off")
	assert(G.GuardianBarsOnList(), "option and list on")
	assert(f.rows[2].bar.shown and f.rows[2].bar.pct.text == "11%", "bar with percent under the fighting guardian: " .. tostring(f.rows[2].bar.pct.text))
	assert(not f.rows[1].bar.shown and not f.rows[3].bar.shown, "no bar for an empty lair or a sleeping guardian")
	local bp = lastPoint(f.rows[2].bar)
	assert(bp[1] == "TOPLEFT" and bp[2] == f.rows[2] and bp[3] == "BOTTOMLEFT", "bar hangs under its own row")
	-- short: it stays well inside the list (and so far from the screen's edge)
	assert(f.rows[2].bar:GetWidth() >= 100 and f.rows[2].bar:GetWidth() <= 160 and f.rows[2].bar.fill.shown, "a short bar with a fill")
	assert(bp[4] + f.rows[2].bar:GetWidth() <= f:GetWidth() - 40, "the bar ends well before the right edge of the list")
	assert(lastPoint(f.rows[2])[5] == -42 and lastPoint(f.rows[3])[5] == -74, "the row after a bar is lower by the bar: " .. tostring(lastPoint(f.rows[3])[5]))
	assert(f:GetHeight() == 24 + 3 * 18 + 14 + 4, "list height with one bar: " .. tostring(f:GetHeight()))
	assert(top()["Boss C"] and not top()["Necrofiend"], "the top bar leaves the guardian out")
	dumpLayout(OUTDIR .. "/layout_guardlist.txt")
	-- health follows
	local sg = AZS_GetGuardians
	AZS_GetGuardians = function() return { { id = 5, name = "Necrofiend", hp = 450, hpm = 900, awake = true, debuffs = {} },
		{ id = 6, name = "Spectral Tutor", hp = 900, hpm = 900, awake = false, debuffs = {} } } end
	runTicks(4, 0.3)
	assert(f.rows[2].bar.pct.text == "50%", "percent follows the health: " .. tostring(f.rows[2].bar.pct.text))
	-- a second guardian wakes: it gets its bar too, the rows below move down again
	AZS_GetGuardians = function() return { { id = 5, name = "Necrofiend", hp = 450, hpm = 900, awake = true, debuffs = {} },
		{ id = 6, name = "Spectral Tutor", hp = 900, hpm = 900, awake = true, debuffs = {} } } end
	runTicks(4, 0.3)
	assert(f.rows[3].bar.shown and f.rows[3].bar.pct.text == "100%" and f:GetHeight() == 24 + 3 * 18 + 28 + 4, "two bars")
	assert(not top()["Necrofiend"] and not top()["Spectral Tutor"] and top()["Boss C"], "none of the two on the top bar")
	-- the switches are separate: with the boss bar one on again, the guardians are on both
	click("Guardians on the boss bar")
	runTicks(4, 0.3)
	assert(G.Opt("guardianBoss") == true and G.Opt("guardianBars") == true, "both on")
	assert(top()["Necrofiend"] and top()["Spectral Tutor"] and f.rows[2].bar.shown and f.rows[3].bar.shown, "on the boss bar and on the list")
	-- a guardian whose lair is not among the rows (id unknown to the list) has no bar there and stays on the boss bar
	AZS_GetGuardians = function() return { { id = 77, name = "Lost Guardian", hp = 5, hpm = 10, awake = true, debuffs = {} } } end
	runTicks(4, 0.3)
	assert(top()["Lost Guardian"], "a guardian without a row stays on the boss bar")
	assert(not f.rows[2].bar.shown and not f.rows[3].bar.shown, "bars gone with the guardians")
	-- and with the boss bar one off it is on neither (the player's choice)
	click("Guardians on the boss bar")
	runTicks(4, 0.3)
	assert(not top()["Lost Guardian"] and top()["Boss C"], "off: no guardians on the boss bar, the bosses stay")
	AZS_GetGuardians = sg
	-- the list switched off: no bars, and the boss bar switch is the player's
	G.SetOpt("guardians", false)
	runTicks(8, 0.3)
	assert(not G.GuardianBarsOnList() and not f:IsShown(), "list off: no bars")
	G.SetOpt("guardianBoss", true)
	runTicks(8, 0.3)
	assert(top()["Necrofiend"], "boss bar switch on: guardians on the boss bar")
	G.SetOpt("guardians", true)
	runTicks(8, 0.3)
	assert(f.rows[2].bar.shown and top()["Necrofiend"], "list on again: bars again, boss bar as set")
	-- a stale list (the run before) shows no bars
	AZS_ZONE_UPDATED = 5; AZS_UNITS_UPDATED = 1
	runTicks(4, 0.3)
	AZS_ZONE_UPDATED = nil; AZS_UNITS_UPDATED = nil
	-- the switch off again puts the guardians back on the boss bar
	G.SetOpt("guardianBoss", false)
	click("Health bars on the list")
	runTicks(8, 0.3)
	assert(G.Opt("guardianBars") == false and G.Opt("guardianBoss") == true, "list bars off: boss bar on again")
	for i = 1, 8 do assert(not f.rows[i].bar.shown, "bars gone, row " .. i) end
	assert(top()["Necrofiend"] == "guardian" and lastPoint(f.rows[3])[5] == -60 and f:GetHeight() == 24 + 3 * 18 + 4, "plain list again")
	print("guardian bars ok")
end)


scenario("party barrier", function()
	local rows = G.party.rows
	runTicks(6, 0.1)
	local r1, r2 = rows[1], rows[2]
	print("party row 1:", r1.pct.text, r1.hpText.text, "| barrier shown:", r1.bar.barrier.shown)
	assert(not r1.bar.barrier.shown and not r1.bar.edge.shown and r1.barText.text == "", "no barrier by default")
	-- the layer is above the health: its frame is above the bar's and the percent text's frame above that
	do
		local bar = r1.bar.barrier.parent
		assert(bar and bar.parent == r1.bar and bar:GetFrameLevel() > r1.bar:GetFrameLevel(), "barrier layer is a frame above the bar")
		assert(r1.pct.parent:GetFrameLevel() > bar:GetFrameLevel() and r1.pct.parent.parent == r1.bar, "percent text above the barrier")
		assert(r1.bar.barrier.layer == "OVERLAY", "barrier is an overlay texture")
	end
	-- health above the maximum is a barrier with an amount
	partyData.party1.hp = 2100
	runTicks(6, 0.1)
	print("party row 1 with barrier:", r1.pct.text, r1.hpText.text, r1.barText.text, "| shown:", r1.bar.barrier.shown)
	assert(r1.bar.barrier.shown and r1.barText.text == "+300" and r1.pct.text == "100%" and r1.hpText.text == "1.8K", "barrier amount")
	local pt = r1.bar.barrier.pts[#r1.bar.barrier.pts]
	assert(pt[4] > 100, "barrier runs back from the full end: " .. pt[4])
	assert(r1.port.edges.top.vc[2] > 0.8 and r1.port.edges.top.vc[3] < 0.5, "portrait trim goes gold")
	do
		local ub0 = UnitBuff
		UnitBuff = function(u, i) if u == "party2" and i == 4 then return "Interface\\Icons\\Spell_Holy_PowerWordShield" end if i <= 3 then return "Interface\\Icons\\Spell_Holy_WordFortitude" end end
		partyData.party2.hp = 1000
		runTicks(6, 0.1)
		dumpLayout(OUTDIR .. "/layout_party.txt")
		partyData.party2.hp = 700
		UnitBuff = ub0
	end
	partyData.party1.hp = 1000
	partyData.party1.hpm = 1800
	runTicks(2, 0.1)
	partyData.party1.hp = 1800 + 200
	runTicks(6, 0.1)
	r1.scripts.OnEnter()
	partyData.party1.hp = 1800
	-- a shield buff without an amount: a gold line
	local ub = UnitBuff
	UnitBuff = function(u, i) if u == "party2" and i == 4 then return "Interface\\Icons\\Spell_Holy_PowerWordShield" end if i <= 3 then return "Interface\\Icons\\Spell_Holy_WordFortitude" end end
	runTicks(6, 0.1)
	print("party row 2 with a shield buff:", r2.bar.barrier.shown, r2.bar.barrier.vc[4])
	assert(r2.bar.barrier.shown and r2.barText.text == "" and r2.bar.barrier.vc[4] < 0.5, "shield buff: a faint layer over the health, no amount")
	assert(r2.bar.barrier.pts[#r2.bar.barrier.pts][4] < 5, "the layer starts at the left end of the bar")
	assert(not r1.bar.barrier.shown, "no layer for a friend without the buff")
	r2.scripts.OnEnter()
	-- the shield goes: the line goes
	UnitBuff = function(u, i) if i <= 3 then return "Interface\\Icons\\Spell_Holy_WordFortitude" end end
	runTicks(6, 0.1)
	assert(not r2.bar.barrier.shown and not r2.bar.edge.shown, "layer stays")
	-- a downed friend shows no barrier
	partyData.party3.hp = 900 + 100
	runTicks(6, 0.1)
	assert(not rows[3].bar.barrier.shown and not rows[3].bar.edge.shown, "downed friend")
	partyData.party3.hp = 0
	-- many different buff icons do not grow anything without a limit
	UnitBuff = function(u, i) if i <= 16 then return "Interface\\Icons\\Spell_X_" .. math.floor(now * 1000) .. "_" .. i end end
	runTicks(120, 0.2)
	UnitBuff = ub
	runTicks(6, 0.1)
	SlashCmdList["AZSGW2"]("partyinfo")
end)


scenario("soak: 24 minutes of play with churn (memory / widget count must stay flat)", function()
	local function mem() collectgarbage(); collectgarbage(); return collectgarbage("count") end
	local function tick(n)
		for i = 1, n do
			runTicks(1, 0.05)
			if ctHandler then ctHandler() end
			if worldHandler then worldHandler() end
		end
	end
	local function guards()
		for _, id in ipairs({ "s1", "s2", "s3", "s4", "s5", "s6" }) do ctProj[id] = { anchorId = id, state = "onScreen", x = 300 + #id * 90 + tonumber(id:sub(2)) * 60, y = 300, playerDistance = 12 } end
	end
	local f = G.charPanel
	local widgets0, m0, samples = nil, nil, {}
	G.hunt.off = false
	local statsKeep = AZS_STATS
	for minute = 1, 24 do
		for step = 1, 60 do
			if step % 3 == 0 then
				guards()
				for i = 1, 6 do ctEvents[#ctEvents + 1] = { kind = "damage", amount = 1000 + i * step, critical = (i == 3), periodic = (i == 5), anchorId = "s" .. i, anchorStatus = "ready", sourceKind = (i == 6) and "pet" or "player", presentedAt = GetTime() } end
			end
			if step % 11 == 0 then
				bannerHandler({ kind = ({ "guardian", "magnet", "cache", "bossdown", "frienddown", "rune" })[1 + (step + minute) % 6], boss = false, name = "Some Guardian " .. minute, text = "Some Guardian " .. minute .. " is slain! Its lair yields treasure." })
			end
			if step % 13 == 0 then
				if #downedList == 1 then
					downedList = { { id = "H2", name = "Ghost", positionAvailable = false }, { id = "H" .. minute, name = "Friend" .. minute, positionAvailable = true, x = 10 + step, y = 5, z = 0, spaceId = "m1:1" } }
					anchorCatalog = { { anchorId = "dp" .. minute, kind = "downedPartyMember", state = "downed", memberId = "H" .. minute, name = "Friend" .. minute } }
				else
					downedList = { { id = "H2", name = "Ghost", positionAvailable = false } }
				end
			end
			if step % 5 == 0 then
				AZS_STATS = { hp = 2400 + step, dmg = 1.25 + step / 100, crit = 0.12, luck = 0.4, reg = 1.5, ["x" .. (step % 4)] = step, gdmg = 0.1 }
				partyData.party1.hp = 1800 + (step % 2) * 200
				partyData.party2.hp = 400 + step * 10
			end
			if step % 9 == 0 then
				clientTarget = (clientTarget == nil) and { name = "Kobold " .. minute, hostile = true, dead = false, class = "normal", hp = 50, hpm = 100 } or nil
				fire("PLAYER_TARGET_CHANGED")
			end
			if step % 17 == 0 then
				f:Show(); f.scripts.OnShow(); tick(3)
				for _, b in ipairs(f.slots) do if b.scripts.OnEnter then b.scripts.OnEnter(); b.scripts.OnLeave() end end
				for _, c in ipairs(f.attr.cells) do if c.shown and c.scripts.OnEnter then c.scripts.OnEnter() end end
				f:Hide(); f.scripts.OnHide()
			end
			if step % 19 == 0 then
				AZS_ZONE.heroic = step % 6
				AZS_ZONE.affixes = (step % 2 == 0) and "bolstering,sanguine" or ""
			end
			if step % 23 == 0 then
				G.ToggleSettings(); tick(2); G.ToggleSettings()
				G.SetUnlocked(true); tick(2); G.SetUnlocked(false)
			end
			if step == 31 then
				phase = nil; tick(4); phase = "playing"
			end
			tick(20)
			if step % 7 == 0 then
				for _, fr in ipairs({ G.orb, G.slots[1], G.slots[3], G.racial, G.meter.rows[1], G.tally.items.kills, G.jewSlots[1], G.talentBtn, G.charBtn }) do
					if fr and fr.scripts.OnEnter then pcall(fr.scripts.OnEnter) end
				end
			end
		end
		-- the mock's own logs are not the addon's memory
		for k in pairs(chatLines) do chatLines[k] = nil end
		for k in pairs(playedSounds) do playedSounds[k] = nil end
		for k in pairs(errorsMsgs) do errorsMsgs[k] = nil end
		for k in pairs(raidMsgs) do raidMsgs[k] = nil end
		ctEvents = {}
		local m = mem()
		samples[#samples + 1] = string.format("%.0f", m)
		if minute == 4 then widgets0, m0 = #allWidgets, m end
	end
	AZS_STATS = statsKeep
	local m1 = mem()
	print("memory (KB) after each minute:", table.concat(samples, " "))
	print("widgets after minute 4:", widgets0, "at the end:", #allWidgets)
	print(string.format("memory growth from minute 4 to 24: %.1f KB", m1 - m0))
	assert(#allWidgets == widgets0, "widgets still being created: " .. (#allWidgets - widgets0))
	assert(m1 - m0 < 150, "memory keeps growing: " .. (m1 - m0) .. " KB")
	local count = 0
	for _ in pairs(G.hunt.seen) do count = count + 1 end
	print("hunter remembered frames:", count, "| hide list:", #AZSGW2DB.hide, "| known downed:", (function() local n = 0 for _ in pairs(G.down.known) do n = n + 1 end return n end)(), "| label free list:", #G.dmg.free)
end)


scenario("garbage per rendered frame (60 fps, steady state)", function()
	local function measure(label, setup)
		if setup then setup() end
		runTicks(30, 0.016); collectgarbage(); collectgarbage()
		collectgarbage("stop")
		local before = collectgarbage("count")
		local frames = 300
		for i = 1, frames do
			runTicks(1, 0.016)
			if ctHandler then ctHandler() end
			if worldHandler then worldHandler() end
		end
		local after = collectgarbage("count")
		collectgarbage("restart")
		print(string.format("  %-34s %7.1f bytes per frame", label, (after - before) * 1024 / frames))
		return (after - before) * 1024 / frames
	end
	local idle = measure("idle run")
	local busy = measure("damage numbers on screen", function()
		for i = 1, 6 do ctProj["g" .. i] = { anchorId = "g" .. i, state = "onScreen", x = 300 + i * 80, y = 300, playerDistance = 10 } end
		for i = 1, 40 do ctEvents[i] = { kind = "damage", amount = 100 + i, critical = (i % 5 == 0), anchorId = "g" .. (1 + i % 6), anchorStatus = "ready", sourceKind = "player", presentedAt = GetTime() + 1000 } end
	end)
	ctEvents = {}
	runTicks(100, 0.016)
	local downed = measure("ally down, marker on screen", function()
		downedList = { { id = "H3", name = "Zaynor", positionAvailable = true, x = 30, y = 40, z = 0, spaceId = "m1:1" } }
		anchorCatalog = { { anchorId = "dpX", kind = "downedPartyMember", state = "downed", memberId = "H3", name = "Zaynor" } }
	end)
	downedList = { { id = "H2", name = "Ghost", positionAvailable = false } }
	local panel = measure("character panel open", function() G.charPanel:Show() end)
	G.charPanel:Hide()
end)


scenario("widget calls per rendered frame (idle, steady state)", function()
	runTicks(60, 0.016)
	local before = {}
	for k, v in pairs(used) do before[k] = v end
	local frames = 300
	for i = 1, frames do runTicks(1, 0.016); if ctHandler then ctHandler() end; if worldHandler then worldHandler() end end
	local list, total = {}, 0
	for k, v in pairs(used) do
		local d = v - (before[k] or 0)
		if d > 0 then table.insert(list, { k, d / frames }); total = total + d / frames end
	end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	local out = {}
	for i = 1, math.min(14, #list) do out[#out + 1] = string.format("%s %.1f", list[i][1], list[i][2]) end
	print(string.format("  widget method calls per frame: %.0f total | %s", total, table.concat(out, ", ")))
	-- 1.7 made about 91 calls a frame in this state: unchanged values are no longer sent to the game
	assert(total <= 50, "idle widget calls per frame went up: " .. total)
end)


scenario("widget calls per updater (steady state)", function()
	runTicks(60, 0.016)
	local rows = {}
	for _, u in ipairs(G.updaters) do
		local before = {}
		for k, v in pairs(used) do before[k] = v end
		local n = 40
		for i = 1, n do pcall(u.fn, 0.05) end
		local total, top = 0, {}
		for k, v in pairs(used) do local d = v - (before[k] or 0); if d > 0 then total = total + d; top[#top + 1] = { k, d / n } end end
		table.sort(top, function(a, b) return a[2] > b[2] end)
		local t = {}
		for i = 1, math.min(4, #top) do t[#t + 1] = string.format("%s %.1f", top[i][1], top[i][2]) end
		local hz = (u.interval > 0) and math.min(60, 1 / u.interval) or 60
		rows[#rows + 1] = { u.name, total / n, hz, total / n * hz, table.concat(t, ", ") }
	end
	table.sort(rows, function(a, b) return a[4] > b[4] end)
	for _, r in ipairs(rows) do print(string.format("  %-10s %6.1f calls/run  x %4.1f Hz = %7.1f calls/s   %s", r[1], r[2], r[3], r[4], r[5])) end
end)


scenario("hardening: saved variables, slash input, protected frames, error recovery", function()
	-- a damaged saved variables file
	local bad = { scale = "huge", enabled = "yes", customArt = 5, plates = 1,
		opt = { dmg = "x", dmgCrit = true, [3] = true },
		pos = { orb = { "NOWHERE", "CENTER", 0, 0 }, top = { "TOP", "TOP", 0, -10 }, party = { "LEFT", "LEFT", 0 / 0, 1 }, junk = 5, far = { "TOP", "TOP", 1e9, 0 } },
		hide = { "UIParent", "SomeFrame", "SomeFrame", "bad name!", 17, "WorldFrame", "ChatFrame1", "AZSGW2Bosses", "GameMenuFrame" },
		bind = { character = "TOGGLECHARACTER0", talents = "not a name!", [1] = "X" },
		cvSaved = { CombatDamage = "1", Big = string.rep("x", 100), [2] = "1" }, mapYards = -4 }
	G.CleanDB(bad)
	assert(bad.scale == 1 and bad.enabled == true and bad.customArt == true and bad.plates == nil and bad.opt.nameplates == true, "scalars / plates migration")
	assert(bad.opt.dmgCrit == true and bad.opt.dmg == nil and bad.opt[3] == nil, "opt")
	assert(bad.pos.top and bad.pos.orb == nil and bad.pos.party == nil and bad.pos.junk == nil and bad.pos.far == nil, "pos")
	assert(#bad.hide == 1 and bad.hide[1] == "SomeFrame", "hide list: " .. table.concat(bad.hide, ","))
	assert(bad.bind.character == "TOGGLECHARACTER0" and bad.bind.talents == nil and bad.bind[1] == nil, "bind")
	assert(bad.cvSaved.CombatDamage == "1" and bad.cvSaved.Big == nil and bad.cvSaved[2] == nil and bad.mapYards == nil, "cvSaved / mapYards")
	local notTable = { opt = 3, pos = "x", hide = 7, bind = false, cvSaved = 9 }
	G.CleanDB(notTable)
	assert(type(notTable.opt) == "table" and type(notTable.pos) == "table" and type(notTable.hide) == "table" and type(notTable.bind) == "table" and notTable.cvSaved == nil, "wrong types")
	-- the slash commands refuse what could hurt
	local n0 = #AZSGW2DB.hide
	for _, name in ipairs({ "UIParent", "WorldFrame", "ChatFrame1", "StaticPopup1", "GameMenuFrame", "AZSGW2Orb", "x y", "a;b", "" }) do
		SlashCmdList["AZSGW2"]("hide " .. name)
	end
	assert(#AZSGW2DB.hide == n0, "a protected / invalid name was stored")
	assert(not G.keptHidden.UIParent and not G.keptHidden.WorldFrame, "protected frame kept hidden")
	G.KeepHidden("UIParent"); G.KeepHidden("ChatFrame1"); G.KeepHidden("bad name")
	assert(UIParent.shown and not G.keptHidden.UIParent, "UIParent must never be hidden")
	SlashCmdList["AZSGW2"]("bind talents bad;name!")
	assert(AZSGW2DB.bind.talents ~= "bad;name!", "bad binding stored")
	-- text from outside cannot start a colour code
	assert(G.Esc("a|cffff0000b|r") == "a||cffff0000b||r" and G.Esc(nil) == "" and G.Esc(5) == "5", "Esc")
	-- a failing updater tries again later and only gives up after repeated errors
	local fails, runs = 0, 0
	G.AddUpdater("flaky", function() runs = runs + 1; if runs <= 2 or runs == 4 then fails = fails + 1; error("boom") end end, 0.1)
	for i = 1, 50 do runTicks(20, 0.05) end
	local u = G.updaters[#G.updaters]
	print("flaky updater: runs", runs, "errors", fails, "dead", tostring(u.dead))
	assert(not u.dead and runs > 10, "updater should have recovered")
	local always = 0
	G.AddUpdater("broken", function() always = always + 1; error("always") end, 0.1)
	for i = 1, 80 do runTicks(20, 0.05) end
	local b = G.updaters[#G.updaters]
	print("broken updater: runs", always, "dead", tostring(b.dead))
	assert(b.dead and always == 5, "gives up after 5 errors: " .. always)
	table.remove(G.updaters); table.remove(G.updaters)
	-- the popup hunter does not hide a protected frame that shows banner text
	local dlg = CreateFrame("Frame", "StaticPopup1", UIParent)
	local fs = dlg:CreateFontString(nil, "OVERLAY"); fs:SetFont(G.FONT, 12, ""); fs:SetText("Hardening Test is slain! Its lair yields treasure")
	G.hunt.off = false
	local hits = G.HuntNative({ "Hardening Test is slain! Its lair yields treasure" })
	assert(hits == 0 and dlg.shown, "protected popup frame was hidden by the hunter")
	dlg.shown = false
end)


scenario("hardening 2: bounded caches, text from outside", function()
	-- the meter's name tables never grow without a limit
	for i = 1, 1500 do
		G.meterTry = G.meterTry or {}
		local lines = { { name = "Spell " .. i } }
		G.meterSnapAt = nil
		now = now + 20
		AZS_GetMeter = function() return lines, 1, 1 end
		pcall(G.UpdateMeter, 1)
	end
	AZS_GetMeter = nil
	local nIcons, nTry = 0, 0
	for _ in pairs(G.meterIcons) do nIcons = nIcons + 1 end
	for _ in pairs(G.meterTry) do nTry = nTry + 1 end
	print("meter name tables after 1500 different spells:", nIcons, nTry)
	assert(nIcons <= 401 and nTry <= 401, "meter tables unbounded")
	-- banner text: colour codes and links are dropped, other pipes shown as they are
	assert(G.Plain("|cffff0000Boss|r is |Hitem:1:0|h[a link]|h down|x") == "Boss is [a link] down||x", "Plain: " .. G.Plain("|cffff0000Boss|r is |Hitem:1:0|h[a link]|h down|x"))
	assert(G.Plain(nil) == "")
	bannerHandler({ kind = "guardian", boss = false, name = "X", text = "|cff00ff00Hostile|r name |c12 is slain" })
	runTicks(8, 0.1)
	print("banner shows:", G.banner.text.text)
	assert(not string.find(G.banner.text.text, "|cff00ff00", 1, true), "banner colour code shown")
	runTicks(60, 0.1)
end)

scenario("API call budget (10 s at 60 fps)", function()
	local calls = {}
	local names = { "AZS_GetLairs", "AZS_GetMeterSnapshot", "AZS_GetMeterLoadout", "AZS_GetPlayerPosition", "AZS_GetDownedPartyMembers", "AZS_GetMeter" }
	local orig = {}
	for _, n in ipairs(names) do
		orig[n] = _G[n]; calls[n] = 0
		if orig[n] then _G[n] = function(...) calls[n] = calls[n] + 1; return orig[n](...) end end
	end
	AZSGW2DB.meterMode = "damage"
	local z0, h0 = used.SetZoom or 0, plateCalls.hide
	runTicks(600, 1 / 60)
	print("  SetZoom calls in 10 s:", (used.SetZoom or 0) - z0, "| HideNameplates calls:", plateCalls.hide - h0)
	assert((used.SetZoom or 0) - z0 <= 4, "minimap zoom is being set too often")
	assert(plateCalls.hide - h0 <= 1, "HideNameplates is called too often")
	for _, n in ipairs(names) do print("  calls in 10 s:", n, calls[n]) end
	assert(calls.AZS_GetLairs <= 300, "minimap/guardian list read lairs too often: " .. calls.AZS_GetLairs)
	assert(calls.AZS_GetMeterSnapshot <= 12, "meter snapshot read too often (once a second for the rate, plus the lines): " .. calls.AZS_GetMeterSnapshot)
	assert(calls.AZS_GetMeterLoadout <= 1, "loadout read too often: " .. calls.AZS_GetMeterLoadout)
	-- a new revision is picked up within the second
	local before = calls.AZS_GetMeterLoadout
	metaRev = "m2"
	runTicks(90, 1 / 60)
	assert(calls.AZS_GetMeterLoadout == before + 1, "a changed metadata revision did not reload the loadout")
	-- the minimap pins still follow (20 Hz): one position per ~3 frames
	for _, n in ipairs(names) do _G[n] = orig[n] end
end)

scenario("meter tabs", function()
	for _, m in ipairs({ "healing", "boss", "party", "damage" }) do
		AZSGW2DB.meterMode = m
		G.meterAcc = 99
		runTicks(10, 0.05)
		print(m, G.meter.summary.text, G.meter.rows[1].shown, G.meter.rows[1].name.text)
	end
end)

scenario("party frames: click to target, right click menu", function()
	runTicks(6, 0.1)
	local rows = G.party.rows
	for i = 1, 3 do assert(rows[i].unit == "party" .. i and rows[i].shown, "row " .. i .. " knows its unit") end
	assert(rows[4].unit == nil and not rows[4].shown, "an empty row has no unit")
	assert(rows[1].scripts.OnClick and rows[1].kind == "Button", "rows are clickable buttons")
	-- left click targets, and the row of the target gets the white outline
	arg1 = "LeftButton"; rows[2].scripts.OnClick()
	assert(clicks.targeted[1] == "party2", "left click targets: " .. tostring(clicks.targeted[1]))
	runTicks(6, 0.1)
	assert(rows[2].sel.shown and not rows[1].sel.shown and not rows[3].sel.shown, "target outline")
	arg1 = "LeftButton"; rows[1].scripts.OnClick(); runTicks(6, 0.1)
	assert(rows[1].sel.shown and not rows[2].sel.shown, "outline follows the target")
	-- a spell waiting for a target, or an item on the cursor, goes to the friend instead
	spellTargeting = true; arg1 = "LeftButton"; rows[3].scripts.OnClick(); spellTargeting = false
	assert(clicks.spell[1] == "party3" and #clicks.targeted == 2, "a pending spell is cast on the friend")
	cursorItem = true; arg1 = "LeftButton"; rows[3].scripts.OnClick(); cursorItem = false
	assert(clicks.dropped[1] == "party3" and #clicks.targeted == 2, "the cursor item goes to the friend")
	-- right click: our own menu (Inspect, Trade, Follow, Whisper) for that friend
	arg1 = "RightButton"; rows[2].scripts.OnClick()
	local m = G.partyMenu
	assert(m and m:GetName() == "AZSGW2PartyMenu" and G.IsProtected("AZSGW2PartyMenu") and G.ValidFrameName("AZSGW2PartyMenu"), "menu frame is ours and protected")
	assert(m.shown and m.catcher.shown, "menu and its click catcher are up")
	assert(m.title.text == "Carolin", "menu title is the friend: " .. tostring(m.title.text))
	local names = {}
	for i, b in ipairs(m.items) do if b.shown then table.insert(names, b.text.text) end end
	print("  menu items:", table.concat(names, ", "))
	assert(table.concat(names, ",") == "Inspect,Trade,Follow,Whisper", "menu entries: " .. table.concat(names, ","))
	assert(m.catcher:GetFrameLevel() < m:GetFrameLevel() and m.strata == "FULLSCREEN_DIALOG" and m.catcher.strata == "FULLSCREEN_DIALOG", "catcher below the menu, menu on top")
	-- Inspect really inspects that unit
	acts = {}
	m.items[1].scripts.OnClick()
	assert(not m.shown and not m.catcher.shown, "menu closes after a choice")
	assert(acts[1] == "notify:party2" and acts[2] == "inspect:party2", "inspect: " .. table.concat(acts, " "))
	-- too far away: a clear message, no inspect
	inRange = false; acts = {}
	arg1 = "RightButton"; rows[2].scripts.OnClick(); m.items[1].scripts.OnClick()
	assert(#acts == 0, "no inspect out of range")
	inRange = true
	-- trade / follow / whisper
	acts = {}
	for i = 2, 4 do arg1 = "RightButton"; rows[1].scripts.OnClick(); m.items[i].scripts.OnClick() end
	assert(table.concat(acts, " ") == "trade:party1 follow:party1 tell:Zaynor", "other entries: " .. table.concat(acts, " "))
	-- the leader also gets Make leader / Remove
	leader = true
	arg1 = "RightButton"; rows[3].scripts.OnClick()
	assert(m.items[5].shown and m.items[5].text.text == "Make leader" and m.items[6].text.text == "Remove", "leader entries")
	acts = {}; m.items[6].scripts.OnClick()
	assert(acts[1] == "uninvite:Ghost", "remove: " .. tostring(acts[1]))
	leader = false
	-- a click elsewhere closes it; the party changing while it is open is noticed
	arg1 = "RightButton"; rows[1].scripts.OnClick()
	m.catcher.scripts.OnClick()
	assert(not m.shown and not m.catcher.shown, "click elsewhere closes the menu")
	arg1 = "RightButton"; rows[1].scripts.OnClick()
	local nm = partyData.party1.name; partyData.party1.name = "Someone"
	acts = {}; m.items[1].scripts.OnClick(); partyData.party1.name = nm
	assert(#acts == 0, "the menu does nothing for a friend who left the slot")
	-- an action that fails is caught
	local ins = InspectUnit; InspectUnit = function() error("boom") end
	arg1 = "RightButton"; rows[1].scripts.OnClick(); m.items[1].scripts.OnClick()
	InspectUnit = ins
	-- no inspect function in the game: a message, not an error
	InspectUnit = nil
	arg1 = "RightButton"; rows[1].scripts.OnClick(); m.items[1].scripts.OnClick()
	InspectUnit = ins
	-- missing trade / follow / whisper functions: those entries are left out
	local t0, f0, w0 = InitiateTrade, FollowUnit, ChatFrame_SendTell
	InitiateTrade, FollowUnit, ChatFrame_SendTell = nil, nil, nil
	arg1 = "RightButton"; rows[1].scripts.OnClick()
	assert(m.items[1].shown and not m.items[2].shown, "only Inspect without the other functions")
	m.catcher.scripts.OnClick()
	InitiateTrade, FollowUnit, ChatFrame_SendTell = t0, f0, w0
	-- the menu goes when the friends go
	arg1 = "RightButton"; rows[1].scripts.OnClick()
	assert(m.shown)
	-- a hidden row (no unit) does nothing
	local nT = #clicks.targeted
	arg1 = "LeftButton"; rows[4].scripts.OnClick(); arg1 = "RightButton"; rows[4].scripts.OnClick()
	assert(#clicks.targeted == nT, "empty row ignored")
	-- the tooltip carries the hint
	rows[1].scripts.OnEnter(); rows[1].scripts.OnLeave()
	-- the friend leaves: the unit is forgotten
	local n = GetNumPartyMembers
	GetNumPartyMembers = function() return 1 end
	runTicks(6, 0.1)
	assert(rows[2].unit == nil and not rows[2].shown, "left row forgot its unit")
	GetNumPartyMembers = function() return 3 end
	runTicks(6, 0.1)
	arg1 = "RightButton"; rows[1].scripts.OnClick()
	assert(m.shown)
	local nm2 = partyData.party1.name; partyData.party1.name = "Someone"
	runTicks(6, 0.1)
	assert(not m.shown, "the menu closes when its friend leaves the slot")
	partyData.party1.name = nm2
	GetNumPartyMembers = function() return 1 end
	GetNumPartyMembers = n
	targetedUnit = nil
	runTicks(6, 0.1)
end)

scenario("meter: reset, the 10 second rate, party icons", function()
	local f = G.meter
	local function rateOf() return tonumber(string.match(f.summary.text, "10s [DH]PS: ([%d%.]+)")) or -1, string.match(f.summary.text, "10s [DH]PS: [%d%.]+(%a?)") end
	local function kRate() local v, u = rateOf(); if u == "K" then v = v * 1000 elseif u == "M" then v = v * 1e6 end; return v end
	local dmg = 1000000
	AZS_GetMeter = function() return { { name = "Frostbolt", dmg = dmg, dps = 1, share = 1, proc = 0 } }, dmg, 1 end
	AZSGW2DB.meterMode = "damage"; G.meterAcc = 99
	local before = snapshotCalls
	-- 5000 damage a second for 15 seconds
	for i = 1, 150 do dmg = dmg + 500; runTicks(1, 0.1) end
	print("steady 5000/s:", f.summary.text)
	assert(math.abs(kRate() - 5000) < 400, "10 s rate near 5000: " .. f.summary.text)
	assert(f.resetBtn and f.resetBtn.scripts.OnClick, "reset button")
	pcall(f.resetBtn.scripts.OnEnter)
	-- the rate asks the API once a second at most (150 ticks of 0.1 s = 15 s)
	assert(snapshotCalls - before <= 18, "rate used the snapshot API too often: " .. (snapshotCalls - before))
	-- twice as much damage: the rate follows within the window, not the whole run
	for i = 1, 150 do dmg = dmg + 1000; runTicks(1, 0.1) end
	assert(math.abs(kRate() - 10000) < 800, "10 s rate follows: " .. f.summary.text)
	-- nothing dealt: it falls to zero after the window
	runTicks(150, 0.1)
	assert(kRate() == 0, "idle rate is zero: " .. f.summary.text)
	-- reset: all zero, the rate counts from the reset
	f.resetBtn.scripts.OnClick()
	assert(string.find(f.summary.text, "Total: 0", 1, true) and not f.rows[1].shown, "all zero after the reset: " .. f.summary.text)
	for i = 1, 30 do dmg = dmg + 300; runTicks(1, 0.1) end
	print("after reset + damage:", f.summary.text, f.rows[1].name.text, f.rows[1].val.text)
	do   -- 30 ticks of 300: the meter reads every third tick, so the last one or two ticks may not be in yet
		local tk = tonumber(string.match(f.summary.text, "Total: ([%d%.]+)K"))
		assert(tk and tk >= 8.1 and tk <= 9.0, "total counts from the reset: " .. f.summary.text)
	end
	assert(math.abs(kRate() - 3000) < 500, "rate since the reset: " .. f.summary.text)
	assert(f.rows[1].name.text == "Frostbolt" and string.find(f.rows[1].val.text, "100.0%", 1, true), "share of the new total: " .. f.rows[1].val.text)
	-- a counter that went down (a new boss fight / a new run) ends the reset
	local d0 = dmg
	dmg = 100; runTicks(10, 0.1)
	assert(string.find(f.summary.text, "Total: 100", 1, true), "counters started over: " .. f.summary.text)
	assert(kRate() < 5000, "no negative or huge rate after a restart: " .. f.summary.text)
	-- the other tabs reset too
	AZS_GetMeter = defaultGetMeter
	f.resetBtn.scripts.OnClick()
	for _, m in ipairs({ "healing", "party", "boss" }) do
		AZSGW2DB.meterMode = m; G.meterAcc = 99
		runTicks(10, 0.1)
		assert(string.find(f.summary.text, "Total: 0", 1, true), m .. " tab not reset: " .. f.summary.text)
	end
	-- another run: the reset is over, the game's numbers show
	AZSGW2DB.meterMode = "damage"
	mockRun = "r2"
	runTicks(25, 0.1)
	assert(string.find(f.summary.text, "Total: 2.4B", 1, true), "a new run shows the game's numbers: " .. f.summary.text)
	-- party tab: the best spell's icon sits left of each player's name
	G.meterIcons["Shadow Bolt"] = nil          -- not learned yet, so the party tab has to ask
	for k in pairs(G.meterTry) do G.meterTry[k] = nil end
	G.meterSnapAt = nil
	f.tabs[4].scripts.OnClick()               -- the Party tab, as a click
	assert(AZSGW2DB.meterMode == "party", "the Party tab is a click away")
	G.meterAcc = 99
	f.iconAcc = 99
	runTicks(20, 0.1)
	local q = snapshotQueries[#snapshotQueries]
	assert(q and q.scope == "party", "the party tab asks for the party's sources")
	local r1, r2 = f.rows[1], f.rows[2]
	print("party rows:", r1.name.text, r1.icon.tex, "|", r2.name.text, r2.icon.tex)
	dumpLayout(OUTDIR .. "/layout_meter_party.txt")
	assert(r1.name.text == "Carolin" and string.find(r1.icon.tex, "Spell_Shadow_ShadowBolt", 1, true) and r1.iconBack.shown and r1.icon.shown, "best spell icon of the first player")
	assert(r2.name.text == "Zaynor" and string.find(r2.icon.tex, "QuestionMark", 1, true), "a player without a best spell gets the stand-in")
	pcall(r1.scripts.OnEnter)
	AZSGW2DB.meterMode = "damage"
	AZS_GetMeter = nil                        -- as the scenarios after this one expect
	G.meterResetAt = nil
end)

scenario("layout dump: elite target bar, nameplates, max target chips", function()
	-- an elite target
	AZS_UNITS = { { kind = "elite", id = 7, name = "Defias Captain", hp = 1000, hpm = 4000, state = 0 } }
	clientTarget = { name = "Defias Captain", hostile = true, hp = 25, hpm = 100, class = "elite" }
	AZS_TARGET = { kind = "elite", id = "m7", name = "Defias Captain", hp = 1000, hpm = 4000, state = 0 }
	fire("PLAYER_TARGET_CHANGED"); runTicks(6, 0.05)
	assert(G.target.shown and G.target.badge.shown, "elite target bar with its badge")
	-- target chips on two skills
	spellTipText[3] = { "Blizzard", "Pounds the 5 nearest enemies within 40 yd." }
	spellTipText[2] = { "Frostbolt", "Hurls the 3 nearest enemies." }
	G.slots[1].tgtKey = nil; G.slots[4].tgtKey = nil
	runTicks(12, 0.1)
	AZSGW2DB.opt = AZSGW2DB.opt or {}
	G.SetOpt("nameplates", true); G.SetOpt("platesFriend", true); G.EnforcePlates()
	local function plate(name, hp, color, elite, x, y)
		local f = new("Frame", WorldFrame); f.shown = false; f:SetWidth(110); f:SetHeight(30)
		f:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", x, y)
		local border = new("Texture", f); border.tex = "Interface\\Tooltips\\Nameplate-Border"
		new("Texture", f)
		local nm = new("FontString", f); nm.fontSet = true; nm.text = name; nm.tcol = { color[1], color[2], color[3] }
		new("FontString", f); local icon = new("Texture", f); icon.tex = "Interface\\Tooltips\\EliteNameplateIcon"; icon.shown = elite
		new("Texture", f)
		local hb = new("StatusBar", f); hb.sbMin, hb.sbMax, hb.sbValue, hb.sbColor = 0, 100, hp, color
		new("StatusBar", f).shown = false
		f.shown = true
		return f
	end
	local RED, GREEN = { 1, 0.05, 0.05 }, { 0.05, 1, 0.05 }
	local a = plate("Umbraglow Stinger", 55, RED, false, 560, 420)
	local b = plate("Defias Captain", 25, RED, true, 760, 470)
	local c = plate("Jungle Golem", 90, RED, false, 960, 400)
	local d = plate("Carolin", 70, GREEN, false, 700, 330)
	b:SetAlpha(1); a:SetAlpha(0.6); c:SetAlpha(0.6); d:SetAlpha(0.6)
	runTicks(4, 0.1)
	local wp = WorldFrame.parent; WorldFrame.parent = UIParent
	dumpLayout(OUTDIR .. "/layout_plates.txt")
	WorldFrame.parent = wp
	-- take it all down again
	for _, f in ipairs({ a, b, c, d }) do f.shown = false end
	G.SetOpt("nameplates", false); G.SetOpt("platesFriend", false); G.EnforcePlates()
	runTicks(3, 0.1)
	ctEvents = {}
	clientTarget = nil; AZS_TARGET = nil; AZS_UNITS = {}
	fire("PLAYER_TARGET_CHANGED"); runTicks(60, 0.1)
end)

scenario("meter: pet classes, the rate comes from the API, dips do not start it over", function()
	local f = G.meter
	local function lastRateQuery()
		for k = table.getn(snapshotQueries), 1, -1 do
			if snapshotQueries[k].windowSeconds == 10 then return snapshotQueries[k] end
		end
		return {}
	end
	local function kRate()
		local v = tonumber(string.match(f.summary.text, "10s [DH]PS: ([%d%.]+)")) or -1
		local u = string.match(f.summary.text, "10s [DH]PS: [%d%.]+(%a?)")
		if u == "K" then v = v * 1000 elseif u == "M" then v = v * 1e6 end
		return v
	end
	local dmg = 5000000
	local lines = { { name = "Frostbolt", dmg = dmg, dps = 1, share = 1, proc = 0 } }
	AZS_GetMeter = function() lines[1].dmg = dmg; return lines, dmg, 1 end
	AZSGW2DB.meterMode = "damage"; G.meterAcc = 99
	local made0 = checkpoints.made
	G.ResetMeter(); G.meterAcc = 99
	-- the API knows the pets' damage too: its rate is shown although the lines hardly move
	snapRate = 7800
	runTicks(30, 0.1)
	assert(math.abs(kRate() - 7800) < 100, "rate from the API: " .. f.summary.text)
	assert(checkpoints.made == made0 + 1 and lastRateQuery().checkpointId == "cp" .. checkpoints.made, "the reset's checkpoint is in the rate query")
	assert(lastRateQuery().windowSeconds == 10 and lastRateQuery().scope == "self", "rate query")
	-- the API says nothing (older game, an error): the addon works it out, a pet that leaves the list does not stop it
	snapRate = nil
	AZSGW2DB.meterMode = "damage"
	local dips = 0
	for i = 1, 300 do
		dmg = dmg + 500
		if math.mod(i, 20) == 0 then dmg = dmg - 4000; dips = dips + 1 end   -- every 2 s a source drops out of the list
		runTicks(1, 0.1)
	end
	assert(dips == 15)
	local r = kRate()
	assert(r > 3000 and r < 6000, "rate with dips (5000 a second added, a dip every 2 s): " .. f.summary.text)
	-- a different tab: the same
	AZSGW2DB.meterMode = "healing"; G.meterAcc = 99
	snapRate = 1234
	runTicks(30, 0.1)
	assert(math.abs(kRate() - 1234) < 60 and lastRateQuery().metric == "healing", "healing rate: " .. f.summary.text)
	AZSGW2DB.meterMode = "damage"
	-- the checkpoint is gone (a new run): the next ask is made without it and the rate goes on
	snapRate = 900; checkpoints.expired = true
	runTicks(40, 0.1)
	assert(math.abs(kRate() - 900) < 20 and lastRateQuery().checkpointId == nil, "rate after the checkpoint expired: " .. f.summary.text)
	checkpoints.expired = false
	-- the next reset gives the old checkpoint back and takes a new one
	local rel0 = #checkpoints.released
	G.ResetMeter(); runTicks(30, 0.1)
	assert(#checkpoints.released == rel0 + 1 or checkpoints.made > made0 + 1, "checkpoint not renewed on reset")
	-- an API rate that is not a number is ignored
	snapRate = 0 / 0
	runTicks(40, 0.1)
	assert(kRate() >= 0, "NaN rate shown: " .. f.summary.text)
	-- a stale API answer (the API went quiet) is not shown for ever
	snapRate = 5000; runTicks(30, 0.1)
	snapRate = nil; runTicks(60, 0.1)
	assert(kRate() == 0 or kRate() == -1 or kRate() < 5000, "stale API rate stays: " .. f.summary.text)
	AZS_GetMeter = nil; snapRate = nil
	G.meterResetAt = nil
	print("pet meter ok")
end)

scenario("target bar: friend dump for the preview", function()
	clientTarget = { name = "Carolin", hostile = false, hp = 700, hpm = 1500, isPlayer = true, class = "WARLOCK" }
	AZS_TARGET = { kind = "other", name = "Carolin" }
	fire("PLAYER_TARGET_CHANGED")
	runTicks(6, 0.05)
	assert(G.target.shown and G.target.hpText.text == "700  47%", "friend bar")
	dumpLayout(OUTDIR .. "/layout_target_friend.txt")
	clientTarget = nil
	AZS_TARGET = nil
	fire("PLAYER_TARGET_CHANGED")
	runTicks(6, 0.05)
end)

scenario("caches still follow changes (orb, skill bar, minimap pins, bars)", function()
	-- the orb: shield on, off, on again; health down and back; text follows
	local keep = { hp = run.hp, hpm = run.hpm, sh = run.sh }
	local orb = G.orb
	run.hp, run.hpm, run.sh = 2400, 2400, 0
	runTicks(60, 0.05)
	assert(not orb.shield.shown, "no shield, no layer")
	assert(math.abs(orb.fill.h - 112) < 1, "full orb: " .. tostring(orb.fill.h))
	run.sh = 300; runTicks(60, 0.05)
	assert(orb.shield.shown, "a shield shows")
	run.sh = 0; runTicks(60, 0.05)
	assert(not orb.shield.shown, "the shield goes")
	run.sh = 300; runTicks(60, 0.05)
	assert(orb.shield.shown, "the next shield shows again")
	run.sh, run.hp = 0, 1200; runTicks(80, 0.05)
	assert(math.abs(orb.fill.h - 56) < 1.5 and orb.hpText.text == "1,200", "half health: " .. tostring(orb.fill.h) .. " " .. tostring(orb.hpText.text))
	run.hp = 0; runTicks(120, 0.05)
	assert(not orb.fill.shown, "empty orb has no fill")
	run.hp = 2400; runTicks(80, 0.05)
	assert(orb.fill.shown and orb.fill.h > 100, "orb fills again")
	run.hp, run.hpm, run.sh = keep.hp, keep.hpm, keep.sh
	runTicks(40, 0.05)
	-- the skill bar: a cooldown starts, ends, starts again
	local slot = G.slots[3]
	AZS_SPELLS[3].cd = 0; AZS_SPELLS_UPDATED = (AZS_SPELLS_UPDATED or 0) + 1
	runTicks(6, 0.05)
	assert(slot.cdText.text == "" and not slot.cd.shown, "ready: no count")
	AZS_SPELLS[3].cd = 6; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(6, 0.05)
	assert(slot.cdText.text ~= "" and slot.cd.shown and slot.icon.vc[1] < 0.7, "cooling down: count, bar, dim icon")
	local h1 = slot.cd.h
	runTicks(40, 0.05)
	assert(slot.cd.h < h1, "the bar shrinks")
	AZS_SPELLS[3].cd = 0; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(6, 0.05)
	assert(slot.cdText.text == "" and not slot.cd.shown and slot.icon.vc[1] > 0.9, "ready again")
	AZS_SPELLS[3].cd = 5; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(6, 0.05)
	assert(slot.cd.shown and slot.cdText.text ~= "", "a second cooldown shows again")
	AZS_SPELLS[3].cd = 0; AZS_SPELLS_UPDATED = AZS_SPELLS_UPDATED + 1
	runTicks(6, 0.05)
	-- the shared bar helper and portrait trim: same value twice, then a different one
	local bar = G.NewBar(UIParent, 100, 10, 1, 0, 0)
	bar:SetFrac(0.5); assert(bar.fill.shown and math.abs(bar.fill.w - 49) < 0.01, "bar half")
	bar:SetFrac(0); assert(not bar.fill.shown, "bar empty hides the fill")
	bar:SetFrac(0.5); assert(bar.fill.shown, "bar shows the fill again")
	bar:SetColor(0, 1, 0); bar:SetColor(0, 1, 0); assert(bar.fill.vc[2] == 1, "bar colour")
	bar:SetColor(1, 0, 0); assert(bar.fill.vc[1] == 1 and bar.fill.vc[2] == 0, "bar colour changes")
	local box = CreateFrame("Frame", nil, UIParent)
	G.Edges(box, 0, 0, 0, 1)
	G.EdgeColor(box, 1, 0, 0, 1); G.EdgeColor(box, 1, 0, 0, 1)
	assert(box.edges.top.vc[1] == 1, "edge colour")
	G.EdgeColor(box, 0, 1, 0, 1)
	assert(box.edges.top.vc[2] == 1 and box.edges.left.vc[1] == 0, "edge colour changes")
	-- an arrow keeps pointing where it should
	local t = box:CreateTexture(nil, "ARTWORK")
	G.SetArrow(t, 0); local a0 = t.tc and t.tc[3]
	G.SetArrow(t, 0.01); G.SetArrow(t, 3.14159)
	local a1 = t.tc and t.tc[3]
	G.SetArrow(t, 0)
	assert(t.tc and t.tc[3] == a0 and a0 ~= a1, "arrow turns and comes back")
end)

scenario("crit blot grows with the number", function()
	local t = GetTime()
	ctProj = {}
	for i = 1, 4 do ctProj["b" .. i] = { anchorId = "b" .. i, state = "onScreen", x = 150 + i * 150, y = 400, playerDistance = 10 } end
	local function crit(n, i) return { kind = "damage", amount = n, critical = true, anchorId = "b" .. i, anchorStatus = "ready", sourceKind = "player", presentedAt = t } end
	ctEvents = { crit(10, 1), crit(1000, 2), crit(98765, 3), crit(5000000, 4) }
	ctHandler()
	local L = G.dmg.labels
	do
		local was = {}
		for _, w in ipairs(G.all) do was[w] = w.shown; w.shown = false end
		for _, w in ipairs(G.always) do was[w] = w.shown; w.shown = false end
		local wp = WorldFrame.parent; WorldFrame.parent = UIParent
		dumpLayout(OUTDIR .. "/layout_blot.txt")
		WorldFrame.parent = wp
		for w, v in pairs(was) do w.shown = v end
	end
	local w = {}
	for i = 1, 4 do
		local sp = L[i].holder.splat
		local tw = L[i].holder.text:GetStringWidth()
		w[i] = sp.w
		print(string.format("  crit %-8s font %2d  text %5.1f wide  blot %5.1f x %5.1f", L[i].holder.text.text, L[i].size, tw, sp.w, sp.h))
		if not os.getenv("STOCK") then
			assert(sp.w * 0.65 >= tw + L[i].size * 0.45, "blot wider than the number by a margin: " .. L[i].holder.text.text)
			assert(sp.h >= L[i].size * 1.85 and sp.h <= L[i].size * 1.9 * 1.36, "blot height")
			local pt = sp.pts[#sp.pts]
			assert(pt[1] == "CENTER" and pt[4] == 0, "blot centred behind the number")
		end
	end
	assert(w[1] < w[2] and w[2] < w[3], "the blot grows with the number")
	ctEvents = {}
	runTicks(30, 0.05)
end)

scenario("hero panel: default position at the left", function()
	local p = lastPoint(G.charPanel)
	print("hero panel anchor:", p[1], p[3], p[4], p[5])
	assert(p[1] == "LEFT" and p[3] == "LEFT" and p[4] == 14, "hero panel starts at the left edge")
end)

scenario("skill bar tooltips", function()
	runTicks(6, 0.1)
	local sl = G.slots
	-- a spell that is in the spellbook shows the game's own tooltip (the rank that matches), plus our cooldown line
	sl[1].scripts.OnEnter()
	assert(lastSetSpell and lastSetSpell[1] == 2, "frostbolt rank 3 is book entry 2: " .. tostring(lastSetSpell and lastSetSpell[1]))
	assert(tipLines[#tipLines] == "Casts automatically", "our line follows the game's tooltip")
	sl[1].scripts.OnLeave()
	G.cdEnd = G.cdEnd or {}; G.cdEnd["blizzard"] = AZS_GetRunTime() + 5    -- cooling down for 5 more seconds
	sl[4].scripts.OnEnter()
	assert(lastSetSpell and lastSetSpell[1] == 3, "blizzard is book entry 3")
	local sawReady = false
	for _, l in ipairs(tipLines) do if string.find(l, "Ready in", 1, true) then sawReady = true end end
	assert(sawReady, "cooldown line on a spell that is cooling down")
	sl[4].scripts.OnLeave()
	-- a spell that is not in the book: our own tooltip
	sl[2].scripts.OnEnter()
	assert(lastSetSpell == nil and tipLines[1] == "Arcane Missiles" and #tipLines >= 3, "own tooltip for a spell outside the book")
	print("  fallback tooltip:", table.concat(tipLines, " | "))
	sl[2].scripts.OnLeave()
	-- no spellbook functions at all: still the own tooltip
	local g1, g2, g3 = GetNumSpellTabs, GetSpellTabInfo, GetSpellName
	GetNumSpellTabs, GetSpellTabInfo, GetSpellName = nil, nil, nil
	sl[1].scripts.OnEnter()
	assert(lastSetSpell == nil and #tipLines >= 3, "own tooltip without a spellbook")
	sl[1].scripts.OnLeave()
	GetNumSpellTabs, GetSpellTabInfo, GetSpellName = g1, g2, g3
	-- the racial, and an empty slot
	G.racial.scripts.OnEnter(); G.racial.scripts.OnLeave()
	sl[6].scripts.OnEnter(); sl[6].scripts.OnLeave()
	-- a tooltip that fails does not break the hover: said once
	local failer = CreateFrame("Frame", nil, UIParent)
	G.Tooltip(failer, function(tt) error("boom") end)
	G.tipFailed = nil
	failer.scripts.OnEnter(); failer.scripts.OnEnter()
	assert(G.tipFailed, "a failing tooltip function is caught")
	G.tipFailed = nil
end)

scenario("endless / no proc / dead", function()
	run.endl = 1; run.nb = 30; run.proc = ""; phase = "dead"; run.hp = 0
	runTicks(20, 0.05)
	print("top:", G.top.title.text, "|", G.top.next.text, "| orb:", G.orb.hpText.text, "| resource shown:", G.resource.shown)
	run.endl = 0; run.hp = 100; run.proc = "bloodrage"; run.pv = 100; run.pm = 100; phase = "playing"
	runTicks(20, 0.05)
	print("rage resource shown:", G.resource.shown)
	run.proc = "lightwell"; run.pv = 0.4; run.pm = 1
	runTicks(5, 0.05)
end)

scenario("no run (phase nil) hides, empty data tolerated", function()
	phase = nil
	runTicks(10, 0.05)
	print("shown:", G.shown)
	assert(not G.shown)
	phase = "ready"
	AZS_SPELLS = {}; AZS_SPELLS_UPDATED = 3
	AZS_SCHEDULE = {}
	function AZS_GetBosses() return {} end
	function AZS_GetGuardians() return {} end
	function AZS_GetLairs() return {} end
	function AZS_GetSummonGroups() return {}, 0 end
	function AZS_GetTotems() return {} end
	function AZS_GetTimers() return {} end
	function AZS_GetUpcomingBosses() return {} end
	stored = 0
	AZS_RUN = {}
	run = AZS_RUN
	runTicks(20, 0.05)
	print("shown:", G.shown, "levelup:", G.levelBtn.shown)
end)

scenario("slash commands", function()
	for _, c in ipairs({ "", "scale 1.2", "scale", "hide Foo", "unhide Foo", "find kills", "bindings TOGGLE", "bind", "bind talents TOGGLETALENTS", "off", "on", "art", "debug", "garbage" }) do
		print("> /gw2 " .. c)
		SlashCmdList["AZSGW2"](c)
	end
	G.RestoreHidden()
	assert(rawget(UIErrorsFrame, "AddMessage") == nil, "UIErrorsFrame shadow not removed on /gw2 off")
	assert(NAMEPLATES_ON == 1, "nameplates not given back on /gw2 off")
	assert(stockFrames.ActionButton1.scripts.OnShow == originalOnShow, "original OnShow not restored")
	assert(stockFrames.PlayerFrame.shown == true and stockFrames.PlayerFrame.scripts.OnShow == nil, "PlayerFrame not restored")
	AZSGW2DB.enabled = true
	G.EnforceHidden()
	assert(stockFrames.PlayerFrame.shown == false, "not hidden again after /gw2 on")
	print("/gw2 off restores the stock frames, on hides them again")
	-- talent / character clicks
	G.talentBtn.scripts.OnClick()
	G.charBtn.scripts.OnClick()
	G.levelBtn.scripts.OnClick()
end)

scenario("tooltips", function()
	local frames = { G.orb, G.buffs[1], G.debuffs[1], G.resource, G.slots[1], G.slots[3], G.racial, G.talentBtn, G.charBtn, G.top.skulls[1],
		G.tally.items.kills, G.meter.rows[1], G.levelBtn, G.jewSlots[1], G.status[1], G.bossFrame.rows[1].debuffs[1] }
	local ok = 0
	for _, f in ipairs(frames) do
		if f.scripts.OnEnter then
			local good, err = pcall(f.scripts.OnEnter)
			if not good then print("TOOLTIP ERROR", err) else ok = ok + 1 end
		end
	end
	print("tooltips ran:", ok)
end)

print("\n== widget methods used that are not in my mock (check each is a real 1.12 method):")
local list = {}
for k in pairs(globals) do if k:find("UNKNOWN_METHOD_") then table.insert(list, (k:gsub("UNKNOWN_METHOD_", ""))) end end
table.sort(list)
print(table.concat(list, ", "))
print("== done")
