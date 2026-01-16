local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = "0.1.0"
NS.COMM_PREFIX = "GLD1"
NS.MSG = {
  STATE_SNAPSHOT = "STATE_SNAPSHOT",
  DELTA = "DELTA",
  ROLL_SESSION = "ROLL_SESSION",
  ROLL_VOTE = "ROLL_VOTE",
  ROLL_RESULT = "ROLL_RESULT",
  ROLL_MISMATCH = "ROLL_MISMATCH",
}

local function SafeGetLib(name)
  if not LibStub then
    return nil
  end
  return LibStub(name, true)
end

local AceAddon = SafeGetLib("AceAddon-3.0")
if not AceAddon then
  DEFAULT_CHAT_FRAME:AddMessage("GuildLootDistrabution: Ace3 libraries not found. Add them to Libs/.")
  return
end

local GLD = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
NS.GLD = GLD

function GLD:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GuildLoot|r " .. tostring(msg))
end

function GLD:IsAdmin()
  if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
    return true
  end
  if IsGuildLeader and IsGuildLeader() then
    return true
  end
  if IsInGuild() then
    local _, _, rankIndex = GetGuildInfo("player")
    if rankIndex ~= nil and rankIndex == 0 then
      return true
    end
  end
  return false
end

function GLD:OnInitialize()
  self:InitDB()
  self:InitConfig()
  self:InitComms()
  self:InitUI()
  self:InitTestUI()
  self:InitAttendance()
  self:InitLoot()
  self:RegisterSlashCommands()
end

function GLD:OnEnable()
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnGroupRosterUpdate")
  self:Print("Commands: /gld (main UI), /disadmin (admin), /gldtest (seed test), /gldadmintest (admin test panel)")
end

function GLD:RegisterSlashCommands()
  SLASH_GLD1 = "/gld"
  SLASH_GLD2 = "/disloot"
  SlashCmdList["GLD"] = function()
    self.UI:ToggleMain()
  end

  SLASH_DISADMIN1 = "/disadmin"
  SlashCmdList["DISADMIN"] = function()
    if not self:IsAdmin() then
      self:Print("you do not have Guild Permission to access this panel")
      return
    end
    self.UI:OpenAdmin()
  end

  SLASH_GLDTEST1 = "/gldtest"
  SlashCmdList["GLDTEST"] = function()
    if not self:IsAdmin() then
      self:Print("you do not have Guild Permission to access this panel")
      return
    end
    self:SeedTestData()
  end

  SLASH_GLDADMINTEST1 = "/gldadmintest"
  SlashCmdList["GLDADMINTEST"] = function()
    if not self:IsAdmin() then
      self:Print("you do not have Guild Permission to access this panel")
      return
    end
    NS.TestUI:ToggleTestPanel()
  end
end
