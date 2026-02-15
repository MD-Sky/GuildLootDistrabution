local _, NS = ...

local GLD = NS.GLD

local ACCOUNT_DB_SCHEMA_VERSION = 2
local NO_GUILD_KEY = "NO_GUILD"

local DEFAULT_SHARED_CONFIG = {
  trinketRoleMap = {},
  bossDisabled = {},
  trinketLootRaidId = nil,
  trinketLootRaidName = "The Voidspire",
  trinketLootRole = "DPS",
  transmogWinnerMove = "NONE",
  greedWinnerMove = "NONE",
  officerThresholdRankIndex = 1,
}

local DEFAULT_UI_CONFIG = {
  debugLogs = false,
  tutorialSeen = false,
  tutorialVersion = 1,
  popupDismissed = {},
  minimap = {
    hide = false,
    angle = 220,
  },
}

local UI_CONFIG_FIELDS = {
  debugLogs = true,
  tutorialSeen = true,
  tutorialVersion = true,
  popupDismissed = true,
  minimap = true,
}

local function DeepCopy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local copy = {}
  seen[value] = copy
  for key, entry in pairs(value) do
    copy[DeepCopy(key, seen)] = DeepCopy(entry, seen)
  end
  return copy
end

local function DeepFillMissing(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then
    return false
  end
  local changed = false
  for key, value in pairs(source) do
    if target[key] == nil then
      target[key] = DeepCopy(value)
      changed = true
    elseif type(target[key]) == "table" and type(value) == "table" then
      if DeepFillMissing(target[key], value) then
        changed = true
      end
    end
  end
  return changed
end

local function StableStringify(value, depth)
  depth = (depth or 0) + 1
  if depth > 8 then
    return "<maxdepth>"
  end
  if type(value) ~= "table" then
    return tostring(value)
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = tostring(key) .. "=" .. StableStringify(value[key], depth)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function HasEntries(list)
  return type(list) == "table" and next(list) ~= nil
end

local function CountEntries(list)
  if type(list) ~= "table" then
    return 0
  end
  local count = 0
  for _ in pairs(list) do
    count = count + 1
  end
  return count
end

local function NormalizeGuildToken(value)
  if value == nil then
    return nil
  end
  local text = tostring(value):lower()
  text = text:gsub("%s+", "")
  text = text:gsub("[^%w%-_]", "")
  if text == "" then
    return nil
  end
  return text
end

local function IsLegacyDBPayload(db)
  if type(db) ~= "table" then
    return false
  end
  if type(db.guilds) == "table" and db.players == nil and db.queue == nil and db.session == nil then
    return false
  end
  return type(db.players) == "table"
    or type(db.approvedGuests) == "table"
    or type(db.queue) == "table"
    or type(db.rollHistory) == "table"
    or type(db.raidSessions) == "table"
    or type(db.auditLog) == "table"
    or type(db.session) == "table"
    or type(db.lootSession) == "table"
    or type(db.config) == "table"
end

local function GetLegacyMasterDB()
  if IsLegacyDBPayload(GuildLootDB) then
    return GuildLootDB
  end
  return nil
end

local function StripUIConfigFields(sharedConfig)
  if type(sharedConfig) ~= "table" then
    return
  end
  for key in pairs(UI_CONFIG_FIELDS) do
    sharedConfig[key] = nil
  end
end

local function EnsureGuestDB()
  if not GLT_DB or type(GLT_DB) ~= "table" then
    GLT_DB = {}
  end
  GLT_DB.seenGuests = GLT_DB.seenGuests or {}
  GLT_DB.lastGuestWelcomeAt = GLT_DB.lastGuestWelcomeAt or {}
end

local function EnsureApprovedGuestsFromPlayers(guildDB)
  local now = (GetServerTime and GetServerTime()) or time()
  guildDB.approvedGuests = guildDB.approvedGuests or {}
  for key, player in pairs(guildDB.players or {}) do
    local isGuest = player and (player.isGuest == true or player.source == "guest")
    if isGuest and key and guildDB.approvedGuests[key] == nil then
      guildDB.approvedGuests[key] = {
        key = key,
        guid = player and player.guid or nil,
        name = player and player.name or nil,
        realm = player and player.realm or nil,
        approvedAt = now,
        approvedBy = "migration",
      }
    end
  end
end

local function EnsureGuildDBDefaults(guildDB)
  guildDB.version = guildDB.version or 1
  guildDB.meta = guildDB.meta or {
    revision = 0,
    lastChanged = 0,
  }

  guildDB.config = guildDB.config or {}
  DeepFillMissing(guildDB.config, DEFAULT_SHARED_CONFIG)
  StripUIConfigFields(guildDB.config)

  guildDB.lootRollBlocker = guildDB.lootRollBlocker or {}
  if guildDB.lootRollBlocker.enabled == nil then
    guildDB.lootRollBlocker.enabled = true
  end
  if guildDB.lootRollBlocker.isBlocking == nil then
    guildDB.lootRollBlocker.isBlocking = false
  end
  if guildDB.lootRollBlocker.needsRecovery == nil then
    guildDB.lootRollBlocker.needsRecovery = false
  end

  guildDB.players = guildDB.players or {}
  guildDB.authorityWhitelist = guildDB.authorityWhitelist or {}
  guildDB.approvedGuests = guildDB.approvedGuests or {}
  guildDB.queue = guildDB.queue or {}
  guildDB.rollHistory = guildDB.rollHistory or {}
  guildDB.raidSessions = guildDB.raidSessions or {}
  guildDB.auditLog = guildDB.auditLog or {}
  guildDB.testSessions = guildDB.testSessions or {}
  guildDB.testSession = guildDB.testSession or {
    active = false,
    currentId = nil,
  }

  guildDB.session = guildDB.session or {
    active = false,
    startedAt = 0,
    attended = {},
    raidSessionId = nil,
    pugsInRaid = false,
    currentBoss = nil,
    authorityGUID = nil,
    authorityName = nil,
    hostGUID = nil,
    hostName = nil,
    hostRevision = 0,
    zoneInstanceID = nil,
  }

  guildDB.lootSession = guildDB.lootSession or {
    sessionActive = guildDB.session and guildDB.session.active == true or false,
    sessionId = guildDB.session and guildDB.session.raidSessionId or nil,
    pugsInRaid = guildDB.session and guildDB.session.pugsInRaid == true or false,
  }
  if guildDB.lootSession.sessionActive == nil then
    guildDB.lootSession.sessionActive = guildDB.session and guildDB.session.active == true or false
  end
  if guildDB.lootSession.sessionId == nil then
    guildDB.lootSession.sessionId = guildDB.session and guildDB.session.raidSessionId or nil
  end
  if guildDB.session.pugsInRaid == nil then
    guildDB.session.pugsInRaid = guildDB.lootSession.pugsInRaid == true
  end
  if guildDB.lootSession.pugsInRaid == nil then
    guildDB.lootSession.pugsInRaid = guildDB.session.pugsInRaid == true
  end

  EnsureApprovedGuestsFromPlayers(guildDB)
end

local function EnsureAccountDBRoot()
  if not GuildLootAccountDB or type(GuildLootAccountDB) ~= "table" then
    GuildLootAccountDB = {}
  end

  GuildLootAccountDB.schemaVersion = tonumber(GuildLootAccountDB.schemaVersion) or ACCOUNT_DB_SCHEMA_VERSION
  if GuildLootAccountDB.schemaVersion < ACCOUNT_DB_SCHEMA_VERSION then
    GuildLootAccountDB.schemaVersion = ACCOUNT_DB_SCHEMA_VERSION
  end
  GuildLootAccountDB.guilds = GuildLootAccountDB.guilds or {}
  GuildLootAccountDB.migration = GuildLootAccountDB.migration or {}
  GuildLootAccountDB.migration.byGuild = GuildLootAccountDB.migration.byGuild or {}
  GuildLootAccountDB.migrationBackup = GuildLootAccountDB.migrationBackup or {}

  return GuildLootAccountDB
end

local function EnsureCharDB(legacyDB)
  if not GuildLootCharDB or type(GuildLootCharDB) ~= "table" then
    GuildLootCharDB = {}
  end

  for key in pairs(GuildLootCharDB) do
    if key ~= "ui" then
      GuildLootCharDB[key] = nil
    end
  end
  GuildLootCharDB.ui = GuildLootCharDB.ui or {}

  local legacyConfig = legacyDB and legacyDB.config or nil
  if type(legacyConfig) == "table" then
    if GuildLootCharDB.ui.debugLogs == nil and legacyConfig.debugLogs ~= nil then
      GuildLootCharDB.ui.debugLogs = legacyConfig.debugLogs == true
    end
    if GuildLootCharDB.ui.tutorialSeen == nil and legacyConfig.tutorialSeen ~= nil then
      GuildLootCharDB.ui.tutorialSeen = legacyConfig.tutorialSeen == true
    end
    if GuildLootCharDB.ui.tutorialVersion == nil and legacyConfig.tutorialVersion ~= nil then
      GuildLootCharDB.ui.tutorialVersion = tonumber(legacyConfig.tutorialVersion) or DEFAULT_UI_CONFIG.tutorialVersion
    end
    if GuildLootCharDB.ui.popupDismissed == nil and type(legacyConfig.popupDismissed) == "table" then
      GuildLootCharDB.ui.popupDismissed = DeepCopy(legacyConfig.popupDismissed)
    end
    if GuildLootCharDB.ui.minimap == nil and type(legacyConfig.minimap) == "table" then
      GuildLootCharDB.ui.minimap = DeepCopy(legacyConfig.minimap)
    end
  end

  DeepFillMissing(GuildLootCharDB.ui, DEFAULT_UI_CONFIG)
  GuildLootCharDB.ui.popupDismissed = GuildLootCharDB.ui.popupDismissed or {}
  GuildLootCharDB.ui.minimap = GuildLootCharDB.ui.minimap or {}
  if GuildLootCharDB.ui.minimap.hide == nil then
    GuildLootCharDB.ui.minimap.hide = false
  end
  if GuildLootCharDB.ui.minimap.angle == nil then
    GuildLootCharDB.ui.minimap.angle = 220
  end

  return GuildLootCharDB
end

local function CreateRuntimeShadowState()
  return {
    version = 1,
    meta = {
      revision = 0,
      lastChanged = 0,
    },
    lastSyncAt = 0,
    rosterReceived = false,
    sessionActive = false,
    sessionId = nil,
    pugsInRaid = false,
    my = {
      queuePos = nil,
      savedPos = nil,
      numAccepted = nil,
      attendance = nil,
      attendanceCount = nil,
    },
    roster = {},
  }
end

local function MergeMapMissing(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then
    return 0
  end
  local added = 0
  for key, value in pairs(source) do
    if target[key] == nil then
      target[key] = DeepCopy(value)
      added = added + 1
    end
  end
  return added
end

local function MergeQueueMissing(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then
    return 0
  end
  local seen = {}
  for _, key in ipairs(target) do
    seen[tostring(key)] = true
  end
  local added = 0
  for _, key in ipairs(source) do
    local signature = tostring(key)
    if not seen[signature] then
      target[#target + 1] = key
      seen[signature] = true
      added = added + 1
    end
  end
  return added
end

local function MergeListMissing(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then
    return 0
  end
  local seen = {}
  for _, entry in ipairs(target) do
    seen[StableStringify(entry)] = true
  end
  local added = 0
  for _, entry in ipairs(source) do
    local signature = StableStringify(entry)
    if not seen[signature] then
      target[#target + 1] = DeepCopy(entry)
      seen[signature] = true
      added = added + 1
    end
  end
  return added
end

local function MergeLegacyConfigMissing(targetConfig, legacyConfig)
  if type(targetConfig) ~= "table" or type(legacyConfig) ~= "table" then
    return 0
  end
  local added = 0
  for key, value in pairs(legacyConfig) do
    if not UI_CONFIG_FIELDS[key] and targetConfig[key] == nil then
      targetConfig[key] = DeepCopy(value)
      added = added + 1
    end
  end
  StripUIConfigFields(targetConfig)
  return added
end

local function MergeLegacyIntoGuildDB(guildDB, legacyDB)
  local stats = {
    mapAdds = 0,
    listAdds = 0,
    configAdds = 0,
    sessionAdds = 0,
  }

  stats.configAdds = stats.configAdds + MergeLegacyConfigMissing(guildDB.config, legacyDB.config)

  if type(legacyDB.lootRollBlocker) == "table" then
    if DeepFillMissing(guildDB.lootRollBlocker, legacyDB.lootRollBlocker) then
      stats.sessionAdds = stats.sessionAdds + 1
    end
  end

  stats.mapAdds = stats.mapAdds + MergeMapMissing(guildDB.players, legacyDB.players)
  stats.mapAdds = stats.mapAdds + MergeMapMissing(guildDB.approvedGuests, legacyDB.approvedGuests)

  stats.listAdds = stats.listAdds + MergeQueueMissing(guildDB.queue, legacyDB.queue)
  stats.listAdds = stats.listAdds + MergeListMissing(guildDB.rollHistory, legacyDB.rollHistory)
  stats.listAdds = stats.listAdds + MergeListMissing(guildDB.raidSessions, legacyDB.raidSessions)
  stats.listAdds = stats.listAdds + MergeListMissing(guildDB.auditLog, legacyDB.auditLog)
  stats.listAdds = stats.listAdds + MergeListMissing(guildDB.testSessions, legacyDB.testSessions)

  if type(legacyDB.testSession) == "table" then
    if DeepFillMissing(guildDB.testSession, legacyDB.testSession) then
      stats.sessionAdds = stats.sessionAdds + 1
    end
  end
  if type(legacyDB.session) == "table" then
    if DeepFillMissing(guildDB.session, legacyDB.session) then
      stats.sessionAdds = stats.sessionAdds + 1
    end
  end
  if type(legacyDB.lootSession) == "table" then
    if DeepFillMissing(guildDB.lootSession, legacyDB.lootSession) then
      stats.sessionAdds = stats.sessionAdds + 1
    end
  end
  if type(legacyDB.meta) == "table" then
    if DeepFillMissing(guildDB.meta, legacyDB.meta) then
      stats.sessionAdds = stats.sessionAdds + 1
    end
  end

  EnsureApprovedGuestsFromPlayers(guildDB)
  return stats
end

local function IsGuildDBEmpty(guildDB)
  if type(guildDB) ~= "table" then
    return true
  end
  if HasEntries(guildDB.players) then
    return false
  end
  if HasEntries(guildDB.approvedGuests) then
    return false
  end
  if HasEntries(guildDB.queue) then
    return false
  end
  if HasEntries(guildDB.rollHistory) then
    return false
  end
  if HasEntries(guildDB.raidSessions) then
    return false
  end
  if HasEntries(guildDB.auditLog) then
    return false
  end
  if HasEntries(guildDB.testSessions) then
    return false
  end
  local session = guildDB.session
  if type(session) == "table" then
    if session.active == true then
      return false
    end
    if session.raidSessionId ~= nil then
      return false
    end
    if HasEntries(session.attended) then
      return false
    end
  end
  return true
end

local function BuildFallbackGuildKey()
  local guildName, _, _, realmName = GetGuildInfo("player")
  if not guildName or guildName == "" then
    return NO_GUILD_KEY
  end
  realmName = realmName or GetRealmName() or "unknownrealm"
  local normalizedGuild = NormalizeGuildToken(guildName) or "unknownguild"
  local normalizedRealm = NormalizeGuildToken(realmName) or "unknownrealm"
  return "name:" .. normalizedGuild .. "-" .. normalizedRealm
end

local function LogDBDebug(self, msg)
  if self and self.IsDebugEnabled and self:IsDebugEnabled() and self.Debug then
    self:Debug("[DB] " .. tostring(msg))
    return
  end
  if self and self.IsLilyDebugEnabled and self:IsLilyDebugEnabled() and self.LilyDebug then
    self:LilyDebug("[DB] " .. tostring(msg))
  end
end

function GLD:GetCurrentGuildKey()
  local guildClubId = nil
  if C_Club and C_Club.GetGuildClubId then
    guildClubId = C_Club.GetGuildClubId()
  end
  if guildClubId and guildClubId ~= 0 then
    return "club:" .. tostring(guildClubId)
  end
  return BuildFallbackGuildKey()
end

function GLD:GetGuildDB(guildKey)
  if not self.accountDB or type(self.accountDB) ~= "table" then
    self.accountDB = EnsureAccountDBRoot()
  end
  local resolvedKey = guildKey and tostring(guildKey) or NO_GUILD_KEY
  if resolvedKey == "" then
    resolvedKey = NO_GUILD_KEY
  end
  self.accountDB.guilds = self.accountDB.guilds or {}
  local guildDB = self.accountDB.guilds[resolvedKey]
  local created = false
  if type(guildDB) ~= "table" then
    guildDB = {}
    self.accountDB.guilds[resolvedKey] = guildDB
    created = true
  end
  EnsureGuildDBDefaults(guildDB)
  return guildDB, created
end

function GLD:GetActiveDB()
  return self.db
end

function GLD:GetActiveGuildKey()
  return self.activeGuildKey or NO_GUILD_KEY
end

function GLD:GetUIConfig()
  if not self.charDB or type(self.charDB) ~= "table" then
    self.charDB = EnsureCharDB(GetLegacyMasterDB())
  end
  self.charDB.ui = self.charDB.ui or {}
  DeepFillMissing(self.charDB.ui, DEFAULT_UI_CONFIG)
  return self.charDB.ui
end

function GLD:InitDB()
  local legacyDB = GetLegacyMasterDB()

  self.accountDB = EnsureAccountDBRoot()
  self.charDB = EnsureCharDB(legacyDB)
  self.shadow = CreateRuntimeShadowState()

  EnsureGuestDB()
  self.guestDB = GLT_DB

  local guildKey = self:GetCurrentGuildKey()
  local guildDB, createdPartition = self:GetGuildDB(guildKey)
  local wasEmpty = IsGuildDBEmpty(guildDB)

  local migration = self.accountDB.migration or {}
  migration.byGuild = migration.byGuild or {}
  self.accountDB.migration = migration
  local migrationState = migration.byGuild[guildKey]
  if type(migrationState) ~= "table" then
    migrationState = {}
    migration.byGuild[guildKey] = migrationState
  end

  local migrationRan = false
  if legacyDB and migrationState.complete ~= true then
    migrationRan = true
    if self.accountDB.migrationBackup[guildKey] == nil then
      self.accountDB.migrationBackup[guildKey] = DeepCopy(legacyDB)
    end
    local stats = MergeLegacyIntoGuildDB(guildDB, legacyDB)
    EnsureGuildDBDefaults(guildDB)

    migrationState.complete = true
    migrationState.completedAt = (GetServerTime and GetServerTime()) or time()
    migrationState.source = "GuildLootDB"
    migrationState.mode = wasEmpty and "copy_merge" or "merge_missing"
    migrationState.stats = stats

    LogDBDebug(
      self,
      string.format(
        "migration ran for key=%s mode=%s mapAdds=%d listAdds=%d configAdds=%d sessionAdds=%d",
        tostring(guildKey),
        tostring(migrationState.mode),
        tonumber(stats.mapAdds) or 0,
        tonumber(stats.listAdds) or 0,
        tonumber(stats.configAdds) or 0,
        tonumber(stats.sessionAdds) or 0
      )
    )
  end

  self.db = guildDB
  self.activeGuildKey = guildKey
  self.isNoGuildPartition = guildKey == NO_GUILD_KEY

  LogDBDebug(self, "resolved guildKey=" .. tostring(guildKey))
  LogDBDebug(self, "active partition=" .. tostring(guildKey) .. " created=" .. tostring(createdPartition))
  LogDBDebug(self, "active partition rosterSize=" .. tostring(CountEntries(self.db.players)))
  if not migrationRan then
    LogDBDebug(self, "migration ran=false for key=" .. tostring(guildKey))
  end
end

function GLD:MarkDBChanged(reason)
  if not self.db then
    return
  end
  self.db.meta = self.db.meta or {}
  self.db.meta.revision = (tonumber(self.db.meta.revision) or 0) + 1
  self.db.meta.lastChanged = (GetServerTime and GetServerTime() or time())
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    local label = reason and (" reason=" .. tostring(reason)) or ""
    self:Debug("DB revision bumped to " .. tostring(self.db.meta.revision) .. label)
  end
end

local AUDIT_LOG_MAX = 5000

function GLD:AppendAuditLog(entry)
  if not self.db then
    return
  end
  self.db.auditLog = self.db.auditLog or {}
  table.insert(self.db.auditLog, 1, entry)
  if #self.db.auditLog > AUDIT_LOG_MAX then
    for i = #self.db.auditLog, AUDIT_LOG_MAX + 1, -1 do
      table.remove(self.db.auditLog, i)
    end
  end
end

function GLD:LogAuditEvent(eventType, data)
  if not self.db then
    return
  end
  local entry = {
    timestamp = GetServerTime(),
    type = eventType,
    actor = data and data.actor or nil,
    target = data and data.target or nil,
    isGuest = data and data.isGuest or nil,
    class = data and data.class or nil,
    spec = data and data.spec or nil,
    playerKey = data and (data.playerKey or data.rosterKey or data.key or data.id) or nil,
    details = data and data.details or nil,
  }
  self:AppendAuditLog(entry)
end

function GLD:GetConfig()
  if not self.db then
    return nil
  end
  self.db.config = self.db.config or {}
  DeepFillMissing(self.db.config, DEFAULT_SHARED_CONFIG)
  StripUIConfigFields(self.db.config)
  return self.db.config
end
