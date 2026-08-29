local addonName, addon = ...
local L = addon.L

addon.defaults = {
    scale = 1,
    backgroundAlpha = 0.82,
    iconSize = 34,
    spacing = 4,
    showShortName = true,
    locked = false,
    font = "default",
    fontSize = 12,
    fontOutline = "OUTLINE",
    textColor = { r = 1, g = 0.82, b = 0 },
    position = nil,
}

addon.fonts = {
    default = GameFontNormal:GetFont(),
    chat = ChatFontNormal:GetFont(),
    damage = NumberFontNormal:GetFont(),
}

local eventFrame = CreateFrame("Frame")
local buttons = {}
local pendingRefresh
local pendingVisibility
local searchPanel

local function copyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                copyDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            copyDefaults(target[key], value)
        end
    end
end

local function isDungeonSearchVisible()
    return searchPanel
        and searchPanel:IsShown()
        and searchPanel.categoryID == GROUP_FINDER_CATEGORY_ID_DUNGEONS
end

local function setShownOutOfCombat(shown)
    if InCombatLockdown() then
        pendingVisibility = shown
        return
    end
    pendingVisibility = nil
    addon.bar:SetShown(shown)
end

function addon:UpdateVisibility()
    setShownOutOfCombat(isDungeonSearchVisible())
end

local function savePosition()
    local point, _, relativePoint, x, y = addon.bar:GetPoint(1)
    MythicPortalBarDB.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

function addon:ResetPosition(silent)
    MythicPortalBarDB.position = nil
    self.bar:ClearAllPoints()
    if searchPanel then
        self.bar:SetPoint("BOTTOM", searchPanel, "TOP", 0, 8)
    else
        self.bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    if not silent then
        print("|cff33ff99MythicPortalBar:|r " .. L.RESET_POSITION_DONE)
    end
end

local function restorePosition()
    local position = MythicPortalBarDB.position
    addon.bar:ClearAllPoints()
    if position then
        addon.bar:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        addon:ResetPosition(true)
    end
end

local function beginDrag()
    if MythicPortalBarDB.locked or not IsShiftKeyDown() or InCombatLockdown() then
        return
    end
    addon.bar.isMoving = true
    addon.bar:StartMoving()
end

local function endDrag()
    if not addon.bar.isMoving then
        return
    end
    addon.bar:StopMovingOrSizing()
    addon.bar.isMoving = false
    savePosition()
end

local function showTooltip(button)
    local dungeon = button.dungeon
    if not dungeon then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(dungeon.name)
    GameTooltip:AddDoubleLine(L.LEVEL, tostring(dungeon.level), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(L.SCORE, tostring(dungeon.score), 1, 1, 1, 1, 0.82, 0)
    if dungeon.portalKnown then
        GameTooltip:AddLine(L.PORTAL_KNOWN, 0.2, 1, 0.2)
        GameTooltip:AddLine(L.CLICK_TO_TELEPORT, 0.7, 0.7, 0.7)
    elseif dungeon.portalMapped then
        GameTooltip:AddLine(L.PORTAL_UNKNOWN, 0.55, 0.55, 0.55)
    else
        GameTooltip:AddLine(L.PORTAL_UNMAPPED, 0.55, 0.55, 0.55)
    end
    GameTooltip:AddLine(MythicPortalBarDB.locked and L.LOCKED or L.SHIFT_TO_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function createDungeonButton(index)
    local button = CreateFrame("Button", addonName .. "Dungeon" .. index, addon.bar, "SecureActionButtonTemplate")
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    -- Keep the unmodified left click on the secure action path.
    button:SetAttribute("type1", "spell")
    -- Shift-click is reserved for moving the bar, never for casting.
    button:SetAttribute("shift-type1", ATTRIBUTE_NOOP)
    button:SetAttribute("alt-shift-type1", ATTRIBUTE_NOOP)
    button:SetAttribute("ctrl-shift-type1", ATTRIBUTE_NOOP)
    button:SetAttribute("alt-ctrl-shift-type1", ATTRIBUTE_NOOP)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.035, 0.035, 0.035, 0.92)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(0.8, 0.6, 0.15, 0.16)
    button.highlight:SetBlendMode("ADD")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.name:SetJustifyH("CENTER")

    button.level = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.level:SetJustifyH("CENTER")
    button.score = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.score:SetJustifyH("CENTER")

    button:SetScript("OnEnter", function(self)
        self.highlight:Show()
        showTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip_Hide()
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and IsShiftKeyDown() then
            beginDrag()
        end
    end)
    button:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            endDrag()
        end
    end)
    buttons[index] = button
    return button
end

local function configureSecureAction(button, dungeon)
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    if dungeon.portalKnown then
        button:SetAttribute("type1", "spell")
        local spellName
        if C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(dungeon.spellID)
        end
        if not spellName and GetSpellInfo then
            spellName = GetSpellInfo(dungeon.spellID)
        end
        button:SetAttribute("spell1", spellName or dungeon.spellID)
    else
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
    end
end

function addon:ApplyAppearance()
    local db = MythicPortalBarDB
    local font = self.fonts[db.font] or self.fonts.default
    local color = db.textColor
    self.bar:SetScale(db.scale)
    self.bar:SetBackdropColor(0.035, 0.035, 0.035, db.backgroundAlpha)

    for _, button in ipairs(buttons) do
        button.icon:SetSize(db.iconSize, db.iconSize)
        button.name:SetShown(db.showShortName)
        button.level:SetFont(font, db.fontSize, db.fontOutline)
        button.score:SetFont(font, db.fontSize, db.fontOutline)
        button.level:SetTextColor(color.r, color.g, color.b)
        button.score:SetTextColor(color.r, color.g, color.b)
    end
    self:Layout()
end

function addon:Layout()
    local db = MythicPortalBarDB
    local itemWidth = math.max(db.iconSize + 8, 62)
    local itemHeight = db.iconSize + (db.showShortName and 18 or 6)
    local visible = 0

    for _, button in ipairs(buttons) do
        if button:IsShown() then
            visible = visible + 1
            button:ClearAllPoints()
            button:SetPoint("LEFT", self.bar, "LEFT", 8 + (visible - 1) * (itemWidth + db.spacing), 0)
            button:SetSize(itemWidth, itemHeight)
            button.icon:ClearAllPoints()
            button.icon:SetPoint("LEFT", button, "LEFT", 4, db.showShortName and 6 or 0)
            button.name:ClearAllPoints()
            button.name:SetPoint("TOP", button.icon, "BOTTOM", 0, -1)
            button.name:SetWidth(itemWidth)
            button.level:ClearAllPoints()
            button.level:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMRIGHT", 3, 3)
            button.score:ClearAllPoints()
            button.score:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", 3, -3)
        end
    end

    if visible == 0 then
        self.bar:SetSize(260, 38)
    else
        self.bar:SetSize(16 + visible * itemWidth + (visible - 1) * db.spacing, itemHeight + 12)
    end
end

local function applyDungeon(button, dungeon)
    button.dungeon = dungeon
    button.icon:SetTexture(dungeon.texture)
    button.name:SetText(dungeon.shortName)
    button.level:SetText(dungeon.level)
    button.score:SetText(dungeon.score)
    button.icon:SetDesaturated(not dungeon.portalKnown)
    button.name:SetTextColor(dungeon.portalKnown and 1 or 0.5, dungeon.portalKnown and 0.82 or 0.5, dungeon.portalKnown and 0 or 0.5)
    button.level:SetAlpha(dungeon.portalKnown and 1 or 0.45)
    button.score:SetAlpha(dungeon.portalKnown and 1 or 0.45)
    button.bg:SetColorTexture(0.035, 0.035, 0.035, dungeon.portalKnown and 0.92 or 0.52)
    button.highlight:SetShown(false)
    configureSecureAction(button, dungeon)
    button:Show()
end

function addon:Refresh()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    pendingRefresh = nil
    local dungeons = self:GetSeasonDungeons()
    self.unavailable:SetShown(not dungeons)

    for index, dungeon in ipairs(dungeons or {}) do
        applyDungeon(buttons[index] or createDungeonButton(index), dungeon)
    end
    for index = dungeons and (#dungeons + 1) or 1, #buttons do
        buttons[index]:Hide()
    end
    self:ApplyAppearance()
end

local function createBar()
    local bar = CreateFrame("Frame", "MythicPortalBarFrame", UIParent, "BackdropTemplate")
    addon.bar = bar
    bar:SetFrameStrata("HIGH")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    -- Only dungeon buttons need mouse input. Keeping the container transparent
    -- prevents its empty area from covering the Group Finder drag region.
    bar:EnableMouse(false)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bar:SetBackdropBorderColor(0.25, 0.2, 0.12, 0.85)
    bar.unavailable = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addon.unavailable = bar.unavailable
    bar.unavailable:SetPoint("CENTER")
    bar.unavailable:SetText(L.DATA_UNAVAILABLE)
    bar:Hide()
end

local function hookGroupFinder()
    searchPanel = LFGListFrame.SearchPanel
    searchPanel:HookScript("OnShow", function()
        addon:Refresh()
        addon:UpdateVisibility()
    end)
    searchPanel:HookScript("OnHide", function()
        setShownOutOfCombat(false)
    end)
    hooksecurefunc("LFGListSearchPanel_SetCategory", function(panel)
        if panel == searchPanel then
            addon:UpdateVisibility()
        end
    end)
    restorePosition()
    addon:UpdateVisibility()
end

function addon:Initialize()
    MythicPortalBarDB = MythicPortalBarDB or {}
    copyDefaults(MythicPortalBarDB, self.defaults)
    createBar()
    restorePosition()
    self:ApplyAppearance()
    C_MythicPlus.RequestMapInfo()
    self:Refresh()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder", hookGroupFinder)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon:Initialize()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingRefresh then
            addon:Refresh()
        end
        if pendingVisibility ~= nil then
            setShownOutOfCombat(pendingVisibility)
        end
    elseif addon.bar then
        addon:Refresh()
    end
end)
