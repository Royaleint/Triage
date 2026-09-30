-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals GetSpecialization GetSpecializationInfo C_SpecializationInfo GetNumSpecializations

local Triage = _G.Triage

local function IsBlank(value)
	return type(value) ~= "string" or value:match("^%s*$") ~= nil
end

local function EnsureDefaultsState(profile)
	profile.defaultsState = profile.defaultsState or {}
	profile.defaultsState.aura = profile.defaultsState.aura or {}
	return profile.defaultsState
end

local function CopyValue(value)
	if type(value) ~= "table" then
		return value
	end

	local copied = {}
	for k, v in pairs(value) do
		copied[k] = CopyValue(v)
	end

	return copied
end

local function NotifyIndicatorOptionsChanged()
	local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
	if AceConfigRegistry then
		AceConfigRegistry:NotifyChange("Triage Indicator Options")
	end
end

-- The player's spec index and ID. C_SpecializationInfo first; the old
-- globals exist only when the game loads its deprecation fallbacks.
local function ReadCurrentSpec()
	local specInfo = C_SpecializationInfo
	local getSpecialization = (specInfo and specInfo.GetSpecialization) or GetSpecialization
	local getSpecializationInfo = (specInfo and specInfo.GetSpecializationInfo) or GetSpecializationInfo
	local specIndex = getSpecialization and getSpecialization()
	if not specIndex then
		return nil, nil
	end

	local specID = getSpecializationInfo and getSpecializationInfo(specIndex)
	return specIndex, specID
end

function Triage:GetCurrentSpecDefaultsID()
	if not self.supportsSpecDefaults then
		return nil
	end

	local _, specID = ReadCurrentSpec()
	return specID
end

function Triage:GetCurrentSpecAuraDefaults()
	local specID = self:GetCurrentSpecDefaultsID()
	if not specID or not self.SpecDefaults then
		return nil, specID
	end

	return self.SpecDefaults[specID], specID
end

function Triage:HasCurrentSpecAuraDefaults()
	local defaults = self:GetCurrentSpecAuraDefaults()
	return defaults ~= nil
end

-- Writes a spec's aura lists into the active profile's indicator slots and
-- records the spec in defaultsState when anything was written. Data only:
-- callers decide whether to refresh the frames and the options panel.
local function WriteSpecAuraDefaults(self, defaults, specID, overwrite)
	local applied = 0
	local skipped = 0
	local baseDefaults = overwrite and self:CreateDefaults()
	local defaultIndicatorSettings = baseDefaults and baseDefaults.profile["indicator-1"]
	for i = 1, 9 do
		local auraList = defaults[i]
		local indicatorDB = self.db.profile["indicator-" .. i]
		if indicatorDB then
			if overwrite then
				for key, value in pairs(defaultIndicatorSettings) do
					indicatorDB[key] = CopyValue(value)
				end
				indicatorDB.auras = auraList or ""
				applied = applied + 1
			elseif auraList then
				if IsBlank(indicatorDB.auras) then
					indicatorDB.auras = auraList
					applied = applied + 1
				else
					skipped = skipped + 1
				end
			end
		end
	end

	if applied > 0 then
		local defaultsState = EnsureDefaultsState(self.db.profile)
		defaultsState.aura[specID] = true
	end

	return applied, skipped
end

function Triage:ApplyCurrentSpecAuraDefaults(overwrite)
	if not self.db or not self.db.profile then
		return 0, 0, nil
	end

	local defaults, specID = self:GetCurrentSpecAuraDefaults()
	if not defaults then
		-- Keep returning specID: callers print "No spec aura defaults
		-- available." only when there is no spec at all.
		return 0, 0, specID
	end

	local applied, skipped = WriteSpecAuraDefaults(self, defaults, specID, overwrite)
	if applied > 0 then
		self:RefreshConfig()
		NotifyIndicatorOptionsChanged()
	end

	return applied, skipped, specID
end

--- The spec a new profile's starter setup comes from: its ID once spec data
--- is loaded, false for a starting spec (no setup to give), nil while the
--- game is still loading spec data.
function Triage:GetStarterSpecID()
	local specInfo = C_SpecializationInfo
	if specInfo and specInfo.IsInitialized and not specInfo.IsInitialized() then
		return nil
	end

	local specIndex, specID = ReadCurrentSpec()
	local numSpecs = GetNumSpecializations and GetNumSpecializations()
	-- Anything half-loaded counts as "not yet", never as "no spec": a false
	-- here permanently skips the fill for this profile.
	if not specIndex or specIndex < 1 or not numSpecs or numSpecs < 1 then
		return nil
	end
	if specIndex > numSpecs then
		return false
	end
	if not specID or specID == 0 then
		return nil
	end

	return specID
end

--- Give the profile created this session its spec's starter aura lists once
--- the spec is known. Pass render to refresh and notify when this runs
--- outside a profile change. Returns the number of slots filled.
function Triage:ResolvePendingStarterSetup(render)
	local key = self.Triage_pendingStarterSetupKey
	if not key then
		return 0
	end
	if not self.supportsSpecDefaults or key ~= self.db:GetCurrentProfile() then
		self.Triage_pendingStarterSetupKey = nil
		return 0
	end

	local specID = self:GetStarterSpecID()
	if specID == nil then
		return 0
	end
	self.Triage_pendingStarterSetupKey = nil

	local defaults = specID and self.SpecDefaults and self.SpecDefaults[specID]
	if not defaults then
		return 0
	end

	local applied = WriteSpecAuraDefaults(self, defaults, specID, false)
	if render and applied > 0 then
		self:RefreshConfig()
		NotifyIndicatorOptionsChanged()
	end

	return applied
end
