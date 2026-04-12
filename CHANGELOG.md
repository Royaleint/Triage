# Triage Changelog

## v1.0.0 — ERF Reforged

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
- Full Classic Era and Pandaria Classic support

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
