-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Spell validation + autocomplete helper for the aura watch-list config UI.
-- No WoW API is touched at file scope: every C_Spell / C_SpellBook / legacy
-- call lives inside a function, and the event frame is created on first use.

local SpellLookup = {}
Triage.SpellLookup = SpellLookup

-------------------------------------------------------------------------
-------------------------------------------------------------------------

-- Reserved wildcard words that are active (matchable) on every client. The
-- "bleed" wildcard is handled separately because dispelName == "Bleed" only
-- exists on Retail (Midnight 12.0+) — see ResolveToken / Suggest.
local RESERVED_ACTIVE = {
	"dispel",
	"magic",
	"poison",
	"curse",
	"disease",
}

-- Fast membership set for the always-active reserved words.
local RESERVED_ACTIVE_SET = {}
for _, word in ipairs(RESERVED_ACTIVE) do
	RESERVED_ACTIVE_SET[word] = true
end

-- Full reserved set (includes "bleed") used for near-miss detection regardless
-- of client; activeness is decided per-client in ResolveToken / Suggest.
local RESERVED_ALL = {
	"dispel",
	"magic",
	"poison",
	"curse",
	"disease",
	"bleed",
}

-- Case-normalized wildcard -> numeric fileID. These mirror the VALUES in
-- Globals.lua iconCache (which are keyed Capitalized — "Magic", "Poison", …),
-- so we do NOT index Triage.iconCache directly (its keys would miss a
-- lowercase token). "dispel" is a meta-wildcard (any dispellable) with no
-- iconCache key; 134400 (inv_misc_questionmark) is a verified neutral fileID.
local WILDCARD_ICON = {
	magic = 135894,
	poison = 132104,
	curse = 132095,
	disease = 132099,
	bleed = 136168,
	dispel = 134400,
}

-------------------------------------------------------------------------
-- Shared name + icon resolution
-------------------------------------------------------------------------

--- Resolve a spellID to its display name and icon, cross-client.
---@param spellID number
---@return string|nil name
---@return number|string|nil icon
function SpellLookup.ResolveNameIcon(spellID)
	if not spellID then
		return nil, nil
	end

	-- Name: prefer the all-flavor C_Spell.GetSpellName; fall back to legacy.
	local name
	if C_Spell and C_Spell.GetSpellName then
		name = C_Spell.GetSpellName(spellID)
	else
		name = GetSpellInfo(spellID)
	end

	-- Icon: C_Spell.GetSpellTexture is the Retail path; on Classic flavors that
	-- lack it the icon is the 3rd return of GetSpellInfo. Mirrors AuraIndicators.
	local icon
	if C_Spell and C_Spell.GetSpellTexture then
		icon = C_Spell.GetSpellTexture(spellID)
	else
		icon = select(3, GetSpellInfo(spellID))
	end

	return name, icon
end

-------------------------------------------------------------------------
-- Near-miss (Levenshtein-1) detection against reserved words
-------------------------------------------------------------------------

-- Return true when a and b differ by exactly one single-character edit
-- (insertion, deletion, or substitution). Early-out keeps it allocation-light.
local function IsLevenshtein1(a, b)
	local la, lb = #a, #b
	if a == b then
		return false
	end
	if math.abs(la - lb) > 1 then
		return false
	end

	if la == lb then
		-- Substitution: exactly one differing position.
		local diffs = 0
		for i = 1, la do
			if a:sub(i, i) ~= b:sub(i, i) then
				diffs = diffs + 1
				if diffs > 1 then
					return false
				end
			end
		end
		return diffs == 1
	end

	-- Insertion / deletion: walk the shorter against the longer, allowing one skip.
	local short, long = a, b
	if la > lb then
		short, long = b, a
	end
	local i, j = 1, 1
	local skipped = false
	while i <= #short and j <= #long do
		if short:sub(i, i) == long:sub(j, j) then
			i = i + 1
			j = j + 1
		elseif skipped then
			return false
		else
			skipped = true
			j = j + 1
		end
	end
	return true
end

--- Find a reserved word within one edit of the given lowercase token.
---@param token string @already lowercase
---@return string|nil @the suggested reserved word, or nil
local function NearestReservedWord(token)
	for _, word in ipairs(RESERVED_ALL) do
		if IsLevenshtein1(token, word) then
			return word
		end
	end
	return nil
end

-------------------------------------------------------------------------
-- Player spellbook enumeration (LibRangeCheck-3.0 replicated verbatim)
-------------------------------------------------------------------------

-- The legacy spellbook globals return positional values while C_SpellBook.*
-- returns structs. The aliases and translating wrappers below are copied
-- character-for-character from Libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua
-- (lib:73, 92, 93-102, 122, 123-135). Do not paraphrase: the struct->
-- positional translation and the nil-guards are load-bearing across clients.
-- (lib:74 GetSpellBookItemName is intentionally NOT copied — names come from
-- the spellID via ResolveNameIcon, not from the slot-name function; see spec
-- Gate 0.) They live inside BuildPlayerSpells so nothing touches the WoW API
-- at file scope. The one adaptation: the lib's `_G.GetSpellBookItemInfo`
-- prefix is the bare global here, matching how .luacheckrc allowlists it.

local playerSpellsCache

-- Build the cached list of known player spells via the LibRangeCheck walk.
local function BuildPlayerSpells()
	local BOOKTYPE_SPELL = BOOKTYPE_SPELL or Enum.SpellBookSpellBank.Player
	local spellTypes = {"SPELL", "FUTURESPELL", "PETACTION", "FLYOUT"}
	local GetSpellBookItemInfo = GetSpellBookItemInfo or function(index, spellBank)
		if type(spellBank) == "string" then
			spellBank = (spellBank == "spell") and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.Pet;
		end
		local info = C_SpellBook.GetSpellBookItemInfo(index, spellBank)
		--map spell-type
		if info and spellTypes[info.itemType or 0] then
			return spellTypes[info.itemType or 0] or "None", info.spellID, info
		end
	end
	local GetNumSpellTabs = GetNumSpellTabs or C_SpellBook.GetNumSpellBookSkillLines
	local GetSpellTabInfo = GetSpellTabInfo or function(index)
		local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(index);
		if skillLineInfo then
			return skillLineInfo.name,
				skillLineInfo.iconID,
				skillLineInfo.itemIndexOffset,
				skillLineInfo.numSpellBookItems,
				skillLineInfo.isGuild,
				skillLineInfo.offSpecID,
				skillLineInfo.shouldHide,
				skillLineInfo.specID;
		end
	end

	-- getNumSpells (lib:3835-3840)
	local function getNumSpells()
		local _, _, offset, numSpells = GetSpellTabInfo(GetNumSpellTabs())
		if not offset or not numSpells then
			return 0
		end
		return offset + numSpells
	end

	-- Walk every spellbook slot and keep only active-spec player spells, using
	-- the same spellType filter as LibRangeCheck's findSpellIdx (lib:3851-3856).
	-- Unlike the lib (which returns the slot index on Classic), we resolve the
	-- spellID from GetSpellBookItemInfo's 2nd return so ResolveNameIcon can name
	-- it — an intentional adaptation noted in the spec's Gate 3.
	local spells = {}
	local seen = {}
	for i = 1, getNumSpells() do
		local spellType, spellID, spellInfo = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
		local keep = false
		if spellInfo then -- new API output available
			if Enum.SpellBookItemType and spellInfo.itemType == Enum.SpellBookItemType.Spell and not spellInfo.isOffSpec then -- retail - filter for only active spec "SPELL"
				keep = true
			end
		elseif spellType == "SPELL" then -- classic/era
			keep = true
		end

		if keep and spellID and not seen[spellID] then
			local name, icon = SpellLookup.ResolveNameIcon(spellID)
			if name then
				seen[spellID] = true
				spells[#spells + 1] = { name = name, icon = icon, spellID = spellID }
			end
		end
	end

	return spells
end

-- Invalidate the cache so the next PlayerSpells() call rebuilds it. Driven by
-- SPELLS_CHANGED / LEARNED_SPELL_IN_TAB via the helper's own event frame.
local function InvalidatePlayerSpells()
	playerSpellsCache = nil
end

-- The helper owns its event frame (config-time only); created on first use so
-- nothing runs at file scope. Bound to the cache (PlayerSpells), not to Suggest,
-- so any consumer of the cache gets live invalidation.
local eventFrame
local function EnsureEventFrame()
	if eventFrame then
		return
	end
	eventFrame = CreateFrame("Frame")
	-- SPELLS_CHANGED fires on any spellbook change (including learning a spell),
	-- which is all we need to invalidate the cache. LEARNED_SPELL_IN_TAB was removed
	-- in Dragonflight, and RegisterEvent THROWS on an unknown event on Retail/Midnight,
	-- so we register only SPELLS_CHANGED — it already covers the learn case on every client.
	eventFrame:RegisterEvent("SPELLS_CHANGED")
	eventFrame:SetScript("OnEvent", InvalidatePlayerSpells)
end

--- Return the cached list of known player spells, rebuilding on first use.
---@return table @array of { name, icon, spellID }
function SpellLookup.PlayerSpells()
	EnsureEventFrame()
	if not playerSpellsCache then
		playerSpellsCache = BuildPlayerSpells()
	end
	return playerSpellsCache
end

-------------------------------------------------------------------------
-- Token resolution + suggestions
-------------------------------------------------------------------------

--- Whether the "bleed" wildcard is active on the current client. Bleed relies
--- on dispelName == "Bleed", which only exists on Retail (Midnight 12.0+).
---@return boolean
local function BleedActive()
	return Triage.isRetail == true
end

--- Resolve a single raw watch-list line to a validation result.
---@param rawLine string
---@return table|nil @{ kind, name, icon, spellID, suggestion? } or nil for empty
function SpellLookup.ResolveToken(rawLine)
	if not rawLine then
		return nil
	end

	local trimmed = strtrim(rawLine)
	if trimmed == "" then
		return nil
	end

	local lower = trimmed:lower()

	-- Wildcard words (active on this client) -> ◇ with a generic icon.
	if RESERVED_ACTIVE_SET[lower] or (lower == "bleed" and BleedActive()) then
		return {
			kind = "wildcard",
			name = trimmed,
			icon = WILDCARD_ICON[lower],
		}
	end

	-- "bleed" on a non-Retail client: recognized but inactive (muted ◇).
	if lower == "bleed" and not BleedActive() then
		return {
			kind = "inactive",
			name = trimmed,
			icon = WILDCARD_ICON[lower],
		}
	end

	-- Numeric spell ID.
	local numeric = tonumber(trimmed)
	if numeric then
		local name, icon = SpellLookup.ResolveNameIcon(numeric)
		if name then
			return {
				kind = "id",
				name = name,
				icon = icon,
				spellID = numeric,
			}
		end
		return { kind = "badID" }
	end

	-- Levenshtein-1 near-miss of a reserved word (e.g. "Magicc" -> "magic").
	local suggestion = NearestReservedWord(lower)
	if suggestion then
		return {
			kind = "nearMiss",
			suggestion = suggestion,
		}
	end

	-- A spell name the client knows resolves to a real spell; otherwise it is
	-- left neutral ("unverified") — cross-class names resolve nil locally but
	-- may still match in game, so we confirm rather than warn.
	local name, icon = SpellLookup.ResolveNameIcon(trimmed)
	if name then
		return {
			kind = "spell",
			name = name,
			icon = icon,
		}
	end

	return { kind = "unverified", name = trimmed }
end

--- Suggest completions for a prefix over player spells + active wildcards.
---@param prefix string
---@param max number|nil @optional cap on returned suggestions
---@return table @array of { name, icon, spellID? }
function SpellLookup.Suggest(prefix, max)
	EnsureEventFrame()

	local results = {}
	if not prefix then
		return results
	end

	local needle = strtrim(prefix):lower()
	if needle == "" then
		return results
	end

	-- Active reserved words: the always-active set, plus "bleed" on Retail.
	for _, word in ipairs(RESERVED_ALL) do
		local active = RESERVED_ACTIVE_SET[word] or (word == "bleed" and BleedActive())
		if active and word:sub(1, #needle) == needle then
			results[#results + 1] = { name = word, icon = WILDCARD_ICON[word] }
		end
	end

	-- Player spellbook names matching the prefix.
	for _, spell in ipairs(SpellLookup.PlayerSpells()) do
		if spell.name and spell.name:lower():sub(1, #needle) == needle then
			results[#results + 1] = { name = spell.name, icon = spell.icon, spellID = spell.spellID }
		end
	end

	if max and #results > max then
		for i = #results, max + 1, -1 do
			results[i] = nil
		end
	end

	return results
end
