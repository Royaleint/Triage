-- luacheck: globals arg LibStub InCombatLockdown dofile
-- luacheck: globals CompactUnitFrame_GetOptionShowBigDefensive
-- luacheck: globals CompactUnitFrame_GetOptionDisplayBuffs CompactUnitFrame_GetOptionDisplayDebuffs CompactUnitFrame_GetOptionDisplayDispelDebuffs

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
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

_G.Triage = {
	db = {
		profile = {
			showBuffs = false,
			showDebuffs = false,
			showDispellableDebuffs = false,
		},
	},
	-- Ownership admission is exercised in tests/tri088_frame_ownership.lua, not
	-- here; this frame is a party/raid member frame as far as this test is concerned.
	IsOwnableFrame = function()
		return true
	end,
}

dofile(repoRoot .. "Overrides.lua")

-- Retail-shaped getters: no CompactUnitFrame_GetOptionShowDispelIndicatorOverlay
-- here -- that global does not exist on Retail 12.1, only on Classic Era and
-- Mists Classic.
function CompactUnitFrame_GetOptionShowBigDefensive()
	return true
end
function CompactUnitFrame_GetOptionDisplayBuffs()
	return true
end
function CompactUnitFrame_GetOptionDisplayDebuffs()
	return true
end
function CompactUnitFrame_GetOptionDisplayDispelDebuffs()
	return true
end

local function NewRetailFrame()
	return {
		maxBuffs = 3,
		maxDebuffs = 3,
		maxDispelDebuffs = 2,
		optionTable = {},
		attributes = {},
		SetPrivateAuraAnchorSettings = function() end,
		SetAttribute = function(self, key, value)
			self.attributes[key] = value
		end,
		GetAttribute = function(self, key)
			return self.attributes[key]
		end,
	}
end

local frame = NewRetailFrame()
_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
assertEqual(frame.attributes["ignore-buffs"], true, "disabled stock buffs should set ignore-buffs")
assertEqual(frame.attributes["ignore-debuffs"], true, "disabled stock debuffs should set ignore-debuffs")
assertEqual(frame.attributes["ignore-dispel-debuffs"], true, "disabled stock dispels should set ignore-dispel-debuffs")
assertEqual(frame.attributes["max-buffs"], 0, "disabled stock buffs should suppress buff container frames")
assertEqual(frame.attributes["max-debuffs"], 0, "disabled stock debuffs should suppress debuff container frames")
assertEqual(frame.attributes["max-dispel-debuffs"], 0, "disabled stock dispels should suppress dispel overlay frames")
assertEqual(frame.attributes["show-big-defensive"], false, "disabled stock buffs should suppress center defensive buffs")
assertEqual(frame.attributes["show-dispel-indicator-overlay"], false, "disabled stock dispels should suppress the dispel overlay")
assertEqual(frame.attributes["update-settings"], true, "notify should toggle update-settings")

_G.Triage.db.profile.showBuffs = true
_G.Triage.db.profile.showDebuffs = true
_G.Triage.db.profile.showDispellableDebuffs = true
_G.Triage:ApplyRetailStockAuraVisibility(frame, true)
assertEqual(frame.attributes["ignore-buffs"], false, "re-enabled stock buffs should clear ignore-buffs")
assertEqual(frame.attributes["ignore-debuffs"], false, "re-enabled stock debuffs should clear ignore-debuffs")
assertEqual(frame.attributes["ignore-dispel-debuffs"], false, "re-enabled stock dispels should clear ignore-dispel-debuffs")
assertEqual(frame.attributes["max-buffs"], 3, "re-enabled stock buffs should restore genuine max-buffs")
assertEqual(frame.attributes["max-debuffs"], 3, "re-enabled stock debuffs should restore genuine max-debuffs")
assertEqual(frame.attributes["max-dispel-debuffs"], 2, "re-enabled stock dispels should restore genuine max-dispel-debuffs")
assertEqual(frame.attributes["show-big-defensive"], true, "re-enabled stock buffs should restore genuine center defensive visibility")
-- Retail has no dispel-overlay getter, so restoring must not invent a value;
-- the attribute is simply left at whatever it was last written to.
assertEqual(frame.attributes["show-dispel-indicator-overlay"], false, "retail restore must not write a made-up dispel overlay value")
assertEqual(frame.attributes["update-settings"], false, "second notify should toggle update-settings again")

print("tri048_retail_stock_aura_subchannels: PASS")
