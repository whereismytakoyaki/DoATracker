DAT = DAT or {}

-- L[key] returns the localized string, or the key itself as a fallback so
-- a missing translation degrades to readable English instead of nil.
DAT.L = DAT.L or setmetatable({}, { __index = function(_, k) return k end })

DAT._localeTables = DAT._localeTables or {}
DAT._localeHooks  = DAT._localeHooks  or {}

function DAT.RegisterLocale(loc, tbl)
    DAT._localeTables[loc] = tbl
end

-- Modules that cache translated strings at load time can register a hook
-- here; it's fired every time LoadLocale applies a locale table so caches
-- can be rebuilt with the freshly-resolved values.
function DAT.RegisterLocaleHook(fn)
    DAT._localeHooks[#DAT._localeHooks + 1] = fn
end

-- Available override values for the UI dropdown. "auto" means follow the
-- game client locale. Switching requires /reload since module-level tables
-- in Config.lua capture L values at load time.
DAT.LOCALE_CHOICES = {
    { key = "auto",  label = "Auto (Client)" },
    { key = "enUS",  label = "English" },
    { key = "zhCN",  label = "简体中文" },
}

local function Detect()
    local pref = DoATrackerDB and DoATrackerDB.locale
    if pref and pref ~= "auto" and DAT._localeTables[pref] then
        return pref
    end
    local client = GetLocale()
    if DAT._localeTables[client] then return client end
    return "enUS"
end

function DAT.LoadLocale()
    local loc = Detect()
    local tbl = DAT._localeTables[loc]
    if tbl then
        for k, v in pairs(tbl) do
            DAT.L[k] = v
        end
    end
    for _, fn in ipairs(DAT._localeHooks) do
        fn()
    end
end
