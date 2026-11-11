# 14 · Screenshots and screen recording

## Purpose
- After a screenshot, show it in the notch with quick actions.
- While the screen is being recorded, show a recording activity, then the finished video.

**Both are off by default.**

## Screenshots

### Detection
- Watch the folder where the system saves screenshots: the user's screenshot location
  preference, or the Desktop.
- **Never change the system screenshot location.**
- A new screenshot file is picked up within ≈ 1 s. A manual rescan is possible.

### Optional: hide the system thumbnail
- *Disable the system floating thumbnail* (default off) switches off the system's own
  thumbnail preview, so there is no duplicate.
- Turning it off again restores the user's previous system value.

### Presentation
- **Fly-in:** a short animation flies a thumbnail from the screen centre into the notch on a
  curved path. It can finish early if the user interacts.
- **Alert:** the *Screenshot* alert shows for 4 s (setting). Size: base + 160 × base +
  105 pt (island base + 230 × base + 100 pt).
  - With *auto-hide* on (default), it closes after that time.
  - With auto-hide off, it stays until handled.
- **Expanded actions:**
  - **Drag out:** drag the thumbnail into any app or Finder.
  - **Copy:** the image goes to the clipboard.
  - **Show in Finder.**
  - **Edit:** opens the system markup editor.
  - **Delete:** moves the file to the Trash.
  - **Copy text:** on-device text recognition copies the text in the image to the
    clipboard.
- **Saving:** if the screenshot only exists on the clipboard and was not saved, it is
  written as PNG to the *save folder* (setting; default = system screenshot folder), with a
  unique name. This happens unless it was dropped, copied or deleted.

## Screen recording

### Detection
- Detect when a system screen recording starts and stops, using the system's
  screen-capture events. There is no public API, so implement independently.
- Track the elapsed time while recording.

### Activity
- **The *Screen recording* activity** (priority 10) while recording.
  - **Compact:** a red record dot and the elapsed time (*detailed*, the default style:
    base + 115 pt, island base + 105 pt), or the dot only (*compact* style: base + 60 pt,
    island base + 50 pt).
  - **Expanded:** elapsed time and a **stop** button that ends the system recording. Size:
    base + 130 × base + 60 pt (island base + 210 × base + 50 pt).
  - Outline: red at 30 %.
- **When the recording ends** and the file appears:
  - show a **result** alert with the video thumbnail and name, for 6 s. Same size as the
    screenshot alert;
  - actions: open, show in Finder, copy, drag out, delete (to the Trash);
  - videos are found in the *recording save folder* (setting; default = the system
    location).

## Settings
| Setting | Default |
|---|---|
| Screenshot alert | **Off** |
| Disable system thumbnail | Off |
| Screenshot alert duration | 4 s |
| Screenshot auto-hide | On |
| Screenshot save folder | System location |
| Screen-recording activity | **Off** |
| Recording style | Detailed (detailed / compact) |
| Recording save folder | System location |

## Edge cases
- **Several screenshots quickly:** each new one replaces the shown one. Older files stay on
  disk.
- **Screenshot permission or location folder unreadable:** show a hint in settings, nothing
  in the notch.
- **A recording made by a third-party app** (not the system tool): no activity is required.

## Acceptance checks
1. With the feature on, Cmd-Shift-4 flies a thumbnail into the notch and shows the actions.
2. Copy puts the image on the clipboard. Delete moves the file to the Trash.
3. Copy text on a screenshot of a paragraph copies that text.
4. Starting a system screen recording (Cmd-Shift-5) shows the red dot with a running time.
   Stop ends it, and the result appears with the thumbnail.
5. With the system-thumbnail option on, the system's corner thumbnail no longer appears.
   Turning the option off brings it back.
