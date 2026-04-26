# Triage — Completed Items

Append-only history of completed Triage work. Active and queued items live in
`Tri_Tracker.md`. Cross-project status rollup lives in `BawrLabs/INDEX.md`.

## Unreleased — 2026-04-25

### TRI-004 Managed frame registry for raid/party/boss frames
- **Type:** Refactor / Infrastructure
- **Priority:** High
- **Status:** Complete
- **Source:** GitHub issue #4.
- **Summary:** Replaced direct Blizzard compact-frame iteration with a central managed-frame registry that tracks frame add/remove/unit-change lifecycle. All modules now query the registry instead of iterating Blizzard raid/party frames directly, which keeps boss-frame support and future click-casting work unblocked.
- **Implementation:** Added `Utils/FrameRegistry.lua`, wired registry-backed iteration and unit lookup across aura listeners, aura indicators, target markers, dispel overlay, range, and stock-aura passes, synchronized lifecycle from startup, roster changes, and `CompactUnitFrame_SetUnit`, widened default registry support for `boss1..boss5`, and made unnamed-frame child creation safe for future addon-owned frames. Target markers were then fixed for Midnight secret raid-target values and given a configurable downward nudge to keep the icon off the name.
- **Files touched:** `Utils/FrameRegistry.lua`, `EnhancedRaidFrames.lua`, `Modules/AuraListeners.lua`, `Modules/AuraIndicators.lua`, `Modules/TargetMarkers.lua`, `Modules/DispelOverlay.lua`, `Modules/Range.lua`, `Modules/StockAuras.lua`, `GUI/TargetMarkerConfigPanel.lua`, `DatabaseDefaults.lua`, `Localizations/enUS.lua`.
- **Verification:** Argus Gate 1 passed. Gate 2 passed on live Retail party and raid frames after the target-marker visibility fix and placement adjustment.
- **Completed:** 2026-04-25

### TRI-033 Stock buff/debuff hide toggles stop hiding on Retail (Midnight)
- **Type:** Bug
- **Priority:** High
- **Status:** Complete
- **Source:** CurseForge comment on v1.1.0, 2026-04-23. Reporter explicitly named Midnight; Retail 12.0.5 confirmed in-game.
- **Summary:** Fixed Retail 12.0.5+ stock aura visibility toggles so disabled Blizzard buff, debuff, and dispellable icons no longer render over Triage indicators on compact party/raid frames.
- **Root cause:** Blizzard replaced the legacy compact-frame aura arrays and update functions with `Blizzard_PrivateAurasUI`, which reads secure attributes such as `ignore-buffs`, `ignore-debuffs`, and `ignore-dispel-debuffs`.
- **Implementation:** Retail path now applies the new ignore attributes, hooks each frame's copied `SetPrivateAuraAnchorSettings` method to reapply Triage settings after Blizzard rewrites, and uses `update-settings` as the refresh signal. It avoids `frame.optionTable` mutation and does not call `TriggerPrivateAuraSettingsUpdate` from addon code.
- **Files touched:** `Overrides.lua`.
- **Verification:** `luacheck Overrides.lua --config .luacheckrc` passed with 0 warnings / 0 errors. Gate 2 passed on Retail party frames, group-drop taint check, runtime toggle behavior, and 6+ raid verification.
- **Completed:** 2026-04-25

### TRI-007 Test mode — preview frames without a group
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Source:** GitHub issue #13.
- **Summary:** Added configurable addon-owned preview frames so users can see Triage indicators, dispel overlay, target markers, range fade, health states, dead/offline states, and simulated healing without joining a group.
- **Implementation:** Landed preview frame scaffolding, rendering adapters, simulated healing, slash/config wiring, teardown, client hardening, and Gate 2 visual/interaction/movability fixes.
- **Files touched:** `Modules/TestMode.lua`, `Utils/TestModeData.lua`, `Utils/TestModeFrames.lua`, GUI/localization/config integration, and related preview adapters.
- **Verification:** Gate 1 passed. Gate 2 passed on Retail after visual, interaction, and movability fixes landed in `dbc1a66`.
- **Completed:** 2026-04-25

### TRI-003 Colored dispel glow — debuff-type-colored glow animation
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Source:** GitHub issue #6.
- **Summary:** Replaced the visually dominant neutral yellow glow path with a debuff-type colored glow/border path when `Color by Debuff Type` is enabled. Neutral mode now has its own completed follow-up under TRI-032.
- **Implementation:** Vendored `LibCustomGlow-1.0`, integrated colored `ButtonGlow` into the dispel overlay, and completed the later neutral-mode fallback work in TRI-032.
- **Files touched:** `Libs/`, `Modules/DispelOverlay.lua`, `Localizations/enUS.lua`, `.pkgmeta`, `Libs/embeds.xml`.
- **Verification:** Gate 1 passed. Gate 2 passed via TRI-032 follow-up testing on test-mode frames and live Blizzard party frames, including colored mode, neutral mode, clear behavior, and out-of-range neutral behavior.
- **Completed:** 2026-04-25

### TRI-006 Curated per-spec aura defaults
- **Type:** Feature
- **Priority:** High
- **Status:** Complete
- **Source:** GitHub issue #7; launch-readiness work for out-of-box healer setup.
- **Summary:** Added Retail-only manual Apply/Reset actions under Indicator Options that fill curated per-spec aura defaults for 7 healer specs plus utility dispeller specs. Defaults use researched applied aura IDs where available and preserve wildcard entries such as `Dispel`, `Magic`, `Poison`, `Disease`, `Curse`, and `Bleed`.
- **Implementation:** Added `Data/SpecDefaults.lua` and `Utils/SpecDefaults.lua`, wired TOC load order, added option UI/localization, and fixed aura ID matching so numeric `auraData.spellId` values are compared safely as full tokens.
- **Files touched:** `Data/SpecDefaults.lua`, `DatabaseDefaults.lua`, `GUI/IndicatorConfigPanel.lua`, `Localizations/enUS.lua`, `Modules/AuraListeners.lua`, `Triage.toc`, `Utils/SpecDefaults.lua`.
- **Verification:** Gate 1 passed. Merged to `main` for Gate 2 as `7a84992` (`merge: gate2 prep tri-006`), with tracker update `5b5a1e6`. Addon-only `luacheck` passed with 0 warnings / 0 errors. Gate 2 passed on Retail: Apply/Reset behavior worked as expected, and Restoration Druid live aura matching displayed Rejuvenation in upper-left and Lifebloom in center-right as expected.
- **Completed:** 2026-04-25

### TRI-032 Neutral dispel highlight uses default proc glow
- **Type:** Feature (polish)
- **Priority:** Medium
- **Status:** Complete
- **Source:** TRI-003 Gate 2 follow-up and live PvP-group verification on Retail.
- **Summary:** Neutral dispel mode now uses the default Blizzard-style action-button proc glow when `Color by Debuff Type` is disabled. Colored mode remains the Triage debuff-type border/glow path. The overlay no longer clears solely because the dispellable unit is out of range, so players can still see that an out-of-range target needs a dispel.
- **Implementation:** Replaced the abandoned `RaidFrame-DispelHighlight` atlas direction with a live-frame-safe `LibCustomGlow.ButtonGlow` host for real Blizzard compact frames, while test-mode frames continue to render through the existing overlay. Removed the range gate from dispel-overlay refresh; dead, ghost, offline, unsupported, hidden, and disabled states still clear the overlay.
- **Files touched:** `Modules/DispelOverlay.lua`.
- **Verification:** Targeted `luacheck Modules\DispelOverlay.lua --config .luacheckrc` passed. Gate 2 passed on test-mode frames, live Blizzard party frames, colored mode, neutral mode, clear behavior, and out-of-range neutral behavior.
- **Completed:** 2026-04-25

## v1.1.0 — 2026-04-23

### TRI-021 Extended range check beyond 40 yards
- **Type:** Feature (quick win)
- **Priority:** High
- **Status:** Complete
- **Source:** ERF #130.
- **Summary:** Custom Distance select extended with 45 / 50 / 55 / 60yd options on Retail only (Classic Era and Pandaria Classic LibRangeCheck have no reliable checkers >40yd).
- **Shipped in:** v1.1.0.
- **Implementation:** PR #36. Final commit `a3a9dfa`. Argus Gate 1 conditional pass → full pass after adding a user-facing warning in chat when `LibRangeCheck:GetFriendMinChecker(range)` returns nil for the selected distance (silent-failure avoidance).
- **Files touched:** `GUI/GeneralConfigPanel.lua`, `Localizations/enUS.lua`.
- **Completed:** 2026-04-23

### TRI-022 "Not mine" aura filter
- **Type:** Feature (quick win)
- **Priority:** Medium
- **Status:** Complete
- **Source:** ERF #79.
- **Summary:** Replaced the per-indicator `mineOnly` boolean with a three-way `casterFilter` select: All Casters / Mine Only / Not Mine. Primary use case: two druids in a group each watching the other's Rejuv to avoid overwrites.
- **Shipped in:** v1.1.0.
- **Implementation:** PR #37. Final commit `9eef674`. Argus Gate 1 full PASS. DB migration 2.2 → 2.3 is idempotent (runs only while `mineOnly ~= nil`); maps `true → "mine"`, `false → "all"`. `notMine` branch rejects `sourceUnit == nil` at both filter sites so server-side / stale auras don't slip through.
- **Files touched:** `DatabaseDefaults.lua`, `GUI/IndicatorConfigPanel.lua`, `Localizations/enUS.lua`, `Modules/AuraIndicators.lua`, `Utils/DatabaseMigration.lua`.
- **Completed:** 2026-04-23

### TRI-023 Transform spell tracking (Cenarion Ward, etc.)
- **Type:** Bug / Feature (quick win)
- **Priority:** High
- **Status:** Complete
- **Source:** ERF #77.
- **Summary:** Aura Watch List now documents the two-line workaround for spells that change spell ID when they proc (e.g. Cenarion Ward 102351 ↔ 102352). Runtime matcher already supports both name and ID matching per line.
- **Shipped in:** v1.1.0.
- **Implementation:** PR #38. Commits `a4d0dc9` + `bd6f4c5`. Argus Gate 1 conditional pass → full pass after dropping the `Utils/TransformSpells.lua` lookup table (no runtime consumer + ambiguous positional 4-tuple contract). Deferred to land with TRI-014 (spell validation) where the data shape will be driven by a real consumer. Shipped scope: GUI hint + two localization keys.
- **Files touched:** `GUI/IndicatorConfigPanel.lua`, `Localizations/enUS.lua`.
- **Completed:** 2026-04-23

### TRI-024 Finer indicator positioning increments
- **Type:** Feature (quick win)
- **Priority:** Low
- **Status:** Complete
- **Source:** ERF #45, #47.
- **Summary:** Indicator horizontal/vertical offset sliders tightened from 1% to 0.5% steps. New per-indicator Countdown Text Location dropdown (five corners + center) decouples countdown anchor from stack size anchor — pick opposite corners to show both without overlap.
- **Shipped in:** v1.1.0.
- **Implementation:** PR #39. Final commit `c4b59d9`. Argus Gate 1 full PASS. `UpdateStackSizeText` rewritten to hoist `Countdown:ClearAllPoints()` and `StackSize:ClearAllPoints()` above the branches — fixes a latent anchor-accumulation bug. No DB version bump needed (AceDB defaults merge handles the new `countdownLocation = "CENTER"` key).
- **Files touched:** `DatabaseDefaults.lua`, `GUI/IndicatorConfigPanel.lua`, `Localizations/enUS.lua`, `Modules/AuraIndicators.lua`.
- **Completed:** 2026-04-23

### TRI-025 Keep indicators visible when out of range
- **Type:** Feature (quick win)
- **Priority:** Low
- **Status:** Complete
- **Source:** ERF #52.
- **Summary:** New profile-level `keepIndicatorsVisible` toggle under Out-of-Range. When enabled, aura indicators stay at full alpha while the parent raid frame fades. Only visibly effective with Override Default Distance enabled (Blizzard's native 40yd fade uses a secret-tainted alpha path addons can't intercept).
- **Shipped in:** v1.1.0.
- **Implementation:** PR #40. Final commit `eef5944` (+ merge commit `5123958` resolving an enUS.lua conflict with PR #36). Argus Gate 1 full PASS. Uses `indicatorFrame:SetIgnoreParentAlpha(...)` with a defensive method check mirroring the `SetPropagateMouseClicks` pattern. Placed on `SetIndicatorAppearance` / `RefreshConfig` path so mid-session toggle works without `/reload`.
- **Files touched:** `DatabaseDefaults.lua`, `GUI/GeneralConfigPanel.lua`, `Localizations/enUS.lua`, `Modules/AuraIndicators.lua`.
- **Completed:** 2026-04-23

### TRI-027 Stale AceTab-3.0 XML include triggers LUA_WARNING on login
- **Type:** Bug
- **Priority:** High
- **Status:** Complete
- **Source:** In-game report 2026-04-21.
- **Symptom:** `4x LUA_WARNING: Triage/Libs/embeds.xml:22 Couldn't open Triage/AceTab-3.0/AceTab-3.0.xml` on login.
- **Root cause:** v1.0.0 (2026-04-20) removed AceTab-3.0 from vendoring because CurseForge rejected the auto-derived slug and the library was unused. `.pkgmeta` was updated. `Libs/embeds.xml` line 22 was missed and still `<Include>`d the now-absent `AceTab-3.0\AceTab-3.0.xml`.
- **Shipped in:** v1.1.0.
- **Implementation:** one-line delete in `Libs/embeds.xml`. Commit `378360a`. Merged to main as `3ba6b3e` (2026-04-21). Gate 1 passed (Argus, 5/5 lenses). Gate 2 passed in-game on Retail 2026-04-21 — no warning on fresh login.
- **Completed:** 2026-04-23

### TRI-028 SecureHook on CompactUnitFrame_UpdatePrivateAuras errors when global is absent
- **Type:** Bug
- **Priority:** High
- **Status:** Complete
- **Source:** In-game report 2026-04-21.
- **Symptom:** Repeated `Triage/Overrides.lua:23: ... Attempting to hook a non existing target` errors on login, zone change, and group roster events.
- **Root cause:** `Overrides.lua:22` called `self:SecureHook("CompactUnitFrame_UpdatePrivateAuras", ...)` guarded only by `IsHooked`, while sibling hooks at `EnhancedRaidFrames.lua:126` / `:136` already used the `if CompactUnitFrame_<name> and ...` existence-check pattern. Midnight 12.0.5 (live 2026-04-21) removed the free-standing global — confirmed via `/dump CompactUnitFrame_UpdatePrivateAuras` returning `nil`. Logic moved to `CompactUnitPrivateAuraAnchorMixin:SetUnit`.
- **Shipped in:** v1.1.0.
- **Implementation:** one-line existence guard added to match sibling pattern. Commit `1f36640`. Merged to main as `3ba6b3e` (2026-04-21). Gate 1 passed (Argus, 5/5 lenses). Gate 2 passed in-game on Retail 2026-04-21 — no errors on login or zone change.
- **Follow-up filed:** TRI-029 (Maintenance queued item) — retire or rework `UpdatePrivateAuraVisOverrides` (now confirmed dead code on 12.0.5). Guard stays regardless.
- **Completed:** 2026-04-23

---
Pre-split history: Royaleint/BawrLabs@2951ea8:BACKLOG.md
Archaeology: `git log -S "<ITEM-ID>" -- BACKLOG.md` at commit 2951ea8^ (the commit before BACKLOG.md was deleted)
