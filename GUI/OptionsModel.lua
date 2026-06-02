-- Triage - Native Options Model

local Triage = _G.Triage
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local LibRangeCheck = LibStub("LibRangeCheck-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local OptionsModel = {}
Triage.OptionsModel = OptionsModel

local importExportBuffer = ""
local importExportStatus = ""
local RESET_ALL_INDICATORS_POPUP = "TRIAGE_NATIVE_RESET_ALL_INDICATOR_SETTINGS"
local RESET_ALL_AURA_LISTS_POPUP = "TRIAGE_NATIVE_RESET_ALL_AURA_LISTS"
local RESET_SPEC_DEFAULTS_POPUP = "TRIAGE_NATIVE_RESET_SPEC_AURA_DEFAULTS"
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

local function GetProfile()
	return Triage and Triage.db and Triage.db.profile
end

local function GetOptionsFrameSettings()
	local profile = GetProfile()
	if not profile then
		return nil
	end
	profile.optionsFrame = profile.optionsFrame or {}
	return profile.optionsFrame
end

local function RefreshConfig()
	if Triage and Triage.RefreshConfig then
		Triage:RefreshConfig()
	end
end

local function RefreshOptionsFrame()
	if Triage and Triage.OptionsFrame and Triage.OptionsFrame.Refresh then
		Triage.OptionsFrame:Refresh()
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

local function BuildIndicatorPositionValues(includeAll)
	local values = {}
	if includeAll then
		values[#values + 1] = { key = "all", label = L["All Other Positions"] }
	end
	for index, position in ipairs(Triage.POSITIONS or {}) do
		values[#values + 1] = { key = tostring(index), label = index .. ": " .. position }
	end
	return values
end

local function GetIndicatorProfile(index)
	local profile = GetProfile()
	return profile and profile["indicator-" .. index]
end

local function CopyValue(value)
	if type(value) ~= "table" then
		return value
	end

	local copied = {}
	for key, childValue in pairs(value) do
		copied[key] = CopyValue(childValue)
	end
	return copied
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

local function CopyIndicatorSettings()
	local sourceIndex = tonumber(copySource)
	local sourceDB = GetIndicatorProfile(sourceIndex)
	local copiedTargets = 0
	if not sourceDB then
		return copiedTargets
	end

	for targetIndex = 1, 9 do
		if (copyTarget == "all" and targetIndex ~= sourceIndex) or targetIndex == tonumber(copyTarget) then
			local targetDB = GetIndicatorProfile(targetIndex)
			if targetDB then
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
	end

	return copiedTargets
end

local function ResetIndicatorSettings()
	local defaults = Triage:CreateDefaults()
	local defaultDB = defaults.profile["indicator-1"]
	local resetCount = 0

	for targetIndex = 1, 9 do
		if resetScope == "all" or targetIndex == tonumber(copySource) then
			local targetDB = GetIndicatorProfile(targetIndex)
			if targetDB then
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
	end

	return resetCount
end

local function ResetAuraWatchLists(resetAll)
	local resetCount = 0
	for targetIndex = 1, 9 do
		if resetAll or targetIndex == tonumber(copySource) then
			local indicatorDB = GetIndicatorProfile(targetIndex)
			if indicatorDB then
				indicatorDB.auras = ""
				resetCount = resetCount + 1
			end
		end
	end
	RefreshConfig()
	Triage:Print(L["Aura watch lists reset."]:format(resetCount))
end

local function ApplyCurrentSpecDefaults(reset)
	local applied, skipped, specID = Triage:ApplyCurrentSpecAuraDefaults(reset)
	if applied == 0 and not specID then
		Triage:Print(L["No spec aura defaults available."])
	elseif reset then
		Triage:Print(L["Spec aura defaults reset."]:format(applied, skipped))
	else
		Triage:Print(L["Spec aura defaults applied."]:format(applied, skipped))
	end
end

local function ConfirmOrRun(popupKey, run)
	local showPopup = rawget(_G, "StaticPopup_Show")
	if showPopup then
		showPopup(popupKey, nil, nil, { run = run })
		return
	end
	run()
end

local popupDialogs = rawget(_G, "StaticPopupDialogs")
if popupDialogs then
	popupDialogs[RESET_ALL_INDICATORS_POPUP] = {
		text = L["resetAllIndicatorSettings_confirm"],
		button1 = L["Yes"],
		button2 = L["No"],
		OnAccept = function(_, data)
			if data and data.run then
				data.run()
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
			if data and data.run then
				data.run()
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
			if data and data.run then
				data.run()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
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
				key = "optionsFrameOpacity",
				type = "slider",
				label = "Options Window Opacity",
				tooltip = "Adjust the native Triage options window opacity.",
				isPercent = true,
				min = 0.2,
				max = 1,
				step = 0.01,
				get = function()
					local settings = GetOptionsFrameSettings()
					return (settings and settings.opacity) or 0.82
				end,
				set = function(value)
					local settings = GetOptionsFrameSettings()
					if settings then
						settings.opacity = value
					end
					RefreshOptionsFrame()
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

local casterFilterValues = {
	{ key = "all", label = L["All Casters"] },
	{ key = "mine", label = L["Mine Only"] },
	{ key = "notMine", label = L["Not Mine"] },
}

local tooltipLocationValues = {
	{ key = "ANCHOR_CURSOR", label = L["Attached to Cursor"] },
	{ key = "ANCHOR_PRESERVE", label = L["Blizzard Default"] },
}

local cornerLocationValues = {
	{ key = "TOPLEFT", label = L["Top-Left"] },
	{ key = "TOPRIGHT", label = L["Top-Right"] },
	{ key = "BOTTOMLEFT", label = L["Bottom-Left"] },
	{ key = "BOTTOMRIGHT", label = L["Bottom-Right"] },
}

local countdownLocationValues = {
	{ key = "TOPLEFT", label = L["Top-Left"] },
	{ key = "TOPRIGHT", label = L["Top-Right"] },
	{ key = "CENTER", label = L["Center"] },
	{ key = "BOTTOMLEFT", label = L["Bottom-Left"] },
	{ key = "BOTTOMRIGHT", label = L["Bottom-Right"] },
}

local function CreateIndicatorToolsSection()
	return {
		key = "indicatorTools",
		label = L["Indicator Tools"],
		rows = {
			{
				key = "specDefaultsHeader",
				type = "header",
				label = L["Spec Aura Defaults"],
				hidden = function()
					return not Triage.supportsSpecDefaults
				end,
			},
			{
				key = "applySpecDefaults",
				type = "button",
				label = L["Apply Current Spec Defaults"],
				tooltip = L["applySpecDefaults_desc"],
				run = function()
					ApplyCurrentSpecDefaults(false)
				end,
				hidden = function()
					return not Triage.supportsSpecDefaults
				end,
				disabled = function()
					return not Triage:HasCurrentSpecAuraDefaults()
				end,
			},
			{
				key = "resetSpecDefaults",
				type = "button",
				label = L["Reset Current Spec Defaults"],
				tooltip = L["resetSpecDefaults_desc"],
				run = function()
					ConfirmOrRun(RESET_SPEC_DEFAULTS_POPUP, function()
						ApplyCurrentSpecDefaults(true)
					end)
				end,
				hidden = function()
					return not Triage.supportsSpecDefaults
				end,
				disabled = function()
					return not Triage:HasCurrentSpecAuraDefaults()
				end,
			},
			{
				key = "copySettingsHeader",
				type = "header",
				label = L["Copy Indicator Settings"],
			},
			{
				key = "copySource",
				type = "dropdown",
				label = L["Copy From"],
				tooltip = L["copyIndicatorSource_desc"],
				values = function()
					return BuildIndicatorPositionValues(false)
				end,
				get = function()
					return copySource
				end,
				set = function(value)
					copySource = value
					if copyTarget == value then
						copyTarget = "all"
					end
				end,
			},
			{
				key = "copyTarget",
				type = "dropdown",
				label = L["Copy To"],
				tooltip = L["copyIndicatorTarget_desc"],
				values = function()
					return BuildIndicatorPositionValues(true)
				end,
				get = function()
					return copyTarget
				end,
				set = function(value)
					copyTarget = value
				end,
			},
			{
				key = "copyVisibility",
				type = "checkbox",
				label = L["Visibility and Behavior"],
				get = function()
					return copyCategories.visibility
				end,
				set = function(value)
					copyCategories.visibility = value
				end,
			},
			{
				key = "copyIcon",
				type = "checkbox",
				label = L["Icon and Visuals"],
				get = function()
					return copyCategories.icon
				end,
				set = function(value)
					copyCategories.icon = value
				end,
			},
			{
				key = "copyText",
				type = "checkbox",
				label = L["Text"],
				get = function()
					return copyCategories.text
				end,
				set = function(value)
					copyCategories.text = value
				end,
			},
			{
				key = "copyAnimation",
				type = "checkbox",
				label = L["Animations"],
				get = function()
					return copyCategories.animation
				end,
				set = function(value)
					copyCategories.animation = value
				end,
			},
			{
				key = "copyIndicatorSettings",
				type = "button",
				label = L["Copy Settings"],
				tooltip = L["copyIndicatorSettings_desc"],
				run = function()
					if CountSelectedCopyCategories() == 0 then
						Triage:Print(L["No indicator setting categories selected."])
						return
					end

					local copiedTargets = CopyIndicatorSettings()
					RefreshConfig()
					Triage:Print(L["Indicator settings copied."]:format(copiedTargets))
				end,
				disabled = function()
					return copyTarget == copySource
				end,
			},
			{
				key = "resetScope",
				type = "dropdown",
				label = L["Reset Scope"],
				tooltip = L["resetIndicatorScope_desc"],
				values = {
					{ key = "current", label = L["Copy From Position"] },
					{ key = "all", label = L["All Positions"] },
				},
				get = function()
					return resetScope
				end,
				set = function(value)
					resetScope = value
				end,
			},
			{
				key = "resetIndicatorSettings",
				type = "button",
				label = L["Reset Settings"],
				tooltip = L["resetIndicatorSettings_desc"],
				run = function()
					if CountSelectedCopyCategories() == 0 then
						Triage:Print(L["No indicator setting categories selected."])
						return
					end

					local run = function()
						local resetCount = ResetIndicatorSettings()
						RefreshConfig()
						Triage:Print(L["Indicator settings reset."]:format(resetCount))
					end
					if resetScope == "all" then
						ConfirmOrRun(RESET_ALL_INDICATORS_POPUP, run)
					else
						run()
					end
				end,
			},
			{
				key = "auraListHeader",
				type = "header",
				label = L["Aura Watch Lists"],
			},
			{
				key = "resetSelectedAuraList",
				type = "button",
				label = L["Reset Selected Aura List"],
				tooltip = L["resetSelectedAuraList_desc"],
				run = function()
					ResetAuraWatchLists(false)
				end,
			},
			{
				key = "resetAllAuraLists",
				type = "button",
				label = L["Reset All Aura Lists"],
				tooltip = L["resetAllAuraLists_desc"],
				run = function()
					ConfirmOrRun(RESET_ALL_AURA_LISTS_POPUP, function()
						ResetAuraWatchLists(true)
					end)
				end,
			},
		},
	}
end

local function CreateIndicatorSection(index, position)
	local function indicator()
		return GetIndicatorProfile(index)
	end

	return {
		key = "indicator" .. index,
		label = index .. ": " .. position,
		description = L["indicatorOptions_desc"] .. ":",
		rows = {
			{
				key = "indicator" .. index .. "Instructions",
				type = "description",
				label = position .. "\n\n" .. L["instructions_desc1"] .. ".\n\n" .. L["auras_usage"] .. ".",
				height = 70,
			},
			{
				key = "indicator" .. index .. "Auras",
				type = "auraInput",
				label = L["Aura Watch List"],
				tooltip = L["auras_desc"],
				height = 280,
				get = function()
					return indicator().auras
				end,
				onTextChanged = function(value)
					indicator().auras = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "VisibilityHeader",
				type = "header",
				label = L["Visibility and Behavior"],
			},
			{
				key = "indicator" .. index .. "CasterFilter",
				type = "dropdown",
				label = L["Caster Filter"],
				tooltip = L["casterFilter_desc"],
				values = casterFilterValues,
				get = function()
					return indicator().casterFilter
				end,
				set = function(value)
					indicator().casterFilter = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "MeOnly",
				type = "checkbox",
				label = L["Show On Me Only"],
				tooltip = L["meOnly_desc"],
				get = function()
					return indicator().meOnly
				end,
				set = function(value)
					indicator().meOnly = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "MissingOnly",
				type = "checkbox",
				label = L["Show Only if Missing"],
				tooltip = L["missingOnly_desc"],
				get = function()
					return indicator().missingOnly
				end,
				set = function(value)
					indicator().missingOnly = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "TooltipsHeader",
				type = "header",
				label = L["Tooltips"],
			},
			{
				key = "indicator" .. index .. "ShowTooltip",
				type = "checkbox",
				label = L["Show Tooltip"],
				tooltip = L["showTooltip_desc"],
				get = function()
					return indicator().showTooltip
				end,
				set = function(value)
					indicator().showTooltip = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "TooltipLocation",
				type = "dropdown",
				label = L["Tooltip Location"],
				tooltip = L["tooltipLocation_desc"],
				values = tooltipLocationValues,
				get = function()
					return indicator().tooltipLocation
				end,
				set = function(value)
					indicator().tooltipLocation = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showTooltip
				end,
			},
			{
				key = "indicator" .. index .. "IconHeader",
				type = "header",
				label = L["Icon and Visuals"],
			},
			{
				key = "indicator" .. index .. "IndicatorSize",
				type = "slider",
				label = L["Indicator Size"],
				tooltip = L["indicatorSize_desc"],
				min = 1,
				max = 30,
				step = 1,
				get = function()
					return indicator().indicatorSize
				end,
				set = function(value)
					indicator().indicatorSize = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "VerticalOffset",
				type = "slider",
				label = L["Vertical Offset"],
				tooltip = L["verticalOffset_desc"],
				isPercent = true,
				min = -1,
				max = 1,
				step = 0.005,
				get = function()
					return indicator().indicatorVerticalOffset
				end,
				set = function(value)
					indicator().indicatorVerticalOffset = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "HorizontalOffset",
				type = "slider",
				label = L["Horizontal Offset"],
				tooltip = L["horizontalOffset_desc"],
				isPercent = true,
				min = -1,
				max = 1,
				step = 0.005,
				get = function()
					return indicator().indicatorHorizontalOffset
				end,
				set = function(value)
					indicator().indicatorHorizontalOffset = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "ShowIcon",
				type = "checkbox",
				label = L["Show Icon"],
				tooltip = L["showIcon_desc1"] .. "\n(" .. L["showIcon_desc2"] .. ")",
				get = function()
					return indicator().showIcon
				end,
				set = function(value)
					indicator().showIcon = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "IndicatorAlpha",
				type = "slider",
				label = L["Icon Opacity"],
				tooltip = L["indicatorAlpha_desc"],
				min = 0,
				max = 1,
				step = 0.05,
				get = function()
					return indicator().indicatorAlpha
				end,
				set = function(value)
					indicator().indicatorAlpha = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showIcon
				end,
			},
			{
				key = "indicator" .. index .. "IndicatorColor",
				type = "color",
				label = L["Indicator Color"],
				tooltip = L["indicatorColor_desc1"] .. "\n(" .. L["indicatorColor_desc2"] .. ")",
				get = function()
					return unpack(indicator().indicatorColor)
				end,
				set = function(r, g, b, a)
					indicator().indicatorColor = { r, g, b, a }
					RefreshConfig()
				end,
				disabled = function()
					return indicator().showIcon
				end,
			},
			{
				key = "indicator" .. index .. "ColorIndicatorByDebuff",
				type = "checkbox",
				label = L["Color By Debuff Type"],
				tooltip = L["colorByDebuff_desc"],
				get = function()
					return indicator().colorIndicatorByDebuff
				end,
				set = function(value)
					indicator().colorIndicatorByDebuff = value
					RefreshConfig()
				end,
				disabled = function()
					return indicator().showIcon
				end,
			},
			{
				key = "indicator" .. index .. "ColorIndicatorByTime",
				type = "checkbox",
				label = L["Color By Remaining Time"],
				tooltip = L["colorByTime_desc"],
				get = function()
					return indicator().colorIndicatorByTime
				end,
				set = function(value)
					indicator().colorIndicatorByTime = value
					RefreshConfig()
				end,
				disabled = function()
					return indicator().showIcon
				end,
			},
			{
				key = "indicator" .. index .. "ColorIndicatorByTimeLow",
				type = "slider",
				label = L["Time #1"],
				tooltip = L["colorByTime_low_desc"] .. "\n(" .. L["zeroMeansIgnored_desc"] .. ")",
				min = 0,
				max = 10,
				step = 1,
				get = function()
					return indicator().colorIndicatorByTime_low
				end,
				set = function(value)
					indicator().colorIndicatorByTime_low = value
					RefreshConfig()
				end,
				disabled = function()
					return indicator().showIcon or not indicator().colorIndicatorByTime
				end,
			},
			{
				key = "indicator" .. index .. "ColorIndicatorByTimeHigh",
				type = "slider",
				label = L["Time #2"],
				tooltip = L["colorByTime_high_desc"] .. "\n(" .. L["zeroMeansIgnored_desc"] .. ")",
				min = 0,
				max = 10,
				step = 1,
				get = function()
					return indicator().colorIndicatorByTime_high
				end,
				set = function(value)
					indicator().colorIndicatorByTime_high = value
					RefreshConfig()
				end,
				disabled = function()
					return indicator().showIcon or not indicator().colorIndicatorByTime
				end,
			},
			{
				key = "indicator" .. index .. "TextHeader",
				type = "header",
				label = L["Text"],
			},
			{
				key = "indicator" .. index .. "ShowCountdownText",
				type = "checkbox",
				label = L["Show Countdown Text"],
				tooltip = L["showCountdownText_desc"],
				get = function()
					return indicator().showCountdownText
				end,
				set = function(value)
					indicator().showCountdownText = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "ShowStackSize",
				type = "checkbox",
				label = L["Show Stack Size"],
				tooltip = L["showStackSize_desc"],
				get = function()
					return indicator().showStackSize
				end,
				set = function(value)
					indicator().showStackSize = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "TextSize",
				type = "slider",
				label = L["Countdown Text Size"],
				tooltip = L["countdownTextSize_desc"],
				min = 1,
				max = 30,
				step = 1,
				get = function()
					return indicator().textSize
				end,
				set = function(value)
					indicator().textSize = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText
				end,
			},
			{
				key = "indicator" .. index .. "StackSizeLocation",
				type = "dropdown",
				label = L["Stack Size Location"],
				tooltip = L["stackSizeLocation_desc"],
				values = cornerLocationValues,
				get = function()
					return indicator().stackSizeLocation
				end,
				set = function(value)
					indicator().stackSizeLocation = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showStackSize
				end,
			},
			{
				key = "indicator" .. index .. "CountdownLocation",
				type = "dropdown",
				label = L["Countdown Text Location"],
				tooltip = L["countdownLocation_desc"],
				values = countdownLocationValues,
				get = function()
					return indicator().countdownLocation
				end,
				set = function(value)
					indicator().countdownLocation = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText
				end,
			},
			{
				key = "indicator" .. index .. "TextColor",
				type = "color",
				label = L["Text Color"],
				tooltip = L["textColor_desc1"] .. "\n(" .. L["textColor_desc2"] .. ")",
				get = function()
					return unpack(indicator().textColor)
				end,
				set = function(r, g, b, a)
					indicator().textColor = { r, g, b, a }
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText
				end,
			},
			{
				key = "indicator" .. index .. "ColorTextByDebuff",
				type = "checkbox",
				label = L["Color By Debuff Type"],
				tooltip = L["colorByDebuff_desc"],
				get = function()
					return indicator().colorTextByDebuff
				end,
				set = function(value)
					indicator().colorTextByDebuff = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText
				end,
			},
			{
				key = "indicator" .. index .. "ColorTextByTime",
				type = "checkbox",
				label = L["Color By Remaining Time"],
				tooltip = L["colorByTime_desc"],
				get = function()
					return indicator().colorTextByTime
				end,
				set = function(value)
					indicator().colorTextByTime = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText
				end,
			},
			{
				key = "indicator" .. index .. "ColorTextByTimeLow",
				type = "slider",
				label = L["Time #1"],
				tooltip = L["colorByTime_low_desc"] .. "\n(" .. L["zeroMeansIgnored_desc"] .. ")",
				min = 0,
				max = 10,
				step = 1,
				get = function()
					return indicator().colorTextByTime_low
				end,
				set = function(value)
					indicator().colorTextByTime_low = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText or not indicator().colorTextByTime
				end,
			},
			{
				key = "indicator" .. index .. "ColorTextByTimeHigh",
				type = "slider",
				label = L["Time #2"],
				tooltip = L["colorByTime_high_desc"] .. "\n(" .. L["zeroMeansIgnored_desc"] .. ")",
				min = 0,
				max = 10,
				step = 1,
				get = function()
					return indicator().colorTextByTime_high
				end,
				set = function(value)
					indicator().colorTextByTime_high = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().showCountdownText or not indicator().colorTextByTime
				end,
			},
			{
				key = "indicator" .. index .. "AnimationsHeader",
				type = "header",
				label = L["Animations"],
			},
			{
				key = "indicator" .. index .. "ShowCountdownSwipe",
				type = "checkbox",
				label = L["Show Countdown Swipe"],
				tooltip = L["showCountdownSwipe_desc"],
				get = function()
					return indicator().showCountdownSwipe
				end,
				set = function(value)
					indicator().showCountdownSwipe = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "IndicatorGlow",
				type = "checkbox",
				label = L["Indicator Glow Effect"],
				tooltip = L["indicatorGlow_desc"],
				get = function()
					return indicator().indicatorGlow
				end,
				set = function(value)
					indicator().indicatorGlow = value
					RefreshConfig()
				end,
			},
			{
				key = "indicator" .. index .. "GlowRemainingSecs",
				type = "slider",
				label = L["Glow At Countdown Time"],
				tooltip = L["glowRemainingSecs_desc1"] .. "\n(" .. L["glowRemainingSecs_desc2"] .. ")",
				min = 0,
				max = 10,
				step = 1,
				get = function()
					return indicator().glowRemainingSecs
				end,
				set = function(value)
					indicator().glowRemainingSecs = value
					RefreshConfig()
				end,
				disabled = function()
					return not indicator().indicatorGlow
				end,
			},
		},
	}
end

table.insert(OptionsModel.sections, 2, CreateIndicatorToolsSection())
for index = #(Triage.POSITIONS or {}), 1, -1 do
	table.insert(OptionsModel.sections, 3, CreateIndicatorSection(index, Triage.POSITIONS[index]))
end

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
