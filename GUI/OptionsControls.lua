-- Triage - Native Options Controls

local Triage = _G.Triage

local Controls = {}
Triage.OptionsControls = Controls

local ROW_HEIGHT = 32
local HEADER_HEIGHT = 36
local DESCRIPTION_HEIGHT = 24
local SLIDER_HEIGHT = 46
local DROPDOWN_HEIGHT = 40
local COLOR_HEIGHT = 34
local EDIT_HEIGHT = 34
local MULTILINE_HEIGHT = 190
local STATUS_HEIGHT = 24

local LEFT_WIDTH = 260
local RIGHT_WIDTH = 300
local CONTROL_GAP = 14
local CONTROL_RIGHT_PADDING = 36

local function GetTooltip()
	local tooltip = rawget(_G, "TriageOptionsTooltip")
	if not tooltip then
		tooltip = CreateFrame("GameTooltip", "TriageOptionsTooltip", UIParent, "GameTooltipTemplate")
	end
	return tooltip
end

local function SetRowHeight(frame, height)
	frame:SetHeight(height)
	frame:SetSize(LEFT_WIDTH + RIGHT_WIDTH + CONTROL_GAP, height)
end

local function SafeGet(row, defaultValue)
	if row.get then
		local value = row.get()
		if value ~= nil then
			return value
		end
	end
	return defaultValue
end

local function IsDisabled(row)
	if row and row.disabled then
		return row.disabled() and true or false
	end
	return false
end

local function SetControlEnabled(control, enabled)
	if not control then
		return
	end
	if enabled and control.Enable then
		control:Enable()
	elseif not enabled and control.Disable then
		control:Disable()
	end
end

local function Clamp(value, minValue, maxValue)
	if minValue and value < minValue then
		return minValue
	end
	if maxValue and value > maxValue then
		return maxValue
	end
	return value
end

local function RoundToStep(value, minValue, step)
	if not step or step <= 0 then
		return value
	end

	local origin = minValue or 0
	return origin + math.floor(((value - origin) / step) + 0.5) * step
end

local function FormatValue(row, value)
	if row.isPercent then
		return tostring(math.floor((value * 100) + 0.5)) .. "%"
	end
	if math.floor(value) == value then
		return tostring(value)
	end
	return string.format("%.2f", value)
end

local function CreateLabel(parent, row)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", parent, "LEFT", 0, 0)
	label:SetWidth(LEFT_WIDTH)
	label:SetJustifyH("LEFT")
	label:SetText(row.label or "")
	return label
end

local function CreateHeaderSeparator(parent, label)
	local separator = parent:CreateTexture(nil, "ARTWORK")
	separator:SetPoint("LEFT", label, "RIGHT", 12, -1)
	separator:SetPoint("RIGHT", parent, "RIGHT", -4, -1)
	separator:SetHeight(1)
	separator:SetColorTexture(0.68, 0.6, 0.42, 0.42)
	return separator
end

local function CreateSliderTrackBackground(parent, slider)
	local trackBackground = parent:CreateTexture(nil, "BACKGROUND")
	trackBackground:SetPoint("LEFT", slider, "LEFT", -2, 0)
	trackBackground:SetPoint("RIGHT", slider, "RIGHT", 2, 0)
	trackBackground:SetHeight(8)
	trackBackground:SetColorTexture(0.02, 0.02, 0.02, 0.78)

	local topLine = parent:CreateTexture(nil, "BORDER")
	topLine:SetPoint("BOTTOMLEFT", trackBackground, "TOPLEFT", 0, 0)
	topLine:SetPoint("BOTTOMRIGHT", trackBackground, "TOPRIGHT", 0, 0)
	topLine:SetHeight(1)
	topLine:SetColorTexture(0.65, 0.6, 0.48, 0.35)

	local bottomLine = parent:CreateTexture(nil, "BORDER")
	bottomLine:SetPoint("TOPLEFT", trackBackground, "BOTTOMLEFT", 0, 0)
	bottomLine:SetPoint("TOPRIGHT", trackBackground, "BOTTOMRIGHT", 0, 0)
	bottomLine:SetHeight(1)
	bottomLine:SetColorTexture(0, 0, 0, 0.75)

	return trackBackground
end

local function GetDropdownLabel(row)
	local selected = SafeGet(row, nil)
	for _, value in ipairs(row.values or {}) do
		if value.key == selected then
			return value.label
		end
	end
	return row.label or ""
end

local function SetDropdownText(dropdown, row)
	local text = GetDropdownLabel(row)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(text)
	elseif dropdown.SetText then
		dropdown:SetText(text)
	end
end

local function AttachRefresh(refresh)
	if refresh then
		refresh()
	end
end

function Controls.AttachTooltip(frame, title, body)
	if not frame then
		return
	end

	frame.triageTooltipTitle = title
	frame.triageTooltipBody = body
	frame:EnableMouse(true)

	if frame.triageTooltipAttached then
		return
	end
	frame.triageTooltipAttached = true

	frame:HookScript("OnEnter", function(self)
		local tooltipTitle = self.triageTooltipTitle
		local tooltipBody = self.triageTooltipBody
		if not tooltipTitle and not tooltipBody then
			return
		end

		local tooltip = GetTooltip()
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
		tooltip:ClearLines()
		if tooltipTitle then
			tooltip:AddLine(tooltipTitle, 1, 0.82, 0, true)
		end
		if tooltipBody then
			tooltip:AddLine(tooltipBody, 1, 1, 1, true)
		end
		tooltip:Show()
	end)

	frame:HookScript("OnLeave", function()
		GetTooltip():Hide()
	end)
end

function Controls.CreateHeader(parent, row)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, HEADER_HEIGHT)

	local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	label:SetPoint("LEFT", frame, "LEFT", 0, -3)
	label:SetText(row.label or "")
	label:SetTextColor(1, 0.96, 0.84, 1)
	frame.separator = CreateHeaderSeparator(frame, label)

	return frame
end

function Controls.CreateDescription(parent, row)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, row.height or DESCRIPTION_HEIGHT)

	local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("LEFT", frame, "LEFT", 0, 0)
	text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	text:SetJustifyH("LEFT")
	text:SetText(row.label or "")

	return frame
end

function Controls.CreateCheckbox(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, ROW_HEIGHT)

	CreateLabel(frame, row)

	local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	checkbox:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP - 4, 0)

	frame.triageRefresh = function()
		checkbox:SetChecked(SafeGet(row, false) and true or false)
		SetControlEnabled(checkbox, not IsDisabled(row))
	end
	frame.triageRefresh()

	checkbox:SetScript("OnClick", function(self)
		if IsDisabled(row) then
			self:SetChecked(SafeGet(row, false) and true or false)
			return
		end
		if row.set then
			row.set(self:GetChecked() and true or false)
		end
		AttachRefresh(refresh)
	end)

	Controls.AttachTooltip(frame, row.label, row.tooltip)
	Controls.AttachTooltip(checkbox, row.label, row.tooltip)

	return frame
end

function Controls.CreateButton(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, ROW_HEIGHT)

	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetPoint("LEFT", frame, "LEFT", 0, 0)
	button:SetSize(row.width or 220, 24)
	button:SetText(row.label or "")

	frame.triageRefresh = function()
		SetControlEnabled(button, not IsDisabled(row))
	end
	frame.triageRefresh()

	button:SetScript("OnClick", function()
		if IsDisabled(row) then
			return
		end
		if row.run then
			row.run()
		end
		AttachRefresh(refresh)
	end)

	Controls.AttachTooltip(button, row.label, row.tooltip)

	return frame
end

function Controls.CreateSlider(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, SLIDER_HEIGHT)

	CreateLabel(frame, row)

	local slider = CreateFrame("Slider", nil, frame, "UISliderTemplate")
	slider:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
	slider:SetSize(RIGHT_WIDTH, 18)
	slider.trackBackground = CreateSliderTrackBackground(frame, slider)
	slider:SetMinMaxValues(row.min or 0, row.max or 100)
	if row.step then
		slider:SetValueStep(row.step)
		if slider.SetObeyStepOnDrag then
			slider:SetObeyStepOnDrag(true)
		end
	end

	local valueText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	valueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)

	local function UpdateValueText(value)
		valueText:SetText(FormatValue(row, value))
	end

	frame.triageRefresh = function()
		local value = Clamp(RoundToStep(tonumber(SafeGet(row, row.min or 0)) or 0, row.min, row.step), row.min, row.max)
		slider:SetValue(value)
		UpdateValueText(value)
		SetControlEnabled(slider, not IsDisabled(row))
	end
	frame.triageRefresh()

	slider:SetScript("OnValueChanged", function(self, value)
		if IsDisabled(row) then
			return
		end

		local newValue = Clamp(RoundToStep(value, row.min, row.step), row.min, row.max)
		if newValue ~= value then
			self:SetValue(newValue)
			return
		end

		UpdateValueText(newValue)

		local oldValue = tonumber(SafeGet(row, newValue))
		if oldValue ~= newValue and row.set then
			row.set(newValue)
			AttachRefresh(refresh)
		end
	end)

	Controls.AttachTooltip(frame, row.label, row.tooltip)
	Controls.AttachTooltip(slider, row.label, row.tooltip)

	return frame
end

function Controls.CreateDropdown(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, DROPDOWN_HEIGHT)

	CreateLabel(frame, row)

	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	dropdown:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
	dropdown:SetPoint("RIGHT", frame, "RIGHT", -CONTROL_RIGHT_PADDING, 0)

	frame.triageRefresh = function()
		SetDropdownText(dropdown, row)
		SetControlEnabled(dropdown, not IsDisabled(row))
	end
	frame.triageRefresh()

	if dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, root)
			root:CreateTitle(row.label or "")
			for _, value in ipairs(row.values or {}) do
				root:CreateRadio(value.label, function()
					return SafeGet(row, nil) == value.key
				end, function()
					if IsDisabled(row) then
						return
					end
					if row.set then
						row.set(value.key)
					end
					SetDropdownText(dropdown, row)
					AttachRefresh(refresh)
				end)
			end
		end)
	end

	Controls.AttachTooltip(frame, row.label, row.tooltip)
	Controls.AttachTooltip(dropdown, row.label, row.tooltip)

	return frame
end

function Controls.CreateColor(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, COLOR_HEIGHT)

	CreateLabel(frame, row)

	local swatch = CreateFrame("Button", nil, frame)
	swatch:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
	swatch:SetSize(22, 22)

	local texture = swatch:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints(swatch)

	local border = swatch:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0, 0, 0, 1)

	local function SetSwatchColor(r, g, b, a)
		texture:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
	end

	local function GetColor()
		local r, g, b, a = 1, 1, 1, 1
		if row.get then
			r, g, b, a = row.get()
		end
		return r or 1, g or 1, b or 1, a or 1
	end

	frame.triageRefresh = function()
		SetSwatchColor(GetColor())
		SetControlEnabled(swatch, not IsDisabled(row))
	end
	frame.triageRefresh()

	swatch:SetScript("OnClick", function()
		if IsDisabled(row) then
			return
		end

		local previousR, previousG, previousB, previousA = GetColor()
		local picker = rawget(_G, "ColorPickerFrame")
		if not picker or not picker.SetupColorPickerAndShow then
			return
		end

		local suppressSetupCallback = true

		local function ApplyColor()
			if suppressSetupCallback then
				suppressSetupCallback = false
				return
			end

			local newR, newG, newB = picker:GetColorRGB()
			local newA = previousA
			if picker.GetColorAlpha then
				newA = picker:GetColorAlpha()
			elseif picker.opacity then
				newA = 1 - picker.opacity
			end
			if row.set then
				row.set(newR, newG, newB, newA)
			end
			SetSwatchColor(newR, newG, newB, newA)
			AttachRefresh(refresh)
		end

		local function CancelColor()
			if row.set then
				row.set(previousR, previousG, previousB, previousA)
			end
			SetSwatchColor(previousR, previousG, previousB, previousA)
			AttachRefresh(refresh)
		end

		picker:SetupColorPickerAndShow({
			r = previousR,
			g = previousG,
			b = previousB,
			opacity = 1 - previousA,
			hasOpacity = true,
			swatchFunc = ApplyColor,
			opacityFunc = ApplyColor,
			cancelFunc = CancelColor,
		})
		suppressSetupCallback = false
	end)

	Controls.AttachTooltip(frame, row.label, row.tooltip)
	Controls.AttachTooltip(swatch, row.label, row.tooltip)

	return frame
end

function Controls.CreateEditBox(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, EDIT_HEIGHT)

	CreateLabel(frame, row)

	local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	editBox:SetPoint("LEFT", frame, "LEFT", LEFT_WIDTH + CONTROL_GAP, 0)
	editBox:SetPoint("RIGHT", frame, "RIGHT", -CONTROL_RIGHT_PADDING, 0)
	editBox:SetHeight(24)
	editBox:SetAutoFocus(false)

	frame.triageRefresh = function()
		editBox:SetText(tostring(SafeGet(row, "") or ""))
		SetControlEnabled(editBox, not IsDisabled(row))
	end
	frame.triageRefresh()

	editBox:SetScript("OnEnterPressed", function(self)
		if row.set and not IsDisabled(row) then
			row.set(self:GetText() or "")
		end
		self:ClearFocus()
		AttachRefresh(refresh)
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(SafeGet(row, "") or ""))
		self:ClearFocus()
	end)

	Controls.AttachTooltip(frame, row.label, row.tooltip)
	Controls.AttachTooltip(editBox, row.label, row.tooltip)

	return frame
end

function Controls.CreateMultiline(parent, row, refresh)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, row.height or MULTILINE_HEIGHT)

	local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
	label:SetText(row.label or "")

	local editBox = CreateFrame("EditBox", nil, frame)
	editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
	editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTROL_RIGHT_PADDING, 4)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject("ChatFontNormal")
	editBox:SetTextInsets(6, 6, 6, 6)
	editBox:SetMaxLetters(row.maxLetters or 0)
	editBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput and row.onTextChanged then
			row.onTextChanged(self:GetText() or "")
		end
	end)

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", editBox, "TOPLEFT", -2, 2)
	background:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 2, -2)
	background:SetColorTexture(0, 0, 0, 0.45)

	frame.triageRefresh = function()
		editBox:SetText(tostring(SafeGet(row, "") or ""))
		SetControlEnabled(editBox, not IsDisabled(row))
	end
	frame.triageRefresh()

	Controls.AttachTooltip(frame, row.label, row.tooltip)
	Controls.AttachTooltip(editBox, row.label, row.tooltip)

	return frame
end

function Controls.CreateStatus(parent, row)
	local frame = CreateFrame("Frame", nil, parent)
	SetRowHeight(frame, row.height or STATUS_HEIGHT)

	local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("LEFT", frame, "LEFT", 0, 0)
	text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	text:SetJustifyH("LEFT")

	frame.triageRefresh = function()
		local label = row.get and row.get() or row.label
		text:SetText(label or "")
	end
	frame.triageRefresh()

	return frame
end

return Controls
