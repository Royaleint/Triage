-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

-- Some healing spells change name and/or spell ID when they proc, so the
-- aura the user typed in the watch list never matches the live aura on the
-- target after the transform. The fix today is for users to list both forms
-- (one per line) in the indicator's Aura Watch List — the matcher in
-- AuraIndicators:FindActiveAndTrackedAura already supports name- and ID-based
-- matching per line.
--
-- This table catalogs the known pairs so future tooling can:
--   1. Warn at config time when only one half of a pair is listed (issue #21
--      spell validation will consume this when it lands).
--   2. Drive documentation / autocomplete suggestions in the GUI.
--
-- Each entry maps a user-facing identifier (lowercase name OR spell ID as
-- string) to the full set of related identifiers for that spell. Lookups
-- are O(1) in either direction. To extend, add new entries with all known
-- forms — keep names lowercased so consumers can normalize input cheaply.
EnhancedRaidFrames.TRANSFORM_SPELLS = {
	-- Druid: Cenarion Ward applies a buff that transforms into a HoT on damage taken.
	-- Pre-proc and post-proc auras have different spell IDs.
	["cenarion ward"]   = { "Cenarion Ward", "Cenarion Ward", 102351, 102352 },
	["102351"]          = { "Cenarion Ward", "Cenarion Ward", 102351, 102352 },
	["102352"]          = { "Cenarion Ward", "Cenarion Ward", 102351, 102352 },

	-- TODO: extend with additional confirmed transform pairs per healer spec
	-- (e.g. other Druid / Priest / Shaman / Monk / Paladin / Evoker procs).
	-- Only add entries where the pre/post forms have different spell IDs —
	-- spells that share an ID across phases already match without help.
}
