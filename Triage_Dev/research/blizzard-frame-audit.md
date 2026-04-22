# Blizzard Raid / Party / Group Frame Capability Audit

**Scope:** WoW Classic Era 1.15.x, Pandaria Classic (MoP) 5.5.x,
Retail / Midnight 12.0.5 (as of 2026-04-22).
**Purpose:** Strategic input for Triage's product direction — shift
from "replace/override Blizzard's frame features" to "add functionality
Blizzard doesn't already offer."

Legend: ✅ native · ⚠️ native with caveats · ❌ not native · N/A

---

## Bottom-line summary

Blizzard's compact raid frames cover the common case well on all three
clients — class color, heal prediction, absorb shields, dispel
highlight, range fade, role / ready / rez / leader icons, and
sort-by-group / role. On Retail these are almost all toggleable in
Edit Mode per 10 / 25 / 40 profile.

The real gaps are:
1. **Rich aura tracking** beyond 3 stock buffs / 3 debuffs with no
   positioning, stacks, or duration text.
2. **Fine-grained per-aura indicators** like Grid / VuhDo offered.
3. A worsening **visibility problem in Midnight** where many dispellable
   mechanics are Private Auras / Secret Values, so the frame shows
   *something is wrong* but addons can no longer drive decisions from it.

Classic Era and MoP Classic lag Retail: no Private Aura pipeline,
thinner Edit Mode, fewer role / dispel options.

**Strategic takeaway:** stop reinventing anything Edit Mode already
does well. Invest in the aura-indicator grid, custom range / utility
overlays, and the narrow "surface without decoding" pattern that Secret
Values now force.

---

## Feature matrix

### Health bar display

| Feature | Classic 1.15 | MoP 5.5 | Retail 12.0 | Toggle location | Addon strategy |
|---|---|---|---|---|---|
| Class colors | ✅ | ✅ | ✅ | Edit Mode → Frames → Use Class Colors | Augment (recolor) |
| HP % gradient | ❌ | ❌ | ❌ | — | Replace / overlay |
| Flat custom color | ❌ | ❌ | ❌ | — | Overlay |
| Role-based tint | ❌ | ❌ | ❌ | — | Overlay |
| Aggro / threat color | ❌ | ❌ | ❌ | — | Overlay via `UnitThreatSituation` |
| Status (charm / OOM / offline / dead) | ⚠️ offline + dead text only | ⚠️ same | ⚠️ same | Status Text dropdown | Augment |

### Predictive healing

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| My-heal prediction | ❌ | ✅ | ✅ | Retail: Edit Mode "Display Heal Prediction" |
| Others-heal prediction | ❌ | ✅ | ✅ | Same toggle |
| Overflow / overheal viz | ❌ | ❌ | ❌ | Addon territory |
| HoT duration / stack | ❌ | ❌ | ❌ | Stock shows icon only, 3-max |
| Absorb shields overlay | ❌ | ✅ | ✅ | Retail toggle "Display Absorbs"; texture revamped in 12.0 |
| Healing absorb (Brittle etc.) | ❌ | ⚠️ | ✅ | New Midnight texture on Retail; not surfaced on Classic clients |

### Debuffs / dispels

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Dispellable highlight (colored border) | ⚠️ basic | ✅ | ✅ | Retail: "Display Only Dispellable Debuffs" + "Dispellable By Me" |
| Debuff-type coloring | ✅ border | ✅ | ✅ | Magic / Curse / Disease / Poison; Bleed only via addons |
| Boss debuff prominence | ❌ | ⚠️ | ✅ | "Big Defensive" icon + size slider added 12.0.5 |
| Private auras | N/A | N/A | ⚠️ | Retail-only. Blizzard draws them; addons cannot read values (Secret Values). Major dispel-visibility complaint in S1 |

### Buff display

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Stock buff icons | ⚠️ 3 max | ⚠️ 3 max | ⚠️ 3 max, filtered | Hard cap; no size / position control |
| Consolidated buffs | ❌ (removed pre-7.0) | ⚠️ legacy | ❌ | — |
| Long-duration suppression | ❌ | ❌ | ⚠️ filter list is hardcoded | Not user-editable |

### Utility / layout

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Current-target highlight | ✅ | ✅ | ✅ | Thin border, not configurable |
| Role icons | ⚠️ | ✅ | ✅ | Edit Mode toggle on Retail |
| Raid marker icons (skull / star / …) | ❌ on frame | ❌ | ❌ | World-only; addons must overlay |
| Ready-check icons | ✅ | ✅ | ✅ | — |
| Resurrection pending | ✅ | ✅ | ✅ | — |
| Phasing / summoning | ⚠️ summoning only | ✅ | ✅ | — |
| Leader / assist markers | ✅ crown | ✅ | ✅ | — |
| Power bars | ⚠️ mana only | ✅ | ✅ | "Display Power Bar" toggle |
| Pet frames | ❌ in raid | ❌ | ⚠️ party only | Not available in raid layout |
| Range fade (40yd) | ✅ | ✅ | ✅ | Fixed 40yd alpha dim |
| Custom-range out-of-range | ❌ | ❌ | ❌ | Addon territory (spell-range APIs) |

### Sorting / grouping

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Sort by group | ✅ | ✅ | ✅ | — |
| Sort by role | ⚠️ | ✅ | ✅ | `raidOptionSortMode` CVar |
| Sort by name / class | ⚠️ CVar only | ✅ | ✅ | No Edit Mode UI on Classic |
| 5 / 10 / 25 / 40 layouts | ⚠️ combined / separate only | ✅ | ⚠️ reduced to 10 / 25 / 40 profiles post-Edit-Mode |
| Separate tanks frame | ❌ | ❌ | ❌ | Must re-declare MT / MA as addon |
| Main tank / main assist frames | ✅ `/mt` `/ma` | ✅ | ✅ | Visible if role promoted; limited styling |

### Layout / positioning

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Edit Mode draggability | ⚠️ (added in TBC Anniv, limited) | ✅ | ✅ | Shift-click-to-enable shortcut added 12.0.5 |
| Per-profile raid profiles | ⚠️ 3 sizes only | ⚠️ 3 sizes | ⚠️ 3 sizes | Pre-Edit-Mode allowed unlimited |
| Custom unit frame templates | ❌ | ❌ | ❌ | `CompactUnitFrameTemplate` is fixed |
| Boss frames integration | N/A | ✅ | ✅ | Separate Edit Mode module |
| Arena frames integration | N/A | ✅ | ✅ | Separate Edit Mode module; size slider added 12.0.5 |

### Click-casting

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Native click-bind (`C_ClickBindings`) | ❌ | ✅ | ✅ | LMB / RMB / MMB / B4 / B5 only |
| Click-through / propagation | ❌ explicit | ❌ | ❌ | Not exposed |
| Mouseover macro integration | ✅ (macros) | ✅ | ✅ | Works; not frame-aware |

### Other

| Feature | Classic | MoP | Retail | Notes |
|---|---|---|---|---|
| Name show / hide / position | ⚠️ on / off | ✅ | ✅ | Position not configurable |
| Level display | ❌ | ❌ | ❌ | — |
| Cross-realm realm name | ✅ appended | ✅ | ✅ | — |
| Group number display | ❌ on frame | ❌ | ❌ | Header only |
| Vehicle / mount swap | N/A | ✅ | ✅ | Auto via `UnitHasVehicleUI` |

---

## Midnight-specific degradations (vs 11.x)

- **Private Auras expanded:** most Season 1 raid and dungeon debuffs are
  flagged private. Addons get a handle but no spellID / duration / stacks.
- **Secret Values on combat-sensitive fields:** boss `UnitHealth` /
  `UnitHealthMax` and select aura fields return black-box values unusable
  for conditionals; still safe for cosmetic display via the
  restricted-aware APIs.
- **CLEU removal in restricted contexts:** `COMBAT_LOG_EVENT_UNFILTERED`
  neutered for decision-making; breaks addon-driven debuff tracking built
  pre-12.0.
- **Click-cast keys capped** at LMB / RMB / MMB / B4 / B5 since
  Dragonflight; unchanged in Midnight but still a live constraint.
- **Raid profile count reduced** when Edit Mode shipped to Classic
  clients: 10 / 25 / 40 only, no per-encounter profiles.
- **Size-slider scripts broken** by the Dragonflight-options port into
  Classic (`CompactUnitFrameProfilesGeneralOptionsFrameHeightSlider:
  SetMinMaxValues` no longer works on Classic Era the old way).

---

## Strategic gaps for Triage (prioritized)

### High — genuinely additive, minimal overlap

1. **9-position aura indicator grid** — Blizzard's 3-buff / 3-debuff
   stock is the single biggest gap on all three clients. Triage's
   flagship feature; keep investing.
2. **Custom-range out-of-range fade** — Blizzard only does 40yd; healers
   need per-spell (30 / 25 / 15) alpha tiers. Viable on all three clients.
3. **Target-marker overlay on the frame** — Blizzard does not render
   world icons on raid frames; universally missing. Already in Triage
   as `Modules/TargetMarkers.lua`.
4. **Private-Aura-aware dispel indicator (Retail Midnight)** — surface
   "this unit has a dispellable private aura" without decoding it. Uses
   the new restricted-aura APIs; high value given S1 pain and Blizzard's
   stated willingness to expose structured info.
5. **Healing-absorb and overheal visualization** on Classic / MoP, which
   lack the Retail texture entirely.

### Medium — useful but partially covered

6. HoT duration / stack text on indicator slots (not in stock frames).
7. Per-role / per-spec tinting overlay on the health bar.
8. Raid-frame-based "aggro pulse" using `UnitThreatSituation` (stock
   shows nothing frame-side).
9. Frame-scale and density controls beyond Edit Mode's coarse slider,
   especially for Classic where Edit Mode is thinner.
10. Boss-debuff size / position override for Classic / MoP (Retail got
    the 12.0.5 slider; older clients did not).

### Low — skip or deprioritize (Blizzard does this acceptably)

- Class colors, basic heal prediction, absorbs, dispel-border, role
  icons, ready check, rez icons, leader / assist, native click-binds,
  base sort-by-group / role, 40yd range fade, vehicle swap.
- Do *not* rebuild Edit Mode positioning or click-cast binding; stay
  additive on both.

---

## Sources

- [Wowhead – UI Hub for WoW Midnight (Edit Mode, raid frames)](https://www.wowhead.com/guide/ui/user-interface-hub-raidframes-damage-meter-timelines-edit-mode)
- [Blizzard forums – Development clarification: Secret Value obfuscation in Midnight](https://us.forums.blizzard.com/en/wow/t/development-clarification-maintaining-ui-accuracy-vs-secret-value-obfuscation-in-midnight/2243547)
- [Warcraft Wiki – Patch 12.0.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [Warcraft Wiki – Patch 12.0.0 Planned API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes)
- [Warcraft Wiki – Edit Mode](https://warcraft.wiki.gg/wiki/Edit_Mode)
- [Cell PR #457 – WoW 12.0 Midnight compatibility (Secret Values, CLEU removal)](https://github.com/enderneko/Cell/pull/457)
- [Wowhead – Blizzard explains why most debuffs are Private Auras in Midnight S1](https://www.wowhead.com/news/blizzard-explains-why-most-debuffs-are-private-auras-in-midnight-season-1-380762)
- [Wowhead – Healers struggling with dispel visibility due to Private Auras (Voidspire / Dreamrift)](https://www.wowhead.com/news/healers-struggling-with-dispel-visibility-due-to-private-auras-in-voidspire-and-380867)
- [Wowhead – New Healing Absorb Texture on Midnight Beta](https://www.wowhead.com/news/new-healing-absorb-texture-on-midnight-beta-many-default-raid-frame-texture-379517)
- [tomrus88/BlizzardInterfaceCode – CompactRaidFrameContainer & CUFProfiles](https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_CompactRaidFrames/Blizzard_CompactRaidFrameContainer.lua)
- [Wowpedia – CVar raidOptionSortMode](https://wowpedia.fandom.com/wiki/CVar_raidOptionSortMode)

---

## Unverified items

Flagged as not authoritatively confirmed via available sources; revisit
before committing code that relies on these specific facts:

- Exact Edit Mode checkbox labels on MoP Classic 5.5.x (labels inferred
  from Retail parity + RaidFrameSettings / ERF option names).
- Whether `C_ClickBindings` is fully wired on MoP Classic 5.5.x as on
  Retail (widely reported yes, but not directly confirmed in a Blizzard
  source).
- Whether the 12.0.5 "Big Defensive" size slider was backported to
  Classic clients — no evidence it was; treat as Retail-only.
