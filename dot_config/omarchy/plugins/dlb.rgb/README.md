# MSI 7E49 RGB Studio

A personal Omarchy shell plugin for the validated OpenRGB build on this MSI
MS-7E49 system.

The selectable bar icon opens a panel with a persistent lights switch, Sync and
Individual device modes, a visual hue/saturation/value picker, and an Advanced
OpenRGB launcher. Merely loading the plugin or refreshing its displayed state
does not perform detection or hardware I/O.

`AUTO-SYNC THEME SELECTIONS` is an opt-in bridge to Omarchy's `theme-set` hook.
When Off, theme selections never access RGB hardware. Turning it On resolves
and previews the current palette without hardware access; `APPLY CURRENT THEME`
performs the first explicit action and arms automation. Future settled theme
selections then apply automatically. In device Sync mode, both targets use the
theme `accent`; in Individual mode, the motherboard uses `accent` and RAM uses
`magenta` (falling back to the accent if necessary).

`PALETTE SOURCE` can instead use the active theme wallpaper. The controller
uses ImageMagick to reduce that image to a small palette, then favors visible,
saturated colors suitable for LEDs. In device Sync mode, the dominant wallpaper
color is used for both targets. In Individual mode, the motherboard uses that
primary and RAM uses a hue-separated companion. Changing the source updates the
preview and disarms automatic writes; the new palette is not sent to hardware
until `APPLY & START THEME SYNC` is selected. A later Omarchy theme selection
extracts the wallpaper installed with that theme. Cycling only the background
within the same theme does not currently trigger a lighting update.

The `BAR ICON` section offers Link, Stack, Split, and the standalone Maingear
mark. The selected icon is also used in the panel header. `SYNC ICON COLORS`
switches between device-state colors and the standard Omarchy plugin foreground
color. Both appearance choices, recent colors, and favorites are UI-only and
persist across shell restarts in
`~/.local/state/openrgb-msi7e49/appearance.json`.

Sync mode lets the visual picker apply one shared color to the motherboard and
both RAM DIMMs together. Individual mode uses picker target buttons to apply
the motherboard or RAM pair separately. Switching modes only stores a local
preference and never accesses hardware.

`TURN LIGHTS OFF` turns both targets black for the night while retaining their
last successful colors. It becomes `TURN LIGHTS ON` while dark and restores that
saved pair when selected. Both directions are explicit combined hardware
actions; they remain volatile and never save to device firmware.

Theme changes never turn darkened lights back on. While the lights are off, a
new palette only replaces the saved resume pair. Duplicate and stale theme
requests are ignored. Automatic failures are retained for the panel's
dismissible error banner and are never retried.

Picker interactions update only the selected target's preview. Hardware is
accessed only after an explicit Apply or lights-switch action.

`SAVED COLORS` keeps the 5 most recently applied unique manual colors, newest
first. Only a successful Apply adds to this history; picker drags, status
refreshes, theme sync, and failed actions do not. Each successful
Individual-mode apply records that target's color. Favorites are stored
separately, stay pinned when recent colors age out, and are also limited to 5.
Select any swatch to load it into the active picker target (or both targets in
Sync mode) without accessing hardware. Right-click a swatch to add or remove a
favorite. Once all 5 favorite slots are used, remove one before adding another;
favorites are never evicted automatically.

Hardware actions delegate to `~/.local/bin/openrgb-msi7e49-control`. That
guarded command:

- verifies the tested OpenRGB binary SHA-256;
- enforces complete detector allowlists;
- uses a motherboard-only profile for motherboard changes and an ENE-only
  profile for RAM changes;
- serializes actions and refuses to run while the OpenRGB GUI is open;
- performs one non-persistent Static action with no retry or firmware save;
- records the last successful colors, saved resume colors, lights state, and
  Sync/Individual preference in
  `~/.local/state/openrgb-msi7e49/state.json`.

The displayed colors are the last successfully applied or visually confirmed
values, not a hardware readback. Changes made elsewhere can make them stale.

Safe checks that do not access hardware:

```bash
openrgb-msi7e49-control check
openrgb-msi7e49-control plan motherboard 12AB34
openrgb-msi7e49-control plan ram C0FFEE
openrgb-msi7e49-control plan all FF00AA 00E5FF
openrgb-msi7e49-control plan-power off
openrgb-msi7e49-control plan-power on
openrgb-msi7e49-control theme-preview
openrgb-msi7e49-control theme-preview tokyo-night wallpaper
openrgb-msi7e49-control palette-source theme
openrgb-msi7e49-control palette-source wallpaper
```
