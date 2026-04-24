# Triage - Enhanced Raid Frames, reforged for Midnight

Short version: Enhanced Raid Frames is back under a new name. Works on
Midnight (12.0.5), still ships for Classic Era and Pandaria Classic
alongside Retail. Links at the bottom.

If you used ERF, you already know what this is. 9-position aura
indicator grid on the built-in raid frames, range checking, target
markers, frame scaling, per-spec profiles, import/export. All of that
still works. A few things were silently broken through the late
Midnight PTR builds; those are fixed.

## Why the new name

ERF's original author Soyier (Britt W. Yazel) stepped back from the
addon around the Midnight transition. 1.7M downloads on the old
listing don't maintain themselves, and nobody was picking up the code.
I emailed in March asking to continue it, didn't hear back, so the
fork ships under a new name with full attribution. All of the original
ERF work is Soyier's - eight years of it. Credit where it's due.

`/triage`, `/tri`, and the old `/erf` alias all open the settings
panel.

## v1.0 - the port

Everything that worked pre-Midnight works again, and the things that
broke on 12.0 are fixed. Headline additions over ERF:

- **Dispel Overlay** - a colored border and glow on any raid frame
  where you can dispel a debuff. Color matches the debuff type. Works
  for every class with a dispel, not just healers. Six knobs to tune
  it.
- **Test Mode** - `/triage test` spawns 5/10/25/40 synthetic preview
  frames so you can configure indicators and the dispel overlay
  without being in a group. Indicators, target markers, range fade,
  tooltips, and simulated healing all render on the previews.
- Minimap button.
- Blizzard's stock buff/debuff icons show alongside your indicators
  by default now. Still togglable.

Fixes worth calling out: "Mine Only" was silently not filtering, glow
animation was calling a deprecated API and quietly doing nothing,
range checking was crashing on Midnight, click-casting and mouseover
macros didn't work through indicators. All of that works now.

## v1.1 - shipped yesterday

Five quick wins from the old ERF issue backlog:

- **Keep aura indicators visible out of range.** Parent frame fades,
  indicators don't. Useful when you want to keep watching HoTs on
  someone you've walked past.
- **Three-way caster filter per indicator: All / Mine / Not Mine.**
  Two druids in a group can each watch the other's Rejuv and stop
  overwriting it.
- **Countdown text has its own corner setting,** separate from stack
  count. Put them in opposite corners if you want both readable.
- **Position sliders move in 0.5% steps now.** Twice the precision.
- **Custom range extends to 60 yards on Retail** for specs with
  talent-boosted heal range. If the range you pick has no checker
  available on your spec, Triage tells you in chat instead of
  silently not fading.

Also fixed two login-time Lua errors that showed up on 12.0.5 live -
a stale library include and a SecureHook on a global Blizzard removed
in that patch.

## Classic Era and Pandaria Classic

Builds for both ship alongside Retail. I play Retail, so Classic
testing is community-assisted. If something's off on your client,
please file an issue - the bug report template has a Game Version
field so I know which client and build to reproduce against.

## Links

- CurseForge: <https://www.curseforge.com/wow/addons/triage-erf>
- Source: <https://github.com/Royaleint/Triage>
- Report bugs: <https://github.com/Royaleint/Triage/issues>
- Changelog: <https://github.com/Royaleint/Triage/blob/main/CHANGELOG.md>

Feedback welcome. If you were an ERF user especially - if anything
feels different in a bad way, tell me.
