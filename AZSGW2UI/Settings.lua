-- AZS GW2 UI: Settings.lua
-- The round icon on the minimap (left click: settings window)
-- and the settings window, in the style of the hero panel: a list of pages on the left (Interface, Nameplates, Damage, Map &
-- Guardians, Utility), the switches of the page in titled panels on the right, size / unlock / reset under Interface.

local G = AZSGW2;

local W, H = 620, 360;
local NAVW = 142;
local TOP = 48;                     -- under the title line
local PAGEX = 166;                  -- left edge of the page area
local PAGEW = W - PAGEX - 14;
local PAGEH = H - TOP - 14;
local ROWH = 24;
local SECHEAD = 34;                 -- the title of a panel and the line under it

------------------------------------------------------------------------ options

function G.SetScaleAll(s)
	s = G.Clamp(s, 0.6, 1.6);
	AZSGW2DB.scale = s;
	G.ApplyScales();
	for i = 1, table.getn(G.movables) do
		if ( G.movables[i].ov ) then
			G.movables[i].ov:SetScale(s);
		end
	end
end

-- the nameplate options: the GW2 nameplates (Plates.lua) on the game's own plates, which are switched to match
function G.SetPlateOpt(key, on)
	G.SetOpt(key, on);
	G.EnforcePlates();
end

function G.SetMessages(on)
	AZSGW2DB.messages = on and true or false;
	G.QuietMessages(not on);
end

-- a switch of a saved option: what it is called, what it says when the mouse is on it, how it reads and sets the option.
-- sub = a part of the switch above it (drawn indented, and dim while that one is off); needs = a function that says whether
-- the option does anything at the moment (the row is dim when it does not, but it can still be switched).
local function Opt(label, tip, key, after)
	return { label = label, tip = tip,
		get = function() return G.Opt(key); end,
		set = function(v) G.SetOpt(key, v); if ( after ) then after(v); end end };
end

local function PlateOpt(label, tip, key)
	return { label = label, tip = tip,
		get = function() return G.Opt(key); end,
		set = function(v) G.SetPlateOpt(key, v); end };
end

-- the pages: { name, sections = { { title, rows } } }. A section with layout = true holds the size / unlock / reset controls.
local PAGES = {
	{ name = "Interface", sections = {
		{ title = "Frames", rows = {
			Opt("Target bar", "A wide bar with the name and the health of your target, at the top of the screen.", "target"),
			Opt("Party frames", "Health, barrier and buffs of your friends in a co-op game.", "party"),
			Opt("GW2 character panel", "The hero panel opens in place of the game's character window. The game's own window still opens for its other tabs.", "charPanel"),
			Opt("Accessories", "Your amulet, rings and trinkets in a row above the left skills, like the F1 - F5 skills of Guild Wars 2. Move them with Unlock layout.", "accessories"),
		} },
		{ title = "Layout", layout = true },
	} },
	{ name = "Nameplates", sections = {
		{ title = "Enemies", rows = {
			PlateOpt("Enable nameplates", "GW2 style nameplates above the enemies, in place of the game's own.", "nameplates"),
			PlateOpt("Only elites and guardians", "Plates only for elites, guardians and bosses.", "platesElite"),
		} },
		{ title = "Friends", rows = {
			PlateOpt("Enable friendly nameplates", "Plates above your friends, with health and, where the game says it, mana.", "platesFriend"),
			Opt("Show pets and summons", "Friendly plates for pets and summoned creatures too.", "friendPets"),
			{ label = "Hide totems", tip = "No friendly plates for totems.",
				get = function() return not G.Opt("friendTotems"); end,
				set = function(v) G.SetOpt("friendTotems", not v); end },
		} },
	} },
	{ name = "Damage", sections = {
		{ title = "Damage numbers", rows = {
			Opt("GW2 style damage numbers", "Your hits as GW2 style numbers rising from the enemy.", "dmg", function() G.ApplyDamage(); end),
			Opt("Only critical hits", "Show the numbers of critical hits only.", "dmgCrit"),
			Opt("Damage over time ticks", "Show the ticks of damage over time effects too.", "dmgTicks"),
			Opt("Also from pets and summons", "Show what your pets and summons deal too.", "dmgPet"),
			Opt("The game's own damage numbers", "Keep the game's own numbers over the enemies' heads as well.", "dmgNative", function() G.ApplyDamage(); end),
		} },
		{ title = "Meter", rows = {
			Opt("Damage meter", "Who dealt how much: the list at the side of the screen.", "meter"),
		} },
	} },
	{ name = "Map & Guardians", sections = {
		{ title = "Minimap", rows = {
			Opt("GW2 minimap", "The round GW2 minimap in place of the game's.", "minimap", function() G.ApplyMinimap(); end),
			Opt("Caches on the minimap", "A pin for every cache that waits for you.", "pinChest"),
			Opt("Guardians on the minimap", "A pin for every guardian and its lair.", "pinGuard"),
		} },
		{ title = "Guardians", rows = {
			Opt("Guardian list", "The list of guardians and their lairs at the side of the screen.", "guardians"),
			Opt("Direction arrows", "An arrow beside each guardian that points the way to it.", "arrows"),
			Opt("Health bars on the list", "The health of a guardian that fights is a short bar with its percent under its name on the list (off by default). Switching it on takes the guardians off the boss bar, switching it off puts them back; the next switch can be set on its own. Needs the guardian list.", "guardianBars",
				function(v) G.SetOpt("guardianBoss", not v); end),
			Opt("Guardians on the boss bar", "A guardian that fights has its health bar on the boss bar at the top, with the bosses (on by default). Switch it off to see guardians on the list only.", "guardianBoss"),
		} },
	} },
	{ name = "Utility", sections = {
		{ title = "Co-op", rows = {
			Opt("Ally down alert + arrow", "When a friend falls: a message with an arrow and the distance, and a marker over the body.", "revive"),
			Opt("Mark the party in co-op games", "Puts the game's raid icons on the friends (and you) when you join. Needs the leader or a solo game.", "markAllies"),
		} },
		{ title = "Skills", rows = {
			Opt("Max targets, on the skills", "The most enemies a skill can hit, on its icon.", "hits"),
		} },
		{ title = "Game", rows = {
			{ label = "The game's centre-screen messages", tip = "The game's own big messages in the middle of the screen (off by default: the banners of this UI say the same).",
				get = function() return AZSGW2DB.messages and true or false; end,
				set = function(v) G.SetMessages(v); end },
		} },
	} },
};

-- the rows that are a part of another switch, and when that one does nothing
local DEPENDS = {
	["Only elites and guardians"] = function() return G.Opt("nameplates"); end,
	["Show pets and summons"] = function() return G.Opt("platesFriend"); end,
	["Hide totems"] = function() return G.Opt("platesFriend"); end,
	["Only critical hits"] = function() return G.Opt("dmg"); end,
	["Damage over time ticks"] = function() return G.Opt("dmg"); end,
	["Also from pets and summons"] = function() return G.Opt("dmg"); end,
	["Caches on the minimap"] = function() return G.Opt("minimap"); end,
	["Guardians on the minimap"] = function() return G.Opt("minimap"); end,
	["Direction arrows"] = function() return G.Opt("guardians"); end,
	["Health bars on the list"] = function() return G.Opt("guardians"); end,
};
local SUBS = {
	["Only elites and guardians"] = true, ["Show pets and summons"] = true, ["Hide totems"] = true,
	["Only critical hits"] = true, ["Damage over time ticks"] = true, ["Also from pets and summons"] = true,
	["Caches on the minimap"] = true, ["Guardians on the minimap"] = true,
	["Direction arrows"] = true, ["Health bars on the list"] = true,
};

------------------------------------------------------------------------ window

local function NewCheck(parent, row, x, y, w)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(w);
	b:SetHeight(ROWH - 2);
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	local hl = b:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture(G.WHITE);
	hl:SetVertexColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 0.07);
	hl:SetAllPoints(b);
	local box = CreateFrame("Frame", nil, b);
	box:SetWidth(16);
	box:SetHeight(16);
	box:SetPoint("LEFT", b, "LEFT", 4, 0);
	local bg = G.Solid(box, "BACKGROUND", 0.02, 0.02, 0.03, 1);
	bg:SetAllPoints(box);
	G.Edges(box, G.GOLD[1], G.GOLD[2], G.GOLD[3], 1, 1, "BORDER");
	local mark = G.Solid(box, "ARTWORK", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
	mark:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3);
	mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3);
	b.mark = mark;
	b.box = box;
	b.text = G.TextS(b, 12, "LEFT");
	b.text:SetPoint("LEFT", b, "LEFT", 28, 0);
	b.text:SetText(row.label);
	b.row = row;
	b.Refresh = function(self)
		local on = self.row.get() and true or false;
		if ( on ) then
			self.mark:Show();
		else
			self.mark:Hide();
		end
		-- a part of another switch is dim while that one is off (it can still be switched)
		local live = true;
		local need = DEPENDS[self.row.label];
		if ( need ) then
			live = need() and true or false;
		end
		if ( self.live ~= live ) then
			self.live = live;
			if ( live ) then
				self.text:SetTextColor(0.93, 0.93, 0.95);
				self.mark:SetVertexColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
			else
				self.text:SetTextColor(0.52, 0.52, 0.56);
				self.mark:SetVertexColor(0.55, 0.50, 0.36, 1);
			end
		end
	end;
	b:SetScript("OnClick", function()
		b.row.set(not b.row.get());
		G.RefreshSettings();
	end);
	G.Tooltip(b, function(tt)
		tt:AddLine(b.row.label, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		if ( b.row.tip ) then
			tt:AddLine(b.row.tip, 0.82, 0.82, 0.86, 1);
		end
	end, "ANCHOR_RIGHT");
	return b;
end

local function NewButton(parent, text, w, point, x, y, onClick)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(w);
	b:SetHeight(22);
	b:SetPoint(point, parent, point, x, y);
	G.Panel(b, 0.9);
	b.text = G.Text(b, 11, "CENTER");
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0);
	b.text:SetText(text);
	b:SetScript("OnClick", onClick);
	b:SetScript("OnEnter", function()
		G.EdgeColor(b, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
	end);
	b:SetScript("OnLeave", function()
		G.EdgeColor(b, 0.50, 0.41, 0.25, 0.95);
	end);
	return b;
end

-- a titled panel of the page: the title in gold with a line under it, like "Attributes" in the hero panel
local function NewSection(page, title, y, height)
	local p = CreateFrame("Frame", nil, page);
	p:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y);
	p:SetWidth(PAGEW);
	p:SetHeight(height);
	G.Panel(p, 0.5);
	local t = G.Text(p, 13, "LEFT");
	t:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -9);
	t:SetText(title);
	t:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	local line = G.Band(p, "ARTWORK", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.8);
	line:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -28);
	line:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -28);
	line:SetHeight(1);
	return p;
end

local LAYOUTH = SECHEAD + 36 + 32 + 40;

-- size, unlock and reset (the page "Interface")
local function BuildLayout(f, panel)
	local st = G.TextS(panel, 12, "LEFT");
	st:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -SECHEAD - 9);
	st:SetText("Size of everything");
	st:SetTextColor(0.93, 0.93, 0.95);
	f.scaleText = G.Text(panel, 11, "CENTER");
	f.scaleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 190, -SECHEAD - 9);
	f.scaleText:SetWidth(50);
	local function Step(d)
		G.SetScaleAll(math.floor((AZSGW2DB.scale + d) * 100 + 0.5) / 100);
		f.scaleText:SetText(string.format("%d%%", math.floor(AZSGW2DB.scale * 100 + 0.5)));
	end
	NewButton(panel, "-", 22, "TOPLEFT", 164, -SECHEAD - 5, function() Step(-0.05); end);
	NewButton(panel, "+", 22, "TOPLEFT", 244, -SECHEAD - 5, function() Step(0.05); end);
	f.unlock = NewButton(panel, "Unlock layout", 150, "TOPLEFT", 14, -SECHEAD - 36 - 2, function()
		G.ToggleUnlock();
	end);
	NewButton(panel, "Reset positions", 150, "TOPLEFT", 172, -SECHEAD - 36 - 2, function()
		G.ResetPositions();
	end);
	local hint = G.Text(panel, 9, "LEFT");
	hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -SECHEAD - 36 - 32);
	hint:SetWidth(PAGEW - 28);
	hint:SetHeight(24);
	hint:SetTextColor(0.65, 0.65, 0.68);
	hint:SetText("Unlocked: drag a gold box to move it, its corner or the mouse wheel to resize it, right click puts its size back.");
	f.hint = hint;
end

local function NewTab(nav, name, i, onClick)
	local t = CreateFrame("Button", nil, nav);
	t:SetWidth(NAVW - 12);
	t:SetHeight(30);
	t:SetPoint("TOPLEFT", nav, "TOPLEFT", 6, -8 - ( i - 1 ) * 33);
	local hl = t:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture(G.WHITE);
	hl:SetVertexColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 0.07);
	hl:SetAllPoints(t);
	t.back = G.Solid(t, "BACKGROUND", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.20);
	t.back:SetAllPoints(t);
	t.back:Hide();
	t.stripe = G.Solid(t, "ARTWORK", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
	t.stripe:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0);
	t.stripe:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0);
	t.stripe:SetWidth(3);
	t.stripe:Hide();
	t.text = G.Text(t, 12, "LEFT");
	t.text:SetPoint("LEFT", t, "LEFT", 14, 0);
	t.text:SetText(name);
	t.Select = function(self, on)
		if ( on ) then
			self.back:Show();
			self.stripe:Show();
			self.text:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		else
			self.back:Hide();
			self.stripe:Hide();
			self.text:SetTextColor(0.80, 0.80, 0.84);
		end
	end;
	t:Select(false);
	t:SetScript("OnClick", onClick);
	return t;
end

function G.BuildSettings()
	local f = CreateFrame("Frame", "AZSGW2Settings", UIParent);
	f:SetWidth(W);
	f:SetHeight(H);
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40);
	f:SetFrameStrata("DIALOG");
	f:SetMovable(true);
	f:EnableMouse(true);
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", function()
		f:StartMoving();
	end);
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing();
	end);
	f:Hide();
	local bg = G.Solid(f, "BACKGROUND", 0.04, 0.04, 0.05, 0.97);
	bg:SetAllPoints(f);
	G.Frame9(f, "BORDER");
	G.settings = f;
	f.azs = true;               -- the popup hunter never looks inside this window

	local title = G.Text(f, 15, "LEFT");
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -14);
	title:SetText("AZS GW2 UI");
	title:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	local sub = G.TextS(f, 11, "LEFT");
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1);
	sub:SetText("Settings");
	sub:SetTextColor(0.62, 0.62, 0.66);
	local line = G.Band(f, "ARTWORK", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.9);
	line:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38);
	line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -38);
	line:SetHeight(1);

	local x = CreateFrame("Button", nil, f);
	x:SetWidth(22);
	x:SetHeight(22);
	x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10);
	local xbg = G.Solid(x, "BACKGROUND", 0.10, 0.09, 0.10, 0.95);
	xbg:SetAllPoints(x);
	G.Edges(x, 0.55, 0.46, 0.30, 1, 1, "BORDER");
	local xt = G.Text(x, 13, "CENTER");
	xt:SetPoint("CENTER", x, "CENTER", 0, 0);
	xt:SetText("x");
	x:SetScript("OnClick", function()
		f:Hide();
	end);
	x:SetScript("OnEnter", function()
		xbg:SetVertexColor(0.30, 0.10, 0.10, 0.95);
	end);
	x:SetScript("OnLeave", function()
		xbg:SetVertexColor(0.10, 0.09, 0.10, 0.95);
	end);

	-- the pages, listed on the left
	local nav = CreateFrame("Frame", nil, f);
	nav:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -TOP);
	nav:SetWidth(NAVW);
	nav:SetHeight(PAGEH);
	G.Panel(nav, 0.5);
	local ver = G.TextS(nav, 10, "CENTER");
	ver:SetPoint("BOTTOM", nav, "BOTTOM", 0, 10);
	ver:SetTextColor(0.5, 0.5, 0.54);
	local v = GetAddOnMetadata and GetAddOnMetadata("AZSGW2UI", "Version");
	ver:SetText(v and ( "version " .. tostring(v) ) or "");

	f.checks = {};
	f.pages = {};
	f.tabs = {};
	for i = 1, table.getn(PAGES) do
		local def = PAGES[i];
		local index = i;            -- a copy of its own: Lua 5.0 (the game) shares the loop variable between the closures
		f.tabs[i] = NewTab(nav, def.name, index, function()
			G.SettingsPage(index);
		end);
		local page = CreateFrame("Frame", nil, f);
		page:SetPoint("TOPLEFT", f, "TOPLEFT", PAGEX, -TOP);
		page:SetWidth(PAGEW);
		page:SetHeight(PAGEH);
		page:Hide();
		local y = 0;
		for k = 1, table.getn(def.sections) do
			local sec = def.sections[k];
			local height;
			if ( sec.layout ) then
				height = LAYOUTH;
			else
				height = SECHEAD + table.getn(sec.rows) * ROWH + 6;
			end
			local panel = NewSection(page, sec.title, y, height);
			if ( sec.layout ) then
				BuildLayout(f, panel);
			else
				for r = 1, table.getn(sec.rows) do
					local row = sec.rows[r];
					local indent = SUBS[row.label] and 22 or 0;
					local c = NewCheck(panel, row, 10 + indent, -SECHEAD - ( r - 1 ) * ROWH, PAGEW - 20 - indent);
					c.page = i;
					table.insert(f.checks, c);
				end
			end
			y = y + height + 8;
		end
		f.pages[i] = page;
	end
	f.page = 1;
	f:SetScript("OnShow", function()
		G.SettingsPage(f.page);
	end);
	if ( UISpecialFrames ) then
		table.insert(UISpecialFrames, "AZSGW2Settings");
	end
end

-- shows one page (and remembers it for the next time the window opens)
function G.SettingsPage(i)
	local f = G.settings;
	if ( not f or not f.pages ) then
		return;
	end
	if ( not f.pages[i] ) then
		i = 1;
	end
	f.page = i;
	for k = 1, table.getn(f.pages) do
		if ( k == i ) then
			f.pages[k]:Show();
		else
			f.pages[k]:Hide();
		end
		f.tabs[k]:Select(k == i);
	end
end

function G.RefreshSettings()
	local f = G.settings;
	if ( not f ) then
		return;
	end
	for i = 1, table.getn(f.checks) do
		f.checks[i]:Refresh();
	end
	f.scaleText:SetText(string.format("%d%%", math.floor((AZSGW2DB.scale or 1) * 100 + 0.5)));
	f.unlock.text:SetText(G.unlocked and "Lock layout" or "Unlock layout");
end

function G.ToggleSettings()
	local f = G.settings;
	if ( not f ) then
		return;
	end
	if ( f:IsShown() ) then
		f:Hide();
	else
		G.RefreshSettings();
		f:Show();
	end
end

function G.ToggleUnlock()
	G.SetUnlocked(not G.unlocked);
	G.RefreshSettings();
	G.Print(G.unlocked and "layout unlocked: drag the gold boxes, then lock again." or "layout locked.");
end

function G.ResetPositions()
	AZSGW2DB.pos = {};
	AZSGW2DB.fscale = {};
	G.Print("positions and sizes reset, reloading.");
	ReloadUI();
end

------------------------------------------------------------------------ the minimap icon

function G.BuildMapButton()
	local b = CreateFrame("Button", "AZSGW2MapButton", UIParent);
	b:SetWidth(30);
	b:SetHeight(30);
	b:SetFrameStrata("HIGH");
	if ( G.mm ) then
		b:SetPoint("CENTER", G.mm, "BOTTOMLEFT", 2, 2);
	else
		b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -190, -40);
	end
	G.RegisterAlways(b);
	G.mapButton = b;
	G.Movable(b, "mapButton", "Settings icon");

	local icon = b:CreateTexture(nil, "ARTWORK");
	icon:SetAllPoints(b);
	if ( G.art.custom ) then
		icon:SetTexture(G.TEXPATH .. "mm_button.tga");
	else
		icon:SetTexture(G.MASK);
		icon:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3], 1);
	end
	local glow = b:CreateTexture(nil, "OVERLAY");
	glow:SetTexture(G.MASK);
	glow:SetAllPoints(b);
	glow:SetVertexColor(1, 0.9, 0.55, 0);
	b.glow = glow;

	b:RegisterForClicks("LeftButtonUp");
	b:SetScript("OnClick", function()
		G.ToggleSettings();
	end);
	b:SetScript("OnEnter", function()
		glow:SetVertexColor(1, 0.9, 0.55, 0.28);
		GameTooltip:SetOwner(b, "ANCHOR_LEFT");
		GameTooltip:AddLine("AZS GW2 UI", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		GameTooltip:AddLine("Left click: settings", 1, 1, 1);
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function()
		glow:SetVertexColor(1, 0.9, 0.55, 0);
		GameTooltip:Hide();
	end);
	if ( not AZSGW2DB.enabled ) then
		b:Hide();
	end
end
