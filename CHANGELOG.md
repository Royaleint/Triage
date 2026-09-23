# Triage Changelog

## Maintenance mode (2026-05-24)

Triage has moved to maintenance mode. It still works and stays compatible with current game patches across Retail, Classic Era, TBC Classic, and Pandaria Classic, and critical bugs will be fixed, but new feature development has ended. See [SHELVED.md](SHELVED.md) for the full picture.

## v1.4.0-beta.2 (2026-09-22)

Retail fixes for raid frame errors in Edit Mode, plus a simpler Triage entry in the Options window.

---

This is a beta build. Please test it and report anything that looks wrong. The dispel border on party frames has not been re-checked in game on this build; if it shows without a dispellable debuff, or stays off when there is one, please report it. Closing the Options window after typing in its search box has also not been re-checked.

### Bug Fixes

- Opening Edit Mode with Triage running no longer sets off a flood of Lua errors from Blizzard's party and arena frames. Please report if you still see them.
- Closing the game's Options window while Edit Mode is open no longer breaks the raid frames' incoming-heal display until the next reload.
- Leaving Edit Mode through its close button, or closing the game's Options window while Edit Mode is open, no longer causes a Lua error from Blizzard's arena frames.

### Changed

- The Triage entry in the game's Options window is now a single Open Triage Options button that opens Triage's own options window.
- On Retail, while Edit Mode is open, Triage indicators show the unit's real auras instead of Edit Mode's placeholder auras.

### Known Issues

- On Retail, turning Stock Dispellable Icons off hides the icons but not Blizzard's colored dispel border.
- Stock icon changes made during combat apply when combat ends.
- A brief one-frame flicker of stock icons can happen when settings change.
- Classic Era, TBC Classic and Pandaria Classic are only lightly tested in this beta; the new single-button Triage entry in the Options window has not been checked on them.
- Indicator text uses the transparency set in the text color picker. If your countdown text looks too faint, reopen the picker and set the transparency you want.

## v1.4.0-beta.1 (2026-09-21)

Retail fixes for indicators during combat, the dispel border after Edit Mode, and stock icon visibility, plus two options page fixes.

---

This is a beta build. Please test it and report anything that looks wrong. Not every fix in this list has been confirmed in game yet.

### Bug Fixes

- Custom aura indicators no longer disappear during Retail combat when the game restricts aura information. Configured indicators stay visible, keep their placement and size, and recover after combat.
- Fixed a red pulsing dispel border appearing on every party frame on Retail after leaving Edit Mode and then changing any option. It no longer appears without a real dispellable debuff.
- Turning a stock icon switch back on releases Blizzard's own icons immediately, with no reload needed.
- Indicators no longer take mouse clicks meant for the party or raid frame underneath them.
- Fixed indicator offsets sticking after the first change, so later horizontal or vertical changes move the indicator as expected.
- Changing Indicator Size no longer scrolls the options page back to the top.
- Triage no longer prints a diagnostic line to chat on Retail when the game restricts aura information.
- This beta contains changes intended to stop the flood of Lua errors from Blizzard's party frames when Edit Mode is opened on Retail with Triage running. Please report whether you still see them.

### Changed

- Turning a Stock Buff Icons, Stock Debuff Icons or Stock Dispellable Icons switch on no longer forces Blizzard's own icons to show. If you turned them off in Blizzard's raid frame settings, they stay off.
- Indicators set to Show Only if Missing stay hidden while the game restricts aura information during combat, with a one-time notice in chat.

### Known Issues

- On Retail, turning Stock Dispellable Icons off hides the icons but not Blizzard's colored dispel border.
- Stock icon changes made during combat apply when combat ends.
- A brief one-frame flicker of stock icons can happen when settings change.
- Classic Era, TBC Classic and Pandaria Classic are only lightly tested in this beta.
- Indicator text now uses the transparency set in the text color picker. If your countdown text looks too faint, reopen the picker and set the transparency you want.

## v1.3.4 (2026-08-23)

Fixes for Retail 12.1 aura errors, stock aura icon visibility, and indicator placement, plus an autocomplete improvement.

---

### Improved

- Aura watch-list autocomplete suggestions can now be accepted with Enter as well as click. Enter still adds a new line when no suggestion is open.

### Bug Fixes

- Fixed aura indicators breaking during combat on Retail 12.1.
- Fixed stock Blizzard buff and debuff icons still showing on party and raid frames while Triage's own indicators were active, even though their Triage visibility options were turned off. This affected Retail, Classic Era, and Pandaria Classic.
- Fixed indicators and target markers sitting at the wrong height on party and raid frames after logging in or reloading.

## v1.3.3 (2026-08-19)

Hotfix for Retail 12.1 aura secrecy errors.

---

### Bug Fixes

- Fixed aura indicators breaking during combat on Retail 12.1.

## v1.3.2 (2026-06-08)

Hotfix for Classic-family raid frame fading in combat.

---

### Bug Fixes

- Fix Pandaria Classic raid frames fading when combat starts and staying faded until combat ends, even when players are in range. The same Classic-family range handling is also corrected for Classic Era and Burning Crusade Classic.

## v1.3.1 (2026-05-20)

Packaging fix so Triage installs from a single download across all supported clients.

---

### Bug Fixes

- Triage now installs from one download that covers Retail, Classic Era, Burning Crusade Classic, and Pandaria Classic, instead of a separate file for each version.

## v1.3.0 (2026-05-19)

Burning Crusade Classic support and a stock-aura visibility fix.

---

### New

- **TBC Classic support.** Triage now runs on the Burning Crusade Classic Anniversary client, joining Retail, Pandaria Classic, and Classic Era.

### Bug Fixes

- Fix stock Blizzard buff and debuff icons reappearing on raid frames after a unit was assigned or reassigned, even with their Triage visibility options turned off.

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
