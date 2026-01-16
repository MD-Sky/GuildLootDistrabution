local _, NS = ...

local GLD = NS.GLD

function GLD:InitLoot()
  self.activeRolls = {}
  self:RegisterEvent("START_LOOT_ROLL", "OnStartLootRoll")
end

local function RollTypeToVote(rollType)
  if rollType == LOOT_ROLL_TYPE_NEED then
    return "NEED"
  end
  if rollType == LOOT_ROLL_TYPE_GREED then
    return "GREED"
  end
  if rollType == LOOT_ROLL_TYPE_PASS then
    return "PASS"
  end
  if LOOT_ROLL_TYPE_TRANSMOG and rollType == LOOT_ROLL_TYPE_TRANSMOG then
    return "TRANSMOG"
  end
  return nil
end

function GLD:BuildExpectedVoters()
  local list = {}
  local seen = {}

  local function addUnit(unit)
    if not UnitExists(unit) or not UnitIsConnected(unit) then
      return
    end
    local key = NS:GetPlayerKeyFromUnit(unit)
    if key and not seen[key] then
      table.insert(list, key)
      seen[key] = true
    end
  end

  if IsInRaid() then
    local count = GetNumGroupMembers()
    for i = 1, count do
      addUnit("raid" .. i)
    end
  elseif IsInGroup() then
    local count = GetNumSubgroupMembers()
    for i = 1, count do
      addUnit("party" .. i)
    end
    addUnit("player")
  else
    addUnit("player")
  end

  return list
end

function GLD:FindPlayerKeyByName(name, realm)
  if not name then
    return nil
  end
  local realmName = realm and realm ~= "" and realm or GetRealmName()
  for key, player in pairs(self.db.players or {}) do
    if player and player.name == name and (player.realm == realmName or not player.realm) then
      return key
    end
  end
  return nil
end

function GLD:GetRollCandidateKey(sender)
  if not sender then
    return nil
  end
  local name, realm = NS:SplitNameRealm(sender)
  return self:FindPlayerKeyByName(name, realm) or sender
end

function GLD:AnnounceRollResult(result)
  if not result then
    return
  end
  local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "SAY")
  local winnerName = result.winnerName or "None"
  local itemText = result.itemLink or result.itemName or "Item"
  local msg = string.format("GLD Result: %s -> %s", itemText, winnerName)
  SendChatMessage(msg, channel)
end

function GLD:RecordRollHistory(result)
  if not result then
    return
  end
  self.db.rollHistory = self.db.rollHistory or {}
  table.insert(self.db.rollHistory, 1, result)
  if #self.db.rollHistory > 200 then
    table.remove(self.db.rollHistory)
  end
end

function GLD:ResolveRollWinner(session)
  if not session or session.locked then
    return nil
  end
  local votes = session.votes or {}
  local priority = { "NEED", "GREED", "TRANSMOG" }

  local function queuePosFor(key)
    local player = self.db.players and self.db.players[key] or nil
    if player and player.queuePos then
      return player.queuePos
    end
    return 99999
  end

  local function nameFor(key)
    local player = self.db.players and self.db.players[key] or nil
    if player and player.name then
      if player.realm and player.realm ~= "" then
        return player.name .. "-" .. player.realm
      end
      return player.name
    end
    return key
  end

  for _, voteType in ipairs(priority) do
    local winnerKey = nil
    local bestPos = nil
    local bestName = nil
    for key, vote in pairs(votes) do
      if vote == voteType then
        local pos = queuePosFor(key)
        local nm = nameFor(key) or ""
        if not winnerKey or pos < bestPos or (pos == bestPos and nm < (bestName or "~")) then
          winnerKey = key
          bestPos = pos
          bestName = nm
        end
      end
    end
    if winnerKey then
      return winnerKey
    end
  end
  return nil
end

function GLD:FinalizeRoll(session)
  if not session or session.locked then
    return
  end
  local winnerKey = self:ResolveRollWinner(session)
  local winnerPlayer = winnerKey and self.db.players and self.db.players[winnerKey] or nil
  local winnerName = winnerPlayer and winnerPlayer.name or (winnerKey or "None")
  local winnerFull = winnerName
  if winnerPlayer and winnerPlayer.realm and winnerPlayer.realm ~= "" then
    winnerFull = winnerPlayer.name .. "-" .. winnerPlayer.realm
  end

  local result = {
    rollID = session.rollID,
    itemLink = session.itemLink,
    itemName = session.itemName,
    winnerKey = winnerKey,
    winnerName = winnerFull,
    votes = session.votes or {},
    resolvedAt = GetServerTime(),
  }

  session.locked = true
  session.result = result

  self:RecordRollHistory(result)
  if self:IsAuthority() then
    self:AnnounceRollResult(result)
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "SAY")
    self:SendCommMessageSafe(NS.MSG.ROLL_RESULT, result, channel)
  end
end

function GLD:CheckRollCompletion(session)
  if not session or session.locked then
    return
  end
  local expected = session.expectedVoters or {}
  local votes = session.votes or {}
  local count = 0
  for _, key in ipairs(expected) do
    if votes[key] then
      count = count + 1
    end
  end
  if count >= #expected and #expected > 0 then
    self:FinalizeRoll(session)
  end
end

function GLD:NoteMismatch(session, playerName, expectedVote, actualVote)
  if not session then
    return
  end
  session.mismatches = session.mismatches or {}
  table.insert(session.mismatches, {
    name = playerName,
    expected = expectedVote,
    actual = actualVote,
  })
  if self:IsAuthority() then
    local msg = string.format("GLD mismatch: %s declared %s but rolled %s", tostring(playerName), tostring(expectedVote), tostring(actualVote))
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "SAY")
    SendChatMessage(msg, channel)
    self:SendCommMessageSafe(NS.MSG.ROLL_MISMATCH, {
      rollID = session.rollID,
      name = playerName,
      expected = expectedVote,
      actual = actualVote,
    }, channel)
  end
end

function GLD:OnStartLootRoll(rollID, rollTime, lootHandle)
  local texture, name, count, quality, bop, canNeed, canGreed, canDE, canTransmog, reason = GetLootRollItemInfo(rollID)
  local link = GetLootRollItemLink(rollID)

  local session = {
    rollID = rollID,
    rollTime = rollTime,
    itemLink = link,
    itemName = name,
    quality = quality,
    canNeed = canNeed,
    canGreed = canGreed,
    canTransmog = canTransmog,
    votes = {},
    expectedVoters = self:BuildExpectedVoters(),
    createdAt = GetServerTime(),
  }
  self.activeRolls[rollID] = session

  if link then
    self:RequestItemData(link)
  end

  if self.UI then
    self.UI:ShowRollPopup(session)
    if self.UI.ShowPendingFrame then
      self.UI:ShowPendingFrame()
    end
  end

  if not self:IsAuthority() then
    local authority = self:GetAuthorityName()
    if authority then
      self:SendCommMessageSafe(NS.MSG.ROLL_SESSION, {
        rollID = rollID,
        rollTime = rollTime,
        itemLink = link,
        itemName = name,
        canNeed = canNeed,
        canGreed = canGreed,
        canTransmog = canTransmog,
      }, "WHISPER", authority)
    end
  else
    local delay = (tonumber(rollTime) or 120000) / 1000
    C_Timer.After(delay, function()
      local active = self.activeRolls and self.activeRolls[rollID]
      if active and not active.locked then
        self:FinalizeRoll(active)
      end
    end)
  end

  local delay = (tonumber(rollTime) or 120000) / 1000
  C_Timer.After(delay + 1, function()
    self:OnLootHistoryRollChanged()
  end)
  C_Timer.After(delay + 6, function()
    self:OnLootHistoryRollChanged()
  end)
end

function GLD:OnLootHistoryRollChanged()
  if not C_LootHistory or not C_LootHistory.GetItem then
    return
  end
  local numItems = C_LootHistory.GetNumItems and C_LootHistory.GetNumItems() or 0
  if numItems <= 0 then
    return
  end
  for itemIndex = 1, numItems do
    local lootID, itemLink, itemQuality, itemGUID, numPlayers = C_LootHistory.GetItem(itemIndex)
    if itemLink and numPlayers and numPlayers > 0 then
      for rollID, session in pairs(self.activeRolls) do
        if session and session.itemLink == itemLink and session.votes then
          for playerIndex = 1, numPlayers do
            local name, class, rollType = C_LootHistory.GetPlayerInfo(itemIndex, playerIndex)
            local declaredKey = self:GetRollCandidateKey(name)
            local declaredVote = declaredKey and session.votes[declaredKey] or nil
            local actualVote = RollTypeToVote(rollType)
            if declaredVote and actualVote and declaredVote ~= actualVote then
              self:NoteMismatch(session, name, declaredVote, actualVote)
            end
          end
        end
      end
    end
  end
end
