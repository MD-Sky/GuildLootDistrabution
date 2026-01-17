local _, NS = ...

local GLD = NS.GLD

local SAMPLE_PLAYERS = {
  { name = "Aeryn", class = "MAGE", attendance = "PRESENT" },
  { name = "Bram", class = "WARRIOR", attendance = "PRESENT" },
  { name = "Cyra", class = "PRIEST", attendance = "PRESENT" },
  { name = "Dho", class = "HUNTER", attendance = "PRESENT" },
  { name = "Elra", class = "DRUID", attendance = "PRESENT" },
  { name = "Fenn", class = "PALADIN", attendance = "PRESENT" },
  { name = "Gorr", class = "SHAMAN", attendance = "ABSENT" },
  { name = "Hela", class = "ROGUE", attendance = "ABSENT" },
  { name = "Iris", class = "WARLOCK", attendance = "PRESENT" },
  { name = "Jace", class = "DEMONHUNTER", attendance = "PRESENT" },
}

function GLD:SeedTestData()
  local realm = GetRealmName()

  self.db.players = {}
  self.db.queue = {}

  for i, data in ipairs(SAMPLE_PLAYERS) do
    local key = data.name .. "-" .. realm
    self.db.players[key] = {
      name = data.name,
      realm = realm,
      class = data.class,
      attendance = data.attendance,
      queuePos = nil,
      savedPos = nil,
      numAccepted = math.max(0, i - 5),
      lastWinAt = 0,
      isHonorary = false,
      attendanceCount = math.max(0, i - 3),
      source = "test",
    }
    if data.attendance == "PRESENT" then
      table.insert(self.db.queue, key)
    else
      self.db.players[key].savedPos = i
    end
  end

  self:CompactQueue()

  local roster = {}
  for _, key in ipairs(self.db.queue) do
    local player = self.db.players[key]
    if player then
      table.insert(roster, {
        key = key,
        name = player.name,
        class = player.class,
        queuePos = player.queuePos,
        attendance = player.attendance,
        role = "NONE",
      })
    end
  end

  for key, player in pairs(self.db.players) do
    if player.attendance == "ABSENT" then
      table.insert(roster, {
        key = key,
        name = player.name,
        class = player.class,
        queuePos = player.queuePos,
        attendance = player.attendance,
        role = "NONE",
      })
    end
  end

  self.shadow.roster = roster
  self.shadow.my.queuePos = 1
  self.shadow.my.attendance = "PRESENT"

  self:BroadcastSnapshot()
  if self.UI then
    self.UI:RefreshMain()
  end
  self:Print("Test data seeded")
end
