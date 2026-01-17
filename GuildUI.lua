local _, NS = ...

local GLD = NS.GLD

function GLD:TryCreateGuildUIButton()
  if self.guildUIButton then
    return
  end

  local parent = CommunitiesFrame or GuildFrame
  if not parent then
    return
  end

  local btn = CreateFrame("Button", "GLD_GuildButton", parent, "UIPanelButtonTemplate")
  btn:SetSize(50, 50)
  btn:SetText("GLD")
  btn:SetPoint("CENTER", parent, "TOPLEFT", 25, -20)

  btn:SetScript("OnClick", function()
    if self.UI and self.UI.ToggleMain then
      self.UI:ToggleMain()
    end
  end)

  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("Guild Loot Distribution")
    GameTooltip:AddLine("Open table", 1, 1, 1)
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self.guildUIButton = btn
end

function GLD:OnAddonLoaded(event, addonName)
  if addonName == "Blizzard_Communities" or addonName == "Blizzard_GuildUI" or addonName == "Blizzard_GuildControlUI" then
    self:TryCreateGuildUIButton()
  end
end
