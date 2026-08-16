# Influencer Ratio
<img width="556" height="856" alt="clop_2026-08-16_587" src="https://github.com/user-attachments/assets/c085e74b-2f40-45e6-8b9c-fda4e3323365" />


A macOS menu bar app that snaps the **frontmost window of any app** to a fixed
recording aspect ratio — vertical 9:16 for phone, 16:9 for landscape — so screen
recordings come out at an exact resolution with no cropping in post.

No Dock icon, no window of its own. Menu bar item + global shortcuts.

## Install

```sh
./build.sh install     # builds, copies to /Applications, launches
./build.sh             # build only, into ./build
```

On first launch macOS asks for **Accessibility** access. Grant it in
System Settings → Privacy & Security → Accessibility, then quit and relaunch the
app. Resizing another app's window is impossible without this.

## Shortcuts

All presets are **⌃⌥⌘ + digit**, and every size is expressed in **output pixels**
(what your recorder captures), not points.

| Shortcut | Preset | Pixels |
|---|---|---|
| ⌃⌥⌘1 | 4K UHD | 3840×2160 |
| ⌃⌥⌘2 | 1440p | 2560×1440 |
| ⌃⌥⌘3 | 1080p | 1920×1080 |
| ⌃⌥⌘4 | Vertical 1080p | 1080×1920 |
| ⌃⌥⌘5 | Vertical 2K QHD | 1440×2560 |
| ⌃⌥⌘6 | Vertical 4K UHD | 2160×3840 |
| ⌃⌥⌘9 | Vertical 720p | 720×1280 |
| ⌃⌥⌘7 | Square | 1080×1080 |
| ⌃⌥⌘0 | Center window | — |

The resized window is centred on whichever screen it is already on. The menu bar
briefly flashes the result, e.g. `Safari → 1080×1920 px`.

### Pixels vs points

On a 2× Retina display a window that is 540×960 **points** renders at
1080×1920 **pixels**. The app reads each screen's `backingScaleFactor` and does
that conversion, so the preset numbers are the resolution you actually record.

## Screen space

A preset only produces its exact resolution if the window physically fits on
screen. The menu marks presets that don't with **⚠︎**, and the tooltip shows the
usable area of the screen under your pointer.

Two behaviours, toggled by **Shrink to Fit Screen** in the menu:

- **Off (default)** — the window gets the exact requested size and overflows past
  the bottom edge, pinned to the top so the title bar stays reachable. Window-based
  recorders (ScreenCaptureKit, QuickTime "record window") generally still capture
  the full surface; region/display recorders will not. Test yours before a real take.
- **On** — the window is scaled down to the largest size of that same aspect ratio
  that fits. Correct framing, lower resolution.

### Reclaiming height for 4K

On a display running at 3840×1080 points @2× (7680×2160 px), the usable area is
only 954 pt / 1908 px tall — the menu bar takes 30 pt and the Dock 96 pt. 4K needs
1080 pt. To make it fit exactly:

```sh
defaults write com.apple.dock autohide -bool true && killall Dock   # +96 pt
```

plus System Settings → Control Center → "Automatically hide and show the menu bar"
→ Always (+30 pt). That brings the usable area to the full 1080 pt = 2160 px.

### Vertical above 1080p needs a virtual display

Panel height is a hard ceiling that no scaling mode changes. A 2160 px tall
display can show at most **1215×2160 px** of 9:16 — so vertical 2K (2560 px tall)
and vertical 4K (3840 px tall) cannot be displayed, and therefore cannot be
screen-recorded, on that panel.

The presets are still correct; they need somewhere taller to live:

- **Virtual display** — [BetterDisplay](https://github.com/waydabber/BetterDisplay)
  creates a dummy display at any resolution, e.g. 2160×3840. Put the window there
  with ⌃⌥⌘6 and record that display. This is the only way to get true vertical 4K
  out of a landscape panel.
- **Shoot 1080×1920 and upscale** in post if the platform only needs a 4K container.
- **Shrink to Fit on + ⌃⌥⌘6** gives the largest 9:16 the real screen can hold —
  1215×2160 px with the Dock and menu bar hidden. Best native vertical available.

## Notes

- Some apps refuse the size they're given — Terminal snaps to a character grid,
  others enforce a minimum width. The menu bar flash reports the size actually
  applied and names the mismatch rather than pretending it worked.
- **Launch at Login** is in the menu.
- The bundle is ad-hoc signed, so its code signature changes on every rebuild and
  macOS makes you re-grant Accessibility. To avoid that, build with a stable
  identity: `SIGN_ID="Developer ID Application: …" ./build.sh install`.

## Layout

| File | Role |
|---|---|
| `Sources/InfluencerRatio/Presets.swift` | preset table — edit to add sizes or change keys |
| `Sources/InfluencerRatio/WindowResizer.swift` | Accessibility API, coordinate conversion, centring |
| `Sources/InfluencerRatio/HotkeyManager.swift` | global hotkeys via Carbon `RegisterEventHotKey` |
| `Sources/InfluencerRatio/AppDelegate.swift` | status item, menu, feedback |
| `build.sh` | assembles + signs the `.app` bundle |
