-- Triage - Native Options Frame

local Triage = _G.Triage
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

local OptionsFrame = {}
Triage.OptionsFrame = OptionsFrame

local frame
local navButtons = {}
local activeSection = "general"
local rowControlCache = {}
local sectionHeaderRows = {}
local sectionDescriptionRows = {}
local headerDescriptionRows = {}
local settingsBridgeRegistered = false

local DEFAULT_WIDTH = 760
local DEFAULT_HEIGHT = 560
local MIN_WIDTH = 640
local MIN_HEIGHT = 420
local DEFAULT_OPACITY = 0.82
local NAV_WIDTH = 176
local NAV_BUTTON_HEIGHT = 28
local NAV_BUTTON_SPACING = 2
local CONTENT_INSET = 18
local SCROLL_SPACING = 6

local NAV_SELECTED_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local NAV_NORMAL_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local NAV_HOVER_COLOR = { r = 1.0, g = 0.93, b = 0.45 }

local DEFAULT_ROW_HEIGHTS = {
	header = 36,
	description = 24,
	checkbox = 32,
	button = 32,
	slider = 46,
	dropdown = 40,
	color = 34,
	editbox = 34,
	multiline = 190,
	status = 24,
}

local VALID_POINTS = {
	CENTER = true,
	TOP = true,
	BOTTOM = true,
	LEFT = true,
	RIGHT = true,
	TOPLEFT = true,
	TOPRIGHT = true,
	BOTTOMLEFT = true,
	BOTTOMRIGHT = true,
}

local function GetProfile()
	return Triage and Triage.db and Triage.db.profile
end

local function GetGeometry()
	local profile = GetProfile()
	if not profile then
		return nil
	end

	profile.optionsFrame = profile.optionsFrame or {}
	return profile.optionsFrame
end

local function Clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function GetOpacity()
	local geometry = GetGeometry()
	local opacity = geometry and tonumber(geometry.opacity)
	if not opacity then
		return DEFAULT_OPACITY
	end
	return Clamp(opacity, 0.2, 1)
end

local function ApplyOpacity()
	if frame then
		frame:SetAlpha(GetOpacity())
	end
end

local function SaveGeometry()
	if not frame then
		return
	end

	local geometry = GetGeometry()
	if not geometry then
		return
	end

	local point, _, relativePoint, x, y = frame:GetPoint(1)
	geometry.point = point or "CENTER"
	geometry.relativePoint = relativePoint or geometry.point
	geometry.x = x or 0
	geometry.y = y or 0
	geometry.width = frame:GetWidth()
	geometry.height = frame:GetHeight()
	geometry.opacity = GetOpacity()
	geometry.activeSection = activeSection
end

local function RestoreGeometry()
	if not frame then
		return
	end

	local geometry = GetGeometry()
	frame:ClearAllPoints()

	local width = geometry and tonumber(geometry.width)
	local height = geometry and tonumber(geometry.height)
	frame:SetSize(math.max(width or DEFAULT_WIDTH, MIN_WIDTH), math.max(height or DEFAULT_HEIGHT, MIN_HEIGHT))

	local point = geometry and geometry.point
	local relativePoint = geometry and (geometry.relativePoint or point)
	if point and VALID_POINTS[point] and relativePoint and VALID_POINTS[relativePoint] then
		local ok = pcall(frame.SetPoint, frame, point, UIParent, relativePoint, geometry.x or 0, geometry.y or 0)
		if not ok then
			frame:SetPoint("CENTER")
		end
	else
		frame:SetPoint("CENTER")
	end

	if geometry and type(geometry.activeSection) == "string" then
		activeSection = geometry.activeSection
	end
	if geometry then
		geometry.opacity = GetOpacity()
	end
	ApplyOpacity()
end

local function GetRowHeight(row)
	if row and row.height then
		return row.height
	end
	return (row and DEFAULT_ROW_HEIGHTS[row.type]) or DEFAULT_ROW_HEIGHTS.checkbox
end

local function IsRowVisible(row)
	if not row then
		return false
	end
	if row.hidden then
		return not row.hidden()
	end
	return true
end

local function GetSectionHeaderRow(section)
	if not section or not section.key then
		return nil
	end

	local row = sectionHeaderRows[section.key]
	if not row then
		row = {
			key = section.key .. "Header",
			type = "header",
		}
		sectionHeaderRows[section.key] = row
	end

	row.label = section.label or section.key
	return row
end

local function GetSectionDescriptionRow(section)
	if not section or not section.key or not section.description then
		return nil
	end

	local row = sectionDescriptionRows[section.key]
	if not row then
		row = {
			key = section.key .. "Description",
			type = "description",
		}
		sectionDescriptionRows[section.key] = row
	end

	row.label = section.description
	row.height = 24
	return row
end

local function GetHeaderDescriptionRow(row)
	if not row or not row.key or not row.description then
		return nil
	end

	local descriptionRow = headerDescriptionRows[row]
	if not descriptionRow then
		descriptionRow = {
			key = row.key .. "Description",
			type = "description",
			height = 24,
		}
		headerDescriptionRows[row] = descriptionRow
	end

	descriptionRow.label = row.description
	return descriptionRow
end

local function ClearRenderedChild(rowFrame)
	local child = rowFrame.triageOptionsChild
	if not child then
		return
	end

	child:Hide()
	child:ClearAllPoints()
	child:SetParent(nil)
	child.triageOwnerRowFrame = nil
	rowFrame.triageOptionsChild = nil
end

local function AttachRenderedChild(rowFrame, child, height)
	if not child then
		return
	end

	if child.triageOwnerRowFrame and child.triageOwnerRowFrame ~= rowFrame then
		child.triageOwnerRowFrame.triageOptionsChild = nil
	end

	child:SetParent(rowFrame)
	child:ClearAllPoints()
	child:SetAllPoints(rowFrame)
	child:SetHeight(height)
	if child.triageRefresh then
		child:triageRefresh()
	end
	child:Show()
	rowFrame.triageOptionsChild = child
	child.triageOwnerRowFrame = rowFrame
end

local function GetCachedControl(row)
	return row and rowControlCache[row]
end

local function CacheControl(row, child)
	if row and child then
		rowControlCache[row] = child
	end
end

local function ApplyNavButtonState(button, isActive)
	if not button then
		return
	end

	button.isActive = isActive and true or false

	if button.selectedTexture then
		button.selectedTexture:SetShown(button.isActive)
	end
	if button.leftAccent then
		button.leftAccent:SetShown(button.isActive)
	end
	if button.text then
		local color = button.isActive and NAV_SELECTED_COLOR or NAV_NORMAL_COLOR
		button.text:SetTextColor(color.r, color.g, color.b)
	end
end

local function UpdateNavButtons()
	for _, button in ipairs(navButtons) do
		local isActive = button.sectionKey == activeSection
		button:SetEnabled(true)
		ApplyNavButtonState(button, isActive)
	end
end

local function CreateNavButton(parent, section, index)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(NAV_WIDTH, NAV_BUTTON_HEIGHT)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (NAV_BUTTON_HEIGHT + NAV_BUTTON_SPACING)))
	button.sectionKey = section.key

	button.backgroundTexture = button:CreateTexture(nil, "BACKGROUND")
	button.backgroundTexture:SetAllPoints(button)
	button.backgroundTexture:SetColorTexture(0.02, 0.02, 0.02, 0.46)

	button.selectedTexture = button:CreateTexture(nil, "BORDER")
	button.selectedTexture:SetAllPoints(button)
	button.selectedTexture:SetColorTexture(0.33, 0.28, 0.09, 0.42)
	button.selectedTexture:Hide()

	button.leftAccent = button:CreateTexture(nil, "ARTWORK")
	button.leftAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -3)
	button.leftAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 3)
	button.leftAccent:SetWidth(2)
	button.leftAccent:SetColorTexture(1.0, 0.82, 0.0, 0.82)
	button.leftAccent:Hide()

	button.hoverTexture = button:CreateTexture(nil, "HIGHLIGHT")
	button.hoverTexture:SetAllPoints(button)
	button.hoverTexture:SetColorTexture(1.0, 0.82, 0.0, 0.12)

	button.text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	button.text:SetPoint("LEFT", button, "LEFT", 14, 0)
	button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
	button.text:SetJustifyH("LEFT")
	button.text:SetText(section.label or section.key or "")

	button:SetScript("OnEnter", function(self)
		if self.text then
			self.text:SetTextColor(NAV_HOVER_COLOR.r, NAV_HOVER_COLOR.g, NAV_HOVER_COLOR.b)
		end
	end)
	button:SetScript("OnLeave", function(self)
		ApplyNavButtonState(self, self.isActive)
	end)
	button:SetScript("OnClick", function(self)
		OptionsFrame:ShowSection(self.sectionKey)
	end)

	ApplyNavButtonState(button, section.key == activeSection)
	navButtons[index] = button
end

local function AddDragHandling(targetFrame, ownerFrame)
	if not targetFrame then
		return
	end

	targetFrame:EnableMouse(true)
	targetFrame:RegisterForDrag("LeftButton")
	targetFrame:SetScript("OnDragStart", function()
		ownerFrame:StartMoving()
	end)
	targetFrame:SetScript("OnDragStop", function()
		ownerFrame:StopMovingOrSizing()
		SaveGeometry()
	end)
end

local function CreateTitleHitBox(ownerFrame)
	local titleHitBox = CreateFrame("Frame", nil, ownerFrame)
	titleHitBox:SetPoint("TOPLEFT", ownerFrame, "TOPLEFT", 10, -2)
	titleHitBox:SetPoint("TOPRIGHT", ownerFrame, "TOPRIGHT", -30, -2)
	titleHitBox:SetHeight(24)
	return titleHitBox
end

local function SetTitle(ownerFrame)
	local title = L["Triage"] or "Triage"
	if ownerFrame.TitleContainer and ownerFrame.TitleContainer.TitleText then
		ownerFrame.TitleContainer.TitleText:SetText(title)
		return
	end

	ownerFrame.titleText = ownerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	ownerFrame.titleText:SetPoint("TOP", ownerFrame, "TOP", 0, -7)
	ownerFrame.titleText:SetText(title)
end

local function CreateResizeHandle(ownerFrame)
	ownerFrame:SetResizable(true)
	if ownerFrame.SetResizeBounds then
		ownerFrame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
	end

	local handle = CreateFrame("Button", nil, ownerFrame)
	handle:SetPoint("BOTTOMRIGHT", ownerFrame, "BOTTOMRIGHT", -6, 6)
	handle:SetSize(16, 16)
	handle:EnableMouse(true)
	handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	handle:SetScript("OnMouseDown", function()
		ownerFrame:StartSizing("BOTTOMRIGHT")
	end)
	handle:SetScript("OnMouseUp", function()
		ownerFrame:StopMovingOrSizing()
		SaveGeometry()
	end)
	ownerFrame.resizeHandle = handle
end

local function CreateShell()
	local ownerFrame = CreateFrame("Frame", "TriageOptionsFrame", UIParent, "DefaultPanelTemplate")
	ownerFrame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
	ownerFrame:SetPoint("CENTER")
	ownerFrame:SetFrameStrata("HIGH")
	ownerFrame:SetToplevel(true)
	ownerFrame:SetMovable(true)
	ownerFrame:EnableMouse(true)
	ownerFrame:SetClampedToScreen(true)
	ownerFrame:Hide()

	SetTitle(ownerFrame)

	local closeButton = CreateFrame("Button", nil, ownerFrame, "UIPanelCloseButtonDefaultAnchors")
	closeButton:SetScript("OnClick", function()
		ownerFrame:Hide()
	end)
	ownerFrame.closeButton = closeButton

	AddDragHandling(ownerFrame.TitleContainer or CreateTitleHitBox(ownerFrame), ownerFrame)
	CreateResizeHandle(ownerFrame)

	local content = CreateFrame("Frame", nil, ownerFrame)
	content:SetPoint("TOPLEFT", ownerFrame, "TOPLEFT", CONTENT_INSET, -38)
	content:SetPoint("BOTTOMRIGHT", ownerFrame, "BOTTOMRIGHT", -CONTENT_INSET, CONTENT_INSET)
	ownerFrame.content = content

	local nav = CreateFrame("Frame", nil, content)
	nav:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -8)
	nav:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 8)
	nav:SetWidth(NAV_WIDTH)
	ownerFrame.nav = nav

	local navInset = CreateFrame("Frame", nil, content, "InsetFrameTemplate")
	navInset:SetPoint("TOPLEFT", nav, "TOPLEFT", -4, 4)
	navInset:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 4, -4)
	ownerFrame.navInset = navInset

	local navDivider = content:CreateTexture(nil, "ARTWORK")
	navDivider:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
	navDivider:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 10, 0)
	navDivider:SetWidth(1)
	navDivider:SetColorTexture(0.68, 0.6, 0.42, 0.28)
	ownerFrame.navDivider = navDivider

	local scrollBar = CreateFrame("EventFrame", nil, content, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -8)
	scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 8)
	ownerFrame.scrollBar = scrollBar

	local contentInset = CreateFrame("Frame", nil, content, "InsetFrameTemplate")
	contentInset:SetPoint("TOPLEFT", nav, "TOPRIGHT", 18, 4)
	contentInset:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -2, -4)
	ownerFrame.contentInset = contentInset

	local scrollBox = CreateFrame("Frame", nil, content, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", nav, "TOPRIGHT", 26, 0)
	scrollBox:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -10, 0)
	ownerFrame.scrollBox = scrollBox

	local createView = rawget(_G, "CreateScrollBoxListLinearView")
	local scrollUtil = rawget(_G, "ScrollUtil")
	local view = createView(0, 0, 0, 0, SCROLL_SPACING)
	view:SetElementExtentCalculator(function(_, row)
		return GetRowHeight(row)
	end)
	view:SetElementFactory(function(factory, row)
		factory("Frame", function(rowFrame)
			OptionsFrame:RenderRow(rowFrame, row)
		end)
	end)
	scrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	ownerFrame.view = view

	local model = Triage.OptionsModel
	if model and model.GetSections then
		for index, section in ipairs(model:GetSections() or {}) do
			CreateNavButton(nav, section, index)
		end
	end

	ownerFrame:HookScript("OnHide", SaveGeometry)
	return ownerFrame
end

local function CreateSettingsPanel()
	local panel = OptionsFrame.settingsPanel
	if panel then
		return panel
	end

	panel = CreateFrame("Frame", "TriageSettingsPanel")
	panel.name = "Triage"

	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	label:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	label:SetText("Triage")
	panel.label = label

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(200, 24)
	button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -16)
	button:SetText("Open Triage Options")
	button:SetScript("OnClick", function()
		OptionsFrame:Open()
	end)
	panel.openButton = button

	OptionsFrame.settingsPanel = panel
	return panel
end

local function RegisterSettingsBridge()
	if settingsBridgeRegistered then
		return
	end

	local panel = CreateSettingsPanel()

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local categoryOk, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Triage")
		if categoryOk and category then
			local addonOk = pcall(Settings.RegisterAddOnCategory, category)
			if addonOk then
				OptionsFrame.settingsCategory = category
				settingsBridgeRegistered = true
				return
			end
		end
	end

	local addCategory = rawget(_G, "InterfaceOptions_AddCategory")
	if addCategory then
		local legacyOk = pcall(addCategory, panel)
		if legacyOk then
			settingsBridgeRegistered = true
		end
	end
end

function OptionsFrame:Initialize()
	if not frame then
		frame = CreateShell()
	end

	RegisterSettingsBridge()
	return frame
end

function OptionsFrame:Open(sectionKey)
	self:Initialize()
	RestoreGeometry()
	frame:Show()
	frame:Raise()
	self:ShowSection(sectionKey or activeSection)
end

function OptionsFrame:Toggle(sectionKey)
	if self:IsShown() then
		frame:Hide()
	else
		self:Open(sectionKey)
	end
end

function OptionsFrame:Hide()
	if frame then
		frame:Hide()
	end
end

function OptionsFrame:IsShown()
	return frame and frame:IsShown() and true or false
end

function OptionsFrame:ShowSection(sectionKey)
	self:Initialize()

	local model = Triage.OptionsModel
	if not model or not model.GetSection then
		return
	end

	local section = model:GetSection(sectionKey or activeSection)
	if not section then
		return
	end

	activeSection = section.key or activeSection
	UpdateNavButtons()

	local createDataProvider = rawget(_G, "CreateDataProvider")
	local dataProvider = createDataProvider()
	local sectionHeader = GetSectionHeaderRow(section)
	if sectionHeader then
		dataProvider:Insert(sectionHeader)
	end
	local sectionDescription = GetSectionDescriptionRow(section)
	if sectionDescription then
		dataProvider:Insert(sectionDescription)
	end
	for _, row in ipairs(section.rows or {}) do
		if IsRowVisible(row) then
			dataProvider:Insert(row)
			local headerDescription = GetHeaderDescriptionRow(row)
			if headerDescription then
				dataProvider:Insert(headerDescription)
			end
		end
	end

	frame.scrollBox:SetDataProvider(dataProvider)
end

function OptionsFrame:Refresh()
	if frame then
		self:ShowSection(activeSection)
		ApplyOpacity()
	end
end

function OptionsFrame:RenderRow(rowFrame, row)
	local controls = Triage.OptionsControls
	if not controls or not row then
		ClearRenderedChild(rowFrame)
		return
	end

	local height = GetRowHeight(row)
	rowFrame:SetHeight(height)

	local child = GetCachedControl(row)
	if not child then
		if row.type == "header" then
			child = controls.CreateHeader(rowFrame, row)
		elseif row.type == "description" then
			child = controls.CreateDescription(rowFrame, row)
		elseif row.type == "checkbox" then
			child = controls.CreateCheckbox(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "button" then
			child = controls.CreateButton(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "slider" then
			child = controls.CreateSlider(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "dropdown" then
			child = controls.CreateDropdown(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "color" then
			child = controls.CreateColor(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "editbox" then
			child = controls.CreateEditBox(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "multiline" then
			child = controls.CreateMultiline(rowFrame, row, function() OptionsFrame:Refresh() end)
		elseif row.type == "status" then
			child = controls.CreateStatus(rowFrame, row)
		end

		CacheControl(row, child)
	end

	ClearRenderedChild(rowFrame)
	AttachRenderedChild(rowFrame, child, height)
end

return OptionsFrame
