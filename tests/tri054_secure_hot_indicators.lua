-- luacheck: globals arg debug dofile CreateFrame InCombatLockdown UnitIsUnit LibStub AuraUtil

local repoRoot = arg[0]:match("^(.*[\\/])tests[\\/]") or "./"

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertTrue(value, message)
	if not value then
		error(message or "assertion failed", 2)
	end
end

-- The real LibStub is a callable table, so the stub is one too: shared media is fetched
-- through the method form, AceLocale and LibDispel through the call form. The locale echoes
-- each key back, so assertions can name the message that fired rather than repeat its
-- English text.
local localeStub = setmetatable({}, { __index = function(_, key) return key end })
LibStub = setmetatable({
	GetLibrary = function() return nil end,
}, {
	__call = function(_, library)
		if library == "AceLocale-3.0" then
			return { GetLocale = function() return localeStub end }
		end
		return {}
	end,
})

local inCombat = false
function InCombatLockdown()
	return inCombat
end

function UnitIsUnit(left, right)
	return left == right
end

local created = {}
local failCreate = false
function CreateFrame(frameType, _name, parent, template)
	if frameType == "Cooldown" then
		return {
			SetAllPoints = function() end,
			SetHideCountdownNumbers = function(self, hide) self.hidesNumbers = hide end,
			SetReverse = function(self, reverse) self.reversed = reverse end,
		}
	end
	if failCreate then
		error("CustomAuraContainerTemplate unavailable")
	end
	assertEqual(frameType, "AuraContainer", "secure bridge should create Blizzard's aura container")
	assertEqual(template, "CustomAuraContainerTemplate", "secure bridge should request the custom container template")
	local container = { parent = parent }
	function container:SetUnit(unit) self.unit = unit end
	function container:SetEnabled(enabled) self.enabled = enabled end
	function container:Hide() self.hidden = true end
	function container:Show() self.hidden = false end
	function container:ClearAllPoints() self.anchoredTo = nil end
	function container:SetAllPoints(target) self.anchoredTo = target end
	function container:SetIgnoreParentAlpha(ignore) self.ignoreParentAlpha = ignore end
	function container:SetAuraSlotCandidateFilters(slotKey, filters)
		self.updatedSlotKey, self.updatedFilters = slotKey, filters
	end
	function container:AddAuraSlot(slotKey, filter, options)
		self.slotKey, self.filter, self.options = slotKey, filter, options
		local auraFrame = {
			SetAllPoints = function() self.slotFillsContainer = true end,
			CreateTexture = function()
				return {
					SetAllPoints = function() end,
					SetAlpha = function(_, alpha) self.iconAlpha = alpha end,
					SetColorTexture = function(_, r, g, b, a) self.iconColor = { r, g, b, a } end,
				}
			end,
			CreateFontString = function()
				return {
					SetPoint = function(_, point) self.textPoints[#self.textPoints + 1] = point end,
					SetFont = function(_, path, size) self.fontPath, self.fontSize = path, size end,
					SetFontObject = function(_, name) self.stackFontObject = name end,
					SetJustifyH = function(_, justify) self.stackJustifyH = justify end,
					-- Both font strings share this factory and only the countdown is ever
					-- recolored, so the call count doubles as the stack text's parity check.
					SetTextColor = function(_, r, g, b, a)
						self.textColorCalls = self.textColorCalls + 1
						self.countdownColor = { r, g, b, a }
					end,
				}
			end,
			SetIcon = function() self.iconBoundToAura = true end,
			SetDurationCooldown = function(_, cooldown)
				self.cooldownHidesNumbers = cooldown.hidesNumbers
				self.cooldownReversed = cooldown.reversed
			end,
			SetDurationText = function() self.hasCountdown = true end,
			SetApplicationCount = function() self.hasStackSize = true end,
		}
		self.textPoints = {}
		self.textColorCalls = 0
		options.initializeFrame(auraFrame)
		return auraFrame
	end
	created[#created + 1] = container
	return container
end

-- Reassigning this table stands in for a SPELLS_CHANGED invalidation: SpellLookup builds a
-- fresh list, and the bridge keys its resolution memo on the list's identity.
local playerSpells = {
	{ name = "Regrowth", spellID = 8936 },
	{ name = "Rejuvenation", spellID = 774 },
}

local timerSchedules = 0
local scheduledTimers = {}
local nextTimerHandle = 0
local diagnostics = {}

_G.Triage = {
	isRetail = true,
	SpellLookup = {
		PlayerSpells = function()
			return playerSpells
		end,
	},
	db = {
		profile = {
			indicatorFont = "Arial Narrow",
			keepIndicatorsVisible = false,
			["indicator-4"] = {
				indicatorSize = 18, indicatorVerticalOffset = 0, indicatorHorizontalOffset = 0,
				indicatorAlpha = 0.7, showIcon = true, showCountdownSwipe = true,
				showCountdownText = true, showStackSize = true, textSize = 8,
				casterFilter = "all", countdownLocation = "CENTER", stackSizeLocation = "BOTTOMRIGHT",
				indicatorColor = { 0, 1, 0.59, 1 }, textColor = { 1, 1, 1, 1 },
			},
			-- Never configured, standing in for the majority of positions that keep the
			-- database default of an empty aura list (DatabaseDefaults.lua).
			["indicator-5"] = {
				casterFilter = "all",
			},
		},
	},
	Print = function(_, message) diagnostics[#diagnostics + 1] = message end,
	ScheduleTimer = function(_, method)
		timerSchedules = timerSchedules + 1
		nextTimerHandle = nextTimerHandle + 1
		scheduledTimers[nextTimerHandle] = method
		return nextTimerHandle
	end,
	CancelTimer = function(_, handle)
		scheduledTimers[handle] = nil
	end,
	ShouldContinue = function() return true end,
}

local profile = _G.Triage.db.profile["indicator-4"]
local indicatorFrame = { name = "indicator-4-frame" }
local parent = {
	GetWidth = function() return 72 end,
	GetHeight = function() return 36 end,
	Triage_indicatorFrames = { [4] = indicatorFrame },
}

local currentUnit = "party1"
local currentAuras = { "Regrowth", "Rejuvenation" }
local indicatorUpdates = 0

-- A one-position stand-in for the real UpdateIndicators loop, so the deferred flushes drive
-- EnsureSecureAuraIndicator the way they do in game rather than being counted and discarded.
_G.Triage.UpdateIndicators = function(self, frame)
	indicatorUpdates = indicatorUpdates + 1
	self:EnsureSecureAuraIndicator(frame, 4, currentUnit, currentAuras)
end

--- Fire every timer currently outstanding. Returns how many there were.
local function fireTimers()
	local pending = scheduledTimers
	scheduledTimers = {}
	local fired = 0
	for _, method in pairs(pending) do
		fired = fired + 1
		_G.Triage[method](_G.Triage)
	end
	return fired
end

local function ensure(unit, auras)
	return _G.Triage:EnsureSecureAuraIndicator(parent, 4, unit or currentUnit, auras or currentAuras)
end

local function live()
	return parent.Triage_secureAuraIndicators and parent.Triage_secureAuraIndicators[4]
end

dofile(repoRoot .. "Modules/SecureAuraIndicators.lua")

assertEqual(_G.Triage:GetSecureAuraSpellID("Regrowth"), 8936, "known local spell names should resolve")
assertEqual(_G.Triage:GetSecureAuraSpellID("Cross-Class Aura"), nil, "unresolved names keep the legacy matcher")

-- GetSpellIDs constructs one result table per call. Wrap its closed-over function so this
-- test can make the allocation contract observable without changing the module's API.
local getSpellIDsIndex
local originalGetSpellIDs
local upvalueIndex = 1
while true do
	local name, value = debug.getupvalue(_G.Triage.EnsureSecureAuraIndicator, upvalueIndex)
	if not name then
		break
	end
	if name == "GetSpellIDs" then
		getSpellIDsIndex = upvalueIndex
		originalGetSpellIDs = value
		break
	end
	upvalueIndex = upvalueIndex + 1
end
assertTrue(originalGetSpellIDs, "EnsureSecureAuraIndicator retains its spell-ID resolver")
local spellIDTableAllocations = 0
local previousSpellIDs
debug.setupvalue(_G.Triage.EnsureSecureAuraIndicator, getSpellIDsIndex, function(...)
	local spellIDs, spells = originalGetSpellIDs(...)
	if spellIDs ~= previousSpellIDs then
		spellIDTableAllocations = spellIDTableAllocations + 1
		previousSpellIDs = spellIDs
	end
	return spellIDs, spells
end)

parent.Triage_auraDataRestricted = false
assertEqual(ensure(), false, "readable Retail updates must retain the legacy renderer")
assertEqual(#created, 0, "readable updates must not allocate secure frames")

parent.Triage_auraDataRestricted = true
assertEqual(ensure(), true, "restricted Retail updates should use a secure slot")
assertEqual(#created, 1, "one indicator uses one managed secure slot")
local container = live()
assertTrue(container.options.candidateFilters.includeSpellIDs[8936], "first configured HoT must be included")
assertTrue(container.options.candidateFilters.includeSpellIDs[774], "later configured HoT must be included")
assertEqual(container.unit, "party1", "secure container tracks the managed unit")

-- The secure path is entered repeatedly while aura data is restricted. Identical inputs must
-- reuse the resolved set instead of allocating a throwaway result table every time; both an
-- identifier-list replacement and a new PlayerSpells generation must rebuild it.
assertEqual(spellIDTableAllocations, 1, "the initial secure update resolves one spell-ID set")
assertEqual(ensure(), true, "unchanged restricted updates retain the secure slot")
assertEqual(spellIDTableAllocations, 1, "an unchanged restricted update allocates no spell-ID result table")
currentAuras = { "Regrowth" }
assertEqual(ensure(), true, "changed identifiers retain the secure slot")
assertEqual(spellIDTableAllocations, 2, "changed identifiers rebuild the spell-ID set")
assertTrue(live().Triage_spellIDs[8936], "changed identifiers retain their resolved spell")
assertEqual(live().Triage_spellIDs[774], nil, "changed identifiers remove dropped spells")
playerSpells = { { name = "Regrowth", spellID = 55555 } }
assertEqual(ensure(), true, "a new spellbook generation retains the secure slot")
assertEqual(spellIDTableAllocations, 3, "a new spellbook generation rebuilds the spell-ID set")
assertTrue(live().Triage_spellIDs[55555], "a new spellbook generation refreshes the resolved spell")
playerSpells = {
	{ name = "Regrowth", spellID = 8936 },
	{ name = "Rejuvenation", spellID = 774 },
}
currentAuras = { "Regrowth", "Rejuvenation" }
assertEqual(ensure(), true, "restoring the configured spells retains the secure slot")

-- Regression for Major 2: an indicator with nothing configured must never resolve or
-- allocate a spell-ID set, and unconfigured positions are the majority since every
-- indicator defaults to an empty aura list.
local allocationsBeforeUnconfigured = spellIDTableAllocations
local createdBeforeUnconfigured = #created
assertEqual(_G.Triage:EnsureSecureAuraIndicator(parent, 5, "party1", {}), false,
	"an unconfigured position never resolves a secure slot")
assertEqual(spellIDTableAllocations, allocationsBeforeUnconfigured,
	"an unconfigured position allocates no spell-ID table")
assertEqual(_G.Triage:EnsureSecureAuraIndicator(parent, 5, "party1", {}), false,
	"a repeated update on an unconfigured position never resolves a secure slot")
assertEqual(spellIDTableAllocations, allocationsBeforeUnconfigured,
	"an unconfigured position allocates no spell-ID table on a repeated update")
assertEqual(#created, createdBeforeUnconfigured, "an unconfigured position never creates a container")

-- Geometry comes from anchors, never from a post-restriction call on the aura button:
-- Blizzard's empty layout pass would overwrite a SetSize on the container, and the
-- button is restricted the moment initializeFrame returns.
assertEqual(container.anchoredTo, indicatorFrame, "the container mirrors the configured indicator frame")
assertTrue(container.slotFillsContainer, "the aura button fills its container instead of being resized later")
assertEqual(container.hidden, false, "a new secure container is shown")

-- Appearance values that only apply inside initializeFrame
assertEqual(container.iconAlpha, 0.7, "configured opacity reaches the secure icon")
assertTrue(container.iconBoundToAura, "an icon indicator binds the texture to the aura")
assertEqual(container.fontSize, 8, "configured text size reaches the secure countdown text")
assertEqual(container.textPoints[1], "CENTER", "countdown text honors its configured location")
assertEqual(container.textPoints[2], "BOTTOMRIGHT", "stack text honors its configured location")
assertEqual(container.ignoreParentAlpha, false, "keepIndicatorsVisible reaches the container")

-- The readable cooldown is declared reverse + hideCountdownNumbers; a bare CooldownFrameTemplate
-- defaults both off and would draw Blizzard's own number over the addon's.
assertEqual(container.cooldownHidesNumbers, true, "the secure cooldown hides Blizzard's countdown number")
assertEqual(container.cooldownReversed, true, "the secure cooldown swipes the way the readable one does")

-- The readable stack text takes NumberFontNormalSmall wholesale and is never restyled in Lua.
assertEqual(container.stackFontObject, "NumberFontNormalSmall", "the secure stack text matches the readable font")
assertEqual(container.stackJustifyH, "RIGHT", "the secure stack text matches the readable justification")

-- Size is not a rebuild trigger: it travels through the indicator frame the container
-- is anchored to, so a resize must not throw the secure slot away.
profile.indicatorSize = 24
assertEqual(ensure(), true, "out-of-combat settings refresh should keep the secure slot")
assertEqual(#created, 1, "a size change reuses the anchored container")
profile.indicatorSize = 18

-- Blizzard can never reclaim a retired container, and the color and opacity widgets call
-- RefreshConfig on every sample of a drag. A drag must collapse into one rebuild.
local beforeDrag = #created
for step = 1, 12 do
	profile.indicatorAlpha = 0.30 + (step * 0.01)
	assertEqual(ensure(), true, "a settings drag keeps the current secure visual on screen")
end
assertEqual(#created, beforeDrag, "a settings drag allocates nothing while it is still moving")
assertEqual(live(), container, "the pre-drag container keeps drawing until the settings settle")
assertEqual(fireTimers(), 1, "a settings drag leaves exactly one rebuild scheduled")
assertEqual(#created, beforeDrag + 1, "a settings drag ends in exactly one rebuild")
container = live()
assertEqual(container.iconAlpha, 0.42, "the one rebuild carries the value the drag finished on")

-- Aura updates keep arriving while the settings differ from the live container. They must not
-- restart the window, or a ticking HoT would starve the rebuild for as long as it kept ticking.
profile.indicatorAlpha = 0.55
local schedulesBefore = timerSchedules
assertEqual(ensure(), true, "a changed setting keeps the current secure visual")
assertEqual(timerSchedules, schedulesBefore + 1, "a settings change schedules one rebuild")
for _ = 1, 5 do
	assertEqual(ensure(), true, "aura updates during the rebuild window keep the current visual")
end
assertEqual(timerSchedules, schedulesBefore + 1,
	"aura updates with unchanged settings must not restart the rebuild window")
fireTimers()
container = live()
assertEqual(container.iconAlpha, 0.55, "the deferred rebuild applies the pending settings")

-- The countdown font is applied inside initializeFrame too, and it is a profile-wide setting
-- rather than a per-indicator one.
local beforeFontChange = #created
_G.Triage.db.profile.indicatorFont = "Friz Quadrata TT"
assertEqual(ensure(), true, "changing the indicator font keeps the indicator on the secure path")
fireTimers()
assertEqual(#created, beforeFontChange + 1, "changing the indicator font rebuilds the secure slot")
_G.Triage.db.profile.indicatorFont = "Arial Narrow"
assertEqual(ensure(), true, "restoring the indicator font keeps the indicator on the secure path")
fireTimers()

-- A rebuild whose window elapses in combat waits for PLAYER_REGEN_ENABLED rather than
-- polling, and must not lose the settings it was holding.
profile.indicatorAlpha = 0.65
assertEqual(ensure(), true, "a settings change before combat keeps the current visual")
inCombat = true
local createdBeforeCombat = #created
local schedulesInCombat = timerSchedules
fireTimers()
assertEqual(#created, createdBeforeCombat, "a rebuild window elapsing in combat rebuilds nothing")
assertEqual(timerSchedules, schedulesInCombat, "a rebuild deferred by combat does not poll on a timer")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds, "a rebuild deferred by combat keeps its settings")
inCombat = false
_G.Triage:FlushSecureAuraIndicatorRefresh()
_G.Triage:FlushSecureAuraIndicatorRebuilds()
assertEqual(#created, createdBeforeCombat + 1, "leaving combat runs the deferred rebuild")
container = live()
assertEqual(container.iconAlpha, 0.65, "the combat-deferred rebuild applies the settings it held")

-- Trying a value and going back is the common case, and the container the first change retired
-- is the only one that can ever be used again.
local beforePool = #created
local original = container
profile.textSize = 20
ensure()
fireTimers()
assertEqual(#created, beforePool + 1, "a new text size builds one container")
assertTrue(live() ~= original, "the new text size is on a different container")
profile.textSize = 8
ensure()
fireTimers()
assertEqual(#created, beforePool + 1, "returning to earlier settings allocates nothing")
assertEqual(live(), original, "returning to earlier settings reuses the container they retired")
assertEqual(live().hidden, false, "a reused container is shown again")
assertEqual(live().enabled, true, "a reused container is enabled again")

-- Binding a duration cooldown is what makes Blizzard draw a countdown number, so the
-- swipe-off case must bind none at all.
profile.showCountdownSwipe = false
ensure()
fireTimers()
container = live()
assertEqual(container.cooldownHidesNumbers, nil, "no cooldown is bound when the swipe is switched off")
profile.showCountdownSwipe = true
ensure()
fireTimers()
container = live()

-- TRI-058: the countdown's color and its alpha both live in the text color picker, and the
-- secure countdown can only be styled where its font string is created. A picker change has to
-- travel the debounced out-of-combat rebuild, the same route indicatorColor already takes.
assertEqual(container.countdownColor[1], 1, "the secure countdown is painted from the text color picker")
assertEqual(container.countdownColor[4], 1, "the secure countdown carries the picker's alpha")
assertEqual(container.textColorCalls, 1, "the secure stack text keeps its font object's color")

local beforeTextColor = #created
profile.textColor = { 0.2, 0.4, 0.6, 0.35 }
assertEqual(ensure(), true, "a text color change keeps the current secure visual on screen")
assertEqual(#created, beforeTextColor, "a text color change allocates nothing before its window elapses")
assertEqual(fireTimers(), 1, "a text color change schedules exactly one rebuild")
assertEqual(#created, beforeTextColor + 1, "a text color change rebuilds the secure slot once")
container = live()
assertEqual(container.countdownColor[1], 0.2, "the rebuilt countdown carries the new red component")
assertEqual(container.countdownColor[2], 0.4, "the rebuilt countdown carries the new green component")
assertEqual(container.countdownColor[3], 0.6, "the rebuilt countdown carries the new blue component")
assertEqual(container.countdownColor[4], 0.35, "the rebuilt countdown carries the picker's alpha")

-- Aura updates keep arriving between picker changes. An unchanged color must not arm a rebuild,
-- or every restricted update would strand a container Blizzard can never reclaim.
local schedulesBeforeSameColor = timerSchedules
for _ = 1, 5 do
	assertEqual(ensure(), true, "an unchanged text color keeps the current secure visual")
end
assertEqual(timerSchedules, schedulesBeforeSameColor, "an unchanged text color arms no rebuild")
assertEqual(#created, beforeTextColor + 1, "an unchanged text color allocates nothing")

-- The picker mutates its table in place across a drag, so the recorded color has to be a copy:
-- a stored reference would compare equal to itself and no change would ever reach the screen.
profile.textColor[4] = 1
assertEqual(ensure(), true, "an alpha-only change keeps the current secure visual")
assertEqual(fireTimers(), 1, "an in-place alpha change schedules one rebuild")
container = live()
assertEqual(container.countdownColor[4], 1, "the rebuilt countdown carries the in-place alpha change")
profile.textColor = { 1, 1, 1, 1 }
ensure()
fireTimers()
container = live()

-- With the alpha folded into the picker, the profile must not carry a second alpha key that
-- nothing reads.
dofile(repoRoot .. "DatabaseDefaults.lua")
local indicatorDefaults = _G.Triage:CreateDefaults().profile["indicator-4"]
assertEqual(indicatorDefaults.textAlpha, nil, "no profile default carries the removed textAlpha key")
assertEqual(indicatorDefaults.textColor[4], 1, "the text color default carries a full alpha")

-- Regression for Major 1: the memo must be written on the in-combat success path too, or
-- one SPELLS_CHANGED invalidation reverts every later restricted update in the fight to a
-- fresh allocation for as long as combat lasts.
local savedCombatPlayerSpells = playerSpells
playerSpells = {
	{ name = "Regrowth", spellID = 8936 },
	{ name = "Rejuvenation", spellID = 774 },
}
inCombat = true
local allocationsBeforeCombatGeneration = spellIDTableAllocations
assertEqual(ensure(), true, "a new spellbook generation in combat keeps the current secure visual")
assertEqual(spellIDTableAllocations, allocationsBeforeCombatGeneration + 1,
	"a new spellbook generation in combat rebuilds the spell-ID set once")
-- The next hit returns the memo's bound-object identity rather than the throwaway table
-- GetSpellIDs just built, so the harness's identity-tracking hook sees one further change
-- here even on a cache hit. That is not a second allocation; it is this call's own return
-- value settling back onto container.Triage_spellIDs. The discriminating comparison for
-- "is the memo being written on the in-combat success path" is the call after this one,
-- which must return that same settled identity again.
assertEqual(ensure(), true, "a repeated in-combat update after the generation change keeps the current secure visual")
local allocationsAfterFirstRepeat = spellIDTableAllocations
assertEqual(ensure(), true,
	"a second repeated in-combat update after the generation change keeps the current secure visual")
assertEqual(spellIDTableAllocations, allocationsAfterFirstRepeat,
	"in combat, the memo records the new generation on the success path")
inCombat = false
playerSpells = savedCombatPlayerSpells

-- Names resolve once per spellbook generation rather than being walked out of the spell list
-- on every restricted update.
local memoAuras = { "Regrowth" }
assertEqual(ensure("party1", memoAuras), true, "a name-based indicator resolves on the secure path")
local savedSpells = { playerSpells[1], playerSpells[2] }
playerSpells[1], playerSpells[2] = nil, nil
assertEqual(ensure("party1", { "Regrowth" }), true,
	"a resolved name is not walked out of the spell list again on the next update")
playerSpells[1], playerSpells[2] = savedSpells[1], savedSpells[2]

-- A spellbook change replaces the cached list, and the memo has to go with it.
playerSpells = { { name = "Regrowth", spellID = 55555 } }
assertEqual(ensure("party1", memoAuras), true, "a relearned spell stays on the secure path")
assertTrue(container.updatedFilters.includeSpellIDs[55555], "a spellbook change re-resolves configured names")
playerSpells = { { name = "Regrowth", spellID = 8936 }, { name = "Rejuvenation", spellID = 774 } }
assertEqual(ensure(), true, "restoring the spellbook stays on the secure path")

assertTrue(container.updatedFilters.includeSpellIDs[774], "reconciled slot keeps the replacement HoT")

-- Caster origin is expressible securely, so "mine"/"notMine" must not fall back to the
-- readable matcher that cannot see the secret aura.
profile.casterFilter = "mine"
assertEqual(ensure(), true, "a mine-only indicator stays on the secure path")
assertEqual(container.updatedFilters.isFromPlayerOrPlayerPet, true,
	"mine maps onto Blizzard's secure caster filter")
profile.casterFilter = "notMine"
assertEqual(ensure(), true, "a notMine indicator stays on the secure path")
assertEqual(container.updatedFilters.isFromPlayerOrPlayerPet, false,
	"notMine maps onto Blizzard's secure caster filter")
profile.casterFilter = "all"
assertEqual(ensure(), true, "clearing the caster filter stays on the secure path")
assertEqual(container.updatedFilters.isFromPlayerOrPlayerPet, nil,
	"an unfiltered indicator sends no caster filter")

-- A colored indicator has no aura icon, so the texture must stay unbound and keep the
-- configured color rather than fall back to the readable matcher.
profile.showIcon = false
ensure()
fireTimers()
container = live()
assertEqual(container.iconBoundToAura, nil, "a colored indicator does not bind Blizzard's aura icon")
assertEqual(container.iconColor[2], 1, "a colored indicator paints its configured color")
profile.showIcon = true
ensure()
fireTimers()
container = live()

-- missingOnly cannot be expressed securely, so the indicator is claimed and cleared rather
-- than left to assert an absence the readable cache cannot verify.
profile.missingOnly = true
assertEqual(_G.Triage:EnsureSecureAuraIndicator(parent, 4, "party1", { "Cross-Class Aura" }), false,
	"a missingOnly indicator with nothing resolvable falls through to the readable path")
assertEqual(#diagnostics, 0, "an indicator with nothing resolvable does not announce the missingOnly limit")
assertEqual(ensure(), true, "missingOnly must not fall through to a matcher that cannot see the aura")
assertEqual(container.enabled, false, "a missingOnly indicator disables its secure slot")
assertTrue(container.hidden, "a missingOnly indicator hides its secure slot")
assertEqual(#diagnostics, 1, "the missingOnly limitation is reported")
assertEqual(diagnostics[1], "secureAuraMissingOnlyUnsupported",
	"the missingOnly notice is a localized string, not hardcoded English")
assertEqual(ensure(), true, "missingOnly stays claimed on later updates")
assertEqual(#diagnostics, 1, "the missingOnly limitation is reported once")
profile.missingOnly = nil

profile.meOnly = true
assertEqual(ensure(), false, "meOnly must retain the existing player-frame contract")
assertEqual(container.enabled, false, "incompatible settings disable an existing secure slot")
profile.meOnly = nil
assertEqual(ensure(), true, "clearing meOnly returns the indicator to the secure path")
container = live()

-- If UpdateIndicators throws after consuming one rebuild arm, the frame-level flag is never
-- normally cleared. That consumed position must still queue future mismatches; otherwise every
-- later settings sample allocates an unreclaimable container inline.
local armParent = {
	Triage_auraDataRestricted = true,
	GetWidth = parent.GetWidth,
	GetHeight = parent.GetHeight,
	Triage_indicatorFrames = { [4] = { name = "armed-indicator-4-frame" } },
}
local function ensureArmParent()
	return _G.Triage:EnsureSecureAuraIndicator(armParent, 4, "party1", { "Regrowth" })
end
local alphaBeforeArmTest = profile.indicatorAlpha
assertEqual(ensureArmParent(), true, "the arm test frame creates its initial secure slot")
profile.indicatorAlpha = 0.66
assertEqual(ensureArmParent(), true, "a changed setting queues before the throwing flush")
local beforeThrow = #created
local normalUpdateIndicators = _G.Triage.UpdateIndicators
_G.Triage.UpdateIndicators = function(self, frame)
	normalUpdateIndicators(self, frame)
	error("forced UpdateIndicators failure after the armed position rebuilds")
end
local flushed = pcall(fireTimers)
assertEqual(flushed, false, "the simulated UpdateIndicators failure reaches the flush caller")
_G.Triage.UpdateIndicators = normalUpdateIndicators
local afterThrow = #created
assertEqual(afterThrow, beforeThrow + 1, "the armed flush rebuilds its position before the forced failure")
profile.indicatorAlpha = 0.67
assertEqual(ensureArmParent(), true, "a post-failure mismatch retains the current secure visual")
assertEqual(#created, afterThrow, "a consumed arm queues after a throwing flush instead of rebuilding inline")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds[armParent][4],
	"a post-failure mismatch remains in the pending rebuild queue")
assertEqual(fireTimers(), 1, "the post-failure queued rebuild runs on its normal timer")

profile.indicatorAlpha = 0.68
armParent.Triage_secureAuraRebuildArmed = { [4] = true }
local beforeOneShotArm = #created
assertEqual(ensureArmParent(), true, "an armed position rebuilds inline")
assertEqual(#created, beforeOneShotArm + 1, "an armed position rebuilds inline exactly once")
profile.indicatorAlpha = 0.69
assertEqual(ensureArmParent(), true, "a second mismatch after an armed rebuild retains the current visual")
assertEqual(#created, beforeOneShotArm + 1, "a second mismatch after an armed rebuild queues instead of rebuilding inline")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds[armParent][4],
	"a second mismatch after an armed rebuild enters the pending queue")
fireTimers()
profile.indicatorAlpha = alphaBeforeArmTest
assertEqual(ensureArmParent(), true, "the arm test frame can return to its prior settings")
fireTimers()

-- Pins the clear ahead of the rebuild call: moving the clear after the rebuild would leave
-- a throw inside RebuildSecureAuraIndicator with the arm still set.
armParent.Triage_secureAuraRebuildArmed = { [4] = true }
local armContainer = armParent.Triage_secureAuraIndicators and armParent.Triage_secureAuraIndicators[4]
local originalArmSetEnabled = armContainer.SetEnabled
armContainer.SetEnabled = function(self, enabled)
	armContainer.SetEnabled = originalArmSetEnabled
	error("forced rebuild failure inside RebuildSecureAuraIndicator")
end
local beforeRebuildThrow = #created
profile.indicatorAlpha = 0.71
local rebuildFlushed = pcall(ensureArmParent)
assertEqual(rebuildFlushed, false, "a throw inside the armed rebuild reaches the caller")
assertEqual(#created, beforeRebuildThrow, "a rebuild that throws in DisableContainer allocates nothing")
assertEqual(armParent.Triage_secureAuraRebuildArmed[4], nil, "the arm is consumed before the rebuild runs")
profile.indicatorAlpha = 0.72
assertEqual(ensureArmParent(), true, "a mismatch after a throwing rebuild retains the current secure visual")
assertEqual(#created, beforeRebuildThrow, "a mismatch after a throwing rebuild queues instead of rebuilding inline")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds[armParent][4],
	"a mismatch after a throwing rebuild enters the pending queue")
armParent.Triage_secureAuraRebuildArmed = nil
fireTimers()
profile.indicatorAlpha = alphaBeforeArmTest
assertEqual(ensureArmParent(), true, "the arm test frame can return to its prior settings")
fireTimers()

-- TRI-059: a rebuild that throws must cost only its own frame. The flush takes the frames
-- this cycle owns, drops each one before rebuilding it, contains the throw, and re-raises it
-- once the rest of the queue has run.
local flushParentA = {
	Triage_auraDataRestricted = true,
	GetWidth = parent.GetWidth,
	GetHeight = parent.GetHeight,
	Triage_indicatorFrames = { [4] = { name = "flush-a-indicator-4-frame" } },
}
local flushParentB = {
	Triage_auraDataRestricted = true,
	GetWidth = parent.GetWidth,
	GetHeight = parent.GetHeight,
	Triage_indicatorFrames = { [4] = { name = "flush-b-indicator-4-frame" } },
}
local function ensureFlushParent(frame)
	return _G.Triage:EnsureSecureAuraIndicator(frame, 4, "party1", { "Regrowth" })
end
assertEqual(ensureFlushParent(flushParentA), true, "the first flush test frame creates its initial secure slot")
assertEqual(ensureFlushParent(flushParentB), true, "the second flush test frame creates its initial secure slot")
profile.indicatorAlpha = 0.61
assertEqual(ensureFlushParent(flushParentA), true, "a changed setting queues the first flush test frame")
assertEqual(ensureFlushParent(flushParentB), true, "a changed setting queues the second flush test frame")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds[flushParentA][4],
	"the first flush test frame is pending before the throwing flush")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds[flushParentB][4],
	"the second flush test frame is pending before the throwing flush")

-- Whichever frame pairs() reaches first is the one that throws, so nothing below depends on
-- the iteration order of the pending table.
local armedAtRebuild = {}
local flushThrowsLeft = 1
local beforeFlushThrow = #created
local updateIndicatorsBeforeFlush = _G.Triage.UpdateIndicators
_G.Triage.UpdateIndicators = function(_, frame)
	local armed = frame.Triage_secureAuraRebuildArmed
	armedAtRebuild[frame] = armed ~= nil and armed[4] ~= nil
	if flushThrowsLeft > 0 then
		flushThrowsLeft = flushThrowsLeft - 1
		error("forced UpdateIndicators failure during the secure rebuild flush")
	end
	ensureFlushParent(frame)
end
local flushCompleted, flushError = pcall(fireTimers)
_G.Triage.UpdateIndicators = updateIndicatorsBeforeFlush
assertEqual(flushThrowsLeft, 0, "exactly one frame in the flush was made to throw")
assertEqual(flushCompleted, false, "a throwing rebuild still reaches the flush caller")
assertTrue(tostring(flushError):find("forced UpdateIndicators failure during the secure rebuild flush", 1, true),
	"the flush re-raises the frame's own error rather than a wrapper")
assertEqual(armedAtRebuild[flushParentA], true, "the first flush test frame rebuilt with its armed position")
assertEqual(armedAtRebuild[flushParentB], true, "the second flush test frame rebuilt with its armed position")
assertEqual(#created, beforeFlushThrow + 1, "the frame that did not throw rebuilt its armed position")
assertEqual(flushParentA.Triage_secureAuraRebuildArmed, nil, "the first flush test frame is left unarmed")
assertEqual(flushParentB.Triage_secureAuraRebuildArmed, nil, "the second flush test frame is left unarmed")
assertEqual(_G.Triage.Triage_pendingSecureAuraRebuilds, nil, "a drained flush clears the pending table")

-- A rebuild can queue a frame while the flush is still running. That entry belongs to the
-- next debounce window, so the flush must neither run it now nor discard it on the way out.
profile.indicatorAlpha = 0.62
assertEqual(ensureFlushParent(flushParentA), true, "a further change re-queues the first flush test frame alone")
local timersBeforeRequeue = timerSchedules
local rebuildsDuringRequeue = 0
local updateIndicatorsBeforeRequeue = _G.Triage.UpdateIndicators
_G.Triage.UpdateIndicators = function(_, frame)
	rebuildsDuringRequeue = rebuildsDuringRequeue + 1
	ensureFlushParent(frame)
	-- Stands in for an aura update landing mid-flush on a frame this cycle does not own.
	profile.indicatorAlpha = 0.63
	ensureFlushParent(flushParentB)
end
local requeueCompleted = pcall(fireTimers)
_G.Triage.UpdateIndicators = updateIndicatorsBeforeRequeue
assertTrue(requeueCompleted, "the mid-flush re-queue flush runs without a throw")
assertEqual(rebuildsDuringRequeue, 1, "a mid-flush re-queue does not get rebuilt by the flush already running")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds, "a mid-flush re-queue survives the flush it landed in")
assertTrue(_G.Triage.Triage_pendingSecureAuraRebuilds[flushParentB][4],
	"the mid-flush re-queue keeps its own pending target")
assertTrue(timerSchedules > timersBeforeRequeue, "the mid-flush re-queue schedules its own debounce window")
assertEqual(fireTimers(), 1, "the mid-flush re-queue rebuilds on its own timer")
assertEqual(_G.Triage.Triage_pendingSecureAuraRebuilds, nil, "the following flush drains the re-queued frame")
profile.indicatorAlpha = alphaBeforeArmTest

-- UpdateIndicators walks every position, so one pass rebuilds the armed position and can find
-- an unarmed one whose container has drifted. That second position queues its own rebuild
-- while the flush still holds the frame, which is only safe because the frame leaves the
-- pending table before its rebuild runs: the new target then lands in a fresh entry instead of
-- the positions table the flush is about to drop. Two positions on one frame are what it takes
-- to reach that shape; the single-position stubs above cannot.
-- One table per position: the case drifts the two positions' settings independently.
local function twoPositionProfile()
	return {
		indicatorSize = 18, indicatorVerticalOffset = 0, indicatorHorizontalOffset = 0,
		indicatorAlpha = 0.7, showIcon = true, showCountdownSwipe = true,
		showCountdownText = true, showStackSize = true, textSize = 8,
		casterFilter = "all", countdownLocation = "CENTER", stackSizeLocation = "BOTTOMRIGHT",
		indicatorColor = { 0, 1, 0.59, 1 }, textColor = { 1, 1, 1, 1 },
	}
end
_G.Triage.db.profile["indicator-6"] = twoPositionProfile()
_G.Triage.db.profile["indicator-7"] = twoPositionProfile()
local twoPositionParent = {
	Triage_auraDataRestricted = true,
	GetWidth = parent.GetWidth,
	GetHeight = parent.GetHeight,
	Triage_indicatorFrames = {
		[6] = { name = "two-position-indicator-6-frame" },
		[7] = { name = "two-position-indicator-7-frame" },
	},
}
local function ensureTwoPositionParent(position)
	return _G.Triage:EnsureSecureAuraIndicator(twoPositionParent, position, "party1", { "Regrowth" })
end
assertEqual(ensureTwoPositionParent(6), true, "the two-position frame creates its armed position's slot")
assertEqual(ensureTwoPositionParent(7), true, "the two-position frame creates its unarmed position's slot")

-- Position 6 is queued, so the flush arms it. Position 7 is drifted without being queued, so
-- the pass that rebuilds 6 is the first thing to notice 7 and has to queue it mid-rebuild.
_G.Triage.db.profile["indicator-6"].indicatorAlpha = 0.51
assertEqual(ensureTwoPositionParent(6), true, "a changed setting queues the armed position")
_G.Triage.db.profile["indicator-7"].indicatorAlpha = 0.52
local timersBeforeTwoPosition = timerSchedules
local createdBeforeTwoPosition = #created
local updateIndicatorsBeforeTwoPosition = _G.Triage.UpdateIndicators
_G.Triage.UpdateIndicators = function()
	ensureTwoPositionParent(6)
	ensureTwoPositionParent(7)
end
local armedFlushCompleted = pcall(fireTimers)
local pendingAfterArmedFlush = _G.Triage.Triage_pendingSecureAuraRebuilds
local queuedTarget = pendingAfterArmedFlush and pendingAfterArmedFlush[twoPositionParent]
	and pendingAfterArmedFlush[twoPositionParent][7]
local timersAfterArmedFlush = timerSchedules
local createdAfterArmedFlush = #created
local queuedFlushCompleted, queuedFlushCount = pcall(fireTimers)
local createdAfterQueuedFlush = #created
_G.Triage.UpdateIndicators = updateIndicatorsBeforeTwoPosition
assertTrue(armedFlushCompleted, "the two-position flush runs without a throw")
assertTrue(queuedTarget, "a position queued during the rebuild survives the flush that was holding the frame")
assertTrue(timersAfterArmedFlush > timersBeforeTwoPosition,
	"the position queued during the rebuild schedules its own debounce window")
assertEqual(createdAfterArmedFlush, createdBeforeTwoPosition + 1,
	"the armed position still rebuilds in the pass that queues the unarmed one")
assertTrue(queuedFlushCompleted, "the flush that drains the queued position runs without a throw")
assertEqual(queuedFlushCount, 1, "the position queued during the rebuild rebuilds on its own timer")
assertEqual(createdAfterQueuedFlush, createdAfterArmedFlush + 1,
	"the position queued during the rebuild rebuilds exactly once")
assertEqual(_G.Triage.Triage_pendingSecureAuraRebuilds, nil, "the following flush drains the queued position")

_G.Triage:InvalidateSecureAuraIndicators(parent)
assertEqual(container.enabled, false, "recycling invalidates the old unit before reassignment")
assertTrue(container.hidden, "recycling hides the previous unit's secure visual")
assertEqual(ensure("party2"), true,
	"the same slot can be safely assigned to a recycled frame's new unit out of combat")
assertEqual(container.unit, "party2", "recycled frame must not keep the previous unit")
-- Blizzard registers a container for UNIT_AURA only while it is visible and enabled,
-- so a reused container that is never shown again would silently stop updating.
assertEqual(container.hidden, false, "reuse must show the container it previously hid")
assertEqual(container.enabled, true, "reuse must re-enable the container it previously disabled")

-- Combat frame recycling: the container must stop showing the old unit's aura
-- immediately, not at the next PLAYER_REGEN_ENABLED.
currentUnit = "party2"
inCombat = true
_G.Triage:InvalidateSecureAuraIndicators(parent)
assertTrue(container.hidden, "a combat retarget hides the previous unit's secure visual at once")
assertEqual(container.Triage_unit, nil, "a combat retarget drops the stale unit binding")
assertTrue(_G.Triage.Triage_pendingSecureAuraIndicators[parent], "a combat retarget queues a post-combat refresh")
assertEqual(ensure("party3"), false, "unit changes requiring secure mutation defer during combat")
assertTrue(container.hidden, "a deferred unit change leaves nothing on screen for the old unit")
inCombat = false
currentUnit = "party2"
local updatesBeforeFlush = indicatorUpdates
_G.Triage:FlushSecureAuraIndicatorRefresh()
assertEqual(indicatorUpdates, updatesBeforeFlush + 1, "post-combat flush re-enters the normal indicator refresh")

local retailResolverCalls = #created
_G.Triage.isRetail = false
assertEqual(ensure(), false, "Classic clients retain their existing aura path")
assertEqual(#created, retailResolverCalls, "Classic clients allocate no secure frames")
_G.Triage.isRetail = true
assertEqual(ensure(), true, "returning to Retail restores the secure path")
container = live()

local beforeVisualRebuild = #created
profile.showCountdownText = false
ensure()
fireTimers()
assertEqual(#created, beforeVisualRebuild + 1, "visual binding changes create one replacement container")
assertEqual(container.enabled, false, "the replaced container is disabled")
assertTrue(container.hidden, "the replaced container is hidden")
container = live()
assertEqual(container.hasCountdown, nil, "the replacement drops the countdown binding")
profile.showCountdownText = true
ensure()
fireTimers()
container = live()

-- A latched capability failure must not leave a container drawing beside the readable path.
_G.Triage.Triage_secureAuraCapability = false
assertEqual(ensure(), false, "a latched capability failure returns the indicator to the readable path")
assertEqual(container.enabled, false, "a latched capability failure disables the live container")
assertTrue(container.hidden, "a latched capability failure hides the live container")

local failingParent = { Triage_auraDataRestricted = true, GetWidth = parent.GetWidth, GetHeight = parent.GetHeight }
_G.Triage.Triage_secureAuraCapability = nil
failCreate = true
local beforeCapabilityFailure = #created
local diagnosticsBefore = #diagnostics
assertEqual(_G.Triage:EnsureSecureAuraIndicator(failingParent, 4, "party1", { "Regrowth" }), false,
	"a missing capability fails closed")
assertEqual(_G.Triage:EnsureSecureAuraIndicator(failingParent, 4, "party1", { "Regrowth" }), false,
	"a failed capability stays latched")
assertEqual(#diagnostics, diagnosticsBefore + 1, "capability failure reports once")
assertEqual(diagnostics[#diagnostics], "secureAuraUnavailable",
	"the capability notice is a localized string, not hardcoded English")
assertEqual(#created, beforeCapabilityFailure, "capability failure cannot allocate on subsequent aura updates")
failCreate = false

------------------------------------------------------------------
-- Listener: restriction detection
------------------------------------------------------------------

rawset(_G, "issecretvalue", function(value)
	return type(value) == "table" and value.restricted == true
end)
_G.Triage.needsLibClassicDurations = false
_G.Triage.UpdateIndicators = function()
	indicatorUpdates = indicatorUpdates + 1
end
dofile(repoRoot .. "Modules/AuraListeners.lua")
-- Set after the load: the module defines its own CreateAuraListener, which needs frame
-- plumbing this test has no reason to build.
_G.Triage.GetManagedFrameUnit = function(_, frame) return frame.unit end
_G.Triage.CreateAuraListener = function(_, frame) frame.Triage_auraListenerFrame = {} end

local restrictedFrame = { Triage_unitAuras = {} }
assertEqual(_G.Triage:addToAuraTable(restrictedFrame, { name = { restricted = true } }), false,
	"secret aura fields stay out of the readable aura cache")
assertEqual(restrictedFrame.Triage_auraDataRestricted, true,
	"the listener marks restricted updates for secure rendering")

-- A scan the client refuses outright is the least ambiguous restricted update there is, and
-- addToAuraTable never runs to record it. Rolling the flag back would switch the secure path
-- off in exactly the case it exists for.
AuraUtil = {
	ForEachAura = function()
		error("Auras cannot be accessed when secret while tainted by an addon")
	end,
}
local deniedFrame = { unit = "party1", Triage_unitAuras = { existing = { name = "Rejuvenation" } } }
local updatesBeforeDenial = indicatorUpdates
_G.Triage:UpdateUnitAuras(deniedFrame, { isFullUpdate = true })
assertEqual(deniedFrame.Triage_auraDataRestricted, true, "a denied scan is a restricted scan")
assertTrue(deniedFrame.Triage_unitAuras.existing, "a denied scan still rolls the aura table back")
assertEqual(indicatorUpdates, updatesBeforeDenial + 1,
	"the first denied scan runs the indicators so the secure slot gets built")

local updatesBeforeRepeat = indicatorUpdates
_G.Triage:UpdateUnitAuras(deniedFrame, { isFullUpdate = true })
assertEqual(indicatorUpdates, updatesBeforeRepeat,
	"a repeated denied scan does not re-run the indicators")

print("tri054_secure_hot_indicators: PASS")
