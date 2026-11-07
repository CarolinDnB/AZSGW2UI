-- AZS GW2 UI: Plates.lua
-- Nameplates in the look of this UI (1.9.0): a thin red bar with the health number in it, orange for elites and
-- guardians, a crown for elites and a white outline on your target, like Guild Wars 2. Own art.
--
-- The game keeps doing the work: it decides which enemies and friends get a plate, where it stands and how
-- full its health is. Its plates are frames under WorldFrame; this file recognises them, makes their own drawing
-- invisible (alpha 0, so the game's own Show / Hide still tells us what the unit is) and hangs its own bar on them. The same plate that was a red bar with a border is now this one, at the same place. If the game's plates
-- are not what this file expects, nothing is hidden and the game's own plates stay as they were.
--
-- The game may give a plate's drawing back at any time (it reuses a plate for the next enemy), so the plate is looked at
-- again: if the game made anything visible again, it is made invisible again.
--
-- Options: Enable Nameplates (enemies), Only Elites and Guardians, Enable Friendly Nameplates (heroes only, no pets, summons
-- or totems). The plates show a bar and no name: the name is for the target bar.

local G = AZSGW2;

local PLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border";   -- the first drawing of every nameplate of the game
local BARW = 104;
local BARH = 11;
local BUDGET = 30;          -- plates looked at per tick (every 0.1 s): with hundreds around, the rest follow on the next ticks
local IDENTIFY = 12;        -- a plate is read for name, kind and colour again every this many looks

local COLOR_ENEMY = { 0.80, 0.14, 0.12 };
local COLOR_NEUTRAL = { 0.86, 0.74, 0.18 };
local COLOR_ELITE = G.COLOR_ELITE;                  -- orange: elites and guardians stand out among the red
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
	local p = { frame = frame, border = border, glow = glow, name = name, level = level, icon = icon, raid = raid, hb = hb, cast = cast,
		regs = { frame:GetRegions() } };
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

-- every part of the game's plate (all its regions and all its frames but ours) gets this alpha
local function NativeAlpha(p, a)
	local regs = p.regs;
	for i = 1, table.getn(regs) do
		local r = regs[i];
		if ( r == p.raid and not p.raidOurs ) then
			r:SetAlpha(1);                                  -- we cannot draw the icon ourselves: the game's own stays
		else
			r:SetAlpha(a);
		end
	end
	local kids = { p.frame:GetChildren() };
	for i = 1, table.getn(kids) do
		if ( kids[i] ~= p.v ) then
			kids[i]:SetAlpha(a);
		end
	end
	p.nkids = p.frame:GetNumChildren();
end

local function Quiet(p)
	NativeAlpha(p, 0);
	p.quiet = true;
end

function G.PlateBuild(p)
	local plate = p.frame;
	local v = CreateFrame("Frame", nil, plate);
	v:SetWidth(BARW);
	v:SetHeight(BARH);
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

	-- the raid icon (the game's mark on a unit): the game's own icon sits where its old bar was, so it is drawn again
	-- above our bar from the same picture. If the game's icon cannot be read, its own stays as it is.
	p.raidTex = tf:CreateTexture(nil, "OVERLAY");
	p.raidTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");
	p.raidTex:SetWidth(16);
	p.raidTex:SetHeight(16);
	p.raidTex:SetPoint("BOTTOM", p.bar, "TOP", 0, 3);
	p.raidTex:Hide();
	p.raidOurs = ( p.raid ~= nil and p.raid.GetTexCoord ~= nil and p.raid.IsShown ~= nil );
	p.cRaid = 0;

	-- the game's own drawing becomes invisible (see Quiet: it is done again whenever the game undoes it)
	Quiet(p);

	-- a plate is given to another unit by showing it again: start from nothing until it has been looked at
	local old = plate:GetScript("OnShow");
	plate:SetScript("OnShow", function()
		if ( old ) then
			old();
		end
		local q = this.azsPlate;
		if ( q and q.v ) then
			q.v:Hide();
			if ( P.active ) then
				Quiet(q);                                 -- the game sets a plate up again when it gives it to a new unit
			end
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
	NativeAlpha(p, 1);
	p.quiet = false;
	p.cRaid = 0;
	p.raidTex:Hide();
	p.v:Hide();
end

local function Requiet(p)
	if ( p.quiet ) then
		return;
	end
	Quiet(p);
end

-- did the game bring its health bar back? (every look: one call)
local function Disturbed(p)
	return p.hb:GetAlpha() > 0;
end

-- did it add a part (its cast bar is made when it is first needed) or bring the cast bar back? (every few looks)
local function Stirred(p)
	return p.frame:GetNumChildren() ~= p.nkids or ( p.cast ~= nil and p.cast:GetAlpha() > 0 );
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

-- What the AZS API says about a plate's name: the list of special enemies alive (elites, guardians, bosses) is complete,
-- so a name that is not in it is an ordinary enemy, whatever icon the game's plate carries. Returns the kind of the unit
-- ("final", "boss", "guardian", "elite" or nil) and whether the list is there at all.
local function SpecialKind(name)
	local list = AZS_UNITS;
	if ( type(list) ~= "table" ) then
		return nil, false;
	end
	if ( G.UnitsStale() ) then
		return nil, true;                                     -- the list is the run before's: this run has none up yet
	end
	local best = nil;
	for i = 1, table.getn(list) do
		local u = list[i];
		if ( type(u) == "table" and u.name == name ) then
			local k = u.kind or "elite";
			if ( k == "final" or k == "boss" ) then
				return k, true;
			end
			if ( not best or k == "guardian" ) then
				best = k;
			end
		end
	end
	return best, true;
end

local function SpecialHealth(name)
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
	if ( count == 1 and found and G.Num(found.hpm) > 0 ) then
		return G.Num(found.hp), G.Num(found.hpm);
	end
	return nil;
end

-- Friendly plates: a hero (you and your party), a totem, or else a pet / summon / other friendly creature. The player
-- chooses whether pets and totems get a plate. Heroes are known by name (their own and the party's); a totem by its
-- name (the API's list of your totems, or "Totem" in the name); everything else that is friendly and no hero is
-- a pet or summon, whatever it is called.
local heroNames = {};
local totemNames = {};
local heroRead = -100;

local function ReadHeroes()
	local now = GetTime();
	if ( now - heroRead < 0.5 ) then
		return;
	end
	heroRead = now;
	heroNames = {};
	totemNames = {};
	local totems = AZS_TOTEMS;
	if ( type(totems) == "table" ) then
		for i = 1, table.getn(totems) do
			if ( type(totems[i]) == "table" and type(totems[i].name) == "string" ) then
				totemNames[totems[i].name] = true;
			end
		end
	end
	local me = UnitName("player");
	if ( me ) then
		heroNames[me] = true;
	end
	for i = 1, 4 do
		local u = "party" .. i;
		if ( UnitExists(u) ) then
			local n = UnitName(u);
			if ( n ) then
				heroNames[n] = true;
			end
		end
	end
end

-- a totem is known by "Totem" in its name (whatever case, a rank after it does not matter), or by the name of one of your
-- totems in the API's list (the plate may carry a rank the list does not, or the other way round)
local function IsTotemName(name)
	if ( totemNames[name] ) then
		return true;
	end
	local l = string.lower(name);
	if ( string.find(l, "totem", 1, true) or string.find(l, "t\195\179tem", 1, true) ) then
		return true;
	end
	if ( string.len(l) >= 5 ) then
		for tn in pairs(totemNames) do
			local lt = string.lower(tn);
			if ( string.len(lt) >= 5 and ( string.find(l, lt, 1, true) or string.find(lt, l, 1, true) ) ) then
				return true;
			end
		end
	end
	return false;
end

-- what a friendly plate is: "hero", "totem" or "pet" (a pet, summon or any other friendly creature)
local function FriendClass(name)
	if ( heroNames[name] ) then
		return "hero";
	end
	if ( IsTotemName(name) ) then
		return "totem";
	end
	return "pet";
end

-- does a friendly plate get drawn: heroes always, pets as the option says, totems unless they are hidden
local function FriendShown(name)
	local c = FriendClass(name);
	if ( c == "hero" ) then
		return true;
	end
	if ( c == "totem" ) then
		return G.Opt("friendTotems");
	end
	return G.Opt("friendPets");
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
	local special, listed = SpecialKind(name);
	if ( listed ) then
		elite = special ~= nil;
		boss = ( special == "boss" or special == "final" );
	elseif ( type(tex) == "string" ) then
		-- no list from the API (an older game): the level icon of the game's plate says it
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
		if ( kind == "elite" ) then
			p.bar:SetColor(COLOR_ELITE[1], COLOR_ELITE[2], COLOR_ELITE[3]);
		elseif ( kind == "friend" ) then
			p.bar:SetColor(COLOR_FRIEND[1], COLOR_FRIEND[2], COLOR_FRIEND[3]);
		elseif ( kind == "neutral" ) then
			p.bar:SetColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3]);
		else
			p.bar:SetColor(COLOR_ENEMY[1], COLOR_ENEMY[2], COLOR_ENEMY[3]);
		end
		-- the mark left of the bar: a skull for a boss, a crown for an elite
		if ( boss ) then
			G.SetSkull(p.mark, "tiny");
			p.mark:SetVertexColor(0.92, 0.85, 0.80, 1);
			p.mark:Show();
		elseif ( elite and G.SetCrown(p.mark) ) then
			p.mark:SetVertexColor(COLOR_ELITE[1], COLOR_ELITE[2] + 0.2, COLOR_ELITE[3] + 0.2, 1);
			p.mark:Show();
		else
			p.mark:Hide();
		end
	end
end

-- which raid icon (1 to 8) the game's icon on the plate shows: the picture is 4 x 4 icons, the icon is a part of it
local function RaidIndex(raid)
	local a, b, c, d, e, f, g, h = raid:GetTexCoord();
	local left, top = a, b;
	if ( h == nil ) then
		left, top = a, c;                                   -- the four number form: left, right, top, bottom
	end
	if ( type(left) ~= "number" or type(top) ~= "number" ) then
		return nil;
	end
	local col = math.floor(left * 4 + 0.5);
	local row = math.floor(top * 4 + 0.5);
	if ( col < 0 or col > 3 or row < 0 or row > 3 ) then
		return nil;
	end
	return row * 4 + col + 1;
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
		show = G.Opt("platesFriend") and FriendShown(p.rawName);
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
	-- a mark on the unit (skull, cross, ...): drawn above the bar
	if ( p.raidOurs ) then
		local idx = 0;
		if ( p.raid:IsShown() ) then
			idx = RaidIndex(p.raid);
			if ( not idx ) then
				p.raidOurs = false;                           -- not readable here: the game's own icon stays
				p.raid:SetAlpha(1);
				idx = 0;
			end
		end
		if ( p.cRaid ~= idx ) then
			p.cRaid = idx;
			if ( idx > 0 ) then
				local col = math.mod(idx - 1, 4);
				local row = math.floor(( idx - 1 ) / 4);
				p.raidTex:SetTexCoord(col * 0.25, ( col + 1 ) * 0.25, row * 0.25, ( row + 1 ) * 0.25);
				p.raidTex:Show();
			else
				p.raidTex:Hide();
			end
		end
	end
	if ( not p.shownV ) then
		p.shownV = true;
		p.v:Show();
	end
end

local function Look(p, tname, tkind)
	if ( p.quiet and Disturbed(p) ) then
		p.quiet = false;                                      -- the game made something visible again
	end
	if ( not p.quiet ) then
		Requiet(p);
	end
	p.age = ( p.age or 0 ) + 1;
	if ( p.age >= IDENTIFY or not p.rawName ) then
		if ( p.quiet and Stirred(p) ) then
			Quiet(p);
		end
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
	if ( G.Opt("platesFriend") and not ( G.Opt("friendPets") and G.Opt("friendTotems") ) ) then
		ReadHeroes();
	end
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
		p.cRaid = 0;
		if ( p.frame:IsShown() ) then
			p.quiet = false;                                  -- a plate given to a unit is set up again
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
	local dumped = 0;
	for i = 1, table.getn(P.list) do
		local p = P.list[i];
		if ( dumped < 2 and p.frame:IsShown() ) then
			dumped = dumped + 1;
			local kids = { p.frame:GetChildren() };
			local sk, listed = SpecialKind(p.rawName or "");
			G.Print("  plate " .. dumped .. " " .. G.Plain(tostring(p.rawName)) .. ": " .. tostring(p.cKind) .. ", API says "
				.. ( listed and tostring(sk or "ordinary") or "nothing (no list)" ) .. ", game's level icon "
				.. ( p.icon:IsShown() and G.Plain(tostring(p.icon:GetTexture())) or "off" ) .. ", hidden by us " .. tostring(p.quiet)
				.. ", " .. table.getn(kids) .. " frames, " .. table.getn(p.regs) .. " regions");
			for k = 1, table.getn(kids) do
				local c = kids[k];
				G.Print("    frame " .. k .. (c == p.v and " (ours)" or "") .. ": " .. tostring(c:GetObjectType()) .. ", shown " .. tostring(c:IsShown())
					.. ", alpha " .. string.format("%.2f", c:GetAlpha()));
			end
			for k = 1, table.getn(p.regs) do
				local r = p.regs[k];
				G.Print("    region " .. k .. ": " .. tostring(r:GetObjectType()) .. ", shown " .. tostring(r:IsShown())
					.. ", alpha " .. string.format("%.2f", r:GetAlpha()));
			end
		end
	end
	-- the plates up: what each one is taken for (enemy, neutral, a hero, a totem or a pet) and whether we draw it
	ReadHeroes();
	local said = 0;
	for i = 1, table.getn(P.list) do
		local p = P.list[i];
		if ( said < 8 and p.frame:IsShown() and p.rawName and p.rawName ~= "" ) then
			said = said + 1;
			local r, g, b = p.hb:GetStatusBarColor();
			local what, drawn = nil, nil;
			if ( p.enemy ) then
				what = p.neutral and "neutral" or "enemy";
				drawn = G.Opt("nameplates") and ( p.elite or not G.Opt("platesElite") );
			else
				what = FriendClass(p.rawName);
				drawn = G.Opt("platesFriend") and FriendShown(p.rawName);
			end
			G.Print("  plate " .. G.Plain(p.rawName) .. ": taken for " .. what .. ", drawn " .. ( drawn and "yes" or "no" )
				.. ", game's bar colour " .. string.format("%.2f %.2f %.2f", r or 0, g or 0, b or 0));
		end
	end
	local tn = {};
	for n in pairs(totemNames) do
		table.insert(tn, n);
	end
	G.Print("your totems by the API: " .. ( table.getn(tn) > 0 and G.Plain(table.concat(tn, ", ")) or "none" ) .. "; hiding totems: "
		.. ( G.Opt("friendTotems") and "no" or "yes" ));
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
