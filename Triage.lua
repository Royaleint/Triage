-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

--- Triage is the main addon object.
---@class Triage : AceAddon-3.0 @The main addon object for Triage
-- AceAddon registration name is frozen. External addons, including Triage_Dev,
-- hook _G.EnhancedRaidFrames; _G.Triage below is the canonical internal handle.
_G.EnhancedRaidFrames = LibStub("AceAddon-3.0"):NewAddon("EnhancedRaidFrames", "AceTimer-3.0", "AceHook-3.0",
		"AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0", "AceSerializer-3.0")

-- Backwards-compatibility alias and canonical internal handle as of TRI-036.
_G.Triage = _G.EnhancedRaidFrames

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Import libraries
-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Called directly after the addon is fully loaded.
--- We do initialization tasks here, such as loading our saved variables or setting up slash commands.
function Triage:OnInitialize()
	-- Set up our database
	self:InitializeDatabase()

	-- Run our database migration if necessary
	self:MigrateDatabase()

	-- Setup config panels in the Blizzard interface options
	self:InitializeConfigPanels()

	-- Register callbacks for profile switching
	local function onProfileUpdate()
		if self:IsTestModeActive() then
			self:StopTestMode(true)
		end
		self:MigrateDatabase()
		self:RefreshConfig()
		local LDBIcon = LibStub("LibDBIcon-1.0", true)
		if LDBIcon then
			LDBIcon:Refresh("Triage", self.db.profile.minimap)
		end
	end
	self.db.RegisterCallback(self, "OnProfileChanged", onProfileUpdate)
	self.db.RegisterCallback(self, "OnProfileCopied", onProfileUpdate)
	self.db.RegisterCallback(self, "OnProfileReset", onProfileUpdate)

	-- Initialize minimap button
	self:InitializeMinimapButton()
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Initialize the minimap button using LibDataBroker and LibDBIcon
function Triage:InitializeMinimapButton()
	local LDB = LibStub("LibDataBroker-1.1", true)
	local LDBIcon = LibStub("LibDBIcon-1.0", true)

	if not LDB or not LDBIcon then
		return
	end

	local dataObj = LDB:NewDataObject("Triage", {
		type = "launcher",
		text = "Triage",
		icon = "Interface\\Icons\\spell_holy_borrowedtime",
		OnClick = function(_, button)
			if button == "LeftButton" then
				self:OpenBlizzardOptions()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine("|cFFFFD700Triage|r")
			tooltip:AddLine("Enhanced Raid Frames Reforged", 1, 1, 1)
			tooltip:AddLine(" ")
			tooltip:AddLine("|cFFFFFFFFLeft-Click:|r Open settings")
		end,
	})

	LDBIcon:Register("Triage", dataObj, self.db.profile.minimap)
end

--- Called during the PLAYER_LOGIN event when most of the data provided by the game is already present.
--- We perform more startup tasks here, such as registering events, hooking functions, creating frames, or getting
--- information from the game that wasn't yet available during :OnInitialize()
function Triage:OnEnable()
	-- Register slash commands first so they're available even if startup hits an error
	-- /erf slash alias frozen; preserves command muscle memory for old ERF users.
	self:RegisterChatCommand("erf", "ChatCommand")
	self:RegisterChatCommand("triage", "ChatCommand")
	self:RegisterChatCommand("tri", "ChatCommand")

	-- Sync the managed frame registry before the first config refresh/update pass.
	self:RefreshManagedFrameRegistry()

	-- Populate our starting config values
	self:RefreshConfig()

	-- Run a full update of all auras for a starting point
	self:UpdateAllAuras()

	-- (THROTTLED) Force a full update of all group member's auras when the group roster changes
	self:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 1, function() -- 1 second throttle to avoid lagging the game
		self:RefreshManagedFrameRegistry()
		self:UpdateAllAuras()
		self:RefreshRangeTicker()
		self:UpdateTriageFocus()
	end)

	-- Force a full update of all stock aura visibilities, target markers, and ranges when the group roster changes
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		self:RefreshManagedFrameRegistry()
		self:UpdateAllStockAuraVisibility()
		self:UpdateAllTargetMarkers()
		self:RefreshRangeTicker()
		self:UpdateTriageFocus()
	end)

	self:RegisterEvent("UNIT_HEALTH", function(_, unit)
		self:UpdateTriageFocusForUnit(unit)
	end)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		self:RefreshRangeTicker()
		self:UpdateTriageFocus()
		if self.supportsRetailStockAuraAttributes then
			self:UpdateAllStockAuraVisibility()
		end
	end)

	-- Apply indicator mouse propagation settings that were skipped during combat lockdown.
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		self:FlushDeferredMouseBehavior()
		if self.Triage_pendingStockAuraVisibilityUpdate then
			self.Triage_pendingStockAuraVisibilityUpdate = nil
			self:UpdateAllStockAuraVisibility()
		end
	end)

	-- Force a full update of all frames when a raid target icon changes
	self:RegisterEvent("RAID_TARGET_UPDATE", function()
		self:UpdateAllTargetMarkers()
	end)

	-- Hook our UpdateInRange function if the global function exists.
	-- Using SecureHook ensures that our function will run 'after' the default function, which is what we want.
	if CompactUnitFrame_UpdateInRange then
		self:SecureHook("CompactUnitFrame_UpdateInRange", function(frame)
			self:UpdateInRange(frame)
		end)
	end

	-- Hook UpdateCenterStatusIcon to re-apply our range alpha after Blizzard sets its own.
	-- Blizzard's SetAlpha at CompactUnitFrame.lua:1583 uses frame.outOfRange which is
	-- broken by C_Secrets in Midnight. Our hook runs after and overrides with LibRangeCheck.
	-- We cannot write frame.outOfRange directly — that taints Blizzard's next comparison.
	if CompactUnitFrame_UpdateCenterStatusIcon then
		self:SecureHook("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
			self:UpdateInRange(frame)
		end)
	end

	-- Hook frame unit assignment to refresh indicators and listeners when a frame gets a new unit.
	-- Without this, indicators and aura listeners become stale until the next GROUP_ROSTER_UPDATE
	-- throttle interval (1 second) when frames are reassigned.
	if rawget(_G, "CompactUnitFrame_SetUnit") then
		self:SecureHook("CompactUnitFrame_SetUnit", function(frame, unit)
			self:UpdateManagedFrameUnit(frame, unit, "blizzard")
			if not self.ShouldContinue(frame, true) then
				return
			end
			-- Clear stale indicators and immediately scan the new unit's auras
			-- so there is no visible gap between reassignment and repopulation
			if frame.Triage_indicatorFrames then
				for i = 1, 9 do
					if frame.Triage_indicatorFrames[i] then
						self:ClearIndicator(frame.Triage_indicatorFrames[i])
					end
				end
			end
			if self.usesLegacyUnitAura then
				self:UpdateUnitAuras_Classic(frame, true)
			else
				self:UpdateUnitAuras(frame, {}, true)
			end
			-- Refresh target marker
			if frame.Triage_targetMarkerFrame then
				self:UpdateTargetMarker(frame)
			end
		end)
	end

	-- Hook aura updates to refresh dispel overlay (Retail DispelSource path;
	-- legacy clients keep the frame.dispels fallback when refreshed elsewhere).
	-- No explicit hide on SetUnit — the aura hook handles it. Blizzard's SetUnit calls UpdateAll
	-- which calls UpdateAuras before our SetUnit hook runs, so hiding here would blank valid overlays.
	if self.supportsUnitAuraPayloads then
		if CompactUnitFrame_UpdateAuras then
			self:SecureHook("CompactUnitFrame_UpdateAuras", function(frame)
				if not self.ShouldContinue(frame, true) then
					return
				end
				self:UpdateDispelOverlay(frame)
			end)
		end
	end

end

--- Open the Triage panel inside the Blizzard addon settings UI.
function Triage:OpenBlizzardOptions()
	if InCombatLockdown() then
		self:Print("Cannot open settings during combat.")
		return
	end

	if self.generalOptionsCategoryID and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(self.generalOptionsCategoryID)
		return
	end

	self:OpenConfigWindow()
end

--- Open the standalone Triage config window.
function Triage:OpenConfigWindow()
	AceConfigDialog:Open("Triage")

	local openFrames = AceConfigDialog.OpenFrames
	local frameWidget = openFrames and openFrames["Triage"]
	if not frameWidget or not frameWidget.frame then
		return
	end

	frameWidget.frame:SetClampedToScreen(true)
	if self.db and self.db.profile and self.db.profile.configWindowStatus then
		frameWidget:SetStatusTable(self.db.profile.configWindowStatus)
		frameWidget:ApplyStatus()
	end
end

--- Open the Triage settings panel or handle slash subcommands.
---@param input string|nil
function Triage:ChatCommand(input)
	input = input or ""
	if self:HandleTestModeChatCommand(input) then
		return
	end

	if InCombatLockdown() then
		self:Print("Cannot open settings during combat.")
		return
	end

	self:OpenConfigWindow()
end

--- Called when our addon is manually being disabled during a running session.
--- We primarily use this to unhook scripts, unregister events, or hide frames that we created.
function Triage:OnDisable()
	if self.rangeTicker then
		self:CancelTimer(self.rangeTicker)
		self.rangeTicker = nil
	end
	if self.triageFocusTicker then
		self:CancelTimer(self.triageFocusTicker)
		self.triageFocusTicker = nil
	end

	self:StopTestMode(true)
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Create a table containing our default database values
function Triage:InitializeDatabase()
	-- Set up database defaults
	local defaults = self:CreateDefaults()
	-- Create database object
	self.db = AceDB:New("EnhancedRaidFramesDB", defaults) -- SavedVariables key frozen; matches Triage.toc.
	-- Enhance database and profile options using LibDualSpec
	if self.supportsLibDualSpec then
		-- Not available on Classic Era or TBC Classic Anniversary
		-- Enhance the database object with per spec profile features
		-- LibDualSpec namespace frozen; changing it would orphan dual-spec profile bindings.
		LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.db, "EnhancedRaidFrames")
		-- Enhance the profile options table with per spec profile features
		LibStub("LibDualSpec-1.0"):EnhanceOptions(AceDBOptions:GetOptionsTable(self.db), self.db)
	end
end

--- Set up our configuration panels and add them to the Blizzard interface options
function Triage:InitializeConfigPanels()
	-- Build our config panels
	AceConfigRegistry:RegisterOptionsTable("Triage", self:CreateGeneralOptions())
	AceConfigRegistry:RegisterOptionsTable("Triage Indicator Options", self:CreateIndicatorOptions())
	AceConfigRegistry:RegisterOptionsTable("Triage Target Marker Options", self:CreateIconOptions())
	AceConfigRegistry:RegisterOptionsTable("Triage Profiles", AceDBOptions:GetOptionsTable(self.db))
	AceConfigRegistry:RegisterOptionsTable("Triage Import Export Profile Options", self:CreateProfileImportExportOptions())

	-- Add config panels to in-game interface options
	self.generalOptionsFrame, self.generalOptionsCategoryID = AceConfigDialog:AddToBlizOptions("Triage", "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Indicator Options", L["Indicator Options"], "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Target Marker Options", L["Target Marker Options"], "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Profiles", L["Profiles"], "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Import Export Profile Options",
			(L["Profile"] .. " " .. L["Import"] .. "/" .. L["Export"]), "Triage")
end

--- Refresh everything that is affected by changes to the configuration
function Triage:RefreshConfig()
	self:GenerateAuraStrings()
	self:UpdateAllAuras() -- Update all auras to reflect new settings
	self:RefreshRangeTicker()
	self:UpdateScale()
	self:ForEachManagedFrame(function(frame)
		self:UpdateIndicators(frame, true)
		self:UpdateBackgroundAlpha(frame)
		self:UpdateInRange(frame)
		self:UpdateTargetMarker(frame, true)
		self:UpdateStockAuraVisibility(frame)
		self:UpdateDispelOverlay(frame)
	end)
	self:UpdateTriageFocus()
end
