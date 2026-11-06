-- AZS GW2 UI: Skills.lua
-- Six display-only skill slots (the spells cast themselves in Azeroth Survivors): three on each side of
-- the orb, big and tight, each with a round rank chip. The racial sits left of the left three; Talents and
-- Character are two small buttons stacked right of the right three. A jewelry plate and the status
-- row (summons, totems) sit around them. Own art; the layout is inspired by GW2_UI.

local G = AZSGW2;

local SLOT = 52;          -- the six skill slots
local GAP = 3;
local SMALL = 25;         -- Talents / Character: two of them stacked are as tall as one slot
local RACIAL = 40;
local SIDE = 6;           -- room between the orb's rim and the nearest slot
local LIFT = 4;           -- slots stand this far above the bottom of the orb
local OUTER = 8;          -- gap before the racial / the small buttons
local WINGH = SLOT + 24;  -- height of the smoke behind each side
local AURAS = 10;      -- buffs / debuffs shown, one row each
local AURASIZE = 26;
local STATUS = 12;     -- summons and totems: two rows of six
local STATUSSIZE = 24;
local STATUSROW = 6;   -- 6 x 24 + 5 x 2 = 154 px: as wide as the left three slots, so it never reaches the orb

G.slots = {};
G.abilityInfo = {};
G.jewelry = {};
G.cdEnd = nil;
G.lastSpellStamp = nil;

------------------------------------------------------------------------ icon data from the meter API's loadout

function G.RefreshLoadout()
	if ( not AZS_GetMeterContext or not AZS_GetMeterLoadout ) then
		return;
	end
	local ctx = AZS_GetMeterContext();
	if ( not ctx ) then
		return;
	end
	-- metadataRevision changes when a name, an icon or the loadout does, so the loadout is only read again
	-- then (revisions are opaque strings, so the run id is part of the key)
	local stamp = tostring(ctx.runId) .. "/" .. tostring(ctx.metadataRevision);
	if ( G.loadoutStamp == stamp ) then
		return;
	end
	local lo = AZS_GetMeterLoadout({ apiVersion = 1, runId = ctx.runId });
	if ( not lo ) then
		return;
	end
	G.loadoutStamp = stamp;

	local info = {};
	local sources = lo.sources or {};
	for key, src in pairs(sources) do
		if ( src.abilityKey ) then
			local icon = nil;
			if ( src.icon and src.icon.status == "ready" ) then
				icon = src.icon.path;
			end
			local cur = info[src.abilityKey];
			if ( not cur or ( cur.variant and not src.variantKey ) ) then
				info[src.abilityKey] = { name = src.name, icon = icon, variant = src.variantKey };
			end
		end
	end
	G.abilityInfo = info;

	local jew = {};
	local list = lo.runJewelry or {};
	for i = 1, table.getn(list) do
		local j = list[i];
		local src = j.sourceKey and sources[j.sourceKey];
		if ( src ) then
			local icon = nil;
			if ( src.icon and src.icon.status == "ready" ) then
				icon = src.icon.path;
			end
			table.insert(jew, { name = src.name or "?", icon = icon, category = j.category });
		end
	end
	G.jewelry = jew;
end

------------------------------------------------------------------------ one slot

local function NewSlot(size, hasCooldown, ranked)
	local b = CreateFrame("Button", nil, UIParent);
	b:SetWidth(size);
	b:SetHeight(size);
	b:SetFrameStrata("HIGH");   -- above the game's own HUD frames, so hovering and clicking always reach us
	b.size = size;

	local icon = b:CreateTexture(nil, "BACKGROUND");
	icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3);
	icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3);
	icon:SetTexture(G.QUESTION);
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	b.icon = icon;
	b.curIcon = G.QUESTION;

	if ( hasCooldown ) then
		local cd = b:CreateTexture(nil, "BORDER");
		cd:SetTexture(G.WHITE);
		cd:SetVertexColor(0, 0, 0, 0.72);
		cd:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3);
		cd:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3);
		cd:SetHeight(1);
		cd:Hide();
		b.cd = cd;
	end

	-- frame: a black outline, a two pixel steel bevel (light on top and left), a soft shadow on the icon
	G.Edges(b, 0.02, 0.02, 0.03, 1, 1, "ARTWORK");
	local bev = CreateFrame("Frame", nil, b);
	bev:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1);
	bev:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1);
	local e = G.Edges(bev, 0.6, 0.6, 0.64, 1, 2, "ARTWORK");
	e.top:SetVertexColor(0.78, 0.78, 0.82, 1);
	e.left:SetVertexColor(0.64, 0.64, 0.68, 1);
	e.bottom:SetVertexColor(0.27, 0.27, 0.31, 1);
	e.right:SetVertexColor(0.33, 0.33, 0.37, 1);
	local shade = CreateFrame("Frame", nil, b);
	shade:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3);
	shade:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3);
	G.Edges(shade, 0, 0, 0, 0.55, 1, "ARTWORK");

	local tf = CreateFrame("Frame", nil, b);
	tf:SetAllPoints(b);
	tf:SetFrameLevel(b:GetFrameLevel() + 3);
	b.cdText = G.Text(tf, math.floor(size * 0.38), "CENTER");
	b.cdText:SetPoint("CENTER", b, "CENTER", 0, 0);

	-- the skill's rank sits in a small round chip at the bottom centre, where GW2 puts the key
	local chip = CreateFrame("Frame", nil, tf);
	chip:SetWidth(18);
	chip:SetHeight(18);
	chip:SetPoint("CENTER", b, "BOTTOM", 0, 1);
	chip:SetFrameLevel(b:GetFrameLevel() + 6);
	local ring = chip:CreateTexture(nil, "BACKGROUND");
	ring:SetTexture(G.MASK);
	ring:SetVertexColor(0.64, 0.58, 0.42, 1);
	ring:SetAllPoints(chip);
	local disc = chip:CreateTexture(nil, "BORDER");
	disc:SetTexture(G.MASK);
	disc:SetVertexColor(0.03, 0.03, 0.04, 1);
	disc:SetPoint("TOPLEFT", chip, "TOPLEFT", 2, -2);
	disc:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", -2, 2);
	chip:Hide();
	b.chip = chip;
	b.keyText = G.Text(chip, 10, "CENTER");
	b.keyText:SetPoint("CENTER", chip, "CENTER", 0, 0);
	b.keyText:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);

	-- the most enemies the skill can hit (see "how many targets a skill can hit"): the same chip as the rank, at the top centre, in red
	if ( hasCooldown ) then
		local hc = CreateFrame("Frame", nil, tf);
		hc:SetWidth(18);
		hc:SetHeight(18);
		hc:SetPoint("CENTER", b, "TOP", 0, -1);
		hc:SetFrameLevel(b:GetFrameLevel() + 6);
		local hring = hc:CreateTexture(nil, "BACKGROUND");
		hring:SetTexture(G.MASK);
		hring:SetVertexColor(0.74, 0.30, 0.25, 1);
		hring:SetAllPoints(hc);
		local hdisc = hc:CreateTexture(nil, "BORDER");
		hdisc:SetTexture(G.MASK);
		hdisc:SetVertexColor(0.07, 0.02, 0.02, 1);
		hdisc:SetPoint("TOPLEFT", hc, "TOPLEFT", 2, -2);
		hdisc:SetPoint("BOTTOMRIGHT", hc, "BOTTOMRIGHT", -2, 2);
		hc:Hide();
		b.hitChip = hc;
		b.hitText = G.Text(hc, 10, "CENTER");
		b.hitText:SetPoint("CENTER", hc, "CENTER", 0, 0);
		b.hitText:SetTextColor(1, 0.90, 0.84);
	end
	return b;
end

-- These run for every slot about thirty times a second, and nearly always with the same values as the
-- last time, so each one remembers what it drew and only talks to the game when something changed.
local function SetRank(b, rank)
	rank = rank or 0;
	if ( b.curRank == rank ) then
		return;
	end
	b.curRank = rank;
	if ( rank > 0 ) then
		b.keyText:SetText(tostring(rank));
		b.chip:Show();
	else
		b.keyText:SetText("");
		b.chip:Hide();
	end
end

local function SetHits(b, n)
	if ( not b.hitChip or b.curHits == n ) then
		return;
	end
	b.curHits = n;
	if ( n and n > 0 ) then
		b.hitText:SetText(tostring(n));
		b.hitChip:Show();
	else
		b.hitChip:Hide();
	end
end

local function SetCdText(b, text)
	if ( b.curCd ~= text ) then
		b.curCd = text;
		b.cdText:SetText(text);
	end
end

local function SetTint(b, kind)
	if ( b.tint ~= kind ) then
		b.tint = kind;
		if ( kind == "dim" ) then
			b.icon:SetVertexColor(0.55, 0.55, 0.6, 1);
		else
			b.icon:SetVertexColor(1, 1, 1, 1);
		end
	end
end

local function SetIcon(b, path)
	path = path or G.QUESTION;
	if ( b.curIcon ~= path ) then
		b.curIcon = path;
		b.icon:SetTexture(path);
		b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	end
end

local function SetEmpty(b)
	b.entry = nil;
	if ( b.curIcon ~= "empty" ) then
		b.icon:SetTexture(G.WHITE);
		b.icon:SetTexCoord(0, 1, 0, 1);
		b.icon:SetVertexColor(0.04, 0.04, 0.05, 1);
		b.curIcon = "empty";
	end
	if ( b.cd and b.cdOn ~= false ) then
		b.cdOn = false;
		b.cd:Hide();
	end
	SetCdText(b, "");
	SetRank(b, 0);
	SetHits(b, 0);
	b.tgtKey = nil;
end

local function SetSpell(b, entry)
	b.entry = entry;
	if ( b.curIcon == "empty" ) then
		b.icon:SetVertexColor(1, 1, 1, 1);
		b.tint = "norm";
		b.curIcon = nil;
	end
	local info = G.abilityInfo[entry.key];
	SetIcon(b, info and info.icon);

	local rem = G.SpellRemaining(entry, G.skillNow);
	local cdmax = G.Num(entry.cdmax);
	if ( rem > 0.05 and cdmax > 0 ) then
		if ( b.cd ) then
			local h = math.max(1, math.floor((b.size - 6) * G.Clamp(rem / cdmax, 0, 1) + 0.5));
			if ( b.cdH ~= h ) then
				b.cdH = h;
				b.cd:SetHeight(h);
			end
			if ( b.cdOn ~= true ) then
				b.cdOn = true;
				b.cd:Show();
			end
		end
		SetTint(b, "dim");
		SetCdText(b, G.Rem(rem));
	else
		if ( b.cd and b.cdOn ~= false ) then
			b.cdOn = false;
			b.cd:Hide();
		end
		SetTint(b, "norm");
		SetCdText(b, "");
	end
	-- the skill's rank, where the slot number used to be
	SetRank(b, math.floor(G.Num(entry.rank)));
end

-- "now" is the run clock when the caller already has it (the skill bar reads it once per update, not once per slot)
function G.SpellRemaining(entry, now)
	local base = G.cdEnd and G.cdEnd[entry.key];
	if ( base and AZS_GetRunTime ) then
		local t = now or AZS_GetRunTime();
		if ( t ) then
			return math.max(0, base - t);
		end
	end
	return G.Num(entry.cd);
end

-- the position of a spell in the spellbook, found by name (and rank when there is one): the game's own tooltip for
-- it (description, cost, range, cast time) can be shown with SetSpell. nil when the spell is not in the book.
local function BookIndex(name, rank)
	if ( not ( name and GetNumSpellTabs and GetSpellTabInfo and GetSpellName ) ) then
		return nil;
	end
	local last, exact = nil, nil;
	local want = nil;
	if ( rank and rank > 0 ) then
		want = "Rank " .. rank;
	end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab);
		if ( offset and count ) then
			for i = offset + 1, offset + count do
				local n, r = GetSpellName(i, "spell");
				if ( n == name ) then
					last = i;
					if ( want and r == want ) then
						exact = i;
					end
				end
			end
		end
	end
	return exact or last;
end

-- "arcane_missiles" -> "Arcane Missiles", for a spell the loadout has no name for
local function Pretty(key)
	local t = string.gsub(tostring(key), "_", " ");
	t = string.gsub(t, "(%a)(%a*)", function(a, rest) return string.upper(a) .. rest; end);
	return t;
end

local function SpellTooltip(tt, b)
	local e = b.entry;
	if ( not e ) then
		if ( b == G.racial ) then
			tt:AddLine("Racial ability", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			tt:AddLine("Not available yet", 0.6, 0.6, 0.6);
		end
		return;
	end
	local info = G.abilityInfo[e.key];
	local rem = G.SpellRemaining(e);
	-- the game's own spell tooltip when the spell is in the spellbook
	local idx = BookIndex(info and info.name, math.floor(G.Num(e.rank)));
	if ( idx and tt.SetSpell ) then
		local ok = pcall(tt.SetSpell, tt, idx, "spell");
		if ( ok ) then
			if ( rem > 0.05 ) then
				tt:AddLine(string.format("Ready in %.1f sec", rem), 1, 0.4, 0.4);
			end
			tt:AddLine("Casts automatically", 0.6, 0.6, 0.6);
			return;
		end
	end
	tt:AddLine((info and info.name) or Pretty(e.key), G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	if ( G.Num(e.rank) > 0 ) then
		tt:AddLine("Rank " .. math.floor(G.Num(e.rank)), 0.8, 0.8, 0.8);
	end
	local cdmax = G.Num(e.cdmax);
	if ( cdmax > 0 ) then
		tt:AddLine(string.format("Cooldown: %.1f sec", cdmax), 1, 1, 1);
	end
	if ( rem > 0.05 ) then
		tt:AddLine(string.format("Ready in %.1f sec", rem), 1, 0.4, 0.4);
	else
		tt:AddLine("Ready", 0.4, 1, 0.4);
	end
	tt:AddLine("Casts automatically", 0.6, 0.6, 0.6);
end

------------------------------------------------------------------------ actions of the two small buttons

local function RunAction(which)
	if ( which == "character" and G.CharActive and G.CharActive() ) then
		G.ToggleCharPanel();         -- the GW2 hero panel (the key binding gets there through ToggleCharacter)
		return;
	end
	G.RunKind(which);
end

------------------------------------------------------------------------ build

-- a soft, smoky dark patch behind one side of the bar (it tucks under the orb)
local function Smoke(orb, w, point, relPoint, x, y, flip)
	local f = CreateFrame("Frame", nil, UIParent);
	f:SetWidth(w);
	f:SetHeight(WINGH);
	f:SetFrameStrata("MEDIUM");
	f:SetFrameLevel(math.max(0, orb:GetFrameLevel() - 1));
	f:SetPoint(point, orb, relPoint, x, y);
	if ( G.art.custom ) then
		local t = f:CreateTexture(nil, "BACKGROUND");
		t:SetTexture(G.TEXPATH .. "smoke.tga");
		t:SetAllPoints(f);
		if ( flip ) then
			t:SetTexCoord(1, 0, 0, 1);
		end
	else
		G.Panel(f, 0.7);
	end
	G.Register(f);
	return f;
end

function G.BuildSkills()
	local orb = G.orb;

	-- the dark smoke behind the two sides
	local leftW = RACIAL + OUTER + 3 * SLOT + 2 * GAP;
	local rightW = 3 * SLOT + 2 * GAP + OUTER + SMALL;
	local wl = Smoke(orb, leftW + 44, "BOTTOMRIGHT", "BOTTOMLEFT", 14, LIFT - 12, false);
	local wr = Smoke(orb, rightW + 44, "BOTTOMLEFT", "BOTTOMRIGHT", -14, LIFT - 12, true);
	G.wingL, G.wingR = wl, wr;

	-- six skills: 1 2 3  (orb)  4 5 6
	local function Hook(b)
		G.Tooltip(b, function(tt)
			SpellTooltip(tt, b);
		end, "ANCHOR_TOP");
		SetEmpty(b);
		G.Register(b);
	end
	for i = 3, 1, -1 do
		local b = NewSlot(SLOT, true);
		if ( i == 3 ) then
			b:SetPoint("BOTTOMRIGHT", orb, "BOTTOMLEFT", -SIDE, LIFT);
		else
			b:SetPoint("RIGHT", G.slots[i + 1], "LEFT", -GAP, 0);
		end
		G.slots[i] = b;
		Hook(b);
	end
	for i = 4, 6 do
		local b = NewSlot(SLOT, true);
		if ( i == 4 ) then
			b:SetPoint("BOTTOMLEFT", orb, "BOTTOMRIGHT", SIDE, LIFT);
		else
			b:SetPoint("LEFT", G.slots[i - 1], "RIGHT", GAP, 0);
		end
		G.slots[i] = b;
		Hook(b);
	end

	-- racial: left of the left three
	local racial = NewSlot(RACIAL, true);
	racial:SetPoint("RIGHT", G.slots[1], "LEFT", -OUTER, 0);
	G.Tooltip(racial, function(tt)
		SpellTooltip(tt, racial);
	end, "ANCHOR_TOP");
	SetEmpty(racial);
	G.racial = racial;
	G.Register(racial);

	-- talents (top) and character (bottom): two small buttons right of the right three
	local tal = NewSlot(SMALL, false);
	tal:SetPoint("TOPLEFT", G.slots[6], "TOPRIGHT", OUTER, 0);
	SetIcon(tal, "Interface\\Icons\\INV_Misc_Book_09");
	SetRank(tal, 0);
	tal:SetScript("OnClick", function()
		RunAction("talents");
	end);
	G.Tooltip(tal, function(tt)
		tt:AddLine("Talents", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		tt:AddLine("Click to open", 0.7, 0.7, 0.7);
		tt:AddLine(G.BindingText("talents"), 0.5, 0.5, 0.5);
	end, "ANCHOR_TOP");
	G.talentBtn = tal;
	G.Register(tal);

	local ch = NewSlot(SMALL, false);
	ch:SetPoint("BOTTOMLEFT", G.slots[6], "BOTTOMRIGHT", OUTER, 0);
	ch.icon:SetTexture(G.CLASSICON);
	ch.curIcon = G.CLASSICON;
	SetRank(ch, 0);
	ch:SetScript("OnClick", function()
		RunAction("character");
	end);
	G.Tooltip(ch, function(tt)
		local z = AZS_ZONE or {};
		tt:AddLine(z.hero or "Character", G.ClassColor(z.class));
		tt:AddLine("Click to open the character panel", 0.7, 0.7, 0.7);
		tt:AddLine(G.BindingText("character"), 0.5, 0.5, 0.5);
	end, "ANCHOR_TOP");
	G.charBtn = ch;
	G.Register(ch);

	-- the whole bar (orb, slots, experience arcs) moves as one when the layout is unlocked
	local box = CreateFrame("Frame", nil, UIParent);
	box:SetPoint("BOTTOMLEFT", racial, "BOTTOMLEFT", -6, -14);
	box:SetPoint("TOPRIGHT", ch, "TOPRIGHT", 6, 74);
	G.barBox = box;
	G.Movable(orb, "orb", "Skill bar", box, box);

	-- jewelry: a small steel plate right of the bar, 3 x 2 icons
	local plate = CreateFrame("Frame", nil, UIParent);
	plate:SetWidth(82);
	plate:SetHeight(SLOT + 2);
	plate:SetFrameStrata("MEDIUM");
	plate:SetPoint("BOTTOMLEFT", ch, "BOTTOMRIGHT", 8, 0);
	plate:Hide();
	local pbg = G.Solid(plate, "BACKGROUND", 0.05, 0.05, 0.06, 0.92);
	pbg:SetAllPoints(plate);
	G.Frame9(plate, "BORDER");
	G.Register(plate, true);
	G.jewPlate = plate;
	G.jewSlots = {};
	for i = 1, 6 do
		local j = CreateFrame("Frame", nil, UIParent);
		j:SetWidth(22);
		j:SetHeight(22);
		j:SetFrameStrata("MEDIUM");
		j:SetFrameLevel(plate:GetFrameLevel() + 2);
		local col, row = math.mod(i - 1, 3), math.floor((i - 1) / 3);
		j:SetPoint("TOPLEFT", plate, "TOPLEFT", 6 + col * 24, -(5 + row * 24));
		local t = j:CreateTexture(nil, "BACKGROUND");
		t:SetPoint("TOPLEFT", j, "TOPLEFT", 2, -2);
		t:SetPoint("BOTTOMRIGHT", j, "BOTTOMRIGHT", -2, 2);
		t:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		j.icon = t;
		G.Edges(j, 0.55, 0.55, 0.60, 1, 1, "ARTWORK");
		G.Tooltip(j, function(tt)
			if ( j.data ) then
				tt:AddLine(j.data.name, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
				if ( j.data.category ) then
					tt:AddLine(tostring(j.data.category), 0.7, 0.7, 0.7);
				end
			end
		end, "ANCHOR_TOP");
		j:Hide();
		G.jewSlots[i] = j;
		G.Register(j, true);
	end

	-- buffs (lower row) and debuffs (upper row) above the right-hand side of the bar, as in GW2
	local function BuildAuraRow(row, point, anchor, relPoint, x, y)
		for i = 1, AURAS do
			local a = CreateFrame("Frame", nil, UIParent);
			a:SetWidth(AURASIZE);
			a:SetHeight(AURASIZE);
			a:SetFrameStrata("HIGH");
			if ( i == 1 ) then
				a:SetPoint(point, anchor, relPoint, x, y);
			else
				a:SetPoint("LEFT", row[i - 1], "RIGHT", 2, 0);
			end
			local t = a:CreateTexture(nil, "BACKGROUND");
			t:SetPoint("TOPLEFT", a, "TOPLEFT", 1, -1);
			t:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -1, 1);
			t:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			a.icon = t;
			G.Edges(a, G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95, 1, "ARTWORK");
			local tf = CreateFrame("Frame", nil, a);
			tf:SetAllPoints(a);
			tf:SetFrameLevel(a:GetFrameLevel() + 3);
			a.count = G.Text(tf, 10, "RIGHT");
			a.count:SetPoint("TOPRIGHT", a, "TOPRIGHT", -2, -2);
			a.time = G.Text(tf, 9, "CENTER");
			a.time:SetPoint("BOTTOM", a, "BOTTOM", 0, 2);
			G.Tooltip(a, function(tt)
				local d = a.data;
				if ( d and d.index and tt.SetPlayerBuff ) then
					tt:SetPlayerBuff(d.index);
				elseif ( d ) then
					tt:AddLine("Effect", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
				end
			end, "ANCHOR_TOP");
			a:Hide();
			row[i] = a;
			G.Register(a, true);
		end
	end
	G.buffs = {};
	G.debuffs = {};
	BuildAuraRow(G.buffs, "BOTTOMLEFT", G.slots[4], "TOPLEFT", 6, 12);
	BuildAuraRow(G.debuffs, "BOTTOMLEFT", G.buffs[1], "TOPLEFT", 0, 6);

	-- status rows above the left three skills: summons and totems (two rows of six)
	G.status = {};
	for i = 1, STATUS do
		local s = CreateFrame("Frame", nil, UIParent);
		s:SetWidth(STATUSSIZE);
		s:SetHeight(STATUSSIZE);
		s:SetFrameStrata("MEDIUM");
		if ( i == 1 ) then
			s:SetPoint("BOTTOMLEFT", G.slots[1], "TOPLEFT", 0, 10);
		elseif ( i == STATUSROW + 1 ) then
			s:SetPoint("BOTTOMLEFT", G.status[1], "TOPLEFT", 0, 2);
		else
			s:SetPoint("LEFT", G.status[i - 1], "RIGHT", 2, 0);
		end
		local t = s:CreateTexture(nil, "BACKGROUND");
		t:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1);
		t:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1);
		t:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		s.icon = t;
		G.Edges(s, 0.45, 0.37, 0.22, 1, 1, "ARTWORK");
		local tf = CreateFrame("Frame", nil, s);
		tf:SetAllPoints(s);
		tf:SetFrameLevel(s:GetFrameLevel() + 3);
		s.count = G.Text(tf, 10, "RIGHT");
		s.count:SetPoint("TOPRIGHT", s, "TOPRIGHT", -2, -2);
		s.time = G.Text(tf, 10, "CENTER");
		s.time:SetPoint("BOTTOM", s, "BOTTOM", 0, 2);
		G.Tooltip(s, function(tt)
			local d = s.data;
			if ( d ) then
				tt:AddLine(d.name or "?", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
				if ( d.note ) then
					tt:AddLine(d.note, 0.7, 0.7, 0.7);
				end
			end
		end, "ANCHOR_TOP");
		s:Hide();
		G.status[i] = s;
		G.Register(s, true);
	end
end

------------------------------------------------------------------------ update

function G.UpdateSkills(dt)
	if ( not G.slots[1] ) then
		return;
	end

	-- re-base the cooldown clocks whenever the game's spell table changes
	local stamp = AZS_SPELLS_UPDATED;
	if ( stamp ~= G.lastSpellStamp ) then
		G.lastSpellStamp = stamp;
		if ( stamp ) then
			local t = G.RunTime();
			G.cdEnd = {};
			local sp = AZS_SPELLS or {};
			for i = 1, table.getn(sp) do
				G.cdEnd[sp[i].key] = t + G.Num(sp[i].cd);
			end
		end
	end

	G.skillNow = AZS_GetRunTime and AZS_GetRunTime() or nil;
	local spells = AZS_SPELLS or {};
	local n = table.getn(spells);
	local racialEntry = nil;
	local mainCount = n;
	if ( n > 0 ) then
		racialEntry = spells[n];
		mainCount = n - 1;
	end
	for i = 1, 6 do
		if ( i <= mainCount ) then
			SetSpell(G.slots[i], spells[i]);
		else
			SetEmpty(G.slots[i]);
		end
	end
	if ( racialEntry ) then
		SetSpell(G.racial, racialEntry);
	else
		SetEmpty(G.racial);
	end
	G.skillNow = nil;

	-- the class icon on the character button
	local z = AZS_ZONE or {};
	local c = G.CLASSCOORDS[z.class or ""];
	if ( c and G.charBtn.classShown ~= c ) then
		G.charBtn.classShown = c;
		G.charBtn.icon:SetTexCoord(c[1] + 0.01, c[2] - 0.01, c[3] + 0.01, c[4] - 0.01);
	end
end

------------------------------------------------------------------------ how many targets a skill can hit

-- The game's own spell tooltip says it ("Strikes the 5 nearest enemies within 30 yd ..."), and the +targets of upgrades
-- and cards are already in that number. So a hidden tooltip of ours is given the spell and its text is read: the number
-- on the chip is the most the skill can hit, whether or not that many enemies are near. A skill for one enemy shows
-- nothing. One skill is read per look (a changed skill first, the others about every three seconds, as upgrades come
-- and go), never all of them at once.
local TGT_AGE = 3;
local scanTip = nil;

local function ScanTip()
	if ( scanTip == nil ) then
		scanTip = false;
		local ok, tt = pcall(CreateFrame, "GameTooltip", "AZSGW2ScanTip", UIParent, "GameTooltipTemplate");
		if ( ok and tt and tt.SetSpell and tt.SetOwner and tt.NumLines ) then
			scanTip = tt;
		end
	end
	return scanTip or nil;
end

-- "Strikes the 5 nearest enemies within 30 yd" -> 5. Lines of upgrades and bonuses ("+1 target") are not the description.
local function TargetsInText(text)
	local s = string.lower(text);
	if ( string.find(s, "%+%d+ target") or string.find(s, "^upgrades") or string.find(s, "^your bonuses") ) then
		return nil;
	end
	local _, _, n = string.find(s, "(%d+) nearest enem");
	if ( not n ) then
		_, _, n = string.find(s, "up to (%d+) enem");
	end
	if ( not n ) then
		_, _, n = string.find(s, "up to (%d+) target");
	end
	if ( not n ) then
		_, _, n = string.find(s, "(%d+) random enem");
	end
	if ( not n ) then
		_, _, n = string.find(s, "(%d+) nearby enem");
	end
	if ( not n ) then
		_, _, n = string.find(s, "(%d+) enemies");
	end
	if ( not n ) then
		_, _, n = string.find(s, "(%d+) targets");
	end
	return tonumber(n);
end

local function KeyOf(e)
	return tostring(e.key) .. ":" .. tostring(math.floor(G.Num(e.rank)));
end

local function ReadTargets(b)
	local e = b.entry;
	local now = GetTime();
	b.tgtAt = now;
	if ( not e ) then
		b.tgtKey = nil;
		SetHits(b, 0);
		return;
	end
	local key = KeyOf(e);
	if ( b.tgtKey ~= key ) then
		b.tgtKey = key;
		b.bookIdx, b.bookAt = nil, nil;
	end
	-- where the skill stands in the spellbook: looked up once per skill and rank. Until the loadout has told the skill's
	-- name, and for a skill that is not in the book, it is tried again every few seconds, not every look.
	if ( not b.bookIdx ) then
		local info = G.abilityInfo[e.key];
		if ( info and info.name and now - ( b.bookAt or -100 ) >= 5 ) then
			b.bookAt = now;
			b.bookIdx = BookIndex(info.name, math.floor(G.Num(e.rank)));
		end
	end
	local n = 0;
	local tt = b.bookIdx and ScanTip();
	if ( tt ) then
		tt:SetOwner(UIParent, "ANCHOR_NONE");
		local ok = pcall(tt.SetSpell, tt, b.bookIdx, "spell");
		if ( ok ) then
			for i = 2, tt:NumLines() do
				local fs = getglobal("AZSGW2ScanTipTextLeft" .. i);
				local text = fs and fs:GetText();
				if ( text ) then
					local c = TargetsInText(text);
					if ( c ) then
						n = c;
						break;
					end
				end
			end
		end
		tt:Hide();
	end
	if ( n >= 2 ) then
		SetHits(b, math.min(n, 99));
	else
		SetHits(b, 0);
	end
end

G.tgtCursor = 0;
G.tgtOff = false;

function G.UpdateTargets(dt)
	if ( not G.slots[1] ) then
		return;
	end
	if ( not G.shown or not G.Opt("hits") ) then
		if ( not G.tgtOff ) then
			G.tgtOff = true;
			for i = 1, 7 do
				local b = G.slots[i];
				if ( i == 7 ) then
					b = G.racial;
				end
				if ( b ) then
					SetHits(b, 0);
					b.tgtKey, b.tgtAt = nil, nil;
				end
			end
		end
		return;
	end
	G.tgtOff = false;
	local now = GetTime();
	-- a skill that changed (or is new) is read first
	local pick = nil;
	for i = 1, 7 do
		local b = G.slots[i];
		if ( i == 7 ) then
			b = G.racial;
		end
		if ( b and b.entry and b.tgtKey ~= KeyOf(b.entry) ) then
			pick = b;
			break;
		end
	end
	-- else the next one that was read a while ago
	if ( not pick ) then
		for step = 1, 7 do
			G.tgtCursor = G.tgtCursor + 1;
			if ( G.tgtCursor > 7 ) then
				G.tgtCursor = 1;
			end
			local b = G.slots[G.tgtCursor];
			if ( G.tgtCursor == 7 ) then
				b = G.racial;
			end
			if ( b and b.entry and now - ( b.tgtAt or -100 ) >= TGT_AGE ) then
				pick = b;
				break;
			end
		end
	end
	if ( pick ) then
		ReadTargets(pick);
	end
end

function G.UpdateJewelry(dt)
	if ( not G.jewSlots ) then
		return;
	end
	G.RefreshLoadout();
	local jew = G.jewelry or {};
	if ( G.jewPlate ) then
		if ( G.shown and table.getn(jew) > 0 ) then
			G.jewPlate:Show();
		else
			G.jewPlate:Hide();
		end
	end
	for i = 1, 6 do
		local j = G.jewSlots[i];
		local d = jew[i];
		if ( d and G.shown ) then
			j.data = d;
			j.icon:SetTexture(d.icon or G.QUESTION);
			j.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			j:Show();
		else
			j.data = nil;
			j:Hide();
		end
	end
end

function G.UpdateStatus(dt)
	if ( not G.status ) then
		return;
	end
	local list = {};
	local function add(e)
		if ( table.getn(list) < STATUS ) then
			table.insert(list, e);
		end
	end

	if ( AZS_GetSummonGroups ) then
		local groups = AZS_GetSummonGroups();
		if ( groups ) then
			for i = 1, table.getn(groups) do
				local g = groups[i];
				local note = nil;
				if ( g.permanent and g.permanent > 0 and g.temporary == 0 ) then
					note = "Permanent";
				end
				add({ icon = g.icon, count = g.count, remaining = g.remaining, name = g.name, note = note });
			end
		end
	end
	if ( AZS_GetTotems ) then
		local totems = AZS_GetTotems();
		if ( totems ) then
			for i = 1, table.getn(totems) do
				local t = totems[i];
				add({ icon = t.icon, count = t.count, remaining = t.remaining, name = t.name, note = "Totem" });
			end
		end
	end

	for i = 1, STATUS do
		local s = G.status[i];
		local e = list[i];
		if ( e and G.shown ) then
			s.data = e;
			s.icon:SetTexture(e.icon or G.QUESTION);
			s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			s.icon:SetVertexColor(1, 1, 1, 1);
			if ( e.count and e.count > 1 ) then
				s.count:SetText(tostring(e.count));
			else
				s.count:SetText("");
			end
			if ( e.remaining ) then
				s.time:SetText(G.Rem(e.remaining));
			else
				s.time:SetText("");
			end
			s:Show();
		else
			s.data = nil;
			s:Hide();
		end
	end
end

------------------------------------------------------------------------ buffs / debuffs of your hero

-- the 1.12 player aura API: ids from 0, -1 when there is none
function G.CollectAuras(filter)
	local list = {};
	if ( not GetPlayerBuff ) then
		return list;
	end
	for i = 0, 31 do
		local idx = GetPlayerBuff(i, filter);
		if ( type(idx) == "number" and idx >= 0 ) then
			local tex = nil;
			if ( GetPlayerBuffTexture ) then
				tex = GetPlayerBuffTexture(idx);
			end
			if ( tex ) then
				local left, count, dispel = 0, 0, nil;
				if ( GetPlayerBuffTimeLeft ) then
					left = GetPlayerBuffTimeLeft(idx) or 0;
				end
				if ( GetPlayerBuffApplications ) then
					count = GetPlayerBuffApplications(idx) or 0;
				end
				if ( GetPlayerBuffDispelType ) then
					dispel = GetPlayerBuffDispelType(idx);
				end
				table.insert(list, { index = idx, icon = tex, left = left, count = count, dispel = dispel });
				if ( table.getn(list) >= AURAS ) then
					break;
				end
			end
		end
	end
	return list;
end

local DISPEL = {
	Magic = { 0.25, 0.60, 1.0 }, Curse = { 0.65, 0.10, 1.0 },
	Disease = { 0.65, 0.45, 0.10 }, Poison = { 0.10, 0.65, 0.15 },
};

local function ShowAuras(frames, list, harmful)
	for i = 1, AURAS do
		local a = frames[i];
		local d = list[i];
		if ( d and G.shown ) then
			a.data = d;
			a.icon:SetTexture(d.icon);
			a.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			if ( harmful ) then
				local c = DISPEL[d.dispel or ""] or { 0.80, 0.10, 0.10 };
				G.EdgeColor(a, c[1], c[2], c[3], 1);
			end
			if ( G.Num(d.count) > 1 ) then
				a.count:SetText(tostring(math.floor(d.count)));
			else
				a.count:SetText("");
			end
			if ( G.Num(d.left) > 0 ) then
				a.time:SetText(G.Rem(d.left));
			else
				a.time:SetText("");
			end
			a:Show();
		else
			a.data = nil;
			a:Hide();
		end
	end
end

function G.UpdateAuras(dt)
	if ( not G.buffs ) then
		return;
	end
	ShowAuras(G.buffs, G.CollectAuras("HELPFUL"), false);
	ShowAuras(G.debuffs, G.CollectAuras("HARMFUL"), true);
end
