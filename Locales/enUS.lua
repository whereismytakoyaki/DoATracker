-- English is the canonical source; L falls back to the key itself when a
-- locale override doesn't translate a given string, so this table can stay
-- empty. It exists so enUS is explicitly registered and selectable from
-- the locale override dropdown.
DAT.RegisterLocale("enUS", {})
