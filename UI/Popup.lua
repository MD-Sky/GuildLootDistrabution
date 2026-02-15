local _, NS = ...

local GLD = NS.GLD
local AceGUI = LibStub("AceGUI-3.0", true)

local UI = NS.UI or {}
NS.UI = UI
GLD.UI = UI

local function GetPopupDismissed()
  if not GLD or not GLD.GetUIConfig then
    return nil
  end
  local ui = GLD:GetUIConfig()
  if not ui then
    return nil
  end
  ui.popupDismissed = ui.popupDismissed or {}
  return ui.popupDismissed
end

function UI:ShowPopup(title, bodyText, options)
  options = options or {}
  local dismissKey = options.dontShowKey
  if dismissKey then
    local dismissed = GetPopupDismissed()
    if dismissed and dismissed[dismissKey] then
      return
    end
  end

  if not AceGUI then
    if GLD and GLD.Print then
      GLD:Print(bodyText or title or "")
    end
    return
  end

  if self.popupFrame then
    self.popupFrame:Release()
    self.popupFrame = nil
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle(title or "lilyUI")
  frame:SetWidth(options.width or 380)
  frame:SetHeight(options.height or 200)
  frame:SetLayout("Flow")
  frame:EnableResize(false)

  local label = AceGUI:Create("Label")
  label:SetFullWidth(true)
  label:SetText(bodyText or "")
  frame:AddChild(label)

  local check = nil
  if dismissKey then
    check = AceGUI:Create("CheckBox")
    check:SetLabel("Don't show again")
    check:SetValue(false)
    check:SetFullWidth(true)
    frame:AddChild(check)
  end

  local function CommitDismiss()
    if dismissKey and check and check:GetValue() then
      local dismissed = GetPopupDismissed()
      if dismissed then
        dismissed[dismissKey] = true
      end
    end
  end

  local okButton = AceGUI:Create("Button")
  okButton:SetText("OK")
  okButton:SetWidth(100)
  okButton:SetCallback("OnClick", function()
    CommitDismiss()
    self.popupFrame = nil
    frame:Release()
  end)
  frame:AddChild(okButton)

  frame:SetCallback("OnClose", function(widget)
    CommitDismiss()
    self.popupFrame = nil
    widget:Release()
  end)

  self.popupFrame = frame
end
