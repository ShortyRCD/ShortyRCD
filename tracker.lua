-- tracker.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.Tracker = ShortyRCD.Tracker or {}

function ShortyRCD.Tracker:Init()
  self.timers = {} -- sender -> spellID -> {start, dur, ends}
end

-- Later:
-- function ShortyRCD.Tracker:Start(sender, spellID, startTime, duration) ... end
-- function ShortyRCD.Tracker:GetRemaining(sender, spellID) ... end
