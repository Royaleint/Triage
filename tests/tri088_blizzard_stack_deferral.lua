-- luacheck: globals arg dofile LibStub InCombatLockdown hooksecurefunc geterrorhandler C_Timer wipe CompactRaidGroupTypeEnum
-- luacheck: globals CompactUnitFrame_UpdateInRange CompactUnitFrame_UpdateCenterStatusIcon

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertTrue(value, message)
	if not value then
		error(message or "assertion failed", 2)
	end
end

-- Timer stub: matches tests/tri068_setunit_deferral.lua.
local timerQueue = {}
local timersScheduled = 0
C_Timer = {
	After = function(_, callback)
		timersScheduled = timersScheduled + 1
		timerQueue[#timerQueue + 1] = callback
	end,
}

local function fireTimers()
	local queue = timerQueue
	timerQueue = {}
	for _, callback in ipairs(queue) do
		callback()
	end
end

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

local reportedErrors = {}
function geterrorhandler()
	return function(err)
		reportedErrors[#reportedErrors + 1] = err
	end
end

-- Friend-range checker: controllable per block so range-on rows can pick in/out
-- of range without a real LibRangeCheck.
local friendChecker
local addon = {}
function LibStub(name)
	if name == "LibRangeCheck-3.0" then
		return {
			GetFriendMinChecker = function()
				return friendChecker
			end,
		}
	end
	return {
		NewAddon = function() return addon end,
		GetLocale = function() return {} end,
	}
end

function InCombatLockdown()
	return false
end

function hooksecurefunc(owner, name, callback)
	local original = owner[name]
	owner[name] = function(...)
		if original then
			original(...)
		end
		callback(...)
	end
end

CompactRaidGroupTypeEnum = { Party = "party", Raid = "raid", Arena = "arena" }

rawset(_G, "CompactUnitFrame_SetUnit", function() end)
CompactUnitFrame_UpdateInRange = function() end
CompactUnitFrame_UpdateCenterStatusIcon = function() end

dofile(repoRoot .. "Triage.lua")
dofile(repoRoot .. "Utils/FrameRegistry.lua")
dofile(repoRoot .. "Overrides.lua")

addon.db = {
	profile = {
		showBuffs = true,
		showDebuffs = true,
		showDispellableDebuffs = true,
		rangeAlpha = 0.3,
		customRangeCheck = false,
		customRange = 20,
	},
}
addon.usesLegacyUnitAura = false
addon.isRetail = true
addon.supportsDispelOverlay = false

-- The rest of the deferred SetUnit body: stubbed as no-ops so this file stays
-- focused on the hooks it's actually exercising (which Blizzard stack a body
-- runs on), not indicator/aura mechanics already covered elsewhere.
addon.RegisterChatCommand = function() end
addon.RefreshManagedFrameRegistry = function() end
addon.RefreshConfig = function() end
addon.UpdateAllAuras = function() end
addon.RegisterBucketEvent = function() end
addon.RegisterEvent = function() end
addon.InvalidateSecureAuraIndicators = function() end
addon.UpdateStockAuraVisibility = function() end
addon.ClearIndicator = function() end
addon.UpdateUnitAuras = function() end
addon.UpdateUnitAuras_Classic = function() end
addon.UpdateTargetMarker = function() end
addon.UpdateDispelOverlay = function() end

local hooks = {}
addon.SecureHook = function(_, name, callback)
	hooks[name] = callback
end
addon:OnEnable()
assertTrue(hooks["CompactUnitFrame_SetUnit"], "the SetUnit hook installs")
assertTrue(hooks["CompactUnitFrame_UpdateInRange"], "the range hook installs")
assertTrue(hooks["CompactUnitFrame_UpdateCenterStatusIcon"], "the center-status-icon hook installs")

local function resetState()
	timerQueue = {}
	timersScheduled = 0
	reportedErrors = {}
end

-- A frame that records every method a hook running on Blizzard's stack could call:
-- SetAlpha, the private-aura attribute writes, and the child frame/visibility calls.
local function NewRecorderFrame(unit)
	local calls = {}
	local frame = {
		unit = unit,
		displayedUnit = unit,
		groupType = CompactRaidGroupTypeEnum.Party,
		IsForbidden = function() return false end,
		IsShown = function() return true end,
		SetAlpha = function(_, alpha)
			calls[#calls + 1] = { "SetAlpha", alpha }
		end,
		SetAttribute = function(_, key, value)
			calls[#calls + 1] = { "SetAttribute", key, value }
		end,
		GetAttribute = function()
			calls[#calls + 1] = { "GetAttribute" }
			return nil
		end,
		CreateTexture = function()
			calls[#calls + 1] = { "CreateTexture" }
			return {}
		end,
		Hide = function()
			calls[#calls + 1] = { "Hide" }
		end,
		Show = function()
			calls[#calls + 1] = { "Show" }
		end,
		SetPrivateAuraAnchorSettings = function()
			calls[#calls + 1] = { "SetPrivateAuraAnchorSettings" }
		end,
	}
	return frame, calls
end

local function countCalls(calls, name)
	local n = 0
	for _, entry in ipairs(calls) do
		if entry[1] == name then
			n = n + 1
		end
	end
	return n
end

-- Neither the range hook nor the SetUnit hook makes a recorded call before its
-- timer fires; the range flush applies alpha exactly once once it does.
resetState()
addon.db.profile.customRangeCheck = true
friendChecker = function() return true end
do
	local frame, calls = NewRecorderFrame("party1")

	hooks["CompactUnitFrame_SetUnit"](frame, "party1")
	assertEqual(#calls, 0, "the SetUnit hook records no call before the timer fires")

	hooks["CompactUnitFrame_UpdateInRange"](frame)
	assertEqual(#calls, 0, "the range hook records no call before the timer fires")

	fireTimers()
	assertEqual(countCalls(calls, "SetAlpha"), 1, "the range flush applies alpha exactly once after the timer fires")
end

-- A range hook, the center-status-icon hook, and the SetUnit hook on the
-- same frame in one tick schedule exactly one timer and run one flush pass.
resetState()
do
	local frame = NewRecorderFrame("party1")

	hooks["CompactUnitFrame_SetUnit"](frame, "party1")
	hooks["CompactUnitFrame_UpdateInRange"](frame)
	hooks["CompactUnitFrame_UpdateCenterStatusIcon"](frame)
	assertEqual(timersScheduled, 1, "three hooks on one frame in one tick schedule one timer")

	fireTimers()
	assertEqual(timersScheduled, 1, "the flush schedules no further timer once nothing else fires")
end

-- Custom Range off on Retail performs no SetAlpha; Custom Range on
-- performs exactly one SetAlpha per frame per flush.
resetState()
addon.db.profile.customRangeCheck = false
do
	local frame, calls = NewRecorderFrame("party2")
	hooks["CompactUnitFrame_UpdateInRange"](frame)
	fireTimers()
	assertEqual(countCalls(calls, "SetAlpha"), 0, "Custom Range off on Retail performs no SetAlpha")
end

resetState()
addon.db.profile.customRangeCheck = true
friendChecker = function() return false end
do
	local frame, calls = NewRecorderFrame("party3")
	hooks["CompactUnitFrame_UpdateInRange"](frame)
	fireTimers()
	assertEqual(countCalls(calls, "SetAlpha"), 1, "Custom Range on performs exactly one SetAlpha per frame per flush")
end

-- If the deferred flush was never set up (MarkFramePendingRange missing), the
-- range hook on Retail must stay inert rather than fall back to running its
-- body on Blizzard's stack -- checked both immediately and after any timer.
resetState()
addon.db.profile.customRangeCheck = true
friendChecker = function() return true end
do
	local savedMarkFramePendingRange = addon.MarkFramePendingRange
	addon.MarkFramePendingRange = nil

	local frame, calls = NewRecorderFrame("party1")
	hooks["CompactUnitFrame_UpdateInRange"](frame)
	assertEqual(#calls, 0, "the range hook makes no recorded call when the deferred flush isn't set up")

	fireTimers()
	assertEqual(#calls, 0, "the range hook still makes no recorded call after any pending timers fire")

	addon.MarkFramePendingRange = savedMarkFramePendingRange
end

print("tri088_blizzard_stack_deferral: PASS")
