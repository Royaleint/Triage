-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals IsInGroup IsInRaid

local EnhancedRaidFrames = _G.EnhancedRaidFrames

local DEFAULT_TEST_MODE_SIZE = 5
local TEST_MODE_ROTATION_INTERVAL = 8

local function ParseSizeToken(token)
	local size = tonumber(token)
	if EnhancedRaidFrames:IsValidTestModeSize(size) then
		return size
	end

	return nil
end

--- Return true when preview mode is active.
---@return boolean
function EnhancedRaidFrames:IsTestModeActive()
	return self.testModeState and self.testModeState.active == true
end

--- Stop preview mode and release all synthetic frames.
function EnhancedRaidFrames:StopTestMode()
	if not self.testModeState then
		return
	end

	if self.testModeState.rotationTicker then
		self:CancelTimer(self.testModeState.rotationTicker)
		self.testModeState.rotationTicker = nil
	end

	if self.testModeState.exitFrame then
		self.testModeState.exitFrame:UnregisterAllEvents()
	end

	self:HideTestModeFrames()
	self.testModeState = nil
end

--- Start preview mode for the requested synthetic roster size.
---@param size number|nil
function EnhancedRaidFrames:StartTestMode(size)
	size = size or DEFAULT_TEST_MODE_SIZE
	if not self:IsValidTestModeSize(size) or InCombatLockdown() then
		return
	end

	self:StopTestMode()

	local session = self:CreateTestModeSession(size)
	if not session then
		return
	end

	self.testModeState = {
		active = true,
		size = size,
		session = session,
		exitFrame = self.testModeState and self.testModeState.exitFrame or CreateFrame("Frame"),
	}

	self.testModeState.exitFrame:SetScript("OnEvent", function()
		if IsInGroup() or IsInRaid() or InCombatLockdown() then
			self:StopTestMode()
		end
	end)
	self.testModeState.exitFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	self.testModeState.exitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.testModeState.exitFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

	self:ShowTestModeFrames(session)
	self.testModeState.rotationTicker = self:ScheduleRepeatingTimer(function()
		if not self:IsTestModeActive() then
			return
		end
		self:AdvanceTestModeSession(self.testModeState.session)
		self:RefreshTestModeFrames()
	end, TEST_MODE_ROTATION_INTERVAL)
end

--- Handle `/triage test` commands during the phased rollout.
---@param input string
---@return boolean
function EnhancedRaidFrames:HandleTestModeChatCommand(input)
	local command, rest = input:match("^(%S*)%s*(.-)%s*$")
	if command ~= "test" then
		return false
	end

	local size = ParseSizeToken(rest) or DEFAULT_TEST_MODE_SIZE
	self:StartTestMode(size)
	return true
end
