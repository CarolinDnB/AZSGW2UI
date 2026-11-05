-- AZS GW2 UI: Character.lua
-- A Guild Wars 2 style hero panel in place of the game's character window: armour in a column on the left
-- beside the character model, name / level / class on the right with an "Attributes" panel (every stat of
-- AZS_STATS, grouped Offense / Defense / Utility), accessories and weapons under it. The game's own window
-- still opens for its other tabs (pet, reputation, skills, honor) and whenever this UI is off.

local G = AZSGW2;

local W, H = 660, 524;
local RX = 316;                  -- left edge of the right-hand column
local AH = 346;                  -- height of the attributes panel
local COLW, ROWH, HEADH = 156, 18, 17;

------------------------------------------------------------------------ the equipment slots

-- left: every piece of gear that is worn on the body; right: the accessories (neck, rings, trinkets); weapons
-- show only for what the hero holds
local GEAR = { "HeadSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
	"HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot" };
local ACCESS = { "NeckSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" };
local WEAPONS = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" };

local SLOTNAME = {
	HeadSlot = "Head", ShoulderSlot = "Shoulders", ChestSlot = "Chest", HandsSlot = "Hands", LegsSlot = "Legs",
	FeetSlot = "Feet", NeckSlot = "Neck", BackSlot = "Back", WaistSlot = "Waist", WristSlot = "Wrists",
	ShirtSlot = "Shirt", Finger0Slot = "Ring", Finger1Slot = "Ring", Trinket0Slot = "Trinket",
	Trinket1Slot = "Trinket", TabardSlot = "Tabard", MainHandSlot = "Main Hand", SecondaryHandSlot = "Off Hand",
	RangedSlot = "Ranged", AmmoSlot = "Ammo",
};

-- the colour of an item link ("|cffa335ee|Hitem:..."): its quality
local function LinkColor(link)
	if ( type(link) ~= "string" ) then
		return nil;
	end
	local _, _, r, g, b = string.find(link, "|c%x%x(%x%x)(%x%x)(%x%x)");
	if ( not r ) then
		return nil;
	end
	r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16);
	if ( not r or not g or not b ) then
		return nil;
	end
	r, g, b = r / 255, g / 255, b / 255;
	if ( r > 0.95 and g > 0.95 and b > 0.95 ) then
		return 0.74, 0.74, 0.78;          -- common items: a quiet steel instead of glaring white
	end
	return r, g, b;
end

local function Safe(fn, a, b, c)
	if ( fn ) then
		local ok, r1, r2 = pcall(fn, a, b, c);
		if ( ok ) then
			return r1, r2;
		end
	end
	return nil;
end

local function NewSlot(parent, slotName, size)
	local id, emptyTex = nil, nil;
	if ( GetInventorySlotInfo ) then
		local ok, a, b = pcall(GetInventorySlotInfo, slotName);
		if ( ok ) then
			id, emptyTex = a, b;
		end
	end
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(size);
	b:SetHeight(size);
	b.slotName = slotName;
	b.slotId = id;
	local bg = G.Solid(b, "BACKGROUND", 0.015, 0.015, 0.02, 0.96);
	bg:SetAllPoints(b);
	b.icon = b:CreateTexture(nil, "ARTWORK");
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3);
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3);
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	G.Edges(b, 0.30, 0.28, 0.28, 1, 1, "BORDER");
	b.count = G.Text(b, 11, "RIGHT", "OVERLAY");
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3);
	b.emptyTex = emptyTex;
	b.sig = "?";
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	b:RegisterForDrag("LeftButton");
	b:SetScript("OnClick", function()
		if ( not b.slotId ) then
			return;
		end
		if ( arg1 == "RightButton" ) then
			Safe(UseInventoryItem, b.slotId);
		elseif ( IsShiftKeyDown and IsShiftKeyDown() and GetInventoryItemLink and GetInventoryItemLink("player", b.slotId) ) then
			if ( ChatFrameEditBox and ChatFrameEditBox:IsVisible() ) then
				Safe(ChatFrameEditBox.Insert, ChatFrameEditBox, GetInventoryItemLink("player", b.slotId));
			end
		else
			Safe(PickupInventoryItem, b.slotId);
		end
	end);
	b:SetScript("OnDragStart", function()
		if ( b.slotId ) then
			Safe(PickupInventoryItem, b.slotId);
		end
	end);
	b:SetScript("OnReceiveDrag", function()
		if ( b.slotId ) then
			Safe(PickupInventoryItem, b.slotId);
		end
	end);
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT");
		local has = false;
		if ( b.slotId and b.hasItem and GameTooltip.SetInventoryItem ) then
			local ok, r = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", b.slotId);
			has = ok and r;
		end
		if ( not has ) then
			GameTooltip:AddLine(SLOTNAME[slotName] or slotName, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			GameTooltip:AddLine("Empty", 0.6, 0.6, 0.6);
		end
		GameTooltip:Show();
	end);
	b:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	return b;
end

local function RefreshSlot(b)
	if ( not b.slotId ) then
		return;
	end
	local tex = nil;
	if ( GetInventoryItemTexture ) then
		tex = GetInventoryItemTexture("player", b.slotId);
	end
	local link = nil;
	if ( tex and GetInventoryItemLink ) then
		link = GetInventoryItemLink("player", b.slotId);
	end
	local sig = tostring(tex) .. "|" .. tostring(link);
	if ( sig ~= b.sig ) then
		b.sig = sig;
		b.hasItem = tex and true or false;
		if ( tex ) then
			b.icon:SetTexture(tex);
			b.icon:SetVertexColor(1, 1, 1, 1);
			local r, g, bl = LinkColor(link);
			if ( r ) then
				G.EdgeColor(b, r, g, bl, 1);
			else
				G.EdgeColor(b, 0.62, 0.62, 0.66, 1);
			end
		else
			if ( b.emptyTex ) then
				b.icon:SetTexture(b.emptyTex);
			else
				b.icon:SetTexture(G.WHITE);
			end
			b.icon:SetVertexColor(0.55, 0.55, 0.6, 0.55);
			G.EdgeColor(b, 0.30, 0.28, 0.28, 1);
		end
	end
	local n = 0;
	if ( tex and GetInventoryItemCount ) then
		n = G.Num(GetInventoryItemCount("player", b.slotId));
	end
	if ( n > 1 ) then
		b.count:SetText(tostring(n));
	else
		b.count:SetText("");
	end
end

------------------------------------------------------------------------ the attributes

-- every stat the game's character pane shows (AZS_STATS), with how to write it. The value formats are
-- guesses from the names (the API says what a key is, not how it is scaled); the tooltip of each stat shows
-- the raw number, so a wrong guess is easy to spot and to report.
local OFFENSE, DEFENSE, UTILITY = 1, 2, 3;

local TINT = {
	{ 0.98, 0.68, 0.40 },        -- offense: warm
	{ 0.60, 0.80, 0.97 },        -- defense: cool
	{ 0.74, 0.90, 0.52 },        -- utility: green
	{ 0.80, 0.80, 0.84 },        -- anything else
};
local GROUPNAME = { "Offense", "Defense", "Utility", "Other" };

local STATS = {
	{ "dmg", "Damage", "mult", 0, OFFENSE, "Damage multiplier" },
	{ "crit", "Crit Chance", "pct", 1, OFFENSE, "Chance to hit critically" },
	{ "cm", "Crit Damage", "mult", 2, OFFENSE, "Critical hit multiplier" },
	{ "cd", "CDR", "cut", 3, OFFENSE, "How much shorter your cooldowns are", "Cooldown Reduction" },
	{ "spd", "Speed", "mult", 4, OFFENSE, "Speed" },
	{ "area", "Area", "mult", 5, OFFENSE, "Area of effect" },
	{ "cnt", "Extra Targets", "num", 6, OFFENSE, "Extra targets of your spells" },
	{ "echo", "Echo", "pct", 7, OFFENSE, "Echo" },
	{ "hp", "Health", "num", 8, DEFENSE, "Maximum health" },
	{ "arm", "Armor", "pct", 9, DEFENSE, "Damage reduction" },
	{ "reg", "Regeneration", "rate", 10, DEFENSE, "Health per second" },
	{ "lch", "Leech", "pct", 11, DEFENSE, "Share of the damage you deal that heals you" },
	{ "thn", "Thorns", "num", 12, DEFENSE, "Damage returned to attackers" },
	{ "heal", "Heal on Kill", "num", 13, DEFENSE, "Health restored per kill" },
	{ "liv", "Extra Lives", "num", 14, DEFENSE, "Extra lives" },
	{ "pick", "Pickup Range", "num", 15, UTILITY, "How far pickups are drawn to you" },
	{ "xp", "Experience", "mult", 16, UTILITY, "Experience gained" },
	{ "luck", "Luck", "pct", 17, UTILITY, "Luck" },
	{ "gold", "Gold", "mult", 18, UTILITY, "Gold gained" },
};
local KNOWN = {};
for i = 1, table.getn(STATS) do
	KNOWN[STATS[i][1]] = STATS[i];
end

-- a stat is "from gear" when it starts with g and the rest is a stat (ghp -> hp); "gold" is not "g" + "old"
local function GearBase(key, st)
	if ( string.len(key) > 1 and string.sub(key, 1, 1) == "g" ) then
		local base = string.sub(key, 2);
		if ( KNOWN[base] or ( st and st[base] ~= nil ) ) then
			return base;
		end
	end
	return nil;
end

-- 1.50 -> 1.5, 2.00 -> 2 (only digits after a decimal point are cut)
local function Trim(s)
	if ( string.find(s, ".", 1, true) ) then
		s = string.gsub(s, "0+$", "");
		s = string.gsub(s, "%.$", "");
	end
	return s;
end

local function Plain(v)
	local a = math.abs(v);
	if ( a >= 100000 ) then
		return G.Short(v);
	elseif ( a >= 1000 ) then
		return G.Comma(v);
	elseif ( a >= 100 ) then
		return Trim(string.format("%.1f", v));
	end
	return Trim(string.format("%.2f", v));
end

local FORMAT = {
	num = Plain,
	-- chances and shares are fractions (0.4 = 40%, leech 0.005 = 0.5%); a number above 10 can only be
	-- a percentage already (a fraction of 1000% does not exist), so it is not multiplied again
	pct = function(v)
		if ( math.abs(v) <= 10 ) then
			v = v * 100;
		end
		return Trim(string.format("%.1f", v)) .. "%";
	end,
	-- the API gives the cooldown multiplier (0.62 = cooldowns take 62% as long); shown as the cut: 38%
	cut = function(v)
		if ( math.abs(v) > 10 ) then
			return Trim(string.format("%.1f", v)) .. "%";
		end
		return Trim(string.format("%.1f", ( 1 - v ) * 100)) .. "%";
	end,
	mult = function(v)
		if ( math.abs(v) >= 10 ) then
			return Trim(string.format("%.0f", v)) .. "%";
		end
		return "x" .. Trim(string.format("%.2f", v));
	end,
	rate = function(v)
		return Trim(string.format("%.1f", v)) .. "/s";
	end,
};

local function Write(kind, v)
	return ( FORMAT[kind] or Plain )(v);
end

local function SetIcon(cell, index, group)
	local t = TINT[group] or TINT[4];
	if ( G.art.custom ) then
		local col, row = math.mod(index, 8), math.floor(index / 8);
		cell.icon:SetTexture(G.TEXPATH .. "stat_icons.tga");
		cell.icon:SetTexCoord(col / 8, (col + 1) / 8, row / 4, (row + 1) / 4);
		cell.icon:SetVertexColor(t[1], t[2], t[3], 1);
	else
		cell.icon:SetTexture(G.WHITE);
		cell.icon:SetTexCoord(0, 1, 0, 1);
		cell.icon:SetVertexColor(t[1], t[2], t[3], 0.9);
	end
end

local function NewCell(panel)
	local c = CreateFrame("Frame", nil, panel);
	c:SetWidth(COLW - 8);
	c:SetHeight(ROWH - 1);
	c.icon = c:CreateTexture(nil, "ARTWORK");
	c.icon:SetWidth(16);
	c.icon:SetHeight(16);
	c.icon:SetPoint("LEFT", c, "LEFT", 0, 0);
	c.label = G.TextS(c, 11, "LEFT");
	c.label:SetPoint("LEFT", c, "LEFT", 21, 0);
	c.label:SetTextColor(0.78, 0.78, 0.80);
	c.value = G.TextS(c, 12, "RIGHT");
	c.value:SetPoint("RIGHT", c, "RIGHT", 0, 0);
	c.value:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	local hl = G.Solid(c, "BACKGROUND", 1, 1, 1, 0.0);
	hl:SetAllPoints(c);
	c.hl = hl;
	G.Tooltip(c, function(tt)
		local e = c.entry;
		if ( not e ) then
			return;
		end
		tt:AddLine(e.title or e.label, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		if ( e.tip and e.tip ~= "" ) then
			tt:AddLine(e.tip, 0.72, 0.72, 0.76);
		end
		tt:AddLine(c.value:GetText() or "", 1, 1, 1);
		if ( e.fmt == "mult" and math.abs(e.v) < 10 ) then
			tt:AddLine("= " .. Trim(string.format("%.0f", e.v * 100)) .. "% of the normal value", 0.72, 0.72, 0.76);
		end
		if ( e.fmt == "cut" and math.abs(e.v) <= 10 ) then
			tt:AddLine("Cooldowns take " .. Trim(string.format("%.0f", e.v * 100)) .. "% as long", 0.72, 0.72, 0.76);
		end
		if ( e.gear and e.gear ~= 0 ) then
			if ( e.fmt == "cut" and math.abs(e.gear) <= 10 ) then
				tt:AddLine("From gear: " .. Trim(string.format("%.1f", math.abs(e.gear) * 100)) .. "%", 0.6, 1, 0.6);
			else
				tt:AddLine("From gear: " .. Write(e.fmt, e.gear), 0.6, 1, 0.6);
			end
		end
		tt:AddLine(e.key .. " = " .. tostring(e.raw), 0.5, 0.5, 0.5);
	end, "ANCHOR_LEFT");
	c:Hide();
	return c;
end

local function NewHead(panel)
	local h = {};
	h.text = G.Text(panel, 11, "LEFT");
	h.text:SetTextColor(G.GOLD[1], G.GOLD[2], G.GOLD[3]);
	h.line = G.Band(panel, "ARTWORK", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.55);
	h.line:SetHeight(1);
	h.text:Hide();
	h.line:Hide();
	return h;
end

-- which stats are present, in what groups; extras the list does not know are put last (never gear sums)
local function Collect()
	local st = AZS_STATS;
	local groups = { {}, {}, {}, {} };
	if ( type(st) ~= "table" ) then
		return groups;
	end
	for i = 1, table.getn(STATS) do
		local s = STATS[i];
		local raw = st[s[1]];
		local v = tonumber(raw);
		if ( v ) then
			local gv = tonumber(st["g" .. s[1]]);
			table.insert(groups[s[5]], { key = s[1], label = s[2], fmt = s[3], icon = s[4], group = s[5],
				tip = s[6], title = s[7], v = v, raw = raw, gear = gv });
		end
	end
	local extra = {};
	for k, raw in pairs(st) do
		if ( type(k) == "string" and not KNOWN[k] and not GearBase(k, st) and tonumber(raw) ) then
			table.insert(extra, k);
		end
	end
	table.sort(extra);
	for i = 1, table.getn(extra) do
		local k = extra[i];
		table.insert(groups[4], { key = k, label = string.upper(string.sub(k, 1, 1)) .. string.sub(k, 2), fmt = "num",
			icon = 19, group = 4, tip = "", v = tonumber(st[k]), raw = st[k], gear = tonumber(st["g" .. k]) });
	end
	return groups;
end

-- lays the cells out when the set of stats changed, then writes the values
function G.RefreshAttributes()
	local p = G.charPanel and G.charPanel.attr;
	if ( not p ) then
		return;
	end
	local groups = Collect();
	local sig = "";
	for g = 1, 4 do
		for i = 1, table.getn(groups[g]) do
			sig = sig .. groups[g][i].key .. ",";
		end
		sig = sig .. "/";
	end
	if ( sig ~= p.sig ) then
		p.sig = sig;
		for i = 1, table.getn(p.cells) do
			p.cells[i]:Hide();
			p.cells[i].entry = nil;
		end
		for i = 1, table.getn(p.heads) do
			p.heads[i].text:Hide();
			p.heads[i].line:Hide();
		end
		local y = 34;                         -- below the "Attributes" title
		local ci, any = 0, false;
		for g = 1, 4 do
			local list = groups[g];
			local n = table.getn(list);
			local rows = math.ceil(n / 2);
			if ( n > 0 and y + HEADH + rows * ROWH <= AH - 4 ) then
				any = true;
				local h = p.heads[g];
				h.text:ClearAllPoints();
				h.text:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -y);
				h.text:SetText(GROUPNAME[g]);
				h.text:Show();
				h.line:ClearAllPoints();
				h.line:SetPoint("TOPLEFT", p, "TOPLEFT", 12 + 62, -(y + 6));
				h.line:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -(y + 6));
				h.line:Show();
				y = y + HEADH;
				for i = 1, n do
					ci = ci + 1;
					local cell = p.cells[ci];
					if ( not cell ) then
						cell = NewCell(p);
						p.cells[ci] = cell;
					end
					local col, row = math.mod(i - 1, 2), math.floor((i - 1) / 2);
					cell:ClearAllPoints();
					cell:SetPoint("TOPLEFT", p, "TOPLEFT", 12 + col * COLW, -(y + row * ROWH));
					cell.entry = list[i];
					cell.label:SetText(list[i].label);
					SetIcon(cell, list[i].icon, list[i].group);
					cell.last = nil;
					cell:Show();
				end
				y = y + rows * ROWH + 4;
			end
		end
		p.empty:SetText(any and "" or "No attributes yet.");
	end
	-- values (only text that changed is written)
	for g = 1, 4 do
		for i = 1, table.getn(groups[g]) do
			local e = groups[g][i];
			for ci = 1, table.getn(p.cells) do
				local cell = p.cells[ci];
				if ( cell.entry and cell.entry.key == e.key ) then
					cell.entry = e;
					local txt = Write(e.fmt, e.v);
					if ( cell.last ~= txt ) then
						cell.last = txt;
						cell.value:SetText(txt);
					end
					if ( e.gear and e.gear ~= 0 ) then
						cell.value:SetTextColor(0.62, 1, 0.62);
					else
						cell.value:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
					end
					break;
				end
			end
		end
	end
end

------------------------------------------------------------------------ the panel

local function HexColor(r, g, b)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5));
end

function G.RefreshCharacterHeader()
	local f = G.charPanel;
	if ( not f ) then
		return;
	end
	local z = AZS_ZONE or {};
	local run = AZS_RUN or {};
	local name = z.hero;
	if ( ( not name or name == "" ) and UnitName ) then
		name = UnitName("player");
	end
	name = G.Esc(name or "Hero");
	if ( f.nameText:GetText() ~= name ) then
		f.nameText:SetText(name);
	end
	local r, g, b = G.ClassColor(z.class);
	local race = G.Esc(z.rname or z.race or "");
	local class = G.Esc(z.cname or z.class or "");
	local line = "Level " .. math.floor(G.Num(run.lvl)) .. "  " .. race .. "  " .. HexColor(r, g, b) .. class .. "|r";
	if ( f.levelText:GetText() ~= line ) then
		f.levelText:SetText(line);
	end
end

function G.UpdateCharacter(dt)
	local f = G.charPanel;
	if ( not f or not f:IsShown() ) then
		return;
	end
	G.RefreshCharacterHeader();
	G.RefreshAttributes();
	for i = 1, table.getn(f.slots) do
		RefreshSlot(f.slots[i]);
	end
	G.LayoutWeapons();
end

local function Close()
	if ( G.charPanel ) then
		G.charPanel:Hide();
	end
end

function G.ToggleCharPanel(force)
	local f = G.charPanel;
	if ( not f ) then
		return false;
	end
	local want;
	if ( force == nil ) then
		want = not f:IsShown();
	else
		want = force and true or false;
	end
	if ( want ) then
		if ( CharacterFrame and CharacterFrame:IsShown() ) then
			Safe(HideUIPanel, CharacterFrame);
		end
		f:Show();
	else
		f:Hide();
	end
	return true;
end

-- the panel stands in for the game's window during a run, with this UI and the option on
function G.CharActive()
	return AZSGW2DB and AZSGW2DB.enabled and G.started and G.shown and G.Opt("charPanel") and G.charPanel ~= nil;
end

local function Heading(parent, text, x, y)
	local t = G.Text(parent, 11, "LEFT");
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	t:SetText(text);
	t:SetTextColor(G.GOLD[1], G.GOLD[2], G.GOLD[3]);
	return t;
end

local function PlaceSlots(f, names, size, x0, y0, perRow, gap)
	for i = 1, table.getn(names) do
		local b = NewSlot(f, names[i], size);
		local col, row = math.mod(i - 1, perRow), math.floor((i - 1) / perRow);
		b:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + col * (size + gap), y0 - row * (size + gap));
		table.insert(f.slots, b);
	end
end

-- weapons: only the ones the hero holds are shown, side by side from the left; the title goes when there is none
local WSIZE, WGAP, WX, WY = 38, 8, 18, -474;
function G.LayoutWeapons()
	local f = G.charPanel;
	if ( not f or not f.weapons ) then
		return;
	end
	local sig = "";
	for i = 1, table.getn(f.weapons) do
		if ( f.weapons[i].hasItem ) then
			sig = sig .. "1";
		else
			sig = sig .. "0";
		end
	end
	if ( sig == f.weaponSig ) then
		return;
	end
	f.weaponSig = sig;
	local n = 0;
	for i = 1, table.getn(f.weapons) do
		local b = f.weapons[i];
		if ( b.hasItem ) then
			b:ClearAllPoints();
			b:SetPoint("TOPLEFT", f, "TOPLEFT", WX + n * (WSIZE + WGAP), WY);
			b:Show();
			n = n + 1;
		else
			b:Hide();
		end
	end
	if ( n > 0 ) then
		f.weaponHead:Show();
	else
		f.weaponHead:Hide();
	end
end

function G.BuildCharacter()
	local f = CreateFrame("Frame", "AZSGW2Char", UIParent);
	f:SetWidth(W);
	f:SetHeight(H);
	f:SetPoint("LEFT", UIParent, "LEFT", 14, 10);          -- at the left edge, the middle of the screen stays free
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
	f.azs = true;
	f.slots = {};
	G.charPanel = f;
	-- the window never needs to be bigger than the screen
	if ( UIParent.GetHeight and UIParent:GetHeight() and UIParent:GetHeight() > 0 and UIParent:GetHeight() < H + 40 ) then
		f:SetScale(UIParent:GetHeight() / ( H + 40 ));
	end

	local bg = G.Solid(f, "BACKGROUND", 0.04, 0.04, 0.05, 0.97);
	bg:SetAllPoints(f);
	G.Frame9(f, "BORDER");

	local title = G.Text(f, 15, "LEFT");
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -14);
	title:SetText("Hero");
	title:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
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
	x:SetScript("OnClick", Close);
	x:SetScript("OnEnter", function()
		xbg:SetVertexColor(0.30, 0.10, 0.10, 0.95);
	end);
	x:SetScript("OnLeave", function()
		xbg:SetVertexColor(0.10, 0.09, 0.10, 0.95);
	end);

	-- left: every piece of gear in a column beside the model
	PlaceSlots(f, GEAR, 32, 18, -56, 1, 4);

	local mp = CreateFrame("Frame", nil, f);
	mp:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -52);
	mp:SetWidth(238);
	mp:SetHeight(396);
	G.Panel(mp, 0.55);
	f.modelBox = mp;
	local okm, model = pcall(CreateFrame, "PlayerModel", nil, mp);
	if ( okm and model ) then
		model:SetPoint("TOPLEFT", mp, "TOPLEFT", 2, -2);
		model:SetPoint("BOTTOMRIGHT", mp, "BOTTOMRIGHT", -2, 2);
		f.model = model;
		model.rot = 0.61;
		Safe(model.SetUnit, model, "player");
		Safe(model.SetRotation, model, model.rot);
		model:EnableMouse(true);
		model:SetScript("OnMouseDown", function()
			if ( arg1 == "LeftButton" and GetCursorPosition ) then
				model.dragX = GetCursorPosition();
				model:SetScript("OnUpdate", function()
					if ( not IsMouseButtonDown or IsMouseButtonDown("LeftButton") ) then
						local cx = GetCursorPosition();
						model.rot = model.rot + ( cx - model.dragX ) * 0.012;
						model.dragX = cx;
						Safe(model.SetRotation, model, model.rot);
					else
						model:SetScript("OnUpdate", nil);
					end
				end);
			end
		end);
		model:SetScript("OnMouseUp", function()
			model:SetScript("OnUpdate", nil);
		end);
	end

	-- under the model: the weapons the hero holds (none held: no title, no slots)
	f.weaponHead = Heading(f, "Weapons", 18, -456);
	f.weaponHead:Hide();
	f.weapons = {};
	for i = 1, table.getn(WEAPONS) do
		local b = NewSlot(f, WEAPONS[i], WSIZE);
		b:Hide();
		table.insert(f.slots, b);
		table.insert(f.weapons, b);
	end

	-- right: name, level, the attributes
	f.nameText = G.Text(f, 20, "LEFT");
	f.nameText:SetPoint("TOPLEFT", f, "TOPLEFT", RX, -46);
	f.nameText:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	f.nameText:SetText("");
	f.levelText = G.TextS(f, 12, "LEFT");
	f.levelText:SetPoint("TOPLEFT", f, "TOPLEFT", RX, -70);
	f.levelText:SetTextColor(0.90, 0.90, 0.92);
	f.levelText:SetText("");

	local ap = CreateFrame("Frame", nil, f);
	ap:SetPoint("TOPLEFT", f, "TOPLEFT", RX, -92);
	ap:SetWidth(W - RX - 18);
	ap:SetHeight(AH);
	G.Panel(ap, 0.5);
	local at = G.Text(ap, 14, "LEFT");
	at:SetPoint("TOPLEFT", ap, "TOPLEFT", 12, -9);
	at:SetText("Attributes");
	at:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	local al = G.Band(ap, "ARTWORK", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.8);
	al:SetPoint("TOPLEFT", ap, "TOPLEFT", 10, -28);
	al:SetPoint("TOPRIGHT", ap, "TOPRIGHT", -10, -28);
	al:SetHeight(1);
	ap.cells = {};
	ap.heads = {};
	for g = 1, 4 do
		ap.heads[g] = NewHead(ap);
	end
	ap.empty = G.TextS(ap, 11, "CENTER");
	ap.empty:SetPoint("CENTER", ap, "CENTER", 0, 0);
	ap.empty:SetTextColor(0.6, 0.6, 0.64);
	ap.empty:SetText("");
	f.attr = ap;

	-- right, below: accessories
	Heading(f, "Accessories", RX, -452);
	PlaceSlots(f, ACCESS, 40, RX, -468, 5, 12);

	f:SetScript("OnShow", function()
		Safe(PlaySound, "igCharacterInfoOpen");
		if ( f.model ) then
			Safe(f.model.SetUnit, f.model, "player");
			Safe(f.model.SetRotation, f.model, f.model.rot or 0.61);
		end
		for i = 1, table.getn(f.slots) do
			f.slots[i].sig = "?";
		end
		G.UpdateCharacter(0);
	end);
	f:SetScript("OnHide", function()
		Safe(PlaySound, "igCharacterInfoClose");
		GameTooltip:Hide();
	end);
	if ( UISpecialFrames ) then
		table.insert(UISpecialFrames, "AZSGW2Char");
	end

	G.HookCharacter();
end

-- the game's window: ToggleCharacter (the key binding, the old micro button) and its OnShow
function G.HookCharacter()
	if ( G.charHooked ) then
		return;
	end
	G.charHooked = true;
	if ( type(ToggleCharacter) == "function" ) then
		local orig = ToggleCharacter;
		G.origToggleCharacter = orig;
		ToggleCharacter = function(tab, a, b, c)
			if ( ( tab == nil or tab == "PaperDollFrame" ) and G.CharActive() ) then
				G.ToggleCharPanel();
				return;
			end
			if ( G.charPanel and G.charPanel:IsShown() ) then
				G.charPanel:Hide();           -- another tab asked for: ours steps aside
			end
			return orig(tab, a, b, c);
		end
	end
	if ( CharacterFrame and CharacterFrame.GetScript and CharacterFrame.SetScript ) then
		local orig = CharacterFrame:GetScript("OnShow");
		G.origCharacterOnShow = orig;
		CharacterFrame:SetScript("OnShow", function()
			local tab = CharacterFrame.selectedTab;
			if ( G.CharActive() and ( tab == nil or tab == 1 ) ) then
				Safe(HideUIPanel, CharacterFrame);
				if ( CharacterFrame:IsShown() ) then
					CharacterFrame:Hide();
				end
				G.ToggleCharPanel(true);
				return;
			end
			if ( orig ) then
				orig();
			end
		end);
	end
end

-- /gw2 stats: everything AZS_STATS holds, to check the formats or to report a wrong label
function G.PrintStats()
	local st = AZS_STATS;
	if ( type(st) ~= "table" ) then
		G.Print("AZS_STATS is not there (no run yet?).");
		return;
	end
	local keys = {};
	for k in pairs(st) do
		if ( type(k) == "string" ) then
			table.insert(keys, k);
		end
	end
	table.sort(keys);
	local line = "";
	for i = 1, table.getn(keys) do
		local k = keys[i];
		local part = k .. "=" .. tostring(st[k]);
		if ( string.len(line) + string.len(part) > 90 ) then
			G.Print(line);
			line = "";
		end
		line = line .. part .. "  ";
	end
	if ( line ~= "" ) then
		G.Print(line);
	end
end
