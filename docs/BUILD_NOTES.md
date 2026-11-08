# Build notes — in progress

Host: MacBook Pro MacBookPro18,3, Apple M1 Pro arm64, 16 GB; macOS 27.2 (26B5112a); Xcode 27.2 (27B52), macOS SDK 27.2; developer directory `/Applications/Xcode.app/Contents/Developer`. The upstream README claims macOS 14.6/Xcode 15 but that is not established by this audit. Project target settings differ (26.0, recommended target, test targets 15.6); Swift language mode 5. No minimum Xcode version inferred.

Shared schemes in source: DynamicNotch and DynamicNotchUI. Baseline SPM pins: Lottie 4.6.0 and Sparkle 2.9.4. Initial sandboxed `xcodebuild -list -project DynamicNotch.xcodeproj` failed resolving packages because the sandbox denied writes to the default Xcode SourcePackages directory; retry uses a workspace-local package directory and network access. Baseline build/test not yet completed.

## Results on this machine

`xcodebuild -list` identified targets DynamicNotch, DynamicNotchTests and DynamicNotchUITests, schemes DynamicNotch and DynamicNotchUI. Package resolution succeeded with Lottie 4.6.0 and Sparkle 2.9.4. Baseline first build failed because `DynamicNotch/Resources/Preview Content` was absent from the Git checkout. After creating that empty directory the baseline Debug build succeeded with `CODE_SIGNING_ALLOWED=NO`. Effective baseline Debug app settings showed `MACOSX_DEPLOYMENT_TARGET = 14.0`, `SWIFT_VERSION = 5.0`, SDK macOS 27.2 and upstream development team; this differs from the project metadata. Fork effective Debug app settings confirm deployment target 26.0, bundle ID `local.NotchFlow`, Swift 5.0 and macOS 27.2 SDK; the upstream team ID is removed.

Fork Debug build succeeded with signing disabled. Initial XCTest run: 249 passed, 1 failed (restore activity timeout); a focused rerun passed. Fixed a queued show event that could undo dismissal; full suite then passed 250/250. These are local automated tests, including mocked integrations, not proof of real integrations. Two new focused safety tests subsequently passed (2/2); the full-suite count predates those new tests. Build artifacts are unsigned for distribution: the linker adds an ad-hoc Mach-O signature, without a sealed app bundle or team identity. No notarization or distribution signing performed.

MediaRemoteAdapter script and test client were copied to Contents/Resources, framework to Contents/Frameworks; framework source is ad-hoc signed and has arm64/x86_64 slices. Resource resolution outside source, runtime helper loading, subprocess cleanup and TCC behavior have not been verified.

## Product identity follow-up

The built product is now `NotchFlow.app`, with module and project/scheme names retained as `DynamicNotch` to avoid sweeping source renames. The default configuration uses a local ad-hoc signature (no team). A normal Debug build succeeded and `codesign --verify --deep --strict` passed locally. This does not establish TCC stability, notarization or distribution. The project was opened in Xcode with the DynamicNotch scheme and My Mac selected.

After the identity/default changes, the parallel suite had one timeout in the download event test; that test passed on a focused rerun. A subsequent serial full suite had one timeout in the first-launch Now Playing test; that test passed on a focused rerun. Treat the full suite as unstable, not passing. Earlier full suite before these changes passed 250/250. No live app interaction or device integration was manually verified in this follow-up.

## Language and branding follow-up

Shared `NotchFlow` scheme builds `NotchFlow.app`; the original DynamicNotch scheme remains available. The app defaults to Vietnamese, supports Vietnamese for notch activities, and migrates an old Russian/system choice once without replacing other explicit choices. Onboarding and About no longer advertise upstream donation or social channels; explicit GPL/upstream credit remains. The app uses a system placeholder icon so the visual identity can be designed separately. Existing data under the upstream FileTray directory is left untouched; new tray files use a separate NotchFlow directory. Vietnamese and localization tests passed; real UI after restarting the new build has not yet been inspected.

## Standalone Settings redesign

Source snapshot has no `.git` directory and no configured remote; source remains GPL-3.0 derived. Xcode project `NotchFlow.xcodeproj`, scheme `NotchFlow`. Local Debug build succeeded. UI tests on a separate preview bundle passed for Settings launch, sidebar search and Battery navigation; screenshots were reviewed in dark mode and the Battery screen was reviewed in light mode. Seventeen focused settings, history and language tests passed. A new local build script does not install into Applications. Test mode uses inactive providers, so it does not prove real device integrations.

## Liquid Glass follow-up

Debug build of `NotchFlow.xcodeproj`, scheme `NotchFlow`, succeeded with Xcode 27.2 / macOS 27.2. Three focused background-style tests and three language tests passed; an isolated UI test switched from Black to Liquid Glass and passed. An initial UI test incorrectly cast the accessibility value to String and failed; corrected test accepts the native numeric value and passed. A subsequent picker warning about publishing during view updates was addressed and the two-way selection test passed without that warning. These checks do not verify backdrop rendering at the physical notch, on an external display, or under actual Reduce Transparency system settings.
