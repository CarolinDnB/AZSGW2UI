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

-- the spell a line is known by: its own name, and on the Party tab the player's best spell (the line's name is the player)
local function SpellOf(mode, d)
	if ( mode == "party" ) then
		return tostring(d.top or "");
	end
	return tostring(d.name or "");
end

local function ReadIcons(mode, lines)
	for key, info in pairs(G.abilityInfo or {}) do
		if ( info.name and info.icon and G.meterIcons[info.name] ~= info.icon ) then
			Learn(info.name, info.icon);
		end
	end
	local icons = G.meterIcons;
	if ( not AZS_GetMeterContext or not AZS_GetMeterSnapshot ) then
		return;
	end
	-- the snapshot call is only made for lines that still have no icon (and not more often than the gap
	-- allows): while the same spells fight on, the meter makes no API call here at all
	local now = GetTime();
	local need = false;
	for i = 1, table.getn(lines or {}) do
		local n = SpellOf(mode, lines[i]);
		if ( n ~= "" and not icons[n] and not STANDIN[string.lower(n)] ) then
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
		local n = SpellOf(mode, lines[i]);
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
	elseif ( mode == "party" ) then
		q.scope = "party";                     -- every hero's sources: their icons are in the descriptors
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

------------------------------------------------------------------------ reset and the 10 second rate
-- Reset: the game's counters cannot be cleared (the API only reads them), so a reset remembers what every line
-- had at that moment and shows the difference from then on, on all four tabs. A new run, or a counter that
-- went down (a new boss fight), ends the remembered state and the game's numbers show again.
-- The rate is the damage (healing) of the last 10 seconds. The game's meter API counts it (with the hero's pets,
-- summons and totems, which is where the numbers of a pet class come from), once a second for the tab on screen,
-- and from the reset on: a reset takes a checkpoint of the API too. When the API cannot say (an older game, an
-- error) the addon works it out itself: every tab's total is noted (twice a second on screen, once a second
-- otherwise) and the rate is what was added over the last 10 seconds. A total that goes down (a source left the
-- list, a new fight) takes nothing back and does not start the history over.

local WINDOW = 10;
local RATEGAP = 1;               -- seconds between two asks of the API for the rate
local RATEFRESH = 3;             -- an answer older than this is not shown
local base = {};                 -- base[mode] = { map = { name = amount }, total = amount, run = runId }
local rings = {};                -- rings[mode] = { t = { time, ... }, v = { added so far, ... }, last = total, cum = added so far }
local skipNote = {};             -- skipNote[mode]: the next note is a new start (the baseline went), not damage
local apiRate = {};              -- apiRate[mode] = { asked = time, value = rate, at = time }
G.meterResetAt = nil;
G.meterCheckpoint = nil;         -- the API checkpoint of the last reset
G.meterCheckpointWanted = false;

local function RunId()
	if ( AZS_GetMeterContext ) then
		local ctx = AZS_GetMeterContext();
		if ( type(ctx) == "table" and type(ctx.runId) == "string" ) then
			return ctx.runId;
		end
	end
	return nil;
end

function G.ResetMeter()
	local run = RunId();
	base, rings, skipNote, apiRate = {}, {}, {}, {};
	if ( G.meterCheckpoint and AZS_ReleaseMeterCheckpoint ) then
		pcall(AZS_ReleaseMeterCheckpoint, G.meterCheckpoint);
	end
	G.meterCheckpoint = nil;
	G.meterCheckpointWanted = true;                      -- taken with the next rate read
	for i = 1, table.getn(TABS) do
		local mode = TABS[i].key;
		local lines, total = GetData(mode);
		local b = { map = {}, total = G.Num(total), run = run };
		for j = 1, table.getn(lines or {}) do
			local d = lines[j];
			if ( d.name ~= nil ) then
				b.map[tostring(d.name)] = G.Num(d.dmg);
			end
		end
		base[mode] = b;
	end
	G.meterResetAt = GetTime();
	if ( G.meter ) then
		G.UpdateMeter(0);
	end
end

-- the lines and the total as they stand since the reset (changes the lines in place: they are a copy)
local function Rebase(mode, lines, total)
	local b = base[mode];
	if ( not b ) then
		return lines, total;
	end
	local over = false;
	if ( b.run and RunId() ~= b.run ) then
		over = true;                                       -- another run
	elseif ( G.Num(total) < b.total - 0.5 ) then
		over = true;                                       -- the counters started over (a new boss fight)
	else
		for i = 1, table.getn(lines) do
			local o = b.map[tostring(lines[i].name)];
			if ( o and G.Num(lines[i].dmg) < o - 0.5 ) then
				over = true;
				break;
			end
		end
	end
	if ( over ) then
		base[mode] = nil;
		skipNote[mode] = true;                             -- the total jumps back to the game's own: not damage
		return lines, total;
	end
	local out, sum = {}, 0;
	local span = math.max(1, GetTime() - ( G.meterResetAt or GetTime() ));
	for i = 1, table.getn(lines) do
		local d = lines[i];
		local v = G.Num(d.dmg) - ( b.map[tostring(d.name)] or 0 );
		if ( v > 0.5 ) then
			d.dmg, d.dps = v, v / span;
			sum = sum + v;
			table.insert(out, d);
		end
	end
	table.sort(out, function(a, c) return a.dmg > c.dmg; end);
	for i = 1, table.getn(out) do
		out[i].share = out[i].dmg / sum;
	end
	-- the game's total minus the total at the reset also counts sources the list does not show
	return out, math.max(sum, G.Num(total) - b.total);
end

-- notes the total of a tab. The history keeps what was ADDED: a total that went down (a source left the list, a new
-- fight, a pet that is gone) is not damage taken back, and the rate goes on from the new level
local function Note(mode, now, total)
	local r = rings[mode];
	if ( not r ) then
		r = { t = {}, v = {}, last = total, cum = 0 };
		rings[mode] = r;
	end
	local d = total - r.last;
	r.last = total;
	if ( skipNote[mode] ) then
		skipNote[mode] = nil;
		d = 0;
	end
	if ( d > 0 ) then
		r.cum = r.cum + d;
	end
	local n = table.getn(r.t);
	r.t[n + 1], r.v[n + 1] = now, r.cum;
	-- one note older than the window is kept, the rest goes
	while ( table.getn(r.t) > 2 and r.t[2] <= now - WINDOW ) do
		table.remove(r.t, 1);
		table.remove(r.v, 1);
	end
end

-- per second over the last WINDOW seconds (0 while there is no history yet)
local function RateOf(mode, now)
	local r = rings[mode];
	local n = r and table.getn(r.t) or 0;
	if ( n < 2 ) then
		return 0;
	end
	local span = r.t[n] - r.t[1];
	if ( span < 0.25 ) then
		return 0;
	end
	return math.max(0, ( r.v[n] - r.v[1] ) / span);
end

-- the rate of the last 10 seconds as the game's meter API counts it (the hero with pets, summons and totems), nil when
-- it cannot say; asked once a second at most
local function ApiRateOf(mode, now)
	if ( not AZS_GetMeterContext or not AZS_GetMeterSnapshot ) then
		return nil;
	end
	local a = apiRate[mode];
	if ( not a ) then
		a = { asked = -100 };
		apiRate[mode] = a;
	end
	if ( now - a.asked >= RATEGAP ) then
		a.asked = now;
		local ctx = AZS_GetMeterContext();
		if ( type(ctx) == "table" and type(ctx.runId) == "string" ) then
			if ( G.meterCheckpointWanted and not G.meterCheckpoint and AZS_CreateMeterCheckpoint ) then
				local cp = AZS_CreateMeterCheckpoint(ctx.runId);
				if ( type(cp) == "table" and type(cp.checkpointId) == "string" ) then
					G.meterCheckpoint = cp.checkpointId;
					G.meterCheckpointWanted = false;
				end
			end
			local q = { apiVersion = 1, runId = ctx.runId, metric = "damage", scope = "self", period = "run",
				groupBy = "owner", windowSeconds = WINDOW };
			if ( mode == "healing" ) then
				q.metric = "healing";
			elseif ( mode == "boss" ) then
				q.period = "encounter";
			elseif ( mode == "party" ) then
				q.scope = "party";
			end
			if ( G.meterCheckpoint ) then
				q.checkpointId = G.meterCheckpoint;
			end
			local snap, err = AZS_GetMeterSnapshot(q);
			if ( snap and type(snap.totals) == "table" and type(snap.totals.displayRate) == "table" ) then
				local rate = snap.totals.displayRate;
				if ( rate.status == "ready" and type(rate.value) == "number" and rate.value == rate.value and rate.value >= 0 ) then
					a.value, a.at = rate.value, now;
				end
			elseif ( err and type(err.code) == "string" and string.find(err.code, "^CHECKPOINT" ) ) then
				G.meterCheckpoint = nil;                     -- gone (a new run, a /reload): the next ask goes without it
			end
		end
	end
	if ( a.value and now - a.at <= RATEFRESH ) then
		return a.value;
	end
	return nil;
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

	local rb = CreateFrame("Button", nil, f);                 -- Reset: all four tabs start from zero
	rb:SetWidth(40);
	rb:SetHeight(15);
	rb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -22);
	G.Solid(rb, "BACKGROUND", 0.05, 0.05, 0.06, 0.85):SetAllPoints(rb);
	G.Edges(rb, G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.6, 1, "BORDER");
	rb.text = G.Text(rb, 10, "CENTER");
	rb.text:SetPoint("CENTER", rb, "CENTER", 0, 0);
	rb.text:SetText("Reset");
	rb.text:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	rb:SetScript("OnClick", function()
		G.ResetMeter();
	end);
	G.Tooltip(rb, function(tt)
		tt:AddLine("Reset the meter", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		tt:AddLine("All four tabs count from zero again. The game's own meter keeps its numbers.", 0.8, 0.8, 0.8, 1);
	end, "ANCHOR_TOP");
	f.resetBtn = rb;

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
	lines, total = Rebase(mode, lines, G.Num(total));
	f.iconAcc = ( f.iconAcc or 99 ) + dt;
	if ( f.iconAcc >= 1 or f.iconMode ~= mode ) then
		f.iconAcc = 0;
		f.iconMode = mode;
		ReadIcons(mode, lines);
	end

	local unit = "10s DPS";                                    -- the last 10 seconds, not the whole run
	if ( mode == "healing" ) then
		unit = "10s HPS";
	end
	-- the rate of the last 10 seconds, from the totals noted here (the tabs that are not shown get a note once a second)
	local now = GetTime();
	Note(mode, now, total);
	f.noteAcc = ( f.noteAcc or 0 ) + dt;
	if ( f.noteAcc >= 1 ) then
		f.noteAcc = 0;
		for i = 1, table.getn(TABS) do
			local m = TABS[i].key;
			if ( m ~= mode ) then
				local l, t = GetData(m);
				local _, tt = Rebase(m, l or {}, G.Num(t));
				Note(m, now, tt);
			end
		end
	end
	rate = ApiRateOf(mode, now) or RateOf(mode, now);
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
			r.name:SetText(G.Esc(tostring(d.name or "?")));
			-- the icon: the spell (the Party tab: the player's best spell) left of the name
			r.iconBack:Show();
			r.icon:Show();
			local ic = IconFor(SpellOf(mode, d));
			if ( r.curIcon ~= ic ) then
				r.curIcon = ic;
				r.icon:SetTexture(ic);
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
