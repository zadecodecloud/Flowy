# 12 · Calendar

## Purpose
Show the next calendar event in the notch shortly before it starts, and while it runs.

## Behaviour

### Access
- **Calendar access:** full access to events is needed.
  - Settings shows the current permission and a button to request it.
  - When access is denied, a button opens the privacy pane.

### Which event
- **Fetch events** from now until *days to show* ahead (default 7) from the included
  calendars. *All calendars* applies when none are chosen.
- **Filter:**
  - drop events that have already ended;
  - drop all-day events unless *show all-day* is on (default on);
  - with *only events I created* on (default off), keep only events where the current user
    is the organiser. An event with no organiser counts as the user's own, unless its
    calendar is read-only (subscriptions, birthdays);
  - drop events the user dismissed in this session.
- **Sort** by start time. The **next event** is the first one.
- **Refresh** when the calendar store changes, and every 60 s.

### When the activity shows
- **The *Upcoming event* activity** (priority 9) shows while either is true:
  - the next event starts within *notice time* (default 15 min); or
  - it is running now.
- *Notice time* is a menu: *at start* (0: the event shows only once it is running), 5, 10,
  15 (default), 30 or 60 min.
- *Hide running events after* is a menu: *never* (0, default), 5, 10 or 15 min. It hides a
  running event once that many minutes have passed since it started. The next eligible
  event (within the notice time) then shows instead.
- *Hide when Focus is on* (default on): no calendar activity during Focus. Use the Focus
  state from the system-status feature ([10](10-system-status.md)); do not read Focus
  separately.
- An all-day event counts as running all day.
- **Compact:** a calendar symbol and the time, shown according to *time format*:
  - *exact* (default): for example 14:30. Follows the system's 12/24-hour setting. All-day
    events read "All day";
  - *relative*: "now", "in 12m" or "in 1h 5m";
  - *both*.
- **Expanded:**
  - title, time range and location;
  - a button to open the event in Calendar;
  - a button to dismiss it.
- **Privacy mode** (default off) replaces the title and location with a generic label.
- **Sound alert** (default off) plays a short system sound once per event when it enters the
  notice window. This includes at launch, if the event is already inside the window.

## Settings
| Setting | Default |
|---|---|
| Calendar activity | On |
| Calendars included | All |
| Days to show | 7 (fixed; not shown in Settings) |
| Notice time | 15 min |
| Show all-day events | On |
| Only events I created | Off |
| Time format | Exact |
| Hide running events after | 0 (never) |
| Hide when Focus is on | On |
| Privacy mode | Off |
| Sound alert | Off |

## Edge cases
- **An event moved or deleted while shown:** the next refresh updates or removes it.
- **Two events starting at the same time:** show the earlier one in sort order. The expanded
  view may list the second one.
- **Time zone or clock change:** refresh immediately.

## Acceptance checks
1. An event starting in 10 minutes shows the calendar activity with its start time.
2. With the relative format, it reads "in 10m" and counts down each minute.
3. Dismissing it hides it until the next launch.
4. Privacy mode hides the title.
5. With *Hide when Focus is on*, turning on Do Not Disturb removes it.
