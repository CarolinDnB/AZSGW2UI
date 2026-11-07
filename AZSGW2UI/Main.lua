-- AZS GW2 UI: Main.lua
-- Saved variables, building everything once the world is up, the update loop and /gw2.

local G = AZSGW2;

G.shown = false;
G.started = false;

------------------------------------------------------------------------ saved variables

-- The saved variables are a file the player (or a crash) can have damaged: every field is checked, so a bad
-- value can never stop the UI from building or hide a frame the game needs.
local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true };

local function IsNumber(v)
	return type(v) == "number" and v == v and v > -100000 and v < 100000;
end

function G.CleanDB(d)
	if ( not IsNumber(d.scale) ) then
		d.scale = 1;
	end
	d.scale = G.Clamp(d.scale, 0.6, 1.6);
	if ( type(d.enabled) ~= "boolean" ) then
		d.enabled = true;
	end
	if ( type(d.customArt) ~= "boolean" ) then
		d.customArt = true;
	end
	d.messages = d.messages and true or nil;
	if ( d.mapYards ~= nil and not ( IsNumber(d.mapYards) and d.mapYards > 20 and d.mapYards < 2000 ) ) then
		d.mapYards = nil;
	end
	if ( type(d.opt) ~= "table" ) then
		d.opt = {};
	end
	-- before 1.9.0 "plates" meant the game's own enemy nameplates: now they are the GW2 nameplates
	if ( d.plates and d.opt.nameplates == nil ) then
		d.opt.nameplates = true;
	end
	d.plates = nil;
	for k, v in pairs(d.opt) do
		if ( type(k) ~= "string" or type(v) ~= "boolean" ) then
			d.opt[k] = nil;
		end
	end
	if ( type(d.pos) ~= "table" ) then
		d.pos = {};
	end
	for k, p in pairs(d.pos) do
		if ( type(k) ~= "string" or type(p) ~= "table" or not ANCHORS[p[1] or ""] or not ANCHORS[p[2] or ""]
			or not IsNumber(p[3]) or not IsNumber(p[4]) ) then
			d.pos[k] = nil;
		end
	end
	if ( type(d.fscale) ~= "table" ) then
		d.fscale = {};
	end
	for k, v in pairs(d.fscale) do
		if ( type(k) ~= "string" or not IsNumber(v) ) then
			d.fscale[k] = nil;
		else
			d.fscale[k] = G.Clamp(v, G.FSCALE_MIN, G.FSCALE_MAX);
		end
	end
	local clean = {};
	if ( type(d.hide) == "table" ) then
		for i = 1, table.getn(d.hide) do
			local name = d.hide[i];
			local dupe = false;
			for j = 1, table.getn(clean) do
				if ( clean[j] == name ) then
					dupe = true;
				end
			end
			if ( not dupe and table.getn(clean) < 60 and G.ValidFrameName(name) and not G.IsProtected(name) ) then
				table.insert(clean, name);
			end
		end
	end
	d.hide = clean;
	if ( type(d.bind) ~= "table" ) then
		d.bind = {};
	end
	for k, v in pairs(d.bind) do
		if ( type(k) ~= "string" or not G.ValidFrameName(v) ) then
			d.bind[k] = nil;
		end
	end
	if ( d.cvSaved ~= nil ) then
		if ( type(d.cvSaved) ~= "table" ) then
			d.cvSaved = nil;
		else
			for k, v in pairs(d.cvSaved) do
				if ( type(k) ~= "string" or type(v) ~= "string" or string.len(v) > 12 ) then
					d.cvSaved[k] = nil;
				end
			end
		end
	end
end

function G.InitDB()
	if ( not AZSGW2DB ) then
		AZSGW2DB = {};
	end
	local d = AZSGW2DB;
	if ( d.enabled == nil ) then
		d.enabled = true;
	end
	if ( not d.scale ) then
		d.scale = 1;
	end
	if ( d.customArt == nil ) then
		d.customArt = true;
	end
	G.CleanDB(d);
end

------------------------------------------------------------------------ show / hide

function G.SetShown(show)
	G.shown = show and true or false;
	if ( G.shown ) then
		for i = 1, table.getn(G.containers) do
			G.containers[i]:Show();
		end
	else
		for i = 1, table.getn(G.all) do
			G.all[i].vis = nil;
			G.all[i]:Hide();
		end
		if ( G.charPanel ) then
			G.charPanel:Hide();
		end
	end
end

function G.Visibility(dt)
	local want = false;
	if ( AZSGW2DB.enabled and G.Phase() ~= nil ) then
		want = true;
	end
	if ( want ~= G.shown ) then
		G.SetShown(want);
	end
end

------------------------------------------------------------------------ update loop

function G.Tick(elapsed)
	for i = 1, table.getn(G.updaters) do
		local u = G.updaters[i];
		if ( not u.dead and ( u.always or G.shown ) ) then
			u.acc = u.acc + elapsed;
			if ( u.hold and u.hold > 0 ) then
				u.hold = u.hold - elapsed;               -- after an error: wait, then try again
				u.acc = 0;
			elseif ( u.acc >= u.interval ) then
				local dt = u.acc;
				u.acc = 0;
				local ok, err = pcall(u.fn, dt);
				if ( ok ) then
					u.runs = ( u.runs or 0 ) + 1;
					if ( u.runs > 1200 ) then
						u.errors = 0;                    -- a long quiet stretch forgives old errors
						u.runs = 0;
					end
				else
					u.runs = 0;
					u.errors = ( u.errors or 0 ) + 1;
					if ( u.errors == 1 ) then
						G.Print("error in '" .. u.name .. "': " .. tostring(err));
					end
					if ( u.errors >= 5 ) then
						u.dead = true;
						G.Print("'" .. u.name .. "' stopped after repeated errors: " .. tostring(err));
					else
						u.hold = 10;                     -- a hiccup (a table the game had not filled yet) heals itself
					end
				end
			end
		end
	end
end

local function AddUpdater(name, fn, interval, always)
	G.AddUpdater(name, fn, interval);
	G.updaters[table.getn(G.updaters)].always = always;
end

------------------------------------------------------------------------ start

local BUILDERS = {
	{ "orb", "BuildOrb" },
	{ "resource", "BuildResource" },
	{ "skills", "BuildSkills" },
	{ "top", "BuildTop" },
	{ "tally", "BuildTally" },
	{ "bosses", "BuildBosses" },
	{ "guardians", "BuildGuardians" },
	{ "party", "BuildParty" },
	{ "revive", "BuildRevive" },
	{ "character", "BuildCharacter" },
	{ "target", "BuildTarget" },
	{ "banner", "BuildBanner" },
	{ "levelup", "BuildLevelUp" },
	{ "meter", "BuildMeter" },
	{ "minimap", "BuildMinimap" },
	{ "mapbutton", "BuildMapButton" },
	{ "settings", "BuildSettings" },
	{ "damage", "BuildDamage" },
};

function G.Start()
	if ( G.started ) then
		return;
	end
	G.started = true;
	G.InitDB();
	G.art.custom = ( AZSGW2DB.customArt ~= false );

	for i = 1, table.getn(BUILDERS) do
		local ok, err = pcall(G[BUILDERS[i][2]]);
		if ( not ok ) then
			G.Print("could not build '" .. BUILDERS[i][1] .. "': " .. tostring(err));
		end
	end

	-- every frame exists now: work out which ones hang off which movable frame, and size them
	local ok, err = pcall(G.ApplyScales);
	if ( not ok ) then
		G.Print("could not apply frame sizes: " .. tostring(err));
	end

	AddUpdater("visibility", G.Visibility, 0.2, true);
	AddUpdater("enforce", G.EnforceHidden, 0.5, true);
	AddUpdater("hunt", G.UpdateHunt, 0.05, true);
	AddUpdater("livetip", G.UpdateLiveTip, 0.1, true);
	AddUpdater("orb", G.UpdateOrb, 0);
	AddUpdater("resource", G.UpdateResource, 0.05);
	AddUpdater("skills", G.UpdateSkills, 0.03);
	AddUpdater("targets", G.UpdateTargets, 0.25);
	AddUpdater("jewelry", G.UpdateJewelry, 1.0);
	AddUpdater("status", G.UpdateStatus, 0.2);
	AddUpdater("auras", G.UpdateAuras, 0.2);
	AddUpdater("party", G.UpdateParty, 0.2);
	AddUpdater("revive", G.UpdateRevive, 0.05);
	AddUpdater("character", G.UpdateCharacter, 0.25);
	AddUpdater("target", G.UpdateTarget, 0.05);
	AddUpdater("top", G.UpdateTop, 0.1);
	AddUpdater("tally", G.UpdateTally, 0.25);
	AddUpdater("bosses", G.UpdateBosses, 0.1);
	AddUpdater("guardians", G.UpdateGuardians, 0.25);
	AddUpdater("banner", G.UpdateBanner, 0);
	AddUpdater("levelup", G.UpdateLevelUp, 0.05);
	AddUpdater("meter", G.UpdateMeter, 0.3);
	AddUpdater("minimap", G.UpdateMinimap, 0, true);
	AddUpdater("arrows", G.UpdateGuardianArrows, 0.05);
	AddUpdater("plates", G.UpdatePlates, 0.1, true);
	AddUpdater("marks", G.UpdateMarks, 1, true);
	AddUpdater("rave", G.UpdateRave, 0.5, true);
	G.raveUpdater = G.updaters[table.getn(G.updaters)];

	local driver = CreateFrame("Frame", "AZSGW2Driver", UIParent);
	driver.azs = true;
	driver:SetScript("OnUpdate", function()
		G.Tick(arg1 or 0);
	end);

	if ( AZSGW2DB.enabled ) then
		G.HideGameHud(true);
		G.EnforceHidden();
	end
end

local events = CreateFrame("Frame");
events:RegisterEvent("VARIABLES_LOADED");
events:RegisterEvent("PLAYER_ENTERING_WORLD");
events:RegisterEvent("PLAYER_TARGET_CHANGED");
events:RegisterEvent("UNIT_HEALTH");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", function()
	if ( event == "PLAYER_TARGET_CHANGED" or ( event == "UNIT_HEALTH" and arg1 == "target" )
		or ( event == "CHAT_MSG_ADDON" and arg1 == "AZSTGT" ) ) then
		-- the bar changes in the same frame as the click / the table update, not at the next poll
		if ( G.started and G.target ) then
			pcall(G.UpdateTarget, 0);
		end
	elseif ( event == "VARIABLES_LOADED" ) then
		G.InitDB();
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		if ( not G.started ) then
			G.Start();
		elseif ( AZSGW2DB.enabled ) then
			G.HideGameHud(true);
		end
		-- the game forgets which nameplates are on when a world loads: switch them to the options again
		G.platesApplied, G.friendApplied = nil, nil;
	end
end);

------------------------------------------------------------------------ /gw2

local function Help()
	G.Print("commands:");
	G.Print("/gw2 config : settings window (also: left click the round icon at the minimap)");
	G.Print("/gw2 unlock | lock : move and resize every frame freely (a bar at the top locks it again)");
	G.Print("/gw2 off | on : give the game's own HUD back / use this one");
	G.Print("/gw2 scale <0.6-1.6> : size of everything");
	G.Print("/gw2 reset : forget moved windows");
	G.Print("/gw2 mapyards <number|off> : yards across the minimap, if the pins are off from the map");
	G.Print("/gw2 art custom | stock : generated textures or stock Blizzard ones (reloads the UI)");
	G.Print("/gw2 hide <FrameName> | unhide <FrameName> : keep one of the game's frames hidden");
	G.Print("/gw2 find <text> : list frames that show that text (to find a frame name)");
	G.Print("/gw2 bind <character|talents> <BINDING> : key binding the two buttons run");
	G.Print("/gw2 bindings [text] : list key binding names");
	G.Print("/gw2 plates on|off | elite on|off | friends on|off | pets on|off | hidetotems on|off | debug : GW2 nameplates (off by default)");
	G.Print("/gw2 targets [on|off] : the number of targets on the skills; without on / off it shows what each skill's tooltip says");
	G.Print("/gw2 marks on|off : mark your co-op party (you too) with the game's raid icons when you join (/gw2 marks says who has which)");
	G.Print("/gw2 messages on|off : the game's own centre-screen messages (off by default)");
	G.Print("/gw2 dmg all | crits | off | ticks on | ticks off : damage numbers");
	G.Print("/gw2 char [on|off] : open the character panel / use it instead of the game's window");
	G.Print("/gw2 partyinfo : health and buffs of each friend as the client reports them (barrier check)");
	G.Print("/gw2 stats : every value of AZS_STATS (to check what the attributes show)");
	G.Print("/gw2 hunt on|off : look for the game's own popup text on screen (stops itself when it finds none)");
	G.Print("/gw2 debug : what is hidden, which bindings the buttons use");
	G.Print("/gw2 version : the version of this UI");
	G.Print("/gw2 focus : what is under the mouse (point at something that has no tooltip first); /gw2 rows [tip [skill]] : where the game draws its own skill icons (tip: and what its tooltips say)");
end

local function FindFrames(text)
	if ( not EnumerateFrames ) then
		G.Print("this client has no EnumerateFrames.");
		return;
	end
	text = string.lower(text);
	local found = 0;
	local f = EnumerateFrames();
	while ( f and found < 20 ) do
		local hit = false;
		if ( f.GetText ) then
			local ok, s = pcall(f.GetText, f);
			if ( ok and type(s) == "string" and string.find(string.lower(s), text, 1, true) ) then
				hit = true;
			end
		end
		if ( not hit and f.GetRegions ) then
			local regs = { f:GetRegions() };
			for i = 1, table.getn(regs) do
				local r = regs[i];
				if ( r.GetObjectType and r:GetObjectType() == "FontString" ) then
					local s = r:GetText();
					if ( type(s) == "string" and string.find(string.lower(s), text, 1, true) ) then
						hit = true;
						break;
					end
				end
			end
		end
		if ( hit ) then
			local own = f.GetName and f:GetName();
			local n, p, depth = own, f, 0;
			while ( not n and p and depth < 8 ) do
				p = p.GetParent and p:GetParent();
				n = p and p.GetName and p:GetName();
				depth = depth + 1;
			end
			local shown = "";
			if ( f.IsShown and f:IsShown() ) then
				shown = " (visible)";
			end
			if ( own ) then
				G.Print(own .. shown);
			else
				G.Print("(unnamed frame inside " .. tostring(n or "?") .. ")" .. shown);
			end
			found = found + 1;
		end
		f = EnumerateFrames(f);
	end
	if ( found == 0 ) then
		G.Print("nothing found for '" .. text .. "'.");
	end
end

-- the chain of names above a frame: "AZSSpell3 < AZSHud < UIParent"
local function Chain(f)
	local out, depth = {}, 0;
	while ( f and depth < 6 ) do
		local n = f.GetName and f:GetName();
		table.insert(out, n or "(unnamed)");
		f = f.GetParent and f:GetParent();
		depth = depth + 1;
	end
	return table.concat(out, " < ");
end

-- /gw2 focus: what is under the mouse right now (point at a thing that has no tooltip and type this)
local function FocusReport()
	local f = GetMouseFocus and GetMouseFocus();
	if ( not f ) then
		G.Print("nothing is under the mouse (point at the thing, then type /gw2 focus).");
		return;
	end
	local kind = f.GetObjectType and f:GetObjectType() or "?";
	G.Print("under the mouse: " .. Chain(f) .. " [" .. kind .. "]"
		.. ( f.IsVisible and f:IsVisible() and ", visible" or ", hidden" ));
	if ( f.GetWidth and f.GetHeight ) then
		G.Print("size " .. string.format("%.0f x %.0f", f:GetWidth() or 0, f:GetHeight() or 0)
			.. ", mouse " .. tostring(f.IsMouseEnabled and f:IsMouseEnabled())
			.. ", OnEnter " .. tostring(f.GetScript and f:GetScript("OnEnter") ~= nil));
	end
	if ( f.tipTag ) then
		G.Print("one of ours (" .. f.tipTag .. ")" .. ( f.entry and ( ", skill " .. tostring(f.entry.key) ) or "" )
			.. ( f.data and f.data.name and ( ", " .. G.Plain(f.data.name) ) or "" ));
	else
		G.Print("not one of ours: the game's own frame, or another addon's");
	end
	if ( f.entry and G.SkillBookReport ) then
		G.SkillBookReport(f);
	end
	local t = G.tipLast;
	if ( t ) then
		G.Print("last tooltip of ours: " .. t.tag .. ", " .. t.lines .. " lines" .. ( t.floor and ", filled by the fallback" or "" ));
	end
	if ( GameTooltip and GameTooltip.IsShown ) then
		local n = GameTooltip.NumLines and GameTooltip:NumLines() or 0;
		G.Print("the game's tooltip is " .. ( GameTooltip:IsShown() and "up" or "not up" ) .. ", " .. n .. " lines:");
		for i = 1, math.min(n, 8) do
			local fs = getglobal("GameTooltipTextLeft" .. i);
			local text = fs and fs.GetText and fs:GetText();
			G.Print("  " .. ( ( text and text ~= "" ) and G.Plain(text) or "(empty line)" ));
		end
	end
	if ( f.GetRegions ) then
		local regs = { f:GetRegions() };
		local shown = 0;
		for i = 1, table.getn(regs) do
			local r = regs[i];
			if ( shown < 4 and r.GetTexture and r:GetObjectType() == "Texture" ) then
				local tex = r:GetTexture();
				if ( tex ) then
					G.Print("texture: " .. G.Plain(tostring(tex)));
					shown = shown + 1;
				end
			end
		end
	end
end

-- /gw2 rows: where the game draws its own skill icons (frames showing the icon of one of your skills; ours left out)
-- what the game's tooltip holds right now (up or not, and its first lines)
local function PrintGameTooltip(prefix)
	if ( not ( GameTooltip and GameTooltip.IsShown ) ) then
		return;
	end
	local n = GameTooltip.NumLines and GameTooltip:NumLines() or 0;
	G.Print(prefix .. "tooltip " .. ( GameTooltip:IsShown() and "up" or "not up" ) .. ", " .. n .. " lines");
	for i = 1, math.min(n, 6) do
		local fs = getglobal("GameTooltipTextLeft" .. i);
		local text = fs and fs.GetText and fs:GetText();
		G.Print(prefix .. "  " .. ( ( text and text ~= "" ) and G.Plain(text) or "(empty line)" ));
	end
end

local function RowsReport(withTip, word)
	if ( not EnumerateFrames ) then
		G.Print("this client has no EnumerateFrames.");
		return;
	end
	local want = {};
	local n = 0;
	for key, info in pairs(G.abilityInfo or {}) do
		if ( info.icon ) then
			want[string.lower(tostring(info.icon))] = info.name or key;
			n = n + 1;
		end
	end
	if ( n == 0 ) then
		G.Print("no skill icons known yet: start a run first.");
		return;
	end
	local found, ours = 0, 0;
	local hits = {};
	local f = EnumerateFrames();
	while ( f ) do
		if ( f.GetRegions ) then
			local regs = { f:GetRegions() };
			for i = 1, table.getn(regs) do
				local r = regs[i];
				if ( r.GetObjectType and r:GetObjectType() == "Texture" ) then
					local tex = r:GetTexture();
					local what = type(tex) == "string" and want[string.lower(tex)];
					if ( what and word and word ~= "" and not string.find(string.lower(tostring(what)), word, 1, true) ) then
						what = nil;              -- only the skill that was asked for
					end
					if ( what ) then
						if ( f.tipTag or f.entry or f.data ) then
							ours = ours + 1;
						elseif ( found < 16 ) then
							found = found + 1;
							table.insert(hits, { frame = f, what = what });
							G.Print(G.Plain(what) .. ": " .. Chain(f) .. ( f:IsVisible() and ", visible" or ", hidden" )
								.. ( r.IsShown and r:IsShown() and "" or ", icon hidden" )
								.. ( f.GetScript and f:GetScript("OnEnter") and ", has a tooltip script" or ", no tooltip script" ));
						end
						break;
					end
				end
			end
		end
		f = EnumerateFrames(f);
	end
	G.Print("frames with a skill icon that are not ours: " .. found .. " (ours: " .. ours .. ")."
		.. ( found == 0 and " The game's own skill row is not drawn right now." or "" ));
	if ( withTip ) then
		-- point at each of them the way the mouse would: what the game's own tooltip says for its icon
		for i = 1, math.min(table.getn(hits), 8) do
			local fr = hits[i].frame;
			G.Print(G.Plain(hits[i].what) .. " (" .. Chain(fr) .. "):");
			local enter = fr.GetScript and fr:GetScript("OnEnter");
			if ( enter ) then
				local keep = this;
				this = fr;
				local ok, err = pcall(enter);
				this = keep;
				if ( ok ) then
					PrintGameTooltip("  ");
				else
					G.Print("  its tooltip script failed: " .. G.Plain(tostring(err)));
				end
				local leave = fr.GetScript and fr:GetScript("OnLeave");
				if ( leave ) then
					this = fr;
					pcall(leave);
					this = keep;
				end
				GameTooltip:Hide();
			else
				G.Print("  no tooltip script");
			end
		end
	end
end

local function ListBindings(text)
	if ( not GetNumBindings ) then
		return;
	end
	text = string.lower(text or "");
	local shown = 0;
	for i = 1, GetNumBindings() do
		local cmd, key1 = GetBinding(i);
		if ( cmd and shown < 30 and string.find(string.lower(cmd), text, 1, true) ) then
			G.Print(cmd .. "  " .. tostring(key1 or ""));
			shown = shown + 1;
		end
	end
end

function G.Slash(msg)
	msg = msg or "";
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)%s*$");
	cmd = string.lower(cmd or "");
	rest = rest or "";
	G.InitDB();

	if ( cmd == "off" ) then
		AZSGW2DB.enabled = false;
		G.PartyStop(true);
		G.SetUnlocked(false);
		G.ApplyMinimap();
		G.HideGameHud(false);
		G.RestoreHidden();
		G.SetShown(false);
		G.ApplyDamage();
		if ( G.mapButton ) then
			G.mapButton:Hide();
		end
		if ( G.settings ) then
			G.settings:Hide();
		end
		G.Print("off. The game's own HUD is back. /gw2 on to use this UI again.");
		local phase = AZS_GetPhase and AZS_GetPhase() or nil;
		if ( phase == "playing" or phase == "choosing" or phase == "paused" ) then
			G.Print("A run is on: if the game's own skill bars look empty, /reload makes the game draw them again. /gw2 rows shows what the game has drawn.");
		end
	elseif ( cmd == "on" ) then
		AZSGW2DB.enabled = true;
		G.HideGameHud(true);
		G.ApplyMinimap();
		G.ApplyDamage();
		if ( G.mapButton ) then
			G.mapButton:Show();
		end
		G.Print("on.");
	elseif ( cmd == "scale" ) then
		local s = tonumber(rest);
		if ( not s ) then
			G.Print("scale is " .. tostring(AZSGW2DB.scale));
			return;
		end
		G.SetScaleAll(s);
		G.Print("scale " .. AZSGW2DB.scale);
	elseif ( cmd == "reset" ) then
		G.ResetPositions();
	elseif ( cmd == "config" or cmd == "settings" or cmd == "menu" ) then
		G.ToggleSettings();
	elseif ( cmd == "unlock" or cmd == "lock" ) then
		G.SetUnlocked(cmd == "unlock");
		G.RefreshSettings();
		G.Print("layout " .. ( G.unlocked and "unlocked: drag the gold boxes, /gw2 lock when done." or "locked." ));
	elseif ( cmd == "mapyards" ) then
		local y = tonumber(rest);
		if ( rest == "off" ) then
			AZSGW2DB.mapYards = nil;
			G.yardsStamp = nil;
			G.Print("minimap range: automatic.");
		elseif ( y and y > 20 and y < 2000 ) then
			AZSGW2DB.mapYards = y;
			G.Print("minimap range: " .. y .. " yards across.");
		else
			G.Print("minimap range: " .. string.format("%.0f", G.MapYards()) .. " yards across (" .. ( G.indoors and "indoors" or "outdoors" ) .. " zoom). /gw2 mapyards <number> to set it, off for automatic.");
		end
	elseif ( cmd == "art" ) then
		if ( rest == "stock" ) then
			AZSGW2DB.customArt = false;
		elseif ( rest == "custom" ) then
			AZSGW2DB.customArt = true;
		else
			G.Print("art is " .. ( AZSGW2DB.customArt and "custom" or "stock" ) .. ". Use /gw2 art custom or /gw2 art stock.");
			return;
		end
		ReloadUI();
	elseif ( cmd == "hide" and rest ~= "" ) then
		if ( not G.ValidFrameName(rest) ) then
			G.Print("that is not a frame name (letters, digits and _ only).");
			return;
		end
		if ( G.IsProtected(rest) ) then
			G.Print(rest .. " is a protected frame (the game's dialogs, chat and map, or this addon's own): it is not hidden.");
			return;
		end
		if ( table.getn(AZSGW2DB.hide) >= 60 ) then
			G.Print("the list of hidden frames is full (60): /gw2 unhide one first.");
			return;
		end
		for i = 1, table.getn(AZSGW2DB.hide) do
			if ( AZSGW2DB.hide[i] == rest ) then
				G.Print(rest .. " is already hidden.");
				return;
			end
		end
		table.insert(AZSGW2DB.hide, rest);
		G.Print("keeping " .. rest .. " hidden.");
	elseif ( cmd == "unhide" and rest ~= "" ) then
		for i = table.getn(AZSGW2DB.hide), 1, -1 do
			if ( AZSGW2DB.hide[i] == rest ) then
				table.remove(AZSGW2DB.hide, i);
			end
		end
		local fr = nil;
		if ( G.ValidFrameName(rest) and not G.IsProtected(rest) ) then
			fr = getglobal(rest);
		end
		if ( fr and fr.Show ) then
			fr:Show();
		end
		G.hiddenByUs[rest] = nil;
		G.Print(rest .. " is no longer kept hidden.");
	elseif ( cmd == "find" and rest ~= "" ) then
		FindFrames(rest);
	elseif ( cmd == "version" or cmd == "ver" or cmd == "v" ) then
		local v = GetAddOnMetadata and GetAddOnMetadata("AZSGW2UI", "Version");
		G.Print("version " .. ( v and tostring(v) or "unknown" ));
	elseif ( cmd == "focus" ) then
		FocusReport();
	elseif ( cmd == "rows" ) then
		local _, _, tipWord = string.find(rest, "^tip%s*(.-)%s*$");
		RowsReport(tipWord ~= nil, tipWord and string.lower(tipWord) or nil);
	elseif ( cmd == "dmg" or cmd == "damage" ) then
		if ( rest == "all" ) then
			G.SetOpt("dmg", true);
			G.SetOpt("dmgCrit", false);
		elseif ( rest == "crits" or rest == "crit" ) then
			G.SetOpt("dmg", true);
			G.SetOpt("dmgCrit", true);
		elseif ( rest == "off" ) then
			G.SetOpt("dmg", false);
		elseif ( rest == "ticks on" or rest == "ticks off" ) then
			G.SetOpt("dmgTicks", rest == "ticks on");
		end
		G.ApplyDamage();
		G.Print("damage numbers: " .. ( G.Opt("dmg") and ( G.Opt("dmgCrit") and "critical hits only" or "all hits" ) or "off" )
			.. ", damage over time ticks " .. ( G.Opt("dmgTicks") and "on" or "off" ));
		if ( rest == "" ) then
			G.Print("usage: /gw2 dmg all | crits | off | ticks on | ticks off");
		end
	elseif ( cmd == "partyinfo" ) then
		G.PrintParty();
	elseif ( cmd == "party" ) then
		G.PartyCommand(rest);
	elseif ( cmd == "stats" ) then
		G.PrintStats();
	elseif ( cmd == "char" or cmd == "character" ) then
		if ( rest == "on" or rest == "off" ) then
			G.SetOpt("charPanel", rest == "on");
			G.Print("character panel " .. rest .. ( rest == "on" and " (it replaces the game's window)." or " (the game's window is used)." ));
		elseif ( not G.ToggleCharPanel() ) then
			G.Print("the character panel could not be built.");
		end
	elseif ( cmd == "hunt" ) then
		if ( rest == "on" ) then
			G.hunt.off = false;
			G.hunt.misses = 0;
		elseif ( rest == "off" ) then
			G.hunt.off = true;
			G.hunt.pending = nil;
		end
		G.Print("popup hunter: " .. ( G.hunt.off and "off" or "on" ) .. ", popups hidden so far: "
			.. tostring(G.hunt.count) .. ", frames looked at last time: " .. tostring(G.hunt.nodes or 0));
	elseif ( cmd == "bindings" ) then
		ListBindings(rest);
	elseif ( cmd == "bind" ) then
		local _, _, which, name = string.find(rest, "^(%S+)%s+(%S+)$");
		if ( which and ( which == "character" or which == "talents" ) and G.ValidFrameName(name) ) then
			AZSGW2DB.bind[which] = name;
			G.Print(which .. " button now runs " .. name);
		else
			G.Print("character: " .. G.BindingText("character"));
			G.Print("talents: " .. G.BindingText("talents"));
			G.Print("usage: /gw2 bind <character|talents> <BINDING>   (names: /gw2 bindings)");
		end
	elseif ( cmd == "plates" ) then
		local _, _, which, state = string.find(rest, "^(%S*)%s*(%S*)$");
		which = which or "";
		state = state or "";
		local key = nil;
		local invert = false;
		if ( which == "on" or which == "off" ) then
			key, state = "nameplates", which;
		elseif ( which == "elite" or which == "elites" ) then
			key = "platesElite";
		elseif ( which == "friends" or which == "friend" or which == "friendly" ) then
			key = "platesFriend";
		elseif ( which == "pets" or which == "summons" ) then
			key = "friendPets";
		elseif ( which == "hidetotems" or which == "totems" ) then
			key = "friendTotems";                              -- the option says "show", the command says "hide"
			invert = true;
		elseif ( which == "debug" ) then
			G.PlatesReport();
			return;
		end
		if ( not key or ( state ~= "on" and state ~= "off" ) ) then
			G.Print("nameplates are " .. ( G.Opt("nameplates") and "on" or "off" ) .. ", only elites and guardians "
				.. ( G.Opt("platesElite") and "on" or "off" ) .. ", friendly " .. ( G.Opt("platesFriend") and "on" or "off" ) .. ".");
			G.Print("Use /gw2 plates on | off,  /gw2 plates elite on | off,  /gw2 plates friends on | off,  /gw2 plates pets on | off,  /gw2 plates hidetotems on | off (friendly plates of pets and summons / hide the plates of totems),  /gw2 plates debug.");
			return;
		end
		G.SetPlateOpt(key, ( state == "on" ) ~= invert);
		G.Print("plates " .. which .. " " .. state);
	elseif ( cmd == "targets" ) then
		if ( rest == "on" or rest == "off" ) then
			G.SetOpt("hits", rest == "on");
			G.RefreshSettings();
			G.Print("max targets on the skills: " .. rest);
		else
			G.TargetsReport();
		end
	elseif ( cmd == "marks" ) then
		if ( rest ~= "on" and rest ~= "off" ) then
			G.AllyMarksReport();
			return;
		end
		G.SetOpt("markAllies", rest == "on");
		G.RefreshSettings();
		G.Print("marking the party " .. rest);
	elseif ( cmd == "messages" ) then
		if ( rest ~= "on" and rest ~= "off" ) then
			G.Print("messages are " .. ( AZSGW2DB.messages and "on" or "off" ) .. ". Use /gw2 messages on or /gw2 messages off.");
			return;
		end
		G.SetMessages(rest == "on");
		G.Print("messages " .. rest);
	elseif ( cmd == "debug" ) then
		for i = 1, table.getn(G.HUD_PARTS) do
			local p = G.HUD_PARTS[i];
			local cv = "?";
			if ( G.HUD_CVAR[p] and GetCVar ) then
				cv = tostring(GetCVar(G.HUD_CVAR[p]));
			end
			G.Print("game HUD '" .. p .. "' shown: " .. tostring(AZS_IsHudShown and AZS_IsHudShown(p)) .. "  cvar " .. cv);
		end
		local n = 0;
		for name in pairs(G.keptHidden) do
			n = n + 1;
		end
		G.Print("stock frames kept hidden: " .. n);
		if ( G.tipLast ) then
			G.Print("last tooltip of ours: " .. G.tipLast.tag .. ", " .. G.tipLast.lines .. " lines" .. ( G.tipLast.floor and ", filled by the fallback" or "" ));
		end
		G.Print("talents button: " .. G.BindingText("talents"));
		G.Print("character button: " .. G.BindingText("character"));
		G.Print("party members: " .. tostring(GetNumPartyMembers and GetNumPartyMembers()));
		G.Print("minimap: " .. ( G.mmAttached and "game minimap moved into the GW2 frame" or "not attached" )
			.. ( Minimap and "" or " (this client has no Minimap frame)" ));
		if ( Minimap and Minimap.GetZoom ) then
			G.Print("minimap zoom " .. Minimap:GetZoom() .. ", " .. string.format("%.0f", G.MapYards()) .. " yards across, " .. ( G.indoors and "indoor" or "outdoor" ));
		end
		G.Print("damage numbers: " .. ( G.dmg.ok and "world combat text API found" or "API missing, the game's numbers stay" ));
	else
		Help();
	end
end

SLASH_AZSGW21 = "/gw2";
SlashCmdList["AZSGW2"] = function(msg)
	G.Slash(msg);
end
