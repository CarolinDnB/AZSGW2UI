-- AZS GW2 UI: Core.lua
-- Shared constants and small widget helpers. Written for the 1.12 client (Lua 5.0).

AZSGW2 = {};
local G = AZSGW2;

G.NAME = "AZSGW2UI";
G.TEXPATH = "Interface\\AddOns\\AZSGW2UI\\Textures\\";
G.WHITE = "Interface\\ChatFrame\\ChatFrameBackground";
G.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask";
G.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark";
G.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";

G.GOLD = { 0.80, 0.66, 0.38 };
G.GOLDLIGHT = { 0.96, 0.86, 0.58 };

G.CLASSICON = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes";
G.CLASSCOORDS = {
	warrior = { 0, 0.25, 0, 0.25 },
	mage = { 0.25, 0.5, 0, 0.25 },
	rogue = { 0.5, 0.75, 0, 0.25 },
	druid = { 0.75, 1, 0, 0.25 },
	hunter = { 0, 0.25, 0.25, 0.5 },
	shaman = { 0.25, 0.5, 0.25, 0.5 },
	priest = { 0.5, 0.75, 0.25, 0.5 },
	warlock = { 0.75, 1, 0.25, 0.5 },
	paladin = { 0, 0.25, 0.5, 0.75 },
};

-- what the Character / Talents buttons run (key binding commands). Change in game with /gw2 bind.
G.DEFAULT_BIND = {
	character = "TOGGLECHARACTER0",
	talents = "TOGGLETALENTS",
};

-- stock frames kept hidden while this UI is on (each is skipped if it does not exist):
-- player and party frames, buffs, and every piece of the stock action bar.
G.DEFAULT_HIDE = {
	"PlayerFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
	"BuffFrame", "TemporaryEnchantFrame", "TargetFrame", "TargetofTargetFrame",
	"MainMenuBar", "MainMenuExpBar", "MainMenuBarMaxLevelBar", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
	"MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
	"BonusActionBarFrame", "ShapeshiftBarFrame", "PetActionBarFrame",
	"RaidBossEmoteFrame", "RaidWarningFrame",       -- big centre-screen notices (stock RaidNotice frames)
};
for i = 1, 12 do
	table.insert(G.DEFAULT_HIDE, "ActionButton" .. i);
	table.insert(G.DEFAULT_HIDE, "BonusActionButton" .. i);
end

G.HUD_CVAR = {
	clock = "hudClock", bosses = "hudBosses", tally = "hudTally", build = "hudBuild",
	meter = "hudMeter", levels = "hudLevels", banners = "hudBanners", loot = "hudLoot",
	flag = "hudFlag", localClock = "hudLocalClock",
};

-- the game's own minimap red flag and local clock: hidden only while this UI's minimap is up
G.HUD_MAP_PARTS = { "flag", "localClock" };

-- options (Settings window): what a missing value means
G.OPTDEF = {
	dmg = true, dmgPet = true, dmgCrit = false, dmgTicks = true, dmgNative = false, minimap = true, pinChest = true, pinGuard = true, arrows = true,
	target = true, party = true, revive = true, meter = true, guardians = true, charPanel = true,
};

G.art = { custom = true };
G.movables = {};
G.always = {};       -- frames that stay up outside a run (minimap, settings icon): scaled, never hidden
G.all = {};          -- every top level frame (for /gw2 scale)
G.containers = {};   -- frames shown / hidden as a whole with the run
G.updaters = {};
G.hiddenByUs = {};

------------------------------------------------------------------------ misc

function G.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffd9ad57AZS GW2 UI:|r " .. tostring(msg));
end

function G.Num(v)
	return tonumber(v) or 0;
end

function G.Clamp(v, lo, hi)
	if ( v < lo ) then return lo; end
	if ( v > hi ) then return hi; end
	return v;
end

-- A string from outside (a hero's or friend's name, a boss name, banner text) is shown as it is: "|" would
-- start a colour / link code inside a font string, so it is doubled ("||" draws one "|").
function G.Esc(s)
	return ( string.gsub(tostring(s or ""), "|", "||") );
end

-- names of frames the player (or the popup hunter) may ask to keep hidden: letters, digits and "_" only,
-- and never one the game needs on screen, a chat or a dialog frame, or one of this addon's own
local PROTECTED = { UIParent = true, WorldFrame = true, GameTooltip = true, DEFAULT_CHAT_FRAME = true,
	CharacterFrame = true, SpellBookFrame = true, QuestLogFrame = true, QuestFrame = true, GossipFrame = true,
	MerchantFrame = true, LootFrame = true, MailFrame = true, TradeFrame = true, TaxiFrame = true,
	WorldMapFrame = true, BattlefieldFrame = true, TalentFrame = true, SkillFrame = true };
local PROTECTED_PREFIX = { "ChatFrame", "StaticPopup", "AZSGW2", "ContainerFrame", "GameMenu", "UIOptions",
	"VideoOptions", "KeyBinding", "OptionsFrame", "UIDropDownMenu", "DropDownList", "InterfaceOptions", "Talent" };

-- banner text from the game: colour codes and links are dropped (the banner has its own colours), any other
-- "|" is doubled so it shows as it is
function G.Plain(s)
	s = tostring(s or "");
	s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "");
	s = string.gsub(s, "|r", "");
	s = string.gsub(s, "|H.-|h(.-)|h", "%1");
	return ( string.gsub(s, "|", "||") );
end

function G.ValidFrameName(name)
	return type(name) == "string" and string.len(name) > 0 and string.len(name) <= 64 and string.find(name, "^[%w_]+$") ~= nil;
end

function G.IsProtected(name)
	if ( type(name) ~= "string" ) then
		return true;
	end
	if ( PROTECTED[name] ) then
		return true;
	end
	for i = 1, table.getn(PROTECTED_PREFIX) do
		local p = PROTECTED_PREFIX[i];
		if ( string.sub(name, 1, string.len(p)) == p ) then
			return true;
		end
	end
	return false;
end

function G.Opt(key)
	local d = AZSGW2DB and AZSGW2DB.opt;
	if ( d and d[key] ~= nil ) then
		return d[key];
	end
	return G.OPTDEF[key];
end

function G.SetOpt(key, value)
	AZSGW2DB.opt = AZSGW2DB.opt or {};
	AZSGW2DB.opt[key] = value and true or false;
end

-- arrows: 32 rotations in arrows.tga (8 x 4 cells). rel = radians counter-clockwise from "up".
function G.SetArrow(tex, rel)
	local tau = 6.28318531;
	rel = rel - tau * math.floor(rel / tau);
	local k = math.floor(rel / tau * 32 + 0.5);
	if ( k >= 32 ) then
		k = 0;
	end
	local col, row = math.mod(k, 8), math.floor(k / 8);
	tex:SetTexCoord(col / 8, (col + 1) / 8, row / 4, (row + 1) / 4);
end

-- where (x, y) lies relative to where the hero looks, from AZS_GetPlayerPosition()'s position p:
-- +x is north, +y west, facing 0 north growing towards west, so the angle is atan2(dy, dx) - facing
function G.RelBearing(p, x, y)
	return math.atan2(y - p.y, x - p.x) - ( p.facing or 0 );
end

function G.Distance(p, x, y)
	local dx, dy = x - p.x, y - p.y;
	return math.sqrt(dx * dx + dy * dy);
end

function G.Comma(n)
	local s = string.format("%d", math.floor((tonumber(n) or 0) + 0.5));
	local k;
	while true do
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2");
		if ( k == 0 ) then
			break;
		end
	end
	return s;
end

function G.Short(n)
	n = tonumber(n) or 0;
	local a = math.abs(n);
	if ( a >= 1000000000 ) then
		return string.format("%.1fB", n / 1000000000);
	elseif ( a >= 1000000 ) then
		return string.format("%.1fM", n / 1000000);
	elseif ( a >= 1000 ) then
		return string.format("%.1fK", n / 1000);
	end
	return string.format("%d", math.floor(n + 0.5));
end

function G.Clock(s)
	s = math.floor((tonumber(s) or 0) + 0.5);
	if ( s < 0 ) then s = 0; end
	return string.format("%d:%02d", math.floor(s / 60), math.mod(s, 60));
end

-- short countdown text for icons: "1:05", "34", "7.5"
function G.Rem(s)
	s = tonumber(s) or 0;
	if ( s >= 60 ) then
		return G.Clock(s);
	elseif ( s >= 10 ) then
		return string.format("%d", math.floor(s + 0.5));
	end
	return string.format("%.1f", s);
end

function G.ClassColor(key)
	if ( key and RAID_CLASS_COLORS ) then
		local c = RAID_CLASS_COLORS[string.upper(key)];
		if ( c ) then
			return c.r, c.g, c.b;
		end
	end
	return 0.9, 0.9, 0.9;
end

function G.Phase()
	if ( AZS_GetPhase ) then
		return AZS_GetPhase();
	end
	return nil;
end

function G.RunTime()
	if ( AZS_GetRunTime ) then
		return AZS_GetRunTime() or 0;
	end
	return 0;
end

------------------------------------------------------------------------ frames

function G.Register(frame, conditional)
	table.insert(G.all, frame);
	if ( not conditional ) then
		table.insert(G.containers, frame);
	end
	frame:SetScale(AZSGW2DB and AZSGW2DB.scale or 1);
end

function G.RegisterAlways(frame)
	table.insert(G.always, frame);
	frame:SetScale(AZSGW2DB and AZSGW2DB.scale or 1);
end

function G.AddUpdater(name, fn, interval)
	table.insert(G.updaters, { name = name, fn = fn, interval = interval or 0, acc = 0 });
end

function G.Text(parent, size, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY");
	fs:SetFont(G.FONT, size or 12, "OUTLINE");
	fs:SetJustifyH(justify or "LEFT");
	fs:SetTextColor(1, 1, 1);
	fs:SetText("");
	return fs;
end

function G.Solid(frame, layer, r, g, b, a)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND");
	t:SetTexture(G.WHITE);
	t:SetVertexColor(r, g, b, a or 1);
	return t;
end

-- 1px (or size px) coloured edges inside a frame
function G.Edges(frame, r, g, b, a, size, layer)
	size = size or 1;
	layer = layer or "BORDER";
	local e = {};
	e.top = G.Solid(frame, layer, r, g, b, a);
	e.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
	e.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0);
	e.top:SetHeight(size);
	e.bottom = G.Solid(frame, layer, r, g, b, a);
	e.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0);
	e.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0);
	e.bottom:SetHeight(size);
	e.left = G.Solid(frame, layer, r, g, b, a);
	e.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -size);
	e.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, size);
	e.left:SetWidth(size);
	e.right = G.Solid(frame, layer, r, g, b, a);
	e.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -size);
	e.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, size);
	e.right:SetWidth(size);
	frame.edges = e;
	return e;
end

function G.EdgeColor(frame, r, g, b, a)
	local e = frame.edges;
	if ( not e ) then return; end
	e.top:SetVertexColor(r, g, b, a or 1);
	e.bottom:SetVertexColor(r, g, b, a or 1);
	e.left:SetVertexColor(r, g, b, a or 1);
	e.right:SetVertexColor(r, g, b, a or 1);
end

-- dark glass panel with a bronze trim, the GW2 look
function G.Panel(frame, alpha)
	local bg = G.Solid(frame, "BACKGROUND", 0.03, 0.03, 0.04, alpha or 0.72);
	bg:SetAllPoints(frame);
	G.Edges(frame, 0.50, 0.41, 0.25, 0.95, 1, "BORDER");
	frame.bg = bg;
end

-- the steel frame (frame9.tga, 8 px corners) around a frame; stock art gets plain edges
function G.Frame9(frame, layer)
	if ( not G.art.custom ) then
		G.Edges(frame, 0.62, 0.62, 0.66, 1, 2, layer or "BORDER");
		return;
	end
	layer = layer or "BORDER";
	local c = 8;
	local a = c / 64;
	local path = G.TEXPATH .. "frame9.tga";
	local function piece(p1, x1, y1, p2, x2, y2, w, h, u0, u1, v0, v1)
		local t = frame:CreateTexture(nil, layer);
		t:SetTexture(path);
		t:SetPoint(p1, frame, p1, x1, y1);
		if ( p2 ) then
			t:SetPoint(p2, frame, p2, x2, y2);
		end
		if ( w ) then t:SetWidth(w); end
		if ( h ) then t:SetHeight(h); end
		t:SetTexCoord(u0, u1, v0, v1);
	end
	piece("TOPLEFT", 0, 0, nil, 0, 0, c, c, 0, a, 0, a);
	piece("TOPRIGHT", 0, 0, nil, 0, 0, c, c, 1 - a, 1, 0, a);
	piece("BOTTOMLEFT", 0, 0, nil, 0, 0, c, c, 0, a, 1 - a, 1);
	piece("BOTTOMRIGHT", 0, 0, nil, 0, 0, c, c, 1 - a, 1, 1 - a, 1);
	piece("TOPLEFT", c, 0, "TOPRIGHT", -c, 0, nil, c, a, 1 - a, 0, a);
	piece("BOTTOMLEFT", c, 0, "BOTTOMRIGHT", -c, 0, nil, c, a, 1 - a, 1 - a, 1);
	piece("TOPLEFT", 0, -c, "BOTTOMLEFT", 0, c, c, nil, 0, a, a, 1 - a);
	piece("TOPRIGHT", 0, -c, "BOTTOMRIGHT", 0, c, c, nil, 1 - a, 1, a, 1 - a);
end

-- horizontal fade strip. Custom art: band.tga, stock art: plain colour.
function G.Band(frame, layer, r, g, b, a)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND");
	if ( G.art.custom ) then
		t:SetTexture(G.TEXPATH .. "band.tga");
	else
		t:SetTexture(G.WHITE);
	end
	t:SetVertexColor(r, g, b, a or 1);
	return t;
end

------------------------------------------------------------------------ fonts

-- the clean sans font shipped with the addon (Fonts\\azs_numbers.ttf: Latin and Cyrillic). Numbers use it
-- on every client; names and labels use it on Latin / Cyrillic clients (Chinese, Japanese and Korean
-- clients keep their own font, which has their glyphs). If the file can not be loaded, the game's font stays.
G.SANSFILE = "Interface\\AddOns\\AZSGW2UI\\Fonts\\azs_numbers.ttf";

local function FontLoads()
	if ( G.sansOk ~= nil ) then
		return G.sansOk;
	end
	G.sansOk = false;
	if ( UIParent and UIParent.CreateFontString ) then
		local t = UIParent:CreateFontString(nil, "OVERLAY");
		t:SetFont(G.FONT, 12, "");
		t:SetFont(G.SANSFILE, 12, "");
		local got = t.GetFont and t:GetFont();
		if ( got == nil or string.find(string.lower(tostring(got)), "azs_numbers", 1, true) ) then
			G.sansOk = true;
		end
	end
	return G.sansOk;
end

function G.NumFont()
	if ( FontLoads() ) then
		return G.SANSFILE;
	end
	return G.FONT;
end

function G.Sans()
	if ( FontLoads() and string.find(string.lower(G.FONT or ""), "frizqt", 1, true) ) then
		return G.SANSFILE;
	end
	return G.FONT;
end

-- crisp text for lists: the sans font, a soft drop shadow instead of an outline
function G.TextS(parent, size, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY");
	fs:SetFont(G.Sans(), size or 12, "");
	fs:SetJustifyH(justify or "LEFT");
	fs:SetTextColor(1, 1, 1);
	fs:SetShadowColor(0, 0, 0, 0.95);
	fs:SetShadowOffset(1, -1);
	fs:SetText("");
	return fs;
end

-- GW2 style status bar. Use bar:SetFrac(0..1) and bar:SetColor(r, g, b)
function G.NewBar(parent, w, h, r, g, b)
	local f = CreateFrame("Frame", nil, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	local back = G.Solid(f, "BACKGROUND", 0.03, 0.03, 0.03, 0.88);
	back:SetAllPoints(f);
	local fill = G.Solid(f, "BORDER", r, g, b, 1);
	fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
	fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1);
	fill:SetWidth(1);
	fill:Hide();
	f.fill = fill;
	if ( G.art.custom ) then
		local gl = f:CreateTexture(nil, "ARTWORK");
		gl:SetTexture(G.TEXPATH .. "bar_gloss.tga");
		gl:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
		gl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1);
	end
	G.Edges(f, 0.52, 0.43, 0.26, 1, 1, "ARTWORK");
	f.SetFrac = function(self, frac)
		frac = G.Clamp(tonumber(frac) or 0, 0, 1);
		local width = (self:GetWidth() or 0) - 2;
		if ( frac <= 0.002 or width <= 0 ) then
			self.fill:Hide();
			return;
		end
		self.fill:SetWidth(width * frac);
		self.fill:Show();
	end;
	f.SetColor = function(self, cr, cg, cb)
		self.fill:SetVertexColor(cr, cg, cb, 1);
	end;
	return f;
end

------------------------------------------------------------------------ tooltips / dragging

function G.Tooltip(frame, func, anchor)
	frame:EnableMouse(true);
	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(frame, anchor or "ANCHOR_TOP");
		func(GameTooltip);
		GameTooltip:Show();
	end);
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
end

function G.ApplyPos(frame, key)
	local p = AZSGW2DB and AZSGW2DB.pos and AZSGW2DB.pos[key];
	if ( p and p[1] ) then
		frame:ClearAllPoints();
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]);
	end
end

function G.HasPos(key)
	local p = AZSGW2DB and AZSGW2DB.pos and AZSGW2DB.pos[key];
	return p and p[1] and true or false;
end

function G.SavePos(m)
	local point, rel, relPoint, x, y = m.frame:GetPoint();
	if ( point and AZSGW2DB ) then
		AZSGW2DB.pos = AZSGW2DB.pos or {};
		AZSGW2DB.pos[m.key] = { point, relPoint, x, y };
	end
end

-- a frame the player can move: in "unlock" mode (the settings window or /gw2 unlock) every movable
-- frame gets a gold box with its name that is dragged freely; the place is saved. tl / br: two
-- frames whose corners make the box when the group (such as the skill bar) is bigger than the frame.
-- mouse = true keeps the old Shift + drag on the frame itself.
function G.Movable(frame, key, label, tl, br, mouse)
	frame:SetMovable(true);
	local m = { frame = frame, key = key, label = label or key, tl = tl, br = br };
	table.insert(G.movables, m);
	if ( mouse ) then
		frame:EnableMouse(true);
		frame:RegisterForDrag("LeftButton");
		frame:SetScript("OnDragStart", function()
			if ( IsShiftKeyDown() ) then
				frame:StartMoving();
			end
		end);
		frame:SetScript("OnDragStop", function()
			frame:StopMovingOrSizing();
			G.SavePos(m);
		end);
	end
	G.ApplyPos(frame, key);
	return m;
end

function G.SetUnlocked(on)
	G.unlocked = on and true or false;
	for i = 1, table.getn(G.movables) do
		local m = G.movables[i];
		if ( on and not m.ov ) then
			local ov = CreateFrame("Frame", nil, UIParent);
			ov.azs = true;
			ov:SetFrameStrata("FULLSCREEN_DIALOG");
			if ( m.tl and m.br ) then
				ov:SetPoint("TOPLEFT", m.tl, "TOPLEFT", -4, 4);
				ov:SetPoint("BOTTOMRIGHT", m.br, "BOTTOMRIGHT", 4, -4);
			else
				ov:SetPoint("TOPLEFT", m.frame, "TOPLEFT", 0, 0);
				ov:SetPoint("BOTTOMRIGHT", m.frame, "BOTTOMRIGHT", 0, 0);
			end
			local bg = G.Solid(ov, "BACKGROUND", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.30);
			bg:SetAllPoints(ov);
			G.Edges(ov, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 0.95, 1, "BORDER");
			local t = G.Text(ov, 11, "CENTER");
			t:SetPoint("CENTER", ov, "CENTER", 0, 0);
			t:SetText(m.label);
			ov:SetScale(AZSGW2DB and AZSGW2DB.scale or 1);
			ov:EnableMouse(true);
			ov:RegisterForDrag("LeftButton");
			ov:SetScript("OnDragStart", function()
				m.frame:StartMoving();
			end);
			ov:SetScript("OnDragStop", function()
				m.frame:StopMovingOrSizing();
				G.SavePos(m);
			end);
			m.ov = ov;
		end
		if ( m.ov ) then
			if ( on ) then
				m.ov:Show();
			else
				m.ov:Hide();
			end
		end
	end
end

------------------------------------------------------------------------ game HUD

G.HUD_PARTS = { "clock", "bosses", "tally", "build", "meter", "levels", "banners", "loot" };

-- the parts of the game's HUD this UI replaces right now (the minimap's flag and local clock only
-- while the GW2 minimap is up); restoring gives every part back
function G.HudList(restoring)
	local list = {};
	for i = 1, table.getn(G.HUD_PARTS) do
		table.insert(list, G.HUD_PARTS[i]);
	end
	if ( G.mapActive or restoring ) then
		for i = 1, table.getn(G.HUD_MAP_PARTS) do
			table.insert(list, G.HUD_MAP_PARTS[i]);
		end
	end
	return list;
end

function G.HideGameHud(hide)
	if ( not AZS_SetHudShown ) then
		return;
	end
	local list = G.HudList(not hide);
	for i = 1, table.getn(list) do
		AZS_SetHudShown(list[i], not hide);
	end
end

-- Frames are kept hidden with an OnShow hook: whatever shows them again, they hide again at once.
G.keptHidden = {};

function G.KeepHidden(name)
	if ( not G.ValidFrameName(name) or G.IsProtected(name) ) then
		return;
	end
	local f = getglobal(name);
	if ( not f or not f.Hide or not f.GetScript ) then
		return;
	end
	if ( not G.keptHidden[name] ) then
		G.keptHidden[name] = { frame = f, onshow = f:GetScript("OnShow"), was = f:IsShown() };
		local frame = f;
		f:SetScript("OnShow", function()
			frame:Hide();
		end);
	end
	if ( f:IsShown() ) then
		f:Hide();
	end
end

-- the game's own HUD parts (AZS_SetHudShown). Asserted again every half second: something
-- on the game's side was switching the spells row back on.
function G.EnforceHud()
	if ( not AZS_SetHudShown ) then
		return;
	end
	local list = G.HudList(false);
	for i = 1, table.getn(list) do
		local part = list[i];
		local on = true;
		if ( AZS_IsHudShown ) then
			on = AZS_IsHudShown(part);
		end
		if ( on ) then
			AZS_SetHudShown(part, false);
			local cvar = G.HUD_CVAR[part];
			if ( cvar and SetCVar and GetCVar and GetCVar(cvar) ~= "0" ) then
				SetCVar(cvar, "0");
			end
		end
	end
end

function G.EnforceHidden()
	if ( not AZSGW2DB or not AZSGW2DB.enabled ) then
		return;
	end
	G.EnforceHud();
	G.QuietMessages(not AZSGW2DB.messages);
	if ( not AZSGW2DB.plates ) then
		-- enemy nameplates: switched off once, and again only when the game switches them on (it sets
		-- NAMEPLATES_ON); with hundreds of enemies around the game's own call is not something to run twice a second
		if ( NAMEPLATES_ON or not G.platesOff ) then
			if ( HideNameplates ) then
				HideNameplates();
			end
			NAMEPLATES_ON = nil;
			G.platesOff = true;
		end
	else
		G.platesOff = false;
	end
	for i = 1, table.getn(G.DEFAULT_HIDE) do
		G.KeepHidden(G.DEFAULT_HIDE[i]);
	end
	if ( G.mmAttached and G.KeepMinimapQuiet ) then
		G.KeepMinimapQuiet();
	end
	local extra = AZSGW2DB.hide;
	if ( extra ) then
		for i = 1, table.getn(extra) do
			G.KeepHidden(extra[i]);
		end
	end
end

-- the game's own centre-screen messages (boss engaged, guardian slain, ...): silenced while our
-- banners are on. UIErrorsFrame's AddMessage is shadowed by an empty function (removing the
-- shadow gives the real method back), RaidNotice_AddMessage is swapped for an empty one.
G.quiet = {};

function G.QuietMessages(on)
	if ( on ) then
		if ( UIErrorsFrame and not G.quiet.errors ) then
			G.quiet.errors = true;
			UIErrorsFrame.AddMessage = function() end;
		end
		if ( RaidNotice_AddMessage and not G.quiet.raid ) then
			G.quiet.raid = RaidNotice_AddMessage;
			RaidNotice_AddMessage = function() end;
		end
	else
		if ( G.quiet.errors ) then
			UIErrorsFrame.AddMessage = nil;
			G.quiet.errors = nil;
		end
		if ( G.quiet.raid ) then
			RaidNotice_AddMessage = G.quiet.raid;
			G.quiet.raid = nil;
		end
	end
end

-- give some of the kept-hidden frames back (their old OnShow script, shown again if they were)
function G.RestoreHiddenList(names)
	for i = 1, table.getn(names) do
		local info = G.keptHidden[names[i]];
		if ( info ) then
			local f = info.frame;
			if ( f and f.SetScript ) then
				f:SetScript("OnShow", info.onshow);
				if ( info.was ) then
					f:Show();
				end
			end
			G.keptHidden[names[i]] = nil;
		end
	end
end

function G.RestoreHidden()
	G.QuietMessages(false);
	if ( ShowNameplates and not AZSGW2DB.plates ) then
		ShowNameplates();
		NAMEPLATES_ON = 1;
	end
	G.platesOff = false;
	if ( G.mmAttached and G.DetachMinimap ) then
		G.DetachMinimap();
	end
	local names = {};
	for name in pairs(G.keptHidden) do
		table.insert(names, name);
	end
	G.RestoreHiddenList(names);
	G.keptHidden = {};
	if ( G.RestoreHunted ) then
		G.RestoreHunted();
	end
end

------------------------------------------------------------------------ the game's own popup text
-- A banner the game draws itself ("Kobold Taskmaster is slain! Its lair yields ...") can come out of a
-- frame whose name is not known. When a banner arrives, the frames are searched for visible text that
-- matches it (our own frames excluded); the frame that holds it is hidden for good (moved under a hidden
-- parent, with an OnShow hook as well). Named frames are also written to AZSGW2DB.hide.
G.hunt = { pending = nil, seen = {}, count = 0, misses = 0, off = false };

local HUNT_SKIP = { UIParent = true, WorldFrame = true, GameTooltip = true, DEFAULT_CHAT_FRAME = true };

local function StripCodes(s)
	s = string.gsub(tostring(s or ""), "|c%x%x%x%x%x%x%x%x", "");
	s = string.gsub(s, "|r", "");
	s = string.gsub(s, "|n", " ");
	return s;
end

local function Squash(s)
	s = string.gsub(s, "%s+", " ");
	return string.lower(s);
end

-- our own frames (registered ones and their children) are never searched
local function OurSet()
	local set = {};
	for i = 1, table.getn(G.all) do
		set[G.all[i]] = true;
	end
	for i = 1, table.getn(G.always) do
		set[G.always[i]] = true;
	end
	return set;
end

local function HiddenHolder()
	if ( not G.hunt.holder ) then
		local h = CreateFrame("Frame", nil, UIParent);
		h:Hide();
		G.hunt.holder = h;
	end
	return G.hunt.holder;
end

-- keep one frame (or a lone font string) hidden for good; returns a short name for the message
function G.HideNativeFrame(frame, region)
	local info = G.hunt.seen[frame];
	if ( info ) then
		return nil;
	end
	local name = frame.GetName and frame:GetName();
	local big = false;
	if ( frame.GetWidth and frame.GetHeight and UIParent ) then
		big = ( frame:GetWidth() > UIParent:GetWidth() * 0.8 and frame:GetHeight() > UIParent:GetHeight() * 0.6 );
	end
	if ( name and G.IsProtected(name) and not HUNT_SKIP[name] ) then
		return nil;                      -- a frame the game needs (a dialog, the map ...): never hidden by a guess
	end
	if ( HUNT_SKIP[name or ""] or big or not frame.SetParent ) then
		-- text drawn straight on a full-screen frame: only the text itself can go
		if ( region and not G.hunt.seen[region] ) then
			G.hunt.seen[region] = { region = region, lone = true };
			region:Hide();
			region.Show = function() end;
			return "text on " .. ( name or "a full-screen frame" );
		end
		return nil;
	end
	local old = frame:GetParent();
	info = { frame = frame, parent = old, onshow = frame.GetScript and frame:GetScript("OnShow") };
	G.hunt.seen[frame] = info;
	frame:SetParent(HiddenHolder());
	if ( frame.SetScript ) then
		frame:SetScript("OnShow", function()
			frame:Hide();
		end);
	end
	frame:Hide();
	if ( name and AZSGW2DB and G.ValidFrameName(name) ) then
		AZSGW2DB.hide = AZSGW2DB.hide or {};
		local known = false;
		for i = 1, table.getn(AZSGW2DB.hide) do
			if ( AZSGW2DB.hide[i] == name ) then
				known = true;
			end
		end
		if ( not known and table.getn(AZSGW2DB.hide) < 60 ) then
			table.insert(AZSGW2DB.hide, name);
		end
	end
	return name or "an unnamed frame";
end

-- One pass over the frames that are SHOWN right now (a walk down from UIParent and WorldFrame that does
-- not enter hidden frames, ours or chat): hide the ones holding visible text that matches `text`.
-- The walk touches a few hundred frames, not the thousands EnumerateFrames() would give.
local function WalkFor(frame, keys, ours, state)
	state.nodes = state.nodes + 1;
	local regions = { frame:GetRegions() };
	for i = 1, table.getn(regions) do
		local r = regions[i];
		if ( r and r.GetObjectType and r:GetObjectType() == "FontString" and r:IsShown() and r.GetText ) then
			local t = r:GetText();
			if ( t and t ~= "" ) then
				local flat = Squash(StripCodes(t));
				for j = 1, table.getn(keys) do
					if ( string.len(flat) >= string.len(keys[j]) and string.find(flat, keys[j], 1, true) ) then
						local what = G.HideNativeFrame(frame, r);
						if ( what ) then
							state.hits = state.hits + 1;
							G.hunt.count = G.hunt.count + 1;
							G.Print("hid the game's own popup (" .. what .. ")");
						end
						break;
					end
				end
			end
		end
	end
	local kids = { frame:GetChildren() };
	for i = 1, table.getn(kids) do
		if ( state.nodes >= 900 ) then
			break;                       -- a hard stop: this must never cost a noticeable moment
		end
		local k = kids[i];
		if ( k and k:IsShown() and not ours[k] and not k.azs ) then
			local ot = k.GetObjectType and k:GetObjectType();
			local name = k.GetName and k:GetName();
			if ( ot ~= "ScrollingMessageFrame" and ot ~= "EditBox" and ot ~= "GameTooltip" and ot ~= "Minimap"
				and not ( name and string.sub(name, 1, 9) == "ChatFrame" ) and not G.hunt.seen[k] ) then
				WalkFor(k, keys, ours, state);
			end
		end
	end
end

function G.HuntNative(texts)
	local keys = {};
	for i = 1, table.getn(texts) do
		local want = Squash(StripCodes(texts[i]));
		if ( string.len(want) >= 8 ) then
			table.insert(keys, string.sub(want, 1, 30));
		end
	end
	if ( table.getn(keys) == 0 ) then
		return 0;
	end
	local state = { hits = 0, nodes = 0 };
	local ours = OurSet();
	local ok = pcall(function()
		WalkFor(UIParent, keys, ours, state);
		if ( state.nodes < 900 and WorldFrame and WorldFrame.GetChildren ) then
			WalkFor(WorldFrame, keys, ours, state);
		end
	end);
	if ( not ok ) then
		G.hunt.off = true;               -- whatever went wrong: never again this session
	end
	G.hunt.nodes = state.nodes;
	return state.hits;
end

-- A banner came: look for its stock twin twice (the game draws it a moment later). Two hunts in a row that
-- find nothing mean the game's own switches already hide it, and the hunter stops for the session, so it
-- can never cost anything again. (/gw2 hunt on starts it again.) Banners that arrive while a hunt is
-- running join it.
function G.QueueHunt(text)
	if ( not AZSGW2DB or not AZSGW2DB.enabled or AZSGW2DB.messages or G.hunt.off ) then
		return;
	end
	local h = G.hunt.pending;
	if ( not h ) then
		h = { texts = {}, age = 0, stage = 0, hits = 0 };
		G.hunt.pending = h;
	end
	if ( table.getn(h.texts) < 4 ) then
		table.insert(h.texts, text);
	end
end

local HUNT_AT = { 0.15, 0.7 };

function G.UpdateHunt(dt)
	local h = G.hunt.pending;
	if ( not h ) then
		return;
	end
	h.age = h.age + dt;
	local due = HUNT_AT[h.stage + 1];
	if ( due and h.age >= due ) then
		h.stage = h.stage + 1;
		h.hits = h.hits + G.HuntNative(h.texts);
	end
	if ( h.stage >= table.getn(HUNT_AT) ) then
		G.hunt.pending = nil;
		if ( h.hits > 0 ) then
			G.hunt.misses = 0;
		else
			G.hunt.misses = ( G.hunt.misses or 0 ) + 1;
			if ( G.hunt.misses >= 2 ) then
				G.hunt.off = true;
			end
		end
	end
end

-- give everything the hunter hid back (/gw2 off)
function G.RestoreHunted()
	for key, info in pairs(G.hunt.seen) do
		if ( info.lone ) then
			info.region.Show = nil;
		elseif ( info.frame ) then
			local f = info.frame;
			f:SetParent(info.parent or UIParent);
			if ( f.SetScript ) then
				f:SetScript("OnShow", info.onshow);
			end
		end
	end
	G.hunt.seen = {};
	G.hunt.pending = nil;
	G.hunt.misses = 0;
	G.hunt.off = false;
end

------------------------------------------------------------------------ key bindings of the Talents / Character buttons

-- a binding the player set with /gw2 bind wins; otherwise the best match in the binding list
-- ("AZS..." names first, then names with TOGGLE), otherwise the stock 1.12 name
function G.FindBinding(kind)
	local set = AZSGW2DB and AZSGW2DB.bind and AZSGW2DB.bind[kind];
	if ( set ) then
		return set;
	end
	G.foundBind = G.foundBind or {};
	if ( G.foundBind[kind] ) then
		return G.foundBind[kind];
	end
	local pattern = "CHARACTER";
	if ( kind == "talents" ) then
		pattern = "TALENT";
	end
	local best, bestScore = nil, 0;
	if ( GetNumBindings and GetBinding ) then
		for i = 1, GetNumBindings() do
			local cmd = GetBinding(i);
			if ( cmd ) then
				local u = string.upper(cmd);
				if ( string.find(u, pattern, 1, true) ) then
					local score = 1;
					if ( string.find(u, "AZS", 1, true) ) then
						score = score + 4;
					end
					if ( string.find(u, "TOGGLE", 1, true) ) then
						score = score + 1;
					end
					if ( score > bestScore ) then
						best, bestScore = cmd, score;
					end
				end
			end
		end
	end
	best = best or G.DEFAULT_BIND[kind];
	G.foundBind[kind] = best;
	return best;
end

function G.BindingText(kind)
	local cmd = G.FindBinding(kind);
	local key = nil;
	if ( cmd and GetBindingKey ) then
		key = GetBindingKey(cmd);
	end
	if ( key ) then
		return tostring(cmd) .. "  [" .. tostring(key) .. "]";
	end
	return tostring(cmd);
end

function G.RunKind(kind)
	local cmd = G.FindBinding(kind);
	if ( RunBinding and cmd ) then
		local ok, err = pcall(RunBinding, cmd);
		if ( not ok ) then
			G.Print("could not run " .. tostring(cmd) .. ": " .. tostring(err));
		end
	end
end
