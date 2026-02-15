local _, NS = ...

local GLD = NS.GLD

local LiveProvider = {}
NS.LiveProvider = LiveProvider

function LiveProvider:GetPlayers()
  return GLD.db and GLD.db.players or {}
end

function LiveProvider:GetPlayer(key)
  local players = self:GetPlayers()
  return players and players[key] or nil
end

function LiveProvider:GetPlayerKeyByName(name, realm)
  if GLD.FindPlayerKeyByName then
    return GLD:FindPlayerKeyByName(name, realm)
  end
  return nil
end

function LiveProvider:GetQueuePos(key)
  local player = self:GetPlayer(key)
  return player and player.queuePos or 99999
end

function LiveProvider:GetHeldPos(key)
  local player = self:GetPlayer(key)
  return player and player.savedPos or 0
end

function LiveProvider:GetPlayerName(key)
  if not key then
    return nil
  end
  local isGuid = type(key) == "string" and key:match("^Player%-") ~= nil
  local player = self:GetPlayer(key)
  if not player and isGuid and GLD and GLD.UpsertPlayerFromUnit and IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if UnitExists(unit) and UnitGUID(unit) == key then
        if GLD.IsTrackedRaidUnit and GLD:IsTrackedRaidUnit(unit) then
          local trackedKey = GLD.GetTrackedPlayerKeyForUnit and GLD:GetTrackedPlayerKeyForUnit(unit) or key
          if trackedKey and trackedKey ~= key then
            player = self:GetPlayer(trackedKey)
          else
            GLD:UpsertPlayerFromUnit(unit)
            player = self:GetPlayer(key)
          end
        end
        break
      end
    end
  end
  if player and player.name then
    if isGuid then
      return player.name
    end
    if player.realm and player.realm ~= "" then
      return player.name .. "-" .. player.realm
    end
    return player.name
  end
  return key
end

function LiveProvider:UpdateAward(key, itemContext)
  local player = self:GetPlayer(key)
  if not player then
    return
  end
  player.numAccepted = (player.numAccepted or 0) + 1
  player.lastWinAt = GetServerTime()
end
