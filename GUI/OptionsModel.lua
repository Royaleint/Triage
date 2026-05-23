-- Triage - Native Options Model

local Triage = _G.Triage
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local LibRangeCheck = LibStub("LibRangeCheck-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local OptionsModel = {}
Triage.OptionsModel = OptionsModel

local importExportBuffer = ""
local importExportStatus = ""

local function GetProfile()
	return Triage and Triage.db and Triage.db.profile
end

local function RefreshConfig()
	if Triage and Triage.RefreshConfig then
		Triage:RefreshConfig()
	end
end

local function WarnIfNoRangeChecker()
	local profile = GetProfile()
	if not profile or not profile.customRangeCheck or not LibRangeCheck then
		return
	end
	if not LibRangeCheck:GetFriendMinChecker(profile.customRange) then
		Triage:Print(L["customRangeUnavailable"]:format(profile.customRange))
	end
end

local function WarnIfNoTriageFocusRangeChecker()
	local profile = GetProfile()
	local focus = profile and profile.triageFocus
	if not focus or not focus.enabled or not LibRangeCheck then
		return
	end

	local range = Triage:GetTriageFocusRange()
	if not LibRangeCheck:GetFriendMinChecker(range) then
		Triage:Print(L["triageFocusRangeUnavailable"]:format(range))
	end
end

local function IsGrouped()
	local isInGroup = rawget(_G, "IsInGroup")
	return (isInGroup and isInGroup()) or IsInRaid()
end

local function OpenBlizzardRaidOptions()
	if Settings and Settings.OpenToCategory and Settings.INTERFACE_CATEGORY_ID then
		Settings.OpenToCategory(Settings.INTERFACE_CATEGORY_ID, RAID_FRAMES_LABEL)
	end
end

local function BuildFontValues()
	local values = {}
	local fonts = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font
	if not fonts then
		return values
	end

	for key, label in pairs(fonts) do
		values[#values + 1] = { key = key, label = label }
	end
	table.sort(values, function(left, right)
		return tostring(left.label) < tostring(right.label)
	end)
	return values
end

local function BuildPositionValues()
	local values = {}
	for index, label in ipairs(Triage.POSITIONS or {}) do
		values[#values + 1] = { key = index, label = label }
	end
	return values
end

local testModeSizeValues = {
	{ key = 5, label = "5" },
	{ key = 10, label = "10" },
	{ key = 25, label = "25" },
	{ key = 40, label = "40" },
}

local customRangeValues = {
	{ key = 5, label = L["Melee"] },
	{ key = 10, label = L["10 yards"] },
	{ key = 15, label = L["15 yards"] },
	{ key = 20, label = L["20 yards"] },
	{ key = 25, label = L["25 yards"] },
	{ key = 30, label = L["30 yards"] },
	{ key = 35, label = L["35 yards"] },
	{ key = 40, label = L["40 yards"] },
}

local extendedCustomRangeValues = {
	{ key = 5, label = L["Melee"] },
	{ key = 10, label = L["10 yards"] },
	{ key = 15, label = L["15 yards"] },
	{ key = 20, label = L["20 yards"] },
	{ key = 25, label = L["25 yards"] },
	{ key = 30, label = L["30 yards"] },
	{ key = 35, label = L["35 yards"] },
	{ key = 40, label = L["40 yards"] },
	{ key = 45, label = L["45 yards"] },
	{ key = 50, label = L["50 yards"] },
	{ key = 55, label = L["55 yards"] },
	{ key = 60, label = L["60 yards"] },
}

local triageFocusRangeModeValues = {
	{ key = "auto", label = L["Auto"] },
	{ key = "fixed", label = L["Fixed"] },
}

local triageFocusFixedRangeValues = {
	{ key = 30, label = L["30 yards"] },
	{ key = 35, label = L["35 yards"] },
	{ key = 40, label = L["40 yards"] },
	{ key = 45, label = L["45 yards"] },
	{ key = 50, label = L["50 yards"] },
	{ key = 55, label = L["55 yards"] },
	{ key = 60, label = L["60 yards"] },
}

local glowStyleValues = {
	{ key = "border", label = L["Border Only"] },
	{ key = "pulse", label = L["Pulse Only"] },
	{ key = "both", label = L["Both"] },
}

OptionsModel.sections = {
	{
		key = "general",
		label = L["General Options"],
		description = L["generalOptions_desc"],
		rows = {
			{
				key = "blizzardRaidOptionsButton",
				type = "button",
				label = L["Open the Blizzard Raid Profiles Options"],
				tooltip = L["blizzardRaidOptionsButton_desc"],
				run = OpenBlizzardRaidOptions,
				disabled = function()
					return not (Settings and Settings.OpenToCategory and Settings.INTERFACE_CATEGORY_ID)
				end,
			},
			{
				key = "testModeHeader",
				type = "header",
				label = L["Test Mode"],
			},
			{
				key = "testModeDescription",
				type = "description",
				label = L["testModeDescription_desc"],
			},
			{
				key = "testModeSize",
				type = "dropdown",
				label = L["Preview Group Size"],
				tooltip = L["testModeSize_desc"],
				values = testModeSizeValues,
				get = function()
					return Triage:GetLastTestModeSize()
				end,
				set = function(value)
					local profile = GetProfile()
					if profile then
						profile.testModeLastSize = value
					end
				end,
			},
			{
				key = "testModeToggle",
				type = "button",
				label = function()
					if Triage:IsTestModeActive() then
						return L["Disable Test Mode"]
					end
					return L["Enable Test Mode"]
				end,
				tooltip = L["testModeToggle_desc"],
				run = function()
					if Triage:IsTestModeActive() then
						Triage:StopTestMode()
					else
						Triage:StartTestMode(Triage:GetLastTestModeSize())
					end
				end,
				disabled = function()
					return InCombatLockdown() or (not Triage:IsTestModeActive() and IsGrouped())
				end,
			},
			{
				key = "testModeLabel",
				type = "description",
				label = L["testModeLabel_desc"],
			},
			{
				key = "textHeader",
				type = "header",
				label = L["Default Icon Visibility"],
			},
			{
				key = "showBuffs",
				type = "checkbox",
				label = L["Stock Buff Icons"],
				tooltip = L["showBuffs_desc"],
				get = function()
					return GetProfile().showBuffs
				end,
				set = function(value)
					GetProfile().showBuffs = value
					RefreshConfig()
				end,
			},
			{
				key = "showDebuffs",
				type = "checkbox",
				label = L["Stock Debuff Icons"],
				tooltip = L["showDebuffs_desc"],
				get = function()
					return GetProfile().showDebuffs
				end,
				set = function(value)
					GetProfile().showDebuffs = value
					RefreshConfig()
				end,
			},
			{
				key = "showDispellableDebuffs",
				type = "checkbox",
				label = L["Stock Dispellable Icons"],
				tooltip = L["showDispellableDebuffs_desc"],
				get = function()
					return GetProfile().showDispellableDebuffs
				end,
				set = function(value)
					GetProfile().showDispellableDebuffs = value
					RefreshConfig()
				end,
			},
			{
				key = "visualOptions",
				type = "header",
				label = L["General"],
			},
			{
				key = "powerBarOffset",
				type = "checkbox",
				label = L["Power Bar Vertical Offset"],
				tooltip = L["powerBarOffset_desc"],
				get = function()
					return GetProfile().powerBarOffset
				end,
				set = function(value)
					GetProfile().powerBarOffset = value
					RefreshConfig()
				end,
			},
			{
				key = "frameScale",
				type = "slider",
				label = L["Raidframe Scale"],
				tooltip = L["frameScale_desc"],
				isPercent = true,
				min = 0.5,
				max = 2,
				step = 0.01,
				get = function()
					return GetProfile().frameScale
				end,
				set = function(value)
					GetProfile().frameScale = value
					RefreshConfig()
				end,
			},
			{
				key = "backgroundAlpha",
				type = "slider",
				label = L["Background Opacity"],
				tooltip = L["backgroundAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return GetProfile().backgroundAlpha
				end,
				set = function(value)
					GetProfile().backgroundAlpha = value
					RefreshConfig()
				end,
			},
			{
				key = "indicatorFont",
				type = "dropdown",
				label = L["Indicator Font"],
				tooltip = L["indicatorFont_desc"],
				values = BuildFontValues(),
				get = function()
					return GetProfile().indicatorFont
				end,
				set = function(value)
					GetProfile().indicatorFont = value
					RefreshConfig()
				end,
			},
			{
				key = "outOfRangeOptions",
				type = "header",
				label = L["Out-of-Range"],
			},
			{
				key = "customRangeCheck",
				type = "checkbox",
				label = L["Override Default Distance"],
				tooltip = L["customRange_desc"],
				get = function()
					return GetProfile().customRangeCheck
				end,
				set = function(value)
					GetProfile().customRangeCheck = value
					RefreshConfig()
					WarnIfNoRangeChecker()
				end,
			},
			{
				key = "customRange",
				type = "dropdown",
				label = L["Select a Custom Distance"],
				tooltip = L["customRangeCheck_desc"],
				values = function()
					if Triage.supportsExtendedRangeOptions then
						return extendedCustomRangeValues
					end
					return customRangeValues
				end,
				get = function()
					return GetProfile().customRange
				end,
				set = function(value)
					GetProfile().customRange = value
					RefreshConfig()
					WarnIfNoRangeChecker()
				end,
				disabled = function()
					return not GetProfile().customRangeCheck
				end,
			},
			{
				key = "rangeAlpha",
				type = "slider",
				label = L["Out-of-Range Opacity"],
				tooltip = L["rangeAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return GetProfile().rangeAlpha
				end,
				set = function(value)
					GetProfile().rangeAlpha = value
					RefreshConfig()
				end,
			},
			{
				key = "keepIndicatorsVisible",
				type = "checkbox",
				label = L["Keep Indicators Visible Out of Range"],
				tooltip = L["keepIndicatorsVisible_desc"],
				get = function()
					return GetProfile().keepIndicatorsVisible
				end,
				set = function(value)
					GetProfile().keepIndicatorsVisible = value
					RefreshConfig()
				end,
			},
			{
				key = "triageFocusHeader",
				type = "header",
				label = L["Triage Focus"],
			},
			{
				key = "triageFocusEnabled",
				type = "checkbox",
				label = L["Enable Triage Focus"],
				tooltip = L["triageFocusEnabled_desc"],
				get = function()
					return GetProfile().triageFocus.enabled
				end,
				set = function(value)
					GetProfile().triageFocus.enabled = value
					RefreshConfig()
					WarnIfNoTriageFocusRangeChecker()
				end,
			},
			{
				key = "triageFocusForceEnabled",
				type = "checkbox",
				label = L["Force Enable"],
				tooltip = L["triageFocusForceEnabled_desc"],
				get = function()
					return GetProfile().triageFocus.forceEnabled
				end,
				set = function(value)
					GetProfile().triageFocus.forceEnabled = value
					RefreshConfig()
					WarnIfNoTriageFocusRangeChecker()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "triageFocusRangeMode",
				type = "dropdown",
				label = L["Range Mode"],
				tooltip = L["triageFocusRangeMode_desc"],
				values = triageFocusRangeModeValues,
				get = function()
					return GetProfile().triageFocus.rangeMode
				end,
				set = function(value)
					GetProfile().triageFocus.rangeMode = value
					RefreshConfig()
					WarnIfNoTriageFocusRangeChecker()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "triageFocusFixedRange",
				type = "dropdown",
				label = L["Fixed Range"],
				tooltip = L["triageFocusFixedRange_desc"],
				values = triageFocusFixedRangeValues,
				get = function()
					return GetProfile().triageFocus.fixedRange
				end,
				set = function(value)
					GetProfile().triageFocus.fixedRange = value
					RefreshConfig()
					WarnIfNoTriageFocusRangeChecker()
				end,
				disabled = function()
					local focus = GetProfile().triageFocus
					return not focus.enabled or focus.rangeMode ~= "fixed"
				end,
			},
			{
				key = "triageFocusThreshold",
				type = "slider",
				label = L["Minimum Deficit"],
				tooltip = L["triageFocusThreshold_desc"],
				isPercent = true,
				min = 0.01,
				max = 1,
				step = 0.01,
				get = function()
					return GetProfile().triageFocus.minDeficitPercent / 100
				end,
				set = function(value)
					GetProfile().triageFocus.minDeficitPercent = value * 100
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "triageFocusInterval",
				type = "slider",
				label = L["Update Interval"],
				tooltip = L["triageFocusInterval_desc"],
				min = 0.1,
				max = 1,
				step = 0.05,
				get = function()
					return GetProfile().triageFocus.updateInterval
				end,
				set = function(value)
					GetProfile().triageFocus.updateInterval = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "triageFocusGlowStyle",
				type = "dropdown",
				label = L["Glow Style"],
				tooltip = L["triageFocusGlowStyle_desc"],
				values = glowStyleValues,
				get = function()
					return GetProfile().triageFocus.glowStyle
				end,
				set = function(value)
					GetProfile().triageFocus.glowStyle = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "triageFocusWidth",
				type = "slider",
				label = L["Border Width"],
				tooltip = L["triageFocusWidth_desc"],
				min = 1,
				max = 8,
				step = 1,
				get = function()
					return GetProfile().triageFocus.width
				end,
				set = function(value)
					GetProfile().triageFocus.width = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "triageFocusColor",
				type = "color",
				label = L["Color"],
				tooltip = L["triageFocusColor_desc"],
				get = function()
					return unpack(GetProfile().triageFocus.color)
				end,
				set = function(r, g, b, a)
					GetProfile().triageFocus.color = { r, g, b, a }
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().triageFocus.enabled
				end,
			},
			{
				key = "dispelOverlayHeader",
				type = "header",
				label = L["Dispel Overlay"],
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
			},
			{
				key = "dispelOverlayEnabled",
				type = "checkbox",
				label = L["Enable Dispel Overlay"],
				tooltip = L["dispelOverlayEnabled_desc"],
				get = function()
					return GetProfile().dispelOverlay.enabled
				end,
				set = function(value)
					GetProfile().dispelOverlay.enabled = value
					RefreshConfig()
				end,
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
			},
			{
				key = "dispelOverlayColorByType",
				type = "checkbox",
				label = L["Color by Debuff Type"],
				tooltip = L["dispelOverlayColorByType_desc"],
				get = function()
					return GetProfile().dispelOverlay.colorByType
				end,
				set = function(value)
					GetProfile().dispelOverlay.colorByType = value
					RefreshConfig()
				end,
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
				disabled = function()
					return not GetProfile().dispelOverlay.enabled
				end,
			},
			{
				key = "dispelOverlayGlowStyle",
				type = "dropdown",
				label = L["Glow Style"],
				tooltip = L["dispelOverlayGlowStyle_desc"],
				values = glowStyleValues,
				get = function()
					return GetProfile().dispelOverlay.glowStyle
				end,
				set = function(value)
					GetProfile().dispelOverlay.glowStyle = value
					RefreshConfig()
				end,
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
				disabled = function()
					return not GetProfile().dispelOverlay.enabled
				end,
			},
			{
				key = "dispelOverlayAlpha",
				type = "slider",
				label = L["Border Opacity"],
				tooltip = L["dispelOverlayBorderAlpha_desc"],
				isPercent = true,
				min = 0.1,
				max = 1,
				step = 0.05,
				get = function()
					return GetProfile().dispelOverlay.borderAlpha
				end,
				set = function(value)
					GetProfile().dispelOverlay.borderAlpha = value
					RefreshConfig()
				end,
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
				disabled = function()
					return not GetProfile().dispelOverlay.enabled
				end,
			},
			{
				key = "dispelOverlayShowInParty",
				type = "checkbox",
				label = L["Show in Party"],
				tooltip = L["dispelOverlayShowInParty_desc"],
				get = function()
					return GetProfile().dispelOverlay.showInParty
				end,
				set = function(value)
					GetProfile().dispelOverlay.showInParty = value
					RefreshConfig()
				end,
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
				disabled = function()
					return not GetProfile().dispelOverlay.enabled
				end,
			},
			{
				key = "dispelOverlayShowInRaid",
				type = "checkbox",
				label = L["Show in Raid"],
				tooltip = L["dispelOverlayShowInRaid_desc"],
				get = function()
					return GetProfile().dispelOverlay.showInRaid
				end,
				set = function(value)
					GetProfile().dispelOverlay.showInRaid = value
					RefreshConfig()
				end,
				hidden = function()
					return not Triage.supportsDispelOverlay
				end,
				disabled = function()
					return not GetProfile().dispelOverlay.enabled
				end,
			},
		},
	},
	{
		key = "targetMarkers",
		label = L["Target Marker Options"],
		description = L["markerOptions_desc"] .. ":",
		rows = {
			{
				key = "generalHeader",
				type = "header",
				label = L["General"],
			},
			{
				key = "showTargetMarkers",
				type = "checkbox",
				label = L["Show Target Markers"],
				tooltip = L["showTargetMarkers_desc"],
				get = function()
					return GetProfile().showTargetMarkers
				end,
				set = function(value)
					GetProfile().showTargetMarkers = value
					RefreshConfig()
				end,
			},
			{
				key = "markerSize",
				type = "slider",
				label = L["Target Marker Size"],
				tooltip = L["markerSize_desc"],
				min = 1,
				max = 40,
				step = 1,
				get = function()
					return GetProfile().markerSize
				end,
				set = function(value)
					GetProfile().markerSize = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().showTargetMarkers
				end,
			},
			{
				key = "markerAlpha",
				type = "slider",
				label = L["Target Marker Opacity"],
				tooltip = L["markerAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return GetProfile().markerAlpha
				end,
				set = function(value)
					GetProfile().markerAlpha = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().showTargetMarkers
				end,
			},
			{
				key = "positionOptions",
				type = "header",
				label = L["Position"],
			},
			{
				key = "markerPosition",
				type = "dropdown",
				label = L["Marker Position"],
				tooltip = L["markerPosition_desc"],
				values = BuildPositionValues,
				get = function()
					return GetProfile().markerPosition
				end,
				set = function(value)
					GetProfile().markerPosition = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().showTargetMarkers
				end,
			},
			{
				key = "markerVerticalOffset",
				type = "slider",
				label = L["Vertical Offset"],
				tooltip = L["verticalOffset_desc"],
				isPercent = true,
				min = -1,
				max = 1,
				step = 0.01,
				get = function()
					return GetProfile().markerVerticalOffset
				end,
				set = function(value)
					GetProfile().markerVerticalOffset = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().showTargetMarkers
				end,
			},
			{
				key = "markerVerticalNudge",
				type = "slider",
				label = L["Marker Vertical Nudge"],
				tooltip = L["markerVerticalNudge_desc"],
				min = -10,
				max = 10,
				step = 1,
				get = function()
					return GetProfile().markerVerticalNudge or 0
				end,
				set = function(value)
					GetProfile().markerVerticalNudge = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().showTargetMarkers
				end,
			},
			{
				key = "markerHorizontalOffset",
				type = "slider",
				label = L["Horizontal Offset"],
				tooltip = L["horizontalOffset_desc"],
				isPercent = true,
				min = -1,
				max = 1,
				step = 0.01,
				get = function()
					return GetProfile().markerHorizontalOffset
				end,
				set = function(value)
					GetProfile().markerHorizontalOffset = value
					RefreshConfig()
				end,
				disabled = function()
					return not GetProfile().showTargetMarkers
				end,
			},
			{
				key = "resetTargetMarkerDefaults",
				type = "button",
				label = L["Reset Target Marker Defaults"],
				tooltip = L["resetTargetMarkerDefaults_desc"],
				run = function()
					Triage:ResetTargetMarkerDefaults()
					Triage:Print(L["Target marker defaults reset."])
				end,
			},
		},
	},
	{
		key = "profiles",
		label = L["Profiles"],
		description = L["Profiles"],
		rows = {
			{
				key = "openAceProfiles",
				type = "button",
				label = L["Profiles"],
				tooltip = L["Profiles"],
				run = function()
					if Triage.OptionsFrame and Triage.OptionsFrame.Hide then
						Triage.OptionsFrame:Hide()
					end
					AceConfigDialog:Open("Triage Profiles")
				end,
			},
		},
	},
	{
		key = "importExport",
		label = L["Profile"] .. " " .. L["Import"] .. "/" .. L["Export"],
		description = L["ImportExport_Desc"],
		rows = {
			{
				key = "importExportWarning",
				type = "description",
				label = L["ImportExport_WarningDesc"],
				height = 48,
			},
			{
				key = "importExportText",
				type = "multiline",
				label = L["Import or Export the current profile:"],
				tooltip = L["ImportExport_WarningDesc"],
				height = 280,
				get = function()
					return importExportBuffer
				end,
				onTextChanged = function(value)
					importExportBuffer = value
					importExportStatus = ""
				end,
			},
			{
				key = "exportCurrentProfile",
				type = "button",
				label = L["Export"],
				run = function()
					importExportBuffer = Triage:SerializeAndCompressProfile()
					importExportStatus = L["Export"] .. " complete."
				end,
			},
			{
				key = "importCurrentProfile",
				type = "button",
				label = L["Import"],
				tooltip = L["ImportWarning"],
				run = function()
					if importExportBuffer == "" then
						importExportStatus = L["No data to import."] .. " " .. L["Aborting."]
						return
					end
					Triage:DeserializeAndDecompressProfile(importExportBuffer)
					importExportStatus = L["Import"] .. " attempted. Check chat for the result."
					RefreshConfig()
				end,
			},
			{
				key = "clearImportExportBuffer",
				type = "button",
				label = "Clear",
				run = function()
					importExportBuffer = ""
					importExportStatus = ""
				end,
			},
			{
				key = "importExportStatus",
				type = "status",
				get = function()
					return importExportStatus
				end,
			},
		},
	},
}

function OptionsModel:GetSections()
	return self.sections
end

function OptionsModel:GetSection(sectionKey)
	for _, section in ipairs(self.sections) do
		if section.key == sectionKey then
			return section
		end
	end
	return self.sections[1]
end

return OptionsModel
