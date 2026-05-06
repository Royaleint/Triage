# Triage Changelog

## v1.2.0 (2026-05-06)

New healing-focus highlight, spec aura defaults, indicator copy and reset tools, and a wave of fixes for target markers, dispel highlights, stock auras, and combat-safe options.

---

### New

- **Triage Focus.** Highlights the party or raid member with the biggest health deficit so you can find them without scanning every bar. Tune the range, minimum deficit, update speed, color, border width, and glow style under General options.
- **Spec aura defaults.** Fill empty indicator slots with curated aura watch lists for your current specialization. Existing custom aura lists are left alone when you apply defaults.
- **Indicator copy tools.** Copy selected settings — visibility, icon, text, animation — from one indicator position to another without touching aura watch lists. Build one indicator the way you want it, then reuse the look on the other eight.
- **Indicator reset tools.** Reset selected setting categories on one indicator position or every position at once.
- **Aura watch list reset.** Clear the selected indicator's aura watch list, or wipe all of them in one go.
- **Reset confirmations.** Broad indicator and spec-default resets now ask for confirmation, so a stray click can't wipe nine indicators or your spec defaults.

### Improved

- Minimap button click now opens Triage inside the Blizzard settings UI, so options live in one place with the rest of your addons instead of in a separate window.
- Resetting current spec defaults now clears indicator settings and aura watch lists before applying the curated list, so the reset button actually resets instead of layering defaults on top of old settings.
- Indicator setting resets now use the same baseline defaults for every position, so all nine indicators reset consistently.
- Neutral dispel highlights now use Blizzard's stock dispel highlight when color-by-type is off, matching the look of the default game UI.
- Dispel overlay behavior stays in sync when you switch between colored and neutral dispel highlights.

### Bug Fixes

- Fix target markers not appearing on Blizzard party and raid frames. Markers also stay matched to the correct unit when raid frames update, move, or get reassigned.
- Keep stock Blizzard buff and debuff icons hidden on Retail when their Triage visibility options are turned off. The toggles were being ignored on the Midnight client.
- Stop indicator mouse setup from firing protected changes during combat. Changes that aren't combat-safe now wait until combat ends instead of triggering Lua errors.

## v1.1.0

### What's new
- **Keep aura indicators visible when you step out of range.** New toggle under Out-of-Range. Handy for watching heals on someone you've walked past.
- **Filter each indicator by who cast the aura.** The old Mine Only checkbox is now a three-way choice: All, Mine, or Not Mine. Two druids in a group can each watch the other's Rejuv to avoid overwriting.
- **Place the countdown text in any corner.** The countdown now has its own location setting, separate from the stack count. Put them in opposite corners to show both without overlap.
- **Move indicators in half-percent steps.** The position sliders are now twice as fine-grained.
- **Set out-of-range distance up to 60 yards on Retail.** Useful for specs with talent-boosted heals. If none of your current spells reach the distance you pick, Triage tells you in chat instead of silently not fading.
- **Track spells that change ID when they proc.** The Aura Watch List hint now explains the two-line trick for spells like Cenarion Ward.

### What's fixed
- No more login warnings about a missing AceTab library. (The library
  was never used — the file reference was left behind from an earlier
  cleanup.)
- No more "Attempting to hook a non existing target" errors on login,
  zone change, or group changes. (12.0.5 removed an internal Blizzard
  function the overlay was attaching to. The overlay now checks whether
  the function exists before wiring up.)

## v1.0.0 — Triage - Enhanced Raid Frames Reforged

Triage picks up where Enhanced Raid Frames left off. Everything that
worked before Midnight works again, with fixes for the things that
broke and a new feature that didn't exist before.

### What's back
- 9-position indicator grid on Blizzard raid frames
- Track any buff, debuff, or cooldown by name, spell ID, or type
  wildcard (dispel, poison, curse, disease, magic, bleed)
- Countdown timers, stack counts, and glow alerts
- Custom range checking with adjustable fade
- Target marker icons on raid frames
- Frame scaling
- Per-spec profiles with import/export
- Classic Era and Pandaria Classic builds ship alongside Retail — community testing welcome.

### What's new
- **Dispel Overlay** — a colored border and glow lights up around
  any raid frame where you can dispel a debuff. Color matches the
  debuff type. Works for every class with a dispel, not just healers.
  Six settings to tune it how you like.
- **Test Mode** — `/triage test` spawns 5/10/25/40 synthetic preview
  frames so you can tune the addon without joining a group. Indicators,
  target markers, dispel overlay, range fade, tooltips, and simulated
  healing all render on the preview frames.
- Minimap button for quick settings access
- Blizzard's stock buff/debuff icons now show alongside indicators
  by default (you can still turn them off)

### What's fixed
- Range checking no longer crashes on Midnight
- Indicator glow animation works again (old API was deprecated)
- "Mine Only" filter now actually filters (was silently broken)
- Click-casting and mouseover macros work through indicators
- No more errors from target markers during combat
- Profile switching on fresh profiles no longer crashes
- Settings panel doesn't trigger combat lockdown errors

### Credits
Built on the original work of Soyier, who maintained Enhanced Raid
Frames from 2017 to 2025. Thanks for a great addon and all your work
over the years — not just on ERF, but for the WoW addon dev community
as a whole.
