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
end

function UI:ToggleMain()
  if not self.mainFrame then
    self:CreateMainFrame()
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
  frame:EnableResize(false)
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

  local rosterGroup = AceGUI:Create("SimpleGroup")
  rosterGroup:SetFullWidth(true)
  rosterGroup:SetFullHeight(true)
  rosterGroup:SetLayout("Fill")
  if rosterGroup.frame and rosterGroup.frame.SetBackdrop then
    rosterGroup.frame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    rosterGroup.frame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
  end

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("Flow")
  rosterGroup:AddChild(scroll)

  frame:AddChild(rosterGroup)

  self.mainFrame = frame
  self.header = header
  self.showAbsent = true
  self.filterText = ""
  self.scroll = scroll
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

  self.scroll:ReleaseChildren()

  local entries = self:GetRosterEntries(isAdmin)
  self:AddHeaderRow(isAdmin)
  self:AddDivider()
  for _, entry in ipairs(entries) do
    self:AddRosterRow(entry, isAdmin)
    self:AddDivider()
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

function UI:AddHeaderRow(isAdmin)
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

  self.scroll:AddChild(row)
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
  nameLabel:SetText(entry.name or "?")
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

  if self.rollFrame then
    self.rollFrame:Release()
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
      GLD:SendCommMessageSafe(NS.MSG.ROLL_VOTE, {
        rollID = session.rollID,
        vote = btn.vote,
      }, "RAID")
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
      frame:Hide()
      if NS.TestUI and session.testVoterName then
        NS.TestUI.testVotes[session.testVoterName] = btn.vote
        NS.TestUI:AdvanceTestVoter()
      end
    end)
    frame:AddChild(button)
  end

  self.rollFrame = frame
end
