local _, addon = ...
local L = addon.L

local function copyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end

local function refresh()
    addon:ApplyAppearance()
end

local function addSetting(category, variable, key, varType, name, default, kind, options, tooltip)
    local setting = Settings.RegisterAddOnSetting(
        category,
        "MYTHIC_PORTAL_BAR_" .. variable,
        key,
        MythicPortalBarDB,
        varType,
        name,
        default
    )
    setting:SetValueChangedCallback(refresh)
    if kind == "checkbox" then
        Settings.CreateCheckbox(category, setting, tooltip)
    elseif kind == "slider" then
        Settings.CreateSlider(category, setting, options, tooltip)
    elseif kind == "dropdown" then
        Settings.CreateDropdown(category, setting, options, tooltip)
    end
    return setting
end

local function dropdownOptions(values)
    return function()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(values) do
            container:Add(option.value, option.label)
        end
        return container:GetData()
    end
end

local function sliderOptions(minValue, maxValue, step)
    return Settings.CreateSliderOptions(minValue, maxValue, step)
end

local function registerSettings()
    local category = Settings.RegisterVerticalLayoutCategory("MythicPortalBar")
    addon.settingsCategory = category

    addSetting(category, "SCALE", "scale", Settings.VarType.Number, L.SCALE, 1, "slider", sliderOptions(0.5, 2, 0.05), L.SCALE_TOOLTIP)
    addSetting(category, "BACKGROUND_ALPHA", "backgroundAlpha", Settings.VarType.Number, L.BACKGROUND_ALPHA, 0.82, "slider", sliderOptions(0, 1, 0.05), L.BACKGROUND_ALPHA_TOOLTIP)
    addSetting(category, "ICON_SIZE", "iconSize", Settings.VarType.Number, L.ICON_SIZE, 34, "slider", sliderOptions(24, 52, 1), L.ICON_SIZE_TOOLTIP)
    addSetting(category, "SPACING", "spacing", Settings.VarType.Number, L.SPACING, 4, "slider", sliderOptions(0, 16, 1), L.SPACING_TOOLTIP)
    addSetting(category, "SHOW_SHORT_NAME", "showShortName", Settings.VarType.Boolean, L.SHOW_SHORT_NAME, true, "checkbox", nil, L.SHOW_SHORT_NAME_TOOLTIP)
    addSetting(category, "LOCKED", "locked", Settings.VarType.Boolean, L.LOCK_POSITION, false, "checkbox", nil, L.LOCK_POSITION_TOOLTIP)
    addSetting(category, "FONT", "font", Settings.VarType.String, L.FONT, "default", "dropdown", dropdownOptions({
        { value = "default", label = L.FONT_DEFAULT },
        { value = "chat", label = L.FONT_CHAT },
        { value = "damage", label = L.FONT_DAMAGE },
    }), L.FONT_TOOLTIP)
    addSetting(category, "FONT_SIZE", "fontSize", Settings.VarType.Number, L.FONT_SIZE, 12, "slider", sliderOptions(9, 20, 1), L.FONT_SIZE_TOOLTIP)
    addSetting(category, "FONT_OUTLINE", "fontOutline", Settings.VarType.String, L.FONT_OUTLINE, "OUTLINE", "dropdown", dropdownOptions({
        { value = "", label = L.OUTLINE_NONE },
        { value = "OUTLINE", label = L.OUTLINE_NORMAL },
        { value = "THICKOUTLINE", label = L.OUTLINE_THICK },
    }), L.FONT_OUTLINE_TOOLTIP)

    local function colorComponent(variable, component)
        local setting = Settings.RegisterProxySetting(category, "MYTHIC_PORTAL_BAR_TEXT_COLOR_" .. variable, Settings.VarType.Number, L.TEXT_COLOR .. " - " .. variable, addon.defaults.textColor[component], function()
            return MythicPortalBarDB.textColor[component]
        end, function(value)
            MythicPortalBarDB.textColor[component] = value
            refresh()
        end)
        Settings.CreateSlider(category, setting, sliderOptions(0, 1, 0.05), L.TEXT_COLOR_TOOLTIP)
    end
    colorComponent("RED", "r")
    colorComponent("GREEN", "g")
    colorComponent("BLUE", "b")

    local resetPanel = CreateFrame("Frame")
    local resetPosition = CreateFrame("Button", nil, resetPanel, "UIPanelButtonTemplate")
    resetPosition:SetSize(180, 24)
    resetPosition:SetPoint("TOPLEFT", 16, -20)
    resetPosition:SetText(L.RESET_POSITION)
    resetPosition:SetScript("OnClick", function() addon:ResetPosition() end)
    local resetAll = CreateFrame("Button", nil, resetPanel, "UIPanelButtonTemplate")
    resetAll:SetSize(180, 24)
    resetAll:SetPoint("TOPLEFT", resetPosition, "BOTTOMLEFT", 0, -12)
    resetAll:SetText(L.RESET_ALL)
    resetAll:SetScript("OnClick", function() addon:ResetAll() end)
    Settings.RegisterCanvasLayoutSubcategory(category, resetPanel, L.RESET_ALL)

    Settings.RegisterAddOnCategory(category)
end

function addon:ResetAll()
    for key in pairs(MythicPortalBarDB) do
        MythicPortalBarDB[key] = nil
    end
    local defaults = copyTable(self.defaults)
    for key, value in pairs(defaults) do
        MythicPortalBarDB[key] = value
    end
    self:ResetPosition(true)
    self:ApplyAppearance()
    print("|cff33ff99MythicPortalBar:|r " .. L.RESET_ALL_DONE)
end

local function openOptions()
    if addon.settingsCategory then
        Settings.OpenToCategory(addon.settingsCategory:GetID())
    end
end

SLASH_MYTHICPORTALBAR1 = "/mpb"
SLASH_MYTHICPORTALBAR2 = "/mythicportalbar"
SlashCmdList.MYTHICPORTALBAR = function(message)
    local command, argument = message:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "options" or command == "config" then
        openOptions()
    elseif command == "reset" then
        addon:ResetPosition()
    elseif command == "resetall" then
        addon:ResetAll()
    elseif command == "scale" then
        local scale = tonumber(argument)
        if not scale or scale < 0.5 or scale > 2 then
            print("|cff33ff99MythicPortalBar:|r " .. L.SCALE_USAGE)
            return
        end
        MythicPortalBarDB.scale = scale
        addon:ApplyAppearance()
        print("|cff33ff99MythicPortalBar:|r " .. L.SCALE_SET:format(scale))
    else
        print("|cff33ff99MythicPortalBar:|r " .. L.COMMANDS)
    end
end

EventUtil.ContinueOnAddOnLoaded("MythicPortalBar", registerSettings)
