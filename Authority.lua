local _, NS = ...

local GLD = NS.GLD

local HOST_ELECTION_COOLDOWN_SECONDS = 3

local function GetHostNow()
  if GetTime then
    return GetTime()
  end
  return time()
end

local function SafeName(value)
  if value and value ~= "" then
    return value
  end
  return nil
end

function GLD:SetSessionAuthority(guid, name, revision)
  if not self.db or not self.db.session then
    return
  end
  local cleanGuid = SafeName(guid)
  local cleanName = SafeName(name)
  self.db.session.authorityGUID = cleanGuid
  self.db.session.authorityName = cleanName
  self.db.session.hostGUID = cleanGuid
  self.db.session.hostName = cleanName
  if revision ~= nil then
    self.db.session.hostRevision = tonumber(revision) or 0
  elseif self.db.session.hostRevision == nil then
    self.db.session.hostRevision = 0
  end
end

function GLD:ClearSessionAuthority()
  if not self.db or not self.db.session then
    return
  end
  self.db.session.authorityGUID = nil
  self.db.session.authorityName = nil
  self.db.session.hostGUID = nil
  self.db.session.hostName = nil
  self.db.session.hostRevision = 0
end

function GLD:GetAuthorityGUID()
  local session = self.db and self.db.session or nil
  if not session then
    return nil
  end
  if session.hostGUID and session.hostGUID ~= "" then
    return session.hostGUID
  end
  return session.authorityGUID
end

function GLD:GetAuthorityName()
  local session = self.db and self.db.session or nil
  if session and session.hostName and session.hostName ~= "" then
    return session.hostName
  end
  if session and session.authorityName and session.authorityName ~= "" then
    return session.authorityName
  end
  local guid = session and (session.hostGUID or session.authorityGUID) or nil
  if guid and self.db and self.db.players and self.db.players[guid] then
    local player = self.db.players[guid]
    local name = player.name
    local realm = player.realm
    if name then
      if realm and realm ~= "" then
        return name .. "-" .. realm
      end
      return name
    end
  end
  if guid then
    local function tryUnit(unit)
      if UnitExists(unit) and UnitGUID(unit) == guid then
        return self:GetUnitFullName(unit)
      end
      return nil
    end
    local name = tryUnit("player")
    if name then
      return name
    end
    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do
        name = tryUnit("raid" .. i)
        if name then
          return name
        end
      end
    end
  end
  return nil
end

function GLD:GetHostRevision()
  local session = self.db and self.db.session or nil
  if not session then
    return 0
  end
  return tonumber(session.hostRevision) or 0
end

function GLD:NextHostRevision()
  local current = self:GetHostRevision()
  return current + 1
end

function GLD:GetSessionId()
  if self.db and self.db.session and self.db.session.raidSessionId then
    return self.db.session.raidSessionId
  end
  if self.shadow and self.shadow.sessionId then
    return self.shadow.sessionId
  end
  if self.db and self.db.lootSession and self.db.lootSession.sessionId then
    return self.db.lootSession.sessionId
  end
  return nil
end

function GLD:IsAuthority()
  local authorityGUID = self:GetAuthorityGUID()
  if not authorityGUID then
    return false
  end
  local myGuid = UnitGUID("player")
  return myGuid and myGuid == authorityGUID
end

function GLD:IsSessionHostMissing()
  local authorityGUID = self:GetAuthorityGUID()
  if not authorityGUID or authorityGUID == "" then
    return true
  end
  if not IsInRaid() then
    return true
  end
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitGUID(unit) == authorityGUID then
      return not UnitIsConnected(unit)
    end
  end
  return true
end

local function BuildCandidate(self, unit)
  local guid = UnitGUID(unit)
  if not guid then
    return nil
  end
  local fullName = self.GetUnitFullName and self:GetUnitFullName(unit) or UnitName(unit)
  local _, _, rankIndex = GetGuildInfo(unit)
  return {
    unit = unit,
    guid = guid,
    fullName = fullName,
    rankIndex = rankIndex or 99,
  }
end

local function CompareCandidates(a, b)
  if a.rankIndex ~= b.rankIndex then
    return a.rankIndex < b.rankIndex
  end
  if a.guid and b.guid and a.guid ~= b.guid then
    return a.guid < b.guid
  end
  local nameA = a.fullName or ""
  local nameB = b.fullName or ""
  return nameA < nameB
end

function GLD:IsHostEligibleUnit(unit)
  if not unit or not UnitExists(unit) then
    return false
  end
  if self.IsOfficerUnit then
    return self:IsOfficerUnit(unit)
  end
  if self.IsHostEligible then
    return self:IsHostEligible(unit)
  end
  return false
end

function GLD:GetBestSessionHostCandidate()
  if not IsInRaid() then
    return nil
  end
  local leader = nil
  local assistants = {}
  local officers = {}
  local eligible = {}

  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) and self:IsHostEligibleUnit(unit) then
      local candidate = BuildCandidate(self, unit)
      if candidate then
        eligible[#eligible + 1] = candidate
        if UnitIsGroupLeader(unit) then
          leader = candidate
        elseif UnitIsGroupAssistant(unit) then
          assistants[#assistants + 1] = candidate
        else
          officers[#officers + 1] = candidate
        end
      end
    end
  end

  if leader then
    return leader
  end
  if #assistants > 0 then
    table.sort(assistants, CompareCandidates)
    return assistants[1]
  end
  if #officers > 0 then
    table.sort(officers, CompareCandidates)
    return officers[1]
  end
  if #eligible > 0 then
    table.sort(eligible, CompareCandidates)
    return eligible[1]
  end
  return nil
end

function GLD:GetUnitNameForGuid(guid)
  if not guid then
    return nil
  end
  if UnitGUID("player") == guid then
    return self.GetUnitFullName and self:GetUnitFullName("player") or UnitName("player")
  end
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if UnitExists(unit) and UnitGUID(unit) == guid then
        return self.GetUnitFullName and self:GetUnitFullName(unit) or UnitName(unit)
      end
    end
  end
  return nil
end

function GLD:BroadcastHostClaim(revision, hostGUID, hostName, sessionId)
  if not IsInRaid() then
    return
  end
  if not self.SendCommMessageSafe then
    return
  end
  local payload = {
    sessionId = sessionId or self:GetSessionId(),
    hostGUID = hostGUID,
    hostName = hostName,
    revision = revision,
  }
  self:SendCommMessageSafe(NS.MSG.HOST_CLAIM, payload, "RAID")
end

function GLD:ApplyHostClaim(revision, hostGUID, hostName, source)
  if not hostGUID or hostGUID == "" then
    return
  end
  local name = hostName
  if not name or name == "" then
    name = self:GetUnitNameForGuid(hostGUID) or hostName
  end
  self:SetSessionAuthority(hostGUID, name, revision)
  if UnitGUID("player") == hostGUID then
    if self.BroadcastSessionState then
      self:BroadcastSessionState(true)
    end
    if self.BroadcastSnapshot then
      self:BroadcastSnapshot(true)
    end
  end
  if self.UI and self.UI.RefreshMain then
    self.UI:RefreshMain()
  end
end

function GLD:EvaluateSessionHost(reason)
  local sessionActive = self.IsSessionActiveLocal and self:IsSessionActiveLocal() or (self.db and self.db.session and self.db.session.active == true)
  if not sessionActive then
    return
  end
  if not IsInRaid() then
    return
  end
  if not self:IsSessionHostMissing() then
    return
  end
  local now = GetHostNow()
  if self.hostElectionLastAt and now - self.hostElectionLastAt < HOST_ELECTION_COOLDOWN_SECONDS then
    return
  end
  self.hostElectionLastAt = now
  if self.LilyDebug then
    self:LilyDebug("[HOST] Host missing. Electing new host...")
  end
  if self.RunSessionHostElection then
    self:RunSessionHostElection()
  end
end

function GLD:RunSessionHostElection()
  local candidate = self:GetBestSessionHostCandidate()
  if not candidate then
    return
  end
  local myGuid = UnitGUID("player")
  if myGuid and candidate.guid == myGuid then
    local revision = self:NextHostRevision()
    local name = candidate.fullName or self:GetUnitNameForGuid(myGuid) or "Unknown"
    self:ApplyHostClaim(revision, myGuid, name, "local")
    self:BroadcastHostClaim(revision, myGuid, name)
    if self.LilyDebug then
      self:LilyDebug(
        string.format(
          "[HOST] New host elected: %s (%s) rev=%s",
          tostring(name),
          tostring(myGuid),
          tostring(revision)
        )
      )
    end
  end
end

function GLD:HandleHostClaim(sender, payload)
  if not payload or not payload.hostGUID or not payload.revision then
    return
  end
  if not IsInRaid() then
    return
  end
  if self.IsSenderInRaid and not self:IsSenderInRaid(sender) then
    return
  end
  local sessionId = payload.sessionId
  local localSessionId = self:GetSessionId()
  if sessionId and localSessionId and sessionId ~= localSessionId then
    return
  end

  local senderGuid = self.GetGuidForSender and self:GetGuidForSender(sender) or nil
  if senderGuid and senderGuid ~= payload.hostGUID then
    return
  end
  if self.GetUnitForSender then
    local unit = self:GetUnitForSender(sender)
    if unit and not self:IsHostEligibleUnit(unit) then
      return
    end
  end

  local currentRevision = self:GetHostRevision()
  local hostMissing = self:IsSessionHostMissing()
  local accept = (tonumber(payload.revision) or 0) > currentRevision or hostMissing
  local action = accept and "ACCEPT" or "IGNORE"

  if self.LilyDebug then
    self:LilyDebug(
      string.format(
        "[HOST] RX HOST_CLAIM from %s host=%s rev=%s action=%s",
        tostring(sender),
        tostring(payload.hostGUID),
        tostring(payload.revision),
        action
      )
    )
  end

  if not accept then
    return
  end

  if sessionId and not localSessionId and self.db and self.db.session then
    self.db.session.raidSessionId = sessionId
  end

  self:ApplyHostClaim(tonumber(payload.revision) or 0, payload.hostGUID, payload.hostName, sender)
end

function GLD:IsAuthorizedSender(sender, payloadAuthorityGUID, payloadAuthorityName)
  local senderGuid = self.GetGuidForSender and self:GetGuidForSender(sender) or nil
  if payloadAuthorityGUID and senderGuid and payloadAuthorityGUID ~= senderGuid then
    return false, senderGuid
  end

  local authorityGUID = self:GetAuthorityGUID()
  if (not authorityGUID or authorityGUID == "") and (payloadAuthorityGUID or senderGuid) then
    local name = payloadAuthorityName or sender
    self:SetSessionAuthority(payloadAuthorityGUID or senderGuid, name)
    authorityGUID = self:GetAuthorityGUID()
  end

  if payloadAuthorityGUID and authorityGUID and authorityGUID ~= payloadAuthorityGUID then
    return false, senderGuid
  end

  if not authorityGUID or not senderGuid then
    return false, senderGuid
  end

  if payloadAuthorityName and payloadAuthorityName ~= "" and authorityGUID == senderGuid then
    if self.db and self.db.session and (not self.db.session.authorityName or self.db.session.authorityName == "") then
      self.db.session.authorityName = payloadAuthorityName
    end
  end

  return senderGuid == authorityGUID, senderGuid
end
