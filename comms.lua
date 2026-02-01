-- comms.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.Comms = ShortyRCD.Comms or {}

local Comms = ShortyRCD.Comms
Comms.PREFIX = "ShortyRCD" -- <= 16 chars

local function AllowedChannel()
  -- LFG / LFR
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  end

  -- Raid (non-LFG)
  if IsInRaid() then
    return "RAID"
  end

  -- 5-man party (manual group)
  if IsInGroup() then
    return "PARTY"
  end

  return nil
end


function Comms:Init()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
  end

  if not EventRegistry then
    ShortyRCD:Print("EventRegistry unavailable; comms disabled")
    return
  end

  EventRegistry:RegisterFrameEvent("CHAT_MSG_ADDON")
  EventRegistry:RegisterCallback("CHAT_MSG_ADDON", function(_, ...)
    self:OnAddonMessage(...)
  end, self)
end

function Comms:Send(msg)
  local ch = AllowedChannel()
  if not ch then
    ShortyRCD:Debug("TX blocked (not in RAID/INSTANCE)")
    return
  end
  C_ChatInfo.SendAddonMessage(self.PREFIX, msg, ch)
end

function Comms:BroadcastCast(spellID)
  if type(spellID) ~= "number" then return end
  self:Send("C|" .. tostring(spellID))
end

function Comms:OnAddonMessage(prefix, msg, channel, sender)
  if prefix ~= self.PREFIX then return end
  if channel ~= "RAID" and channel ~= "INSTANCE_CHAT" and channel ~= "PARTY" then return end

  local kind, spellIDStr = strsplit("|", msg or "", 2)
  if kind ~= "C" then return end

  local spellID = tonumber(spellIDStr)
  if not spellID then return end

  local entry = ShortyRCD.GetSpellEntry and ShortyRCD:GetSpellEntry(spellID) or nil
  if not entry then
    ShortyRCD:Debug(("RX ignored unknown spellID %s from %s"):format(tostring(spellIDStr), tostring(sender)))
    return
  end

  if ShortyRCD.Tracker and ShortyRCD.Tracker.OnRemoteCast then
    ShortyRCD.Tracker:OnRemoteCast(sender, spellID)
  end

  ShortyRCD:Debug(("RX %s cast %s (%d)"):format(tostring(sender), entry.name or "?", spellID))
end

-- Dev helper: simulate receiving a cast locally (no network).
-- Usage: /srcd inject <spellID>
function Comms:DevInjectCast(spellID, senderOverride)
  spellID = tonumber(spellID)
  if not spellID then
    ShortyRCD:Print("Inject usage: /srcd inject <spellID>")
    return
  end

  local sender = senderOverride
  if not sender then
    local name, realm = UnitFullName("player")
    if realm and realm ~= "" then sender = name .. "-" .. realm else sender = name end
  end

  -- Use RAID as a valid receive channel to exercise the real receive path.
  self:OnAddonMessage(self.PREFIX, "C|" .. tostring(spellID), "RAID", sender)
end