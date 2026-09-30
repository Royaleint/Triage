-- luacheck: globals arg dofile os io loadstring wipe CreateFrame GetRealmName UnitName UnitClass UnitRace UnitFactionGroup GetLocale GetCurrentRegion GetCurrentRegionName CopyTable securecallfunction GetBuildInfo IsLoggedIn ClassicExpansionAtLeast ClassicExpansionAtMost LE_EXPANSION_MISTS_OF_PANDARIA LE_EXPANSION_SHADOWLANDS LE_EXPANSION_CATACLYSM C_SpecializationInfo GetSpecialization GetSpecializationInfo GetSpecializationInfoForClassID GetNumSpecializations StaticPopupDialogs StaticPopup_Show StaticPopup_Hide
-- TRI-095: a profile that is new (a new character's first profile, or one
-- made with New) or reset starts with Blizzard's buff icons hidden, while
-- every profile that already exists keeps showing them. AceDB copies scalar
-- defaults into a profile the first time it is used, so the difference can
-- only be made when a profile is created or reset, never read back later.

local repoRoot = arg[1] or "./"
if repoRoot:sub(-1) ~= "/" and repoRoot:sub(-1) ~= "\\" then
	repoRoot = repoRoot .. "/"
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function deepcopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepcopy(v)
	end
	return out
end

local function wipeTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

-- What the test stand-ins record: the first indicator's aura list at each
-- RefreshConfig call, NotifyChange calls per options table, and the event
-- handlers OnEnable registers.
local snaps = {}
local notifyLog = {}
local handlers = {}

-- enUS.lua ships with a UTF-8 BOM; dofile() chokes on it, so strip it.
local function dofileSkipBOM(path)
	local f = io.open(path, "rb")
	local content = f:read("*a")
	f:close()
	if content:sub(1, 3) == "\239\187\191" then
		content = content:sub(4)
	end
	local chunk = assert(loadstring(content, path))
	return chunk()
end

-------------------------------------------------------------------------
-- 1. LibStub, the real file.
-------------------------------------------------------------------------
dofile(repoRoot .. "Libs/LibStub/LibStub.lua")

-------------------------------------------------------------------------
-- 2. securecallfunction, captured by CallbackHandler at its own load time.
-------------------------------------------------------------------------
securecallfunction = function(f, ...)
	return f(...)
end

-------------------------------------------------------------------------
-- 3. CallbackHandler, the real file.
-------------------------------------------------------------------------
dofile(repoRoot .. "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")

-------------------------------------------------------------------------
-- 4. WoW stubs AceDB-3.0 needs at its own load time: its char/realm/class
-- keys are plain locals computed once, when the file is read.
-------------------------------------------------------------------------
CreateFrame = function()
	local frame = { events = {}, scripts = {} }
	function frame:RegisterEvent(e)
		self.events[e] = true
	end
	function frame:UnregisterEvent(e)
		self.events[e] = nil
	end
	function frame:RegisterUnitEvent(e)
		self.events[e] = true
	end
	function frame:UnregisterAllEvents()
		self.events = {}
	end
	function frame:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function frame:GetScript(script)
		return self.scripts[script]
	end
	return frame
end

local CHAR_NAME = "TestChar"
local REALM_NAME = "TestRealm"
local CHAR_KEY = CHAR_NAME .. " - " .. REALM_NAME

GetRealmName = function() return REALM_NAME end
UnitName = function() return CHAR_NAME end
UnitClass = function() return "Warrior", "WARRIOR", 1 end
UnitRace = function() return "Human", "Human" end
UnitFactionGroup = function() return "Alliance" end
GetLocale = function() return "enUS" end
GetCurrentRegion = function() return 1 end
GetCurrentRegionName = function() return "US" end

-- WoW's in-place table clear; LibDualSpec's event handler uses it.
wipe = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

-- Matches Blizzard_SharedXMLBase/TableUtil.lua:245-255: deep-copies unless
-- told to stay shallow.
CopyTable = function(settings, shallow)
	local copy = {}
	for k, v in pairs(settings) do
		if type(v) == "table" and not shallow then
			copy[k] = CopyTable(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-------------------------------------------------------------------------
-- 5. AceDB, then AceDBOptions, the real files.
-------------------------------------------------------------------------
dofile(repoRoot .. "Libs/AceDB-3.0/AceDB-3.0.lua")
dofile(repoRoot .. "Libs/AceDBOptions-3.0/AceDBOptions-3.0.lua")

local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

-------------------------------------------------------------------------
-- 6. LibStub:NewLibrary stubs.
-------------------------------------------------------------------------
local registeredOptions = {}
local AceConfigRegistry = LibStub:NewLibrary("AceConfigRegistry-3.0", 1)
function AceConfigRegistry:RegisterOptionsTable(appName, tbl)
	registeredOptions[appName] = tbl
end
function AceConfigRegistry:IterateOptionsTables()
	return pairs(registeredOptions)
end
function AceConfigRegistry:NotifyChange(appName)
	notifyLog[appName] = (notifyLog[appName] or 0) + 1
end

LibStub:NewLibrary("AceConfigDialog-3.0", 1)

local AceAddonLib = LibStub:NewLibrary("AceAddon-3.0", 1)
function AceAddonLib:NewAddon()
	return {}
end

-- Minimal AceLocale: enUS is the base locale, so `L[k] = true` means "the
-- key is its own display text" and `L[k] = "literal"` stores that literal.
local locales = {}
local AceLocaleLib = LibStub:NewLibrary("AceLocale-3.0", 1)
function AceLocaleLib:NewLocale(appName)
	local L = locales[appName]
	if not L then
		L = setmetatable({}, {
			__newindex = function(t, k, v)
				rawset(t, k, v == true and k or v)
			end,
			__index = function(_, k)
				return k
			end,
		})
		locales[appName] = L
	end
	return L
end
function AceLocaleLib:GetLocale(appName)
	return locales[appName]
end

local LibDeflate = LibStub:NewLibrary("LibDeflate", 1)
function LibDeflate:DecodeForPrint(s) return s end
function LibDeflate:DecompressZlib(s) return s end
function LibDeflate:CompressZlib(s) return s end
function LibDeflate:EncodeForPrint(s) return s end

local LibDBIcon = LibStub:NewLibrary("LibDBIcon-1.0", 1)
function LibDBIcon:Refresh() end

-------------------------------------------------------------------------
-- 7. LibDualSpec load-time stubs.
-------------------------------------------------------------------------
local currentSpec = 0
local specInit = true
local specReads = 0
-- Spec index 5 is past GetNumSpecializations(), a starting spec. It maps to a
-- covered ID on purpose, so skipping the starting-spec check would fill.
local SPEC_IDS = { 105, 264, 250, 65, 105 }

local function stubGetSpecialization()
	specReads = specReads + 1
	return currentSpec
end
local function stubIsInitialized()
	specReads = specReads + 1
	return specInit
end
local function stubGetSpecializationInfo(i)
	return SPEC_IDS[i] or 0
end

C_SpecializationInfo = {
	GetNumSpecializationsForClassID = function() return 4 end,
	GetSpecialization = stubGetSpecialization,
	IsInitialized = stubIsInitialized,
	GetSpecializationInfo = stubGetSpecializationInfo,
	CanPlayerUseTalentUI = function() return true end,
}
GetSpecializationInfoForClassID = function(_, i) return i, "Spec" .. i end
GetNumSpecializations = function() return 4 end
GetBuildInfo = function() return "1.0.0", "1", "enUS", 120100 end
IsLoggedIn = function() return false end
LE_EXPANSION_MISTS_OF_PANDARIA = 5
LE_EXPANSION_SHADOWLANDS = 8
LE_EXPANSION_CATACLYSM = 4
ClassicExpansionAtLeast = function() return true end
ClassicExpansionAtMost = function() return false end

-------------------------------------------------------------------------
-- 8. LibDualSpec, the real file.
-------------------------------------------------------------------------
dofile(repoRoot .. "Libs/LibDualSpec-1.0/LibDualSpec-1.0.lua")
local LibDualSpec = LibStub("LibDualSpec-1.0")

-------------------------------------------------------------------------
-- 9. StaticPopup stubs, mirroring Blizzard's show/hide/click semantics
-- (Blizzard's StaticPopup.lua and GameDialog.lua).
-------------------------------------------------------------------------
StaticPopupDialogs = {}
local shownDialogs = {}

local function makeDialog(entry)
	local dialog = { which = entry.which, data = entry.data, entry = entry }
	local editText = ""
	dialog.editBox = {
		SetText = function(_, text) editText = text end,
		GetText = function() return editText end,
		HighlightText = function() end,
		GetParent = function() return dialog end,
	}
	function dialog:GetEditBox()
		return self.editBox
	end
	function dialog:Hide()
		self.entry.shown = false
	end
	return dialog
end

StaticPopup_Show = function(which, a1, a2, data)
	local def = StaticPopupDialogs[which]
	local entry = { which = which, a1 = a1, a2 = a2, data = data, shown = true }
	entry.dialog = makeDialog(entry)
	shownDialogs[#shownDialogs + 1] = entry
	if def and def.OnShow then
		def.OnShow(entry.dialog, data)
	end
	return entry.dialog
end

StaticPopup_Hide = function(which)
	for _, entry in ipairs(shownDialogs) do
		if entry.which == which and entry.shown then
			entry.shown = false
		end
	end
end

local function lastPopup(which)
	for i = #shownDialogs, 1, -1 do
		if shownDialogs[i].which == which then
			return shownDialogs[i]
		end
	end
	return nil
end

-- Mirrors StaticPopup_OnClick's non-selectCallbackByIndex branch: the
-- dialog hides only if OnAccept exists and returns falsy.
local function acceptName(text, popup)
	popup = popup or lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	if text ~= nil then
		popup.dialog.editBox:SetText(text)
	end
	local def = StaticPopupDialogs["TRIAGE_IMPORT_PROFILE_NAME"]
	local result = def.OnAccept(popup.dialog, popup.data)
	if not result then
		popup.shown = false
	end
	return result
end

-- Mirrors the selectCallbackByIndex branch: hides only if the indexed
-- button function exists and returns falsy.
local function clickCollision(i, popup)
	popup = popup or lastPopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	local def = StaticPopupDialogs["TRIAGE_IMPORT_PROFILE_EXISTS"]
	local fn = def["OnButton" .. i]
	local result
	if fn then
		result = fn(popup.dialog, popup.data, "clicked")
	end
	if not result then
		popup.shown = false
	end
	return result
end

-------------------------------------------------------------------------
-- 10. Load order matches the TOC: Localizations, then Core, then Utils,
-- then GUI.
-------------------------------------------------------------------------
dofileSkipBOM(repoRoot .. "Localizations/enUS.lua")
dofile(repoRoot .. "Triage.lua")
local Triage = _G.Triage
dofile(repoRoot .. "DatabaseDefaults.lua")
dofile(repoRoot .. "Utils/Utilities.lua")
dofile(repoRoot .. "Utils/SpecDefaults.lua")
dofile(repoRoot .. "Utils/DatabaseMigration.lua")
dofile(repoRoot .. "GUI/ProfileImportExport.lua")

-------------------------------------------------------------------------
-- Test-only stand-ins for the pieces this harness does not load: options
-- panels, minimap, aura/config refresh, test mode, and AceSerializer.
-------------------------------------------------------------------------
Triage.supportsLibDualSpec = true
Triage.RED_COLOR = { WrapTextInColorCode = function(_, s) return s end }

local printLog = {}
function Triage:Print(msg)
	printLog[#printLog + 1] = msg
end

local refreshConfigCount = 0
function Triage:RefreshConfig()
	refreshConfigCount = refreshConfigCount + 1
	snaps[refreshConfigCount] = self.db.profile["indicator-1"].auras
end

function Triage:IsTestModeActive()
	return false
end
function Triage:StopTestMode() end

Triage.OptionsFrame = { Refresh = function() end }

-- OnEnable's own calls that reach outside this harness. The CompactUnitFrame
-- globals and supportsDispelOverlay are nil here, so its hook blocks are
-- skipped.
function Triage:RegisterChatCommand() end
function Triage:RefreshManagedFrameRegistry() end
function Triage:UpdateAllAuras() end
function Triage:RegisterBucketEvent() end
function Triage:RegisterEvent(event, fn)
	handlers[event] = fn
end
function Triage:RefreshRangeTicker() end
function Triage:UpdateTriageFocus() end
function Triage:UpdateAllStockAuraVisibility() end

function Triage:CreateGeneralOptions() return {} end
function Triage:CreateIndicatorOptions() return {} end
function Triage:CreateIconOptions() return {} end
function Triage:InitializeMinimapButton() end

-- Stand-ins for AceSerializer-3.0. Serialize keeps the table it was handed,
-- so a test can read what an export carries; Deserialize returns a fresh
-- table per call, same as the real one (AceSerializer-3.0.lua:213-230).
local pendingPayload
local exported
function Triage:Serialize(t)
	exported = deepcopy(t)
	return "serialized"
end
function Triage:Deserialize()
	return true, deepcopy(pendingPayload)
end

-- The native options frame's data model: the Hide Stock Buff Icons row is
-- read from it, the way the checkbox reads the profile.
dofile(repoRoot .. "GUI/OptionsModel.lua")

-------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------

local function panelHandler()
	local tbl = registeredOptions["Triage Profiles"]
	return tbl and tbl.handler
end

local function migrationMessageCount()
	local n = 0
	for _, msg in ipairs(printLog) do
		if tostring(msg):find("being migrated", 1, true) then
			n = n + 1
		end
	end
	return n
end

local function freshLogin(sv)
	wipeTable(AceDB.db_registry)
	wipeTable(LibDualSpec.registry)
	wipeTable(AceDBOptions.optionTables)
	wipeTable(AceDBOptions.handlers)
	registeredOptions = {}
	shownDialogs = {}
	printLog = {}
	refreshConfigCount = 0
	wipeTable(snaps)
	wipeTable(notifyLog)
	wipeTable(handlers)
	Triage.Triage_pendingStarterSetupKey = nil
	Triage.Triage_starterSetupReady = nil
	_G.EnhancedRaidFramesDB = sv
	Triage:OnInitialize()
end

local function logout()
	AceDB.frame:GetScript("OnEvent")(AceDB.frame, "PLAYER_LOGOUT")
end

local function importAs(payload, name)
	pendingPayload = payload
	Triage:PromptProfileImport("x")
	local result = acceptName(name)
	pendingPayload = nil
	return result
end

-- The Hide Stock Buff Icons checkbox as the native options frame reads it:
-- checked means the buff icons are hidden.
local function hideBuffsBox()
	for _, section in ipairs(Triage.OptionsModel.sections) do
		for _, row in ipairs(section.rows or {}) do
			if row.key == "showBuffs" then
				return row.get()
			end
		end
	end
	error("no showBuffs row in the options model")
end

local function showBuffs()
	return Triage.db.profile.showBuffs
end

local function slot(i)
	return Triage.db.profile["indicator-" .. i].auras
end

local function ds(specID)
	return Triage.db.profile.defaultsState.aura[specID]
end

-- A stored profile that has no starter setup: every indicator list it stores
-- is blank and it records no spec.
local function untouched(profile, label)
	for i = 1, 9 do
		local indicator = rawget(profile, "indicator-" .. i)
		if indicator then
			local auras = rawget(indicator, "auras")
			assertEqual(auras == nil or auras == "", true, label .. " indicator-" .. i .. " list")
		end
	end
	local state = rawget(profile, "defaultsState")
	assertEqual(state == nil or next(state.aura or {}) == nil, true, label .. " defaultsState")
end

local function pew()
	handlers.PLAYER_ENTERING_WORLD()
end

local function ldsEvent(event)
	LibDualSpec.eventFrame:GetScript("OnEvent")(LibDualSpec.eventFrame, event)
end

local function retail(i)
	Triage.supportsSpecDefaults = true
	currentSpec = i
end

-------------------------------------------------------------------------
-- Fixtures
-------------------------------------------------------------------------

-- Character on "Old" (a profile that never stored showBuffs), plus one
-- stored profile of each other kind to switch to.
local function preSV()
	return {
		profileKeys = { [CHAR_KEY] = "Old" },
		profiles = {
			Old = { DB_VERSION = 2.3 },
			Hid = { DB_VERSION = 2.3, showBuffs = false },
			Shown = { DB_VERSION = 2.3, showBuffs = true },
			Def = { DB_VERSION = 2.2 },
			Leg = { [1] = { mineOnly = true } },
		},
	}
end

-------------------------------------------------------------------------
-- Tests
-------------------------------------------------------------------------

local tests = {}

-- Rule 2: a profile that already exists and never stored showBuffs still
-- shows buff icons at login.
tests.T1 = function()
	freshLogin(preSV())
	assertEqual(showBuffs(), true, "showBuffs on an existing profile at login")
	assertEqual(hideBuffsBox(), false, "Hide Stock Buff Icons box on an existing profile")
	assertEqual(migrationMessageCount(), 0, "migration messages at login")
end

-- Rule 2: switching to existing profiles, including by spec change.
tests.T2 = function()
	freshLogin(preSV())
	Triage.db:SetProfile("Hid")
	assertEqual(showBuffs(), false, "showBuffs after switching to Hid")
	Triage.db:SetProfile("Shown")
	assertEqual(showBuffs(), true, "showBuffs after switching to Shown")

	Triage.db:SetDualSpecEnabled(true)
	Triage.db:SetDualSpecProfile("Old", 2)
	currentSpec = 2
	local eventFn = LibDualSpec.eventFrame:GetScript("OnEvent")
	eventFn(LibDualSpec.eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
	assertEqual(Triage.db:GetCurrentProfile(), "Old", "profile follows the spec 2 assignment")
	assertEqual(showBuffs(), true, "showBuffs after a spec change to Old")
end

-- Rule 2: legacy profiles migrate but keep showing buff icons.
tests.T3 = function()
	freshLogin(preSV())
	Triage.db:SetProfile("Def")
	assertEqual(showBuffs(), true, "showBuffs after switching to a 2.2 profile")
	assertEqual(migrationMessageCount(), 1, "migration messages after the 2.2 profile")
	Triage.db:SetProfile("Leg")
	assertEqual(showBuffs(), true, "showBuffs after switching to a legacy profile")
	assertEqual(Triage.db.profile["indicator-1"].casterFilter, "mine", "legacy indicator migrated")
end

-- Rule 1: a profile made with New starts hidden.
tests.T4 = function()
	freshLogin(preSV())
	panelHandler():SetProfile(nil, "G2buffs")
	assertEqual(showBuffs(), false, "showBuffs on a New profile")
	assertEqual(Triage.db.profile.showDebuffs, true, "showDebuffs on a New profile")
	assertEqual(Triage.db.profile.showDispellableDebuffs, true, "showDispellableDebuffs on a New profile")
	assertEqual(hideBuffsBox(), true, "Hide Stock Buff Icons box on a New profile")
	assertEqual(Triage.db.profile.DB_VERSION, Triage.DATABASE_VERSION, "DB_VERSION on a New profile")
	assertEqual(migrationMessageCount(), 0, "migration messages for a New profile")
end

-- Rule 1: a reset profile starts hidden.
tests.T5 = function()
	freshLogin(preSV())
	Triage.db:SetProfile("Shown")
	local before = refreshConfigCount
	panelHandler():Reset()
	assertEqual(showBuffs(), false, "showBuffs after Reset")
	assertEqual(Triage.db.profile.showDebuffs, true, "showDebuffs after Reset")
	assertEqual(Triage.db.profile.showDispellableDebuffs, true, "showDispellableDebuffs after Reset")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from Reset")
end

-- Rule 1: a new character's first profile is set up before login migration
-- reads it.
tests.T6 = function()
	freshLogin({})
	local stored = Triage.db.sv.profiles[CHAR_KEY]
	assertEqual(rawget(stored, "showBuffs"), false, "stored showBuffs on a new character's profile")
	assertEqual(migrationMessageCount(), 0, "migration messages for a new character")
end

-- Rule 3: Copy From takes the source's value.
tests.T7 = function()
	freshLogin(preSV())
	Triage.db:SetProfile("C1")
	panelHandler():CopyProfile(nil, "Leg")
	assertEqual(showBuffs(), true, "showBuffs after Copy From a legacy profile")
	assertEqual(migrationMessageCount(), 1, "Copy From migrates the destination once")
	Triage.db:SetProfile("C2")
	panelHandler():CopyProfile(nil, "Hid")
	assertEqual(showBuffs(), false, "showBuffs after Copy From a hidden profile")
end

-- Rule 3: importing under a new name takes the string's value.
tests.T8 = function()
	freshLogin(preSV())
	importAs({ DB_VERSION = 2.3 }, "I1")
	assertEqual(Triage.db:GetCurrentProfile(), "I1", "imported profile is active")
	assertEqual(showBuffs(), true, "showBuffs when the string has none")
	importAs({ DB_VERSION = 2.3, showBuffs = true }, "I2")
	assertEqual(showBuffs(), true, "showBuffs when the string has true")
	importAs({ [1] = { mineOnly = true } }, "I3")
	assertEqual(showBuffs(), true, "showBuffs when the string is a legacy one")
end

-- Rule 3: importing over the active profile takes the string's value.
tests.T9 = function()
	freshLogin(preSV())
	importAs({ DB_VERSION = 2.3 }, "Old")
	clickCollision(1)
	assertEqual(Triage.db:GetCurrentProfile(), "Old", "still on Old after the overwrite")
	assertEqual(showBuffs(), true, "showBuffs after overwriting with a string that has none")
	importAs({ DB_VERSION = 2.3, showBuffs = false }, "Old")
	clickCollision(1)
	assertEqual(showBuffs(), false, "showBuffs after overwriting with a string that has false")
end

-- Rule 4: an export carries showBuffs and imports back the same.
tests.T10 = function()
	freshLogin(preSV())
	panelHandler():SetProfile(nil, "RT")
	Triage:SerializeAndCompressProfile()
	assertEqual(exported.showBuffs, false, "export of a New profile carries showBuffs")
	local fromNew = exported
	importAs(fromNew, "RT2")
	assertEqual(showBuffs(), false, "showBuffs after importing a New profile's export")

	Triage.db:SetProfile("Shown")
	Triage:SerializeAndCompressProfile()
	assertEqual(exported.showBuffs, true, "export of a shown profile carries showBuffs")
	importAs(exported, "RT3")
	assertEqual(showBuffs(), true, "showBuffs after importing a shown profile's export")
end

-- Invariant: every existing profile reads what it read before, and no
-- profile that has not been opened gains a showBuffs key.
tests.T11 = function()
	local expected = { Old = true, Hid = false, Shown = true, Def = true, Leg = true }
	local names = { "Old", "Hid", "Shown", "Def", "Leg" }

	for _, loginName in ipairs(names) do
		local sv = preSV()
		sv.profileKeys[CHAR_KEY] = loginName
		freshLogin(sv)
		assertEqual(showBuffs(), expected[loginName], "login on " .. loginName)
	end

	local sv = preSV()
	local rawBefore = {}
	for name, profile in pairs(sv.profiles) do
		rawBefore[name] = profile.showBuffs
	end
	freshLogin(sv)
	local opened = { Old = true }
	for _, name in ipairs(names) do
		Triage.db:SetProfile(name)
		opened[name] = true
		assertEqual(showBuffs(), expected[name], "switch to " .. name)
		for other, profile in pairs(sv.profiles) do
			if not opened[other] then
				assertEqual(rawget(profile, "showBuffs"), rawBefore[other], other .. " raw showBuffs after switching to " .. name)
			end
		end
	end
end

-- Logout keeps a stored false and strips a stored true, and both read back
-- the same at the next login.
tests.T12 = function()
	local sv = preSV()
	freshLogin(sv)
	Triage.db:SetProfile("N5")
	logout()
	assertEqual(rawget(sv.profiles.N5, "showBuffs"), false, "N5 stored showBuffs after logout")
	freshLogin(sv)
	assertEqual(Triage.db:GetCurrentProfile(), "N5", "relogin lands on N5")
	assertEqual(showBuffs(), false, "N5 showBuffs after relogin")

	local sv2 = preSV()
	freshLogin(sv2)
	Triage.db:SetProfile("Shown")
	logout()
	assertEqual(rawget(sv2.profiles.Shown, "showBuffs"), nil, "Shown stored showBuffs after logout")
	freshLogin(sv2)
	assertEqual(Triage.db:GetCurrentProfile(), "Shown", "relogin lands on Shown")
	assertEqual(showBuffs(), true, "Shown showBuffs after relogin")
end

-------------------------------------------------------------------------
-- Starter setup: a new Retail profile also gets its spec's starter
-- indicator lists, once the spec is known.
-------------------------------------------------------------------------

-- A new profile made after login is filled inline, before the refresh the
-- profile change already runs.
tests.S1 = function()
	retail(1)
	freshLogin(preSV())
	Triage:OnEnable()
	local before = refreshConfigCount
	panelHandler():SetProfile(nil, "F1")
	assertEqual(slot(1), "774", "slot 1 on a New profile")
	assertEqual(slot(4), "Dispel", "slot 4 on a New profile")
	assertEqual(slot(2), "", "slot 2 on a New profile")
	assertEqual(ds(105), true, "spec recorded on a New profile")
	assertEqual(showBuffs(), false, "showBuffs on a New profile")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from New")
	assertEqual(snaps[before + 1], "774", "lists in place at the refresh")
	assertEqual(#printLog, 0, "chat lines from New")
	local applied = Triage:ApplyCurrentSpecAuraDefaults(false)
	assertEqual(applied, 0, "slots Apply still finds to fill")
end

tests.S2 = function()
	retail(1)
	freshLogin(preSV())
	Triage:OnEnable()
	Triage.db:SetProfile("Shown")
	Triage.db.profile["indicator-1"].auras = "123"
	Triage.db.profile["indicator-5"].auras = "999"
	local before = refreshConfigCount
	panelHandler():Reset()
	assertEqual(slot(1), "774", "slot 1 after Reset")
	assertEqual(slot(4), "Dispel", "slot 4 after Reset")
	assertEqual(slot(5), "", "slot 5 after Reset")
	assertEqual(ds(105), true, "spec recorded after Reset")
	assertEqual(showBuffs(), false, "showBuffs after Reset")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from Reset")
	assertEqual(snaps[before + 1], "774", "lists in place at the refresh")
end

-- Spec data not ready while the addon loads: no spec read and no refresh in
-- OnInitialize, and the fill lands at OnEnable ahead of its one refresh.
tests.S3 = function()
	retail(1)
	specInit = false
	freshLogin({})
	assertEqual(slot(1), "", "slot 1 after login")
	assertEqual(refreshConfigCount, 0, "RefreshConfig at login")
	assertEqual(specReads, 0, "spec reads at login")
	specInit = true
	Triage:OnEnable()
	assertEqual(slot(1), "774", "slot 1 after OnEnable")
	assertEqual(refreshConfigCount, 1, "RefreshConfig calls through OnEnable")
	assertEqual(snaps[1], "774", "lists in place at the OnEnable refresh")
	assertEqual(notifyLog["Triage Indicator Options"], nil, "options panel notifications")
	assertEqual(ds(105), true, "spec recorded after OnEnable")
end

-- Spec data already ready at login still waits for OnEnable.
tests.S4 = function()
	retail(1)
	freshLogin({})
	assertEqual(slot(1), "", "slot 1 after login")
	assertEqual(refreshConfigCount, 0, "RefreshConfig at login")
	assertEqual(specReads, 0, "spec reads at login")
	Triage:OnEnable()
	assertEqual(slot(1), "774", "slot 1 after OnEnable")
end

-- Still unknown at OnEnable: the next loading screen fills it, once.
tests.S5 = function()
	retail(1)
	specInit = false
	freshLogin({})
	Triage:OnEnable()
	assertEqual(slot(1), "", "slot 1 after OnEnable")
	assertEqual(refreshConfigCount, 1, "RefreshConfig after OnEnable")
	specInit = true
	pew()
	assertEqual(slot(1), "774", "slot 1 after the loading screen")
	assertEqual(refreshConfigCount, 2, "RefreshConfig after the late fill")
	assertEqual(notifyLog["Triage Indicator Options"], 1, "options panel notifications after the late fill")
	Triage.db.profile["indicator-1"].auras = ""
	pew()
	assertEqual(slot(1), "", "slot 1 after a second loading screen")
	assertEqual(refreshConfigCount, 2, "RefreshConfig after a second loading screen")
end

-- A waiting fill belongs to the profile it was made for.
tests.S6 = function()
	retail(1)
	specInit = false
	local sv = { profiles = { Other = { DB_VERSION = 2.3 } } }
	freshLogin(sv)
	Triage:OnEnable()
	Triage.db:SetProfile("Other")
	Triage.db:SetProfile(CHAR_KEY)
	specInit = true
	pew()
	untouched(sv.profiles.Other, "Other after switching away and back")
	untouched(sv.profiles[CHAR_KEY], "the new profile after switching away and back")

	sv = {
		profiles = { Other = { DB_VERSION = 2.3 } },
		namespaces = { ["LibDualSpec-1.0"] = { char = { [CHAR_KEY] = { enabled = true, [1] = "Other" } } } },
	}
	freshLogin(sv)
	ldsEvent("PLAYER_LOGIN")
	assertEqual(Triage.db:GetCurrentProfile(), "Other", "LibDualSpec moved the character before OnEnable")
	Triage:OnEnable()
	pew()
	untouched(sv.profiles.Other, "Other after a LibDualSpec switch")
	untouched(sv.profiles[CHAR_KEY], "the new profile after a LibDualSpec switch")
end

tests.S7 = function()
	retail(1)
	specInit = false
	local sv = { profiles = { Src = { DB_VERSION = 2.3, ["indicator-1"] = { auras = "555" } } } }
	freshLogin(sv)
	Triage:OnEnable()
	panelHandler():CopyProfile(nil, "Src")
	specInit = true
	pew()
	assertEqual(slot(1), "555", "slot 1 after Copy From")
	assertEqual(slot(4), "", "slot 4 after Copy From")
	assertEqual(ds(105), nil, "spec recorded after Copy From")
end

tests.S8 = function()
	retail(1)
	specInit = false
	freshLogin({})
	Triage:OnEnable()
	importAs({ DB_VERSION = 2.3, ["indicator-1"] = { auras = "555" } }, CHAR_KEY)
	clickCollision(1)
	specInit = true
	pew()
	assertEqual(slot(1), "555", "slot 1 after the import")
	assertEqual(slot(4), "", "slot 4 after the import")
	assertEqual(ds(105), nil, "spec recorded after the import")
end

-- Profiles that already exist are never filled, however they are reached.
tests.S9 = function()
	retail(1)
	local sv = preSV()
	freshLogin(sv)
	Triage:OnEnable()
	pew()
	Triage.db:SetProfile("Shown")
	Triage.db:SetProfile("Def")
	Triage.db:SetProfile("Old")
	Triage.db:SetDualSpecEnabled(true)
	Triage.db:SetDualSpecProfile("Hid", 2)
	currentSpec = 2
	ldsEvent("PLAYER_SPECIALIZATION_CHANGED")
	assertEqual(Triage.db:GetCurrentProfile(), "Hid", "profile follows the spec 2 assignment")
	freshLogin(sv)
	Triage:OnEnable()
	pew()
	for name, profile in pairs(sv.profiles) do
		untouched(profile, name)
	end
end

tests.S10 = function()
	retail(1)
	local sv = preSV()
	sv.profiles.Src = { DB_VERSION = 2.3, ["indicator-2"] = { auras = "42" } }
	freshLogin(sv)
	Triage:OnEnable()
	panelHandler():SetProfile(nil, "C1")
	assertEqual(slot(1), "774", "C1 filled")
	panelHandler():CopyProfile(nil, "Src")
	assertEqual(slot(1), "", "slot 1 after Copy From")
	assertEqual(slot(2), "42", "slot 2 after Copy From")
	assertEqual(slot(4), "", "slot 4 after Copy From")
	assertEqual(ds(105), nil, "spec recorded after Copy From")

	importAs({ DB_VERSION = 2.3 }, "I1")
	untouched(sv.profiles.I1, "I1 after import")
	importAs({ DB_VERSION = 2.3, ["indicator-3"] = { auras = "7" } }, "I1")
	clickCollision(1)
	assertEqual(slot(3), "7", "slot 3 after the overwrite")
	assertEqual(slot(1), "", "slot 1 after the overwrite")
	assertEqual(ds(105), nil, "spec recorded after the overwrite")
end

-- A starting spec has no setup to give, now or later in the session.
tests.S11 = function()
	retail(5)
	freshLogin({})
	Triage:OnEnable()
	assertEqual(slot(1), "", "slot 1 on a starting spec")
	currentSpec = 1
	pew()
	assertEqual(slot(1), "", "slot 1 after choosing a spec")
	currentSpec = 5
	panelHandler():SetProfile(nil, "N2")
	assertEqual(slot(1), "", "slot 1 on a New profile on a starting spec")
	assertEqual(showBuffs(), false, "showBuffs on a starting spec")
end

tests.S12 = function()
	retail(3)
	local sv = preSV()
	freshLogin(sv)
	Triage:OnEnable()
	panelHandler():SetProfile(nil, "G2none")
	untouched(sv.profiles.G2none, "G2none")
	assertEqual(showBuffs(), false, "showBuffs on a spec with no setup")
	assertEqual(#printLog, 0, "chat lines from New")
	pew()
	untouched(sv.profiles.G2none, "G2none after a loading screen")
end

tests.S13 = function()
	Triage.supportsSpecDefaults = false
	currentSpec = 1
	local sv = {}
	freshLogin(sv)
	Triage:OnEnable()
	pew()
	untouched(sv.profiles[CHAR_KEY], "the new character's profile")
	assertEqual(showBuffs(), false, "showBuffs on a new character")
	panelHandler():SetProfile(nil, "N13")
	untouched(sv.profiles.N13, "N13")
	assertEqual(showBuffs(), false, "showBuffs on a New profile")
	panelHandler():Reset()
	untouched(sv.profiles.N13, "N13 after Reset")
	assertEqual(showBuffs(), false, "showBuffs after Reset")
	assertEqual(specReads, 0, "spec reads")
end

-- The Apply and Reset buttons keep their return values, refresh and notify.
tests.S14 = function()
	retail(1)
	GetSpecialization = C_SpecializationInfo.GetSpecialization
	GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo
	freshLogin(preSV())
	local before = refreshConfigCount
	local notified = notifyLog["Triage Indicator Options"] or 0
	Triage.db.profile["indicator-1"].auras = "123"
	local applied, skipped, specID = Triage:ApplyCurrentSpecAuraDefaults(false)
	assertEqual(applied, 1, "applied by Apply")
	assertEqual(skipped, 1, "skipped by Apply")
	assertEqual(specID, 105, "spec from Apply")
	assertEqual(slot(1), "123", "slot 1 kept by Apply")
	assertEqual(slot(4), "Dispel", "slot 4 filled by Apply")
	assertEqual(ds(105), true, "spec recorded by Apply")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from Apply")
	assertEqual(notifyLog["Triage Indicator Options"], notified + 1, "notifications from Apply")

	applied, skipped, specID = Triage:ApplyCurrentSpecAuraDefaults(false)
	assertEqual(applied, 0, "applied by a second Apply")
	assertEqual(skipped, 2, "skipped by a second Apply")
	assertEqual(specID, 105, "spec from a second Apply")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from a second Apply")
	assertEqual(notifyLog["Triage Indicator Options"], notified + 1, "notifications from a second Apply")

	Triage.db.profile["indicator-1"].indicatorSize = 30
	Triage.db.profile["indicator-2"].auras = "9"
	applied, skipped, specID = Triage:ApplyCurrentSpecAuraDefaults(true)
	assertEqual(applied, 9, "applied by Reset")
	assertEqual(skipped, 0, "skipped by Reset")
	assertEqual(specID, 105, "spec from Reset")
	assertEqual(slot(1), "774", "slot 1 after Reset")
	assertEqual(slot(2), "", "slot 2 after Reset")
	assertEqual(Triage.db.profile["indicator-1"].indicatorSize, 18, "indicator size after Reset")
	assertEqual(refreshConfigCount, before + 2, "RefreshConfig delta from Reset")
	assertEqual(notifyLog["Triage Indicator Options"], notified + 2, "notifications from Reset")

	currentSpec = 3
	applied, skipped, specID = Triage:ApplyCurrentSpecAuraDefaults(false)
	assertEqual(applied .. "," .. skipped .. "," .. tostring(specID), "0,0,250", "Apply on a spec with no setup")
	assertEqual(refreshConfigCount, before + 2, "RefreshConfig delta on a spec with no setup")

	Triage.supportsSpecDefaults = false
	applied, skipped, specID = Triage:ApplyCurrentSpecAuraDefaults(false)
	assertEqual(applied .. "," .. skipped .. "," .. tostring(specID), "0,0,nil", "Apply where spec defaults are unsupported")
end

-- The spec comes from C_SpecializationInfo; the old globals are only a
-- fallback.
tests.S15 = function()
	retail(1)
	freshLogin(preSV())
	local applied, _, specID = Triage:ApplyCurrentSpecAuraDefaults(false)
	assertEqual(specID, 105, "spec with no global functions")
	assertEqual(applied, 2, "slots Apply fills with no global functions")

	GetSpecialization = function() return 2 end
	GetSpecializationInfo = function() return 264 end
	assertEqual(Triage:GetCurrentSpecDefaultsID(), 105, "spec with both sets present")

	C_SpecializationInfo.GetSpecialization = nil
	C_SpecializationInfo.GetSpecializationInfo = nil
	assertEqual(Triage:GetCurrentSpecDefaultsID(), 264, "spec from the global fallback")
end

-- A profile a spec change creates is filled for the spec it was made for.
tests.S16 = function()
	retail(1)
	local sv = preSV()
	freshLogin(sv)
	Triage:OnEnable()
	ldsEvent("PLAYER_LOGIN")
	Triage.db:SetDualSpecEnabled(true)
	Triage.db:SetDualSpecProfile("Spec2Prof", 2)
	assertEqual(Triage.db:GetCurrentProfile(), "Old", "still on Old before the spec change")
	currentSpec = 2
	ldsEvent("PLAYER_SPECIALIZATION_CHANGED")
	assertEqual(Triage.db:GetCurrentProfile(), "Spec2Prof", "profile follows the spec 2 assignment")
	assertEqual(slot(2), "61295", "slot 2 on the spec 2 profile")
	assertEqual(slot(1), "", "slot 1 on the spec 2 profile")
	assertEqual(ds(264), true, "spec 2 recorded")
	assertEqual(ds(105), nil, "spec 1 not recorded")
	assertEqual(showBuffs(), false, "showBuffs on the spec 2 profile")
	currentSpec = 1
	ldsEvent("PLAYER_SPECIALIZATION_CHANGED")
	assertEqual(Triage.db:GetCurrentProfile(), "Old", "back on Old")
	untouched(sv.profiles.Old, "Old after the spec changes")
end

-- Invariant: only a new or reset profile is ever filled or given
-- showBuffs = false.
tests.S17 = function()
	retail(1)
	local sv = preSV()
	sv.profiles.Src = { DB_VERSION = 2.3 }
	freshLogin(sv)
	Triage:OnEnable()
	pew()
	panelHandler():SetProfile(nil, "N1")
	panelHandler():Reset()
	for _, name in ipairs({ "Old", "Hid", "Shown", "Def", "Leg" }) do
		Triage.db:SetProfile(name)
	end
	panelHandler():SetProfile(nil, "N2")
	panelHandler():CopyProfile(nil, "Hid")
	importAs({ DB_VERSION = 2.3 }, "I1")
	Triage.db:SetDualSpecEnabled(true)
	Triage.db:SetDualSpecProfile("Old", 2)
	currentSpec = 2
	ldsEvent("PLAYER_SPECIALIZATION_CHANGED")
	assertEqual(Triage.db:GetCurrentProfile(), "Old", "profile follows the spec 2 assignment")
	pew()
	for _, name in ipairs({ "Old", "Hid", "Shown", "Def", "Leg", "Src", "I1", "N2" }) do
		untouched(sv.profiles[name], name)
	end
	assertEqual(rawget(sv.profiles.N1, "showBuffs"), false, "N1 stored showBuffs")
end

-- LibDualSpec can move the character before Triage listens for profile
-- changes, leaving the fill armed for a profile that is no longer active.
tests.S18 = function()
	retail(1)
	local sv = {
		profiles = { Other = { DB_VERSION = 2.3 } },
		namespaces = { ["LibDualSpec-1.0"] = { char = { [CHAR_KEY] = { enabled = true, [1] = "Other" } } } },
	}
	LibDualSpec.currentSpec = 1
	freshLogin(sv)
	assertEqual(Triage.db:GetCurrentProfile(), "Other", "LibDualSpec moved the character during login")
	assertEqual(Triage.Triage_pendingStarterSetupKey, CHAR_KEY, "fill armed for the profile made before the move")
	Triage:OnEnable()
	pew()
	untouched(sv.profiles.Other, "Other")
	assertEqual(ds(105), nil, "spec recorded on Other")
	assertEqual(Triage.Triage_pendingStarterSetupKey, nil, "fill still waiting")
end

-------------------------------------------------------------------------
-- Runner
-------------------------------------------------------------------------

local order = {
	"T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10", "T11", "T12",
	"S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11", "S12", "S13", "S14", "S15", "S16",
	"S17", "S18",
}

-- Each row starts from a client with no spec support and the spec stubs as
-- the game exposes them; Triage itself persists across rows.
local function resetRow()
	Triage.supportsSpecDefaults = nil
	Triage.SpecDefaults = {
		[105] = { [1] = "774", [4] = "Dispel" },
		[264] = { [2] = "61295", [4] = "Dispel" },
		[65] = { [1] = "53563" },
	}
	specInit = true
	specReads = 0
	currentSpec = 0
	C_SpecializationInfo.GetSpecialization = stubGetSpecialization
	C_SpecializationInfo.IsInitialized = stubIsInitialized
	C_SpecializationInfo.GetSpecializationInfo = stubGetSpecializationInfo
	GetSpecialization = nil
	GetSpecializationInfo = nil
	LibDualSpec.currentSpec = 0
end

local anyFailed = false
for _, name in ipairs(order) do
	resetRow()
	local ok, err = pcall(tests[name])
	if ok then
		print(name .. " PASS")
	else
		print(name .. " FAIL: " .. tostring(err))
		anyFailed = true
	end
end

if anyFailed then
	os.exit(1)
end
