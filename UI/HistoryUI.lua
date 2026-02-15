local _, NS = ...

local GLD = NS.GLD
local UI = NS.UI
local AceGUI = LibStub("AceGUI-3.0", true)

local function FormatDateTime(ts)
  if not ts or ts == 0 then
    return "-"
  end
  return date("%Y-%m-%d %H:%M", ts)
end

local function FormatDuration(startedAt, endedAt)
  if not startedAt or startedAt == 0 then
    return "-"
  end
  local finish = endedAt and endedAt > 0 and endedAt or GetServerTime()
  local total = math.max(0, finish - startedAt)
  local hours = math.floor(total / 3600)
  local mins = math.floor((total % 3600) / 60)
  return string.format("%dh %dm", hours, mins)
end

local function NormalizeHistoryName(name)
  if not name then
    return ""
  end
  if type(name) == "string" and name:match("^Player%-") then
    return name:lower()
  end
  local base = NS and NS.GetPlayerBaseName and NS:GetPlayerBaseName(name) or name
  return tostring(base or ""):lower()
end

local function GetHistoryPlayerEntry(name, key)
  if not GLD or not GLD.db or not GLD.db.players then
    return nil
  end
  local playerKey = key
  if not playerKey and name and GLD.FindPlayerKeyByName and NS and NS.SplitNameRealm then
    local base, realm = NS:SplitNameRealm(name)
    if base then
      playerKey = GLD:FindPlayerKeyByName(base, realm)
    end
  end
  if playerKey and GLD.db.players[playerKey] then
    return GLD.db.players[playerKey], playerKey
  end
  return nil
end

local function GetHistoryDisplayName(name, key, isGuestOverride)
  if not name or name == "" then
    return "?"
  end
  if type(name) == "string" and name:match("^Player%-") then
    return name
  end
  if name == "Unclaimed" or name == "None" then
    return name
  end
  local player = GetHistoryPlayerEntry(name, key)
  local isGuest = isGuestOverride == true
  if isGuestOverride == nil and player and GLD and GLD.IsGuestEntry then
    isGuest = GLD:IsGuestEntry(player)
  end
  if NS and NS.GetPlayerDisplayName then
    return NS:GetPlayerDisplayName(name, isGuest)
  end
  return name
end

local function NamesMatch(a, b)
  return NormalizeHistoryName(a) == NormalizeHistoryName(b)
end

local VOTE_TYPES = { "NEED", "GREED", "TRANSMOG", "PASS" }
local VOTE_LABELS = {
  NEED = "Need",
  GREED = "Greed",
  TRANSMOG = "Transmog",
  PASS = "Pass",
}

local function HighlightRollNumber(roll)
  if roll == nil then
    return nil
  end
  return "|cffffd200" .. tostring(roll) .. "|r"
end

local function ResolveWinnerVote(item)
  if item and item.winnerVote then
    return item.winnerVote
  end
  if item and item.winnerName and item.votes then
    return item.votes[item.winnerName]
  end
  return nil
end

local function IsLostHistoryItem(item)
  if not item then
    return false
  end
  local reason = item.resolutionReason and tostring(item.resolutionReason):upper() or nil
  local status = item.rollStatus and tostring(item.rollStatus):upper() or nil
  return reason == "LOST" or status == "LOST"
end

local function BuildVoteCounts(entry)
  local counts = { NEED = 0, GREED = 0, TRANSMOG = 0, PASS = 0 }
  if entry and entry.voteCounts then
    for key, value in pairs(entry.voteCounts) do
      if counts[key] ~= nil then
        counts[key] = tonumber(value) or 0
      end
    end
    return counts
  end
  if entry and entry.votes then
    for _, vote in pairs(entry.votes) do
      if counts[vote] ~= nil then
        counts[vote] = counts[vote] + 1
      end
    end
  end
  return counts
end

local function BuildVoteGroups(entry)
  local groups = { NEED = {}, GREED = {}, TRANSMOG = {}, PASS = {} }
  if entry and entry.votes then
    for voter, vote in pairs(entry.votes) do
      if groups[vote] then
        table.insert(groups[vote], voter)
      end
    end
  end
  for _, voteType in ipairs(VOTE_TYPES) do
    table.sort(groups[voteType], function(a, b)
      return tostring(a) < tostring(b)
    end)
  end
  return groups
end

local function BuildHistoryLootKey(sessionId, item, index, section)
  local base = item and (item.rollID or item.itemLink or item.itemName) or "loot"
  local tag = section and ("|" .. tostring(section)) or ""
  return tostring(sessionId or "") .. ":" .. tostring(base) .. tag .. ":" .. tostring(index or 0)
end

local function ToggleHistoryLootEntry(self, key)
  self.historyExpandedLoot = self.historyExpandedLoot or {}
  self.historyExpandedLoot[key] = not self.historyExpandedLoot[key]
end

local function IsHistoryLootExpanded(self, key)
  return self.historyExpandedLoot and self.historyExpandedLoot[key] or false
end

local function GetUniqueValues(list, field)
  local values = { ALL = "All" }
  local seen = {}
  for _, entry in ipairs(list or {}) do
    local val = entry[field]
    if val and val ~= "" and not seen[val] then
      seen[val] = true
      values[val] = val
    end
  end
  return values
end

local function AddHistoryVoteDetails(self, item)
  if not self.historyDetailScroll then
    return
  end
  local hasDetails = item and (item.votes ~= nil or item.voteCounts ~= nil or item.voteDetails ~= nil)
  if not hasDetails then
    local none = AceGUI:Create("Label")
    none:SetFullWidth(true)
    none:SetText("  Vote details not recorded.")
    self.historyDetailScroll:AddChild(none)
    return
  end

  local counts = BuildVoteCounts(item)
  local totals = AceGUI:Create("Label")
  totals:SetFullWidth(true)
  totals:SetText(string.format("  Totals: Need %d | Greed %d | Transmog %d | Pass %d",
    counts.NEED, counts.GREED, counts.TRANSMOG, counts.PASS))
  self.historyDetailScroll:AddChild(totals)

  local winnerVote = ResolveWinnerVote(item)
  for _, voteType in ipairs(VOTE_TYPES) do
    local entries = GLD and GLD.BuildResultVoteEntries and GLD:BuildResultVoteEntries(item, voteType) or nil
    local listText = "none"
    if entries and #entries > 0 then
      local parts = {}
      for _, entry in ipairs(entries) do
        local rawName = entry.name or "?"
        local displayName = GetHistoryDisplayName(rawName)
        local rollText = entry.roll ~= nil and tostring(entry.roll) or nil
        if rollText and NamesMatch(item.winnerName, rawName) and winnerVote == voteType then
          rollText = HighlightRollNumber(entry.roll)
        end
        local label = displayName
        if rollText then
          label = label .. " " .. rollText
        end
        local orig = entry.voteOriginal or entry.voteEffective
        local eff = entry.voteEffective or entry.voteOriginal
        if orig or eff then
          label = label .. " (" .. tostring(orig or "?") .. "->" .. tostring(eff or "?")
          local reason = entry.reasonText or entry.reason
          if reason and reason ~= "" then
            label = label .. ": " .. tostring(reason)
          end
          label = label .. ")"
        end
        parts[#parts + 1] = label
      end
      listText = table.concat(parts, ", ")
    end
    local row = AceGUI:Create("Label")
    row:SetFullWidth(true)
    row:SetText(string.format("  %s: %s", VOTE_LABELS[voteType] or voteType, listText))
    self.historyDetailScroll:AddChild(row)
  end

  local instructionLine = GLD and GLD.BuildRollResultInstructionLine and GLD:BuildRollResultInstructionLine(item) or nil
  if item.instructionText then
    local voteText = item.winnerVote or "ROLL"
    local displayWinner = GetHistoryDisplayName(item.winnerName, item.winnerKey, item.winnerIsGuest)
    instructionLine = "Winner via " .. tostring(voteText) .. ": " .. tostring(displayWinner) .. " - " .. tostring(item.instructionText)
  end
  if instructionLine then
    local instruction = AceGUI:Create("Label")
    instruction:SetFullWidth(true)
    instruction:SetText("  " .. tostring(instructionLine))
    self.historyDetailScroll:AddChild(instruction)
  end

  if item.missingAtLock and #item.missingAtLock > 0 then
    local missing = AceGUI:Create("Label")
    missing:SetFullWidth(true)
    local names = {}
    for _, name in ipairs(item.missingAtLock) do
      names[#names + 1] = GetHistoryDisplayName(name)
    end
    missing:SetText("  Missing at lock: " .. table.concat(names, ", "))
    self.historyDetailScroll:AddChild(missing)
  end
end

local function AddHistoryLootEntry(self, item, entryKey)
  if not self.historyDetailScroll then
    return
  end
  local expanded = IsHistoryLootExpanded(self, entryKey)

  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")

  local toggleBtn = AceGUI:Create("Button")
  toggleBtn:SetText(expanded and "-" or "+")
  toggleBtn:SetWidth(24)
  toggleBtn:SetCallback("OnClick", function()
    ToggleHistoryLootEntry(self, entryKey)
    self:RefreshHistoryDetails()
  end)
  row:AddChild(toggleBtn)

  local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  if item.itemLink then
    local itemIcon = select(10, GetItemInfo(item.itemLink))
    if itemIcon then
      icon = itemIcon
    else
      GLD:RequestItemData(item.itemLink)
    end
  end

  local iconWidget = AceGUI:Create("Icon")
  iconWidget:SetImage(icon)
  iconWidget:SetImageSize(20, 20)
  iconWidget:SetWidth(24)
  iconWidget:SetHeight(24)
  iconWidget:SetCallback("OnEnter", function()
    local link = item.itemLink
    if link and link ~= "" then
      GameTooltip:SetOwner(iconWidget.frame, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end)
  iconWidget:SetCallback("OnLeave", function()
    GameTooltip:Hide()
  end)
  iconWidget:SetCallback("OnClick", function()
    ToggleHistoryLootEntry(self, entryKey)
    self:RefreshHistoryDetails()
  end)
  row:AddChild(iconWidget)

  local itemLabel = AceGUI:Create("InteractiveLabel")
  itemLabel:SetWidth(220)
  itemLabel:SetText(item.itemLink or item.itemName or "Unknown Item")
  itemLabel:SetCallback("OnEnter", function()
    local link = item.itemLink
    if link and link ~= "" then
      GameTooltip:SetOwner(itemLabel.frame, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end)
  itemLabel:SetCallback("OnLeave", function()
    GameTooltip:Hide()
  end)
  itemLabel:SetCallback("OnClick", function()
    ToggleHistoryLootEntry(self, entryKey)
    self:RefreshHistoryDetails()
  end)
  row:AddChild(itemLabel)

  local winnerLabel = AceGUI:Create("InteractiveLabel")
  winnerLabel:SetWidth(160)
  local displayWinner = GetHistoryDisplayName(item.winnerName or "None", item.winnerKey, item.winnerIsGuest)
  if IsLostHistoryItem(item) then
    winnerLabel:SetText("Winner: LOST/VOID")
  else
    winnerLabel:SetText("Winner: " .. tostring(displayWinner))
  end
  winnerLabel:SetCallback("OnClick", function()
    ToggleHistoryLootEntry(self, entryKey)
    self:RefreshHistoryDetails()
  end)
  row:AddChild(winnerLabel)

  self.historyDetailScroll:AddChild(row)

  if expanded then
    AddHistoryVoteDetails(self, item)
  end
end

function UI:ToggleHistory()
  if not AceGUI then
    return
  end
  if not GLD.CanAccessAdminUI or not GLD:CanAccessAdminUI() then
    GLD:ShowPermissionDeniedPopup()
    return
  end
  local created = false
  if not self.historyFrame then
    self:CreateHistoryFrame()
    created = true
  end
  if not self.historyFrame then
    return
  end
  if created or not self.historyFrame:IsShown() then
    self.historyFrame:Show()
    self:RefreshHistoryList()
    self:RefreshHistoryDetails()
  else
    self.historyFrame:Hide()
  end
end

function UI:CreateHistoryFrame()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Raid Session History")
  frame:SetStatusText("Browse raid nights, bosses, and loot")
  frame:SetWidth(900)
  frame:SetHeight(560)
  frame:SetLayout("Flow")
  frame:EnableResize(true)

  local filters = AceGUI:Create("SimpleGroup")
  filters:SetFullWidth(true)
  filters:SetLayout("Flow")

  local raidFilter = AceGUI:Create("Dropdown")
  raidFilter:SetLabel("Raid")
  raidFilter:SetWidth(200)
  raidFilter:SetList({ ALL = "All" })
  raidFilter:SetValue("ALL")
  filters:AddChild(raidFilter)

  local diffFilter = AceGUI:Create("Dropdown")
  diffFilter:SetLabel("Difficulty")
  diffFilter:SetWidth(160)
  diffFilter:SetList({ ALL = "All" })
  diffFilter:SetValue("ALL")
  filters:AddChild(diffFilter)

  local rangeFilter = AceGUI:Create("Dropdown")
  rangeFilter:SetLabel("Date Range")
  rangeFilter:SetWidth(140)
  rangeFilter:SetList({ ALL = "All", D7 = "Last 7 days", D30 = "Last 30 days", D90 = "Last 90 days" })
  rangeFilter:SetValue("ALL")
  filters:AddChild(rangeFilter)

  frame:AddChild(filters)

  local tree = AceGUI:Create("TreeGroup")
  tree:SetFullWidth(true)
  tree:SetFullHeight(true)
  tree:SetLayout("Fill")
  if tree.EnableTreeResizing then
    tree:EnableTreeResizing(false)
  end
  if tree.SetTreeWidth then
    tree:SetTreeWidth(320, false)
  end
  if tree.EnableButtonTooltips then
    tree:EnableButtonTooltips(false)
  end
  tree:SetCallback("OnGroupSelected", function(_, _, value)
    self.historySelectedId = value
    self:RefreshHistoryDetails()
  end)
  frame:AddChild(tree)

  raidFilter:SetCallback("OnValueChanged", function(_, _, value)
    self.historyRaidFilter = value
    self:RefreshHistoryList()
  end)

  diffFilter:SetCallback("OnValueChanged", function(_, _, value)
    self.historyDiffFilter = value
    self:RefreshHistoryList()
  end)

  rangeFilter:SetCallback("OnValueChanged", function(_, _, value)
    self.historyRangeFilter = value
    self:RefreshHistoryList()
  end)

  self.historyFrame = frame
  self.historyTree = tree
  self.historyDetailScroll = nil
  self.historySelectedId = nil
  self.historyRaidFilter = "ALL"
  self.historyDiffFilter = "ALL"
  self.historyRangeFilter = "ALL"
  self.historyRaidFilterWidget = raidFilter
  self.historyDiffFilterWidget = diffFilter
  self.historyRangeFilterWidget = rangeFilter
end

function UI:RefreshHistoryIfOpen()
  if not self.historyFrame or not self.historyFrame:IsShown() then
    return
  end
  self:RefreshHistoryList()
  self:RefreshHistoryDetails()
end

function UI:RefreshHistoryList()
  if not self.historyTree then
    return
  end

  local sessions = GLD.db.raidSessions or {}

  if self.historyRaidFilterWidget then
    self.historyRaidFilterWidget:SetList(GetUniqueValues(sessions, "raidName"))
  end
  if self.historyDiffFilterWidget then
    self.historyDiffFilterWidget:SetList(GetUniqueValues(sessions, "difficultyName"))
  end

  local cutoff = nil
  if self.historyRangeFilter == "D7" then
    cutoff = GetServerTime() - (7 * 24 * 60 * 60)
  elseif self.historyRangeFilter == "D30" then
    cutoff = GetServerTime() - (30 * 24 * 60 * 60)
  elseif self.historyRangeFilter == "D90" then
    cutoff = GetServerTime() - (90 * 24 * 60 * 60)
  end

  local treeData = {}
  local firstMatch = nil
  local selectedStillValid = false
  local maxLabelWidth = 0
  for _, entry in ipairs(sessions) do
    local raidOk = self.historyRaidFilter == "ALL" or entry.raidName == self.historyRaidFilter
    local diffOk = self.historyDiffFilter == "ALL" or entry.difficultyName == self.historyDiffFilter
    local dateOk = not cutoff or (entry.startedAt or 0) >= cutoff
    if raidOk and diffOk and dateOk then
      if not firstMatch then
        firstMatch = entry.id
      end
      if self.historySelectedId == entry.id then
        selectedStillValid = true
      end
      local label = string.format("%s - %s - %s - %s",
        FormatDateTime(entry.startedAt),
        entry.raidName or "Unknown",
        entry.difficultyName or "-",
        FormatDuration(entry.startedAt, entry.endedAt)
      )
      treeData[#treeData + 1] = { value = entry.id, text = label }
      if self.historyTree and self.historyTree.frame then
        if not self._historyMeasure then
          local fs = self.historyTree.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          fs:SetText("")
          self._historyMeasure = fs
        end
        if self._historyMeasure then
          self._historyMeasure:SetText(label)
          local w = self._historyMeasure:GetStringWidth() or 0
          if w > maxLabelWidth then
            maxLabelWidth = w
          end
        end
      end
    end
  end

  self.historyTree:SetTree(treeData)
  if self.historyTree.SetTreeWidth and maxLabelWidth > 0 then
    local padding = 60
    local width = math.floor(maxLabelWidth + padding)
    width = math.max(220, math.min(520, width))
    self.historyTree:SetTreeWidth(width, false)
  end

  if not firstMatch then
    self.historySelectedId = nil
    self:RefreshHistoryDetails()
    return
  end

  if not selectedStillValid then
    self.historySelectedId = nil
  end
  if self.historySelectedId then
    self.historyTree:Select(self.historySelectedId)
  elseif firstMatch then
    self.historySelectedId = firstMatch
    self.historyTree:Select(firstMatch)
  end
end

function UI:RefreshHistoryDetails()
  if not self.historyTree then
    return
  end

  self.historyTree:ReleaseChildren()

  local detailScroll = AceGUI:Create("ScrollFrame")
  detailScroll:SetLayout("Flow")
  detailScroll:SetFullWidth(true)
  detailScroll:SetFullHeight(true)
  self.historyTree:AddChild(detailScroll)
  self.historyDetailScroll = detailScroll

  local selected = nil
  for _, entry in ipairs(GLD.db.raidSessions or {}) do
    if entry.id == self.historySelectedId then
      selected = entry
      break
    end
  end

  if not selected then
    local empty = AceGUI:Create("Label")
    empty:SetFullWidth(true)
    empty:SetText("Select a session on the left to view details.")
    detailScroll:AddChild(empty)
    return
  end

  local header = AceGUI:Create("Heading")
  header:SetFullWidth(true)
  header:SetText((selected.raidName or "Unknown") .. " - " .. (selected.difficultyName or "-") )
  detailScroll:AddChild(header)

  local meta = AceGUI:Create("Label")
  meta:SetFullWidth(true)
  meta:SetText(string.format("Start: %s | End: %s | Duration: %s",
    FormatDateTime(selected.startedAt),
    FormatDateTime(selected.endedAt),
    FormatDuration(selected.startedAt, selected.endedAt)
  ))
  detailScroll:AddChild(meta)

  local copyBtn = AceGUI:Create("Button")
  copyBtn:SetText("Copy Summary")
  copyBtn:SetWidth(140)
  copyBtn:SetCallback("OnClick", function()
    self:ShowHistorySummaryPopup(selected)
  end)
  detailScroll:AddChild(copyBtn)

  local bosses = selected.bosses or {}
  if #bosses == 0 then
    local none = AceGUI:Create("Label")
    none:SetFullWidth(true)
    none:SetText("No boss kills logged for this session.")
    detailScroll:AddChild(none)
  end

  for _, boss in ipairs(bosses) do
    local bossHeader = AceGUI:Create("Heading")
    bossHeader:SetFullWidth(true)
    bossHeader:SetText((boss.encounterName or "Boss") .. " - " .. FormatDateTime(boss.killedAt))
    detailScroll:AddChild(bossHeader)

    local loot = boss.loot or {}
    if #loot == 0 then
      local none = AceGUI:Create("Label")
      none:SetFullWidth(true)
      none:SetText("No loot recorded for this boss.")
      detailScroll:AddChild(none)
    else
      local bossKey = boss.encounterID or boss.encounterId or boss.encounterName or boss.killedAt or "boss"
      for idx, item in ipairs(loot) do
        local entryKey = BuildHistoryLootKey(selected.id, item, idx, bossKey)
        AddHistoryLootEntry(self, item, entryKey)
      end
    end
  end

  local looseLoot = {}
  for _, item in ipairs(selected.loot or {}) do
    local assigned = false
    for _, boss in ipairs(bosses) do
      for _, bossItem in ipairs(boss.loot or {}) do
        if bossItem.rollID == item.rollID then
          assigned = true
          break
        end
      end
      if assigned then
        break
      end
    end
    if not assigned then
      looseLoot[#looseLoot + 1] = item
    end
  end

  if #looseLoot > 0 then
    local looseHeader = AceGUI:Create("Heading")
    looseHeader:SetFullWidth(true)
    looseHeader:SetText("Session Loot (unassigned)")
    detailScroll:AddChild(looseHeader)

    for idx, item in ipairs(looseLoot) do
      local entryKey = BuildHistoryLootKey(selected.id, item, idx, "loose")
      AddHistoryLootEntry(self, item, entryKey)
    end
  end
end

function UI:ShowHistorySummaryPopup(session)
  if not AceGUI or not session then
    return
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Session Summary")
  frame:SetStatusText(session.raidName or "Raid")
  frame:SetWidth(520)
  frame:SetHeight(360)
  frame:SetLayout("Fill")
  frame:EnableResize(true)

  local box = AceGUI:Create("MultiLineEditBox")
  box:SetLabel("Copy this summary")
  box:SetFullWidth(true)
  box:SetFullHeight(true)
  box:DisableButton(true)

  local lines = {}
  lines[#lines + 1] = string.format("Raid: %s (%s)", session.raidName or "Unknown", session.difficultyName or "-")
  lines[#lines + 1] = string.format("Start: %s", FormatDateTime(session.startedAt))
  lines[#lines + 1] = string.format("End: %s", FormatDateTime(session.endedAt))
  lines[#lines + 1] = string.format("Duration: %s", FormatDuration(session.startedAt, session.endedAt))
  lines[#lines + 1] = ""

  local hasBosses = #((session.bosses) or {}) > 0
  for _, boss in ipairs(session.bosses or {}) do
    lines[#lines + 1] = string.format("Boss: %s (%s)", boss.encounterName or "Boss", FormatDateTime(boss.killedAt))
    for _, item in ipairs(boss.loot or {}) do
      local displayWinner = GetHistoryDisplayName(item.winnerName or "None", item.winnerKey, item.winnerIsGuest)
      if IsLostHistoryItem(item) then
        lines[#lines + 1] = string.format("  - %s -> LOST/VOID", item.itemName or item.itemLink or "Unknown Item")
      else
        lines[#lines + 1] = string.format("  - %s -> %s", item.itemName or item.itemLink or "Unknown Item", displayWinner)
      end
    end
  end

  if not hasBosses then
    lines[#lines + 1] = "No boss kills or loot recorded."
  end

  box:SetText(table.concat(lines, "\n"))
  frame:AddChild(box)
end
