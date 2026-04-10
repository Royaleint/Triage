-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals RAID_CLASS_COLORS DEAD PLAYER_OFFLINE
-- luacheck: globals LOCALIZED_CLASS_NAMES_MALE LOCALIZED_CLASS_NAMES_FEMALE

local EnhancedRaidFrames = _G.EnhancedRaidFrames

local FRAME_WIDTH = 88
local FRAME_HEIGHT = 42
local POWER_BAR_HEIGHT = 5
local COLUMN_SPACING = 10
local ROW_SPACING = 6
local FLOATING_TEXT_DURATION = 1.5
local HEAL_ANIMATION_DURATION = 0.2
local SIMULATED_HEAL_FRACTION = 0.15
local HEALTH_STATE_COLORS = {
	full = {0.18, 0.72, 0.33},
	injured = {0.86, 0.72, 0.2},
	critical = {0.85, 0.22, 0.22},
	dead = {0.38, 0.38, 0.38},
	offline = {0.28, 0.28, 0.28},
}

local RefreshSingleTestModeFrame

local function GetClassColor(classFile)
	local classColors = RAID_CLASS_COLORS
	if classColors and classColors[classFile] then
		return classColors[classFile].r, classColors[classFile].g, classColors[classFile].b
	end

	return 1, 1, 1
end

local function GetGroupLayout(size)
	local rows = math.min(size, 5)
	local columns = math.ceil(size / 5)
	return columns, rows
end

local function GetLocalizedClassName(classFile)
	return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile])
		or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile])
		or classFile
		or ""
end

local function UpdateMemberHealthState(member)
	local percent = member.maxHealth > 0 and member.currentHealth / member.maxHealth or 0
	member.status = "alive"
	if percent >= 0.95 then
		member.healthState = "full"
	elseif percent >= 0.45 then
		member.healthState = "injured"
	else
		member.healthState = "critical"
	end
end

local function UpdateFrameVisuals(frame)
	local member = frame.ERF_testData
	if not member then
		return
	end

	frame.ERF_nameText:SetText(member.displayName)
	frame.ERF_healthBar:SetMinMaxValues(0, member.maxHealth)
	frame.ERF_healthBar:SetValue(member.currentHealth)
	frame.powerBar:SetMinMaxValues(0, member.maxPower)
	frame.powerBar:SetValue(member.currentPower)

	local color = HEALTH_STATE_COLORS[member.healthState] or HEALTH_STATE_COLORS.full
	frame.ERF_healthBar:SetStatusBarColor(color[1], color[2], color[3], 1)

	if member.status == "dead" then
		frame.ERF_statusText:SetText(DEAD or "")
	elseif member.status == "offline" then
		frame.ERF_statusText:SetText(PLAYER_OFFLINE or "")
	else
		frame.ERF_statusText:SetText("")
	end

	frame:SetAlpha(member.status == "offline" and 0.7 or 1)
end

local function StopPreviewAnimations(frame)
	frame.ERF_healAnimation = nil
	frame.ERF_floatingTextState = nil
	frame:SetScript("OnUpdate", nil)
end

local function PreviewFrame_OnUpdate(frame, elapsed)
	local hasAnimation = false

	if frame.ERF_healAnimation then
		local animation = frame.ERF_healAnimation
		animation.elapsed = animation.elapsed + elapsed

		local progress = math.min(animation.elapsed / animation.duration, 1)
		local value = animation.startValue + ((animation.endValue - animation.startValue) * progress)
		frame.ERF_healthBar:SetValue(value)

		if progress >= 1 then
			frame.ERF_healthBar:SetValue(animation.endValue)
			frame.ERF_healAnimation = nil
		else
			hasAnimation = true
		end
	end

	if frame.ERF_floatingTextState then
		local textState = frame.ERF_floatingTextState
		textState.elapsed = textState.elapsed + elapsed

		local progress = math.min(textState.elapsed / textState.duration, 1)
		local alpha = 1 - progress
		frame.ERF_floatingText:SetAlpha(alpha)
		frame.ERF_floatingText:ClearAllPoints()
		frame.ERF_floatingText:SetPoint("CENTER", frame, "CENTER", 0, 8 + (progress * 12))

		if progress >= 1 then
			frame.ERF_floatingText:Hide()
			frame.ERF_floatingTextState = nil
		else
			hasAnimation = true
		end
	end

	if not hasAnimation then
		StopPreviewAnimations(frame)
	end
end

local function ShowFloatingHealText(frame, amount)
	frame.ERF_floatingText:SetText(amount)
	frame.ERF_floatingText:SetTextColor(0.2, 1, 0.35, 1)
	frame.ERF_floatingText:SetAlpha(1)
	frame.ERF_floatingText:ClearAllPoints()
	frame.ERF_floatingText:SetPoint("CENTER", frame, "CENTER", 0, 8)
	frame.ERF_floatingText:Show()

	frame.ERF_floatingTextState = {
		elapsed = 0,
		duration = FLOATING_TEXT_DURATION,
	}
	frame:SetScript("OnUpdate", PreviewFrame_OnUpdate)
end

local function ShowPreviewTooltip(frame)
	local member = frame.ERF_testData
	if not member then
		return
	end

	local classR, classG, classB = GetClassColor(member.classFile)
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(member.displayName, 1, 1, 1)
	GameTooltip:AddLine(GetLocalizedClassName(member.classFile), classR, classG, classB)
	GameTooltip:AddLine(member.currentHealth .. " / " .. member.maxHealth, 0.85, 0.85, 0.85)
	GameTooltip:Show()
end

local function HandlePreviewFrameClick(frame)
	local member = frame.ERF_testData
	if not member or member.status ~= "alive" then
		return
	end

	local healAmount = math.floor(member.maxHealth * SIMULATED_HEAL_FRACTION + 0.5)
	local startValue = member.currentHealth
	member.currentHealth = math.min(member.maxHealth, member.currentHealth + healAmount)
	UpdateMemberHealthState(member)

	frame.ERF_healAnimation = {
		startValue = startValue,
		endValue = member.currentHealth,
		duration = HEAL_ANIMATION_DURATION,
		elapsed = 0,
	}

	ShowFloatingHealText(frame, healAmount)
	RefreshSingleTestModeFrame(EnhancedRaidFrames, frame, false)
end

local function CreatePreviewFrame(frameName)
	local frame = CreateFrame("Button", frameName, nil)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:EnableMouse(true)
	frame:RegisterForClicks("AnyUp")
	frame:Hide()

	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints()
	frame.background:SetColorTexture(0.06, 0.06, 0.06, 0.95)

	frame.ERF_healthBackground = frame:CreateTexture(nil, "BORDER")
	frame.ERF_healthBackground:SetPoint("TOPLEFT", 1, -1)
	frame.ERF_healthBackground:SetPoint("TOPRIGHT", -1, -1)
	frame.ERF_healthBackground:SetHeight(FRAME_HEIGHT - POWER_BAR_HEIGHT - 3)
	frame.ERF_healthBackground:SetColorTexture(0.13, 0.13, 0.13, 1)

	frame.ERF_healthBar = CreateFrame("StatusBar", nil, frame)
	frame.ERF_healthBar:SetPoint("TOPLEFT", 1, -1)
	frame.ERF_healthBar:SetPoint("TOPRIGHT", -1, -1)
	frame.ERF_healthBar:SetHeight(FRAME_HEIGHT - POWER_BAR_HEIGHT - 3)
	frame.ERF_healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	frame.healthBar = frame.ERF_healthBar

	frame.powerBar = CreateFrame("StatusBar", nil, frame)
	frame.powerBar:SetPoint("BOTTOMLEFT", 1, 1)
	frame.powerBar:SetPoint("BOTTOMRIGHT", -1, 1)
	frame.powerBar:SetHeight(POWER_BAR_HEIGHT)
	frame.powerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	frame.powerBar:SetStatusBarColor(0.18, 0.4, 0.84, 1)

	frame.ERF_nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.ERF_nameText:SetPoint("TOPLEFT", 4, -4)
	frame.ERF_nameText:SetPoint("TOPRIGHT", -4, -4)
	frame.ERF_nameText:SetJustifyH("LEFT")
	frame.name = frame.ERF_nameText

	frame.ERF_statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.ERF_statusText:SetPoint("CENTER", frame.ERF_healthBar, "CENTER", 0, 0)

	frame.ERF_floatingText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.ERF_floatingText:Hide()

	frame.ERF_borderTop = frame:CreateTexture(nil, "ARTWORK")
	frame.ERF_borderTop:SetPoint("TOPLEFT")
	frame.ERF_borderTop:SetPoint("TOPRIGHT")
	frame.ERF_borderTop:SetHeight(1)
	frame.ERF_borderTop:SetColorTexture(0.22, 0.22, 0.22, 1)

	frame.ERF_borderBottom = frame:CreateTexture(nil, "ARTWORK")
	frame.ERF_borderBottom:SetPoint("BOTTOMLEFT")
	frame.ERF_borderBottom:SetPoint("BOTTOMRIGHT")
	frame.ERF_borderBottom:SetHeight(1)
	frame.ERF_borderBottom:SetColorTexture(0.22, 0.22, 0.22, 1)

	frame.ERF_borderLeft = frame:CreateTexture(nil, "ARTWORK")
	frame.ERF_borderLeft:SetPoint("TOPLEFT")
	frame.ERF_borderLeft:SetPoint("BOTTOMLEFT")
	frame.ERF_borderLeft:SetWidth(1)
	frame.ERF_borderLeft:SetColorTexture(0.22, 0.22, 0.22, 1)

	frame.ERF_borderRight = frame:CreateTexture(nil, "ARTWORK")
	frame.ERF_borderRight:SetPoint("TOPRIGHT")
	frame.ERF_borderRight:SetPoint("BOTTOMRIGHT")
	frame.ERF_borderRight:SetWidth(1)
	frame.ERF_borderRight:SetColorTexture(0.22, 0.22, 0.22, 1)

	frame:SetScript("OnEnter", function()
		ShowPreviewTooltip(frame)
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	frame:SetScript("OnClick", function()
		HandlePreviewFrameClick(frame)
	end)

	return frame
end

--- Ensure the shared preview container and frame pool exist.
function EnhancedRaidFrames:InitializeTestModeFrames()
	if self.testModeFrames then
		return
	end

	local container = CreateFrame("Frame", "ERFTestModeContainer", UIParent)
	container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	container:Hide()

	container.background = container:CreateTexture(nil, "BACKGROUND")
	container.background:SetAllPoints()
	container.background:SetColorTexture(0, 0, 0, 0.35)

	self.testModeFrames = {
		container = container,
		activeFrames = {},
		inactiveFrames = {},
		nextFrameId = 1,
	}
end

--- Acquire a preview frame from the manual pool.
---@return table
function EnhancedRaidFrames:AcquireTestModeFrame()
	self:InitializeTestModeFrames()

	local pool = self.testModeFrames
	local frame = table.remove(pool.inactiveFrames)
	if frame then
		return frame
	end

	local frameName = "ERFTestModeFrame" .. pool.nextFrameId
	pool.nextFrameId = pool.nextFrameId + 1
	return CreatePreviewFrame(frameName)
end

RefreshSingleTestModeFrame = function(self, frame, setAppearance)
	UpdateFrameVisuals(frame)
	self:UpdateBackgroundAlpha(frame)
	self:UpdateIndicators(frame, setAppearance)
	self:UpdateTargetMarker(frame, setAppearance)
	self:UpdateDispelOverlay(frame)
	self:UpdateInRange(frame)
end

--- Update preview-frame visuals from the current session data.
function EnhancedRaidFrames:RefreshTestModeFrames()
	if not self.testModeState or not self.testModeState.active then
		return
	end

	for _, frame in ipairs(self.testModeFrames.activeFrames) do
		RefreshSingleTestModeFrame(self, frame, true)
	end
end

--- Spawn or resize the preview roster for the current test session.
---@param session table
function EnhancedRaidFrames:ShowTestModeFrames(session)
	self:InitializeTestModeFrames()

	local pool = self.testModeFrames
	local container = pool.container
	local columns, rows = GetGroupLayout(session.size)
	local width = (columns * FRAME_WIDTH) + ((columns - 1) * COLUMN_SPACING)
	local height = (rows * FRAME_HEIGHT) + ((rows - 1) * ROW_SPACING)

	container:SetScale(self.db and self.db.profile.frameScale or 1)
	container:SetSize(width, height)
	container:Show()

	for _, frame in ipairs(pool.activeFrames) do
		frame:Hide()
		self:UnregisterManagedFrame(frame)
		pool.inactiveFrames[#pool.inactiveFrames + 1] = frame
	end
	wipe(pool.activeFrames)

	for index, member in ipairs(session.members) do
		local frame = self:AcquireTestModeFrame()
		frame:SetParent(container)
		frame:ClearAllPoints()

		local column = math.floor((index - 1) / 5)
		local row = (index - 1) % 5
		frame:SetPoint("TOPLEFT", container, "TOPLEFT",
			column * (FRAME_WIDTH + COLUMN_SPACING),
			-(row * (FRAME_HEIGHT + ROW_SPACING)))

		frame.unit = member.unitToken
		frame.ERF_isTestFrame = true
		frame.ERF_testData = member
		frame.ERF_unitAuras = member.auras

		local classR, classG, classB = GetClassColor(member.classFile)
		frame.ERF_nameText:SetTextColor(classR, classG, classB, 1)
		UpdateFrameVisuals(frame)
		self:RegisterManagedFrame(frame, frame.unit, "test")
		frame:Show()

		pool.activeFrames[#pool.activeFrames + 1] = frame
	end

	self:RefreshTestModeFrames()
end

--- Tear down and release all preview frames back into the pool.
function EnhancedRaidFrames:HideTestModeFrames()
	if not self.testModeFrames then
		return
	end

	local pool = self.testModeFrames
	for _, frame in ipairs(pool.activeFrames) do
		self:UnregisterManagedFrame(frame)
		frame:Hide()
		frame:SetParent(nil)
		frame.unit = nil
		frame.ERF_isTestFrame = nil
		frame.ERF_testData = nil
		frame.ERF_unitAuras = nil
		frame.ERF_statusText:SetText("")
		frame.ERF_floatingText:Hide()
		StopPreviewAnimations(frame)
		pool.inactiveFrames[#pool.inactiveFrames + 1] = frame
	end

	wipe(pool.activeFrames)
	pool.container:Hide()
end
