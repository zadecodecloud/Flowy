# 06 · Lock-screen music panel

## Purpose
While the Mac is locked and music plays, show a music widget on the lock screen. It can grow
into a full-screen, Apple-Music-style player with a moving album-colour background and
synced lyrics. This is a **Pro** feature ([16](16-updates-licensing.md)).

Much of this area is NotchFlow's own work and is carried over in `Imported/`: the layout
geometry, the ambient background, the expanded player and the scrolling text. This spec
defines the behaviour those files must keep.

## Behaviour

### When it shows
- **All of these must be true:**
  - the screen is locked ([05](05-lock-screen.md));
  - there is a media session ([04](04-media-lyrics.md));
  - *Music panel* is on;
  - Pro is active.
- **Layering:** the panel lives in two lock-screen windows. An edge-to-edge **background
  window** ignores the mouse. A **foreground window** holds the controls. Both are attached
  to the music panel's lock-screen Space (level 400, under the notch's 401), following "How
  attaching works" in [05](05-lock-screen.md).
- **Brief session gaps** while locked (between tracks) keep the panel. It hides only after
  5 s without a media session, counted from the moment the session ends.
- **The background window** is fully transparent while the panel is compact. It fades in
  with the immersive player.
- **Timing:** the window and panel fades take 0.25 s ease-in-out. The background fades with
  the expansion over 0.25 s ease-out. The artwork move takes 0.5 s. The palette cross-fade
  on a track change takes 0.9 s ease-in-out.

### Compact widget
- **Size and position:** a 340 × 180 pt card with a 28 pt corner radius. It is centred
  horizontally, with its centre 170 pt below the screen centre plus the *vertical offset*
  setting (−100 to +100 pt).
- **Content:**
  - artwork, 60 pt, radius 10, inset 18 pt;
  - title and artist that scroll when too long (see below);
  - a small equalizer;
  - a thin progress line with times;
  - previous / play-pause / next.
- **Card surface (setting):**
  - *Liquid Glass* (default, glass variant 8). A variant control (0–19) exists in debug
    builds only; release builds have no control.
  - *ultra-thin material*;
  - *ultra-thick material*.
- **Tint:** neutral (default) or accent from the artwork. The accent wash is 24 % on
  ultra-thin, 28 % on ultra-thick and 18 % on Liquid Glass. The thin white outline is 15 %,
  18 % and 12 % respectively.
- **Expanding:** clicking the artwork, or an expand control, opens the immersive player. The
  choice is remembered (default: compact).

### Immersive player (expanded)
- **Full screen.** The artwork animates from the card position to its large position.
- **Top-right controls:** two 44 pt round glass buttons, a lyrics toggle and a collapse
  button.
- **Responsive layout:**
  - **Lyrics off:** large centred artwork, up to 52 % of the screen height or 75 % of the
    width. The title, artist and controls sit below it, stacked when the screen is narrower
    than 900 pt.
  - **Lyrics on, landscape:**
    - left column: artwork with the player under it (174 pt tall);
    - right column: lyrics;
    - side padding ≈ 10.8 % of the width (≤ 180 pt);
    - column gap ≈ 9.6 % of the width (≤ 160 pt).
  - **Lyrics on, portrait** (width < 0.9 × height): artwork and player side by side at the
    top, lyrics below.
  - **Insets:** top ≈ 6.5 % of the height (70–96 pt), bottom ≈ 6.4 % (18–56 pt).
  - The exact geometry is in the imported layout file and its tests.
- **Lyrics column:**
  - Lyrics are loaded via [04](04-media-lyrics.md#lyrics-used-on-the-lock-screen).
  - **Font:** bold, ≈ 2.8 % of the screen width, 32–58 pt (26 pt minimum in portrait).
  - **Synced lines:**
    - the current line is white at 91 % with a faint glow;
    - the current line sits at 37 % of the column height, not the centre;
    - line opacity: the current or hovered line 100 %, the lines next to it 55 %, the rest
      35 %;
    - other lines blur by 0.65 pt per line of distance (max 2 pt) and are scaled to 97.5 %;
    - the view scrolls with a spring (response 0.5, damping 0.9) to keep the current line
      at that position;
    - scrolling by hand stops the follow; it resumes 6 s after the scrolling stops. While
      scrolling, lines show at 78 % without blur;
    - an empty line shows a pulsing ellipsis at 72 %. It pulses only while it is the
      current line and the music plays;
    - clicking a line seeks to its time.
  - **Plain lyrics** are a static, scrollable text block at the same font size (bold, white
    91 %), with the same top and bottom edge fade. Nothing is highlighted, and clicking does
    nothing.
  - **Instrumental tracks** show a waveform symbol and the word *Instrumental*
    ([04](04-media-lyrics.md)).
  - **Other states:** a small spinner while loading, and centred messages for "not found"
    and "failed", with a retry on failure.
  - **Accessibility:** with Increase Contrast or Reduce Motion, drop the blur, scale and
    glow, and scroll without animation. With Increase Contrast, other lines show at 78 %.

### Ambient background
- **Style (setting):** *animated artwork* (default), *static artwork* or *black*.
- **Animated:**
  - **Colours:**
    - Sample a **3 × 3 grid** of the artwork, giving nine region colours.
    - Tone-match each one the way Apple Music does: keep its hue, lift saturation × 1.15,
      and map brightness b to 0.06 + 0.94 b.
  - **Motion:**
    - Ten large, soft colour fields drift on independent slow orbits, each taking the
      colour of the cover region it maps to.
    - The overall pace is 0.65 of the base drift rate, kept deliberately slow.
    - No hard edges or creases. Fields overlap and blend.
  - **Timing:** driven by a main-run-loop timer. A visibility-based animation schedule
    pauses on the lock screen because the system reports the window as hidden.
- **Static:** a blurred, darkened full-screen artwork.
- **Black:** solid black.
- **Track changes** cross-fade the palette. They never flash.

### Scrolling titles
- A title or artist line that does not fit **scrolls horizontally**, the way Music and
  Spotify do.
  - It rests for 1.6 s, then moves left at 30 pt/s.
  - A copy follows 40 pt behind, so the loop is seamless, then it rests again.
  - The edges fade softly: 4 % on the left, 8 % on the right.
- **Text that fits** never moves.
- **Reduce Motion:** no scrolling; truncate with an ellipsis.
- **A new track** restarts the cycle.
- **Timing:** driven by its own run-loop timer, for the same lock-screen reason as above.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Music panel | On | Pro only |
| Card surface | Liquid Glass (variant 8) | Liquid Glass / ultra-thin / ultra-thick |
| Card tint | Neutral | Neutral / accent |
| Vertical offset | 0 pt (−100…100) | Moves the compact card |
| Background | Animated artwork | Animated / static / black |
| Lyrics | On | Shows the lyrics column in the immersive player |
| Immersive player remembered | Compact | Last state the user chose |

## Edge cases
- **No artwork:** use neutral grey fields and a placeholder note symbol.
- **Very small screens** (height < 620 pt): tighter gaps (12 pt).
- **The session ends while expanded:** wait out the grace period, then fade out both windows.
- **Unlocking while expanded:** both windows fade out with the unlock.
- **Without Pro:** nothing shows, and Settings explains that the panel is a Pro feature.

## Acceptance checks
1. Lock the Mac while a song plays. The glass card appears below the centre, with artwork,
   title and controls that work.
2. A long title scrolls after a short rest and loops without a jump. A short title stays
   still.
3. Expanding shows the full-screen player. The background drifts slowly in colours taken
   from different parts of the cover.
4. With lyrics on and a song that has synced lyrics, the current line is bright and sits about
   a third of the way down the column, and clicking another line seeks to it.
5. Turning lyrics off re-centres the large artwork.
6. *Vertical offset* +100 moves the card 100 pt down.
7. With Reduce Motion on, nothing scrolls or drifts. The titles truncate.
8. The background moves smoothly for minutes on the lock screen without pausing.
