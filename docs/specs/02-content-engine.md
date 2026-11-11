# 02 · Content engine

## Purpose
Many features want the notch at once: music, a timer, a VPN connecting, a charger plugged
in. The engine decides what shows, in which order, for how long, and what comes back
afterwards. It knows nothing about any one feature. Features hand it content items.

## Behaviour

### Two kinds of content
1. **Activities.** They are long-lived and stay until their feature removes them, for
   example "music is playing", "timer running" or "VPN connected". Many activities can exist
   at once in a **stack ordered by priority**. Only the top one is visible.
2. **Alerts.** They are short and each has a duration, for example "charger connected",
   "Bluetooth headphones connected" or a volume change. Only one alert shows at a time. While
   it shows, the visible activity is **suspended** and returns when the alert ends.

### What every content item declares
- A unique identity, plus an optional *group*: a new item in the same group replaces the old
  one in the stack.
- A priority. Higher wins.
- Whether it can expand, and whether a click expands it.
- Whether it is **restorable** after being dismissed (default yes).
- An optional *open* action, for example bringing the related app forward.
- An outline colour, defaulting to white at 20 % opacity.
- Its compact and expanded sizes and corner radii, and views for both states.

### Showing and updating
- **Showing an activity** puts it into the stack, replacing any item of the same group, and
  re-sorts the stack. If it becomes the top item, the notch transitions to it.
- **Updating content that is already visible** (same identity) changes it in place with a
  soft content animation. There is no hide-and-show transition.
- **Showing an alert:**
  - If the same alert is already visible, its content is updated and its timer restarts.
  - If it is waiting in the queue, the queued copy is replaced.
  - Otherwise the current content hides, the alert shows, and its timer starts.
- **Removing an activity** takes it out of the stack. If it was visible, the next-best
  activity is shown, or the notch goes idle.
- **Hide everything** clears the queue and the visible content (activity and alert). The
  stack and the dismissed list are kept, so the best activity can come back afterwards.

### Order and pacing
- Requests are queued and handled one at a time.
- Each change is **hide → wait 0.30 s → show**. When the notch is empty, the show happens at
  once.
- Successive queued changes are spaced 0.30 s apart.
- Requests that arrive during a transition wait for it to finish. They are never dropped.

### Alert timing
- Each alert's duration is multiplied by a global **alert duration scale** (default 1.0).
  Durations are in seconds; *infinite* means it stays until removed.
- The timer **pauses while content is expanded** and starts again from the full duration
  when it collapses.
- When an alert ends, the best activity in the stack comes back.

### Dismiss and restore
- **Dismissing** (an upward swipe, or a feature asking):
  - An *alert* is hidden. If it is restorable, it is remembered with its duration.
  - A *restorable activity* is hidden but stays in the stack, marked as dismissed. The
    next-best activity shows.
  - A *non-restorable activity* is removed.
- **Restoring** (a downward swipe) brings back the most recently dismissed item first. That
  can be an alert (shown again with its duration) or an activity. Earlier dismissed
  activities come back one per restore, most recent first.
- Showing an activity again clears its dismissed mark.

### Expanding and collapsing
- A click on compact content expands it when it can expand and *click expands* is set.
  Expanding stops any running alert timer.
- When content cannot expand, a click runs its *open* action, if it has one. For an alert,
  the open action also ends the alert.
- **Collapsing** (a click outside or the pointer leaving) is a hide → show transition back to
  the compact form, with the same 0.30 s gap. This short blink is the intended behaviour. A
  collapsed alert restarts its timer.

### Priorities
| Activity | Default priority |
|---|---|
| Focus mode | 1 |
| Personal hotspot | 2 |
| VPN | 3 |
| Timer | 4 |
| Downloads | 5 |
| File tray holds files | 6 |
| AirDrop transfer | 7 |
| Now playing | 8 |
| Upcoming calendar event | 9 |
| Screen recording | 10 |

- The user can set each of these from 0 to 20 in *Settings → Activity priorities*, with a
  per-row reset. Ties are broken by a stable order based on identity.
- These system items always outrank user priorities, in rising order:
  1. a drag in progress over the notch;
  2. a software update notice;
  3. the lock screen;
  4. onboarding;
  5. quick timer setup.
- Items with no priority use 0.

### Pages
- **Media, Tray and Mirror are pages**, which are activities the user can choose between.
- **Availability:**
  - Media is available while there is a media session and Now Playing is on.
  - Tray is available with Pro, with drag-and-drop on and the tray on.
  - Mirror is available while Mirror is on.
- The available pages, in order **Media → Tray → Mirror**, form the sequence for horizontal
  swipes and the dots ([01](01-notch-shell.md)).
- **Choosing a page** shows it expanded. When the top of the stack is a page, the chosen page
  wins over page priorities. A non-page item with a higher priority still wins.
- **Leaving Mirror** turns the camera off. So do closing the notch and locking the screen.
- **The idle-click default page** is the first available page.

### Hiding presentation
- Some situations hide all content but keep the stack, and restore it afterwards.
- Example: *hide content in full screen*.
- The shape animates to idle and back. Nothing is lost.

### Outline
- The visible content's outline colour is shown around the shape when outlines are on
  ([03](03-glass-appearance.md)).
- When the notch empties, the outline stays 0.31 s longer, so it fades with the shape rather
  than vanishing first.

## Edge cases
- **The same activity is shown twice quickly:** one transition only, with the latest content.
- **An activity is removed while an alert suspends it:** it does not come back when the alert
  ends.
- **An alert arrives while an activity is expanded:** the activity collapses, is suspended,
  and the alert shows.
- **The user changes a priority while two activities are active:** the new order applies at
  once and the visible item may change.
- **A restore with nothing dismissed** does nothing.

## Acceptance checks
1. With music playing (priority 8), starting a timer (priority 4) keeps music visible. After
   the timer's priority is raised to 9, the timer shows.
2. Plugging in a charger while music shows: music hides, the charger alert shows for its
   duration, then music comes back.
3. Plugging and unplugging repeatedly within a second produces one alert that updates. It
   never shows a queue of alerts.
4. An alert arriving while music is expanded collapses music and shows the alert at once.
   An alert that is itself expanded keeps its timer paused until the user collapses it.
5. Dismissing music with a swipe shows the next activity. A downward swipe brings music back.
6. Each visible change is a hide, a gap of about 0.3 s, and a show. Nothing overlaps.
7. With *hide content in full screen* on, entering full screen empties the notch. Leaving
   full screen restores the same content.
