-- Triage - Enhanced Raid Frames Reforged
-- Original work copyright (c) 2017-2025 Britt W. Yazel
-- Continued by Royaleint - licensed under the MIT license (see LICENSE for details)
-- luacheck: globals CompactRaidGroupTypeEnum CompactUnitFrame_SetUpFrame DefaultCompactUnitFrameSetup
-- luacheck: globals CompactUnitFrame_SetUnit RegisterUnitWatch BossTargetFrameContainer

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

local BOSS_FRAME_UNIT = "boss1"
local BOSS_FRAME_NAME = "TriageBossFrame1"

local function GetBossFrameOptions()
	local db = EnhancedRaidFrames.db and EnhancedRaidFrames.db.profile
	return db and db.bossFrames
end

local function ResolveRelativeFrame(relativeTo)
	if type(relativeTo) == "string" then
		return _G[relativeTo] or UIParent
	end

	return relativeTo or UIParent
end

local function PositionBossFrame(frame, options)
	local anchor = options and options.anchor or {}
	local point = anchor.point or "TOPLEFT"
	local relativeTo = ResolveRelativeFrame(anchor.relativeTo or "BossTargetFrameContainer")
	local relativePoint = anchor.relativePoint or "TOPLEFT"
	local x = anchor.x or 0
	local y = anchor.y or 0

	frame:ClearAllPoints()
	frame:SetPoint(point, relativeTo, relativePoint, x, y)
end

function EnhancedRaidFrames:InitializeBossFrames()
	if self.isWoWClassicEra or self.isWoWClassic then
		return
	end

	local options = GetBossFrameOptions()
	if options and not options.enabled then
		return
	end

	if self.bossFramePrototype then
		return
	end

	local frame = CreateFrame("Button", BOSS_FRAME_NAME, UIParent, "CompactUnitFrameTemplate")
	frame.groupType = CompactRaidGroupTypeEnum.Raid
	frame.ERF_isBossPrototype = true

	CompactUnitFrame_SetUpFrame(frame, DefaultCompactUnitFrameSetup)
	CompactUnitFrame_SetUnit(frame, BOSS_FRAME_UNIT)
	RegisterUnitWatch(frame)
	PositionBossFrame(frame, options)

	self.bossFramePrototype = frame
	self:RegisterManagedFrame(frame, BOSS_FRAME_UNIT, "addon")
end
