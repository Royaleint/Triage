-- luacheck: globals arg LibStub InCombatLockdown dofile

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
}

dofile(repoRoot .. "Overrides.lua")

local function NewRetailFrame()
	return {
		maxBuffs = 3,
		maxDebuffs = 3,
		maxDispelDebuffs = 2,
		attributes = {
			["max-buffs"] = 3,
			["max-debuffs"] = 3,
			["max-dispel-debuffs"] = 2,
			["show-big-defensive"] = true,
			["show-dispel-indicator-overlay"] = true,
			["ignore-buffs"] = false,
			["ignore-debuffs"] = false,
			["ignore-dispel-debuffs"] = false,
		},
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
assertEqual(frame.attributes["max-buffs"], 3, "re-enabled stock buffs should restore base max-buffs")
assertEqual(frame.attributes["max-debuffs"], 3, "re-enabled stock debuffs should restore base max-debuffs")
assertEqual(frame.attributes["max-dispel-debuffs"], 2, "re-enabled stock dispels should restore base max-dispel-debuffs")
assertEqual(frame.attributes["show-big-defensive"], true, "re-enabled stock buffs should restore center defensive visibility")
assertEqual(frame.attributes["show-dispel-indicator-overlay"], true, "re-enabled stock dispels should restore dispel overlay visibility")
assertEqual(frame.attributes["update-settings"], false, "second notify should toggle update-settings again")

print("tri048_retail_stock_aura_subchannels: PASS")
