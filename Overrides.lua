-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames
local LibRangeCheck = LibStub("LibRangeCheck-3.0")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Set the visibility on the stock buff/debuff frames
function EnhancedRaidFrames:UpdateAllStockAuraVisibility()
	self:ForEachManagedFrame(function(frame)
		self:UpdateStockAuraVisibility(frame)
	end)

	-- In retail, there's a special type of boss aura called a "private aura" that is not accessible to addons.
	-- We can attempt to hide these auras by hooking the default CompactUnitFrame_UpdatePrivateAuras function.
	if not self.isWoWClassicEra and not self.isWoWClassic then
		if not self:IsHooked("CompactUnitFrame_UpdatePrivateAuras") then
			self:SecureHook("CompactUnitFrame_UpdatePrivateAuras", function(frame)
				self:UpdatePrivateAuraVisOverrides(frame)
			end)
		end
	end
end

--- Set the visibility on the stock buff/debuff frames for a single frame
--- This function hooks the "OnShow" event of the stock buff/debuff frames.
---@param frame table @The frame to set the visibility on
function EnhancedRaidFrames:UpdateStockAuraVisibility(frame)
	if frame.ERF_isTestFrame then
		return
	end

	if not self.ShouldContinue(frame) then
		return
	end

	-- Tables to track the stock buff/debuff frames and their visibility flags in our database
	local allAuraFrames = { frame.buffFrames, frame.debuffFrames, frame.dispelDebuffFrames }
	local auraVisibilityFlags = { self.db.profile.showBuffs, self.db.profile.showDebuffs, self.db.profile.showDispellableDebuffs }

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
			else
				if self:IsHooked(auraFrame, "OnShow") then
					-- Unhook the frame if it's hooked and we want to return it to the default behavior
					self:Unhook(auraFrame, "OnShow")
				end
			end
		end
	end
end

--- Set the visibility on the private buff/debuff frames
--- This function is secure hooked to the CompactUnitFrame_UpdateAuras function.
--- We can't hide the private aura frames directly, so we'll hide their anchor frames instead.
---@param frame table @The frame to set the visibility on
function EnhancedRaidFrames:UpdatePrivateAuraVisOverrides(frame)
	if frame.ERF_isTestFrame then
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
function EnhancedRaidFrames:UpdateInRange(frame, rangeChecker)
	if not self.ShouldContinue(frame, true) then
		return
	end

	if frame.ERF_isTestFrame then
		local previewData = frame.ERF_testData
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
		-- Default range: Blizzard handles 40yd range correctly via privileged code
		-- (immune to C_Secrets). frame.outOfRange, GetAlpha(), and UnitInRange() are
		-- all secret-tainted and unreadable from addon code. Let Blizzard's hardcoded
		-- 0.3 alpha stand. Users who want custom dim alpha should enable Custom Range.
		return
	end

	-- Custom range: use LibRangeCheck since Blizzard only checks the default 40yd boundary.
	-- CompactUnitFrame_UpdateInRange only flips when Blizzard's UnitInRange state changes,
	-- so crossing a custom threshold inside 40yd needs our own polling pass.
	local effectiveUnit = self:GetManagedFrameUnit(frame)
	rangeChecker = rangeChecker or LibRangeCheck:GetFriendMinChecker(self.db.profile.customRange)

	if rangeChecker then
		local inRange = rangeChecker(effectiveUnit)
		if not inRange then
			frame:SetAlpha(self.db.profile.rangeAlpha)
		else
			frame:SetAlpha(1)
		end
	else
		frame:SetAlpha(1)
	end
end

--- Update the range alpha state for all active compact frames.
function EnhancedRaidFrames:UpdateAllRanges()
	local rangeChecker
	if self.db.profile.customRangeCheck then
		rangeChecker = LibRangeCheck:GetFriendMinChecker(self.db.profile.customRange)
	end

	self:ForEachManagedFrame(function(frame)
		self:UpdateInRange(frame, rangeChecker)
	end)
end

--- Start or stop the custom range polling timer based on the user's settings.
function EnhancedRaidFrames:RefreshRangeTicker()
	if self.rangeTicker then
		self:CancelTimer(self.rangeTicker)
		self.rangeTicker = nil
	end

	if self.db.profile.customRangeCheck then
		-- Blizzard only updates its in-range state when the native 40yd result changes.
		-- Poll custom ranges so frames recover immediately after crossing the configured threshold.
		self.rangeTicker = self:ScheduleRepeatingTimer(function()
			self:UpdateAllRanges()
		end, 0.2)
	end
end

--- Set the background alpha amount based on a defined value by the user.
---@param frame table @The frame to set the background alpha on
function EnhancedRaidFrames:UpdateBackgroundAlpha(frame)
	if not self.ShouldContinue(frame) then
		return
	end

	-- Set the background alpha to the user defined value
	if frame.background then
		frame.background:SetAlpha(self.db.profile.backgroundAlpha)
	end
end

--- Set the scale of the overall raid frame container.
function EnhancedRaidFrames:UpdateScale()
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
