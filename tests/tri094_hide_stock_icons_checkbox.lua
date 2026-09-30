-- luacheck: globals arg dofile LibStub InCombatLockdown AceGUIWidgetLSMlists io loadstring
-- TRI-094: the "Hide Stock ... Icons" checkboxes are shown inverted (checked
-- means Blizzard's icons are hidden) while the stored profile keys keep
-- their meaning (true = shown), so existing settings carry over unchanged.

local repoRoot = arg[1] or "./"
if repoRoot:sub(-1) ~= "/" and repoRoot:sub(-1) ~= "\\" then
	repoRoot = repoRoot .. "/"
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

-- enUS.lua ships with a UTF-8 BOM; dofile() chokes on it, so strip it.
local function dofileSkipBOM(path)
	local handle = assert(io.open(path, "rb"))
	local source = handle:read("*a")
	handle:close()
	if source:sub(1, 3) == "\239\187\191" then
		source = source:sub(4)
	end
	assert(loadstring(source, "@" .. path))()
end

-------------------------------------------------------------------------
-- Stand-ins: LibStub is the real one; AceLocale, LibRangeCheck and
-- AceConfigDialog are just enough for the two GUI files to load.
-------------------------------------------------------------------------
dofile(repoRoot .. "Libs/LibStub/LibStub.lua")

local locales = {}
local AceLocale = LibStub:NewLibrary("AceLocale-3.0", 1)
function AceLocale:NewLocale(appName)
	locales[appName] = locales[appName] or {}
	return locales[appName]
end
function AceLocale:GetLocale(appName)
	return setmetatable({}, {
		__index = function(_, key)
			local value = locales[appName][key]
			if value == true then
				return key
			end
			return value
		end,
	})
end
LibStub:NewLibrary("LibRangeCheck-3.0", 1)
LibStub:NewLibrary("AceConfigDialog-3.0", 1)

InCombatLockdown = function() return false end -- luacheck: ignore 121
AceGUIWidgetLSMlists = { font = {} } -- luacheck: ignore 121

dofileSkipBOM(repoRoot .. "Localizations/enUS.lua")

local Triage = { POSITIONS = nil }
_G.Triage = Triage
local refreshCount = 0
function Triage:RefreshConfig()
	refreshCount = refreshCount + 1
end
function Triage:IsTestModeActive() return false end

dofile(repoRoot .. "GUI/GeneralConfigPanel.lua")
dofile(repoRoot .. "GUI/OptionsModel.lua")

local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-------------------------------------------------------------------------
-- Collect both presentations of each option.
-------------------------------------------------------------------------
local OPTIONS = {
	{ key = "showBuffs", label = "Hide Stock Buff Icons", desc = "Hide the standard raid frame buff icons" },
	{ key = "showDebuffs", label = "Hide Stock Debuff Icons", desc = "Hide the standard raid frame debuff icons" },
	{
		key = "showDispellableDebuffs",
		label = "Hide Stock Dispellable Icons",
		desc = "Hide the standard raid frame dispellable icons",
	},
}

Triage.db = { profile = {} }
local generalArgs = Triage:CreateGeneralOptions().args

local modelItems = {}
for _, section in ipairs(Triage.OptionsModel.sections) do
	for _, item in ipairs(section.rows or {}) do
		modelItems[item.key] = item
	end
end

for _, option in ipairs(OPTIONS) do
	-- AceConfig toggle: get(), set(info, value)
	local toggle = assert(generalArgs[option.key], "missing AceConfig toggle " .. option.key)
	assertEqual(toggle.name, option.label, option.key .. " AceConfig label")
	assertEqual(toggle.desc, option.desc, option.key .. " AceConfig desc")

	Triage.db.profile[option.key] = true
	assertEqual(toggle.get(), false, option.key .. " AceConfig get with stored true")
	Triage.db.profile[option.key] = false
	assertEqual(toggle.get(), true, option.key .. " AceConfig get with stored false")

	local before = refreshCount
	toggle.set(nil, true)
	assertEqual(Triage.db.profile[option.key], false, option.key .. " AceConfig set(true) stores false")
	toggle.set(nil, false)
	assertEqual(Triage.db.profile[option.key], true, option.key .. " AceConfig set(false) stores true")
	assertEqual(refreshCount, before + 2, option.key .. " AceConfig set refreshes config")

	-- Native options checkbox: get(), set(value)
	local checkbox = assert(modelItems[option.key], "missing OptionsModel checkbox " .. option.key)
	assertEqual(checkbox.type, "checkbox", option.key .. " model type")
	assertEqual(checkbox.label, option.label, option.key .. " model label")
	assertEqual(checkbox.tooltip, option.desc, option.key .. " model tooltip")

	Triage.db.profile[option.key] = true
	assertEqual(checkbox.get(), false, option.key .. " model get with stored true")
	Triage.db.profile[option.key] = false
	assertEqual(checkbox.get(), true, option.key .. " model get with stored false")

	before = refreshCount
	checkbox.set(true)
	assertEqual(Triage.db.profile[option.key], false, option.key .. " model set(true) stores false")
	checkbox.set(false)
	assertEqual(Triage.db.profile[option.key], true, option.key .. " model set(false) stores true")
	assertEqual(refreshCount, before + 2, option.key .. " model set refreshes config")
end

assertEqual(L["Hide Stock Buff Icons"], "Hide Stock Buff Icons", "locale key present")

print("tri094_hide_stock_icons_checkbox: all assertions passed")
