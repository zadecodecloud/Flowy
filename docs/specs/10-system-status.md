# 10 · System status

## Purpose
Short notch notices and activities for the Mac's own state:
- battery and charging;
- Focus;
- network: no internet, personal hotspot, VPN;
- Bluetooth audio devices;
- external drives.

Each notice can be turned off, and alert durations can be set.

All alert durations below are multiplied by the global alert duration scale
([02](02-content-engine.md)). Duration settings range from 1 to 5 s, in 1 s steps, unless
stated otherwise.

## Battery

### Triggers
Compare the previous reading with the new one.
- **Charger connected:** the power source changes from battery to AC.
- **Low battery:** the level drops from above the low threshold to at or below it.
  - Threshold default 20 %, range 5–50 %.
- **Full battery:** the level rises from below the full threshold to at or above it.
  - Threshold default 100 %, range 50–100 %.

### Alerts
| Alert | Default | Shows |
|---|---|---|
| Charger | On, 4 s | Charging bolt and the battery level |
| Low battery | On, 4 s | Red battery and the level, with a note to charge, or to turn on Low Power Mode if it is off |
| Full battery | On, 4 s | Green battery and "fully charged", with a short sentence |

- **None of the battery alerts expand.**
- **Style** for the low and full alerts: *standard* (default) or *compact*.
  - *Standard* is a taller alert: base + 130 × base + 75 pt (island base + 230 × base +
    60 pt), top corner radius 22 pt and bottom 40 pt. On the left: the title with the
    coloured level beside it, and the note below in grey (two lines at most). On the right:
    a large battery graphic, ≈ 75 × 45 pt. For a low battery it is red, with a segment that
    pulses slowly (1 s in, 1 s out). With Low Power Mode on it is yellow and still. For a
    full battery it is green.
  - *Compact* stays in the wings: base + 180 pt wide (island base + 170 pt). The title is on
    the left. The coloured level and a small battery glyph, filled to the level, are on the
    right.
- **The charger alert** is always wing-sized: base + 180 pt (island base + 170 pt).
- **Outline colour:** the alert colour at 30 %. That is red for low, yellow with Low Power
  Mode on, and green for full and charging.
- **When several triggers fire in one reading,** show one alert: low or full wins over the
  charger.
- **Sounds:**
  - *Low battery sound*, default on, plays ≈ 0.4 s after the alert. It is a new asset.
  - *Full battery sound*, default on, plays ≈ 0.5 s after the alert, using a built-in
    system sound.
- **Low Power Mode** changes are tracked, so the low-battery text is correct.

## Focus

### Detection
- **Sources:** there is no public API, so implement independently. Use all three of these:
  1. the system's distributed Focus on/off broadcasts;
  2. the Focus daemon's log messages, plus a look-back through the recent log at launch:
     the last 5 minutes, then the last hour, then the last 24 hours, stopping at the first
     window that has a Focus message;
  3. the Focus state file the system writes when a Focus starts or ends.
  - The state file is protected by Full Disk Access. When it can be read it is
    authoritative and wins. Watch it for changes, with a 2 s poll as a fallback.
  - Without access, sources 1 and 2 fill in on a best-effort basis. On macOS 26 the off
    signal is often missing there, and the mode is often unknown.
  - Settings shows a warning with a button to the Full Disk Access pane when access is
    missing.
- **At launch,** a Focus that is already on shows its activity (when auto-hide is off), but
  no *Focus on* alert.
- **Known modes:** Do Not Disturb, Work, Personal, Sleep, Driving, Fitness, Gaming,
  Mindfulness, Reading, Reduce Interruptions, custom and unknown. Each has its own symbol
  and colour, matching the system.

### Behaviour
- **Focus turns on:**
  - With *auto-hide* on (default), show a *Focus on* **alert** for 3 s (setting). It shows
    only once per mode change.
  - With auto-hide off, show a persistent *Focus* **activity** (priority 1) until Focus
    turns off.
- **Focus turns off:** remove the activity, cut short any *Focus on* alert, and show a
  *Focus off* alert for 3 s (setting, default on).
- **Appearance:** *icons only* (default) or *standard* (symbol plus mode name and on/off
  text).
- **Expanding:** the Focus content is expandable and shows the mode name and state.
- **Focus activity setting off:** no Focus content at all, alerts included.
- **Click to close** (setting, default on): applies only when the click would not expand
  the Focus content (click-to-expand is off, or it is already expanded). The click plays a
  short squeeze-and-stretch close animation, opens the system's Focus settings, and removes
  the activity. It stays away until the Focus mode changes.
  - The squeeze narrows the shape by ≈ 20 % of its width (at least 20 pt) and adds
    ≈ 20 % height (at least 40 pt) for ≈ 0.1 s, then springs back over ≈ 0.4 s.

## Network

### No internet
- Watch the system network path.
- When it becomes unsatisfied, show a *No internet* alert (setting, default on) that stays
  until dismissed: an infinite duration.
  - The path must stay unsatisfied for 2 s first, so a short drop shows nothing.
  - Only a change from online to offline counts. A Mac that starts offline shows no alert
    until it has been online once.
- The alert has a dismiss button and a button that opens the network settings.
- It hides automatically when the connection returns.

### Personal hotspot
- **While the Mac uses an iPhone's personal hotspot:** a *Hotspot* activity (priority 2,
  setting default on).
- **Detection:** the path is satisfied over Wi-Fi, and either:
  - the system reports the current network as the last tethered device the Mac joined, with
    the same name; or
  - the path is marked expensive **and** not constrained (Low Data Mode alone is not a
    hotspot).
- **The phone's battery** has no public source. The old app used a private part of the
  system's sharing framework that browses nearby Instant Hotspot devices. Whether to use a
  private API is the owner's decision. Until then, *battery* falls back to the minimal look.
- **Appearance:**
  - *minimal* (default): the hotspot symbol;
  - *detailed*: symbol and network name;
  - *battery*: the phone's battery percentage, when it can be read.

### VPN
- **While a VPN is connected:** a *VPN* activity (priority 3, setting default on). It is
  expandable.
  - **Compact:** a shield symbol, and the connection timer if *show timer* is on (default).
  - **Expanded:** the VPN name, "connected" with the elapsed time, and the public IP and
    country flag when *show detail* is on (default off).
- **Location lookup,** in order until one answers:
  1. `api.country.is`
  2. `ipapi.co/json`
  3. `ipwho.is`
- **Alerts:**
  - *VPN connected* (setting on, 5 s);
  - *VPN disconnected* (setting on, 5 s).
- **macOS System Settings open on its VPN page** (not NotchFlow's own settings): remove the
  VPN activity and skip VPN alerts while the user is looking at that page. Restore them when
  they leave it.
  - "Looking at it" means System Settings is running and not hidden, and has a window that
    is not minimised and whose title contains "VPN".
  - Check on app launch, quit, activate, deactivate, hide and unhide events, and poll every
    0.5 s while System Settings runs.
  - Reading window titles needs the Accessibility permission. Without it, never suppress.
- **Disconnects** get a 1.5 s grace, so a quick reconnect shows no alerts.

## Bluetooth audio devices
- **When headphones, earbuds or a speaker connects:** a *connected* alert (setting on, 5 s).
  - Shows the device type symbol (AirPods, AirPods Pro, AirPods Max, Beats, generic
    headphones, speaker) and the name, scrolling when long.
  - Shows the battery levels where they can be read: left, right and case for earbuds;
    one level otherwise.
- **Appearance:** *compact* (default: symbol and level) or *detailed* (name and levels).
- **Battery indicator:** *percent* (default) or *ring*. A coloured battery outline is
  optional (default off).
- **Battery reading:**
  - Use the system's Bluetooth battery information where available.
  - For Apple earbuds, read the battery from their Bluetooth LE advertisements.
  - Never block the UI while reading.
  - Show the alert at once, and update the levels in place as they arrive.
- **Devices already connected at launch** get no alert.

## External drives
- **When an external or removable volume mounts:** an alert (setting on, 8 s; range 1–10 s)
  with the drive name, its capacity, and a drive symbol.
- **When it is ejected:** an alert saying it is safe to disconnect (setting *show ejected*,
  default on).
- **Clicking the mount alert** opens the volume itself in Finder: a window of its root, not
  a selection in its parent.
- System, hidden and disk-image volumes are ignored.

## Settings summary
| Setting | Default |
|---|---|
| Charger alert / duration | On / 4 s |
| Low battery alert / duration / threshold / style / sound | On / 4 s / 20 % / standard / on |
| Full battery alert / duration / threshold / style / sound | On / 4 s / 100 % / standard / on |
| Focus activity | On |
| Focus auto-hide (alert instead of activity) / duration | On / 3 s |
| Focus off alert / duration | On / 3 s |
| Focus appearance | Icons only |
| Click Focus to close | On |
| No internet alert | On |
| Hotspot activity / appearance | On / minimal |
| VPN activity / show timer / show detail | On / on / off |
| VPN connected alert / duration | On / 5 s |
| VPN disconnected alert / duration | On / 5 s |
| Bluetooth alert / duration / appearance / indicator / coloured outline | On / 5 s / compact / percent / off |
| External drive alerts / duration / show ejected | On / 8 s / on |

## Edge cases
- **Battery hovering around a threshold:** an alert fires only on crossing it, never
  repeatedly while the level stays there. After a low alert, the level must climb 2 points
  above the threshold (or the charger must connect above it) before it can fire again. The
  full alert re-arms 2 points below its threshold.
- **Desktop Macs without a battery:** no battery alerts at all.
- **Two Bluetooth devices connecting at once:** one alert per device, queued by the engine.
- **The VPN reconnecting within a second:** no burst of alerts. The activity simply stays.
- **Location services offline:** the VPN detail shows only what is known. It never shows an
  error in the notch.

## Acceptance checks
1. Plugging in the charger shows the charging alert with the level for 4 s.
2. With the low threshold at 30 %, draining from 31 % to 30 % shows the low-battery alert
   once.
3. Turning on Do Not Disturb shows a 3 s *Focus on* alert. With auto-hide off, a moon stays
   in the notch until DND is turned off, and then *Focus off* shows.
4. Turning Wi-Fi off shows the no-internet alert, which stays until dismissed or until the
   connection returns.
5. Connecting a VPN shows the shield with a running timer. Expanding shows the name and the
   time.
6. Connecting AirPods shows their name and the left, right and case battery levels.
7. Mounting a USB drive shows its name and capacity for 8 s. Ejecting it shows "safe to
   disconnect".
