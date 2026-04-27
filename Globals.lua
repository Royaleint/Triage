-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Import libraries
-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

-- Set Classic and Classic_Era flags
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	Triage.isWoWClassicEra = true
elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
	Triage.isWoWClassic = true
end

-- Declare Color Global Constants
Triage.NORMAL_COLOR = NORMAL_FONT_COLOR or CreateColor(1.0, 0.82, 0.0) --the default game yellow text color
Triage.WHITE_COLOR = WHITE_FONT_COLOR or CreateColor(1.0, 1.0, 1.0) --default game white color for text
Triage.RED_COLOR = DIM_RED_FONT_COLOR or CreateColor(0.8, 0.1, 0.1) --solid red color
Triage.YELLOW_COLOR = DARKYELLOW_FONT_COLOR or CreateColor(1.0, 0.82, 0.0) --solid yellow color
Triage.GREEN_COLOR = CreateColor(0.6627, 0.8235, 0.4431) --poison text color
Triage.PURPLE_COLOR = CreateColor(0.6392, 0.1882, 0.7882) --curse text color
Triage.BROWN_COLOR = CreateColor(0.7804, 0.6118, 0.4314) --disease text color
Triage.BLUE_COLOR = CreateColor(0.0, 0.4392, 0.8706) --magic text color
Triage.PINK_COLOR = CreateColor(1.0, 0.2, 0.6) --bleed text color

-- Declare Global positions table
Triage.POSITIONS = {}
Triage.POSITIONS[1] = L["Top-Left"]
Triage.POSITIONS[2] = L["Top"]
Triage.POSITIONS[3] = L["Top-Right"]
Triage.POSITIONS[4] = L["Left"]
Triage.POSITIONS[5] = L["Center"]
Triage.POSITIONS[6] = L["Right"]
Triage.POSITIONS[7] = L["Bottom-Left"]
Triage.POSITIONS[8] = L["Bottom"]
Triage.POSITIONS[9] = L["Bottom-Right"]

-- Declare Global iconCache table with pre-populated values
Triage.iconCache = {}
Triage.iconCache["Poison"] = 132104
Triage.iconCache["Disease"] = 132099
Triage.iconCache["Curse"] = 132095
Triage.iconCache["Magic"] = 135894
Triage.iconCache["Bleed"] = 136168
