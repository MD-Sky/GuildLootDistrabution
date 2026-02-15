local _, NS = ...

local GLD = NS.GLD

local CLASS_FILE_TO_ID = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  DEATHKNIGHT = 6,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  MONK = 10,
  DRUID = 11,
  DEMONHUNTER = 12,
  EVOKER = 13,
}

function GLD:InitSpec()
  self.specCache = self.specCache or {}
  self.inspectQueue = self.inspectQueue or {}
  self._inspectTicker = self._inspectTicker or nil
end

local function GetUnitKey(unit)
  return NS:GetPlayerKeyFromUnit(unit)
end

function GLD:UpdatePlayerSpecFromId(player, specId)
  if not player then
    return
  end
  if not specId or specId == 0 then
    return
  end
  if not GetSpecializationInfoByID then
    player.specId = specId
    return
  end
  local _, name, _, icon = GetSpecializationInfoByID(specId)
  player.specId = specId
  player.specName = name
  if icon then
    player.specIcon = icon
  end
end

function GLD:GetSpecIcon(member)
  if not member then
    return nil
  end
  if member.specIcon and member.specIcon ~= "" then
    return member.specIcon
  end
  local specId = member.specId
  if specId and specId > 0 and GetSpecializationInfoByID then
    local _, _, _, icon = GetSpecializationInfoByID(specId)
    if icon then
      return icon
    end
  end

  local specName = member.specName or member.spec
  local classFile = member.classFile or member.classFileName or member.class
  if specName and classFile and GetSpecializationInfoForClassID and GetNumSpecializationsForClassID then
    if type(classFile) == "string" then
      classFile = classFile:upper()
    end
    local classID = CLASS_FILE_TO_ID[classFile]
    if classID then
      local count = GetNumSpecializationsForClassID(classID) or 0
      local target = type(specName) == "string" and specName:lower() or nil
      if target then
        for i = 1, count do
          local _, name, _, icon = GetSpecializationInfoForClassID(classID, i)
          if name and icon and name:lower() == target then
            return icon
          end
        end
      end
    end
  end

  return nil
end

function GLD:UpdateSelfSpec()
  local specIndex = GetSpecialization()
  if not specIndex then
    return
  end
  local specId = GetSpecializationInfo(specIndex)
  if not specId then
    return
  end
  local key = NS:GetPlayerKeyFromUnit("player")
  if key and self.db.players and self.db.players[key] then
    self:UpdatePlayerSpecFromId(self.db.players[key], specId)
  end
end

function GLD:QueueInspect(unit)
  if not unit or not UnitExists(unit) then
    return
  end
  if not CanInspect or not CanInspect(unit) then
    return
  end
  if UnitIsDeadOrGhost(unit) then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if not self.inspectQueue then
    self.inspectQueue = {}
  end
  local key = GetUnitKey(unit)
  if not key then
    return
  end
  self.inspectQueue[key] = unit
  if not self._inspectTicker then
    self._inspectTicker = C_Timer.NewTicker(0.3, function()
      GLD:ProcessInspectQueue()
    end)
  end
end

function GLD:ProcessInspectQueue()
  if not self.inspectQueue then
    self.inspectQueue = {}
  end
  for key, unit in pairs(self.inspectQueue) do
    if unit and UnitExists(unit) and CanInspect(unit) then
      NotifyInspect(unit)
      return
    else
      self.inspectQueue[key] = nil
    end
  end
  if self._inspectTicker then
    self._inspectTicker:Cancel()
    self._inspectTicker = nil
  end
end

function GLD:OnInspectReady(_, guid)
  if not guid then
    return
  end
  local unit = nil
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local u = "raid" .. i
      if UnitGUID(u) == guid then
        unit = u
        break
      end
    end
  else
    if UnitGUID("player") == guid then
      unit = "player"
    end
  end

  local specId = GetInspectSpecialization(unit)
  if specId and specId > 0 then
    local key = NS:GetPlayerKeyFromUnit(unit)
    if key and self.db.players and self.db.players[key] then
      self:UpdatePlayerSpecFromId(self.db.players[key], specId)
      if self.UI and self.UI.RefreshMain then
        self.UI:RefreshMain()
      end
      if NS.TestUI and NS.TestUI.RefreshTestPanel then
        NS.TestUI:RefreshTestPanel()
      end
    end
  end

  if self.inspectQueue then
    for k, u in pairs(self.inspectQueue) do
      if u and UnitGUID(u) == guid then
        self.inspectQueue[k] = nil
        break
      end
    end
  end
end

function GLD:QueueGroupSpecSync()
  self:UpdateSelfSpec()
  if not IsInRaid() then
    return
  end
  for i = 1, GetNumGroupMembers() do
    self:QueueInspect("raid" .. i)
  end
end

function GLD:OnPlayerSpecChanged(_, unit)
  if not unit then
    return
  end
  if unit == "player" then
    self:UpdateSelfSpec()
  else
    self:QueueInspect(unit)
  end
end

local function SimplifySpecName(name)
  if not name then
    return nil
  end
  local specName = tostring(name)
  specName = specName:lower()
  specName = specName:gsub("%s+", "")
  specName = specName:gsub("[^%w]", "")
  if specName == "" then
    return nil
  end
  return specName
end

local function GetMemberSpecName(member)
  if not member then
    return nil
  end
  local specName = member.specName or member.spec
  if not specName and member.specId and GetSpecializationInfoByID then
    local _, name = GetSpecializationInfoByID(member.specId)
    specName = name
  end
  if not specName or specName == "" then
    return nil
  end
  return specName
end

local function GetRoleFromClassSpec(member)
  if not member then
    return nil
  end
  local classFile = member.classFile or member.classFileName or member.class
  if not classFile or not NS.CLASS_DATA then
    return nil
  end
  classFile = tostring(classFile):upper()
  local classInfo = NS.CLASS_DATA[classFile]
  if not classInfo or not classInfo.specs then
    return nil
  end
  local target = SimplifySpecName(GetMemberSpecName(member))
  if not target then
    return nil
  end
  for specKey, specInfo in pairs(classInfo.specs) do
    if specInfo and specInfo.role then
      local normalizedKey = SimplifySpecName(specKey)
      if normalizedKey == target then
        return specInfo.role
      end
    end
  end
  return nil
end

function GLD:GetRole(member)
  if not member then
    return nil
  end
  local role = member.role
  if role and role ~= "" and role ~= "NONE" then
    return role
  end
  role = GetRoleFromClassSpec(member)
  if role then
    return role
  end
  if NS.GetRoleForPlayer then
    local baseName = member.name and NS:GetPlayerBaseName(member.name)
    if not baseName and member.displayName then
      baseName = NS:GetPlayerBaseName(member.displayName)
    end
    if baseName then
      role = NS:GetRoleForPlayer(baseName)
      if role and role ~= "NONE" then
        return role
      end
    end
  end
  return nil
end

function GLD:FinalSpecSyncBeforePull()
  if self.QueueGroupSpecSync then
    self:QueueGroupSpecSync()
  end
end
