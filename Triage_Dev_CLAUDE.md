# Triage_Dev — Development Environment

Private nested git repo (Royaleint/Triage-Dev) — gitignored by the public Triage repo. Contains dev scripts, docs, plans, session tracking, scan data, and the Triage_Dev companion addon.

Commit dev changes inside Triage_Dev/ separately from public addon code.

## Working Principles

These bias toward caution over speed. For trivial tasks, use judgment.

**Think before coding.** Don't assume, don't hide confusion, surface tradeoffs.
- State assumptions explicitly; if uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop, name what's confusing, and ask.

**Simplicity first.** Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If 200 lines could be 50, rewrite it.
- Ask: "would a senior engineer call this overcomplicated?" If yes, simplify.

**Surgical changes.** Touch only what you must. Clean up only your own mess.
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Remove imports/variables/functions your changes orphaned; leave pre-existing dead code alone unless asked.
- Test: every changed line should trace directly to the user's request.

**Goal-driven execution.** Define success criteria, then loop until verified.
- "Add validation" → write tests for invalid inputs, then make them pass.
- "Fix the bug" → write a test that reproduces it, then make it pass.
- "Refactor X" → ensure tests pass before and after.
- For multi-step tasks, state a brief plan as `step → verify` pairs.
- Strong success criteria let the agent loop independently; weak ones ("make it work") force constant clarification.

## Session Workflow

- **Start:** Run `/startup` skill
- **During:** Keep `Tri_Tracker.md` In Progress items updated with current scope and next action. (Cross-project rollup lives in `BawrLabs/INDEX.md`; studio-level items in `BawrLabs/Studio_Tracker.md`.)
- **End:** Run `/wrapup` skill

**Agent routing:** Address agents by name to activate Bawr Labs. Prodigy for feature requests and specs. Argus for code review. Douglock for implementation. Everett for release notes and comms. Claude handles unrouted requests directly — this is intentional for quick tasks.

## Planning

All non-trivial features and fixes require a plan before implementation. Use the studio gate overlay at `../BawrLabs/plans/PLAN_TEMPLATE.md`. Gate 0 (pre-read research) completes before plan mode. Gate 3 (open questions) must be empty before handoff — a plan with unconfirmed assumptions is not ready.

### Plan file lifecycle
- Save active plans to `Triage_Dev/plans/active/` with descriptive filenames
- Move completed plan files to `Triage_Dev/plans/completed/` after merge
- `REFACTOR_CONTRACT.md` stays in `Triage_Dev/plans/` permanently

### Plan execution
- At the end of each plan phase or commit block, summarise what was done and await user confirmation before proceeding to the next phase
- Never chain multiple phases without a checkpoint

## Changelogs

Two changelogs with different audiences:

- `CHANGELOG.md` (public, committed) — player-facing, what changed and why it matters
- `Triage_Dev/CHANGELOG-internal.md` (technical, gitignored) — implementation details, architectural decisions, files changed

Routing rules: `.claude/skills/triage/references/changelog-system.md`

## Triage_Dev Companion Addon

Lives at `Triage_Dev/Triage_Dev/`, never published. Dev features gate on `<TODO: confirm dev-addon flag — Homestead uses HA.DevAddon; Triage equivalent likely EnhancedRaidFrames.DevAddon>`. Provides in-game dev tools: API testing, scan export, debug overlays.

## Reference Library

Reference docs are available on demand — read when needed, not auto-loaded. The wow-api MCP server covers WoW API, frame patterns, and Ace3 conventions. For Triage-specific references, read the files directly.

<TODO: port your existing Triage reference table here. Likely entries based on the addon's scope:>

| File | Contents |
| --- | --- |
| `Triage_Dev/reference/WOW_ADDON_PATTERNS.md` | Lua 5.1 constraints, event/frame patterns, performance, tooltip hooks |
| `Triage_Dev/reference/RAID_FRAME_API_REFERENCE.md` | CompactRaidFrame hooks, unit frame registry, secure-template constraints |
| `Triage_Dev/reference/AURA_SYSTEM_REFERENCE.md` | UNIT_AURA payload, AuraUtil patterns, caster filter semantics |
| `Triage_Dev/reference/DISPEL_OVERLAY_ARCHITECTURE.md` | Atlas usage, debuff-type colors, Classic vs Retail gating |
| `Triage_Dev/reference/LIBRANGECHECK_NOTES.md` | Range checker availability by expansion, fallback strategy |
| `Triage_Dev/reference/DATABASE_MIGRATION_PATTERNS.md` | AceDB version bumps, idempotent migration rules |
| `Triage_Dev/reference/ADDON_MANUAL.md` | Full module-by-module breakdown, data pipeline, API capability map |
| `../BawrLabs/plans/PLAN_TEMPLATE.md` | Studio-level plan gate overlay (shared across all projects) |
| `Triage_Dev/plans/REFACTOR_CONTRACT.md` | Pre-refactor baseline protocol |
| `Triage_Dev/session/KNOWLEDGE.md` | Running log of session findings and gotchas |
