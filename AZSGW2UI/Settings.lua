-- AZS GW2 UI: Settings.lua
-- The round icon on the minimap (left click: settings window)
-- and the settings window: switches for the parts of this UI, size, moving frames, reset.

local G = AZSGW2;

local ROWH = 22;

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

-- what each switch is called, reads and does. messages keeps its old saved name: true means "show the game's own".
local ROWS = {
	{ label = "Damage numbers (GW2 style)", get = function() return G.Opt("dmg"); end,
		set = function(v) G.SetOpt("dmg", v); G.ApplyDamage(); end },
	{ label = "   only critical hits", get = function() return G.Opt("dmgCrit"); end,
		set = function(v) G.SetOpt("dmgCrit", v); end },
	{ label = "   damage over time ticks", get = function() return G.Opt("dmgTicks"); end,
		set = function(v) G.SetOpt("dmgTicks", v); end },
	{ label = "   also from pets and summons", get = function() return G.Opt("dmgPet"); end,
		set = function(v) G.SetOpt("dmgPet", v); end },
	{ label = "Game's own damage numbers", get = function() return G.Opt("dmgNative"); end,
		set = function(v) G.SetOpt("dmgNative", v); G.ApplyDamage(); end },
	{ label = "GW2 minimap", get = function() return G.Opt("minimap"); end,
		set = function(v) G.SetOpt("minimap", v); G.ApplyMinimap(); end },
	{ label = "   caches on the minimap", get = function() return G.Opt("pinChest"); end,
		set = function(v) G.SetOpt("pinChest", v); end },
	{ label = "   guardians on the minimap", get = function() return G.Opt("pinGuard"); end,
		set = function(v) G.SetOpt("pinGuard", v); end },
	{ label = "Guardian list", get = function() return G.Opt("guardians"); end,
		set = function(v) G.SetOpt("guardians", v); end },
	{ label = "   direction arrows", get = function() return G.Opt("arrows"); end,
		set = function(v) G.SetOpt("arrows", v); end },
	{ label = "Target bar", get = function() return G.Opt("target"); end,
		set = function(v) G.SetOpt("target", v); end },
	{ label = "Party frames", get = function() return G.Opt("party"); end,
		set = function(v) G.SetOpt("party", v); end },
	{ label = "Ally down alert + arrow", get = function() return G.Opt("revive"); end,
		set = function(v) G.SetOpt("revive", v); end },
	{ label = "GW2 character panel", get = function() return G.Opt("charPanel"); end,
		set = function(v) G.SetOpt("charPanel", v); end },
	{ label = "Enable nameplates", get = function() return G.Opt("nameplates"); end,
		set = function(v) G.SetPlateOpt("nameplates", v); end },
	{ label = "   only elites and guardians", get = function() return G.Opt("platesElite"); end,
		set = function(v) G.SetPlateOpt("platesElite", v); end },
	{ label = "Enable friendly nameplates", get = function() return G.Opt("platesFriend"); end,
		set = function(v) G.SetPlateOpt("platesFriend", v); end },
	{ label = "Enemies hit, on the skills", get = function() return G.Opt("hits"); end,
		set = function(v) G.SetOpt("hits", v); end },
	{ label = "Damage meter", get = function() return G.Opt("meter"); end,
		set = function(v) G.SetOpt("meter", v); end },
	{ label = "Game's centre-screen messages", get = function() return AZSGW2DB.messages and true or false; end,
		set = function(v) G.SetMessages(v); end },
};

-- the nameplate options: the GW2 nameplates (Plates.lua) on the game's own plates, which are switched to match
function G.SetPlateOpt(key, on)
	G.SetOpt(key, on);
	G.EnforcePlates();
end

function G.SetMessages(on)
	AZSGW2DB.messages = on and true or false;
	G.QuietMessages(not on);
end

------------------------------------------------------------------------ window

local function NewCheck(parent, row, y)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(268);
	b:SetHeight(ROWH - 2);
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y);
	local box = CreateFrame("Frame", nil, b);
	box:SetWidth(14);
	box:SetHeight(14);
	box:SetPoint("LEFT", b, "LEFT", 0, 0);
	local bg = G.Solid(box, "BACKGROUND", 0.03, 0.03, 0.04, 1);
	bg:SetAllPoints(box);
	G.Edges(box, G.GOLD[1], G.GOLD[2], G.GOLD[3], 1, 1, "BORDER");
	local mark = G.Solid(box, "ARTWORK", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
	mark:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3);
	mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3);
	b.mark = mark;
	local t = G.Text(b, 11, "LEFT");
	t:SetPoint("LEFT", b, "LEFT", 20, 0);
	t:SetText(row.label);
	b.row = row;
	b.Refresh = function(self)
		if ( self.row.get() ) then
			self.mark:Show();
		else
			self.mark:Hide();
		end
	end;
	b:SetScript("OnClick", function()
		b.row.set(not b.row.get());
		b:Refresh();
	end);
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

function G.BuildSettings()
	local nrows = table.getn(ROWS);
	local w, h = 300, 78 + nrows * ROWH + 74;
	local f = CreateFrame("Frame", "AZSGW2Settings", UIParent);
	f:SetWidth(w);
	f:SetHeight(h);
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
	local bg = G.Solid(f, "BACKGROUND", 0.04, 0.04, 0.05, 0.96);
	bg:SetAllPoints(f);
	G.Frame9(f, "BORDER");
	G.settings = f;
	f.azs = true;               -- the popup hunter never looks inside this window

	local title = G.Text(f, 14, "CENTER");
	title:SetPoint("TOP", f, "TOP", 0, -14);
	title:SetText("AZS GW2 UI");
	title:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	local line = G.Band(f, "ARTWORK", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95);
	line:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34);
	line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -34);
	line:SetHeight(1);

	local close = CreateFrame("Button", nil, f);
	close:SetWidth(18);
	close:SetHeight(18);
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10);
	local ct = G.Text(close, 13, "CENTER");
	ct:SetPoint("CENTER", close, "CENTER", 0, 0);
	ct:SetText("x");
	close:SetScript("OnClick", function()
		f:Hide();
	end);

	f.checks = {};
	for i = 1, nrows do
		f.checks[i] = NewCheck(f, ROWS[i], -44 - (i - 1) * ROWH);
	end

	-- size
	local sy = -44 - nrows * ROWH - 8;
	local st = G.Text(f, 11, "LEFT");
	st:SetPoint("TOPLEFT", f, "TOPLEFT", 16, sy - 4);
	st:SetText("Size");
	f.scaleText = G.Text(f, 11, "CENTER");
	f.scaleText:SetPoint("TOPLEFT", f, "TOPLEFT", 100, sy - 4);
	f.scaleText:SetWidth(50);
	local function Step(d)
		G.SetScaleAll(math.floor((AZSGW2DB.scale + d) * 100 + 0.5) / 100);
		f.scaleText:SetText(string.format("%d%%", math.floor(AZSGW2DB.scale * 100 + 0.5)));
	end
	NewButton(f, "-", 22, "TOPLEFT", 70, sy, function() Step(-0.05); end);
	NewButton(f, "+", 22, "TOPLEFT", 158, sy, function() Step(0.05); end);

	-- move / reset / close
	f.unlock = NewButton(f, "Unlock layout", 126, "BOTTOMLEFT", 16, 14, function()
		G.ToggleUnlock();
	end);
	NewButton(f, "Reset positions", 126, "BOTTOMRIGHT", -16, 14, function()
		G.ResetPositions();
	end);
	local hint = G.Text(f, 9, "CENTER");
	hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 42);
	hint:SetWidth(w - 30);
	hint:SetHeight(24);
	hint:SetTextColor(0.65, 0.65, 0.65);
	hint:SetText("Unlocked: drag a gold box to move it, its corner or the mouse wheel to resize it, right click puts its size back.");
	f.hint = hint;
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
