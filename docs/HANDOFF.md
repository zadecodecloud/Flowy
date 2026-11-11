# NotchFlow: handover (2026-11-09)

This file is the starting point for the next chat session. Read it first, then
`docs/REWRITE_PLAN.md`.

## 1. Background
- **NotchFlow** is a macOS notch app (Swift/SwiftUI/AppKit, macOS 26+, Xcode 27.2).
- **The owner** speaks Vietnamese and prefers short replies with only the main points.
- **The current app is a fork of DynamicNotch (GPL-3.0).** The owner wants to **sell it as
  closed source**. So the app is being **rewritten from scratch in a clean room**, in a new
  repo.
- **Do not remove the GPL or copyright notices from the old app.** The owner asked for this
  and it was refused, because it is legally required. A lawyer must review the clean-room
  process before the GPL is dropped.

## 2. Repos and folders
| Path | Role | Status |
|---|---|---|
| `~/Documents/ChatGPT/notch` | Old app (GPL), the **spec side** | Bundle `app.notchflow.mac`. Many changes **not committed** (only the baseline commit `034f360`) |
| `~/Documents/ChatGPT/notchflow-clean` | **New app, clean room** (closed source) | `main` = `11b9e8f`, 279 tests pass. Bundle `app.notchflow.next` |
| `~/Documents/Codex/2026-11-02/.../outputs/NotchFlow-Standalone` | Backup of the old project | **Keep, do not delete** |
| `~/Documents/Codex/2026-11-02/.../outputs/NotchFlow` | Shallow clone of upstream DynamicNotch (`61657ee`) | Used only by the spec side's leak checker |

## 3. Clean-room rules (binding)
- **Spec side:** may read the old code and writes behaviour specs. That is this chat
  session, or any session that has read the old code.
- **Build side:** fresh sessions that work only in `notchflow-clean`. They read only:
  - `docs/specs/`;
  - `Imported/`;
  - Apple and public third-party documentation.
- **The build side must never open** `~/Documents/ChatGPT/notch`, `~/Documents/Codex/2026-11-02/`
  or any DynamicNotch source.
- **Leak checker:** `scripts/spec-leak-check.py` in the old repo.

  ```bash
  git -C <upstream clone> archive HEAD DynamicNotch DynamicNotchTests | tar -x -C <dir>
  python3 -I scripts/spec-leak-check.py <dir> <folder to check>
  ```

  It checks upstream identifiers, preference keys and phrases of four or more words.
- **Every file** in the new repo is recorded in `PROVENANCE.md`.
- **Build-side questions** go to `notchflow-clean/docs/questions.md`. The spec side answers
  there and updates the specs.
- **All assets and text must be new.** Third-party code is limited to Sparkle (MIT),
  Lottie (Apache-2.0) and MediaRemoteAdapter (BSD-3).

## 4. Done
### Old app (`notch`, not committed)
- Clear notch glass, Canopy style (lensing `_variant` 11 plus variable blur), with clarity
  +10 %.
- Mirror page 560 pt with ring light and zoom; page dots; clicking the idle notch opens the
  default page.
- Language rewritten (en/vi only, default English).
  - Root cause of "starts in Russian": the tests wrote into the real settings.
  - Fixed with `NotchFlowTestObserver` and by clearing the real domain.
- Scrolling titles on the lock screen; slower lock-screen background (pace 0.65); compact notch
  pure black with no border.
- HUD back on, all three types on by default.
- 363 tests pass, 6 skipped.

### Rewrite
- **Phase 0:** plan in `docs/REWRITE_PLAN.md`. Scope: keep everything, drop Face ID.
- **Phase 1:** 16 behaviour specs in `docs/specs/` (the same copy is in the clean repo). The
  leak checker finds 0 matches.
- **Phase 2:** the clean repo, with a hand-written Xcode project, `Imported/` (reviewed
  NotchFlow-own code), README with the rules, LICENSE (proprietary, **name still needed**)
  and PROVENANCE.
- **Phase 3:** core (shell, content engine, glass surface, settings, en/vi strings).
  Commits `9a25adb` and `2b58ba9`. The spec side answered 10 questions.
- **Phase 4, wave 1, merged into `main`:** HUD, lock screen, media and lyrics, tray plus
  drag-and-drop plus mirror. Commits `e7cad92`, `8ee123c`, `b0ac021` and `11b9e8f`; 279 tests.
  - A real Finder drag onto the notch **works**. This was the old app's bug.

## 5. Phase 4, wave 2
**Merged into `main` on 2026-11-09** (owner approved). `main` = `ebad048`, 407 tests pass.
| Feature | Branch | Merge commit |
|---|---|---|
| System status (spec 10) | `claude/feature-system-status-b2830b` | `318d95f` |
| Timer and calendar (specs 11, 12) | `claude/feature-timer-calendar-4cf48f` | `4c7df24` |
| Lock-screen music panel (spec 06) | `claude/feature-lockscreen-music-252291` | `ebad048` |

- Merge fixes: the settings section-title test now checks each title through its own table
  (`titleTable`) with the feature-table fallback; the status tests' private Focus and chime
  fakes were renamed, because they clashed with the timer/calendar fakes.
- **Open follow-up (build side):** the calendar still reads Focus on its own. Timer/calendar
  question 11 says it should use the system-status Focus state now that both are merged.
- While Xcode has the project open, it keeps deleting
  `NotchFlow.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` in the
  working tree. Never commit that deletion; `git restore` it.

**Still in progress:**
| Feature | Branch | Commit | State |
|---|---|---|---|
| Downloads and screenshots (specs 13, 14) | `claude/feature-downloads-screens-d68cc2` | **none** | The session was stopped partway; 6 files are uncommitted in worktree `.claude/worktrees/feature-downloads-screens-d68cc2` (base `11b9e8f`, so it must merge the new `main` first) |

- **All spec questions answered** on 2026-11-09 (round 2 at the end of
  `notchflow-clean/docs/questions.md`): phase 3 follow-up, HUD, lock screen, media,
  tray/Mirror, system status, timer/calendar, lock-screen music. Specs 04–12 are updated in
  both repos; the leak checker found 0 matches. **Not committed yet.**
- **Build follow-up:** every answer marked **Change** needs a code change. One build session
  per area, after the Downloads branch is merged. The biggest items are: the battery alert
  styles; Focus from three sources; the VPN page in macOS System Settings; the timer's
  time's-up activity and compact layout; calendar menus and shared Focus; lock-screen
  lyrics; and holding alerts during a drag.
- **Owner decision pending:** whether to use a private API to read the iPhone hotspot's
  battery.
- **To merge:**
  - merge each branch with `git merge --no-ff refs/heads/<branch>`;
  - resolve conflicts by keeping both sides;
  - merge the string catalog `.xcstrings` as a JSON union with sorted keys and
    `" : "` separators;
  - run all tests after each merge;
  - before merging, discard the junk change Xcode keeps adding to `Localizable.xcstrings`
    (the empty `""` key).

## 6. Next (plan agreed 2026-11-09)
Each step: build sessions code and test on their own branches → the spec side reviews the
diffs against the specs and runs all tests → the owner approves the merge → next step.

1. ~~Merge the three finished wave-2 branches~~ (done, `main` = `ebad048`).
2. ~~Answer the build sessions' spec questions~~ (done, `b956038`).
3. **Step 1 (2 sessions in parallel):**
   - **A. Downloads and screenshots** (specs 13, 14): continue in the existing worktree,
     after merging the new `main` into it.
   - **B. Engine fixes:** a per-mode compact width (island vs notch), holding alerts during a
     file drag (spec 07), and Mirror using the lock-screen lock signal (spec 08).
   - **Step 1 done and merged on 2026-11-09:** engine `42cf40e`, downloads `3da7feb`; `main`
     passes 473 tests. Round 3 answers (engine notes; downloads and screenshots 1–13) are at
     the end of `questions.md`, and specs 13 and 14 are updated. **Not committed yet.**
     Round 3 has **Change** items (downloads sizes, more Chromium channels, screenshot and
     recording sizes) for one small build session after step 2.
4. **Step 2 (3 sessions in parallel, started 2026-11-09 from `main` `3da7feb`):**
   `nf-build-status2`, `nf-build-timercal2`, `nf-build-hudlock2`.
   - **Done and merged on 2026-11-09:** status `fb151b6`, timer/calendar `f8851a7`,
     HUD/lock/media `3a01276`. Round 3 answers are committed (`1ad94f9`). `main` = `3a01276`,
     **520 tests pass**.
   - **Round 4 answers** (the step 2 questions) are written at the end of `questions.md`, and
     specs 04, 05, 10 and 11 are updated. **Not committed yet.** The leak checker flags only
     `modeIdentifier` in the build side's own question: that is a field of macOS's Focus log,
     not upstream code.
   - **Next:** one small build session for the round 3 and round 4 **Change** items:
     - round 3: downloads sizes, Chromium channels, screenshot and recording sizes, the
       recording compact style;
     - round 4: the Focus look-back at 5 min → 1 h → 24 h; *hide everything* stops the
       time's-up ringtone; the debug lock-screen preview window.
   - **Owner decision pending:** the phone's battery, either through the undocumented tether
     record (lighter) or a private framework, or not at all. Each one works through the
   **Change** answers for its area:
   - **C. System status:** battery styles, Focus from three sources, hotspot detection, the
     VPN page in macOS System Settings, opening the drive on click.
   - **D. Timer and calendar:** the time's-up activity, compact layout and setup size, calendar
     menus, and shared Focus.
   - **E. HUD, lock screen, media, lock-screen music:** tick and symbols, padlock insets,
     preparing, debug lock, the instrumental state, lyrics, materials.
   - **Round 3/4 fixes merged** (`3074798`, 526 tests). Rounds 4 and 5 are answered and
     committed.
   - **Lock-screen bug found (2026-11-09):** on a real lock, nothing of the new app showed.
     The log said "Could not attach … -1342177280". The cause: the window server's Space
     functions return no status, and the build treated leftover register values as
     errors. Spec 05 now has "How attaching works" (`d155acb`). Fix session:
     `nf-build-lockspace`.
     - Note: in zsh, `log` is a builtin. Use `/usr/bin/log show` to read logs.
   - **Lock-screen fix merged** (`ce5d916`, 527 tests): the Spaces are created at launch
     (400 for the panel, 401 for the notch), and the read-back uses mask 15. **Not yet
     checked on a real lock:** the owner presses Run in Xcode, then locks the Mac.
   - **Improvement plan for owner review:** `docs/IMPROVEMENT_PLAN.md` (what we learned from
     the old app and Canopy; P0–P3; 5 questions).
   - **Step 3 merged** (`8c1f97c`, 564 tests): settings with search, permissions, onboarding,
     licensing (Debug builds count as Pro without a token), and Sparkle 2.9.4 with no feed.
     Round 6 answers are in `8708972`. Follow-up (Keychain tokens in Release builds, search
     reach into the lock-screen rows) was sent to `nf-build-settings16`.
   - **Round 6 follow-up merged** (`1355b58`, 570 tests; the Release build compiles).
   - **Lock-panel diagnostics merged** (`4e498e4`, 574 tests). Every lock logs why the
     panel shows or stays hidden (category `lockMusic`), and the panel falls back to the
     menu-bar screen. The rebuilt app is running. Read the log after a real lock:
     `/usr/bin/log show --last 10m --info --predicate 'subsystem == "app.notchflow.next" AND category IN {"lock","lockMusic"}'`.
   - **Not started yet** (it could not start over Remote Control): phase 5, Vietnamese
     InfoPlist permission texts. Start one build session for it.
   - **Step 3 started** in parallel: `nf-build-settings16` (specs 15 and 16). Specs updated
     in `d0c0c3d`: System status stays one section, and Debug builds count as Pro while no
     token is stored.
5. **Step 3 (alone):** spec 15 (settings: structure, search, reset, permissions, onboarding)
   and spec 16 (Sparkle, NF1 licensing, About). It touches every settings screen.
5. **Phase 5:** new assets (icon, language flags `flag-en`/`flag-vi`, onboarding animation)
   and new en/vi text.
6. **Phase 6:** QA on a real Mac. Nothing has been tried by hand yet:
   - lock screen, HUD (needs the Accessibility permission), AirDrop, camera, lyrics;
   - charger, VPN, AirPods, USB drive;
   - the Clock app, Calendar.
   - Clicks and hovers on the real notch are also still unconfirmed.
7. **Phase 7:**
   - a lawyer reviews the clean room;
   - LICENSE gets the owner's legal name;
   - Developer ID, notarisation and a Sparkle feed;
   - the bundle ID switches to `app.notchflow.mac`, with migration of settings from the old
     app.

## 7. Notes
- **Commit only when the owner asks.** The owner approved:
  - committing feature work on the feature branches;
  - merging wave 1.
- **Do not click macOS privacy (TCC) prompts or change system settings.**
- **Tests:** in the old repo, `xcodebuild test ... -only-testing:NotchFlowTests`. In the clean
  repo:

  ```bash
  xcodebuild test -project NotchFlow.xcodeproj -scheme NotchFlow -destination 'platform=macOS'
  ```
- **The scratchpad in `/private/tmp` gets wiped.** Extract the upstream tree again whenever
  the leak checker is needed.
- **Linked sessions:** `notchflow-core`, `nf-media`, `nf-lockscreen`, `nf-tray-mirror`,
  `nf-hud`, `nf-status`, `nf-timer-cal`, `nf-downloads`, `nf-lock-music`. All are idle and
  can be archived once their branches are merged.
