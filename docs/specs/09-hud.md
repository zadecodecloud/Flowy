# 09 · HUD (volume, brightness, keyboard backlight)

## Purpose
- Replace the system's on-screen volume, display-brightness and keyboard-backlight
  indicators with a level display in the notch.
- Each of the three can be switched on or off. All three are **on by default**.

## Behaviour

### Catching the keys
- **Intercept the hardware keys** (or Touch Bar equivalents) for volume up, down and mute,
  brightness up and down, and keyboard-backlight up and down.
  - This requires the **Accessibility** permission.
  - Without it, check again every 1 s until it is granted. Meanwhile the system indicators
    keep working as usual.
- **An intercepted key is consumed**, so the system shows no indicator and plays no tick of
  its own. The app then applies the change itself:
  - **Volume:** steps of 1/16. *Option + Shift* gives fine steps of 1/64, matching the
    system.
    - Mute toggles. Raising the volume from mute unmutes and restores the last audible
      level, at least one step.
    - Applied to the current default output device.
  - **Display brightness:** steps of 1/16 (fine 1/64) on the built-in display. Steps are
    discrete, because the smooth hardware ramp is only available when the system handles
    the key.
  - **Keyboard backlight:** the same stepping.
- **A key whose HUD is off is not intercepted.** The system handles it normally.
- **Volume feedback tick:**
  - Plays only if the system's sound preference for volume-change feedback is on. When that
    preference has never been set, treat it as on, as macOS does.
  - Holding *Shift* inverts it, as in macOS.
  - A NotchFlow setting can turn the tick off entirely (default on: follow the system).
  - Plays on every volume up or down press, key repeats included. Each press restarts the
    sound from the beginning. Never for mute.

### Changes not made by keys
- **Volume changes from elsewhere** also show the volume HUD while it is on. Examples:
  headphone buttons, AirPods stems, other apps, a change of output device.
  - Watch the default output device's volume and mute properties, and the default-device
    change.
- **External brightness changes** are not required.

### Display
- **Each event is an alert** ([02](02-content-engine.md)) of the matching kind. A new event
  of the same kind updates the visible HUD in place and restarts its timer, so holding a key
  gives one smooth HUD.
- **Durations** (settings): 2 s each by default, range 1–5 s in 1 s steps, multiplied by the
  global alert duration scale.
- **Symbols:**
  - **Volume:** muted or 0 → speaker with slash; 1–19 → speaker; 20–49 → one wave; 50–69 →
    two waves; 70 and up → three waves.
  - **Brightness:** below 50 % → small sun; otherwise large sun.
  - **Keyboard:** 0 % → dim key light; anything above → bright key light.
- **Volume down while muted** keeps it muted; volume up unmutes.
- **Layout styles** (setting), with widths added to the base notch width:

| Style | Look | Extra width | Extra height |
|---|---|---|---|
| Standard (default family) | Kind title (14 pt) left, level indicator right | bar 140 (keyboard 150) · circle 140 | 0 |
| Compact (default) | Symbol (18 pt; 16 pt in island mode) left, indicator right | bar 140 · circle 85 | 0 |
| Minimal | Symbol and an animated percentage | 80 | 0 |
| Expanded compact | Symbol and percentage on top, bar below the notch | 85 | 35 |
| Expanded detailed | Device name (scrolling), symbol, bar and percentage below the notch | 85 | 65 |

  Island mode uses slightly narrower extras: standard 130 / 140 / 125, compact 130 / 60,
  minimal 75.

- **Indicator** (setting): *bar* (default) or *circle* (ring).
- **Indicator tint** (setting):
  - *Level colour* (default): hue runs from green at 0 % to red at 100 %, with saturation
    0.86 and brightness 0.98. A level of 0 shows white at 45 %.
  - *Plain white*: white at 92 %, or 45 % at 0.
  - *Accent colour*: the system accent, or white at 45 % at 0.
- **Glow** (setting, default on): a soft glow in the fill colour around the indicator.
- **Coloured level** (setting, default on): colours the level as above. When off, plain
  white.
- **Coloured outline** (setting, default off): the notch outline takes the level colour at
  30 % (white at 20 % at 0).
- **The percentage** animates digit changes.

### Lock screen
- The HUD also appears in the lock-screen notch ([05](05-lock-screen.md)).

## Settings
| Setting | Default | Effect |
|---|---|---|
| Volume HUD | On | Intercept and show volume |
| Brightness HUD | On | Intercept and show brightness |
| Keyboard backlight HUD | On | Intercept and show the keyboard backlight |
| Volume feedback tick | On | Follow the system preference; off silences it |
| Durations (each) | 2 s (1–5) | |
| Style | Compact | Standard / compact / minimal / expanded compact / expanded detailed |
| Indicator | Bar | Bar / circle |
| Tint | Level colour | Level colour / plain white / accent |
| Glow | On | |
| Coloured level | On | |
| Coloured outline | Off | |

## Edge cases
- **Output devices with no software volume** (some HDMI or DisplayPort devices): show the
  HUD with the level the system reports, and change nothing.
- **External displays:** brightness keys act on the built-in display only. If there is no
  built-in display, do not intercept the brightness keys.
- **Accessibility granted while the app runs:** interception starts within ≈ 1 s, without a
  relaunch.
- **Very fast key repeat:** one HUD, updated in place. Never a queue of alerts.
- **Under tests:** never install the key interception.

## Acceptance checks
1. Pressing volume up shows the notch HUD and no system indicator, and the volume rises one
   step.
2. Option-Shift-volume-up raises the volume by a quarter step.
3. Mute shows the slashed speaker. Volume up from mute restores the sound.
4. Turning the volume HUD off brings back the system indicator for the volume keys only.
5. Pressing the AirPods stem to change volume shows the HUD.
6. Holding volume up for 2 s shows one continuously updating HUD that disappears 2 s after
   release.
7. Brightness keys change the built-in display brightness and show the sun HUD.
8. Without the Accessibility permission, the system indicators work, and granting the
   permission enables the HUD without a relaunch.
