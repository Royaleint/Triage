-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals IsInGroup IsInRaid

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

-- Import libraries
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-- Constants
local THIRD_WIDTH = 1.25

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Populate our "General" options table for our Blizzard interface options
function EnhancedRaidFrames:CreateGeneralOptions()
	local generalOptions = {
		type = "group",
		childGroups = "tree",
		name = L["General Options"],
		args = {
			instructions = {
				type = "description",
				name = L["generalOptions_desc"],
				fontSize = "medium",
				order = 2,
			},
			-------------------------------------------------
			topSpacer = {
				type = "header",
				name = "",
				order = 3,
			},
			blizzardRaidOptionsButton = {
				type = 'execute',
				name = L["Open the Blizzard Raid Profiles Options"],
				desc = L["blizzardRaidOptionsButton_desc"],
				func = function()
					Settings.OpenToCategory(Settings.INTERFACE_CATEGORY_ID, RAID_FRAMES_LABEL)
				end,
				width = THIRD_WIDTH * 1.5,
				order = 4,
			},
			-------------------------------------------------
			textHeader = {
				type = "header",
				name = L["Default Icon Visibility"],
				order = 10,
			},
			showBuffs = {
				type = "toggle",
				name = L["Stock Buff Icons"],
				desc = L["showBuffs_desc"],
				get = function()
					return self.db.profile.showBuffs
				end,
				set = function(_, value)
					self.db.profile.showBuffs = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 11,
			},
			showDebuffs = {
				type = "toggle",
				name = L["Stock Debuff Icons"],
				desc = L["showDebuffs_desc"],
				get = function()
					return self.db.profile.showDebuffs
				end,
				set = function(_, value)
					self.db.profile.showDebuffs = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 12,
			},
			showDispellableDebuffs = {
				type = "toggle",
				name = L["Stock Dispellable Icons"],
				desc = L["showDispellableDebuffs_desc"],
				get = function()
					return self.db.profile.showDispellableDebuffs
				end,
				set = function(_, value)
					self.db.profile.showDispellableDebuffs = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 13,
			},
			-------------------------------------------------
			visualOptions = {
				type = "header",
				name = L["General"],
				order = 30,
			},
			powerBarOffset = {
				type = "toggle",
				name = L["Power Bar Vertical Offset"],
				desc = L["powerBarOffset_desc"],
				get = function()
					return self.db.profile.powerBarOffset
				end,
				set = function(_, value)
					self.db.profile.powerBarOffset = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 31,
			},
			frameScale = {
				type = "range",
				name = L["Raidframe Scale"],
				desc = L["frameScale_desc"],
				isPercent = true,
				min = 0.5,
				max = 2,
				step = 0.01,
				get = function()
					return self.db.profile.frameScale
				end,
				set = function(_, value)
					self.db.profile.frameScale = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 32,
			},
			backgroundAlpha = {
				type = "range",
				name = L["Background Opacity"],
				desc = L["backgroundAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return self.db.profile.backgroundAlpha
				end,
				set = function(_, value)
					self.db.profile.backgroundAlpha = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 33,
			},
			-- mouseoverCastCompat removed in v1.0 — click-cast safety is now always on
			indicatorFont = {
				type = 'select',
				dialogControl = "LSM30_Font",
				name = L["Indicator Font"],
				desc = L["indicatorFont_desc"],
				values = AceGUIWidgetLSMlists.font,
				get = function()
					return self.db.profile.indicatorFont
				end,
				set = function(_, value)
					self.db.profile.indicatorFont = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 35,
			},
			-------------------------------------------------
			outOfRangeOptions = {
				type = "header",
				name = L["Out-of-Range"],
				order = 40,
			},
			customRangeCheck = {
				type = "toggle",
				name = L["Override Default Distance"],
				desc = L["customRange_desc"],
				get = function()
					return self.db.profile.customRangeCheck
				end,
				set = function(_, value)
					self.db.profile.customRangeCheck = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 41,
			},
			customRange = {
				type = "select",
				name = L["Select a Custom Distance"],
				desc = L["customRangeCheck_desc"],
				values = { [5] = L["Melee"], [10] = L["10 yards"], [15] = L["15 yards"], [20] = L["20 yards"],
						   [25] = L["25 yards"], [30] = L["30 yards"], [35] = L["35 yards"], [40] = L["40 yards"] },
				get = function()
					return self.db.profile.customRange
				end,
				set = function(_, value)
					self.db.profile.customRange = value
					self:RefreshConfig()
				end,
				disabled = function()
					return not self.db.profile.customRangeCheck
				end,
				width = THIRD_WIDTH,
				order = 42,
			},
			rangeAlpha = {
				type = "range",
				name = L["Out-of-Range Opacity"],
				desc = L["rangeAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return self.db.profile.rangeAlpha
				end,
				set = function(_, value)
					self.db.profile.rangeAlpha = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 43,
			},
			keepIndicatorsVisible = {
				type = "toggle",
				name = L["Keep Indicators Visible Out of Range"],
				desc = L["keepIndicatorsVisible_desc"],
				get = function()
					return self.db.profile.keepIndicatorsVisible
				end,
				set = function(_, value)
					self.db.profile.keepIndicatorsVisible = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 44,
			},
			testModeHeader = {
				type = "header",
				name = L["Test Mode"],
				order = 60,
			},
			testModeDescription = {
				type = "description",
				name = L["testModeDescription_desc"],
				fontSize = "medium",
				order = 61,
			},
			testModeSize = {
				type = "select",
				name = L["Preview Group Size"],
				desc = L["testModeSize_desc"],
				values = { [5] = "5", [10] = "10", [25] = "25", [40] = "40" },
				get = function()
					return self:GetLastTestModeSize()
				end,
				set = function(_, value)
					self.db.profile.testModeLastSize = value
				end,
				width = THIRD_WIDTH,
				order = 62,
			},
			testModeToggle = {
				type = "execute",
				name = function()
					if self:IsTestModeActive() then
						return L["Disable Test Mode"]
					end
					return L["Enable Test Mode"]
				end,
				desc = L["testModeToggle_desc"],
				func = function()
					if self:IsTestModeActive() then
						self:StopTestMode()
					else
						self:StartTestMode(self:GetLastTestModeSize())
					end
				end,
				disabled = function()
					return InCombatLockdown() or (not self:IsTestModeActive() and (IsInGroup() or IsInRaid()))
				end,
				width = THIRD_WIDTH,
				order = 63,
			},
			testModeLabel = {
				type = "description",
				name = L["testModeLabel_desc"],
				fontSize = "medium",
				order = 64,
			},
		}
	}

	-- Dispel Overlay settings (Retail only)
	if not self.isWoWClassicEra and not self.isWoWClassic then
		generalOptions.args.dispelOverlayHeader = {
			type = "header",
			name = L["Dispel Overlay"],
			order = 50,
		}
		generalOptions.args.dispelOverlayEnabled = {
			type = "toggle",
			name = L["Enable Dispel Overlay"],
			desc = L["dispelOverlayEnabled_desc"],
			get = function()
				return self.db.profile.dispelOverlay.enabled
			end,
			set = function(_, value)
				self.db.profile.dispelOverlay.enabled = value
				self:RefreshConfig()
			end,
			width = THIRD_WIDTH,
			order = 51,
		}
		generalOptions.args.dispelOverlayColorByType = {
			type = "toggle",
			name = L["Color by Debuff Type"],
			desc = L["dispelOverlayColorByType_desc"],
			get = function()
				return self.db.profile.dispelOverlay.colorByType
			end,
			set = function(_, value)
				self.db.profile.dispelOverlay.colorByType = value
				self:RefreshConfig()
			end,
			disabled = function()
				return not self.db.profile.dispelOverlay.enabled
			end,
			width = THIRD_WIDTH,
			order = 53,
		}
		generalOptions.args.dispelOverlayGlowStyle = {
			type = "select",
			name = L["Glow Style"],
			desc = L["dispelOverlayGlowStyle_desc"],
			values = { ["border"] = L["Border Only"], ["pulse"] = L["Pulse Only"], ["both"] = L["Both"] },
			get = function()
				return self.db.profile.dispelOverlay.glowStyle
			end,
			set = function(_, value)
				self.db.profile.dispelOverlay.glowStyle = value
				self:RefreshConfig()
			end,
			disabled = function()
				return not self.db.profile.dispelOverlay.enabled
			end,
			width = THIRD_WIDTH,
			order = 54,
		}
		generalOptions.args.dispelOverlayAlpha = {
			type = "range",
			name = L["Border Opacity"],
			desc = L["dispelOverlayBorderAlpha_desc"],
			isPercent = true,
			min = 0.1,
			max = 1,
			step = 0.05,
			get = function()
				return self.db.profile.dispelOverlay.borderAlpha
			end,
			set = function(_, value)
				self.db.profile.dispelOverlay.borderAlpha = value
				self:RefreshConfig()
			end,
			disabled = function()
				return not self.db.profile.dispelOverlay.enabled
			end,
			width = THIRD_WIDTH,
			order = 55,
		}
		generalOptions.args.dispelOverlayShowInParty = {
			type = "toggle",
			name = L["Show in Party"],
			desc = L["dispelOverlayShowInParty_desc"],
			get = function()
				return self.db.profile.dispelOverlay.showInParty
			end,
			set = function(_, value)
				self.db.profile.dispelOverlay.showInParty = value
				self:RefreshConfig()
			end,
			disabled = function()
				return not self.db.profile.dispelOverlay.enabled
			end,
			width = THIRD_WIDTH,
			order = 56,
		}
		generalOptions.args.dispelOverlayShowInRaid = {
			type = "toggle",
			name = L["Show in Raid"],
			desc = L["dispelOverlayShowInRaid_desc"],
			get = function()
				return self.db.profile.dispelOverlay.showInRaid
			end,
			set = function(_, value)
				self.db.profile.dispelOverlay.showInRaid = value
				self:RefreshConfig()
			end,
			disabled = function()
				return not self.db.profile.dispelOverlay.enabled
			end,
			width = THIRD_WIDTH,
			order = 57,
		}
	end

	return generalOptions
end
