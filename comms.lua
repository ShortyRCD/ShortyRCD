-- comms.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.Comms = ShortyRCD.Comms or {}

ShortyRCD.Comms.PREFIX = "ShortyRCD" -- <= 16 chars

function ShortyRCD.Comms:Init()
  self:RegisterPrefix()
  self:RegisterEvents()
end

function ShortyRCD.Comms:RegisterPrefix()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
  end
end

function ShortyRCD.Comms:GetBestChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
  return nil
end

function ShortyRCD.Comms:Send(msg)
  local ch = self:GetBestChannel()
  if not ch then return end
  C_ChatInfo.SendAddonMessage(self.PREFIX, msg, ch)
end

function ShortyRCD.Comms:OnAddonMessage(prefix, msg, channel, sender)
  if prefix ~= self.PREFIX then return end
  -- Later: parse spellID|t|dur and pass to Tracker
  -- ShortyRCD.Tracker:OnRemoteCast(sender, spellID, t, dur)
end

function ShortyRCD.Comms:RegisterEvents()
  local f = CreateFrame("Frame")
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      self:OnAddonMessage(...)
    end
  end)
  self.eventFrame = f
end
