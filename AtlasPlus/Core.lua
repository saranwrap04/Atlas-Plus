--[[
    Atlas Plus - core: saved settings, auto-select, slash commands, events
    Author: Saranwrap

    Instance maps and their legends come from Atlas (GPL v2, Dan Gilbert and contributors).
    Loot comes from the AzerothCore world database (the core ChromieCraft runs on).
]]

local ADDON_NAME = ...
AtlasPlus = AtlasPlus or {}
local AP = AtlasPlus
AP.VERSION = "1.11.1"
AP.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"
AP.MAPS = AP.MEDIA .. "Images\\Maps\\"
AP.ACCENT = "|cffffd100"
AP.ICON = AP.MEDIA .. "Images\\icon"

local DEFAULTS = {
    autoSelect = true,      -- open on the map of the instance (or entrance) you are in
    autoOpen = false,       -- open by itself when you enter a dungeon or raid
    minimap = { hide = false, angle = 200 },
    locked = false,
    scale = 1,
    alpha = 1,
    worldZoneInfo = true,   -- world map: level range and instances of the zone under the cursor
    worldCoords = true,     -- world map: player and cursor coordinates
    zoneBlock = true,       -- world map page: info of the zone shown (top left)
    markers = { dungeon = true, raid = true, worldboss = true, boat = true, zepp = true, tram = true, portal = true,
                flight = true, inn = true, mail = true, bank = true, auction = true },
    townScale = 1,          -- size of the town markers (flight masters, inns, mailboxes, banks, auction houses)
    fadeAlpha = 0.5,        -- window opacity while moving
    myFactionOnly = true,   -- transports and portals: only yours and neutral ones
    pinScale = 1,           -- size of the map markers
    continentMarkers = true,-- markers on continent maps too
    questScale = 1,         -- size of the game's quest icons on the map
    gameInstanceMaps = true,-- in an instance: the game's interactive map when it has one
    hideQuestieInstances = true, -- Atlas Plus dungeon / raid icons replace Questie's
    fadeMoving = true,      -- the window fades to 50% while you move (mouse away)
    showUnexplored = true,  -- no fog of war: unexplored areas are drawn
    darkenUnexplored = true,
    replaceWorldMap = true, -- the world map key (M) opens Atlas Plus on its world map page
    gameMapAlpha = 1,       -- the game's own world map (when opened from Atlas Plus)
    gameSmallScale = 1,     -- the game's small world map
    listW = 175,            -- width of the instance list (drag the bar between the list and the map)
    lastMap = "TheDeadmines",
    modes = {},             -- last loot mode per map
    collapsed = {},         -- collapsed categories in the list
}

-- Categories, in list order
AP.CATEGORIES = {
    "Classic Dungeons", "Classic Raids",
    "Burning Crusade Dungeons", "Burning Crusade Raids",
    "Wrath of the Lich King Dungeons", "Wrath of the Lich King Raids",
    "World Drops", "World Events", "Vendors",
    "Entrances", "Dungeon Locations",
}
-- icon of the pages that have no map
AP.CAT_ICON = {
    ["World Drops"] = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
    ["World Events"] = "Interface\\Icons\\INV_Misc_Gift_02",
    ["Vendors"] = "Interface\\Icons\\INV_Misc_Coin_02",
}
-- the server's current phase (ChromieCraft), for the emblems
AP.PHASE = "Phase 3, Ulduar"

AP.MODE_LABEL = { N = "Normal", H = "Heroic", ["10"] = "10", ["25"] = "25", ["10H"] = "10 Heroic", ["25H"] = "25 Heroic" }

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function AP:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(AP.ACCENT .. "Atlas Plus|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Map list (sorted per category)
---------------------------------------------------------------------------
local function MinLevel(m)
    return tonumber((m.lvl or ""):match("^(%d+)")) or 99
end

function AP:BuildIndex()
    local byCat = {}
    for _, c in ipairs(self.CATEGORIES) do byCat[c] = {} end
    for key, m in pairs(AtlasPlus_Maps) do
        m.key = key
        local list = byCat[m.cat]
        if list then list[#list + 1] = key end
    end
    for cat, list in pairs(byCat) do
        table.sort(list, function(a, b)
            local ma, mb = AtlasPlus_Maps[a], AtlasPlus_Maps[b]
            if ma.order or mb.order then return (ma.order or 0) < (mb.order or 0) end
            if cat ~= "Entrances" and cat ~= "Dungeon Locations" then
                local la, lb = MinLevel(ma), MinLevel(mb)
                if la ~= lb then return la < lb end
            end
            return ma.name < mb.name
        end)
    end
    self.byCategory = byCat

    -- area id -> map key (entrance legends link to instance maps)
    self.byArea = {}
    for key, m in pairs(AtlasPlus_Maps) do
        if m.area and m.cat ~= "Entrances" and not self.byArea[m.area] then self.byArea[m.area] = key end
    end
end

---------------------------------------------------------------------------
-- Auto-select: the map of the instance (or the entrance of the zone) you are in
---------------------------------------------------------------------------
local function ZoneShortName(m)
    -- "Auchindoun: Mana-Tombs" -> "Mana-Tombs", "Ulduar [A] (The Siege)" -> "Ulduar"
    local z = m.full or m.name or ""
    z = z:gsub("%s*%b[]", ""):gsub("%s*%b()", "")
    return z:match(":%s*(.+)$") or z
end

-- zone names that differ from the map names
local ZONE_FIX = { ["Tempest Keep"] = "TempestKeepTheEye" }

function AP:FindMapForLocation()
    local A = AtlasPlus_Assoc
    local zone = GetRealZoneText() or ""
    zone = A.substitutions[zone] or zone
    local sub = GetSubZoneText() or ""
    local inInstance = IsInInstance()

    -- multi-map instances (Ulduar, Icecrown Citadel, Karazhan, Dire Maul...): pick the wing by subzone
    if A.defaults[zone] then
        local key = A.subzones[sub]
        if key and AtlasPlus_Maps[key] and A.zoneOf[key] == zone then return key end
        -- staying in the same instance: keep the wing already shown
        local cur = self.db.lastMap
        if cur and A.zoneOf[cur] == zone then return cur end
        return A.defaults[zone]
    end

    if inInstance then
        if ZONE_FIX[zone] then return ZONE_FIX[zone] end
        for key, m in pairs(AtlasPlus_Maps) do
            if m.cat ~= "Entrances" and m.cat ~= "Dungeon Locations" and not m.nomap then
                local full = (m.full or ""):gsub("%s*%b[]", ""):gsub("%s*%b()", "")
                if full == zone or ZoneShortName(m) == zone then return key end
            end
        end
    end

    return nil
end

-- Map of an instance from its zone name ("Utgarde Keep", "Ulduar", "Ahn'kahet: The Old Kingdom")
function AP:KeyForZoneName(zone)
    local A = AtlasPlus_Assoc
    zone = A.substitutions[zone] or zone
    if A.defaults[zone] then return A.defaults[zone] end
    if ZONE_FIX[zone] then return ZONE_FIX[zone] end
    for key, m in pairs(AtlasPlus_Maps) do
        if m.cat ~= "Entrances" and m.cat ~= "Dungeon Locations" and not m.nomap then
            local full = (m.full or ""):gsub("%s*%b[]", ""):gsub("%s*%b()", "")
            if full == zone or ZoneShortName(m) == zone then return key end
        end
    end
end

-- Group size of an instance: "5", "10", "10/25"... (Atlas data, then the zone data)
local SIZE_FIX = { ["Blackrock Spire"] = "5/10", ["Scarlet Monastery"] = "5", ["Tempest Keep"] = "5/25" }  -- BRS: Lower 5, Upper 10
local sizeCache = {}
function AP:GroupSize(name)
    if sizeCache[name] ~= nil then return sizeCache[name] or nil end
    local size = SIZE_FIX[name]
    if not size then
        local key = self:KeyForZoneName(name)
        local m = key and AtlasPlus_Maps[key]
        if m and m.players and m.players ~= "" then size = m.players end
    end
    if not size then
        local z = AtlasPlus_Zones[name]
        if z and z[5] and z[5] > 0 then size = tostring(z[5]) end
    end
    sizeCache[name] = size or false
    return size
end

-- a raid: more than 5 players (Blackrock Spire counts as a dungeon)
function AP:IsRaid(name)
    local s = self:GroupSize(name)
    return s and (tonumber(s:match("^(%d+)")) or 0) > 5 or false
end

-- Loot mode that matches the difficulty you are in
function AP:CurrentMode(key)
    local m = AtlasPlus_Maps[key]
    if not (m and m.modes) then return nil end
    if not IsInInstance() then return nil end
    local diff = GetInstanceDifficulty and GetInstanceDifficulty() or 1
    local want
    if m.modes[1] == "N" then
        want = (diff >= 2) and "H" or "N"
    else
        want = ({ "10", "25", "10H", "25H" })[diff] or "10"
    end
    for _, md in ipairs(m.modes) do if md == want then return want end end
    return nil
end

-- In an instance: its map. Outdoors: the world map page on your zone.
function AP:AutoSelect(force)
    if not (self.db.autoSelect or force) then return end
    local key = IsInInstance() and self:FindMapForLocation()
    -- the game's own instance map (World map page, follows your floor) when there is one
    if key and self.db.gameInstanceMaps and self.WorldMap:InstanceMapAvailable() then
        self.UI:ShowWorld()
        return
    end
    if key then
        local mode = self:CurrentMode(key)
        if mode then self.db.modes[key] = mode end
        self.UI:OpenInstance(key)
    else
        self.UI:ShowWorld()
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

local lastInstanceZone
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        AtlasPlusDB = AtlasPlusDB or {}
        if AtlasPlusDB.instancePins == false then AtlasPlusDB.dungeonPins, AtlasPlusDB.raidPins = false, false end
        AtlasPlusDB.instancePins = nil
        if AtlasPlusDB.dungeonPins ~= nil or AtlasPlusDB.raidPins ~= nil then
            AtlasPlusDB.markers = AtlasPlusDB.markers or {}
            if AtlasPlusDB.dungeonPins == false then AtlasPlusDB.markers.dungeon = false end
            if AtlasPlusDB.raidPins == false then AtlasPlusDB.markers.raid = false end
            AtlasPlusDB.dungeonPins, AtlasPlusDB.raidPins = nil, nil
        end
        CopyDefaults(AtlasPlusDB, DEFAULTS)
        AP.db = AtlasPlusDB
        if not AtlasPlus_Maps[AP.db.lastMap] then AP.db.lastMap = DEFAULTS.lastMap end
        AP:BuildIndex()
    elseif event == "PLAYER_LOGIN" then
        AP.UI:Create()
        AP.UI:CreateMinimapButton()
        if AP.WorldMap then AP.WorldMap:Init() end
        AP.Markers:Init()
        AP.Fog:Init()
        AP.UI:CreateInterfacePanel()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not AP.db then return end
        local inInstance, kind = IsInInstance()
        local zone = GetRealZoneText()
        if AP.db.autoOpen and inInstance and (kind == "party" or kind == "raid") and zone ~= lastInstanceZone then
            lastInstanceZone = zone
            AP.UI:Show()
        end
        if not inInstance then lastInstanceZone = nil end
        if event == "PLAYER_ENTERING_WORLD" and AP.UI.frame and AP.UI.frame:IsShown() then AP:AutoSelect() end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        -- new wing / floor of a multi-map instance
        if AP.UI.frame and AP.UI.frame:IsShown() and IsInInstance() and AP.db.autoSelect then
            local key = AP:FindMapForLocation()
            if key and key ~= AP.UI.mapKey and AtlasPlus_Assoc.zoneOf[key] and AP.UI.page == "instance" then AP.UI:SelectMap(key) end
        end
    end
end)

---------------------------------------------------------------------------
-- Slash commands / key binding
---------------------------------------------------------------------------
BINDING_HEADER_ATLASPLUS = "Atlas Plus"
BINDING_NAME_ATLASPLUS_TOGGLE = "Open / close Atlas Plus"

function AtlasPlus_Toggle() AP.UI:Toggle() end

SLASH_ATLASPLUS1 = "/atlasplus"
SLASH_ATLASPLUS2 = "/ap"
SlashCmdList.ATLASPLUS = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "" then
        AP.UI:Toggle()
    elseif msg == "settings" or msg == "options" or msg == "config" then
        AP.UI:ShowSettings()
    elseif msg == "here" or msg == "current" then
        AP.UI:Show()
        AP:AutoSelect(true)
    elseif msg == "world" or msg == "map" then
        AP.UI:Show()
        AP.UI:ShowWorld()
    elseif msg == "reset" then
        AP.db.pos = nil
        AP.db.scale, AP.db.alpha = 1, 1
        AP.db.gameMapAlpha, AP.db.gameSmallScale = 1, 1
        if AP.WorldMap then AP.WorldMap:Update() end
        AP.UI:ApplyLayout()
        AP:Print("Window position, size and opacity reset.")
    elseif msg:match("^search ") then
        AP.UI:Show()
        AP.UI:Search(msg:match("^search (.+)$"))
    else
        AP:Print("/ap - open / close    /ap here - map of where you are    /ap world - world map    /ap search <item>    /ap settings    /ap reset")
    end
end
