local AddOnName, KeystonePolaris = ...;

local _G = _G;
-- Cache frequently used global functions for better performance
local pairs, unpack, select = pairs, unpack, select

-- Initialize Ace3 libraries
local AceAddon = LibStub("AceAddon-3.0")
KeystonePolaris = AceAddon:NewAddon(KeystonePolaris, AddOnName, "AceConsole-3.0", "AceEvent-3.0");

-- Initialize changelog
KeystonePolaris.Changelog = {}

-- Define constants
KeystonePolaris.constants = {
    mediaPath = "Interface\\AddOns\\" .. AddOnName .. "\\media\\"
}

-- Track the last routes update version for prompting users
KeystonePolaris.lastRoutesUpdate = "2.0.1" -- Set to true when routes have been updated

-- Table to store dungeons with changed routes
KeystonePolaris.CHANGED_ROUTES_DUNGEONS = {
    ["HoA"] = true,
}

-- Initialize Ace3 configuration libraries
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Initialize LibSharedMedia for font and texture support
KeystonePolaris.LSM = LibStub('LibSharedMedia-3.0');

-- Get localization table
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName, true)
KeystonePolaris.L = L

-- Initialize dungeons table to store all dungeon data
KeystonePolaris.DUNGEONS = {}


-- Track current dungeon and section
KeystonePolaris.currentDungeonID = 0
KeystonePolaris.currentSection = 1
KeystonePolaris.currentSectionOrder = nil

-- Called when the addon is first loaded
function KeystonePolaris:OnInitialize()
    -- Initialize the database first with AceDB
    self.db = LibStub("AceDB-3.0"):New("KeystonePolarisDB", self.defaults, "Default")

    -- Load dungeon data from expansion modules
    self:LoadExpansionDungeons()

    -- Generate changelog for display in options
    self:GenerateChangelog()

    -- Check if a new season has started
    self:CheckForNewSeason()

    -- Check if routes have been updated in a new version
    self:CheckForNewRoutes()

    -- Initialize Display (Frames, Overlay, Anchors) - Moved to Modules/Display.lua
    if self.InitializeDisplay then
        self:InitializeDisplay()
    end

    -- Register options with Ace3 config system
    AceConfig:RegisterOptionsTable(AddOnName, {
        name = "Keystone Polaris",
        type = "group",
        args = {
            general = {
                name = L["GENERAL_SETTINGS"],
                type = "group",
                order = 1,
                args = {
                    testMode = {
                        order = 0,
                        type = "toggle",
                        name = L["TEST_MODE"] or "Test Mode",
                        desc = L["TEST_MODE_DESC"],
                        width = "full",
                        get = function()
                            return self._testMode or false
                        end,
                        set = function(_, value)
                            self._testMode = not not value
                            if self._testMode then
                                -- Close settings so the user can see the preview behind
                                if HideUIPanel and _G.SettingsPanel then HideUIPanel(_G.SettingsPanel) end
                                if self.ShowTestOverlay then self:ShowTestOverlay() end
                                if self.StartTestModeTicker then self:StartTestModeTicker() end
                            else
                                if self.HideTestOverlay then self:HideTestOverlay() end
                                if self.StopTestModeTicker then self:StopTestModeTicker() end
                            end
                            if self.UpdatePercentageText then self:UpdatePercentageText() end
                            if self.Refresh then self:Refresh() end
                        end,
                    },
                    generalHeader = {
                        order = 0.1,
                        type = "header",
                        name = L["GENERAL_SETTINGS"],
                    },
                    positioning = self:GetPositioningOptions(),
                    font = self:GetFontOptions(),
                    colors = self:GetColorOptions(),
                    mainDisplay = self:GetMainDisplayOptions(),
                    otherOptions = self:GetOtherOptions(),
                }
            },
            modules = {
                name = L["MODULES"],
                type = "group",
                order = 2,
                childGroups = "tree",
                args = {
                    mdtIntegration = {
                        name = L["MDT_INTEGRATION"],
                        type = "group",
                        order = 2,
                        args = {
                            mdtIntegrationHeader = {
                                order = 0,
                                type = "header",
                                name = L["MDT_INTEGRATION"],
                            },
                            mdtWarning = {
                                name = L["MDT_SECTION_WARNING"],
                                type = "description",
                                order = 1,
                                fontSize = "medium",
                            },
                            -- Information about MDT integration features
                            featuresHeader = {
                                order = 2,
                                type = "header",
                                name = L["MDT_INTEGRATION_FEATURES"],
                            },
                            mobPercentagesInfo = {
                                name = L["MOB_PERCENTAGES_INFO"],
                                type = "description",
                                order = 4,
                                fontSize = "medium",
                            },
                            mobPercentages = self:GetMobPercentagesOptions(),
                        }
                    },
                }
            },
            advanced = self:GetAdvancedOptions()
        }
    })
    AceConfig:RegisterOptionsTable(AddOnName .. "_Changelog", self.changelogOptions)

    AceConfigDialog:AddToBlizOptions(AddOnName, "Keystone Polaris")
    AceConfigDialog:AddToBlizOptions(AddOnName .. "_Changelog", L['Changelog'], "Keystone Polaris")


    -- Register chat command and events
    self:RegisterChatCommand('kph', 'ToggleConfig')
    -- Quick test command to force migration popup
    self:RegisterChatCommand('kpl_mig', 'ShowMigrationPopup')

    -- Initialize mob percentages module if enabled
    if self.db.profile.mobPercentages and self.db.profile.mobPercentages.enabled then
        self:InitializeMobPercentages()
    end
end

-- Open configuration panel when command is used
function KeystonePolaris:ToggleConfig()
    Settings.OpenToCategory("Keystone Polaris")
end

-- Handler for addon compartment button click
_G.KeystonePolaris_OnAddonCompartmentClick = function()
    KeystonePolaris:ToggleConfig()
end

-- Build logical section order for the given dungeon, using advanced bossOrder when available
function KeystonePolaris:BuildSectionOrder(dungeonId)
    self.currentSectionOrder = nil
    local dungeon = self.DUNGEONS[dungeonId]
    if not dungeon then return end

    local numBosses = #dungeon
    if numBosses == 0 then return end

    local order = {}
    local dungeonKey = self.GetDungeonKeyById and self:GetDungeonKeyById(dungeonId) or nil
    if dungeonKey and self.db and self.db.profile and self.db.profile.advanced and self.db.profile.advanced[dungeonKey] then
        local adv = self.db.profile.advanced[dungeonKey]
        local advOrder = adv.bossOrder
        if type(advOrder) == "table" then
            local valid = true
            for i = 1, numBosses do
                local idx = advOrder[i]
                if type(idx) ~= "number" or idx < 1 or idx > numBosses then
                    valid = false
                    break
                end
                order[i] = math.floor(idx)
            end
            if valid then
                self.currentSectionOrder = order
                return
            end
        end
    end

    -- Fallback: order by required percentage ascending
    for i = 1, numBosses do
        order[i] = i
    end
    table.sort(order, function(a, b)
        local da = dungeon[a]
        local db = dungeon[b]
        local pa = da and da[2] or 0
        local pb = db and db[2] or 0
        return pa < pb
    end)
    self.currentSectionOrder = order
end

-- Initialize dungeon tracking when entering a dungeon
function KeystonePolaris:InitiateDungeon()
    local currentDungeonId = C_ChallengeMode.GetActiveChallengeMapID()
    -- Return if not in a dungeon or already tracking this dungeon
    if currentDungeonId == nil or currentDungeonId == self.currentDungeonID then return end

    -- Set current dungeon and reset to first section
    self.currentDungeonID = currentDungeonId
    self.currentSection = 1
    self:BuildSectionOrder(self.currentDungeonID)
end

-- Get the current enemy forces percentage from the scenario UI
function KeystonePolaris:GetCurrentPercentage()
    -- Mirror WarpDeplete logic: scan criteria and use weighted progress with the
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return 0 end

    local bestTotal = 0
    local bestCurrent = 0
    for i = 1, stepCount do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress and info.totalQuantity and info.totalQuantity > 0 then
            local currentCount = 0
            if type(info.quantityString) == "string" then
                currentCount = tonumber(info.quantityString:match("%d+")) or 0
            else
                currentCount = tonumber(info.quantity) or 0
            end
            if info.totalQuantity > bestTotal then
                bestTotal = info.totalQuantity
                bestCurrent = currentCount
            end
        end
    end

    if bestTotal > 0 then
        return (bestCurrent / bestTotal) * 100
    end
    return 0
end

-- Retrieve raw Enemy Forces counts: current and total. Returns 0,0 if unavailable.
function KeystonePolaris:GetCurrentForcesInfo()
    local stepCount = select(3, C_Scenario.GetStepInfo())
    if not stepCount or stepCount <= 0 then return 0, 0 end

    local bestTotal = 0
    local bestCurrent = 0
    for i = 1, stepCount do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress and info.totalQuantity and info.totalQuantity > 0 then
            local currentCount = 0
            if type(info.quantityString) == "string" then
                currentCount = tonumber(info.quantityString:match("%d+")) or 0
            else
                currentCount = tonumber(info.quantity) or 0
            end
            if info.totalQuantity > bestTotal then
                bestTotal = info.totalQuantity
                bestCurrent = currentCount
            end
        end
    end

    return bestCurrent, bestTotal
end

-- Get data for the current section of the dungeon
function KeystonePolaris:GetDungeonData()
    local dungeon = self.DUNGEONS[self.currentDungeonID]
    if not dungeon then
        return nil
    end

    if not self.currentSectionOrder then
        if self.currentDungeonID then
            self:BuildSectionOrder(self.currentDungeonID)
        end
    end

    local order = self.currentSectionOrder
    if not order then
        return nil
    end

    local sectionIndex = order[self.currentSection]
    if not sectionIndex or not dungeon[sectionIndex] then
        return nil
    end

    local dungeonData = dungeon[sectionIndex]
    return dungeonData[1], dungeonData[2], dungeonData[3], dungeonData[4]
end

-- Send a chat message to inform the group about missing percentage
function KeystonePolaris:InformGroup(percentage)
    if not self.db.profile.general.informGroup then return end

    local channel = self.db.profile.general.informChannel
    local percentageStr = string.format("%.2f%%", percentage)
    -- Don't send message if percentage is 0
    if percentageStr == "0.00%" then return end
    SendChatMessage("[Keystone Polaris]: " .. L["WE_STILL_NEED"] .. " " .. percentageStr, channel)
end


-- Called when the addon is enabled
function KeystonePolaris:OnEnable()
    -- Ensure display exists and is visible
    if self.CreateDisplayFrame then
        self:CreateDisplayFrame()
    end

    -- Mythic+ mode triggers
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")

	-- Scenario triggers
	self:RegisterEvent("SCENARIO_POI_UPDATE")
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE")

    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Extra refresh triggers for dynamic current pull percent
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    self:RegisterEvent("ENCOUNTER_END")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Force an initial update
    if self.UpdatePercentageText then
        self:UpdatePercentageText()
    end
end

-- Event handler for POI updates (boss positions)
function KeystonePolaris:SCENARIO_POI_UPDATE()
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Event handler for criteria updates (enemy forces percentage changes)
function KeystonePolaris:SCENARIO_CRITERIA_UPDATE()
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- React to nameplate additions/removals to refresh dynamic pull percent
function KeystonePolaris:NAME_PLATE_UNIT_ADDED(event, unit)
    -- Maintain a map of nameplate unit -> GUID so we can cleanly remove on REMOVED
    self._nameplateUnits = self._nameplateUnits or {}
    if unit then
        local guid = UnitGUID(unit)
        if guid then
            self._nameplateUnits[unit] = guid
        end
    end
    -- Engagement tracking remains via COMBAT_LOG to avoid double counting
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:NAME_PLATE_UNIT_REMOVED(event, unit)
    -- Use stored GUID (UnitGUID may be nil after removal)
    -- Do not remove engaged mobs here: nameplates can disappear when rotating camera;
    -- rely on COMBAT_LOG (UNIT_DIED/UNIT_DESTROYED) and end-of-combat reset instead.
    if unit then
        local guid
        if self._nameplateUnits then
            guid = self._nameplateUnits[unit]
            self._nameplateUnits[unit] = nil
        end
        -- Intentionally not calling RemoveEngagedMobByGUID(guid) to avoid Pull% oscillation.
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Update when threat list changes (engagement state)
function KeystonePolaris:UNIT_THREAT_LIST_UPDATE(event, unit)
    -- Add mobs to current pull based on threat updates (WarpDeplete-like)
    if not C_ChallengeMode.IsChallengeModeActive() then return end
    if not (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    if not unit or not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- Prevent re-adding mobs that have been marked dead during this combat
    self._deadGuids = self._deadGuids or {}
    if self._deadGuids[guid] then return end

    -- If already tracked, just refresh lastSeen
    if self.realPull and self.realPull.mobs[guid] then
        local existing = self.realPull.mobs[guid]
        existing.lastSeen = (GetTime and GetTime()) or existing.lastSeen or 0
        return
    end

    -- Use AddEngagedMobByGUID which pulls MDT count/denom and updates sums
    self:AddEngagedMobByGUID(guid)
    self:_QueuePullUpdate()
end

-- Start of combat: reset real pull state
function KeystonePolaris:PLAYER_REGEN_DISABLED()
    if self._testMode and self.DisableTestMode then self:DisableTestMode("entered combat") end
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
    -- Start a lightweight watchdog ticker to clean stale GUIDs during combat
    if self._pullWatchdogTicker then
        self._pullWatchdogTicker:Cancel()
        self._pullWatchdogTicker = nil
    end
    local TTL = 8 -- seconds without activity before considering GUID stale
    self._pullWatchdogTicker = C_Timer.NewTicker(1, function()
        if not C_ChallengeMode.IsChallengeModeActive() then return end
        -- Build a quick lookup of currently visible nameplate GUIDs
        local plateGuids = {}
        if self._nameplateUnits then
            for unit, g in pairs(self._nameplateUnits) do
                if g then plateGuids[g] = true end
            end
        end
        local now = (GetTime and GetTime()) or 0
        for g, data in pairs(self.realPull.mobs) do
            local last = tonumber(data and data.lastSeen) or now
            if (now - last) >= TTL then
                -- Skip removal if GUID is clearly still in view/target
                local stillVisible = plateGuids[g]
                    or (UnitGUID and (g == UnitGUID("target") or g == UnitGUID("focus") or g == UnitGUID("mouseover")
                        or g == UnitGUID("boss1") or g == UnitGUID("boss2") or g == UnitGUID("boss3") or g == UnitGUID("boss4") or g == UnitGUID("boss5")))
                if not stillVisible then
                    self:RemoveEngagedMobByGUID(g)
                    self:_QueuePullUpdate()
                end
            end
        end
    end)
end

-- End of combat: clear and refresh
function KeystonePolaris:PLAYER_REGEN_ENABLED()
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
    if self._deadGuids then
        wipe(self._deadGuids)
    end
    if self._pullWatchdogTicker then
        self._pullWatchdogTicker:Cancel()
        self._pullWatchdogTicker = nil
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Reset pull state when an encounter ends (e.g., boss end), mirroring WarpDeplete behavior
function KeystonePolaris:ENCOUNTER_END()
    self.realPull.mobs = {}
    self.realPull.sum = 0
    self.realPull.denom = 0
    if self._deadGuids then
        wipe(self._deadGuids)
    end
    if self._pullWatchdogTicker then
        self._pullWatchdogTicker:Cancel()
        self._pullWatchdogTicker = nil
    end
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Throttled updater for combat log bursts
function KeystonePolaris:_QueuePullUpdate()
    if self._pullUpdateQueued then return end
    self._pullUpdateQueued = true
    C_Timer.After(0.1, function()
        self._pullUpdateQueued = nil
        if self.UpdatePercentageText then self:UpdatePercentageText() end
    end)
end

-- Listen to combat log to track engaged NPCs even when nameplates are not visible
function KeystonePolaris:COMBAT_LOG_EVENT_UNFILTERED()
    if not C_ChallengeMode.IsChallengeModeActive() then return end
    local info = { CombatLogGetCurrentEventInfo() }
    local subEvent = info[2]
    -- WoW API order: 4=sourceGUID, 6=sourceFlags, 8=destGUID, 10=destFlags
    local srcGUID, srcFlags = info[4], info[6]
    local destGUID, destFlags = info[8], info[10]

    local function IsGroup(flags)
        local mask = bit.bor(
            COMBATLOG_OBJECT_AFFILIATION_MINE or 0,
            COMBATLOG_OBJECT_AFFILIATION_PARTY or 0,
            COMBATLOG_OBJECT_AFFILIATION_RAID or 0
        )
        local f = tonumber(flags) or 0
        return bit.band(f, mask) ~= 0
    end
    local function IsNPCGuid(guid)
        return type(guid) == "string" and (guid:find("^Creature%-") or guid:find("^Vehicle%-"))
    end

    if subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" or subEvent == "UNIT_DISSIPATES" or subEvent == "SPELL_INSTAKILL" or subEvent == "PARTY_KILL" then
        if IsNPCGuid(destGUID) then
            self._deadGuids = self._deadGuids or {}
            self._deadGuids[destGUID] = true
            self:RemoveEngagedMobByGUID(destGUID)
            self:_QueuePullUpdate()
        end
        return
    end

    -- Detect engagement in both directions (group -> npc or npc -> group)
    -- Do NOT treat aura applications (e.g., CC) as engagement. We no longer add via CLEU;
    -- additions are handled by UNIT_THREAT_LIST_UPDATE to avoid false positives and match WarpDeplete behavior.
    return
end

-- Event handler for starting a Mythic+ dungeon
function KeystonePolaris:CHALLENGE_MODE_START()
    if self._testMode and self.DisableTestMode then self:DisableTestMode("started dungeon") end
    self.currentDungeonID = nil

    self:InitiateDungeon()
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

function KeystonePolaris:CHALLENGE_MODE_COMPLETED()
    self.currentDungeonID = nil
end

-- Event handler for entering the world or changing zones
function KeystonePolaris:PLAYER_ENTERING_WORLD()
    if self._testMode and self.DisableTestMode then self:DisableTestMode("changed zone") end
    self:InitiateDungeon()
    if self.UpdatePercentageText then self:UpdatePercentageText() end
end

-- Update dungeon data with advanced options if enabled
function KeystonePolaris:UpdateDungeonData()
    if self.db.profile.general.advancedOptionsEnabled then
        for dungeonId, dungeonData in pairs(self.DUNGEONS) do
            local dungeonKey = self:GetDungeonKeyById(dungeonId)
            if dungeonKey and self.db.profile.advanced[dungeonKey] then
                local advancedData = self.db.profile.advanced[dungeonKey]
                for i, bossData in ipairs(dungeonData) do
                    local bossNumStr = self:GetBossNumberString(i)
                    bossData[2] = advancedData["Boss"..bossNumStr]
                    bossData[3] = advancedData["Boss" .. bossNumStr .. "Inform"]
                    bossData[4] = false -- Reset informed status
                end
            end
        end
    end
end
