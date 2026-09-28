-- luacheck: globals arg dofile os io loadstring wipe CreateFrame GetRealmName UnitName UnitClass UnitRace UnitFactionGroup GetLocale GetCurrentRegion GetCurrentRegionName CopyTable securecallfunction GetBuildInfo IsLoggedIn ClassicExpansionAtLeast ClassicExpansionAtMost LE_EXPANSION_MISTS_OF_PANDARIA LE_EXPANSION_SHADOWLANDS LE_EXPANSION_CATACLYSM C_SpecializationInfo GetSpecializationInfoForClassID GetNumSpecializations StaticPopupDialogs StaticPopup_Show StaticPopup_Hide
-- TRI-072: login must keep exactly one AceDB object alive, through migration,
-- reset, new-profile creation, Copy From, a spec change, and importing a
-- pasted profile. Base f520c77 rebuilds the whole database object on every
-- migration and on every import, which orphans the panel, LibDualSpec, and
-- every registered callback. This file proves that stops happening, and
-- that migration and import keep producing the same data they always did.

local repoRoot = arg[1] or "./"
if repoRoot:sub(-1) ~= "/" and repoRoot:sub(-1) ~= "\\" then
	repoRoot = repoRoot .. "/"
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertTrue(value, message)
	if not value then
		error(message or "assertion failed", 2)
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

-- Reports the first differing path, so a failed compare says where.
local function deepEqual(a, b, path)
	path = path or "root"
	if type(a) ~= type(b) then
		return false, path .. " (type " .. type(a) .. " vs " .. type(b) .. ")"
	end
	if type(a) ~= "table" then
		if a ~= b then
			return false, path .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")"
		end
		return true
	end
	for k, v in pairs(a) do
		local ok, diff = deepEqual(v, b[k], path .. "." .. tostring(k))
		if not ok then
			return false, diff
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false, path .. "." .. tostring(k) .. " (missing on the left side)"
		end
	end
	return true
end

local function wipeTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

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

local realNew = AceDB.New
local newCallCount = 0
AceDB.New = function(self, ...)
	newCallCount = newCallCount + 1
	return realNew(self, ...)
end

-------------------------------------------------------------------------
-- 6. LibStub:NewLibrary stubs.
-------------------------------------------------------------------------
local registeredOptions = {}
local notifyChangeLog = {}
local AceConfigRegistry = LibStub:NewLibrary("AceConfigRegistry-3.0", 1)
function AceConfigRegistry:RegisterOptionsTable(appName, tbl)
	registeredOptions[appName] = tbl
end
function AceConfigRegistry:IterateOptionsTables()
	return pairs(registeredOptions)
end
function AceConfigRegistry:NotifyChange(appName)
	notifyChangeLog[#notifyChangeLog + 1] = appName
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
			__index = function(t, k)
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

local ldbIconRefreshCount = 0
local ldbIconRefreshArg
local LibDBIcon = LibStub:NewLibrary("LibDBIcon-1.0", 1)
function LibDBIcon:Refresh(_, minimapTable)
	ldbIconRefreshCount = ldbIconRefreshCount + 1
	ldbIconRefreshArg = minimapTable
end

-------------------------------------------------------------------------
-- 7. LibDualSpec load-time stubs.
-------------------------------------------------------------------------
local currentSpec = 0
C_SpecializationInfo = {
	GetNumSpecializationsForClassID = function() return 4 end,
	GetSpecialization = function() return currentSpec end,
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
-- 9. StaticPopup stubs, mirroring Blizzard's show/hide/escape/click
-- semantics (Blizzard's StaticPopup.lua and GameDialog.lua).
-------------------------------------------------------------------------
StaticPopupDialogs = {}
local popupLog = {}
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
	local entry = {
		which = which,
		a1 = a1,
		a2 = a2,
		data = data,
		shown = true,
		hideOnEscape = def and def.hideOnEscape,
	}
	entry.dialog = makeDialog(entry)
	entry.button1 = def and def.button1
	entry.button2 = def and def.button2
	entry.button3 = def and def.button3
	popupLog[#popupLog + 1] = entry
	shownDialogs[#shownDialogs + 1] = entry
	if def and def.OnShow then
		def.OnShow(entry.dialog, data)
	end
	return entry.dialog
end

StaticPopup_Hide = function(which)
	popupLog[#popupLog + 1] = { which = which, hide = true }
	for _, entry in ipairs(shownDialogs) do
		if entry.which == which and entry.shown then
			entry.shown = false
		end
	end
end

-- Mirrors StaticPopup_EscapePressed: acts only on shown dialogs whose def
-- has hideOnEscape, and calls OnCancel only if the def defines one.
local function escape(which)
	for _, entry in ipairs(shownDialogs) do
		if entry.shown and entry.hideOnEscape and (not which or entry.which == which) then
			local def = StaticPopupDialogs[entry.which]
			if def and def.OnCancel then
				def.OnCancel(entry.dialog, entry.data)
			end
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

-- Mirrors StaticPopupEditBoxMixin:OnEscapePressed(): a dialog's edit box
-- auto-focuses as soon as it shows, so Escape reaches the edit box's own
-- handler instead of the global StaticPopup_EscapePressed path used by
-- every other dialog.
local function escapeEditBox(which)
	local popup = lastPopup(which)
	if not popup then
		return
	end
	local def = StaticPopupDialogs[which]
	local handler = def and def.EditBoxOnEscapePressed
	if handler then
		handler(popup.dialog.editBox, popup.data)
	end
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
end

local testModeActive = false
local stopTestModeCalls = 0
function Triage:IsTestModeActive()
	return testModeActive
end
function Triage:StopTestMode()
	stopTestModeCalls = stopTestModeCalls + 1
	testModeActive = false
end

local optionsFrameRefreshCount = 0
Triage.OptionsFrame = {
	Refresh = function()
		optionsFrameRefreshCount = optionsFrameRefreshCount + 1
	end,
}

function Triage:CreateGeneralOptions() return {} end
function Triage:CreateIndicatorOptions() return {} end
function Triage:CreateIconOptions() return {} end
function Triage:InitializeMinimapButton() end

-- Stand-in for AceSerializer-3.0's Deserialize: returns a fresh table per
-- call, same as the real one (AceSerializer-3.0.lua:213-230).
local pendingPayload
local deserializeOverride
function Triage:Deserialize(input)
	if deserializeOverride then
		return deserializeOverride(input)
	end
	return true, deepcopy(pendingPayload)
end

-- GUI/OptionsModel.lua is the native options frame's data model. It loads
-- cleanly under these same stand-ins plus Triage.POSITIONS left nil (the
-- default here), so T15 drives the real native Import button instead of
-- scanning its source. A load failure here fails the whole run loudly,
-- rather than being silently absorbed into a weaker fallback check.
dofile(repoRoot .. "GUI/OptionsModel.lua")

-------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------

local function liveCount()
	local n = 0
	for db in pairs(AceDB.db_registry) do
		if rawget(db, "sv") == _G.EnhancedRaidFramesDB then
			n = n + 1
		end
	end
	return n
end

local function ldsCount()
	local n = 0
	for _, name in LibDualSpec:IterateDatabases() do
		if name == "EnhancedRaidFrames" then
			n = n + 1
		end
	end
	return n
end

local function ldsTarget()
	local target
	for t in pairs(LibDualSpec.registry) do
		target = t
	end
	return target
end

local function panelDb()
	local tbl = registeredOptions["Triage Profiles"]
	return tbl and tbl.handler and tbl.handler.db
end

local function panelHandler()
	local tbl = registeredOptions["Triage Profiles"]
	return tbl and tbl.handler
end

local function printedMigrationMessage()
	for _, msg in ipairs(printLog) do
		if tostring(msg):find("being migrated", 1, true) then
			return true
		end
	end
	return false
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
	notifyChangeLog = {}
	popupLog = {}
	shownDialogs = {}
	printLog = {}
	newCallCount = 0
	refreshConfigCount = 0
	stopTestModeCalls = 0
	optionsFrameRefreshCount = 0
	ldbIconRefreshCount = 0
	ldbIconRefreshArg = nil
	testModeActive = false
	_G.EnhancedRaidFramesDB = sv
	Triage:OnInitialize()
end

-- The frozen f520c77 old-path oracle (Utils/DatabaseMigration.lua:27-64,
-- verbatim). It must never be edited to track the fix; it exists to prove
-- what the fix changed. Uses the unwrapped AceDB.New so its two calls are
-- not counted by the New-count spy.
local function oldPathMigrate(sv)
	local db1 = realNew(AceDB, sv, Triage:CreateDefaults())
	local profile = db1.profile

	for i = 1, 9 do
		if profile[i] then
			if profile[i].indicatorColor and profile[i].indicatorColor.r then
				profile[i].indicatorColor = {
					profile[i].indicatorColor.r, profile[i].indicatorColor.g,
					profile[i].indicatorColor.b, profile[i].indicatorColor.a,
				}
			end
			if profile[i].textColor and profile[i].textColor.r then
				profile[i].textColor = {
					profile[i].textColor.r, profile[i].textColor.g,
					profile[i].textColor.b, profile[i].textColor.a,
				}
			end
		end
	end

	for i = 1, 9 do
		if profile[i] then
			for k, v in pairs(profile[i]) do
				profile["indicator-" .. i][k] = v
			end
		end
	end

	for i = 1, 9 do
		local indicatorDB = profile["indicator-" .. i]
		if indicatorDB and indicatorDB.mineOnly ~= nil then
			indicatorDB.casterFilter = indicatorDB.mineOnly and "mine" or "all"
			indicatorDB.mineOnly = nil
		end
	end

	profile.DB_VERSION = Triage.DATABASE_VERSION

	local db2 = realNew(AceDB, sv, Triage:CreateDefaults())
	local result = db2.profile

	AceDB.db_registry[db1] = nil
	AceDB.db_registry[db2] = nil

	return result
end

local function importAs(payload, name)
	pendingPayload = payload
	Triage:PromptProfileImport("x")
	local result = acceptName(name)
	pendingPayload = nil
	return result
end

-------------------------------------------------------------------------
-- Fixtures
-------------------------------------------------------------------------

-- Character already at the current version, plus one stored legacy profile
-- to switch to.
local function baseSV()
	return {
		profileKeys = { [CHAR_KEY] = "Main" },
		profiles = {
			Main = { DB_VERSION = Triage.DATABASE_VERSION },
			Legacy = { [1] = { mineOnly = true } },
		},
	}
end

-- Active "Main" carries non-default values, so an import that replaces it
-- can be checked for leftover ("stale") data.
local function customMainSV()
	return {
		profileKeys = { [CHAR_KEY] = "Main" },
		profiles = {
			Main = {
				DB_VERSION = Triage.DATABASE_VERSION,
				frameScale = 2,
				optionsFrame = { x = 1 },
				["indicator-1"] = { indicatorSize = 30 },
			},
		},
	}
end

-- A non-active "Imported" profile already exists, with non-default values,
-- so a collision can be exercised.
local function svWithExistingImported()
	local sv = baseSV()
	sv.profiles.Imported = {
		DB_VERSION = Triage.DATABASE_VERSION,
		frameScale = 3,
		optionsFrame = { x = 1 },
		["indicator-1"] = { indicatorSize = 40 },
	}
	return sv
end

-- Wording fragment unique to the spec note, absent from the plain
-- name-prompt text.
local L_SPEC_NOTE_MARK = "assigned profile"

-- Runs T1's operation sequence (login, reset, new profile, import, switch
-- to a legacy profile), calling fn(stepName) after each one.
local function forEachProfileOp(sv, fn)
	freshLogin(sv)
	fn("login")

	Triage.db:ResetProfile()
	fn("reset")

	Triage.db:SetProfile("G2test")
	fn("new")

	importAs({ DB_VERSION = Triage.DATABASE_VERSION, frameScale = 1.25 }, "T1imp")
	fn("import")

	Triage.db:SetProfile("Legacy")
	fn("switch to a legacy profile")
end

-------------------------------------------------------------------------
-- Tests
-------------------------------------------------------------------------

local tests = {}

tests.T1 = function()
	forEachProfileOp(baseSV(), function(step)
		assertEqual(newCallCount, 1, "AceDB:New call count at " .. step)
	end)
end

tests.T2 = function()
	forEachProfileOp(baseSV(), function(step)
		assertEqual(liveCount(), 1, "live db count at " .. step)
		assertEqual(ldsCount(), 1, "LibDualSpec db count at " .. step)
		assertEqual(ldsTarget(), Triage.db, "LibDualSpec target at " .. step)
	end)
end

tests.T3 = function()
	forEachProfileOp(baseSV(), function(step)
		local before = refreshConfigCount
		local other = (Triage.db:GetCurrentProfile() == "Probe") and "Probe2" or "Probe"
		Triage.db:SetProfile(other)
		assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta at " .. step)
	end)
end

tests.T4 = function()
	forEachProfileOp(baseSV(), function(step)
		assertEqual(panelDb(), Triage.db, "panel db at " .. step)
	end)
end

tests.T5 = function()
	freshLogin(baseSV())
	Triage.db:ResetProfile()
	Triage.db:SetProfile("B")
	local _ = Triage.db.profile -- materialize sv.profiles.B
	local handler = panelHandler()
	local ok, err = pcall(handler.DeleteProfile, handler, nil, "B")
	assertTrue(not ok, "DeleteProfile on the active profile must error")
	assertTrue(tostring(err):find("Cannot delete the active profile", 1, true) ~= nil,
		"unexpected error: " .. tostring(err))
end

tests.T6 = function()
	freshLogin(baseSV())
	Triage.db:SetProfile("G2test")
	assertTrue(not printedMigrationMessage(), "no migration print for a new profile")
	assertEqual(Triage.db.profile.DB_VERSION, Triage.DATABASE_VERSION, "DB_VERSION on a new profile")
end

tests.T7 = function()
	freshLogin(baseSV())
	Triage.db:ResetProfile()
	assertTrue(not printedMigrationMessage(), "no migration print on reset")
	assertEqual(Triage.db.profile.DB_VERSION, Triage.DATABASE_VERSION, "DB_VERSION after reset")
end

tests.T8 = function()
	freshLogin({})
	assertTrue(not printedMigrationMessage(), "no migration print for a brand-new character")
	assertEqual(Triage.db.profile.DB_VERSION, Triage.DATABASE_VERSION, "DB_VERSION for a new character")
end

tests.T9 = function()
	local sv = {
		profileKeys = { [CHAR_KEY] = "Legacy" },
		profiles = {
			Legacy = { [1] = { mineOnly = true, indicatorColor = { r = 0, g = 1, b = 0 } } },
			Legacy2 = { [1] = { mineOnly = false } },
		},
	}
	freshLogin(sv)
	assertEqual(migrationMessageCount(), 1, "login migration message count")
	assertEqual(Triage.db.profile.DB_VERSION, Triage.DATABASE_VERSION, "DB_VERSION after login migration")
	assertEqual(Triage.db.profile["indicator-1"].casterFilter, "mine", "casterFilter converted from mineOnly")
	assertEqual(Triage.db.profile["indicator-1"].indicatorColor[4], 1, "indicatorColor alpha filled by defaults")
	assertEqual(newCallCount, 1, "AceDB:New count after login migration")

	printLog = {}
	Triage.db:SetProfile("Legacy2")
	assertEqual(migrationMessageCount(), 1, "migration message count on switching to a second legacy profile")
	assertEqual(newCallCount, 1, "AceDB:New count stays 1 after the second migration")
end

tests.T10 = function()
	freshLogin(customMainSV())

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION, showBuffs = false, ["indicator-1"] = { auras = "X" } }
	local opts = registeredOptions["Triage Import Export Profile Options"]
	opts.args.TextBox.set(nil, "x")
	pendingPayload = nil

	local popup = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(popup ~= nil and popup.shown, "name popup shown")
	assertEqual(popup.dialog.editBox:GetText(), "Imported", "prefilled suggested name")

	acceptName(nil)

	assertEqual(Triage.db:GetCurrentProfile(), "Imported", "current profile after import")
	local p = Triage.db.profile
	assertEqual(p.frameScale, 1, "frameScale reset to default")
	assertEqual(p["indicator-1"].indicatorSize, 18, "indicator-1.indicatorSize reset to default")
	assertEqual(p["indicator-1"].showIcon, true, "indicator-1.showIcon default")
	assertEqual(p["indicator-1"].auras, "X", "indicator-1.auras from the payload")
	assertEqual(p.showBuffs, false, "showBuffs from the payload")
	assertEqual(p.optionsFrame, nil, "optionsFrame not carried from Main")
end

tests.T11 = function()
	freshLogin(customMainSV())
	testModeActive = true
	local refreshBefore = refreshConfigCount

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	local opts = registeredOptions["Triage Import Export Profile Options"]
	opts.args.TextBox.set(nil, "x")
	pendingPayload = nil
	acceptName(nil)

	assertEqual(stopTestModeCalls, 1, "StopTestMode called once")
	assertEqual(refreshConfigCount, refreshBefore + 1, "RefreshConfig delta")
	assertEqual(ldbIconRefreshCount, 1, "LDBIcon refreshed exactly once")
	assertEqual(ldbIconRefreshArg, Triage.db.profile.minimap, "LDBIcon refreshed with the new profile's minimap table")
end

tests.T12 = function()
	freshLogin(baseSV())
	local newBefore = newCallCount
	local opts = registeredOptions["Triage Import Export Profile Options"]

	pendingPayload = { [1] = { mineOnly = true } }
	opts.args.TextBox.set(nil, "x")
	pendingPayload = nil
	acceptName("LegacyImp")
	assertEqual(migrationMessageCount(), 1, "legacy import migrates once")
	assertEqual(Triage.db.profile["indicator-1"].casterFilter, "mine", "casterFilter converted on import")
	assertEqual(newCallCount, newBefore, "AceDB:New count unchanged by import")

	printLog = {}
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	opts.args.TextBox.set(nil, "x")
	pendingPayload = nil
	acceptName("CurrentImp")
	assertEqual(migrationMessageCount(), 0, "current-version import prints no migration message")

	printLog = {}
	pendingPayload = { DB_VERSION = 9.9 }
	opts.args.TextBox.set(nil, "x")
	pendingPayload = nil
	acceptName("FutureImp")
	assertEqual(migrationMessageCount(), 0, "future-version import prints no migration message")
	assertEqual(Triage.db.profile.DB_VERSION, 9.9, "future DB_VERSION applied as-is")
end

tests.T13 = function()
	-- Fixture A: legacy colors keep every component, plus a non-default
	-- top-level key and an all-default nested table. Old and new must
	-- match exactly.
	local fixtureA = {
		profileKeys = { [CHAR_KEY] = "Legacy" },
		profiles = {
			Legacy = {
				[1] = {
					indicatorColor = { r = 0, g = 1, b = 0.59, a = 1 },
					textColor = { r = 1, g = 1, b = 1, a = 1 },
					mineOnly = true,
					indicatorSize = 22,
				},
				frameScale = 1.5,
				minimap = { hide = false },
			},
		},
	}
	local oldA = oldPathMigrate(deepcopy(fixtureA))
	freshLogin(deepcopy(fixtureA))
	local newA = Triage.db.profile
	local okA, diffA = deepEqual(oldA, newA)
	assertTrue(okA, "fixture A old/new profiles differ at " .. tostring(diffA))

	-- Fixture B: a partial legacy color -- the one case where old and new
	-- migration are allowed to differ (see the alpha-slot check below).
	local fixtureB = {
		profileKeys = { [CHAR_KEY] = "Legacy" },
		profiles = {
			Legacy = {
				[1] = { indicatorColor = { r = 0, g = 1, b = 0 } },
			},
		},
	}
	local oldB = oldPathMigrate(deepcopy(fixtureB))
	freshLogin(deepcopy(fixtureB))
	local newB = Triage.db.profile

	assertEqual(oldB[1].indicatorColor[4], 1, "old path fills legacy alpha through the shared (aliased) table")
	assertEqual(newB[1].indicatorColor[4], nil, "new path leaves legacy alpha unfilled")
	assertEqual(oldB["indicator-1"].indicatorColor[4], 1, "old path's indicator-1 color is default-filled")
	assertEqual(newB["indicator-1"].indicatorColor[4], 1, "new path's indicator-1 color is still default-filled")

	local oldSnapshot = deepcopy(oldB)
	oldSnapshot[1].indicatorColor[4] = nil
	local okB, diffB = deepEqual(oldSnapshot, newB)
	assertTrue(okB, "fixture B profiles differ outside the legacy alpha slot, at " .. tostring(diffB))
end

tests.T14 = function()
	freshLogin(baseSV())
	local snapProfiles = deepcopy(Triage.db.sv.profiles)
	local snapKeys = deepcopy(Triage.db.sv.profileKeys)
	local snapCurrent = Triage.db:GetCurrentProfile()
	local refreshBefore = refreshConfigCount

	local function checkUnchanged(label)
		local okP, diffP = deepEqual(Triage.db.sv.profiles, snapProfiles)
		assertTrue(okP, label .. ": profiles changed at " .. tostring(diffP))
		local okK, diffK = deepEqual(Triage.db.sv.profileKeys, snapKeys)
		assertTrue(okK, label .. ": profileKeys changed at " .. tostring(diffK))
		assertEqual(Triage.db:GetCurrentProfile(), snapCurrent, label .. ": current profile changed")
		assertEqual(refreshConfigCount, refreshBefore, label .. ": RefreshConfig fired")
	end

	-- (i) empty input
	printLog = {}
	Triage:PromptProfileImport("")
	assertTrue(#printLog > 0, "(i) prints a failure message")
	local p1 = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(p1 == nil or not p1.shown, "(i) no popup left shown")
	checkUnchanged("(i)")

	-- (ii) Deserialize returns false
	printLog = {}
	deserializeOverride = function() return false end
	Triage:PromptProfileImport("x")
	deserializeOverride = nil
	assertTrue(#printLog > 0, "(ii) prints a failure message")
	checkUnchanged("(ii)")

	-- (iii) Deserialize returns true, "str" (a non-table payload)
	printLog = {}
	deserializeOverride = function() return true, "str" end
	Triage:PromptProfileImport("x")
	deserializeOverride = nil
	assertTrue(#printLog > 0, "(iii) prints a failure message")
	checkUnchanged("(iii)")

	-- (iv) valid payload, but the popup API is missing
	printLog = {}
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	local realShow = StaticPopup_Show
	StaticPopup_Show = nil
	Triage:PromptProfileImport("x")
	StaticPopup_Show = realShow
	pendingPayload = nil
	local found = false
	for _, msg in ipairs(printLog) do
		if tostring(msg):find("Data import Failed", 1, true) then
			found = true
		end
	end
	assertTrue(found, "(iv) prints the Data import Failed message")
	checkUnchanged("(iv)")
end

tests.T15 = function()
	freshLogin(baseSV())
	local importExportSection = Triage.OptionsModel:GetSection("importExport")
	local textRow, importRow
	for _, row in ipairs(importExportSection.rows) do
		if row.key == "importExportText" then
			textRow = row
		elseif row.key == "importCurrentProfile" then
			importRow = row
		end
	end
	assertTrue(textRow ~= nil and importRow ~= nil, "found the native import/export rows")

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	textRow.onTextChanged("x")
	local before = refreshConfigCount
	importRow.run()
	pendingPayload = nil

	local popup = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(popup ~= nil and popup.shown, "the native Import button shows the name popup")

	acceptName("NativeImp")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from the native Import button")
	assertEqual(ldbIconRefreshCount, 1, "LDBIcon refreshed once through the native Import button")
end

tests.T16 = function()
	freshLogin(baseSV())
	Triage.db:ResetProfile()
	Triage.db:SetDualSpecEnabled(true)
	Triage.db:SetDualSpecProfile("B", 2)

	currentSpec = 2
	local before = refreshConfigCount
	local eventFn = LibDualSpec.eventFrame:GetScript("OnEvent")
	eventFn(LibDualSpec.eventFrame, "PLAYER_SPECIALIZATION_CHANGED")

	assertEqual(Triage.db:GetCurrentProfile(), "B", "current profile follows the spec 2 assignment")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta on the spec-change event")
	assertEqual(ldsCount(), 1, "exactly one LibDualSpec target remains")
end

tests.T17 = function()
	local sv = {
		profileKeys = { [CHAR_KEY] = "Main" },
		profiles = {
			Main = { DB_VERSION = Triage.DATABASE_VERSION },
			LegacySrc = { [1] = { mineOnly = true } },
		},
	}
	freshLogin(sv)
	local before = refreshConfigCount
	local handler = panelHandler()
	handler:CopyProfile(nil, "LegacySrc")

	assertEqual(migrationMessageCount(), 1, "Copy From migrates the destination exactly once")
	assertEqual(Triage.db.profile["indicator-1"].casterFilter, "mine", "casterFilter converted by Copy From's migration")
	assertEqual(Triage.db.profile.DB_VERSION, Triage.DATABASE_VERSION, "DB_VERSION after Copy From")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta from Copy From")
	assertEqual(panelDb(), Triage.db, "panel still bound to the live db")
	assertEqual(newCallCount, 1, "AceDB:New count stays 1")
	assertEqual(liveCount(), 1, "exactly one live db for this SavedVariables table")
end

tests.T18 = function()
	freshLogin(baseSV())
	local before = deepcopy(Triage.db.profile)
	local refreshFrameBefore = optionsFrameRefreshCount

	importAs({ DB_VERSION = Triage.DATABASE_VERSION }, "Imported")

	assertTrue(rawget(Triage.db.sv.profiles, "Imported") ~= nil, "Imported profile exists in sv.profiles")
	local notified = false
	for _, name in ipairs(notifyChangeLog) do
		if name == "Triage Profiles" then
			notified = true
		end
	end
	assertTrue(notified, "AceConfigRegistry:NotifyChange('Triage Profiles') recorded")
	assertEqual(optionsFrameRefreshCount, refreshFrameBefore + 1, "OptionsFrame:Refresh delta")

	local handler = panelHandler()
	local list = handler:ListProfiles({ arg = "common" })
	local found = false
	for _, v in pairs(list) do
		if v == "Imported" then
			found = true
		end
	end
	assertTrue(found, "ListProfiles includes the imported profile")

	Triage.db:SetProfile("Main")
	local ok, diff = deepEqual(Triage.db.profile, before)
	assertTrue(ok, "Main is untouched by the import, differs at " .. tostring(diff))
end

tests.T19 = function()
	freshLogin(baseSV())

	Triage.db.sv.profiles.Imported = { DB_VERSION = Triage.DATABASE_VERSION }
	assertEqual(Triage:NextFreeProfileName("Imported"), "Imported 2", "{Main, Imported}")

	Triage.db.sv.profiles["Imported 2"] = { DB_VERSION = Triage.DATABASE_VERSION }
	assertEqual(Triage:NextFreeProfileName("Imported"), "Imported 3", "{Main, Imported, Imported 2}")

	Triage.db.sv.profiles["Imported 2"] = nil
	Triage.db.sv.profiles["Imported 3"] = { DB_VERSION = Triage.DATABASE_VERSION }
	assertEqual(Triage:NextFreeProfileName("Imported"), "Imported 2", "{Main, Imported, Imported 3}, lowest free")

	freshLogin(baseSV())
	assertEqual(Triage:NextFreeProfileName("Imported"), "Imported", "{Main} only")

	-- the current profile key counts even before it is materialised
	-- (AceDB GetProfiles :509-513)
	freshLogin(baseSV())
	Triage.db.sv.profileKeys[CHAR_KEY] = "Imported"
	Triage.db.keys.profile = "Imported"
	assertEqual(Triage:NextFreeProfileName("Imported"), "Imported 2",
		"current profile key counts even before it is materialised")

	-- wiring: the second import's name popup is prefilled with the next
	-- free name
	freshLogin(baseSV())
	importAs({ DB_VERSION = Triage.DATABASE_VERSION }, "Imported")
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local popup = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertEqual(popup.dialog.editBox:GetText(), "Imported 2", "second import prefilled with the next free name")
end

tests.T20 = function()
	freshLogin(svWithExistingImported())
	local snapMain = deepcopy(Triage.db.sv.profiles.Main)
	local snapLegacy = deepcopy(Triage.db.sv.profiles.Legacy)
	local before = refreshConfigCount

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION, frameScale = 1.5 }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Imported")

	local collision = lastPopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	assertTrue(collision ~= nil and collision.shown, "collision popup shown")
	assertEqual(collision.a1, "Imported", "collision popup text_arg1")
	assertEqual(collision.button2, 'Use "Imported 2"', "collision popup button2 label")

	clickCollision(1)

	assertEqual(Triage.db:GetCurrentProfile(), "Imported", "current profile after Overwrite")
	local p = Triage.db.profile
	assertEqual(p.frameScale, 1.5, "frameScale from the payload")
	assertEqual(p.optionsFrame, nil, "optionsFrame not carried over from the old Imported")
	assertEqual(p["indicator-1"].indicatorSize, 18, "indicatorSize reset to default, no stale data")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta")

	-- Legacy was never activated, so its raw table is untouched as-is.
	local okLegacy, diffLegacy = deepEqual(Triage.db.sv.profiles.Legacy, snapLegacy)
	assertTrue(okLegacy, "Legacy unaffected, differs at " .. tostring(diffLegacy))

	-- Main WAS active and was switched away from, so AceDB strips its
	-- default-equal fields from the raw table (normal behavior, restored on
	-- next load -- same reasoning as T18). Compare the live, default-filled
	-- profile instead of the raw table.
	Triage.db:SetProfile("Main")
	local okMain, diffMain = deepEqual(Triage.db.profile, snapMain)
	assertTrue(okMain, "Main unaffected, differs at " .. tostring(diffMain))
end

tests.T21 = function()
	-- (i)
	freshLogin(svWithExistingImported())
	local snapImported = deepcopy(Triage.db.sv.profiles.Imported)

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION, frameScale = 1.5 }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Imported")
	clickCollision(2)

	assertEqual(Triage.db:GetCurrentProfile(), "Imported 2", 'current profile after Use "Imported 2"')
	assertEqual(Triage.db.profile.frameScale, 1.5, "Imported 2 holds the payload")
	local okI, diffI = deepEqual(Triage.db.sv.profiles.Imported, snapImported)
	assertTrue(okI, "Imported unaffected, differs at " .. tostring(diffI))

	-- (ii) a second import starts while the first one's collision popup is
	-- still open, then the stale popup's button is clicked anyway
	local sv = baseSV()
	sv.profiles.Imported = { DB_VERSION = Triage.DATABASE_VERSION }
	freshLogin(sv)

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION, frameScale = 11 } -- P1
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Imported")
	local popupA = lastPopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	assertTrue(popupA ~= nil and popupA.shown, "collision popup A shown")

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION, frameScale = 22 } -- P2
	Triage:PromptProfileImport("x")
	pendingPayload = nil

	local hidName, hidExists = false, false
	for _, entry in ipairs(popupLog) do
		if entry.hide and entry.which == "TRIAGE_IMPORT_PROFILE_NAME" then
			hidName = true
		end
		if entry.hide and entry.which == "TRIAGE_IMPORT_PROFILE_EXISTS" then
			hidExists = true
		end
	end
	assertTrue(hidName, "StaticPopup_Hide recorded for the name popup")
	assertTrue(hidExists, "StaticPopup_Hide recorded for the collision popup")
	assertTrue(not popupA.shown, "the stale collision popup A is marked hidden")

	acceptName("Imported 2")
	assertEqual(Triage.db:GetCurrentProfile(), "Imported 2", "Imported 2 now holds P2")
	assertEqual(Triage.db.profile.frameScale, 22, "Imported 2 holds P2's payload")
	local snapImported2 = deepcopy(Triage.db.sv.profiles["Imported 2"])

	local refreshBefore = refreshConfigCount
	local def = StaticPopupDialogs["TRIAGE_IMPORT_PROFILE_EXISTS"]
	local result = def.OnButton2(popupA.dialog, popupA.data, "clicked")

	assertTrue(result == true, "the stale click returns true, so the reused frame stays shown")
	assertEqual(refreshConfigCount, refreshBefore, "RefreshConfig unaffected by the stale click")
	local ok2, diff2 = deepEqual(Triage.db.sv.profiles["Imported 2"], snapImported2)
	assertTrue(ok2, "Imported 2 was not overwritten by the stale click, differs at " .. tostring(diff2))

	local reopened = lastPopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	assertTrue(reopened ~= popupA, "a fresh collision popup entry was recorded")
	assertEqual(reopened.a1, "Imported 2", "the re-opened popup names Imported 2")
	assertEqual(reopened.button2, 'Use "Imported 2 2"', "re-opened popup offers the next free name")
end

tests.T22 = function()
	freshLogin(svWithExistingImported())
	local snapProfiles = deepcopy(Triage.db.sv.profiles)
	local snapCurrent = Triage.db:GetCurrentProfile()
	local refreshBefore = refreshConfigCount

	local function checkUnchanged(label)
		local ok, diff = deepEqual(Triage.db.sv.profiles, snapProfiles)
		assertTrue(ok, label .. ": profiles changed at " .. tostring(diff))
		assertEqual(refreshConfigCount, refreshBefore, label .. ": RefreshConfig fired")
		assertEqual(Triage.db:GetCurrentProfile(), snapCurrent, label .. ": current profile changed")
	end

	-- (i) Cancel on the collision popup
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Imported")
	clickCollision(3)
	checkUnchanged("(i)")

	-- (ii) name popup dismissed without accept
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	checkUnchanged("(ii)")

	-- (iii) empty name keeps the dialog open
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local result = acceptName("   ")
	assertTrue(result == true, "empty name keeps the dialog open")
	checkUnchanged("(iii)")
end

tests.T23 = function()
	freshLogin(customMainSV())
	local before = refreshConfigCount

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Main")
	local collision = lastPopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	assertTrue(collision ~= nil and collision.shown, "collision popup shown for the active profile's own name")
	clickCollision(1)

	assertEqual(Triage.db:GetCurrentProfile(), "Main", "current profile is still Main")
	assertTrue(Triage.db.profile == Triage.db.sv.profiles.Main, "Triage.db.profile is still the live Main table")
	assertEqual(Triage.db.profile.frameScale, 1, "frameScale reset to default (no stale data)")
	assertEqual(Triage.db.profile.optionsFrame, nil, "optionsFrame not carried over")
	assertEqual(Triage.db.profile["indicator-1"].indicatorSize, 18, "indicatorSize reset to default")
	assertEqual(refreshConfigCount, before + 1, "RefreshConfig delta")
end

tests.T24 = function()
	-- (i) spec profiles enabled. IsDualSpecEnabled() also requires
	-- lib.currentSpec > 0, which is LibDualSpec's own module state and
	-- outlives freshLogin; fire a spec event here instead of relying on
	-- another row having already done so, so this row passes standalone.
	freshLogin(baseSV())
	currentSpec = 1
	local eventFn = LibDualSpec.eventFrame:GetScript("OnEvent")
	eventFn(LibDualSpec.eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
	Triage.db:SetDualSpecEnabled(true)
	Triage.db:SetDualSpecProfile("B", 2)
	local snapChar = deepcopy(LibDualSpec.registry[Triage.db].db.char)

	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local popup = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(popup.a1:find(L_SPEC_NOTE_MARK, 1, true) ~= nil, "spec note present when spec profiles are enabled")
	acceptName("SpecImp")

	local okChar, diffChar = deepEqual(LibDualSpec.registry[Triage.db].db.char, snapChar)
	assertTrue(okChar, "LibDualSpec spec assignments unchanged, differ at " .. tostring(diffChar))

	-- (ii) spec profiles disabled
	freshLogin(baseSV())
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local popup2 = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(popup2.a1:find(L_SPEC_NOTE_MARK, 1, true) == nil, "no spec note when spec profiles are disabled")
	acceptName("NoSpecImp")

	-- (iii) the Era/TBC shape: IsDualSpecEnabled absent entirely
	freshLogin(baseSV())
	Triage.db.IsDualSpecEnabled = nil
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	local ok, err = pcall(function()
		Triage:PromptProfileImport("x")
	end)
	pendingPayload = nil
	assertTrue(ok, "no error when IsDualSpecEnabled is absent: " .. tostring(err))
	local popup3 = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(popup3.a1:find(L_SPEC_NOTE_MARK, 1, true) == nil, "no spec note on the Era/TBC shape")
end

tests.T25 = function()
	freshLogin(svWithExistingImported())

	local nameDef = StaticPopupDialogs["TRIAGE_IMPORT_PROFILE_NAME"]
	assertTrue(nameDef ~= nil, "name popup def exists")
	assertTrue(nameDef.hasEditBox ~= nil and nameDef.hasEditBox ~= false, "name popup has an edit box")
	assertTrue(nameDef.hideOnEscape == true, "name popup hides on Escape")
	assertTrue(type(nameDef.OnAccept) == "function", "name popup has OnAccept")
	assertTrue(type(nameDef.OnShow) == "function", "name popup has OnShow")
	assertTrue(type(nameDef.EditBoxOnEnterPressed) == "function", "name popup has EditBoxOnEnterPressed")
	assertTrue(type(nameDef.EditBoxOnEscapePressed) == "function", "name popup has EditBoxOnEscapePressed")
	assertTrue(nameDef.OnCancel == nil, "name popup has no OnCancel")
	assertTrue(nameDef.editBoxSecureText == nil, "name popup does not set editBoxSecureText")

	local existsDef = StaticPopupDialogs["TRIAGE_IMPORT_PROFILE_EXISTS"]
	assertTrue(existsDef ~= nil, "collision popup def exists")
	assertTrue(existsDef.selectCallbackByIndex == true, "collision popup uses selectCallbackByIndex")
	assertTrue(existsDef.hideOnEscape == true, "collision popup hides on Escape")
	assertTrue(type(existsDef.OnButton1) == "function", "collision popup has OnButton1")
	assertTrue(type(existsDef.OnButton2) == "function", "collision popup has OnButton2")
	assertTrue(type(existsDef.OnButton3) == "function", "collision popup has OnButton3")
	assertTrue(existsDef.OnCancel == nil, "collision popup has no OnCancel")
	assertTrue(existsDef.OnAccept == nil, "collision popup has no OnAccept")
	assertTrue(existsDef.editBoxSecureText == nil, "collision popup does not set editBoxSecureText")

	-- Escape on the collision popup
	local snapProfiles = deepcopy(Triage.db.sv.profiles)
	local refreshBefore = refreshConfigCount
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Imported")
	local collision = lastPopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	assertTrue(collision.shown, "collision popup shown before Escape")
	escape("TRIAGE_IMPORT_PROFILE_EXISTS")
	assertTrue(not collision.shown, "Escape hides the collision popup")
	local okC, diffC = deepEqual(Triage.db.sv.profiles, snapProfiles)
	assertTrue(okC, "Escape on the collision popup changed nothing, differs at " .. tostring(diffC))
	assertEqual(refreshConfigCount, refreshBefore, "Escape on the collision popup fires no RefreshConfig")

	-- Escape on the name popup. Its edit box auto-focuses on show, so real
	-- Escape reaches EditBoxOnEscapePressed, not the global escape handler
	-- used above -- model it through that path.
	local snapProfiles2 = deepcopy(Triage.db.sv.profiles)
	local refreshBefore2 = refreshConfigCount
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local namePopup = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(namePopup.shown, "name popup shown before Escape")
	escapeEditBox("TRIAGE_IMPORT_PROFILE_NAME")
	assertTrue(not namePopup.shown, "Escape (via the edit box) hides the name popup")
	local okN, diffN = deepEqual(Triage.db.sv.profiles, snapProfiles2)
	assertTrue(okN, "Escape on the name popup changed nothing, differs at " .. tostring(diffN))
	assertEqual(refreshConfigCount, refreshBefore2, "Escape on the name popup fires no RefreshConfig")
end

tests.T26 = function()
	local payload = {
		DB_VERSION = Triage.DATABASE_VERSION,
		testModePosition = false,
		["indicator-1"] = { indicatorColor = false },
	}

	freshLogin(baseSV())

	pendingPayload = payload
	local sanitised = Triage:DeserializeAndDecompressProfile("x")
	pendingPayload = nil
	assertTrue(type(sanitised) == "table", "DeserializeAndDecompressProfile returns a table")
	assertEqual(sanitised.testModePosition, nil, "sanitised payload drops the non-table testModePosition")

	-- (i) new name, the non-active raw-write path
	importAs(deepcopy(payload), "S1")
	local snapS1 = deepcopy(Triage.db.profile)
	assertEqual(type(snapS1.testModePosition), "table", "(i) testModePosition reads its table default")
	local ok1, diff1 = deepEqual(snapS1["indicator-1"].indicatorColor, { 0, 1, 0.59, 1 })
	assertTrue(ok1, "(i) indicatorColor reads its default, differs at " .. tostring(diff1))

	-- (ii) the active profile, through collision Overwrite (the reset+copy path)
	freshLogin(baseSV())
	pendingPayload = deepcopy(payload)
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	acceptName("Main")
	clickCollision(1)
	local snapMain = deepcopy(Triage.db.profile)
	assertEqual(type(snapMain.testModePosition), "table", "(ii) testModePosition reads its table default")
	local ok2, diff2 = deepEqual(snapMain["indicator-1"].indicatorColor, { 0, 1, 0.59, 1 })
	assertTrue(ok2, "(ii) indicatorColor reads its default, differs at " .. tostring(diff2))

	local okBoth, diffBoth = deepEqual(snapS1, snapMain)
	assertTrue(okBoth, "the two apply paths give the same content, differs at " .. tostring(diffBoth))
end

tests.T27 = function()
	-- Enter in the name box accepts, same result as clicking Import.
	freshLogin(customMainSV())
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION, showBuffs = false }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local popup = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	popup.dialog.editBox:SetText("EnterImp")
	local def = StaticPopupDialogs["TRIAGE_IMPORT_PROFILE_NAME"]
	def.EditBoxOnEnterPressed(popup.dialog.editBox, popup.data)

	assertEqual(Triage.db:GetCurrentProfile(), "EnterImp", "Enter accepts the typed name, same as clicking Import")
	assertEqual(Triage.db.profile.showBuffs, false, "the payload was applied")
	assertTrue(not popup.shown, "Enter hides the dialog, same as Escape")

	-- Enter with an empty/whitespace name changes nothing and keeps the
	-- dialog open, same as clicking Import with an empty box.
	freshLogin(baseSV())
	local snapProfiles = deepcopy(Triage.db.sv.profiles)
	local refreshBefore = refreshConfigCount
	pendingPayload = { DB_VERSION = Triage.DATABASE_VERSION }
	Triage:PromptProfileImport("x")
	pendingPayload = nil
	local popup2 = lastPopup("TRIAGE_IMPORT_PROFILE_NAME")
	popup2.dialog.editBox:SetText("   ")
	local result = def.EditBoxOnEnterPressed(popup2.dialog.editBox, popup2.data)
	assertTrue(result == true, "empty name keeps the dialog open")
	assertTrue(popup2.shown, "dialog stays open on an empty name")
	local ok, diff = deepEqual(Triage.db.sv.profiles, snapProfiles)
	assertTrue(ok, "nothing applied on an empty-name Enter, differs at " .. tostring(diff))
	assertEqual(refreshConfigCount, refreshBefore, "no RefreshConfig from an empty-name Enter")
end

-------------------------------------------------------------------------
-- Runner
-------------------------------------------------------------------------

local order = {
	"T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10",
	"T11", "T12", "T14", "T15", "T16", "T17", "T18", "T19", "T20", "T21",
	"T22", "T23", "T24", "T25", "T26", "T27", "T13",
}

local anyFailed = false
for _, name in ipairs(order) do
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
