# 07 · File tray and drag-and-drop

## Purpose
Let the user drag files onto the notch to:
1. **AirDrop** them; or
2. park them in a **file tray**, a shelf in the notch to drag them out of later.

The tray is a page ([02](02-content-engine.md#pages)). New tray imports need **Pro**.

> **Known failure in the old app:** drops never reached the notch window, and neither did
> clicks, so drag-and-drop did not work at all. The new build must receive drags and drops
> on a window that sits above the menu bar. Prove this with a real Finder drag **first**,
> before building any UI on top of it.

## Behaviour

### Drag over the notch
- **A drag starts.** When the user starts dragging files anywhere (seen from the system drag
  pasteboard) and drag-and-drop is on, the notch shows the *drag* activity. It has system
  priority "drag in progress", so it outranks everything ([02](02-content-engine.md)).
- **Mode (setting):**
  - *AirDrop only*: one AirDrop zone.
  - *Tray only*: one tray zone.
  - *Combined* (default): two zones side by side, AirDrop on the left and tray on the right.
- **Availability decides what the zones are:**
  - AirDrop is off: tray only.
  - Tray is off, or there is no Pro: AirDrop only.
  - Both are off: no drag activity.
  - The zones shown and the drop destinations always match.
- **Hover feedback:** the zone under the pointer highlights.
- **The drag ends** (dropped anywhere, or cancelled): the drag activity is removed.

### AirDrop
- **Dropping on the AirDrop zone** opens the system AirDrop sharing picker with those files.
  The files are resolved first: aliases are followed, and an unreadable file aborts the
  batch with a short error alert.
- **While a transfer runs** and the AirDrop activity is on: show an *AirDrop transfer*
  activity (priority 7).
  - It shows a progress ring and the file count or name.
  - Expanded size: base + 120 × base + 70 pt.
  - It ends when the share finishes or fails.

### Tray: import
- **Dropping on the tray zone** imports the files into the tray folder in the app's
  Application Support area. The *usage mode* setting decides how:
  - **Copy** (default): copies the files, and the originals stay.
  - **Move originals:** moves the files into the tray folder.
- **All or nothing:**
  - Every file in the batch is checked to exist before anything is moved or copied.
  - If a step fails midway, the files already done are rolled back: copies are deleted and
    moved originals are moved back.
  - If even the rollback fails, show an error naming the tray folder.
- **Name clashes** in the tray folder get a unique suffix.
- **The same file dropped twice** (same resolved path) is ignored.
- **The tray persists.** Items survive relaunches. At launch, files in the tray folder that
  are no longer tracked are cleaned up.

### Tray: page (expanded)
- **Size:** base + 200 × base + 110 pt; top radius 24, bottom radius 25.
- **Empty:** a tray symbol (22 pt), "drop files here" (13 pt semibold) and a hint that
  sideways swipes switch pages (11 pt medium).
- **Items** sit in a horizontal, scrollable row. Each item is an 80 × 94 pt tile:
  - a thumbnail (≈ 55 × 47 pt) or file icon (42 pt);
  - the name below, in up to 2 lines, 10 pt medium;
  - a remove (×) button on each tile unless *hide remove button* is on.
- **Selecting:** a click toggles selection. Selected tiles are highlighted.
- **Dragging out:**
  - Dragging a tile drags it, or all selected tiles when it is part of the selection, to
    any app or Finder.
  - Items brought in with *move originals* leave the tray when dragged out, because the
    file moves.
  - Copies stay until removed.
- **Space bar** toggles Quick Look for the focused or selected items.
- **Removing:**
  - A copy is deleted from the tray folder.
  - A moved original is sent to the **Trash**, so it is recoverable, never deleted outright.
- **The tray activity** (priority 6) exists while the tray has items, or while the user has
  the tray page open.

### Pro gating
- Without Pro:
  - new imports are refused, and the tray zone is not offered;
  - files already in the tray are kept;
  - Settings offers to reveal the tray folder, so the user can still reach the files.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Drag and drop | On | Master switch for the drag activity |
| Drop mode | Combined | AirDrop / tray / combined |
| AirDrop | On | AirDrop zone and transfer activity |
| File tray | On | Tray zone and page (Pro) |
| Usage mode | Copy | Copy / move originals |
| Hide remove button | Off | |

## Edge cases
- **Dragging text or an image from a browser** (not files): no drag activity. Only drags
  that carry files show the zones.
- **Alerts during a drag:** while a file drag is over the notch or its zones are showing,
  alerts are held back. They queue and show after the drag ends or leaves. Losing the drop
  target in the middle of a drag is worse than a late alert.
- **Folders** are copied or moved as a whole.
- **Very large files:** the copy runs off the main thread with a progress indication, and
  the UI never freezes.
- **The tray folder is deleted externally:** items whose files are missing disappear at the
  next check.
- **A drag starts while the notch is expanded:** the drag activity takes over. After the
  drag, the previous content returns.

## Acceptance checks
1. Dragging a file from Finder over the notch shows the two zones, and the zone under the
   pointer highlights.
2. Dropping on AirDrop opens the AirDrop picker with that file.
3. Dropping on the tray (copy mode) adds a tile. The original stays in Finder.
4. Relaunching the app keeps the tile.
5. Dragging the tile to the desktop creates the file there.
6. In *move originals* mode, the file disappears from its folder on drop. Removing it from
   the tray puts it in the Trash.
7. Selecting two tiles and dragging one drags both.
8. Space bar opens Quick Look on the selected tile.
9. Without Pro, the tray zone is not offered, and existing items stay reachable from
   Settings.
