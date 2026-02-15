local _, NS = ...

local GLD = NS.GLD

local DEFAULT_OFFICER_THRESHOLD_RANK_INDEX = 1
local MAIN_NOTE_PATTERN = "[Mm][Aa][Ii][Nn]%s*=%s*([^,;|]+)"

local function Trim(value)
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

local function BuildFullName(name, realm)
  local cleanName = Trim(name)
  if not cleanName then
    return nil
  end
  local cleanRealm = Trim(realm)
  if not cleanRealm then
    cleanRealm = GetRealmName()
  end
  if not cleanRealm or cleanRealm == "" then
    return cleanName
  end
  return cleanName .. "-" .. cleanRealm
end

local function Lower(value)
  if value == nil then
    return nil
  end
  return string.lower(tostring(value))
end

local function ParseSlash(msg)
  local text = Trim(msg)
  if not text then
    return "list", nil
  end
  local action, rest = text:match("^(%S+)%s*(.-)%s*$")
  if not action then
    return "list", nil
  end
  return string.lower(action), Trim(rest)
end

local AuthorityManager = {}
AuthorityManager.__index = AuthorityManager

function NS:CreateAuthorityManager(owner)
  return setmetatable({
    gld = owner,
    rankByName = {},
    mainByAlt = {},
    nameByLookup = {},
    cache = {},
    lastBuildAt = 0,
    lastRosterCount = 0,
  }, AuthorityManager)
end

function AuthorityManager:IsDebugEnabled()
  local owner = self.gld
  return owner and owner.IsDebugEnabled and owner:IsDebugEnabled() or false
end

function AuthorityManager:Print(msg)
  local owner = self.gld
  if owner and owner.Print then
    owner:Print(msg)
  end
end

function AuthorityManager:Debug(msg)
  local owner = self.gld
  if owner and owner.Debug then
    owner:Debug(msg)
  end
end

function AuthorityManager:NormalizeName(name, realm)
  local owner = self.gld
  if owner and owner.NormalizeGuildMemberFullName then
    return owner:NormalizeGuildMemberFullName(name, realm)
  end
  local cleanName = Trim(name)
  local cleanRealm = Trim(realm)
  if not cleanName then
    return nil
  end
  cleanName = cleanName:gsub("%s*%-%s*", "-")
  if Ambiguate then
    cleanName = Ambiguate(cleanName, "none") or cleanName
  end
  if cleanRealm then
    return BuildFullName(cleanName, cleanRealm)
  end
  local baseName, realmName = strsplit("-", cleanName, 2)
  return BuildFullName(baseName, realmName)
end

function AuthorityManager:LookupKey(name)
  local normalized = self:NormalizeName(name)
  if not normalized then
    return nil
  end
  return Lower(normalized)
end

function AuthorityManager:ResolveKnownName(name)
  local normalized = self:NormalizeName(name)
  if not normalized then
    return nil
  end
  if self.rankByName[normalized] ~= nil or self.mainByAlt[normalized] ~= nil then
    return normalized
  end
  local lookup = Lower(normalized)
  return self.nameByLookup[lookup] or normalized
end

function AuthorityManager:GetOfficerThresholdRankIndex()
  local owner = self.gld
  local config = owner and owner.GetConfig and owner:GetConfig() or nil
  local raw = config and config.officerThresholdRankIndex or nil
  local threshold = tonumber(raw)
  if threshold == nil then
    threshold = DEFAULT_OFFICER_THRESHOLD_RANK_INDEX
  end
  threshold = math.floor(threshold)
  if threshold < 0 then
    threshold = 0
  end
  return threshold
end

function AuthorityManager:GetWhitelist()
  local owner = self.gld
  if not owner or not owner.db then
    return nil
  end
  owner.db.authorityWhitelist = owner.db.authorityWhitelist or {}
  return owner.db.authorityWhitelist
end

function AuthorityManager:FindWhitelistKey(name)
  local whitelist = self:GetWhitelist()
  local normalized = self:NormalizeName(name)
  if not whitelist or not normalized then
    return nil, normalized
  end
  if whitelist[normalized] == true then
    return normalized, normalized
  end
  local needle = Lower(normalized)
  for key, enabled in pairs(whitelist) do
    if enabled == true and Lower(key) == needle then
      return key, normalized
    end
  end
  return nil, normalized
end

function AuthorityManager:IsWhitelisted(name)
  local key = self:FindWhitelistKey(name)
  return key ~= nil, key
end

function AuthorityManager:InvalidateCache()
  self.cache = {}
end

function AuthorityManager:ParseMainFromNotes(officerNote, publicNote)
  local function parse(noteText)
    if type(noteText) ~= "string" or noteText == "" then
      return nil
    end
    local candidate = noteText:match(MAIN_NOTE_PATTERN)
    if not candidate then
      return nil
    end
    return self:NormalizeName(candidate)
  end

  local main = parse(officerNote)
  if main then
    return main, "officer"
  end
  main = parse(publicNote)
  if main then
    return main, "public"
  end
  return nil, nil
end

function AuthorityManager:RequestGuildRosterRefresh(reason)
  if not IsInGuild() then
    return
  end
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  elseif GuildRoster then
    GuildRoster()
  end
  if self:IsDebugEnabled() then
    self:Debug("[Authority] roster refresh requested reason=" .. tostring(reason or "manual"))
  end
end

function AuthorityManager:RebuildFromGuildRoster(reason)
  local owner = self.gld
  if owner and owner.RebuildGuildOfficerRosterCache then
    owner:RebuildGuildOfficerRosterCache(reason or "AuthorityManager.RebuildFromGuildRoster")
    local cache = owner.GetGuildOfficerRosterCache and owner:GetGuildOfficerRosterCache() or nil
    self.rankByName = cache and cache.rankByName or {}
    self.mainByAlt = {}
    self.nameByLookup = cache and cache.nameByLookup or {}
    self.lastBuildAt = (GetServerTime and GetServerTime()) or time()
    self.lastRosterCount = cache and tonumber(cache.count) or 0
    self:InvalidateCache()
    if self:IsDebugEnabled() then
      self:Debug(
        string.format(
          "[Authority] roster rebuilt reason=%s members=%d linkedAlts=0",
          tostring(reason or "unknown"),
          tonumber(self.lastRosterCount) or 0
        )
      )
    end
    return cache and cache.ready == true
  end

  if not IsInGuild() then
    self.rankByName = {}
    self.mainByAlt = {}
    self.nameByLookup = {}
    self:InvalidateCache()
    if self:IsDebugEnabled() then
      self:Debug("[Authority] cleared authority roster: not in guild")
    end
    return false
  end
  if not GetNumGuildMembers or not GetGuildRosterInfo then
    return false
  end

  local count = GetNumGuildMembers() or 0
  if count <= 0 then
    self:InvalidateCache()
    if self:IsDebugEnabled() then
      self:Debug("[Authority] rebuild skipped: guild roster empty reason=" .. tostring(reason or "unknown"))
    end
    return false
  end

  local rankByName = {}
  local mainByAlt = {}
  local nameByLookup = {}
  local linkedCount = 0
  for i = 1, count do
    local name, _, rankIndex, _, _, _, publicNote, officerNote = GetGuildRosterInfo(i)
    local normalized = self:NormalizeName(name)
    if normalized then
      rankByName[normalized] = tonumber(rankIndex)
      nameByLookup[Lower(normalized)] = normalized
      local main = self:ParseMainFromNotes(officerNote, publicNote)
      if main and Lower(main) ~= Lower(normalized) then
        mainByAlt[normalized] = main
        linkedCount = linkedCount + 1
      end
    end
  end

  self.rankByName = rankByName
  self.mainByAlt = mainByAlt
  self.nameByLookup = nameByLookup
  self.lastBuildAt = (GetServerTime and GetServerTime()) or time()
  self.lastRosterCount = count
  self:InvalidateCache()

  if self:IsDebugEnabled() then
    self:Debug(
      string.format(
        "[Authority] roster rebuilt reason=%s members=%d linkedAlts=%d",
        tostring(reason or "unknown"),
        count,
        linkedCount
      )
    )
  end
  return true
end

function AuthorityManager:GetRankByName(name)
  local canonical = self:ResolveKnownName(name)
  if not canonical then
    return nil, nil
  end
  local rankIndex = self.rankByName[canonical]
  if rankIndex ~= nil then
    return rankIndex, canonical
  end

  local owner = self.gld
  local function tryUnit(unit)
    if not unit or not UnitExists(unit) then
      return nil
    end
    local unitName = owner and owner.GetUnitFullName and owner:GetUnitFullName(unit) or UnitName(unit)
    if not unitName then
      return nil
    end
    if Lower(self:NormalizeName(unitName)) ~= Lower(canonical) then
      return nil
    end
    local _, _, unitRank = GetGuildInfo(unit)
    return tonumber(unitRank)
  end

  rankIndex = tryUnit("player")
  if rankIndex == nil and IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      rankIndex = tryUnit("raid" .. i)
      if rankIndex ~= nil then
        break
      end
    end
  end
  if rankIndex ~= nil then
    self.rankByName[canonical] = rankIndex
    self.nameByLookup[Lower(canonical)] = canonical
  end
  return rankIndex, canonical
end

function AuthorityManager:GetMainForAlt(name)
  local canonical = self:ResolveKnownName(name)
  if not canonical then
    return nil, nil
  end
  local main = self.mainByAlt[canonical]
  if not main then
    return nil, canonical
  end
  return self:ResolveKnownName(main), canonical
end

function AuthorityManager:IsRankAuthorized(rankIndex, threshold)
  if rankIndex == nil then
    return false, "no_rank"
  end
  if rankIndex == 0 then
    return true, "guild_master"
  end
  if rankIndex <= threshold then
    return true, "officer_threshold"
  end
  return false, "rank_above_threshold"
end

function AuthorityManager:ShouldLogDecision(options, fromCache)
  if type(options) == "table" and options.logDecision == false then
    return false
  end
  if fromCache and not (type(options) == "table" and options.logCache == true) then
    return false
  end
  return self:IsDebugEnabled()
end

function AuthorityManager:LogDecision(subject, allowed, reason, details, options, fromCache)
  if not self:ShouldLogDecision(options, fromCache) then
    return
  end
  details = details or {}
  self:Debug(
    string.format(
      "[Authority] source=%s subject=%s allowed=%s reason=%s rank=%s rankName=%s rosterMatch=%s isOfficer=%s isGuildMaster=%s cache=%s",
      tostring(options and options.source or "unknown"),
      tostring(subject or "nil"),
      tostring(allowed == true),
      tostring(reason or "unknown"),
      tostring(details.rankIndex),
      tostring(details.rankName),
      tostring(details.rosterMatch == true),
      tostring(details.isOfficer == true),
      tostring(details.isGuildMaster == true),
      tostring(fromCache == true)
    )
  )
end

function AuthorityManager:EvaluateAuthority(name)
  local subject = self:ResolveKnownName(name)
  local details = {
    subject = subject,
    rankIndex = nil,
    rankName = nil,
    rosterMatch = false,
    isOfficer = false,
    isGuildMaster = false,
  }
  if not subject then
    return false, "invalid_name", details
  end

  local owner = self.gld
  if not owner then
    return false, "owner_unavailable", details
  end

  local localName = owner.GetUnitFullName and owner:GetUnitFullName("player") or UnitName("player")
  if owner.NormalizeGuildMemberFullName then
    localName = owner:NormalizeGuildMemberFullName(localName)
  end
  local isLocalSubject = localName and Lower(localName) == Lower(subject) or false
  local allowed, reason, authorityDetails = false, "manager_unavailable", nil

  if isLocalSubject and owner.IsUnitGuildOfficer then
    allowed, reason, authorityDetails = owner:IsUnitGuildOfficer("player")
  elseif owner.IsNameGuildOfficer then
    allowed, reason, authorityDetails = owner:IsNameGuildOfficer(subject)
  end

  if type(authorityDetails) == "table" then
    details.rankIndex = authorityDetails.rankIndex
    details.rankName = authorityDetails.rankName
    details.rosterMatch = authorityDetails.rosterMatch == true
    details.isOfficer = authorityDetails.isOfficer == true
    details.isGuildMaster = authorityDetails.isGuildMaster == true
  end
  return allowed == true, reason, details
end

function AuthorityManager:IsAuthority(name, options)
  local subject = self:ResolveKnownName(name)
  if not subject then
    local _, _, details = self:EvaluateAuthority(name)
    self:LogDecision(name, false, "invalid_name", details, options, false)
    return false, "invalid_name", details
  end

  local lookup = Lower(subject)
  local cached = self.cache[lookup]
  if cached then
    self:LogDecision(subject, cached.allowed, cached.reason, cached.details, options, true)
    return cached.allowed, cached.reason, cached.details
  end

  local allowed, reason, details = self:EvaluateAuthority(subject)
  self.cache[lookup] = {
    allowed = allowed == true,
    reason = reason,
    details = details,
  }
  self:LogDecision(subject, allowed, reason, details, options, false)
  return allowed, reason, details
end

function AuthorityManager:Usage()
  self:Print("Usage: /lootauth add Name[-Realm], /lootauth remove Name[-Realm], /lootauth list")
end

function AuthorityManager:ListWhitelist()
  local whitelist = self:GetWhitelist()
  if not whitelist then
    self:Print("Authority whitelist unavailable.")
    return
  end
  local entries = {}
  for name, enabled in pairs(whitelist) do
    if enabled == true then
      entries[#entries + 1] = tostring(name)
    end
  end
  table.sort(entries)
  if #entries == 0 then
    self:Print("Authority whitelist is empty.")
    return
  end
  self:Print("Authority whitelist:")
  for _, name in ipairs(entries) do
    self:Print(" - " .. tostring(name))
  end
end

function AuthorityManager:CanManageWhitelist()
  local owner = self.gld
  if not owner or not owner.IsLocalAuthority then
    return false
  end
  return select(1, owner:IsLocalAuthority({ source = "AuthorityManager.CanManageWhitelist" })) == true
end

function AuthorityManager:AddWhitelist(name)
  local whitelist = self:GetWhitelist()
  if not whitelist then
    return false, "whitelist_unavailable"
  end
  local normalized = self:ResolveKnownName(name)
  if not normalized then
    normalized = self:NormalizeName(name)
  end
  if not normalized then
    return false, "invalid_name"
  end
  whitelist[normalized] = true
  self:InvalidateCache()
  local owner = self.gld
  if owner and owner.MarkDBChanged then
    owner:MarkDBChanged("authority_whitelist_add")
  end
  return true, normalized
end

function AuthorityManager:RemoveWhitelist(name)
  local whitelist = self:GetWhitelist()
  if not whitelist then
    return false, "whitelist_unavailable"
  end
  local key = self:FindWhitelistKey(name)
  if not key then
    return false, "not_found"
  end
  whitelist[key] = nil
  self:InvalidateCache()
  local owner = self.gld
  if owner and owner.MarkDBChanged then
    owner:MarkDBChanged("authority_whitelist_remove")
  end
  return true, key
end

function AuthorityManager:HandleSlashCommand(msg)
  local action, arg = ParseSlash(msg)
  if action == "list" then
    self:ListWhitelist()
    return
  end
  if action ~= "add" and action ~= "remove" and action ~= "del" and action ~= "delete" then
    self:Usage()
    return
  end
  if not self:CanManageWhitelist() then
    local owner = self.gld
    if owner and owner.ShowPermissionDeniedPopup then
      owner:ShowPermissionDeniedPopup()
    else
      self:Print("You are not authorized to manage authority whitelist.")
    end
    return
  end
  if not arg then
    self:Usage()
    return
  end
  if action == "add" then
    local ok, value = self:AddWhitelist(arg)
    if ok then
      self:Print("Authority whitelist add: " .. tostring(value))
      return
    end
    self:Print("Authority whitelist add failed: " .. tostring(value))
    return
  end
  local ok, value = self:RemoveWhitelist(arg)
  if ok then
    self:Print("Authority whitelist remove: " .. tostring(value))
    return
  end
  self:Print("Authority whitelist remove failed: " .. tostring(value))
end

function GLD:GetAuthorityManager()
  if not self.AuthorityManager and NS.CreateAuthorityManager then
    self.AuthorityManager = NS:CreateAuthorityManager(self)
  end
  return self.AuthorityManager
end

function GLD:InitAuthorityManager()
  local manager = self:GetAuthorityManager()
  if not manager then
    return
  end
  manager:RebuildFromGuildRoster("init")
  manager:RequestGuildRosterRefresh("init")
end

function GLD:OnGuildRosterUpdate()
  local manager = self:GetAuthorityManager()
  if manager then
    manager:RebuildFromGuildRoster("GUILD_ROSTER_UPDATE")
  elseif self.RebuildGuildOfficerRosterCache then
    self:RebuildGuildOfficerRosterCache("GUILD_ROSTER_UPDATE")
  end
end

function GLD:RequestAuthorityRosterRefresh(reason)
  local manager = self:GetAuthorityManager()
  if not manager then
    return
  end
  manager:RequestGuildRosterRefresh(reason)
end

function GLD:GetOfficerThresholdRankIndex()
  local manager = self:GetAuthorityManager()
  if manager and manager.GetOfficerThresholdRankIndex then
    return manager:GetOfficerThresholdRankIndex()
  end
  return DEFAULT_OFFICER_THRESHOLD_RANK_INDEX
end

function GLD:IsAuthorityName(name, options)
  local manager = self:GetAuthorityManager()
  if not manager or not manager.IsAuthority then
    return false, "manager_unavailable", nil
  end
  return manager:IsAuthority(name, options)
end

function GLD:IsLocalAuthority(options)
  local fullName = self.GetUnitFullName and self:GetUnitFullName("player") or UnitName("player")
  return self:IsAuthorityName(fullName, options)
end

function GLD:HandleLootAuthSlashCommand(msg)
  local manager = self:GetAuthorityManager()
  if not manager or not manager.HandleSlashCommand then
    self:Print("Authority manager unavailable.")
    return
  end
  manager:HandleSlashCommand(msg)
end
