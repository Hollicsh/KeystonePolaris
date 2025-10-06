local AddOnName, KeystonePercentageHelper = ...;

local _G = _G;
-- Cache frequently used global functions for better performance
local pairs, unpack, select = pairs, unpack, select

-- Initialize Ace3 libraries
local AceAddon = LibStub("AceAddon-3.0")
KeystonePercentageHelper = AceAddon:NewAddon(KeystonePercentageHelper, AddOnName, "AceConsole-3.0", "AceEvent-3.0");

-- Initialize changelog
KeystonePercentageHelper.Changelog = {}

-- Define constants
KeystonePercentageHelper.constants = {
    mediaPath = "Interface\\AddOns\\" .. AddOnName .. "\\media\\"
}

-- Track the last routes update version for prompting users
KeystonePercentageHelper.lastRoutesUpdate = "2.0.1" -- Set to true when routes have been updated

-- Table to store dungeons with changed routes
KeystonePercentageHelper.CHANGED_ROUTES_DUNGEONS = {
    ["HoA"] = true,
}

-- Initialize Ace3 configuration libraries
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Initialize LibSharedMedia for font and texture support
KeystonePercentageHelper.LSM = LibStub('LibSharedMedia-3.0');

-- Get localization table
local L = KeystonePercentageHelper.L;

-- Initialize dungeons table to store all dungeon data
KeystonePercentageHelper.DUNGEONS = {}

-- Track currently engaged mobs for real pull percent
KeystonePercentageHelper.realPull = {
    mobs = {},    -- [guid] = { npcID = number, count = number }
    sum = 0,      -- total count across engaged GUIDs
    denom = 0,    -- MDT total required count for 100%
}

-- Track current dungeon and section
KeystonePercentageHelper.currentDungeonID = 0
KeystonePercentageHelper.currentSection = 1

-- Called when the addon is first loaded
function KeystonePercentageHelper:OnInitialize()
    -- Initialize the database first with AceDB
    self.db = LibStub("AceDB-3.0"):New("KeystonePercentageHelperDB", self.defaults, "Default")

    -- Load dungeon data from expansion modules
    self:LoadExpansionDungeons()

    -- Generate changelog for display in options
    self:GenerateChangelog()

    -- Check if a new season has started
    self:CheckForNewSeason()

    -- Check if routes have been updated in a new version
    self:CheckForNewRoutes()

    -- Create overlay frame for positioning UI
    self.overlayFrame = CreateFrame("Frame", "KeystonePercentageHelperOverlay", UIParent, "BackdropTemplate")
    self.overlayFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.overlayFrame:SetAllPoints()
    self.overlayFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16,
    })
    self.overlayFrame:SetBackdropColor(0, 0, 0, 0.7)

    -- Create plus sign crosshair for positioning
    local lineThickness = 2

    -- Horizontal line for crosshair
    local horizontalLine = self.overlayFrame:CreateLine()
    horizontalLine:SetThickness(lineThickness)
    horizontalLine:SetColorTexture(1, 1, 1, 0.1)
    horizontalLine:SetStartPoint("LEFT")
    horizontalLine:SetEndPoint("RIGHT")

    -- Vertical line for crosshair
    local verticalLine = self.overlayFrame:CreateLine()
    verticalLine:SetThickness(lineThickness)
    verticalLine:SetColorTexture(1, 1, 1, 0.1)
    verticalLine:SetStartPoint("TOP")
    verticalLine:SetEndPoint("BOTTOM")

    self.overlayFrame:Hide()

    -- Create main display frame that shows percentage
    self.displayFrame = CreateFrame("Frame", "KeystonePercentageHelperFrame", UIParent)
    self.displayFrame:SetSize(200, 20)
    self.displayFrame:SetPoint(self.db.profile.general.position, UIParent, self.db.profile.general.position, self.db.profile.general.xOffset, self.db.profile.general.yOffset)

    -- Create text element for displaying percentage
    self.displayFrame.text = self.displayFrame:CreateFontString(nil, "OVERLAY")
    self.displayFrame.text:SetPoint("CENTER")
    self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, "OUTLINE")

    -- Create anchor frame for moving the display
    self.anchorFrame = CreateFrame("Frame", "KeystonePercentageHelperAnchorFrame", self.overlayFrame, "BackdropTemplate")
    self.anchorFrame:SetFrameStrata("TOOLTIP")
    self.anchorFrame:SetSize(200, 30)
    self.anchorFrame:SetPoint("CENTER", self.displayFrame, "CENTER", 0, 0)
    self.anchorFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    self.anchorFrame:SetBackdropColor(0, 0, 0, 0.5)
    self.anchorFrame:SetBackdropBorderColor(1, 1, 1, 1)

    -- Create text for the anchor frame
    local text = self.anchorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(L["ANCHOR_TEXT"])

    -- Create validate button to confirm position
    local validateButton = CreateFrame("Button", nil, self.anchorFrame, "UIPanelButtonTemplate")
    validateButton:SetSize(80, 30)
    validateButton:SetPoint("BOTTOMRIGHT", self.anchorFrame, "BOTTOMRIGHT", -10, -40)
    validateButton:SetText(L["VALIDATE"])
    validateButton:SetScript("OnClick", function()
        self.anchorFrame:Hide()
        self.overlayFrame:Hide()
        -- Show the settings panel and navigate to our addon
        Settings.OpenToCategory("Keystone Percentage Helper")
    end)

    -- Create cancel button to abort positioning
    local cancelButton = CreateFrame("Button", nil, self.anchorFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 30)
    cancelButton:SetPoint("BOTTOMLEFT", self.anchorFrame, "BOTTOMLEFT", 10, -40)
    cancelButton:SetText(L["CANCEL"])

    -- Function to cancel positioning and return to settings
    local function CancelPositioning()
        self.anchorFrame:Hide()
        self.overlayFrame:Hide()
        -- Show the settings panel and navigate to our addon
        Settings.OpenToCategory("Keystone Percentage Helper")
    end

-- Helpers to manage real pull set
function KeystonePercentageHelper:AddEngagedMobByGUID(guid)
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

function KeystonePercentageHelper:RemoveEngagedMobByGUID(guid)
    local data = guid and self.realPull.mobs[guid]
    if not data then return end
    self.realPull.sum = math.max(0, self.realPull.sum - (data.count or 0))
    self.realPull.mobs[guid] = nil
end

-- Resize the display frame to fit multi-line content when enabled
function KeystonePercentageHelper:AdjustDisplayFrameSize()
    if not self.displayFrame or not self.db or not self.db.profile then return end
    local cfg = self.db.profile.general.mainDisplay
    if not (cfg and cfg.multiLine) then
        -- Reset to default height for single-line usage
        self.displayFrame:SetHeight(30)
        return
    end
    local text = self.displayFrame.text:GetText() or ""
    local _, count = text:gsub("\n", "")
    local lines = (count or 0) + 1
    local lineHeight = self.db.profile.general.fontSize or 12
    local padding = 6
    self.displayFrame:SetHeight(lines * lineHeight + padding)
end

    cancelButton:SetScript("OnClick", CancelPositioning)

    -- Handle ESC key to cancel positioning
    self.anchorFrame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            CancelPositioning()
        end
    end)
    self.anchorFrame:EnableKeyboard(true)

    -- Handle combat state to hide positioning UI during combat
    local combatFrame = CreateFrame("Frame")
    combatFrame.wasShown = false
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Hide positioning UI when entering combat
            if self.anchorFrame:IsShown() then
                combatFrame.wasShown = true
                self.anchorFrame:Hide()
                self.overlayFrame:Hide()
            end
        elseif event == "PLAYER_REGEN_ENABLED" and combatFrame.wasShown then
            -- Restore positioning UI when leaving combat
            combatFrame.wasShown = false
            self.anchorFrame:Show()
            self.overlayFrame:Show()
        end
    end)

    -- Apply ElvUI skin if available for better integration
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.Skins then
            E:GetModule('Skins'):HandleButton(validateButton)
            E:GetModule('Skins'):HandleButton(cancelButton)
        end
    end

    -- Make anchor frame movable for positioning
    self.anchorFrame:EnableMouse(true)
    self.anchorFrame:SetMovable(true)
    self.anchorFrame:RegisterForDrag("LeftButton")
    self.anchorFrame:SetScript("OnDragStart", function() self.anchorFrame:StartMoving() end)
    self.anchorFrame:SetScript("OnDragStop", function()
        self.anchorFrame:StopMovingOrSizing()
        -- Update position based on anchor frame position
        local point, _, relativePoint, xOffset, yOffset = self.anchorFrame:GetPoint()
        self.db.profile.general.position = point
        self.db.profile.general.xOffset = xOffset
        self.db.profile.general.yOffset = yOffset
        self:Refresh()
    end)

    self.anchorFrame:Hide()

    -- Register options with Ace3 config system
    AceConfig:RegisterOptionsTable(AddOnName, {
        name = "Keystone Percentage Helper",
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
                        name = "Test Mode",
                        width = "full",
                        get = function()
                            return self._testMode or false
                        end,
                        set = function(_, value)
                            self._testMode = not not value
                            if self._testMode then
                                if self.StartTestModeTicker then self:StartTestModeTicker() end
                            else
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
                            --[[ mobIndicatorInfo = {
                                name = L["MOB_INDICATOR_INFO"],
                                type = "description",
                                order = 5,
                                fontSize = "medium",
                            }, ]]
                            mobPercentages = self:GetMobPercentagesOptions(),
                            --mobIndicator = self:GetMobIndicatorOptions(),
                        }
                    },
                }
            },
            advanced = self:GetAdvancedOptions()
        }
    })
    AceConfig:RegisterOptionsTable(AddOnName .. "_Changelog", self.changelogOptions)

    AceConfigDialog:AddToBlizOptions(AddOnName, "Keystone Percentage Helper")
    AceConfigDialog:AddToBlizOptions(AddOnName .. "_Changelog", L['Changelog'], "Keystone Percentage Helper")


    -- Register chat command and events
    self:RegisterChatCommand('kph', 'ToggleConfig')

    -- Create display after DB is initialized
    self:CreateDisplay()
    
    -- Initialize mob percentages module if enabled
    if self.db.profile.mobPercentages and self.db.profile.mobPercentages.enabled then
        self:InitializeMobPercentages()
    end

    -- After InitializeMobPercentages check
    --[[ if self.db.profile.mobIndicator and self.db.profile.mobIndicator.enabled then
        self:InitializeMobIndicator()
    end ]]
end

-- Open configuration panel when command is used
function KeystonePercentageHelper:ToggleConfig()
    Settings.OpenToCategory("Keystone Percentage Helper")
end

-- Handler for addon compartment button click
_G.KeystonePercentageHelper_OnAddonCompartmentClick = function()
    KeystonePercentageHelper:ToggleConfig()
end

-- Create or recreate the main display frame
function KeystonePercentageHelper:CreateDisplay()
    if not self.displayFrame then
        self.displayFrame = CreateFrame("Frame", "KeystonePercentageHelperDisplay", UIParent)
        self.displayFrame:SetSize(200, 30)

        -- Create percentage text
        self.displayFrame.text = self.displayFrame:CreateFontString(nil, "OVERLAY")
        self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, "OUTLINE")
        self.displayFrame.text:SetPoint("CENTER")
        self.displayFrame.text:SetText("0.0%") -- Set initial text

        -- Set position from saved variables
        self.displayFrame:ClearAllPoints()
        self.displayFrame:SetPoint(
            self.db.profile.general.position,
            UIParent,
            self.db.profile.general.position,
            self.db.profile.general.xOffset,
            self.db.profile.general.yOffset
        )
    end

    -- Ensure text is visible and settings are applied
    self:ApplyTextLayout()
    self:Refresh()
end

-- Initialize dungeon tracking when entering a dungeon
function KeystonePercentageHelper:InitiateDungeon()
    local currentDungeonId = C_ChallengeMode.GetActiveChallengeMapID()
    -- Return if not in a dungeon or already tracking this dungeon
    if currentDungeonId == nil or currentDungeonId == self.currentDungeonID then return end

    -- Set current dungeon and reset to first section
    self.currentDungeonID = currentDungeonId
    self.currentSection = 1

    -- Sort dungeon data by percentage to ensure proper progression
    if self.DUNGEONS[self.currentDungeonID] then
        table.sort(self.DUNGEONS[self.currentDungeonID], function(left, right)
            return left[2] < right[2]
        end)
    end
end

-- Get the current enemy forces percentage from the scenario UI
function KeystonePercentageHelper:GetCurrentPercentage()
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
function KeystonePercentageHelper:GetCurrentForcesInfo()
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
function KeystonePercentageHelper:GetDungeonData()
    if not self.DUNGEONS[self.currentDungeonID] or not self.DUNGEONS[self.currentDungeonID][self.currentSection] then
        return nil
    end

    local dungeonData = self.DUNGEONS[self.currentDungeonID][self.currentSection]
    return dungeonData[1], dungeonData[2], dungeonData[3], dungeonData[4]
end

-- Send a chat message to inform the group about missing percentage
function KeystonePercentageHelper:InformGroup(percentage)
    if not self.db.profile.general.informGroup then return end

    local channel = self.db.profile.general.informChannel
    local percentageStr = string.format("%.2f%%", percentage)
    -- Don't send message if percentage is 0
    if percentageStr == "0.00%" then return end
    SendChatMessage("[KPH]: " .. L["WE_STILL_NEED"] .. " " .. percentageStr, channel)
end

-- Update the displayed percentage text based on dungeon progress
function KeystonePercentageHelper:UpdatePercentageText()
    if not self.displayFrame then return end

    -- Test Mode: render preview and bypass real dungeon state
    if self._testMode then
        if self.RenderTestText then self:RenderTestText() end
        return
    end

    -- Initialize dungeon tracking if needed
    self:InitiateDungeon()

    -- Check if we're in a supported dungeon
    local currentDungeonID = C_ChallengeMode.GetActiveChallengeMapID()
    if currentDungeonID == nil or not self.DUNGEONS[currentDungeonID] then
        self.displayFrame.text:SetText("")
        return
    end

    -- Get current enemy forces counts and percentage
    local currentCount, totalCount = self:GetCurrentForcesInfo()
    local currentPercentage = (totalCount and totalCount > 0) and ((currentCount / totalCount) * 100) or self:GetCurrentPercentage()
    -- Try to get current pull percent from MDT
    local currentPullPercent = self:GetCurrentPullPercent()
    local currentPullCount = tonumber(self.realPull and self.realPull.sum) or 0

    -- Skip sections that have 0 or negative percentage requirements
    while self.DUNGEONS[self.currentDungeonID][self.currentSection] and self.DUNGEONS[self.currentDungeonID][self.currentSection][2] <= 0 do
        self.currentSection = self.currentSection + 1
    end

    -- Get data for current section
    local bossID, neededPercent, shouldInfom, haveInformed = self:GetDungeonData()
    if not bossID then return end

    -- Check if criteria info is available for this boss
    if C_ScenarioInfo.GetCriteriaInfo(bossID) then
        -- Check if boss is killed
        local isBossKilled = C_ScenarioInfo.GetCriteriaInfo(bossID).completed

        -- Calculate remaining needed (percent and count)
        local remainingPercent = neededPercent - currentPercentage
        -- Ensure remainingPercent never goes below zero
        if remainingPercent < 0 then
            remainingPercent = 0.00
        end
        -- Round very small values to 0 to avoid showing 0.01%
        if remainingPercent < 0.05 and remainingPercent > 0.00 then
            remainingPercent = 0.00
        end
        local remainingCount = 0
        if totalCount and totalCount > 0 then
            local neededCount = math.ceil((neededPercent / 100) * totalCount)
            remainingCount = math.max(0, neededCount - (currentCount or 0))
        end

        local cfg = self.db.profile.general.mainDisplay
        local formatMode = cfg and cfg.formatMode or "percent"
        local fmtData = {
            currentCount = currentCount or 0,
            totalCount = totalCount or 0,
            pullCount = currentPullCount or 0,
            remainingCount = remainingCount or 0,
            sectionRequiredPercent = neededPercent or 0,
            sectionRequiredCount = ((totalCount and totalCount > 0) and math.ceil((neededPercent / 100) * totalCount) or 0),
        }
        local displayPercent = string.format("%.2f%%", remainingPercent)
        local displayCount = tostring(remainingCount)
        local color = self.db.profile.color.inProgress

        if remainingPercent > 0 and isBossKilled then -- Boss has been killed but percentage is missing
            -- Inform group about missing percentage if enabled
            if shouldInfom and not haveInformed and self.db.profile.general.informGroup then
                self:InformGroup(remainingPercent)
                self.DUNGEONS[self.currentDungeonID][self.currentSection][4] = true
            end
            color = self.db.profile.color.missing
            local base = (formatMode == "count") and displayCount or displayPercent
            local allBosses = self:AreAllBossesKilled()
            self.displayFrame.text:SetText(self:FormatMainDisplayText(base, currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
        elseif remainingPercent > 0 and not isBossKilled then -- Boss has not been killed yet and percentage is missing
            local base = (formatMode == "count") and displayCount or displayPercent
            local allBosses = self:AreAllBossesKilled()
            self.displayFrame.text:SetText(self:FormatMainDisplayText(base, currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
        elseif remainingPercent <= 0 and not isBossKilled then -- Boss has not been killed yet but percentage is done
            color = self.db.profile.color.finished
            if(currentPercentage >= 100) then
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            else
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DONE"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            end
        elseif remainingPercent <= 0 and isBossKilled then -- Boss has been killed and percentage is done
            color = self.db.profile.color.finished
            if(currentPercentage >= 100) then
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            else
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["SECTION_DONE"], currentPercentage, currentPullPercent, remainingPercent, fmtData, isBossKilled, allBosses))
            end
            self.currentSection = self.currentSection + 1
            if self.currentSection <= #self.DUNGEONS[self.currentDungeonID] then -- Next section exists
                C_Timer.After(2, function()
                    local nextRequired = self.DUNGEONS[self.currentDungeonID][self.currentSection][2] - currentPercentage
                        -- Ensure nextRequired never goes below zero
                        if nextRequired < 0 then
                            nextRequired = 0.00
                        end
                    if currentPercentage >= 100 then -- Percentage is already done for the dungeon
                        color = self.db.profile.color.finished
                        local allBosses = self:AreAllBossesKilled()
                        self.displayFrame.text:SetText(self:FormatMainDisplayText(L["FINISHED"], currentPercentage, currentPullPercent, nil, fmtData, isBossKilled, allBosses))
                    else -- Dungeon has not been completed
                        if nextRequired == 0 then
                            color = self.db.profile.color.finished
                            local allBosses = self:AreAllBossesKilled()
                            self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DONE"], currentPercentage, currentPullPercent, nil, fmtData, isBossKilled, allBosses))
                        else
                            color = self.db.profile.color.inProgress
                            local nextNeededPercent = self.DUNGEONS[self.currentDungeonID][self.currentSection][2]
                            local nextNeededCount = (totalCount and totalCount > 0) and math.ceil((nextNeededPercent / 100) * totalCount) or 0
                            local nextRemainingCount = (totalCount and totalCount > 0) and math.max(0, nextNeededCount - (currentCount or 0)) or 0
                            local baseNext
                            if (cfg and cfg.formatMode == "count") and (totalCount and totalCount > 0) then
                                baseNext = tostring(nextRemainingCount)
                            else
                                baseNext = string.format("%.2f%%", nextRequired)
                            end
                            local fmtNext = {
                                currentCount = currentCount or 0,
                                totalCount = totalCount or 0,
                                pullCount = currentPullCount or 0,
                                remainingCount = nextRemainingCount or 0,
                                sectionRequiredPercent = nextNeededPercent or 0,
                                sectionRequiredCount = nextNeededCount or 0,
                            }
                            local allBosses = self:AreAllBossesKilled()
                            -- For next section preview, the current section boss context shouldn't mark as killed for the new section; pass false
                            self.displayFrame.text:SetText(self:FormatMainDisplayText(baseNext, currentPercentage, currentPullPercent, nextRequired, fmtNext, false, allBosses))
                        end
                    end
                    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
                    -- Adjust frame size if multi-line is enabled
                    self:AdjustDisplayFrameSize()
                    -- Ensure alignment reflects new text layout immediately
                    self:ApplyTextLayout()
                end)
            else
                local allBosses = self:AreAllBossesKilled()
                self.displayFrame.text:SetText(self:FormatMainDisplayText(L["DUNGEON_DONE"], currentPercentage, currentPullPercent, nil, fmtData, isBossKilled, allBosses)) -- Dungeon has been completed
            end
        end

        -- Apply text color based on status
        self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
        -- Adjust frame size if multi-line is enabled
        self:AdjustDisplayFrameSize()
        -- Ensure alignment reflects latest text
        self:ApplyTextLayout()
    end
end

-- Compute current planned pull percent via MDT (if available)
function KeystonePercentageHelper:GetCurrentPullPercent()
    if not C_ChallengeMode.IsChallengeModeActive() then return 0 end
    local denom = tonumber(self.realPull.denom) or 0
    local sum = tonumber(self.realPull.sum) or 0
    if denom <= 0 or sum <= 0 then return 0 end
    return (sum / denom) * 100
end

-- Determine if all non-weighted (boss) criteria are completed
function KeystonePercentageHelper:AreAllBossesKilled()
    local stepInfo = C_ScenarioInfo and C_ScenarioInfo.GetStepInfo and C_ScenarioInfo.GetStepInfo()
    local numCriteria = stepInfo and stepInfo.numCriteria or 0
    if numCriteria == 0 then return false end
    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            if not info.completed then return false end
        end
    end
    return true
end

-- FormatMainDisplayText: builds the final display string with optional Current/Pull/Required parts and projected values.
-- Params:
--   baseText (string): numeric required (percent or count) or textual state (DONE/SECTION_DONE/FINISHED)
--   currentPercent (number): current enemy forces percent [0..100]
--   currentPullPercent (number): projected pull percent [0..100]
--   remainingNeeded (number|nil): remaining percent to hit current section target (for projected Required)
--   fmtData (table): { currentCount, totalCount, pullCount, remainingCount, sectionRequiredPercent, sectionRequiredCount }
--   isBossKilled (bool): current section boss killed
--   allBossesKilled (bool): all dungeon bosses killed
-- Behavior:
--   - Projected values are shown only in combat (showProj depends on UnitAffectingCombat and the option).
--   - Current (base) is green if >= section required (works out of combat, percent and count).
--   - Current (projected) is green if (Current + Pull) >= section required (combat-only, shown in parentheses).
--   - Pull is green if >= section required (not combat-gated; percent and count).
--   - Required (projected):
--       * Last section: (FINISHED) only if projected total >= 100 and all bosses are killed; else (DONE).
--       * Other sections: (DONE). Otherwise, show numeric projected value.
function KeystonePercentageHelper:FormatMainDisplayText(baseText, currentPercent, currentPullPercent, remainingNeeded, fmtData, isBossKilled, allBossesKilled)
    local cfg = self.db and self.db.profile and self.db.profile.general and self.db.profile.general.mainDisplay or nil
    if not cfg then return baseText end

    -- If dungeon percentage is done (100%) or dungeon is fully done, show only the end text (no extras appended)
    if type(baseText) == "string" and (baseText == L["FINISHED"] or baseText == L["DUNGEON_DONE"]) then
        return baseText
    end

    local extras = {}
    -- Build hex color for prefixes
    local pc = cfg.prefixColor or { r = 0.8, g = 0.8, b = 0.8, a = 1 }
    local hexPrefix = string.format("%02x%02x%02x",
        math.floor((pc.r or 0.8) * 255),
        math.floor((pc.g or 0.8) * 255),
        math.floor((pc.b or 0.8) * 255)
    )
    local function colorizePrefix(text)
        return string.format("|cff%s%s|r", hexPrefix, tostring(text or ""))
    end
    -- Display logic notes:
    -- - Projected values (the parenthesized part) are shown only while in combat (showProj below).
    -- - Base Current can be highlighted even out of combat if it already meets the section requirement.
    -- - All comparisons use greater-than-or-equal (>=); values are already rounded to two decimals.

    if cfg.showCurrentPercent and (currentPercent ~= nil) then
        local label = colorizePrefix(cfg.currentLabel or L["CURRENT_DEFAULT"])
        local inCombat = self:IsCombatContext()
        local showProj = (cfg.showProjected and inCombat) and true or false
        if (cfg.formatMode == "count") and fmtData then
            -- Current (count) base highlighting:
            -- If currentCount >= sectionRequiredCount, color the base value in finished green (works out of combat too).
            local cc = tonumber(fmtData.currentCount) or 0
            local tt = tonumber(fmtData.totalCount) or 0
            local pullC = tonumber(fmtData.pullCount) or 0
            local ccStr = tostring(cc)
            do
                local reqC = tonumber(fmtData.sectionRequiredCount) or 0
                if reqC > 0 and cc >= reqC then
                    local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                    local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                    ccStr = string.format("|cff%s%s|r", hex, ccStr)
                end
            end
            local baseStr = string.format("%s %s/%d", label, ccStr, tt)
            if showProj and (pullC or 0) > 0 then
                -- Current (count) projected highlighting (combat only):
                -- If (currentCount + pullCount) >= sectionRequiredCount, color the parenthesized value in finished green.
                local projC = cc + pullC
                if projC < 0 then projC = 0 end
                if tt > 0 and projC > tt then projC = tt end
                local paren = string.format("%d/%d", projC, tt)
                local reqC = tonumber(fmtData.sectionRequiredCount) or 0
                if inCombat and reqC > 0 and projC >= reqC then
                    local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                    local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                    paren = string.format("|cff%s%s|r", hex, paren)
                end
                baseStr = string.format("%s (%s)", baseStr, paren)
            end
            table.insert(extras, baseStr)
        else
            -- Current (percent) base highlighting:
            -- If currentPercent >= sectionRequiredPercent, color the base value in finished green (works out of combat too).
            local cur = tonumber(currentPercent) or 0
            local pull = tonumber(currentPullPercent) or 0
            local proj = cur + pull
            if proj < 0 then proj = 0 end
            if proj > 100 then proj = 100 end
            local curStr = string.format("%.2f%%", cur)
            if fmtData and tonumber(fmtData.sectionRequiredPercent) then
                local req = tonumber(fmtData.sectionRequiredPercent) or 0
                if req > 0 and cur >= req then
                    local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                    local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                    curStr = string.format("|cff%s%s|r", hex, curStr)
                end
            end
            local baseStr = string.format("%s %s", label, curStr)
            if showProj and ((currentPullPercent or 0) > 0) then
                -- Current (percent) projected highlighting (combat only):
                -- If (currentPercent + pullPercent) >= sectionRequiredPercent, color the parenthesized value in finished green.
                local paren = string.format("%.2f%%", proj)
                if inCombat and fmtData and tonumber(fmtData.sectionRequiredPercent) then
                    local req = tonumber(fmtData.sectionRequiredPercent) or 0
                    if req > 0 and proj >= req then
                        local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                        local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                        paren = string.format("|cff%s%s|r", hex, paren)
                    end
                end
                baseStr = string.format("%s (%s)", baseStr, paren)
            end
            table.insert(extras, baseStr)
        end
    end
    if cfg.showCurrentPullPercent and (currentPullPercent ~= nil) and self:IsCombatContext() then
        -- Pull highlighting:
        -- If Pull >= section required (percent or count), color Pull in finished green. Not gated by combat.
        local label = colorizePrefix(cfg.pullLabel or L["PULL_DEFAULT"])
        if cfg.formatMode == "count" and fmtData then
            local pullCount = tonumber(fmtData.pullCount) or 0
            if pullCount > 0 then
                local value = tostring(pullCount)
                local reqC = tonumber(fmtData.sectionRequiredCount) or 0
                if reqC > 0 and pullCount >= reqC then
                    local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                    local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                    value = string.format("|cff%s%s|r", hex, value)
                end
                table.insert(extras, string.format("%s %s", label, value))
            end
        else
            local pullPct = tonumber(currentPullPercent) or 0
            if pullPct > 0 then
                local value = string.format("%.2f%%", pullPct)
                -- Highlight pull if it meets or exceeds the total required for the current section
                if fmtData and tonumber(fmtData.sectionRequiredPercent) then
                    local req = tonumber(fmtData.sectionRequiredPercent) or 0
                    if req > 0 and pullPct >= req then
                        local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                        local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                        value = string.format("|cff%s%s|r", hex, value)
                    end
                end
                table.insert(extras, string.format("%s %s", label, value))
            end
        end
    end

    -- Optionally show the base required text prefix if it's numeric
    local base = baseText
    local isNumericPercent = type(baseText) == "string" and baseText:find("%%$") and tonumber((baseText:gsub("%%",""))) ~= nil
    local isNumericCount = type(baseText) == "string" and baseText:find("^%d+$") ~= nil
    if isNumericPercent then
        if cfg.showRequiredText == false then 
            base = baseText
        else
            local rlabel = colorizePrefix(cfg.requiredLabel or L["REQUIRED_DEFAULT"])
            base = rlabel .. " " .. baseText
        end
    elseif isNumericCount and (cfg.formatMode == "count") then
        if cfg.showRequiredText == false then
            base = baseText
        else
            local rlabel = colorizePrefix(cfg.requiredLabel or L["REQUIRED_DEFAULT"])
            base = rlabel .. " " .. baseText
        end
    else
        base = baseText -- keep DONE/SECTION DONE/FINISHED as-is without label
    end

    -- Required (projected) behavior (combat only):
    -- - If the base is numeric, append a parenthesized projected value.
    -- - If the projection completes the target:
    --     * Last section: (FINISHED) only if projected total >= 100 and all bosses are killed; otherwise (DONE).
    --     * Other sections: (DONE).
    -- - Else: show the numeric projected value (percent or count).
    -- The suffix is colored using the finished color.
    -- Note: projected values are hidden out of combat via the showProjected + UnitAffectingCombat gate.
    -- Optionally append projected value next to numeric Required base (do not replace base label)
    if cfg.showProjected and self:IsCombatContext() then
        if isNumericPercent and (type(remainingNeeded) == "number") then
            local pull = tonumber(currentPullPercent) or 0
            local projReq = (tonumber(remainingNeeded) or 0) - pull
            if projReq < 0 then projReq = 0 end
            if projReq > 100 then projReq = 100 end
            -- Round to two decimals to avoid printing 0.00% instead of DONE when the true value is an epsilon > 0
            local projReqRounded = math.floor((projReq * 100) + 0.5) / 100
            local projTotal = tonumber(currentPercent or 0) + (tonumber(currentPullPercent) or 0)
            if projTotal < 0 then projTotal = 0 end
            if projTotal > 100 then projTotal = 100 end
            if projReqRounded <= 0 then
                -- Distinction: Section done vs Dungeon percentage done vs Dungeon finished (projected)
                local suffix
                local isLastSection = false
                if self.DUNGEONS and self.currentDungeonID and self.DUNGEONS[self.currentDungeonID] then
                    isLastSection = (self.currentSection == #self.DUNGEONS[self.currentDungeonID])
                end
                if projTotal >= 100 then
                    suffix = L["FINISHED"]
                elseif isLastSection then
                    suffix = L["DONE"]
                else
                    suffix = L["DONE"]
                end
                local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                base = string.format("%s (|cff%s%s|r)", base, hex, suffix)
            else
                base = string.format("%s (%.2f%%)", base, projReqRounded)
            end
        elseif isNumericCount and (cfg.formatMode == "count") and fmtData then
            local cc   = tonumber(fmtData.currentCount) or 0
            local tt   = tonumber(fmtData.totalCount) or 0
            local remC = tonumber(fmtData.remainingCount) or 0
            local pullC = tonumber(fmtData.pullCount) or 0
            local projC = remC - pullC
            if projC < 0 then projC = 0 end
            if projC == 0 then
                local suffix
                local projShare = 0
                if tt > 0 then projShare = ((cc + pullC) / tt) * 100 end
                if projShare > 100 then projShare = 100 end
                local isLastSection = false
                if self.DUNGEONS and self.currentDungeonID and self.DUNGEONS[self.currentDungeonID] then
                    isLastSection = (self.currentSection == #self.DUNGEONS[self.currentDungeonID])
                end
                if projShare >= 100 then
                    suffix = L["FINISHED"]
                elseif isLastSection then
                    suffix = L["DONE"]
                else
                    suffix = L["DONE"]
                end
                local col = self.db.profile.color.finished or { r = 0, g = 1, b = 0 }
                local hex = string.format("%02x%02x%02x", math.floor((col.r or 1)*255), math.floor((col.g or 1)*255), math.floor((col.b or 1)*255))
                base = string.format("%s (|cff%s%s|r)", base, hex, suffix)
            else
                base = string.format("%s (%d)", base, projC)
            end
        end
    end

    -- Optionally insert the section required value right after the base required and before Current percent
    if (isNumericPercent or isNumericCount) and cfg.showSectionRequiredText and fmtData then
        local sLabel = colorizePrefix(cfg.sectionRequiredLabel or L["REQUIRED_DEFAULT"])
        local sValue
        if cfg.formatMode == "count" and tonumber(fmtData.totalCount or 0) > 0 then
            if fmtData.sectionRequiredCount then sValue = tostring(tonumber(fmtData.sectionRequiredCount) or 0) end
        else
            if fmtData.sectionRequiredPercent then sValue = string.format("%.2f%%", tonumber(fmtData.sectionRequiredPercent) or 0) end
        end
        if sValue then
            -- Put at the beginning so it appears before Current percent in the extras list
            table.insert(extras, 1, string.format("%s %s", sLabel, sValue))
        end
    end

    if #extras == 0 then return base end

    if base == nil or base == "" then
        if cfg.multiLine then
            return table.concat(extras, "\n")
        else
            local sep = tostring(cfg.singleLineSeparator or " | ")
            return table.concat(extras, sep)
        end
    end

    if cfg.multiLine then
        return base .. "\n" .. table.concat(extras, "\n")
    else
        local sep = tostring(cfg.singleLineSeparator or " | ")
        return base .. sep .. table.concat(extras, sep)
    end
end

-- Apply text layout to support configurable text alignment (LEFT/CENTER/RIGHT)
function KeystonePercentageHelper:ApplyTextLayout()
    if not (self.displayFrame and self.displayFrame.text and self.db and self.db.profile) then return end
    local cfg = self.db.profile.general.mainDisplay
    if not cfg then return end

    local align = cfg.textAlign or "CENTER"
    local multi = cfg.multiLine and true or false
    local maxWidth = tonumber(cfg.maxWidth) or 0

    self.displayFrame.text:ClearAllPoints()

    if multi then
        -- Multi-line: fixed default width (600px); each metric on its own line
        self.displayFrame:SetWidth(600)
        self.displayFrame.text:SetPoint("TOPLEFT", self.displayFrame, "TOPLEFT", 0, 0)
        self.displayFrame.text:SetPoint("TOPRIGHT", self.displayFrame, "TOPRIGHT", 0, 0)
        self.displayFrame.text:SetWidth(self.displayFrame:GetWidth())
        self.displayFrame.text:SetWordWrap(true)
        if self.displayFrame.text.SetMaxLines then
            self.displayFrame.text:SetMaxLines(0) -- unlimited lines
        end
        self.displayFrame.text:SetJustifyV("TOP")
    else
        -- Single-line: ALWAYS center-align regardless of option
        self.displayFrame.text:SetPoint("CENTER", self.displayFrame, "CENTER", 0, 0)
        if maxWidth > 0 then
            self.displayFrame.text:SetWidth(maxWidth)
            self.displayFrame.text:SetWordWrap(true)
        else
            -- Autosize to text; no wrapping
            self.displayFrame.text:SetWidth(0)
            self.displayFrame.text:SetWordWrap(false)
        end
        self.displayFrame.text:SetJustifyV("MIDDLE")
        self.displayFrame.text:SetJustifyH("CENTER")
        return
    end

    -- Multi-line justification
    self.displayFrame.text:SetJustifyH(align)
    -- Force reflow so alignment applies immediately
    local _cur = self.displayFrame.text:GetText()
    if _cur ~= nil then
        self.displayFrame.text:SetText(_cur)
    end
end

-- Simulated combat context for Test Mode
function KeystonePercentageHelper:IsCombatContext()
    if self._testMode then
        if self._testCombatContext == nil then
            return true -- default to "in combat" when starting test mode
        end
        return self._testCombatContext and true or false
    end
    return UnitAffectingCombat and UnitAffectingCombat("player")
end

-- Start ticker to alternate simulated combat context
function KeystonePercentageHelper:StartTestModeTicker()
    -- Cancel existing ticker if any
    if self._testTicker then
        self._testTicker:Cancel()
        self._testTicker = nil
    end
    -- Begin with out-of-combat to show transitions clearly
    self._testCombatContext = false
    local period = 3 -- seconds; can be made configurable later
    self._testTicker = C_Timer.NewTicker(period, function()
        self._testCombatContext = not self._testCombatContext
        if self.UpdatePercentageText then self:UpdatePercentageText() end
    end)
end

function KeystonePercentageHelper:StopTestModeTicker()
    if self._testTicker then
        self._testTicker:Cancel()
        self._testTicker = nil
    end
    self._testCombatContext = nil
end

-- Render a configuration preview while Test Mode is enabled
function KeystonePercentageHelper:RenderTestText()
    if not (self.displayFrame and self.displayFrame.text and self.db and self.db.profile) then return end
    local cfg = self.db.profile.general and self.db.profile.general.mainDisplay or nil
    local formatMode = (cfg and cfg.formatMode) or "percent"

    -- Example values to reflect a mid-dungeon situation
    local totalCount = 220
    local currentPercent = 62.5
    local neededPercent = 70.0
    local remainingPercent = math.max(0, neededPercent - currentPercent)
    local pullPercent = 8.5

    local currentCount = math.floor((currentPercent / 100) * totalCount + 0.5)
    local pullCount = math.floor((pullPercent / 100) * totalCount + 0.5)
    local sectionRequiredCount = math.ceil((neededPercent / 100) * totalCount)
    local remainingCount = math.max(0, sectionRequiredCount - currentCount)

    local fmtData = {
        currentCount = currentCount,
        totalCount = totalCount,
        pullCount = pullCount,
        remainingCount = remainingCount,
        sectionRequiredPercent = neededPercent,
        sectionRequiredCount = sectionRequiredCount,
    }

    local base
    if formatMode == "count" then
        base = tostring(remainingCount)
    else
        base = string.format("%.2f%%", remainingPercent)
    end

    local text = self:FormatMainDisplayText(base, currentPercent, pullPercent, remainingPercent, fmtData, false, false)
    self.displayFrame.text:SetText(text)
    local color = self.db.profile.color.inProgress
    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
    if self.ApplyTextLayout then self:ApplyTextLayout() end
    if self.AdjustDisplayFrameSize then self:AdjustDisplayFrameSize() end
end

-- Called when the addon is enabled
function KeystonePercentageHelper:OnEnable()
    -- Ensure display exists and is visible
    self:CreateDisplay()

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
    self:UpdatePercentageText()
end

-- Event handler for POI updates (boss positions)
function KeystonePercentageHelper:SCENARIO_POI_UPDATE()
    self:UpdatePercentageText()
end

-- Event handler for criteria updates (enemy forces percentage changes)
function KeystonePercentageHelper:SCENARIO_CRITERIA_UPDATE()
    self:UpdatePercentageText()
end

-- React to nameplate additions/removals to refresh dynamic pull percent
function KeystonePercentageHelper:NAME_PLATE_UNIT_ADDED(event, unit)
    -- Maintain a map of nameplate unit -> GUID so we can cleanly remove on REMOVED
    self._nameplateUnits = self._nameplateUnits or {}
    if unit then
        local guid = UnitGUID(unit)
        if guid then
            self._nameplateUnits[unit] = guid
        end
    end
    -- Engagement tracking remains via COMBAT_LOG to avoid double counting
    self:UpdatePercentageText()
end

function KeystonePercentageHelper:NAME_PLATE_UNIT_REMOVED(event, unit)
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
    self:UpdatePercentageText()
end

-- Update when threat list changes (engagement state)
function KeystonePercentageHelper:UNIT_THREAT_LIST_UPDATE(event, unit)
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
function KeystonePercentageHelper:PLAYER_REGEN_DISABLED()
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
function KeystonePercentageHelper:PLAYER_REGEN_ENABLED()
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
    self:UpdatePercentageText()
end

-- Reset pull state when an encounter ends (e.g., boss end), mirroring WarpDeplete behavior
function KeystonePercentageHelper:ENCOUNTER_END()
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
    self:UpdatePercentageText()
end

-- Throttled updater for combat log bursts
function KeystonePercentageHelper:_QueuePullUpdate()
    if self._pullUpdateQueued then return end
    self._pullUpdateQueued = true
    C_Timer.After(0.1, function()
        self._pullUpdateQueued = nil
        self:UpdatePercentageText()
    end)
end

-- Listen to combat log to track engaged NPCs even when nameplates are not visible
function KeystonePercentageHelper:COMBAT_LOG_EVENT_UNFILTERED()
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
function KeystonePercentageHelper:CHALLENGE_MODE_START()
    self.currentDungeonID = nil

    self:InitiateDungeon()
    self:UpdatePercentageText()
end

function KeystonePercentageHelper:CHALLENGE_MODE_COMPLETED()
    self.currentDungeonID = nil
end

-- Event handler for entering the world or changing zones
function KeystonePercentageHelper:PLAYER_ENTERING_WORLD()
    self:InitiateDungeon()
    self:UpdatePercentageText()
end

-- Refresh the display with current settings
function KeystonePercentageHelper:Refresh()
    if not self.displayFrame then return end

    -- Update frame position
    self.displayFrame:ClearAllPoints()
    self.displayFrame:SetPoint(
        self.db.profile.general.position,
        UIParent,
        self.db.profile.general.position,
        self.db.profile.general.xOffset,
        self.db.profile.general.yOffset
    )

    -- Update anchor frame position
    self.anchorFrame:ClearAllPoints()
    self.anchorFrame:SetPoint("CENTER", self.displayFrame, "CENTER", 0, 0)

    -- Update font size and font
    self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, "OUTLINE")
    -- Update horizontal alignment
    self:ApplyTextLayout()

    -- Update text color
    local color = self.db.profile.color.inProgress
    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, color.a)

    -- Update dungeon data with advanced options if enabled
    self:UpdateDungeonData()

    -- Show/hide based on enabled state
    local leaderEnabled   = self.db.profile.general.rolesEnabled.LEADER
    local isLeader        = UnitIsGroupLeader("player")
    local role            = UnitGroupRolesAssigned("player")   -- "TANK", "HEALER", "DAMAGER", ou "NONE"
    local roleEnabled     = self.db.profile.general.rolesEnabled[role]

    local shouldShow = (leaderEnabled and isLeader) or roleEnabled or role == "NONE"

    if not shouldShow then
        if self._testMode then
            self.displayFrame:Show()
        else
            self.displayFrame:Hide()
            return
        end
    end
    self.displayFrame:Show()
end

-- Update dungeon data with advanced options if enabled
function KeystonePercentageHelper:UpdateDungeonData()
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
