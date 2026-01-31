-- tracker.lua
-- Stores per-sender cooldown state. ClassLib provides cd/ac/icon/name.

ShortyRCD = ShortyRCD or {}
ShortyRCD.Tracker = ShortyRCD.Tracker or {}

-- timers[sender][spellID] = { startedAt=<time>, cd=<sec>, ac=<sec> }

function ShortyRCD.Tracker:Init()
  self.timers = self.timers or {}
end

local function Now()
  return (GetTime and GetTime()) or 0
end

local function EnsureSender(timers, sender)
  local t = timers[sender]
  if not t then
    t = {}
    timers[sender] = t
  end
  return t
end

-- Called for both true comms and dev injection.
function ShortyRCD.Tracker:OnRemoteCast(sender, spellID)
  if not sender or sender == "" then return end
  if type(spellID) ~= "number" then return end

  local entry = (ShortyRCD.GetSpellEntry and ShortyRCD:GetSpellEntry(spellID)) or nil
  if not entry then return end

  local startedAt = Now()
  local cd = tonumber(entry.cd) or 0
  local ac = tonumber(entry.ac) or 0

  local st = EnsureSender(self.timers, sender)
  st[spellID] = {
    startedAt = startedAt,
    cd = cd,
    ac = ac,
  }
end


-- Clears cooldowns that reset on encounter end (roe == true in ClassLib).
function ShortyRCD.Tracker:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
  -- We intentionally do not broadcast anything here.
  -- Each client receives ENCOUNTER_END and can clear ROE timers locally.
  if not self.timers then return end

  for sender, spells in pairs(self.timers) do
    for spellID, t in pairs(spells) do
      local entry = (ShortyRCD.GetSpellEntry and ShortyRCD:GetSpellEntry(spellID)) or nil
      if entry and entry.roe == true then
        spells[spellID] = nil
      end
    end
    if next(spells) == nil then
      self.timers[sender] = nil
    end
  end
end

function ShortyRCD.Tracker:SweepExpired()
  local now = Now()

  for sender, spells in pairs(self.timers) do
    local senderEmpty = true

    for spellID, t in pairs(spells) do
      local cd = t.cd or 0
      local endsAt = (t.startedAt or 0) + cd

      if cd <= 0 or now >= endsAt then
        spells[spellID] = nil
      else
        senderEmpty = false
      end
    end

    if senderEmpty then
      self.timers[sender] = nil
    end
  end
end

-- Returns a flat, sorted list for UI rendering.
function ShortyRCD.Tracker:GetRows()
  self:SweepExpired()

  local rows = {}
  local now = Now()

  for sender, spells in pairs(self.timers) do
    for spellID, t in pairs(spells) do
      local entry = (ShortyRCD.GetSpellEntry and ShortyRCD:GetSpellEntry(spellID)) or nil
      if entry then
        local startedAt = t.startedAt or 0
        local cd = t.cd or 0
        local ac = t.ac or 0

        local activeEnds = startedAt + ac
        local cdEnds = startedAt + cd

        local activeRem = activeEnds - now
        if activeRem < 0 then activeRem = 0 end

        local cdRem = cdEnds - now
        if cdRem < 0 then cdRem = 0 end

        if cdRem > 0 or activeRem > 0 then
          rows[#rows + 1] = {
            sender = sender,
            spellID = spellID,
            name = entry.name,
            iconID = entry.iconID,
            type = entry.type,
            startedAt = startedAt,
            cd = cd,
            ac = ac,
            activeRemaining = activeRem,
            cooldownRemaining = cdRem,
            isActive = (activeRem > 0),
          }
        end
      end
    end
  end

  table.sort(rows, function(a, b)
    if a.isActive ~= b.isActive then
      return a.isActive and (not b.isActive) -- active first
    end
    if a.sender ~= b.sender then
      return a.sender < b.sender
    end
    return a.spellID < b.spellID
  end)

  return rows
end
