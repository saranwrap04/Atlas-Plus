--[[
    Atlas Plus - the game's own world map
    * the map key (M) opens Atlas Plus; its World map page holds the game's map (the small map,
      resized to fill the page), so quest objectives, Questie and other map addons keep working
    * "Game map" (or the quest log's map button) opens the game's map on its own, full screen or small
    * zone info: level range (colored for your level), instances and fishing skill of the zone under the cursor
    * coordinates on the game's map when it is on its own
    Zone data: LibTourist-3.0 (MIT, ckknight and Arrowmaster).
    Author: Saranwrap
]]

local AP = AtlasPlus
local WM = {}
AP.WorldMap = WM

local MAP_W, MAP_H = 1002, 668

-- parts of the small map frame that Atlas Plus replaces
local HIDE_WHEN_EMBEDDED = {
    "WorldMapFrameMiniBorderLeft", "WorldMapFrameMiniBorderRight", "WorldMapTitleButton", "WorldMapFrameTitle",
    "WorldMapFrameCloseButton", "WorldMapFrameSizeUpButton", "WorldMapFrameSizeDownButton",
    "WorldMapQuestShowObjectives", "WorldMapTrackQuest",
}
local TOOLTIPS = { "WorldMapTooltip", "WorldMapCompareTooltip1", "WorldMapCompareTooltip2", "WorldMapCompareTooltip3" }

---------------------------------------------------------------------------
-- Run something on the next frame (never inside the map's own show/hide)
---------------------------------------------------------------------------
local queue = {}
local defer = CreateFrame("Frame")
defer:Hide()
defer:SetScript("OnUpdate", function(self)
    self:Hide()
    local q = queue
    queue = {}
    for _, fn in ipairs(q) do fn() end
end)
local function Defer(fn)
    queue[#queue + 1] = fn
    defer:Show()
end

local function WindowedSize() return WORLDMAP_WINDOWED_SIZE or 0.573 end

---------------------------------------------------------------------------
-- The game's map inside the Atlas Plus window
---------------------------------------------------------------------------
function WM:Layout()
    if not self.embedded then return end
    local holder = AP.WorldView.holder
    local w = MAP_W * WindowedSize()
    local s = holder:GetWidth() / w
    WorldMapFrame:SetScale(s)
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    WorldMapFrame:SetWidth(w)
    WorldMapFrame:SetHeight(MAP_H * WindowedSize())
    WorldMapDetailFrame:ClearAllPoints()
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 0, 0)
    if WorldMapLevelDropDown and WorldMapPositioningGuide then
        WorldMapLevelDropDown:ClearAllPoints()
        WorldMapLevelDropDown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", 0, -2)
        WorldMapLevelDropDown:SetScale(1.2 / s)              -- floor list: readable, not enlarged with the map
    end
    for _, n in ipairs(TOOLTIPS) do if _G[n] then _G[n]:SetScale(1 / s) end end
    self:RedrawQuestAreas()
    if self.UpdateArrow then self:UpdateArrow() end
end

-- the selected quest's area is drawn at a fixed place: draw it again after a move or a resize
function WM:RedrawQuestAreas()
    local blob = WorldMapBlobFrame
    if not blob then return end
    blob.xRatio = nil                                                  -- recalculate mouse hits
    local q = WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuest
    if q and blob:IsVisible() and blob.DrawQuestBlob then
        blob:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, false)
        if not q.completed then blob:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, true) end
    end
end

-- your arrow: a sharp Atlas Plus arrow above every icon (the game's one is blurry once the map is enlarged)
local arrow
local function RotateTex(tex, a)
    local c, s = math.cos(a), math.sin(a)
    local function uv(dx, dy) return 0.5 + dx * c + dy * s, 0.5 - (-dx * s + dy * c) end
    local ulx, uly = uv(-0.5, 0.5)
    local llx, lly = uv(-0.5, -0.5)
    local urx, ury = uv(0.5, 0.5)
    local lrx, lry = uv(0.5, -0.5)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function GameArrows(alpha)
    for _, n in ipairs({ "PlayerArrowEffectFrame", "PlayerArrowFrame" }) do
        local f = _G[n]
        if f then
            if alpha == 0 then f.apAlpha = f.apAlpha or f:GetAlpha(); f:SetAlpha(0)
            elseif f.apAlpha then f:SetAlpha(f.apAlpha); f.apAlpha = nil end
        end
    end
end

local function RaiseArrow(strata)
    if not (WorldMapButton and WorldMapPlayer) then return end
    if not arrow then
        arrow = CreateFrame("Frame", nil, WorldMapButton)
        arrow.tex = arrow:CreateTexture(nil, "OVERLAY")
        arrow.tex:SetAllPoints()
        arrow.tex:SetTexture(AP.MEDIA .. "Images\\PlayerArrow")
        arrow:SetScript("OnUpdate", function(self)
            if WorldMapPlayer:IsShown() then
                self:ClearAllPoints()
                self:SetPoint("CENTER", WorldMapPlayer, "CENTER")
                RotateTex(self.tex, GetPlayerFacing and GetPlayerFacing() or 0)
                self.tex:Show()
            else
                self.tex:Hide()
            end
        end)
    end
    if strata then
        arrow:SetFrameStrata(strata)
        arrow:SetFrameLevel(300)
        local size = 30 / (WorldMapButton:GetEffectiveScale() / AP.UI.frame:GetEffectiveScale())   -- about 30 pixels of the window
        arrow:SetWidth(size)
        arrow:SetHeight(size)
        arrow:Show()
        GameArrows(0)
    else
        arrow:Hide()
        GameArrows(1)
    end
end

function WM:UpdateArrow() if self.embedded then RaiseArrow(WorldMapFrame:GetFrameStrata()) end end

function WM:EmbedInner()
    if self.embedded then
        self:Layout()
        if not WorldMapFrame:IsShown() then self.internal = true; WorldMapFrame:Show(); self.internal = nil end
        return
    end
    local holder = AP.WorldView.holder
    self.internal = true
    if WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
    if WorldMapFrame:IsShown() then WorldMapFrame:Hide() end
    if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size ~= WindowedSize() and WorldMap_ToggleSizeDown then WorldMap_ToggleSizeDown() end
    self.embedded = true
    self.saved = { scale = WorldMapFrame:GetScale(), strata = WorldMapFrame:GetFrameStrata(), alpha = WorldMapFrame:GetAlpha() }
    self.hidden = {}
    for _, n in ipairs(HIDE_WHEN_EMBEDDED) do
        local o = _G[n]
        if o then self.hidden[n] = o:IsShown(); o:Hide() end
    end
    self:ResetAlpha()
    WorldMapFrame:SetParent(holder)
    WorldMapFrame:SetFrameStrata(holder:GetFrameStrata())
    WorldMapFrame:SetAlpha(1)
    WorldMapFrame:SetClampedToScreen(false)     -- it follows the Atlas Plus window, which is clamped itself
    if WorldMapFrame_ResetFrameLevels then WorldMapFrame_ResetFrameLevels() end
    self:Layout()
    WorldMapFrame:Show()
    RaiseArrow(holder:GetFrameStrata())
    self.internal = nil
    -- back from an instance map: the map that was shown before; otherwise the game shows your zone
    local v = self.restore and self.lastView
    self.restore = nil
    if v then
        if v.mapID < 0 then SetMapZoom(v.cont) else
            SetMapByID(v.mapID)
            if v.level > 0 and SetDungeonMapLevel then SetDungeonMapLevel(v.level) end
        end
    end
    self:Update()
    AP.WorldView:Refresh()
    local q = self.whenShown
    self.whenShown = nil
    if q then for _, fn in ipairs(q) do fn() end end
    self:RedrawQuestAreas()
end

-- the game places its quest icons for a scale of 1; keep the same spot at another size
function WM:ScaleQuestIcon(b)
    if not (b and b.GetPoint and b:GetNumPoints() > 0) then return end
    local qs = (AP.db.questScale or 1) * 0.5           -- 100% = half the game's size (the map is enlarged)
    local point, rel, relPoint, x, y = b:GetPoint(1)
    local bx, by = x, y                                     -- offsets for scale 1
    if b.apX and x == b.apX and y == b.apY then bx, by = x * b.apScale, y * b.apScale end   -- not moved by the game
    b:SetScale(qs)
    b:ClearAllPoints()
    b:SetPoint(point, rel, relPoint, bx / qs, by / qs)
    b.apScale, b.apX, b.apY = qs, bx / qs, by / qs
end

-- settings slider: redraw the quest icons
function WM:RescaleQuestIcons()
    if WorldMapFrame:IsVisible() and WorldMapFrame_DisplayQuests then WorldMapFrame_DisplayQuests() end
end

-- in an instance: does the game have a map of it?
local NOT_INSTANCE = { World = true, Cosmic = true, Kalimdor = true, Azeroth = true, Expansion01 = true, Northrend = true }
function WM:InstanceMapAvailable()
    if not IsInInstance() then return false end
    SetMapToCurrentZone()
    local file = GetMapInfo()
    return file and not NOT_INSTANCE[file] and true or false
end

-- run something once the map is on the World map page
function WM:WhenShown(fn)
    self.whenShown = self.whenShown or {}
    table.insert(self.whenShown, fn)
    if AP.UI.page ~= "world" or not AP.UI.frame:IsShown() then AP.UI:ShowWorld(true) end
end

function WM:ReleaseInner()
    if not self.embedded then return end
    self.internal = true
    if GetCurrentMapAreaID then
        self.lastView = { mapID = GetCurrentMapAreaID() - 1, cont = GetCurrentMapContinent(),
                          level = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0 }
    end
    RaiseArrow(nil)
    WorldMapFrame:Hide()
    self.embedded = nil
    WorldMapFrame:SetParent(UIParent)
    -- the game's map is always at scale 1 (the small map size of the settings is applied when it opens)
    WorldMapFrame:SetScale(1)
    WorldMapFrame:SetFrameStrata(self.saved.strata or "MEDIUM")
    WorldMapFrame:SetAlpha(self.saved.alpha or 1)
    WorldMapFrame:SetClampedToScreen(true)
    -- no anchor left on the Atlas Plus window: the game places its map again
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    for _, n in ipairs(TOOLTIPS) do if _G[n] then _G[n]:SetScale(1) end end
    if WorldMapLevelDropDown then WorldMapLevelDropDown:SetScale(1) end
    -- borders, title, close and size buttons back (the size functions below hide what their size does not use)
    for _, n in ipairs(HIDE_WHEN_EMBEDDED) do
        if n ~= "WorldMapTrackQuest" and _G[n] then _G[n]:Show() end
    end
    -- back to the game's own layout (small or full screen, as the player last used it)
    if GetCVarBool and GetCVarBool("miniWorldMap") then
        if WorldMap_ToggleSizeDown then WorldMap_ToggleSizeDown() end
    elseif WorldMap_ToggleSizeUp then
        WorldMap_ToggleSizeUp()
    end
    if WorldMapFrame_ResetFrameLevels then WorldMapFrame_ResetFrameLevels() end
    self.internal = nil
    self:Update()
end

-- the game's map on its own must stay on the screen, with its title and close button visible
function WM:KeepOnScreen()
    if self.embedded or not WorldMapFrame:IsShown() then return end
    local top, left = WorldMapFrame:GetTop(), WorldMapFrame:GetLeft()
    local s = WorldMapFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not top or not left then return end
    if top * s > UIParent:GetHeight() + 2 or left * s < -2 or (WorldMapFrame:GetWidth() * s > UIParent:GetWidth() + 4) then
        if WorldMapFrame:GetWidth() * s > UIParent:GetWidth() then WorldMapFrame:SetScale(1) end
        if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WindowedSize() then
            WorldMapFrame:ClearAllPoints()
            WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        end
    end
end

-- the World map page asks for the map (next frame), or gives it back (now)
-- Safe wrappers: an error must never leave the game's map half moved (invisible map, window stuck)
local function Report(what, err)
    if not WM.reported then
        WM.reported = true
        AP:Print("could not " .. what .. " the game's map (" .. tostring(err) .. "). It opens on its own instead; please report this message.")
    end
end

local function Restore()
    WM.internal = true
    pcall(WorldMapFrame.Hide, WorldMapFrame)
    WM.embedded = nil
    pcall(WorldMapFrame.SetParent, WorldMapFrame, UIParent)
    pcall(WorldMapFrame.SetScale, WorldMapFrame, 1)
    pcall(WorldMapFrame.SetClampedToScreen, WorldMapFrame, true)
    pcall(WorldMapFrame.ClearAllPoints, WorldMapFrame)
    pcall(WorldMapFrame.SetPoint, WorldMapFrame, "TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    for _, n in ipairs(HIDE_WHEN_EMBEDDED) do if n ~= "WorldMapTrackQuest" and _G[n] then pcall(_G[n].Show, _G[n]) end end
    if GetCVarBool and GetCVarBool("miniWorldMap") then pcall(WorldMap_ToggleSizeDown) else pcall(WorldMap_ToggleSizeUp) end
    WM.internal = nil
end

function WM:Embed()
    if self.failed then return end
    local ok, err = pcall(self.EmbedInner, self)
    self.internal = nil
    if not ok then
        self.failed = true          -- until /reload: use the game's map on its own
        Restore()
        Report("place", err)
    end
end

function WM:Release()
    local ok, err = pcall(self.ReleaseInner, self)
    self.internal = nil
    if not ok then
        Restore()
        Report("give back", err)
    end
end

-- In combat the game forbids moving a window that holds a protected frame. The only one in the
-- game's map is its quest area frame (WorldMapBlobFrame), set aside for the fight when combat starts
-- (see WM:BlobCombat). Without it the map moves freely, so it stays usable in combat.
-- If it could not be set aside (a reload in combat), the map waits for the end of the fight.
function WM:CanMoveInCombat()
    if not InCombatLockdown() then return true end
    if WorldMapBlobFrame and not self.blobAside then return false end
    return not WorldMapFrame:IsProtected()
end

function WM:Attach()
    self.want = true
    Defer(function()
        local UI = AP.UI
        if WM.want and UI.frame:IsShown() and UI.page == "world" then
            if WM:CanMoveInCombat() then WM:Embed() else WM:CombatNotice(true) end
        end
    end)
end

function WM:CombatNotice(on)
    local WV = AP.WorldView
    if not WV.combatText then
        WV.combatText = WV.layer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        WV.combatText:SetPoint("CENTER", WV.holder, "CENTER")
        WV.combatText:SetText("The map comes back when the fight ends.\nThe map key (M) opens the game's map meanwhile.")
    end
    if on then WV.combatText:Show() else WV.combatText:Hide() end
end

function WM:Detach()
    self.want = nil
    self:Release()
end

-- open the game's map on its own (Game map button)
function WM:OpenGameMap()
    AP.UI.frame:Hide()
    self:Detach()
    -- one frame later: the map is fully given back to the game first
    Defer(function()
        if not self:CanMoveInCombat() then return end
        -- the small map, at the size of the settings (its button on the map goes full screen)
        if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size ~= WindowedSize() and WorldMap_ToggleSizeDown then
            WorldMap_ToggleSizeDown()
        end
        self.allowGameMap = true
        ShowUIPanel(WorldMapFrame)
        self.allowGameMap = nil
        self:ApplySize()
        self:KeepOnScreen()
    end)
end

---------------------------------------------------------------------------
-- Zone info (zone under the cursor) and coordinates
---------------------------------------------------------------------------
local function ZoneText(name)
    local z = AtlasPlus_Zones[name]
    if not z then return nil end
    local WV = AP.WorldView
    local lines = {}
    local r = WV.Range(z)
    if r then lines[1] = WV.LevelColor(z[1], z[2]) .. "Level " .. r .. "|r" end
    for _, l in ipairs(WV.ZoneLines(z)) do lines[#lines + 1] = l end
    return table.concat(lines, "\n")
end

local lastZone, lastTarget
local function OnMapUpdate()
    if not WM.ready then return end
    if WorldMapFrame:GetNumPoints() == 0 then WM:EnsurePlaced() end
    local target = WM.embedded and WM.infoEmbedded or WM.info
    local other = WM.embedded and WM.info or WM.infoEmbedded
    if target ~= lastTarget then other:SetText(""); lastTarget = target; lastZone = nil end
    if not AP.db.worldZoneInfo or not (WorldMapFrameAreaLabel and WorldMapFrameAreaLabel:IsShown()) then
        target:SetText("")
        lastZone = nil
        return
    end
    local zone = WorldMapFrameAreaLabel:GetText()
    if zone then zone = zone:gsub(" |c%x+.*$", "") end
    if WorldMapFrameAreaDescription and WorldMapFrameAreaDescription:GetText() and WorldMapFrameAreaDescription:GetText() ~= "" then
        local d = WorldMapFrameAreaDescription:GetText():gsub(" |c%x+.*$", "")
        if AtlasPlus_Zones[d] then zone = d end
    end
    if zone == lastZone then return end
    lastZone = zone
    target:SetText(zone and ZoneText(zone) or "")
end

local function UpdateCoords(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    local px, py = GetPlayerMapPosition("player")
    local ptext = (px and px > 0) and string.format("%.1f, %.1f", px * 100, py * 100) or "-"
    local ctext = "-"
    local d = WorldMapDetailFrame
    local left, top, w, h = d:GetLeft(), d:GetTop(), d:GetWidth(), d:GetHeight()
    if left and w and w > 0 then
        local scale = d:GetEffectiveScale()
        local x, y = GetCursorPosition()
        local cx, cy = (x / scale - left) / w, (top - y / scale) / h
        if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then ctext = string.format("%.1f, %.1f", cx * 100, cy * 100) end
    end
    WM.coords:SetText("|cffffd100Player|r  " .. ptext .. "        |cffffd100Cursor|r  " .. ctext)
end

---------------------------------------------------------------------------
-- The game's map on its own: opacity, small map size
---------------------------------------------------------------------------
local function IsSmallMap()
    return WORLDMAP_SETTINGS and WORLDMAP_WINDOWED_SIZE and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
end

-- opacity of the game's map on its own: on the map's parts too (other addons can reset the frame's alpha)
local ALPHA_PARTS = { "WorldMapDetailFrame", "WorldMapFrameMiniBorderLeft", "WorldMapFrameMiniBorderRight", "WorldMapPOIFrame", "BlackoutWorld" }
function WM:ApplyAlpha()
    if not WorldMapFrame or self.embedded then return end
    local a = AP.db.gameMapAlpha or 1
    WorldMapFrame:SetAlpha(1)
    if a >= 1 then self:ResetAlpha() return end
    for _, n in ipairs(ALPHA_PARTS) do
        local o = _G[n]
        if o and o.SetAlpha then o:SetAlpha(a) end
    end
    self.alphaApplied = a < 1
end

-- back to the game's own opacity (inside Atlas Plus the map is opaque)
function WM:ResetAlpha()
    if not self.alphaApplied then return end
    self.alphaApplied = nil
    for _, n in ipairs(ALPHA_PARTS) do
        local o = _G[n]
        if o and o.SetAlpha then o:SetAlpha(1) end
    end
    if WorldMapFrame_SetOpacity and WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.opacity then
        pcall(WorldMapFrame_SetOpacity, WORLDMAP_SETTINGS.opacity)
    end
end

function WM:ApplySize()
    if not WorldMapFrame or self.embedded then return end
    self:ApplyAlpha()
    if IsSmallMap() then
        local sc = AP.db.gameSmallScale or 1
        -- never bigger than the screen
        local fit = math.min(UIParent:GetWidth() / 640, UIParent:GetHeight() / 470)
        if sc > fit then sc = fit end
        if math.abs(WorldMapFrame:GetScale() - sc) > 0.001 then WorldMapFrame:SetScale(sc) end
        self.scaled = true
        self:KeepOnScreen()
    elseif self.scaled then
        self.scaled = nil
    end
end

function WM:Update()
    if not self.ready then return end
    if AP.db.worldCoords and not self.embedded then self.coordFrame:Show() else self.coordFrame:Hide() end
    if not AP.db.worldZoneInfo then self.info:SetText(""); self.infoEmbedded:SetText("") end
    lastZone = nil
    self:ApplySize()
    if AP.Markers then AP.Markers:Draw() end
    if AP.Fog then AP.Fog:Update() end
end

---------------------------------------------------------------------------
-- Quest areas in combat: the game's quest area frame (WorldMapBlobFrame) is protected, and
-- once an addon has moved the map the game's own Show / Hide / SetScale calls on it are
-- blocked in combat (ADDON_ACTION_BLOCKED). In combat it is set aside and those calls only
-- remember what the game wanted; after combat it goes back and shows the quest area again.
---------------------------------------------------------------------------
local blobVisible, blobScale
local function BlobShow() blobVisible = true end
local function BlobHide() blobVisible = nil end
local function BlobScale(_, s) blobScale = s end

function WM:BlobCombat(on)
    local blob = WorldMapBlobFrame
    if not blob then return end
    if on then
        if self.blobAside then return end
        self.blobAside = true
        blobVisible, blobScale = blob:IsShown(), nil
        self.blobHome = { parent = blob:GetParent(), points = {} }
        for i = 1, blob:GetNumPoints() do self.blobHome.points[i] = { blob:GetPoint(i) } end
        blob:SetParent(nil)
        blob:ClearAllPoints()
        blob:SetPoint("TOP", UIParent, "BOTTOM")       -- off the screen, the game's sums still work
        blob:Hide()
        blob.Show, blob.Hide, blob.SetScale = BlobShow, BlobHide, BlobScale
    else
        if not self.blobAside then return end
        self.blobAside = nil
        blob.Show, blob.Hide, blob.SetScale = nil, nil, nil
        local home = self.blobHome or {}
        blob:SetParent(home.parent or WorldMapFrame)
        blob:ClearAllPoints()
        if home.points and #home.points > 0 then
            for _, p in ipairs(home.points) do blob:SetPoint(unpack(p)) end
        else
            blob:SetPoint("TOPLEFT", WorldMapDetailFrame)
        end
        if blobScale then blob:SetScale(blobScale) end
        blob.xRatio = nil
        if blobVisible then
            blob:Show()
            if WorldMapBlobFrame_CalculateHitTranslations then pcall(WorldMapBlobFrame_CalculateHitTranslations) end
            local q = WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuest
            if q and blob.DrawQuestBlob then
                pcall(blob.DrawQuestBlob, blob, WORLDMAP_SETTINGS.selectedQuestId, false)
                if not q.completed then pcall(blob.DrawQuestBlob, blob, WORLDMAP_SETTINGS.selectedQuestId, true) end
            end
        end
        blobVisible, blobScale = nil, nil
    end
end

-- The game's small map is placed by the game's window manager, and the game's own map
-- functions take its place away (WorldMapFrame_SetMiniMode clears it). Shown without a
-- place (by the game or by an addon), the game's map code errors (WorldMapFrame.lua:750,
-- "centerY" nil). A map on the screen always gets a place.
function WM:EnsurePlaced()
    if self.embedded or not WorldMapFrame:IsShown() then return end
    if WorldMapFrame:GetNumPoints() == 0 then
        WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
function WM:Init()
    if self.ready or not WorldMapFrame or not WorldMapButton then return end
    self.ready = true

    -- the map key opens Atlas Plus (the quest log's map button and "Game map" still open the game's map)
    WorldMapFrame:HookScript("OnShow", function()
        WM:EnsurePlaced()
        if WM.internal or WM.embedded then return end
        if not WM:CanMoveInCombat() then
            -- in combat, map not free to move: the game's map on its own; if Atlas Plus is open it closes
            local UI = AP.UI
            if UI.frame:IsShown() and not UI.frame:IsProtected() then UI.frame:Hide() end
            return
        end
        -- opened while still inside a hidden Atlas Plus window: put it back on the screen
        if WorldMapFrame:GetParent() ~= UIParent and WorldMapFrame:GetParent() ~= nil then
            Restore()
            WorldMapFrame:Show()
            WM:EnsurePlaced()
            return
        end
        if WM.failed then return end
        WM:ApplySize()
        WM:KeepOnScreen()
        if AP.db.replaceWorldMap and not WM.allowGameMap and not (QuestLogFrame and QuestLogFrame:IsShown()) then
            HideUIPanel(WorldMapFrame)
            local UI = AP.UI
            -- the game closes every window before it opens its map: Atlas Plus was open if it closed this same frame
            if UI.frame:IsShown() then UI.frame:Hide()
            elseif not (UI.lastHide and GetTime() - UI.lastHide < 0.05) then UI:Show() end
        end
    end)

    -- the game's full screen map hides the whole interface; make sure it comes back when the map closes
    WorldMapFrame:HookScript("OnHide", function()
        if WM.embedded or WM.internal then return end
        Defer(function()
            if WorldMapFrame:IsShown() or UIParent:IsShown() or InCombatLockdown() then return end
            if GetUIPanel and GetUIPanel("fullscreen") == WorldMapFrame then HideUIPanel(WorldMapFrame) end
            if not UIParent:IsShown() then UIParent:Show() end
        end)
    end)

    -- the map inside Atlas Plus was closed by the game: map key = close Atlas Plus, loading screen = put it back
    WorldMapFrame:HookScript("OnHide", function()
        if WM.internal or not WM.embedded then return end
        Defer(function()
            if not WM.embedded or WorldMapFrame:IsShown() then return end
            if WM.zoning and AP.UI.frame:IsShown() then
                WM.internal = true; WorldMapFrame:Show(); WM.internal = nil
            elseif not (InCombatLockdown() and AP.UI.frame:IsProtected()) then
                AP.UI.frame:Hide()
            end
        end)
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    local cf = CreateFrame("Frame")
    cf:RegisterEvent("PLAYER_REGEN_DISABLED")
    cf:RegisterEvent("PLAYER_REGEN_ENABLED")
    cf:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- the quest area frame is set aside first: the map then stays in the window during the fight
            WM:BlobCombat(true)
            if WM.embedded and WorldMapFrame:IsProtected() then
                WM.want = true
                WM:Release()
                WM:CombatNotice(true)
            end
        else
            WM:BlobCombat(false)
            WM:CombatNotice(false)
            local UI = AP.UI
            if UI.frame:IsShown() and UI.page == "world" then WM:Attach() end
        end
    end)
    ev:SetScript("OnEvent", function()
        -- the game closes its map on a loading screen; only that frame and the next count as "zoning"
        WM.zoning = true
        Defer(function() Defer(function() WM.zoning = nil end) end)
    end)

    -- the game sets the opacity of its small map itself: ours again afterwards
    if WorldMapFrame_SetOpacity then
        hooksecurefunc("WorldMapFrame_SetOpacity", function()
            if not WM.embedded and (AP.db.gameMapAlpha or 1) < 1 then WM:ApplyAlpha() end
        end)
    end

    -- the game keeps showing the "track quest" box: not on the Atlas Plus page
    if WorldMapFrame_DisplayQuests then
        hooksecurefunc("WorldMapFrame_DisplayQuests", function()
            if WM.embedded and WorldMapTrackQuest then WorldMapTrackQuest:Hide() end
        end)
    end

    -- size of the game's quest icons: rescale each one where the game has just placed it
    if WorldMapFrame_DisplayQuestPOI then
        hooksecurefunc("WorldMapFrame_DisplayQuestPOI", function(questFrame) WM:ScaleQuestIcon(questFrame and questFrame.poiIcon) end)
    end
    -- the selected "turn in" icon is a separate button: same size as the others
    if QuestPOI_SelectButton then
        hooksecurefunc("QuestPOI_SelectButton", function(b)
            local swap = QUEST_POI_SWAP_BUTTONS and QUEST_POI_SWAP_BUTTONS["WorldMapPOIFrame"]
            if swap and b and b.parentName == "WorldMapPOIFrame" then swap:SetScale(b:GetScale()) end
        end)
    end
    -- in an instance with floors (Ulduar, Icecrown Citadel...): follow the floor you are on
    local zf = CreateFrame("Frame")
    zf:RegisterEvent("ZONE_CHANGED")
    zf:RegisterEvent("ZONE_CHANGED_INDOORS")
    zf:SetScript("OnEvent", function()
        if WM.embedded and IsInInstance() and WorldMapFrame:IsVisible() then SetMapToCurrentZone() end
    end)

    -- zone info under the zone name: on the game's map, and above it inside Atlas Plus
    local holder = CreateFrame("Frame", nil, WorldMapFrame)
    holder:SetAllPoints(WorldMapFrame)
    holder:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 30)
    local font, size = GameFontHighlightLarge:GetFont()
    local anchor = WorldMapFrameAreaDescription or WorldMapFrameAreaLabel
    local info = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    info:SetFont(font, size, "OUTLINE")
    info:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    info:SetJustifyH("CENTER")
    self.info = info
    local infoE = AP.WorldView.layer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local f2, s2 = GameFontHighlight:GetFont()
    infoE:SetFont(f2, s2 + 2, "OUTLINE")
    infoE:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    infoE:SetJustifyH("CENTER")
    self.infoEmbedded = infoE
    -- the game's map update needs the map's position on the screen: for one frame after the map
    -- is shown or moved the game can give none yet (WorldMapFrame.lua:750, "centerY" nil), so that
    -- frame is skipped (the next one has it)
    local gameUpdate = WorldMapButton:GetScript("OnUpdate")
    WorldMapButton:SetScript("OnUpdate", function(self, elapsed)
        if gameUpdate and self:GetCenter() then gameUpdate(self, elapsed) end
        OnMapUpdate()
    end)

    -- coordinates on the game's map on its own, one line under the map art
    local cf = CreateFrame("Frame", nil, WorldMapFrame)
    cf:SetAllPoints(WorldMapFrame)
    cf:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 30)
    local coords = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local f3, s3 = GameFontNormal:GetFont()
    coords:SetFont(f3, s3 + 2, "OUTLINE")
    coords:SetPoint("BOTTOMLEFT", WorldMapDetailFrame, "BOTTOMLEFT", 10, 8)
    cf:SetScript("OnUpdate", UpdateCoords)
    self.coordFrame, self.coords = cf, coords

    if WorldMap_ToggleSizeDown then hooksecurefunc("WorldMap_ToggleSizeDown", function() WM:EnsurePlaced(); WM:ApplySize() end) end
    if WorldMap_ToggleSizeUp then hooksecurefunc("WorldMap_ToggleSizeUp", function() WM:ApplySize() end) end
    self:Update()
end
