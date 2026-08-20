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

-- usedHeight is what Blizzard stored in frame.powerBarUsedHeight at layout time;
-- powerShown/powerHeight drive the live powerBar re-derivation fallback.
local function NewFrame(usedHeight, powerShown, powerHeight)
	local indicators = {}
	for i = 1, 9 do
		indicators[i] = NewRegion()
		indicators[i].position = i
	end

	return {
		Triage_indicatorFrames = indicators,
		Triage_targetMarkerFrame = NewRegion(),
		powerBarUsedHeight = usedHeight,
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

-- Expected y at position 8 (BOTTOM): indicators use PAD 1, markers use PAD 3,
-- plus the power bar compensation (usedHeight + 2) when the bar occupies space.

-- Bar shown and occupying 8px: offset applies
local frame = NewFrame(8, true, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator offset should apply for a shown power bar")

frame = NewFrame(8, true, 8)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 13, "target marker offset should apply for a shown power bar")

-- Original TRI-048 report: during initial layout IsShown() still reads false,
-- but Blizzard has already computed powerBarUsedHeight = 8 -> offset applies
frame = NewFrame(8, false, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator offset should trust powerBarUsedHeight over IsShown at initial layout")

frame = NewFrame(8, false, 8)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 13, "target marker offset should trust powerBarUsedHeight over IsShown at initial layout")

-- Bar legitimately hidden (e.g. healer-only power bars): no offset
frame = NewFrame(0, false, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 1, "indicator offset must not apply when the power bar takes no space")

frame = NewFrame(0, false, 8)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 3, "target marker offset must not apply when the power bar takes no space")

-- powerBarUsedHeight wins over a stale IsShown() reading true
frame = NewFrame(0, true, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 1, "indicator offset should trust powerBarUsedHeight == 0 over IsShown")

-- Secret field: fall back to the IsShown()/GetHeight() derivation
frame = NewFrame(secretSentinel, true, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator fallback should derive offset from a shown power bar")

frame = NewFrame(secretSentinel, false, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 1, "indicator fallback should skip offset for a hidden power bar")

frame = NewFrame(secretSentinel, false, 8)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 3, "target marker fallback should skip offset for a hidden power bar")

-- Missing field, secret height on a shown bar: fallback assumes the default 8px
frame = NewFrame(nil, true, secretSentinel)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator fallback should use default height when GetHeight is secret")

-- Wrong-typed field behaves like a missing one
frame = NewFrame("8", false, 8)
_G.Triage:SetTargetMarkerAppearance(frame)
assertEqual(frame.Triage_targetMarkerFrame.y, 3, "target marker fallback should ignore a non-number powerBarUsedHeight")

-- Secret IsShown() in the fallback is treated as shown (instanced-group default)
frame = NewFrame(nil, secretSentinel, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 11, "indicator fallback should treat a secret IsShown as shown")

-- Feature disabled: never any offset
_G.Triage.db.profile.powerBarOffset = false
frame = NewFrame(8, true, 8)
_G.Triage:SetIndicatorAppearance(frame)
assertEqual(frame.Triage_indicatorFrames[8].y, 1, "indicator offset should not apply when powerBarOffset is disabled")
_G.Triage.db.profile.powerBarOffset = true

print("tri048_power_bar_offsets: PASS")
