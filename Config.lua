local _, NS = ...

local GLD = NS.GLD
local AceGUI = LibStub("AceGUI-3.0", true)

local DEFAULT_TRINKET_RAID = "The Voidspire"
local TRINKET_DIFFICULTY_ID = 14
local ITEM_LABEL_WIDGET = "GLD_ItemLabel"

local function EJ_Call(name, ...)
  if C_EncounterJournal and C_EncounterJournal[name] then
    return C_EncounterJournal[name](...)
  end
  local legacy = _G["EJ_" .. name]
  if legacy then
    return legacy(...)
  end
  return nil
end

local trinketLootCache = {
  raids = nil,
  order = nil,
  raidsByName = nil,
  encountersByRaid = {},
  trinketByEncounter = {},
}

local TRINKET_ROLE_VALUES = {
  RANGEDPS = "RangeDPS",
  MELEEDPS = "MeleeDPS",
  TANK = "Tank",
  HEALER = "Healer",
}

local function ExtractItemId(itemLink)
  if not itemLink then
    return nil
  end
  local itemId = itemLink:match("item:(%d+)")
  if itemId then
    return tonumber(itemId)
  end
  return nil
end

local function GetItemIconTag(itemId)
  if not itemId then
    return ""
  end
  local icon = select(5, C_Item.GetItemInfoInstant(itemId))
  if not icon then
    return ""
  end
  return string.format("|T%s:20:20:0:0:64:64:4:60:4:60|t", icon)
end

local function RegisterItemLabelWidget()
  if not AceGUI or AceGUI.widgetRegistry and AceGUI.widgetRegistry[ITEM_LABEL_WIDGET] then
    return
  end

  local function Constructor()
    local frame = CreateFrame("Frame")
    frame:SetHeight(26)
    frame:EnableMouse(true)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", frame, "LEFT", 4, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    label:SetText("")

    local widget = {
      frame = frame,
      label = label,
      type = ITEM_LABEL_WIDGET,
    }

    local function ExtractLink(text)
      if not text then
        return nil
      end
      local link = text:match("|Hitem:[^|]+|h%[[^%]]+%]|h")
      return link
    end

    frame:SetScript("OnEnter", function(self)
      local link = self.itemLink or ExtractLink(label:GetText())
      if link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    function widget:OnAcquire()
      self.itemLink = nil
      self:SetText("")
      frame:Show()
    end

    function widget:OnRelease()
      frame:Hide()
    end

    function widget:SetText(text)
      label:SetText(text or "")
      self.itemLink = ExtractLink(text)
    end

    function widget:SetFontObject(fontObject)
      if fontObject and label.SetFontObject then
        label:SetFontObject(fontObject)
      end
    end

    function widget:SetWidth(width)
      frame:SetWidth(width)
    end

    function widget:SetFullWidth(full)
      if full then
        frame:SetWidth(0)
      end
    end

    return AceGUI:RegisterAsWidget(widget)
  end

  AceGUI:RegisterWidgetType(ITEM_LABEL_WIDGET, Constructor, 1)
end

function GLD:ScheduleTrinketLootRefresh(scope)
  if not C_Timer or not C_Timer.After then
    return
  end
  scope = scope or "raids"
  self._trinketLootRefresh = self._trinketLootRefresh or {}
  if self._trinketLootRefresh[scope] then
    return
  end
  local retryKey = "_trinketLootRetries_" .. scope
  local retries = (self[retryKey] or 0) + 1
  if retries > 10 then
    return
  end
  self[retryKey] = retries
  self._trinketLootRefresh[scope] = true
  C_Timer.After(0.6, function()
    self._trinketLootRefresh[scope] = nil
    if scope == "raids" then
      local ok = self:BuildTrinketLootRaidList()
      if ok then
        self[retryKey] = 0
      else
        self:ScheduleTrinketLootRefresh("raids")
      end
    else
      local raidId = self:GetSelectedTrinketLootRaidId()
      if raidId then
        local encounters = self:GetTrinketLootEncountersForRaid(raidId)
        if encounters then
          self[retryKey] = 0
        else
          self:ScheduleTrinketLootRefresh("encounters")
        end
      end
    end
    if self.options then
      self:RefreshTrinketRoleOptions(self.options)
    end
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
    if AceConfigRegistry then
      AceConfigRegistry:NotifyChange("GuildLoot")
    end
  end)
end

function GLD:GetTrinketRole(itemId)
  if not itemId then
    return { RANGEDPS = true }
  end
  local map = self.db.config.trinketRoleMap
  if type(map) ~= "table" then
    return { RANGEDPS = true }
  end
  local value = map[tostring(itemId)]
  if type(value) == "table" then
    if value.DPS then
      value.DPS = nil
      value.RANGEDPS = true
      value.MELEEDPS = true
    end
    return value
  end
  if type(value) == "string" then
    if value == "DPS" then
      return { RANGEDPS = true, MELEEDPS = true }
    end
    return { [value] = true }
  end
  return { RANGEDPS = true }
end

function GLD:SetTrinketRole(itemId, role, enabled)
  if not itemId then
    return
  end
  local map = self.db.config.trinketRoleMap
  if type(map) ~= "table" then
    map = {}
    self.db.config.trinketRoleMap = map
  end
  local key = tostring(itemId)
  local entry = map[key]
  if type(entry) ~= "table" then
    entry = {}
    map[key] = entry
  end
  if not role or not TRINKET_ROLE_VALUES[role] then
    return
  end
  if enabled == nil then
    enabled = true
  end
  if enabled then
    entry[role] = true
  else
    entry[role] = nil
  end
end

function GLD:EnsureEncounterJournalReady()
  if InCombatLockdown and InCombatLockdown() then
    return false, "Encounter Journal unavailable in combat."
  end
  if not EncounterJournal then
    if C_AddOns and C_AddOns.LoadAddOn then
      C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
      LoadAddOn("Blizzard_EncounterJournal")
    end
  end
  if EncounterJournal_LoadUI then
    EncounterJournal_LoadUI()
  end
  if not EncounterJournal or (not (C_EncounterJournal and C_EncounterJournal.GetNumTiers) and not _G.EJ_GetNumTiers) then
    return false, "Encounter Journal loading..."
  end
  return true
end

function GLD:BuildTrinketLootRaidList()
  if trinketLootCache.raids then
    return true
  end
  local ok, msg = self:EnsureEncounterJournalReady()
  if not ok then
    self:ScheduleTrinketLootRefresh("raids")
    return false, msg
  end

  EJ_Call("SetDifficultyID", TRINKET_DIFFICULTY_ID)

  local values = {}
  local order = {}
  local tiers = EJ_Call("GetNumTiers") or 0
  if tiers == 0 then
    self:ScheduleTrinketLootRefresh("raids")
    return false, "Encounter Journal: no tiers yet"
  end
  for tier = 1, tiers do
    EJ_Call("SelectTier", tier)
    local i = 1
    while true do
      local instanceID, name = EJ_Call("GetInstanceByIndex", i, true)
      if not instanceID then
        break
      end
      if not values[instanceID] then
        values[instanceID] = name
        table.insert(order, instanceID)
      end
      i = i + 1
    end
  end

  if #order == 0 then
    self:ScheduleTrinketLootRefresh("raids")
    return false, "Encounter Journal: no raids found"
  end

  trinketLootCache.raids = values
  trinketLootCache.order = order
  trinketLootCache.raidsByName = {}
  for id, name in pairs(values) do
    trinketLootCache.raidsByName[name] = id
  end

  return true
end

function GLD:GetTrinketLootRaidValues()
  local ok = self:BuildTrinketLootRaidList()
  if not ok then
    self:ScheduleTrinketLootRefresh("raids")
  end
  return trinketLootCache.raids or {}
end

function GLD:GetTrinketLootRaidOrder()
  local ok = self:BuildTrinketLootRaidList()
  if not ok then
    self:ScheduleTrinketLootRefresh("raids")
  end
  return trinketLootCache.order or {}
end

function GLD:GetSelectedTrinketLootRaidId()
  self:BuildTrinketLootRaidList()
  local raidId = self.db.config.trinketLootRaidId
  if raidId and trinketLootCache.raids and trinketLootCache.raids[raidId] then
    return raidId
  end

  local raidName = self.db.config.trinketLootRaidName or DEFAULT_TRINKET_RAID
  if trinketLootCache.raidsByName and raidName and trinketLootCache.raidsByName[raidName] then
    raidId = trinketLootCache.raidsByName[raidName]
    self.db.config.trinketLootRaidId = raidId
    self.db.config.trinketLootRaidName = raidName
    return raidId
  end

  if trinketLootCache.order and trinketLootCache.order[1] then
    raidId = trinketLootCache.order[1]
    self.db.config.trinketLootRaidId = raidId
    self.db.config.trinketLootRaidName = trinketLootCache.raids[raidId]
    return raidId
  end
  return nil
end

function GLD:SetSelectedTrinketLootRaidId(raidId)
  self.db.config.trinketLootRaidId = raidId
  if trinketLootCache.raids and trinketLootCache.raids[raidId] then
    self.db.config.trinketLootRaidName = trinketLootCache.raids[raidId]
  end
  trinketLootCache.encountersByRaid[raidId] = nil
  trinketLootCache.trinketByEncounter = {}
end

function GLD:GetTrinketLootEncountersForRaid(raidId)
  if trinketLootCache.encountersByRaid[raidId] then
    return trinketLootCache.encountersByRaid[raidId]
  end
  local ok, msg = self:EnsureEncounterJournalReady()
  if not ok then
    return nil, msg
  end

  EJ_Call("SetDifficultyID", TRINKET_DIFFICULTY_ID)
  EJ_Call("SelectInstance", raidId)

  local encounters = {}
  local seenEncounterIds = {}
  local i = 1
  while true do
    local a, b, c = EJ_Call("GetEncounterInfoByIndex", i, raidId)
    if not a then
      break
    end
    local encounterID = nil
    local name = nil
    if type(a) == "number" then
      encounterID = a
      name = b
    elseif type(b) == "number" then
      encounterID = b
      name = a
    elseif type(c) == "number" then
      encounterID = c
      name = a
    end

    if encounterID and not seenEncounterIds[encounterID] then
      seenEncounterIds[encounterID] = true
      table.insert(encounters, {
        id = encounterID,
        index = i,
        name = name or ("Encounter " .. encounterID),
      })
    end
    i = i + 1
  end

  if #encounters == 0 then
    return nil, "Encounter Journal: encounters not available yet"
  end

  trinketLootCache.encountersByRaid[raidId] = encounters
  return encounters
end

local function GetLootInfoByIndex(index, encounterId, encounterIndex)
  if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
    return C_EncounterJournal.GetLootInfoByIndex(index)
  end
  if _G.EJ_GetLootInfoByIndex then
    return _G.EJ_GetLootInfoByIndex(index, encounterId or encounterIndex)
  end
  return nil
end

function GLD:GetEncounterTrinketLinks(raidId, encounter)
  if not encounter or not encounter.id then
    return nil
  end
  local cacheKey = tostring(raidId) .. ":" .. tostring(encounter.id)
  if trinketLootCache.trinketByEncounter[cacheKey] ~= nil then
    return trinketLootCache.trinketByEncounter[cacheKey]
  end

  local ok = self:EnsureEncounterJournalReady()
  if not ok then
    return nil
  end

  EJ_Call("SetDifficultyID", TRINKET_DIFFICULTY_ID)
  EJ_Call("SelectInstance", raidId)
  EJ_Call("SetLootFilter", 0)
  if C_EncounterJournal and C_EncounterJournal.ResetLootFilter then
    C_EncounterJournal.ResetLootFilter()
  end
  if _G.EJ_ResetLootFilter then
    _G.EJ_ResetLootFilter()
  end
  if encounter.id then
    EJ_Call("SelectEncounter", encounter.id)
  elseif encounter.index then
    EJ_Call("SelectEncounter", encounter.index)
  end

  local numLoot = nil
  if C_EncounterJournal and C_EncounterJournal.GetNumLoot then
    numLoot = C_EncounterJournal.GetNumLoot()
  elseif _G.EJ_GetNumLoot then
    numLoot = _G.EJ_GetNumLoot()
  end

  local trinkets = {}
  local index = 1
  while true do
    if numLoot and index > numLoot then
      break
    end
    local rawInfo = { GetLootInfoByIndex(index, encounter.id, encounter.index) }
    local info = rawInfo[1]
    if not info then
      break
    end

    local itemID = nil
    local itemLink = nil
    if type(info) == "table" then
      itemID = info.itemId or info.itemID or info.id
      if type(info.link) == "string" then
        itemLink = info.link
      elseif type(info.itemLink) == "string" then
        itemLink = info.itemLink
      end
    else
      for _, value in ipairs(rawInfo) do
        if not itemID and type(value) == "number" then
          itemID = value
        elseif type(value) == "string" then
          if not itemLink and (value:find("|Hitem:") or value:find("^item:")) then
            itemLink = value
          end
        end
      end
    end
    if not itemID and itemLink then
      itemID = tonumber(itemLink:match("item:(%d+)"))
    end

    if itemID then
      local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
      if equipLoc == "INVTYPE_TRINKET" then
        local link = select(2, GetItemInfo(itemID))
        if not link and itemLink then
          link = itemLink
        end
        if not link then
          link = "item:" .. tostring(itemID)
        end
        trinkets[#trinkets + 1] = {
          itemId = itemID,
          link = link,
        }
      end
    end
    index = index + 1
  end

  trinketLootCache.trinketByEncounter[cacheKey] = trinkets
  return trinkets
end

function GLD:GetTrinketLootBossListText()
  local ok, msg = self:BuildTrinketLootRaidList()
  if not ok then
    return msg or "Encounter Journal loading..."
  end
  local raidId = self:GetSelectedTrinketLootRaidId()
  if not raidId then
    return "No raid selected."
  end

  local encounters, err = self:GetTrinketLootEncountersForRaid(raidId)
  if not encounters then
    return err or "No bosses found for this raid."
  end
  if #encounters == 0 then
    return "No bosses found for this raid."
  end

  local lines = { "Bosses:" }
  for _, encounter in ipairs(encounters) do
    local trinkets = self:GetEncounterTrinketLinks(raidId, encounter)
    if trinkets and #trinkets > 0 then
      for _, trinket in ipairs(trinkets) do
        local role = self:GetTrinketRole(trinket.itemId)
        table.insert(lines, string.format("%s %s %s", encounter.name, trinket.link, role))
      end
    else
      table.insert(lines, encounter.name)
    end
  end
  return table.concat(lines, "\n")
end

function GLD:BuildTrinketRoleOptions()
  local ok, msg = self:BuildTrinketLootRaidList()
  if not ok then
    self:ScheduleTrinketLootRefresh("raids")
    return {
      status = {
        type = "description",
        name = msg or "Encounter Journal loading...",
        order = 1,
      },
    }
  end

  local raidId = self:GetSelectedTrinketLootRaidId()
  if not raidId then
    return {
      status = {
        type = "description",
        name = "No raid selected.",
        order = 1,
      },
    }
  end

  local encounters, err = self:GetTrinketLootEncountersForRaid(raidId)
  if not encounters then
    self:ScheduleTrinketLootRefresh("encounters")
    return {
      status = {
        type = "description",
        name = err or "No bosses found for this raid.",
        order = 1,
      },
    }
  end

  local args = {}
  local order = 1
  for _, encounter in ipairs(encounters) do
    local bossKey = string.format("boss_%s", tostring(encounter.id))
    args[bossKey] = {
      type = "description",
      name = string.format("|cffffff00%s|r", encounter.name),
      fontSize = "large",
      order = order,
    }
    order = order + 1

    local trinkets = self:GetEncounterTrinketLinks(raidId, encounter)
    if trinkets and #trinkets > 0 then
      for _, trinket in ipairs(trinkets) do
        local itemId = trinket.itemId
        local link = trinket.link
        local iconTag = GetItemIconTag(itemId)
        local itemKey = string.format("trinket_label_%s_%s", tostring(encounter.id), tostring(itemId))
        args[itemKey] = {
          type = "description",
          dialogControl = ITEM_LABEL_WIDGET,
          name = string.format("%s %s", iconTag, link),
          order = order,
          width = "full",
        }
        order = order + 1

        local roleKey = string.format("trinket_role_%s_%s", tostring(encounter.id), tostring(itemId))
        args[roleKey] = {
          type = "multiselect",
          name = "",
          values = TRINKET_ROLE_VALUES,
          get = function(_, key)
            local roles = GLD:GetTrinketRole(itemId)
            return roles and roles[key] == true
          end,
          set = function(_, key, val)
            GLD:SetTrinketRole(itemId, key, val)
          end,
          order = order,
          width = "full",
        }
        order = order + 1

        local padKey = string.format("trinket_pad_%s_%s", tostring(encounter.id), tostring(itemId))
        args[padKey] = {
          type = "description",
          name = " ",
          order = order,
        }
        order = order + 1
      end
    else
      local emptyKey = string.format("boss_%s_none", tostring(encounter.id))
      args[emptyKey] = {
        type = "description",
        name = "No trinkets found.",
        order = order,
      }
      order = order + 1
    end
  end

  if order == 1 then
    args.status = {
      type = "description",
      name = "No bosses found for this raid.",
      order = 1,
    }
  end
  return args
end

function GLD:RefreshTrinketRoleOptions(options)
  if not options or not options.args or not options.args.customiseTrinketLoot then
    return
  end
  options.args.customiseTrinketLoot.args.trinketRoles = {
    type = "group",
    name = "Boss / Trinket / Role",
    inline = true,
    order = 4,
    args = self:BuildTrinketRoleOptions(),
  }
end

function GLD:BuildAddonAuditOptions()
  local args = {}
  local order = 1
  args.auditButton = {
    type = "execute",
    name = "Audit Addons",
    desc = "Scan raid members for addon installs and versions.",
    order = order,
    width = "full",
    disabled = function()
      return not GLD:CanRunAddonAudit()
    end,
    func = function()
      GLD:StartAddonAudit(true, false)
    end,
  }
  order = order + 1

  args.auditSummary = {
    type = "description",
    name = GLD:GetAddonAuditSummaryText(),
    order = order,
    width = "full",
  }
  order = order + 1

  args.auditHeader = {
    type = "description",
    name = "Player | Status | Version",
    order = order,
    width = "full",
  }
  order = order + 1

  local rows = GLD:GetAddonAuditRows()
  if #rows == 0 then
    args.auditEmpty = {
      type = "description",
      name = "No audit results yet.",
      order = order,
      width = "full",
    }
  else
    for i, line in ipairs(rows) do
      args["auditRow_" .. tostring(i)] = {
        type = "description",
        name = line,
        order = order,
        width = "full",
      }
      order = order + 1
    end
  end
  return args
end

function GLD:RefreshAddonAuditOptions(options)
  if not options or not options.args or not options.args.addonAudit then
    return
  end
  options.args.addonAudit.args = self:BuildAddonAuditOptions()
end

function GLD:InitConfig()
  local AceConfig = LibStub("AceConfig-3.0", true)
  local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
  if not AceConfig or not AceConfigDialog then
    return
  end

  RegisterItemLabelWidget()

  local options = {
    type = "group",
    name = "GuildLoot",
    args = {
      general = {
        type = "group",
        name = "General",
        order = 1,
        args = {
          transmogWinnerMove = {
            type = "select",
            name = "Transmog winner move",
            values = { NONE = "None", END = "End", MIDDLE = "Middle" },
            get = function() return GLD.db.config.transmogWinnerMove end,
            set = function(_, val) GLD.db.config.transmogWinnerMove = val end,
            order = 1,
          },
          greedWinnerMove = {
            type = "select",
            name = "Greed winner move",
            values = { NONE = "None", END = "End" },
            get = function() return GLD.db.config.greedWinnerMove end,
            set = function(_, val) GLD.db.config.greedWinnerMove = val end,
            order = 2,
          },
          pugsInRaid = {
            type = "toggle",
            name = function()
              local enabled = GLD.GetPugsInRaid and GLD:GetPugsInRaid()
              return enabled and "Pugs in raid (ON)" or "Pugs in raid (OFF)"
            end,
            desc = "Manual approval mode: keep loot table/votes, disable Blizzard roll blockers, and require admin confirm/lost.",
            get = function()
              return GLD.GetPugsInRaid and GLD:GetPugsInRaid() or false
            end,
            set = function(_, val)
              if GLD.RequestSetPugsInRaid then
                GLD:RequestSetPugsInRaid(val == true)
              elseif GLD.SetPugsInRaid then
                GLD:SetPugsInRaid(val == true)
              end
            end,
            hidden = function() return not GLD:CanLocalSeeAdminUI() end,
            order = 3,
          },
            debugLogs = {
              type = "toggle",
              name = "Enable debug logs",
              desc = "Log debug messages to the debug window (/glddebug).",
              get = function()
                local ui = GLD.GetUIConfig and GLD:GetUIConfig() or nil
                return ui and ui.debugLogs == true or false
              end,
              set = function(_, val)
                local ui = GLD.GetUIConfig and GLD:GetUIConfig() or nil
                if ui then
                  ui.debugLogs = val and true or false
                end
              end,
            hidden = function() return not GLD:CanLocalSeeAdminUI() end,
            order = 99,
          },
        },
      },
      customiseTrinketLoot = {
        type = "group",
        name = "Customise Trinket Loot",
        order = 2,
        args = {
          loadRaid = {
            type = "execute",
            name = "Load resources",
            desc = "Reload raid and encounter data from the Encounter Journal.",
            order = 1,
            width = "full",
            func = function()
              trinketLootCache.raids = nil
              trinketLootCache.order = nil
              trinketLootCache.raidsByName = nil
              trinketLootCache.encountersByRaid = {}
              trinketLootCache.trinketByEncounter = {}
              GLD:ScheduleTrinketLootRefresh("raids")
              GLD:ScheduleTrinketLootRefresh("encounters")
              GLD:RefreshTrinketRoleOptions(options)
              local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
              if AceConfigRegistry then
                AceConfigRegistry:NotifyChange("GuildLoot")
              end
            end,
          },
          raidSelect = {
            type = "select",
            name = "Raid Encounter",
            values = function() return GLD:GetTrinketLootRaidValues() end,
            sorting = function() return GLD:GetTrinketLootRaidOrder() end,
            get = function() return GLD:GetSelectedTrinketLootRaidId() end,
            set = function(_, val)
              GLD:SetSelectedTrinketLootRaidId(val)
              GLD:RefreshTrinketRoleOptions(options)
              local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
              if AceConfigRegistry then
                AceConfigRegistry:NotifyChange("GuildLoot")
              end
            end,
            order = 2,
            width = "full",
          },
          info = {
            type = "description",
            name = "Configure custom trinket loot settings here.",
            order = 3,
            width = "full",
          },
        },
      },
      addonAudit = {
        type = "group",
        name = "Addon Audit",
        order = 3,
        hidden = function() return not GLD:CanLocalSeeAdminUI() end,
        args = {},
      },
    },
  }

  self:RefreshTrinketRoleOptions(options)
  self:RefreshAddonAuditOptions(options)
  AceConfig:RegisterOptionsTable("GuildLoot", options)
  self.options = options
end

function GLD:OpenConfig()
  local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
  if not AceConfigDialog then
    return
  end
  AceConfigDialog:Open("GuildLoot")
end
