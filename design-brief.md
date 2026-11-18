# Design Brief v0.1 (working title: TBD)

## Identity
- Base: CachyOS (Arch), KDE Plasma (Wayland first, X11 fallback)
- Purpose: daily desktop + local AI. Users: owner + family/friends (Hebrew/RTL is a first-class language).
- Hardware floor: Intel UHD 630, 16GB RAM. Design must run at 60fps there and leave RAM for AI models.
- Name and logo: not chosen yet. Do not use CachyOS logos or marks in a public release.

## Personality
Dark, technological, sharp. Calm and precise, not flashy.

## Principles
1. Quiet by default: content first, chrome recedes.
2. Sharp, not busy: small radii (2-6px), thin 1px lines, one accent color.
3. Fast feels beautiful: short, subtle motion; no blur or heavy effects (iGPU).

## Color story
Near-black blue-tinted background, one electric cyan accent (#00E0FF). Status colors are green/amber/red, used only for state. A light theme exists (accent darkened to #005F6E) so the OS stays usable in daylight and for accessibility.

## Typography
- UI: Inter with Noto Sans Hebrew fallback (RTL tested). Scale 12/13/14/16/20/28.
- Mono: JetBrains Mono.

## Motion
120/180/280 ms, ease cubic-bezier(.2,.8,.2,1). Honors reduced motion (all durations 0).

## Tone of voice
Short, plain, direct. No jargon in the installer; an explicit "this will erase the disk" screen.

## Layers to design (in order)
1. Bootloader theme, Plymouth splash
2. SDDM login
3. First-run welcome (3 screens: language, look, AI setup)
4. Plasma shell: panel, launcher, notifications, quick settings
5. Core apps: Dolphin, Konsole, System Settings
6. Calamares installer
7. Wallpapers, icons, cursors, sounds
8. AI panel (global shortcut, local-only)

## Token files
`design-tokens.json` and `design-tokens.css` (dark and light, same keys).

## Contrast check (WCAG, computed)
Text and status colors on surfaces: all 4.5:1 or higher in both themes.
Known gap: `border` on `bg` is about 1.5:1. That is fine for decorative dividers but below the 3:1 needed for input-field outlines and focus rings. Controls need a stronger border or the accent focus ring.

## Not yet done
- Not tested in a real Plasma session; tokens are not yet translated to a KDE color scheme, Kvantum or GTK theme.
- Reference system you like: not provided yet.
- Fonts (Inter, JetBrains Mono) are assumed installable from Arch repos; verify package names before the build.
