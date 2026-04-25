-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals GetSpecialization GetSpecializationInfo

local EnhancedRaidFrames = _G.EnhancedRaidFrames

local function IsBlank(value)
	return type(value) ~= "string" or value:match("^%s*$") ~= nil
end

local function EnsureDefaultsState(profile)
	profile.defaultsState = profile.defaultsState or {}
	profile.defaultsState.aura = profile.defaultsState.aura or {}
	return profile.defaultsState
end

local function NotifyIndicatorOptionsChanged()
	local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
	if AceConfigRegistry then
		AceConfigRegistry:NotifyChange("Triage Indicator Options")
	end
end

function EnhancedRaidFrames:GetCurrentSpecDefaultsID()
	if self.isWoWClassicEra or self.isWoWClassic then
		return nil
	end

	local specIndex = GetSpecialization and GetSpecialization()
	if not specIndex then
		return nil
	end

	local specID = GetSpecializationInfo and GetSpecializationInfo(specIndex)
	return specID
end

function EnhancedRaidFrames:GetCurrentSpecAuraDefaults()
	local specID = self:GetCurrentSpecDefaultsID()
	if not specID or not self.SpecDefaults then
		return nil, specID
	end

	return self.SpecDefaults[specID], specID
end

function EnhancedRaidFrames:HasCurrentSpecAuraDefaults()
	local defaults = self:GetCurrentSpecAuraDefaults()
	return defaults ~= nil
end

function EnhancedRaidFrames:ApplyCurrentSpecAuraDefaults(overwrite)
	if not self.db or not self.db.profile then
		return 0, 0, nil
	end

	local defaults, specID = self:GetCurrentSpecAuraDefaults()
	if not defaults then
		return 0, 0, specID
	end

	local applied = 0
	local skipped = 0
	for i = 1, 9 do
		local auraList = defaults[i]
		local indicatorDB = self.db.profile["indicator-" .. i]
		if auraList and indicatorDB then
			if overwrite or IsBlank(indicatorDB.auras) then
				indicatorDB.auras = auraList
				applied = applied + 1
			else
				skipped = skipped + 1
			end
		end
	end

	if applied > 0 then
		local defaultsState = EnsureDefaultsState(self.db.profile)
		defaultsState.aura[specID] = true
		self:RefreshConfig()
		NotifyIndicatorOptionsChanged()
	end

	return applied, skipped, specID
end
