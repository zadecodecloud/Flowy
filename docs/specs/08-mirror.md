# 08 · Mirror

## Purpose
A camera mirror page in the notch, for checking yourself before a call. It has an optional
warm ring light and digital zoom. It never records. This feature is NotchFlow's own work;
its files are carried over in `Imported/`.

## Behaviour

### Where it lives
- **A page** ([02](02-content-engine.md#pages)), available while *Mirror* is on.
- **Reached by** a horizontal swipe from the other pages, or as the default page when it is
  the only one available.

### Layout
- **Expanded size:** at least 560 × 440 pt (base + 340 × base + 405 pt when that is larger).
  This gives a usable 16:10 preview. Top radius 24, bottom 25.
- **Spacing:** the page sits 20 pt inside the notch walls on a 4 pt grid, starting below the
  hardware notch band.
- **Header:** a camera symbol (13 pt semibold) and the "Mirror" title (12 pt).
- **Preview:** fills the remaining space, with rounded corners.
- **Controls row** under the preview:
  - ring light on/off;
  - a zoom slider, 1× to 2×;
  - flip on/off.

### Camera lifecycle
- The camera **starts only while the Mirror page is visible and expanded**.
- It **stops** when:
  - the user leaves the page;
  - the notch collapses or closes;
  - the screen locks (use the lock-screen feature's lock signal from
    [05](05-lock-screen.md); display sleep and session changes are only a fallback);
  - Mirror is turned off.
- **Permission:**
  - Not yet decided: asking happens on the first open.
  - Granted: start.
  - Denied or restricted: show a message and a button that opens the camera privacy pane in
    System Settings.
  - Retry starts whichever step failed: authorisation or the session.
- **Camera unavailable** (another app took it, or the system interrupted it): show an
  "unavailable" state, and resume when the camera frees up.
- **Stale callbacks** from a preview that has already closed are ignored, using a generation
  counter or similar.
- **Under tests**, the real camera must never be touched and no permission prompt may appear.

### Image
- **Flip** (setting, default **on**): a mirrored, selfie-style image. It is applied to the
  preview connection, with the automatic mirroring adjustment turned off.
- **Zoom:** digital, preview only. The image grows around its centre and is clipped by the
  preview frame. The value is clamped to 1–2×.
- **Ring light:** a bright warm rim around the preview that lights the face in a dark room.
  Default off each time.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Mirror | On | Makes the page available |
| Flip image | On | Mirrored preview |

## Edge cases
- **Swiping away and back quickly:** no flicker, and no second permission prompt.
- **Locking while the mirror shows:** the camera light goes off immediately.
- **A Mac with no camera:** the page shows "no camera" and offers nothing else.

## Acceptance checks
1. Swiping to Mirror turns the camera on and shows a mirrored preview at least 560 pt wide.
2. Swiping away, collapsing or locking turns the camera indicator off within ≈ 1 s.
3. Zoom at 2× doubles the preview around its centre. Nothing outside the frame shows.
4. The ring light makes a bright warm rim visible around the preview.
5. With the camera permission denied, the page explains this and opens the right System
   Settings pane.
6. The unit tests never open the camera.
