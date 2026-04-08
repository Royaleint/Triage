-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

-- Import libraries
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Serialize and compress the profile for copy+paste.
---@return string @The serialized and compressed profile
function EnhancedRaidFrames:SerializeAndCompressProfile()
	local serialized = self:Serialize(self.db.profile) -- Serialize the database into a single string value
	local compressed = LibDeflate:CompressZlib(serialized) -- Compress the serialized data
	local encoded = LibDeflate:EncodeForPrint(compressed) -- Encode the compressed data for print for easy copy+paste
	return encoded
end

--- Deserialize and decompress the profile from copy+paste.
---@param input string @The input string to deserialize and decompress
function EnhancedRaidFrames:DeserializeAndDecompressProfile(input)
	-- Stop here if the input is empty
	if input == "" then
		self:Print(L["No data to import."] .. " " .. L["Aborting."])
		return
	end

	-- Decode and check if decoding worked properly
	local decoded = LibDeflate:DecodeForPrint(input)
	if not decoded then
		self:Print(L["Decoding failed."] .. " " .. L["Aborting."])
		return
	end

	-- Decompress and verify if decompression worked properly
	local decompressed = LibDeflate:DecompressZlib(decoded)
	if not decompressed then
		self:Print(L["Decompression failed."] .. " " .. L["Aborting."])
		return
	end

	-- Deserialize the data and return it back into a table format
	local success, newProfile = self:Deserialize(decompressed)

	-- If we successfully deserialize, load the new table into the database
	if success and newProfile then
		for k, v in pairs(newProfile) do
			if type(v) == "table" then
				self.db.profile[k] = CopyTable(v)
			else
				self.db.profile[k] = v
			end
		end

		-- Reload our database object with the defaults post-import
		self:InitializeDatabase()
	else
		self:Print(L["Data import Failed."] .. " " .. L["Aborting."])
	end
end
