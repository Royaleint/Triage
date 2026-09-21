-- luacheck: globals arg LibStub InCombatLockdown dofile issecretvalue rawset
-- luacheck: globals CompactUnitFrame_GetOptionShowBigDefensive CompactUnitFrame_GetOptionShowDispelIndicatorOverlay
-- luacheck: globals CompactUnitFrame_GetOptionDisplayBuffs CompactUnitFrame_GetOptionDisplayDebuffs CompactUnitFrame_GetOptionDisplayDispelDebuffs
-- luacheck: globals hooksecurefunc geterrorhandler C_Timer wipe CompactRaidGroupTypeEnum

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

function LibStub(name)
	assertEqual(name, "LibRangeCheck-3.0", "library lookup")
	return {
		GetFriendMinChecker = function()
			return nil
		end,
	}
end

local inCombat = false
function InCombatLockdown()
	return inCombat
end

local secretMarker
function issecretvalue(value)
	return secretMarker ~= nil and value == secretMarker
end

local ownable = true
_G.Triage = {
	db = {
		profile = {
			showBuffs = true,
			showDebuffs = true,
			showDispellableDebuffs = true,
		},
	},
	-- Ownership admission is exercised in tests/tri088_frame_ownership.lua, not
	-- here; every frame below is a party/raid member frame as far as this
	-- test is concerned, except where a block deliberately de-owns it.
	IsOwnableFrame = function()
		return ownable
	end,
}

dofile(repoRoot .. "Overrides.lua")

-- Retail-shaped getters: real functions reading a value off the frame, the
-- way Blizzard's own getters read frame.optionTable. CompactUnitFrame_GetOptionShowDispelIndicatorOverlay
-- is left undefined here -- that global does not exist on Retail 12.1, only
-- on Classic Era and Mists Classic.
function CompactUnitFrame_GetOptionShowBigDefensive(frame)
	return frame.optionShowBigDefensive
end
function CompactUnitFrame_GetOptionDisplayBuffs(frame)
	return frame.optionDisplayBuffs
end
function CompactUnitFrame_GetOptionDisplayDebuffs(frame)
	return frame.optionDisplayDebuffs
end
function CompactUnitFrame_GetOptionDisplayDispelDebuffs(frame)
	return frame.optionDisplayDispelDebuffs
end

local function NewFrame()
	local frame = {
		maxBuffs = 5,
		maxDebuffs = 6,
		maxDispelDebuffs = 4,
		optionTable = {},
		optionShowBigDefensive = true,
		optionDisplayBuffs = true,
		optionDisplayDebuffs = true,
		optionDisplayDispelDebuffs = true,
		attributes = {},
		calls = {},
		SetPrivateAuraAnchorSettings = function() end,
	}
	frame.SetAttribute = function(self, key, value)
		self.calls[#self.calls + 1] = { "SetAttribute", key, value }
		self.attributes[key] = value
	end
	frame.GetAttribute = function(self, key)
		self.calls[#self.calls + 1] = { "GetAttribute", key }
		return self.attributes[key]
	end
	return frame
end

local function countMatchingCalls(calls, name, key)
	local n = 0
	for _, entry in ipairs(calls) do
		if entry[1] == name and (key == nil or entry[2] == key) then
			n = n + 1
		end
	end
	return n
end

-- Suppressing every category writes Blizzard's hidden constants, not
-- anything computed.
do
	_G.Triage.db.profile.showBuffs = false
	_G.Triage.db.profile.showDebuffs = false
	_G.Triage.db.profile.showDispellableDebuffs = false

	local frame = NewFrame()
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	assertEqual(frame.attributes["ignore-buffs"], true, "hidden buffs are ignored")
	assertEqual(frame.attributes["ignore-debuffs"], true, "hidden debuffs are ignored")
	assertEqual(frame.attributes["ignore-dispel-debuffs"], true, "hidden dispellable debuffs are ignored")
	assertEqual(frame.attributes["max-buffs"], 0, "the buff container collapses to zero")
	assertEqual(frame.attributes["max-debuffs"], 0, "the debuff container collapses to zero")
	assertEqual(frame.attributes["max-dispel-debuffs"], 0, "the dispel container collapses to zero")
	assertEqual(frame.attributes["show-big-defensive"], false, "the big defensive icon is turned off")

	_G.Triage.db.profile.showBuffs = true
	_G.Triage.db.profile.showDebuffs = true
	_G.Triage.db.profile.showDispellableDebuffs = true
end

-- Turning a switch back on writes Blizzard's own current values, and the
-- switch only ever hides -- it never forces Blizzard's own raid-frame
-- option back on. Restoring never reads a Triage-written attribute back.
do
	local frame = NewFrame()
	frame.maxBuffs = 7
	frame.optionShowBigDefensive = false
	frame.optionDisplayBuffs = false -- the player turned this off in Blizzard's own options

	_G.Triage.db.profile.showBuffs = false
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	_G.Triage.db.profile.showBuffs = true
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	assertEqual(frame.attributes["max-buffs"], 7, "the restored buff count comes from Blizzard's own frame field")
	assertEqual(frame.attributes["show-big-defensive"], false, "the restored value comes from Blizzard's own getter")
	assertEqual(frame.attributes["ignore-buffs"], true,
		"Triage's own switch only hides -- it leaves Blizzard's own display option alone")
	assertEqual(countMatchingCalls(frame.calls, "GetAttribute"), 0, "restoring never reads a Triage-written attribute back")
end

-- Retail has no dispel-overlay getter at all: this attribute is never
-- written in either direction on this client, suppressing or restoring.
do
	local frame = NewFrame()
	_G.Triage.db.profile.showDispellableDebuffs = false
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(countMatchingCalls(frame.calls, "SetAttribute", "show-dispel-indicator-overlay"), 0,
		"with no overlay getter on this client, suppressing must not write that attribute either")

	frame.calls = {}
	_G.Triage.db.profile.showDispellableDebuffs = true
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	assertEqual(countMatchingCalls(frame.calls, "SetAttribute", "show-dispel-indicator-overlay"), 0,
		"with no overlay getter on this client, restoring must not write a made-up value")
end

-- On a client that does carry the overlay getter, the value round-trips to
-- whatever that getter reports.
do
	rawset(_G, "CompactUnitFrame_GetOptionShowDispelIndicatorOverlay", function(frame)
		return frame.optionShowDispelOverlay
	end)

	local frame = NewFrame()
	frame.optionShowDispelOverlay = true

	_G.Triage.db.profile.showDispellableDebuffs = false
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(frame.attributes["show-dispel-indicator-overlay"], false, "suppressing writes the hidden overlay constant")

	_G.Triage.db.profile.showDispellableDebuffs = true
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(frame.attributes["show-dispel-indicator-overlay"], true,
		"restoring on a client with the getter round-trips to its value")

	rawset(_G, "CompactUnitFrame_GetOptionShowDispelIndicatorOverlay", nil)
end

-- A missing optionTable must not raise. Suppression still writes its
-- constants; restoring leaves the ignore-* keys alone rather than guessing.
do
	local frame = NewFrame()
	frame.optionTable = nil

	_G.Triage.db.profile.showBuffs = false
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(frame.attributes["ignore-buffs"], true, "suppression still writes its constant with no optionTable")

	frame.calls = {}
	_G.Triage.db.profile.showBuffs = true
	local ok = pcall(function()
		_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	end)
	assertTrue(ok, "a missing optionTable must not raise")
	assertEqual(countMatchingCalls(frame.calls, "SetAttribute", "ignore-buffs"), 0,
		"restoring with no optionTable leaves ignore-buffs alone rather than guessing")
end

-- A getter returning a secret value is treated as unavailable, not tested
-- as a boolean and not written.
do
	secretMarker = {}
	local frame = NewFrame()
	frame.optionShowBigDefensive = secretMarker

	_G.Triage.db.profile.showBuffs = false
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	frame.calls = {}
	_G.Triage.db.profile.showBuffs = true
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	assertEqual(countMatchingCalls(frame.calls, "SetAttribute", "show-big-defensive"), 0,
		"a secret getter return is treated as unavailable, not as a value to test or write")
	secretMarker = nil
end

-- With every switch already on and a frame Triage has never suppressed,
-- there is nothing to write and nothing to announce.
do
	_G.Triage.db.profile.showBuffs = true
	_G.Triage.db.profile.showDebuffs = true
	_G.Triage.db.profile.showDispellableDebuffs = true

	local frame = NewFrame()
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)

	assertEqual(#frame.calls, 0, "default options on a never-suppressed frame perform no attribute call at all")
end

-- Combat lockdown performs no writes and leaves the pending flag set; the
-- deferred regen pass applies once combat ends. This is unchanged behaviour.
do
	local frame = NewFrame()
	_G.Triage.db.profile.showBuffs = false
	_G.Triage.Triage_pendingStockAuraVisibilityUpdate = nil

	inCombat = true
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(#frame.calls, 0, "combat lockdown performs no attribute writes")
	assertTrue(_G.Triage.Triage_pendingStockAuraVisibilityUpdate, "combat lockdown leaves the pending flag set for the regen flush")

	inCombat = false
	_G.Triage.Triage_pendingStockAuraVisibilityUpdate = nil
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(frame.attributes["ignore-buffs"], true, "the regen flush applies the suppressed state once combat ends")

	_G.Triage.db.profile.showBuffs = true
end

-- A test-mode frame and a de-owned frame both early-out before any write.
do
	local testFrame = NewFrame()
	testFrame.Triage_isTestFrame = true
	_G.Triage:UpdateStockAuraVisibility(testFrame)
	assertEqual(#testFrame.calls, 0, "a test-mode frame is never touched by the stock aura path")

	ownable = false
	local deOwnedFrame = NewFrame()
	local applied = _G.Triage:ApplyRetailStockAuraVisibility(deOwnedFrame, true)
	assertEqual(applied, false, "a de-owned frame is rejected before any write")
	assertEqual(#deOwnedFrame.calls, 0, "a de-owned frame receives no attribute writes")
	ownable = true
end

-------------------------------------------------------------------------
-- Mark-only settings hook and cross-set dedupe (Retail only). This section
-- builds its own addon instance through Triage.lua's real OnEnable, the way
-- tests/tri088_blizzard_stack_deferral.lua does, since the deferred flush
-- and its pending sets live there rather than in Overrides.lua.
-------------------------------------------------------------------------
do
	local timerQueue = {}
	C_Timer = {
		After = function(_, callback)
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

	function geterrorhandler()
		return function() end
	end

	CompactRaidGroupTypeEnum = { Party = "party", Raid = "raid", Arena = "arena" }
	rawset(_G, "CompactUnitFrame_SetUnit", function() end)

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

	function hooksecurefunc(owner, name, callback)
		local original = owner[name]
		owner[name] = function(...)
			if original then
				original(...)
			end
			callback(...)
		end
	end

	dofile(repoRoot .. "Triage.lua")
	dofile(repoRoot .. "Utils/FrameRegistry.lua")
	dofile(repoRoot .. "Overrides.lua")

	addon.db = {
		profile = {
			showBuffs = false,
			showDebuffs = true,
			showDispellableDebuffs = true,
			rangeAlpha = 0.3,
			customRangeCheck = false,
		},
	}
	addon.usesLegacyUnitAura = false
	addon.isRetail = true
	addon.supportsDispelOverlay = false
	addon.RegisterChatCommand = function() end
	addon.RefreshManagedFrameRegistry = function() end
	addon.RefreshConfig = function() end
	addon.UpdateAllAuras = function() end
	addon.RegisterBucketEvent = function() end
	addon.RegisterEvent = function() end
	addon.InvalidateSecureAuraIndicators = function() end
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

	-- A real attribute-container frame; SetAttribute/GetAttribute record every
	-- call the way the recorder frames in tests/tri088_blizzard_stack_deferral.lua do.
	local function NewMarkFrame(unit)
		local calls = {}
		local frame = {
			unit = unit,
			displayedUnit = unit,
			groupType = CompactRaidGroupTypeEnum.Party,
			maxBuffs = 5,
			maxDebuffs = 5,
			maxDispelDebuffs = 3,
			optionTable = {},
			IsForbidden = function() return false end,
			IsShown = function() return true end,
			SetPrivateAuraAnchorSettings = function() end,
		}
		frame.SetAttribute = function(_, key, value)
			calls[#calls + 1] = { "SetAttribute", key, value }
		end
		frame.GetAttribute = function(_, key)
			calls[#calls + 1] = { "GetAttribute", key }
			return nil
		end
		return frame, calls
	end

	local function countCalls(calls, name, key)
		local n = 0
		for _, entry in ipairs(calls) do
			if entry[1] == name and (key == nil or entry[2] == key) then
				n = n + 1
			end
		end
		return n
	end

	local function resetCalls(calls)
		for i = #calls, 1, -1 do
			calls[i] = nil
		end
	end

	-- Driving the settings hook records no call before the timer fires; the
	-- deferred apply runs once the timer does.
	do
		local frame, calls = NewMarkFrame("party1")
		addon:RegisterManagedFrame(frame, "party1", "blizzard")
		addon:UpdateStockAuraVisibility(frame) -- installs the hook; not the row under test
		resetCalls(calls)

		frame:SetPrivateAuraAnchorSettings()
		assertEqual(#calls, 0, "the settings hook records no call before the timer fires")

		fireTimers()
		assertTrue(countCalls(calls, "SetAttribute") > 0, "the deferred apply writes the suppressed attributes once the timer fires")
		assertEqual(countCalls(calls, "GetAttribute"), 0, "the deferred apply never reads a Triage-written attribute back")
	end

	-- A settings hook and the SetUnit hook firing on the same frame in one
	-- tick still produce exactly one apply and at most one update-settings write.
	do
		local frame, calls = NewMarkFrame("party2")
		addon:RegisterManagedFrame(frame, "party2", "blizzard")
		addon:UpdateStockAuraVisibility(frame)
		resetCalls(calls)

		hooks["CompactUnitFrame_SetUnit"](frame, "party2")
		frame:SetPrivateAuraAnchorSettings()
		assertEqual(#calls, 0, "neither hook records a call before the timer fires")

		fireTimers()
		assertEqual(countCalls(calls, "SetAttribute", "update-settings"), 1,
			"one unit assignment marking both sets yields at most one update-settings write per frame per tick")
	end

	-- If the deferred flush was never set up, the settings hook on Retail
	-- must stay inert rather than fall back to a synchronous apply.
	do
		local frame, calls = NewMarkFrame("party3")
		addon:RegisterManagedFrame(frame, "party3", "blizzard")
		addon:UpdateStockAuraVisibility(frame)
		resetCalls(calls)

		local savedMark = addon.MarkFramePendingStockAura
		addon.MarkFramePendingStockAura = nil

		frame:SetPrivateAuraAnchorSettings()
		assertEqual(#calls, 0, "the settings hook makes no recorded call when the deferred flush isn't set up")
		fireTimers()
		assertEqual(#calls, 0, "the settings hook still makes no recorded call after any pending timers fire")

		addon.MarkFramePendingStockAura = savedMark
	end

	-- Teardown through the real registry, then re-adoption with every switch
	-- now on, still restores genuine values: the applied flag survives that
	-- teardown instead of resetting to "nothing to restore".
	do
		addon.db.profile.showBuffs = false
		addon.db.profile.showDebuffs = true
		addon.db.profile.showDispellableDebuffs = true

		local frame, calls = NewMarkFrame("party4")
		addon:RegisterManagedFrame(frame, "party4", "blizzard")
		addon:UpdateStockAuraVisibility(frame)
		assertTrue(frame.Triage_stockAuraVisibilityApplied, "the frame carries suppressed values before teardown")

		frame.groupType = nil
		addon:RegisterManagedFrame(frame, "party4", "blizzard") -- de-owned; runs the real teardown
		assertTrue(frame.Triage_stockAuraVisibilityApplied, "the applied flag survives the real registry teardown")

		frame.groupType = CompactRaidGroupTypeEnum.Party
		addon:RegisterManagedFrame(frame, "party4", "blizzard")
		addon.db.profile.showBuffs = true
		resetCalls(calls)
		addon:UpdateStockAuraVisibility(frame)

		assertEqual(countCalls(calls, "SetAttribute", "max-buffs"), 1,
			"re-adoption with every switch on restores the genuine buff count")
		assertTrue(not frame.Triage_stockAuraVisibilityApplied, "the flag clears once every suppressed attribute is restored")

		addon.db.profile.showBuffs = false
	end

	-- A restore pass where a present source can't be read right now leaves
	-- the flag set so a later pass tries that source again; once it can be
	-- read, that later pass restores it and clears the flag.
	do
		addon.db.profile.showBuffs = true
		addon.db.profile.showDebuffs = false
		addon.db.profile.showDispellableDebuffs = true

		local frame, calls = NewMarkFrame("party5")
		addon:RegisterManagedFrame(frame, "party5", "blizzard")
		addon:UpdateStockAuraVisibility(frame)
		assertTrue(frame.Triage_stockAuraVisibilityApplied, "the frame carries suppressed values before the restore attempt")

		frame.optionTable = nil
		addon.db.profile.showDebuffs = true
		resetCalls(calls)
		addon:UpdateStockAuraVisibility(frame)

		assertEqual(countCalls(calls, "SetAttribute", "ignore-debuffs"), 0,
			"a source that can't be read right now is not written")
		assertTrue(frame.Triage_stockAuraVisibilityApplied, "the flag stays set so a later pass tries the unread source again")

		frame.optionTable = {}
		resetCalls(calls)
		addon:UpdateStockAuraVisibility(frame)

		assertEqual(countCalls(calls, "SetAttribute", "ignore-debuffs"), 1, "the source restores once it can be read again")
		assertTrue(not frame.Triage_stockAuraVisibilityApplied, "the flag clears once every suppressed attribute has been restored")

		addon.db.profile.showBuffs = false
		addon.db.profile.showDebuffs = true
	end

	-- A full suppress-then-restore cycle on the Retail shape ends with the
	-- flag clear, and a further apply with nothing left to do performs no
	-- calls at all.
	do
		addon.db.profile.showBuffs = false
		addon.db.profile.showDebuffs = false
		addon.db.profile.showDispellableDebuffs = false

		local frame, calls = NewMarkFrame("party6")
		addon:RegisterManagedFrame(frame, "party6", "blizzard")
		addon:UpdateStockAuraVisibility(frame)
		assertTrue(frame.Triage_stockAuraVisibilityApplied, "the frame carries suppressed values")

		addon.db.profile.showBuffs = true
		addon.db.profile.showDebuffs = true
		addon.db.profile.showDispellableDebuffs = true
		addon:UpdateStockAuraVisibility(frame)
		assertTrue(not frame.Triage_stockAuraVisibilityApplied, "the flag clears once the full cycle restores everything")

		resetCalls(calls)
		addon:UpdateStockAuraVisibility(frame)
		assertEqual(#calls, 0, "a further apply with the flag already clear performs no calls at all")

		addon.db.profile.showBuffs = false
		addon.db.profile.showDebuffs = true
		addon.db.profile.showDispellableDebuffs = true
	end
end

print("tri089_stock_aura_genuine_values: PASS")
