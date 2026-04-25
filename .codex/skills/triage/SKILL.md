---
name: triage
description: >
  Triage project skill for Codex. Use for Triage addon work involving
  EnhancedRaidFrames internals, multi-client Retail / Pandaria Classic /
  Classic Era behavior, C_Secrets-safe aura handling, compact raid frame
  overrides, frame registry work, test mode, release checks, or tracker
  maintenance.
---

# Triage Project Skill

Use with the BawrLabs `wow-addon-dev` platform skill for Triage-specific
rules. `AGENTS.md` remains the authority; this skill is the operational
memory Codex should load when doing Triage work.

## Identity

- User-facing addon name: `Triage`.
- Internal addon table/global: `EnhancedRaidFrames`.
- SavedVariables key: `EnhancedRaidFramesDB`.
- Framework: Ace3.
- Current supported clients are defined by `Triage.toc`, not this skill.

## Client Buckets

Before code edits, declare one bucket:

- `Retail`: Midnight 12.0+, C_Secrets and compact-frame taint matter.
- `Mists`: Pandaria Classic.
- `Classic Era`: Classic Era / Season of Discovery.
- `shared`: name which clients the change affects and how each is verified.

## Architecture Notes

- `RefreshConfig()` is the central "apply settings to world" entry point.
- `isWoWClassic` means Pandaria Classic, not all Classic clients.
- File load order in `Triage.toc` is authoritative.
- Indicator frames intentionally use named globals and `_G[...]` recapture.
- Managed frame iteration should go through `Utils/FrameRegistry.lua` helpers.

## Retail Aura / Taint Rules

- Guard secret aura fields before string operations.
- Do not use `UnitInRange()` for custom range logic on Retail; use
  LibRangeCheck paths.
- Do not upvalue WoW API functions at file load time.
- Do not mutate Blizzard compact-frame `optionTable` fields from addon code.
- For Retail 12.0.5+ stock aura hiding, use frame `ignore-*` attributes and
  `update-settings`; legacy `buffFrames` / `debuffFrames` parentArrays are
  gone on Retail.

## Workflow

- Use `.worktrees/{tri-id-name}` for non-trivial feature, bug-fix, refactor,
  and release work unless Rawb explicitly approves direct `main` edits.
- Keep behavior changes and refactors in separate commits.
- Run targeted `luacheck` for touched Lua files; run full `luacheck` before
  release or handoff when feasible.
- Gate 1 is code review; Gate 2 is Rawb in-game verification.
- Track active work in `Tri_Tracker.md`; completed work moves to
  `Tri_Completed.md`; `BawrLabs/INDEX.md` is the rollup.
