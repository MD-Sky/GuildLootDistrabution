local _, NS = ...

local GLD = NS.GLD
local AceGUI = LibStub("AceGUI-3.0", true)

local UI = {}
NS.UI = UI
GLD.UI = UI

function GLD:InitUI()
  if not AceGUI then
    return
  end
  UI.mainFrame = nil
  UI.rollFrame = nil
  UI.rollFrames = nil
end

function UI:ToggleMain()
  if not self.mainFrame then
    self:CreateMainFrame()
    self.mainFrame:Show()
    self:RefreshMain()
    return
  end
  if self.mainFrame:IsShown() then
    self.mainFrame:Hide()
  else
    self.mainFrame:Show()
    self:RefreshMain()
  end
end

function UI:CreateMainFrame()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Guild Loot Distribution")
  frame:SetStatusText("GLD / Disloot")
  frame:SetWidth(800)
  frame:SetHeight(500)
  frame:SetLayout("Flow")
  frame:EnableResize(true)
  if frame.frame then
    frame.frame:HookScript("OnSizeChanged", function()
      if UI.guestAnchorsVisible == false and UI.guestGroup and UI.guestGroup.frame then
        UI.guestGroup.frame:Hide()
        UI.guestGroup:SetHeight(1)
      end
    end)
  end
  if frame.frame and frame.frame.SetBackdrop then
    frame.frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame.frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  end

  local header = AceGUI:Create("Label")
  header:SetFullWidth(true)
  header:SetText("My Position: --")
  frame:AddChild(header)

  local filterGroup = AceGUI:Create("SimpleGroup")
  filterGroup:SetFullWidth(true)
  filterGroup:SetLayout("Flow")

  local showAbsent = AceGUI:Create("CheckBox")
  showAbsent:SetLabel("Show Offline Members")
  showAbsent:SetValue(true)
  showAbsent:SetWidth(180)
  showAbsent:SetCallback("OnValueChanged", function(_, _, value)
    UI.showAbsent = value
    UI:RefreshMain()
  end)
  filterGroup:AddChild(showAbsent)

  local search = AceGUI:Create("EditBox")
  search:SetLabel("Player Search")
  search:SetWidth(220)
  search:SetCallback("OnTextChanged", function(_, _, value)
    UI.filterText = value
    UI:RefreshMain()
  end)
  filterGroup:AddChild(search)

  frame:AddChild(filterGroup)

  local adminButton = AceGUI:Create("Button")
  adminButton:SetText("Admin Panel")
  adminButton:SetWidth(120)
  adminButton:SetCallback("OnClick", function()
    if GLD:IsAdmin() then
      UI:OpenAdmin()
    else
      GLD:Print("you do not have Guild Permission to access this panel")
    end
  end)
  frame:AddChild(adminButton)

  local refreshGuildBtn = AceGUI:Create("Button")
  refreshGuildBtn:SetText("Refresh Guild Members")
  refreshGuildBtn:SetWidth(180)
  refreshGuildBtn:SetCallback("OnClick", function()
    if GLD:IsAdmin() then
      GLD:RefreshFromGuildRoster()
    else
      GLD:Print("you do not have Guild Permission to access this panel")
    end
  end)
  frame:AddChild(refreshGuildBtn)

  local toggleGuestsBtn = AceGUI:Create("Button")
  toggleGuestsBtn:SetText("Toggle Guest Anchors")
  toggleGuestsBtn:SetWidth(160)
  toggleGuestsBtn:SetCallback("OnClick", function()
    if GLD:IsAdmin() then
      UI.guestAnchorsVisible = not UI.guestAnchorsVisible
      UI:RefreshMain()
    else
      GLD:Print("you do not have Guild Permission to access this panel")
    end
  end)
  frame:AddChild(toggleGuestsBtn)

  local sessionStart = AceGUI:Create("Button")
  sessionStart:SetText("Start Session")
  sessionStart:SetWidth(120)
  sessionStart:SetCallback("OnClick", function()
    if GLD:IsAdmin() then
      GLD:StartSession()
      UI:RefreshMain()
    else
      GLD:Print("you do not have Guild Permission to access this panel")
    end
  end)
  frame:AddChild(sessionStart)

  local sessionEnd = AceGUI:Create("Button")
  sessionEnd:SetText("End Session")
  sessionEnd:SetWidth(120)
  sessionEnd:SetCallback("OnClick", function()
    if GLD:IsAdmin() then
      GLD:EndSession()
      UI:RefreshMain()
    else
      GLD:Print("you do not have Guild Permission to access this panel")
    end
  end)
  frame:AddChild(sessionEnd)

  local guestGroup = AceGUI:Create("InlineGroup")
  guestGroup:SetTitle("Guest Anchors (Non-guild Party/Raid)")
  guestGroup:SetFullWidth(true)
  guestGroup:SetHeight(80)
  guestGroup:SetLayout("Fill")
  if guestGroup.frame then
    guestGroup.frame:HookScript("OnShow", function()
      if UI.guestAnchorsVisible == false then
        guestGroup.frame:Hide()
        guestGroup:SetHeight(1)
      end
    end)
  end

  local guestScroll = AceGUI:Create("ScrollFrame")
  guestScroll:SetLayout("Flow")
  guestGroup:AddChild(guestScroll)

  frame:AddChild(guestGroup)

  local rosterDescription = AceGUI:Create("Label")
  rosterDescription:SetFullWidth(true)
  rosterDescription:SetHeight(24)
  rosterDescription:SetText("This table shows all guild members in the current session, including their role, loot history, raid participation, and attendance status to support fair loot decisions.")
  frame:AddChild(rosterDescription)

  local rosterContainer = AceGUI:Create("SimpleGroup")
  rosterContainer:SetFullWidth(true)
  rosterContainer:SetFullHeight(true)
  rosterContainer:SetLayout("List")
  if rosterContainer.frame and rosterContainer.frame.SetBackdrop then
    rosterContainer.frame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    rosterContainer.frame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
  end

  local rosterHeaderGroup = AceGUI:Create("SimpleGroup")
  rosterHeaderGroup:SetFullWidth(true)
  rosterHeaderGroup:SetLayout("Flow")
  rosterContainer:AddChild(rosterHeaderGroup)

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("Flow")
  scroll:SetFullWidth(true)
  scroll:SetFullHeight(true)
  rosterContainer:AddChild(scroll)

  frame:AddChild(rosterContainer)

  self.mainFrame = frame
  self.header = header
  self.showAbsent = true
  self.filterText = ""
  self.scroll = scroll
  self.guestGroup = guestGroup
  self.guestScroll = guestScroll
  self.rosterHeader = rosterHeaderGroup
  self.toggleGuestsBtn = toggleGuestsBtn
  self.guestAnchorsVisible = true
end

function UI:CreatePendingFrame()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Pending Votes")
  frame:SetStatusText("Waiting on votes")
  frame:SetWidth(420)
  frame:SetHeight(260)
  frame:SetLayout("Fill")
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

  if frame.frame then
    frame.frame:ClearAllPoints()
    local width = UIParent and UIParent:GetWidth() or 0
    frame.frame:SetPoint("CENTER", UIParent, "CENTER", -(width * 0.25), 0)
  end

  local pendingScroll = AceGUI:Create("ScrollFrame")
  pendingScroll:SetLayout("Flow")
  frame:AddChild(pendingScroll)

  self.pendingFrame = frame
  self.pendingScroll = pendingScroll
end

function UI:ShowPendingFrame()
  if not self.pendingFrame then
    self:CreatePendingFrame()
  end
  if not self.pendingFrame:IsShown() then
    self.pendingFrame:Show()
  end
  self:RefreshPendingVotes()
end

function UI:TogglePendingFrame()
  if not self.pendingFrame then
    self:CreatePendingFrame()
    self.pendingFrame:Show()
    self:RefreshPendingVotes()
    return
  end
  if self.pendingFrame:IsShown() then
    self.pendingFrame:Hide()
  else
    self.pendingFrame:Show()
    self:RefreshPendingVotes()
  end
end

function UI:RefreshMain()
  if not self.mainFrame then
    return
  end

  local isAdmin = GLD:IsAdmin()
  local myPos = "--"
  if isAdmin then
    local key = NS:GetPlayerKeyFromUnit("player")
    local player = key and GLD.db.players[key]
    if player and player.queuePos then
      myPos = tostring(player.queuePos)
    end
  else
    if GLD.shadow and GLD.shadow.my and GLD.shadow.my.queuePos then
      myPos = tostring(GLD.shadow.my.queuePos)
    end
  end

  self.header:SetText("My Position: " .. myPos)

  GLD:UpdateGuestAttendanceFromGroup()

  if self.toggleGuestsBtn and self.toggleGuestsBtn.frame then
    if isAdmin then
      self.toggleGuestsBtn.frame:Show()
    else
      self.toggleGuestsBtn.frame:Hide()
    end
  end

  if self.guestAnchorsVisible ~= false then
    if self.guestGroup and self.guestGroup.frame then
      self.guestGroup.frame:Show()
      self.guestGroup:SetHeight(80)
    end
    self:RefreshGuestAnchors(isAdmin)
  else
    if self.guestGroup and self.guestGroup.frame then
      self.guestGroup.frame:Hide()
      self.guestGroup:SetHeight(1)
    end
    if self.guestScroll then
      self.guestScroll:ReleaseChildren()
    end
  end

  if self.mainFrame and self.mainFrame.DoLayout then
    self.mainFrame:DoLayout()
  end

  if self.rosterHeader then
    self.rosterHeader:ReleaseChildren()
  end
  self.scroll:ReleaseChildren()

  local entries = self:GetRosterEntries(isAdmin)
  self:AddHeaderRow(isAdmin, self.rosterHeader)
  for _, entry in ipairs(entries) do
    self:AddRosterRow(entry, isAdmin)
    self:AddDivider()
  end
end

function UI:RefreshGuestAnchors(isAdmin)
  if not self.guestScroll then
    return
  end

  self.guestScroll:ReleaseChildren()

  local existingGuests = {}
  for key, player in pairs(GLD.db.players or {}) do
    if player and player.source == "guest" then
      existingGuests[key] = true
    end
  end

  local units = {}
  local function addUnit(unit)
    if not UnitExists(unit) or not UnitIsConnected(unit) then
      return
    end
    if UnitIsUnit(unit, "player") then
      return
    end
    if UnitIsInMyGuild and UnitIsInMyGuild(unit) then
      return
    end
    local key = NS:GetPlayerKeyFromUnit(unit)
    if key and existingGuests[key] then
      return
    end
    units[#units + 1] = unit
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      addUnit("raid" .. i)
    end
  elseif IsInGroup() then
    for i = 1, GetNumSubgroupMembers() do
      addUnit("party" .. i)
    end
  end

  if #units == 0 then
    local empty = AceGUI:Create("Label")
    empty:SetText("No non-guild party/raid members found.")
    empty:SetFullWidth(true)
    empty:SetHeight(18)
    self.guestScroll:AddChild(empty)
    if self.guestGroup then
      self.guestGroup:SetHeight(70)
    end
    return
  end

  for _, unit in ipairs(units) do
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

    local name, realm = UnitName(unit)
    local classFile = select(2, UnitClass(unit))
    local displayName = name or "?"
    if realm and realm ~= "" then
      displayName = displayName .. "-" .. realm
    end

    local classLabel = AceGUI:Create("Label")
    classLabel:SetText(NS:GetClassIcon(classFile))
    classLabel:SetWidth(30)
    row:AddChild(classLabel)

    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetText(displayName)
    nameLabel:SetWidth(200)
    row:AddChild(nameLabel)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText("Add Guest")
    addBtn:SetWidth(100)
    addBtn:SetCallback("OnClick", function()
      if GLD:IsAdmin() then
        GLD:AddGuestFromUnit(unit)
        UI:RefreshMain()
      else
        GLD:Print("you do not have Guild Permission to access this panel")
      end
    end)
    if not isAdmin and addBtn.SetDisabled then
      addBtn:SetDisabled(true)
    end
    row:AddChild(addBtn)

    self.guestScroll:AddChild(row)
  end

  if self.guestGroup then
    local rowHeight = 28
    local padding = 18
    self.guestGroup:SetHeight((#units * rowHeight) + padding)
  end
end

function UI:RefreshPendingVotes()
  if not self.pendingFrame or not self.pendingFrame:IsShown() or not self.pendingScroll then
    return
  end

  self.pendingScroll:ReleaseChildren()

  local guidToInfo = {}
  local nameToInfo = {}
  local nameRealmToInfo = {}

  local function addName(name, realm, classFile)
    if not name or name == "" then
      return
    end
    local full = realm and realm ~= "" and (name .. "-" .. realm) or name
    nameToInfo[name] = { name = name, class = classFile, full = full }
    nameRealmToInfo[full] = { name = name, class = classFile, full = full }
  end

  local function addUnit(unit)
    if not UnitExists(unit) then
      return
    end
    local name, realm = UnitName(unit)
    if not name then
      return
    end
    local classFile = select(2, UnitClass(unit))
    local guid = UnitGUID(unit)
    if guid then
      local full = realm and realm ~= "" and (name .. "-" .. realm) or name
      guidToInfo[guid] = { name = name, class = classFile, full = full }
    end
    addName(name, realm, classFile)
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      addUnit("raid" .. i)
    end
  elseif IsInGroup() then
    for i = 1, GetNumSubgroupMembers() do
      addUnit("party" .. i)
    end
    addUnit("player")
  else
    addUnit("player")
  end

  for key, player in pairs(GLD.db.players or {}) do
    if player and player.name then
      addName(player.name, player.realm, player.class)
      if key and key:find("^Player%-") then
        guidToInfo[key] = { name = player.name, class = player.class }
      end
    end
  end

  local rolls = {}
  for rollID, session in pairs(GLD.activeRolls or {}) do
    if session and not session.locked then
      rolls[#rolls + 1] = session
    end
  end
  table.sort(rolls, function(a, b)
    return (a.createdAt or 0) < (b.createdAt or 0)
  end)

  if #rolls == 0 then
    local emptyLabel = AceGUI:Create("Label")
    emptyLabel:SetFullWidth(true)
    emptyLabel:SetText("No active loot votes.")
    self.pendingScroll:AddChild(emptyLabel)
    return
  end

  local function getNameAndClass(key)
    if not key then
      return "?", nil, nil
    end
    local guidMatch = guidToInfo[key]
    if guidMatch then
      return guidMatch.name, guidMatch.class, guidMatch.full
    end
    local nameMatch = nameRealmToInfo[key]
    if nameMatch then
      return nameMatch.name, nameMatch.class, nameMatch.full
    end
    local name = NS:GetNameRealmFromKey(key)
    if name and nameToInfo[name] then
      local info = nameToInfo[name]
      return info.name, info.class, info.full
    end
    if name then
      return name, nil, name
    end
    return tostring(key), nil, tostring(key)
  end

  local function colorizeName(name, classFile)
    if not name then
      return "?"
    end
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
      local c = RAID_CLASS_COLORS[classFile]
      return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
    end
    return name
  end

  for _, session in ipairs(rolls) do
    local expected = session.expectedVoters or {}
    local votes = session.votes or {}
    local pending = {}
    local pendingTargets = {}
    for _, key in ipairs(expected) do
      if not votes[key] then
        local name, classFile, full = getNameAndClass(key)
        pending[#pending + 1] = colorizeName(name, classFile)
        if full and full ~= "" then
          pendingTargets[#pendingTargets + 1] = full
        end
      end
    end

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")

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
    row:AddChild(iconWidget)

    local itemLabel = AceGUI:Create("InteractiveLabel")
    itemLabel:SetText(session.itemLink or session.itemName or "Unknown Item")
    itemLabel:SetWidth(190)
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
    row:AddChild(itemLabel)

    local waitingLabel = AceGUI:Create("Label")
    waitingLabel:SetWidth(140)
    if #pending == 0 then
      local winnerKey = GLD.ResolveRollWinner and GLD:ResolveRollWinner(session) or nil
      local winnerName = nil
      if winnerKey then
        local name, _, full = getNameAndClass(winnerKey)
        winnerName = full or name
      end
      if winnerName and winnerName ~= "" then
        waitingLabel:SetText("|cff88ff88Winner: " .. winnerName .. "|r")
      else
        waitingLabel:SetText("|cffaaaaaaWaiting: none|r")
      end
    else
      waitingLabel:SetText("|cffaaaaaaWaiting: " .. table.concat(pending, ", ") .. "|r")
    end
    row:AddChild(waitingLabel)

    if GLD:IsAuthority() and #pendingTargets > 0 then
      local reopenBtn = AceGUI:Create("Button")
      reopenBtn:SetText("Reopen")
      reopenBtn:SetWidth(70)
      reopenBtn:SetCallback("OnClick", function()
        for _, target in ipairs(pendingTargets) do
          GLD:SendCommMessageSafe(NS.MSG.ROLL_SESSION, {
            rollID = session.rollID,
            rollTime = session.rollTime,
            itemLink = session.itemLink,
            itemName = session.itemName,
            quality = session.quality,
            canNeed = session.canNeed,
            canGreed = session.canGreed,
            canTransmog = session.canTransmog,
            test = session.isTest,
            reopen = true,
          }, "WHISPER", target)
        end
      end)
      row:AddChild(reopenBtn)
    end

    self.pendingScroll:AddChild(row)
  end
end

function UI:GetRosterEntries(isAdmin)
  local entries = {}
  local filter = (self.filterText or ""):lower()

  if isAdmin then
    local list = {}
    for _, player in pairs(GLD.db.players) do
      if self.showAbsent or player.attendance == "PRESENT" then
        if filter == "" or (player.name and player.name:lower():find(filter, 1, true)) then
          table.insert(list, player)
        end
      end
    end

    table.sort(list, function(a, b)
      if a.attendance == "PRESENT" and b.attendance ~= "PRESENT" then
        return true
      end
      if a.attendance ~= "PRESENT" and b.attendance == "PRESENT" then
        return false
      end
      if a.queuePos and b.queuePos then
        return a.queuePos < b.queuePos
      end
      if a.savedPos and b.savedPos then
        return a.savedPos < b.savedPos
      end
      return (a.name or "") < (b.name or "")
    end)

    for _, player in ipairs(list) do
      table.insert(entries, {
        name = player.name,
        class = player.class,
        role = NS:GetRoleForPlayer(player.name),
        queuePos = player.queuePos,
        savedPos = player.savedPos,
        attendance = player.attendance,
        numAccepted = player.numAccepted,
        attendanceCount = player.attendanceCount,
        source = player.source,
      })
    end
  else
    local roster = GLD.shadow and GLD.shadow.roster or {}
    local list = {}
    for _, entry in pairs(roster) do
      if self.showAbsent or entry.attendance == "PRESENT" then
        if filter == "" or (entry.name and entry.name:lower():find(filter, 1, true)) then
          table.insert(list, entry)
        end
      end
    end
    table.sort(list, function(a, b)
      if a.queuePos and b.queuePos then
        return a.queuePos < b.queuePos
      end
      return (a.name or "") < (b.name or "")
    end)

    for _, entry in ipairs(list) do
      table.insert(entries, {
        name = entry.name,
        class = entry.class,
        role = entry.role or "NONE",
        queuePos = entry.queuePos,
        attendance = entry.attendance,
      })
    end
  end

  return entries
end

function UI:AddHeaderRow(isAdmin, container)
  local target = container or self.scroll
  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")

  local classHeader = AceGUI:Create("Label")
  classHeader:SetText("Class")
  classHeader:SetWidth(60)
  row:AddChild(classHeader)

  local roleHeader = AceGUI:Create("Label")
  roleHeader:SetText("Role")
  roleHeader:SetWidth(50)
  row:AddChild(roleHeader)

  local nameHeader = AceGUI:Create("Label")
  nameHeader:SetText("Name")
  nameHeader:SetWidth(180)
  row:AddChild(nameHeader)

  local posHeader = AceGUI:Create("Label")
  posHeader:SetText("Queue")
  posHeader:SetWidth(60)
  row:AddChild(posHeader)

  if isAdmin then
    local prevHeader = AceGUI:Create("Label")
    prevHeader:SetText("Prev")
    prevHeader:SetWidth(50)
    row:AddChild(prevHeader)

    local wonHeader = AceGUI:Create("Label")
    wonHeader:SetText("Won")
    wonHeader:SetWidth(50)
    row:AddChild(wonHeader)

    local raidsHeader = AceGUI:Create("Label")
    raidsHeader:SetText("Raids")
    raidsHeader:SetWidth(60)
    row:AddChild(raidsHeader)
  end

  local attendanceHeader = AceGUI:Create("Label")
  attendanceHeader:SetText("Attendance")
  attendanceHeader:SetWidth(90)
  row:AddChild(attendanceHeader)

  target:AddChild(row)
end

function UI:AddDivider()
  local divider = AceGUI:Create("Heading")
  divider:SetText(" ")
  divider:SetFullWidth(true)
  self.scroll:AddChild(divider)
end

function UI:AddRosterRow(entry, isAdmin)
  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")

  local classLabel = AceGUI:Create("Label")
  classLabel:SetText(NS:GetClassIcon(entry.class))
  classLabel:SetWidth(60)
  row:AddChild(classLabel)

  local roleLabel = AceGUI:Create("Label")
  roleLabel:SetText(NS:GetRoleIcon(entry.role))
  roleLabel:SetWidth(50)
  row:AddChild(roleLabel)

  local nameLabel = AceGUI:Create("Label")
  local nameText = entry.name or "?"
  if isAdmin and entry.source == "guest" then
    nameText = nameText .. " (Guest)"
  elseif isAdmin and entry.source == "test" then
    nameText = nameText .. " (Test)"
  end
  nameLabel:SetText(nameText)
  nameLabel:SetWidth(180)
  row:AddChild(nameLabel)

  local posLabel = AceGUI:Create("Label")
  posLabel:SetText(entry.queuePos or "-")
  posLabel:SetWidth(60)
  row:AddChild(posLabel)

  if isAdmin then
    local prevLabel = AceGUI:Create("Label")
    prevLabel:SetText(entry.savedPos or "-")
    prevLabel:SetWidth(50)
    row:AddChild(prevLabel)

    local wonLabel = AceGUI:Create("Label")
    wonLabel:SetText(entry.numAccepted or 0)
    wonLabel:SetWidth(50)
    row:AddChild(wonLabel)

    local raidsLabel = AceGUI:Create("Label")
    raidsLabel:SetText(entry.attendanceCount or 0)
    raidsLabel:SetWidth(60)
    row:AddChild(raidsLabel)
  end

  local attendanceLabel = AceGUI:Create("Label")
  attendanceLabel:SetText(NS:ColorAttendance(entry.attendance))
  attendanceLabel:SetWidth(90)
  row:AddChild(attendanceLabel)

  self.scroll:AddChild(row)
end

function UI:ShowRollPopup(session)
  if not AceGUI then
    return
  end

  if self.ShowPendingFrame then
    self:ShowPendingFrame()
  end

  self.rollFrames = self.rollFrames or {}
  if session.rollID and self.rollFrames[session.rollID] then
    self.rollFrames[session.rollID]:Release()
    self.rollFrames[session.rollID] = nil
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
    if session.rollID and self.rollFrames then
      self.rollFrames[session.rollID] = nil
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
    if btn.vote == "NEED" and session.canNeed == false then
      button:SetDisabled(true)
    end
    if btn.vote == "GREED" and session.canGreed == false then
      button:SetDisabled(true)
    end
    if btn.vote == "TRANSMOG" and session.canTransmog == false then
      button:SetDisabled(true)
    end
    button:SetCallback("OnClick", function()
      session.votes = session.votes or {}
      local key = NS:GetPlayerKeyFromUnit("player")
      session.votes[key] = btn.vote
      if self.RefreshPendingVotes then
        self:RefreshPendingVotes()
      end

      if not session.isTest then
        local authority = GLD:GetAuthorityName()
        if authority and not GLD:IsAuthority() then
          GLD:SendCommMessageSafe(NS.MSG.ROLL_VOTE, {
            rollID = session.rollID,
            vote = btn.vote,
            voterKey = key,
          }, "WHISPER", authority)
        else
          local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "SAY")
          GLD:SendCommMessageSafe(NS.MSG.ROLL_VOTE, {
            rollID = session.rollID,
            vote = btn.vote,
            voterKey = key,
          }, channel)
        end
      else
        local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "SAY")
        GLD:SendCommMessageSafe(NS.MSG.ROLL_VOTE, {
          rollID = session.rollID,
          vote = btn.vote,
          voterKey = key,
        }, channel)
      end
      if session.locked then
        GLD:Print("Result locked. Your vote was recorded but the outcome is final.")
      end
      if btn.vote == "NEED" then
        waitLabel:SetText("WAIT FOR EVERYONE TO VOTE TO FIND THE WINNER")
        for _, child in ipairs(frame.children or {}) do
          if child.type == "Button" then
            child:SetDisabled(true)
          end
        end
        return
      end
      if session.rollID and self.rollFrames then
        self.rollFrames[session.rollID] = nil
      end
      frame:Release()
      if NS.TestUI and session.testVoterName and not IsInGroup() and not IsInRaid() then
        NS.TestUI.testVotes[session.testVoterName] = btn.vote
        NS.TestUI:AdvanceTestVoter()
      end
    end)
    frame:AddChild(button)
  end

  if session.rollID then
    self.rollFrames[session.rollID] = frame
  else
    self.rollFrame = frame
  end
end

function UI:ShowRollResultPopup(result)
  if not AceGUI or not result then
    return
  end

  if self.resultFrame then
    self.resultFrame:Release()
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Loot Result")
  frame:SetStatusText(result.itemName or "Item")
  frame:SetWidth(420)
  frame:SetHeight(180)
  frame:SetLayout("Flow")
  frame:EnableResize(false)

  local itemLabel = AceGUI:Create("InteractiveLabel")
  itemLabel:SetFullWidth(true)
  itemLabel:SetText(result.itemLink or result.itemName or "Unknown Item")
  itemLabel:SetCallback("OnEnter", function()
    local link = result.itemLink
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

  local winnerLabel = AceGUI:Create("Label")
  winnerLabel:SetFullWidth(true)
  winnerLabel:SetText("Winner: " .. tostring(result.winnerName or "None"))
  frame:AddChild(winnerLabel)

  local closeBtn = AceGUI:Create("Button")
  closeBtn:SetText("OK")
  closeBtn:SetWidth(100)
  closeBtn:SetCallback("OnClick", function()
    frame:Hide()
  end)
  frame:AddChild(closeBtn)

  self.resultFrame = frame
end
