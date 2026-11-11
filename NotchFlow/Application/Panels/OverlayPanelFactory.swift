//
//  OverlayPanelFactory.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 6/28/26.
//

import SwiftUI

enum OverlayPanelFactory {
    static func makeLockScreenPanel(frame: NSRect) -> OverlayPanelWindow {
        let window = makePanel(frame: frame, level: OverlayWindowLevel.lockScreenPanel, canBecomeKey: false)
        // AppKit otherwise suppresses the panel while loginwindow owns the screen.
        window.canBecomeVisibleWithoutLogin = true
        return window
    }

    static func makeLockScreenBackground(frame: NSRect) -> OverlayPanelWindow {
        let window = makeLockScreenPanel(frame: frame)
        window.ignoresMouseEvents = true
        return window
    }

    static func collectionBehavior(includesFullscreenAuxiliary: Bool = true) -> NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]

        if includesFullscreenAuxiliary {
            behavior.insert(.fullScreenAuxiliary)
        }

        return behavior
    }

    static func makePanel(
        frame: NSRect,
        level: NSWindow.Level,
        isFloatingPanel: Bool = true,
        canBecomeKey: Bool = true
    ) -> OverlayPanelWindow {
        let window = OverlayPanelWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.allowsKeyWindow = canBecomeKey
        window.allowsMainWindow = canBecomeKey

        configure(window, level: level, isFloatingPanel: isFloatingPanel)
        return window
    }

    static func configure(_ window: NSPanel, level: NSWindow.Level, isFloatingPanel: Bool = true) {
        window.isReleasedWhenClosed = false
        window.isFloatingPanel = isFloatingPanel
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.hasShadow = false
        window.animationBehavior = .none
        window.level = level
        window.collectionBehavior = collectionBehavior()
        window.acceptsMouseMovedEvents = true
    }
}
