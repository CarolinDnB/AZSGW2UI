-- AZS GW2 UI: Minimap.lua
-- The game's minimap in a square steel frame with a zone plate, zoom buttons and our own pins for
-- caches (chests), guardian lairs and downed friends. The terrain is still drawn by the game's own
-- Minimap frame; we move it into our frame and give it a square mask. Pins are placed from world
-- positions (AZS_GetPlayerPosition / AZS_CHESTS / AZS_GetLairs): +x is north, +y west, the map
-- is north-up.

local G = AZSGW2;

local SIZE = 160;
local CHESTS, LAIRS, DOWNED = 12, 12, 4;

-- yards across the minimap per zoom level (1.12): outdoors and indoors
local YARDS_OUT = { [0] = 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 };
local YARDS_IN = { [0] = 300, 240, 180, 120, 80, 50 };

-- pins: cell numbers in mm_icons.tga (4 x 4 cells)
local CELL = { chest = 0, asleep = 1, awake = 2, empty = 3, downed = 4 };

-- stock minimap pieces hidden while ours is up (each skipped if it does not exist)
G.MINIMAP_HIDE = {
	"MinimapBackdrop", "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MinimapToggleButton",
	"MinimapZoneTextButton", "GameTimeFrame", "MiniMapTracking", "MiniMapMailFrame", "MiniMapBattlefieldFrame",
	"MinimapBorder", "MinimapBorderTop",
};

------------------------------------------------------------------------ zoom / scale

function G.MapZoom(delta)
	local mm = Minimap;
	if ( not mm or not mm.GetZoom ) then
		return;
	end
	local maxz = 4;
	if ( mm.GetZoomLevels ) then
		maxz = mm:GetZoomLevels() - 1;
	end
	local z = G.Clamp(mm:GetZoom() + delta, 0, maxz);
	mm:SetZoom(z);
	G.yardsStamp = nil;
end

-- yards across the map right now. Indoor and outdoor zoom are two settings; which one is in use
-- is found the way map addons do it: make the two CVars differ, set a zoom, see which one moved.
-- Setting the zoom makes the game redraw the whole minimap, so this is done as rarely as possible: once
-- per zoom level and map, and then again only every 20 seconds.
function G.MapYards(space)
	if ( AZSGW2DB and AZSGW2DB.mapYards ) then
		return AZSGW2DB.mapYards;
	end
	local now = GetTime();
	if ( G.yardsStamp and now - G.yardsStamp < 20 and G.yardsZoom == ( Minimap and Minimap:GetZoom() )
		and ( space == nil or G.yardsSpace == space ) ) then
		return G.yards;
	end
	local mm = Minimap;
	if ( not mm or not mm.GetZoom ) then
		return YARDS_OUT[3];
	end
	local zoom = mm:GetZoom();
	local indoors = false;
	if ( GetCVar and mm.SetZoom ) then
		if ( GetCVar("minimapInsideZoom") == GetCVar("minimapZoom") ) then
			if ( zoom < 2 ) then
				mm:SetZoom(zoom + 1);
			else
				mm:SetZoom(zoom - 1);
			end
		end
		indoors = ( tonumber(GetCVar("minimapInsideZoom")) == mm:GetZoom() );
		mm:SetZoom(zoom);
	end
	local table_ = YARDS_OUT;
	if ( indoors ) then
		table_ = YARDS_IN;
	end
	G.yards = table_[zoom] or table_[3];
	G.yardsStamp = now;
	G.yardsZoom = zoom;
	G.yardsSpace = space;
	G.indoors = indoors;
	return G.yards;
end

------------------------------------------------------------------------ build

local function NewPin(parent, kind)
	local p = CreateFrame("Frame", nil, parent);
	p:SetWidth(16);
	p:SetHeight(16);
	p:SetFrameLevel(parent:GetFrameLevel() + 2);
	local t = p:CreateTexture(nil, "ARTWORK");
	t:SetTexture(G.TEXPATH .. "mm_icons.tga");
	t:SetAllPoints(p);
	p.icon = t;
	p.kind = kind;
	G.Tooltip(p, function(tt)
		if ( p.title ) then
			tt:AddLine(p.title, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			if ( p.text ) then
				tt:AddLine(p.text, 0.85, 0.85, 0.85);
			end
		end
	end, "ANCHOR_LEFT");
	p:Hide();
	return p;
end

local function SetCell(tex, cell)
	local col, row = math.mod(cell, 4), math.floor(cell / 4);
	tex:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4);
end

function G.BuildMinimap()
	local f = CreateFrame("Frame", "AZSGW2Minimap", UIParent);
	f:SetWidth(SIZE + 8);
	f:SetHeight(SIZE + 8);
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -34);
	f:SetFrameStrata("LOW");
	G.RegisterAlways(f);
	G.mm = f;
	G.Movable(f, "minimap", "Minimap");

	-- the square the game's Minimap frame is moved into
	local holder = CreateFrame("Frame", nil, f);
	holder:SetWidth(SIZE);
	holder:SetHeight(SIZE);
	holder:SetPoint("CENTER", f, "CENTER", 0, 0);
	local back = G.Solid(holder, "BACKGROUND", 0.02, 0.02, 0.03, 1);
	back:SetAllPoints(holder);
	f.holder = holder;

	-- steel frame on top of the map
	local frame = CreateFrame("Frame", nil, f);
	frame:SetAllPoints(f);
	frame:SetFrameLevel(f:GetFrameLevel() + 4);
	G.Frame9(frame, "OVERLAY");
	f.frame = frame;

	-- zone plate above the map: zone name, local time
	local plate = CreateFrame("Frame", nil, f);
	plate:SetWidth(SIZE + 8);
	plate:SetHeight(18);
	plate:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 1);
	G.Panel(plate, 0.9);
	f.zone = G.Text(plate, 11, "LEFT");
	f.zone:SetPoint("LEFT", plate, "LEFT", 6, 0);
	f.zone:SetWidth(SIZE - 50);
	f.zone:SetHeight(12);
	f.zone:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	f.clock = G.Text(plate, 11, "RIGHT");
	f.clock:SetPoint("RIGHT", plate, "RIGHT", -6, 0);
	f.plate = plate;

	-- zoom buttons, lower right inside the map
	local function ZoomButton(text, delta, y)
		local b = CreateFrame("Button", nil, f);
		b:SetWidth(18);
		b:SetHeight(18);
		b:SetFrameLevel(f:GetFrameLevel() + 6);
		b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, y);
		G.Panel(b, 0.85);
		local t = G.Text(b, 14, "CENTER");
		t:SetPoint("CENTER", b, "CENTER", 0, 1);
		t:SetText(text);
		b:SetScript("OnClick", function()
			G.MapZoom(delta);
		end);
		return b;
	end
	f.zoomIn = ZoomButton("+", 1, 28);
	f.zoomOut = ZoomButton("-", -1, 8);

	-- pins
	local pins = CreateFrame("Frame", nil, f);
	pins:SetAllPoints(holder);
	pins:SetFrameLevel(f:GetFrameLevel() + 5);
	f.pins = pins;
	-- you: a light arrow in the middle that turns with the hero (the map itself keeps north up)
	local me = pins:CreateTexture(nil, "OVERLAY");
	me:SetTexture(G.TEXPATH .. "arrows.tga");
	me:SetWidth(24);
	me:SetHeight(24);
	me:SetPoint("CENTER", holder, "CENTER", 0, 0);
	me:SetVertexColor(1, 0.93, 0.55, 1);
	me:Hide();
	f.me = me;
	f.chestPins, f.lairPins, f.downPins = {}, {}, {};
	for i = 1, CHESTS do
		f.chestPins[i] = NewPin(pins, "chest");
		SetCell(f.chestPins[i].icon, CELL.chest);
	end
	for i = 1, LAIRS do
		f.lairPins[i] = NewPin(pins, "lair");
	end
	for i = 1, DOWNED do
		f.downPins[i] = NewPin(pins, "downed");
		SetCell(f.downPins[i].icon, CELL.downed);
	end

	G.ApplyMinimap();
end

------------------------------------------------------------------------ move the game's minimap in / out

local function HideRegion(name)
	local r = getglobal(name);
	if ( r and r.Hide and not r.GetScript ) then
		r:Hide();
	end
end

function G.AttachMinimap()
	local mm = Minimap;
	local f = G.mm;
	if ( not f or not mm or not mm.SetParent ) then
		return false;
	end
	if ( not G.mmOrig ) then
		local o = { parent = mm:GetParent(), w = mm:GetWidth(), h = mm:GetHeight(), points = {} };
		if ( mm.GetNumPoints ) then
			for i = 1, mm:GetNumPoints() do
				local point, rel, relPoint, x, y = mm:GetPoint(i);
				table.insert(o.points, { point, rel, relPoint, x, y });
			end
		else
			local point, rel, relPoint, x, y = mm:GetPoint();
			if ( point ) then
				table.insert(o.points, { point, rel, relPoint, x, y });
			end
		end
		G.mmOrig = o;
	end
	mm:SetParent(f.holder);
	mm:ClearAllPoints();
	mm:SetPoint("CENTER", f.holder, "CENTER", 0, 0);
	mm:SetWidth(SIZE);
	mm:SetHeight(SIZE);
	mm:SetFrameLevel(f.holder:GetFrameLevel() + 1);
	if ( mm.SetMaskTexture ) then
		mm:SetMaskTexture(G.TEXPATH .. "mm_mask.tga");
	end
	if ( mm.EnableMouseWheel ) then
		mm:EnableMouseWheel(true);
		mm:SetScript("OnMouseWheel", function()
			if ( arg1 and arg1 > 0 ) then
				G.MapZoom(1);
			else
				G.MapZoom(-1);
			end
		end);
	end
	G.mmAttached = true;
	G.KeepMinimapQuiet();
	return true;
end

-- the stock minimap pieces stay hidden; the cluster only once the map itself is safely in our frame
function G.KeepMinimapQuiet()
	if ( not G.mmAttached ) then
		return;
	end
	for i = 1, table.getn(G.MINIMAP_HIDE) do
		local name = G.MINIMAP_HIDE[i];
		G.KeepHidden(name);
		HideRegion(name);
	end
	local mm = Minimap;
	if ( mm and mm:GetParent() ~= G.mm.holder ) then
		mm:SetParent(G.mm.holder);       -- the game moved it back
		mm:ClearAllPoints();
		mm:SetPoint("CENTER", G.mm.holder, "CENTER", 0, 0);
	end
	if ( mm and mm:GetParent() == G.mm.holder ) then
		G.KeepHidden("MinimapCluster");
	end
end

function G.DetachMinimap()
	local mm = Minimap;
	local o = G.mmOrig;
	if ( mm and o and G.mmAttached ) then
		G.RestoreHiddenList(G.MINIMAP_HIDE);
		G.RestoreHiddenList({ "MinimapCluster" });
		mm:SetParent(o.parent or UIParent);
		mm:ClearAllPoints();
		for i = 1, table.getn(o.points) do
			local p = o.points[i];
			mm:SetPoint(p[1], p[2], p[3], p[4], p[5]);
		end
		mm:SetWidth(o.w or 140);
		mm:SetHeight(o.h or 140);
		if ( mm.SetMaskTexture ) then
			mm:SetMaskTexture("Textures\\MinimapMask");
		end
	end
	G.mmAttached = false;
end

-- on / off by option and by /gw2 off | on
function G.ApplyMinimap()
	local f = G.mm;
	if ( not f ) then
		return;
	end
	local want = ( AZSGW2DB.enabled and G.Opt("minimap") ) and true or false;
	if ( want ) then
		f:Show();
		if ( not G.mmAttached ) then
			G.AttachMinimap();
		end
		G.mapActive = true;
		G.HideGameHud(true);
	else
		if ( G.mmAttached ) then
			G.DetachMinimap();
		end
		f:Hide();
		if ( G.mapActive and AZS_SetHudShown ) then
			for i = 1, table.getn(G.HUD_MAP_PARTS) do
				AZS_SetHudShown(G.HUD_MAP_PARTS[i], true);
			end
		end
		G.mapActive = false;
	end
end

------------------------------------------------------------------------ update

local function Place(pin, holder, p, x, y, ppy, half)
	local dx, dy = x - p.x, y - p.y;
	local px, py = -dy * ppy, dx * ppy;
	local m = math.max(math.abs(px), math.abs(py));
	local edge = false;
	if ( m > half ) then
		px, py = px * half / m, py * half / m;
		edge = true;
	end
	pin:ClearAllPoints();
	pin:SetPoint("CENTER", holder, "CENTER", px, py);
	if ( edge ) then
		pin:SetAlpha(0.6);
	else
		pin:SetAlpha(1);
	end
	pin:Show();
	return math.sqrt(dx * dx + dy * dy);
end

local function HidePins(list, from)
	for i = from, table.getn(list) do
		list[i]:Hide();
	end
end

function G.UpdateMinimap(dt)
	local f = G.mm;
	if ( not f or not f:IsShown() ) then
		return;
	end

	-- zone name and time, about once a second
	f.t = ( f.t or 0 ) + dt;
	if ( f.t > 1 or not f.zoneSet ) then
		f.t = 0;
		f.zoneSet = true;
		local zone = ( GetMinimapZoneText and GetMinimapZoneText() ) or ( GetZoneText and GetZoneText() ) or "";
		if ( AZS_ZONE and AZS_ZONE.zname and AZS_ZONE.zname ~= "" and G.Phase() ~= nil ) then
			zone = AZS_ZONE.zname;
		end
		f.zone:SetText(zone);
		local clock = "";
		if ( AZS_GetLocalTime ) then
			local c = AZS_GetLocalTime();
			if ( c and c.text ) then
				clock = c.text;
			end
		end
		f.clock:SetText(clock);
	end

	-- pins: 20 times a second is smooth enough, and keeps the API calls (positions, lairs, downed friends)
	-- off most frames
	f.pinT = ( f.pinT or 0 ) + dt;
	if ( f.pinT < 0.05 and f.pinsDone ) then
		return;
	end
	f.pinT = 0;
	f.pinsDone = true;
	local p = nil;
	if ( AZS_GetPlayerPosition and G.Phase() ~= nil ) then
		p = AZS_GetPlayerPosition();
	end
	if ( not p ) then
		f.me:Hide();
		HidePins(f.chestPins, 1);
		HidePins(f.lairPins, 1);
		HidePins(f.downPins, 1);
		return;
	end
	local holder = f.holder;
	G.SetArrow(f.me, p.facing or 0);
	f.me:Show();
	local ppy = SIZE / G.MapYards(p.spaceId);
	local half = SIZE / 2 - 8;

	-- caches
	local n = 0;
	if ( G.Opt("pinChest") and AZS_CHESTS ) then
		for i = 1, table.getn(AZS_CHESTS) do
			local c = AZS_CHESTS[i];
			if ( c.spaceId == p.spaceId and n < CHESTS ) then
				n = n + 1;
				local pin = f.chestPins[n];
				local dist = Place(pin, holder, p, c.x, c.y, ppy, half);
				pin.title = "Cache";
				pin.text = string.format("%d yd", math.floor(dist + 0.5));
			end
		end
	end
	HidePins(f.chestPins, n + 1);

	-- guardian lairs
	n = 0;
	if ( G.Opt("pinGuard") and AZS_GetLairs ) then
		local lairs = AZS_GetLairs();
		if ( lairs ) then
			for i = 1, table.getn(lairs) do
				local l = lairs[i];
				if ( l.spaceId == p.spaceId and n < LAIRS and l.x ) then
					n = n + 1;
					local pin = f.lairPins[n];
					local dist = Place(pin, holder, p, l.x, l.y, ppy, half);
					local cell = CELL.empty;
					local word = "Empty";
					if ( l.state == "awake" ) then
						cell = CELL.awake;
						word = "Fighting";
						pin:SetAlpha(0.65 + 0.35 * math.sin(GetTime() * 6));
					elseif ( l.state == "asleep" ) then
						cell = CELL.asleep;
						word = "Asleep";
					elseif ( G.Num(l.left) > 0 ) then
						word = "Respawns in " .. G.Clock(l.left);
					end
					SetCell(pin.icon, cell);
					pin.title = tostring(l.name or "Guardian");
					pin.text = word .. "  " .. string.format("%d yd", math.floor(dist + 0.5));
				end
			end
		end
	end
	HidePins(f.lairPins, n + 1);

	-- downed friends
	n = 0;
	if ( AZS_GetDownedPartyMembers ) then
		local list = AZS_GetDownedPartyMembers();
		if ( list ) then
			for i = 1, table.getn(list) do
				local d = list[i];
				if ( d.positionAvailable and d.spaceId == p.spaceId and n < DOWNED ) then
					n = n + 1;
					local pin = f.downPins[n];
					local dist = Place(pin, holder, p, d.x, d.y, ppy, half);
					pin.title = tostring(d.name or "Friend") .. " is down";
					pin.text = string.format("%d yd", math.floor(dist + 0.5));
				end
			end
		end
	end
	HidePins(f.downPins, n + 1);
end
