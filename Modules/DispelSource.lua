-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

local PRIORITY_ORDER = {"Magic", "Curse", "Disease", "Poison", "Bleed"}

Triage.UNKNOWN_DISPEL_TYPE = "unknown-active"

local function IsSecretValue(value)
	return issecretvalue and issecretvalue(value)
end

local function GetLibDispel()
	return LibStub("LibDispel-1.0")
end

local function ReadObjectField(object, key)
	return object[key]
end

local function ReadField(object, key)
	if not object or IsSecretValue(object) then
		return nil
	end

	local ok, value = pcall(ReadObjectField, object, key)
	if not ok or IsSecretValue(value) then
		return nil
	end

	return value
end

local function CallMethod(object, methodName)
	if not object or IsSecretValue(object) then
		return nil, false
	end

	local method = ReadField(object, methodName)
	if type(method) ~= "function" then
		return nil, false
	end

	local ok, result = pcall(method, object)
	if not ok or IsSecretValue(result) then
		return nil, false
	end

	return result, true
end

function Triage:GetDispelCapabilities()
	return {
		supportsBlizzardDispelOverlayState = self.supportsPrivateAuraSuppression == true,
		supportsReadableAuraDispelFields = self.supportsPrivateAuraSuppression and "conditional" or false,
		supportsLibDispelPlayerCapability = true,
		supportsLegacyFrameDispels = not self.supportsPrivateAuraSuppression,
	}
end

local function GetActiveDispelTypeLegacy(frame)
	local frameDispels = ReadField(frame, "dispels")
	if type(frameDispels) ~= "table" then
		return nil
	end

	local myDispels = GetLibDispel():GetMyDispelTypes()
	for _, dispelType in ipairs(PRIORITY_ORDER) do
		if myDispels[dispelType] then
			local pt = ReadField(frameDispels, dispelType)
			local size = pt and CallMethod(pt, "Size")
			if size and size > 0 then
				return dispelType
			end
		end
	end

	return nil
end

local function GetActiveDispelTypeRetail(frame)
	local blizzardOverlay = ReadField(frame, "DispelOverlay")
	local dispelDebuffFrames = ReadField(blizzardOverlay, "dispelDebuffFrames")
	if type(dispelDebuffFrames) ~= "table" then
		return nil
	end

	local readableTypes = {}
	local foundUnknownActive = false
	local myDispels = GetLibDispel():GetMyDispelTypes()

	for _, dispelDebuffFrame in ipairs(dispelDebuffFrames) do
		local aura = ReadField(dispelDebuffFrame, "aura")
		if aura then
			local shown, shownReadable = CallMethod(dispelDebuffFrame, "IsShown")
			if not shownReadable or shown then
				local canDispel = ReadField(aura, "canActivePlayerDispel")
				local dispelType = ReadField(aura, "dispelName")

				if canDispel ~= false then
					if dispelType then
						if myDispels[dispelType] then
							readableTypes[dispelType] = true
						end
					else
						foundUnknownActive = true
					end
				end
			end
		end
	end

	for _, dispelType in ipairs(PRIORITY_ORDER) do
		if readableTypes[dispelType] then
			return dispelType
		end
	end

	if foundUnknownActive then
		return Triage.UNKNOWN_DISPEL_TYPE
	end

	return nil
end

function Triage:GetActiveDispelType(frame)
	local caps = self:GetDispelCapabilities()
	if caps.supportsLegacyFrameDispels then
		return GetActiveDispelTypeLegacy(frame)
	end

	return GetActiveDispelTypeRetail(frame)
end
