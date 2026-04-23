-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

-- Latest Database Version (<major>.<minor>)
EnhancedRaidFrames.DATABASE_VERSION = 2.3

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Create a table containing our default database values
function EnhancedRaidFrames:CreateDefaults()
	local defaults = {}

	defaults.profile = {
		--------------------------------
		------- General Settings -------
		--------------------------------
		-- Default Icon Visibility
		showBuffs = true,
		showDebuffs = true,
		showDispellableDebuffs = true,

		-- Visual Options
		powerBarOffset = true,
		frameScale = 1,
		backgroundAlpha = 1,
		indicatorFont = "Arial Narrow",

		-- Minimap Button
		minimap = {
			hide = false,
		},

		-- Test Mode
		testModeLastSize = 5,
		testModePosition = {},
		configWindowStatus = {},

		-- Out-of-Range Options
		customRangeCheck = false,
		customRange = 30,
		rangeAlpha = 0.55,
		keepIndicatorsVisible = false,

		-------------------------------
		---- Dispel Overlay (Retail) ---
		-------------------------------
		dispelOverlay = {
			enabled = true,
			colorByType = true,
			glowStyle = "both",     -- "border", "pulse", "both"
			borderAlpha = 0.8,
			showInParty = true,
			showInRaid = true,
		},

		--------------------------------
		---- Target Marker Settings ----
		--------------------------------
		-- General Options
		showTargetMarkers = true,
		markerPosition = 5,

		-- Visual Options
		markerSize = 20,
		markerAlpha = 1,

		-- Position Options
		markerVerticalOffset = 0,
		markerHorizontalOffset = 0,
	}

	-----------------------------------
	---- Indicator Option Settings ----
	-----------------------------------
	for i = 1, 9 do
		defaults.profile["indicator-" .. i] = {
			-- Aura Strings
			auras = "",

			-- Visibility and Behavior
			casterFilter = "all",
			meOnly = false,
			missingOnly = false,
			showTooltip = true,
			tooltipLocation = "ANCHOR_CURSOR",

			-- Icon and Color
			indicatorSize = 18,
			indicatorHorizontalOffset = 0,
			indicatorVerticalOffset = 0,
			showIcon = true,
			indicatorAlpha = 1,
			indicatorColor = { 0, 1, 0.59, 1 },
			colorIndicatorByDebuff = false,
			colorIndicatorByTime = false,
			colorIndicatorByTime_low = 2,
			colorIndicatorByTime_high = 5,

			-- Text and Color
			showCountdownText = false,
			showStackSize = true,
			stackSizeLocation = "BOTTOMRIGHT",
			countdownLocation = "CENTER",
			textColor = { 1, 1, 1, 1 },
			colorTextByTime = false,
			colorTextByTime_low = 2,
			colorTextByTime_high = 5,
			colorTextByDebuff = false,
			textSize = 14,
			textAlpha = 1,

			-- Animations and Effects
			showCountdownSwipe = true,
			indicatorGlow = false,
			glowRemainingSecs = 3,
		}
	end

	return defaults
end
