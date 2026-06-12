-- luacheck: globals arg LibStub InCombatLockdown hooksecurefunc dofile

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

function hooksecurefunc(owner, name, callback)
	local original = owner[name]
	owner[name] = function(...)
		original(...)
		callback(...)
	end
end

local hooks = setmetatable({}, { __mode = "k" })

-- Classic-family client: the addon-level Retail flag is false, but 1.15.9+ /
-- 5.5.4+ frames still carry the attribute-based private-aura container.
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

-- A Classic 1.15.9+ / 5.5.4+ CompactUnitFrame: no legacy buffFrames tables,
-- but the ContainerPrivateAuraBehaviorMixin attribute surface is present.
local function NewAttributeFrame()
	return {
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

-- Capability gate: a Classic-shaped frame with the attribute container must be
-- routed through the shared attribute path despite the Retail flag being false.
local attributeFrame = NewAttributeFrame()
_G.Triage:UpdateStockAuraVisibility(attributeFrame)
assertEqual(attributeFrame.attributes["ignore-buffs"], true, "classic attribute frame should hide stock buffs via attributes")
assertEqual(attributeFrame.attributes["max-buffs"], 0, "classic attribute frame should suppress buff container frames")
assertEqual(attributeFrame.attributes["ignore-debuffs"], false, "classic attribute frame should leave enabled debuffs alone")
assertEqual(attributeFrame.attributes["update-settings"], true, "classic attribute frame should notify Blizzard_PrivateAurasUI")
assertEqual(attributeFrame.Triage_stockAuraVisibilityHooked, true, "classic attribute frame should hook SetPrivateAuraAnchorSettings")

-- Blizzard rewriting anchor settings must re-assert Triage's visibility state
attributeFrame.attributes["max-buffs"] = 3
attributeFrame:SetPrivateAuraAnchorSettings()
assertEqual(attributeFrame.attributes["max-buffs"], 0, "settings rewrite should re-apply the suppressed buff container")

-- Re-enable: attributes restored from the captured base values
_G.Triage.db.profile.showBuffs = true
_G.Triage:UpdateStockAuraVisibility(attributeFrame)
assertEqual(attributeFrame.attributes["ignore-buffs"], false, "re-enabled stock buffs should clear ignore-buffs")
assertEqual(attributeFrame.attributes["max-buffs"], 3, "re-enabled stock buffs should restore base max-buffs")

-- Legacy fallback: a frame without the attribute container (e.g. an older
-- Classic client) still gets the OnShow-hook path, and re-enabling restores
-- frames Triage itself hid.
_G.Triage.db.profile.showBuffs = false

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

local legacyFrame = {
	buffFrames = { auraFrame },
	debuffFrames = {},
	dispelDebuffFrames = {},
}

_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(auraFrame.shown, false, "disabled stock buff frame should be hidden")
assertEqual(_G.Triage:IsHooked(auraFrame, "OnShow"), true, "disabled stock buff frame should keep OnShow hook")

_G.Triage.db.profile.showBuffs = true
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(_G.Triage:IsHooked(auraFrame, "OnShow"), false, "re-enabled stock buff frame should remove OnShow hook")
assertEqual(auraFrame.shown, true, "re-enabled stock buff frame should be shown immediately")

print("tri048_classic_stock_aura_reenable: PASS")
