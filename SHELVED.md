# Triage — Shelved (Maintenance Mode)

**Decision date:** 2026-05-24
**Status:** Maintenance mode — installable, patch-compatible, critical-fix-only. No active development.

## Decision

Triage is moving to maintenance mode. It stays installable and compatible with
game patches, and critical breakage will be fixed. Active feature development has
ended. This is a deliberate strategic call, not abandonment, and the decision not
to continue active development is final.

## Rationale

The retail raid-frame / healing space is dominated by Danders Frames (3M+
downloads), and there is no realistic differentiation path that justifies
continued investment. Triage's one structural differentiator is Classic Era / TBC
Classic / Pandaria Classic support — a lane we do not want to maintain actively.

The original decision to fork Enhanced Raid Frames rather than build clean created
an architectural ceiling. The features that would have set Triage apart —
addon-owned boss frames, built-in click-casting, health-bar coloring — all run
into Midnight's secret-value taint when layered on Blizzard's compact-frame
internals (see the TRI-001 and TRI-005 findings in the dev tracker). Getting past
that ceiling means a near-total rebuild, and the payoff does not justify the cost
against a 3M-download incumbent.

Active development bandwidth belongs to Homestead and BawrSpam.

Triage was not a loss. It proved the BawrLabs pipeline end to end — research,
fork, four-client releases, CurseForge/Wago publishing, and in-game gate
verification — and it preserves working Classic-family raid-frame enhancement for
users the incumbents underserve.

## What maintenance mode covers

- Keeping the addon installable and loading cleanly.
- Compatibility fixes when a game patch breaks it.
- Critical bug fixes — errors on load, broken core functionality after a patch.

## What it does not cover

- New features. The queued TRI- roadmap (boss frames, click-casting, auto-layout
  switching, priority chains, raid debuffs, raid tools, the healing intelligence
  layer, and the rest) is shelved.
- Non-critical polish, UX work, or cosmetic bugs.
- Active competitive positioning or marketing.

## Context: the Danders comparison

Danders Frames is the dominant Midnight-native raid-frame / healing addon (3M+
downloads). It ships fully custom frames (replace, not enhance), auto-switching
layouts, built-in click-casting, a visual aura designer, and curated per-spec
aura lists, on a fast solo-dev release cadence.

Triage's "enhance Blizzard frames" approach is architecturally cleaner in
principle but capped by what Blizzard's compact frames let an addon do under
Midnight taint rules. Against an incumbent that size with that feature surface,
"a better-behaved overlay" is not a wedge that wins users. Recorded here so the
comparison does not have to be re-derived if Triage is ever reconsidered.

## Lesson for BawrLabs: fork vs clean build

Forking ERF got us to a shipping multi-client product fast, and that was the
right call for proving the pipeline. The cost showed up later: inheriting
Blizzard's compact-frame coupling meant the differentiating features kept hitting
secret-value taint that a clean, addon-owned-frame architecture would have
avoided from the start.

The lesson is not "never fork." It is this: a fork inherits the original's
architectural ceiling. Before forking to ship fast, decide whether the features
you actually want to build live above or below that ceiling. If the wedge
features need an architecture the fork cannot reach, the fork buys speed now and
a rebuild later — weigh that explicitly at the fork-vs-build decision, not after
the ceiling is hit.

## Reactivation criteria

Triage returns to active development only if something material changes.
Concretely, any of:

- **The taint ceiling lifts.** Blizzard relaxes the compact-frame taint
  constraints so the "enhance, don't replace" approach can deliver boss frames,
  click-casting, or health coloring without a rebuild.
- **The incumbent vacates the lane.** Danders Frames is abandoned or breaks badly
  enough that the Classic-family + Blizzard-frame niche becomes a real,
  defensible space again.
- **A funded strategic reason appears.** Studio strategy shifts to a deliberate
  reason to own a raid-frame product.
- **Sustained Classic-family demand.** Real, ongoing user demand on the
  Classic-family side that the incumbents do not serve.

Absent one of those, Triage stays in maintenance mode.

---

Triage is a fork of [Enhanced Raid Frames](https://github.com/brittyazel/EnhancedRaidFrames)
by Britt W. Yazel (Soyier), used under the MIT license. That attribution and
license stand unchanged.
