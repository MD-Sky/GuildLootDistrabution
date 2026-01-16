local _, NS = ...

local GLD = NS.GLD

local ARMOR_BY_CLASS = {
  WARRIOR = {4},
  PALADIN = {4},
  DEATHKNIGHT = {4},
  HUNTER = {3},
  SHAMAN = {3},
  ROGUE = {2},
  DRUID = {2},
  MONK = {2},
  DEMONHUNTER = {2},
  PRIEST = {1},
  MAGE = {1},
  WARLOCK = {1},
  EVOKER = {3},
}

local WEAPON_BY_CLASS = {
  WARRIOR = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  PALADIN = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  DEATHKNIGHT = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  HUNTER = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  SHAMAN = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  ROGUE = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  DRUID = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  MONK = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  DEMONHUNTER = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  PRIEST = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  MAGE = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  WARLOCK = {0, 1, 2, 3, 4, 5, 6, 7, 8},
  EVOKER = {0, 1, 2, 3, 4, 5, 6, 7, 8},
}

local ITEM_CLASS_ARMOR = 4
local ITEM_CLASS_WEAPON = 2
local ARMOR_TRINKET = 0
local ARMOR_RING = 11
local ARMOR_NECK = 2

local ARMOR_SUBCLASS_BY_NAME = {}
if ITEM_SUBCLASS_ARMOR_CLOTH then
  ARMOR_SUBCLASS_BY_NAME[ITEM_SUBCLASS_ARMOR_CLOTH] = 1
end
if ITEM_SUBCLASS_ARMOR_LEATHER then
  ARMOR_SUBCLASS_BY_NAME[ITEM_SUBCLASS_ARMOR_LEATHER] = 2
end
if ITEM_SUBCLASS_ARMOR_MAIL then
  ARMOR_SUBCLASS_BY_NAME[ITEM_SUBCLASS_ARMOR_MAIL] = 3
end
if ITEM_SUBCLASS_ARMOR_PLATE then
  ARMOR_SUBCLASS_BY_NAME[ITEM_SUBCLASS_ARMOR_PLATE] = 4
end

local CLASS_NAME_TO_FILE = {}
if LOCALIZED_CLASS_NAMES_MALE then
  for classFile, className in pairs(LOCALIZED_CLASS_NAMES_MALE) do
    if className then
      CLASS_NAME_TO_FILE[string.lower(className)] = classFile
    end
  end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
  for classFile, className in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
    if className then
      CLASS_NAME_TO_FILE[string.lower(className)] = classFile
    end
  end
end

local function StripColor(text)
  if not text then
    return text
  end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  return text
end

local function Trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetClassesPrefix()
  if ITEM_CLASSES_ALLOWED then
    return ITEM_CLASSES_ALLOWED:match("^(.-)%%s")
  end
  return "Classes: "
end

local function ParseClassRestriction(text)
  if not text or text == "" then
    return nil
  end
  local cleanText = Trim(StripColor(text))
  local prefix = GetClassesPrefix()
  if not cleanText:find(prefix, 1, true) then
    return nil
  end
  local rest = Trim(cleanText:sub(#prefix + 1))
  if rest == "" then
    return nil
  end
  if ALL and rest:lower() == tostring(ALL):lower() then
    return false
  end
  local allowed = {}
  local count = 0
  for name in rest:gmatch("[^,]+") do
    local key = Trim(name):lower()
    local classFile = CLASS_NAME_TO_FILE[key]
    if classFile and not allowed[classFile] then
      allowed[classFile] = true
      count = count + 1
    end
  end
  if count > 0 then
    return allowed
  end
  return nil
end

local function Contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

function GLD:RequestItemData(item)
  if not item then
    return
  end
  if type(item) == "table" and item.GetEquipmentSlot then
    C_Item.RequestLoadItemData(item)
    return
  end

  local itemID = nil
  if type(item) == "number" then
    itemID = item
  elseif type(item) == "string" then
    itemID = tonumber(item:match("item:(%d+)")) or tonumber(item:match("^%d+$"))
  end

  if itemID then
    C_Item.RequestLoadItemDataByID(itemID)
  end
end

function GLD:GetItemClassRestrictions(item)
  if not item then
    return nil
  end

  local itemID = C_Item.GetItemInfoInstant(item)
  if not itemID then
    self:RequestItemData(item)
    return nil
  end

  self._classRestrictionCache = self._classRestrictionCache or {}
  if self._classRestrictionCache[itemID] ~= nil then
    return self._classRestrictionCache[itemID] or nil
  end

  local itemLink = item
  if type(item) == "number" then
    itemLink = "item:" .. tostring(item)
  elseif type(item) == "string" and item:match("^%d+$") then
    itemLink = "item:" .. item
  end

  local restriction = nil
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink and itemLink then
    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if data and data.lines then
      for _, line in ipairs(data.lines) do
        local text = line.leftText or line.text
        restriction = ParseClassRestriction(text)
        if restriction ~= nil then
          break
        end
      end
    end
  end

  if restriction == nil and GameTooltip and itemLink then
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetHyperlink(itemLink)
    for i = 1, GameTooltip:NumLines() do
      local line = _G["GameTooltipTextLeft" .. i]
      local text = line and line:GetText() or nil
      restriction = ParseClassRestriction(text)
      if restriction ~= nil then
        break
      end
    end
    GameTooltip:Hide()
  end

  if restriction == nil then
    self._classRestrictionCache[itemID] = false
    return nil
  end

  self._classRestrictionCache[itemID] = restriction
  return restriction
end

function GLD:IsEligibleForNeed(classFile, item)
  if not classFile or not item then
    return false
  end
  local classID, subClassID, _, equipLoc = C_Item.GetItemInfoInstant(item)
  if not classID then
    self:RequestItemData(item)
    return false
  end

  local classRestriction = self:GetItemClassRestrictions(item)
  if classRestriction then
    return classRestriction[classFile] == true
  end

  if classID == ITEM_CLASS_ARMOR then
    if subClassID == ARMOR_TRINKET or subClassID == ARMOR_RING or subClassID == ARMOR_NECK then
      return true
    end
    local allowed = ARMOR_BY_CLASS[classFile]
    if allowed and Contains(allowed, subClassID) then
      return true
    end
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(item)
    local fallbackSub = itemSubType and ARMOR_SUBCLASS_BY_NAME[itemSubType]
    return allowed and fallbackSub and Contains(allowed, fallbackSub) or false
  end

  if classID == ITEM_CLASS_WEAPON then
    local allowed = WEAPON_BY_CLASS[classFile]
    return allowed and Contains(allowed, subClassID)
  end

  return false
end
