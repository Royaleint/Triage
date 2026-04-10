-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

local EnhancedRaidFrames = _G.EnhancedRaidFrames

local VALID_TEST_MODE_SIZES = {
	[5] = true,
	[10] = true,
	[25] = true,
	[40] = true,
}

local HEALTH_STATE_RATIOS = {
	full = 1.0,
	injured = 0.62,
	critical = 0.27,
	dead = 0,
	offline = 0,
}

local NEXT_HEALTH_STATE = {
	full = "injured",
	injured = "critical",
	critical = "critical",
}

-- Spell IDs are identical across clients currently.
-- Branch structure is intentional scaffolding for future per-client divergence.
local PROJECT_PREVIEW_SPELLS
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	PROJECT_PREVIEW_SPELLS = {
		helpful = 17,
		harmful = {
			Magic = 118,
			Curse = 1714,
			Poison = 2818,
			Disease = 15007,
		},
	}
elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
	PROJECT_PREVIEW_SPELLS = {
		helpful = 17,
		harmful = {
			Magic = 118,
			Curse = 1714,
			Poison = 2818,
			Disease = 15007,
		},
	}
else
	PROJECT_PREVIEW_SPELLS = {
		helpful = 17,
		harmful = {
			Magic = 118,
			Curse = 1714,
			Poison = 2818,
			Disease = 15007,
		},
	}
end

local MASTER_MEMBER_SEEDS = {
	{name = "Aelwyn", classFile = "WARRIOR", specID = 73, role = "TANK", dispelType = nil, healthState = "full"},
	{name = "Brenna", classFile = "PRIEST", specID = 257, role = "HEALER", dispelType = "Magic", healthState = "injured"},
	{name = "Corin", classFile = "MAGE", specID = 62, role = "DAMAGER", dispelType = "Curse", healthState = "critical"},
	{name = "Darian", classFile = "ROGUE", specID = 259, role = "DAMAGER", dispelType = nil, healthState = "dead"},
	{name = "Elaith", classFile = "HUNTER", specID = 254, role = "DAMAGER", dispelType = "Poison", healthState = "offline"},
	{name = "Faelyn", classFile = "PALADIN", specID = 66, role = "TANK", dispelType = nil, healthState = "full"},
	{name = "Garron", classFile = "DRUID", specID = 105, role = "HEALER", dispelType = "Disease", healthState = "injured"},
	{name = "Helia", classFile = "WARLOCK", specID = 266, role = "DAMAGER", dispelType = "Magic", healthState = "full", inRange = false},
	{name = "Ilya", classFile = "SHAMAN", specID = 262, role = "DAMAGER", dispelType = "Curse", healthState = "full"},
	{name = "Joren", classFile = "WARRIOR", specID = 72, role = "DAMAGER", dispelType = nil, healthState = "injured", inRange = false},
	{name = "Kaelis", classFile = "PALADIN", specID = 65, role = "HEALER", dispelType = "Poison", healthState = "full"},
	{name = "Liora", classFile = "PRIEST", specID = 256, role = "HEALER", dispelType = "Magic", healthState = "critical"},
	{name = "Maelor", classFile = "MAGE", specID = 63, role = "DAMAGER", dispelType = "Curse", healthState = "full"},
	{name = "Nerith", classFile = "WARLOCK", specID = 265, role = "DAMAGER", dispelType = nil, healthState = "injured"},
	{name = "Orin", classFile = "HUNTER", specID = 255, role = "DAMAGER", dispelType = "Disease", healthState = "full"},
	{name = "Pyria", classFile = "DRUID", specID = 104, role = "TANK", dispelType = nil, healthState = "full"},
	{name = "Quill", classFile = "ROGUE", specID = 260, role = "DAMAGER", dispelType = nil, healthState = "injured"},
	{name = "Ryn", classFile = "SHAMAN", specID = 264, role = "HEALER", dispelType = "Poison", healthState = "full", inRange = false},
	{name = "Sera", classFile = "PALADIN", specID = 70, role = "DAMAGER", dispelType = "Magic", healthState = "critical"},
	{name = "Torren", classFile = "WARRIOR", specID = 71, role = "DAMAGER", dispelType = nil, healthState = "full"},
	{name = "Ulric", classFile = "PRIEST", specID = 258, role = "DAMAGER", dispelType = "Disease", healthState = "injured"},
	{name = "Vaela", classFile = "DRUID", specID = 102, role = "DAMAGER", dispelType = "Curse", healthState = "full"},
	{name = "Wes", classFile = "HUNTER", specID = 253, role = "DAMAGER", dispelType = nil, healthState = "full", inRange = false},
	{name = "Xara", classFile = "MAGE", specID = 64, role = "DAMAGER", dispelType = "Magic", healthState = "injured"},
	{name = "Yorin", classFile = "WARLOCK", specID = 267, role = "DAMAGER", dispelType = "Curse", healthState = "critical"},
	{name = "Zella", classFile = "SHAMAN", specID = 263, role = "DAMAGER", dispelType = "Poison", healthState = "full"},
	{name = "Alric", classFile = "WARRIOR", specID = 72, role = "DAMAGER", dispelType = nil, healthState = "injured", inRange = false},
	{name = "Bria", classFile = "PRIEST", specID = 257, role = "HEALER", dispelType = "Magic", healthState = "full"},
	{name = "Cael", classFile = "PALADIN", specID = 65, role = "HEALER", dispelType = "Disease", healthState = "full"},
	{name = "Delia", classFile = "DRUID", specID = 105, role = "HEALER", dispelType = "Poison", healthState = "critical"},
	{name = "Eamon", classFile = "HUNTER", specID = 254, role = "DAMAGER", dispelType = nil, healthState = "full"},
	{name = "Fiora", classFile = "MAGE", specID = 62, role = "DAMAGER", dispelType = "Curse", healthState = "injured"},
	{name = "Galen", classFile = "ROGUE", specID = 261, role = "DAMAGER", dispelType = nil, healthState = "full"},
	{name = "Hale", classFile = "SHAMAN", specID = 262, role = "DAMAGER", dispelType = "Magic", healthState = "full"},
	{name = "Isla", classFile = "WARLOCK", specID = 266, role = "DAMAGER", dispelType = "Poison", healthState = "injured", inRange = false},
	{name = "Jarek", classFile = "WARRIOR", specID = 71, role = "DAMAGER", dispelType = nil, healthState = "critical"},
	{name = "Kira", classFile = "PRIEST", specID = 256, role = "HEALER", dispelType = "Magic", healthState = "full"},
	{name = "Lukas", classFile = "PALADIN", specID = 70, role = "DAMAGER", dispelType = "Disease", healthState = "injured"},
	{name = "Mira", classFile = "DRUID", specID = 102, role = "DAMAGER", dispelType = "Curse", healthState = "full"},
	{name = "Nolan", classFile = "HUNTER", specID = 255, role = "DAMAGER", dispelType = nil, healthState = "full"},
}

local function CopyAuraTemplate(auraTemplate, expirationTime)
	local aura = {}
	for key, value in pairs(auraTemplate) do
		aura[key] = value
	end
	aura.expirationTime = expirationTime
	return aura
end

local function GetSpellNameAndIcon(spellId, fallbackIcon)
	if C_Spell and C_Spell.GetSpellName then
		local spellName = C_Spell.GetSpellName(spellId)
		local spellIcon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId)
		if spellName then
			return spellName:lower(), spellIcon or fallbackIcon
		end
	end

	local spellName, _, spellIcon = GetSpellInfo(spellId)
	if spellName then
		return spellName:lower(), spellIcon or fallbackIcon
	end

	return tostring(spellId), fallbackIcon
end

local function GetAuraTemplatesForSeed(seed)
	local helpfulName, helpfulIcon = GetSpellNameAndIcon(PROJECT_PREVIEW_SPELLS.helpful, 136090)
	local helpfulAura = {
		name = helpfulName,
		icon = helpfulIcon,
		applications = 0,
		duration = 18,
		sourceUnit = "player",
		spellId = PROJECT_PREVIEW_SPELLS.helpful,
		timeMod = 1,
		isHelpful = true,
	}

	local templates = {helpfulAura}
	if seed.dispelType then
		local harmfulSpellId = PROJECT_PREVIEW_SPELLS.harmful[seed.dispelType]
		local harmfulName, harmfulIcon = GetSpellNameAndIcon(harmfulSpellId, 136182)
		templates[#templates + 1] = {
			name = harmfulName,
			icon = harmfulIcon,
			applications = 1,
			dispelName = seed.dispelType,
			duration = 22,
			sourceUnit = "boss1",
			spellId = harmfulSpellId,
			timeMod = 1,
			isHarmful = true,
		}
	end

	return templates
end

local function ApplyHealthState(member)
	local ratio = HEALTH_STATE_RATIOS[member.healthState] or 0
	member.currentHealth = math.floor(member.maxHealth * ratio + 0.5)
	if member.healthState == "dead" then
		member.status = "dead"
	elseif member.healthState == "offline" then
		member.status = "offline"
	else
		member.status = "alive"
	end
end

local function RefreshMemberAuras(member, now)
	member.auras = member.auras or {}
	for index, auraTemplate in ipairs(member.auraTemplates) do
		member.auras[index] = CopyAuraTemplate(auraTemplate, now + auraTemplate.duration)
	end
end

local function CreateMember(seed, index)
	local member = {
		id = index,
		displayName = seed.name,
		classFile = seed.classFile,
		specID = seed.specID,
		role = seed.role,
		status = "alive",
		healthState = seed.healthState,
		maxHealth = 100000,
		currentHealth = 100000,
		powerType = "MANA",
		currentPower = 100000,
		maxPower = 100000,
		inRange = seed.inRange == nil and seed.healthState ~= "offline" or seed.inRange,
		raidTargetIndex = (index % 8) + 1,
		dispelType = seed.dispelType,
		unitToken = "raid" .. index,
		auraTemplates = GetAuraTemplatesForSeed(seed),
		auras = {},
	}

	ApplyHealthState(member)
	RefreshMemberAuras(member, GetTime())
	return member
end

local function GetSessionMembers(size)
	local members = {}
	for index = 1, size do
		members[index] = CreateMember(MASTER_MEMBER_SEEDS[index], index)
	end
	return members
end

--- Test whether a requested test mode size is valid.
---@param size number
---@return boolean
function EnhancedRaidFrames:IsValidTestModeSize(size)
	return VALID_TEST_MODE_SIZES[size] == true
end

--- Build a fresh preview session for the requested roster size.
---@param size number
---@return table|nil
function EnhancedRaidFrames:CreateTestModeSession(size)
	if not self:IsValidTestModeSize(size) then
		return nil
	end

	return {
		size = size,
		members = GetSessionMembers(size),
		cycleCount = 0,
	}
end

--- Advance the preview session by degrading one or two active members.
---@param session table
function EnhancedRaidFrames:AdvanceTestModeSession(session)
	if not session or not session.members then
		return
	end

	local eligibleMembers = {}
	for _, member in ipairs(session.members) do
		if member.status ~= "dead" and member.status ~= "offline" then
			eligibleMembers[#eligibleMembers + 1] = member
		end
	end

	if #eligibleMembers == 0 then
		return
	end

	local picks = math.random(1, math.min(2, #eligibleMembers))
	for index = 1, picks do
		local memberIndex = math.random(1, #eligibleMembers)
		local member = table.remove(eligibleMembers, memberIndex)
		member.healthState = NEXT_HEALTH_STATE[member.healthState] or member.healthState
		ApplyHealthState(member)
	end

	local now = GetTime()
	for _, member in ipairs(session.members) do
		RefreshMemberAuras(member, now)
	end

	session.cycleCount = session.cycleCount + 1
end
