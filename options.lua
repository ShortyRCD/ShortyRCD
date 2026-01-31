-- options.lua
ShortyRCD = ShortyRCD or {}
ShortyRCD.Options = ShortyRCD.Options or {}

-- -------------------------------------------------
-- Helpers
-- -------------------------------------------------

local CLASS_ICON_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local function ClassColorText(classToken, text)
  local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]) or nil
  if c then
    return string.format("|cFF%02X%02X%02X%s|r", c.r * 255, c.g * 255, c.b * 255, text)
  end
  return text
end

local function PrettyType(t)
  t = tostring(t or ""):upper()
  if t == "DEFENSIVE" then return "Defensive" end
  if t == "HEALING"   then return "Healing" end
  if t == "UTILITY"   then return "Utility" end
  return "Other"
end

local function FormatCooldownSeconds(sec)
  sec = tonumber(sec) or 0
  if sec <= 0 then return "" end

  if sec < 60 then
    return string.format("%ds", sec)
  end

  if (sec % 60) == 0 then
    return string.format("%dm", sec / 60)
  end

  if (sec % 30) == 0 then
    return string.format("%.1fm", sec / 60)
  end

  return string.format("%ds", sec)
end

local function SetClassIcon(tex, classToken)
  if not tex then return end
  tex:SetTexture(CLASS_ICON_TEX)

  if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken] then
    local coords = CLASS_ICON_TCOORDS[classToken]
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  else
    tex:SetTexCoord(0, 1, 0, 1)
  end
end

local function CreateSpellIcon(parent, iconID)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(18, 18)
  t:SetPoint("LEFT", parent, "LEFT", 24, 0) -- after checkbox
  if iconID then t:SetTexture(iconID) end
  t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  return t
end

local function CreateLeftLabel(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", parent, "LEFT", 46, 0) -- after checkbox+icon
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  return fs
end

local function CreateRightTag(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
  fs:SetJustifyH("RIGHT")
  fs:SetText(text or "")
  return fs
end

local function CreateCheckboxRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(22)

  local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("LEFT", 0, 0)
  cb.Text:SetText("")
  row.checkbox = cb

  return row
end

local function NukeChildren(frame)
  if not frame or not frame.GetNumChildren then return end
  local children = { frame:GetChildren() }
  for _, child in ipairs(children) do
    child:Hide()
    child:SetParent(nil)
  end
end

local function GetClassOrder()
  -- Prefer the library’s explicit order, else derive from ClassDisplay keys
  if ShortyRCD.ClassOrder and #ShortyRCD.ClassOrder > 0 then
    return ShortyRCD.ClassOrder
  end

  local order = {}
  if ShortyRCD.ClassDisplay then
    for k in pairs(ShortyRCD.ClassDisplay) do
      table.insert(order, k)
    end
    table.sort(order)
  end
  return order
end

-- -------------------------------------------------
-- Options Panel
-- -------------------------------------------------

function ShortyRCD.Options:Init()
  self:CreatePanel()
  self:RegisterPanel()
end

function ShortyRCD.Options:Open()
  if not self.panel then return end

  if Settings and Settings.OpenToCategory and self.category then
    Settings.OpenToCategory(self.category:GetID())
    return
  end

  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(self.panel)
    InterfaceOptionsFrame_OpenToCategory(self.panel) -- quirk
    return
  end

  ShortyRCD:Print("Could not open options in this client build.")
end

function ShortyRCD.Options:CreatePanel()
  if self.panel then return end

  local p = CreateFrame("Frame", "ShortyRCDOptionsPanel", UIParent)
  p.name = "ShortyRCD"

  local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ShortyRCD")

  local subtitle = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  subtitle:SetText("Configure raid cooldown tracking. Use /srcd to open this page.")

  -- Frame controls
  local lockCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
  lockCB.Text:SetText("Lock display frame")
  lockCB:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
  lockCB:SetChecked(ShortyRCDDB.locked)

  lockCB:SetScript("OnClick", function(self)
    ShortyRCDDB.locked = self:GetChecked()
    if ShortyRCD.UI then ShortyRCD.UI:ApplyLockState() end
  end)

  local moveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  moveBtn:SetSize(120, 22)
  moveBtn:SetPoint("LEFT", lockCB.Text, "RIGHT", 14, 0)
  moveBtn:SetText("Move Frame")
  moveBtn:SetScript("OnClick", function()
    ShortyRCDDB.locked = false
    lockCB:SetChecked(false)
    if ShortyRCD.UI then ShortyRCD.UI:ApplyLockState() end
    ShortyRCD:Print("Frame unlocked. Drag it, then re-lock here.")
  end)

  -- Tracking header
  local trackingHeader = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  trackingHeader:SetPoint("TOPLEFT", lockCB, "BOTTOMLEFT", 2, -20)
  trackingHeader:SetText("Tracking")

  -- Scroll container
  local scrollFrame = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", trackingHeader, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 12)

  -- scrollChild (IMPORTANT: set width dynamically)
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(1, 1)
  scrollFrame:SetScrollChild(scrollChild)

  self.panel = p
  self.scrollFrame = scrollFrame
  self.scrollChild = scrollChild

  -- Rebuild list when panel is shown (ensures sizes are real)
  p:SetScript("OnShow", function()
    ShortyRCD.Options:RebuildTrackingList()
  end)

  -- Keep width correct if resized
  scrollFrame:SetScript("OnSizeChanged", function()
    ShortyRCD.Options:UpdateScrollChildWidth()
    -- Don’t rebuild every resize; just fix width
  end)
end

function ShortyRCD.Options:UpdateScrollChildWidth()
  if not self.scrollFrame or not self.scrollChild then return end
  local w = self.scrollFrame:GetWidth()
  if not w or w <= 0 then return end

  -- scrollbar takes space; give a little padding
  self.scrollChild:SetWidth(math.max(1, w - 28))
end

function ShortyRCD.Options:RebuildTrackingList()
  if not self.scrollChild then return end

  -- Fix width before building rows
  self:UpdateScrollChildWidth()

  -- Clear previous content
  NukeChildren(self.scrollChild)

  local y = -4
  local child = self.scrollChild
  local width = child:GetWidth()

  local classOrder = GetClassOrder()
  local classLib = ShortyRCD.ClassLib or {}

  local function AddClassBlock(classToken)
    local className = (ShortyRCD.ClassDisplay and ShortyRCD.ClassDisplay[classToken]) or classToken

    -- Header row (full width)
    local header = CreateFrame("Frame", nil, child)
    header:SetHeight(20)
    header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    header:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)

    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 0, 0)
    SetClassIcon(icon, classToken)

    local headerText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    headerText:SetText(ClassColorText(classToken, className))

    y = y - 22

    local spells = classLib[classToken] or {}
    if #spells == 0 then
      local none = child:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      none:SetPoint("TOPLEFT", child, "TOPLEFT", 24, y)
      none:SetText("(no raid cooldowns)")
      y = y - 18
      y = y - 8
      return
    end

    for _, s in ipairs(spells) do
      local row = CreateCheckboxRow(child)
      row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
      row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)

      local tracked = ShortyRCD:IsTracked(classToken, s.spellID)
      row.checkbox:SetChecked(tracked)

      row.checkbox:SetScript("OnClick", function(self)
        ShortyRCD:SetTracked(classToken, s.spellID, self:GetChecked())
      end)

      row.icon  = CreateSpellIcon(row, s.iconID)
      row.label = CreateLeftLabel(row, s.name or "Unknown Spell")

      local typeText = PrettyType(s.type)
      local cdText = FormatCooldownSeconds(s.cd)
      local tag = typeText
      if cdText ~= "" then
        tag = string.format("%s \226\128\162 %s", typeText, cdText) -- " • "
      end
      row.tag = CreateRightTag(row, tag)

      y = y - 24
    end

    y = y - 10
  end

  for _, classToken in ipairs(classOrder) do
    AddClassBlock(classToken)
  end

  -- Set total scroll height so scrolling works
  child:SetHeight(math.abs(y) + 40)
end

function ShortyRCD.Options:RegisterPanel()
  if not self.panel then return end

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(self.panel, self.panel.name)
    Settings.RegisterAddOnCategory(category)
    self.category = category
    return
  end

  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(self.panel)
  end
end
