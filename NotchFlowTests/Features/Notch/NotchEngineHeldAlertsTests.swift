import XCTest
import SwiftUI
@testable import NotchFlow

/// Alerts wait while an alert-holding activity (a file drag over the notch, onboarding) is
/// in the stack, as in notchflow-clean's `FlowStage.holdsAlerts`.
final class NotchEngineHeldAlertsTests: XCTestCase {
    @MainActor
    private func makeViewModel() -> NotchViewModel {
        let viewModel = NotchViewModel(settings: TestNotchSettings(), hideDelay: 0.01, queueDelay: 0)
        TestLifetime.retain(viewModel)
        return viewModel
    }

    private var dragID: String { NotchContentRegistry.DragAndDrop.combined.id }

    @MainActor
    func testAlertWaitsWhileDragActivityIsShownAndShowsAfterIt() async {
        let viewModel = makeViewModel()
        viewModel.send(.showLiveActivity(TestNotchContent(id: dragID, priority: 100)))
        await assertEventually {
            await MainActor.run { viewModel.notchModel.liveActivityContent?.id == self.dragID }
        }

        viewModel.send(.showTemporaryNotification(TestNotchContent(id: "battery", priority: 0), duration: 5))
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(viewModel.notchModel.temporaryNotificationContent, "The alert must wait during the drag")

        viewModel.send(.hideLiveActivity(id: dragID))
        await assertEventually {
            await MainActor.run { viewModel.notchModel.temporaryNotificationContent?.id == "battery" }
        }
    }

    @MainActor
    func testShowingAlertStepsAsideForDragActivity() async {
        let viewModel = makeViewModel()
        viewModel.send(.showTemporaryNotification(TestNotchContent(id: "battery", priority: 0), duration: 5))
        await assertEventually {
            await MainActor.run { viewModel.notchModel.temporaryNotificationContent?.id == "battery" }
        }

        viewModel.send(.showLiveActivity(TestNotchContent(id: dragID, priority: 100)))
        await assertEventually {
            await MainActor.run {
                viewModel.notchModel.temporaryNotificationContent == nil &&
                viewModel.notchModel.liveActivityContent?.id == self.dragID
            }
        }

        viewModel.send(.hideLiveActivity(id: dragID))
        await assertEventually {
            await MainActor.run { viewModel.notchModel.temporaryNotificationContent?.id == "battery" }
        }
    }

    @MainActor
    func testHideAllDropsHeldAlerts() async {
        let viewModel = makeViewModel()
        viewModel.send(.showLiveActivity(TestNotchContent(id: dragID, priority: 100)))
        await assertEventually {
            await MainActor.run { viewModel.notchModel.liveActivityContent?.id == self.dragID }
        }
        viewModel.send(.showTemporaryNotification(TestNotchContent(id: "battery", priority: 0), duration: 5))
        viewModel.send(.hide)
        viewModel.send(.hideLiveActivity(id: dragID))
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(viewModel.notchModel.temporaryNotificationContent)
    }
}
