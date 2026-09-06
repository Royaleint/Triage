-- luacheck: globals arg dofile CreateFrame UIParent CreateDataProvider CreateScrollBoxListLinearView ScrollUtil
-- TRI-054: settings writes refresh visible controls without replacing the
-- ScrollBox provider, which would reset the user to the top mid-interaction.

local repoRoot = arg[1] or "./"
if repoRoot:sub(-1) ~= "/" and repoRoot:sub(-1) ~= "\\" then
	repoRoot = repoRoot .. "/"
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function noop() end
local scrollBoxes = {}

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
rawset(_G, "CreateFrame", function(_, _, _, template)
	local frame = makeFrame()
	if template == "WowScrollBoxList" then
		scrollBoxes[#scrollBoxes + 1] = frame
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

local refreshes = 0
local function makeControl()
	local control = makeFrame()
	control.triageRefresh = function()
		refreshes = refreshes + 1
	end
	return control
end

_G.Triage = {
	db = { profile = {} },
	OptionsControls = {
		CreateHeader = makeControl,
		CreateDescription = makeControl,
		CreateStatus = makeControl,
	},
	OptionsModel = {
		GetSections = function()
			return { { key = "general", label = "General", rows = { { key = "status", type = "status" } } } }
		end,
		GetSection = function(_, key)
			return { key = key, label = "General", rows = { { key = "status", type = "status" } } }
		end,
	},
	SupportsNativeOptionsFrame = function() return true end,
}

dofile(repoRoot .. "GUI/OptionsFrame.lua")

_G.Triage.OptionsFrame:Open("general")
local scrollBox = scrollBoxes[1]
assertEqual(scrollBox.setDataProviderCalls, 1, "opening the section installs its provider once")
scrollBox.offset = 137
local activeChild = scrollBox.frames[2].triageOptionsChild
activeChild.dragging = true
local refreshesBefore = refreshes

_G.Triage.OptionsFrame:Refresh()

assertEqual(scrollBox.setDataProviderCalls, 1, "refresh does not replace the active section provider")
assertEqual(scrollBox.offset, 137, "refresh retains the user's scroll position")
assertEqual(scrollBox.frames[2].triageOptionsChild, activeChild, "refresh retains the active control")
assertEqual(activeChild.dragging, true, "refresh does not interrupt an active slider interaction")
assertEqual(refreshes, refreshesBefore + 2, "refresh updates each visible control for dependent state")

print("tri054_options_refresh: PASS")
