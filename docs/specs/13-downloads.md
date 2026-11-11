# 13 · Downloads

## Purpose
Show download progress in the notch for files arriving in the user's Downloads folder, from
any browser.

## Behaviour

### Detecting downloads
- **Scan the Downloads folder** every 1 s while monitoring.
- **What counts as an in-flight download:**
  - **Browser temporary files:** Safari's download bundles, Chromium's partial files,
    Firefox's partial files and similar.
  - **Recently modified ordinary files that are growing.** Skip files not modified in the
    last 10 s.
- **Progress, in order of preference:**
  1. The exact progress fraction that browsers write as a file attribute on in-flight
     downloads.
  2. For Chromium-based browsers, the expected total size from the browser's download
     history database. Cache the lookup for 30 s. Read it only, never writing or locking.
     Browsers: Chrome (stable, Beta, Dev, Canary), Chromium, Brave (stable, Beta,
     Nightly), Edge (stable, Beta, Dev, Canary), Arc, Vivaldi, Opera, Opera GX and Yandex.
  3. Otherwise, a growth-based estimate that never goes backwards.
- **Completion:** a download is done when the temporary file becomes the final file, or when
  progress reaches 100 %.
- **Stalled:** a download with no growth for 2.5 s is considered inactive and is no longer
  shown.

### Activity
- **The *Downloads* activity** (priority 5) exists while at least one download is active.
- **Sizes:** compact base + 90 pt for *percent* and base + 70 pt for *circle* (island:
  + 90 pt and + 60 pt). Expanded base + 150 × base + 65 pt (island base + 230 × base +
  65 pt), top corner radius 24 pt and bottom 34 pt.
- **Compact:** a progress indicator on the right of the notch, by style:
  - *percent* (default): a number;
  - *circle*: a ring.
- **Expanded:**
  - file thumbnail or icon, name, size progress (for example 12.4 of 80 MB), and a bar;
  - with several downloads, the most recent one plus a count.
- **On completion:** briefly show a done state (a check), then remove the activity once
  nothing else is downloading.
- **Clicking a finished item** reveals it in Finder.

## Settings
| Setting | Default |
|---|---|
| Downloads activity | On |
| Progress style | Percent (percent / circle) |

## Edge cases
- **Very small files** that complete within one scan show nothing, or one brief done state.
  They never flicker.
- **The Downloads folder is redirected or missing:** monitoring stays off. It never crashes.
- **Huge folders:** the scan must stay cheap. Look only at recent and temporary files.

## Acceptance checks
1. Downloading a 100 MB file in Safari shows a rising percentage in the notch.
2. The same in Chrome shows accurate progress.
3. When it finishes, a done state appears briefly, then the activity goes away.
4. Pausing a download in the browser removes the activity after ≈ 2.5 s.
