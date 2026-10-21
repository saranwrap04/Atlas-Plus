--[[
    Atlas Plus - world map page
    The game's own world map sits inside the Atlas Plus window (see WorldMap.lua), so everything that
    draws on it keeps working there: quest objectives, Questie, your group, flight paths...
    This page adds the navigation bar, the zone block, clickable instance entrances and coordinates.
    Author: Saranwrap
]]

local AP = AtlasPlus
local W = AP.W
local C = W.C
local WV = {}
AP.WorldView = WV

local MAP_W, MAP_H = 1002, 668          -- size of the game's world map art
local BAR_H, FOOT_H = 28, 26

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function LevelColor(low, high)
    local lvl = UnitLevel("player")
    if not low or low == 0 then return "|cffffffff" end
    if lvl < low - 2 then return "|cffff3333"
    elseif lvl < low then return "|cffff9933"
    elseif lvl <= high then return "|cffffff00"
    elseif lvl <= high + 5 then return "|cff40c040" end
    return "|cff9d9d9d"
end
WV.LevelColor = LevelColor

local function Range(z)
    if not z or not z[1] or z[1] == 0 then return nil end
    if z[1] == z[2] then return tostring(z[1]) end
    return z[1] .. "-" .. z[2]
end
WV.Range = Range

-- name of the zone shown on the map (nil on a continent or the world)
local function ShownZoneName()
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
    if c and c > 0 and z and z > 0 then return (select(z, GetMapZones(c))) end
end

-- level range, dungeons and raids, fishing skill of a zone
function WV.ZoneLines(z)
    local lines = {}
    if z and z[8] then
        for _, iname in ipairs(z[8]) do
            local iz = AtlasPlus_Zones[iname]
            local ir = iz and Range(iz)
            local gs = AP:GroupSize(iname)
            local size = gs and ("  |cffaaaaaa" .. gs .. "-man|r") or ""
            lines[#lines + 1] = (iz and LevelColor(iz[1], iz[2]) or "|cffffffff") .. iname .. (ir and ("  " .. ir) or "") .. "|r" .. size
        end
    end
    if z and z[7] and z[7] > 0 then lines[#lines + 1] = "|cff88ccffFishing " .. z[7] .. "|r" end
    return lines
end

---------------------------------------------------------------------------
-- Frame. Returns its height (the map fills the width, ratio 1.5).
---------------------------------------------------------------------------
function WV:Create(parent, width)
    local mapW = width - 2
    local mapH = math.floor(mapW * MAP_H / MAP_W + 0.5)
    local height = 1 + BAR_H + 2 + mapH + FOOT_H + 1

    local panel = CreateFrame("Frame", nil, parent)
    W.Size(panel, width, height)
    W.Backdrop(panel, C.inset)
    panel:Hide()
    self.panel = panel

    -- navigation bar
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(BAR_H)
    W.Backdrop(bar, C.panel, C.panel)
    local up = W.Button(bar, "< Zoom out", 82, 20)
    up:SetPoint("LEFT", 4, 0)
    up.tip = "Zone > continent > world. Right-click on the map does the same."
    up:SetScript("OnClick", function() WV:ZoomOut() end)
    local prev = up
    self.contBtns = {}
    for i, name in ipairs({ GetMapContinents() }) do
        local b = W.Button(bar, name, 10, 20)
        b:SetWidth(b:GetFontString():GetStringWidth() + 16)
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        b:SetScript("OnClick", function() SetMapZoom(i) end)
        self.contBtns[i] = b
        prev = b
    end
    local zoneBtn = W.MenuButton(bar, "Zone", 170, 20)
    zoneBtn:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    zoneBtn:SetScript("OnClick", function(b) WV:ZoneMenu(b) end)
    self.zoneBtn = zoneBtn
    local here = W.Button(bar, "Find me", 70, 20)
    here:SetPoint("RIGHT", -4, 0)
    here.tip = "The map of your zone, with a pulse on your arrow."
    here:SetScript("OnClick", function() AP.Markers:FindMe() end)
    local game = W.Button(bar, "Game map", 80, 20)
    game:SetPoint("RIGHT", here, "LEFT", -4, 0)
    game.tip = "The game's full screen map, with the quest list."
    game:SetScript("OnClick", function() AP.WorldMap:OpenGameMap() end)
    local quests = W.Button(bar, "Quests", 64, 20)
    quests:SetPoint("RIGHT", game, "LEFT", -4, 0)
    quests.tip = "Show or hide quest objectives on the map."
    quests:SetScript("OnClick", function()
        local cb = WorldMapQuestShowObjectives
        if cb then
            cb:SetChecked(not cb:GetChecked())
            local fn = cb:GetScript("OnClick")
            if fn then fn(cb, "LeftButton") end
        end
        WV:Refresh()
    end)
    self.questsBtn = quests

    -- the game's map goes here
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetPoint("TOPLEFT", 1, -(1 + BAR_H + 2))
    W.Size(holder, mapW, mapH)
    local bg = holder:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 1)
    self.holder = holder

    -- text above the game's map (same strata, higher level)
    local layer = CreateFrame("Frame", nil, panel)
    layer:SetAllPoints(holder)
    layer:SetFrameLevel(250)
    self.layer = layer
    local info = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    local font, size = GameFontHighlightLarge:GetFont()
    info:SetFont(font, size, "OUTLINE")
    info:SetPoint("TOPLEFT", 10, -8)
    info:SetJustifyH("LEFT")
    self.info = info
    local insts = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local f2, s2 = GameFontHighlight:GetFont()
    insts:SetFont(f2, s2 + 1, "OUTLINE")
    insts:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -4)
    insts:SetJustifyH("LEFT")
    self.insts = insts

    -- footer: coordinates (one line, readable) and help
    local foot = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local f3, s3 = GameFontNormal:GetFont()
    foot:SetFont(f3, s3 + 1, "OUTLINE")
    foot:SetPoint("BOTTOMLEFT", 10, 7)
    self.coords = foot
    local find = W.Button(panel, "Find", 70, 20)
    find:SetPoint("BOTTOMRIGHT", -24, 4)
    find.tip = "Find a dungeon, raid, world boss, boat, zeppelin, tram or portal and show it on the map."
    find:SetScript("OnClick", function() AP.Markers:ToggleFind() end)
    local markers = W.MenuButton(panel, "Markers", 96, 20)
    markers:SetPoint("RIGHT", find, "LEFT", -4, 0)
    markers.tip = "Choose which markers the map shows."
    markers:SetScript("OnClick", function(b) AP.Markers:FilterMenu(b) end)
    local hint = W.Text(panel, "GameFontDisableSmall")
    hint:SetPoint("RIGHT", markers, "LEFT", -14, 0)
    hint:SetText("Left-click: zoom in    Right-click: zoom out")
    AP.Markers:CreateFind(panel, holder)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("WORLD_MAP_UPDATE")
    ev:SetScript("OnEvent", function() WV:Refresh() end)
    panel:SetScript("OnUpdate", function(_, elapsed) WV:OnUpdate(elapsed) end)
    return height
end

-- same steps as the game's "Zoom out" button: zone > continent > world (Outland > cosmic)
function WV:ZoomOut()
    if WorldMapZoomOutButton_OnClick then WorldMapZoomOutButton_OnClick() return end
    if (GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0) > 0 and ZoomOut() then return end
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
    if z and z > 0 then SetMapZoom(c) elseif c and c > 0 then SetMapZoom(0) end
end

---------------------------------------------------------------------------
-- Refresh on every map change
---------------------------------------------------------------------------
function WV:Refresh()
    if not (self.panel and self.panel:IsVisible()) then return end
    local c = GetCurrentMapContinent()
    for i, b in ipairs(self.contBtns) do b:SetSelected(i == c) end
    self.zoneBtn:SetText(ShownZoneName() or "Zone")
    self.questsBtn:SetSelected(WorldMapQuestShowObjectives and WorldMapQuestShowObjectives:GetChecked() and true or false)

    -- zone block: the zone shown on the map
    local name = ShownZoneName()
    local z = name and AtlasPlus_Zones[name]
    if z and AP.db.zoneBlock then
        local r = Range(z)
        self.info:SetText(name .. (r and ("   " .. LevelColor(z[1], z[2]) .. "Level " .. r .. "|r") or ""))
        self.insts:SetText(table.concat(WV.ZoneLines(z), "\n"))
    else
        self.info:SetText("")
        self.insts:SetText("")
    end
end

function WV:ZoneMenu(btn)
    local c = GetCurrentMapContinent()
    if not c or c < 1 then c = 1 end
    local menu = { { text = (select(c, GetMapContinents())), isTitle = true, notCheckable = true } }
    for i, name in ipairs({ GetMapZones(c) }) do
        local z = AtlasPlus_Zones[name]
        local r = Range(z)
        menu[#menu + 1] = { text = name .. (r and ("  " .. LevelColor(z[1], z[2]) .. r .. "|r") or ""), notCheckable = true,
            func = function() SetMapZoom(c, i) end }
    end
    W.ShowMenu(menu, btn)
end

---------------------------------------------------------------------------
-- Coordinates (player and cursor), once, under the map
---------------------------------------------------------------------------
function WV:OnUpdate(elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    if not AP.db.worldCoords then self.coords:SetText("") return end
    local px, py = GetPlayerMapPosition("player")
    local ptext = (px and px > 0) and string.format("%.1f, %.1f", px * 100, py * 100) or "-"
    local ctext = "-"
    local b = WorldMapButton
    if AP.WorldMap.embedded and b and b:GetLeft() then
        local s = b:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local x, y = (cx / s - b:GetLeft()) / b:GetWidth(), (b:GetTop() - cy / s) / b:GetHeight()
        if x >= 0 and x <= 1 and y >= 0 and y <= 1 then ctext = string.format("%.1f, %.1f", x * 100, y * 100) end
    end
    self.coords:SetText("|cffffd100Player|r  " .. ptext .. "        |cffffd100Cursor|r  " .. ctext)
end
