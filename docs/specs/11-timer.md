# 11 · Timer

## Purpose
Two kinds of timer show in the notch:
1. **Clock app timers:** timers started in macOS Clock appear in the notch and can be paused
   or cancelled from there.
2. **Quick timer:** a timer set from the notch itself, opened with a global keyboard
   shortcut.

## Behaviour

### Clock app timers
- **Detecting them:** the running or paused timer comes from the Clock app's stored state
  and its system log messages.
  - There is no public API, so implement independently.
  - Watch the stored preferences file for changes. Also follow the timer service's log
    stream, which reports more promptly.
  - If the log stream stops, restart it with back-off.
- **Pause state:** the most recent logged pause or resume wins over stale stored values. The
  stored preferences are rewritten after the log line arrives.
- **Remaining time** counts down locally between updates.
- **The *Timer* activity** (priority 4) exists while a Clock timer is running or paused, and
  the timer activity setting is on.
  - **Compact:** on the left, a small circular progress ring (orange gradient on a 16 % white
    track, with a pause glyph when paused). On the right, the remaining time as text (m:ss,
    or with hours). Width: base + 110 pt for m:ss and base + 170 pt with hours (10 pt less
    in island mode). Insets: leading 14 pt and trailing 15 pt (island 5 pt and 7 pt).
  - **Expanded:** base + 170 × base + 60 pt. It shows the large remaining time (h:mm:ss or
    m:ss) and two 45 pt round buttons: pause/resume (orange tint) and cancel (grey tint).
- **The buttons control Clock itself:**
  1. Activate Clock.
  2. Press its pause/resume or cancel button through the Accessibility interface, waiting
     briefly for it to appear.
  3. Return focus to the app that was in front before.
  - This needs the Accessibility permission. Without it, the buttons are disabled with a
    hint.
- **When the timer ends** (or is cancelled), the activity is removed.

### Quick timer
- **Shortcut:** a global shortcut, default **Control-Option-T** and configurable in
  settings, toggles the quick timer setup.
  - The setup has system priority "quick timer setup" ([02](02-content-engine.md)).
  - Size: base + 160 × base + 135 pt (island base + 220 × base + 135 pt, corner radius a
    quarter of the base height). It stays open until Start, the shortcut again, or its close
    button.
- **Setup view:** a horizontal **ruler** with ticks 9 pt apart.
  - Drag it or scroll it to choose a duration.
  - Values run from 10 s to 50 s in 10 s steps, then 1 min to 120 min in 1 min steps.
  - It opens at the last used value, or 15 min.
  - The chosen value is shown large above the ruler.
  - A **Start timer** button starts the countdown.
- **Running:**
  - Shows the countdown with **Stop** and **Pause / Resume**.
  - Collapses to the same compact ring as Clock timers.
  - Pressing the shortcut again reopens the controls.
- **When it finishes:**
  - Show a *time's up* activity that stays until the user acts. Size: base + 130 × base +
    60 pt (island base + 250 × base + 50 pt). It has a title and two 45 pt round buttons:
    *restart* (orange tint), which runs the same duration again, and *dismiss* (grey tint,
    ×).
  - Play the chosen **timer sound**, if *timer sound* is on (default on). It **loops** until
    either button is pressed, the activity is swiped away, or *hide everything* empties the
    notch.
- **Timer sounds:** the system ringtone set: Radar (default), Alarm, Apex, Beacon,
  Bulletin, By The Seaside, Chimes, Circuit, Constellation, Cosmic, Crystals, Hillside,
  Illuminate, Night Owl, Opening, Playtime, Presto, Radiate, Reflection, Ripples, Sencha,
  Signal, and the rest of that set.
  - Play them from the system's ringtone library. Do not bundle them.
  - Settings plays a preview when a sound is picked: once, to its natural end, without
    looping.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Timer activity | On | Clock and quick timers in the notch |
| Timer sound | On | Plays when the quick timer finishes |
| Sound | Radar | Ringtone list with preview |
| Quick timer shortcut | Control-Option-T | Shortcut recorder |

## Edge cases
- **Several Clock timers:** running timers come first, ending soonest first; then paused
  ones, least time left first.
- **Timer activity off:** Clock detection stops, a running quick timer stops, and the
  shortcut is unregistered.
- **Clock app not installed or not running:** detection must not crash. Stored state alone is
  enough to show a running timer.
- **Shortcut already taken by another app:** show a warning in settings.
- **A quick timer running while a Clock timer also runs:** the soonest-ending timer shows,
  and the other stays reachable through its own activity.

## Acceptance checks
1. Starting a 5-minute timer in Clock shows the ring in the notch within ≈ 2 s, and the
   expanded view counts down.
2. Pause in the notch pauses the Clock timer, and focus returns to the previous app.
3. Cancel in the notch ends the Clock timer, and the activity disappears.
4. Control-Option-T opens the ruler. Choosing 30 s and Start counts down. At the end, Radar
   loops and the time's-up activity stays until *dismiss* or *restart* is pressed.
5. Changing the sound to Chimes plays a preview, and Chimes plays at the next finish.
