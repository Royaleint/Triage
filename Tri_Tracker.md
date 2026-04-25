# Triage — Tracker

Active and queued work for the Triage addon. Completed items live in
`Tri_Completed.md`. Cross-project status rollup lives in
`BawrLabs/INDEX.md`.

## Backlog

### Next Release

*(None — populated by Rawb as scope decisions are made.)*

### Bugs

*(None.)*

### Features

### TRI-001 Boss frames as raid-style compact frames
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Summary:** Boss unit frames (Boss1–Boss5) are Blizzard's default `TargetFrame` buttons, not compact raid frames. On fights like Lura, healable adds appear in these frames and healers have no way to configure them. Supporting them would require addon-owned compact-style boss frames so they can receive Triage indicators, dispel overlay, range, and profile-driven appearance.
- **Source:** Direct guild feedback from a healer.
- **Research status:** Initial feasibility review complete (2026-04-06).
- **Findings:** Retail-only and technically feasible, but not as a pure overlay feature. Blizzard's compact frame system can bind fixed unit tokens, so addon-created `CompactUnitFrameTemplate` buttons can target `boss1`–`boss5`. Blizzard arena frames prove the template supports fixed unit tokens, and Cell already ships a separate boss/NPC unit-frame surface.
- **Constraints:** Frames must be pre-created and unit-bound out of combat, then shown/hidden with `RegisterUnitWatch` as bosses appear mid-fight. Avoid the Blizzard `Arena` compact-frame mode because its PvP-specific option path disables dispel indicators; use Party-style sizing/options or a compact setup clone instead.
- **Triage impact:** Current architecture only iterates Blizzard raid/party compact frames and filters to `player`/`party`/`raid` units. This feature needs a managed frame registry, boss-aware iteration, and selective widening of `ShouldContinue()` rather than a small hook on the existing code.
- **Suggested spike:** Build one Retail-only prototype frame for `boss1`, anchor it near `BossTargetFrameContainer`, and validate targeting, right-click menu, Blizzard click-casting, aura listener updates, dispel overlay, and encounter-time appearance before committing to all five frames.
- **Notes:** High differentiator for Blizzard-frame users, but not literally unique — Cell already supports boss/NPC frames. Bigger scope than the current overlay-only healing modules. Retail only.

### TRI-002 Import aura watch lists from other addons
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
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
- **Status:** Research Complete, Spike Defined
- **Summary:** Compiled macro click-casting system. Harm/help conditionals, Smart Resurrection, per-spec defaults. Retail + Classic support. Feasibility spike required before full implementation. GitHub issue #5.

### TRI-006 Curated per-spec aura defaults
- **Type:** Feature
- **Priority:** High
- **Status:** Gate 1 Ready
- **Summary:** Pre-configured Retail aura watch lists for 7 healer specs + utility dispellers, with manual Apply/Reset actions in Indicator Options. Paired with click-casting defaults for out-of-box experience. GitHub issue #7.
- **Branch:** `tri-006-apply-spec-defaults`
- **Verification:** Targeted `luacheck` on touched Lua files passed with 0 warnings / 0 errors.

### TRI-008 Auto layout switching — content-aware profile selection
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** Competitor analysis (Danders), ERF #58. 4 users +1'd on ERF over multiple years.
- **Summary:** Auto-switch profiles based on content type and group size (dungeon, raid, BG, open world). Per-size-range profiles, auto-detection on roster/zone change, combat-safe queuing. Ships with sensible defaults (party 1-5, raid 6+). GitHub issue #14.

### TRI-009 Priority-chain indicators — "show X, else Y, else Z" per slot
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** Competitor analysis (VuhDo bouquet system).
- **Summary:** Each indicator slot supports an ordered priority chain of conditions (specific aura, aura type, health threshold, aggro, role, missing buff). First match wins. Visual drag-and-drop editor, not nested dropdowns. Default profiles use simple single-aura slots — chains are opt-in.

### TRI-010 Pre-configured raid debuffs with auto-detection
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** Competitor analysis (Cell curated lists, Grid2 auto-detection).
- **Summary:** Ship curated per-tier debuff lists for current content. Auto-detect unknown debuffs in combat and surface them for review post-encounter. Dedicated "raid debuff" indicator mode shows highest-priority active boss debuff without manual config. Works with priority chains (TRI-009).

### TRI-011 Cluster heal finder — AoE heal target recommendation
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Source:** Competitor analysis (VuhDo — only addon with this feature).
- **Summary:** Highlight the best target for AoE/chain heals by detecting clusters of nearby injured players. Configurable radius, health threshold, per-spell presets. Performance-sensitive — needs throttled updates (0.2-0.5s). Uses positional data from C_Map or combat log range checks.

### TRI-012 Raid tools panel — ready check, pull timer, markers, trackers
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Source:** Competitor analysis (Cell — only raid frame addon with built-in raid tools).
- **Summary:** Lightweight collapsible panel near raid frames. Core: ready check, raid markers, pull timer (syncs with DBM/BigWigs), battle res tracker. Extended: buff/consumable checker, interrupt tracker, cooldown tracker. Auto-appears for raid leaders/assists.

### TRI-013 Pinned frames — custom frame groups for priority targets
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Source:** Competitor analysis (VuhDo private tanks).
- **Summary:** Pin specific players into a dedicated always-visible frame group independent of Blizzard Main Tank assignments. For assigned healing — pin co-healer, assigned tank, priority targets. Multiple named groups, drag-and-drop or right-click to pin. Depends on frame registry (TRI-004).

### TRI-014 Spell validation with autocomplete in aura configuration
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** Original — no competitor has this.
- **Summary:** Real-time spell name validation and autocomplete in aura config fields. Validates against C_Spell.GetSpellInfo(), supports spell IDs and fuzzy matching ("rejuv" → "Rejuvenation"). Warning icon on typos. Eliminates the most common config error across all raid frame addons.
- **Notes:** AceTab-3.0 was removed from vendoring in v1.0.0 (was inherited unused from ERF; CurseForge slug `acetab-3.0` invalid). If implementing via the Tab-key autocomplete pattern, re-vendor AceTab-3.0 with the correct CurseForge externals override or use an alternative pattern (Blizzard's `AutoCompleteEditBoxTemplate`, AceGUI editbox + live `OnTextChanged` suggestions, or LibAdvancedAutoComplete).

### TRI-015 First-run experience — spec detection, welcome flow, progressive disclosure
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** Original — UX strategy.
- **Summary:** Detect class/spec on first load, apply defaults automatically, show brief dismissable tooltip. Progressive disclosure in settings: simple mode by default, advanced toggle for power users. Ship 3 preset templates (Raid Healer, Dungeon Healer, DPS Dispeller). This defines how the UX layer system manifests in the UI.

### TRI-016 Buff/debuff blacklist for stock Blizzard icons
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** ERF #142, #110. Most requested feature across ERF issues (3+ users over multiple years).
- **Summary:** Granular control over which buffs/debuffs show in Blizzard's stock icon display. Blacklist mode (hide specific auras) and whitelist mode (hide all except listed). Separate lists for buffs and debuffs. Current workaround (disable all + re-add as indicators) wastes indicator slots.

### TRI-017 Copy/sync indicator settings between positions
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Source:** ERF #122.
- **Summary:** Copy visual settings (size, text, animation, colors) from one indicator position to others. Optional sync mode to link positions. Bulk reset to defaults. Excludes aura lists (always per-position). Reduces tedium of configuring 9 positions with similar appearance.

### TRI-018 Health bar color by health percentage
- **Type:** Feature
- **Priority:** High
- **Status:** Backlog
- **Source:** ERF #135. Standard feature in VuhDo and Grid2.
- **Summary:** Dynamically color health bars by remaining health (green → yellow → red). Options: class colors, flat custom color, or gradient. Configurable thresholds, smooth vs stepped. Coexists with debuff-type coloring (TRI-019) via priority. Uses SetStatusBarColor on frame.healthBar.

### TRI-019 Frame color by debuff type
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Source:** ERF #57. VuhDo staple feature.
- **Summary:** Override health bar color with debuff type color when a dispellable debuff is active (Magic=blue, Curse=purple, Poison=green, Disease=brown). Configurable per type, priority when multiple active, option to limit to player-dispellable types. Complements existing dispel border/glow overlay. Toggle: border-only, bar-color-only, or both.

### TRI-020 Multiple auras per indicator position
- **Type:** Feature
- **Priority:** Medium
- **Status:** Backlog
- **Source:** ERF #33.
- **Summary:** Show multiple active matching auras at a single indicator position as stacked sub-icons (up to 4). Configurable direction (horizontal, vertical, grid). Alternative: cycle through matches on a timer. Default unchanged (first match). Partially overlaps with priority chains (TRI-009) — different use case (show everything vs show most important).

### Data

*(None.)*

### Maintenance

### TRI-029 Retire or rework UpdatePrivateAuraVisOverrides (dead on 12.0.5)
- **Type:** Maintenance
- **Priority:** Low
- **Status:** Backlog
- **Source:** TRI-028 follow-up (2026-04-21). Confirmed via `/dump CompactUnitFrame_UpdatePrivateAuras` → `nil` on live 12.0.5.
- **Context:** Midnight 12.0.5 removed the free-standing `CompactUnitFrame_UpdatePrivateAuras` global. Private-aura handling moved to `CompactUnitPrivateAuraAnchorMixin:SetUnit` (CompactUnitFrame.lua:2711 in our Blizzard source extraction). TRI-028's existence guard prevents the error but leaves `UpdatePrivateAuraVisOverrides` permanently unreachable on Retail — the polish behavior that hides private-aura anchors when `showDebuffs` is off no longer runs.
- **Acceptance criteria:** Decide between (a) reworking `UpdatePrivateAuraVisOverrides` against the current `PrivateAuraAnchors` / mixin path so the polish works again on 12.0.5, or (b) deleting `UpdatePrivateAuraVisOverrides` and its call site as permanently dead code. Document the choice. Existence guard in `Overrides.lua:22` stays either way.
- **Notes:** Low priority — polish feature for a niche setting most users don't change. File if someone reports private auras visibly leaking through `showDebuffs = false`.

### Release & Comms

### TRI-030 Publish Triage v1.0.0 announcement
- **Type:** Communications
- **Priority:** Medium
- **Status:** Backlog — drafts ready, awaiting Rawb go
- **Source:** Session 2026-04-21. 17 organic CurseForge downloads since v1.0.0 launch (2026-04-20) with zero announcement push. Signal that ERF-redirect discovery is working; announcement would amplify reach.
- **Scope:** Refresh announcement drafts (CurseForge news post, Reddit, GitHub issues) written in Session 16-17 against current state — v1.0.0 shipped, CurseForge moderation cleared, placeholder Soyier photos stand on the listing, TRI-003/004/007 merged but pending Gate 2.
- **Voice:** Rawb's voice, not Blizzard style (memory: author voice vs product voice). Reddit post keeps rough edges per anti-AI signal pattern. Tone per locked decision (2026-04-03): community revival, respectful continuation, full credit to Soyier.
- **Owner at execution:** Everett.
- **Notes:** Timing is Rawb's call — no urgency. Organic 17 is a bonus, not a deadline driver. Classic Era + Pandaria Classic framed as "ships alongside Retail — community testing welcome" per the locked v1.0.0 softening.

### TRI-031 Replace placeholder Soyier photos on CurseForge listing
- **Type:** Communications / Assets
- **Priority:** Low
- **Status:** Backlog — blocked on TRI-003/004/007 Gate 2
- **Source:** Session 2026-04-21. Soyier's original ERF screenshots currently on the Triage CurseForge listing (intentional placeholder during the revival handoff — visual continuity signal for returning ERF users).
- **Acceptance criteria:** (1) Original Triage screenshots captured showing current v1.0 features in-game (test mode preview, dispel overlay with colored glow, indicator grid, minimap button, settings panel). (2) CurseForge listing screenshots replaced. (3) Wago listing screenshots updated to match.
- **Depends on:** TRI-003, TRI-004, TRI-007 Gate 2 pass. Screenshots should reflect verified-shipped behavior, not pre-Gate-2 state.
- **Owner at execution:** Everett (listing updates) + Rawb (actual screenshots, since only Rawb has the in-game environment).
- **Notes:** The placeholder is not a bug — it's continuity signal. Don't rush the swap; swap when we have the full set of verified-feature screenshots in hand, not piecemeal.

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
  - Classic API reference created: FrameXML sparse checkout for Classic Era (1.15.8) and Pandaria Classic (5.5.3). New `classic_api_differences` tool in wow-api MCP. Backlog BL-008.
  - Dispel overlay feature IMPLEMENTED and merged to main (feature/dispel-overlay branch):
    - Standalone Modules/DispelOverlay.lua — edge border + glow on raid frames when player can dispel
    - Reads frame.dispels PriorityTable (:Size() API) + LibDispel — zero secret values
    - Hooks CompactUnitFrame_UpdateAuras (timing confirmed in-game via /tridev)
    - 6 settings, Retail only, code review findings addressed
  - Triage_Dev companion addon created with dev/debug slash commands (/tridev)
  - GitHub issue templates added (bug report + feature request with Game Version field)
  - Announcement drafts written (CurseForge, Reddit, GitHub issues) — v2, rewritten for voice
  - LibDualSpec updated v1.27→v1.29, CallbackHandler and LibStub refreshed
  - Triage Backlog section created with TRI- prefix (TRI-001 boss frames, TRI-002 addon import)
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
  - Cherry-picked backlog docs from `Triage-Analysis-ERF-Issues` branch (build file regressions excluded).
  - Added 18 new backlog items (TRI-008 through TRI-025) from ERF open issues and competitor analysis.
  - Created 14 GitHub issues (#17-#31) to sync backlog with repo issues; created `quick-win` label.
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
  - **Comms items filed.** 17 organic CurseForge downloads since v1.0.0 with zero announcement push — filed TRI-030 (publish announcement, refresh Session 16-17 drafts) and TRI-031 (replace placeholder Soyier CF screenshots after TRI-003/004/007 Gate 2 passes). Both under a new `Release & Comms` Backlog subsection.
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
- **Pending (next session):**
  - **Gate 2 for v1.1.0 features** — run the per-PR in-game checks from Argus Gate 1 review: caster filter two-druid test, keep-indicators-visible toggle with `rangeAlpha`, countdown corner placement, 0.5% offset slider stepping, extended-range warning on DPS/tank spec, transform-spell hint renders in config panel.
  - **Gate 2 for v1.1.0 DB migration** — load a pre-v1.1.0 profile with `mineOnly = true/false` and confirm 2.2 → 2.3 migration rewrites to `casterFilter = "mine" / "all"` and drops the old key.
  - **Verify CurseForge v1.1.0 listing** — public changelog rendered correctly, all three client builds present.
  - Fresh in-game Retail verification of the merged TRI-003, TRI-004, and TRI-007 work.
  - Run click-casting spike A1-A5 in-game (Retail).
  - Run boss frame spike B1-B6 in-game (Retail).
  - Run click-casting spike A6-A7 on Classic Era.
  - Urgency glow data source investigation (Spike C).
  - In-game test dispel overlay on a dispel class.
  - **TRI-032** — Gate 1 (Argus) and in-game re-verify for the atlas neutral-fallback work on branch `tri-003-atlas-followup` (`2e73752`).
  - **TRI-029** — decide whether to rework or delete `UpdatePrivateAuraVisOverrides` (now confirmed dead on 12.0.5 via `/dump`).
  - **TRI-030** — refresh Session 16-17 announcement drafts against current state, then publish (CurseForge, Reddit, GitHub). v1.1.0 launch is a natural bundling moment.
  - **TRI-031** — swap placeholder Soyier CF screenshots after TRI-003/004/007 Gate 2 passes.
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

### TRI-033 Stock buff/debuff hide toggles stop hiding on Retail (Midnight)
- **Type:** Bug
- **Priority:** High
- **Status:** In Progress — local implementation passed Retail Gate 2, needs commit/PR
- **Source:** CurseForge comment on v1.1.0, 2026-04-23. Reporter explicitly names Midnight (Retail 12.0.5 confirmed by Rawb).
- **Symptom:** With `Show Standard Raid Frame Buff/Debuff Icons` disabled in the Triage General panel, Blizzard's default buff icons still appear on compact raid/party frames and render on top of Triage indicators.
- **Regression class:** 12.0.5 Blizzard compact-frame restructure (same class as TRI-028's `CompactUnitFrame_UpdatePrivateAuras` silent removal).
- **Root-cause finding (2026-04-23, primary source):** Confirmed via fresh `Gethe/wow-ui-source` extraction at `058ff8d` (12.0.5.67186). The entire compact-frame aura system was deleted and rebuilt. Gone: `frame.buffFrames` / `.debuffFrames` / `.dispelDebuffFrames` parentArrays; `CompactUnitFrame_UpdateAuras`; `CompactUnitFrame_UtilSetBuff`/`UtilSetDebuff`/`UtilSetDispelDebuff`. Replaced by `Blizzard_PrivateAurasUI` (pool-based rendering) plus new mixins (`BasePrivateAuraBehaviorMixin`, `ContainerPrivateAuraBehaviorMixin`) reading secure attributes `ignore-buffs` / `ignore-debuffs` / `ignore-dispel-debuffs`. Full platform-layer finding in `Triage_Dev/session/KNOWLEDGE.md` (2026-04-23, `[PROMOTE]`).
- **Direction picked — D'' (hooksecurefunc on `SetPrivateAuraAnchorSettings` + per-frame re-apply):** `SetAttribute` path, no `optionTable` writes (those taint — verified 2026-04-23 via `ForceTaint_Strong` LUA_ERROR at `CompactUnitFrame.lua:693`). `TriggerPrivateAuraSettingsUpdate` must also not be called from addon code (same taint class); use `SetAttribute("update-settings", true)` as the sanctioned refresh signal.
- **Gate 3 test results (2026-04-24):**
  - Q1 (does `SetAttribute` from `hooksecurefunc` callback taint?) — passed Gate 2 group-drop confirmation; no `CompactUnitFrame.lua:693` taint error.
  - Q2 (raid uses same mixin?) — passed Gate 2 in 6+ raid.
  - Q3 (does `Mixin()` run before Triage init on `/reload`?) — `false`. **Per-frame mixin reference was already copied;** mixin-table hook alone will not fire for existing frames. Implementation must hook each frame individually OR enumerate and write attributes directly.
- **Acceptance criteria:**
  1. On Retail 12.0.5, with `Show Standard Raid Frame Buff Icons` off, no Blizzard buff icon appears on any compact party/raid frame — verified in an actual grouped session with a player carrying a buff.
  2. Same for `Show Standard Raid Frame Debuff Icons` and `Show Standard Raid Frame Dispellable Icons`.
  3. Toggling any of the three flags at runtime honors the new value on the next aura update without a `/reload`.
  4. `luacheck .` clean.
  5. No new Lua errors on login, zone change, roster change, boss encounter, or **group drop** (the `oldR` taint regression — hard stop).
  6. Classic Era and Pandaria Classic: no regression (code is Retail-gated).
- **Scope guardrails:** Retail-only per Rawb. Out of scope: `UpdatePrivateAuraVisOverrides` (TRI-029), per-aura blacklist (TRI-016), any refactor of the stock-aura hide loop.
- **Codex implementation in flight (2026-04-24):** Local `Overrides.lua` implementation uses per-frame `hooksecurefunc(frame, "SetPrivateAuraAnchorSettings", ...)`, direct `ignore-*` attributes, `update-settings` refresh signaling, `PLAYER_ENTERING_WORLD` catch-up, and `PLAYER_REGEN_ENABLED` deferred re-apply. `luacheck` clean for shipped addon files. Rawb Gate 2 passed in party through group-drop taint check and passed 6+ raid confirmation.
- **Open actions:**
  1. Codex: commit the D''-revised implementation on the target branch and open PR/branch review.
  2. Rawb: Classic/Pandaria smoke if required before release.
  3. Everett / Rawb: file GH issue when fix lands (still held pending).
- **Branch target:** `.worktrees/tri-033-stock-aura-hide-retail` on branch `tri-033-stock-aura-hide-retail`.
- **Notes:** Distinct from TRI-016 (per-aura blacklist feature).

## Awaiting Gate 2

### TRI-003 Colored dispel glow — debuff-type-colored glow animation
- **Type:** Feature
- **Priority:** High
- **Status:** Merged to main, pending in-game verification
- **Summary:** Current dispel overlay "both" mode shows colored edge border + standard yellow glow. The yellow glow is visually dominant and hides the debuff-type color. Replace with a colored glow that matches the debuff type (blue pulse for Magic, purple for Curse, green for Poison, etc). LibCustomGlow-1.0 supports colored glows via `PixelGlow_Start`, `AutoCastGlow_Start`, and `ButtonGlow_Start` — all accept a color parameter. Cell and HealBot both embed it.
- **Source:** In-game testing feedback — glow overwhelms border color.
- **Session progress (2026-04-07):** `LibCustomGlow-1.0` vendored and wired into packaging/load order on worktree branch `tri-003-colored-dispel-glow` (`ccc2fbf`). Integration into `Modules/DispelOverlay.lua` and in-game validation still pending.
- **Session progress (2026-04-09/11):** Current mainline history is linearized. TRI-003 is on `main` as `53807f4` (`build: vendor LibCustomGlow for colored dispel glow`) and `edb877d` (`feat: integrate colored ButtonGlow into dispel overlay`). Argus QA passed on the vendoring work. Worktree `tri-003-colored-dispel-glow` still exists but is stale.
- **Next step:** In-game verification on a dispel-capable class.

### TRI-004 Managed frame registry for raid/party/boss frames
- **Type:** Refactor / Infrastructure
- **Priority:** High
- **Status:** Merged to main, pending in-game verification
- **Summary:** Replace direct Blizzard compact-frame iteration with a central managed-frame registry that tracks frame add/remove/unit-change lifecycle. All modules should query the registry instead of iterating Blizzard raid/party frames directly. This unblocks boss-frame support and future click-casting registration.
- **Source:** GitHub issue #4.
- **Session progress (2026-04-07):** Implemented on worktree branch `tri-004-frame-registry` with two local commits: `445d6ff` (`refactor: add managed frame registry`) and `5b51eea` (`fix: support boss units and unnamed managed frames`).
- **Scope landed on main:** New `Utils/FrameRegistry.lua`; registry-backed iteration and unit lookup across aura listeners, aura indicators, target markers, dispel overlay, range, and stock-aura passes; lifecycle sync from startup, roster changes, and `CompactUnitFrame_SetUnit`; widened default registry support for `boss1..boss5`; unnamed-frame-safe child creation for future addon-owned frames.
- **Verification:** Argus Gate 1 passed. Current mainline history is linearized; TRI-004 is on `main` as `7eb36f0` (`refactor: add managed frame registry`) and `0588c57` (`fix: support boss units and unnamed managed frames`). Worktree `tri-004-frame-registry` still exists but is stale.
- **Next step:** In-game Retail verification.

### TRI-007 Test mode — preview frames without a group
- **Type:** Feature
- **Priority:** High
- **Status:** Merged to main, pending in-game verification
- **Summary:** Preview raid frames without being in a group. Simulated party/raid frames with class colors, health states, aura indicators, power bars, healing-on-click, tooltips. GitHub issue #13.
- **Implementation:** Current mainline history is linearized. TRI-007 is on `main` as `24248dd`, `ff31723`, `185c6a5`, `c93b4a3`, `886cc61`, `9e75dfa`, and `dbc1a66`. Preview frames are addon-owned and movable, integrate the existing rendering modules through preview-aware adapters, and simulate healing locally.
- **Gate 1:** Passed. Current mainline hardening commit is `9e75dfa` (earlier branch SHA `f9fc418` is stale after rebase).
- **Gate 2:** Visual, interaction, and movability fixes landed in `dbc1a66`. Earlier backlog notes that still describe Gate 2 Bug 1 as open are stale.
- **Next step:** Fresh in-game Retail verification of the merged preview frames.

## Awaiting Release

*(None — v1.1.0 released 2026-04-23.)*
