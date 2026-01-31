-- ui.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.UI = ShortyRCD.UI or {}

function ShortyRCD.UI:Init()
  self:CreateFrame()
  self:CreateListArea()
  self:StartUpdateLoop()
  self:RestorePosition()
  self:ApplyLockState()
end

function ShortyRCD.UI:CreateFrame()
  if self.frame then return end

  local f = CreateFrame("Frame", "ShortyRCD_Frame", UIParent, "BackdropTemplate")
  f:SetSize(280, 140)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")

  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0, 0, 0, 0.80)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetText("ShortyRCD")

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Raid cooldown tracker")

  f:SetScript("OnDragStart", function()
    if ShortyRCDDB.locked then return end
    f:StartMoving()
  end)

  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    ShortyRCD.UI:SavePosition()
  end)

  self.frame = f
end

function ShortyRCD.UI:CreateListArea()
  if not self.frame or self.content then return end

  local content = CreateFrame("Frame", nil, self.frame)
  content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -50)
  content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)

  self.content = content
  self.bars = self.bars or {}
  self.maxBars = 12
  self.barHeight = 18
  self.barGap = 4
end

local function FormatTime(seconds)
  seconds = math.floor((seconds or 0) + 0.5)
  if seconds <= 0 then return "0s" end
  local m = math.floor(seconds / 60)
  local s = seconds % 60
  if m > 0 then
    return string.format("%dm%02ds", m, s)
  end
  return string.format("%ds", s)
end

function ShortyRCD.UI:EnsureBar(index)
  if self.bars[index] then return self.bars[index] end
  if not self.content then return nil end

  local bar = CreateFrame("Frame", nil, self.content)
  bar:SetHeight(self.barHeight)
  bar:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -((index - 1) * (self.barHeight + self.barGap)))
  bar:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -((index - 1) * (self.barHeight + self.barGap)))

  local icon = bar:CreateTexture(nil, "ARTWORK")
  icon:SetSize(self.barHeight, self.barHeight)
  icon:SetPoint("LEFT", bar, "LEFT", 0, 0)

  local status = CreateFrame("StatusBar", nil, bar)
  status:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  status:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  status:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
  status:SetHeight(self.barHeight)
  status:SetMinMaxValues(0, 1)
  status:SetValue(0)
  status:SetStatusBarColor(0.20, 0.70, 1.00, 0.90) -- active default

  local bg = status:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(status)
  bg:SetColorTexture(0, 0, 0, 0.35)

  local text = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", status, "LEFT", 6, 0)
  text:SetJustifyH("LEFT")

  local timer = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  timer:SetPoint("RIGHT", status, "RIGHT", -6, 0)
  timer:SetJustifyH("RIGHT")

  bar.icon = icon
  bar.status = status
  bar.text = text
  bar.timer = timer

  self.bars[index] = bar
  return bar
end

function ShortyRCD.UI:ClearUnusedBars(fromIndex)
  for i = fromIndex, #self.bars do
    local bar = self.bars[i]
    if bar then
      bar:Hide()
    end
  end
end

function ShortyRCD.UI:UpdateBars()
  if not (ShortyRCD.Tracker and ShortyRCD.Tracker.GetRows) then return end
  local rows = ShortyRCD.Tracker:GetRows()
  if not rows then return end

  local count = math.min(#rows, self.maxBars or 12)
  local neededHeight = 60 + count * (self.barHeight + self.barGap) + 14
  if self.frame and neededHeight > 140 then
    self.frame:SetHeight(neededHeight)
  end

  for i = 1, count do
    local row = rows[i]
    local bar = self:EnsureBar(i)
    if bar then
      bar:Show()

      -- Icon
      if row.iconID then
        bar.icon:SetTexture(row.iconID)
      else
        bar.icon:SetTexture(nil)
      end

      local label = string.format("%s - %s", row.sender, row.name or ("#" .. tostring(row.spellID)))
      bar.text:SetText(label)

      if row.isActive then
        local frac = 0
        if (row.ac or 0) > 0 then
          frac = (row.activeRemaining or 0) / row.ac
        end
        if frac < 0 then frac = 0 end
        if frac > 1 then frac = 1 end
        bar.status:SetMinMaxValues(0, 1)
        bar.status:SetValue(frac)
        bar.status:SetStatusBarColor(0.20, 0.70, 1.00, 0.90)
        bar.timer:SetText(FormatTime(row.activeRemaining))
      else
        local frac = 0
        if (row.cd or 0) > 0 then
          frac = (row.cooldownRemaining or 0) / row.cd
        end
        if frac < 0 then frac = 0 end
        if frac > 1 then frac = 1 end
        bar.status:SetMinMaxValues(0, 1)
        bar.status:SetValue(frac)
        bar.status:SetStatusBarColor(0.45, 0.45, 0.45, 0.85) -- cooldown gray
        bar.timer:SetText(FormatTime(row.cooldownRemaining))
      end
    end
  end

  self:ClearUnusedBars(count + 1)
end

function ShortyRCD.UI:StartUpdateLoop()
  if not self.frame then return end
  if self._updateLoopStarted then return end
  self._updateLoopStarted = true

  local accum = 0
  self.frame:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + (elapsed or 0)
    if accum < 0.10 then return end -- ~10fps update for timers
    accum = 0
    ShortyRCD.UI:UpdateBars()
  end)
end

function ShortyRCD.UI:SavePosition()
  if not self.frame then return end
  local point, relTo, relPoint, x, y = self.frame:GetPoint(1)
  local relName = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
  ShortyRCDDB.frame.point = { point, relName, relPoint, x, y }
  ShortyRCD:Debug(("Saved pos: %s %s %s %.1f %.1f"):format(point, relName, relPoint, x, y))
end

function ShortyRCD.UI:RestorePosition()
  if not self.frame then return end
  local p = ShortyRCDDB.frame.point
  if type(p) ~= "table" or #p < 5 then return end

  local rel = _G[p[2]] or UIParent
  self.frame:ClearAllPoints()
  self.frame:SetPoint(p[1], rel, p[3], p[4], p[5])
end

function ShortyRCD.UI:SetLocked(locked)
  ShortyRCDDB.locked = (locked == true)
  self:ApplyLockState()
end

function ShortyRCD.UI:ApplyLockState()
  if not self.frame then return end
  if ShortyRCDDB.locked then
    self.frame:EnableMouse(false) -- locked means not draggable
  else
    self.frame:EnableMouse(true)
  end
end
