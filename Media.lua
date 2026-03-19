DAT = DAT or {}
DAT.Media = {}

local BUILTIN_FONTS = {
    { name = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",            path = "Fonts\\ARIALN.TTF"   },
    { name = "Skurri",                  path = "Fonts\\SKURRI.TTF"   },
    { name = "Morpheus",                path = "Fonts\\MORPHEUS.TTF" },
}

local BUILTIN_BORDERS = {
    { name = "None",        path = nil },
    { name = "Tooltip",     path = "Interface\\Tooltips\\UI-Tooltip-Border" },
    { name = "Dialog",      path = "Interface\\DialogFrame\\UI-DialogBox-Border" },
    { name = "Achievement", path = "Interface\\AchievementFrame\\UI-Achievement-Border" },
}

local function GetLSM()
    local LS = _G["LibStub"]
    return LS and LS("LibSharedMedia-3.0", true) or nil
end

function DAT.Media:GetAvailableFonts()
    local out, seen = {}, {}
    local lsm = GetLSM()
    if lsm then
        local list = lsm:List("font")
        if list then
            table.sort(list)
            for _, name in ipairs(list) do
                local path = lsm:Fetch("font", name)
                if path and not seen[name] then
                    seen[name] = true
                    out[#out+1] = { name = name, path = path }
                end
            end
        end
    end
    for _, e in ipairs(BUILTIN_FONTS) do
        if not seen[e.name] then
            seen[e.name] = true
            out[#out+1] = e
        end
    end
    return out
end

function DAT.Media:GetAvailableBorders()
    local out, seen = {}, {}
    out[#out+1] = { name = "None", path = nil }
    seen["None"] = true
    local lsm = GetLSM()
    if lsm then
        local list = lsm:List("border")
        if list then
            table.sort(list)
            for _, name in ipairs(list) do
                local path = lsm:Fetch("border", name)
                if path and not seen[name] then
                    seen[name] = true
                    out[#out+1] = { name = name, path = path }
                end
            end
        end
    end
    for _, e in ipairs(BUILTIN_BORDERS) do
        if e.path and not seen[e.name] then
            seen[e.name] = true
            out[#out+1] = e
        end
    end
    return out
end

function DAT.Media:Load()
    local db = DAT.db
    if db.fontPath then
        self.font     = db.fontPath
        self.fontName = db.fontName or "Custom"
    else
        self.font     = "Fonts\\FRIZQT__.TTF"
        self.fontName = "Friz Quadrata (Default)"
        local lsm = GetLSM()
        if lsm then
            for _, name in ipairs({ "PT Sans Narrow", "Expressway", "Arial Narrow" }) do
                if lsm:IsValid("font", name) then
                    self.font     = lsm:Fetch("font", name)
                    self.fontName = name
                    break
                end
            end
        end
    end
end

function DAT.Media:SetFont(fs, size)
    local flags = (DAT.db and DAT.db.fontFlags) or "OUTLINE"
    fs:SetFont(self.font or "Fonts\\FRIZQT__.TTF", size, flags)
end
