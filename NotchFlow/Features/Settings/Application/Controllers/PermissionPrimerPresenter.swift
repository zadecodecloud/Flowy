internal import AppKit
import SwiftUI
import ApplicationServices

/// Shows the permission explainer in its own small window when a feature needs a permission
/// outside Settings (e.g. the volume/brightness HUD at launch), then lets macOS ask.
@MainActor
final class PermissionPrimerPresenter: NSObject, NSWindowDelegate {
    static let shared = PermissionPrimerPresenter()

    private var window: NSWindow?
    private var onClose: (() -> Void)?
    private static let dismissedKey = "permissionPrimer.accessibility.dismissed"

    /// At launch: explain Accessibility once if the HUD needs it and it isn't granted.
    /// "Not now" is remembered; the Permissions page can still ask later.
    func presentAccessibilityIfNeeded(locale: Locale, defaults: UserDefaults = .standard) {
        guard !AppEnvironment.isRunningTests, !AXIsProcessTrusted(),
              !defaults.bool(forKey: Self.dismissedKey), window == nil else { return }
        present(kind: .accessibility, locale: locale,
                onContinue: {
                    let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                    _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                },
                onCancel: { defaults.set(true, forKey: Self.dismissedKey) })
    }

    /// From inside a feature: explain `kind`, then run `request` (which shows the macOS prompt).
    /// "Not now" calls `onDecline` so the feature can show its "no access" state.
    func explainThenRequest(_ kind: Kind, request: @escaping () -> Void, onDecline: @escaping () -> Void = {}) {
        guard !AppEnvironment.isRunningTests else { request(); return }
        guard window == nil else { onDecline(); return }
        present(kind: kind, locale: Self.appLocale, onContinue: request, onCancel: onDecline)
    }

    /// The language chosen in Settings, for callers that don't hold the settings store.
    static var appLocale: Locale {
        let raw = UserDefaults.standard.string(forKey: GeneralSettingsStorage.Keys.appLanguage) ?? NotchLanguage.english.rawValue
        return NotchLanguage.resolved(raw).locale
    }

    private func present(kind: Kind, locale: Locale, onContinue: @escaping () -> Void, onCancel: @escaping () -> Void) {
        let sheet = PermissionPrimerSheet(
            kind: kind, locale: locale, usesSystemSettings: false,
            onContinue: { [weak self] in
                self?.close(cancelled: false)
                onContinue()
            },
            onCancel: { [weak self] in self?.close(cancelled: true) })
        let window = NSWindow(contentViewController: NSHostingController(rootView: sheet))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = PermissionPrimerContent(kind: kind, locale: locale).title
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.center()
        onClose = onCancel
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func close(cancelled: Bool) {
        let cancel = onClose
        onClose = nil
        window?.delegate = nil
        window?.close()
        window = nil
        if cancelled { cancel?() }
    }

    /// The red close button counts as "Not now".
    func windowWillClose(_ notification: Notification) {
        let cancel = onClose
        onClose = nil
        window = nil
        cancel?()
    }
}
