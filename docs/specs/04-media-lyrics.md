# 04 · Media and lyrics

## Purpose
Show what is playing on the Mac, from any app, in the notch. The user can control playback
and pick the audio output there. The same media session also feeds the lock-screen music
panel ([06](06-lock-screen-music.md)), which also shows synced lyrics.

## Behaviour

### Reading the media session
- **Source.** Read the system-wide now-playing information:
  - title, artist, album and duration;
  - elapsed time, with the timestamp it was measured at, and the playback rate;
  - artwork image;
  - the source app's bundle identifier.
- **Third-party help.** macOS gives no public API for this. A permissively licensed
  third-party helper may be used (see [16](16-updates-licensing.md#third-party)); otherwise
  implement it independently.
- **Elapsed time** is extrapolated locally: last elapsed + (now − measured-at) × rate.
  Reported values more than 3 s away from the local estimate replace it. A timestamp more
  than an hour from now is treated as invalid.
- **Session-end grace.** When the session disappears, wait 0.55 s before treating it as
  ended. Players often drop the session briefly between tracks.
- **Source filter** (setting): *Any app* (default), *Apple Music*, *Spotify* or *YouTube
  Music*. Sessions from other apps are ignored. While a filtered app is quiet, the last valid
  matching track stays.

### Commands
- Play, pause, toggle, next, previous, seek, plus shuffle, repeat and volume where the app
  supports them.
- **Command order:**
  1. Send the command through the system media session.
  2. For Apple Music and Spotify, also use their scripting interface, which is more
     reliable.
  3. For the YouTube Music desktop app, use its local HTTP control API
     (`localhost:26538`): a 5 s request timeout and a 10 s resource timeout.
  4. As a last resort, send media-key events.
- **Refresh** after a command: 0.2 s later, or 0.8 s after a seek.
- **Favourite** (heart): supported for Apple Music and YouTube Music. Spotify has no
  scripting call for it, so the button is hidden or disabled there. The button shows the
  current state, read from the app.
- **Opening the source app.** Clicking the artwork or the title brings the source app
  forward and collapses the notch.

### Activity behaviour
- **Starts playing:** show the *Now playing* activity (priority 8, see
  [02](02-content-engine.md)), if Now Playing is enabled.
- **Paused:**
  - With *close when paused* on (default), the activity hides after the *close delay*:
    default 5 s, range 1–5 s.
  - If the panel is expanded when that time comes, the hide waits until it collapses.
  - With the setting off, the activity stays while paused.
- **Session ends:** hide the activity, again waiting for any expanded panel to collapse.
- **Playing again** cancels any pending hide.

### Compact view
- Width = base width + 70 pt (+65 pt in island mode).
- **Left:** the artwork, 22 pt (20 pt in island mode), corner radius 5.
- **Right:** a small animated **equalizer** in an 18 × 18 pt box: ≈ 2.2 pt bars up to 16 pt
  tall, coloured from the artwork palette. The bars move only while playing and settle flat
  when paused.
- Horizontal insets: 14 / 16 pt (7 / 9 pt in island mode), scaled.

### Expanded view (the Media page)
- **Size:** base + 190 × base + 160 pt; in island mode base + 260 × base + 150 pt.
- **Corners:** top radius 34, bottom 25. Side padding follows the page metrics
  ([03](03-glass-appearance.md)).
- **Header row** (60 pt tall, 15 pt spacing):
  - artwork, 60 pt, radius 10;
  - title (16 pt medium, white) above artist (14 pt, white at 68 %); both scroll
    horizontally when too long ([06](06-lock-screen-music.md#scrolling-titles));
  - an equalizer, 23 × 18 pt, on the right.
- **Progress bar:**
  - shows elapsed and remaining time, as mm:ss or h:mm:ss, with "--:--" when unknown;
  - can be dragged to scrub only when the duration is known; the seek is sent on release;
  - updates every 0.25 s while playing and every 30 s while paused.
- **Controls row:** favourite · previous · play/pause · next · output device. Buttons are
  38 pt, icons 18 pt. Favourite and output device can each be hidden in settings.
- **Fallback text:** missing title or artist shows "unknown track" or "unknown artist".
  With no session at all (debug preview only), it shows "nothing playing".

### Artwork palette
- Take the artwork's **average colour**.
- **Near-grey artwork** (saturation < 0.08): use neutral greys.
  - Base: brightness clamped to 0.7–0.92, alpha 0.72.
  - Highlight: 0.12 lighter, alpha 0.95.
- **Otherwise:**
  - Base: saturation × 1.12 clamped to 0.42–0.92; brightness × 1.04 clamped to 0.58–0.94;
    alpha 0.88.
  - Highlight: 74 % of that saturation (at least 0.22) and 0.12 brighter.
- **No artwork:** grey at 36 % (base) and 60 % (highlight).
- The palette colours the equalizer and accents.

### Track change
- **Artwork 3D flip** (setting, default on):
  - The artwork flips 180° over 0.45 s, ease-in-out.
  - The new image swaps in at the midpoint.
  - There is a short cooldown, so rapid skipping causes one flip.
  - Title, artist and progress update immediately, without waiting for the flip.

### Audio output
- The output button opens a list of the system's audio output devices, with the current one
  marked.
- Choosing one switches the system default output.
- The list refreshes each time it opens.

### Lyrics (used on the lock screen)
- **Providers, in order:**
  1. LRCLIB (`lrclib.net`): time-synced lyrics in LRC format, with plain text as fallback.
  2. lyrics.ovh: plain text.
- Look up by artist, title, album and duration. Requests time out after 30 s, and the whole
  lookup after 45 s.
- **Retries** after errors: wait 1.5 s, then 4 s, then 8 s; then give up and mark the track
  as failed. "Not found" is final for that track.
- **States:** idle, loading, loaded (synced or plain), instrumental, not found, failed. All
  are tied to the track, so a late answer for an old track is discarded.
  - **Instrumental:** the provider marks the track as having no lyrics on purpose. Show a
    waveform symbol and the word *Instrumental*, not the not-found message. Lyrics show only
    on the lock screen; the notch has no lyrics view.
- **Fetch only when needed.** Lyrics are fetched only while a lyrics view is on screen.
  Re-check when the track changes.
- **LRC parsing:** lines carry `[mm:ss.xx]` timestamps. A line may carry several timestamps.
  Lines are sorted by time.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Now Playing | On | Enables the activity and the Media page |
| Source filter | Any app | Any / Apple Music / Spotify / YouTube Music |
| Close when paused | On | Hide after the close delay while paused |
| Close delay | 5 s (1–5) | |
| Artwork 3D flip | On | Flip on track change |
| Favourite button | Shown | |
| Output device button | Shown | |

## Edge cases
- **The source app quits while playing:** the session ends after the grace period, then the
  activity hides.
- **Streams of unknown duration:** the progress bar is not draggable, and the times show
  "--:--" or elapsed only.
- **A favourite toggled in the app itself** is reflected the next time the state is read.
- **Media keys** used while the notch shows media: the system handles them as usual. The
  notch only reflects the result.
- **No network:** lyrics fail quietly. The rest of the media features keep working.

## Acceptance checks
1. Playing a song in Music shows artwork and the equalizer around the notch within ≈ 1 s.
2. Expanding shows the title, artist, a moving progress bar, and working
   previous / play-pause / next.
3. Dragging the progress bar seeks the song to that position.
4. Pausing hides the activity after 5 s. With *close when paused* off, it stays.
5. Pausing while expanded keeps the panel open. Collapsing then hides it, once the delay has
   passed.
6. With the source filter set to Spotify, playing in Music shows nothing. Playing in Spotify
   shows the track.
7. A track change flips the artwork once, and the title updates immediately.
8. The output button lists the speakers and headphones. Picking headphones moves the sound.
9. On the lock screen with lyrics on, a track with synced lyrics on LRCLIB shows timed
   lines.
