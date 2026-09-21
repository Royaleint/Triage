-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- The folder name the TOC was loaded from; WoW passes it as this file's first
-- vararg. Used to tell the DevBuild variant apart from live for SavedVariables naming.
local ADDON_NAME = ...

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
				self:OpenConfigWindow()
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
		self:UpdateAllDispelOverlays()
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
		self:UpdateAllStockAuraVisibility()
	end)

	-- Apply indicator mouse propagation settings that were skipped during combat lockdown.
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if self.Triage_pendingStockAuraVisibilityUpdate then
			self.Triage_pendingStockAuraVisibilityUpdate = nil
			self:UpdateAllStockAuraVisibility()
		end
		self:FlushDeferredMouseBehavior()
		-- The restriction flag can only be cleared by a scan that actually reads the auras, so
		-- leaving combat forces one rather than assuming the encounter's secrecy has lifted.
		-- Instance-gated secrecy can persist through a regen, and the rescan re-sets the flag
		-- when it does. Bounded by the module flag: content that never hid an aura pays nothing.
		if self.Triage_anyAuraDataRestricted then
			self.Triage_anyAuraDataRestricted = nil
			self:UpdateAllAuras()
		end
		self:FlushSecureAuraIndicatorRefresh()
		self:FlushSecureAuraIndicatorRebuilds()
	end)

	-- Force a full update of all frames when a raid target icon changes
	self:RegisterEvent("RAID_TARGET_UPDATE", function()
		self:UpdateAllTargetMarkers()
	end)

	-- Hook our UpdateInRange function if the global function exists.
	-- Using SecureHook ensures that our function will run 'after' the default function, which is what we want.
	-- On Retail this body only marks the frame and returns; running SetAlpha inside
	-- either Blizzard call stack leaves the frame's next health compare tainted, the
	-- same class of problem the SetUnit hook already had to move off the stack for.
	-- The mark lands on the same coalesced flush as SetUnit, so a frame touched by
	-- more than one of these hooks in a tick still schedules only one timer.
	local function onRangeOrStatusIconUpdate(frame)
		if self.usesLegacyUnitAura then
			self:UpdateInRange(frame)
			return
		end
		if not self:IsOwnableFrame(frame) then
			return
		end
		if self.MarkFramePendingRange then
			self:MarkFramePendingRange(frame)
		else
			self:UpdateInRange(frame)
		end
	end

	if CompactUnitFrame_UpdateInRange then
		self:SecureHook("CompactUnitFrame_UpdateInRange", onRangeOrStatusIconUpdate)
	end

	-- UpdateCenterStatusIcon re-applies our range alpha after Blizzard sets its own.
	-- Blizzard's SetAlpha at CompactUnitFrame.lua:1583 uses frame.outOfRange which is
	-- broken by C_Secrets in Midnight. Our hook runs after and overrides with LibRangeCheck.
	-- We cannot write frame.outOfRange directly — that taints Blizzard's next comparison.
	if CompactUnitFrame_UpdateCenterStatusIcon then
		self:SecureHook("CompactUnitFrame_UpdateCenterStatusIcon", onRangeOrStatusIconUpdate)
	end

	-- Hook frame unit assignment to refresh indicators and listeners when a frame gets a new unit.
	-- Without this, indicators and aura listeners become stale until the next GROUP_ROSTER_UPDATE
	-- throttle interval (1 second) when frames are reassigned.
	if rawget(_G, "CompactUnitFrame_SetUnit") then
		-- Body of the hook, run against the frame's state at call time.
		local function refreshFrameForUnit(frame)
			if not self:IsOwnableFrame(frame) then
				return
			end
			local unit = frame.displayedUnit or frame.unit
			self:UpdateManagedFrameUnit(frame, unit, "blizzard")
			self:InvalidateSecureAuraIndicators(frame)
			self:UpdateStockAuraVisibility(frame)
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
		end

		if self.usesLegacyUnitAura then
			self:SecureHook("CompactUnitFrame_SetUnit", function(frame)
				refreshFrameForUnit(frame)
			end)
		else
			-- Retail: running this body inside Blizzard's secure SetUnit stack leaves the
			-- forced aura scan tainting later Blizzard health code (secret-value compares on
			-- Edit Mode entry), and UpdateStockAuraVisibility writes secure attributes. The
			-- whole body therefore runs one timer tick later, in Triage's own execution.
			-- Trade-off: indicators can be stale for up to one frame after a frame is
			-- reassigned. The unit is re-read at fire time because the hook's argument is
			-- nil on clear and hooks arrive in bursts.
			local pendingFrames = setmetatable({}, { __mode = "k" })
			local pendingRangeFrames = setmetatable({}, { __mode = "k" })
			local flushBatch = {}
			local rangeFlushBatch = {}
			local flushScheduled = false

			-- Re-evaluate the dispel overlay on frame reassignment; already deferred by
			-- TRI-068, so this runs outside Blizzard's SetUnit stack like the rest of the
			-- flush body. Folded into the same pcall as refreshFrameForUnit so a throw here
			-- costs only this frame, not the rest of the batch.
			local function refreshRetailFrame(frame)
				refreshFrameForUnit(frame)
				self:UpdateDispelOverlay(frame)
			end

			-- Drains one pending set into its scratch batch and runs body on each frame,
			-- each call wrapped so one frame's error can't strand the rest of the batch.
			local function runDeferredBatch(pendingSet, batch, body)
				wipe(batch)
				for frame in pairs(pendingSet) do
					batch[#batch + 1] = frame
				end
				wipe(pendingSet)
				for i = 1, #batch do
					local frame = batch[i]
					batch[i] = nil
					local ok, err = pcall(body, frame)
					if not ok then
						pcall(function()
							geterrorhandler()(err)
						end)
					end
				end
			end

			-- Frames hooked while a flush runs belong to the next window: each pending
			-- set is emptied before iterating so a re-hook schedules a fresh timer.
			local function flushPendingFrames()
				flushScheduled = false
				runDeferredBatch(pendingFrames, flushBatch, refreshRetailFrame)
				runDeferredBatch(pendingRangeFrames, rangeFlushBatch, function(frame)
					self:UpdateInRange(frame)
				end)
			end

			local function scheduleDeferredFlush()
				if not flushScheduled then
					flushScheduled = true
					C_Timer.After(0, flushPendingFrames)
				end
			end

			self:SecureHook("CompactUnitFrame_SetUnit", function(frame)
				if not self:IsOwnableFrame(frame) then
					return
				end
				pendingFrames[frame] = true
				scheduleDeferredFlush()
			end)

			-- An addon-level entry point rather than a local, so the range hook above
			-- (installed earlier in this same function, before this scope exists) still
			-- reaches this exact flush purely through a runtime field lookup on self.
			self.MarkFramePendingRange = function(_, frame)
				pendingRangeFrames[frame] = true
				scheduleDeferredFlush()
			end
		end
	end

	-- Dispel overlay detection state (TRI-069): the Retail probe (Modules/DispelSource.lua)
	-- consults dispelProviderIsSample instead of reading any Blizzard overlay/frame state.
	-- Both callback bodies below do mark-and-defer only, coalesced onto one timer, so no work
	-- runs inside Blizzard's AURA_DATA_PROVIDER_SWITCH event or EditMode.Exit callback stack.
	if self.supportsDispelOverlay then
		self.dispelProviderIsSample = false
		local dispelOverlayRefreshScheduled = false
		local function scheduleDispelOverlayRefresh()
			if dispelOverlayRefreshScheduled then
				return
			end
			dispelOverlayRefreshScheduled = true
			C_Timer.After(0, function()
				dispelOverlayRefreshScheduled = false
				self:UpdateAllDispelOverlays()
			end)
		end

		-- Edit Mode's sample aura data provider fabricates dispellable debuffs; while it is
		-- active the overlay must go dark rather than trust it. AURA_DATA_PROVIDER_SWITCH is a
		-- real WoW engine event (UnitAuraDocumentation.lua), so it is registered through
		-- Triage's own AceEvent-3.0 handle rather than EventRegistry: the handler then runs in
		-- Triage's own execution instead of alongside Blizzard's own listener on that event.
		-- Already Retail-gated by the enclosing "if self.supportsDispelOverlay" check, so this
		-- never registers on a client where the event might not exist. Payload per the engine's
		-- event definition: (event, useRealDataProvider).
		self:RegisterEvent("AURA_DATA_PROVIDER_SWITCH", function(_, useRealDataProvider)
			self.dispelProviderIsSample = useRealDataProvider == false
			scheduleDispelOverlayRefresh()
		end)

		-- EditMode.Exit is an EventRegistry-only callback name, not a WoW engine event, so it
		-- has no AceEvent equivalent and stays on EventRegistry. Belt-and-suspenders: Edit Mode
		-- always exits back onto the real provider, but this also covers the case where
		-- AURA_DATA_PROVIDER_SWITCH never fires because nothing inside Edit Mode requested a
		-- sample aura.
		EventRegistry:RegisterCallback("EditMode.Exit", function()
			self.dispelProviderIsSample = false
			scheduleDispelOverlayRefresh()
		end, self)
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

--- Return whether the current client has the native UI primitives required
--- for Triage's standalone Blizzard-style options frame.
function Triage:SupportsNativeOptionsFrame()
	local scrollUtil = rawget(_G, "ScrollUtil")
	return type(rawget(_G, "CreateScrollBoxListLinearView")) == "function"
			and type(rawget(_G, "CreateDataProvider")) == "function"
			and type(scrollUtil) == "table"
			and type(scrollUtil.InitScrollBoxListWithScrollBar) == "function"
end

--- Open the standalone Triage config window.
function Triage:OpenConfigWindow()
	if InCombatLockdown() then
		self:Print("Cannot open settings during combat.")
		return
	end

	if self:SupportsNativeOptionsFrame()
			and self.OptionsFrame
			and self.OptionsFrame.Open then
		self.OptionsFrame:Open()
		return
	end

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

	if input == "native" then
		if self.OptionsFrame and self.OptionsFrame.Open then
			self.OptionsFrame:Open()
		end
		return
	elseif input == "aceconfig" then
		AceConfigDialog:Open("Triage")
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
	-- SavedVariables key: derived from ADDON_NAME, not a literal, so the DevBuild
	-- variant (Triage_DevBuild.toc declares EnhancedRaidFramesDB_DevBuild) reads
	-- and writes its own SavedVariables instead of the live player's.
	local DEVBUILD_SV_NAME = "EnhancedRaidFramesDB_DevBuild"
	local svName = (ADDON_NAME == "Triage_DevBuild") and DEVBUILD_SV_NAME
		or (DEVBUILD_SV_NAME:gsub("_DevBuild$", ""))
	self.db = AceDB:New(svName, defaults)
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

	if self.OptionsFrame and self.OptionsFrame.Initialize then
		self.OptionsFrame:Initialize()
	end
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
