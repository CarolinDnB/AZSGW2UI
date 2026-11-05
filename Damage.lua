-- AZS GW2 UI: Damage.lua
-- Guild Wars 2 style floating damage numbers from the world-anchored combat text API: plain white
-- numbers in a clean sans font for hits, bigger ones on a red splash for critical hits, small grey words
-- for misses. The labels follow the enemy (AZS_ProjectCombatTextAnchors, "follow") and are moved in the
-- game's per-frame handler.

local G = AZSGW2;

local MAXLABELS = 60;
local LIFE = 0.95;          -- seconds a number floats
local MAXAGE = 0.8;         -- a hit older than this when it is read is not shown
local PERFRAME = 14;        -- new numbers per frame at most

-- sizes (in the game's font points; the font's digits are about 63% of that tall): last release's sizes
-- (14 / 24 / 11 / 12) made 10% bigger for hits and 17.5% bigger for crits; the numbers are drawn at whole
-- font sizes, so a hit comes out at 15 and a crit at 28 (+7% and +17%)
local SIZE_HIT = 15.4;      -- a normal hit
local SIZE_CRIT = 28.2;     -- a critical hit
local SIZE_TICK = 12.1;     -- damage over time
local SIZE_OTHER = 13.2;    -- pets and others
local SIZE_MISS = 13.2;
local RISE_HIT, RISE_CRIT = 40, 54;   -- pixels a number climbs

G.dmg = { labels = {}, free = {}, cursor = nil, last = 0 };

local function PickFont()
	return G.NumFont();      -- the shipped sans font; the game's own if the client can not load it
end

local function NewLabel()
	local d = G.dmg;
	local h = table.remove(d.free);
	if ( not h ) then
		h = CreateFrame("Frame", nil, WorldFrame);
		h.azs = true;
		h:SetWidth(2);
		h:SetHeight(2);
		h:SetFrameStrata("HIGH");
		h.splat = h:CreateTexture(nil, "BACKGROUND");
		h.splat:SetTexture(G.TEXPATH .. "splat.tga");
		h.splat:SetPoint("CENTER", h, "CENTER", 0, 0);
		h.splat:SetWidth(40);
		h.splat:SetHeight(40);
		h.splat:Hide();
		h.text = h:CreateFontString(nil, "OVERLAY");
		h.text:SetPoint("CENTER", h, "CENTER", 0, 0);
		h.text:SetJustifyH("CENTER");
		h.text:SetFont(G.FONT, 14, "OUTLINE");   -- a font string needs a font before it gets text
		h.text:SetFont(PickFont(), 14, "OUTLINE");
	end
	h.size = 0;
	return h;
end

local function Release(l)
	l.holder:Hide();
	table.insert(G.dmg.free, l.holder);
	l.holder = nil;
end

-- GW2 shows the plain number; very big ones are shortened (this game's damage runs into the billions)
local function NumberText(n)
	n = G.Num(n);
	if ( n >= 100000 ) then
		return G.Short(n);
	end
	return string.format("%d", math.floor(n + 0.5));
end

-- the font sizes that are used (whole sizes up to 16, then steps of two): 18 fonts at most, however many
-- numbers there are and however far away
local SIZES = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34 };

local function Snap(size)
	local best = SIZES[1];
	for i = 1, table.getn(SIZES) do
		if ( math.abs(SIZES[i] - size) < math.abs(best - size) ) then
			best = SIZES[i];
		end
	end
	return best;
end

local function Style(l, size)
	size = Snap(size);
	if ( l.size ~= size ) then
		l.size = size;
		l.holder.text:SetFont(PickFont(), size, "OUTLINE");
		if ( l.crit ) then
			-- the red blot is a little taller than the digits and sits behind the start of the number
			local tw = l.holder.text:GetStringWidth();
			if ( not tw or tw <= 0 ) then
				tw = size * 0.5 * string.len(tostring(l.holder.text:GetText() or "0000"));
			end
			local w = size * 1.9;
			l.holder.splat:SetWidth(w);
			l.holder.splat:SetHeight(w);
			l.holder.splat:ClearAllPoints();
			l.holder.splat:SetPoint("CENTER", l.holder, "CENTER", math.min(0, -tw / 2 + size * 0.6), 0);
		end
	end
end

local function AddLabel(ev, now)
	local d = G.dmg;
	if ( not ev.anchorId or ( ev.anchorStatus and ev.anchorStatus ~= "ready" ) ) then
		return;
	end
	if ( ev.presentedAt and now - ev.presentedAt > MAXAGE ) then
		return;
	end
	local own = ( ev.sourceKind == nil or ev.sourceKind == "player" );
	if ( not own and not G.Opt("dmgPet") ) then
		return;
	end
	local text, base, r, g, b = nil, SIZE_HIT, 1, 1, 1;
	local crit = false;
	if ( G.Opt("dmgCrit") and not ( ev.kind == "damage" and ev.critical ) ) then
		return;                              -- "only critical hits": nothing else, not even the misses
	end
	if ( ev.periodic and not G.Opt("dmgTicks") ) then
		return;                              -- damage over time switched off
	end
	if ( ev.kind == "damage" ) then
		text = NumberText(ev.amount);
		if ( ev.critical ) then
			crit = true;
			base = SIZE_CRIT;               -- bigger, white, with the red blot behind it
			if ( not G.art.custom ) then
				r, g, b = 1, 0.82, 0.25;    -- without the splash texture: golden instead
			end
		elseif ( ev.periodic ) then
			base = SIZE_TICK;
			r, g, b = 0.92, 0.92, 0.94;
		elseif ( not own ) then
			base = SIZE_OTHER;
			r, g, b = 0.84, 0.84, 0.90;
		end
	elseif ( ev.kind == "miss" ) then
		if ( not own ) then
			return;
		end
		text = ( ev.result and ( ev.result.text or ev.result.key ) ) or "Miss";
		text = string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2);
		base = SIZE_MISS;
		r, g, b = 0.74, 0.74, 0.78;
	else
		return;
	end
	if ( table.getn(d.labels) >= MAXLABELS ) then
		if ( not crit ) then
			return;                          -- the screen is full: only crits push the oldest out
		end
		Release(table.remove(d.labels, 1));
	end
	d.n = ( d.n or 0 ) + 1;
	local l = { anchorId = ev.anchorId, born = now, holder = NewLabel(), crit = crit, base = base, size = 0,
		jx = math.mod(d.n * 37, 29) - 14, jy = math.mod(d.n, 3) * 8, r = r, g = g, b = b, own = own };
	if ( ev.periodic ) then
		l.alpha = 0.85;
	else
		l.alpha = 1;
	end
	l.holder.text:SetText(text);
	l.holder.text:SetTextColor(r, g, b);
	if ( crit and G.art.custom ) then
		-- one of the splash drawings, mirrored at random
		local cell = math.mod(d.n, 2);
		local x0, x1 = cell * 0.5, cell * 0.5 + 0.5;
		if ( math.mod(math.floor(d.n / 2), 2) == 1 ) then
			x0, x1 = x1, x0;
		end
		l.holder.splat:SetTexCoord(x0, x1, 0, 1);
		l.holder.splat:SetVertexColor(1, 1, 1, 0.9);
		l.holder.splat:Show();
	else
		l.holder.splat:Hide();
	end
	l.size = 0;
	Style(l, base);
	table.insert(d.labels, l);
end

-- the game's own floating numbers are switched off while ours are on (they come back with /gw2 off)
local NATIVE = { "CombatDamage", "PetMeleeDamage", "PetSpellDamage" };

-- The game's own numbers stay off whenever this UI is on and the combat text API is there, whether ours are
-- shown or not ("Damage numbers" off means none at all); "Game's own damage numbers" brings them back.
function G.ApplyDamage()
	if ( not GetCVar or not SetCVar or not AZSGW2DB ) then
		return;
	end
	local suppress = ( AZSGW2DB.enabled and G.dmg.ok and not G.Opt("dmgNative") ) and true or false;
	AZSGW2DB.cvSaved = AZSGW2DB.cvSaved or {};
	for i = 1, table.getn(NATIVE) do
		local name = NATIVE[i];
		local cur = GetCVar(name);
		if ( suppress ) then
			if ( cur ~= nil and AZSGW2DB.cvSaved[name] == nil ) then
				AZSGW2DB.cvSaved[name] = cur;
			end
			if ( cur ~= nil and cur ~= "0" ) then
				SetCVar(name, "0");
			end
		elseif ( AZSGW2DB.cvSaved[name] ~= nil ) then
			SetCVar(name, AZSGW2DB.cvSaved[name]);
			AZSGW2DB.cvSaved[name] = nil;
		end
	end
	if ( not ( AZSGW2DB.enabled and G.Opt("dmg") and G.dmg.ok ) ) then
		G.ClearDamage();
	end
end

function G.ClearDamage()
	local d = G.dmg;
	for i = table.getn(d.labels), 1, -1 do
		Release(table.remove(d.labels, i));
	end
	d.cursor = nil;
end

-- once per rendered frame, after the camera moved
function G.DamageFrame()
	local d = G.dmg;
	if ( not G.shown or not G.Opt("dmg") ) then
		if ( table.getn(d.labels) > 0 or d.cursor ) then
			G.ClearDamage();
		end
		return;
	end
	local now = GetTime();

	local batch, err = AZS_GetCombatTextEvents(d.cursor);
	if ( err and err.code == "STREAM_CHANGED" ) then
		G.ClearDamage();
		batch, err = AZS_GetCombatTextEvents(nil);
	end
	if ( batch ) then
		d.cursor = batch.cursor;
		local events = batch.events or {};
		local added = 0;
		for i = 1, table.getn(events) do
			if ( added < PERFRAME ) then
				local before = table.getn(d.labels);
				AddLabel(events[i], now);
				if ( table.getn(d.labels) ~= before ) then
					added = added + 1;
				end
			end
		end
	end

	local labels = d.labels;
	local n = table.getn(labels);
	if ( n == 0 ) then
		return;
	end
	local ids = {};
	for i = 1, n do
		ids[i] = labels[i].anchorId;
	end
	local proj = AZS_ProjectCombatTextAnchors(ids, "follow");
	if ( not proj or not proj.entries ) then
		return;
	end
	for i = n, 1, -1 do
		local l = labels[i];
		local e = proj.entries[i];
		local age = now - l.born;
		local gone = ( age >= LIFE );
		if ( e and ( e.state == "expired" or e.state == "unknownAnchor" or e.state == "worldChanged" ) ) then
			gone = true;
		end
		if ( gone ) then
			Release(l);
			table.remove(labels, i);
		elseif ( e and e.state == "onScreen" ) then
			local t = age / LIFE;
			local rise = 1 - (1 - t) * (1 - t);                      -- fast start, slow end
			local up = rise * ( l.crit and RISE_CRIT or RISE_HIT ) + l.jy;
			-- far enemies get smaller numbers: full size within 20 yards, 55% at the farthest
			local k = 1;
			if ( e.playerDistance and e.playerDistance > 20 ) then
				k = math.max(0.55, 20 / e.playerDistance);
			end
			local pop = 1;
			if ( l.crit and age < 0.10 ) then
				pop = 1.2;                                            -- a crit lands a bit bigger
			end
			Style(l, l.base * k * pop);
			local a = l.alpha;
			if ( t > 0.55 ) then
				a = a * (1 - (t - 0.55) / 0.45);
			end
			l.holder:SetAlpha(G.Clamp(a, 0, 1));
			l.holder:ClearAllPoints();
			l.holder:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", e.x + l.jx, e.y + up + 14);
			l.holder:Show();
		else
			l.holder:Hide();
		end
	end
end

function G.BuildDamage()
	if ( not AZS_GetCombatTextCapabilities or not AZS_RegisterCombatTextFrameHandler or not AZS_GetCombatTextEvents ) then
		G.dmg.ok = false;           -- an older game version: the game's own numbers stay
		return;
	end
	G.dmg.ok = true;
	AZS_RegisterCombatTextFrameHandler(function()
		local ok, err = pcall(G.DamageFrame);
		if ( not ok and not G.dmg.failed ) then
			G.dmg.failed = true;
			G.Print("damage numbers error: " .. tostring(err));
		end
	end);
	G.ApplyDamage();
end
