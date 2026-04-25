-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Curated Retail spec starter profiles for the 3x3 indicator grid.
-- Keys are specialization IDs. Slot values are newline-delimited aura IDs or
-- supported wildcard strings, matching the existing indicator aura input format.

local EnhancedRaidFrames = _G.EnhancedRaidFrames

local SpecDefaults = {
	-- Restoration Druid
	[105] = {
		[1] = "774\n155777",
		[2] = "8936\n48438",
		[3] = "102342\n22812",
		[4] = "Dispel",
		[6] = "33763",
		[8] = "Magic\nBleed",
		[9] = "1236573\n33891",
	},

	-- Restoration Shaman
	[264] = {
		[1] = "61295",
		[2] = "383648\n73920",
		[3] = "98007",
		[4] = "Dispel",
		[6] = "382024",
		[7] = "207400",
		[8] = "Magic\nCurse",
		[9] = "79206",
	},

	-- Holy Paladin
	[65] = {
		[1] = "156322",
		[2] = "53563\n156910",
		[3] = "6940\n1022",
		[4] = "Dispel",
		[6] = "200025",
		[7] = "200654",
		[8] = "Magic\nPoison\nDisease",
		[9] = "31884\n210294",
	},

	-- Holy Priest
	[257] = {
		[1] = "139",
		[2] = "41635\n77489",
		[3] = "47788\n17",
		[4] = "Dispel",
		[6] = "64844",
		[8] = "Magic\nDisease",
		[9] = "200183",
	},

	-- Discipline Priest
	[256] = {
		[1] = "194384",
		[2] = "17",
		[3] = "33206\n81782",
		[4] = "Dispel",
		[6] = "47536",
		[8] = "Magic\nDisease",
		[9] = "472433",
	},

	-- Mistweaver Monk
	[270] = {
		[1] = "448430\n1238851",
		[2] = "227345\n1260617",
		[3] = "116849",
		[4] = "Dispel",
		[6] = "1260617",
		[7] = "406139\n1260681",
		[8] = "Magic\nPoison\nDisease",
		[9] = "343820",
	},

	-- Preservation Evoker
	[1468] = {
		[1] = "367364",
		[2] = "364343\n376788",
		[3] = "357170",
		[4] = "Dispel",
		[6] = "373267",
		[7] = "373862\n370537\n370562",
		[8] = "Magic\nPoison\nBleed",
		[9] = "363534",
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
