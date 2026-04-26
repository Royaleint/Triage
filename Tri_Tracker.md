# Triage — Tracker

Active and queued work for the Triage addon. Completed items live in
`Tri_Completed.md`. Cross-project status rollup lives in
`BawrLabs/INDEX.md`.

## Queued

### Next Release

*(None — populated by Rawb as scope decisions are made.)*

### Bugs

*(None.)*

### Features

### TRI-001 Boss frames as raid-style compact frames
- **Type:** Feature
- **Priority:** High
- **Status:** Blocked — TRI-001a Gate 1 PASS but Gate 2 FAIL (Retail Midnight secret-value taint in `CompactUnitFrame_UpdateHealPrediction` and `_UpdateInRange` paths on addon-owned `CompactUnitFrameTemplate` boss frames). Architecture must be redesigned (B-alt1 owned `SecureUnitButtonTemplate` clone, B-alt2 read-only overlay, or B-alt3 defer). TRI-001b dependent on replacement.
- **Summary:** Boss unit frames (Boss1–Boss5) are Blizzard's default `TargetFrame` buttons, not compact raid frames. On fights like Lura, healable adds appear in these frames and healers have no way to configure them. Supporting them would require addon-owned compact-style boss frames so they can receive Triage indicators, dispel overlay, range, and profile-driven appearance.
- **Source:** Direct guild feedback from a healer.
- **Research status:** Initial feasibility review complete (2026-04-06).
- **Findings:** Retail-only and technically feasible, but not as a pure overlay feature. Blizzard's compact frame system can bind fixed unit tokens, so addon-created `CompactUnitFrameTemplate` buttons can target `boss1`–`boss5`. Blizzard arena frames prove the template supports fixed unit tokens, and Cell already ships a separate boss/NPC unit-frame surface.
- **Constraints:** Frames must be pre-created and unit-bound out of combat, then shown/hidden with `RegisterUnitWatch` as bosses appear mid-fight. Avoid the Blizzard `Arena` compact-frame mode because its PvP-specific option path disables dispel indicators; use Party-style sizing/options or a compact setup clone instead.
- **Triage impact:** Current architecture only iterates Blizzard raid/party compact frames and filters to `player`/`party`/`raid` units. This feature needs a managed frame registry, boss-aware iteration, and selective widening of `ShouldContinue()` rather than a small hook on the existing code.
- **Suggested spike:** Build one Retail-only prototype frame for `boss1`, anchor it near `BossTargetFrameContainer`, and validate targeting, right-click menu, Blizzard click-casting, aura listener updates, dispel overlay, and encounter-time appearance before committing to all five frames.
- **Notes:** High differentiator for Blizzard-frame users, but not literally unique — Cell already supports boss/NPC frames. Bigger scope than the current overlay-only healing modules. Retail only.
- **Follow-up:** After the Retail version is settled, evaluate whether Classic Era and Pandaria Classic can support a separate boss-frame approach without breaking their existing shared ERF behavior.
- **Session progress:** Retail-only `boss1` compact-frame prototype is in the worktree on `Modules/BossFrames.lua`, registered through the managed frame registry, and wired into startup before the first config refresh. Prodigy spec drafted in `Triage_Dev/plans/active/tri-001-boss-frames-prodigy-spec.md`.
- **Session progress (2026-04-25):** Prodigy reviewed Codex's draft spec, found Gate 3 incorrectly empty (5 unresolved questions), and rewrote against the studio plan template. Rawb resolved all five: Q1 anchor stays near Blizzard's default boss frame position; Q2 ship coexistence toggle unconditionally (default `false`); Q3 lifecycle driver = `RegisterUnitWatch(frame)` after `CompactUnitFrame_SetUnit(frame, "boss1")`, with `SetUpdateAllEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")` named as documented fallback if Spike B5 finds taint; Q4 split into TRI-001a (prototype + Spike B) and TRI-001b (full feature); Q5 frames named `TriageBossFrame1..5`. Final spec at `Triage_Dev/plans/active/tri-001-boss-frames-prodigy-spec.md` (353 lines, gitignored by Triage_Dev's `plans/*` rule, by design). Codex caught and corrected the `RegisterUnitWatch(frame, "boss1")` API bug before implementation. TRI-001a was implemented and Gate 1-passed on worktree branch `tri-001-boss-frames` at `9a7c96e`. **Next action:** run Spike B / Gate 2 when Rawb decides whether to continue refactor/extension or pause for rebuild evaluation.
- **Verification update (2026-04-26):** Local Blizzard UI source review supports addon-owned secure/compact boss frames bound to `boss1`-`boss5`; the remaining uncertainty is live encounter lifecycle and taint, not basic API feasibility. Gate 2 should focus on boss token appearance/disappearance, phase transitions, combat lockdown, and whether Triage modules can decorate the boss frame cleanly during combat.
- **Gate 2 result (2026-04-26):** FAILED. `/tridev bossdungeon` run during a real Retail Midnight dungeon boss encounter produced two Lua errors: `CompactUnitFrame_UpdateHealPrediction: attempt to compare local 'maxHealth' (a secret number value, while execution tainted by 'Triage_Dev')` and `CompactUnitFrame_UpdateInRange: attempt to perform boolean test on local 'checkedRange' (a secret boolean value, while execution tainted by 'Triage_Dev')` — both on `TriageDevBossFrame1`. Blizzard's compact-frame internals read boss `maxHealth`/`checkedRange` as secret values, and addon-tainted execution context blocks the comparisons. The naive `CompactUnitFrameTemplate` owned-boss-frame approach is **blocked on Retail Midnight**. Code itself was Gate 1 PASS — failure was architectural, not implementation-quality. Findings docs at `Triage_Dev/plans/active/triage-rebuild-verification-findings-2026-04-26.md` (Codex — strategic rebuild handoff) and `Triage_Dev/plans/active/tri-001a-claude-findings.md` (Claude — comprehensive Gate 1 review with Gate 2 postscript). KNOWLEDGE.md entry tagged `[PROMOTE]`. **Next action:** write the rebuild architecture spec from the combined findings; treat boss-frame provider as unresolved with B-alt1/B-alt2/B-alt3 spike paths. Do not commit the worktree boss-frame prototype as-is.
- **Related issues:** GitHub `#1` parent feature, `#9` boss-frame prototype, `#8` click-casting scaffold.

### TRI-002 Import aura watch lists from other addons
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Summary:** Import DandersFrames Aura Designer placed-aura configurations into Triage's 9 indicator positions as aura watch lists. This is a lossy migration tool, not a full profile import or Aura Designer compatibility layer.
- **Data policy:** Safe. Reads user-owned DandersFrames data only: either the live `DandersFramesDB_v2` global if Danders is loaded, or a user-provided Danders export string. Does not require runtime parsing of competitor source files and does not ship competitor config semantics wholesale.
- **Research status:** Investigated 2026-04-06 against DandersFrames' current SavedVariables and Aura Designer runtime model.
- **Findings:** Feasible on Retail if scoped narrowly. Danders stores Aura Designer data under `DandersFramesDB_v2.profiles[profile].party/raid.auraDesigner.auras[spec]`; placed indicators live in `auraCfg.indicators[]` with `type`, `anchor`, `offsetX`, and `offsetY`. Triage stores only 9 fixed per-position watch lists (`indicator-1`..`indicator-9`), so any import is inherently lossy.
- **Findings:** Anchor mapping is clean because both addons use the same 9-point model: `TOPLEFT`, `TOP`, `TOPRIGHT`, `LEFT`, `CENTER`, `RIGHT`, `BOTTOMLEFT`, `BOTTOM`, `BOTTOMRIGHT`. These can map directly to Triage indicator slots 1-9.
- **Findings:** Danders Aura Designer keys are mostly internal aura IDs like `PowerWordShield`, not literal WoW aura names. Import must prefer `AuraDesigner.SpellIDs[spec][auraName]` and `AlternateSpellIDs` where available. Importing raw internal names into Triage would silently produce bad watch lists.
- **Findings:** Triage cannot faithfully import Danders layout groups, multi-aura frame effects, sound alerts, or other Aura Designer-only semantics. Grouped indicators are stored separately via `layoutGroups[spec]` and their effective positions are computed dynamically; Triage has no equivalent grouping or growth model. These should be skipped in v1.
- **Findings:** Danders also supports secret, inferred, and self-only aura systems that exceed Triage's current matcher. Examples include secret aura fingerprints, linked aura inference, and self-only spell handling. These entries should be skipped or clearly warned about during import rather than copied blindly.
- **Findings:** Multiple Danders auras can occupy the same anchor. Triage can only show one active aura per slot, so same-anchor imports should become ordered watch lists in a single Triage slot rather than attempting visual parity. Use Danders aura priority to order collisions where possible.
- **Findings:** WoW cannot read another addon's WTF SavedVariables file from disk at runtime. Clean input options are therefore: `1)` live import from `DandersFramesDB_v2` if Danders is installed and loaded, or `2)` pasted Danders export text. Supporting Danders export text is feasible, but Triage would need to parse Danders' `!DFP1!` format, which currently uses `LibSerialize` + `LibDeflate` rather than Triage's existing `AceSerializer` import path.
- **Recommended v1 scope:** Retail only. Select one Danders profile, one mode (`party` or `raid`), and one spec at a time. Import only ungrouped placed indicators (`icon`, `square`, `bar`) from supported Aura Designer specs. Resolve to spell IDs, map anchors to Triage slots, and write newline-delimited aura lists into Triage's existing indicator config.
- **Recommended v1 scope:** Provide a preview before apply showing counts for imported entries, skipped grouped entries, skipped secret or inferred entries, unsupported entries, and per-slot anchor collisions. Offer merge vs overwrite behavior per target slot so the tool does not unexpectedly destroy an existing Triage setup.
- **Non-goals:** No full Danders profile import. No recreation of layout groups. No translation of frame-level effects such as border, health bar color, text color, frame alpha, or sound. No promise of secret-aura parity.
- **Notes:** Danders Aura Designer currently targets healer specs plus Augmentation Evoker, which limits the source surface and helps feasibility. If this importer works, the generalizable pattern is not 'import competitor profiles' but 'map another addon's anchored aura definitions into Triage's slot-based watch lists.' That same pattern could later be evaluated for Cell or VuhDo.

### TRI-005 Built-in click-casting
- **Type:** Feature
- **Priority:** High
- **Status:** Research Complete, Spike A partially verified; scope revised after Midnight taint finding
- **Summary:** Compiled macro click-casting system. Harm/help conditionals, Smart Resurrection, per-spec defaults. Retail + Classic support. Feasibility spike required before full implementation. GitHub issue #5.
- **Finding (2026-04-26):** Directly stamping Triage click-cast attributes onto Blizzard compact raid/party frames is unsafe on Retail Midnight. TriageDev testing produced secret-value taint in Blizzard `CompactUnitFrame_UpdateInRange`, `CompactUnitFrame_UpdateHealthColor`, `CompactUnitFrame_GetRangeAlpha`, and related update paths. After moving the probes to an addon-owned secure frame (`TriageDevClickProbeFrame`), A1/A3/A4 passed without Lua errors.
- **Scope update:** First-party click-casting should target addon-owned/provider-safe frames. Blizzard compact frames should preserve native `C_ClickBindings`, Clicked, and Clique compatibility rather than being mutated by Triage. Add an explicit provider/capability flag such as `supportsTriageClickCasting`. Classic/Pandaria A6/A7 remain unverified.

### TRI-008 Auto layout switching — content-aware profile selection
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** Competitor analysis (Danders), ERF #58. 4 users +1'd on ERF over multiple years.
- **Summary:** Auto-switch profiles based on content type and group size (dungeon, raid, BG, open world). Per-size-range profiles, auto-detection on roster/zone change, combat-safe queuing. Ships with sensible defaults (party 1-5, raid 6+). GitHub issue #14.

### TRI-009 Priority-chain indicators — "show X, else Y, else Z" per slot
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** Competitor analysis (VuhDo bouquet system).
- **Summary:** Each indicator slot supports an ordered priority chain of conditions (specific aura, aura type, health threshold, aggro, role, missing buff). First match wins. Visual drag-and-drop editor, not nested dropdowns. Default profiles use simple single-aura slots — chains are opt-in.

### TRI-010 Pre-configured raid debuffs with auto-detection
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** Competitor analysis (Cell curated lists, Grid2 auto-detection).
- **Summary:** Ship curated per-tier debuff lists for current content. Auto-detect unknown debuffs in combat and surface them for review post-encounter. Dedicated "raid debuff" indicator mode shows highest-priority active boss debuff without manual config. Works with priority chains (TRI-009).
- **Finding (2026-04-26):** Spike C is reduced from an architecture unknown to a data-policy/content-curation problem. Local competitor/source review found Cell and Danders-style whitelist approaches for secret-safe aura display. A hand-curated whitelist plus graceful degradation is viable for v1.x, but active aura/debuff behavior still needs live verification.

### TRI-011 Cluster heal finder — AoE heal target recommendation
- **Type:** Feature
- **Priority:** Medium
- **Status:** Reframed by feasibility research; see GitHub #41 / TRI-011b
- **Source:** Competitor analysis (VuhDo — only addon with this feature).
- **Summary:** Original VuhDo-style spatial cluster detection is not a reliable Retail path with current APIs. The practical feature is Triage Focus: highlight the best in-range heal target using LibRangeCheck, health deficit, incoming-heal adjustment where safe, and a throttled priority score. Avoid `UnitPosition()`/CLEU spatial assumptions.

### TRI-012 Raid tools panel — ready check, pull timer, markers, trackers
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Source:** Competitor analysis (Cell — only raid frame addon with built-in raid tools).
- **Summary:** Lightweight collapsible panel near raid frames. Core: ready check, raid markers, pull timer (syncs with DBM/BigWigs), battle res tracker. Extended: buff/consumable checker, interrupt tracker, cooldown tracker. Auto-appears for raid leaders/assists.

### TRI-013 Pinned frames — custom frame groups for priority targets
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Source:** Competitor analysis (VuhDo private tanks).
- **Summary:** Pin specific players into a dedicated always-visible frame group independent of Blizzard Main Tank assignments. For assigned healing — pin co-healer, assigned tank, priority targets. Multiple named groups, drag-and-drop or right-click to pin. Depends on frame registry (TRI-004).

### TRI-014 Spell validation with autocomplete in aura configuration
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** Original — no competitor has this.
- **Summary:** Real-time spell name validation and autocomplete in aura config fields. Validates against C_Spell.GetSpellInfo(), supports spell IDs and fuzzy matching ("rejuv" → "Rejuvenation"). Warning icon on typos. Eliminates the most common config error across all raid frame addons.
- **Notes:** AceTab-3.0 was removed from vendoring in v1.0.0 (was inherited unused from ERF; CurseForge slug `acetab-3.0` invalid). If implementing via the Tab-key autocomplete pattern, re-vendor AceTab-3.0 with the correct CurseForge externals override or use an alternative pattern (Blizzard's `AutoCompleteEditBoxTemplate`, AceGUI editbox + live `OnTextChanged` suggestions, or LibAdvancedAutoComplete).

### TRI-015 First-run experience — spec detection, welcome flow, progressive disclosure
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** Original — UX strategy.
- **Summary:** Detect class/spec on first load, apply defaults automatically, show brief dismissable tooltip. Progressive disclosure in settings: simple mode by default, advanced toggle for power users. Ship 3 preset templates (Raid Healer, Dungeon Healer, DPS Dispeller). This defines how the UX layer system manifests in the UI.

### TRI-016 Buff/debuff blacklist for stock Blizzard icons
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** ERF #142, #110. Most requested feature across ERF issues (3+ users over multiple years).
- **Summary:** Granular control over which buffs/debuffs show in Blizzard's stock icon display. Blacklist mode (hide specific auras) and whitelist mode (hide all except listed). Separate lists for buffs and debuffs. Current workaround (disable all + re-add as indicators) wastes indicator slots.
- **Finding (2026-04-26):** This must be treated as a Blizzard-frame-specific capability. Retail stock/private aura suppression uses Blizzard compact-frame attributes and private-aura paths; owned frames or future third-party providers should not be assumed to support the same mechanism.

### TRI-017 Copy/sync indicator settings between positions
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Source:** ERF #122.
- **Summary:** Copy visual settings (size, text, animation, colors) from one indicator position to others. Optional sync mode to link positions. Bulk reset to defaults. Excludes aura lists (always per-position). Reduces tedium of configuring 9 positions with similar appearance.

### TRI-018 Health bar color by health percentage
- **Type:** Feature
- **Priority:** High
- **Status:** Queued
- **Source:** ERF #135. Standard feature in VuhDo and Grid2.
- **Summary:** Dynamically color health bars by remaining health (green → yellow → red). Options: class colors, flat custom color, or gradient. Configurable thresholds, smooth vs stepped. Coexists with debuff-type coloring (TRI-019) via priority. Uses SetStatusBarColor on frame.healthBar.
- **Finding (2026-04-26):** Treat Blizzard health-color paths as taint-sensitive on Retail Midnight. TriageDev click-cast testing produced secret-number taint inside Blizzard health-color updates after protected frame mutation. This feature should avoid mutating protected Blizzard state in ways that cause Blizzard update code to execute under Triage taint.

### TRI-019 Frame color by debuff type
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Source:** ERF #57. VuhDo staple feature.
- **Summary:** Override health bar color with debuff type color when a dispellable debuff is active (Magic=blue, Curse=purple, Poison=green, Disease=brown). Configurable per type, priority when multiple active, option to limit to player-dispellable types. Complements existing dispel border/glow overlay. Toggle: border-only, bar-color-only, or both.
- **Finding (2026-04-26):** Prefer overlay/border presentation over direct Blizzard health-bar color mutation until a taint-safe implementation is proven. `frame.dispels` remains Retail Blizzard-frame-specific; cross-client behavior needs a separate data source.

### TRI-020 Multiple auras per indicator position
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Source:** ERF #33.
- **Summary:** Show multiple active matching auras at a single indicator position as stacked sub-icons (up to 4). Configurable direction (horizontal, vertical, grid). Alternative: cycle through matches on a timer. Default unchanged (first match). Partially overlaps with priority chains (TRI-009) — different use case (show everything vs show most important).

### Data

*(None.)*

### Maintenance

### TRI-029 Retire or rework UpdatePrivateAuraVisOverrides (dead on 12.0.5)
- **Type:** Maintenance
- **Priority:** Low
- **Status:** Queued
- **Source:** TRI-028 follow-up (2026-04-21). Confirmed via `/dump CompactUnitFrame_UpdatePrivateAuras` → `nil` on live 12.0.5.
- **Context:** Midnight 12.0.5 removed the free-standing `CompactUnitFrame_UpdatePrivateAuras` global. Private-aura handling moved to `CompactUnitPrivateAuraAnchorMixin:SetUnit` (CompactUnitFrame.lua:2711 in our Blizzard source extraction). TRI-028's existence guard prevents the error but leaves `UpdatePrivateAuraVisOverrides` permanently unreachable on Retail — the polish behavior that hides private-aura anchors when `showDebuffs` is off no longer runs.
- **Acceptance criteria:** Decide between (a) reworking `UpdatePrivateAuraVisOverrides` against the current `PrivateAuraAnchors` / mixin path so the polish works again on 12.0.5, or (b) deleting `UpdatePrivateAuraVisOverrides` and its call site as permanently dead code. Document the choice. Existence guard in `Overrides.lua:22` stays either way.
- **Notes:** Low priority — polish feature for a niche setting most users don't change. File if someone reports private auras visibly leaking through `showDebuffs = false`.

### Release & Comms

### TRI-030 Publish Triage v1.0.0 announcement
- **Type:** Communications
- **Priority:** Medium
- **Status:** Queued — drafts ready, awaiting Rawb go
- **Source:** Session 2026-04-21. 17 organic CurseForge downloads since v1.0.0 launch (2026-04-20) with zero announcement push. Signal that ERF-redirect discovery is working; announcement would amplify reach.
- **Scope:** Refresh announcement drafts (CurseForge news post, Reddit, GitHub issues) written in Session 16-17 against current state — v1.0.0 shipped, CurseForge moderation cleared, and placeholder Soyier photos still stand on the listing.
- **Voice:** Rawb's voice, not Blizzard style (memory: author voice vs product voice). Reddit post keeps rough edges per anti-AI signal pattern. Tone per locked decision (2026-04-03): community revival, respectful continuation, full credit to Soyier.
- **Owner at execution:** Everett.
- **Notes:** Timing is Rawb's call — no urgency. Organic 17 is a bonus, not a deadline driver. Classic Era + Pandaria Classic framed as "ships alongside Retail — community testing welcome" per the locked v1.0.0 softening.

### TRI-031 Replace placeholder Soyier photos on CurseForge listing
- **Type:** Communications / Assets
- **Priority:** Low
- **Status:** Queued — unblocked
- **Source:** Session 2026-04-21. Soyier's original ERF screenshots currently on the Triage CurseForge listing (intentional placeholder during the revival handoff — visual continuity signal for returning ERF users).
- **Acceptance criteria:** (1) Original Triage screenshots captured showing current v1.0 features in-game (test mode preview, dispel overlay with colored glow, indicator grid, minimap button, settings panel). (2) CurseForge listing screenshots replaced. (3) Wago listing screenshots updated to match.
- **Depends on:** Verified-shipped behavior, not pre-Gate-2 state.
- **Owner at execution:** Everett (listing updates) + Rawb (actual screenshots, since only Rawb has the in-game environment).
- **Notes:** The placeholder is not a bug — it's continuity signal. Don't rush the swap; swap when we have the full set of verified-feature screenshots in hand, not piecemeal.

### TRI-034 TBC Classic Anniversary support
- **Type:** Feature
- **Priority:** Medium
- **Status:** Queued
- **Summary:** Add TBC Classic Anniversary as a fourth supported client alongside Retail, Classic Era, and Pandaria Classic. TBC Anniversary launched January 2026 on Anniversary realms with active player base and addon ecosystem. None of DandersFrames, Cell, MidnightHealerUI, or HealBot ship TBC support; this widens Triage's multi-client moat.
- **Source:** Codex's rebuild brief flagged TBC as a separate compatibility track. Cost assessment dated 2026-04-26 in `Triage_Dev/plans/active/triage-rebuild-tbc-cost-assessment.md`.
- **Research status:** Cost assessment complete (2026-04-26).
- **Findings:** TBC Anniversary uses the modern Midnight 12.0+ engine with TBC content gating, the same backend pattern as Pandaria Classic. Interface version is 20505 (verified via recent TBC Anniversary addon TOCs). Prunes Enhanced Raid Frames for TBC Anniversary (1.5K+ downloads) demonstrates CompactUnitFrame APIs are exposed on this client; ERF's overlay model applies directly.
- **Findings:** Library compatibility verified against vendored externals — `LibRangeCheck-3.0` has `isTBC` branch (line 55), `LibDispel` has TBC branch (line 21), Ace3 stack is universal. `LibClassicDurations` does not apply (TBC's `UnitAura` returns durations natively from 2.0). `LibDualSpec` does not apply (dual spec was a WotLK 3.1 addition).
- **Findings:** Per Codex's source verification (`triage-rebuild-source-verification-findings.md`), the local Blizzard UI extracts do not include full TBC compact-frame source; treat TBC as closer to Classic Era for aura and click-cast paths (no `C_UnitAuras` payload, no `C_ClickBindings`, no private aura APIs). Path B (legacy `UnitAura` polling) is the safe default; Path A (modern payload) is an opportunistic optimization to verify on first port.
- **Constraints:** TBC predates the spec system (talent points only). `Utils/SpecDefaults.lua` early-return must include the new client flag. Click-casting uses the attribute-based path like Classic Era / Pandaria — no `C_ClickBindings` interop. TRI-001 boss frames remain Retail-only and do not apply to TBC.
- **Triage impact:** Surface area is small. `Globals.lua` needs `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` branch and an `isWoWClassicTBC` flag (~5 lines). `Triage.toc` Interface line extends to `11508, 20505, 50503, 120005`. `.github/workflows/release.yml` needs a TBC build step using `BigWigsMods/packager@v2 -g bcc` (~10 lines). Per-module client gates in `Modules/AuraIndicators.lua`, `Modules/AuraListeners.lua`, `Overrides.lua`, `Utils/SpecDefaults.lua`, `GUI/IndicatorConfigPanel.lua`, `GUI/GeneralConfigPanel.lua` need TBC additions; `Utils/TestModeData.lua` needs a TBC variant (~10 lines).
- **Effort estimate:** 2-4 days focused work plus community-assisted in-game verification window.
- **Suggested spike:** D4 sub-items (D4a–D4h) in `Triage_Dev/plans/active/triage-rebuild-ingame-verification.md`. Verify CompactUnitFrame surface, aura indicator population, range fade, target markers, profile import/export, dispel overlay, test mode rendering on TBC Anniversary client.
- **Sequencing:** Should run after TRI-001a Spike B Gate 2 and TRI-005 Spike A so capability-flag layer decisions are settled. Can run in parallel with the rebuild architecture work since code surfaces don't intersect — TBC port touches `Globals.lua`, TOC, build pipeline, and per-module client gates; rebuild touches state model, providers, and schema.
- **Open product question:** Ship in a v1.x point release as a quick-win moat extension, or bundle with the v2.x rebuild release? Cost assessment recommends v1.x — low cost, meaningful differentiator, reinforces multi-client moat ahead of Cell's planned framework rewrite.
- **Notes:** Triage v1.0 launch design (`triage-v1-launch-design.md:12`) already mentions "future TBC Classic support" in the product thesis. This issue formalizes that promise as tracked work. Not unique value (other TBC Anniversary frame addons exist — Prunes ERF, Shadowed Unit Frames TBC Anniversary), but Triage would be the only addon spanning Retail + Classic Era + Pandaria + TBC under one identity.
- **Related issues:** None on GitHub yet. File when sequencing decision lands.

### Stale

*(None.)*

## In Progress

### TRI-026 Triage — ERF Reforged + Healing Addon
- **Reclassified:** Originally logged as BL-005. Reclassified as TRI-026 in STU-023 — this is a Triage project item, not studio infrastructure.
- **Type:** Feature
- **Priority:** High
- **Status:** In Progress (v1.0 scope expanded to full healing addon launch — design approved, feasibility spikes defined, Codex tasks assigned)
- **Summary:** Market research for a potential new WoW healing addon. Midnight's API changes (WeakAuras dead, CLEU removed, secret values system) created a once-in-a-decade disruption window. DandersFrames proved a new entrant can gain 1M+ downloads by being Midnight-native.
- **Market findings:**
  - Current players: Cell (4.3M, strongest), VuhDo (28.2M, "archaic"), HealBot (82.4M, broken HoTs), Grid2 (14M, survived best), DandersFrames (1M, new Midnight-native), Clique (click-casting layer)
  - WeakAuras effectively discontinued for combat data — massive gap for proc alerts, boss debuff callouts, cooldown coordination
  - All incumbents except Grid2 were broken at Midnight launch
  - DandersFrames: solo dev (DanderBot), open source (GitHub), Patreon-funded, **confirmed Claude Code user** (`.gitignore` excludes `CLAUDE.md`, `.claude/`, `.mcp.json`). Built fully custom frames (replace, not enhance). 531 commits, 84 releases in 4 months. Strengths: auto-switching layouts, built-in click-casting, visual aura designer, curated healer spec aura lists. Weaknesses: range bugs in combat, perf issues on group change, solo-dev risk, profile limit of 5, secret value taint fixes needed multiple iterations (v4.0.8–v4.1.1)
- **Guild feedback (direct user research):**
  - Boss-aware debuff priority is "pure gold" — highest value feature
  - Cross-role dispel support needed — not just healers. Mages need obvious decurse, hybrids with dispels need "big fucking obvious YOU CAN DISPEL THIS" indicator
  - VuhDo user likes DandersFrames' incoming cast tracking but can't figure out how to get VuhDo to do it — config complexity is a real barrier. DandersFrames actually uses a separate addon (TargetedSpells by ljosberinn) for this, not built-in
  - Users run multiple addons because none covers everything well
  - **Overlay vs separate frames: healers don't care** — "If you can deliver [customizability], I don't think they much care how." The separate-vs-overlay distinction is invisible to users. What matters is deep color/visual customization.
  - **Good defaults are critical** — "nice to have would be a default starting point because some have too many options and little good to start from." Confirms config UX is the #1 barrier. Ship with curated per-spec presets, don't make users build from scratch.
- **Differentiation opportunity:**
  1. Midnight-native architecture (no legacy code paths)
  2. "Enhance Blizzard frames" philosophy (overlays on CompactUnitFrame, not replacement) — no one does this well. 16+ hookable global functions available (UpdateHealth, UpdateAuras, UpdateDispellableDebuffs, etc.). Overlays are safe in combat. Follows Homestead design principles
  3. Cross-role dispel/utility support (not healer-only) — mages, shadow priests, ret paladins, enhancement shamans all have dispels
  4. Boss-aware debuff priority (fills WeakAuras void)
  5. Genuinely intuitive config UX (the #1 complaint across all addons)
  6. Accessibility as first-class design concern
- **Key technical APIs:** SecureUnitButtonTemplate, UnitHealPredictionCalculator, C_UnitAuras, C_Secrets, C_ClickBindings, whitelisted healer spells, RegisterEventCallback, CompactUnitFrame hook system, C_UnitAuras.GetAuraDispelTypeColor, TriggerPrivateAuraShowDispelType
- **DandersFrames v4.0 rewrite analysis (2026-03-23):**
  - v3.x modified Blizzard CompactUnitFrames; v4.0 switched to fully custom frames via SecureGroupHeaderTemplate
  - Drivers: (1) frames stuck/missing after roster changes, (2) taint cascades from Midnight secret values leaking through Blizzard code paths, (3) vehicle/arena frame isolation impossible while hooking shared pool, (4) test mode can't avoid protected frames, (5) secret booleans in pet range, secret strings in cross-realm names — uncontrollable when inheriting Blizzard code
  - Key insight: taint came from inheriting Blizzard's value-handling code paths (arithmetic on secret values), NOT from visual overlays. Our overlay-only approach (child frames + hooksecurefunc) avoids this — but must never read/compare values from hooked frames that could be secret
  - Human-designed architecture with AI-assisted implementation. Deep WoW domain knowledge, credits community techniques (Harrek's signature fingerprinting), authentic code style. AI accelerates boilerplate and iteration speed
  - Proactive rewrite timed to Midnight launch, not driven by user complaints
- **Blizzard API audit complete (2026-03-23):**
  - Dispel detection: no single API — need maintained spell ID table (14 class/spec combos) + C_SpellBook.IsSpellKnown(). Match against auraData.dispelName ("Magic"/"Curse"/"Disease"/"Poison")
  - Health bars must use StatusBar:SetValue() with secret values — no arithmetic. UnitHealPredictionCalculator mandatory (separate instances per use)
  - Whitelisted healer spells (Rejuv, Riptide, Beacon, Atonement, etc.) return real non-secret data
  - Boss-aware debuffs: Warcraftlogs API v2 (GraphQL) is strongest data source — query encounter abilities, analyze fight reports, ship as static dataset
  - Incoming cast: UNIT_SPELLCAST_SENT has target name but secret in 12.0 — displayable not comparable
  - ClickCastFrames global table is community interop convention
  - C_DamageMeter provides built-in meter data as CLEU replacement
- **Blizzard UI source analysis complete (2026-03-23):**
  - CompactUnitFrame has 16+ hookable global functions (UpdateHealth, UpdateAuras, UpdateDispellableDebuffs, UpdateHealPrediction, etc.)
  - Overlay pattern safe in combat: CreateFrame child + hooksecurefunc. Textures/fontstrings/non-secure children modifiable in combat. Only SetAttribute blocked.
  - Blizzard already has dispelDebuffFrames (3 colored squares + border tint) — addon overlays bigger/louder visuals on top
  - Source files need extraction: Blizzard_UnitFrame, Blizzard_CompactRaidFrames, Blizzard_CUFProfiles, Blizzard_ClickBindingUI, Blizzard_FrameXMLUtil, Blizzard_BuffFrame, Blizzard_FrameXML, Blizzard_RestrictedAddOnEnvironment, Blizzard_NamePlates, Blizzard_EditMode — via `git sparse-checkout add` on BlizzardUI repo
- **Competitor code review complete (2026-03-23):**
  - 6 addons reviewed from downloaded source: TargetedSpells, DandersFrames, Cell, Clique, VuhDo, HealBot
  - TargetedSpells: proven click-through pattern (`enableMouse=false` + `propagateMouseInput="Both"`), forked LibCustomGlow for secret value safety, 0.2s delay pattern, CompactUnitFrame discovery via `CompactPartyFrame.memberUnitFrames`
  - Cell: dispel detection via `C_Traits.GetNodeInfo()` talent introspection (better than spell ID tables), 168K lines / 144 files, no UnitHealPredictionCalculator (direct API calls instead)
  - Clique: canonical click-casting reference. Key lesson: click-through alone is insufficient; overlays must preserve the real secure unit button, hover continuity, and Blizzard/Clique click-binding paths. `ClickCastFrames` matters for custom unit-frame addons but is only part of the interop story on Blizzard frames
  - DandersFrames: filter fingerprinting for secret auras (4-boolean signature), 11 scattered combat-deferred flags (anti-pattern vs Clique's centralized queue), batch binding application with yield points
  - HealBot: root cause of HoT failure found — switches from `"HELPFUL"` to `"RAID_IN_COMBAT"` filter in Midnight combat mode, dropping most HoTs
  - VuhDo: bouquet system (composable condition chains) is genuinely innovative but intimidating UX
- **Locked decisions (2026-03-23 end session):**
  - Overlay-first on Blizzard frames; do not build replacement raid frames for early scope
  - Preserve the real secure unit button. Overlay safety means click-through **and** hover continuity, not just non-clickable visuals
  - Blizzard `C_ClickBindings` is the default click-casting path for early scope. First-party click-casting remains a possible later feature if Blizzard's system proves insufficient. Preserve external compatibility where feasible
  - Core product wedge: boss-aware debuff priority + cross-role dispel urgency + strong defaults / accessibility
- **Overlay PoC validation (2026-03-24 to 2026-03-25):**
  - Standalone PoC addon built at `BawrLabs/projects/BawrHealingOverlayPoC/` with slash diagnostics and a minimal `frame.dispels`-driven visual
  - Overlay attached correctly to real Blizzard compact party and raid frames
  - Left-click targeting, right-click unit menus, Blizzard native click-casting, and Clicked bindings all worked through the overlay
  - Real grouped dumps confirmed correct frame-to-unit mapping on `player`, `partyN`, and `raidN` frames
  - Live grouped combat in LFR produced no Lua errors and no observed frame-behavior regressions
  - Live `frame.dispels` validation passed on a real compact party frame: the PoC dispel border and top-right badge rendered correctly from Blizzard-owned state
  - Core architecture question answered: read-only Blizzard-frame overlay is viable for early scope
- **Early roadmap (2026-03-23):**
  - Top 5 core features: boss-aware debuff priority, cross-role dispel urgency, additional aura layer on Blizzard raid frames, click-safe frame enhancement, strong defaults plus accessibility options
  - Medium-tier follow-ons: targeted spell/incoming-cast alerts, enhanced health prediction emphasis, curated third-party frame support
- **Open research:**
  - Roster churn and frame reuse stress testing across joins, leaves, and party-to-raid conversion
  - Decide whether first-party click-casting should ever move beyond Blizzard native support
  - Optional: explicit Clique compatibility validation if the product wants to advertise it
  - TargetedSpells incoming-cast detection: could be built in rather than depending on external addon
  - Validate with real healers whether Blizzard-frame ceiling is acceptable
  - Runtime validation of code-derived competitor behavior claims, especially the HealBot HoT filter regression explanation
  - Name the addon and create project repo
- **Session progress (2026-03-25):**
  - V1 design doc updated: incoming cast awareness added as third core feature (Section 6.3), using curated boss dataset with `signalType` field (`aura` or `cast`). `CastDetector.lua` module added. Phase 3 expanded to "Boss-Aware Priority Layer" covering both debuffs and casts.
  - Evaluated Enhanced Raid Frames (ERF) as potential project foundation — MIT licensed, 1.7M downloads, abandoned by author for Midnight. Cloned to `C:\Projects\addon-review\EnhancedRaidFrames\`. Full codebase analysis: 8 core files, ~1,200 lines, Ace3 stack, 9-position aura indicator grid, LibDispel dispel detection, CompactUnitFrame overlay with click-through. 47 open GitHub issues, no active forks. Community research confirmed the niche is unserved post-Midnight.
  - Decision: revive ERF as the project scaffold. Keep all existing features (3x3 grid, range check, scaling, target markers, profiles, Classic support). Add healing layer as new modules on top. Port hooks for Midnight 12.0.
  - Email sent to author (Britt W. Yazel, bwyazel@gmail.com) requesting permission to continue the project under the ERF name and CurseForge listing. Awaiting response.
  - DevTool addon (also by brittyazel, MIT, actively maintained) downloaded for development use.
- **Session progress (2026-03-26):**
  - Reviewed the current discovery and design docs against the active ERF-exploration constraint. Product docs remain product-first; no adoption strategy was expanded while the owner response is still pending.
  - Audited the local ERF clone specifically for Midnight continuation work. Main likely changes remain: TOC/interface bump, embedded library refresh, overlay mouse model rework, frame lifecycle hardening, and runtime verification of free-form aura matching under `C_Secrets`.
  - Extended `BawrLabs/projects/erf-midnight-compatibility-analysis.md` with three follow-up findings: party-frame support is not explicit, direct frame scaling may conflict with Edit Mode ownership, and `C_Secrets` may require Blizzard-owned fallback signals rather than only a simple redaction check.
- **Product decisions locked (2026-04-03–04):**
  - **Name:** Triage — CurseForge listing: "Triage - Enhanced Raid Frames Reforged"
  - **Slash commands:** `/triage`, `/tri`, `/erf` (alias)
  - ERF fork under MIT license. Author (Britt W. Yazel) contacted 2026-03-26 (email) and again via CurseForge — no response received. Proceeding with fork and full attribution.
  - ERF Midnight port ships as v1.0 (all legacy features preserved). Triage healing features ship in v1.1+ (design not locked yet).
  - **Multi-version support: full support across Retail, Classic Era, and Pandaria Classic.** ERF features get equal bug fix and feature work on all clients. Triage healing layer is Retail-only (technical constraint, not policy). Classic testing is community-assisted — announcement includes open call for testers.
  - Single addon, single CurseForge listing. Healing modules are toggleable Ace3 modules inside the same addon.
  - Announcement tone: community revival, respectful continuation, full credit to Soyier.
  - Design spec: `BawrLabs/projects/triage-design-spec.md`
  - Implementation plan: `BawrLabs/projects/triage-v1-implementation-plan.md` (11 tasks, Codex-reviewed)
  - Confirmed Midnight crash: `Overrides.lua:133` — `UnitInRange()` secret boolean taint. Fixed in plan Task 2.
- **Setup (complete):**
  - GitHub repo: `Royaleint/Triage` (not a fork, clean clone with attribution)
  - Local repo at `C:\Projects\Triage\`, symlinked to WoW AddOns as `Triage`
  - CurseForge listing created: slug `triage-erf`, icon uploaded
  - Dev folder: `C:\Projects\Triage\Triage_Dev\` with plans, reference, session dirs
  - All project docs copied from BawrLabs/projects/ to Triage_Dev/reference/
- **Implementation (session 15, 2026-04-04):**
  - Tasks 0-10 complete and pushed. Task 11 (in-game verification) remaining.
  - Icon design finalized: anvil + medical cross + borrowed time clock (DALL-E generated)
  - CurseForge blurb written with Soyier credit
  - Mouse model: hybrid approach (Retail XML propagation, Classic parent-level scanning)
  - Range fix: GetFriendMinChecker (was using MaxChecker, caused undim regression)
  - Minimap button added (LibDBIcon + spell_holy_borrowedtime icon)
  - Code quality drift identified in late session — documented for process improvement
- **Session progress (2026-04-05/06, sessions 16-17):**
  - Task 11 in-game verification COMPLETE. 10 bugs found and fixed during verification:
    - /triage and /tri opening ESC game menu (HideUIPanel fix)
    - TargetMarkers + AuraIndicators secret number taint on GetHeight/GetWidth/powerBar
    - AuraListeners GetBleedList nil (LibDispel never had this method — bleed works natively on Retail)
    - GetRaidTargetIndex returning secret number
    - Profile switching crash on fresh/default profiles
    - Settings panel ADDON_ACTION_BLOCKED during combat (InCombatLockdown guard)
    - Range check undim regression (multiple iterations — final: Blizzard handles default, LibRangeCheck for custom only)
    - Mouseover macros not working through indicators (explicit SetPropagateMouseMotion)
    - frame.outOfRange secret boolean taint
    - Stock aura OnShow hook self-shadowing
  - Classic API reference created: FrameXML sparse checkout for Classic Era (1.15.8) and Pandaria Classic (5.5.3). New `classic_api_differences` tool in wow-api MCP. Former BL-008.
  - Dispel overlay feature IMPLEMENTED and merged to main (feature/dispel-overlay branch):
    - Standalone Modules/DispelOverlay.lua — edge border + glow on raid frames when player can dispel
    - Reads frame.dispels PriorityTable (:Size() API) + LibDispel — zero secret values
    - Hooks CompactUnitFrame_UpdateAuras (timing confirmed in-game via /tridev)
    - 6 settings, Retail only, code review findings addressed
  - Triage_Dev companion addon created with dev/debug slash commands (/tridev)
  - GitHub issue templates added (bug report + feature request with Game Version field)
  - Announcement drafts written (CurseForge, Reddit, GitHub issues) — v2, rewritten for voice
  - LibDualSpec updated v1.27→v1.29, CallbackHandler and LibStub refreshed
  - Triage queued-work section created with TRI- prefix (TRI-001 boss frames, TRI-002 addon import)
  - 3 GitHub issues created: #1 boss frames, #2 addon import, #3 dispel overlay
- **Session progress (2026-04-07, session 18):**
  - Implemented `TRI-004` on worktree `tri-004-frame-registry` with a central managed-frame registry replacing direct compact-frame iteration. Branch commits:
    - `445d6ff` — `refactor: add managed frame registry`
    - `5b51eea` — `fix: support boss units and unnamed managed frames`
  - `TRI-004` code review completed. Two findings were identified and fixed:
    - Registry processing now defaults to registry-supported unit tokens, so managed `boss1..boss5` frames flow through existing module call sites.
    - Indicator/listener child-frame creation is now safe on unnamed managed frames, which matters for future addon-owned boss frames.
  - Started `TRI-003` follow-up work on worktree `tri-003-colored-dispel-glow`:
    - `ccc2fbf` — `build: vendor LibCustomGlow for colored dispel glow`
    - `.pkgmeta` and `Libs/embeds.xml` updated; `Libs/LibCustomGlow/` vendored
    - Integration into `Modules/DispelOverlay.lua` remains open
  - Reviewed and revised `Triage_Dev/plans/active/triage-v1-launch-design.md`:
    - Default rollout state changed from global marker to profile-scoped `defaultsState`
    - Classic Era click-casting explicitly changed to preset-based profiles (no spec auto-switch)
    - Click-casting spike expanded to validate keyboard hover/global hovercast paths with a mouse-only v1 fallback
  - **Release pipeline built and tested:**
    - GitHub Actions workflow (BigWigsMods/packager@v2) — 3 game versions
    - .pkgmeta fixed (all 25 embedded-library names corrected)
    - X-Curse-Project-ID (1504503) and X-Wago-ID (5NR82vK3) added to TOC
    - CurseForge webhook fixed (was pointing to Homestead project 1450714)
    - Wago webhook confirmed working. CurseForge pending first-upload moderation.
    - Test tag v0.0.1-test: all zips built, GitHub Release created
  - **Click-casting research completed:** Full analysis of Blizzard C_ClickBindings, Clique v4.8, Clicked v1.17, DandersFrames click-casting module. Compiled macro approach selected (Approach B).
  - **v1.0 scope expansion approved:** 6 launch features, 5 differentiators. Feasibility spike checklist written at `Triage_Dev/plans/active/feasibility-spikes.md`.
  - **wow-addon-dev skill updated:** Secret value patterns, CompactUnitFrame overlay pattern, classic_api_differences reference, wipe() note, globals count fix.
  - **New GitHub issues created:** #4-#12 covering all launch features and Codex tasks
- **Session progress (2026-04-09/11, session 19):**
  - Confirmed current `main` is linearized after rebase; older merge-SHA references in session docs are stale.
  - TRI-003 is on `main` as `53807f4` and `edb877d`.
  - TRI-004 is on `main` as `7eb36f0` and `0588c57`.
  - TRI-007 is on `main` as `24248dd`, `ff31723`, `185c6a5`, `c93b4a3`, `886cc61`, `9e75dfa`, and `dbc1a66`.
  - Argus QA passed on TRI-003 vendoring (WARN: ProcGlow is Retail-only, but Triage uses only ButtonGlow).
  - Cherry-picked queued-work docs from `Triage-Analysis-ERF-Issues` branch (build file regressions excluded).
  - Added 18 new queued items (TRI-008 through TRI-025) from ERF open issues and competitor analysis.
  - Created 14 GitHub issues (#17-#31) to sync tracker items with repo issues; created `quick-win` label.
  - Cleaned up 3 stale remote branches (Triage, BawrLabs, Homestead) and 1 stale local branch (Homestead).
  - Reviewed Claude Code releases v2.1.92-v2.1.98 against all CLAUDE.md files — no updates needed.
- **Session progress (2026-04-20, v1.0.0 release):**
  - **Triage v1.0.0 — ERF Reforged shipped to all three platforms:** GitHub Release, CurseForge (project 1504503), Wago (5NR82vK3). Final tag at commit `fd11afb` (workflow run 24696631355, success). Per-game-version zips: Retail (12.0.1), Classic Era (1.15.8), Pandaria Classic (5.5.3).
  - **AceTab-3.0 removed** from vendoring — was inherited from ERF but unused, and CurseForge rejected the auto-derived slug `acetab-3.0`. See `.pkgmeta` comment for re-add guidance if TRI-014 wants the Tab-key autocomplete pattern.
  - **`.pkgmeta` migrated from `embedded-libraries:` to `externals:`** matching Homestead's pattern. Root cause of v1.0.0 CurseForge failures: BigWigs packager auto-derives CF slugs from `embedded-libraries` entry names keeping dots (e.g. `libdualspec-1.0`), but CurseForge stores slugs with hyphens (e.g. `libdualspec-1-0`). External URLs let us name the slug correctly via the URL path. Hybrid approach: WowAce SVN for libs hosted there, GitHub for libs that aren't (LibDualSpec-1.0, LibRangeCheck-3.0, LibDeflate, LibClassicDurations, LibDispel, LibCustomGlow). `curse-slug` overrides set for GitHub libs with confirmed CF presence.
  - **Workflow `awk` extractor bug fixed** (`.github/workflows/release.yml`) — previously grabbed top CHANGELOG section regardless of pushed tag (caused v0.0.2 to ship with v1.0.0 release notes). Now matches the section heading by tag and fails loudly if no matching section exists.
  - **CHANGELOG `Classic Era + Pandaria Classic` claim softened** to "ships alongside Retail — community testing welcome" per locked decision.
  - **GitHub repo secrets configured by Rawb:** `CF_API_KEY` and `WAGO_API_TOKEN` (without these, all upload attempts silently produced empty release notes; the failure mode that hid the AceTab/embedded-libraries issue).
  - **Cleanup:** v0.0.2 GitHub Release + tag deleted; v1.0.1 tag (interim packaging-fix attempt) deleted; v1.0.0 re-tagged at the cleanup HEAD.
  - **Open from this session — TRI-003 follow-up:** uncommitted changes to `Modules/DispelOverlay.lua` and `Localizations/enUS.lua` (Blizzard dispel highlight atlas integration) restored from stash to Triage main working tree. Needs Argus review + worktree migration before merge. Saved for a future session.
- **Session progress (2026-04-21, post-12.0.5 launch):**
  - **12.0.5 live.** Two login-time Lua errors surfaced immediately. Shipped hotfixes as TRI-027 (`Libs/embeds.xml` stale `AceTab-3.0` include removed — commit `378360a`) and TRI-028 (`Overrides.lua` existence guard for `CompactUnitFrame_UpdatePrivateAuras` SecureHook — commit `1f36640`). Merged to main as `3ba6b3e`, Argus Gate 1 passed, Rawb Gate 2 passed on Retail (no errors on login/zone/roster).
  - **12.0.5 private-aura removal confirmed.** `/dump CompactUnitFrame_UpdatePrivateAuras` returned `nil` — Blizzard removed the free-standing global and moved private-aura handling to the `CompactUnitPrivateAuraAnchorMixin:SetUnit` path. Filed TRI-029 to retire or rework the now-dead `UpdatePrivateAuraVisOverrides` polish code. Guard stays either way.
  - **TRI-003 atlas follow-up rescued.** The parked Blizzard dispel highlight atlas work from Session 24 (uncommitted for 8 days) preserved on new branch `tri-003-atlas-followup` at commit `2e73752`. Filed TRI-032 to track Gate 1 + in-game re-verify.
  - **Comms items filed.** 17 organic CurseForge downloads since v1.0.0 with zero announcement push — filed TRI-030 (publish announcement, refresh Session 16-17 drafts) and TRI-031 (replace placeholder Soyier CF screenshots after TRI-003/004/007 Gate 2 passes). Both under a new `Release & Comms` queued subsection.
  - **Worktree cleanup.** Removed 3 merged worktrees (`tri-003-colored-dispel-glow`, `tri-004-frame-registry`, `tri-027-login-errors`) and 4 stale branches (the three above plus `fix/remove-acetab`). `stu-034-tracker-split` worktree held per Rawb (Category C — 1 real unmerged cutover-SHA commit).
  - **Studio-side impact:** Stop and PreCompact hooks were broken project-agnostically (relative paths + Windows-path-mangling regex). Fixed in BawrLabs this session — session heartbeat now fires correctly across all projects.
- **Session progress (2026-04-23, v1.1.0 release):**
  - **Triage v1.1.0 shipped to all three platforms:** GitHub Release at tag `v1.1.0` (commit `a90a59d`, workflow run 24814684602, 3m 28s). Per-client zips uploaded to CurseForge (project 1504503) and Wago (5NR82vK3): Retail (Interface 120005), Pandaria Classic (50503), Classic Era (11508). Retail TOC bumped 120001 → 120005 for 12.0.5.
  - **Five quick-win features shipped** — all PRs reviewed through Argus Gate 1 and merged to main in sequence:
    - TRI-021 extended custom range to 60yd on Retail (PR #36, commit `a3a9dfa`). Argus flagged silent-failure when `LibRangeCheck:GetFriendMinChecker` returns nil for the selected distance — fix: user-facing chat warning on both `customRangeCheck` and `customRange` `set` callbacks.
    - TRI-022 three-way caster filter All / Mine / Not Mine (PR #37, commit `9eef674`). DB migration 2.2 → 2.3 converts `mineOnly` boolean to `casterFilter` string, idempotent. Full Argus PASS.
    - TRI-023 transform-spell hint in Aura Watch List (PR #38, commits `a4d0dc9` + `bd6f4c5`). Landed as GUI hint + localization only; `TRANSFORM_SPELLS` lookup table shipped initially but removed per Argus feedback (no runtime consumer, ambiguous positional 4-tuple). Deferred to land with TRI-014 consumer.
    - TRI-024 finer position steps (0.5%) + countdown text anchor dropdown (PR #39, commit `c4b59d9`). Also fixes a latent anchor-accumulation bug in `UpdateStackSizeText` by hoisting `Countdown:ClearAllPoints()` above the branches.
    - TRI-025 keep-indicators-visible-out-of-range toggle (PR #40, commit `eef5944`). Uses `SetIgnoreParentAlpha` with a defensive method check; placed on the `SetIndicatorAppearance` / `RefreshConfig` path for mid-session toggle without `/reload`.
  - **Merge conflict on PR #40 resolved locally** — PR #36's `customRangeUnavailable` key collided with PR #40's `keepIndicatorsVisible` strings in `Localizations/enUS.lua`. Both kept, merged at commit `5123958` and re-pushed.
  - **Public v1.1.0 CHANGELOG rewritten** in imperative voice per Rawb feedback (outcome-first bullets, no jargon, no internal codenames, no file paths / SHAs). v1.0.0 heading expanded to "Triage - Enhanced Raid Frames Reforged" in both `CHANGELOG.md` and `README.md`.
  - **TRI-027 and TRI-028 hotfixes** (previously Awaiting Release) shipped inside v1.1.0 alongside the five features.
  - **Release:** `luacheck` 0 errors / 2 warnings (both in `Triage_Dev/` dev-only code, not shipped). Tag `v1.1.0` pushed, BigWigs packager workflow produced 4 assets (Retail zip, Mists zip, Classic zip, release.json) and uploaded to CF + Wago.
- **Session progress (2026-04-26, rebuild verification):**
  - **Strategic direction re-validated:** ERF-preserving architectural rebuild remains the favored path. Do not rewrite from scratch. Keep EnhancedRaidFramesDB, `/erf`, legacy 3x3 indicator behavior, and multi-client support while adding owned-frame surfaces where proven.
  - **GitHub issue update attempt blocked:** Codex attempted to add finding comments to GitHub issues `#1`, `#4`, `#5`, `#8`, `#9`, and `#13`, but the GitHub app returned 403 `Resource not accessible by integration`. Tracker was updated locally instead; issue comments still need to be applied manually or after connector permissions are fixed.
  - **TRI-001 / Spike B:** Local Blizzard UI source review supports addon-owned secure/compact boss frames bound to `boss1`-`boss5`; remaining uncertainty is live encounter lifecycle, combat lockdown, and taint.
  - **TRI-001 / Spike B live dungeon result:** Dungeon boss test of `TriageDevBossFrame1` using addon-created `CompactUnitFrameTemplate` bound to `boss1` failed with Retail secret-value taint in Blizzard compact-frame update code. Errors hit `CompactUnitFrame_UpdateHealPrediction` (`maxHealth` secret number) and `CompactUnitFrame_UpdateInRange` (`checkedRange` secret boolean) while execution was tainted by `Triage_Dev`. **Implication:** The naive owned `CompactUnitFrameTemplate` boss-frame path is not safe on Retail Midnight for boss units. Spike B should be marked failed/blocked for this implementation shape; next research should evaluate a lower-level owned `SecureUnitButtonTemplate` visual clone or a read-only overlay/anchor strategy that avoids Blizzard compact-frame health/range/heal-prediction update code.
  - **TRI-005 / Spike A:** Directly mutating Blizzard compact frames for Triage click-cast caused Retail Midnight secret-value taint in Blizzard compact-frame range and health paths. Owned secure click probe path passed non-healer A1/A3/A4 after reload. Implementation scope changed to owned/provider-safe frames; Blizzard compact frames should preserve native/external click-cast paths.
  - **TRI-003 / dispel:** Non-healer C1 probe command worked. Follow-up PvE/follower testing showed `frame.dispels` is not the correct Retail Midnight source for active dispel overlay state. Blizzard's live signal is `frame.DispelOverlay.dispelDebuffFrames[i].aura`, but the aura object fields and even `IsShown()` calls can be secret/blocked. Treat `frame.dispels` as non-load-bearing on Retail 12.0+ and rename any capability around this to the Blizzard dispel-overlay state path.
  - **Spike C / TRI-010:** Source review reduces secret-safe boss debuff handling to curated whitelist + graceful degradation. C4 was inconclusive on non-healer because no matching active aura/debuff was visible.
  - **PvP healer verification (2026-04-26, Restoration Druid BG):** Retail BG compact raid frames were discovered correctly (`10` visible raid frames), but `frame.dispels` was nil on visible PvP raid frames and capability dump reported `supportsFrameDispels=false`. LibDispel correctly reported Druid dispel capability as `Poison, Magic, Curse`. `TriggerPrivateAuraShowDispelType` was absent. Aura whitelist probing showed `774`/Rejuvenation readable once with duration/stacks, then later secret; other Druid HoT IDs hit secret `spellId` guards. User observed the visual dispel border/glow path working and stable with no Lua errors, but no pulse was visible. Healer geometry was usable, with a note that hovering did not always behave as expected. **Implication:** PvP must be treated as a degraded data context for dispel urgency/whitelist work; visual active-dispel signaling can work, but `frame.dispels` and aura-field matching are not reliable load-bearing sources there.
  - **Follower-style party verification (2026-04-26, Restoration Druid):** `/tridev dispelbundle druid` wrote a new report at `12:38:45`. Runtime capability still reported `supportsFrameDispels=false`, but whitelist probes successfully found `774`/Rejuvenation and `8936`/Regrowth on visible party frames. `33763`/Lifebloom, `48438`/Wild Growth, and `102351`/Cenarion Ward did not match and skipped `27` aura(s) with secret `spellId`. **Implication:** Normal party/follower-style content improves readability for some friendly HoTs, but `frame.dispels` still should not be assumed available and spell-ID matching still needs secret-safe fallback behavior.
  - **Follower dungeon frame-context check (2026-04-26, Restoration Druid):** `/tridev dungeoncheck follower` in Windrunner Spire recorded `type=party`, `difficulty=205/Follower`, `group=5`, `5/5` compact party frames, normal `player`/`party1`-`party4` unit tokens, and both Blizzard/Triage dispel overlay objects present on all five frames. Follower units were NPC-controlled (`UnitIsPlayer=false`, `UnitPlayerControlled=false`) but assist-friendly and class-tagged. **Implication:** Follower dungeons are valid for frame discovery, provider assumptions, overlay attachment, aura-surface presence, and general party layout checks. They are not a full substitute for player dungeon addon-coexistence, real-player aura/cooldown behavior, social roster churn, or player-specific role edge cases.
  - **TRI-011:** Spatial cluster finder is reframed into Triage Focus / priority heal target highlight. Use range + deficit + incoming-heal-aware scoring where safe; avoid true position-based clustering.
  - **Capability flags:** Capability layer should replace scattered client/frame assumptions. Current derived shape includes UnitAura payload support, LibClassicDurations need, LibDualSpec support, compact party frames, mouse input propagation, private-aura suppression/hooking, spec defaults, Retail indicator features, `frame.dispels`, and Triage-owned click-cast support.
- **Pending (next session):**
  - **Gate 2 for v1.1.0 features** — run the per-PR in-game checks from Argus Gate 1 review: caster filter two-druid test, keep-indicators-visible toggle with `rangeAlpha`, countdown corner placement, 0.5% offset slider stepping, extended-range warning on DPS/tank spec, transform-spell hint renders in config panel.
  - **Gate 2 for v1.1.0 DB migration** — load a pre-v1.1.0 profile with `mineOnly = true/false` and confirm 2.2 → 2.3 migration rewrites to `casterFilter = "mine" / "all"` and drops the old key.
  - **Verify CurseForge v1.1.0 listing** — public changelog rendered correctly, all three client builds present.
  - Run remaining click-casting spike items in-game (Retail): A2/A5 still open; A1/A3/A4 passed on owned `TriageDevClickProbeFrame`; direct Blizzard CompactUnitFrame mutation is now considered unsafe on Midnight.
  - Run boss frame spike B1-B6 in-game (Retail).
  - Revise TRI-001 boss-frame architecture before any further live boss testing. Do not rerun the current `CompactUnitFrameTemplate` boss prototype except as an explicit unsafe retest.
  - Run click-casting spike A6-A7 on Classic Era.
  - Urgency glow data source investigation (Spike C): PvP healer and follower/PvE checks completed for Restoration Druid. `frame.dispels` is no longer a candidate source on Retail Midnight; remaining PvE value is limited to confirming non-secret availability for curated whitelist entries in live dungeon/M+/raid contexts and validating graceful-degrade visuals.
  - Optional: run `/tridev dungeoncheck player` in a real player dungeon to compare against the saved follower snapshot. This is useful but not blocking for frame/provider assumptions.
  - **TRI-032** — Gate 1 (Argus) and in-game re-verify for the atlas neutral-fallback work on branch `tri-003-atlas-followup` (`2e73752`).
  - **TRI-029** — decide whether to rework or delete `UpdatePrivateAuraVisOverrides` (now confirmed dead on 12.0.5 via `/dump`).
  - **TRI-030** — refresh Session 16-17 announcement drafts against current state, then publish (CurseForge, Reddit, GitHub). v1.1.0 launch is a natural bundling moment.
  - **TRI-031** — swap placeholder Soyier CF screenshots now that TRI-004 is complete.
  - Verify CurseForge v1.0.0 moderation status (web UI).
  - Clean up Wago duplicate v1.0.0 + v1.0.1 entries (web UI — old failed-release artifacts).
  - Classic Era testing (community-assisted).
  - Clean up `.worktrees/stu-034-tracker-split` after deciding whether to merge or drop the one-commit `fix/stu-034-cutover-sha` (Tri_Completed footer placeholder `<CUTOVER-SHA>` → `2951ea8`).
- **ERF Midnight compatibility analysis (2026-03-25):**
  - Full analysis at `BawrLabs/projects/erf-midnight-compatibility-analysis.md`
  - Not a rewrite — port plus two structural fixes (overlay mouse model rework, frame lifecycle hooks) and one verification gate (aura matching under C_Secrets)
  - Pre-existing bugs found: glow API deprecated in 11.1.7 (silent failure), mineOnly precedence bug
  - Multi-client: must maintain Classic Era, Cata/Pandaria Classic, and Retail. Healing layer Retail-only. Classic paths are frozen.
  - Cross-promotion opportunity: ERF users are self-selected Blizzard-frame-enhancement users — natural Homestead audience
- **PTR 12.0.5 API findings (2026-03-25):**
  - `C_HousingCatalog` — 36 members. New function: `GetAllVariantInfosForEntry` (dye variant consolidation API). All existing safe calls still present.
  - `C_HousingDecor` — 31 members, no visible changes.
  - `C_CatalogShop` — 38 members.
  - `C_HousingPhotoSharing` — nil (not available yet).
  - `GetAllFilterTagGroups` returned 5 groups (was 6 in earlier reference) — Theme, Expansion, Style, Culture, Size. Needs diff against live.
  - Discovery scanner: maxRecordID 4562, ~712 items (live: 4562, ~711). Only +1 item on PTR so far — 317 datamined items not yet in catalog API.
  - Housing panel not available on PTR without a house — CatalogOverlay visual testing deferred to live or later PTR build.
- **Project documents:**
  - `BawrLabs/projects/healing-addon-discovery.md` — Product discovery document (strategic, Codex-verified)
  - `BawrLabs/projects/healing-addon-design-v1.md` — Draft product design for the first real addon version after PoC validation
  - `BawrLabs/projects/healing-addon-architecture-analysis.md` — Competitive architecture analysis (technical reference, 12 cross-cutting sections + addon profiles + anti-patterns + quick-reference tables)
  - `BawrLabs/projects/healing-addon-feature-priorities.md` — Ranked user-facing feature priorities and competitor strengths
  - `BawrLabs/projects/healer_roadmap_featsV0.md` — Early feature roadmap (top 5 core features + 3 medium-tier follow-ons)
  - `BawrLabs/projects/healing-addon-poc-spec.md` — PoC scope, acceptance criteria, and validation result
  - `BawrLabs/projects/erf-midnight-compatibility-analysis.md` — ERF Midnight port analysis (Claude + Codex findings)
  - `BawrLabs/projects/BawrHealingOverlayPoC/` — Standalone overlay viability addon used for in-game testing
  - `Homestead/Home_Dev/reference/HEALING_ADDON_ARCHITECTURE_REVIEW.md` — Raw all-in-one review (supplementary)
  - Blizzard UI source extracted at `C:\Projects\BlizzardUI\` (10 healing-related directories via sparse checkout)
  - Competitor addon source copied to `C:\Projects\addon-review\` for reference (7 addons, including ERF)
- **Notes:** Separate project from Homestead, but shares the BawrLabs platform layer (Ace3, WoW API MCP server, studio workflow). Would be a second addon under the BawrLabs umbrella.

## Awaiting Release

*(None — v1.1.0 released 2026-04-23.)*
