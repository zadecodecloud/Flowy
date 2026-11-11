# 15 · Settings and onboarding

## Purpose
- A settings window that exposes every option in specs 01–14 and 16.
- A first-launch onboarding inside the notch.
- English and Vietnamese throughout.

## Settings window

### Structure
A standard macOS settings window: a sidebar of sections, a scrolling detail pane of cards,
and a search field.

| Group | Sections |
|---|---|
| App | General · Appearance · Language · Permissions · Software update · About |
| Notch | Notch (style, size, outline) · Display · Gestures · Activity priorities |
| Live content | Now Playing · Lock screen (with the music panel) · Drop and tray · Mirror · HUD · Timer · Calendar · Downloads · Screen recording and screenshots · System status |

- **System status** is one section with its own pages: Battery · Focus · Network ·
  Bluetooth · External devices. It is not five sidebar entries. The build already works
  this way; keep it.

- A **developer section** exists only when a developer token is active
  ([16](16-updates-licensing.md)).
- **No support or donation links** ship until they are configured.

### Card conventions
- Each card groups related rows. A row has a title, a one-line description and a control:
  toggle, slider with value, segmented picker, menu, file chooser, or shortcut recorder.
- **Duration sliders** use 1 s steps, 1–5 s unless the feature says otherwise.
- **Changes apply immediately.** There is no Save button.
- Each section has **Reset to defaults**, which asks for confirmation first.
- **Live previews:** sections with a visual style show a small live preview. This applies to
  the notch appearance, HUD, Bluetooth, battery and lock-screen card.
- **Search:**
  - Search covers section names, row titles and descriptions.
  - Choosing a result opens its section and highlights the row.
  - With no matches, an empty state names the search text.
- The window remembers the last section shown.
- The window's **appearance** follows the setting: system, light or dark.

### General
- Launch at login (off) · Dock icon (off) · Menu-bar icon (on) · Settings appearance
  (system).
- If the menu-bar icon is hidden and the Dock icon is off, Settings stays reachable from the
  notch's right-click menu. Opening the app again also opens Settings.

### Language
- **Two languages:** *English* (default) and *Tiếng Việt*.
  - App language: the settings window and menus.
  - Notch language: text inside the notch.
  - Each can be set separately, or one choice can apply to both.
- **Stored values that are unknown or retired fall back to English.** No other language may
  ever appear, whatever the system language.
- **Changing the language:**
  - updates all open UI immediately, without a relaunch;
  - shows a brief notch alert in the new language.

### Permissions
- One row per permission, each with its status (granted / needs access) and a button that
  opens the matching System Settings pane:
  - Accessibility
  - Bluetooth
  - Media controls (Automation for Music and Spotify)
  - Camera
  - Calendar
  - Full Disk Access
  - Automation
- **Status refreshes** when the window becomes active.
- **Ask in context:** request each permission only when the feature that needs it is first
  used or enabled. Never ask for everything at launch.

## Onboarding
- **When:** shown once, ≈ 1 s after the first launch, as notch content with system priority
  "onboarding" ([02](02-content-engine.md)).
- **While it runs**, power alerts and other alerts are held back.
- **Steps** (expanded notch cards, each with Next / Back, and Done on the last):
  1. **Welcome:** app name, a short tagline, and a new welcome animation.
  2. **Permissions:** explains which permissions unlock which features, with a button to the
     Permissions section.
  3. **Pages:** a hand-swipe symbol and a short explanation that sideways swipes switch
     between Music, Tray and Mirror.
  4. **Done:** a short confirmation.
- **Skipping or finishing** marks onboarding as seen, and normal activities start, for
  example the current music.
- A debug-only command can replay onboarding.

## Accessibility (all specs)
- Every control has an accessibility label.
- Reduce Motion turns off non-essential animation: scrolling text, drifting backgrounds,
  flips and bounces.
- Reduce Transparency means solid surfaces.
- Increase Contrast removes blur effects on text.
- Keyboard: Settings is fully keyboard-navigable. The notch itself needs no keyboard
  operation.

## Localisation (all specs)
- All user-visible text lives in a string catalog with **English (source)** and
  **Vietnamese**.
- The text is written new. Do not reuse the old catalog.
- Format strings keep identical placeholders in both languages. A test checks this.
- Missing Vietnamese text falls back to English, never to a key name.

## Acceptance checks
1. The first launch shows the welcome step in the notch. Finishing it never shows it again.
2. Setting the language to Tiếng Việt changes Settings and the notch text immediately.
   Relaunching keeps Vietnamese.
3. A stored language value of an unsupported code (for example "ru") starts the app in
   English.
4. Searching "volume" finds the HUD volume row and jumps to it.
5. Reset in the HUD section restores all HUD defaults after a confirmation.
6. Denying the camera shows "needs access" on the Camera row, and its button opens the
   camera privacy pane.
