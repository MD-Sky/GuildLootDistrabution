local _, NS = ...

local GLD = NS.GLD
local AceGUI = LibStub("AceGUI-3.0", true)

local TestUI = {}
NS.TestUI = TestUI

local TEST_VOTERS = {
  { name = "Lily", class = "DRUID", armor = "Leather", weapon = "Staff" },
  { name = "Rob", class = "SHAMAN", armor = "Mail", weapon = "One-Handed Mace & Shield" },
  { name = "Steph", class = "HUNTER", armor = "Mail", weapon = "Bow" },
  { name = "Alex", class = "WARLOCK", armor = "Cloth", weapon = "Staff" },
  { name = "Ryan", class = "DEATHKNIGHT", armor = "Plate", weapon = "Two-Handed Sword" },
  { name = "Vulthan", class = "WARRIOR", armor = "Plate", weapon = "Two-Handed Axe" },
}

local CLASS_TO_ARMOR = {
  WARRIOR = "Plate",
  PALADIN = "Plate",
  DEATHKNIGHT = "Plate",
  HUNTER = "Mail",
  SHAMAN = "Mail",
  EVOKER = "Mail",
  ROGUE = "Leather",
  DRUID = "Leather",
  MONK = "Leather",
  DEMONHUNTER = "Leather",
  PRIEST = "Cloth",
  MAGE = "Cloth",
  WARLOCK = "Cloth",
}

local function BuildDynamicTestVoters()
  if not IsInGroup() then
    return nil
  end

  local voters = {}
  local function addUnit(unit)
    if not UnitExists(unit) then
      return
    end
    local name, realm = UnitName(unit)
    if not name then
      return
    end
    local classFile = select(2, UnitClass(unit))
    local armor = CLASS_TO_ARMOR[classFile] or "-"
    local displayName = name
    if realm and realm ~= "" then
      displayName = name .. "-" .. realm
    end
    voters[#voters + 1] = {
      name = displayName,
      class = classFile,
      armor = armor,
      weapon = nil,
    }
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      addUnit("raid" .. i)
    end
  else
    for i = 1, GetNumSubgroupMembers() do
      addUnit("party" .. i)
    end
    addUnit("player")
  end

  if #voters > 0 then
    return voters
  end
  return nil
end

local function GetActiveVoters()
  return TestUI.dynamicVoters or TEST_VOTERS
end

local function BuildTestRosterList()
  local list = {}
  if TestUI.dynamicVoters and #TestUI.dynamicVoters > 0 then
    for _, voter in ipairs(TestUI.dynamicVoters) do
      local name, realm = NS:SplitNameRealm(voter.name)
      local key = GLD:FindPlayerKeyByName(name, realm)
      if key and GLD.db.players[key] then
        list[#list + 1] = GLD.db.players[key]
      else
        list[#list + 1] = {
          name = name,
          realm = realm or GetRealmName(),
          class = voter.class,
          attendance = "PRESENT",
          numAccepted = 0,
          attendanceCount = 0,
          _isGuest = true,
        }
      end
    end
    return list
  end

  for _, player in pairs(GLD.db.players) do
    list[#list + 1] = player
  end
  return list
end

local function GetTestVoter(index)
  return GetActiveVoters()[index]
end

local function GetTestVoterName(index)
  local entry = GetActiveVoters()[index]
  return entry and entry.name or nil
end

local function NormalizeItemInput(itemLink)
  if not itemLink or itemLink == "" then
    return nil
  end
  local normalized = itemLink
  local wowheadId = itemLink:match("item=(%d+)")
  if wowheadId then
    normalized = "item:" .. wowheadId
  end
  if not normalized:find("|Hitem:") and normalized:find("^item:%d+") then
    normalized = "item:" .. normalized:match("item:(%d+)")
  end
  return normalized
end

local function IsEligibleForNeedSafe(classFile, itemLink)
  if not classFile or not itemLink then
    return false
  end
  local classID = C_Item.GetItemInfoInstant(itemLink)
  if not classID then
    GLD:RequestItemData(itemLink)
    return true
  end
  return GLD:IsEligibleForNeed(classFile, itemLink)
end

local EQUIP_SLOT_LABELS = {
  INVTYPE_HEAD = "Head",
  INVTYPE_SHOULDER = "Shoulder",
  INVTYPE_CHEST = "Chest",
  INVTYPE_ROBE = "Chest",
  INVTYPE_WAIST = "Waist",
  INVTYPE_LEGS = "Legs",
  INVTYPE_FEET = "Feet",
  INVTYPE_WRIST = "Wrist",
  INVTYPE_HAND = "Hands",
  INVTYPE_CLOAK = "Back",
}

local ARMOR_SUBCLASS = {
  [1] = "Cloth",
  [2] = "Leather",
  [3] = "Mail",
  [4] = "Plate",
}

local ARMOR_SPECIAL = {
  [0] = "Trinket",
  [2] = "Neck",
  [11] = "Ring",
}

local function GetArmorTypeOnly(itemLink)
  if not itemLink then
    return "-"
  end
  local classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
  if not classID then
    GLD:RequestItemData(itemLink)
    return "-"
  end
  if classID == 4 then
    local armor = ARMOR_SPECIAL[subClassID] or ARMOR_SUBCLASS[subClassID]
    if armor then
      return armor
    end
  end
  if classID == 2 then
    return "Weapon"
  end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
  if itemType == "Armor" and itemSubType and itemSubType ~= "" then
    return itemSubType
  end
  if itemType and itemType ~= "" then
    return itemType
  end
  return "Other"
end

local function GetLootTypeText(itemLink)
  if not itemLink then
    return "-"
  end
  local classID, subClassID, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
  if not classID then
    return "-"
  end
  if classID == 4 then
    local armor = ARMOR_SUBCLASS[subClassID] or "Armor"
    local slot = EQUIP_SLOT_LABELS[equipLoc] or "Other"
    return armor .. " " .. slot
  end
  if classID == 2 then
    return "Weapon"
  end
  return "Other"
end

local function GetLootTypeDetailed(itemLink)
  if not itemLink then
    return "-"
  end
  local classID, subClassID, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
  if not classID then
    return "-"
  end
  if classID == 4 then
    local armor = ARMOR_SPECIAL[subClassID] or ARMOR_SUBCLASS[subClassID] or "Armor"
    local slot = EQUIP_SLOT_LABELS[equipLoc] or "Other"
    return armor .. " " .. slot
  end
  if classID == 2 then
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if itemType == "Weapon" and itemSubType and itemSubType ~= "" then
      return "Weapon - " .. itemSubType
    end
    return "Weapon"
  end
  local _, _, _, _, _, itemType = GetItemInfo(itemLink)
  return itemType or "Other"
end

local function IsPreferredItemForEntry(entry, itemLink)
  if not entry or not itemLink then
    return false
  end
  if GLD.GetItemClassRestrictions then
    local restriction = GLD:GetItemClassRestrictions(itemLink)
    if restriction then
      return restriction[entry.class] == true
    end
  end
  local armorType = GetArmorTypeOnly(itemLink)
  if armorType == "Cloth" or armorType == "Leather" or armorType == "Mail" or armorType == "Plate" then
    return entry.armor == armorType
  end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
  if itemType == "Weapon" then
    if not entry.weapon or not itemSubType then
      return false
    end
    local pref = string.lower(entry.weapon)
    local sub = string.lower(itemSubType)
    if pref:find("bow") and sub:find("bow") then
      return true
    end
    if pref:find("gun") and sub:find("gun") then
      return true
    end
    if pref:find("crossbow") and sub:find("crossbow") then
      return true
    end
    if pref:find("staff") and sub:find("staff") then
      return true
    end
    if pref:find("polearm") and sub:find("polearm") then
      return true
    end
    if pref:find("sword") and sub:find("sword") then
      return true
    end
    if pref:find("axe") and sub:find("axe") then
      return true
    end
    if pref:find("mace") and sub:find("mace") then
      return true
    end
    if pref:find("dagger") and sub:find("dagger") then
      return true
    end
    if pref:find("fist") and sub:find("fist") then
      return true
    end
  end
  return false
end

local function IsNeedAllowedForEntry(entry, itemLink)
  return IsPreferredItemForEntry(entry, itemLink)
end

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

local DEFAULT_TEST_RAID = "Manaforge Omega"
local DEFAULT_TEST_ENCOUNTER = "Manaforge Omega"

local function ColorizeClassName(name, classFile)
  if not name then
    return "?"
  end
  if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
    local c = RAID_CLASS_COLORS[classFile]
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
  end
  return name
end

function TestUI:SetEJStatus(text)
  if self.ejStatusLabel then
    self.ejStatusLabel:SetText(text or "")
  end
end

function GLD:InitTestUI()
  TestUI.testFrame = nil
  TestUI.testVotes = {}
  TestUI.currentVoterIndex = 0
  TestUI.disableManualVotes = true
  TestUI.queueEditEnabled = false
end

function TestUI:ResetTestVotes()
  self.testVotes = {}
  self.currentVoterIndex = 0
end

function TestUI:UpdateDynamicTestVoters()
  local voters = BuildDynamicTestVoters()
  if not voters then
    if self.dynamicVoters then
      self.dynamicVoters = nil
      self:ResetTestVotes()
    end
    return
  end

  local signature = {}
  for _, entry in ipairs(voters) do
    signature[#signature + 1] = entry.name .. ":" .. tostring(entry.class or "")
  end
  local newSignature = table.concat(signature, "|")

  if self._dynamicVotersSignature ~= newSignature then
    self.dynamicVoters = voters
    self._dynamicVotersSignature = newSignature
    self:ResetTestVotes()
  else
    self.dynamicVoters = voters
  end
end

function TestUI:SetSelectedItemLink(itemLink)
  if self.itemLinkInput and itemLink then
    self.itemLinkInput:SetText(itemLink)
  end
  self:UpdateSelectedItemInfo()
end

function TestUI:UpdateSelectedItemInfo()
  if not self.itemArmorLabel then
    return
  end
  local itemLink = NormalizeItemInput(self.itemLinkInput and self.itemLinkInput:GetText() or nil)
  local armorType = GetArmorTypeOnly(itemLink)
  self.itemArmorLabel:SetText("Armor Type: " .. armorType)
end

function TestUI:ToggleTestPanel()
  if not GLD:IsAdmin() then
    GLD:Print("you do not have Guild Permission to access this panel")
    return
  end
  if not self.testFrame then
    self:CreateTestFrame()
  end
  if self.testFrame:IsShown() then
    self.testFrame:Hide()
  else
    self:ResetTestVotes()
    self.testFrame:Show()
    GLD:Print("Test panel opened")
    self:RefreshTestPanel()
  end
end

function TestUI:CreateTestFrame()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Admin Test Panel")
  frame:SetStatusText("Test Session / Loot / Variables")
  frame:SetWidth(900)
  frame:SetHeight(560)
  frame:SetLayout("Flow")
  frame:EnableResize(false)

  local columns = AceGUI:Create("SimpleGroup")
  columns:SetFullWidth(true)
  columns:SetFullHeight(true)
  columns:SetLayout("Flow")
  frame:AddChild(columns)

  local rightColumn = AceGUI:Create("ScrollFrame")
  rightColumn:SetFullWidth(true)
  rightColumn:SetHeight(465)
  rightColumn:SetLayout("List")
  columns:AddChild(rightColumn)

  local sessionGroup = AceGUI:Create("SimpleGroup")
  sessionGroup:SetFullWidth(true)
  sessionGroup:SetLayout("Flow")

  local sessionLabel = AceGUI:Create("Heading")
  sessionLabel:SetText("Session Controls")
  sessionLabel:SetFullWidth(true)
  sessionGroup:AddChild(sessionLabel)

  local startBtn = AceGUI:Create("Button")
  startBtn:SetText("Start Session")
  startBtn:SetWidth(150)
  startBtn:SetCallback("OnClick", function()
    GLD:StartSession()
    TestUI:RefreshTestPanel()
  end)
  sessionGroup:AddChild(startBtn)

  local endBtn = AceGUI:Create("Button")
  endBtn:SetText("End Session")
  endBtn:SetWidth(150)
  endBtn:SetCallback("OnClick", function()
    GLD:EndSession()
    TestUI:RefreshTestPanel()
  end)
  sessionGroup:AddChild(endBtn)

  local queueEditBtn = AceGUI:Create("Button")
  queueEditBtn:SetWidth(150)
  local function updateQueueEditLabel()
    queueEditBtn:SetText(TestUI.queueEditEnabled and "Queue Edit: On" or "Queue Edit: Off")
  end
  updateQueueEditLabel()
  queueEditBtn:SetCallback("OnClick", function()
    TestUI.queueEditEnabled = not TestUI.queueEditEnabled
    updateQueueEditLabel()
    TestUI:RefreshTestPanel()
  end)
  sessionGroup:AddChild(queueEditBtn)

  local sessionStatus = AceGUI:Create("Label")
  sessionStatus:SetFullWidth(true)
  sessionStatus:SetText("Session Status: INACTIVE")
  sessionGroup:AddChild(sessionStatus)

  rightColumn:AddChild(sessionGroup)

  local rosterLabel = AceGUI:Create("Heading")
  rosterLabel:SetText("Player Management")
  rosterLabel:SetFullWidth(true)
  rightColumn:AddChild(rosterLabel)

  local rosterScroll = AceGUI:Create("ScrollFrame")
  rosterScroll:SetFullWidth(true)
  rosterScroll:SetHeight(180)
  rosterScroll:SetLayout("Flow")
  rightColumn:AddChild(rosterScroll)

  local voteGroup = AceGUI:Create("InlineGroup")
  voteGroup:SetTitle("Test Vote Selection")
  voteGroup:SetFullWidth(true)
  voteGroup:SetHeight(170)
  voteGroup:SetLayout("Fill")

  local voteScroll = AceGUI:Create("ScrollFrame")
  voteScroll:SetFullWidth(true)
  voteScroll:SetHeight(160)
  voteScroll:SetLayout("Flow")
  voteGroup:AddChild(voteScroll)
  rightColumn:AddChild(voteGroup)

  local resultsGroup = AceGUI:Create("InlineGroup")
  resultsGroup:SetTitle("Loot Distribution (Test)")
  resultsGroup:SetFullWidth(true)
  resultsGroup:SetHeight(170)
  resultsGroup:SetLayout("Fill")

  local resultsScroll = AceGUI:Create("ScrollFrame")
  resultsScroll:SetFullWidth(true)
  resultsScroll:SetHeight(140)
  resultsScroll:SetLayout("Flow")
  resultsGroup:AddChild(resultsScroll)
  rightColumn:AddChild(resultsGroup)

  local lootFrame = AceGUI:Create("Frame")
  lootFrame:SetTitle("Test Loot Choices")
  lootFrame:SetStatusText("Loot")
  lootFrame:SetWidth(320)
  lootFrame:SetHeight(560)
  lootFrame:SetLayout("Flow")
  lootFrame:EnableResize(false)
  if lootFrame.frame then
    lootFrame.frame:ClearAllPoints()
    lootFrame.frame:SetPoint("RIGHT", frame.frame, "LEFT", -10, 0)
  end

  local instanceSelect = AceGUI:Create("Dropdown")
  instanceSelect:SetLabel("Raid")
  instanceSelect:SetWidth(260)
  lootFrame:AddChild(instanceSelect)

  local encounterSelect = AceGUI:Create("Dropdown")
  encounterSelect:SetLabel("Encounter")
  encounterSelect:SetWidth(260)
  lootFrame:AddChild(encounterSelect)

  local ejStatusLabel = AceGUI:Create("Label")
  ejStatusLabel:SetFullWidth(true)
  ejStatusLabel:SetText("Encounter Journal: idle")
  lootFrame:AddChild(ejStatusLabel)

  local ejReloadBtn = AceGUI:Create("Button")
  ejReloadBtn:SetText("Reload Encounter Journal")
  ejReloadBtn:SetWidth(200)
  ejReloadBtn:SetCallback("OnClick", function()
    TestUI:SetEJStatus("Encounter Journal: reloading...")
    TestUI:RefreshInstanceList()
  end)
  lootFrame:AddChild(ejReloadBtn)

  local loadLootBtn = AceGUI:Create("Button")
  loadLootBtn:SetText("Load Loot")
  loadLootBtn:SetWidth(120)
  lootFrame:AddChild(loadLootBtn)

  local itemLinkInput = AceGUI:Create("EditBox")
  itemLinkInput:SetLabel("Item Link")
  itemLinkInput:SetWidth(260)
  itemLinkInput:SetText("item:19345")
  lootFrame:AddChild(itemLinkInput)

  local itemArmorLabel = AceGUI:Create("Label")
  itemArmorLabel:SetFullWidth(true)
  itemArmorLabel:SetText("Armor Type: -")
  lootFrame:AddChild(itemArmorLabel)

  local dropBtn = AceGUI:Create("Button")
  dropBtn:SetText("Simulate Loot Roll")
  dropBtn:SetWidth(150)
  dropBtn:SetCallback("OnClick", function()
    TestUI:SimulateLootRoll(itemLinkInput:GetText())
  end)
  lootFrame:AddChild(dropBtn)

  local pendingBtn = AceGUI:Create("Button")
  pendingBtn:SetText("Show Pending Votes UI")
  pendingBtn:SetWidth(180)
  pendingBtn:SetCallback("OnClick", function()
    if GLD.UI then
      if GLD.UI.TogglePendingFrame then
        GLD.UI:TogglePendingFrame()
      end
    end
  end)
  lootFrame:AddChild(pendingBtn)

  local lootListGroup = AceGUI:Create("InlineGroup")
  lootListGroup:SetTitle("Encounter Loot")
  lootListGroup:SetFullWidth(true)
  lootListGroup:SetLayout("Fill")

  local lootScroll = AceGUI:Create("ScrollFrame")
  lootScroll:SetLayout("Flow")
  lootListGroup:AddChild(lootScroll)
  lootFrame:AddChild(lootListGroup)

  self.testFrame = frame
  self.sessionStatus = sessionStatus
  self.rosterScroll = rosterScroll
  self.voteGroup = voteGroup
  self.voteScroll = voteScroll
  self.resultsGroup = resultsGroup
  self.resultsScroll = resultsScroll
  self.lootScroll = lootScroll
  self.instanceSelect = instanceSelect
  self.lootFrame = lootFrame
  self.ejStatusLabel = ejStatusLabel

  self.encounterSelect = encounterSelect
  self.itemLinkInput = itemLinkInput
  self.itemArmorLabel = itemArmorLabel

  instanceSelect:SetCallback("OnValueChanged", function(_, _, value)
    TestUI:SelectInstance(value)
  end)
  encounterSelect:SetCallback("OnValueChanged", function(_, _, value)
    TestUI:SelectEncounter(value)
  end)
  loadLootBtn:SetCallback("OnClick", function()
    TestUI:LoadEncounterLoot()
  end)
  itemLinkInput:SetCallback("OnEnterPressed", function()
    TestUI:UpdateSelectedItemInfo()
  end)
  itemLinkInput:SetCallback("OnTextChanged", function()
    TestUI:UpdateSelectedItemInfo()
  end)
  self:UpdateSelectedItemInfo()

  frame:Hide()
end

function TestUI:RefreshTestPanel()
  if not self.testFrame then
    return
  end

  self:UpdateDynamicTestVoters()

  local sessionActive = GLD.db.session and GLD.db.session.active
  self.sessionStatus:SetText("Session Status: " .. (sessionActive and "|cff00ff00ACTIVE|r" or "|cffff0000INACTIVE|r"))

  self.rosterScroll:ReleaseChildren()

  GLD:Debug("RefreshTestPanel: resultsScroll=" .. tostring(self.resultsScroll))

  local list = BuildTestRosterList()

  table.sort(list, function(a, b)
    if a.attendance == "PRESENT" and b.attendance ~= "PRESENT" then
      return true
    end
    if a.attendance ~= "PRESENT" and b.attendance == "PRESENT" then
      return false
    end
    if a.attendance == "PRESENT" and b.attendance == "PRESENT" then
      local posA = a.queuePos or 99999
      local posB = b.queuePos or 99999
      if posA ~= posB then
        return posA < posB
      end
    end
    if a.attendance ~= "PRESENT" and b.attendance ~= "PRESENT" then
      local posA = a.savedPos or 99999
      local posB = b.savedPos or 99999
      if posA ~= posB then
        return posA < posB
      end
    end
    return (a.name or "") < (b.name or "")
  end)

  for _, player in ipairs(list) do
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local nameLabel = AceGUI:Create("Label")
    local displayName = player.name or "?"
    if player._isGuest then
      displayName = displayName .. " (Party)"
    end
    nameLabel:SetText(ColorizeClassName(displayName, player.class))
    nameLabel:SetWidth(160)
    row:AddChild(nameLabel)

    local attendanceLabel = AceGUI:Create("Label")
    attendanceLabel:SetText(player.attendance or "-")
    attendanceLabel:SetWidth(80)
    row:AddChild(attendanceLabel)

    local toggleBtn = AceGUI:Create("Button")
    toggleBtn:SetText(player.attendance == "PRESENT" and "Mark Absent" or "Mark Present")
    toggleBtn:SetWidth(120)
    local playerKey = player.name .. "-" .. (player.realm or GetRealmName())
    if player._isGuest then
      toggleBtn:SetText("Party Member")
      if toggleBtn.SetDisabled then
        toggleBtn:SetDisabled(true)
      end
    else
      toggleBtn:SetCallback("OnClick", function()
        if GLD.db.players[playerKey] then
          local newState = GLD.db.players[playerKey].attendance == "PRESENT" and "ABSENT" or "PRESENT"
          GLD:SetAttendance(playerKey, newState)
          TestUI:RefreshTestPanel()
        end
      end)
    end
    row:AddChild(toggleBtn)

    if self.queueEditEnabled and not player._isGuest then
      local queueBox = AceGUI:Create("EditBox")
      queueBox:SetLabel("Queue")
      queueBox:SetText(tostring(player.queuePos or ""))
      queueBox:SetWidth(60)
      queueBox:SetCallback("OnEnterPressed", function(_, _, value)
        local pos = tonumber(value)
        if GLD.db.players[playerKey] then
          GLD:RemoveFromQueue(playerKey)
          GLD:InsertToQueue(playerKey, pos)
          TestUI:RefreshTestPanel()
        end
      end)
      row:AddChild(queueBox)
    else
      local queueLabel = AceGUI:Create("Label")
      queueLabel:SetText(tostring(player.queuePos or "-"))
      queueLabel:SetWidth(60)
      row:AddChild(queueLabel)
    end

    local frozenLabel = AceGUI:Create("Label")
    frozenLabel:SetText(tostring(player.savedPos or 0))
    frozenLabel:SetWidth(60)
    row:AddChild(frozenLabel)

    local wonBox = AceGUI:Create("EditBox")
    wonBox:SetLabel("Won")
    wonBox:SetText(tostring(player.numAccepted or 0))
    wonBox:SetWidth(80)
    if player._isGuest then
      if wonBox.SetDisabled then
        wonBox:SetDisabled(true)
      end
    else
      wonBox:SetCallback("OnEnterPressed", function(_, _, value)
        local num = tonumber(value) or 0
        if GLD.db.players[playerKey] then
          GLD.db.players[playerKey].numAccepted = num
        end
      end)
    end
    row:AddChild(wonBox)

    local raidsBox = AceGUI:Create("EditBox")
    raidsBox:SetLabel("Raids")
    raidsBox:SetText(tostring(player.attendanceCount or 0))
    raidsBox:SetWidth(80)
    if player._isGuest then
      if raidsBox.SetDisabled then
        raidsBox:SetDisabled(true)
      end
    else
      raidsBox:SetCallback("OnEnterPressed", function(_, _, value)
        local num = tonumber(value) or 0
        if GLD.db.players[playerKey] then
          GLD.db.players[playerKey].attendanceCount = num
        end
      end)
    end
    row:AddChild(raidsBox)

    self.rosterScroll:AddChild(row)
  end

  self:RefreshInstanceList()
  self:RefreshVotePanel()
  self:RefreshResultsPanel()
end

function TestUI:RefreshVotePanel()
  if not self.voteScroll then
    return
  end

  self:UpdateDynamicTestVoters()

  if self.currentVoterIndex == nil or self.currentVoterIndex < 0 then
    self.currentVoterIndex = 0
  end

  self.voteScroll:ReleaseChildren()
  GLD:Debug("RefreshVotePanel: index=" .. tostring(self.currentVoterIndex))

  local debugLabel = AceGUI:Create("Label")
  debugLabel:SetFullWidth(true)
  debugLabel:SetText("Test vote panel active")
  self.voteScroll:AddChild(debugLabel)

  local resetBtn = AceGUI:Create("Button")
  resetBtn:SetText("Reset Votes")
  resetBtn:SetWidth(120)
  resetBtn:SetCallback("OnClick", function()
    self:ResetTestVotes()
    self:RefreshVotePanel()
    self:RefreshResultsPanel()
  end)
  if self.disableManualVotes then
    if resetBtn.SetDisabled then
      resetBtn:SetDisabled(true)
    end
  end
  self.voteScroll:AddChild(resetBtn)

  if self.disableManualVotes then
    if self.voteGroup then
      self.voteGroup:SetTitle("Test Vote Selection (live)")
    end
    local infoLabel = AceGUI:Create("Label")
    infoLabel:SetFullWidth(true)
    infoLabel:SetText("Manual voting disabled. Waiting for live votes sent to the authority.")
    self.voteScroll:AddChild(infoLabel)
    return
  end

  local activeVoters = GetActiveVoters()
  local currentEntry = activeVoters[self.currentVoterIndex + 1]
  local name = currentEntry and currentEntry.name or nil
  if self.voteGroup then
    self.voteGroup:SetTitle("Test Vote Selection" .. (name and (" - " .. name) or ""))
  end
  GLD:Debug("Test vote current player=" .. tostring(name))
  if not name then
    local doneLabel = AceGUI:Create("Label")
    doneLabel:SetFullWidth(true)
    doneLabel:SetText("All test votes recorded.")
    self.voteScroll:AddChild(doneLabel)
    self:RefreshResultsPanel()
    return
  end

  local header = AceGUI:Create("Heading")
  header:SetFullWidth(true)
  header:SetText("Player: " .. name)
  self.voteScroll:AddChild(header)

  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")

  local itemLink = NormalizeItemInput(self.itemLinkInput and self.itemLinkInput:GetText() or nil)
  local canNeed = true
  if itemLink and currentEntry and currentEntry.class then
    canNeed = IsNeedAllowedForEntry(currentEntry, itemLink)
  end

  local function addButton(text, vote)
    local btn = AceGUI:Create("Button")
    btn:SetText(text)
    btn:SetWidth(70)
    if vote == "NEED" and not canNeed then
      btn:SetDisabled(true)
    end
    btn:SetCallback("OnClick", function()
      self.testVotes[name] = vote
      self.currentVoterIndex = self.currentVoterIndex + 1
      GLD:Debug("Test vote: " .. tostring(name) .. " -> " .. tostring(vote) .. " (next index=" .. tostring(self.currentVoterIndex) .. ")")
      self:RefreshVotePanel()
      self:RefreshResultsPanel()
    end)
    row:AddChild(btn)
  end

  addButton("Need", "NEED")
  addButton("Greed", "GREED")
  addButton("Mog", "TRANSMOG")
  addButton("Pass", "PASS")

  self.voteScroll:AddChild(row)
  self:RefreshResultsPanel()
end

function TestUI:RefreshResultsPanel()
  if not self.resultsScroll then
    return
  end

  self:UpdateDynamicTestVoters()

  self.resultsScroll:ReleaseChildren()

  local header = AceGUI:Create("Label")
  header:SetFullWidth(true)
  header:SetText("Name | Choice | Loot Item Type | Class | Armor Type | Weapon Type")
  self.resultsScroll:AddChild(header)

  local itemLink = NormalizeItemInput(self.itemLinkInput and self.itemLinkInput:GetText() or nil)
  local liveSession = nil
  if self.disableManualVotes and self.currentTestRollID and GLD.activeRolls then
    local candidate = GLD.activeRolls[self.currentTestRollID]
    if candidate and candidate.isTest then
      liveSession = candidate
    end
  end
  local liveVotes = liveSession and liveSession.votes or nil

  local function getVoteForEntry(entry)
    if not entry then
      return nil
    end
    if liveVotes then
      local key = GLD:GetRollCandidateKey(entry.name)
      return liveVotes[key] or liveVotes[entry.name]
    end
    return self.testVotes[entry.name]
  end
  local counts = { NEED = 0, GREED = 0, TRANSMOG = 0, PASS = 0 }
  local activeVoters = GetActiveVoters()
  for _, entry in ipairs(activeVoters) do
    local vote = getVoteForEntry(entry)
    if vote and counts[vote] then
      if vote == "NEED" and itemLink then
        if IsNeedAllowedForEntry(entry, itemLink) then
          counts[vote] = counts[vote] + 1
        end
      else
        counts[vote] = counts[vote] + 1
      end
    end
  end

  local summary = AceGUI:Create("Label")
  summary:SetFullWidth(true)
  summary:SetText(string.format("Need: %d | Greed: %d | Mog: %d | Pass: %d",
    counts.NEED, counts.GREED, counts.TRANSMOG, counts.PASS))
  self.resultsScroll:AddChild(summary)

  local allDone = true
  if liveSession and liveSession.expectedVoters then
    for _, key in ipairs(liveSession.expectedVoters) do
      if not (liveVotes and liveVotes[key]) then
        allDone = false
        break
      end
    end
  else
    for _, entry in ipairs(activeVoters) do
      if not getVoteForEntry(entry) then
        allDone = false
        break
      end
    end
  end

  local winnerLabel = AceGUI:Create("Label")
  winnerLabel:SetFullWidth(true)
  winnerLabel:SetText("Winner: (pending votes)")
  if allDone then
    local winner = nil
    local lootArmorType = GetArmorTypeOnly(itemLink)
    if lootArmorType == "Cloth" or lootArmorType == "Leather" or lootArmorType == "Mail" or lootArmorType == "Plate" then
      for _, entry in ipairs(activeVoters) do
        if entry.armor == lootArmorType and getVoteForEntry(entry) == "NEED" and (not itemLink or IsNeedAllowedForEntry(entry, itemLink)) then
          winner = entry.name
          break
        end
      end
    end

    if not winner and counts.NEED > 0 then
      for _, entry in ipairs(activeVoters) do
        if getVoteForEntry(entry) == "NEED" and (not itemLink or IsNeedAllowedForEntry(entry, itemLink)) then
          winner = entry.name
          break
        end
      end
    end

    if not winner and counts.GREED > 0 then
      for _, entry in ipairs(activeVoters) do
        if getVoteForEntry(entry) == "GREED" then
          winner = entry.name
          break
        end
      end
    elseif not winner and counts.TRANSMOG > 0 then
      for _, entry in ipairs(activeVoters) do
        if getVoteForEntry(entry) == "TRANSMOG" then
          winner = entry.name
          break
        end
      end
    end
    local winnerArmor = "-"
    if winner then
      for _, entry in ipairs(activeVoters) do
        if entry.name == winner then
          winnerArmor = entry.armor or "-"
          break
        end
      end
    end
    local lootTypeDetail = GetLootTypeDetailed(itemLink)
    local lootArmorType = GetArmorTypeOnly(itemLink)
    winnerLabel:SetText(string.format("Winner: %s | Armor: %s | Loot Armor: %s | Loot: %s", winner or "None", winnerArmor, lootArmorType, lootTypeDetail))

    if GLD.UI and GLD.UI.ShowRollResultPopup then
      local key = tostring(itemLink or "") .. ":" .. tostring(winner or "None")
      if self._lastTestResultKey ~= key then
        self._lastTestResultKey = key
        GLD.UI:ShowRollResultPopup({
          itemLink = itemLink,
          itemName = (itemLink and GetItemInfo(itemLink)) or nil,
          winnerName = winner or "None",
        })
      end
    end
  end
  self.resultsScroll:AddChild(winnerLabel)

  local lootType = GetLootTypeText(itemLink)
  for _, entry in ipairs(activeVoters) do
    local row = AceGUI:Create("Label")
    row:SetFullWidth(true)
    local vote = getVoteForEntry(entry) or "-"
    if vote == "NEED" and itemLink and not IsNeedAllowedForEntry(entry, itemLink) then
      vote = "NEED (ineligible)"
    end
    local nameText = entry.name or "-"
    local classText = entry.class or "-"
    local armorText = entry.armor or "-"
    local weaponText = entry.weapon or "-"
    row:SetText(string.format("%s | %s | %s | %s | %s | %s",
      nameText,
      vote,
      lootType or "-",
      classText,
      armorText,
      weaponText
    ))
    self.resultsScroll:AddChild(row)
  end
end

function TestUI:RefreshInstanceList()
  if not self.instanceSelect then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self:SetEJStatus("Encounter Journal: unavailable in combat")
    return
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
    self:SetEJStatus("Encounter Journal: loading...")
    if not self._ejDebugShown then
      self._ejDebugShown = true
      GLD:Debug("EJ not ready yet (EncounterJournal or EJ_GetNumTiers missing)")
    end
    C_Timer.After(0.2, function()
      TestUI:RefreshInstanceList()
    end)
    return
  end

  EJ_Call("SetDifficultyID", 14)

  local values = {}
  local order = {}

  local tiers = EJ_Call("GetNumTiers") or 0
  if tiers == 0 then
    self:SetEJStatus("Encounter Journal: no tiers yet")
    if not self._ejDebugShown then
      self._ejDebugShown = true
      GLD:Debug("EJ tiers = 0 (no data yet)")
    end
    C_Timer.After(0.2, function()
      TestUI:RefreshInstanceList()
    end)
    return
  end
  for tier = 1, tiers do
    EJ_Call("SelectTier", tier)
    local i = 1
    while true do
      local instanceID, name = EJ_Call("GetInstanceByIndex", i, true)
      if not instanceID then
        break
      end
      values[instanceID] = name
      table.insert(order, instanceID)
      i = i + 1
    end
  end

  self.instanceSelect:SetList(values, order)
  if #order == 0 then
    self:SetEJStatus("Encounter Journal: no raids returned")
    if not self._ejDebugShown then
      self._ejDebugShown = true
      GLD:Debug("EJ instances = 0 (no raids returned)")
    end
    C_Timer.After(0.2, function()
      TestUI:RefreshInstanceList()
    end)
    return
  end

  self:SetEJStatus("Encounter Journal: ready")

  local defaultInstanceId = nil
  for instanceId, name in pairs(values) do
    if name == DEFAULT_TEST_RAID then
      defaultInstanceId = instanceId
      break
    end
  end

  if not self.selectedInstance and (defaultInstanceId or order[1]) then
    local selected = defaultInstanceId or order[1]
    self.instanceSelect:SetValue(selected)
    self:SelectInstance(selected)
  end
end

function TestUI:SelectInstance(instanceID)
  if not instanceID then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    self:SetEJStatus("Encounter Journal: unavailable in combat")
    return
  end
  if not EncounterJournal then
    if C_AddOns and C_AddOns.LoadAddOn then
      C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
      LoadAddOn("Blizzard_EncounterJournal")
    end
  end
  if not (C_EncounterJournal and C_EncounterJournal.SelectInstance) and not _G.EJ_SelectInstance then
    self:SetEJStatus("Encounter Journal: not ready")
    return
  end
  self.selectedInstance = instanceID
  EJ_Call("SelectInstance", instanceID)

  local encounters = {}
  local order = {}
  self.encounterNameToId = {}
  self.encounterNameToIndex = {}
  self.encounterIdToIndex = {}
  local i = 1
  while true do
    local a, b, c = EJ_Call("GetEncounterInfoByIndex", i, instanceID)
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

    if type(encounterID) == "number" then
      local displayName = name or ("Encounter " .. encounterID)
      encounters[i] = displayName
      table.insert(order, i)
      if name then
        self.encounterNameToId[name] = encounterID
        self.encounterNameToIndex[name] = i
      end
      self.encounterIdToIndex[encounterID] = i
    end
    i = i + 1
  end

  self.encounterSelect:SetList(encounters, order)
  if #order == 0 then
    self:SetEJStatus("Encounter Journal: no encounters for raid")
    GLD:Debug("EJ encounters = 0 for instance " .. tostring(instanceID))
  end
  local defaultEncounterIndex = nil
  if DEFAULT_TEST_ENCOUNTER and self.encounterNameToIndex then
    defaultEncounterIndex = self.encounterNameToIndex[DEFAULT_TEST_ENCOUNTER]
  end
  if order[1] then
    local selected = defaultEncounterIndex or order[1]
    self.encounterSelect:SetValue(selected)
    self:SelectEncounter(selected)
  end
end

function TestUI:SelectEncounter(encounterID)
  if type(encounterID) == "string" and self.encounterNameToIndex then
    encounterID = self.encounterNameToIndex[encounterID] or encounterID
  end
  self.selectedEncounterIndex = encounterID
  if type(encounterID) == "number" and self.encounterIdToIndex then
    self.selectedEncounterID = nil
    for id, idx in pairs(self.encounterIdToIndex) do
      if idx == encounterID then
        self.selectedEncounterID = id
        break
      end
    end
  end
end

function TestUI:LoadEncounterLoot(retryCount)
  if not self.selectedEncounterIndex or not self.lootScroll then
    GLD:Debug("LoadLoot: missing encounter or lootScroll")
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self:SetEJStatus("Encounter Journal: unavailable in combat")
    return
  end

  local encounterIndex = self.selectedEncounterIndex
  if type(encounterIndex) ~= "number" then
    GLD:Debug("LoadLoot: invalid encounterIndex " .. tostring(self.selectedEncounterIndex))
    return
  end

  local encounterID = self.selectedEncounterID
  if type(encounterID) ~= "number" then
    GLD:Debug("LoadLoot: missing encounterID for index " .. tostring(encounterIndex))
  end

  if not EncounterJournal then
    if C_AddOns and C_AddOns.LoadAddOn then
      C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
      LoadAddOn("Blizzard_EncounterJournal")
    end
  end
  if not (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) and not _G.EJ_GetLootInfoByIndex then
    self:SetEJStatus("Encounter Journal: loot data unavailable")
    GLD:Debug("LoadLoot: EJ_GetLootInfoByIndex missing")
    return
  end

  self.lootScroll:ReleaseChildren()

  EJ_Call("SetLootFilter", 0)
  if C_EncounterJournal and C_EncounterJournal.ResetLootFilter then
    C_EncounterJournal.ResetLootFilter()
  end
  if _G.EJ_ResetLootFilter then
    _G.EJ_ResetLootFilter()
  end

  EJ_Call("SetDifficultyID", 14)
  if C_EncounterJournal and C_EncounterJournal.SetDifficultyID then
    C_EncounterJournal.SetDifficultyID(14)
  end

  if self.selectedInstance then
    EJ_Call("SelectInstance", self.selectedInstance)
  end
  if encounterID then
    EJ_Call("SelectEncounter", encounterID)
  elseif encounterIndex then
    EJ_Call("SelectEncounter", encounterIndex)
  end

  GLD:Debug("LoadLoot: encounterIndex=" .. tostring(encounterIndex) .. " encounterID=" .. tostring(encounterID))

  local function GetLootInfoByIndex(index)
    if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
      return C_EncounterJournal.GetLootInfoByIndex(index)
    end
    if _G.EJ_GetLootInfoByIndex then
      return _G.EJ_GetLootInfoByIndex(index, encounterID or encounterIndex)
    end
    return nil
  end

  local numLoot = nil
  if C_EncounterJournal and C_EncounterJournal.GetNumLoot then
    numLoot = C_EncounterJournal.GetNumLoot()
  elseif _G.EJ_GetNumLoot then
    numLoot = _G.EJ_GetNumLoot()
  end

  local index = 1
  local added = 0
  while true do
    if numLoot and index > numLoot then
      break
    end
    local itemInfo = { GetLootInfoByIndex(index) }
    local info = itemInfo[1]
    if type(info) == "table" then
      itemInfo = info
    end
    if not itemInfo[1] and type(info) ~= "table" then
      break
    end

    local itemName, itemLink, itemQuality, itemLevel, _, _, _, _, icon = unpack(itemInfo)
    if type(info) == "table" then
      itemName = info.name or itemName
      itemLink = info.link or info.itemLink or itemLink
      itemLevel = info.itemLevel or itemLevel
      icon = info.icon or info.texture or icon
    end
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local iconButton = AceGUI:Create("Icon")
    iconButton:SetImage(icon)
    iconButton:SetImageSize(20, 20)
    iconButton:SetWidth(24)
    iconButton:SetHeight(24)
    iconButton:SetCallback("OnEnter", function()
      if itemLink then
        GameTooltip:SetOwner(iconButton.frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
      end
    end)
    iconButton:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)
    iconButton:SetCallback("OnClick", function()
      if itemLink then
        self:SetSelectedItemLink(itemLink)
      end
    end)
    row:AddChild(iconButton)

    local nameLabel = AceGUI:Create("InteractiveLabel")
    local labelText = tostring(itemLink or itemName or "Unknown Item")
    if itemLevel then
      labelText = string.format("%s |cff999999(ilvl %s)|r", labelText, itemLevel)
    end
    nameLabel:SetText(labelText)
    nameLabel:SetWidth(220)
    nameLabel:SetCallback("OnEnter", function()
      if itemLink then
        GameTooltip:SetOwner(nameLabel.frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
      end
    end)
    nameLabel:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)
    nameLabel:SetCallback("OnClick", function()
      if itemLink then
        self:SetSelectedItemLink(itemLink)
      end
    end)
    row:AddChild(nameLabel)

    self.lootScroll:AddChild(row)
    added = added + 1

    index = index + 1
  end

  GLD:Debug("LoadLoot: items added=" .. tostring(added))

  retryCount = retryCount or 0
  if added == 0 and retryCount < 5 then
    GLD:Debug("LoadLoot: no items yet, retrying " .. tostring(retryCount + 1))
    C_Timer.After(0.3, function()
      TestUI:LoadEncounterLoot(retryCount + 1)
    end)
  end
end

function TestUI:SimulateLootRoll(itemLink)
  local activeVoters = GetActiveVoters()
  if (self.currentVoterIndex or 0) > (#activeVoters - 1) then
    GLD:Print("All test voters completed. Use Reset Votes to start again.")
    return
  end
  if not itemLink or itemLink == "" then
    GLD:Print("Please enter an item link")
    return
  end

  local normalized = NormalizeItemInput(itemLink)
  if not normalized then
    GLD:Print("Please enter an item link")
    return
  end

  if normalized:find("^item:%d+") then
    GLD:RequestItemData(normalized)
  elseif normalized:find("|Hitem:") then
    GLD:RequestItemData(normalized)
  end

  local name, link, quality = GetItemInfo(normalized)
  local displayLink = link or normalized
  local displayName = name or "Test Item"

  local voterEntry = GetTestVoter((self.currentVoterIndex or 0) + 1)
  local canNeed = true
  if voterEntry and voterEntry.class then
    canNeed = IsNeedAllowedForEntry(voterEntry, normalized)
  end

  local rollID = math.random(1, 10000)
  local rollTime = 120

  local session = {
    rollID = rollID,
    rollTime = rollTime,
    itemLink = displayLink,
    itemName = displayName,
    quality = quality or 4,
    canNeed = canNeed,
    canGreed = true,
    canTransmog = true,
    votes = {},
    expectedVoters = GLD:BuildExpectedVoters(),
    isTest = true,
  }

  GLD.activeRolls[rollID] = session
  self.currentTestRollID = rollID

  if GLD.UI then
    local voter = nil
    if IsInGroup() or IsInRaid() then
      local name, realm = UnitName("player")
      if name then
        voter = realm and realm ~= "" and (name .. "-" .. realm) or name
      end
    end
    if not voter then
      voter = GetTestVoterName((self.currentVoterIndex or 0) + 1) or "Test Player"
    end
    session.testVoterName = voter
    GLD.UI:ShowRollPopup(session)
    if GLD.UI.ShowPendingFrame then
      GLD.UI:ShowPendingFrame()
    end
  end

  if IsInRaid() or IsInGroup() then
    local channel = IsInRaid() and "RAID" or "PARTY"
    GLD:SendCommMessageSafe(NS.MSG.ROLL_SESSION, {
      rollID = rollID,
      rollTime = rollTime * 1000,
      itemLink = displayLink,
      itemName = displayName,
      quality = session.quality,
      canNeed = canNeed,
      canGreed = true,
      canTransmog = true,
      test = true,
    }, channel)
  end

  GLD:Print("Simulated loot roll: " .. displayLink)
end

function TestUI:AdvanceTestVoter()
  self.currentVoterIndex = (self.currentVoterIndex or 0) + 1
  local activeVoters = GetActiveVoters()
  if self.currentVoterIndex > (#activeVoters - 1) then
    self.currentVoterIndex = #activeVoters
  end
  self:RefreshVotePanel()
  self:RefreshResultsPanel()
  if self.currentVoterIndex <= (#activeVoters - 1) then
    if self.itemLinkInput then
      self:SimulateLootRoll(self.itemLinkInput:GetText())
    end
  end
end
