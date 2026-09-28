-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

-- Import libraries
-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Show the popup that names the target profile for a pasted import. Both
--- import entry points funnel through here.
---@param input string @The pasted export string
function Triage:PromptProfileImport(input)
	-- A stale popup from an earlier import could still act on a name that's
	-- since been taken; close any pending one before starting a new import.
	local hidePopup = rawget(_G, "StaticPopup_Hide")
	if hidePopup then
		hidePopup("TRIAGE_IMPORT_PROFILE_NAME")
		hidePopup("TRIAGE_IMPORT_PROFILE_EXISTS")
	end

	local decoded = self:DeserializeAndDecompressProfile(input)
	if not decoded then
		return
	end

	local showPopup = rawget(_G, "StaticPopup_Show")
	local popupDialogs = rawget(_G, "StaticPopupDialogs")
	if not showPopup or not popupDialogs or not popupDialogs.TRIAGE_IMPORT_PROFILE_NAME then
		self:Print(L["Data import Failed."] .. " " .. L["Aborting."])
		return
	end

	local suggested = self:NextFreeProfileName(L["Imported"])
	local text = L["ImportProfile_NamePrompt"]
	if self.db.IsDualSpecEnabled and self.db:IsDualSpecEnabled() then
		text = text .. "\n\n" .. L["ImportProfile_SpecNote"]
	end
	showPopup("TRIAGE_IMPORT_PROFILE_NAME", text, nil, { profile = decoded, suggested = suggested })
end

--- The single entry point for every accept: re-checks the target name at
--- the moment of acceptance, since a stale popup can outlive the state it
--- was shown for.
---@param name string
---@param decoded table
---@param allowOverwrite boolean
function Triage:TryImportAs(name, decoded, allowOverwrite)
	local taken = rawget(self.db.profiles, name) ~= nil or name == self.db:GetCurrentProfile()
	if taken and not allowOverwrite then
		local altName = self:NextFreeProfileName(name)
		local popupDialogs = rawget(_G, "StaticPopupDialogs")
		if popupDialogs and popupDialogs.TRIAGE_IMPORT_PROFILE_EXISTS then
			popupDialogs.TRIAGE_IMPORT_PROFILE_EXISTS.button2 = L["ImportProfile_UseName"]:format(altName)
		end
		local showPopup = rawget(_G, "StaticPopup_Show")
		if showPopup then
			showPopup("TRIAGE_IMPORT_PROFILE_EXISTS", name, nil, { profile = decoded, name = name, altName = altName })
		end
		return true
	end

	self:ApplyImportedProfile(name, decoded)
	return false
end

-- Shared by the Import button and by pressing Enter in the edit box, so the
-- two can't drift. The edit box auto-focuses as soon as the popup shows
-- (that's the default for edit boxes), so Enter and Escape there are
-- handled by the box itself, not by the dialog's button clicks.
local function acceptImportName(editBox, data)
	local name = editBox:GetText():match("^%s*(.-)%s*$")
	if name == "" then
		return true -- keep the dialog open; an empty name isn't a choice
	end
	Triage:TryImportAs(name, data.profile, false)
	editBox:GetParent():Hide()
end

local popupDialogs = rawget(_G, "StaticPopupDialogs")
if popupDialogs then
	popupDialogs.TRIAGE_IMPORT_PROFILE_NAME = {
		text = "%s",
		button1 = L["Import"],
		button2 = L["Cancel"],
		hasEditBox = 1,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnShow = function(dialog, data)
			local editBox = dialog:GetEditBox()
			editBox:SetText(data.suggested)
			editBox:HighlightText()
		end,
		OnAccept = function(dialog, data)
			return acceptImportName(dialog:GetEditBox(), data)
		end,
		EditBoxOnEnterPressed = acceptImportName,
		EditBoxOnEscapePressed = function(editBox)
			editBox:GetParent():Hide()
		end,
	}

	popupDialogs.TRIAGE_IMPORT_PROFILE_EXISTS = {
		text = L["ImportProfile_Exists"],
		button1 = L["Overwrite"],
		button3 = L["Cancel"],
		selectCallbackByIndex = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnButton1 = function(dialog, data)
			return Triage:TryImportAs(data.name, data.profile, true)
		end,
		OnButton2 = function(dialog, data)
			return Triage:TryImportAs(data.altName, data.profile, false)
		end,
		OnButton3 = function() end,
	}
end

--- Populate our "Profile Import/Export" options table for our Blizzard interface options
function Triage:CreateProfileImportExportOptions()
	local import_export = {
		name = L["Profile"] .. " " .. L["Import"] .. "/" .. L["Export"],
		type = "group",
		order = 1,
		args = {
			Header = {
				order = 1,
				name = L["Profile"] .. " " .. L["Import"] .. "/" .. L["Export"],
				type = "header",
			},
			Instructions = {
				order = 2,
				name = L["ImportExport_Desc"],
				type = "description",
				fontSize = "medium",
			},
			TextBox = {
				order = 3,
				name = L["Import or Export the current profile:"],
				desc = self.RED_COLOR:WrapTextInColorCode(L["ImportExport_WarningDesc"]),
				type = "input",
				multiline = 22,
				validate = false,
					set = function(_, input)
						Triage:PromptProfileImport(input)
					end,
				get = function()
					return Triage:SerializeAndCompressProfile()
				end,
				width = "full",
			},
		},
	}

	return import_export
end
