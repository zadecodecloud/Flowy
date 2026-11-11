# 01 · Notch shell

## Purpose
The notch shell is the shape at the top centre of one screen. It grows out of the hardware
notch (or floats as a pill on screens without one) to show content, and lets the user open,
close, dismiss and page through that content. What it shows is decided by the content engine
([02](02-content-engine.md)). How it looks is in [03](03-glass-appearance.md).

## Behaviour

### Placement
- **One overlay per chosen screen.** It is centred horizontally and anchored to the top
  edge, above the menu bar.
- **Visible everywhere.** It shows on every Space, including full-screen Spaces. It never
  appears in Mission Control or window cycling, and it does not take keyboard focus unless
  its own controls need it.
- **Clicks pass through outside the shape.** Only the visible shape is interactive.
- **Choosing the screen:**
  - *Main display* (default): the display with the menu bar.
  - *Built-in display.*
  - *A specific display*, remembered by its identifier and name. If that display is missing:
    - with *automatic switching* on (default), the shell falls back to the main display;
    - with it off, the shell shows nowhere until the display returns.
- **Display changes.** Connecting, disconnecting or rearranging displays re-evaluates the
  choice and re-measures the shape.

### Two shape modes
**Notch screens (the screen has a top safe-area inset).**
- The idle shape matches the hardware notch, so it is invisible against it.
- Width = notch width + ≈14 pt (scaled) + 2 pt + the user's width offset.
- Height = notch height + the user's height offset.
- If the notch size cannot be measured: width 190 pt × width-scale, height 26 pt.

**Screens without a notch ("island mode").**
- A floating pill just below the top edge.
- Base width (90 pt × width-scale + 2 pt + the user's width offset) × 0.85; height
  26 + 5 pt + the user's height offset. The pill sits ≈ 6 pt below the top edge.
- Corner radius: half the height when compact, 20 % of the height when expanded.
- Expanded content is 40 pt wider than on notch screens.
- With no content, the pill fades out after the transition delay and is hidden.

**Scaling.**
- scale = screen width ÷ 1440, minimum 0.35.
- width-scale = scale below 1; above 1 it grows more slowly: 1 + (scale − 1) × 0.35.
- Size changes animate with a quick spring (response ≈ 0.25 s, damping ≈ 0.85).

**Corner radii.** Compact: top = base height ÷ 3 − 4, bottom = base height ÷ 3. Expanded
content keeps the compact top radius unless it declares its own. The pages declare top 34 pt
(Media) or 24 pt (Tray, Mirror), and all use a 25 pt bottom radius
([03](03-glass-appearance.md)).

### Compact and expanded
- Each piece of content declares a **compact** size and optionally an **expanded** size.
  Compact usually adds small elements left and right of the notch. Expanded is a panel that
  hangs below it.
- **Opening (setting):** *Hover* (default), *Click* or *Press and hold*.
  - The hold time also serves as the hover delay: default 0.20 s.
  - A separate *tap to expand* switch (default on) allows click-to-open in every mode.
- **Closing (setting):** *Pointer leaves* (default) or *Click outside*. A click outside the
  shape always closes expanded content.
- **Hovering the idle notch** does not open anything, in any mode.
- **Clicking the idle notch** opens the default page: the first available of Media, Tray,
  Mirror ([02](02-content-engine.md#pages)).
- **Hover and press feedback.** The shape grows slightly while hovered or pressed: × 1.08 on
  notch screens, × 1.14 in island mode. It eases back in ≈ 0.12–0.25 s.
- **Hover haptic** (setting, default off): a light haptic tap when the pointer enters.
- **Attention pulse.** A short bounce, ≈ +30 pt wide and +10 pt tall, then back. Used when
  content wants to draw the eye without opening.

### Gestures
- **Vertical swipe (trackpad two-finger scroll or mouse drag) on the shape:**
  - *Up* by 60 pt or more, and mostly vertical, **dismisses** the current content. Mostly
    vertical means more than 1.25 × the horizontal movement on a trackpad and 1.15 × with a
    mouse drag. Dismissed content can be restored.
  - *Down* by 60 pt or more **restores** the most recently dismissed content.
  - While swiping, the shape follows the finger:
    - dismissing narrows a compact shape by 18 % of its width (28–44 pt), or shortens an
      expanded one by 16 % of its height (12–28 pt);
    - restoring adds up to 10 pt of height;
    - the content blurs up to 8 pt and fades up to 20 %;
    - corners round slightly more (+3 pt) in island mode.
  - Settings, all on by default: trackpad swipes, mouse drags, swipe to dismiss, swipe to
    restore.
- **Horizontal swipe between pages:**
  - Applies when a page is expanded and other pages are available.
  - A two-finger horizontal scroll locks to the horizontal axis after ≈ 12 pt when it is at
    least 1.5 × the vertical movement. It moves one page once the horizontal travel reaches
    60 pt. One page per gesture; momentum scrolling is ignored.
  - Page dots are always visible while an expanded page has siblings.

### Menus
- **Right-clicking the shape** opens a menu: check for updates, open settings, restart the
  app, quit.
- **Menu-bar icon** (setting, default on). Its menu shows the version and the same items.
- **Dock icon:** hidden by default (setting).

### Full screen
- *Hide content in full screen* (default on): no content shows on a screen whose active
  Space is full screen.
- *Hide the island in full screen* (default on): in island mode the pill disappears too.

### Window margin on screens without a notch
- Setting, default **off**; margin 17 pt.
- When the user drags a window to the top edge, the window is pushed down by the margin so it
  never sits under the pill.
- While dragging, a snap-preview outline appears: black 16 % fill, 3 pt white border at 60 %,
  soft shadow. It fades in over 0.14 s and out over 0.12 s.
- Needs the Accessibility permission. Until it is granted, the feature checks again every
  3 s and does nothing else.

### Size adjustment
- *Width offset* and *height offset* settings, default 0, nudge the shape.
- Changing either one shows a short "notch size" indicator for 2 s (setting, default on).

## States and transitions
- **Idle:** no content; the shape is at its base size.
- **Compact:** content shown around the notch.
- **Expanded:** a panel below the notch.
- Changing content always **hides the old content, waits 0.30 s, then shows the new**.
  Showing into an empty shell starts immediately.
- **Animation feel.**
  - Show and hide: spring, response 0.5 s, damping 0.70.
  - Expand: spring, response 0.5 s, damping 0.75.
  - Collapse: spring, response 0.5 s, default damping.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Screen | Main display | Main / built-in / specific display |
| Automatic display switching | On | Fall back to the main display when the chosen one is missing |
| Open with | Hover | Hover / click / press and hold |
| Tap to expand | On | A click opens content in every mode |
| Hold and hover delay | 0.20 s (0.20–0.60, step 0.01) | Time before hover or hold opens |
| Close with | Pointer leaves | Pointer leaves / click outside |
| Trackpad swipes | On | Vertical swipes on the trackpad |
| Mouse drags | On | Vertical drags with the mouse |
| Swipe to dismiss | On | Upward swipe dismisses |
| Swipe to restore | On | Downward swipe restores |
| Hover haptic | Off | Haptic tap on hover |
| Width offset / height offset | 0 / 0 (−5…+5 pt / −1…+1 pt, whole points) | Nudge the shape size |
| Size-change indicator | On, 2 s | Shown while adjusting the size |
| Hide content in full screen | On | |
| Hide the island in full screen | On | Island mode only |
| Window margin (no-notch screens) | Off, 17 pt | Push windows below the pill |
| Menu-bar icon | On | |
| Dock icon | Off | |

## Edge cases
- **Display unplugged while content is expanded:** move to the fallback screen, or hide.
  Nothing may stay on screen without an owner.
- **Two screens with notches:** only the chosen screen shows the shell.
- **The menu bar auto-hides:** the shape stays anchored to the top edge.
- **Swipes on scrollable content inside an expanded page** scroll that content. They do not
  dismiss or change page.
- **A trackpad gesture that starts vertical stays vertical**, and the same for horizontal.
  The axis locks after ≈ 12 pt.

## Out of scope
The HUD replacing the system volume and brightness indicators is covered in
[09](09-hud.md).

## Acceptance checks
1. On a MacBook with a notch and no content, the shape cannot be told apart from the
   hardware notch.
2. On an external display without a notch, the island is hidden while there is no content
   and appears as a pill when content arrives.
3. With *Hover* opening, resting the pointer on compact content for 0.2 s expands it.
   Moving the pointer away collapses it.
4. A click anywhere outside expanded content collapses it. The click still reaches the app
   underneath.
5. An upward two-finger swipe of at least 60 pt dismisses the content. A downward swipe
   brings it back.
6. With media playing, clicking the idle notch opens the Media page. A horizontal swipe
   moves to the Tray page, then to Mirror. The page dots show the position.
7. Choosing a specific display, then unplugging it, moves the shell to the main display when
   automatic switching is on, and hides it when that setting is off.
8. In a full-screen app, no content is shown while *Hide content in full screen* is on.
9. Right-clicking the shape shows the update, settings, restart and quit items.
10. Changing the width offset resizes the shape and briefly shows the size indicator.
