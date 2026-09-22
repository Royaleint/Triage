-- luacheck: globals arg dofile LibStub geterrorhandler C_Timer wipe issecretvalue AuraUtil
-- luacheck: globals IsInRaid UnitExists UnitIsConnected UnitIsDeadOrGhost CreateFrame UIParent EventRegistry
-- Run from the repository root with a relative path: lua5.1 tests/tri069_dispel_detection.lua

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertTrue(value, message)
	if not value then
		error(message or "assertion failed", 2)
	end
end

-- Timer stub: queues callbacks so each row controls when the coalesced refresh fires.
local timerQueue = {}
local timersScheduled = 0
C_Timer = {
	After = function(_, callback)
		timersScheduled = timersScheduled + 1
		timerQueue[#timerQueue + 1] = callback
	end,
}

local function fireTimers()
	local queue = timerQueue
	timerQueue = {}
	for _, callback in ipairs(queue) do
		callback()
	end
end

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

local reportedErrors = {}
function geterrorhandler()
	return function(err)
		reportedErrors[#reportedErrors + 1] = err
	end
end

-- LibDispel / LibCustomGlow are fetched at module scope by DispelOverlay.lua and
-- AuraListeners.lua, so the stubs must exist before those files are dofile'd.
local libDispelStub = {
	myDispels = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true },
	GetMyDispelTypes = function(self) return self.myDispels end,
	GetDebuffTypeColor = function()
		return {
			Magic = { r = 0.2, g = 0.4, b = 1.0 },
			Curse = { r = 0.6, g = 0.0, b = 1.0 },
			Disease = { r = 0.6, g = 0.4, b = 0.0 },
			Poison = { r = 0.0, g = 0.6, b = 0.0 },
			Bleed = { r = 1.0, g = 0.2, b = 0.6 },
			None = { r = 1.0, g = 0.0, b = 0.0 },
		}
	end,
}

local libCustomGlowStub = { startCalls = {}, stopCalls = {} }
function libCustomGlowStub.ButtonGlow_Start(target, color)
	libCustomGlowStub.startCalls[#libCustomGlowStub.startCalls + 1] = { target = target, color = color }
end
function libCustomGlowStub.ButtonGlow_Stop(target)
	libCustomGlowStub.stopCalls[#libCustomGlowStub.stopCalls + 1] = target
end

local addon = {}
LibStub = setmetatable({}, {
	__call = function(_, name)
		if name == "AceLocale-3.0" then
			return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
		elseif name == "LibDispel-1.0" then
			return libDispelStub
		elseif name == "LibCustomGlow-1.0" then
			return libCustomGlowStub
		elseif name == "AceAddon-3.0" then
			return { NewAddon = function() return addon end }
		end
		return {}
	end,
})

-- issecretvalue: a per-test set of "secret" markers, mirroring Retail's C_Secrets gate.
-- Weak-keyed so marker tables used as stand-ins for secret field values don't leak.
local secretValues = setmetatable({}, { __mode = "k" })
function issecretvalue(value)
	return secretValues[value] == true
end

-- AuraUtil.ForEachAura: each row installs foreachAuraImpl to control what the probe sees
-- (nothing, a throw, or one or more fake auraData tables delivered through the callback).
local foreachAuraCalls = {}
local foreachAuraImpl
AuraUtil = {
	ForEachAura = function(unit, filter, _maxCount, callback, _usePackedAura)
		foreachAuraCalls[#foreachAuraCalls + 1] = { unit = unit, filter = filter }
		if foreachAuraImpl then
			foreachAuraImpl(callback)
		end
	end,
}

function IsInRaid() return false end
function UnitExists(unit) return unit ~= nil end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end

UIParent = {}

-- Minimal WoW frame stub: covers everything Modules/DispelOverlay.lua touches building and
-- driving the overlay (edges, glow host, OnHide/OnUpdate scripts) and everything the raid-frame
-- mocks below need (GetFrameLevel/GetFrameStrata, queried by GetGlowTarget).
local function NewStubFrame()
	local scripts = {}
	local frame = {
		SetAllPoints = function() end,
		SetParent = function() end,
		SetFrameLevel = function(self, level) self._frameLevel = level end,
		GetFrameLevel = function(self) return self._frameLevel or 0 end,
		SetFrameStrata = function(self, strata) self._strata = strata end,
		GetFrameStrata = function(self) return self._strata or "MEDIUM" end,
		CreateTexture = function()
			return {
				SetColorTexture = function() end,
				SetPoint = function() end,
				SetHeight = function() end,
				SetWidth = function() end,
				Show = function() end,
				Hide = function() end,
			}
		end,
		Hide = function(self) self._shown = false end,
		Show = function(self) self._shown = true end,
		IsShown = function(self) return self._shown end,
		SetScript = function(self, name, fn) scripts[name] = fn end,
		GetScript = function(_, name) return scripts[name] end,
		ClearAllPoints = function() end,
		SetPoint = function() end,
		EnableMouse = function() end,
		GetSize = function() return 72, 36 end,
		UnregisterAllEvents = function() end,
		RegisterUnitEvent = function() end,
		RegisterEvent = function() end,
	}
	return frame
end

function CreateFrame()
	return NewStubFrame()
end

local function NewRaidFrame(unit)
	local frame = NewStubFrame()
	frame.unit = unit
	frame.displayedUnit = unit
	return frame
end

local function overlayIsShown(frame)
	local overlay = frame.Triage_dispelOverlay
	return overlay ~= nil and overlay:IsShown() == true
end

-- EventRegistry: captures the callbacks Triage:OnEnable registers so rows can fire them
-- directly, the way Blizzard's real EventRegistry would. Both EditMode.Enter and
-- EditMode.Exit go through this stub; Triage no longer registers anything through its own
-- AceEvent RegisterEvent for aura provider state.
local eventRegistryCallbacks = {}
EventRegistry = {
	RegisterCallback = function(_, name, callback, owner)
		eventRegistryCallbacks[name] = { callback = callback, owner = owner }
	end,
}

-- RegisterEvent: captures any handler Triage:OnEnable registers through its own AceEvent-3.0
-- handle, so rows can fire it directly the way the WoW engine would dispatch a real event.
local registeredEvents = {}

dofile(repoRoot .. "Triage.lua")

-- Frame-registry and gating stubs the modules under test call into; not under test here.
addon.GetManagedFrameUnit = function(_, frame) return frame and (frame.displayedUnit or frame.unit) end
addon.GetManagedChildFrameName = function() return nil end
addon.ShouldContinue = function() return true end
addon.RegisterChatCommand = function() end
addon.RefreshManagedFrameRegistry = function() end
addon.RefreshConfig = function() end
addon.UpdateAllAuras = function() end
addon.RegisterBucketEvent = function() end
addon.RegisterEvent = function(_, event, callback) registeredEvents[event] = callback end
addon.SecureHook = function() end
addon.ForEachManagedFrame = function() end

addon.db = {
	profile = {
		dispelOverlay = {
			enabled = true,
			colorByType = false,
			glowStyle = "both",
			borderAlpha = 1,
			showInParty = true,
			showInRaid = true,
		},
	},
}

dofile(repoRoot .. "Modules/DispelSource.lua")
dofile(repoRoot .. "Modules/DispelOverlay.lua")
dofile(repoRoot .. "Modules/AuraListeners.lua")

local function resetState()
	timerQueue = {}
	timersScheduled = 0
	foreachAuraCalls = {}
	foreachAuraImpl = nil
	reportedErrors = {}
	libCustomGlowStub.startCalls = {}
	libCustomGlowStub.stopCalls = {}
end

local function installOnEnable(isRetail)
	resetState()
	eventRegistryCallbacks = {}
	registeredEvents = {}
	addon.isRetail = isRetail
	addon.supportsDispelOverlay = isRetail
	addon.supportsUnitAuraPayloads = isRetail
	addon.usesLegacyUnitAura = not isRetail
	addon.supportsPrivateAuraSuppression = isRetail
	addon.dispelProviderIsSample = nil
	addon:OnEnable()
end

-- Row 1: a stale Blizzard overlay texture (Blizzard never clears frame.DispelOverlay
-- .dispelDebuffFrames[i].aura, per Modules/DispelSource.lua) must not resurrect a
-- dispel type; only the query result matters, and it found nothing.
installOnEnable(true)
do
	local frame = NewRaidFrame("party1")
	frame.DispelOverlay = {
		dispelDebuffFrames = {
			{ aura = { dispelName = "Magic", canActivePlayerDispel = true }, IsShown = function() return true end },
		},
	}
	assertEqual(addon:GetActiveDispelType(frame), nil,
		"a stale Blizzard overlay texture with no matching aura in the query must not report a dispel type")
	assertEqual(#foreachAuraCalls, 1, "the probe queries the unit's auras")
	addon:UpdateDispelOverlay(frame)
	assertTrue(not overlayIsShown(frame), "a stale Blizzard texture with nothing in the query hides the overlay")
end

-- Row 2: a denied aura query (pcall throw) hides the overlay and never escapes as a Lua error.
installOnEnable(true)
do
	foreachAuraImpl = function() error("Auras cannot be accessed when secret while tainted") end
	local frame = NewRaidFrame("party1")
	local ok, result = pcall(function() return addon:GetActiveDispelType(frame) end)
	assertTrue(ok, "a denied aura query must not escape as a Lua error")
	assertEqual(result, addon.DISPEL_STATE_UNAVAILABLE, "a denied aura query reports unavailable")
	addon:UpdateDispelOverlay(frame)
	assertTrue(not overlayIsShown(frame), "a denied aura query hides the overlay")
end

-- Row 3: a positively present debuff whose type is unreadable (secret dispelName) shows the
-- overlay neutral, and ShowDispelOverlay is never called with "None".
installOnEnable(true)
do
	local secretDispelName = {}
	secretValues[secretDispelName] = true
	foreachAuraImpl = function(callback) callback({ dispelName = secretDispelName }) end
	local frame = NewRaidFrame("party1")
	assertEqual(addon:GetActiveDispelType(frame), addon.UNKNOWN_DISPEL_TYPE,
		"a present but type-unreadable debuff reports the unknown-active sentinel")

	local shownCalls = {}
	local originalShow = addon.ShowDispelOverlay
	addon.ShowDispelOverlay = function(self, f, dispelType)
		shownCalls[#shownCalls + 1] = dispelType
		return originalShow(self, f, dispelType)
	end
	addon:UpdateDispelOverlay(frame)
	addon.ShowDispelOverlay = originalShow

	assertEqual(#shownCalls, 1, "the overlay is shown exactly once")
	assertEqual(shownCalls[1], addon.UNKNOWN_DISPEL_TYPE,
		"ShowDispelOverlay is called with the sentinel, never with \"None\"")
	assertTrue(overlayIsShown(frame), "a present but unreadable debuff shows the overlay")
	assertEqual(frame.Triage_dispelOverlay.currentDispelType, addon.UNKNOWN_DISPEL_TYPE,
		"the overlay records the sentinel, not \"None\"")
end

-- Row 4: row 3 with colorByType on, then one OnUpdate glow tick: the glow colour stays neutral,
-- at both the ShowDispelOverlay site and the OnUpdate colour pick.
installOnEnable(true)
do
	addon.db.profile.dispelOverlay.colorByType = true
	local secretDispelName = {}
	secretValues[secretDispelName] = true
	foreachAuraImpl = function(callback) callback({ dispelName = secretDispelName }) end
	local frame = NewRaidFrame("party1")
	addon:UpdateDispelOverlay(frame)
	assertEqual(frame.Triage_dispelOverlay.currentDispelType, addon.UNKNOWN_DISPEL_TYPE,
		"the sentinel reaches the overlay even with colorByType on")

	local onUpdate = frame.Triage_dispelOverlay:GetScript("OnUpdate")
	assertTrue(onUpdate, "the overlay installs an OnUpdate glow tick")
	-- EnsureGlow skips a redundant redraw when nothing about the glow state changed since
	-- ShowDispelOverlay's own call; invalidate the cache so the tick's own colour pick runs,
	-- the way it would on the next tick after a frame resize.
	frame.Triage_dispelOverlay.glowVisible = nil
	libCustomGlowStub.startCalls = {}
	onUpdate(frame.Triage_dispelOverlay, 0.2)

	assertTrue(#libCustomGlowStub.startCalls > 0, "the glow tick runs")
	local lastCall = libCustomGlowStub.startCalls[#libCustomGlowStub.startCalls]
	assertEqual(lastCall.color, nil,
		"the OnUpdate glow colour stays neutral for the unreadable sentinel even with colorByType on")

	addon.db.profile.dispelOverlay.colorByType = false
end

-- Row 5: UNIT_AURA fires the Retail aura listener; the overlay re-evaluates without
-- RefreshConfig ever running.
installOnEnable(true)
do
	addon.UpdateUnitAuras = function() end
	local frame = NewRaidFrame("party1")
	addon:CreateAuraListener(frame)
	local onEvent = frame.Triage_auraListenerFrame:GetScript("OnEvent")
	assertTrue(onEvent, "the Retail aura listener installs an OnEvent handler")

	foreachAuraImpl = function(callback) callback({ dispelName = "Magic" }) end
	assertTrue(not overlayIsShown(frame), "nothing shown before the aura event fires")
	onEvent(frame.Triage_auraListenerFrame, "UNIT_AURA", "party1", {})
	assertTrue(overlayIsShown(frame), "the dispel overlay re-evaluates on UNIT_AURA without RefreshConfig")
	assertEqual(frame.Triage_dispelOverlay.currentDispelType, "Magic",
		"the aura listener refresh reaches the real dispel type")
end

-- Row 6: while Edit Mode's sample aura provider is active the overlay hides even with a
-- matching aura present; exiting Edit Mode and firing the coalesced timer re-evaluates it.
installOnEnable(true)
do
	local frame = NewRaidFrame("party1")
	foreachAuraImpl = function(callback) callback({ dispelName = "Magic" }) end
	addon.ForEachManagedFrame = function(_, func) func(frame) end

	local enterEntry = eventRegistryCallbacks["EditMode.Enter"]
	assertTrue(enterEntry, "OnEnable registers the EditMode.Enter callback")
	local exitEntry = eventRegistryCallbacks["EditMode.Exit"]
	assertTrue(exitEntry, "OnEnable registers the EditMode.Exit callback")

	enterEntry.callback()
	assertEqual(addon.dispelProviderIsSample, true, "entering Edit Mode marks the sample state")
	assertEqual(addon:GetActiveDispelType(frame), addon.DISPEL_STATE_UNAVAILABLE,
		"the probe reports unavailable while the sample provider is active, even with a matching aura present")

	addon:UpdateDispelOverlay(frame)
	assertTrue(not overlayIsShown(frame), "the overlay hides while the sample provider is active")

	exitEntry.callback()
	assertEqual(addon.dispelProviderIsSample, false, "exiting Edit Mode clears the sample state")
	fireTimers()
	assertTrue(overlayIsShown(frame),
		"clearing the sample provider and firing the deferred timer re-evaluates the overlay")

	addon.ForEachManagedFrame = function() end
end

-- Row 7: the EditMode.Exit callback body performs zero work before its timer fires -- only the
-- coalesced C_Timer.After(0) runs the actual refresh.
installOnEnable(true)
do
	local exitEntry = eventRegistryCallbacks["EditMode.Exit"]
	assertTrue(exitEntry, "OnEnable registers the EditMode.Exit callback")

	local updateAllCalls = 0
	local originalUpdateAll = addon.UpdateAllDispelOverlays
	addon.UpdateAllDispelOverlays = function(...)
		updateAllCalls = updateAllCalls + 1
		return originalUpdateAll(...)
	end

	exitEntry.callback()
	assertEqual(updateAllCalls, 0, "the EditMode.Exit callback body performs zero work before the timer fires")
	assertEqual(timersScheduled, 1, "the EditMode.Exit callback schedules exactly one coalesced timer")

	fireTimers()
	assertEqual(updateAllCalls, 1, "the deferred timer runs the overlay refresh")

	addon.UpdateAllDispelOverlays = originalUpdateAll
end

-- Row 7b: the EditMode.Enter callback body performs zero refresh work before its timer fires
-- either -- setting the sample-state marker is cheap mark-and-defer, not refresh work; only
-- the coalesced C_Timer.After(0) actually re-evaluates any overlay.
installOnEnable(true)
do
	local enterEntry = eventRegistryCallbacks["EditMode.Enter"]
	assertTrue(enterEntry, "OnEnable registers the EditMode.Enter callback")

	local updateAllCalls = 0
	local originalUpdateAll = addon.UpdateAllDispelOverlays
	addon.UpdateAllDispelOverlays = function(...)
		updateAllCalls = updateAllCalls + 1
		return originalUpdateAll(...)
	end

	enterEntry.callback()
	assertEqual(addon.dispelProviderIsSample, true, "the callback body still marks the sample state synchronously")
	assertEqual(updateAllCalls, 0,
		"the EditMode.Enter callback body performs zero refresh work before the timer fires")
	assertEqual(timersScheduled, 1, "the callback schedules exactly one coalesced timer")

	fireTimers()
	assertEqual(updateAllCalls, 1, "the deferred timer runs the overlay refresh")

	addon.UpdateAllDispelOverlays = originalUpdateAll
end

-- Row 7c: a repeated EditMode.Enter before the timer fires (Edit Mode re-entered, or Blizzard
-- calling it more than once) coalesces onto the same single timer as the eventual Exit.
installOnEnable(true)
do
	local enterEntry = eventRegistryCallbacks["EditMode.Enter"]
	local exitEntry = eventRegistryCallbacks["EditMode.Exit"]
	assertTrue(enterEntry, "OnEnable registers the EditMode.Enter callback")
	assertTrue(exitEntry, "OnEnable registers the EditMode.Exit callback")

	local updateAllCalls = 0
	local originalUpdateAll = addon.UpdateAllDispelOverlays
	addon.UpdateAllDispelOverlays = function(...)
		updateAllCalls = updateAllCalls + 1
		return originalUpdateAll(...)
	end

	enterEntry.callback()
	enterEntry.callback()
	exitEntry.callback()
	assertEqual(timersScheduled, 1, "repeated Enter followed by Exit still schedules exactly one coalesced timer")
	assertEqual(addon.dispelProviderIsSample, false, "Exit clears the sample state regardless of how many Enters preceded it")

	fireTimers()
	assertEqual(updateAllCalls, 1, "the single coalesced timer runs the overlay refresh exactly once")

	addon.UpdateAllDispelOverlays = originalUpdateAll
end

-- New row: the invariant this fix exists for -- Retail OnEnable must never register an
-- AURA_DATA_PROVIDER_SWITCH handler, since that event dispatches synchronously inside
-- Blizzard's own Edit Mode entry stack.
installOnEnable(true)
do
	assertEqual(registeredEvents["AURA_DATA_PROVIDER_SWITCH"], nil,
		"Retail OnEnable registers no AURA_DATA_PROVIDER_SWITCH handler")
end

-- Row 8: Classic clients reach the legacy frame.dispels path, register no new EventRegistry
-- listener, and never draw the overlay -- byte-identical behaviour to before this change.
installOnEnable(false)
do
	assertEqual(registeredEvents["AURA_DATA_PROVIDER_SWITCH"], nil,
		"Classic OnEnable registers no AURA_DATA_PROVIDER_SWITCH handler")
	assertEqual(eventRegistryCallbacks["EditMode.Enter"], nil,
		"Classic OnEnable registers no EditMode.Enter callback")
	assertEqual(eventRegistryCallbacks["EditMode.Exit"], nil,
		"Classic OnEnable registers no EditMode.Exit callback")

	local legacyFrame = {
		dispels = {
			Magic = { Size = function() return 1 end },
		},
	}
	assertEqual(addon:GetActiveDispelType(legacyFrame), "Magic", "Classic reaches the legacy frame.dispels path")
	assertEqual(#foreachAuraCalls, 0, "Classic never calls the Retail aura probe")

	local frame = NewRaidFrame("party1")
	frame.dispels = legacyFrame.dispels
	addon:UpdateDispelOverlay(frame)
	assertTrue(not overlayIsShown(frame), "Classic never draws the dispel overlay")

	addon.UpdateUnitAuras_Classic = function() end
	addon:CreateAuraListener(frame)
	local onEvent = frame.Triage_auraListenerFrame:GetScript("OnEvent")
	assertTrue(onEvent, "the Classic aura listener installs an OnEvent handler")

	local updateDispelCalls = 0
	local originalUpdateDispel = addon.UpdateDispelOverlay
	addon.UpdateDispelOverlay = function(...)
		updateDispelCalls = updateDispelCalls + 1
		return originalUpdateDispel(...)
	end
	onEvent(frame.Triage_auraListenerFrame)
	addon.UpdateDispelOverlay = originalUpdateDispel
	assertEqual(updateDispelCalls, 0, "the Classic listener closure adds no dispel overlay call")
end

-- Row 9: the probe uses the engine's player-dispellable filter, "HARMFUL|RAID", not the wider
-- "HARMFUL|RAID_PLAYER_DISPELLABLE" or the bare "HARMFUL".
installOnEnable(true)
do
	local frame = NewRaidFrame("party1")
	foreachAuraImpl = function(callback) callback({ dispelName = "Magic" }) end
	addon:GetActiveDispelType(frame)
	assertEqual(#foreachAuraCalls, 1, "the probe queries the aura filter exactly once per call")
	assertEqual(foreachAuraCalls[1].filter, "HARMFUL|RAID", "the probe uses the engine's player-dispellable filter")
	assertEqual(foreachAuraCalls[1].unit, "party1", "the probe queries the frame's managed unit")
end

-- Row 10: a positively present debuff whose dispelName is readable but not one of the five
-- priority types still reports the unknown-active sentinel -- neutral, never nil.
installOnEnable(true)
do
	foreachAuraImpl = function(callback) callback({ dispelName = "Enrage" }) end
	local frame = NewRaidFrame("party1")
	assertEqual(addon:GetActiveDispelType(frame), addon.UNKNOWN_DISPEL_TYPE,
		"a readable dispelName outside the priority order reports the unknown-active sentinel, not nil")
end

print("tri069_dispel_detection: PASS")
