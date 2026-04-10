DAT        = DAT or {}
DAT.Config = DAT.Config or {}

------------------------------------------------------------
-- Helper: section header
------------------------------------------------------------
local function SectionHeader(cat, text)
    local layout = SettingsPanel:GetLayout(cat)
    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = "|cff9482c9" .. text .. "|r" }))
end

------------------------------------------------------------
-- Helper: slider
------------------------------------------------------------
local function MakeSlider(cat, varKey, name, default,
                           minV, maxV, step, fmtFn,
                           getVal, setVal, tooltip)
    local setting = Settings.RegisterProxySetting(cat, varKey,
        Settings.VarType.Number, name, default, getVal, setVal)
    local opts = Settings.CreateSliderOptions(minV, maxV, step)
    if fmtFn then
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmtFn)
    end
    Settings.CreateSlider(cat, setting, opts, tooltip)
    return setting
end

------------------------------------------------------------
-- Helper: checkbox
------------------------------------------------------------
local function MakeCheckbox(cat, varKey, name, default, getVal, setVal, tooltip)
    local setting = Settings.RegisterProxySetting(cat, varKey,
        Settings.VarType.Boolean, name, default, getVal, setVal)
    Settings.CreateCheckbox(cat, setting, tooltip)
    return setting
end

------------------------------------------------------------
-- Helper: dropdown
------------------------------------------------------------
local function MakeDropdown(cat, varKey, name, default, getVal, setVal, optsFn, tooltip)
    local setting = Settings.RegisterProxySetting(cat, varKey,
        Settings.VarType.String, name, default, getVal, setVal)
    Settings.CreateDropdown(cat, setting, optsFn, tooltip)
    return setting
end

------------------------------------------------------------
-- Combined hook: injects color swatches and text inputs into
-- SettingsListSectionHeaderTemplate rows via _colorGetFn / _textGetFn.
------------------------------------------------------------
local _settingsHookDone = false
local function EnsureSettingsHook()
    if _settingsHookDone then return end
    if not SettingsListSectionHeaderMixin then return end
    _settingsHookDone = true

    hooksecurefunc(SettingsListSectionHeaderMixin, "Init", function(self, initializer)
        -- Hide injected controls from any previous row reuse
        if self._datColorBtn  then self._datColorBtn:Hide()  end
        if self._datTextInput then self._datTextInput:Hide() end
        if self._datButton    then self._datButton:Hide()    end

        local data = initializer and initializer.GetData and initializer:GetData()
        if not data then return end

        -- ── Color swatch ──────────────────────────────────────────
        if data._colorGetFn then
            if not self._datColorBtn then
                local btn = CreateFrame("Button", nil, self, "BackdropTemplate")
                btn:SetSize(20, 20)
                btn:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                btn:SetPoint("RIGHT", self, "RIGHT", -20, 0)
                self._datColorBtn = btn
            end

            local btn   = self._datColorBtn
            local getFn = data._colorGetFn
            local setFn = data._colorSetFn
            local c = getFn()
            btn:SetBackdropColor(c.r, c.g, c.b, 1)
            btn:Show()

            btn:SetScript("OnClick", function()
                local cur = getFn()
                local info = {
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        setFn(r, g, b)
                        btn:SetBackdropColor(r, g, b, 1)
                    end,
                    cancelFunc = function(prev)
                        setFn(prev.r, prev.g, prev.b)
                        btn:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                    end,
                    r = cur.r, g = cur.g, b = cur.b,
                    hasOpacity = false,
                    previousValues = { r = cur.r, g = cur.g, b = cur.b },
                }
                ColorPickerFrame:SetupColorPickerAndShow(info)
            end)
        end

        -- ── Button ────────────────────────────────────────────────
        if data._buttonOnClick then
            if not self._datButton then
                local btn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
                btn:SetSize(160, 24)
                btn:SetPoint("RIGHT", self, "RIGHT", -10, 0)
                self._datButton = btn
            end
            self._datButton:SetText(data._buttonLabel or "Open")
            self._datButton:SetScript("OnClick", data._buttonOnClick)
            self._datButton:Show()
        end

        -- ── Text input ────────────────────────────────────────────
        if data._textGetFn then
            if not self._datTextInput then
                local eb = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
                eb:SetSize(220, 20)
                eb:SetPoint("RIGHT", self, "RIGHT", -10, 0)
                eb:SetAutoFocus(false)
                self._datTextInput = eb
            end

            local eb    = self._datTextInput
            local getFn = data._textGetFn
            local setFn = data._textSetFn
            eb:SetText(getFn() or "")
            eb:Show()

            local function Save() setFn(eb:GetText()) end
            eb:SetScript("OnEnterPressed",  function(s) Save(); s:ClearFocus() end)
            eb:SetScript("OnEscapePressed", function(s) s:SetText(getFn() or ""); s:ClearFocus() end)
            eb:SetScript("OnEditFocusLost", Save)
        end
    end)
end

local function MakeColorPicker(cat, label, getColor, setColor)
    EnsureSettingsHook()
    local layout = SettingsPanel:GetLayout(cat)
    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = label, _colorGetFn = getColor, _colorSetFn = setColor }
    ))
end

local function MakeTextInput(cat, label, getText, setText)
    EnsureSettingsHook()
    local layout = SettingsPanel:GetLayout(cat)
    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = label, _textGetFn = getText, _textSetFn = setText }
    ))
end

------------------------------------------------------------
-- Page: Main
------------------------------------------------------------
local function BuildPageMain(cat)
    SectionHeader(cat, "Frame")

    MakeSlider(cat, "DAT_iconSize", "Icon Size", 72,
        32, 128, 1,
        function(v) return v .. " px" end,
        function() return DAT.db.iconSize or 72 end,
        function(v) DAT.db.iconSize = v; DAT:RebuildUI() end)

    MakeSlider(cat, "DAT_scale", "Scale", 100,
        50, 200, 1,
        function(v) return v .. "%" end,
        function() return DAT.db.scale or 100 end,
        function(v) DAT.db.scale = v; DAT:RebuildUI() end)

    MakeCheckbox(cat, "DAT_locked", "Lock Position", false,
        function() return DAT.db.locked end,
        function(v) DAT.db.locked = v; DAT:RebuildUI() end)

    SectionHeader(cat, "Position")

    MakeSlider(cat, "DAT_posX", "Position X", 0,
        -500, 2500, 1,
        function(v) return tostring(v) end,
        function() return math.floor((DAT.db.posX or 0) + 0.5) end,
        function(v) DAT.db.posX = v; DAT:ApplyFramePosition() end,
        "Horizontal position from the left edge of the screen.")

    MakeSlider(cat, "DAT_posY", "Position Y", 0,
        -500, 1500, 1,
        function(v) return tostring(v) end,
        function() return math.floor((DAT.db.posY or 0) + 0.5) end,
        function(v) DAT.db.posY = v; DAT:ApplyFramePosition() end,
        "Vertical position from the bottom edge of the screen.")

    MakeDropdown(cat, "DAT_visibilityMode", "Show Tracker", "always",
        function() return DAT.db.visibilityMode or "always" end,
        function(v) DAT.db.visibilityMode = v; DAT:UpdateVisibility() end,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("always",   "Always")
            c:Add("combat",   "In Combat Only")
            c:Add("nocombat", "Out of Combat Only")
            c:Add("never",    "Never")
            return c:GetData()
        end,
        "Controls when the tracker frame is visible.")

    MakeCheckbox(cat, "DAT_hideWhenNoBuff", "Hide When No Buff", false,
        function() return DAT.db.hideWhenNoBuff or false end,
        function(v) DAT.db.hideWhenNoBuff = v; DAT:UpdateVisibility() end,
        "Hide the tracker icon when Dominion of Argus is not active.")

    MakeSlider(cat, "DAT_hideDelaySec", "Hide Delay", 0,
        0, 30, 1,
        function(v) return v .. "s" end,
        function() return DAT.db.hideDelaySec or 0 end,
        function(v) DAT.db.hideDelaySec = v end,
        "Seconds to wait after the buff ends before hiding the tracker. 0 = hide immediately. Only applies when 'Hide When No Buff' is enabled.")

    SectionHeader(cat, "Icon")

    MakeSlider(cat, "DAT_brightness", "Icon Brightness", 35,
        0, 100, 1,
        function(v) return v .. "%" end,
        function() return DAT.db.iconBrightness or 35 end,
        function(v) DAT.db.iconBrightness = v; DAT:ApplyVisuals() end)

    MakeSlider(cat, "DAT_overlayAlpha", "Overlay Alpha", 45,
        0, 90, 1,
        function(v) return v .. "%" end,
        function() return DAT.db.overlayAlpha or 45 end,
        function(v) DAT.db.overlayAlpha = v; DAT:ApplyVisuals() end)

    SectionHeader(cat, "Display")

    MakeSlider(cat, "DAT_countLingerSec", "Count Linger (sec)", 10,
        0, 60, 1,
        function(v) return v == 0 and "keep" or (v .. "s") end,
        function() return DAT.db.countLingerSec or 0 end,
        function(v) DAT.db.countLingerSec = v end,
        "Seconds to keep the count visible after Dominion ends. 0 = keep until next Dominion.")
end

------------------------------------------------------------
-- Page: Fonts
------------------------------------------------------------
local function BuildPageFonts(cat)
    SectionHeader(cat, "Font")

    MakeDropdown(cat, "DAT_fontName", "Font", "Default",
        function() return DAT.db.fontName or DAT.Media.fontName or "Default" end,
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
        end,
        function()
            local c = Settings.CreateControlTextContainer()
            for _, e in ipairs(DAT.Media:GetAvailableFonts()) do
                c:Add(e.name, e.name)
            end
            return c:GetData()
        end)

    -- Font style
    SectionHeader(cat, "Font Style")

    MakeDropdown(cat, "DAT_fontFlags", "Outline", "OUTLINE",
        function() return DAT.db.fontFlags or "OUTLINE" end,
        function(v)
            DAT.db.fontFlags = v
            DAT:RebuildUI()
        end,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("OUTLINE",                  "Outline")
            c:Add("THICKOUTLINE",             "Thick Outline")
            c:Add("MONOCHROME",               "Monochrome")
            c:Add("OUTLINE, MONOCHROME",      "Outline + Monochrome")
            c:Add("THICKOUTLINE, MONOCHROME", "Thick + Monochrome")
            c:Add("",                         "None")
            return c:GetData()
        end)

    MakeCheckbox(cat, "DAT_shadowEnabled", "Shadow", false,
        function() return DAT.db.shadowEnabled or false end,
        function(v) DAT.db.shadowEnabled = v; DAT:ApplyShadow() end)

    MakeSlider(cat, "DAT_shadowOffsetX", "Shadow X Offset", 1,
        -5, 5, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.shadowOffsetX or 1 end,
        function(v) DAT.db.shadowOffsetX = v; DAT:ApplyShadow() end)

    MakeSlider(cat, "DAT_shadowOffsetY", "Shadow Y Offset", -1,
        -5, 5, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.shadowOffsetY or -1 end,
        function(v) DAT.db.shadowOffsetY = v; DAT:ApplyShadow() end)

    MakeColorPicker(cat, "Shadow Color",
        function() return DAT.db.shadowColor or { r=0, g=0, b=0 } end,
        function(r, g, b)
            DAT.db.shadowColor = { r=r, g=g, b=b }
            DAT:ApplyShadow()
        end)

    -- Count text
    SectionHeader(cat, "Count Text")

    MakeSlider(cat, "DAT_countFontSize", "Font Size", 28,
        8, 60, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.countFontSize or 28 end,
        function(v) DAT.db.countFontSize = v; DAT:RebuildUI() end)

    MakeDropdown(cat, "DAT_countAnchor", "Anchor", "CENTER",
        function() return DAT.db.countAnchor or "CENTER" end,
        function(v) DAT.db.countAnchor = v; DAT:RebuildUI() end,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("CENTER", "Center")
            c:Add("TOP",    "Top")
            c:Add("BOTTOM", "Bottom")
            c:Add("LEFT",   "Left")
            c:Add("RIGHT",  "Right")
            return c:GetData()
        end,
        "Which edge of the icon center the text is pinned to. Offsets are then symmetric around that point.")

    MakeSlider(cat, "DAT_countOffsetX", "Offset X", 0,
        -100, 100, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.countOffsetX or 0 end,
        function(v) DAT.db.countOffsetX = v; DAT:RebuildUI() end)

    MakeSlider(cat, "DAT_countOffsetY", "Offset Y", 0,
        -100, 100, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.countOffsetY or 0 end,
        function(v) DAT.db.countOffsetY = v; DAT:RebuildUI() end)

    -- Demon count text
    SectionHeader(cat, "Demon Count Text")

    MakeSlider(cat, "DAT_demonFontSize", "Font Size", 13,
        6, 60, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.demonFontSize or 13 end,
        function(v) DAT.db.demonFontSize = v; DAT:RebuildUI() end)

    MakeDropdown(cat, "DAT_demonAnchor", "Anchor", "TOP",
        function() return DAT.db.demonAnchor or "TOP" end,
        function(v) DAT.db.demonAnchor = v; DAT:RebuildUI() end,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("CENTER", "Center")
            c:Add("TOP",    "Top")
            c:Add("BOTTOM", "Bottom")
            c:Add("LEFT",   "Left")
            c:Add("RIGHT",  "Right")
            return c:GetData()
        end,
        "Which edge of the icon center the text is pinned to. Offsets are then symmetric around that point.")

    MakeSlider(cat, "DAT_demonOffsetX", "Offset X", 0,
        -100, 100, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.demonOffsetX or 0 end,
        function(v) DAT.db.demonOffsetX = v; DAT:RebuildUI() end)

    MakeSlider(cat, "DAT_demonOffsetY", "Offset Y", 0,
        -100, 100, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.demonOffsetY or 0 end,
        function(v) DAT.db.demonOffsetY = v; DAT:RebuildUI() end)

    -- Timer text
    SectionHeader(cat, "Timer Text")

    MakeSlider(cat, "DAT_timerFontSize", "Font Size", 13,
        6, 60, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.timerFontSize or 13 end,
        function(v) DAT.db.timerFontSize = v; DAT:RebuildUI() end)

    MakeDropdown(cat, "DAT_timerAnchor", "Anchor", "BOTTOM",
        function() return DAT.db.timerAnchor or "BOTTOM" end,
        function(v) DAT.db.timerAnchor = v; DAT:RebuildUI() end,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("CENTER", "Center")
            c:Add("TOP",    "Top")
            c:Add("BOTTOM", "Bottom")
            c:Add("LEFT",   "Left")
            c:Add("RIGHT",  "Right")
            return c:GetData()
        end,
        "Which edge of the icon center the text is pinned to. Offsets are then symmetric around that point.")

    MakeSlider(cat, "DAT_timerOffsetX", "Offset X", 0,
        -100, 100, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.timerOffsetX or 0 end,
        function(v) DAT.db.timerOffsetX = v; DAT:RebuildUI() end)

    MakeSlider(cat, "DAT_timerOffsetY", "Offset Y", 0,
        -100, 100, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.timerOffsetY or 0 end,
        function(v) DAT.db.timerOffsetY = v; DAT:RebuildUI() end)

    MakeCheckbox(cat, "DAT_timerShowSuffix", "Show \"s\" Suffix", true,
        function() return DAT.db.timerShowSuffix ~= false end,
        function(v) DAT.db.timerShowSuffix = v end)
end

------------------------------------------------------------
-- Page: Border
------------------------------------------------------------
local function BuildPageBorder(cat)
    SectionHeader(cat, "Border Style")

    MakeDropdown(cat, "DAT_borderName", "Border", "None",
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
        end,
        function()
            local c = Settings.CreateControlTextContainer()
            for _, e in ipairs(DAT.Media:GetAvailableBorders()) do
                c:Add(e.name, e.name)
            end
            return c:GetData()
        end)

    MakeSlider(cat, "DAT_borderSize", "Border Size", 12,
        1, 32, 1,
        function(v) return v .. " px" end,
        function() return DAT.db.borderSize or 12 end,
        function(v) DAT.db.borderSize = v; DAT:ApplyBorder() end)

    MakeSlider(cat, "DAT_borderOffset", "Border Offset", 0,
        -16, 32, 1,
        function(v) return v .. " px" end,
        function() return DAT.db.borderOffset or 0 end,
        function(v) DAT.db.borderOffset = v; DAT:ApplyBorder() end)

    SectionHeader(cat, "Active Border Color")
    MakeColorPicker(cat, "Active Border",
        function() return DAT.db.borderColor or { r=0.1, g=0.9, b=0.1 } end,
        function(r, g, b)
            DAT.db.borderColor = { r=r, g=g, b=b }
            DAT:ApplyBorder()
        end)

    SectionHeader(cat, "Inactive Border Color")
    MakeColorPicker(cat, "Inactive Border",
        function() return DAT.db.inactBorderColor or { r=0.15, g=0.15, b=0.15 } end,
        function(r, g, b)
            DAT.db.inactBorderColor = { r=r, g=g, b=b }
            DAT:ApplyBorder()
        end)
end

------------------------------------------------------------
-- Page: Colors
------------------------------------------------------------
local function BuildPageColors(cat)
    SectionHeader(cat, "Active Count Color")
    MakeColorPicker(cat, "Active Count",
        function() return DAT.db.activeCountColor or { r=0.15, g=1.0, b=0.15 } end,
        function(r, g, b)
            DAT.db.activeCountColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    SectionHeader(cat, "Inactive Count Color")
    MakeColorPicker(cat, "Inactive Count",
        function() return DAT.db.inactCountColor or { r=0.55, g=0.55, b=0.55 } end,
        function(r, g, b)
            DAT.db.inactCountColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    SectionHeader(cat, "Active Demon Count Color")
    MakeColorPicker(cat, "Active Demon Count",
        function() return DAT.db.activeDemonColor or { r=1.0, g=0.84, b=0.0 } end,
        function(r, g, b)
            DAT.db.activeDemonColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    SectionHeader(cat, "Inactive Demon Count Color")
    MakeColorPicker(cat, "Inactive Demon Count",
        function() return DAT.db.inactDemonColor or { r=0.55, g=0.55, b=0.55 } end,
        function(r, g, b)
            DAT.db.inactDemonColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    SectionHeader(cat, "Timer Color")
    MakeColorPicker(cat, "Timer",
        function() return DAT.db.timerColor or { r=1.0, g=0.82, b=0.0 } end,
        function(r, g, b)
            DAT.db.timerColor = { r=r, g=g, b=b }
            DAT:ApplyVisuals()
        end)

    SectionHeader(cat, "Timer Warning Color")

    MakeCheckbox(cat, "DAT_timerWarnEnabled", "Enable Timer Warning Color", true,
        function() return DAT.db.timerWarnEnabled ~= false end,
        function(v) DAT.db.timerWarnEnabled = v end,
        "Change the timer text color when time is running low.")

    MakeSlider(cat, "DAT_timerWarnThreshold", "Warn When ≤ (sec)", 5,
        1, 20, 1,
        function(v) return v .. "s" end,
        function() return DAT.db.timerWarnThreshold or 5 end,
        function(v) DAT.db.timerWarnThreshold = v end,
        "Timer text switches to the warning color when this many seconds remain.")

    MakeColorPicker(cat, "Timer Warning Color",
        function() return DAT.db.timerWarnColor or { r=1.0, g=0.2, b=0.2 } end,
        function(r, g, b)
            DAT.db.timerWarnColor = { r=r, g=g, b=b }
        end)
end

------------------------------------------------------------
-- Page: Glow
------------------------------------------------------------
local function BuildPageGlow(cat)
    SectionHeader(cat, "Glow")

    MakeCheckbox(cat, "DAT_glowEnabled", "Enable Glow", false,
        function() return DAT.db.glowEnabled or false end,
        function(v)
            DAT.db.glowEnabled = v
            DAT:ApplyGlow(DAT._dominionActive)
        end)

    MakeDropdown(cat, "DAT_glowType", "Glow Type", "proc",
        function() return DAT.db.glowType or "proc" end,
        function(v)
            DAT.db.glowType = v
            DAT:ApplyGlow(DAT._dominionActive)
        end,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("proc",     "Proc Glow")
            c:Add("pixel",    "Pixel Glow")
            c:Add("autocast", "Autocast Glow")
            c:Add("button",   "Button Glow")
            return c:GetData()
        end)

    SectionHeader(cat, "Glow Color")
    MakeColorPicker(cat, "Glow Color",
        function() return DAT.db.glowColor or { r=1.0, g=0.84, b=0.0 } end,
        function(r, g, b)
            DAT.db.glowColor = { r=r, g=g, b=b }
            DAT:ApplyGlow(DAT._dominionActive)
        end)

    -- Pixel Glow Options
    SectionHeader(cat, "Pixel Glow Options")

    MakeSlider(cat, "DAT_glowPixelN", "Lines", 8,
        1, 20, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.glowPixelN or 8 end,
        function(v) DAT.db.glowPixelN = v; DAT:ApplyGlow(DAT._dominionActive) end)

    MakeSlider(cat, "DAT_glowPixelFreq", "Frequency (x100)", 25,
        1, 200, 1,
        function(v) return string.format("%.2f", v / 100) end,
        function() return math.floor((DAT.db.glowPixelFreq or 0.25) * 100 + 0.5) end,
        function(v) DAT.db.glowPixelFreq = v / 100; DAT:ApplyGlow(DAT._dominionActive) end)

    MakeSlider(cat, "DAT_glowPixelLength", "Length (0=auto)", 3,
        0, 20, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.glowPixelLength or 3 end,
        function(v) DAT.db.glowPixelLength = v; DAT:ApplyGlow(DAT._dominionActive) end)

    MakeSlider(cat, "DAT_glowPixelThick", "Thickness", 2,
        1, 10, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.glowPixelThick or 2 end,
        function(v) DAT.db.glowPixelThick = v; DAT:ApplyGlow(DAT._dominionActive) end)

    MakeSlider(cat, "DAT_glowPixelXOffset", "X Offset", 0,
        -20, 20, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.glowPixelXOffset or 0 end,
        function(v) DAT.db.glowPixelXOffset = v; DAT:ApplyGlow(DAT._dominionActive) end)

    MakeSlider(cat, "DAT_glowPixelYOffset", "Y Offset", 0,
        -20, 20, 1,
        function(v) return tostring(v) end,
        function() return DAT.db.glowPixelYOffset or 0 end,
        function(v) DAT.db.glowPixelYOffset = v; DAT:ApplyGlow(DAT._dominionActive) end)
end

------------------------------------------------------------
-- Announce Rules Editor
------------------------------------------------------------
local RULE_CONDITIONS = {
    { key = "dominion", label = "Dominion" },
    { key = "hog",      label = "HoG Count" },
    { key = "demon",    label = "Demons" },
}

local DOMINION_OPERATORS = {
    { key = "start", label = "Start" },
    { key = "end",   label = "End" },
}

local COUNT_OPERATORS = {
    { key = ">",  label = ">" },
    { key = ">=", label = ">=" },
    { key = "<",  label = "<" },
    { key = "<=", label = "<=" },
    { key = "=",  label = "=" },
}

local COUNT_CONDITIONS = {
    { key = "hog",   label = "HoG Count" },
    { key = "demon", label = "Demons" },
}

local LOGIC_OPERATORS = {
    { key = "and", label = "AND" },
    { key = "or",  label = "OR" },
}

local RULE_CHANNELS = {
    { key = "SYSTEM", label = "System" },
    { key = "PARTY",  label = "Party" },
    { key = "SAY",    label = "Say" },
    { key = "YELL",   label = "Yell" },
}

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
-- ElvUI-style design tokens
------------------------------------------------------------
local E_BG        = "Interface\\Buttons\\WHITE8X8"
local E_BD        = { bgFile = E_BG, edgeFile = E_BG, edgeSize = 1 }
local E_BD2       = { bgFile = E_BG, edgeFile = E_BG, edgeSize = 2 }

-- Palette
local C_PANEL_BG  = { 0.05,  0.05,  0.05,  0.96 }  -- main window
local C_PANEL_BD  = { 0.00,  0.00,  0.00,  1.00 }
local C_CARD_BG   = { 0.08,  0.08,  0.10,  1.00 }  -- rule card
local C_CARD_BD   = { 0.18,  0.18,  0.22,  1.00 }
local C_WIDGET_BG = { 0.12,  0.12,  0.14,  1.00 }  -- dropdown / editbox
local C_WIDGET_BD = { 0.25,  0.25,  0.30,  1.00 }
local C_BTN_BG    = { 0.14,  0.14,  0.16,  1.00 }  -- buttons
local C_BTN_BD    = { 0.30,  0.30,  0.35,  1.00 }
local C_BTN_HI    = { 0.22,  0.22,  0.28,  1.00 }  -- button hover
local C_ACCENT    = { 0.58,  0.51,  0.79 }          -- Warlock class color #9482C9
local C_GOLD      = { 1.00,  0.82,  0.00 }          -- selected / accent alt
local C_TEXT      = { 0.90,  0.90,  0.90 }           -- normal text
local C_MUTED     = { 0.55,  0.55,  0.55 }           -- secondary text
local C_DANGER    = { 0.80,  0.25,  0.25 }           -- delete buttons
local C_HEADER_BG = { 0.10,  0.08,  0.14,  1.00 }   -- title bar
local C_SEP       = { 0.20,  0.18,  0.25,  1.00 }   -- separators
local C_CHECK     = { C_ACCENT[1], C_ACCENT[2], C_ACCENT[3] }

------------------------------------------------------------
-- Widget helpers
------------------------------------------------------------
local function SetBD(f, bg, bd, template)
    f:SetBackdrop(template or E_BD)
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    f:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4] or 1)
end

-- Flat button (no Blizzard template)
local function CreateFlatBtn(parent, w, h, label)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    SetBD(btn, C_BTN_BG, C_BTN_BD)
    btn._label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn._label:SetPoint("CENTER")
    btn._label:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
    if label then btn._label:SetText(label) end
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C_BTN_HI[1], C_BTN_HI[2], C_BTN_HI[3], C_BTN_HI[4])
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.6)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], C_BTN_BG[4])
        self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], C_BTN_BD[4])
    end)
    return btn
end

-- Flat icon button (small, for delete / add)
-- sz = box size, fontObj = optional font object for bigger/smaller glyphs
local function CreateIconBtn(parent, sz, label, color, fontObj)
    local btn = CreateFlatBtn(parent, sz, sz, label)
    if fontObj then btn._label:SetFontObject(fontObj) end
    local c = color or C_TEXT
    btn._label:SetTextColor(c[1], c[2], c[3])
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(c[1], c[2], c[3], 0.2)
        self:SetBackdropBorderColor(c[1], c[2], c[3], 0.7)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], C_BTN_BG[4])
        self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], C_BTN_BD[4])
    end)
    return btn
end

-- Flat checkbox (custom square)
local function CreateFlatCheckbox(parent)
    local cb = CreateFrame("Button", nil, parent, "BackdropTemplate")
    cb:SetSize(18, 18)
    SetBD(cb, C_WIDGET_BG, C_WIDGET_BD)

    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetSize(10, 10)
    check:SetPoint("CENTER")
    check:SetColorTexture(C_CHECK[1], C_CHECK[2], C_CHECK[3], 1)
    check:Hide()
    cb._check = check

    cb._checked = false
    function cb:GetChecked() return self._checked end
    function cb:SetChecked(val)
        self._checked = val and true or false
        if self._checked then self._check:Show() else self._check:Hide() end
    end
    cb:SetScript("OnClick", function(self)
        self:SetChecked(not self._checked)
        if self._onClick then self._onClick(self) end
    end)
    cb:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.7)
    end)
    cb:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C_WIDGET_BD[1], C_WIDGET_BD[2], C_WIDGET_BD[3], C_WIDGET_BD[4])
    end)
    return cb
end

-- Flat edit box (no Blizzard template)
local function CreateFlatEditBox(parent, w, h)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(w or 60, h or 22)
    SetBD(box, C_WIDGET_BG, C_WIDGET_BD)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.5)
    end)
    box:SetScript("OnLeave", function(self)
        if not self:HasFocus() then
            self:SetBackdropBorderColor(C_WIDGET_BD[1], C_WIDGET_BD[2], C_WIDGET_BD[3], C_WIDGET_BD[4])
        end
    end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.8)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(C_WIDGET_BD[1], C_WIDGET_BD[2], C_WIDGET_BD[3], C_WIDGET_BD[4])
    end)
    return box
end

-- Horizontal separator line
local function CreateSep(parent)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(C_SEP[1], C_SEP[2], C_SEP[3], C_SEP[4])
    return sep
end

------------------------------------------------------------
-- Shared dropdown menu (ElvUI flat style)
------------------------------------------------------------
local _menuOverlay, _menuFrame, _menuItems = nil, nil, {}

local function CloseDropdownMenu()
    if _menuFrame   then _menuFrame:Hide()   end
    if _menuOverlay then _menuOverlay:Hide() end
end

local function ShowDropdownMenu(anchor, options, curVal, onSelect)
    if not _menuOverlay then
        _menuOverlay = CreateFrame("Button", nil, UIParent)
        _menuOverlay:SetFrameStrata("FULLSCREEN")
        _menuOverlay:SetAllPoints()
        _menuOverlay:SetScript("OnClick", CloseDropdownMenu)
    end
    if not _menuFrame then
        _menuFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        SetBD(_menuFrame, { 0.08, 0.08, 0.10, 0.98 }, C_PANEL_BD)
        _menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    for _, it in ipairs(_menuItems) do it:Hide() end

    local w = math.max(anchor:GetWidth(), 80)
    local pad = 4
    local itemH = 22
    local h = pad * 2
    for i, opt in ipairs(options) do
        local it = _menuItems[i]
        if not it then
            it = CreateFrame("Button", nil, _menuFrame, "BackdropTemplate")
            it:SetBackdrop(E_BD)
            it:SetBackdropColor(0, 0, 0, 0)
            it:SetBackdropBorderColor(0, 0, 0, 0)
            it._text = it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            it._text:SetPoint("LEFT", 8, 0)
            it._text:SetPoint("RIGHT", -8, 0)
            it._text:SetJustifyH("LEFT")
            it:SetScript("OnEnter", function(self)
                self:SetBackdropColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.15)
            end)
            it:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
            end)
            _menuItems[i] = it
        end
        it:SetSize(w - 2, itemH)
        it:SetPoint("TOPLEFT", _menuFrame, "TOPLEFT", 1, -(pad + (i - 1) * itemH))
        it._text:SetText(opt.label)
        if opt.key == curVal then
            it._text:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])
        else
            it._text:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
        end
        it:SetScript("OnClick", function()
            onSelect(opt.key)
            CloseDropdownMenu()
        end)
        it:Show()
        h = h + itemH
    end

    _menuFrame:SetSize(w, h)
    _menuFrame:ClearAllPoints()
    _menuFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    _menuOverlay:Show()
    _menuFrame:Show()
end

local function CreateDropdownBtn(parent, w, options)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, 22)
    SetBD(btn, C_WIDGET_BG, C_WIDGET_BD)
    btn._label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn._label:SetPoint("LEFT", 8, 0)
    btn._label:SetPoint("RIGHT", -18, 0)
    btn._label:SetJustifyH("LEFT")
    btn._label:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetText("|cff888899v|r")
    btn._options = options
    btn._getValue = function() return nil end
    btn._onSelect = function() end
    function btn:Refresh()
        self._label:SetText(LabelForKey(self._options, self._getValue()))
    end
    btn:SetScript("OnClick", function(self)
        ShowDropdownMenu(self, self._options, self._getValue(), function(key)
            self._onSelect(key)
            self:Refresh()
        end)
    end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.5)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C_WIDGET_BD[1], C_WIDGET_BD[2], C_WIDGET_BD[3], C_WIDGET_BD[4])
    end)
    return btn
end

------------------------------------------------------------
-- Layout constants
------------------------------------------------------------
local COND_ROW_H = 30       -- one condition line
local RULE_PAD   = 10       -- inner padding
local MSG_ROW_H  = 30       -- message row
local ADD_ROW_H  = 26       -- "+ Condition" button row
local CARD_GAP   = 6        -- gap between rule cards
local INNER_LEFT = 36       -- left indent past checkbox

local _editorFrame, _scrollChild
local _ruleRows = {}
local RefreshRuleRows   -- forward declaration

local function RuleCardHeight(rule)
    local n = rule.conditions and #rule.conditions or 1
    local isDominion = (rule.conditions and #rule.conditions > 0
        and rule.conditions[1].condition == "dominion")
    local extra = isDominion and 0 or ADD_ROW_H
    return RULE_PAD + (n * COND_ROW_H) + extra + 6 + MSG_ROW_H + RULE_PAD
end

----------------------------------------------------------------
-- Condition sub-row
----------------------------------------------------------------
local function CreateCondSubRow(parent)
    local cr = CreateFrame("Frame", nil, parent)
    cr:SetHeight(COND_ROW_H)

    -- "If" label (shown on first row)
    cr._ifLabel = cr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cr._ifLabel:SetPoint("TOPLEFT", INNER_LEFT, -4)
    cr._ifLabel:SetTextColor(C_MUTED[1], C_MUTED[2], C_MUTED[3])
    cr._ifLabel:SetText("If")

    -- Logic dropdown (AND / OR) — shown on subsequent rows
    cr._logicBtn = CreateDropdownBtn(cr, 58, LOGIC_OPERATORS)
    cr._logicBtn:SetPoint("TOPLEFT", INNER_LEFT, -4)

    -- Condition dropdown
    cr._condBtn = CreateDropdownBtn(cr, 105, RULE_CONDITIONS)

    -- Operator dropdown (wide enough for "Start" label)
    cr._opBtn = CreateDropdownBtn(cr, 68, DOMINION_OPERATORS)
    cr._opBtn:SetPoint("LEFT", cr._condBtn, "RIGHT", 4, 0)

    -- Threshold edit box
    cr._threshEB = CreateFlatEditBox(cr, 46, 22)
    cr._threshEB:SetPoint("LEFT", cr._opBtn, "RIGHT", 4, 0)
    cr._threshEB:SetNumeric(true)

    -- Delete-condition button
    cr._delCondBtn = CreateIconBtn(cr, 18, "x", C_DANGER, "GameFontNormal")
    cr._delCondBtn:SetPoint("LEFT", cr._threshEB, "RIGHT", 6, 0)

    return cr
end

local function PopulateCondSubRow(cr, ruleIdx, condIdx, cond, isFirst, isDominion)
    if isFirst then
        cr._logicBtn:Hide()
        cr._ifLabel:Show()
        cr._condBtn:ClearAllPoints()
        cr._condBtn:SetPoint("LEFT", cr._ifLabel, "RIGHT", 6, 0)
    else
        cr._ifLabel:Hide()
        cr._logicBtn:Show()
        cr._logicBtn._getValue = function() return cond.logic or "and" end
        cr._logicBtn._onSelect = function(key) cond.logic = key end
        cr._logicBtn:Refresh()
        cr._condBtn:ClearAllPoints()
        cr._condBtn:SetPoint("LEFT", cr._logicBtn, "RIGHT", 4, 0)
    end

    cr._condBtn._options = isFirst and RULE_CONDITIONS or COUNT_CONDITIONS
    cr._condBtn._getValue = function() return cond.condition or "hog" end
    cr._condBtn._onSelect = function(key)
        cond.condition = key
        cond.operator = DefaultOperator(key)
        if isFirst and key == "dominion" then
            local rule = DAT.db.announceRules[ruleIdx]
            while #rule.conditions > 1 do
                table.remove(rule.conditions)
            end
        end
        RefreshRuleRows()
    end
    cr._condBtn:Refresh()

    local ops = OperatorsForCondition(cond.condition or "dominion")
    cr._opBtn._options = ops
    cr._opBtn._getValue = function()
        return cond.operator or DefaultOperator(cond.condition or "dominion")
    end
    cr._opBtn._onSelect = function(key) cond.operator = key end
    cr._opBtn:Refresh()

    local needsThresh = ConditionNeedsThreshold(cond.condition or "dominion")
    cr._threshEB:SetShown(needsThresh)
    cr._threshEB:SetText(tostring(cond.threshold or 0))
    local function SaveThresh(self)
        cond.threshold = tonumber(self:GetText()) or 0
    end
    cr._threshEB:SetScript("OnEnterPressed",  function(s) SaveThresh(s); s:ClearFocus() end)
    cr._threshEB:SetScript("OnEscapePressed",  function(s)
        s:SetText(tostring(cond.threshold or 0)); s:ClearFocus()
    end)
    -- preserve the focus border behavior then save
    local origFocusLost = cr._threshEB:GetScript("OnEditFocusLost")
    cr._threshEB:SetScript("OnEditFocusLost", function(s)
        SaveThresh(s)
        s:SetBackdropBorderColor(C_WIDGET_BD[1], C_WIDGET_BD[2], C_WIDGET_BD[3], C_WIDGET_BD[4])
    end)

    if isFirst then
        cr._delCondBtn:Hide()
    else
        cr._delCondBtn:Show()
        cr._delCondBtn:SetScript("OnClick", function()
            local rule = DAT.db.announceRules[ruleIdx]
            table.remove(rule.conditions, condIdx)
            RefreshRuleRows()
        end)
    end
end

----------------------------------------------------------------
-- Rule card
----------------------------------------------------------------
local function CreateRuleCard(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    SetBD(row, C_CARD_BG, C_CARD_BD)

    -- Enable checkbox (left edge, vertically aligned with first condition)
    row._cb = CreateFlatCheckbox(row)
    row._cb:SetPoint("TOPLEFT", 10, -(RULE_PAD + 1))

    -- Delete-rule button (top-right, vertically centered with first condition row)
    row._delBtn = CreateIconBtn(row, 18, "x", C_DANGER, "GameFontNormal")
    row._delBtn:SetPoint("TOPRIGHT", -10, -(RULE_PAD + (COND_ROW_H - 18) / 2))

    -- Channel dropdown (top-right, left of delete)
    row._chanLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row._chanLabel:SetTextColor(C_MUTED[1], C_MUTED[2], C_MUTED[3])
    row._chanLabel:SetText("Channel")
    row._chanBtn = CreateDropdownBtn(row, 85, RULE_CHANNELS)

    -- Separator before msg
    row._sep = CreateSep(row)

    -- "+ Add Condition" button
    row._addCondBtn = CreateFlatBtn(row, 120, 22, "+ Condition")
    row._addCondBtn._label:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])

    -- Msg label + edit box
    row._msgLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row._msgLbl:SetTextColor(C_MUTED[1], C_MUTED[2], C_MUTED[3])
    row._msgLbl:SetText("Message")
    row._msgEB = CreateFlatEditBox(row, 200, 22)

    -- Pool of condition sub-rows
    row._condRows = {}

    return row
end

local function PopulateRuleCard(row, ruleIdx, rule)
    local conds = rule.conditions or {}
    local isDominion = (#conds > 0 and conds[1].condition == "dominion")
    local nConds = #conds
    local h = RuleCardHeight(rule)
    row:SetHeight(h)

    -- Enable
    row._cb:SetChecked(rule.enabled)
    row._cb._onClick = function(self) rule.enabled = self:GetChecked() end

    -- Delete rule
    row._delBtn:SetScript("OnClick", function()
        table.remove(DAT.db.announceRules, ruleIdx)
        RefreshRuleRows()
    end)

    -- Channel (vertically centered with delete button)
    row._chanLabel:ClearAllPoints()
    row._chanLabel:SetPoint("RIGHT", row._delBtn, "LEFT", -8, 0)
    row._chanBtn:ClearAllPoints()
    row._chanBtn:SetPoint("RIGHT", row._chanLabel, "LEFT", -4, 0)
    row._chanBtn._getValue = function() return rule.channel end
    row._chanBtn._onSelect = function(key) rule.channel = key end
    row._chanBtn:Refresh()

    -- Hide old condition sub-rows
    for _, cr in ipairs(row._condRows) do cr:Hide() end

    -- Condition sub-rows
    for ci, cond in ipairs(conds) do
        local cr = row._condRows[ci]
        if not cr then
            cr = CreateCondSubRow(row)
            row._condRows[ci] = cr
        end
        cr:ClearAllPoints()
        cr:SetPoint("TOPLEFT", 0, -(RULE_PAD + (ci - 1) * COND_ROW_H))
        cr:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        PopulateCondSubRow(cr, ruleIdx, ci, cond, ci == 1, isDominion)
        cr:Show()
    end

    -- "+ Add Condition" button
    local cursorY = -(RULE_PAD + nConds * COND_ROW_H)
    if isDominion then
        row._addCondBtn:Hide()
    else
        row._addCondBtn:ClearAllPoints()
        row._addCondBtn:SetPoint("TOPLEFT", INNER_LEFT, cursorY)
        row._addCondBtn:SetScript("OnClick", function()
            table.insert(rule.conditions, {
                logic = "and", condition = "hog", operator = ">=", threshold = 0,
            })
            RefreshRuleRows()
        end)
        row._addCondBtn:Show()
        cursorY = cursorY - ADD_ROW_H
    end

    -- Separator
    row._sep:ClearAllPoints()
    row._sep:SetPoint("TOPLEFT", INNER_LEFT, cursorY - 3)
    row._sep:SetPoint("RIGHT", row, "RIGHT", -12, 0)

    -- Message row
    local msgY = cursorY - 6
    row._msgLbl:ClearAllPoints()
    row._msgLbl:SetPoint("TOPLEFT", INNER_LEFT, msgY - 4)
    row._msgEB:ClearAllPoints()
    row._msgEB:SetPoint("LEFT", row._msgLbl, "RIGHT", 6, 0)
    row._msgEB:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row._msgEB:SetText(rule.msg or "")
    local function SaveMsg(self) rule.msg = self:GetText() end
    row._msgEB:SetScript("OnEnterPressed",  function(s) SaveMsg(s); s:ClearFocus() end)
    row._msgEB:SetScript("OnEscapePressed",  function(s)
        s:SetText(rule.msg or ""); s:ClearFocus()
    end)
    row._msgEB:SetScript("OnEditFocusLost", function(s)
        SaveMsg(s)
        s:SetBackdropBorderColor(C_WIDGET_BD[1], C_WIDGET_BD[2], C_WIDGET_BD[3], C_WIDGET_BD[4])
    end)
end

----------------------------------------------------------------
-- Refresh all rule rows
----------------------------------------------------------------
RefreshRuleRows = function()
    for _, row in ipairs(_ruleRows) do row:Hide() end
    local rules = DAT.db.announceRules or {}
    local totalH = 0
    for i, rule in ipairs(rules) do
        local row = _ruleRows[i]
        if not row then
            row = CreateRuleCard(_scrollChild)
            _ruleRows[i] = row
        end
        local cardH = RuleCardHeight(rule)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -totalH)
        row:SetPoint("RIGHT", 0, 0)
        PopulateRuleCard(row, i, rule)
        row:Show()
        totalH = totalH + cardH + CARD_GAP
    end
    _scrollChild:SetHeight(math.max(totalH, 1))
end

------------------------------------------------------------
-- Main editor window
------------------------------------------------------------
function DAT.Config:OpenAnnounceEditor()
    if _editorFrame then
        RefreshRuleRows()
        _editorFrame:Show()
        return
    end

    -- Outer border frame (ElvUI double-border look)
    local outer = CreateFrame("Frame", "DoATrackerAnnounceEditor", UIParent, "BackdropTemplate")
    outer:SetSize(640, 500)
    outer:SetPoint("CENTER")
    outer:SetFrameStrata("DIALOG")
    outer:SetMovable(true)
    outer:EnableMouse(true)
    outer:RegisterForDrag("LeftButton")
    outer:SetScript("OnDragStart", outer.StartMoving)
    outer:SetScript("OnDragStop", outer.StopMovingOrSizing)
    SetBD(outer, C_PANEL_BD, C_PANEL_BD, E_BD2)
    _editorFrame = outer

    -- Inner panel
    local f = CreateFrame("Frame", nil, outer, "BackdropTemplate")
    f:SetPoint("TOPLEFT", 2, -2)
    f:SetPoint("BOTTOMRIGHT", -2, 2)
    SetBD(f, C_PANEL_BG, { C_CARD_BD[1], C_CARD_BD[2], C_CARD_BD[3], 0.5 })

    -- Title bar
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetHeight(36)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    SetBD(header, C_HEADER_BG, { 0, 0, 0, 0 })

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText("|cff9482c9DoA Tracker|r  Announce Rules")
    title:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])

    -- Scale stepper: [-] [100%] [+]  (no slider — SetScale on a dragged frame causes flicker)
    local _curScale = 100
    local function ApplyEditorScale(val)
        _curScale = math.max(50, math.min(150, val))
        outer:SetScale(_curScale / 100)
    end

    local scaleLbl = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLbl:SetTextColor(C_MUTED[1], C_MUTED[2], C_MUTED[3])
    scaleLbl:SetText("Scale")

    local scaleVal = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleVal:SetTextColor(C_TEXT[1], C_TEXT[2], C_TEXT[3])
    scaleVal:SetText("100%")

    local scaleDown = CreateIconBtn(header, 18, "-", C_TEXT, "GameFontNormal")
    scaleDown:SetScript("OnClick", function()
        ApplyEditorScale(_curScale - 5)
        scaleVal:SetText(_curScale .. "%")
    end)

    local scaleUp = CreateIconBtn(header, 18, "+", C_TEXT, "GameFontNormal")
    scaleUp:SetScript("OnClick", function()
        ApplyEditorScale(_curScale + 5)
        scaleVal:SetText(_curScale .. "%")
    end)

    -- Close button
    local closeBtn = CreateIconBtn(header, 20, "x", C_DANGER, "GameFontNormal")
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    closeBtn:SetScript("OnClick", function() outer:Hide() end)

    -- Position: ... [Scale] [-] [100%] [+]  [x]
    scaleUp:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    scaleVal:SetPoint("RIGHT", scaleUp, "LEFT", -4, 0)
    scaleDown:SetPoint("RIGHT", scaleVal, "LEFT", -4, 0)
    scaleLbl:SetPoint("RIGHT", scaleDown, "LEFT", -6, 0)

    -- Header separator
    local hSep = CreateSep(f)
    hSep:SetPoint("TOPLEFT", 1, -38)
    hSep:SetPoint("TOPRIGHT", -1, -38)

    -- Tag hints
    local tags = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tags:SetPoint("TOPLEFT", 14, -48)
    tags:SetTextColor(C_MUTED[1], C_MUTED[2], C_MUTED[3])
    tags:SetText("Variables:  |cffffd700{count:hog}|r = HoG casts    "
        .. "|cffffd700{count:demon}|r = demons summoned")

    -- Scroll area
    local scrollBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT", 8, -68)
    scrollBg:SetPoint("BOTTOMRIGHT", -8, 46)
    SetBD(scrollBg, { 0.03, 0.03, 0.04, 1 }, { 0.12, 0.12, 0.15, 1 })

    local scroll = CreateFrame("ScrollFrame", nil, scrollBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -24, 4)

    -- Style the scrollbar track
    local sb = scroll.ScrollBar
    if sb then
        local thumbTex = sb:GetThumbTexture()
        if thumbTex then
            thumbTex:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.35)
            thumbTex:SetSize(6, 40)
        end
    end

    _scrollChild = CreateFrame("Frame", nil, scroll)
    _scrollChild:SetWidth(scroll:GetWidth() or 556)
    _scrollChild:SetHeight(1)
    scroll:SetScrollChild(_scrollChild)

    -- Bottom bar separator
    local bSep = CreateSep(f)
    bSep:SetPoint("BOTTOMLEFT", 1, 40)
    bSep:SetPoint("BOTTOMRIGHT", -1, 40)

    -- Add Rule button
    local addBtn = CreateFlatBtn(f, 130, 26, "+ Add Rule")
    addBtn._label:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])
    addBtn:SetPoint("BOTTOMLEFT", 12, 10)
    addBtn:SetScript("OnClick", function()
        local rules = DAT.db.announceRules
        if not rules then rules = {}; DAT.db.announceRules = rules end
        table.insert(rules, {
            enabled = true, channel = "SYSTEM", msg = "",
            conditions = {
                { condition = "dominion", operator = "end", threshold = 0 },
            },
        })
        RefreshRuleRows()
    end)

    tinsert(UISpecialFrames, "DoATrackerAnnounceEditor")
    RefreshRuleRows()
end

------------------------------------------------------------
-- Page: Announce
------------------------------------------------------------
local function BuildPageAnnounce(cat)
    SectionHeader(cat, "Announce Rules")

    local layout = SettingsPanel:GetLayout(cat)
    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = "Configure announce messages and conditions.",
          _buttonLabel = "Open Editor",
          _buttonOnClick = function() DAT.Config:OpenAnnounceEditor() end }))

    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = "Or use |cffffd700/doat announce|r to open the editor." }))

    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = "|cffaaaaaaNote: SAY and YELL only work inside instances.|r" }))
end

------------------------------------------------------------
-- DAT.Config:Register()
------------------------------------------------------------
function DAT.Config:Register()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    local mainCat = Settings.RegisterVerticalLayoutCategory("DoA Tracker")
    BuildPageMain(mainCat)
    Settings.RegisterAddOnCategory(mainCat)

    local fontsCat   = Settings.RegisterVerticalLayoutSubcategory(mainCat, "Fonts")
    BuildPageFonts(fontsCat)

    local borderCat  = Settings.RegisterVerticalLayoutSubcategory(mainCat, "Border")
    BuildPageBorder(borderCat)

    local colorsCat  = Settings.RegisterVerticalLayoutSubcategory(mainCat, "Colors")
    BuildPageColors(colorsCat)

    local glowCat    = Settings.RegisterVerticalLayoutSubcategory(mainCat, "Glow")
    BuildPageGlow(glowCat)

    local msgCat     = Settings.RegisterVerticalLayoutSubcategory(mainCat, "Announce")
    BuildPageAnnounce(msgCat)

    DAT.Config.mainCat = mainCat
end
