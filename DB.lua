local _, NS = ...

local GLD = NS.GLD

local DEFAULT_CONFIG = {
  trinketRoleMap = {},
  bossDisabled = {},
  transmogWinnerMove = "END",
  greedWinnerMove = "NONE",
}

local function InitMasterDB()
  if not GuildLootDB or type(GuildLootDB) ~= "table" then
    GuildLootDB = {}
  end

  GuildLootDB.version = GuildLootDB.version or 1
  GuildLootDB.config = GuildLootDB.config or DEFAULT_CONFIG
  GuildLootDB.players = GuildLootDB.players or {}
  GuildLootDB.queue = GuildLootDB.queue or {}
  GuildLootDB.rollHistory = GuildLootDB.rollHistory or {}
  GuildLootDB.session = GuildLootDB.session or {
    active = false,
    startedAt = 0,
    attended = {},
  }
end

local function InitShadowDB()
  if not GuildLootShadow or type(GuildLootShadow) ~= "table" then
    GuildLootShadow = {}
  end

  GuildLootShadow.version = GuildLootShadow.version or 1
  GuildLootShadow.lastSyncAt = GuildLootShadow.lastSyncAt or 0
  GuildLootShadow.my = GuildLootShadow.my or {
    queuePos = nil,
    savedPos = nil,
    numAccepted = nil,
    attendance = nil,
    attendanceCount = nil,
  }
  GuildLootShadow.roster = GuildLootShadow.roster or {}
end

function GLD:InitDB()
  InitMasterDB()
  InitShadowDB()
  self.db = GuildLootDB
  self.shadow = GuildLootShadow
end

function GLD:GetConfig()
  return self.db.config
end
