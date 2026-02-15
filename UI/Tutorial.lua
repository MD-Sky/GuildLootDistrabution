local _, NS = ...

local GLD = NS.GLD
local UI = NS.UI

local Tutorial = {}
UI.Tutorial = Tutorial

if not SlashCmdList["GLDTUTDEBUG"] then
  SLASH_GLDTUTDEBUG1 = "/tutdebug"
  SlashCmdList["GLDTUTDEBUG"] = function()
    Tutorial.wrapLayoutDebug = not Tutorial.wrapLayoutDebug
    if GLD and GLD.Print then
      GLD:Print("Tutorial wrap debug " .. (Tutorial.wrapLayoutDebug and "enabled" or "disabled"))
    else
      DEFAULT_CHAT_FRAME:AddMessage("Tutorial wrap debug " .. (Tutorial.wrapLayoutDebug and "enabled" or "disabled"))
    end
  end
end

local GOLD = { 1, 0.82, 0, 1 }
local POPUP_BG = { 0, 0, 0, 0.88 }
local DIM_ALPHA = 0.55
local SYSTEM_FRAME_PAD = 12
local SYSTEM_FRAME_WIDTH = 980
local SYSTEM_FRAME_MIN_HEIGHT = 280
local SYSTEM_QUEUE_WIDTH = 500
local SYSTEM_EXPLAIN_WIDTH = 430
local SYSTEM_RULES_GAP = 8
local SYSTEM_ROW_HEIGHT = 22
local SYSTEM_ROW_GAP = 4
local SYSTEM_LOG_LINES = 6
local SYSTEM_STEP_DELAY = 2.6
local SYSTEM_ITEM_NAME = "Plate Helm"
local SYSTEM_ITEM_ARMOR = "Plate"
local SYSTEM_POS_GREEN = "3bd65a"
local SYSTEM_POS_RED = "ff5b5b"
local SYSTEM_POS_GRAY = "b0b0b0"

local SYSTEM_SAMPLE_ROSTER = {
  { name = "Ayla", className = "Mage", armorType = "Cloth", present = true, eligible = true, pos = 1 },
  { name = "Borin", className = "Warrior", armorType = "Plate", present = true, eligible = true, pos = 2 },
  { name = "Cora", className = "Rogue", armorType = "Leather", present = true, eligible = true, pos = 3 },
  { name = "Dax", className = "Paladin", armorType = "Plate", present = true, eligible = true, pos = 4 },
  { name = "Eryn", className = "Priest", armorType = "Cloth", present = true, eligible = true, pos = 5 },
}

Tutorial.Offsets = {
  default = { pad = 8 },
  header = { padL = 6, padR = 6, padT = 6, padB = 6 },
  buttonRow = { padL = 12, padR = 12, padT = 12, padB = 12 },
  panel = { padL = 10, padR = 10, padT = 10, padB = 10 },
  row = { padL = 8, padR = 8, padT = 6, padB = 6 },
}

Tutorial.Layout = {
  maxWidth = 360,
  padX = 14,
  padTop = 14,
  padBottom = 12,
  titleGap = 8,
  buttonsGap = 12,
  buttonsMinGap = 16,
  controlsGap = 8,
  controlsMinWidth = 360,
  minHeight = 180,
  anchorPad = 16,
}

Tutorial.wrapLayoutDebug = false

local function ColorText(color, text)
  if not color then
    return tostring(text or "")
  end
  return "|cff" .. color .. tostring(text or "") .. "|r"
end

local function CloneRoster(source)
  local out = {}
  for i, entry in ipairs(source or {}) do
    out[i] = {
      name = entry.name,
      className = entry.className,
      armorType = entry.armorType,
      present = entry.present,
      eligible = entry.eligible,
      pos = entry.pos,
      holdPos = entry.holdPos,
      ineligibleReason = entry.ineligibleReason,
    }
  end
  return out
end

function Tutorial:ApplyWrappedText(panelFrame, bodyFS, controlsFrame, text, options, skipDefer)
  if not panelFrame or not bodyFS then
    return 0, 0, 0
  end
  if panelFrame._gldWrapApplying then
    return 0, 0, 0
  end
  panelFrame._gldWrapApplying = true
  options = options or {}
  local padX = options.padX or 12
  local padTop = options.padTop or 12
  local padBottom = options.padBottom or 10
  local titleGap = options.titleGap or 6
  local spacing = options.spacing or 8
  local titleHeight = options.titleHeight or 0
  local controlsHeight = options.controlsHeight
  local minHeight = options.minHeight or 0
  local maxHeight = options.maxHeight

  local innerW = (panelFrame.GetWidth and panelFrame:GetWidth() or 0) - (padX * 2)
  if innerW <= 1 and options.innerWidth and options.innerWidth > 1 then
    innerW = options.innerWidth
  end

  bodyFS:SetJustifyH("LEFT")
  bodyFS:SetJustifyV("TOP")
  bodyFS:SetWordWrap(true)
  if bodyFS.SetNonSpaceWrap then
    bodyFS:SetNonSpaceWrap(true)
  end
  if bodyFS.SetMaxLines then
    bodyFS:SetMaxLines(0)
  end
  if innerW and innerW > 1 then
    bodyFS:SetWidth(innerW)
  end
  bodyFS:SetHeight(2000)
  bodyFS:SetText(text or "")
  if innerW and innerW > 1 then
    bodyFS:SetWidth(innerW)
  end

  local rawHeight = math.ceil(bodyFS:GetStringHeight() or 0)
  local textHeight = rawHeight > 0 and (rawHeight + 4) or 0
  bodyFS:SetHeight(textHeight)

  if controlsFrame then
    controlsFrame:ClearAllPoints()
    controlsFrame:SetPoint("TOPLEFT", bodyFS, "BOTTOMLEFT", 0, -spacing)
    controlsFrame:SetPoint("TOPRIGHT", bodyFS, "BOTTOMRIGHT", 0, -spacing)
    if controlsHeight == nil and controlsFrame.GetHeight then
      controlsHeight = controlsFrame:GetHeight() or 0
    end
  end
  controlsHeight = controlsHeight or 0

  local newHeight = padTop + titleHeight + titleGap + textHeight + spacing + controlsHeight + padBottom
  if minHeight > 0 and newHeight < minHeight then
    newHeight = minHeight
  end
  if maxHeight and newHeight > maxHeight then
    newHeight = maxHeight
  end
  if panelFrame.SetHeight then
    panelFrame:SetHeight(newHeight)
  end

  if not panelFrame._gldWrapHooked then
    panelFrame._gldWrapHooked = true
    panelFrame:HookScript("OnSizeChanged", function()
      if panelFrame._gldWrapApplying or not panelFrame._gldWrapState then
        return
      end
      local state = panelFrame._gldWrapState
      Tutorial:ApplyWrappedText(panelFrame, state.bodyFS, state.controlsFrame, state.text, state.options, true)
    end)
  end
  panelFrame._gldWrapState = {
    bodyFS = bodyFS,
    controlsFrame = controlsFrame,
    text = text,
    options = options,
  }

  if self.wrapLayoutDebug then
    local panelName = panelFrame.GetName and panelFrame:GetName() or "tutorial"
    local truncated = bodyFS.IsTruncated and bodyFS:IsTruncated() or nil
    local msg = string.format(
      "Tutorial wrap: panel=%s innerW=%.1f textH=%s panelH=%.1f truncated=%s",
      tostring(panelName),
      innerW or 0,
      tostring(rawHeight),
      newHeight or 0,
      truncated == nil and "n/a" or tostring(truncated)
    )
    if GLD and GLD.Debug then
      GLD:Debug(msg)
    else
      DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
    if truncated == true then
      local err = "Tutorial wrap error: body text still truncated"
      if GLD and GLD.Debug then
        GLD:Debug(err)
      else
        DEFAULT_CHAT_FRAME:AddMessage(err)
      end
    end
  end

  if not skipDefer and C_Timer and C_Timer.After then
    if not panelFrame._gldWrapQueued then
      panelFrame._gldWrapQueued = true
      C_Timer.After(0, function()
        panelFrame._gldWrapQueued = false
        if panelFrame._gldWrapState then
          Tutorial:ApplyWrappedText(panelFrame, bodyFS, controlsFrame, text, options, true)
        end
      end)
    end
  end

  panelFrame._gldWrapApplying = false
  return textHeight, newHeight, innerW or 0
end

local function ResolveFrame(target)
  if not target then
    return nil
  end
  if target.frame then
    return target.frame
  end
  return target
end

local function IsFrameVisible(frame)
  return frame and frame.IsShown and frame:IsShown()
end

function Tutorial:EnsureFrames()
  if self.root then
    return
  end

  local dimmer = CreateFrame("Frame", "GLDTutorialDimmer", UIParent, "BackdropTemplate")
  dimmer:SetAllPoints(UIParent)
  dimmer:SetFrameStrata("DIALOG")
  dimmer:SetFrameLevel(10)
  dimmer:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
  })
  dimmer:SetBackdropColor(0, 0, 0, DIM_ALPHA)
  dimmer:EnableMouse(false)
  dimmer:Hide()

  local root = CreateFrame("Frame", "GLDTutorialRoot", UIParent, "BackdropTemplate")
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("TOOLTIP")
  root:SetFrameLevel(100)
  root:EnableMouse(false)
  root:Hide()

  local highlight = CreateFrame("Frame", nil, root, "BackdropTemplate")
  highlight:SetFrameLevel(root:GetFrameLevel() + 10)
  highlight:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  highlight:SetBackdropColor(0, 0, 0, 0)
  highlight:SetBackdropBorderColor(unpack(GOLD))
  highlight:EnableMouse(false)
  highlight:Hide()

  local popup = CreateFrame("Frame", nil, root, "BackdropTemplate")
  popup:SetSize(420, 190)
  popup:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
  popup:SetFrameLevel(highlight:GetFrameLevel() + 10)
  popup:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  popup:SetBackdropColor(unpack(POPUP_BG))
  popup:SetBackdropBorderColor(unpack(GOLD))
  popup:SetClampedToScreen(true)

  local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -14)
  title:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -14, -14)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(true)
  if title.SetNonSpaceWrap then
    title:SetNonSpaceWrap(true)
  end
  title:SetText("")

  local body = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  body:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -8)
  body:SetText("")

  local backButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  backButton:SetSize(90, 22)
  backButton:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 12, 12)
  backButton:SetText("Back")
  backButton:SetScript("OnClick", function()
    Tutorial:Back()
  end)
  backButton:Hide()

  local skipButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  skipButton:SetSize(90, 22)
  skipButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -112, 12)
  skipButton:SetText("Skip")
  skipButton:SetScript("OnClick", function()
    Tutorial:Skip()
  end)

  local nextButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
  nextButton:SetSize(90, 22)
  nextButton:SetText("Next")
  nextButton:SetScript("OnClick", function()
    Tutorial:Next()
  end)

  local controlsContainer = CreateFrame("Frame", nil, popup)
  controlsContainer:SetFrameLevel(popup:GetFrameLevel() + 5)

  local buttonRow = CreateFrame("Frame", nil, controlsContainer)
  buttonRow:SetFrameLevel(controlsContainer:GetFrameLevel() + 1)

  local fakeControls = CreateFrame("Frame", nil, controlsContainer)
  fakeControls:SetFrameLevel(controlsContainer:GetFrameLevel() + 1)
  fakeControls:Hide()
  fakeControls.buttons = {}
  local controlSpecs = {
    { mode = "LOCK_ALL", text = "LOCK ALL" },
    { mode = "WINNER", text = "WINNER (uncover Need/Greed/Mog)" },
    { mode = "LOSER", text = "LOSER (uncover Pass only)" },
    { mode = "UNLOCK_ALL", text = "UNLOCK ALL" },
  }
  local controlHeight = 20
  local controlSpacing = 4
  local prev = nil
  for _, entry in ipairs(controlSpecs) do
    local btn = CreateFrame("Button", nil, fakeControls, "UIPanelButtonTemplate")
    btn:SetHeight(controlHeight)
    btn:SetText(entry.text)
    btn:SetPoint("LEFT", fakeControls, "LEFT", 0, 0)
    btn:SetPoint("RIGHT", fakeControls, "RIGHT", 0, 0)
    if prev then
      btn:SetPoint("TOP", prev, "BOTTOM", 0, -controlSpacing)
    else
      btn:SetPoint("TOP", fakeControls, "TOP", 0, 0)
    end
    btn:SetScript("OnClick", function()
      Tutorial:SetFakeLootMode(entry.mode)
    end)
    fakeControls.buttons[#fakeControls.buttons + 1] = { button = btn, mode = entry.mode }
    prev = btn
  end
  local totalControlHeight = (controlHeight * #controlSpecs) + (controlSpacing * (#controlSpecs - 1))
  fakeControls:SetHeight(totalControlHeight)

  self.root = root
  self.dimmer = dimmer
  self.highlightFrame = highlight
  self.popup = popup
  self.title = title
  self.body = body
  self.backButton = backButton
  self.skipButton = skipButton
  self.nextButton = nextButton
  self.controlsContainer = controlsContainer
  self.buttonRow = buttonRow
  self.fakeLootControls = fakeControls
end

function Tutorial:EnsureSystemExplanationFrames()
  if self.systemFrame then
    return
  end

  local frame = CreateFrame("Frame", "GLDTutorialSystemExplanation", UIParent, "BackdropTemplate")
  frame:SetSize(SYSTEM_FRAME_WIDTH, SYSTEM_FRAME_MIN_HEIGHT)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(180)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  frame:SetBackdropBorderColor(unpack(GOLD))
  frame:SetClampedToScreen(true)
  frame:Hide()

  local queueFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  queueFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", SYSTEM_FRAME_PAD, -SYSTEM_FRAME_PAD)
  queueFrame:SetWidth(SYSTEM_QUEUE_WIDTH)
  queueFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 4,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  queueFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
  queueFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)

  local queueTitle = queueFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  queueTitle:SetPoint("TOPLEFT", queueFrame, "TOPLEFT", 10, -8)
  queueTitle:SetPoint("TOPRIGHT", queueFrame, "TOPRIGHT", -10, -8)
  queueTitle:SetJustifyH("LEFT")
  queueTitle:SetText("Queue (Present Players)")

  local header = CreateFrame("Frame", nil, queueFrame)
  header:SetHeight(16)
  header:SetPoint("TOPLEFT", queueFrame, "TOPLEFT", 10, -28)
  header:SetPoint("TOPRIGHT", queueFrame, "TOPRIGHT", -10, -28)

  local colGap = 8
  local colSpecs = {
    { key = "pos", label = "Pos", width = 46, align = "CENTER" },
    { key = "name", label = "Player", width = 110, align = "LEFT" },
    { key = "status", label = "Status", width = 64, align = "CENTER" },
    { key = "eligible", label = "Eligible", width = 62, align = "CENTER" },
    { key = "reason", label = "Reason", width = 170, align = "LEFT" },
  }
  local colOffsets = {}
  local x = 0
  for i, col in ipairs(colSpecs) do
    colOffsets[i] = x
    local fs = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetWidth(col.width)
    fs:SetJustifyH(col.align or "LEFT")
    fs:SetPoint("LEFT", header, "LEFT", x, 0)
    fs:SetText(col.label)
    x = x + col.width + colGap
  end

  local rows = {}
  local rowTopPad = 6
  for i = 1, #SYSTEM_SAMPLE_ROSTER do
    local row = CreateFrame("Frame", nil, queueFrame, "BackdropTemplate")
    row:SetHeight(SYSTEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -rowTopPad - (i - 1) * (SYSTEM_ROW_HEIGHT + SYSTEM_ROW_GAP))
    row:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -rowTopPad - (i - 1) * (SYSTEM_ROW_HEIGHT + SYSTEM_ROW_GAP))
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = true,
      tileSize = 4,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    row:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    row:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.6)
    row._gldBaseBorder = { 0.2, 0.2, 0.2, 0.6 }

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 0.82, 0, 0.18)
    row.highlight:Hide()

    row.cells = {}
    for colIndex, col in ipairs(colSpecs) do
      local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      fs:SetWidth(col.width)
      fs:SetJustifyH(col.align or "LEFT")
      fs:SetPoint("LEFT", row, "LEFT", colOffsets[colIndex], 0)
      row.cells[col.key] = fs
    end

    rows[i] = row
  end

  local rowCount = #rows
  local headerOffset = 28
  local headerHeight = 16
  local bottomPad = 10
  local queueHeight = headerOffset
    + headerHeight
    + rowTopPad
    + (SYSTEM_ROW_HEIGHT * rowCount)
    + (SYSTEM_ROW_GAP * (rowCount - 1))
    + bottomPad
  queueFrame:SetHeight(queueHeight)

  local rulesFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  rulesFrame:SetPoint("TOPLEFT", queueFrame, "BOTTOMLEFT", 0, -SYSTEM_RULES_GAP)
  rulesFrame:SetWidth(SYSTEM_QUEUE_WIDTH)
  rulesFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 4,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  rulesFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
  rulesFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)

  local rulesTitle = rulesFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  rulesTitle:SetPoint("TOPLEFT", rulesFrame, "TOPLEFT", 10, -8)
  rulesTitle:SetPoint("TOPRIGHT", rulesFrame, "TOPRIGHT", -10, -8)
  rulesTitle:SetJustifyH("LEFT")
  rulesTitle:SetText("Eligibility Rules")

  local rulesBody = rulesFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rulesBody:SetPoint("TOPLEFT", rulesTitle, "BOTTOMLEFT", 0, -6)
  rulesBody:SetPoint("TOPRIGHT", rulesTitle, "BOTTOMRIGHT", 0, -6)
  rulesBody:SetJustifyH("LEFT")
  rulesBody:SetText("")

  local explainFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  explainFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SYSTEM_FRAME_PAD, -SYSTEM_FRAME_PAD)
  explainFrame:SetWidth(SYSTEM_EXPLAIN_WIDTH)
  explainFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 4,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  explainFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
  explainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)

  local explainTitle = explainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  explainTitle:SetPoint("TOPLEFT", explainFrame, "TOPLEFT", 10, -8)
  explainTitle:SetPoint("TOPRIGHT", explainFrame, "TOPRIGHT", -10, -8)
  explainTitle:SetJustifyH("LEFT")
  explainTitle:SetText("System Explanation")

  local explainBody = explainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  explainBody:SetPoint("TOPLEFT", explainTitle, "BOTTOMLEFT", 0, -6)
  explainBody:SetPoint("TOPRIGHT", explainTitle, "BOTTOMRIGHT", 0, -6)
  explainBody:SetJustifyH("LEFT")
  explainBody:SetText("")

  local controlsFrame = CreateFrame("Frame", nil, explainFrame)
  controlsFrame:SetFrameLevel(explainFrame:GetFrameLevel() + 1)
  controlsFrame:SetWidth(SYSTEM_EXPLAIN_WIDTH - 20)
  controlsFrame:SetPoint("TOPLEFT", explainBody, "BOTTOMLEFT", 0, -8)
  controlsFrame:SetPoint("TOPRIGHT", explainBody, "BOTTOMRIGHT", 0, -8)

  local buttonRow = CreateFrame("Frame", nil, controlsFrame)
  buttonRow:SetHeight(24)
  buttonRow:SetPoint("TOPLEFT", controlsFrame, "TOPLEFT", 0, 0)
  buttonRow:SetPoint("TOPRIGHT", controlsFrame, "TOPRIGHT", 0, 0)

  local backButton = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
  backButton:SetSize(70, 24)
  backButton:SetPoint("LEFT", buttonRow, "LEFT", 0, 0)
  backButton:SetText("Back")
  backButton:SetScript("OnClick", function()
    Tutorial:SystemSimBack()
  end)

  local playButton = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
  playButton:SetSize(120, 24)
  playButton:SetPoint("LEFT", backButton, "RIGHT", 8, 0)
  playButton:SetText("Play")
  playButton:SetScript("OnClick", function()
    Tutorial:SystemSimTogglePlay()
  end)

  local stepButton = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
  stepButton:SetSize(120, 24)
  stepButton:SetPoint("LEFT", playButton, "RIGHT", 8, 0)
  stepButton:SetText("Step")
  stepButton:SetScript("OnClick", function()
    Tutorial:SystemSimStepOrEnd()
  end)

  local logTitle = controlsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  logTitle:SetPoint("TOPLEFT", buttonRow, "BOTTOMLEFT", 0, -6)
  logTitle:SetJustifyH("LEFT")
  logTitle:SetText("Event Log")

  local logLines = {}
  local lineSpacing = 2
  local prev = logTitle
  for i = 1, SYSTEM_LOG_LINES do
    local line = controlsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line:SetJustifyH("LEFT")
    line:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -(i == 1 and 2 or lineSpacing))
    line:SetPoint("TOPRIGHT", controlsFrame, "TOPRIGHT", 0, 0)
    line:SetText("")
    logLines[i] = line
    prev = line
  end

  local logTitleHeight = logTitle:GetStringHeight() or 12
  local lineHeight = logLines[1] and logLines[1].GetStringHeight and logLines[1]:GetStringHeight() or 12
  if lineHeight == 0 then
    lineHeight = 12
  end
  local linesHeight = (lineHeight * SYSTEM_LOG_LINES) + (lineSpacing * (SYSTEM_LOG_LINES - 1))
  local controlsHeight = buttonRow:GetHeight() + 6 + logTitleHeight + 2 + linesHeight
  controlsFrame:SetHeight(controlsHeight)

  self.systemFrame = frame
  self.systemQueueFrame = queueFrame
  self.systemQueueRows = rows
  self.systemRulesFrame = rulesFrame
  self.systemRulesTitle = rulesTitle
  self.systemRulesBody = rulesBody
  self.systemExplainFrame = explainFrame
  self.systemExplainTitle = explainTitle
  self.systemExplainBody = explainBody
  self.systemControlsFrame = controlsFrame
  self.systemBackButton = backButton
  self.systemPlayButton = playButton
  self.systemStepButton = stepButton
  self.systemLogLines = logLines
  self.systemQueueColSpecs = colSpecs
  self.systemQueueRowCount = rowCount
  self.systemExplainControlsHeight = controlsHeight
  self.systemExplainMinHeight = queueHeight
end

function Tutorial:GetOffsets(presetName)
  local offsets = self.Offsets or {}
  local preset = offsets[presetName] or offsets.default or {}
  local pad = preset.pad or 0
  return {
    padL = preset.padL or pad,
    padR = preset.padR or pad,
    padT = preset.padT or pad,
    padB = preset.padB or pad,
  }
end

function Tutorial:HighlightTarget(target, presetName)
  if not self.highlightFrame then
    return
  end
  local frame = ResolveFrame(target)
  if not frame or not frame.GetLeft or not IsFrameVisible(frame) then
    self.highlightFrame:Hide()
    return
  end
  local offsets = self:GetOffsets(presetName)
  self.highlightFrame:ClearAllPoints()
  self.highlightFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -offsets.padL, offsets.padT)
  self.highlightFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offsets.padR, -offsets.padB)
  self.highlightFrame:Show()
end

function Tutorial:HighlightBetween(leftFrame, rightFrame, presetName)
  if not self.highlightFrame then
    return
  end
  local left = ResolveFrame(leftFrame)
  local right = ResolveFrame(rightFrame)
  if not left or not right or not IsFrameVisible(left) or not IsFrameVisible(right) then
    self.highlightFrame:Hide()
    return
  end
  local leftX = left:GetLeft()
  local rightX = right:GetRight()
  local leftTop = left:GetTop()
  local rightTop = right:GetTop()
  local leftBottom = left:GetBottom()
  local rightBottom = right:GetBottom()
  if not leftX or not rightX or not leftTop or not rightTop or not leftBottom or not rightBottom then
    self.highlightFrame:Hide()
    return
  end
  local topY = math.max(leftTop, rightTop)
  local bottomY = math.min(leftBottom, rightBottom)
  local offsets = self:GetOffsets(presetName)
  self.highlightFrame:ClearAllPoints()
  self.highlightFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", leftX - offsets.padL, topY + offsets.padT)
  self.highlightFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", rightX + offsets.padR, bottomY - offsets.padB)
  self.highlightFrame:Show()
end

function Tutorial:UpdateTutorialLayout(anchorFrame, skipDefer)
  if not self.popup or not self.title or not self.body then
    return
  end
  local layout = self.Layout or {}
  local maxWidth = layout.maxWidth or 360
  local padX = layout.padX or 12
  local padTop = layout.padTop or 12
  local padBottom = layout.padBottom or 10
  local titleGap = layout.titleGap or 6
  local buttonsGap = layout.buttonsGap or 10
  local controlsGap = layout.controlsGap or 8
  local anchorPad = layout.anchorPad or 12

  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", self.popup, "TOPLEFT", padX, -padTop)
  self.title:SetPoint("TOPRIGHT", self.popup, "TOPRIGHT", -padX, -padTop)
  self.title:SetWidth(maxWidth)

  self.body:ClearAllPoints()
  self.body:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -titleGap)
  self.body:SetPoint("TOPRIGHT", self.title, "BOTTOMRIGHT", 0, -titleGap)
  self.body:SetWidth(maxWidth)

  local titleText = self.title:GetText() or ""
  if titleText ~= "" then
    self.title:SetText(titleText)
  end
  local bodyText = self.body:GetText() or ""
  if bodyText ~= "" then
    self.body:SetText(bodyText)
  end

  local titleWidth = math.min(self.title:GetStringWidth() or 0, maxWidth)
  local bodyWidth = math.min(self.body:GetStringWidth() or 0, maxWidth)

  local contentWidth = math.min(maxWidth, math.max(titleWidth, bodyWidth))
  local buttonHeight = self.nextButton and self.nextButton.GetHeight and self.nextButton:GetHeight() or 22
  local showControls = self.fakeLootControls and self.fakeLootControls.IsShown and self.fakeLootControls:IsShown()
  local fakeControlsHeight = showControls and (self.fakeLootControls.GetHeight and self.fakeLootControls:GetHeight() or 0) or 0
  local controlsHeight = buttonHeight
  if showControls and fakeControlsHeight > 0 then
    controlsHeight = controlsHeight + buttonsGap + fakeControlsHeight
  end
  local bodyToControlsGap = showControls and controlsGap or buttonsGap

  local frameWidth = contentWidth + (padX * 2)
  local minGap = layout.buttonsMinGap or 16
  local backWidth = (self.backButton and self.backButton.IsShown and self.backButton:IsShown() and self.backButton:GetWidth()) or 0
  local skipWidth = (self.skipButton and self.skipButton.GetWidth and self.skipButton:GetWidth()) or 0
  local nextWidth = (self.nextButton and self.nextButton.GetWidth and self.nextButton:GetWidth()) or 0
  local buttonsWidth = skipWidth + nextWidth + minGap
  if backWidth > 0 then
    buttonsWidth = buttonsWidth + backWidth + minGap
  end
  local minWidth = buttonsWidth + (padX * 2)
  if frameWidth < minWidth then
    frameWidth = minWidth
  end
  if showControls then
    local controlsMinWidth = layout.controlsMinWidth or maxWidth
    local controlsFrameWidth = controlsMinWidth + (padX * 2)
    if frameWidth < controlsFrameWidth then
      frameWidth = controlsFrameWidth
    end
  end

  self.popup:SetWidth(frameWidth)

  local contentFrameWidth = math.max(1, frameWidth - (padX * 2))
  self.title:SetWidth(contentFrameWidth)
  self.body:SetWidth(contentFrameWidth)

  local titleHeight = self.title:GetStringHeight() or 0
  self.title:SetHeight(titleHeight)

  local controlsContainer = self.controlsContainer
  if controlsContainer then
    controlsContainer:SetWidth(contentFrameWidth)
    controlsContainer:Show()
  end

  if self.fakeLootControls then
    if showControls then
      self.fakeLootControls:Show()
      self.fakeLootControls:ClearAllPoints()
      self.fakeLootControls:SetPoint("TOPLEFT", controlsContainer, "TOPLEFT", 0, 0)
      self.fakeLootControls:SetPoint("TOPRIGHT", controlsContainer, "TOPRIGHT", 0, 0)
    else
      self.fakeLootControls:Hide()
    end
  end

  local buttonRow = self.buttonRow
  if buttonRow then
    buttonRow:ClearAllPoints()
    if showControls and self.fakeLootControls then
      buttonRow:SetPoint("TOPLEFT", self.fakeLootControls, "BOTTOMLEFT", 0, -buttonsGap)
      buttonRow:SetPoint("TOPRIGHT", self.fakeLootControls, "BOTTOMRIGHT", 0, -buttonsGap)
    else
      buttonRow:SetPoint("TOPLEFT", controlsContainer, "TOPLEFT", 0, 0)
      buttonRow:SetPoint("TOPRIGHT", controlsContainer, "TOPRIGHT", 0, 0)
    end
    buttonRow:SetHeight(buttonHeight)
  end

  if controlsContainer then
    controlsContainer:SetHeight(controlsHeight)
  end

  bodyText = self.body:GetText() or ""
  self:ApplyWrappedText(self.popup, self.body, controlsContainer, bodyText, {
    padX = padX,
    padTop = padTop,
    padBottom = padBottom,
    titleGap = titleGap,
    spacing = bodyToControlsGap,
    titleHeight = titleHeight,
    controlsHeight = controlsHeight,
    minHeight = layout.minHeight or 0,
    maxHeight = layout.maxHeight,
    innerWidth = contentFrameWidth,
  }, skipDefer)

  if self.backButton and buttonRow then
    self.backButton:ClearAllPoints()
    self.backButton:SetPoint("LEFT", buttonRow, "LEFT", 0, 0)
  end
  if self.nextButton and buttonRow then
    self.nextButton:ClearAllPoints()
    self.nextButton:SetPoint("RIGHT", buttonRow, "RIGHT", 0, 0)
  end
  if self.skipButton and buttonRow then
    self.skipButton:ClearAllPoints()
    if self.nextButton then
      self.skipButton:SetPoint("RIGHT", self.nextButton, "LEFT", -minGap, 0)
    else
      self.skipButton:SetPoint("RIGHT", buttonRow, "RIGHT", 0, 0)
    end
  end

  local anchor = ResolveFrame(anchorFrame)
  self.popup:ClearAllPoints()
  if anchor and anchor.GetRight and IsFrameVisible(anchor) and UIParent and UIParent.GetWidth then
    local parentWidth = UIParent:GetWidth() or 0
    local anchorRight = anchor:GetRight() or 0
    local anchorLeft = anchor:GetLeft() or 0
    if parentWidth > 0 and (anchorRight + anchorPad + frameWidth) <= parentWidth then
      self.popup:SetPoint("LEFT", anchor, "RIGHT", anchorPad, 0)
    else
      self.popup:SetPoint("RIGHT", anchor, "LEFT", -anchorPad, 0)
    end
  else
    self.popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function Tutorial:ElevateFrame(frame)
  frame = ResolveFrame(frame)
  if not frame or not frame.SetFrameStrata then
    return
  end
  self.elevatedFrames = self.elevatedFrames or {}
  if not frame.__tutorialOldStrata then
    frame.__tutorialOldStrata = frame:GetFrameStrata()
    frame.__tutorialOldLevel = frame:GetFrameLevel()
  end
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(200)
  self.elevatedFrames[frame] = true
end

function Tutorial:RestoreFrame(frame)
  frame = ResolveFrame(frame)
  if not frame then
    return
  end
  if frame.__tutorialOldStrata then
    frame:SetFrameStrata(frame.__tutorialOldStrata)
    if frame.__tutorialOldLevel ~= nil then
      frame:SetFrameLevel(frame.__tutorialOldLevel)
    end
    frame.__tutorialOldStrata = nil
    frame.__tutorialOldLevel = nil
  end
end

function Tutorial:RestoreElevatedFrames()
  if not self.elevatedFrames then
    return
  end
  for frame, _ in pairs(self.elevatedFrames) do
    self:RestoreFrame(frame)
  end
  self.elevatedFrames = {}
end

function Tutorial:UpdateButtons()
  local total = self.steps and #self.steps or 0
  local isFirst = self.currentStep == 1
  local isLast = total > 0 and self.currentStep >= total
  if self.backButton then
    self.backButton:SetShown(not isFirst)
  end
  if self.nextButton then
    self.nextButton:SetText(isLast and "Finish" or "Next")
  end
end

function Tutorial:UpdateFakeLootControlState()
  local controls = self.fakeLootControls
  if not controls or not controls.buttons then
    return
  end
  for _, entry in ipairs(controls.buttons) do
    local btn = entry.button
    if btn and btn.SetEnabled then
      btn:SetEnabled(entry.mode ~= self.fakeLootMode)
    end
  end
end

function Tutorial:SetFakeLootMode(mode)
  if not mode or mode == "" then
    return
  end
  self.fakeLootMode = mode
  local fake = UI and UI.FakeLootRoll or nil
  if fake and fake.SetMode then
    fake:SetMode(mode)
  end
  self:UpdateFakeLootControlState()
end

function Tutorial:ShowFakeLootControls(show)
  local controls = self.fakeLootControls
  if not controls then
    return
  end
  controls:SetShown(show and true or false)
  if show then
    self:UpdateFakeLootControlState()
  end
end

function Tutorial:ShowFakeLootRoll(show, mode)
  local fake = UI and UI.FakeLootRoll or nil
  if not fake then
    return
  end
  if show then
    fake:Show()
    self:SetFakeLootMode(mode or self.fakeLootMode or "LOCK_ALL")
    if fake.frame then
      self:RegisterOpenFrame(fake.frame)
    end
  else
    fake:Hide()
  end
end

function Tutorial:ApplyFakeLootStep(step)
  local showRoll = step and step.showFakeLootRoll
  local showControls = step and step.showFakeLootControls
  if showRoll then
    self:ShowFakeLootRoll(true, step.fakeLootMode)
  else
    self:ShowFakeLootRoll(false)
  end
  self:ShowFakeLootControls(showControls)
end

local function HideAnyFrame(frame)
  if not frame then
    return
  end
  if frame.Hide then
    frame:Hide()
    return
  end
  if frame.frame and frame.frame.Hide then
    frame.frame:Hide()
  end
end

local function ShowAnyFrame(frame)
  if not frame then
    return
  end
  if frame.Show then
    frame:Show()
    return
  end
  if frame.frame and frame.frame.Show then
    frame.frame:Show()
  end
end

function Tutorial:ShowPage(frame)
  if self.currentPageFrame and self.currentPageFrame ~= frame then
    HideAnyFrame(self.currentPageFrame)
  end
  self.currentPageFrame = frame
  if frame then
    ShowAnyFrame(frame)
  end
end

function Tutorial:RegisterOpenFrame(frame)
  if not frame then
    return
  end
  self.openFrames = self.openFrames or {}
  for _, existing in ipairs(self.openFrames) do
    if existing == frame then
      return
    end
  end
  self.openFrames[#self.openFrames + 1] = frame
end

function Tutorial:CloseRegisteredFrames()
  if not self.openFrames then
    return
  end
  for _, frame in ipairs(self.openFrames) do
    HideAnyFrame(frame)
  end
  self.openFrames = {}
end

local function SnapshotPositions(roster)
  local map = {}
  for _, entry in ipairs(roster or {}) do
    if entry.present and entry.pos then
      map[entry.name] = entry.pos
    end
  end
  return map
end

local function BuildDisplayList(roster)
  local present = {}
  local absent = {}
  for _, entry in ipairs(roster or {}) do
    if entry.present then
      present[#present + 1] = entry
    else
      absent[#absent + 1] = entry
    end
  end
  table.sort(present, function(a, b)
    return (a.pos or 9999) < (b.pos or 9999)
  end)
  table.sort(absent, function(a, b)
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  local display = {}
  for _, entry in ipairs(present) do
    display[#display + 1] = entry
  end
  for _, entry in ipairs(absent) do
    display[#display + 1] = entry
  end
  return display
end

local function BuildPosChanges(oldMap, newMap, winnerName)
  local changes = {}
  for name, oldPos in pairs(oldMap or {}) do
    local newPos = newMap and newMap[name] or nil
    if newPos and oldPos and newPos ~= oldPos then
      local isWinner = winnerName and name == winnerName
      local oldColor = isWinner and SYSTEM_POS_GREEN or SYSTEM_POS_RED
      local newColor = isWinner and SYSTEM_POS_RED or SYSTEM_POS_GREEN
      changes[name] = {
        oldPos = oldPos,
        newPos = newPos,
        oldColor = oldColor,
        newColor = newColor,
      }
    end
  end
  return changes
end

local function BuildEligibilityRulesText()
  return "Item example: "
    .. SYSTEM_ITEM_NAME
    .. "\n- Ayla (Mage, Cloth) is above Borin but is ineligible for "
    .. SYSTEM_ITEM_ARMOR
    .. ", so only Pass is available.\n- Borin (Warrior, "
    .. SYSTEM_ITEM_ARMOR
    .. ") is eligible, so the highest eligible queue position wins on NEED.\n- For GREED/TRANSMOG, the highest eligible roll wins.\n- Class-restricted items (tier) only allow listed classes."
end

function Tutorial:PositionFakeLootForSystem(show)
  local fake = UI and UI.FakeLootRoll or nil
  if not fake or not fake.frame then
    return
  end
  local frame = fake.frame
  if show then
    if not frame._gldSystemPoints then
      frame._gldSystemPoints = {}
      local count = frame:GetNumPoints() or 0
      for i = 1, count do
        frame._gldSystemPoints[i] = { frame:GetPoint(i) }
      end
    end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
    if self.systemFrame then
      self.systemFrame._gldFakeLootAnchored = true
    end
  else
    if frame._gldSystemPoints then
      frame:ClearAllPoints()
      for _, point in ipairs(frame._gldSystemPoints) do
        frame:SetPoint(unpack(point))
      end
      frame._gldSystemPoints = nil
    end
    if self.systemFrame then
      self.systemFrame._gldFakeLootAnchored = nil
    end
  end
end

function Tutorial:SetFakeLootRowModes(modes)
  local fake = UI and UI.FakeLootRoll or nil
  local rollBlockers = GLD and GLD.RollBlockers or nil
  if not fake or not fake.rows or not rollBlockers or not rollBlockers.SetMode then
    return
  end
  for i, row in ipairs(fake.rows) do
    local mode = (modes and modes[i]) or (modes and modes.default) or self.fakeLootMode or "UNLOCK_ALL"
    rollBlockers.SetMode(row, mode)
  end
end

function Tutorial:SystemSimFlashRollButtons(buttons, duration, rowIndex)
  local fake = UI and UI.FakeLootRoll or nil
  if not fake or not fake.rows then
    return
  end
  local row = fake.rows[rowIndex or 1]
  if not row then
    return
  end
  local function Flash(button)
    if not button or not button.LockHighlight or not button.UnlockHighlight then
      return
    end
    button:LockHighlight()
    if C_Timer and C_Timer.After then
      C_Timer.After(duration or 0.6, function()
        if button and button.UnlockHighlight then
          button:UnlockHighlight()
        end
      end)
    end
  end
  if buttons.need then
    Flash(row.NeedButton or row.Need)
  end
  if buttons.greed then
    Flash(row.GreedButton or row.Greed)
  end
  if buttons.transmog then
    Flash(row.TransmogButton or row.DisenchantButton or row.Disenchant)
  end
  if buttons.pass then
    Flash(row.PassButton or row.Pass)
  end
end

function Tutorial:SystemSimResetState()
  self.systemSim = self.systemSim or {}
  local sim = self.systemSim
  sim.roster = CloneRoster(SYSTEM_SAMPLE_ROSTER)
  self:SystemSimApplyEligibility()
  sim.log = {}
  sim.posChanges = {}
  sim.current = 0
  sim.stepsCount = 8
  sim.stepDelay = SYSTEM_STEP_DELAY
  sim.stepDelays = { [5] = 3.2, [8] = 4 }
  sim.running = false
  sim.runToken = (sim.runToken or 0)
  sim.winnerName = "Borin"
  sim.ineligibleName = "Ayla"
  sim.absentName = "Dax"
  sim.highlights = {}
  self:SystemSimRefreshRulesPanel()
  self:SystemSimSetExplanation("Paused. Press Play to begin the simulator.")
  self:SystemSimRefreshQueue()
  self:SystemSimRefreshLog()
  self:SystemSimUpdateControls()
end

function Tutorial:SystemSimUpdateControls()
  local sim = self.systemSim
  if not sim then
    return
  end
  if self.systemPlayButton and self.systemPlayButton.SetText then
    local label = sim.running and "Pause" or (sim.current >= sim.stepsCount and "Replay" or "Play")
    self.systemPlayButton:SetText(label)
  end
  if self.systemStepButton and self.systemStepButton.SetEnabled then
    local stepLabel = sim.current >= sim.stepsCount and "End Tutorial" or "Step"
    if self.systemStepButton.SetText then
      self.systemStepButton:SetText(stepLabel)
    end
    self.systemStepButton:SetEnabled(not sim.running)
  end
  if self.systemBackButton and self.systemBackButton.SetEnabled then
    self.systemBackButton:SetEnabled(not sim.running and sim.current > 1)
  end
end

function Tutorial:SystemSimGoToStep(target)
  local sim = self.systemSim
  if not sim then
    return
  end
  if target < 0 then
    target = 0
  end
  self:SystemSimResetState()
  if target == 0 then
    sim.current = 0
    self:SystemSimUpdateControls()
    return
  end
  for i = 1, target do
    self:SystemSimApplyStep(i)
  end
  sim.current = target
  sim.running = false
  self:SystemSimUpdateControls()
end

function Tutorial:SystemSimBack()
  local sim = self.systemSim
  if not sim or sim.running then
    return
  end
  if sim.current <= 1 then
    return
  end
  self:SystemSimGoToStep(sim.current - 1)
end

function Tutorial:SystemSimEndTutorial()
  if UI and UI.resultFrame then
    if UI.resultFrame.Release then
      UI.resultFrame:Release()
    elseif UI.resultFrame.frame and UI.resultFrame.frame.Hide then
      UI.resultFrame.frame:Hide()
    end
    UI.resultFrame = nil
  end
  self:FinishTutorial()
end

function Tutorial:FinishTutorial()
  if GLD and GLD.SetTutorialBlockersActive then
    GLD:SetTutorialBlockersActive(false)
  end
  if GLD and GLD.DisableAllBlockers then
    GLD:DisableAllBlockers("tutorial_finished")
  end
  self:Stop(true)
end

function Tutorial:SystemSimStepOrEnd()
  local sim = self.systemSim
  if not sim or sim.running then
    return
  end
  if sim.current >= sim.stepsCount then
    self:SystemSimEndTutorial()
    return
  end
  self:SystemSimAdvance()
end

function Tutorial:SystemSimUpdateLayout()
  if not self.systemFrame or not self.systemQueueFrame or not self.systemExplainFrame then
    return
  end
  local queueHeight = self.systemQueueFrame:GetHeight() or 0
  local rulesHeight = self.systemRulesFrame and self.systemRulesFrame:GetHeight() or 0
  local explainHeight = self.systemExplainFrame:GetHeight() or 0
  local leftHeight = queueHeight
  if rulesHeight > 0 then
    leftHeight = leftHeight + SYSTEM_RULES_GAP + rulesHeight
  end
  local newHeight = math.max(leftHeight, explainHeight) + (SYSTEM_FRAME_PAD * 2)
  if newHeight < SYSTEM_FRAME_MIN_HEIGHT then
    newHeight = SYSTEM_FRAME_MIN_HEIGHT
  end
  self.systemFrame:SetHeight(newHeight)
  if self.systemFrame._gldFakeLootAnchored then
    self:PositionFakeLootForSystem(true)
  end
end

function Tutorial:SystemSimSetExplanation(text)
  if not self.systemExplainFrame or not self.systemExplainBody then
    return
  end
  local padX = 10
  local padTop = 10
  local padBottom = 10
  local titleGap = 6
  local spacing = 8
  local titleHeight = self.systemExplainTitle and self.systemExplainTitle:GetStringHeight() or 0
  local controlsHeight = self.systemExplainControlsHeight
    or (self.systemControlsFrame and self.systemControlsFrame.GetHeight and self.systemControlsFrame:GetHeight())
    or 0
  local innerWidth = (self.systemExplainFrame:GetWidth() or 0) - (padX * 2)
  self:ApplyWrappedText(self.systemExplainFrame, self.systemExplainBody, self.systemControlsFrame, text or "", {
    padX = padX,
    padTop = padTop,
    padBottom = padBottom,
    titleGap = titleGap,
    spacing = spacing,
    titleHeight = titleHeight,
    controlsHeight = controlsHeight,
    minHeight = self.systemExplainMinHeight or 0,
    innerWidth = innerWidth,
  })
  self:SystemSimUpdateLayout()
end

function Tutorial:SystemSimRefreshRulesPanel()
  if not self.systemRulesFrame or not self.systemRulesBody then
    return
  end
  local padX = 10
  local padTop = 8
  local padBottom = 8
  local titleGap = 6
  local titleHeight = self.systemRulesTitle and self.systemRulesTitle:GetStringHeight() or 0
  local innerWidth = (self.systemRulesFrame:GetWidth() or 0) - (padX * 2)
  self:ApplyWrappedText(self.systemRulesFrame, self.systemRulesBody, nil, BuildEligibilityRulesText(), {
    padX = padX,
    padTop = padTop,
    padBottom = padBottom,
    titleGap = titleGap,
    spacing = 0,
    titleHeight = titleHeight,
    innerWidth = innerWidth,
  })
  self.systemRulesHeight = self.systemRulesFrame:GetHeight() or 0
  if self.systemQueueFrame then
    local leftHeight = (self.systemQueueFrame:GetHeight() or 0) + SYSTEM_RULES_GAP + self.systemRulesHeight
    self.systemExplainMinHeight = leftHeight
  end
  self:SystemSimUpdateLayout()
end

function Tutorial:SystemSimApplyEligibility()
  local sim = self.systemSim
  if not sim or not sim.roster then
    return
  end
  for _, entry in ipairs(sim.roster) do
    entry.eligible = true
    entry.ineligibleReason = nil
    if entry.classRestricted then
      entry.eligible = false
      entry.ineligibleReason = "class_restriction"
    elseif entry.armorType and SYSTEM_ITEM_ARMOR and entry.armorType ~= SYSTEM_ITEM_ARMOR then
      entry.eligible = false
      entry.ineligibleReason = "wrong_armor"
    end
  end
end

function Tutorial:SystemSimGetReasonText(entry)
  if not entry then
    return ""
  end
  if entry.ineligibleReason == "class_restriction" then
    return "Ineligible: class restriction"
  end
  if entry.ineligibleReason == "wrong_armor" then
    local armor = entry.armorType or "?"
    return "Ineligible: wrong armor (" .. armor .. " vs " .. SYSTEM_ITEM_ARMOR .. ")"
  end
  return "Eligible"
end

function Tutorial:SystemSimAddLog(text)
  local sim = self.systemSim
  if not sim then
    return
  end
  sim.log = sim.log or {}
  sim.log[#sim.log + 1] = text
  self:SystemSimRefreshLog()
end

function Tutorial:SystemSimRefreshLog()
  local lines = self.systemLogLines
  if not lines then
    return
  end
  local log = (self.systemSim and self.systemSim.log) or {}
  local maxLines = #lines
  local start = math.max(1, #log - maxLines + 1)
  for i = 1, maxLines do
    local entry = log[start + i - 1]
    lines[i]:SetText(entry or "")
  end
end

function Tutorial:SystemSimApplyHighlights()
  local rows = self.systemQueueRows
  local sim = self.systemSim
  if not rows or not sim then
    return
  end
  local map = sim.highlights or {}
  for _, row in ipairs(rows) do
    local data = row.data
    local show = data and map[data.name]
    if row.highlight then
      row.highlight:SetShown(show and true or false)
    end
    local border = row._gldBaseBorder or { 0.2, 0.2, 0.2, 0.6 }
    if show then
      row:SetBackdropBorderColor(unpack(GOLD))
    else
      row:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end
  end
end

function Tutorial:SystemSimSetHighlights(names)
  local sim = self.systemSim
  if not sim then
    return
  end
  local map = {}
  if type(names) == "string" then
    map[names] = true
  elseif type(names) == "table" then
    if #names > 0 then
      for _, name in ipairs(names) do
        map[name] = true
      end
    else
      for name, enabled in pairs(names) do
        if enabled then
          map[name] = true
        end
      end
    end
  end
  sim.highlights = map
  self:SystemSimApplyHighlights()
end

function Tutorial:SystemSimRefreshQueue()
  local sim = self.systemSim
  if not sim or not self.systemQueueRows then
    return
  end
  local display = BuildDisplayList(sim.roster)
  for i, row in ipairs(self.systemQueueRows) do
    local data = display[i]
    row.data = data
    if data then
      row:Show()
      local posText = data.pos and tostring(data.pos) or "-"
      local change = sim.posChanges and sim.posChanges[data.name]
      if change then
        posText = ColorText(change.oldColor, change.oldPos) .. " -> " .. ColorText(change.newColor, change.newPos)
      elseif not data.present then
        posText = ColorText(SYSTEM_POS_GRAY, "-")
      end
      if row.cells.pos then
        row.cells.pos:SetText(posText)
      end
      if row.cells.name then
        row.cells.name:SetText(data.name or "")
        if data.present then
          row.cells.name:SetTextColor(1, 1, 1)
        else
          row.cells.name:SetTextColor(0.7, 0.7, 0.7)
        end
      end
      if row.cells.status then
        local statusText = data.present and "Present" or "Absent"
        row.cells.status:SetText(statusText)
        if data.present then
          row.cells.status:SetTextColor(0.85, 0.85, 0.85)
        else
          row.cells.status:SetTextColor(0.6, 0.6, 0.6)
        end
      end
      if row.cells.eligible then
        local eligible = data.present and data.eligible
        row.cells.eligible:SetText(eligible and "Yes" or "No")
        if eligible then
          row.cells.eligible:SetTextColor(0.2, 0.85, 0.3)
        else
          row.cells.eligible:SetTextColor(0.9, 0.3, 0.3)
        end
      end
      if row.cells.reason then
        row.cells.reason:SetText(self:SystemSimGetReasonText(data))
        if data.present then
          row.cells.reason:SetTextColor(0.85, 0.85, 0.85)
        else
          row.cells.reason:SetTextColor(0.6, 0.6, 0.6)
        end
      end
    else
      row:Hide()
    end
  end
  self:SystemSimApplyHighlights()
end

function Tutorial:SystemSimFindPlayer(name)
  local sim = self.systemSim
  if not sim or not sim.roster then
    return nil
  end
  for _, entry in ipairs(sim.roster) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

function Tutorial:SystemSimCompactQueue()
  local sim = self.systemSim
  if not sim or not sim.roster then
    return
  end
  local present = {}
  for _, entry in ipairs(sim.roster) do
    if entry.present then
      present[#present + 1] = entry
    end
  end
  table.sort(present, function(a, b)
    return (a.pos or 9999) < (b.pos or 9999)
  end)
  for i, entry in ipairs(present) do
    entry.pos = i
  end
end

function Tutorial:SystemSimSetAttendance(name, state)
  local sim = self.systemSim
  local entry = self:SystemSimFindPlayer(name)
  if not sim or not entry then
    return
  end
  if state then
    if entry.present then
      return
    end
    local presentCount = 0
    for _, player in ipairs(sim.roster) do
      if player.present then
        presentCount = presentCount + 1
      end
    end
    local insertPos = entry.holdPos or (presentCount + 1)
    if insertPos < 1 then
      insertPos = 1
    end
    local maxPos = presentCount + 1
    if insertPos > maxPos then
      insertPos = maxPos
    end
    for _, player in ipairs(sim.roster) do
      if player.present and player.pos and player.pos >= insertPos then
        player.pos = player.pos + 1
      end
    end
    entry.pos = insertPos
    entry.present = true
    self:SystemSimCompactQueue()
    return
  end
  if not entry.present then
    return
  end
  entry.holdPos = entry.pos
  entry.pos = nil
  entry.present = false
  self:SystemSimCompactQueue()
end

function Tutorial:SystemSimOnAwarded(name)
  local entry = self:SystemSimFindPlayer(name)
  if not entry or not entry.present then
    return
  end
  entry.pos = 9999
  self:SystemSimCompactQueue()
end

function Tutorial:SystemSimApplyStep(index)
  local sim = self.systemSim
  if not sim then
    return
  end
  sim.posChanges = {}
  local winner = sim.winnerName
  local ineligible = sim.ineligibleName
  local absent = sim.absentName

  if index == 1 then
    sim.roster = CloneRoster(SYSTEM_SAMPLE_ROSTER)
    self:SystemSimApplyEligibility()
    self:SystemSimCompactQueue()
    self:SystemSimSetHighlights({})
    self:SystemSimSetExplanation(
      "Present players are numbered in order. Queue positions count only Present members; Absent players do not take a slot."
    )
    self:SystemSimAddLog("Queue built for " .. SYSTEM_ITEM_NAME .. ": Ayla=1, Borin=2, Cora=3, Dax=4, Eryn=5.")
    self:SetFakeLootMode("UNLOCK_ALL")
  elseif index == 2 then
    self:SystemSimSetHighlights(ineligible)
    self:SystemSimSetExplanation(
      "Eligibility gates who can claim. "
        .. ineligible
        .. " is above "
        .. winner
        .. " but is ineligible for "
        .. SYSTEM_ITEM_ARMOR
        .. " (Cloth vs "
        .. SYSTEM_ITEM_ARMOR
        .. "), so only Pass is allowed."
    )
    self:SystemSimAddLog("Eligibility: " .. ineligible .. " ineligible for " .. SYSTEM_ITEM_ARMOR .. "; Pass only.")
    self:SetFakeLootMode("LOSER")
    self:SystemSimFlashRollButtons({ pass = true }, 0.6, 1)
  elseif index == 3 then
    self:SystemSimSetHighlights({})
    self:SystemSimSetExplanation("Roll starts: all buttons are blocked (LOCK ALL) while votes and eligibility are checked.")
    self:SystemSimAddLog("Roll started: buttons locked.")
    self:SetFakeLootMode("LOCK_ALL")
  elseif index == 4 then
    self:SystemSimSetHighlights({ ineligible, winner })
    self:SystemSimSetExplanation(
      ineligible
        .. " is above "
        .. winner
        .. ", but is ineligible for this item. Next eligible player is "
        .. winner
        .. ".\nQueue order applies only among ELIGIBLE players for the item.\nNeed uses queue priority among eligible players; Greed/Mog uses highest eligible roll."
    )
    self:SystemSimAddLog("Roll resolved: " .. ineligible .. " ineligible; " .. winner .. " is next eligible and wins.")
    self:SetFakeLootRowModes({ "WINNER", "LOSER" })
    self:SystemSimFlashRollButtons({ need = true, greed = true, transmog = true }, 0.6, 1)
    self:SystemSimFlashRollButtons({ pass = true }, 0.6, 2)
  elseif index == 5 then
    local oldPos = SnapshotPositions(sim.roster)
    self:SystemSimOnAwarded(winner)
    local newPos = SnapshotPositions(sim.roster)
    sim.posChanges = BuildPosChanges(oldPos, newPos, winner)
    self:SystemSimSetHighlights(winner)
    self:SystemSimSetExplanation(
      "Awarding moves the winner to the end. Everyone else compacts upward to fill the gap."
    )
    self:SystemSimAddLog("Awarded: Borin 2 -> 5; others compact upward.")
  elseif index == 6 then
    local oldPos = SnapshotPositions(sim.roster)
    self:SystemSimSetAttendance(absent, false)
    local newPos = SnapshotPositions(sim.roster)
    sim.posChanges = BuildPosChanges(oldPos, newPos, nil)
    self:SystemSimSetHighlights(absent)
    local entry = self:SystemSimFindPlayer(absent)
    local holdPos = entry and entry.holdPos or "?"
    self:SystemSimSetExplanation(
      "If a player becomes Absent, their position is saved as holdPos and removed from the Present queue."
    )
    self:SystemSimAddLog("Attendance: Dax absent; holdPos=" .. tostring(holdPos) .. " saved.")
  elseif index == 7 then
    local oldPos = SnapshotPositions(sim.roster)
    self:SystemSimSetAttendance(absent, true)
    local newPos = SnapshotPositions(sim.roster)
    sim.posChanges = BuildPosChanges(oldPos, newPos, nil)
    self:SystemSimSetHighlights(absent)
    local entry = self:SystemSimFindPlayer(absent)
    local pos = entry and entry.pos or "?"
    self:SystemSimSetExplanation(
      "When they return Present, they always reinsert at their saved holdPos. If holdPos exceeds the current queue length, it clamps to the last valid index."
    )
    self:SystemSimAddLog("Attendance: Dax returns; reinserted at holdPos=" .. tostring(pos) .. ".")
  elseif index == 8 then
    self:SystemSimSetHighlights({})
    self:SystemSimSetExplanation(
      "Cheat sheet:\n- Queue positions count Present players only\n- Queue order applies only among eligible players\n- Eligible = can claim; otherwise Pass only\n- Winner moves to end; others compact\n- Absent saves holdPos; returning reinserts at holdPos\n- Blockers show which buttons are usable\n\nYou're all set. The tutorial won't auto-run again."
    )
    self:SystemSimAddLog("Summary: Present queue, eligibility gates, winner to end, holdPos reinserts, blockers explain buttons.")
    self:SetFakeLootRowModes({ "WINNER", "LOSER" })
  end

  self:SystemSimRefreshQueue()
end

function Tutorial:SystemSimAdvance()
  local sim = self.systemSim
  if not sim then
    return
  end
  if sim.current >= sim.stepsCount then
    sim.running = false
    self:SystemSimUpdateControls()
    return
  end
  sim.current = sim.current + 1
  self:SystemSimApplyStep(sim.current)
  if sim.current >= sim.stepsCount then
    sim.running = false
  end
  self:SystemSimUpdateControls()
end

function Tutorial:SystemSimScheduleNext()
  local sim = self.systemSim
  if not sim or not sim.running then
    return
  end
  if sim.current >= sim.stepsCount then
    sim.running = false
    self:SystemSimUpdateControls()
    return
  end
  local delay = (sim.stepDelays and sim.stepDelays[sim.current]) or sim.stepDelay or SYSTEM_STEP_DELAY
  local token = sim.runToken
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function()
      if not self.systemSim or not sim.running or sim.runToken ~= token then
        return
      end
      self:SystemSimAdvance()
      self:SystemSimScheduleNext()
    end)
  else
    self:SystemSimAdvance()
  end
end

function Tutorial:SystemSimTogglePlay()
  local sim = self.systemSim
  if not sim then
    return
  end
  if sim.running then
    sim.running = false
    sim.runToken = (sim.runToken or 0) + 1
    self:SystemSimUpdateControls()
    return
  end
  if sim.current >= sim.stepsCount then
    self:SystemSimResetState()
  end
  sim.running = true
  sim.runToken = (sim.runToken or 0) + 1
  if sim.current == 0 then
    self:SystemSimAdvance()
  end
  self:SystemSimUpdateControls()
  self:SystemSimScheduleNext()
end

function Tutorial:SystemSimStep()
  local sim = self.systemSim
  if not sim or sim.running then
    return
  end
  if sim.current >= sim.stepsCount then
    self:SystemSimResetState()
  end
  self:SystemSimAdvance()
end

function Tutorial:SystemSimStart()
  local sim = self.systemSim
  if not sim then
    return
  end
  sim.running = true
  sim.runToken = (sim.runToken or 0) + 1
  if sim.current == 0 then
    self:SystemSimAdvance()
  end
  self:SystemSimUpdateControls()
  self:SystemSimScheduleNext()
end

function Tutorial:ShowSystemExplanation()
  self:EnsureSystemExplanationFrames()
  if self.systemFrame then
    self.systemFrame:Show()
    self:ElevateFrame(self.systemFrame)
    self:RegisterOpenFrame(self.systemFrame)
  end
  if UI and UI.FakeLootRoll and UI.FakeLootRoll.EnsureFrame then
    UI.FakeLootRoll:EnsureFrame()
  end
  self:PositionFakeLootForSystem(true)
  self:SystemSimResetState()
end

function Tutorial:StopSystemExplanation()
  if self.systemSim then
    self.systemSim.running = false
    self.systemSim.runToken = (self.systemSim.runToken or 0) + 1
  end
  if self.systemFrame then
    self:RestoreFrame(self.systemFrame)
    self.systemFrame:Hide()
  end
  self:PositionFakeLootForSystem(false)
end

function Tutorial:Stop(markSeen)
  if GLD and GLD.SetTutorialBlockersActive then
    GLD:SetTutorialBlockersActive(false)
  end
  if markSeen and GLD and GLD.GetUIConfig then
    local ui = GLD:GetUIConfig()
    if ui then
      ui.tutorialSeen = true
    end
  end
  self.active = false
  self:RestoreElevatedFrames()
  self:ShowPage(nil)
  self:CloseRegisteredFrames()
  self:StopSystemExplanation()
  self:ShowFakeLootRoll(false)
  self:ShowFakeLootControls(false)
  if self.dimmer then
    self.dimmer:Hide()
  end
  if self.root then
    self.root:Hide()
  end
  if self.highlightFrame then
    self.highlightFrame:Hide()
  end
end

function Tutorial:Skip()
  self:FinishTutorial()
end

function Tutorial:MaybeAutoStart()
  if self.active then
    return
  end
  if not GLD or not GLD.GetUIConfig then
    return
  end
  local ui = GLD:GetUIConfig()
  local seen = ui and ui.tutorialSeen
  if seen == false or seen == nil then
    self:Start(false)
  end
end

function Tutorial:Start(force)
  if InCombatLockdown and InCombatLockdown() then
    if not self.startRetryPending and C_Timer and C_Timer.After then
      self.startRetryPending = true
      C_Timer.After(1, function()
        self.startRetryPending = false
        Tutorial:Start(force)
      end)
    end
    return
  end
  local ui = GLD and GLD.GetUIConfig and GLD:GetUIConfig() or nil
  if not force and ui and ui.tutorialSeen then
    return
  end

  self:EnsureFrames()
  if self.active then
    self:Stop(false)
  end
  self.active = true
  if GLD and GLD.SetTutorialBlockersActive then
    GLD:SetTutorialBlockersActive(true)
  end
  self.elevatedFrames = {}
  self.demoCloakRow = nil
  self.demoCloakSession = nil
  self.fakeLootMode = "LOCK_ALL"

  if UI and UI.mainFrame and UI.mainFrame.IsShown and UI.mainFrame:IsShown() then
    if UI.RefreshMain then
      UI:RefreshMain()
    end
  else
    if UI and UI.ToggleMain then
      UI:ToggleMain()
    end
  end
  if UI and UI.RefreshMain then
    UI:RefreshMain()
  end

  self:BuildSteps()
  self:ShowStep(1)
end

function Tutorial:ShowStep(index)
  if not self.steps or #self.steps == 0 then
    self:Stop(true)
    return
  end
  local step = self.steps[index]
  if not step then
    self:Stop(true)
    return
  end

  local prevStep = self.steps and self.steps[self.currentStep] or nil
  if prevStep and prevStep.onExit then
    prevStep.onExit(self, prevStep)
  end
  self:ShowPage(nil)
  self:CloseRegisteredFrames()

  self.currentStep = index
  if self.root then
    self.root:Show()
  end
  if self.dimmer then
    self.dimmer:Show()
  end
  if self.popup then
    self.popup:Show()
  end

  if self.title then
    self.title:SetText(step.title or "")
  end
  if self.body then
    self.body:SetText(step.text or "")
  end

  if step.onShow then
    step.onShow(self, step)
  end

  self:ApplyFakeLootStep(step)

  local pageFrame = step.getPageFrame and step.getPageFrame(self, step) or step.pageFrame
  if pageFrame then
    self:ShowPage(pageFrame)
  end

  if step.getHighlightBounds then
    local left, right = step.getHighlightBounds(self, step)
    self:HighlightBetween(left, right, step.highlightPreset)
  else
    local target = step.getTarget and step.getTarget(self, step) or nil
    if not target then
      target = step.target
    end
    self:HighlightTarget(target, step.highlightPreset)
  end

  self:UpdateButtons()
  local anchor = step.getAnchor and step.getAnchor(self, step) or nil
  if not anchor then
    anchor = step.getTarget and step.getTarget(self, step) or step.target
  end
  self:UpdateTutorialLayout(anchor)
end

function Tutorial:Next()
  if not self.active then
    return
  end
  local step = self.steps and self.steps[self.currentStep] or nil
  if step and step.onNext then
    step.onNext(self, step)
  end
  if not self.steps or self.currentStep >= #self.steps then
    self:FinishTutorial()
    return
  end
  self:ShowStep(self.currentStep + 1)
end

function Tutorial:Back()
  if not self.active then
    return
  end
  local step = self.steps and self.steps[self.currentStep] or nil
  if step and step.onBack then
    step.onBack(self, step)
  end
  if self.currentStep > 1 then
    self:ShowStep(self.currentStep - 1)
  end
end

function Tutorial:GetDemoCloakRowAndSession()
  if UI and UI.ShowLootWindowDemo then
    local w = UI.lootVoteWindow
    if not w or not w.frame or not w.frame:IsShown() or not w.pendingRows or #w.pendingRows == 0 then
      UI:ShowLootWindowDemo()
    end
  end

  local w = UI and UI.lootVoteWindow or nil
  if not w or not w.pendingRows then
    return nil
  end

  local cloakRow = nil
  for _, row in ipairs(w.pendingRows) do
    if row and row.itemText and row.itemText.GetText then
      local text = row.itemText:GetText() or ""
      if text:find("Astral Gladiator's Prestigious Cloak", 1, true) then
        cloakRow = row
        break
      end
    end
  end
  if not cloakRow then
    cloakRow = w.pendingRows[2]
  end

  local session = nil
  if cloakRow then
    local entryKey = cloakRow.entryKey
    local state = UI and UI.lootVoteState or nil
    if entryKey and state and state.indexByKey then
      local idx = state.indexByKey[entryKey]
      local entry = idx and state.currentVoteItems and state.currentVoteItems[idx] or nil
      session = entry and entry.session or nil
    end
  end

  local itemName = session and session.itemName or nil
  local itemLink = session and session.itemLink or nil
  if cloakRow then
    if not itemLink and cloakRow.itemLink then
      itemLink = cloakRow.itemLink
    end
    if not itemName and cloakRow.itemText and cloakRow.itemText.GetText then
      itemName = cloakRow.itemText:GetText()
    end
  end
  if not itemName and itemLink then
    local name = select(1, GetItemInfo(itemLink))
    if name and name ~= "" then
      itemName = name
    end
  end
  if not itemName and itemLink then
    itemName = itemLink
  end

  local cloakSession = nil
  if itemName or itemLink then
    cloakSession = { itemName = itemName, itemLink = itemLink }
  end

  return cloakRow, cloakSession
end

function Tutorial:FocusPendingRow(row)
  if not row then
    return
  end
  if row.hitArea and row.hitArea.Click then
    row.hitArea:Click()
    return
  end
  if row.hitArea and row.hitArea.GetScript then
    local handler = row.hitArea:GetScript("OnClick")
    if handler then
      handler(row.hitArea)
      return
    end
  end
  if row.entryKey and UI and UI.RefreshLootWindow then
    UI:RefreshLootWindow({ activeKey = row.entryKey })
  end
end

function Tutorial:BuildResultPayloads(cloak)
  if not cloak then
    return nil, nil
  end

  local itemName = cloak.itemName or "Item"
  local itemLink = cloak.itemLink
  local playerName = UnitName("player") or "Player"
  local playerFullName = GLD and GLD.GetUnitFullName and GLD:GetUnitFullName("player") or playerName
  local playerKey = NS and NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
  local classToken = select(2, UnitClass("player")) or "WARRIOR"

  local votesWinner = {}
  votesWinner[playerFullName] = "NEED"

  local votesLoser = {}
  votesLoser[playerFullName] = "GREED"

  local winnerPayload = {
    itemName = itemName,
    itemLink = itemLink,
    winnerShortName = playerName,
    winnerName = playerFullName,
    winnerKey = playerKey,
    winnerClassToken = classToken,
    winnerVote = "NEED",
    instructionVote = "NEED",
    votes = votesWinner,
    winningRoll = 98,
  }

  local loserPayload = {
    itemName = itemName,
    itemLink = itemLink,
    winnerShortName = "SomeoneElse",
    winnerName = "SomeoneElse-Realm",
    winnerKey = "demo-other",
    winnerClassToken = "WARRIOR",
    winnerVote = "NEED",
    instructionVote = "PASS",
    votes = votesLoser,
    winningRoll = 88,
  }

  return winnerPayload, loserPayload
end

function Tutorial:BuildSteps()
  local steps = {}
  local function addStep(step)
    steps[#steps + 1] = step
  end

  local function getMainFrame()
    return UI and (UI.mainFrame or UI.frame) or nil
  end

  local function getLootVotesFrame()
    local w = UI and UI.lootVoteWindow or nil
    return w and w.frame or nil
  end

  local function getResultFrame()
    local result = UI and UI.resultFrame or nil
    return result and (result.frame or result) or nil
  end

  local function getFakeRollFrame()
    local fake = UI and UI.FakeLootRoll or nil
    return fake and fake.frame or nil
  end

  local function elevateMain()
    if UI then
      Tutorial:ElevateFrame(UI.mainFrame or UI.frame)
    end
  end

  local function elevateLootVotes()
    local w = UI and UI.lootVoteWindow or nil
    if w and w.frame then
      Tutorial:ElevateFrame(w.frame)
    end
  end

  local function elevateResults()
    if UI and UI.resultFrame and UI.resultFrame.frame then
      Tutorial:ElevateFrame(UI.resultFrame.frame)
    end
  end

  addStep({
    title = "Welcome",
    text = "This guided tour walks through Main Roster -> Loot Votes -> Loot Result.",
    onShow = function()
      elevateMain()
    end,
    getPageFrame = getMainFrame,
  })

  local function addHeaderStep(key, title, text)
    local button = UI and UI.headerButtonByKey and UI.headerButtonByKey[key] or nil
    if button then
      addStep({
        title = title,
        text = text,
        target = button,
        highlightPreset = "header",
        onShow = function()
          elevateMain()
        end,
        getPageFrame = getMainFrame,
      })
    end
  end

  addHeaderStep("class", "Class", "Class shows each roster member's class icon.")
  addHeaderStep("spec", "Spec", "Spec shows each member's specialization.")
  addHeaderStep("role", "Role", "Role shows the assigned role.")
  addHeaderStep("name", "Name", "Name lists the roster member.")
  addHeaderStep("queuePos", "Queue Pos", "Queue Pos shows the current loot queue order.")
  addHeaderStep("heldPos", "Held Pos", "Held Pos shows saved or held positions.")
  addHeaderStep("itemsWon", "Items Won", "Items Won tracks how many items a member has received.")
  addHeaderStep("raidsAttended", "Raids Attended", "Raids Attended counts recent attendance.")
  addHeaderStep("attendance", "Attendance", "Attendance shows overall raid attendance.")

  addStep({
    title = "Loot Votes",
    text = "This is the Loot Votes window. Active Vote is at the top, Pending below.",
    onShow = function(selfStep)
      if UI and UI.ShowLootWindowDemo then
        UI:ShowLootWindowDemo()
      end
      elevateLootVotes()
    end,
    getTarget = function()
      local w = UI and UI.lootVoteWindow or nil
      return w and w.frame or nil
    end,
    highlightPreset = "panel",
    getPageFrame = getLootVotesFrame,
  })

  addStep({
    title = "Active Vote",
    text = "Active Vote is the item everyone is currently voting on.",
    getTarget = function()
      local w = UI and UI.lootVoteWindow or nil
      return w and w.activePanel or nil
    end,
    highlightPreset = "panel",
    onShow = function()
      elevateLootVotes()
    end,
    getPageFrame = getLootVotesFrame,
  })

  addStep({
    title = "Vote Buttons",
    text = "Use Need, Greed, Mog, or Pass to submit your vote.",
    getHighlightBounds = function()
      local w = UI and UI.lootVoteWindow or nil
      return w and w.needButton, w and w.passButton
    end,
    getAnchor = function()
      local w = UI and UI.lootVoteWindow or nil
      return w and w.buttonRow or nil
    end,
    highlightPreset = "buttonRow",
    onShow = function()
      elevateLootVotes()
    end,
    getPageFrame = getLootVotesFrame,
  })

  addStep({
    title = "Pending List",
    text = "Pending items wait here until they become the Active Vote.",
    getTarget = function()
      local w = UI and UI.lootVoteWindow or nil
      return w and w.pendingPanel or nil
    end,
    highlightPreset = "panel",
    onShow = function()
      elevateLootVotes()
    end,
    getPageFrame = getLootVotesFrame,
  })

  addStep({
    title = "Pending Item",
    text = "Click the highlighted Pending item to make it the Active Vote at the top.",
    onShow = function(selfRef)
      local row, session = Tutorial:GetDemoCloakRowAndSession()
      Tutorial.demoCloakRow = row
      Tutorial.demoCloakSession = session
      elevateLootVotes()
    end,
    onNext = function(selfRef)
      if Tutorial.demoCloakRow then
        Tutorial:FocusPendingRow(Tutorial.demoCloakRow)
      end
    end,
    getTarget = function()
      local row = Tutorial.demoCloakRow
      if row then
        return row
      end
      local w = UI and UI.lootVoteWindow or nil
      return w and w.pendingPanel or nil
    end,
    highlightPreset = "row",
    getPageFrame = getLootVotesFrame,
  })

  addStep({
    title = "Loot Result (Winner)",
    text = "If you won, click NEED/GREED/MOG on the loot to claim it.",
    onShow = function()
      local w = UI and UI.lootVoteWindow or nil
      if w and w.frame then
        w.frame:Hide()
      end
      if not Tutorial.demoCloakSession then
        Tutorial.demoCloakSession = {
          itemName = "Astral Gladiator's Prestigious Cloak",
          itemLink = "item:244234",
        }
      end
      local winnerPayload = nil
      if Tutorial.demoCloakSession then
        winnerPayload = select(1, Tutorial:BuildResultPayloads(Tutorial.demoCloakSession))
      end
      if winnerPayload and UI and UI.ShowRollResultPopup then
        UI:ShowRollResultPopup(winnerPayload)
        if UI.resultFrame then
          Tutorial:RegisterOpenFrame(UI.resultFrame)
        end
      end
      elevateResults()
    end,
    getTarget = function()
      return UI and UI.resultFrame and UI.resultFrame.frame or nil
    end,
    highlightPreset = "panel",
    getPageFrame = getResultFrame,
  })

  addStep({
    title = "Loot Result (Not Winner)",
    text = "If you didn't win, click PASS so the winner can take it.",
    onShow = function()
      if not Tutorial.demoCloakSession then
        Tutorial.demoCloakSession = {
          itemName = "Astral Gladiator's Prestigious Cloak",
          itemLink = "item:244234",
        }
      end
      local loserPayload = nil
      if Tutorial.demoCloakSession then
        loserPayload = select(2, Tutorial:BuildResultPayloads(Tutorial.demoCloakSession))
      end
      if loserPayload and UI and UI.ShowRollResultPopup then
        UI:ShowRollResultPopup(loserPayload)
        if UI.resultFrame then
          Tutorial:RegisterOpenFrame(UI.resultFrame)
        end
      end
      elevateResults()
    end,
    getTarget = function()
      return UI and UI.resultFrame and UI.resultFrame.frame or nil
    end,
    highlightPreset = "panel",
    getPageFrame = getResultFrame,
  })

  addStep({
    title = "Blizzard Loot Roll",
    text = "This simulated loot roll row mirrors the Blizzard window. Use the buttons below to see how lock states behave.",
    getTarget = function()
      local fake = UI and UI.FakeLootRoll or nil
      return fake and fake.frame or nil
    end,
    highlightPreset = "panel",
    showFakeLootRoll = true,
    showFakeLootControls = true,
    fakeLootMode = "LOCK_ALL",
    getPageFrame = getFakeRollFrame,
  })

  addStep({
    title = "System Explanation",
    text = "Queue & Eligibility Simulator starts paused. Use Play, Back, and Step to control the walkthrough.",
    onShow = function()
      Tutorial:ShowSystemExplanation()
    end,
    onNext = function()
      Tutorial:StopSystemExplanation()
    end,
    onBack = function()
      Tutorial:StopSystemExplanation()
    end,
    getTarget = function()
      return Tutorial.systemFrame
    end,
    highlightPreset = "panel",
    showFakeLootRoll = true,
    showFakeLootControls = false,
    fakeLootMode = "UNLOCK_ALL",
    getPageFrame = function()
      return Tutorial.systemFrame
    end,
  })

  self.steps = steps
end
