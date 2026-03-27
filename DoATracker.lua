DAT = DAT or {}

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local TYRANT_ID       = 265187   -- Summon Demonic Tyrant  (triggers Dominion)
local HOG_ID          = 105174   -- Hand of Gul'dan
local DOMINION_DURATION = 25     -- seconds
local ICON_SPELL_ID   = 1276166  -- DoA aura spell ID (icon fetched via C_Spell)
local GLOW_KEY        = "DoATrackerGlow"

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
DAT.DEFAULTS = {
    iconSize         = 72,
    scale            = 100,
    locked           = false,
    posX             = nil,
    posY             = nil,
    fontName         = "Default",
    fontPath         = nil,
    fontFlags        = "OUTLINE",
    shadowEnabled    = false,
    shadowOffsetX    = 1,
    shadowOffsetY    = -1,
    shadowColor      = { r = 0, g = 0, b = 0 },
    countFontSize    = 28,
    countOffsetX     = 0,
    countOffsetY     = 0,
    countAnchor      = "CENTER",
    timerFontSize    = 13,
    timerOffsetX     = 0,
    timerOffsetY     = 0,
    timerAnchor      = "BOTTOM",
    timerShowSuffix  = true,
    demonFontSize    = 13,
    demonOffsetX     = 0,
    demonOffsetY     = 0,
    demonAnchor      = "TOP",
    borderName       = "None",
    borderPath       = nil,
    borderSize       = 12,
    borderColor      = { r = 0.1,  g = 0.9,  b = 0.1  },
    inactBorderColor = { r = 0.15, g = 0.15, b = 0.15 },
    activeCountColor = { r = 0.15, g = 1.0,  b = 0.15 },
    inactCountColor  = { r = 0.55, g = 0.55, b = 0.55 },
    timerColor       = { r = 1.0,  g = 0.82, b = 0.0  },
    activeDemonColor = { r = 1.0,  g = 0.84, b = 0.0  },
    inactDemonColor  = { r = 0.55, g = 0.55, b = 0.55 },
    iconBrightness   = 35,
    overlayAlpha     = 45,
    glowEnabled      = false,
    glowType         = "proc",
    glowColor        = { r = 1.0,  g = 0.84, b = 0.0  },
    -- pixel glow options
    glowPixelN       = 8,
    glowPixelFreq    = 0.25,
    glowPixelLength  = 3,
    glowPixelThick   = 2,
    glowPixelXOffset = 0,
    glowPixelYOffset = 0,
    -- display / messages
    countLingerSec   = 10,
    startMsg         = "Dominion of Argus active!",
    endMsg           = "Dominion ended — HoG casts: {count}",
    -- visibility
    visibilityMode   = "always",
}

------------------------------------------------------------
-- State
------------------------------------------------------------
local dominionActive  = false
local hogCount        = 0
local dominionTimer   = nil
local dominionEndTime = 0
local updateTicker    = nil
local lingerTimer     = nil
DAT._dominionActive   = false   -- exposed for Config.lua

------------------------------------------------------------
-- UI handles
------------------------------------------------------------
local frame       = nil
local iconTex     = nil
local darkOverlay = nil
local borderFrame = nil
local countText   = nil
local timerText   = nil
local demonText   = nil

------------------------------------------------------------
-- Text anchor helper
-- Positions a text object by centering it on the chosen
-- edge of the icon (TOP / BOTTOM / LEFT / RIGHT / CENTER).
-- offsetX/Y are then symmetric around that anchor point.
------------------------------------------------------------
local function ApplyTextPoint(textObj, anchor, offsetX, offsetY)
    textObj:ClearAllPoints()
    -- Bake a 12px base gap so that offset=0 already gives breathing room.
    local bx, by = 0, 0
    if     anchor == "TOP"    then by =  12
    elseif anchor == "BOTTOM" then by = -12
    elseif anchor == "LEFT"   then bx = -12
    elseif anchor == "RIGHT"  then bx =  12
    end
    textObj:SetPoint("CENTER", iconTex, anchor or "CENTER",
        (offsetX or 0) + bx, (offsetY or 0) + by)
end

------------------------------------------------------------
-- LibCustomGlow
------------------------------------------------------------
local _lcg = nil
local function GetLCG()
    if _lcg == nil then
        local LS = _G["LibStub"]
        _lcg = (LS and LS("LibCustomGlow-1.0", true)) or false
    end
    return _lcg or nil
end

------------------------------------------------------------
-- DAT:Initialize()  — called from ADDON_LOADED
------------------------------------------------------------
function DAT:Initialize()
    DoATrackerDB = DoATrackerDB or {}
    self.db = DoATrackerDB

    -- Migrate old separate R/G/B channel fields → color tables
    local db = self.db
    local function Migrate(rk, gk, bk, tk)
        if db[rk] ~= nil then
            if not db[tk] then
                db[tk] = { r = db[rk], g = db[gk], b = db[bk] }
            end
            db[rk], db[gk], db[bk] = nil, nil, nil
        end
    end
    Migrate("borderColorR",  "borderColorG",  "borderColorB",  "borderColor")
    Migrate("inactBorderR",  "inactBorderG",  "inactBorderB",  "inactBorderColor")
    Migrate("activeCountR",  "activeCountG",  "activeCountB",  "activeCountColor")
    Migrate("inactCountR",   "inactCountG",   "inactCountB",   "inactCountColor")
    Migrate("timerR",        "timerG",        "timerB",        "timerColor")
    Migrate("activeDemonR",  "activeDemonG",  "activeDemonB",  "activeDemonColor")
    Migrate("inactDemonR",   "inactDemonG",   "inactDemonB",   "inactDemonColor")

    -- Merge defaults
    for k, v in pairs(self.DEFAULTS) do
        if self.db[k] == nil then
            if type(v) == "table" then
                self.db[k] = { r = v.r, g = v.g, b = v.b }
            else
                self.db[k] = v
            end
        end
    end

    DAT.Media:Load()
    DAT.Config:Register()
end

------------------------------------------------------------
-- DAT:CreateUI()  — called from PLAYER_LOGIN
------------------------------------------------------------
function DAT:CreateUI()
    local db = self.db
    local sz = db.iconSize

    frame = CreateFrame("Frame", "DoATrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(sz, sz + 22)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(not db.locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        if not DAT.db.locked then f:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local x = f:GetLeft()
        local y = f:GetBottom()
        if x and y then
            local s = f:GetEffectiveScale()
            DAT.db.posX = x * s
            DAT.db.posY = y * s
        end
    end)

    -- Icon texture
    iconTex = frame:CreateTexture(nil, "BACKGROUND")
    iconTex:SetSize(sz, sz)
    iconTex:SetPoint("TOP", frame, "TOP", 0, 0)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local _si = C_Spell.GetSpellInfo(ICON_SPELL_ID)
    if _si and _si.iconID then
        iconTex:SetTexture(_si.iconID)
    end

    -- Dark overlay
    darkOverlay = frame:CreateTexture(nil, "BORDER")
    darkOverlay:SetSize(sz, sz)
    darkOverlay:SetPoint("TOP", frame, "TOP", 0, 0)
    darkOverlay:SetColorTexture(0, 0, 0, db.overlayAlpha / 100)

    -- Border frame
    borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderFrame:SetSize(sz, sz)
    borderFrame:SetPoint("TOP", frame, "TOP", 0, 0)
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 5)

    -- Demon count text (anchored to chosen icon edge)
    demonText = frame:CreateFontString(nil, "OVERLAY")
    ApplyTextPoint(demonText, db.demonAnchor, db.demonOffsetX, db.demonOffsetY)
    DAT.Media:SetFont(demonText, db.demonFontSize)
    demonText:SetText("0")
    demonText:Hide()

    -- Count text
    countText = frame:CreateFontString(nil, "OVERLAY")
    ApplyTextPoint(countText, db.countAnchor, db.countOffsetX, db.countOffsetY)
    DAT.Media:SetFont(countText, db.countFontSize)
    countText:SetText("0")

    -- Timer text
    timerText = frame:CreateFontString(nil, "OVERLAY")
    ApplyTextPoint(timerText, db.timerAnchor, db.timerOffsetX, db.timerOffsetY)
    DAT.Media:SetFont(timerText, db.timerFontSize)
    timerText:SetText("")
    timerText:Hide()

    self:ApplyBorder()
    self:ApplyVisuals()
    self:ApplyShadow()
    self:ApplyFramePosition()
    frame:SetScale(db.scale / 100)
end

------------------------------------------------------------
-- DAT:RebuildUI()  — called when settings change
------------------------------------------------------------
function DAT:RebuildUI()
    if not frame then return end
    local db = self.db
    local sz = db.iconSize

    frame:SetSize(sz, sz + 22)
    frame:EnableMouse(not db.locked)
    frame:SetScale(db.scale / 100)

    iconTex:SetSize(sz, sz)
    iconTex:ClearAllPoints()
    iconTex:SetPoint("TOP", frame, "TOP", 0, 0)

    darkOverlay:SetSize(sz, sz)
    darkOverlay:ClearAllPoints()
    darkOverlay:SetPoint("TOP", frame, "TOP", 0, 0)

    borderFrame:SetSize(sz, sz)
    borderFrame:ClearAllPoints()
    borderFrame:SetPoint("TOP", frame, "TOP", 0, 0)

    ApplyTextPoint(demonText, db.demonAnchor, db.demonOffsetX, db.demonOffsetY)
    DAT.Media:SetFont(demonText, db.demonFontSize)

    ApplyTextPoint(countText, db.countAnchor, db.countOffsetX, db.countOffsetY)
    DAT.Media:SetFont(countText, db.countFontSize)

    ApplyTextPoint(timerText, db.timerAnchor, db.timerOffsetX, db.timerOffsetY)
    DAT.Media:SetFont(timerText, db.timerFontSize)

    self:ApplyBorder()
    self:ApplyVisuals()
    self:ApplyShadow()
    self:ApplyGlow(dominionActive)
end

------------------------------------------------------------
-- DAT:ApplyBorder()
------------------------------------------------------------
function DAT:ApplyBorder()
    if not borderFrame then return end
    local db = self.db

    if not db.borderPath then
        borderFrame:SetBackdrop(nil)
        return
    end

    local bsz = db.borderSize or 12
    borderFrame:SetBackdrop({
        edgeFile = db.borderPath,
        edgeSize = bsz,
        insets   = { left = bsz/2, right = bsz/2, top = bsz/2, bottom = bsz/2 },
    })

    local c = dominionActive and db.borderColor or db.inactBorderColor
    borderFrame:SetBackdropBorderColor(c.r, c.g, c.b, 1)
end

------------------------------------------------------------
-- DAT:ApplyVisuals()
------------------------------------------------------------
function DAT:ApplyVisuals()
    if not frame then return end
    local db = self.db
    local br = db.iconBrightness / 100

    if dominionActive then
        iconTex:SetVertexColor(1, 1, 1, 1)
        local c = db.activeCountColor
        countText:SetTextColor(c.r, c.g, c.b)
        local dc = db.activeDemonColor
        if demonText then demonText:SetTextColor(dc.r, dc.g, dc.b) end
        if borderFrame and db.borderPath then
            local bc = db.borderColor
            borderFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, 1)
        end
    else
        iconTex:SetVertexColor(br, br, br, 1)
        local c = db.inactCountColor
        countText:SetTextColor(c.r, c.g, c.b)
        local dc = db.inactDemonColor
        if demonText then demonText:SetTextColor(dc.r, dc.g, dc.b) end
        if borderFrame and db.borderPath then
            local bc = db.inactBorderColor
            borderFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, 1)
        end
    end

    darkOverlay:SetColorTexture(0, 0, 0, db.overlayAlpha / 100)
    local tc = db.timerColor
    timerText:SetTextColor(tc.r, tc.g, tc.b)
end

------------------------------------------------------------
-- DAT:ApplyFramePosition()
------------------------------------------------------------
function DAT:ApplyFramePosition()
    if not frame then return end
    local db = self.db
    frame:ClearAllPoints()
    if db.posX and db.posY then
        local s = frame:GetEffectiveScale()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.posX / s, db.posY / s)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 200)
    end
end

------------------------------------------------------------
-- DAT:ApplyShadow()
------------------------------------------------------------
function DAT:ApplyShadow()
    if not countText or not timerText then return end
    local db = self.db
    if db.shadowEnabled then
        local ox = db.shadowOffsetX or 1
        local oy = db.shadowOffsetY or -1
        local c  = db.shadowColor or { r = 0, g = 0, b = 0 }
        countText:SetShadowOffset(ox, oy)
        countText:SetShadowColor(c.r, c.g, c.b, 1)
        timerText:SetShadowOffset(ox, oy)
        timerText:SetShadowColor(c.r, c.g, c.b, 1)
        if demonText then
            demonText:SetShadowOffset(ox, oy)
            demonText:SetShadowColor(c.r, c.g, c.b, 1)
        end
    else
        countText:SetShadowOffset(0, 0)
        timerText:SetShadowOffset(0, 0)
        if demonText then demonText:SetShadowOffset(0, 0) end
    end
end

------------------------------------------------------------
-- DAT:ApplyGlow()
------------------------------------------------------------
function DAT:ApplyGlow(active)
    local lcg = GetLCG()
    if not lcg or not borderFrame then return end
    local db  = self.db
    local tgt = borderFrame   -- glow only the icon area, not the timer text

    -- Stop all types first
    if lcg.PixelGlow_Stop    then lcg.PixelGlow_Stop(tgt, GLOW_KEY)    end
    if lcg.AutoCastGlow_Stop then lcg.AutoCastGlow_Stop(tgt, GLOW_KEY) end
    if lcg.ButtonGlow_Stop   then lcg.ButtonGlow_Stop(tgt)              end
    if lcg.ProcGlow_Stop     then lcg.ProcGlow_Stop(tgt, GLOW_KEY)     end

    if not (active and db.glowEnabled) then return end

    local c = db.glowColor or { r = 1, g = 1, b = 1 }
    local color = { c.r, c.g, c.b, 1 }
    local t = db.glowType or "proc"

    if t == "pixel" then
        local len = db.glowPixelLength or 3
        lcg.PixelGlow_Start(tgt, color,
            db.glowPixelN       or 8,
            db.glowPixelFreq    or 0.25,
            len > 0 and len or nil,
            db.glowPixelThick   or 2,
            db.glowPixelXOffset or 0,
            db.glowPixelYOffset or 0,
            false, GLOW_KEY)
    elseif t == "autocast" then
        lcg.AutoCastGlow_Start(tgt, color, 4, 0.2, 1, 0, 0, GLOW_KEY)
    elseif t == "button" then
        lcg.ButtonGlow_Start(tgt, color)
    else
        lcg.ProcGlow_Start(tgt, { color = color, startAnim = false, duration = 1, key = GLOW_KEY })
    end
end

------------------------------------------------------------
-- DAT:UpdateVisibility()  — show/hide frame based on hard requirements
--   and the user-selected visibilityMode.
-- Hard requirements (all must pass):
--   1. Player is a Warlock
--   2. Player is in Demonology specialization (spec ID 266)
--   3. Player has learned Summon Demonic Tyrant
------------------------------------------------------------
local DEMONOLOGY_SPEC_ID = 266

function DAT:UpdateVisibility()
    if not frame then return end

    -- 1. Class: must be Warlock
    local _, classFile = UnitClass("player")
    if classFile ~= "WARLOCK" then frame:Hide(); return end

    -- 2. Spec: must be Demonology
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then
        local specID = select(1, GetSpecializationInfo(specIndex))
        if specID ~= DEMONOLOGY_SPEC_ID then frame:Hide(); return end
    end

    -- 3. Spell: must have Summon Demonic Tyrant learned
    if not IsSpellKnown(TYRANT_ID) then frame:Hide(); return end

    -- User visibility mode
    local mode     = (self.db and self.db.visibilityMode) or "always"
    local inCombat = UnitAffectingCombat("player")
    local show
    if     mode == "always"   then show = true
    elseif mode == "combat"   then show = inCombat
    elseif mode == "nocombat" then show = not inCombat
    else                           show = false   -- "never"
    end
    if show then frame:Show() else frame:Hide() end
end

------------------------------------------------------------
-- Countdown
------------------------------------------------------------
local function UpdateCountdown()
    if not timerText then return end
    local rem = dominionEndTime - GetTime()
    local suffix = DAT.db.timerShowSuffix and "s" or ""
    if rem <= 0 then
        timerText:SetText("0.0" .. suffix)
        return
    end
    timerText:SetText(string.format("%.1f%s", rem, suffix))
end

------------------------------------------------------------
-- Dominion state
------------------------------------------------------------
local function OnDominionEnd()
    dominionActive        = false
    DAT._dominionActive   = false
    dominionTimer         = nil
    if updateTicker then updateTicker:Cancel(); updateTicker = nil end

    local db  = DAT.db
    local msg = (db.endMsg or "Dominion ended — HoG casts: {count}")
                    :gsub("{count}", tostring(hogCount))
    print("|cffaa44ff[DoA Tracker]|r " .. msg)

    timerText:Hide()
    timerText:SetText("")
    DAT:ApplyVisuals()
    DAT:ApplyGlow(false)

    -- Auto-reset count after linger duration (0 = keep until next dominion)
    if lingerTimer then lingerTimer:Cancel(); lingerTimer = nil end
    local linger = db.countLingerSec or 0
    if linger > 0 then
        lingerTimer = C_Timer.NewTimer(linger, function()
            lingerTimer = nil
            hogCount = 0
            if countText then countText:SetText("0") end
            if demonText then demonText:SetText("0"); demonText:Hide() end
            DAT:ApplyVisuals()
        end)
    end
end

local function OnDominionStart()
    if dominionTimer  then dominionTimer:Cancel()  end
    if updateTicker   then updateTicker:Cancel()   end
    if lingerTimer    then lingerTimer:Cancel();  lingerTimer = nil end
    dominionActive        = true
    DAT._dominionActive   = true
    hogCount              = 0
    dominionEndTime       = GetTime() + DOMINION_DURATION
    dominionTimer         = C_Timer.NewTimer(DOMINION_DURATION, OnDominionEnd)
    updateTicker          = C_Timer.NewTicker(0.1, UpdateCountdown)
    if countText then countText:SetText("0") end
    if demonText then demonText:SetText("0"); demonText:Hide() end
    if timerText then timerText:Show() end
    local msg = DAT.db.startMsg or "Dominion of Argus active!"
    print("|cffaa44ff[DoA Tracker]|r " .. msg)
    DAT:ApplyVisuals()
    DAT:ApplyGlow(true)
end

------------------------------------------------------------
-- Cast watcher: player only
------------------------------------------------------------
local castFrame = CreateFrame("Frame")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
castFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
    if spellID == TYRANT_ID then
        OnDominionStart()
    elseif spellID == HOG_ID and dominionActive then
        hogCount = hogCount + 1
        if countText then countText:SetText(hogCount) end
        if demonText then
            local dc = math.floor(hogCount / 2)
            if dc > 0 then
                demonText:SetText(dc)
                demonText:Show()
            end
        end
    end
end)

------------------------------------------------------------
-- Main event frame
------------------------------------------------------------
local eventFrame    = CreateFrame("Frame")
local eventHandlers = {}

eventHandlers["ADDON_LOADED"] = function(addon)
    if addon == "DoATracker" then
        DAT:Initialize()
    end
end

eventHandlers["PLAYER_LOGIN"] = function()
    DAT:CreateUI()
    DAT:UpdateVisibility()
    print("|cffaa44ff[DoA Tracker]|r v1.2 loaded. Type |cffffd700/doat|r for commands.")
end

eventHandlers["PLAYER_REGEN_DISABLED"] = function()
    DAT:UpdateVisibility()
end

eventHandlers["PLAYER_REGEN_ENABLED"] = function()
    DAT:UpdateVisibility()
end

eventHandlers["PLAYER_SPECIALIZATION_CHANGED"] = function()
    DAT:UpdateVisibility()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, a1)
    local h = eventHandlers[event]
    if h then h(a1) end
end)

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
SLASH_DOATRACKER1 = "/doat"
SlashCmdList["DOATRACKER"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "hide" then
        if frame then frame:Hide() end
    elseif msg == "show" then
        DAT:UpdateVisibility()
    elseif msg == "reset" then
        if dominionTimer  then dominionTimer:Cancel();  dominionTimer  = nil end
        if updateTicker   then updateTicker:Cancel();   updateTicker   = nil end
        if lingerTimer    then lingerTimer:Cancel();    lingerTimer    = nil end
        dominionActive      = false
        DAT._dominionActive = false
        hogCount            = 0
        if countText then countText:SetText("0") end
        if demonText then demonText:SetText("0"); demonText:Hide() end
        if timerText then timerText:Hide(); timerText:SetText("") end
        DAT:ApplyVisuals()
        DAT:ApplyGlow(false)
        print("|cffaa44ff[DoA Tracker]|r Reset.")
    else
        if DAT.Config and DAT.Config.mainCat and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(DAT.Config.mainCat:GetID())
        else
            print("|cffaa44ff[DoA Tracker]|r v1.2")
            print("  |cffffd700/doat|r         — open settings")
            print("  |cffffd700/doat hide|r    — hide tracker")
            print("  |cffffd700/doat show|r    — show tracker")
            print("  |cffffd700/doat reset|r   — reset state")
        end
    end
end
