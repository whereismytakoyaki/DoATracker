DAT        = DAT or {}
DAT.Config = DAT.Config or {}

-- L is populated via the locale hook once LoadLocale() runs from
-- Initialize() (SavedVariables are not yet restored at Lua load time).
local L = DAT.L

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

StaticPopupDialogs["DOATRACKER_LOCALE_RELOAD"] = {
    -- text / button1 / button2 are filled in by RebuildLocalizedLists
    -- once the locale table has been applied.
    OnAccept       = function() ReloadUI() end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

-- forward declarations (assigned in DAT.Config:Open / near SelectGroup)
local _currentTree
local _configFrame
local RefreshPage
-- Live refs to the Main page position sliders so drag-to-move can push
-- the new value back into the open config. Cleared in SelectGroup before
-- ReleaseChildren so we never call methods on a pooled widget.
local _posXSlider, _posYSlider

------------------------------------------------------------
-- AceGUI widget helpers (UnhaltedUnitFrames-style)
------------------------------------------------------------
local function AddHeading(parent, text)
    local h = AceGUI:Create("Heading")
    h:SetText("|cFFFFCC00" .. text .. "|r")
    h:SetFullWidth(true)
    parent:AddChild(h)
    return h
end

local function AddGroup(parent, title)
    local g = AceGUI:Create("InlineGroup")
    g:SetTitle("|cFFFFFFFF" .. title .. "|r")
    g:SetFullWidth(true)
    g:SetLayout("Flow")
    parent:AddChild(g)
    return g
end

local function AddSlider(parent, label, minV, maxV, step, getFn, setFn, width)
    local s = AceGUI:Create("Slider")
    s:SetLabel(label)
    s:SetSliderValues(minV, maxV, step)
    s:SetValue(getFn() or minV)
    s:SetRelativeWidth(width or 0.5)
    s:SetCallback("OnValueChanged", function(_, _, val)
        if step >= 1 then val = math.floor(val + 0.5) end
        setFn(val)
    end)
    parent:AddChild(s)
    return s
end

local function AddCheckbox(parent, label, getFn, setFn, width, desc)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(label)
    cb:SetValue(getFn() and true or false)
    cb:SetRelativeWidth(width or 1)
    if desc then cb:SetDescription(desc) end
    cb:SetCallback("OnValueChanged", function(_, _, val) setFn(val) end)
    parent:AddChild(cb)
    return cb
end

local function AddDropdown(parent, label, items, order, getFn, setFn, width)
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(label)
    dd:SetList(items, order)
    dd:SetValue(getFn())
    dd:SetRelativeWidth(width or 0.5)
    dd:SetCallback("OnValueChanged", function(_, _, key) setFn(key) end)
    parent:AddChild(dd)
    return dd
end

local function AddColorPicker(parent, label, getFn, setFn, width)
    local cp = AceGUI:Create("ColorPicker")
    cp:SetLabel(label)
    local c = getFn() or { r = 1, g = 1, b = 1 }
    cp:SetColor(c.r, c.g, c.b)
    cp:SetRelativeWidth(width or 0.5)
    -- The AceGUI ColorPicker widget only fires OnValueConfirmed when HasAlpha
    -- is true (or on Cancel). For non-alpha swatches we must listen on
    -- OnValueChanged so picks are actually saved when the user clicks OK.
    local function handle(_, _, r, g, b) setFn(r, g, b) end
    cp:SetCallback("OnValueChanged",   handle)
    cp:SetCallback("OnValueConfirmed", handle)
    parent:AddChild(cp)
    return cp
end

------------------------------------------------------------
-- Shared option lists
------------------------------------------------------------
-- Populated by RebuildLocalizedLists(); declared up front so module-local
-- references below close over the same variables when they get rebuilt.
local ANCHOR_LIST, ANCHOR_ORDER
local VISIBILITY_LIST, VISIBILITY_ORDER
local OUTLINE_LIST, OUTLINE_ORDER
local GLOW_LIST, GLOW_ORDER
local LOCALE_LIST, LOCALE_ORDER

local function BuildFontList()
    local list, order = {}, {}
    if DAT.Media and DAT.Media.GetAvailableFonts then
        for _, e in ipairs(DAT.Media:GetAvailableFonts()) do
            list[e.name] = e.name
            order[#order + 1] = e.name
        end
    end
    return list, order
end

local function BuildBorderList()
    local list, order = {}, {}
    if DAT.Media and DAT.Media.GetAvailableBorders then
        for _, e in ipairs(DAT.Media:GetAvailableBorders()) do
            list[e.name] = e.name
            order[#order + 1] = e.name
        end
    end
    return list, order
end

------------------------------------------------------------
-- Page: Main
------------------------------------------------------------
local function BuildPageMain(c)
    local ug = AddGroup(c, L["UI"])
    local uiScaleSlider = AceGUI:Create("Slider")
    uiScaleSlider:SetLabel(L["UI Scale"])
    uiScaleSlider:SetSliderValues(50, 200, 1)
    uiScaleSlider:SetValue(DAT.db.guiScale or 100)
    uiScaleSlider:SetRelativeWidth(0.5)
    -- Apply scale only on mouse-up: while dragging, the slider itself lives
    -- inside the scaled frame, so continuous SetScale calls shift the thumb
    -- under the cursor and feed back into the value, causing flicker.
    uiScaleSlider:SetCallback("OnValueChanged", function(_, _, val)
        DAT.db.guiScale = math.floor(val + 0.5)
    end)
    uiScaleSlider:SetCallback("OnMouseUp", function(_, _, val)
        val = math.floor(val + 0.5)
        DAT.db.guiScale = val
        if _configFrame and _configFrame.frame then
            _configFrame.frame:SetScale(val / 100)
        end
    end)
    ug:AddChild(uiScaleSlider)

    local langDd = AceGUI:Create("Dropdown")
    langDd:SetLabel(L["Language"])
    langDd:SetList(LOCALE_LIST, LOCALE_ORDER)
    langDd:SetValue(DAT.db.locale or "auto")
    langDd:SetRelativeWidth(0.5)
    langDd:SetCallback("OnValueChanged", function(_, _, key)
        DAT.db.locale = key
        StaticPopup_Show("DOATRACKER_LOCALE_RELOAD")
    end)
    ug:AddChild(langDd)

    local ig = AddGroup(c, L["Icon"])
    AddSlider(ig, L["Icon Size"], 32, 128, 1,
        function() return DAT.db.iconSize or 72 end,
        function(v) DAT.db.iconSize = v; DAT:RebuildUI() end)
    AddSlider(ig, L["Icon Zoom"], 0, 30, 1,
        function() return DAT.db.iconZoom or 8 end,
        function(v) DAT.db.iconZoom = v; DAT:ApplyIconZoom() end)
    AddSlider(ig, L["Icon Brightness (%)"], 0, 100, 1,
        function() return DAT.db.iconBrightness or 35 end,
        function(v) DAT.db.iconBrightness = v; DAT:ApplyVisuals() end)
    AddSlider(ig, L["Icon Alpha (%)"], 0, 100, 1,
        function() return DAT.db.iconAlpha or 100 end,
        function(v) DAT.db.iconAlpha = v; DAT:ApplyVisuals() end)

    local pg = AddGroup(c, L["Position"])
    local maxX = math.floor(GetScreenWidth()  + 0.5)
    local maxY = math.floor(GetScreenHeight() + 0.5)
    _posXSlider = AddSlider(pg, L["Position X"], 0, maxX, 1,
        function() return math.floor((DAT.db.posX or 0) + 0.5) end,
        function(v) DAT.db.posX = v; DAT:ApplyFramePosition() end)
    _posYSlider = AddSlider(pg, L["Position Y"], 0, maxY, 1,
        function() return math.floor((DAT.db.posY or 0) + 0.5) end,
        function(v) DAT.db.posY = v; DAT:ApplyFramePosition() end)
    _posXSlider:SetDisabled(DAT.db.locked and true or false)
    _posYSlider:SetDisabled(DAT.db.locked and true or false)
    AddCheckbox(pg, L["Lock Position"],
        function() return DAT.db.locked end,
        function(v)
            DAT.db.locked = v
            DAT:RebuildUI()
            if _posXSlider then _posXSlider:SetDisabled(v and true or false) end
            if _posYSlider then _posYSlider:SetDisabled(v and true or false) end
        end, 1)

    local dg = AddGroup(c, L["Display"])
    AddDropdown(dg, L["Show Tracker"], VISIBILITY_LIST, VISIBILITY_ORDER,
        function() return DAT.db.visibilityMode or "always" end,
        function(v) DAT.db.visibilityMode = v; DAT:UpdateVisibility() end)
    local hideGroup = {}
    AddCheckbox(dg, L["Hide When No Buff"],
        function() return DAT.db.hideWhenNoBuff or false end,
        function(v)
            DAT.db.hideWhenNoBuff = v
            DAT:UpdateVisibility()
            local dis = not v
            for _, w in ipairs(hideGroup) do w:SetDisabled(dis) end
        end,
        0.5)
    hideGroup[#hideGroup+1] = AddSlider(dg, L["Hide Delay (sec)"], 0, 30, 1,
        function() return DAT.db.hideDelaySec or 0 end,
        function(v) DAT.db.hideDelaySec = v end,
        0.5)
    do
        local dis = not DAT.db.hideWhenNoBuff
        for _, w in ipairs(hideGroup) do w:SetDisabled(dis) end
    end
    AddSlider(dg, L["Count Reset Delay (sec)"], 0, 60, 1,
        function() return DAT.db.countLingerSec or 0 end,
        function(v) DAT.db.countLingerSec = v end,
        0.5)
end

------------------------------------------------------------
-- Page: Fonts
------------------------------------------------------------
local function BuildPageFonts(c)
    local fg = AddGroup(c, L["Font"])
    local fontList, fontOrder = BuildFontList()
    AddDropdown(fg, L["Font"], fontList, fontOrder,
        function() return DAT.db.fontName or "Default" end,
        function(v)
            for _, e in ipairs(DAT.Media:GetAvailableFonts()) do
                if e.name == v then
                    DAT.db.fontPath    = e.path
                    DAT.db.fontName    = e.name
                    DAT.Media.font     = e.path
                    DAT.Media.fontName = e.name
                    break
                end
            end
            DAT:RebuildUI()
        end, 1)
    AddDropdown(fg, L["Outline"], OUTLINE_LIST, OUTLINE_ORDER,
        function() return DAT.db.fontFlags or "OUTLINE" end,
        function(v) DAT.db.fontFlags = v; DAT:RebuildUI() end)
    local shadowGroup = {}
    AddCheckbox(fg, L["Shadow"],
        function() return DAT.db.shadowEnabled or false end,
        function(v)
            DAT.db.shadowEnabled = v
            DAT:ApplyShadow()
            local dis = not v
            for _, w in ipairs(shadowGroup) do w:SetDisabled(dis) end
        end, 0.5)
    shadowGroup[#shadowGroup+1] = AddSlider(fg, L["Shadow X Offset"], -5, 5, 1,
        function() return DAT.db.shadowOffsetX or 1 end,
        function(v) DAT.db.shadowOffsetX = v; DAT:ApplyShadow() end)
    shadowGroup[#shadowGroup+1] = AddSlider(fg, L["Shadow Y Offset"], -5, 5, 1,
        function() return DAT.db.shadowOffsetY or -1 end,
        function(v) DAT.db.shadowOffsetY = v; DAT:ApplyShadow() end)
    shadowGroup[#shadowGroup+1] = AddColorPicker(fg, L["Shadow Color"],
        function() return DAT.db.shadowColor or { r=0, g=0, b=0 } end,
        function(r, g, b)
            DAT.db.shadowColor = { r=r, g=g, b=b }
            DAT:ApplyShadow()
        end)
    do
        local dis = not DAT.db.shadowEnabled
        for _, w in ipairs(shadowGroup) do w:SetDisabled(dis) end
    end

    local cg = AddGroup(c, L["Count Text"])
    AddSlider(cg, L["Font Size"], 8, 60, 1,
        function() return DAT.db.countFontSize or 28 end,
        function(v) DAT.db.countFontSize = v; DAT:RebuildUI() end)
    AddDropdown(cg, L["Anchor"], ANCHOR_LIST, ANCHOR_ORDER,
        function() return DAT.db.countAnchor or "CENTER" end,
        function(v) DAT.db.countAnchor = v; DAT:RebuildUI() end)
    AddSlider(cg, L["Offset X"], -100, 100, 1,
        function() return DAT.db.countOffsetX or 0 end,
        function(v) DAT.db.countOffsetX = v; DAT:RebuildUI() end)
    AddSlider(cg, L["Offset Y"], -100, 100, 1,
        function() return DAT.db.countOffsetY or 0 end,
        function(v) DAT.db.countOffsetY = v; DAT:RebuildUI() end)

    local dg = AddGroup(c, L["Demon Count Text"])
    AddSlider(dg, L["Font Size"], 6, 60, 1,
        function() return DAT.db.demonFontSize or 13 end,
        function(v) DAT.db.demonFontSize = v; DAT:RebuildUI() end)
    AddDropdown(dg, L["Anchor"], ANCHOR_LIST, ANCHOR_ORDER,
        function() return DAT.db.demonAnchor or "TOP" end,
        function(v) DAT.db.demonAnchor = v; DAT:RebuildUI() end)
    AddSlider(dg, L["Offset X"], -100, 100, 1,
        function() return DAT.db.demonOffsetX or 0 end,
        function(v) DAT.db.demonOffsetX = v; DAT:RebuildUI() end)
    AddSlider(dg, L["Offset Y"], -100, 100, 1,
        function() return DAT.db.demonOffsetY or 0 end,
        function(v) DAT.db.demonOffsetY = v; DAT:RebuildUI() end)

    local tg = AddGroup(c, L["Timer Text"])
    AddSlider(tg, L["Font Size"], 6, 60, 1,
        function() return DAT.db.timerFontSize or 13 end,
        function(v) DAT.db.timerFontSize = v; DAT:RebuildUI() end)
    AddDropdown(tg, L["Anchor"], ANCHOR_LIST, ANCHOR_ORDER,
        function() return DAT.db.timerAnchor or "BOTTOM" end,
        function(v) DAT.db.timerAnchor = v; DAT:RebuildUI() end)
    AddSlider(tg, L["Offset X"], -100, 100, 1,
        function() return DAT.db.timerOffsetX or 0 end,
        function(v) DAT.db.timerOffsetX = v; DAT:RebuildUI() end)
    AddSlider(tg, L["Offset Y"], -100, 100, 1,
        function() return DAT.db.timerOffsetY or 0 end,
        function(v) DAT.db.timerOffsetY = v; DAT:RebuildUI() end)
    AddCheckbox(tg, L["Show \"s\" Suffix"],
        function() return DAT.db.timerShowSuffix ~= false end,
        function(v) DAT.db.timerShowSuffix = v end, 1)
end

------------------------------------------------------------
-- Page: Border
------------------------------------------------------------
local function BuildPageBorder(c)
    local g = AddGroup(c, L["Border Style"])
    local bList, bOrder = BuildBorderList()
    AddDropdown(g, L["Border"], bList, bOrder,
        function() return DAT.db.borderName or "None" end,
        function(v)
            for _, e in ipairs(DAT.Media:GetAvailableBorders()) do
                if e.name == v then
                    DAT.db.borderPath = e.path
                    DAT.db.borderName = e.name
                    DAT:ApplyBorder()
                    break
                end
            end
        end, 1)
    AddSlider(g, L["Border Size (px)"], 1, 32, 1,
        function() return DAT.db.borderSize or 12 end,
        function(v) DAT.db.borderSize = v; DAT:ApplyBorder() end)
    AddSlider(g, L["Border Offset (px)"], -16, 32, 1,
        function() return DAT.db.borderOffset or 0 end,
        function(v) DAT.db.borderOffset = v; DAT:ApplyBorder() end)

    local cg = AddGroup(c, L["Border Colors"])
    AddColorPicker(cg, L["Active Border"],
        function() return DAT.db.borderColor or { r=0.1, g=0.9, b=0.1 } end,
        function(r, g, b)
            DAT.db.borderColor = { r=r, g=g, b=b }
            DAT:ApplyBorderColor()
        end)
    AddColorPicker(cg, L["Inactive Border"],
        function() return DAT.db.inactBorderColor or { r=0.15, g=0.15, b=0.15 } end,
        function(r, g, b)
            DAT.db.inactBorderColor = { r=r, g=g, b=b }
            DAT:ApplyBorderColor()
        end)
end

------------------------------------------------------------
-- Page: Colors
------------------------------------------------------------
local function BuildPageColors(c)
    local g = AddGroup(c, L["Count Colors"])
    AddColorPicker(g, L["Active Count"],
        function() return DAT.db.activeCountColor or { r=0.15, g=1.0, b=0.15 } end,
        function(r, g, b)
            DAT.db.activeCountColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)
    AddColorPicker(g, L["Inactive Count"],
        function() return DAT.db.inactCountColor or { r=0.55, g=0.55, b=0.55 } end,
        function(r, g, b)
            DAT.db.inactCountColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    local dg = AddGroup(c, L["Demon Count Colors"])
    AddColorPicker(dg, L["Active Demon Count"],
        function() return DAT.db.activeDemonColor or { r=1.0, g=0.84, b=0.0 } end,
        function(r, g, b)
            DAT.db.activeDemonColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)
    AddColorPicker(dg, L["Inactive Demon Count"],
        function() return DAT.db.inactDemonColor or { r=0.55, g=0.55, b=0.55 } end,
        function(r, g, b)
            DAT.db.inactDemonColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    local tg = AddGroup(c, L["Timer Colors"])
    AddColorPicker(tg, L["Timer"],
        function() return DAT.db.timerColor or { r=1.0, g=0.82, b=0.0 } end,
        function(r, g, b)
            DAT.db.timerColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)
    local warnGroup = {}
    AddCheckbox(tg, L["Enable Timer Warning Color"],
        function() return DAT.db.timerWarnEnabled ~= false end,
        function(v)
            DAT.db.timerWarnEnabled = v
            local dis = not v
            for _, w in ipairs(warnGroup) do w:SetDisabled(dis) end
        end, 1,
        L["Change the timer text color when time is running low."])
    warnGroup[#warnGroup+1] = AddSlider(tg, L["Warn When <= (sec)"], 1, 20, 1,
        function() return DAT.db.timerWarnThreshold or 5 end,
        function(v) DAT.db.timerWarnThreshold = v end)
    warnGroup[#warnGroup+1] = AddColorPicker(tg, L["Timer Warning"],
        function() return DAT.db.timerWarnColor or { r=1.0, g=0.2, b=0.2 } end,
        function(r, g, b)
            DAT.db.timerWarnColor = { r=r, g=g, b=b }
        end)
    do
        local dis = (DAT.db.timerWarnEnabled == false)
        for _, w in ipairs(warnGroup) do w:SetDisabled(dis) end
    end
end

------------------------------------------------------------
-- Page: Glow
------------------------------------------------------------
local function BuildPageGlow(c)
    local g = AddGroup(c, L["Glow"])
    local glowGroup = {}
    AddCheckbox(g, L["Enable Glow"],
        function() return DAT.db.glowEnabled or false end,
        function(v)
            DAT.db.glowEnabled = v
            DAT:ApplyGlow(DAT._dominionActive)
            local dis = not v
            for _, w in ipairs(glowGroup) do w:SetDisabled(dis) end
        end, 1)
    glowGroup[#glowGroup+1] = AddDropdown(g, L["Glow Type"], GLOW_LIST, GLOW_ORDER,
        function() return DAT.db.glowType or "proc" end,
        function(v)
            local prev = DAT.db.glowType
            DAT.db.glowType = v
            DAT:ApplyGlow(DAT._dominionActive)
            if (prev == "pixel") ~= (v == "pixel") and RefreshPage then
                RefreshPage("glow")
            end
        end)
    glowGroup[#glowGroup+1] = AddColorPicker(g, L["Glow Color"],
        function() return DAT.db.glowColor or { r=1.0, g=0.84, b=0.0 } end,
        function(r, g, b)
            DAT.db.glowColor = { r=r, g=g, b=b }
            DAT:ApplyGlow(DAT._dominionActive)
        end)

    if DAT.db.glowType == "pixel" then
        local pg = AddGroup(c, L["Pixel Glow Options"])
        glowGroup[#glowGroup+1] = AddSlider(pg, L["Lines"], 1, 20, 1,
            function() return DAT.db.glowPixelN or 8 end,
            function(v) DAT.db.glowPixelN = v; DAT:ApplyGlow(DAT._dominionActive) end)
        glowGroup[#glowGroup+1] = AddSlider(pg, L["Frequency"], 0.01, 2, 0.01,
            function() return DAT.db.glowPixelFreq or 0.25 end,
            function(v) DAT.db.glowPixelFreq = v; DAT:ApplyGlow(DAT._dominionActive) end)
        glowGroup[#glowGroup+1] = AddSlider(pg, L["Length (0=auto)"], 0, 20, 1,
            function() return DAT.db.glowPixelLength or 3 end,
            function(v) DAT.db.glowPixelLength = v; DAT:ApplyGlow(DAT._dominionActive) end)
        glowGroup[#glowGroup+1] = AddSlider(pg, L["Thickness"], 1, 10, 1,
            function() return DAT.db.glowPixelThick or 2 end,
            function(v) DAT.db.glowPixelThick = v; DAT:ApplyGlow(DAT._dominionActive) end)
        glowGroup[#glowGroup+1] = AddSlider(pg, L["X Offset"], -20, 20, 1,
            function() return DAT.db.glowPixelXOffset or 0 end,
            function(v) DAT.db.glowPixelXOffset = v; DAT:ApplyGlow(DAT._dominionActive) end)
        glowGroup[#glowGroup+1] = AddSlider(pg, L["Y Offset"], -20, 20, 1,
            function() return DAT.db.glowPixelYOffset or 0 end,
            function(v) DAT.db.glowPixelYOffset = v; DAT:ApplyGlow(DAT._dominionActive) end)
    end

    do
        local dis = not DAT.db.glowEnabled
        for _, w in ipairs(glowGroup) do w:SetDisabled(dis) end
    end
end

------------------------------------------------------------
-- Announce Rules Editor
------------------------------------------------------------
-- Populated by RebuildLocalizedLists()
local RULE_CONDITIONS, DOMINION_OPERATORS, COUNT_OPERATORS
local COUNT_CONDITIONS, LOGIC_OPERATORS, RULE_CHANNELS

local function ConditionNeedsThreshold(cond)
    return cond ~= "dominion"
end

local function OperatorsForCondition(cond)
    if cond == "dominion" then return DOMINION_OPERATORS end
    return COUNT_OPERATORS
end

local function DefaultOperator(cond)
    if cond == "dominion" then return "start" end
    return ">="
end

local function LabelForKey(list, key)
    for _, v in ipairs(list) do
        if v.key == key then return v.label end
    end
    return key or "—"
end

------------------------------------------------------------
-- AceGUI list builders for rule constants
------------------------------------------------------------
local function ListFromArray(arr)
    local list, order = {}, {}
    for _, v in ipairs(arr) do
        list[v.key] = v.label
        order[#order + 1] = v.key
    end
    return list, order
end

local LOGIC_LIST,    LOGIC_ORDER
local CHANNEL_LIST,  CHANNEL_ORDER
local RULE_COND_LIST_FIRST, RULE_COND_ORDER_FIRST
local RULE_COND_LIST_EXTRA, RULE_COND_ORDER_EXTRA
local DOMINION_OP_LIST, DOMINION_OP_ORDER
local COUNT_OP_LIST,    COUNT_OP_ORDER

local function RebuildLocalizedLists()
    ANCHOR_LIST = {
        CENTER = L["Center"], TOP = L["Top"], BOTTOM = L["Bottom"],
        LEFT = L["Left"], RIGHT = L["Right"],
    }
    ANCHOR_ORDER = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT" }

    VISIBILITY_LIST = {
        always   = L["Always"],
        combat   = L["In Combat Only"],
        nocombat = L["Out of Combat Only"],
        never    = L["Never"],
    }
    VISIBILITY_ORDER = { "always", "combat", "nocombat", "never" }

    OUTLINE_LIST = {
        ["OUTLINE"]                  = L["Outline"],
        ["THICKOUTLINE"]             = L["Thick Outline"],
        ["MONOCHROME"]               = L["Monochrome"],
        ["OUTLINE, MONOCHROME"]      = L["Outline + Monochrome"],
        ["THICKOUTLINE, MONOCHROME"] = L["Thick + Monochrome"],
        [""]                         = L["None"],
    }
    OUTLINE_ORDER = {
        "OUTLINE", "THICKOUTLINE", "MONOCHROME",
        "OUTLINE, MONOCHROME", "THICKOUTLINE, MONOCHROME", "",
    }

    GLOW_LIST = {
        proc = L["Proc Glow"], pixel = L["Pixel Glow"],
        autocast = L["Autocast Glow"], button = L["Button Glow"],
    }
    GLOW_ORDER = { "proc", "pixel", "autocast", "button" }

    LOCALE_LIST, LOCALE_ORDER = {}, {}
    for _, ch in ipairs(DAT.LOCALE_CHOICES or {}) do
        LOCALE_LIST[ch.key] = (ch.key == "auto") and L["Auto (Client)"] or ch.label
        LOCALE_ORDER[#LOCALE_ORDER + 1] = ch.key
    end

    RULE_CONDITIONS = {
        { key = "dominion", label = L["Dominion"] },
        { key = "hog",      label = L["HoG Count"] },
        { key = "demon",    label = L["Demons"] },
    }
    DOMINION_OPERATORS = {
        { key = "start", label = L["Start"] },
        { key = "end",   label = L["End"] },
    }
    COUNT_OPERATORS = {
        { key = ">",  label = ">" },  { key = ">=", label = ">=" },
        { key = "<",  label = "<" },  { key = "<=", label = "<=" },
        { key = "=",  label = "=" },
    }
    COUNT_CONDITIONS = {
        { key = "hog",   label = L["HoG Count"] },
        { key = "demon", label = L["Demons"] },
    }
    LOGIC_OPERATORS = {
        { key = "and", label = L["AND"] },
        { key = "or",  label = L["OR"] },
    }
    RULE_CHANNELS = {
        { key = "SYSTEM", label = L["System"] },
        { key = "PARTY",  label = L["Party"] },
        { key = "SAY",    label = L["Say"] },
        { key = "YELL",   label = L["Yell"] },
    }

    local popup = StaticPopupDialogs["DOATRACKER_LOCALE_RELOAD"]
    popup.text    = L["Language change requires reloading the UI. Reload now?"]
    popup.button1 = L["Reload"]
    popup.button2 = L["Later"]

    LOGIC_LIST,   LOGIC_ORDER   = ListFromArray(LOGIC_OPERATORS)
    CHANNEL_LIST, CHANNEL_ORDER = ListFromArray(RULE_CHANNELS)
    RULE_COND_LIST_FIRST, RULE_COND_ORDER_FIRST = ListFromArray(RULE_CONDITIONS)
    RULE_COND_LIST_EXTRA, RULE_COND_ORDER_EXTRA = ListFromArray(COUNT_CONDITIONS)
    DOMINION_OP_LIST, DOMINION_OP_ORDER = ListFromArray(DOMINION_OPERATORS)
    COUNT_OP_LIST,    COUNT_OP_ORDER    = ListFromArray(COUNT_OPERATORS)
end

-- Initial build with whatever L has right now (likely fallback keys, since
-- SavedVariables aren't restored until ADDON_LOADED). LoadLocale fires the
-- hook again after the locale table is applied inside Initialize().
RebuildLocalizedLists()
if DAT.RegisterLocaleHook then DAT.RegisterLocaleHook(RebuildLocalizedLists) end

local function OperatorListForCondition(cond)
    if cond == "dominion" then
        return DOMINION_OP_LIST, DOMINION_OP_ORDER
    end
    return COUNT_OP_LIST, COUNT_OP_ORDER
end

------------------------------------------------------------
-- Announce rule condition row
------------------------------------------------------------
local function BuildConditionRow(parent, ruleIdx, condIdx, cond, isFirst, collect)
    local function track(w) if collect then collect[#collect+1] = w end end

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    parent:AddChild(row)

    -- Logic / "If" prefix
    if isFirst then
        local lbl = AceGUI:Create("Label")
        lbl:SetText("  |cffffd700" .. L["If"] .. "|r")
        lbl:SetFontObject(GameFontHighlight)
        lbl:SetRelativeWidth(0.12)
        row:AddChild(lbl)
    else
        local logicDd = AceGUI:Create("Dropdown")
        logicDd:SetLabel("")
        logicDd:SetList(LOGIC_LIST, LOGIC_ORDER)
        logicDd:SetValue(cond.logic or "and")
        logicDd:SetRelativeWidth(0.12)
        logicDd:SetCallback("OnValueChanged", function(_, _, key) cond.logic = key end)
        row:AddChild(logicDd)
        track(logicDd)
    end

    -- Condition type dropdown
    local condList, condOrder
    if isFirst then
        condList, condOrder = RULE_COND_LIST_FIRST, RULE_COND_ORDER_FIRST
    else
        condList, condOrder = RULE_COND_LIST_EXTRA, RULE_COND_ORDER_EXTRA
    end
    local condDd = AceGUI:Create("Dropdown")
    condDd:SetLabel("")
    condDd:SetList(condList, condOrder)
    condDd:SetValue(cond.condition or (isFirst and "dominion" or "hog"))
    condDd:SetRelativeWidth(0.28)
    condDd:SetCallback("OnValueChanged", function(_, _, key)
        cond.condition = key
        cond.operator = DefaultOperator(key)
        if isFirst and key == "dominion" then
            local rule = DAT.db.announceRules[ruleIdx]
            while #rule.conditions > 1 do
                table.remove(rule.conditions)
            end
        end
        if RefreshPage then RefreshPage("announce") end
    end)
    row:AddChild(condDd)
    track(condDd)

    -- Operator dropdown
    local opList, opOrder = OperatorListForCondition(cond.condition or "dominion")
    local opDd = AceGUI:Create("Dropdown")
    opDd:SetLabel("")
    opDd:SetList(opList, opOrder)
    opDd:SetValue(cond.operator or DefaultOperator(cond.condition or "dominion"))
    opDd:SetRelativeWidth(0.2)
    opDd:SetCallback("OnValueChanged", function(_, _, key) cond.operator = key end)
    row:AddChild(opDd)
    track(opDd)

    -- Threshold editbox (hidden for dominion)
    if ConditionNeedsThreshold(cond.condition or "dominion") then
        local eb = AceGUI:Create("EditBox")
        eb:SetLabel("")
        eb:SetText(tostring(cond.threshold or 0))
        eb:SetRelativeWidth(0.2)
        eb:SetCallback("OnEnterPressed", function(_, _, text)
            cond.threshold = tonumber(text) or 0
        end)
        eb.editbox:SetFontObject(GameFontHighlightSmall)
        row:AddChild(eb)
        track(eb)
    else
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetRelativeWidth(0.2)
        row:AddChild(spacer)
    end

    -- Delete-condition button (only for non-first rows)
    if not isFirst then
        local delBtn = AceGUI:Create("Button")
        delBtn:SetText("X")
        delBtn:SetWidth(24)
        delBtn:SetHeight(24)
        delBtn.text:ClearAllPoints()
        delBtn.text:SetPoint("TOPLEFT", 2, -1)
        delBtn.text:SetPoint("BOTTOMRIGHT", -2, 1)
        delBtn.text:SetJustifyH("CENTER")
        delBtn.text:SetJustifyV("MIDDLE")
        delBtn.alignoffset = 10
        delBtn:SetCallback("OnClick", function()
            local rule = DAT.db.announceRules[ruleIdx]
            table.remove(rule.conditions, condIdx)
            if RefreshPage then RefreshPage("announce") end
        end)
        row:AddChild(delBtn)
        track(delBtn)
    end
end

------------------------------------------------------------
-- Announce rule card
------------------------------------------------------------
local function BuildRuleCard(parent, ruleIdx, rule)
    local card = AceGUI:Create("InlineGroup")
    card:SetTitle(L["Announcement"] .. " " .. ruleIdx)
    card:SetLayout("List")
    card:SetFullWidth(true)
    parent:AddChild(card)

    local conds = rule.conditions or {}
    local isDominion = (#conds > 0 and conds[1].condition == "dominion")

    -- Widgets that get disabled when the rule's Enabled checkbox is off.
    -- Delete button is intentionally excluded so disabled rules can still
    -- be removed.
    local ruleGroup = {}

    -- Header row: enable / channel / delete
    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("Flow")
    header:SetFullWidth(true)
    card:AddChild(header)

    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(L["Enabled"])
    cb:SetValue(rule.enabled and true or false)
    cb:SetRelativeWidth(0.3)
    cb:SetCallback("OnValueChanged", function(_, _, v)
        rule.enabled = v
        local dis = not v
        for _, w in ipairs(ruleGroup) do w:SetDisabled(dis) end
    end)
    header:AddChild(cb)

    local chanDd = AceGUI:Create("Dropdown")
    chanDd:SetLabel("")
    chanDd:SetList(CHANNEL_LIST, CHANNEL_ORDER)
    chanDd:SetValue(rule.channel or "SYSTEM")
    chanDd:SetRelativeWidth(0.4)
    chanDd:SetCallback("OnValueChanged", function(_, _, key) rule.channel = key end)
    header:AddChild(chanDd)
    ruleGroup[#ruleGroup+1] = chanDd

    local delRule = AceGUI:Create("Button")
    delRule:SetText(L["Delete"])
    delRule:SetRelativeWidth(0.3)
    delRule:SetHeight(24)
    delRule:SetCallback("OnClick", function()
        table.remove(DAT.db.announceRules, ruleIdx)
        if RefreshPage then RefreshPage("announce") end
    end)
    delRule.alignoffset = 10
    header:AddChild(delRule)

    -- Condition rows
    for ci, cond in ipairs(conds) do
        BuildConditionRow(card, ruleIdx, ci, cond, ci == 1, ruleGroup)
    end

    -- "+ Add Condition" (hidden for dominion rules)
    if not isDominion then
        local spacer = AceGUI:Create("SimpleGroup")
        spacer.noAutoHeight = true
        spacer:SetFullWidth(true)
        spacer:SetHeight(4)
        card:AddChild(spacer)

        local addCondBtn = AceGUI:Create("Button")
        addCondBtn:SetText(L["+ Add Condition"])
        addCondBtn:SetRelativeWidth(0.5)
        addCondBtn:SetCallback("OnClick", function()
            table.insert(rule.conditions, {
                logic = "and", condition = "hog", operator = ">=", threshold = 0,
            })
            if RefreshPage then RefreshPage("announce") end
        end)
        card:AddChild(addCondBtn)
        ruleGroup[#ruleGroup+1] = addCondBtn
    end

    -- Message editbox (full width)
    local msgEb = AceGUI:Create("EditBox")
    msgEb:SetLabel(L["Message"])
    msgEb:SetText(rule.msg or "")
    msgEb:SetFullWidth(true)
    msgEb:SetCallback("OnEnterPressed", function(_, _, text) rule.msg = text end)
    msgEb.editbox:SetFontObject(ChatFontNormal)
    card:AddChild(msgEb)
    ruleGroup[#ruleGroup+1] = msgEb

    -- Apply initial disabled state
    do
        local dis = not rule.enabled
        for _, w in ipairs(ruleGroup) do w:SetDisabled(dis) end
    end
end

------------------------------------------------------------
-- Page: Announce
------------------------------------------------------------
local function BuildPageAnnounce(c)
    local intro = AddGroup(c, L["Announcement"])

    local hint = AceGUI:Create("Label")
    hint:SetText(L["Tags:\n- |cffffd700{count:hog}|r: Hand of Gul'dan casts\n- |cffffd700{count:demon}|r: Demons summoned"])
    hint:SetFullWidth(true)
    hint:SetFontObject(GameFontHighlight)
    intro:AddChild(hint)

    local gap = AceGUI:Create("SimpleGroup")
    gap.noAutoHeight = true
    gap:SetFullWidth(true)
    gap:SetHeight(6)
    intro:AddChild(gap)

    local note = AceGUI:Create("Label")
    note:SetText(L["|cffaaaaaaNote: Say and Yell only work inside instances.|r"])
    note:SetFullWidth(true)
    note:SetFontObject(GameFontHighlight)
    intro:AddChild(note)

    local gap2 = AceGUI:Create("SimpleGroup")
    gap2.noAutoHeight = true
    gap2:SetFullWidth(true)
    gap2:SetHeight(8)
    intro:AddChild(gap2)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L["+ Add Announcement"])
    addBtn:SetRelativeWidth(0.5)
    addBtn:SetCallback("OnClick", function()
        local rules = DAT.db.announceRules
        if not rules then rules = {}; DAT.db.announceRules = rules end
        table.insert(rules, {
            enabled = true, channel = "SYSTEM", msg = "",
            conditions = {
                { condition = "dominion", operator = "end", threshold = 0 },
            },
        })
        if RefreshPage then RefreshPage("announce") end
    end)
    intro:AddChild(addBtn)

    local rules = DAT.db.announceRules or {}
    if #rules == 0 then
        local empty = AceGUI:Create("Label")
        empty:SetText(L["|cff888888No rules configured. Click '+ Add Announcement' above.|r"])
        empty:SetFullWidth(true)
        c:AddChild(empty)
    else
        for i, rule in ipairs(rules) do
            BuildRuleCard(c, i, rule)
        end
    end
end

------------------------------------------------------------
-- Main config window (AceGUI Frame + TreeGroup)
------------------------------------------------------------
-- textKey is resolved through L at BuildTree time so the tree picks up the
-- active locale after LoadLocale runs inside Initialize.
local PAGES = {
    { value = "main",     textKey = "Main",         build = BuildPageMain     },
    { value = "fonts",    textKey = "Fonts",        build = BuildPageFonts    },
    { value = "border",   textKey = "Border",       build = BuildPageBorder   },
    { value = "colors",   textKey = "Colors",       build = BuildPageColors   },
    { value = "glow",     textKey = "Glow",         build = BuildPageGlow     },
    { value = "announce", textKey = "Announcement", build = BuildPageAnnounce },
}

local _configStatus = {}
local _scrollStatus = {}

local function BuildTree()
    local t = {}
    for _, p in ipairs(PAGES) do
        t[#t + 1] = { value = p.value, text = L[p.textKey] }
    end
    return t
end

local function SelectGroup(container, _, value)
    _posXSlider, _posYSlider = nil, nil
    container:ReleaseChildren()
    for _, p in ipairs(PAGES) do
        if p.value == value then
            local scroll = AceGUI:Create("ScrollFrame")
            scroll:SetLayout("Flow")
            scroll:SetFullWidth(true)
            scroll:SetFullHeight(true)
            _scrollStatus[value] = _scrollStatus[value] or {}
            scroll:SetStatusTable(_scrollStatus[value])
            container:AddChild(scroll)
            p.build(scroll)
            scroll:DoLayout()
            break
        end
    end
end

RefreshPage = function(value)
    if _currentTree then
        _configStatus.selected = value
        _currentTree:SelectByValue(value)
        SelectGroup(_currentTree, nil, value)
    end
end

function DAT.Config:Open()
    if not AceGUI then
        print(L["|cff9482c9[DoA Tracker]|r AceGUI-3.0 is not available."])
        return
    end
    if _configFrame then
        _configFrame:Show()
        return
    end

    local f = AceGUI:Create("Frame")
    f:SetTitle("|cffffffffDoA Tracker|r")
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = (getMeta and getMeta("DoATracker", "Version")) or ""
    f:SetStatusText("DoATracker v" .. version .. " - by whereismytakoyaki")
    f:SetLayout("Fill")
    f:SetWidth(760)
    f:SetHeight(560)

    -- Enlarge the title text and nudge it down a touch
    if f.titletext then
        f.titletext:SetFontObject(GameFontNormalLarge)
        f.titletext:ClearAllPoints()
        f.titletext:SetPoint("TOP", f.titlebg, "TOP", 0, -18)
        f:SetTitle("|cffffffffDoA Tracker|r")
    end
    f:EnableResize(false)
    f:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        _configFrame = nil
        _currentTree = nil
        _posXSlider, _posYSlider = nil, nil
    end)
    _configFrame = f

    if f.frame then
        f.frame:SetScale((DAT.db.guiScale or 100) / 100)
    end

    local tree = AceGUI:Create("TreeGroup")
    tree:SetLayout("Fill")
    tree:SetFullWidth(true)
    tree:SetFullHeight(true)
    tree:SetStatusTable(_configStatus)
    tree:SetTreeWidth(150, false)
    tree:SetTree(BuildTree())
    tree:SetCallback("OnGroupSelected", SelectGroup)
    f:AddChild(tree)
    _currentTree = tree

    tree:SelectByValue(_configStatus.selected or "main")
end

function DAT.Config:Close()
    if _configFrame then _configFrame:Hide() end
end

-- Push the live posX/posY back into the open Main page sliders. Called
-- from the frame's OnDragStop so the UI reflects the new position while
-- the config window is open. No-op if the user isn't currently viewing
-- the Main page (refs are cleared in SelectGroup / OnClose).
function DAT.Config:UpdatePositionSliders()
    if _posXSlider then
        _posXSlider:SetValue(math.floor((DAT.db.posX or 0) + 0.5))
    end
    if _posYSlider then
        _posYSlider:SetValue(math.floor((DAT.db.posY or 0) + 0.5))
    end
end

-- Kept for backwards-compatibility; Blizzard Settings panel removed.
function DAT.Config:Register() end
