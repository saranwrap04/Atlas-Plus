--[[
    Atlas Plus - main window: instance list, map, legend, loot, item search, settings
    Author: Saranwrap
]]

local AP = AtlasPlus
local W = AP.W
local C = W.C

local UI = { listRows = {}, rows = {}, lootCache = {} }
AP.UI = UI

local FRAME_W, FRAME_H = 1124, 571        -- 19 px under the content: footer text and resize corner
local LIST_W, MAP_S, RIGHT_W = 175, 512, 395
local TOP = 38                         -- content starts under the title bar
local LIST_ROW_H = 18
local ROW_H, ROWS = 20, 20
local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local LIST_MIN, LIST_MAX = 120, 420
local function ListW() return math.max(LIST_MIN, math.min(LIST_MAX, AP.db.listW or LIST_W)) end

---------------------------------------------------------------------------
-- Loot data
---------------------------------------------------------------------------
-- "45100:4.4:h,47241:100:x2,..." -> { {id=, pct=, ...}, ... }
--   h = hard mode, x2 = two at once, l52-56 = creature levels (world drops),
--   e123 / g500 = sold for a cost / for copper, q123 = quest reward, p / f = emblem of the current / a later phase
local function Parse(str)
    local list = {}
    for entry in (str or ""):gmatch("[^,]+") do
        local id, pct, rest = entry:match("^(%d+):([%d%.e%-]+)(.*)$")
        if id then
            local r = { id = tonumber(id), pct = tonumber(pct) or 0 }
            for f in rest:gmatch("[^:]+") do
                local c, v = f:sub(1, 1), f:sub(2)
                if c == "h" then r.hm = true
                elseif c == "x" then r.count = tonumber(v)
                elseif c == "l" then r.lv = v
                elseif c == "e" then r.cost = tonumber(v)
                elseif c == "g" then r.copper = tonumber(v)
                elseif c == "q" then r.quest = tonumber(v)
                elseif c == "p" then r.phase = "now"
                elseif c == "f" then r.phase = "later" end
            end
            list[#list + 1] = r
        end
    end
    return list
end

-- prices: "12 [icon] 2 [icon]", copper as gold / silver / copper
local function Coins(c)
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t" end
    if s > 0 then out[#out + 1] = s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t" end
    if cp > 0 or #out == 0 then out[#out + 1] = cp .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t" end
    return table.concat(out, " ")
end
local function CostParts(d)
    local parts = {}
    if d.copper then
        if d.copper > 0 then parts[1] = { Coins(d.copper), "Gold" } end
        return parts
    end
    local c = d.cost and AtlasPlus_Costs[d.cost]
    if not c then return parts end
    if c[1] > 0 then
        local fac = UnitFactionGroup("player") or "Alliance"
        parts[#parts + 1] = { c[1] .. "|TInterface\\PVPFrame\\PVP-Currency-" .. fac .. ":0|t", "Honor Points" }
    end
    if c[2] > 0 then parts[#parts + 1] = { c[2] .. "|TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:0|t", "Arena Points" } end
    for i = 4, #c, 2 do
        local name = AtlasPlus_Items[c[i]] and AtlasPlus_Items[c[i]][1] or GetItemInfo(c[i]) or ("item " .. c[i])
        parts[#parts + 1] = { c[i + 1] .. "|T" .. (GetItemIcon(c[i]) or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":0|t", name, c[i + 1] }
    end
    return parts, c[3]
end
local function CostText(d)
    local out = {}
    for _, p in ipairs((CostParts(d))) do out[#out + 1] = p[1] end
    return #out > 0 and table.concat(out, " ") or "|cff888888free|r"
end
AP.CostText = CostText

function UI:GetLoot(key, line, mode)
    local ck = key .. ":" .. tostring(line) .. ":" .. tostring(mode)
    if self.lootCache[ck] then return self.lootCache[ck] end
    local m = AtlasPlus_Maps[key]
    local str
    if line == "trash" then
        local t = m and m.mapID and AtlasPlus_Trash[m.mapID]
        str = t and t[mode]
    else
        local l = AtlasPlus_Loot[key] and AtlasPlus_Loot[key][line]
        str = l and l[mode]
    end
    local list = Parse(str)
    self.lootCache[ck] = list
    return list
end

local function HasLoot(key, line)
    if line == "trash" then
        local m = AtlasPlus_Maps[key]
        return m and m.mapID and AtlasPlus_Trash[m.mapID] ~= nil
    end
    return AtlasPlus_Loot[key] and AtlasPlus_Loot[key][line] ~= nil
end

local function ItemInfo(id)
    local d = AtlasPlus_Items[id]
    local name, link, q = GetItemInfo(id)
    q = q or (d and d[2]) or 1
    name = name or (d and d[1]) or ("item " .. id)
    if not link then
        link = (W.QUALITY_HEX[q] or "|cffffffff") .. "|Hitem:" .. id .. ":0:0:0:0:0:0:0:0|h[" .. name .. "]|h|r"
    end
    return name, link, q, d and d[3] or "", d and d[4] or 0, d and d[5]
end
AP.ItemInfo = ItemInfo

local function StripColor(s)
    return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function LineTitle(key, line)
    if line == "trash" then return "Trash mobs" end
    local l = AtlasPlus_Maps[key].lines[line]
    local t = strtrim(StripColor(l and l[1] or ""))
    return (t:gsub("^%w+'?%)%s*", ""))
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
function UI:Create()
    local f = CreateFrame("Frame", "AtlasPlusFrame", UIParent)
    self.frame = f
    W.Size(f, FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    W.Backdrop(f, C.bg)
    f:Hide()
    tinsert(UISpecialFrames, "AtlasPlusFrame")
    f:SetScript("OnShow", function() UI:OnShow() end)
    f:SetScript("OnHide", function() f:StopMovingOrSizing(); UI:SavePosition(); AP.WorldMap:Detach(); UI.lastHide = GetTime() end)

    -- Title bar (drag to move)
    local title = CreateFrame("Frame", nil, f)
    title:SetPoint("TOPLEFT", 1, -1)
    title:SetPoint("TOPRIGHT", -1, -1)
    title:SetHeight(30)
    W.Backdrop(title, C.panel, C.panel)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() if not AP.db.locked then f:StartMoving() end end)
    title:SetScript("OnDragStop", function() f:StopMovingOrSizing(); UI:SavePosition(); AP.WorldMap:Layout() end)
    local line = title:CreateTexture(nil, "BORDER")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(unpack(C.accent))
    line:SetAlpha(0.6)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    local icon = title:CreateTexture(nil, "ARTWORK")
    W.Size(icon, 20, 20)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local tfs = W.Text(title, "GameFontNormal")
    tfs:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    tfs:SetText("|cffffffffAtlas Plus|r")
    local ver = W.Text(title, "GameFontDisableSmall")
    ver:SetPoint("LEFT", tfs, "RIGHT", 6, -1)
    ver:SetText("v" .. AP.VERSION .. "  -  by Saranwrap")

    local close = W.Button(title, "X", 26, 22)
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    local settings = W.Button(title, "Settings", 80, 22)
    settings:SetPoint("RIGHT", close, "LEFT", -4, 0)
    settings:SetScript("OnClick", function() UI:ToggleSettings() end)
    self.settingsBtn = settings

    local search = W.EditBox(title, 230, 22, "Search an instance, a boss or loot...")
    search:SetPoint("RIGHT", settings, "LEFT", -10, 0)

    -- pages
    local worldTab = W.Button(title, "World map", 84, 22)
    worldTab:SetPoint("LEFT", ver, "RIGHT", 18, 1)
    worldTab:SetScript("OnClick", function() UI:BackToWorld() end)
    local instTab = W.Button(title, "Atlas", 84, 22)
    instTab:SetPoint("LEFT", worldTab, "RIGHT", 4, 0)
    instTab:SetScript("OnClick", function() UI:OpenInstance(UI.mapKey or AP.db.lastMap) end)
    self.worldTab, self.instTab = worldTab, instTab
    search:SetScript("OnTextChanged", function(eb)
        local t = eb:GetText() or ""
        if t == "" then eb.placeholder:Show(); eb.clear:Hide() else eb.placeholder:Hide(); eb.clear:Show() end
        UI:OnSearchChanged(t)
    end)
    self.searchBox = search

    -- Content (the world map page is taller: its map fills the width)
    self.worldH = AP.WorldView:Create(f, FRAME_W - LIST_W - 30)
    self:CreateList(f)
    self:CreateMap(f)
    self:CreateRight(f)
    AP.WorldView.panel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -TOP)
    self.worldW = FRAME_W - LIST_W - 10            -- the World map page has no list: the window is narrower

    -- fades to 50% while you move, unless the mouse is over it
    f:SetScript("OnUpdate", function(self, elapsed)
        self.fadeT = (self.fadeT or 0) + elapsed
        if self.fadeT < 0.05 then return end
        self.fadeT = 0
        local base = AP.db.alpha or 1
        local target = base
        if AP.db.fadeMoving and GetUnitSpeed and GetUnitSpeed("player") > 0 and not MouseIsOver(self) then target = base * (AP.db.fadeAlpha or 0.5) end
        local cur = self:GetAlpha()
        if math.abs(cur - target) > 0.01 then self:SetAlpha(cur + (target - cur) * 0.4) else self:SetAlpha(target) end
    end)
    self:CreateGrip(f)

    local foot = W.Text(f, "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 12, 5)
    foot:SetPoint("RIGHT", f, "RIGHT", -24, 0)      -- clear of the resize corner
    foot:SetHeight(12)                               -- one line: stays inside the bottom strip
    foot:SetJustifyH("LEFT")
    self.foot = foot

    self:CreateSettings(f)
    self:ApplyLayout()
end

-- position saved as the top left corner in screen units, so it stays put when the size changes
function UI:SavePosition()
    local f = self.frame
    if not (f and f:GetLeft()) then return end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    AP.db.pos = { left = f:GetLeft() * s, top = f:GetTop() * s }
end

function UI:ApplyLayout()
    local f = self.frame
    if not f then return end
    local scale = AP.db.scale or 1
    f:SetScale(scale)
    f:SetAlpha(AP.db.alpha or 1)
    f:ClearAllPoints()
    local p = AP.db.pos
    if p and p.left then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left / scale, p.top / scale)
    else
        f:SetPoint("CENTER")
    end
    if AP.WorldMap then AP.WorldMap:Layout() end
end

-- bottom right corner: drag to resize the window (keeps its shape)
function UI:CreateGrip(f)
    local g = CreateFrame("Button", nil, f)
    W.Size(g, 16, 16)
    g:SetPoint("BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(f:GetFrameLevel() + 30)
    for i = 0, 2 do
        local d = g:CreateTexture(nil, "OVERLAY")
        d:SetTexture("Interface\\Buttons\\WHITE8X8")
        d:SetVertexColor(0.6, 0.6, 0.6, 0.8)
        W.Size(d, 2, 2)
        d:SetPoint("BOTTOMRIGHT", -(i * 4) - 2, 2)
        local e = g:CreateTexture(nil, "OVERLAY")
        e:SetTexture("Interface\\Buttons\\WHITE8X8")
        e:SetVertexColor(0.6, 0.6, 0.6, 0.8)
        W.Size(e, 2, 2)
        e:SetPoint("BOTTOMRIGHT", -2, (i * 4) + 2)
    end
    g:SetScript("OnEnter", function(self) W.Tip(self, "Resize", "Drag to make the window bigger or smaller.") end)
    g:SetScript("OnLeave", function() GameTooltip:Hide() end)
    g:SetScript("OnMouseDown", function(self)
        UI:SavePosition()
        local ui = UIParent:GetEffectiveScale()
        local x = GetCursorPosition() / ui
        self.startX, self.startScale = x, AP.db.scale or 1
        self.startW = FRAME_W * self.startScale
        self:SetScript("OnUpdate", function(s)
            -- button released elsewhere (or the window closed meanwhile): stop resizing
            if not IsMouseButtonDown("LeftButton") then s:SetScript("OnUpdate", nil); UI:SavePosition() return end
            local cx = GetCursorPosition() / ui
            local w = math.max(FRAME_W * 0.5, math.min(FRAME_W * 1.6, s.startW + (cx - s.startX)))
            AP.db.scale = math.floor(w / FRAME_W * 100 + 0.5) / 100
            UI:ApplyLayout()
        end)
    end)
    g:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil); UI:SavePosition() end)
    g:SetScript("OnHide", function(self) if self:GetScript("OnUpdate") then self:SetScript("OnUpdate", nil); UI:SavePosition() end end)
end

---------------------------------------------------------------------------
-- Instance list (left)
---------------------------------------------------------------------------
local CAT_SHORT = {
    ["Wrath of the Lich King Dungeons"] = "Wrath Dungeons", ["Wrath of the Lich King Raids"] = "Wrath Raids",
}

function UI:CreateList(f)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", 10, -TOP)
    W.Size(panel, ListW(), MAP_S)
    W.Backdrop(panel, C.panel)
    self.listPanel = panel

    -- the bar between the list and the map: drag it to make the list wider or narrower
    -- (a child of the list: it hides, moves and fades with it)
    local bar = CreateFrame("Button", nil, panel)
    bar:SetPoint("TOPLEFT", panel, "TOPRIGHT", 1, 0)
    bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 1, 0)
    bar:SetWidth(8)
    bar:SetFrameLevel(panel:GetFrameLevel() + 5)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(C.line[1], C.line[2], C.line[3], 0.6)
    line:SetWidth(2)
    line:SetPoint("TOP", 0, -4)
    line:SetPoint("BOTTOM", 0, 4)
    local dots = {}
    for i = -1, 1 do
        local d = bar:CreateTexture(nil, "OVERLAY")
        d:SetTexture("Interface\\Buttons\\WHITE8X8")
        d:SetVertexColor(C.line[1], C.line[2], C.line[3], 1)
        W.Size(d, 4, 4)
        d:SetPoint("CENTER", 0, i * 8)
        dots[#dots + 1] = d
    end
    local function Paint(on)
        local c = on and C.accent or C.line
        line:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
        for _, d in ipairs(dots) do d:SetVertexColor(c[1], c[2], c[3], 1) end
    end
    bar:SetScript("OnEnter", function(b)
        Paint(true)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag: list wider or narrower", 1, 1, 1)
        GameTooltip:AddLine("Right-click: back to the first width", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function(b) if not b.dragging then Paint(false) end GameTooltip:Hide() end)
    bar:RegisterForClicks("RightButtonUp")
    bar:SetScript("OnClick", function() UI:SetListWidth(LIST_W) end)
    bar:SetScript("OnMouseDown", function(b, button)
        if button ~= "LeftButton" then return end
        b.dragging = true
        b.x0, b.w0 = GetCursorPosition(), ListW()
        b.sc = b:GetEffectiveScale()
        b:SetScript("OnUpdate", function(s)
            -- the button was let go somewhere else (over the map, another window): the drag ends
            if not IsMouseButtonDown("LeftButton") then s:GetScript("OnMouseUp")(s) return end
            local x = GetCursorPosition()
            UI:SetListWidth(s.w0 + (x - s.x0) / s.sc)
        end)
    end)
    local function StopDrag(b)
        if b.dragging then
            b.dragging = nil
            b:SetScript("OnUpdate", nil)
        end
        if not (b:IsVisible() and b:IsMouseOver()) then
            Paint(false)
            if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
        end
    end
    bar:SetScript("OnMouseUp", StopDrag)
    bar:SetScript("OnHide", StopDrag)
    self.listBar = bar

    local maxRows = math.floor((math.max(self.worldH, MAP_S + 2) - 4) / LIST_ROW_H)
    self.listVisible = math.floor((MAP_S + 2 - 4) / LIST_ROW_H)
    for i = 1, maxRows do
        local row = CreateFrame("Button", nil, panel)
        row:SetHeight(LIST_ROW_H)
        row:SetPoint("TOPLEFT", 1, -2 - (i - 1) * LIST_ROW_H)
        row:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
        local sel = row:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.25)
        sel:Hide()
        row.sel = sel
        local fs = W.Text(row, "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        row.fs = fs
        row:SetScript("OnClick", function(r)
            local e = r.entry
            if not e then return end
            if e.cat then
                AP.db.collapsed[e.cat] = not AP.db.collapsed[e.cat] or nil
                UI:RefreshList()
            else
                UI:OpenInstance(e.key)
            end
        end)
        row:SetScript("OnEnter", function(r)
            local e = r.entry
            if not (e and e.key) then return end
            local m = AtlasPlus_Maps[e.key]
            GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.full or m.name, 1, 1, 1)
            if m.lvl then GameTooltip:AddLine("Level " .. m.lvl .. (m.players and ("  -  " .. m.players .. " players") or ""), 0.8, 0.8, 0.8) end
            if m.loc then GameTooltip:AddLine(m.loc, 0.8, 0.8, 0.8) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.listRows[i] = row
    end
    local sf = CreateFrame("ScrollFrame", "AtlasPlusListScroll", panel, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -2)
    sf:SetPoint("BOTTOMRIGHT", -14, 2)
    sf:SetScript("OnVerticalScroll", function(s, offset)
        FauxScrollFrame_OnVerticalScroll(s, offset, LIST_ROW_H, function() UI:RefreshList() end)
    end)
    W.FlatScroll(sf)
    self.listScroll = sf
end

function UI:ListEntries()
    local out = {}
    for _, cat in ipairs(AP.CATEGORIES) do
        local keys = AP.byCategory[cat]
        if keys and #keys > 0 then
            out[#out + 1] = { cat = cat }
            if not AP.db.collapsed[cat] then
                for _, k in ipairs(keys) do out[#out + 1] = { key = k } end
            end
        end
    end
    return out
end

-- width of the instance list (the window grows or shrinks with it)
function UI:SetListWidth(w)
    w = math.floor(math.max(LIST_MIN, math.min(LIST_MAX, w)) + 0.5)
    if w == ListW() and self.listPanel:GetWidth() == w then return end
    AP.db.listW = w
    self.listPanel:SetWidth(w)
    if self.page == "instance" then self.frame:SetWidth(FRAME_W + w - LIST_W) end
end

function UI:RefreshList()
    local entries = self:ListEntries()
    self.listEntries = entries
    local visible = self.listVisible
    FauxScrollFrame_Update(self.listScroll, #entries, visible, LIST_ROW_H)
    local off = FauxScrollFrame_GetOffset(self.listScroll)
    for i, row in ipairs(self.listRows) do
        local e = i <= visible and entries[off + i] or nil
        row.entry = e
        if e then
            if e.cat then
                local open = not AP.db.collapsed[e.cat]
                row.fs:SetText(AP.ACCENT .. (open and "-  " or "+  ") .. (CAT_SHORT[e.cat] or e.cat) .. "|r")
                row.fs:SetFontObject("GameFontNormalSmall")
                row.sel:Hide()
            else
                local m = AtlasPlus_Maps[e.key]
                local lvl = m.lvl and ("|cff888888 " .. m.lvl .. "|r") or ""
                row.fs:SetFontObject("GameFontHighlightSmall")
                row.fs:SetText("   " .. m.name .. lvl)
                if e.key == self.mapKey and self.page == "instance" then row.sel:Show() else row.sel:Hide() end
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

-- scroll the list so the selected map is visible (and its category open)
function UI:RevealInList(key)
    local cat = AtlasPlus_Maps[key].cat
    if AP.db.collapsed[cat] then self:RefreshList() return end
    local entries = self:ListEntries()
    for i, e in ipairs(entries) do
        if e.key == key then
            local off = FauxScrollFrame_GetOffset(self.listScroll)
            if i <= off or i > off + self.listVisible then
                local newOff = math.max(0, math.min(i - 4, #entries - self.listVisible))
                FauxScrollFrame_SetOffset(self.listScroll, newOff)
                self.listScroll:SetVerticalScroll(newOff * LIST_ROW_H)
            end
            break
        end
    end
    self:RefreshList()
end

---------------------------------------------------------------------------
-- Map (center)
---------------------------------------------------------------------------
function UI:CreateMap(f)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("TOPLEFT", self.listPanel, "TOPRIGHT", 10, 0)
    W.Size(holder, MAP_S + 2, MAP_S + 2)
    W.Backdrop(holder, C.inset)
    local tex = holder:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    W.Size(tex, MAP_S, MAP_S)
    self.mapTex = tex
    self.mapHolder = holder
    -- pages without a map (world drops, events, vendors): what the page is about
    local info = CreateFrame("Frame", nil, holder)
    info:SetAllPoints()
    local big = info:CreateTexture(nil, "ARTWORK")
    W.Size(big, 64, 64)
    big:SetPoint("TOP", 0, -120)
    big:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local title = W.Text(info, "GameFontNormalLarge")
    title:SetPoint("TOP", big, "BOTTOM", 0, -14)
    title:SetWidth(MAP_S - 60)
    local body = W.Text(info, "GameFontHighlight")
    body:SetPoint("TOP", title, "BOTTOM", 0, -12)
    body:SetWidth(MAP_S - 80)
    body:SetSpacing(3)
    local count = W.Text(info, "GameFontDisable")
    count:SetPoint("TOP", body, "BOTTOM", 0, -14)
    count:SetWidth(MAP_S - 80)
    info.icon, info.title, info.body, info.count = big, title, body, count
    info:Hide()
    self.mapInfo = info
    -- right-click on the instance map: back to the world map
    holder:EnableMouse(true)
    holder:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then UI:BackToWorld() end end)
    self.listPanel:SetHeight(MAP_S + 2)
end

---------------------------------------------------------------------------
-- Right panel: header, modes, legend / loot / search rows
---------------------------------------------------------------------------
local function CreateRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", parent, "RIGHT", -15, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetTexture(1, 1, 1, (i % 2 == 0) and 0.025 or 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
    row.hl = hl
    local icon = row:CreateTexture(nil, "ARTWORK")
    W.Size(icon, 16, 16)
    icon:SetPoint("LEFT", 5, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon = icon
    local left = W.Text(row, "GameFontHighlightSmall")
    left:SetHeight(ROW_H)
    left:SetJustifyH("LEFT")
    row.left = left
    local right = W.Text(row, "GameFontHighlightSmall")
    right:SetPoint("RIGHT", -6, 0)
    right:SetHeight(ROW_H)
    right:SetJustifyH("RIGHT")
    row.right = right
    local mid = W.Text(row, "GameFontDisableSmall")
    mid:SetHeight(ROW_H)
    mid:SetJustifyH("LEFT")
    row.mid = mid
    row:SetScript("OnClick", function(r, button) UI:OnRowClick(r, button) end)
    row:SetScript("OnEnter", function(r) UI:OnRowEnter(r) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

-- layout of one row: "legend" (text only), "item" (icon, name, type, chance), "result" (icon, name, where)
local function LayoutRow(row, kind, width, rightW)
    row.left:ClearAllPoints(); row.mid:ClearAllPoints()
    if kind == "legend" or kind == "group" then
        row.icon:Hide()
        row.left:SetPoint("LEFT", 6, 0)
        row.left:SetWidth(width - 60)
        row.mid:Hide()
        row.right:SetWidth(50)
    elseif kind == "item" then
        rightW = rightW or 44
        row.icon:Show()
        row.left:SetPoint("LEFT", 27, 0)
        local nameW = math.floor((width - 27 - rightW - 2) * 0.58)
        row.left:SetWidth(nameW)
        row.mid:Show()
        row.mid:SetPoint("LEFT", 27 + nameW + 6, 0)
        row.mid:SetWidth(width - 27 - nameW - 6 - rightW - 6)
        row.right:SetWidth(rightW)
    else -- result
        row.icon:Show()
        row.left:SetPoint("LEFT", 27, 0)
        local nameW = math.floor((width - 27 - 10) * 0.5)
        row.left:SetWidth(nameW)
        row.mid:Show()
        row.mid:SetPoint("LEFT", 27 + nameW + 6, 0)
        row.mid:SetWidth(width - 27 - nameW - 12)
        row.right:SetWidth(1)
    end
end

function UI:CreateRight(f)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", self.mapHolder, "TOPRIGHT", 10, 0)
    W.Size(panel, RIGHT_W, MAP_S + 2)
    self.right = panel
    panel:EnableMouse(true)
    panel:SetScript("OnMouseUp", function(_, button) if button == "RightButton" and UI.view == "loot" then UI:Back() end end)

    -- header
    local name = W.Text(panel, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", 4, -2)
    name:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 1, 1)
    self.hName = name
    local info = W.Text(panel, "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    info:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    info:SetJustifyH("LEFT")
    self.hInfo = info
    local loc = W.Text(panel, "GameFontDisableSmall")
    loc:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -3)
    loc:SetPoint("RIGHT", panel, "RIGHT", -100, 0)
    loc:SetJustifyH("LEFT")
    self.hLoc = loc
    local ent = W.Button(panel, "Entrance", 90, 18)
    ent:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -34)
    ent:SetScript("OnClick", function(b) UI:GoEntrance(b) end)
    self.entBtn = ent

    -- modes
    self.modeBtns = {}
    for i = 1, 4 do
        local b = W.Button(panel, "", 60, 20)
        if i == 1 then b:SetPoint("TOPLEFT", 0, -56) else b:SetPoint("LEFT", self.modeBtns[i - 1], "RIGHT", 4, 0) end
        b:SetScript("OnClick", function(btn) UI:SetMode(btn.mode) end)
        self.modeBtns[i] = b
    end
    local back = W.Button(panel, "< Back", 64, 20)
    back:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -56)
    back:SetScript("OnClick", function() UI:Back() end)
    self.backBtn = back

    -- sub title (boss name in loot view, result count in search)
    local sub = W.Text(panel, "GameFontNormal")
    sub:SetPoint("TOPLEFT", 2, -82)
    sub:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    sub:SetJustifyH("LEFT")
    self.sub = sub

    -- rows
    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", 0, -100)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    W.Backdrop(list, C.panel)
    self.rowPanel = list
    for i = 1, ROWS do self.rows[i] = CreateRow(list, i) end
    local sf = CreateFrame("ScrollFrame", "AtlasPlusRowScroll", list, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -1)
    sf:SetPoint("BOTTOMRIGHT", -15, 1)
    sf:SetScript("OnVerticalScroll", function(s, offset)
        FauxScrollFrame_OnVerticalScroll(s, offset, ROW_H, function() UI:RefreshRows() end)
    end)
    W.FlatScroll(sf)
    self.rowScroll = sf
    local empty = W.Text(list, "GameFontDisableSmall")
    empty:SetPoint("CENTER")
    empty:SetWidth(RIGHT_W - 40)
    self.empty = empty
end

---------------------------------------------------------------------------
-- Selection
---------------------------------------------------------------------------
function UI:ModeFor(key)
    local m = AtlasPlus_Maps[key]
    if not (m and m.modes) then return nil end
    local saved = AP.db.modes[key]
    for _, md in ipairs(m.modes) do if md == saved then return saved end end
    return m.modes[1]
end

function UI:SelectMap(key, keepView)
    local m = AtlasPlus_Maps[key]
    if not m then return end
    self.mapKey = key
    AP.db.lastMap = key
    self.mode = self:ModeFor(key)
    if not keepView then
        self.view, self.lootLine = "legend", nil
        if self.searchBox:GetText() ~= "" then self.searchBox:SetText("") end
    end
    if m.nomap then
        self.mapTex:Hide()
        local info = self.mapInfo
        info.icon:SetTexture(AP.CAT_ICON[m.cat] or ICON)
        info.title:SetText(m.full or m.name)
        info.body:SetText(m.info or "")
        local n, items = 0, 0
        for _, modes in pairs(AtlasPlus_Loot[key] or {}) do
            n = n + 1
            for _, str in pairs(modes) do for _ in str:gmatch("[^,]+") do items = items + 1 end end
        end
        info.count:SetText(n .. " list" .. (n == 1 and "" or "s") .. ", " .. items .. " item" .. (items == 1 and "" or "s"))
        info:Show()
    else
        self.mapInfo:Hide()
        self.mapTex:Show()
        self.mapTex:SetTexture(AP.MAPS .. key)
    end
    FauxScrollFrame_SetOffset(self.rowScroll, 0)
    self.rowScroll:SetVerticalScroll(0)
    self:RevealInList(key)
    self:RefreshRight()
end

-- pages: the instance map (list + map + legend) or the world map (list + world map)
function UI:SetPage(page)
    self.page = page
    local inst = page == "instance"
    local h = inst and (MAP_S + 2) or self.worldH
    self.frame:SetHeight(FRAME_H + h - (MAP_S + 2))
    self.frame:SetWidth(inst and (FRAME_W + ListW() - LIST_W) or self.worldW)
    self.listPanel:SetHeight(MAP_S + 2)
    self.listVisible = math.floor((MAP_S + 2 - 4) / LIST_ROW_H)
    if inst then
        AP.WorldMap:Detach()
        self.listPanel:Show(); self.mapHolder:Show(); self.right:Show(); AP.WorldView.panel:Hide()
    else
        self.listPanel:Hide(); self.mapHolder:Hide(); self.right:Hide(); AP.WorldView.panel:Show()
        self.foot:SetText("")
        AP.WorldMap:Attach()
    end
    self.worldTab:SetSelected(not inst)
    self.instTab:SetSelected(inst)
    self:RefreshList()
end

function UI:OpenInstance(key)
    if not self.frame:IsShown() then self.opening = true; self.frame:Show(); self.opening = nil end
    self:SetPage("instance")
    self:SelectMap(key)
end

function UI:ShowWorld(keepMap)
    if not self.frame:IsShown() then self.opening = true; self.frame:Show(); self.opening = nil end
    self:SetPage("world")
    if not keepMap then SetMapToCurrentZone() end
end

-- the world map as it was before an instance was opened
function UI:BackToWorld()
    AP.WorldMap.restore = true
    self:ShowWorld(true)
end

function UI:SetMode(mode)
    self.mode = mode
    AP.db.modes[self.mapKey] = mode
    self:RefreshRight()
end

function UI:OpenLoot(line)
    self.view, self.lootLine = "loot", line
    FauxScrollFrame_SetOffset(self.rowScroll, 0)
    self.rowScroll:SetVerticalScroll(0)
    self:RefreshRight()
end

function UI:Back()
    if self.view == "loot" and self.fromSearch then
        self.view = "search"
        self.fromSearch = nil
    else
        self.view = "legend"
        self.fromSearch = nil
    end
    FauxScrollFrame_SetOffset(self.rowScroll, 0)
    self.rowScroll:SetVerticalScroll(0)
    self:RefreshRight()
end

function UI:GoEntrance(btn)
    local A = AtlasPlus_Assoc
    local key = self.mapKey
    local ents = A.instToEnt[key]
    if ents and ents[1] then self:SelectMap(ents[1]) return end
    -- entrance map: back to an instance of it
    local insts = A.entToInst[key]
    if insts then
        local menu = { { text = "Instances", isTitle = true, notCheckable = true } }
        for _, k in ipairs(insts) do
            local m = AtlasPlus_Maps[k]
            if m then menu[#menu + 1] = { text = m.name, notCheckable = true, func = function() UI:SelectMap(k) end } end
        end
        W.ShowMenu(menu, btn)
    end
end

---------------------------------------------------------------------------
-- Right panel content
---------------------------------------------------------------------------
function UI:RefreshHeader()
    local key = self.mapKey
    local m = AtlasPlus_Maps[key]
    self.hName:SetText(m.name)
    local bits = {}
    if m.lvl then bits[#bits + 1] = "Level " .. m.lvl end
    if m.minlvl then bits[#bits + 1] = "min. " .. m.minlvl end
    if m.players then bits[#bits + 1] = m.players .. " players" end
    if m.nomap then bits[#bits + 1] = "|cff888888" .. m.cat .. "|r" end
    if m.acr and m.acr ~= "" then bits[#bits + 1] = "|cff888888" .. m.acr .. "|r" end
    self.hInfo:SetText(table.concat(bits, "   "))
    local hub = m.full and m.full:match("^(.-):") or nil
    local locText = m.loc and ("Location: " .. m.loc) or ""
    if hub and hub ~= m.name then locText = hub .. (locText ~= "" and ("  -  " .. locText) or "") end
    self.hLoc:SetText(locText)

    local A = AtlasPlus_Assoc
    if A.instToEnt[key] then
        self.entBtn:SetText("Entrance map"); self.entBtn:Show()
    elseif A.entToInst[key] then
        self.entBtn:SetText("Instances"); self.entBtn:Show()
    else
        self.entBtn:Hide()
    end
end

function UI:RefreshModes()
    local m = AtlasPlus_Maps[self.mapKey]
    local modes = (self.view ~= "search") and m.modes or nil
    local show = modes and #modes > 1 and AtlasPlus_Loot[self.mapKey] ~= nil
    for i, b in ipairs(self.modeBtns) do
        local md = show and modes[i]
        if md then
            b.mode = md
            b:SetText(AP.MODE_LABEL[md] or md)
            b:SetWidth((md == "N" or md == "H") and 64 or (#md > 2 and 80 or 44))
            b:SetSelected(md == self.mode)
            b:Show()
        else
            b:Hide()
        end
    end
    if self.view == "legend" then self.backBtn:Hide() else self.backBtn:Show() end
end

-- class loot: folded lists per class (like the instance list)
local CLASS_BITS = {
    { "WARRIOR", 1 }, { "PALADIN", 2 }, { "HUNTER", 4 }, { "ROGUE", 8 }, { "PRIEST", 16 },
    { "DEATHKNIGHT", 32 }, { "SHAMAN", 64 }, { "MAGE", 128 }, { "WARLOCK", 256 }, { "DRUID", 1024 },
}
local CLASS_LABEL = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local CLASS_GROUP_MIN = 6      -- fewer class items than this: they stay in the main list

local function ClassMask(id)
    local d = AtlasPlus_Items[id]
    return d and d[6] or 0
end

function UI:GroupOpen(gk)
    self.groupOpen = self.groupOpen or {}
    local v = self.groupOpen[gk]
    if v == nil then
        -- your own class starts open
        local _, mine = UnitClass("player")
        return gk == "class:" .. (mine or "")
    end
    return v
end

function UI:ToggleGroup(gk)
    self.groupOpen = self.groupOpen or {}
    self.groupOpen[gk] = not self:GroupOpen(gk)
    self:RefreshRight()
end

function UI:LootRows(list)
    local rows, main, byClass, nClass = {}, {}, {}, 0
    for _, r in ipairs(list) do
        local cm = ClassMask(r.id)
        if cm > 0 then
            nClass = nClass + 1
            for _, c in ipairs(CLASS_BITS) do
                if bit.band(cm, c[2]) ~= 0 then
                    byClass[c[1]] = byClass[c[1]] or {}
                    table.insert(byClass[c[1]], r)
                end
            end
        else
            main[#main + 1] = r
        end
    end
    local function item(r)
        return { kind = "item", id = r.id, pct = r.pct, hm = r.hm, count = r.count, lv = r.lv, cost = r.cost,
                 copper = r.copper, quest = r.quest, phase = r.phase }
    end
    if nClass < CLASS_GROUP_MIN then
        -- a few class items: in the main list, in drop order
        main = {}
        for _, r in ipairs(list) do main[#main + 1] = r end
        byClass = {}
    end
    for _, r in ipairs(main) do rows[#rows + 1] = item(r) end
    for _, c in ipairs(CLASS_BITS) do
        local l = byClass[c[1]]
        if l then
            local gk = "class:" .. c[1]
            local open = self:GroupOpen(gk)
            local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c[1]]
            local hex = col and string.format("|cff%02x%02x%02x", col.r * 255, col.g * 255, col.b * 255) or "|cffffffff"
            rows[#rows + 1] = { kind = "group", gk = gk, open = open,
                text = (open and "- " or "+ ") .. hex .. CLASS_LABEL[c[1]] .. "|r |cff888888(" .. #l .. ")|r" }
            if open then for _, r in ipairs(l) do rows[#rows + 1] = item(r) end end
        end
    end
    return rows
end

-- rows for the current view
function UI:BuildRows()
    local key, rows = self.mapKey, {}
    local m = AtlasPlus_Maps[key]
    if self.view == "legend" then
        for i, l in ipairs(m.lines) do
            rows[#rows + 1] = { kind = "legend", line = i, text = l[1], type = l[2], id = l[3], loot = HasLoot(key, i) }
        end
        if m.cat ~= "Entrances" and m.cat ~= "Dungeon Locations" and HasLoot(key, "trash") then
            rows[#rows + 1] = { kind = "legend", line = "trash", text = "|cff999999Trash mobs|r", loot = true }
        end
    elseif self.view == "loot" then
        rows = self:LootRows(self:GetLoot(key, self.lootLine, self.mode))
    elseif self.view == "search" then
        rows = self.results or {}
    end
    return rows
end

function UI:RefreshRight()
    if not self.mapKey then return end
    self:RefreshHeader()
    self:RefreshModes()
    local m = AtlasPlus_Maps[self.mapKey]
    if self.view == "loot" then
        local t = LineTitle(self.mapKey, self.lootLine)
        self.sub:SetText(t .. (m.nomap and "" or ("  |cff888888" .. (AP.MODE_LABEL[self.mode] or "") .. "|r")))
    elseif self.view == "search" then
        local f = self.found or { places = 0, bosses = 0, items = #(self.results or {}) }
        local parts = {}
        if f.places > 0 then parts[#parts + 1] = f.places .. " instance" .. (f.places == 1 and "" or "s") end
        if f.bosses > 0 then parts[#parts + 1] = f.bosses .. " boss" .. (f.bosses == 1 and "" or "es") end
        parts[#parts + 1] = f.items .. " item" .. (f.items == 1 and "" or "s") .. (self.resultsCapped and " (first 200)" or "")
        self.sub:SetText(table.concat(parts, ", ") .. " found")
    else
        local hasLoot = AtlasPlus_Loot[self.mapKey] ~= nil
        self.sub:SetText(hasLoot and ("|cff888888Click " .. (m.nomap and "a list" or "a boss") .. " (|r" .. AP.ACCENT .. ">|r|cff888888) to see its " ..
            (m.nomap and "items" or "loot") .. "|r") or "")
    end
    self.rowData = self:BuildRows()
    self:RefreshRows()
    if self.view == "search" then
        self.foot:SetText("Click a result to open its boss.  Shift-click: link in chat.  Ctrl-click: try on.")
    elseif self.view == "loot" and m.cat == "Vendors" then
        self.foot:SetText("Prices from the game data.  What a vendor sells can depend on the server's phase.  Shift-click: link.  Ctrl-click: try on.")
    elseif self.view == "loot" and m.cat == "World Drops" then
        self.foot:SetText("Chances per kill, for a typical creature of the level (AzerothCore database).  Lx-y = creature levels.  Shift-click: link.")
    elseif self.view == "loot" then
        self.foot:SetText("Drop chances from the AzerothCore database (the server can differ).  HM = hard mode.  " ..
            "|cff4a9effA|r / |cffff4a4aH|r = Alliance / Horde only.  Shift-click: link.  Ctrl-click: try on.")
    else
        self.foot:SetText("")
    end
end

local FACTION_TAG = { A = " |cff4a9effA|r", H = " |cffff4a4aH|r" }
local function PctText(p)
    if p >= 100 then return "|cff4cd964100%|r" end
    local c = p >= 20 and "|cffffffff" or (p >= 5 and "|cffcccccc" or "|cff999999")
    return c .. p .. "%|r"
end

function UI:RefreshRows()
    local data = self.rowData or {}
    FauxScrollFrame_Update(self.rowScroll, #data, ROWS, ROW_H)
    local off = FauxScrollFrame_GetOffset(self.rowScroll)
    local width = RIGHT_W - 17
    for i, row in ipairs(self.rows) do
        local d = data[off + i]
        row.data = d
        if d then
            LayoutRow(row, d.kind, width, (d.cost or d.copper) and 120 or (d.quest and 50) or nil)
            if d.kind == "group" then
                row.left:SetText(d.text)
                row.right:SetText("")
                row.hl:Show()
            elseif d.kind == "legend" then
                row.left:SetText(d.text or "")
                row.right:SetText(d.loot and (AP.ACCENT .. "loot >|r") or "")
                local clickable = d.loot or (d.type == 1 and d.id and AP.byArea[d.id])
                if clickable then row.hl:Show() else row.hl:Hide() end
            elseif d.kind == "item" then
                local name, _, q, typ, _, fac = ItemInfo(d.id)
                row.icon:SetTexture(GetItemIcon(d.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.left:SetText((d.count and ("|cffffffff" .. d.count .. "x|r ") or "") .. (W.QUALITY_HEX[q] or "") .. name .. "|r" .. (FACTION_TAG[fac or ""] or "") .. (d.hm and " |cffff8040HM|r" or "") or "")
                local mid = typ
                if d.phase == "now" then mid = "|cff4cd964current phase|r"
                elseif d.phase == "later" then mid = "|cff888888later phase|r"
                elseif d.lv then mid = typ .. " |cff888888L" .. d.lv .. "|r" end
                row.mid:SetText(mid)
                if d.cost or d.copper then row.right:SetText(CostText(d))
                elseif d.quest then row.right:SetText("|cffffd100Quest|r")
                else row.right:SetText(PctText(d.pct)) end
                row.hl:Show()
            elseif d.kind == "place" or d.kind == "boss" then
                row.icon:SetTexture(d.kind == "place" and ICON or "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
                row.left:SetText(AP.ACCENT .. d.text .. "|r")
                row.mid:SetText(d.where)
                row.right:SetText("")
                row.hl:Show()
            else
                local name, _, q = ItemInfo(d.id)
                row.icon:SetTexture(GetItemIcon(d.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.left:SetText((W.QUALITY_HEX[q] or "") .. name .. "|r")
                row.mid:SetText(d.where)
                row.right:SetText("")
                row.hl:Show()
            end
            row:Show()
        else
            row:Hide()
        end
    end
    if #data == 0 then
        if self.view == "search" then
            self.empty:SetText((self.searchText or ""):len() < 2 and "Type at least 2 letters." or "Nothing found.")
        elseif self.view == "loot" then
            self.empty:SetText("No loot for this mode.")
        else
            self.empty:SetText("")
        end
        self.empty:Show()
    else
        self.empty:Hide()
    end
end

---------------------------------------------------------------------------
-- Row interaction
---------------------------------------------------------------------------
function UI:OnRowClick(row, button)
    -- right-click in a loot list: back to the bosses (or the search results)
    if button == "RightButton" and self.view == "loot" then self:Back() return end
    local d = row.data
    if not d then return end
    if d.kind == "group" then self:ToggleGroup(d.gk) return end
    if d.kind == "legend" then
        if d.loot then
            self:OpenLoot(d.line)
        elseif d.type == 1 and d.id and AP.byArea[d.id] then
            self:SelectMap(AP.byArea[d.id])
        elseif d.type == 3 and d.id and IsShiftKeyDown() then
            local _, link = ItemInfo(d.id)
            ChatEdit_InsertLink(link)
        end
        return
    end
    if d.kind == "place" then
        self:OpenInstance(d.key)
        return
    end
    if d.kind == "boss" then
        local from = { results = self.results, text = self.searchText, found = self.found }
        self:SelectMap(d.key, true)
        self.view, self.lootLine, self.fromSearch = "loot", d.line, from
        FauxScrollFrame_SetOffset(self.rowScroll, 0)
        self.rowScroll:SetVerticalScroll(0)
        self:RefreshRight()
        return
    end
    local _, link = ItemInfo(d.id)
    if IsControlKeyDown() and DressUpItemLink then DressUpItemLink(link) return end
    if IsShiftKeyDown() then ChatEdit_InsertLink(link) return end
    if d.kind == "result" then
        local from = { results = self.results, text = self.searchText }
        self.mode = d.mode
        AP.db.modes[d.key] = d.mode
        self:SelectMap(d.key, true)
        self.view, self.lootLine, self.fromSearch = "loot", d.line, from
        FauxScrollFrame_SetOffset(self.rowScroll, 0)
        self.rowScroll:SetVerticalScroll(0)
        self:RefreshRight()
    end
end

function UI:OnRowEnter(row)
    local d = row.data
    if not d then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if d.kind == "legend" then
        if d.type == 3 and d.id then
            GameTooltip:SetHyperlink("item:" .. d.id)
        else
            GameTooltip:AddLine(strtrim(StripColor(d.text)), 1, 1, 1)
            if d.loot then GameTooltip:AddLine("Click: see its loot", 0.6, 0.6, 0.6)
            elseif d.type == 1 and d.id and AP.byArea[d.id] then GameTooltip:AddLine("Click: open this map", 0.6, 0.6, 0.6) end
        end
        GameTooltip:Show()
        return
    end
    if d.kind == "group" then
        GameTooltip:AddLine("Items for this class", 1, 1, 1)
        GameTooltip:AddLine(d.open and "Click: fold" or "Click: open", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    if d.kind == "place" or d.kind == "boss" then
        GameTooltip:AddLine(d.text, 1, 1, 1)
        GameTooltip:AddLine(d.where, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(d.kind == "place" and "Click: open this map" or "Click: see its loot", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetHyperlink("item:" .. d.id)
    GameTooltip:AddLine(" ")
    if d.kind == "item" then
        if d.cost or d.copper then
            local parts, rating = CostParts(d)
            if #parts == 0 then GameTooltip:AddLine("Cost: free", 1, 0.82, 0) end
            for i, p in ipairs(parts) do
                GameTooltip:AddLine((i == 1 and "Cost: " or "          ") .. p[1] .. "  " .. p[2], 1, 0.82, 0)
            end
            if rating and rating > 0 then GameTooltip:AddLine("Requires a personal arena rating of " .. rating, 1, 0.3, 0.3) end
            GameTooltip:AddLine("Sold by: " .. LineTitle(self.mapKey, self.lootLine), 0.8, 0.8, 0.8, true)
        elseif d.quest then
            GameTooltip:AddLine("Quest reward: " .. (AtlasPlus_Quests[d.quest] or ("quest " .. d.quest)), 1, 0.82, 0, true)
        else
            GameTooltip:AddLine("Drop chance: " .. d.pct .. "%" .. (d.count and ("  (" .. d.count .. " at once)") or "") .. (d.hm and "  (hard mode)" or ""), 1, 0.82, 0)
        end
        if d.lv then
            GameTooltip:AddLine("World drop: creatures of level " .. d.lv:gsub("%-", " - ") .. " can drop it, in any zone, dungeon or raid of that level.", 0.8, 0.8, 0.8, true)
        end
        if d.phase == "now" then
            GameTooltip:AddLine("Emblem of the server's current phase (" .. AP.PHASE .. ").", 0.3, 0.85, 0.4, true)
            GameTooltip:AddLine("It can change in another phase.", 0.8, 0.8, 0.8, true)
        elseif d.phase == "later" then
            GameTooltip:AddLine("Emblem of a later phase: it replaces the emblem above when the server moves on.", 0.8, 0.8, 0.8, true)
        end
    else
        GameTooltip:AddLine(d.where, 1, 1, 1)
        if d.modes and not d.nomap then GameTooltip:AddLine("Drops in: " .. d.modes, 0.8, 0.8, 0.8) end
    end
    local fac = select(6, ItemInfo(d.id))
    if fac == "A" then GameTooltip:AddLine("Alliance only", 0.29, 0.62, 1)
    elseif fac == "H" then GameTooltip:AddLine("Horde only", 1, 0.29, 0.29) end
    GameTooltip:AddLine("Shift-click: link   Ctrl-click: try on", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Item search (every instance, every mode)
---------------------------------------------------------------------------
local MODE_ORDER = { N = 1, H = 2, ["10"] = 3, ["25"] = 4, ["10H"] = 5, ["25H"] = 6 }

function UI:BuildSearchIndex()
    if self.index then return end
    local idx = {}
    local function add(key, line, mode, str)
        for entry in (str or ""):gmatch("[^,]+") do
            local id, pct, rest = entry:match("^(%d+):([%d%.]+)(.*)$")
            if id then
                idx[#idx + 1] = { id = tonumber(id), key = key, line = line, mode = mode, pct = tonumber(pct) }
            end
        end
    end
    for key, lines in pairs(AtlasPlus_Loot) do
        for line, modes in pairs(lines) do
            for mode, str in pairs(modes) do add(key, line, mode, str) end
        end
    end
    -- trash: shown under the first map of each instance
    local firstKey = {}
    for key, m in pairs(AtlasPlus_Maps) do
        if m.mapID and m.cat ~= "Entrances" and (not firstKey[m.mapID] or key < firstKey[m.mapID]) then firstKey[m.mapID] = key end
    end
    for mapID, modes in pairs(AtlasPlus_Trash) do
        if firstKey[mapID] then
            for mode, str in pairs(modes) do add(firstKey[mapID], "trash", mode, str) end
        end
    end
    self.index = idx
end

function UI:OnSearchChanged(text)
    text = strlower(strtrim(text or ""))
    self.searchText = text
    if text == "" then
        if self.view == "search" then self.view = "legend"; self:RefreshRight() end
        return
    end
    self:Search(text, true)
end

function UI:Search(text, fromBox)
    if not fromBox then
        self.searchBox:SetText(text)          -- also fires OnTextChanged in game
        if self.searchText ~= strlower(strtrim(text)) then self:OnSearchChanged(text) end
        return
    end
    if self.page ~= "instance" then
        self:SetPage("instance")
        if not self.mapKey then self:SelectMap(AP.db.lastMap, true) end
    end
    self:BuildSearchIndex()
    local results, groups = {}, {}
    -- instances and bosses first (2 letters are enough: "OS", "EoE", "ICC")
    local places, bosses = {}, {}
    if text:len() >= 2 then
        for key, m in pairs(AtlasPlus_Maps) do
            local acr = strlower(m.acr or "")
            local hit = strlower(m.name or ""):find(text, 1, true) or strlower(m.full or ""):find(text, 1, true)
            for a in acr:gmatch("[^,%s]+") do if a == text or (text:len() >= 3 and a:find(text, 1, true)) then hit = true end end
            if hit then
                places[#places + 1] = { kind = "place", key = key, text = m.name,
                    where = (m.acr and (m.acr .. "  ") or "") .. "|cff888888" .. (m.cat or "") .. "|r" }
            end
        end
        table.sort(places, function(a, b) return a.text < b.text end)
        if text:len() >= 3 then
            for key, lines in pairs(AtlasPlus_Loot) do
                local m = AtlasPlus_Maps[key]
                for line in pairs(lines) do
                    if type(line) == "number" then
                        local t = LineTitle(key, line)
                        if strlower(t):find(text, 1, true) then
                            bosses[#bosses + 1] = { kind = "boss", key = key, line = line, text = t,
                                where = "|cff888888" .. (m and m.name or "") .. "|r" }
                        end
                    end
                end
            end
            table.sort(bosses, function(a, b) if a.text ~= b.text then return a.text < b.text end return a.where < b.where end)
        end
    end
    if text:len() >= 3 then
        for _, e in ipairs(self.index) do
            local d = AtlasPlus_Items[e.id]
            local name = d and d[1] or ""
            if strlower(name):find(text, 1, true) or (d and strlower(d[3]):find(text, 1, true)) then
                local gk = e.id .. ":" .. e.key .. ":" .. e.line
                local g = groups[gk]
                if not g then
                    local m = AtlasPlus_Maps[e.key]
                    g = { kind = "result", id = e.id, key = e.key, line = e.line, mode = e.mode, list = {},
                          where = LineTitle(e.key, e.line) .. "  |cff888888" .. (m and (m.nomap and m.full or m.name) or "") .. "|r",
                          q = d and d[2] or 0, nomap = m and m.nomap }
                    groups[gk] = g
                    results[#results + 1] = g
                end
                g.list[#g.list + 1] = e.mode
                if MODE_ORDER[e.mode] < MODE_ORDER[g.mode] then g.mode = e.mode end
            end
        end
    end
    for _, g in ipairs(results) do
        table.sort(g.list, function(a, b) return MODE_ORDER[a] < MODE_ORDER[b] end)
        local labels = {}
        for i, md in ipairs(g.list) do labels[i] = AP.MODE_LABEL[md] or md end
        g.modes = table.concat(labels, ", ")
    end
    table.sort(results, function(a, b)
        if a.q ~= b.q then return a.q > b.q end
        local na, nb = AtlasPlus_Items[a.id][1], AtlasPlus_Items[b.id][1]
        if na ~= nb then return na < nb end
        return a.where < b.where
    end)
    self.resultsCapped = #results > 200
    while #results > 200 do table.remove(results) end
    self.found = { places = #places, bosses = #bosses, items = #results }
    for i = #bosses, 1, -1 do table.insert(results, 1, bosses[i]) end
    for i = #places, 1, -1 do table.insert(results, 1, places[i]) end
    self.results = results
    self.view = "search"
    self.fromSearch = nil
    FauxScrollFrame_SetOffset(self.rowScroll, 0)
    self.rowScroll:SetVerticalScroll(0)
    self:RefreshRight()
end

---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------
function UI:OnShow()
    -- the list starts folded every time the window opens
    for _, cat in ipairs(AP.CATEGORIES) do AP.db.collapsed[cat] = true end
    FauxScrollFrame_SetOffset(self.listScroll, 0)
    self.listScroll:SetVerticalScroll(0)
    if self.opening then return end      -- OpenInstance / ShowWorld choose the page
    if AP.db.autoSelect then
        AP:AutoSelect()
        return
    end
    if self.page == "world" then self:SetPage("world") else self:OpenInstance(self.mapKey or AP.db.lastMap) end
end

function UI:Show() self.frame:Show() end
function UI:Toggle() if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end end

---------------------------------------------------------------------------
-- Settings (replaces the content while open)
---------------------------------------------------------------------------
-- Settings: a window of its own, so the map stays visible while you change things
function UI:CreateSettings(f)
    local win = CreateFrame("Frame", "AtlasPlusSettings", UIParent)
    W.Size(win, FRAME_W - 20, FRAME_H - TOP + 83)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    W.Backdrop(win, C.bg)
    win:Hide()
    tinsert(UISpecialFrames, "AtlasPlusSettings")
    self.settings = win
    local bar = CreateFrame("Frame", nil, win)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(28)
    W.Backdrop(bar, C.panel, C.panel)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() win:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local sc = win:GetEffectiveScale() / UIParent:GetEffectiveScale()
        AP.db.settingsPos = { left = win:GetLeft() * sc, top = win:GetTop() * sc }
    end)
    local bt = W.Text(bar, "GameFontNormal")
    bt:SetPoint("LEFT", 10, 0)
    bt:SetText("|cffffffffAtlas Plus|r  " .. AP.ACCENT .. "Settings|r")
    local bx = W.Button(bar, "X", 24, 20)
    bx:SetPoint("RIGHT", -4, 0)
    bx:SetScript("OnClick", function() win:Hide() end)
    -- size: drag the bottom right corner
    local g = CreateFrame("Button", nil, win)
    W.Size(g, 16, 16)
    g:SetPoint("BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(win:GetFrameLevel() + 30)
    for i = 0, 2 do
        local d = g:CreateTexture(nil, "OVERLAY")
        d:SetTexture("Interface\\Buttons\\WHITE8X8")
        d:SetVertexColor(0.6, 0.6, 0.6, 0.8)
        W.Size(d, 2, 2)
        d:SetPoint("BOTTOMRIGHT", -(i * 4) - 2, 2)
        local e = g:CreateTexture(nil, "OVERLAY")
        e:SetTexture("Interface\\Buttons\\WHITE8X8")
        e:SetVertexColor(0.6, 0.6, 0.6, 0.8)
        W.Size(e, 2, 2)
        e:SetPoint("BOTTOMRIGHT", -2, (i * 4) + 2)
    end
    g:SetScript("OnMouseDown", function(self)
        local ui = UIParent:GetEffectiveScale()
        self.x0, self.s0, self.w0 = GetCursorPosition() / ui, AP.db.settingsScale or 0.9, win:GetWidth() * (AP.db.settingsScale or 0.9)
        self:SetScript("OnUpdate", function(s2)
            if not IsMouseButtonDown("LeftButton") then s2:SetScript("OnUpdate", nil) return end
            local cx = GetCursorPosition() / ui
            local sc = math.max(0.5, math.min(1.4, (s2.w0 + cx - s2.x0) / win:GetWidth()))
            AP.db.settingsScale = math.floor(sc * 100 + 0.5) / 100
            UI:PlaceSettings()
        end)
    end)
    g:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    g:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

    local s = CreateFrame("Frame", nil, win)
    s:SetPoint("TOPLEFT", 0, -30)
    s:SetPoint("BOTTOMRIGHT", 0, 0)
    local db = function() return AP.db end

    local function Header(text, x, y)
        local h = W.Text(s, "GameFontNormal")
        h:SetPoint("TOPLEFT", x, y)
        h:SetText(AP.ACCENT .. text .. "|r")
        local l = s:CreateTexture(nil, "ARTWORK")
        l:SetTexture("Interface\\Buttons\\WHITE8X8")
        l:SetVertexColor(unpack(C.line))
        l:SetHeight(1)
        l:SetWidth(330)
        l:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
    end
    local y, x0
    local function Column(title, x)
        Header(title, x, -16)
        x0, y = x, -44
    end
    local function Check(label, desc, key, after)
        local cb = W.CheckBox(s, label, desc, function() return db()[key] end, function(v) db()[key] = v; if after then after(v) end end)
        cb:SetPoint("TOPLEFT", x0 + 4, y)
        y = y - (desc and 46 or 28)
        return cb
    end
    local function Slider(label, minV, maxV, step, key, after)
        y = y - 26
        local sl = W.Slider(s, label, minV, maxV, step, function() return db()[key] or 1 end,
            function(v) db()[key] = v; if after then after(v) end end, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
        sl:SetPoint("TOPLEFT", x0 + 8, y)
        y = y - 30
        return sl
    end
    local function Note(text)
        local n = W.Text(s, "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", x0 + 4, y - 8)
        n:SetWidth(330)
        n:SetJustifyH("LEFT")
        n:SetText(text)
        y = y - 34
    end
    local function Refresh() AP.WorldMap:Update(); AP.WorldView:Refresh() end

    -- 1. the window
    Column("Atlas Plus window", 20)
    Check("Open on the map of where you are", "In a dungeon or raid: its map and wing, with the loot of your difficulty. Outdoors: the world map, on your zone.", "autoSelect")
    Check("Open by itself in dungeons and raids", nil, "autoOpen")
    local mm = W.CheckBox(s, "Minimap button", nil, function() return not db().minimap.hide end,
        function(v) db().minimap.hide = not v; UI:UpdateMinimapButton() end)
    mm:SetPoint("TOPLEFT", x0 + 4, y)
    y = y - 28
    Check("Lock the window", "It can't be moved by its title bar.", "locked")
    Check("Fade while moving", "See-through while you move, unless the mouse is over it.", "fadeMoving")
    Slider("Opacity while moving", 0.1, 1, 0.05, "fadeAlpha")
    Slider("Window size", 0.5, 1.6, 0.05, "scale", function() UI:ApplyLayout() end)
    Slider("Window opacity", 0.3, 1, 0.05, "alpha", function() UI:ApplyLayout() end)
    Note("Move the window: drag its title. Resize it: drag its bottom right corner.")

    -- 2. the world map
    Column("World map", 385)
    Check("The map key (M) opens Atlas Plus", "The game's map opens inside Atlas Plus, quests and map addons included. Untick to get the game's map back on M.", "replaceWorldMap")
    Check("Game instance maps", "In a dungeon or raid with a game map (Ulduar, Icecrown Citadel...): open it, on your floor. The Atlas map stays in the Atlas tab.", "gameInstanceMaps")
    Check("No fog of war", "Show the areas you have not explored yet.", "showUnexplored", Refresh)
    Check("Darken unexplored areas", "So you can still tell them apart.", "darkenUnexplored", Refresh)
    Check("Zone panel (top left of the map)", nil, "zoneBlock", Refresh)
    Check("Zone info under the cursor", nil, "worldZoneInfo", Refresh)
    Check("Coordinates (yours and the cursor's)", nil, "worldCoords", Refresh)
    Slider("Quest icon size", 0.5, 2, 0.1, "questScale", function() AP.WorldMap:RescaleQuestIcons() end)
    Slider("Game map opacity", 0.3, 1, 0.05, "gameMapAlpha", function() AP.WorldMap:Update() end)
    Slider("Game small map size", 0.5, 1.5, 0.05, "gameSmallScale", function() AP.WorldMap:Update() end)
    Note("These two: the game's own map (Game map button). The size changes the small map, even while it is open.")

    -- 3. map markers: one switch per kind, two per line
    Column("Map markers", 750)
    local col = 0
    local function Marker(label, key)
        local cb = W.CheckBox(s, label, nil, function() return db().markers[key] end, function(v) db().markers[key] = v; AP.Markers:Refresh() end)
        cb:SetPoint("TOPLEFT", x0 + 4 + col * 172, y)
        if col == 1 then y = y - 24 end
        col = 1 - col
    end
    Marker("Dungeons (blue)", "dungeon"); Marker("Raids (green)", "raid")
    Marker("World bosses", "worldboss"); Marker("Portals", "portal")
    Marker("Boats", "boat");             Marker("Zeppelins", "zepp")
    Marker("Deeprun Tram", "tram");      Marker("Flight masters", "flight")
    Marker("Innkeepers", "inn");         Marker("Mailboxes", "mail")
    Marker("Banks", "bank");             Marker("Auction houses", "auction")
    y = y - 6
    Check("Markers on continent maps", "Not the town ones (flight masters, inns...).", "continentMarkers", function() AP.Markers:Refresh() end)
    Check("Hide Questie's dungeon and raid icons", "While the Atlas Plus ones are on. They come back when you turn these off.", "hideQuestieInstances", function() AP.Markers:SyncQuestie(true) end)
    Check("Only my faction's", "Transports, portals and town markers. Neutral ones always show.", "myFactionOnly", function() AP.Markers:Refresh() end)
    Slider("Marker size", 0.6, 2, 0.1, "pinScale", function() AP.Markers:Refresh() end)
    Slider("Town marker size", 0.5, 2, 0.1, "townScale", function() AP.Markers:Refresh() end)

    -- credits
    local credits = W.Text(s, "GameFontDisableSmall")
    credits:SetPoint("BOTTOMLEFT", 20, 16)
    credits:SetPoint("RIGHT", s, "RIGHT", -20, 0)
    credits:SetJustifyH("LEFT")
    credits:SetText("Atlas Plus " .. AP.VERSION .. " by Saranwrap.  Instance maps and legends from Atlas by Dan Gilbert and contributors (GPL v2).  " ..
        "Zone levels from LibTourist-3.0 (MIT).  Loot and drop chances from the AzerothCore world database.\n" ..
        "/ap - open / close     /ap here - map of where you are     /ap world - world map     /ap search <item>     /ap reset - window position and size")
end

function UI:PlaceSettings()
    local win = self.settings
    local sc = AP.db.settingsScale or 0.9
    win:SetScale(sc)
    win:ClearAllPoints()
    local p = AP.db.settingsPos
    if p and p.left then win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left / sc, p.top / sc)
    else win:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
end

function UI:ShowSettings()
    self:PlaceSettings()
    self.settings:Show()
end

function UI:HideSettings()
    if self.settings then self.settings:Hide() end
end

function UI:ToggleSettings()
    if self.settings:IsShown() then self:HideSettings() else self:ShowSettings() end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local function PositionMinimapButton(b)
    local angle = math.rad(AP.db.minimap.angle or 200)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

function UI:CreateMinimapButton()
    local b = CreateFrame("Button", "AtlasPlusMinimapButton", Minimap)
    W.Size(b, 31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    W.Size(bg, 20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    W.Size(icon, 20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = b:CreateTexture(nil, "OVERLAY")
    W.Size(border, 53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then UI:ShowSettings() else UI:Toggle() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(s)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            AP.db.minimap.angle = math.deg(math.atan2(py / sc - my, px / sc - mx))
            PositionMinimapButton(s)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Atlas Plus")
        GameTooltip:AddLine("Left-click: open / close", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapBtn = b
    self:UpdateMinimapButton()
end

function UI:UpdateMinimapButton()
    local b = self.minimapBtn
    if not b then return end
    if AP.db.minimap.hide then b:Hide() else PositionMinimapButton(b); b:Show() end
end

---------------------------------------------------------------------------
-- Escape > Interface > AddOns
---------------------------------------------------------------------------
function UI:CreateInterfacePanel()
    local p = CreateFrame("Frame", "AtlasPlusInterfacePanel", UIParent)
    p.name = "Atlas Plus"
    local t = W.Text(p, "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Atlas Plus |cff888888v" .. AP.VERSION .. "|r")
    local d = W.Text(p, "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
    d:SetWidth(560)
    d:SetJustifyH("LEFT")
    d:SetText("Instance maps with every boss and its loot, item search, and world map zone info.\n\n/ap - open / close     /ap here - map of where you are     /ap settings")
    local open = W.Button(p, "Open Atlas Plus", 140, 24)
    open:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -16)
    open:SetScript("OnClick", function() HideUIPanel(InterfaceOptionsFrame); HideUIPanel(GameMenuFrame); UI:Show() end)
    local set = W.Button(p, "Settings", 100, 24)
    set:SetPoint("LEFT", open, "RIGHT", 8, 0)
    set:SetScript("OnClick", function() HideUIPanel(InterfaceOptionsFrame); HideUIPanel(GameMenuFrame); UI:ShowSettings() end)
    InterfaceOptions_AddCategory(p)
end
