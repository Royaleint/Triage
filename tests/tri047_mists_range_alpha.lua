-- luacheck: globals arg LibStub InCombatLockdown dofile

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local requestedRange
local requestedInCombat
local checkerToReturn

function LibStub(name)
	assertEqual(name, "LibRangeCheck-3.0", "library lookup")
	return {
		GetFriendMinChecker = function(_, range, inCombat)
			requestedRange = range
			requestedInCombat = inCombat
			return checkerToReturn
		end,
	}
end

local inCombat = false
function InCombatLockdown()
	return inCombat
end

_G.Triage = {
	isRetail = false,
	db = {
		profile = {
			customRangeCheck = false,
			customRange = 30,
			rangeAlpha = 0.55,
		},
	},
	ShouldContinue = function()
		return true
	end,
	GetManagedFrameUnit = function()
		return "party1"
	end,
}

dofile(repoRoot .. "Overrides.lua")

local function NewFrame()
	return {
		alpha = 0.55,
		SetAlpha = function(self, value)
			self.alpha = value
		end,
	}
end

local function ResetCase()
	requestedRange = nil
	requestedInCombat = nil
	checkerToReturn = nil
	inCombat = true
	_G.Triage.isRetail = false
	_G.Triage.db.profile.customRangeCheck = false
	_G.Triage.db.profile.customRange = 30
	_G.Triage.db.profile.rangeAlpha = 0.25
end

ResetCase()
local frame = NewFrame()
_G.Triage:UpdateInRange(frame)
assertEqual(requestedRange, 40, "default Mists range should use 40 yard checker")
assertEqual(requestedInCombat, true, "default Mists range should request in-combat-safe checker")
assertEqual(frame.alpha, 1, "default Mists range should restore alpha when no safe checker exists")

ResetCase()
frame = NewFrame()
checkerToReturn = function()
	return false
end
_G.Triage:UpdateInRange(frame)
assertEqual(frame.alpha, 0.25, "default Mists range should dim when a safe checker reports out of range")

ResetCase()
frame = NewFrame()
_G.Triage.db.profile.customRangeCheck = true
_G.Triage:UpdateInRange(frame)
assertEqual(requestedRange, 30, "custom range should use selected range when no safe checker exists")
assertEqual(requestedInCombat, true, "custom range should request in-combat-safe checker when no safe checker exists")
assertEqual(frame.alpha, 1, "custom range should restore alpha when no safe checker exists")

ResetCase()
frame = NewFrame()
checkerToReturn = function()
	return true
end
_G.Triage.db.profile.customRangeCheck = true
_G.Triage:UpdateInRange(frame)
assertEqual(requestedRange, 30, "custom range should use selected range")
assertEqual(requestedInCombat, true, "custom range should request in-combat-safe checker")
assertEqual(frame.alpha, 1, "custom range should keep in-range frames visible")

ResetCase()
frame = NewFrame()
checkerToReturn = function()
	return false
end
_G.Triage.db.profile.customRangeCheck = true
_G.Triage:UpdateInRange(frame)
assertEqual(frame.alpha, 0.25, "custom range should dim when a safe checker reports out of range")

ResetCase()
frame = NewFrame()
_G.Triage.isRetail = true
_G.Triage:UpdateInRange(frame)
assertEqual(requestedRange, nil, "Retail default range should not request a LibRangeCheck override")
assertEqual(frame.alpha, 0.55, "Retail default range should preserve Blizzard alpha")

print("tri047_mists_range_alpha: PASS")
