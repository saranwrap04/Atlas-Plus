--[[
    Atlas Plus - small flat widgets (same look as the other Saranwrap addons)
    Author: Saranwrap
]]

local AP = AtlasPlus
local W = {}
AP.W = W

W.C = {
    bg     = { 0.06, 0.06, 0.06, 0.95 },
    panel  = { 0.10, 0.10, 0.10, 1 },
    inset  = { 0.08, 0.08, 0.08, 1 },
    border = { 0, 0, 0, 1 },
    line   = { 0.22, 0.22, 0.22, 1 },
    button = { 0.10, 0.10, 0.10, 1 },
    header = { 0.13, 0.13, 0.13, 1 },
    accent = { 1, 0.82, 0, 1 },
    sel    = { 0.24, 0.20, 0.06, 1 },
    input  = { 0.04, 0.04, 0.04, 1 },
    rule   = { 0.45, 0.45, 0.45, 0.6 },
    text   = { 0.90, 0.90, 0.90, 1 },
    muted  = { 0.55, 0.55, 0.60, 1 },
}
local C = W.C

W.QUALITY_HEX = {
    [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd",
    [4] = "|cffa335ee", [5] = "|cffff8000", [6] = "|cffe6cc80", [7] = "|cffe6cc80",
}

function W.Size(f, w, h) f:SetWidth(w); f:SetHeight(h) end

function W.Backdrop(f, bg, border)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(unpack(bg or C.panel))
    f:SetBackdropBorderColor(unpack(border or C.border))
end

function W.Text(parent, font, layer)
    return parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall")
end

function W.Tip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 1, 1, 1)
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

function W.Button(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    W.Size(b, w, h or 22)
    W.Backdrop(b, C.button)
    local fs = W.Text(b, "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    b:SetFontString(fs)
    b:SetText(label)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
        if self.tip then W.Tip(self, self.tipTitle or label, self.tip) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(self.selected and C.accent or C.border))
        GameTooltip:Hide()
    end)
    b:SetScript("OnMouseDown", function(self) self:GetFontString():SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self:GetFontString():SetPoint("CENTER", 0, 0) end)
    function b:SetSelected(on)
        self.selected = on
        self:SetBackdropColor(unpack(on and C.sel or C.button))
        self:SetBackdropBorderColor(unpack(on and C.accent or C.border))
        local t = self:GetFontString()
        if on then t:SetTextColor(1, 1, 1) else t:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end
    end
    return b
end

function W.EditBox(parent, w, h, placeholder)
    local e = CreateFrame("EditBox", nil, parent)
    W.Size(e, w, h or 22)
    W.Backdrop(e, C.inset, C.line)
    e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(6, 20, 0, 0)
    e:SetAutoFocus(false)
    local ph = W.Text(e, "GameFontDisableSmall")
    ph:SetPoint("LEFT", 7, 0)
    ph:SetText(placeholder or "")
    e.placeholder = ph
    local clear = CreateFrame("Button", nil, e)
    W.Size(clear, 16, 16)
    clear:SetPoint("RIGHT", -3, 0)
    local x = W.Text(clear, "GameFontDisableSmall")
    x:SetPoint("CENTER")
    x:SetText("x")
    clear:SetScript("OnClick", function() e:SetText(""); e:ClearFocus() end)
    clear:Hide()
    e.clear = clear
    e:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    e:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.line)) end)
    return e
end

-- Check box: dark square, filled with the accent colour when ticked
function W.CheckBox(parent, label, desc, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent)
    W.Size(cb, 16, 16)
    W.Backdrop(cb, C.input, C.border)
    local fill = cb:CreateTexture(nil, "OVERLAY")
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    cb:SetCheckedTexture(fill)
    local fs = W.Text(cb, "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    fs:SetText(label)
    cb.label = fs
    -- the label is clickable too
    local hit = CreateFrame("Button", nil, cb)
    hit:SetPoint("TOPLEFT", fs, "TOPLEFT", -4, 2)
    hit:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 4, -2)
    hit:SetScript("OnClick", function() cb:Click() end)
    if desc then
        local d = W.Text(cb, "GameFontDisableSmall")
        d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
        d:SetWidth(380)
        d:SetJustifyH("LEFT")
        d:SetText(desc)
        cb.desc = d
    end
    local function enter() cb:SetBackdropBorderColor(unpack(C.accent)) end
    local function leave() cb:SetBackdropBorderColor(unpack(C.border)) end
    cb:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb:SetScript("OnEnter", enter); cb:SetScript("OnLeave", leave)
    hit:SetScript("OnEnter", enter); hit:SetScript("OnLeave", leave)
    return cb
end

-- Slider: gold label above, dark track with a gold thumb, min / value box / max below
local sliderCount = 0
function W.Slider(parent, label, minV, maxV, step, getter, setter, fmt)
    sliderCount = sliderCount + 1
    local s = CreateFrame("Slider", "AtlasPlusSlider" .. sliderCount, parent)
    W.Size(s, 240, 10)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:EnableMouseWheel(true)
    W.Backdrop(s, C.input, C.border)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(unpack(C.accent))
    W.Size(thumb, 10, 12)
    s:SetThumbTexture(thumb)
    local title = W.Text(s, "GameFontNormal")
    title:SetPoint("BOTTOM", s, "TOP", 0, 5)
    title:SetText(label)
    title:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    local function F(v) return fmt and fmt(v) or tostring(v) end
    local lo = W.Text(s, "GameFontHighlightSmall")
    lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, -6)
    lo:SetText(F(minV))
    local hi = W.Text(s, "GameFontHighlightSmall")
    hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, -6)
    hi:SetText(F(maxV))
    local box = CreateFrame("EditBox", nil, s)
    W.Size(box, 70, 18)
    box:SetPoint("TOP", s, "BOTTOM", 0, -3)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetJustifyH("CENTER")
    W.Backdrop(box, C.input, C.border)
    local function show(v) if not box:HasFocus() then box:SetText(F(v)) end end
    local function round(v) return math.floor(v / step + 0.5) * step end
    s:SetScript("OnShow", function(self) local v = getter(); self:SetValue(v); show(v) end)
    s:SetScript("OnValueChanged", function(self, v)
        v = round(v)
        show(v)
        if self:IsShown() and math.abs(v - getter()) > 1e-6 then setter(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, d)
        self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + d * step)))
    end)
    -- type a value: "75", "75%" or "0.75"
    box:SetScript("OnEnterPressed", function(self)
        local t = (self:GetText() or ""):gsub("%%", "")
        local v = tonumber(t)
        if v then
            if fmt and F(1):find("%%") and v > maxV then v = v / 100 end
            s:SetValue(round(math.min(maxV, math.max(minV, v))))
        end
        self:ClearFocus()
        show(s:GetValue())
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); show(s:GetValue()) end)
    box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)); self:HighlightText() end)
    box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    return s
end

-- Section heading: gold title in the middle of a thin line
function W.Section(parent, text, w)
    local f = CreateFrame("Frame", nil, parent)
    W.Size(f, w, 16)
    local fs = W.Text(f, "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local l = f:CreateTexture(nil, "ARTWORK")
        l:SetTexture("Interface\\Buttons\\WHITE8X8")
        l:SetVertexColor(unpack(C.rule))
        l:SetHeight(1)
        if side == "LEFT" then l:SetPoint("LEFT"); l:SetPoint("RIGHT", fs, "LEFT", -8, 0)
        else l:SetPoint("RIGHT"); l:SetPoint("LEFT", fs, "RIGHT", 8, 0) end
    end
    f.text = fs
    return f
end

-- Side-bar entry: gold text, the selected one with a gold glow fading to the right
function W.SideButton(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    W.Size(b, w, 22)
    local glow = b:CreateTexture(nil, "BACKGROUND")
    glow:SetAllPoints()
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetGradientAlpha("HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.55, C.accent[1], C.accent[2], C.accent[3], 0)
    glow:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.12, 1, 1, 1, 0)
    local fs = W.Text(b, "GameFontNormal")
    fs:SetPoint("LEFT", 10, 0)
    b:SetFontString(fs)
    b:SetText(label)
    function b:SetSelected(on)
        if on then glow:Show(); fs:SetTextColor(1, 1, 1) else glow:Hide(); fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end
    end
    b:SetSelected(false)
    return b
end

-- Button that opens a menu: the text on the left, a gold arrow on the right
function W.MenuButton(parent, label, w, h)
    local b = W.Button(parent, label, w, h)
    local fs = b:GetFontString()
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -20, 0)
    fs:SetJustifyH("LEFT")
    b:SetScript("OnMouseDown", nil); b:SetScript("OnMouseUp", nil)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    W.Size(arrow, 12, 12)
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)        -- turned to point down
    arrow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    return b
end

-- Flat scroll bar for a FauxScrollFrame / UIPanelScrollFrame
function W.FlatScroll(sf)
    for _, r in ipairs({ sf:GetRegions() }) do r:SetAlpha(0) end
    local name = sf:GetName()
    local sb = name and _G[name .. "ScrollBar"]
    if not sb then return end
    for _, r in ipairs({ sb:GetRegions() }) do
        if r ~= sb:GetThumbTexture() then r:SetAlpha(0) end
    end
    local track = sb:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\WHITE8X8")
    track:SetVertexColor(unpack(C.inset))
    track:SetWidth(6)
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    local thumb = sb:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetVertexColor(0.40, 0.40, 0.40, 1)
        thumb:SetWidth(6)
    end
    for _, part in ipairs({ { "ScrollUpButton", "^" }, { "ScrollDownButton", "v" } }) do
        local b = _G[sb:GetName() .. part[1]]
        if b then
            for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture(), b:GetHighlightTexture() }) do
                if t then t:SetAlpha(0) end
            end
            W.Backdrop(b, C.panel, C.line)
            local fs = W.Text(b, "GameFontHighlightSmall")
            fs:SetPoint("CENTER", 0, 0)
            fs:SetText(part[2])
            b:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
            b:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.line)) end)
        end
    end
end

-- Flat menu: entries { text, isTitle, notCheckable, checked, func, keepShownOnClick }
local menu, catcher
local function MenuFrame()
    if menu then return menu end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()
    menu = CreateFrame("Frame", "AtlasPlusMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    W.Backdrop(menu, C.panel, C.border)
    menu:Hide()
    menu.rows = {}
    catcher:SetScript("OnClick", function() menu:Hide() end)
    menu:SetScript("OnHide", function() catcher:Hide(); W.menuAnchor = nil end)
    tinsert(UISpecialFrames, "AtlasPlusMenu")
    return menu
end

local ROW = 20
local function Fill(m, list)
    local width = 140
    for i, e in ipairs(list) do
        local r = m.rows[i]
        if not r then
            r = CreateFrame("Button", nil, m)
            r:SetHeight(ROW)
            r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW)
            r:SetPoint("RIGHT", -2, 0)
            r.hl = r:CreateTexture(nil, "HIGHLIGHT")
            r.hl:SetAllPoints()
            r.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
            r.hl:SetGradientAlpha("HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.45, C.accent[1], C.accent[2], C.accent[3], 0)
            r.box = CreateFrame("Frame", nil, r)
            W.Size(r.box, 12, 12)
            r.box:SetPoint("LEFT", 6, 0)
            W.Backdrop(r.box, C.input, C.border)
            r.fill = r.box:CreateTexture(nil, "OVERLAY")
            r.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
            r.fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
            r.fill:SetPoint("TOPLEFT", 2, -2); r.fill:SetPoint("BOTTOMRIGHT", -2, 2)
            r.text = W.Text(r, "GameFontHighlight")
            r.text:SetJustifyH("LEFT")
            m.rows[i] = r
        end
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", e.notCheckable and 8 or 24, 0)
        r.text:SetText(e.text or "")
        if e.isTitle then
            r.text:SetFontObject("GameFontNormalSmall")
            r.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
            r:EnableMouse(false)
            r.hl:Hide()
        else
            r.text:SetFontObject("GameFontHighlight")
            r.text:SetTextColor(1, 1, 1)
            r:EnableMouse(true)
            r.hl:Show()
        end
        if e.notCheckable or e.isTitle then r.box:Hide() else
            r.box:Show()
            if e.checked then r.fill:Show() else r.fill:Hide() end
        end
        r:SetScript("OnClick", function()
            if e.func then e.func() end
            if e.keepShownOnClick and not e.notCheckable then
                e.checked = not e.checked
                if e.checked then r.fill:Show() else r.fill:Hide() end
            else
                m:Hide()
            end
        end)
        r:Show()
        width = math.max(width, r.text:GetStringWidth() + (e.notCheckable and 20 or 36))
    end
    for i = #list + 1, #m.rows do m.rows[i]:Hide() end
    m:SetWidth(width)
    m:SetHeight(#list * ROW + 4)
end

-- a second click on the same button closes the menu
function W.ShowMenu(list, anchor)
    local m = MenuFrame()
    if m:IsShown() and W.menuAnchor == anchor then m:Hide() return end
    Fill(m, list)
    m:ClearAllPoints()
    if anchor and anchor ~= "cursor" then
        -- opens upwards when there is no room under the button
        local bottom = (anchor:GetBottom() or 0) * anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if bottom < m:GetHeight() + 10 then
            m:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
        else
            m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        end
    else
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
    end
    catcher:Show()
    m:Show()
    W.menuAnchor = anchor
end

function W.CloseMenu() if menu then menu:Hide() end end
