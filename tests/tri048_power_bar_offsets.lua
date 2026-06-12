-- luacheck: globals arg dofile issecretvalue LibStub

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local secretSentinel = {}

function issecretvalue(value)
	return value == secretSentinel
end

local libStub = {}
function libStub:GetLibrary()
	return {
		Fetch = function(_, _, fallback)
			return fallback
		end,
	}
end
setmetatable(libStub, {
	__call = function(_, name)
		if name == "LibDispel-1.0" then
			return {}
		end
		return libStub:GetLibrary(name)
	end,
})
LibStub = libStub

_G.Triage = {
	POSITIONS = {
		"TOPLEFT", "TOP", "TOPRIGHT",
		"LEFT", "CENTER", "RIGHT",
		"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
	},
	db = {
		profile = {
			powerBarOffset = true,
			keepIndicatorsVisible = false,
			indicatorFont = "Fonts\\ARIALN.TTF",
			markerPosition = 8,
			markerVerticalOffset = 0,
			markerVerticalNudge = 0,
			markerHorizontalOffset = 0,
			markerSize = 12,
		},
	},
	ClearIndicator = function() end,
	ClearTargetMarker = function() end,
}

for i = 1, 9 do
	_G.Triage.db.profile["indicator-" .. i] = {
		indicatorSize = 10,
		indicatorVerticalOffset = 0,
		indicatorHorizontalOffset = 0,
		textSize = 8,
		indicatorAlpha = 1,
		showIcon = true,
		showCountdownText = false,
		showStackSize = false,
		countdownLocation = "CENTER",
		stackSizeLocation = "BOTTOMRIGHT",
		indicatorGlow = false,
	}
end

dofile(repoRoot .. "Modules/AuraIndicators.lua")
dofile(repoRoot .. "Modules/TargetMarkers.lua")

local function NewText()
	return {
		SetFont = function() end,
		SetPoint = function() end,
		ClearAllPoints = function() end,
		Hide = function() end,
		Show = function() end,
		SetText = function() end,
	}
end

local function NewRegion()
	return {
		SetWidth = function() end,
		SetHeight = function() end,
		SetAlpha = function() end,
		SetTexture = function() end,
		SetVertexColor = function() end,
		SetDesaturated = function() end,
		SetDrawSwipe = function() end,
		SetCooldown = function() end,
		Hide = function(self)
			self.hidden = true
		end,
		Show = function(self)
			self.hidden = false
		end,
		ClearAllPoints = function(self)
			self.point = nil
		end,
		SetPoint = function(self, point, relativeTo, relativePoint, x, y)
			if type(relativeTo) == "number" then
				x, y = relativeTo, relativePoint
				relativeTo, relativePoint = nil, nil
			end
			self.point = point
			self.relativeTo = relativeTo
			self.relativePoint = relativePoint
			self.x = x
			self.y = y
		end,
		Countdown = NewText(),
		StackSize = NewText(),
		Icon = {
			SetAlpha = function() end,
		},
		Cooldown = {
			Clear = function() end,
			SetDrawSwipe = function() end,
			SetCooldown = function() end,
			Hide = function() end,
		},
	}
end

local function NewFrame(powerHeight, powerShown)
	local indicators = {}
	for i = 1, 9 do
		indicators[i] = NewRegion()
		indicators[i].position = i
	end

	return {
		Triage_indicatorFrames = indicators,
		Triage_targetMarkerFrame = NewRegion(),
		powerBar = {
			IsShown = function()
				return powerShown
			end,
			GetHeight = function()
				return powerHeight
			end,
		},
		GetHeight = function()
			return 36
		end,
		GetWidth = function()
			return 72
		end,
	}
end

local frame = NewFrame(8, false)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator offset should use hidden power bar height")

frame = NewFrame(8, false)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 13, "target marker offset should use hidden power bar height")

frame = NewFrame(0, false)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator offset should use fallback height when power bar height is zero")

frame = NewFrame(secretSentinel, false)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 13, "target marker offset should use fallback height when power bar height is secret")

print("tri048_power_bar_offsets: PASS")
