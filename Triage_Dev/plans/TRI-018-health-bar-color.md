# TRI-018 — Health bar color by health percentage

**GitHub issue:** [#24](https://github.com/Royaleint/Triage/issues/24)
**Backlog ID:** TRI-018
**Type:** Feature
**Priority:** Medium

---

## Revision note — additive-first lens

After completing the Blizzard frame audit
(`Triage_Dev/research/blizzard-frame-audit.md`), the plan below was
rewritten under a new product principle: **prefer adding what Blizzard
doesn't do over replacing what Blizzard does well.**

For this ticket specifically, the audit confirms:

- **HP % gradient, flat custom color, role tint** — ❌ native on all
  three clients. **Genuinely additive.** Keep.
- **Class colors** — ✅ native everywhere via Edit Mode. Still worth
  providing as a Triage mode because it gives users per-profile control
  independent of their Edit Mode raid profile, but framed as "explicit
  override" rather than "feature we invented."
- **Heal prediction (my + others)** — ✅ native on MoP + Retail, ❌ on
  Classic Era. Our phase-2 blend **augments** the native bar on MoP /
  Retail; it fills a gap on Classic Era.
- **Absorb shields** — ✅ native on MoP + Retail (Blizzard renders
  `frame.totalAbsorbBar`), ❌ on Classic Era. Phase 3 is
  **re-scoped**: on MoP + Retail, theme Blizzard's native bar; on
  Classic Era only, build our own overlay.

This shifts phase 3 from "build an absorb overlay" to "make the
existing Blizzard overlay themeable, and backfill it on Classic Era."
Smaller scope, lower risk, better positioning copy.

---

## Scope & phasing

| Phase | Scope | New code | DB keys | Risk |
|---|---|---|---|---|
| **1. Core HP-gradient** | Off / Flat / Class / Stepped / Gradient modes | ~200 LoC | 8 | Low |
| **2. Heal-prediction blend** | Green tint when incoming heals are queued | ~40 LoC | 2 | Low |
| **3. Absorb overlay** | Theme Blizzard's bar on MoP / Retail; build on Classic Era | ~80 LoC | 3 | Medium — Classic Era fallback only |

All three phases ship in one PR, structured as three commits so review
and revert stay granular. If phase 3 can't be done cleanly in
≤ ~100 LoC (e.g. Classic Era fallback grows unexpectedly), revert the
phase-3 commit and ship phases 1 + 2 alone; reopen phase 3 as a new
issue.

---

## Phase 1 — Core HP-gradient

### File changes

1. **New** `Modules/HealthColor.lua` (~200 LoC) — hook + color dispatch.
2. `Triage.toc` — wire new file after `Modules/AuraIndicators.lua`,
   before `Modules/TargetMarkers.lua`.
3. `DatabaseDefaults.lua` — new profile block.
4. `GUI/GeneralConfigPanel.lua` — new options section.
5. `EnhancedRaidFrames.lua` — one call into `Modules/HealthColor.lua`
   during initialization.
6. `Localizations/enUS.lua` — ~12 new strings.
7. `Utils/TestModeFrames.lua` — ensure `frame.ERF_healthBar` gets colored
   the same way (one extra call in the test-mode color path).

### DB schema (new profile section)

```lua
healthColor = {
    mode = "off",           -- "off" | "flat" | "class" | "stepped" | "gradient"
    flatColor = { 0, 1, 0, 1 },      -- used when mode = "flat"
    gradientHigh = { 0, 1, 0, 1 },   -- green at 100%
    gradientMid  = { 1, 1, 0, 1 },   -- yellow at midpoint
    gradientLow  = { 1, 0, 0, 1 },   -- red at 0%
    midpoint = 0.5,                  -- where yellow sits on the gradient
    steppedHigh = 0.75,              -- >= this = high color
    steppedLow  = 0.25,              -- <= this = low color
},
```

All defaults reproduce current behavior (`mode = "off"` means Blizzard's
own logic runs untouched). **No migration required** — new key with a
safe default; AceDB's defaults merge handles old profiles automatically.

### Core algorithm

```
function HealthColor:Apply(frame)
    if not ShouldContinue(frame) then return end

    local mode = db.profile.healthColor.mode
    if mode == "off" then return end  -- let Blizzard's default stand

    -- Higher-priority override (#16, future): debuff coloring wins
    if self.DebuffColorActive(frame) then return end

    local unit = GetManagedFrameUnit(frame)
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)

    -- Secret Value guard (Midnight boss encounters)
    if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then return end
    if not max or max == 0 then return end

    local pct = cur / max
    local r, g, b

    if mode == "flat" then
        r, g, b = unpack(db.profile.healthColor.flatColor)
    elseif mode == "class" then
        r, g, b = GetClassColor(unit)
    elseif mode == "stepped" then
        r, g, b = StepColor(pct, db.profile.healthColor)
    elseif mode == "gradient" then
        r, g, b = GradientColor(pct, db.profile.healthColor)
    end

    if frame.healthBar and r then
        frame.healthBar:SetStatusBarColor(r, g, b)
    end
end
```

- **`GradientColor(pct, cfg)`** — two-segment lerp: high → mid from
  1.0 to `cfg.midpoint`, mid → low from `cfg.midpoint` to 0.0. Not
  tri-color one-pass blend because the issue explicitly calls out
  green → yellow → red as three distinct color stops.
- **`StepColor(pct, cfg)`** — `pct >= cfg.steppedHigh` → gradientHigh,
  `pct <= cfg.steppedLow` → gradientLow, else gradientMid.
- **`GetClassColor(unit)`** — standard `RAID_CLASS_COLORS[class]` with
  `CUSTOM_CLASS_COLORS` fallback (Classic-safe community convention).

### Hooking

Add to the existing init block in `EnhancedRaidFrames.lua` near
line 126:

```lua
if CompactUnitFrame_UpdateHealthColor then
    self:SecureHook("CompactUnitFrame_UpdateHealthColor", function(frame)
        self:ApplyHealthColor(frame)
    end)
end
```

`SecureHook` runs after Blizzard, so we win the visible color. Pattern
matches the existing `UpdateInRange`, `UpdateCenterStatusIcon`,
`UpdateAuras` hooks.

Piggyback updates on:
- `UNIT_HEALTH` (already fires Blizzard's path).
- `GROUP_ROSTER_UPDATE` (already handled; Blizzard re-calls
  `UpdateHealthColor`).
- `RefreshConfig` — already iterates managed frames
  (`EnhancedRaidFrames.lua:273`); add one `ApplyHealthColor(frame)` call.

### GUI layout

New section header "Health Bar Color" between `Out-of-Range` (order 40)
and `Dispel Overlay` (order 50). Order range 45–49:

```
[Health Bar Color]
  Mode (dropdown): Off / Flat Color / Class Colors (forced) / Stepped / Gradient

  # conditional show/hide by mode
  (flat)     Flat Color picker
  (stepped)  High Threshold range 0.5-1.0 step 0.01
             Low Threshold range 0.0-0.5 step 0.01
             High / Mid / Low color pickers
  (gradient) Midpoint range 0.1-0.9 step 0.01
             High (100%) / Mid / Low (0%) color pickers
```

Use AceConfig `hidden` / `disabled` functions per mode.

### Cross-client

- `CompactUnitFrame_UpdateHealthColor` exists on all three clients.
- `RAID_CLASS_COLORS` exists on all three clients.
- **No client gating required.**

### Test plan

- Each mode renders correctly on test-mode frames at various HP%
  (`/triage test 40`, simulate damage).
- `mode = "off"` reproduces Blizzard's exact default.
- Mode change mid-combat repaints without `/reload`.
- Boss encounter with Secret-Value health: bar retains Blizzard default
  color, no error thrown.
- Profile export / import round-trips the new `healthColor` table.

---

## Phase 2 — Heal-prediction blend

### Goal

Tint the health bar color slightly toward green when significant
incoming heals are queued. Signals "this player is already being taken
care of, deprioritize."

**Audit framing:** on MoP / Retail, Blizzard already renders a heal
prediction bar. Our tint is **additive** on top — Blizzard shows how
much is inbound; we shift the bar color to reflect "this target is being
covered" so the healer's peripheral vision picks it up without reading
the prediction bar. On Classic Era, Blizzard doesn't render heal
prediction at all, so our tint substitutes a minimal alternative.

### File changes

1. `Modules/HealthColor.lua` — ~40 LoC addition inside `Apply`.
2. `DatabaseDefaults.lua` — 2 new keys.
3. `GUI/GeneralConfigPanel.lua` — toggle + weight slider.
4. `Localizations/enUS.lua` — ~4 new strings.

### DB additions

```lua
healthColor = {
    ...
    healPredictionBlend = false,    -- boolean
    healPredictionWeight = 0.5,     -- 0.0 (no effect) to 1.0 (full green override)
}
```

### Algorithm

After computing `r, g, b` in phase 1:

```lua
if cfg.healPredictionBlend then
    local incoming = UnitGetIncomingHeals(unit) or 0
    if issecretvalue and issecretvalue(incoming) then
        incoming = 0
    end
    if max > 0 then
        local incomingPct = math.min(incoming / max, 1.0)
        local blend = incomingPct * cfg.healPredictionWeight
        r = r * (1 - blend) + 0 * blend
        g = g * (1 - blend) + 1 * blend
        b = b * (1 - blend) + 0 * blend
    end
end
```

### Cross-client

`UnitGetIncomingHeals` is present on all three clients (standard since
WotLK). No gating.

### Test plan (additive)

- Cast a HoT on a raid member; bar tints greener while HoT is pending.
- With blend disabled, behavior identical to phase 1.
- Incoming heals larger than max HP: clamped to 100% blend, no visual
  weirdness.

---

## Phase 3 — Absorb overlay (re-scoped)

### Audit-revised goal

| Client | Native absorb rendering | Phase 3 job |
|---|---|---|
| Retail 12.0 | ✅ `frame.totalAbsorbBar` | **Theme** the existing Blizzard bar (color, alpha). Do not rebuild. |
| Pandaria Classic 5.5 | ✅ `frame.totalAbsorbBar` | Same — theme only. |
| Classic Era 1.15 | ❌ (absorbs added Cataclysm; Classic Era lacks the feature) | **Backfill** with a simple `ERF_absorbOverlay` StatusBar. |

### File changes

1. `Modules/HealthColor.lua` — new `ApplyAbsorbOverlay(frame)`.
2. Hook `CompactUnitFrame_UpdateHealthPrediction` on clients that have
   it (MoP + Retail). Classic Era uses our own `UNIT_ABSORB_AMOUNT_CHANGED`
   event — **check API availability first**; Classic Era may lack both
   the event and `UnitGetTotalAbsorbs`. If so, hide phase 3 on Classic
   Era entirely and document the limitation.
3. `DatabaseDefaults.lua` — 3 new keys.
4. `GUI/GeneralConfigPanel.lua` — one toggle + color picker + alpha
   slider.
5. `Localizations/enUS.lua` — ~5 new strings.

### DB additions

```lua
healthColor = {
    ...
    showAbsorbOverlay = false,
    absorbColor = { 0.8, 0.8, 1.0, 1 },  -- pale blue, WoW convention
    absorbAlpha = 0.6,
}
```

### Algorithm (MoP / Retail branch — theme existing bar)

```lua
function HealthColor:ThemeAbsorbBar(frame)
    if not cfg.showAbsorbOverlay then return end
    if not frame.totalAbsorbBar then return end
    frame.totalAbsorbBar:SetStatusBarColor(unpack(cfg.absorbColor))
    frame.totalAbsorbBar:SetAlpha(cfg.absorbAlpha)
end
```

### Algorithm (Classic Era branch — backfill)

Create `frame.ERF_absorbOverlay` as a child StatusBar anchored to the
right edge of `frame.healthBar`'s current fill. Width proportional to
`absorbs / max`. Update on `UNIT_HEALTH` alongside the color hook. Skip
entirely if `UnitGetTotalAbsorbs` doesn't exist on this client.

### Secret Value handling

Same pattern as phase 1 — guard `UnitGetTotalAbsorbs` and
`UnitHealthMax` with `issecretvalue`, skip silently on taint.

### Cross-client

- Retail 12.0: `frame.totalAbsorbBar` + `UnitGetTotalAbsorbs`. ✅
- MoP Classic 5.5: `frame.totalAbsorbBar` exists (added Cata),
  `UnitGetTotalAbsorbs` available. ✅
- Classic Era 1.15: neither exists — absorbs mechanic predates the
  feature. Gate the GUI toggle and skip the code path.

### Risk

Touching bar geometry is more fragile than color. **Pre-agreed cutoff:**
if the Classic Era backfill branches into more than a small,
self-contained overlay (i.e. > ~80 LoC or requires new XML), split
phase 3 off to a new issue and ship only the MoP / Retail theming.

### Test plan (additive)

- Priest with Power Word: Shield casts on a raid member; absorb overlay
  renders in the configured color and alpha.
- Multiple absorbs stack; overlay extends correctly.
- Absorb expiration: overlay disappears when absorbs hit 0.
- Classic Era: feature gracefully disabled (GUI toggle hidden), no error.
- MoP / Retail: Blizzard's native bar adopts the themed color; disabling
  the toggle reverts to Blizzard's default.

---

## Dependencies & coordination

- **#16 (debuff-type frame coloring)** — not built. Phase 1's
  `DebuffColorActive(frame)` hook point is stubbed to `false` until #16
  lands; when #16 ships, it calls into a small coordination function
  phase 1 provides.
- **#41 (Triage Focus)** — orthogonal. Focus sets a *border* glow;
  health-color sets the *bar fill*. No visual conflict.
- **#27 (range dimming)** — orthogonal. Dimming is alpha, color is RGB.
  Stack cleanly.

---

## Branch / PR

- **Branch:** `claude/issue-24-health-color` from `origin/main`.
- **Commits:**
  1. `feat(healthcolor): core health-bar color modes (off/flat/class/stepped/gradient)` — phase 1
  2. `feat(healthcolor): blend toward green for incoming heals` — phase 2
  3. `feat(healthcolor): absorb overlay on raid frames (theme + classic backfill)` — phase 3
- Single PR. If phase 3 hits the cutoff, revert that commit and ship 1+2.

---

## Effort estimate

- Phase 1: ~1 day focused.
- Phase 2: ~2 hours.
- Phase 3: ~2 hours if MoP/Retail theming only; ~1 day if Classic Era
  backfill is in-scope and works cleanly.
- **Total: 1.5–2.5 days.**

---

## Open questions

1. Should `"class"` mode be labeled **"Class Colors (forced)"** in the
   UI so users understand it overrides Blizzard's class-color toggle?
   *Recommended: yes, clearer for bug reports.*
2. For gradient mode, should `midpoint` default to 0.5 or 0.6 (bar
   visibly shifts yellow before half)? *Recommended: 0.5, add a tooltip
   example.*
3. Phase 3 on Classic Era: audit `UnitGetTotalAbsorbs` availability
   during implementation, not upfront. Worst case is a clean
   client-gate and a follow-up issue.

---

## Acceptance criteria

1. With `mode = off`, raid frames are visually identical to a Triage
   build without this module — Blizzard's own health-color behavior
   stands untouched.
2. Each of the four active modes (flat / class / stepped / gradient)
   renders the expected color on a test-mode frame at a representative
   HP% sample (100 / 75 / 50 / 25 / 10 / 1%).
3. Mode change via GUI repaints all existing managed frames without
   requiring `/reload`.
4. No taint: pressing a secure click-cast button on a frame after
   toggling modes repeatedly does not produce lua errors or secure-call
   blocks.
5. On at least one Midnight boss encounter with Secret-Value health,
   the feature degrades silently to Blizzard's default color — no
   errors, no visible stuck-at-red or stuck-at-green bar.
6. Phase 2: heal-prediction blend visibly greens a bar when a HoT or
   slow heal is pending to land; blend disappears when the heal lands.
7. Phase 3: absorb overlay visible when a raid member has an absorb
   shield; color / alpha respect the user's config.
