-- AZS GW2 UI: Revive.lua
-- A fallen friend in co-op: "NAME is down! Revive them!" with an arrow that points to the body and the
-- distance, and a marker floating over the body when it is on screen. The data is AZS_GetDownedPartyMembers()
-- (where each friend has to be brought back) and the world anchors API for the marker over the body.

local G = AZSGW2;

local ROWS = 3;
local ROWH = 50;
local W = 400;

G.down = { known = {}, list = {}, anchorOf = {}, tried = {}, catAt = 0 };

function G.BuildRevive()
	local c = CreateFrame("Frame", "AZSGW2Revive", UIParent);
	c:SetWidth(W);
	c:SetHeight(ROWH * ROWS);
	c:SetPoint("CENTER", UIParent, "CENTER", 0, 118);
	c:SetFrameStrata("HIGH");
	G.Register(c, true);
	-- no mouse on the alert: it stands in the middle of the screen, and a frame with the mouse on takes the clicks that are meant
	-- for the world (right click to turn, to interact). /gw2 move still moves it.
	G.Movable(c, "revive", "Ally down alert");
	c:Hide();
	G.reviveFrame = c;

	c.rows = {};
	for i = 1, ROWS do
		local row = CreateFrame("Frame", nil, c);
		row:SetWidth(W);
		row:SetHeight(ROWH - 6);
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(i - 1) * ROWH);
		local bg = G.Solid(row, "BACKGROUND", 0.16, 0.02, 0.03, 0.86);
		bg:SetAllPoints(row);
		G.Edges(row, 0.78, 0.14, 0.12, 1, 1, "BORDER");
		row.arrow = row:CreateTexture(nil, "ARTWORK");
		row.arrow:SetTexture(G.TEXPATH .. "arrows.tga");
		row.arrow:SetWidth(30);
		row.arrow:SetHeight(30);
		row.arrow:SetPoint("LEFT", row, "LEFT", 10, 0);
		row.arrow:SetVertexColor(1, 0.45, 0.35, 1);
		row.title = G.Text(row, 16, "LEFT");
		row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -6);
		row.title:SetWidth(W - 52 - 80);
		row.title:SetHeight(18);
		row.hint = G.Text(row, 10, "LEFT");
		row.hint:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 52, 6);
		row.hint:SetTextColor(0.82, 0.72, 0.72);
		row.hint:SetText("Stand over them to bring them back");
		row.dist = G.Text(row, 15, "RIGHT");
		row.dist:SetPoint("RIGHT", row, "RIGHT", -12, 0);
		row.dist:SetTextColor(1, 0.85, 0.6);
		row:Hide();
		c.rows[i] = row;
	end

	-- markers over the bodies (children of WorldFrame, placed by the world anchors handler)
	G.reviveMarks = {};
	for i = 1, ROWS do
		local m = CreateFrame("Frame", nil, WorldFrame);
		m.azs = true;
		m:SetWidth(2);
		m:SetHeight(2);
		m:SetFrameStrata("HIGH");
		m.arrow = m:CreateTexture(nil, "ARTWORK");
		m.arrow:SetTexture(G.TEXPATH .. "arrows.tga");
		m.arrow:SetWidth(30);
		m.arrow:SetHeight(30);
		m.arrow:SetPoint("BOTTOM", m, "CENTER", 0, -4);
		m.arrow:SetVertexColor(1, 0.40, 0.30, 1);
		G.SetArrow(m.arrow, 3.14159265);           -- pointing down at the body
		m.text = m:CreateFontString(nil, "OVERLAY");
		m.text:SetFont(G.FONT, 13, "OUTLINE");
		m.text:SetJustifyH("CENTER");
		m.text:SetPoint("BOTTOM", m.arrow, "TOP", 0, 2);
		m.text:SetText("");
		m:Hide();
		G.reviveMarks[i] = m;
	end

	if ( AZS_RegisterWorldAnchorFrameHandler and AZS_ProjectWorldAnchors ) then
		AZS_RegisterWorldAnchorFrameHandler(function()
			local ok, err = pcall(G.ReviveWorld);
			if ( not ok and not G.down.failed ) then
				G.down.failed = true;
				G.Print("ally marker error: " .. tostring(err));
			end
		end);
	end
end

local function HideMarks()
	for i = 1, ROWS do
		if ( G.reviveMarks and G.reviveMarks[i] ) then
			G.reviveMarks[i]:Hide();
		end
	end
end

-- once per 0.05 s: who is down, where, and the alert rows
function G.UpdateRevive(dt)
	local c = G.reviveFrame;
	if ( not c ) then
		return;
	end
	local d = G.down;
	if ( not G.shown or not G.Opt("revive") or not AZS_GetDownedPartyMembers ) then
		c:Hide();
		d.list = {};
		HideMarks();
		return;
	end
	local raw = AZS_GetDownedPartyMembers();
	if ( not raw or table.getn(raw) == 0 ) then
		d.known = {};
		d.anchorOf = {};
		d.tried = {};
		d.list = {};
		c:Hide();
		HideMarks();
		return;
	end
	local now = GetTime();
	local p = nil;
	if ( AZS_GetPlayerPosition ) then
		p = AZS_GetPlayerPosition();
	end

	-- the world anchor handles of the fallen: from the entries themselves, or from the catalog (read at most
	-- twice a second, only for a friend whose place is known and whose handle is missing, and a friend the
	-- catalog did not know is asked about again only every three seconds)
	local missing = false;
	for i = 1, table.getn(raw) do
		local e = raw[i];
		local id = tostring(e.id);
		if ( e.anchorId ) then
			d.anchorOf[id] = e.anchorId;
		elseif ( e.positionAvailable and not d.anchorOf[id] and now - ( d.tried[id] or -99 ) > 3 ) then
			missing = true;
		end
	end
	if ( missing and AZS_GetWorldAnchors and now - d.catAt > 0.5 ) then
		d.catAt = now;
		for i = 1, table.getn(raw) do
			d.tried[tostring(raw[i].id)] = now;
		end
		local page = AZS_GetWorldAnchors({ kinds = { "downedPartyMember" } }, nil, 64);
		if ( page and page.entries ) then
			for i = 1, table.getn(page.entries) do
				local e = page.entries[i];
				if ( e.memberId and e.anchorId ) then
					d.anchorOf[tostring(e.memberId)] = e.anchorId;
				end
			end
		end
	end

	local list = {};
	local fresh = false;
	local seen = {};
	for i = 1, table.getn(raw) do
		local e = raw[i];
		local id = tostring(e.id or e.name);
		seen[id] = true;
		local k = d.known[id];
		if ( not k ) then
			k = { born = now };
			d.known[id] = k;
			fresh = true;
		end
		local item = { id = id, name = tostring(e.name or "?"), anchorId = d.anchorOf[tostring(e.id)], born = k.born };
		if ( e.positionAvailable and p and e.spaceId == p.spaceId and e.x ) then
			item.x, item.y = e.x, e.y;
			item.dist = G.Distance(p, e.x, e.y);
			item.rel = G.RelBearing(p, e.x, e.y);
		end
		table.insert(list, item);
	end
	local gone = {};
	for id in pairs(d.known) do
		if ( not seen[id] ) then
			table.insert(gone, id);
		end
	end
	for i = 1, table.getn(gone) do
		d.known[gone[i]] = nil;
		d.anchorOf[gone[i]] = nil;
		d.tried[gone[i]] = nil;
	end
	d.list = list;

	if ( fresh and PlaySound ) then
		pcall(PlaySound, "RaidWarning");
	end

	c:Show();
	local pulse = 0.5 + 0.5 * math.sin(now * 7);
	for i = 1, ROWS do
		local row = c.rows[i];
		local it = list[i];
		if ( it ) then
			row:Show();
			if ( row.key ~= it.name ) then
				row.key = it.name;
				row.title:SetText("|cfff5dc94" .. G.Esc(it.name) .. "|r is down!  |cffff6a58Revive them!|r");
			end
			if ( it.dist ) then
				row.arrow:Show();
				G.SetArrow(row.arrow, it.rel);
				row.dist:SetText(string.format("%d yd", math.floor(it.dist + 0.5)));
			else
				row.arrow:Hide();
				row.dist:SetText("");
			end
			-- the edge flashes for the first four seconds after the fall
			if ( now - it.born < 4 ) then
				G.EdgeColor(row, 0.78 + 0.22 * pulse, 0.14 + 0.45 * pulse, 0.12 + 0.30 * pulse, 1);
			else
				G.EdgeColor(row, 0.78, 0.14, 0.12, 1);
			end
		else
			row:Hide();
			row.key = nil;
		end
	end
end

-- once per rendered frame (world anchors handler): the marker over each body that is on screen
function G.ReviveWorld()
	local d = G.down;
	if ( not G.shown or not G.Opt("revive") or not AZS_ProjectWorldAnchors ) then
		HideMarks();
		return;
	end
	local reqs, who = {}, {};
	for i = 1, table.getn(d.list) do
		local it = d.list[i];
		if ( it.anchorId and table.getn(reqs) < ROWS ) then
			table.insert(reqs, { anchorId = it.anchorId, attachment = "position", offset = { z = 2.2 } });
			table.insert(who, it);
		end
	end
	if ( table.getn(reqs) == 0 ) then
		HideMarks();
		return;
	end
	local res = AZS_ProjectWorldAnchors(reqs);
	if ( not res or not res.entries ) then
		HideMarks();
		return;
	end
	local bob = 4 * math.sin(GetTime() * 5);
	for j = 1, ROWS do
		local m = G.reviveMarks[j];
		local e = res.entries[j];
		if ( who[j] and e and e.state == "onScreen" ) then
			if ( m.key ~= who[j].name ) then
				m.key = who[j].name;
				m.text:SetText("|cfff5dc94" .. G.Esc(who[j].name) .. "|r");
			end
			m:ClearAllPoints();
			m:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", e.x, e.y + bob);
			m:Show();
		else
			m:Hide();
		end
	end
end
