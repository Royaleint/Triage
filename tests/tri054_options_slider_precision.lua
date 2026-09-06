-- luacheck: globals arg dofile CreateFrame UIParent
-- TRI-054: native slider callbacks may return a reduced-precision value that is
-- adjacent to, rather than exactly equal to, Triage's configured step.

local repoRoot = arg[1] or "./"
if repoRoot:sub(-1) ~= "/" and repoRoot:sub(-1) ~= "\\" then
	repoRoot = repoRoot .. "/"
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertNear(actual, expected, epsilon, message)
	if math.abs(actual - expected) > epsilon then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function noop() end

local function makeRegion()
	local region = {
		SetPoint = noop,
		SetWidth = noop,
		SetHeight = noop,
		SetSize = noop,
		SetJustifyH = noop,
		SetText = function(self, text) self.text = text end,
		SetTextColor = noop,
		SetColorTexture = noop,
		SetAllPoints = noop,
		ClearAllPoints = noop,
		Hide = noop,
		Show = noop,
		SetShown = noop,
	}
	return region
end

local function makeFrame(frameType)
	local frame = {
		scripts = {},
		CreateFontString = function(self)
			local region = makeRegion()
			self.fontStrings = self.fontStrings or {}
			self.fontStrings[#self.fontStrings + 1] = region
			return region
		end,
		CreateTexture = function() return makeRegion() end,
		SetPoint = noop,
		SetWidth = noop,
		SetHeight = noop,
		SetSize = noop,
		EnableMouse = noop,
		HookScript = noop,
		Enable = noop,
		Disable = noop,
		SetChecked = noop,
		SetAutoFocus = noop,
		SetMultiLine = noop,
		SetFontObject = noop,
		SetTextInsets = noop,
		SetMaxLetters = noop,
		SetMinMaxValues = noop,
		SetValueStep = noop,
		SetObeyStepOnDrag = noop,
		SetScript = function(self, event, callback) self.scripts[event] = callback end,
	}
	if frameType == "Slider" then
		frame.SetValue = function(self, value)
			self.value = value
			if self.scripts.OnValueChanged then
				self.scripts.OnValueChanged(self, value)
			end
		end
	end
	return frame
end

_G.Triage = {}
rawset(_G, "UIParent", {})
local lastSlider
rawset(_G, "CreateFrame", function(frameType)
	local created = makeFrame(frameType)
	if frameType == "Slider" then
		lastSlider = created
	end
	return created
end)

dofile(repoRoot .. "GUI/OptionsControls.lua")

local value = 0
local writes = {}
local refreshes = 0
local disabled = false
local row = {
	label = "Vertical Offset",
	isPercent = true,
	min = -1,
	max = 1,
	step = 0.005,
	get = function() return value end,
	set = function(newValue)
		value = newValue
		writes[#writes + 1] = newValue
	end,
	disabled = function() return disabled end,
}

local control = _G.Triage.OptionsControls.CreateSlider(makeFrame("Frame"), row, function()
	refreshes = refreshes + 1
end)
local slider = lastSlider
assertEqual(type(control), "table", "slider control is created")
assertEqual(type(slider.scripts.OnValueChanged), "function", "slider installs its change handler")

-- These are representative IEEE-754 single precision callback values for .005
-- and .010. The saved setting must advance to the configured values, not be
-- discarded while the control tries to force exact double precision equality.
slider.scripts.OnValueChanged(slider, 0.0049999998882413)
assertNear(value, 0.005, 0.0000001, "the first reduced-precision step is stored")
assertEqual(control.fontStrings[2].text, "0.5%", "half-percent offsets display their configured precision")
slider.scripts.OnValueChanged(slider, 0.0099999997764826)
assertNear(value, 0.01, 0.0000001, "a later reduced-precision step is stored")
assertEqual(#writes, 2, "each user-selected step writes once")
assertEqual(refreshes, 2, "each stored step refreshes dependent controls")

-- A programmatic refresh sends the current native value through the same event;
-- it must not turn into a second user write.
slider.scripts.OnValueChanged(slider, 0.0099999997764826)
assertEqual(#writes, 2, "a programmatic value refresh does not write settings")

-- An unset setting is distinct from a stored value. Its first user adjustment
-- still has to persist the normalized step.
value = nil
slider.scripts.OnValueChanged(slider, 0.0049999998882413)
assertNear(value, 0.005, 0.0000001, "the first edit of an unset value is stored")
assertEqual(#writes, 3, "an unset value receives one user write")

disabled = true
slider.scripts.OnValueChanged(slider, 0.0149999996647239)
assertNear(value, 0.005, 0.0000001, "a disabled slider does not change its stored value")
assertEqual(#writes, 3, "a disabled slider does not write settings")

-- Refreshing a row whose value is unset is a programmatic SetValue, not a user
-- edit of the fallback minimum.
disabled = false
value = nil
local writesBeforeRefresh = #writes
control.triageRefresh()
assertEqual(value, nil, "refreshing an unset value does not create a setting")
assertEqual(#writes, writesBeforeRefresh, "refreshing an unset value does not write settings")

local function assertPercentLabel(rawValue, expectedLabel)
	value = rawValue
	control.triageRefresh()
	assertEqual(control.fontStrings[2].text, expectedLabel, "percentage labels retain configured precision")
end

assertPercentLabel(0, "0%")
assertPercentLabel(0.010000000000000009, "1%")
assertPercentLabel(-0.010000000000000009, "-1%")
assertPercentLabel(0.0050000000000001, "0.5%")
assertPercentLabel(-0.0050000000000001, "-0.5%")
assertPercentLabel(1, "100%")

print("tri054_options_slider_precision: PASS")
