-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Import libraries
-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Serialize and compress the profile for copy+paste.
---@return string @The serialized and compressed profile
function Triage:SerializeAndCompressProfile()
	local serialized = self:Serialize(self.db.profile) -- Serialize the database into a single string value
	local compressed = LibDeflate:CompressZlib(serialized) -- Compress the serialized data
	local encoded = LibDeflate:EncodeForPrint(compressed) -- Encode the compressed data for print for easy copy+paste
	return encoded
end

-- A `false` (or other non-table) at a key whose default is a table would
-- read differently on a raw write than on a reset+copy: AceDB only treats
-- a missing table as absent (copyDefaults, AceDB-3.0.lua:118). A real
-- export never has this shape, since it serializes an already default-filled
-- profile; this only guards against a hand-edited or corrupted paste.
local function sanitizeAgainstDefaults(payload, defaults)
	for k, defaultValue in pairs(defaults) do
		if type(defaultValue) == "table" and payload[k] ~= nil then
			if type(payload[k]) == "table" then
				sanitizeAgainstDefaults(payload[k], defaultValue)
			else
				payload[k] = nil
			end
		end
	end
end

--- Decode, decompress, and sanitise a pasted profile string.
---@param input string @The input string to deserialize and decompress
---@return table|nil @The decoded profile, or nil if the input was rejected
function Triage:DeserializeAndDecompressProfile(input)
	-- Stop here if the input is empty
	if input == "" then
		self:Print(L["No data to import."] .. " " .. L["Aborting."])
		return nil
	end

	-- Decode and check if decoding worked properly
	local decoded = LibDeflate:DecodeForPrint(input)
	if not decoded then
		self:Print(L["Decoding failed."] .. " " .. L["Aborting."])
		return nil
	end

	-- Decompress and verify if decompression worked properly
	local decompressed = LibDeflate:DecompressZlib(decoded)
	if not decompressed then
		self:Print(L["Decompression failed."] .. " " .. L["Aborting."])
		return nil
	end

	-- Deserialize the data back into a table
	local success, newProfile = self:Deserialize(decompressed)
	if not (success and type(newProfile) == "table") then
		self:Print(L["Data import Failed."] .. " " .. L["Aborting."])
		return nil
	end

	sanitizeAgainstDefaults(newProfile, self:CreateDefaults().profile)
	return newProfile
end

--- The lowest-numbered free profile name starting from `base`, checked
--- against every existing profile plus the current one (even if it hasn't
--- been created yet).
---@param base string
---@return string
function Triage:NextFreeProfileName(base)
	local existing = {}
	local names = self.db:GetProfiles(existing)
	local taken = {}
	for _, name in ipairs(names) do
		taken[name] = true
	end

	if not taken[base] then
		return base
	end

	local n = 2
	while taken[base .. " " .. n] do
		n = n + 1
	end
	return base .. " " .. n
end

-- AceDB-semantics merge: a table value recurses into the destination,
-- creating it if it isn't already a table; anything else is assigned.
-- Used only for the in-place overwrite of the active profile.
local function copyProfileTable(source, dest)
	for k, v in pairs(source) do
		if type(v) == "table" then
			if type(dest[k]) ~= "table" then
				dest[k] = {}
			end
			copyProfileTable(v, dest[k])
		else
			dest[k] = v
		end
	end
end

--- Apply a decoded, sanitised profile under the given name: a full replace
--- into a new or existing target profile, or an in-place overwrite when the
--- target is the active profile (SetProfile to the same key is a no-op, so
--- that case can't go through the normal write-then-switch path).
---@param name string
---@param decoded table
function Triage:ApplyImportedProfile(name, decoded)
	if name == self.db:GetCurrentProfile() then
		self.db:ResetProfile(nil, true)
		copyProfileTable(decoded, self.db.profile)
		self:OnProfileUpdate()
	else
		self.db.profiles[name] = decoded
		self.db:SetProfile(name)
	end

	local registry = LibStub("AceConfigRegistry-3.0", true)
	if registry then
		registry:NotifyChange("Triage Profiles")
	end
	if self.OptionsFrame and self.OptionsFrame.Refresh then
		self.OptionsFrame:Refresh()
	end
end
