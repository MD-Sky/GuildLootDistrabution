local _, NS = ...

local GLD = NS.GLD
local AceGUI = LibStub("AceGUI-3.0", true)
local LootEngine = NS.LootEngine
local LiveProvider = NS.LiveProvider
local TestProvider = NS.TestProvider

local TestUI = {}
NS.TestUI = TestUI

local TEST_VOTERS = {
  { name = "Lily", class = "DRUID", armor = "Leather", weapon = "Staff" },
  { name = "Rob", class = "SHAMAN", armor = "Mail", weapon = "One-Handed Mace & Shield" },
  { name = "Steph", class = "HUNTER", armor = "Mail", weapon = "Bow" },
  { name = "Alex", class = "WARLOCK", armor = "Cloth", weapon = "Staff" },
  { name = "Ryan", class = "DEATHKNIGHT", armor = "Plate", weapon = "Two-Handed Sword" },
  { name = "Vulthan", class = "WARRIOR", armor = "Plate", weapon = "Two-Handed Axe" },
}

local CLASS_DATA = NS.CLASS_DATA or {}
local CLASS_TO_ARMOR = {
  WARRIOR = "Plate",
  PALADIN = "Plate",
  DEATHKNIGHT = "Plate",
  HUNTER = "Mail",
  SHAMAN = "Mail",
  EVOKER = "Mail",
  ROGUE = "Leather",
  DRUID = "Leather",
  MONK = "Leather",
  DEMONHUNTER = "Leather",
  PRIEST = "Cloth",
  MAGE = "Cloth",
  WARLOCK = "Cloth",
}

local ADMIN_ROW_HEIGHT = 20
local ADMIN_HEADER_HEIGHT = 22
local ADMIN_COLUMN_PADDING = 4
local ADMIN_SECTION_PADDING = 6
local ADMIN_BUTTON_HEIGHT = 20
local ADMIN_SCROLLBAR_OFFSET = 24
local ADMIN_PREVIEW_MODE_POPUP_KEY = "GLD_ADMIN_PREVIEW_MODE_CHOICE"

local ADMIN_HEADER_BACKDROP = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 8,
  edgeSize = 10,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local PLAYER_COLUMNS = {
  { key = "class", label = "Class", width = 60, align = "LEFT" },
  { key = "spec", label = "Spec", width = 80, align = "LEFT" },
  { key = "role", label = "Role", width = 50, align = "CENTER" },
  { key = "name", label = "Name", width = 180, align = "LEFT" },
  { key = "attendance", label = "Attendance", width = 90, align = "CENTER" },
  { key = "mark", label = "Mark Present", width = 110, align = "CENTER" },
  { key = "queue", label = "Queue", width = 60, align = "CENTER" },
  { key = "frozen", label = "Frozen", width = 60, align = "CENTER" },
  { key = "won", label = "Won", width = 60, align = "CENTER" },
  { key = "raids", label = "Raids", width = 60, align = "CENTER" },
  { key = "remove", label = "Remove", width = 70, align = "CENTER" },
}

local RESULT_COLUMNS = {
  { key = "name", label = "Name", width = 160, align = "LEFT" },
  { key = "choice", label = "Choice", width = 90, align = "CENTER" },
  { key = "queue", label = "Queue Pos", width = 70, align = "CENTER" },
  { key = "frozen", label = "Held Pos", width = 70, align = "CENTER" },
  { key = "loot", label = "Loot Item Type", width = 150, align = "LEFT" },
  { key = "class", label = "Class", width = 70, align = "CENTER" },
  { key = "armor", label = "Armor Type", width = 90, align = "CENTER" },
  { key = "weapon", label = "Weapon Type", width = 140, align = "LEFT" },
}

local TEST_DATA_COLUMNS = {
  { key = "class", label = "Class", width = 70, align = "LEFT" },
  { key = "spec", label = "Spec", width = 100, align = "LEFT" },
  { key = "role", label = "Role", width = 60, align = "CENTER" },
  { key = "name", label = "Name", width = 160, align = "LEFT" },
  { key = "queue", label = "Queue Pos", width = 70, align = "CENTER" },
  { key = "held", label = "Held Pos", width = 70, align = "CENTER" },
  { key = "won", label = "Won", width = 60, align = "CENTER" },
  { key = "raids", label = "Raids", width = 60, align = "CENTER" },
  { key = "edit", label = "Edit", width = 50, align = "CENTER" },
  { key = "remove", label = "Remove", width = 60, align = "CENTER" },
}

local function AddSpecialFrame(name)
  if not name then
    return
  end
  if not UISpecialFrames then
    UISpecialFrames = {}
  end
  for _, existing in ipairs(UISpecialFrames) do
    if existing == name then
      return
    end
  end
  table.insert(UISpecialFrames, name)
end

local function EnsureAdminPreviewModePopup()
  if not StaticPopupDialogs or StaticPopupDialogs[ADMIN_PREVIEW_MODE_POPUP_KEY] then
    return
  end
  StaticPopupDialogs[ADMIN_PREVIEW_MODE_POPUP_KEY] = {
    text = "|cffffd200Admin Preview Mode|r\nPug mode?",
    button1 = "Yes (Pug Mode)",
    button2 = "No (Guild Mode)",
    button3 = CANCEL,
    OnAccept = function(_, data)
      local callback = data and data.onChoice
      if type(callback) == "function" then
        callback(true)
      end
    end,
    OnCancel = function(_, data, reason)
      if reason ~= "clicked" then
        return
      end
      local callback = data and data.onChoice
      if type(callback) == "function" then
        callback(false)
      end
    end,
    OnAlt = function()
      -- Cancel button: no-op.
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
end

function TestUI:PromptPugModeChoice(onChoice)
  if type(onChoice) ~= "function" then
    return
  end
  EnsureAdminPreviewModePopup()
  StaticPopup_Show(ADMIN_PREVIEW_MODE_POPUP_KEY, nil, nil, {
    onChoice = function(choice)
      local ok, err = pcall(onChoice, choice)
      if not ok and GLD and GLD.Print then
        GLD:Print("Failed to open admin preview: " .. tostring(err))
      end
    end,
  })
end

GLD.AdminTest = GLD.AdminTest or {}
function GLD.AdminTest:PromptPugModeChoice(onChoice)
  if NS and NS.TestUI and NS.TestUI.PromptPugModeChoice then
    NS.TestUI:PromptPugModeChoice(onChoice)
  end
end

local function CopyColumnDefs(columns)
  local copy = {}
  for index, col in ipairs(columns or {}) do
    local entry = {}
    for key, value in pairs(col) do
      entry[key] = value
    end
    copy[index] = entry
  end
  return copy
end

local function BuildColumnMap(columns)
  local map = {}
  for _, col in ipairs(columns or {}) do
    map[col.key] = col
  end
  return map
end

local function UpdateColumnOffsets(columns, startX)
  local x = startX or 0
  for _, col in ipairs(columns or {}) do
    col.x = x
    x = x + col.width + ADMIN_COLUMN_PADDING
  end
end

local function ApplyHeaderCellStyle(frame)
  if not frame or not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(ADMIN_HEADER_BACKDROP)
  frame:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
  frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
end

local function SetEditBoxEnabled(editBox, enabled)
  if not editBox then
    return
  end
  if editBox.SetEnabled then
    editBox:SetEnabled(enabled)
  else
    editBox:EnableMouse(enabled)
  end
  if editBox.SetTextColor then
    if enabled then
      editBox:SetTextColor(1, 1, 1)
    else
      editBox:SetTextColor(0.6, 0.6, 0.6)
    end
  end
end

local function ParseNonNegativeInt(text)
  local num = tonumber(text)
  if not num or num < 0 then
    return nil
  end
  if math.floor(num) ~= num then
    return nil
  end
  return num
end

local function GetClassColor(classFile)
  if not classFile then
    return 1, 1, 1
  end
  local color = nil
  if C_ClassColor and C_ClassColor.GetClassColor then
    color = C_ClassColor.GetClassColor(classFile)
  elseif RAID_CLASS_COLORS then
    color = RAID_CLASS_COLORS[classFile]
  end
  if color then
    return color.r or 1, color.g or 1, color.b or 1
  end
  return 1, 1, 1
end

local function GetAttendanceColor(attendance)
  local key = (attendance or ""):upper()
  if key == "PRESENT" then
    return 0.55, 0.9, 0.55
  end
  return 0.9, 0.45, 0.45
end

local function GetArmorForClass(classFile)
  local data = CLASS_DATA and CLASS_DATA[classFile]
  if data and data.armor then
    return data.armor
  end
  return CLASS_TO_ARMOR[classFile] or "-"
end

local function GetRoleForClassSpec(classFile, specName)
  if not classFile or not specName then
    return "-"
  end
  local classData = CLASS_DATA and CLASS_DATA[classFile]
  if not classData or not classData.specs then
    return "-"
  end
  local target = tostring(specName):lower()
  for name, data in pairs(classData.specs) do
    if name and name:lower() == target then
      return data and data.role or "-"
    end
  end
  return "-"
end

local function GetSortedKeys(tbl)
  local keys = {}
  for key in pairs(tbl or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function BuildClassOptions()
  local options = {}
  for _, classToken in ipairs(GetSortedKeys(CLASS_DATA)) do
    options[classToken] = classToken
  end
  return options
end

local function BuildSpecOptionsForClass(classToken)
  local options = {}
  local classData = CLASS_DATA and CLASS_DATA[classToken]
  if classData and classData.specs then
    local specs = GetSortedKeys(classData.specs)
    for _, specName in ipairs(specs) do
      options[specName] = specName
    end
  end
  return options
end

local function BuildDynamicTestVoters()
  if not IsInRaid() then
    return nil
  end

  local voters = {}
  local function addUnit(unit)
    if not UnitExists(unit) then
      return
    end
    local name, realm = UnitName(unit)
    if not name then
      return
    end
    local classFile = select(2, UnitClass(unit))
    local armor = GetArmorForClass(classFile)
    local isGuest = GLD and GLD.IsGuest and GLD:IsGuest(unit) or false
    local displayName = NS:GetPlayerDisplayName(name, isGuest)
    local specName = nil
    if GLD and GLD.FindPlayerKeyByName then
      local key = GLD:FindPlayerKeyByName(name, realm)
      if key and GLD.db and GLD.db.players and GLD.db.players[key] then
        specName = GLD.db.players[key].specName or GLD.db.players[key].spec
      end
    end
    voters[#voters + 1] = {
      name = displayName,
      class = classFile,
      spec = specName,
      armor = armor,
      weapon = nil,
    }
  end

  for i = 1, GetNumGroupMembers() do
    addUnit("raid" .. i)
  end

  if #voters > 0 then
    return voters
  end
  return nil
end

local function IsSolo()
  return not IsInRaid()
end

local function GetTestDB()
  return GLD.testDb
end

local function GetTestPlayersTable()
  local db = GetTestDB()
  return db and db.players or {}
end

local function GetLivePlayersTable()
  return GLD.db and GLD.db.players or {}
end

local function GetLivePlayerDisplayName(player, key, isGuest)
  local rawName = nil
  if player then
    rawName = player.name or player.fullName or player.displayName
  end
  if (not rawName or rawName == "") and key and NS.GetNameRealmFromKey then
    local name, _ = NS:GetNameRealmFromKey(key)
    rawName = name
  end
  if not rawName or rawName == "" then
    return key or "?"
  end
  return NS:GetPlayerDisplayName(rawName, isGuest)
end

local function BuildAdminRosterList()
  local list = {}
  if GLD and GLD.GetRosterSource then
    local source = GLD:GetRosterSource()
    if type(source) == "table" and #source > 0 then
      for _, entry in ipairs(source) do
        local player = entry.member or entry
        local key = entry.key or (player and (player.key or player.playerKey)) or nil
        if player then
          list[#list + 1] = { key = key, player = player }
        end
      end
      return list
    end
  end
  for key, player in pairs(GetLivePlayersTable()) do
    if player then
      list[#list + 1] = { key = key, player = player }
    end
  end
  return list
end

local function BuildTestVotersFromDB()
  local voters = {}
  for _, player in pairs(GetTestPlayersTable()) do
    if player and player.name then
      local fullName = player.name
      if player.realm and player.realm ~= "" then
        fullName = player.name .. "-" .. player.realm
      end
      local specName = player.specName or player.spec
      voters[#voters + 1] = {
        name = fullName,
        class = player.class,
        spec = specName,
        armor = GetArmorForClass(player.class),
        weapon = player.weaponType or "-",
      }
    end
  end
  table.sort(voters, function(a, b)
    local nameA = NS:GetPlayerBaseName(a.name) or (a.name or "")
    local nameB = NS:GetPlayerBaseName(b.name) or (b.name or "")
    return nameA < nameB
  end)
  return voters
end

local function GetActiveVoters()
  if TestUI.dynamicVoters and #TestUI.dynamicVoters > 0 then
    return TestUI.dynamicVoters
  end
  local dbVoters = BuildTestVotersFromDB()
  if #dbVoters > 0 then
    return dbVoters
  end
  return TEST_VOTERS
end

local function BuildSoloExpectedVoters(voters)
  local expected = {}
  local seen = {}
  for _, entry in ipairs(voters or {}) do
    local key = nil
    if entry and entry.name then
      local name, realm = NS:SplitNameRealm(entry.name)
      if TestProvider and TestProvider.GetPlayerKeyByName then
        key = TestProvider:GetPlayerKeyByName(name, realm)
      end
      if not key then
        key = GLD:GetRollCandidateKey(entry.name)
      end
    end
    if key and not seen[key] then
      expected[#expected + 1] = key
      seen[key] = true
    end
  end
  return expected
end

local function GetTestPlayerKey(name, realm)
  if not name or name == "" then
    return nil
  end
  local useRealm = realm and realm ~= "" and realm or GetRealmName()
  return name .. "-" .. useRealm
end

local function GetOrCreateTestPlayer(name, realm, class)
  local key = GetTestPlayerKey(name, realm)
  if not key then
    return nil, nil
  end
  local db = GetTestDB()
  if not db then
    return nil, nil
  end
  db.players = db.players or {}
  local player = db.players[key]
  if not player then
    player = {
      name = name,
      realm = realm or GetRealmName(),
      class = class,
      attendance = "PRESENT",
      numAccepted = 0,
      attendanceCount = 0,
      queuePos = nil,
      savedPos = 0,
    }
    db.players[key] = player
  end
  return player, key
end

local function BuildTestRosterList()
  local list = {}
  if TestUI.dynamicVoters and #TestUI.dynamicVoters > 0 then
    for _, voter in ipairs(TestUI.dynamicVoters) do
      local name, realm = NS:SplitNameRealm(voter.name)
      local player = GetOrCreateTestPlayer(name, realm, voter.class)
      if player then
        list[#list + 1] = player
      end
    end
    return list
  end

  for _, player in pairs(GetTestPlayersTable()) do
    list[#list + 1] = player
  end
  return list
end

local function GetTestVoter(index)
  return GetActiveVoters()[index]
end

local function GetTestVoterName(index)
  local entry = GetActiveVoters()[index]
  return entry and entry.name or nil
end

local function FormatDateTime(ts)
  if not ts or ts == 0 then
    return "-"
  end
  return date("%Y-%m-%d %H:%M", ts)
end

local function FormatDuration(startedAt, endedAt)
  if not startedAt or startedAt == 0 then
    return "-"
  end
  local finish = endedAt and endedAt > 0 and endedAt or GetServerTime()
  local total = math.max(0, finish - startedAt)
  local hours = math.floor(total / 3600)
  local mins = math.floor((total % 3600) / 60)
  return string.format("%dh %dm", hours, mins)
end

local function NormalizeItemInput(itemLink)
  if not itemLink or itemLink == "" then
    return nil
  end
  local normalized = itemLink
  local wowheadId = itemLink:match("item=(%d+)")
  if wowheadId then
    normalized = "item:" .. wowheadId
  end
  if not normalized:find("|Hitem:") and normalized:find("^item:%d+") then
    normalized = "item:" .. normalized:match("item:(%d+)")
  end
  return normalized
end

local function ResolveItemClassId(itemType)
  if not itemType or not ITEM_CLASSES then
    return nil
  end
  for classId, className in pairs(ITEM_CLASSES) do
    if className == itemType then
      return classId
    end
  end
  return nil
end

local function GetItemInfoInstantCompat(itemLink)
  if not itemLink or itemLink == "" then
    return nil
  end
  if C_Item and C_Item.GetItemInfoInstant then
    local itemID, itemType, itemSubType, itemEquipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
    if classID ~= nil then
      return classID, subClassID, itemType, itemEquipLoc
    end
    if type(itemID) == "number" and type(itemType) == "number" then
      return itemID, itemType, itemSubType, itemEquipLoc
    end
    local resolvedClassID = ResolveItemClassId(itemType)
    if resolvedClassID then
      return resolvedClassID, subClassID, itemType, itemEquipLoc
    end
  end
  if GetItemInfoInstant then
    local itemID, itemType, itemSubType, itemEquipLoc, _, classID, subClassID = GetItemInfoInstant(itemLink)
    if classID ~= nil then
      return classID, subClassID, itemType, itemEquipLoc
    end
    if type(itemID) == "number" and type(itemType) == "number" then
      return itemID, itemType, itemSubType, itemEquipLoc
    end
    local resolvedClassID = ResolveItemClassId(itemType)
    if resolvedClassID then
      return resolvedClassID, subClassID, itemType, itemEquipLoc
    end
  end
  if GetItemInfo then
    local _, _, _, _, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
    local resolvedClassID = ResolveItemClassId(itemType)
    if resolvedClassID then
      return resolvedClassID, nil, itemSubType, itemEquipLoc
    end
  end
  return nil
end

local function IsEligibleForNeedSafe(classFile, itemLink)
  if not classFile or not itemLink then
    return false
  end
  local classID = GetItemInfoInstantCompat(itemLink)
  if not classID then
    GLD:RequestItemData(itemLink)
    return true
  end
  return GLD:IsEligibleForNeed(classFile, itemLink)
end

local EQUIP_SLOT_LABELS = {
  INVTYPE_HEAD = "Head",
  INVTYPE_SHOULDER = "Shoulder",
  INVTYPE_CHEST = "Chest",
  INVTYPE_ROBE = "Chest",
  INVTYPE_WAIST = "Waist",
  INVTYPE_LEGS = "Legs",
  INVTYPE_FEET = "Feet",
  INVTYPE_WRIST = "Wrist",
  INVTYPE_HAND = "Hands",
  INVTYPE_CLOAK = "Back",
}

local ARMOR_SUBCLASS = {
  [1] = "Cloth",
  [2] = "Leather",
  [3] = "Mail",
  [4] = "Plate",
}

local ARMOR_SPECIAL = {
  [0] = "Trinket",
  [2] = "Neck",
  [11] = "Ring",
}

local function GetArmorTypeOnly(itemLink)
  if not itemLink then
    return "-"
  end
  if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
    return "Trinket"
  end
  local classID, subClassID = GetItemInfoInstantCompat(itemLink)
  if not classID then
    if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
      return "Trinket"
    end
    if GLD and GLD.IsKnownTrinket and GLD:IsKnownTrinket(itemLink) then
      return "Trinket"
    end
    GLD:RequestItemData(itemLink)
    return "-"
  end
  if GLD and GLD.GetItemSetName then
    local setName = GLD:GetItemSetName(itemLink)
    if setName and setName ~= "" then
      return "Tier"
    end
  end
  if classID == 4 then
    local armor = ARMOR_SPECIAL[subClassID] or ARMOR_SUBCLASS[subClassID]
    if armor then
      return armor
    end
  end
  if classID == 2 then
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if itemSubType and itemSubType ~= "" then
      return "Weapon - " .. itemSubType
    end
    return "Weapon"
  end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
  if itemType == "Armor" and itemSubType and itemSubType ~= "" then
    return itemSubType
  end
  if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
    return "Trinket"
  end
  if GLD and GLD.IsKnownTrinket and GLD:IsKnownTrinket(itemLink) then
    return "Trinket"
  end
  if itemType and itemType ~= "" then
    return itemType
  end
  return "Other"
end

local function GetLootTypeText(itemLink)
  if not itemLink then
    return "-"
  end
  local classID, subClassID, _, equipLoc = GetItemInfoInstantCompat(itemLink)
  if not classID then
    if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
      return "Trinket"
    end
    if GLD and GLD.IsKnownTrinket and GLD:IsKnownTrinket(itemLink) then
      return "Trinket"
    end
    return "-"
  end
  if classID == 4 then
    local armor = ARMOR_SUBCLASS[subClassID] or "Armor"
    local slot = EQUIP_SLOT_LABELS[equipLoc] or "Other"
    return armor .. " " .. slot
  end
  if classID == 2 then
    return "Weapon"
  end
  if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
    return "Trinket"
  end
  if GLD and GLD.IsKnownTrinket and GLD:IsKnownTrinket(itemLink) then
    return "Trinket"
  end
  return "Other"
end

local function GetLootTypeDetailed(itemLink)
  if not itemLink then
    return "-"
  end
  local classID, subClassID, _, equipLoc = GetItemInfoInstantCompat(itemLink)
  if not classID then
    if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
      return "Trinket"
    end
    if GLD and GLD.IsKnownTrinket and GLD:IsKnownTrinket(itemLink) then
      return "Trinket"
    end
    return "-"
  end
  if classID == 4 then
    local armor = ARMOR_SPECIAL[subClassID] or ARMOR_SUBCLASS[subClassID] or "Armor"
    local slot = EQUIP_SLOT_LABELS[equipLoc] or "Other"
    return armor .. " " .. slot
  end
  if classID == 2 then
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if itemType == "Weapon" and itemSubType and itemSubType ~= "" then
      return "Weapon - " .. itemSubType
    end
    return "Weapon"
  end
  if GLD and GLD.IsItemInfoTrinket and GLD:IsItemInfoTrinket(itemLink) then
    return "Trinket"
  end
  if GLD and GLD.IsKnownTrinket and GLD:IsKnownTrinket(itemLink) then
    return "Trinket"
  end
  local _, _, _, _, _, itemType = GetItemInfo(itemLink)
  return itemType or "Other"
end

local function IsPreferredItemForEntry(entry, itemLink)
  if not entry or not itemLink then
    return false
  end
  if GLD.IsEligibleForNeed then
    if not GLD:IsEligibleForNeed(entry.class, itemLink, entry.spec) then
      return false
    end
  end
  if GLD.GetItemClassRestrictions then
    local restriction = GLD:GetItemClassRestrictions(itemLink)
    if restriction then
      return restriction[entry.class] == true
    end
  end
  local armorType = GetArmorTypeOnly(itemLink)
  if armorType == "Cloth" or armorType == "Leather" or armorType == "Mail" or armorType == "Plate" then
    return entry.armor == armorType
  end
  if armorType == "Trinket" then
    return true
  end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
  if itemType == "Weapon" then
    if not itemSubType then
      return false
    end

    local function matchPreference(pref, sub)
      if not pref or pref == "" then
        return false
      end
      if pref:find("bow") and sub:find("bow") then
        return true
      end
      if pref:find("gun") and sub:find("gun") then
        return true
      end
      if pref:find("crossbow") and sub:find("crossbow") then
        return true
      end
      if pref:find("staff") and sub:find("staff") then
        return true
      end
      if pref:find("polearm") and sub:find("polearm") then
        return true
      end
      if pref:find("sword") and sub:find("sword") then
        return true
      end
      if pref:find("axe") and sub:find("axe") then
        return true
      end
      if pref:find("mace") and sub:find("mace") then
        return true
      end
      if pref:find("dagger") and sub:find("dagger") then
        return true
      end
      if pref:find("fist") and sub:find("fist") then
        return true
      end
      if pref:find("warglaive") and (sub:find("warglaive") or sub:find("glaive")) then
        return true
      end
      if pref:find("wand") and sub:find("wand") then
        return true
      end
      if pref:find("shield") and sub:find("shield") then
        return true
      end
      if pref:find("two%-handed") and sub:find("two") then
        return true
      end
      if pref:find("one%-handed") and sub:find("one") then
        return true
      end
      return false
    end

    local sub = string.lower(itemSubType)
    if entry.weapon then
      local pref = string.lower(entry.weapon)
      if matchPreference(pref, sub) then
        return true
      end
    elseif entry.class and CLASS_DATA and CLASS_DATA[entry.class] then
      local classInfo = CLASS_DATA[entry.class]
      local prefs = nil
      if entry.spec and classInfo.specs and classInfo.specs[entry.spec] then
        prefs = classInfo.specs[entry.spec].preferredWeapons
      else
        prefs = classInfo.weapons
      end
      if prefs then
        for _, pref in ipairs(prefs) do
          if matchPreference(string.lower(pref), sub) then
            return true
          end
        end
      end
    else
      return false
    end
  end
  return false
end

local function IsNeedAllowedForEntry(entry, itemLink)
  return IsPreferredItemForEntry(entry, itemLink)
end

local function EJ_Call(name, ...)
  if C_EncounterJournal and C_EncounterJournal[name] then
    return C_EncounterJournal[name](...)
  end
  local legacy = _G["EJ_" .. name]
  if legacy then
    return legacy(...)
  end
  return nil
end

local DEFAULT_TEST_RAID = "Manaforge Omega"
local DEFAULT_TEST_ENCOUNTER = "Manaforge Omega"

local function ColorizeClassName(name, classFile, isGuest)
  local displayName = NS:GetPlayerDisplayName(name, isGuest)
  if not displayName or displayName == "" then
    displayName = "?"
  end
  local r, g, b = NS:GetClassColor(classFile)
  if r and g and b then
    return string.format("|cff%02x%02x%02x%s|r", (r * 255), (g * 255), (b * 255), displayName)
  end
  return displayName
end

local function BuildVoteRow(parent, playerName, voteOptions)
  if not parent or not AceGUI then
    return nil
  end
  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")

  local nameLabel = AceGUI:Create("Label")
  nameLabel:SetText(playerName or "?")
  nameLabel:SetWidth(140)
  row:AddChild(nameLabel)

  local buttons = {}
  for _, opt in ipairs(voteOptions or {}) do
    local btn = AceGUI:Create("Button")
    btn:SetText(opt.label or "?")
    btn:SetWidth(70)
    if opt.disabled and btn.SetDisabled then
      btn:SetDisabled(true)
    end
    btn:SetCallback("OnClick", function()
      if opt.onClick then
        opt.onClick(opt.vote)
      end
    end)
    row:AddChild(btn)
    buttons[#buttons + 1] = btn
  end

  local statusLabel = AceGUI:Create("Label")
  statusLabel:SetText("")
  statusLabel:SetWidth(60)
  row:AddChild(statusLabel)

  parent:AddChild(row)
  return {
    row = row,
    buttons = buttons,
    statusLabel = statusLabel,
  }
end

local function SetTestAttendance(player, state)
  if not player then
    return
  end
  local changed = player.attendance ~= state
  if state == "ABSENT" then
    if player.attendance ~= "ABSENT" then
      player.savedPos = player.queuePos or player.savedPos
      player.queuePos = nil
    end
    player.attendance = "ABSENT"
    if changed and GLD.NormalizeTestQueuePositions then
      GLD:NormalizeTestQueuePositions()
    end
    return
  end
  if state == "PRESENT" then
    if player.attendance ~= "PRESENT" and player.savedPos and player.savedPos > 0 then
      player.queuePos = player.savedPos
    end
    player.attendance = "PRESENT"
    if changed and GLD.NormalizeTestQueuePositions then
      GLD:NormalizeTestQueuePositions()
    end
  end
end

function TestUI:SetEJStatus(text)
  if self.ejStatusLabel then
    self.ejStatusLabel:SetText(text or "")
  end
end

function GLD:InitTestUI()
  TestUI.testFrame = nil
  TestUI.testVotes = {}
  TestUI.currentVoterIndex = 0
  TestUI.disableManualVotes = true
  TestUI.queueEditEnabled = false
  TestUI.testSessionActive = GLD.testDb and GLD.testDb.testSession and GLD.testDb.testSession.active or false
  TestUI.testHistoryFrame = nil
  TestUI.testGraphsFrame = nil
  TestUI.testGraphsDebug = false
end

function TestUI:RefreshGuestSimStatus()
  if not self.simGuestStatusLabel then
    return
  end
  local count = 0
  if GLD.GetSimGuestAnchors then
    local list = GLD:GetSimGuestAnchors()
    count = type(list) == "table" and #list or 0
  end
  local mode = GLD.GetSimMode and GLD:GetSimMode() or "merge"
  local modeLabel = mode == "replace" and "Replace" or "Merge"
  self.simGuestStatusLabel:SetText(string.format("Sim Guests: %d | Mode: %s", count, modeLabel))
  if self.simModeToggleButton then
    self.simModeToggleButton:SetText("Toggle Sim Mode: " .. modeLabel)
  end
end

function TestUI:AddSimulatedGuest(isAdminLike)
  if not GLD.AddSimGuestAnchor then
    return
  end
  GLD:AddSimGuestAnchor({
    isAdmin = isAdminLike == true,
    showingButton = true,
    classFile = isAdminLike and "PALADIN" or "MAGE",
  })
  if GLD.RefreshGuestAnchors then
    GLD:RefreshGuestAnchors("SimGuestAdded")
  end
  local count = 0
  if GLD.GetGuestAnchorCandidates then
    local rows = GLD:GetGuestAnchorCandidates()
    count = type(rows) == "table" and #rows or 0
  end
  local dbg = NS and NS.Debug or nil
  if dbg and dbg.Force then
    dbg:Force("GuestAnchorsUI", "Refresh reason=SimGuestAdded count=%d", count)
  end
  self:RefreshGuestSimStatus()
end

function TestUI:ClearSimulatedGuests()
  if not GLD.ClearSimGuestAnchors then
    return
  end
  GLD:ClearSimGuestAnchors()
  if GLD.RefreshGuestAnchors then
    GLD:RefreshGuestAnchors("SimGuestCleared")
  end
  local count = 0
  if GLD.GetGuestAnchorCandidates then
    local rows = GLD:GetGuestAnchorCandidates()
    count = type(rows) == "table" and #rows or 0
  end
  local dbg = NS and NS.Debug or nil
  if dbg and dbg.Force then
    dbg:Force("GuestAnchorsUI", "Refresh reason=SimGuestCleared count=%d", count)
  end
  self:RefreshGuestSimStatus()
end

function TestUI:ToggleSimGuestMode()
  if not GLD.GetSimMode or not GLD.SetSimMode then
    return
  end
  local current = GLD:GetSimMode()
  local nextMode = current == "replace" and "merge" or "replace"
  GLD:SetSimMode(nextMode)
  if GLD.RefreshGuestAnchors then
    GLD:RefreshGuestAnchors("SimGuestModeChanged")
  end
  local count = 0
  if GLD.GetGuestAnchorCandidates then
    local rows = GLD:GetGuestAnchorCandidates()
    count = type(rows) == "table" and #rows or 0
  end
  local dbg = NS and NS.Debug or nil
  if dbg and dbg.Force then
    dbg:Force("GuestAnchorsUI", "Refresh reason=SimGuestModeChanged count=%d", count)
  end
  self:RefreshGuestSimStatus()
end

function TestUI:StartTestSession()
  if self.testSessionActive then
    return
  end
  if not GLD.testDb then
    return
  end
  local id = tostring(GetServerTime()) .. "-" .. tostring(math.random(1000, 9999))
  local entry = {
    id = id,
    startedAt = GetServerTime(),
    endedAt = nil,
    raidName = self.selectedInstanceName or "Test Raid",
    loot = {},
    bosses = {},
  }
  GLD.testDb.testSessions = GLD.testDb.testSessions or {}
  table.insert(GLD.testDb.testSessions, 1, entry)
  GLD.testDb.testSession.active = true
  GLD.testDb.testSession.currentId = id
  self.testSessionActive = true
end

function TestUI:EndTestSession()
  if not self.testSessionActive then
    return
  end
  if GLD.testDb and GLD.testDb.testSession and GLD.testDb.testSession.currentId then
    for _, entry in ipairs(GLD.testDb.testSessions or {}) do
      if entry.id == GLD.testDb.testSession.currentId then
        entry.endedAt = GetServerTime()
        break
      end
    end
  end
  GLD.testDb.testSession.active = false
  GLD.testDb.testSession.currentId = nil
  self.testSessionActive = false
end

function TestUI:ResetTestVotes()
  self.testVotes = {}
  self.currentVoterIndex = 0
end

function TestUI:ResetSoloTestVotes()
  self:ResetTestVotes()
  self.currentTestRollID = nil
  self._lastTestResultKey = nil
  if GLD.activeRolls then
    for _, session in pairs(GLD.activeRolls) do
      if session and session.isTest then
        session.votes = {}
        session.locked = nil
      end
    end
  end
  if self.RefreshVotePanel then
    self:RefreshVotePanel()
  end
  if self.RefreshResultsPanel then
    self:RefreshResultsPanel()
  end
  if GLD.UI and GLD.UI.RefreshPendingVotes then
    GLD.UI:RefreshPendingVotes()
  end
end

function TestUI:ShowSoloSimVotePopup(session, testPlayers)
  if not AceGUI or not session then
    return
  end

  local voters = testPlayers or {}
  if #voters == 0 then
    GLD:Print("No test players available for solo voting.")
    return
  end

  if self.soloVoteFrame then
    self.soloVoteFrame:Release()
    self.soloVoteFrame = nil
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Solo Test Votes")
  frame:SetStatusText(session.itemName or "Item")
  frame:SetWidth(520)
  frame:SetHeight(420)
  frame:SetLayout("Flow")
  frame:EnableResize(false)

  frame:SetCallback("OnClose", function(widget)
    self.soloVoteFrame = nil
    self.soloVoteScroll = nil
    widget:Release()
  end)

  local header = AceGUI:Create("SimpleGroup")
  header:SetFullWidth(true)
  header:SetLayout("Flow")
  frame:AddChild(header)

  local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  if session.itemLink then
    local itemIcon = select(10, GetItemInfo(session.itemLink))
    if itemIcon then
      icon = itemIcon
    else
      GLD:RequestItemData(session.itemLink)
    end
  end

  local iconWidget = AceGUI:Create("Icon")
  iconWidget:SetImage(icon)
  iconWidget:SetImageSize(28, 28)
  iconWidget:SetWidth(32)
  iconWidget:SetHeight(32)
  iconWidget:SetCallback("OnEnter", function()
    local link = session.itemLink
    if link and link ~= "" then
      GameTooltip:SetOwner(iconWidget.frame, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end)
  iconWidget:SetCallback("OnLeave", function()
    GameTooltip:Hide()
  end)
  header:AddChild(iconWidget)

  local itemLabel = AceGUI:Create("InteractiveLabel")
  itemLabel:SetText(session.itemLink or session.itemName or "Unknown Item")
  itemLabel:SetWidth(440)
  itemLabel:SetCallback("OnEnter", function()
    local link = session.itemLink
    if link and link ~= "" then
      GameTooltip:SetOwner(itemLabel.frame, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end)
  itemLabel:SetCallback("OnLeave", function()
    GameTooltip:Hide()
  end)
  header:AddChild(itemLabel)

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetFullWidth(true)
  scroll:SetHeight(340)
  scroll:SetLayout("Flow")
  frame:AddChild(scroll)

  self.soloVoteFrame = frame
  self.soloVoteScroll = scroll
  self.testVotes = self.testVotes or {}

  local rowState = {}

  local function applyVote(entry, vote)
    session.votes = session.votes or {}
    local key = nil
    if entry and entry.name then
      local name, realm = NS:SplitNameRealm(entry.name)
      if TestProvider and TestProvider.GetPlayerKeyByName then
        key = TestProvider:GetPlayerKeyByName(name, realm)
      end
      if not key then
        key = GLD:GetRollCandidateKey(entry.name)
      end
    end
    if key then
      session.votes[key] = vote
    end
    if entry and entry.name then
      self.testVotes[entry.name] = vote
    end
    if key and rowState[key] then
      local controls = rowState[key]
      if controls.statusLabel then
        controls.statusLabel:SetText("voted")
      end
      for _, btn in ipairs(controls.buttons or {}) do
        if btn.SetDisabled then
          btn:SetDisabled(true)
        end
      end
    end
    if self.RefreshResultsPanel then
      self:RefreshResultsPanel()
    end
    if GLD.UI and GLD.UI.RefreshPendingVotes then
      GLD.UI:RefreshPendingVotes()
    end
    if GLD.CheckRollCompletion then
      GLD:CheckRollCompletion(session)
    end
    if session.locked then
      GLD:Print("Result locked. Your vote was recorded but the outcome is final.")
    end
  end

  for _, entry in ipairs(voters) do
    local displayName = ColorizeClassName(entry.name or "Test Player", entry.class)
    local canNeed = true
    if session.itemLink then
      canNeed = IsNeedAllowedForEntry(entry, session.itemLink)
    end
    local voteOptions = {
      { label = "Need", vote = "NEED", disabled = not canNeed },
      { label = "Greed", vote = "GREED" },
      { label = "Transmog", vote = "TRANSMOG" },
      { label = "Pass", vote = "PASS" },
    }
    for _, opt in ipairs(voteOptions) do
      opt.onClick = function(vote)
        applyVote(entry, vote)
      end
    end
    local controls = BuildVoteRow(scroll, displayName, voteOptions)
    local key = nil
    if entry and entry.name then
      local name, realm = NS:SplitNameRealm(entry.name)
      if TestProvider and TestProvider.GetPlayerKeyByName then
        key = TestProvider:GetPlayerKeyByName(name, realm)
      end
      if not key then
        key = GLD:GetRollCandidateKey(entry.name)
      end
    end
    if key and controls then
      rowState[key] = controls
      if session.votes and session.votes[key] then
        if controls.statusLabel then
          controls.statusLabel:SetText("voted")
        end
        for _, btn in ipairs(controls.buttons or {}) do
          if btn.SetDisabled then
            btn:SetDisabled(true)
          end
        end
      end
    end
  end
end

function TestUI:UpdateDynamicTestVoters()
  local voters = BuildDynamicTestVoters()
  if not voters then
    if self.dynamicVoters then
      self.dynamicVoters = nil
      self:ResetTestVotes()
    end
    return
  end

  local signature = {}
  for _, entry in ipairs(voters) do
    signature[#signature + 1] = entry.name .. ":" .. tostring(entry.class or "")
  end
  local newSignature = table.concat(signature, "|")

  if self._dynamicVotersSignature ~= newSignature then
    self.dynamicVoters = voters
    self._dynamicVotersSignature = newSignature
    self:ResetTestVotes()
  else
    self.dynamicVoters = voters
  end
end

function TestUI:SetSelectedItemLink(itemLink)
  if not itemLink then
    return
  end
  local primary = self.itemLinkInput
  local secondary = self.itemLinkInput2
  local primaryText = primary and primary:GetText() or ""
  local secondaryText = secondary and secondary:GetText() or ""
  if primary and primaryText == "" then
    primary:SetText(itemLink)
  elseif secondary and secondaryText == "" then
    secondary:SetText(itemLink)
  elseif primary then
    primary:SetText(itemLink)
  end
  self:UpdateSelectedItemInfo()
end

function TestUI:UpdateSelectedItemInfo()
  if self.itemArmorLabel then
    local itemLink = NormalizeItemInput(self.itemLinkInput and self.itemLinkInput:GetText() or nil)
    local armorType = GetArmorTypeOnly(itemLink)
    self.itemArmorLabel:SetText("Armor Type: " .. armorType)
  end
  if self.itemArmorLabel2 then
    local itemLink2 = NormalizeItemInput(self.itemLinkInput2 and self.itemLinkInput2:GetText() or nil)
    local armorType2 = GetArmorTypeOnly(itemLink2)
    self.itemArmorLabel2:SetText("Armor Type 2: " .. armorType2)
  end
end

function TestUI:ToggleTestPanel()
  if not GLD:IsAdmin() then
    GLD:ShowPermissionDeniedPopup()
    return
  end
  if not self.testFrame then
    self:CreateTestFrame()
  end
  if self.testFrame:IsShown() then
    self.testFrame:Hide()
  else
    self:ResetTestVotes()
    self.testFrame:Show()
    self:SetActiveAdminTab("admin")
    GLD:Print("Test panel opened")
    self:RefreshTestPanel()
  end
end

function TestUI:SetActiveAdminTab(tab)
  self.activeAdminTab = tab or "admin"
  if self.adminPanel then
    self.adminPanel:SetShown(self.activeAdminTab == "admin")
  end
  if self.lootFrame then
    self.lootFrame:SetShown(self.activeAdminTab == "loot")
  end
  if self.dataPanel then
    self.dataPanel:SetShown(self.activeAdminTab == "data")
  end
  if self.historyPanel then
    self.historyPanel:SetShown(self.activeAdminTab == "history")
  end
  self:UpdateLootFrameToggle()
end

function TestUI:UpdateLootFrameToggle()
  if not self.adminTabButton or not self.lootTabButton or not self.dataTabButton or not self.historyTabButton then
    return
  end
  local activeTab = self.activeAdminTab or "admin"
  if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
    PanelTemplates_DeselectTab(self.adminTabButton)
    PanelTemplates_DeselectTab(self.lootTabButton)
    PanelTemplates_DeselectTab(self.dataTabButton)
    PanelTemplates_DeselectTab(self.historyTabButton)
    if activeTab == "loot" then
      PanelTemplates_SelectTab(self.lootTabButton)
    elseif activeTab == "data" then
      PanelTemplates_SelectTab(self.dataTabButton)
    elseif activeTab == "history" then
      PanelTemplates_SelectTab(self.historyTabButton)
    else
      PanelTemplates_SelectTab(self.adminTabButton)
    end
  else
    local activeR, activeG, activeB = 1, 0.9, 0.6
    local inactiveR, inactiveG, inactiveB = 1, 1, 1
    if self.adminTabButton.Text then
      local active = activeTab == "admin"
      self.adminTabButton.Text:SetTextColor(active and activeR or inactiveR, active and activeG or inactiveG, active and activeB or inactiveB)
    end
    if self.lootTabButton.Text then
      local active = activeTab == "loot"
      self.lootTabButton.Text:SetTextColor(active and activeR or inactiveR, active and activeG or inactiveG, active and activeB or inactiveB)
    end
    if self.dataTabButton.Text then
      local active = activeTab == "data"
      self.dataTabButton.Text:SetTextColor(active and activeR or inactiveR, active and activeG or inactiveG, active and activeB or inactiveB)
    end
    if self.historyTabButton.Text then
      local active = activeTab == "history"
      self.historyTabButton.Text:SetTextColor(active and activeR or inactiveR, active and activeG or inactiveG, active and activeB or inactiveB)
    end
  end
end

function TestUI:ToggleLootFrame()
  if not self.testFrame then
    return
  end
  local nextTab = self.activeAdminTab == "loot" and "admin" or "loot"
  self:SetActiveAdminTab(nextTab)
end

function TestUI:CreateTestFrame()
  local frame = CreateFrame("Frame", "GLDAdminTestFrame", UIParent, "BackdropTemplate")
  frame:SetSize(980, 710)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
  AddSpecialFrame(frame:GetName())

  local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -8)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -8)
  header:SetHeight(28)
  ApplyHeaderCellStyle(header)

  local titleText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  titleText:SetPoint("LEFT", header, "LEFT", 8, 0)
  titleText:SetText("Admin Test Panel")
  frame.TitleText = titleText

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  frame.CloseButton = closeButton

  local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  statusText:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
  statusText:SetText("Test Session / Loot / Data / History")

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
  content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8)
  content:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 16)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)

  local tabBar = CreateFrame("Frame", nil, content)
  tabBar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  tabBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  tabBar:SetHeight(24)

  local adminTabButton = CreateFrame("Button", nil, tabBar, "PanelTabButtonTemplate")
  adminTabButton:SetText("Admin")
  if PanelTemplates_TabResize then
    PanelTemplates_TabResize(adminTabButton, 0)
  end
  adminTabButton:SetPoint("LEFT", tabBar, "LEFT", 0, 0)
  adminTabButton:SetScript("OnClick", function()
    TestUI:SetActiveAdminTab("admin")
  end)

  local lootTabButton = CreateFrame("Button", nil, tabBar, "PanelTabButtonTemplate")
  lootTabButton:SetText("Test Loot")
  if PanelTemplates_TabResize then
    PanelTemplates_TabResize(lootTabButton, 0)
  end
  lootTabButton:SetPoint("LEFT", adminTabButton, "RIGHT", 4, 0)
  lootTabButton:SetScript("OnClick", function()
    TestUI:SetActiveAdminTab("loot")
  end)

  local dataTabButton = CreateFrame("Button", nil, tabBar, "PanelTabButtonTemplate")
  dataTabButton:SetText("Test Data")
  if PanelTemplates_TabResize then
    PanelTemplates_TabResize(dataTabButton, 0)
  end
  dataTabButton:SetPoint("LEFT", lootTabButton, "RIGHT", 4, 0)
  dataTabButton:SetScript("OnClick", function()
    TestUI:SetActiveAdminTab("data")
  end)

  local historyTabButton = CreateFrame("Button", nil, tabBar, "PanelTabButtonTemplate")
  historyTabButton:SetText("History")
  if PanelTemplates_TabResize then
    PanelTemplates_TabResize(historyTabButton, 0)
  end
  historyTabButton:SetPoint("LEFT", dataTabButton, "RIGHT", 4, 0)
  historyTabButton:SetScript("OnClick", function()
    TestUI:SetActiveAdminTab("history")
  end)

  local adminPanel = CreateFrame("Frame", nil, content)
  adminPanel:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
  adminPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

  local lootPanel = CreateFrame("Frame", nil, content)
  lootPanel:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
  lootPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  lootPanel:Hide()

  local dataPanel = CreateFrame("Frame", nil, content)
  dataPanel:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
  dataPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  dataPanel:Hide()

  local historyPanel = CreateFrame("Frame", nil, content)
  historyPanel:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
  historyPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  historyPanel:Hide()

  local sessionBar = CreateFrame("Frame", nil, adminPanel, "InsetFrameTemplate3")
  sessionBar:SetPoint("TOPLEFT", adminPanel, "TOPLEFT", 0, 0)
  sessionBar:SetPoint("TOPRIGHT", adminPanel, "TOPRIGHT", 0, 0)
  sessionBar:SetHeight(90)

  local sessionTitle = sessionBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  sessionTitle:SetPoint("TOPLEFT", sessionBar, "TOPLEFT", 8, -6)
  sessionTitle:SetText("Session Controls")

  local sessionStatus = sessionBar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sessionStatus:SetPoint("TOPRIGHT", sessionBar, "TOPRIGHT", -10, -6)
  sessionStatus:SetJustifyH("RIGHT")
  sessionStatus:SetWidth(250)
  sessionStatus:SetText("Session Status: INACTIVE")

  local buttonRow = nil
  local function CreateSessionButton(label, width, onClick)
    if not buttonRow then
      return nil
    end
    local button = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
    button:SetSize(width, ADMIN_BUTTON_HEIGHT)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
  end

  local demoLootButton = CreateFrame("Button", nil, sessionBar, "UIPanelButtonTemplate")
  demoLootButton:SetSize(220, ADMIN_BUTTON_HEIGHT)
  demoLootButton:SetText("Show Example Loot/Pending Window")
  demoLootButton:SetPoint("TOPRIGHT", sessionBar, "TOPRIGHT", -10, -22)
  demoLootButton:SetScript("OnClick", function()
    if GLD and GLD.ShowExampleMemberLootPendingWindow then
      GLD:ShowExampleMemberLootPendingWindow()
    elseif GLD.UI and GLD.UI.ShowLootWindowDemo then
      GLD.UI:ShowLootWindowDemo("member")
    end
  end)

  local demoAdminLootButton = CreateFrame("Button", nil, sessionBar, "UIPanelButtonTemplate")
  demoAdminLootButton:SetSize(280, ADMIN_BUTTON_HEIGHT)
  demoAdminLootButton:SetText("Show Example ADMIN Loot/Pending Window")
  demoAdminLootButton:SetPoint("RIGHT", demoLootButton, "LEFT", -6, 0)
  demoAdminLootButton:SetScript("OnClick", function()
    if GLD and GLD.AdminTest and GLD.AdminTest.PromptPugModeChoice then
      GLD.AdminTest:PromptPugModeChoice(function(pugMode)
        if GLD and GLD.ShowExampleLootPendingWindow then
          GLD:ShowExampleLootPendingWindow("admin", pugMode)
        elseif GLD.UI and GLD.UI.ShowLootWindowDemo then
          GLD.UI:ShowLootWindowDemo("admin", { pugMode = pugMode == true })
        end
      end)
    elseif GLD and GLD.ShowExampleLootPendingWindow then
      GLD:ShowExampleLootPendingWindow("admin", false)
    elseif GLD.UI and GLD.UI.ShowLootWindowDemo then
      GLD.UI:ShowLootWindowDemo("admin", { pugMode = false })
    end
  end)
  demoAdminLootButton:SetScript("OnEnter", function(selfButton)
    GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Preview admin controls (force vote/pending, confirm obtained) - test only", 1, 0.82, 0, 1, true)
    GameTooltip:Show()
  end)
  demoAdminLootButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  if not GLD:IsAdmin() then
    demoLootButton:Hide()
    demoAdminLootButton:Hide()
  end

  buttonRow = CreateFrame("Frame", nil, sessionBar)
  buttonRow:SetPoint("TOPLEFT", sessionBar, "TOPLEFT", 8, -22)
  buttonRow:SetPoint("RIGHT", demoAdminLootButton, "LEFT", -8, 0)
  buttonRow:SetHeight(ADMIN_BUTTON_HEIGHT)

  local sessionButtons = {}
  sessionButtons[#sessionButtons + 1] = CreateSessionButton("Start Session", 110, function()
    TestUI:StartTestSession()
    TestUI:RefreshTestPanel()
  end)
  sessionButtons[#sessionButtons + 1] = CreateSessionButton("End Session", 110, function()
    TestUI:EndTestSession()
    TestUI:RefreshTestPanel()
  end)

  local queueEditBtn = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
  queueEditBtn:SetSize(120, ADMIN_BUTTON_HEIGHT)
  local function updateQueueEditLabel()
    queueEditBtn:SetText(TestUI.queueEditEnabled and "Edit Roster: On" or "Edit Roster: Off")
  end
  updateQueueEditLabel()
  queueEditBtn:SetScript("OnClick", function()
    TestUI.queueEditEnabled = not TestUI.queueEditEnabled
    if GLD.SetRosterEditEnabled then
      GLD:SetRosterEditEnabled(TestUI.queueEditEnabled)
    else
      GLD.editRosterEnabled = TestUI.queueEditEnabled
    end
    updateQueueEditLabel()
    TestUI:RefreshTestPanel()
    if GLD.UI and GLD.UI.RefreshMain then
      GLD.UI:RefreshMain()
    end
  end)
  sessionButtons[#sessionButtons + 1] = queueEditBtn

  local previous = nil
  for _, button in ipairs(sessionButtons) do
    if not previous then
      button:SetPoint("LEFT", buttonRow, "LEFT", 0, 0)
    else
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    end
    previous = button
  end

  local simSectionTitle = sessionBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  simSectionTitle:SetPoint("TOPLEFT", buttonRow, "BOTTOMLEFT", 0, -8)
  simSectionTitle:SetText("Guest Anchor Simulation")

  local simGuestStatusLabel = sessionBar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  simGuestStatusLabel:SetPoint("LEFT", simSectionTitle, "RIGHT", 10, 0)
  simGuestStatusLabel:SetPoint("RIGHT", sessionBar, "RIGHT", -10, 0)
  simGuestStatusLabel:SetJustifyH("RIGHT")
  simGuestStatusLabel:SetText("Sim Guests: 0 | Mode: Merge")

  local simButtonRow = CreateFrame("Frame", nil, sessionBar)
  simButtonRow:SetPoint("TOPLEFT", simSectionTitle, "BOTTOMLEFT", 0, -4)
  simButtonRow:SetPoint("RIGHT", sessionBar, "RIGHT", -10, 0)
  simButtonRow:SetHeight(ADMIN_BUTTON_HEIGHT)

  local simAddBtn = CreateFrame("Button", nil, simButtonRow, "UIPanelButtonTemplate")
  simAddBtn:SetSize(145, ADMIN_BUTTON_HEIGHT)
  simAddBtn:SetPoint("LEFT", simButtonRow, "LEFT", 0, 0)
  simAddBtn:SetText("Add Simulated Guest")
  simAddBtn:SetScript("OnClick", function()
    TestUI:AddSimulatedGuest(false)
  end)

  local simAddAdminBtn = CreateFrame("Button", nil, simButtonRow, "UIPanelButtonTemplate")
  simAddAdminBtn:SetSize(190, ADMIN_BUTTON_HEIGHT)
  simAddAdminBtn:SetPoint("LEFT", simAddBtn, "RIGHT", 6, 0)
  simAddAdminBtn:SetText("Add Sim Guest (Admin-like)")
  simAddAdminBtn:SetScript("OnClick", function()
    TestUI:AddSimulatedGuest(true)
  end)

  local simClearBtn = CreateFrame("Button", nil, simButtonRow, "UIPanelButtonTemplate")
  simClearBtn:SetSize(150, ADMIN_BUTTON_HEIGHT)
  simClearBtn:SetPoint("LEFT", simAddAdminBtn, "RIGHT", 6, 0)
  simClearBtn:SetText("Clear Simulated Guests")
  simClearBtn:SetScript("OnClick", function()
    TestUI:ClearSimulatedGuests()
  end)

  local simModeBtn = CreateFrame("Button", nil, simButtonRow, "UIPanelButtonTemplate")
  simModeBtn:SetSize(165, ADMIN_BUTTON_HEIGHT)
  simModeBtn:SetPoint("LEFT", simClearBtn, "RIGHT", 6, 0)
  simModeBtn:SetText("Toggle Sim Mode: Merge")
  simModeBtn:SetScript("OnClick", function()
    TestUI:ToggleSimGuestMode()
  end)

  local playerPanel = CreateFrame("Frame", nil, adminPanel, "InsetFrameTemplate3")
  playerPanel:SetPoint("TOPLEFT", sessionBar, "BOTTOMLEFT", 0, -ADMIN_SECTION_PADDING)
  playerPanel:SetPoint("TOPRIGHT", sessionBar, "BOTTOMRIGHT", 0, -ADMIN_SECTION_PADDING)
  playerPanel:SetPoint("BOTTOMLEFT", adminPanel, "BOTTOMLEFT", 0, 0)
  playerPanel:SetPoint("BOTTOMRIGHT", adminPanel, "BOTTOMRIGHT", 0, 0)

  local testDataPanel = CreateFrame("Frame", nil, dataPanel, "InsetFrameTemplate3")
  testDataPanel:SetPoint("TOPLEFT", dataPanel, "TOPLEFT", 0, 0)
  testDataPanel:SetPoint("TOPRIGHT", dataPanel, "TOPRIGHT", 0, 0)
  testDataPanel:SetHeight(180)

  local votePanel = CreateFrame("Frame", nil, dataPanel, "InsetFrameTemplate3")
  votePanel:SetHeight(110)
  votePanel:SetPoint("TOPLEFT", testDataPanel, "BOTTOMLEFT", 0, -ADMIN_SECTION_PADDING)
  votePanel:SetPoint("TOPRIGHT", testDataPanel, "BOTTOMRIGHT", 0, -ADMIN_SECTION_PADDING)

  local resultsPanel = CreateFrame("Frame", nil, dataPanel, "InsetFrameTemplate3")
  resultsPanel:SetPoint("TOPLEFT", votePanel, "BOTTOMLEFT", 0, -ADMIN_SECTION_PADDING)
  resultsPanel:SetPoint("TOPRIGHT", votePanel, "BOTTOMRIGHT", 0, -ADMIN_SECTION_PADDING)
  resultsPanel:SetPoint("BOTTOMLEFT", dataPanel, "BOTTOMLEFT", 0, 0)
  resultsPanel:SetPoint("BOTTOMRIGHT", dataPanel, "BOTTOMRIGHT", 0, 0)

  local historyInset = CreateFrame("Frame", nil, historyPanel, "InsetFrameTemplate3")
  historyInset:SetPoint("TOPLEFT", historyPanel, "TOPLEFT", 0, 0)
  historyInset:SetPoint("BOTTOMRIGHT", historyPanel, "BOTTOMRIGHT", 0, 0)

  local historyTitle = historyInset:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  historyTitle:SetPoint("TOPLEFT", historyInset, "TOPLEFT", 8, -6)
  historyTitle:SetText("Test History")

  local historyControls = CreateFrame("Frame", nil, historyInset)
  historyControls:SetPoint("TOPRIGHT", historyInset, "TOPRIGHT", -8, -6)
  historyControls:SetHeight(ADMIN_BUTTON_HEIGHT)

  local graphsBtn = CreateFrame("Button", nil, historyControls, "UIPanelButtonTemplate")
  graphsBtn:SetSize(150, ADMIN_BUTTON_HEIGHT)
  graphsBtn:SetText("Experimental Graphs")
  graphsBtn:SetPoint("RIGHT", historyControls, "RIGHT", 0, 0)
  graphsBtn:SetScript("OnClick", function()
    TestUI:ToggleTestGraphs()
  end)

  self:CreateTestHistoryPanel(historyInset)

  local playerTitle = playerPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  playerTitle:SetPoint("TOPLEFT", playerPanel, "TOPLEFT", 8, -6)
  playerTitle:SetText("Player Management")

  self.playerColumns = CopyColumnDefs(PLAYER_COLUMNS)
  UpdateColumnOffsets(self.playerColumns, 4)
  self.playerColumnMap = BuildColumnMap(self.playerColumns)

  local playerHeaderRow = CreateFrame("Frame", nil, playerPanel)
  playerHeaderRow:SetHeight(ADMIN_HEADER_HEIGHT)
  playerHeaderRow:SetPoint("TOPLEFT", playerPanel, "TOPLEFT", 6, -24)
  playerHeaderRow:SetPoint("TOPRIGHT", playerPanel, "TOPRIGHT", -ADMIN_SCROLLBAR_OFFSET, -24)

  self.playerHeaderCells = {}
  for _, col in ipairs(self.playerColumns) do
    local cell = CreateFrame("Frame", nil, playerHeaderRow, "BackdropTemplate")
    cell:SetSize(col.width, ADMIN_HEADER_HEIGHT)
    cell:SetPoint("LEFT", playerHeaderRow, "LEFT", col.x, 0)
    ApplyHeaderCellStyle(cell)
    local text = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", cell, "CENTER", 0, 0)
    text:SetText(col.label)
    self.playerHeaderCells[col.key] = cell
  end

  local playerScrollBox = CreateFrame("Frame", nil, playerPanel, "WowScrollBoxList")
  playerScrollBox:SetPoint("TOPLEFT", playerHeaderRow, "BOTTOMLEFT", 0, -2)
  playerScrollBox:SetPoint("BOTTOMRIGHT", playerPanel, "BOTTOMRIGHT", -ADMIN_SCROLLBAR_OFFSET, 6)

  local playerScrollBar = CreateFrame("EventFrame", nil, playerPanel, "MinimalScrollBar")
  playerScrollBar:SetPoint("TOPLEFT", playerHeaderRow, "TOPRIGHT", 4, 0)
  playerScrollBar:SetPoint("BOTTOMLEFT", playerScrollBox, "BOTTOMRIGHT", 4, 0)

  local playerView = CreateScrollBoxListLinearView()
  playerView:SetElementInitializer("GLDRosterRowTemplate", function(row, elementData)
    TestUI:InitializePlayerRow(row)
    TestUI:PopulatePlayerRow(row, elementData)
  end)
  if playerView.SetElementResetter then
    playerView:SetElementResetter(function(row)
      if not row then
        return
      end
      row.data = nil
      row.canRemoveHoverHighlight = false
      if row.SetRemoveHoverHighlighted then
        row:SetRemoveHoverHighlighted(false)
      end
    end)
  end
  playerView:SetElementExtent(ADMIN_ROW_HEIGHT)
  ScrollUtil.InitScrollBoxListWithScrollBar(playerScrollBox, playerScrollBar, playerView)

  local testDataTitle = testDataPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  testDataTitle:SetPoint("TOPLEFT", testDataPanel, "TOPLEFT", 8, -6)
  testDataTitle:SetText("Test DB Players")

  local testDataControls = CreateFrame("Frame", nil, testDataPanel)
  testDataControls:SetPoint("TOPRIGHT", testDataPanel, "TOPRIGHT", -8, -6)
  testDataControls:SetHeight(ADMIN_BUTTON_HEIGHT)

  local testDataAddBtn = CreateFrame("Button", nil, testDataControls, "UIPanelButtonTemplate")
  testDataAddBtn:SetSize(90, ADMIN_BUTTON_HEIGHT)
  testDataAddBtn:SetText("Add Player")
  testDataAddBtn:SetPoint("RIGHT", testDataControls, "RIGHT", 0, 0)
  testDataAddBtn:SetScript("OnClick", function()
    TestUI:ShowAddTestPlayerDialog()
  end)

  local testDataResetBtn = CreateFrame("Button", nil, testDataControls, "UIPanelButtonTemplate")
  testDataResetBtn:SetSize(110, ADMIN_BUTTON_HEIGHT)
  testDataResetBtn:SetText("Reset Test DB")
  testDataResetBtn:SetPoint("RIGHT", testDataAddBtn, "LEFT", -6, 0)
  testDataResetBtn:SetScript("OnClick", function()
    if GLD.ResetTestDB then
      GLD:ResetTestDB()
      TestUI:ShowTestDataMessage("Test DB reset.", false)
      TestUI:RefreshTestPanel()
      TestUI:RefreshTestDataPanel()
    end
  end)

  local testDataStatus = testDataPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  testDataStatus:SetPoint("TOPLEFT", testDataTitle, "BOTTOMLEFT", 0, -2)
  testDataStatus:SetPoint("RIGHT", testDataPanel, "RIGHT", -12, 0)
  testDataStatus:SetJustifyH("LEFT")
  testDataStatus:SetText("")

  self.testDataColumns = CopyColumnDefs(TEST_DATA_COLUMNS)
  UpdateColumnOffsets(self.testDataColumns, 4)
  self.testDataColumnMap = BuildColumnMap(self.testDataColumns)

  local testDataHeaderRow = CreateFrame("Frame", nil, testDataPanel)
  testDataHeaderRow:SetHeight(ADMIN_HEADER_HEIGHT)
  testDataHeaderRow:SetPoint("TOPLEFT", testDataPanel, "TOPLEFT", 6, -40)
  testDataHeaderRow:SetPoint("TOPRIGHT", testDataPanel, "TOPRIGHT", -ADMIN_SCROLLBAR_OFFSET, -40)

  for _, col in ipairs(self.testDataColumns) do
    local cell = CreateFrame("Frame", nil, testDataHeaderRow, "BackdropTemplate")
    cell:SetSize(col.width, ADMIN_HEADER_HEIGHT)
    cell:SetPoint("LEFT", testDataHeaderRow, "LEFT", col.x, 0)
    ApplyHeaderCellStyle(cell)
    local text = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", cell, "CENTER", 0, 0)
    text:SetText(col.label)
  end

  local testDataScrollBox = CreateFrame("Frame", nil, testDataPanel, "WowScrollBoxList")
  testDataScrollBox:SetPoint("TOPLEFT", testDataHeaderRow, "BOTTOMLEFT", 0, -2)
  testDataScrollBox:SetPoint("BOTTOMRIGHT", testDataPanel, "BOTTOMRIGHT", -ADMIN_SCROLLBAR_OFFSET, 6)

  local testDataScrollBar = CreateFrame("EventFrame", nil, testDataPanel, "MinimalScrollBar")
  testDataScrollBar:SetPoint("TOPLEFT", testDataHeaderRow, "TOPRIGHT", 4, 0)
  testDataScrollBar:SetPoint("BOTTOMLEFT", testDataScrollBox, "BOTTOMRIGHT", 4, 0)

  local testDataView = CreateScrollBoxListLinearView()
  testDataView:SetElementInitializer("GLDRosterRowTemplate", function(row, elementData)
    TestUI:InitializeTestDataRow(row)
    TestUI:PopulateTestDataRow(row, elementData)
  end)
  testDataView:SetElementExtent(ADMIN_ROW_HEIGHT)
  ScrollUtil.InitScrollBoxListWithScrollBar(testDataScrollBox, testDataScrollBar, testDataView)

  local voteTitle = votePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  voteTitle:SetPoint("TOPLEFT", votePanel, "TOPLEFT", 8, -6)
  voteTitle:SetText("Test Vote Selection")

  local voteResetBtn = CreateFrame("Button", nil, votePanel, "UIPanelButtonTemplate")
  voteResetBtn:SetSize(110, ADMIN_BUTTON_HEIGHT)
  voteResetBtn:SetPoint("TOPLEFT", votePanel, "TOPLEFT", 8, -24)
  voteResetBtn:SetText("Reset Votes")
  voteResetBtn:SetScript("OnClick", function()
    TestUI:ResetTestVotes()
    TestUI:RefreshVotePanel()
    TestUI:RefreshResultsPanel()
  end)

  local voteStatusLabel = votePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  voteStatusLabel:SetPoint("TOPLEFT", voteResetBtn, "BOTTOMLEFT", 0, -4)
  voteStatusLabel:SetPoint("RIGHT", votePanel, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)
  voteStatusLabel:SetJustifyH("LEFT")
  voteStatusLabel:SetText("Test vote panel active")

  local votePlayerLabel = votePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  votePlayerLabel:SetPoint("TOPLEFT", voteStatusLabel, "BOTTOMLEFT", 0, -2)
  votePlayerLabel:SetPoint("RIGHT", votePanel, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)
  votePlayerLabel:SetJustifyH("LEFT")

  local voteButtonsRow = CreateFrame("Frame", nil, votePanel)
  voteButtonsRow:SetPoint("BOTTOMLEFT", votePanel, "BOTTOMLEFT", 8, 6)
  voteButtonsRow:SetHeight(ADMIN_BUTTON_HEIGHT)

  local voteButtons = {}
  local function CreateVoteButton(label)
    local button = CreateFrame("Button", nil, voteButtonsRow, "UIPanelButtonTemplate")
    button:SetSize(70, ADMIN_BUTTON_HEIGHT)
    button:SetText(label)
    return button
  end
  voteButtons.need = CreateVoteButton("Need")
  voteButtons.greed = CreateVoteButton("Greed")
  voteButtons.mog = CreateVoteButton("Mog")
  voteButtons.pass = CreateVoteButton("Pass")

  local prevVote = nil
  for _, button in ipairs({ voteButtons.need, voteButtons.greed, voteButtons.mog, voteButtons.pass }) do
    if not prevVote then
      button:SetPoint("LEFT", voteButtonsRow, "LEFT", 0, 0)
    else
      button:SetPoint("LEFT", prevVote, "RIGHT", 6, 0)
    end
    prevVote = button
  end

  local resultsTitle = resultsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  resultsTitle:SetPoint("TOPLEFT", resultsPanel, "TOPLEFT", 8, -6)
  resultsTitle:SetText("Loot Distribution (Test)")

  local resultsControls = CreateFrame("Frame", nil, resultsPanel)
  resultsControls:ClearAllPoints()
  resultsControls:SetPoint("LEFT", resultsTitle, "RIGHT", 12, 0)
  resultsControls:SetPoint("TOP", resultsTitle, "TOP", 0, 0)
  resultsControls:SetPoint("RIGHT", resultsPanel, "RIGHT", -12, 0)
  resultsControls:SetHeight(ADMIN_BUTTON_HEIGHT)

  local resultsAbsentBtn = CreateFrame("Button", nil, resultsControls, "UIPanelButtonTemplate")
  resultsAbsentBtn:SetSize(140, ADMIN_BUTTON_HEIGHT)
  resultsAbsentBtn:SetText("Set Raid Absent")
  resultsAbsentBtn:SetScript("OnClick", function()
    local activeVoters = GetActiveVoters()
    for _, entry in ipairs(activeVoters or {}) do
      local name, realm = NS:SplitNameRealm(entry.name)
      local player = GetOrCreateTestPlayer(name, realm, entry.class)
      if player then
        SetTestAttendance(player, "ABSENT")
      end
    end
    TestUI:RefreshTestPanel()
  end)

  local resultsRandomBtn = CreateFrame("Button", nil, resultsControls, "UIPanelButtonTemplate")
  resultsRandomBtn:SetSize(200, ADMIN_BUTTON_HEIGHT)
  resultsRandomBtn:SetText("Randomize Queue Positions")
  resultsRandomBtn:SetPoint("LEFT", resultsAbsentBtn, "RIGHT", 6, 0)
  resultsRandomBtn:SetScript("OnClick", function()
    local activeVoters = GetActiveVoters()
    local players = {}
    for _, entry in ipairs(activeVoters or {}) do
      local name, realm = NS:SplitNameRealm(entry.name)
      local player = GetOrCreateTestPlayer(name, realm, entry.class)
      if player then
        players[#players + 1] = player
      end
    end
    local count = #players
    if count == 0 then
      return
    end
    local positions = {}
    for i = 1, count do
      positions[i] = i
    end
    for i = count, 2, -1 do
      local j = math.random(i)
      positions[i], positions[j] = positions[j], positions[i]
    end
    for i, player in ipairs(players) do
      if player.attendance == "ABSENT" then
        player.savedPos = positions[i]
        player.queuePos = nil
      else
        player.queuePos = positions[i]
        if not player.savedPos then
          player.savedPos = 0
        end
      end
    end
    TestUI:RefreshTestPanel()
  end)

  local resultsResetSoloBtn = CreateFrame("Button", nil, resultsControls, "UIPanelButtonTemplate")
  resultsResetSoloBtn:SetSize(170, ADMIN_BUTTON_HEIGHT)
  resultsResetSoloBtn:SetText("Reset Solo Test Votes")
  resultsResetSoloBtn:SetPoint("LEFT", resultsRandomBtn, "RIGHT", 6, 0)
  resultsResetSoloBtn:SetScript("OnClick", function()
    TestUI:ResetSoloTestVotes()
  end)

  local resultsSummaryLabel = resultsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  resultsSummaryLabel:SetPoint("TOPLEFT", resultsControls, "BOTTOMLEFT", 0, -4)
  resultsSummaryLabel:SetPoint("RIGHT", resultsPanel, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)
  resultsSummaryLabel:SetJustifyH("LEFT")

  local resultsWinnerLabel = resultsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  resultsWinnerLabel:SetPoint("TOPLEFT", resultsSummaryLabel, "BOTTOMLEFT", 0, -2)
  resultsWinnerLabel:SetPoint("RIGHT", resultsPanel, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)
  resultsWinnerLabel:SetJustifyH("LEFT")
  resultsWinnerLabel:SetText("Winner: (pending votes)")

  self.resultsColumns = CopyColumnDefs(RESULT_COLUMNS)
  UpdateColumnOffsets(self.resultsColumns, 4)
  self.resultsColumnMap = BuildColumnMap(self.resultsColumns)

  local resultsTableContainer = CreateFrame("Frame", nil, resultsPanel)
  local titleHeight = resultsTitle.GetStringHeight and resultsTitle:GetStringHeight() or resultsTitle:GetHeight() or 0
  local titleOffsetY = -6 - titleHeight - 8
  resultsTableContainer:ClearAllPoints()
  resultsTableContainer:SetPoint("TOPLEFT", resultsTitle, "BOTTOMLEFT", 0, -8)
  resultsTableContainer:SetPoint("TOPRIGHT", resultsPanel, "TOPRIGHT", -12, titleOffsetY)
  resultsTableContainer:SetPoint("BOTTOMLEFT", resultsPanel, "BOTTOMLEFT", 12, 12)
  resultsTableContainer:SetPoint("BOTTOMRIGHT", resultsPanel, "BOTTOMRIGHT", -12, 12)

  resultsSummaryLabel:SetParent(resultsTableContainer)
  resultsSummaryLabel:ClearAllPoints()
  resultsSummaryLabel:SetPoint("TOPLEFT", resultsTableContainer, "TOPLEFT", 6, -6)
  resultsSummaryLabel:SetPoint("RIGHT", resultsTableContainer, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)

  resultsWinnerLabel:SetParent(resultsTableContainer)
  resultsWinnerLabel:ClearAllPoints()
  resultsWinnerLabel:SetPoint("TOPLEFT", resultsSummaryLabel, "BOTTOMLEFT", 0, -2)
  resultsWinnerLabel:SetPoint("RIGHT", resultsTableContainer, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)

  local resultsHeaderRow = CreateFrame("Frame", nil, resultsTableContainer)
  resultsHeaderRow:SetHeight(ADMIN_HEADER_HEIGHT)
  resultsHeaderRow:ClearAllPoints()
  resultsHeaderRow:SetPoint("LEFT", resultsTableContainer, "LEFT", 6, 0)
  resultsHeaderRow:SetPoint("RIGHT", resultsTableContainer, "RIGHT", -ADMIN_SCROLLBAR_OFFSET, 0)
  resultsHeaderRow:SetPoint("TOP", resultsWinnerLabel, "BOTTOM", 0, -6)

  for _, col in ipairs(self.resultsColumns) do
    local cell = CreateFrame("Frame", nil, resultsHeaderRow, "BackdropTemplate")
    cell:SetSize(col.width, ADMIN_HEADER_HEIGHT)
    cell:SetPoint("LEFT", resultsHeaderRow, "LEFT", col.x, 0)
    ApplyHeaderCellStyle(cell)
    local text = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", cell, "CENTER", 0, 0)
    text:SetText(col.label)
  end

  local resultsScrollBox = CreateFrame("Frame", nil, resultsTableContainer, "WowScrollBoxList")
  resultsScrollBox:ClearAllPoints()
  resultsScrollBox:SetPoint("TOPLEFT", resultsHeaderRow, "BOTTOMLEFT", 0, -2)
  resultsScrollBox:SetPoint("BOTTOMRIGHT", resultsTableContainer, "BOTTOMRIGHT", -ADMIN_SCROLLBAR_OFFSET, 6)

  local resultsScrollBar = CreateFrame("EventFrame", nil, resultsTableContainer, "MinimalScrollBar")
  resultsScrollBar:ClearAllPoints()
  resultsScrollBar:SetPoint("TOPLEFT", resultsHeaderRow, "TOPRIGHT", 4, 0)
  resultsScrollBar:SetPoint("BOTTOMLEFT", resultsScrollBox, "BOTTOMRIGHT", 4, 0)

  local resultsView = CreateScrollBoxListLinearView()
  resultsView:SetElementInitializer("GLDRosterRowTemplate", function(row, elementData)
    TestUI:InitializeResultsRow(row)
    TestUI:PopulateResultsRow(row, elementData)
  end)
  resultsView:SetElementExtent(ADMIN_ROW_HEIGHT)
  ScrollUtil.InitScrollBoxListWithScrollBar(resultsScrollBox, resultsScrollBar, resultsView)

  local lootControls = CreateFrame("Frame", nil, lootPanel, "InsetFrameTemplate3")
  lootControls:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 0, 0)
  lootControls:SetPoint("TOPRIGHT", lootPanel, "TOPRIGHT", 0, 0)
  lootControls:SetHeight(340)

  local lootControlsTitle = lootControls:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  lootControlsTitle:SetPoint("TOPLEFT", lootControls, "TOPLEFT", 8, -6)
  lootControlsTitle:SetText("Test Loot Choices")

  local instanceSelect = AceGUI:Create("Dropdown")
  instanceSelect:SetLabel("Raid")
  instanceSelect:SetWidth(260)
  instanceSelect.frame:SetParent(lootControls)
  instanceSelect.frame:SetPoint("TOPLEFT", lootControls, "TOPLEFT", 8, -24)
  instanceSelect.frame:Show()

  local encounterSelect = AceGUI:Create("Dropdown")
  encounterSelect:SetLabel("Encounter")
  encounterSelect:SetWidth(260)
  encounterSelect.frame:SetParent(lootControls)
  encounterSelect.frame:SetPoint("TOPLEFT", instanceSelect.frame, "BOTTOMLEFT", 0, -6)
  encounterSelect.frame:Show()

  local ejStatusLabel = AceGUI:Create("Label")
  ejStatusLabel:SetFullWidth(true)
  ejStatusLabel:SetText("Encounter Journal: idle")
  ejStatusLabel.frame:SetParent(lootControls)
  ejStatusLabel.frame:SetPoint("TOPLEFT", encounterSelect.frame, "BOTTOMLEFT", 0, -6)
  ejStatusLabel.frame:Show()

  local ejReloadBtn = AceGUI:Create("Button")
  ejReloadBtn:SetText("Reload Encounter Journal")
  ejReloadBtn:SetWidth(200)
  ejReloadBtn.frame:SetParent(lootControls)
  ejReloadBtn.frame:SetPoint("TOPLEFT", ejStatusLabel.frame, "BOTTOMLEFT", 0, -6)
  ejReloadBtn.frame:Show()
  ejReloadBtn:SetCallback("OnClick", function()
    TestUI:SetEJStatus("Encounter Journal: reloading...")
    TestUI:RefreshInstanceList()
  end)

  local loadLootBtn = AceGUI:Create("Button")
  loadLootBtn:SetText("Load Loot")
  loadLootBtn:SetWidth(120)
  loadLootBtn.frame:SetParent(lootControls)
  loadLootBtn.frame:SetPoint("LEFT", ejReloadBtn.frame, "RIGHT", 6, 0)
  loadLootBtn.frame:Show()

  local itemLinkInput = AceGUI:Create("EditBox")
  itemLinkInput:SetLabel("Item Link")
  itemLinkInput:SetWidth(260)
  itemLinkInput:SetText("item:19345")
  itemLinkInput.frame:SetParent(lootControls)
  itemLinkInput.frame:SetPoint("TOPLEFT", ejReloadBtn.frame, "BOTTOMLEFT", 0, -10)
  itemLinkInput.frame:Show()

  local itemArmorLabel = AceGUI:Create("Label")
  itemArmorLabel:SetFullWidth(true)
  itemArmorLabel:SetText("Armor Type: -")
  itemArmorLabel.frame:SetParent(lootControls)
  itemArmorLabel.frame:SetPoint("TOPLEFT", itemLinkInput.frame, "BOTTOMLEFT", 0, -4)
  itemArmorLabel.frame:Show()

  local itemLinkInput2 = AceGUI:Create("EditBox")
  itemLinkInput2:SetLabel("Item Link 2")
  itemLinkInput2:SetWidth(260)
  itemLinkInput2.frame:SetParent(lootControls)
  itemLinkInput2.frame:SetPoint("TOPLEFT", itemArmorLabel.frame, "BOTTOMLEFT", 0, -6)
  itemLinkInput2.frame:Show()

  local itemArmorLabel2 = AceGUI:Create("Label")
  itemArmorLabel2:SetFullWidth(true)
  itemArmorLabel2:SetText("Armor Type 2: -")
  itemArmorLabel2.frame:SetParent(lootControls)
  itemArmorLabel2.frame:SetPoint("TOPLEFT", itemLinkInput2.frame, "BOTTOMLEFT", 0, -4)
  itemArmorLabel2.frame:Show()

  local dropBtn = AceGUI:Create("Button")
  dropBtn:SetText("Simulate Item 1")
  dropBtn:SetWidth(140)
  dropBtn.frame:SetParent(lootControls)
  dropBtn.frame:ClearAllPoints()
  dropBtn.frame:SetPoint("TOPLEFT", itemLinkInput.frame, "TOPRIGHT", 24, 0)
  dropBtn.frame:Show()
  dropBtn:SetCallback("OnClick", function()
    TestUI:SimulateLootRoll(itemLinkInput:GetText())
  end)

  local dropBtn2 = AceGUI:Create("Button")
  dropBtn2:SetText("Simulate Item 2")
  dropBtn2:SetWidth(140)
  dropBtn2.frame:SetParent(lootControls)
  dropBtn2.frame:ClearAllPoints()
  dropBtn2.frame:SetPoint("TOPLEFT", dropBtn.frame, "BOTTOMLEFT", 0, -8)
  dropBtn2.frame:Show()
  dropBtn2:SetCallback("OnClick", function()
    TestUI:SimulateLootRoll(itemLinkInput2:GetText())
  end)

  local dropBothBtn = AceGUI:Create("Button")
  dropBothBtn:SetText("Simulate Both")
  dropBothBtn:SetWidth(140)
  dropBothBtn.frame:SetParent(lootControls)
  dropBothBtn.frame:ClearAllPoints()
  dropBothBtn.frame:SetPoint("TOPLEFT", dropBtn2.frame, "BOTTOMLEFT", 0, -8)
  dropBothBtn.frame:Show()
  dropBothBtn:SetCallback("OnClick", function()
    TestUI:SimulateLootRoll(itemLinkInput:GetText())
    TestUI:SimulateLootRoll(itemLinkInput2:GetText())
  end)

  local pendingBtn = AceGUI:Create("Button")
  pendingBtn:SetText("Show Example Loot/Pending Window")
  pendingBtn:SetWidth(220)
  pendingBtn.frame:SetParent(lootControls)
  pendingBtn.frame:ClearAllPoints()
  pendingBtn.frame:SetPoint("TOPLEFT", dropBothBtn.frame, "BOTTOMLEFT", 0, -10)
  pendingBtn:SetCallback("OnClick", function()
    if GLD and GLD.ShowExampleMemberLootPendingWindow then
      GLD:ShowExampleMemberLootPendingWindow()
    elseif GLD.UI and GLD.UI.ShowLootWindowDemo then
      GLD.UI:ShowLootWindowDemo("member")
    end
  end)
  pendingBtn.frame:SetShown(GLD:IsAdmin())

  local pendingAdminBtn = AceGUI:Create("Button")
  pendingAdminBtn:SetText("Show Example ADMIN Loot/Pending Window")
  pendingAdminBtn:SetWidth(300)
  pendingAdminBtn.frame:SetParent(lootControls)
  pendingAdminBtn.frame:ClearAllPoints()
  pendingAdminBtn.frame:SetPoint("TOPLEFT", pendingBtn.frame, "BOTTOMLEFT", 0, -6)
  pendingAdminBtn:SetCallback("OnClick", function()
    if GLD and GLD.AdminTest and GLD.AdminTest.PromptPugModeChoice then
      GLD.AdminTest:PromptPugModeChoice(function(pugMode)
        if GLD and GLD.ShowExampleLootPendingWindow then
          GLD:ShowExampleLootPendingWindow("admin", pugMode)
        elseif GLD.UI and GLD.UI.ShowLootWindowDemo then
          GLD.UI:ShowLootWindowDemo("admin", { pugMode = pugMode == true })
        end
      end)
    elseif GLD and GLD.ShowExampleLootPendingWindow then
      GLD:ShowExampleLootPendingWindow("admin", false)
    elseif GLD.UI and GLD.UI.ShowLootWindowDemo then
      GLD.UI:ShowLootWindowDemo("admin", { pugMode = false })
    end
  end)
  pendingAdminBtn.frame:SetShown(GLD:IsAdmin())
  pendingAdminBtn.frame:SetScript("OnEnter", function(selfButton)
    GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
    GameTooltip:SetText("Preview admin controls (force vote/pending, confirm obtained) - test only", 1, 0.82, 0, 1, true)
    GameTooltip:Show()
  end)
  pendingAdminBtn.frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local lootListPanel = CreateFrame("Frame", nil, lootPanel, "InsetFrameTemplate3")
  lootListPanel:SetPoint("TOPLEFT", lootControls, "BOTTOMLEFT", 0, -ADMIN_SECTION_PADDING)
  lootListPanel:SetPoint("TOPRIGHT", lootControls, "BOTTOMRIGHT", 0, -ADMIN_SECTION_PADDING)
  lootListPanel:SetPoint("BOTTOMLEFT", lootPanel, "BOTTOMLEFT", 0, 0)
  lootListPanel:SetPoint("BOTTOMRIGHT", lootPanel, "BOTTOMRIGHT", 0, 0)

  local lootListTitle = lootListPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  lootListTitle:SetPoint("TOPLEFT", lootListPanel, "TOPLEFT", 8, -6)
  lootListTitle:SetText("Encounter Loot")

  local encounterLootContainer = CreateFrame("Frame", nil, lootListPanel)
  local lootTitleHeight = lootListTitle.GetStringHeight and lootListTitle:GetStringHeight() or lootListTitle:GetHeight() or 0
  local lootTitleOffsetY = -6 - lootTitleHeight - 8
  encounterLootContainer:ClearAllPoints()
  encounterLootContainer:SetPoint("TOPLEFT", lootListTitle, "BOTTOMLEFT", 0, -8)
  encounterLootContainer:SetPoint("TOPRIGHT", lootListPanel, "TOPRIGHT", -12, lootTitleOffsetY)
  encounterLootContainer:SetPoint("BOTTOMLEFT", lootListPanel, "BOTTOMLEFT", 12, 12)
  encounterLootContainer:SetPoint("BOTTOMRIGHT", lootListPanel, "BOTTOMRIGHT", -12, 12)

  local lootScroll = AceGUI:Create("ScrollFrame")
  lootScroll:SetLayout("Flow")
  lootScroll.frame:SetParent(encounterLootContainer)
  lootScroll.frame:ClearAllPoints()
  lootScroll.frame:SetPoint("TOPLEFT", encounterLootContainer, "TOPLEFT", 6, -6)
  lootScroll.frame:SetPoint("BOTTOMRIGHT", encounterLootContainer, "BOTTOMRIGHT", -28, 6)
  lootScroll.frame:Show()

  self.testFrame = frame
  self.adminPanel = adminPanel
  self.lootFrame = lootPanel
  self.dataPanel = dataPanel
  self.historyPanel = historyPanel
  self.adminTabButton = adminTabButton
  self.lootTabButton = lootTabButton
  self.dataTabButton = dataTabButton
  self.historyTabButton = historyTabButton
  self.sessionStatus = sessionStatus
  self.simGuestStatusLabel = simGuestStatusLabel
  self.simModeToggleButton = simModeBtn
  self.playerHeaderRow = playerHeaderRow
  self.playerScrollBox = playerScrollBox
  self.playerScrollBar = playerScrollBar
  self.testDataHeaderRow = testDataHeaderRow
  self.testDataScrollBox = testDataScrollBox
  self.testDataScrollBar = testDataScrollBar
  self.testDataStatusLabel = testDataStatus
  self.voteTitleLabel = voteTitle
  self.voteResetBtn = voteResetBtn
  self.voteStatusLabel = voteStatusLabel
  self.votePlayerLabel = votePlayerLabel
  self.voteButtonsRow = voteButtonsRow
  self.voteButtons = voteButtons
  self.resultsHeaderRow = resultsHeaderRow
  self.resultsScrollBox = resultsScrollBox
  self.resultsScrollBar = resultsScrollBar
  self.resultsSummaryLabel = resultsSummaryLabel
  self.resultsWinnerLabel = resultsWinnerLabel
  self.resultsAbsentBtn = resultsAbsentBtn
  self.resultsRandomBtn = resultsRandomBtn
  self.resultsResetSoloBtn = resultsResetSoloBtn
  self.lootScroll = lootScroll
  self.instanceSelect = instanceSelect
  self.ejStatusLabel = ejStatusLabel
  self.encounterSelect = encounterSelect
  self.itemLinkInput = itemLinkInput
  self.itemArmorLabel = itemArmorLabel
  self.itemLinkInput2 = itemLinkInput2
  self.itemArmorLabel2 = itemArmorLabel2

  instanceSelect:SetCallback("OnValueChanged", function(_, _, value)
    TestUI:SelectInstance(value)
  end)
  encounterSelect:SetCallback("OnValueChanged", function(_, _, value)
    TestUI:SelectEncounter(value)
  end)
  loadLootBtn:SetCallback("OnClick", function()
    TestUI:LoadEncounterLoot()
  end)
  itemLinkInput:SetCallback("OnEnterPressed", function()
    TestUI:UpdateSelectedItemInfo()
  end)
  itemLinkInput:SetCallback("OnTextChanged", function()
    TestUI:UpdateSelectedItemInfo()
  end)
  itemLinkInput2:SetCallback("OnEnterPressed", function()
    TestUI:UpdateSelectedItemInfo()
  end)
  itemLinkInput2:SetCallback("OnTextChanged", function()
    TestUI:UpdateSelectedItemInfo()
  end)
  self:UpdateSelectedItemInfo()

  self:SetActiveAdminTab("admin")
  self:RefreshGuestSimStatus()
  frame:Hide()
end

function TestUI:InitializePlayerRow(row)
  if row.isInitialized then
    return
  end
  row:SetHeight(ADMIN_ROW_HEIGHT)
  if self.playerHeaderRow and self.playerHeaderRow.GetWidth then
    row:SetWidth(self.playerHeaderRow:GetWidth())
  end

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetColorTexture(1, 1, 1, 0.08)
  highlight:SetAllPoints(row)
  row.baseHighlight = highlight

  local removeHoverHighlight = row:CreateTexture(nil, "BACKGROUND")
  removeHoverHighlight:SetAllPoints(row)
  removeHoverHighlight:SetColorTexture(0.95, 0.25, 0.25, 0.16)
  removeHoverHighlight:Hide()
  row.removeHoverHighlight = removeHoverHighlight
  row.canRemoveHoverHighlight = false
  function row:SetRemoveHoverHighlighted(highlighted)
    if not self.removeHoverHighlight then
      return
    end
    local show = highlighted == true and self.canRemoveHoverHighlight == true
    self.removeHoverHighlight:SetShown(show)
  end

  row.cells = {}
  for _, col in ipairs(self.playerColumns or {}) do
    if col.key == "mark" then
      local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      button:SetSize(col.width, ADMIN_BUTTON_HEIGHT)
      button:SetPoint("LEFT", row, "LEFT", col.x, 0)
      row.cells.mark = button
    elseif col.key == "queue" then
      local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      label:SetWidth(col.width)
      label:SetJustifyH("CENTER")
      label:SetPoint("LEFT", row, "LEFT", col.x, 0)
      row.cells.queue = label

      local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
      box:SetSize(col.width - 6, ADMIN_BUTTON_HEIGHT)
      box:SetPoint("LEFT", row, "LEFT", col.x + 3, 0)
      box:SetAutoFocus(false)
      box:SetJustifyH("CENTER")
      if box.SetNumeric then
        box:SetNumeric(true)
      end
      box:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
      end)
      row.queueBox = box
    elseif col.key == "won" or col.key == "raids" then
      local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
      box:SetSize(col.width - 6, ADMIN_BUTTON_HEIGHT)
      box:SetPoint("LEFT", row, "LEFT", col.x + 3, 0)
      box:SetAutoFocus(false)
      box:SetJustifyH("CENTER")
      if box.SetNumeric then
        box:SetNumeric(true)
      end
      box:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
      end)
      if col.key == "won" then
        row.wonBox = box
      else
        row.raidsBox = box
      end
    elseif col.key == "remove" then
      local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      button:SetSize(col.width, ADMIN_BUTTON_HEIGHT)
      button:SetPoint("LEFT", row, "LEFT", col.x, 0)
      button:SetText("Remove")
      row.cells.remove = button
    else
      local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      fs:SetWidth(col.width)
      fs:SetJustifyH(col.align or "LEFT")
      fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
      row.cells[col.key] = fs
    end
  end

  if row.cells.mark then
    row.cells.mark:SetScript("OnClick", function()
      local data = row.data
      if not data or data.isGuest then
        return
      end
      local playerKey = data.playerKey
      if GLD.db and GLD.db.players and GLD.db.players[playerKey] then
        local player = GLD.db.players[playerKey]
        local newState = player.attendance == "PRESENT" and "ABSENT" or "PRESENT"
        if GLD.SetAttendance then
          GLD:SetAttendance(playerKey, newState)
        else
          player.attendance = newState
        end
        TestUI:RefreshTestPanel()
        if GLD.UI and GLD.UI.RefreshMain then
          GLD.UI:RefreshMain()
        end
      end
    end)
  end

  if row.queueBox then
    row.queueBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or data.isGuest then
        box:ClearFocus()
        return
      end
      local pos = ParseNonNegativeInt(box:GetText())
      if pos ~= nil and GLD.db and GLD.db.players and GLD.db.players[data.playerKey] then
        local player = GLD.db.players[data.playerKey]
        if player.attendance == "ABSENT" then
          player.savedPos = pos
          player.queuePos = nil
        else
          if GLD.RemoveFromQueue then
            GLD:RemoveFromQueue(data.playerKey)
          end
          if GLD.InsertToQueue then
            GLD:InsertToQueue(data.playerKey, pos)
          else
            player.queuePos = pos
          end
        end
        TestUI:RefreshTestPanel()
        if GLD.UI and GLD.UI.RefreshMain then
          GLD.UI:RefreshMain()
        end
      end
      box:ClearFocus()
    end)
  end

  if row.cells.remove then
    row.cells.remove:SetScript("OnClick", function()
      local data = row.data
      if not data or not data.playerKey or not (GLD and GLD.db and GLD.db.players and GLD.db.players[data.playerKey]) then
        return
      end
      if not GLD:IsAdmin() or not TestUI.queueEditEnabled then
        return
      end
      if GLD.RemovePlayerFromDatabase then
        GLD:RemovePlayerFromDatabase(data.playerKey)
      else
        GLD.db.players[data.playerKey] = nil
      end
      TestUI:RefreshTestPanel()
      if GLD.UI and GLD.UI.RefreshMain then
        GLD.UI:RefreshMain()
      end
    end)
    row.cells.remove:HookScript("OnEnter", function()
      if row.canRemoveHoverHighlight then
        row:SetRemoveHoverHighlighted(true)
      end
    end)
    row.cells.remove:HookScript("OnLeave", function()
      row:SetRemoveHoverHighlighted(false)
    end)
  end

  if row.wonBox then
    row.wonBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or data.isGuest then
        box:ClearFocus()
        return
      end
      local num = ParseNonNegativeInt(box:GetText())
      if num ~= nil and GLD.db and GLD.db.players and GLD.db.players[data.playerKey] then
        GLD.db.players[data.playerKey].numAccepted = num
        if TestUI.testGraphsFrame and TestUI.testGraphsFrame:IsShown() then
          TestUI:RefreshTestGraphs()
        end
        TestUI:RefreshTestPanel()
        if GLD.UI and GLD.UI.RefreshMain then
          GLD.UI:RefreshMain()
        end
      end
      box:ClearFocus()
    end)
  end

  if row.raidsBox then
    row.raidsBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or data.isGuest then
        box:ClearFocus()
        return
      end
      local num = ParseNonNegativeInt(box:GetText())
      if num ~= nil and GLD.db and GLD.db.players and GLD.db.players[data.playerKey] then
        GLD.db.players[data.playerKey].attendanceCount = num
        if TestUI.testGraphsFrame and TestUI.testGraphsFrame:IsShown() then
          TestUI:RefreshTestGraphs()
        end
        TestUI:RefreshTestPanel()
        if GLD.UI and GLD.UI.RefreshMain then
          GLD.UI:RefreshMain()
        end
      end
      box:ClearFocus()
    end)
  end

  row.isInitialized = true
end

function TestUI:PopulatePlayerRow(row, data)
  if not row or not data or not row.cells then
    return
  end
  if row.SetRemoveHoverHighlighted then
    row:SetRemoveHoverHighlighted(false)
  end
  row.canRemoveHoverHighlight = false
  row.data = data
  local cells = row.cells

  if cells.class then
    cells.class:SetText(data.class or "-")
  end
  if cells.spec then
    cells.spec:SetText(data.spec or "-")
  end
  if cells.role then
    cells.role:SetText(data.role or "-")
  end
  if cells.name then
    cells.name:SetText(data.name or "-")
    local r, g, b = GetClassColor(data.class)
    cells.name:SetTextColor(r, g, b)
  end
  if cells.attendance then
    cells.attendance:SetText(data.attendance or "-")
    local r, g, b = GetAttendanceColor(data.attendance)
    cells.attendance:SetTextColor(r, g, b)
  end
  if cells.queue then
    cells.queue:SetText(tostring(data.queuePos or "-"))
  end
  if cells.frozen then
    cells.frozen:SetText(tostring(data.savedPos or 0))
  end

  if cells.mark then
    if data.isGuest then
      cells.mark:SetText("Guest")
      if cells.mark.SetEnabled then
        cells.mark:SetEnabled(false)
      end
    else
      cells.mark:SetText(data.attendance == "PRESENT" and "Mark Absent" or "Mark Present")
      if cells.mark.SetEnabled then
        cells.mark:SetEnabled(true)
      end
    end
  end

  if row.queueBox then
    if self.queueEditEnabled and not data.isGuest then
      row.queueBox:Show()
      row.queueBox:SetText(tostring(data.queuePos or ""))
      if cells.queue then
        cells.queue:Hide()
      end
    else
      row.queueBox:Hide()
      if cells.queue then
        cells.queue:Show()
      end
    end
  end

  if row.wonBox then
    row.wonBox:SetText(tostring(data.won or 0))
    SetEditBoxEnabled(row.wonBox, not data.isGuest)
  end
  if row.raidsBox then
    row.raidsBox:SetText(tostring(data.raids or 0))
    SetEditBoxEnabled(row.raidsBox, not data.isGuest)
  end

  if cells.remove then
    if GLD:IsAdmin() and self.queueEditEnabled then
      cells.remove:SetShown(true)
      local canRemove = data.playerKey ~= nil
      cells.remove:SetEnabled(canRemove)
      row.canRemoveHoverHighlight = canRemove == true
    else
      cells.remove:SetShown(false)
      row.canRemoveHoverHighlight = false
    end
  end
end

function TestUI:ShowTestDataMessage(text, isWarning)
  if not self.testDataStatusLabel then
    return
  end
  self.testDataStatusLabel:SetText(text or "")
  if isWarning then
    self.testDataStatusLabel:SetTextColor(1, 0.82, 0.2)
  else
    self.testDataStatusLabel:SetTextColor(0.9, 0.9, 0.9)
  end
end

function TestUI:ShowAddTestPlayerDialog()
  if not AceGUI then
    return
  end
  if self.testDataAddFrame then
    self.testDataAddFrame:Release()
    self.testDataAddFrame = nil
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Add Test Player")
  frame:SetStatusText("Create a test-only player")
  frame:SetWidth(360)
  frame:SetHeight(240)
  frame:SetLayout("Flow")
  frame:EnableResize(false)
  frame:SetCallback("OnClose", function(widget)
    self.testDataAddFrame = nil
    widget:Release()
  end)

  local nameBox = AceGUI:Create("EditBox")
  nameBox:SetLabel("Name")
  nameBox:SetWidth(300)
  frame:AddChild(nameBox)

  local classDrop = AceGUI:Create("Dropdown")
  classDrop:SetLabel("Class")
  classDrop:SetWidth(300)
  classDrop:SetList(BuildClassOptions())
  frame:AddChild(classDrop)

  local specDrop = AceGUI:Create("Dropdown")
  specDrop:SetLabel("Spec")
  specDrop:SetWidth(300)
  frame:AddChild(specDrop)

  classDrop:SetCallback("OnValueChanged", function(_, _, value)
    specDrop:SetList(BuildSpecOptionsForClass(value))
    specDrop:SetValue(nil)
  end)

  local createBtn = AceGUI:Create("Button")
  createBtn:SetText("Create")
  createBtn:SetWidth(120)
  createBtn:SetCallback("OnClick", function()
    local name = nameBox:GetText()
    local classToken = classDrop:GetValue()
    local specName = specDrop:GetValue()
    local ok, err, warn = GLD:AddTestPlayer({
      name = name,
      class = classToken,
      spec = specName,
    })
    if not ok then
      TestUI:ShowTestDataMessage(err or "Unable to add player.", true)
      return
    end
    if warn then
      TestUI:ShowTestDataMessage(warn, true)
    else
      TestUI:ShowTestDataMessage("Player added.", false)
    end
    TestUI:RefreshTestPanel()
    TestUI:RefreshTestDataPanel()
    frame:Release()
    TestUI.testDataAddFrame = nil
  end)
  frame:AddChild(createBtn)

  self.testDataAddFrame = frame
end

function TestUI:ShowEditTestPlayerDialog(playerKey)
  if not AceGUI or not GLD.testDb or not GLD.testDb.players then
    return
  end
  local player = GLD.testDb.players[playerKey]
  if not player then
    return
  end
  if self.testDataEditFrame then
    self.testDataEditFrame:Release()
    self.testDataEditFrame = nil
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Edit Test Player")
  frame:SetStatusText(player.name or "")
  frame:SetWidth(360)
  frame:SetHeight(360)
  frame:SetLayout("Flow")
  frame:EnableResize(false)
  frame:SetCallback("OnClose", function(widget)
    self.testDataEditFrame = nil
    widget:Release()
  end)

  local nameLabel = AceGUI:Create("Label")
  nameLabel:SetText("Name: " .. (player.name or "?"))
  nameLabel:SetFullWidth(true)
  frame:AddChild(nameLabel)

  local classDrop = AceGUI:Create("Dropdown")
  classDrop:SetLabel("Class")
  classDrop:SetWidth(300)
  classDrop:SetList(BuildClassOptions())
  classDrop:SetValue(player.class)
  frame:AddChild(classDrop)

  local specDrop = AceGUI:Create("Dropdown")
  specDrop:SetLabel("Spec")
  specDrop:SetWidth(300)
  specDrop:SetList(BuildSpecOptionsForClass(player.class))
  specDrop:SetValue(player.specName)
  frame:AddChild(specDrop)

  classDrop:SetCallback("OnValueChanged", function(_, _, value)
    specDrop:SetList(BuildSpecOptionsForClass(value))
    specDrop:SetValue(nil)
  end)

  local attendanceDrop = AceGUI:Create("Dropdown")
  attendanceDrop:SetLabel("Attendance")
  attendanceDrop:SetWidth(300)
  attendanceDrop:SetList({ PRESENT = "Present", ABSENT = "Absent" })
  attendanceDrop:SetValue(player.attendance or "PRESENT")
  frame:AddChild(attendanceDrop)

  local queueBox = AceGUI:Create("EditBox")
  queueBox:SetLabel("Queue Pos")
  queueBox:SetWidth(300)
  queueBox:SetText(tostring(player.queuePos or ""))
  frame:AddChild(queueBox)

  local wonBox = AceGUI:Create("EditBox")
  wonBox:SetLabel("Won")
  wonBox:SetWidth(300)
  wonBox:SetText(tostring(player.numAccepted or 0))
  frame:AddChild(wonBox)

  local raidsBox = AceGUI:Create("EditBox")
  raidsBox:SetLabel("Raids")
  raidsBox:SetWidth(300)
  raidsBox:SetText(tostring(player.attendanceCount or 0))
  frame:AddChild(raidsBox)

  local saveBtn = AceGUI:Create("Button")
  saveBtn:SetText("Save")
  saveBtn:SetWidth(120)
  saveBtn:SetCallback("OnClick", function()
    local classToken = classDrop:GetValue()
    local specName = specDrop:GetValue()
    local attendance = attendanceDrop:GetValue() or player.attendance or "PRESENT"
    local queuePosText = queueBox:GetText()
    local wonText = wonBox:GetText()
    local raidsText = raidsBox:GetText()
    local queuePos = nil
    if queuePosText and queuePosText ~= "" then
      queuePos = ParseNonNegativeInt(queuePosText)
      if queuePos == nil then
        TestUI:ShowTestDataMessage("Queue Pos must be >= 0.", true)
        return
      end
    end
    local won = ParseNonNegativeInt(wonText)
    if won == nil then
      TestUI:ShowTestDataMessage("Won must be >= 0.", true)
      return
    end
    local raids = ParseNonNegativeInt(raidsText)
    if raids == nil then
      TestUI:ShowTestDataMessage("Raids must be >= 0.", true)
      return
    end
    local ok, err, warn = GLD:UpdateTestPlayer(playerKey, {
      class = classToken,
      spec = specName,
      attendance = attendance,
      queuePos = queuePos,
      numAccepted = won,
      attendanceCount = raids,
    })
    if not ok then
      TestUI:ShowTestDataMessage(err or "Unable to update player.", true)
      return
    end
    if warn then
      TestUI:ShowTestDataMessage(warn, true)
    else
      TestUI:ShowTestDataMessage("Player updated.", false)
    end
    TestUI:RefreshTestPanel()
    TestUI:RefreshTestDataPanel()
    frame:Release()
    TestUI.testDataEditFrame = nil
  end)
  frame:AddChild(saveBtn)

  self.testDataEditFrame = frame
end

function TestUI:InitializeTestDataRow(row)
  if row.testDataInitialized then
    return
  end
  row:SetHeight(ADMIN_ROW_HEIGHT)
  if self.testDataHeaderRow and self.testDataHeaderRow.GetWidth then
    row:SetWidth(self.testDataHeaderRow:GetWidth())
  end

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetColorTexture(1, 1, 1, 0.08)
  highlight:SetAllPoints(row)

  row.cells = {}
  for _, col in ipairs(self.testDataColumns or {}) do
    if col.key == "queue" or col.key == "held" or col.key == "won" or col.key == "raids" then
      local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
      box:SetSize(col.width - 6, ADMIN_BUTTON_HEIGHT)
      box:SetPoint("LEFT", row, "LEFT", col.x + 3, 0)
      box:SetAutoFocus(false)
      box:SetJustifyH("CENTER")
      if box.SetNumeric then
        box:SetNumeric(true)
      end
      box:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
      end)
      if col.key == "queue" then
        row.queueBox = box
      elseif col.key == "held" then
        row.heldBox = box
      elseif col.key == "won" then
        row.wonBox = box
      elseif col.key == "raids" then
        row.raidsBox = box
      end
    elseif col.key == "edit" or col.key == "remove" then
      local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      button:SetSize(col.width, ADMIN_BUTTON_HEIGHT)
      button:SetPoint("LEFT", row, "LEFT", col.x, 0)
      row.cells[col.key] = button
    else
      local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      fs:SetWidth(col.width)
      fs:SetJustifyH(col.align or "LEFT")
      fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
      row.cells[col.key] = fs
    end
  end

  if row.queueBox then
    row.queueBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or not data.playerKey then
        box:ClearFocus()
        return
      end
      if not TestUI.queueEditEnabled then
        TestUI:ShowTestDataMessage("Edit Roster is off.", true)
        box:ClearFocus()
        return
      end
      local pos = ParseNonNegativeInt(box:GetText())
      if pos == nil then
        TestUI:ShowTestDataMessage("Queue Pos must be >= 0.", true)
      else
        local maxPos = GLD.GetTestQueueMax and GLD:GetTestQueueMax() or nil
        if maxPos ~= nil and pos > maxPos then
          pos = maxPos
          TestUI:ShowTestDataMessage("Queue Pos capped at " .. tostring(maxPos) .. ".", true)
        end
        local ok, err, warn = GLD:UpdateTestPlayer(data.playerKey, { queuePos = pos })
        if not ok then
          TestUI:ShowTestDataMessage(err or "Unable to update Queue Pos.", true)
        elseif warn then
          TestUI:ShowTestDataMessage(warn, true)
        else
          TestUI:RefreshTestPanel()
          TestUI:RefreshTestDataPanel()
        end
      end
      box:ClearFocus()
    end)
  end

  if row.heldBox then
    row.heldBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or not data.playerKey then
        box:ClearFocus()
        return
      end
      if not TestUI.queueEditEnabled then
        TestUI:ShowTestDataMessage("Edit Roster is off.", true)
        box:ClearFocus()
        return
      end
      local pos = ParseNonNegativeInt(box:GetText())
      if pos == nil then
        TestUI:ShowTestDataMessage("Held Pos must be >= 0.", true)
      else
        local ok, err = GLD:UpdateTestPlayer(data.playerKey, { savedPos = pos })
        if not ok then
          TestUI:ShowTestDataMessage(err or "Unable to update Held Pos.", true)
        else
          TestUI:RefreshTestPanel()
          TestUI:RefreshTestDataPanel()
        end
      end
      box:ClearFocus()
    end)
  end

  if row.wonBox then
    row.wonBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or not data.playerKey then
        box:ClearFocus()
        return
      end
      local num = ParseNonNegativeInt(box:GetText())
      if num == nil then
        TestUI:ShowTestDataMessage("Won must be >= 0.", true)
      else
        local ok, err = GLD:UpdateTestPlayer(data.playerKey, { numAccepted = num })
        if not ok then
          TestUI:ShowTestDataMessage(err or "Unable to update Won.", true)
        else
          TestUI:RefreshTestPanel()
          TestUI:RefreshTestDataPanel()
        end
      end
      box:ClearFocus()
    end)
  end

  if row.raidsBox then
    row.raidsBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not data or not data.playerKey then
        box:ClearFocus()
        return
      end
      local num = ParseNonNegativeInt(box:GetText())
      if num == nil then
        TestUI:ShowTestDataMessage("Raids must be >= 0.", true)
      else
        local ok, err = GLD:UpdateTestPlayer(data.playerKey, { attendanceCount = num })
        if not ok then
          TestUI:ShowTestDataMessage(err or "Unable to update Raids.", true)
        else
          TestUI:RefreshTestPanel()
          TestUI:RefreshTestDataPanel()
        end
      end
      box:ClearFocus()
    end)
  end

  if row.cells.edit then
    row.cells.edit:SetText("Edit")
    row.cells.edit:SetScript("OnClick", function()
      local data = row.data
      if data and data.playerKey then
        TestUI:ShowEditTestPlayerDialog(data.playerKey)
      end
    end)
  end

  if row.cells.remove then
    row.cells.remove:SetText("Remove")
    row.cells.remove:SetScript("OnClick", function()
      local data = row.data
      if data and data.playerKey then
        GLD:RemoveTestPlayer(data.playerKey)
        TestUI:ShowTestDataMessage("Player removed.", false)
        TestUI:RefreshTestPanel()
        TestUI:RefreshTestDataPanel()
      end
    end)
  end

  row.testDataInitialized = true
end

function TestUI:PopulateTestDataRow(row, data)
  if not row or not data or not row.cells then
    return
  end
  row.data = data

  if row.cells.class then
    row.cells.class:SetText(data.class or "-")
  end
  if row.cells.spec then
    row.cells.spec:SetText(data.spec or "-")
  end
  if row.cells.role then
    row.cells.role:SetText(data.role or "-")
  end
  if row.cells.name then
    row.cells.name:SetText(data.name or "-")
    local r, g, b = GetClassColor(data.class)
    row.cells.name:SetTextColor(r, g, b)
  end

  if row.queueBox then
    row.queueBox:SetText(tostring(data.queuePos or ""))
    SetEditBoxEnabled(row.queueBox, self.queueEditEnabled)
  end
  if row.heldBox then
    row.heldBox:SetText(tostring(data.savedPos or ""))
    SetEditBoxEnabled(row.heldBox, self.queueEditEnabled)
  end
  if row.wonBox then
    row.wonBox:SetText(tostring(data.won or 0))
  end
  if row.raidsBox then
    row.raidsBox:SetText(tostring(data.raids or 0))
  end
end

function TestUI:InitializeResultsRow(row)
  if row.isInitialized then
    return
  end
  row:SetHeight(ADMIN_ROW_HEIGHT)
  if self.resultsHeaderRow and self.resultsHeaderRow.GetWidth then
    row:SetWidth(self.resultsHeaderRow:GetWidth())
  end

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetColorTexture(1, 1, 1, 0.08)
  highlight:SetAllPoints(row)

  row.cells = {}
  for _, col in ipairs(self.resultsColumns or {}) do
    local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetWidth(col.width)
    fs:SetJustifyH(col.align or "LEFT")
    fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
    row.cells[col.key] = fs
  end

  row.isInitialized = true
end

function TestUI:PopulateResultsRow(row, data)
  if not row or not data or not row.cells then
    return
  end
  row.data = data
  local cells = row.cells

  if cells.name then
    cells.name:SetText(data.name or "-")
    local r, g, b = GetClassColor(data.class)
    cells.name:SetTextColor(r, g, b)
  end
  if cells.choice then
    cells.choice:SetText(data.choice or "-")
  end
  if cells.queue then
    cells.queue:SetText(data.queue or "-")
  end
  if cells.frozen then
    cells.frozen:SetText(data.frozen or "-")
  end
  if cells.loot then
    cells.loot:SetText(data.loot or "-")
  end
  if cells.class then
    cells.class:SetText(data.class or "-")
  end
  if cells.armor then
    cells.armor:SetText(data.armor or "-")
  end
  if cells.weapon then
    cells.weapon:SetText(data.weapon or "-")
  end
end
function TestUI:RefreshTestPanel()
  if not self.testFrame then
    return
  end

  self:UpdateDynamicTestVoters()

  if self.playerHeaderCells and self.playerHeaderCells.remove then
    local showRemove = GLD:IsAdmin() and self.queueEditEnabled
    self.playerHeaderCells.remove:SetShown(showRemove)
  end

  if GLD.testDb and GLD.testDb.testSession then
    self.testSessionActive = GLD.testDb.testSession.active == true
  end

  local sessionActive = self.testSessionActive == true
  if self.sessionStatus then
    self.sessionStatus:SetText("Session Status: " .. (sessionActive and "|cff00ff00ACTIVE|r" or "|cffff0000INACTIVE|r"))
  end
  self:RefreshGuestSimStatus()

  local list = BuildAdminRosterList() or {}

  table.sort(list, function(a, b)
    local playerA = a.player or a
    local playerB = b.player or b
    local attendanceA = playerA and playerA.attendance or ""
    local attendanceB = playerB and playerB.attendance or ""
    if attendanceA == "PRESENT" and attendanceB ~= "PRESENT" then
      return true
    end
    if attendanceA ~= "PRESENT" and attendanceB == "PRESENT" then
      return false
    end
    if attendanceA == "PRESENT" and attendanceB == "PRESENT" then
      local posA = playerA and playerA.queuePos or 99999
      local posB = playerB and playerB.queuePos or 99999
      if posA ~= posB then
        return posA < posB
      end
    end
    if attendanceA ~= "PRESENT" and attendanceB ~= "PRESENT" then
      local posA = playerA and playerA.savedPos or 99999
      local posB = playerB and playerB.savedPos or 99999
      if posA ~= posB then
        return posA < posB
      end
    end
    return ((playerA and playerA.name) or "") < ((playerB and playerB.name) or "")
  end)

  local rows = {}
  for _, entry in ipairs(list) do
    local player = entry.player
    if player then
      local displayName = GetLivePlayerDisplayName(player, entry.key, player.source == "guest")
      local baseName = player.name
      if not baseName then
        baseName = NS:GetPlayerBaseName(displayName)
      end
      baseName = baseName or displayName
      local role = NS.GetRoleForPlayer and NS:GetRoleForPlayer(baseName) or "NONE"
      if role == "NONE" then
        role = "-"
      end
      local specName = player.specName or player.spec or "-"
      rows[#rows + 1] = {
        player = player,
        playerKey = entry.key,
        name = displayName,
        class = player.class,
        spec = specName,
        role = role or "-",
        attendance = player.attendance or "-",
        queuePos = player.queuePos,
        savedPos = player.savedPos,
        won = player.numAccepted or 0,
        raids = player.attendanceCount or 0,
        isGuest = player.source == "guest",
      }
    end
  end

  if self.playerScrollBox and CreateDataProvider then
    local dataProvider = CreateDataProvider()
    for _, rowData in ipairs(rows) do
      dataProvider:Insert(rowData)
    end
    self.playerScrollBox:SetDataProvider(dataProvider, true)
  end

  self:RefreshTestDataPanel()
  self:RefreshInstanceList()
  self:RefreshVotePanel()
  self:RefreshResultsPanel()
  if self.testHistoryTree then
    self:RefreshTestHistoryList()
    self:RefreshTestHistoryDetails()
  end
end

function TestUI:RefreshTestDataPanel()
  if not self.testDataScrollBox or not CreateDataProvider then
    return
  end
  local rows = {}
  for key, player in pairs(GetTestPlayersTable()) do
    if player then
      local displayName = NS:GetPlayerDisplayName(player.name, player.source == "guest")
      rows[#rows + 1] = {
        playerKey = key,
        class = player.class,
        spec = player.specName or player.spec or "-",
        role = GetRoleForClassSpec(player.class, player.specName or player.spec),
        name = displayName,
        queuePos = player.queuePos,
        savedPos = player.savedPos,
        won = player.numAccepted or 0,
        raids = player.attendanceCount or 0,
      }
    end
  end
  local function NormalizeSortingName(value)
    local base = NS:GetPlayerBaseName(value or "")
    if base then
      return base
    end
    return value or ""
  end
  table.sort(rows, function(a, b)
    return NormalizeSortingName(a.name) < NormalizeSortingName(b.name)
  end)

  local dataProvider = CreateDataProvider()
  for _, rowData in ipairs(rows) do
    dataProvider:Insert(rowData)
  end
  self.testDataScrollBox:SetDataProvider(dataProvider, true)
end

function TestUI:RefreshVotePanel()
  if not self.voteStatusLabel then
    return
  end

  self:UpdateDynamicTestVoters()

  if self.currentVoterIndex == nil or self.currentVoterIndex < 0 then
    self.currentVoterIndex = 0
  end

  if self.disableManualVotes then
    if self.voteResetBtn and self.voteResetBtn.SetEnabled then
      self.voteResetBtn:SetEnabled(false)
    end
    if self.voteTitleLabel then
      self.voteTitleLabel:SetText("Test Vote Selection (live)")
    end
    if self.voteStatusLabel then
      self.voteStatusLabel:SetText("Manual voting disabled. Waiting for live votes sent to the authority.")
    end
    if self.votePlayerLabel then
      self.votePlayerLabel:SetText("")
    end
    if self.voteButtonsRow then
      self.voteButtonsRow:Hide()
    end
    return
  end

  if self.voteResetBtn and self.voteResetBtn.SetEnabled then
    self.voteResetBtn:SetEnabled(true)
  end
  if self.voteButtonsRow then
    self.voteButtonsRow:Show()
  end

  local activeVoters = GetActiveVoters()
  local currentEntry = activeVoters[self.currentVoterIndex + 1]
  local name = currentEntry and currentEntry.name or nil
  if self.voteTitleLabel then
    self.voteTitleLabel:SetText("Test Vote Selection" .. (name and (" - " .. name) or ""))
  end
  if not name then
    if self.voteStatusLabel then
      self.voteStatusLabel:SetText("All test votes recorded.")
    end
    if self.votePlayerLabel then
      self.votePlayerLabel:SetText("")
    end
    if self.voteButtonsRow then
      self.voteButtonsRow:Hide()
    end
    self:RefreshResultsPanel()
    return
  end

  if self.voteStatusLabel then
    self.voteStatusLabel:SetText("Test vote panel active")
  end
  if self.votePlayerLabel then
    self.votePlayerLabel:SetText("Player: " .. name)
  end

  local itemLink = NormalizeItemInput(self.itemLinkInput and self.itemLinkInput:GetText() or nil)
  local canNeed = true
  if itemLink and currentEntry and currentEntry.class then
    canNeed = IsNeedAllowedForEntry(currentEntry, itemLink)
  end

  local function setupVoteButton(button, vote)
    if not button then
      return
    end
    if button.SetEnabled then
      if vote == "NEED" and not canNeed then
        button:SetEnabled(false)
      else
        button:SetEnabled(true)
      end
    end
    button:SetScript("OnClick", function()
      self.testVotes[name] = vote
      self.currentVoterIndex = self.currentVoterIndex + 1
      GLD:Debug("Test vote: " .. tostring(name) .. " -> " .. tostring(vote) .. " (next index=" .. tostring(self.currentVoterIndex) .. ")")
      self:RefreshVotePanel()
      self:RefreshResultsPanel()
    end)
  end

  local buttons = self.voteButtons or {}
  setupVoteButton(buttons.need, "NEED")
  setupVoteButton(buttons.greed, "GREED")
  setupVoteButton(buttons.mog, "TRANSMOG")
  setupVoteButton(buttons.pass, "PASS")

  self:RefreshResultsPanel()
end

function TestUI:RefreshResultsPanel()
  if not self.resultsScrollBox then
    return
  end

  self:UpdateDynamicTestVoters()

  local itemLink = NormalizeItemInput(self.itemLinkInput and self.itemLinkInput:GetText() or nil)
  local liveSession = nil
  if self.disableManualVotes and self.currentTestRollID and GLD.activeRolls then
    local candidate = GLD.activeRolls[self.currentTestRollID]
    if candidate and candidate.isTest then
      liveSession = candidate
    end
  end
  local manualSession = nil
  if not liveSession and self.currentTestRollID and GLD.activeRolls then
    local candidate = GLD.activeRolls[self.currentTestRollID]
    if candidate and candidate.isTest then
      manualSession = candidate
    end
  end
  local liveVotes = liveSession and liveSession.votes or nil
  local provider = TestProvider or LiveProvider

  local function getVoteForEntry(entry)
    if not entry then
      return nil
    end
    if liveVotes then
      local key = nil
      if entry.name and provider and provider.GetPlayerKeyByName then
        local name, realm = NS:SplitNameRealm(entry.name)
        key = provider:GetPlayerKeyByName(name, realm)
      end
      if not key then
        key = GLD:GetRollCandidateKey(entry.name)
      end
      return liveVotes[key] or liveVotes[entry.name]
    end
    return self.testVotes[entry.name]
  end

  local function getPositionsForEntry(entry)
    if not entry or not entry.name then
      return "-", "-"
    end
    local name, realm = NS:SplitNameRealm(entry.name)
    local key = nil
    if provider and provider.GetPlayerKeyByName then
      key = provider:GetPlayerKeyByName(name, realm)
    end
    local queuePos = key and provider and provider.GetQueuePos and provider:GetQueuePos(key) or "-"
    local savedPos = key and provider and provider.GetHeldPos and provider:GetHeldPos(key) or "-"
    return queuePos, savedPos
  end
  local counts = { NEED = 0, GREED = 0, TRANSMOG = 0, PASS = 0 }
  local activeVoters = GetActiveVoters()
  for _, entry in ipairs(activeVoters) do
    local vote = getVoteForEntry(entry)
    if vote and counts[vote] then
      if vote == "NEED" and itemLink then
        if IsNeedAllowedForEntry(entry, itemLink) then
          counts[vote] = counts[vote] + 1
        end
      else
        counts[vote] = counts[vote] + 1
      end
    end
  end

  if self.resultsSummaryLabel then
    self.resultsSummaryLabel:SetText(string.format("Need: %d | Greed: %d | Mog: %d | Pass: %d",
      counts.NEED, counts.GREED, counts.TRANSMOG, counts.PASS))
  end

  local allDone = true
  if liveSession and liveSession.expectedVoters then
    for _, key in ipairs(liveSession.expectedVoters) do
      if not (liveVotes and liveVotes[key]) then
        allDone = false
        break
      end
    end
  else
    for _, entry in ipairs(activeVoters) do
      if not getVoteForEntry(entry) then
        allDone = false
        break
      end
    end
  end

  local winnerText = "Winner: (pending votes)"
  if allDone then
    local lootArmorType = GetArmorTypeOnly(itemLink)
    local armorPriority = {}
    local hasArmorPriority = false
    if lootArmorType == "Cloth" or lootArmorType == "Leather" or lootArmorType == "Mail" or lootArmorType == "Plate" then
      for _, entry in ipairs(activeVoters) do
        local vote = getVoteForEntry(entry)
        if vote == "NEED" and (not itemLink or IsNeedAllowedForEntry(entry, itemLink)) and entry.armor == lootArmorType then
          local name, realm = NS:SplitNameRealm(entry.name)
          local key = provider and provider.GetPlayerKeyByName and provider:GetPlayerKeyByName(name, realm) or nil
          if key then
            armorPriority[key] = true
            hasArmorPriority = true
          end
        end
      end
    end

    local votesByKey = {}
    for _, entry in ipairs(activeVoters) do
      local vote = getVoteForEntry(entry)
      if vote then
        if vote == "NEED" and itemLink and not IsNeedAllowedForEntry(entry, itemLink) then
          vote = nil
        end
      end
      if vote then
        local name, realm = NS:SplitNameRealm(entry.name)
        local key = provider and provider.GetPlayerKeyByName and provider:GetPlayerKeyByName(name, realm) or nil
        if key then
          if vote ~= "NEED" or not hasArmorPriority or armorPriority[key] then
            votesByKey[key] = vote
          end
        end
      end
    end

    local winnerKey = LootEngine
      and LootEngine.ResolveWinner
      and LootEngine:ResolveWinner(votesByKey, provider, nil, { itemLink = itemLink })
      or nil
    local winnerName = winnerKey and provider and provider.GetPlayerName and provider:GetPlayerName(winnerKey) or nil
    local winnerArmor = "-"
    if winnerKey and provider and provider.GetPlayer then
      local winnerPlayer = provider:GetPlayer(winnerKey)
      if winnerPlayer then
        winnerArmor = GetArmorForClass(winnerPlayer.class) or "-"
      end
    end
    local lootTypeDetail = GetLootTypeDetailed(itemLink)
    local lootArmorType = GetArmorTypeOnly(itemLink)
    winnerText = string.format(
      "Winner: %s | Armor: %s | Loot Armor: %s | Loot: %s",
      winnerName or "None",
      winnerArmor,
      lootArmorType,
      lootTypeDetail
    )

    if GLD.UI and GLD.UI.ShowRollResultPopup then
      local key = tostring(itemLink or "") .. ":" .. tostring(winnerName or "None")
      if self._lastTestResultKey ~= key then
        self._lastTestResultKey = key
        GLD.UI:ShowRollResultPopup({
          itemLink = itemLink,
          itemName = (itemLink and GetItemInfo(itemLink)) or nil,
          winnerName = winnerName or "None",
        })
      end
    end

    if manualSession and not manualSession.locked then
      local votesByKey = {}
      for _, entry in ipairs(activeVoters) do
        local vote = getVoteForEntry(entry)
        if vote == "NEED" and itemLink and not IsNeedAllowedForEntry(entry, itemLink) then
          vote = "PASS"
        end
        if vote then
          local key = nil
          if entry.name and provider and provider.GetPlayerKeyByName then
            local name, realm = NS:SplitNameRealm(entry.name)
            key = provider:GetPlayerKeyByName(name, realm)
          end
          if not key and entry.name and NS.SplitNameRealm then
            local name, realm = NS:SplitNameRealm(entry.name)
            if name and realm then
              key = name .. "-" .. realm
            end
          end
          if key then
            votesByKey[key] = vote
          end
        end
      end
      manualSession.votes = votesByKey
      if GLD.CheckRollCompletion then
        GLD:CheckRollCompletion(manualSession)
      end
    end
  end
  if self.resultsWinnerLabel then
    self.resultsWinnerLabel:SetText(winnerText)
  end

  if self.resultsResetSoloBtn then
    local showReset = self.disableManualVotes and not IsInRaid()
    self.resultsResetSoloBtn:SetShown(showReset)
  end
  local solo = IsSolo()
  if self.resultsAbsentBtn then
    self.resultsAbsentBtn:SetShown(solo)
  end
  if self.resultsRandomBtn then
    self.resultsRandomBtn:SetShown(solo)
  end

  local rows = {}
  local lootType = GetLootTypeText(itemLink)
  for _, entry in ipairs(activeVoters) do
    local vote = getVoteForEntry(entry) or "-"
    if vote == "NEED" and itemLink and not IsNeedAllowedForEntry(entry, itemLink) then
      vote = "NEED (ineligible)"
    end
    local queuePos, savedPos = getPositionsForEntry(entry)
    local queueSort = tonumber(queuePos) or 99999
    local normalized = NS:GetPlayerBaseName(entry.name) or (entry.name or "")
    rows[#rows + 1] = {
      name = NS:GetPlayerDisplayName(entry.name, entry.isGuest),
      nameLower = (normalized or ""):lower(),
      choice = vote,
      queue = queuePos,
      queueSort = queueSort,
      frozen = savedPos,
      loot = lootType or "-",
      class = entry.class or "-",
      armor = entry.armor or "-",
      weapon = entry.weapon or "-",
    }
  end

  table.sort(rows, function(a, b)
    if a.queueSort ~= b.queueSort then
      return a.queueSort < b.queueSort
    end
    return (a.nameLower or "") < (b.nameLower or "")
  end)

  if self.resultsScrollBox and CreateDataProvider then
    local dataProvider = CreateDataProvider()
    for _, rowData in ipairs(rows) do
      dataProvider:Insert(rowData)
    end
    self.resultsScrollBox:SetDataProvider(dataProvider, true)
  end
end

function TestUI:RefreshInstanceList()
  if not self.instanceSelect then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self:SetEJStatus("Encounter Journal: unavailable in combat")
    return
  end

  if not EncounterJournal then
    if C_AddOns and C_AddOns.LoadAddOn then
      C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
      LoadAddOn("Blizzard_EncounterJournal")
    end
  end
  if EncounterJournal_LoadUI then
    EncounterJournal_LoadUI()
  end

  if not EncounterJournal or (not (C_EncounterJournal and C_EncounterJournal.GetNumTiers) and not _G.EJ_GetNumTiers) then
    self:SetEJStatus("Encounter Journal: loading...")
    if not self._ejDebugShown then
      self._ejDebugShown = true
      GLD:Debug("EJ not ready yet (EncounterJournal or EJ_GetNumTiers missing)")
    end
    C_Timer.After(0.2, function()
      TestUI:RefreshInstanceList()
    end)
    return
  end

  EJ_Call("SetDifficultyID", 14)

  local values = {}
  local order = {}

  local tiers = EJ_Call("GetNumTiers") or 0
  if tiers == 0 then
    self:SetEJStatus("Encounter Journal: no tiers yet")
    if not self._ejDebugShown then
      self._ejDebugShown = true
      GLD:Debug("EJ tiers = 0 (no data yet)")
    end
    C_Timer.After(0.2, function()
      TestUI:RefreshInstanceList()
    end)
    return
  end
  for tier = 1, tiers do
    EJ_Call("SelectTier", tier)
    local i = 1
    while true do
      local instanceID, name = EJ_Call("GetInstanceByIndex", i, true)
      if not instanceID then
        break
      end
      if not values[instanceID] then
        values[instanceID] = name
        table.insert(order, instanceID)
      end
      i = i + 1
    end
  end

  self.instanceSelect:SetList(values, order)
  if #order == 0 then
    self:SetEJStatus("Encounter Journal: no raids returned")
    if not self._ejDebugShown then
      self._ejDebugShown = true
      GLD:Debug("EJ instances = 0 (no raids returned)")
    end
    C_Timer.After(0.2, function()
      TestUI:RefreshInstanceList()
    end)
    return
  end

  self:SetEJStatus("Encounter Journal: ready")

  local defaultInstanceId = nil
  for instanceId, name in pairs(values) do
    if name == DEFAULT_TEST_RAID then
      defaultInstanceId = instanceId
      break
    end
  end

  if not self.selectedInstance and (defaultInstanceId or order[1]) then
    local selected = defaultInstanceId or order[1]
    self.instanceSelect:SetValue(selected)
    self:SelectInstance(selected)
  end
end

function TestUI:SelectInstance(instanceID)
  if not instanceID then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    self:SetEJStatus("Encounter Journal: unavailable in combat")
    return
  end
  if not EncounterJournal then
    if C_AddOns and C_AddOns.LoadAddOn then
      C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
      LoadAddOn("Blizzard_EncounterJournal")
    end
  end
  if not (C_EncounterJournal and C_EncounterJournal.SelectInstance) and not _G.EJ_SelectInstance then
    self:SetEJStatus("Encounter Journal: not ready")
    return
  end
  self.selectedInstance = instanceID
  local instName = nil
  if C_EncounterJournal and C_EncounterJournal.GetInstanceInfo then
    local info = C_EncounterJournal.GetInstanceInfo(instanceID)
    if type(info) == "table" then
      instName = info.name
    else
      instName = info
    end
  elseif _G.EJ_GetInstanceInfo then
    instName = _G.EJ_GetInstanceInfo(instanceID)
  end
  self.selectedInstanceName = instName
  EJ_Call("SetDifficultyID", 14)
  EJ_Call("SelectInstance", instanceID)

  local encounters = {}
  local order = {}
  self.encounterNameToId = {}
  self.encounterNameToIndex = {}
  self.encounterIdToIndex = {}
  local seenEncounterIds = {}
  local i = 1
  while true do
    local a, b, c = EJ_Call("GetEncounterInfoByIndex", i, instanceID)
    if not a then
      break
    end
    local encounterID = nil
    local name = nil
    if type(a) == "number" then
      encounterID = a
      name = b
    elseif type(b) == "number" then
      encounterID = b
      name = a
    elseif type(c) == "number" then
      encounterID = c
      name = a
    end

    if type(encounterID) == "number" and not seenEncounterIds[encounterID] then
      seenEncounterIds[encounterID] = true
      local displayName = name or ("Encounter " .. encounterID)
      encounters[i] = displayName
      table.insert(order, i)
      if name then
        self.encounterNameToId[name] = encounterID
        self.encounterNameToIndex[name] = i
      end
      self.encounterIdToIndex[encounterID] = i
    end
    i = i + 1
  end

  self.encounterSelect:SetList(encounters, order)
  if #order == 0 then
    self:SetEJStatus("Encounter Journal: no encounters for raid")
    GLD:Debug("EJ encounters = 0 for instance " .. tostring(instanceID))
  end
  local defaultEncounterIndex = nil
  if DEFAULT_TEST_ENCOUNTER and self.encounterNameToIndex then
    defaultEncounterIndex = self.encounterNameToIndex[DEFAULT_TEST_ENCOUNTER]
  end
  if order[1] then
    local selected = defaultEncounterIndex or order[1]
    self.encounterSelect:SetValue(selected)
    self:SelectEncounter(selected)
  end
end

function TestUI:SelectEncounter(encounterID)
  if type(encounterID) == "string" and self.encounterNameToIndex then
    encounterID = self.encounterNameToIndex[encounterID] or encounterID
  end
  self.selectedEncounterIndex = encounterID
  if type(encounterID) == "number" and self.encounterIdToIndex then
    self.selectedEncounterID = nil
    for id, idx in pairs(self.encounterIdToIndex) do
      if idx == encounterID then
        self.selectedEncounterID = id
        break
      end
    end
  end
  local encounterName = nil
  if self.selectedInstance and type(encounterID) == "number" then
    local a, b, c = EJ_Call("GetEncounterInfoByIndex", encounterID, self.selectedInstance)
    if type(a) == "string" then
      encounterName = a
    elseif type(b) == "string" then
      encounterName = b
    elseif type(c) == "string" then
      encounterName = c
    end
  end
  self.selectedEncounterName = encounterName
end

function TestUI:LoadEncounterLoot(retryCount)
  if not self.selectedEncounterIndex or not self.lootScroll then
    GLD:Debug("LoadLoot: missing encounter or lootScroll")
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self:SetEJStatus("Encounter Journal: unavailable in combat")
    return
  end

  local encounterIndex = self.selectedEncounterIndex
  if type(encounterIndex) ~= "number" then
    GLD:Debug("LoadLoot: invalid encounterIndex " .. tostring(self.selectedEncounterIndex))
    return
  end

  local encounterID = self.selectedEncounterID
  if type(encounterID) ~= "number" then
    GLD:Debug("LoadLoot: missing encounterID for index " .. tostring(encounterIndex))
  end

  if not EncounterJournal then
    if C_AddOns and C_AddOns.LoadAddOn then
      C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then
      LoadAddOn("Blizzard_EncounterJournal")
    end
  end
  if not (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) and not _G.EJ_GetLootInfoByIndex then
    self:SetEJStatus("Encounter Journal: loot data unavailable")
    GLD:Debug("LoadLoot: EJ_GetLootInfoByIndex missing")
    return
  end

  self.lootScroll:ReleaseChildren()

  EJ_Call("SetLootFilter", 0)
  if C_EncounterJournal and C_EncounterJournal.ResetLootFilter then
    C_EncounterJournal.ResetLootFilter()
  end
  if _G.EJ_ResetLootFilter then
    _G.EJ_ResetLootFilter()
  end

  EJ_Call("SetDifficultyID", 14)
  if C_EncounterJournal and C_EncounterJournal.SetDifficultyID then
    C_EncounterJournal.SetDifficultyID(14)
  end

  if self.selectedInstance then
    EJ_Call("SelectInstance", self.selectedInstance)
  end
  if encounterID then
    EJ_Call("SelectEncounter", encounterID)
  elseif encounterIndex then
    EJ_Call("SelectEncounter", encounterIndex)
  end

  GLD:Debug("LoadLoot: encounterIndex=" .. tostring(encounterIndex) .. " encounterID=" .. tostring(encounterID))

  local function GetLootInfoByIndex(index)
    if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
      return C_EncounterJournal.GetLootInfoByIndex(index)
    end
    if _G.EJ_GetLootInfoByIndex then
      return _G.EJ_GetLootInfoByIndex(index, encounterID or encounterIndex)
    end
    return nil
  end

  local numLoot = nil
  if C_EncounterJournal and C_EncounterJournal.GetNumLoot then
    numLoot = C_EncounterJournal.GetNumLoot()
  elseif _G.EJ_GetNumLoot then
    numLoot = _G.EJ_GetNumLoot()
  end

  local index = 1
  local added = 0
  local needsRetry = false
  while true do
    if numLoot and index > numLoot then
      break
    end
    local rawInfo = { GetLootInfoByIndex(index) }
    local info = rawInfo[1]
    if not info then
      break
    end

    local itemName = nil
    local itemLink = nil
    local itemQuality = nil
    local itemLevel = nil
    local icon = nil
    local itemId = nil
    if type(info) == "table" then
      if type(info.name) == "string" then
        itemName = info.name
      end
      if type(info.link) == "string" then
        itemLink = info.link
      elseif type(info.itemLink) == "string" then
        itemLink = info.itemLink
      end
      if type(info.quality) == "number" then
        itemQuality = info.quality
      elseif type(info.itemQuality) == "number" then
        itemQuality = info.itemQuality
      end
      if type(info.itemLevel) == "number" then
        itemLevel = info.itemLevel
      end
      icon = info.icon or info.texture
      itemId = info.itemId or info.itemID or info.id
    else
      for _, value in ipairs(rawInfo) do
        if not itemId and type(value) == "number" then
          itemId = value
        elseif type(value) == "string" then
          if not itemLink and (value:find("|Hitem:") or value:find("^item:")) then
            itemLink = value
          elseif not itemName then
            itemName = value
          end
        end
      end
    end
    if not itemLink and itemId then
      itemLink = "item:" .. tostring(itemId)
    end
    if itemLink then
      GLD:RequestItemData(itemLink)
      local name, link, quality, level, _, _, _, _, iconInfo = GetItemInfo(itemLink)
      if type(itemName) ~= "string" or itemName == "" then
        itemName = name
      end
      if type(itemLink) ~= "string" or itemLink == "" then
        itemLink = link or itemLink
      else
        itemLink = link or itemLink
      end
      if type(itemQuality) ~= "number" then
        itemQuality = quality
      end
      if type(itemLevel) ~= "number" then
        itemLevel = level
      end
      if not icon then
        icon = iconInfo
      end
    end
    if not itemName or not icon then
      needsRetry = true
    end
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local iconButton = AceGUI:Create("Icon")
    iconButton:SetImage(icon)
    iconButton:SetImageSize(20, 20)
    iconButton:SetWidth(24)
    iconButton:SetHeight(24)
    iconButton:SetCallback("OnEnter", function()
      if itemLink then
        GameTooltip:SetOwner(iconButton.frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
      end
    end)
    iconButton:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)
    iconButton:SetCallback("OnClick", function()
      if itemLink then
        self:SetSelectedItemLink(itemLink)
      end
    end)
    row:AddChild(iconButton)

    local nameLabel = AceGUI:Create("InteractiveLabel")
    local labelText = tostring(itemName or itemLink or "Unknown Item")
    if itemLevel then
      labelText = string.format("%s |cff999999(ilvl %s)|r", labelText, itemLevel)
    end
    nameLabel:SetText(labelText)
    nameLabel:SetWidth(220)
    nameLabel:SetCallback("OnEnter", function()
      if itemLink then
        GameTooltip:SetOwner(nameLabel.frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
      end
    end)
    nameLabel:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)
    nameLabel:SetCallback("OnClick", function()
      if itemLink then
        self:SetSelectedItemLink(itemLink)
      end
    end)
    row:AddChild(nameLabel)

    self.lootScroll:AddChild(row)
    added = added + 1

    index = index + 1
  end

  GLD:Debug("LoadLoot: items added=" .. tostring(added))

  retryCount = retryCount or 0
  if (added == 0 or needsRetry) and retryCount < 5 then
    GLD:Debug("LoadLoot: items pending, retrying " .. tostring(retryCount + 1))
    C_Timer.After(0.3, function()
      TestUI:LoadEncounterLoot(retryCount + 1)
    end)
  end
end

function TestUI:SimulateLootRoll(itemLink)
  if GLD.CleanupOldTestRolls then
    GLD:CleanupOldTestRolls()
  end
  if not self.testSessionActive then
    self:StartTestSession()
  end
  local solo = IsSolo()
  local activeVoters = GetActiveVoters()
  if not activeVoters or #activeVoters == 0 then
    GLD:Print("No test players configured.")
    return
  end
  if not solo and (self.currentVoterIndex or 0) > (#activeVoters - 1) then
    GLD:Print("All test voters completed. Use Reset Votes to start again.")
    return
  end
  if not itemLink or itemLink == "" then
    GLD:Print("Please enter an item link")
    return
  end

  local normalized = NormalizeItemInput(itemLink)
  if not normalized then
    GLD:Print("Please enter an item link")
    return
  end

  if normalized:find("^item:%d+") then
    GLD:RequestItemData(normalized)
  elseif normalized:find("|Hitem:") then
    GLD:RequestItemData(normalized)
  end

  local name, link, quality = GetItemInfo(normalized)
  local displayLink = link or normalized
  local displayName = name or "Test Item"

  local itemContext = {
    itemLink = displayLink,
    itemName = displayName,
    armorType = GetArmorTypeOnly(normalized),
    lootType = GetLootTypeText(normalized),
  }
  if LootEngine and TestProvider then
    local eligiblePlayers = LootEngine:BuildEligiblePlayers(itemContext, TestProvider)
    LootEngine:ApplyRestrictions(eligiblePlayers, { queueEditEnabled = self.queueEditEnabled })
    LootEngine:ComputeQueue(eligiblePlayers)
  end

  local voterEntry = GetTestVoter((self.currentVoterIndex or 0) + 1)
  local canNeed = true
  if not solo and voterEntry and voterEntry.class then
    canNeed = IsNeedAllowedForEntry(voterEntry, normalized)
  end

  local rollID = math.random(1, 10000)
  local rollTime = 120
  local rollKey = nil
  if GLD and GLD.BuildRollNonce and GLD.MakeRollKey then
    rollKey = GLD:MakeRollKey(rollID, GLD:BuildRollNonce())
  end
  rollKey = rollKey or (tostring(rollID) .. "@legacy")

  local session = {
    rollID = rollID,
    rollKey = rollKey,
    rollTime = rollTime,
    itemLink = displayLink,
    itemName = displayName,
    quality = quality or 4,
    canNeed = canNeed,
    canGreed = true,
    canTransmog = true,
    votes = {},
    expectedVoters = nil,
    createdAt = GetServerTime(),
    isTest = true,
    testEncounterId = self.selectedEncounterID,
    testEncounterName = self.selectedEncounterName,
    testRaidName = self.selectedInstanceName,
  }
  if TestProvider and TestProvider.BuildExpectedVoters then
    session.expectedVoters = TestProvider:BuildExpectedVoters()
  end
  if not session.expectedVoters or #session.expectedVoters == 0 then
    session.expectedVoters = solo and BuildSoloExpectedVoters(activeVoters) or GLD:BuildExpectedVoters()
  end

  GLD.activeRolls[rollKey] = session
  self.currentTestRollID = rollKey

  if GLD.UI then
    local voter = nil
    if not solo and IsInRaid() then
      local name, realm = UnitName("player")
      if name then
        voter = realm and realm ~= "" and (name .. "-" .. realm) or name
      end
    end
    if not solo and not voter then
      voter = GetTestVoterName((self.currentVoterIndex or 0) + 1) or "Test Player"
    end
    if solo then
      self:ShowSoloSimVotePopup(session, activeVoters)
    else
      session.testVoterName = voter
      GLD.UI:ShowRollPopup(session)
      if GLD.UI.ShowPendingFrame then
        GLD.UI:ShowPendingFrame()
      end
    end
  end

  if IsInRaid() then
    local channel = "RAID"
    GLD:SendCommMessageSafe(NS.MSG.ROLL_SESSION, {
      rollID = rollID,
      rollKey = rollKey,
      rollTime = rollTime * 1000,
      itemLink = displayLink,
      itemName = displayName,
      quality = session.quality,
      canNeed = canNeed,
      canGreed = true,
      canTransmog = true,
      test = true,
    }, channel)
  end

  GLD:Print("Simulated loot roll: " .. displayLink)
end

function TestUI:AdvanceTestVoter()
  self.currentVoterIndex = (self.currentVoterIndex or 0) + 1
  local activeVoters = GetActiveVoters()
  if self.currentVoterIndex > (#activeVoters - 1) then
    self.currentVoterIndex = #activeVoters
  end
  self:RefreshVotePanel()
  self:RefreshResultsPanel()
  local soloLive = self.disableManualVotes and not IsInRaid()
  if not soloLive and self.currentVoterIndex <= (#activeVoters - 1) then
    if self.itemLinkInput then
      self:SimulateLootRoll(self.itemLinkInput:GetText())
    end
    if self.itemLinkInput2 then
      self:SimulateLootRoll(self.itemLinkInput2:GetText())
    end
  end
end

function TestUI:ToggleTestHistory()
  if not GLD:IsAdmin() then
    GLD:ShowPermissionDeniedPopup()
    return
  end
  self:SetActiveAdminTab("history")
  self:RefreshTestHistoryList()
  self:RefreshTestHistoryDetails()
  if self.testHistoryTree then
    if self.testHistoryTree.RefreshTree then
      self.testHistoryTree:RefreshTree()
    end
    if self.testHistoryTree.DoLayout then
      self.testHistoryTree:DoLayout()
    end
  end
end

function TestUI:ToggleTestGraphs()
  if not AceGUI then
    return
  end
  if not GLD:IsAdmin() then
    GLD:ShowPermissionDeniedPopup()
    return
  end
  if not self.testGraphsFrame then
    self:CreateTestGraphsFrame()
    self.testGraphsFrame:Show()
    self:RefreshTestGraphs()
    return
  end
  if self.testGraphsFrame:IsShown() then
    self.testGraphsFrame:Hide()
  else
    self.testGraphsFrame:Show()
    self:RefreshTestGraphs()
  end
end

function TestUI:CreateTestGraphsFrame()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Experimental Graphs (Test Data)")
  frame:SetStatusText("Items won and attendance from test panel data")
  frame:SetWidth(700)
  frame:SetHeight(520)
  frame:SetLayout("Flow")
  frame:EnableResize(true)

  local refreshBtn = AceGUI:Create("Button")
  refreshBtn:SetText("Refresh")
  refreshBtn:SetWidth(120)
  refreshBtn:SetCallback("OnClick", function()
    self:RefreshTestGraphs()
  end)
  frame:AddChild(refreshBtn)

  local debugToggle = AceGUI:Create("CheckBox")
  debugToggle:SetLabel("Debug Mode")
  debugToggle:SetWidth(140)
  debugToggle:SetValue(self.testGraphsDebug == true)
  debugToggle:SetCallback("OnValueChanged", function(_, _, value)
    self.testGraphsDebug = value and true or false
    self:RefreshTestGraphs()
  end)
  frame:AddChild(debugToggle)

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("Flow")
  scroll:SetFullWidth(true)
  scroll:SetFullHeight(true)
  frame:AddChild(scroll)

  self.testGraphsFrame = frame
  self.testGraphsScroll = scroll
end

function TestUI:RefreshTestGraphs()
  if not self.testGraphsScroll then
    return
  end
  if self._testGraphBars then
    for _, bar in ipairs(self._testGraphBars) do
      bar:Hide()
      bar:SetParent(nil)
    end
  end
  self._testGraphBars = {}
  self.testGraphsScroll:ReleaseChildren()

  local list = BuildTestRosterList()
  if not list or #list == 0 then
    local empty = AceGUI:Create("Label")
    empty:SetFullWidth(true)
    empty:SetText("No test data available.")
    self.testGraphsScroll:AddChild(empty)
    return
  end

  if self.testGraphsDebug then
    local debugHeader = AceGUI:Create("Heading")
    debugHeader:SetFullWidth(true)
    debugHeader:SetText("Debug: Graph data source")
    self.testGraphsScroll:AddChild(debugHeader)

    for _, entry in ipairs(list) do
      local name = entry.name or "?"
      local realm = entry.realm or GetRealmName()
      local key = name .. "-" .. realm
      local wins = tonumber(entry.numAccepted or 0) or 0
      local attend = tonumber(entry.attendanceCount or 0) or 0
      local dbKey = GLD:FindTestPlayerKeyByName(name, realm)
      local fromDb = dbKey and GLD.testDb and GLD.testDb.players and GLD.testDb.players[dbKey] and "TestDB" or "Local"
      local debugLine = AceGUI:Create("Label")
      debugLine:SetFullWidth(true)
      debugLine:SetText(string.format("%s (%s) | wins=%s | raids=%s | source=%s", name, key, wins, attend, fromDb))
      self.testGraphsScroll:AddChild(debugLine)
    end
  end

  local maxWins = 0
  for _, entry in ipairs(list) do
    local wins = tonumber(entry.numAccepted or 0) or 0
    if wins > maxWins then
      maxWins = wins
    end
  end
  if maxWins == 0 then
    maxWins = 1
  end

  local header = AceGUI:Create("Label")
  header:SetFullWidth(true)
  header:SetText("Player | Items Won")
  self.testGraphsScroll:AddChild(header)

  local function createWinsBar(parentFrame, width, height, value, maxValue, classFile)
    if not parentFrame then
      return
    end
    local bar = parentFrame._gldBar
    if bar and bar:GetParent() ~= parentFrame then
      bar = nil
      parentFrame._gldBar = nil
      parentFrame._gldBarText = nil
    end
    if not bar then
      bar = CreateFrame("StatusBar", nil, parentFrame)
      bar:SetPoint("LEFT", parentFrame, "LEFT", 0, 0)
      bar:SetPoint("TOP", parentFrame, "TOP", 0, 0)
      bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
      if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        bar:SetStatusBarColor(c.r, c.g, c.b, 0.9)
      else
        bar:SetStatusBarColor(0.2, 0.6, 1, 0.9)
      end

      local bg = bar:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(bar)
      bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)

      local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      text:SetPoint("CENTER", bar, "CENTER", 0, 0)
      parentFrame._gldBarText = text
      parentFrame._gldBar = bar
    end

    bar:SetSize(width, height)
    bar:SetMinMaxValues(0, maxValue)
    bar:SetValue(value)
    if parentFrame._gldBarText then
      parentFrame._gldBarText:SetText(tostring(value))
    end
  end

  for _, entry in ipairs(list) do
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetHeight(18)
    row:SetLayout("Flow")

    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetWidth(160)
    nameLabel:SetText(ColorizeClassName(entry.name or "?", entry.class))
    row:AddChild(nameLabel)

    local wins = tonumber(entry.numAccepted or 0) or 0
    local barGroup = AceGUI:Create("SimpleGroup")
    barGroup:SetWidth(280)
    barGroup:SetHeight(16)
    barGroup:SetLayout("Fill")
    row:AddChild(barGroup)

    if barGroup.frame then
      if barGroup.frame._gldBar then
        barGroup.frame._gldBar:Hide()
        barGroup.frame._gldBar:SetParent(nil)
        barGroup.frame._gldBar = nil
        barGroup.frame._gldBarText = nil
      end
      barGroup.frame:SetWidth(280)
      barGroup.frame:SetHeight(16)
      createWinsBar(barGroup.frame, 270, 14, wins, maxWins, entry.class)
      if barGroup.frame._gldBar then
        table.insert(self._testGraphBars, barGroup.frame._gldBar)
      end
    end

    self.testGraphsScroll:AddChild(row)
  end
end

function TestUI:CreateTestHistoryPanel(parent)
  if not AceGUI or not parent then
    return
  end
  if self.testHistoryTree then
    return
  end

  local tree = AceGUI:Create("TreeGroup")
  tree:SetFullWidth(true)
  tree:SetFullHeight(true)
  tree:SetLayout("Fill")
  if tree.EnableTreeResizing then
    tree:EnableTreeResizing(false)
  end
  if tree.SetTreeWidth then
    tree:SetTreeWidth(320, false)
  end
  if tree.EnableButtonTooltips then
    tree:EnableButtonTooltips(false)
  end
  tree:SetCallback("OnGroupSelected", function(_, _, value)
    self.testHistorySelectedId = value
    self:RefreshTestHistoryDetails()
  end)

  tree.frame:SetParent(parent)
  tree.frame:ClearAllPoints()
  tree.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -24)
  tree.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)
  tree.frame:Show()

  self.testHistoryFrame = parent
  self.testHistoryTree = tree
  self.testHistoryDetailScroll = nil
  self.testHistorySelectedId = nil
end

function TestUI:CreateTestHistoryFrame()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Test Session History")
  frame:SetStatusText("Admin test loot history")
  frame:SetWidth(900)
  frame:SetHeight(560)
  frame:SetLayout("Flow")
  frame:EnableResize(true)

  local tree = AceGUI:Create("TreeGroup")
  tree:SetFullWidth(true)
  tree:SetFullHeight(true)
  tree:SetLayout("Fill")
  if tree.EnableTreeResizing then
    tree:EnableTreeResizing(false)
  end
  if tree.SetTreeWidth then
    tree:SetTreeWidth(380, false)
  end
  if tree.EnableButtonTooltips then
    tree:EnableButtonTooltips(false)
  end
  tree:SetCallback("OnGroupSelected", function(_, _, value)
    self.testHistorySelectedId = value
    self:RefreshTestHistoryDetails()
  end)
  frame:AddChild(tree)

  self.testHistoryFrame = frame
  self.testHistoryTree = tree
  self.testHistoryDetailScroll = nil
  self.testHistorySelectedId = nil
end

function TestUI:RefreshTestHistoryList()
  if not self.testHistoryTree then
    return
  end

  local sessions = GLD.testDb and GLD.testDb.testSessions or {}
  local treeData = {}
  if #sessions == 0 then
    self.testHistoryTree:SetTree(treeData)
    self.testHistorySelectedId = nil
    self:RefreshTestHistoryDetails()
    return
  end

  local firstId = nil
  local maxLabelWidth = 0
  for _, entry in ipairs(sessions) do
    if not firstId then
      firstId = entry.id
    end
    local label = string.format("%s - %s - %s", FormatDateTime(entry.startedAt), entry.raidName or "Test Raid", FormatDuration(entry.startedAt, entry.endedAt))
    treeData[#treeData + 1] = { value = entry.id, text = label }
    if self.testHistoryTree and self.testHistoryTree.frame then
      if not self._testHistoryMeasure then
        local fs = self.testHistoryTree.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText("")
        self._testHistoryMeasure = fs
      end
      if self._testHistoryMeasure then
        self._testHistoryMeasure:SetText(label)
        local w = self._testHistoryMeasure:GetStringWidth() or 0
        if w > maxLabelWidth then
          maxLabelWidth = w
        end
      end
    end
  end

  self.testHistoryTree:SetTree(treeData)
  if self.testHistoryTree.SetTreeWidth and maxLabelWidth > 0 then
    local padding = 60
    local width = math.floor(maxLabelWidth + padding)
    width = math.max(220, math.min(520, width))
    self.testHistoryTree:SetTreeWidth(width, false)
  end
  if not self.testHistorySelectedId and firstId then
    self.testHistorySelectedId = firstId
    self.testHistoryTree:Select(firstId)
  end
end

function TestUI:RefreshTestHistoryDetails()
  if not self.testHistoryTree then
    return
  end
  self.testHistoryTree:ReleaseChildren()

  local detailScroll = AceGUI:Create("ScrollFrame")
  detailScroll:SetLayout("Flow")
  detailScroll:SetFullWidth(true)
  detailScroll:SetFullHeight(true)
  self.testHistoryTree:AddChild(detailScroll)
  self.testHistoryDetailScroll = detailScroll

  local selected = nil
  for _, entry in ipairs(GLD.testDb and GLD.testDb.testSessions or {}) do
    if entry.id == self.testHistorySelectedId then
      selected = entry
      break
    end
  end

  if not selected then
    local empty = AceGUI:Create("Label")
    empty:SetFullWidth(true)
    empty:SetText("Select a test session to view details.")
    detailScroll:AddChild(empty)
    return
  end

  local header = AceGUI:Create("Heading")
  header:SetFullWidth(true)
  header:SetText("Test Session - " .. (selected.raidName or "Test Raid"))
  detailScroll:AddChild(header)

  local meta = AceGUI:Create("Label")
  meta:SetFullWidth(true)
  meta:SetText(string.format("Start: %s | End: %s | Duration: %s",
    FormatDateTime(selected.startedAt),
    FormatDateTime(selected.endedAt),
    FormatDuration(selected.startedAt, selected.endedAt)
  ))
  detailScroll:AddChild(meta)

  local copyBtn = AceGUI:Create("Button")
  copyBtn:SetText("Copy Summary")
  copyBtn:SetWidth(140)
  copyBtn:SetCallback("OnClick", function()
    self:ShowTestHistorySummaryPopup(selected)
  end)
  detailScroll:AddChild(copyBtn)

  local function addLootRow(item)
    local winnerName = item.winnerName or "None"
    local shortName = winnerName
    local classFile = nil
    if NS and NS.SplitNameRealm and winnerName ~= "None" then
      local nameOnly = NS:SplitNameRealm(winnerName)
      if nameOnly and nameOnly ~= "" then
        shortName = nameOnly
      end
    end
    if item.winnerKey and GLD.testDb and GLD.testDb.players and GLD.testDb.players[item.winnerKey] then
      classFile = GLD.testDb.players[item.winnerKey].class
    elseif shortName and GLD.FindTestPlayerKeyByName then
      local key = GLD:FindTestPlayerKeyByName(shortName)
      if key and GLD.testDb and GLD.testDb.players and GLD.testDb.players[key] then
        classFile = GLD.testDb.players[key].class
      end
    end
    if classFile then
      shortName = ColorizeClassName(shortName, classFile)
    end

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    if item.itemLink then
      local itemIcon = select(10, GetItemInfo(item.itemLink))
      if itemIcon then
        icon = itemIcon
      else
        GLD:RequestItemData(item.itemLink)
      end
    end

    local iconWidget = AceGUI:Create("Icon")
    iconWidget:SetImage(icon)
    iconWidget:SetImageSize(20, 20)
    iconWidget:SetWidth(24)
    iconWidget:SetHeight(24)
    iconWidget:SetCallback("OnEnter", function()
      local link = item.itemLink
      if link and link ~= "" then
        GameTooltip:SetOwner(iconWidget.frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
      end
    end)
    iconWidget:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)
    row:AddChild(iconWidget)

    local itemLabel = AceGUI:Create("InteractiveLabel")
    itemLabel:SetWidth(240)
    itemLabel:SetText(item.itemLink or item.itemName or "Unknown Item")
    itemLabel:SetCallback("OnEnter", function()
      local link = item.itemLink
      if link and link ~= "" then
        GameTooltip:SetOwner(itemLabel.frame, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
      end
    end)
    itemLabel:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)
    row:AddChild(itemLabel)

    local winnerLabel = AceGUI:Create("Label")
    winnerLabel:SetWidth(160)
    winnerLabel:SetText("Winner: " .. tostring(shortName or "None"))
    row:AddChild(winnerLabel)

    self.testHistoryDetailScroll:AddChild(row)
  end

  local bosses = selected.bosses or {}
  if #bosses == 0 then
    local loot = selected.loot or {}
    if #loot == 0 then
      local none = AceGUI:Create("Label")
      none:SetFullWidth(true)
      none:SetText("No loot recorded for this test session.")
      detailScroll:AddChild(none)
      return
    end
    for _, item in ipairs(loot) do
      addLootRow(item)
    end
    return
  end

  for _, boss in ipairs(bosses) do
    local bossHeader = AceGUI:Create("Heading")
    bossHeader:SetFullWidth(true)
    bossHeader:SetText((boss.encounterName or "Encounter") .. " - " .. FormatDateTime(boss.killedAt))
    detailScroll:AddChild(bossHeader)

    local loot = boss.loot or {}
    if #loot == 0 then
      local none = AceGUI:Create("Label")
      none:SetFullWidth(true)
      none:SetText("No loot recorded for this encounter.")
      detailScroll:AddChild(none)
    else
      for _, item in ipairs(loot) do
        addLootRow(item)
      end
    end
  end
end

function TestUI:ShowTestHistorySummaryPopup(session)
  if not AceGUI or not session then
    return
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Test Session Summary")
  frame:SetStatusText("Test")
  frame:SetWidth(520)
  frame:SetHeight(360)
  frame:SetLayout("Fill")
  frame:EnableResize(true)

  local box = AceGUI:Create("MultiLineEditBox")
  box:SetLabel("Copy this summary")
  box:SetFullWidth(true)
  box:SetFullHeight(true)
  box:DisableButton(true)

  local lines = {}
  lines[#lines + 1] = "Test Session"
  lines[#lines + 1] = string.format("Raid: %s", session.raidName or "Test Raid")
  lines[#lines + 1] = string.format("Start: %s", FormatDateTime(session.startedAt))
  lines[#lines + 1] = string.format("End: %s", FormatDateTime(session.endedAt))
  lines[#lines + 1] = string.format("Duration: %s", FormatDuration(session.startedAt, session.endedAt))
  lines[#lines + 1] = ""

  local bosses = session.bosses or {}
  if #bosses > 0 then
    for _, boss in ipairs(bosses) do
      lines[#lines + 1] = string.format("Encounter: %s", boss.encounterName or "Encounter")
      for _, item in ipairs(boss.loot or {}) do
        lines[#lines + 1] = string.format("  - %s -> %s", item.itemName or item.itemLink or "Unknown Item", item.winnerName or "None")
      end
    end
  else
    for _, item in ipairs(session.loot or {}) do
      lines[#lines + 1] = string.format("- %s -> %s", item.itemName or item.itemLink or "Unknown Item", item.winnerName or "None")
    end
  end

  if #lines <= 5 then
    lines[#lines + 1] = "No loot recorded."
  end

  box:SetText(table.concat(lines, "\n"))
  frame:AddChild(box)
end

