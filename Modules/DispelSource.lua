-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type Triage
local Triage = _G.Triage

local PRIORITY_ORDER = {"Magic", "Curse", "Disease", "Poison", "Bleed"}

Triage.UNKNOWN_DISPEL_TYPE = "unknown-active"
-- Returned when the Retail probe cannot answer at all (denied query or Edit Mode's
-- sample aura provider active), as distinct from a probe that ran and found nothing.
Triage.DISPEL_STATE_UNAVAILABLE = "unavailable"

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

-- Positive query only: never reads Blizzard's overlay textures or frame state, because
-- Blizzard's own dispel stream sets a debuff icon's aura reference once and never clears it,
-- so a hidden texture can still carry a stale value -- that stale read is exactly the bug this
-- probe replaces. "HARMFUL|RAID" is the engine's own player-dispellable filter (AuraUtil.lua),
-- narrower than "HARMFUL|RAID_PLAYER_DISPELLABLE" -- the engine already gates on "this player
-- can dispel", so LibDispel:GetMyDispelTypes() is not used as a second presence gate here.
--
-- readableTypes/foundUnknownActive are file-local scratch state, wiped and reused each call,
-- and the callback below is hoisted to a file-local function instead of built fresh per call,
-- for the same reason AURA_FILTERS is hoisted in AuraListeners.lua: UNIT_AURA-driven calls are
-- hot enough that a fresh table and closure per call is avoidable allocation. Because that state
-- is shared, DispelProbeCallback must never call back into Triage or anything else that could
-- re-enter the probe while it is running.
local readableTypes = {}
local foundUnknownActive = false

local function DispelProbeCallback(auraData)
	local dispelName = auraData.dispelName
	if IsSecretValue(dispelName) then
		foundUnknownActive = true
		return
	end

	if dispelName and dispelName ~= "" then
		readableTypes[dispelName] = true
	else
		foundUnknownActive = true
	end
end

local function GetActiveDispelTypeRetail(frame)
	if Triage.dispelProviderIsSample then
		return Triage.DISPEL_STATE_UNAVAILABLE
	end

	local unit = Triage:GetManagedFrameUnit(frame)
	if not unit then
		return nil
	end

	wipe(readableTypes)
	foundUnknownActive = false

	-- Direct C_UnitAuras walk, not AuraUtil.ForEachAura: see ForEachUnitAura in
	-- AuraListeners.lua for why this probe stays off Edit Mode's sample aura provider.
	local ok = pcall(Triage.ForEachUnitAura, Triage, unit, "HARMFUL|RAID", DispelProbeCallback)

	if not ok then
		return Triage.DISPEL_STATE_UNAVAILABLE
	end

	for _, dispelType in ipairs(PRIORITY_ORDER) do
		if readableTypes[dispelType] then
			return dispelType
		end
	end

	-- Present, and either the type could not be read at all, or it read fine but isn't one of
	-- the five priority types: either way something is positively there, so this reports the
	-- neutral sentinel rather than falling through to nil.
	if foundUnknownActive or next(readableTypes) then
		return Triage.UNKNOWN_DISPEL_TYPE
	end

	return nil
end

function Triage:GetActiveDispelType(frame)
	if not self.supportsPrivateAuraSuppression then
		return GetActiveDispelTypeLegacy(frame)
	end

	return GetActiveDispelTypeRetail(frame)
end
