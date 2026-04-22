# Triage_Dev

Development-only notes, plans, and research for the Triage addon.

This folder is excluded from CurseForge packaging via `.pkgmeta` (see the
`Triage_Dev` entry in the `ignore` block). Safe to commit anything here
that helps design and track in-progress work without bloating the
addon distribution.

## Layout

- `plans/` — per-issue implementation plans. File naming convention:
  `TRI-<id>-<short-slug>.md`, matching the tracker IDs used in
  `Tri_Tracker.md`.
- `research/` — reference docs and feasibility audits that outlive a
  single ticket. Consulted when scoping new features.

## When to write here

- Plans: when an issue is large enough that the implementation approach
  needs to be captured outside of the GitHub issue body — typically
  anything with multiple phases, cross-client gating questions, or
  non-trivial API risk.
- Research: when the investigation produces reusable findings (Blizzard
  API changes, competitor analysis, etc.) that will inform more than
  one issue.

## Relation to other planning docs

- `Tri_Tracker.md` (repo root) is the authoritative backlog — short
  per-ticket entries with TRI-### IDs, acceptance criteria, and
  statuses. Keep it scannable.
- `Tri_Completed.md` (repo root) is the shipped-work archive.
- Files here go deeper than what fits in the tracker. Link from the
  tracker entry (`See Triage_Dev/plans/TRI-018-health-bar-color.md`)
  rather than duplicating content.
