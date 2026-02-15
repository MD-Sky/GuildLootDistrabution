local _, NS = ...

local GLD = NS.GLD

local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS
local ROLE_ICON_TCOORDS = {
  TANK = {0, 19/64, 22/64, 41/64},
  HEALER = {20/64, 39/64, 1/64, 20/64},
  DAMAGER = {20/64, 39/64, 22/64, 41/64},
  NONE = {0, 0, 0, 0},
}

local function IsFlagTrue(value)
  if value == true then
    return true
  end
  local valueType = type(value)
  if valueType == "number" then
    return value ~= 0
  end
  if valueType == "string" then
    local lowered = value:lower()
    return lowered == "true" or lowered == "1" or lowered == "yes"
  end
  return false
end

local function GetRankName(index)
  if index == nil then
    return nil
  end
  if C_GuildInfo and C_GuildInfo.GuildControlGetRankName then
    return C_GuildInfo.GuildControlGetRankName(index)
  end
  if GuildControlGetRankName then
    return GuildControlGetRankName(index)
  end
  return nil
end

function NS:SplitNameRealm(name)
  if not name or name == "" then
    return nil, nil
  end
  local base, realm = strsplit("-", name)
  if not realm or realm == "" then
    realm = GetRealmName()
  end
  return base, realm
end

function NS:GetPlayerKeyFromUnit(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  local guid = UnitGUID(unit)
  if guid and guid ~= "" then
    return guid
  end
  local name, realm = UnitName(unit)
  if not name then
    return nil
  end
  if not realm or realm == "" then
    realm = GetRealmName()
  end
  return name .. "-" .. realm
end

function GLD:GetUnitFullName(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  local name, realm = UnitName(unit)
  if not name or name == "" then
    return nil
  end
  if realm and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

if _G and _G.BuildSessionVoteSnapshot == nil then
  function _G.BuildSessionVoteSnapshot(session, state, entryKey)
    local votes = {}
    if session and session.votes then
      for k, v in pairs(session.votes) do
        local canon = (GLD and GLD.GetRollCandidateKey and GLD:GetRollCandidateKey(k)) or k
        if canon and votes[canon] == nil then
          votes[canon] = v
        end
      end
    end
    if state and state.demoMode and state.demoVotes and entryKey then
      local localKey = NS and NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
      if localKey and state.demoVotes[entryKey] then
        votes[localKey] = state.demoVotes[entryKey]
      end
    end
    return votes
  end
end

function GLD:GetOurGuildName()
  local name = GetGuildInfo("player")
  if name and name ~= "" then
    return name
  end
  return nil
end

local DEBUG_AUTH = false
local OFFICER_FLAG_KEYS = { "isOfficer" }
local GUILD_MASTER_FLAG_KEYS = { "isGM", "isGuildMaster" }
local OFFICER_PROXY_FLAG_KEYS = {
  "canViewOfficerNote",
  "canEditOfficerNote",
  "viewOffNote",
  "editOffNote",
  "canViewOffNote",
  "canEditOffNote",
}

local function TrimToNil(value)
  if value == nil then
    return nil
  end
  local text = tostring(value)
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  if text == "" then
    return nil
  end
  return text
end

local function NormalizeAuthorityRealm(realm)
  local raw = TrimToNil(realm)
  if raw and raw ~= "" then
    return raw
  end
  return GetRealmName()
end

local function LowerString(value)
  if value == nil then
    return nil
  end
  return string.lower(tostring(value))
end

local function ToAdminDenyReason(reason)
  if reason == "not_in_guild" then
    return "not in guild"
  end
  if reason == "not_in_roster" or reason == "roster_not_ready" then
    return "not in roster"
  end
  if reason == "not_officer" then
    return "not officer"
  end
  return tostring(reason or "not authorized")
end

local function FirstKnownFlag(flags, keys)
  if type(flags) ~= "table" then
    return false, nil
  end
  for _, key in ipairs(keys) do
    if flags[key] ~= nil then
      return true, IsFlagTrue(flags[key])
    end
  end
  return false, nil
end

local function ReadOfficerProxyFlag(flags)
  if type(flags) ~= "table" then
    return false, nil
  end
  for _, key in ipairs(OFFICER_PROXY_FLAG_KEYS) do
    if flags[key] ~= nil then
      return true, IsFlagTrue(flags[key])
    end
  end
  if flags[11] ~= nil or flags[12] ~= nil then
    return true, IsFlagTrue(flags[11]) or IsFlagTrue(flags[12])
  end
  return false, nil
end

local function HasOfficerSignal(flags)
  local hasOfficerField = select(1, FirstKnownFlag(flags, OFFICER_FLAG_KEYS))
  if hasOfficerField then
    return true
  end
  return select(1, ReadOfficerProxyFlag(flags))
end

local function NormalizeRankFlagsResult(...)
  local count = select("#", ...)
  if count <= 0 then
    return nil
  end
  if count == 1 then
    local value = ...
    if value == nil then
      return nil
    end
    if type(value) == "table" then
      return value
    end
  end
  return { ... }
end

local function FetchRankFlagsByIndex(rankIndex)
  if rankIndex == nil then
    return nil
  end
  local numericRank = tonumber(rankIndex)
  if not numericRank then
    return nil
  end
  local fetch = nil
  if GuildControlGetRankFlags then
    fetch = GuildControlGetRankFlags
  elseif C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags then
    fetch = C_GuildInfo.GuildControlGetRankFlags
  end
  if not fetch then
    return nil
  end
  return NormalizeRankFlagsResult(fetch(numericRank))
end

function GLD:IsLlyDebugEnabled()
  local dbg = NS and NS.Debug or nil
  return dbg and dbg.enabled == true or false
end

function GLD:DebugOfficerAuthority(message, ...)
  local dbg = NS and NS.Debug or nil
  if not (dbg and dbg.enabled == true and dbg.Print) then
    return
  end
  dbg:Print("AUTH", message, ...)
end

function GLD:NormalizeGuildMemberFullName(name, realm)
  local cleanName = TrimToNil(name)
  if not cleanName then
    return nil
  end
  cleanName = cleanName:gsub("%s*%-%s*", "-")
  if Ambiguate then
    cleanName = Ambiguate(cleanName, "none") or cleanName
  end
  local baseName, parsedRealm = strsplit("-", cleanName, 2)
  baseName = TrimToNil(baseName)
  if not baseName then
    return nil
  end
  local fullRealm = NormalizeAuthorityRealm(realm or parsedRealm)
  if fullRealm and fullRealm ~= "" then
    return baseName .. "-" .. fullRealm
  end
  return baseName
end

function GLD:GetGuildRankFlags(rankIndex, rankName)
  local numericRank = tonumber(rankIndex)
  if numericRank == nil then
    return nil
  end

  local directFlags = FetchRankFlagsByIndex(numericRank)
  local altFlags = FetchRankFlagsByIndex(numericRank + 1)

  if rankName then
    local directName = GetRankName(numericRank)
    if directName and directName == rankName then
      return directFlags
    end
    local altName = GetRankName(numericRank + 1)
    if altName and altName == rankName then
      return altFlags
    end
  end

  if directFlags and not altFlags then
    return directFlags
  end
  if altFlags and not directFlags then
    return altFlags
  end
  if HasOfficerSignal(directFlags) and not HasOfficerSignal(altFlags) then
    return directFlags
  end
  if HasOfficerSignal(altFlags) and not HasOfficerSignal(directFlags) then
    return altFlags
  end
  return directFlags or altFlags
end

function GLD:EvaluateGuildRankOfficerStatus(rankIndex, rankName, options)
  local numericRank = tonumber(rankIndex)
  if numericRank == nil then
    return false, false, "invalid_rank", {
      rankIndex = rankIndex,
      rankName = rankName,
    }
  end

  local isGuildMaster = numericRank == 0
  local isOfficer = false
  local source = "none"
  local flags = self:GetGuildRankFlags(numericRank, rankName)
  local hasOfficerField, officerFlag = FirstKnownFlag(flags, OFFICER_FLAG_KEYS)
  local hasGuildMasterField, guildMasterFlag = FirstKnownFlag(flags, GUILD_MASTER_FLAG_KEYS)
  if hasGuildMasterField then
    isGuildMaster = isGuildMaster or guildMasterFlag
  end
  if hasOfficerField then
    isOfficer = officerFlag == true
    source = "isOfficer_flag"
  else
    local hasProxy, proxyIsOfficer = ReadOfficerProxyFlag(flags)
    if hasProxy then
      isOfficer = proxyIsOfficer == true
      source = "permission_proxy"
    end
  end

  local allowLocalFallback = type(options) == "table" and options.allowLocalAPIFallback == true
  if source == "none" and allowLocalFallback then
    if C_GuildInfo and C_GuildInfo.IsGuildOfficer then
      isOfficer = IsFlagTrue(C_GuildInfo.IsGuildOfficer())
      source = "local_api_fallback"
    elseif IsGuildOfficer then
      isOfficer = IsFlagTrue(IsGuildOfficer())
      source = "local_api_fallback"
    end
  end

  return isOfficer, isGuildMaster, source, {
    rankIndex = numericRank,
    rankName = rankName,
    hasOfficerField = hasOfficerField,
    hasGuildMasterField = hasGuildMasterField,
    source = source,
  }
end

function GLD:IsGuildRankOfficerOrGM(rankIndex, rankName)
  local isOfficer, isGuildMaster = self:EvaluateGuildRankOfficerStatus(rankIndex, rankName, {
    allowLocalAPIFallback = true,
  })
  return isOfficer == true, isGuildMaster == true
end

function GLD:IsGuildAuthorityRank(rankIndex)
  local isOfficer, isGuildMaster = self:IsGuildRankOfficerOrGM(rankIndex, nil)
  return isGuildMaster or isOfficer
end

function GLD:GetGuildOfficerRosterCache()
  self._guildOfficerRosterCache = self._guildOfficerRosterCache or {
    rankByName = {},
    rankNameByName = {},
    nameByLookup = {},
    builtAt = 0,
    count = 0,
    ready = false,
    serial = 0,
    reason = "init",
  }
  return self._guildOfficerRosterCache
end

function GLD:RebuildGuildOfficerRosterCache(reason)
  local cache = self:GetGuildOfficerRosterCache()
  if not IsInGuild() then
    cache.rankByName = {}
    cache.rankNameByName = {}
    cache.nameByLookup = {}
    cache.count = 0
    cache.ready = false
    cache.builtAt = (GetServerTime and GetServerTime()) or time()
    cache.serial = (cache.serial or 0) + 1
    cache.reason = "not_in_guild"
    return false
  end
  if not GetNumGuildMembers or not GetGuildRosterInfo then
    return false
  end

  local count = GetNumGuildMembers() or 0
  if count <= 0 then
    cache.rankByName = {}
    cache.rankNameByName = {}
    cache.nameByLookup = {}
    cache.count = 0
    cache.ready = false
    cache.builtAt = (GetServerTime and GetServerTime()) or time()
    cache.serial = (cache.serial or 0) + 1
    cache.reason = "roster_empty"
    return false
  end

  local rankByName = {}
  local rankNameByName = {}
  local nameByLookup = {}
  for i = 1, count do
    local name, rankName, rankIndex = GetGuildRosterInfo(i)
    local normalized = self:NormalizeGuildMemberFullName(name)
    local numericRank = tonumber(rankIndex)
    if normalized and numericRank ~= nil then
      rankByName[normalized] = numericRank
      rankNameByName[normalized] = rankName
      nameByLookup[LowerString(normalized)] = normalized
    end
  end

  cache.rankByName = rankByName
  cache.rankNameByName = rankNameByName
  cache.nameByLookup = nameByLookup
  cache.count = count
  cache.ready = true
  cache.builtAt = (GetServerTime and GetServerTime()) or time()
  cache.serial = (cache.serial or 0) + 1
  cache.reason = reason or "manual"
  return true
end

function GLD:IsNameGuildOfficer(fullName)
  local normalized = self:NormalizeGuildMemberFullName(fullName)
  if not normalized then
    return false, "invalid_name", {
      fullName = fullName,
      normalizedName = nil,
      rosterMatch = false,
      isOfficer = false,
      isGuildMaster = false,
    }
  end
  if not IsInGuild() then
    return false, "not_in_guild", {
      fullName = fullName,
      normalizedName = normalized,
      rosterMatch = false,
      isOfficer = false,
      isGuildMaster = false,
    }
  end

  local cache = self:GetGuildOfficerRosterCache()
  if cache.ready ~= true then
    self:RebuildGuildOfficerRosterCache("IsNameGuildOfficer")
    cache = self:GetGuildOfficerRosterCache()
  end
  if cache.ready ~= true then
    if self.RequestAuthorityRosterRefresh then
      self:RequestAuthorityRosterRefresh("IsNameGuildOfficer")
    end
    return false, "roster_not_ready", {
      fullName = fullName,
      normalizedName = normalized,
      rosterMatch = false,
      isOfficer = false,
      isGuildMaster = false,
    }
  end

  local canonical = cache.rankByName[normalized] and normalized or nil
  if not canonical then
    canonical = cache.nameByLookup[LowerString(normalized)]
  end
  if not canonical then
    return false, "not_in_roster", {
      fullName = fullName,
      normalizedName = normalized,
      rosterMatch = false,
      isOfficer = false,
      isGuildMaster = false,
    }
  end

  local rankIndex = cache.rankByName[canonical]
  local rankName = cache.rankNameByName and cache.rankNameByName[canonical] or nil
  local isOfficer, isGuildMaster, source, statusDetails = self:EvaluateGuildRankOfficerStatus(rankIndex, rankName, {
    allowLocalAPIFallback = false,
  })
  local allowed = isGuildMaster or isOfficer
  local reason = allowed and (isGuildMaster and "guild_master" or "officer") or "not_officer"
  return allowed, reason, {
    fullName = fullName,
    normalizedName = canonical,
    rosterMatch = true,
    rankIndex = rankIndex,
    rankName = rankName,
    isOfficer = isOfficer == true,
    isGuildMaster = isGuildMaster == true,
    rankStatusSource = source,
    rankStatusDetails = statusDetails,
  }
end

function GLD:IsUnitGuildOfficer(unit)
  local resolvedUnit = unit or "player"
  local guildName, rankName, rankIndex = GetGuildInfo(resolvedUnit)
  local details = {
    unit = resolvedUnit,
    guildName = guildName,
    rankName = rankName,
    rankIndex = rankIndex,
    isOfficer = false,
    isGuildMaster = false,
  }
  if not IsInGuild() then
    return false, "not_in_guild", details
  end
  if not resolvedUnit or not UnitExists(resolvedUnit) then
    return false, "unit_missing", details
  end
  local ourGuild = self:GetOurGuildName()
  if not guildName or not ourGuild or guildName ~= ourGuild then
    return false, "not_in_guild", details
  end

  local allowLocalFallback = UnitIsUnit and UnitIsUnit(resolvedUnit, "player") or false
  local isOfficer, isGuildMaster, source, statusDetails = self:EvaluateGuildRankOfficerStatus(rankIndex, rankName, {
    allowLocalAPIFallback = allowLocalFallback,
  })
  details.rankStatusSource = source
  details.rankStatusDetails = statusDetails
  details.isOfficer = isOfficer == true
  details.isGuildMaster = isGuildMaster == true

  local allowed = details.isGuildMaster or details.isOfficer
  local reason = allowed and (details.isGuildMaster and "guild_master" or "officer") or "not_officer"
  return allowed, reason, details
end

function GLD:GetUnitAuthorityContext(unit)
  local resolvedUnit = unit or "player"
  local playerName = nil
  local playerRealm = GetRealmName()
  local playerGUID = nil
  local authorityName = nil
  local guildRankName = nil
  local guildRankIndex = nil
  local computedAuthority = false
  local authorityReason = nil
  local authorityDetails = nil

  if UnitExists(resolvedUnit) then
    playerName, playerRealm = UnitName(resolvedUnit)
    if not playerRealm or playerRealm == "" then
      playerRealm = GetRealmName()
    end
    playerGUID = UnitGUID(resolvedUnit)
    local _, rankName, rankIndex = GetGuildInfo(resolvedUnit)
    guildRankName = rankName
    guildRankIndex = rankIndex
    authorityName = self.GetUnitFullName and self:GetUnitFullName(resolvedUnit) or nil
    if (not authorityName or authorityName == "") and playerName then
      authorityName = self:NormalizeGuildMemberFullName(playerName, playerRealm)
    end
  end

  local allowed, reason, details = self:IsUnitGuildOfficer(resolvedUnit)
  computedAuthority = allowed == true
  authorityReason = reason
  authorityDetails = details

  return {
    unit = resolvedUnit,
    playerName = playerName,
    playerRealm = playerRealm,
    playerGUID = playerGUID,
    authorityName = authorityName,
    authorityReason = authorityReason,
    authorityDetails = authorityDetails,
    guildRankIndex = guildRankIndex,
    guildRankName = guildRankName,
    computedAuthority = computedAuthority,
  }
end

function GLD:IsAuthDebugEnabled()
  return DEBUG_AUTH or (self.db and self.db.debugAuth == true)
end

function GLD:DebugAuth(reason, source, context)
  if not self.IsAuthDebugEnabled or not self:IsAuthDebugEnabled() then
    return
  end
  local auth = context
  if type(auth) ~= "table" then
    auth = self:GetUnitAuthorityContext("player")
  end
  local message = string.format(
    "AuthDebug reason=%s source=%s authorityName=%s authReason=%s playerName=%s playerRealm=%s playerGUID=%s guildRankIndex=%s guildRankName=%s computedAuthority=%s",
    tostring(reason or "unknown"),
    tostring(source or "unknown"),
    tostring(auth.authorityName),
    tostring(auth.authorityReason),
    tostring(auth.playerName),
    tostring(auth.playerRealm),
    tostring(auth.playerGUID),
    tostring(auth.guildRankIndex),
    tostring(auth.guildRankName),
    tostring(auth.computedAuthority)
  )
  if self.Debug then
    self:Debug(message)
  elseif self.Print then
    self:Print(message)
  end
end

function GLD:IsLocalGuildOfficerOrGM()
  local allowed, _, details = self:IsUnitGuildOfficer("player")
  return allowed == true,
    details and details.isOfficer == true or false,
    details and details.isGuildMaster == true or false,
    details and details.rankIndex or nil,
    details and details.rankName or nil
end

function GLD:CanLocalSeeAdminUI()
  local allowed, reason, details = self:IsUnitGuildOfficer("player")
  local humanReason = ToAdminDenyReason(reason)
  self:DebugOfficerAuthority(
    "local_admin rankIndex=%s isOfficer=%s isGuildMaster=%s result=%s reason=%s",
    tostring(details and details.rankIndex),
    tostring(details and details.isOfficer == true),
    tostring(details and details.isGuildMaster == true),
    tostring(allowed == true),
    tostring(humanReason)
  )
  if allowed ~= true then
    self:DebugOfficerAuthority("admin_denied reason=%s", tostring(humanReason))
  end
  local context = {
    unit = "player",
    playerName = UnitName("player"),
    playerRealm = GetRealmName(),
    playerGUID = UnitGUID("player"),
    authorityName = self.GetUnitFullName and self:GetUnitFullName("player") or UnitName("player"),
    authorityReason = humanReason,
    authorityDetails = details,
    guildRankIndex = details and details.rankIndex or nil,
    guildRankName = details and details.rankName or nil,
    computedAuthority = allowed == true,
  }
  if self.DebugAuth then
    self:DebugAuth("CanAccessAdminUI", "Utils.CanLocalSeeAdminUI", context)
  end
  return allowed == true
end

function GLD:ShouldShowGuestNotice()
  local canAccess = self.CanAccessAdminUI and self:CanAccessAdminUI() or false
  return not canAccess
end

function GLD:ShowPermissionDeniedPopup()
  local message = "You do not have Guild Permission to access this panel."
  if NS and NS.UI and NS.UI.ShowPopup then
    NS.UI:ShowPopup("lilyUI", message)
    return
  end
  if self.Print then
    self:Print(message)
  end
end

function GLD:ShowGuestNotice(bodyText, options)
  if not bodyText or bodyText == "" then
    return false
  end
  if self.ShouldShowGuestNotice and not self:ShouldShowGuestNotice() then
    return false
  end
  if NS and NS.UI and NS.UI.ShowPopup then
    NS.UI:ShowPopup((options and options.title) or "lilyUI", bodyText, options)
    return true
  end
  if self.Print then
    self:Print(bodyText)
  end
  return true
end

function GLD:GetGuestWelcomeText()
  return "Guest mode: View + Request only.\nUse /gld to open the loot window.\nAsk an officer if you need admin access."
end

local function NormalizeRealmName(realm)
  if realm and realm ~= "" then
    return realm
  end
  return GetRealmName()
end

local function NamesMatch(nameA, realmA, nameB, realmB)
  if not nameA or not nameB then
    return false
  end
  if tostring(nameA) ~= tostring(nameB) then
    return false
  end
  return NormalizeRealmName(realmA) == NormalizeRealmName(realmB)
end

function GLD:IsGuest(unitOrMember)
  local ourGuild = self:GetOurGuildName()
  if type(unitOrMember) == "table" then
    if unitOrMember.isGuest ~= nil then
      return unitOrMember.isGuest
    end
    if unitOrMember.source ~= nil then
      return unitOrMember.source == "guest"
    end
    if unitOrMember.member then
      return self:IsGuest(unitOrMember.member)
    end
    if unitOrMember.unit then
      local guildName = GetGuildInfo(unitOrMember.unit)
      if not ourGuild then
        return true
      end
      return not guildName or guildName ~= ourGuild
    end
    return false
  end

  if type(unitOrMember) == "string" and UnitExists(unitOrMember) then
    local guildName = GetGuildInfo(unitOrMember)
    if not ourGuild then
      return true
    end
    return not guildName or guildName ~= ourGuild
  end

  return false
end

function GLD:IsGuestEntry(player)
  if not player then
    return false
  end
  if player.isGuest ~= nil then
    return player.isGuest == true
  end
  return player.source == "guest"
end

function GLD:GetGuestRosterKey(guid, name, realm)
  if guid and guid ~= "" then
    return guid
  end
  if name and name ~= "" then
    return tostring(name) .. "-" .. NormalizeRealmName(realm)
  end
  return nil
end

function GLD:IsUnitInOurGuild(unit)
  if not unit or not UnitExists(unit) then
    return false
  end
  if UnitIsInMyGuild then
    return UnitIsInMyGuild(unit) == true
  end
  local ourGuild = self:GetOurGuildName()
  if not ourGuild then
    return false
  end
  local guildName = GetGuildInfo(unit)
  return guildName and guildName == ourGuild or false
end

function GLD:FindGuestPlayerKeyByIdentity(guid, name, realm)
  if not self.db or not self.db.players then
    return nil
  end
  local realmName = NormalizeRealmName(realm)
  if guid and guid ~= "" then
    local byGuid = self.db.players[guid]
    if byGuid and self:IsGuestEntry(byGuid) then
      return guid
    end
  end
  local fallback = self:GetGuestRosterKey(nil, name, realmName)
  if fallback and self.db.players[fallback] and self:IsGuestEntry(self.db.players[fallback]) then
    return fallback
  end
  for key, player in pairs(self.db.players) do
    if player and self:IsGuestEntry(player) then
      if guid and guid ~= "" then
        if player.guid and player.guid == guid then
          return key
        end
      end
      if name and player.name and NamesMatch(player.name, player.realm, name, realmName) then
        return key
      end
    end
  end
  return nil
end

function GLD:FindApprovedGuestEntry(guid, name, realm)
  if not self.db then
    return nil, nil
  end
  self.db.approvedGuests = self.db.approvedGuests or {}
  local approved = self.db.approvedGuests
  local realmName = NormalizeRealmName(realm)

  if guid and guid ~= "" and approved[guid] then
    return approved[guid], guid
  end
  local fallback = self:GetGuestRosterKey(nil, name, realmName)
  if fallback and approved[fallback] then
    return approved[fallback], fallback
  end
  for key, entry in pairs(approved) do
    if entry then
      if guid and guid ~= "" and entry.guid and entry.guid == guid then
        return entry, key
      end
      if name and entry.name and NamesMatch(entry.name, entry.realm, name, realmName) then
        return entry, key
      end
    end
  end

  local existingKey = self:FindGuestPlayerKeyByIdentity(guid, name, realmName)
  if existingKey then
    local player = self.db.players and self.db.players[existingKey] or nil
    if player and self:IsGuestEntry(player) then
      return {
        key = existingKey,
        guid = player.guid or guid,
        name = player.name or name,
        realm = player.realm or realmName,
      }, existingKey
    end
  end
  return nil, nil
end

function GLD:IsApprovedGuestKey(key)
  if not key or not self.db then
    return false
  end
  self.db.approvedGuests = self.db.approvedGuests or {}
  if self.db.approvedGuests[key] then
    return true
  end
  local player = self.db.players and self.db.players[key] or nil
  return player and self:IsGuestEntry(player) or false
end

function GLD:IsApprovedGuestUnit(unit)
  if not unit or not UnitExists(unit) then
    return false, nil
  end
  local guid = UnitGUID(unit)
  local name, realm = UnitName(unit)
  local _, key = self:FindApprovedGuestEntry(guid, name, realm)
  if key then
    return true, key
  end
  local roster = self.shadow and self.shadow.roster or nil
  if type(roster) == "table" then
    local fullName = self:GetUnitFullName(unit)
    local realmName = NormalizeRealmName(realm)
    for _, entry in pairs(roster) do
      if type(entry) == "table" and (entry.isGuest == true or entry.source == "guest") then
        local entryKey = entry.key or entry.playerKey
        if guid and entryKey and entryKey == guid then
          return true, entryKey
        end
        if entry.name and NamesMatch(entry.name, entry.realm, name, realmName) then
          return true, entryKey or (entry.name .. "-" .. NormalizeRealmName(entry.realm))
        end
        if fullName and entry.name and entry.realm and (entry.name .. "-" .. entry.realm) == fullName then
          return true, entryKey or fullName
        end
      end
    end
  end
  return false, nil
end

function GLD:IsTrackedPlayerKey(key, opts)
  if not key or not self.db then
    return false
  end
  local player = self.db.players and self.db.players[key] or nil
  if player then
    if player.source == "guild" then
      return true
    end
    if self:IsGuestEntry(player) then
      return true
    end
  end
  if self.db.approvedGuests and self.db.approvedGuests[key] then
    return true
  end
  if self.db.approvedGuests then
    for _, entry in pairs(self.db.approvedGuests) do
      if entry and entry.guid and entry.guid == key then
        return true
      end
    end
  end
  if opts and opts.allowGuildLookup and IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if UnitExists(unit) and UnitIsConnected(unit) then
        local unitKey = NS:GetPlayerKeyFromUnit(unit)
        if unitKey == key and self:IsUnitInOurGuild(unit) then
          return true
        end
      end
    end
  end
  return false
end

function GLD:PromoteGuestKeyToGuid(oldKey, guid)
  if not oldKey or not guid or oldKey == guid then
    return oldKey
  end
  if not self.db or not self.db.players then
    return oldKey
  end
  if self.db.players[guid] then
    return guid
  end
  local player = self.db.players[oldKey]
  if not player or not self:IsGuestEntry(player) then
    return oldKey
  end

  self.db.players[guid] = player
  self.db.players[oldKey] = nil
  player.guid = guid

  self.db.approvedGuests = self.db.approvedGuests or {}
  local approved = self.db.approvedGuests
  if approved[oldKey] and not approved[guid] then
    approved[guid] = approved[oldKey]
  end
  if approved[guid] then
    approved[guid].key = guid
    approved[guid].guid = guid
  end
  approved[oldKey] = nil

  if self.db.queue then
    for i = 1, #self.db.queue do
      if self.db.queue[i] == oldKey then
        self.db.queue[i] = guid
      end
    end
  end
  if self.db.session and self.db.session.attended and self.db.session.attended[oldKey] ~= nil then
    self.db.session.attended[guid] = self.db.session.attended[oldKey]
    self.db.session.attended[oldKey] = nil
  end
  if self.CompactQueue then
    self:CompactQueue()
  end
  if self.MarkDBChanged then
    self:MarkDBChanged("guest_key_promote")
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("Guest key promoted: old=" .. tostring(oldKey) .. " new=" .. tostring(guid))
  end
  return guid
end

function GLD:GetTrackedPlayerKeyForUnit(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  local key = NS:GetPlayerKeyFromUnit(unit)
  local isGuid = type(key) == "string" and key:match("^Player%-") ~= nil
  if key and self.db and self.db.players and self.db.players[key] then
    return key
  end
  local name, realm = UnitName(unit)
  if name and self.FindPlayerKeyByName then
    local byName = self:FindPlayerKeyByName(name, realm)
    if isGuid and byName and byName ~= key and self.db and self.db.players and self.db.players[byName] then
      if self:IsGuestEntry(self.db.players[byName]) and self.PromoteGuestKeyToGuid then
        byName = self:PromoteGuestKeyToGuid(byName, key)
      end
    end
    if byName and self:IsTrackedPlayerKey(byName, { allowGuildLookup = true }) then
      return byName
    end
  end
  if key and self:IsTrackedPlayerKey(key, { allowGuildLookup = true }) then
    return key
  end
  return key
end

function GLD:IsTrackedRaidUnit(unit)
  if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
    return false
  end
  if self:IsUnitInOurGuild(unit) then
    return true
  end
  return self:IsApprovedGuestUnit(unit)
end

function GLD:RemoveApprovedGuestRecord(key, player)
  if not self.db then
    return false
  end
  self.db.approvedGuests = self.db.approvedGuests or {}
  local approved = self.db.approvedGuests
  local removed = false
  local guid = player and player.guid or nil
  local name = player and player.name or nil
  local realm = player and player.realm or nil

  if key and approved[key] then
    approved[key] = nil
    removed = true
  end

  for guestKey, entry in pairs(approved) do
    if entry then
      local sameGuid = guid and entry.guid and entry.guid == guid
      local sameName = name and entry.name and NamesMatch(entry.name, entry.realm, name, realm)
      if sameGuid or sameName then
        approved[guestKey] = nil
        removed = true
      end
    end
  end
  return removed
end

local function NormalizeSimGuestMode(mode)
  local value = tostring(mode or ""):lower()
  if value == "replace" then
    return "replace"
  end
  return "merge"
end

local function CopyGuestAnchorRow(entry)
  if type(entry) ~= "table" then
    return {}
  end
  local copy = {}
  for key, value in pairs(entry) do
    copy[key] = value
  end
  return copy
end

local function BuildSimGuestDefaults(serial, opts)
  opts = opts or {}
  local name = tostring(opts.name or ""):match("^%s*(.-)%s*$")
  if name == "" then
    name = string.format("SimGuest-%02d", serial)
  end
  local guid = tostring(opts.guid or ""):match("^%s*(.-)%s*$")
  if guid == "" then
    guid = string.format("SIM-Guest-%02d", serial)
  end
  local realm = NormalizeRealmName(opts.realm) or NormalizeRealmName(GetRealmName()) or GetRealmName()
  local fullName = opts.fullName
  if not fullName or fullName == "" then
    fullName = realm and realm ~= "" and (name .. "-" .. realm) or name
  end
  return name, guid, realm, fullName
end

function GLD:GetSimMode()
  self.simGuestAnchorMode = NormalizeSimGuestMode(self.simGuestAnchorMode)
  return self.simGuestAnchorMode
end

function GLD:SetSimMode(mode)
  self.simGuestAnchorMode = NormalizeSimGuestMode(mode)
  local dbg = NS and NS.Debug or nil
  if dbg and dbg.Force then
    dbg:Force("GuestAnchorsUI", "SimMode=%s", self.simGuestAnchorMode)
  end
  return self.simGuestAnchorMode
end

function GLD:GetSimGuestAnchors()
  self.simGuestAnchors = self.simGuestAnchors or {}
  local rows = {}
  for i, entry in ipairs(self.simGuestAnchors) do
    rows[i] = CopyGuestAnchorRow(entry)
  end
  return rows
end

function GLD:AddSimGuestAnchor(opts)
  opts = opts or {}
  self.simGuestAnchors = self.simGuestAnchors or {}
  self.simGuestAnchorSerial = (tonumber(self.simGuestAnchorSerial) or 0) + 1

  local serial = self.simGuestAnchorSerial
  local name, guid, realm, fullName = BuildSimGuestDefaults(serial, opts)
  local entry = {
    key = opts.key or guid,
    guid = guid,
    name = name,
    realm = realm,
    fullName = fullName,
    classFile = opts.classFile or opts.class or "WARRIOR",
    unit = nil,
    isSimulated = true,
    isAdmin = opts.isAdmin == true,
    showingButton = opts.showingButton ~= false,
  }
  self.simGuestAnchors[#self.simGuestAnchors + 1] = entry

  local dbg = NS and NS.Debug or nil
  if dbg and dbg.Force then
    dbg:Force(
      "GuestAnchorsUI",
      "SimGuestAdded name=%s guid=%s flags=SIMULATED,isAdmin=%s,showingButton=%s",
      tostring(entry.name),
      tostring(entry.guid),
      tostring(entry.isAdmin == true),
      tostring(entry.showingButton == true)
    )
  end
  return CopyGuestAnchorRow(entry)
end

function GLD:ClearSimGuestAnchors()
  local cleared = self.simGuestAnchors and #self.simGuestAnchors or 0
  self.simGuestAnchors = {}
  local dbg = NS and NS.Debug or nil
  if dbg and dbg.Force then
    dbg:Force("GuestAnchorsUI", "SimGuestCleared count=%d", tonumber(cleared) or 0)
  end
  return cleared
end

function GLD:GetGuestAnchorCandidatesForUI(realCandidates)
  local realRows = type(realCandidates) == "table" and realCandidates or (self.guestAnchorCandidates or {})
  local simRows = self:GetSimGuestAnchors()
  local mode = self:GetSimMode()
  local providerRows = {}

  if mode == "replace" then
    for _, entry in ipairs(simRows) do
      providerRows[#providerRows + 1] = entry
    end
  else
    for _, entry in ipairs(realRows) do
      providerRows[#providerRows + 1] = entry
    end
    for _, entry in ipairs(simRows) do
      providerRows[#providerRows + 1] = entry
    end
  end

  self._guestAnchorProviderStats = {
    mode = mode,
    realCount = #realRows,
    simCount = #simRows,
    providerCount = #providerRows,
  }
  return providerRows, self._guestAnchorProviderStats
end

function GLD:ResetGuestAnchorCandidates(reason)
  self.guestAnchorCandidates = {}
  self.guestAnchorCandidatesByKey = {}
  if not IsInRaid() or reason == "session_end" then
    self._guestCandidateDebugSeen = {}
  end
end

function GLD:RebuildGuestAnchorCandidates()
  local dbg = NS and NS.Debug or nil
  local rosterCountIn = (IsInRaid and IsInRaid() and GetNumGroupMembers and GetNumGroupMembers()) or 0
  if not IsInRaid() then
    self:ResetGuestAnchorCandidates("left_raid")
    self._guestAnchorRebuildStats = {
      candidatesFound = 0,
      afterFiltering = 0,
      rowsProvidedToUI = 0,
      approvedSkipped = 0,
      duplicateSkipped = 0,
      missingIdentity = 0,
    }
    if dbg and dbg.Once then
      dbg:Once("ga_build_not_in_raid", "GA_BUILD", "rosterIn=%d guestOut=0 firstName=- firstGuid=- reason=not_in_raid", rosterCountIn)
    end
    return self:GetGuestAnchorCandidatesForUI(self.guestAnchorCandidates)
  end

  local candidates = {}
  local byKey = {}
  local seen = {}
  local candidatesFound = 0
  local approvedSkipped = 0
  local duplicateSkipped = 0
  local missingIdentity = 0
  self._guestCandidateDebugSeen = self._guestCandidateDebugSeen or {}

  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsUnit(unit, "player") then
      if not self:IsUnitInOurGuild(unit) then
        candidatesFound = candidatesFound + 1
        local guid = UnitGUID(unit)
        local name, realm = UnitName(unit)
        local realmName = NormalizeRealmName(realm)
        local resolvedKey = self:GetGuestRosterKey(guid, name, realmName)
        local approvedEntry = self.IsApprovedGuestUnit and self:IsApprovedGuestUnit(unit) or false
        if resolvedKey and not approvedEntry and not seen[resolvedKey] then
          local classFile = select(2, UnitClass(unit))
          local fullName = self:GetUnitFullName(unit) or (name and (name .. "-" .. realmName)) or name
          local candidate = {
            key = resolvedKey,
            guid = guid,
            name = name,
            realm = realmName,
            fullName = fullName,
            classFile = classFile,
            unit = unit,
          }
          candidates[#candidates + 1] = candidate
          byKey[resolvedKey] = candidate
          seen[resolvedKey] = true
          if self.IsDebugEnabled and self:IsDebugEnabled() and not self._guestCandidateDebugSeen[resolvedKey] then
            self._guestCandidateDebugSeen[resolvedKey] = true
            self:Debug(
              "Guest anchor candidate detected: name="
                .. tostring(fullName or name or "?")
                .. " key="
                .. tostring(resolvedKey)
                .. " guid="
                .. tostring(guid)
            )
          end
        elseif approvedEntry then
          approvedSkipped = approvedSkipped + 1
        elseif resolvedKey and seen[resolvedKey] then
          duplicateSkipped = duplicateSkipped + 1
        elseif not resolvedKey and self.IsDebugEnabled and self:IsDebugEnabled() then
          missingIdentity = missingIdentity + 1
          self:Debug("Guest anchor skipped (missing identity): unit=" .. tostring(unit))
        elseif not resolvedKey then
          missingIdentity = missingIdentity + 1
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    return tostring(a.fullName or a.name or a.key or "") < tostring(b.fullName or b.name or b.key or "")
  end)
  self.guestAnchorCandidates = candidates
  self.guestAnchorCandidatesByKey = byKey
  self._guestAnchorRebuildStats = {
    candidatesFound = candidatesFound,
    afterFiltering = #candidates,
    rowsProvidedToUI = #candidates,
    approvedSkipped = approvedSkipped,
    duplicateSkipped = duplicateSkipped,
    missingIdentity = missingIdentity,
  }
  local first = candidates[1]
  local firstName = first and (first.fullName or first.name or first.key) or "-"
  local firstGuid = first and first.guid or "-"
  if dbg and dbg.Throttle then
    dbg:Throttle(
      "ga_build_summary",
      1.0,
      "GA_BUILD",
      "rosterIn=%d guestOut=%d firstName=%s firstGuid=%s",
      tonumber(rosterCountIn) or 0,
      #candidates,
      tostring(firstName),
      tostring(firstGuid)
    )
  end
  if dbg and dbg.Verbose then
    dbg:Verbose(
      "GA_BUILD",
      "approvedSkipped=%d duplicateSkipped=%d missingIdentity=%d",
      approvedSkipped,
      duplicateSkipped,
      missingIdentity
    )
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "Guest anchor rebuild: candidatesFound="
        .. tostring(candidatesFound)
        .. " afterFiltering="
        .. tostring(#candidates)
        .. " approvedSkipped="
        .. tostring(approvedSkipped)
        .. " duplicateSkipped="
        .. tostring(duplicateSkipped)
        .. " missingIdentity="
        .. tostring(missingIdentity)
    )
  end
  return self:GetGuestAnchorCandidatesForUI(candidates)
end

function GLD:GetGuestAnchorCandidates()
  if not self.guestAnchorCandidates then
    return self:RebuildGuestAnchorCandidates()
  end
  return self:GetGuestAnchorCandidatesForUI(self.guestAnchorCandidates)
end

function GLD:ApproveGuestCandidate(candidate, opts)
  opts = opts or {}
  if not self.db or not self.db.players then
    return false, "missing_db"
  end
  if candidate and candidate.isSimulated then
    local dbg = NS and NS.Debug or nil
    if dbg and dbg.Force then
      dbg:Force(
        "GuestAnchorsUI",
        "SimGuestIgnored name=%s guid=%s reason=mutation_blocked",
        tostring(candidate.name or "?"),
        tostring(candidate.guid or "?")
      )
    end
    if self.Print and not opts.silent then
      self:Print("SIMULATED guest entries are UI-only and cannot be approved.")
    end
    return false, "simulated"
  end

  if not opts.skipPermission then
    if self.CanAccessAdminUI and not self:CanAccessAdminUI() then
      self:ShowPermissionDeniedPopup()
      return false, "permission_denied"
    end
  end

  local unit = candidate and candidate.unit or nil
  local guid = candidate and candidate.guid or nil
  local name = candidate and candidate.name or nil
  local realm = candidate and candidate.realm or nil
  local classFile = candidate and (candidate.classFile or candidate.class) or nil
  local fullName = candidate and candidate.fullName or nil

  if unit and UnitExists(unit) then
    guid = guid or UnitGUID(unit)
    local unitName, unitRealm = UnitName(unit)
    name = name or unitName
    realm = realm or unitRealm
    classFile = classFile or select(2, UnitClass(unit))
    fullName = fullName or self:GetUnitFullName(unit)
    if self:IsUnitInOurGuild(unit) then
      if self.Print then
        self:Print("Cannot add guest: player is a guild member.")
      end
      return false, "guild_member"
    end
  end

  realm = NormalizeRealmName(realm)
  local resolvedKey = (candidate and candidate.key) or self:GetGuestRosterKey(guid, name, realm)
  if not name and (not guid or guid == "") then
    if self.Print then
      self:Print("Cannot add guest: missing GUID and player name.")
    end
    return false, "missing_identity"
  end
  if not resolvedKey then
    if self.Print then
      self:Print("Cannot add guest: missing player key.")
    end
    return false, "missing_key"
  end

  if not opts.skipRequest and not self:IsAuthority() then
    if self.RequestAdminAction then
      local requested = self:RequestAdminAction("APPROVE_GUEST", {
        key = resolvedKey,
        guid = guid,
        name = name,
        realm = realm,
        class = classFile,
        fullName = fullName,
      })
      if requested and self.Print and not opts.silent then
        self:Print("Guest approval request sent: " .. tostring(fullName or name or resolvedKey))
      end
      return requested, "requested"
    end
    return false, "not_authority"
  end

  local approvedEntry, approvedKey = self:FindApprovedGuestEntry(guid, name, realm)
  if approvedKey then
    if guid and guid ~= "" and approvedKey ~= guid and self.PromoteGuestKeyToGuid then
      approvedKey = self:PromoteGuestKeyToGuid(approvedKey, guid)
    end
    local existing = self.db.players and self.db.players[approvedKey] or nil
    if existing and not existing.guid and guid and guid ~= "" then
      existing.guid = guid
    end
    if self.db.approvedGuests and self.db.approvedGuests[approvedKey] and guid and guid ~= "" then
      self.db.approvedGuests[approvedKey].guid = guid
    end
    if self.Print and not opts.silent then
      self:Print("Guest already approved: " .. tostring(fullName or name or approvedKey))
    end
    return false, "already_approved"
  end

  local playerKey = resolvedKey
  if guid and guid ~= "" and self.db.players[guid] then
    playerKey = guid
  elseif name and self.FindPlayerKeyByName then
    local byName = self:FindPlayerKeyByName(name, realm)
    if byName and self.db.players[byName] then
      playerKey = byName
    end
  end
  if guid and guid ~= "" and playerKey and playerKey ~= guid and self.db.players[playerKey] then
    local byKey = self.db.players[playerKey]
    if byKey and self:IsGuestEntry(byKey) and self.PromoteGuestKeyToGuid then
      playerKey = self:PromoteGuestKeyToGuid(playerKey, guid)
    end
  end

  local existingPlayerForKey = self.db.players[playerKey]
  if existingPlayerForKey and existingPlayerForKey.source == "guild" then
    if self.Print and not opts.silent then
      self:Print("Cannot add guest: player is already tracked as guild.")
    end
    return false, "guild_member"
  end

  local player = self.db.players[playerKey]
  local isNew = false
  if not player then
    isNew = true
    player = {
      name = name,
      realm = realm,
      class = classFile,
      attendance = "ABSENT",
      queuePos = nil,
      savedPos = nil,
      numAccepted = 0,
      lastWinAt = 0,
      isHonorary = false,
      attendanceCount = 0,
    }
    self.db.players[playerKey] = player
  end

  player.name = name or player.name
  player.realm = realm or player.realm or GetRealmName()
  player.class = classFile or player.class
  player.source = "guest"
  player.isGuest = true
  player.guid = guid or player.guid
  if player.attendance == nil then
    player.attendance = "ABSENT"
  end
  if unit and UnitExists(unit) and UnitIsConnected(unit) then
    player.attendance = "PRESENT"
  end

  local approvedAt = opts.approvedAt or ((GetServerTime and GetServerTime()) or time())
  local approvedBy = opts.approvedBy
  if not approvedBy or approvedBy == "" then
    approvedBy = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
  end
  local approvedByGuid = opts.approvedByGuid
  if not approvedByGuid or approvedByGuid == "" then
    approvedByGuid = UnitGUID("player")
  end

  self.db.approvedGuests = self.db.approvedGuests or {}
  if self.RemoveApprovedGuestRecord then
    self:RemoveApprovedGuestRecord(nil, {
      guid = guid,
      name = name,
      realm = realm,
    })
  end
  self.db.approvedGuests[playerKey] = {
    key = playerKey,
    guid = guid or player.guid,
    name = player.name or name,
    realm = player.realm or realm,
    approvedAt = approvedAt,
    approvedBy = approvedBy,
    approvedByGuid = approvedByGuid,
  }
  player.approvedAt = approvedAt
  player.approvedBy = approvedBy
  player.approvedByGuid = approvedByGuid

  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "Guest approved: key="
        .. tostring(playerKey)
        .. " name="
        .. tostring(player.name or name or "?")
        .. " guid="
        .. tostring(guid)
        .. " by="
        .. tostring(approvedBy)
    )
    self:Debug("SavedVariables updated: approvedGuests[" .. tostring(playerKey) .. "]")
  end

  if isNew and self.LogAuditEvent then
    local specName = player.specName or player.spec
    self:LogAuditEvent("ADD_MEMBER", {
      actor = approvedBy,
      target = player.name or name,
      isGuest = true,
      class = player.class,
      spec = specName,
      playerKey = playerKey,
    })
  end

  if self.BroadcastGuestApproved and self:IsAuthority() and not opts.skipBroadcast then
    self:BroadcastGuestApproved({
      key = playerKey,
      guid = guid or player.guid,
      name = player.name or name,
      realm = player.realm or realm,
      class = player.class,
      approvedAt = approvedAt,
      approvedBy = approvedBy,
      approvedByGuid = approvedByGuid,
    })
  end

  if self.guestAnchorCandidatesByKey then
    self.guestAnchorCandidatesByKey[playerKey] = nil
    if resolvedKey ~= playerKey then
      self.guestAnchorCandidatesByKey[resolvedKey] = nil
    end
  end
  if self.guestAnchorCandidates then
    for i = #self.guestAnchorCandidates, 1, -1 do
      local row = self.guestAnchorCandidates[i]
      if row and (row.key == playerKey or row.key == resolvedKey) then
        table.remove(self.guestAnchorCandidates, i)
      end
    end
  end

  if self:IsAuthority() then
    if self.OnRosterChanged then
      self:OnRosterChanged("guest_approved")
    elseif self.MarkDBChanged then
      self:MarkDBChanged("guest_approved")
    end
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      self:Debug("Roster updated: guest approval broadcasted to raid.")
    end
  else
    if self.EnsureQueuePositions then
      self:EnsureQueuePositions()
    end
    if self.MarkDBChanged then
      self:MarkDBChanged("guest_approved_sync")
    end
    if self.UI and self.UI.RefreshMain then
      self.UI:RefreshMain()
    end
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      self:Debug("Roster updated: guest approval applied from sync.")
    end
  end

  if self.Print and not opts.silent then
    self:Print("Added guest to Raid Database: " .. tostring(player.name or name or playerKey))
  end
  return true, nil, playerKey
end

function GLD:ApproveGuestFromUnit(unit, opts)
  if not unit or not UnitExists(unit) then
    return false, "missing_unit"
  end
  local name, realm = UnitName(unit)
  local guid = UnitGUID(unit)
  local classFile = select(2, UnitClass(unit))
  return self:ApproveGuestCandidate({
    unit = unit,
    name = name,
    realm = realm,
    guid = guid,
    classFile = classFile,
    fullName = self:GetUnitFullName(unit),
    key = self:GetGuestRosterKey(guid, name, realm),
  }, opts)
end

function GLD:GetDBPlayerForUnit(unit)
  if not unit or not UnitExists(unit) then
    return nil, nil
  end
  if not self.db or not self.db.players then
    return nil, nil
  end
  local key = NS:GetPlayerKeyFromUnit(unit)
  if key and self.db.players[key] then
    return self.db.players[key], key
  end
  local name, realm = UnitName(unit)
  if name and self.FindPlayerKeyByName then
    local lookup = self:FindPlayerKeyByName(name, realm)
    if lookup and self.db.players[lookup] then
      return self.db.players[lookup], lookup
    end
  end
  local fullName = self:GetUnitFullName(unit)
  if fullName and self.db.players[fullName] then
    return self.db.players[fullName], fullName
  end
  if name and self.db.players[name] then
    return self.db.players[name], name
  end
  return nil, nil
end

local function NormalizeSenderRealmForMatch(realm)
  local raw = NormalizeRealmName(realm)
  if not raw then
    return ""
  end
  return tostring(raw):gsub("[%s%-]", ""):lower()
end

local function NormalizeSenderNameForMatch(name)
  if not name then
    return ""
  end
  return tostring(name):lower()
end

local function SenderMatchesUnit(sender, unit)
  if not sender or sender == "" or not unit or not UnitExists(unit) then
    return false
  end
  local senderBase, senderRealm = NS:SplitNameRealm(sender)
  if not senderBase or senderBase == "" then
    return false
  end
  local senderBaseNorm = NormalizeSenderNameForMatch(senderBase)
  local senderRealmNorm = NormalizeSenderRealmForMatch(senderRealm)
  local unitName, unitRealm = UnitName(unit)
  if not unitName or unitName == "" then
    return false
  end
  local unitNameNorm = NormalizeSenderNameForMatch(unitName)
  local unitRealmNorm = NormalizeSenderRealmForMatch(unitRealm)
  if senderBaseNorm == unitNameNorm and senderRealmNorm == unitRealmNorm then
    return true
  end
  local senderRawNorm = NormalizeSenderNameForMatch(sender)
  if senderRawNorm ~= "" and unitNameNorm == senderRawNorm then
    return true
  end
  return false
end

function GLD:GetGuidForSender(sender)
  if not sender or sender == "" then
    return nil
  end
  if SenderMatchesUnit(sender, "player") then
    return UnitGUID("player")
  end
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if SenderMatchesUnit(sender, unit) then
        return UnitGUID(unit)
      end
    end
  end
  return nil
end

function GLD:GetUnitForSender(sender)
  if not sender or sender == "" then
    return nil
  end
  if SenderMatchesUnit(sender, "player") then
    return "player"
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if SenderMatchesUnit(sender, unit) then
        return unit
      end
    end
  end

  return nil
end

function GLD:IsSenderInRaid(sender)
  if not IsInRaid() then
    return false
  end
  local unit = self:GetUnitForSender(sender)
  return unit ~= nil
end

function GLD:ValidateAdminRequestSender(sender, actionLabel)
  local function buildDetails(unit, senderName, reason, authorityAllowed, officerDetails)
    return {
      sender = sender,
      unit = unit,
      authorityName = senderName,
      authorityReason = reason,
      playerGUID = unit and UnitGUID(unit) or nil,
      guildRankIndex = officerDetails and officerDetails.rankIndex or nil,
      guildRankName = officerDetails and officerDetails.rankName or nil,
      computedAuthority = authorityAllowed == true,
      rosterMatch = officerDetails and officerDetails.rosterMatch == true or false,
      isOfficer = officerDetails and officerDetails.isOfficer == true or false,
      isGuildMaster = officerDetails and officerDetails.isGuildMaster == true or false,
    }
  end
  if not sender or sender == "" then
    return false, "missing sender", nil
  end
  if not IsInRaid() then
    return false, "not in raid", nil
  end
  local unit = self:GetUnitForSender(sender)
  if not unit then
    return false, "sender not in raid", nil
  end

  local senderName = self.GetUnitFullName and self:GetUnitFullName(unit) or sender
  senderName = self:NormalizeGuildMemberFullName(senderName) or self:NormalizeGuildMemberFullName(sender) or sender
  local ourGuild = self:GetOurGuildName()
  local senderGuild = GetGuildInfo(unit)
  if not ourGuild or not senderGuild or senderGuild ~= ourGuild then
    local details = buildDetails(unit, senderName, "not in guild", false, nil)
    self:DebugOfficerAuthority(
      "validate_sender sender=%s rosterMatch=%s isOfficer=%s result=%s reason=%s",
      tostring(senderName),
      "false",
      "false",
      "false",
      "not in guild"
    )
    self:DebugOfficerAuthority("admin_denied reason=%s", "not in guild")
    return false, "not in guild", details
  end

  local allowed, reason, officerDetails = self:IsNameGuildOfficer(senderName)
  local humanReason = ToAdminDenyReason(reason)
  local details = buildDetails(unit, senderName, humanReason, allowed, officerDetails)
  self:DebugOfficerAuthority(
    "validate_sender sender=%s rosterMatch=%s isOfficer=%s result=%s reason=%s",
    tostring(senderName),
    tostring(details.rosterMatch == true),
    tostring(details.isOfficer == true or details.isGuildMaster == true),
    tostring(allowed == true),
    tostring(humanReason)
  )

  local context = {
    unit = unit,
    playerName = UnitName(unit),
    playerRealm = select(2, UnitName(unit)),
    playerGUID = UnitGUID(unit),
    authorityName = senderName,
    authorityReason = humanReason,
    authorityDetails = officerDetails,
    guildRankIndex = details.guildRankIndex,
    guildRankName = details.guildRankName,
    computedAuthority = allowed == true,
  }

  if not allowed then
    self:DebugOfficerAuthority("admin_denied reason=%s", tostring(humanReason))
    if self.DebugAuth then
      self:DebugAuth("ValidateAdminRequestSender:" .. tostring(actionLabel), "Utils.ValidateAdminRequestSender:denied", context)
    end
    return false, humanReason, details
  end

  if self.DebugAuth then
    self:DebugAuth("ValidateAdminRequestSender:" .. tostring(actionLabel), "Utils.ValidateAdminRequestSender:allowed", context)
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "Admin request accepted: sender="
        .. tostring(sender)
        .. " action="
        .. tostring(actionLabel)
        .. " authReason="
        .. tostring(context.authorityReason)
    )
  end
  return true, nil, details
end

function GLD:IsOfficerUnit(unit)
  if not unit or not UnitExists(unit) then
    return false
  end
  local allowed = self:IsUnitGuildOfficer(unit)
  return allowed == true
end

function GLD:IsOfficerSender(sender)
  if not sender or sender == "" then
    return false
  end
  if not IsInRaid() then
    return false
  end
  local unit = self:GetUnitForSender(sender)
  if not unit then
    return false
  end
  local senderName = self.GetUnitFullName and self:GetUnitFullName(unit) or sender
  local allowed = self:IsNameGuildOfficer(senderName)
  return allowed == true
end

function GLD:GetRaidOfficerUnits()
  local units = {}
  if not IsInRaid() then
    return units
  end
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) and self:IsOfficerUnit(unit) then
      units[#units + 1] = unit
    end
  end
  return units
end

function GLD:MaybeWelcomeGuest(unit, fullName, playerKey, playerEntry)
  if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
    return
  end
  if UnitIsUnit(unit, "player") then
    return
  end
  playerEntry = playerEntry or (self.GetDBPlayerForUnit and select(1, self:GetDBPlayerForUnit(unit))) or nil
  if not playerEntry or not self:IsGuestEntry(playerEntry) then
    return
  end

  local guid = UnitGUID(unit)
  if not guid or guid == "" then
    return
  end
  fullName = fullName or self:GetUnitFullName(unit)
  if not fullName or fullName == "" then
    return
  end

  local guestDB = self.guestDB or GLT_DB
  if not guestDB then
    return
  end
  guestDB.seenGuests = guestDB.seenGuests or {}
  guestDB.lastGuestWelcomeAt = guestDB.lastGuestWelcomeAt or {}

  if not guestDB.seenGuests[guid] then
    guestDB.seenGuests[guid] = true
    guestDB.lastGuestWelcomeAt[guid] = time()
    if self.IsAuthority and self:IsAuthority() and self.BroadcastNotice then
      local text = self:GetGuestWelcomeText()
      self:BroadcastNotice("guest_welcome", text, { audience = "GUESTS", allowSuppress = true })
    end
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      self:Debug("Guest welcome notice queued (no whispers): " .. tostring(fullName))
    end
  end
end

function GLD:WelcomeGuestsFromGroup()
  if not IsInRaid() then
    return
  end

  local recipients = {}
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsUnit(unit, "player") then
      local playerEntry, playerKey = self:GetDBPlayerForUnit(unit)
      if playerEntry and self:IsGuestEntry(playerEntry) then
        local fullName = self:GetUnitFullName(unit)
        if fullName then
          recipients[#recipients + 1] = {
            unit = unit,
            fullName = fullName,
            playerKey = playerKey,
            playerEntry = playerEntry,
          }
        end
      end
    end
  end

  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("Guest welcome recipients: " .. tostring(#recipients))
  end
  for _, entry in ipairs(recipients) do
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      self:Debug("Guest welcome target: " .. tostring(entry.fullName) .. " isGuest=true")
    end
    self:MaybeWelcomeGuest(entry.unit, entry.fullName, entry.playerKey, entry.playerEntry)
  end
end

function GLD:RebuildGroupRoster()
  local roster = {}
  local rosterByKey = {}
  local currentKeys = {}
  local added = {}
  local previousKeys = self.groupRosterKeys or {}
  local ourGuild = self:GetOurGuildName()

  local function addUnit(unit)
    if not unit or not UnitExists(unit) then
      return
    end
    local key = NS:GetPlayerKeyFromUnit(unit)
    local name, realm = UnitName(unit)
    local fullName = self:GetUnitFullName(unit)
    local guildName = GetGuildInfo(unit)
    local isGuildMember = ourGuild and guildName and guildName == ourGuild or false
    local entry = {
      unit = unit,
      key = key,
      name = name,
      realm = realm,
      fullName = fullName,
      isGuildMember = isGuildMember,
    }
    roster[#roster + 1] = entry
    if key then
      rosterByKey[key] = entry
      currentKeys[key] = true
      if not previousKeys[key] and fullName and not UnitIsUnit(unit, "player") then
        added[#added + 1] = fullName
      end
    end
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      addUnit("raid" .. i)
    end
  else
    addUnit("player")
  end

  self.groupRoster = roster
  self.groupRosterByKey = rosterByKey
  self.groupRosterKeys = currentKeys
  return roster, rosterByKey, added
end

function GLD:CanAccessAdminUI()
  if self.CanLocalSeeAdminUI then
    return self:CanLocalSeeAdminUI()
  end
  return false
end

function GLD:IsAdminCharacter()
  if self.CanAccessAdminUI then
    return self:CanAccessAdminUI()
  end
  if self.IsAdmin then
    return self:IsAdmin()
  end
  return false
end

function GLD:CanMutateState()
  if not self:CanAccessAdminUI() then
    return false
  end
  local authorityGUID = self.GetAuthorityGUID and self:GetAuthorityGUID() or nil
  if not authorityGUID or authorityGUID == "" then
    return true
  end
  return self:IsAuthority()
end

local function GetClassColorObject(classFile)
  if not classFile then
    return nil
  end
  if C_ClassColor and C_ClassColor.GetClassColor then
    return C_ClassColor.GetClassColor(classFile)
  end
  if RAID_CLASS_COLORS then
    return RAID_CLASS_COLORS[classFile]
  end
  return nil
end

function NS:GetPlayerBaseName(name)
  if type(name) == "string" and name ~= "" then
    local base = strsplit("-", name)
    if base and base ~= "" then
      return base
    end
    return name
  end
  if name then
    return tostring(name)
  end
  return nil
end

function NS:GetPlayerDisplayName(name, isGuest)
  if type(name) == "string" and name:match("^Player%-") then
    return name
  end
  local base = NS:GetPlayerBaseName(name)
  if not base or base == "" then
    base = name or "?"
  end
  base = tostring(base)
  base = base:gsub("%s+$", "")
  if not isGuest and type(name) == "string" then
    local lowered = name:lower()
    if lowered:match("%-guest$") or lowered:match("%s%-?%s*guest$") or lowered:match("%|cffffffff%-?guest%|r$") then
      isGuest = true
    end
  end
  if isGuest then
    return base .. " |cffffffff-Guest|r"
  end
  return base
end

function NS:GetClassColor(classFile)
  local color = GetClassColorObject(classFile)
  if color then
    return color.r or 1, color.g or 1, color.b or 1
  end
  return 1, 1, 1
end

function NS:GetNameRealmFromKey(key)
  if not key then
    return nil
  end
  if key:find("Player%-") then
    return nil
  end
  return NS:SplitNameRealm(key)
end

function NS:GetClassIcon(classFile)
  if not classFile then
    return ""
  end
  local coords = CLASS_ICON_TCOORDS[classFile]
  if not coords then
    return ""
  end
  return string.format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:16:16:0:0:256:256:%d:%d:%d:%d|t",
    coords[1] * 256, coords[2] * 256, coords[3] * 256, coords[4] * 256)
end

function NS:GetRoleIcon(role)
  role = role or "NONE"
  local coords = ROLE_ICON_TCOORDS[role] or ROLE_ICON_TCOORDS.NONE
  if role == "NONE" then
    return ""
  end
  return string.format("|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:16:16:0:0:64:64:%d:%d:%d:%d|t",
    coords[1] * 64, coords[2] * 64, coords[3] * 64, coords[4] * 64)
end

function NS:ColorAttendance(attendance)
  if attendance == "PRESENT" then
    return "|cff00ff00PRESENT|r"
  end
  return "|cffff0000ABSENT|r"
end

function NS:GetRoleForPlayer(name)
  if not name then
    return "NONE"
  end
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      local unitName = UnitName(unit)
      if unitName == name then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
          return role
        end
      end
    end
  end
  return "NONE"
end

function GLD:UpsertPlayerFromUnit(unit)
  local key = NS:GetPlayerKeyFromUnit(unit)
  if not key then
    return nil
  end
  local name, realm = UnitName(unit)
  local classFile = select(2, UnitClass(unit))
  local player = self.db.players[key]
  local isNew = false
  if not player then
    isNew = true
    player = {
      name = name,
      realm = realm or GetRealmName(),
      class = classFile,
      specId = nil,
      specName = nil,
      attendance = "ABSENT",
      queuePos = nil,
      savedPos = nil,
      numAccepted = 0,
      lastWinAt = 0,
      isHonorary = false,
      attendanceCount = 0,
    }
    self.db.players[key] = player
    if self.MarkDBChanged then
      self:MarkDBChanged("player_add")
    end
    if self.LogAuditEvent then
      local actor = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
      local isGuest = self.IsGuest and self:IsGuest(unit) or false
      local specName = player.specName or player.spec
      self:LogAuditEvent("ADD_MEMBER", {
        actor = actor,
        target = name or player.name,
        isGuest = isGuest,
        class = classFile,
        spec = specName,
        playerKey = key,
      })
    end
  else
    player.name = name or player.name
    player.realm = realm or player.realm
    player.class = classFile or player.class
  end
  return key, isNew
end

function GLD:AddGuestFromUnit(unit)
  return self:ApproveGuestFromUnit(unit)
end

function GLD:RefreshFromGuildRoster()
  if not IsInGuild() then
    self:Print("You are not in a guild.")
    return
  end

  if GuildRoster then
    GuildRoster()
  end

  local attempts = 0
  local function rebuild()
    attempts = attempts + 1
    local count = GetNumGuildMembers and GetNumGuildMembers() or 0
    if (not count or count == 0) and attempts < 6 then
      C_Timer.After(0.4, rebuild)
      return
    end

    local keep = {}
    self.db.approvedGuests = self.db.approvedGuests or {}
    for key, player in pairs(self.db.players or {}) do
      if player and player.source == "test" then
        keep[key] = player
      end
    end
    for key, entry in pairs(self.db.approvedGuests) do
      local player = self.db.players and self.db.players[key] or nil
      if player then
        keep[key] = player
      elseif entry and entry.name then
        keep[key] = {
          name = entry.name,
          realm = entry.realm or GetRealmName(),
          class = nil,
          attendance = "ABSENT",
          queuePos = nil,
          savedPos = nil,
          numAccepted = 0,
          lastWinAt = 0,
          isHonorary = false,
          attendanceCount = 0,
          source = "guest",
          isGuest = true,
          guid = entry.guid,
          approvedAt = entry.approvedAt,
          approvedBy = entry.approvedBy,
          approvedByGuid = entry.approvedByGuid,
        }
      end
    end

    self.db.players = {}
    self.db.queue = {}

    local realmName = GetRealmName()
    for i = 1, (count or 0) do
      local name, _, _, _, _, _, _, _, _, _, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(i)
      if name then
        local base, realm = NS:SplitNameRealm(name)
        local key = (guid and guid ~= "" and guid) or (base .. "-" .. (realm or realmName))
        self.db.players[key] = {
          name = base,
          realm = realm or realmName,
          class = classFileName,
          attendance = "ABSENT",
          queuePos = nil,
          savedPos = nil,
          numAccepted = 0,
          lastWinAt = 0,
          isHonorary = false,
          attendanceCount = 0,
          source = "guild",
        }
      end
    end

    for key, player in pairs(keep) do
      if not self.db.players[key] then
        self.db.players[key] = player
      end
    end

    self.shadow.roster = {}
    self.shadow.my.queuePos = nil
    self.shadow.my.attendance = nil

    self:AutoMarkCurrentGroup()
    if self.OnRosterChanged then
      self:OnRosterChanged("guild_roster_refresh")
    end
    self:Print("Guild roster loaded.")
  end

  C_Timer.After(0.4, rebuild)
end

function GLD:UpdateGuestAttendanceFromGroup()
  if not self.db or not self.db.players then
    return
  end
  if not IsInRaid() then
    return
  end

  local present = {}
  local function addUnit(unit)
    if not UnitExists(unit) or not UnitIsConnected(unit) then
      return
    end
    local key = NS:GetPlayerKeyFromUnit(unit)
    if key then
      present[key] = true
    end
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      addUnit("raid" .. i)
    end
  else
    addUnit("player")
  end

  for key, player in pairs(self.db.players) do
    if player and player.source == "guest" then
      if present[key] then
        self:SetAttendance(key, "PRESENT")
      else
        self:SetAttendance(key, "ABSENT")
      end
    end
  end
end

local function BuildFullName(name, realm)
  if not name or name == "" then
    return nil
  end
  if realm and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

function GLD:GetLocalRosterEntry(roster)
  if type(roster) ~= "table" then
    return nil
  end

  local localKey = NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
  local name, realm = UnitName("player")
  local fullName = BuildFullName(name, realm)

  if localKey and roster[localKey] then
    return roster[localKey], localKey
  end
  if fullName and roster[fullName] then
    return roster[fullName], fullName
  end
  if name and roster[name] then
    return roster[name], name
  end

  for key, entry in pairs(roster) do
    if type(entry) == "table" then
      local entryKey = entry.key or entry.playerKey or key
      if localKey and entryKey == localKey then
        return entry, entryKey
      end
      local entryName = entry.name or entry.fullName or entry.displayName
      local entryRealm = entry.realm
      if entryName and not entryRealm and NS.SplitNameRealm then
        local base, parsedRealm = NS:SplitNameRealm(entryName)
        if base then
          entryName = base
          entryRealm = parsedRealm or entryRealm
        end
      end
      local entryFull = BuildFullName(entryName, entryRealm)
      if fullName and entryFull and entryFull == fullName then
        return entry, entryKey
      end
      if name and entryName and entryName == name then
        return entry, entryKey
      end
    end
  end

  return nil
end

function GLD:BuildMySnapshotFromRoster(roster)
  local entry = self:GetLocalRosterEntry(roster)
  if not entry then
    return nil
  end
  return {
    queuePos = entry.queuePos,
    savedPos = entry.savedPos or entry.heldPos or entry.holdPos,
    numAccepted = entry.numAccepted,
    attendance = entry.attendance,
    attendanceCount = entry.attendanceCount,
  }
end

function GLD:UpdateShadowMyFromRoster(roster)
  if not self.shadow then
    return nil
  end
  local snapshot = self:BuildMySnapshotFromRoster(roster)
  if not snapshot then
    return nil
  end
  self.shadow.my = self.shadow.my or {}
  for key, value in pairs(snapshot) do
    self.shadow.my[key] = value
  end
  return snapshot
end

function GLD:BuildRollNonce()
  self._rollNonce = (self._rollNonce or 0) + 1
  local now = GetServerTime and GetServerTime() or time()
  return tostring(now) .. "-" .. tostring(math.random(100000, 999999)) .. "-" .. tostring(self._rollNonce)
end

function GLD:MakeRollKey(rollID, nonce)
  if rollID == nil then
    return nil
  end
  local suffix = nonce and tostring(nonce) or "legacy"
  return tostring(rollID) .. "@" .. suffix
end

function GLD:GetLegacyRollKey(rollID)
  return self:MakeRollKey(rollID, "legacy")
end

function GLD:GetRollKeyFromPayload(payload)
  if not payload then
    return nil
  end
  if payload.rollKey and payload.rollKey ~= "" then
    return tostring(payload.rollKey)
  end
  if payload.rollID ~= nil then
    return self:GetLegacyRollKey(payload.rollID)
  end
  return nil
end

function GLD:IsRollSessionExpired(session, now, maxAgeSeconds)
  if not session then
    return true
  end
  local status = nil
  if session.status then
    status = tostring(session.status):upper()
  end
  if status == "PENDING_APPROVAL" then
    return false
  end
  if status == "APPROVED" or status == "LOST" or status == "CLOSED" then
    return true
  end
  local ts = now or (GetServerTime and GetServerTime() or time())
  if session.locked then
    return true
  end
  if session.rollExpiresAt and session.rollExpiresAt > 0 and session.rollExpiresAt < ts then
    return true
  end
  local maxAge = maxAgeSeconds or 1800
  if session.createdAt and session.createdAt > 0 and session.createdAt < (ts - maxAge) then
    return true
  end
  return false
end

function GLD:GetRollStatus(session)
  if not session then
    return "CLOSED"
  end
  if session.status then
    local status = tostring(session.status):upper()
    if status == "ACTIVE" or status == "PENDING_APPROVAL" or status == "APPROVED" or status == "LOST" or status == "CLOSED" then
      return status
    end
  end
  if session.locked then
    return "CLOSED"
  end
  return "ACTIVE"
end

function GLD:IsRollPendingApproval(session)
  return self:GetRollStatus(session) == "PENDING_APPROVAL"
end

function GLD:IsRollStatusTerminal(status)
  status = status and tostring(status):upper() or nil
  return status == "APPROVED" or status == "LOST" or status == "CLOSED"
end

function GLD:IsRollClosed(session)
  local status = self:GetRollStatus(session)
  return self:IsRollStatusTerminal(status)
end

function GLD:FindActiveRoll(rollKey, rollID)
  if not self.activeRolls then
    return rollKey, nil
  end
  if rollKey and self.activeRolls[rollKey] then
    return rollKey, self.activeRolls[rollKey]
  end
  if rollID ~= nil then
    local legacyKey = self:GetLegacyRollKey(rollID)
    if self.activeRolls[legacyKey] then
      return legacyKey, self.activeRolls[legacyKey]
    end
    for key, session in pairs(self.activeRolls) do
      if session and session.rollID == rollID then
        return key, session
      end
    end
  end
  return rollKey, nil
end
