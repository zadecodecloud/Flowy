# NotchFlow — incomplete development fork

NotchFlow is a work-in-progress derivative of [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) at commit `61657ee7fa7a96633f49d1eda803296030a4f4fa`. Upstream authors retain their copyright. The source is GPL-3.0; see `LICENSE`, source notices, `THIRD_PARTY_NOTICES/` and `README.UPSTREAM.md`. The changes from the audited baseline are described in the documentation; this snapshot has no Git history. This checkout is corresponding source for these local changes; preserve all notices and provide complete corresponding source when distributing a modified binary.

**Not ready for use or distribution.** The fork has only initial safety changes and has not met the requested feature or runtime acceptance tests. Do not run it against important files or enable system integrations until the remaining work is completed. The screenshot preference setters and stop-by-process-name action have been disabled, but screenshot monitoring, recording attribution and private callback lifetime still require correction. Upstream scripts can install over an application in /Applications; do not run them.

## Build

On the audited Mac: macOS 27.2 arm64, Xcode 27.2 and macOS 27.2 SDK. Deployment target is set to macOS 26.0; older macOS support is not claimed. Open `NotchFlow.xcodeproj`, select shared scheme `NotchFlow` and My Mac. The project uses a local ad-hoc signature, with no development team. TCC and launch-at-login behavior remain unverified. For compilation without signing:

```sh
xcodebuild -resolvePackageDependencies -project NotchFlow.xcodeproj -scheme NotchFlow -clonedSourcePackagesDirPath build/SourcePackages
xcodebuild -project NotchFlow.xcodeproj -scheme NotchFlow -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages CODE_SIGNING_ALLOWED=NO build
```

The Debug product is `build/DerivedData/Build/Products/Debug/NotchFlow.app`. A normal local build uses ad-hoc signing; this is not a verified runnable release or distribution signature. See `docs/BUILD_NOTES.md`, `docs/FEATURE_PARITY.md`, and `docs/MANUAL_TESTS.md` for status. Lottie 4.6.0 and Sparkle 2.9.4 are pinned. Fork update checks are disabled and no feed or key is configured.

## Permissions and cleanup

Feature permissions may include Calendar, Accessibility and others; the upstream consent flows remain unaudited. No permissions or Keychain entries were changed by this development work. Quit the app before deleting any local build. This fork does not migrate or delete upstream Keychain entries. Global screenshot preference recovery is not yet implemented; avoid enabling screenshot integration. Launch at login defaults off; its identity and uninstall/recovery behavior still require verification.

## Language and identity

NotchFlow defaults to Vietnamese. Existing Russian/system selections from the earlier fork are switched once to Vietnamese; later choices are respected and other explicitly selected languages are retained. Vietnamese is available both for Settings and notch activities. Some inherited strings still fall back to English; translation coverage and visual layout are not fully audited.

The current app icon is the system placeholder, intentionally leaving visual design for a later pass. The internal Swift module remains named DynamicNotch for compatibility; NotchFlow is a GPL-3.0 derivative, with upstream attribution retained in the source and license documents. Tray copies now use Application Support/NotchFlow/FileTray. Previously stored upstream-path files are not automatically moved or deleted; startup no longer deletes untracked tray files.

## Standalone project

This standalone source snapshot is not connected to the upstream Git remote. It remains a GPL-3.0 derivative because it contains upstream source. The `NotchFlow` shared scheme opens from `NotchFlow.xcodeproj`. The older upstream install scripts, appcast and community files are retained under `upstream-reference/` for provenance and should not be used: the install script can overwrite files in `/Applications`. `scripts/build-local.sh` builds locally without installation.

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
