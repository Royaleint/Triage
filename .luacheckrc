std = "none"
max_line_length = false

globals = {
    -- Addon global (intentionally written)
    "EnhancedRaidFrames",

    -- Slash commands
    "SlashCmdList",

    -- SavedVariables (created by WoW, read/written by addon)
    "EnhancedRaidFramesDB",
}

read_globals = {
    -- Lua builtins
    "_G",
    "next", "pairs", "ipairs", "type", "select", "unpack",
    "tonumber", "tostring", "print", "format",
    "tinsert", "tremove", "wipe",
    "strsplit", "strlower", "strtrim", "strfind", "strmatch",
    "time", "date",
    "math", "string", "table",
    "error", "pcall",
    "rawget", "rawset",
    "setmetatable", "getmetatable",
    "floor",

    -- WoW project constants
    "WOW_PROJECT_ID",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_MISTS_CLASSIC",

    -- WoW frames / UI globals
    "CreateFrame",
    "CreateColor",
    "UIParent",
    "GameTooltip",
    "GameFontNormal",
    "GameFontNormalSmall",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "ChatFontNormal",
    "NumberFontNormalSmall",
    "Settings",
    "InCombatLockdown",
    "hooksecurefunc",
    "issecretvalue",

    -- WoW color constants
    "NORMAL_FONT_COLOR",
    "WHITE_FONT_COLOR",
    "DIM_RED_FONT_COLOR",
    "DARKYELLOW_FONT_COLOR",

    -- WoW API functions
    "GetLocale",
    "GetTime",
    "GetRaidTargetIndex",
    "UnitAura",
    "UnitIsUnit",
    "UnitInRange",

    -- WoW C_ namespaces
    "C_Spell",
    "C_UnitAuras",

    -- Raid frame globals
    "CompactRaidFrameContainer",
    "CompactRaidFrameContainer_ApplyToFrames",
    "CompactPartyFrame",
    "CompactUnitFrame_UpdateInRange",
    "CompactUnitFrame_UpdatePrivateAuras",
    "UnitFrame_UpdateTooltip",

    -- Glow API (Retail 11.1.7+)
    "ActionButtonSpellAlertManager",
    -- Legacy glow API (Classic / pre-11.1.7)
    "ActionButton_ShowOverlayGlow",
    "ActionButton_HideOverlayGlow",

    -- Target marker mixins
    "UnitPopupRaidTarget1ButtonMixin",
    "UnitPopupRaidTarget2ButtonMixin",
    "UnitPopupRaidTarget3ButtonMixin",
    "UnitPopupRaidTarget4ButtonMixin",
    "UnitPopupRaidTarget5ButtonMixin",
    "UnitPopupRaidTarget6ButtonMixin",
    "UnitPopupRaidTarget7ButtonMixin",
    "UnitPopupRaidTarget8ButtonMixin",

    -- Ace3 / Libraries
    "LibStub",
}

ignore = {
    "21[23]",  -- Ace3 callback patterns (unused argument warnings)
}
