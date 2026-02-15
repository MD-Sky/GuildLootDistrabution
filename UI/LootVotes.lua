local _, NS = ...
local GLD = NS.GLD
local UI = NS.UI
local LiveProvider = NS.LiveProvider
local TestProvider = NS.TestProvider
local AceGUI = LibStub and LibStub("AceGUI-3.0", true) or nil

local WINDOW_WIDTH = 440
local WINDOW_HEIGHT = 480
local ACTIVE_PANEL_HEIGHT = 170
local PADDING = 10
local PENDING_ROW_HEIGHT = 56
local ROW_SPACING = 4
local MAX_MISSING_DISPLAY = 5
local TOOLTIP_CURSOR_OFFSET = 20
local PENDING_BORDER_ACTIVE = { 1, 0.82, 0, 1 }
local PENDING_BORDER_DEFAULT = { 0.3, 0.3, 0.3, 0.9 }
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PREVIEW_CONFIRM_POPUP_KEY = "GLD_ADMIN_TEST_CONFIRM_OBTAINED"

local function AdminTestLog(message)
  if GLD and GLD.Debug then
    GLD:Debug("[AdminTest] " .. tostring(message))
  end
end

local TRINKET_ROLE_LABELS = {
  TANK = "Tanks",
  HEALER = "Healers",
  MELEEDPS = "Melee DPS",
  RANGEDPS = "Ranged DPS",
  DPS = "DPS",
}

local TRINKET_ROLE_ORDER = { "TANK", "HEALER", "MELEEDPS", "RANGEDPS", "DPS" }

local function FormatTrinketRoleList(roles)
  if type(roles) ~= "table" then
    return nil
  end
  local list = {}
  for _, key in ipairs(TRINKET_ROLE_ORDER) do
    if roles[key] then
      list[#list + 1] = TRINKET_ROLE_LABELS[key] or key
    end
  end
  if #list == 0 then
    return nil
  end
  return table.concat(list, ", ")
end

local function FormatVoteLabel(vote)
  if not vote or vote == "" then
    return "None"
  end
  local label = tostring(vote)
  return label:sub(1, 1) .. label:sub(2):lower()
end

local function GetDisplayedItemText(session)
  if not session then
    return "Unknown Item"
  end
  local link = session.itemLink
  if link and link ~= "" then
    local name = select(1, GetItemInfo(link))
    if name and name ~= "" then
      return name
    end
  end
  if session.itemName and session.itemName ~= "" then
    return session.itemName
  end
  if link and link ~= "" then
    return link
  end
  return "Unknown Item"
end

local function GetVoteProvider(session)
  if session and session.isTest then
    return TestProvider or LiveProvider
  end
  return LiveProvider
end

local function GetSessionStatus(session)
  if not session then
    return "CLOSED"
  end
  if GLD and GLD.GetRollStatus then
    return GLD:GetRollStatus(session)
  end
  if session.status then
    return tostring(session.status):upper()
  end
  return session.locked and "CLOSED" or "ACTIVE"
end

local function CanonicalizeVoteKey(key)
  if not key then
    return nil
  end
  if GLD and GLD.GetRollCandidateKey then
    return GLD:GetRollCandidateKey(key) or key
  end
  return key
end

local function StripRealmForDisplay(name)
  if not name or name == "" then
    return name
  end
  if type(name) == "string" and name:match("^Player%-") then
    return name
  end
  if NS and NS.GetPlayerBaseName then
    return NS:GetPlayerBaseName(name) or name
  end
  local base = tostring(name):match("^([^%-]+)")
  return base or name
end

local function GetVoterDisplayName(provider, key)
  if not key then
    return nil
  end
  local name = provider and provider.GetPlayerName and provider:GetPlayerName(key) or key
  if type(name) == "string" and name:match("^Player%-") then
    return name
  end
  local isGuest = false
  local player = provider and provider.GetPlayer and provider:GetPlayer(key) or nil
  if player and GLD and GLD.IsGuestEntry then
    isGuest = GLD:IsGuestEntry(player)
  end
  if NS and NS.GetPlayerDisplayName then
    return NS:GetPlayerDisplayName(name, isGuest)
  end
  return StripRealmForDisplay(name)
end

local function GetClassColorCode(classToken)
  if not classToken then
    return nil
  end
  local color = nil
  if C_ClassColor and C_ClassColor.GetClassColor then
    color = C_ClassColor.GetClassColor(classToken)
  elseif RAID_CLASS_COLORS then
    color = RAID_CLASS_COLORS[classToken]
  end
  if color and color.r then
    local r = math.floor((color.r or 1) * 255)
    local g = math.floor((color.g or 1) * 255)
    local b = math.floor((color.b or 1) * 255)
    return string.format("|cff%02x%02x%02x", r, g, b)
  end
  return nil
end

local function GetColoredVoterName(provider, key, classHint)
  if not key then
    return nil
  end
  local displayName = GetVoterDisplayName(provider, key) or key
  local player = provider and provider.GetPlayer and provider:GetPlayer(key)
  local classToken = player and (player.class or player.classToken)
  if not classToken and classHint then
    classToken = classHint[key]
  end
  local colorCode = GetClassColorCode(classToken)
  if colorCode then
    return colorCode .. displayName .. "|r"
  end
  return displayName
end

local function FormatMissingDisplayText(missingNames)
  if not missingNames or #missingNames == 0 then
    return ""
  end
  local chunk = math.min(MAX_MISSING_DISPLAY, #missingNames)
  local displayed = {}
  for i = 1, chunk do
    displayed[#displayed + 1] = missingNames[i]
  end
  local text = table.concat(displayed, ", ")
  if #missingNames > MAX_MISSING_DISPLAY then
    text = text .. " +" .. (#missingNames - MAX_MISSING_DISPLAY) .. " more"
  end
  return text
end

local function AdjustPendingRowHeight(row)
  if not row then
    return
  end
  local minHeight = PENDING_ROW_HEIGHT
  local textHeight = row.statusText:GetStringHeight() or 0
  local padding = 30
  local newHeight = math.max(minHeight, textHeight + padding)
  row:SetHeight(newHeight)
end

local function DebugPendingRow(session, hasLocalVoted, missingNames, displayText)
  if not GLD:IsDebugEnabled() then
    return
  end
  local key = session and (session.rollKey or session.rollID or session.key or session.itemLink or session.itemName) or "unknown"
  local missingSummary = ""
  if missingNames and #missingNames > 0 then
    missingSummary = table.concat(missingNames, ", ")
  else
    missingSummary = "none"
  end
  GLD:Debug(
    string.format(
      "Pending row [%s]: localVoted=%s missing=%s text=%s",
      tostring(key),
      tostring(hasLocalVoted),
      missingSummary,
      tostring(displayText)
    )
  )
end

local function GetLootWindowState(self)
  self.lootVoteState = self.lootVoteState or {
    currentVoteItems = {},
    indexByKey = {},
    activeKey = nil,
    activeIndex = nil,
    demoMode = false,
    demoItems = {},
    demoVotes = {},
    previewMode = "member",
    previewAuthority = nil,
    previewPugMode = false,
  }
  return self.lootVoteState
end

local function IsAdminPreview(state)
  return state and state.demoMode and state.previewAuthority == "admin"
end

local function GetPreviewParticipantMeta(session, key)
  if not session or type(session.previewParticipants) ~= "table" or not key then
    return nil
  end
  return session.previewParticipants[key]
end

local function IsPreviewNoAddonParticipant(session, key)
  local meta = GetPreviewParticipantMeta(session, key)
  return meta and meta.isNoAddon == true
end

local function GetPreviewParticipantLabel(session, key, fallback)
  local meta = GetPreviewParticipantMeta(session, key)
  if meta and type(meta.label) == "string" and meta.label ~= "" then
    return meta.label
  end
  return fallback
end

local function NormalizeSessionKey(session, key)
  if not key then
    return nil
  end
  if GetPreviewParticipantMeta(session, key) then
    return key
  end
  return CanonicalizeVoteKey(key)
end

local function BuildMissingVoteKeys(session, votes, opts)
  local missing = {}
  if not session then
    return missing
  end
  opts = opts or {}
  local includeNoAddon = opts.includeNoAddon ~= false
  votes = votes or session.votes or {}
  local expected = session.expectedVoters or {}
  local voted = {}
  for key in pairs(votes) do
    local canon = NormalizeSessionKey(session, key)
    if canon then
      voted[canon] = true
    end
  end
  for _, key in ipairs(expected) do
    local canon = NormalizeSessionKey(session, key)
    if canon and not voted[canon] then
      if includeNoAddon or not IsPreviewNoAddonParticipant(session, canon) then
        missing[#missing + 1] = canon
      end
    end
  end
  return missing
end

local function BuildMissingVoterDisplay(session, votes, opts)
  local missing = {}
  if not session then
    return missing
  end
  opts = opts or {}
  local includeNoAddon = opts.includeNoAddon ~= false
  local expected = session.expectedVoters or {}
  local classHint = session.expectedVoterClasses
  local provider = GetVoteProvider(session)
  local voted = {}
  for key in pairs(votes or {}) do
    local canon = NormalizeSessionKey(session, key)
    if canon then
      voted[canon] = true
    end
  end
  for _, key in ipairs(expected) do
    local canon = NormalizeSessionKey(session, key)
    if canon and not voted[canon] then
      local isNoAddon = IsPreviewNoAddonParticipant(session, canon)
      if includeNoAddon or not isNoAddon then
        if isNoAddon then
          missing[#missing + 1] = GetPreviewParticipantLabel(session, canon, "pug")
        else
          missing[#missing + 1] = GetColoredVoterName(provider, canon, classHint) or canon
        end
      end
    end
  end
  return missing
end

local function IsPreviewPugWaitingForNoAddon(session)
  return session and session.previewPugMode == true and session.obtainedConfirmed ~= true
end

local function IsPreviewConfirmAllowed(state, session)
  if not IsAdminPreview(state) or not session then
    return false
  end
  if session.previewPugMode == true then
    return session.obtainedConfirmed ~= true
  end
  return session.isPugRun == true
end

local function GetPreviewWinnerName(session)
  if not session then
    return nil
  end
  if session.previewWinnerName and session.previewWinnerName ~= "" then
    return session.previewWinnerName
  end
  return session.winnerName or session.computedWinnerGuid
end

local function GetPreviewMissingKeys(session, votes)
  local includeNoAddon = IsPreviewPugWaitingForNoAddon(session)
  if session and session.previewPugMode == true then
    return BuildMissingVoteKeys(session, votes, { includeNoAddon = includeNoAddon })
  end
  return BuildMissingVoteKeys(session, votes)
end

local function GetPreviewMissingAddonDisplay(session, votes)
  return BuildMissingVoterDisplay(session, votes, { includeNoAddon = false })
end

local function GetPreviewMissingDisplay(session, votes)
  if session and session.previewPugMode == true then
    return BuildMissingVoterDisplay(session, votes, {
      includeNoAddon = IsPreviewPugWaitingForNoAddon(session),
    })
  end
  return BuildMissingVoterDisplay(session, votes, { includeNoAddon = true })
end

local function BuildForceVoteCandidates(session, votes)
  local pendingKeys = BuildMissingVoteKeys(session, votes, { includeNoAddon = false })
  local provider = GetVoteProvider(session)
  local values = {}
  local order = {}
  for _, key in ipairs(pendingKeys) do
    if values[key] == nil then
      values[key] = GetVoterDisplayName(provider, key) or key
      order[#order + 1] = key
    end
  end
  return order, values
end

local function CountPreviewDismissedMissing(session, missingKeys)
  if not session or type(session.previewDismissedCandidates) ~= "table" then
    return 0
  end
  local count = 0
  for _, key in ipairs(missingKeys or {}) do
    if session.previewDismissedCandidates[key] then
      count = count + 1
    end
  end
  return count
end

local function ApplyPreviewForcePending(self, state, entry)
  if not entry or not entry.session then
    return
  end
  local session = entry.session
  local votes = {}
  if session.votes then
    for k, v in pairs(session.votes) do
      local canon = NormalizeSessionKey(session, k)
      if canon and votes[canon] == nil then
        votes[canon] = v
      end
    end
  end
  if state and state.demoMode and state.demoVotes and entry.key then
    local localKey = NS:GetPlayerKeyFromUnit("player")
    if localKey and state.demoVotes[entry.key] then
      votes[localKey] = state.demoVotes[entry.key]
    end
  end
  local missingKeys = GetPreviewMissingKeys(session, votes)
  session.previewDismissedCandidates = session.previewDismissedCandidates or {}
  local affected = 0
  for _, key in ipairs(missingKeys) do
    if session.previewDismissedCandidates[key] then
      session.previewDismissedCandidates[key] = nil
      affected = affected + 1
    end
  end
  if affected == 0 then
    affected = #missingKeys
  end
  session.previewForcePendingAt = GetServerTime()
  local itemId = session.rollKey or session.rollID or entry.key or "unknown"
  AdminTestLog("ForcePending item=" .. tostring(itemId) .. " affected=" .. tostring(affected))
  local ok, err = pcall(function()
    self:RefreshLootWindow({
      forceShow = true,
      forceDemo = true,
      activeKey = entry.key,
    })
  end)
  if not ok and GLD and GLD.Print then
    GLD:Print("Preview force pending refresh failed: " .. tostring(err))
  end
end

local function IsLootGateActive()
  if not GLD then
    return false
  end
  local enabled = GLD.IsEnabled and GLD:IsEnabled()
  local active = GLD.IsSessionActive and GLD:IsSessionActive()
  return enabled and active
end

local function GetActiveVoteSessions()
  local sessions = {}
  if not IsLootGateActive() then
    return sessions
  end
  if not GLD.activeRolls then
    return sessions
  end
  for _, session in pairs(GLD.activeRolls) do
    local status = GetSessionStatus(session)
    if session and (status == "ACTIVE" or status == "PENDING_APPROVAL") then
      sessions[#sessions + 1] = session
    end
  end
  table.sort(sessions, function(a, b)
    return (a.createdAt or 0) < (b.createdAt or 0)
  end)
  return sessions
end

local function GetSessionByKey(itemKey)
  if not itemKey or not GLD.activeRolls then
    return nil
  end
  for _, session in pairs(GLD.activeRolls) do
    if session then
      local key = session.rollKey or session.rollID or session.key or session.itemLink or session.itemName
      if key == itemKey then
        return session
      end
    end
  end
  return nil
end

local function BuildSessionVoteSnapshot(session, state, entryKey)
  local votes = {}
  if session and session.votes then
    for k, v in pairs(session.votes) do
      local canon = NormalizeSessionKey(session, k)
      if canon and votes[canon] == nil then
        votes[canon] = v
      end
    end
  end
  if state and state.demoMode and state.demoVotes and entryKey then
    local localKey = NS:GetPlayerKeyFromUnit("player")
    if localKey and state.demoVotes[entryKey] then
      votes[localKey] = state.demoVotes[entryKey]
    end
  end
  return votes
end

if _G and _G.BuildSessionVoteSnapshot == nil then
  _G.BuildSessionVoteSnapshot = BuildSessionVoteSnapshot
end

local function BuildVoteEntries(self, sessions)
  local state = GetLootWindowState(self)
  state.currentVoteItems = {}
  state.indexByKey = {}
  for idx, session in ipairs(sessions or {}) do
    local key = session.rollKey
      or session.rollID
      or session.key
      or session.itemLink
      or (session.itemName and session.itemName .. "_" .. idx)
      or ("pending_" .. idx)
    local vote = nil
    if state.demoMode then
      vote = state.demoVotes and state.demoVotes[key]
    else
      local votes = BuildSessionVoteSnapshot(session, state, key)
      local myKey = NS:GetPlayerKeyFromUnit("player")
      vote = myKey and votes and votes[myKey] or nil
    end
    state.currentVoteItems[idx] = {
      key = key,
      session = session,
      vote = vote,
    }
    state.indexByKey[key] = idx
  end
end


local function HasLocalPlayerVotedSession(session, votes)
  if not session then
    return false
  end
  local localKey = NS:GetPlayerKeyFromUnit("player")
  if not localKey then
    return false
  end
  votes = votes or BuildSessionVoteSnapshot(session)
  return votes[localKey] ~= nil
end

local function HasUnvotedEntries(state, entries)
  if state and state.demoMode then
    return false
  end
  for _, entry in ipairs(entries or {}) do
    if entry and entry.session and GetSessionStatus(entry.session) == "ACTIVE" and not entry.vote then
      return true
    end
  end
  return false
end

local function HasBlockingVotes(self)
  local state = GetLootWindowState(self)
  if state and state.demoMode then
    return false
  end
  local localKey = NS:GetPlayerKeyFromUnit("player")
  if not localKey then
    return false
  end
  local sessions = GetActiveVoteSessions()
  for _, session in ipairs(sessions) do
    if session and GetSessionStatus(session) == "ACTIVE" then
      local votes = BuildSessionVoteSnapshot(session)
      if votes[localKey] == nil then
        return true
      end
    end
  end
  return false
end

local function GetMissingVotersForSession(session, votes, opts)
  if not session then
    return {}
  end
  return BuildMissingVoterDisplay(session, votes or session.votes or {}, opts)
end

local function IsGuidKey(key)
  return type(key) == "string" and key:find("^Player%-") ~= nil
end

local function FormatNameRealm(name, realm)
  if not name or name == "" then
    return nil
  end
  if realm and realm ~= "" then
    return tostring(name) .. "-" .. tostring(realm)
  end
  return tostring(name)
end

local function SplitKeyIdentity(key)
  if type(key) ~= "string" or key == "" then
    return nil, nil, nil
  end
  if IsGuidKey(key) then
    return key, nil, nil
  end
  if NS and NS.SplitNameRealm then
    local name, realm = NS:SplitNameRealm(key)
    if name and name ~= "" then
      return nil, name, realm
    end
  end
  return nil, key, nil
end

local function BuildDebugListFromArray(list, limit)
  local out = {}
  local max = math.min(limit or 12, #list)
  for i = 1, max do
    out[#out + 1] = tostring(list[i])
  end
  if #list > max then
    out[#out + 1] = "...+" .. tostring(#list - max)
  end
  return table.concat(out, ", ")
end

local function BuildDebugListFromMap(map, limit, includeValues)
  local out = {}
  local count = 0
  for key, value in pairs(map or {}) do
    count = count + 1
    if #out < (limit or 12) then
      if includeValues then
        out[#out + 1] = tostring(key) .. "=" .. tostring(value)
      else
        out[#out + 1] = tostring(key)
      end
    end
  end
  if count > (limit or 12) then
    out[#out + 1] = "...+" .. tostring(count - (limit or 12))
  end
  return table.concat(out, ", "), count
end

local function ResolveGuestAnchorCandidateKey(session, provider, rawKey, canonicalKey)
  if not (GLD and GLD.FindApprovedGuestEntry) then
    return nil, nil
  end
  local guid, name, realm = SplitKeyIdentity(rawKey)
  if not guid and not name then
    guid, name, realm = SplitKeyIdentity(canonicalKey)
  end
  local lookupKeys = { canonicalKey, rawKey }
  for _, key in ipairs(lookupKeys) do
    if provider and provider.GetPlayer and key then
      local player = provider:GetPlayer(key)
      if player then
        if not guid and player.guid and player.guid ~= "" then
          guid = player.guid
        end
        if not name and player.name and player.name ~= "" then
          name = player.name
        end
        if not realm and player.realm and player.realm ~= "" then
          realm = player.realm
        end
      end
    end
  end
  local approvedEntry, approvedKey = GLD:FindApprovedGuestEntry(guid, name, realm)
  return approvedKey, approvedEntry
end

local function BuildOverrideCandidateLabel(provider, key, fallbackName, isGuest)
  local display = GetVoterDisplayName(provider, key)
  local hasDisplay = type(display) == "string" and display ~= "" and display ~= tostring(key)
  if hasDisplay and isGuest ~= true then
    return display
  end
  local name = fallbackName
  if (not name or name == "") and provider and provider.GetPlayerName then
    name = provider:GetPlayerName(key)
  end
  if not name or name == "" or name == key then
    name = tostring(key)
  end
  if NS and NS.GetPlayerDisplayName then
    return NS:GetPlayerDisplayName(name, isGuest == true)
  end
  if isGuest then
    return tostring(StripRealmForDisplay(name) or name) .. " - Guest"
  end
  return StripRealmForDisplay(name) or name
end

local function BuildAdminOverrideCandidates(session)
  local keys = {}
  local labels = {}
  if not session then
    return keys, labels
  end

  local provider = GetVoteProvider(session)
  local expected = session.expectedVoters or {}
  local votes = session.votes or {}
  local voteDetails = session.voteDetails or {}
  local approvedGuests = GLD and GLD.db and GLD.db.approvedGuests or nil
  local debugEnabled = GLD and GLD.IsDebugEnabled and GLD:IsDebugEnabled() or false
  local rollRef = session.rollID or session.rollKey or "unknown"
  local itemRef = session.itemLink or session.itemID or session.itemName or "unknown"

  if debugEnabled then
    local expectedText = BuildDebugListFromArray(expected, 20)
    local voteText, voteCount = BuildDebugListFromMap(votes, 20, true)
    local detailText, detailCount = BuildDebugListFromMap(voteDetails, 20, false)
    local approvedText, approvedCount = BuildDebugListFromMap(approvedGuests or {}, 20, false)
    GLD:Debug("Admin override candidate build: rollID=" .. tostring(rollRef) .. " item=" .. tostring(itemRef))
    GLD:Debug("Admin override source expectedVoters(" .. tostring(#expected) .. "): " .. tostring(expectedText))
    GLD:Debug("Admin override source votes(" .. tostring(voteCount) .. "): " .. tostring(voteText))
    GLD:Debug("Admin override source voteDetails(" .. tostring(detailCount) .. "): " .. tostring(detailText))
    GLD:Debug("Admin override source approvedGuests(" .. tostring(approvedCount) .. "): " .. tostring(approvedText))
  end

  local added = {}
  local expectedIdentity = {}
  for _, key in ipairs(expected) do
    if key then
      expectedIdentity[key] = true
      local canon = NormalizeSessionKey(session, key) or CanonicalizeVoteKey(key)
      if canon then
        expectedIdentity[canon] = true
      end
    end
  end

  local function addCandidate(rawKey, sourceTag)
    if not rawKey or rawKey == "" then
      if debugEnabled then
        GLD:Debug("Admin override candidate filtered: source=" .. tostring(sourceTag) .. " raw=nil reason=empty_key")
      end
      return
    end

    local canonical = NormalizeSessionKey(session, rawKey) or CanonicalizeVoteKey(rawKey) or rawKey
    if not canonical or canonical == "" then
      if debugEnabled then
        GLD:Debug(
          "Admin override candidate filtered: source="
            .. tostring(sourceTag)
            .. " raw="
            .. tostring(rawKey)
            .. " reason=canonicalize_failed"
        )
      end
      return
    end

    local guestKey, guestEntry = ResolveGuestAnchorCandidateKey(session, provider, rawKey, canonical)
    local resolvedKey = guestKey or canonical
    if GLD and GLD.GetRollCandidateKey then
      resolvedKey = GLD:GetRollCandidateKey(resolvedKey) or resolvedKey
    end
    if not resolvedKey or resolvedKey == "" then
      if debugEnabled then
        GLD:Debug(
          "Admin override candidate filtered: source="
            .. tostring(sourceTag)
            .. " raw="
            .. tostring(rawKey)
            .. " canonical="
            .. tostring(canonical)
            .. " reason=resolved_key_missing"
        )
      end
      return
    end

    if added[resolvedKey] then
      if debugEnabled then
        GLD:Debug(
          "Admin override candidate filtered: source="
            .. tostring(sourceTag)
            .. " raw="
            .. tostring(rawKey)
            .. " canonical="
            .. tostring(canonical)
            .. " resolved="
            .. tostring(resolvedKey)
            .. " reason=duplicate"
        )
      end
      return
    end

    local player = provider and provider.GetPlayer and (provider:GetPlayer(resolvedKey) or provider:GetPlayer(canonical)) or nil
    local isGuest = false
    if player and GLD and GLD.IsGuestEntry then
      isGuest = GLD:IsGuestEntry(player)
    end
    if not isGuest and GLD and GLD.IsApprovedGuestKey then
      isGuest = GLD:IsApprovedGuestKey(resolvedKey)
    end
    if not isGuest and guestKey then
      isGuest = true
    end

    local fallbackName = nil
    if player then
      fallbackName = FormatNameRealm(player.name, player.realm)
    elseif guestEntry then
      fallbackName = FormatNameRealm(guestEntry.name, guestEntry.realm)
    end

    local label = BuildOverrideCandidateLabel(provider, resolvedKey, fallbackName, isGuest)
    keys[#keys + 1] = resolvedKey
    labels[#labels + 1] = label
    added[resolvedKey] = true

    if debugEnabled then
      local guid, name, realm = SplitKeyIdentity(resolvedKey)
      if guestEntry then
        if not guid and guestEntry.guid and guestEntry.guid ~= "" then
          guid = guestEntry.guid
        end
        if not name and guestEntry.name and guestEntry.name ~= "" then
          name = guestEntry.name
        end
        if not realm and guestEntry.realm and guestEntry.realm ~= "" then
          realm = guestEntry.realm
        end
      end
      GLD:Debug(
        "Admin override candidate added: source="
          .. tostring(sourceTag)
          .. " raw="
          .. tostring(rawKey)
          .. " canonical="
          .. tostring(canonical)
          .. " resolved="
          .. tostring(resolvedKey)
          .. " name="
          .. tostring(name or (player and player.name) or fallbackName or "")
          .. " guid="
          .. tostring(guid or (player and player.guid) or "")
          .. " guest="
          .. tostring(isGuest)
          .. " voted="
          .. tostring(votes[resolvedKey] ~= nil or votes[canonical] ~= nil)
      )
    end
  end

  for _, key in ipairs(expected) do
    addCandidate(key, "expectedVoters")
  end
  for key in pairs(votes) do
    addCandidate(key, "votes")
  end
  for key in pairs(voteDetails) do
    addCandidate(key, "voteDetails")
  end

  for guestKey, guestEntry in pairs(approvedGuests or {}) do
    if type(guestEntry) == "table" then
      local guestGuid = guestEntry.guid
      local guestFull = FormatNameRealm(guestEntry.name, guestEntry.realm)
      if expectedIdentity[guestKey] or (guestGuid and expectedIdentity[guestGuid]) or (guestFull and expectedIdentity[guestFull]) then
        addCandidate(guestKey, "approvedGuests")
      elseif debugEnabled then
        GLD:Debug(
          "Admin override candidate filtered: source=approvedGuests raw="
            .. tostring(guestKey)
            .. " reason=not_in_roll_participants"
        )
      end
    elseif debugEnabled then
      GLD:Debug(
        "Admin override candidate filtered: source=approvedGuests raw="
          .. tostring(guestKey)
          .. " reason=invalid_entry"
      )
    end
  end

  if debugEnabled then
    local preview = BuildDebugListFromArray(labels, 12)
    GLD:Debug(
      "Admin override candidate build complete: rollID="
        .. tostring(rollRef)
        .. " total="
        .. tostring(#keys)
        .. " candidates="
        .. tostring(preview)
    )
  end

  return keys, labels
end

local function EnsurePreviewConfirmPopup()
  if not StaticPopupDialogs or StaticPopupDialogs[PREVIEW_CONFIRM_POPUP_KEY] then
    return
  end
  StaticPopupDialogs[PREVIEW_CONFIRM_POPUP_KEY] = {
    text = "Mark item as obtained?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, data)
      local uiRef = data and data.ui
      local session = data and data.session
      if not uiRef or not session then
        return
      end
      session.obtainedConfirmed = true
      session.previewObtained = true
      local winner = GetPreviewWinnerName(session) or "Unknown"
      session.computedWinnerGuid = session.computedWinnerGuid or winner
      session.winnerName = session.winnerName or winner
      local itemId = session.rollKey or session.rollID or session.itemLink or session.itemName or "unknown"
      AdminTestLog("ConfirmObtained item=" .. tostring(itemId) .. " winner=" .. tostring(winner))
      local ok, err = pcall(function()
        uiRef:RefreshLootWindow({
          forceShow = true,
          forceDemo = true,
          activeKey = data.entryKey,
        })
      end)
      if not ok and GLD and GLD.Print then
        GLD:Print("Preview confirm refresh failed: " .. tostring(err))
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
end

local function ShowPreviewForceVotePopup(self, state, session, entryKey)
  if not AceGUI then
    if GLD and GLD.Print then
      GLD:Print("Preview force vote unavailable (AceGUI missing).")
    end
    return
  end
  local votes = BuildSessionVoteSnapshot(session, state, entryKey)
  local candidateOrder, candidateValues = BuildForceVoteCandidates(session, votes)
  if #candidateOrder == 0 then
    if GLD and GLD.Print then
      GLD:Print("No pending voters left to force in preview.")
    end
    return
  end

  if self.previewForceVoteFrame then
    self.previewForceVoteFrame:Release()
    self.previewForceVoteFrame = nil
  end

  local provider = GetVoteProvider(session)

  local voteValues = {
    NEED = "Need",
    GREED = "Greed",
    TRANSMOG = "Transmog",
    PASS = "Pass",
  }
  local voteOrder = { "NEED", "GREED", "TRANSMOG", "PASS" }

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Preview Force Vote")
  frame:SetStatusText("Admin test only")
  frame:SetWidth(360)
  frame:SetHeight(210)
  frame:SetLayout("Flow")
  frame:EnableResize(false)
  frame:SetCallback("OnClose", function(widget)
    if self.previewForceVoteFrame == widget then
      self.previewForceVoteFrame = nil
    end
  end)

  local candidateDropdown = AceGUI:Create("Dropdown")
  candidateDropdown:SetLabel("Candidate")
  candidateDropdown:SetFullWidth(true)
  frame:AddChild(candidateDropdown)

  local voteDropdown = AceGUI:Create("Dropdown")
  voteDropdown:SetLabel("Vote")
  voteDropdown:SetFullWidth(true)
  voteDropdown:SetList(voteValues, voteOrder)
  voteDropdown:SetValue("NEED")
  frame:AddChild(voteDropdown)

  local applyBtn = nil
  local function refreshCandidates()
    local snapshot = BuildSessionVoteSnapshot(session, state, entryKey)
    local order, values = BuildForceVoteCandidates(session, snapshot)
    candidateDropdown:SetList(values, order)
    if #order == 0 then
      candidateDropdown:SetValue(nil)
      applyBtn:SetDisabled(true)
      frame:SetStatusText("No pending addon voters for this item.")
      return false
    end
    local current = candidateDropdown:GetValue()
    if not current or values[current] == nil then
      candidateDropdown:SetValue(order[1])
    end
    applyBtn:SetDisabled(false)
    frame:SetStatusText("Admin test only")
    return true
  end

  applyBtn = AceGUI:Create("Button")
  applyBtn:SetText("Apply (Preview)")
  applyBtn:SetWidth(140)
  applyBtn:SetCallback("OnClick", function()
    local key = candidateDropdown:GetValue()
    local vote = voteDropdown:GetValue()
    if not key or not vote then
      return
    end
    session.votes = session.votes or {}
    session.votes[key] = vote
    if session.previewDismissedCandidates then
      session.previewDismissedCandidates[key] = nil
    end
    local itemId = session.rollKey or session.rollID or entryKey or "unknown"
    local voterName = GetVoterDisplayName(provider, key) or tostring(key)
    AdminTestLog("ForceVote item=" .. tostring(itemId) .. " voter=" .. tostring(voterName) .. " choice=" .. tostring(vote))
    local ok, err = pcall(function()
      self:RefreshLootWindow({
        forceShow = true,
        forceDemo = true,
        activeKey = entryKey,
      })
    end)
    if not ok and GLD and GLD.Print then
      GLD:Print("Preview force vote refresh failed: " .. tostring(err))
    end
    refreshCandidates()
  end)
  frame:AddChild(applyBtn)

  local cancelBtn = AceGUI:Create("Button")
  cancelBtn:SetText("Cancel")
  cancelBtn:SetWidth(100)
  cancelBtn:SetCallback("OnClick", function()
    frame:Release()
    if self.previewForceVoteFrame == frame then
      self.previewForceVoteFrame = nil
    end
  end)
  frame:AddChild(cancelBtn)

  refreshCandidates()
  self.previewForceVoteFrame = frame
end

function UI:GetMissingVotersForItem(itemKey)
  local session = GetSessionByKey(itemKey)
  local votes = session and session.votes or nil
  return GetMissingVotersForSession(session, votes)
end

function UI:HasLocalPlayerVoted(itemKey)
  local session = GetSessionByKey(itemKey)
  return HasLocalPlayerVotedSession(session, nil)
end

local function GetNextUnvotedItemIndex(self, startIndex)
  local state = GetLootWindowState(self)
  local entries = state.currentVoteItems or {}
  local start = math.max(startIndex or 1, 1)
  for i = start, #entries do
    if not entries[i].vote then
      return i
    end
  end
  return nil
end

local function CreatePendingRow(self, window)
  local row = CreateFrame("Frame", nil, window.pendingScrollChild, "BackdropTemplate")
  row:SetHeight(PENDING_ROW_HEIGHT)
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints(row)
  row.bg:SetColorTexture(0, 0, 0, 0)
  row.bg:Hide()

  row:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 4,
    edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  row:SetBackdropColor(0, 0, 0, 0)
  row:SetBackdropBorderColor(unpack(PENDING_BORDER_DEFAULT))

  row.hoverHighlight = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.hoverHighlight:SetAllPoints(row)
  row.hoverHighlight:SetColorTexture(0.18, 0.18, 0.18, 0.65)
  row.hoverHighlight:Hide()

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(24, 24)
  row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
  row.icon:SetTexture(DEFAULT_ICON)

  row.itemText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.itemText:SetWidth(160)
  row.itemText:SetJustifyH("LEFT")

  row.statusText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.statusText:SetPoint("TOPLEFT", row.itemText, "TOPRIGHT", 8, -4)
  row.statusText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -4)
  row.statusText:SetJustifyH("LEFT")
  row.statusText:SetJustifyV("TOP")
  row.statusText:SetWordWrap(true)
  row.statusText:SetWidth(220)
  row.missingTooltipText = nil

  local function AnchorPendingTooltip()
    GameTooltip:ClearAllPoints()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local uiX = cursorX / scale
    local uiY = cursorY / scale
    local offset = TOOLTIP_CURSOR_OFFSET
    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or nil
    if issecretvalue and issecretvalue(parentWidth) then
      parentWidth = nil
    end
    local tooltipWidth = GameTooltip and GameTooltip.GetWidth and GameTooltip:GetWidth() or nil
    if issecretvalue and issecretvalue(tooltipWidth) then
      tooltipWidth = nil
    end
    if type(tooltipWidth) ~= "number" or tooltipWidth <= 0 then
      tooltipWidth = 220
    end
    local point = "BOTTOMLEFT"
    local anchorX = uiX + offset
    if type(parentWidth) == "number" and parentWidth > 0 and anchorX + tooltipWidth > parentWidth then
      point = "BOTTOMRIGHT"
      anchorX = uiX - offset
    end
    GameTooltip:SetPoint(point, UIParent, "BOTTOMLEFT", anchorX, uiY)
  end

  local function showPendingTooltip(widget)
    local link = row.itemLink
    GameTooltip:SetOwner(row.icon, "ANCHOR_NONE")
    if link and link ~= "" then
      GameTooltip:SetHyperlink(link)
    else
      GameTooltip:SetText(row.itemText:GetText() or "Pending roll")
    end
    if row.missingTooltipText and row.missingTooltipText ~= "" then
      GameTooltip:AddLine("Missing voters:", 1, 0.8, 0, true)
      GameTooltip:AddLine(row.missingTooltipText, 1, 1, 1, true)
    end
    AnchorPendingTooltip()
    GameTooltip:Show()
  end
  local function hidePendingTooltip()
    GameTooltip:Hide()
  end
  local function focusEntry()
    local key = row.entryKey
    if key and self.RefreshLootWindow then
      self:RefreshLootWindow({ activeKey = key })
    end
  end

  row:EnableMouse(true)
  row.icon:EnableMouse(false)
  row.itemText:EnableMouse(false)

  -- make the clickable region span the icon and the item text at the icon's height
  local hitArea = CreateFrame("Button", nil, row)
  hitArea:SetPoint("LEFT", row.icon, "LEFT", 0, 0)
  hitArea:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  hitArea:SetPoint("TOP", row, "TOP", 0, 0)
  hitArea:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
  hitArea:RegisterForClicks("LeftButtonUp")
  hitArea:SetScript("OnEnter", function(widget)
    showPendingTooltip(widget)
    row.hoverHighlight:Show()
  end)
  hitArea:SetScript("OnLeave", function()
    hidePendingTooltip()
    row.hoverHighlight:Hide()
  end)
  hitArea:SetScript("OnClick", focusEntry)
  row.hitArea = hitArea

  return row
end

local function EnsureLootWindow(self)
  local window = self.lootVoteWindow or {}
  if window.frame then
    return window
  end

  local frame = CreateFrame("Frame", "GLDLootVoteWindow", UIParent, "BackdropTemplate")
  frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
  local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
  local centerOffset = -(parentWidth > 0 and parentWidth * 0.25 or 200)
  frame:SetPoint("CENTER", UIParent, "CENTER", centerOffset, 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("HIGH")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
  title:SetText("Loot Votes")

  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
  closeButton:SetScript("OnClick", function()
    if HasBlockingVotes(self) then
      if GLD and GLD.Print then
        GLD:Print("You must vote or pass before closing.")
      end
      if frame.Raise then
        frame:Raise()
      end
      return
    end
    frame:Hide()
  end)
  frame:SetScript("OnHide", function()
    local state = GetLootWindowState(self)
    state.demoMode = false
    state.previewMode = "member"
    state.previewAuthority = nil
    state.previewPugMode = false
    if GLD and GLD.MarkLocalVoteDismissed then
      for _, entry in ipairs(state.currentVoteItems or {}) do
        local session = entry and entry.session
        if session then
          local votes = BuildSessionVoteSnapshot(session, state, entry.key)
          if not HasLocalPlayerVotedSession(session, votes) then
            GLD:MarkLocalVoteDismissed(session)
          end
        end
      end
    end
    if HasBlockingVotes(self) then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
          if frame and not frame:IsShown() then
            frame:Show()
            if frame.Raise then
              frame:Raise()
            end
          end
        end)
      end
    end
    if self.previewForceVoteFrame then
      self.previewForceVoteFrame:Release()
      self.previewForceVoteFrame = nil
    end
  end)

  local activePanel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
  activePanel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -38)
  activePanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -38)
  activePanel:SetHeight(ACTIVE_PANEL_HEIGHT)

  local activeTitle = activePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  activeTitle:SetPoint("TOPLEFT", activePanel, "TOPLEFT", 8, -6)
  activeTitle:SetText("Active Vote")

  local adminOverrideButton = CreateFrame("Button", nil, activePanel, "UIPanelButtonTemplate")
  adminOverrideButton:SetSize(120, 18)
  adminOverrideButton:SetText("Admin Override")
  adminOverrideButton:SetPoint("TOPRIGHT", activePanel, "TOPRIGHT", -8, -4)
  adminOverrideButton:SetScript("OnClick", function()
    local state = GetLootWindowState(self)
    local entry = state.currentVoteItems[state.activeIndex]
    local session = entry and entry.session
    if not session then
      return
    end
    if IsAdminPreview(state) then
      local ok, err = pcall(ShowPreviewForceVotePopup, self, state, session, entry.key)
      if not ok and GLD and GLD.Print then
        GLD:Print("Preview force vote failed: " .. tostring(err))
      end
      return
    end
    if not GLD:IsAuthority() then
      GLD:Print("Only the authority can apply overrides.")
      return
    end
    local keys, labels = BuildAdminOverrideCandidates(session)
    UI:ShowAdminVotePopup(session, keys, labels)
  end)
  adminOverrideButton:Hide()

  local forcePendingButton = CreateFrame("Button", nil, activePanel, "UIPanelButtonTemplate")
  forcePendingButton:SetSize(120, 18)
  forcePendingButton:SetText("Force Pending")
  forcePendingButton:SetPoint("TOPRIGHT", adminOverrideButton, "TOPLEFT", -6, 0)
  forcePendingButton:SetScript("OnClick", function()
    local state = GetLootWindowState(self)
    local entry = state.currentVoteItems[state.activeIndex]
    if IsAdminPreview(state) then
      local ok, err = pcall(ApplyPreviewForcePending, self, state, entry)
      if not ok and GLD and GLD.Print then
        GLD:Print("Preview force pending failed: " .. tostring(err))
      end
      return
    end
    if not GLD:IsAuthority() then
      GLD:Print("Only the authority can force pending windows.")
      return
    end
    if GLD.ForcePendingVotesWindow then
      GLD:ForcePendingVotesWindow()
    end
  end)
  forcePendingButton:Hide()

  local confirmObtainedButton = CreateFrame("Button", nil, activePanel, "UIPanelButtonTemplate")
  confirmObtainedButton:SetSize(120, 18)
  confirmObtainedButton:SetText("Confirm Obtained")
  confirmObtainedButton:SetPoint("TOPRIGHT", activePanel, "TOPRIGHT", -8, -24)
  confirmObtainedButton:SetScript("OnClick", function()
    local state = GetLootWindowState(self)
    local entry = state.currentVoteItems[state.activeIndex]
    local session = entry and entry.session
    if not session then
      return
    end
    if IsAdminPreview(state) then
      local ok, err = pcall(function()
        EnsurePreviewConfirmPopup()
        StaticPopup_Show(PREVIEW_CONFIRM_POPUP_KEY, nil, nil, {
          ui = self,
          session = session,
          entryKey = entry.key,
        })
      end)
      if not ok and GLD and GLD.Print then
        GLD:Print("Preview confirm prompt failed: " .. tostring(err))
      end
      return
    end
    if GLD and GLD.ConfirmPendingRoll then
      GLD:ConfirmPendingRoll(session.rollKey or session.rollID, session.computedWinnerGuid)
    end
  end)
  confirmObtainedButton:Hide()

  local markLostButton = CreateFrame("Button", nil, activePanel, "UIPanelButtonTemplate")
  markLostButton:SetSize(120, 18)
  markLostButton:SetText("Mark Lost")
  markLostButton:SetPoint("TOPRIGHT", confirmObtainedButton, "TOPLEFT", -6, 0)
  markLostButton:SetScript("OnClick", function()
    local state = GetLootWindowState(self)
    local entry = state.currentVoteItems[state.activeIndex]
    local session = entry and entry.session
    if not session then
      return
    end
    if IsAdminPreview(state) then
      session.previewMarkedLost = not session.previewMarkedLost
      AdminTestLog("Preview action: MarkLost winner=" .. tostring(session.winnerName or session.computedWinnerGuid or "Unknown"))
      local ok, err = pcall(function()
        self:RefreshLootWindow({
          forceShow = true,
          forceDemo = true,
          activeKey = entry.key,
        })
      end)
      if not ok and GLD and GLD.Print then
        GLD:Print("Preview mark-lost refresh failed: " .. tostring(err))
      end
      return
    end
    if GLD and GLD.MarkPendingRollLost then
      GLD:MarkPendingRollLost(session.rollKey or session.rollID)
    end
  end)
  markLostButton:Hide()

  local activeIcon = activePanel:CreateTexture(nil, "ARTWORK")
  activeIcon:SetSize(36, 36)
  activeIcon:SetPoint("TOPLEFT", activeTitle, "BOTTOMLEFT", 0, -6)
  activeIcon:SetTexture(DEFAULT_ICON)

  local activeItemLabel = activePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  activeItemLabel:SetPoint("LEFT", activeIcon, "RIGHT", 6, 0)
  activeItemLabel:SetPoint("RIGHT", activePanel, "RIGHT", -8, 0)
  activeItemLabel:SetJustifyH("LEFT")
  activeItemLabel:SetJustifyV("TOP")
  activeItemLabel:SetText("No active loot roll.")

  local function showActiveTooltip(widget)
    local link = activeItemLabel.link
    if link and link ~= "" then
      GameTooltip:SetOwner(widget, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end
  local function hideActiveTooltip()
    GameTooltip:Hide()
  end

  activeIcon:EnableMouse(true)
  activeIcon:SetScript("OnEnter", showActiveTooltip)
  activeIcon:SetScript("OnLeave", hideActiveTooltip)
  activeItemLabel:EnableMouse(true)
  activeItemLabel:SetScript("OnEnter", showActiveTooltip)
  activeItemLabel:SetScript("OnLeave", hideActiveTooltip)

  local statusLabel = activePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  statusLabel:SetPoint("TOPLEFT", activeIcon, "BOTTOMLEFT", 0, -6)
  statusLabel:SetPoint("RIGHT", activePanel, "RIGHT", -8, 0)
  statusLabel:SetJustifyH("LEFT")
  statusLabel:SetJustifyV("TOP")
  statusLabel:SetWordWrap(true)
  statusLabel:SetText("Loot votes will appear when items drop.")

  local votedLabel = activePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  votedLabel:SetPoint("CENTER", activePanel, "CENTER", 0, -6)
  votedLabel:SetText("")
  votedLabel:Hide()

  local buttonRow = CreateFrame("Frame", nil, activePanel)
  buttonRow:SetPoint("BOTTOMLEFT", activePanel, "BOTTOMLEFT", 6, 6)
  buttonRow:SetPoint("BOTTOMRIGHT", activePanel, "BOTTOMRIGHT", -6, 6)
  buttonRow:SetHeight(28)

  local voteButtons = {}
  local function createVoteButton(text, key, anchorPoint, relativeTo, relPoint, offsetX, offsetY)
    local button = CreateFrame("Button", nil, activePanel, "UIPanelButtonTemplate")
    button:SetSize(104, 24)
    button:SetText(text)
    button:SetPoint(anchorPoint, relativeTo, relPoint, offsetX, offsetY)
    button:SetScript("OnClick", function()
      UI:HandleLootVote(key)
    end)
    voteButtons[key] = button
    return button
  end

  local needButton = createVoteButton("Need", "NEED", "BOTTOMLEFT", buttonRow, "BOTTOMLEFT", 0, 0)
  local greedButton = createVoteButton("Greed", "GREED", "BOTTOMRIGHT", buttonRow, "BOTTOMRIGHT", 0, 0)
  local transmogButton = createVoteButton("Transmog", "TRANSMOG", "BOTTOMLEFT", needButton, "TOPLEFT", 0, 4)
  local passButton = createVoteButton("Pass", "PASS", "BOTTOMRIGHT", greedButton, "TOPRIGHT", 0, 4)

  local pendingPanel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
  pendingPanel:SetPoint("TOPLEFT", activePanel, "BOTTOMLEFT", 0, -PADDING)
  pendingPanel:SetPoint("TOPRIGHT", activePanel, "BOTTOMRIGHT", 0, -PADDING)
  pendingPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING, 8)
  pendingPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, 8)

  local pendingTitle = pendingPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  pendingTitle:SetPoint("TOPLEFT", pendingPanel, "TOPLEFT", 8, -6)
  pendingTitle:SetText("Pending Votes")

  local pendingScroll = CreateFrame("ScrollFrame", nil, pendingPanel, "UIPanelScrollFrameTemplate")
  pendingScroll:SetPoint("TOPLEFT", pendingPanel, "TOPLEFT", 6, -24)
  pendingScroll:SetPoint("BOTTOMRIGHT", pendingPanel, "BOTTOMRIGHT", -28, 6)
  local pendingScrollChild = CreateFrame("Frame", nil, pendingScroll)
  pendingScrollChild:SetSize(1, 1)
  pendingScroll:SetScrollChild(pendingScrollChild)

  local pendingEmpty = pendingPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  pendingEmpty:SetPoint("TOPLEFT", pendingPanel, "TOPLEFT", 8, -28)
  pendingEmpty:SetText("No active loot votes.")
  pendingEmpty:Hide()

  window.frame = frame
  window.titleLabel = title
  window.closeButton = closeButton
  window.activePanel = activePanel
  window.activeIcon = activeIcon
  window.activeItemLabel = activeItemLabel
  window.activeStatusLabel = statusLabel
  window.activeMessageLabel = votedLabel
  window.adminOverrideButton = adminOverrideButton
  window.forcePendingButton = forcePendingButton
  window.confirmObtainedButton = confirmObtainedButton
  window.markLostButton = markLostButton
  window.buttonRow = buttonRow
  window.needButton = needButton
  window.greedButton = greedButton
  window.transmogButton = transmogButton
  window.passButton = passButton
  window.voteButtons = voteButtons
  window.pendingPanel = pendingPanel
  window.pendingScroll = pendingScroll
  window.pendingScrollChild = pendingScrollChild
  window.pendingRows = {}
  window.pendingEmptyLabel = pendingEmpty
  self.lootVoteWindow = window

  return window
end

local function ShouldPromptPendingSessions(self, state, sessions, options)
  local trigger = options and options.trigger or "auto"
  local now = GetServerTime()
  local playerName = GLD and GLD.GetUnitFullName and GLD:GetUnitFullName("player") or UnitName("player") or "player"
  local shouldShow = false
  for _, session in ipairs(sessions or {}) do
    local status = GetSessionStatus(session)
    local votes = BuildSessionVoteSnapshot(session, state)
    local hasVoted = HasLocalPlayerVotedSession(session, votes)
    local voteState = GLD and GLD.GetLocalVoteState and GLD:GetLocalVoteState(session) or nil
    local dismissed = voteState and voteState.dismissedWithoutVote or false
    local lastPromptedAt = voteState and voteState.lastPromptedAt or nil
    local action = "SKIP"
    if status == "PENDING_APPROVAL" then
      action = "SHOW"
      shouldShow = true
    elseif not hasVoted then
      if trigger == "force" then
        action = "SHOW"
        shouldShow = true
      elseif not lastPromptedAt or dismissed then
        action = "SHOW"
        shouldShow = true
      end
    end
    if action == "SHOW" and voteState then
      voteState.lastPromptedAt = now
      voteState.dismissedWithoutVote = false
    end
    if GLD and GLD.LilyDebug then
      GLD:LilyDebug(
        string.format(
          "[VOTE] ForcePendingCheck player=%s hasVoted=%s dismissed=%s action=%s",
          tostring(playerName),
          tostring(hasVoted),
          tostring(dismissed),
          tostring(action)
        )
      )
    end
  end
  return shouldShow
end

local function UpdateVoteButtons(window, session, alreadyVoted)
  local sessionStatus = GetSessionStatus(session)
  local votingOpen = sessionStatus == "ACTIVE"
  local localKey = NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
  local eligibility = { NEED = true, GREED = true, TRANSMOG = true, PASS = true }
  local reasons = { NEED = nil, GREED = nil, TRANSMOG = nil, PASS = nil }
  if session and votingOpen and GLD and GLD.GetEligibilityForVote then
    eligibility.NEED, reasons.NEED = GLD:GetEligibilityForVote(session, localKey, "NEED", { log = true, requireData = true })
    eligibility.GREED, reasons.GREED = GLD:GetEligibilityForVote(session, localKey, "GREED", { log = true })
    eligibility.TRANSMOG, reasons.TRANSMOG = GLD:GetEligibilityForVote(session, localKey, "TRANSMOG", { log = true })
  end
  local reasonTexts = {}
  if GLD and GLD.GetEligibilityReasonText then
    for voteType, reason in pairs(reasons) do
      if reason then
        reasonTexts[voteType] = GLD:GetEligibilityReasonText(reason, session)
      end
    end
  end
  window.needDisabledReasonText = eligibility.NEED == false and reasonTexts.NEED or nil

  local debugEnabled = GLD and GLD.IsDebugEnabled and GLD:IsDebugEnabled()
  if debugEnabled and session then
    local provider = session.isTest and TestProvider or LiveProvider
    local player = provider and provider.GetPlayer and provider:GetPlayer(localKey) or nil
    local classFile = player and (player.classFile or player.classFileName or player.classToken or player.class) or nil
    local specName = player and (player.specName or player.spec) or nil
    local roleKey = (GLD and GLD.GetTrinketRoleKey and classFile) and GLD:GetTrinketRoleKey(classFile, specName) or nil
    local name = provider and provider.GetPlayerName and provider:GetPlayerName(localKey) or localKey or "Unknown"
    local snapshot = session.restrictionSnapshot
    local roleText = snapshot and FormatTrinketRoleList(snapshot.trinketRoles) or "none"
    GLD:Debug(
      "Vote UI refresh: player="
        .. tostring(name)
        .. " class="
        .. tostring(classFile)
        .. " spec="
        .. tostring(specName)
        .. " role="
        .. tostring(roleKey)
    )
    GLD:Debug(
      "Vote UI snapshot: trinketRoles="
        .. tostring(roleText)
        .. " itemId="
        .. tostring(snapshot and snapshot.itemId or session.itemID)
    )
  end

  for vote, button in pairs(window.voteButtons or {}) do
    if not button or not button.SetEnabled then
      -- skip invalid button
    else
      local allow = not alreadyVoted
      if not votingOpen then
        allow = false
      end
      if session and eligibility[vote] == false then
        allow = false
      end
      button:SetEnabled(allow)
      button:SetAlpha(allow and 1 or 0.45)
      if not allow and not alreadyVoted then
        button.gldDisabledReason = reasonTexts[vote]
      else
        button.gldDisabledReason = nil
      end
      if not button.gldTooltipHooked then
        button.gldTooltipHooked = true
        button:SetScript("OnEnter", function(selfBtn)
          if selfBtn.gldDisabledReason then
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:SetText(selfBtn.gldDisabledReason, 1, 0.8, 0, 1, true)
            GameTooltip:Show()
          end
        end)
        button:SetScript("OnLeave", function()
          GameTooltip:Hide()
        end)
      end
      if debugEnabled then
        GLD:Debug(
          "Vote UI button: vote="
            .. tostring(vote)
            .. " enabled="
            .. tostring(allow)
            .. (button.gldDisabledReason and (" reason=" .. tostring(button.gldDisabledReason)) or "")
        )
      end
    end
  end
end

local function UpdateActivePanel(self, state, window)
  local index = state.activeIndex
  local entry = state.currentVoteItems[index]
  local session = entry and entry.session or nil
  local status = GetSessionStatus(session)
  local isPendingApproval = status == "PENDING_APPROVAL"
  local previewAdmin = IsAdminPreview(state)
  local previewPugMode = previewAdmin and session and session.previewPugMode == true
  local liveAuthority = not state.demoMode and GLD.IsAuthority and GLD:IsAuthority()
  local showOverride = entry and status == "ACTIVE" and (previewAdmin or liveAuthority)
  local showForce = entry and status == "ACTIVE" and (previewAdmin or (liveAuthority and IsInRaid()))
  local showPendingActions = entry and ((previewAdmin and IsPreviewConfirmAllowed(state, session))
    or (isPendingApproval and not state.demoMode and GLD.CanAccessAdminUI and GLD:CanAccessAdminUI()))
  if window.adminOverrideButton then
    if previewAdmin then
      window.adminOverrideButton:SetText("Force Vote")
    else
      window.adminOverrideButton:SetText("Admin Override")
    end
    window.adminOverrideButton:SetShown(showOverride)
    window.adminOverrideButton:SetEnabled(showOverride)
  end
  if window.forcePendingButton then
    window.forcePendingButton:SetText("Force Pending")
    window.forcePendingButton:SetShown(showForce)
    window.forcePendingButton:SetEnabled(showForce)
  end
  if window.confirmObtainedButton then
    if previewAdmin and session and session.obtainedConfirmed then
      window.confirmObtainedButton:SetText("Obtained Confirmed")
    else
      window.confirmObtainedButton:SetText("Confirm Obtained")
    end
    window.confirmObtainedButton:SetShown(showPendingActions)
    window.confirmObtainedButton:SetEnabled(showPendingActions and (not previewPugMode or session.obtainedConfirmed ~= true))
  end
  if window.markLostButton then
    local showMarkLost = showPendingActions and not previewPugMode
    window.markLostButton:SetShown(showMarkLost)
    window.markLostButton:SetEnabled(showMarkLost)
  end
  if not entry then
    window.activeItemLabel:SetText("No active loot roll.")
    window.activeItemLabel.link = nil
    window.activeIcon:SetTexture(DEFAULT_ICON)
    window.activeStatusLabel:SetText("Loot votes will appear when items drop.")
    window.activeMessageLabel:Hide()
    UpdateVoteButtons(window, nil, true)
    return
  end

  local link = session and session.itemLink or nil
  local text = GetDisplayedItemText(session)
  window.activeItemLabel:SetText(text or "Unknown Item")
  window.activeItemLabel.link = link
  local icon = DEFAULT_ICON
  if link then
    local itemIcon = select(10, GetItemInfo(link))
    if itemIcon then
      icon = itemIcon
    elseif session and session.itemIcon then
      icon = session.itemIcon
    else
      GLD:RequestItemData(link)
    end
  elseif session and session.itemIcon then
    icon = session.itemIcon
  end
  window.activeIcon:SetTexture(icon)

  local alreadyVoted = entry.vote and entry.vote ~= ""
  if isPendingApproval then
    UpdateVoteButtons(window, session, true)
    local winnerName = GetPreviewWinnerName(session) or "Unknown"
    if previewPugMode and session.obtainedConfirmed ~= true then
      window.activeStatusLabel:SetText("Preview pug mode: waiting for obtained confirmation.")
      window.activeMessageLabel:SetText("No-addon participants pending. Click Confirm Obtained to resolve pugs.")
    elseif previewPugMode and session.obtainedConfirmed == true then
      window.activeStatusLabel:SetText("Winner confirmed: " .. tostring(winnerName))
      window.activeMessageLabel:SetText("Waiting for addon votes only.")
    else
      local winnerRef = session and (session.computedWinnerGuid or (session.computedResult and session.computedResult.winnerKey)) or nil
      local provider = GetVoteProvider(session)
      local displayWinner = winnerRef and GetVoterDisplayName(provider, winnerRef) or "Unknown"
      if not winnerRef then
        displayWinner = "No computed winner"
      end
      window.activeStatusLabel:SetText("Pending admin approval. Computed winner: " .. tostring(displayWinner))
      if showPendingActions then
        if previewAdmin and session and session.previewMarkedLost then
          window.activeMessageLabel:SetText("Preview: item marked lost.")
        else
          window.activeMessageLabel:SetText("Confirm obtained (guild/guest only) or mark item lost.")
        end
      else
        window.activeMessageLabel:SetText("Waiting for admin confirmation.")
      end
    end
    window.activeMessageLabel:Show()
  elseif alreadyVoted then
    UpdateVoteButtons(window, session, alreadyVoted)
    local voteText = FormatVoteLabel(entry.vote)
    window.activeStatusLabel:SetText("Vote submitted: " .. voteText .. ". Waiting for results.")
    window.activeMessageLabel:SetText("Voted - waiting for winner")
    window.activeMessageLabel:Show()
  else
    UpdateVoteButtons(window, session, alreadyVoted)
    if previewAdmin then
      local votes = BuildSessionVoteSnapshot(session, state, entry.key)
      local missingKeys = GetPreviewMissingKeys(session, votes)
      local dismissedCount = CountPreviewDismissedMissing(session, missingKeys)
      if previewPugMode and session.obtainedConfirmed == true then
        local addonMissing = GetPreviewMissingAddonDisplay(session, votes)
        local addonText = FormatMissingDisplayText(addonMissing)
        window.activeStatusLabel:SetText("Winner: " .. tostring(GetPreviewWinnerName(session) or "Unknown"))
        if addonText ~= "" then
          window.activeMessageLabel:SetText("Waiting for addon votes: " .. tostring(addonText))
        else
          window.activeMessageLabel:SetText("Winner resolved and all addon votes present.")
        end
        window.activeMessageLabel:Show()
      elseif dismissedCount > 0 then
        window.activeStatusLabel:SetText("Declare your intent here. Buttons remain enabled until you vote.")
        window.activeMessageLabel:SetText("Preview: " .. tostring(dismissedCount) .. " pending voters dismissed; use Force Pending.")
        window.activeMessageLabel:Show()
      elseif window.needDisabledReasonText then
        window.activeStatusLabel:SetText("Declare your intent here. Buttons remain enabled until you vote.")
        window.activeMessageLabel:SetText("Need disabled: " .. tostring(window.needDisabledReasonText))
        window.activeMessageLabel:Show()
      else
        window.activeStatusLabel:SetText("Declare your intent here. Buttons remain enabled until you vote.")
        window.activeMessageLabel:Hide()
      end
    elseif window.needDisabledReasonText then
      window.activeStatusLabel:SetText("Declare your intent here. Buttons remain enabled until you vote.")
      window.activeMessageLabel:SetText("Need disabled: " .. tostring(window.needDisabledReasonText))
      window.activeMessageLabel:Show()
    else
      window.activeStatusLabel:SetText("Declare your intent here. Buttons remain enabled until you vote.")
      window.activeMessageLabel:Hide()
    end
  end
end

local function UpdatePendingRows(self, state, window)
  local entries = state.currentVoteItems
  local rows = window.pendingRows
  local yOffset = 0
  local spacing = ROW_SPACING
  local scrollWidth = 0
  if window.pendingScroll and window.pendingScroll.GetWidth then
    scrollWidth = window.pendingScroll:GetWidth() or 0
  end
  if scrollWidth <= 1 then
    local fallbackWidth = window.pendingPanel and window.pendingPanel.GetWidth and window.pendingPanel:GetWidth() or 0
    if fallbackWidth <= 1 and window.frame and window.frame.GetWidth then
      fallbackWidth = window.frame:GetWidth() or 0
    end
    if fallbackWidth > 1 then
      scrollWidth = math.max(fallbackWidth - 34, 1)
    else
      scrollWidth = 1
    end
    if not state.pendingWidthRetry and C_Timer and C_Timer.After then
      state.pendingWidthRetry = true
      C_Timer.After(0, function()
        state.pendingWidthRetry = false
        if UI and UI.RefreshLootWindow then
          UI:RefreshLootWindow()
        end
      end)
    end
  end
  local childWidth = math.max(scrollWidth, 1)
  window.pendingScrollChild:SetWidth(childWidth)
  for idx, entry in ipairs(entries) do
    local row = rows[idx]
    if not row then
      row = CreatePendingRow(self, window)
      rows[idx] = row
    end
    row.entryKey = entry.key
    local session = entry.session
    local link = session and session.itemLink or nil
    row.itemLink = link
    row.itemText:SetText(GetDisplayedItemText(session))
    local statusWidth = math.max(80, childWidth - 200)
    row.statusText:SetWidth(statusWidth)
    row.itemText:SetWidth(math.max(100, childWidth - statusWidth - 60))
    local entryKey = entry.key
    local votes = BuildSessionVoteSnapshot(session, state, entryKey)
    local previewPugMode = IsAdminPreview(state) and session and session.previewPugMode == true
    local missingNames = GetPreviewMissingDisplay(session, votes)
    local addonMissingNames = GetPreviewMissingAddonDisplay(session, votes)
    local hasLocalVoted = HasLocalPlayerVotedSession(session, votes)
    local status = GetSessionStatus(session)
    row.missingTooltipText = (#missingNames > 0) and table.concat(missingNames, "\n") or nil

    local displayText = ""
    if previewPugMode then
      row.statusText:SetFontObject(GameFontHighlightSmall)
      row.statusText:SetTextColor(0.9, 0.9, 0.9)
      if session.obtainedConfirmed == true then
        local winner = GetPreviewWinnerName(session) or "Unknown"
        local addonMissingText = FormatMissingDisplayText(addonMissingNames)
        if addonMissingText == "" then
          displayText = "Winner: " .. tostring(winner) .. " | Waiting for addon votes: none"
        else
          displayText = "Winner: " .. tostring(winner) .. " | Waiting for addon votes: " .. addonMissingText
        end
      else
        local missingText = FormatMissingDisplayText(missingNames)
        if missingText == "" then
          displayText = "Waiting for votes"
        else
          displayText = "Waiting for votes: " .. missingText
        end
      end
    elseif status == "PENDING_APPROVAL" then
      row.statusText:SetFontObject(GameFontHighlightSmall)
      row.statusText:SetTextColor(1, 0.82, 0.2)
      local winnerRef = session and (session.computedWinnerGuid or (session.computedResult and session.computedResult.winnerKey)) or nil
      local provider = GetVoteProvider(session)
      local winnerName = winnerRef and GetVoterDisplayName(provider, winnerRef) or "Unknown"
      displayText = "Pending admin approval"
      if winnerRef then
        displayText = displayText .. ": " .. tostring(winnerName)
      end
    elseif not hasLocalVoted then
      row.statusText:SetFontObject(GameFontNormalLarge)
      row.statusText:SetTextColor(0.2, 1, 0.2)
      displayText = "Waiting for your Vote"
    else
      row.statusText:SetFontObject(GameFontHighlightSmall)
      row.statusText:SetTextColor(0.9, 0.9, 0.9)
      local missingText = FormatMissingDisplayText(missingNames)
      if missingText == "" then
        displayText = "Waiting for votes"
      else
        displayText = "Waiting for votes: " .. missingText
      end
    end
    row.statusText:SetText(displayText)
    DebugPendingRow(session, hasLocalVoted, missingNames, displayText)

    AdjustPendingRowHeight(row)

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", window.pendingScrollChild, "TOPLEFT", 0, -yOffset)
    row:SetPoint("RIGHT", window.pendingScrollChild, "RIGHT", -4, 0)
    row:SetWidth(math.max(1, childWidth - 4))
    yOffset = yOffset + row:GetHeight() + spacing

    local icon = DEFAULT_ICON
    if link then
      local itemIcon = select(10, GetItemInfo(link))
      if itemIcon then
        icon = itemIcon
      elseif session and session.itemIcon then
        icon = session.itemIcon
      else
        GLD:RequestItemData(link)
      end
    elseif session and session.itemIcon then
      icon = session.itemIcon
    end
    row.icon:SetTexture(icon)
    if entry.key == state.activeKey then
      row:SetBackdropBorderColor(unpack(PENDING_BORDER_ACTIVE))
    else
      row:SetBackdropBorderColor(unpack(PENDING_BORDER_DEFAULT))
    end
    row.bg:SetShown(entry.key == state.activeKey)
    row:Show()
  end
  -- Removed the OnEnter/Leave scripts that previously covered the whole row to limit tooltip activation
  for i = #entries + 1, #rows do
    rows[i]:Hide()
  end
  local height = math.max(yOffset + spacing, PENDING_ROW_HEIGHT)
  window.pendingScrollChild:SetHeight(height)
  window.pendingScroll:UpdateScrollChildRect()
  window.pendingEmptyLabel:SetShown(#entries == 0)
end

local function UpdateLootWindowContent(self, state, window)
  if window and window.titleLabel then
    if state and state.demoMode then
      if IsAdminPreview(state) then
        local modeText = state.previewPugMode and "Pug Mode" or "Guild Mode"
        window.titleLabel:SetText("[PREVIEW] Admin Pending Window (" .. modeText .. ")")
      else
        window.titleLabel:SetText("[PREVIEW] Loot Votes (Member)")
      end
    else
      window.titleLabel:SetText("Loot Votes")
    end
  end
  UpdateActivePanel(self, state, window)
  UpdatePendingRows(self, state, window)
end

local function UpdateActiveSelection(self, state, options)
  local entries = state.currentVoteItems or {}
  if #entries == 0 then
    state.activeIndex = nil
    state.activeKey = nil
    return
  end
  if options and options.activeKey then
    local idx = state.indexByKey[options.activeKey]
    if idx then
      if options.advance then
        local start = idx + 1
        local nextIndex = GetNextUnvotedItemIndex(self, start)
        if not nextIndex then
          nextIndex = GetNextUnvotedItemIndex(self, 1)
        end
        if nextIndex then
          state.activeIndex = nextIndex
          state.activeKey = entries[nextIndex].key
          return
        end
      else
        state.activeIndex = idx
        state.activeKey = options.activeKey
        return
      end
    end
  end
  if state.activeKey then
    local idx = state.indexByKey[state.activeKey]
    if idx then
      state.activeIndex = idx
      return
    end
  end
  state.activeIndex = 1
  state.activeKey = entries[1].key
end

function UI:RefreshLootWindow(options)
  options = options or {}
  local state = GetLootWindowState(self)
  if not state.demoMode and not IsLootGateActive() then
    state.currentVoteItems = {}
    state.indexByKey = {}
    state.activeKey = nil
    state.activeIndex = nil
    if self.lootVoteWindow and self.lootVoteWindow.frame then
      self.lootVoteWindow.frame:Hide()
    end
    return
  end
  local sessions = GetActiveVoteSessions()
  local displaySessions = state.demoMode and (state.demoItems or {}) or sessions
  BuildVoteEntries(self, displaySessions)
  UpdateActiveSelection(self, state, options)
  local sessionActive = nil
  local sessionSource = "unknown"
  if GLD.IsAuthority and GLD:IsAuthority() then
    sessionActive = GLD.db and GLD.db.session and GLD.db.session.active
    sessionSource = "authority-db"
  elseif GLD.shadow and GLD.shadow.sessionActive ~= nil then
    sessionActive = GLD.shadow.sessionActive
    sessionSource = "shadow"
  else
    sessionActive = GLD.db and GLD.db.session and GLD.db.session.active
    sessionSource = "db"
  end
  local inRaid = IsInRaid()
  local shouldShow = options.forceShow
    or state.demoMode
    or (inRaid and #sessions > 0)
  local window = EnsureLootWindow(self)
  if options.onlyIfPending and not state.demoMode then
    local alreadyShown = window and window.frame and window.frame.IsShown and window.frame:IsShown()
    if not alreadyShown then
      shouldShow = shouldShow and ShouldPromptPendingSessions(self, state, sessions, options)
    end
  end
  local blockClose = HasUnvotedEntries(state, state.currentVoteItems)
  if window.closeButton and window.closeButton.SetEnabled then
    window.closeButton:SetEnabled(not blockClose)
  end
  if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
    GLD:Debug(
      "Loot window refresh: sessions="
        .. tostring(#sessions)
        .. " shouldShow="
        .. tostring(shouldShow)
        .. " inRaid="
        .. tostring(inRaid)
        .. " sessionActive="
        .. tostring(sessionActive)
        .. " source="
        .. tostring(sessionSource)
        .. " blockClose="
        .. tostring(blockClose)
    )
  end
  if shouldShow and #state.currentVoteItems == 0 then
    state.activeKey = nil
    state.activeIndex = nil
  end
  if shouldShow then
    if UI and UI.mainFrame and UI.mainFrame.IsShown and UI.mainFrame:IsShown() then
      UI.mainFrame:Hide()
    end
    window.frame:Show()
    if window.frame.Raise and (options.forceShow or options.reopen) then
      window.frame:Raise()
    end
    UpdateLootWindowContent(self, state, window)
    if not state.demoMode and GLD and GLD.ReapplyCoverBlockersForActiveRolls then
      GLD:ReapplyCoverBlockersForActiveRolls("ui_refresh", true)
    end
    if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
      GLD:Debug("Loot window shown: items=" .. tostring(#state.currentVoteItems))
    end
  else
    window.frame:Hide()
    if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
      GLD:Debug("Loot window hidden.")
    end
  end
end

function UI:CloseLootSessionWindows(reason)
  local state = GetLootWindowState(self)
  state.currentVoteItems = {}
  state.indexByKey = {}
  state.activeKey = nil
  state.activeIndex = nil
  state.demoMode = false
  state.demoItems = {}
  state.demoVotes = {}
  state.previewMode = "member"
  state.previewAuthority = nil
  state.previewPugMode = false
  if self.lootVoteWindow and self.lootVoteWindow.frame then
    self.lootVoteWindow.frame:Hide()
  end
  if self.rollFrames then
    for key, frame in pairs(self.rollFrames) do
      if frame then
        if frame.Release then
          frame:Release()
        elseif frame.Hide then
          frame:Hide()
        end
      end
      self.rollFrames[key] = nil
    end
  end
  if self.demoWinnerNotice and self.demoWinnerNotice.Hide then
    self.demoWinnerNotice:Hide()
  end
  if self.previewForceVoteFrame then
    self.previewForceVoteFrame:Release()
    self.previewForceVoteFrame = nil
  end
  if GLD and GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
    GLD:Debug("Loot session windows closed: reason=" .. tostring(reason))
  end
end

local function BuildExamplePreviewData(mode, pugMode)
  local previewMode = (mode == "admin") and "admin" or "member"
  local previewPugMode = previewMode == "admin" and pugMode == true
  local items = {}

  if previewMode == "admin" and previewPugMode then
    items = {
      {
        rollID = "demo-loot-a",
        rollKey = "demo-loot-a@demo",
        itemLink = "item:237728",
        itemName = "Voidglass Kris",
        itemTexture = "Interface\\Icons\\INV_Knife_1H_BFA_Dungeon_C_01",
        itemLevel = 639,
        itemSlot = "One-Hand Dagger",
        canNeed = true,
        canGreed = true,
        canTransmog = true,
        isTest = true,
        status = "ACTIVE",
        isPugRun = true,
        previewPugMode = true,
        previewWinnerName = "Steph",
        obtainedConfirmed = false,
        expectedVoters = { "pug-1", "pug-2", "Alex", "Lily", "Rob", "Steph" },
        expectedVoterClasses = {
          Lily = "DRUID",
          Rob = "SHAMAN",
          Steph = "HUNTER",
          Alex = "WARLOCK",
        },
        previewParticipants = {
          ["pug-1"] = { isNoAddon = true, label = "pug" },
          ["pug-2"] = { isNoAddon = true, label = "pug" },
          Alex = { isAddon = true, label = "Alex" },
          Lily = { isAddon = true, label = "Lily" },
          Rob = { isAddon = true, label = "Rob" },
          Steph = { isAddon = true, label = "Steph" },
        },
        votes = {
          Lily = "NEED",
          Rob = "GREED",
          Steph = "NEED",
        },
        previewDismissedCandidates = {
          Alex = true,
          ["pug-1"] = true,
          ["pug-2"] = true,
        },
      },
      {
        rollID = "demo-loot-b",
        rollKey = "demo-loot-b@demo",
        itemLink = "item:244234",
        itemName = "Astral Gladiator's Prestigious Cloak",
        itemTexture = "Interface\\Icons\\INV_Cape_01",
        itemLevel = 639,
        itemSlot = "Back",
        canNeed = true,
        canGreed = true,
        canTransmog = true,
        isTest = true,
        status = "ACTIVE",
        expectedVoters = { "Lily", "Rob", "Alex" },
        expectedVoterClasses = {
          Lily = "DRUID",
          Rob = "SHAMAN",
          Alex = "WARLOCK",
        },
        previewParticipants = {
          Lily = { isAddon = true, label = "Lily" },
          Rob = { isAddon = true, label = "Rob" },
          Alex = { isAddon = true, label = "Alex" },
        },
        votes = {
          Lily = "GREED",
        },
      },
    }
  elseif previewMode == "admin" then
    items = {
      {
        rollID = "demo-loot-a",
        rollKey = "demo-loot-a@demo",
        itemLink = "item:237728",
        itemName = "Voidglass Kris",
        itemTexture = "Interface\\Icons\\INV_Knife_1H_BFA_Dungeon_C_01",
        itemLevel = 639,
        itemSlot = "One-Hand Dagger",
        canNeed = true,
        canGreed = true,
        canTransmog = true,
        isTest = true,
        status = "ACTIVE",
        expectedVoters = { "Lily", "Rob", "Steph", "Alex" },
        expectedVoterClasses = {
          Lily = "DRUID",
          Rob = "SHAMAN",
          Steph = "HUNTER",
          Alex = "WARLOCK",
        },
        previewParticipants = {
          Lily = { isAddon = true, label = "Lily" },
          Rob = { isAddon = true, label = "Rob" },
          Steph = { isAddon = true, label = "Steph" },
          Alex = { isAddon = true, label = "Alex" },
        },
        votes = {
          Lily = "NEED",
        },
      },
      {
        rollID = "demo-loot-b",
        rollKey = "demo-loot-b@demo",
        itemLink = "item:244234",
        itemName = "Astral Gladiator's Prestigious Cloak",
        itemTexture = "Interface\\Icons\\INV_Cape_01",
        itemLevel = 639,
        itemSlot = "Back",
        canNeed = true,
        canGreed = true,
        canTransmog = true,
        isTest = true,
        status = "ACTIVE",
        expectedVoters = { "Ryan", "Vulthan", "Mira" },
        expectedVoterClasses = {
          Ryan = "DEATHKNIGHT",
          Vulthan = "WARRIOR",
          Mira = "MAGE",
        },
        previewParticipants = {
          Ryan = { isAddon = true, label = "Ryan" },
          Vulthan = { isAddon = true, label = "Vulthan" },
          Mira = { isAddon = true, label = "Mira" },
        },
        votes = {
          Ryan = "GREED",
        },
      },
    }
  else
    items = {
      {
        rollID = "demo-loot-a",
        rollKey = "demo-loot-a@demo",
        itemLink = "item:237728",
        itemName = "Voidglass Kris",
        canNeed = true,
        canGreed = true,
        canTransmog = true,
        isTest = true,
        status = "ACTIVE",
        expectedVoters = { "Lily", "Rob", "Steph", "Alex" },
        expectedVoterClasses = {
          Lily = "DRUID",
          Rob = "SHAMAN",
          Steph = "HUNTER",
          Alex = "WARLOCK",
        },
        votes = {
          Lily = "NEED",
          Rob = "GREED",
        },
      },
      {
        rollID = "demo-loot-b",
        rollKey = "demo-loot-b@demo",
        itemLink = "item:244234",
        itemName = "Astral Gladiator's Prestigious Cloak",
        canNeed = true,
        canGreed = true,
        canTransmog = true,
        isTest = true,
        status = "ACTIVE",
        expectedVoters = { "Lily" },
        expectedVoterClasses = {
          Lily = "DRUID",
        },
        votes = {},
      },
    }
  end

  local demoVotes = {}
  if previewMode ~= "admin" then
    demoVotes["demo-loot-a@demo"] = "NEED"
  end

  return {
    previewMode = previewMode,
    previewAuthority = previewMode == "admin" and "admin" or "member",
    previewPugMode = previewPugMode,
    demoItems = items,
    demoVotes = demoVotes,
  }
end

function UI:ShowLootWindowDemo(mode, options)
  if type(mode) == "table" then
    options = mode
    mode = options and options.mode
  end
  options = options or {}
  local requestedMode = (mode == "admin") and "admin" or "member"
  local requestedPugMode = options.pugMode == true
  if InCombatLockdown and InCombatLockdown() then
    if GLD and GLD.Print then
      GLD:Print("Cannot open the example Loot/Pending preview during combat.")
    end
    AdminTestLog("ShowExampleLootPendingWindow blocked: in combat mode=" .. tostring(requestedMode))
    return false
  end

  local state = GetLootWindowState(self)
  local payload = BuildExamplePreviewData(requestedMode, requestedPugMode)
  state.demoMode = true
  state.previewMode = payload.previewMode
  state.previewAuthority = payload.previewAuthority
  state.previewPugMode = payload.previewPugMode == true
  state.demoVotes = payload.demoVotes or {}
  state.demoItems = payload.demoItems or {}
  state.activeKey = nil
  state.activeIndex = nil

  local liveSessions = GetActiveVoteSessions()
  if #liveSessions > 0 and GLD and GLD.Print then
    GLD:Print("Real session active; showing preview mock window only.")
    AdminTestLog("Real session active; showing preview mock window only.")
  end
  if requestedMode == "admin" then
    AdminTestLog("AdminPreview opened pugMode=" .. tostring(state.previewPugMode == true))
  else
    AdminTestLog("ShowExampleLootPendingWindow mode=" .. tostring(requestedMode))
  end

  local ok, err = pcall(function()
    self:RefreshLootWindow({ forceShow = true, forceDemo = true })
  end)
  if not ok then
    if GLD and GLD.Print then
      GLD:Print("Failed to open preview window: " .. tostring(err))
    end
    return false
  end
  return true
end

function GLD:ShowExampleLootPendingWindow(mode, pugMode)
  if not self.UI or not self.UI.ShowLootWindowDemo then
    return false
  end
  return self.UI:ShowLootWindowDemo(mode, { pugMode = pugMode == true })
end

function GLD:ShowExampleMemberLootPendingWindow()
  return self:ShowExampleLootPendingWindow("member")
end

function GLD:ShowExampleAdminLootPendingWindow(pugMode)
  return self:ShowExampleLootPendingWindow("admin", pugMode)
end

function UI:ShowDemoWinnerNotice(session)
  if not session then
    return
  end
  local window = self.demoWinnerNotice
  if not window then
    window = CreateFrame("Frame", "GLDDemoWinnerNotice", UIParent, "BackdropTemplate")
    window:SetSize(360, 180)
    window:SetPoint("TOP", UIParent, "TOP", 0, -160)
    window:SetFrameStrata("HIGH")
    window:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    window:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    window:SetClampedToScreen(true)

    local title = window:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", window, "TOP", 0, -18)
    title:SetText("You have won the item!")
    window.title = title

    local itemContainer = CreateFrame("Frame", nil, window)
    itemContainer:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -80, -6)
    itemContainer:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 80, -6)
    itemContainer:SetHeight(60)
    window.itemContainer = itemContainer
    window.itemLines = {}

    local action = window:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    action:SetPoint("TOP", itemContainer, "BOTTOM", 0, -2)
    action:SetText("|cffFFD200Roll NEED|r")
    window.action = action

    local sub = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOP", action, "BOTTOM", 0, -6)
    sub:SetText("In the Blizzard loot roll window.")
    window.sub = sub

    local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)
    closeButton:SetScript("OnClick", function()
      window:Hide()
    end)

    self.demoWinnerNotice = window
  end

  self.demoWinnerItems = self.demoWinnerItems or {}
  local id = session.rollKey or session.rollID or session.itemLink or session.itemName or tostring(session)
  if not self.demoWinnerItems[id] then
    local itemName = GetDisplayedItemText(session)
    local itemLink = session.itemLink
    local icon = DEFAULT_ICON
    if itemLink then
      local itemIcon = select(10, GetItemInfo(itemLink))
      if itemIcon then
        icon = itemIcon
      else
        GLD:RequestItemData(itemLink)
      end
    end
    self.demoWinnerItems[id] = { name = itemName, icon = icon }
  end

  local items = {}
  for _, entry in pairs(self.demoWinnerItems) do
    items[#items + 1] = entry
  end

  for i, line in ipairs(window.itemLines or {}) do
    line.icon:Hide()
    line.text:Hide()
  end

  local maxLines = math.min(#items, 3)
  for i = 1, maxLines do
    local entry = items[i]
    local line = window.itemLines[i]
    if not line then
      line = {}
      line.frame = CreateFrame("Frame", nil, window.itemContainer)
      line.frame:SetSize(320, 52)
      line.icon = line.frame:CreateTexture(nil, "ARTWORK")
      line.icon:SetSize(36, 36)
      line.text = line.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      line.text:SetJustifyH("CENTER")
      window.itemLines[i] = line
    end
    line.icon:SetTexture(entry.icon or DEFAULT_ICON)
    line.frame:ClearAllPoints()
    line.frame:SetPoint("TOP", window.itemContainer, "TOP", 0, -((i - 1) * 52))
    line.icon:SetPoint("TOP", line.frame, "TOP", 0, 0)
    line.icon:Show()
    line.text:SetPoint("TOP", line.icon, "BOTTOM", 0, -2)
    line.text:SetPoint("LEFT", line.frame, "LEFT", 6, 0)
    line.text:SetPoint("RIGHT", line.frame, "RIGHT", -6, 0)
    line.text:SetText(entry.name or "Item")
    line.text:Show()
  end

  if window.itemContainer then
    window.itemContainer:SetHeight(maxLines * 52)
  end

  if window then
    window:Show()
  end
end

function UI:HandleLootVote(vote)
  local state = GetLootWindowState(self)
  local entry = state.currentVoteItems[state.activeIndex]
  if not entry then
    return
  end
  if state.demoMode then
    state.demoVotes[entry.key] = vote
    if entry.key == "demo-loot-b" and vote ~= "PASS" then
      self:ShowDemoWinnerNotice(entry.session)
    end
    self:RefreshLootWindow({ advance = true, activeKey = entry.key })
    return
  end
  if entry.session then
    self:SubmitRollVote(entry.session, vote, true)
  end
end

function UI:ShowPendingFrame(options)
  options = options or {}
  if not IsLootGateActive() then
    return
  end
  self:RefreshLootWindow({
    forceShow = true,
    reopen = options.reopen,
    onlyIfPending = options.onlyIfPending,
    trigger = options.trigger,
  })
end

function UI:RefreshPendingVotes()
  self:RefreshLootWindow()
end
