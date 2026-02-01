-- comms.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.Comms = ShortyRCD.Comms or {}

local Comms = ShortyRCD.Comms
Comms.PREFIX = "ShortyRCD" -- <= 16 chars

-- Prefer ChatThrottleLib if present (recommended by Blizzard docs / best practice)
local CTL = _G.ChatThrottleLib

local function AllowedChannel()
  -- Works in:
  --  * LFG / LFR / Instance groups  -> INSTANCE_CHAT
  --  * Raid groups                  -> RAID
  --  * Premade / normal parties     -> PARTY (this includes Mythic+ premade parties)
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
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

local function SendAddon(prefix, msg, chatType, target)
  if CTL and CTL.SendAddonMessage then
    -- priority: "NORMAL" is fine for small messages; CTL will throttle safely
    CTL:SendAddonMessage("NORMAL", prefix, msg, chatType, target)
    return true
  end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    return C_ChatInfo.SendAddonMessage(prefix, msg, chatType, target)
  end
  return false
end

function Comms:Send(msg)
  local ch = AllowedChannel()
  if not ch then
    ShortyRCD:Debug("TX blocked (not in RAID/PARTY/INSTANCE)")
    return
  end

  local ok = SendAddon(self.PREFIX, msg, ch)
  if not ok then
    ShortyRCD:Debug(("TX failed (%s) msg=%s"):format(tostring(ch), tostring(msg)))
  end
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

  local entry = (ShortyRCD.GetSpellEntry and ShortyRCD:GetSpellEntry(spellID)) or nil
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
    sender = (realm and realm ~= "") and (name .. "-" .. realm) or name
  end

  -- Use PARTY as a valid receive channel to exercise the real receive path.
  self:OnAddonMessage(self.PREFIX, "C|" .. tostring(spellID), "PARTY", sender)
end
