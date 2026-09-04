-- luacheck: globals arg dofile CreateFrame InCombatLockdown UnitIsUnit LibStub AuraUtil

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
				indicatorColor = { 0, 1, 0.59, 1 },
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

-- Names resolve once per spellbook generation rather than being walked out of the spell list
-- on every restricted update.
local memoAuras = { "Regrowth" }
assertEqual(ensure("party1", memoAuras), true, "a name-based indicator resolves on the secure path")
local savedSpells = { playerSpells[1], playerSpells[2] }
playerSpells[1], playerSpells[2] = nil, nil
assertEqual(ensure("party1", memoAuras), true,
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
