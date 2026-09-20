-- luacheck: globals arg debug dofile LibStub geterrorhandler C_Timer wipe

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

-- Timer stub: queues callbacks so each row controls when they fire.
local timerQueue = {}
local timersScheduled = 0
C_Timer = {
	After = function(_, callback)
		timersScheduled = timersScheduled + 1
		timerQueue[#timerQueue + 1] = callback
	end,
}

local function fireTimers()
	local queue = timerQueue
	timerQueue = {}
	for _, callback in ipairs(queue) do
		callback()
	end
end

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

local reportedErrors = {}
function geterrorhandler()
	return function(err)
		reportedErrors[#reportedErrors + 1] = err
	end
end

local addon = {}
function LibStub()
	return {
		NewAddon = function()
			return addon
		end,
		GetLocale = function()
			return {}
		end,
	}
end

dofile(repoRoot .. "Triage.lua")

-- Call log for the body calls the hook must not make synchronously.
local calls = {}
local gateResult = true

local function resetState()
	calls = {}
	gateResult = true
	timerQueue = {}
	timersScheduled = 0
	reportedErrors = {}
end

local hookCallback
local function installHook(legacy)
	addon.usesLegacyUnitAura = legacy
	hookCallback = nil
	addon.ShouldContinue = function(frame, flag)
		calls[#calls + 1] = { "ShouldContinue", frame, flag }
		return gateResult
	end
	addon.UpdateManagedFrameUnit = function(_, frame, unit, source)
		calls[#calls + 1] = { "UpdateManagedFrameUnit", frame, unit, source }
	end
	addon.InvalidateSecureAuraIndicators = function(_, frame)
		calls[#calls + 1] = { "InvalidateSecureAuraIndicators", frame }
	end
	addon.UpdateStockAuraVisibility = function(_, frame)
		calls[#calls + 1] = { "UpdateStockAuraVisibility", frame }
	end
	addon.ClearIndicator = function(_, indicator)
		calls[#calls + 1] = { "ClearIndicator", indicator }
	end
	addon.UpdateUnitAuras = function(_, frame, payload, forced)
		calls[#calls + 1] = { "UpdateUnitAuras", frame, payload, forced }
	end
	addon.UpdateUnitAuras_Classic = function(_, frame, forced)
		calls[#calls + 1] = { "UpdateUnitAuras_Classic", frame, forced }
	end
	addon.UpdateTargetMarker = function(_, frame)
		calls[#calls + 1] = { "UpdateTargetMarker", frame }
	end
	addon.SecureHook = function(_, name, callback)
		if name == "CompactUnitFrame_SetUnit" then
			hookCallback = callback
		end
	end
	addon.RegisterChatCommand = function() end
	addon.RefreshManagedFrameRegistry = function() end
	addon.RefreshConfig = function() end
	addon.UpdateAllAuras = function() end
	addon.RegisterBucketEvent = function() end
	addon.RegisterEvent = function() end

	rawset(_G, "CompactUnitFrame_SetUnit", function() end)
	addon:OnEnable()
	assert(hookCallback, "SetUnit hook was not installed")
end

local function countCalls(name)
	local n = 0
	for _, entry in ipairs(calls) do
		if entry[1] == name then
			n = n + 1
		end
	end
	return n
end

local function NewFrame(unit)
	return { unit = unit, displayedUnit = unit, Triage_indicatorFrames = { "ind1" } }
end

-- Row 1: Retail hook runs none of the body synchronously.
resetState()
installHook(false)
local frame = NewFrame("party1")
hookCallback(frame, "party1")
assertEqual(#calls, 0, "no body call may run before the timer fires")
assertEqual(timersScheduled, 1, "hook schedules one timer")

-- Row 2: fire-time unit wins over the hook argument.
frame.displayedUnit = "party2"
fireTimers()
assertEqual(countCalls("UpdateManagedFrameUnit"), 1, "body runs once")
assertEqual(calls[1][3], "party2", "UpdateManagedFrameUnit uses fire-time unit")
assertEqual(calls[1][4], "blizzard", "source unchanged")
local expectedOrder = {
	"UpdateManagedFrameUnit",
	"InvalidateSecureAuraIndicators",
	"UpdateStockAuraVisibility",
	"ShouldContinue",
	"ClearIndicator",
	"UpdateUnitAuras",
}
assertEqual(#calls, #expectedOrder, "body call count (no marker frame, so no marker refresh)")
for i, name in ipairs(expectedOrder) do
	assertEqual(calls[i][1], name, "body call order at position " .. i)
end
assertEqual(calls[6][4], true, "aura scan is forced")
assertEqual(countCalls("UpdateUnitAuras_Classic"), 0, "Retail does not use the Classic scan")

-- Row 3: bursts coalesce.
resetState()
installHook(false)
frame = NewFrame("party1")
hookCallback(frame, "party1")
hookCallback(frame, "party1")
hookCallback(frame, "party1")
assertEqual(timersScheduled, 1, "burst on one frame schedules one timer")
fireTimers()
assertEqual(countCalls("UpdateManagedFrameUnit"), 1, "burst on one frame runs body once")

resetState()
installHook(false)
local frameA, frameB = NewFrame("party1"), NewFrame("party2")
hookCallback(frameA, "party1")
hookCallback(frameB, "party2")
assertEqual(timersScheduled, 1, "two frames share one timer")
fireTimers()
assertEqual(countCalls("UpdateManagedFrameUnit"), 2, "both frames processed")
local seen = {}
for _, entry in ipairs(calls) do
	if entry[1] == "UpdateManagedFrameUnit" then
		seen[entry[2]] = entry[3]
	end
end
assertEqual(seen[frameA], "party1", "frame A unit")
assertEqual(seen[frameB], "party2", "frame B unit")

-- A second burst after the flush schedules a fresh timer.
hookCallback(frameA, "party1")
assertEqual(timersScheduled, 2, "flag cleared after flush so a new timer is scheduled")
fireTimers()

-- Row 4: nil unit at hook time, unit assigned before fire.
resetState()
installHook(false)
frame = { Triage_indicatorFrames = {} }
hookCallback(frame, nil)
frame.unit = "raid5"
frame.displayedUnit = nil
fireTimers()
assertEqual(calls[1][1], "UpdateManagedFrameUnit", "body ran")
assertEqual(calls[1][3], "raid5", "fire-time unit used when hook argument was nil")

-- Row 5: frame failing the gate at fire time is not cleared or scanned.
resetState()
installHook(false)
frame = NewFrame("party1")
hookCallback(frame, "party1")
gateResult = false
fireTimers()
assertEqual(countCalls("ShouldContinue"), 1, "gate consulted")
assertEqual(countCalls("ClearIndicator"), 0, "no clear after failed gate")
assertEqual(countCalls("UpdateUnitAuras"), 0, "no scan after failed gate")
assertEqual(countCalls("UpdateTargetMarker"), 0, "no marker refresh after failed gate")

-- Row 6: Classic runs synchronously with no timer.
resetState()
installHook(true)
frame = NewFrame("party1")
hookCallback(frame, "party1")
assertEqual(timersScheduled, 0, "Classic schedules no timer")
assertEqual(countCalls("UpdateManagedFrameUnit"), 1, "Classic body runs synchronously")
assertEqual(countCalls("UpdateUnitAuras_Classic"), 1, "Classic scan runs synchronously")
assertEqual(countCalls("UpdateUnitAuras"), 0, "Classic never uses the payload scan")

-- Row 7: pending table is Triage-owned, weak-keyed, and the hook writes nothing to the frame.
resetState()
installHook(false)
local pending
for i = 1, 20 do
	local name, value = debug.getupvalue(hookCallback, i)
	if not name then
		break
	end
	if type(value) == "table" then
		local candidateMeta = getmetatable(value)
		if candidateMeta and candidateMeta.__mode == "k" then
			pending = value
		end
	end
end
assert(pending, "hook closure must hold a weak-keyed (__mode == \"k\") pending table as an upvalue")
frame = NewFrame("party1")
local snapshot = {}
for k, v in pairs(frame) do
	snapshot[k] = v
end
hookCallback(frame, "party1")
local fieldCount = 0
for k, v in pairs(frame) do
	fieldCount = fieldCount + 1
	assertEqual(snapshot[k], v, "hook changed frame field " .. tostring(k))
end
local snapshotCount = 0
for _ in pairs(snapshot) do
	snapshotCount = snapshotCount + 1
end
assertEqual(fieldCount, snapshotCount, "hook added a field to the Blizzard frame")
assert(pending[frame], "frame is marked pending")
fireTimers()
assertEqual(pending[frame], nil, "pending entry cleared on flush")

-- Row 8: one failing frame does not strand the rest, and the error is reported.
resetState()
installHook(false)
frameA, frameB = NewFrame("party1"), NewFrame("party2")
local originalManaged = addon.UpdateManagedFrameUnit
addon.UpdateManagedFrameUnit = function(self, f, unit, source)
	if f == frameA then
		error("boom")
	end
	return originalManaged(self, f, unit, source)
end
hookCallback(frameA, "party1")
hookCallback(frameB, "party2")
fireTimers()
assertEqual(#reportedErrors, 1, "failure reported through the error handler")
assertEqual(countCalls("UpdateManagedFrameUnit"), 1, "other frame still processed")

-- Row 9: target marker refresh runs on the pass path, not when the fire-time gate fails.
resetState()
installHook(false)
frame = NewFrame("party1")
frame.Triage_targetMarkerFrame = {}
hookCallback(frame, "party1")
fireTimers()
assertEqual(countCalls("UpdateTargetMarker"), 1, "marker refreshed on pass path")
assertEqual(calls[#calls][1], "UpdateTargetMarker", "marker refresh is the last body step")
assertEqual(calls[#calls][2], frame, "marker refresh targets the frame")

resetState()
installHook(false)
frame = NewFrame("party1")
frame.Triage_targetMarkerFrame = {}
hookCallback(frame, "party1")
gateResult = false
fireTimers()
assertEqual(countCalls("ShouldContinue"), 1, "gate consulted for marker frame")
assertEqual(countCalls("UpdateTargetMarker"), 0, "marker not refreshed when gate fails")

-- Row 10: frames hooked during a flush are queued for a second flush with a new timer,
-- and the rest of the first batch is still processed.
resetState()
installHook(false)
local batchFrames = { NewFrame("party1"), NewFrame("party2"), NewFrame("party3") }
local lateFrames = {}
for i = 1, 32 do
	lateFrames[i] = NewFrame("raid" .. i)
end
local rehookDone = false
local processedCount = {}
local inSecondFlush = false
local secondFlushFrames = {}
local managedStub = addon.UpdateManagedFrameUnit
addon.UpdateManagedFrameUnit = function(self, f, unit, source)
	processedCount[f] = (processedCount[f] or 0) + 1
	if inSecondFlush then
		secondFlushFrames[#secondFlushFrames + 1] = f
	end
	if not rehookDone then
		rehookDone = true
		hookCallback(f, unit)
		for i = 1, #lateFrames do
			hookCallback(lateFrames[i], lateFrames[i].unit)
		end
	end
	return managedStub(self, f, unit, source)
end
for _, f in ipairs(batchFrames) do
	hookCallback(f, f.unit)
end
assertEqual(timersScheduled, 1, "one timer for the first batch")
fireTimers()
assertEqual(#reportedErrors, 0, "re-hook during flush raised no error")
for i, f in ipairs(batchFrames) do
	assertEqual(processedCount[f] >= 1, true, "first-batch frame " .. i .. " processed")
end
for i, f in ipairs(lateFrames) do
	assertEqual(processedCount[f], nil, "late frame " .. i .. " not processed in the first flush")
end
assertEqual(timersScheduled, 2, "hook during flush scheduled a new timer")
for _, f in ipairs(batchFrames) do
	processedCount[f] = 0
end
inSecondFlush = true
fireTimers()
assertEqual(#reportedErrors, 0, "second flush raised no error")
for i, f in ipairs(lateFrames) do
	assertEqual(processedCount[f], 1, "late frame " .. i .. " processed once in the second flush")
end
local rehooked = 0
for _, f in ipairs(batchFrames) do
	rehooked = rehooked + processedCount[f]
end
assertEqual(rehooked, 1, "the re-hooked batch frame ran again exactly once")
assertEqual(#secondFlushFrames, 33, "second flush covers the re-hooked frame and all late frames")
assertEqual(timersScheduled, 2, "second flush schedules no further timer")

-- Row 11: a throwing error handler does not abandon the rest of the batch.
resetState()
installHook(false)
frameA, frameB = NewFrame("party1"), NewFrame("party2")
local realHandlerFn = geterrorhandler
geterrorhandler = function()
	return function()
		error("handler boom")
	end
end
local managedOriginal = addon.UpdateManagedFrameUnit
addon.UpdateManagedFrameUnit = function(self, f, unit, source)
	if f == frameA then
		error("boom")
	end
	return managedOriginal(self, f, unit, source)
end
hookCallback(frameA, "party1")
hookCallback(frameB, "party2")
fireTimers()
geterrorhandler = realHandlerFn
assertEqual(countCalls("UpdateManagedFrameUnit"), 1, "other frame processed despite throwing handler")

print("tri068_setunit_deferral: PASS")
