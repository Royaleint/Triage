-- luacheck: globals arg dofile LibStub CreateColor
-- luacheck: globals WOW_PROJECT_ID WOW_PROJECT_MAINLINE WOW_PROJECT_CLASSIC
-- luacheck: globals WOW_PROJECT_BURNING_CRUSADE_CLASSIC WOW_PROJECT_MISTS_CLASSIC

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
WOW_PROJECT_MISTS_CLASSIC = 19
WOW_PROJECT_ID = WOW_PROJECT_MAINLINE

-- ColorMixin's accessor hands back three values, which is the whole reason this test exists:
-- an override color reaching SetTextColor ahead of another argument is truncated to its red.
function CreateColor(r, g, b)
	return {
		GetRGB = function(self) return self.r, self.g, self.b end,
		r = r, g = g, b = b,
	}
end

local localeStub = setmetatable({}, { __index = function(_, key) return key end })
LibStub = setmetatable({
	GetLibrary = function() return { Fetch = function(_, _, fallback) return fallback end } end,
}, {
	__call = function(_, library)
		if library == "AceLocale-3.0" then
			return { GetLocale = function() return localeStub end }
		end
		return {}
	end,
})

_G.Triage = {
	db = {
		profile = {
			["indicator-1"] = {
				colorTextByTime = false,
				colorTextByTime_low = 2,
				colorTextByTime_high = 5,
				colorTextByDebuff = false,
				textColor = { 0.1, 0.2, 0.3, 0.4 },
			},
		},
	},
}

dofile(repoRoot .. "Globals.lua")
dofile(repoRoot .. "Modules/AuraIndicators.lua")

local Triage = _G.Triage
local profile = Triage.db.profile["indicator-1"]

local applied = {}
local indicatorFrame = {
	position = 1,
	Countdown = {
		SetTextColor = function(_, r, g, b, a)
			applied[1], applied[2], applied[3], applied[4] = r, g, b, a
		end,
	},
}

--- Every branch overrides the countdown's red, green and blue only; the alpha always comes
--- from the text color picker, so all four components are checked on all of them.
local function assertCountdown(color, message)
	local r, g, b = color:GetRGB()
	assertEqual(applied[1], r, message .. ": red")
	assertEqual(applied[2], g, message .. ": green")
	assertEqual(applied[3], b, message .. ": blue")
	assertEqual(applied[4], profile.textColor[4], message .. ": alpha")
end

local pickerColor = {
	GetRGB = function() return profile.textColor[1], profile.textColor[2], profile.textColor[3] end,
}

-- With no coloring rule active the picker owns all four components outright.
Triage:UpdateCountdownTextColor(indicatorFrame, 10)
assertCountdown(pickerColor, "an uncolored countdown takes the picker's color")

indicatorFrame.thisAura = { isHarmful = true, dispelName = "Magic" }
Triage:UpdateCountdownTextColor(indicatorFrame, 10)
assertCountdown(pickerColor, "a countdown with both coloring rules off takes the picker's color")

-- Coloring by time replaces the color as the aura runs down. Before TRI-058 these branches
-- passed three components and the picker's alpha silently reset to fully opaque.
profile.colorTextByTime = true
Triage:UpdateCountdownTextColor(indicatorFrame, 1)
assertCountdown(Triage.RED_COLOR, "the low-time countdown keeps the picker's alpha")
Triage:UpdateCountdownTextColor(indicatorFrame, 4)
assertCountdown(Triage.YELLOW_COLOR, "the high-time countdown keeps the picker's alpha")
Triage:UpdateCountdownTextColor(indicatorFrame, 10)
assertCountdown(pickerColor, "a countdown outside both time thresholds falls back to the picker")

-- A zero threshold switches that band off rather than firing on every aura.
profile.colorTextByTime_low = 0
Triage:UpdateCountdownTextColor(indicatorFrame, 1)
assertCountdown(Triage.YELLOW_COLOR, "a zeroed low threshold falls through to the high band")
profile.colorTextByTime_low = 2
profile.colorTextByTime = false

-- Coloring by debuff type carried the same three-component reset on every dispel type.
profile.colorTextByDebuff = true
local debuffColors = {
	Poison = Triage.GREEN_COLOR,
	Curse = Triage.PURPLE_COLOR,
	Disease = Triage.BROWN_COLOR,
	Magic = Triage.BLUE_COLOR,
	Bleed = Triage.PINK_COLOR,
}
for dispelName, color in pairs(debuffColors) do
	indicatorFrame.thisAura = { isHarmful = true, dispelName = dispelName }
	Triage:UpdateCountdownTextColor(indicatorFrame, 10)
	assertCountdown(color, "the " .. dispelName .. " countdown keeps the picker's alpha")
end

-- A helpful aura and an unclassified debuff both have no type color to apply.
indicatorFrame.thisAura = { isHarmful = false, dispelName = "Magic" }
Triage:UpdateCountdownTextColor(indicatorFrame, 10)
assertCountdown(pickerColor, "a helpful aura is not colored by debuff type")
indicatorFrame.thisAura = { isHarmful = true, dispelName = "Enrage" }
Triage:UpdateCountdownTextColor(indicatorFrame, 10)
assertCountdown(pickerColor, "an unclassified debuff falls back to the picker")

-- A fully transparent picker has to reach every branch, or the setting is a no-op wherever
-- one of the coloring rules is on.
profile.textColor[4] = 0
indicatorFrame.thisAura = { isHarmful = true, dispelName = "Curse" }
Triage:UpdateCountdownTextColor(indicatorFrame, 10)
assertCountdown(Triage.PURPLE_COLOR, "a transparent picker reaches the by-debuff branch")
profile.colorTextByDebuff = false
profile.colorTextByTime = true
Triage:UpdateCountdownTextColor(indicatorFrame, 1)
assertCountdown(Triage.RED_COLOR, "a transparent picker reaches the by-time branch")

print("tri058_countdown_text_alpha: PASS")
