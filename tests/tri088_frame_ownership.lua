-- luacheck: globals arg dofile LibStub InCombatLockdown hooksecurefunc geterrorhandler C_Timer wipe CompactRaidGroupTypeEnum

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

-- Timer stub: matches tests/tri068_setunit_deferral.lua so the real SetUnit hook
-- can be driven and its scheduling observed.
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

local addon = {}
function LibStub(name)
	if name == "LibRangeCheck-3.0" then
		return { GetFriendMinChecker = function() return nil end }
	end
	return {
		NewAddon = function() return addon end,
		GetLocale = function() return {} end,
	}
end

function InCombatLockdown()
	return false
end

local hooksecurefuncCounts = setmetatable({}, { __mode = "k" })
function hooksecurefunc(owner, name, callback)
	hooksecurefuncCounts[owner] = (hooksecurefuncCounts[owner] or 0) + 1
	local original = owner[name]
	owner[name] = function(...)
		if original then
			original(...)
		end
		callback(...)
	end
end

-- Every verified client's party/raid member frames carry this groupType before
-- Blizzard ever calls SetUnit on them.
CompactRaidGroupTypeEnum = { Party = "party", Raid = "raid", Arena = "arena" }

rawset(_G, "CompactUnitFrame_SetUnit", function() end)

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
	},
}

-- Party and raid groupTypes are ownable; arena is excluded on purpose.
do
	local partyFrame = { groupType = CompactRaidGroupTypeEnum.Party }
	local raidFrame = { groupType = CompactRaidGroupTypeEnum.Raid }
	local arenaFrame = { groupType = CompactRaidGroupTypeEnum.Arena }
	assertTrue(addon:IsOwnableFrame(partyFrame), "a party-shaped frame is ownable")
	assertTrue(addon:IsOwnableFrame(raidFrame), "a raid-shaped frame is ownable")
	assertTrue(not addon:IsOwnableFrame(arenaFrame), "an arena-shaped frame is not ownable -- party and raid only")
end

-- Install the real SetUnit hook the way OnEnable does, so rejection can be proven
-- at the hook itself and not just at the predicate.
local hookCallback
addon.usesLegacyUnitAura = false
addon.isRetail = true
addon.supportsDispelOverlay = false
addon.RegisterChatCommand = function() end
addon.RefreshManagedFrameRegistry = function() end
addon.RefreshConfig = function() end
addon.UpdateAllAuras = function() end
addon.RegisterBucketEvent = function() end
addon.RegisterEvent = function() end
addon.SecureHook = function(_, name, callback)
	if name == "CompactUnitFrame_SetUnit" then
		hookCallback = callback
	end
end
addon:OnEnable()
assertTrue(hookCallback, "the SetUnit hook installs")

-- A nameplate-shaped frame is rejected by ShouldContinue, by
-- RegisterManagedFrame, and by the SetUnit hook, and admission never writes to it.
do
	local nameplateFrame = {
		unit = "player",
		displayedUnit = "player",
		UpdatePrivateAuras = function() end,
		IsForbidden = function() return false end,
		IsShown = function() return true end,
	}
	local snapshot = {}
	for k, v in pairs(nameplateFrame) do
		snapshot[k] = v
	end

	assertTrue(not Triage.ShouldContinue(nameplateFrame, true), "ShouldContinue rejects a nameplate-shaped frame")
	assertEqual(addon:RegisterManagedFrame(nameplateFrame, "player", "blizzard"), nil,
		"RegisterManagedFrame rejects a nameplate-shaped frame")
	assertEqual(addon:GetManagedFrameEntry(nameplateFrame), nil, "a nameplate-shaped frame is never registered")

	timersScheduled = 0
	hookCallback(nameplateFrame, "player")
	assertEqual(timersScheduled, 0, "the SetUnit hook never marks a nameplate-shaped frame pending")
	fireTimers()

	local fieldCount = 0
	for k, v in pairs(nameplateFrame) do
		fieldCount = fieldCount + 1
		assertEqual(snapshot[k], v, "admission changed frame field " .. tostring(k))
	end
	local snapshotCount = 0
	for _ in pairs(snapshot) do
		snapshotCount = snapshotCount + 1
	end
	assertEqual(fieldCount, snapshotCount, "admission added a field to the frame")
end

-- A forbidden frame rejects every field access except IsForbidden itself;
-- the ownership test must not touch anything else, proving the check runs first.
do
	local forbiddenFrame = setmetatable({}, {
		__index = function(_, key)
			if key == "IsForbidden" then
				return function()
					return true
				end
			end
			error("forbidden object should not expose field " .. tostring(key))
		end,
	})
	local ok, result = pcall(function()
		return addon:IsOwnableFrame(forbiddenFrame)
	end)
	assertTrue(ok, "a forbidden frame must not raise: " .. tostring(result))
	assertTrue(not result, "a forbidden frame is rejected")
end

-- A token-shaped frame missing groupType is rejected -- the unit token
-- no longer admits by itself once the enum is present.
do
	local frame = { unit = "party1", displayedUnit = "party1", IsForbidden = function() return false end }
	assertTrue(not addon:IsOwnableFrame(frame), "a token-shaped frame with no groupType is not ownable")
end

-- A Triage-created test-mode frame is admitted without a groupType.
do
	local frame = { Triage_isTestFrame = true }
	assertTrue(addon:IsOwnableFrame(frame), "a test-mode frame is ownable without a groupType")
end

-- A frame adopted while ownable, then de-owned (groupType cleared), is rejected
-- on its next touch and the fix's own bookkeeping is torn down -- except the
-- installed-hook flag, which hooksecurefunc can never undo. Re-adopting the
-- same frame later must not install that hook a second time.
do
	local attributes = {}
	local frame = {
		unit = "party3",
		displayedUnit = "party3",
		groupType = CompactRaidGroupTypeEnum.Party,
		IsForbidden = function() return false end,
		IsShown = function() return true end,
		SetPrivateAuraAnchorSettings = function() end,
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
	}

	assertTrue(addon:RegisterManagedFrame(frame, "party3", "blizzard"), "the frame registers while ownable")
	addon:UpdateStockAuraVisibility(frame)
	assertTrue(frame.Triage_stockAuraVisibilityHooked, "the settings hook installs while ownable")
	assertTrue(frame.Triage_stockAuraVisibilityApplied, "stock aura visibility applies while ownable")
	assertEqual(hooksecurefuncCounts[frame], 1, "the settings hook installs exactly once")

	frame.groupType = nil -- adopted earlier this session; now de-owned

	assertEqual(addon:RegisterManagedFrame(frame, "party3", "blizzard"), nil,
		"re-registering a de-owned frame is rejected")
	assertEqual(addon:GetManagedFrameEntry(frame), nil, "the registry drops a de-owned frame on its next touch")
	assertEqual(frame.Triage_stockAuraVisibilityApplied, nil, "teardown clears the applied flag")
	assertEqual(frame.Triage_stockAuraBaseAttributes, nil, "teardown clears the captured base attributes")
	assertEqual(frame.Triage_privateAuraSettingsVersion, nil, "teardown clears the settings version toggle")
	assertTrue(frame.Triage_stockAuraVisibilityHooked, "the hooked flag survives teardown -- the hook itself can't be removed")

	local attributeWritesBefore = 0
	for _ in pairs(attributes) do
		attributeWritesBefore = attributeWritesBefore + 1
	end

	assertTrue(not Triage.ShouldContinue(frame, true), "ShouldContinue rejects the de-owned frame")
	addon:UpdateStockAuraVisibility(frame)
	timersScheduled = 0
	hookCallback(frame, "party3")
	assertEqual(timersScheduled, 0, "the SetUnit hook does not re-adopt a de-owned frame")
	fireTimers()

	local attributeWritesAfter = 0
	for _ in pairs(attributes) do
		attributeWritesAfter = attributeWritesAfter + 1
	end
	assertEqual(attributeWritesAfter, attributeWritesBefore, "no hook body writes to a de-owned frame")

	-- Re-adopt: the frame becomes ownable again (e.g. Blizzard reuses it for a
	-- real party member later). The settings hook must not install a second time.
	frame.groupType = CompactRaidGroupTypeEnum.Party
	assertTrue(addon:RegisterManagedFrame(frame, "party3", "blizzard"), "the frame registers again once re-owned")
	addon:UpdateStockAuraVisibility(frame)
	assertTrue(frame.Triage_stockAuraVisibilityApplied, "stock aura visibility re-applies once re-owned")
	assertEqual(hooksecurefuncCounts[frame], 1, "re-adopting the frame does not install the settings hook a second time")
end

-- With CompactRaidGroupTypeEnum absent, Retail fails closed and every
-- other client falls back to today's unit-token gate.
do
	CompactRaidGroupTypeEnum = nil

	local partyShaped = { unit = "party1", displayedUnit = "party1", groupType = "party" }
	addon.isRetail = true
	assertTrue(not addon:IsOwnableFrame(partyShaped), "Retail with no CompactRaidGroupTypeEnum fails closed")

	addon.isRetail = false
	assertTrue(addon:IsOwnableFrame(partyShaped), "non-Retail with no CompactRaidGroupTypeEnum falls back to the unit-token gate")

	local unrecognizedToken = { unit = "nameplate1", displayedUnit = "nameplate1" }
	assertTrue(not addon:IsOwnableFrame(unrecognizedToken),
		"the unit-token fallback still rejects a token outside the registry map")

	CompactRaidGroupTypeEnum = { Party = "party", Raid = "raid", Arena = "arena" }
	addon.isRetail = true
end

print("tri088_frame_ownership: PASS")
