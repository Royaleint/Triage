-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage
local LibRangeCheck = LibStub("LibRangeCheck-3.0")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

-- Each entry names either a frame field (always present on both client
-- families) or a Blizzard getter global (present on some clients only --
-- CompactUnitFrame_GetOptionShowDispelIndicatorOverlay does not exist on
-- Retail 12.1) that holds Blizzard's own genuine value for the attribute.
-- negate marks the three keys Blizzard itself stores inverted from the
-- option that drives them.
local STOCK_AURA_ATTRIBUTES = {
	{ option = "showBuffs", attribute = "ignore-buffs", hiddenValue = true,
		getterName = "CompactUnitFrame_GetOptionDisplayBuffs", negate = true },
	{ option = "showDebuffs", attribute = "ignore-debuffs", hiddenValue = true,
		getterName = "CompactUnitFrame_GetOptionDisplayDebuffs", negate = true },
	{ option = "showDispellableDebuffs", attribute = "ignore-dispel-debuffs", hiddenValue = true,
		getterName = "CompactUnitFrame_GetOptionDisplayDispelDebuffs", negate = true },
	{ option = "showBuffs", attribute = "max-buffs", hiddenValue = 0, frameField = "maxBuffs" },
	{ option = "showDebuffs", attribute = "max-debuffs", hiddenValue = 0, frameField = "maxDebuffs" },
	{ option = "showDispellableDebuffs", attribute = "max-dispel-debuffs", hiddenValue = 0, frameField = "maxDispelDebuffs" },
	{ option = "showBuffs", attribute = "show-big-defensive", hiddenValue = false,
		getterName = "CompactUnitFrame_GetOptionShowBigDefensive" },
	{ option = "showDispellableDebuffs", attribute = "show-dispel-indicator-overlay", hiddenValue = false,
		getterName = "CompactUnitFrame_GetOptionShowDispelIndicatorOverlay" },
}

-- Whether this client has the attribute's genuine source at all. A frame
-- field is always present; a getter is only present when the client's own
-- CompactUnitFrame.lua defines it. This gates both directions: an attribute
-- with no source on this client is never suppressed and never restored,
-- because there is nothing Blizzard-owned to fall back to either way.
local function AttributeSourceExists(mapping)
	if mapping.frameField then
		return true
	end
	return type(rawget(_G, mapping.getterName)) == "function"
end

-- Blizzard's own genuine value for one attribute, read fresh from a
-- Blizzard-owned source every time -- a frame field or a Blizzard getter --
-- and never from anything Triage itself wrote. available is false only when
-- the source could not be read right now (no optionTable yet, or a secret
-- value); a getter that legitimately returns nil or false is still a real
-- reading, so value and availability are returned separately rather than
-- folded into one nil-means-either result.
local function GenuineAttributeValue(frame, mapping)
	if mapping.frameField then
		local value = frame[mapping.frameField]
		if issecretvalue and issecretvalue(value) then
			return nil, false
		end
		return value, true
	end

	-- Every one of these getters indexes frame.optionTable unguarded.
	if type(frame.optionTable) ~= "table" then
		return nil, false
	end

	local getter = rawget(_G, mapping.getterName)
	if type(getter) ~= "function" then
		return nil, false
	end

	local value = getter(frame)
	if issecretvalue and issecretvalue(value) then
		return nil, false
	end

	if mapping.negate then
		value = not value
	end

	return value, true
end

local function GetFriendRangeChecker(range)
	return LibRangeCheck:GetFriendMinChecker(range, InCombatLockdown() == true)
end

local function ApplyRangeAlpha(addon, frame, rangeChecker)
	local effectiveUnit = addon:GetManagedFrameUnit(frame)
	if not effectiveUnit then
		frame:SetAlpha(1)
		return
	end

	if rangeChecker then
		local inRange = rangeChecker(effectiveUnit)
		if not inRange then
			frame:SetAlpha(addon.db.profile.rangeAlpha)
		else
			frame:SetAlpha(1)
		end
	else
		frame:SetAlpha(1)
	end
end

local function IsRetailPrivateAuraContainer(frame)
	return frame and type(frame.SetPrivateAuraAnchorSettings) == "function" and type(frame.SetAttribute) == "function"
			and type(frame.GetAttribute) == "function"
end

--- Set the visibility on the stock buff/debuff frames
function Triage:UpdateAllStockAuraVisibility()
	self:ForEachManagedFrame(function(frame)
		self:UpdateStockAuraVisibility(frame)
	end)

	-- In retail, there's a special type of boss aura called a "private aura" that is not accessible to addons.
	-- We can attempt to hide these auras by hooking the default CompactUnitFrame_UpdatePrivateAuras function.
	if self.supportsPrivateAuraSuppression then
		if CompactUnitFrame_UpdatePrivateAuras and not self:IsHooked("CompactUnitFrame_UpdatePrivateAuras") then
			self:SecureHook("CompactUnitFrame_UpdatePrivateAuras", function(frame)
				self:UpdatePrivateAuraVisOverrides(frame)
			end)
		end
	end
end

--- Apply stock aura visibility via Blizzard_PrivateAurasUI attributes (Retail 12.0.5+, Classic Era 1.15.9+, Mists Classic 5.5.4+).
---@param frame table @The frame to update
---@param notifyPrivateAuraUI boolean|nil @Whether to signal Blizzard_PrivateAurasUI to reread settings
function Triage:ApplyRetailStockAuraVisibility(frame, notifyPrivateAuraUI)
	-- The per-frame settings hook below cannot be removed once installed, so this
	-- is the one place that has to re-test ownership itself rather than trust
	-- whatever admitted the frame earlier: a de-owned frame's hook still fires.
	if not self:IsOwnableFrame(frame) then
		return false
	end

	if not IsRetailPrivateAuraContainer(frame) then
		return false
	end

	if InCombatLockdown() then
		self.Triage_pendingStockAuraVisibilityUpdate = true
		return true
	end

	-- Triage_stockAuraVisibilityApplied means "this frame currently carries
	-- Triage-suppressed values", not "has been touched once". With every
	-- switch on and nothing suppressed, Blizzard's own settings already
	-- stand, so there is nothing to write and nothing to announce.
	local suppressing = not (self.db.profile.showBuffs and self.db.profile.showDebuffs
			and self.db.profile.showDispellableDebuffs)
	if not suppressing and not frame.Triage_stockAuraVisibilityApplied then
		return true
	end

	-- Restoring can land on a source that isn't readable this instant (no
	-- optionTable yet, a secret value). When that happens the flag stays set
	-- so the next apply tries that attribute again instead of the frame
	-- getting stuck showing Blizzard's stock icons forever.
	local everyRestoredSourceRead = true

	for _, mapping in ipairs(STOCK_AURA_ATTRIBUTES) do
		if AttributeSourceExists(mapping) then
			if self.db.profile[mapping.option] then
				-- Turning a switch back on hands the attribute back to whatever
				-- Blizzard's own setting says, not to a value Triage remembered.
				local genuine, available = GenuineAttributeValue(frame, mapping)
				if available then
					frame:SetAttribute(mapping.attribute, genuine)
				else
					everyRestoredSourceRead = false
				end
			else
				frame:SetAttribute(mapping.attribute, mapping.hiddenValue)
			end
		end
	end

	if suppressing then
		frame.Triage_stockAuraVisibilityApplied = true
	elseif everyRestoredSourceRead then
		frame.Triage_stockAuraVisibilityApplied = nil
	end

	if notifyPrivateAuraUI then
		frame.Triage_privateAuraSettingsVersion = not frame.Triage_privateAuraSettingsVersion
		frame:SetAttribute("update-settings", frame.Triage_privateAuraSettingsVersion)
	end

	return true
end

--- Ensure Blizzard setting rewrites cannot restore stock auras over Triage indicators.
---@param frame table @The frame to hook
function Triage:EnsureRetailStockAuraVisibilityHook(frame)
	if not self:IsOwnableFrame(frame) then
		return false
	end

	if not IsRetailPrivateAuraContainer(frame) then
		return false
	end

	if not frame.Triage_stockAuraVisibilityHooked then
		frame.Triage_stockAuraVisibilityHooked = true
		hooksecurefunc(frame, "SetPrivateAuraAnchorSettings", function(hookedFrame)
			-- Blizzard calls this from inside its own secure SetUnit and
			-- settings-update code. Running the apply here writes secure
			-- attributes on Blizzard's own stack, so on Retail this only
			-- marks the frame for the shared deferred flush and returns.
			-- Classic-family clients never get that flush set up, so they
			-- keep applying right here, same as before.
			if self.usesLegacyUnitAura then
				self:ApplyRetailStockAuraVisibility(hookedFrame, nil)
				return
			end
			if not self:IsOwnableFrame(hookedFrame) then
				return
			end
			if self.MarkFramePendingStockAura then
				self:MarkFramePendingStockAura(hookedFrame)
			end
		end)
	end

	return true
end

--- Set the visibility on the stock buff/debuff frames for a single frame
--- This function hooks the "OnShow" event of the stock buff/debuff frames.
---@param frame table @The frame to set the visibility on
function Triage:UpdateStockAuraVisibility(frame)
	if frame.Triage_isTestFrame then
		return
	end

	if not self:IsOwnableFrame(frame) then
		return
	end

	-- Route by frame capability, not client flavor: Classic Era 1.15.9 and Mists
	-- Classic 5.5.4 ship the same attribute-based private-aura container as Retail
	-- (and removed the legacy buffFrames/debuffFrames tables). Frames without the
	-- container fall through to the legacy OnShow-hook path below.
	if self:EnsureRetailStockAuraVisibilityHook(frame) then
		if not self.ShouldContinue(frame, true) then
			return
		end

		self:ApplyRetailStockAuraVisibility(frame, true)
		return
	end

	if not self.ShouldContinue(frame) then
		return
	end

	-- Tables to track the stock buff/debuff frames and their visibility flags in our database
	local allAuraFrames = { frame.buffFrames, frame.debuffFrames, frame.dispelDebuffFrames }
	local auraVisibilityFlags = { self.db.profile.showBuffs, self.db.profile.showDebuffs, self.db.profile.showDispellableDebuffs }
	local unhookedAny = false

	-- Iterate through the stock buff/debuff/dispelDebuff frame types
	for i, auraFrames in ipairs(allAuraFrames) do
		if not auraFrames then
			break
		end

		-- Iterate through the individual buff/debuff/dispelDebuff frames
		for _, auraFrame in pairs(auraFrames) do
			-- Set our hook to override "OnShow" on the frame based on the visibility flag in our database
			if not auraVisibilityFlags[i] then
				-- Query the specific visibility flag for this frame type
				if not self:IsHooked(auraFrame, "OnShow") then
					-- Be careful not to hook the same frame multiple times
					self:SecureHookScript(auraFrame, "OnShow", function(shownFrame)
						shownFrame:Hide()
					end)
				end
				-- Hide frame immediately as well, otherwise some already shown frames will remain visible
				auraFrame:Hide()
			elseif self:IsHooked(auraFrame, "OnShow") then
				-- Unhook the frame if it's hooked and we want to return it to the default behavior
				self:Unhook(auraFrame, "OnShow")
				unhookedAny = true
			end
		end
	end

	-- Re-enabling a category: let Blizzard rebuild the icons from the unit's current aura
	-- state instead of restoring visibility ourselves. We only ever hid these frames, never
	-- refreshed their texture/cooldown data, so a frame whose aura expired while suppressed
	-- would still be holding a stale icon if we just called Show() on it directly.
	-- No combat-lockdown deferral needed: like the Hide()/Show() calls above, this only
	-- touches plain texture/cooldown regions on these sub-frames, not secure attributes.
	if unhookedAny and CompactUnitFrame_UpdateAuras then
		CompactUnitFrame_UpdateAuras(frame)
	end
end

--- Set the visibility on the private buff/debuff frames
--- This function is secure hooked to the CompactUnitFrame_UpdateAuras function.
--- We can't hide the private aura frames directly, so we'll hide their anchor frames instead.
---@param frame table @The frame to set the visibility on
function Triage:UpdatePrivateAuraVisOverrides(frame)
	if frame.Triage_isTestFrame then
		return
	end

	if not self.ShouldContinue(frame) then
		return
	end

	-- If we don't have any private auras, stop here
	if not frame.PrivateAuraAnchors then
		return
	end

	-- Use our debuff visibility flag because that's where these auras are anchored by default
	if not self.db.profile.showDebuffs then
		-- Try to "hide" the private aura by clearing the attachment of its anchor frame and hiding the anchor frame
		for _, auraAnchor in ipairs(frame.PrivateAuraAnchors) do
			auraAnchor:ClearAllPoints()
			auraAnchor:Hide()
		end
	end
end

--- Updates the frame alpha based on if a unit is in range or not.
--- Hooked to CompactUnitFrame_UpdateInRange and CompactUnitFrame_UpdateCenterStatusIcon.
---@param frame table @The frame to update the alpha on
---@param rangeChecker function|nil @Optional cached LibRangeCheck checker for this update pass
function Triage:UpdateInRange(frame, rangeChecker)
	if not self.ShouldContinue(frame, true) then
		return
	end

	if frame.Triage_isTestFrame then
		local previewData = frame.Triage_testData
		if not previewData then
			frame:SetAlpha(1)
			return
		end

		if not self.db.profile.customRangeCheck then
			frame:SetAlpha(previewData.status == "offline" and 0.7 or 1)
			return
		end

		if previewData.status ~= "alive" or not previewData.inRange then
			frame:SetAlpha(self.db.profile.rangeAlpha)
		else
			frame:SetAlpha(1)
		end
		return
	end

	if not self.db.profile.customRangeCheck then
		if not self.isRetail then
			ApplyRangeAlpha(self, frame, rangeChecker or GetFriendRangeChecker(40))
		end
		-- Default range: Blizzard handles 40yd range correctly via privileged code
		-- (immune to C_Secrets). frame.outOfRange, GetAlpha(), and UnitInRange() are
		-- all secret-tainted and unreadable from addon code. Let Blizzard's hardcoded
		-- 0.3 alpha stand on Retail. Classic-family clients can safely override stale
		-- combat fades with LibRangeCheck; if no safe checker exists, keep frames visible.
		-- Users who want custom dim alpha should enable Custom Range.
		return
	end

	-- Custom range: use LibRangeCheck since Blizzard only checks the default 40yd boundary.
	-- CompactUnitFrame_UpdateInRange only flips when Blizzard's UnitInRange state changes,
	-- so crossing a custom threshold inside 40yd needs our own polling pass.
	ApplyRangeAlpha(self, frame, rangeChecker or GetFriendRangeChecker(self.db.profile.customRange))
end

--- Update the range alpha state for all active compact frames.
function Triage:UpdateAllRanges()
	local rangeChecker
	if self.db.profile.customRangeCheck then
		rangeChecker = GetFriendRangeChecker(self.db.profile.customRange)
	elseif not self.isRetail then
		rangeChecker = GetFriendRangeChecker(40)
	end

	self:ForEachManagedFrame(function(frame)
		self:UpdateInRange(frame, rangeChecker)
	end)
end

--- Start or stop the custom range polling timer based on the user's settings.
function Triage:RefreshRangeTicker()
	if self.rangeTicker then
		self:CancelTimer(self.rangeTicker)
		self.rangeTicker = nil
	end
	if self.triageFocusTicker then
		self:CancelTimer(self.triageFocusTicker)
		self.triageFocusTicker = nil
	end

	if self.db.profile.customRangeCheck then
		-- Blizzard only updates its in-range state when the native 40yd result changes.
		-- Poll custom ranges so frames recover immediately after crossing the configured threshold.
		self.rangeTicker = self:ScheduleRepeatingTimer(function()
			self:UpdateAllRanges()
		end, 0.2)
	end

	if self:IsTriageFocusActive() then
		self.triageFocusTicker = self:ScheduleRepeatingTimer(function()
			self:UpdateTriageFocus()
		end, self:GetTriageFocusUpdateInterval())
	end
end

--- Set the background alpha amount based on a defined value by the user.
---@param frame table @The frame to set the background alpha on
function Triage:UpdateBackgroundAlpha(frame)
	if not self.ShouldContinue(frame) then
		return
	end

	-- Set the background alpha to the user defined value
	if frame.background then
		frame.background:SetAlpha(self.db.profile.backgroundAlpha)
	end
end

--- Set the scale of the overall raid frame container.
function Triage:UpdateScale()
	if not InCombatLockdown() then
		if CompactRaidFrameContainer then
			CompactRaidFrameContainer:SetScale(self.db.profile.frameScale)
		end
		if CompactPartyFrame then
			CompactPartyFrame:SetScale(self.db.profile.frameScale)
		end
		if self.testModeFrames and self.testModeFrames.container then
			self.testModeFrames.container:SetScale(self.db.profile.frameScale)
		end
	end
end
