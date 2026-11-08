//
//  AudioOutputRouting.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/8/26.
//

import Foundation
import CoreAudio

protocol AudioOutputRouting: AnyObject {
    func startObservingChanges(_ handler: @escaping @Sendable () -> Void)
    func stopObservingChanges()
    func availableRoutes() -> [AudioOutputRoute]
    func currentRoute() -> AudioOutputRoute?
    @discardableResult func setCurrentRoute(_ id: AudioDeviceID) -> Bool
}

extension AudioOutputRouting {
    func startObservingChanges(_ handler: @escaping @Sendable () -> Void) {}
    func stopObservingChanges() {}
}
