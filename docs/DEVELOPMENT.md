# NotchFlow

NotchFlow is a macOS notch companion: media, a file tray and a camera mirror, switched by swiping sideways on the open notch. It is a work in progress.

**License.** NotchFlow is GPL-3.0. It contains code derived from an earlier open-source notch project; those authors keep their copyright, which is recorded in `LICENSE`, the source file headers and `THIRD_PARTY_NOTICES/`. Keep these notices and ship complete corresponding source with any modified binary you distribute.

**Not ready for distribution.** Screenshot monitoring, recording attribution and private callback lifetime still need correction; avoid enabling screenshot integration. Dragging files onto the notch is currently not working (investigation paused).

## Build

On the audited Mac: macOS 27.2 arm64, Xcode 27.2 and macOS 27.2 SDK. Deployment target is set to macOS 26.0; older macOS support is not claimed. Open `NotchFlow.xcodeproj`, select shared scheme `NotchFlow` and My Mac. The project uses a local ad-hoc signature, with no development team. TCC and launch-at-login behavior remain unverified. For compilation without signing:

```sh
xcodebuild -resolvePackageDependencies -project NotchFlow.xcodeproj -scheme NotchFlow -clonedSourcePackagesDirPath build/SourcePackages
xcodebuild -project NotchFlow.xcodeproj -scheme NotchFlow -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages CODE_SIGNING_ALLOWED=NO build
```

The Debug product is `build/DerivedData/Build/Products/Debug/NotchFlow.app`. A normal local build uses ad-hoc signing; this is not a verified runnable release or distribution signature. See `docs/BUILD_NOTES.md`, `docs/FEATURE_PARITY.md`, and `docs/MANUAL_TESTS.md` for status. Lottie 4.6.0 and Sparkle 2.9.4 are pinned. Fork update checks are disabled and no feed or key is configured.

## Permissions and cleanup

Feature permissions may include Calendar, Accessibility and others; the inherited consent flows remain unaudited. No permissions or Keychain entries were changed by this development work. Quit the app before deleting any local build. Global screenshot preference recovery is not yet implemented; avoid enabling screenshot integration. Launch at login defaults off; its identity and uninstall/recovery behavior still require verification.

## Language and identity

NotchFlow defaults to English. Vietnamese and other languages can be chosen separately for Settings and for notch activities; a one-time migration moved existing installs to English.

The current app icon is the system placeholder. Source lives in `NotchFlow/`, tests in `NotchFlowTests/` and `NotchFlowUITests/`; the Swift module is `NotchFlow`. Tray copies use Application Support/NotchFlow/FileTray; startup does not delete untracked tray files.

## Debug review hooks

Debug builds accept `-NotchFlowDebugOpenPage media|tray|mirror` to open a page at launch; add `-isNotchLocked YES` to keep it expanded without saving that preference.

## Settings design

The native Settings shell uses a searchable left sidebar, grouped sections and neutral cards inspired by the layout of Canopy; no Canopy assets or implementation were copied. Existing SwiftUI feature views and settings stores remain connected. New visual styling is concentrated in `SettingsRootView.swift` and the shared Settings components so it can be redesigned independently of system services. See `docs/SETTINGS_DESIGN.md`.

## Notch appearance

In Settings → General → Notch, choose Black or Liquid Glass. Black is the default; Glass uses public AppKit glass and behind-window material with a dark tint. If Reduce Transparency is enabled, the surface falls back to opaque black while retaining the saved preference. Physical-notch and external-display appearance still require manual verification. The About screen is concise; GPL license and third-party notices remain in the source distribution.

## Free, Pro, and developer access

The app defaults to Free; new File Tray imports and lock-screen music require Pro.
Developer previews are hidden until a separate developer token is activated. The
production activation service and verification key are not configured. Debug builds
accept the dedicated local Pro/developer test tokens; Release excludes that test issuer.
The local signature format, issuer bootstrap, file recovery,
distribution limitations and remaining work are described in `docs/LICENSING-AND-RELEASE.md`.
