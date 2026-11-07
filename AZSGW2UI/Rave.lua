-- AZS GW2 UI: Rave.lua
-- A small surprise for parties. Nothing is built, nothing runs and nothing costs a thing until it is asked for.
-- The lights are textures on one full-screen frame behind the interface; the interface itself bounces on the beat.

local G = AZSGW2;

local SOUNDS = "Interface\\AddOns\\AZSGW2UI\\Sounds\\";
local BEAMTEX = G.TEXPATH .. "rave_beam.tga";      -- 64 cells (8 x 8) of one light beam, turned a little more in each cell
local SONG = { file = "party", len = 24 };         -- the song that comes with the addon: 16 bars of 160 BPM
local BPS = 160 / 60;                              -- beats per second of that song
local TWOPI = 6.2831853;
local EQ = 48;                                     -- equalizer bars along the bottom
local CONFETTI = 40;
local RINGA, RINGB = 16, 10;                       -- lights that circle around the orb
local STEP = 1 / 30;
local IDLE = 0.5;                                  -- how often the updater looks while the party is off

G.rave = { on = false, built = false, t = 0, n = 0 };

-- hue 0..1, saturation, value -> r, g, b
local function Hue(h, s, v)
	h = h - math.floor(h);
	local i = math.floor(h * 6);
	local f = h * 6 - i;
	local p, q, t = v * ( 1 - s ), v * ( 1 - f * s ), v * ( 1 - ( 1 - f ) * s );
	i = math.mod(i, 6);
	if ( i == 0 ) then
		return v, t, p;
	elseif ( i == 1 ) then
		return q, v, p;
	elseif ( i == 2 ) then
		return p, v, t;
	elseif ( i == 3 ) then
		return p, q, v;
	elseif ( i == 4 ) then
		return t, p, v;
	end
	return v, p, q;
end

-- the song to play: the one that comes with the addon, or a file the player put into the Sounds folder
-- (/gw2 party song <file name without .mp3> <length in seconds>). Anything odd falls back to the built-in one.
local function Song()
	local s = AZSGW2DB and AZSGW2DB.partySong;
	if ( type(s) == "table" and type(s.file) == "string" and type(s.len) == "number" and s.len == s.len
		and string.len(s.file) > 0 and string.len(s.file) <= 40 and not string.find(s.file, "[^%w_%-]")
		and ( s.len == 0 or ( s.len >= 3 and s.len <= 1800 ) ) ) then
		return s.file, s.len, true;                       -- a length of 0: the song is played once and not repeated
	end
	return SONG.file, SONG.len, false;
end

------------------------------------------------------------------------ build (once, the first time)

local function Tex(f, layer, path, add)
	local t = f:CreateTexture(nil, layer);
	t:SetTexture(path or G.WHITE);
	if ( add ) then
		t:SetBlendMode("ADD");
	end
	return t;
end

local function Build()
	local R = G.rave;
	local W, H = UIParent:GetWidth(), UIParent:GetHeight();
	if ( type(W) ~= "number" or type(H) ~= "number" or W < 200 or H < 200 ) then
		W, H = 1024, 768;
	end
	local f = CreateFrame("Frame", "AZSGW2Rave", UIParent);
	f:SetAllPoints(UIParent);
	f:SetFrameStrata("BACKGROUND");                   -- behind the interface, above the world
	f:EnableMouse(false);                             -- never in the way of a click
	f.azs = true;
	f:Hide();
	R.frame, R.W, R.H = f, W, H;

	-- a colour that washes over the whole screen and breathes with the kick
	R.wash = Tex(f, "BACKGROUND", G.WHITE, true);
	R.wash:SetAllPoints(f);
	R.wash:SetVertexColor(1, 0.2, 0.8, 0);

	-- light beams: four that sweep from the corners, one that fans from the bottom, four that spin in the middle
	local size = math.min(4000, math.max(W, H) * 2.6);
	local defs = {
		{ x = 0, y = 0, base = 0.62, amp = 0.65, speed = 0.9, ph = 0, hue = 0.00, a = 0.34 },
		{ x = W, y = 0, base = -0.62, amp = 0.65, speed = 1.1, ph = 1.7, hue = 0.25, a = 0.34 },
		{ x = 0, y = H, base = 2.36, amp = 0.65, speed = 1.0, ph = 3.1, hue = 0.50, a = 0.30 },
		{ x = W, y = H, base = 3.93, amp = 0.65, speed = 0.8, ph = 4.4, hue = 0.75, a = 0.30 },
		{ x = W / 2, y = 0, base = 0, amp = 0.95, speed = 1.3, ph = 0.5, hue = 0.12, a = 0.30 },
	};
	for k = 0, 3 do
		table.insert(defs, { x = W / 2, y = H / 2, spin = 0.9, off = k * TWOPI / 4, hue = 0.2 * k, a = 0.11 });
	end
	R.beams = {};
	for i = 1, table.getn(defs) do
		local d = defs[i];
		local t = Tex(f, "BORDER", BEAMTEX, true);
		t:SetWidth(size);
		t:SetHeight(size);
		t:SetPoint("CENTER", f, "BOTTOMLEFT", d.x, d.y);
		t:SetVertexColor(1, 1, 1, 0);
		d.tex = t;
		d.cell = -1;
		R.beams[i] = d;
	end

	-- the equalizer along the bottom edge
	R.eq = {};
	R.eqMax = H * 0.17;
	local bw = W / EQ;
	for i = 1, EQ do
		local t = Tex(f, "ARTWORK", G.WHITE, true);
		t:SetWidth(bw - 2);
		t:SetHeight(4);
		t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ( i - 1 ) * bw + 1, 0);
		t:SetVertexColor(1, 0.3, 0.8, 0.5);
		R.eq[i] = { tex = t, sp = 2.5 + math.random() * 5, ph = math.random() * TWOPI, kick = 0.3 + math.random() * 0.7, v = 0 };
	end

	-- confetti
	R.conf = {};
	for i = 1, CONFETTI do
		local sz = 5 + math.random() * 6;
		local t = Tex(f, "ARTWORK", ( math.mod(i, 2) == 0 ) and G.MASK or G.WHITE, false);
		t:SetWidth(sz);
		t:SetHeight(sz);
		local r, g, b = Hue(math.random(), 0.85, 1);
		t:SetVertexColor(r, g, b, 0.9);
		R.conf[i] = { tex = t, x = math.random() * W, y = math.random() * H, vy = 40 + math.random() * 90,
			sway = 8 + math.random() * 22, sf = 1 + math.random() * 2.5, ph = math.random() * TWOPI };
		t:SetPoint("CENTER", f, "BOTTOMLEFT", R.conf[i].x, R.conf[i].y);
	end

	-- two rings of lights that circle around the health orb in opposite directions
	R.hub = G.orb or f;
	local orbW = ( G.orb and G.orb.GetWidth and G.orb:GetWidth() ) or 120;
	if ( type(orbW) ~= "number" or orbW < 40 ) then
		orbW = 120;
	end
	R.ringA, R.ringB = orbW * 0.5 + 20, orbW * 0.5 + 38;
	R.dotsA, R.dotsB = {}, {};
	for i = 1, RINGA do
		local t = Tex(f, "ARTWORK", G.MASK, true);
		t:SetWidth(9);
		t:SetHeight(9);
		t:SetPoint("CENTER", R.hub, "CENTER", R.ringA, 0);
		R.dotsA[i] = t;
	end
	for i = 1, RINGB do
		local t = Tex(f, "ARTWORK", G.MASK, true);
		t:SetWidth(12);
		t:SetHeight(12);
		t:SetPoint("CENTER", R.hub, "CENTER", R.ringB, 0);
		R.dotsB[i] = t;
	end

	-- the title, for the first few seconds
	R.title = f:CreateFontString(nil, "OVERLAY");
	R.title:SetFont(G.FONT, 34, "OUTLINE");
	R.title:SetJustifyH("CENTER");
	R.title:SetPoint("TOP", f, "TOP", 0, -190);
	R.title:SetText("PARTY MODE!");

	R.built = true;
end

------------------------------------------------------------------------ the song

local function PlayLoop(R)
	local file, len = Song();
	local now = GetTime();
	if ( R.songEnds and now < R.songEnds ) then
		R.musicAt = R.t + ( R.songEnds - now );        -- the last round is still playing: wait for its end
		return;
	end
	if ( PlaySoundFile ) then
		local ok, _, handle = pcall(PlaySoundFile, SOUNDS .. file .. ".mp3");
		R.handle = ok and handle or nil;               -- newer clients hand back a handle that StopSound takes
	end
	if ( len > 0 ) then
		R.songEnds = now + len;
		R.musicAt = R.t + len;
	else
		R.songEnds = nil;                              -- a song of unknown length: played once
		R.musicAt = nil;
	end
end

-- PlaySoundFile has no stop. What may cut a song short, whichever of it this client has: StopSound with the handle (newer
-- clients), and a short switch of the sound effects off and on again (the sound system drops what it is playing when its
-- effects are turned off). The switch is put back about half a second later; if the game ends in between, the next start of
-- this addon puts it back (the saved variable remembers). Returns whether anything was tried.
local SFXVARS = { "Sound_EnableSFX", "MasterSoundEffects" };

local function CutSong(R)
	local tried = false;
	if ( R.handle and StopSound ) then
		pcall(StopSound, R.handle);
		tried = true;
	end
	R.handle = nil;
	if ( GetCVar and SetCVar and not R.sfx ) then
		for i = 1, table.getn(SFXVARS) do
			local name = SFXVARS[i];
			local ok, v = pcall(GetCVar, name);
			if ( ok and tostring(v) == "1" ) then
				if ( pcall(SetCVar, name, "0") ) then
					R.sfx = { name = name, at = GetTime() };
					AZSGW2DB.sfxMuted = name;
					tried = true;
					if ( G.raveUpdater ) then
						G.raveUpdater.interval = 0.1;
					end
				end
				break;
			end
		end
	end
	if ( tried ) then
		R.songEnds = nil;                                  -- it may be cut: a new start need not wait for its end
	end
	R.musicAt = nil;
	return tried;
end

-- puts the sound effects back (after the short switch, or after a game that ended in the middle of it)
local function RestoreSfx(R)
	local name = R.sfx and R.sfx.name or AZSGW2DB.sfxMuted;
	R.sfx = nil;
	AZSGW2DB.sfxMuted = nil;
	if ( type(name) == "string" and ( name == SFXVARS[1] or name == SFXVARS[2] ) and SetCVar ) then
		pcall(SetCVar, name, "1");
	end
	if ( G.raveUpdater and not R.on ) then
		G.raveUpdater.interval = IDLE;
	end
end

------------------------------------------------------------------------ the show

function G.UpdateRave(dt)
	local R = G.rave;
	if ( not R.checked ) then
		R.checked = true;
		if ( AZSGW2DB and AZSGW2DB.sfxMuted ) then
			RestoreSfx(R);                                 -- the game ended while the sound effects were switched off
		end
	end
	if ( R.sfx and GetTime() - R.sfx.at >= 0.5 ) then
		RestoreSfx(R);
	end
	if ( not R.on ) then
		return;
	end
	if ( dt > 0.25 ) then
		dt = 0.25;
	end
	R.t = R.t + dt;
	R.n = R.n + 1;
	local t, n = R.t, R.n;
	local f, W, H = R.frame, R.W, R.H;
	if ( R.musicAt and t >= R.musicAt ) then
		PlayLoop(R);
	end

	-- the beat: 1 on the kick, fading out before the next one. Everything that pulses follows it smoothly (the lights never switch
	-- off and on: no flash is brighter than a gentle swell, and none comes faster than the beat of 2.7 a second).
	local beat = t * BPS;
	local hit = math.exp(-( beat - math.floor(beat) ) * 6.5);
	R.kick = ( R.kick or 0 ) + ( hit - ( R.kick or 0 ) ) * math.min(1, dt * 22);       -- swells over two or three frames, never a jump
	local kick = R.kick;
	local hue0 = t * 0.11;

	local r, g, b = Hue(hue0, 0.9, 1);
	R.wash:SetVertexColor(r, g, b, 0.05 + 0.05 * kick);

	-- beams: the cell of the picture that points the right way
	local k0 = 0.16 * kick;
	for i = 1, table.getn(R.beams) do
		local bm = R.beams[i];
		local th;
		if ( bm.spin ) then
			th = t * bm.spin + bm.off;
		else
			th = bm.base + bm.amp * math.sin(t * bm.speed + bm.ph);
		end
		th = th - TWOPI * math.floor(th / TWOPI);
		local cell = math.floor(th / TWOPI * 64 + 0.5);
		if ( cell >= 64 ) then
			cell = 0;
		end
		if ( cell ~= bm.cell ) then
			bm.cell = cell;
			local col, row = math.mod(cell, 8), math.floor(cell / 8);
			bm.tex:SetTexCoord(col / 8, ( col + 1 ) / 8, row / 8, ( row + 1 ) / 8);
		end
		local br, bg, bb = Hue(hue0 + bm.hue, 1, 1);
		bm.tex:SetVertexColor(br, bg, bb, bm.a + ( bm.spin and 0 or k0 ));
	end

	-- the equalizer: every bar its own rhythm on top of the kick; the colours roll along the row every fourth frame
	local smooth = math.min(1, dt * 14);
	local recolor = ( math.mod(n, 4) == 0 );
	for i = 1, EQ do
		local e = R.eq[i];
		local lvl = ( 0.5 + 0.5 * math.sin(t * e.sp + e.ph) ) * 0.55 + kick * e.kick * 0.45;
		e.v = e.v + ( lvl - e.v ) * smooth;
		e.tex:SetHeight(4 + R.eqMax * e.v);
		if ( recolor ) then
			local er, eg, eb = Hue(i / EQ + hue0 * 2, 0.85, 1);
			e.tex:SetVertexColor(er, eg, eb, 0.55);
		end
	end

	-- confetti falls and sways
	for i = 1, CONFETTI do
		local c = R.conf[i];
		c.y = c.y - c.vy * dt;
		if ( c.y < -12 ) then
			c.y = H + 12;
			c.x = math.random() * W;
		end
		c.tex:SetPoint("CENTER", f, "BOTTOMLEFT", c.x + c.sway * math.sin(t * c.sf + c.ph), c.y);
	end

	-- the rings around the orb
	for i = 1, RINGA do
		local a = i * TWOPI / RINGA + t * 1.5;
		local d = R.dotsA[i];
		d:SetPoint("CENTER", R.hub, "CENTER", R.ringA * math.cos(a), R.ringA * math.sin(a));
		if ( recolor ) then
			local dr, dg, db = Hue(i / RINGA + hue0 * 3, 0.9, 1);
			d:SetVertexColor(dr, dg, db, 0.85);
		end
	end
	for i = 1, RINGB do
		local a = i * TWOPI / RINGB - t * 2.2;
		local d = R.dotsB[i];
		d:SetPoint("CENTER", R.hub, "CENTER", R.ringB * math.cos(a), R.ringB * math.sin(a));
		if ( recolor ) then
			local dr, dg, db = Hue(0.5 + i / RINGB - hue0 * 3, 0.9, 1);
			d:SetVertexColor(dr, dg, db, 0.85);
		end
	end

	-- the interface bounces on the beat, each part a little behind the one before
	if ( math.mod(n, 2) == 0 and G.shown ) then
		for i = 1, table.getn(G.all) do
			local fr = G.all[i];
			fr:SetScale(G.ScaleFor(fr) * ( 1 + 0.045 * math.abs(math.sin(beat * 3.14159265 + i * 0.45)) ));
		end
	end

	-- the title: a rainbow, a few seconds
	if ( t < 5 ) then
		local tr, tg, tb = Hue(t * 0.6, 0.8, 1);
		R.title:SetTextColor(tr, tg, tb);
		R.title:Show();
	elseif ( R.title:IsShown() ) then
		R.title:Hide();
	end
end

function G.PartyStart()
	local R = G.rave;
	if ( R.on ) then
		return;
	end
	if ( not R.built ) then
		local ok, err = pcall(Build);
		if ( not ok ) then
			G.Print("could not start: " .. tostring(err));
			return;
		end
	end
	if ( R.sfx ) then
		RestoreSfx(R);                                     -- started again within half a second of the end: sound effects back first
	end
	R.on = true;
	R.t, R.n, R.kick = 0, 0, 0;
	R.musicAt = 0;
	R.frame:Show();
	if ( G.raveUpdater ) then
		G.raveUpdater.interval = STEP;
	end
	G.Print("party mode! Loud music and moving lights. /gw2 party again stops it.");
end

function G.PartyStop(quiet)
	local R = G.rave;
	if ( not R.on ) then
		return false;
	end
	R.on = false;
	if ( R.frame ) then
		R.frame:Hide();
	end
	G.ApplyScales();                                   -- the interface stands still again, at its own size
	if ( G.raveUpdater ) then
		G.raveUpdater.interval = IDLE;
	end
	local left = R.songEnds and math.ceil(R.songEnds - GetTime()) or 0;
	local tried = CutSong(R);
	if ( not quiet ) then
		if ( left > 1 and not tried ) then
			G.Print("party's over. (This game cannot stop a song once it plays: this one ends by itself in " .. left .. " seconds.)");
		else
			G.Print("party's over.");
		end
	end
	return true;
end

-- /gw2 party [on | off | song <file> <seconds> | song default]
function G.PartyCommand(rest)
	rest = rest or "";
	local _, _, word, args = string.find(rest, "^(%S*)%s*(.-)%s*$");
	word = string.lower(word or "");
	args = args or "";
	if ( word == "song" ) then
		if ( args == "default" or args == "" ) then
			if ( args == "default" ) then
				AZSGW2DB.partySong = nil;
			end
			local file, len, custom = Song();
			G.Print("party song: " .. ( custom and ( file .. ".mp3, " .. ( len > 0 and ( len .. " seconds" ) or "played once" ) ) or "the one that comes with the addon" )
				.. ". Put your own mp3 into the AZSGW2UI/Sounds folder and use /gw2 party song <name without .mp3> [length in seconds, to repeat it].");
			return;
		end
		local _, _, name, secs = string.find(args, "^([%w_%-]+)%s*([%d%.]*)$");
		if ( secs == "" ) then
			secs = 0;                                         -- no length: the song is played once
		else
			secs = tonumber(secs);
		end
		if ( not name or string.len(name) > 40 or not secs or ( secs ~= 0 and ( secs < 3 or secs > 1800 ) ) ) then
			G.Print("usage: /gw2 party song <file name without .mp3> [length in seconds]  |  /gw2 party song default");
			return;
		end
		AZSGW2DB.partySong = { file = name, len = secs };
		G.rave.songEnds = nil;
		G.rave.musicAt = G.rave.on and G.rave.t or nil;      -- a running party plays it from the next moment
		G.Print("party song: " .. name .. ".mp3, " .. ( secs > 0 and ( secs .. " seconds." ) or "played once." ));
		return;
	end
	if ( word == "off" ) then
		G.PartyStop();
	elseif ( word == "on" ) then
		G.PartyStart();
	elseif ( G.rave.on ) then
		G.PartyStop();                                     -- plain /gw2 party switches it
	else
		G.PartyStart();
	end
end
