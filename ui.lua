-- ui.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.UI = ShortyRCD.UI or {}

local UI = ShortyRCD.UI

local function ShortName(nameWithRealm)
  if type(nameWithRealm) ~= "string" then return nameWithRealm end
  if Ambiguate then return Ambiguate(nameWithRealm, "short") end
  return (nameWithRealm:gsub("%-.*$", ""))
end

local function FormatTime(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  if sec >= 3600 then
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    return ("%dh%dm"):format(h, m)
  elseif sec >= 60 then
    local m = math.floor(sec / 60)
    local s = sec % 60
    return ("%dm%02ds"):format(m, s)
  else
    return ("%ds"):format(sec)
  end
end

function UI:Init()
  self.rows = {}
  self.classByName = {}
  self:CreateFrame()
  self:RestorePosition()
  self:ApplyLockState()
  self:RegisterRosterEvents()
  self:RefreshRoster()

  self.accum = 0
  self.frame:SetScript("OnUpdate", function(_, elapsed)
    self.accum = self.accum + elapsed
    if self.accum >= 0.10 then
      self.accum = 0
      self:UpdateRows()
    end
  end)
end

function UI:RegisterRosterEvents()
  if not EventRegistry then return end
  EventRegistry:RegisterFrameEvent("GROUP_ROSTER_UPDATE")
  EventRegistry:RegisterCallback("GROUP_ROSTER_UPDATE", function() self:RefreshRoster() end, self)

  EventRegistry:RegisterFrameEvent("PLAYER_ENTERING_WORLD")
  EventRegistry:RegisterCallback("PLAYER_ENTERING_WORLD", function() self:RefreshRoster() end, self)
end

function UI:RefreshRoster()
  wipe(self.classByName)

  local function AddUnit(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    if not name then return end
    local short = ShortName(name)
    local _, classToken = UnitClass(unit)
    if classToken then
      self.classByName[short] = classToken
    end
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      AddUnit("raid" .. i)
    end
  elseif IsInGroup() then
    AddUnit("player")
    for i = 1, GetNumSubgroupMembers() do
      AddUnit("party" .. i)
    end
  else
    AddUnit("player")
  end
end

function UI:GetClassColorForSender(senderShort)
  local classToken = self.classByName[senderShort]
  if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
    local c = RAID_CLASS_COLORS[classToken]
    return c.r, c.g, c.b
  end
  -- Neutral bluish-gray (Discord-ish)
  return 0.32, 0.36, 0.42
end

function UI:CreateFrame()
  if self.frame then return end

  local f = CreateFrame("Frame", "ShortyRCD_Frame", UIParent, "BackdropTemplate")
  f:SetSize(320, 190)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")

  -- Modern flat backdrop (dark)
  f:SetBackdrop({
    bgFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeFile = "Interface/ChatFrame/ChatFrameBackground",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  f:SetBackdropColor(0.07, 0.08, 0.10, 0.92)
  f:SetBackdropBorderColor(0.12, 0.13, 0.16, 1.0)

  -- Header strip
  local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -1, -1)
  header:SetHeight(34)
  header:SetBackdrop({
    bgFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeFile = "Interface/ChatFrame/ChatFrameBackground",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  })
  header:SetBackdropColor(0.05, 0.06, 0.08, 0.98)
  header:SetBackdropBorderColor(0.12, 0.13, 0.16, 1.0)

  local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", 10, 0)
  title:SetText("|cffffd000ShortyRCD|r")

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -6)
  sub:SetText("Raid cooldown tracker")

  f:SetScript("OnDragStart", function()
    if ShortyRCDDB.locked then return end
    f:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    UI:SavePosition()
  end)

  self.frame = f
  self.header = header
  self.sub = sub

  -- Container for rows
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8)
  list:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -60)
  list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)

  self.list = list
end

function UI:EnsureRow(i)
  if self.rows[i] then return self.rows[i] end

  local parent = self.list
  local rowH = 22
  local width = 300

  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(width, rowH)
  if i == 1 then
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  else
    r:SetPoint("TOPLEFT", self.rows[i-1], "BOTTOMLEFT", 0, -6)
  end

  -- Icon
  local icon = r:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", r, "LEFT", 0, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- Bar background
  local barBG = CreateFrame("Frame", nil, r, "BackdropTemplate")
  barBG:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  barBG:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  barBG:SetHeight(18)
  barBG:SetBackdrop({
    bgFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeFile = "Interface/ChatFrame/ChatFrameBackground",
    tile = true, tileSize = 16, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  barBG:SetBackdropColor(0.03, 0.03, 0.04, 0.95)
  barBG:SetBackdropBorderColor(0.14, 0.15, 0.18, 1.0)

  -- Status bar
  local bar = CreateFrame("StatusBar", nil, barBG)
  bar:SetPoint("TOPLEFT", barBG, "TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", barBG, "BOTTOMRIGHT", -1, 1)
  bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  -- Timer text (fixed width so it never overlaps)
  local timer = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  timer:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
  timer:SetJustifyH("RIGHT")
  timer:SetWidth(60)

  -- Label text (anchored to timer's left edge)
  local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", bar, "LEFT", 6, 0)
  label:SetPoint("RIGHT", timer, "LEFT", -8, 0)
  label:SetJustifyH("LEFT")

  r.icon = icon
  r.bar = bar
  r.label = label
  r.timer = timer
  r.barBG = barBG

  self.rows[i] = r
  return r
end

function UI:HideExtraRows(fromIndex)
  for i = fromIndex, #self.rows do
    self.rows[i]:Hide()
  end
end

function UI:UpdateRows()
  if not self.frame or not ShortyRCD.Tracker or not ShortyRCD.Tracker.GetRows then return end

  local rows = ShortyRCD.Tracker:GetRows()
  local maxRows = 6 -- keep it compact; can expand later

  local shown = math.min(#rows, maxRows)
  for i = 1, shown do
    local data = rows[i]
    local r = self:EnsureRow(i)

    local senderShort = ShortName(data.sender)
    local labelText = ("%s - %s"):format(senderShort or "?", data.spellName or ("Spell " .. tostring(data.spellID)))
    r.label:SetText(labelText)

    if data.iconID then
      r.icon:SetTexture(data.iconID)
    else
      r.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
    end

    local cr, cg, cb = self:GetClassColorForSender(senderShort)
    local isActive = data.isActive
    local total = isActive and (data.ac > 0 and data.ac or 1) or (data.cd > 0 and data.cd or 1)
    local remaining = isActive and data.activeRemaining or data.cooldownRemaining
    local progress = 1.0
    if total > 0 then
      progress = math.max(0, math.min(1, remaining / total))
    end

    r.bar:SetMinMaxValues(0, 1)
    r.bar:SetValue(progress)

    if isActive then
      r.bar:SetStatusBarColor(cr, cg, cb, 0.90)
      r.timer:SetText(FormatTime(remaining))
      r.timer:SetTextColor(0.90, 0.92, 0.96, 1.0)
      r.label:SetTextColor(0.90, 0.92, 0.96, 1.0)
    else
      -- Dimmed class color for cooldown rows
      r.bar:SetStatusBarColor(cr * 0.35, cg * 0.35, cb * 0.35, 0.85)
      r.timer:SetText(FormatTime(remaining))
      r.timer:SetTextColor(0.70, 0.72, 0.76, 1.0)
      r.label:SetTextColor(0.70, 0.72, 0.76, 1.0)
    end

    r:Show()
  end

  if shown == 0 and self.rows[1] then
    self:HideExtraRows(1)
  elseif shown < #self.rows then
    self:HideExtraRows(shown + 1)
  end
end

function UI:SavePosition()
  if not self.frame then return end
  local point, relTo, relPoint, x, y = self.frame:GetPoint(1)
  local relName = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
  ShortyRCDDB.frame.point = { point, relName, relPoint, x, y }
end

function UI:RestorePosition()
  if not self.frame then return end
  local p = ShortyRCDDB.frame.point
  if type(p) ~= "table" or #p < 5 then return end
  local rel = _G[p[2]] or UIParent
  self.frame:ClearAllPoints()
  self.frame:SetPoint(p[1], rel, p[3], p[4], p[5])
end

function UI:SetLocked(locked)
  ShortyRCDDB.locked = (locked == true)
  self:ApplyLockState()
end

function UI:ApplyLockState()
  if not self.frame then return end
  if ShortyRCDDB.locked then
    self.frame:EnableMouse(false)
  else
    self.frame:EnableMouse(true)
  end
end
