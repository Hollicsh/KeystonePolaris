local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- ---------------------------------------------------------------------------
-- Dungeon Data & Management
-- ---------------------------------------------------------------------------

-- List of expansions and their corresponding data
-- Exposed to the addon object so other modules can access it if needed
KeystonePolaris.Expansions = {
    {id = "MIDNIGHT", name = "EXPANSION_MIDNIGHT", order = 3}, -- Midnight
    {id = "TWW", name = "EXPANSION_WW", order = 4}, -- The War Within
    {id = "DF", name = "EXPANSION_DF", order = 5}, -- Dragonflight
    {id = "SL", name = "EXPANSION_SL", order = 6}, -- Shadowlands
    {id = "BFA", name = "EXPANSION_BFA", order = 7}, -- Battle for Azeroth
    {id = "LEGION", name = "EXPANSION_LEGION", order = 8}, -- Legion
    {id = "WOD", name = "EXPANSION_WOD", order = 9},       -- Warlords of Draenor
    -- {id = "MOP", name = "EXPANSION_MOP", order = 10},      -- Mists of Pandaria
    {id = "CATACLYSM", name = "EXPANSION_CATA", order = 11}, -- Cataclysm
    {id = "WOTLK", name = "EXPANSION_WOTLK", order = 12}, -- Wrath of the Lich King
    -- {id = "TBC", name = "EXPANSION_TBC", order = 13} -- The Burning Crusade
    -- {id = "Vanilla", name = "EXPANSION_VANILLA", order = 14} -- Vanilla WoW
}

local expansions = KeystonePolaris.Expansions

-- Initialize Season Start Dates
local portal = C_CVar.GetCVar("portal")
if portal == "US" then
    KeystonePolaris.SEASON_START_DATES = {
        ["2024-09-10"] = "TWW_1", -- TWW Season 1 start date
        ["2025-03-04"] = "TWW_2", -- TWW Season 2 start date
        ["2025-08-12"] = "TWW_3",  -- TWW Season 3 start date
        ["2026-03-24"] = "MIDNIGHT_1" -- Midnight Season 1 start date
    }
elseif portal == "EU" then
    KeystonePolaris.SEASON_START_DATES = {
        ["2024-09-10"] = "TWW_1", -- TWW Season 1 start date
        ["2025-03-05"] = "TWW_2", -- TWW Season 2 start date
        ["2025-08-13"] = "TWW_3",  -- TWW Season 3 start date
        ["2026-03-25"] = "MIDNIGHT_1" -- Midnight Season 1 start date
    }
else
    KeystonePolaris.SEASON_START_DATES = {
        ["2024-09-10"] = "TWW_1", -- TWW Season 1 start date
        ["2025-03-05"] = "TWW_2", -- TWW Season 2 start date
        ["2025-08-13"] = "TWW_3",  -- TWW Season 3 start date
        ["2026-03-25"] = "MIDNIGHT_1" -- Midnight Season 1 start date
    }
end

-- Shallow clone helper
local function CloneTable(tbl)
    if type(CopyTable) == "function" then return CopyTable(tbl) end
    local t = {}
    for k, v in pairs(tbl) do t[k] = v end
    return t
end

function KeystonePolaris:GetBossNumberString(num)
    local numbers = {
        [1] = "One",
        [2] = "Two",
        [3] = "Three",
        [4] = "Four",
        [5] = "Five",
        [6] = "Six",
        [7] = "Seven",
        [8] = "Eight",
        [9] = "Nine",
        [10] = "Ten"
    }
    return numbers[num] or tostring(num)
end

function KeystonePolaris:GenerateExpansionTables(expansionId, dungeonData)
    -- Initialize the tables if they don't exist
    self[expansionId .. "_DUNGEONS"] = self[expansionId .. "_DUNGEONS"] or {}
    self[expansionId .. "_DEFAULTS"] = self[expansionId .. "_DEFAULTS"] or {}
    self[expansionId .. "_DUNGEON_IDS"] = self[expansionId .. "_DUNGEON_IDS"] or {}
    self[expansionId .. "_DUNGEON_NAMES"] = self[expansionId .. "_DUNGEON_NAMES"] or {}

    -- Clear existing data if any
    wipe(self[expansionId .. "_DUNGEONS"])
    wipe(self[expansionId .. "_DEFAULTS"])
    wipe(self[expansionId .. "_DUNGEON_IDS"])
    wipe(self[expansionId .. "_DUNGEON_NAMES"])

    for shortName, dData in pairs(dungeonData) do
        -- Support for 'hidden' flag to skip unimplemented dungeons
        if not dData.hidden then
            -- Generate DUNGEONS table
            local dungeonBosses = {}
            for i, bossData in ipairs(dData.bosses) do
                -- Add haveInformed = false to each boss entry
                dungeonBosses[i] = {bossData[1], bossData[2], bossData[3], false}
            end
            self[expansionId .. "_DUNGEONS"][dData.id] = dungeonBosses

            -- Generate DEFAULTS table
            local defaults = {}
            local numBosses = #dData.bosses
            local bossOrder = {}
            for i, bossData in ipairs(dData.bosses) do
                local bossNumber = "Boss" .. self:GetBossNumberString(i)
                defaults[bossNumber] = bossData[2]
                defaults[bossNumber .. "Inform"] = bossData[3]

                -- Optional 4th field in bossData defines the logical section order (rank)
                local rank = bossData[4]
                if type(rank) == "number" then
                    rank = math.floor(rank)
                    if rank >= 1 and rank <= numBosses then
                        bossOrder[rank] = i
                    end
                end
            end

            -- Only store bossOrder if it forms a complete permutation of 1..numBosses
            local hasOrder = next(bossOrder) ~= nil
            if hasOrder then
                for idx = 1, numBosses do
                    if not bossOrder[idx] then
                        hasOrder = false
                        break
                    end
                end
            end
            if hasOrder then
                defaults.bossOrder = bossOrder
            end

            self[expansionId .. "_DEFAULTS"][shortName] = defaults
        end

        -- Always generate IDS and NAMES tables, even if hidden, so they can be referenced
        self[expansionId .. "_DUNGEON_IDS"][shortName] = dData.id
        self[expansionId .. "_DUNGEON_NAMES"][shortName] = dData.displayName
    end
end

function KeystonePolaris:LoadExpansionDungeons()
    -- Initialize Global Lookup Table for faster access
    self.GlobalDungeonLookup = {} -- Maps dungeonKey (shortName) -> dungeonData
    self.GlobalDungeonIDLookup = {} -- Maps dungeonID -> dungeonKey

    -- Process dungeon data and generate tables for all expansions
    for _, expansion in ipairs(expansions) do
        local dungeonData = self[expansion.id .. "_DUNGEON_DATA"]
        if dungeonData then
            -- Generate the tables for this expansion
            self:GenerateExpansionTables(expansion.id, dungeonData)

            -- Populate Global Lookup and Initialize defaults
            for shortName, dData in pairs(dungeonData) do
                -- Add to global lookup
                self.GlobalDungeonLookup[shortName] = dData
                if dData.id then
                    self.GlobalDungeonIDLookup[dData.id] = shortName
                end

                -- Ensure the advanced settings table exists for this dungeon
                if not self.db.profile.advanced[shortName] then
                    self.db.profile.advanced[shortName] = {}
                end

                -- Initialize with defaults if needed (only if not hidden, effectively)
                local defaults = self[expansion.id .. "_DEFAULTS"][shortName]
                if defaults then
                    for key, value in pairs(defaults) do
                        if self.db.profile.advanced[shortName][key] == nil then
                            self.db.profile.advanced[shortName][key] = value
                        end
                    end
                end
            end

            -- Load dungeons into the main DUNGEONS table
            local dungeons = self[expansion.id .. "_DUNGEONS"]
            if dungeons then
                for id, data in pairs(dungeons) do
                    self.DUNGEONS[id] = data
                end
            end
        end
    end
    
    -- Load defaults for AceConfig profile from generated expansion defaults
    -- This ensures that even if we reset profile, we have the right defaults
    for _, expansion in ipairs(expansions) do
        local defaults = self[expansion.id .. "_DEFAULTS"]
        if defaults then
            for k, v in pairs(defaults) do
                KeystonePolaris.defaults.profile.advanced[k] = v
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Data Accessors (Optimized with Global Lookup)
-- ---------------------------------------------------------------------------

function KeystonePolaris:GetDungeonEncounterID(dungeonKey, bossIndex)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData and dungeonData.bosses and dungeonData.bosses[bossIndex] then
        return dungeonData.bosses[bossIndex][5]
    end
    return nil
end

function KeystonePolaris:GetBossName(dungeonKey, bossIdx)
    local name
    local encounterID = self:GetDungeonEncounterID(dungeonKey, bossIdx)

    if encounterID then
        -- Try to get name from Encounter Journal using the ID
        name = EJ_GetEncounterInfo(encounterID)
    end

    if not name then
        -- Try to find manual boss name (6th parameter)
        local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
        if dungeonData and dungeonData.bosses and dungeonData.bosses[bossIdx] then
            name = dungeonData.bosses[bossIdx][6]
        end
    end

    return name or ("Boss " .. bossIdx)
end

function KeystonePolaris:GetDungeonMapID(dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData then
        return dungeonData.mapID
    end
    return nil
end

function KeystonePolaris:GetDungeonIdByKey(dungeonKey)
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData then
        return dungeonData.id
    end
    return nil
end

function KeystonePolaris:GetDungeonKeyById(dungeonId)
    return self.GlobalDungeonIDLookup and self.GlobalDungeonIDLookup[dungeonId] or nil
end

function KeystonePolaris:GetDungeonDisplayName(dungeonKey)
    if not dungeonKey then return "Unknown Dungeon" end

    local mapId = self:GetDungeonIdByKey(dungeonKey)

    local name
    if mapId then
        name, _, _, _ = C_ChallengeMode.GetMapUIInfo(mapId)
        if name then return name end
    end

    -- Try manual display name from data
    local dungeonData = self.GlobalDungeonLookup and self.GlobalDungeonLookup[dungeonKey]
    if dungeonData and dungeonData.displayName then
        return dungeonData.displayName
    end

    -- Fallback: Try to make the key look presentable
    name = dungeonKey:gsub("_", " ")
    name = name:gsub("(%l)(%u)", "%1 %2") -- Add space between lower and upper case
    name = name:gsub("^%l", string.upper) -- Capitalize first letter
    return name
end

-- ---------------------------------------------------------------------------
-- Season & Update Management
-- ---------------------------------------------------------------------------

function KeystonePolaris:IsCurrentSeasonDungeon(dungeonId)
    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- Find the most recent season
    local mostRecentSeasonDate = nil
    local currentSeasonId = nil

    for seasonDate, _ in pairs(self.SEASON_START_DATES) do
        if seasonDate <= currentDate and
            (not mostRecentSeasonDate or seasonDate > mostRecentSeasonDate) then
            currentSeasonId = self.SEASON_START_DATES[seasonDate]
            mostRecentSeasonDate = seasonDate
        end
    end

    if currentSeasonId then
        local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
        local seasonDungeons = self[seasonDungeonsTabName]

        if seasonDungeons then return seasonDungeons[dungeonId] or false end
    end

    return false
end

function KeystonePolaris:IsNextSeasonDungeon(dungeonId)
    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- Find the next season (first season that starts after current date)
    local nextSeasonDate = nil
    local nextSeasonId = nil

    for seasonDate, _ in pairs(self.SEASON_START_DATES) do
        if seasonDate > currentDate and
            (not nextSeasonDate or seasonDate < nextSeasonDate) then
            nextSeasonId = self.SEASON_START_DATES[seasonDate]
            nextSeasonDate = seasonDate
        end
    end

    if nextSeasonId then
        local nextSeasonDungeonsTabName = nextSeasonId .. "_DUNGEONS"
        local nextSeasonDungeons = self[nextSeasonDungeonsTabName]

        if nextSeasonDungeons then
            return nextSeasonDungeons[dungeonId] or false
        end
    end

    return false
end

function KeystonePolaris:ResetAllDungeons()
    local self = KeystonePolaris
    -- Reset all dungeons to their defaults
    -- Use global lookup for iteration if possible, or iterate expansions to keep order/structure logic
    for _, expansion in ipairs(expansions) do
        local dungeonIds = self[expansion.id .. "_DUNGEON_IDS"]
        if dungeonIds then
            for dungeonKey, _ in pairs(dungeonIds) do
                -- Get the appropriate defaults
                local defaults = self[expansion.id .. "_DEFAULTS"][dungeonKey]

                if defaults then
                    if not self.db.profile.advanced[dungeonKey] then
                        self.db.profile.advanced[dungeonKey] = {}
                    else
                        wipe(self.db.profile.advanced[dungeonKey])
                    end
                    for key, value in pairs(defaults) do
                        if type(value) == "table" then
                            self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                        else
                            self.db.profile.advanced[dungeonKey][key] = value
                        end
                    end
                end
            end
        end
    end

    -- Update the display
    self:UpdateDungeonData()
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:ResetCurrentSeasonDungeons(specificDungeons)
    local self = KeystonePolaris

    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- Find the most recent season
    local mostRecentSeasonDate = nil
    local currentSeasonId = nil

    for seasonDate, _ in pairs(self.SEASON_START_DATES) do
        if seasonDate <= currentDate and
            (not mostRecentSeasonDate or seasonDate > mostRecentSeasonDate) then
            currentSeasonId = self.SEASON_START_DATES[seasonDate]
            mostRecentSeasonDate = seasonDate
        end
    end

    if currentSeasonId then
        local seasonDungeonsTabName = currentSeasonId .. "_DUNGEONS"
        local seasonDungeons = self[seasonDungeonsTabName]

        if seasonDungeons then
            -- Reset only the current season dungeons to their defaults
            for dungeonId, _ in pairs(seasonDungeons) do
                local dungeonKey = self:GetDungeonKeyById(dungeonId)
                if dungeonKey then
                    -- If specificDungeons is provided, only reset those dungeons
                    if specificDungeons and not specificDungeons[dungeonKey] then
                        -- Skip this dungeon as it's not in the list of dungeons to reset
                    else
                        -- Find the appropriate defaults for this dungeon
                        -- Using global lookup logic could simplify, but sticking to existing struct for safety
                        local defaults
                        for _, expansion in ipairs(expansions) do
                            if self[expansion.id .. "_DUNGEON_IDS"] and
                                self[expansion.id .. "_DUNGEON_IDS"][dungeonKey] then
                                defaults =
                                    self[expansion.id .. "_DEFAULTS"][dungeonKey]
                                break
                            end
                        end

                        if defaults then
                            if not self.db.profile.advanced[dungeonKey] then
                                self.db.profile.advanced[dungeonKey] = {}
                            else
                                wipe(self.db.profile.advanced[dungeonKey])
                            end
                            for key, value in pairs(defaults) do
                                if type(value) == "table" then
                                    self.db.profile.advanced[dungeonKey][key] = CloneTable(value)
                                else
                                    self.db.profile.advanced[dungeonKey][key] = value
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Update the display
    self:UpdateDungeonData()
    if self.currentDungeonID and self.BuildSectionOrder then
        self:BuildSectionOrder(self.currentDungeonID)
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("KeystonePolaris")
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:CheckForNewSeason()
    local self = KeystonePolaris
    local currentDate = date("%Y-%m-%d")

    -- If this is first load (lastSeasonCheck is empty), just set the date and don't show popup
    if not self.db.profile.lastSeasonCheck or self.db.profile.lastSeasonCheck ==
        "" then
        self.db.profile.lastSeasonCheck = currentDate
        return
    end

    -- Find the most recent season start date
    local mostRecentSeasonDate = nil
    for seasonDate, _ in pairs(self.SEASON_START_DATES) do
        if seasonDate <= currentDate and
            (not mostRecentSeasonDate or seasonDate > mostRecentSeasonDate) then
            mostRecentSeasonDate = seasonDate
        end
    end

    -- If last check was before the most recent season start, show popup
    if mostRecentSeasonDate and self.db.profile.lastSeasonCheck <
        mostRecentSeasonDate and not InCombatLockdown() then
        StaticPopupDialogs["KPL_NEW_SEASON"] = {
            text = "|cffffd100Keystone Polaris|r\n\n" ..
                L["NEW_SEASON_RESET_PROMPT"] .. "\n\n",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                -- Reset only current season dungeon values
                self:ResetCurrentSeasonDungeons()
                self.db.profile.lastSeasonCheck = currentDate
            end,
            OnCancel = function()
                self.db.profile.lastSeasonCheck = currentDate
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            showAlert = true,
            title = "Keystone Polaris"
        }
        StaticPopup_Show("KPL_NEW_SEASON")
    end
end

function KeystonePolaris:GetChangedDungeonsText()
    local self = KeystonePolaris
    local changedDungeonsText = ""

    -- Vérifier si la table CHANGED_ROUTES_DUNGEONS existe et n'est pas vide
    if self.CHANGED_ROUTES_DUNGEONS and next(self.CHANGED_ROUTES_DUNGEONS) then
        changedDungeonsText = L["CHANGED_ROUTES_DUNGEONS_LIST"] .. "\n"

        for dungeonKey, _ in pairs(self.CHANGED_ROUTES_DUNGEONS) do
            local displayName = self:GetDungeonDisplayName(dungeonKey) or
                                    dungeonKey
            changedDungeonsText = changedDungeonsText .. "- " .. displayName ..
                                      "\n"
        end
        changedDungeonsText = changedDungeonsText .. "\n"
    end

    return changedDungeonsText
end

-- ---------------------------------------------------------------------------
-- Dungeon State & Tracking
-- ---------------------------------------------------------------------------

-- Track currently engaged mobs for real pull percent
KeystonePolaris.realPull = {
    mobs = {},    -- [guid] = { npcID = number, count = number }
    sum = 0,      -- total count across engaged GUIDs
    denom = 0,    -- MDT total required count for 100%
}

-- Helpers to manage real pull set
function KeystonePolaris:AddEngagedMobByGUID(guid)
    if not guid then return end
    -- If already tracked, just refresh lastSeen and return
    local existing = self.realPull.mobs[guid]
    if existing then
        existing.lastSeen = (GetTime and GetTime()) or existing.lastSeen or 0
        return
    end
    local DungeonTools = _G and (_G.MDT or _G.MethodDungeonTools)
    if not DungeonTools or not DungeonTools.GetEnemyForces then return end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    local id = tonumber(npcID)
    if not id then return end

    local count, max, maxTeeming, teemingCount = DungeonTools:GetEnemyForces(id)
    local isTeeming = self.IsTeeming and self:IsTeeming() or false
    local denom = (isTeeming and maxTeeming) or max
    local c = (isTeeming and teemingCount) or count
    c = tonumber(c) or 0
    denom = tonumber(denom) or 0

    -- Initialize denominator when first known
    if self.realPull.denom == 0 and denom > 0 then
        self.realPull.denom = denom
    end

    if c > 0 then
        self.realPull.mobs[guid] = { npcID = id, count = c, lastSeen = (GetTime and GetTime()) or 0 }
        self.realPull.sum = self.realPull.sum + c
    end
end

function KeystonePolaris:RemoveEngagedMobByGUID(guid)
    local data = guid and self.realPull.mobs[guid]
    if not data then return end
    self.realPull.sum = math.max(0, self.realPull.sum - (data.count or 0))
    self.realPull.mobs[guid] = nil
end

-- Compute current planned pull percent via MDT (if available)
function KeystonePolaris:GetCurrentPullPercent()
    if not C_ChallengeMode.IsChallengeModeActive() then return 0 end
    local denom = tonumber(self.realPull.denom) or 0
    local sum = tonumber(self.realPull.sum) or 0
    if denom <= 0 or sum <= 0 then return 0 end
    return (sum / denom) * 100
end

function KeystonePolaris:CheckForNewRoutes()
    local currentVersion = C_AddOns.GetAddOnMetadata("KeystonePolaris",
                                                     "Version")
    local lastVersionCheck = self.db.profile.general.lastVersionCheck or ""
    local lastSeasonCheck = self.db.profile.lastSeasonCheck or ""
    local lastRoutesUpdate = self.lastRoutesUpdate or ""

    -- Get the current date
    local currentDate = date("%Y-%m-%d")

    -- If it's the first version check but the user already had a previous version installed
    -- (indicated by lastSeasonCheck being populated), and we need to prompt for route reset
    if lastVersionCheck == "" and self.db.profile.general.advancedOptionsEnabled and
        currentDate > lastSeasonCheck and not InCombatLockdown() then
        local changedDungeonsText = self:GetChangedDungeonsText()

        StaticPopupDialogs["KPL_NEW_ROUTES"] = {
            text = "|cffffd100Keystone Polaris|r\n\n" ..
                L["NEW_ROUTES_RESET_PROMPT"] .. "\n\n" .. changedDungeonsText,
            button1 = L["RESET_ALL"],
            button2 = L["NO"],
            button3 = (self.CHANGED_ROUTES_DUNGEONS and
                next(self.CHANGED_ROUTES_DUNGEONS)) and L["RESET_CHANGED_ONLY"] or
                nil,
            OnAccept = function()
                -- Reset all current season dungeon values
                self:ResetCurrentSeasonDungeons()
                self.db.profile.general.lastVersionCheck = currentVersion
            end,
            OnAlt = function()
                -- Reset only dungeons with changed routes
                self:ResetCurrentSeasonDungeons(self.CHANGED_ROUTES_DUNGEONS)
                self.db.profile.general.lastVersionCheck = currentVersion
            end,
            OnCancel = function()
                self.db.profile.general.lastVersionCheck = currentVersion
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            showAlert = true,
            title = "Keystone Polaris"
        }
        StaticPopup_Show("KPL_NEW_ROUTES")
        return
        -- If it's the first initialization of the addon (both checks are empty), just store the current version
    elseif lastVersionCheck == "" and lastSeasonCheck == "" then
        self.db.profile.general.lastVersionCheck = currentVersion
        return
    end

    -- If the version has changed and we need to prompt for route reset
    local prevWasBeta = (lastVersionCheck ~= "" and lastVersionCheck:lower():find("beta", 1, true) ~= nil)
    if lastVersionCheck ~= currentVersion and
        self.db.profile.general.advancedOptionsEnabled and
        not InCombatLockdown() and
        currentDate > lastSeasonCheck and
        (((lastRoutesUpdate > lastVersionCheck or lastVersionCheck == "") and currentVersion >= lastRoutesUpdate) or prevWasBeta) then

        local changedDungeonsText = self:GetChangedDungeonsText()

        StaticPopupDialogs["KPL_NEW_ROUTES"] = {
            text = "|cffffd100Keystone Polaris|r\n\n" ..
                L["NEW_ROUTES_RESET_PROMPT"] .. "\n\n" .. changedDungeonsText,
            button1 = L["RESET_ALL"],
            button2 = L["NO"],
            button3 = (self.CHANGED_ROUTES_DUNGEONS and
                next(self.CHANGED_ROUTES_DUNGEONS)) and L["RESET_CHANGED_ONLY"] or
                nil,
            OnAccept = function()
                -- Reset all current season dungeon values
                self:ResetCurrentSeasonDungeons()
                self.db.profile.general.lastVersionCheck = currentVersion
            end,
            OnAlt = function()
                -- Reset only dungeons with changed routes
                self:ResetCurrentSeasonDungeons(self.CHANGED_ROUTES_DUNGEONS)
                self.db.profile.general.lastVersionCheck = currentVersion
            end,
            OnCancel = function()
                self.db.profile.general.lastVersionCheck = currentVersion
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            showAlert = true,
            title = "Keystone Polaris"
        }
        StaticPopup_Show("KPL_NEW_ROUTES")
    else
        -- Update the version check without prompting
        self.db.profile.general.lastVersionCheck = currentVersion
    end
end
