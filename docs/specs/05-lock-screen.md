# 05 · Lock screen

## Purpose
- Keep the notch alive on the macOS lock screen.
- Show a lock / unlock activity in it.
- Optionally play lock and unlock sounds.
- Host the lock-screen music panel ([06](06-lock-screen-music.md)).

The Face ID unlock animation from the old app is **dropped**.

## Behaviour

### Detecting lock state
- **Primary signal:** the system's "screen is locked" and "screen is unlocked" broadcasts.
- **Safety net:** every 2 s (with ≤ 0.5 s timer tolerance), read the session's locked flag
  and correct the state if a broadcast was missed.
- **Fast user switching:**
  - When the session becomes inactive, enter *preparing to lock*. The notch can get ready
    before the lock screen draws, but shows nothing and plays no sound yet. The padlock and
    the lock sound come only with the real lock.
  - When the session becomes active while locked, treat it as an unlock, unless the session
    itself still reports locked at that moment.
  - When the session becomes active again without a lock, leave *preparing* silently: no
    padlock and no unlock sound.
- **Deduplication:** only real changes are published. The same state twice in a row is
  ignored.

### Lock-state model
| State | Meaning |
|---|---|
| Unlocked, idle | Normal desktop |
| Preparing | The session has gone inactive and the lock is expected |
| Locked | The lock screen is up |
| Unlocking | Just unlocked; the unlock animation runs for 0.82 s, then back to idle |

### Lock activity in the notch
- **When the screen locks**, if *lock screen activity* is on (default), show the lock
  activity:
  - it is the system priority "lock screen" ([02](02-content-engine.md)), so it is above
    every user activity;
  - compact width = base + 55 pt;
  - a closed-padlock symbol at 16 pt semibold, white, on the left;
  - insets: leading 14 pt and trailing 14 pt on notch screens; leading 8 pt and trailing
    6 pt in island mode. The padlock is centred vertically, and the right side of the shape
    stays empty.
- **Debug builds** have a menu item that fakes lock and unlock (with sounds) without locking
  the Mac, for QA. They also have a *lock-screen preview*: the music panel
  ([06](06-lock-screen-music.md)) in a normal desktop window, fed by the current media and
  closed with Esc or its own button. Neither is in release builds.
- **When the screen unlocks:** the symbol changes to an open padlock and holds for 0.82 s.
  Then the activity is removed and normal content returns.
- **The notch on the lock screen:**
  - It must be visible on the lock screen. That means a window placed at the lock-screen
    shielding level and attached to the lock-screen Space. A normal window is hidden by the
    system there.
- **How attaching works** (shared by the notch window and the music panel,
  [06](06-lock-screen-music.md)). This was checked against the working old app:
  - **The window server's private Space functions return no usable result.** Creating a
    Space returns its ID. Setting the absolute level, showing Spaces, and adding windows to a
    Space return nothing: declare them as returning nothing. Whatever is left in the return
    register is not a status, so **never treat it as success or failure**. Treating a
    leftover non-zero value as an error is exactly why nothing showed on the lock screen.
  - **Create the Spaces once, at app launch**, not during the lock. Each gets its own
    absolute level and is shown right away:
    - level 400 for the music panel (its background and foreground windows);
    - level 401 for the notch window, so it sits above the panel.
  - **To attach a window:** order it front first (so it has a window number and is on
    screen). Then show its Space again, because the system can hide it after a lock or a
    display wake. Then add the window to the Space, removing it from all its other Spaces.
  - **To confirm,** read the window's Space membership back from the window server,
    including the system's own Spaces, and check that it contains the target Space.
    Membership can settle a little later. Check again after a short delay (≈ 0.25 s, a few
    times). If the read-back function is unavailable, assume it attached.
  - **Retry** the whole attach during the lock transition when the read-back says no. Never
    keep a window hidden only because a mutating call "failed".
  - **Re-attach after a display wake** or a screen change while locked, using the same
    steps.
  - The notch window shows the current content, for example the lock activity, the HUD
    while the volume changes, or other alerts.
- **Mirror** turns its camera off when the screen locks ([08](08-mirror.md)).

### Sounds
- **Play a sound on lock and unlock** (setting, default on).
  - Built-in lock and unlock sounds ship with the app. They are new assets, not the old ones.
  - The user may pick a **custom sound file** separately for lock and for unlock (any audio
    file the system can play), and reset to the built-in sound.
  - A missing or unplayable custom file falls back to the built-in sound silently.
- **Respect the system:** muted output means no sound. Sounds play at the system alert
  volume.

### Keeping the display awake
- *Keep display awake while the music panel shows* (setting, default on).
- While locked, with the music panel visible, the app holds a "display stays on" power
  assertion.
- Release the assertion as soon as the panel hides, the screen unlocks, or the setting is
  turned off.
- Explicit sleep and closing the lid must still work.

### Waking
- After the displays wake from sleep while locked, re-attach the lock-screen windows and
  re-check the lock state.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Lock screen activity | On | Lock and unlock activity in the notch |
| Lock and unlock sounds | On | |
| Custom lock sound / custom unlock sound | None | File chooser, with reset |
| Keep display awake | On | While the music panel is visible |
| Music panel | On (Pro) | See [06](06-lock-screen-music.md) |

## Edge cases
- **The lock happens with no broadcast** (some MDM or screensaver paths): the 2 s check
  catches it.
- **Unlock and lock again quickly:** cancel the pending unlock animation, so the states
  never overlap.
- **The window cannot be attached to the lock-screen Space at first:** retry during the
  lock transition and log the failure. Never show the panel on the normal desktop by
  mistake.
- **External displays while locked:** the notch and panel appear on the screen the shell is
  using ([01](01-notch-shell.md)).

## Acceptance checks
1. Pressing Ctrl-Cmd-Q shows a padlock in the notch on the lock screen. The lock sound plays
   if enabled.
2. Unlocking shows an open padlock for about 0.8 s, then the previous content returns, and
   the unlock sound plays.
3. With sounds off, lock and unlock are silent.
4. A custom unlock sound plays instead of the built-in one. Deleting the file restores the
   built-in sound.
5. With music playing and the screen locked, the display does not dim while the panel is
   visible. It dims normally when *keep display awake* is off.
6. Changing the volume while locked shows the HUD in the lock-screen notch.
