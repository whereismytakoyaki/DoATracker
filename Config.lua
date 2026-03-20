DAT        = DAT or {}
DAT.Config = DAT.Config or {}

------------------------------------------------------------
-- Helper: section header
------------------------------------------------------------
local function SectionHeader(cat, text)
    local layout = SettingsPanel:GetLayout(cat)
    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = "|cffaa44ff" .. text .. "|r" }))
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
        6, 24, 1,
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
        6, 24, 1,
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
-- Page: Messages
------------------------------------------------------------
local function BuildPageMessages(cat)
    SectionHeader(cat, "Start Message")
    MakeTextInput(cat, "On Dominion Start",
        function() return DAT.db.startMsg or "Dominion of Argus active!" end,
        function(v) DAT.db.startMsg = v end)

    SectionHeader(cat, "End Message")
    MakeTextInput(cat, "On Dominion End",
        function() return DAT.db.endMsg or "Dominion ended — HoG casts: {count}" end,
        function(v) DAT.db.endMsg = v end)

    SectionHeader(cat, "Hint")
    local layout = SettingsPanel:GetLayout(cat)
    layout:AddInitializer(Settings.CreateElementInitializer(
        "SettingsListSectionHeaderTemplate",
        { name = "|cffaaaaaaUse {count} in the end message to insert the HoG cast count.|r" }))
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

    local msgCat     = Settings.RegisterVerticalLayoutSubcategory(mainCat, "Messages")
    BuildPageMessages(msgCat)

    DAT.Config.mainCat = mainCat
end
