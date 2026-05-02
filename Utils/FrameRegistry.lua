-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

local GROUP_UNIT_PREFIXES = {
	player = true,
	party = true,
	partypet = true,
	raid = true,
	raidpet = true,
}

local REGISTRY_UNIT_PREFIXES = {
	player = true,
	party = true,
	partypet = true,
	raid = true,
	raidpet = true,
	boss = true,
}

Triage.GROUP_UNIT_PREFIXES = GROUP_UNIT_PREFIXES
Triage.REGISTRY_UNIT_PREFIXES = REGISTRY_UNIT_PREFIXES

local function RemoveOrderedEntry(orderedEntries, entryToRemove)
	for index, entry in ipairs(orderedEntries) do
		if entry == entryToRemove then
			table.remove(orderedEntries, index)
			return
		end
	end
end

--- Initialize the managed frame registry.
function Triage:InitializeFrameRegistry()
	if self.frameRegistry then
		return
	end

	self.frameRegistry = {
		orderedEntries = {},
		entriesByFrame = {},
		seenBlizzardFrames = {},
	}
end

--- Return the registry entry for a frame if it exists.
---@param frame table
---@return table|nil
function Triage:GetManagedFrameEntry(frame)
	if not self.frameRegistry or not frame then
		return nil
	end

	return self.frameRegistry.entriesByFrame[frame]
end

--- Build a stable child-frame name when the parent frame is named.
---@param frame table
---@param suffix string
---@return string|nil
function Triage:GetManagedChildFrameName(frame, suffix)
	if not frame or not suffix then
		return nil
	end

	local frameName = frame:GetName()
	if not frameName then
		return nil
	end

	return frameName .. suffix
end

--- Return the current unit token for a managed frame.
---@param frame table
---@return string|nil
function Triage:GetManagedFrameUnit(frame)
	if not frame then
		return nil
	end

	if frame.displayedUnit then
		return frame.displayedUnit
	end

	if frame.unit then
		return frame.unit
	end

	local entry = self:GetManagedFrameEntry(frame)
	if entry and entry.unit then
		return entry.unit
	end

	return nil
end

--- Test whether a unit token is allowed for the current operation.
---@param unit string|nil
---@param allowedUnitPrefixes table|nil
---@return boolean
function Triage:IsSupportedUnitToken(unit, allowedUnitPrefixes)
	if type(unit) ~= "string" then
		return false
	end

	allowedUnitPrefixes = allowedUnitPrefixes or REGISTRY_UNIT_PREFIXES

	if unit == "player" then
		return allowedUnitPrefixes.player == true
	end
	if allowedUnitPrefixes.party and unit:match("^party%d+$") then
		return true
	end
	if allowedUnitPrefixes.partypet and unit:match("^partypet%d+$") then
		return true
	end
	if allowedUnitPrefixes.raid and unit:match("^raid%d+$") then
		return true
	end
	if allowedUnitPrefixes.raidpet and unit:match("^raidpet%d+$") then
		return true
	end
	if allowedUnitPrefixes.boss and unit:match("^boss%d+$") then
		return true
	end

	return false
end

--- Clear addon-managed state from a frame when it leaves the registry.
---@param frame table
function Triage:ClearManagedFrameState(frame)
	if not frame then
		return
	end

	if frame.Triage_auraListenerFrame then
		frame.Triage_auraListenerFrame:UnregisterAllEvents()
	end

	if frame.Triage_indicatorFrames then
		for i = 1, 9 do
			local indicatorFrame = frame.Triage_indicatorFrames[i]
			if indicatorFrame then
				self:ClearIndicator(indicatorFrame)
			end
		end
	end

	if frame.Triage_targetMarkerFrame then
		self:ClearTargetMarker(frame)
	end

	if frame.Triage_dispelOverlay then
		self:HideDispelOverlay(frame)
	end

	if frame.Triage_focusOverlay and self.HideTriageFocusOverlay then
		self:HideTriageFocusOverlay(frame)
	end

	if frame.Triage_tooltipTicker then
		self:StopClassicTooltipScanning(frame)
	end

	frame.Triage_activeTooltipIndicator = nil
	frame.Triage_unitAuras = nil
end

--- Register a frame in the central managed frame registry.
---@param frame table
---@param unit string|nil
---@param source string|nil
---@return table|nil
function Triage:RegisterManagedFrame(frame, unit, source)
	if not frame then
		return nil
	end

	self:InitializeFrameRegistry()

	local entry = self.frameRegistry.entriesByFrame[frame]
	unit = unit or frame.displayedUnit or frame.unit or (entry and entry.unit)
	if not self:IsSupportedUnitToken(unit, REGISTRY_UNIT_PREFIXES) then
		self:UnregisterManagedFrame(frame)
		return nil
	end

	if not entry then
		entry = {
			frame = frame,
		}
		self.frameRegistry.entriesByFrame[frame] = entry
		self.frameRegistry.orderedEntries[#self.frameRegistry.orderedEntries + 1] = entry
	end

	entry.unit = unit
	entry.source = source or entry.source or "addon"

	return entry
end

--- Remove a frame from the central managed frame registry.
---@param frame table
function Triage:UnregisterManagedFrame(frame)
	if not self.frameRegistry or not frame then
		return
	end

	local entry = self.frameRegistry.entriesByFrame[frame]
	if not entry then
		return
	end

	self.frameRegistry.entriesByFrame[frame] = nil
	RemoveOrderedEntry(self.frameRegistry.orderedEntries, entry)
	self:ClearManagedFrameState(frame)
end

--- Update the tracked unit token for a managed frame.
---@param frame table
---@param unit string|nil
---@param source string|nil
---@return table|nil
function Triage:UpdateManagedFrameUnit(frame, unit, source)
	return self:RegisterManagedFrame(frame, unit, source)
end

--- Register a Blizzard compact frame in the central registry.
---@param frame table
---@return table|nil
function Triage:RegisterBlizzardFrame(frame)
	return self:RegisterManagedFrame(frame, self:GetManagedFrameUnit(frame), "blizzard")
end

--- Refresh the registry entries for Blizzard-owned compact frames.
function Triage:RefreshManagedFrameRegistry()
	self:InitializeFrameRegistry()

	local registry = self.frameRegistry
	wipe(registry.seenBlizzardFrames)

	local function registerFrame(frame)
		if not frame then
			return
		end

		registry.seenBlizzardFrames[frame] = true
		self:RegisterBlizzardFrame(frame)
	end

	if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
		CompactRaidFrameContainer:ApplyToFrames("normal", registerFrame)
	elseif CompactRaidFrameContainer then
		CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal", registerFrame)
	end

	if CompactPartyFrame and CompactPartyFrame.memberUnitFrames then
		for _, frame in pairs(CompactPartyFrame.memberUnitFrames) do
			registerFrame(frame)
		end
	end

	for index = #registry.orderedEntries, 1, -1 do
		local entry = registry.orderedEntries[index]
		if entry.source == "blizzard" and not registry.seenBlizzardFrames[entry.frame] then
			self:UnregisterManagedFrame(entry.frame)
		end
	end
end

--- Apply a function to every registered frame after syncing Blizzard-owned frames.
---@param func function
function Triage:ForEachManagedFrame(func)
	self:RefreshManagedFrameRegistry()

	for _, entry in ipairs(self.frameRegistry.orderedEntries) do
		func(entry.frame, entry)
	end
end

--- Backward-compatible wrapper for older call sites.
---@param func function
function Triage.ApplyToAllFrames(func)
	Triage:ForEachManagedFrame(func)
end

--- Test whether a frame is eligible for processing.
---@param frame table
---@param skipVisibilityCheck boolean|nil
---@param allowedUnitPrefixes table|nil @Optional narrower prefix map such as GROUP_UNIT_PREFIXES
---@return boolean
function Triage.ShouldContinue(frame, skipVisibilityCheck, allowedUnitPrefixes)
	if not frame then
		return false
	end

	local unit = Triage:GetManagedFrameUnit(frame)
	if not Triage:IsSupportedUnitToken(unit, allowedUnitPrefixes) then
		return false
	end

	if not skipVisibilityCheck and not frame:IsShown() then
		return false
	end

	return true
end
