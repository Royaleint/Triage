-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)

local EnhancedRaidFrames = _G.EnhancedRaidFrames
local LibDispel = LibStub("LibDispel-1.0")

-- Dispel type priority order (highest to lowest)
local PRIORITY_ORDER = {"Magic", "Curse", "Disease", "Poison", "Bleed"}

-- Border thickness in pixels
local BORDER_THICKNESS = 2

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Create the dispel overlay on a raid frame (edge border + glow host)
---@param frame table @The compact unit frame
function EnhancedRaidFrames:CreateDispelOverlay(frame)
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

--- Check frame.dispels and update the overlay
---@param frame table @The compact unit frame
function EnhancedRaidFrames:UpdateDispelOverlay(frame)
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
	local inRaid = IsInRaid()
	if inRaid and not self.db.profile.dispelOverlay.showInRaid then
		self:HideDispelOverlay(frame)
		return
	end
	if not inRaid and not self.db.profile.dispelOverlay.showInParty then
		self:HideDispelOverlay(frame)
		return
	end

	-- Read Blizzard's frame.dispels (PriorityTable per type)
	if not frame.dispels then
		self:HideDispelOverlay(frame)
		return
	end

	local myDispels = LibDispel:GetMyDispelTypes()
	local bestType = nil

	if self.db.profile.dispelOverlay.priorityOnly then
		-- Priority mode: show highest-priority type the player can dispel
		for _, dispelType in ipairs(PRIORITY_ORDER) do
			if myDispels[dispelType] then
				local pt = frame.dispels[dispelType]
				if pt and pt:Size() > 0 then
					bestType = dispelType
					break
				end
			end
		end
	else
		-- Any mode: show if the player can dispel ANY present debuff type
		for _, dispelType in ipairs(PRIORITY_ORDER) do
			if myDispels[dispelType] then
				local pt = frame.dispels[dispelType]
				if pt and pt:Size() > 0 then
					bestType = dispelType
					break
				end
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

	if self.db.profile.dispelOverlay.colorByType then
		SetBorderColor(overlay, color.r, color.g, color.b, alpha)
	else
		SetBorderColor(overlay, 1, 1, 1, alpha)
	end

	overlay:Show()

	-- Track current type for glow management
	local previousType = overlay.currentDispelType
	overlay.currentDispelType = dispelType

	-- Glow effect
	local glowStyle = self.db.profile.dispelOverlay.glowStyle
	if glowStyle == "pulse" or glowStyle == "both" then
		-- Only trigger glow on new dispel appearance, not every update
		if not previousType then
			if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert then
				ActionButtonSpellAlertManager:ShowAlert(overlay)
			elseif ActionButton_ShowOverlayGlow then
				ActionButton_ShowOverlayGlow(overlay)
			end
		end
	elseif glowStyle == "border" then
		-- Border only — ensure glow is off
		if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.HideAlert then
			ActionButtonSpellAlertManager:HideAlert(overlay)
		elseif ActionButton_HideOverlayGlow then
			ActionButton_HideOverlayGlow(overlay)
		end
	end
end

--- Hide the dispel overlay and remove glow
---@param frame table @The compact unit frame
function EnhancedRaidFrames:HideDispelOverlay(frame)
	local overlay = frame.ERF_dispelOverlay
	if not overlay then return end

	overlay:Hide()
	overlay.currentDispelType = nil

	if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.HideAlert then
		ActionButtonSpellAlertManager:HideAlert(overlay)
	elseif ActionButton_HideOverlayGlow then
		ActionButton_HideOverlayGlow(overlay)
	end
end

--- Update all dispel overlays on all frames
function EnhancedRaidFrames:UpdateAllDispelOverlays()
	self.ApplyToAllFrames(function(frame)
		self:UpdateDispelOverlay(frame)
	end)
end
