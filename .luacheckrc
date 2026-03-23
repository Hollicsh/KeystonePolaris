std = "max"

files = {}

exclude_files = {
    ".history/",
    "Libs/",
}

ignore = {
    "111",
    "611",
    "631",
}

globals = {
    "LibStub",
    "CreateFrame",
    "StaticPopup_Show",
    "StaticPopupDialogs",
    "UIParent",
    "BackdropTemplateMixin",
    "hooksecurefunc",
    "C_AddOns",
    "C_ChallengeMode",
    "C_CVar",
    "C_ScenarioInfo",
    "C_Spell",
    "C_LFGList",
    "C_Map",
    "C_NamePlate",
    "C_Texture",
    "C_Timer",
    "GetBuildInfo",
    "GetTime",
    "IsAddOnLoaded",
    "InCombatLockdown",
    "UnitExists",
    "UnitGUID",
    "UnitReaction",
    "UnitAffectingCombat",
    "UnitGroupRolesAssigned",
    "GetLFGRoles",
    "GetLocale",
    "GetNumGroupMembers",
    "GetSpellInfo",
    "GetTexCoordsForRole",
    "GetTexCoordsForRoleSmallCircle",
    "SetItemRef",
    "Settings",
    "CopyTable",
    "strsplit",
    "wipe",
    "date",
    "time",
    "unpack",
    "UISpecialFrames",
    "GameTooltip",
    "SettingsPanel",
    "ElvUI",
    "IsSpellKnown",
    "IsInGroup",
    "IsInRaid",
    "UnitIsGroupLeader",
    "EJ_GetEncounterInfo",
    "DEFAULT_CHAT_FRAME",
    "LFGListInviteDialog",
    "TANK",
    "HEALER",
    "DAMAGER",
    "OKAY",
    "CANCEL",
    "YES",
    "NO",
    "ChatFontNormal",
    "MDT",
    "MethodDungeonTools",
}

files["Locales/*.lua"] = {
    globals = {
        "LibStub",
    },
    ignore = {
        "211",
    },
}

files["Data/**/*.lua"] = {
    ignore = {
        "211",
    },
}

files["Modules/Changelog/**/*.lua"] = {
    ignore = {
        "211",
    },
}
