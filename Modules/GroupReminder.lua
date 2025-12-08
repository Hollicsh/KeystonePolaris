local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

-- ---------------------------------------------------------------------------
-- Group Reminder Module
-- ---------------------------------------------------------------------------
-- Minimal Group Reminder with simple options: enable, showPopup, showChat
-- Triggers on 'inviteaccepted' only and filters to Mythic+ activities

-- Track the role used at application time by searchResultID
KeystonePolaris.groupReminderRoleByResult = {}

-- Hook ApplyToGroup to capture the role flags used for each application
if C_LFGList and C_LFGList.ApplyToGroup then
    hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID, tank, heal, dps, comment)
        if tank then
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "Tank"
        elseif heal then
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "Healer"
        elseif dps then
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "Damage"
        else
            KeystonePolaris.groupReminderRoleByResult[searchResultID] = "-"
        end
    end)
end

-- Internal helpers
local function IsMythicPlusActivity(activityID)
    local t = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
    if t and t.isMythicPlusActivity ~= nil then
        return not not t.isMythicPlusActivity
    end
    return false
end

local function GetAppliedRoleText(searchResultID)
    -- Prefer the role actually assigned in the group (after join)
    if type(UnitGroupRolesAssigned) == "function" then
        local assigned = UnitGroupRolesAssigned("player")
        if assigned == "TANK" then return TANK end
        if assigned == "HEALER" then return HEALER end
        if assigned == "DAMAGER" then return DAMAGER end
    end

    -- Prefer role captured at application time
    local role = KeystonePolaris.groupReminderRoleByResult and KeystonePolaris.groupReminderRoleByResult[searchResultID]
    if role then
        if role == "Tank" then return TANK end
        if role == "Healer" then return HEALER end
        if role == "Damage" then return DAMAGER end
        return role
    end
    -- Fallback to current LFG role flags
    local tank, heal, dps = GetLFGRoles()
    if tank then return TANK end
    if heal then return HEALER end
    if dps then return DAMAGER end
    return "-"
end

local function BuildMessages(db, titleText, zoneText, groupName, groupComment, roleText)
    -- Build body (without header) once
    local bodyLines = {}
    if db.showDungeonName then table.insert(bodyLines, (L["KPH_GR_DUNGEON"] or "Dungeon:") .. " " .. (zoneText or "-")) end
    if db.showGroupName then table.insert(bodyLines, (L["KPH_GR_GROUP"] or "Group:") .. " " .. (groupName or "-")) end
    if db.showGroupDescription then table.insert(bodyLines, (L["KPH_GR_DESCRIPTION"] or "Description:") .. " " .. (groupComment or "-")) end
    if db.showAppliedRole then table.insert(bodyLines, (L["KPH_GR_ROLE"] or "Role:") .. " " .. (roleText or "-")) end
    local body = table.concat(bodyLines, "\n")

    -- Popup message: gold header + blank line + body
    local popupMsg
    if body ~= "" then
        popupMsg = "|cffffd700" .. (L["KPH_GR_HEADER"] or "Group Reminder") .. "|r\n\n" .. body
    else
        popupMsg = "|cffffd700" .. (L["KPH_GR_HEADER"] or "Group Reminder") .. "|r"
    end

    return popupMsg, body
end

-- Teleport lookup from expansions data by mapID
function KeystonePolaris:GetTeleportCandidatesForMapID(mapID)
    if not mapID then return nil end
    local candidates
    
    -- Heuristic iteration over known expansion prefixes if available in self
    local knownPrefixes = {"TWW", "DF", "SL", "BFA", "LEGION", "WOD", "MOP", "CATA", "WOTLK", "BC", "CLASSIC"}
    for _, prefix in ipairs(knownPrefixes) do
        local data = self[prefix .. "_DUNGEON_DATA"]
        if type(data) == "table" then
             for _, d in pairs(data) do
                if type(d) == "table" and d.mapID == mapID and d.teleportID ~= nil then
                    candidates = d.teleportID
                    break
                end
            end
        end
        if candidates then break end
    end
    return candidates
end

function KeystonePolaris:GetTeleportSpellForMapID(mapID)
    local cands = self:GetTeleportCandidatesForMapID(mapID)
    if not cands then return nil end
    if type(cands) == "number" then
        return (IsSpellKnown and IsSpellKnown(cands)) and cands or nil
    elseif type(cands) == "table" then
        for _, id in ipairs(cands) do
            if IsSpellKnown and IsSpellKnown(id) then
                return id
            end
        end
    end
    return nil
end

-- Small secure frame opened from chat link to perform the protected cast on user click
local function EnsureTeleportClickFrame(self)
    if self.teleportClickFrame then return self.teleportClickFrame end
    local f = CreateFrame("Frame", "KPL_TeleportClickSecure", UIParent, "BackdropTemplate")
    f:SetSize(260, 80)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 12,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Title:SetPoint("TOP", 0, -12)
    f.Title:SetText(L["KPH_GR_TELEPORT"] or "Teleport to dungeon")

    -- Create a text-like secure button
    f.LinkButton = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    f.LinkButton:SetPoint("CENTER", 0, -5)
    f.LinkButton:SetSize(200, 18)
    local fs = f.LinkButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT")
    fs:SetText("|cff00aaff[" .. (L["KPH_GR_TELEPORT"] or "Teleport to dungeon") .. "]|r")
    f.LinkButtonText = fs

    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetPoint("TOPRIGHT", 0, 0)

    f:Hide()
    self.teleportClickFrame = f
    return f
end

function KeystonePolaris:ShowTeleportClickFrame(spellID)
    local f = EnsureTeleportClickFrame(self)
    local spellName
    if C_Spell and C_Spell.GetSpellName then
        spellName = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        spellName = (GetSpellInfo(spellID))
    end
    if spellID and spellName and IsSpellKnown and IsSpellKnown(spellID) then
        f.LinkButton:SetAttribute("type", "macro")
        f.LinkButton:SetAttribute("macrotext", "/cast " .. spellName)
        f:Show()
    else
        f:Hide()
    end
end

-- Clickable chat link handler: opens secure click frame instead of casting directly
if not KeystonePolaris._KPL_TeleportChatLinkHooked then
    KeystonePolaris._KPL_TeleportChatLinkHooked = true
    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if type(link) == "string" then
            local linkType, rest = strsplit(":", link, 2)
            if linkType == "kphteleport" then
                local spellID = tonumber(rest or "")
                if spellID then
                    if KeystonePolaris and KeystonePolaris.ShowTeleportClickFrame then
                        KeystonePolaris:ShowTeleportClickFrame(spellID)
                    end
                end
            end
        end
    end)
end

-- Styled popup UI with a text hyperlink (secure button) to teleport
local function GuessRoleKey(roleText)
    if type(roleText) ~= "string" then return nil end
    local up = string.upper(roleText)
    if up == "TANK" or roleText == TANK then return "TANK" end
    if up == "HEALER" or roleText == HEALER then return "HEALER" end
    if up == "DAMAGER" or up == "DAMAGE" or roleText == DAMAGER then return "DAMAGER" end
end

local function EnsureGroupReminderStyledFrame(self)
    if self.groupReminderStyledFrame then return self.groupReminderStyledFrame end

    local f = CreateFrame("Frame", "KPL_GroupReminderStyled", UIParent, "BackdropTemplate")
    f:SetSize(400, 200) -- Slightly smaller/standard size
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", -- Standard Blizzard Border
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    table.insert(UISpecialFrames, "KPL_GroupReminderStyled")

    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.Title:SetPoint("TOP", 0, -16)
    f.Title:SetText(L["KPH_GR_HEADER"] or "Group Reminder")

    -- Single centered content block
    f.Content = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Content:SetPoint("TOP", f.Title, "BOTTOM", 0, -10)
    f.Content:SetPoint("LEFT", 20, 0)
    f.Content:SetPoint("RIGHT", -20, 0)
    f.Content:SetJustifyH("CENTER")
    f.Content:SetJustifyV("TOP")
    f.Content:SetSpacing(4) -- Add some breathing room between lines

    -- Text label "Teleport to dungeon" above the icon
    f.TeleportLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.TeleportLabel:SetPoint("BOTTOM", 0, 65) -- Position above the icon
    f.TeleportLabel:SetText(L["KPH_GR_TELEPORT"] or "Teleport to dungeon")
    -- Add fake underline using texture (since fonts don't support underline directly easily)
    f.TeleportLabel.Underline = f:CreateTexture(nil, "ARTWORK")
    f.TeleportLabel.Underline:SetColorTexture(1, 0.82, 0, 1) -- Gold color
    f.TeleportLabel.Underline:SetHeight(1)
    f.TeleportLabel.Underline:SetPoint("TOPLEFT", f.TeleportLabel, "BOTTOMLEFT", 0, -1)
    f.TeleportLabel.Underline:SetPoint("TOPRIGHT", f.TeleportLabel, "BOTTOMRIGHT", 0, -1)

    -- Icon-based secure button for teleport, centered at bottom
    f.TeleportLink = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    f.TeleportLink:SetPoint("BOTTOM", 0, 20)
    f.TeleportLink:SetSize(40, 40)
    f.TeleportLink:RegisterForClicks("AnyUp", "AnyDown")
    
    f.TeleportLink.Icon = f.TeleportLink:CreateTexture(nil, "ARTWORK")
    f.TeleportLink.Icon:SetAllPoints()
    f.TeleportLink.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Zoom slightly to remove ugly borders
    
    f.TeleportLink:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    
    -- Tooltip handling
    f.TeleportLink:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    f.TeleportLink:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetPoint("TOPRIGHT", -5, -5)

    f:Hide()
    self.groupReminderStyledFrame = f
    return f
end

function KeystonePolaris:ShowStyledGroupReminderPopup(title, zone, groupName, groupComment, roleText, teleportSpellID)
    local db = self.db.profile.groupReminder
    local f = EnsureGroupReminderStyledFrame(self)
    f.Title:SetText(L["KPH_GR_HEADER"] or "Group Reminder")

    local lines = {}
    if db.showDungeonName then table.insert(lines, "|cffffffff" .. (L["KPH_GR_DUNGEON"] or "Dungeon:") .. "|r " .. (zone or "-")) end
    if db.showGroupName then table.insert(lines, "|cffffffff" .. (L["KPH_GR_GROUP"] or "Group:") .. "|r " .. (groupName or "-")) end
    if db.showGroupDescription then table.insert(lines, "|cffffffff" .. (L["KPH_GR_DESCRIPTION"] or "Description:") .. "|r " .. (groupComment or "-")) end
    if db.showAppliedRole then table.insert(lines, "|cffffffff" .. (L["KPH_GR_ROLE"] or "Role:") .. "|r " .. (roleText or "-")) end

    -- Join all lines with newlines
    local fullText = table.concat(lines, "\n")
    f.Content:SetText(fullText)

    -- Dynamic height adjustment based on text content
    local textHeight = f.Content:GetStringHeight()
    local baseHeight = 140 -- Increased base height for label + icon
    f:SetHeight(baseHeight + textHeight)

    -- Configure teleport link (secure button) only if spell is known (or in test mode)
    local isKnown = teleportSpellID and IsSpellKnown and IsSpellKnown(teleportSpellID)
    if self._testingGroupReminder and teleportSpellID then isKnown = true end

    if teleportSpellID and isKnown then
        local spellName, _, icon
        if C_Spell and C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(teleportSpellID)
            icon = C_Spell.GetSpellTexture(teleportSpellID)
        elseif GetSpellInfo then
            spellName, _, icon = GetSpellInfo(teleportSpellID)
        end
        
        if spellName then
            f.TeleportLink.spellID = teleportSpellID -- Store for tooltip
            f.TeleportLink:SetAttribute("type", "macro")
            f.TeleportLink:SetAttribute("macrotext", "/cast " .. spellName)
            if icon then
                f.TeleportLink.Icon:SetTexture(icon)
            end
            f.TeleportLink:Show()
            f.TeleportLabel:Show()
        else
            f.TeleportLink:Hide()
            f.TeleportLabel:Hide()
        end
    else
        f.TeleportLink:Hide()
        f.TeleportLabel:Hide()
    end

    f:Show()
end
function KeystonePolaris:ShowGroupReminder(searchResultID, title, zone, comment, activityMapID)
    local db = self.db and self.db.profile and self.db.profile.groupReminder
    if not db or not db.enabled then return end

    local roleText = GetAppliedRoleText(searchResultID)
    local popupMsg, body = BuildMessages(db, title, zone, title, comment, roleText)

    -- Resolve teleport spell for this dungeon
    local teleportSpellID = self:GetTeleportSpellForMapID(activityMapID)

    -- Popup
    if db.showPopup then
        self:ShowStyledGroupReminderPopup(title, zone, title, comment, roleText, teleportSpellID)
    end

    -- Chat
    if db.showChat then
        local chatHeader = "|cffdb6233" .. (L["KPH_GR_HEADER"] or "Group Reminder") .. "|r :"
        if body ~= "" then
            print(chatHeader .. "\n" .. body)
        else
            print(chatHeader)
        end
        if teleportSpellID and (not IsSpellKnown or IsSpellKnown(teleportSpellID)) then
            local linkText = L["KPH_GR_TELEPORT"] or "Teleport to dungeon"
            local link = string.format("|Hkphteleport:%d|h[%s]|h", teleportSpellID, linkText)
            print(link)
        end
    end
end

function KeystonePolaris:InitializeGroupReminder()
    if self.groupReminderFrame then
        -- Ensure registration reflects current settings
        self:UpdateGroupReminderRegistration()
        return
    end

    self.groupReminderFrame = CreateFrame("Frame")
    self.groupReminderFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

    self.groupReminderFrame:SetScript("OnEvent", function(_, event, ...)
        if event ~= "LFG_LIST_APPLICATION_STATUS_UPDATED" then return end

        local searchResultID, newStatus = ...
        if not searchResultID or not newStatus then return end

        -- Show reminder when the invite is accepted (joined)
        if newStatus ~= "inviteaccepted" then return end

        local srd = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(searchResultID)
        if not srd then return end

        -- Some APIs return multiple activityIDs; prefer the first when present
        local activityID = (srd.activityIDs and srd.activityIDs[1]) or srd.activityID
        if not activityID then return end

        if not IsMythicPlusActivity(activityID) then return end

        local activity = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
        if not activity then return end

        -- Hide Blizzard's LFG invite dialog if it's still visible (post-accept)
        if self.db.profile.groupReminder.suppressQuickJoinToast and type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Hide then
            if LFGListInviteDialog:IsShown() then
                LFGListInviteDialog:Hide()
            end
        end

        local title = srd.name or ""
        local zone = activity.fullName or ""
        local comment = srd.comment or ""
        local mapID = activity.mapID
        -- Delay slightly to allow group roster to update so UnitGroupRolesAssigned returns the accepted role
        C_Timer.After(0.2, function()
            self:ShowGroupReminder(searchResultID, title, zone, comment, mapID)
        end)

        -- Cleanup stored role for this application
        self.groupReminderRoleByResult[searchResultID] = nil
    end)
end

function KeystonePolaris:DisableGroupReminder()
    if self.groupReminderFrame then
        self.groupReminderFrame:UnregisterAllEvents()
    end
end

function KeystonePolaris:UpdateGroupReminderRegistration()
    local db = self.db and self.db.profile and self.db.profile.groupReminder
    if not db then return end
    if db.enabled then
        if not self.groupReminderFrame then
            self:InitializeGroupReminder()
            return
        end
        self.groupReminderFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    else
        self:DisableGroupReminder()
    end
end

-- Ensure Blizzard UI related to group invites/toasts is visible again
function KeystonePolaris:RestoreBlizzardJoinUI()
    if type(LFGListInviteDialog) == "table" and LFGListInviteDialog.Show then
        LFGListInviteDialog:Show()
    end
end

function KeystonePolaris:TestGroupReminder()
    self._testingGroupReminder = true
    local fakeID = 999999
    -- Fake a role application
    self.groupReminderRoleByResult = self.groupReminderRoleByResult or {}
    self.groupReminderRoleByResult[fakeID] = "Damage"

    -- Fake data
    local title = "Test Group (+10)"
    local zone = "The Stonevault" 
    local comment = "Checking logs, big pumpers only."
    
    -- Use a mapID that likely has a teleport spell (2652 = The Stonevault)
    -- This spell ID (445269) will be used. Even if not known, the button will show in test mode.
    local mapID = 2652 
    local teleportSpellID = 445269

    -- Ensure options are loaded so we don't crash
    if not self.db.profile.groupReminder then
        self.db.profile.groupReminder = self.defaults.profile.groupReminder
    end
    
    -- Force show even if disabled, for testing purposes? 
    -- Better to respect "enabled" flag or print a warning.
    if not self.db.profile.groupReminder.enabled then
        print("|cffff0000[Keystone Polaris]|r Group Reminder is currently disabled in options.")
        self._testingGroupReminder = false
        return
    end

    self:ShowGroupReminder(fakeID, title, zone, comment, mapID)
    self._testingGroupReminder = false
end

function KeystonePolaris:GetGroupReminderOptions()
    local self = KeystonePolaris
    return {
        name = L["KPH_GR_HEADER"] or "Group Reminder",
        type = "group",
        order = 7, -- Place it after Colors
        args = {
            header = { order = 0, type = "header", name = L["KPH_GR_HEADER"] or "Group Reminder" },
            enable = {
                name = L["ENABLE"] or "Enable",
                type = "toggle",
                width = "full",
                order = 1,
                get = function() return self.db.profile.groupReminder.enabled end,
                set = function(_, value)
                    self.db.profile.groupReminder.enabled = value
                    if value then self:InitializeGroupReminder() else self:DisableGroupReminder() end
                end,
            },
            behavior = {
                name = L["OPTIONS"] or "Options",
                type = "group",
                inline = true,
                order = 2,
                args = {
                    suppressQuickJoinToast = {
                        name = L["KPH_GR_SUPPRESS_TOAST"] or "Suppress Blizzard quick-join toast",
                        type = "toggle",
                        order = 0,
                        width = "full",
                        get = function() return self.db.profile.groupReminder.suppressQuickJoinToast end,
                        set = function(_, v)
                            self.db.profile.groupReminder.suppressQuickJoinToast = v
                            -- If turning suppression OFF while not in group, restore Blizzard UI now for future invites
                            if (not v) and (not IsInGroup()) and self.RestoreBlizzardJoinUI then
                                self:RestoreBlizzardJoinUI()
                            end
                        end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                    showPopup = {
                        name = L["KPH_GR_SHOW_POPUP"] or "Show popup",
                        type = "toggle",
                        order = 1,
                        get = function() return self.db.profile.groupReminder.showPopup end,
                        set = function(_, v) self.db.profile.groupReminder.showPopup = v end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                    showChat = {
                        name = L["KPH_GR_SHOW_CHAT"] or "Show chat message",
                        type = "toggle",
                        order = 2,
                        get = function() return self.db.profile.groupReminder.showChat end,
                        set = function(_, v) self.db.profile.groupReminder.showChat = v end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                    showDungeonName = {
                        name = L["KPH_GR_SHOW_DUNGEON"] or "Show dungeon name",
                        type = "toggle",
                        order = 3,
                        get = function() return self.db.profile.groupReminder.showDungeonName end,
                        set = function(_, v) self.db.profile.groupReminder.showDungeonName = v end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                    showGroupName = {
                        name = L["KPH_GR_SHOW_GROUP"] or "Show group name",
                        type = "toggle",
                        order = 4,
                        get = function() return self.db.profile.groupReminder.showGroupName end,
                        set = function(_, v) self.db.profile.groupReminder.showGroupName = v end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                    showGroupDescription = {
                        name = L["KPH_GR_SHOW_DESC"] or "Show group description",
                        type = "toggle",
                        order = 5,
                        get = function() return self.db.profile.groupReminder.showGroupDescription end,
                        set = function(_, v) self.db.profile.groupReminder.showGroupDescription = v end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                    showAppliedRole = {
                        name = L["KPH_GR_SHOW_ROLE"] or "Show applied role",
                        type = "toggle",
                        order = 6,
                        get = function() return self.db.profile.groupReminder.showAppliedRole end,
                        set = function(_, v) self.db.profile.groupReminder.showAppliedRole = v end,
                        disabled = function() return not self.db.profile.groupReminder.enabled end,
                    },
                },
            },
        },
    }
end