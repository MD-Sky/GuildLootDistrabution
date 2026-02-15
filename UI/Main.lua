local _, NS = ...

local GLD = NS.GLD
local AceGUI = LibStub("AceGUI-3.0", true)

local UI = {}
NS.UI = UI
GLD.UI = UI

function GLD:InitUI()
  UI.mainFrame = nil
  UI.rollFrame = nil
  UI.rollFrames = nil
  UI.adminVoteFrame = nil
  UI.lastRollResult = nil
  UI.lastRollResultAt = nil
  UI.historyFrame = nil
  UI.debugFrame = nil
  UI.debugEditBox = nil
  UI.debugLines = {}
  UI.debugMaxLines = 400
  UI.historySelectedId = nil
  UI.filterText = ""
  UI.noteFilterText = ""
  UI.showOffline = true
  UI.showGuests = true
  UI.sortKey = "name"
  UI.sortAscending = true
  UI.guestAnchorsVisible = false
  UI.sessionStateLabel = nil
  UI.sessionStateDot = nil
  UI.editRosterEnabled = false
  UI.enableNoteSearch = false
  UI.visibleRows = 18
  if NS and NS.Debug and NS.Debug.FlushBuffered then
    NS.Debug:FlushBuffered()
  end
  if not AceGUI then
    return
  end
end

function UI:ToggleMain()
  if not self.mainFrame then
    self:CreateMainFrame()
    self.mainFrame:Show()
    self:RefreshMain()
    if self.Tutorial then
      self.Tutorial:MaybeAutoStart()
    end
    return
  end
  if self.mainFrame:IsShown() then
    self.mainFrame:Hide()
  else
    self.mainFrame:Show()
    self:RefreshMain()
    if self.Tutorial then
      self.Tutorial:MaybeAutoStart()
    end
  end
end

function UI:CreateMainFrame()
  GLD:CreateMainFrame()
  self.mainFrame = GLD.UI and GLD.UI.mainFrame or nil
end

function UI:CreateDebugFrame()
  if not AceGUI or self.debugFrame then
    return
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("GuildLoot Debug")
  frame:SetStatusText("Debug output")
  frame:SetWidth(700)
  frame:SetHeight(420)
  frame:SetLayout("Fill")
  frame:EnableResize(true)
  if frame.frame and frame.frame.SetBackdrop then
    frame.frame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.frame:SetBackdropColor(0, 0, 0, 1)
  end

  frame:SetCallback("OnClose", function(widget)
    widget:Hide()
  end)

  local editBox = AceGUI:Create("MultiLineEditBox")
  editBox:SetLabel("")
  editBox:DisableButton(true)
  editBox:SetFullWidth(true)
  editBox:SetFullHeight(true)
  frame:AddChild(editBox)

  self.debugFrame = frame
  self.debugEditBox = editBox
  if NS and NS.Debug and NS.Debug.FlushBuffered then
    NS.Debug:FlushBuffered()
  end
  self:RefreshDebugLog()
end

function UI:ShowDebugFrame()
  if not self.debugFrame then
    self:CreateDebugFrame()
  end
  if self.debugFrame and not self.debugFrame:IsShown() then
    self.debugFrame:Show()
  end
  self:RefreshDebugLog()
end

function UI:ToggleDebugFrame()
  if not self.debugFrame then
    self:CreateDebugFrame()
    if self.debugFrame then
      self.debugFrame:Show()
    end
    self:RefreshDebugLog()
    return
  end
  if self.debugFrame:IsShown() then
    self.debugFrame:Hide()
  else
    self.debugFrame:Show()
    self:RefreshDebugLog()
  end
end

function UI:AppendDebugLine(msg)
  if msg == nil then
    return
  end
  self.debugLines = self.debugLines or {}
  table.insert(self.debugLines, tostring(msg))
  local maxLines = self.debugMaxLines or 400
  if #self.debugLines > maxLines then
    local overflow = #self.debugLines - maxLines
    for _ = 1, overflow do
      table.remove(self.debugLines, 1)
    end
  end
  if self.debugEditBox then
    self:RefreshDebugLog()
  end
end

function UI:AddDebugLine(msg)
  self:AppendDebugLine(msg)
end

function UI:ClearDebugLog()
  self.debugLines = {}
  self:RefreshDebugLog()
end

function UI:RefreshDebugLog()
  if not self.debugEditBox then
    return
  end
  local lines = self.debugLines or {}
  local text = table.concat(lines, "\n")
  self.debugEditBox:SetText(text)
  if self.debugEditBox.SetCursorPosition then
    self.debugEditBox:SetCursorPosition(#text)
  end
  if self.debugEditBox.scrollFrame and self.debugEditBox.scrollFrame.GetVerticalScrollRange then
    self.debugEditBox.scrollFrame:SetVerticalScroll(self.debugEditBox.scrollFrame:GetVerticalScrollRange())
  end
  if self.debugFrame and self.debugFrame.SetStatusText then
    self.debugFrame:SetStatusText(string.format("Lines: %d", #lines))
  end
end

function UI:RefreshMain()
  if not self.mainFrame then
    return
  end

  if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
    local sessionEnabled = GLD.IsEnabled and GLD:IsEnabled() or false
    local sessionActive = GLD.IsSessionActiveLocal and GLD:IsSessionActiveLocal()
    if sessionActive == nil then
      sessionActive = GLD.IsSessionActive and GLD:IsSessionActive() or false
    end
    local pugsMode = GLD.GetPugsInRaid and GLD:GetPugsInRaid() or false
    local guestCount = GLD.guestAnchorCandidates and #GLD.guestAnchorCandidates or 0
    GLD:Debug(
      "[UIRefresh] sessionEnabled="
        .. tostring(sessionEnabled)
        .. " sessionActive="
        .. tostring(sessionActive)
        .. " pugsMode="
        .. tostring(pugsMode)
        .. " guestCount="
        .. tostring(guestCount)
        .. " guestAnchorsVisible="
        .. tostring(self.guestAnchorsVisible == true)
    )
  end

  if GLD.UpdateGuestAttendanceFromGroup then
    GLD:UpdateGuestAttendanceFromGroup()
  end

  if GLD.UpdateRosterStatusText then
    GLD:UpdateRosterStatusText()
  end

  if GLD.UpdateSessionStateIndicator then
    GLD:UpdateSessionStateIndicator()
  end

  if GLD.UpdateBottomBarPermissions then
    GLD:UpdateBottomBarPermissions()
  end

  if GLD.UpdateGuestPanelLayout then
    GLD:UpdateGuestPanelLayout()
  end

  if self.guestAnchorsVisible and GLD.RefreshGuestAnchors then
    GLD:RefreshGuestAnchors("ui_refresh_main")
  end

  if GLD.RefreshTable then
    GLD:RefreshTable()
  end

  if self.RefreshLootWindow then
    self:RefreshLootWindow()
  end
end

function UI:ShowAdminVotePopup(session, pendingKeys, pendingLabels)
  if not AceGUI or not session then
    return
  end
  if not GLD:IsAuthority() then
    GLD:Print("Only the authority can apply overrides.")
    return
  end

  if self.adminVoteFrame then
    self.adminVoteFrame:Release()
    self.adminVoteFrame = nil
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Admin Vote Override")
  frame:SetStatusText(session.itemName or "Item")
  frame:SetWidth(360)
  frame:SetHeight(220)
  frame:SetLayout("Flow")
  frame:EnableResize(false)

  if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
    local adminName = GLD:GetAuthorityName() or GLD:GetUnitFullName("player") or UnitName("player") or "Unknown"
    local itemLabel = session.itemLink or session.itemName or "Item"
    GLD:Debug(
      "Admin override popup opened: rollID="
        .. tostring(session.rollID)
        .. " item="
        .. tostring(itemLabel)
        .. " by="
        .. tostring(adminName)
    )
  end

  local dropdown = AceGUI:Create("Dropdown")
  dropdown:SetLabel("Select Winner")
  dropdown:SetFullWidth(true)
  local values = {}
  local order = {}
  local forceKey = "GLD_FORCE_PASS"
  values[forceKey] = "Force Pass / Unclaimed"
  order[#order + 1] = forceKey
  for i, key in ipairs(pendingKeys or {}) do
    if key and values[key] == nil then
      local label = pendingLabels and pendingLabels[i] or tostring(key)
      values[key] = label
      order[#order + 1] = key
    end
  end
  if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
    local listPreview = {}
    local cap = math.min(12, #order)
    for i = 1, cap do
      local key = order[i]
      listPreview[#listPreview + 1] = tostring(values[key] or key) .. " [" .. tostring(key) .. "]"
    end
    if #order > cap then
      listPreview[#listPreview + 1] = "...+" .. tostring(#order - cap)
    end
    GLD:Debug(
      "Admin override dropdown options: rollID="
        .. tostring(session.rollID)
        .. " item="
        .. tostring(session.itemLink or session.itemName or "Item")
        .. " count="
        .. tostring(#order)
        .. " options="
        .. table.concat(listPreview, ", ")
    )
  end
  dropdown:SetList(values, order)
  local defaultKey = (pendingKeys and pendingKeys[1]) or forceKey
  if defaultKey and values[defaultKey] then
    dropdown:SetValue(defaultKey)
  elseif order[1] then
    dropdown:SetValue(order[1])
  end
  frame:AddChild(dropdown)

  local applyBtn = AceGUI:Create("Button")
  applyBtn:SetText("Apply Override")
  applyBtn:SetWidth(140)
  applyBtn:SetCallback("OnClick", function()
    local key = dropdown:GetValue()
    if not key then
      GLD:Print("Select a winner first.")
      return
    end
    if key == forceKey then
      key = nil
    end
    if GLD.ApplyAdminOverride then
      GLD:ApplyAdminOverride(session, key)
    end
    frame:Release()
  end)
  frame:AddChild(applyBtn)

  local cancelBtn = AceGUI:Create("Button")
  cancelBtn:SetText("Cancel")
  cancelBtn:SetWidth(100)
  cancelBtn:SetCallback("OnClick", function()
    frame:Release()
  end)
  frame:AddChild(cancelBtn)

  self.adminVoteFrame = frame
end

-- Roster Manager-style UI ---------------------------------------------------
local ROSTER_ROW_HEIGHT = 20
local ROSTER_HEADER_HEIGHT = 22
local ROSTER_COLUMN_PADDING = 2
local ROSTER_ICON_SIZE = 16
local ROSTER_HEADER_AREA_HEIGHT = 36
local ROSTER_BOTTOM_BAR_HEIGHT = 78
local ROSTER_GUEST_PANEL_HEIGHT = 90
local GUEST_ANCHOR_ROW_HEIGHT = 20
local GUEST_ANCHOR_ROW_SIDE_PADDING = 6
local GUEST_ANCHOR_BUTTON_WIDTH = 150
local DEBUG_GUEST_ANCHORS = false
local GUILD_CREST_SIZE = 40
local GUILD_CREST_RETRY_DELAY = 0.5
local GUILD_CREST_MAX_RETRIES = 6
local GUILD_CREST_BACKGROUND_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local GUILD_CREST_SHOW_TABARD_BORDER = false
local GUILD_CREST_USE_TABARD_FILES = true
local GUILD_CREST_INNER_PADDING = 3
local GUILD_CREST_OFFSET_X = 0
local GUILD_CREST_OFFSET_Y = 0
local GUILD_CREST_EMBLEM_SCALE = 1
local GUILD_CREST_EMBLEM_OFFSET_X = -1
local GUILD_CREST_EMBLEM_OFFSET_Y = 3
local GUILD_CREST_EMBLEM_ZOOM = 0.08
local GUILD_CREST_USE_MASK = true
local MAIN_FRAME_HORIZONTAL_PADDING = 32 -- 16 left + 16 right margins
local HEADER_ROW_HORIZONTAL_PADDING = 30 -- 6 left + 24 right margins inside the inset
local MIN_MAIN_FRAME_WIDTH = 520

local function GetFrameDebugName(frame)
  if not frame then
    return "nil"
  end
  local name = frame.GetName and frame:GetName()
  if name and name ~= "" then
    return name
  end
  return tostring(frame)
end

local function GetTopLevelContainer(frame)
  local current = frame
  local guard = 0
  while current and current.GetParent and guard < 64 do
    local parent = current:GetParent()
    if not parent then
      break
    end
    current = parent
    guard = guard + 1
  end
  return current
end

local function GetFrameRectLTRB(frame)
  if not frame or not frame.GetRect then
    return nil, nil, nil, nil
  end
  local left, bottom, width, height = frame:GetRect()
  if not left or not bottom then
    return nil, nil, nil, nil
  end
  local right = left + (width or 0)
  local top = bottom + (height or 0)
  return left, right, top, bottom
end

local function FormatRectLTRB(left, right, top, bottom)
  if not left or not right or not top or not bottom then
    return "nil nil nil nil"
  end
  return string.format("%.1f %.1f %.1f %.1f", left, right, top, bottom)
end

local function FormatFramePoint(frame)
  if not frame or not frame.GetPoint then
    return "nil"
  end
  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
  return string.format(
    "%s->%s:%s(%.1f,%.1f)",
    tostring(point or "nil"),
    GetFrameDebugName(relativeTo),
    tostring(relativePoint or "nil"),
    tonumber(xOfs) or 0,
    tonumber(yOfs) or 0
  )
end

local function RectsIntersect(aLeft, aRight, aTop, aBottom, bLeft, bRight, bTop, bBottom)
  if (not aLeft) or (not aRight) or (not aTop) or (not aBottom) then
    return false
  end
  if (not bLeft) or (not bRight) or (not bTop) or (not bBottom) then
    return false
  end
  return (aLeft < bRight) and (aRight > bLeft) and (aBottom < bTop) and (aTop > bBottom)
end

local function ForceGuestAnchorsLayoutRefresh(panel, ui, refreshReason, dbg)
  if not panel then
    return
  end
  if panel.Show then
    panel:Show()
  end
  if panel.scrollFrame and panel.scrollFrame.Show then
    panel.scrollFrame:Show()
  end
  if panel.scrollChild and panel.scrollChild.Show then
    panel.scrollChild:Show()
  end

  local guestScrollBox = panel.guestScrollBox or panel.scrollBox or (ui and ui.guestScrollBox) or nil
  local didFullUpdate = false
  if guestScrollBox and guestScrollBox.FullUpdate then
    guestScrollBox:FullUpdate()
    didFullUpdate = true
  end
  if panel.scrollFrame and panel.scrollFrame.FullUpdate then
    panel.scrollFrame:FullUpdate()
    didFullUpdate = true
  end
  if panel.scrollFrame and panel.scrollFrame.UpdateScrollChildRect then
    panel.scrollFrame:UpdateScrollChildRect()
  end
  if panel.Layout then
    panel:Layout()
  end
  if panel.MarkDirty then
    panel:MarkDirty()
  end
  if panel.scrollChild and panel.scrollChild.Layout then
    panel.scrollChild:Layout()
  end
  if panel.scrollChild and panel.scrollChild.MarkDirty then
    panel.scrollChild:MarkDirty()
  end
  if dbg and dbg.Throttle then
    dbg:Throttle(
      "ga_layout_refresh",
      0.5,
      "GuestAnchorsUI",
      "LayoutRefresh reason=%s panel=%s scrollFrame=%s guestScrollBox=%s fullUpdate=%s",
      tostring(refreshReason or "unspecified"),
      GetFrameDebugName(panel),
      GetFrameDebugName(panel.scrollFrame),
      GetFrameDebugName(guestScrollBox),
      tostring(didFullUpdate)
    )
  end
end

local function LogGuestAnchorsGeometry(owner, panel, rows, refreshReason, stage, dbg)
  if not panel then
    return
  end
  local shouldLog = DEBUG_GUEST_ANCHORS or (owner and owner.IsDebugEnabled and owner:IsDebugEnabled())
  if not shouldLog then
    return
  end
  local scrollFrame = panel.scrollFrame
  local scrollChild = panel.scrollChild
  if not scrollFrame or not scrollChild then
    return
  end
  local firstRow = rows and rows[1] or nil
  local sfWidth = scrollFrame.GetWidth and scrollFrame:GetWidth() or 0
  local sfHeight = scrollFrame.GetHeight and scrollFrame:GetHeight() or 0
  local scWidth = scrollChild.GetWidth and scrollChild:GetWidth() or 0
  local scHeight = scrollChild.GetHeight and scrollChild:GetHeight() or 0
  local rowWidth = firstRow and firstRow.GetWidth and firstRow:GetWidth() or 0
  local rowHeight = firstRow and firstRow.GetHeight and firstRow:GetHeight() or 0
  local sfRect = FormatRectLTRB(GetFrameRectLTRB(scrollFrame))
  local scRect = FormatRectLTRB(GetFrameRectLTRB(scrollChild))
  local rowRect = firstRow and FormatRectLTRB(GetFrameRectLTRB(firstRow)) or "nil nil nil nil"
  local msg = string.format(
    "[GuestAnchorsSize:%s] reason=%s scrollFrame w=%.1f h=%.1f rect=(%s) scrollChild w=%.1f h=%.1f rect=(%s) firstRow w=%.1f h=%.1f rect=(%s)",
    tostring(stage or "unknown"),
    tostring(refreshReason or "unspecified"),
    tonumber(sfWidth) or 0,
    tonumber(sfHeight) or 0,
    sfRect,
    tonumber(scWidth) or 0,
    tonumber(scHeight) or 0,
    scRect,
    tonumber(rowWidth) or 0,
    tonumber(rowHeight) or 0,
    rowRect
  )
  if owner and owner.IsDebugEnabled and owner:IsDebugEnabled() then
    owner:Debug(msg)
  end
  if dbg and dbg.Throttle then
    dbg:Throttle("ga_size_" .. tostring(stage or "unknown"), 0.3, "GuestAnchorsUI", "%s", msg)
  end
end

local function SyncGuestAnchorsScrollGeometry(owner, panel, rowCount, rows, refreshReason, dbg)
  if not panel then
    return
  end
  local scrollFrame = panel.scrollFrame
  local scrollChild = panel.scrollChild
  if not scrollFrame or not scrollChild then
    return
  end

  if scrollFrame.GetScrollChild and scrollFrame:GetScrollChild() ~= scrollChild then
    scrollFrame:SetScrollChild(scrollChild)
  end

  LogGuestAnchorsGeometry(owner, panel, rows, refreshReason, "before", dbg)

  local frameWidth = scrollFrame.GetWidth and scrollFrame:GetWidth() or 0
  if (not frameWidth) or frameWidth <= 0 then
    local panelWidth = panel.GetWidth and panel:GetWidth() or 0
    frameWidth = math.max(1, (tonumber(panelWidth) or 0) - 34)
  end
  frameWidth = math.max(1, tonumber(frameWidth) or 1)

  local rowWidth = math.max(1, frameWidth - (2 * GUEST_ANCHOR_ROW_SIDE_PADDING))
  local contentHeight = math.max(1, (tonumber(rowCount) or 0) * GUEST_ANCHOR_ROW_HEIGHT)

  scrollChild:SetWidth(frameWidth)
  scrollChild:SetHeight(contentHeight)

  if rows then
    local visibleCount = math.min(tonumber(rowCount) or 0, #rows)
    for i = 1, visibleCount do
      local row = rows[i]
      if row then
        row:SetWidth(rowWidth)
        row:SetHeight(GUEST_ANCHOR_ROW_HEIGHT)
      end
    end
  end

  if scrollFrame.UpdateScrollChildRect then
    scrollFrame:UpdateScrollChildRect()
  end
  if DEBUG_GUEST_ANCHORS and scrollFrame.SetVerticalScroll then
    scrollFrame:SetVerticalScroll(0)
  end

  LogGuestAnchorsGeometry(owner, panel, rows, refreshReason, "after", dbg)
end

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

local function SafeRegisterEvent(frame, event)
  if not frame or not event then
    return false
  end
  local ok = pcall(frame.RegisterEvent, frame, event)
  return ok
end

local function BuildDefaultRosterColumns(includeRemove)
  local columns = {
    { key = "class", label = "Class", width = 32, align = "CENTER", isIcon = true },
    { key = "spec", label = "Spec", width = 32, align = "CENTER", isIcon = true },
    { key = "role", label = "Role", width = 60, align = "CENTER" },
    { key = "name", label = "Name", width = 190, align = "LEFT", sortKey = "name" },
    { key = "queuePos", label = "Queue Pos", width = 72, align = "CENTER", sortKey = "queuePos" },
    { key = "heldPos", label = "Held Pos", width = 72, align = "CENTER", sortKey = "heldPos" },
    { key = "itemsWon", label = "Items Won", width = 80, align = "CENTER", sortKey = "itemsWon" },
    { key = "raidsAttended", label = "Raids Attended", width = 110, align = "CENTER", sortKey = "raidsAttended" },
    { key = "attendance", label = "Attendance", width = 90, align = "CENTER", sortKey = "attendance" },
  }
  if includeRemove then
    columns[#columns + 1] = { key = "remove", label = "Remove", width = 70, align = "CENTER" }
  end
  return columns
end

local function CalculateMainFrameWidth(columns)
  if not columns or #columns == 0 then
    return nil
  end
  local x = 4
  local maxRight = 0
  for _, col in ipairs(columns) do
    local width = (col and col.width) or 0
    local right = x + width
    if right > maxRight then
      maxRight = right
    end
    x = x + width + ROSTER_COLUMN_PADDING
  end
  if maxRight <= 0 then
    return nil
  end
  return math.max(MIN_MAIN_FRAME_WIDTH, maxRight + HEADER_ROW_HORIZONTAL_PADDING + MAIN_FRAME_HORIZONTAL_PADDING)
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

local function NormalizeAttendanceInput(text)
  local key = (text or ""):upper()
  if key == "P" then
    return "PRESENT"
  end
  if key == "A" then
    return "ABSENT"
  end
  if key == "PART" then
    return "PARTIAL"
  end
  if key == "PRESENT" or key == "ABSENT" or key == "PARTIAL" or key == "OFFLINE" then
    return key
  end
  return nil
end

local function SetCheckLabel(check, text)
  if check.Text then
    check.Text:SetText(text)
  elseif check.text then
    check.text:SetText(text)
  end
end

local function DebugGuildCrest(frame, msg)
  if not GLD or not GLD.Debug then
    return
  end
  if frame then
    if frame.guildCrestDebugState == msg then
      return
    end
    frame.guildCrestDebugState = msg
  end
  GLD:Debug("Guild crest: " .. msg)
end

local function FormatFrameSize(frame)
  if not frame or not frame.GetSize then
    return "0x0"
  end
  local width, height = frame:GetSize()
  return string.format("%.1fx%.1f", width or 0, height or 0)
end

local function FormatFramePoint(frame)
  if not frame or not frame.GetPoint then
    return "none"
  end
  local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
  if not point then
    return "none"
  end
  local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
  return string.format("%s %s %s %.1f %.1f", tostring(point), tostring(relativeName), tostring(relativePoint), x or 0, y or 0)
end

local function NormalizeTexCoordValues(a, b, c, d, e, f, g, h)
  if e == nil then
    local left, right, top, bottom = a, b, c, d
    return left, top, left, bottom, right, top, right, bottom
  end
  return a, b, c, d, e, f, g, h
end

local function FormatTexCoordValues(a, b, c, d, e, f, g, h)
  a, b, c, d, e, f, g, h = NormalizeTexCoordValues(a, b, c, d, e, f, g, h)
  return string.format(
    "%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f",
    a or 0,
    b or 0,
    c or 0,
    d or 0,
    e or 0,
    f or 0,
    g or 0,
    h or 0
  )
end

local function DebugTextureState(label, texture)
  if not texture then
    GLD:Debug(label .. "=nil")
    return
  end
  local width, height = texture:GetSize()
  local a, b, c, d, e, f, g, h = texture:GetTexCoord()
  local point, relativeTo, relativePoint, x, y = texture:GetPoint(1)
  local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
  local layer, sublevel = texture:GetDrawLayer()
  local atlas = texture.GetAtlas and texture:GetAtlas() or nil
  GLD:Debug(
    label
      .. " tex="
      .. tostring(texture:GetTexture())
      .. " atlas="
      .. tostring(atlas)
      .. " size="
      .. string.format("%.1fx%.1f", width or 0, height or 0)
      .. " shown="
      .. tostring(texture:IsShown())
      .. " layer="
      .. tostring(layer)
      .. ":"
      .. tostring(sublevel)
      .. " coord="
      .. FormatTexCoordValues(a, b, c, d, e, f, g, h)
      .. " point="
      .. string.format(
        "%s %s %s %.1f %.1f",
        tostring(point),
        tostring(relativeName),
        tostring(relativePoint),
        x or 0,
        y or 0
      )
  )
end

local function IsTexCoordValid(texture)
  if not texture or not texture.GetTexCoord then
    return false
  end
  local left, right, top, bottom = texture:GetTexCoord()
  if not left or not right or not top or not bottom then
    return false
  end
  if right <= left or bottom <= top then
    return false
  end
  return true
end

local function EnsureFullTexCoord(texture, label, crest)
  if not texture then
    return
  end
  local left, right, top, bottom = texture:GetTexCoord()
  if left ~= 0 or right ~= 1 or top ~= 0 or bottom ~= 1 then
    texture:SetTexCoord(0, 1, 0, 1)
    DebugGuildCrest(
      crest and crest.ownerFrame,
      (label or "texture") .. " texcoord reset from " .. FormatTexCoordValues(left, right, top, bottom)
    )
  end
end

local function FindBlizzardEmblemTexture()
  local function TextureHasData(texture)
    if not texture or not texture.GetTexture then
      return false
    end
    local tex = texture:GetTexture()
    local atlas = texture.GetAtlas and texture:GetAtlas() or nil
    return tex ~= nil or atlas ~= nil
  end

  local function FindEmblemInFrame(frame, frameLabel)
    if not frame then
      return nil, nil
    end
    local keys = {
      "Emblem",
      "EmblemTexture",
      "TabardEmblem",
      "TabardEmblemTexture",
    }
    for _, key in ipairs(keys) do
      local tex = frame[key]
      if TextureHasData(tex) then
        return frameLabel .. "." .. key, tex
      end
    end
    if frame.GetRegions then
      local regions = { frame:GetRegions() }
      for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
          local name = region.GetName and region:GetName() or nil
          if name and name:find("Emblem") and TextureHasData(region) then
            return name, region
          end
        end
      end
    end
    return nil, nil
  end

  local candidates = {
    { name = "GuildFrameTabardEmblem", texture = _G.GuildFrameTabardEmblem },
    { name = "GuildFrameTabardEmblemTexture", texture = _G.GuildFrameTabardEmblemTexture },
    { name = "GuildFrameTabard.Emblem", texture = _G.GuildFrameTabard and _G.GuildFrameTabard.Emblem },
    { name = "GuildFrameTabard.EmblemTexture", texture = _G.GuildFrameTabard and _G.GuildFrameTabard.EmblemTexture },
    { name = "GuildFrameTabard.TabardEmblem", texture = _G.GuildFrameTabard and _G.GuildFrameTabard.TabardEmblem },
    { name = "TabardFrame.Emblem", texture = _G.TabardFrame and _G.TabardFrame.Emblem },
    { name = "TabardFrame.EmblemTexture", texture = _G.TabardFrame and _G.TabardFrame.EmblemTexture },
    {
      name = "CommunitiesFrame.GuildDetailsFrame.TabardFrame.Emblem",
      texture = _G.CommunitiesFrame
        and _G.CommunitiesFrame.GuildDetailsFrame
        and _G.CommunitiesFrame.GuildDetailsFrame.TabardFrame
        and _G.CommunitiesFrame.GuildDetailsFrame.TabardFrame.Emblem,
    },
    {
      name = "CommunitiesFrame.GuildDetailsFrame.TabardFrame.EmblemTexture",
      texture = _G.CommunitiesFrame
        and _G.CommunitiesFrame.GuildDetailsFrame
        and _G.CommunitiesFrame.GuildDetailsFrame.TabardFrame
        and _G.CommunitiesFrame.GuildDetailsFrame.TabardFrame.EmblemTexture,
    },
  }
  for _, candidate in ipairs(candidates) do
    local texture = candidate.texture
    if TextureHasData(texture) then
      return candidate.name, texture
    end
  end
  local name, texture = FindEmblemInFrame(_G.GuildFrameTabard, "GuildFrameTabard")
  if texture then
    return name, texture
  end
  name, texture = FindEmblemInFrame(_G.TabardFrame, "TabardFrame")
  if texture then
    return name, texture
  end
  if _G.CommunitiesFrame and _G.CommunitiesFrame.GuildDetailsFrame then
    name, texture = FindEmblemInFrame(_G.CommunitiesFrame.GuildDetailsFrame.TabardFrame, "CommunitiesFrame.GuildDetailsFrame.TabardFrame")
    if texture then
      return name, texture
    end
  end
  for name, obj in pairs(_G) do
    if type(name) == "string"
      and name:find("Tabard")
      and name:find("Emblem")
      and not name:find("Top")
      and not name:find("Bottom")
      and not name:find("Left")
      and not name:find("Right")
      and obj
      and obj.GetObjectType
    then
      if obj:GetObjectType() == "Texture" and TextureHasData(obj) then
        return name, obj
      end
    end
  end
  return nil, nil
end

local function DebugEmblemState(crest, tag)
  if not GLD or not GLD.IsDebugEnabled or not GLD:IsDebugEnabled() then
    return
  end
  if not crest then
    return
  end
  local key = tostring(tag)
  if crest.lastEmblemDebugTag == key then
    return
  end
  crest.lastEmblemDebugTag = key
  local ownerName = crest.ownerFrame and crest.ownerFrame.GetName and crest.ownerFrame:GetName() or tostring(crest.ownerFrame)
  GLD:Debug("Guild crest: emblem dump (" .. key .. ") owner=" .. tostring(ownerName))
  GLD:Debug("Guild crest: crest size=" .. FormatFrameSize(crest) .. " point=" .. FormatFramePoint(crest))
  if crest.anchorFrame then
    local anchorName = crest.anchorFrame.GetName and crest.anchorFrame:GetName() or tostring(crest.anchorFrame)
    GLD:Debug(
      "Guild crest: anchor="
        .. tostring(anchorName)
        .. " size="
        .. FormatFrameSize(crest.anchorFrame)
        .. " point="
        .. FormatFramePoint(crest.anchorFrame)
    )
  end
  DebugTextureState("Guild crest: emblem", crest.TabardEmblem)
  DebugTextureState("Guild crest: emblemUpper", crest.TabardEmblemUpper)
  DebugTextureState("Guild crest: emblemLower", crest.TabardEmblemLower)
  DebugTextureState("Guild crest: background", crest.TabardBackground)
  DebugTextureState("Guild crest: mask", crest.Mask)
  local blizzardName, blizzardEmblem = FindBlizzardEmblemTexture()
  if blizzardEmblem then
    DebugTextureState("Guild crest: blizzard emblem (" .. tostring(blizzardName) .. ")", blizzardEmblem)
  else
    GLD:Debug("Guild crest: blizzard emblem not found")
  end
  local emblemTex = crest.TabardEmblem or crest.TabardEmblemUpper or crest.TabardEmblemLower
  if emblemTex and crest.GetSize and crest.GetPoint and emblemTex.GetSize and emblemTex.GetPoint then
    print("CrestHolder", crest:GetSize(), crest:GetPoint(1))
    print("Emblem", emblemTex:GetSize(), emblemTex:GetPoint(1))
  end
end

local function GetGuildTabardColor(color, defaultR, defaultG, defaultB)
  if not color then
    return defaultR, defaultG, defaultB
  end
  if type(color) == "table" then
    if color.GetRGB then
      return color:GetRGB()
    end
    if color.r and color.g and color.b then
      return color.r, color.g, color.b
    end
    if color[1] and color[2] and color[3] then
      return color[1], color[2], color[3]
    end
  end
  return defaultR, defaultG, defaultB
end

local function GetGuildTabardInfoCompat(unit)
  if C_GuildInfo and C_GuildInfo.GetGuildTabardInfo then
    return C_GuildInfo.GetGuildTabardInfo(unit)
  end
  if GetGuildTabardInfo then
    local ok, a, b, c, d, e, f = pcall(GetGuildTabardInfo, unit)
    if not ok then
      return nil
    end
    if type(a) == "table" then
      return a
    end
    if a == nil and b == nil and c == nil and d == nil and e == nil and f == nil then
      return nil
    end
    return {
      backgroundFileID = a,
      borderFileID = b,
      emblemFileID = c,
      backgroundColor = d,
      borderColor = e,
      emblemColor = f,
    }
  end
  return nil
end

local function FormatGuildTabardColor(color)
  if not color then
    return "nil"
  end
  if type(color) == "table" then
    if color.GetRGB then
      local r, g, b = color:GetRGB()
      return string.format("%.2f,%.2f,%.2f", r, g, b)
    end
    if color.r and color.g and color.b then
      return string.format("%.2f,%.2f,%.2f", color.r, color.g, color.b)
    end
    if color[1] and color[2] and color[3] then
      return string.format("%.2f,%.2f,%.2f", color[1], color[2], color[3])
    end
  end
  return tostring(color)
end

local function FormatTabardFiles(results)
  if not results or #results == 0 then
    return "none"
  end
  local parts = {}
  for i = 1, #results do
    parts[i] = tostring(results[i])
  end
  return table.concat(parts, ",")
end

local function ResolvePortraitAnchor(frame)
  if not frame then
    return nil
  end
  if frame.PortraitFrame then
    return frame.PortraitFrame.Portrait or frame.PortraitFrame
  end
  if frame.portrait then
    return frame.portrait
  end
  if frame.Portrait then
    return frame.Portrait
  end
  local name = frame.GetName and frame:GetName()
  if name then
    return _G[name .. "Portrait"] or _G[name .. "PortraitFrame"] or _G[name .. "PortraitFramePortrait"]
  end
  return nil
end

local function ResolvePortraitParent(anchor, frame)
  if not anchor then
    return frame
  end
  if anchor.GetObjectType and anchor:GetObjectType() == "Texture" then
    return anchor:GetParent() or frame
  end
  return anchor
end

local function ApplyCrestMask(crest)
  if not crest or not crest.Mask or not GUILD_CREST_USE_MASK then
    return
  end
  if crest.maskApplied then
    return
  end
  local mask = crest.Mask
  local textures = {
    crest.TabardBackground,
    crest.TabardBorder,
    crest.TabardEmblem,
    crest.TabardBackgroundUpper,
    crest.TabardBackgroundLower,
    crest.TabardEmblemUpper,
    crest.TabardEmblemLower,
    crest.TabardBorderUpper,
    crest.TabardBorderLower,
  }
  for _, tex in ipairs(textures) do
    if tex and tex.AddMaskTexture then
      tex:AddMaskTexture(mask)
    end
  end
  crest.maskApplied = true
end

local function UpdateCrestLayout(crest, anchor)
  if not crest then
    return
  end
  local size = GUILD_CREST_SIZE
  if anchor and anchor.GetWidth and anchor.GetHeight then
    local width = anchor:GetWidth()
    local height = anchor:GetHeight()
    if width and height and width > 0 and height > 0 then
      size = math.min(width, height)
    end
  end
  if GUILD_CREST_INNER_PADDING and GUILD_CREST_INNER_PADDING > 0 then
    size = math.max(1, size - (GUILD_CREST_INNER_PADDING * 2))
  end
  crest:SetSize(size, size)
  local emblemScale = tonumber(GUILD_CREST_EMBLEM_SCALE) or 1
  local emblemOffsetX = tonumber(GUILD_CREST_EMBLEM_OFFSET_X) or 0
  local emblemOffsetY = tonumber(GUILD_CREST_EMBLEM_OFFSET_Y) or 0
  if emblemScale <= 0 then
    emblemScale = 1
  end
  local emblemWidth = math.max(1, size * emblemScale)
  local emblemHeight = math.max(1, size * emblemScale)
  local emblemHalfHeight = emblemHeight / 2
  local emblemQuarterHeight = emblemHeight / 4

  local function SetupFull(tex)
    if not tex then
      return
    end
    tex:ClearAllPoints()
    tex:SetAllPoints(crest)
    tex:SetTexCoord(0, 1, 0, 1)
  end

  local function SetupHalf(tex, position)
    if not tex then
      return
    end
    tex:ClearAllPoints()
    if position == "TOP" then
      tex:SetPoint("TOPLEFT", crest, "TOPLEFT", 0, 0)
      tex:SetPoint("TOPRIGHT", crest, "TOPRIGHT", 0, 0)
      tex:SetHeight(size / 2)
    else
      tex:SetPoint("BOTTOMLEFT", crest, "BOTTOMLEFT", 0, 0)
      tex:SetPoint("BOTTOMRIGHT", crest, "BOTTOMRIGHT", 0, 0)
      tex:SetHeight(size / 2)
    end
    tex:SetTexCoord(0, 1, 0, 1)
  end

  local function SetupEmblemFull(tex)
    if not tex then
      return
    end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", crest, "CENTER", emblemOffsetX, emblemOffsetY)
    tex:SetSize(emblemWidth, emblemHeight)
  end

  local function SetupEmblemHalf(tex, position)
    if not tex then
      return
    end
    tex:ClearAllPoints()
    if position == "TOP" then
      tex:SetPoint("CENTER", crest, "CENTER", emblemOffsetX, emblemOffsetY + emblemQuarterHeight)
    else
      tex:SetPoint("CENTER", crest, "CENTER", emblemOffsetX, emblemOffsetY - emblemQuarterHeight)
    end
    tex:SetSize(emblemWidth, emblemHalfHeight)
  end

  SetupFull(crest.TabardBackground)
  SetupFull(crest.TabardBorder)
  SetupEmblemFull(crest.TabardEmblem)
  SetupHalf(crest.TabardBackgroundUpper, "TOP")
  SetupHalf(crest.TabardBackgroundLower, "BOTTOM")
  SetupEmblemHalf(crest.TabardEmblemUpper, "TOP")
  SetupEmblemHalf(crest.TabardEmblemLower, "BOTTOM")
  SetupFull(crest.TabardBorderUpper)
  SetupFull(crest.TabardBorderLower)
  if crest.Mask then
    crest.Mask:ClearAllPoints()
    crest.Mask:SetAllPoints(crest)
    crest.Mask:SetTexCoord(0, 1, 0, 1)
  end
  ApplyCrestMask(crest)
end

local function SetTabardTexturePiece(texture, fileID, r, g, b, show)
  if not texture then
    return false
  end
  if not fileID or fileID == 0 then
    texture:Hide()
    return false
  end
  texture:SetTexture(fileID)
  EnsureFullTexCoord(texture, "tabard-piece", texture and texture:GetParent())
  if r and g and b then
    texture:SetVertexColor(r, g, b, 1)
  end
  if show then
    texture:Show()
  else
    texture:Hide()
  end
  return true
end

local function GetEmblemTexCoord(emblemTexture)
  if not emblemTexture or not C_Texture or not C_Texture.GetTextureInfo then
    return 0, 1, 0, 1
  end
  local ok, width, height = pcall(C_Texture.GetTextureInfo, emblemTexture)
  if not ok then
    return 0, 1, 0, 1
  end
  if type(width) == "table" then
    local info = width
    width = info.width or info[1]
    height = info.height or info[2]
  end
  if not width or not height or height <= 0 then
    return 0, 1, 0, 1
  end
  -- Some emblem textures are 2x1 with the emblem art on the right half.
  if (width / height) >= 1.5 then
    return 0.5, 1, 0, 1
  end
  return 0, 1, 0, 1
end

local function TexCoordsEqual(a, b)
  if not a or not b or #a ~= #b then
    return false
  end
  for i = 1, #a do
    if math.abs((a[i] or 0) - (b[i] or 0)) > 0.0001 then
      return false
    end
  end
  return true
end

local function ApplyEmblemZoomToTexture(texture)
  if not texture or not texture.GetTexCoord or not texture.SetTexCoord then
    return
  end
  local zoom = tonumber(GUILD_CREST_EMBLEM_ZOOM) or 0
  if zoom <= 0 then
    return
  end
  if zoom > 0.49 then
    zoom = 0.49
  end
  local a, b, c, d, e, f, g, h = texture:GetTexCoord()
  a, b, c, d, e, f, g, h = NormalizeTexCoordValues(a, b, c, d, e, f, g, h)
  local current = { a, b, c, d, e, f, g, h }
  if texture.gldZoomedTexCoord and TexCoordsEqual(texture.gldZoomedTexCoord, current) then
    return
  end
  local minX = math.min(a, c, e, g)
  local maxX = math.max(a, c, e, g)
  local minY = math.min(b, d, f, h)
  local maxY = math.max(b, d, f, h)
  if minX == maxX or minY == maxY then
    return
  end
  local scale = 1 - (zoom * 2)
  if scale <= 0 then
    return
  end
  local centerX = (minX + maxX) * 0.5
  local centerY = (minY + maxY) * 0.5
  local function scaleX(x)
    return centerX + (x - centerX) * scale
  end
  local function scaleY(y)
    return centerY + (y - centerY) * scale
  end
  local na, nb, nc, nd, ne, nf, ng, nh =
    scaleX(a), scaleY(b), scaleX(c), scaleY(d), scaleX(e), scaleY(f), scaleX(g), scaleY(h)
  texture:SetTexCoord(na, nb, nc, nd, ne, nf, ng, nh)
  texture.gldZoomedTexCoord = { na, nb, nc, nd, ne, nf, ng, nh }
end

local function ApplyEmblemZoom(crest)
  if not crest then
    return
  end
  local hasSingle = crest.TabardEmblem and crest.TabardEmblem:GetTexture()
  local hasPieces = (crest.TabardEmblemUpper and crest.TabardEmblemUpper:GetTexture())
    or (crest.TabardEmblemLower and crest.TabardEmblemLower:GetTexture())
  if hasSingle and not hasPieces then
    ApplyEmblemZoomToTexture(crest.TabardEmblem)
  end
end

local function ApplyGuildEmblemTexture(crest, emblemTexture, r, g, b)
  if not crest or not crest.TabardEmblem then
    return false
  end
  local emblem = crest.TabardEmblem
  emblem:ClearAllPoints()
  emblem:SetAllPoints(crest)
  emblem:SetTexture(emblemTexture)
  local left, right, top, bottom = GetEmblemTexCoord(emblemTexture)
  emblem:SetTexCoord(left, right, top, bottom)
  if r and g and b then
    emblem:SetVertexColor(r, g, b, 1)
  end
  ApplyEmblemZoomToTexture(emblem)
  local a, b, c, d, e, f, g, h = emblem:GetTexCoord()
  print("emblem texcoord", FormatTexCoordValues(a, b, c, d, e, f, g, h))
  emblem:Show()
  return emblem:GetTexture() ~= nil
end

local function HideTabardSingles(crest)
  if not crest then
    return
  end
  if crest.TabardBackground then
    crest.TabardBackground:Hide()
  end
  if crest.TabardEmblem then
    crest.TabardEmblem:Hide()
  end
  if crest.TabardBorder then
    crest.TabardBorder:Hide()
  end
end

local function HideTabardPieces(crest)
  if not crest then
    return
  end
  if crest.TabardBackgroundUpper then
    crest.TabardBackgroundUpper:Hide()
  end
  if crest.TabardBackgroundLower then
    crest.TabardBackgroundLower:Hide()
  end
  if crest.TabardEmblemUpper then
    crest.TabardEmblemUpper:Hide()
  end
  if crest.TabardEmblemLower then
    crest.TabardEmblemLower:Hide()
  end
  if crest.TabardBorderUpper then
    crest.TabardBorderUpper:Hide()
  end
  if crest.TabardBorderLower then
    crest.TabardBorderLower:Hide()
  end
end

local function HideEmblemSingles(crest)
  if not crest then
    return
  end
  if crest.TabardEmblem then
    crest.TabardEmblem:Hide()
  end
end

local function TrySetGuildCrestFromTabardFiles(crest, unit)
  if not GetGuildTabardFiles then
    DebugGuildCrest(crest and crest.ownerFrame, "GetGuildTabardFiles missing")
    return false
  end

  local results = { pcall(GetGuildTabardFiles) }
  local ok = table.remove(results, 1)
  if (not ok or #results == 0) and unit then
    local unitResults = { pcall(GetGuildTabardFiles, unit) }
    local unitOk = table.remove(unitResults, 1)
    if unitOk and #unitResults > 0 then
      results = unitResults
      ok = true
    end
  end
  if not ok then
    DebugGuildCrest(crest and crest.ownerFrame, "GetGuildTabardFiles error")
    return false
  end
  if #results == 0 then
    DebugGuildCrest(crest and crest.ownerFrame, "GetGuildTabardFiles returned no files")
    return false
  end
  DebugGuildCrest(
    crest and crest.ownerFrame,
    "GetGuildTabardFiles count=" .. tostring(#results) .. " files=" .. FormatTabardFiles(results)
  )

  local info = GetGuildTabardInfoCompat("player")
  local bgR, bgG, bgB = GetGuildTabardColor(info and info.backgroundColor, 0, 0, 0)
  local emR, emG, emB = GetGuildTabardColor(info and info.emblemColor, 1, 1, 1)
  local brR, brG, brB = GetGuildTabardColor(info and info.borderColor, 1, 1, 1)

  local appliedEmblem = false
  if #results >= 6 then
    local bgUpper, bgLower, borderUpper, borderLower, emblemUpper, emblemLower =
      results[1], results[2], results[3], results[4], results[5], results[6]
    HideTabardSingles(crest)
    SetTabardTexturePiece(crest.TabardBackgroundUpper, bgUpper, bgR, bgG, bgB, true)
    SetTabardTexturePiece(crest.TabardBackgroundLower, bgLower, bgR, bgG, bgB, true)
    local hasEmblemUpper = SetTabardTexturePiece(crest.TabardEmblemUpper, emblemUpper, emR, emG, emB, true)
    local hasEmblemLower = SetTabardTexturePiece(crest.TabardEmblemLower, emblemLower, emR, emG, emB, true)
    appliedEmblem = hasEmblemUpper and hasEmblemLower
    ApplyEmblemZoom(crest)
    DebugEmblemState(
      crest,
      "tabard-files-upper-lower:" .. tostring(emblemUpper) .. ":" .. tostring(emblemLower)
    )
    SetTabardTexturePiece(crest.TabardBorderUpper, borderUpper, brR, brG, brB, GUILD_CREST_SHOW_TABARD_BORDER)
    SetTabardTexturePiece(crest.TabardBorderLower, borderLower, brR, brG, brB, GUILD_CREST_SHOW_TABARD_BORDER)
  else
    local bgFile, borderFile, emblemFile = results[1], results[2], results[3]
    HideTabardPieces(crest)
    SetTabardTexturePiece(crest.TabardBackground, bgFile, bgR, bgG, bgB, true)
    appliedEmblem = SetTabardTexturePiece(crest.TabardEmblem, emblemFile, emR, emG, emB, true)
    ApplyEmblemZoom(crest)
    DebugEmblemState(crest, "tabard-files-single:" .. tostring(emblemFile))
    SetTabardTexturePiece(crest.TabardBorder, borderFile, brR, brG, brB, GUILD_CREST_SHOW_TABARD_BORDER)
  end

  if appliedEmblem then
    DebugGuildCrest(
      crest and crest.ownerFrame,
      "applied tabard files count=" .. tostring(#results) .. " bg=" .. FormatGuildTabardColor(info and info.backgroundColor)
        .. " em=" .. FormatGuildTabardColor(info and info.emblemColor)
    )
    return true
  end

  DebugGuildCrest(
    crest and crest.ownerFrame,
    "tabard files missing emblem piece count=" .. tostring(#results)
  )
  return false
end

local function TrySetGuildCrestEmblemFromTabardFiles(crest, unit)
  if not GetGuildTabardFiles then
    return false
  end
  local results = { pcall(GetGuildTabardFiles, unit or "player") }
  local ok = table.remove(results, 1)
  if not ok or #results < 6 then
    return false
  end

  local emblemUpper, emblemLower = results[5], results[6]
  local info = GetGuildTabardInfoCompat("player")
  local emR, emG, emB = GetGuildTabardColor(info and info.emblemColor, 1, 1, 1)

  HideTabardPieces(crest)
  HideEmblemSingles(crest)
  local hasUpper = SetTabardTexturePiece(crest.TabardEmblemUpper, emblemUpper, emR, emG, emB, true)
  local hasLower = SetTabardTexturePiece(crest.TabardEmblemLower, emblemLower, emR, emG, emB, true)
  if hasUpper and hasLower then
    ApplyEmblemZoom(crest)
    DebugGuildCrest(
      crest and crest.ownerFrame,
      "applied emblem pieces from tabard files upper=" .. tostring(emblemUpper) .. " lower=" .. tostring(emblemLower)
    )
    DebugEmblemState(crest, "tabard-files-emblem-only:" .. tostring(emblemUpper) .. ":" .. tostring(emblemLower))
    return true
  end
  return false
end

local function TrySetGuildCrestFromTabardInfo(crest, unit)
  if not crest then
    DebugGuildCrest(crest and crest.ownerFrame, "missing crest")
    return false
  end

  local info = GetGuildTabardInfoCompat(unit)
  if not info then
    DebugGuildCrest(crest.ownerFrame, "tabard info nil")
    return false
  end

  local emblemTexture = info.emblemFileID or info.emblemTexture or info.emblemFile
  if not emblemTexture or (type(emblemTexture) == "number" and emblemTexture == 0) then
    DebugGuildCrest(crest.ownerFrame, "tabard info missing emblem file id: " .. tostring(emblemTexture))
    return false
  end

  local bgR, bgG, bgB = GetGuildTabardColor(info.backgroundColor, 0, 0, 0)
  local emR, emG, emB = GetGuildTabardColor(info.emblemColor, 1, 1, 1)

  HideTabardPieces(crest)
  if crest.TabardBackground then
    crest.TabardBackground:SetTexture(GUILD_CREST_BACKGROUND_TEXTURE)
    EnsureFullTexCoord(crest.TabardBackground, "background", crest)
    crest.TabardBackground:SetVertexColor(bgR, bgG, bgB, 1)
    crest.TabardBackground:Show()
  end
  local hasEmblem = ApplyGuildEmblemTexture(crest, emblemTexture, emR, emG, emB)
  if crest.TabardBorder then
    crest.TabardBorder:Hide()
  end
  if hasEmblem then
    ApplyEmblemZoom(crest)
    DebugGuildCrest(
      crest.ownerFrame,
      "applied emblem=" .. tostring(emblemTexture) .. " bg=" .. FormatGuildTabardColor(info.backgroundColor)
        .. " em=" .. FormatGuildTabardColor(info.emblemColor)
    )
    DebugEmblemState(crest, "tabard-info:" .. tostring(emblemTexture))
  else
    DebugGuildCrest(crest.ownerFrame, "emblem texture missing after apply: " .. tostring(emblemTexture))
    DebugEmblemState(crest, "tabard-info-missing:" .. tostring(emblemTexture))
    return false
  end
  return true
end

local function TrySetGuildCrestFromHelpers(crest, unit)
  if SetLargeGuildTabardTextures then
    if crest and crest.TabardEmblem and crest.TabardBackground and crest.TabardBorder then
      if pcall(SetLargeGuildTabardTextures, unit or "player", crest.TabardEmblem, crest.TabardBackground, crest.TabardBorder) then
        local hasEmblem = crest.TabardEmblem and crest.TabardEmblem:GetTexture()
        if hasEmblem then
          HideTabardPieces(crest)
          if not GUILD_CREST_SHOW_TABARD_BORDER and crest.TabardBorder then
            crest.TabardBorder:Hide()
          end
          ApplyEmblemZoom(crest)
          DebugGuildCrest(crest and crest.ownerFrame, "applied SetLargeGuildTabardTextures (textures)")
          DebugEmblemState(crest, "helper-large-textures")
          return true
        end
      end
    end
    if pcall(SetLargeGuildTabardTextures, crest, unit) or pcall(SetLargeGuildTabardTextures, unit, crest) then
      local hasEmblem = (crest.TabardEmblem and crest.TabardEmblem:GetTexture())
        or (crest.TabardEmblemUpper and crest.TabardEmblemUpper:GetTexture())
      if hasEmblem then
        if crest.TabardEmblemUpper and crest.TabardEmblemUpper:GetTexture() then
          HideTabardSingles(crest)
        elseif crest.TabardEmblem and crest.TabardEmblem:GetTexture() then
          HideTabardPieces(crest)
        end
        ApplyEmblemZoom(crest)
        DebugGuildCrest(crest and crest.ownerFrame, "applied SetLargeGuildTabardTextures")
        DebugEmblemState(crest, "helper-large")
        return true
      end
    end
  end
  if SetSmallGuildTabardTextures then
    if pcall(SetSmallGuildTabardTextures, crest, unit) or pcall(SetSmallGuildTabardTextures, unit, crest) then
      local hasEmblem = (crest.TabardEmblem and crest.TabardEmblem:GetTexture())
        or (crest.TabardEmblemUpper and crest.TabardEmblemUpper:GetTexture())
      if hasEmblem then
        if crest.TabardEmblemUpper and crest.TabardEmblemUpper:GetTexture() then
          HideTabardSingles(crest)
        elseif crest.TabardEmblem and crest.TabardEmblem:GetTexture() then
          HideTabardPieces(crest)
        end
        ApplyEmblemZoom(crest)
        DebugGuildCrest(crest and crest.ownerFrame, "applied SetSmallGuildTabardTextures")
        DebugEmblemState(crest, "helper-small")
        return true
      end
    end
  end
  return false
end

local function TrySetGuildCrestTextures(crest, unit)
  if TrySetGuildCrestFromHelpers(crest, unit) then
    return true
  end
  if GUILD_CREST_USE_TABARD_FILES and TrySetGuildCrestEmblemFromTabardFiles(crest, unit) then
    return true
  end
  if TrySetGuildCrestFromTabardInfo(crest, unit) then
    return true
  end
  if GUILD_CREST_USE_TABARD_FILES and TrySetGuildCrestFromTabardFiles(crest, unit) then
    return true
  end
  return false
end

local function UpdateGuildCrest(frame)
  if not frame then
    return
  end
  if frame.PortraitFrame then
    frame.PortraitFrame:Show()
  end
  if frame.portrait then
    frame.portrait:Hide()
  end
  local portraitAnchor = ResolvePortraitAnchor(frame)
  local portraitParent = ResolvePortraitParent(portraitAnchor, frame)
  if not portraitParent then
    return
  end

  if not frame.guildCrest then
    local crest = CreateFrame("Frame", nil, portraitParent)
    crest:SetSize(GUILD_CREST_SIZE, GUILD_CREST_SIZE)
    if portraitParent.GetFrameLevel then
      crest:SetFrameLevel(portraitParent:GetFrameLevel() + 2)
    end
    crest.TabardBackground = crest:CreateTexture(nil, "BACKGROUND")
    crest.TabardBorder = crest:CreateTexture(nil, "BORDER")
    crest.TabardEmblem = crest:CreateTexture(nil, "ARTWORK")
    crest.TabardBackgroundUpper = crest:CreateTexture(nil, "BACKGROUND")
    crest.TabardBackgroundLower = crest:CreateTexture(nil, "BACKGROUND")
    crest.TabardEmblemUpper = crest:CreateTexture(nil, "ARTWORK")
    crest.TabardEmblemLower = crest:CreateTexture(nil, "ARTWORK")
    crest.TabardBorderUpper = crest:CreateTexture(nil, "BORDER")
    crest.TabardBorderLower = crest:CreateTexture(nil, "BORDER")
    crest.Mask = crest:CreateMaskTexture()
    crest.TabardBackground:SetAllPoints(crest)
    crest.TabardBorder:SetAllPoints(crest)
    crest.TabardEmblem:SetAllPoints(crest)
    crest.TabardBackground:SetTexture(GUILD_CREST_BACKGROUND_TEXTURE)
    crest.Mask:SetTexture(GUILD_CREST_BACKGROUND_TEXTURE)
    crest.Mask:SetAllPoints(crest)
    crest.Mask:SetTexCoord(0, 1, 0, 1)
    crest.ownerFrame = frame
    frame.guildCrest = crest
  end
  if portraitParent and frame.guildCrest:GetParent() ~= portraitParent then
    frame.guildCrest:SetParent(portraitParent)
    if portraitParent.GetFrameLevel then
      frame.guildCrest:SetFrameLevel(portraitParent:GetFrameLevel() + 2)
    end
  end
  frame.guildCrest:ClearAllPoints()
  if portraitAnchor then
    frame.guildCrest:SetPoint(
      "CENTER",
      portraitAnchor,
      "CENTER",
      GUILD_CREST_OFFSET_X or 0,
      GUILD_CREST_OFFSET_Y or 0
    )
  else
    frame.guildCrest:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    DebugGuildCrest(frame, "portrait anchor missing; using fallback top-left anchor")
  end
  frame.guildCrest.anchorFrame = portraitAnchor
  UpdateCrestLayout(frame.guildCrest, portraitAnchor)

  if IsInGuild and IsInGuild() then
    if TrySetGuildCrestTextures(frame.guildCrest, "player") then
      frame.guildCrest:Show()
      frame.guildCrestRetries = 0
    else
      frame.guildCrest:Hide()
      DebugGuildCrest(frame, "crest data not ready; requesting guild roster")
      if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
      elseif GuildRoster then
        GuildRoster()
      end
      if C_Timer and C_Timer.After then
        local retries = frame.guildCrestRetries or 0
        if retries < GUILD_CREST_MAX_RETRIES and not frame.guildCrestRetryPending then
          frame.guildCrestRetryPending = true
          frame.guildCrestRetries = retries + 1
          DebugGuildCrest(
            frame,
            "crest retry scheduled " .. tostring(frame.guildCrestRetries) .. "/" .. tostring(GUILD_CREST_MAX_RETRIES)
          )
          C_Timer.After(GUILD_CREST_RETRY_DELAY, function()
            if not frame then
              return
            end
            frame.guildCrestRetryPending = nil
            UpdateGuildCrest(frame)
          end)
        end
      end
    end
  else
    DebugGuildCrest(frame, "not in guild")
    frame.guildCrest:Hide()
    frame.guildCrestRetries = 0
  end
end

function GLD:CreateMainFrame()
  local ui = self.UI
  if ui.mainFrame then
    return ui.mainFrame
  end

  local frame = CreateFrame("Frame", "GLDMainFrame", UIParent, "ButtonFrameTemplate")
  frame:SetSize(1200, 580)
  frame:SetPoint("CENTER")
  if frame.TitleText then
    frame.TitleText:SetText("Guild Loot Distribution")
  end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  UpdateGuildCrest(frame)
  frame:HookScript("OnShow", function()
    UpdateGuildCrest(frame)
  end)
  SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")
  SafeRegisterEvent(frame, "PLAYER_GUILD_UPDATE")
  SafeRegisterEvent(frame, "GUILD_ROSTER_UPDATE")
  frame:HookScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
      if event == "GUILD_ROSTER_UPDATE" and not frame.guildCrestRosterEventLogged then
        frame.guildCrestRosterEventLogged = true
        DebugGuildCrest(frame, "event GUILD_ROSTER_UPDATE fired")
      end
      UpdateGuildCrest(frame)
    end
  end)
  AddSpecialFrame(frame:GetName())

  local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  local closeButton = frame.CloseButton or (frame:GetName() and _G[frame:GetName() .. "CloseButton"])
  if closeButton then
    statusText:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
  else
    statusText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -6)
  end
  statusText:SetText("")
  ui.statusText = statusText

    ui.mainFrame = frame
    ui.headerArea = self:CreateHeaderArea(frame)
    ui.bottomBar = self:CreateBottomBar(frame)
    ui.guestPanel = self:CreateGuestPanel(frame)
    ui.tableInset, ui.headerRow, ui.scrollBox, ui.scrollBar = self:CreateTable(frame)

    self:UpdateGuestPanelLayout()
    local requiredWidth = CalculateMainFrameWidth(ui.rosterColumns)
    if requiredWidth then
      frame:SetWidth(requiredWidth)
    end
    self:UpdateHeaderSortIndicators()
    return frame
  end

function GLD:CreateHeaderArea(frame)
  local ui = self.UI
  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -32)
  header:SetHeight(ROSTER_HEADER_AREA_HEIGHT)

  local label = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("LEFT", header, "LEFT", 42, 0)
  label:SetText("Player Search")

  local searchBox = CreateFrame("EditBox", nil, header, "SearchBoxTemplate")
  searchBox:SetSize(200, 20)
  searchBox:SetPoint("LEFT", label, "RIGHT", 8, 0)
  searchBox:SetAutoFocus(false)
  searchBox:SetText(ui.filterText or "")
  searchBox:SetScript("OnTextChanged", function(box)
    if SearchBoxTemplate_OnTextChanged then
      SearchBoxTemplate_OnTextChanged(box)
    end
    ui.filterText = box:GetText() or ""
    self:RefreshTable()
  end)
  if SearchBoxTemplate_OnEditFocusGained then
    searchBox:SetScript("OnEditFocusGained", SearchBoxTemplate_OnEditFocusGained)
  end
  if SearchBoxTemplate_OnEditFocusLost then
    searchBox:SetScript("OnEditFocusLost", SearchBoxTemplate_OnEditFocusLost)
  end
  ui.searchBox = searchBox

  local stateLabel = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  stateLabel:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
  stateLabel:SetText("Session State")
  ui.sessionStateLabel = stateLabel

  local stateDot = header:CreateTexture(nil, "ARTWORK")
  stateDot:SetSize(12, 12)
  stateDot:SetPoint("LEFT", stateLabel, "RIGHT", 6, 0)
  stateDot:SetTexture("Interface\\COMMON\\Indicator-Red")
  ui.sessionStateDot = stateDot

  if ui.enableNoteSearch then
    local noteBox = CreateFrame("EditBox", nil, header, "SearchBoxTemplate")
    noteBox:SetSize(200, 20)
    noteBox:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    noteBox:SetAutoFocus(false)
    noteBox:SetText(ui.noteFilterText or "")
    noteBox:SetScript("OnTextChanged", function(box)
      if SearchBoxTemplate_OnTextChanged then
        SearchBoxTemplate_OnTextChanged(box)
      end
      ui.noteFilterText = box:GetText() or ""
      self:RefreshTable()
    end)
    if SearchBoxTemplate_OnEditFocusGained then
      noteBox:SetScript("OnEditFocusGained", SearchBoxTemplate_OnEditFocusGained)
    end
    if SearchBoxTemplate_OnEditFocusLost then
      noteBox:SetScript("OnEditFocusLost", SearchBoxTemplate_OnEditFocusLost)
    end

    local noteLabel = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    noteLabel:SetPoint("RIGHT", noteBox, "LEFT", -8, 0)
    noteLabel:SetText("Note Search")
    ui.noteSearchBox = noteBox
  end

  return header
end

function GLD:CreateTable(frame)
  local ui = self.UI
  local showRemove = false
  if not ui.rosterColumns or ui.rosterColumnsIsAdmin ~= showRemove then
    ui.rosterColumns = BuildDefaultRosterColumns(showRemove)
    ui.rosterColumnsIsAdmin = showRemove
  end
  self.rosterColumns = ui.rosterColumns
  self:UpdateColumnOffsets()

  local tableInset = frame.Inset
  if not tableInset then
    tableInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
  end
  tableInset:ClearAllPoints()
  tableInset:SetPoint("TOPLEFT", ui.headerArea, "BOTTOMLEFT", 0, -6)
  tableInset:SetPoint("BOTTOMRIGHT", ui.bottomBar, "TOPRIGHT", 0, 6)

  local headerRow = CreateFrame("Frame", nil, tableInset)
  headerRow:SetHeight(ROSTER_HEADER_HEIGHT)
  headerRow:SetPoint("TOPLEFT", tableInset, "TOPLEFT", 6, -6)
  headerRow:SetPoint("TOPRIGHT", tableInset, "TOPRIGHT", -24, -6)

  local scrollBox = CreateFrame("Frame", nil, tableInset, "WowScrollBoxList")
  scrollBox:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
  scrollBox:SetPoint("BOTTOMRIGHT", tableInset, "BOTTOMRIGHT", -24, 6)

  local scrollBar = CreateFrame("EventFrame", nil, tableInset, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", headerRow, "TOPRIGHT", 4, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

  local view = CreateScrollBoxListLinearView()
  view:SetElementInitializer("GLDRosterRowTemplate", function(row, elementData)
    self:InitializeRosterRow(row)
    self:PopulateRosterRow(row, elementData)
  end)
  if view.SetElementResetter then
    view:SetElementResetter(function(row)
      if not row then
        return
      end
      row.data = nil
      row.rosterKey = nil
      row.canRemoveHoverHighlight = false
      if row.SetRemoveHoverHighlighted then
        row:SetRemoveHoverHighlighted(false)
      end
    end)
  end
  view:SetElementExtent(ROSTER_ROW_HEIGHT)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

  ui.headerRow = headerRow
  ui.scrollBox = scrollBox
  ui.scrollBar = scrollBar
  self:CreateHeaderButtons(headerRow)

  return tableInset, headerRow, scrollBox, scrollBar
end

function GLD:CreateBottomBar(frame)
  local ui = self.UI
  local bar = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
  bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
  bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
  bar:SetHeight(ROSTER_BOTTOM_BAR_HEIGHT)

  local showOffline = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
  showOffline:SetPoint("LEFT", bar, "LEFT", 8, 9)
  showOffline:SetChecked(ui.showOffline)
  SetCheckLabel(showOffline, "Show Offline")
  showOffline:SetScript("OnClick", function(btn)
    ui.showOffline = btn:GetChecked()
    self:RefreshTable()
  end)

  local showGuests = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
  showGuests:SetPoint("LEFT", showOffline, "RIGHT", 120, 0)
  showGuests:SetChecked(ui.showGuests)
  SetCheckLabel(showGuests, "Show Guests")
  showGuests:SetScript("OnClick", function(btn)
    ui.showGuests = btn:GetChecked()
    self:RefreshTable()
  end)

  local rowSlider = CreateFrame("Slider", nil, bar, "OptionsSliderTemplate")
  rowSlider:SetWidth(160)
  rowSlider:SetPoint("CENTER", bar, "CENTER", 0, 9)
  rowSlider:SetMinMaxValues(12, 30)
  rowSlider:SetValueStep(1)
  rowSlider:SetObeyStepOnDrag(true)
  rowSlider:SetValue(ui.visibleRows or 18)
  if rowSlider.Text then
    rowSlider.Text:SetText("Rows")
  end
  if rowSlider.Low then
    rowSlider.Low:SetText("12")
  end
  if rowSlider.High then
    rowSlider.High:SetText("30")
  end
  rowSlider:SetScript("OnValueChanged", function(_, value)
    ui.visibleRows = math.floor(value + 0.5)
    -- Integration point: adjust frame height or visible rows if you want this slider to resize the list.
  end)
  ui.rowSlider = rowSlider

  local rowCountText = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rowCountText:SetPoint("LEFT", rowSlider, "RIGHT", 8, 0)
  rowCountText:SetText("")
  ui.rowCountText = rowCountText

  local guestModeLabel = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  guestModeLabel:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -10, -8)
  guestModeLabel:SetText("Guest mode: View + Request only")
  guestModeLabel:SetTextColor(1, 0.82, 0.1)
  guestModeLabel:Hide()
  ui.guestModeLabel = guestModeLabel

  local function RequireAdminAccess(action)
    if self.CanAccessAdminUI and self:CanAccessAdminUI() then
      action()
    else
      self:ShowPermissionDeniedPopup()
    end
  end

  local function RequireAuthorityAccess(action, requestAction)
    if self.CanMutateState and self:CanMutateState() then
      action()
      return
    end
    if requestAction and self.RequestAdminAction and self:RequestAdminAction(requestAction) then
      return
    end
    self:ShowPermissionDeniedPopup()
  end

  local buttonSpacing = 6
  local buttonRowOffset = 5
  local buttonRow = CreateFrame("Frame", nil, bar)
  buttonRow:SetHeight(20)
  buttonRow:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 8, buttonRowOffset)
  buttonRow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -8, buttonRowOffset)

  local function CreateActionButton(label, width, onClick)
    local button = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
  end

  local buttons = {}
  buttons[#buttons + 1] = CreateActionButton("History", 80, function()
    RequireAdminAccess(function()
      if ui.ToggleHistory then
        ui:ToggleHistory()
      end
    end)
  end)
  buttons[#buttons].requiresAuthority = false
  buttons[#buttons].hideWhenNoAuthority = false
  buttons[#buttons + 1] = CreateActionButton("Admin", 70, function()
    RequireAdminAccess(function()
      if ui.OpenAdmin then
        ui:OpenAdmin()
      end
    end)
  end)
  buttons[#buttons].requiresAuthority = false
  buttons[#buttons].hideWhenNoAuthority = false
  buttons[#buttons + 1] = CreateActionButton("End Session", 100, function()
    RequireAuthorityAccess(function()
      if self.PromptEndSession then
        self:PromptEndSession()
      elseif self.EndSession then
        self:EndSession()
      end
      ui:RefreshMain()
    end, "END_SESSION")
  end)
  buttons[#buttons].requiresAuthority = false
  buttons[#buttons].hideWhenNoAuthority = false
  ui.endSessionBtn = buttons[#buttons]
  buttons[#buttons + 1] = CreateActionButton("Start Session", 100, function()
    RequireAuthorityAccess(function()
      if self.PromptStartSession then
        self:PromptStartSession()
      elseif self.StartSession then
        self:StartSession()
      end
      ui:RefreshMain()
    end, "START_SESSION")
  end)
  buttons[#buttons].requiresAuthority = false
  buttons[#buttons].hideWhenNoAuthority = false
  ui.startSessionBtn = buttons[#buttons]
  buttons[#buttons + 1] = CreateActionButton("Pugs: OFF", 90, function()
    RequireAdminAccess(function()
      local nextValue = not (self.GetPugsInRaid and self:GetPugsInRaid())
      if self.RequestSetPugsInRaid then
        self:RequestSetPugsInRaid(nextValue)
      elseif self.SetPugsInRaid then
        self:SetPugsInRaid(nextValue)
      end
      ui:RefreshMain()
    end)
  end)
  buttons[#buttons].requiresAuthority = false
  buttons[#buttons].hideWhenNoAuthority = false
  ui.pugsModeBtn = buttons[#buttons]
  buttons[#buttons + 1] = CreateActionButton("Guest Anchors", 110, function()
    if self.CanAccessAdminUI and self:CanAccessAdminUI() then
      ui.guestAnchorsVisible = not ui.guestAnchorsVisible
      ui:RefreshMain()
      return
    end
    self:ShowPermissionDeniedPopup()
  end)
  buttons[#buttons].requiresAuthority = false
  buttons[#buttons].hideWhenNoAuthority = false

  local previous = nil
  for _, button in ipairs(buttons) do
    if not previous then
      button:SetPoint("LEFT", buttonRow, "LEFT", 0, 0)
    else
      button:SetPoint("LEFT", previous, "RIGHT", buttonSpacing, 0)
    end
    previous = button
  end

  ui.adminButtons = { buttons[1], buttons[2], buttons[3], buttons[4], buttons[5], buttons[6] }
  ui.toggleGuestsBtn = buttons[6]

  return bar
end

function GLD:CreateGuestPanel(frame)
  local ui = self.UI
  local panel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
  panel:SetHeight(ROSTER_GUEST_PANEL_HEIGHT)
  panel:SetPoint("BOTTOMLEFT", ui.bottomBar, "TOPLEFT", 0, 6)
  panel:SetPoint("BOTTOMRIGHT", ui.bottomBar, "TOPRIGHT", 0, 6)

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
  title:SetText("Guest Anchors (Pending Approval)")
  panel.title = title

  local scrollFrame = CreateFrame("ScrollFrame", "GuestAnchorsScrollFrame", panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -22)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 6)
  local scrollChild = CreateFrame("Frame", "GuestAnchorsScrollChild", scrollFrame)
  scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
  scrollChild:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 0)
  scrollChild:SetHeight(1)
  scrollFrame:SetScrollChild(scrollChild)
  if DEBUG_GUEST_ANCHORS then
    local containerBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    containerBg:SetAllPoints(scrollFrame)
    containerBg:SetColorTexture(0, 1, 0, 0.1)
    panel.debugContainerBg = containerBg
  end
  panel.scrollFrame = scrollFrame
  panel.scrollChild = scrollChild
  panel.guestAnchorsScrollChild = scrollChild
  panel.rows = {}
  panel.pendingApprovalsByKey = {}

  return panel
end

function GLD:UpdateGuestPanelLayout()
  local ui = self.UI
  if not ui or not ui.mainFrame or not ui.tableInset or not ui.bottomBar or not ui.guestPanel or not ui.headerArea then
    return
  end

  if ui.guestAnchorsVisible then
    ui.guestPanel:Show()
  else
    ui.guestPanel:Hide()
  end

  ui.tableInset:ClearAllPoints()
  ui.tableInset:SetPoint("TOPLEFT", ui.headerArea, "BOTTOMLEFT", 0, -6)
  if ui.guestAnchorsVisible then
    ui.tableInset:SetPoint("BOTTOMRIGHT", ui.guestPanel, "TOPRIGHT", 0, 6)
  else
    ui.tableInset:SetPoint("BOTTOMRIGHT", ui.bottomBar, "TOPRIGHT", 0, 6)
  end
end

function GLD:UpdateBottomBarPermissions()
  local ui = self.UI
  if not ui or not ui.adminButtons then
    return
  end
  local canAccessAdmin = self.CanAccessAdminUI and self:CanAccessAdminUI() or false
  local canMutate = self.CanMutateState and self:CanMutateState() or false
  for _, button in ipairs(ui.adminButtons) do
    if button then
      local show = canAccessAdmin
      if show and button.hideWhenNoAuthority then
        show = canMutate
      end
      if button.SetShown then
        button:SetShown(show)
      elseif show then
        button:Show()
      else
        button:Hide()
      end
      if button.SetEnabled then
        local allow = canAccessAdmin
        if button.requiresAuthority then
          allow = canMutate
        end
        button:SetEnabled(allow)
      end
    end
  end
  if ui.toggleGuestsBtn and ui.toggleGuestsBtn.SetEnabled then
    ui.toggleGuestsBtn:SetEnabled(canAccessAdmin)
  end
  if ui.pugsModeBtn then
    local enabled = self.GetPugsInRaid and self:GetPugsInRaid()
    ui.pugsModeBtn:SetText(enabled and "Pugs: ON" or "Pugs: OFF")
    if ui.pugsModeBtn.SetEnabled then
      ui.pugsModeBtn:SetEnabled(canAccessAdmin)
    end
  end
  local sessionActive = self.IsSessionActiveLocal and self:IsSessionActiveLocal()
  if sessionActive == nil then
    sessionActive = self.IsSessionActive and self:IsSessionActive() or false
  end
  if ui.startSessionBtn and ui.startSessionBtn.SetEnabled then
    ui.startSessionBtn:SetEnabled(canAccessAdmin and not sessionActive)
  end
  if ui.endSessionBtn and ui.endSessionBtn.SetEnabled then
    ui.endSessionBtn:SetEnabled(canAccessAdmin and sessionActive)
  end
  if not canAccessAdmin and ui.guestAnchorsVisible then
    ui.guestAnchorsVisible = false
    if self.UpdateGuestPanelLayout then
      self:UpdateGuestPanelLayout()
    end
  end
  if ui.guestModeLabel then
    if self.IsGuest and self:IsGuest("player") then
      ui.guestModeLabel:Show()
    else
      ui.guestModeLabel:Hide()
    end
  end
end

function GLD:UpdateRosterStatusText()
  local ui = self.UI
  if not ui or not ui.statusText then
    return
  end
  local text = nil
  if self.GetRosterStatusText then
    text = self:GetRosterStatusText()
  end
  if not text or text == "" then
    text = self:GetDefaultRosterStatusText()
  end
  ui.statusText:SetText(text or "")
end

function GLD:UpdateSessionStateIndicator()
  local ui = self.UI
  if not ui or not ui.sessionStateDot then
    return
  end
  local isActive = nil
  if self.IsAuthority and self:IsAuthority() then
    isActive = self.db and self.db.session and self.db.session.active == true
  elseif self.shadow and self.shadow.sessionActive ~= nil then
    isActive = self.shadow.sessionActive == true
  else
    isActive = self.db and self.db.session and self.db.session.active == true
  end
  if isActive then
    ui.sessionStateDot:SetTexture("Interface\\COMMON\\Indicator-Green")
  else
    ui.sessionStateDot:SetTexture("Interface\\COMMON\\Indicator-Red")
  end
end

function GLD:IsRosterEditEnabled()
  return self.editRosterEnabled == true and self.CanMutateState and self:CanMutateState()
end

function GLD:SetRosterEditEnabled(enabled)
  self.editRosterEnabled = enabled and true or false
  if self.UI then
    self.UI.editRosterEnabled = self.editRosterEnabled
  end
  if self.UpdateRosterEditState then
    self:UpdateRosterEditState()
  end
end

function GLD:UpdateRosterEditState()
  local ui = self.UI
  if not ui or not ui.headerButtons then
    return
  end
  -- Placeholder for any edit-only header tweaks.
  -- Keep this method to hook in refreshes when Edit Roster is toggled.
end

function GLD:GetDefaultRosterStatusText()
  local myPos = "--"
  local roster = self.GetRosterSource and self:GetRosterSource() or (self.db and self.db.players) or nil
  local entry = self.GetLocalRosterEntry and roster and self:GetLocalRosterEntry(roster) or nil
  if entry and entry.queuePos then
    myPos = tostring(entry.queuePos)
  end
  local pugsMode = self.GetPugsInRaid and self:GetPugsInRaid()
  local pugsText = pugsMode and "ON" or "OFF"
  return "My Position: " .. myPos .. "   |   Pugs in raid: " .. pugsText
end

function GLD:CreateHeaderButtons(headerRow)
  local ui = self.UI
  ui.headerButtons = {}
  ui.headerButtonByKey = {}
  for index, col in ipairs(self.rosterColumns or {}) do
    local button = CreateFrame("Button", nil, headerRow, "BackdropTemplate")
    button:SetSize(col.width, ROSTER_HEADER_HEIGHT)
    button:SetPoint("LEFT", headerRow, "LEFT", col.x, 0)
    button:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    button:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText(col.label)
    button.text = text

    button.sortKey = col.sortKey
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    arrow:SetSize(10, 10)
    arrow:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    arrow:Hide()
    button.sortArrow = arrow

    if col.sortKey then
      button:SetScript("OnClick", function()
        self:ToggleSort(col.sortKey)
      end)
    end

    ui.headerButtons[index] = button
    if col.key then
      ui.headerButtonByKey[col.key] = button
    end
  end
end

function GLD:UpdateColumnOffsets()
  local x = 4
  for _, col in ipairs(self.rosterColumns or {}) do
    col.x = x
    x = x + col.width + ROSTER_COLUMN_PADDING
  end
end

function GLD:ToggleSort(sortKey)
  local ui = self.UI
  if ui.sortKey == sortKey then
    ui.sortAscending = not ui.sortAscending
  else
    ui.sortKey = sortKey
    ui.sortAscending = true
  end
  self:UpdateHeaderSortIndicators()
  self:RefreshTable()
end

function GLD:UpdateHeaderSortIndicators()
  local ui = self.UI
  if not ui or not ui.headerButtons then
    return
  end
  for _, button in ipairs(ui.headerButtons) do
    if button.sortKey and button.sortKey == ui.sortKey then
      if button.sortArrow then
        button.sortArrow:Show()
        if ui.sortAscending then
          button.sortArrow:SetTexCoord(0, 1, 0, 1)
        else
          button.sortArrow:SetTexCoord(0, 1, 1, 0)
        end
      end
      if button.text then
        button.text:SetTextColor(1, 0.9, 0.6)
      end
    else
      if button.sortArrow then
        button.sortArrow:Hide()
      end
      if button.text then
        button.text:SetTextColor(1, 1, 1)
      end
    end
  end
end

function GLD:GetRosterSource()
  if self:IsAuthority() then
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      if self._lastRosterSourceLabel ~= "db.players" then
        self._lastRosterSourceLabel = "db.players"
        self:Debug("Roster source: db.players (authority)")
      end
    end
    return (self.db and self.db.players) or {}
  end
  local roster = self.shadow and self.shadow.roster or nil
  if type(roster) == "table" then
    local rosterReady = (self.shadow and self.shadow.rosterReceived) or (self.shadow and (self.shadow.lastSyncAt or 0) > 0)
    if rosterReady or next(roster) ~= nil then
      if self.IsDebugEnabled and self:IsDebugEnabled() then
        if self._lastRosterSourceLabel ~= "shadow.roster" then
          self._lastRosterSourceLabel = "shadow.roster"
          self:Debug("Roster source: shadow.roster")
        end
      end
      return roster
    end
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    if self._lastRosterSourceLabel ~= "db.players_fallback" then
      self._lastRosterSourceLabel = "db.players_fallback"
      self:Debug("Roster source: db.players (fallback)")
    end
  end
  return (self.db and self.db.players) or {}
end

function GLD:GetRosterMembers()
  -- Integration point: return your current roster list (array or keyed table).
  local members = self.GetRosterSource and self:GetRosterSource() or {}

  local list = {}
  if type(members) == "table" and #members > 0 then
    for _, member in ipairs(members) do
      if type(member) == "table" and member.member then
        list[#list + 1] = member
      else
        list[#list + 1] = { member = member, key = member and (member.key or member.playerKey) or nil }
      end
    end
  else
    for key, member in pairs(members) do
      if type(member) == "table" and member.member then
        if not member.key then
          member.key = key
        end
        list[#list + 1] = member
      else
        list[#list + 1] = { member = member, key = key }
      end
    end
  end
  return list
end

function GLD:GetMemberName(member)
  if not member then
    return "?"
  end
  local name = member.name or member.fullName or member.displayName
  if name and name ~= "" then
    if type(name) == "string" then
      return (strsplit("-", name))
    end
    return name
  end
  return tostring(member)
end

function GLD:IsGuestMember(member)
  if self.IsGuest then
    return self:IsGuest(member)
  end
  if member and member.isGuest ~= nil then
    return member.isGuest
  end
  return member and member.source == "guest"
end

function GLD:IsMemberOffline(rowData)
  if rowData and rowData.member and rowData.member.online ~= nil then
    return not rowData.member.online
  end
  local status = (rowData and rowData.attendanceStatus or ""):upper()
  if status == "" then
    return false
  end
  return status ~= "PRESENT"
end

function GLD:GetMemberNoteText(member)
  -- Integration point: return the note text you want to filter on for note search.
  return member and (member.note or member.publicNote or member.officerNote) or nil
end

function GLD:GetAttendanceSortValue(status)
  local key = (status or ""):upper()
  if key == "PRESENT" then
    return 1
  end
  if key == "PARTIAL" then
    return 2
  end
  if key == "ABSENT" or key == "OFFLINE" then
    return 3
  end
  return 4
end

function GLD:GetAttendanceTextColor(status, override)
  if type(override) == "table" then
    local r = override.r or override[1]
    local g = override.g or override[2]
    local b = override.b or override[3]
    if r and g and b then
      return r, g, b
    end
  end

  local key = (status or ""):upper()
  if key == "PRESENT" then
    return 0.55, 0.9, 0.55
  end
  if key == "ABSENT" or key == "OFFLINE" then
    return 0.9, 0.45, 0.45
  end
  if key == "PARTIAL" then
    return 0.9, 0.75, 0.4
  end
  return 0.8, 0.8, 0.8
end

function GLD:BuildRosterRowData(entry)
  -- Integration point: wire your existing helper functions here.
  local member = entry
  local playerKey = nil
  if type(entry) == "table" and entry.member then
    member = entry.member
    playerKey = entry.key
  end
  if not playerKey and type(entry) == "table" then
    playerKey = entry.rosterKey or entry.playerKey or entry.key
  end
  local rawName = self:GetMemberName(member)
  local isGuest = self:IsGuestMember(member)
  local baseName = NS:GetPlayerBaseName(rawName) or rawName or "?"
  local displayName = NS:GetPlayerDisplayName(baseName, isGuest)
  local classFile = member and (member.classFile or member.classFileName or member.class)
  local nameColor = nil
  if classFile then
    local r, g, b = NS:GetClassColor(classFile)
    nameColor = { r = r, g = g, b = b }
  end

  local role = self.GetRole and self:GetRole(member) or (member and member.role)
  local queuePos = self.GetQueuePos and self:GetQueuePos(member) or (member and member.queuePos)
  local heldPos = self.GetHeldPos and self:GetHeldPos(member) or (member and (member.heldPos or member.savedPos))
  local itemsWon = self.GetItemsWon and self:GetItemsWon(member) or (member and (member.itemsWon or member.numAccepted))
  local raidsAttended = self.GetRaidsAttended and self:GetRaidsAttended(member) or (member and (member.raidsAttended or member.attendanceCount))

  local attendanceStatus, attendanceColor = nil, nil
  if self.GetAttendanceStatus then
    attendanceStatus, attendanceColor = self:GetAttendanceStatus(member)
  end
  attendanceStatus = attendanceStatus or (member and member.attendance) or ""
  local r, g, b = self:GetAttendanceTextColor(attendanceStatus, attendanceColor)

  local classTexture, classCoords = nil, nil
  if self.GetClassIconInfo then
    local tex, left, right, top, bottom = self:GetClassIconInfo(member)
    classTexture = tex
    if type(left) == "table" then
      classCoords = left
    elseif left and right and top and bottom then
      classCoords = { left, right, top, bottom }
    end
    if classTexture and not classCoords and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classTexture] then
      classCoords = CLASS_ICON_TCOORDS[classTexture]
      classTexture = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
    end
  end
  if not classTexture then
    if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
      classTexture = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
      classCoords = CLASS_ICON_TCOORDS[classFile]
    end
  end

  local specIcon = self.GetSpecIcon and self:GetSpecIcon(member) or (member and member.specIcon)

  if not playerKey and baseName and self.FindPlayerKeyByName then
    playerKey = self:FindPlayerKeyByName(baseName, member and member.realm)
  end
  if not playerKey and member then
    local entryName = member.fullName or member.name or rawName
    local entryRealm = member.realm
    if entryName and not entryRealm and NS.SplitNameRealm then
      local base, realm = NS:SplitNameRealm(entryName)
      if base then
        entryName = base
        entryRealm = realm
      end
    end
    if entryName and entryRealm and entryRealm ~= "" then
      playerKey = entryName .. "-" .. entryRealm
    elseif entryName and entryName ~= "" then
      playerKey = entryName
    end
  end

  return {
    member = member,
    playerKey = playerKey,
    rosterKey = playerKey,
    name = baseName,
    nameLower = (baseName or ""):lower(),
    displayName = displayName,
    isGuest = isGuest,
    nameColor = nameColor,
    role = role or "",
    queuePos = queuePos,
    heldPos = heldPos,
    itemsWon = itemsWon,
    raidsAttended = raidsAttended,
    attendanceStatus = attendanceStatus,
    attendanceColor = { r = r, g = g, b = b },
    classTexture = classTexture,
    classCoords = classCoords,
    specIcon = specIcon,
    sort = {
      name = (name or ""):lower(),
      queuePos = tonumber(queuePos),
      heldPos = tonumber(heldPos),
      itemsWon = tonumber(itemsWon),
      raidsAttended = tonumber(raidsAttended),
      attendance = self:GetAttendanceSortValue(attendanceStatus),
    },
  }
end

function GLD:InitializeRosterRow(row)
  if row.isInitialized then
    return
  end
  row:SetHeight(ROSTER_ROW_HEIGHT)
  if self.UI and self.UI.headerRow then
    row:SetWidth(self.UI.headerRow:GetWidth())
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
  row.editBoxes = {}

  for _, col in ipairs(self.rosterColumns or {}) do
    if col.isIcon then
      local tex = row:CreateTexture(nil, "ARTWORK")
      tex:SetSize(ROSTER_ICON_SIZE, ROSTER_ICON_SIZE)
      tex:SetPoint("LEFT", row, "LEFT", col.x + (col.width - ROSTER_ICON_SIZE) * 0.5, 0)
      row.cells[col.key] = tex
    elseif col.key == "remove" then
      local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      button:SetSize(col.width, ROSTER_ROW_HEIGHT - 2)
      button:SetPoint("LEFT", row, "LEFT", col.x, 0)
      button:SetText("Remove")
      row.cells[col.key] = button
    else
      local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      fs:SetWidth(col.width)
      fs:SetJustifyH(col.align or "LEFT")
      fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
      row.cells[col.key] = fs

      if col.key == "queuePos" or col.key == "heldPos" or col.key == "itemsWon" or col.key == "raidsAttended" or col.key == "attendance" then
        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(col.width - 6, ROSTER_ROW_HEIGHT - 2)
        box:SetPoint("LEFT", row, "LEFT", col.x + 3, 0)
        box:SetAutoFocus(false)
        box:SetJustifyH("CENTER")
        if col.key ~= "attendance" and box.SetNumeric then
          box:SetNumeric(true)
        end
        box:SetScript("OnEscapePressed", function(edit)
          edit:ClearFocus()
        end)
        row.editBoxes[col.key] = box
        if col.key == "queuePos" then
          row.queuePosBox = box
        elseif col.key == "heldPos" then
          row.heldPosBox = box
        elseif col.key == "itemsWon" then
          row.itemsWonBox = box
        elseif col.key == "raidsAttended" then
          row.raidsBox = box
        elseif col.key == "attendance" then
          row.attendanceBox = box
        end
      end
    end
  end

  local function canEditRow(data)
    if not self:IsRosterEditEnabled() then
      return false
    end
    if not data or data.isGuest then
      return false
    end
    if not data.playerKey or not self.db or not self.db.players or not self.db.players[data.playerKey] then
      return false
    end
    return true
  end

  if row.cells.remove then
    row.cells.remove:SetScript("OnClick", function()
      local data = row.data
      local actor = self:GetUnitFullName("player") or UnitName("player") or "Unknown"
      local target = data and (data.displayName or data.name or "?") or "?"
      local rosterKey = row.rosterKey or (data and data.rosterKey) or (data and data.playerKey) or nil
      local isGuest = data and data.isGuest or false
      local attendance = data and data.attendanceStatus or nil
      local presentFlag = nil
      if attendance ~= nil then
        local attKey = tostring(attendance):upper()
        if attKey == "PRESENT" then
          presentFlag = true
        elseif attKey == "ABSENT" or attKey == "OFFLINE" then
          presentFlag = false
        end
      end
      local reason = nil
      local ok = false
      if self.IsDebugEnabled and self:IsDebugEnabled() then
        self:Debug(
          "Roster remove click: actor="
            .. tostring(actor)
            .. " target="
            .. tostring(target)
            .. " key="
            .. tostring(rosterKey)
            .. " isGuest="
            .. tostring(isGuest)
            .. " attendance="
            .. tostring(attendance)
            .. " present="
            .. tostring(presentFlag)
        )
      end
      if not self:IsRosterEditEnabled() then
        reason = "edit_roster_off"
      elseif not rosterKey then
        reason = "missing_player_key"
      elseif not self.db or not self.db.players or not self.db.players[rosterKey] then
        reason = "missing_player"
      else
        local player = self.db.players[rosterKey]
        if self.IsGuestMember then
          isGuest = self:IsGuestMember(player)
        end
        local classFile = player and (player.classFile or player.classFileName or player.class)
        local specName = player and (player.specName or player.spec)
        local targetName = player and player.name or data.name
        if self.RemoveRosterMember then
          ok, reason = self:RemoveRosterMember(rosterKey)
        else
          reason = "remove_handler_missing"
        end
        if ok then
          if self.LogAuditEvent then
            self:LogAuditEvent("REMOVE_MEMBER", {
              actor = actor,
              target = targetName,
              isGuest = isGuest,
              class = classFile,
              spec = specName,
              rosterKey = rosterKey,
            })
          end
          if not self.OnRosterChanged then
            if self.BroadcastSnapshot then
              self:BroadcastSnapshot(true)
              if self.IsDebugEnabled and self:IsDebugEnabled() then
                self:Debug("Roster remove broadcast: key=" .. tostring(rosterKey))
              end
            end
            if self.UI and self.UI.RefreshMain then
              self.UI:RefreshMain()
            end
          end
        else
          reason = reason or "remove_failed"
        end
      end
      if self.IsDebugEnabled and self:IsDebugEnabled() then
        local outcome = ok and "ok" or (reason or "failed")
        self:Debug(
          "Roster remove result: actor="
            .. tostring(actor)
            .. " target="
            .. tostring(target)
            .. " key="
            .. tostring(rosterKey)
            .. " isGuest="
            .. tostring(isGuest)
            .. " result="
            .. tostring(outcome)
        )
        if not ok and (reason == "missing_player_key" or reason == "missing_player") and self.GetRosterSource then
          local roster = self:GetRosterSource()
          local sample = {}
          if type(roster) == "table" then
            for k in pairs(roster) do
              sample[#sample + 1] = tostring(k)
              if #sample >= 8 then
                break
              end
            end
          end
          if #sample > 0 then
            self:Debug("Roster remove lookup sample keys: " .. table.concat(sample, ", "))
          end
        end
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

  if row.queuePosBox then
    row.queuePosBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not canEditRow(data) then
        box:ClearFocus()
        return
      end
      local pos = ParseNonNegativeInt(box:GetText())
      if pos ~= nil then
        local player = self.db.players[data.playerKey]
        if player.attendance == "ABSENT" then
          player.savedPos = pos
          player.queuePos = nil
        else
          if self.RemoveFromQueue then
            self:RemoveFromQueue(data.playerKey)
          end
          if self.InsertToQueue then
            self:InsertToQueue(data.playerKey, pos)
          else
            player.queuePos = pos
          end
        end
      end
      if pos ~= nil and self.OnRosterChanged then
        self:OnRosterChanged("edit_queue_pos")
      else
        self:RefreshTable()
        self:UpdateRosterStatusText()
      end
      box:ClearFocus()
    end)
  end

  if row.heldPosBox then
    row.heldPosBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not canEditRow(data) then
        box:ClearFocus()
        return
      end
      local pos = ParseNonNegativeInt(box:GetText())
      if pos ~= nil then
        self.db.players[data.playerKey].savedPos = pos
      end
      if pos ~= nil and self.OnRosterChanged then
        self:OnRosterChanged("edit_held_pos")
      else
        self:RefreshTable()
      end
      box:ClearFocus()
    end)
  end

  if row.itemsWonBox then
    row.itemsWonBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not canEditRow(data) then
        box:ClearFocus()
        return
      end
      local num = ParseNonNegativeInt(box:GetText())
      if num ~= nil then
        self.db.players[data.playerKey].numAccepted = num
      end
      if num ~= nil and self.OnRosterChanged then
        self:OnRosterChanged("edit_items_won")
      else
        self:RefreshTable()
      end
      box:ClearFocus()
    end)
  end

  if row.raidsBox then
    row.raidsBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not canEditRow(data) then
        box:ClearFocus()
        return
      end
      local num = ParseNonNegativeInt(box:GetText())
      if num ~= nil then
        self.db.players[data.playerKey].attendanceCount = num
      end
      if num ~= nil and self.OnRosterChanged then
        self:OnRosterChanged("edit_raids_attended")
      else
        self:RefreshTable()
      end
      box:ClearFocus()
    end)
  end

  if row.attendanceBox then
    row.attendanceBox:SetScript("OnEnterPressed", function(box)
      local data = row.data
      if not canEditRow(data) then
        box:ClearFocus()
        return
      end
      local status = NormalizeAttendanceInput(box:GetText())
      if status then
        local player = self.db.players[data.playerKey]
        if status == "PRESENT" or status == "ABSENT" then
          if self.SetAttendance then
            self:SetAttendance(data.playerKey, status)
          else
            player.attendance = status
          end
        elseif status == "OFFLINE" then
          if self.SetAttendance then
            self:SetAttendance(data.playerKey, "ABSENT")
          else
            player.attendance = "ABSENT"
          end
          player.attendance = "OFFLINE"
        else
          player.attendance = status
        end
      end
      if status and self.OnRosterChanged then
        self:OnRosterChanged("edit_attendance")
      else
        self:RefreshTable()
      end
      box:ClearFocus()
    end)
  end

  row.isInitialized = true
end

function GLD:PopulateRosterRow(row, data)
  if not data or not row.cells then
    return
  end
  if row.SetRemoveHoverHighlighted then
    row:SetRemoveHoverHighlighted(false)
  end
  row.canRemoveHoverHighlight = false
  row.data = data
  row.rosterKey = data.rosterKey or data.playerKey
  local cells = row.cells

  local classIcon = cells.class
  if classIcon then
    if data.classTexture then
      classIcon:SetTexture(data.classTexture)
      if data.classCoords then
        classIcon:SetTexCoord(data.classCoords[1], data.classCoords[2], data.classCoords[3], data.classCoords[4])
      else
        classIcon:SetTexCoord(0, 1, 0, 1)
      end
      classIcon:Show()
    else
      classIcon:Hide()
    end
  end

  local specIcon = cells.spec
  if specIcon then
    if data.specIcon then
      specIcon:SetTexture(data.specIcon)
      specIcon:SetTexCoord(0, 1, 0, 1)
      specIcon:Show()
    else
      specIcon:Hide()
    end
  end

  if cells.role then
    cells.role:SetText(data.role or "")
  end
  if cells.name then
    cells.name:SetText(data.displayName or data.name or "")
    if data.nameColor then
      cells.name:SetTextColor(data.nameColor.r, data.nameColor.g, data.nameColor.b)
    else
      cells.name:SetTextColor(1, 1, 1)
    end
  end
  if cells.queuePos then
    cells.queuePos:SetText(data.queuePos or "-")
  end
  if cells.heldPos then
    cells.heldPos:SetText(data.heldPos or "-")
  end
  if cells.itemsWon then
    cells.itemsWon:SetText(data.itemsWon or "-")
  end
  if cells.raidsAttended then
    cells.raidsAttended:SetText(data.raidsAttended or "-")
  end
  if cells.attendance then
    cells.attendance:SetText(data.attendanceStatus or "")
    if data.attendanceColor then
      cells.attendance:SetTextColor(data.attendanceColor.r, data.attendanceColor.g, data.attendanceColor.b)
    else
      cells.attendance:SetTextColor(0.8, 0.8, 0.8)
    end
  end

  local editEnabled = self:IsRosterEditEnabled()
  local canEdit = editEnabled and not data.isGuest and data.playerKey and self.db and self.db.players and self.db.players[data.playerKey]

  if row.queuePosBox then
    if canEdit then
      row.queuePosBox:Show()
      row.queuePosBox:SetText(tostring(data.queuePos or ""))
      SetEditBoxEnabled(row.queuePosBox, true)
      if cells.queuePos then
        cells.queuePos:Hide()
      end
    else
      row.queuePosBox:Hide()
      if cells.queuePos then
        cells.queuePos:Show()
      end
    end
  end
  if row.heldPosBox then
    if canEdit then
      row.heldPosBox:Show()
      row.heldPosBox:SetText(tostring(data.heldPos or ""))
      SetEditBoxEnabled(row.heldPosBox, true)
      if cells.heldPos then
        cells.heldPos:Hide()
      end
    else
      row.heldPosBox:Hide()
      if cells.heldPos then
        cells.heldPos:Show()
      end
    end
  end
  if row.itemsWonBox then
    if canEdit then
      row.itemsWonBox:Show()
      row.itemsWonBox:SetText(tostring(data.itemsWon or 0))
      SetEditBoxEnabled(row.itemsWonBox, true)
      if cells.itemsWon then
        cells.itemsWon:Hide()
      end
    else
      row.itemsWonBox:Hide()
      if cells.itemsWon then
        cells.itemsWon:Show()
      end
    end
  end
  if row.raidsBox then
    if canEdit then
      row.raidsBox:Show()
      row.raidsBox:SetText(tostring(data.raidsAttended or 0))
      SetEditBoxEnabled(row.raidsBox, true)
      if cells.raidsAttended then
        cells.raidsAttended:Hide()
      end
    else
      row.raidsBox:Hide()
      if cells.raidsAttended then
        cells.raidsAttended:Show()
      end
    end
  end
  if row.attendanceBox then
    if canEdit then
      row.attendanceBox:Show()
      row.attendanceBox:SetText(tostring(data.attendanceStatus or ""))
      SetEditBoxEnabled(row.attendanceBox, true)
      if cells.attendance then
        cells.attendance:Hide()
      end
    else
      row.attendanceBox:Hide()
      if cells.attendance then
        cells.attendance:Show()
      end
    end
  end

  if cells.remove then
    if editEnabled then
      cells.remove:Show()
      local canRemove = data.playerKey and self.db and self.db.players and self.db.players[data.playerKey] ~= nil
      if cells.remove.SetEnabled then
        cells.remove:SetEnabled(canRemove == true)
      end
      row.canRemoveHoverHighlight = canRemove == true
    else
      cells.remove:Hide()
      row.canRemoveHoverHighlight = false
    end
  end
end

function GLD:PassRosterFilters(rowData)
  local ui = self.UI
  if not ui then
    return false
  end
  if not ui.showGuests and rowData.isGuest then
    return false
  end
  if not ui.showOffline and self:IsMemberOffline(rowData) then
    return false
  end
  local filterText = (ui.filterText or ""):lower()
  if filterText ~= "" then
    if not rowData.nameLower or not rowData.nameLower:find(filterText, 1, true) then
      return false
    end
  end
  local noteFilter = (ui.noteFilterText or ""):lower()
  if ui.enableNoteSearch and noteFilter ~= "" then
    local noteText = self:GetMemberNoteText(rowData.member)
    noteText = noteText and noteText:lower() or ""
    if noteText == "" or not noteText:find(noteFilter, 1, true) then
      return false
    end
  end
  return true
end

function GLD:SortRosterData(rows)
  local ui = self.UI
  if not ui or not ui.sortKey then
    return
  end
  local key = ui.sortKey
  local ascending = ui.sortAscending

  table.sort(rows, function(a, b)
    local aSort = a.sort and a.sort[key]
    local bSort = b.sort and b.sort[key]
    if aSort == bSort then
      return (a.sort and a.sort.name or "") < (b.sort and b.sort.name or "")
    end
    if aSort == nil then
      return not ascending
    end
    if bSort == nil then
      return ascending
    end
    if type(aSort) == "string" or type(bSort) == "string" then
      aSort = tostring(aSort)
      bSort = tostring(bSort)
    end
    if ascending then
      return aSort < bSort
    end
    return aSort > bSort
  end)
end

function GLD:RefreshTable()
  local ui = self.UI
  if not ui or not ui.scrollBox then
    return
  end

  local members = self:GetRosterMembers()
  local rows = {}
  for _, member in ipairs(members) do
    local rowData = self:BuildRosterRowData(member)
    if self:PassRosterFilters(rowData) then
      rows[#rows + 1] = rowData
    end
  end

  self:SortRosterData(rows)

  if CreateDataProvider then
    local dataProvider = CreateDataProvider()
    for _, rowData in ipairs(rows) do
      dataProvider:Insert(rowData)
    end
    ui.scrollBox:SetDataProvider(dataProvider, true)
  end

  if ui.rowCountText then
    ui.rowCountText:SetText(string.format("%d Rows", #rows))
  end
end

local function CreateGuestAnchorRow(panel)
  local parent = panel and (panel.guestAnchorsScrollChild or panel.scrollChild)
  local row = CreateFrame("Frame", nil, parent, "GLDGuestAnchorsRowTemplate")
  row:SetHeight(GUEST_ANCHOR_ROW_HEIGHT)
  if DEBUG_GUEST_ANCHORS then
    row.bg = row.bg or row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(1, 0, 0, 0.2)
    row.bg:Show()
  end

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  row.name:SetJustifyH("LEFT")

  row.addButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.addButton:SetSize(GUEST_ANCHOR_BUTTON_WIDTH, 18)
  row.addButton:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  row.addButton:SetText("Add to Raid Database")
  row.addButton:SetFrameLevel(row:GetFrameLevel() + 2)
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.addButton, "LEFT", -8, 0)
  row.name:SetJustifyH("LEFT")

  row.hoverTexture = row:CreateTexture(nil, "HIGHLIGHT")
  row.hoverTexture:SetAllPoints(row)
  row.hoverTexture:SetColorTexture(1, 1, 1, 0.06)
  row.hoverTexture:Hide()

  row:EnableMouse(true)
  row:SetScript("OnEnter", function(self)
    if self.hoverTexture then
      self.hoverTexture:Show()
    end
  end)
  row:SetScript("OnLeave", function(self)
    if self.hoverTexture then
      self.hoverTexture:Hide()
    end
  end)

  return row
end

function GLD:RefreshGuestAnchors(reason)
  local dbg = NS and NS.Debug or nil
  local refreshReason = tostring(reason or "unspecified")
  local ui = self.UI
  local panel = ui and ui.guestPanel
  local sessionEnabled = self.IsEnabled and self:IsEnabled() or false
  local sessionActive = self.IsSessionActiveLocal and self:IsSessionActiveLocal()
  if sessionActive == nil then
    sessionActive = self.IsSessionActive and self:IsSessionActive() or false
  end
  local pugsMode = self.GetPugsInRaid and self:GetPugsInRaid() or false
  local inCombat = InCombatLockdown and InCombatLockdown() or false
  local inRaid = IsInRaid and IsInRaid() or false
  local panelShown = panel and panel.IsShown and panel:IsShown() or false
  local panelVisible = panel and panel.IsVisible and panel:IsVisible() or false
  local panelName = GetFrameDebugName(panel)
  local scrollFrameName = GetFrameDebugName(panel and panel.scrollFrame)
  local scrollChildName = GetFrameDebugName(panel and panel.scrollChild)
  local rosterScrollBoxName = GetFrameDebugName(ui and ui.scrollBox)
  local guestScrollBoxName = GetFrameDebugName(panel and (panel.guestScrollBox or panel.scrollBox))

  if dbg and dbg.Throttle then
    dbg:Throttle(
      "ga_refresh_start",
      0.5,
      "GA_REFRESH",
      "reason=%s panelShown=%s inCombat=%s inRaid=%s sessionEnabled=%s sessionActive=%s pugsMode=%s",
      refreshReason,
      tostring(panelShown),
      tostring(inCombat),
      tostring(inRaid),
      tostring(sessionEnabled),
      tostring(sessionActive),
      tostring(pugsMode)
    )
    dbg:Throttle(
      "ga_refresh_target",
      0.5,
      "GuestAnchorsUI",
      "RefreshTarget reason=%s panel=%s panelShown=%s panelVisible=%s scrollFrame=%s scrollChild=%s guestScrollBox=%s rosterScrollBox=%s",
      refreshReason,
      panelName,
      tostring(panelShown),
      tostring(panelVisible),
      scrollFrameName,
      scrollChildName,
      guestScrollBoxName,
      rosterScrollBoxName
    )
  end
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "GuestAnchors refresh target: panel="
        .. tostring(panelName)
        .. " panelShown="
        .. tostring(panelShown)
        .. " panelVisible="
        .. tostring(panelVisible)
        .. " scrollFrame="
        .. tostring(scrollFrameName)
        .. " scrollChild="
        .. tostring(scrollChildName)
        .. " guestScrollBox="
        .. tostring(guestScrollBoxName)
        .. " rosterScrollBox="
        .. tostring(rosterScrollBoxName)
    )
  end
  if not panel then
    if dbg and dbg.Throttle then
      dbg:Throttle("ga_refresh_early_no_panel", 2.0, "GA_REFRESH", "earlyReturn reason=%s cause=no_panel", refreshReason)
    end
    return
  end
  if not panelShown then
    if dbg and dbg.Throttle then
      dbg:Throttle("ga_refresh_early_panel_hidden", 1.0, "GA_REFRESH", "earlyReturn reason=%s cause=panel_hidden", refreshReason)
    end
    return
  end

  local isAdminCharacter = self.IsAdminCharacter and self:IsAdminCharacter() or false
  panel.pendingApprovalsByKey = panel.pendingApprovalsByKey or {}
  local candidates = self.RebuildGuestAnchorCandidates and self:RebuildGuestAnchorCandidates() or {}
  local rebuildStats = self._guestAnchorRebuildStats or {}
  local providerStats = self._guestAnchorProviderStats or {}
  local realCount = tonumber(providerStats.realCount) or #candidates
  local simCount = tonumber(providerStats.simCount) or 0
  local providerCount = tonumber(providerStats.providerCount) or #candidates
  local simMode = tostring(providerStats.mode or "merge")
  panel.guestAnchorProviderCount = providerCount
  panel.guestAnchorRealCount = realCount
  panel.guestAnchorSimCount = simCount
  panel.guestAnchorSimMode = simMode
  if dbg and dbg.Throttle then
    dbg:Throttle("ga_refresh_candidates", 0.5, "GA_REFRESH", "reason=%s anchorListCount=%d", refreshReason, #candidates)
    dbg:Throttle(
      "ga_provider_set",
      0.5,
      "GuestAnchorsUI",
      "ProviderSet count=%d simCount=%d realCount=%d",
      providerCount,
      simCount,
      realCount
    )
  end
  if dbg and dbg.Force and refreshReason:find("SimGuest", 1, true) then
    dbg:Force("GuestAnchorsUI", "Refresh reason=%s count=%d", refreshReason, #candidates)
  end

  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "GuestAnchors refresh: candidatesFound="
        .. tostring(rebuildStats.candidatesFound or #candidates)
        .. " afterFiltering="
        .. tostring(rebuildStats.afterFiltering or #candidates)
        .. " rowsProvidedToUI="
        .. tostring(#candidates)
        .. " realCount="
        .. tostring(realCount)
        .. " simCount="
        .. tostring(simCount)
        .. " simMode="
        .. tostring(simMode)
        .. " sessionEnabled="
        .. tostring(sessionEnabled)
        .. " sessionActive="
        .. tostring(sessionActive)
        .. " pugsMode="
        .. tostring(pugsMode)
    )
  end

  if #candidates == 0 then
    panel.guestAnchorProviderCount = 0
    if not panel.emptyLabel then
      panel.emptyLabel = panel.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      panel.emptyLabel:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", GUEST_ANCHOR_ROW_SIDE_PADDING, -4)
    end
    panel.emptyLabel:SetText("No pending guest anchors.")
    panel.emptyLabel:Show()
    for _, row in ipairs(panel.rows) do
      row:Hide()
    end
    for key in pairs(panel.pendingApprovalsByKey) do
      panel.pendingApprovalsByKey[key] = nil
    end
    SyncGuestAnchorsScrollGeometry(self, panel, 0, panel.rows, refreshReason, dbg)
    ForceGuestAnchorsLayoutRefresh(panel, ui, refreshReason, dbg)
    SyncGuestAnchorsScrollGeometry(self, panel, 0, panel.rows, refreshReason, dbg)
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      self:Debug(
        "GuestAnchors refresh complete: candidatesFound="
          .. tostring(rebuildStats.candidatesFound or 0)
          .. " afterFiltering="
          .. tostring(rebuildStats.afterFiltering or 0)
          .. " rowsProvidedToUI=0"
      )
    end
    if dbg and dbg.Throttle then
      dbg:Throttle("ga_refresh_early_empty", 1.0, "GA_REFRESH", "earlyReturn reason=%s cause=empty_candidates", refreshReason)
    end
    return
  end

  if panel.emptyLabel then
    panel.emptyLabel:Hide()
  end

  local activeApprovalKeys = {}
  local initialFrameWidth = panel.scrollFrame and panel.scrollFrame.GetWidth and panel.scrollFrame:GetWidth() or 0
  if (not initialFrameWidth) or initialFrameWidth <= 0 then
    local panelWidth = panel.GetWidth and panel:GetWidth() or 0
    initialFrameWidth = math.max(1, (tonumber(panelWidth) or 0) - 34)
  end
  initialFrameWidth = math.max(1, tonumber(initialFrameWidth) or 1)
  local initialRowWidth = math.max(1, initialFrameWidth - (2 * GUEST_ANCHOR_ROW_SIDE_PADDING))
  if panel.scrollChild and panel.scrollChild.SetWidth then
    panel.scrollChild:SetWidth(initialFrameWidth)
  end

  for index, candidate in ipairs(candidates) do
    local row = panel.rows[index]
    if not row then
      row = CreateGuestAnchorRow(panel)
      panel.rows[index] = row
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", GUEST_ANCHOR_ROW_SIDE_PADDING, -((index - 1) * GUEST_ANCHOR_ROW_HEIGHT))
    row:SetWidth(initialRowWidth)
    row:SetHeight(GUEST_ANCHOR_ROW_HEIGHT)

    local unit = candidate.unit
    local classFile = candidate.classFile
    local name = candidate.name
    local realm = candidate.realm
    local isSimulated = candidate.isSimulated == true
    local displayName = NS:GetPlayerBaseName(name) or name or "Unknown"
    if isSimulated then
      displayName = "[SIMULATED] " .. tostring(displayName)
    end
    row.name:SetText(displayName)
    local r, g, b = NS:GetClassColor(classFile)
    if isSimulated then
      r, g, b = 1, 0.85, 0.3
    end
    row.name:SetTextColor(r, g, b)

    local candidateKey = candidate.key
    local candidateGuid = candidate.guid
    local fullName = candidate.fullName or (name and realm and (name .. "-" .. realm)) or name
    local approvalKey = candidateKey or candidateGuid or fullName or displayName
    local isPendingApproval = approvalKey and panel.pendingApprovalsByKey[approvalKey] == true or false
    local rowIsAdmin = candidate.isAdmin
    if rowIsAdmin == nil then
      rowIsAdmin = isAdminCharacter == true
    end
    local showButton = candidate.showingButton == nil and (isAdminCharacter == true) or (candidate.showingButton == true)
    local alreadyApproved = (not isSimulated) and (self.IsApprovedGuestUnit and self:IsApprovedGuestUnit(unit) or false) or false
    activeApprovalKeys[approvalKey] = true

    local unitRef = unit
    local nameRef = name
    local realmRef = realm
    local displayNameRef = displayName
    local candidateKeyRef = candidateKey
    local candidateGuidRef = candidateGuid
    local classRef = classFile
    local fullNameRef = fullName
    local approvalKeyRef = approvalKey
    local rowRef = row

    if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
      local coords = CLASS_ICON_TCOORDS[classFile]
      row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
      row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
      row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      row.icon:SetTexCoord(0, 1, 0, 1)
    end

    if row.addButton then
      row.addButton:SetFrameLevel(row:GetFrameLevel() + 2)
      if isSimulated then
        row.addButton:SetText("SIMULATED (No Add)")
      elseif alreadyApproved then
        row.addButton:SetText("Already added")
      elseif isPendingApproval then
        row.addButton:SetText("Pending...")
      else
        row.addButton:SetText("Add to Raid Database")
      end
      if row.addButton.SetEnabled then
        local canClick = showButton and (not alreadyApproved) and (not isPendingApproval)
        row.addButton:SetEnabled(canClick)
      end
    end
    if row.hoverTexture then
      row.hoverTexture:Hide()
    end

    if row.addButton then
      row.addButton:SetScript("OnClick", function()
        if isSimulated then
          if dbg and dbg.Force then
            dbg:Force(
              "GuestAnchorsUI",
              "SimGuestIgnored name=%s guid=%s reason=ui_click_blocked",
              tostring(nameRef or displayNameRef or "?"),
              tostring(candidateGuidRef or "?")
            )
          end
          if self.Print then
            self:Print("SIMULATED guest entries are UI-only and cannot be approved.")
          end
          return
        end
        if not self.IsAdminCharacter or not self:IsAdminCharacter() then
          self:ShowPermissionDeniedPopup()
          return
        end
        if approvalKeyRef and panel.pendingApprovalsByKey[approvalKeyRef] then
          return
        end
        if (not candidateGuidRef or candidateGuidRef == "") and (not nameRef or nameRef == "") then
          self:Print("Cannot add guest " .. tostring(displayNameRef or "?") .. ": missing GUID and name.")
          return
        end
        if rowRef and rowRef.addButton then
          rowRef.addButton:SetText("Pending...")
          if rowRef.addButton.SetEnabled then
            rowRef.addButton:SetEnabled(false)
          end
        end
        if approvalKeyRef then
          panel.pendingApprovalsByKey[approvalKeyRef] = true
        end
        local ok, reason = false, nil
        if self.ApproveGuestCandidate then
          ok, reason = self:ApproveGuestCandidate({
            unit = unitRef,
            key = candidateKeyRef,
            guid = candidateGuidRef,
            name = nameRef,
            realm = realmRef,
            class = classRef,
            fullName = fullNameRef,
          })
        elseif self.AddGuestFromUnit then
          ok = self:AddGuestFromUnit(unitRef)
        end
        if not ok and reason == "already_approved" then
          if approvalKeyRef then
            panel.pendingApprovalsByKey[approvalKeyRef] = nil
          end
          if rowRef and rowRef.addButton then
            rowRef.addButton:SetText("Already added")
            if rowRef.addButton.SetEnabled then
              rowRef.addButton:SetEnabled(false)
            end
          end
        elseif ok and reason == "requested" then
          if self.RefreshGuestAnchors then
            self:RefreshGuestAnchors("approve_requested")
          end
        elseif not ok and (reason == "missing_identity" or reason == "missing_key") then
          if approvalKeyRef then
            panel.pendingApprovalsByKey[approvalKeyRef] = nil
          end
          self:Print("Cannot add guest " .. tostring(displayNameRef or nameRef or "?") .. ": missing GUID/name.")
          if self.RefreshGuestAnchors then
            self:RefreshGuestAnchors("approve_missing_identity")
          end
        elseif not ok then
          if approvalKeyRef then
            panel.pendingApprovalsByKey[approvalKeyRef] = nil
          end
          if self.RefreshGuestAnchors then
            self:RefreshGuestAnchors("approve_failed")
          end
        elseif ok and self.RefreshGuestAnchors then
          if approvalKeyRef then
            panel.pendingApprovalsByKey[approvalKeyRef] = nil
          end
          self:RefreshGuestAnchors("approve_success")
        end
        if self.UI and self.UI.RefreshMain then
          self.UI:RefreshMain()
        elseif UI and UI.RefreshMain then
          UI:RefreshMain()
        end
        if self.IsDebugEnabled and self:IsDebugEnabled() then
          self:Debug(
            "Guest anchor approve click: target="
              .. tostring(displayNameRef or nameRef or "?")
              .. " key="
              .. tostring(candidateKeyRef)
              .. " guid="
              .. tostring(candidateGuidRef)
              .. " result="
              .. tostring(ok and "ok" or (reason or "failed"))
          )
        end
      end)
    end
    row:Show()
    if row.addButton then
      row.addButton:SetShown(showButton)
      row.addButton:SetFrameLevel(row:GetFrameLevel() + 2)
    end
    if dbg and dbg.Throttle then
      local parent = row:GetParent()
      local parentShown = parent and parent.IsShown and parent:IsShown() or false
      local rowWidth = row.GetWidth and row:GetWidth() or 0
      local rowHeight = row.GetHeight and row:GetHeight() or 0
      dbg:Throttle(
        "ga_row_bind_" .. tostring(index),
        1.0,
        "GA_ROW_BIND",
        "idx=%d name=%s guid=%s isAdmin=%s showBtn=%s parentShown=%s w=%.1f h=%.1f",
        index,
        tostring(displayNameRef or nameRef or "?"),
        tostring(candidateGuidRef or "?"),
        tostring(rowIsAdmin),
        tostring(showButton),
        tostring(parentShown),
        tonumber(rowWidth) or 0,
        tonumber(rowHeight) or 0
      )
    end
    if self.IsDebugEnabled and self:IsDebugEnabled() then
      local buttonShown = row.addButton and row.addButton:IsShown() or false
      local buttonVisible = row.addButton and row.addButton:IsVisible() or false
      local buttonAlpha = row.addButton and row.addButton:GetAlpha() or 0
      local rowShown = row:IsShown()
      local rowVisible = row:IsVisible()
      local rowAlpha = row:GetAlpha()
      local rowEffectiveAlpha = row.GetEffectiveAlpha and row:GetEffectiveAlpha() or rowAlpha
      local parent = row:GetParent()
      local parentShown = parent and parent:IsShown() or false
      local parentVisible = parent and parent.IsVisible and parent:IsVisible() or false
      local parentEffectiveAlpha = parent and parent.GetEffectiveAlpha and parent:GetEffectiveAlpha() or 0
      local rowLeft, rowRight, rowTop, rowBottom = GetFrameRectLTRB(row)
      local parentLeft, parentRight, parentTop, parentBottom = GetFrameRectLTRB(parent)
      local rectIntersectsParent =
        RectsIntersect(rowLeft, rowRight, rowTop, rowBottom, parentLeft, parentRight, parentTop, parentBottom)
      local parentName = GetFrameDebugName(parent)
      local topLevelName = GetFrameDebugName(GetTopLevelContainer(row))
      local rowPoint = FormatFramePoint(row)
      local parentPoint = FormatFramePoint(parent)
      local rowHeight = row:GetHeight() or 0
      self:Debug(
        "GuestAnchorsRow bind: name="
          .. tostring(displayNameRef or nameRef or "?")
          .. " isAdmin="
          .. tostring(rowIsAdmin)
          .. " showingButton="
          .. tostring(showButton)
          .. " buttonShown="
          .. tostring(buttonShown)
          .. " buttonVisible="
          .. tostring(buttonVisible)
          .. " buttonAlpha="
          .. tostring(buttonAlpha)
          .. " rowShown="
          .. tostring(rowShown)
          .. " rowVisible="
          .. tostring(rowVisible)
          .. " rowAlpha="
          .. tostring(rowAlpha)
          .. " rowEffAlpha="
          .. tostring(rowEffectiveAlpha)
          .. " parentShown="
          .. tostring(parentShown)
          .. " parentVisible="
          .. tostring(parentVisible)
          .. " parentEffAlpha="
          .. tostring(parentEffectiveAlpha)
          .. " rowHeight="
          .. tostring(rowHeight)
      )
      self:Debug(
        string.format(
          "[GuestAnchorsRow] visible row=%s btn=%s parent=%s effAlpha row=%.2f parent=%.2f rect row=(%s) parent=(%s) parentName=%s topContainer=%s intersects=%s rowPoint=%s parentPoint=%s",
          tostring(rowVisible),
          tostring(buttonVisible),
          tostring(parentVisible),
          tonumber(rowEffectiveAlpha) or 0,
          tonumber(parentEffectiveAlpha) or 0,
          FormatRectLTRB(rowLeft, rowRight, rowTop, rowBottom),
          FormatRectLTRB(parentLeft, parentRight, parentTop, parentBottom),
          parentName,
          topLevelName,
          tostring(rectIntersectsParent),
          rowPoint,
          parentPoint
        )
      )
    end
  end

  for key in pairs(panel.pendingApprovalsByKey) do
    if not activeApprovalKeys[key] then
      panel.pendingApprovalsByKey[key] = nil
    end
  end

  for i = #candidates + 1, #panel.rows do
    panel.rows[i]:Hide()
  end

  SyncGuestAnchorsScrollGeometry(self, panel, #candidates, panel.rows, refreshReason, dbg)
  ForceGuestAnchorsLayoutRefresh(panel, ui, refreshReason, dbg)
  SyncGuestAnchorsScrollGeometry(self, panel, #candidates, panel.rows, refreshReason, dbg)
  if self.IsDebugEnabled and self:IsDebugEnabled() then
    self:Debug(
      "GuestAnchors refresh complete: candidatesFound="
        .. tostring(rebuildStats.candidatesFound or #candidates)
        .. " afterFiltering="
        .. tostring(rebuildStats.afterFiltering or #candidates)
        .. " rowsProvidedToUI="
        .. tostring(#candidates)
        .. " realCount="
        .. tostring(realCount)
        .. " simCount="
        .. tostring(simCount)
    )
  end
end

function UI:SubmitRollVote(session, vote, advanceTest)
  if not session or not vote then
    return
  end
  if (not session.isTest) and GLD and GLD.IsEnabled and GLD.IsSessionActive then
    if not GLD:IsEnabled() or not GLD:IsSessionActive() then
      return
    end
  end

  if GLD and GLD.GetRollStatus then
    local status = GLD:GetRollStatus(session)
    if status ~= "ACTIVE" then
      if status == "PENDING_APPROVAL" then
        GLD:Print("Voting is closed for this item: pending admin approval.")
      else
        GLD:Print("Voting is closed for this item.")
      end
      return
    end
  end
  if session.locked then
    GLD:Print("Voting is closed for this item.")
    return
  end

  local key = NS:GetPlayerKeyFromUnit("player")
  if not key then
    return
  end
  if GLD and GLD.GetRollCandidateKey then
    key = GLD:GetRollCandidateKey(key) or key
  end
  if GLD and GLD.GetEligibilityForVote then
    local eligible, reason = GLD:GetEligibilityForVote(session, key, vote, { log = true, requireData = true })
    if not eligible then
      local reasonText = GLD.GetEligibilityReasonText and GLD:GetEligibilityReasonText(reason, session) or nil
      local msg = "Vote blocked: " .. tostring(vote)
      if reasonText then
        msg = msg .. " (" .. tostring(reasonText) .. ")"
      end
      GLD:Print(msg)
      return
    end
  end

  session.votes = session.votes or {}
  session.votes[key] = vote
  if GLD and GLD.RecordLocalVote then
    GLD:RecordLocalVote(session, vote)
  end

  if session.isTest and GLD.CheckRollCompletion then
    GLD:CheckRollCompletion(session)
  end

  if not session.isTest then
    if IsInRaid() then
      GLD:SendCommMessageSafe(NS.MSG.ROLL_VOTE, {
        rollID = session.rollID,
        rollKey = session.rollKey,
        vote = vote,
        voterKey = key,
      }, "RAID")
    end
  else
    if IsInRaid() then
      GLD:SendCommMessageSafe(NS.MSG.ROLL_VOTE, {
        rollID = session.rollID,
        rollKey = session.rollKey,
        vote = vote,
        voterKey = key,
      }, "RAID")
    end
  end
  if GLD.IsDebugEnabled and GLD:IsDebugEnabled() then
    GLD:Debug("Vote sent: rollID=" .. tostring(session.rollID) .. " vote=" .. tostring(vote))
  end
  if GLD.TraceStep then
    local itemLabel = session.itemLink or session.itemName or "Item"
    GLD:TraceStep("Vote submitted: " .. tostring(vote) .. " for " .. tostring(itemLabel))
  end

  if advanceTest and NS.TestUI and session.testVoterName and not IsInRaid() then
    NS.TestUI.testVotes = NS.TestUI.testVotes or {}
    NS.TestUI.testVotes[session.testVoterName] = vote
    NS.TestUI:AdvanceTestVoter()
  end

  if self.RefreshLootWindow then
    local rollKey = session and (session.rollKey or session.rollID)
    self:RefreshLootWindow({ advance = true, activeKey = rollKey })
  end
end

function UI:ShowRollPopup(session)
  if session and not session.isTest and GLD and GLD.IsEnabled and GLD.IsSessionActive then
    if not GLD:IsEnabled() or not GLD:IsSessionActive() then
      return
    end
  end
  if self.mainFrame and self.mainFrame:IsShown() and session and not session.isTest then
    if self.RefreshLootWindow then
      self:RefreshLootWindow()
    end
    return
  end
  if not AceGUI then
    return
  end

  if self.RefreshLootWindow then
    self:RefreshLootWindow({ forceShow = true })
  end

  self.rollFrames = self.rollFrames or {}
  local frameKey = session.rollKey or session.rollID
  if frameKey and self.rollFrames[frameKey] then
    self.rollFrames[frameKey]:Release()
    self.rollFrames[frameKey] = nil
  end

  local frame = AceGUI:Create("Frame")
  if session.testVoterName then
    frame:SetTitle("Loot Roll - " .. session.testVoterName)
  else
    frame:SetTitle("Loot Roll")
  end
  frame:SetStatusText(session.itemName or "Item")
  frame:SetWidth(400)
  frame:SetHeight(240)
  frame:SetLayout("Flow")
  frame:EnableResize(false)
  if frame.frame and frame.frame.SetBackdrop then
    frame.frame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.frame:SetBackdropColor(0, 0, 0, 1)
  end

  frame:SetCallback("OnClose", function(widget)
    if frameKey and self.rollFrames then
      self.rollFrames[frameKey] = nil
    end
    widget:Release()
  end)

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
  frame:AddChild(iconWidget)

  local itemLabel = AceGUI:Create("InteractiveLabel")
  itemLabel:SetFullWidth(true)
  itemLabel:SetText(session.itemLink or session.itemName or "Unknown Item")
  itemLabel:SetCallback("OnEnter", function()
    local link = session.itemLink
    if link and link ~= "" then
      GameTooltip:SetOwner(frame.frame, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end)
  itemLabel:SetCallback("OnLeave", function()
    GameTooltip:Hide()
  end)
  frame:AddChild(itemLabel)

  local intentLabel = AceGUI:Create("Label")
  intentLabel:SetFullWidth(true)
  intentLabel:SetText("Declare your intent here. Please mirror your choice in the Blizzard roll window.")
  frame:AddChild(intentLabel)

  local waitLabel = AceGUI:Create("Label")
  waitLabel:SetFullWidth(true)
  waitLabel:SetText("")
  frame:AddChild(waitLabel)

  local localKey = NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
  local eligibility = { NEED = true, GREED = true, TRANSMOG = true, PASS = true }
  local reasons = {}
  if GLD and GLD.GetEligibilityForVote then
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
  if eligibility.NEED == false then
    local reasonText = reasonTexts.NEED
    if reasonText then
      waitLabel:SetText("Need disabled: " .. tostring(reasonText))
    else
      waitLabel:SetText("Need disabled.")
    end
  end

  local buttons = {
    { label = "Need", vote = "NEED" },
    { label = "Greed", vote = "GREED" },
    { label = "Transmog", vote = "TRANSMOG" },
    { label = "Pass", vote = "PASS" },
  }

  for _, btn in ipairs(buttons) do
    local button = AceGUI:Create("Button")
    button:SetText(btn.label)
    button:SetWidth(90)
    local allow = eligibility[btn.vote] ~= false
    button:SetDisabled(not allow)
    if button.frame and button.frame.SetAlpha then
      button.frame:SetAlpha(allow and 1 or 0.45)
    end
    button.gldDisabledReason = (not allow and reasonTexts[btn.vote]) or nil
    if button.frame then
      button.frame:SetScript("OnEnter", function()
        if button.gldDisabledReason then
          GameTooltip:SetOwner(button.frame, "ANCHOR_RIGHT")
          GameTooltip:SetText(button.gldDisabledReason, 1, 0.8, 0, 1, true)
          GameTooltip:Show()
        end
      end)
      button.frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    end
    button:SetCallback("OnClick", function()
      self:SubmitRollVote(session, btn.vote, btn.vote ~= "NEED")
      if btn.vote == "NEED" then
        waitLabel:SetText("WAIT FOR EVERYONE TO VOTE TO FIND THE WINNER")
        for _, child in ipairs(frame.children or {}) do
          if child.type == "Button" then
            child:SetDisabled(true)
          end
        end
        return
      end
      if frameKey and self.rollFrames then
        self.rollFrames[frameKey] = nil
      end
      frame:Release()
    end)
    frame:AddChild(button)
  end

  if frameKey then
    self.rollFrames[frameKey] = frame
  else
    self.rollFrame = frame
  end
end

function UI:ShowRollResultPopup(result)
  if not result then
    return
  end
  if self.RecordRollResult then
    self:RecordRollResult(result)
  end
  if not AceGUI then
    return
  end

  if self.resultFrame then
    self.resultFrame:Release()
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Loot Result")
  frame:SetStatusText(result.itemName or "Item")
  frame:SetWidth(420)
  frame:SetHeight(240)
  frame:SetLayout("Fill")
  frame:EnableResize(false)

  local function BuildPopup(target)
    if target._built then
      return
    end
    target._built = true

    local content = target.frame
    target.gldContent = content
    if content then
      content:EnableMouse(true)
    end

    if content and content.SetScript then
      content:SetScript("OnMouseDown", function()
        if target and target.Hide then
          target:Hide()
        end
      end)
    end

    if content then
      if content.HookScript then
        content:HookScript("OnHide", function()
          if target.gldAutoCloseTimer and target.gldAutoCloseTimer.Cancel then
            target.gldAutoCloseTimer:Cancel()
          end
        end)
      elseif content.SetScript then
        content:SetScript("OnHide", function()
          if target.gldAutoCloseTimer and target.gldAutoCloseTimer.Cancel then
            target.gldAutoCloseTimer:Cancel()
          end
        end)
      end
    end

    local itemIcon = content:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(40, 40)
    target.gldItemIcon = itemIcon

    local iconHit = CreateFrame("Frame", nil, content)
    iconHit:SetAllPoints(itemIcon)
    iconHit:EnableMouse(true)
    iconHit:SetScript("OnMouseDown", function()
      if target and target.Hide then
        target:Hide()
      end
    end)
    iconHit:SetScript("OnEnter", function()
      local link = target.gldItemRef
      if link and link ~= "" then
        GameTooltip:SetOwner(iconHit, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
      end
    end)
    iconHit:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    target.gldIconHit = iconHit

    local itemNameLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    itemNameLabel:SetJustifyH("CENTER")
    itemNameLabel:SetWidth(380)
    target.gldItemNameLabel = itemNameLabel

    local stateLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    stateLabel:SetJustifyH("CENTER")
    stateLabel:SetWidth(380)
    target.gldStateLabel = stateLabel

    local positionLine = CreateFrame("Frame", nil, content)
    positionLine:SetHeight(16)
    target.gldPositionLine = positionLine

    local positionLabel = positionLine:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    positionLabel:SetText("Position:")
    target.gldPositionLabel = positionLabel

    local oldPosFS = positionLine:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    target.gldOldPosFS = oldPosFS

    local arrowFS = positionLine:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    arrowFS:SetText("->")
    target.gldArrowFS = arrowFS

    local newPosFS = positionLine:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    target.gldNewPosFS = newPosFS

    local detailLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailLabel:SetJustifyH("CENTER")
    detailLabel:SetWidth(380)
    target.gldDetailLabel = detailLabel
  end

  local function ApplyLayout(target)
    local content = target.gldContent
    local itemIcon = target.gldItemIcon
    local itemNameLabel = target.gldItemNameLabel
    local stateLabel = target.gldStateLabel
    local positionLine = target.gldPositionLine
    local positionLabel = target.gldPositionLabel
    local oldPosFS = target.gldOldPosFS
    local arrowFS = target.gldArrowFS
    local newPosFS = target.gldNewPosFS
    local detailLabel = target.gldDetailLabel

    itemIcon:ClearAllPoints()
    itemIcon:SetPoint("TOP", content, "TOP", 0, -36)

    itemNameLabel:ClearAllPoints()
    itemNameLabel:SetPoint("TOP", itemIcon, "BOTTOM", 0, -6)

    stateLabel:ClearAllPoints()
    stateLabel:SetPoint("TOP", itemNameLabel, "BOTTOM", 0, -10)

    positionLine:ClearAllPoints()
    positionLine:SetPoint("TOP", stateLabel, "BOTTOM", 0, -6)

    detailLabel:ClearAllPoints()
    detailLabel:SetPoint("TOP", positionLine, "BOTTOM", 0, -6)

    local gap = 4
    local totalWidth = positionLabel:GetStringWidth()
      + oldPosFS:GetStringWidth()
      + arrowFS:GetStringWidth()
      + newPosFS:GetStringWidth()
      + (gap * 3)
    if totalWidth < 1 then
      totalWidth = 1
    end
    positionLine:SetWidth(totalWidth)

    positionLabel:ClearAllPoints()
    positionLabel:SetPoint("LEFT", positionLine, "LEFT", 0, 0)
    oldPosFS:ClearAllPoints()
    oldPosFS:SetPoint("LEFT", positionLabel, "RIGHT", gap, 0)
    arrowFS:ClearAllPoints()
    arrowFS:SetPoint("LEFT", oldPosFS, "RIGHT", gap, 0)
    newPosFS:ClearAllPoints()
    newPosFS:SetPoint("LEFT", arrowFS, "RIGHT", gap, 0)
  end

  BuildPopup(frame)

  if C_Timer and C_Timer.NewTimer then
    frame.gldAutoCloseTimer = C_Timer.NewTimer(5, function()
      if frame and frame.frame and frame.frame.IsShown and frame.frame:IsShown() then
        frame:Hide()
      end
    end)
  elseif C_Timer and C_Timer.After then
    C_Timer.After(5, function()
      if frame and frame.frame and frame.frame.IsShown and frame.frame:IsShown() then
        frame:Hide()
      end
    end)
  end

  local itemRef = result.itemLink or result.itemID
  local fallbackName = result.itemName or "Item"
  local fallbackIcon = result.itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark"

  frame.gldItemRef = itemRef
  frame.gldFallbackName = fallbackName
  frame.gldFallbackIcon = fallbackIcon

  local function UpdateItemDisplay(target)
    local itemNameLabel = target.gldItemNameLabel
    local itemIcon = target.gldItemIcon
    if not itemRef or itemRef == "" then
      itemNameLabel:SetText(fallbackName)
      itemIcon:SetTexture(fallbackIcon)
      return true
    end
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemRef)
    if name and name ~= "" then
      itemNameLabel:SetText(name)
    else
      itemNameLabel:SetText("Loading item...")
    end
    itemIcon:SetTexture(icon or fallbackIcon)
    return name ~= nil and icon ~= nil
  end

  local function ClearItemEvent(target)
    local content = target.gldContent
    if content and content.UnregisterEvent then
      content:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    if content and content.SetScript then
      content:SetScript("OnEvent", nil)
    end
  end

  if not UpdateItemDisplay(frame) and frame.gldContent and frame.gldContent.RegisterEvent then
    local content = frame.gldContent
    content:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    content:SetScript("OnEvent", function()
      if UpdateItemDisplay(frame) then
        ClearItemEvent(frame)
      end
    end)
    if GLD and GLD.RequestItemData and result.itemLink then
      GLD:RequestItemData(result.itemLink)
    end
  end

  if frame.gldContent and frame.gldContent.HookScript then
    frame.gldContent:HookScript("OnHide", function()
      ClearItemEvent(frame)
    end)
  end

  local function UpdatePopup(target, payload)
    local isWinner = payload.isWinner
    if isWinner == nil then
      local localKey = NS.GetPlayerKeyFromUnit and NS:GetPlayerKeyFromUnit("player") or nil
      local localFull = GLD and GLD.GetUnitFullName and GLD:GetUnitFullName("player") or nil
      local localShort = UnitName("player")
      if localKey and payload.winnerKey and payload.winnerKey == localKey then
        isWinner = true
      elseif localFull and payload.winnerName and payload.winnerName == localFull then
        isWinner = true
      elseif localShort and payload.winnerShortName and payload.winnerShortName == localShort then
        isWinner = true
      else
        isWinner = false
      end
    end

    local roll = payload.winnerRoll
    if roll == nil then
      roll = payload.winningRoll
    end
    if roll == nil and GLD and GLD.GetWinnerRoll then
      roll = GLD:GetWinnerRoll(payload)
    end
    local rollText = roll ~= nil and tostring(roll) or "?"
    local isLost = payload.resolutionReason == "LOST" or payload.rollStatus == "LOST"

    local stateLabel = target.gldStateLabel
    local detailLabel = target.gldDetailLabel
    local positionLabel = target.gldPositionLabel
    local oldPosFS = target.gldOldPosFS
    local arrowFS = target.gldArrowFS
    local newPosFS = target.gldNewPosFS

    if isLost then
      stateLabel:SetText("Item Lost (Void)")
      stateLabel:SetTextColor(1, 0.5, 0.5)
      detailLabel:SetText("No queue movement for this item.")
      oldPosFS:SetTextColor(0.9, 0.9, 0.9)
      newPosFS:SetTextColor(0.9, 0.9, 0.9)
    elseif isWinner then
      stateLabel:SetText("Item Claimed!")
      stateLabel:SetTextColor(0.2, 1, 0.2)
      detailLabel:SetText("Winning Roll: " .. rollText)
      oldPosFS:SetTextColor(0.2, 1, 0.2)
      newPosFS:SetTextColor(1, 0.2, 0.2)
    else
      stateLabel:SetText("Not first in line this time")
      stateLabel:SetTextColor(1, 0.82, 0.4)
      local winnerName = payload.winnerName or payload.winnerShortName or "Unknown"
      if winnerName == "" then
        winnerName = "Unknown"
      end
      detailLabel:SetText("Winner: " .. tostring(winnerName) .. " - Roll: " .. rollText)
      oldPosFS:SetTextColor(1, 0.2, 0.2)
      newPosFS:SetTextColor(0.2, 1, 0.2)
    end

    local oldPosText = payload.oldPosition ~= nil and tostring(payload.oldPosition) or "?"
    local newPosText = payload.newPosition ~= nil and tostring(payload.newPosition) or "?"
    positionLabel:SetTextColor(0.9, 0.9, 0.9)
    oldPosFS:SetText(oldPosText)
    arrowFS:SetTextColor(0.8, 0.8, 0.8)
    newPosFS:SetText(newPosText)
  end

  UpdatePopup(frame, result)
  ApplyLayout(frame)

  self.resultFrame = frame
end


