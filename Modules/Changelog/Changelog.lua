local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local gsub = string.gsub
local format = string.format
local strsplit = strsplit

-- ---------------------------------------------------------------------------
-- Changelog Logic
-- ---------------------------------------------------------------------------

function KeystonePolaris.RGBToHex(r, g, b, header, ending)
    r = r <= 1 and r >= 0 and r or 1
    g = g <= 1 and g >= 0 and g or 1
    b = b <= 1 and b >= 0 and b or 1

    local hex = format('%s%02x%02x%02x%s', header or '|cff', r * 255, g * 255,
                       b * 255, ending or '')
    return hex
end

local function versionToSortKey(versionString)
    local major, minor, patch = versionString:match("^(%d+)%.(%d+)%.?(%d*)")
    if not major then return 0 end
    return (tonumber(major) or 0) * 1000000
         + (tonumber(minor) or 0) * 10000
         + (tonumber(patch) or 0) * 100
end

function KeystonePolaris:GenerateChangelog()
    self.changelogOptions = {
        type = "group",
        childGroups = "select",
        name = L["Changelog"],
        args = {}
    }

    if not self.Changelog or type(self.Changelog) ~= "table" then return end

    local orangeHex = self.RGBToHex(0.859, 0.388, 0.203)
    local lightblueHex = self.RGBToHex(0.4, 0.6, 1.0)

    local function colorize(text, hex)
        if type(text) ~= "string" then text = tostring(text) end
        return hex .. text .. "|r"
    end

    local function renderChangelogLine(line, hex)
        -- Parentheses drop gsub's replacement count so table.insert gets one value.
        return (gsub(line, "%[[^%[]+%]", function(bracket)
            return colorize(bracket, hex)
        end))
    end

    local function resolveList(list)
        if not list then return nil end
        local localized = list[GetLocale()]
        if localized and next(localized) then
            return localized
        end
        return list["enUS"]
    end

    local function resolveHeader(headerData)
        if not headerData then return nil end
        local headerLocalized = headerData[GetLocale()]
        if headerLocalized ~= nil and (headerLocalized.title ~= nil or headerLocalized.text ~= nil) then
            return headerLocalized
        end
        return headerData["enUS"]
    end

    local function formatDate(releaseDate)
        local dateTable = {strsplit("/", releaseDate)}
        local dateString = releaseDate
        if #dateTable == 3 then
            dateString = L["%month%-%day%-%year%"]
            dateString = gsub(dateString, "%%year%%", dateTable[1])
            dateString = gsub(dateString, "%%month%%", dateTable[2])
            dateString = gsub(dateString, "%%day%%", dateTable[3])
        end
        return dateString
    end

    local function stripColors(s)
        if type(s) ~= "string" then s = tostring(s) end
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|r", "")
        return s
    end

    local function buildPlainText(data)
        local chunks = {}
        local function appendSection(titleKey, list)
            local items = resolveList(list)
            if items and #items > 0 then
                table.insert(chunks, (L and L[titleKey]) or titleKey)
                for _, line in ipairs(items) do
                    table.insert(chunks, "- " .. stripColors(line))
                end
                table.insert(chunks, "")
            end
        end

        local function appendHeader(headerData)
            local items = resolveHeader(headerData)
            if items and items.title and items.text then
                table.insert(chunks, stripColors(items.title))
                table.insert(chunks, "")
                table.insert(chunks, stripColors(items.text))
                table.insert(chunks, "")
            end
        end

        if data and type(data) == "table" then
            if data.version_string and data.release_date then
                table.insert(chunks, (L and L["Version"] or "Version") .. ": " .. data.version_string ..
                    " (" .. data.release_date .. ")")
                table.insert(chunks, "")
            end
            appendHeader(data.header)
            appendSection("Important", data.important)
            appendSection("New", data.new)
            appendSection("Bugfixes", data.bugfix)
            appendSection("Improvement", data.improvment)
        end

        return table.concat(chunks, "\n")
    end

    local function dashedSection(items, hex)
        if not items or #items == 0 then return nil end
        local chunks = {}
        for _, line in ipairs(items) do
            chunks[#chunks + 1] = "- " .. renderChangelogLine(line, hex)
        end
        return table.concat(chunks, "\n") .. "\n"
    end

    local function buildPage(data)
        local header = resolveHeader(data.header)
        local page = {
            plain = buildPlainText(data),
            sortKey = versionToSortKey(data.version_string),
            versionName = L["Version"] .. " " .. colorize(data.version_string, orangeHex) ..
                " - |cffbbbbbb" .. formatDate(data.release_date) .. "|r",
            important = dashedSection(resolveList(data.important), orangeHex),
            new = dashedSection(resolveList(data.new), orangeHex),
            bugfix = dashedSection(resolveList(data.bugfix), orangeHex),
            improvment = dashedSection(resolveList(data.improvment), orangeHex),
        }
        if header then
            if header.title ~= nil and header.title ~= "" then
                page.headerTitle = colorize(header.title, lightblueHex)
            end
            if header.text ~= nil and header.text ~= "" then
                page.headerText = renderChangelogLine(header.text, lightblueHex) .. "\n"
            end
        end
        return page
    end

    local function addBulletSection(args, headerKey, bodyKey, headerOrder, bodyOrder, titleKey, body)
        if not body then return end
        args[headerKey] = {
            order = headerOrder,
            type = "header",
            name = colorize(L[titleKey] or titleKey, orangeHex),
        }
        args[bodyKey] = {
            order = bodyOrder,
            type = "description",
            name = body,
            fontSize = "medium",
        }
    end

    local function buildGroupArgs(page)
        local args = {
            translate = {
                order = 1,
                type = "execute",
                name = L["TRANSLATE"],
                desc = L["TRANSLATE_DESC"],
                func = function()
                    if self.ShowCopyPopup then
                        self:ShowCopyPopup(page.plain)
                    end
                end,
            },
            versionLine = {
                order = 2,
                type = "description",
                name = page.versionName,
                fontSize = "large",
            },
        }

        if page.headerTitle then
            args.headerHeader = {
                order = 3,
                type = "header",
                name = page.headerTitle,
            }
        end
        if page.headerText then
            args.headerText = {
                order = 4,
                type = "description",
                name = page.headerText,
                fontSize = "medium",
            }
        end

        addBulletSection(args, "importantHeader", "important", 5, 6, "Important", page.important)
        addBulletSection(args, "newHeader", "new", 7, 8, "New", page.new)
        addBulletSection(args, "bugfixHeader", "bugfix", 9, 10, "Bugfixes", page.bugfix)
        addBulletSection(args, "improvmentHeader", "improvment", 11, 12, "Improvement", page.improvment)

        return args
    end

    for version, data in pairs(self.Changelog) do
        if type(data) == "table" and data.version_string and data.release_date then
            local page = buildPage(data)
            self.changelogOptions.args[tostring(version)] = {
                type = "group",
                name = data.version_string,
                order = 10000000 - page.sortKey,
                args = buildGroupArgs(page),
            }
        end
    end
end

-- ---------------------------------------------------------------------------
-- Update announcement (chat link)
-- ---------------------------------------------------------------------------

local function AddChatMessage(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    else
        print(message)
    end
end

function KeystonePolaris:OpenChangelogCategory()
    local optionsAddonName = (self.GetGradientAddonNameFromSecondLetter and self:GetGradientAddonNameFromSecondLetter()) or "Keystone Polaris"
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.changelogCategoryId or self.optionsCategoryId or optionsAddonName)
    end
end

function KeystonePolaris:ScheduleOpenChangelogAfterCombat()
    if self._changelogOpenAfterCombat then return end
    self._changelogOpenAfterCombat = true

    local frame = self._changelogCombatFrame
    if not frame then
        frame = CreateFrame("Frame")
        self._changelogCombatFrame = frame
    end

    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(eventFrame, event)
        if event ~= "PLAYER_REGEN_ENABLED" then return end
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:SetScript("OnEvent", nil)
        self._changelogOpenAfterCombat = nil
        if self.OpenChangelogCategory then
            self:OpenChangelogCategory()
        end
    end)
end

function KeystonePolaris:HandleChangelogChatLink()
    if InCombatLockdown() then
        local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
        AddChatMessage(prefix .. ": " .. (L["CHANGELOG_AFTER_COMBAT"] or "Changelog will open after combat ends"))
        self:ScheduleOpenChangelogAfterCombat()
        return
    end

    self:OpenChangelogCategory()
end

function KeystonePolaris:MaybeAnnounceAddonUpdate()
    if not (self.db and self.db.profile and self.db.profile.general) then return end

    local currentVersion = C_AddOns.GetAddOnMetadata("KeystonePolaris", "Version") or ""
    -- Hotfix tags (e.g. 3.11-fix1): seed silently, no [Open Changelog] announce.
    if currentVersion:lower():find("fix", 1, true) then
        self.db.profile.general.lastChangelogAnnounce = currentVersion
        return
    end

    local lastAnnounce = self.db.profile.general.lastChangelogAnnounce or ""

    if lastAnnounce == "" then
        -- Brand-new install: seed silently. Existing profiles: fall through and announce.
        if not self._hadPriorVersionCheck then
            self.db.profile.general.lastChangelogAnnounce = currentVersion
            return
        end
    elseif lastAnnounce == currentVersion then
        return
    end

    local prefix = (self.GetChatPrefix and self:GetChatPrefix()) or "Keystone Polaris"
    local versionText = "|cffffd100" .. currentVersion .. "|r"
    local linkText = "|cffdb6233[" .. (L["OPEN_CHANGELOG"] or "Open Changelog") .. "]|r"
    local link = "|Hkplchangelog:1|h" .. linkText .. "|h"
    local body = (L["UPDATE_ANNOUNCE"] or "got updated to %s,"):format(versionText)
    AddChatMessage(prefix .. " " .. body .. " " .. link)
    self.db.profile.general.lastChangelogAnnounce = currentVersion
end

if not KeystonePolaris._KPL_ChangelogChatLinkHooked then
    KeystonePolaris._KPL_ChangelogChatLinkHooked = true
    hooksecurefunc("SetItemRef", function(link)
        if type(link) ~= "string" then return end
        local linkType = strsplit(":", link, 2)
        if linkType ~= "kplchangelog" then return end

        if KeystonePolaris and KeystonePolaris.HandleChangelogChatLink then
            KeystonePolaris:HandleChangelogChatLink()
        end
    end)
end
