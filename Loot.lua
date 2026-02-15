local _, NS = ...

local GLD = NS.GLD
local LootEngine = NS.LootEngine
local LiveProvider = NS.LiveProvider
local TestProvider = NS.TestProvider

local function LBDebugEnabled()
  return GLD and GLD.lbDebug == true
end

local function LBPrint(msg, force)
  if not force and not LBDebugEnabled() then
    return
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("[LB] " .. tostring(msg))
  end
end

local function EnsureLootRollBlockerDB()
  if not GLD or not GLD.db then
    return nil
  end
  GLD.db.lootRollBlocker = GLD.db.lootRollBlocker or {}
  local db = GLD.db.lootRollBlocker
  if db.enabled == nil then
    db.enabled = true
  end
  if db.isBlocking == nil then
    db.isBlocking = false
  end
  if db.needsRecovery == nil then
    db.needsRecovery = false
  end
  return db
end

function GLD:EnsureLootRollBlockerDB()
  return EnsureLootRollBlockerDB()
end

function GLD:GetLocalVoteState(session)
  if not session then
    return nil
  end
  session.localVoteState = session.localVoteState or {
    hasVoted = false,
    voteValue = nil,
    dismissedWithoutVote = false,
    lastPromptedAt = nil,
  }
  return session.localVoteState
end

function GLD:RecordLocalVote(session, vote)
  if not session then
    return
  end
  local state = self:GetLocalVoteState(session)
  if not state then
    return
  end
  if state.hasVoted and state.voteValue == vote then
    return
  end
  state.hasVoted = true
  state.voteValue = vote
  state.dismissedWithoutVote = false
  if self.LilyDebug then
    local playerName = self.GetUnitFullName and self:GetUnitFullName("player") or UnitName("player") or "player"
    local itemRef = session.itemLink or session.itemID or session.itemName or "unknown"
    self:LilyDebug(
      string.format(
        "[VOTE] VoteRecorded player=%s item=%s value=%s",
        tostring(playerName),
        tostring(itemRef),
        tostring(vote)
      )
    )
  end
end

function GLD:MarkLocalVoteDismissed(session)
  if not session then
    return
  end
  local state = self:GetLocalVoteState(session)
  if not state or state.hasVoted then
    return
  end
  state.dismissedWithoutVote = true
end

function GLD:GetLocalVoteValue(session)
  if not session or not session.votes then
    return nil
  end
  local localKey = NS:GetPlayerKeyFromUnit("player")
  if not localKey then
    return nil
  end
  if session.votes[localKey] ~= nil then
    return session.votes[localKey]
  end
  if self.GetRollCandidateKey then
    local alt = self:GetRollCandidateKey(localKey)
    if alt and session.votes[alt] ~= nil then
      return session.votes[alt]
    end
  end
  local provider = session.isTest and TestProvider or LiveProvider
  if provider and provider.GetPlayerName then
    local name = provider:GetPlayerName(localKey)
    if name and session.votes[name] ~= nil then
      return session.votes[name]
    end
  end
  return nil
end

function GLD:SyncLocalVoteState(session)
  local vote = self:GetLocalVoteValue(session)
  if vote ~= nil then
    self:RecordLocalVote(session, vote)
  end
end

local function IsLocalWinnerForResult(result)
  if not result then
    return false
  end
  local localKey = NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
  local localFull = GLD.GetUnitFullName and GLD:GetUnitFullName("player") or nil
  local localShort = UnitName("player")
  if localKey and result.winnerKey and result.winnerKey == localKey then
    return true
  end
  if localFull and result.winnerName and result.winnerName == localFull then
    return true
  end
  if localShort and result.winnerShortName and result.winnerShortName == localShort then
    return true
  end
  return false
end

function GLD:ApplyCoverOutcomeForResult(result, isWinner)
  if not result or not result.rollID then
    return
  end
  if not self.SetCoverOverride then
    return
  end
  local guid = UnitGUID("player")
  if not guid then
    return
  end
  if isWinner == nil then
    isWinner = IsLocalWinnerForResult(result)
  end
  local mode = isWinner and "WINNER" or "LOSER"
  self:SetCoverOverride(result.rollID, guid, mode, false)
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("Cover result applied: rollID=" .. tostring(result.rollID) .. " mode=" .. tostring(mode))
  end
end

do
  local version = NS.VERSION
  if not version and GetAddOnMetadata and NS.ADDON_NAME then
    version = GetAddOnMetadata(NS.ADDON_NAME, "Version")
  end
  local build = nil
  if GetBuildInfo then
    build = select(4, GetBuildInfo())
  end
  local stamp = date and date("%Y-%m-%d %H:%M:%S") or "unknown time"
  LBPrint(
    "Covers module loaded (version="
      .. tostring(version or "unknown")
      .. ", build="
      .. tostring(build or "unknown")
      .. ", time="
      .. tostring(stamp)
      .. ")",
    true
  )
end

function GLD:InitLoot()
  self.activeRolls = {}
  if self.InitLootSessionController then
    self:InitLootSessionController()
  end
  EnsureLootRollBlockerDB()
  self:RegisterEvent("START_LOOT_ROLL", "OnStartLootRoll")
  self:RegisterEvent("CANCEL_LOOT_ROLL", "OnCancelLootRoll")
  self:RegisterEvent("PLAYER_LOGIN", "OnCoverLogin")
  if self.lbDebug == nil then
    self.lbDebug = false
  end
  SLASH_LBDEBUG1 = "/lbdebug"
  SlashCmdList["LBDEBUG"] = function()
    self.lbDebug = not self.lbDebug
    LBPrint("Debug " .. (self.lbDebug and "enabled" or "disabled"), true)
  end
  SLASH_LBLOCK1 = "/lblock"
  SlashCmdList["LBLOCK"] = function(msg)
    if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
      LBPrint("Loot blocker command ignored: loot session is not active.", true)
      return
    end
    local mode = tostring(msg or ""):lower():gsub("%s+", "")
    if mode == "" then
      mode = "lock_all"
    end
    local mapped = {
      lock_all = "LOCK_ALL",
      unlock_all = "UNLOCK_ALL",
      winner = "WINNER",
      loser = "LOSER",
    }
    local applyMode = mapped[mode]
    if not applyMode then
      LBPrint("Unknown mode: " .. tostring(msg), true)
      return
    end
    local rollFrame = nil
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 8) do
      local frame = _G["GroupLootFrame" .. i] or _G["LootRollFrame" .. i]
      if frame and frame.IsShown and frame:IsShown() then
        rollFrame = frame
        break
      end
    end
    if not rollFrame then
      LBPrint("No visible roll frame found for manual test", true)
      return
    end
    RollBlockers.SetMode(rollFrame, applyMode)
    LBPrint("Manual apply " .. applyMode .. " to " .. tostring(rollFrame:GetName() or rollFrame), true)
  end
  if C_Timer and C_Timer.NewTicker then
    -- Periodic cleanup to keep roll data from growing in long sessions.
    self.cleanupTicker = C_Timer.NewTicker(300, function()
      if self.IsEnabled and not self:IsEnabled() then
        return
      end
      if self.CleanupActiveRolls then
        self:CleanupActiveRolls(1800)
      else
        self:CleanupOldTestRolls(1800)
      end
    end)
  end
  if self.InitCoverAuthority then
    self:InitCoverAuthority()
  end
  if self.InitLootRollBootProtection then
    self:InitLootRollBootProtection()
  end
  if self.RefreshLootControllerFromPersistence then
    self:RefreshLootControllerFromPersistence("InitLoot")
  end
end

local RollBlockers = {
  byFrame = setmetatable({}, { __mode = "k" }),
}

GLD.RollBlockers = RollBlockers

local LibCustomGlow = LibStub and LibStub("LibCustomGlow-1.0", true) or nil
local BLOCKER_TOOLTIP_TEXT = "Waiting for loot decision..."

local function GetTransmogOrDisenchantButton(rollFrame)
  if not rollFrame then
    return nil
  end
  return rollFrame.TransmogButton or rollFrame.DisenchantButton or rollFrame.Disenchant
end

local function GetPassButton(rollFrame)
  if not rollFrame then
    return nil
  end
  return rollFrame.PassButton or rollFrame.Pass
end

local function SyncBlocker(blocker, button)
  if not blocker or not button then
    return
  end
  if blocker.GetParent and blocker:GetParent() ~= UIParent then
    blocker:SetParent(UIParent)
  end
  blocker:ClearAllPoints()
  blocker:SetAllPoints(button)
  blocker:SetFrameStrata("FULLSCREEN_DIALOG")
  local level = button.GetFrameLevel and button:GetFrameLevel() or 0
  blocker:SetFrameLevel(level + 200)
end

local function CreateBlocker(button)
  if not button then
    return nil
  end
  local blocker = CreateFrame("Frame", nil, UIParent)
  blocker:EnableMouse(true)
  blocker:SetAllPoints(button)
  blocker:SetFrameStrata("FULLSCREEN_DIALOG")
  local level = button.GetFrameLevel and button:GetFrameLevel() or 0
  blocker:SetFrameLevel(level + 200)
  if blocker.SetPropagateMouseClicks then
    blocker:SetPropagateMouseClicks(false)
  end
  blocker:SetScript("OnMouseDown", function(self)
    if LBDebugEnabled() then
      local name = self._gldButtonName or "unknown"
      LBPrint("blocker clicked over " .. tostring(name))
    end
  end)
  blocker:SetScript("OnMouseUp", function() end)
  if GameTooltip then
    blocker:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetText(BLOCKER_TOOLTIP_TEXT)
      GameTooltip:Show()
    end)
    blocker:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  local texture = blocker:CreateTexture(nil, "BACKGROUND")
  texture:SetAllPoints()
  texture:SetTexture("Interface\\AddOns\\GuildLootDistribution\\media\\ClickDenied.tga")
  texture:SetAlpha(0.9)
  blocker._gldTexture = texture
  blocker:Hide()
  return blocker
end

local function EnsureBlocker(blockers, key, button)
  if not button then
    return
  end
  if not blockers[key] then
    blockers[key] = CreateBlocker(button)
  end
  SyncBlocker(blockers[key], button)
end

local function SetHighlight(button, on)
  if not button then
    return
  end
  if LibCustomGlow and LibCustomGlow.ButtonGlow_Start and LibCustomGlow.ButtonGlow_Stop then
    if on then
      LibCustomGlow.ButtonGlow_Start(button)
    else
      LibCustomGlow.ButtonGlow_Stop(button)
    end
    return
  end
  if ActionButton_ShowOverlayGlow and ActionButton_HideOverlayGlow then
    if on then
      ActionButton_ShowOverlayGlow(button)
    else
      ActionButton_HideOverlayGlow(button)
    end
  end
end

local function ApplyHighlights(rollFrame, mode)
  if not rollFrame then
    return
  end
  local blockers = RollBlockers.byFrame[rollFrame]
  local buttons = blockers and blockers.buttons or {}
  local function Apply(key, on)
    SetHighlight(buttons[key], on)
  end
  if mode == "WINNER" then
    Apply("need", true)
    Apply("greed", true)
    Apply("transmog", true)
    Apply("pass", false)
    return
  end
  if mode == "LOSER" then
    Apply("need", false)
    Apply("greed", false)
    Apply("transmog", false)
    Apply("pass", true)
    return
  end
  Apply("need", false)
  Apply("greed", false)
  Apply("transmog", false)
  Apply("pass", false)
end

function RollBlockers.EnsureForRollFrame(rollFrame)
  if not rollFrame then
    return nil
  end
  local blockers = RollBlockers.byFrame[rollFrame]
  if not blockers then
    blockers = {}
    RollBlockers.byFrame[rollFrame] = blockers
  end
  if not rollFrame._gldBlockerHooksSet then
    rollFrame:HookScript("OnShow", function()
      local source = "RollBlockers.OnShow"
      if rollFrame._gldBlockerNeedsOnShow then
        local mode = rollFrame._gldBlockerOnShowMode or "LOCK_ALL"
        rollFrame._gldBlockerNeedsOnShow = nil
        rollFrame._gldBlockerOnShowMode = nil
        LBPrint("OnShow reapply " .. tostring(mode) .. " for " .. tostring(rollFrame:GetName() or rollFrame))
        RollBlockers.SetMode(rollFrame, mode)
        source = source .. ".reapply"
      end
      if GLD and GLD.OnObservedLootRollFrameShown then
        GLD:OnObservedLootRollFrameShown(rollFrame, source)
      end
    end)
    rollFrame:HookScript("OnHide", function()
      ApplyHighlights(rollFrame, "UNLOCK_ALL")
      LBPrint("Roll frame hidden: highlights cleared for " .. tostring(rollFrame:GetName() or rollFrame))
    end)
    rollFrame._gldBlockerHooksSet = true
  end
  blockers.buttons = blockers.buttons or {}
  blockers.buttons.need = rollFrame.NeedButton or rollFrame.Need
  blockers.buttons.greed = rollFrame.GreedButton or rollFrame.Greed
  blockers.buttons.transmog = GetTransmogOrDisenchantButton(rollFrame)
  blockers.buttons.pass = GetPassButton(rollFrame)
  if LBDebugEnabled() then
    local function LogButton(label, button)
      if not button then
        LBPrint(label .. ": nil")
        return
      end
      local w = button.GetWidth and button:GetWidth() or 0
      local h = button.GetHeight and button:GetHeight() or 0
      local strata = button.GetFrameStrata and button:GetFrameStrata() or "?"
      local level = button.GetFrameLevel and button:GetFrameLevel() or 0
      LBPrint(label .. ": " .. tostring(button:GetName() or button) .. " size=" .. tostring(w) .. "x" .. tostring(h) .. " strata=" .. tostring(strata) .. " level=" .. tostring(level))
      if w == 0 or h == 0 then
        LBPrint("button size 0x0: layout not ready; reapply next frame / OnShow hook needed")
      end
    end
    LogButton("need", blockers.buttons.need)
    LogButton("greed", blockers.buttons.greed)
    LogButton("transmog", blockers.buttons.transmog)
    LogButton("pass", blockers.buttons.pass)
    local missing = {}
    if not blockers.buttons.need then
      missing[#missing + 1] = "need"
    end
    if not blockers.buttons.greed then
      missing[#missing + 1] = "greed"
    end
    if not blockers.buttons.transmog then
      missing[#missing + 1] = "transmog"
    end
    if not blockers.buttons.pass then
      missing[#missing + 1] = "pass"
    end
    if #missing > 0 then
      LBPrint("missing buttons: " .. table.concat(missing, ", "))
    end
  end
  EnsureBlocker(blockers, "need", blockers.buttons.need)
  EnsureBlocker(blockers, "greed", blockers.buttons.greed)
  EnsureBlocker(blockers, "transmog", blockers.buttons.transmog)
  EnsureBlocker(blockers, "pass", blockers.buttons.pass)
  return blockers
end

local function SetBlockerVisible(blocker, button, show)
  if not blocker then
    return
  end
  if show then
    if button then
      blocker._gldButton = button
      blocker._gldButtonName = button.GetName and button:GetName() or tostring(button)
      SyncBlocker(blocker, button)
    end
    blocker:Show()
    if blocker.Raise then
      blocker:Raise()
    end
    if LBDebugEnabled() then
      local w = blocker.GetWidth and blocker:GetWidth() or 0
      local h = blocker.GetHeight and blocker:GetHeight() or 0
      if w == 0 or h == 0 then
        LBPrint("blocker has 0 size: anchor timing problem")
      end
    end
  else
    blocker:Hide()
  end
end

function RollBlockers.SetMode(rollFrame, mode)
  local blockers = RollBlockers.EnsureForRollFrame(rollFrame)
  if not blockers then
    return
  end
  rollFrame._gldBlockerMode = mode
  if mode == "UNLOCK_ALL" then
    rollFrame._gldBlockerNeedsOnShow = nil
    rollFrame._gldBlockerOnShowMode = nil
  end
  if LBDebugEnabled() then
    local name = rollFrame and (rollFrame.GetName and rollFrame:GetName() or tostring(rollFrame)) or "unknown"
    LBPrint("SetMode " .. tostring(mode) .. " for " .. tostring(name))
  end
  if LBDebugEnabled() then
    local name = rollFrame and (rollFrame.GetName and rollFrame:GetName() or tostring(rollFrame)) or "unknown"
    local shown = rollFrame and rollFrame.IsShown and rollFrame:IsShown() or false
    if not shown then
      LBPrint("rollFrame hidden when applying " .. tostring(mode) .. ": " .. tostring(name))
    end
  end
  local buttons = blockers.buttons or {}
  local function ShowForButton(key, show)
    local button = buttons[key]
    local blocker = blockers[key]
    if not button then
      show = false
    end
    if show and blocker and button then
      blocker:ClearAllPoints()
      blocker:SetAllPoints(button)
    end
    SetBlockerVisible(blocker, button, show)
  end
  if mode == "LOCK_ALL" then
    ShowForButton("need", true)
    ShowForButton("greed", true)
    ShowForButton("transmog", true)
    ShowForButton("pass", true)
  elseif mode == "WINNER" then
    ShowForButton("need", false)
    ShowForButton("greed", false)
    ShowForButton("transmog", false)
    ShowForButton("pass", true)
  elseif mode == "LOSER" then
    ShowForButton("need", true)
    ShowForButton("greed", true)
    ShowForButton("transmog", true)
    ShowForButton("pass", false)
  else
    ShowForButton("need", false)
    ShowForButton("greed", false)
    ShowForButton("transmog", false)
    ShowForButton("pass", false)
  end
  ApplyHighlights(rollFrame, mode)
end

function RollBlockers.ReleaseForRollFrame(rollFrame)
  if not rollFrame then
    return
  end
  local blockers = RollBlockers.byFrame[rollFrame]
  if not blockers then
    return
  end
  for _, key in ipairs({ "need", "greed", "transmog", "pass" }) do
    local blocker = blockers[key]
    if blocker and blocker.Hide then
      blocker:Hide()
    end
    blockers[key] = nil
  end
  blockers.buttons = nil
  RollBlockers.byFrame[rollFrame] = nil
end

local function FindRollFrameByID(rollID)
  if not rollID then
    return nil
  end
  if GroupLootContainer then
    if GroupLootContainer.GetFrameForLootID then
      local frame = GroupLootContainer:GetFrameForLootID(rollID)
      if LBDebugEnabled() then
        LBPrint("GroupLootContainer:GetFrameForLootID exists, result=" .. tostring(frame and (frame.GetName and frame:GetName() or frame) or "nil"))
      end
      if frame then
        return frame
      end
    elseif LBDebugEnabled() then
      LBPrint("GroupLootContainer:GetFrameForLootID missing")
    end
    if GroupLootContainer.GetFrameForRollID then
      local frame = GroupLootContainer:GetFrameForRollID(rollID)
      if LBDebugEnabled() then
        LBPrint("GroupLootContainer:GetFrameForRollID exists, result=" .. tostring(frame and (frame.GetName and frame:GetName() or frame) or "nil"))
      end
      if frame then
        return frame
      end
    elseif LBDebugEnabled() then
      LBPrint("GroupLootContainer:GetFrameForRollID missing")
    end
  elseif LBDebugEnabled() then
    LBPrint("GroupLootContainer missing; fallback to GroupLootFrame scan")
  end
  local maxFrames = NUM_GROUP_LOOT_FRAMES or NUM_LOOT_ROLLS or 8
  for i = 1, maxFrames do
    local frame = _G["GroupLootFrame" .. i] or _G["LootRollFrame" .. i]
    if frame and (frame.rollID == rollID or frame.lootID == rollID or frame.LootID == rollID) then
      if LBDebugEnabled() then
        LBPrint("Fallback scan matched: " .. tostring(frame:GetName() or frame))
      end
      return frame
    end
  end
  if LBDebugEnabled() then
    LBPrint("Fallback scan: no GroupLootFrame1.." .. tostring(maxFrames) .. " matched rollID=" .. tostring(rollID))
  end
  return nil
end

local LOOT_BOOT_GLOBAL_HOOKS = {
  "GroupLootFrame_OpenNewFrame",
  "GroupLootContainer_AddFrame",
  "GroupLootContainer_OpenNewFrame",
}

local LOOT_BOOT_CONTAINER_METHOD_HOOKS = {
  "AddFrame",
  "OpenNewFrame",
}

local LOOT_BOOT_CONTAINER_FRAME_TABLES = {
  "rollFrames",
  "activeFrames",
  "frames",
}

local function IsFrameObject(value)
  return type(value) == "table" and value.GetObjectType and value:IsObjectType("Frame")
end

local function IsBlockingMode(mode)
  return mode == "LOCK_ALL" or mode == "WINNER" or mode == "LOSER"
end

function GLD:IsLootRollBlockModeActive()
  local db = EnsureLootRollBlockerDB()
  if not self:AreLootBlockersEnabled() then
    if db then
      db.isBlocking = false
    end
    return false
  end
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    if db then
      db.isBlocking = false
    end
    return false
  end
  if db and db.enabled == false then
    db.isBlocking = false
    return false
  end
  if self.GetPugsInRaid and self:GetPugsInRaid() then
    if db then
      db.isBlocking = false
    end
    return false
  end
  local mode = self.GetCoverAutoMode and self:GetCoverAutoMode() or "LOCK_ALL"
  local active = mode ~= "UNLOCK_ALL"
  if db then
    db.isBlocking = active
  end
  return active
end

function GLD:EnsureLootBootState()
  if not self._lootBootState then
    local ui = self.GetUIConfig and self:GetUIConfig() or nil
    local blockersEnabled = true
    local tutorialActive = false
    if ui then
      if ui.tutorialBlockersEnabled ~= nil then
        blockersEnabled = ui.tutorialBlockersEnabled == true
      end
      tutorialActive = ui.tutorialActive == true
    end
    self._lootBootState = {
      hooksInstalled = false,
      scanCompleted = false,
      lastScan = nil,
      lateScanPending = false,
      bootGuardArmed = true,
      sawPlayerLogin = false,
      sawEnteringWorld = false,
      globalHooks = {},
      containerMethodHooks = {},
      blockersEnabled = blockersEnabled,
      tutorialActive = tutorialActive,
      pendingDisableAllBlockers = false,
      pendingDisableReason = nil,
    }
  end
  return self._lootBootState
end

function GLD:AreLootBlockersEnabled()
  local state = self:EnsureLootBootState()
  if state.blockersEnabled == nil then
    state.blockersEnabled = true
  end
  return state.blockersEnabled == true
end

function GLD:SetTutorialBlockersActive(active)
  local state = self:EnsureLootBootState()
  active = active == true
  state.tutorialActive = active
  state.blockersEnabled = active

  local ui = self.GetUIConfig and self:GetUIConfig() or nil
  if ui then
    ui.tutorialActive = active
    ui.tutorialBlockersEnabled = active
  end

  local db = EnsureLootRollBlockerDB()
  if db then
    db.enabled = active
    if not active then
      db.isBlocking = false
      db.needsRecovery = false
    end
  end
end

function GLD:StopLootBootLateScan(reason)
  local state = self:EnsureLootBootState()
  state.lateScanPending = false
  state.lateScanReason = reason or "stop"
  state.lateScanTick = 0
  if state.lateScanTicker and state.lateScanTicker.Cancel then
    state.lateScanTicker:Cancel()
  end
  state.lateScanTicker = nil
end

function GLD:DisableAllBlockers(reason)
  local state = self:EnsureLootBootState()
  reason = reason or "unknown"

  if InCombatLockdown and InCombatLockdown() then
    state.pendingDisableAllBlockers = true
    state.pendingDisableReason = reason
    local eventFrame = self:EnsureLootBootEventFrame()
    if eventFrame and eventFrame.RegisterEvent then
      eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return false, "deferred"
  end

  self:DisableAllBlockersNow(reason, "immediate")
  return true, "immediate"
end

function GLD:DisableAllBlockersNow(reason, source)
  local state = self:EnsureLootBootState()
  reason = reason or "unknown"
  source = source or "immediate"

  state.pendingDisableAllBlockers = false
  state.pendingDisableReason = nil
  state.blockersEnabled = false
  state.tutorialActive = false

  local ui = self.GetUIConfig and self:GetUIConfig() or nil
  if ui then
    ui.tutorialActive = false
    ui.tutorialBlockersEnabled = false
  end

  local db = EnsureLootRollBlockerDB()
  if db then
    db.enabled = false
    db.isBlocking = false
    db.needsRecovery = false
  end

  self:ClearLootRollInterception("DisableAllBlockers:" .. tostring(reason), false)

  local trackedFrames = {}
  for rollFrame in pairs(RollBlockers.byFrame or {}) do
    trackedFrames[#trackedFrames + 1] = rollFrame
  end
  for _, rollFrame in ipairs(trackedFrames) do
    if rollFrame then
      rollFrame._gldBlockerNeedsOnShow = nil
      rollFrame._gldBlockerOnShowMode = nil
      RollBlockers.SetMode(rollFrame, "UNLOCK_ALL")
      RollBlockers.ReleaseForRollFrame(rollFrame)
    end
  end

  if reason == "tutorial_finished" and self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("[Tutorial] Finish -> DisableAllBlockers (" .. tostring(source) .. ")")
  end
end

function GLD:ClearLootRollInterception(reason, clearActiveRolls)
  local state = self:EnsureLootBootState()
  self:StopLootBootLateScan("clear:" .. tostring(reason))
  state.waitingForCombatUnlock = nil
  state.bootGuardArmed = false
  state.scanCompleted = false
  state.lastScan = nil
  if state.eventFrame and state.eventFrame.UnregisterEvent then
    state.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  self:SetLootBootGuardEnabled(false, "clear:" .. tostring(reason))

  local frames = self.CollectLootRollFrames and self:CollectLootRollFrames() or {}
  for _, rollFrame in ipairs(frames) do
    if rollFrame then
      rollFrame._gldBlockerNeedsOnShow = nil
      rollFrame._gldBlockerOnShowMode = nil
      RollBlockers.SetMode(rollFrame, "UNLOCK_ALL")
      RollBlockers.ReleaseForRollFrame(rollFrame)
    end
  end

  if self._rollFrameByRollID then
    wipe(self._rollFrameByRollID)
  end
  if self._pendingRollFrameLookup then
    wipe(self._pendingRollFrameLookup)
  end
  self._reapplyBlockersRetryPending = nil
  self.coverAppliedModes = self.coverAppliedModes or {}
  wipe(self.coverAppliedModes)
  self.coverOverrides = self.coverOverrides or {}
  wipe(self.coverOverrides)

  if clearActiveRolls and self.activeRolls then
    wipe(self.activeRolls)
  end
  if self.UI and self.UI.CloseLootSessionWindows then
    self.UI:CloseLootSessionWindows("session_disabled")
  elseif self.UI and self.UI.RefreshLootWindow then
    self.UI:RefreshLootWindow()
  end
end

function GLD:OnLootSessionEnabled(sessionId, reason)
  local state = self:EnsureLootBootState()
  state.bootGuardArmed = true
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "Loot session enabled: sessionId="
        .. tostring(sessionId or "nil")
        .. " reason="
        .. tostring(reason)
    )
  end
  self:SetLootBootGuardEnabled(true, "enable:" .. tostring(reason))
  self:RunLootBootBootstrap("enable:" .. tostring(reason))
  self:StartLootBootLateScan("enable:" .. tostring(reason))
  if self.ResumeCoverBlockers then
    self:ResumeCoverBlockers()
  end
end

function GLD:OnLootSessionDisabled(reason, _, options)
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("Loot session disabled: reason=" .. tostring(reason))
  end
  self:ClearLootRollInterception(reason or "session_disabled", options and options.clearActiveRolls == true)
end

function GLD:EnsureLootBootEventFrame()
  local state = self:EnsureLootBootState()
  if state.eventFrame then
    return state.eventFrame
  end
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
      local addonName = ...
      if addonName == "Blizzard_GroupLootFrames" and GLD and GLD.OnLootBootBlizzardGroupLootLoaded then
        GLD:OnLootBootBlizzardGroupLootLoaded(event, addonName)
      end
    elseif event == "PLAYER_ENTERING_WORLD" then
      if GLD and GLD.OnLootBootPlayerEnteringWorld then
        GLD:OnLootBootPlayerEnteringWorld(event)
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if GLD and GLD.OnLootBootCombatUnlocked then
        GLD:OnLootBootCombatUnlocked(event)
      end
    end
  end)
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  state.eventFrame = frame
  return frame
end

function GLD:EnsureLootBootGuard()
  local state = self:EnsureLootBootState()
  if state.bootGuard then
    return state.bootGuard
  end
  local guard = CreateFrame("Frame", nil, UIParent)
  guard:SetFrameStrata("TOOLTIP")
  guard:SetFrameLevel(10000)
  guard:SetAllPoints(UIParent)
  guard:EnableMouse(true)
  if guard.SetPropagateMouseClicks then
    guard:SetPropagateMouseClicks(false)
  end
  guard:SetScript("OnMouseDown", function()
    if LBDebugEnabled() then
      LBPrint("BootGuard intercepted click")
    end
  end)
  guard:SetScript("OnMouseUp", function() end)
  guard:Hide()
  state.bootGuard = guard
  return guard
end

function GLD:SetLootBootGuardEnabled(enabled, reason)
  local state = self:EnsureLootBootState()
  local guard = self:EnsureLootBootGuard()
  enabled = enabled == true
  if enabled and self.IsEnabled and not self:IsEnabled() then
    enabled = false
  end
  if state.bootGuardEnabled == enabled then
    return
  end
  state.bootGuardEnabled = enabled
  if enabled then
    guard:SetAllPoints(UIParent)
    guard:Show()
    if guard.Raise then
      guard:Raise()
    end
    LBPrint("BootGuard enabled: " .. tostring(reason))
  else
    guard:Hide()
    LBPrint("BootGuard disabled: " .. tostring(reason))
  end
end

function GLD:GetLootRollIDFromFrame(rollFrame)
  if not rollFrame then
    return nil
  end
  local direct = {
    rollFrame.rollID,
    rollFrame.lootID,
    rollFrame.LootID,
    rollFrame.rollId,
    rollFrame.lootId,
  }
  for _, value in ipairs(direct) do
    local id = tonumber(value)
    if id then
      return id
    end
  end
  local rollInfo = rollFrame.rollInfo
  if type(rollInfo) == "table" then
    local fromInfo = tonumber(rollInfo.rollID or rollInfo.lootID or rollInfo.rollId or rollInfo.lootId)
    if fromInfo then
      return fromInfo
    end
  end
  if rollFrame.GetRollID then
    local ok, id = pcall(rollFrame.GetRollID, rollFrame)
    id = ok and tonumber(id) or nil
    if id then
      return id
    end
  end
  if rollFrame.GetLootID then
    local ok, id = pcall(rollFrame.GetLootID, rollFrame)
    id = ok and tonumber(id) or nil
    if id then
      return id
    end
  end
  return nil
end

function GLD:GetBlockModeForRollFrame(rollID, rollFrame)
  local mode = nil
  local playerGUID = UnitGUID("player")
  if rollID and playerGUID and self.GetCoverOverrideMode then
    mode = self:GetCoverOverrideMode(rollID, playerGUID)
  end
  if mode ~= "LOCK_ALL" and mode ~= "WINNER" and mode ~= "LOSER" and mode ~= "UNLOCK_ALL" then
    mode = self.GetCoverAutoMode and self:GetCoverAutoMode() or nil
  end
  if mode ~= "LOCK_ALL" and mode ~= "WINNER" and mode ~= "LOSER" and mode ~= "UNLOCK_ALL" then
    mode = rollFrame and rollFrame._gldBlockerMode or nil
  end
  if mode ~= "LOCK_ALL" and mode ~= "WINNER" and mode ~= "LOSER" and mode ~= "UNLOCK_ALL" then
    mode = "LOCK_ALL"
  end
  return mode
end

function GLD:ApplyBlockerForRollFrame(rollID, rollFrame, reason)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return false, nil
  end
  if not self:AreLootBlockersEnabled() then
    return false, nil
  end
  if not rollFrame then
    return false, nil
  end
  rollID = rollID or self:GetLootRollIDFromFrame(rollFrame)
  local mode = self:GetBlockModeForRollFrame(rollID, rollFrame)
  if rollID then
    self._rollFrameByRollID = self._rollFrameByRollID or {}
    self._rollFrameByRollID[rollID] = rollFrame
  end
  if mode == "UNLOCK_ALL" then
    rollFrame._gldBlockerNeedsOnShow = nil
    rollFrame._gldBlockerOnShowMode = nil
  else
    rollFrame._gldBlockerNeedsOnShow = true
    rollFrame._gldBlockerOnShowMode = mode
  end
  RollBlockers.SetMode(rollFrame, mode)
  LBPrint(
    "ApplyBlocker: source="
      .. tostring(reason or "unknown")
      .. " rollID="
      .. tostring(rollID)
      .. " mode="
      .. tostring(mode)
      .. " frame="
      .. tostring(rollFrame.GetName and rollFrame:GetName() or rollFrame)
  )
  return true, mode
end

function GLD:ApplyBlocker(rollID, rollFrame, reason)
  return self:ApplyBlockerForRollFrame(rollID, rollFrame, reason)
end

function GLD:EnsureLootRollFrameOnShowHook(rollFrame, source)
  if not rollFrame or not rollFrame.HookScript or rollFrame._gldBootOnShowHookSet then
    return
  end
  rollFrame:HookScript("OnShow", function(frame)
    if GLD and GLD.OnObservedLootRollFrameShown then
      GLD:OnObservedLootRollFrameShown(frame, "Boot.OnShow")
    end
  end)
  rollFrame._gldBootOnShowHookSet = true
  LBPrint("OnShow hook installed for " .. tostring(rollFrame.GetName and rollFrame:GetName() or rollFrame) .. " source=" .. tostring(source))
end

function GLD:ObserveLootRollFrame(rollFrame, source, hintedRollID, applyNow)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return false
  end
  if not IsFrameObject(rollFrame) then
    return false
  end
  self:EnsureLootRollFrameOnShowHook(rollFrame, source)
  RollBlockers.EnsureForRollFrame(rollFrame)
  local rollID = hintedRollID or self:GetLootRollIDFromFrame(rollFrame)
  if rollID then
    self._rollFrameByRollID = self._rollFrameByRollID or {}
    self._rollFrameByRollID[rollID] = rollFrame
  end
  if applyNow then
    self:ApplyBlocker(rollID, rollFrame, source)
  end
  return true
end

function GLD:OnObservedLootRollFrameShown(rollFrame, source)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not rollFrame then
    return
  end
  local rollID = self:GetLootRollIDFromFrame(rollFrame)
  if rollID then
    self:ApplyBlocker(rollID, rollFrame, source or "OnShow")
  elseif LBDebugEnabled() then
    LBPrint("OnShow frame without rollID: " .. tostring(rollFrame.GetName and rollFrame:GetName() or rollFrame))
  end
  self:EvaluateLootBootGuardRelease("OnShow")
end

function GLD:OnLootRollHookTriggered(hookName, ...)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  local rollID = nil
  local rollFrame = nil
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if not rollFrame and IsFrameObject(value) then
      rollFrame = value
    end
    if rollID == nil and type(value) == "number" then
      rollID = value
    elseif rollID == nil and type(value) == "table" then
      rollID = tonumber(value.rollID or value.lootID or value.LootID or value.rollId or value.lootId) or nil
    end
  end
  if rollFrame then
    self:ObserveLootRollFrame(rollFrame, "hook:" .. tostring(hookName), rollID, true)
  end
  if rollID then
    local found = rollFrame or FindRollFrameByID(rollID)
    if found then
      self:ObserveLootRollFrame(found, "hook-find:" .. tostring(hookName), rollID, true)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        local delayed = FindRollFrameByID(rollID)
        if delayed then
          self:ObserveLootRollFrame(delayed, "hook-delay:" .. tostring(hookName), rollID, true)
        end
      end)
    end
  end
  self:EvaluateLootBootGuardRelease("hook:" .. tostring(hookName))
end

function GLD:TryLoadBlizzardGroupLootFrames(reason)
  if IsAddOnLoaded and IsAddOnLoaded("Blizzard_GroupLootFrames") then
    return true
  end
  if not LoadAddOn then
    return false
  end
  local state = self:EnsureLootBootState()
  local eventFrame = self:EnsureLootBootEventFrame()
  if InCombatLockdown and InCombatLockdown() then
    state.waitingForCombatUnlock = true
    if eventFrame and eventFrame.RegisterEvent then
      eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    LBPrint("Deferred Blizzard_GroupLootFrames load until combat ends (" .. tostring(reason) .. ")")
    return false
  end
  local ok, loaded, loadReason = pcall(LoadAddOn, "Blizzard_GroupLootFrames")
  local isLoaded = (ok and loaded) or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_GroupLootFrames"))
  if not isLoaded then
    LBPrint("LoadAddOn Blizzard_GroupLootFrames failed: " .. tostring(loadReason) .. " source=" .. tostring(reason))
    return false
  end
  state.waitingForCombatUnlock = nil
  if eventFrame and eventFrame.UnregisterEvent then
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  LBPrint("Blizzard_GroupLootFrames ready (" .. tostring(reason) .. ")")
  return true
end

function GLD:InstallLootRollStartupHooks(reason)
  local state = self:EnsureLootBootState()
  if not self:TryLoadBlizzardGroupLootFrames(reason) then
    if not state.waitingForCombatUnlock then
      -- Fallback to scans even if explicit load failed; avoids a permanent guard lock.
      state.hooksInstalled = true
      LBPrint("Loot hooks fallback active (load unavailable): " .. tostring(reason))
      return true
    end
    return false
  end

  for _, hookName in ipairs(LOOT_BOOT_GLOBAL_HOOKS) do
    if not state.globalHooks[hookName] and type(_G[hookName]) == "function" then
      hooksecurefunc(hookName, function(...)
        if GLD and GLD.OnLootRollHookTriggered then
          GLD:OnLootRollHookTriggered(hookName, ...)
        end
      end)
      state.globalHooks[hookName] = true
      LBPrint("Hook installed: " .. tostring(hookName))
    end
  end

  if GroupLootContainer then
    for _, methodName in ipairs(LOOT_BOOT_CONTAINER_METHOD_HOOKS) do
      if not state.containerMethodHooks[methodName] and type(GroupLootContainer[methodName]) == "function" then
        hooksecurefunc(GroupLootContainer, methodName, function(_, ...)
          if GLD and GLD.OnLootRollHookTriggered then
            GLD:OnLootRollHookTriggered("GroupLootContainer:" .. tostring(methodName), ...)
          end
        end)
        state.containerMethodHooks[methodName] = true
        LBPrint("Hook installed: GroupLootContainer:" .. tostring(methodName))
      end
    end
  end

  state.hooksInstalled = true
  LBPrint("Loot hooks installed pass complete (" .. tostring(reason) .. ")")
  return true
end

function GLD:IsLootRollFrameActive(rollFrame, rollID)
  if not rollFrame then
    return false
  end
  if rollID then
    return true
  end
  if rollFrame.IsShown and rollFrame:IsShown() then
    return true
  end
  if rollFrame._gldBlockerNeedsOnShow then
    return true
  end
  return false
end

function GLD:CollectLootRollFrames()
  local seen = {}
  local frames = {}
  local function AddFrame(frame)
    if not IsFrameObject(frame) or seen[frame] then
      return
    end
    seen[frame] = true
    frames[#frames + 1] = frame
  end

  if GroupLootContainer then
    for _, key in ipairs(LOOT_BOOT_CONTAINER_FRAME_TABLES) do
      local frameTable = GroupLootContainer[key]
      if type(frameTable) == "table" then
        for _, frame in pairs(frameTable) do
          AddFrame(frame)
        end
      end
    end
  end

  if self._rollFrameByRollID then
    for _, frame in pairs(self._rollFrameByRollID) do
      AddFrame(frame)
    end
  end

  local maxFrames = math.max(NUM_GROUP_LOOT_FRAMES or 0, NUM_LOOT_ROLLS or 0, 12)
  for i = 1, maxFrames do
    AddFrame(_G["GroupLootFrame" .. i])
    AddFrame(_G["LootRollFrame" .. i])
  end

  return frames
end

function GLD:HasConfirmedBlockersForFrame(rollFrame, mode)
  if not IsBlockingMode(mode) then
    return true
  end
  local blockers = RollBlockers.byFrame[rollFrame]
  if not blockers or not blockers.buttons then
    return false
  end
  local hasAnyButton = false
  for _, key in ipairs({ "need", "greed", "transmog", "pass" }) do
    local button = blockers.buttons[key]
    if button then
      hasAnyButton = true
      if not blockers[key] then
        return false
      end
    end
  end
  return hasAnyButton
end

function GLD:ScanExistingLootRollFrames(reason)
  local state = self:EnsureLootBootState()
  local frames = self:CollectLootRollFrames()
  local activeCount = 0
  local appliedCount = 0
  local unconfirmedCount = 0

  for _, rollFrame in ipairs(frames) do
    local rollID = self:GetLootRollIDFromFrame(rollFrame)
    local isActive = self:IsLootRollFrameActive(rollFrame, rollID)
    if isActive then
      activeCount = activeCount + 1
      self:ObserveLootRollFrame(rollFrame, "scan:" .. tostring(reason), rollID, false)
      local applied, mode = self:ApplyBlocker(rollID, rollFrame, "scan:" .. tostring(reason))
      if applied then
        appliedCount = appliedCount + 1
      end
      if not self:HasConfirmedBlockersForFrame(rollFrame, mode) then
        unconfirmedCount = unconfirmedCount + 1
      end
    end
  end

  local summary = {
    reason = reason,
    totalFrames = #frames,
    activeCount = activeCount,
    appliedCount = appliedCount,
    unconfirmedCount = unconfirmedCount,
  }
  state.scanCompleted = true
  state.lastScan = summary
  LBPrint(
    "Loot scan: reason="
      .. tostring(reason)
      .. " frames="
      .. tostring(summary.totalFrames)
      .. " active="
      .. tostring(summary.activeCount)
      .. " applied="
      .. tostring(summary.appliedCount)
      .. " unconfirmed="
      .. tostring(summary.unconfirmedCount)
  )
  return summary
end

function GLD:CanReleaseLootBootGuard()
  if not self:IsLootRollBlockModeActive() then
    return true
  end
  local state = self:EnsureLootBootState()
  if not state.hooksInstalled then
    return false, "hooks-not-installed"
  end
  if not state.scanCompleted then
    return false, "scan-not-complete"
  end
  if state.waitingForCombatUnlock then
    return false, "combat-lockdown"
  end
  if not state.sawPlayerLogin and not state.sawEnteringWorld then
    return false, "login-or-world-pending"
  end
  if state.lateScanPending then
    return false, "late-scan-pending"
  end
  if self._reapplyBlockersRetryPending then
    return false, "reapply-pending"
  end
  if self._pendingRollFrameLookup and next(self._pendingRollFrameLookup) then
    return false, "frame-lookup-pending"
  end
  local scan = state.lastScan or {}
  local active = tonumber(scan.activeCount) or 0
  local unconfirmed = tonumber(scan.unconfirmedCount) or 0
  if active == 0 then
    return true, "no-active-frames"
  end
  if unconfirmed == 0 then
    return true, "all-active-frames-confirmed"
  end
  return false, "active-frames-unconfirmed"
end

function GLD:EvaluateLootBootGuardRelease(reason)
  if not self:IsLootRollBlockModeActive() then
    local state = self:EnsureLootBootState()
    state.bootGuardArmed = false
    self:SetLootBootGuardEnabled(false, "not-block-mode:" .. tostring(reason))
    return
  end
  local state = self:EnsureLootBootState()
  local canRelease, gateReason = self:CanReleaseLootBootGuard()
  if canRelease then
    state.bootGuardArmed = false
    self:SetLootBootGuardEnabled(false, "release:" .. tostring(gateReason) .. ":" .. tostring(reason))
  elseif state.bootGuardArmed then
    self:SetLootBootGuardEnabled(true, "hold:" .. tostring(gateReason) .. ":" .. tostring(reason))
  end
end

function GLD:RunLootBootBootstrap(reason)
  local state = self:EnsureLootBootState()
  local eventFrame = self:EnsureLootBootEventFrame()
  if self.RefreshLootControllerFromPersistence and (reason == "InitLoot" or reason == "PLAYER_LOGIN" or reason == "ADDON_LOADED") then
    self:RefreshLootControllerFromPersistence("RunLootBootBootstrap:" .. tostring(reason))
  end
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    state.bootGuardArmed = false
    self:SetLootBootGuardEnabled(false, "disabled:" .. tostring(reason))
    return
  end
  if not self:AreLootBlockersEnabled() then
    state.bootGuardArmed = false
    self:SetLootBootGuardEnabled(false, "blockers-disabled:" .. tostring(reason))
    return
  end
  if not self:IsLootRollBlockModeActive() then
    self:EvaluateLootBootGuardRelease(reason)
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    state.waitingForCombatUnlock = true
    if eventFrame and eventFrame.RegisterEvent then
      eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
  else
    state.waitingForCombatUnlock = nil
    if eventFrame and eventFrame.UnregisterEvent then
      eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
  end
  if state.bootGuardArmed then
    self:SetLootBootGuardEnabled(true, "bootstrap:" .. tostring(reason))
  end
  self:InstallLootRollStartupHooks(reason)
  self:ScanExistingLootRollFrames(reason)
  self:EvaluateLootBootGuardRelease(reason)
end

function GLD:StartLootBootLateScan(reason)
  local state = self:EnsureLootBootState()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    self:StopLootBootLateScan("disabled:" .. tostring(reason))
    return
  end
  state.lateScanPending = true
  state.lateScanReason = reason
  state.lateScanTick = 0
  if state.lateScanTicker and state.lateScanTicker.Cancel then
    state.lateScanTicker:Cancel()
    state.lateScanTicker = nil
  end
  if not C_Timer or not C_Timer.NewTicker then
    self:RunLootBootBootstrap("late-fallback:" .. tostring(reason))
    state.lateScanPending = false
    self:EvaluateLootBootGuardRelease("late-fallback-complete")
    return
  end
  state.lateScanTicker = C_Timer.NewTicker(0.1, function()
    local inner = GLD and GLD.EnsureLootBootState and GLD:EnsureLootBootState() or nil
    if not inner then
      return
    end
    inner.lateScanTick = (inner.lateScanTick or 0) + 1
    LBPrint("Late scan tick " .. tostring(inner.lateScanTick) .. "/10 reason=" .. tostring(inner.lateScanReason))
    if GLD and GLD.RunLootBootBootstrap then
      GLD:RunLootBootBootstrap("late:" .. tostring(inner.lateScanReason) .. ":" .. tostring(inner.lateScanTick))
    end
    if inner.lateScanTick >= 10 then
      if inner.lateScanTicker and inner.lateScanTicker.Cancel then
        inner.lateScanTicker:Cancel()
      end
      inner.lateScanTicker = nil
      inner.lateScanPending = false
      LBPrint("Late scan ticker complete reason=" .. tostring(inner.lateScanReason))
      if GLD and GLD.EvaluateLootBootGuardRelease then
        GLD:EvaluateLootBootGuardRelease("late-scan-complete")
      end
    end
  end)
end

function GLD:OnLootBootBlizzardGroupLootLoaded(_, addonName)
  LBPrint("ADDON_LOADED: " .. tostring(addonName) .. " (loot bootstrap)")
  if self.RefreshLootControllerFromPersistence then
    self:RefreshLootControllerFromPersistence("ADDON_LOADED")
  end
  if self.IsEnabled and not self:IsEnabled() then
    return
  end
  self:RunLootBootBootstrap("ADDON_LOADED")
end

function GLD:OnLootBootPlayerEnteringWorld(event)
  if self.RefreshLootControllerFromPersistence then
    self:RefreshLootControllerFromPersistence(event or "PLAYER_ENTERING_WORLD")
  end
  local state = self:EnsureLootBootState()
  state.sawEnteringWorld = true
  state.bootGuardArmed = self:IsLootRollBlockModeActive()
  if self.IsEnabled and not self:IsEnabled() then
    self:ClearLootRollInterception(event or "PLAYER_ENTERING_WORLD", false)
    return
  end
  if not self:AreLootBlockersEnabled() then
    self:ClearLootRollInterception(event or "PLAYER_ENTERING_WORLD", false)
    return
  end
  LBPrint("PLAYER_ENTERING_WORLD loot bootstrap")
  self:RunLootBootBootstrap(event or "PLAYER_ENTERING_WORLD")
  self:StartLootBootLateScan("PLAYER_ENTERING_WORLD")
end

function GLD:OnLootBootCombatUnlocked(event)
  local state = self:EnsureLootBootState()
  if state.pendingDisableAllBlockers then
    local pendingReason = state.pendingDisableReason or "unknown"
    self:DisableAllBlockersNow(pendingReason, "deferred")
    return
  end
  if self.IsEnabled and not self:IsEnabled() then
    self:ClearLootRollInterception(event or "PLAYER_REGEN_ENABLED", false)
    return
  end
  state.waitingForCombatUnlock = nil
  state.bootGuardArmed = self:IsLootRollBlockModeActive()
  local eventFrame = state.eventFrame
  if eventFrame and eventFrame.UnregisterEvent then
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  LBPrint("Combat unlocked; retrying loot bootstrap (" .. tostring(event) .. ")")
  self:RunLootBootBootstrap(event or "PLAYER_REGEN_ENABLED")
end

function GLD:InitLootRollBootProtection()
  local state = self:EnsureLootBootState()
  self:EnsureLootBootEventFrame()
  if self.RefreshLootControllerFromPersistence then
    self:RefreshLootControllerFromPersistence("InitLootRollBootProtection")
  end
  if self.IsEnabled and not self:IsEnabled() then
    state.bootGuardArmed = false
    self:ClearLootRollInterception("InitLootRollBootProtection", true)
    return
  end
  state.bootGuardArmed = self:IsLootRollBlockModeActive()
  if self:IsLootRollBlockModeActive() then
    self:SetLootBootGuardEnabled(true, "InitLoot")
  else
    self:SetLootBootGuardEnabled(false, "InitLoot")
  end
  self:RunLootBootBootstrap("InitLoot")
end

function RollBlockers.ApplyForRoll(rollID, mode)
  if not rollID then
    return nil
  end
  local rollFrame = (GLD and GLD._rollFrameByRollID and GLD._rollFrameByRollID[rollID]) or FindRollFrameByID(rollID)
  if not rollFrame then
    if LBDebugEnabled() then
      LBPrint("ApplyForRoll: rollFrame nil for rollID=" .. tostring(rollID))
    end
    return nil
  end
  if GLD then
    GLD._rollFrameByRollID = GLD._rollFrameByRollID or {}
    GLD._rollFrameByRollID[rollID] = rollFrame
  end
  RollBlockers.SetMode(rollFrame, mode)
  return rollFrame
end

function GLD:LockLootRollButtons(rollID)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not self:AreLootBlockersEnabled() then
    return
  end
  if not rollID then
    return
  end
  if LBDebugEnabled() then
    LBPrint("START_LOOT_ROLL: rollID=" .. tostring(rollID))
  end
  local rollFrame = FindRollFrameByID(rollID)
  if not rollFrame then
    if LBDebugEnabled() then
      LBPrint("rollFrame nil: lookup mismatch (GroupLootContainer vs GroupLootFrame scan)")
    end
    if C_Timer and C_Timer.After then
      self._pendingRollFrameLookup = self._pendingRollFrameLookup or {}
      if not self._pendingRollFrameLookup[rollID] then
        self._pendingRollFrameLookup[rollID] = true
        C_Timer.After(0, function()
          if self._pendingRollFrameLookup then
            self._pendingRollFrameLookup[rollID] = nil
          end
          if not (self.AreLootBlockersEnabled and self:AreLootBlockersEnabled()) then
            return
          end
          self:LockLootRollButtons(rollID)
        end)
      end
    end
    return
  end
  if LBDebugEnabled() then
    local name = rollFrame.GetName and rollFrame:GetName() or tostring(rollFrame)
    local shown = rollFrame.IsShown and rollFrame:IsShown() or false
    local strata = rollFrame.GetFrameStrata and rollFrame:GetFrameStrata() or "?"
    local level = rollFrame.GetFrameLevel and rollFrame:GetFrameLevel() or 0
    LBPrint("rollFrame=" .. tostring(name) .. " shown=" .. tostring(shown) .. " strata=" .. tostring(strata) .. " level=" .. tostring(level))
  end
  self._rollFrameByRollID = self._rollFrameByRollID or {}
  self._rollFrameByRollID[rollID] = rollFrame
  self:ObserveLootRollFrame(rollFrame, "START_LOOT_ROLL", rollID, false)
  self:ApplyBlocker(rollID, rollFrame, "START_LOOT_ROLL")
  if LBDebugEnabled() then
    LBPrint("SetMode LOCK_ALL called")
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if not (self.AreLootBlockersEnabled and self:AreLootBlockersEnabled()) then
        return
      end
      if self.ApplyBlocker then
        self:ApplyBlocker(rollID, rollFrame, "START_LOOT_ROLL.nextFrame")
      else
        RollBlockers.SetMode(rollFrame, "LOCK_ALL")
      end
      if LBDebugEnabled() then
        LBPrint("Reapplied next frame")
      end
    end)
  end
  self:EvaluateLootBootGuardRelease("START_LOOT_ROLL")
end

function GLD:UnlockLootRollButtons(rollID)
  if self.IsEnabled and not self:IsEnabled() then
    return
  end
  if not rollID then
    return
  end
  if LBDebugEnabled() then
    LBPrint("CANCEL_LOOT_ROLL: rollID=" .. tostring(rollID))
  end
  local rollFrame = self._rollFrameByRollID and self._rollFrameByRollID[rollID] or nil
  if not rollFrame then
    rollFrame = FindRollFrameByID(rollID)
  end
  if rollFrame then
    rollFrame._gldBlockerNeedsOnShow = nil
    rollFrame._gldBlockerOnShowMode = nil
    RollBlockers.SetMode(rollFrame, "UNLOCK_ALL")
    if LBDebugEnabled() then
      local name = rollFrame.GetName and rollFrame:GetName() or tostring(rollFrame)
      LBPrint("Unlock rollFrame=" .. tostring(name))
      LBPrint("SetMode UNLOCK_ALL called")
    end
    if RollBlockers.ReleaseForRollFrame then
      RollBlockers.ReleaseForRollFrame(rollFrame)
    end
  elseif LBDebugEnabled() then
    LBPrint("rollFrame not found on CANCEL_LOOT_ROLL")
  end
  if self._rollFrameByRollID then
    self._rollFrameByRollID[rollID] = nil
  end
  if self._pendingRollFrameLookup then
    self._pendingRollFrameLookup[rollID] = nil
  end
  self:RunLootBootBootstrap("CANCEL_LOOT_ROLL")
end

local function GetResumeMode(self, rollID, playerGUID)
  local mode = self.GetCoverOverrideMode and self:GetCoverOverrideMode(rollID, playerGUID) or nil
  if mode ~= "WINNER" and mode ~= "LOSER" then
    mode = "LOCK_ALL"
  end
  return mode
end

local function ApplyCoverBlockerForFrame(self, rollID, rollFrame, mode)
  if not rollID or not rollFrame then
    return
  end
  if not (self.AreLootBlockersEnabled and self:AreLootBlockersEnabled()) then
    return
  end
  self:ObserveLootRollFrame(rollFrame, "ReapplyCover", rollID, false)
  self._rollFrameByRollID = self._rollFrameByRollID or {}
  self._rollFrameByRollID[rollID] = rollFrame
  rollFrame._gldBlockerNeedsOnShow = true
  rollFrame._gldBlockerOnShowMode = mode
  RollBlockers.SetMode(rollFrame, mode)
  LBPrint(
    "ApplyBlocker: source=ReapplyCover rollID="
      .. tostring(rollID)
      .. " mode="
      .. tostring(mode)
      .. " frame="
      .. tostring(rollFrame.GetName and rollFrame:GetName() or rollFrame)
  )
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if not (self.AreLootBlockersEnabled and self:AreLootBlockersEnabled()) then
        return
      end
      RollBlockers.SetMode(rollFrame, mode)
    end)
  end
end

function GLD:ReapplyCoverBlockersForActiveRolls(reason, allowRetry)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not self:AreLootBlockersEnabled() then
    self._reapplyBlockersRetryPending = nil
    return
  end
  if self.GetPugsInRaid and self:GetPugsInRaid() then
    if self._rollFrameByRollID then
      for rollID, rollFrame in pairs(self._rollFrameByRollID) do
        if rollFrame then
          RollBlockers.SetMode(rollFrame, "UNLOCK_ALL")
        elseif self.ClearCoverOverridesForRoll then
          self:ClearCoverOverridesForRoll(rollID)
        end
      end
    end
    self:RunLootBootBootstrap("ReapplyCoverBlockers:pugs_mode")
    return
  end
  if not self.activeRolls then
    return
  end
  local playerGUID = UnitGUID("player")
  if not playerGUID then
    return
  end
  local missing = false
  for _, session in pairs(self.activeRolls) do
    if session and not session.locked then
      if not (self.IsRollSessionExpired and self:IsRollSessionExpired(session)) then
        local rollID = session.rollID
        local rollFrame = rollID and FindRollFrameByID(rollID) or nil
        local mode = GetResumeMode(self, rollID, playerGUID)
        local applied = false
        if rollFrame then
          ApplyCoverBlockerForFrame(self, rollID, rollFrame, mode)
          applied = true
        else
          missing = true
        end
        if self.LilyDebug then
          local sessionId = session.rollID or session.rollKey or "unknown"
          local itemRef = session.itemLink or session.itemID or session.itemName or "unknown"
          self:LilyDebug(
            string.format(
              "[VOTE] ReapplyBlockers session=%s item=%s blocked=%s",
              tostring(sessionId),
              tostring(itemRef),
              tostring(applied)
            )
          )
        end
      end
    end
  end
  if missing and allowRetry and C_Timer and C_Timer.After then
    if not self._reapplyBlockersRetryPending then
      self._reapplyBlockersRetryPending = true
      C_Timer.After(0.2, function()
        if not (self.AreLootBlockersEnabled and self:AreLootBlockersEnabled()) then
          self._reapplyBlockersRetryPending = nil
          return
        end
        self._reapplyBlockersRetryPending = nil
        self:ReapplyCoverBlockersForActiveRolls(reason, false)
      end)
    end
  end
  self:RunLootBootBootstrap("ReapplyCoverBlockers:" .. tostring(reason))
end

function GLD:ResumeCoverBlockers()
  self:ReapplyCoverBlockersForActiveRolls("resume", true)
end

function GLD:OnCoverLogin()
  if self.RefreshLootControllerFromPersistence then
    self:RefreshLootControllerFromPersistence("PLAYER_LOGIN")
  end
  if self.IsEnabled and not self:IsEnabled() then
    self:ClearLootRollInterception("PLAYER_LOGIN", true)
    return
  end
  local state = self:EnsureLootBootState()
  state.sawPlayerLogin = true
  state.bootGuardArmed = self:IsLootRollBlockModeActive()
  if not self:AreLootBlockersEnabled() then
    self:ClearLootRollInterception("PLAYER_LOGIN", true)
    return
  end
  LBPrint("PLAYER_LOGIN loot bootstrap")
  self:RunLootBootBootstrap("PLAYER_LOGIN")
  self:StartLootBootLateScan("PLAYER_LOGIN")
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if self.ResumeCoverBlockers then
        self:ResumeCoverBlockers()
      end
      self:RunLootBootBootstrap("PLAYER_LOGIN.resume")
      if not (self.IsAuthority and self:IsAuthority()) and self.IsSessionActive and self:IsSessionActive() and self.RequestRollSessionSnapshot then
        self:RequestRollSessionSnapshot(nil, nil)
      end
    end)
  else
    if self.ResumeCoverBlockers then
      self:ResumeCoverBlockers()
    end
    self:RunLootBootBootstrap("PLAYER_LOGIN.resume")
    if not (self.IsAuthority and self:IsAuthority()) and self.IsSessionActive and self:IsSessionActive() and self.RequestRollSessionSnapshot then
      self:RequestRollSessionSnapshot(nil, nil)
    end
  end
end

local COVER_COMM_PREFIX = NS.COVER_COMM_PREFIX or "GLD1COV"
local COVER_AUTH_PING = "AUTH_PING"
local COVER_AUTH_CLAIM = "AUTH_CLAIM"
local COVER_AUTH_SET = "AUTH_SET"
local COVER_OVR_SET = "OVR_SET"
local COVER_OVR_CLR = "OVR_CLR"
local COVER_HEARTBEAT_SECONDS = 2
local COVER_ELECTION_TIMEOUT = 8
local COVER_FALLBACK_TIMEOUT = 15

local function GetCoverEpochSeconds()
  if GetServerTime then
    return GetServerTime()
  end
  return time()
end

local function GetCoverNow()
  if GetTime then
    return GetTime()
  end
  return GetCoverEpochSeconds()
end

local function CompareCoverCandidates(a, b)
  if a.rankIndex ~= b.rankIndex then
    return a.rankIndex < b.rankIndex
  end
  if a.guid and b.guid and a.guid ~= b.guid then
    return a.guid < b.guid
  end
  local nameA = a.fullName or ""
  local nameB = b.fullName or ""
  return nameA < nameB
end

function GLD:IsHostEligible(unit)
  if not unit or not UnitExists(unit) then
    return false
  end
  local fullName = self.GetUnitFullName and self:GetUnitFullName(unit) or UnitName(unit)
  if self.IsAuthorityName and fullName then
    return select(1, self:IsAuthorityName(fullName, { source = "Loot.IsHostEligible" })) == true
  end
  if self.IsUnitGuildOfficer then
    return self:IsUnitGuildOfficer(unit) == true
  end
  return false
end

function GLD:IsCoverAuthority()
  local guid = self.coverAuthorityGUID
  return guid and UnitGUID("player") == guid or false
end

function GLD:InitCoverAuthority()
  if self.coverAuthorityInitialized then
    return
  end
  self.coverAuthorityInitialized = true
  self.coverOverrides = self.coverOverrides or {}
  self.coverAppliedModes = self.coverAppliedModes or {}
  self.coverEpoch = self.coverEpoch or 0
  self.coverAuthorityGUID = self.coverAuthorityGUID or nil
  self.coverLastSeen = self.coverLastSeen or GetCoverNow()
  self.coverFallbackActive = false
  self.coverLastElectionAt = 0

  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(COVER_COMM_PREFIX)
  end
  self:RegisterEvent("CHAT_MSG_ADDON", "OnCoverAddonMessage")
  if C_Timer and C_Timer.NewTicker and not self.coverAuthorityTicker then
    self.coverAuthorityTicker = C_Timer.NewTicker(COVER_HEARTBEAT_SECONDS, function()
      if self.OnCoverAuthorityTick then
        self:OnCoverAuthorityTick()
      end
    end)
  end
end

function GLD:OnCoverAuthorityTick()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  local now = GetCoverNow()
  if self:IsCoverAuthority() then
    self:SendCoverAuthPing()
    self.coverLastSeen = now
    return
  end

  local lastSeen = self.coverLastSeen or 0
  local since = now - lastSeen
  if since > COVER_FALLBACK_TIMEOUT then
    self:EnableCoverFallback()
  end
  if since > COVER_ELECTION_TIMEOUT and self:IsHostEligible("player") then
    self:RunCoverElection()
  end
end

function GLD:EnableCoverFallback()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if self.coverFallbackActive then
    return
  end
  self.coverFallbackActive = true
  self:ApplyCoverStatesForAllActiveRolls()
end

function GLD:DisableCoverFallback()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    self.coverFallbackActive = false
    return
  end
  if not self.coverFallbackActive then
    return
  end
  self.coverFallbackActive = false
  self:ApplyCoverStatesForAllActiveRolls()
end

function GLD:NextCoverEpoch()
  local now = GetCoverEpochSeconds()
  local current = tonumber(self.coverEpoch) or 0
  if now <= current then
    now = current + 1
  end
  return now
end

function GLD:SendCoverMessage(parts)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
    return
  end
  if not IsInRaid() then
    return
  end
  local payload = table.concat(parts, " ")
  C_ChatInfo.SendAddonMessage(COVER_COMM_PREFIX, payload, "RAID")
end

function GLD:SendCoverAuthPing()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not self:IsCoverAuthority() then
    return
  end
  if not self:IsHostEligible("player") then
    return
  end
  local epoch = tonumber(self.coverEpoch) or self:NextCoverEpoch()
  self.coverEpoch = epoch
  local guid = self.coverAuthorityGUID or UnitGUID("player")
  if not guid then
    return
  end
  self:SendCoverMessage({ COVER_AUTH_PING, tostring(epoch), guid })
end

function GLD:RunCoverElection()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not IsInRaid() then
    return
  end
  local now = GetCoverNow()
  if self.coverLastElectionAt and now - self.coverLastElectionAt < COVER_ELECTION_TIMEOUT then
    return
  end
  self.coverLastElectionAt = now
  local best = self:GetBestCoverCandidate()
  if not best then
    return
  end
  local myGuid = UnitGUID("player")
  if myGuid and best.guid == myGuid then
    local epoch = self:NextCoverEpoch()
    self:SendCoverMessage({ COVER_AUTH_CLAIM, tostring(epoch), myGuid })
    self:SendCoverMessage({ COVER_AUTH_SET, tostring(epoch), myGuid })
    self:ApplyCoverAuthority(epoch, myGuid, "local")
  end
end

function GLD:GetBestCoverCandidate()
  if not IsInRaid() then
    return nil
  end
  local best = nil
  local count = GetNumGroupMembers()
  for i = 1, count do
    local unit = "raid" .. i
    if UnitExists(unit) and self:IsHostEligible(unit) then
      local _, _, rankIndex = GetGuildInfo(unit)
      local candidate = {
        unit = unit,
        guid = UnitGUID(unit),
        fullName = self:GetUnitFullName(unit) or UnitName(unit),
        rankIndex = rankIndex or 99,
      }
      if not best or CompareCoverCandidates(candidate, best) then
        best = candidate
      end
    end
  end
  return best
end

function GLD:ApplyCoverAuthority(epoch, authorityGUID, sender)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  local previousEpoch = tonumber(self.coverEpoch) or 0
  if epoch < previousEpoch then
    return
  end
  local previousAuthority = self.coverAuthorityGUID
  local changedEpoch = epoch ~= previousEpoch
  local changedAuthority = authorityGUID ~= previousAuthority
  local hadFallback = self.coverFallbackActive == true

  self.coverEpoch = epoch
  self.coverAuthorityGUID = authorityGUID
  self.coverLastSeen = GetCoverNow()

  if changedEpoch then
    self.coverOverrides = {}
    self.coverAppliedModes = {}
  end
  if authorityGUID and UnitGUID("player") == authorityGUID then
    if not self.coverIsAuthority then
      self.coverIsAuthority = true
      if self.OnBecameAuthority then
        self:OnBecameAuthority()
      end
    end
  else
    self.coverIsAuthority = false
  end
  if hadFallback then
    self.coverFallbackActive = false
  end

  if changedEpoch or changedAuthority or hadFallback then
    self:ApplyCoverStatesForAllActiveRolls()
  end
end

function GLD:OnBecameAuthority()
  self:Print("You are now host")
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug("You are now host")
  end
end

function GLD:GetCoverOverrideMode(rollID, playerGUID)
  if not rollID or not playerGUID then
    return nil
  end
  local rollOverrides = self.coverOverrides and self.coverOverrides[rollID] or nil
  return rollOverrides and rollOverrides[playerGUID] or nil
end

function GLD:GetCoverAutoMode()
  if self.GetPugsInRaid and self:GetPugsInRaid() then
    return "UNLOCK_ALL"
  end
  if self.coverFallbackActive then
    return "UNLOCK_ALL"
  end
  return "LOCK_ALL"
end

function GLD:ApplyCoverStateForRoll(rollID)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not rollID then
    return
  end
  local guid = UnitGUID("player")
  if not guid then
    return
  end
  local mode = self:GetCoverOverrideMode(rollID, guid) or self:GetCoverAutoMode()
  self.coverAppliedModes = self.coverAppliedModes or {}
  if self.coverAppliedModes[rollID] == mode then
    return
  end
  local rollFrame = RollBlockers.ApplyForRoll(rollID, mode)
  if not rollFrame then
    return
  end
  self.coverAppliedModes[rollID] = mode
end

function GLD:ApplyCoverStatesForAllActiveRolls()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not self._rollFrameByRollID then
    return
  end
  for rollID in pairs(self._rollFrameByRollID) do
    self:ApplyCoverStateForRoll(rollID)
  end
end

function GLD:SetCoverOverride(rollID, playerGUID, mode, broadcast)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not rollID or not playerGUID then
    return
  end
  self.coverOverrides = self.coverOverrides or {}
  local rollOverrides = self.coverOverrides[rollID]
  if not rollOverrides then
    rollOverrides = {}
    self.coverOverrides[rollID] = rollOverrides
  end
  if mode and mode ~= "" then
    rollOverrides[playerGUID] = mode
  else
    rollOverrides[playerGUID] = nil
  end
  if playerGUID == UnitGUID("player") then
    self:ApplyCoverStateForRoll(rollID)
  end
  if broadcast and self:IsCoverAuthority() then
    local epoch = tonumber(self.coverEpoch) or self:NextCoverEpoch()
    self.coverEpoch = epoch
    if mode and mode ~= "" then
      self:SendCoverMessage({ COVER_OVR_SET, tostring(epoch), tostring(rollID), playerGUID, mode })
    else
      self:SendCoverMessage({ COVER_OVR_CLR, tostring(epoch), tostring(rollID), playerGUID })
    end
  end
end

function GLD:ClearCoverOverridesForRoll(rollID)
  if not rollID then
    return
  end
  if self.coverOverrides then
    self.coverOverrides[rollID] = nil
  end
  if self.coverAppliedModes then
    self.coverAppliedModes[rollID] = nil
  end
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  local rollFrame = self._rollFrameByRollID and self._rollFrameByRollID[rollID] or FindRollFrameByID(rollID)
  if rollFrame then
    RollBlockers.SetMode(rollFrame, "UNLOCK_ALL")
  end
end

function GLD:IsCoverSenderEligible(sender)
  if not sender or sender == "" then
    return false
  end
  if not self.GetUnitForSender then
    return false
  end
  local unit = self:GetUnitForSender(sender)
  if not unit then
    return false
  end
  return self:IsHostEligible(unit)
end

function GLD:OnCoverAddonMessage(_, prefix, message, _, sender)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if prefix ~= COVER_COMM_PREFIX then
    return
  end
  if type(message) ~= "string" then
    return
  end
  local msgType, epochText, arg1, arg2, arg3 = strsplit(" ", message)
  local epoch = tonumber(epochText)
  if not msgType or not epoch then
    return
  end
  if msgType == COVER_AUTH_PING then
    self:HandleCoverAuthPing(sender, epoch, arg1)
  elseif msgType == COVER_AUTH_CLAIM then
    self:HandleCoverAuthClaim(sender, epoch, arg1)
  elseif msgType == COVER_AUTH_SET then
    self:HandleCoverAuthSet(sender, epoch, arg1)
  elseif msgType == COVER_OVR_SET then
    local rollID = tonumber(arg1)
    self:HandleCoverOverrideSet(sender, epoch, rollID, arg2, arg3)
  elseif msgType == COVER_OVR_CLR then
    local rollID = tonumber(arg1)
    self:HandleCoverOverrideClear(sender, epoch, rollID, arg2)
  end
end

function GLD:HandleCoverAuthPing(sender, epoch, authorityGUID)
  if not authorityGUID or authorityGUID == "" then
    return
  end
  if not self:IsCoverSenderEligible(sender) then
    return
  end
  local currentEpoch = tonumber(self.coverEpoch) or 0
  if epoch < currentEpoch then
    return
  end
  local senderGuid = self.GetGuidForSender and self:GetGuidForSender(sender) or nil
  if senderGuid and senderGuid ~= authorityGUID then
    return
  end
  if not self.coverAuthorityGUID or epoch > currentEpoch then
    self:ApplyCoverAuthority(epoch, authorityGUID, sender)
  end
  if self.coverAuthorityGUID == authorityGUID and epoch == (tonumber(self.coverEpoch) or 0) then
    self.coverLastSeen = GetCoverNow()
    if self.coverFallbackActive then
      self:DisableCoverFallback()
    end
  end
end

function GLD:HandleCoverAuthClaim(sender, epoch, candidateGUID)
  if not candidateGUID or candidateGUID == "" then
    return
  end
  if not self:IsCoverSenderEligible(sender) then
    return
  end
  local currentEpoch = tonumber(self.coverEpoch) or 0
  if epoch < currentEpoch then
    return
  end
  self.coverLastClaimAt = GetCoverNow()
  self.coverLastClaimGuid = candidateGUID
end

function GLD:HandleCoverAuthSet(sender, epoch, authorityGUID)
  if not authorityGUID or authorityGUID == "" then
    return
  end
  if not self:IsCoverSenderEligible(sender) then
    return
  end
  local currentEpoch = tonumber(self.coverEpoch) or 0
  if epoch < currentEpoch then
    return
  end
  local senderGuid = self.GetGuidForSender and self:GetGuidForSender(sender) or nil
  if senderGuid and senderGuid ~= authorityGUID then
    return
  end
  self:ApplyCoverAuthority(epoch, authorityGUID, sender)
end

function GLD:HandleCoverOverrideSet(sender, epoch, rollID, playerGUID, mode)
  if not rollID or not playerGUID or not mode or mode == "" then
    return
  end
  if not self:IsCoverSenderEligible(sender) then
    return
  end
  local currentEpoch = tonumber(self.coverEpoch) or 0
  if epoch < currentEpoch then
    return
  end
  local senderGuid = self.GetGuidForSender and self:GetGuidForSender(sender) or nil
  if not self.coverAuthorityGUID and senderGuid then
    self:ApplyCoverAuthority(epoch, senderGuid, sender)
  end
  if senderGuid and self.coverAuthorityGUID and senderGuid ~= self.coverAuthorityGUID then
    return
  end
  if epoch ~= (tonumber(self.coverEpoch) or 0) then
    return
  end
  self:SetCoverOverride(rollID, playerGUID, mode, false)
end

function GLD:HandleCoverOverrideClear(sender, epoch, rollID, playerGUID)
  if not rollID or not playerGUID then
    return
  end
  if not self:IsCoverSenderEligible(sender) then
    return
  end
  local currentEpoch = tonumber(self.coverEpoch) or 0
  if epoch < currentEpoch then
    return
  end
  local senderGuid = self.GetGuidForSender and self:GetGuidForSender(sender) or nil
  if not self.coverAuthorityGUID and senderGuid then
    self:ApplyCoverAuthority(epoch, senderGuid, sender)
  end
  if senderGuid and self.coverAuthorityGUID and senderGuid ~= self.coverAuthorityGUID then
    return
  end
  if epoch ~= (tonumber(self.coverEpoch) or 0) then
    return
  end
  self:SetCoverOverride(rollID, playerGUID, nil, false)
end

local function GetRollRemainingTimeMs(session)
  if not session then
    return nil
  end
  if session.rollExpiresAt then
    local remaining = (session.rollExpiresAt - GetServerTime()) * 1000
    if remaining < 0 then
      remaining = 0
    end
    return remaining
  end
  return session.rollTime
end

local function CountActiveRolls(activeRolls)
  local count = 0
  for _ in pairs(activeRolls or {}) do
    count = count + 1
  end
  return count
end

local function IsPlayerGuidKey(key)
  return type(key) == "string" and key:find("^Player%-") ~= nil
end

function GLD:GetWhisperTargetForPlayerKey(key)
  if not key then
    return nil
  end
  if IsPlayerGuidKey(key) then
    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitGUID(unit) == key then
          return self:GetUnitFullName(unit) or UnitName(unit)
        end
      end
    end
    local name = LiveProvider and LiveProvider.GetPlayerName and LiveProvider:GetPlayerName(key) or nil
    if name and name ~= key then
      return name
    end
    return nil
  end
  return key
end

function GLD:GetRaidWhisperTargets()
  local targets = {}
  local seen = {}
  if not IsInRaid() then
    return targets
  end
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    if UnitExists(unit) then
      local name = self:GetUnitFullName(unit) or UnitName(unit)
      if name and not seen[name] then
        targets[#targets + 1] = name
        seen[name] = true
      end
    end
  end
  return targets
end

function GLD:GetMissingAckTargetsForSession(session)
  if not session then
    return {}
  end
  local targets = {}
  local seen = {}
  local expected = session.expectedVoters or {}
  local acks = session.acks or {}
  if #expected == 0 then
    return self:GetRaidWhisperTargets()
  end
  for _, key in ipairs(expected) do
    if key and not acks[key] then
      local name = self:GetWhisperTargetForPlayerKey(key)
      if name and not seen[name] then
        targets[#targets + 1] = name
        seen[name] = true
      end
    end
  end
  if #targets == 0 then
    return self:GetRaidWhisperTargets()
  end
  return targets
end

function GLD:GetMissingAckTargetsForActiveRolls()
  local targets = {}
  local seen = {}
  for _, session in pairs(self.activeRolls or {}) do
    if session and not session.locked and not session.isTest then
      for _, name in ipairs(self:GetMissingAckTargetsForSession(session)) do
        if name and not seen[name] then
          targets[#targets + 1] = name
          seen[name] = true
        end
      end
    end
  end
  return targets
end

function GLD:BuildRollSessionPayload(session, options)
  if not session then
    return nil
  end
  local votes = nil
  if session.votes then
    votes = {}
    for k, v in pairs(session.votes) do
      votes[k] = v
    end
  end
  local expected = nil
  if session.expectedVoters then
    expected = {}
    for i, key in ipairs(session.expectedVoters) do
      expected[i] = key
    end
  end
  local expectedClasses = nil
  if session.expectedVoterClasses then
    expectedClasses = {}
    for k, v in pairs(session.expectedVoterClasses) do
      expectedClasses[k] = v
    end
  end
  local restrictionSnapshot = nil
  if session.restrictionSnapshot then
    restrictionSnapshot = {}
    for k, v in pairs(session.restrictionSnapshot) do
      restrictionSnapshot[k] = v
    end
  end

  return {
    rollID = session.rollID,
    rollKey = session.rollKey,
    status = self.GetRollStatus and self:GetRollStatus(session) or session.status or "ACTIVE",
    locked = session.locked == true,
    rollTime = GetRollRemainingTimeMs(session),
    rollExpiresAt = session.rollExpiresAt,
    itemLink = session.itemLink,
    itemName = session.itemName,
    itemID = session.itemID,
    itemIcon = session.itemIcon,
    quality = session.quality,
    count = session.count,
    canNeed = session.canNeed,
    canGreed = session.canGreed,
    canTransmog = session.canTransmog,
    blizzNeedAllowed = session.blizzNeedAllowed,
    blizzGreedAllowed = session.blizzGreedAllowed,
    blizzTransmogAllowed = session.blizzTransmogAllowed,
    expectedVoters = expected,
    expectedVoterClasses = expectedClasses,
    createdAt = session.createdAt,
    votes = votes,
    computedWinnerGuid = session.computedWinnerGuid,
    approvedWinnerGuid = session.approvedWinnerGuid,
    resolutionReason = session.resolutionReason,
    computedResult = session.computedResult,
    restrictionSnapshot = restrictionSnapshot,
    authorityGUID = self:GetAuthorityGUID(),
    authorityName = self:GetAuthorityName(),
    reopen = options and options.reopen or nil,
    snapshot = options and options.snapshot or nil,
  }
end

function GLD:BroadcastRollSession(session, options, target)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not session or session.isTest then
    return
  end
  if self:IsAuthority() then
    session.acks = session.acks or {}
    local myKey = NS:GetPlayerKeyFromUnit("player")
    if myKey then
      session.acks[myKey] = true
    end
  end
  local payload = self:BuildRollSessionPayload(session, options)
  if not payload then
    return
  end
  if not IsInRaid() then
    return
  end
  self:SendCommMessageSafe(NS.MSG.ROLL_SESSION, payload, "RAID")
  if self:IsAuthority() and self.ScheduleRollSessionResend then
    self:ScheduleRollSessionResend(session)
  end
end

function GLD:ScheduleRollSessionResend(session)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not session or session.isTest then
    return
  end
  if not self:IsAuthority() or not IsInRaid() then
    return
  end
  if session.resendScheduled then
    return
  end
  session.resendScheduled = true

  local function checkAndResend()
    if not self:IsAuthority() or not IsInRaid() then
      return
    end
    if not session or session.locked then
      return
    end
    local active = self.activeRolls and session.rollKey and self.activeRolls[session.rollKey] or nil
    if active ~= session then
      return
    end
    local targets = self:GetMissingAckTargetsForSession(session)
    if #targets == 0 then
      return
    end
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      self:Debug(
        "Roll resend check: rollID="
          .. tostring(session.rollID)
          .. " rollKey="
          .. tostring(session.rollKey)
          .. " missing="
          .. tostring(#targets)
      )
    end
    self:BroadcastRollSession(session, { snapshot = true, reopen = true })
  end

  C_Timer.After(1, checkAndResend)
  C_Timer.After(3, checkAndResend)
end

function GLD:BroadcastActiveRollsSnapshot(targets, options)
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return
  end
  if not self:IsAuthority() then
    return
  end
  if not self.db or not self.db.session or not self.db.session.active then
    return
  end
  if not IsInRaid() then
    return
  end
  if not self.activeRolls then
    return
  end
  local snapshotOptions = options or {}
  for _, session in pairs(self.activeRolls) do
    local status = self.GetRollStatus and self:GetRollStatus(session) or (session and session.status) or "ACTIVE"
    local include = session and not session.isTest and (status == "ACTIVE" or status == "PENDING_APPROVAL")
    if include then
      self:BroadcastRollSession(session, { snapshot = true, reopen = snapshotOptions.reopen })
    end
  end
end

function GLD:ForcePendingVotesWindow()
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    return false
  end
  if not self:IsAuthority() then
    return false
  end
  if not IsInRaid() then
    return false
  end
  if self.BroadcastActiveRollsSnapshot then
    self:BroadcastActiveRollsSnapshot(nil, { reopen = true })
  end
  local payload = {
    authorityGUID = self:GetAuthorityGUID(),
    authorityName = self:GetAuthorityName(),
    requestedAt = GetServerTime(),
  }
  self:SendCommMessageSafe(NS.MSG.FORCE_PENDING, payload, "RAID")
  if self.UI and self.UI.ShowPendingFrame then
    self.UI:ShowPendingFrame({ onlyIfPending = true, trigger = "force", reopen = true })
  end
  self:TraceStep("Force pending votes window sent to raid.")
  return true
end

function GLD:CleanupActiveRolls(maxAgeSeconds)
  if not self.activeRolls then
    return
  end
  local now = GetServerTime()
  local maxAge = maxAgeSeconds or 1800
  for rollKey, session in pairs(self.activeRolls) do
    if not session or (self.IsRollSessionExpired and self:IsRollSessionExpired(session, now, maxAge)) then
      self.activeRolls[rollKey] = nil
    end
  end
end

function GLD:CleanupOldTestRolls(maxAgeSeconds)
  self:CleanupActiveRolls(maxAgeSeconds)
end

function GLD:GetActiveTestSession()
  if not self.testDb or not self.testDb.testSession or not self.testDb.testSession.currentId then
    return nil
  end
  for _, entry in ipairs(self.testDb.testSessions or {}) do
    if entry.id == self.testDb.testSession.currentId then
      return entry
    end
  end
  return nil
end

local function RollTypeToVote(rollType)
  if rollType == LOOT_ROLL_TYPE_NEED then
    return "NEED"
  end
  if rollType == LOOT_ROLL_TYPE_GREED then
    return "GREED"
  end
  if rollType == LOOT_ROLL_TYPE_PASS then
    return "PASS"
  end
  if LOOT_ROLL_TYPE_TRANSMOG and rollType == LOOT_ROLL_TYPE_TRANSMOG then
    return "TRANSMOG"
  end
  return nil
end

function GLD:BuildExpectedVoters()
  local list = {}
  local seen = {}

  local function addUnit(unit)
    if not UnitExists(unit) or not UnitIsConnected(unit) then
      return
    end
    if self.IsTrackedRaidUnit and not self:IsTrackedRaidUnit(unit) then
      return
    end
    local key = nil
    if self.GetTrackedPlayerKeyForUnit then
      key = self:GetTrackedPlayerKeyForUnit(unit)
    end
    if not key then
      key = NS:GetPlayerKeyFromUnit(unit)
    end
    if key and not seen[key] then
      table.insert(list, key)
      seen[key] = true
    end
  end

  if IsInRaid() then
    local count = GetNumGroupMembers()
    for i = 1, count do
      addUnit("raid" .. i)
    end
  else
    addUnit("player")
  end

  return list
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

local function GetPlayerInfoForVote(self, session, playerKey)
  if not playerKey or not self then
    return nil, nil, nil, nil
  end
  local provider = session and session.isTest and TestProvider or LiveProvider
  local player = provider and provider.GetPlayer and provider:GetPlayer(playerKey) or nil
  local classFile = player and (player.classFile or player.classFileName or player.classToken or player.class) or nil
  local specName = player and (player.specName or player.spec) or nil
  if not classFile and session and session.expectedVoterClasses then
    classFile = session.expectedVoterClasses[playerKey]
  end
  local localKey = NS:GetPlayerKeyFromUnit("player")
  if localKey and playerKey == localKey and (not classFile or classFile == "" or not specName or specName == "") then
    if (not classFile or classFile == "") and UnitClass then
      classFile = select(2, UnitClass("player")) or classFile
    end
    if not specName or specName == "" then
      local specIndex = GetSpecialization and GetSpecialization()
      if specIndex then
        local specId = GetSpecializationInfo and GetSpecializationInfo(specIndex)
        if specId and GetSpecializationInfoByID then
          local _, name = GetSpecializationInfoByID(specId)
          specName = name or specName
        end
      end
    end
    local record = self.db and self.db.players and self.db.players[localKey] or nil
    if record then
      if classFile and not (record.classFile or record.classFileName or record.classToken or record.class) then
        record.classFile = classFile
      end
      if specName and not (record.specName or record.spec) then
        record.specName = specName
      end
    end
  end
  return classFile, specName, player, provider
end

function GLD:BuildRollRestrictionSnapshot(session)
  if not session then
    return nil
  end
  local itemId = session.itemID
  if not itemId and session.itemLink and C_Item and C_Item.GetItemInfoInstant then
    itemId = select(1, C_Item.GetItemInfoInstant(session.itemLink))
  end
  local roles = itemId and self.GetTrinketRoleRestriction and self:GetTrinketRoleRestriction(itemId) or nil
  if roles then
    return {
      trinketRoles = roles,
      itemId = itemId,
    }
  end
  return nil
end

function GLD:GetEligibilityReasonText(reason, session)
  if not reason or reason == "" then
    return nil
  end
  if reason == "need_disabled" then
    return "Not allowed for this roll."
  end
  if reason == "greed_disabled" then
    return "Not allowed for this roll."
  end
  if reason == "transmog_disabled" then
    return "Not allowed for this roll."
  end
  if reason == "ineligible_trinket_role" then
    local roles = session and session.restrictionSnapshot and session.restrictionSnapshot.trinketRoles or nil
    local roleText = FormatTrinketRoleList(roles)
    if roleText then
      return "Trinket reserved for " .. roleText .. "."
    end
    return "Trinket role restriction."
  end
  if reason == "ineligible_tier" then
    return "Tier token not for your class."
  end
  if reason == "ineligible_class_restriction" then
    return "Class restricted item."
  end
  if reason == "ineligible_armor" then
    return "Cannot equip this armor type."
  end
  if reason == "ineligible_weapon" then
    return "Cannot equip this weapon type."
  end
  if reason == "ineligible_shield" then
    return "Cannot equip a shield."
  end
  if reason == "ineligible_item_type" then
    return "Cannot use this item type."
  end
  if reason == "item_data_missing" then
    return "Item data still loading."
  end
  if reason == "eligibility_pending" then
    return "Determining eligibility..."
  end
  return "Ineligible for this vote."
end

function GLD:GetEligibilityForVote(session, playerKey, voteType, opts)
  if not session or not voteType then
    return true, nil, nil
  end
  if voteType == "PASS" then
    return true, nil, nil
  end

  local requireData = opts and opts.requireData == true

  if voteType ~= "NEED" then
    if opts and opts.log and self.Debug then
      local _, _, player, provider = GetPlayerInfoForVote(self, session, playerKey)
      local name = provider and provider.GetPlayerName and provider:GetPlayerName(playerKey) or (player and player.name) or playerKey or "Unknown"
      self:Debug(
        "Eligibility result: rollID="
          .. tostring(session.rollID)
          .. " vote="
          .. tostring(voteType)
          .. " player="
          .. tostring(name)
          .. " eligible=true"
      )
    end
    return true, nil, nil
  end

  local itemRef = session.itemLink or session.itemID or session.itemName
  if not itemRef then
    if requireData then
      return false, "eligibility_pending", "GREED"
    end
    return true, nil, nil
  end

  local classFile, specName, player, provider = GetPlayerInfoForVote(self, session, playerKey)
  if not classFile or classFile == "" then
    if opts and opts.log and self.Debug then
      local name = provider and provider.GetPlayerName and provider:GetPlayerName(playerKey) or playerKey or "Unknown"
      self:Debug("Eligibility skipped: missing class for " .. tostring(name))
    end
    if requireData then
      return false, "eligibility_pending", "GREED"
    end
    return true, nil, nil
  end
  classFile = tostring(classFile):upper()

  local context = nil
  if session.restrictionSnapshot and session.restrictionSnapshot.trinketRoles then
    context = { trinketRoles = session.restrictionSnapshot.trinketRoles }
  end
  if requireData and (not specName or specName == "") then
    local isTrinket = context and context.trinketRoles
    if not isTrinket and self.IsItemInfoTrinket then
      isTrinket = self:IsItemInfoTrinket(itemRef)
    end
    if not isTrinket and self.IsKnownTrinket then
      isTrinket = self:IsKnownTrinket(itemRef)
    end
    if isTrinket then
      return false, "eligibility_pending", "GREED"
    end
  end

  local ok, reason = self:IsEligibleForNeed(classFile, itemRef, specName, context)
  if not ok and reason == "item_data_missing" then
    if opts and opts.log and self.Debug then
      self:Debug("Eligibility skipped: item data missing for rollID=" .. tostring(session.rollID))
    end
    if requireData then
      return false, "eligibility_pending", "GREED"
    end
    return true, nil, nil
  end

  if opts and opts.log and self.Debug then
    local name = provider and provider.GetPlayerName and provider:GetPlayerName(playerKey) or playerKey or "Unknown"
    local roleKey = nil
    local isTrinket = session.restrictionSnapshot and session.restrictionSnapshot.trinketRoles or nil
    if not isTrinket and self.IsItemInfoTrinket then
      isTrinket = self:IsItemInfoTrinket(itemRef)
    end
    if self.GetTrinketRoleKey and isTrinket then
      roleKey = self:GetTrinketRoleKey(classFile, specName)
    end
    if roleKey then
      self:Debug("Eligibility role: " .. tostring(name) .. " -> " .. tostring(roleKey))
    end
    self:Debug(
      "Eligibility result: rollID="
        .. tostring(session.rollID)
        .. " vote="
        .. tostring(voteType)
        .. " player="
        .. tostring(name)
        .. " eligible="
        .. tostring(ok)
        .. (reason and (" reason=" .. tostring(reason)) or "")
    )
  end

  return ok, reason, "GREED"
end

function GLD:FindPlayerKeyByName(name, realm)
  if not name then
    return nil
  end
  local realmName = realm and realm ~= "" and realm or GetRealmName()
  for key, player in pairs(self.db.players or {}) do
    if player and player.name == name and (player.realm == realmName or not player.realm) then
      return key
    end
  end
  return nil
end

function GLD:GetRollCandidateKey(sender)
  if not sender then
    return nil
  end
  if type(sender) == "string" and sender:find("^Player%-") then
    if self.FindGuestPlayerKeyByIdentity then
      local guestKey = self:FindGuestPlayerKeyByIdentity(sender, nil, nil)
      if guestKey then
        return guestKey
      end
    end
    return sender
  end
  local name, realm = NS:SplitNameRealm(sender)
  local key = self:FindPlayerKeyByName(name, realm)
  if key then
    return key
  end
  if self.GetGuidForSender then
    local guid = self:GetGuidForSender(sender)
    if guid then
      return guid
    end
  end
  return sender
end

local function IsBlizzFlagKnown(flag)
  return flag == true or flag == false
end

local function HighlightRoll(roll)
  if roll == nil then
    return nil
  end
  return "|cffffd200" .. tostring(roll) .. "|r"
end

function GLD:BuildResultVoteEntries(result, voteType)
  local entries = {}
  if not result or not voteType or not result.votes then
    return entries
  end
  local details = result.voteDetails or {}
  for name, vote in pairs(result.votes) do
    if vote == voteType then
      local detail = details[name]
      entries[#entries + 1] = {
        name = name,
        roll = detail and detail.roll or nil,
        voteOriginal = detail and detail.voteOriginal or nil,
        voteEffective = detail and detail.voteEffective or nil,
        reason = detail and detail.reason or nil,
        reasonText = detail and detail.reasonText or nil,
      }
    end
  end
  table.sort(entries, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)
  return entries
end

function GLD:GetWinnerRoll(result)
  if not result then
    return nil
  end
  if result.winningRoll ~= nil then
    return result.winningRoll
  end
  local details = result.voteDetails or {}
  local winner = result.winnerName
  local entry = winner and details[winner] or nil
  return entry and entry.roll or nil
end

function GLD:ResolveInstructionOverride(result)
  if not result or result.winnerVote ~= "GREED" then
    return nil, nil, nil
  end
  if not IsBlizzFlagKnown(result.blizzNeedAllowed) or not IsBlizzFlagKnown(result.blizzGreedAllowed) then
    return nil, nil, nil
  end
  if result.blizzNeedAllowed == false and result.blizzGreedAllowed == false and result.blizzTransmogAllowed == true then
    return "ROLL_TRANSMOG_REASON_BLIZZARD_GREED_DISABLED", "TRANSMOG", "Blizzard doesn't allow Greed here; please roll TRANSMOG."
  end
  return nil, nil, nil
end

function GLD:BuildRollResultSummaryLine(result)
  if not result then
    return nil
  end
  if result.resolutionReason == "LOST" or result.rollStatus == "LOST" then
    return "Item marked LOST/VOID by admin. Queue standings unchanged."
  end
  local winnerName = result.winnerName or "None"
  local winnerVote = result.winnerVote
  if winnerVote == "GREED" or winnerVote == "TRANSMOG" then
    local entries = self:BuildResultVoteEntries(result, winnerVote)
    local parts = {}
    for _, entry in ipairs(entries) do
      local label = entry.name or "?"
      if entry.roll ~= nil then
        label = label .. " " .. tostring(entry.roll)
      end
      parts[#parts + 1] = label
    end
    local listText = #parts > 0 and table.concat(parts, ", ") or "none"
    local winnerRoll = self:GetWinnerRoll(result)
    local winnerSuffix = winnerRoll ~= nil and (" (" .. HighlightRoll(winnerRoll) .. ")") or ""
    return tostring(winnerVote) .. " rolls: " .. listText .. " -> Winner: " .. tostring(winnerName) .. winnerSuffix
  end
  if winnerVote == "NEED" then
    local entries = self:BuildResultVoteEntries(result, "NEED")
    local parts = {}
    for _, entry in ipairs(entries) do
      parts[#parts + 1] = entry.name or "?"
    end
    local listText = #parts > 0 and table.concat(parts, ", ") or "none"
    return "NEED eligible: " .. listText .. " -> Winner: " .. tostring(winnerName) .. " (queue priority)"
  end
  return "Winner: " .. tostring(winnerName)
end

function GLD:BuildRollResultInstructionLine(result)
  if not result or not result.instructionText then
    return nil
  end
  local winnerName = result.winnerName or "None"
  local voteText = result.winnerVote or "ROLL"
  return "Winner via " .. tostring(voteText) .. ": " .. tostring(winnerName) .. " - " .. tostring(result.instructionText)
end

function GLD:BuildRollResultLines(result)
  local lines = {}
  local summary = self:BuildRollResultSummaryLine(result)
  if summary then
    lines[#lines + 1] = summary
  end
  local instruction = self:BuildRollResultInstructionLine(result)
  if instruction then
    lines[#lines + 1] = instruction
  end
  return lines
end

function GLD:AnnounceRollResult(result)
  if not result then
    return
  end
  if not IsInRaid() then
    return
  end
  local channel = "RAID"
  local itemText = result.itemLink or result.itemName or "Item"
  local lines = self:BuildRollResultLines(result)
  local detail = #lines > 0 and table.concat(lines, " | ") or ("Winner: " .. tostring(result.winnerName or "None"))
  local msg = "GLD Result: " .. tostring(itemText) .. " - " .. detail
  SendChatMessage(msg, channel)
end

function GLD:RecordRollHistory(result)
  if not result then
    return
  end
  self.db.rollHistory = self.db.rollHistory or {}
  table.insert(self.db.rollHistory, 1, result)
  if #self.db.rollHistory > 200 then
    table.remove(self.db.rollHistory)
  end
end

function GLD:ResolveRollWinner(session)
  if not session or session.locked then
    return nil
  end
  if LootEngine and LootEngine.ResolveWinner then
    local provider = session.isTest and TestProvider or LiveProvider
    return LootEngine:ResolveWinner(session.votes or {}, provider, session.rules, session)
  end
  return nil
end

function GLD:LogItemWonAudit(session, winnerKey, winnerVote, provider)
  if not self.LogAuditEvent or not session or session.isTest then
    return
  end
  local targetName = "Unclaimed"
  local isGuest = false
  local classFile = nil
  local specName = nil
  if winnerKey and provider then
    local player = provider.GetPlayer and provider:GetPlayer(winnerKey) or nil
    if player then
      targetName = player.name or targetName
      if self.IsGuestEntry then
        isGuest = self:IsGuestEntry(player)
      end
      classFile = player.classFile or player.classFileName or player.class
      specName = player.specName or player.spec
    else
      local name = provider.GetPlayerName and provider:GetPlayerName(winnerKey) or winnerKey
      if name then
        targetName = name
      end
    end
  end
  local details = {
    itemID = session.itemID,
    itemName = session.itemName,
    voteType = winnerVote,
  }
  if not details.itemID and session.itemLink then
    if C_Item and C_Item.GetItemInfoInstant then
      details.itemID = select(1, C_Item.GetItemInfoInstant(session.itemLink))
    elseif GetItemInfoInstant then
      details.itemID = select(1, GetItemInfoInstant(session.itemLink))
    end
  end
  if not details.itemName and session.itemLink then
    details.itemName = session.itemLink
  end
  local baseName = targetName
  if type(baseName) == "string" and not baseName:match("^Player%-") then
    baseName = NS and NS.GetPlayerBaseName and NS:GetPlayerBaseName(baseName) or baseName
  end
  self:LogAuditEvent("ITEM_WON", {
    target = baseName,
    isGuest = isGuest,
    class = classFile,
    spec = specName,
    details = details,
  })
end

local function NormalizeVoteKey(provider, key)
  if provider and provider.GetPlayerName then
    local name = provider:GetPlayerName(key)
    if name and name ~= "" then
      return name
    end
  end
  return key
end

local function SnapshotVotes(votes, provider)
  local snapshot = {}
  local counts = { NEED = 0, GREED = 0, TRANSMOG = 0, PASS = 0 }
  if votes then
    for key, vote in pairs(votes) do
      local displayKey = NormalizeVoteKey(provider, key)
      snapshot[displayKey] = vote
      if vote and counts[vote] ~= nil then
        counts[vote] = counts[vote] + 1
      end
    end
  end
  return snapshot, counts
end

local function SnapshotVoteDetails(details, provider)
  if not details then
    return nil
  end
  local snapshot = {}
  for key, entry in pairs(details or {}) do
    local displayKey = NormalizeVoteKey(provider, key)
    snapshot[displayKey] = {
      voteOriginal = entry.voteOriginal,
      voteEffective = entry.voteEffective,
      reason = entry.reason,
      reasonText = entry.reasonText,
      roll = entry.roll,
      blizzVote = entry.blizzVote,
    }
  end
  return snapshot
end

local function BuildMissingAtLock(expectedVoters, votes, provider)
  if not expectedVoters then
    return nil
  end
  local missing = {}
  for _, key in ipairs(expectedVoters) do
    local displayKey = key and NormalizeVoteKey(provider, key) or nil
    if displayKey and not (votes and votes[displayKey]) then
      missing[#missing + 1] = displayKey
    end
  end
  if #missing == 0 then
    return nil
  end
  return missing
end

local function CountVotes(votes)
  local count = 0
  for _ in pairs(votes or {}) do
    count = count + 1
  end
  return count
end

local function NormalizeMoveMode(mode)
  local value = tostring(mode or ""):upper()
  if value == "BOTTOM" then
    return "END"
  end
  if value == "END" or value == "MIDDLE" or value == "NONE" then
    return value
  end
  return "END"
end

function GLD:GetMoveModeForVoteType(voteType)
  local config = self.db and self.db.config or {}
  if voteType == "TRANSMOG" then
    return NormalizeMoveMode(config.transmogWinnerMove or "NONE")
  end
  if voteType == "GREED" then
    return NormalizeMoveMode(config.greedWinnerMove or "NONE")
  end
  return "END"
end

function GLD:ApplyWinnerMove(winnerKey, voteType)
  if not winnerKey then
    return nil
  end
  local mode = self:GetMoveModeForVoteType(voteType)
  local player = self.db and self.db.players and self.db.players[winnerKey] or nil
  local oldPos = player and player.queuePos or nil
  if mode == "NONE" then
    -- no movement
  elseif mode == "MIDDLE" then
    if self.MoveToQueueMiddle then
      self:MoveToQueueMiddle(winnerKey)
    end
  else
    if self.MoveToQueueBottom then
      self:MoveToQueueBottom(winnerKey)
    end
  end
  local newPos = player and player.queuePos or nil
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "Winner move: vote="
        .. tostring(voteType)
        .. " mode="
        .. tostring(mode)
        .. " pos="
        .. tostring(oldPos)
        .. "->"
        .. tostring(newPos)
    )
  end
  return mode
end

function GLD:CaptureBlizzardRollData(session)
  if not session or not session.itemLink then
    return nil
  end
  if not C_LootHistory or not C_LootHistory.GetItem or not C_LootHistory.GetPlayerInfo then
    return nil
  end
  local numItems = C_LootHistory.GetNumItems and C_LootHistory.GetNumItems() or 0
  if numItems <= 0 then
    return nil
  end
  local rollMap = nil
  for itemIndex = 1, numItems do
    local _, itemLink, _, _, numPlayers = C_LootHistory.GetItem(itemIndex)
    if itemLink and itemLink == session.itemLink and numPlayers and numPlayers > 0 then
      for playerIndex = 1, numPlayers do
        local name, _, rollType, roll = C_LootHistory.GetPlayerInfo(itemIndex, playerIndex)
        local key = name and self.GetRollCandidateKey and self:GetRollCandidateKey(name) or nil
        if key and session.votes and session.votes[key] then
          rollMap = rollMap or {}
          rollMap[key] = roll
          session.voteDetails = session.voteDetails or {}
          local detail = session.voteDetails[key] or {
            voteOriginal = session.votes[key],
            voteEffective = session.votes[key],
          }
          detail.roll = roll
          if rollType and RollTypeToVote then
            detail.blizzVote = RollTypeToVote(rollType)
          end
          session.voteDetails[key] = detail
        end
      end
      break
    end
  end
  return rollMap
end

local function BuildRollResultId(session, result)
  local rollRef = (session and (session.rollKey or session.rollID)) or "unknown"
  local reason = result and (result.resolutionReason or result.rollStatus or result.resolvedBy) or "NORMAL"
  local winner = result and (result.approvedWinnerGuid or result.winnerKey) or nil
  local resolvedAt = result and (result.resolvedAt or result.startedAt) or 0
  return tostring(rollRef) .. ":" .. tostring(reason or "NORMAL") .. ":" .. tostring(winner or "none") .. ":" .. tostring(resolvedAt or 0)
end

local function BuildRollResult(self, session, winnerKey, opts)
  opts = opts or {}
  local provider = opts.provider or (session.isTest and TestProvider or LiveProvider)
  local rollMap = opts.rollMap
  if rollMap == nil and self.CaptureBlizzardRollData then
    rollMap = self:CaptureBlizzardRollData(session)
  end
  if opts.commitAward and winnerKey and LootEngine and LootEngine.CommitAward then
    LootEngine:CommitAward(winnerKey, session, provider)
  end

  local winnerPlayer = winnerKey and provider and provider.GetPlayer and provider:GetPlayer(winnerKey) or nil
  local winnerName = winnerPlayer and winnerPlayer.name or (winnerKey or "None")
  local winnerFull = winnerName
  if winnerPlayer and winnerPlayer.realm and winnerPlayer.realm ~= "" then
    winnerFull = winnerPlayer.name .. "-" .. winnerPlayer.realm
  end
  if not winnerKey then
    winnerName = "Unclaimed"
    winnerFull = "Unclaimed"
  end
  local winnerVote = session.votes and winnerKey and session.votes[winnerKey] or nil
  local winnerRoll = rollMap and winnerKey and rollMap[winnerKey] or nil
  if winnerRoll == nil and winnerKey and session.voteDetails and session.voteDetails[winnerKey] then
    winnerRoll = session.voteDetails[winnerKey].roll
  end
  local winnerShortName = winnerName
  if winnerFull and winnerFull ~= "" and NS and NS.SplitNameRealm then
    local short = select(1, NS:SplitNameRealm(winnerFull))
    if short and short ~= "" then
      winnerShortName = short
    end
  end
  if not winnerKey then
    winnerShortName = "Unclaimed"
  end
  local winnerClassToken = winnerPlayer
    and (winnerPlayer.classToken or winnerPlayer.classFile or winnerPlayer.classFileName or winnerPlayer.class)
    or nil
  if winnerClassToken then
    winnerClassToken = tostring(winnerClassToken):upper()
  end
  local winnerIsGuest = winnerPlayer and self.IsGuestEntry and self:IsGuestEntry(winnerPlayer) or false

  local resolvedAt = GetServerTime()
  local voteSnapshot, voteCounts = SnapshotVotes(session.votes, provider)
  local voteDetails = SnapshotVoteDetails(session.voteDetails, provider)
  local missingAtLock = BuildMissingAtLock(session.expectedVoters, voteSnapshot, provider)
  local startedAt = session.createdAt or resolvedAt
  local authorityGUID = self:GetAuthorityGUID()
  local authorityName = self:GetAuthorityName()
  local result = {
    rollID = session.rollID,
    rollKey = session.rollKey,
    itemLink = session.itemLink,
    itemName = session.itemName,
    winnerKey = winnerKey,
    winnerName = winnerFull,
    winnerShortName = winnerShortName,
    winnerClassToken = winnerClassToken,
    winnerIsGuest = winnerIsGuest,
    votes = voteSnapshot,
    voteCounts = voteCounts,
    voteDetails = voteDetails,
    missingAtLock = missingAtLock,
    startedAt = startedAt,
    resolvedAt = resolvedAt,
    resolvedBy = opts.resolvedBy or session.resolvedBy or "NORMAL",
    overrideBy = opts.overrideBy,
    authorityGUID = authorityGUID,
    authorityName = authorityName,
    winnerVote = winnerVote,
    winningRoll = winnerRoll,
    blizzNeedAllowed = session.blizzNeedAllowed,
    blizzGreedAllowed = session.blizzGreedAllowed,
    blizzTransmogAllowed = session.blizzTransmogAllowed,
    rollStatus = opts.rollStatus,
    computedWinnerGuid = opts.computedWinnerGuid,
    approvedWinnerGuid = opts.approvedWinnerGuid,
    resolutionReason = opts.resolutionReason,
    approvedByGuid = opts.approvedByGuid,
    approvedByName = opts.approvedByName,
    markedByGuid = opts.markedByGuid,
    markedByName = opts.markedByName,
  }
  result.resultId = BuildRollResultId(session, result)
  local overrideId, instructionVote, instructionText = self:ResolveInstructionOverride(result)
  if overrideId then
    result.instructionOverride = overrideId
    result.instructionVote = instructionVote
    result.instructionText = instructionText
  end
  return result, winnerVote, provider
end

local function RemoveActiveRoll(self, session)
  local activeKey = session and session.rollKey
  if not activeKey and self.FindActiveRoll then
    activeKey = select(1, self:FindActiveRoll(nil, session and session.rollID))
  end
  if activeKey and self.activeRolls then
    self.activeRolls[activeKey] = nil
  end
end

function GLD:CommitResolvedRoll(session, result, opts)
  opts = opts or {}
  if not session or not result then
    return false
  end
  if self.GetRollStatus and self:IsRollStatusTerminal(self:GetRollStatus(session)) then
    return false
  end
  session.locked = true
  session.status = result.rollStatus or opts.sessionStatus or "CLOSED"
  session.result = result
  session.resolutionReason = result.resolutionReason or session.resolutionReason
  session.approvedWinnerGuid = result.approvedWinnerGuid or session.approvedWinnerGuid
  session.computedWinnerGuid = result.computedWinnerGuid or session.computedWinnerGuid

  if result.winnerKey and self.ApplyCoverOutcomeForResult then
    self:ApplyCoverOutcomeForResult(result)
  end
  if opts.logAudit ~= false then
    self:LogItemWonAudit(session, result.winnerKey, result.winnerVote, opts.provider)
  end

  if not session.isTest then
    self:RecordRollHistory(result)
  end
  if session.isTest then
    self:RecordTestSessionLoot(result, session)
  else
    self:RecordSessionLoot(result, session)
  end

  if session.isTest and result.winnerKey and self.MoveTestPlayerToQueueBottom then
    self:MoveTestPlayerToQueueBottom(result.winnerKey)
    if NS.TestUI and NS.TestUI.RefreshTestPanel then
      NS.TestUI:RefreshTestPanel()
    end
  end

  if self:IsAuthority() and not session.isTest and opts.broadcast ~= false then
    if opts.announce ~= false then
      self:AnnounceRollResult(result)
    end
    if opts.applyWinnerMove ~= false and result.winnerKey then
      self:ApplyWinnerMove(result.winnerKey, result.winnerVote)
      self:BroadcastSnapshot()
    end
    if IsInRaid() then
      self:SendCommMessageSafe(NS.MSG.ROLL_RESULT, result, "RAID")
      if result.rollStatus == "APPROVED" and result.resolutionReason == "CONFIRMED_OBTAINED" and NS.MSG.ROLL_APPROVED then
        self:SendCommMessageSafe(NS.MSG.ROLL_APPROVED, {
          rollID = result.rollID,
          rollKey = result.rollKey,
          approvedWinnerGuid = result.approvedWinnerGuid or result.winnerKey,
          approvedByGuid = result.approvedByGuid or UnitGUID("player"),
          authorityGUID = self:GetAuthorityGUID(),
          authorityName = self:GetAuthorityName(),
        }, "RAID")
      elseif result.rollStatus == "LOST" and NS.MSG.ROLL_LOST then
        self:SendCommMessageSafe(NS.MSG.ROLL_LOST, {
          rollID = result.rollID,
          rollKey = result.rollKey,
          markedByGuid = result.markedByGuid or UnitGUID("player"),
          authorityGUID = self:GetAuthorityGUID(),
          authorityName = self:GetAuthorityName(),
        }, "RAID")
      end
    end
  end

  RemoveActiveRoll(self, session)
  session.status = "CLOSED"
  if self.CleanupActiveRolls then
    self:CleanupActiveRolls(1800)
  end
  if self:IsDebugEnabled() then
    self:Debug(
      "Roll resolved: rollID="
        .. tostring(session.rollID)
        .. " rollKey="
        .. tostring(session.rollKey)
        .. " reason="
        .. tostring(result.resolutionReason or result.rollStatus or result.resolvedBy)
        .. " active="
        .. tostring(CountActiveRolls(self.activeRolls))
    )
  end
  if self.UI and self.UI.RefreshLootWindow then
    self.UI:RefreshLootWindow()
  end
  return true
end

function GLD:SetRollPendingApproval(session, computedResult, winnerKey)
  if not session or not computedResult then
    return false
  end
  if self.GetRollStatus and self:GetRollStatus(session) ~= "ACTIVE" then
    return false
  end
  session.locked = true
  session.status = "PENDING_APPROVAL"
  session.computedWinnerGuid = winnerKey
  session.approvedWinnerGuid = nil
  session.resolutionReason = "PENDING_APPROVAL"
  session.computedResult = computedResult

  if self.BroadcastRollSession then
    self:BroadcastRollSession(session, { snapshot = true, reopen = true })
  end
  if self:IsAuthority() and IsInRaid() and NS.MSG.ROLL_PENDING_APPROVAL then
    self:SendCommMessageSafe(NS.MSG.ROLL_PENDING_APPROVAL, {
      rollID = session.rollID,
      rollKey = session.rollKey,
      itemLink = session.itemLink,
      itemName = session.itemName,
      status = "PENDING_APPROVAL",
      computedWinnerGuid = winnerKey,
      computedResult = computedResult,
      votes = session.votes,
      authorityGUID = self:GetAuthorityGUID(),
      authorityName = self:GetAuthorityName(),
    }, "RAID")
  end
  if self:IsDebugEnabled() then
    self:Debug(
      "Roll pending approval: rollID="
        .. tostring(session.rollID)
        .. " rollKey="
        .. tostring(session.rollKey)
        .. " computedWinner="
        .. tostring(winnerKey)
    )
  end
  if self.UI and self.UI.RefreshLootWindow then
    self.UI:RefreshLootWindow({ forceShow = true, reopen = true, onlyIfPending = true, trigger = "force" })
  end
  return true
end

function GLD:IsTrackedAddonHolderRecipient(winnerKey, session)
  if not winnerKey then
    return false
  end
  local key = winnerKey
  if self.GetRollCandidateKey then
    key = self:GetRollCandidateKey(winnerKey) or winnerKey
  end
  local player = self.db and self.db.players and self.db.players[key] or nil
  if player and self.IsGuestEntry and self:IsGuestEntry(player) then
    return true
  end
  if player and player.source == "guild" then
    return true
  end
  if IsInRaid() then
    local ourGuild = self.GetOurGuildName and self:GetOurGuildName() or nil
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if UnitExists(unit) and UnitIsConnected(unit) then
        local unitKey = NS:GetPlayerKeyFromUnit(unit)
        if unitKey == key then
          local guildName = GetGuildInfo(unit)
          if ourGuild and guildName and guildName == ourGuild then
            return true
          end
          break
        end
      end
    end
  end
  return false
end

function GLD:ConfirmPendingRoll(rollRef, approvedWinnerGuid, opts)
  opts = opts or {}
  if not opts.skipPermission and self.CanAccessAdminUI and not self:CanAccessAdminUI() then
    self:ShowPermissionDeniedPopup()
    return false
  end
  if not self:IsAuthority() then
    if self.RequestAdminAction then
      return self:RequestAdminAction("ROLL_CONFIRM_OBTAINED", {
        rollKey = rollRef,
        approvedWinnerGuid = approvedWinnerGuid,
      })
    end
    return false
  end
  local rollKey = nil
  local rollID = nil
  local session = nil
  if type(rollRef) == "table" then
    session = rollRef
  elseif type(rollRef) == "number" then
    rollID = rollRef
  else
    rollKey = rollRef
  end
  if not session and self.FindActiveRoll then
    _, session = self:FindActiveRoll(rollKey, rollID)
  end
  if not session then
    return false
  end
  if self.GetRollStatus and self:GetRollStatus(session) ~= "PENDING_APPROVAL" then
    return false
  end
  local winnerKey = approvedWinnerGuid or session.computedWinnerGuid
  if not winnerKey then
    self:Print("Cannot confirm: no computed winner is available.")
    return false
  end
  if self.GetRollCandidateKey then
    winnerKey = self:GetRollCandidateKey(winnerKey) or winnerKey
  end
  if not self:IsTrackedAddonHolderRecipient(winnerKey, session) then
    self:Print("Cannot confirm obtained: recipient is not a tracked guild/guest addon-holder.")
    return false
  end

  local rollMap = self:CaptureBlizzardRollData(session)
  local approvedByGuid = opts.actorGuid or UnitGUID("player")
  local approvedByName = opts.actorName
  if not approvedByName or approvedByName == "" then
    approvedByName = self:GetAuthorityName() or self:GetUnitFullName("player") or UnitName("player") or "Unknown"
  end
  local result, _, provider = BuildRollResult(self, session, winnerKey, {
    provider = session.isTest and TestProvider or LiveProvider,
    rollMap = rollMap,
    commitAward = true,
    resolvedBy = "MANUAL_APPROVAL",
    rollStatus = "APPROVED",
    computedWinnerGuid = session.computedWinnerGuid or winnerKey,
    approvedWinnerGuid = winnerKey,
    resolutionReason = "CONFIRMED_OBTAINED",
    approvedByGuid = approvedByGuid,
    approvedByName = approvedByName,
  })
  session.approvedWinnerGuid = winnerKey
  session.status = "APPROVED"
  if self.LogAuditEvent and not session.isTest then
    self:LogAuditEvent("ROLL_APPROVED", {
      actor = approvedByName,
      target = winnerKey,
      details = tostring(session.rollKey or session.rollID) .. "|" .. tostring(session.itemLink or session.itemName or "Item"),
    })
  end
  return self:CommitResolvedRoll(session, result, {
    provider = provider,
    announce = true,
    applyWinnerMove = true,
  })
end

function GLD:MarkPendingRollLost(rollRef, opts)
  opts = opts or {}
  if not opts.skipPermission and self.CanAccessAdminUI and not self:CanAccessAdminUI() then
    self:ShowPermissionDeniedPopup()
    return false
  end
  if not self:IsAuthority() then
    if self.RequestAdminAction then
      return self:RequestAdminAction("ROLL_MARK_LOST", {
        rollKey = rollRef,
      })
    end
    return false
  end
  local rollKey = nil
  local rollID = nil
  local session = nil
  if type(rollRef) == "table" then
    session = rollRef
  elseif type(rollRef) == "number" then
    rollID = rollRef
  else
    rollKey = rollRef
  end
  if not session and self.FindActiveRoll then
    _, session = self:FindActiveRoll(rollKey, rollID)
  end
  if not session then
    return false
  end
  if self.GetRollStatus and self:GetRollStatus(session) ~= "PENDING_APPROVAL" then
    return false
  end

  local markedByGuid = opts.actorGuid or UnitGUID("player")
  local markedByName = opts.actorName
  if not markedByName or markedByName == "" then
    markedByName = self:GetAuthorityName() or self:GetUnitFullName("player") or UnitName("player") or "Unknown"
  end
  local result, _, provider = BuildRollResult(self, session, nil, {
    provider = session.isTest and TestProvider or LiveProvider,
    commitAward = false,
    resolvedBy = "MANUAL_APPROVAL",
    rollStatus = "LOST",
    computedWinnerGuid = session.computedWinnerGuid,
    approvedWinnerGuid = nil,
    resolutionReason = "LOST",
    markedByGuid = markedByGuid,
    markedByName = markedByName,
  })
  session.status = "LOST"
  session.resolutionReason = "LOST"
  if self.LogAuditEvent and not session.isTest then
    self:LogAuditEvent("ROLL_LOST", {
      actor = markedByName,
      details = tostring(session.rollKey or session.rollID) .. "|" .. tostring(session.itemLink or session.itemName or "Item"),
    })
  end
  return self:CommitResolvedRoll(session, result, {
    provider = provider,
    announce = false,
    applyWinnerMove = false,
  })
end

function GLD:FinalizeRoll(session)
  if not session then
    return
  end
  if self.GetRollStatus and self:GetRollStatus(session) ~= "ACTIVE" then
    return
  end
  if session.locked then
    return
  end
  if session and not session.isTest and ((self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive())) then
    return
  end
  if not session.isTest and not self:IsAuthority() then
    return
  end

  local rollMap = self:CaptureBlizzardRollData(session)
  local winnerKey = self:ResolveRollWinner(session)
  if self:IsDebugEnabled() then
    local totalVotes = CountVotes(session.votes)
    local expectedCount = session.expectedVoters and #session.expectedVoters or 0
    self:Debug(
      "Finalize roll: rollID="
        .. tostring(session.rollID)
        .. " votes="
        .. tostring(totalVotes)
        .. "/"
        .. tostring(expectedCount)
        .. " winnerKey="
        .. tostring(winnerKey)
        .. " pugsMode="
        .. tostring(self.GetPugsInRaid and self:GetPugsInRaid())
    )
  end

  if not session.isTest and self.GetPugsInRaid and self:GetPugsInRaid() then
    local pendingResult = BuildRollResult(self, session, winnerKey, {
      provider = session.isTest and TestProvider or LiveProvider,
      rollMap = rollMap,
      commitAward = false,
      resolvedBy = "PENDING_APPROVAL",
      rollStatus = "PENDING_APPROVAL",
      computedWinnerGuid = winnerKey,
      approvedWinnerGuid = nil,
      resolutionReason = "PENDING_APPROVAL",
    })
    self:SetRollPendingApproval(session, pendingResult, winnerKey)
    return
  end

  local result, _, provider = BuildRollResult(self, session, winnerKey, {
    provider = session.isTest and TestProvider or LiveProvider,
    rollMap = rollMap,
    commitAward = true,
    resolvedBy = session.resolvedBy or "NORMAL",
    rollStatus = "APPROVED",
    computedWinnerGuid = winnerKey,
    approvedWinnerGuid = winnerKey,
    resolutionReason = "AUTO_FINALIZED",
  })
  session.status = "APPROVED"
  self:CommitResolvedRoll(session, result, {
    provider = provider,
    announce = true,
    applyWinnerMove = true,
  })
end

local function SplitOverrideWinnerIdentity(key)
  if type(key) ~= "string" or key == "" then
    return nil, nil, nil
  end
  if key:find("^Player%-") then
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

local function ResolveAdminOverrideWinnerKey(self, provider, winnerKey)
  if not winnerKey then
    return nil, nil
  end
  local resolved = winnerKey
  if self.GetRollCandidateKey then
    resolved = self:GetRollCandidateKey(resolved) or resolved
  end
  if provider and provider.GetPlayer and provider:GetPlayer(resolved) then
    return resolved, nil
  end
  if not self.FindApprovedGuestEntry then
    return resolved, nil
  end

  local guid, name, realm = SplitOverrideWinnerIdentity(resolved)
  if not guid and not name then
    guid, name, realm = SplitOverrideWinnerIdentity(winnerKey)
  end
  if provider and provider.GetPlayerName then
    local providerName = provider:GetPlayerName(resolved)
    if providerName and providerName ~= "" and providerName ~= resolved then
      local _, providerBaseName, providerRealm = SplitOverrideWinnerIdentity(providerName)
      if not name then
        name = providerBaseName
      end
      if not realm then
        realm = providerRealm
      end
    end
  end
  local guestEntry, guestKey = self:FindApprovedGuestEntry(guid, name, realm)
  if guestKey and guestKey ~= "" then
    return guestKey, guestEntry
  end
  return resolved, guestEntry
end

function GLD:ApplyAdminOverride(session, winnerKey)
  if not session or session.locked then
    return false
  end
  if session and not session.isTest and ((self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive())) then
    return false
  end
  if not self:IsAuthority() then
    return false
  end
  local isPass = not winnerKey or winnerKey == "" or winnerKey == "GLD_FORCE_PASS"
  if isPass then
    winnerKey = nil
  end
  local provider = session.isTest and TestProvider or LiveProvider
  local guestEntry = nil
  if winnerKey then
    winnerKey, guestEntry = ResolveAdminOverrideWinnerKey(self, provider, winnerKey)
  end
  local overrideBy = self:GetAuthorityName() or self:GetUnitFullName("player") or UnitName("player") or "Unknown"
  local rollMap = self:CaptureBlizzardRollData(session)
  local result, _, resolvedProvider = BuildRollResult(self, session, winnerKey, {
    provider = provider,
    rollMap = rollMap,
    commitAward = winnerKey ~= nil,
    resolvedBy = "OVERRIDE",
    overrideBy = overrideBy,
    rollStatus = "APPROVED",
    computedWinnerGuid = winnerKey,
    approvedWinnerGuid = winnerKey,
    resolutionReason = "OVERRIDE",
    approvedByGuid = UnitGUID("player"),
    approvedByName = overrideBy,
  })
  if result and winnerKey and guestEntry and (not result.winnerName or result.winnerName == winnerKey) then
    local guestName = guestEntry.name
    local guestRealm = guestEntry.realm
    if guestName and guestName ~= "" then
      result.winnerName = guestRealm and guestRealm ~= "" and (guestName .. "-" .. guestRealm) or guestName
      result.winnerShortName = guestName
      result.winnerIsGuest = true
    end
  end
  session.status = "APPROVED"
  if self:IsDebugEnabled() then
    self:Debug(
      "Override applied: rollID="
        .. tostring(session.rollID)
        .. " item="
        .. tostring(session.itemLink or session.itemName or "Item")
        .. " winner="
        .. tostring(result.winnerName)
        .. " winnerKey="
        .. tostring(result.winnerKey)
        .. " winnerVote="
        .. tostring(result.winnerVote)
        .. " by="
        .. tostring(overrideBy)
    )
  end
  return self:CommitResolvedRoll(session, result, {
    provider = resolvedProvider,
    announce = true,
    applyWinnerMove = true,
  })
end

function GLD:RecordTestSessionLoot(result, session)
  if not result or not self.testDb or not self.testDb.testSession or not self.testDb.testSession.active then
    return
  end
  local testSession = self:GetActiveTestSession()
  if not testSession then
    return
  end

  local lootEntry = {
    rollID = result.rollID,
    itemLink = result.itemLink,
    itemName = result.itemName,
    winnerKey = result.winnerKey,
    winnerName = result.winnerName,
    winnerIsGuest = result.winnerIsGuest,
    rollStatus = result.rollStatus,
    computedWinnerGuid = result.computedWinnerGuid,
    approvedWinnerGuid = result.approvedWinnerGuid,
    resolutionReason = result.resolutionReason,
    votes = result.votes,
    voteCounts = result.voteCounts,
    voteDetails = result.voteDetails,
    missingAtLock = result.missingAtLock,
    startedAt = result.startedAt,
    resolvedAt = result.resolvedAt or GetServerTime(),
    resolvedBy = result.resolvedBy or "NORMAL",
    overrideBy = result.overrideBy,
    approvedByGuid = result.approvedByGuid,
    approvedByName = result.approvedByName,
    markedByGuid = result.markedByGuid,
    markedByName = result.markedByName,
    winnerVote = result.winnerVote,
    winningRoll = result.winningRoll,
    resultId = result.resultId,
    instructionOverride = result.instructionOverride,
    instructionVote = result.instructionVote,
    instructionText = result.instructionText,
    blizzNeedAllowed = result.blizzNeedAllowed,
    blizzGreedAllowed = result.blizzGreedAllowed,
    blizzTransmogAllowed = result.blizzTransmogAllowed,
  }

  if self:IsDebugEnabled() then
    self:Debug("Test history entry saved votes: rollID=" .. tostring(result.rollID) .. " votes=" .. tostring(CountVotes(lootEntry.votes)))
  end

  testSession.loot = testSession.loot or {}
  table.insert(testSession.loot, 1, lootEntry)

  local encounterId = session and session.testEncounterId or nil
  local encounterName = session and session.testEncounterName or nil
  if encounterId or encounterName then
    testSession.bosses = testSession.bosses or {}
    local bossEntry = nil
    for _, boss in ipairs(testSession.bosses) do
      if encounterId and boss.encounterId == encounterId then
        bossEntry = boss
        break
      end
      if not encounterId and encounterName and boss.encounterName == encounterName then
        bossEntry = boss
        break
      end
    end
    if not bossEntry then
      bossEntry = {
        encounterId = encounterId,
        encounterName = encounterName or "Encounter",
        killedAt = GetServerTime(),
        loot = {},
      }
      table.insert(testSession.bosses, bossEntry)
    end
    bossEntry.loot = bossEntry.loot or {}
    table.insert(bossEntry.loot, 1, lootEntry)
  end
end

function GLD:RecordSessionLoot(result, session)
  if not result or not self.db.session or not self.db.session.active then
    return
  end
  local raidSession = self.GetActiveRaidSession and self:GetActiveRaidSession() or nil
  if not raidSession then
    return
  end

  local lootEntry = {
    rollID = result.rollID,
    itemLink = result.itemLink,
    itemName = result.itemName,
    winnerKey = result.winnerKey,
    winnerName = result.winnerName,
    winnerIsGuest = result.winnerIsGuest,
    rollStatus = result.rollStatus,
    computedWinnerGuid = result.computedWinnerGuid,
    approvedWinnerGuid = result.approvedWinnerGuid,
    resolutionReason = result.resolutionReason,
    votes = result.votes,
    voteCounts = result.voteCounts,
    voteDetails = result.voteDetails,
    missingAtLock = result.missingAtLock,
    startedAt = result.startedAt,
    resolvedAt = result.resolvedAt or GetServerTime(),
    resolvedBy = result.resolvedBy or "NORMAL",
    overrideBy = result.overrideBy,
    approvedByGuid = result.approvedByGuid,
    approvedByName = result.approvedByName,
    markedByGuid = result.markedByGuid,
    markedByName = result.markedByName,
    winnerVote = result.winnerVote,
    winningRoll = result.winningRoll,
    resultId = result.resultId,
    instructionOverride = result.instructionOverride,
    instructionVote = result.instructionVote,
    instructionText = result.instructionText,
    blizzNeedAllowed = result.blizzNeedAllowed,
    blizzGreedAllowed = result.blizzGreedAllowed,
    blizzTransmogAllowed = result.blizzTransmogAllowed,
  }

  if self:IsDebugEnabled() then
    self:Debug("History entry saved votes: rollID=" .. tostring(result.rollID) .. " votes=" .. tostring(CountVotes(lootEntry.votes)))
  end

  raidSession.loot = raidSession.loot or {}
  table.insert(raidSession.loot, 1, lootEntry)

  local bossCtx = self.db.session.currentBoss
  if bossCtx and bossCtx.encounterID and bossCtx.killedAt then
    for _, boss in ipairs(raidSession.bosses or {}) do
      if boss.encounterID == bossCtx.encounterID and boss.killedAt == bossCtx.killedAt then
        boss.loot = boss.loot or {}
        table.insert(boss.loot, 1, lootEntry)
        break
      end
    end
  end
  if self.TouchRaidSession then
    self:TouchRaidSession(raidSession, "loot")
  end
  if self.UI and self.UI.RefreshHistoryIfOpen then
    self.UI:RefreshHistoryIfOpen()
  end
end

function GLD:CheckRollCompletion(session)
  if not session or session.locked then
    return
  end
  if self.GetRollStatus and self:GetRollStatus(session) ~= "ACTIVE" then
    return
  end
  local expected = session.expectedVoters or {}
  local votes = session.votes or {}
  local count = 0
  for _, key in ipairs(expected) do
    if votes[key] then
      count = count + 1
    end
  end
  if count >= #expected and #expected > 0 then
    self:FinalizeRoll(session)
  end
end

function GLD:NoteMismatch(session, playerName, expectedVote, actualVote)
  if not session then
    return
  end
  session.mismatches = session.mismatches or {}
  table.insert(session.mismatches, {
    name = playerName,
    expected = expectedVote,
    actual = actualVote,
  })
  if self:IsAuthority() then
    local msg = string.format("GLD mismatch: %s declared %s but rolled %s", tostring(playerName), tostring(expectedVote), tostring(actualVote))
    if IsInRaid() then
      SendChatMessage(msg, "RAID")
      self:SendCommMessageSafe(NS.MSG.ROLL_MISMATCH, {
        rollID = session.rollID,
        rollKey = session.rollKey,
        name = playerName,
        expected = expectedVote,
        actual = actualVote,
      }, "RAID")
    end
  end
end

function GLD:OnStartLootRoll(event, rollID, rollTime, lootHandle)
  local debugEnabled = self:IsDebugEnabled()
  if type(rollID) ~= "number" then
    if debugEnabled then
      self:Debug("Ignoring START_LOOT_ROLL (invalid rollID): event=" .. tostring(event) .. " rollID=" .. tostring(rollID))
    end
    return
  end
  if (self.IsEnabled and not self:IsEnabled()) or (self.IsSessionActive and not self:IsSessionActive()) then
    if debugEnabled then
      self:Debug(
        "Ignoring START_LOOT_ROLL (loot gate disabled): enabled="
          .. tostring(self.IsEnabled and self:IsEnabled() or false)
          .. " sessionActive="
          .. tostring(self.IsSessionActive and self:IsSessionActive() or false)
      )
    end
    return
  end
  if not (self.GetPugsInRaid and self:GetPugsInRaid()) and self.LockLootRollButtons then
    self:LockLootRollButtons(rollID)
  end
  if self.ApplyCoverStateForRoll then
    self:ApplyCoverStateForRoll(rollID)
  end
  if not IsInRaid() then
    if debugEnabled then
      self:Debug("Ignoring START_LOOT_ROLL (not in raid): inRaid=" .. tostring(IsInRaid()))
    end
    return
  end
  if not self:IsAuthority() then
    if debugEnabled then
      self:Debug("Ignoring START_LOOT_ROLL (not authority): leader=" .. tostring(UnitIsGroupLeader("player")) .. " assistant=" .. tostring(UnitIsGroupAssistant("player")))
    end
    return
  end

  self.activeRolls = self.activeRolls or {}
  if self.CleanupActiveRolls then
    self:CleanupActiveRolls(1800)
  end
  local existingKey = nil
  local existingSession = nil
  if self.FindActiveRoll then
    existingKey, existingSession = self:FindActiveRoll(nil, rollID)
  end
  if existingSession and not (self.IsRollSessionExpired and self:IsRollSessionExpired(existingSession, nil, 1800)) then
    if self:IsDebugEnabled() then
      self:Debug("Duplicate START_LOOT_ROLL ignored: rollID=" .. tostring(rollID))
    end
    return
  end
  if existingKey and existingSession then
    self.activeRolls[existingKey] = nil
  end

  local texture, name, count, quality, bop, canNeed, canGreed, canDE, canTransmog, reason = GetLootRollItemInfo(rollID)
  local link = GetLootRollItemLink(rollID)
  if debugEnabled and not link and not name then
    self:Debug("START_LOOT_ROLL missing item info: rollID=" .. tostring(rollID) .. " reason=" .. tostring(reason) .. " bop=" .. tostring(bop))
  end
  local itemID = nil
  if link and GetItemInfoInstant then
    itemID = select(1, GetItemInfoInstant(link))
  end

  local rollTimeMs = tonumber(rollTime) or 120000
  local createdAt = GetServerTime()
  local rollExpiresAt = rollTimeMs > 0 and (createdAt + math.floor(rollTimeMs / 1000)) or nil

  local rollKey = nil
  if self.BuildRollNonce and self.MakeRollKey then
    rollKey = self:MakeRollKey(rollID, self:BuildRollNonce())
    if rollKey and self.activeRolls[rollKey] then
      rollKey = self:MakeRollKey(rollID, self:BuildRollNonce())
    end
  end
  rollKey = rollKey or (self.GetLegacyRollKey and self:GetLegacyRollKey(rollID)) or (tostring(rollID) .. "@legacy")

  local session = {
    rollID = rollID,
    rollKey = rollKey,
    status = "ACTIVE",
    rollTime = rollTimeMs,
    rollExpiresAt = rollExpiresAt,
    itemLink = link,
    itemName = name,
    itemID = itemID,
    itemIcon = texture,
    quality = quality,
    count = count,
    canNeed = canNeed,
    canGreed = canGreed,
    canTransmog = canTransmog,
    blizzNeedAllowed = canNeed,
    blizzGreedAllowed = canGreed,
    blizzTransmogAllowed = canTransmog,
    votes = {},
    expectedVoters = self:BuildExpectedVoters(),
    createdAt = createdAt,
  }
  session.restrictionSnapshot = self:BuildRollRestrictionSnapshot(session)
  self.activeRolls[rollKey] = session

  if self:IsDebugEnabled() then
    local snapshot = session.restrictionSnapshot
    local roleText = snapshot and FormatTrinketRoleList(snapshot.trinketRoles) or "none"
    self:Debug(
      "Roll restriction snapshot: rollID="
        .. tostring(session.rollID)
        .. " item="
        .. tostring(session.itemLink or session.itemName or "Unknown")
        .. " trinketRoles="
        .. tostring(roleText)
    )
  end

  if self:IsDebugEnabled() then
    self:Debug("Roll started detected: rollID=" .. tostring(rollID) .. " rollKey=" .. tostring(rollKey) .. " item=" .. tostring(link or name or "Unknown"))
    self:Debug("Active rolls: " .. tostring(CountActiveRolls(self.activeRolls)))
  end

  if link then
    self:RequestItemData(link)
  end

  self:BroadcastRollSession(session)

  if self.UI and self.UI.RefreshLootWindow then
    self.UI:RefreshLootWindow({ forceShow = true })
  end

  local delay = (tonumber(rollTimeMs) or 120000) / 1000
  session.timerStarted = true
  C_Timer.After(delay, function()
    local active = self.activeRolls and rollKey and self.activeRolls[rollKey] or nil
    if active and not active.locked and (not self.GetRollStatus or self:GetRollStatus(active) == "ACTIVE") then
      self:FinalizeRoll(active)
    end
  end)

  C_Timer.After(delay + 1, function()
    self:OnLootHistoryRollChanged()
  end)
  C_Timer.After(delay + 6, function()
    self:OnLootHistoryRollChanged()
  end)
end

function GLD:OnCancelLootRoll(event, rollID)
  if type(rollID) ~= "number" then
    return
  end
  if self.ClearCoverOverridesForRoll then
    self:ClearCoverOverridesForRoll(rollID)
  end
  if self.UnlockLootRollButtons then
    self:UnlockLootRollButtons(rollID)
  end
end

function GLD:OnLootHistoryRollChanged()
  if not C_LootHistory or not C_LootHistory.GetItem then
    return
  end
  if not self.activeRolls then
    return
  end
  local numItems = C_LootHistory.GetNumItems and C_LootHistory.GetNumItems() or 0
  if numItems <= 0 then
    return
  end
  -- Index active rolls by item link to avoid scanning all rolls per loot history item.
  local sessionsByLink = nil
  for _, session in pairs(self.activeRolls) do
    if session and session.itemLink and session.votes then
      sessionsByLink = sessionsByLink or {}
      local list = sessionsByLink[session.itemLink]
      if not list then
        list = {}
        sessionsByLink[session.itemLink] = list
      end
      list[#list + 1] = session
    end
  end
  if not sessionsByLink then
    return
  end
  for itemIndex = 1, numItems do
    local lootID, itemLink, itemQuality, itemGUID, numPlayers = C_LootHistory.GetItem(itemIndex)
    if itemLink and numPlayers and numPlayers > 0 then
      local sessions = sessionsByLink[itemLink]
      if sessions then
        for _, session in ipairs(sessions) do
          for playerIndex = 1, numPlayers do
            local name, class, rollType, roll = C_LootHistory.GetPlayerInfo(itemIndex, playerIndex)
            local declaredKey = self:GetRollCandidateKey(name)
            local declaredVote = declaredKey and session.votes[declaredKey] or nil
            local actualVote = RollTypeToVote(rollType)
            if declaredKey and declaredVote and roll ~= nil then
              session.voteDetails = session.voteDetails or {}
              local detail = session.voteDetails[declaredKey] or {
                voteOriginal = declaredVote,
                voteEffective = declaredVote,
              }
              detail.roll = roll
              if rollType then
                detail.blizzVote = RollTypeToVote(rollType)
              end
              session.voteDetails[declaredKey] = detail
            end
            if declaredVote and actualVote and declaredVote ~= actualVote then
              self:NoteMismatch(session, name, declaredVote, actualVote)
            end
          end
        end
      end
    end
  end
end
