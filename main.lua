local _G = _G

local revision = 1.0
local bars = {
   'Action',
   'BonusAction',
   'MultiBarBottomLeft',
   'MultiBarBottomRight',
   'MultiBarRight',
   'MultiBarLeft'
}

local flyouts = {}
local buttonCache = {}

FLYOUT_DEFAULT_CONFIG = {
   ['REVISION'] = revision,
   ['BUTTON_SIZE'] = 28,
   ['BORDER_COLOR'] = { 0, 0, 0 },
   ['ARROW_SCALE'] = 5/9,
}

local ARROW_RATIO = 0.6  -- Height to width.

-- upvalues
local ActionButton_CalculateAction = ActionButton_CalculateAction
local GetActionText = GetActionText
local InCombatLockdown = InCombatLockdown
local GetContainerItemLink = GetContainerItemLink
local GetContainerNumSlots = GetContainerNumSlots
local GetNumSpellTabs = GetNumSpellTabs
local GetSpellName = GetSpellName
local GetSpellTabInfo = GetSpellTabInfo
local GetTime = GetTime
local GetScreenHeight = GetScreenHeight
local GetScreenWidth = GetScreenWidth
local HasAction = HasAction
local GetMacroIndexByName = GetMacroIndexByName
local GetMacroInfo = GetMacroInfo
local GetMouseFocus = GetMouseFocus
local GetSpellCooldown = GetSpellCooldown
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetSpellTexture = GetSpellTexture
local GetContainerItemInfo = GetContainerItemInfo
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

local insert = table.insert
local rawset = rawset
local remove = table.remove
-- sizeof alias removed; use # operator instead

local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strsub = string.sub

-- Action type constants
local ACTION_TYPE_SPELL = 0
local ACTION_TYPE_MACRO = 1
local ACTION_TYPE_ITEM  = 2

-- helper functions
local strtrim = strtrim

local wipe = table.wipe

local tsplit = {}
local function Flyout_SplitActions(str, delimiter, fillTable)
   fillTable = fillTable or tsplit
   wipe(fillTable)
   strgsub(str, '([^' .. delimiter .. ']+)', function(value)
      insert(fillTable, strtrim(value))
   end)

   return fillTable
end

local function FindBagItem(name)
   local lowerName = strlower(name)
   for bag = 0, 4 do
      for slot = 1, GetContainerNumSlots(bag) do
         local item = GetContainerItemLink(bag, slot)
         if item and strfind(strlower(item), lowerName, 1, true) then
            local _, _, itemLink = strfind(item, '(item:%d+)')
            return itemLink, bag, slot
         end
      end
   end
end

function Flyout_GetBagPosition(name)
   local _, bag, slot = FindBagItem(name)
   return bag, slot
end

local function GetBagItemByName(name)
   return FindBagItem(name)
end

-- credit: https://github.com/DanielAdolfsson/CleverMacro
local spellSlotCache = {}

local function InvalidateSpellSlotCache()
   wipe(spellSlotCache)
end

local function GetSpellSlotByName(name)
   local cached = spellSlotCache[name]
   if cached then return cached end

   local count, offset, spell, subSpell

   local lowerName = strlower(name)
   name = lowerName
   local b, _, rank = strfind(name, '%(%s*rank%s+(%d+)%s*%)')
   if b then name = (b > 1) and strtrim(strsub(name, 1, b - 1)) or '' end

   for tabIndex = GetNumSpellTabs(), 1, -1 do
      _, _, offset, count = GetSpellTabInfo(tabIndex)
      for index = offset + count, offset + 1, -1 do
         spell, subSpell = GetSpellName(index, 'spell')
         spell = strlower(spell)
         if name == spell and (not rank or subSpell == 'Rank ' .. rank) then
            spellSlotCache[name] = index
            return index
         end
      end
   end
end

-- Returns <action>, <actionType>, <actionTexture>
local function GetFlyoutActionInfo(action)
   local spell = GetSpellSlotByName(action)
   if spell then
      return spell, ACTION_TYPE_SPELL, GetSpellTexture(spell, 'spell')
   end

   local item, bag, slot = GetBagItemByName(action)
   if item then
      return item, ACTION_TYPE_ITEM, GetContainerItemInfo(bag, slot), bag, slot
   end

   local macro = GetMacroIndexByName(action)
   if macro and macro > 0 then
      local _, texture = GetMacroInfo(macro)
      return macro, ACTION_TYPE_MACRO, texture
   end
end

local function GetFlyoutDirection(button)
   if button.flyoutDirection then
      return button.flyoutDirection
   end

   local horizontal = false
   local bar = button:GetParent()
   if bar:GetWidth() > bar:GetHeight() then
      horizontal = true
   end

   local direction = horizontal and 'TOP' or 'LEFT'

   local centerX, centerY = button:GetCenter()
   if centerX and centerY then
      if horizontal then
         local halfScreen = GetScreenHeight() / 2
         direction = centerY < halfScreen and 'TOP' or 'BOTTOM'
      else
         local halfScreen = GetScreenWidth() / 2
         direction = centerX > halfScreen and 'LEFT' or 'RIGHT'
      end
   end
   return direction
end

local function FlyoutBarButton_OnLeave(self)
   if not self.flyoutAction then return end
   self.updateTooltip = nil
   GameTooltip:Hide()

   local focus = GetMouseFocus()
   if focus and not strfind(focus:GetName() or '', 'Flyout') then
      Flyout_Hide()
   end
end

local function FlyoutBarButton_OnEnter(self)
   if not self.flyoutAction then return end
   Flyout_Show(self)

   if self.preFlyoutOnEnter then
      self.preFlyoutOnEnter(self)
   end
end

local function UpdateBarButton(slot)
    local button = Flyout_GetActionButton(slot)
    if button then
      local arrow = _G[button:GetName() .. 'FlyoutArrow']
      if arrow then
         arrow:Hide()
      end

      if not HasAction(slot) or not GetActionText(slot) then
         -- Reset button to pre-Flyout condition.
         button.flyoutActionType = nil
         button.flyoutAction = nil
         button.flyoutSlot = nil
         if button.preFlyoutOnEnter then
            button:SetScript('OnEnter', button.preFlyoutOnEnter)
            button:SetScript('OnLeave', button.preFlyoutOnLeave)
            button.preFlyoutOnEnter = nil
            button.preFlyoutOnLeave = nil
         end

         flyouts[slot] = nil
         return
      end

      button.sticky = false
      button.flyoutDirection = nil

      local icon = false
      local macro = GetActionText(slot)
      local macroIndex = GetMacroIndexByName(macro)
      if not macroIndex or macroIndex == 0 then return end
      local _, _, body = GetMacroInfo(macroIndex)
      if not body then return end
      if not strfind(body, '/flyout', 1, true) then return end
      -- Find /flyout anywhere in the macro body (not just at the start).
      local flyoutLine, flyoutStart, flyoutEnd
      for line in string.gmatch(body .. '\n', '([^\n]*)\n') do
         local s, e = strfind(line, '/flyout')
         if s then
            flyoutLine = line
            flyoutStart = s
            flyoutEnd = e
            break
         end
      end
      if flyoutLine then
         if not button.preFlyoutOnEnter then
            button.preFlyoutOnEnter = button:GetScript('OnEnter')
            button.preFlyoutOnLeave = button:GetScript('OnLeave')
         end

         local flyoutBody = flyoutLine

         -- Identify sticky menus.
         if strfind(flyoutBody, '%[sticky%]') then
            flyoutBody = strgsub(flyoutBody, '%[sticky%]', '')
            button.sticky = true
         end

         if strfind(flyoutBody, '%[icon%]') then
            icon = true

            flyoutBody = strgsub(flyoutBody, '%[icon%]', '')
         end

         -- Identify direction override.
         local _, _, dirValue = strfind(flyoutBody, '%[direction:(%a+)%]')
         if dirValue then
            flyoutBody = strgsub(flyoutBody, '%[direction:%a+%]', '')
            local dirMap = { up = 'TOP', down = 'BOTTOM', left = 'LEFT', right = 'RIGHT' }
            button.flyoutDirection = dirMap[strlower(dirValue)]
         end

         flyoutBody = strsub(flyoutBody, flyoutEnd + 1)

         if not button.flyoutActions then
            button.flyoutActions = {}
         end

         Flyout_SplitActions(flyoutBody, ';', button.flyoutActions)

         if #button.flyoutActions > 0 then
            local cost
            local action, type, texture, bag, bagSlot = GetFlyoutActionInfo(button.flyoutActions[1])

            if type == ACTION_TYPE_SPELL then
               local _, _, _, powerCost = GetSpellInfo(action)
               cost = powerCost
            end

            local f = flyouts[slot]
            if not f then
               f = {}
               flyouts[slot] = f
            end
            f.action = action
            f.type = type
            f.texture = icon and texture or false
            f.cost = cost and tonumber(cost) or 0
            f.bag = bag
            f.slot = bagSlot

            button.flyoutAction = action
            button.flyoutActionType = type
            button.flyoutSlot = slot
         end

         Flyout_UpdateFlyoutArrow(button)

         button:SetScript('OnLeave', FlyoutBarButton_OnLeave)
         button:SetScript('OnEnter', FlyoutBarButton_OnEnter)
      end
    end
 end

local function Flyout_HandleCoreEvent(self, event, arg1, arg2, arg3, arg4, arg5)
   if event == 'VARIABLES_LOADED' then
      if not Flyout_Config or (Flyout_Config['REVISION'] == nil or Flyout_Config['REVISION'] ~= revision) then
         Flyout_Config = {}
      end
      -- Initialize defaults if not present.
      for key, value in pairs(FLYOUT_DEFAULT_CONFIG) do
         if not Flyout_Config[key] then
            Flyout_Config[key] = value
         end
      end
      return
   elseif event == 'PLAYER_ENTERING_WORLD' then
      if not FlyoutScanner then
         local scanner = CreateFrame('GameTooltip', 'FlyoutScanner', UIParent, 'GameTooltipTemplate')
         scanner:SetOwner(WorldFrame, 'ANCHOR_NONE')
      end

      local MAX_FLYOUT_BUTTONS = 12
      for i = 1, MAX_FLYOUT_BUTTONS do
         local b = _G['FlyoutButton' .. i]
         if not b then
            b = CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'FlyoutButtonTemplate')
            b:SetID(i)
            b:SetScript('PostClick', Flyout_OnClick)
            b:Hide()
         end
      end

      -- Delayed rescan for action-bar replacements (ElvUI, etc.) that create
      -- buttons after PLAYER_ENTERING_WORLD.
      local delayFrame = CreateFrame('Frame')
      local delayElapsed = 0
      delayFrame:SetScript('OnUpdate', function(self, elapsed)
         delayElapsed = delayElapsed + elapsed
         if delayElapsed >= 3 then
            self:Hide()
            self:SetScript('OnUpdate', nil)
            Flyout_BuildButtonCache()
            Flyout_UpdateBars()
         end
      end)
   elseif event == 'ACTIONBAR_SLOT_CHANGED' then
      Flyout_Hide(true)  -- Keep sticky menus open.
      UpdateBarButton(arg1)
      return
   elseif event == 'BAG_UPDATE' then
      Flyout_Hide()
      Flyout_UpdateBars()
      return
   elseif event == 'SPELL_UPDATE_COOLDOWN' then
      Flyout_UpdateVisibleCooldowns()
      return
   elseif event == 'UPDATE_MACROS' then
      Flyout_Hide()
      Flyout_UpdateBars()
      return
   elseif event == 'SPELLS_CHANGED' or event == 'LEARNED_SPELL_IN_TAB' then
      InvalidateSpellSlotCache()
      Flyout_Hide()
      Flyout_UpdateBars()
      return
   elseif event == 'ACTIONBAR_PAGE_CHANGED' then
      Flyout_BuildButtonCache()
      Flyout_Hide()
      Flyout_UpdateBars()
      return
   end
end

local handler = CreateFrame('Frame')
handler:RegisterEvent('VARIABLES_LOADED')
handler:RegisterEvent('PLAYER_ENTERING_WORLD')
handler:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
handler:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
handler:RegisterEvent('BAG_UPDATE')
handler:RegisterEvent('SPELL_UPDATE_COOLDOWN')
handler:RegisterEvent('UPDATE_MACROS')
handler:RegisterEvent('SPELLS_CHANGED')
handler:RegisterEvent('LEARNED_SPELL_IN_TAB')
handler:SetScript('OnEvent', Flyout_HandleCoreEvent)

-- globals
local function SwapMacroDefault(body, oldAction, newAction)
   local lines = {}
   for rawLine in string.gmatch(body .. '\n', '([^\n]*)\n') do
      local line = rawLine
      if strfind(line, '/flyout') then
         local as, ae = string.find(line, oldAction, 1, true)
         local bs, be = string.find(line, newAction, 1, true)
         if as and bs then
            line = string.sub(line, 1, as - 1) .. newAction .. string.sub(line, ae + 1, bs - 1) .. oldAction .. string.sub(line, be + 1)
         end
      elseif strfind(line, '/cast%s+') then
         -- Update /cast line to match the new default action.
         line = '/cast ' .. newAction
      end
      insert(lines, line)
    end
    return table.concat(lines, '\n')
end

function Flyout_OnClick(button, mouseButton)
   if InCombatLockdown() then return end
   if not button or not button.flyoutActionType or not button.flyoutAction or button.flyoutAction == 0 then
      return
   end

   -- Left clicks are handled by the SecureActionButtonTemplate secure handler.
   -- We only process right-clicks here (set-as-default).
   if mouseButton == 'RightButton' and button.flyoutParent then
      local parent = button.flyoutParent
      local oldAction = parent.flyoutActions[1]
      local newAction = parent.flyoutActions[button:GetID()]
      if oldAction ~= newAction then
         local slot = parent.flyoutSlot
            or tonumber(parent.action)
            or tonumber(parent._state_action)
            or (ActionButton_CalculateAction and ActionButton_CalculateAction(parent))
         if not slot or slot == 0 then return end
         local macro = GetActionText(slot)
         if not macro then return end
         local macroIndex = GetMacroIndexByName(macro)
         if not macroIndex or macroIndex == 0 then return end
         local _, icon, body, isLocal = GetMacroInfo(macroIndex)

         local newBody = SwapMacroDefault(body, oldAction, newAction)
         if newBody ~= body then
            EditMacro(macroIndex, macro, icon, newBody, isLocal)
            Flyout_Show(parent)
         end
      else
         button:SetChecked(0)
      end
   end
end

local function IsCurrentCast(spellIndex, bookType)
   if not spellIndex then return false end
   local spellName = GetSpellName(spellIndex, bookType)
   if not spellName then return false end
   local currentSpell = UnitCastingInfo('player')
   if currentSpell == spellName then return true end
   local channelSpell = UnitChannelInfo('player')
   if channelSpell == spellName then return true end
   return false
end

function Flyout_Hide(keepOpenIfSticky)
   if InCombatLockdown() then return end
   local i = 1
   local button = _G['FlyoutButton' .. i]
   while button do
      i = i + 1

      if not keepOpenIfSticky or (keepOpenIfSticky and not button.sticky) then
         button:Hide()
         button:GetNormalTexture():SetTexture(nil)
         button:GetPushedTexture():SetTexture(nil)
      end
      -- Un-highlight if no longer needed.
      if button.flyoutActionType ~= ACTION_TYPE_SPELL or not IsCurrentCast(button.flyoutAction, 'spell') then
         button:SetChecked(false)
      end

      button = _G['FlyoutButton' .. i]
   end

   -- Restore arrow to original strata (it was moved to FULLSCREEN in Flyout_Show())
   if _G['FlyoutButton1'] and not _G['FlyoutButton1']:IsVisible() and _G['FlyoutButton1'].flyoutParent then
      local arrow = _G[_G['FlyoutButton1'].flyoutParent:GetName() .. 'FlyoutArrow']
      if arrow then
         arrow:SetFrameStrata(arrow.flyoutOriginalStrata)
      end
   end

   -- Remove OnUpdate scripts from flyout buttons.
   for i = 1, 12 do
      local b = _G['FlyoutButton' .. i]
      if b then
         b:SetScript('OnUpdate', nil)
      end
   end
end

-- Reusable variables for FlyoutBarButton_UpdateCooldown().
local cooldownStart, cooldownDuration, cooldownEnable

local function FlyoutBarButton_UpdateCooldown(button, reset)
   if not button then return end

   if button.flyoutActionType == ACTION_TYPE_SPELL then
      cooldownStart, cooldownDuration, cooldownEnable = GetSpellCooldown(button.flyoutAction, BOOKTYPE_SPELL)
      if cooldownStart > 0 and cooldownDuration > 0 then
         -- Start/Duration check is needed to get the shine animation.
         CooldownFrame_SetTimer(button.cooldown, cooldownStart, cooldownDuration, cooldownEnable)
      elseif reset then
         -- When switching flyouts, need to hide cooldown if it shouldn't be visible.
         button.cooldown:Hide()
      end
   else
      button.cooldown:Hide()
   end
end

-- Update cooldowns only on currently-visible flyout buttons.
-- Called from SPELL_UPDATE_COOLDOWN instead of a full bar rescan.
function Flyout_UpdateVisibleCooldowns()
   for i = 1, 12 do
      local b = _G['FlyoutButton' .. i]
      if b and b:IsVisible() then
         FlyoutBarButton_UpdateCooldown(b)
      end
   end
end

function FlyoutBarButton_OnUpdate(self, elapsed)
    self.updateElapsed = (self.updateElapsed or 0) + elapsed
    if self.updateElapsed >= 0.1 then
       self.updateElapsed = 0
       -- Update tooltip.
        if GetMouseFocus() == self and (not self.lastUpdate or GetTime() - self.lastUpdate > 1) then
           self:GetScript('OnEnter')(self, true)
           self.lastUpdate = GetTime()
       end
      FlyoutBarButton_UpdateCooldown(self)
   end
end

function Flyout_Show(button)
    if InCombatLockdown() then return end
    local direction = GetFlyoutDirection(button)
    local size = Flyout_Config['BUTTON_SIZE']
    local offset = size

    -- Put arrow above the flyout buttons.
    local arrow = _G[button:GetName() .. 'FlyoutArrow']
    if arrow then
       if Flyout_LastArrow and Flyout_LastArrow ~= arrow then
          Flyout_LastArrow:SetFrameStrata(Flyout_LastArrow.flyoutOriginalStrata)
       end
       Flyout_LastArrow = arrow
       arrow:SetFrameStrata('FULLSCREEN')
    end

   for i, n in ipairs(button.flyoutActions) do
      if InCombatLockdown() then break end
      local b = _G['FlyoutButton' .. i]
      if not b then break end

      b.flyoutParent = button
      b.sticky = button.sticky
      local texture = nil

      b.flyoutAction, b.flyoutActionType, texture = GetFlyoutActionInfo(n)

      if texture then
         b:ClearAllPoints()
         b:SetWidth(size)
         b:SetHeight(size)
         b.cooldown:SetScale(size / b.cooldown:GetWidth())  -- Scale cooldown so it will stay centered on the button.
         b:SetBackdropColor(Flyout_Config['BORDER_COLOR'][1], Flyout_Config['BORDER_COLOR'][2], Flyout_Config['BORDER_COLOR'][3])
         b:Show()

         b:GetNormalTexture():SetTexture(texture)
         b:GetPushedTexture():SetTexture(texture)  -- Without this, icons disappear on click.

         b:SetScript('OnUpdate', FlyoutBarButton_OnUpdate)

         -- Highlight professions and channeled casts.
         if b.flyoutActionType == ACTION_TYPE_SPELL and IsCurrentCast(b.flyoutAction, 'spell') then
            b:SetChecked(true)
         end

         -- Configure secure attributes so the button casts via Blizzard's secure handler.
         if b.flyoutActionType == ACTION_TYPE_SPELL then
            local spellName = GetSpellName(b.flyoutAction, 'spell')
            b:SetAttribute('type1', 'spell')
            b:SetAttribute('spell1', spellName)
            b:SetAttribute('type2', '')
         elseif b.flyoutActionType == ACTION_TYPE_ITEM then
            b:SetAttribute('type1', 'item')
            b:SetAttribute('item1', b.flyoutAction)
            b:SetAttribute('type2', '')
         elseif b.flyoutActionType == ACTION_TYPE_MACRO then
            local _, _, macroBody = GetMacroInfo(b.flyoutAction)
            b:SetAttribute('type1', 'macro')
            b:SetAttribute('macrotext1', macroBody)
            b:SetAttribute('type2', '')
         end

         -- Force an instant update.
         b.lastUpdate = nil
         FlyoutBarButton_UpdateCooldown(b, true)

         if direction == 'BOTTOM' then
            b:SetPoint('BOTTOM', button, 0, -offset)
         elseif direction == 'LEFT' then
            b:SetPoint('LEFT', button, -offset, 0)
         elseif direction == 'RIGHT' then
            b:SetPoint('RIGHT', button, offset, 0)
         else
            b:SetPoint('TOP', button, 0, offset)
         end

         offset = offset + size
      end
   end
 end

-- Build a reverse map from action slot -> visible button object.
-- Rebuild on PLAYER_ENTERING_WORLD (after addon buttons exist) and
-- ACTIONBAR_PAGE_CHANGED (page swaps change which button shows which slot).
function Flyout_BuildButtonCache()
   wipe(buttonCache)

   if Flyout_GetActionButton_Custom then
      for slot = 1, 120 do
         local button = Flyout_GetActionButton_Custom(slot)
         if button then
            buttonCache[slot] = button
         end
      end
   end

   for i = 1, #bars do
      for j = 1, 12 do
         local button = _G[bars[i] .. 'Button' .. j]
         if button and button:IsVisible() then
            local slot = tonumber(button.action)
                        or tonumber(button._state_action)
                        or (ActionButton_CalculateAction and ActionButton_CalculateAction(button))
            if slot and not buttonCache[slot] then
               buttonCache[slot] = button
            end
         end
      end
   end
end

-- 3.3.5a: ActionButton_GetPagedID was removed in Wrath.  Default action buttons
-- expose the resolved slot as button.action; ElvUI / LibActionButton-1.0 uses
-- button._state_action.  Fall back to ActionButton_CalculateAction if needed.
function Flyout_GetActionButton(action)
   local cached = buttonCache[action]
   if cached then return cached end

   -- Fallback if cache hasn't been built yet (early events before PLAYER_ENTERING_WORLD).
   if Flyout_GetActionButton_Custom then
      local button = Flyout_GetActionButton_Custom(action)
      if button then return button end
   end

   for i = 1, #bars do
      for j = 1, 12 do
         local button = _G[bars[i] .. 'Button' .. j]
         if button and button:IsVisible() then
            local slot = tonumber(button.action)
                        or tonumber(button._state_action)
                        or (ActionButton_CalculateAction and ActionButton_CalculateAction(button))
            if slot == action then
               return button
            end
         end
      end
   end
end

function Flyout_UpdateBars()
   for i = 1, 120 do
      UpdateBarButton(i)
   end
end

function Flyout_UpdateFlyoutArrow(button)
   if not button then return end

   local direction = GetFlyoutDirection(button)

   local arrow = _G[button:GetName() .. 'FlyoutArrow']
   if not arrow then
      arrow = CreateFrame('Frame', button:GetName() .. 'FlyoutArrow', button)
      arrow:SetPoint('TOPLEFT', button)
      arrow:SetPoint('BOTTOMRIGHT', button)
      arrow.flyoutOriginalStrata = arrow:GetFrameStrata()
      arrow.texture = arrow:CreateTexture(arrow:GetName() .. 'Texture', 'ARTWORK')
      arrow.texture:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
   end

   arrow:Show()
   arrow.texture:ClearAllPoints()

   local arrowWideDimension = (button:GetWidth() or 36) * Flyout_Config['ARROW_SCALE']
   local arrowShortDimension = arrowWideDimension * ARROW_RATIO

   if direction == 'BOTTOM' then
      arrow.texture:SetWidth(arrowWideDimension)
      arrow.texture:SetHeight(arrowShortDimension)
      arrow.texture:SetTexCoord(0, 0.565, 0.315, 0)
      arrow.texture:SetPoint('BOTTOM', arrow, 0, -6)
   elseif direction == 'LEFT' then
      arrow.texture:SetWidth(arrowShortDimension)
      arrow.texture:SetHeight(arrowWideDimension)
      arrow.texture:SetTexCoord(0, 0.315, 0.375, 1)
      arrow.texture:SetPoint('LEFT', arrow, -6, 0)
   elseif direction == 'RIGHT' then
      arrow.texture:SetWidth(arrowShortDimension)
      arrow.texture:SetHeight(arrowWideDimension)
      arrow.texture:SetTexCoord(0.315, 0, 0.375, 1)
      arrow.texture:SetPoint('RIGHT', arrow, 6, 0)
   else
      arrow.texture:SetWidth(arrowWideDimension)
      arrow.texture:SetHeight(arrowShortDimension)
      arrow.texture:SetTexCoord(0, 0.565, 0, 0.315)
      arrow.texture:SetPoint('TOP', arrow, 0, 6)
   end
end

-- 3.3.5a port: removed global function hooks for GetActionCooldown,
-- GetActionTexture, IsUsableAction, and UseAction.  The default action
-- is now handled by a /cast line inside the flyout macro, which lets
-- Blizzard's secure handler execute it without taint.
