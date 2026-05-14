-- upvalues
local _G = _G
local strgfind = string.gmatch
local strlower = string.lower
local tonumber = tonumber
local type = type

local PREFIX = "|cff33ff99[Flyout]|r "

-- ------------------------------------------------------------------
-- Interface Options Panel
-- ------------------------------------------------------------------
local panel = CreateFrame("Frame", "FlyoutOptionsPanel")
panel.name = "Flyout"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Flyout")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Configure flyout button appearance.")

-- Helper: create a slider
local function makeSlider(name, label, minV, maxV, step, anchor, x, y, tooltip)
    local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -16)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetWidth(180)
    _G[slider:GetName() .. "Text"]:SetText(label)
    _G[slider:GetName() .. "Low"]:SetText(tostring(minV))
    _G[slider:GetName() .. "High"]:SetText(tostring(maxV))
    slider.tooltipText = tooltip
    return slider
end

-- Button size slider
local sliderSize =
    makeSlider("FlyoutSizeSlider", "Button Size", 10, 50, 1, subtitle, 0, -24, "Size of each flyout button in pixels.")
sliderSize:SetScript(
    "OnValueChanged",
    function(self)
        local val = math.floor(self:GetValue() + 0.5)
        Flyout_Config["BUTTON_SIZE"] = val
        _G[self:GetName() .. "Text"]:SetText("Button Size: " .. val)
        Flyout.UpdateBars()
    end
)

-- Arrow scale slider
local sliderArrow =
    makeSlider(
    "FlyoutArrowSlider",
    "Arrow Scale",
    0.1,
    2.0,
    0.05,
    sliderSize,
    0,
    -32,
    "Relative size of the flyout arrow indicator."
)
sliderArrow:SetScript(
    "OnValueChanged",
    function(self)
        local val = math.floor(self:GetValue() * 100 + 0.5) / 100
        Flyout_Config["ARROW_SCALE"] = val
        _G[self:GetName() .. "Text"]:SetText("Arrow Scale: " .. val)
        Flyout.UpdateBars()
    end
)

-- Color picker button
local colorBtn = CreateFrame("Button", "FlyoutColorButton", panel)
colorBtn:SetSize(24, 24)
colorBtn:SetPoint("TOPLEFT", sliderArrow, "BOTTOMLEFT", 0, -24)
colorBtn:SetBackdrop(
    {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    }
)

local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
colorLabel:SetPoint("LEFT", colorBtn, "RIGHT", 8, 0)
colorLabel:SetText("Border Color")

local function UpdateColorSwatch()
    local r = Flyout_Config["BORDER_COLOR"][1] or 0
    local g = Flyout_Config["BORDER_COLOR"][2] or 0
    local b = Flyout_Config["BORDER_COLOR"][3] or 0
    colorBtn:SetBackdropColor(r, g, b)
end

colorBtn:SetScript(
    "OnClick",
    function()
        local r = Flyout_Config["BORDER_COLOR"][1] or 0
        local g = Flyout_Config["BORDER_COLOR"][2] or 0
        local b = Flyout_Config["BORDER_COLOR"][3] or 0
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.previousValues = {r, g, b}
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            Flyout_Config["BORDER_COLOR"][1] = nr
            Flyout_Config["BORDER_COLOR"][2] = ng
            Flyout_Config["BORDER_COLOR"][3] = nb
            UpdateColorSwatch()
            Flyout.UpdateBars()
        end
        ColorPickerFrame.cancelFunc = function()
            local pr, pg, pb = unpack(ColorPickerFrame.previousValues)
            Flyout_Config["BORDER_COLOR"][1] = pr
            Flyout_Config["BORDER_COLOR"][2] = pg
            Flyout_Config["BORDER_COLOR"][3] = pb
            UpdateColorSwatch()
            Flyout.UpdateBars()
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
)

-- Sync UI when panel is shown
panel:SetScript(
    "OnShow",
    function()
        sliderSize:SetValue(Flyout_Config["BUTTON_SIZE"] or Flyout.DEFAULT_CONFIG["BUTTON_SIZE"])
        sliderArrow:SetValue(Flyout_Config["ARROW_SCALE"] or Flyout.DEFAULT_CONFIG["ARROW_SCALE"])
        UpdateColorSwatch()
    end
)

InterfaceOptions_AddCategory(panel)

-- ------------------------------------------------------------------
-- Slash Commands
-- ------------------------------------------------------------------
SLASH_FLYOUT1 = "/flyout"
SLASH_FLYOUT2 = "/fo"
SlashCmdList["FLYOUT"] = function(msg)
    msg = msg or ""
    local args = {}
    local i = 1
    for arg in strgfind(strlower(msg), "%S+") do
        args[i] = arg
        i = i + 1
    end

    if not args[1] then
        -- No args: open the native Interface Options panel.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
        return
    end

    if args[1] == "size" then
        if args[2] then
            if type(tonumber(args[2])) == "number" then
                Flyout_Config["BUTTON_SIZE"] = tonumber(args[2])
            elseif args[2] == "reset" then
                Flyout_Config["BUTTON_SIZE"] = Flyout.DEFAULT_CONFIG["BUTTON_SIZE"]
            end
            DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Button size set to " .. Flyout_Config["BUTTON_SIZE"] .. ".")
        end
    elseif args[1] == "color" then
        if args[2] == "reset" then
            Flyout_Config["BORDER_COLOR"][1] = Flyout.DEFAULT_CONFIG["BORDER_COLOR"][1]
            Flyout_Config["BORDER_COLOR"][2] = Flyout.DEFAULT_CONFIG["BORDER_COLOR"][2]
            Flyout_Config["BORDER_COLOR"][3] = Flyout.DEFAULT_CONFIG["BORDER_COLOR"][3]
            DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Border color reset.")
        else
            local r = Flyout_Config["BORDER_COLOR"][1]
            local g = Flyout_Config["BORDER_COLOR"][2]
            local b = Flyout_Config["BORDER_COLOR"][3]
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.previousValues = {r, g, b}
            ColorPickerFrame.func = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                Flyout_Config["BORDER_COLOR"][1] = nr
                Flyout_Config["BORDER_COLOR"][2] = ng
                Flyout_Config["BORDER_COLOR"][3] = nb
                Flyout.UpdateBars()
            end
            ColorPickerFrame.cancelFunc = function()
                local pr, pg, pb = unpack(ColorPickerFrame.previousValues)
                Flyout_Config["BORDER_COLOR"][1] = pr
                Flyout_Config["BORDER_COLOR"][2] = pg
                Flyout_Config["BORDER_COLOR"][3] = pb
                Flyout.UpdateBars()
            end
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
            DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Use the color picker to adjust the border color.")
        end
    elseif args[1] == "arrow" then
        if args[2] then
            if type(tonumber(args[2])) == "number" then
                Flyout_Config["ARROW_SCALE"] = tonumber(args[2])
            elseif args[2] == "reset" then
                Flyout_Config["ARROW_SCALE"] = Flyout.DEFAULT_CONFIG["ARROW_SCALE"]
            end
            DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Arrow scale set to " .. Flyout_Config["ARROW_SCALE"] .. ".")
            Flyout.UpdateBars()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Usage: /flyout [size|color|arrow] [value|reset]")
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Or /flyout with no args to open the options panel.")
    end
end
