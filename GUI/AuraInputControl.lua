-- Triage - Native Aura Input Control
--
-- A multi-line aura watch-list editbox augmented with live validation and an
-- autocomplete popup. Rides the native OptionsFrame; the matcher is untouched.
-- Config writes stay per-keystroke (unchanged); only the validation strip and
-- the suggestion popup are debounced. Built on Controls.CreateMultiline.

local Triage = _G.Triage

-- AceLocale namespace frozen; paired with NewLocale("EnhancedRaidFrames", ...) registrations.
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

local Controls = Triage.OptionsControls

local SpellLookup = Triage.SpellLookup

-------------------------------------------------------------------------
-------------------------------------------------------------------------

local AURA_INPUT_HEIGHT = 280
local CONTROL_RIGHT_PADDING = 36

-- Validation strip layout.
local STRIP_MAX_LINES = 5
local STRIP_ROW_HEIGHT = 16
local STRIP_ICON_SIZE = 14

-- Suggestion popup layout.
local POPUP_MAX_SUGGESTIONS = 8
local POPUP_ROW_HEIGHT = 18
local POPUP_ICON_SIZE = 14
local POPUP_WIDTH = 240

-- Debounce delay (seconds) for recomputing the strip + current-line suggestions.
local RECOMPUTE_DELAY = 0.25

-- Status icon textures (stable across clients).
local ICON_RECOGNIZED = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_FLAGGED = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_NEUTRAL = "Interface\\RaidFrame\\ReadyCheck-Waiting"

-------------------------------------------------------------------------
-- Line / token helpers
-------------------------------------------------------------------------

-- Split text into an array of lines, preserving order and empty entries so the
-- byte offsets below line up with the editbox cursor position.
local function SplitLines(text)
	local lines = {}
	if not text or text == "" then
		return lines
	end
	-- strsplit collapses nothing; gmatch keeps trailing/blank lines intact.
	local start = 1
	while true do
		local newlinePos = text:find("\n", start, true)
		if not newlinePos then
			lines[#lines + 1] = text:sub(start)
			break
		end
		lines[#lines + 1] = text:sub(start, newlinePos - 1)
		start = newlinePos + 1
	end
	return lines
end

-- Given a byte cursor position, return the current line's text plus its byte
-- range [startByte, endByte] (1-based, inclusive of the line's last character,
-- exclusive of the surrounding newlines) so HighlightText can target just it.
local function CurrentLineRange(text, cursorByte)
	if not text or text == "" then
		return "", 0, 0
	end

	local len = #text
	if cursorByte < 0 then
		cursorByte = 0
	elseif cursorByte > len then
		cursorByte = len
	end

	-- Walk back to the start of the line (byte after the previous newline).
	local startByte = 0
	for i = cursorByte, 1, -1 do
		if text:sub(i, i) == "\n" then
			startByte = i
			break
		end
	end

	-- Walk forward to the end of the line (byte before the next newline).
	local endByte = len
	for i = cursorByte + 1, len do
		if text:sub(i, i) == "\n" then
			endByte = i - 1
			break
		end
	end

	local lineText = text:sub(startByte + 1, endByte)
	return lineText, startByte, endByte
end

-- Resolve a token result to a status icon + tooltip-ish label for the strip.
-- Returns iconTexture, labelText, flagged (boolean).
local function DescribeResult(result)
	local kind = result.kind
	if kind == "wildcard" then
		return ICON_RECOGNIZED, result.name .. " - " .. L["Wildcard"], false
	elseif kind == "inactive" then
		return ICON_NEUTRAL, result.name .. " - " .. L["Inactive wildcard"], false
	elseif kind == "id" then
		return ICON_RECOGNIZED, result.name .. " - " .. L["Recognized"], false
	elseif kind == "spell" then
		return ICON_RECOGNIZED, result.name .. " - " .. L["Recognized"], false
	elseif kind == "badID" then
		return ICON_FLAGGED, L["Unknown spell ID"], true
	elseif kind == "nearMiss" then
		return ICON_FLAGGED, string.format(L["Did you mean format"], result.suggestion), true
	end
	-- "unverified": neutral, not an error.
	return ICON_NEUTRAL, (result.name or "") .. " - " .. L["Unverified entry"], false
end

-------------------------------------------------------------------------
-- Suggestion popup (single, unnamed, file-local)
-------------------------------------------------------------------------

-- One shared popup for every aura-input control. Unnamed, parented to UIParent.
local popup

local function EnsurePopup()
	if popup then
		return popup
	end

	popup = CreateFrame("Frame", nil, UIParent)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetWidth(POPUP_WIDTH)
	popup:Hide()

	local bg = popup:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(popup)
	bg:SetColorTexture(0, 0, 0, 0.92)
	popup.bg = bg

	local border = popup:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", popup, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0.45, 0.4, 0.28, 0.85)

	popup.rows = {}
	popup.suggestions = {}
	popup.selected = 0

	return popup
end

-- Acquire (or build) a clickable row at the given index.
local function GetPopupRow(index)
	local row = popup.rows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, popup)
	row:SetHeight(POPUP_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", popup, "TOPLEFT", 2, -(2 + (index - 1) * POPUP_ROW_HEIGHT))
	row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -(2 + (index - 1) * POPUP_ROW_HEIGHT))

	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(row)
	highlight:SetColorTexture(1, 0.82, 0, 0.25)

	local selected = row:CreateTexture(nil, "ARTWORK")
	selected:SetAllPoints(row)
	selected:SetColorTexture(1, 0.82, 0, 0.18)
	selected:Hide()
	row.selectedTexture = selected

	local icon = row:CreateTexture(nil, "OVERLAY")
	icon:SetSize(POPUP_ICON_SIZE, POPUP_ICON_SIZE)
	icon:SetPoint("LEFT", row, "LEFT", 3, 0)
	row.icon = icon

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
	text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	text:SetJustifyH("LEFT")
	row.text = text

	popup.rows[index] = row
	return row
end

-------------------------------------------------------------------------
-- Control factory
-------------------------------------------------------------------------

function Controls.CreateAuraInput(parent, row, refresh)
	-- Build on the base multiline editbox; reuse its frame, editbox, scripts.
	local frame = Controls.CreateMultiline(parent, row, refresh)
	frame:SetHeight(row.height or AURA_INPUT_HEIGHT)

	-- The base CreateMultiline parents a single EditBox under the frame.
	local editBox
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:GetObjectType() == "EditBox" then
			editBox = child
			break
		end
	end
	if not editBox then
		return frame
	end

	-- Shrink the editbox to leave room for the validation strip beneath it.
	-- Re-setting the BOTTOMRIGHT anchor replaces the base control's BOTTOMRIGHT
	-- point (same anchor point) without disturbing its TOPLEFT.
	editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
		-CONTROL_RIGHT_PADDING, 4 + (STRIP_MAX_LINES + 1) * STRIP_ROW_HEIGHT + 6)

	-- Validation strip rows beneath the editbox.
	local strip = {}
	for i = 1, STRIP_MAX_LINES + 1 do
		local stripRow = CreateFrame("Frame", nil, frame)
		stripRow:SetHeight(STRIP_ROW_HEIGHT)
		if i == 1 then
			stripRow:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -6)
		else
			stripRow:SetPoint("TOPLEFT", strip[i - 1], "BOTTOMLEFT", 0, 0)
		end
		stripRow:SetPoint("RIGHT", frame, "RIGHT", -CONTROL_RIGHT_PADDING, 0)

		local icon = stripRow:CreateTexture(nil, "ARTWORK")
		icon:SetSize(STRIP_ICON_SIZE, STRIP_ICON_SIZE)
		icon:SetPoint("LEFT", stripRow, "LEFT", 0, 0)
		stripRow.icon = icon

		local text = stripRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
		text:SetPoint("RIGHT", stripRow, "RIGHT", 0, 0)
		text:SetJustifyH("LEFT")
		stripRow.text = text

		stripRow:Hide()
		strip[i] = stripRow
	end

	-- Cancellable debounce timer handle (recompute strip + suggestions).
	local pendingTimer

	local function CancelPending()
		if pendingTimer then
			Triage:CancelTimer(pendingTimer)
			pendingTimer = nil
		end
	end

	-- Hide the suggestion popup and detach it from this editbox.
	local function HidePopup()
		if popup and popup.owner == editBox then
			popup:Hide()
			popup:ClearAllPoints()
			popup.owner = nil
			popup.suggestions = {}
			popup.selected = 0
		end
	end

	-- Recompute and render the per-line validation strip from the full text.
	local function RefreshStrip()
		local text = editBox:GetText() or ""
		local lines = SplitLines(text)

		-- Resolve every non-empty line, tracking flagged ones first.
		local results = {}
		local flaggedCount = 0
		for _, line in ipairs(lines) do
			local result = SpellLookup.ResolveToken(line)
			if result then
				local icon, label, flagged = DescribeResult(result)
				if flagged then
					flaggedCount = flaggedCount + 1
				end
				results[#results + 1] = { icon = icon, label = label, flagged = flagged }
			end
		end

		-- Flagged lines surface first so a flag is never silently hidden.
		table.sort(results, function(a, b)
			if a.flagged ~= b.flagged then
				return a.flagged
			end
			return false
		end)

		-- Render up to STRIP_MAX_LINES rows; the final row carries the tail.
		local shown = math.min(#results, STRIP_MAX_LINES)
		local shownFlagged = 0
		for i = 1, shown do
			local entry = results[i]
			if entry.flagged then
				shownFlagged = shownFlagged + 1
			end
			local stripRow = strip[i]
			stripRow.icon:SetTexture(entry.icon)
			stripRow.text:SetText(entry.label)
			stripRow:Show()
		end

		-- Tail row: "+N more (M flagged)" reporting any hidden + hidden flagged.
		local hidden = #results - shown
		if hidden > 0 then
			local hiddenFlagged = flaggedCount - shownFlagged
			local tail = strip[STRIP_MAX_LINES + 1]
			tail.icon:SetTexture(nil)
			tail.text:SetText(string.format(L["More entries format"], hidden, hiddenFlagged))
			tail:Show()
			for i = shown + 1, STRIP_MAX_LINES do
				strip[i]:Hide()
			end
		else
			for i = shown + 1, STRIP_MAX_LINES + 1 do
				strip[i]:Hide()
			end
		end
	end

	-- Re-anchor the popup rows to the current selection highlight.
	local function UpdatePopupSelection()
		for i, popupRow in ipairs(popup.rows) do
			if popupRow.selectedTexture then
				popupRow.selectedTexture:SetShown(i == popup.selected)
			end
		end
	end

	-- Accept the highlighted suggestion: replace only the current line's byte
	-- range with the suggestion name, then consume.
	local function AcceptSelected()
		if not popup or not popup:IsShown() or popup.owner ~= editBox then
			return false
		end
		local entry = popup.suggestions[popup.selected]
		if not entry then
			return false
		end

		local text = editBox:GetText() or ""
		local cursorByte = editBox:GetCursorPosition()
		local _, startByte, endByte = CurrentLineRange(text, cursorByte)

		editBox:HighlightText(startByte, endByte)
		editBox:Insert(entry.name)
		-- Insert() is a programmatic mutation: it does NOT fire OnTextChanged with
		-- userInput=true, so the config-write path never runs. Persist explicitly,
		-- exactly as the drag path does, or the accepted line is wiped on the next
		-- triageRefresh/SetText. (RefreshStrip, not ScheduleRecompute — the latter is
		-- declared later and out of scope here; RefreshStrip also avoids re-popping
		-- the suggestion list immediately after an accept.)
		if row.onTextChanged then
			row.onTextChanged(editBox:GetText() or "")
		end
		HidePopup()
		RefreshStrip()
		return true
	end

	-- Build + show the suggestion popup for the current line's prefix.
	local function RefreshSuggestions()
		EnsurePopup()

		local text = editBox:GetText() or ""
		local cursorByte = editBox:GetCursorPosition()
		local lineText = CurrentLineRange(text, cursorByte)
		local prefix = strtrim(lineText or "")

		if prefix == "" or not editBox:HasFocus() then
			HidePopup()
			return
		end

		local suggestions = SpellLookup.Suggest(prefix, POPUP_MAX_SUGGESTIONS)
		if #suggestions == 0 then
			HidePopup()
			return
		end

		popup.owner = editBox
		popup.suggestions = suggestions
		popup.selected = 1

		for i = 1, #suggestions do
			local entry = suggestions[i]
			local popupRow = GetPopupRow(i)
			if entry.icon then
				popupRow.icon:SetTexture(entry.icon)
				popupRow.icon:Show()
			else
				popupRow.icon:Hide()
			end
			popupRow.text:SetText(entry.name)
			popupRow:SetScript("OnClick", function()
				popup.selected = i
				AcceptSelected()
				editBox:SetFocus()
			end)
			popupRow:Show()
		end
		for i = #suggestions + 1, #popup.rows do
			popup.rows[i]:Hide()
		end

		popup:SetHeight(4 + #suggestions * POPUP_ROW_HEIGHT)
		popup:ClearAllPoints()
		popup:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
		popup:SetWidth(math.max(POPUP_WIDTH, editBox:GetWidth()))
		UpdatePopupSelection()
		popup:Show()
	end

	-- Debounced recompute: strip + current-line suggestions.
	local function ScheduleRecompute()
		CancelPending()
		pendingTimer = Triage:ScheduleTimer(function()
			pendingTimer = nil
			RefreshStrip()
			RefreshSuggestions()
		end, RECOMPUTE_DELAY)
	end

	-- Per-keystroke: immediate config write (base behavior) + debounced UI.
	editBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			if row.onTextChanged then
				row.onTextChanged(self:GetText() or "")
			end
			ScheduleRecompute()
		end
	end)

	-- Tab accepts the highlighted suggestion when the popup is shown; otherwise
	-- it is a no-op (OnTabPressed has no engine default to fall through to).
	-- Enter is intentionally left bound to the multiline newline.
	editBox:SetScript("OnTabPressed", function()
		if popup and popup:IsShown() and popup.owner == editBox then
			AcceptSelected()
		end
	end)

	-- Keyboard suggestion navigation (Up/Down) is intentionally NOT wired for v1.
	-- On a multiline EditBox, OnArrowPressed only fires under SetAltArrowKeyMode(true),
	-- which then suppresses normal caret movement — a genuine conflict that needs
	-- in-game tuning. v1 accepts the top (highlighted) suggestion via Tab, or any row
	-- via click. Deferred to a follow-up: toggle SetAltArrowKeyMode while the popup is
	-- shown and dismiss the popup on Left/Right. (TRI-014 Gate-2 / v1.1 item.)

	-- Recompute as the caret moves (focus + non-empty line) — routed through the
	-- shared debounce timer so the strip + popup rebuild at most once per ~0.25s
	-- settle, not synchronously on every caret move (the timer is the single owner).
	editBox:HookScript("OnCursorChanged", function()
		if editBox:HasFocus() then
			ScheduleRecompute()
		end
	end)

	editBox:HookScript("OnEditFocusLost", function()
		HidePopup()
	end)

	editBox:HookScript("OnEscapePressed", function()
		HidePopup()
	end)

	-- Drag a spell onto the box -> insert its resolved name on a new line.
	-- EditBox OnReceiveDrag fires without RegisterForDrag (AceGUI precedent).
	editBox:SetScript("OnReceiveDrag", function(self)
		local cursorType, _, _, spellID = GetCursorInfo()
		if cursorType == "spell" and spellID then
			local name = SpellLookup.ResolveNameIcon(spellID)
			if name then
				if not self:HasFocus() then
					self:SetFocus()
					self:SetCursorPosition(self:GetNumLetters())
				end
				local existing = self:GetText() or ""
				if existing ~= "" and existing:sub(-1) ~= "\n" then
					self:Insert("\n")
				end
				self:Insert(name)
				if row.onTextChanged then
					row.onTextChanged(self:GetText() or "")
				end
				ScheduleRecompute()
			end
		end
		ClearCursor()
	end)

	-- Clean up timer + popup whenever the row frame is hidden / reattached.
	frame:HookScript("OnHide", function()
		CancelPending()
		HidePopup()
	end)

	-- triageRefresh (programmatic SetText): refresh strip, drop popup + timer.
	-- The base CreateMultiline already installed a triageRefresh that SetTexts;
	-- wrap it so the strip recomputes and no stale popup/timer lingers.
	local baseRefresh = frame.triageRefresh
	frame.triageRefresh = function()
		if baseRefresh then
			baseRefresh()
		end
		CancelPending()
		HidePopup()
		RefreshStrip()
	end
	frame.triageRefresh()

	return frame
end

return Controls
