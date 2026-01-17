local _, NS = ...

local GLD = NS.GLD

local MENU_BUTTON_KEY = "GLD_MENU"
local MENU_ACTION_KEY = "GLD_ADD_GUEST"
local MENU_LIST_KEY = "GLD_MENU_LIST"
local MENU_HOOKED = false

local function GetUnitFromPopup(self)
  if UIDROPDOWNMENU_INIT_MENU and UIDROPDOWNMENU_INIT_MENU.unit then
    return UIDROPDOWNMENU_INIT_MENU.unit
  end
  if self and self.unit then
    return self.unit
  end
  if UnitPopup_GetUnit then
    return UnitPopup_GetUnit()
  end
  return nil
end

local function EnsureUnitPopupEntry()
  if not UnitPopupButtons or not UnitPopupMenus then
    return false
  end
  if UnitPopupButtons[MENU_BUTTON_KEY] then
    return true
  end

  UnitPopupButtons[MENU_BUTTON_KEY] = {
    text = "GLD",
    dist = 0,
    hasArrow = true,
    menuList = MENU_LIST_KEY,
  }

  UnitPopupButtons[MENU_ACTION_KEY] = {
    text = "Add as GLD Guest",
    dist = 0,
    func = function(self)
      if not GLD or not GLD.IsAdmin or not GLD:IsAdmin() then
        return
      end
      local unit = GetUnitFromPopup(self)
      if unit and UnitExists(unit) then
        GLD:AddGuestFromUnit(unit)
      end
    end,
  }

  UnitPopupMenus[MENU_LIST_KEY] = {
    MENU_ACTION_KEY,
  }

  local function addToMenu(menuKey)
    local menu = UnitPopupMenus[menuKey]
    if type(menu) ~= "table" then
      return
    end
    for _, entry in ipairs(menu) do
      if entry == MENU_BUTTON_KEY then
        return
      end
    end
    table.insert(menu, MENU_BUTTON_KEY)
  end

  addToMenu("PARTY")
  addToMenu("RAID")
  addToMenu("RAID_PLAYER")

  if GLD and GLD.Print then
    GLD:Print("GLD menu added to party/raid right-click menus.")
  end

  return true
end

local function EnsureMenuAPIEntry()
  if MENU_HOOKED then
    return true
  end
  if not Menu or not Menu.ModifyMenu then
    return false
  end

  Menu.ModifyMenu("UNIT_POPUP", function(_, rootDescription, contextData)
    if not GLD or not GLD.IsAdmin or not GLD:IsAdmin() then
      return
    end
    local unit = contextData and contextData.unit
    if not unit or not UnitExists(unit) then
      return
    end
    rootDescription:CreateDivider()
    local submenu = rootDescription:CreateButton("GLD")
    submenu:CreateButton("Add as GLD Guest", function()
      GLD:AddGuestFromUnit(unit)
    end)
  end)

  MENU_HOOKED = true
  if GLD and GLD.Print then
    GLD:Print("GLD menu added via Menu API (UNIT_POPUP).")
  end
  return true
end

local function TryRegisterMenu()
  if EnsureUnitPopupEntry() then
    return true
  end
  if EnsureMenuAPIEntry() then
    return true
  end
  return false
end

local function ForceLoadUnitPopup()
  if UnitPopupButtons and UnitPopupMenus then
    return
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    C_AddOns.LoadAddOn("Blizzard_UnitPopup")
    C_AddOns.LoadAddOn("Blizzard_UnitPopupShared")
  elseif LoadAddOn then
    LoadAddOn("Blizzard_UnitPopup")
    LoadAddOn("Blizzard_UnitPopupShared")
  end
end

local attempts = 0
local function RetryRegister()
  attempts = attempts + 1
  if TryRegisterMenu() then
    return
  end
  if attempts < 10 then
    C_Timer.After(0.5, RetryRegister)
  elseif GLD and GLD.Print then
    GLD:Print("GLD menu could not be registered (UnitPopup/Menu API not ready).")
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addon)
  if addon == "Blizzard_UnitPopup" or addon == "Blizzard_UnitPopupShared" then
    RetryRegister()
  end
end)

ForceLoadUnitPopup()
RetryRegister()