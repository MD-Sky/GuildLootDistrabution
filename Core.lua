local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = "0.2.3"
NS.COMM_PREFIX = "GLD1"
NS.COVER_COMM_PREFIX = "GLD1COV"
NS.MSG = {
  STATE_SNAPSHOT = "STATE_SNAPSHOT",
  DELTA = "DELTA",
  ROLL_SESSION = "ROLL_SESSION",
  ROLL_VOTE = "ROLL_VOTE",
  ROLL_RESULT = "ROLL_RESULT",
  ROLL_MISMATCH = "ROLL_MISMATCH",
  ROLL_ACK = "ROLL_ACK",
  ROLL_SESSION_REQUEST = "ROLL_SESSION_REQUEST",
  VOTE_CONVERTED = "VOTE_CONVERTED",
  FORCE_PENDING = "FORCE_PENDING",
  SESSION_STATE = "SESSION_STATE",
  HOST_CLAIM = "HOST_CLAIM",
  REQ_END_SESSION = "REQ_END_SESSION",
  END_SESSION = "END_SESSION",
  REV_CHECK = "REV_CHECK",
  ADMIN_REQUEST = "ADMIN_REQUEST",
  NOTICE = "NOTICE",
  HISTORY_DATA = "HISTORY_DATA",
  HISTORY_ACK = "HISTORY_ACK",
  HISTORY_REQ = "HISTORY_REQ",
  PUGS_MODE_SET = "PUGS_MODE_SET",
  GUEST_APPROVED = "GUEST_APPROVED",
  ROLL_PENDING_APPROVAL = "ROLL_PENDING_APPROVAL",
  ROLL_APPROVED = "ROLL_APPROVED",
  ROLL_LOST = "ROLL_LOST",
}

local function SafeGetLib(name)
  if not LibStub then
    return nil
  end
  return LibStub(name, true)
end

local AceAddon = SafeGetLib("AceAddon-3.0")
if not AceAddon then
  DEFAULT_CHAT_FRAME:AddMessage("GuildLootDistribution: Ace3 libraries not found. Add them to Libs/.")
  return
end

local GLD = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
NS.GLD = GLD

function GLD:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GuildLoot|r " .. tostring(msg))
end

function GLD:TraceStep(msg)
  if msg == nil then
    return
  end
  self:Print("Step: " .. tostring(msg))
end

function GLD:IsDebugEnabled()
  local ui = self.GetUIConfig and self:GetUIConfig() or nil
  return ui and ui.debugLogs == true or false
end

function GLD:Debug(msg)
  if not self:IsDebugEnabled() then
    return
  end
  if self.UI and self.UI.AppendDebugLine then
    self.UI:AppendDebugLine(msg)
    return
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GuildLoot|r " .. tostring(msg))
end

function GLD:IsLilyDebugEnabled()
  return self.lilyDebug == true
end

function GLD:LilyDebug(msg)
  if not self:IsLilyDebugEnabled() then
    return
  end
  if self.UI and self.UI.AppendDebugLine then
    self.UI:AppendDebugLine(tostring(msg))
    return
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("[/lilydebug] " .. tostring(msg))
  end
end

function GLD:IsAdmin()
  if self.CanLocalSeeAdminUI then
    return self:CanLocalSeeAdminUI()
  end
  return false
end

function GLD:OnInitialize()
  self:InitDB()
  if self.InitAuthorityManager then
    self:InitAuthorityManager()
  end
  if self.InitTestDB then
    self:InitTestDB()
  end
  if self.lilyDebug == nil then
    self.lilyDebug = false
  end
  self:InitConfig()
  self:InitComms()
  self:InitUI()
  self:InitTestUI()
  self:InitMinimapButton()
  self:InitAttendance()
  self:InitLoot()
  if self.InitSpec then
    self:InitSpec()
  end
  self:RegisterSlashCommands()
end

function GLD:OnEnable()
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "OnGroupRosterUpdate")
  self:RegisterEvent("PARTY_LEADER_CHANGED", "OnGroupRosterUpdate")
  self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnGroupRosterUpdate")
  self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
  self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
  self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
  self:RegisterEvent("INSPECT_READY", "OnInspectReady")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnPlayerSpecChanged")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
  if self.TryCreateGuildUIButton then
    self:TryCreateGuildUIButton()
  end
  if self.InitRaidStateTicker then
    self:InitRaidStateTicker()
  end
  if self.RequestAuthorityRosterRefresh then
    self:RequestAuthorityRosterRefresh("OnEnable")
  end
  self:Print("Commands: /gld (main UI), /disadmin (admin), /gldtest (seed test), /gldadmintest (admin test panel), /glddebug (debug window), /lootauth (authority whitelist), /llydbg (guest anchors debug)")
end

function GLD:RegisterSlashCommands()
  SLASH_GLD1 = "/gld"
  SLASH_GLD2 = "/disloot"
  SlashCmdList["GLD"] = function()
    self.UI:ToggleMain()
  end

  SLASH_GLDTUTORIAL1 = "/gldtutorial"
  SlashCmdList["GLDTUTORIAL"] = function()
    local ui = GLD.GetUIConfig and GLD:GetUIConfig() or nil
    if ui then
      ui.tutorialSeen = false
    end
    GLD.UI:ToggleMain()
    if GLD.UI.Tutorial then
      GLD.UI.Tutorial:Start(true)
    end
  end

  SLASH_DISADMIN1 = "/disadmin"
  SlashCmdList["DISADMIN"] = function()
    if not self.CanAccessAdminUI or not self:CanAccessAdminUI() then
      self:ShowPermissionDeniedPopup()
      return
    end
    self.UI:OpenAdmin()
  end

  SLASH_GLDTEST1 = "/gldtest"
  SlashCmdList["GLDTEST"] = function()
    if not self.CanMutateState or not self:CanMutateState() then
      self:ShowPermissionDeniedPopup()
      return
    end
    self:SeedTestData()
  end

  SLASH_GLDADMINTEST1 = "/gldadmintest"
  SlashCmdList["GLDADMINTEST"] = function()
    if not self.CanAccessAdminUI or not self:CanAccessAdminUI() then
      self:ShowPermissionDeniedPopup()
      return
    end
    NS.TestUI:ToggleTestPanel()
  end

  SLASH_GLDDEBUG1 = "/glddebug"
  SLASH_GLDDEBUG2 = "/gldlogs"
  SlashCmdList["GLDDEBUG"] = function()
    if self.UI and self.UI.ToggleDebugFrame then
      self.UI:ToggleDebugFrame()
    end
  end

  SLASH_LILYDEBUG1 = "/lilydebug"
  SlashCmdList["LILYDEBUG"] = function()
    self.lilyDebug = not self.lilyDebug
    local label = self.lilyDebug and "enabled" or "disabled"
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("[/lilydebug] " .. label)
    end
  end

  SLASH_LLYDBG1 = "/llydbg"
  SlashCmdList["LLYDBG"] = function(msg)
    local dbg = NS.Debug
    if not dbg then
      self:Print("[LLYDBG][CMD] debug module unavailable")
      return
    end

    local input = tostring(msg or ""):match("^%s*(.-)%s*$")
    local command, rest = input:match("^(%S+)%s*(.*)$")
    command = command and command:lower() or ""
    rest = rest and rest:match("^%s*(.-)%s*$") or ""

    if command == "on" then
      dbg:SetEnabled(true)
      self:Print(string.format("[LLYDBG][CMD] enabled=true level=%d", dbg:GetLevel()))
      return
    end
    if command == "off" then
      dbg:SetEnabled(false)
      self:Print(string.format("[LLYDBG][CMD] enabled=false level=%d", dbg:GetLevel()))
      return
    end
    if command == "level" then
      local level = tonumber(rest)
      if level ~= 1 and level ~= 2 then
        self:Print("[LLYDBG][CMD] usage: /llydbg level 1|2")
        return
      end
      dbg:SetLevel(level)
      self:Print(string.format("[LLYDBG][CMD] level=%d", dbg:GetLevel()))
      return
    end
    if command == "echo" then
      local toggle = tostring(rest or ""):lower()
      if toggle == "on" then
        dbg:SetEchoToChat(true)
      elseif toggle == "off" then
        dbg:SetEchoToChat(false)
      else
        self:Print("[LLYDBG][CMD] usage: /llydbg echo on|off")
        return
      end
      self:Print(string.format("[LLYDBG][CMD] echoToChat=%s", tostring(dbg:GetEchoToChat())))
      return
    end
    if command == "clear" then
      if self.UI and self.UI.ClearDebugLog then
        self.UI:ClearDebugLog()
        self:Print("[LLYDBG][CMD] GLDDebug log cleared")
      else
        self:Print("[LLYDBG][CMD] GLDDebug window unavailable")
      end
      return
    end
    if command == "dump" then
      if self.DumpGuestAnchorState then
        self:DumpGuestAnchorState()
      else
        self:Print("[LLYDBG][CMD] dump unavailable")
      end
      return
    end

    self:Print(
      string.format(
        "[LLYDBG][CMD] usage: /llydbg on|off|level 1|2|echo on|off|clear|dump (enabled=%s level=%d echo=%s)",
        tostring(dbg.enabled == true),
        dbg:GetLevel(),
        tostring(dbg:GetEchoToChat())
      )
    )
  end

  SLASH_LOOTAUTH1 = "/lootauth"
  SlashCmdList["LOOTAUTH"] = function(msg)
    if self.HandleLootAuthSlashCommand then
      self:HandleLootAuthSlashCommand(msg)
    end
  end
end
