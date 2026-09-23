-- luacheck: globals arg dofile LibStub geterrorhandler wipe issecretvalue CreateFrame C_UnitAuras AuraUtil io package
-- TRI-093: Triage's full aura rescan and dispel probe must never call AuraUtil's data-provider
-- entry points, because while Edit Mode is open that provider is Blizzard's sample-aura table.
-- Run from the repository root: lua tests/tri093_direct_aura_walk.lua <repoRoot>

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
-- Minimal globals AuraListeners.lua and DispelSource.lua need at load
-- and call time. Neither module needs the rest of Triage.lua or AceAddon.
-------------------------------------------------------------------------

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

function LibStub(name)
	if name == "LibDispel-1.0" then
		return { GetMyDispelTypes = function() return {} end }
	end
	return {}
end

local reportedErrors = {}
function geterrorhandler()
	return function(err)
		reportedErrors[#reportedErrors + 1] = err
	end
end

local function NewStubListenerFrame()
	return {
		SetParent = function() end,
		UnregisterAllEvents = function() end,
		RegisterUnitEvent = function() end,
		SetScript = function() end,
	}
end

function CreateFrame()
	return NewStubListenerFrame()
end

-- AuraUtil.ForEachAura: a call counter, not a working stub. The whole point of this fix is
-- that neither call site may reach it any more; base (5e56a07) routes the full rescan and the
-- dispel probe through here, so a nonzero count on either row 1 or row 5 pins the regression.
local auraUtilCalls = 0
AuraUtil = {
	ForEachAura = function()
		auraUtilCalls = auraUtilCalls + 1
	end,
}

-- C_UnitAuras: each row installs its own GetAuraSlots/GetAuraDataBySlot to control what the
-- direct walk sees. Declared here so base (which never reads it) and the worktree (which does)
-- both have a table to index without erroring.
C_UnitAuras = {
	GetAuraSlots = function() return nil end,
	GetAuraDataBySlot = function() return nil end,
}

_G.Triage = {
	allAuras = " ",
	isRetail = true,
	supportsUnitAuraPayloads = true,
	supportsPrivateAuraSuppression = true,
	needsLibClassicDurations = false,
	dispelProviderIsSample = false,
	ShouldContinue = function() return true end,
	GetManagedFrameUnit = function(_, frame) return frame.unit end,
	GetManagedChildFrameName = function() return nil end,
	UpdateIndicators = function() end,
}

dofile(repoRoot .. "Modules/AuraListeners.lua")
dofile(repoRoot .. "Modules/DispelSource.lua")

local Triage = _G.Triage

-------------------------------------------------------------------------
-- Row 1: must FAIL against base (5e56a07) -- a full rescan through the entry the SetUnit
-- flush uses must never call AuraUtil.ForEachAura. At base this calls it once per entry in
-- AURA_FILTERS ("HELPFUL", "HARMFUL"), so the assertion fails with "expected 0, got 2".
-------------------------------------------------------------------------

do
	auraUtilCalls = 0
	local frame = { unit = "party1", Triage_unitAuras = {} }
	Triage:UpdateUnitAuras(frame, {}, true)
	assertEqual(auraUtilCalls, 0, "a full rescan through UpdateUnitAuras never calls AuraUtil.ForEachAura")
end

-------------------------------------------------------------------------
-- Row 2: the direct walk delivers every slot across a continuation token, in order.
-------------------------------------------------------------------------

do
	C_UnitAuras = {
		GetAuraSlots = function(_unit, _filter, _maxCount, continuationToken)
			if continuationToken == nil then
				return "page2", 1, 2
			end
			assertEqual(continuationToken, "page2", "the second GetAuraSlots call receives the token the first call returned")
			return nil, 3
		end,
		GetAuraDataBySlot = function(_unit, slot)
			return { slot = slot }
		end,
	}

	local seen = {}
	Triage:ForEachUnitAura("party1", "HELPFUL", function(auraData)
		seen[#seen + 1] = auraData.slot
	end)

	assertEqual(#seen, 3, "the walk delivers all three slots across the continuation token")
	assertEqual(seen[1], 1, "slot 1 is delivered first")
	assertEqual(seen[2], 2, "slot 2 is delivered second")
	assertEqual(seen[3], 3, "slot 3, from the second page, is delivered third")
end

-------------------------------------------------------------------------
-- Row 3: a GetAuraDataBySlot that returns nil for one slot is skipped, no error, the other
-- slots are still delivered.
-------------------------------------------------------------------------

do
	C_UnitAuras = {
		GetAuraSlots = function(_unit, _filter, _maxCount, continuationToken)
			if continuationToken == nil then
				return nil, 1, 2, 3
			end
		end,
		GetAuraDataBySlot = function(_unit, slot)
			if slot == 2 then
				return nil
			end
			return { slot = slot }
		end,
	}

	local seen = {}
	local ok = pcall(Triage.ForEachUnitAura, Triage, "party1", "HELPFUL", function(auraData)
		seen[#seen + 1] = auraData.slot
	end)

	assertTrue(ok, "a nil GetAuraDataBySlot for one slot does not raise an error")
	assertEqual(#seen, 2, "the two resolvable slots are still delivered")
	assertEqual(seen[1], 1, "slot 1 is delivered")
	assertEqual(seen[2], 3, "slot 3 is delivered; slot 2 was skipped")
end

-------------------------------------------------------------------------
-- Row 4: a throwing GetAuraSlots propagates through the site's pcall into the existing
-- rollback branch, same as a denied AuraUtil.ForEachAura did before this change.
-------------------------------------------------------------------------

do
	C_UnitAuras = {
		GetAuraSlots = function()
			error("Auras cannot be accessed when secret while tainted by an addon")
		end,
		GetAuraDataBySlot = function() return nil end,
	}

	local frame = {
		unit = "party1",
		Triage_unitAuras = { existing = { name = "rejuvenation" } },
	}
	Triage:UpdateUnitAuras(frame, {}, true)

	assertEqual(frame.Triage_auraDataRestricted, true, "a throwing GetAuraSlots is treated as a denied scan")
	assertEqual(frame.Triage_unitAurasStale, true, "a throwing GetAuraSlots marks the readable cache stale")
	assertTrue(frame.Triage_unitAuras.existing, "the scan rolls the aura table back to the last-known-good state")
end

-------------------------------------------------------------------------
-- Row 5: DispelSource's probe uses the same direct walk and never AuraUtil; the
-- dispelProviderIsSample guard still short-circuits before touching either.
-------------------------------------------------------------------------

do
	local unitAurasCalls = 0
	Triage.dispelProviderIsSample = false
	C_UnitAuras = {
		GetAuraSlots = function(_unit, _filter, _maxCount, continuationToken)
			unitAurasCalls = unitAurasCalls + 1
			if continuationToken == nil then
				return nil, 1
			end
		end,
		GetAuraDataBySlot = function()
			return { dispelName = "Magic" }
		end,
	}
	auraUtilCalls = 0

	local frame = { unit = "party1" }
	local dispelType = Triage:GetActiveDispelType(frame)
	assertEqual(dispelType, "Magic", "the probe still finds a real dispellable debuff through the direct walk")
	assertTrue(unitAurasCalls > 0, "the probe walks C_UnitAuras directly")
	assertEqual(auraUtilCalls, 0, "the probe never calls AuraUtil.ForEachAura")

	Triage.dispelProviderIsSample = true
	unitAurasCalls = 0
	local unavailable = Triage:GetActiveDispelType(frame)
	assertEqual(unavailable, Triage.DISPEL_STATE_UNAVAILABLE, "the sample-provider guard still returns unavailable")
	assertEqual(unitAurasCalls, 0, "the sample-provider guard never touches C_UnitAuras")
	assertEqual(auraUtilCalls, 0, "the sample-provider guard never touches AuraUtil.ForEachAura")

	Triage.dispelProviderIsSample = false
end

-------------------------------------------------------------------------
-- Row 6: grep invariant -- no non-comment line in a shipped .lua file (excluding Libs/,
-- tests/, dbm-research/, Triage_Dev/, .worktrees/) references AuraUtil, the way the spec's
-- `grep -rn "AuraUtil\." --include=*.lua` invariant does.
-------------------------------------------------------------------------

do
	local isWindows = package.config:sub(1, 1) == "\\"

	-- dir /s /b and find both return fully-qualified paths regardless of whether the pattern
	-- passed in was relative or absolute, so resolve repoRoot to an absolute path first --
	-- otherwise a relative repoRoot (e.g. "./") never matches as a prefix of the listing below.
	local resolveCommand = isWindows
		and ('cd /d "' .. repoRoot .. '" && cd')
		or ('cd "' .. repoRoot .. '" && pwd')
	local resolveHandle = io.popen(resolveCommand)
	local absoluteRoot = resolveHandle and resolveHandle:read("*l")
	if resolveHandle then
		resolveHandle:close()
	end
	assertTrue(absoluteRoot and absoluteRoot ~= "", "repoRoot resolves to an absolute path")

	local listCommand = isWindows
		and ('dir /s /b "' .. absoluteRoot .. '\\*.lua"')
		or ('find "' .. absoluteRoot .. '" -name "*.lua"')

	local handle = io.popen(listCommand)
	assertTrue(handle, "the shipped-file listing command runs")

	-- Exclusions apply to the path relative to repoRoot, not the absolute path: this worktree's
	-- own checkout lives under a ".worktrees" directory in the main checkout, so matching on the
	-- absolute path would exclude every file this test is supposed to be scanning.
	local normalizedRoot = absoluteRoot:gsub("\\", "/") .. "/"
	local excludedSegments = { "/Libs/", "/tests/", "/dbm-research/", "/Triage_Dev/", "/.worktrees/" }
	local function isExcluded(path)
		for _, segment in ipairs(excludedSegments) do
			if path:find(segment, 1, true) then
				return true
			end
		end
		return false
	end

	local offenders = {}
	local filesChecked = 0
	for rawPath in handle:lines() do
		local normalized = rawPath:gsub("\\", "/")
		local relative = normalized
		if normalized:sub(1, #normalizedRoot) == normalizedRoot then
			relative = normalized:sub(#normalizedRoot + 1)
		end
		relative = "/" .. relative
		if rawPath ~= "" and not isExcluded(relative) then
			local file = io.open(rawPath, "r")
			if file then
				filesChecked = filesChecked + 1
				for line in file:lines() do
					local codePart = line:match("^(.-)%-%-") or line
					if codePart:find("AuraUtil.", 1, true) then
						offenders[#offenders + 1] = rawPath
						break
					end
				end
				file:close()
			end
		end
	end
	handle:close()

	assertTrue(filesChecked > 10, "the invariant actually scanned shipped files, not an empty listing")
	assertEqual(#offenders, 0,
		"no shipped file outside Libs/tests/dbm-research/Triage_Dev/.worktrees calls AuraUtil.: " .. table.concat(offenders, ", "))
end

print("tri093_direct_aura_walk: PASS")
