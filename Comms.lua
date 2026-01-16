local _, NS = ...

local GLD = NS.GLD

local function HashString(input)
  local hash = 5381
  local str = tostring(input or "")
  for i = 1, #str do
    hash = ((hash * 33) + str:byte(i)) % 4294967296
  end
  return hash
end

local function StableStringify(value, depth)
  depth = (depth or 0) + 1
  if depth > 10 then
    return "<maxdepth>"
  end
  local t = type(value)
  if t == "table" then
    local keys = {}
    for k in pairs(value) do
      table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
      return tostring(a) < tostring(b)
    end)
    local parts = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = tostring(k) .. "=" .. StableStringify(value[k], depth)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(value)
end

function GLD:ComputeRosterHashFromSnapshot(roster)
  if not roster then
    return nil
  end
  local keys = {}
  local entries = {}
  for _, entry in ipairs(roster) do
    local key = entry.key or (entry.name and (entry.name .. "-" .. (entry.realm or ""))) or ""
    keys[#keys + 1] = key
    entries[key] = entry
  end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    local entry = entries[key]
    parts[#parts + 1] = table.concat({
      key,
      tostring(entry.name or ""),
      tostring(entry.realm or ""),
      tostring(entry.class or ""),
      tostring(entry.attendance or ""),
      tostring(entry.queuePos or ""),
      tostring(entry.savedPos or ""),
      tostring(entry.numAccepted or ""),
      tostring(entry.attendanceCount or ""),
    }, "|")
  end
  return HashString(table.concat(parts, "#"))
end

function GLD:ComputeRosterHashFromDB()
  local roster = {}
  for key, player in pairs(self.db.players or {}) do
    roster[#roster + 1] = {
      key = key,
      name = player.name,
      realm = player.realm,
      class = player.class,
      attendance = player.attendance,
      queuePos = player.queuePos,
      savedPos = player.savedPos,
      numAccepted = player.numAccepted,
      attendanceCount = player.attendanceCount,
    }
  end
  return self:ComputeRosterHashFromSnapshot(roster)
end

function GLD:ComputeConfigHash()
  if not self.db or not self.db.config then
    return nil
  end
  return HashString(StableStringify(self.db.config))
end

function GLD:InitComms()
  self:RegisterComm(NS.COMM_PREFIX)
  self.commHandlers = {}

  self.commHandlers[NS.MSG.STATE_SNAPSHOT] = function(sender, payload)
    self:HandleStateSnapshot(sender, payload)
  end
  self.commHandlers[NS.MSG.DELTA] = function(sender, payload)
    self:HandleDelta(sender, payload)
  end
  self.commHandlers[NS.MSG.ROLL_SESSION] = function(sender, payload)
    self:HandleRollSession(sender, payload)
  end
  self.commHandlers[NS.MSG.ROLL_VOTE] = function(sender, payload)
    self:HandleRollVote(sender, payload)
  end
  self.commHandlers[NS.MSG.ROLL_RESULT] = function(sender, payload)
    self:HandleRollResult(sender, payload)
  end
  self.commHandlers[NS.MSG.ROLL_MISMATCH] = function(sender, payload)
    self:HandleRollMismatch(sender, payload)
  end
end

function GLD:SendCommMessageSafe(msgType, payload, channel, target)
  local message = { type = msgType, payload = payload }
  local serialized = self:Serialize(message)
  self:SendCommMessage(NS.COMM_PREFIX, serialized, channel or "RAID", target)
end

function GLD:OnCommReceived(prefix, message, distribution, sender)
  if prefix ~= NS.COMM_PREFIX then
    return
  end
  local success, data = self:Deserialize(message)
  if not success or type(data) ~= "table" then
    return
  end
  local handler = self.commHandlers[data.type]
  if handler then
    handler(sender, data.payload)
  end
end

function GLD:HandleStateSnapshot(sender, payload)
  if not payload then
    return
  end
  local localRosterHash = self:ComputeRosterHashFromDB()
  local localConfigHash = self:ComputeConfigHash()
  if payload.rosterHash and localRosterHash and payload.rosterHash ~= localRosterHash then
    self:Print("Sync mismatch: your roster differs from authority. Using authority data.")
  end
  if payload.configHash and localConfigHash and payload.configHash ~= localConfigHash then
    self:Print("Sync mismatch: your config differs from authority.")
  end
  self.shadow.lastSyncAt = GetServerTime()
  if payload.my then
    self.shadow.my = payload.my
  end
  if payload.roster then
    self.shadow.roster = payload.roster
  end
  if self.UI then
    self.UI:RefreshMain()
  end
end

function GLD:HandleDelta(sender, payload)
  if not payload then
    return
  end
  if payload.my then
    self.shadow.my = payload.my
  end
  if payload.roster then
    self.shadow.roster = payload.roster
  end
  if self.UI then
    self.UI:RefreshMain()
  end
end

function GLD:BuildSnapshot()
  local roster = {}
  for key, player in pairs(self.db.players) do
    table.insert(roster, {
      key = key,
      name = player.name,
      realm = player.realm,
      class = player.class,
      queuePos = player.queuePos,
      savedPos = player.savedPos,
      numAccepted = player.numAccepted,
      attendance = player.attendance,
      attendanceCount = player.attendanceCount,
      role = NS:GetRoleForPlayer(player.name),
    })
  end

  local rosterHash = self:ComputeRosterHashFromSnapshot(roster)
  local configHash = self:ComputeConfigHash()

  local my = {
    queuePos = nil,
    savedPos = nil,
    numAccepted = nil,
    attendance = nil,
    attendanceCount = nil,
  }

  local myKey = NS:GetPlayerKeyFromUnit("player")
  if myKey then
    local me = self.db.players[myKey]
    if me then
      my.queuePos = me.queuePos
      my.savedPos = me.savedPos
      my.numAccepted = me.numAccepted
      my.attendance = me.attendance
      my.attendanceCount = me.attendanceCount
    end
  end

  return {
    my = my,
    roster = roster,
    rosterHash = rosterHash,
    configHash = configHash,
  }
end

function GLD:BroadcastSnapshot()
  if not self:IsAuthority() then
    return
  end
  local snapshot = self:BuildSnapshot()
  self:SendCommMessageSafe(NS.MSG.STATE_SNAPSHOT, snapshot, "RAID")
end

function GLD:HandleRollSession(sender, payload)
  if not self:IsAuthority() or not payload or not payload.rollID then
    return
  end
  local rollID = payload.rollID
  local session = self.activeRolls and self.activeRolls[rollID] or nil
  if not session then
    session = {
      rollID = rollID,
      rollTime = payload.rollTime,
      itemLink = payload.itemLink,
      itemName = payload.itemName,
      quality = payload.quality,
      canNeed = payload.canNeed,
      canGreed = payload.canGreed,
      canTransmog = payload.canTransmog,
      votes = {},
      expectedVoters = self:BuildExpectedVoters(),
      createdAt = GetServerTime(),
    }
    self.activeRolls = self.activeRolls or {}
    self.activeRolls[rollID] = session
    C_Timer.After(payload.rollTime or 120, function()
      local active = self.activeRolls and self.activeRolls[rollID]
      if active and not active.locked then
        self:FinalizeRoll(active)
      end
    end)
  end
end

function GLD:HandleRollVote(sender, payload)
  if not self:IsAuthority() or not payload or not payload.rollID then
    return
  end
  local rollID = payload.rollID
  local session = self.activeRolls and self.activeRolls[rollID] or nil
  if not session or session.locked then
    return
  end
  local key = self:GetRollCandidateKey(sender)
  session.votes = session.votes or {}
  session.votes[key] = payload.vote
  self:CheckRollCompletion(session)
end

function GLD:HandleRollResult(sender, payload)
  if not payload or not payload.rollID then
    return
  end
  local rollID = payload.rollID
  if self.activeRolls and self.activeRolls[rollID] then
    self.activeRolls[rollID].locked = true
    self.activeRolls[rollID].result = payload
  end
  self:RecordRollHistory(payload)
  self:Print("GLD Result: " .. tostring(payload.itemName or payload.itemLink or "Item") .. " -> " .. tostring(payload.winnerName or "None"))
end

function GLD:HandleRollMismatch(sender, payload)
  if not payload then
    return
  end
  self:Print("GLD mismatch: " .. tostring(payload.name) .. " declared " .. tostring(payload.expected) .. " but rolled " .. tostring(payload.actual))
end
