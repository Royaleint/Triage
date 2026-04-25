-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Curated Retail spec starter profiles for the 3x3 indicator grid.
-- Keys are specialization IDs. Slot values are newline-delimited aura strings,
-- matching the existing indicator aura input format.

local EnhancedRaidFrames = _G.EnhancedRaidFrames

local SpecDefaults = {
	-- Restoration Druid
	[105] = {
		[1] = "Rejuvenation\nRejuvenation (Germination)",
		[2] = "Regrowth\nWild Growth",
		[3] = "Ironbark\nBarkskin",
		[4] = "Dispel",
		[6] = "Lifebloom",
		[7] = "Power of the Archdruid",
		[8] = "Magic\nBleed",
		[9] = "Tranquility\nIncarnation: Tree of Life",
	},

	-- Restoration Shaman
	[264] = {
		[1] = "Riptide",
		[2] = "Earth Shield\nHealing Rain",
		[3] = "Spirit Link Totem\nHealing Tide Totem",
		[4] = "Dispel",
		[6] = "Earthliving Weapon",
		[7] = "Ancestral Vigor",
		[8] = "Magic\nCurse",
		[9] = "Ascendance\nSpiritwalker's Grace",
	},

	-- Holy Paladin
	[65] = {
		[1] = "Bestow Faith\nEternal Flame",
		[2] = "Beacon of Light\nBeacon of Faith",
		[3] = "Blessing of Sacrifice\nBlessing of Protection",
		[4] = "Dispel",
		[6] = "Beacon of Virtue",
		[7] = "Tyr's Deliverance",
		[8] = "Magic\nPoison\nDisease",
		[9] = "Avenging Wrath\nDivine Favor",
	},

	-- Holy Priest
	[257] = {
		[1] = "Renew",
		[2] = "Prayer of Mending\nEcho of Light",
		[3] = "Guardian Spirit\nPower Word: Shield",
		[4] = "Dispel",
		[6] = "Divine Hymn",
		[7] = "Surge of Light\nHoly Word: Serenity",
		[8] = "Magic\nDisease",
		[9] = "Apotheosis\nDivine Hymn",
	},

	-- Discipline Priest
	[256] = {
		[1] = "Atonement",
		[2] = "Power Word: Shield\nPlea",
		[3] = "Pain Suppression\nPower Word: Barrier",
		[4] = "Dispel",
		[6] = "Rapture",
		[7] = "Power of the Dark Side",
		[8] = "Magic\nDisease",
		[9] = "Evangelism\nShadowfiend",
	},

	-- Mistweaver Monk
	[270] = {
		[1] = "Renewing Mist",
		[2] = "Enveloping Mist\nSoothing Mist",
		[3] = "Life Cocoon\nDiffuse Magic",
		[4] = "Dispel",
		[6] = "Soothing Mist",
		[7] = "Chi Cocoon\nZen Pulse",
		[8] = "Magic\nPoison\nDisease",
		[9] = "Invoke Yu'lon, the Jade Serpent\nInvoke Chi-Ji, the Red Crane",
	},

	-- Preservation Evoker
	[1468] = {
		[1] = "Reversion",
		[2] = "Echo\nDream Breath",
		[3] = "Time Dilation\nZephyr",
		[4] = "Dispel",
		[6] = "Lifebind",
		[7] = "Temporal Anomaly\nStasis",
		[8] = "Magic\nPoison\nBleed",
		[9] = "Rewind\nDream Flight",
	},

	-- Arcane Mage
	[62] = {
		[4] = "Curse",
	},

	-- Fire Mage
	[63] = {
		[4] = "Curse",
	},

	-- Frost Mage
	[64] = {
		[4] = "Curse",
	},

	-- Retribution Paladin
	[70] = {
		[4] = "Poison\nDisease",
	},

	-- Shadow Priest
	[258] = {
		[4] = "Disease",
	},

	-- Enhancement Shaman
	[263] = {
		[4] = "Curse",
	},
}

EnhancedRaidFrames.SpecDefaults = SpecDefaults
