# NotchFlow Settings

Standalone source snapshot; no upstream Git remote. Still a GPL-3.0 derivative of DynamicNotch. Project: `NotchFlow.xcodeproj`, shared scheme: `NotchFlow`. Swift module/target retain their existing internal names.

The new Settings shell is inspired by the reference Canopy window observed locally: a quiet sidebar, search, clear section heading and grouped controls. It uses native SwiftUI controls, SF Symbols and the existing feature settings models; it does not include Canopy assets or code. Appearance adapts to light/dark settings. `Features/Settings/Root/Views/SettingsRootView.swift` owns the shell and navigation; `Features/Settings/Shared/Components` owns reusable styling; feature pages remain under their respective Features directories.

Search filters existing section names, with a no-results message. Navigation retains selection and history. Unsupported Face ID is omitted from the sidebar. The app name and Settings UI are a separate presentation layer, while service and storage code is still derived from upstream. The old app and its Git checkout were not overwritten.

Validation: local Debug build and UI tests use a temporary bundle identifier and inactive service implementations; Settings and Battery screens were inspected in dark mode; Battery was also inspected in light mode. Search and opening Battery were exercised by UI automation. Accessibility settings, every section and real system integrations have not all been manually verified. See FEATURE_PARITY.md for broader limitations.
