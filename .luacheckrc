-- Baseline Luacheck config for WoW WotLK 3.3.5a addon work.
-- This is intentionally permissive at the start because WoW exposes many globals.
std = "lua51"
max_line_length = false

globals = {
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "DEFAULT_CHAT_FRAME",
    "SlashCmdList",
    "print",

    "GetAddOnMetadata",
    "GetBuildInfo",
    "GetLocale",
    "UnitName",
    "UnitClass",
    "UnitLevel",
    "UnitExists",
    "RegisterAddonMessagePrefix",
    "SendAddonMessage",

    "C_Timer",
    "LibStub",
}

ignore = {
    "111", -- setting non-standard global
    "113", -- accessing undefined variable, often WoW API until stubs are added
}
