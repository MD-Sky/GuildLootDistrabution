local _, NS = ...

local GLD = NS.GLD

local Debug = NS.Debug or {}
NS.Debug = Debug

Debug.enabled = Debug.enabled == true
Debug.level = tonumber(Debug.level) == 2 and 2 or 1
Debug.echoToChat = Debug.echoToChat == true
Debug._once = Debug._once or {}
Debug._throttle = Debug._throttle or {}
Debug._buffer = Debug._buffer or {}

local PREFIX = "[LLYDBG]"

local function Now()
  if GetTimePreciseSec then
    return GetTimePreciseSec()
  end
  if GetTime then
    return GetTime()
  end
  if time then
    return time()
  end
  return 0
end

local function FormatMessage(fmt, ...)
  local argCount = select("#", ...)
  if argCount > 0 then
    local ok, text = pcall(string.format, tostring(fmt or ""), ...)
    if ok then
      return text
    end
  end
  return tostring(fmt or "")
end

local function DefaultSink(line, category)
  if GLD and GLD.UI then
    if GLD.UI.AddDebugLine then
      GLD.UI:AddDebugLine(line, category)
      return true
    end
    if GLD.UI.AppendDebugLine then
      GLD.UI:AppendDebugLine(line)
      return true
    end
  end
  return false
end

Debug._sink = Debug._sink or DefaultSink

local function EnqueueLine(line, category)
  Debug._buffer = Debug._buffer or {}
  Debug._buffer[#Debug._buffer + 1] = {
    line = line,
    category = category,
  }
end

function Debug:FlushBuffered()
  self._buffer = self._buffer or {}
  if #self._buffer == 0 then
    return
  end

  local sink = self._sink or DefaultSink
  local remaining = {}
  for _, entry in ipairs(self._buffer) do
    local ok, delivered = pcall(sink, entry.line, entry.category)
    if not ok or delivered == false then
      remaining[#remaining + 1] = entry
    end
  end
  self._buffer = remaining
end

function Debug:SetSink(fn)
  if type(fn) == "function" then
    self._sink = fn
  else
    self._sink = DefaultSink
  end
  self:FlushBuffered()
end

local function Emit(category, text, force)
  if not force and not Debug.enabled then
    return
  end
  local categoryLabel = tostring(category or "GEN")
  local line = string.format("[%s] %s", categoryLabel, tostring(text or ""))

  Debug:FlushBuffered()
  local sink = Debug._sink or DefaultSink
  local ok, delivered = pcall(sink, line, categoryLabel)
  if not ok or delivered == false then
    EnqueueLine(line, categoryLabel)
  end

  if Debug.echoToChat then
    local chatLine = string.format("%s %s", PREFIX, line)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GuildLoot|r " .. chatLine)
    elseif GLD and GLD.Print then
      GLD:Print(chatLine)
    end
  end
end

function Debug:Print(category, fmt, ...)
  Emit(category, FormatMessage(fmt, ...), false)
end

function Debug:Verbose(category, fmt, ...)
  if (tonumber(self.level) or 1) < 2 then
    return
  end
  Emit(category, FormatMessage(fmt, ...), false)
end

function Debug:Once(key, category, fmt, ...)
  local token = tostring(key or "")
  if token == "" then
    self:Print(category, fmt, ...)
    return
  end
  self._once = self._once or {}
  if self._once[token] then
    return
  end
  self._once[token] = true
  self:Print(category, fmt, ...)
end

function Debug:Throttle(key, seconds, category, fmt, ...)
  local token = tostring(key or "")
  if token == "" then
    self:Print(category, fmt, ...)
    return
  end
  local interval = tonumber(seconds) or 0
  self._throttle = self._throttle or {}
  local now = Now()
  local last = self._throttle[token]
  if last and (now - last) < interval then
    return
  end
  self._throttle[token] = now
  self:Print(category, fmt, ...)
end

function Debug:Force(category, fmt, ...)
  Emit(category, FormatMessage(fmt, ...), true)
end

function Debug:SetEnabled(enabled)
  self.enabled = enabled == true
end

function Debug:SetLevel(level)
  self.level = tonumber(level) == 2 and 2 or 1
end

function Debug:SetEchoToChat(enabled)
  self.echoToChat = enabled == true
end

function Debug:GetEchoToChat()
  return self.echoToChat == true
end

function Debug:GetLevel()
  return tonumber(self.level) == 2 and 2 or 1
end

local function CountEntries(list)
  if type(list) ~= "table" then
    return 0
  end
  local count = 0
  for _ in pairs(list) do
    count = count + 1
  end
  return count
end

function GLD:DumpGuestAnchorState()
  local ui = self.UI
  local rosterWindowShown = ui and ui.mainFrame and ui.mainFrame.IsShown and ui.mainFrame:IsShown() or false
  local guestViewShown = ui and ui.guestPanel and ui.guestPanel.IsShown and ui.guestPanel:IsShown() or false
  local authorityAnchorCount = CountEntries(self.db and self.db.approvedGuests or nil)
  local providerCount = ui and ui.guestPanel and tonumber(ui.guestPanel.guestAnchorProviderCount) or nil
  if providerCount == nil then
    providerCount = self.guestAnchorCandidates and #self.guestAnchorCandidates or 0
  end
  Debug:Force(
    "GA_DUMP",
    "rosterWindowShown=%s guestViewShown=%s authorityDBAnchorCount=%d providerCount=%d",
    tostring(rosterWindowShown),
    tostring(guestViewShown),
    authorityAnchorCount,
    tonumber(providerCount) or 0
  )
end
