// NotchFlow modification: upstream face recognition and automatic unlock removed.
import Foundation
import Combine

@MainActor
final class FaceIDService: NSObject, ObservableObject {
    static let shared = FaceIDService()
    @Published private(set) var state: FaceIDState = .idle
    @Published private(set) var detectedFaceCount = 0
    @Published private(set) var areEyesOpen = false
    @Published private(set) var livenessScore = 0.0

    func startScan(requireOpenEyes: Bool = true, livenessCheck: Bool = true, completion: ((Bool) -> Void)? = nil) {
        state = .failed(reason: "Face authentication is unavailable")
        completion?(false)
    }
    func cancelScan() { state = .idle }
}
