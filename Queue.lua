local _, NS = ...

local GLD = NS.GLD

local function NormalizeAttendanceState(state)
  if state == "Absent" or state == "ABSENT" then
    return "Absent"
  end
  if state == "Present" or state == "PRESENT" then
    return "Present"
  end
  return state
end

local function IsPresentState(state)
  return NormalizeAttendanceState(state) ~= "Absent"
end

local function GetHoldPos(player)
  if not player then
    return nil
  end
  if player.holdPos ~= nil then
    return player.holdPos
  end
  return player.savedPos
end

local function SetHoldPos(player, pos)
  if not player then
    return
  end
  player.holdPos = pos
  player.savedPos = pos
end

local function ClearHoldPos(player)
  if not player then
    return
  end
  player.holdPos = nil
  player.savedPos = nil
end

local function CountRosterEntries(players)
  local count = 0
  if type(players) ~= "table" then
    return count
  end
  for _ in pairs(players) do
    count = count + 1
  end
  return count
end

function GLD:RemoveFromQueue(key, skipRevision)
  if not key then
    return false
  end
  self.db.queue = self.db.queue or {}
  local removed = false
  for i, k in ipairs(self.db.queue) do
    if k == key then
      table.remove(self.db.queue, i)
      removed = true
      break
    end
  end
  local player = self.db.players[key]
  if player then
    player.queuePos = nil
  end
  if removed and self.CompactQueue then
    self:CompactQueue()
  end
  if removed and not skipRevision and self.MarkDBChanged then
    self:MarkDBChanged("queue_remove")
  end
  return removed
end

function GLD:InsertToQueue(key, position, skipRevision)
  if not key then
    return false
  end
  self.db.queue = self.db.queue or {}
  local count = #self.db.queue
  local pos = tonumber(position)
  if not pos or pos < 1 or pos > count + 1 then
    pos = count + 1
  end
  table.insert(self.db.queue, pos, key)
  self:CompactQueue()
  if not skipRevision and self.MarkDBChanged then
    self:MarkDBChanged("queue_insert")
  end
  return true
end

function GLD:CompactQueue()
  self.db.queue = self.db.queue or {}
  local newQueue = {}
  local seen = {}
  for _, key in ipairs(self.db.queue) do
    local player = self.db.players[key]
    if player then
      local normalized = NormalizeAttendanceState(player.attendance)
      if (normalized == "Present" or normalized == "Absent") and normalized ~= player.attendance then
        player.attendance = normalized
      end
    end
    if player and IsPresentState(player.attendance) and not seen[key] then
      table.insert(newQueue, key)
      seen[key] = true
    end
  end
  self.db.queue = newQueue
  for i, key in ipairs(self.db.queue) do
    local player = self.db.players[key]
    if player then
      player.queuePos = i
    end
  end
end

function GLD:SetAttendance(key, state)
  if not key then
    return false
  end
  local player = self.db.players[key]
  if not player then
    return false
  end

  local normalized = NormalizeAttendanceState(state)
  if normalized ~= "Absent" then
    normalized = "Present"
  end

  local current = NormalizeAttendanceState(player.attendance)
  if current ~= "Absent" then
    current = "Present"
  end

  if normalized == "Absent" then
    if current ~= "Absent" then
      if player.queuePos then
        SetHoldPos(player, player.queuePos)
      end
      self:RemoveFromQueue(key, true)
    end
    player.attendance = "Absent"
    if current ~= "Absent" and self.MarkDBChanged then
      self:MarkDBChanged("attendance_absent")
    end
    return current ~= "Absent"
  end

  if current == "Absent" then
    local desiredPos = nil
    local holdPos = GetHoldPos(player)
    if holdPos and holdPos >= 1 then
      desiredPos = holdPos
    end
    player.attendance = "Present"
    self:InsertToQueue(key, desiredPos, true)
    ClearHoldPos(player)
    if self.MarkDBChanged then
      self:MarkDBChanged("attendance_present")
    end
    return true
  end

  player.attendance = "Present"
  if current ~= "Present" and self.MarkDBChanged then
    self:MarkDBChanged("attendance_present")
  end
  return current ~= "Present"
end

function GLD:EnsureQueuePositions()
  self.db.queue = self.db.queue or {}
  local inQueue = {}
  for _, key in ipairs(self.db.queue) do
    inQueue[key] = true
  end
  for key, player in pairs(self.db.players or {}) do
    if player and IsPresentState(player.attendance) and not inQueue[key] then
      table.insert(self.db.queue, key)
      inQueue[key] = true
    end
  end
  self:CompactQueue()
end

function GLD:OnRosterChanged(reason)
  if self.EnsureQueuePositions then
    self:EnsureQueuePositions()
  end
  if self.MarkDBChanged then
    self:MarkDBChanged(reason or "roster_changed")
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    local revision = self.db and self.db.meta and self.db.meta.revision or 0
    local rosterCount = CountRosterEntries(self.db and self.db.players or nil)
    local sessionActive = self.db and self.db.session and self.db.session.active == true
    self:Debug(
      "Roster changed: reason="
        .. tostring(reason or "roster_changed")
        .. " revision="
        .. tostring(revision)
        .. " rosterCount="
        .. tostring(rosterCount)
        .. " sessionActive="
        .. tostring(sessionActive)
    )
  end
  if self.BroadcastSnapshot then
    self:BroadcastSnapshot(true)
  end
  if self.UI and self.UI.RefreshMain then
    self.UI:RefreshMain()
  end
end

function GLD:MoveToQueueBottom(key)
  if not key then
    return
  end
  local removed = self:RemoveFromQueue(key, true)
  local inserted = self:InsertToQueue(key, nil, true)
  if (removed or inserted) and self.MarkDBChanged then
    self:MarkDBChanged("queue_move_bottom")
  end
end

function GLD:MoveToQueueMiddle(key)
  if not key then
    return
  end
  local removed = self:RemoveFromQueue(key, true)
  self.db.queue = self.db.queue or {}
  local count = #self.db.queue
  local pos = math.floor((count + 1) / 2)
  if pos < 1 then
    pos = 1
  end
  local inserted = self:InsertToQueue(key, pos, true)
  if (removed or inserted) and self.MarkDBChanged then
    self:MarkDBChanged("queue_move_middle")
  end
end

function GLD:OnAwardedItem(key)
  if not key then
    return false
  end
  local player = self.db.players[key]
  if not player then
    return false
  end
  if not IsPresentState(player.attendance) then
    return false
  end
  player.attendance = NormalizeAttendanceState(player.attendance) or "Present"
  player.numAccepted = (player.numAccepted or 0) + 1
  self:MoveToQueueBottom(key)
  if self.MarkDBChanged then
    self:MarkDBChanged("award_item")
  end
  return true
end

function GLD:RosterRemoveMember(key)
  if not key then
    return false, "missing_player_key"
  end
  if not self.db or not self.db.players then
    return false, "missing_db"
  end
  if not self.db.players[key] then
    return false, "missing_player"
  end
  local player = self.db.players[key]

  if self.RemovePlayerFromDatabase then
    local ok = self:RemovePlayerFromDatabase(key)
    if ok then
      return true, nil
    end
    return false, "remove_failed"
  end

  if self.RemoveFromQueue then
    self:RemoveFromQueue(key, true)
  end

  if self.db.queue then
    for i = #self.db.queue, 1, -1 do
      if self.db.queue[i] == key then
        table.remove(self.db.queue, i)
      end
    end
  end

  if self.db.session and self.db.session.attended then
    self.db.session.attended[key] = nil
  end

  if player and self.IsGuestEntry and self:IsGuestEntry(player) and self.RemoveApprovedGuestRecord then
    self:RemoveApprovedGuestRecord(key, player)
  end
  self.db.players[key] = nil

  if self.CompactQueue then
    self:CompactQueue()
  end
  if self.MarkDBChanged then
    self:MarkDBChanged("player_remove")
  end

  return true, nil
end

function GLD:RemoveRosterMember(key)
  local ok, reason = false, "remove_failed"
  if self.RosterRemoveMember then
    ok, reason = self:RosterRemoveMember(key)
  end
  if ok and self.OnRosterChanged then
    self:OnRosterChanged("roster_remove")
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    local outcome = ok and "ok" or (reason or "failed")
    self:Debug("Roster remove authority: key=" .. tostring(key) .. " result=" .. tostring(outcome))
  end
  return ok, reason
end

function GLD:RemovePlayerFromDatabase(key)
  if not key or not self.db or not self.db.players then
    return false
  end
  local player = self.db.players[key]

  if self.RemoveFromQueue then
    self:RemoveFromQueue(key, true)
  end

  if self.db.queue then
    for i = #self.db.queue, 1, -1 do
      if self.db.queue[i] == key then
        table.remove(self.db.queue, i)
      end
    end
  end

  if self.db.session and self.db.session.attended then
    self.db.session.attended[key] = nil
  end

  if player and self.IsGuestEntry and self:IsGuestEntry(player) and self.RemoveApprovedGuestRecord then
    self:RemoveApprovedGuestRecord(key, player)
  end
  self.db.players[key] = nil

  if self.CompactQueue then
    self:CompactQueue()
  end
  if self.MarkDBChanged then
    self:MarkDBChanged("player_remove")
  end

  return true
end
