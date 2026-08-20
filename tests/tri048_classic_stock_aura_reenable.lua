-- luacheck: globals arg LibStub InCombatLockdown hooksecurefunc dofile CompactUnitFrame_UpdateAuras

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

-- Classic-family client: 1.15.9+ / 5.5.4+ frames carry the attribute-based
-- private-aura container; older Classic-family frames fall to the legacy path.
_G.Triage = {
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
-- Classic client) still gets the OnShow-hook path. Re-enabling no longer restores
-- visibility itself -- it lets Blizzard's own CompactUnitFrame_UpdateAuras rebuild
-- the frame from current aura state, so a buff that expired while suppressed can't
-- leave behind a stale icon (TRI-048 phantom-icon fix).
_G.Triage.db.profile.showBuffs = false

-- Simulates whether the unit currently has an active buff, from Blizzard's perspective.
local blizzardAuraActive = true
local updateAurasCalls = 0

-- Show() mirrors real SecureHookScript semantics: the original show runs first,
-- then a still-active OnShow hook runs after and can immediately hide it again.
local function NewLegacyAuraFrame(shown, texture)
	local auraFrame = { shown = shown, texture = texture }
	auraFrame.IsShown = function(self)
		return self.shown
	end
	auraFrame.Hide = function(self)
		self.shown = false
	end
	auraFrame.Show = function(self)
		self.shown = true
		if self.onShowHook then
			self.onShowHook(self)
		end
	end
	return auraFrame
end

local auraFrame = NewLegacyAuraFrame(true, "buff-icon")

function CompactUnitFrame_UpdateAuras(updatedFrame)
	updateAurasCalls = updateAurasCalls + 1
	assertEqual(updatedFrame.buffFrames[1], auraFrame, "Blizzard rebuild should target the raid frame Triage updated")
	if blizzardAuraActive then
		auraFrame.texture = "buff-icon"
		auraFrame:Show()
	else
		auraFrame.texture = nil
		auraFrame:Hide()
	end
end

local legacyFrame = {
	buffFrames = { auraFrame },
	debuffFrames = {},
	dispelDebuffFrames = {},
}

_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(auraFrame.shown, false, "disabled stock buff frame should be hidden")
assertEqual(_G.Triage:IsHooked(auraFrame, "OnShow"), true, "disabled stock buff frame should keep OnShow hook")
assertEqual(updateAurasCalls, 0, "suppressing should not trigger a Blizzard aura rebuild")

-- Re-enable while the buff is still active: Blizzard rebuilds and shows the current icon
_G.Triage.db.profile.showBuffs = true
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(_G.Triage:IsHooked(auraFrame, "OnShow"), false, "re-enabled stock buff frame should remove OnShow hook")
assertEqual(updateAurasCalls, 1, "re-enabling should ask Blizzard to rebuild the frame")
assertEqual(auraFrame.shown, true, "re-enabled stock buff frame should be shown when the buff is still active")
assertEqual(auraFrame.texture, "buff-icon", "re-enabled stock buff frame should show the current aura icon")

-- Phantom-icon regression: the buff expires while suppressed, then the user re-enables.
_G.Triage.db.profile.showBuffs = false
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(auraFrame.shown, false, "re-suppressed stock buff frame should be hidden")

blizzardAuraActive = false -- the buff expires while suppressed; Blizzard has no aura to show anymore

_G.Triage.db.profile.showBuffs = true
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(updateAurasCalls, 2, "re-enabling after expiry should still ask Blizzard to rebuild the frame")
assertEqual(auraFrame.shown, false, "re-enabling after the buff expired must not flash the stale icon")
assertEqual(auraFrame.texture, nil, "re-enabling after the buff expired must not retain the stale icon texture")

-- Steady-state regression: once nothing is transitioning from suppressed to enabled,
-- repeated updates (e.g. every GROUP_ROSTER_UPDATE) must not keep asking Blizzard to
-- rebuild the frame.
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(updateAurasCalls, 2, "an unchanged enabled state should not trigger another rebuild")

-- Mixed-category regression: re-enabling buffs must not resurrect a debuff that stays
-- suppressed. Blizzard's rebuild refreshes every category in one pass, so it's the
-- still-active OnShow hook on the debuff frame -- not any category-specific skip in
-- Triage -- that has to keep it hidden.
_G.Triage.db.profile.showDebuffs = false
local debuffAuraFrame = NewLegacyAuraFrame(false)
legacyFrame.debuffFrames = { debuffAuraFrame }

_G.Triage.db.profile.showBuffs = false
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(_G.Triage:IsHooked(debuffAuraFrame, "OnShow"), true, "suppressed debuff frame should be hooked")

function CompactUnitFrame_UpdateAuras(updatedFrame)
	updateAurasCalls = updateAurasCalls + 1
	assertEqual(updatedFrame, legacyFrame, "Blizzard rebuild should target the raid frame Triage updated")
	-- Blizzard's rebuild tries to show every category it has aura data for.
	auraFrame.texture = "buff-icon"
	auraFrame:Show()
	debuffAuraFrame:Show()
end

_G.Triage.db.profile.showBuffs = true
_G.Triage:UpdateStockAuraVisibility(legacyFrame)
assertEqual(updateAurasCalls, 3, "re-enabling buffs should still trigger a rebuild")
assertEqual(auraFrame.shown, true, "re-enabled buff frame should be shown by the rebuild")
assertEqual(debuffAuraFrame.shown, false, "suppressed debuff frame must stay hidden even though the rebuild tried to show it")
assertEqual(_G.Triage:IsHooked(debuffAuraFrame, "OnShow"), true, "suppressed debuff frame should keep its OnShow hook")

print("tri048_classic_stock_aura_reenable: PASS")
