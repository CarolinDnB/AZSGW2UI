-- AZS GW2 UI: TopBar.lua
-- Run clock with the boss schedule, the kills / gold / cache strip, and the boss + guardian frames.

local G = AZSGW2;

local SKULLTEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons";
local BARW = 360;

------------------------------------------------------------------------ run clock

-- the run's difficulty from AZS_ZONE: `heroic` 0 = Normal, 1 to 5 = Heroic I to V; `affixes` is a comma list of
-- English keys (bolstering, sanguine, explosive)
local ROMAN = { "I", "II", "III", "IV", "V" };
local HEROIC_COL = {
	{ 1.00, 0.80, 0.32 }, { 1.00, 0.64, 0.22 }, { 1.00, 0.48, 0.16 }, { 1.00, 0.30, 0.13 }, { 0.96, 0.14, 0.20 },
};

local function AffixNames(list)
	local out = {};
	list = tostring(list or "");
	local pos = 1;
	while ( pos <= string.len(list) ) do
		local c = string.find(list, ",", pos, true);
		local piece;
		if ( c ) then
			piece = string.sub(list, pos, c - 1);
			pos = c + 1;
		else
			piece = string.sub(list, pos);
			pos = string.len(list) + 1;
		end
		piece = string.gsub(piece, "^%s+", "");
		piece = string.gsub(piece, "%s+$", "");
		if ( piece ~= "" ) then
			table.insert(out, string.upper(string.sub(piece, 1, 1)) .. string.lower(string.sub(piece, 2)));
		end
	end
	return out;
end

function G.Difficulty()
	local z = AZS_ZONE or {};
	local lv = math.floor(G.Num(z.heroic) + 0.5);
	if ( lv < 0 ) then
		lv = 0;
	elseif ( lv > 5 ) then
		lv = 5;
	end
	local d = { level = lv, affixes = AffixNames(z.affixes) };
	if ( lv == 0 ) then
		d.short, d.long = "NORMAL", "Normal";
		d.r, d.g, d.b = 0.78, 0.78, 0.82;
	else
		d.short = "HEROIC " .. ROMAN[lv];
		d.long = "Heroic " .. ROMAN[lv];
		local c = HEROIC_COL[lv];
		d.r, d.g, d.b = c[1], c[2], c[3];
	end
	return d;
end

function G.BuildTop()
	local f = CreateFrame("Frame", "AZSGW2Top", UIParent);
	f:SetWidth(BARW + 40);
	f:SetHeight(58);
	f:SetPoint("TOP", UIParent, "TOP", 0, -8);
	G.Movable(f, "top", "Run clock", nil, nil, false);
	f:SetFrameStrata("MEDIUM");
	G.Register(f);
	G.top = f;

	local bg = G.Band(f, "BACKGROUND", 0.02, 0.02, 0.03, 0.80);
	bg:SetAllPoints(f);
	local l1 = G.Band(f, "BORDER", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95);
	l1:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
	l1:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0);
	l1:SetHeight(1);
	local l2 = G.Band(f, "BORDER", G.GOLD[1], G.GOLD[2], G.GOLD[3], 0.95);
	l2:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
	l2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
	l2:SetHeight(1);

	f.title = G.Text(f, 15, "CENTER");
	f.title:SetPoint("TOP", f, "TOP", 0, -6);
	f.title:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);

	-- the difficulty (Normal, Heroic I-V) at the left of the title row; the Heroic affixes sit at the right end of the
	-- line under the bar, and the next boss moves to its left end while there are affixes (the title row is full)
	local dg = CreateFrame("Frame", nil, f);
	dg:SetWidth(112);
	dg:SetHeight(18);
	dg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -5);
	dg.text = G.Text(dg, 12, "LEFT");
	dg.text:SetPoint("LEFT", dg, "LEFT", 0, 0);
	G.Tooltip(dg, function(tt)
		local d = G.Difficulty();
		tt:AddLine(d.long, d.r, d.g, d.b);
		if ( d.level > 0 ) then
			if ( table.getn(d.affixes) > 0 ) then
				tt:AddLine("Affixes:", 0.8, 0.8, 0.8);
				for i = 1, table.getn(d.affixes) do
					tt:AddLine(d.affixes[i], 1, 1, 1);
				end
			else
				tt:AddLine("No affixes", 0.7, 0.7, 0.7);
			end
		end
	end, "ANCHOR_BOTTOM");
	f.diff = dg;
	f.affix = G.Text(f, 11, "RIGHT");
	f.affix:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -41);
	f.affix:SetTextColor(0.85, 0.85, 0.88);

	f.bar = G.NewBar(f, BARW, 10, 0.70, 0.07, 0.07);
	f.bar:SetPoint("TOP", f, "TOP", 0, -26);

	f.next = G.Text(f, 11, "CENTER");
	f.next:SetPoint("TOP", f, "TOP", 0, -41);

	f.skulls = {};
	for i = 1, 14 do
		local s = CreateFrame("Frame", nil, f);
		s:SetWidth(18);
		s:SetHeight(18);
		s:SetFrameLevel(f.bar:GetFrameLevel() + 3);
		local t = s:CreateTexture(nil, "OVERLAY");
		t:SetTexture(SKULLTEX);
		t:SetTexCoord(0.75, 1, 0.25, 0.5);
		t:SetAllPoints(s);
		s.tex = t;
		G.Tooltip(s, function(tt)
			local e = s.data;
			if ( not e ) then
				return;
			end
			tt:AddLine(e.name or "?", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			tt:AddLine("At " .. G.Clock(e.at), 0.8, 0.8, 0.8);
			if ( e.final == 1 ) then
				tt:AddLine("Final boss", 1, 0.5, 0.2);
			end
			if ( e.state == "up" ) then
				tt:AddLine("Alive", 1, 0.3, 0.3);
			elseif ( e.state == "dead" ) then
				tt:AddLine("Defeated", 0.5, 0.9, 0.5);
			end
		end, "ANCHOR_BOTTOM");
		s:Hide();
		f.skulls[i] = s;
	end
end

function G.UpdateTop(dt)
	local f = G.top;
	if ( not f ) then
		return;
	end
	local run = AZS_RUN or {};
	local t = G.RunTime();
	local len = 0;
	if ( AZS_GetRunLength ) then
		len = G.Num(AZS_GetRunLength());
	end
	local endless = ( G.Num(run.endl) == 1 );

	local title;
	if ( endless ) then
		title = "ENDLESS  " .. G.Clock(t);
	else
		title = "RUN " .. G.Clock(t) .. " / " .. G.Clock(len);
	end
	if ( f.cTitle ~= title ) then
		f.cTitle = title;
		f.title:SetText(title);
	end

	local frac = 0;
	if ( endless ) then
		frac = 1;
		f.bar:SetColor(0.45, 0.20, 0.70);
	else
		if ( len > 0 ) then
			frac = G.Clamp(t / len, 0, 1);
		end
		f.bar:SetColor(0.70, 0.07, 0.07);
	end
	f.bar:SetFrac(frac);

	local sched = AZS_SCHEDULE or {};
	local pulse = 0.6 + 0.4 * math.sin(GetTime() * 6);
	for i = 1, 14 do
		local s = f.skulls[i];
		local e = sched[i];
		if ( e and not endless and len > 0 ) then
			s.data = e;
			local x = G.Clamp(G.Num(e.at) / len, 0, 1) * BARW;
			if ( s.cX ~= x ) then
				s.cX = x;
				s:ClearAllPoints();
				s:SetPoint("CENTER", f.bar, "LEFT", x, 0);
			end
			-- the colour is only sent when it changes; a boss that is up pulses, so its colour is sent every time
			local state = e.state == "up" and "up" or ( e.state == "dead" and "dead" or ( e.final == 1 and "final" or "norm" ) );
			if ( state == "up" ) then
				s.tex:SetVertexColor(1, 0.25, 0.2, pulse);
				s.cState = nil;
			elseif ( s.cState ~= state ) then
				s.cState = state;
				if ( state == "dead" ) then
					s.tex:SetVertexColor(0.35, 0.35, 0.38, 0.8);
				elseif ( state == "final" ) then
					s.tex:SetVertexColor(1, 0.85, 0.4, 1);
				else
					s.tex:SetVertexColor(1, 1, 1, 1);
				end
			end
			G.Vis(s, true);
		else
			s.data = nil;
			G.Vis(s, false);
		end
	end

	-- difficulty tag and affixes (worked out again only when the two values it comes from are other ones)
	local zone = AZS_ZONE or {};
	local d = f.cDiff;
	if ( not d or f.cHeroic ~= zone.heroic or f.cAffixes ~= zone.affixes ) then
		d = G.Difficulty();
		f.cDiff, f.cHeroic, f.cAffixes = d, zone.heroic, zone.affixes;
	end
	local key = d.short .. "|" .. table.concat(d.affixes, ",");
	if ( f.diffKey ~= key ) then
		f.diffKey = key;
		f.diff.text:SetText(d.short);
		f.diff.text:SetTextColor(d.r, d.g, d.b);
		if ( table.getn(d.affixes) > 0 ) then
			f.affix:SetText(table.concat(d.affixes, " - "));
		else
			f.affix:SetText("");
		end
		f.affixLen = table.getn(d.affixes);
		f.next:ClearAllPoints();
		if ( f.affixLen > 0 ) then
			f.next:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -41);
			f.next:SetJustifyH("LEFT");
		else
			f.next:SetPoint("TOP", f, "TOP", 0, -41);
			f.next:SetJustifyH("CENTER");
		end
	end

	-- the line under the bar
	local line = "";
	local r, g, b = 0.85, 0.85, 0.85;
	if ( endless ) then
		local nb = G.Num(run.nb);
		if ( nb >= 0 ) then
			line = "Next boss in " .. G.Clock(nb);
		end
	elseif ( AZS_GetUpcomingBosses ) then
		local up = AZS_GetUpcomingBosses();
		local nx = up and up[1];
		if ( nx ) then
			line = tostring(nx.name or "?") .. " in " .. G.Clock(G.Num(nx.left));
			if ( nx.final ) then
				r, g, b = 1, 0.55, 0.25;
			end
		end
	end
	if ( f.cLine ~= line ) then
		f.cLine = line;
		f.next:SetText(line);
		f.cFit = nil;
	end
	if ( f.cR ~= r or f.cG ~= g or f.cB ~= b ) then
		f.cR, f.cG, f.cB = r, g, b;
		f.next:SetTextColor(r, g, b);
	end
	-- the affixes only show when both texts fit on the line (the difficulty tooltip lists them anyway)
	if ( ( f.affixLen or 0 ) > 0 ) then
		if ( f.cFit == nil or f.cFitKey ~= key ) then
			f.cFitKey = key;
			local room = f:GetWidth() - 20 - 8;
			f.cFit = ( f.next:GetStringWidth() + f.affix:GetStringWidth() <= room );
			if ( f.cFit ) then
				f.affix:Show();
			else
				f.affix:Hide();
			end
		end
	end
end

------------------------------------------------------------------------ tally (kills / gold / cache price)

function G.BuildTally()
	local f = CreateFrame("Frame", "AZSGW2Tally", UIParent);
	f:SetWidth(308);
	f:SetHeight(20);
	f:SetPoint("TOP", UIParent, "TOP", 0, -70);
	G.Movable(f, "tally", "Kills / gold", nil, nil, false);
	f:SetFrameStrata("MEDIUM");
	G.Register(f);
	G.tally = f;
	f.samples = {};

	local bg = G.Band(f, "BACKGROUND", 0.02, 0.02, 0.03, 0.70);
	bg:SetAllPoints(f);

	local defs = {
		{ key = "kills", icon = "Interface\\Icons\\INV_Sword_04", x = -96, w = 116, tip = "Enemies slain" },
		{ key = "gold", icon = "Interface\\Icons\\INV_Misc_Coin_01", x = 8, w = 84, tip = "Gold" },
		{ key = "chest", icon = "Interface\\Icons\\INV_Box_01", x = 96, w = 84, tip = "Price of the next cache" },
	};
	f.items = {};
	for i = 1, 3 do
		local d = defs[i];
		local h = CreateFrame("Frame", nil, f);
		h:SetWidth(d.w);
		h:SetHeight(18);
		h:SetPoint("CENTER", f, "CENTER", d.x, 0);
		local ic = h:CreateTexture(nil, "ARTWORK");
		ic:SetTexture(d.icon);
		ic:SetWidth(14);
		ic:SetHeight(14);
		ic:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		ic:SetPoint("LEFT", h, "LEFT", 4, 0);
		h.text = G.Text(h, 12, "LEFT");
		h.text:SetPoint("LEFT", ic, "RIGHT", 4, 0);
		if ( d.key == "kills" ) then
			-- kills per minute, [18/m], to the right of the total
			h.rate = G.Text(h, 10, "LEFT");
			h.rate:SetPoint("LEFT", h.text, "RIGHT", 5, -1);
			h.rate:SetTextColor(0.78, 0.72, 0.52);
		end
		local key = d.key;
		G.Tooltip(h, function(tt)
			tt:AddLine(d.tip, G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			if ( key == "kills" ) then
				local avg, recent = G.KillRate();
				tt:AddLine(string.format("Run average: %s kills per minute", G.RateText(avg)), 1, 1, 1);
				tt:AddLine(string.format("Last minute: %s kills per minute", G.RateText(recent)), 0.8, 0.8, 0.8);
			end
		end, "ANCHOR_BOTTOM");
		f.items[d.key] = h;
	end
end

function G.RateText(v)
	v = G.Num(v);
	if ( v >= 10 ) then
		return string.format("%d", math.floor(v + 0.5));
	end
	return string.format("%.1f", v);
end

-- kills per minute: the whole run, and the last 60 seconds (needs a few seconds of run to mean anything)
function G.KillRate()
	local f = G.tally;
	local run = AZS_RUN or {};
	local kills = G.Num(run.kills);
	local t = G.RunTime();
	local avg = 0;
	if ( t >= 10 ) then
		avg = kills * 60 / t;
	end
	local recent = avg;
	if ( f and f.samples and table.getn(f.samples) > 0 ) then
		local first = f.samples[1];
		local span = t - first.t;
		if ( span >= 10 ) then
			recent = math.max(0, kills - first.k) * 60 / span;
		end
	end
	return avg, recent;
end

function G.UpdateTally(dt)
	local f = G.tally;
	if ( not f ) then
		return;
	end
	local run = AZS_RUN or {};
	local kills = G.Num(run.kills);
	local t = G.RunTime();
	-- one sample a second for the last minute; a new run (kills or the clock going back) starts over
	local s = f.samples;
	local last = s[table.getn(s)];
	if ( last and ( kills < last.k or t < last.t ) ) then
		f.samples = {};
		s = f.samples;
		last = nil;
	end
	if ( not last or t - last.t >= 1 ) then
		table.insert(s, { t = t, k = kills });
	end
	while ( table.getn(s) > 1 and t - s[2].t >= 60 ) do
		table.remove(s, 1);       -- keep the newest sample that is still 60 s or older as the start
	end
	f.items.kills.text:SetText(G.Comma(run.kills));
	local avg = G.KillRate();
	f.items.kills.rate:SetText("[" .. G.RateText(avg) .. "/m]");
	f.items.gold.text:SetText(G.Comma(run.gold));
	f.items.chest.text:SetText(G.Comma(run.chest));
end

------------------------------------------------------------------------ boss and guardian frames

local ROWS = 6;
local DEBUFFS = 8;
local BARW = 308;
local BARH = 16;
local LEFTW = 30;        -- room left of the bars for the red skull
local HEADH = 24;        -- the title line (only when more than one enemy is listed)
local NOHEAD = 2;        -- one enemy: its own row says everything, there is no title above it
local ROWH = 45;          -- one row: the name line and the health bar (the effect timer bar is gone)
local ROWMAX = ROWH + 17;  -- room kept per row in the container

-- the skull and the crown come from bar_icons.tga (own drawing, drawn at twice the size they are shown
-- at: "big" 32 px, "small" 24 px, "tiny" 16 px skulls and a 16 px crown); stock art falls back to the
-- game's own skull
local SKULLS = {
	big = { 0, 0.5, 0, 0.5 },
	small = { 0.5, 0.875, 0, 0.375 },
	tiny = { 0.5, 0.75, 0.5, 0.75 },
};

local function SetSkull(tex, size)
	if ( G.art.custom ) then
		local c = SKULLS[size or "small"];
		tex:SetTexture(G.TEXPATH .. "bar_icons.tga");
		tex:SetTexCoord(c[1], c[2], c[3], c[4]);
	else
		tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull");
		tex:SetTexCoord(0, 1, 0, 1);
	end
end

local function SetCrown(tex)
	if ( G.art.custom ) then
		tex:SetTexture(G.TEXPATH .. "bar_icons.tga");
		tex:SetTexCoord(0, 0.25, 0.5, 0.75);
		return true;
	end
	tex:Hide();
	return false;
end

G.SetSkull = SetSkull;
G.SetCrown = SetCrown;

-- a flat dark bar with a thin border; gold = the mottled timer texture (cropped to the fraction)
local function NewFlatBar(parent, w, h, gold)
	local f = CreateFrame("Frame", nil, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	local back = G.Solid(f, "BACKGROUND", 0.08, 0.06, 0.09, 0.92);
	back:SetAllPoints(f);
	local fill;
	if ( gold and G.art.custom ) then
		fill = f:CreateTexture(nil, "BORDER");
		fill:SetTexture(G.TEXPATH .. "bar_gold.tga");
		fill:SetVertexColor(1, 1, 1, 1);
	elseif ( gold ) then
		fill = G.Solid(f, "BORDER", 0.95, 0.62, 0.12, 1);
	else
		fill = G.Solid(f, "BORDER", 0.78, 0.11, 0.08, 1);
	end
	fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
	fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1);
	fill:SetWidth(1);
	fill:Hide();
	f.fill = fill;
	f.gold = gold and G.art.custom;
	if ( G.art.custom ) then
		local gl = f:CreateTexture(nil, "ARTWORK");
		gl:SetTexture(G.TEXPATH .. "bar_gloss.tga");
		gl:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
		gl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1);
	end
	G.Edges(f, 0.02, 0.01, 0.03, 1, 1, "ARTWORK");
	f.SetFrac = function(self, frac)
		frac = G.Clamp(tonumber(frac) or 0, 0, 1);
		local width = (self:GetWidth() or 0) - 2;
		if ( frac <= 0.002 or width <= 0 ) then
			self.fill:Hide();
			return;
		end
		self.fill:SetWidth(width * frac);
		if ( self.gold ) then
			self.fill:SetTexCoord(0, frac, 0, 1);
		end
		self.fill:Show();
	end;
	f.SetColor = function(self, cr, cg, cb)
		if ( not self.gold ) then
			self.fill:SetVertexColor(cr, cg, cb, 1);
		end
	end;
	return f;
end

function G.BuildBosses()
	local c = CreateFrame("Frame", "AZSGW2Bosses", UIParent);
	c:SetWidth(LEFTW + BARW + 4);
	c:SetHeight(HEADH + ROWMAX * 3);
	c:SetPoint("TOP", UIParent, "TOP", 0, -98);
	c:SetFrameStrata("MEDIUM");
	G.Register(c);
	G.bossFrame = c;
	G.Movable(c, "bosses", "Boss bars", nil, nil, false);

	-- a faint dark panel behind the rows; the red skulls stand to the left of it
	c.panel = G.Solid(c, "BACKGROUND", 0.03, 0.02, 0.05, 0.45);
	c.panel:SetPoint("TOPLEFT", c, "TOPLEFT", LEFTW - 3, -(HEADH - 2));
	c.panel:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -(HEADH - 2));
	c.panel:SetHeight(10);
	c.panel:Hide();

	-- title line over the rows: only text and a thin line (each row has its own skull and crown, so the
	-- title does not repeat them); it shows when more than one enemy is listed
	c.headText = G.TextS(c, 14, "LEFT");
	c.headText:SetPoint("TOPLEFT", c, "TOPLEFT", LEFTW + 4, -3);
	c.headText:SetTextColor(0.95, 0.12, 0.10);
	c.headLine = G.Band(c, "ARTWORK", 0.78, 0.11, 0.08, 0.75);
	c.headLine:SetPoint("TOPLEFT", c, "TOPLEFT", LEFTW, -(HEADH - 4));
	c.headLine:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -(HEADH - 4));
	c.headLine:SetHeight(1);
	c.headLine:Hide();

	c.rows = {};
	for i = 1, ROWS do
		local row = CreateFrame("Frame", nil, c);
		row:SetWidth(BARW);
		row:SetHeight(ROWMAX - 6);
		row:SetPoint("TOPLEFT", c, "TOPLEFT", LEFTW, -(HEADH + (i - 1) * ROWMAX));

		row.skull = row:CreateTexture(nil, "ARTWORK");
		SetSkull(row.skull, "small");
		row.skull:SetVertexColor(0.92, 0.14, 0.11, 1);
		row.skull:SetWidth(24);
		row.skull:SetHeight(24);
		row.skull:SetPoint("TOPLEFT", row, "TOPLEFT", -LEFTW, -14);

		row.crown = row:CreateTexture(nil, "ARTWORK");
		local crowned = SetCrown(row.crown);
		row.crown:SetWidth(16);
		row.crown:SetHeight(16);
		row.crown:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3);
		row.name = G.TextS(row, 14, "LEFT");
		if ( crowned ) then
			row.name:SetPoint("LEFT", row.crown, "RIGHT", 5, 0);
		else
			row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3);
		end
		row.name:SetWidth(BARW - 30);
		row.name:SetHeight(16);

		row.bar = NewFlatBar(row, BARW, BARH);
		row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -22);
		row.pct = G.TextS(row.bar, 12, "CENTER");
		row.pct:SetPoint("CENTER", row.bar, "CENTER", 0, 0);
		G.Tooltip(row.bar, function(tt)
			local e = row.entry;
			if ( e ) then
				tt:AddLine(tostring(e.name or "?"), G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
				tt:AddLine(G.Comma(e.hp) .. " / " .. G.Comma(e.hpm), 1, 1, 1);
			end
		end, "ANCHOR_BOTTOM");

		-- debuffs: small framed icons at the top right, newest nearest the edge
		row.debuffs = {};
		for j = 1, DEBUFFS do
			local d = CreateFrame("Frame", nil, row);
			d:SetWidth(20);
			d:SetHeight(20);
			d:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(j - 1) * 22, 1);
			local t = d:CreateTexture(nil, "BACKGROUND");
			t:SetAllPoints(d);
			t:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			d.icon = t;
			d.edges = G.Edges(d, 0.28, 0.38, 0.78, 1, 1, "ARTWORK");
			d.stack = G.TextS(d, 10, "RIGHT");
			d.stack:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 2, -1);
			G.Tooltip(d, function(tt)
				local x = d.data;
				if ( x ) then
					tt:AddLine(x.name or "?", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
					if ( x.dispelType ) then
						tt:AddLine(x.dispelType, 0.6, 0.8, 1);
					end
					if ( x.remaining and not x.permanent ) then
						tt:AddLine(G.Rem(x.remaining), 0.85, 0.85, 0.85);
					end
				end
			end, "ANCHOR_BOTTOM");
			d:Hide();
			row.debuffs[j] = d;
		end
		row:Hide();
		c.rows[i] = row;
	end
end

local DISPELCOL = {
	Magic = { 0.25, 0.60, 1.0 }, Curse = { 0.65, 0.10, 1.0 },
	Disease = { 0.65, 0.45, 0.10 }, Poison = { 0.10, 0.65, 0.15 },
};

-- fills one row; returns how tall it is
-- Called a few times a second for every row, so every widget is only touched when what it shows has changed.
local function FillRow(row, e)
	if ( row.on ~= true ) then
		row.on = true;
		row:Show();
	end
	row.entry = e;
	local kind, enraged, name = e.kind, e.enraged and true or false, e.name;
	if ( row.cKind ~= kind or row.cEnr ~= enraged or row.cName ~= name ) then
		row.cKind, row.cEnr, row.cName = kind, enraged, name;
		local nameText = tostring(name or "?");
		local r, g, b = 0.78, 0.11, 0.08;
		local nr, ng, nb = 1, 1, 1;
		row.crown:SetVertexColor(1, 1, 1, 1);
		if ( kind == "final" ) then
			r, g, b = 0.90, 0.07, 0.05;
			nr, ng, nb = G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3];
			row.crown:SetVertexColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
		end
		if ( enraged ) then
			r, g, b = 0.95, 0.42, 0.05;
			nameText = nameText .. "  (Enraged)";
			nr, ng, nb = 1, 0.62, 0.30;
		end
		row.name:SetText(nameText);
		row.name:SetTextColor(nr, ng, nb);
		row.bar:SetColor(r, g, b);
	end
	local hpm = G.Num(e.hpm);
	local frac = 0;
	if ( hpm > 0 ) then
		frac = G.Clamp(G.Num(e.hp) / hpm, 0, 1);
	end
	row.bar:SetFrac(frac);
	local pct = math.floor(frac * 100 + 0.5);
	if ( row.cPct ~= pct ) then
		row.cPct = pct;
		row.pct:SetText(pct .. "%");
	end

	local deb = e.debuffs or {};
	local shownDeb = 0;
	for j = 1, DEBUFFS do
		local d = row.debuffs[j];
		local x = deb[j];
		if ( x ) then
			d.data = x;
			local icon, dispel, stacks = x.icon or G.QUESTION, x.dispelType or "", G.Num(x.stacks);
			if ( d.cIcon ~= icon ) then
				d.cIcon = icon;
				d.icon:SetTexture(icon);
				d.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
			end
			if ( d.cDispel ~= dispel ) then
				d.cDispel = dispel;
				local c = DISPELCOL[dispel] or { 0.28, 0.38, 0.78 };
				d.edges.top:SetVertexColor(c[1], c[2], c[3], 1);
				d.edges.bottom:SetVertexColor(c[1], c[2], c[3], 1);
				d.edges.left:SetVertexColor(c[1], c[2], c[3], 1);
				d.edges.right:SetVertexColor(c[1], c[2], c[3], 1);
			end
			if ( stacks > 1 ) then
				stacks = math.floor(stacks);
			else
				stacks = 0;
			end
			if ( d.cStacks ~= stacks ) then
				d.cStacks = stacks;
				d.stack:SetText(stacks > 0 and tostring(stacks) or "");
			end
			if ( d.on ~= true ) then
				d.on = true;
				d:Show();
			end
			shownDeb = shownDeb + 1;
		else
			d.data = nil;
			if ( d.on ~= false ) then
				d.on = false;
				d:Hide();
			end
		end
	end

	-- the name stops before the debuff icons
	local nameW = BARW - 30 - 22 * shownDeb;
	if ( row.nameW ~= nameW ) then
		row.nameW = nameW;
		row.name:SetWidth(nameW);
	end

	return ROWH;
end

function G.UpdateBosses(dt)
	local c = G.bossFrame;
	if ( not c ) then
		return;
	end
	local list = {};
	local stale = G.UnitsStale();            -- the lists of the run before are not shown (the game keeps them until new ones come)
	if ( AZS_GetBosses and not stale ) then
		local bosses = AZS_GetBosses() or {};
		for i = 1, table.getn(bosses) do
			local b = bosses[i];
			if ( table.getn(list) < 4 ) then
				local kind = "boss";
				if ( b.final ) then
					kind = "final";
				end
				table.insert(list, { kind = kind, name = b.name, hp = b.hp, hpm = b.hpm,
					enraged = b.enraged, debuffs = b.debuffs });
			end
		end
	end
	local bossCount = table.getn(list);
	if ( AZS_GetGuardians and not stale ) then
		local guards = AZS_GetGuardians() or {};
		for i = 1, table.getn(guards) do
			local g = guards[i];
			if ( g.awake and table.getn(list) < ROWS ) then
				table.insert(list, { kind = "guardian", name = g.name, hp = g.hp, hpm = g.hpm, debuffs = g.debuffs });
			end
		end
	end
	local count = table.getn(list);
	if ( count > ROWS ) then
		count = ROWS;
	end
	local headH = NOHEAD;
	if ( count >= 2 ) then
		headH = HEADH;
	end
	local y = headH;
	local shown = 0;
	for i = 1, ROWS do
		local row = c.rows[i];
		if ( list[i] and G.shown ) then
			local h = FillRow(row, list[i]);
			if ( row.curY ~= y ) then
				row.curY = y;
				row:ClearAllPoints();
				row:SetPoint("TOPLEFT", c, "TOPLEFT", LEFTW, -y);
			end
			y = y + h;
			shown = shown + 1;
		else
			if ( row.on ~= false ) then
				row.on = false;
				row:Hide();
			end
			row.entry = nil;
		end
	end
	if ( shown > 0 ) then
		if ( c.panelTop ~= headH ) then
			c.panelTop = headH;
			c.panel:ClearAllPoints();
			c.panel:SetPoint("TOPLEFT", c, "TOPLEFT", LEFTW - 3, -(headH - 2));
			c.panel:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -(headH - 2));
		end
		if ( headH == HEADH ) then
			if ( bossCount == shown ) then
				c.headText:SetText("Bosses");
			elseif ( bossCount == 0 ) then
				c.headText:SetText("Guardians");
			else
				c.headText:SetText("Bosses & Guardians");
			end
			c.headText:Show();
			c.headLine:Show();
		else
			c.headText:Hide();
			c.headLine:Hide();
		end
		c.panel:SetHeight(math.max(10, y - headH + 2));
		c.panel:Show();
	else
		c.headText:Hide();
		c.headLine:Hide();
		c.panel:Hide();
	end
end

------------------------------------------------------------------------ target bar (normal and elite enemies)

-- A wide, flat bar in the style of Guild Wars 2: the name on the left inside the bar, the health and the percent on
-- the right, a round badge on the right end (a skull for an enemy, a crown for an elite, none for a friend). Red for
-- enemies, gold for elites, green for friends. Bosses and guardians have their own bars above.
local TARGETW = 320;
local TARGETH = 22;

function G.BuildTarget()
	local f = CreateFrame("Frame", "AZSGW2Target", UIParent);
	f:SetWidth(TARGETW);
	f:SetHeight(TARGETH);
	f:SetPoint("TOP", UIParent, "TOP", 0, -96);
	G.Movable(f, "target", "Target bar", nil, nil, false);
	f:SetFrameStrata("MEDIUM");
	G.Register(f, true);
	f:Hide();
	G.target = f;
	f.bar = G.NewGwBar(f, TARGETW, TARGETH);
	f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
	f.bar:SetColor(0.80, 0.14, 0.12);

	local tf = CreateFrame("Frame", nil, f);
	tf:SetAllPoints(f);
	tf:SetFrameLevel(f.bar:GetFrameLevel() + 4);
	f.name = G.Text(tf, 11, "LEFT");
	f.name:SetPoint("LEFT", f, "LEFT", 10, 0);
	f.name:SetWidth(TARGETW - 130);
	f.name:SetHeight(14);
	f.hpText = G.Text(tf, 11, "RIGHT");
	f.hpText:SetPoint("RIGHT", f, "RIGHT", -20, 0);

	local badge = CreateFrame("Frame", nil, tf);
	badge:SetWidth(28);
	badge:SetHeight(28);
	badge:SetPoint("CENTER", f, "RIGHT", 0, 0);
	badge:SetFrameLevel(tf:GetFrameLevel() + 2);
	local ring = badge:CreateTexture(nil, "BACKGROUND");
	ring:SetTexture(G.MASK);
	ring:SetVertexColor(0.66, 0.66, 0.70, 1);
	ring:SetAllPoints(badge);
	local disc = badge:CreateTexture(nil, "BORDER");
	disc:SetTexture(G.MASK);
	disc:SetVertexColor(0.04, 0.04, 0.05, 1);
	disc:SetPoint("TOPLEFT", badge, "TOPLEFT", 2, -2);
	disc:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -2, 2);
	local icon = badge:CreateTexture(nil, "ARTWORK");
	icon:SetWidth(18);
	icon:SetHeight(18);
	icon:SetPoint("CENTER", badge, "CENTER", 0, 0);
	badge:Hide();
	f.badge = badge;
	f.badgeIcon = icon;
end

local function SetBadge(f, kind)
	if ( f.badgeKind == kind ) then
		return;
	end
	f.badgeKind = kind;
	local icon = f.badgeIcon;
	if ( kind == "friend" ) then
		f.badge:Hide();
		return;
	end
	icon:Show();
	if ( kind == "elite" ) then
		if ( not G.SetCrown(icon) ) then
			G.SetSkull(icon, "tiny");
			icon:Show();
		end
		icon:SetVertexColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
	else
		G.SetSkull(icon, "tiny");
		icon:SetVertexColor(0.86, 0.80, 0.78, 1);
	end
	f.badge:Show();
end

-- the boss rows move down while the target bar is up
function G.PlaceBosses(withTarget)
	local c = G.bossFrame;
	if ( not c or c.withTarget == withTarget ) then
		return;
	end
	c.withTarget = withTarget;
	if ( G.HasPos("bosses") ) then
		return;   -- the player put the boss bars somewhere: leave them
	end
	c:ClearAllPoints();
	if ( withTarget ) then
		c:SetPoint("TOP", UIParent, "TOP", 0, -126);
	else
		c:SetPoint("TOP", UIParent, "TOP", 0, -98);
	end
end

-- The AZS target table (AZS_TARGET) comes from the server and trails a click by up to a second, so
-- the bar starts from the client's own target the moment it changes (name, enemy or not, health
-- percent) and swaps to AZS' exact numbers as soon as they name the same enemy.
local function SpecialByName(name)
	local found, count = nil, 0;
	local list = AZS_UNITS;
	if ( list and not G.UnitsStale() ) then
		for i = 1, table.getn(list) do
			if ( list[i].name == name ) then
				found = list[i];
				count = count + 1;
			end
		end
	end
	return found, count;
end

-- a friendly target (a hero, yourself, a friendly creature): the same bar, green. The client knows a friend's health;
-- for a creature it may only know a percentage (the maximum then reads 100).
local function FriendInfo(name)
	local hp, hpm = G.Num(UnitHealth and UnitHealth("target")), G.Num(UnitHealthMax and UnitHealthMax("target"));
	if ( UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") ) then
		return "friend", name, 0, math.max(hpm, 0), 0;
	end
	if ( hpm <= 0 ) then
		return "friend", name, 0, 0, 1;
	end
	if ( hpm == 100 ) then
		return "friend", name, 0, 0, hp / 100;
	end
	return "friend", name, hp, hpm, hp / hpm;
end

-- what the bar should show right now: nil (hide) or kind, name, hp, hpm, percent
function G.TargetInfo()
	if ( UnitExists and not UnitExists("target") ) then
		return nil;
	end
	local name = UnitName and UnitName("target");
	local t = AZS_TARGET;
	local fresh = ( t and name and t.name == name );
	if ( fresh ) then
		if ( t.kind == "player" or t.kind == "other" ) then
			return FriendInfo(name);
		end
		if ( ( t.kind == "normal" or t.kind == "elite" ) and G.Num(t.hpm) > 0 ) then
			return t.kind, t.name, G.Num(t.hp), G.Num(t.hpm), G.Num(t.hp) / G.Num(t.hpm);
		end
		return nil;
	end
	-- AZS has not caught up yet: use what the client knows
	if ( not name ) then
		return nil;
	end
	if ( UnitCanAttack and not UnitCanAttack("player", "target") ) then
		return FriendInfo(name);
	end
	if ( UnitIsDead and UnitIsDead("target") ) then
		return nil;
	end
	local special, count = SpecialByName(name);
	if ( special and ( special.kind == "boss" or special.kind == "final" or special.kind == "guardian" ) ) then
		return nil;   -- bosses and guardians have their own bars
	end
	if ( special and count == 1 and G.Num(special.hpm) > 0 ) then
		return "elite", name, G.Num(special.hp), G.Num(special.hpm), G.Num(special.hp) / G.Num(special.hpm);
	end
	local kind = "normal";
	local class = UnitClassification and UnitClassification("target");
	if ( class == "worldboss" ) then
		return nil;
	elseif ( class == "elite" or class == "rareelite" or class == "rare" ) then
		kind = "elite";
	end
	local hp, hpm = G.Num(UnitHealth and UnitHealth("target")), G.Num(UnitHealthMax and UnitHealthMax("target"));
	if ( hpm <= 0 ) then
		return kind, name, 0, 0, 1;
	end
	if ( hpm == 100 ) then
		-- the client only knows a percentage of an enemy's health
		return kind, name, 0, 0, hp / 100;
	end
	return kind, name, hp, hpm, hp / hpm;
end

function G.UpdateTarget(dt)
	local f = G.target;
	if ( not f ) then
		return;
	end
	local kind, name, hp, hpm, frac = nil, nil, 0, 0, 0;
	if ( G.shown and G.Opt("target") ) then
		kind, name, hp, hpm, frac = G.TargetInfo();
	end
	if ( not kind ) then
		f:Hide();
		G.PlaceBosses(false);
		return;
	end
	f:Show();
	G.PlaceBosses(true);
	name = G.Esc(name);
	if ( f.shownName ~= name or f.shownKind ~= kind ) then
		f.shownName, f.shownKind = name, kind;
		f.name:SetText(name);
		SetBadge(f, kind);
		if ( kind == "elite" ) then
			f.name:SetTextColor(1, 0.95, 0.78);              -- cream: gold would vanish on the gold bar
			f.bar:SetColor(G.COLOR_ELITE[1], G.COLOR_ELITE[2], G.COLOR_ELITE[3]);
		elseif ( kind == "friend" ) then
			-- a friend: the same bar in green, the name in the class colour (a hero) or soft green (a creature)
			local token = nil;
			if ( UnitClass and UnitIsPlayer and UnitIsPlayer("target") ) then
				local _, tk = UnitClass("target");
				token = tk and string.lower(tk) or nil;
			end
			if ( token ) then
				f.name:SetTextColor(G.ClassColor(token));
			else
				f.name:SetTextColor(0.70, 1, 0.70);
			end
			f.bar:SetColor(0.30, 0.72, 0.22);
		else
			f.name:SetTextColor(1, 1, 1);
			f.bar:SetColor(0.80, 0.14, 0.12);
		end
	end
	frac = G.Clamp(frac, 0, 1);
	local text;
	if ( kind == "friend" and frac <= 0 and UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") ) then
		text = "Downed";
	else
		local pct = string.format("%d%%", math.floor(frac * 100 + 0.5));
		if ( hpm > 0 ) then
			text = G.Short(hp) .. "  " .. pct;
		else
			text = pct;
		end
	end
	if ( f.shownFrac ~= frac ) then
		f.shownFrac = frac;
		f.bar:SetFrac(frac);
	end
	if ( f.shownText ~= text ) then
		f.shownText = text;
		f.hpText:SetText(text);
	end
end
