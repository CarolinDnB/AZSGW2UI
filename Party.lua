-- AZS GW2 UI: Party.lua
-- Co-op party frames, GW2 style: portrait with the hero's HP number, class coloured name,
-- health bar with percent, and the hero's buffs next to it. Health comes from the party units
-- (UnitHealth("partyN")), "down" from AZS_GetDownedPartyMembers().
-- Barrier (absorb shield): the AZS API only gives the hero's own (AZS_RUN.sh), so for friends it is read from
-- what the client shows: health above the maximum counts as barrier (drawn gold with its amount), and a
-- shield buff on the friend (Power Word: Shield, Ice Barrier, Mana Shield, a ward ...) marks the bar with a
-- gold line when no amount is known. /gw2 party lists what the client says about each friend.

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

-- the gold segment on the health bar: from stop to start (fractions of the bar)
local function SetBarrier(bar, from, to)
	local t = bar.barrier;
	local width = (bar:GetWidth() or 0) - 2;
	if ( not to or to - from <= 0.004 or width <= 0 ) then
		t:Hide();
		return;
	end
	t:ClearAllPoints();
	t:SetPoint("TOPLEFT", bar, "TOPLEFT", 1 + from * width, -1);
	t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1 + from * width, 1);
	t:SetWidth((to - from) * width);
	t:Show();
end

function G.BuildParty()
	local c = CreateFrame("Frame", "AZSGW2Party", UIParent);
	c:SetWidth(PORT + 8 + BARW);
	c:SetHeight(ROWH * MEMBERS);
	c:SetPoint("LEFT", UIParent, "LEFT", 14, 80);
	c:SetFrameStrata("MEDIUM");
	G.Register(c, true);
	G.Movable(c, "party", "Party", nil, nil, true);
	c:Hide();
	G.party = c;

	c.rows = {};
	for i = 1, MEMBERS do
		local row = CreateFrame("Frame", nil, c);
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
		row.pct = G.Text(row.bar, 10, "CENTER");
		row.pct:SetPoint("CENTER", row.bar, "CENTER", 0, 0);
		-- barrier: a gold segment over the bar, a gold line when only the shield buff is known
		row.bar.barrier = G.Solid(row.bar, "BORDER", GOLD[1], GOLD[2], GOLD[3], 0.92);
		row.bar.barrier:Hide();
		row.bar.line = G.Solid(row.bar, "OVERLAY", GOLD[1], GOLD[2], GOLD[3], 0.95);
		row.bar.line:SetPoint("BOTTOMLEFT", row.bar, "BOTTOMLEFT", 1, 1);
		row.bar.line:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", -1, 1);
		row.bar.line:SetHeight(2);
		row.bar.line:Hide();
		row.barText = G.Text(row, 11, "RIGHT");           -- above the bar's right end: gold on gold would not read
		row.barText:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2);
		row.barText:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
		G.Tooltip(row.bar, function(tt)
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
	local r, g, b = G.ClassColor(d.class);
	row.name:SetText(G.Esc(d.name));
	row.name:SetTextColor(r, g, b);

	local coords = d.class and G.CLASSCOORDS[d.class];
	if ( coords ) then
		row.icon:SetTexture(G.CLASSICON);
		row.icon:SetTexCoord(coords[1] + 0.01, coords[2] - 0.01, coords[3] + 0.01, coords[4] - 0.01);
	else
		row.icon:SetTexture(G.QUESTION);
		row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
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
				row.buffs[k]:Hide();
			end
			break;
		end
		if ( j <= BUFFS ) then
			local bf = row.buffs[j];
			bf.icon:SetTexture(tex);
			bf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			bf:Show();
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
	row.bar.line:Hide();
	row.barText:SetText("");
	SetBarrier(row.bar, 0, nil);
	if ( not d.known ) then
		row.bar:SetColor(0.35, 0.35, 0.38);
		row.bar:SetFrac(1);
		row.pct:SetText("");
		row.hpText:SetText("");
	elseif ( down ) then
		row.bar:SetColor(0.45, 0.05, 0.05);
		row.bar:SetFrac(1);
		row.pct:SetText("Downed");
		row.hpText:SetText("");
	else
		if ( frac > 0.5 ) then
			row.bar:SetColor(0.30, 0.72, 0.22);
		elseif ( frac > 0.25 ) then
			row.bar:SetColor(0.85, 0.65, 0.12);
		else
			row.bar:SetColor(0.80, 0.15, 0.10);
		end
		row.bar:SetFrac(frac);
		row.pct:SetText(string.format("%d%%", math.floor(frac * 100 + 0.5)));
		row.hpText:SetText(G.Short(hp));
		if ( barrier > 0 and hpm > 0 ) then
			-- like on the hero's orb: the barrier sits after the health, and runs back from the full end
			-- when health plus barrier is more than the bar
			local bf = G.Clamp(barrier / hpm, 0, 1);
			local from, to = frac, frac + bf;
			if ( to > 1 ) then
				from, to = math.max(0, 1 - bf), 1;
			end
			SetBarrier(row.bar, from, to);
			row.barText:SetText("+" .. G.Short(barrier));
		elseif ( shield ) then
			row.bar.line:Show();             -- a shield is up, its size is not known
		end
	end
	if ( down ) then
		row.shade:Show();
		row.stateText:SetText("DOWN");
	else
		row.shade:Hide();
		row.stateText:SetText("");
	end
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
		return;
	end
	c:Show();
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
		end
	end
end
