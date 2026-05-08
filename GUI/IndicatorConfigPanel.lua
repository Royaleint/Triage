-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Import libraries
-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-- Constants
local THIRD_WIDTH = 1.14
local RESET_ALL_INDICATORS_POPUP = "TRIAGE_RESET_ALL_INDICATOR_SETTINGS"
local RESET_ALL_AURA_LISTS_POPUP = "TRIAGE_RESET_ALL_AURA_LISTS"
local RESET_SPEC_DEFAULTS_POPUP = "TRIAGE_RESET_SPEC_AURA_DEFAULTS"

local copySource = "1"
local copyTarget = "all"
local resetScope = "current"
local copyCategories = {
	visibility = true,
	icon = true,
	text = true,
	animation = true,
}

local INDICATOR_COPY_KEYS = {
	visibility = {
		"casterFilter",
		"meOnly",
		"missingOnly",
		"showTooltip",
		"tooltipLocation",
	},
	icon = {
		"indicatorSize",
		"indicatorHorizontalOffset",
		"indicatorVerticalOffset",
		"showIcon",
		"indicatorAlpha",
		"indicatorColor",
		"colorIndicatorByDebuff",
		"colorIndicatorByTime",
		"colorIndicatorByTime_low",
		"colorIndicatorByTime_high",
	},
	text = {
		"showCountdownText",
		"showStackSize",
		"stackSizeLocation",
		"countdownLocation",
		"textColor",
		"colorTextByTime",
		"colorTextByTime_low",
		"colorTextByTime_high",
		"colorTextByDebuff",
		"textSize",
		"textAlpha",
	},
	animation = {
		"showCountdownSwipe",
		"indicatorGlow",
		"glowRemainingSecs",
	},
}

local function CopyValue(value)
	if type(value) ~= "table" then
		return value
	end

	local copied = {}
	for k, v in pairs(value) do
		copied[k] = CopyValue(v)
	end

	return copied
end

local function GetIndicatorPositionValues(addon, includeAll)
	local values = {}

	if includeAll then
		values.all = L["All Other Positions"]
	end

	for i, position in ipairs(addon.POSITIONS) do
		values[tostring(i)] = i .. ": " .. position
	end

	return values
end

local function CountSelectedCopyCategories()
	local selected = 0

	for _, enabled in pairs(copyCategories) do
		if enabled then
			selected = selected + 1
		end
	end

	return selected
end

local function CopyIndicatorSettings(addon)
	local sourceIndex = tonumber(copySource)
	local sourceDB = addon.db.profile["indicator-" .. sourceIndex]
	local copiedTargets = 0

	for targetIndex = 1, 9 do
		if (copyTarget == "all" and targetIndex ~= sourceIndex) or targetIndex == tonumber(copyTarget) then
			local targetDB = addon.db.profile["indicator-" .. targetIndex]

			for category, keys in pairs(INDICATOR_COPY_KEYS) do
				if copyCategories[category] then
					for _, key in ipairs(keys) do
						if sourceDB[key] ~= nil then
							targetDB[key] = CopyValue(sourceDB[key])
						end
					end
				end
			end

			copiedTargets = copiedTargets + 1
		end
	end

	return copiedTargets
end

local function ResetIndicatorSettings(addon)
	local defaults = addon:CreateDefaults()
	local defaultDB = defaults.profile["indicator-1"]
	local resetCount = 0

	for targetIndex = 1, 9 do
		if resetScope == "all" or targetIndex == tonumber(copySource) then
			local targetDB = addon.db.profile["indicator-" .. targetIndex]

			for category, keys in pairs(INDICATOR_COPY_KEYS) do
				if copyCategories[category] then
					for _, key in ipairs(keys) do
						if defaultDB[key] ~= nil then
							targetDB[key] = CopyValue(defaultDB[key])
						end
					end
				end
			end

			resetCount = resetCount + 1
		end
	end

	return resetCount
end

local function ExecuteIndicatorSettingsReset(addon)
	local resetCount = ResetIndicatorSettings(addon)
	addon:RefreshConfig()
	addon:Print(L["Indicator settings reset."]:format(resetCount))
end

local function ResetAuraWatchLists(addon, resetAll)
	local resetCount = 0

	for targetIndex = 1, 9 do
		if resetAll or targetIndex == tonumber(copySource) then
			local indicatorDB = addon.db.profile["indicator-" .. targetIndex]
			if indicatorDB then
				indicatorDB.auras = ""
				resetCount = resetCount + 1
			end
		end
	end

	addon:RefreshConfig()
	addon:Print(L["Aura watch lists reset."]:format(resetCount))
end

local function ExecuteCurrentSpecDefaultsReset(addon)
	local applied, skipped, specID = addon:ApplyCurrentSpecAuraDefaults(true)
	if applied == 0 and not specID then
		addon:Print(L["No spec aura defaults available."])
	else
		addon:Print(L["Spec aura defaults reset."]:format(applied, skipped))
	end
end

local popupDialogs = rawget(_G, "StaticPopupDialogs")
if popupDialogs then
	popupDialogs[RESET_ALL_INDICATORS_POPUP] = {
		text = L["resetAllIndicatorSettings_confirm"],
		button1 = L["Yes"],
		button2 = L["No"],
		OnAccept = function(_, data)
			if data and data.addon then
				ExecuteIndicatorSettingsReset(data.addon)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	popupDialogs[RESET_ALL_AURA_LISTS_POPUP] = {
		text = L["resetAllAuraWatchLists_confirm"],
		button1 = L["Yes"],
		button2 = L["No"],
		OnAccept = function(_, data)
			if data and data.addon then
				ResetAuraWatchLists(data.addon, true)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	popupDialogs[RESET_SPEC_DEFAULTS_POPUP] = {
		text = L["resetSpecDefaults_confirm"],
		button1 = L["Yes"],
		button2 = L["No"],
		OnAccept = function(_, data)
			if data and data.addon then
				ExecuteCurrentSpecDefaultsReset(data.addon)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

local function ConfirmOrExecuteIndicatorSettingsReset(addon)
	if resetScope ~= "all" then
		ExecuteIndicatorSettingsReset(addon)
		return
	end

	local showPopup = rawget(_G, "StaticPopup_Show")
	if showPopup then
		showPopup(RESET_ALL_INDICATORS_POPUP, nil, nil, { addon = addon })
		return
	end

	ExecuteIndicatorSettingsReset(addon)
end

local function ConfirmOrExecuteAllAuraWatchListsReset(addon)
	local showPopup = rawget(_G, "StaticPopup_Show")
	if showPopup then
		showPopup(RESET_ALL_AURA_LISTS_POPUP, nil, nil, { addon = addon })
		return
	end

	ResetAuraWatchLists(addon, true)
end

local function ConfirmOrExecuteCurrentSpecDefaultsReset(addon)
	local showPopup = rawget(_G, "StaticPopup_Show")
	if showPopup then
		showPopup(RESET_SPEC_DEFAULTS_POPUP, nil, nil, { addon = addon })
		return
	end

	ExecuteCurrentSpecDefaultsReset(addon)
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

function Triage:CreateIndicatorToolsOptions()
	return {
		type = "group",
		childGroups = "tree",
		name = L["Indicator Tools"],
		args = {
			specDefaultsHeader = {
				type = "header",
				name = L["Spec Aura Defaults"],
				hidden = function()
					return not self.supportsSpecDefaults
				end,
				order = 2,
			},
			applySpecDefaults = {
				type = "execute",
				name = L["Apply Current Spec Defaults"],
				desc = L["applySpecDefaults_desc"],
				func = function()
					local applied, skipped, specID = self:ApplyCurrentSpecAuraDefaults(false)
					if applied == 0 and not specID then
						self:Print(L["No spec aura defaults available."])
					else
						self:Print(L["Spec aura defaults applied."]:format(applied, skipped))
					end
				end,
				disabled = function()
					return not self:HasCurrentSpecAuraDefaults()
				end,
				hidden = function()
					return not self.supportsSpecDefaults
				end,
				width = THIRD_WIDTH * 1.5,
				order = 3,
			},
			resetSpecDefaults = {
				type = "execute",
				name = L["Reset Current Spec Defaults"],
				desc = L["resetSpecDefaults_desc"],
				func = function()
					ConfirmOrExecuteCurrentSpecDefaultsReset(self)
				end,
				disabled = function()
					return not self:HasCurrentSpecAuraDefaults()
				end,
				hidden = function()
					return not self.supportsSpecDefaults
				end,
				width = THIRD_WIDTH * 1.5,
				order = 4,
			},
			copySettingsHeader = {
				type = "header",
				name = L["Copy Indicator Settings"],
				order = 5,
			},
			copySettings = {
				type = "group",
				name = L["Copy Indicator Settings"],
				inline = true,
				order = 6,
				args = {
					copySource = {
						type = "select",
						name = L["Copy From"],
						desc = L["copyIndicatorSource_desc"],
						style = "dropdown",
						values = function()
							return GetIndicatorPositionValues(self, false)
						end,
						get = function()
							return copySource
						end,
						set = function(_, value)
							copySource = value
							if copyTarget == value then
								copyTarget = "all"
							end
						end,
						width = THIRD_WIDTH,
						order = 1,
					},
					copyTarget = {
						type = "select",
						name = L["Copy To"],
						desc = L["copyIndicatorTarget_desc"],
						style = "dropdown",
						values = function()
							return GetIndicatorPositionValues(self, true)
						end,
						get = function()
							return copyTarget
						end,
						set = function(_, value)
							copyTarget = value
						end,
						width = THIRD_WIDTH,
						order = 2,
					},
					copyVisibility = {
						type = "toggle",
						name = L["Visibility and Behavior"],
						get = function()
							return copyCategories.visibility
						end,
						set = function(_, value)
							copyCategories.visibility = value
						end,
						width = THIRD_WIDTH,
						order = 10,
					},
					copyIcon = {
						type = "toggle",
						name = L["Icon and Visuals"],
						get = function()
							return copyCategories.icon
						end,
						set = function(_, value)
							copyCategories.icon = value
						end,
						width = THIRD_WIDTH,
						order = 11,
					},
					copyText = {
						type = "toggle",
						name = L["Text"],
						get = function()
							return copyCategories.text
						end,
						set = function(_, value)
							copyCategories.text = value
						end,
						width = THIRD_WIDTH,
						order = 12,
					},
					copyAnimation = {
						type = "toggle",
						name = L["Animations"],
						get = function()
							return copyCategories.animation
						end,
						set = function(_, value)
							copyCategories.animation = value
						end,
						width = THIRD_WIDTH,
						order = 13,
					},
					copyIndicatorSettings = {
						type = "execute",
						name = L["Copy Settings"],
						desc = L["copyIndicatorSettings_desc"],
						func = function()
							if CountSelectedCopyCategories() == 0 then
								self:Print(L["No indicator setting categories selected."])
								return
							end

							local copiedTargets = CopyIndicatorSettings(self)
							self:RefreshConfig()
							self:Print(L["Indicator settings copied."]:format(copiedTargets))
						end,
						disabled = function()
							return copyTarget == copySource
						end,
						width = THIRD_WIDTH,
						order = 20,
					},
					resetScope = {
						type = "select",
						name = L["Reset Scope"],
						desc = L["resetIndicatorScope_desc"],
						style = "dropdown",
						values = {
							current = L["Copy From Position"],
							all = L["All Positions"],
						},
						sorting = { [1] = "current", [2] = "all" },
						get = function()
							return resetScope
						end,
						set = function(_, value)
							resetScope = value
						end,
						width = THIRD_WIDTH,
						order = 30,
					},
					resetIndicatorSettings = {
						type = "execute",
						name = L["Reset Settings"],
						desc = L["resetIndicatorSettings_desc"],
						func = function()
							if CountSelectedCopyCategories() == 0 then
								self:Print(L["No indicator setting categories selected."])
								return
							end

							ConfirmOrExecuteIndicatorSettingsReset(self)
						end,
						width = THIRD_WIDTH,
						order = 31,
					},
					auraListHeader = {
						type = "header",
						name = L["Aura Watch Lists"],
						order = 40,
					},
					resetSelectedAuraList = {
						type = "execute",
						name = L["Reset Selected Aura List"],
						desc = L["resetSelectedAuraList_desc"],
						func = function()
							ResetAuraWatchLists(self, false)
						end,
						width = THIRD_WIDTH,
						order = 41,
					},
					resetAllAuraLists = {
						type = "execute",
						name = L["Reset All Aura Lists"],
						desc = L["resetAllAuraLists_desc"],
						func = function()
							ConfirmOrExecuteAllAuraWatchListsReset(self)
						end,
						width = THIRD_WIDTH,
						order = 42,
					},
				},
			},
		},
	}
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Populate our "Indicator" options table for our Blizzard interface options
function Triage:CreateIndicatorOptions()
	local indicatorOptions = {
		type = "group",
		childGroups = "tree",
		name = L["Indicator Options"],
		args = {
			instructions = {
				type = "description",
				name = L["indicatorOptions_desc"] .. ":",
				fontSize = "medium",
				order = 1,
			},
		},
	}

	indicatorOptions.args.tools = self:CreateIndicatorToolsOptions()
	indicatorOptions.args.tools.order = 2

	-- Add options for each indicator
	for i, v in ipairs(self.POSITIONS) do
		indicatorOptions.args[v] = {}
		indicatorOptions.args[v].type = "group"
		indicatorOptions.args[v].childGroups = "tab"
		indicatorOptions.args[v].name = i .. ": " .. v
		indicatorOptions.args[v].order = i + 10
		indicatorOptions.args[v].args = {
			--------------------------------------------
			instructions = {
				type = "description",
				name = self.NORMAL_COLOR:WrapTextInColorCode(v) .. "\n" ..
						"\n" ..
						L["instructions_desc1"] .. "." .. "\n" ..
						"\n" ..
						L["auras_usage"] .. "." .. "\n",
				fontSize = "medium",
				width = THIRD_WIDTH * 1.2,
				order = 1,
			},
			auras = {
				type = "input",
				name = L["Aura Watch List"],
				desc = L["auras_desc"],
				usage = L["auras_usage"] .. ".\n" ..
						L["Example"] .. ":\n" ..
						"\n" ..
						self.WHITE_COLOR:WrapTextInColorCode("Rejuvenation") .. "\n" ..
						self.WHITE_COLOR:WrapTextInColorCode("Curse") .. "\n" ..
						self.WHITE_COLOR:WrapTextInColorCode("155777") .. "\n" ..
						self.WHITE_COLOR:WrapTextInColorCode("Magic") .. "\n" ..
						"\n" ..
						L["Wildcards"] .. ":\n" ..
						self.RED_COLOR:WrapTextInColorCode("Dispel") .. self.WHITE_COLOR:WrapTextInColorCode(": " .. L["dispelWildcard_desc"]) .. "\n" ..
						self.GREEN_COLOR:WrapTextInColorCode("Poison") .. self.WHITE_COLOR:WrapTextInColorCode(": " .. L["poisonWildcard_desc"]) .. "\n" ..
						self.PURPLE_COLOR:WrapTextInColorCode("Curse") .. self.WHITE_COLOR:WrapTextInColorCode(": " .. L["curseWildcard_desc"]) .. "\n" ..
						self.BROWN_COLOR:WrapTextInColorCode("Disease") .. self.WHITE_COLOR:WrapTextInColorCode(": " .. L["diseaseWildcard_desc"]) .. "\n" ..
						self.BLUE_COLOR:WrapTextInColorCode("Magic") .. self.WHITE_COLOR:WrapTextInColorCode(": " .. L["magicWildcard_desc"]) .. "\n" ..
						self.PINK_COLOR:WrapTextInColorCode("Bleed") .. self.WHITE_COLOR:WrapTextInColorCode(": " .. L["bleedWildcard_desc"]) .. "\n" ..
						"\n" ..
						L["Transforming Spells"] .. ":\n" ..
						self.WHITE_COLOR:WrapTextInColorCode(L["transformSpells_desc"]) .. "\n",
				multiline = 7,
				get = function()
					return self.db.profile["indicator-" .. i].auras
				end,
				set = function(_, value)
					self.db.profile["indicator-" .. i].auras = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH * 1.75,
				order = 2,
			},
			--------------------------------------------
			visibilityOptions = {
				type = "group",
				name = L["Visibility and Behavior"],
				order = 3,
				args = {
					generalOptions = {
						type = "header",
						name = L["General"],
						order = 1,
					},
					casterFilter = {
						type = "select",
						name = L["Caster Filter"],
						desc = L["casterFilter_desc"],
						style = "dropdown",
						values = { ["all"] = L["All Casters"], ["mine"] = L["Mine Only"], ["notMine"] = L["Not Mine"] },
						sorting = { [1] = "all", [2] = "mine", [3] = "notMine" },
						get = function()
							return self.db.profile["indicator-" .. i].casterFilter
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].casterFilter = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 2,
					},
					meOnly = {
						type = "toggle",
						name = L["Show On Me Only"],
						desc = L["meOnly_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].meOnly
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].meOnly = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 3,
					},
					missingOnly = {
						type = "toggle",
						name = L["Show Only if Missing"],
						desc = L["missingOnly_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].missingOnly
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].missingOnly = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 4,
					},
					-------------------------------------------------
					tooltipOptions = {
						type = "header",
						name = L["Tooltips"],
						order = 10,
					},
					showTooltip = {
						type = "toggle",
						name = L["Show Tooltip"],
						desc = L["showTooltip_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].showTooltip
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].showTooltip = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 11,
					},
					tooltipLocation = {
						type = "select",
						name = L["Tooltip Location"],
						desc = L["tooltipLocation_desc"],
						style = "dropdown",
						values = { ["ANCHOR_CURSOR"] = L["Attached to Cursor"], ["ANCHOR_PRESERVE"] = L["Blizzard Default"] },
						sorting = { [1] = "ANCHOR_CURSOR", [2] = "ANCHOR_PRESERVE" },
						get = function()
							return self.db.profile["indicator-" .. i].tooltipLocation
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].tooltipLocation = value
							self:RefreshConfig()
						end,
						disabled = function()
							return not self.db.profile["indicator-" .. i].showTooltip
						end,
						width = THIRD_WIDTH,
						order = 12,
					},
				},
			},
			-------------------------------------------------
			iconOptions = {
				type = "group",
				name = L["Icon and Visuals"],
				order = 4,
				args = {
					-------------------------------------------------
					generalHeader = {
						type = "header",
						name = L["General"],
						order = 1,
					},
					indicatorSize = {
						type = "range",
						name = L["Indicator Size"],
						desc = L["indicatorSize_desc"],
						min = 1,
						max = 30,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].indicatorSize
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].indicatorSize = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 2,
					},
					indicatorVerticalOffset = {
						type = "range",
						name = L["Vertical Offset"],
						desc = L["verticalOffset_desc"],
						isPercent = true,
						min = -1,
						max = 1,
						step = .005,
						get = function()
							return self.db.profile["indicator-" .. i].indicatorVerticalOffset
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].indicatorVerticalOffset = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 3,
					},
					indicatorHorizontalOffset = {
						type = "range",
						name = L["Horizontal Offset"],
						desc = L["horizontalOffset_desc"],
						isPercent = true,
						min = -1,
						max = 1,
						step = .005,
						get = function()
							return self.db.profile["indicator-" .. i].indicatorHorizontalOffset
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].indicatorHorizontalOffset = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 4,
					},
					-------------------------------------------------
					iconHeader = {
						type = "header",
						name = L["Icon"],
						order = 10,
					},
					showIcon = {
						type = "toggle",
						name = L["Show Icon"],
						desc = L["showIcon_desc1"] .. "\n" ..
								"(" .. L["showIcon_desc2"] .. ")",
						get = function()
							return self.db.profile["indicator-" .. i].showIcon
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].showIcon = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 11,
					},
					indicatorAlpha = {
						type = "range",
						name = L["Icon Opacity"],
						desc = L["indicatorAlpha_desc"],
						min = 0,
						max = 1,
						step = 0.05,
						get = function()
							return self.db.profile["indicator-" .. i].indicatorAlpha
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].indicatorAlpha = value
							self:RefreshConfig()
						end,
						disabled = function()
							return not self.db.profile["indicator-" .. i].showIcon
						end,
						width = THIRD_WIDTH,
						order = 12,
					},
					-------------------------------------------------
					colorHeader = {
						type = "header",
						name = L["Color"],
						order = 20,
					},
					indicatorColor = {
						type = "color",
						name = L["Indicator Color"],
						desc = L["indicatorColor_desc1"] .. "\n" ..
								"(" .. L["indicatorColor_desc2"] .. ")",
						hasAlpha = true,
						get = function()
							return unpack(self.db.profile["indicator-" .. i].indicatorColor)
						end,
						set = function(_, r, g, b, a)
							self.db.profile["indicator-" .. i].indicatorColor = { r, g, b, a }
							self:RefreshConfig()
						end,
						disabled = function()
							return self.db.profile["indicator-" .. i].showIcon
						end,
						width = THIRD_WIDTH,
						order = 21,
					},
					colorIndicatorByDebuff = {
						type = "toggle",
						name = L["Color By Debuff Type"],
						desc = L["colorByDebuff_desc"] .. "\n" ..
								"(" .. L["colorOverride_desc"] .. ")" .. "\n" ..
								"\n" ..
								self.GREEN_COLOR:WrapTextInColorCode(L["Poison"]) .. "\n" ..
								self.PURPLE_COLOR:WrapTextInColorCode(L["Curse"]) .. "\n" ..
								self.BROWN_COLOR:WrapTextInColorCode(L["Disease"]) .. "\n" ..
								self.BLUE_COLOR:WrapTextInColorCode(L["Magic"]) .. "\n" ..
								self.PINK_COLOR:WrapTextInColorCode(L["Bleed"]) .. "\n",
						get = function()
							return self.db.profile["indicator-" .. i].colorIndicatorByDebuff
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorIndicatorByDebuff = value
							self:RefreshConfig()
						end,
						disabled = function()
							return self.db.profile["indicator-" .. i].showIcon
						end,
						width = THIRD_WIDTH,
						order = 22,
					},
					colorIndicatorByTime = {
						type = "toggle",
						name = L["Color By Remaining Time"],
						desc = L["colorByTime_desc"] .. "\n" ..
								"(" .. L["colorOverride_desc"] .. ")" .. "\n" ..
								"\n" ..
								self.RED_COLOR:WrapTextInColorCode(L["Time #1"]) .. "\n" ..
								self.YELLOW_COLOR:WrapTextInColorCode(L["Time #2"]),
						get = function()
							return self.db.profile["indicator-" .. i].colorIndicatorByTime
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorIndicatorByTime = value
							self:RefreshConfig()
						end,
						disabled = function()
							return self.db.profile["indicator-" .. i].showIcon
						end,
						width = THIRD_WIDTH,
						order = 23,
					},
					colorIndicatorByTime_low = {
						type = "range",
						name = L["Time #1"],
						desc = L["colorByTime_low_desc"] .. "\n" ..
								"(" .. L["zeroMeansIgnored_desc"] .. ")",
						min = 0,
						max = 10,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].colorIndicatorByTime_low
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorIndicatorByTime_low = value
							self:RefreshConfig()
						end,
						disabled = function()
							return self.db.profile["indicator-" .. i].showIcon or not self.db.profile["indicator-" .. i].colorIndicatorByTime
						end,
						width = THIRD_WIDTH,
						order = 24,
					},
					colorIndicatorByTime_high = {
						type = "range",
						name = L["Time #2"],
						desc = L["colorByTime_high_desc"] .. "\n" ..
								"(" .. L["zeroMeansIgnored_desc"] .. ")",
						min = 0,
						max = 10,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].colorIndicatorByTime_high
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorIndicatorByTime_high = value
							self:RefreshConfig()
						end,
						disabled = function()
							return self.db.profile["indicator-" .. i].showIcon or not self.db.profile["indicator-" .. i].colorIndicatorByTime
						end,
						width = THIRD_WIDTH,
						order = 25,
					},
				},
			},
			--------------------------------------------
			textOptions = {
				type = "group",
				name = L["Text"],
				order = 5,
				args = {
					-------------------------------------------------
					generalHeader = {
						type = "header",
						name = L["General"],
						order = 1,
					},
					showCountdownText = {
						type = "toggle",
						name = L["Show Countdown Text"],
						desc = L["showCountdownText_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].showCountdownText
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].showCountdownText = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 2,
					},
					showStackSize = {
						type = "toggle",
						name = L["Show Stack Size"],
						desc = L["showStackSize_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].showStackSize
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].showStackSize = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 3,
					},
					textSize = {
						type = "range",
						name = L["Countdown Text Size"],
						desc = L["countdownTextSize_desc"],
						min = 1,
						max = 30,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].textSize
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].textSize = value
							self:RefreshConfig()
						end,
						disabled = function()
							if not self.db.profile["indicator-" .. i].showCountdownText then
								return true
							end
						end,
						width = THIRD_WIDTH,
						order = 4,
					},
					stackSizeLocation = {
						type = "select",
						name = L["Stack Size Location"],
						desc = L["stackSizeLocation_desc"],
						style = "dropdown",
						values = { ["TOPLEFT"] = L["Top-Left"], ["TOPRIGHT"] = L["Top-Right"], ["BOTTOMLEFT"] = L["Bottom-Left"], ["BOTTOMRIGHT"] = L["Bottom-Right"] },
						sorting = { [1] = "TOPLEFT", [2] = "TOPRIGHT", [3] = "BOTTOMLEFT", [4] = "BOTTOMRIGHT" },
						get = function()
							return self.db.profile["indicator-" .. i].stackSizeLocation
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].stackSizeLocation = value
							self:RefreshConfig()
						end,
						disabled = function()
							return not self.db.profile["indicator-" .. i].showStackSize
						end,
						width = THIRD_WIDTH,
						order = 5,
					},
					countdownLocation = {
						type = "select",
						name = L["Countdown Text Location"],
						desc = L["countdownLocation_desc"],
						style = "dropdown",
						values = { ["TOPLEFT"] = L["Top-Left"], ["TOPRIGHT"] = L["Top-Right"], ["BOTTOMLEFT"] = L["Bottom-Left"], ["BOTTOMRIGHT"] = L["Bottom-Right"], ["CENTER"] = L["Center"] },
						sorting = { [1] = "TOPLEFT", [2] = "TOPRIGHT", [3] = "CENTER", [4] = "BOTTOMLEFT", [5] = "BOTTOMRIGHT" },
						get = function()
							return self.db.profile["indicator-" .. i].countdownLocation
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].countdownLocation = value
							self:RefreshConfig()
						end,
						disabled = function()
							return not self.db.profile["indicator-" .. i].showCountdownText
						end,
						width = THIRD_WIDTH,
						order = 6,
					},
					-------------------------------------------------
					colorHeader = {
						type = "header",
						name = L["Color"],
						order = 10,
					},
					textColor = {
						type = "color",
						name = L["Text Color"],
						desc = L["textColor_desc1"] .. "\n" ..
								"(" .. L["textColor_desc2"] .. ")",
						hasAlpha = true,
						get = function()
							return unpack(self.db.profile["indicator-" .. i].textColor)
						end,
						set = function(_, r, g, b, a)
							self.db.profile["indicator-" .. i].textColor = { r, g, b, a }
							self:RefreshConfig()
						end,
						disabled = function()
							if not self.db.profile["indicator-" .. i].showCountdownText then
								return true
							end
						end,
						width = THIRD_WIDTH,
						order = 11,
					},
					colorTextByDebuff = {
						type = "toggle",
						name = L["Color By Debuff Type"],
						desc = L["colorByDebuff_desc"] .. "\n" ..
								"(" .. L["colorOverride_desc"] .. ")" .. "\n" ..
								"\n" ..
								self.GREEN_COLOR:WrapTextInColorCode(L["Poison"]) .. "\n" ..
								self.PURPLE_COLOR:WrapTextInColorCode(L["Curse"]) .. "\n" ..
								self.BROWN_COLOR:WrapTextInColorCode(L["Disease"]) .. "\n" ..
								self.BLUE_COLOR:WrapTextInColorCode(L["Magic"]) .. "\n" ..
								self.PINK_COLOR:WrapTextInColorCode(L["Bleed"]) .. "\n",
						get = function()
							return self.db.profile["indicator-" .. i].colorTextByDebuff
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorTextByDebuff = value
							self:RefreshConfig()
						end,
						disabled = function()
							if not self.db.profile["indicator-" .. i].showCountdownText then
								return true
							end
						end,
						width = THIRD_WIDTH,
						order = 12,
					},
					colorTextByTime = {
						type = "toggle",
						name = L["Color By Remaining Time"],
						desc = L["colorByTime_desc"] .. "\n" ..
								"(" .. L["colorOverride_desc"] .. ")" .. "\n" ..
								"\n" ..
								self.RED_COLOR:WrapTextInColorCode(L["Time #1"]) .. "\n" ..
								self.YELLOW_COLOR:WrapTextInColorCode(L["Time #2"]),
						get = function()
							return self.db.profile["indicator-" .. i].colorTextByTime
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorTextByTime = value
							self:RefreshConfig()
						end,
						disabled = function()
							if not self.db.profile["indicator-" .. i].showCountdownText then
								return true
							end
						end,
						width = THIRD_WIDTH,
						order = 13,
					},
					colorTextByTime_low = {
						type = "range",
						name = L["Time #1"],
						desc = L["colorByTime_low_desc"] .. "\n" ..
								"(" .. L["zeroMeansIgnored_desc"] .. ")",
						min = 0,
						max = 10,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].colorTextByTime_low
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorTextByTime_low = value
							self:RefreshConfig()
						end,
						disabled = function()
							if not self.db.profile["indicator-" .. i].showCountdownText or not self.db.profile["indicator-" .. i].colorTextByTime then
								return true
							end
						end,
						width = THIRD_WIDTH,
						order = 14,
					},
					colorTextByTime_high = {
						type = "range",
						name = L["Time #2"],
						desc = L["colorByTime_high_desc"] .. "\n" ..
								"(" .. L["zeroMeansIgnored_desc"] .. ")",
						min = 0,
						max = 10,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].colorTextByTime_high
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].colorTextByTime_high = value
							self:RefreshConfig()
						end,
						disabled = function()
							if not self.db.profile["indicator-" .. i].showCountdownText or not self.db.profile["indicator-" .. i].colorTextByTime then
								return true
							end
						end,
						width = THIRD_WIDTH,
						order = 15,
					},
				},
			},
			--------------------------------------------
			animationOptions = {
				type = "group",
				name = L["Animations"],
				order = 6,
				args = {
					-------------------------------------------------
					generalOptions = {
						type = "header",
						name = L["General"],
						order = 1,
					},
					showCountdownSwipe = {
						type = "toggle",
						name = L["Show Countdown Swipe"],
						desc = L["showCountdownSwipe_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].showCountdownSwipe
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].showCountdownSwipe = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 2,
					},
					indicatorGlow = {
						type = "toggle",
						name = L["Indicator Glow Effect"],
						desc = L["indicatorGlow_desc"],
						get = function()
							return self.db.profile["indicator-" .. i].indicatorGlow
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].indicatorGlow = value
							self:RefreshConfig()
						end,
						width = THIRD_WIDTH,
						order = 3,
					},
					glowRemainingSecs = {
						type = "range",
						name = L["Glow At Countdown Time"],
						desc = L["glowRemainingSecs_desc1"] .. "\n" ..
								"(" .. L["glowRemainingSecs_desc2"] .. ")",
						min = 0,
						max = 10,
						step = 1,
						get = function()
							return self.db.profile["indicator-" .. i].glowRemainingSecs
						end,
						set = function(_, value)
							self.db.profile["indicator-" .. i].glowRemainingSecs = value
							self:RefreshConfig()
						end,
						disabled = function()
							return not self.db.profile["indicator-" .. i].indicatorGlow
						end,
						width = THIRD_WIDTH,
						order = 4,
					},
				},
			},
		}
	end

	return indicatorOptions
end
