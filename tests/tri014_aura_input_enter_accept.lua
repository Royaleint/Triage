-- luacheck: globals package dofile CreateFrame UIParent MouseIsOver strtrim LibStub
package.path = package.path .. ";./?.lua;./?/init.lua"

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function noop() end

local frameMethods = {}
frameMethods.__index = frameMethods

function frameMethods:GetObjectType()
    return self.objectType
end

function frameMethods:GetChildren()
    return unpack(self.children or {})
end

function frameMethods:CreateTexture()
    local texture = setmetatable({ objectType = "Texture", children = {}, scripts = {}, parent = self }, frameMethods)
    return texture
end

function frameMethods:CreateFontString()
    local font = setmetatable({ objectType = "FontString", children = {}, scripts = {}, parent = self }, frameMethods)
    return font
end

function frameMethods:SetScript(scriptName, handler)
    self.scripts[scriptName] = handler
end

function frameMethods:HookScript(scriptName, handler)
    local previous = self.scripts[scriptName]
    if previous then
        self.scripts[scriptName] = function(...)
            previous(...)
            handler(...)
        end
    else
        self.scripts[scriptName] = handler
    end
end

function frameMethods:Trigger(scriptName, ...)
    local handler = self.scripts[scriptName]
    if handler then
        return handler(self, ...)
    end
end

function frameMethods:SetText(text)
    self.text = tostring(text or "")
    self.cursor = #self.text
end

function frameMethods:GetText()
    return self.text or ""
end

function frameMethods:Insert(value)
    value = tostring(value or "")
    local text = self:GetText()
    if self.highlightStart ~= nil and self.highlightEnd ~= nil then
        local startPos = self.highlightStart
        local endPos = self.highlightEnd
        self.text = text:sub(1, startPos) .. value .. text:sub(endPos + 1)
        self.cursor = startPos + #value
        self.highlightStart = nil
        self.highlightEnd = nil
        return
    end

    local cursor = self.cursor or #text
    self.text = text:sub(1, cursor) .. value .. text:sub(cursor + 1)
    self.cursor = cursor + #value
end

function frameMethods:HighlightText(startPos, endPos)
    self.highlightStart = startPos
    self.highlightEnd = endPos
end

function frameMethods:SetFocus()
    self.focused = true
end

function frameMethods:ClearFocus()
    self.focused = false
end

function frameMethods:HasFocus()
    return self.focused and true or false
end

function frameMethods:SetCursorPosition(position)
    self.cursor = position
end

function frameMethods:GetCursorPosition()
    return self.cursor or #self:GetText()
end

function frameMethods:GetNumLetters()
    return #self:GetText()
end

function frameMethods:Show()
    self.shown = true
end

function frameMethods:Hide()
    self.shown = false
end

function frameMethods:IsShown()
    return self.shown and true or false
end

function frameMethods:SetShown(value)
    self.shown = value and true or false
end

function frameMethods:GetWidth()
    return self.width or 300
end

function frameMethods:SetWidth(width)
    self.width = width
end

function frameMethods:SetHeight(height)
    self.height = height
end

function frameMethods:SetSize(width, height)
    self.width = width
    self.height = height
end

function frameMethods:SetParent(parent)
    self.parent = parent
end

function frameMethods:SetPoint(...) self.lastPoint = {...} end
function frameMethods:ClearAllPoints() self.pointsCleared = true end
function frameMethods:SetFrameStrata(value) self.frameStrata = value end
function frameMethods:SetColorTexture(...) self.color = {...} end
function frameMethods:SetTexture(value) self.texture = value end
function frameMethods:SetAllPoints() end
function frameMethods:SetJustifyH(value) self.justifyH = value end
function frameMethods:SetFontObject(value) self.fontObject = value end
function frameMethods:SetTextInsets(...) self.textInsets = {...} end
function frameMethods:SetMaxLetters(value) self.maxLetters = value end
function frameMethods:SetMultiLine(value) self.multiLine = value end
function frameMethods:SetAutoFocus(value) self.autoFocus = value end
function frameMethods:EnableMouse(value) self.mouseEnabled = value end

function CreateFrame(objectType, name, parent)
    local frame = setmetatable({
        objectType = objectType,
        name = name,
        parent = parent,
        children = {},
        scripts = {},
        shown = false,
        text = "",
    }, frameMethods)
    if parent and parent.children then
        parent.children[#parent.children + 1] = frame
    end
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")

function MouseIsOver()
    return false
end

function strtrim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

LibStub = function()
    return {
        GetLocale = function()
            return setmetatable({
                ["Wildcard"] = "Wildcard",
                ["Inactive wildcard"] = "Inactive wildcard",
                ["Recognized"] = "Recognized",
                ["Unknown spell ID"] = "Unknown spell ID",
                ["Did you mean format"] = "Did you mean %s?",
                ["Unverified entry"] = "Unverified entry",
                ["More entries format"] = "+%d more (%d flagged)",
            }, { __index = function(_, key) return key end })
        end,
    }
end

_G.Triage = {
    OptionsControls = {},
    SpellLookup = {},
    ScheduleTimer = function(_, callback)
        callback()
        return 1
    end,
    CancelTimer = noop,
}

local Controls = _G.Triage.OptionsControls

function Controls.CreateMultiline(parent, row)
    local frame = CreateFrame("Frame", nil, parent)
    local editBox = CreateFrame("EditBox", nil, frame)
    editBox:SetText(row.get and row.get() or "")
    frame.triageRefresh = function()
        editBox:SetText(row.get and row.get() or "")
    end
    return frame
end

function _G.Triage.SpellLookup.ResolveToken(rawLine)
    if rawLine and rawLine ~= "" then
        return { kind = "unverified", name = rawLine }
    end
end

function _G.Triage.SpellLookup.Suggest(prefix)
    if strtrim(prefix):lower() == "rejuv" then
        return {{ name = "Rejuvenation", icon = 134914, spellID = 774 }}
    end
    return {}
end

local savedText = ""
local parent = CreateFrame("Frame", nil, UIParent)
local row = {
    height = 280,
    get = function() return savedText end,
    onTextChanged = function(value) savedText = value end,
}

dofile("GUI/AuraInputControl.lua")

local control = Controls.CreateAuraInput(parent, row, noop)
local editBox = control.children[1]

editBox:SetFocus()
editBox:SetText("Rejuv")
editBox:SetCursorPosition(5)
editBox:Trigger("OnTextChanged", true)

assertTruthy(editBox.scripts.OnEnterPressed, "aura input should install OnEnterPressed")
editBox:Trigger("OnEnterPressed")

assertEquals(editBox:GetText(), "Rejuvenation", "Enter should accept the visible suggestion")
assertEquals(savedText, "Rejuvenation", "Enter accept should persist through row.onTextChanged")

editBox:SetText("Magic")
savedText = "Magic"
editBox:SetCursorPosition(5)
editBox:Trigger("OnEnterPressed")

assertEquals(editBox:GetText(), "Magic\n", "Enter should remain newline when no suggestion popup is visible")
assertEquals(savedText, "Magic\n", "newline fallback should persist through row.onTextChanged")

print("tri014_aura_input_enter_accept: PASS")
