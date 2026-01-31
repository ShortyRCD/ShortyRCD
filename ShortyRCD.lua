-- ShortyRCD.lua (core/glue)

local ADDON_NAME = ...
ShortyRCD = ShortyRCD or {}
ShortyRCD.ADDON_NAME = ADDON_NAME
ShortyRCD.VERSION = "0.1.0"

ShortyRCDDB = ShortyRCDDB or nil

ShortyRCD.DEFAULTS = {
  debug = false,
  locked = false,
  frame = {
    point = { "CENTER", "UIParent", "CENTER", 0, 0 },
  },
  tracking = {
    -- Populated lazily: tracking[classToken][spellID] = true/false
  }
}

-- ---------- Utils ----------
local function DeepCopy(src)
  if type(src) ~= "table" then return src end
  local dst = {}
  for k, v in pairs(src) do dst[k] = DeepCopy(v) end
  return dst
end

local function ApplyDefaults(dst, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      dst[k] = dst[k] or {}
      ApplyDefaults(dst[k], v)
    else
      if dst[k] == nil then dst[k] = v end
    end
  end
end

function ShortyRCD:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ShortyRCD|r " .. tostring(msg))
end

function ShortyRCD:Debug(msg)
  if ShortyRCDDB and ShortyRCDDB.debug then
    self:Print("|cff999999" .. tostring(msg) .. "|r")
  end
end

-- ---------- DB helpers ----------
function ShortyRCD:InitDB()
  if type(ShortyRCDDB) ~= "table" then
    ShortyRCDDB = DeepCopy(self.DEFAULTS)
  else
    ApplyDefaults(ShortyRCDDB, self.DEFAULTS)
  end
end

function ShortyRCD:IsTracked(classToken, spellID)
  if not ShortyRCDDB or not ShortyRCDDB.tracking then return true end
  if not classToken or not spellID then return false end

  -- Default behavior: tracked unless explicitly disabled
  local classTbl = ShortyRCDDB.tracking[classToken]
  if not classTbl then return true end
  local v = classTbl[spellID]
  if v == nil then return true end
  return v == true
end

function ShortyRCD:SetTracked(classToken, spellID, isTracked)
  ShortyRCDDB.tracking[classToken] = ShortyRCDDB.tracking[classToken] or {}
  ShortyRCDDB.tracking[classToken][spellID] = (isTracked == true)
end

-- ---------- Slash ----------
local function OpenOptions()
  if ShortyRCD and ShortyRCD.Options and ShortyRCD.Options.Open then
    ShortyRCD.Options:Open()
  else
    ShortyRCD:Print("Options module not ready yet.")
  end
end

local function SlashHandler(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" or msg == "options" then
    OpenOptions()
    return
  end
  if msg == "debug" then
    ShortyRCDDB.debug = not ShortyRCDDB.debug
    ShortyRCD:Print("Debug: " .. tostring(ShortyRCDDB.debug))
    return
  end
  ShortyRCD:Print("Usage: /srcd  (opens options) | /srcd debug")
end

-- ---------- Init ----------
function ShortyRCD:OnLogin()
  self:InitDB()

  -- Initialize subsystems (each module attaches itself if loaded)
  if self.Tracker and self.Tracker.Init then self.Tracker:Init() end
  if self.Comms and self.Comms.Init then self.Comms:Init() end
  if self.UI and self.UI.Init then self.UI:Init() end
  if self.Options and self.Options.Init then self.Options:Init() end

  -- Slash command
  SLASH_SHORTYRCD1 = "/srcd"
  SlashCmdList["SHORTYRCD"] = SlashHandler

  self:Print("Loaded v" .. self.VERSION .. ". Type /srcd")
end

-- ---------- Event frame ----------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    ShortyRCD:OnLogin()
  end
end)
