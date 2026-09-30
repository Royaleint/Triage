-- luacheck: globals arg dofile os io loadstring wipe CreateFrame GetRealmName UnitName UnitClass UnitRace UnitFactionGroup GetLocale GetCurrentRegion GetCurrentRegionName CopyTable securecallfunction GetBuildInfo IsLoggedIn ClassicExpansionAtLeast ClassicExpansionAtMost LE_EXPANSION_MISTS_OF_PANDARIA LE_EXPANSION_SHADOWLANDS LE_EXPANSION_CATACLYSM C_SpecializationInfo GetSpecializationInfoForClassID GetNumSpecializations StaticPopupDialogs StaticPopup_Show StaticPopup_Hide
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
function AceConfigRegistry:NotifyChange() end

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

function Triage:IsTestModeActive()
	return false
end
function Triage:StopTestMode() end

Triage.OptionsFrame = { Refresh = function() end }

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
-- Runner
-------------------------------------------------------------------------

local order = {
	"T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10", "T11", "T12",
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
