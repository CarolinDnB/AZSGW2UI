-- AZS GW2 UI: Orb.lua
-- The health orb (AZS_RUN.hp / hpm / sh), the two experience bars on top of it, the level badge
-- between them and the class resource bar under it.

local G = AZSGW2;

local S = 112;           -- orb diameter
local RIMSCALE = 1.30;   -- rim texture size relative to the orb
local XPW = 44;          -- width of each experience bar
local XPH = 9;

-- The orb is updated every frame so its bars glide, but most frames nothing visible changes: the fill is
-- only redrawn when it moved by about a pixel (the smoothing settles within a second), and text only when
-- the string differs. Redrawing identical values costs the game layout work for nothing.
local lastCrop = {};
local function SetCrop(tex, frac)
	if ( frac > 1 ) then
		frac = 1;
	end
	local was = lastCrop[tex];
	if ( was and math.abs(was - frac) < 0.0005 ) then
		return;
	end
	lastCrop[tex] = frac;
	if ( frac < 0.004 ) then
		tex:Hide();
		return;
	end
	tex:Show();
	tex:SetHeight(S * frac);
	tex:SetTexCoord(0, 1, 1 - frac, 1);
end

local SetTextOnce = G.SetText;

-- The two experience bars are curved arcs that follow the top of the orb, like the endurance bars in
-- GW2. The arc is a 64 x 64 texture (made by make_textures.py: same radii and angles); each arc's fill is
-- the same texture cropped from its starting end, so it grows along the curve.
local ARC_RIN, ARC_ROUT, ARC_A0, ARC_A1 = 64, 72, 15, 58;
local ARC_U0 = 72 - ARC_ROUT * math.sin(ARC_A1 * math.pi / 180);   -- where the arc starts / ends on the canvas
local ARC_U1 = 72 - ARC_RIN * math.sin(ARC_A0 * math.pi / 180);
local ARC_N = 64;

local function ArcSetFrac(self, p)
	if ( p > 1 ) then
		p = 1;
	end
	if ( self.lastP and math.abs(self.lastP - p) < 0.0005 ) then
		return;
	end
	self.lastP = p;
	if ( p < 0.004 ) then
		self.fill:Hide();
		return;
	end
	local d0, d1 = ARC_U0, ARC_U1;
	if ( self.mirrored ) then
		d0, d1 = ARC_N - ARC_U1, ARC_N - ARC_U0;      -- the right arc is the left one flipped
	end
	local d = d0 + ( d1 - d0 ) * p;
	self.fill:Show();
	self.fill:SetWidth(d);
	if ( self.mirrored ) then
		self.fill:SetTexCoord(1, 1 - d / ARC_N, 0, 1);
	else
		self.fill:SetTexCoord(0, d / ARC_N, 0, 1);
	end
end

local function NewArc(orb, mirrored)
	local a = CreateFrame("Frame", nil, orb);
	a:SetWidth(ARC_N);
	a:SetHeight(ARC_N);
	a:SetFrameLevel(orb:GetFrameLevel() + 2);
	if ( mirrored ) then
		a:SetPoint("TOPLEFT", orb, "CENTER", 8, 96);
	else
		a:SetPoint("TOPLEFT", orb, "CENTER", -72, 96);
	end
	local track = a:CreateTexture(nil, "BACKGROUND");
	track:SetTexture(G.TEXPATH .. "xp_track.tga");
	track:SetAllPoints(a);
	local fill = a:CreateTexture(nil, "ARTWORK");
	fill:SetTexture(G.TEXPATH .. "xp_fill.tga");
	fill:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0);
	fill:SetHeight(ARC_N);
	fill:SetWidth(1);
	fill:Hide();
	if ( mirrored ) then
		track:SetTexCoord(1, 0, 0, 1);
	end
	a.fill = fill;
	a.mirrored = mirrored;
	a.SetFrac = ArcSetFrac;
	return a;
end

-- Experience: two bars, filled in turn, left first and then right (clockwise over the top).
-- p is 0..1 for the whole level.
function G.SetXP(f, p)
	f.xpL:SetFrac(G.Clamp(p * 2, 0, 1));
	f.xpR:SetFrac(G.Clamp(p * 2 - 1, 0, 1));
end

------------------------------------------------------------------------ orb

function G.BuildOrb()
	local custom = G.art.custom;
	local f = CreateFrame("Frame", "AZSGW2Orb", UIParent);
	f:SetWidth(S);
	f:SetHeight(S);
	f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 34);
	f:SetFrameStrata("MEDIUM");
	G.Register(f);
	G.orb = f;
	f.hpDisp = 0;
	f.shDisp = 0;

	local fillPath = G.MASK;
	if ( custom ) then
		fillPath = G.TEXPATH .. "orb_fill.tga";
	else
		local disc = f:CreateTexture(nil, "BACKGROUND");
		disc:SetTexture(G.MASK);
		disc:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3], 1);
		disc:SetWidth(S * 1.14);
		disc:SetHeight(S * 1.14);
		disc:SetPoint("CENTER", f, "CENTER", 0, 0);
	end

	local back = f:CreateTexture(nil, "BORDER");
	back:SetTexture(fillPath);
	back:SetVertexColor(0.10, 0.02, 0.02, 1);
	back:SetAllPoints(f);

	local shield = f:CreateTexture(nil, "ARTWORK");
	shield:SetTexture(fillPath);
	shield:SetVertexColor(0.98, 0.86, 0.45, 1);
	shield:SetWidth(S);
	shield:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
	f.shield = shield;

	local fill = f:CreateTexture(nil, "OVERLAY");
	fill:SetTexture(fillPath);
	fill:SetVertexColor(0.88, 0.10, 0.08, 1);
	fill:SetWidth(S);
	fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
	f.fill = fill;

	f.xpDisp = 0;
	local RS = S * RIMSCALE;
	if ( custom ) then
		local gloss = f:CreateTexture(nil, "OVERLAY");
		gloss:SetTexture(G.TEXPATH .. "orb_gloss.tga");
		gloss:SetAllPoints(f);
		local rim = f:CreateTexture(nil, "OVERLAY");
		rim:SetTexture(G.TEXPATH .. "orb_rim.tga");
		rim:SetWidth(RS);
		rim:SetHeight(RS);
		rim:SetPoint("CENTER", f, "CENTER", 0, 0);
	end

	-- the two experience bars on top of the orb with the level badge between them
	local badgeY = 9.5;           -- badge centre above the orb's top edge
	local xl, xr;
	if ( custom ) then
		xl = NewArc(f, false);
		xr = NewArc(f, true);
		badgeY = 12;
	else
		xl = G.NewBar(f, XPW, XPH, 1.0, 0.82, 0.20);
		xl:SetPoint("BOTTOMRIGHT", f, "TOP", -14, 5);
		xl:SetFrameLevel(f:GetFrameLevel() + 2);
		xr = G.NewBar(f, XPW, XPH, 1.0, 0.82, 0.20);
		xr:SetPoint("BOTTOMLEFT", f, "TOP", 14, 5);
		xr:SetFrameLevel(f:GetFrameLevel() + 2);
	end
	f.xpL, f.xpR = xl, xr;
	local function xpTip(tt)
		local run = AZS_RUN or {};
		local xp, xpn = G.Num(run.xp), G.Num(run.xpn);
		tt:AddLine("Level " .. math.floor(G.Num(run.lvl)), 1, 0.82, 0.2);
		if ( xpn > 0 ) then
			tt:AddLine(G.Comma(xp) .. " / " .. G.Comma(xpn) .. string.format("  (%.1f%%)", 100 * xp / xpn), 0.9, 0.9, 0.9);
		end
	end
	if ( custom ) then
		-- small hover areas on the arcs (the arc frames themselves cover part of the orb)
		for side = -1, 1, 2 do
			local hit = CreateFrame("Frame", nil, f);
			hit:SetWidth(34);
			hit:SetHeight(22);
			hit:SetPoint("CENTER", f, "CENTER", side * 41, 57);
			hit:SetFrameLevel(f:GetFrameLevel() + 3);
			G.Tooltip(hit, xpTip, "ANCHOR_TOP");
		end
	else
		G.Tooltip(xl, xpTip, "ANCHOR_TOP");
		G.Tooltip(xr, xpTip, "ANCHOR_TOP");
	end

	local tf = CreateFrame("Frame", nil, f);
	tf:SetAllPoints(f);
	tf:SetFrameLevel(f:GetFrameLevel() + 4);
	f.hpText = G.Text(tf, 20, "CENTER");
	f.hpText:SetPoint("CENTER", f, "CENTER", 0, 0);

	G.Tooltip(f, function(tt)
		local run = AZS_RUN or {};
		local hp, hpm, sh = G.Num(run.hp), G.Num(run.hpm), G.Num(run.sh);
		tt:AddLine("Health", G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
		tt:AddLine(G.Comma(hp) .. " / " .. G.Comma(hpm), 1, 1, 1);
		if ( sh > 0 ) then
			tt:AddLine("Shield: " .. G.Comma(sh), 0.98, 0.86, 0.45);
		end
		local lives = G.Num(run.lives);
		if ( lives > 0 ) then
			tt:AddLine("Extra lives: " .. lives, 0.6, 1, 0.6);
		end
		local st = AZS_STATS;
		if ( st and G.Num(st.reg) > 0 ) then
			tt:AddLine(string.format("Regeneration: %.1f / sec", G.Num(st.reg)), 0.8, 0.8, 0.8);
		end
		local xp, xpn = G.Num(run.xp), G.Num(run.xpn);
		tt:AddLine("Level " .. math.floor(G.Num(run.lvl)), 1, 0.82, 0.2);
		if ( xpn > 0 ) then
			tt:AddLine(G.Comma(xp) .. " / " .. G.Comma(xpn) .. string.format("  (%.1f%%)", 100 * xp / xpn), 0.9, 0.9, 0.9);
		end
	end, "ANCHOR_TOP");

	-- level badge
	local badge = CreateFrame("Frame", nil, f);
	badge:SetWidth(26);
	badge:SetHeight(26);
	badge:SetPoint("CENTER", f, "TOP", 0, badgeY);
	badge:SetFrameLevel(f:GetFrameLevel() + 6);
	local bd1 = badge:CreateTexture(nil, "BACKGROUND");
	bd1:SetTexture(G.MASK);
	bd1:SetVertexColor(G.GOLD[1], G.GOLD[2], G.GOLD[3], 1);
	bd1:SetAllPoints(badge);
	local bd2 = badge:CreateTexture(nil, "BORDER");
	bd2:SetTexture(G.MASK);
	bd2:SetVertexColor(0.06, 0.05, 0.05, 1);
	bd2:SetPoint("TOPLEFT", badge, "TOPLEFT", 2, -2);
	bd2:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -2, 2);
	badge.text = G.Text(badge, 11, "CENTER");
	badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0);
	badge.text:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
	f.badge = badge;
end

function G.UpdateOrb(dt)
	local f = G.orb;
	if ( not f ) then
		return;
	end
	local run = AZS_RUN or {};
	local hp, hpm, sh = G.Num(run.hp), G.Num(run.hpm), G.Num(run.sh);
	local den = math.max(hpm, hp + sh);
	local hpT, shT = 0, 0;
	if ( den > 0 ) then
		hpT = hp / den;
		shT = (hp + sh) / den;
	end
	local k = math.min(1, dt * 12);
	f.hpDisp = f.hpDisp + (hpT - f.hpDisp) * k;
	f.shDisp = f.shDisp + (shT - f.shDisp) * k;
	if ( hpT == 0 and f.hpDisp < 0.004 ) then
		f.hpDisp = 0;                              -- settle at empty, so the sliver goes away
	end

	SetCrop(f.fill, f.hpDisp);
	if ( sh > 0 ) then
		SetCrop(f.shield, f.shDisp);
	else
		if ( lastCrop[f.shield] ~= -1 ) then
			f.shield:Hide();
			lastCrop[f.shield] = -1;           -- hidden; the next shield draws again
		end
	end

	local phase = G.Phase();
	if ( phase == "dead" ) then
		if ( f.fillTint ~= "dead" ) then
			f.fillTint = "dead";
			f.fill:SetVertexColor(0.35, 0.35, 0.38, 1);
		end
		SetTextOnce(f.hpText, "0");
	else
		local frac = 1;
		if ( hpm > 0 ) then
			frac = hp / hpm;
		end
		if ( frac < 0.25 ) then
			-- low health: pulse towards a brighter red
			local p = 0.5 + 0.5 * math.sin(GetTime() * 7);
			f.fill:SetVertexColor(0.88 + 0.12 * p, 0.10 + 0.10 * p, 0.08, 1);
			f.fillTint = "pulse";
		elseif ( f.fillTint ~= "red" ) then
			f.fillTint = "red";
			f.fill:SetVertexColor(0.88, 0.10, 0.08, 1);
		end
		SetTextOnce(f.hpText, G.Comma(hp));
	end

	-- experience gauge
	local xp, xpn = G.Num(run.xp), G.Num(run.xpn);
	local xpT = 0;
	if ( xpn > 0 ) then
		xpT = G.Clamp(xp / xpn, 0, 1);
	end
	if ( xpT < f.xpDisp - 0.5 ) then
		f.xpDisp = xpT;      -- a new level: restart the bars instead of sweeping them back
	else
		f.xpDisp = f.xpDisp + (xpT - f.xpDisp) * k;
	end
	G.SetXP(f, f.xpDisp);
	SetTextOnce(f.badge.text, tostring(math.floor(G.Num(run.lvl))));
end

------------------------------------------------------------------------ class resource bar (the "endurance" slot)

local PROC = {
	bloodrage = { name = "Rage", color = { 0.86, 0.18, 0.12 }, seg = 0 },
	seal_fate = { name = "Combo Points", color = { 1.0, 0.82, 0.18 }, seg = 5 },
	soul_fire = { name = "Soul Shards", color = { 0.66, 0.32, 0.95 }, seg = 5 },
	lightwell = { name = "Lightwell", color = { 0.96, 0.95, 0.72 }, seg = 0 },
};

function G.BuildResource()
	local f = CreateFrame("Frame", "AZSGW2Resource", UIParent);
	f:SetWidth(176);
	f:SetHeight(11);
	f:SetPoint("TOP", G.orb, "BOTTOM", 0, -15);
	f:SetFrameStrata("MEDIUM");
	f:SetFrameLevel(8);
	G.Register(f, true);
	f:Hide();
	G.resource = f;

	f.bar = G.NewBar(f, 176, 11, 0.86, 0.18, 0.12);
	f.bar:SetPoint("CENTER", f, "CENTER", 0, 0);

	f.seps = {};
	for i = 1, 4 do
		local s = G.Solid(f.bar, "OVERLAY", 0, 0, 0, 0.85);
		s:SetWidth(1);
		s:SetPoint("TOP", f.bar, "TOPLEFT", 0, -1);
		s:SetPoint("BOTTOM", f.bar, "BOTTOMLEFT", 0, 1);
		s:Hide();
		f.seps[i] = s;
	end
	f.curProc = "";

	f.text = G.Text(f, 9, "CENTER");
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0);

	G.Tooltip(f, function(tt)
		local run = AZS_RUN or {};
		local info = PROC[run.proc or ""];
		if ( info ) then
			tt:AddLine(info.name, info.color[1], info.color[2], info.color[3]);
			tt:AddLine(string.format("%s / %s", tostring(G.Num(run.pv)), tostring(G.Num(run.pm))), 1, 1, 1);
		end
	end, "ANCHOR_TOP");
end

function G.UpdateResource(dt)
	local f = G.resource;
	if ( not f ) then
		return;
	end
	local run = AZS_RUN or {};
	local info = nil;
	if ( run.proc and run.proc ~= "" ) then
		info = PROC[run.proc];
	end
	if ( not info or not G.shown ) then
		f:Hide();
		return;
	end
	f:Show();
	if ( f.curProc ~= run.proc ) then
		f.curProc = run.proc;
		f.bar:SetColor(info.color[1], info.color[2], info.color[3]);
		local w = (f.bar:GetWidth() or 176) - 2;
		for i = 1, 4 do
			if ( info.seg > 0 ) then
				f.seps[i]:ClearAllPoints();
				f.seps[i]:SetPoint("TOP", f.bar, "TOPLEFT", 1 + w * i / info.seg, -1);
				f.seps[i]:SetPoint("BOTTOM", f.bar, "BOTTOMLEFT", 1 + w * i / info.seg, 1);
				f.seps[i]:Show();
			else
				f.seps[i]:Hide();
			end
		end
	end
	local pv, pm = G.Num(run.pv), G.Num(run.pm);
	local frac = 0;
	if ( pm > 0 ) then
		frac = G.Clamp(pv / pm, 0, 1);
	end
	f.bar:SetFrac(frac);
	if ( frac >= 0.999 ) then
		local p = 0.65 + 0.35 * math.sin(GetTime() * 8);
		f.bar:SetAlpha(p);
	else
		f.bar:SetAlpha(1);
	end
	if ( info.seg > 0 ) then
		f.text:SetText(string.format("%d", math.floor(pv + 0.5)));
	else
		f.text:SetText("");
	end
end
