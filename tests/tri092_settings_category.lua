-- luacheck: globals arg dofile CreateFrame UIParent CreateDataProvider CreateScrollBoxListLinearView ScrollUtil LibStub InCombatLockdown Settings CreateSettingsButtonInitializer InterfaceOptions_AddCategory geterrorhandler
-- TRI-092: the Settings panel reads fields on every canvas frame when it
-- closes, on the same execution that then re-shows Edit Mode, so Triage must
-- never hand the Settings panel a frame of its own. It registers a plain
-- category with one button instead, and once that button-category API is
-- present, a failure there must never fall back to handing the panel a
-- frame after all.

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

-------------------------------------------------------------------------
-- Native options frame plumbing (matches tests/tri054_options_refresh.lua),
-- so OptionsFrame:Initialize() can build its shell without erroring.
-------------------------------------------------------------------------

local function noop() end
local scrollBoxes = {}
local settingsPanelFrameCreations = 0

local function makeRegion()
	return {
		SetPoint = noop, SetWidth = noop, SetHeight = noop, SetSize = noop,
		SetJustifyH = noop, SetText = noop, SetTextColor = noop, SetColorTexture = noop,
		SetAllPoints = noop, ClearAllPoints = noop, Hide = noop, Show = noop, SetShown = noop,
	}
end

local function makeFrame()
	local frame = { scripts = {}, shown = false }
	function frame:CreateTexture() return makeRegion() end
	function frame:CreateFontString() return makeRegion() end
	function frame:SetPoint(...) self.point = { ... } end
	function frame:ClearAllPoints() self.point = nil end
	function frame:SetAllPoints(...) self.allPoints = { ... } end
	function frame:SetParent(parent) self.parent = parent end
	function frame:SetHeight(height) self.height = height end
	function frame:SetWidth(width) self.width = width end
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:GetWidth() return self.width or 760 end
	function frame:GetHeight() return self.height or 560 end
	function frame:SetFrameStrata() end
	function frame:SetToplevel() end
	function frame:SetMovable() end
	function frame:EnableMouse() end
	function frame:SetClampedToScreen() end
	function frame:SetResizable() end
	function frame:SetResizeBounds() end
	function frame:RegisterForDrag() end
	function frame:SetNormalTexture() end
	function frame:SetHighlightTexture() end
	function frame:SetPushedTexture() end
	function frame:SetScript(event, callback) self.scripts[event] = callback end
	function frame:HookScript(event, callback) self.scripts[event] = callback end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:IsShown() return self.shown end
	function frame:Raise() end
	function frame:SetAlpha() end
	function frame:SetText() end
	function frame:SetEnabled() end
	function frame:Enable() end
	function frame:Disable() end
	return frame
end

rawset(_G, "UIParent", makeFrame())
rawset(_G, "CreateFrame", function(_, name, _, template)
	local frame = makeFrame()
	if template == "WowScrollBoxList" then
		scrollBoxes[#scrollBoxes + 1] = frame
	end
	if name == "TriageSettingsPanel" then
		settingsPanelFrameCreations = settingsPanelFrameCreations + 1
	end
	return frame
end)

rawset(_G, "CreateDataProvider", function()
	local provider = { entries = {} }
	function provider:Insert(row) self.entries[#self.entries + 1] = row end
	return provider
end)

rawset(_G, "CreateScrollBoxListLinearView", function()
	local view = {}
	function view:SetElementExtentCalculator(callback) self.extentCalculator = callback end
	function view:SetElementFactory(callback) self.elementFactory = callback end
	return view
end)

rawset(_G, "ScrollUtil", {
	InitScrollBoxListWithScrollBar = function(scrollBox, _, view)
		scrollBox.view = view
		function scrollBox:SetDataProvider(provider, retainScrollPosition)
			self.setDataProviderCalls = (self.setDataProviderCalls or 0) + 1
			self.provider = provider
			if not retainScrollPosition then
				self.offset = 0
			end
			self.frames = {}
			for _, row in ipairs(provider.entries) do
				local rowFrame = makeFrame()
				local factory = setmetatable({}, { __call = function(_, _, initialize)
					initialize(rowFrame)
				end })
				view.elementFactory(factory, row)
				self.frames[#self.frames + 1] = rowFrame
			end
		end
		function scrollBox:ForEachFrame(callback)
			for _, rowFrame in ipairs(self.frames or {}) do
				callback(rowFrame)
			end
		end
	end,
})

function InCombatLockdown()
	return false
end

local errorHandlerMessages = {}
function geterrorhandler()
	return function(err)
		errorHandlerMessages[#errorHandlerMessages + 1] = err
	end
end

-------------------------------------------------------------------------
-- Ace3 stubs: enough for Triage.lua's module-scope LibStub calls and for
-- InitializeConfigPanels to run without touching the real Ace3 libs.
-------------------------------------------------------------------------

local addon = {}
local addToBlizOptionsCalls = 0
local registeredOptionsTables = {}

local aceConfigDialog = {
	OpenFrames = {},
	AddToBlizOptions = function()
		addToBlizOptionsCalls = addToBlizOptionsCalls + 1
	end,
	Open = function() end,
}

local aceConfigRegistry = {
	RegisterOptionsTable = function(_, name, optionsTable)
		registeredOptionsTables[name] = optionsTable
	end,
}

local aceDBOptions = {
	GetOptionsTable = function() return {} end,
}

function LibStub(name)
	if name == "AceAddon-3.0" then
		return { NewAddon = function() return addon end }
	elseif name == "AceLocale-3.0" then
		return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
	elseif name == "AceDBOptions-3.0" then
		return aceDBOptions
	elseif name == "AceConfigRegistry-3.0" then
		return aceConfigRegistry
	elseif name == "AceConfigDialog-3.0" then
		return aceConfigDialog
	elseif name == "AceDB-3.0" then
		return { New = function() return {} end }
	end
	return {}
end

-------------------------------------------------------------------------
-- Settings API stubs (Retail button-category path plus the canvas and
-- legacy fallbacks).
-------------------------------------------------------------------------

local registerVerticalCalls = {}
local registerInitializerCalls = {}
local addOnCategoryCalls = {}
local registerCanvasCalls = {}
local openToCategoryCalls = {}
local buttonInitializerCalls = {}
local directAddInitializerCalls = 0
local interfaceOptionsAddCategoryCalls = 0
local nextCategoryID = 0

local function makeCategory()
	nextCategoryID = nextCategoryID + 1
	local id = nextCategoryID
	return { GetID = function() return id end }
end

local function makeLayout()
	local layout = {}
	function layout:AddInitializer()
		directAddInitializerCalls = directAddInitializerCalls + 1
	end
	return layout
end

local settingsStub = {
	RegisterVerticalLayoutCategory = function(name)
		local category = makeCategory()
		local layout = makeLayout()
		registerVerticalCalls[#registerVerticalCalls + 1] = { name = name, category = category, layout = layout }
		return category, layout
	end,
	RegisterInitializer = function(category, initializer)
		registerInitializerCalls[#registerInitializerCalls + 1] = { category = category, initializer = initializer }
	end,
	RegisterAddOnCategory = function(category)
		addOnCategoryCalls[#addOnCategoryCalls + 1] = category
	end,
	RegisterCanvasLayoutCategory = function(panelFrame, name)
		registerCanvasCalls[#registerCanvasCalls + 1] = { frame = panelFrame, name = name }
		return makeCategory()
	end,
	OpenToCategory = function(categoryID)
		openToCategoryCalls[#openToCategoryCalls + 1] = categoryID
	end,
}
rawset(_G, "Settings", settingsStub)

local function workingButtonInitializer(name, buttonText, buttonClick, tooltip, addSearchTags, newTagID, gameDataFunc, gameDataEvent)
	local initializer = {
		name = name,
		buttonText = buttonText,
		buttonClick = buttonClick,
		tooltip = tooltip,
		addSearchTags = addSearchTags,
		newTagID = newTagID,
		gameDataFunc = gameDataFunc,
		gameDataEvent = gameDataEvent,
	}
	buttonInitializerCalls[#buttonInitializerCalls + 1] = initializer
	return initializer
end
rawset(_G, "CreateSettingsButtonInitializer", workingButtonInitializer)

rawset(_G, "InterfaceOptions_AddCategory", function()
	interfaceOptionsAddCategoryCalls = interfaceOptionsAddCategoryCalls + 1
end)

-------------------------------------------------------------------------
-- Load the real files under test.
-------------------------------------------------------------------------

dofile(repoRoot .. "Triage.lua")
dofile(repoRoot .. "GUI/OptionsFrame.lua")

local Triage = _G.Triage
Triage.db = { profile = {} }
Triage.CreateGeneralOptions = function() return {} end
Triage.CreateIndicatorOptions = function() return {} end
Triage.CreateIconOptions = function() return {} end
Triage.CreateProfileImportExportOptions = function() return {} end

Triage.OptionsModel = {
	GetSections = function()
		return { { key = "general", label = "General", rows = { { key = "status", type = "status" } } } }
	end,
	GetSection = function(_, key)
		return { key = key, label = "General", rows = { { key = "status", type = "status" } } }
	end,
}

local function refreshControl()
	local control = makeFrame()
	control.triageRefresh = noop
	return control
end

Triage.OptionsControls = {
	CreateHeader = refreshControl,
	CreateDescription = refreshControl,
	CreateStatus = refreshControl,
}

-------------------------------------------------------------------------
-- Row 1: must FAIL against 2697e95 -- InitializeConfigPanels no longer
-- hands a canvas frame to the Blizzard interface options.
-------------------------------------------------------------------------

Triage:InitializeConfigPanels()

assertEqual(addToBlizOptionsCalls, 0, "AddToBlizOptions is never called")
assertEqual(#registerCanvasCalls, 0, "RegisterCanvasLayoutCategory is never called")
assertTrue(registeredOptionsTables["Triage"] ~= nil, "the general options table still registers with AceConfigRegistry")

-------------------------------------------------------------------------
-- Row 2: exactly one button category registration, routed through
-- Settings.RegisterInitializer (never a direct layout:AddInitializer call),
-- addSearchTags is false.
-------------------------------------------------------------------------

assertEqual(#registerVerticalCalls, 1, "RegisterVerticalLayoutCategory is called exactly once")
assertEqual(registerVerticalCalls[1].name, "Triage", "the category is registered under the name Triage")
assertEqual(directAddInitializerCalls, 0, "layout:AddInitializer is never called directly from Triage's execution")

assertEqual(#buttonInitializerCalls, 1, "CreateSettingsButtonInitializer is called exactly once")
assertEqual(#registerInitializerCalls, 1, "Settings.RegisterInitializer is called exactly once")
assertEqual(registerInitializerCalls[1].category, registerVerticalCalls[1].category,
	"Settings.RegisterInitializer receives the registered category")
assertEqual(registerInitializerCalls[1].initializer, buttonInitializerCalls[1],
	"Settings.RegisterInitializer receives the button initializer")

assertEqual(#addOnCategoryCalls, 1, "RegisterAddOnCategory is called exactly once")
assertEqual(addOnCategoryCalls[1], registerVerticalCalls[1].category, "RegisterAddOnCategory receives the registered category")

assertTrue(buttonInitializerCalls[1].addSearchTags ~= nil, "addSearchTags must never be nil")
assertEqual(buttonInitializerCalls[1].addSearchTags, false, "addSearchTags is false, not nil")

-------------------------------------------------------------------------
-- Row 3: the button click opens the Triage config window.
-------------------------------------------------------------------------

local openConfigWindowCalls = 0
Triage.OpenConfigWindow = function()
	openConfigWindowCalls = openConfigWindowCalls + 1
end

buttonInitializerCalls[1].buttonClick()
assertEqual(openConfigWindowCalls, 1, "the button click calls Triage:OpenConfigWindow() exactly once")

-------------------------------------------------------------------------
-- Row 4: the dead OpenBlizzardOptions function is gone, with no replacement.
-------------------------------------------------------------------------

assertEqual(Triage.OpenBlizzardOptions, nil, "Triage.OpenBlizzardOptions no longer exists")
assertEqual(Triage.OptionsFrame.OpenBlizzardOptions, nil, "OptionsFrame.OpenBlizzardOptions was never added")

-------------------------------------------------------------------------
-- Row 5: registration is idempotent.
-------------------------------------------------------------------------

local verticalCallsBeforeRepeat = #registerVerticalCalls
local addOnCallsBeforeRepeat = #addOnCategoryCalls

Triage.OptionsFrame:RegisterSettingsCategory()

assertEqual(#registerVerticalCalls, verticalCallsBeforeRepeat, "a second RegisterSettingsCategory call registers no new vertical category")
assertEqual(#addOnCategoryCalls, addOnCallsBeforeRepeat, "a second RegisterSettingsCategory call registers no new AddOn category")

-------------------------------------------------------------------------
-- Row 4b: must FAIL on a fallback keyed on pcall success. When the
-- button-category globals are present but the registration attempt itself
-- throws, nothing else is registered -- no canvas fallback, no legacy
-- fallback, no TriageSettingsPanel frame -- and the error is reported once
-- through geterrorhandler().
-------------------------------------------------------------------------

rawset(_G, "CreateSettingsButtonInitializer", function()
	error("tri092 test: CreateSettingsButtonInitializer failed")
end)

dofile(repoRoot .. "GUI/OptionsFrame.lua")

local canvasCallsBefore4b = #registerCanvasCalls
local legacyCallsBefore4b = interfaceOptionsAddCategoryCalls
local panelCreationsBefore4b = settingsPanelFrameCreations
local errorHandlerCallsBefore4b = #errorHandlerMessages

Triage.OptionsFrame:RegisterSettingsCategory()

assertEqual(#registerCanvasCalls, canvasCallsBefore4b,
	"a failed button-category registration never falls back to RegisterCanvasLayoutCategory")
assertEqual(interfaceOptionsAddCategoryCalls, legacyCallsBefore4b,
	"a failed button-category registration never falls back to InterfaceOptions_AddCategory")
assertEqual(settingsPanelFrameCreations, panelCreationsBefore4b,
	"a failed button-category registration never creates a TriageSettingsPanel frame")
assertEqual(#errorHandlerMessages, errorHandlerCallsBefore4b + 1,
	"a failed button-category registration reports through geterrorhandler exactly once")

rawset(_G, "CreateSettingsButtonInitializer", workingButtonInitializer)

-------------------------------------------------------------------------
-- Row 4c: the canvas and legacy fallbacks, keyed on which globals are
-- present at load, not on any earlier failure.
-------------------------------------------------------------------------

-- Path (b): RegisterCanvasLayoutCategory present, no CreateSettingsButtonInitializer.
rawset(_G, "CreateSettingsButtonInitializer", nil)

dofile(repoRoot .. "GUI/OptionsFrame.lua")

local canvasCallsBefore4c = #registerCanvasCalls
Triage.OptionsFrame:RegisterSettingsCategory()

assertEqual(#registerCanvasCalls, canvasCallsBefore4c + 1, "path (b) registers the plain canvas panel exactly once")
local canvasPanel = registerCanvasCalls[#registerCanvasCalls].frame
assertEqual(canvasPanel.OnCommit, nil, "the plain canvas panel defines no OnCommit")
assertEqual(canvasPanel.OnRefresh, nil, "the plain canvas panel defines no OnRefresh")
assertEqual(canvasPanel.OnDefault, nil, "the plain canvas panel defines no OnDefault")

-- Path (c): no Settings at all, InterfaceOptions_AddCategory present.
rawset(_G, "Settings", nil)

dofile(repoRoot .. "GUI/OptionsFrame.lua")

local legacyCallsBefore4c = interfaceOptionsAddCategoryCalls
Triage.OptionsFrame:RegisterSettingsCategory()

assertEqual(interfaceOptionsAddCategoryCalls, legacyCallsBefore4c + 1, "path (c) registers through the legacy call exactly once")

-- Restore the full Retail shape for row 6.
rawset(_G, "Settings", settingsStub)
rawset(_G, "CreateSettingsButtonInitializer", workingButtonInitializer)

-------------------------------------------------------------------------
-- Row 6: a Classic-shaped client (no native options frame support, Settings
-- still present) still gets the category and button.
-------------------------------------------------------------------------

rawset(_G, "CreateScrollBoxListLinearView", nil)
rawset(_G, "CreateDataProvider", nil)
rawset(_G, "ScrollUtil", nil)
assertTrue(not Triage:SupportsNativeOptionsFrame(), "the Classic-shaped stub reports no native options frame support")

dofile(repoRoot .. "GUI/OptionsFrame.lua")

local classicVerticalCallsBefore = #registerVerticalCalls
local classicAddOnCallsBefore = #addOnCategoryCalls

Triage.OptionsFrame:RegisterSettingsCategory()

assertEqual(#registerVerticalCalls, classicVerticalCallsBefore + 1,
	"a Classic-shaped client with Settings present still registers the vertical category")
assertEqual(#addOnCategoryCalls, classicAddOnCallsBefore + 1,
	"a Classic-shaped client with Settings present still registers the AddOn category")

print("tri092_settings_category: PASS")
