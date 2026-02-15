local _, NS = ...

local GLD = NS.GLD
local RAID_STATE_REFRESH_SECONDS = 20
local LEAVE_ZONE_WARNING_SECONDS = 60
local START_SESSION_POPUP = "GLD_START_SESSION_CONFIRM"
local END_SESSION_POPUP = "GLD_END_SESSION_CONFIRM"
local LOOT_CTRL_DISABLED = "DISABLED"
local LOOT_CTRL_ENABLING = "ENABLING"
local LOOT_CTRL_ENABLED = "ENABLED"
local LOOT_CTRL_DISABLING = "DISABLING"

local function IsLocalAdminAuthority(self, source)
  if self and self.IsLocalAuthority then
    local allowed = self:IsLocalAuthority({ source = source })
    return allowed == true
  end
  if self and self.CanAccessAdminUI then
    return self:CanAccessAdminUI()
  end
  return false
end

local function EnsureLootSessionStore(self)
  if not self or not self.db then
    return nil
  end
  self.db.lootSession = self.db.lootSession or {}
  local store = self.db.lootSession
  if store.sessionActive == nil then
    store.sessionActive = self.db.session and self.db.session.active == true or false
  end
  if store.sessionId == nil and self.db.session then
    store.sessionId = self.db.session.raidSessionId
  end
  if store.pugsInRaid == nil then
    store.pugsInRaid = self.db.session and self.db.session.pugsInRaid == true or false
  end
  if self.shadow then
    if self.shadow.sessionActive == nil then
      self.shadow.sessionActive = store.sessionActive == true
    end
    if self.shadow.sessionId == nil then
      self.shadow.sessionId = store.sessionId
    end
    if self.shadow.pugsInRaid == nil then
      self.shadow.pugsInRaid = store.pugsInRaid == true
    end
  end
  if self.db and self.db.session and self.db.session.pugsInRaid == nil then
    self.db.session.pugsInRaid = store.pugsInRaid == true
  end
  return store
end

local function DeterminePersistedLootSessionState(self)
  local dbActive = self.db and self.db.session and self.db.session.active == true
  local shadowActive = self.shadow and self.shadow.sessionActive == true
  local store = EnsureLootSessionStore(self)
  local active = dbActive or shadowActive

  local sessionId = nil
  if dbActive then
    sessionId = self.db and self.db.session and self.db.session.raidSessionId or nil
  end
  if not sessionId and self.shadow and self.shadow.sessionId then
    sessionId = self.shadow.sessionId
  end
  if active and not sessionId and store and store.sessionId then
    sessionId = store.sessionId
  end
  return active, sessionId
end

local function EnsureLootController(self)
  self.lootController = self.lootController or {
    state = LOOT_CTRL_DISABLED,
    enabled = false,
    sessionActive = false,
    sessionId = nil,
  }
  return self.lootController
end

local function DebugSessionStateChange(self, action, reason)
  if not (self.IsDebugEnabled and self:IsDebugEnabled()) then
    return
  end
  local sessionEnabled = self.IsEnabled and self:IsEnabled() or false
  local sessionActive = self.IsSessionActiveLocal and self:IsSessionActiveLocal()
  if sessionActive == nil then
    sessionActive = self.IsSessionActive and self:IsSessionActive() or false
  end
  local pugsMode = self.GetPugsInRaid and self:GetPugsInRaid() or false
  local revision = self.db and self.db.meta and self.db.meta.revision or 0
  self:Debug(
    "[StateChange] action="
      .. tostring(action or "unknown")
      .. " reason="
      .. tostring(reason or "none")
      .. " sessionEnabled="
      .. tostring(sessionEnabled)
      .. " sessionActive="
      .. tostring(sessionActive)
      .. " pugsMode="
      .. tostring(pugsMode)
      .. " revision="
      .. tostring(revision)
  )
end

function GLD:InitAttendance()
  if not self.db.session then
    self.db.session = {
      active = false,
      startedAt = 0,
      attended = {},
      raidSessionId = nil,
      currentBoss = nil,
      zoneInstanceID = nil,
    }
  end
  if not self.lootController then
    self:InitLootSessionController()
  end
end

function GLD:InitLootSessionController()
  EnsureLootSessionStore(self)
  local controller = EnsureLootController(self)
  controller.state = controller.state or LOOT_CTRL_DISABLED
  controller.enabled = controller.enabled == true
  controller.sessionActive = controller.sessionActive == true
  controller.sessionId = controller.sessionId or nil
end

function GLD:SetLootSessionPersistence(active, sessionId)
  local controller = EnsureLootController(self)
  local store = EnsureLootSessionStore(self)
  active = active == true
  if store then
    store.sessionActive = active
    store.sessionId = active and sessionId or nil
  end
  if self.shadow then
    self.shadow.sessionActive = active
    self.shadow.sessionId = active and sessionId or nil
  end
  controller.sessionActive = active
  controller.sessionId = active and sessionId or nil
end

function GLD:GetPugsInRaid()
  local authority = self.IsAuthority and self:IsAuthority()
  if authority then
    return self.db and self.db.session and self.db.session.pugsInRaid == true
  end
  if self.shadow and self.shadow.pugsInRaid ~= nil then
    return self.shadow.pugsInRaid == true
  end
  if self.db and self.db.lootSession and self.db.lootSession.pugsInRaid ~= nil then
    return self.db.lootSession.pugsInRaid == true
  end
  return self.db and self.db.session and self.db.session.pugsInRaid == true or false
end

function GLD:SetPugsInRaidPersistence(enabled)
  enabled = enabled == true
  local store = EnsureLootSessionStore(self)
  if store then
    store.pugsInRaid = enabled
  end
  if self.db and self.db.session then
    self.db.session.pugsInRaid = enabled
  end
  if self.shadow then
    self.shadow.pugsInRaid = enabled
  end
end

function GLD:ApplyPugsInRaidLocal(enabled, reason)
  self:SetPugsInRaidPersistence(enabled)
  if self.RefreshLootControllerFromPersistence then
    self:RefreshLootControllerFromPersistence("PugsMode:" .. tostring(reason or "local"))
  end
  if self.ApplyCoverStatesForAllActiveRolls then
    self:ApplyCoverStatesForAllActiveRolls()
  end
  if self.ReapplyCoverBlockersForActiveRolls then
    self:ReapplyCoverBlockersForActiveRolls("pugs_mode:" .. tostring(reason or "local"), false)
  end
  if self.RunLootBootBootstrap then
    self:RunLootBootBootstrap("pugs_mode:" .. tostring(reason or "local"))
  end
  if self.UI and self.UI.RefreshMain then
    self.UI:RefreshMain()
  elseif self.UI and self.UI.RefreshLootWindow then
    self.UI:RefreshLootWindow()
  end
  local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if AceConfigRegistry then
    AceConfigRegistry:NotifyChange("GuildLoot")
  end
end

function GLD:SetPugsInRaid(enabled, options)
  options = options or {}
  enabled = enabled == true
  if self.DebugAuth then
    self:DebugAuth("SetPugsInRaid", "Attendance.SetPugsInRaid")
  end
  if not options.skipPermission then
    if not IsLocalAdminAuthority(self, "Attendance.SetPugsInRaid") then
      self:ShowPermissionDeniedPopup()
      return false
    end
  end
  local current = self:GetPugsInRaid()
  if current == enabled then
    return true
  end
  self:ApplyPugsInRaidLocal(enabled, options.reason or "SetPugsInRaid")
  if self.MarkDBChanged then
    self:MarkDBChanged("pugs_mode_set")
  end
  DebugSessionStateChange(self, "SET_PUGS_MODE", options.reason or "SetPugsInRaid")
  local actorGuid = options.actorGuid
  local actor = options.actorName
  if not actor or actor == "" then
    actor = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
  end
  if not actorGuid or actorGuid == "" then
    actorGuid = UnitGUID("player")
  end
  if self.LogAuditEvent then
    self:LogAuditEvent("PUGS_MODE_SET", {
      actor = actor,
      actorGuid = actorGuid,
      details = enabled and "ON" or "OFF",
    })
  end
  if self.LilyDebug then
    self:LilyDebug(
      string.format(
        "[PUGS] mode=%s by=%s",
        enabled and "ON" or "OFF",
        tostring(actor)
      )
    )
  end
  if self.BroadcastPugsModeSet and not options.skipBroadcast then
    self:BroadcastPugsModeSet(enabled, actorGuid)
  end
  if self.BroadcastSessionState and options.broadcastSessionState ~= false then
    self:BroadcastSessionState(true)
  end
  return true
end

function GLD:RequestSetPugsInRaid(enabled)
  enabled = enabled == true
  if self:IsAuthority() then
    return self:SetPugsInRaid(enabled, { reason = "local_toggle" })
  end
  if self.RequestAdminAction then
    return self:RequestAdminAction("SET_PUGS_MODE", { enabled = enabled })
  end
  return false
end

function GLD:IsEnabled()
  local controller = EnsureLootController(self)
  local state = controller.state
  return state == LOOT_CTRL_ENABLING or state == LOOT_CTRL_ENABLED
end

function GLD:IsSessionActive()
  local controller = EnsureLootController(self)
  if controller.sessionActive ~= nil then
    return controller.sessionActive == true
  end
  local active = DeterminePersistedLootSessionState(self)
  return active == true
end

function GLD:EnableSession(sessionId, reason, options)
  options = options or {}
  self:InitLootSessionController()
  local controller = EnsureLootController(self)
  local nextSessionId = sessionId
    or (self.db and self.db.session and self.db.session.raidSessionId)
    or (self.shadow and self.shadow.sessionId)
    or (self.db and self.db.lootSession and self.db.lootSession.sessionId)
  if controller.state == LOOT_CTRL_ENABLED and controller.sessionActive and controller.sessionId == nextSessionId then
    return
  end

  local previousState = controller.state
  controller.state = LOOT_CTRL_ENABLING
  controller.enabled = true
  controller.sessionActive = true
  controller.sessionId = nextSessionId
  self:SetLootSessionPersistence(true, nextSessionId)

  if self.OnLootSessionEnabled then
    self:OnLootSessionEnabled(nextSessionId, reason or "EnableSession", previousState, options)
  end

  controller.state = LOOT_CTRL_ENABLED
  controller.enabled = true
  controller.sessionActive = true
  controller.sessionId = nextSessionId
end

function GLD:DisableSession(reason, options)
  options = options or {}
  self:InitLootSessionController()
  local controller = EnsureLootController(self)
  if controller.state == LOOT_CTRL_DISABLED and controller.sessionActive ~= true then
    self:SetLootSessionPersistence(false, nil)
    return
  end

  local previousState = controller.state
  controller.state = LOOT_CTRL_DISABLING
  controller.enabled = false
  controller.sessionActive = false
  controller.sessionId = nil
  self:SetLootSessionPersistence(false, nil)

  if self.OnLootSessionDisabled then
    self:OnLootSessionDisabled(reason or "DisableSession", previousState, options)
  end

  controller.state = LOOT_CTRL_DISABLED
  controller.enabled = false
  controller.sessionActive = false
  controller.sessionId = nil
end

function GLD:RefreshLootControllerFromPersistence(reason, options)
  self:InitLootSessionController()
  local active, sessionId = DeterminePersistedLootSessionState(self)
  if active then
    self:EnableSession(sessionId, reason or "RefreshLootController", options)
  else
    local disableOptions = options or {}
    if disableOptions.clearActiveRolls == nil then
      disableOptions.clearActiveRolls = true
    end
    self:DisableSession(reason or "RefreshLootController", disableOptions)
  end
end

function GLD:GetActiveRaidSession()
  local sessionId = self.db.session and self.db.session.raidSessionId
  if not sessionId then
    return nil
  end
  for _, entry in ipairs(self.db.raidSessions or {}) do
    if entry.id == sessionId then
      return entry
    end
  end
  return nil
end

function GLD:GetRaidMemberCounts()
  local guildCount, nonGuildCount, total = 0, 0, 0
  if not IsInRaid() then
    return guildCount, nonGuildCount, total
  end
  local ourGuild = self.GetOurGuildName and self:GetOurGuildName() or nil
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) then
      total = total + 1
      local isGuild = false
      if UnitIsInMyGuild then
        isGuild = UnitIsInMyGuild(unit)
      elseif ourGuild then
        local guildName = GetGuildInfo(unit)
        isGuild = guildName and guildName == ourGuild or false
      end
      if isGuild then
        guildCount = guildCount + 1
      else
        nonGuildCount = nonGuildCount + 1
      end
    end
  end
  return guildCount, nonGuildCount, total
end

function GLD:EnsureRaidSessionMeta(session)
  if not session then
    return
  end
  session.raidId = session.raidId or session.id
  if session.revision == nil then
    session.revision = 1
  end
end

function GLD:TouchRaidSession(session, reason)
  if not session then
    return
  end
  self:EnsureRaidSessionMeta(session)
  session.revision = (tonumber(session.revision) or 0) + 1
  session.lastUpdatedAt = GetServerTime()
  if reason and self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "History revision bumped: raidId="
        .. tostring(session.raidId)
        .. " rev="
        .. tostring(session.revision)
        .. " reason="
        .. tostring(reason)
    )
  end
end

function GLD:GetHistoryAuthorityUnit()
  if not IsInRaid() then
    return nil
  end
  local leader = nil
  local assistant = nil
  local officer = nil
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) then
      if UnitIsGroupLeader(unit) then
        leader = unit
      end
      if not assistant and UnitIsGroupAssistant(unit) then
        assistant = unit
      end
      if not officer and self.IsOfficerUnit and self:IsOfficerUnit(unit) then
        officer = unit
      end
    end
  end
  return leader or assistant or officer
end

function GLD:IsHistoryAuthority()
  local unit = self:GetHistoryAuthorityUnit()
  if not unit then
    return false
  end
  return UnitIsUnit(unit, "player")
end

function GLD:PromptStartSession()
  if self.db.session.active then
    return
  end
  if not IsInRaid() then
    self:Print("You must be in a raid to start a session.")
    return
  end
  if not IsLocalAdminAuthority(self, "Attendance.PromptStartSession") then
    self:ShowPermissionDeniedPopup()
    return
  end
  local guildCount, nonGuildCount, total = self:GetRaidMemberCounts()
  if not StaticPopupDialogs then
    self:StartSession()
    return
  end
  StaticPopupDialogs[START_SESSION_POPUP] = StaticPopupDialogs[START_SESSION_POPUP] or {}
  local dialog = StaticPopupDialogs[START_SESSION_POPUP]
  dialog.text = string.format("Start Raid session?\nGuild: %d / Total: %d\nNon-guild: %d", guildCount, total, nonGuildCount)
  dialog.button1 = "Confirm"
  dialog.button2 = "Cancel"
  dialog.timeout = 0
  dialog.whileDead = true
  dialog.hideOnEscape = true
  dialog.OnAccept = function()
    if GLD and GLD.StartSession then
      GLD:StartSession()
    end
  end
  StaticPopup_Show(START_SESSION_POPUP)
end

function GLD:PromptEndSession()
  if not self.db.session.active then
    return
  end
  if not IsLocalAdminAuthority(self, "Attendance.PromptEndSession") then
    self:ShowPermissionDeniedPopup()
    return
  end
  if not StaticPopupDialogs then
    self:EndSession()
    return
  end
  StaticPopupDialogs[END_SESSION_POPUP] = StaticPopupDialogs[END_SESSION_POPUP] or {}
  local dialog = StaticPopupDialogs[END_SESSION_POPUP]
  dialog.text = "End Raid session? Are you sure?"
  dialog.button1 = "Confirm"
  dialog.button2 = "Cancel"
  dialog.timeout = 0
  dialog.whileDead = true
  dialog.hideOnEscape = true
  dialog.OnAccept = function()
    if GLD and GLD.EndSession then
      GLD:EndSession()
    end
  end
  StaticPopup_Show(END_SESSION_POPUP)
end

function GLD:StartLeaveZoneTimer()
  if self.leaveZoneTimer or not C_Timer or not C_Timer.NewTimer then
    return
  end
  self:Print("You left the raid zone. Session will end in 60 seconds. Return or end manually.")
  self.leaveZoneTimer = C_Timer.NewTimer(LEAVE_ZONE_WARNING_SECONDS, function()
    self.leaveZoneTimer = nil
    if self.PromptEndSession then
      self:PromptEndSession()
    elseif self.EndSession then
      self:EndSession()
    end
  end)
end

function GLD:CancelLeaveZoneTimer()
  if self.leaveZoneTimer then
    self.leaveZoneTimer:Cancel()
    self.leaveZoneTimer = nil
  end
end

function GLD:CheckSessionZoneStatus()
  if not self.db or not self.db.session or not self.db.session.active then
    self:CancelLeaveZoneTimer()
    return
  end
  if not self:IsAuthority() then
    self:CancelLeaveZoneTimer()
    return
  end
  local raidSession = self.GetActiveRaidSession and self:GetActiveRaidSession() or nil
  local sessionInstanceId = raidSession and raidSession.instanceID or self.db.session.zoneInstanceID
  if not sessionInstanceId or sessionInstanceId == 0 then
    return
  end
  local _, _, _, _, _, _, _, instanceId = GetInstanceInfo()
  if instanceId ~= sessionInstanceId then
    self:StartLeaveZoneTimer()
  else
    self:CancelLeaveZoneTimer()
  end
end

function GLD:StartRaidSession()
  local instanceName, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  local id = tostring(GetServerTime()) .. "-" .. tostring(math.random(1000, 9999))
  local entry = {
    id = id,
    raidId = id,
    revision = 1,
    startedAt = GetServerTime(),
    endedAt = nil,
    raidName = instanceName or "Unknown",
    instanceType = instanceType or "unknown",
    difficultyID = difficultyID,
    difficultyName = difficultyName,
    instanceID = instanceID,
    bosses = {},
    loot = {},
  }
  self.db.raidSessions = self.db.raidSessions or {}
  table.insert(self.db.raidSessions, 1, entry)
  self.db.session.raidSessionId = id
  self.db.session.currentBoss = nil
  if self.MarkDBChanged then
    self:MarkDBChanged("raid_session_start")
  end
  if self.UI and self.UI.RefreshHistoryIfOpen then
    self.UI:RefreshHistoryIfOpen()
  end
  return entry
end

function GLD:StartSession()
  if self.db.session.active then
    return
  end
  if not IsInRaid() then
    self:Print("You must be in a raid to start a session.")
    return
  end
  if self.DebugAuth then
    self:DebugAuth("StartSession", "Attendance.StartSession")
  end
  if not IsLocalAdminAuthority(self, "Attendance.StartSession") then
    self:ShowPermissionDeniedPopup()
    return
  end
  if self.SetSessionAuthority then
    self:SetSessionAuthority(UnitGUID("player"), self:GetUnitFullName("player"), 1)
  end
  self.db.session.active = true
  self.db.session.pugsInRaid = false
  self.db.session.startedAt = GetServerTime()
  self.db.session.attended = {}
  local raidSession = self:StartRaidSession()
  self.db.session.zoneInstanceID = raidSession and raidSession.instanceID or nil
  if self.EnableSession then
    self:EnableSession(self.db.session.raidSessionId, "StartSession", { source = "authority" })
  end
  self:SetPugsInRaidPersistence(false)
  if self.CancelLeaveZoneTimer then
    self:CancelLeaveZoneTimer()
  end
  if self.RebuildGroupRoster then
    self:RebuildGroupRoster()
  end
  if self.WelcomeGuestsFromGroup then
    self:WelcomeGuestsFromGroup()
  end
  self:AutoMarkCurrentGroup()
  self:EnsureQueuePositions()
  if self.MarkDBChanged then
    self:MarkDBChanged("session_start")
  end
  if self.LogAuditEvent then
    local actor = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
    self:LogAuditEvent("SESSION_START", { actor = actor })
  end
  if self.BroadcastSessionState then
    self:BroadcastSessionState()
  end
  self:BroadcastSnapshot()
  if self.UI and self.UI.RefreshMain then
    self.UI:RefreshMain()
  end
  DebugSessionStateChange(self, "START_SESSION", "StartSession")
  self:Print("Session started")
end

function GLD:EndSession(options)
  options = options or {}
  local sessionActive = self.db.session.active == true
  if not sessionActive and not options.force then
    return
  end
  if not options.skipPermission then
    if not IsLocalAdminAuthority(self, "Attendance.EndSession") then
      self:ShowPermissionDeniedPopup()
      return
    end
  end
  if not options.skipRequestLog and self.LilyDebug then
    local actor = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
    self:LilyDebug(
      string.format(
        "[SESSION] End requested by %s host=%s",
        tostring(actor),
        tostring(self:IsAuthority())
      )
    )
  end
  if not options.skipAudit then
    if self.AutoMarkCurrentGroup then
      self:AutoMarkCurrentGroup()
    end
    if self.LogRaidAttendanceAudit then
      self:LogRaidAttendanceAudit()
    end
    if self.LogAuditEvent then
      local actor = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
      self:LogAuditEvent("SESSION_END", { actor = actor })
    end
  end
  if self.CancelLeaveZoneTimer then
    self:CancelLeaveZoneTimer()
  end
  local sessionId = self.db.session.raidSessionId
  self.db.session.active = false
  self.db.session.pugsInRaid = false
  if self.shadow then
    self.shadow.sessionActive = false
    self.shadow.sessionId = nil
    self.shadow.pugsInRaid = false
  end
  if self.ClearSessionAuthority then
    self:ClearSessionAuthority()
  end
  local raidSession = self:GetActiveRaidSession()
  if raidSession then
    raidSession.endedAt = GetServerTime()
    if self.EnsureRaidSessionMeta then
      self:EnsureRaidSessionMeta(raidSession)
    end
    if self.TouchRaidSession then
      self:TouchRaidSession(raidSession, "end")
    end
  end
  local revision = raidSession and raidSession.revision or (self.db and self.db.meta and self.db.meta.revision) or 0
  if not options.skipLog and self.LilyDebug then
    self:LilyDebug(
      string.format(
        "[SESSION] Ending session now. sessionId=%s rev=%s",
        tostring(sessionId or "nil"),
        tostring(revision)
      )
    )
  end
  self.db.session.raidSessionId = nil
  self.db.session.currentBoss = nil
  self.db.session.zoneInstanceID = nil
  if self.ResetGuestAnchorCandidates then
    self:ResetGuestAnchorCandidates("session_end")
  end
  self:SetPugsInRaidPersistence(false)
  if self.DisableSession then
    self:DisableSession("EndSession", { clearActiveRolls = true })
  end
  if self.MarkDBChanged then
    self:MarkDBChanged("session_end")
  end
  DebugSessionStateChange(self, "END_SESSION", "EndSession")
  if not options.skipBroadcast then
    if self.BroadcastSessionState then
      self:BroadcastSessionState(true)
    end
    if raidSession and self.BroadcastHistoryEntry then
      self:BroadcastHistoryEntry(raidSession)
    end
  end
  if self.UI and self.UI.RefreshHistoryIfOpen then
    self.UI:RefreshHistoryIfOpen()
  end
  if not options.skipBroadcast then
    self:BroadcastSnapshot(true)
  end
  if not options.skipEndMessage and self.SendEndSessionMessage then
    self:SendEndSessionMessage(sessionId, revision)
  end
  if self.UI and self.UI.RefreshMain then
    self.UI:RefreshMain()
  end
  self:Print("Session ended")
end

function GLD:OnEncounterEnd(_, encounterID, encounterName, difficultyID, groupSize, success)
  local sessionActive = nil
  if self.shadow and self.shadow.sessionActive ~= nil then
    sessionActive = self.shadow.sessionActive == true
  else
    sessionActive = self.db.session.active == true
  end
  if not sessionActive or success ~= 1 then
    return
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("Boss kill detected: " .. tostring(encounterName or encounterID or "Unknown"))
  end
  if encounterName or encounterID then
    local bossLabel = encounterName or ("Encounter " .. tostring(encounterID))
    self:TraceStep("Boss defeated: " .. tostring(bossLabel))
  else
    self:TraceStep("Boss defeated.")
  end
  local raidSession = self:GetActiveRaidSession()
  if not raidSession then
    return
  end
  local killedAt = GetServerTime()
  local bossEntry = {
    encounterID = encounterID,
    encounterName = encounterName,
    difficultyID = difficultyID,
    groupSize = groupSize,
    killedAt = killedAt,
    loot = {},
  }
  table.insert(raidSession.bosses, bossEntry)
  self.db.session.currentBoss = {
    encounterID = encounterID,
    encounterName = encounterName,
    killedAt = killedAt,
  }
  if self.TouchRaidSession then
    self:TouchRaidSession(raidSession, "boss")
  end
  if self.UI and self.UI.RefreshHistoryIfOpen then
    self.UI:RefreshHistoryIfOpen()
  end
end

function GLD:AutoMarkCurrentGroup()
  if not IsInRaid() then
    return
  end
  local changed = false
  local presentKeys = {}
  local count = GetNumGroupMembers()
  for i = 1, count do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) then
      local shouldTrack = true
      if self.IsTrackedRaidUnit then
        shouldTrack = self:IsTrackedRaidUnit(unit)
      end
      if shouldTrack then
        local playerKey, isNew = self:UpsertPlayerFromUnit(unit)
        if playerKey then
          presentKeys[playerKey] = true
          if isNew then
            changed = true
          end
          if self.db.session.active and not self.db.session.attended[playerKey] then
            local player = self.db.players[playerKey]
            player.attendanceCount = (player.attendanceCount or 0) + 1
            self.db.session.attended[playerKey] = true
            if self.MarkDBChanged then
              self:MarkDBChanged("attendance_count")
            end
          end
          if self.SetAttendance and self:SetAttendance(playerKey, "PRESENT") then
            changed = true
          end
        end
      end
    end
  end

  for key, player in pairs(self.db.players) do
    local state = (player.attendance or ""):upper()
    if state == "PRESENT" and not presentKeys[key] then
      if self.SetAttendance and self:SetAttendance(key, "ABSENT") then
        changed = true
      end
    end
  end
  return changed
end

function GLD:LogRaidAttendanceAudit()
  if not self.db or not self.db.session or not self.db.session.attended then
    return
  end
  if not self.LogAuditEvent then
    return
  end
  for key, present in pairs(self.db.session.attended) do
    if present then
      local player = self.db.players and self.db.players[key]
      local isGuest = false
      if player and self.IsGuestEntry then
        isGuest = self:IsGuestEntry(player)
      end
      local classFile = player and (player.classFile or player.classFileName or player.class)
      local specName = player and (player.specName or player.spec)
      local targetName = player and player.name or key
      self:LogAuditEvent("RAID_ATTENDED", {
        target = targetName,
        isGuest = isGuest,
        class = classFile,
        spec = specName,
      })
    end
  end
end

function GLD:OnGroupRosterUpdate(event)
  if event == "PLAYER_GUILD_UPDATE" and self.OnGuildRosterUpdate then
    self:OnGuildRosterUpdate()
  end
  if (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_GUILD_UPDATE") and self.RequestAuthorityRosterRefresh then
    self:RequestAuthorityRosterRefresh(event)
  end
  local _, _, added = nil, nil, nil
  if self.RebuildGroupRoster then
    _, _, added = self:RebuildGroupRoster()
  end
  if self.RebuildGuestAnchorCandidates then
    self:RebuildGuestAnchorCandidates()
  end
  if self.EvaluateSessionHost then
    self:EvaluateSessionHost("roster")
  end
  if self.WelcomeGuestsFromGroup then
    self:WelcomeGuestsFromGroup()
  end
  local sessionActive = self.db and self.db.session and self.db.session.active == true
  if self:IsAuthority() and sessionActive and IsInRaid() and self.BroadcastActiveRollsSnapshot then
    if added and #added > 0 then
      self:BroadcastActiveRollsSnapshot(added)
    end
  end
  if sessionActive and self.AutoMarkCurrentGroup then
    self:AutoMarkCurrentGroup()
  end
  if self.QueueGroupSpecSync then
    self:QueueGroupSpecSync()
  end
  if self.BroadcastSnapshot then
    self:BroadcastSnapshot()
  end
  if sessionActive and self.CheckSessionZoneStatus then
    self:CheckSessionZoneStatus()
  end
  if self.MaybeAutoAuditAddons then
    self:MaybeAutoAuditAddons()
  end
  if self.UI then
    self.UI:RefreshMain()
  end
end

function GLD:IsSessionActiveLocal()
  if self.IsSessionActive then
    return self:IsSessionActive()
  end
  return self.db and self.db.session and self.db.session.active == true
end

function GLD:InitRaidStateTicker()
  if self.raidStateTicker then
    return
  end
  if not C_Timer or not C_Timer.NewTicker then
    return
  end
  self.raidStateTicker = C_Timer.NewTicker(RAID_STATE_REFRESH_SECONDS, function()
    if self.OnRaidStateTick then
      self:OnRaidStateTick()
    end
  end)
end

function GLD:OnRaidStateTick()
  if not IsInRaid() then
    return
  end

  local sessionActive = self:IsSessionActiveLocal()
  if sessionActive and self:IsAuthority() and self.AutoMarkCurrentGroup then
    local changed = self:AutoMarkCurrentGroup()
    if changed and self.UI then
      self.UI:RefreshMain()
    end
  end

  if not self:IsAuthority() then
    local shouldPing = sessionActive
    if not shouldPing then
      local roster = self.shadow and self.shadow.roster or nil
      if not roster or next(roster) == nil then
        shouldPing = true
      end
    end
    if shouldPing and self.SendRevisionCheck then
      self:SendRevisionCheck()
    end
  end
end
