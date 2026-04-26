-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals SetRaidTargetIconTexture

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

local floor = math.floor

local RAID_TARGET_FALLBACK_UNITS = {
	"target",
	"focus",
	"mouseover",
	"player",
}

for i = 1, 4 do
	RAID_TARGET_FALLBACK_UNITS[#RAID_TARGET_FALLBACK_UNITS + 1] = "party" .. i
end

for i = 1, 40 do
	RAID_TARGET_FALLBACK_UNITS[#RAID_TARGET_FALLBACK_UNITS + 1] = "raid" .. i
end

for i = 1, 5 do
	RAID_TARGET_FALLBACK_UNITS[#RAID_TARGET_FALLBACK_UNITS + 1] = "boss" .. i
end

local function IsSecretValue(value)
	return issecretvalue and issecretvalue(value)
end

local function GetRaidTargetIndexByGUID(unit)
	local index = GetRaidTargetIndex(unit)
	if index or IsSecretValue(index) then
		return index
	end

	local unitGUID = UnitGUID(unit)
	if not unitGUID or IsSecretValue(unitGUID) then
		return nil
	end

	for _, fallbackUnit in ipairs(RAID_TARGET_FALLBACK_UNITS) do
		if fallbackUnit ~= unit and UnitExists(fallbackUnit) then
			local fallbackGUID = UnitGUID(fallbackUnit)
			if fallbackGUID and not IsSecretValue(fallbackGUID) and fallbackGUID == unitGUID then
				index = GetRaidTargetIndex(fallbackUnit)
				if index or IsSecretValue(index) then
					return index
				end
			end
		end
	end
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Create a target marker for a given frame
---@param frame table @The frame to create the target marker for
function EnhancedRaidFrames:CreateTargetMarker(frame)
	-- Create a texture for our target marker
	frame.ERF_targetMarkerFrame = frame:CreateTexture(nil, "OVERLAY")
	self:SetTargetMarkerAppearance(frame)
end

--- Set the appearance for our target marker for a given frame
---@param frame table @The frame to set the appearance for
function EnhancedRaidFrames:SetTargetMarkerAppearance(frame)
	local targetMarker = frame.ERF_targetMarkerFrame

	local PAD = 3
	local pos = self.db.profile.markerPosition

	-- Frame dimensions can be secret numbers in Midnight — fall back to safe defaults
	local frameHeight = frame:GetHeight()
	local frameWidth = frame:GetWidth()
	if issecretvalue and (issecretvalue(frameHeight) or issecretvalue(frameWidth)) then
		frameHeight = 36
		frameWidth = 72
	end
	local markerVerticalOffset = self.db.profile.markerVerticalOffset * frameHeight - (self.db.profile.markerVerticalNudge or 0)
	local markerHorizontalOffset = self.db.profile.markerHorizontalOffset * frameWidth

	-- We probably don't want to overlap the power bar (rage, mana, energy, etc) so we need a compensation factor
	local powerBarVertOffset
	if self.db.profile.powerBarOffset and frame.powerBar and frame.powerBar:IsShown() then
		local pbHeight = frame.powerBar:GetHeight()
		if issecretvalue and issecretvalue(pbHeight) then
			pbHeight = 8
		end
		powerBarVertOffset = pbHeight + 2 -- Add 2 to not overlap the powerBar border
	else
		powerBarVertOffset = 0
	end

	-- Set position relative to frame
	targetMarker:ClearAllPoints()
	if pos == 1 then
		targetMarker:SetPoint("TOPLEFT", PAD + markerHorizontalOffset, -PAD + markerVerticalOffset)
	elseif pos == 2 then
		targetMarker:SetPoint("TOP", 0 + markerHorizontalOffset, -PAD + markerVerticalOffset)
	elseif pos == 3 then
		targetMarker:SetPoint("TOPRIGHT", -PAD + markerHorizontalOffset, -PAD + markerVerticalOffset)
	elseif pos == 4 then
		targetMarker:SetPoint("LEFT", PAD + markerHorizontalOffset, 0 + markerVerticalOffset + powerBarVertOffset / 2)
	elseif pos == 5 then
		targetMarker:SetPoint("CENTER", 0 + markerHorizontalOffset, 0 + markerVerticalOffset + powerBarVertOffset / 2)
	elseif pos == 6 then
		targetMarker:SetPoint("RIGHT", -PAD + markerHorizontalOffset, 0 + markerVerticalOffset + powerBarVertOffset / 2)
	elseif pos == 7 then
		targetMarker:SetPoint("BOTTOMLEFT", PAD + markerHorizontalOffset, PAD + markerVerticalOffset + powerBarVertOffset)
	elseif pos == 8 then
		targetMarker:SetPoint("BOTTOM", 0 + markerHorizontalOffset, PAD + markerVerticalOffset + powerBarVertOffset)
	elseif pos == 9 then
		targetMarker:SetPoint("BOTTOMRIGHT", -PAD + markerHorizontalOffset, PAD + markerVerticalOffset + powerBarVertOffset)
	end

	-- Set the marker size
	targetMarker:SetWidth(self.db.profile.markerSize)
	targetMarker:SetHeight(self.db.profile.markerSize)

	-- Clear the marker
	self:ClearTargetMarker(frame)
end

--- Reset the target marker settings to their database defaults.
function EnhancedRaidFrames:ResetTargetMarkerDefaults()
	if not self.db or not self.db.profile then
		return
	end

	local defaults = self:CreateDefaults().profile
	self.db.profile.showTargetMarkers = defaults.showTargetMarkers
	self.db.profile.markerPosition = defaults.markerPosition
	self.db.profile.markerSize = defaults.markerSize
	self.db.profile.markerAlpha = defaults.markerAlpha
	self.db.profile.markerVerticalOffset = defaults.markerVerticalOffset
	self.db.profile.markerVerticalNudge = defaults.markerVerticalNudge
	self.db.profile.markerHorizontalOffset = defaults.markerHorizontalOffset

	self:RefreshConfig()
end

--- Update the appearance of our target marker for a given frame
---@param frame table @The frame to update the appearance for
---@param setAppearance boolean @Whether or not to set the appearance of the marker
function EnhancedRaidFrames:UpdateTargetMarker(frame, setAppearance)
	if not self.ShouldContinue(frame) then
		return
	end

	local unit = self:GetManagedFrameUnit(frame)
	if not unit then
		return
	end

	-- If our target marker doesn't exist, create it
	if not frame.ERF_targetMarkerFrame then
		self:CreateTargetMarker(frame)
	else
		if setAppearance then
			self:SetTargetMarkerAppearance(frame)
		end
	end

	-- If they don't have target markers enabled, don't show anything
	if not self.db.profile.showTargetMarkers then
		self:ClearTargetMarker(frame)
		return
	end

	-- Get target marker on unit
	local index
	if frame.ERF_isTestFrame and frame.ERF_testData then
		index = frame.ERF_testData.raidTargetIndex
	else
		index = GetRaidTargetIndexByGUID(unit)
	end

	-- GetRaidTargetIndex can return a secret number in Midnight. In that case,
	-- avoid addon-side numeric comparisons/math and let Blizzard's texture helper
	-- consume the value directly, matching TargetFrameMixin:UpdateRaidTargetIcon.
	if IsSecretValue(index) then
		frame.ERF_targetMarkerFrame:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons", nil, nil, "TRILINEAR")
		if SetRaidTargetIconTexture then
			SetRaidTargetIconTexture(frame.ERF_targetMarkerFrame, index)
		end
		frame.ERF_targetMarkerFrame:SetAlpha(self.db.profile.markerAlpha)
		frame.ERF_targetMarkerFrame:Show()
		return
	end

	if index and index >= 1 and index <= 8 then
		-- Get the full texture path for the marker
		local texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
		if UnitPopupRaidTarget1ButtonMixin and UnitPopupRaidTarget1ButtonMixin.GetIcon then
			texture = UnitPopupRaidTarget1ButtonMixin:GetIcon() or texture
		end

		-- Get the texture coordinates for the marker icon
		local mixin = _G["UnitPopupRaidTarget" .. index .. "ButtonMixin"]
		local tCoordLeft, tCoordRight, tCoordTop, tCoordBottom
		if mixin and mixin.GetTextureCoords then
			tCoordLeft, tCoordRight, tCoordTop, tCoordBottom = mixin:GetTextureCoords()
		else
			-- Manual fallback: 4x2 grid of icons in the standard raid target texture
			local col = (index - 1) % 4
			local row = floor((index - 1) / 4)
			tCoordLeft = col * 0.25
			tCoordRight = (col + 1) * 0.25
			tCoordTop = row * 0.5
			tCoordBottom = (row + 1) * 0.5
		end

		-- Set the marker texture using trilinear filtering (reduces pixelation)
		frame.ERF_targetMarkerFrame:SetTexture(texture, nil, nil, "TRILINEAR")

		-- Set the texture coordinates to the correct icon of the larger texture
		frame.ERF_targetMarkerFrame:SetTexCoord(tCoordLeft, tCoordRight, tCoordTop, tCoordBottom)

		-- Set the marker opacity
		frame.ERF_targetMarkerFrame:SetAlpha(self.db.profile.markerAlpha)

		-- Show the marker
		frame.ERF_targetMarkerFrame:Show()
	else
		self:ClearTargetMarker(frame)
	end
end

--- Update the appearance of our target markers for all frames
function EnhancedRaidFrames:UpdateAllTargetMarkers()
	self:ForEachManagedFrame(function(frame)
		self:UpdateTargetMarker(frame)
	end)
end

--- Clear the target marker for a given frame
---@param frame table @The frame to clear the target marker for
function EnhancedRaidFrames:ClearTargetMarker(frame)
	local targetMarker = frame.ERF_targetMarkerFrame
	targetMarker:Hide()
	targetMarker:SetAlpha(1)
end
