-- AZS GW2 UI: Party.lua
-- Co-op party frames, GW2 style: portrait with the hero's HP number, class coloured name,
-- health bar with percent, and the hero's buffs next to it. Health comes from the party units
-- (UnitHealth("partyN")), "down" from AZS_GetDownedPartyMembers().
-- Barrier (absorb shield): the AZS API only gives the hero's own (AZS_RUN.sh), so for friends it is read from
-- what the client shows: health above the maximum counts as barrier (a gold layer over the bar, with its amount),
-- and a shield buff on the friend (Power Word: Shield, Ice Barrier, Mana Shield, a ward ...) puts a fainter gold
-- layer over the health when no amount is known. The layer is a frame above the bar, so it covers the health.
-- /gw2 party lists what the client says about each friend.

local G = AZSGW2;

local MEMBERS = 4;
local ROWH = 54;
local PORT = 46;
local BARW = 150;
local BUFFS = 6;
local SCAN = 16;                       -- buffs looked at per friend for a shield
local GOLD = { 0.98, 0.84, 0.35 };     -- the same gold as the shield on the hero's own orb

-- icons of the buffs that absorb damage in the 1.12 client (matched inside the icon path, lower case)
local ABSORB = { "spell_holy_powerwordshield", "spell_ice_lament", "spell_shadow_detectlesserinvisibility",
	"spell_shadow_sacrificialshield", "spell_frost_frostward", "spell_shadow_antishadow", "spell_fire_sealoffire" };
local absorbCache, absorbCount = {}, 0;

local function IsAbsorb(tex)
	if ( type(tex) ~= "string" ) then
		return false;
	end
	local known = absorbCache[tex];
	if ( known ~= nil ) then
		return known;
	end
	local l = string.lower(tex);
	known = false;
	for i = 1, table.getn(ABSORB) do
		if ( string.find(l, ABSORB[i], 1, true) ) then
			known = true;
			break;
		end
	end
	if ( absorbCount >= 300 ) then
		absorbCache, absorbCount = {}, 0;     -- never grows without a limit
	end
	absorbCache[tex] = known;
	absorbCount = absorbCount + 1;
	return known;
end

-- the gold layer over the health bar: from stop to start (fractions of the bar), a stronger one for a known
-- amount, a fainter one when only a shield buff is known; a bright line along its top edge
local function SetBarrier(bar, from, to, alpha)
	local t, e = bar.barrier, bar.edge;
	local width = (bar:GetWidth() or 0) - 2;
	if ( not to or to - from <= 0.004 or width <= 0 ) then
		if ( bar.barOn ~= false ) then
			bar.barOn = false;
			t:Hide();
			e:Hide();
		end
		return;
	end
	if ( bar.barOn and bar.bFrom == from and bar.bTo == to and bar.bAlpha == alpha and bar.bWidth == width ) then
		return;                                     -- the same overlay as last time
	end
	bar.barOn, bar.bFrom, bar.bTo, bar.bAlpha, bar.bWidth = true, from, to, alpha, width;
	t:ClearAllPoints();
	t:SetPoint("TOPLEFT", bar, "TOPLEFT", 1 + from * width, -1);
	t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1 + from * width, 1);
	t:SetWidth((to - from) * width);
	t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], alpha or 0.6);
	t:Show();
	e:ClearAllPoints();
	e:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0);
	e:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, 0);
	e:SetHeight(2);
	e:Show();
end

------------------------------------------------------------------------ clicking a frame
-- left click = target the friend (or cast the waiting spell / drop the item on the cursor on them), right click =
-- a small menu of ours: Inspect, Trade, Follow, Whisper (and Make leader / Remove for the party leader). It uses
-- plain game functions and no drop-down template, so it does not depend on the game's own party menu.

local MENUW, ITEMH, MAXITEMS = 124, 20, 6;

local function ActInspect(unit, name)
	if ( CheckInteractDistance and not CheckInteractDistance(unit, 1) ) then
		G.Print(G.Plain(name) .. " is too far away to inspect (about 28 yards).");
		return;
	end
	if ( not InspectUnit ) then
		G.Print("Inspect is not available in this game version.");
		return;
	end
	if ( NotifyInspect ) then
		NotifyInspect(unit);
	end
	InspectUnit(unit);
end

local function Actions()
	local list = { { "Inspect", ActInspect } };
	if ( InitiateTrade ) then
		table.insert(list, { "Trade", function(u) InitiateTrade(u); end });
	end
	if ( FollowUnit ) then
		table.insert(list, { "Follow", function(u) FollowUnit(u); end });
	end
	if ( ChatFrame_SendTell ) then
		table.insert(list, { "Whisper", function(u, n) ChatFrame_SendTell(n); end });
	end
	if ( IsPartyLeader and IsPartyLeader() ) then
		if ( PromoteByName ) then
			table.insert(list, { "Make leader", function(u, n) PromoteByName(n); end });
		end
		if ( UninviteByName ) then
			table.insert(list, { "Remove", function(u, n) UninviteByName(n); end });
		end
	end
	return list;
end

local function CloseMenu()
	local m = G.partyMenu;
	if ( m ) then
		m:Hide();
		m.catcher:Hide();
	end
end
G.ClosePartyMenu = CloseMenu;

local function BuildMenu()
	local m = CreateFrame("Frame", "AZSGW2PartyMenu", UIParent);
	m.azs = true;
	m:SetFrameStrata("FULLSCREEN_DIALOG");
	m:SetFrameLevel(10);
	m:SetWidth(MENUW);
	m:SetHeight(40);
	m:EnableMouse(true);
	m:Hide();
	-- one click anywhere else closes it
	local cb = CreateFrame("Button", nil, UIParent);
	cb:SetAllPoints(UIParent);
	cb:SetFrameStrata("FULLSCREEN_DIALOG");
	cb:SetFrameLevel(5);
	cb:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	cb:SetScript("OnClick", CloseMenu);
	cb:Hide();
	m.catcher = cb;
	local bg = G.Solid(m, "BACKGROUND", 0.04, 0.04, 0.05, 0.97);
	bg:SetAllPoints(m);
	G.Edges(m, G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.85, 1, "BORDER");
	m.title = G.Text(m, 12, "LEFT");
	m.title:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -6);
	m.title:SetWidth(MENUW - 16);
	m.title:SetHeight(14);
	m.items = {};
	for i = 1, MAXITEMS do
		local b = CreateFrame("Button", nil, m);
		b:SetWidth(MENUW - 6);
		b:SetHeight(ITEMH);
		b:SetPoint("TOPLEFT", m, "TOPLEFT", 3, -(24 + (i - 1) * ITEMH));
		b:SetFrameLevel(m:GetFrameLevel() + 2);
		b.hl = G.Solid(b, "BACKGROUND", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.22);
		b.hl:SetAllPoints(b);
		b.hl:Hide();
		b.text = G.Text(b, 12, "LEFT");
		b.text:SetPoint("LEFT", b, "LEFT", 6, 0);
		b:SetScript("OnEnter", function() b.hl:Show(); end);
		b:SetScript("OnLeave", function() b.hl:Hide(); end);
		b:SetScript("OnClick", function()
			local act, unit, name = b.act, m.unit, m.pname;
			CloseMenu();
			if ( not act or not unit ) then
				return;
			end
			if ( UnitName(unit) ~= name ) then
				G.Print(G.Plain(tostring(name)) .. " is no longer in the party.");     -- the party changed while the menu was open
				return;
			end
			local ok, err = pcall(act, unit, name);
			if ( not ok ) then
				G.Print("party menu failed: " .. tostring(err));
			end
		end);
		b:Hide();
		m.items[i] = b;
	end
	G.partyMenu = m;
	return m;
end

local function ShowMenu(unit)
	local name = UnitName and UnitName(unit);
	if ( not name ) then
		return;
	end
	local m = G.partyMenu or BuildMenu();
	local list = Actions();
	m.unit, m.pname = unit, name;
	local token = nil;
	if ( UnitClass ) then
		local _, tk = UnitClass(unit);
		token = tk and string.lower(tk) or nil;
	end
	m.title:SetText(G.Esc(name));
	m.title:SetTextColor(G.ClassColor(token));
	local n = math.min(table.getn(list), MAXITEMS);
	for i = 1, MAXITEMS do
		local b = m.items[i];
		if ( i <= n ) then
			b.act = list[i][2];
			b.text:SetText(list[i][1]);
			b.hl:Hide();
			b:Show();
		else
			b.act = nil;
			b:Hide();
		end
	end
	m:SetHeight(24 + n * ITEMH + 4);
	-- at the mouse, kept on the screen
	local x, y = 0, 0;
	if ( GetCursorPosition ) then
		x, y = GetCursorPosition();
	end
	local es = UIParent:GetEffectiveScale() or 1;
	if ( es <= 0 ) then
		es = 1;
	end
	x, y = ( x or 0 ) / es, ( y or 0 ) / es;
	local sw, sh = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768;
	x = G.Clamp(x - 8, 0, math.max(0, sw - MENUW));
	y = G.Clamp(y + 8, 24 + n * ITEMH + 4, sh);
	m:SetScale(1);
	m:ClearAllPoints();
	m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y);
	m.catcher:Show();
	m:Show();
end

local function PartyClick(row, button)
	local unit = row.unit;
	if ( not unit ) then
		return;
	end
	if ( button == "RightButton" ) then
		local ok, err = pcall(ShowMenu, unit);
		if ( not ok ) then
			G.Print("party menu failed: " .. tostring(err));
		end
	elseif ( SpellIsTargeting and SpellIsTargeting() and SpellTargetUnit ) then
		SpellTargetUnit(unit);
	elseif ( CursorHasItem and CursorHasItem() and DropItemOnUnit ) then
		DropItemOnUnit(unit);
	elseif ( TargetUnit ) then
		TargetUnit(unit);
	end
end

function G.BuildParty()
	local c = CreateFrame("Frame", "AZSGW2Party", UIParent);
	c:SetWidth(PORT + 8 + BARW);
	c:SetHeight(ROWH * MEMBERS);
	c:SetPoint("LEFT", UIParent, "LEFT", 14, 80);
	c:SetFrameStrata("MEDIUM");
	G.Register(c, true);
	G.Movable(c, "party", "Party");                    -- the rows take the mouse, the frame around them does not
	c:Hide();
	G.party = c;

	c.rows = {};
	for i = 1, MEMBERS do
		local row = CreateFrame("Button", nil, c);
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		row:SetScript("OnClick", function()
			PartyClick(row, arg1);
		end);
		row:SetWidth(PORT + 8 + BARW);
		row:SetHeight(ROWH - 4);
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(i - 1) * ROWH);

		-- portrait
		local port = CreateFrame("Frame", nil, row);
		port:SetWidth(PORT);
		port:SetHeight(PORT);
		port:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0);
		local icon = port:CreateTexture(nil, "BACKGROUND");
		icon:SetPoint("TOPLEFT", port, "TOPLEFT", 2, -2);
		icon:SetPoint("BOTTOMRIGHT", port, "BOTTOMRIGHT", -2, 2);
		icon:SetTexture(G.QUESTION);
		row.icon = icon;
		local shade = G.Solid(port, "BORDER", 0.75, 0.05, 0.05, 0.55);
		shade:SetPoint("TOPLEFT", port, "TOPLEFT", 2, -2);
		shade:SetPoint("BOTTOMRIGHT", port, "BOTTOMRIGHT", -2, 2);
		shade:Hide();
		row.shade = shade;
		G.Edges(port, G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95, 2, "ARTWORK");
		row.port = port;
		local sel = CreateFrame("Frame", nil, row);       -- white outline round the portrait of the friend you target
		sel:SetPoint("TOPLEFT", port, "TOPLEFT", -2, 2);
		sel:SetPoint("BOTTOMRIGHT", port, "BOTTOMRIGHT", 2, -2);
		G.Edges(sel, 1, 1, 1, 0.95, 2, "OVERLAY");
		sel:Hide();
		row.sel = sel;
		local tf = CreateFrame("Frame", nil, port);
		tf:SetAllPoints(port);
		tf:SetFrameLevel(port:GetFrameLevel() + 3);
		row.hpText = G.Text(tf, 11, "LEFT");
		row.hpText:SetPoint("TOPLEFT", port, "TOPLEFT", 4, -4);
		row.stateText = G.Text(tf, 10, "CENTER");
		row.stateText:SetPoint("BOTTOM", port, "BOTTOM", 0, 4);
		row.stateText:SetTextColor(1, 0.35, 0.30);

		-- name + bar
		row.name = G.Text(row, 12, "LEFT");
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", PORT + 6, -2);
		row.name:SetWidth(BARW);
		row.name:SetHeight(13);
		row.bar = G.NewBar(row, BARW, 14, 0.30, 0.72, 0.22);
		row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", PORT + 6, -18);
		-- barrier: a gold layer in a frame above the bar (so it covers the health), the percent text above that
		local over = CreateFrame("Frame", nil, row.bar);
		over:SetAllPoints(row.bar);
		over:SetFrameLevel(row.bar:GetFrameLevel() + 2);
		row.bar.barrier = G.Solid(over, "OVERLAY", GOLD[1], GOLD[2], GOLD[3], 0.6);
		row.bar.barrier:Hide();
		row.bar.edge = G.Solid(over, "OVERLAY", GOLD[1], GOLD[2], GOLD[3], 0.95);
		row.bar.edge:Hide();
		local topf = CreateFrame("Frame", nil, row.bar);
		topf:SetAllPoints(row.bar);
		topf:SetFrameLevel(row.bar:GetFrameLevel() + 4);
		row.pct = G.Text(topf, 10, "CENTER");
		row.pct:SetPoint("CENTER", row.bar, "CENTER", 0, 0);
		row.barText = G.Text(row, 11, "RIGHT");           -- above the bar's right end: gold on gold would not read
		row.barText:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2);
		row.barText:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
		G.Tooltip(row, function(tt)
			local e = row.entry;
			if ( not e ) then
				return;
			end
			local r, g, b = G.ClassColor(e.class);
			tt:AddLine(G.Esc(e.name), r, g, b);
			if ( e.known and e.hpm > 0 ) then
				tt:AddLine(G.Comma(e.hp) .. " / " .. G.Comma(e.hpm), 1, 1, 1);
			end
			if ( e.barrier and e.barrier > 0 ) then
				tt:AddLine("Barrier: " .. G.Comma(e.barrier), GOLD[1], GOLD[2], GOLD[3]);
			elseif ( e.shielded ) then
				tt:AddLine("Barrier active", GOLD[1], GOLD[2], GOLD[3]);
			end
			if ( row.unit ) then
				tt:AddLine("Click: target   Right click: menu", 0.6, 0.6, 0.6);
			end
		end, "ANCHOR_RIGHT");

		-- buffs
		row.buffs = {};
		for j = 1, BUFFS do
			local b = CreateFrame("Frame", nil, row);
			b:SetWidth(16);
			b:SetHeight(16);
			b:SetPoint("TOPLEFT", row, "TOPLEFT", PORT + 6 + (j - 1) * 18, -35);
			local t = b:CreateTexture(nil, "BACKGROUND");
			t:SetAllPoints(b);
			t:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			b.icon = t;
			G.Edges(b, 0.45, 0.37, 0.22, 1, 1, "ARTWORK");
			b:Hide();
			row.buffs[j] = b;
		end
		row:Hide();
		c.rows[i] = row;
	end
end

-- who is in the party: the party units, or (if the game has no party units) the party meter's heroes
local function Gather()
	local list = {};
	local n = 0;
	if ( GetNumPartyMembers ) then
		n = GetNumPartyMembers() or 0;
	end
	for i = 1, math.min(n, MEMBERS) do
		local unit = "party" .. i;
		local name = UnitName(unit);
		if ( name ) then
			local cls = nil;
			if ( UnitClass ) then
				local _, token = UnitClass(unit);
				cls = token;
			end
			local dead = false;
			if ( UnitIsDeadOrGhost ) then
				dead = UnitIsDeadOrGhost(unit) and true or false;
			end
			table.insert(list, { unit = unit, name = name, class = cls and string.lower(cls) or nil,
				hp = G.Num(UnitHealth(unit)), hpm = G.Num(UnitHealthMax(unit)), dead = dead, known = true });
		end
	end
	if ( table.getn(list) == 0 and AZS_GetPartyMeter ) then
		local lines = AZS_GetPartyMeter();
		local me = AZS_ZONE and AZS_ZONE.hero;
		if ( lines ) then
			for i = 1, table.getn(lines) do
				if ( lines[i].name ~= me and table.getn(list) < MEMBERS ) then
					table.insert(list, { name = lines[i].name, class = lines[i].class, hp = 0, hpm = 0, known = false });
				end
			end
		end
	end
	return list;
end

local function Fill(row, d, downed)
	row:Show();
	row.entry = d;
	row.unit = d.unit;
	-- this runs five times a second for every friend: each piece of the frame remembers what it last showed and
	-- is only touched when that changed
	local sel = ( d.unit and UnitIsUnit and UnitIsUnit("target", d.unit) ) and true or false;
	if ( row.selOn ~= sel ) then
		row.selOn = sel;
		if ( sel ) then
			row.sel:Show();
		else
			row.sel:Hide();
		end
	end
	local r, g, b = G.ClassColor(d.class);
	G.SetText(row.name, G.Esc(d.name));
	if ( row.nameTint ~= d.class ) then
		row.nameTint = d.class;
		row.name:SetTextColor(r, g, b);
	end

	local coords = d.class and G.CLASSCOORDS[d.class];
	local iconKey = coords and d.class or "?";
	if ( row.iconKey ~= iconKey ) then
		row.iconKey = iconKey;
		if ( coords ) then
			row.icon:SetTexture(G.CLASSICON);
			row.icon:SetTexCoord(coords[1] + 0.01, coords[2] - 0.01, coords[3] + 0.01, coords[4] - 0.01);
		else
			row.icon:SetTexture(G.QUESTION);
			row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		end
	end

	-- buffs: the first few are drawn, all (up to SCAN) are checked for a shield
	local shield = false;
	for j = 1, SCAN do
		local tex = nil;
		if ( d.unit and UnitBuff ) then
			tex = UnitBuff(d.unit, j);
		end
		if ( not tex ) then
			for k = j, BUFFS do
				local bf = row.buffs[k];
				if ( bf.vis ~= false ) then
					bf.vis = false;
					bf:Hide();
				end
			end
			break;
		end
		if ( j <= BUFFS ) then
			local bf = row.buffs[j];
			if ( bf.curTex ~= tex ) then
				bf.curTex = tex;
				bf.icon:SetTexture(tex);
				bf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			end
			if ( not bf.vis ) then
				bf.vis = true;
				bf:Show();
			end
		end
		if ( not shield and IsAbsorb(tex) ) then
			shield = true;
		end
	end

	local down = downed[d.name] or d.dead;
	local hp, hpm = d.hp, d.hpm;
	local barrier = 0;
	if ( hpm > 0 and hp > hpm ) then
		barrier = hp - hpm;                -- health above the maximum is the barrier
		hp = hpm;
	end
	local frac = 0;
	if ( hpm > 0 ) then
		frac = G.Clamp(hp / hpm, 0, 1);
	end
	d.hp, d.barrier, d.shielded = hp, barrier, shield and barrier <= 0;
	local pct, hpTxt, barTxt = "", "", "";
	local bFrom, bTo, bAlpha = 0, nil, nil;
	if ( not d.known ) then
		row.bar:SetColor(0.35, 0.35, 0.38);
		row.bar:SetFrac(1);
	elseif ( down ) then
		row.bar:SetColor(0.45, 0.05, 0.05);
		row.bar:SetFrac(1);
		pct = "Downed";
	else
		if ( frac > 0.5 ) then
			row.bar:SetColor(0.30, 0.72, 0.22);
		elseif ( frac > 0.25 ) then
			row.bar:SetColor(0.85, 0.65, 0.12);
		else
			row.bar:SetColor(0.80, 0.15, 0.10);
		end
		row.bar:SetFrac(frac);
		pct = string.format("%d%%", math.floor(frac * 100 + 0.5));
		hpTxt = G.Short(hp);
		if ( barrier > 0 and hpm > 0 ) then
			-- like on the hero's orb: the barrier sits after the health, and runs back from the full end
			-- when health plus barrier is more than the bar
			local bf = G.Clamp(barrier / hpm, 0, 1);
			local from, to = frac, frac + bf;
			if ( to > 1 ) then
				from, to = math.max(0, 1 - bf), 1;
			end
			bFrom, bTo, bAlpha = from, to, 0.62;
			barTxt = "+" .. G.Short(barrier);
		elseif ( shield ) then
			bFrom, bTo, bAlpha = 0, frac, 0.40;   -- a shield is up, its size is not known: a fainter layer over the health
		end
	end
	SetBarrier(row.bar, bFrom, bTo, bAlpha);
	G.SetText(row.barText, barTxt);
	G.SetText(row.pct, pct);
	G.SetText(row.hpText, hpTxt);
	local downOn = down and true or false;
	if ( row.downOn ~= downOn ) then
		row.downOn = downOn;
		if ( downOn ) then
			row.shade:Show();
		else
			row.shade:Hide();
		end
	end
	G.SetText(row.stateText, downOn and "DOWN" or "");
	if ( barrier > 0 or ( shield and not down ) ) then
		G.EdgeColor(row.port, GOLD[1], GOLD[2], GOLD[3], 1);
	else
		G.EdgeColor(row.port, G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95);
	end
end

-- /gw2 party: what the client says about each friend (to see where a shield shows)
function G.PrintParty()
	local n = 0;
	if ( GetNumPartyMembers ) then
		n = GetNumPartyMembers() or 0;
	end
	if ( n == 0 ) then
		G.Print("no party members.");
		return;
	end
	for i = 1, math.min(n, MEMBERS) do
		local unit = "party" .. i;
		local hp, hpm = G.Num(UnitHealth(unit)), G.Num(UnitHealthMax(unit));
		local line = unit .. " " .. tostring(UnitName(unit)) .. "  health " .. hp .. " / " .. hpm;
		if ( hpm > 0 and hp > hpm ) then
			line = line .. "  (barrier " .. ( hp - hpm ) .. ")";
		end
		G.Print(line);
		local list = "";
		for j = 1, SCAN do
			local tex = UnitBuff and UnitBuff(unit, j);
			if ( not tex ) then
				break;
			end
			local short = string.gsub(tostring(tex), "^.*\\", "");
			if ( IsAbsorb(tex) ) then
				short = short .. "*";
			end
			list = list .. short .. " ";
		end
		G.Print("   buffs: " .. ( list == "" and "none" or list ) .. "  (* = counted as a shield)");
	end
end

function G.UpdateParty(dt)
	local c = G.party;
	if ( not c ) then
		return;
	end
	local list = Gather();
	if ( table.getn(list) == 0 or not G.shown or not G.Opt("party") ) then
		c:Hide();
		CloseMenu();
		return;
	end
	c:Show();
	local pm = G.partyMenu;
	if ( pm and pm:IsShown() and ( not pm.unit or not UnitName or UnitName(pm.unit) ~= pm.pname ) ) then
		CloseMenu();                       -- the friend the menu was opened for is gone from that slot
	end
	local downed = {};
	if ( AZS_GetDownedPartyMembers ) then
		local dl = AZS_GetDownedPartyMembers();
		if ( dl ) then
			for i = 1, table.getn(dl) do
				downed[dl[i].name] = true;
			end
		end
	end
	for i = 1, MEMBERS do
		if ( list[i] ) then
			Fill(c.rows[i], list[i], downed);
		else
			c.rows[i]:Hide();
			c.rows[i].unit, c.rows[i].entry = nil, nil;
		end
	end
end

------------------------------------------------------------------------ marking the allies

-- When you join a co-op game (the party forms, a hero comes or goes, or a new run begins) every ally gets one of the game's
-- raid icons, so the allies can be told apart in the swarm. The icon is the hero's place in the party sorted by name, you
-- included: every player who runs this addon gives the same icon to the same hero, and nobody takes an icon from another. A
-- mark that is already on an ally is left alone, and one you take off is not put back until the party changes or a new run
-- begins. Setting a mark can fail while the units are not there yet (or if the game does not let you), so after a change it is
-- tried once a second for a little while.
local ALLY_ICONS = { 1, 2, 3, 4, 5 };
local ALLY_ICON_NAMES = { "star", "circle", "diamond", "triangle", "moon" };
local MARK_TRIES = 15;                                      -- seconds an ally is tried for after a change
local markSig, markUntil, markNext = nil, 0, 0;

-- everyone in the party by name: the sorted names, and the unit of each ally (you have none)
local function PartyRoster()
	local n = 0;
	if ( GetNumPartyMembers ) then
		n = GetNumPartyMembers() or 0;
	end
	local me = UnitName and UnitName("player");
	if ( n == 0 or not me ) then
		return nil;
	end
	local names, units = { me }, {};
	for i = 1, math.min(n, MEMBERS) do
		local unit = "party" .. i;
		local name = UnitName(unit);
		if ( name and name ~= me and not units[name] ) then
			table.insert(names, name);
			units[name] = unit;
		end
	end
	table.sort(names);
	return names, units;
end

function G.UpdateMarks(dt)
	local setIcon = SetRaidTargetIcon or SetRaidTarget;
	if ( not G.Opt("markAllies") or not setIcon or not GetRaidTargetIndex ) then
		markSig = nil;                                      -- turned on later: marks at once
		return;
	end
	local names, units = PartyRoster();
	if ( not names ) then
		markSig = nil;                                      -- out of a party: the next one is a new one
		return;
	end
	local sig = table.concat(names, "\n") .. "\t" .. tostring(AZS_RUN and AZS_RUN.run);
	local now = GetTime();
	if ( sig ~= markSig ) then
		markSig, markUntil, markNext = sig, now + MARK_TRIES, 0;
	end
	if ( now > markUntil or now < markNext ) then
		return;
	end
	markNext = now + 1;
	local open = false;
	for rank = 1, table.getn(names) do
		local unit = units[names[rank]];
		local icon = ALLY_ICONS[rank];
		if ( unit and icon and ( GetRaidTargetIndex(unit) or 0 ) == 0 ) then
			pcall(setIcon, unit, icon);
			open = true;                                    -- looked at again in a second: did it take?
		end
	end
	if ( not open ) then
		markUntil = 0;
	end
end

-- /gw2 marks: who is in the party, which icon each ally should have and which one it has
function G.AllyMarksReport()
	G.Print("marking allies is " .. ( G.Opt("markAllies") and "on" or "off" ) .. " (/gw2 marks on | off), SetRaidTargetIcon "
		.. tostring( ( SetRaidTargetIcon or SetRaidTarget ) ~= nil ) .. ", GetRaidTargetIndex " .. tostring(GetRaidTargetIndex ~= nil));
	local names, units = PartyRoster();
	if ( not names ) then
		G.Print("  you are not in a party");
		return;
	end
	for rank = 1, table.getn(names) do
		local name = G.Plain(names[rank]);
		local unit = units[names[rank]];
		local want = ALLY_ICON_NAMES[rank] or "none";
		if ( not unit ) then
			G.Print("  " .. name .. " (you): " .. want .. " by the others, not set by us");
		else
			local have = GetRaidTargetIndex and GetRaidTargetIndex(unit) or 0;
			G.Print("  " .. name .. " (" .. unit .. "): should have " .. want .. ", has "
				.. ( ( have or 0 ) == 0 and "none" or ( ALLY_ICON_NAMES[have] or ( "icon " .. have ) ) ));
		end
	end
end
