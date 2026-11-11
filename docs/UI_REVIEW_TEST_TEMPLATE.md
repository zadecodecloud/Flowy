# NotchFlow UI review and test template

Date: 2026-11-10. Status: **review draft, nothing merged, no code changed.**

Scope: the current NotchFlow UI in this repo (`notch`, the old DynamicNotch-based app with
the `NotchFlow/Features/Notch` layout) against the new build in `notchflow-clean` (spec-driven
shell, `Shell/`, `Engine/`, `Surface/`). The question is what must be tested before the
old UI's notch layout and feature set go into the real code.

Reading used: the notch layout and features (file tray with drag and drop, music, mirror,
headphones, network, the rest) come from this repo and are meant to replace the notch layout
in `notchflow-clean`. If the intent is different, tell me and I will redo sections 1 and 2.

---

## 0. Blockers before any merge

1. **Clean-room rule.** The old app is a fork of DynamicNotch (GPL-3.0). `docs/HANDOFF.md` §3
   says the build side may read only `docs/specs/`, `Imported/`, and public docs. Copying any
   file from `NotchFlow/Features/Notch`, `Core/NotchEngine`, or `Application/` into
   `notchflow-clean` breaks that rule and the closed-source plan. Allowed path: write or
   update a spec, then implement it from the spec. Any direct port needs owner and lawyer
   sign-off first. Run `scripts/spec-leak-check.py` on the result.

2. **Drag and drop regressed in this UI.** The memory note `notchflow-dragdrop-investigation`
   records that the old notch window gets no drag callbacks and no clicks at the notch on
   macOS 27.2. The `notchflow-clean` handoff says a real Finder drag onto the notch works
   there, because its panel is built differently (`ShellOverlayPanel`, pointer-driven
   `ignoresMouseEvents`, `DropLandingView` registered for file URLs). Porting the old
   `NotchHostingView` and overlay stack would bring the bug back. Gate: tests T-DRAG-01 to
   T-DRAG-10 must pass with a **real Finder drag**, not a synthetic one.

3. **Clicks at the notch.** Same root cause as the drag bug. Old: clicks at the notch never
   reached the app (only a global monitor saw them). Clean: `Input/NotchClickTap.swift`.
   Gate: T-SHELL-02 and T-DRAG-09.

4. **Dirty working trees.** `notch` has about 780 uncommitted entries (the `DynamicNotch` to
   `NotchFlow` rename is staged, and 54 icon assets are deleted). `notchflow-clean` has an
   uncommitted `Localizable.xcstrings`. Commit or stash before any comparison, and never use
   a dirty tree as the baseline.

5. **VPN location lookup sends the public IP to third parties.** Spec 10 (VPN) lists
   `api.country.is`, `ipapi.co`, and `ipwho.is` as lookups "in order until one answers". The
   spec does not say the lookup is off unless *show detail* is on (default off). Owner
   decision needed: lookup only when *show detail* is on, or always. Test T-NET-05 checks
   whichever is chosen.

---

## 1. Architecture comparison

| Concern | Old UI (`notch`) | New build (`notchflow-clean`) |
|---|---|---|
| Content decision | `NotchEngine`, `NotchContentRegistry`, `NotchViewModel` (735 lines), `NotchEventCoordinator` (552 lines) | `FlowStage` (queue, one change at a time, 0.30 s gap), `FlowCard` (features hand it cards) |
| Pages | `NotchPage`: media, tray, mirror, with swipe and dots | `NotchPage`: media, tray, mirror, with swipe and dots (spec 01, 02) |
| Window | `OverlayPanelWindow` passes events through; drag types forwarded to `DragAndDropView` | `ShellOverlayPanel` at mainMenu+3; `ignoresMouseEvents` toggled by pointer position; `DropLandingView` |
| Glass | `NotchGlassBackdrop`, `NotchLensBackdrop` | `Surface/` (`ShellSurface`, `NotchLensBackdrop`, `GlassDimming`) |
| Mirror size | 560 × 440 minimum (base + 340 × base + 405) | Same numbers (spec 08) |
| Idle tap | Opens default page | `FlowStage.tap`: idle opens the first available page |
| Right-click menu | Update, settings, restart, quit | Same (spec 01, line 92) |

Shape and numbers match between the two. The difference is the window and drag stack, and
the content engine.

---

## 2. Feature parity matrix

Status reflects what the spec and folder show, **not** a test result. Section 4 holds the
test results.

| Feature | Old UI | New build | Status |
|---|---|---|---|
| Notch shell, pages, swipe, dots | `NotchView`, `NotchPageIndicator` | `Shell/`, spec 01, 02 | Covered; test |
| File tray | `Features/DragAndDrop/Tray` | `Features/Tray`, spec 07 | Covered; **drag gate** |
| AirDrop zone and transfer | `DragAndDrop/AirDrop` | `Tray/AirDropRelay`, spec 07 | Covered; test |
| Music, lyrics, artwork | `Features/NowPlaying` | `Media/`, spec 04 | Covered; test |
| Lock-screen music | `Features/LockScreen` | `LockMusic/`, spec 06 | Covered; test |
| Mirror (camera, ring light, zoom) | `Features/Mirror` | `Features/Mirror`, spec 08 | Covered; test camera lifecycle |
| Headphones and Bluetooth battery | `Features/Bluetooth` | `Status` (`GadgetKind`, earbud levels), spec 10 | Covered; test with real AirPods |
| Hotspot | `Features/Network/WiFi` | `Status` (hotspot), spec 10 | Covered; **owner decision** on phone battery (private API) |
| VPN | `Features/Network/VPN` | `Status` (`TunnelInterfaces`, location lookup), spec 10 | Covered; **privacy decision** (§0.5) |
| No internet | `Features/Network/WiFi` | `Status`, spec 10 | Covered; test |
| Battery and charger | `Features/Battery` | `Status`, spec 10 | Covered; test |
| Focus | `Features/Focus` | `Status` (`FocusKind`), spec 10 | Covered; test the three sources |
| HUD (volume, brightness, keyboard) | `Features/HUD` | `HUD/` (`Gauge*`), spec 09 | Covered; test |
| External drives | `Features/ExternalDevices` | `Status` (`DriveProbe`), spec 10 | Covered; test |
| Timer | `Features/Timer` | `Features/Timer`, spec 11 | Covered; test |
| Calendar | `Features/Calendar` | `Features/Calendar`, spec 12 | Covered; test |
| Downloads | `Features/Download` | `Downloads/`, spec 13 | Covered; test |
| Screenshots and recording | `Features/ScreenshotHub`, `ScreenRecording` | `Captures/`, spec 14 | Covered; test |
| Settings, onboarding, licences, updates | `Features/Settings`, `Licensing`, `Onboarding`, `SoftwareUpdate` | `Settings/`, `Setup/`, spec 15, 16 | Covered; test |
| Face ID | `Features/FaceID` | none | **Dropped on purpose** (REWRITE_PLAN: drop Face ID) |

Gaps to check when porting, not yet proven missing: anything the old code does that no spec
describes. Run a diff of the old feature folders against `docs/specs/` before porting, and
add a spec line for each gap first.

---

## 3. Automated checks

Run in `notchflow-clean` (never in `notch`):

```bash
xcodebuild test -project NotchFlow.xcodeproj -scheme NotchFlow \
  -destination 'platform=macOS' -only-testing:NotchFlowTests CODE_SIGNING_ALLOWED=NO
```

Leak check on any spec or ported text:

```bash
python3 -I scripts/spec-leak-check.py <extracted upstream tree> docs/specs
```

Baseline: see §5.

---

## 4. Manual test template

Fill the **Result** column with Pass, Fail, or Skip (give a reason). Use a **real** Finder
drag and real hardware. Use a test account where possible. Do not use the real camera
without a reason: spec 08 says tests must never touch it.

Columns: ID, check, steps, expected result, result.

### 4.1 Shell and pages (spec 01, 02)

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-SHELL-01 | Shape sits on the notch | Open on a notch Mac, then on a non-notch screen | Notch mode on notch screens; island mode elsewhere | |
| T-SHELL-02 | Idle tap opens the default page | With no content, click the shape | First available page opens | |
| T-SHELL-03 | Clicks pass through outside the shape | Click the menu bar and an app window right next to the shape | Those clicks reach the menu bar and the app | |
| T-SHELL-04 | Swipe moves between available pages | Expand, swipe left and right | Next or previous page; no wrap at the ends | |
| T-SHELL-05 | Dots show only available pages | Remove a page's content | Dot disappears | |
| T-SHELL-06 | Right-click menu | Right-click the shape | Update, Settings, Restart, Quit | |
| T-SHELL-07 | Hover open and close | Hover mode on, move pointer in and out | Opens and closes per setting | |
| T-SHELL-08 | Queue timing | Trigger two alerts close together | Hide, 0.30 s gap, show; second one after its gap | |
| T-SHELL-09 | Full-screen Space | Put a full-screen app in front | Notch stays visible; app is not activated | |
| T-SHELL-10 | Glass | Compare with spec 03; toggle system Liquid Glass slider | Matches spec; system slider changes it (not a bug) | |

### 4.2 File tray and drag and drop (spec 07) — **drag gate**

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-DRAG-01 | Drag starts the activity | Drag one file from Finder toward the notch | Drag activity shows at once | |
| T-DRAG-02 | Tray drop | Drop on the tray zone | Tile added; original stays in Finder | |
| T-DRAG-03 | AirDrop drop | Drop on the AirDrop zone | System AirDrop picker opens with the file | |
| T-DRAG-04 | Browser text or image drag | Drag text or an image from a browser | No drag activity | |
| T-DRAG-05 | Alerts held during drag | Trigger a battery alert mid-drag | Alert waits; shows after drop or exit | |
| T-DRAG-06 | Cancel drag | Start a drag, press Esc | Activity removed | |
| T-DRAG-07 | Drag while expanded | Expand a page, then drag a file | Drag takes over; previous content returns after | |
| T-DRAG-08 | Drop modes | Set AirDrop only, tray only, combined, both off | Zones match the setting; both off shows nothing | |
| T-DRAG-09 | Clicks work after drags | After T-DRAG-02, click the shape | Expands; no stuck state | |
| T-DRAG-10 | Repeat | Run T-DRAG-01 to 02 twenty times in a row | Every drag works | |

### 4.3 Tray contents (spec 07)

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-TRAY-01 | Drag a tile out | Drag a tile to Finder | File copied out | |
| T-TRAY-02 | Multi-select drag | Select two tiles, drag one | Both drag | |
| T-TRAY-03 | Move originals | Add with move, then drag out | Item leaves tray | |
| T-TRAY-04 | Empty tray | Remove all tiles | Tray page hides or shows empty state per spec | |
| T-TRAY-05 | Pro gating | Without Pro | AirDrop only (tray off) | |

### 4.4 Mirror (spec 08)

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-MIR-01 | Starts only when visible | Swipe to Mirror | Camera on; preview at least 560 pt wide | |
| T-MIR-02 | Stops on leave | Swipe away, collapse | Camera light off within ≈ 1 s | |
| T-MIR-03 | Stops on lock | Lock the screen while Mirror shows | Camera light off immediately | |
| T-MIR-04 | Ring light and zoom | Toggle ring light; zoom 1× to 2× | Visible change; limits respected | |
| T-MIR-05 | Permission denied | Deny camera permission | Message and a button to the privacy pane | |
| T-MIR-06 | No camera | Mac without a camera (or simulated) | "No camera" only | |

### 4.5 Media (spec 04, 06)

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-MED-01 | Compact and expanded | Play music | Compact shows activity; expanded shows art, title, controls | |
| T-MED-02 | Lyrics | Play a track with lyrics | Lyrics follow playback | |
| T-MED-03 | Source switch | Switch player app | Panel follows the new source | |
| T-MED-04 | No media | Stop all players | Media activity removed | |
| T-MED-05 | Lock-screen panel | Lock while music plays | Lock music panel shows (spec 06) | |

### 4.6 Headphones and Bluetooth (spec 10)

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-BT-01 | Connect AirPods | Connect | Alert with left, right, and case levels | |
| T-BT-02 | Unknown level | Connect a device that reports no battery | Shows without a level | |
| T-BT-03 | Disconnect | Disconnect | Disconnect alert; no stale level | |

### 4.7 Network (spec 10)

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-NET-01 | Hotspot on | Connect to an iPhone hotspot | Hotspot activity, priority 2 | |
| T-NET-02 | Hotspot off | Disconnect | Activity removed | |
| T-NET-03 | No internet | Disable Wi-Fi uplink | No-internet alert | |
| T-NET-04 | VPN on and off | Connect and disconnect a VPN | Activity with timer; alerts per settings | |
| T-NET-05 | VPN lookup privacy | Watch network traffic with *show detail* off | Matches the owner decision in §0.5 | |
| T-NET-06 | VPN page in System Settings | Open the VPN page | NotchFlow VPN activity removed; alerts skipped; restored on leave | |

### 4.8 Other features

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-BAT-01 | Charger, low, full | Plug in, unplug, cross thresholds | Alerts per spec 10, sounds per setting | |
| T-FOC-01 | Focus on and off | Change Focus three ways (see spec 10) | Same state from each source | |
| T-HUD-01 | Volume, brightness, keyboard | Press the keys | HUD per spec 09 | |
| T-TMR-01 | Timer | Start, finish, hide all | Ringtone stops on hide all (spec 11) | |
| T-CAL-01 | Calendar | Upcoming event | Shows per spec 12 | |
| T-DL-01 | Downloads | Start a download | Activity per spec 13 | |
| T-CAP-01 | Screenshot and recording | Take a screenshot, record a clip | Per spec 14 | |
| T-LCK-01 | Lock screen | Lock and unlock | Per spec 05 | |
| T-DRV-01 | External drive | Mount, eject | Alert per spec 10 | |
| T-SET-01 | Settings and search | Open settings, search | Every section reachable (spec 15) | |
| T-SET-02 | Licence and updates | Activate; check for updates | Per spec 16 | |

### 4.9 Language

| ID | Check | Steps | Expected | Result |
|---|---|---|---|---|
| T-LANG-01 | English and Vietnamese | Switch language | All notch strings translated; no English leaks in Vietnamese | |

---

## 5. Baseline (to fill in)

- `notchflow-clean` `main` at `4e498e4` (with the uncommitted `Localizable.xcstrings`), unit
  tests run 2026-11-10: **574 executed, 0 failures** (`NotchFlowTests`, macOS destination,
  ad-hoc signing).
- Old UI (`notch`): not measured. Its last recorded result is 363 pass, 6 skipped (HANDOFF §4),
  but the tree has changed since then.

---

## 6. Order to deploy

1. Clean-room check (§0.1) and owner decision on §0.5.
2. Automated tests green (§3).
3. Drag gate (T-DRAG-01 to 10) passes on real hardware.
4. Manual tests in §4 pass, or each fail has a spec change first.
5. Owner approves the merge (`git merge --no-ff`, see HANDOFF §5).
