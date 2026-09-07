-- Triage - Enhanced Raid Frames Reforged
-- Retail-only bridge for Blizzard's secure custom aura containers.

---@type Triage
local Triage = _G.Triage

-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-- Values consumed inside InitializeSecureAuraButton. Blizzard applies
-- DenyTaintedAccessWhenAurasAreSecret to the aura button as soon as that callback
-- returns, so none of these can be changed on a live button; a change rebuilds the
-- container out of combat instead.
local REBUILD_FIELDS = {
	"showIcon",
	"indicatorAlpha",
	"showCountdownSwipe",
	"showCountdownText",
	"countdownLocation",
	"showStackSize",
	"stackSizeLocation",
	"textSize",
}

-- The same contract as REBUILD_FIELDS, for the profile's four-component color tables. They are
-- compared and stored component by component: the picker mutates its table in place across a
-- drag, so a stored reference would compare equal to itself and never rebuild.
local REBUILD_COLOR_FIELDS = {
	"indicatorColor",
	"textColor",
}

-- How long the settings have to hold still before a rebuild runs. The color wheel and the
-- opacity slider call RefreshConfig on every sample of a drag, and every rebuild strands a
-- Blizzard frame permanently, so a drag has to collapse into one rebuild.
local REBUILD_DEBOUNCE_SECONDS = 0.2

local function GetSlotKey(position)
	return "triage-indicator-" .. position
end

local function GetIndicatorFontPath(addon)
	local media = LibStub:GetLibrary("LibSharedMedia-3.0", true)
	return (media and media:Fetch("font", addon.db.profile.indicatorFont)) or "Fonts\\ARIALN.TTF"
end

local function GetCountdownAnchor(location)
	if location == "TOPLEFT" then
		return "TOPLEFT", 1, -1
	elseif location == "TOPRIGHT" then
		return "TOPRIGHT", -1, -1
	elseif location == "BOTTOMLEFT" then
		return "BOTTOMLEFT", 1, 1
	elseif location == "BOTTOMRIGHT" then
		return "BOTTOMRIGHT", -1, 1
	end
	return "CENTER", 0, 0
end

local function GetStackSizeAnchor(location)
	if location == "TOPLEFT" then
		return "TOPLEFT", -3, 2
	elseif location == "TOPRIGHT" then
		return "TOPRIGHT", 4, 2
	elseif location == "BOTTOMLEFT" then
		return "BOTTOMLEFT", -3, -2
	end
	return "BOTTOMRIGHT", 4, -2
end

local function InitializeSecureAuraButton(auraFrame, profile, fontPath)
	-- Anchoring the button to its container is what keeps size configurable: the
	-- container is ours and unrestricted, the button is neither once this returns.
	auraFrame:SetAllPoints()

	local icon = auraFrame:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	if profile.showIcon then
		icon:SetAlpha(profile.indicatorAlpha)
		auraFrame:SetIcon(icon)
	else
		-- Left unbound from the aura so Blizzard's ApplyIcon never overwrites it. The
		-- button is still shown and hidden with the aura, so a flat colored indicator
		-- behaves as it does on the readable path.
		icon:SetColorTexture(unpack(profile.indicatorColor))
	end

	-- Binding a duration cooldown is what makes Blizzard draw its own countdown number, so
	-- the swipe-off case must not bind one at all: the readable path never starts a cooldown
	-- then either. hideCountdownNumbers and reverse mirror XML/IndicatorTemplate.xml, whose
	-- defaults are both off on a bare CooldownFrameTemplate — otherwise the secure indicator
	-- shows a number the player switched off, or a second one in a different font, and swipes
	-- the opposite way from every readable indicator beside it.
	if profile.showCountdownSwipe then
		local cooldown = CreateFrame("Cooldown", nil, auraFrame, "CooldownFrameTemplate")
		cooldown:SetAllPoints()
		cooldown:SetHideCountdownNumbers(true)
		cooldown:SetReverse(true)
		auraFrame:SetDurationCooldown(cooldown)
	end

	if profile.showCountdownText then
		local countdown = auraFrame:CreateFontString(nil, "OVERLAY")
		local point, offsetX, offsetY = GetCountdownAnchor(profile.countdownLocation)
		countdown:SetPoint(point, auraFrame, point, offsetX, offsetY)
		countdown:SetFont(fontPath, profile.textSize, "OUTLINE")
		countdown:SetTextColor(unpack(profile.textColor))
		auraFrame:SetDurationText(countdown)
	end

	if profile.showStackSize then
		local stackSize = auraFrame:CreateFontString(nil, "OVERLAY")
		local point, offsetX, offsetY = GetStackSizeAnchor(profile.stackSizeLocation)
		stackSize:SetPoint(point, auraFrame, point, offsetX, offsetY)
		-- The readable stack text takes its font, size and color from NumberFontNormalSmall and
		-- is never restyled in Lua; the configured font and text size drive the countdown only.
		stackSize:SetFontObject("NumberFontNormalSmall")
		stackSize:SetJustifyH("RIGHT")
		auraFrame:SetApplicationCount(stackSize)
	end
end

-- SpellLookup hands back a fresh table whenever its SPELLS_CHANGED invalidation fires, so the
-- cache table's identity is the spellbook generation. Lowering the spell list once per
-- generation replaces a walk of the whole spellbook on every restricted update, for every
-- configured name, on every managed frame.
local spellIDByLoweredName = {}
local knownSpellsGeneration

local function GetPlayerSpellsGeneration(addon)
	if addon.SpellLookup and addon.SpellLookup.PlayerSpells then
		return addon.SpellLookup.PlayerSpells()
	end
end

local function ResolvePlayerSpellID(spells, auraIdentifier)
	if knownSpellsGeneration ~= spells then
		knownSpellsGeneration = spells
		spellIDByLoweredName = {}
		for _, spell in ipairs(spells) do
			spellIDByLoweredName[spell.name:lower()] = spell.spellID
		end
	end

	return spellIDByLoweredName[auraIdentifier:lower()]
end

local function ResolveSpellID(spells, auraIdentifier)
	local numericID = tonumber(auraIdentifier)
	if numericID then
		return numericID
	end
	return spells and ResolvePlayerSpellID(spells, auraIdentifier)
end

function Triage:GetSecureAuraSpellID(auraIdentifier)
	local numericID = tonumber(auraIdentifier)
	if numericID then
		return numericID
	end
	return ResolveSpellID(GetPlayerSpellsGeneration(self), auraIdentifier)
end

local function ApplySecureAuraIndicatorAppearance(addon, parentFrame, position, container)
	-- A slot-only container has no layout groups, so Blizzard's layout pass resizes it
	-- to 1x1 (AnchorUtil.ApplyFlowLayout -> CustomAuraContainerFlowLayoutMixin:OnLayoutComplete).
	-- Taking geometry from anchors survives that, and the readable indicator frame
	-- already carries the configured size, offsets, and power-bar compensation.
	local keepVisible = addon.db.profile.keepIndicatorsVisible
	container:ClearAllPoints()
	container:SetAllPoints(parentFrame.Triage_indicatorFrames[position])
	container:SetIgnoreParentAlpha(keepVisible)
	container.Triage_keepVisible = keepVisible
end

-- The returned set is shared by reference: it becomes the container's memo, its
-- Triage_spellIDs, and the set handed to SetAuraSlotCandidateFilters as includeSpellIDs.
-- Blizzard only reads it there (Blizzard_AuraContainerUtil.lua's candidate filter only looks a
-- spell ID up in it, and Blizzard_CustomAuraContainer.lua only asserts its type before taking
-- its own securecopy, so our table is never written to and never kept by Blizzard either way).
-- Treat it as immutable once returned; a change always builds a new table. A position with no
-- container -- a missingOnly position, or one whose identifiers never resolve for this
-- character -- has nowhere to memoize this, so the module-level tables below carry the same
-- memo keyed on the identifiers table itself, shared by reference across every position and
-- every managed frame that watches that same table.
local spellIDMemoGeneration = setmetatable({}, { __mode = "k" })
local spellIDMemoSets = setmetatable({}, { __mode = "k" })

local function GetSpellIDs(addon, auraIdentifiers, container)
	local spells = GetPlayerSpellsGeneration(addon)
	if container and container.Triage_spellIDsIdentifiers == auraIdentifiers and
		container.Triage_spellIDsGeneration == spells then
		return container.Triage_resolvedSpellIDs, spells
	end

	local memoized = spellIDMemoSets[auraIdentifiers]
	if memoized and spellIDMemoGeneration[auraIdentifiers] == spells then
		return memoized, spells
	end

	local spellIDs = {}
	for _, auraIdentifier in ipairs(auraIdentifiers) do
		local spellID = ResolveSpellID(spells, auraIdentifier)
		if spellID then
			spellIDs[spellID] = true
		end
	end
	spellIDMemoGeneration[auraIdentifiers] = spells
	spellIDMemoSets[auraIdentifiers] = spellIDs
	return spellIDs, spells
end

local function RecordSpellIDs(container, auraIdentifiers, spells, spellIDs)
	container.Triage_spellIDsIdentifiers = auraIdentifiers
	container.Triage_spellIDsGeneration = spells
	container.Triage_resolvedSpellIDs = spellIDs
end

local function HasSpellIDs(spellIDs)
	return next(spellIDs) ~= nil
end

local function SameSpellIDs(left, right)
	if left == right then
		return true
	end
	for spellID in pairs(left) do
		if not right[spellID] then
			return false
		end
	end
	for spellID in pairs(right) do
		if not left[spellID] then
			return false
		end
	end
	return true
end

local function GetCandidateFilters(profile, spellIDs)
	local filters = { includeSpellIDs = spellIDs }
	-- Blizzard evaluates isFromPlayerOrPlayerPet on the secure side, so caster origin
	-- never has to be read here. It counts the player's pet as the player, which the
	-- readable matcher does not; that is the one behavior difference between the paths.
	if profile.casterFilter == "mine" then
		filters.isFromPlayerOrPlayerPet = true
	elseif profile.casterFilter == "notMine" then
		filters.isFromPlayerOrPlayerPet = false
	end
	return filters
end

-- Compared field by field rather than as a concatenated signature, and against the
-- configured font key rather than the resolved path: this runs for every indicator on
-- every restricted aura update, where string building and media lookups are pure cost.
local function SameRebuildSettings(container, profile, fontKey)
	local applied = container.Triage_rebuildSettings
	if not applied or applied.fontKey ~= fontKey then
		return false
	end
	for index = 1, #REBUILD_FIELDS do
		local field = REBUILD_FIELDS[index]
		if applied[field] ~= profile[field] then
			return false
		end
	end
	for fieldIndex = 1, #REBUILD_COLOR_FIELDS do
		local field = REBUILD_COLOR_FIELDS[fieldIndex]
		local appliedColor, profileColor = applied[field], profile[field]
		for index = 1, 4 do
			if appliedColor[index] ~= profileColor[index] then
				return false
			end
		end
	end
	return true
end

local function RecordRebuildSettings(container, profile, fontKey)
	local applied = { fontKey = fontKey }
	for index = 1, #REBUILD_FIELDS do
		local field = REBUILD_FIELDS[index]
		applied[field] = profile[field]
	end
	for fieldIndex = 1, #REBUILD_COLOR_FIELDS do
		local field = REBUILD_COLOR_FIELDS[fieldIndex]
		local profileColor = profile[field]
		local appliedColor = {}
		for index = 1, 4 do
			appliedColor[index] = profileColor[index]
		end
		applied[field] = appliedColor
	end
	container.Triage_rebuildSettings = applied
end

function Triage:QueueSecureAuraIndicatorRefresh(parentFrame)
	self.Triage_pendingSecureAuraIndicators = self.Triage_pendingSecureAuraIndicators or {}
	self.Triage_pendingSecureAuraIndicators[parentFrame] = true
end

function Triage:FlushSecureAuraIndicatorRefresh()
	if InCombatLockdown() or not self.Triage_pendingSecureAuraIndicators then
		return
	end

	local pending = self.Triage_pendingSecureAuraIndicators
	self.Triage_pendingSecureAuraIndicators = nil
	for parentFrame in pairs(pending) do
		if self.ShouldContinue(parentFrame, true) then
			self:UpdateIndicators(parentFrame, true)
		end
	end
end

--- Record that an indicator's settings have moved away from the container currently showing
--- it, and restart the window the settings have to hold still for before the rebuild runs.
--- @param parentFrame table @The raid frame owning the indicator
--- @param position number @The indicator position, 1-9
--- @param profile table @The indicator's settings
--- @param fontKey string @The profile-wide font name
function Triage:QueueSecureAuraIndicatorRebuild(parentFrame, position, profile, fontKey)
	local pending = self.Triage_pendingSecureAuraRebuilds
	if not pending then
		pending = {}
		self.Triage_pendingSecureAuraRebuilds = pending
	end
	local positions = pending[parentFrame]
	if not positions then
		positions = {}
		pending[parentFrame] = positions
	end

	local target = positions[position]
	if not target then
		target = {}
		positions[position] = target
	elseif SameRebuildSettings(target, profile, fontKey) then
		-- Ordinary aura updates keep arriving while the settings differ from the live
		-- container, and they must not push the deadline out: a ticking HoT would starve
		-- the rebuild for as long as it kept ticking. Only a real settings change restarts it.
		return
	end
	RecordRebuildSettings(target, profile, fontKey)

	if self.Triage_secureAuraRebuildTimer then
		self:CancelTimer(self.Triage_secureAuraRebuildTimer)
	end
	self.Triage_secureAuraRebuildTimer = self:ScheduleTimer("FlushSecureAuraIndicatorRebuilds",
		REBUILD_DEBOUNCE_SECONDS)
end

--- Run the rebuilds whose settings have stopped moving.
function Triage:FlushSecureAuraIndicatorRebuilds()
	self.Triage_secureAuraRebuildTimer = nil
	local pending = self.Triage_pendingSecureAuraRebuilds
	if not pending then
		return
	end

	if InCombatLockdown() then
		-- Rebuilding allocates and anchors frames, so it waits for combat to end. The pending
		-- targets keep until the PLAYER_REGEN_ENABLED handler calls back here; the regen queue
		-- keeps the containers already on screen current meanwhile.
		for parentFrame in pairs(pending) do
			self:QueueSecureAuraIndicatorRefresh(parentFrame)
		end
		return
	end

	-- Settle which frames this cycle owns before any of them rebuilds. A rebuild reaches the
	-- other positions on the same frame and can queue them, and those belong to the next
	-- debounce window; rebuilding them here would allocate the container the window exists
	-- to collapse.
	local frames = {}
	for parentFrame in pairs(pending) do
		frames[#frames + 1] = parentFrame
	end

	local firstError
	for index = 1, #frames do
		local parentFrame = frames[index]
		local positions = pending[parentFrame]
		-- Off the queue before its own rebuild runs, so a throw below costs this frame's
		-- targets alone rather than every frame still waiting behind it.
		pending[parentFrame] = nil
		if self.ShouldContinue(parentFrame, true) then
			-- EnsureSecureAuraIndicator rebuilds only the positions armed here; every other
			-- caller queues instead, which is what keeps a drag from allocating per sample.
			parentFrame.Triage_secureAuraRebuildArmed = positions
			local ok, err = pcall(self.UpdateIndicators, self, parentFrame, true)
			parentFrame.Triage_secureAuraRebuildArmed = nil
			if not ok and firstError == nil then
				firstError = err
			end
		end
	end

	-- Anything left is a frame queued while this loop ran; it keeps the table and the timer
	-- QueueSecureAuraIndicatorRebuild already scheduled for it.
	if next(pending) == nil then
		self.Triage_pendingSecureAuraRebuilds = nil
	end

	if firstError ~= nil then
		-- Level 0 keeps the position the rebuild actually failed at, which is what BugGrabber
		-- and the player need to see rather than this line.
		error(firstError, 0)
	end
end

-- Blizzard registers a container for UNIT_AURA only while it is both visible and
-- enabled (AuraContainerPrivateMixin:ShouldRegisterForDynamicEvents), so hiding is
-- what actually stops a stale container from drawing. Clearing the recorded unit
-- forces the post-combat pass to retarget instead of treating the container as current.
local function HideContainer(container)
	container.Triage_unit = nil
	container:Hide()
end

-- Hides a container that is still current -- a readable pass, or a restricted pass that
-- defers to the readable indicator -- without dropping Triage_unit. HideContainer's nil is
-- what forces the next pass to retarget; a retained container must not pay that cost; it
-- stays current so a later restricted pass can show it at once.
local function RetainContainer(container)
	container:Hide()
end

local function DisableContainer(container)
	container:SetEnabled(false)
	HideContainer(container)
end

local function ShowContainer(container)
	container:SetEnabled(true)
	container:Show()
end

-- Blizzard exposes no way to remove or re-initialize an aura slot, and its own ClearAuraGroups
-- comment says frames left behind that way are irrecoverable. So a container displaced by a
-- settings change can never be freed, only handed back to a later change that wants exactly the
-- settings it was built with — which is the common case of trying a value and going back.
local function RebuildSecureAuraIndicator(parentFrame, position, container, profile, fontKey)
	DisableContainer(container)

	local retired = parentFrame.Triage_retiredSecureAuraIndicators
	if not retired then
		retired = {}
		parentFrame.Triage_retiredSecureAuraIndicators = retired
	end
	local slots = retired[position]
	if not slots then
		slots = {}
		retired[position] = slots
	end
	slots[#slots + 1] = container

	for index = 1, #slots do
		if SameRebuildSettings(slots[index], profile, fontKey) then
			local reused = table.remove(slots, index)
			parentFrame.Triage_secureAuraIndicators[position] = reused
			return reused
		end
	end

	parentFrame.Triage_secureAuraIndicators[position] = nil
	return nil
end

function Triage:DisableSecureAuraIndicator(parentFrame, position)
	local containers = parentFrame.Triage_secureAuraIndicators
	local container = containers and containers[position]
	if not container then
		return
	end
	if InCombatLockdown() then
		-- Hiding an addon-owned child of a compact frame is what ClearIndicator already
		-- does in combat. SetEnabled waits for the post-combat flush.
		HideContainer(container)
		self:QueueSecureAuraIndicatorRefresh(parentFrame)
		return
	end
	DisableContainer(container)
end

function Triage:InvalidateSecureAuraIndicators(parentFrame)
	if not parentFrame.Triage_secureAuraIndicators then
		return
	end
	if InCombatLockdown() then
		for _, container in pairs(parentFrame.Triage_secureAuraIndicators) do
			HideContainer(container)
		end
		self:QueueSecureAuraIndicatorRefresh(parentFrame)
		return
	end
	for _, container in pairs(parentFrame.Triage_secureAuraIndicators) do
		DisableContainer(container)
	end
end

-- The capability latch and the deferred notice are two independent facts, each with its own
-- guard. The pre-build now runs the probe at the first eligible pass, out of combat, whether or
-- not the player is restricted, so latching alone would show an encounter-scoped warning to a
-- player who may never enter restricted content. The print waits for the first pass where
-- restricted is true, on its own one-shot flag, so the message is always true when it fires.
local function ReportCapabilityFailure(addon, restricted)
	addon.Triage_secureAuraCapability = false
	if restricted and not addon.Triage_reportedSecureAuraUnavailable then
		addon.Triage_reportedSecureAuraUnavailable = true
		addon:Print(L["secureAuraUnavailable"])
	end
end

local function ReportMissingOnlyUnsupported(addon)
	if addon.Triage_reportedMissingOnlyLimit then
		return
	end
	addon.Triage_reportedMissingOnlyLimit = true
	addon:Print(L["secureAuraMissingOnlyUnsupported"])
end

local function CreateSecureAuraIndicator(addon, parentFrame, position, unit, spellIDs, fontKey, auraIdentifiers, spells, restricted)
	local profile = addon.db.profile["indicator-" .. position]
	local fontPath = GetIndicatorFontPath(addon)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, parentFrame, "CustomAuraContainerTemplate")
	if not ok or not container or type(container.AddAuraSlot) ~= "function" or type(container.SetUnit) ~= "function" or
		type(container.SetEnabled) ~= "function" then
		ReportCapabilityFailure(addon, restricted)
		return false
	end

	-- A CustomAuraContainerTemplate frame is shown the instant CreateFrame returns (the XML sets
	-- no hidden attribute; UI.xsd defaults it false). Hiding before anything else runs is what
	-- keeps ShouldRegisterForDynamicEvents false through SetEnabled and SetUnit below, so a
	-- retained pre-build never registers UNIT_AURA or draws for even one frame.
	container:Hide()

	local slotOK, auraFrame = pcall(container.AddAuraSlot, container, GetSlotKey(position), "HELPFUL", {
		initializeFrame = function(frame)
			InitializeSecureAuraButton(frame, profile, fontPath)
		end,
		candidateFilters = GetCandidateFilters(profile, spellIDs),
	})
	if not slotOK or not auraFrame then
		ReportCapabilityFailure(addon, restricted)
		return false
	end

	container.Triage_spellIDs = spellIDs
	RecordSpellIDs(container, auraIdentifiers, spells, spellIDs)
	container.Triage_casterFilter = profile.casterFilter
	RecordRebuildSettings(container, profile, fontKey)
	container:SetEnabled(true)
	container:SetUnit(unit)
	container.Triage_unit = unit
	ApplySecureAuraIndicatorAppearance(addon, parentFrame, position, container)

	parentFrame.Triage_secureAuraIndicators = parentFrame.Triage_secureAuraIndicators or {}
	parentFrame.Triage_secureAuraIndicators[position] = container
	addon.Triage_secureAuraCapability = true

	if restricted then
		ShowContainer(container)
		return true
	end
	return false
end

function Triage:EnsureSecureAuraIndicator(parentFrame, position, unit, auraIdentifiers)
	-- This gate must be first: Classic never resolves secure spell IDs or touches Retail frames.
	if self.isRetail ~= true then
		self:DisableSecureAuraIndicator(parentFrame, position)
		return false
	end

	local profile = self.db.profile["indicator-" .. position]
	if not profile or (profile.meOnly and not UnitIsUnit(unit, "player")) then
		self:DisableSecureAuraIndicator(parentFrame, position)
		return false
	end

	-- A readable pass pre-builds the container -- unit bound, filters set -- so a restricted
	-- pass later finds it already current and only has to show it. restricted selects retained
	-- versus live below, and feeds the deferred capability notice at gate 3.
	local restricted = parentFrame.Triage_auraDataRestricted == true

	if self.Triage_secureAuraCapability == false then
		ReportCapabilityFailure(self, restricted)
		self:DisableSecureAuraIndicator(parentFrame, position)
		return false
	end

	-- Nothing configured for this position: nothing to resolve, and nothing to allocate for.
	if not auraIdentifiers[1] then
		self:DisableSecureAuraIndicator(parentFrame, position)
		return false
	end

	local containers = parentFrame.Triage_secureAuraIndicators
	local container = containers and containers[position]
	local spellIDs, spells = GetSpellIDs(self, auraIdentifiers, container)
	if not HasSpellIDs(spellIDs) then
		self:DisableSecureAuraIndicator(parentFrame, position)
		return false
	end

	-- Below the gates above on purpose: an indicator with nothing configured, or with a name
	-- this character cannot cast, has nothing to say about missingOnly and must not announce it.
	-- While readable, the readable matcher already owns this position and the secure limitation
	-- has nothing to say yet, so it falls through with no notice, same as any other readable
	-- position. Only a restricted pass claims and clears it: a slot shows its button only when a
	-- matching aura exists (CustomAuraButtonPrivateMixin:ApplyVisibility), so absence has no
	-- secure form, and the readable cache cannot rule out the secret aura it would have to miss.
	if profile.missingOnly then
		if not restricted then
			self:DisableSecureAuraIndicator(parentFrame, position)
			return false
		end
		-- Claim the indicator and leave it cleared rather than assert a false "missing".
		ReportMissingOnlyUnsupported(self)
		self:DisableSecureAuraIndicator(parentFrame, position)
		return true
	end

	local fontKey = self.db.profile.indicatorFont
	if InCombatLockdown() then
		if not container or container.Triage_unit ~= unit or container.Triage_casterFilter ~= profile.casterFilter or
			container.Triage_keepVisible ~= self.db.profile.keepIndicatorsVisible or
			not SameSpellIDs(container.Triage_spellIDs, spellIDs) or
			not SameRebuildSettings(container, profile, fontKey) then
			if container then
				HideContainer(container)
			end
			self:QueueSecureAuraIndicatorRefresh(parentFrame)
			return false
		end
		-- Written on every in-combat match -- the restricted ending that shows the container and
		-- the readable ending that retains it alike. Keeping the container's own memo current is
		-- what lets the next pass's SameSpellIDs short-circuit on table identity instead of
		-- walking the set, so one SPELLS_CHANGED invalidation does not cost every later update in
		-- the fight for as long as combat lasts.
		RecordSpellIDs(container, auraIdentifiers, spells, container.Triage_spellIDs)
		if restricted then
			ShowContainer(container)
			return true
		end
		RetainContainer(container)
		return false
	end

	if container and not SameRebuildSettings(container, profile, fontKey) then
		local armed = parentFrame.Triage_secureAuraRebuildArmed
		if armed and armed[position] then
			-- Consume the arm before rebuilding: if the rebuild or the rest of this UpdateIndicators
			-- pass throws, the flush never reaches its own clear and the frame would stay armed.
			armed[position] = nil
			container = RebuildSecureAuraIndicator(parentFrame, position, container, profile, fontKey)
		else
			-- Keep showing the current visual and let the settings settle first. Rebuilding
			-- here would allocate a container per sample of a color or opacity drag, and
			-- Blizzard can never reclaim any of them.
			self:QueueSecureAuraIndicatorRebuild(parentFrame, position, profile, fontKey)
		end
	end

	if container then
		if not SameSpellIDs(container.Triage_spellIDs, spellIDs) or
			container.Triage_casterFilter ~= profile.casterFilter then
			local updated = pcall(container.SetAuraSlotCandidateFilters, container, GetSlotKey(position),
				GetCandidateFilters(profile, spellIDs))
			if not updated then
				DisableContainer(container)
				container = nil
			else
				container.Triage_spellIDs = spellIDs
				container.Triage_casterFilter = profile.casterFilter
			end
		end
		if container then
			RecordSpellIDs(container, auraIdentifiers, spells, container.Triage_spellIDs)
			container:SetUnit(unit)
			container.Triage_unit = unit
			ApplySecureAuraIndicatorAppearance(self, parentFrame, position, container)
			if restricted then
				ShowContainer(container)
				return true
			end
			-- A retained target must leave here enabled: an invalidated container was disabled
			-- by DisableContainer, and once combat starts only Show()/Hide() are safe to call on
			-- it, so the in-combat Show() on a later restricted pass needs it enabled now.
			container:SetEnabled(true)
			RetainContainer(container)
			return false
		end
	end

	return CreateSecureAuraIndicator(self, parentFrame, position, unit, spellIDs, fontKey, auraIdentifiers, spells, restricted)
end
