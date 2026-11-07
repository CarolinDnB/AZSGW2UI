-- AZS GW2 UI: Trackers.lua
-- The guardian tracker (GW2's objective list), the centre-screen banners and the Level Up! button.

local G = AZSGW2;

------------------------------------------------------------------------ guardian tracker

local LAIRROWS = 8;
local ROWH = 18;            -- one guardian: the line with the skull, the name and the distance
local BARROW = 14;          -- extra room under a guardian that is fighting: its health bar (12) and a gap (2)
local BARH = 12;
local BARX = 24;            -- the bar starts under the name

-- Where the health of the guardians is drawn: on the boss bar at the top (default), or as a bar with the percent under each
-- guardian on this list. Never both. The list is only used while it is shown: with the list switched off the boss bar
-- keeps the guardians, so their health is always somewhere.
function G.GuardianBarsOnList()
	return G.Opt("guardianBars") and G.Opt("guardians") and true or false;
end

-- for the guardians that are fighting (AZS_GetGuardians() entries): the lairs that show one, row by row, as
-- { [row] = guardian }, and the set of guardian ids that are shown in them. Empty while the bars are at the top.
function G.GuardianBars(guards)
	local rows, ids = {}, {};
	if ( not G.GuardianBarsOnList() or not AZS_GetLairs or G.UnitsStale() ) then
		return rows, ids;
	end
	local lairs = AZS_GetLairs();
	if ( not lairs or not guards ) then
		return rows, ids;
	end
	local awake = {};
	for i = 1, table.getn(guards) do
		local g = guards[i];
		if ( g.awake and g.id ~= nil ) then
			awake[G.Num(g.id)] = g;
		end
	end
	for i = 1, math.min(table.getn(lairs), LAIRROWS) do
		local id = G.Num(lairs[i].id);
		if ( id > 0 and awake[id] and not ids[id] ) then
			rows[i] = awake[id];
			ids[id] = true;
		end
	end
	return rows, ids;
end

-- the boss bar asks only for the ids
function G.ListedGuardians(guards)
	local _, ids = G.GuardianBars(guards);
	return ids;
end

function G.BuildGuardians()
	local f = CreateFrame("Frame", "AZSGW2Guardians", UIParent);
	f:SetWidth(250);
	f:SetHeight(28 + LAIRROWS * ROWH);
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -228);
	f:SetFrameStrata("MEDIUM");
	G.Register(f, true);
	G.Movable(f, "guardians", "Guardian list");        -- no mouse: the list lets clicks through to the world
	G.guardians = f;

	-- header like the boss list: a white horned skull, a crown and the title in red
	local skull = f:CreateTexture(nil, "ARTWORK");
	G.SetSkull(skull, "small");
	skull:SetWidth(24);
	skull:SetHeight(24);
	skull:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 2);
	local crown = f:CreateTexture(nil, "ARTWORK");
	local crowned = G.SetCrown(crown);
	crown:SetWidth(14);
	crown:SetHeight(14);
	crown:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -4);
	f.title = G.TextS(f, 15, "LEFT");
	if ( crowned ) then
		f.title:SetPoint("LEFT", crown, "RIGHT", 4, 0);
	else
		f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -4);
	end
	f.title:SetText("Guardians");
	f.title:SetTextColor(0.95, 0.12, 0.10);
	f.count = G.TextS(f, 12, "RIGHT");
	f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4);

	-- the arrow in the header points at the nearest guardian
	local head = f:CreateTexture(nil, "OVERLAY");
	head:SetTexture(G.TEXPATH .. "arrows.tga");
	head:SetWidth(20);
	head:SetHeight(20);
	head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -48, 0);
	head:Hide();
	f.headArrow = head;

	local line = G.Band(f, "ARTWORK", 0.55, 0.10, 0.08, 0.95);
	line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -22);
	line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -22);
	line:SetHeight(1);
	f.panel = G.Solid(f, "BACKGROUND", 0.03, 0.02, 0.05, 0.40);
	f.panel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -23);
	f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);

	f.rows = {};
	for i = 1, LAIRROWS do
		local r = CreateFrame("Frame", nil, f);
		r:SetWidth(250);
		r:SetHeight(ROWH);
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -24 - (i - 1) * ROWH);
		r.skull = r:CreateTexture(nil, "ARTWORK");
		G.SetSkull(r.skull, "tiny");
		r.skull:SetWidth(16);
		r.skull:SetHeight(16);
		r.skull:SetPoint("LEFT", r, "LEFT", 4, 0);
		r.arrow = r:CreateTexture(nil, "OVERLAY");
		r.arrow:SetTexture(G.TEXPATH .. "arrows.tga");
		r.arrow:SetWidth(14);
		r.arrow:SetHeight(14);
		r.arrow:SetPoint("RIGHT", r, "RIGHT", -4, 0);
		r.arrow:Hide();
		r.name = G.TextS(r, 12, "LEFT");
		r.name:SetPoint("LEFT", r, "LEFT", 24, 0);
		r.name:SetWidth(112);
		r.name:SetHeight(14);
		r.info = G.TextS(r, 12, "RIGHT");
		r.info:SetPoint("RIGHT", r, "RIGHT", -22, 0);
		-- the health bar of a fighting guardian, under its line (only with the bars on the list)
		r.bar = G.NewFlatBar(r, 250 - BARX - 4, BARH);
		r.bar:SetPoint("TOPLEFT", r, "BOTTOMLEFT", BARX, -1);
		r.bar.pct = G.TextS(r.bar, 10, "CENTER");
		r.bar.pct:SetPoint("CENTER", r.bar, "CENTER", 0, 0);
		r.bar:Hide();
		r:Hide();
		f.rows[i] = r;
	end
end

function G.UpdateGuardians(dt)
	local f = G.guardians;
	if ( not f ) then
		return;
	end
	local lairs = nil;
	if ( AZS_GetLairs ) then
		lairs = AZS_GetLairs();
	end
	local n = 0;
	if ( lairs ) then
		n = table.getn(lairs);
	end
	if ( n == 0 or not G.shown or not G.Opt("guardians") ) then
		f:Hide();
		return;
	end
	f:Show();

	local barOf = G.GuardianBars(AZS_GetGuardians and AZS_GetGuardians() or nil);
	local y, bars = 24, 0;

	local p = nil;
	if ( AZS_GetPlayerPosition ) then
		p = AZS_GetPlayerPosition();
	end

	local held = 0;
	f.nearest, f.nearestDist = nil, nil;
	for i = 1, LAIRROWS do
		local row = f.rows[i];
		local l = lairs[i];
		row.lair = l;
		if ( l ) then
			row:Show();
			-- rows stack from the top; a row with a bar is taller by the bar
			if ( row.curY ~= y ) then
				row.curY = y;
				row:ClearAllPoints();
				row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y);
			end
			y = y + ROWH;
			local g = barOf[i];
			if ( g ) then
				bars = bars + 1;
				y = y + BARROW;
				local hpm = G.Num(g.hpm);
				local frac = 0;
				if ( hpm > 0 ) then
					frac = G.Clamp(G.Num(g.hp) / hpm, 0, 1);
				end
				row.bar:SetFrac(frac);
				local pct = math.floor(frac * 100 + 0.5);
				if ( row.cPct ~= pct ) then
					row.cPct = pct;
					row.bar.pct:SetText(pct .. "%");
				end
				if ( not row.barOn ) then
					row.barOn = true;
					row.bar:Show();
				end
			elseif ( row.barOn ) then
				row.barOn = false;
				row.cPct = nil;
				row.bar:Hide();
			end
			row.name:SetText(tostring(l.name or "?"));
			local dist = nil;
			if ( p and l.x and l.spaceId == p.spaceId and l.state ~= "empty" ) then
				local dx, dy = G.Num(l.x) - p.x, G.Num(l.y) - p.y;
				dist = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5);
			end
			if ( dist and ( l.state == "awake" or l.state == "asleep" ) and ( not f.nearestDist or dist < f.nearestDist ) ) then
				f.nearest, f.nearestDist = l, dist;
			end
			if ( l.state == "awake" ) then
				held = held + 1;
				row.name:SetTextColor(1, 0.35, 0.30);
				row.skull:SetVertexColor(0.95, 0.16, 0.12, 1);
				row.info:SetTextColor(1, 0.60, 0.50);
				row.info:SetText(dist and string.format("Fighting  %d yd", dist) or "Fighting");
			elseif ( l.state == "asleep" ) then
				held = held + 1;
				if ( l.flag == 1 ) then
					row.name:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
				else
					row.name:SetTextColor(0.92, 0.92, 0.92);
				end
				row.info:SetTextColor(0.72, 0.72, 0.72);
				row.skull:SetVertexColor(0.80, 0.18, 0.15, 1);
				row.info:SetText(dist and string.format("%d yd", dist) or "Asleep");
			else
				row.name:SetTextColor(0.55, 0.55, 0.55);
				row.skull:SetVertexColor(0.42, 0.42, 0.45, 1);
				row.info:SetTextColor(0.75, 0.75, 0.75);
				if ( G.Num(l.left) > 0 ) then
					row.info:SetText("Respawns in " .. G.Clock(l.left));
				else
					row.info:SetText("Respawning");
				end
			end
		else
			row:Hide();
			row.curY = nil;
			if ( row.barOn ) then
				row.barOn = false;
				row.cPct = nil;
				row.bar:Hide();
			end
		end
	end
	if ( f.curH ~= y + 4 ) then
		f.curH = y + 4;
		f:SetHeight(y + 4);
	end
	f.count:SetText(string.format("%d / %d", held, n));
	f.count:SetTextColor(0.75, 0.75, 0.75);
end

-- the arrows turn with the hero every few frames, so they get an updater of their own
local function PointArrow(tex, p, l, r, g, b)
	tex:SetVertexColor(r, g, b, 1);
	G.SetArrow(tex, G.RelBearing(p, l.x, l.y));
	tex:Show();
end

function G.UpdateGuardianArrows(dt)
	local f = G.guardians;
	if ( not f or not f:IsShown() ) then
		return;
	end
	local p = nil;
	if ( G.Opt("arrows") and AZS_GetPlayerPosition ) then
		p = AZS_GetPlayerPosition();
	end
	local near = f.nearest;
	if ( p and near and near.x and near.spaceId == p.spaceId ) then
		PointArrow(f.headArrow, p, near, 1, 0.85, 0.35);
	else
		f.headArrow:Hide();
	end
	for i = 1, LAIRROWS do
		local row = f.rows[i];
		local l = row.lair;
		if ( p and l and l.x and l.spaceId == p.spaceId and l.state ~= "empty" and row:IsShown() ) then
			if ( l == near ) then
				PointArrow(row.arrow, p, l, 1, 0.85, 0.35);
			elseif ( l.state == "awake" ) then
				PointArrow(row.arrow, p, l, 1, 0.42, 0.36);
			else
				PointArrow(row.arrow, p, l, 0.85, 0.85, 0.88);
			end
		else
			row.arrow:Hide();
		end
	end
end

------------------------------------------------------------------------ banners

function G.BuildBanner()
	local f = CreateFrame("Frame", "AZSGW2Banner", UIParent);
	f:SetWidth(560);
	f:SetHeight(56);
	f:SetPoint("TOP", UIParent, "TOP", 0, -200);
	f:SetFrameStrata("HIGH");
	G.Register(f, true);
	f:Hide();
	G.banner = f;
	f.queue = {};
	f.active = false;
	f.t = 0;
	G.Movable(f, "banner", "Banners");

	local bg = G.Band(f, "BACKGROUND", 0, 0, 0, 0.78);
	bg:SetAllPoints(f);
	local l1 = G.Band(f, "BORDER", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95);
	l1:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
	l1:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0);
	l1:SetHeight(1);
	local l2 = G.Band(f, "BORDER", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95);
	l2:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
	l2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
	l2:SetHeight(1);
	f.text = G.Text(f, 22, "CENTER");
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0);

	if ( AZS_RegisterBannerHandler ) then
		AZS_RegisterBannerHandler(function(b)
			local q = G.banner.queue;
			if ( G.QueueHunt ) then
				G.QueueHunt(tostring(b.text or ""));
			end
			if ( b.kind == "frienddown" and G.Opt("revive") ) then
				return;                          -- the ally-down alert (Revive.lua) says it, with an arrow
			end
			if ( G.shown ) then
				table.insert(q, { text = tostring(b.text or ""), boss = b.boss, kind = b.kind });
				if ( table.getn(q) > 4 ) then
					table.remove(q, 1);
				end
			end
		end);
	end
end

function G.UpdateBanner(dt)
	local f = G.banner;
	if ( not f ) then
		return;
	end
	if ( not G.shown ) then
		f.queue = {};
		f.active = false;
		f:Hide();
		return;
	end
	if ( not f.active ) then
		local nextB = table.remove(f.queue, 1);
		if ( not nextB ) then
			return;
		end
		f.active = true;
		f.t = 0;
		f.text:SetText(G.Plain(nextB.text));
		if ( nextB.boss ) then
			f.text:SetFont(G.FONT, 26, "OUTLINE");
			f.text:SetTextColor(1, 0.28, 0.22);
		elseif ( nextB.kind == "achievement" or nextB.kind == "unlocked" ) then
			f.text:SetFont(G.FONT, 22, "OUTLINE");
			f.text:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		else
			f.text:SetFont(G.FONT, 22, "OUTLINE");
			f.text:SetTextColor(1, 1, 1);
		end
		f:SetAlpha(0);
		f:Show();
		return;
	end
	f.t = f.t + dt;
	local a = 1;
	if ( f.t < 0.25 ) then
		a = f.t / 0.25;
	elseif ( f.t > 2.85 ) then
		a = 1 - (f.t - 2.85) / 0.5;
	end
	if ( f.t >= 3.35 ) then
		f.active = false;
		f:Hide();
		return;
	end
	f:SetAlpha(G.Clamp(a, 0, 1));
end

------------------------------------------------------------------------ Level Up! button

function G.BuildLevelUp()
	local b = CreateFrame("Button", "AZSGW2LevelUp", UIParent);
	b:SetWidth(170);
	b:SetHeight(38);
	b:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200);
	b:SetFrameStrata("HIGH");
	G.Register(b, true);
	b:Hide();
	G.levelBtn = b;
	G.Movable(b, "levelup", "Level up");
	G.Panel(b, 0.88);

	b.label = G.Text(b, 16, "CENTER");
	b.label:SetPoint("CENTER", b, "CENTER", 6, 0);
	b.label:SetText("LEVEL UP");
	b.label:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);

	local badge = CreateFrame("Frame", nil, b);
	badge:SetWidth(22);
	badge:SetHeight(22);
	badge:SetPoint("CENTER", b, "TOPLEFT", 6, -3);
	badge:SetFrameLevel(b:GetFrameLevel() + 3);
	local d1 = badge:CreateTexture(nil, "BACKGROUND");
	d1:SetTexture(G.MASK);
	d1:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3], 1);
	d1:SetAllPoints(badge);
	local d2 = badge:CreateTexture(nil, "BORDER");
	d2:SetTexture(G.MASK);
	d2:SetVertexColor(0.06, 0.05, 0.05, 1);
	d2:SetPoint("TOPLEFT", badge, "TOPLEFT", 2, -2);
	d2:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -2, 2);
	badge.text = G.Text(badge, 11, "CENTER");
	badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0);
	b.badge = badge;

	b:SetScript("OnClick", function()
		if ( AZS_OpenStoredLevels ) then
			AZS_OpenStoredLevels();
		end
	end);
	G.Tooltip(b, function(tt)
		tt:AddLine("Level up!", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		tt:AddLine("Click to open your stored level-ups.", 1, 1, 1);
	end, "ANCHOR_TOP");
end

function G.UpdateLevelUp(dt)
	local b = G.levelBtn;
	if ( not b ) then
		return;
	end
	local n = 0;
	if ( AZS_GetStoredLevels ) then
		n = G.Num(AZS_GetStoredLevels());
	end
	if ( n > 0 and G.shown ) then
		b.badge.text:SetText(tostring(math.floor(n)));
		local p = 0.5 + 0.5 * math.sin(GetTime() * 4);
		G.EdgeColor(b, 0.50 + 0.40 * p, 0.41 + 0.35 * p, 0.25 + 0.15 * p, 1);
		b:Show();
	else
		b:Hide();
	end
end
