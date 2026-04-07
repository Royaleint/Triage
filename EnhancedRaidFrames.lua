-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

--- EnhancedRaidFrames is the main addon object for the Enhanced Raid Frames add-on.
---@class EnhancedRaidFrames : AceAddon-3.0 @The main addon object for the Enhanced Raid Frames add-on
_G.EnhancedRaidFrames = LibStub("AceAddon-3.0"):NewAddon("EnhancedRaidFrames", "AceTimer-3.0", "AceHook-3.0",
		"AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0", "AceSerializer-3.0")

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

-- Import libraries
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Called directly after the addon is fully loaded.
--- We do initialization tasks here, such as loading our saved variables or setting up slash commands.
function EnhancedRaidFrames:OnInitialize()
	-- Set up our database
	self:InitializeDatabase()

	-- Run our database migration if necessary
	self:MigrateDatabase()

	-- Setup config panels in the Blizzard interface options
	self:InitializeConfigPanels()

	-- Register callbacks for profile switching
	local function onProfileUpdate()
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
function EnhancedRaidFrames:InitializeMinimapButton()
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
				self:ChatCommand()
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
function EnhancedRaidFrames:OnEnable()
	-- Register slash commands first so they're available even if startup hits an error
	self:RegisterChatCommand("erf", "ChatCommand")
	self:RegisterChatCommand("triage", "ChatCommand")
	self:RegisterChatCommand("tri", "ChatCommand")

	-- Populate our starting config values
	self:RefreshConfig()

	-- Run a full update of all auras for a starting point
	self:UpdateAllAuras()

	-- (THROTTLED) Force a full update of all group member's auras when the group roster changes
	self:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 1, function() -- 1 second throttle to avoid lagging the game
		self:UpdateAllAuras()
	end)

	-- Force a full update of all stock aura visibilities, target markers, and ranges when the group roster changes
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		self:UpdateAllStockAuraVisibility()
		self:UpdateAllTargetMarkers()
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
	self:SecureHook("CompactUnitFrame_SetUnit", function(frame, unit)
		if not self.ShouldContinue(frame, true) then
			return
		end
		-- Clear stale indicators and immediately scan the new unit's auras
		-- so there is no visible gap between reassignment and repopulation
		if frame.ERF_indicatorFrames then
			for i = 1, 9 do
				if frame.ERF_indicatorFrames[i] then
					self:ClearIndicator(frame.ERF_indicatorFrames[i])
				end
			end
		end
		if self.isWoWClassicEra or self.isWoWClassic then
			self:UpdateUnitAuras_Classic(frame, true)
		else
			self:UpdateUnitAuras(frame, {}, true)
		end
		-- Refresh target marker
		if frame.ERF_targetMarkerFrame then
			self:UpdateTargetMarker(frame)
		end
	end)

	-- Hook aura updates to refresh dispel overlay (Retail only — frame.dispels doesn't exist on Classic)
	-- No explicit hide on SetUnit — the aura hook handles it. Blizzard's SetUnit calls UpdateAll
	-- which calls UpdateAuras before our SetUnit hook runs, so hiding here would blank valid overlays.
	if not self.isWoWClassicEra and not self.isWoWClassic then
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

--- Open the Triage settings panel
function EnhancedRaidFrames:ChatCommand()
	if InCombatLockdown() then
		self:Print("Cannot open settings during combat.")
		return
	end
	-- Use Ace3's internal ID map to get the correct category ID for this client
	local categoryID = AceConfigDialog.BlizOptionsIDMap and AceConfigDialog.BlizOptionsIDMap["Triage"]
	if categoryID then
		Settings.OpenToCategory(categoryID)
		-- Settings.OpenToCategory can show the Game Menu behind the settings panel
		if GameMenuFrame and GameMenuFrame:IsShown() then
			HideUIPanel(GameMenuFrame)
		end
	end
end

--- Called when our addon is manually being disabled during a running session.
--- We primarily use this to unhook scripts, unregister events, or hide frames that we created.
function EnhancedRaidFrames:OnDisable()
	if self.rangeTicker then
		self:CancelTimer(self.rangeTicker)
		self.rangeTicker = nil
	end
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Create a table containing our default database values
function EnhancedRaidFrames:InitializeDatabase()
	-- Set up database defaults
	local defaults = self:CreateDefaults()
	-- Create database object
	self.db = AceDB:New("EnhancedRaidFramesDB", defaults) --EnhancedRaidFramesDB is our saved variable table
	-- Enhance database and profile options using LibDualSpec
	if not self.isWoWClassicEra then
		-- Not available in Classic Era
		-- Enhance the database object with per spec profile features
		LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.db, "EnhancedRaidFrames")
		-- Enhance the profile options table with per spec profile features
		LibStub("LibDualSpec-1.0"):EnhanceOptions(AceDBOptions:GetOptionsTable(self.db), self.db)
	end
end

--- Set up our configuration panels and add them to the Blizzard interface options
function EnhancedRaidFrames:InitializeConfigPanels()
	-- Build our config panels
	AceConfigRegistry:RegisterOptionsTable("Triage", self:CreateGeneralOptions())
	AceConfigRegistry:RegisterOptionsTable("Triage Indicator Options", self:CreateIndicatorOptions())
	AceConfigRegistry:RegisterOptionsTable("Triage Target Marker Options", self:CreateIconOptions())
	AceConfigRegistry:RegisterOptionsTable("Triage Profiles", AceDBOptions:GetOptionsTable(self.db))
	AceConfigRegistry:RegisterOptionsTable("Triage Import Export Profile Options", self:CreateProfileImportExportOptions())

	-- Add config panels to in-game interface options
	AceConfigDialog:AddToBlizOptions("Triage", "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Indicator Options", L["Indicator Options"], "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Target Marker Options", L["Target Marker Options"], "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Profiles", L["Profiles"], "Triage")
	AceConfigDialog:AddToBlizOptions("Triage Import Export Profile Options",
			(L["Profile"] .. " " .. L["Import"] .. "/" .. L["Export"]), "Triage")
end

--- Refresh everything that is affected by changes to the configuration
function EnhancedRaidFrames:RefreshConfig()
	self:GenerateAuraStrings()
	self:UpdateAllAuras() -- Update all auras to reflect new settings
	self:RefreshRangeTicker()
	self:UpdateScale()
	self.ApplyToAllFrames(function(frame)
		self:UpdateIndicators(frame, true)
		self:UpdateBackgroundAlpha(frame)
		self:UpdateInRange(frame)
		self:UpdateTargetMarker(frame, true)
		self:UpdateStockAuraVisibility(frame)
		self:UpdateDispelOverlay(frame)
	end)
end
