# NotchFlow test session, 2026-11-10

Build: the `notch` repo working tree (not committed), Debug, ad-hoc signed, run from a scratch
DerivedData. Mac with a notch, macOS 27.2. Unit tests: 368 pass, 6 skipped, 0 fail.

Result key: **Pass**, **Fail**, **Skip** (with the reason).

## Findings to act on

| # | Severity | Finding | Where |
|---|---|---|---|
| 1 | High | Screenshots go to a hidden folder. The system screenshot location is `~/Library/Caches/com.Jackson.DynamicNotch/RawScreenshots` (left by the upstream app), but NotchFlow watches `~/Library/Caches/app.notchflow.mac/RawScreenshots`. A ⌘⇧3 screenshot lands in the hidden folder and NotchFlow never sees it or moves it to the Desktop. The folder is empty right now. | `defaults read com.apple.screencapture location`; `ScreenshotMonitorService.rawStagingDirectoryURL()` |
| 2 | Medium | Closing Mirror (✕ button) only collapses it. The compact "📷 Mirror" activity stays until the app restarts and hides lower-priority activities: a download did not show while it was there. The camera does turn off. notchflow-clean treats Mirror as a passive page that leaves on collapse. | `NotchEventCoordinator.closeMirror()` |
| 3 | Low | After a click on notch content, the notch panel keeps keyboard focus while another app is in front, until the user clicks elsewhere. Keystrokes in that moment go to NotchFlow. | `OverlayPanelWindow` (`isKeyWindow` always true) |
| 4 | Low (tests) | `ChromiumDownloadMetadataReaderTests.testFolderFileDownloadMonitorCalculatesExactProgressUsingChromiumMetadata` calls `fulfill()` more than once and crashed the test host twice today (16:00, 16:28). The suite still reports success. | `ChromiumDownloadMetadataReaderTests.swift:122` |
| 5 | Info | The Debug settings section (manual triggers for every activity) needs a developer licence; without it most activities cannot be triggered by hand. | `LicenseStore.hasDeveloperAccess` |
| 6 | Info | After a relaunch, the Music activity sometimes appeared only after about a minute while Spotify was playing; the system's now-playing data still showed elapsed time 0. | Not investigated |

## Fixed after the session

- **Finding 1, screenshots.** `ScreenshotMonitorService.stagingDirectory(systemLocation:ownDefault:)`
  now reads from the folder macOS really saves into when it is a leftover `RawScreenshots`
  staging folder. On start, files stuck there are moved to the Desktop. Monitoring now also
  runs with the screenshot and recording features off while such a folder is in use; then new
  screenshots are only moved to the Desktop, with no notch preview. The system setting is not
  changed. Checked on the Mac: a stuck screenshot moved to the Desktop at launch, and a new one
  moved within about 2 s. Tests: `ScreenshotStagingDirectoryTests`.
- **Finding 2, Mirror.** Mirror is now a passive page, as in notchflow-clean: when it collapses
  (✕, click outside, pointer leaves) its activity is removed and the notch goes back to the
  best other content. Checked on the Mac: after ✕ the notch went back to the hotspot activity
  and the camera turned off.
- Unit tests after the fixes: 371 pass. One run hit a flaky download-monitor test and two
  isolated reruns failed to load the test bundle (infrastructure); the full rerun passed.

## Results

### Notch shell
| Check | Result | Notes |
|---|---|---|
| Hover over the idle notch does not open | Pass | |
| Click on the idle notch opens the default page | Pass | Opened Music |
| Click on content expands; outside click collapses | Pass | |
| Hover over content expands (hover mode) | Pass | |
| Hover scale × 1.08 | Pass | Seen on the Files compact form |
| Right-click menu: pages, update, settings, restart, quit | Pass | Vietnamese labels; Open Music / Files / Mirror work |
| Page swipe (two-finger horizontal) | Skip | Cannot send trackpad scrolls from automation |
| Glass: black to 44 %, clear from 86 %, rim, shadow | Pass | |
| Content clipped to the outline, shared margins | Pass | Music, Files |

### Features
| Feature | Result | Notes |
|---|---|---|
| Music: compact, expanded, live music bars | Pass | Bars follow the audio tap ("follow live audio" in the log) |
| File tray: real Finder drag, AirDrop/Tray zones, drop, tile remove | Pass | Copy mode; original stays |
| Mirror: camera preview, zoom, ring light button, close | Pass / **Fail** | Works; see finding 2 |
| AirPods (detailed): layout below the camera band | Pass | Battery ring 92 % |
| Personal Hotspot activity | Pass | Link symbol in the left wing |
| Volume HUD | Pass | Triggered by a volume change; volume restored to 81 |
| Downloads: compact %, expanded name, %, speed; ends cleanly | Pass | Simulated `.crdownload` in Downloads, removed after |
| Onboarding: 4 steps, Next/Back/Skip/Done | Pass | Tested earlier today |
| Settings window opens from the notch menu | Pass | |
| Screenshots | **Fail** (setup) | See finding 1 |
| External drive alert | Skip | Disk images are ignored on purpose; needs a real USB drive |
| Battery (charger, low, full) | Skip | Needs a power change or the Debug triggers |
| VPN, no internet | Skip | Needs a network change or the Debug triggers |
| Focus | Skip | Would change a system setting |
| Timer, Calendar | Skip | Needs a timer or an upcoming event |
| Lock screen and its music panel | Skip | Locking needs your password to unlock |
| Brightness and keyboard HUD | Skip | Automation cannot send those keys |
| AirDrop transfer | Skip | Needs a real transfer |

## Test data cleaned up
- `notch-drag-test.txt` stays in the scratchpad; its tray copy was removed.
- `~/Downloads/nf-test.zip.crdownload` was deleted after the test.
- The test disk image `NFTest` was detached.
- System volume was set back to 81.
