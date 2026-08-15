-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Import libraries
local LibDispel = LibStub("LibDispel-1.0")

-- Localize globals used in hot paths (UNIT_AURA fires often; avoid repeated global lookups)
local issecretvalue = issecretvalue -- nil on Classic, where the global doesn't exist; that's fine, guards below already check for it

-- Aura filters we scan on a full update. Hoisted to a file-local constant so we don't allocate
-- a fresh table on every UNIT_AURA full-update/rescan call.
local AURA_FILTERS = { "HELPFUL", "HARMFUL" }

if Triage.needsLibClassicDurations then
	-- Set up LibClassicDurations
	local LibClassicDurations = LibStub("LibClassicDurations")
	-- LibClassicDurations registration string frozen; library API uses string-keyed registration.
	LibClassicDurations:Register("Enhanced Raid Frames")
	Triage.UnitAuraWrapper = LibClassicDurations.UnitAuraWrapper -- Wrapper function to use in place of UnitAura
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

local function SyncPreviewAuras(parentFrame)
	if not parentFrame or not parentFrame.Triage_isTestFrame or not parentFrame.Triage_testData then
		return false
	end

	parentFrame.Triage_unitAuras = parentFrame.Triage_testData.auras or {}
	Triage:UpdateIndicators(parentFrame)
	return true
end


--- Creates a listener for the UNIT_AURA event attached to a specified raid frame
---@param frame table @The raid frame to create the listener for
function Triage:CreateAuraListener(frame)
	if frame.Triage_isTestFrame then
		if frame.Triage_auraListenerFrame then
			frame.Triage_auraListenerFrame:UnregisterAllEvents()
		end
		return
	end

	-- Skip the visibility check in ShouldContinue() as we need the listener to exist even if the frame is hidden
	if not self.ShouldContinue(frame, true) then
		return
	end

	local unit = self:GetManagedFrameUnit(frame)
	if not unit then
		return
	end

	local listenerName = self:GetManagedChildFrameName(frame, "-Triage_auraListenerFrame")

	-- To stop us from creating redundant frames we should try to re-capture them when possible.
	if listenerName and _G[listenerName] then
		frame.Triage_auraListenerFrame = _G[listenerName]
		-- If we capture an old indicator frame, we should reattach it to the current unit frame.
		frame.Triage_auraListenerFrame:SetParent(frame)
	elseif frame.Triage_auraListenerFrame then
		frame.Triage_auraListenerFrame:SetParent(frame)
	else
		frame.Triage_auraListenerFrame = CreateFrame("Frame", listenerName, frame)
	end

	-- Register the unit event
	frame.Triage_auraListenerFrame:UnregisterAllEvents() -- Clear any existing events
	frame.Triage_auraListenerFrame:RegisterUnitEvent("UNIT_AURA", unit)

	-- Assign the OnEvent callback for the listener frame
	if self.supportsUnitAuraPayloads then
		frame.Triage_auraListenerFrame:SetScript("OnEvent", function(_, _, _, payload)
			self:UpdateUnitAuras(frame, payload)
		end)
	else
		frame.Triage_auraListenerFrame:SetScript("OnEvent", function()
			self:UpdateUnitAuras_Classic(frame) -- Classic uses the legacy method prior to 10.0
		end)
	end
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Scans all raid frame units and updates the unitAuras table with all auras on each unit.
function Triage:UpdateAllAuras()
	-- Iterate over all raid frame units, forcing a full refresh and re-creating the listener frame
	-- It is important that we re-create the listener frame for each unit to ensure that the listener is attached to the correct unit
	self:ForEachManagedFrame(function(frame)
		if SyncPreviewAuras(frame) then
			return
		end
		if self.usesLegacyUnitAura then
			self:UpdateUnitAuras_Classic(frame, true)
		else
			self:UpdateUnitAuras(frame, {}, true)
		end
	end)
end

--- Returns fallback when value is a secret value (aura data restricted under combat/encounter/
--- challenge-mode/PvP as of 12.1), otherwise returns value unchanged. issecretvalue() is safe to
--- call on any value including nil, so it runs before any boolean test on the returned value to
--- avoid taint from truthiness checks on secret UNIT_AURA payload fields.
---@param value any @The payload field to read
---@param fallback any @The value to substitute if value is secret
local function SafeField(value, fallback)
	if issecretvalue and issecretvalue(value) then
		return fallback
	end
	return value
end

--- Called by our UNIT_AURA listeners and is used to store unit aura information for a given unit.
--- Unit aura information for tracked auras is stored in the Triage_unitAuras table.
--- It uses the C_UnitAuras API that was added in 10.0.
---@param parentFrame table @The raid frame to update
---@param payload table @The payload from the UNIT_AURA event
---@param forceRefresh boolean @Whether or not to force a full refresh
function Triage:UpdateUnitAuras(parentFrame, payload, forceRefresh)
	if SyncPreviewAuras(parentFrame) then
		return
	end

	if not self.ShouldContinue(parentFrame) then
		return
	end
	local unit = self:GetManagedFrameUnit(parentFrame)
	if not unit then
		return
	end
	payload = payload or { isFullUpdate = true }

	-- Read payload fields into locals through the secrecy guard before any boolean test on them.
	-- Default isFullUpdate to true (not false) when secret: the full-rescan path below
	-- already degrades safely via addToAuraTable's guard, so treating "secret" as "rescan"
	-- avoids stale, never-clearing indicators instead of the previous crash.
	local isFullUpdate = SafeField(payload.isFullUpdate, true)
	local addedAuras = SafeField(payload.addedAuras, nil)
	local updatedAuraInstanceIDs = SafeField(payload.updatedAuraInstanceIDs, nil)
	local removedAuraInstanceIDs = SafeField(payload.removedAuraInstanceIDs, nil)

	-- Create a listener frame for the unit if we don't happen to have one yet, or we're forcing a re-creation
	if not parentFrame.Triage_auraListenerFrame or forceRefresh then
		self:CreateAuraListener(parentFrame)
		isFullUpdate = true -- Force a full update if we're forcing a refresh
	end
	-- Create the main table for the unit
	if not parentFrame.Triage_unitAuras then
		parentFrame.Triage_unitAuras = {}
		isFullUpdate = true -- Force a full update if we don't have a table for the unit yet
	end

	-- Flag to determine if we need to run an update on the indicators since we only care about select auras
	-- This should filter out a lot of unnecessary updates from triggering an indicator update
	local shouldRunUpdate = false
	-- If we get a full update signal, reset the table and rescan all auras for the unit
	if isFullUpdate then
		-- Remember whether we had anything tracked before the wipe below. Triage_unitAuras is
		-- keyed by auraInstanceID (not array-indexed) on retail, so next() is the correct
		-- emptiness check here, not #.
		local hadAurasBefore = next(parentFrame.Triage_unitAuras) ~= nil
		-- Scan into a scratch table so a mid-scan failure below (see scanOK) can't leave
		-- Triage_unitAuras partially wiped. Only committed to parentFrame.Triage_unitAuras
		-- on success.
		local previousAuras = parentFrame.Triage_unitAuras
		parentFrame.Triage_unitAuras = {}
		local scanOK = true
		-- Accumulated locally, not written straight to shouldRunUpdate: if the scan fails
		-- partway (scanOK false below) we roll back to previousAuras and must NOT report an
		-- update for auras that only ever lived in the discarded scratch table.
		local scanUpdateFlag = false
		-- Iterate through all buffs and debuffs on the unit. pcall-wrapped: AuraUtil.ForEachAura
		-- calls C_UnitAuras.GetAuraSlots, which can hard-throw ("Auras cannot be accessed when
		-- secret while tainted by...") when a tainted caller is denied unit aura access outright
		-- under restriction — a distinct failure class from the secret-*value* taint addToAuraTable
		-- already guards against, and one issecretvalue() cannot detect in advance.
		for _, filter in pairs(AURA_FILTERS) do
			local ok = pcall(AuraUtil.ForEachAura, unit, filter, nil, function(auraData)
				-- Add our auraData to the Triage_unitAuras table
				if self:addToAuraTable(parentFrame, auraData) then
					scanUpdateFlag = true
				end
			end, true)
			if not ok then
				scanOK = false
				break
			end
		end
		if scanOK then
			if scanUpdateFlag then
				shouldRunUpdate = true
			end
			-- If every previously-tracked aura is gone after the rescan (whether genuinely
			-- expired, or dropped by the secrecy guard in addToAuraTable), we still need to run
			-- the indicator update to clear them — otherwise they go stale/pinned on cached data
			-- instead of clearing.
			if hadAurasBefore and not next(parentFrame.Triage_unitAuras) then
				shouldRunUpdate = true
			end
		else
			-- Access was denied partway through the scan. Discard the partial scratch table and
			-- keep the last-known-good display instead of leaving indicators wiped or half-updated.
			parentFrame.Triage_unitAuras = previousAuras
		end
	end

	-- If one or more new auras were added, update the table with their payload information
	if addedAuras then
		for _, auraData in pairs(addedAuras) do
			-- Add our auraData to the Triage_unitAuras table
			local updateFlag = self:addToAuraTable(parentFrame, auraData)
			if updateFlag then
				shouldRunUpdate = true
			end
		end
	end

	-- If one or more auras were updated, query their updated information and add it to the table
	if updatedAuraInstanceIDs then
		for _, auraInstanceID in pairs(updatedAuraInstanceIDs) do
			-- Skip instance IDs that are themselves secret under restriction: C_UnitAuras only
			-- accepts secret arguments from untainted callers, and addon code is tainted.
			if not (issecretvalue and issecretvalue(auraInstanceID)) then
				-- pcall-wrapped: GetAuraDataByAuraInstanceID shares the RequiresUnitAuraAccess
				-- precondition with GetAuraSlots above, so it can hard-throw on a denied access
				-- even when auraInstanceID itself isn't secret. Not yet observed crashing live,
				-- but same failure class, same guard.
				local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
				-- Though rare, it is possible for auraData to be nil if the aura was removed just prior to us querying it.
				if ok and auraData then
					-- Add our auraData to the Triage_unitAuras table
					local updateFlag = self:addToAuraTable(parentFrame, auraData)
					if updateFlag then
						shouldRunUpdate = true
					end
				end
				-- if not ok: access was denied for this instance ID this tick; skip it, no crash
			end
		end
	end

	-- If one or more auras was removed, remove them from the table
	if removedAuraInstanceIDs then
		for _, auraInstanceID in pairs(removedAuraInstanceIDs) do
			-- Skip instance IDs that are secret: secret-as-table-key semantics are undocumented,
			-- so don't risk using one to index Triage_unitAuras.
			if not (issecretvalue and issecretvalue(auraInstanceID)) then
				if parentFrame.Triage_unitAuras[auraInstanceID] then
					-- Set the table entry to nil to remove it
					parentFrame.Triage_unitAuras[auraInstanceID] = nil
					shouldRunUpdate = true
				end
			end
		end
	end

	-- Only update the indicators if we added, updated, or removed a tracked aura
	if shouldRunUpdate then
		self:UpdateIndicators(parentFrame)
	end
end

--- Add or update an aura to the ERFAuras table
---@param parentFrame table @The raid frame that we're updating
---@param auraData table @Payload from UNIT_AURA event
---@return boolean @True if we added or updated an aura
function Triage:addToAuraTable(parentFrame, auraData)
	-- Skip auras with secret values from C_Secrets (M+, rated PvP, and — as of 12.1 — routine
	-- combat/encounter/challenge-mode restrictions). issecretvalue() is safe to call on any
	-- value including nil, so it runs before any boolean tests on aura fields to avoid taint
	-- from truthiness checks. Covers every auraData field this function or AuraIndicators.lua
	-- reads without its own guard, so any aura that reaches Triage_unitAuras is secret-field-free.
	if issecretvalue and (
		issecretvalue(auraData.name)
		or issecretvalue(auraData.spellId)
		or issecretvalue(auraData.dispelName)
		or issecretvalue(auraData.isHelpful)
		or issecretvalue(auraData.isHarmful)
		or issecretvalue(auraData.auraInstanceID)
		or issecretvalue(auraData.expirationTime)
		or issecretvalue(auraData.duration)
		or issecretvalue(auraData.applications)
		or issecretvalue(auraData.icon)
		or issecretvalue(auraData.sourceUnit)
		or issecretvalue(auraData.timeMod)
	) then
		return false
	end

	-- Skip auras with nil names (defensive)
	if not auraData.name then
		return false
	end

	-- Note: bleed debuff injection removed — LibDispel does not export a bleed spell ID list.
	-- DispelList.Bleed only indicates if the player can dispel bleeds (Evoker Cauterizing Flame).
	-- Bleed detection via a maintained spell ID table is a candidate for a future release.
	-- Quickly check if we're watching for this aura, and ignore if we aren't
		-- It's important to use the 4th argument in string.find to turn off pattern matching,
	-- otherwise strings with parentheses in them will fail to be found
	if self.allAuras:find(" " .. auraData.name:lower() .. " ", 1, true)
			or (auraData.spellId and self.allAuras:find(" " .. tostring(auraData.spellId) .. " ", 1, true))
			-- Check if the aura is a debuff, if aura string contains the "dispel" wildcard, and if the player can dispel this type
			or (auraData.isHarmful and self.allAuras:find("dispel", 1, true) and auraData.dispelName and LibDispel:GetMyDispelTypes()[auraData.dispelName])
			-- Check if the aura is a debuff, and if it has a dispelName see if we're tracking the wildcard for it
			or (auraData.isHarmful and auraData.dispelName and auraData.dispelName ~= "" and self.allAuras:find(auraData.dispelName:lower(), 1, true)) then

		-- Lowercase the aura name for consistency
		auraData.name = auraData.name:lower()

		if auraData.auraInstanceID then
			-- For 10.0 and newer
			-- Add our auraData to the Triage_unitAuras table using the auraInstanceID as the key
			parentFrame.Triage_unitAuras[auraData.auraInstanceID] = auraData
		else
			-- For 9.x and older
			-- Append our auraData to the Triage_unitAuras table
			table.insert(parentFrame.Triage_unitAuras, auraData)
		end

		-- Return true if we added or updated an aura
		return true
	end
end

--- Called by our UNIT_AURA listeners and is used to store unit aura information for a given unit.
--- Unit aura information for tracked auras is stored in the Triage_unitAuras table.
--- This function is less optimized than :UpdateUnitAuras(), but is still required for Classic and Classic Era.
---@param parentFrame table @The raid frame to update
---@param forceRefresh boolean @Whether or not to force a full refresh
function Triage:UpdateUnitAuras_Classic(parentFrame, forceRefresh)
	if SyncPreviewAuras(parentFrame) then
		return
	end

	if not self.ShouldContinue(parentFrame) then
		return
	end

	local unit = self:GetManagedFrameUnit(parentFrame)
	if not unit then
		return
	end

	-- Create a listener frame for the unit if we don't happen to have one yet, or we're forcing a re-creation
	if not parentFrame.Triage_auraListenerFrame or forceRefresh then
		self:CreateAuraListener(parentFrame)
	end

	-- Keep a record of how many auras we had previously
	local numPreviousAuras = 0
	if parentFrame.Triage_unitAuras then
		numPreviousAuras = #parentFrame.Triage_unitAuras
	end

	-- Create or clear out the tables for the unit
	parentFrame.Triage_unitAuras = {}

	-- Iterate through all buffs and debuffs on the unit
	for _, filter in pairs(AURA_FILTERS) do
		-- Counter to keep track of our aura index
		local auraIndex = 1

		-- Loop through all auras on the unit until we run out
		repeat
			local shouldStop = false
			local auraData = {}

			if not self.needsLibClassicDurations then
				auraData.name, auraData.icon, auraData.applications, auraData.dispelName, auraData.duration, auraData.expirationTime,
				auraData.sourceUnit, _, _, auraData.spellId, _, _, _, _, auraData.timeMod = UnitAura(unit, auraIndex, filter)
			else
				-- For wow classic we use LibClassicDurations instead of UnitAura() because by default the
				-- game doesn't provide any aura duration information.
				auraData.name, auraData.icon, auraData.applications, auraData.dispelName, auraData.duration, auraData.expirationTime,
				auraData.sourceUnit, _, _, auraData.spellId, _, _, _, _, auraData.timeMod = self.UnitAuraWrapper(unit, auraIndex, filter)
			end

			-- Verify that we have an aura name as a proxy for if we've run out of auras to scan
			if auraData.name then
				-- Set our isHelpful/isHarmful flags to match the C_UnitAuras API syntax for compatibility with the rest of the addon
				if filter == "HELPFUL" then
					auraData.isHelpful = true
				elseif filter == "HARMFUL" then
					auraData.isHarmful = true
				end

				-- Add our auraIndex into the table
				auraData.auraIndex = auraIndex

				-- Add our auraData to the Triage_unitAuras table
				self:addToAuraTable(parentFrame, auraData)
			else
				shouldStop = true
			end

			-- Increment the aura index counter
			auraIndex = auraIndex + 1
		until (shouldStop)
	end

	-- Only update the indicators if we have at least 1 tracked aura in our table
	-- or if we had a tracked aura in our table previously and now we don't (to clear indicators)
	if #parentFrame.Triage_unitAuras > 0 or (#parentFrame.Triage_unitAuras == 0 and numPreviousAuras ~= 0) then
		self:UpdateIndicators(parentFrame)
	end
end
