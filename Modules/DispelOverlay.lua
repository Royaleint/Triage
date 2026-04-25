-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals UnitIsConnected

local EnhancedRaidFrames = _G.EnhancedRaidFrames
local LibDispel = LibStub("LibDispel-1.0")
local LibCustomGlow = LibStub("LibCustomGlow-1.0")

-- Dispel type priority order (highest to lowest)
local PRIORITY_ORDER = {"Magic", "Curse", "Disease", "Poison", "Bleed"}

-- Border thickness in pixels
local BORDER_THICKNESS = 2
local GLOW_ALPHA = 0.85
local GLOW_UPDATE_INTERVAL = 0.2

local StopGlow, GetGlowColor, EnsureGlow

-------------------------------------------------------------------------
-------------------------------------------------------------------------

local function GetGlowTarget(frame, overlay)
	if frame.ERF_isTestFrame then
		return overlay
	end

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

local function GetPreviewDispelType(frame)
	local previewData = frame.ERF_testData
	if not previewData or previewData.status ~= "alive" then
		return nil
	end

	if not previewData.dispelType then
		return nil
	end

	local myDispels = LibDispel:GetMyDispelTypes()
	if not myDispels[previewData.dispelType] then
		return nil
	end

	return previewData.dispelType
end

--- Create the dispel overlay on a raid frame (edge border + glow host)
---@param frame table @The compact unit frame
function EnhancedRaidFrames:CreateDispelOverlay(frame)
	if not frame then
		return
	end

	if frame.ERF_dispelOverlay then
		return
	end

	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(frame:GetFrameLevel() + 2)

	-- Programmatic 4-edge border
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
		if spec[3] == "height" then
			edge:SetHeight(BORDER_THICKNESS)
		else
			edge:SetWidth(BORDER_THICKNESS)
		end
		overlay.edges[#overlay.edges + 1] = edge
	end

	overlay:Hide()
	overlay:SetScript("OnHide", function(hiddenOverlay)
		StopGlow(hiddenOverlay)
	end)
	overlay:SetScript("OnUpdate", function(hiddenOverlay, elapsed)
		hiddenOverlay.elapsedSinceStateCheck = (hiddenOverlay.elapsedSinceStateCheck or 0) + elapsed
		if hiddenOverlay.elapsedSinceStateCheck < GLOW_UPDATE_INTERVAL then
			return
		end

		hiddenOverlay.elapsedSinceStateCheck = 0
		if not hiddenOverlay.currentDispelType then
			return
		end

		if not EnhancedRaidFrames.ShouldContinue(frame, true) then
			EnhancedRaidFrames:HideDispelOverlay(frame)
			return
		end

		local useTypeColor = EnhancedRaidFrames.db.profile.dispelOverlay.colorByType
		local glowStyle = EnhancedRaidFrames.db.profile.dispelOverlay.glowStyle
		if useTypeColor and glowStyle ~= "pulse" and glowStyle ~= "both" then
			StopGlow(hiddenOverlay)
			return
		end

		if frame.ERF_isTestFrame then
			local previewType = GetPreviewDispelType(frame)
			if not previewType then
				StopGlow(hiddenOverlay)
				return
			end

			local debuffColors = LibDispel:GetDebuffTypeColor()
			local color = debuffColors[previewType] or debuffColors["None"]
			local glowColor = GetGlowColor(useTypeColor, color)
			local glowState = useTypeColor and previewType or "neutral"
			EnsureGlow(frame, hiddenOverlay, previewType, glowColor, glowState)
			return
		end

		local unit = frame.displayedUnit or frame.unit
		if not unit or not UnitExists(unit) or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
			StopGlow(hiddenOverlay)
			return
		end

		local debuffColors = LibDispel:GetDebuffTypeColor()
		local color = debuffColors[hiddenOverlay.currentDispelType] or debuffColors["None"]
		local glowColor = GetGlowColor(useTypeColor, color)
		local glowState = useTypeColor and hiddenOverlay.currentDispelType or "neutral"
		EnsureGlow(frame, hiddenOverlay, hiddenOverlay.currentDispelType, glowColor, glowState)
	end)
	frame.ERF_dispelOverlay = overlay
end

--- Set the edge border color on an overlay
---@param overlay table @The overlay frame
---@param r number @Red
---@param g number @Green
---@param b number @Blue
---@param a number @Alpha
local function SetBorderColor(overlay, r, g, b, a)
	for _, edge in ipairs(overlay.edges) do
		edge:SetColorTexture(r, g, b, a)
	end
end

--- Return the LibCustomGlow color for the current overlay settings
---@param useTypeColor boolean @Whether to color by dispel type
---@param color table @LibDispel color table
---@return table
GetGlowColor = function(useTypeColor, color)
	if useTypeColor and color then
		return {color.r, color.g, color.b, GLOW_ALPHA}
	end

	return nil
end

--- Stop and clear the current glow state on an overlay
---@param overlay table @The overlay frame
StopGlow = function(overlay)
	if overlay.glowTarget then
		LibCustomGlow.ButtonGlow_Stop(overlay.glowTarget)
	end
	LibCustomGlow.ButtonGlow_Stop(overlay)
	if overlay.procGlowHost then
		LibCustomGlow.ButtonGlow_Stop(overlay.procGlowHost)
		overlay.procGlowHost:Hide()
	end
	overlay.glowVisible = nil
	overlay.currentGlowState = nil
	overlay.currentGlowWidth = nil
	overlay.currentGlowHeight = nil
end

--- Ensure the overlay glow matches the current dispel type and frame size
---@param frame table @The compact unit frame
---@param overlay table @The overlay frame
---@param dispelType string @The debuff type to display
---@param glowColor table @RGBA color array for LibCustomGlow
---@param glowState string @State key used to detect color changes
EnsureGlow = function(frame, overlay, dispelType, glowColor, glowState)
	local glowTarget = GetGlowTarget(frame, overlay)
	local width, height = glowTarget:GetSize()
	local needsRefresh = not overlay.glowVisible
		or overlay.currentGlowState ~= glowState
		or overlay.currentDispelType ~= dispelType
		or overlay.currentGlowWidth ~= width
		or overlay.currentGlowHeight ~= height
		or overlay.glowTarget ~= glowTarget

	if not needsRefresh then
		return
	end

	-- ProcGlow uses Retail-only FlipBook animations and is intentionally unused here.
	-- ButtonGlow is the compatible LibCustomGlow path across Retail, Classic Era, and Pandaria Classic.
	StopGlow(overlay)
	LibCustomGlow.ButtonGlow_Start(glowTarget, glowColor)
	overlay.glowVisible = true
	overlay.currentGlowState = glowState
	overlay.currentGlowWidth = width
	overlay.currentGlowHeight = height
	overlay.glowTarget = glowTarget
end

--- Check frame.dispels and update the overlay
---@param frame table @The compact unit frame
function EnhancedRaidFrames:UpdateDispelOverlay(frame)
	if not self.ShouldContinue(frame, true) then
		if frame.ERF_dispelOverlay then
			self:HideDispelOverlay(frame)
		end
		return
	end

	if not self.db.profile.dispelOverlay.enabled then
		if frame.ERF_dispelOverlay then
			self:HideDispelOverlay(frame)
		end
		return
	end

	-- Create overlay on demand
	if not frame.ERF_dispelOverlay then
		self:CreateDispelOverlay(frame)
	end

	-- Respect party/raid toggle
	local inRaid = (frame.ERF_isTestFrame and self.testModeState and self.testModeState.size > 5) or IsInRaid()
	if inRaid and not self.db.profile.dispelOverlay.showInRaid then
		self:HideDispelOverlay(frame)
		return
	end
	if not inRaid and not self.db.profile.dispelOverlay.showInParty then
		self:HideDispelOverlay(frame)
		return
	end

	if frame.ERF_isTestFrame then
		local previewType = GetPreviewDispelType(frame)
		if previewType then
			self:ShowDispelOverlay(frame, previewType)
		else
			self:HideDispelOverlay(frame)
		end
		return
	end

	-- Read Blizzard's frame.dispels (PriorityTable per type)
	if not frame.dispels then
		self:HideDispelOverlay(frame)
		return
	end

	-- Find the highest-priority dispel type the player can handle
	-- Priority order: Magic > Curse > Disease > Poison > Bleed
	local myDispels = LibDispel:GetMyDispelTypes()
	local bestType = nil

	for _, dispelType in ipairs(PRIORITY_ORDER) do
		if myDispels[dispelType] then
			local pt = frame.dispels[dispelType]
			if pt and pt:Size() > 0 then
				bestType = dispelType
				break
			end
		end
	end

	if bestType then
		self:ShowDispelOverlay(frame, bestType)
	else
		self:HideDispelOverlay(frame)
	end
end

--- Show the dispel overlay with color and optional glow
---@param frame table @The compact unit frame
---@param dispelType string @The debuff type to display
function EnhancedRaidFrames:ShowDispelOverlay(frame, dispelType)
	local overlay = frame.ERF_dispelOverlay
	if not overlay then return end

	local debuffColors = LibDispel:GetDebuffTypeColor()
	local color = debuffColors[dispelType] or debuffColors["None"]
	local alpha = self.db.profile.dispelOverlay.borderAlpha
	local useTypeColor = self.db.profile.dispelOverlay.colorByType

	local glowStyle = self.db.profile.dispelOverlay.glowStyle

	if not useTypeColor then
		for _, edge in ipairs(overlay.edges) do
			edge:Hide()
		end
		overlay:Show()
		overlay.currentDispelType = dispelType
		EnsureGlow(frame, overlay, dispelType, GetGlowColor(false, color), "neutral")
		return
	end

	-- Border: show edges for "border" and "both", hide for "pulse" only
	if glowStyle == "border" or glowStyle == "both" then
		SetBorderColor(overlay, color.r, color.g, color.b, alpha)
		for _, edge in ipairs(overlay.edges) do
			edge:Show()
		end
	else
		for _, edge in ipairs(overlay.edges) do
			edge:Hide()
		end
	end

	overlay:Show()

	-- Glow: show for "pulse" and "both", hide for "border" only
	if glowStyle == "pulse" or glowStyle == "both" then
		EnsureGlow(frame, overlay, dispelType, GetGlowColor(true, color), dispelType)
	else
		StopGlow(overlay)
	end

	overlay.currentDispelType = dispelType
end

--- Hide the dispel overlay and remove glow
---@param frame table @The compact unit frame
function EnhancedRaidFrames:HideDispelOverlay(frame)
	local overlay = frame.ERF_dispelOverlay
	if not overlay then return end

	overlay:Hide()
	overlay.currentDispelType = nil

	StopGlow(overlay)
end

--- Update all dispel overlays on all frames
function EnhancedRaidFrames:UpdateAllDispelOverlays()
	self:ForEachManagedFrame(function(frame)
		self:UpdateDispelOverlay(frame)
	end)
end
