-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals IsInGroup IsInInstance UnitHealth UnitHealthMax UnitIsConnected UnitCanAssist
-- luacheck: globals UnitGetIncomingHeals UnitGroupRolesAssigned GetSpecialization GetSpecializationInfo

local Triage = _G.Triage
local LibRangeCheck = LibStub("LibRangeCheck-3.0")
local LibCustomGlow = LibStub("LibCustomGlow-1.0")

local GLOW_ALPHA = 0.85
local MIN_UPDATE_INTERVAL = 0.1
local DEFAULT_UPDATE_INTERVAL = 0.3

local HEALER_SPEC_IDS = {
	[65] = true,    -- Holy Paladin
	[105] = true,   -- Restoration Druid
	[256] = true,   -- Discipline Priest
	[257] = true,   -- Holy Priest
	[264] = true,   -- Restoration Shaman
	[270] = true,   -- Mistweaver Monk
	[1468] = true,  -- Preservation Evoker
}

local AUTO_HEAL_RANGE_BY_CLASS = {
	DRUID = 40,
	EVOKER = 30,
	MONK = 40,
	PALADIN = 40,
	PRIEST = 40,
	SHAMAN = 40,
}

local TRIAGE_FOCUS_UNIT_PREFIXES = {
	player = true,
	party = true,
	raid = true,
}

local function IsSecretValue(value)
	return issecretvalue and issecretvalue(value)
end

local function SafeNumber(value)
	if IsSecretValue(value) or type(value) ~= "number" then
		return nil
	end

	return value
end

local function GetProfile(addon)
	return addon.db and addon.db.profile and addon.db.profile.triageFocus
end

local function StopFocusGlow(overlay)
	if overlay.glowTarget then
		LibCustomGlow.ButtonGlow_Stop(overlay.glowTarget)
	end
	LibCustomGlow.ButtonGlow_Stop(overlay)
	if overlay.procGlowHost then
		LibCustomGlow.ButtonGlow_Stop(overlay.procGlowHost)
		overlay.procGlowHost:Hide()
	end
	overlay.glowVisible = nil
	overlay.currentGlowStyle = nil
	overlay.currentGlowWidth = nil
	overlay.currentGlowHeight = nil
	overlay.glowTarget = nil
end

local function GetFocusGlowTarget(frame, overlay)
	if not overlay.procGlowHost then
		local host = CreateFrame("Frame", nil, UIParent)
		host:EnableMouse(false)
		host:Hide()
		overlay.procGlowHost = host
	end

	local host = overlay.procGlowHost
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", frame, "TOPLEFT")
	host:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	host:SetFrameStrata(frame:GetFrameStrata())
	host:SetFrameLevel(frame:GetFrameLevel() + 20)
	host:Show()
	return host
end

local function EnsureFocusGlow(frame, overlay, color, glowStyle)
	local glowTarget = GetFocusGlowTarget(frame, overlay)
	local width, height = glowTarget:GetSize()
	local needsRefresh = not overlay.glowVisible
		or overlay.currentGlowStyle ~= glowStyle
		or overlay.currentGlowWidth ~= width
		or overlay.currentGlowHeight ~= height
		or overlay.glowTarget ~= glowTarget

	if not needsRefresh then
		return
	end

	StopFocusGlow(overlay)
	LibCustomGlow.ButtonGlow_Start(glowTarget, { color[1], color[2], color[3], GLOW_ALPHA })
	overlay.glowVisible = true
	overlay.currentGlowStyle = glowStyle
	overlay.currentGlowWidth = width
	overlay.currentGlowHeight = height
	overlay.glowTarget = glowTarget
end

local function TryRetailIncomingHeals(unit)
	local calculator = rawget(_G, "UnitHealPredictionCalculator")
	local curveUtil = rawget(_G, "C_CurveUtil")
	if type(calculator) ~= "table" or type(curveUtil) ~= "table" then
		return nil
	end

	local method = calculator.GetIncomingHeals
		or calculator.GetTotalIncomingHeals
		or calculator.CalculateIncomingHeals
	if type(method) ~= "function" then
		return nil
	end

	local ok, value = pcall(method, calculator, unit)
	if ok then
		return SafeNumber(value)
	end

	return nil
end

local function GetLegacyIncomingHeals(unit)
	if type(UnitGetIncomingHeals) ~= "function" then
		return 0
	end

	local ok, value = pcall(UnitGetIncomingHeals, unit)
	if ok then
		return SafeNumber(value) or 0
	end

	return 0
end

local function IsInInstancedGroup()
	if not (IsInGroup() or IsInRaid()) then
		return false
	end

	if type(IsInInstance) ~= "function" then
		return true
	end

	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType ~= "none"
end

local function IsDispelOverlayVisible(frame)
	return frame.Triage_dispelOverlay and frame.Triage_dispelOverlay:IsShown()
end

function Triage:GetTriageFocusUpdateInterval()
	local profile = GetProfile(self)
	local interval = profile and tonumber(profile.updateInterval) or DEFAULT_UPDATE_INTERVAL
	if not interval or interval < MIN_UPDATE_INTERVAL then
		return DEFAULT_UPDATE_INTERVAL
	end

	return interval
end

function Triage:IsCurrentSpecHealer()
	if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
		local specIndex = GetSpecialization()
		local specID = specIndex and GetSpecializationInfo(specIndex)
		if specID and HEALER_SPEC_IDS[specID] then
			return true
		end
	end

	if type(UnitGroupRolesAssigned) == "function" then
		return UnitGroupRolesAssigned("player") == "HEALER"
	end

	return false
end

function Triage:IsTriageFocusActive()
	local profile = GetProfile(self)
	if not profile or not profile.enabled then
		return false
	end

	if not IsInInstancedGroup() then
		return false
	end

	return profile.forceEnabled or self:IsCurrentSpecHealer()
end

function Triage:GetTriageFocusRange()
	local profile = GetProfile(self)
	if not profile then
		return 40
	end

	if profile.rangeMode == "fixed" then
		return profile.fixedRange or 40
	end

	local _, classFile = UnitClass("player")
	return AUTO_HEAL_RANGE_BY_CLASS[classFile] or 40
end

function Triage:GetTriageFocusIncomingHeals(unit)
	if not self.isWoWClassicEra and not self.isWoWClassic then
		local retailIncoming = TryRetailIncomingHeals(unit)
		if retailIncoming then
			return retailIncoming
		end
	end

	return GetLegacyIncomingHeals(unit)
end

function Triage:CreateTriageFocusOverlay(frame)
	if frame.Triage_focusOverlay then
		return
	end

	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(frame:GetFrameLevel() + 1)
	overlay.edges = {}

	for _, spec in ipairs({
		{"TOPLEFT", "TOPRIGHT", "height"},
		{"BOTTOMLEFT", "BOTTOMRIGHT", "height"},
		{"TOPLEFT", "BOTTOMLEFT", "width"},
		{"TOPRIGHT", "BOTTOMRIGHT", "width"},
	}) do
		local edge = overlay:CreateTexture(nil, "OVERLAY")
		edge:SetColorTexture(1, 1, 1, 1)
		edge:SetPoint(spec[1])
		edge:SetPoint(spec[2])
		overlay.edges[#overlay.edges + 1] = edge
	end

	overlay:Hide()
	overlay:SetScript("OnHide", function(hiddenOverlay)
		StopFocusGlow(hiddenOverlay)
	end)
	frame.Triage_focusOverlay = overlay
end

function Triage:ShowTriageFocusOverlay(frame)
	if IsDispelOverlayVisible(frame) then
		self:HideTriageFocusOverlay(frame)
		return
	end

	if not frame.Triage_focusOverlay then
		self:CreateTriageFocusOverlay(frame)
	end

	local profile = GetProfile(self)
	local overlay = frame.Triage_focusOverlay
	if not profile or not overlay then
		return
	end

	local width = profile.width or 2
	local color = profile.color or { 0.1, 0.85, 1, 0.9 }
	local glowStyle = profile.glowStyle or "both"

	for index, edge in ipairs(overlay.edges) do
		edge:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		if index <= 2 then
			edge:SetHeight(width)
		else
			edge:SetWidth(width)
		end
		if glowStyle == "border" or glowStyle == "both" then
			edge:Show()
		else
			edge:Hide()
		end
	end

	overlay:Show()
	if glowStyle == "pulse" or glowStyle == "both" then
		EnsureFocusGlow(frame, overlay, color, glowStyle)
	else
		StopFocusGlow(overlay)
	end
end

function Triage:HideTriageFocusOverlay(frame)
	local overlay = frame and frame.Triage_focusOverlay
	if not overlay then
		return
	end

	overlay:Hide()
	StopFocusGlow(overlay)
end

function Triage:HideAllTriageFocusOverlays()
	self.Triage_focusWinnerFrame = nil
	self.Triage_focusWinnerUnit = nil
	self:ForEachManagedFrame(function(frame)
		self:HideTriageFocusOverlay(frame)
	end)
end

function Triage:GetTriageFocusCandidateScore(frame, rangeChecker)
	if not self.ShouldContinue(frame, false, TRIAGE_FOCUS_UNIT_PREFIXES) then
		return nil
	end

	local unit = self:GetManagedFrameUnit(frame)
	if not unit or not UnitExists(unit) or not UnitCanAssist("player", unit) then
		return nil
	end
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		return nil
	end
	if not rangeChecker or not rangeChecker(unit) then
		return nil
	end

	local health = SafeNumber(UnitHealth(unit))
	local maxHealth = SafeNumber(UnitHealthMax(unit))
	if not health or not maxHealth or maxHealth <= 0 then
		return nil
	end

	local deficit = maxHealth - health
	if deficit <= 0 then
		return nil
	end

	local profile = GetProfile(self)
	local minDeficitPercent = profile and profile.minDeficitPercent or 15
	local minDeficit = maxHealth * (minDeficitPercent / 100)
	local incoming = self:GetTriageFocusIncomingHeals(unit)
	local score = deficit - incoming
	if score < minDeficit then
		return nil
	end

	return score, unit, health / maxHealth
end

function Triage:UpdateTriageFocus()
	if not self:IsTriageFocusActive() then
		self:HideAllTriageFocusOverlays()
		return
	end

	local range = self:GetTriageFocusRange()
	local rangeChecker = LibRangeCheck:GetFriendMinChecker(range)
	if not rangeChecker then
		self:HideAllTriageFocusOverlays()
		return
	end

	local bestFrame, bestUnit, bestScore, bestHealthPercent
	self:ForEachManagedFrame(function(frame)
		local score, unit, healthPercent = self:GetTriageFocusCandidateScore(frame, rangeChecker)
		if score and (
			not bestScore
			or score > bestScore
			or (score == bestScore and healthPercent < bestHealthPercent)
		) then
			bestFrame = frame
			bestUnit = unit
			bestScore = score
			bestHealthPercent = healthPercent
		end
	end)

	self:ForEachManagedFrame(function(frame)
		if frame == bestFrame then
			self:ShowTriageFocusOverlay(frame)
		else
			self:HideTriageFocusOverlay(frame)
		end
	end)

	self.Triage_focusWinnerFrame = bestFrame
	self.Triage_focusWinnerUnit = bestUnit
end

function Triage:UpdateTriageFocusForUnit(unit)
	if not unit or not self.Triage_focusWinnerUnit then
		return
	end
	if UnitIsUnit(unit, self.Triage_focusWinnerUnit) then
		self:UpdateTriageFocus()
	end
end
