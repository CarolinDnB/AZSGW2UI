-- AZS GW2 UI: Meter.lua
-- Replaces the game's meter window (hidden with AZS_SetHudShown("meter", false)).
-- Tabs: Damage, Healing, Boss, Party. Shift + drag moves it.

local G = AZSGW2;

local ROWS = 8;
local ROWH = 18;
local W = 256;

local TABS = {
	{ key = "damage", label = "Damage" },
	{ key = "healing", label = "Healing" },
	{ key = "boss", label = "Boss" },
	{ key = "party", label = "Party" },
};

local function GetData(mode)
	if ( mode == "healing" and AZS_GetHealing ) then
		return AZS_GetHealing();
	elseif ( mode == "boss" and AZS_GetBossMeter ) then
		return AZS_GetBossMeter();
	elseif ( mode == "party" and AZS_GetPartyMeter ) then
		return AZS_GetPartyMeter();
	elseif ( AZS_GetMeter ) then
		return AZS_GetMeter();
	end
	return nil;
end

------------------------------------------------------------------------ spell icons
-- The meter lines carry names only. The icons come from the meter API's snapshot (every source has its
-- own icon there) and from the skill bar's loadout, joined by name; what has none gets a stand-in.

G.meterIcons = {};
G.meterTry = {};
G.meterN = 0;                -- how many names the two tables hold: they are emptied past a limit, never unbounded
local MAXNAMES = 400;

local function Learn(name, path)
	if ( G.meterIcons[name] == nil ) then
		if ( G.meterN >= MAXNAMES ) then
			G.meterIcons, G.meterTry, G.meterN = {}, {}, 0;
		end
		G.meterN = G.meterN + 1;
	end
	G.meterIcons[name] = path;
end
local SNAPGAP = 3;       -- seconds between snapshot reads, and only when a line has no icon yet
local RETRY = 15;        -- seconds before asking again for a name whose icon was not ready

local STANDIN = {
	melee = "Interface\\Icons\\Ability_MeleeDamage",
	regeneration = "Interface\\Icons\\Spell_Nature_Rejuvenation",
	leech = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
	thorns = "Interface\\Icons\\Spell_Nature_Thorns",
	pets = "Interface\\Icons\\Ability_Hunter_BeastCall",
};
local UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark";

local function ReadIcons(mode, lines)
	for key, info in pairs(G.abilityInfo or {}) do
		if ( info.name and info.icon and G.meterIcons[info.name] ~= info.icon ) then
			Learn(info.name, info.icon);
		end
	end
	local icons = G.meterIcons;
	if ( not AZS_GetMeterContext or not AZS_GetMeterSnapshot or mode == "party" ) then
		return;
	end
	-- the snapshot call is only made for lines that still have no icon (and not more often than the gap
	-- allows): while the same spells fight on, the meter makes no API call here at all
	local now = GetTime();
	local need = false;
	for i = 1, table.getn(lines or {}) do
		local n = tostring(lines[i].name or "");
		if ( not icons[n] and not STANDIN[string.lower(n)] ) then
			local last = G.meterTry[n];
			if ( not last or now - last >= RETRY ) then
				need = true;
			end
		end
	end
	if ( not need or ( G.meterSnapAt and now - G.meterSnapAt < SNAPGAP ) ) then
		return;
	end
	G.meterSnapAt = now;
	if ( ( G.meterTryN or 0 ) > MAXNAMES ) then
		G.meterTry, G.meterTryN = {}, 0;
	end
	local tries = G.meterTry;
	for i = 1, table.getn(lines or {}) do
		local n = tostring(lines[i].name or "");
		if ( tries[n] == nil ) then
			G.meterTryN = ( G.meterTryN or 0 ) + 1;
		end
		tries[n] = now;
	end
	local ctx = AZS_GetMeterContext();
	if ( not ctx ) then
		return;
	end
	local q = { apiVersion = 1, runId = ctx.runId, metric = "damage", scope = "self", period = "run",
		groupBy = "source", windowSeconds = 0 };
	if ( mode == "healing" ) then
		q.metric = "healing";
	elseif ( mode == "boss" ) then
		q.period = "encounter";
	end
	local snap = AZS_GetMeterSnapshot(q);
	if ( snap and snap.sources ) then
		for key, src in pairs(snap.sources) do
			if ( src.name and src.icon and src.icon.status == "ready" and src.icon.path ) then
				Learn(src.name, src.icon.path);
			end
		end
	end
end

local function IconFor(name)
	name = tostring(name or "");
	return G.meterIcons[name] or STANDIN[string.lower(name)] or UNKNOWN;
end

local function SetMode(mode)
	AZSGW2DB.meterMode = mode;
	local f = G.meter;
	if ( not f ) then
		return;
	end
	for i = 1, table.getn(TABS) do
		local t = f.tabs[i];
		if ( TABS[i].key == mode ) then
			t.text:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			t.line:Show();
		else
			t.text:SetTextColor(0.62, 0.62, 0.62);
			t.line:Hide();
		end
	end
	G.meterAcc = 99;
end

function G.BuildMeter()
	local f = CreateFrame("Frame", "AZSGW2Meter", UIParent);
	f:SetWidth(W);
	f:SetHeight(20 + 18 + ROWS * ROWH + 6);
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 16);
	f:SetFrameStrata("MEDIUM");
	G.Register(f);
	G.meter = f;
	G.Panel(f, 0.62);
	G.Movable(f, "meter", "Damage meter", nil, nil, true);

	f.tabs = {};
	for i = 1, table.getn(TABS) do
		local t = CreateFrame("Button", nil, f);
		t:SetWidth(60);
		t:SetHeight(18);
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + (i - 1) * 62, -2);
		t.text = G.Text(t, 11, "CENTER");
		t.text:SetPoint("CENTER", t, "CENTER", 0, 0);
		t.text:SetText(TABS[i].label);
		t.line = G.Solid(t, "ARTWORK", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.9);
		t.line:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 4, 0);
		t.line:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -4, 0);
		t.line:SetHeight(1);
		local key = TABS[i].key;
		t:SetScript("OnClick", function()
			SetMode(key);
		end);
		f.tabs[i] = t;
	end

	f.summary = G.Text(f, 11, "LEFT");
	f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -23);
	f.summary:SetTextColor(0.85, 0.85, 0.85);

	f.rows = {};
	for i = 1, ROWS do
		local r = CreateFrame("Frame", nil, f);
		r:SetWidth(W - 8);
		r:SetHeight(ROWH - 2);
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -40 - (i - 1) * ROWH);
		r.bar = G.Solid(r, "BACKGROUND", 0.8, 0.4, 0.1, 0.55);
		r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0);
		r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0);
		r.bar:SetWidth(1);
		-- spell icon, framed, left of the name
		r.iconBack = G.Solid(r, "ARTWORK", 0.02, 0.02, 0.02, 0.95);
		r.iconBack:SetWidth(ROWH - 2);
		r.iconBack:SetHeight(ROWH - 2);
		r.iconBack:SetPoint("LEFT", r, "LEFT", 0, 0);
		r.icon = r:CreateTexture(nil, "OVERLAY");
		r.icon:SetWidth(ROWH - 4);
		r.icon:SetHeight(ROWH - 4);
		r.icon:SetPoint("CENTER", r.iconBack, "CENTER", 0, 0);
		r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		r.name = G.Text(r, 11, "LEFT");
		r.name:SetPoint("LEFT", r.iconBack, "RIGHT", 5, 0);
		r.name:SetWidth(112);
		r.name:SetHeight(12);
		r.val = G.Text(r, 11, "RIGHT");
		r.val:SetPoint("RIGHT", r, "RIGHT", -4, 0);
		G.Tooltip(r, function(tt)
			local d = r.data;
			if ( not d ) then
				return;
			end
			tt:AddLine(tostring(d.name or "?"), G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			tt:AddLine(G.Comma(d.dmg) .. "  (" .. G.Short(d.dmg) .. ")", 1, 1, 1);
			tt:AddLine(string.format("%s per second", G.Short(d.dps)), 0.8, 0.8, 0.8);
			tt:AddLine(string.format("%.1f%% of the total", G.Num(d.share) * 100), 0.8, 0.8, 0.8);
			if ( d.top and d.top ~= "" ) then
				tt:AddLine("Best: " .. d.top .. " (" .. G.Short(d.topdps) .. "/s)", 0.6, 0.9, 0.6);
			end
		end, "ANCHOR_LEFT");
		r:Hide();
		f.rows[i] = r;
	end

	G.meterAcc = 99;
	SetMode(AZSGW2DB.meterMode or "damage");
end

function G.UpdateMeter(dt)
	local f = G.meter;
	if ( not f ) then
		return;
	end
	if ( not G.Opt("meter") ) then
		f:Hide();
		return;
	end
	local mode = AZSGW2DB.meterMode or "damage";
	local lines, total, rate = GetData(mode);
	lines = lines or {};
	f.iconAcc = ( f.iconAcc or 99 ) + dt;
	if ( f.iconAcc >= 1 or f.iconMode ~= mode ) then
		f.iconAcc = 0;
		f.iconMode = mode;
		ReadIcons(mode, lines);
	end

	local unit = "DPS";
	if ( mode == "healing" ) then
		unit = "HPS";
	end
	f.summary:SetText(string.format("Total: %s   %s: %s", G.Short(total), unit, G.Short(rate)));

	local maxShare = 0;
	if ( lines[1] ) then
		maxShare = G.Num(lines[1].share);
	end
	local inner = W - 8;
	for i = 1, ROWS do
		local r = f.rows[i];
		local d = lines[i];
		if ( d ) then
			r.data = d;
			r:Show();
			local cr, cg, cb = 0.85, 0.45, 0.10;
			if ( mode == "healing" ) then
				cr, cg, cb = 0.20, 0.70, 0.30;
			elseif ( mode == "boss" ) then
				cr, cg, cb = 0.75, 0.15, 0.15;
			elseif ( mode == "party" ) then
				cr, cg, cb = G.ClassColor(d.class);
			elseif ( G.Num(d.proc) == 1 ) then
				cr, cg, cb = 0.25, 0.50, 0.90;
			end
			r.bar:SetVertexColor(cr, cg, cb, 0.55);
			local w = 1;
			if ( maxShare > 0 ) then
				w = math.max(1, inner * G.Clamp(G.Num(d.share) / maxShare, 0, 1));
			end
			r.bar:SetWidth(w);
			r.name:SetText(tostring(d.name or "?"));
			if ( mode == "party" ) then
				r.iconBack:Hide();
				r.icon:Hide();
				r.name:ClearAllPoints();
				r.name:SetPoint("LEFT", r, "LEFT", 4, 0);
			else
				r.iconBack:Show();
				r.icon:Show();
				r.icon:SetTexture(IconFor(d.name));
				r.name:ClearAllPoints();
				r.name:SetPoint("LEFT", r.iconBack, "RIGHT", 5, 0);
			end
			r.val:SetText(string.format("%s  %.1f%%", G.Short(d.dmg), G.Num(d.share) * 100));
		else
			r.data = nil;
			r:Hide();
		end
	end
	-- the window is only as tall as the lines it shows
	local n = math.min(table.getn(lines), ROWS);
	if ( n < 1 ) then
		n = 1;
	end
	local h = 44 + n * ROWH;
	if ( f.curH ~= h ) then
		f.curH = h;
		f:SetHeight(h);
	end
end
