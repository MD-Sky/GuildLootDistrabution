local _, NS = ...

local GLD = NS.GLD

local AceGUI = LibStub and LibStub("AceGUI-3.0", true) or nil

local function DegToRad(deg)
  return deg * (math.pi / 180)
end

function GLD:UpdateMinimapButtonPosition()
  if not self.minimapButton or not Minimap then
    return
  end
  local ui = self.GetUIConfig and self:GetUIConfig() or nil
  local config = ui and ui.minimap or nil
  if not config then
    return
  end
  local angle = config.angle or 220
  local radius = (Minimap:GetWidth() / 2) + 8
  local rad = DegToRad(angle)
  local x = math.cos(rad) * radius
  local y = math.sin(rad) * radius
  self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function GLD:ToggleMinimapMenu()
  if not AceGUI then
    if self.UI and self.UI.ToggleMain then
      self.UI:ToggleMain()
    end
    return
  end

  if self.minimapMenu and self.minimapMenu:IsShown() then
    self.minimapMenu:Hide()
    return
  end

  if not self.minimapMenu then
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Guild Loot")
    frame:SetWidth(190)
    frame:SetHeight(140)
    frame:SetLayout("Flow")
    frame:EnableResize(false)
    if frame.frame then
      frame.frame:ClearAllPoints()
      if self.minimapButton then
        frame.frame:SetPoint("TOPLEFT", self.minimapButton, "BOTTOMLEFT", 0, -4)
      else
        frame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      end
    end

    local tableBtn = AceGUI:Create("Button")
    tableBtn:SetText("Table")
    tableBtn:SetFullWidth(true)
    tableBtn:SetCallback("OnClick", function()
      if self.UI and self.UI.ToggleMain then
        self.UI:ToggleMain()
      end
    end)
    frame:AddChild(tableBtn)

    if self:IsAdmin() then
      local adminBtn = AceGUI:Create("Button")
      adminBtn:SetText("Admin Test")
      adminBtn:SetFullWidth(true)
      adminBtn:SetCallback("OnClick", function()
        if NS.TestUI then
          NS.TestUI:ToggleTestPanel()
        end
      end)
      frame:AddChild(adminBtn)
    end

    self.minimapMenu = frame
  end

  self.minimapMenu:Show()
end

function GLD:InitMinimapButton()
  if not Minimap then
    return
  end
  local ui = self.GetUIConfig and self:GetUIConfig() or nil
  if not ui then
    return
  end
  ui.minimap = ui.minimap or { hide = false, angle = 220 }
  local config = ui.minimap

  if self.minimapButton then
    self:UpdateMinimapButtonPosition()
    if config.hide then
      self.minimapButton:Hide()
    else
      self.minimapButton:Show()
    end
    return
  end

  local button = CreateFrame("Button", "GLD_MinimapButton", Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER", 0, 1)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(52, 52)
  border:SetPoint("TOPLEFT")

  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("Guild Loot Distribution")
    GameTooltip:AddLine("Left click: menu", 1, 1, 1)
    GameTooltip:AddLine("Right click: menu", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:SetScript("OnClick", function()
    self:ToggleMinimapMenu()
  end)

  button:SetScript("OnDragStart", function()
    button:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      local angle = math.deg(math.atan2(cy - my, cx - mx))
      if angle < 0 then
        angle = angle + 360
      end
      config.angle = angle
      self:UpdateMinimapButtonPosition()
    end)
  end)

  button:SetScript("OnDragStop", function()
    button:SetScript("OnUpdate", nil)
  end)

  self.minimapButton = button
  self:UpdateMinimapButtonPosition()
  if config.hide then
    button:Hide()
  end
end
