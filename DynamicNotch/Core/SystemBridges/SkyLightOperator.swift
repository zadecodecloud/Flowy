internal import AppKit
import Darwin
import os

enum SkyLightSpaceLevel: Int32, CaseIterable {
    case notchSurface = 2_147_483_647
    case lockScreenOverlay = 400
    case lockScreenNotchOverlay = 401
}

@MainActor
final class SkyLightOperator {
    static let shared = SkyLightOperator()
    private let logger = Logger(subsystem: "local.NotchFlow", category: "SkyLight")

    private typealias MainConnectionIDFunction = @convention(c) () -> Int32
    // Space IDs are pointer-sized on 64-bit macOS. Mutating space operations do not
    // provide a synchronous CGError contract: never interpret leftover return-register
    // contents as success/failure. Query window membership separately instead.
    private typealias SpaceCreateFunction = @convention(c) (Int32, Int32, CFDictionary?) -> UInt64
    private typealias SpaceSetAbsoluteLevelFunction = @convention(c) (Int32, UInt64, Int32) -> Void
    private typealias ShowSpacesFunction = @convention(c) (Int32, CFArray) -> Void
    private typealias AddWindowsAndRemoveFromSpacesFunction = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void
    private typealias CopySpacesForWindowsFunction = @convention(c) (Int32, UInt32, CFArray) -> Unmanaged<CFArray>?
    private typealias CopyManagedDisplaySpacesFunction = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private let showSpaces: ShowSpacesFunction?
    private let connection: Int32?
    private let spaces: [SkyLightSpaceLevel: UInt64]
    private let addWindowsAndRemoveFromSpaces: AddWindowsAndRemoveFromSpacesFunction?
    private let copySpacesForWindows: CopySpacesForWindowsFunction?
    private let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFunction?

    private init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"

        let handle = dlopen(frameworkPath, RTLD_NOW)
        let requiredNames = ["SLSMainConnectionID", "SLSSpaceCreate", "SLSSpaceSetAbsoluteLevel",
                             "SLSShowSpaces", "SLSSpaceAddWindowsAndRemoveFromSpaces"]
        var symbols: [String: UnsafeMutableRawPointer] = [:]
        if let handle {
            for name in requiredNames { if let symbol = dlsym(handle, name) { symbols[name] = symbol } }
        }
        guard let handle,
              let mainConnectionIDSymbol = symbols["SLSMainConnectionID"],
              let spaceCreateSymbol = symbols["SLSSpaceCreate"],
              let spaceSetAbsoluteLevelSymbol = symbols["SLSSpaceSetAbsoluteLevel"],
              let showSpacesSymbol = symbols["SLSShowSpaces"],
              let addWindowsAndRemoveFromSpacesSymbol = symbols["SLSSpaceAddWindowsAndRemoveFromSpaces"] else {
            showSpaces = nil
            connection = nil
            spaces = [:]
            addWindowsAndRemoveFromSpaces = nil
            copyManagedDisplaySpaces = nil
            copySpacesForWindows = nil
            let missing = requiredNames.filter { symbols[$0] == nil }.joined(separator: ",")
            logger.error("SkyLight bridge unavailable: loaded=\(handle != nil), missing=\(missing, privacy: .public)")
            return
        }

        let copyManagedDisplaySpacesSymbol = dlsym(handle, "CGSCopyManagedDisplaySpaces") ??
            dlsym(handle, "SLSCopyManagedDisplaySpaces")

        let mainConnectionID = unsafeBitCast(
            mainConnectionIDSymbol,
            to: MainConnectionIDFunction.self
        )
        let spaceCreate = unsafeBitCast(
            spaceCreateSymbol,
            to: SpaceCreateFunction.self
        )
        let spaceSetAbsoluteLevel = unsafeBitCast(
            spaceSetAbsoluteLevelSymbol,
            to: SpaceSetAbsoluteLevelFunction.self
        )
        let showSpaces = unsafeBitCast(
            showSpacesSymbol,
            to: ShowSpacesFunction.self
        )
        let addWindowsAndRemoveFromSpaces = unsafeBitCast(
            addWindowsAndRemoveFromSpacesSymbol,
            to: AddWindowsAndRemoveFromSpacesFunction.self
        )
        let copyManagedDisplaySpaces = copyManagedDisplaySpacesSymbol.map {
            unsafeBitCast($0, to: CopyManagedDisplaySpacesFunction.self)
        }

        let connection = mainConnectionID()
        var spaces: [SkyLightSpaceLevel: UInt64] = [:]

        for level in SkyLightSpaceLevel.allCases {
            let space = spaceCreate(connection, 1, nil)
            guard space != 0 else { continue }

            spaceSetAbsoluteLevel(connection, space, level.rawValue)
            showSpaces(connection, [space] as CFArray)
            spaces[level] = space
        }

        self.showSpaces = showSpaces
        self.connection = connection
        self.spaces = spaces
        self.addWindowsAndRemoveFromSpaces = addWindowsAndRemoveFromSpaces
        self.copyManagedDisplaySpaces = copyManagedDisplaySpaces
        self.copySpacesForWindows = (dlsym(handle, "SLSCopySpacesForWindows") ?? dlsym(handle, "CGSCopySpacesForWindows"))
            .map { unsafeBitCast($0, to: CopySpacesForWindowsFunction.self) }
    }

    var isAvailable: Bool {
        connection != nil &&
        !spaces.isEmpty &&
        addWindowsAndRemoveFromSpaces != nil
    }

    func isFullscreenSpaceActive(on screen: NSScreen) -> Bool {
        guard let connection,
              let copyManagedDisplaySpaces,
              let displayIdentifier = screen.displayUUIDString,
              let managedSpaces = copyManagedDisplaySpaces(connection)?.takeRetainedValue() as? [[String: Any]],
              let displayEntry = managedSpaces.first(where: {
                  guard let identifier = $0["Display Identifier"] as? String else {
                      return false
                  }

                  return identifier.caseInsensitiveCompare(displayIdentifier) == .orderedSame
              }),
              let currentSpace = displayEntry["Current Space"] as? [String: Any],
              let currentSpaceType = currentSpace["type"] as? NSNumber else {
            return false
        }

        return currentSpaceType.intValue == 4
    }

    @discardableResult
    func delegateWindow(
        _ window: NSWindow,
        to level: SkyLightSpaceLevel = .notchSurface
    ) -> Bool {
        guard let connection,
              let space = spaces[level],
              let showSpaces,
              let addWindowsAndRemoveFromSpaces else {
            return false
        }

        // loginwindow can hide this space again after a lock or display wake.
        showSpaces(connection, [space] as CFArray)
        addWindowsAndRemoveFromSpaces(connection, space, [window.windowNumber] as CFArray, 7)
        // True means the operations were submitted, not that the window is visible.
        return true
    }

    func delegationDiagnostic(_ window: NSWindow, to level: SkyLightSpaceLevel) -> String {
        guard let connection, let space = spaces[level], let copySpacesForWindows else { return "unavailable" }
        let user = copySpacesForWindows(connection, 7, [window.windowNumber] as CFArray)?.takeRetainedValue() as? [NSNumber]
        let system = copySpacesForWindows(connection, 15, [window.windowNumber] as CFArray)?.takeRetainedValue() as? [NSNumber]
        return "wid=\(window.windowNumber) expected=\(space) mask7=\(String(describing: user)) mask15=\(String(describing: system))"
    }

    /// A read-back from WindowServer, independent of mutator return registers.
    /// Membership can settle asynchronously; callers must allow a bounded delay.
    func isWindowDelegated(_ window: NSWindow, to level: SkyLightSpaceLevel) -> Bool? {
        guard let connection, let space = spaces[level], let copySpacesForWindows,
              let memberships = copySpacesForWindows(connection, 15, [window.windowNumber] as CFArray)?.takeRetainedValue() as? [NSNumber] else { return nil }
        // 0xF includes the OS/private spaces; mask 7 only enumerates user spaces.
        return memberships.contains { $0.uint64Value == space }
    }
}
