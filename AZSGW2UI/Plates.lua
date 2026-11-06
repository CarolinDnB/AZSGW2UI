-- AZS GW2 UI: Plates.lua
-- Nameplates in the look of this UI (1.8.1): a thin red bar with the health number in it, the name under it,
-- a crown for elites and a white outline on your target, like Guild Wars 2. Own art.
--
-- The game keeps doing the work: it decides which enemies and friends get a plate, where it stands and how
-- full its health is. Its plates are frames under WorldFrame; this file recognises them, makes their own drawing
-- invisible (alpha 0, so the game's own Show / Hide still tells us what the unit is) and hangs its own bar and name
-- on them. The same plate that was a red bar with a border is now this one, at the same place. If the game's plates
-- are not what this file expects, nothing is hidden and the game's own plates stay as they were.
--
-- Options: Enable Nameplates (enemies), Only Elites and Guardians, Enable Friendly Nameplates.

local G = AZSGW2;

local PLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border";   -- the first drawing of every nameplate of the game
local BARW = 104;
local BARH = 11;
local BUDGET = 30;          -- plates looked at per tick (every 0.1 s): with hundreds around, the rest follow on the next ticks
local IDENTIFY = 12;        -- a plate is read for name, kind and colour again every this many looks

local COLOR_ENEMY = { 0.80, 0.14, 0.12 };
local COLOR_NEUTRAL = { 0.86, 0.74, 0.18 };
local COLOR_ELITE = { 0.88, 0.56, 0.10 };
local COLOR_FRIEND = { 0.30, 0.72, 0.22 };

G.plates = { list = {}, seen = 0, cursor = 1, fresh = {}, active = false };
local P = G.plates;

------------------------------------------------------------------------ finding the game's plates

local function IsPlate(frame)
	if ( frame:GetName() ) then
		return false;                                   -- the game's plates have no name
	end
	local kind = frame:GetObjectType();
	if ( kind ~= "Frame" and kind ~= "Button" ) then
		return false;
	end
	local region = frame:GetRegions();
	if ( not region or not region.GetObjectType or region:GetObjectType() ~= "Texture" ) then
		return false;
	end
	return region:GetTexture() == PLATE_BORDER;
end

-- the regions of a plate, in the order of the game: border, glow, name, level, level icon (elite / boss), raid icon;
-- its first child is the health bar, the second the cast bar
local function Adopt(frame)
	local border, glow, name, level, icon, raid = frame:GetRegions();
	local hb, cast = frame:GetChildren();
	if ( not hb or not hb.GetValue or not name or not name.GetText or not icon or not icon.IsShown ) then
		return nil;
	end
	local p = { frame = frame, border = border, glow = glow, name = name, level = level, icon = icon, raid = raid, hb = hb, cast = cast };
	table.insert(P.list, p);
	frame.azsPlate = p;
	return p;
end

-- new plates are found by their number: WorldFrame's children only ever grow
local function Scan()
	local n = WorldFrame:GetNumChildren();
	if ( n == P.seen ) then
		return;
	end
	local kids = { WorldFrame:GetChildren() };
	for i = P.seen + 1, n do
		local f = kids[i];
		if ( f and f.azsPlate == nil ) then
			local ok, plate = pcall(IsPlate, f);
			if ( ok and plate ) then
				local adopted = Adopt(f);
				if ( adopted ) then
					G.PlateBuild(adopted);
					adopted.queued = true;
					table.insert(P.fresh, adopted);
				else
					f.azsPlate = false;
				end
			else
				f.azsPlate = false;
			end
		end
	end
	P.seen = n;
end

------------------------------------------------------------------------ our drawing on a plate

function G.PlateBuild(p)
	local plate = p.frame;
	local v = CreateFrame("Frame", nil, plate);
	v:SetWidth(BARW);
	v:SetHeight(BARH + 16);
	v:SetPoint("TOP", plate, "TOP", 0, 0);
	v:Hide();
	p.v = v;

	p.bar = G.NewGwBar(v, BARW, BARH);
	p.bar:SetPoint("TOP", v, "TOP", 0, 0);

	local tf = CreateFrame("Frame", nil, v);
	tf:SetAllPoints(v);
	tf:SetFrameLevel(p.bar:GetFrameLevel() + 3);
	p.text = G.Text(tf, 8, "CENTER");
	p.text:SetPoint("CENTER", p.bar, "CENTER", 0, 0);
	p.nameText = G.Text(tf, 10, "CENTER");
	p.nameText:SetPoint("TOP", p.bar, "BOTTOM", 0, -2);

	local hl = CreateFrame("Frame", nil, v);
	hl:SetPoint("TOPLEFT", p.bar, "TOPLEFT", -2, 2);
	hl:SetPoint("BOTTOMRIGHT", p.bar, "BOTTOMRIGHT", 2, -2);
	hl:SetFrameLevel(p.bar:GetFrameLevel() + 2);
	G.Edges(hl, 1, 1, 1, 0.9, 1, "OVERLAY");
	hl:Hide();
	p.hl = hl;

	p.mark = tf:CreateTexture(nil, "ARTWORK");
	p.mark:SetWidth(14);
	p.mark:SetHeight(14);
	p.mark:SetPoint("RIGHT", p.bar, "LEFT", -2, 0);
	p.mark:Hide();

	-- the game's own drawing becomes invisible, once: the plates keep their regions for good
	p.border:SetAlpha(0);
	p.glow:SetAlpha(0);
	p.name:SetAlpha(0);
	if ( p.level ) then
		p.level:SetAlpha(0);
	end
	p.icon:SetAlpha(0);
	p.hb:SetAlpha(0);
	if ( p.cast ) then
		p.cast:SetAlpha(0);
	end
	p.quiet = true;

	-- a plate is given to another unit by showing it again: start from nothing until it has been looked at
	local old = plate:GetScript("OnShow");
	plate:SetScript("OnShow", function()
		if ( old ) then
			old();
		end
		local q = this.azsPlate;
		if ( q and q.v ) then
			q.v:Hide();
			if ( not q.queued ) then
				q.queued = true;
				table.insert(P.fresh, q);
			end
		end
	end);
end

-- give the game's drawing back (the plates option went off, /gw2 off)
local function Release(p)
	if ( not p.quiet ) then
		return;
	end
	p.quiet = false;
	p.border:SetAlpha(1);
	p.glow:SetAlpha(1);
	p.name:SetAlpha(1);
	if ( p.level ) then
		p.level:SetAlpha(1);
	end
	p.icon:SetAlpha(1);
	p.hb:SetAlpha(1);
	if ( p.cast ) then
		p.cast:SetAlpha(1);
	end
	p.v:Hide();
end

local function Requiet(p)
	if ( p.quiet ) then
		return;
	end
	p.quiet = true;
	p.border:SetAlpha(0);
	p.glow:SetAlpha(0);
	p.name:SetAlpha(0);
	if ( p.level ) then
		p.level:SetAlpha(0);
	end
	p.icon:SetAlpha(0);
	p.hb:SetAlpha(0);
	if ( p.cast ) then
		p.cast:SetAlpha(0);
	end
end

------------------------------------------------------------------------ what a plate shows

-- the colour of the game's bar says what the unit is: red / yellow are enemies, everything else (green, blue, class
-- colours) is a friend
local function IsEnemyColor(r, g, b)
	if ( r > 0.85 and g < 0.3 ) then
		return true, false;
	end
	if ( r > 0.85 and g > 0.8 and b < 0.3 ) then
		return true, true;
	end
	return false, false;
end

local function SpecialHealth(name)
	local found, count = nil, 0;
	local list = AZS_UNITS;
	if ( list ) then
		for i = 1, table.getn(list) do
			if ( list[i].name == name ) then
				found = list[i];
				count = count + 1;
			end
		end
	end
	if ( count == 1 and found and G.Num(found.hpm) > 0 ) then
		return G.Num(found.hp), G.Num(found.hpm);
	end
	return nil;
end

local function PlateText(name, frac, v, hi, isTarget, elite)
	if ( not isTarget and not elite ) then
		return "";
	end
	if ( isTarget and AZS_TARGET and AZS_TARGET.name == name and G.Num(AZS_TARGET.hpm) > 0 ) then
		return G.Short(G.Num(AZS_TARGET.hp));
	end
	if ( elite and not isTarget ) then
		local hp = SpecialHealth(name);
		if ( hp ) then
			return G.Short(hp);
		end
	end
	if ( hi > 100 ) then
		return G.Short(v);                                -- the game knows the real numbers (a friend)
	end
	return string.format("%d%%", math.floor(frac * 100 + 0.5));
end

-- who is on the plate: name, kind and colours. Read when the plate is given to a unit and now and then after that
-- (a neutral creature turns hostile, a bar changes colour), not every look.
local function Identify(p)
	p.age = 0;
	local hb = p.hb;
	local r, g, b = hb:GetStatusBarColor();
	local enemy, neutral = IsEnemyColor(r or 0, g or 0, b or 0);
	local name = p.name:GetText() or "";
	local tex = p.icon:IsShown() and p.icon:GetTexture() or nil;
	local elite, boss = false, false;
	if ( type(tex) == "string" ) then
		if ( string.find(tex, "Skull") ) then
			boss = true;
			elite = true;
		elseif ( string.find(tex, "Elite") ) then
			elite = true;
		end
	end
	if ( p.forceBoss ) then
		boss = true;                                          -- the target's kind is known exactly (see Refresh)
		elite = true;
	elseif ( p.forceElite ) then
		elite = true;
	end
	p.enemy = enemy;
	p.rawName = name;
	p.elite, p.boss, p.neutral = elite, boss, neutral;
	local kind = "friend";
	if ( enemy ) then
		kind = elite and "elite" or ( neutral and "neutral" or "enemy" );
	end
	if ( p.cName ~= name or p.cKind ~= kind or p.cBoss ~= boss ) then
		p.cName, p.cKind, p.cBoss = name, kind, boss;
		p.nameText:SetText(G.Esc(name));
		if ( kind == "elite" ) then
			p.nameText:SetTextColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3]);
			p.bar:SetColor(COLOR_ELITE[1], COLOR_ELITE[2], COLOR_ELITE[3]);
		elseif ( kind == "friend" ) then
			local nr, ng, nb = p.name:GetTextColor();
			p.nameText:SetTextColor(nr or 0.7, ng or 1, nb or 0.7);
			p.bar:SetColor(COLOR_FRIEND[1], COLOR_FRIEND[2], COLOR_FRIEND[3]);
		elseif ( kind == "neutral" ) then
			p.nameText:SetTextColor(1, 0.92, 0.5);
			p.bar:SetColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3]);
		else
			p.nameText:SetTextColor(0.95, 0.95, 0.95);
			p.bar:SetColor(COLOR_ENEMY[1], COLOR_ENEMY[2], COLOR_ENEMY[3]);
		end
		-- the mark left of the bar: a skull for a boss, a crown for an elite
		if ( boss ) then
			G.SetSkull(p.mark, "tiny");
			p.mark:SetVertexColor(0.92, 0.85, 0.80, 1);
			p.mark:Show();
		elseif ( elite and G.SetCrown(p.mark) ) then
			p.mark:SetVertexColor(G.GOLDLIGHT[1], G.GOLDLIGHT[2], G.GOLDLIGHT[3], 1);
			p.mark:Show();
		else
			p.mark:Hide();
		end
	end
end

-- what the plate shows now: its health, whether it is your target, whether it is shown at all.
-- tname / tkind: your target's name and kind, read once per look
local function Refresh(p, tname, tkind)
	local f = p.frame;
	local hb = p.hb;
	local lo, hi = hb:GetMinMaxValues();
	local v = hb:GetValue();
	if ( not lo or not hi or not v ) then
		return;
	end
	local frac = 0;
	if ( hi > lo ) then
		frac = G.Clamp(( v - lo ) / ( hi - lo ), 0, 1);
	end
	local isTarget = ( tname ~= nil and p.rawName == tname and f:GetAlpha() >= 0.99 );
	-- only your target is known exactly (a guardian is the same creature as an ordinary elite of its type, so on the
	-- other plates it reads as an elite): the game's kind of the target settles it
	if ( isTarget and p.enemy and tkind and not p.elite ) then
		if ( tkind == "guardian" or tkind == "elite" ) then
			p.forceElite = true;
			Identify(p);
		elseif ( tkind == "boss" or tkind == "final" ) then
			p.forceBoss = true;
			Identify(p);
		end
	end
	local elite = p.elite;

	local show;
	if ( frac <= 0.002 ) then
		show = false;                                        -- a dead unit
	elseif ( p.enemy ) then
		show = G.Opt("nameplates") and ( elite or not G.Opt("platesElite") );
	else
		show = G.Opt("platesFriend");
	end
	if ( not show ) then
		if ( p.shownV ) then
			p.shownV = false;
			p.v:Hide();
		end
		return;
	end
	if ( p.cFrac ~= frac ) then
		p.cFrac = frac;
		p.bar:SetFrac(frac);
	end
	local text = PlateText(p.rawName, frac, v, hi, isTarget, elite);
	if ( p.cText ~= text ) then
		p.cText = text;
		p.text:SetText(text);
	end
	if ( p.cTarget ~= isTarget ) then
		p.cTarget = isTarget;
		if ( isTarget ) then
			p.hl:Show();
		else
			p.hl:Hide();
		end
	end
	if ( not p.shownV ) then
		p.shownV = true;
		p.v:Show();
	end
end

local function Look(p, tname, tkind)
	if ( not p.quiet ) then
		Requiet(p);
	end
	p.age = ( p.age or 0 ) + 1;
	if ( p.age >= IDENTIFY or not p.rawName ) then
		Identify(p);
	end
	Refresh(p, tname, tkind);
end

------------------------------------------------------------------------ the updater

function G.PlatesWanted()
	return AZSGW2DB and AZSGW2DB.enabled and ( G.Opt("nameplates") or G.Opt("platesFriend") );
end

local function ReleaseAll()
	for i = 1, table.getn(P.list) do
		local p = P.list[i];
		Release(p);
		p.shownV = false;
		p.cName = nil;
		p.cKind = nil;
		p.rawName = nil;
		p.queued = false;
	end
	P.fresh = {};
end

function G.UpdatePlates(dt)
	local want = G.PlatesWanted();
	if ( not want ) then
		if ( P.active ) then
			P.active = false;
			ReleaseAll();
		end
		return;
	end
	P.active = true;
	Scan();
	local list = P.list;
	local n = table.getn(list);
	if ( n == 0 ) then
		return;
	end
	local tname, tkind = nil, nil;
	if ( UnitExists and UnitExists("target") ) then
		tname = UnitName("target");
		if ( AZS_UnitKind ) then
			tkind = AZS_UnitKind("target");
		end
	end
	-- plates that were just given to a unit come first, all of them
	local fresh = P.fresh;
	local nf = table.getn(fresh);
	for i = 1, nf do
		local p = fresh[i];
		p.queued = false;
		p.shownV = false;
		p.cName = nil;
		p.rawName = nil;
		p.forceElite, p.forceBoss = nil, nil;
		if ( p.frame:IsShown() ) then
			Look(p, tname, tkind);
		end
	end
	if ( nf > 0 ) then
		P.fresh = {};
	end
	local count = 0;
	local i = P.cursor;
	for step = 1, n do
		if ( i > n ) then
			i = 1;
		end
		local p = list[i];
		i = i + 1;
		if ( p.frame:IsShown() ) then
			Look(p, tname, tkind);
			count = count + 1;
			if ( count >= BUDGET ) then
				break;
			end
		end
	end
	P.cursor = i;
end

-- what the plates see, for a report from the game: /gw2 plates debug
function G.PlatesReport()
	G.Print("nameplates: " .. ( G.Opt("nameplates") and "on" or "off" ) .. ", only elites and guardians: "
		.. ( G.Opt("platesElite") and "on" or "off" ) .. ", friendly: " .. ( G.Opt("platesFriend") and "on" or "off" ));
	G.Print("game: NAMEPLATES_ON " .. tostring(NAMEPLATES_ON) .. ", FRIENDNAMEPLATES_ON " .. tostring(FRIENDNAMEPLATES_ON)
		.. ", ShowNameplates " .. tostring(ShowNameplates ~= nil) .. ", ShowFriendNameplates " .. tostring(ShowFriendNameplates ~= nil));
	local shown = 0;
	for i = 1, table.getn(P.list) do
		if ( P.list[i].frame:IsShown() ) then
			shown = shown + 1;
		end
	end
	G.Print("plates found: " .. table.getn(P.list) .. " (" .. shown .. " up), WorldFrame children: " .. WorldFrame:GetNumChildren());
	if ( table.getn(P.list) == 0 ) then
		-- the plates were not recognised: say what the first few unnamed frames under WorldFrame look like
		local kids = { WorldFrame:GetChildren() };
		local said = 0;
		for i = 1, table.getn(kids) do
			local f = kids[i];
			if ( said < 4 and not f:GetName() ) then
				said = said + 1;
				local region = f:GetRegions();
				local rtype, rtex = "none", "";
				if ( region and region.GetObjectType ) then
					rtype = region:GetObjectType();
					if ( rtype == "Texture" ) then
						rtex = tostring(region:GetTexture());
					end
				end
				local child = f:GetChildren();
				G.Print("  frame " .. i .. ": " .. tostring(f:GetObjectType()) .. ", first region " .. rtype .. " " .. G.Plain(rtex)
					.. ", first child " .. ( child and tostring(child:GetObjectType()) or "none" ));
			end
		end
	end
end
