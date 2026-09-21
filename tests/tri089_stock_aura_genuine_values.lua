-- luacheck: globals arg LibStub InCombatLockdown dofile issecretvalue rawset
-- luacheck: globals CompactUnitFrame_GetOptionShowBigDefensive CompactUnitFrame_GetOptionShowDispelIndicatorOverlay
-- luacheck: globals CompactUnitFrame_GetOptionDisplayBuffs CompactUnitFrame_GetOptionDisplayDebuffs CompactUnitFrame_GetOptionDisplayDispelDebuffs

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
	return value == secretMarker
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

-- Retail has no dispel-overlay getter: suppressing still writes the hidden
-- constant, but restoring must not invent a replacement value.
do
	local frame = NewFrame()
	_G.Triage.db.profile.showDispellableDebuffs = false
	_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
	assertEqual(frame.attributes["show-dispel-indicator-overlay"], false, "suppressing writes the hidden overlay constant")

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

print("tri089_stock_aura_genuine_values: PASS")
