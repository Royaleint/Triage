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

function InCombatLockdown()
	return false
end

local hooks = setmetatable({}, { __mode = "k" })

_G.Triage = {
	supportsRetailStockAuraAttributes = false,
	db = {
		profile = {
			showBuffs = false,
			showDebuffs = true,
			showDispellableDebuffs = true,
		},
	},
	ShouldContinue = function()
		return true
	end,
	IsHooked = function(_, frame, scriptName)
		return hooks[frame] == scriptName
	end,
	SecureHookScript = function(_, frame, scriptName, callback)
		hooks[frame] = scriptName
		frame.onShowHook = callback
	end,
	Unhook = function(_, frame, scriptName)
		if hooks[frame] == scriptName then
			hooks[frame] = nil
			frame.onShowHook = nil
		end
	end,
}

dofile(repoRoot .. "Overrides.lua")

local auraFrame = {
	shown = true,
	IsShown = function(self)
		return self.shown
	end,
	Hide = function(self)
		self.shown = false
	end,
	Show = function(self)
		self.shown = true
	end,
}

local frame = {
	buffFrames = { auraFrame },
	debuffFrames = {},
	dispelDebuffFrames = {},
}

_G.Triage:UpdateStockAuraVisibility(frame)
assertEqual(auraFrame.shown, false, "disabled stock buff frame should be hidden")
assertEqual(_G.Triage:IsHooked(auraFrame, "OnShow"), true, "disabled stock buff frame should keep OnShow hook")

_G.Triage.db.profile.showBuffs = true
_G.Triage:UpdateStockAuraVisibility(frame)
assertEqual(_G.Triage:IsHooked(auraFrame, "OnShow"), false, "re-enabled stock buff frame should remove OnShow hook")
assertEqual(auraFrame.shown, true, "re-enabled stock buff frame should be shown immediately")

print("tri048_classic_stock_aura_reenable: PASS")
