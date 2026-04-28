-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Slice 1 ships the schema surface only. Content entries are added only after
-- live readability checks prove which fields are safe in each content type.
--
-- Expected future entry shape:
-- [spellID] = {
--     label = "Internal note",
--     content = "Retail Midnight S1",
--     expectedDispelType = "Magic",
--     priority = 80, -- 0-100, higher means more urgent
--     readableFields = {
--         spellID = true,
--         duration = false,
--         stacks = false,
--     },
--     fallback = "active-only",
-- }
Triage.DispelWhitelist = {}

function Triage:GetDispelWhitelistEntry(spellID)
	if not spellID then
		return nil
	end

	return self.DispelWhitelist[spellID]
end
