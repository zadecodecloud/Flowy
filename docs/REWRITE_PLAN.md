# NotchFlow clean rewrite plan

Decided with the owner on 2026-11-08.

**Goal:** a closed-source NotchFlow written from scratch, containing no DynamicNotch
(GPL-3.0) code, strings or assets. The current app stays GPL-3.0, with all notices kept,
until a lawyer has reviewed both the process and the result. This plan is an engineering
process, not legal advice.

## Where the code stands (measured 2026-11-08)

| | Files | Meaningful lines |
|---|---|---|
| App Swift files | 447 | ~48,000 |
| …in files ≥ 90 % identical to DynamicNotch `61657ee` | 369 | ~39,800 |
| …50–90 % identical | 41 | ~5,300 |
| …mostly or fully NotchFlow's own | 37 | ~3,000 |
| Unit tests (derived from upstream) | — | ~7,300 |

Strings (`Localizable.xcstrings`), Lottie animations, sounds, icons and background images
also come from upstream.

## Scope

**Keep:** notch shell and pages · media / now playing and lyrics · lock screen and its music
panel · file tray and drag-and-drop · mirror · HUD (volume, brightness, keyboard backlight) ·
system status (battery, Focus, Wi-Fi / VPN / hotspot, Bluetooth, external devices) · timer ·
calendar · downloads · screenshots and screen recording · settings · onboarding · updates ·
licensing · English and Vietnamese.

**Drop:** the Face ID unlock animation.

## Clean-room rules

1. **Two sides.** The *spec side* may read the old project and run the old app. The *build
   side* never opens the old project, the upstream clone or any DynamicNotch source. It works
   only from specs, Apple documentation, public third-party documentation and the clean repo.
2. **Specs describe behaviour, not code.** A spec covers what the user sees, states, timings,
   settings and their defaults, edge cases and acceptance checks. It contains no source code,
   no upstream type, function or file names, no copied UI strings and no copied comments.
   A need for a system or private API is described by its purpose (for example "read the
   system's now-playing information"); the build side researches how to do it on its own.
3. **Review before handover.** The spec side checks every spec for leaked expression before
   the build side receives it.
4. **Build sessions start fresh.** Each one runs only inside the clean repo. Its brief names
   the old paths it must not read:
   `~/Documents/ChatGPT/notch` and `~/Documents/Codex/2026-11-02/`.
5. **Provenance log.** `PROVENANCE.md` in the clean repo records, for every file: the
   session, the date, the spec it was built from and the outside sources it consulted.
6. **New assets and strings.** Icons come from SF Symbols or are drawn new. The Lottie
   animations, sounds and background images are replaced. English and Vietnamese strings are
   rewritten.
7. **Third-party packages.** Sparkle (MIT), Lottie (Apache-2.0) and MediaRemoteAdapter
   (BSD-3-Clause) are permissive. They may stay if their license texts ship with the app.
   Check the license of each pinned version again before release.
8. **NotchFlow's own code** may move over after review. These files have no measurable
   upstream match: Mirror (4 files), `NotchLensBackdrop`, `NotchGlassBackdrop`,
   `NotchPageIndicator`, `NotchPageMetrics`, `NotchPageSwipeMonitor`, `NotchPage`,
   `NotchClickTap`, `ScrollingText`, `CrystalGlassSurface`,
   `ExpandedNotchAppearancePreview`, `NotchLanguage`, `LockScreenAmbientMesh`,
   `LockScreenMediaLayout`, `LockScreenMediaBackgroundView`,
   `LockScreenExpandedPlayerView`, `LockScreenPreviewController`,
   `LockScreenDisplayActivity`, `LicenseStore`, `LicenseVerifier` and
   `scripts/license-tool.swift`.
   The spec side copies the approved files into `Imported/` in the clean repo when it is set
   up. The build side then adapts them to the new core. Files that only partly match
   upstream are specced and rebuilt instead.

## Phases

| # | Phase | Side | Needs | Output |
|---|---|---|---|---|
| 0 | Scope and this plan | — | — | This file (done) |
| 1 | Specs | spec | 0 | 16 specs in `docs/specs/` (drafted and leak-checked 2026-11-09; owner review pending) |
| 2 | Set up the clean repo | spec | 1 | New repo, see below |
| 3 | Core | build | 2 | App shell, notch window, content engine |
| 4 | Features (up to 4 sessions at once) | build | 3 | One feature area per session |
| 5 | Assets and strings | build | 2 | New icons, animations, sounds, en/vi text |
| 6 | Integration and parity QA | both | 4, 5 | Checklist from the specs, run on device |
| 7 | Release preparation | — | 6 | Legal review, signing, notarisation, update feed |

**Phase 1 — specs.** One file per area:

- Notch shell: sizes, hover, click and swipe, pages, animation.
- Content engine: priority, queueing, durations.
- Glass and appearance.
- Media and lyrics.
- Lock screen.
- Lock-screen music panel.
- File tray and drag-and-drop.
- Mirror.
- HUD.
- System status.
- Timer.
- Calendar.
- Downloads.
- Screenshots and recording.
- Settings and onboarding.
- Updates and licensing.

**Phase 2 — clean repo.**

- Location: `~/Documents/ChatGPT/notchflow-clean`.
- Fresh `git init`, a new Xcode project targeting macOS 26 or later, and a proprietary
  `LICENSE`.
- `PROVENANCE.md`, the `Imported/` files, and test targets whose defaults are isolated from
  the start.
- Development bundle ID `app.notchflow.next`, so it never shares preferences with the
  current app.

**Phase 3 — core.** One session, because everything else depends on it:

- the app shell, notch window placement per screen, and click, hover and swipe input;
- the content engine (priority, queue, timers) and the page system;
- settings storage, localisation, and the glass surface.

**Phase 4 — features.** Each area runs as its own session in its own worktree. The old line
counts are a rough guide to size only.

| Area | Old lines |
|---|---|
| Media, lyrics and the lock-screen music panel | ~5,000 |
| Lock screen: detection, overlay window, sounds | ~3,700 |
| File tray, drag-and-drop (fix drops from scratch) and the Mirror port | ~2,300 |
| HUD | ~2,200 |
| System status | ~7,800 |
| Timer and calendar | ~3,600 |
| Downloads, screenshots and recording | ~3,200 |
| Settings, onboarding, updates and licensing | ~7,700 |

**Phase 7 — release.**

- A lawyer reviews the process and the result, and the license is chosen.
- Developer ID signing, hardened runtime, notarisation and a Sparkle feed.
- The bundle ID switches to `app.notchflow.mac`, with migration of users' settings from the
  current app.
